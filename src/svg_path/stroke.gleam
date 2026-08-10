//// Stroke outline construction.
////
//// This module turns path geometry into filled outline paths. It delegates the
//// topology work to `svg_path/offset`, where strokes share the same
//// self-intersection pruning machinery as offset bands. It also exposes
//// SVG-style dash extraction: turning a continuous path into the open subpaths
//// that would be stroked as visible dashes.

import gleam/float
import gleam/list
import gleam/result
import svg_path
import svg_path/offset

/// Errors returned by stroke helpers.
pub type Error {
  /// An underlying path operation failed.
  PathError(svg_path.Error)

  /// An underlying offset operation failed.
  OffsetError(offset.Error)

  /// Stroke width must be greater than zero.
  InvalidWidth(width: Float)

  /// Dash lengths must be finite and non-negative.
  InvalidDashLength(length: Float)

  /// Dash offset must be finite.
  InvalidDashOffset(offset: Float)
}

/// Cap style used at open subpath endpoints.
pub type Cap {
  /// Connect the two offset sides directly at the endpoint.
  Butt

  /// Add a half-circle cap at the endpoint.
  Round

  /// Extend the stroke by half the stroke width before capping.
  Square
}

/// Options for stroke outline construction.
pub type Options {
  Options(
    /// Full stroke width in path-coordinate units; must be greater than zero.
    width: Float,
    /// Cap applied to the endpoints of open subpaths.
    cap: Cap,
    /// Options used to construct and join the two half-width offsets.
    offset: offset.Options,
  )
}

/// Options for SVG-style dash extraction.
///
/// Dash lengths are already-resolved user-coordinate lengths. CSS parsing,
/// percentages, and `pathLength` scaling are intentionally outside this type.
/// Empty patterns and all-zero patterns behave like `stroke-dasharray: none`.
pub type DashOptions {
  DashOptions(
    /// Alternating visible and hidden lengths in path-coordinate units.
    pattern: List(Float),
    /// Signed path-coordinate offset into the repeated dash pattern.
    offset: Float,
    /// Options used for arc-length measurement and splitting.
    length: svg_path.LengthOptions,
  )
}

/// Return default stroke options.
pub fn default_options() -> Options {
  Options(width: 1.0, cap: Butt, offset: offset.default_options())
}

/// Return default dash extraction options for a pattern and dash offset.
///
/// `pattern` and `offset` are interpreted as resolved user-coordinate lengths.
pub fn default_dash_options(
  pattern pattern: List(Float),
  offset offset: Float,
) -> DashOptions {
  DashOptions(pattern:, offset:, length: svg_path.default_length_options())
}

/// Stroke a segment using default options with the given width.
pub fn segment(
  segment: svg_path.Segment,
  width width: Float,
) -> Result(svg_path.Path, Error) {
  let options = Options(..default_options(), width:)
  segment_with(segment, options:)
}

/// Stroke a segment using explicit options.
pub fn segment_with(
  segment segment: svg_path.Segment,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use subpath <- result.try(
    svg_path.subpath([segment]) |> result.map_error(PathError),
  )
  subpath_with(subpath, options:)
}

/// Stroke a subpath using default options with the given width.
pub fn subpath(
  subpath: svg_path.Subpath,
  width width: Float,
) -> Result(svg_path.Path, Error) {
  let options = Options(..default_options(), width:)
  subpath_with(subpath, options:)
}

/// Stroke a subpath using explicit options.
pub fn subpath_with(
  subpath subpath: svg_path.Subpath,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  offset.subpath_stroke_with(
    subpath,
    width: options.width,
    cap: to_offset_cap(options.cap),
    options: options.offset,
  )
  |> result.map_error(OffsetError)
}

/// Stroke every subpath in a path using default options with the given width.
pub fn path(
  path: svg_path.Path,
  width width: Float,
) -> Result(svg_path.Path, Error) {
  let options = Options(..default_options(), width:)
  path_with(path, options:)
}

/// Stroke every subpath in a path using explicit options.
pub fn path_with(
  path path: svg_path.Path,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use subpaths <- result.try(
    stroke_subpaths(svg_path.path_subpaths(path), options, stroked: []),
  )
  Ok(svg_path.Path(subpaths:))
}

/// Return the visible dash pieces of a subpath using SVG dasharray semantics.
///
/// Each returned dash is an open subpath preserving the original segment types
/// where possible. Empty and all-zero patterns return the original continuous
/// subpath as a singleton when the subpath has positive length. An active dash
/// pattern on a closed subpath has a visible seam: a dash covering the whole
/// closed subpath is opened at the subpath start so cap styles can apply there.
pub fn subpath_dashes(
  subpath: svg_path.Subpath,
  pattern pattern: List(Float),
  offset offset: Float,
) -> Result(List(svg_path.Subpath), Error) {
  subpath_dashes_with(
    subpath,
    dash_options: default_dash_options(pattern:, offset:),
  )
}

/// Return the visible dash pieces of a subpath using explicit dash options.
pub fn subpath_dashes_with(
  subpath subpath: svg_path.Subpath,
  dash_options dash_options: DashOptions,
) -> Result(List(svg_path.Subpath), Error) {
  use _ <- result.try(validate_dash_options(dash_options))
  use pattern <- result.try(normalize_dash_pattern(dash_options.pattern))
  use length <- result.try(
    svg_path.subpath_length_with(subpath, options: dash_options.length)
    |> result.map_error(PathError),
  )

  case length <=. 0.0 {
    True -> Ok([])
    False ->
      case pattern {
        [] -> continuous_dash(subpath)
        _ -> {
          let intervals =
            dash_intervals(length, pattern, offset: dash_options.offset)
          dash_pieces(
            intervals,
            subpath,
            length,
            dash_options.length,
            accumulated: [],
          )
        }
      }
  }
}

/// Return the visible dash pieces of every subpath in a path.
///
/// The dash pattern resets at the start of each subpath.
pub fn path_dashes(
  path: svg_path.Path,
  pattern pattern: List(Float),
  offset offset: Float,
) -> Result(svg_path.Path, Error) {
  path_dashes_with(path, dash_options: default_dash_options(pattern:, offset:))
}

/// Return the visible dash pieces of every subpath in a path using explicit
/// dash options.
///
/// The dash pattern resets at the start of each subpath.
pub fn path_dashes_with(
  path path: svg_path.Path,
  dash_options dash_options: DashOptions,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_dash_options(dash_options))
  use subpaths <- result.try(
    path_dashes_loop(
      svg_path.path_subpaths(path),
      dash_options,
      accumulated: [],
    ),
  )
  Ok(svg_path.Path(subpaths:))
}

/// Stroke a subpath after applying SVG dasharray semantics.
///
/// This first extracts open dash subpaths, then strokes each dash independently.
pub fn subpath_dashed(
  subpath: svg_path.Subpath,
  width width: Float,
  pattern pattern: List(Float),
  offset offset: Float,
) -> Result(svg_path.Path, Error) {
  subpath_dashed_with(
    subpath,
    options: Options(..default_options(), width:),
    dash_options: default_dash_options(pattern:, offset:),
  )
}

/// Stroke a subpath after applying SVG dasharray semantics using explicit
/// stroke and dash options.
///
/// This first extracts open dash subpaths, then strokes each dash independently.
pub fn subpath_dashed_with(
  subpath subpath: svg_path.Subpath,
  options options: Options,
  dash_options dash_options: DashOptions,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use dashes <- result.try(subpath_dashes_with(subpath, dash_options:))
  use subpaths <- result.try(stroke_subpaths(dashes, options, stroked: []))
  Ok(svg_path.Path(subpaths:))
}

/// Stroke a path after applying SVG dasharray semantics to each subpath.
///
/// The dash pattern resets at the start of each subpath.
pub fn path_dashed(
  path: svg_path.Path,
  width width: Float,
  pattern pattern: List(Float),
  offset offset: Float,
) -> Result(svg_path.Path, Error) {
  path_dashed_with(
    path,
    options: Options(..default_options(), width:),
    dash_options: default_dash_options(pattern:, offset:),
  )
}

/// Stroke a path after applying SVG dasharray semantics using explicit stroke
/// and dash options.
///
/// The dash pattern resets at the start of each subpath.
pub fn path_dashed_with(
  path path: svg_path.Path,
  options options: Options,
  dash_options dash_options: DashOptions,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use dashes <- result.try(path_dashes_with(path, dash_options:))
  path_with(dashes, options:)
}

fn validate_options(options: Options) -> Result(Nil, Error) {
  case options.width <=. 0.0 || !is_finite(options.width) {
    True -> Error(InvalidWidth(options.width))
    False -> Ok(Nil)
  }
}

fn normalize_dash_pattern(pattern: List(Float)) -> Result(List(Float), Error) {
  use _ <- result.try(validate_dash_pattern(pattern))
  case pattern, list.all(pattern, fn(length) { length == 0.0 }) {
    [], _ -> Ok([])
    _, True -> Ok([])
    _, False ->
      case list.length(pattern) % 2 == 1 {
        True -> Ok(list.append(pattern, pattern))
        False -> Ok(pattern)
      }
  }
}

fn validate_dash_pattern(pattern: List(Float)) -> Result(Nil, Error) {
  case pattern {
    [] -> Ok(Nil)
    [first, ..rest] -> {
      case first <. 0.0 || !is_finite(first) {
        True -> Error(InvalidDashLength(first))
        False -> validate_dash_pattern(rest)
      }
    }
  }
}

fn validate_dash_offset(offset: Float) -> Result(Nil, Error) {
  case is_finite(offset) {
    True -> Ok(Nil)
    False -> Error(InvalidDashOffset(offset))
  }
}

fn validate_dash_options(options: DashOptions) -> Result(Nil, Error) {
  use _ <- result.try(validate_dash_pattern(options.pattern))
  use _ <- result.try(validate_dash_offset(options.offset))
  svg_path.validate_length_options(options.length)
  |> result.map_error(PathError)
}

fn dash_intervals(
  length: Float,
  pattern: List(Float),
  offset offset: Float,
) -> List(#(Float, Float)) {
  let pattern_length = sum(pattern)
  let offset = positive_remainder(offset, pattern_length)
  let #(index, remaining) = dash_start(pattern, offset, index: 0)
  dash_intervals_loop(
    length,
    pattern,
    position: 0.0,
    index:,
    remaining:,
    intervals: [],
  )
}

fn dash_start(
  pattern: List(Float),
  offset: Float,
  index index: Int,
) -> #(Int, Float) {
  case pattern {
    [] -> #(0, 0.0)
    [first, ..rest] -> {
      case offset <. first || rest == [] {
        True -> #(index, first -. offset)
        False -> dash_start(rest, offset -. first, index: index + 1)
      }
    }
  }
}

fn dash_intervals_loop(
  length: Float,
  pattern: List(Float),
  position position: Float,
  index index: Int,
  remaining remaining: Float,
  intervals intervals: List(#(Float, Float)),
) -> List(#(Float, Float)) {
  case position >=. length {
    True -> list.reverse(intervals)
    False if remaining <=. 0.0 -> {
      let next_index = next_dash_index(index, pattern)
      dash_intervals_loop(
        length,
        pattern,
        position:,
        index: next_index,
        remaining: dash_length_at(pattern, next_index),
        intervals:,
      )
    }
    False -> {
      let distance_to_end = length -. position
      let #(step, next) = case remaining >=. distance_to_end {
        True -> #(distance_to_end, length)
        False -> #(remaining, position +. remaining)
      }
      let intervals = case index % 2 == 0 && step >. 0.0 {
        True -> [#(position, next), ..intervals]
        False -> intervals
      }
      let next_index = next_dash_index(index, pattern)
      dash_intervals_loop(
        length,
        pattern,
        position: next,
        index: next_index,
        remaining: dash_length_at(pattern, next_index),
        intervals:,
      )
    }
  }
}

fn next_dash_index(index: Int, pattern: List(Float)) -> Int {
  let next = index + 1
  case next >= list.length(pattern) {
    True -> 0
    False -> next
  }
}

fn dash_length_at(pattern: List(Float), index: Int) -> Float {
  case list.drop(pattern, index) {
    [length, ..] -> length
    [] -> 0.0
  }
}

fn dash_pieces(
  intervals: List(#(Float, Float)),
  subpath: svg_path.Subpath,
  length: Float,
  length_options: svg_path.LengthOptions,
  accumulated accumulated: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case intervals {
    [] -> Ok(list.reverse(accumulated))
    [first, ..rest] -> {
      let #(from, to) = first
      use piece <- result.try(
        dash_piece(subpath, from:, to:, length:, length_options:)
        |> result.map_error(PathError),
      )
      dash_pieces(rest, subpath, length, length_options, accumulated: [
        piece,
        ..accumulated
      ])
    }
  }
}

fn dash_piece(
  subpath: svg_path.Subpath,
  from from: Float,
  to to: Float,
  length length: Float,
  length_options length_options: svg_path.LengthOptions,
) -> Result(svg_path.Subpath, svg_path.Error) {
  case from == 0.0 && to == length {
    True -> open_full_dash(subpath)
    False ->
      case svg_path.subpath_is_closed(subpath) {
        True ->
          svg_path.subpath_between_lengths_with(
            subpath,
            from:,
            to:,
            options: length_options,
          )
        False -> {
          case from == 0.0 {
            True -> first_split_piece(subpath, at: to, length_options:)
            False ->
              case to == length {
                True -> last_split_piece(subpath, at: from, length_options:)
                False ->
                  svg_path.subpath_between_lengths_with(
                    subpath,
                    from:,
                    to:,
                    options: length_options,
                  )
              }
          }
        }
      }
  }
}

fn continuous_dash(
  subpath: svg_path.Subpath,
) -> Result(List(svg_path.Subpath), Error) {
  Ok([subpath])
}

fn open_full_dash(
  subpath: svg_path.Subpath,
) -> Result(svg_path.Subpath, svg_path.Error) {
  case svg_path.subpath_is_closed(subpath) {
    True ->
      svg_path.subpath_open_at(subpath, at: svg_path.SubpathParameter(0, 0.0))
    False -> Ok(subpath)
  }
}

fn first_split_piece(
  subpath: svg_path.Subpath,
  at distance: Float,
  length_options length_options: svg_path.LengthOptions,
) -> Result(svg_path.Subpath, svg_path.Error) {
  use pieces <- result.try(svg_path.subpath_between_lengths_many_with(
    subpath,
    between: [distance],
    options: length_options,
  ))
  case pieces {
    [first, ..] -> Ok(first)
    [] ->
      svg_path.subpath_between_lengths_with(
        subpath,
        from: 0.0,
        to: distance,
        options: length_options,
      )
  }
}

fn last_split_piece(
  subpath: svg_path.Subpath,
  at distance: Float,
  length_options length_options: svg_path.LengthOptions,
) -> Result(svg_path.Subpath, svg_path.Error) {
  use pieces <- result.try(svg_path.subpath_between_lengths_many_with(
    subpath,
    between: [distance],
    options: length_options,
  ))
  case list.last(pieces) {
    Ok(last) -> Ok(last)
    Error(_) ->
      svg_path.subpath_between_lengths_with(
        subpath,
        from: distance,
        to: distance,
        options: length_options,
      )
  }
}

fn path_dashes_loop(
  subpaths: List(svg_path.Subpath),
  dash_options: DashOptions,
  accumulated accumulated: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(accumulated))
    [first, ..rest] -> {
      use dashes <- result.try(subpath_dashes_with(first, dash_options:))
      path_dashes_loop(
        rest,
        dash_options,
        accumulated: list.append(list.reverse(dashes), accumulated),
      )
    }
  }
}

fn stroke_subpaths(
  subpaths: List(svg_path.Subpath),
  options: Options,
  stroked stroked: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(stroked))
    [first, ..rest] -> {
      use path <- result.try(subpath_with(first, options:))
      stroke_subpaths(
        rest,
        options,
        stroked: list.append(
          list.reverse(svg_path.path_subpaths(path)),
          stroked,
        ),
      )
    }
  }
}

fn to_offset_cap(cap: Cap) -> offset.Cap {
  case cap {
    Butt -> offset.Butt
    Round -> offset.RoundCap
    Square -> offset.Square
  }
}

fn is_finite(value: Float) -> Bool {
  !is_nan(value -. value)
}

fn is_nan(value: Float) -> Bool {
  !{ value <. 0.0 || value >=. 0.0 }
}

fn sum(values: List(Float)) -> Float {
  list.fold(values, 0.0, fn(total, value) { total +. value })
}

fn positive_remainder(value: Float, modulus: Float) -> Float {
  let turns = float.floor(value /. modulus)
  let remainder = value -. turns *. modulus
  case remainder <. 0.0 {
    True -> remainder +. modulus
    False ->
      case remainder >=. modulus {
        True -> remainder -. modulus
        False -> remainder
      }
  }
}
