//// Stroke outline construction.
////
//// This module turns path geometry into filled outline paths. It delegates the
//// topology work to `svg_path/offset`, where strokes share the same
//// self-intersection pruning machinery as offset bands.

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
  Options(width: Float, cap: Cap, offset: offset.Options)
}

/// Return default stroke options.
pub fn default_options() -> Options {
  Options(width: 1.0, cap: Butt, offset: offset.default_options())
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
    stroke_subpaths(svg_path.subpaths(path), options, stroked: []),
  )
  Ok(svg_path.Path(subpaths:))
}

fn validate_options(options: Options) -> Result(Nil, Error) {
  case options.width <=. 0.0 || !is_finite(options.width) {
    True -> Error(InvalidWidth(options.width))
    False -> Ok(Nil)
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
        stroked: list.append(list.reverse(svg_path.subpaths(path)), stroked),
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
