//// Convert SVG basic shape elements into subpaths.
////
//// These helpers follow SVG's equivalent path algorithms for `rect`,
//// `circle`, `ellipse`, `line`, `polyline`, and `polygon`.

import gleam/float
import gleam/option.{type Option, None, Some}
import svg_path

/// Errors returned by SVG primitive conversion helpers.
pub type Error {
  /// A `rect` width was negative.
  InvalidRectWidth(width: Float)

  /// A `rect` height was negative.
  InvalidRectHeight(height: Float)

  /// A `rect` x-axis corner radius was negative.
  InvalidRectRadiusX(rx: Float)

  /// A `rect` y-axis corner radius was negative.
  InvalidRectRadiusY(ry: Float)

  /// A `circle` radius was negative.
  InvalidCircleRadius(r: Float)

  /// An `ellipse` x-axis radius was negative.
  InvalidEllipseRadiusX(rx: Float)

  /// An `ellipse` y-axis radius was negative.
  InvalidEllipseRadiusY(ry: Float)

  /// The SVG element would not render because at least one required extent is zero.
  DisabledRendering

  /// An error from the core path model.
  PathError(svg_path.Error)
}

/// Convert an SVG `rect` element to a subpath.
///
/// The equivalent path starts at `(x + rx, y)` and proceeds clockwise. If only
/// one corner radius is present, the missing radius uses the same value. Radii
/// are clamped so they are no greater than half the rectangle extent.
pub fn rect(
  x x: Float,
  y y: Float,
  width width: Float,
  height height: Float,
  rx rx: Option(Float),
  ry ry: Option(Float),
) -> Result(svg_path.Subpath, Error) {
  use _ <- result_try(validate_rect_size(width, height))
  use radii <- result_try(rect_radii(width, height, rx, ry))
  let #(rx, ry) = radii
  let x2 = x +. width
  let y2 = y +. height
  let start = svg_path.Point(x +. rx, y)

  let segments = case rx >. 0.0 && ry >. 0.0 {
    False -> [
      svg_path.Line(start: start, end: svg_path.Point(x2, y)),
      svg_path.Line(start: svg_path.Point(x2, y), end: svg_path.Point(x2, y2)),
      svg_path.Line(start: svg_path.Point(x2, y2), end: svg_path.Point(x, y2)),
      svg_path.Line(start: svg_path.Point(x, y2), end: start),
    ]

    True -> [
      svg_path.Line(start: start, end: svg_path.Point(x2 -. rx, y)),
      svg_path.Arc(
        start: svg_path.Point(x2 -. rx, y),
        radius: svg_path.Point(rx, ry),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.Point(x2, y +. ry),
      ),
      svg_path.Line(
        start: svg_path.Point(x2, y +. ry),
        end: svg_path.Point(x2, y2 -. ry),
      ),
      svg_path.Arc(
        start: svg_path.Point(x2, y2 -. ry),
        radius: svg_path.Point(rx, ry),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.Point(x2 -. rx, y2),
      ),
      svg_path.Line(
        start: svg_path.Point(x2 -. rx, y2),
        end: svg_path.Point(x +. rx, y2),
      ),
      svg_path.Arc(
        start: svg_path.Point(x +. rx, y2),
        radius: svg_path.Point(rx, ry),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.Point(x, y2 -. ry),
      ),
      svg_path.Line(
        start: svg_path.Point(x, y2 -. ry),
        end: svg_path.Point(x, y +. ry),
      ),
      svg_path.Arc(
        start: svg_path.Point(x, y +. ry),
        radius: svg_path.Point(rx, ry),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: start,
      ),
    ]
  }

  close(segments)
}

/// Convert an SVG `circle` element to a subpath.
///
/// The equivalent path starts at the 3 o'clock point and uses four quarter-arc
/// segments.
pub fn circle(
  cx cx: Float,
  cy cy: Float,
  r r: Float,
) -> Result(svg_path.Subpath, Error) {
  case r <. 0.0, r == 0.0 {
    True, _ -> Error(InvalidCircleRadius(r))
    _, True -> Error(DisabledRendering)
    False, False -> ellipse(cx:, cy:, rx: r, ry: r)
  }
}

/// Convert an SVG `ellipse` element to a subpath.
///
/// The equivalent path starts at the 3 o'clock point and uses four quarter-arc
/// segments.
pub fn ellipse(
  cx cx: Float,
  cy cy: Float,
  rx rx: Float,
  ry ry: Float,
) -> Result(svg_path.Subpath, Error) {
  use _ <- result_try(validate_ellipse_radii(rx, ry))
  let start = svg_path.Point(cx +. rx, cy)
  let radius = svg_path.Point(rx, ry)

  close([
    svg_path.Arc(
      start: start,
      radius: radius,
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(cx, cy +. ry),
    ),
    svg_path.Arc(
      start: svg_path.Point(cx, cy +. ry),
      radius: radius,
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(cx -. rx, cy),
    ),
    svg_path.Arc(
      start: svg_path.Point(cx -. rx, cy),
      radius: radius,
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(cx, cy -. ry),
    ),
    svg_path.Arc(
      start: svg_path.Point(cx, cy -. ry),
      radius: radius,
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: start,
    ),
  ])
}

/// Convert an SVG `line` element to a subpath.
pub fn line(
  x1 x1: Float,
  y1 y1: Float,
  x2 x2: Float,
  y2 y2: Float,
) -> Result(svg_path.Subpath, Error) {
  let start = svg_path.Point(x1, y1)
  let end = svg_path.Point(x2, y2)

  svg_path.subpath([svg_path.Line(start:, end:)])
  |> map_core_error
}

/// Convert an SVG `polyline` element to a subpath.
pub fn polyline(
  points: List(svg_path.Point),
) -> Result(svg_path.Subpath, Error) {
  svg_path.subpath_polyline(points)
  |> map_core_error
}

/// Convert an SVG `polygon` element to a subpath.
pub fn polygon(
  points: List(svg_path.Point),
) -> Result(svg_path.Subpath, Error) {
  svg_path.subpath_polygon(points)
  |> map_core_error
}

fn validate_rect_size(width: Float, height: Float) -> Result(Nil, Error) {
  case width <. 0.0, height <. 0.0, width == 0.0 || height == 0.0 {
    True, _, _ -> Error(InvalidRectWidth(width))
    _, True, _ -> Error(InvalidRectHeight(height))
    _, _, True -> Error(DisabledRendering)
    False, False, False -> Ok(Nil)
  }
}

fn rect_radii(
  width: Float,
  height: Float,
  rx: Option(Float),
  ry: Option(Float),
) -> Result(#(Float, Float), Error) {
  let radii = case rx, ry {
    None, None -> #(0.0, 0.0)
    Some(rx), None -> #(rx, rx)
    None, Some(ry) -> #(ry, ry)
    Some(rx), Some(ry) -> #(rx, ry)
  }

  let #(rx, ry) = radii
  case rx <. 0.0, ry <. 0.0 {
    True, _ -> Error(InvalidRectRadiusX(rx))
    _, True -> Error(InvalidRectRadiusY(ry))
    False, False ->
      Ok(#(float.min(rx, width /. 2.0), float.min(ry, height /. 2.0)))
  }
}

fn validate_ellipse_radii(rx: Float, ry: Float) -> Result(Nil, Error) {
  case rx <. 0.0, ry <. 0.0, rx == 0.0 || ry == 0.0 {
    True, _, _ -> Error(InvalidEllipseRadiusX(rx))
    _, True, _ -> Error(InvalidEllipseRadiusY(ry))
    _, _, True -> Error(DisabledRendering)
    False, False, False -> Ok(Nil)
  }
}

fn close(segments: List(svg_path.Segment)) -> Result(svg_path.Subpath, Error) {
  use subpath <- result_try(svg_path.subpath(segments) |> map_core_error)

  svg_path.subpath_set_closed(subpath, closed: True)
  |> map_core_error
}

fn map_core_error(
  result: Result(svg_path.Subpath, svg_path.Error),
) -> Result(svg_path.Subpath, Error) {
  case result {
    Ok(subpath) -> Ok(subpath)
    Error(error) -> Error(PathError(error))
  }
}

fn result_try(
  result: Result(a, Error),
  next: fn(a) -> Result(b, Error),
) -> Result(b, Error) {
  case result {
    Ok(value) -> next(value)
    Error(error) -> Error(error)
  }
}
