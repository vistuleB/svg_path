//// Stroke outline construction.
////
//// This module turns path geometry into filled outline paths. An open subpath
//// stroke is built as right offset, end cap, reversed left offset, start cap.
//// A closed subpath stroke is built as the two offset contours with opposite
//// traversal directions. Dash arrays are not part of this first pass; split
//// paths can be stroked by calling these helpers on the visible pieces.

import gleam/list
import gleam/result
import svg_path
import svg_path/offset
import vec/vec2f

const tangent_epsilon = 0.000001

/// Errors returned by stroke helpers.
pub type Error {
  /// An underlying path operation failed.
  PathError(svg_path.Error)

  /// An underlying offset operation failed.
  OffsetError(offset.Error)

  /// Stroke width must be greater than zero.
  InvalidWidth(width: Float)

  /// A segment tangent was too small to define a stable cap direction.
  DegenerateTangent(t: Float)
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
  case svg_path.segments(subpath) {
    [] -> Ok(svg_path.empty_path())
    _ ->
      case svg_path.is_closed(subpath) {
        True -> stroke_closed_subpath(subpath, options)
        False -> stroke_open_subpath(subpath, options)
      }
  }
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
  case options.width <=. 0.0 {
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

fn stroke_closed_subpath(
  subpath: svg_path.Subpath,
  options: Options,
) -> Result(svg_path.Path, Error) {
  let half_width = options.width /. 2.0
  use right <- result.try(offset_subpath(subpath, half_width, options.offset))
  use left <- result.try(offset_subpath(
    subpath,
    0.0 -. half_width,
    options.offset,
  ))
  Ok(svg_path.Path(subpaths: [right, svg_path.reverse_subpath(left)]))
}

fn stroke_open_subpath(
  subpath: svg_path.Subpath,
  options: Options,
) -> Result(svg_path.Path, Error) {
  let half_width = options.width /. 2.0
  use right <- result.try(offset_subpath(subpath, half_width, options.offset))
  use left <- result.try(offset_subpath(
    subpath,
    0.0 -. half_width,
    options.offset,
  ))
  use outline <- result.try(open_outline(
    subpath,
    right,
    left,
    half_width,
    options.cap,
  ))
  Ok(svg_path.from_subpath(outline))
}

fn offset_subpath(
  subpath: svg_path.Subpath,
  distance: Float,
  options: offset.Options,
) -> Result(svg_path.Subpath, Error) {
  offset.subpath_untrimmed_with(subpath, distance:, options:)
  |> result.map_error(OffsetError)
}

fn open_outline(
  source: svg_path.Subpath,
  right: svg_path.Subpath,
  left: svg_path.Subpath,
  half_width: Float,
  cap: Cap,
) -> Result(svg_path.Subpath, Error) {
  use start_tangent <- result.try(subpath_endpoint_tangent(
    source,
    at_start: True,
  ))
  use end_tangent <- result.try(subpath_endpoint_tangent(
    source,
    at_start: False,
  ))

  use right_start <- result.try(
    svg_path.start(right) |> result.map_error(PathError),
  )
  use right_end <- result.try(
    svg_path.end(right) |> result.map_error(PathError),
  )
  use left_start <- result.try(
    svg_path.start(left) |> result.map_error(PathError),
  )
  use left_end <- result.try(svg_path.end(left) |> result.map_error(PathError))

  let reversed_left = svg_path.reverse_subpath(left) |> svg_path.segments

  let segments = case cap {
    Butt ->
      list.append(
        svg_path.segments(right),
        list.append(
          butt_cap(right_end, left_end),
          list.append(reversed_left, butt_cap(left_start, right_start)),
        ),
      )
    Round ->
      list.append(
        svg_path.segments(right),
        list.append(
          round_cap(right_end, left_end, half_width),
          list.append(
            reversed_left,
            round_cap(left_start, right_start, half_width),
          ),
        ),
      )
    Square -> {
      let right_start_ext =
        subtract(right_start, scale(start_tangent, half_width))
      let left_start_ext =
        subtract(left_start, scale(start_tangent, half_width))
      let right_end_ext = add(right_end, scale(end_tangent, half_width))
      let left_end_ext = add(left_end, scale(end_tangent, half_width))

      [
        svg_path.Line(start: right_start_ext, end: right_start),
        ..list.append(
          svg_path.segments(right),
          list.append(
            square_cap_at_end(right_end, right_end_ext, left_end_ext, left_end),
            list.append(
              reversed_left,
              square_cap_at_start(left_start, left_start_ext, right_start_ext),
            ),
          ),
        )
      ]
    }
  }

  use outline <- result.try(
    svg_path.subpath_with(segments, policy: svg_path.Wiggle)
    |> result.map_error(PathError),
  )
  svg_path.set_closed_with(outline, closed: True, policy: svg_path.Wiggle)
  |> result.map_error(PathError)
}

fn butt_cap(
  start: svg_path.Point,
  end: svg_path.Point,
) -> List(svg_path.Segment) {
  [svg_path.Line(start:, end:)]
}

fn round_cap(
  start: svg_path.Point,
  end: svg_path.Point,
  radius: Float,
) -> List(svg_path.Segment) {
  [
    svg_path.Arc(
      start:,
      radius: svg_path.point(radius, radius),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end:,
    ),
  ]
}

fn square_cap_at_end(
  right_end: svg_path.Point,
  right_end_ext: svg_path.Point,
  left_end_ext: svg_path.Point,
  left_end: svg_path.Point,
) -> List(svg_path.Segment) {
  [
    svg_path.Line(start: right_end, end: right_end_ext),
    svg_path.Line(start: right_end_ext, end: left_end_ext),
    svg_path.Line(start: left_end_ext, end: left_end),
  ]
}

fn square_cap_at_start(
  left_start: svg_path.Point,
  left_start_ext: svg_path.Point,
  right_start_ext: svg_path.Point,
) -> List(svg_path.Segment) {
  [
    svg_path.Line(start: left_start, end: left_start_ext),
    svg_path.Line(start: left_start_ext, end: right_start_ext),
  ]
}

fn subpath_endpoint_tangent(
  subpath: svg_path.Subpath,
  at_start at_start: Bool,
) -> Result(svg_path.Point, Error) {
  let segments = svg_path.segments(subpath)
  case at_start {
    True ->
      case segments {
        [] -> Error(DegenerateTangent(0.0))
        [first, ..] -> segment_unit_tangent(first, t: 0.0)
      }
    False ->
      case list.last(segments) {
        Error(_) -> Error(DegenerateTangent(1.0))
        Ok(last) -> segment_unit_tangent(last, t: 1.0)
      }
  }
}

fn segment_unit_tangent(
  segment: svg_path.Segment,
  t t: Float,
) -> Result(svg_path.Point, Error) {
  use derivative <- result.try(
    svg_path.segment_derivative(segment, at: t) |> result.map_error(PathError),
  )
  let length = vec2f.length(derivative)
  case length >. tangent_epsilon {
    True -> Ok(scale(derivative, 1.0 /. length))
    False -> Error(DegenerateTangent(t))
  }
}

fn add(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.point(a.x +. b.x, a.y +. b.y)
}

fn subtract(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.point(a.x -. b.x, a.y -. b.y)
}

fn scale(point: svg_path.Point, factor: Float) -> svg_path.Point {
  svg_path.point(point.x *. factor, point.y *. factor)
}
