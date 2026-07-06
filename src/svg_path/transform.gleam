//// Transform paths and path segments with 2D affine matrices.
////
//// Matrices use SVG's six-value affine form `matrix(a b c d e f)` and are
//// applied to column vectors. Use `chain(first:, then:)` when thinking in
//// transform application order, and `multiply(left:, right:)` when thinking in
//// algebraic matrix multiplication order.

import gleam/list
import gleam_community/maths
import svg_path
import svg_path/ellipse

/// An opaque SVG affine transform matrix.
///
/// The stored values correspond to SVG's `matrix(a b c d e f)` form:
/// `x' = a*x + c*y + e`, `y' = b*x + d*y + f`.
pub opaque type Matrix {
  Matrix(a: Float, b: Float, c: Float, d: Float, e: Float, f: Float)
}

/// An anchor point on a bounding box.
///
/// `Top` means the visual top edge, `box.min.y`; `Bottom` means the visual
/// bottom edge, `box.max.y`.
pub type Anchor {
  TopLeft
  TopCenter
  TopRight
  CenterLeft
  Center
  CenterRight
  BottomLeft
  BottomCenter
  BottomRight
}

/// Errors returned while transforming paths or converting matrices.
pub type Error {
  /// An arc collapsed under the transform and cannot be represented as an arc.
  DegenerateArcTransform

  /// A matrix contains non-finite values.
  InvalidMatrix

  /// An error from the core path model.
  Core(svg_path.Error)
}

/// Create an affine matrix from SVG's six matrix values.
pub fn matrix(
  a a: Float,
  b b: Float,
  c c: Float,
  d d: Float,
  e e: Float,
  f f: Float,
) -> Matrix {
  Matrix(a:, b:, c:, d:, e:, f:)
}

/// Create an affine matrix from SVG's six matrix values as a tuple.
pub fn from_tuple(
  values: #(Float, Float, Float, Float, Float, Float),
) -> Matrix {
  let #(a, b, c, d, e, f) = values

  matrix(a:, b:, c:, d:, e:, f:)
}

/// The identity transform.
pub fn identity() -> Matrix {
  matrix(a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: 0.0)
}

/// Chain two transforms in application order.
///
/// `chain(first: a, then: b)` creates a matrix that applies `a` first and `b`
/// second. In algebraic matrix order, this is `b * a`.
pub fn chain(first first: Matrix, then second: Matrix) -> Matrix {
  multiply(left: second, right: first)
}

/// Multiply two matrices in algebraic order.
///
/// `multiply(left: a, right: b)` returns `a * b`.
pub fn multiply(left left: Matrix, right right: Matrix) -> Matrix {
  matrix(
    a: left.a *. right.a +. left.c *. right.b,
    b: left.b *. right.a +. left.d *. right.b,
    c: left.a *. right.c +. left.c *. right.d,
    d: left.b *. right.c +. left.d *. right.d,
    e: left.a *. right.e +. left.c *. right.f +. left.e,
    f: left.b *. right.e +. left.d *. right.f +. left.f,
  )
}

/// Create a matrix that applies a transform about a point.
pub fn about_point(
  transform transform: Matrix,
  point point: svg_path.Point,
) -> Matrix {
  translate(x: 0.0 -. point.x, y: 0.0 -. point.y)
  |> chain(first: _, then: transform)
  |> chain(first: _, then: translate(x: point.x, y: point.y))
}

/// Create a translation matrix.
pub fn translate(x x: Float, y y: Float) -> Matrix {
  matrix(a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: x, f: y)
}

/// Create a uniform scale matrix.
pub fn scale(factor factor: Float) -> Matrix {
  scale_xy(x: factor, y: factor)
}

/// Create a non-uniform scale matrix.
pub fn scale_xy(x x: Float, y y: Float) -> Matrix {
  matrix(a: x, b: 0.0, c: 0.0, d: y, e: 0.0, f: 0.0)
}

/// Create a rotation matrix from an angle in degrees.
pub fn rotate(degrees degrees: Float) -> Matrix {
  let radians = degrees_to_radians(degrees)
  let cosine = maths.cos(radians)
  let sine = maths.sin(radians)

  matrix(a: cosine, b: sine, c: 0.0 -. sine, d: cosine, e: 0.0, f: 0.0)
}

/// Create an x-axis skew matrix from an angle in degrees.
pub fn skew_x(degrees degrees: Float) -> Matrix {
  matrix(
    a: 1.0,
    b: 0.0,
    c: maths.tan(degrees_to_radians(degrees)),
    d: 1.0,
    e: 0.0,
    f: 0.0,
  )
}

/// Create a y-axis skew matrix from an angle in degrees.
pub fn skew_y(degrees degrees: Float) -> Matrix {
  matrix(
    a: 1.0,
    b: maths.tan(degrees_to_radians(degrees)),
    c: 0.0,
    d: 1.0,
    e: 0.0,
    f: 0.0,
  )
}

/// Return SVG's six matrix values as `#(a, b, c, d, e, f)`.
pub fn to_tuple(
  transform: Matrix,
) -> #(Float, Float, Float, Float, Float, Float) {
  #(
    transform.a,
    transform.b,
    transform.c,
    transform.d,
    transform.e,
    transform.f,
  )
}

/// Transform a point by a matrix.
pub fn point(point: svg_path.Point, by transform: Matrix) -> svg_path.Point {
  svg_path.point(
    transform.a *. point.x +. transform.c *. point.y +. transform.e,
    transform.b *. point.x +. transform.d *. point.y +. transform.f,
  )
}

/// Translate a point.
pub fn translate_point(
  input: svg_path.Point,
  x x: Float,
  y y: Float,
) -> svg_path.Point {
  point(input, by: translate(x:, y:))
}

/// Scale a point uniformly.
pub fn scale_point(
  input: svg_path.Point,
  factor factor: Float,
) -> svg_path.Point {
  point(input, by: scale(factor:))
}

/// Scale a point non-uniformly.
pub fn scale_xy_point(
  input: svg_path.Point,
  x x: Float,
  y y: Float,
) -> svg_path.Point {
  point(input, by: scale_xy(x:, y:))
}

/// Rotate a point around the origin.
pub fn rotate_point(
  input: svg_path.Point,
  degrees degrees: Float,
) -> svg_path.Point {
  point(input, by: rotate(degrees:))
}

/// Skew a point along the x axis.
pub fn skew_x_point(
  input: svg_path.Point,
  degrees degrees: Float,
) -> svg_path.Point {
  point(input, by: skew_x(degrees:))
}

/// Skew a point along the y axis.
pub fn skew_y_point(
  input: svg_path.Point,
  degrees degrees: Float,
) -> svg_path.Point {
  point(input, by: skew_y(degrees:))
}

/// Transform a segment by a matrix.
///
/// Degenerate arc transforms return `DegenerateArcTransform`; use
/// `segment_gracefully` or `segment_gracefully2` to convert collapsed arcs into
/// line-based representations when possible.
pub fn segment(
  segment: svg_path.Segment,
  by transform: Matrix,
) -> Result(svg_path.Segment, Error) {
  case validate_matrix(transform) {
    Error(error) -> Error(error)
    Ok(Nil) -> transform_valid_segment(segment, transform)
  }
}

/// Transform a segment about a point.
pub fn segment_about_point(
  input: svg_path.Segment,
  by transform: Matrix,
  point point: svg_path.Point,
) -> Result(svg_path.Segment, Error) {
  segment(input, by: about_point(transform, point:))
}

/// Transform a segment about an anchor on its bounding box.
pub fn segment_about_anchor(
  input: svg_path.Segment,
  by transform: Matrix,
  anchor anchor: Anchor,
) -> Result(svg_path.Segment, Error) {
  case svg_path.segment_bounding_box(input) {
    Error(error) -> Error(Core(error))
    Ok(box) ->
      segment_about_point(
        input,
        by: transform,
        point: anchor_point(box, anchor),
      )
  }
}

/// Translate a segment.
pub fn translate_segment(
  input: svg_path.Segment,
  x x: Float,
  y y: Float,
) -> Result(svg_path.Segment, Error) {
  segment(input, by: translate(x:, y:))
}

/// Scale a segment uniformly.
pub fn scale_segment(
  input: svg_path.Segment,
  factor factor: Float,
) -> Result(svg_path.Segment, Error) {
  segment(input, by: scale(factor:))
}

/// Scale a segment non-uniformly.
pub fn scale_xy_segment(
  input: svg_path.Segment,
  x x: Float,
  y y: Float,
) -> Result(svg_path.Segment, Error) {
  segment(input, by: scale_xy(x:, y:))
}

/// Rotate a segment around the origin.
pub fn rotate_segment(
  input: svg_path.Segment,
  degrees degrees: Float,
) -> Result(svg_path.Segment, Error) {
  segment(input, by: rotate(degrees:))
}

/// Skew a segment along the x axis.
pub fn skew_x_segment(
  input: svg_path.Segment,
  degrees degrees: Float,
) -> Result(svg_path.Segment, Error) {
  segment(input, by: skew_x(degrees:))
}

/// Skew a segment along the y axis.
pub fn skew_y_segment(
  input: svg_path.Segment,
  degrees degrees: Float,
) -> Result(svg_path.Segment, Error) {
  segment(input, by: skew_y(degrees:))
}

/// Transform a segment, converting collapsed arcs into lines when possible.
///
/// This returns a single segment. If a collapsed arc needs multiple line
/// segments to preserve its motion, use `segment_gracefully2`.
pub fn segment_gracefully(
  input: svg_path.Segment,
  by transform: Matrix,
) -> Result(svg_path.Segment, Error) {
  case segment(input, by: transform) {
    Ok(segment) -> Ok(segment)
    Error(DegenerateArcTransform) -> {
      case input {
        svg_path.Arc(
          start:,
          radius:,
          x_axis_rotation:,
          large_arc:,
          sweep:,
          end:,
        ) -> {
          case
            ellipse.collapsed_arc_line(
              start: to_ellipse_point(start),
              radius: to_ellipse_point(radius),
              x_axis_rotation:,
              large_arc:,
              sweep:,
              end: to_ellipse_point(end),
              by: affine(transform),
            )
          {
            Ok(line) -> {
              let #(start, end) = line
              Ok(svg_path.Line(
                start: from_ellipse_point(start),
                end: from_ellipse_point(end),
              ))
            }
            Error(_) -> Error(DegenerateArcTransform)
          }
        }
        _ -> Error(DegenerateArcTransform)
      }
    }
    Error(error) -> Error(error)
  }
}

/// Transform a segment, returning a subpath for graceful collapsed arc handling.
///
/// This can represent collapsed arcs as multiple line segments when needed.
pub fn segment_gracefully2(
  input: svg_path.Segment,
  by transform: Matrix,
) -> Result(svg_path.Subpath, Error) {
  case segment(input, by: transform) {
    Ok(segment) -> svg_path.subpath([segment]) |> map_core_error
    Error(DegenerateArcTransform) -> {
      case input {
        svg_path.Arc(
          start:,
          radius:,
          x_axis_rotation:,
          large_arc:,
          sweep:,
          end:,
        ) -> {
          case
            ellipse.collapsed_arc_subpath(
              start: to_ellipse_point(start),
              radius: to_ellipse_point(radius),
              x_axis_rotation:,
              large_arc:,
              sweep:,
              end: to_ellipse_point(end),
              by: affine(transform),
            )
          {
            Ok(points) -> {
              svg_path.subpath(lines_between(points)) |> map_core_error
            }
            Error(_) -> Error(DegenerateArcTransform)
          }
        }
        _ -> Error(DegenerateArcTransform)
      }
    }
    Error(error) -> Error(error)
  }
}

/// Transform a subpath by a matrix.
///
/// Closed subpaths remain semantically closed when the transformed endpoints can
/// be reconciled.
pub fn subpath(
  subpath: svg_path.Subpath,
  by transform: Matrix,
) -> Result(svg_path.Subpath, Error) {
  case validate_matrix(transform) {
    Error(error) -> Error(error)
    Ok(Nil) -> {
      case transform_segments(svg_path.segments(subpath), transform, []) {
        Error(error) -> Error(error)
        Ok(segments) ->
          finalize_transformed_subpath(subpath, segments, transform)
      }
    }
  }
}

/// Transform a subpath about a point.
pub fn subpath_about_point(
  input: svg_path.Subpath,
  by transform: Matrix,
  point point: svg_path.Point,
) -> Result(svg_path.Subpath, Error) {
  subpath(input, by: about_point(transform, point:))
}

/// Transform a subpath about an anchor on its bounding box.
pub fn subpath_about_anchor(
  input: svg_path.Subpath,
  by transform: Matrix,
  anchor anchor: Anchor,
) -> Result(svg_path.Subpath, Error) {
  case svg_path.subpath_bounding_box(input) {
    Error(error) -> Error(Core(error))
    Ok(box) ->
      subpath_about_point(
        input,
        by: transform,
        point: anchor_point(box, anchor),
      )
  }
}

/// Translate a subpath.
pub fn translate_subpath(
  input: svg_path.Subpath,
  x x: Float,
  y y: Float,
) -> Result(svg_path.Subpath, Error) {
  subpath(input, by: translate(x:, y:))
}

/// Scale a subpath uniformly.
pub fn scale_subpath(
  input: svg_path.Subpath,
  factor factor: Float,
) -> Result(svg_path.Subpath, Error) {
  subpath(input, by: scale(factor:))
}

/// Scale a subpath non-uniformly.
pub fn scale_xy_subpath(
  input: svg_path.Subpath,
  x x: Float,
  y y: Float,
) -> Result(svg_path.Subpath, Error) {
  subpath(input, by: scale_xy(x:, y:))
}

/// Rotate a subpath around the origin.
pub fn rotate_subpath(
  input: svg_path.Subpath,
  degrees degrees: Float,
) -> Result(svg_path.Subpath, Error) {
  subpath(input, by: rotate(degrees:))
}

/// Skew a subpath along the x axis.
pub fn skew_x_subpath(
  input: svg_path.Subpath,
  degrees degrees: Float,
) -> Result(svg_path.Subpath, Error) {
  subpath(input, by: skew_x(degrees:))
}

/// Skew a subpath along the y axis.
pub fn skew_y_subpath(
  input: svg_path.Subpath,
  degrees degrees: Float,
) -> Result(svg_path.Subpath, Error) {
  subpath(input, by: skew_y(degrees:))
}

/// Transform a subpath, gracefully converting collapsed arcs when possible.
///
/// This uses the core path wiggle helpers to preserve continuity after
/// collapsed arcs are converted to line-based subpaths.
pub fn subpath_gracefully(
  subpath: svg_path.Subpath,
  by transform: Matrix,
) -> Result(svg_path.Subpath, Error) {
  case validate_matrix(transform) {
    Error(error) -> Error(error)
    Ok(Nil) -> {
      case
        transform_segments_gracefully(svg_path.segments(subpath), transform, [])
      {
        Error(error) -> Error(error)
        Ok(segments) ->
          finalize_transformed_subpath(subpath, segments, transform)
      }
    }
  }
}

fn finalize_transformed_subpath(
  original: svg_path.Subpath,
  segments: List(svg_path.Segment),
  transform: Matrix,
) -> Result(svg_path.Subpath, Error) {
  let assert Ok(start) = svg_path.start(original)
  let start = point(start, transform)

  case segments {
    [] -> {
      let subpath = svg_path.empty_subpath(at: start)
      case svg_path.is_closed(original) {
        True -> svg_path.set_closed(subpath, closed: True) |> map_core_error
        False -> Ok(subpath)
      }
    }
    _ -> {
      case svg_path.subpath(segments) {
        Error(error) -> Error(Core(error))
        Ok(transformed) -> {
          case svg_path.is_closed(original) {
            True -> close_transformed_subpath(transformed)
            False -> Ok(transformed)
          }
        }
      }
    }
  }
}

/// Transform every subpath in a path by a matrix.
pub fn path(
  path: svg_path.Path,
  by transform: Matrix,
) -> Result(svg_path.Path, Error) {
  case validate_matrix(transform) {
    Error(error) -> Error(error)
    Ok(Nil) -> {
      case transform_subpaths(svg_path.subpaths(path), transform, []) {
        Error(error) -> Error(error)
        Ok(subpaths) -> Ok(svg_path.Path(subpaths))
      }
    }
  }
}

/// Transform a bounding box by a matrix.
///
/// The result is the smallest axis-aligned bounding box containing the
/// transformed corners of the input box.
pub fn bounding_box(
  box: svg_path.BoundingBox,
  by transform: Matrix,
) -> Result(svg_path.BoundingBox, Error) {
  case validate_matrix(transform) {
    Error(error) -> Error(error)
    Ok(Nil) -> {
      let svg_path.BoundingBox(min:, max:) = box
      let top_left = point(min, by: transform)
      let top_right = point(svg_path.point(max.x, min.y), by: transform)
      let bottom_left = point(svg_path.point(min.x, max.y), by: transform)
      let bottom_right = point(max, by: transform)

      let assert Ok(box) =
        svg_path.bounding_box_union_many([
          svg_path.BoundingBox(min: top_left, max: top_left),
          svg_path.BoundingBox(min: top_right, max: top_right),
          svg_path.BoundingBox(min: bottom_left, max: bottom_left),
          svg_path.BoundingBox(min: bottom_right, max: bottom_right),
        ])

      Ok(box)
    }
  }
}

/// Transform a path about a point.
pub fn path_about_point(
  input: svg_path.Path,
  by transform: Matrix,
  point point: svg_path.Point,
) -> Result(svg_path.Path, Error) {
  path(input, by: about_point(transform, point:))
}

/// Transform a path about an anchor on its bounding box.
pub fn path_about_anchor(
  input: svg_path.Path,
  by transform: Matrix,
  anchor anchor: Anchor,
) -> Result(svg_path.Path, Error) {
  case svg_path.path_bounding_box(input) {
    Error(error) -> Error(Core(error))
    Ok(box) ->
      path_about_point(input, by: transform, point: anchor_point(box, anchor))
  }
}

/// Translate a path.
pub fn translate_path(
  input: svg_path.Path,
  x x: Float,
  y y: Float,
) -> Result(svg_path.Path, Error) {
  path(input, by: translate(x:, y:))
}

/// Scale a path uniformly.
pub fn scale_path(
  input: svg_path.Path,
  factor factor: Float,
) -> Result(svg_path.Path, Error) {
  path(input, by: scale(factor:))
}

/// Scale a path non-uniformly.
pub fn scale_xy_path(
  input: svg_path.Path,
  x x: Float,
  y y: Float,
) -> Result(svg_path.Path, Error) {
  path(input, by: scale_xy(x:, y:))
}

/// Rotate a path around the origin.
pub fn rotate_path(
  input: svg_path.Path,
  degrees degrees: Float,
) -> Result(svg_path.Path, Error) {
  path(input, by: rotate(degrees:))
}

/// Skew a path along the x axis.
pub fn skew_x_path(
  input: svg_path.Path,
  degrees degrees: Float,
) -> Result(svg_path.Path, Error) {
  path(input, by: skew_x(degrees:))
}

/// Skew a path along the y axis.
pub fn skew_y_path(
  input: svg_path.Path,
  degrees degrees: Float,
) -> Result(svg_path.Path, Error) {
  path(input, by: skew_y(degrees:))
}

fn transform_valid_segment(
  segment: svg_path.Segment,
  transform: Matrix,
) -> Result(svg_path.Segment, Error) {
  case segment {
    svg_path.Line(start:, end:) -> {
      Ok(svg_path.Line(
        start: point(start, transform),
        end: point(end, transform),
      ))
    }
    svg_path.QuadraticBezier(start:, control:, end:) -> {
      Ok(svg_path.QuadraticBezier(
        start: point(start, transform),
        control: point(control, transform),
        end: point(end, transform),
      ))
    }
    svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      Ok(svg_path.CubicBezier(
        start: point(start, transform),
        control1: point(control1, transform),
        control2: point(control2, transform),
        end: point(end, transform),
      ))
    }
    svg_path.Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:) -> {
      case
        ellipse.transformed_axes(
          radius: to_ellipse_point(radius),
          x_axis_rotation:,
          by: affine(transform),
        )
      {
        Error(_) -> Error(DegenerateArcTransform)
        Ok(#(radius, x_axis_rotation)) -> {
          Ok(svg_path.Arc(
            start: point(start, transform),
            radius: from_ellipse_point(radius),
            x_axis_rotation: x_axis_rotation,
            large_arc: large_arc,
            sweep: transformed_sweep(sweep, transform),
            end: point(end, transform),
          ))
        }
      }
    }
  }
}

fn validate_matrix(transform: Matrix) -> Result(Nil, Error) {
  case
    is_finite(transform.a)
    && is_finite(transform.b)
    && is_finite(transform.c)
    && is_finite(transform.d)
    && is_finite(transform.e)
    && is_finite(transform.f)
  {
    True -> Ok(Nil)
    False -> Error(InvalidMatrix)
  }
}

fn map_core_error(
  result: Result(svg_path.Subpath, svg_path.Error),
) -> Result(svg_path.Subpath, Error) {
  case result {
    Ok(subpath) -> Ok(subpath)
    Error(error) -> Error(Core(error))
  }
}

fn anchor_point(box: svg_path.BoundingBox, anchor: Anchor) -> svg_path.Point {
  let svg_path.BoundingBox(min:, max:) = box
  let center = svg_path.bounding_box_center(box)

  case anchor {
    TopLeft -> min
    TopCenter -> svg_path.point(center.x, min.y)
    TopRight -> svg_path.point(max.x, min.y)
    CenterLeft -> svg_path.point(min.x, center.y)
    Center -> center
    CenterRight -> svg_path.point(max.x, center.y)
    BottomLeft -> svg_path.point(min.x, max.y)
    BottomCenter -> svg_path.point(center.x, max.y)
    BottomRight -> max
  }
}

fn affine(transform: Matrix) -> ellipse.Affine {
  ellipse.ellipse_affine(
    a: transform.a,
    b: transform.b,
    c: transform.c,
    d: transform.d,
    e: transform.e,
    f: transform.f,
  )
}

fn to_ellipse_point(point: svg_path.Point) -> ellipse.Point {
  ellipse.Point(point.x, point.y)
}

fn from_ellipse_point(point: ellipse.Point) -> svg_path.Point {
  svg_path.point(point.x, point.y)
}

fn lines_between(points: List(ellipse.Point)) -> List(svg_path.Segment) {
  case points {
    [] | [_] -> []
    [first, second, ..rest] -> {
      lines_between_rest(second, rest, [
        svg_path.Line(
          start: from_ellipse_point(first),
          end: from_ellipse_point(second),
        ),
      ])
    }
  }
}

fn lines_between_rest(
  previous: ellipse.Point,
  points: List(ellipse.Point),
  lines: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case points {
    [] -> list.reverse(lines)
    [first, ..rest] -> {
      lines_between_rest(first, rest, [
        svg_path.Line(
          start: from_ellipse_point(previous),
          end: from_ellipse_point(first),
        ),
        ..lines
      ])
    }
  }
}

fn is_finite(value: Float) -> Bool {
  !is_nan(value -. value)
}

fn is_nan(value: Float) -> Bool {
  !{ value <. 0.0 || value >=. 0.0 }
}

fn transform_segments(
  segments: List(svg_path.Segment),
  transform: Matrix,
  transformed: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), Error) {
  case segments {
    [] -> Ok(list.reverse(transformed))
    [first, ..rest] -> {
      case segment(first, by: transform) {
        Error(error) -> Error(error)
        Ok(first) -> transform_segments(rest, transform, [first, ..transformed])
      }
    }
  }
}

fn transform_segments_gracefully(
  segments: List(svg_path.Segment),
  transform: Matrix,
  transformed: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), Error) {
  case segments {
    [] -> Ok(list.reverse(transformed))
    [first, ..rest] -> {
      case segment_gracefully2(first, by: transform) {
        Error(error) -> Error(error)
        Ok(first) -> {
          let transformed =
            prepend_all(svg_path.segments(first), to: transformed)
          transform_segments_gracefully(rest, transform, transformed)
        }
      }
    }
  }
}

fn prepend_all(
  segments: List(svg_path.Segment),
  to transformed: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case segments {
    [] -> transformed
    [first, ..rest] -> prepend_all(rest, to: [first, ..transformed])
  }
}

fn transform_subpaths(
  subpaths: List(svg_path.Subpath),
  transform: Matrix,
  transformed: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(transformed))
    [first, ..rest] -> {
      case subpath(first, by: transform) {
        Error(error) -> Error(error)
        Ok(first) -> transform_subpaths(rest, transform, [first, ..transformed])
      }
    }
  }
}

fn close_transformed_subpath(
  subpath: svg_path.Subpath,
) -> Result(svg_path.Subpath, Error) {
  case svg_path.set_closed(subpath, closed: True) {
    Ok(subpath) -> Ok(subpath)
    Error(_) -> {
      case
        svg_path.set_closed_with(subpath, closed: True, policy: svg_path.Wiggle)
      {
        Ok(subpath) -> Ok(subpath)
        Error(error) -> Error(Core(error))
      }
    }
  }
}

fn transformed_sweep(sweep: Bool, transform: Matrix) -> Bool {
  case determinant(transform) <. 0.0 {
    True -> !sweep
    False -> sweep
  }
}

fn determinant(transform: Matrix) -> Float {
  transform.a *. transform.d -. transform.b *. transform.c
}

fn degrees_to_radians(degrees: Float) -> Float {
  degrees *. maths.pi() /. 180.0
}
