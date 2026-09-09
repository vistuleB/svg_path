//// Stroke outline construction.
////
//// This module turns path geometry into filled outline paths. It delegates the
//// topology work to `svg_path/offset`, where strokes share the same
//// self-intersection pruning machinery as offset bands. It also exposes
//// SVG-style dash extraction: turning a continuous path into the open subpaths
//// that would be stroked as visible dashes.
////
//// Outline operations take explicit `join` and `cap` arguments, including
//// the forms that use default options. Pure dash extraction takes neither.

import gleam/float
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import svg_path
import svg_path/internal/number
import svg_path/offset
import svg_path/point as point_helpers

const point_tolerance = 0.000000001

/// Errors returned by stroke helpers.
pub type Error {
  /// An underlying path operation failed.
  PathError(error: svg_path.Error)

  /// An underlying offset operation failed.
  OffsetError(error: offset.Error)

  /// Stroke width must be finite and greater than zero.
  InvalidWidth(width: Float)

  /// Dash lengths must be finite and non-negative.
  InvalidDashLength(length: Float)

  /// Dash offset must be finite.
  InvalidDashOffset(offset: Float)

  /// The normalized dash pattern's total length must be finite.
  InvalidDashPatternLength
}

/// Join style for the stroke.
///
/// This covers the common SVG `stroke-linejoin` values `bevel`, `miter`, and
/// `round`. SVG 2 also describes `miter-clip` and `arcs`; those are not exposed
/// here yet.
pub type Join {
  /// Connect adjacent offset segments with a straight line.
  Bevel

  /// Extend the offset tangents toward their intersection when the miter stays
  /// within `miter_limit`; otherwise fall back to `Bevel`.
  Miter(miter_limit: Float)

  /// Connect adjacent offset segments with a circular SVG arc.
  Round
}

/// Cap style used at open subpath endpoints.
pub type Cap {
  /// Connect the two offset sides directly at the endpoint.
  Butt

  /// Add a half-circle cap at the endpoint.
  RoundCap

  /// Extend the stroke by half the stroke width before capping.
  Square
}

/// Width and technical options for stroke outline construction.
/// Join and cap styles are explicit operation arguments.
pub type Options {
  Options(
    /// Finite, positive full stroke width in path-coordinate units.
    width: Float,
    /// Technical options used to construct the two half-width offsets.
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
    length_options: svg_path.LengthOptions,
  )
}

/// Return default stroke options.
pub fn default_options() -> Options {
  Options(width: 1.0, offset: offset.default_options())
}

/// Return default dash extraction options for a pattern and dash offset.
///
/// `pattern` and `offset` are interpreted as resolved user-coordinate lengths.
pub fn default_dash_options(
  pattern pattern: List(Float),
  offset offset: Float,
) -> DashOptions {
  DashOptions(
    pattern:,
    offset:,
    length_options: svg_path.default_length_options(),
  )
}

/// Stroke a segment using default options with the given width.
pub fn segment(
  segment: svg_path.Segment,
  width width: Float,
  join join: Join,
  cap cap: Cap,
) -> Result(svg_path.Path, Error) {
  let options = Options(..default_options(), width:)
  segment_with(segment, join:, cap:, options:)
}

/// Stroke a segment using explicit options.
pub fn segment_with(
  segment segment: svg_path.Segment,
  join join: Join,
  cap cap: Cap,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options, join))
  use subpath <- result.try(
    svg_path.subpath([segment]) |> result.map_error(PathError),
  )
  subpath_with(subpath, join:, cap:, options:)
}

/// Stroke a subpath using default options with the given width.
pub fn subpath(
  subpath: svg_path.Subpath,
  width width: Float,
  join join: Join,
  cap cap: Cap,
) -> Result(svg_path.Path, Error) {
  let options = Options(..default_options(), width:)
  subpath_with(subpath, join:, cap:, options:)
}

/// Stroke a subpath using explicit options.
/// Both sides and caps use the same normalized source. Open strokes are
/// trimmed as one closed outline; closed strokes trim their two contours
/// together. The offset options' per-side band trimming controls do not apply.
pub fn subpath_with(
  subpath subpath: svg_path.Subpath,
  join join: Join,
  cap cap: Cap,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options, join))
  let width = options.width
  let join = to_offset_join(join)
  let options = options.offset
  let result = {
    let radius = width /. 2.0
    case svg_path.subpath_segments(subpath) {
      [] -> Ok(svg_path.path_empty())
      _ ->
        case
          svg_path.subpath_is_zero_length(subpath, tolerance: point_tolerance)
        {
          Error(error) -> Error(offset.InternalPathError(error))
          Ok(True) -> zero_length_stroke_path(subpath, radius:, cap:)
          Ok(False) -> {
            case svg_path.subpath_is_closed(subpath) {
              True -> {
                closed_stroke_path(
                  subpath,
                  radius: radius,
                  join:,
                  cap:,
                  options: options,
                )
              }
              False -> {
                use untrimmed <- result.try(untrimmed_stroke_outline(
                  subpath,
                  radius,
                  join,
                  cap,
                  options,
                ))
                topological_band_path(
                  [untrimmed],
                  bands: [offset.OpenSubpathBand(untrimmed)],
                  options:,
                )
              }
            }
          }
        }
    }
  }
  result
  |> result.map_error(fn(error) { OffsetError(offset.public_error(error)) })
}

fn topological_band_path(
  untrimmed: List(svg_path.Subpath),
  bands bands: List(offset.OneSubpathBand),
  options options: offset.Options,
) -> Result(svg_path.Path, offset.InternalError) {
  use loops <- result.try(offset.internal_topological_band_loops(
    untrimmed,
    bands:,
    options:,
  ))
  use winding <- result.try(offset.internal_band_winding_function(bands))
  offset.orient_band_path(svg_path.Path(subpaths: loops), winding)
}

fn closed_stroke_path(
  source: svg_path.Subpath,
  radius radius: Float,
  join join: offset.Join,
  cap cap: Cap,
  options options: offset.Options,
) -> Result(svg_path.Path, offset.InternalError) {
  use band <- result.try(untrimmed_stroke_band(
    source,
    radius *. 2.0,
    join,
    cap,
    options,
  ))
  case band {
    offset.OpenSubpathBand(_) -> Error(offset.InternalBandSubpathNotClosed)
    offset.ClosedSubpathBand(exterior, interior) ->
      offset.topological_band_path_with_opinions(
        [interior, exterior],
        [band],
        [
          offset.WindingSideOpinion(left: 1, right: 0),
          offset.WindingSideOpinion(left: 0, right: 1),
        ],
        options,
      )
  }
}

fn untrimmed_stroke_band(
  source: svg_path.Subpath,
  width: Float,
  join: offset.Join,
  cap: Cap,
  options: offset.Options,
) -> Result(offset.OneSubpathBand, offset.InternalError) {
  let radius = width /. 2.0
  use normalized <- result.try(offset.normalize_source_subpath(source, options))
  case svg_path.subpath_is_closed(source) {
    True -> {
      use side_a <- result.try(closed_untrimmed_side_from_normalized_source(
        normalized,
        offset: 0.0 -. radius,
        join:,
        options:,
      ))
      use side_b <- result.try(closed_untrimmed_side_from_normalized_source(
        normalized,
        offset: radius,
        join:,
        options:,
      ))
      Ok(offset.ClosedSubpathBand(exterior: side_b, interior: side_a))
    }
    False -> {
      use outline <- result.try(untrimmed_stroke_outline_from_normalized_source(
        normalized,
        radius,
        join,
        cap,
        options,
      ))
      Ok(offset.OpenSubpathBand(outline))
    }
  }
}

fn closed_untrimmed_side_from_normalized_source(
  source: svg_path.Subpath,
  offset offset: Float,
  join join: offset.Join,
  options options: offset.Options,
) -> Result(svg_path.Subpath, offset.InternalError) {
  use side <- result.try(offset.untrimmed_subpath_from_normalized_source(
    source,
    offset: offset,
    join:,
    options:,
  ))
  svg_path.subpath_set_closed_with(
    side,
    closed: True,
    policy: svg_path.WiggleWith(options.fitting.tolerance),
  )
  |> result.map_error(offset.InternalPathError)
}

fn untrimmed_stroke_outline(
  source: svg_path.Subpath,
  radius: Float,
  join: offset.Join,
  cap: Cap,
  options: offset.Options,
) -> Result(svg_path.Subpath, offset.InternalError) {
  use normalized <- result.try(offset.normalize_source_subpath(source, options))
  untrimmed_stroke_outline_from_normalized_source(
    normalized,
    radius,
    join,
    cap,
    options,
  )
}

fn untrimmed_stroke_outline_from_normalized_source(
  source: svg_path.Subpath,
  radius: Float,
  join: offset.Join,
  cap: Cap,
  options: offset.Options,
) -> Result(svg_path.Subpath, offset.InternalError) {
  use positive <- result.try(offset.untrimmed_subpath_from_normalized_source(
    source,
    offset: radius,
    join:,
    options:,
  ))
  use negative <- result.try(offset.untrimmed_subpath_from_normalized_source(
    source,
    offset: 0.0 -. radius,
    join:,
    options:,
  ))
  use end_cap <- result.try(stroke_end_cap(source, radius, cap))
  use start_cap <- result.try(stroke_start_cap(source, radius, cap))
  let segments =
    list.append(
      svg_path.subpath_segments(positive),
      list.append(
        end_cap,
        list.append(
          reverse_segments(svg_path.subpath_segments(negative)),
          start_cap,
        ),
      ),
    )
  use candidate <- result.try(
    svg_path.subpath_with(segments, policy: svg_path.Wiggle)
    |> result.map_error(offset.InternalPathError),
  )
  svg_path.subpath_set_closed_with(
    candidate,
    closed: True,
    policy: svg_path.Wiggle,
  )
  |> result.map_error(offset.InternalPathError)
}

fn zero_length_stroke_path(
  subpath: svg_path.Subpath,
  radius radius: Float,
  cap cap: Cap,
) -> Result(svg_path.Path, offset.InternalError) {
  let center = svg_path.subpath_start(subpath)
  case cap {
    Butt -> Ok(svg_path.path_empty())
    RoundCap -> zero_length_round_stroke_path(center, radius)
    Square ->
      zero_length_square_stroke_path(center, radius, svg_path.Point(1.0, 0.0))
  }
}

fn zero_length_round_stroke_path(
  center: svg_path.Point,
  radius: Float,
) -> Result(svg_path.Path, offset.InternalError) {
  let right = point_helpers.add(center, svg_path.Point(radius, 0.0))
  let left = point_helpers.add(center, svg_path.Point(0.0 -. radius, 0.0))
  let segments = [
    svg_path.Arc(
      start: right,
      radius: svg_path.Point(radius, radius),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: left,
    ),
    svg_path.Arc(
      start: left,
      radius: svg_path.Point(radius, radius),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: right,
    ),
  ]
  use outline <- result.try(
    svg_path.subpath_with(segments, policy: svg_path.Strict)
    |> result.map_error(offset.InternalPathError),
  )
  use closed <- result.try(
    svg_path.subpath_set_closed_with(
      outline,
      closed: True,
      policy: svg_path.Strict,
    )
    |> result.map_error(offset.InternalPathError),
  )
  Ok(svg_path.Path(subpaths: [closed]))
}

fn zero_length_square_stroke_path(
  center: svg_path.Point,
  radius: Float,
  direction: svg_path.Point,
) -> Result(svg_path.Path, offset.InternalError) {
  let along = point_helpers.scale(direction, by: radius)
  let across = svg_path.Point(0.0 -. along.y, along.x)
  let top_left =
    point_helpers.subtract(point_helpers.subtract(center, along), across)
  let top_right =
    point_helpers.subtract(point_helpers.add(center, along), across)
  let bottom_right = point_helpers.add(point_helpers.add(center, along), across)
  let bottom_left =
    point_helpers.add(point_helpers.subtract(center, along), across)
  use outline <- result.try(
    svg_path.subpath_with(
      line_segments_between([
        top_left,
        top_right,
        bottom_right,
        bottom_left,
        top_left,
      ]),
      policy: svg_path.Strict,
    )
    |> result.map_error(offset.InternalPathError),
  )
  use closed <- result.try(
    svg_path.subpath_set_closed_with(
      outline,
      closed: True,
      policy: svg_path.Strict,
    )
    |> result.map_error(offset.InternalPathError),
  )
  Ok(svg_path.Path(subpaths: [closed]))
}

fn stroke_end_cap(
  source: svg_path.Subpath,
  radius: Float,
  cap: Cap,
) -> Result(List(svg_path.Segment), offset.InternalError) {
  let end = svg_path.subpath_end(source)
  let assert Ok(last) = list.last(svg_path.subpath_segments(source))
  use tangent <- result.try(offset.unit_tangent(last, t: 1.0))
  stroke_cap_segments(center: end, tangent:, radius:, cap:, at_end: True)
}

fn stroke_start_cap(
  source: svg_path.Subpath,
  radius: Float,
  cap: Cap,
) -> Result(List(svg_path.Segment), offset.InternalError) {
  let start = svg_path.subpath_start(source)
  let assert [first, ..] = svg_path.subpath_segments(source)
  use tangent <- result.try(offset.unit_tangent(first, t: 0.0))
  stroke_cap_segments(center: start, tangent:, radius:, cap:, at_end: False)
}

fn stroke_cap_segments(
  center center: svg_path.Point,
  tangent tangent: svg_path.Point,
  radius radius: Float,
  cap cap: Cap,
  at_end at_end: Bool,
) -> Result(List(svg_path.Segment), offset.InternalError) {
  let normal = point_helpers.rotate_counterclockwise(tangent)
  let positive = point_helpers.add(center, point_helpers.scale(normal, radius))
  let negative =
    point_helpers.add(center, point_helpers.scale(normal, 0.0 -. radius))
  case cap {
    Butt -> {
      case at_end {
        True -> Ok(line_segments_between([positive, negative]))
        False -> Ok(line_segments_between([negative, positive]))
      }
    }
    Square -> {
      let extension = case at_end {
        True -> point_helpers.scale(tangent, radius)
        False -> point_helpers.scale(tangent, 0.0 -. radius)
      }
      let positive_extended = point_helpers.add(positive, extension)
      let negative_extended = point_helpers.add(negative, extension)
      case at_end {
        True ->
          Ok(
            line_segments_between([
              positive,
              positive_extended,
              negative_extended,
              negative,
            ]),
          )
        False ->
          Ok(
            line_segments_between([
              negative,
              negative_extended,
              positive_extended,
              positive,
            ]),
          )
      }
    }
    RoundCap -> {
      let start = case at_end {
        True -> positive
        False -> negative
      }
      let end = case at_end {
        True -> negative
        False -> positive
      }
      Ok([
        svg_path.Arc(
          start:,
          radius: svg_path.Point(radius, radius),
          x_axis_rotation: 0.0,
          large_arc: False,
          sweep: True,
          end:,
        ),
      ])
    }
  }
}

fn line_segments_between(
  points: List(svg_path.Point),
) -> List(svg_path.Segment) {
  case points {
    [] | [_] -> []
    [first, second, ..rest] -> {
      let tail = line_segments_between([second, ..rest])
      case point_helpers.near(first, second, tolerance: point_tolerance) {
        True -> tail
        False -> [svg_path.Line(start: first, end: second), ..tail]
      }
    }
  }
}

fn reverse_segments(
  segments: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  segments
  |> list.reverse
  |> list.map(svg_path.segment_reverse)
}

/// Stroke every subpath in a path using default options with the given width.
pub fn path(
  path: svg_path.Path,
  width width: Float,
  join join: Join,
  cap cap: Cap,
) -> Result(svg_path.Path, Error) {
  let options = Options(..default_options(), width:)
  path_with(path, join:, cap:, options:)
}

/// Stroke every subpath in a path using explicit options.
pub fn path_with(
  path path: svg_path.Path,
  join join: Join,
  cap cap: Cap,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options, join))
  use subpaths <- result.try(
    stroke_subpaths(
      svg_path.path_subpaths(path),
      join,
      cap,
      options,
      stroked: [],
    ),
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
/// Zero-length visible entries are retained as coincident-endpoint Lines.
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
  use pieces <- result.try(located_dash_pieces(subpath, dash_options))
  Ok(list.map(pieces, fn(piece) { piece.0 }))
}

// Retain the source arc-length address for the tangent of zero-length caps.
fn located_dash_pieces(
  subpath: svg_path.Subpath,
  dash_options: DashOptions,
) -> Result(List(#(svg_path.Subpath, Float)), Error) {
  use _ <- result.try(validate_dash_options(dash_options))
  use pattern <- result.try(normalize_dash_pattern(dash_options.pattern))
  use length <- result.try(
    svg_path.subpath_length_with(subpath, options: dash_options.length_options)
    |> result.map_error(PathError),
  )

  case length <=. 0.0 {
    True -> Ok([])
    False ->
      case pattern {
        [] -> Ok([#(subpath, 0.0)])
        _ -> {
          let intervals =
            dash_intervals(length, pattern, offset: dash_options.offset)
          dash_pieces(
            intervals,
            subpath,
            length,
            dash_options.length_options,
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
  join join: Join,
  cap cap: Cap,
) -> Result(svg_path.Path, Error) {
  subpath_dashed_with(
    subpath,
    join:,
    cap:,
    options: Options(..default_options(), width:),
    dash_options: default_dash_options(pattern:, offset:),
  )
}

/// Stroke a subpath after applying SVG dasharray semantics using explicit
/// stroke and dash options.
///
/// This first extracts open dash subpaths, then strokes each dash independently.
/// Zero-length visible dashes produce Round or Square caps (nothing for Butt).
/// Square caps use the source direction at the dash address.
pub fn subpath_dashed_with(
  subpath subpath: svg_path.Subpath,
  join join: Join,
  cap cap: Cap,
  options options: Options,
  dash_options dash_options: DashOptions,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options, join))
  use dashes <- result.try(located_dash_pieces(subpath, dash_options))
  use paths <- result.try(
    list.try_map(dashes, fn(dash) {
      let #(piece, at) = dash
      let point_dash = case svg_path.subpath_segments(piece) {
        [svg_path.Line(start:, end:)] -> start == end
        _ -> False
      }
      case cap == Square && point_dash {
        True -> {
          use parameter <- result.try(
            svg_path.subpath_parameter_at_length_with(
              subpath,
              distance: at,
              options: dash_options.length_options,
            )
            |> result.map_error(PathError),
          )
          use directions <- result.try(
            svg_path.subpath_directions(subpath, at: parameter)
            |> result.map_error(PathError),
          )
          let direction = case directions.outgoing, directions.incoming {
            Some(direction), _ | None, Some(direction) -> direction
            None, None -> svg_path.Point(1.0, 0.0)
          }
          zero_length_square_stroke_path(
            svg_path.subpath_start(piece),
            options.width /. 2.0,
            direction,
          )
          |> result.map_error(fn(error) {
            OffsetError(offset.public_error(error))
          })
        }
        False -> subpath_with(piece, join:, cap:, options:)
      }
    }),
  )
  Ok(svg_path.Path(list.flat_map(paths, svg_path.path_subpaths)))
}

/// Stroke a path after applying SVG dasharray semantics to each subpath.
///
/// The dash pattern resets at the start of each subpath.
pub fn path_dashed(
  path: svg_path.Path,
  width width: Float,
  pattern pattern: List(Float),
  offset offset: Float,
  join join: Join,
  cap cap: Cap,
) -> Result(svg_path.Path, Error) {
  path_dashed_with(
    path,
    join:,
    cap:,
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
  join join: Join,
  cap cap: Cap,
  options options: Options,
  dash_options dash_options: DashOptions,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options, join))
  use _ <- result.try(validate_dash_options(dash_options))
  use paths <- result.try(
    list.try_map(svg_path.path_subpaths(path), fn(subpath) {
      subpath_dashed_with(subpath, join:, cap:, options:, dash_options:)
    }),
  )
  Ok(svg_path.Path(list.flat_map(paths, svg_path.path_subpaths)))
}

fn validate_options(options: Options, join: Join) -> Result(Nil, Error) {
  // Validate before traversing geometry, including empty paths and dash output.
  use _ <- result.try(validate_width(options.width))
  let validation = {
    use _ <- result.try(offset.validate_options(options.offset))
    offset.validate_join(to_offset_join(join))
  }
  validation
  |> result.map_error(fn(error) { OffsetError(offset.public_error(error)) })
}

fn validate_width(width: Float) -> Result(Nil, Error) {
  case width <=. 0.0 || !number.is_finite(width) {
    True -> Error(InvalidWidth(width))
    False -> Ok(Nil)
  }
}

fn normalize_dash_pattern(pattern: List(Float)) -> Result(List(Float), Error) {
  use _ <- result.try(validate_dash_pattern(pattern))
  case pattern, list.all(pattern, number.is_zero) {
    [], _ -> Ok([])
    _, True -> Ok([])
    _, False -> {
      let normalized = case list.length(pattern) % 2 == 1 {
        True -> Ok(list.append(pattern, pattern))
        False -> Ok(pattern)
      }
      use normalized <- result.try(normalized)
      use _ <- result.try(validate_dash_pattern_length(normalized, total: 0.0))
      Ok(normalized)
    }
  }
}

fn validate_dash_pattern_length(
  pattern: List(Float),
  total total: Float,
) -> Result(Nil, Error) {
  case pattern {
    [] -> Ok(Nil)
    [first, ..rest] -> {
      case total >. 1.7976931348623157e308 -. first {
        True -> Error(InvalidDashPatternLength)
        False -> validate_dash_pattern_length(rest, total: total +. first)
      }
    }
  }
}

fn validate_dash_pattern(pattern: List(Float)) -> Result(Nil, Error) {
  case pattern {
    [] -> Ok(Nil)
    [first, ..rest] -> {
      case first <. 0.0 || !number.is_finite(first) {
        True -> Error(InvalidDashLength(first))
        False -> validate_dash_pattern(rest)
      }
    }
  }
}

fn validate_dash_offset(offset: Float) -> Result(Nil, Error) {
  case number.is_finite(offset) {
    True -> Ok(Nil)
    False -> Error(InvalidDashOffset(offset))
  }
}

fn validate_dash_options(options: DashOptions) -> Result(Nil, Error) {
  use _ <- result.try(validate_dash_pattern(options.pattern))
  use _ <- result.try(validate_dash_offset(options.offset))
  svg_path.validate_length_options(options.length_options)
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
      // At a pattern boundary keep zero entries for the interval walker;
      // skipping them here would erase visible point dashes at phase zero.
      case offset == 0.0 || offset <. first || rest == [] {
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
  case position >. length || { position == length && remaining >. 0.0 } {
    True -> list.reverse(intervals)
    False if remaining <=. 0.0 -> {
      // Advancing the index makes progress even when the position is unchanged.
      // Normalization guarantees the pattern has a positive total length.
      let next_index = next_dash_index(index, pattern)
      let intervals = case index % 2 == 0 {
        True -> [#(position, position), ..intervals]
        False -> intervals
      }
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
      case remaining >. distance_to_end {
        // Clipping the last dash/gap is not a pattern boundary. In particular
        // it must not create a zero-length dash at an artificial boundary.
        True -> list.reverse(intervals)
        False ->
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
  accumulated accumulated: List(#(svg_path.Subpath, Float)),
) -> Result(List(#(svg_path.Subpath, Float)), Error) {
  case intervals {
    [] -> Ok(list.reverse(accumulated))
    [first, ..rest] -> {
      let #(from, to) = first
      use piece <- result.try(
        dash_piece(subpath, from:, to:, length:, length_options:)
        |> result.map_error(PathError),
      )
      dash_pieces(rest, subpath, length, length_options, accumulated: [
        #(piece, from),
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
  case from == to {
    True -> {
      use at <- result.try(svg_path.subpath_point_at_length_with(
        subpath,
        distance: from,
        options: length_options,
      ))
      Ok(svg_path.segment_as_subpath(svg_path.Line(at, at)))
    }
    False -> positive_dash_piece(subpath, from:, to:, length:, length_options:)
  }
}

fn positive_dash_piece(
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
  join: Join,
  cap: Cap,
  options: Options,
  stroked stroked: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(stroked))
    [first, ..rest] -> {
      use path <- result.try(subpath_with(first, join:, cap:, options:))
      stroke_subpaths(
        rest,
        join,
        cap,
        options,
        stroked: list.append(
          list.reverse(svg_path.path_subpaths(path)),
          stroked,
        ),
      )
    }
  }
}

fn to_offset_join(join: Join) -> offset.Join {
  case join {
    Bevel -> offset.Bevel
    Miter(miter_limit) -> offset.Miter(miter_limit)
    Round -> offset.Round
  }
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
