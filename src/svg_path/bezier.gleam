//// Lower-level helpers for Bezier curves.
////
//// Most users should work with `svg_path.Line`, `svg_path.QuadraticBezier`,
//// and `svg_path.CubicBezier` values through the root module. This module is
//// the more technical layer for users who want the curve math behind line and
//// Bezier segments.
////
//// A line segment is a degree-1 Bezier curve, a quadratic Bezier has one
//// control point, and a cubic Bezier has two control points. All evaluation
//// and splitting helpers use the standard Bezier parameter `t`:
////
//// - `bezier_point(curve, at: 0.0)` is the curve start point.
//// - `bezier_point(curve, at: 1.0)` is the curve end point.
//// - `bezier_derivative(curve, at: t)` is the derivative with respect to `t`.
//// - `split_bezier(curve, at: t)` preserves the curve degree and divides it
////   with de Casteljau's algorithm.
//// - `map_points(curve, with: f)` maps the curve's defining points.
////
//// The `at` value is not clamped. Values outside `0.0..1.0` extrapolate along
//// the same polynomial curve. `split_bezier` follows the same unclamped policy;
//// use `split_bezier_inside` when outside values should return an error.
//// `split_bezier_many` and `split_bezier_inside_many` sort their split points,
//// remove exact duplicates, and trim boundary `0.0` or `1.0` split points that
//// would only create zero-length boundary curves.
////
//// `map_points` maps the control points that define the curve. For nonlinear
//// functions, this is not the exact image of every point on the rendered curve;
//// it is the Bezier curve obtained by applying the function to the defining
//// points.

import gleam/float
import gleam/list

const root_tolerance = 0.000000001

/// A lightweight point used by the Bezier math helpers.
pub type Point {
  Point(x: Float, y: Float)
}

/// An axis-aligned bounding box for a Bezier curve.
pub type BoundingBox {
  BoundingBox(min: Point, max: Point)
}

/// Bezier-parameter representation of line, quadratic, and cubic curves.
pub type BezierData {
  /// A degree-1 Bezier curve.
  LinearBezierData(start: Point, end: Point)

  /// A degree-2 Bezier curve.
  QuadraticBezierData(start: Point, control: Point, end: Point)

  /// A degree-3 Bezier curve.
  CubicBezierData(start: Point, control1: Point, control2: Point, end: Point)
}

/// Errors returned by Bezier helpers.
pub type Error {
  /// The requested split point is outside the curve's `0.0..1.0` parameter range.
  SplitOutsideBezier
}

/// Return the curve's start point.
pub fn bezier_start(curve: BezierData) -> Point {
  case curve {
    LinearBezierData(start:, ..)
    | QuadraticBezierData(start:, ..)
    | CubicBezierData(start:, ..) -> start
  }
}

/// Return the curve's end point.
pub fn bezier_end(curve: BezierData) -> Point {
  case curve {
    LinearBezierData(end:, ..)
    | QuadraticBezierData(end:, ..)
    | CubicBezierData(end:, ..) -> end
  }
}

/// Evaluate a Bezier curve at parameter `t`.
///
/// `t` is not clamped. `0.0` evaluates the start of the curve, `1.0` evaluates
/// the end of the curve, and values outside that range extrapolate along the
/// same polynomial curve.
pub fn bezier_point(curve: BezierData, at t: Float) -> Point {
  case curve {
    LinearBezierData(start:, end:) -> interpolate(start, end, t)
    QuadraticBezierData(start:, control:, end:) -> {
      interpolate(
        interpolate(start, control, t),
        interpolate(control, end, t),
        t,
      )
    }
    CubicBezierData(start:, control1:, control2:, end:) -> {
      let left = interpolate(start, control1, t)
      let middle = interpolate(control1, control2, t)
      let right = interpolate(control2, end, t)

      interpolate(
        interpolate(left, middle, t),
        interpolate(middle, right, t),
        t,
      )
    }
  }
}

/// Return the derivative with respect to Bezier parameter `t`.
pub fn bezier_derivative(curve: BezierData, at t: Float) -> Point {
  case curve {
    LinearBezierData(start:, end:) -> difference(end, start)
    QuadraticBezierData(start:, control:, end:) -> {
      scale(
        interpolate(difference(control, start), difference(end, control), t),
        2.0,
      )
    }
    CubicBezierData(start:, control1:, control2:, end:) -> {
      let left = difference(control1, start)
      let middle = difference(control2, control1)
      let right = difference(end, control2)

      scale(
        interpolate(
          interpolate(left, middle, t),
          interpolate(middle, right, t),
          t,
        ),
        3.0,
      )
    }
  }
}

/// Return the curve's exact axis-aligned bounding box over `0.0..1.0`.
pub fn bezier_bounding_box(curve: BezierData) -> BoundingBox {
  let points =
    [0.0, 1.0, ..bezier_extrema(curve)]
    |> list.map(fn(t) { bezier_point(curve, at: t) })

  let assert [first, ..rest] = points

  rest
  |> list.fold(BoundingBox(min: first, max: first), include_point)
}

/// Map a Bezier curve's defining points.
///
/// For nonlinear functions, this is not the exact image of every point on the
/// rendered curve. It maps the control polygon and preserves the curve degree.
pub fn map_points(curve: BezierData, with f: fn(Point) -> Point) -> BezierData {
  case curve {
    LinearBezierData(start:, end:) -> {
      LinearBezierData(start: f(start), end: f(end))
    }
    QuadraticBezierData(start:, control:, end:) -> {
      QuadraticBezierData(start: f(start), control: f(control), end: f(end))
    }
    CubicBezierData(start:, control1:, control2:, end:) -> {
      CubicBezierData(
        start: f(start),
        control1: f(control1),
        control2: f(control2),
        end: f(end),
      )
    }
  }
}

/// Split a Bezier curve at parameter `t`.
///
/// `t` is not clamped. Values outside `0.0..1.0` extrapolate along the same
/// polynomial curve, matching `bezier_point`.
pub fn split_bezier(
  curve: BezierData,
  at t: Float,
) -> #(BezierData, BezierData) {
  case curve {
    LinearBezierData(start:, end:) -> {
      let split = interpolate(start, end, t)

      #(
        LinearBezierData(start:, end: split),
        LinearBezierData(start: split, end:),
      )
    }
    QuadraticBezierData(start:, control:, end:) -> {
      let start_control = interpolate(start, control, t)
      let control_end = interpolate(control, end, t)
      let split = interpolate(start_control, control_end, t)

      #(
        QuadraticBezierData(start:, control: start_control, end: split),
        QuadraticBezierData(start: split, control: control_end, end:),
      )
    }
    CubicBezierData(start:, control1:, control2:, end:) -> {
      let start_control = interpolate(start, control1, t)
      let controls = interpolate(control1, control2, t)
      let control_end = interpolate(control2, end, t)
      let left_control = interpolate(start_control, controls, t)
      let right_control = interpolate(controls, control_end, t)
      let split = interpolate(left_control, right_control, t)

      #(
        CubicBezierData(
          start:,
          control1: start_control,
          control2: left_control,
          end: split,
        ),
        CubicBezierData(
          start: split,
          control1: right_control,
          control2: control_end,
          end:,
        ),
      )
    }
  }
}

/// Split a Bezier curve at parameter `t`, returning an error outside `0.0..1.0`.
///
/// Values exactly at `0.0` or `1.0` are accepted and produce one zero-length
/// curve.
pub fn split_bezier_inside(
  curve: BezierData,
  at t: Float,
) -> Result(#(BezierData, BezierData), Error) {
  case t <. 0.0 || t >. 1.0 {
    True -> Error(SplitOutsideBezier)
    False -> Ok(split_bezier(curve, at: t))
  }
}

/// Split a Bezier curve at multiple parameter values.
///
/// Split points are sorted, exact duplicates are removed, and boundary `0.0`
/// or `1.0` split points are trimmed when they would only create zero-length
/// boundary curves. Values outside `0.0..1.0` are allowed and extrapolate along
/// the same polynomial curve, matching `split_bezier`.
pub fn split_bezier_many(
  curve: BezierData,
  at points: List(Float),
) -> List(BezierData) {
  split_bezier_at_progresses(curve, normalized_progresses(points))
}

/// Split a Bezier curve at multiple parameter values, erroring outside `0.0..1.0`.
///
/// Split points are sorted, exact duplicates are removed, and boundary `0.0`
/// or `1.0` split points are trimmed when they would only create zero-length
/// boundary curves. Values exactly at `0.0` or `1.0` are accepted.
pub fn split_bezier_inside_many(
  curve: BezierData,
  at points: List(Float),
) -> Result(List(BezierData), Error) {
  let points = normalized_progresses(points)

  case list.any(points, fn(t) { t <. 0.0 || t >. 1.0 }) {
    True -> Error(SplitOutsideBezier)
    False -> Ok(split_bezier_at_progresses(curve, points))
  }
}

/// Return the Bezier parameters of a cubic curve's inflection points.
///
/// A cubic Bezier can have up to two inflection points. Values outside
/// `0.0..1.0`, values too close to the endpoints, and numerically duplicate
/// roots are not returned. Splitting at these parameters gives pieces with no
/// interior inflection, which is often the useful first step before treating
/// each piece as a convex curve plus its chord. Linear and quadratic curves
/// return an empty list.
pub fn cubic_inflection_parameters(curve: BezierData) -> List(Float) {
  case curve {
    CubicBezierData(start:, control1:, control2:, end:) ->
      inflection_roots(start, control1, control2, end)
      |> list.filter(fn(t) { t >. root_tolerance && t <. 1.0 -. root_tolerance })
      |> sort_unique_close_progresses
    LinearBezierData(..) | QuadraticBezierData(..) -> []
  }
}

fn split_bezier_at_progresses(
  curve: BezierData,
  points: List(Float),
) -> List(BezierData) {
  split_bezier_between_progresses(curve, previous: 0.0, points:, pieces: [])
}

fn split_bezier_between_progresses(
  curve: BezierData,
  previous previous: Float,
  points points: List(Float),
  pieces pieces: List(BezierData),
) -> List(BezierData) {
  case points {
    [] ->
      list.reverse([bezier_between(curve, from: previous, to: 1.0), ..pieces])
    [next, ..rest] -> {
      split_bezier_between_progresses(
        curve,
        previous: next,
        points: rest,
        pieces: [bezier_between(curve, from: previous, to: next), ..pieces],
      )
    }
  }
}

fn bezier_between(
  curve: BezierData,
  from from: Float,
  to to: Float,
) -> BezierData {
  let start = bezier_point(curve, at: from)
  let end = bezier_point(curve, at: to)
  let delta = to -. from

  case curve {
    LinearBezierData(..) -> LinearBezierData(start:, end:)
    QuadraticBezierData(..) -> {
      QuadraticBezierData(
        start:,
        control: offset(start, bezier_derivative(curve, at: from), delta /. 2.0),
        end:,
      )
    }
    CubicBezierData(..) -> {
      CubicBezierData(
        start:,
        control1: offset(
          start,
          bezier_derivative(curve, at: from),
          delta /. 3.0,
        ),
        control2: offset(
          end,
          bezier_derivative(curve, at: to),
          0.0 -. delta /. 3.0,
        ),
        end:,
      )
    }
  }
}

fn normalized_progresses(points: List(Float)) -> List(Float) {
  points
  |> sort_unique_progresses
  |> trim_start_progress
  |> trim_end_progress
}

fn bezier_extrema(curve: BezierData) -> List(Float) {
  case curve {
    LinearBezierData(..) -> []
    QuadraticBezierData(start:, control:, end:) ->
      list.append(
        quadratic_extrema(start.x, control.x, end.x),
        quadratic_extrema(start.y, control.y, end.y),
      )
    CubicBezierData(start:, control1:, control2:, end:) ->
      list.append(
        cubic_extrema(start.x, control1.x, control2.x, end.x),
        cubic_extrema(start.y, control1.y, control2.y, end.y),
      )
  }
  |> list.filter(is_inside_unit_interval)
}

fn quadratic_extrema(start: Float, control: Float, end: Float) -> List(Float) {
  let denominator = start -. { 2.0 *. control } +. end

  case denominator == 0.0 {
    True -> []
    False -> [{ start -. control } /. denominator]
  }
}

fn cubic_extrema(
  start: Float,
  control1: Float,
  control2: Float,
  end: Float,
) -> List(Float) {
  let a = 0.0 -. start +. { 3.0 *. control1 } -. { 3.0 *. control2 } +. end
  let b = { 3.0 *. start } -. { 6.0 *. control1 } +. { 3.0 *. control2 }
  let c = { 3.0 *. control1 } -. { 3.0 *. start }

  quadratic_roots(3.0 *. a, 2.0 *. b, c)
}

fn inflection_roots(
  start: Point,
  control1: Point,
  control2: Point,
  end: Point,
) -> List(Float) {
  let a =
    add(
      difference(scale(control1, 3.0), start),
      difference(end, scale(control2, 3.0)),
    )
  let b =
    add(
      difference(scale(start, 3.0), scale(control1, 6.0)),
      scale(control2, 3.0),
    )
  let c = difference(scale(control1, 3.0), scale(start, 3.0))

  tolerant_quadratic_roots(
    -6.0 *. cross(a, b),
    6.0 *. cross(c, a),
    2.0 *. cross(c, b),
  )
}

fn quadratic_roots(a: Float, b: Float, c: Float) -> List(Float) {
  case a == 0.0 {
    True -> linear_roots(b, c)
    False -> {
      let discriminant = b *. b -. { 4.0 *. a *. c }

      case discriminant <. 0.0 {
        True -> []
        False -> {
          let assert Ok(root_discriminant) = float.square_root(discriminant)
          let denominator = 2.0 *. a

          case root_discriminant == 0.0 {
            True -> [{ 0.0 -. b } /. denominator]
            False -> [
              { 0.0 -. b -. root_discriminant } /. denominator,
              { 0.0 -. b +. root_discriminant } /. denominator,
            ]
          }
        }
      }
    }
  }
}

fn tolerant_quadratic_roots(a: Float, b: Float, c: Float) -> List(Float) {
  case float.absolute_value(a) <. 0.000000000001 {
    True -> {
      case float.absolute_value(b) <. 0.000000000001 {
        True -> []
        False -> [{ 0.0 -. c } /. b]
      }
    }
    False -> {
      let discriminant = b *. b -. { 4.0 *. a *. c }

      case discriminant <. 0.0 {
        True -> []
        False -> {
          let assert Ok(root_discriminant) = float.square_root(discriminant)
          let denominator = 2.0 *. a

          [
            { 0.0 -. b -. root_discriminant } /. denominator,
            { 0.0 -. b +. root_discriminant } /. denominator,
          ]
        }
      }
    }
  }
}

fn linear_roots(a: Float, b: Float) -> List(Float) {
  case a == 0.0 {
    True -> []
    False -> [{ 0.0 -. b } /. a]
  }
}

fn is_inside_unit_interval(t: Float) -> Bool {
  t >=. 0.0 && t <=. 1.0
}

fn include_point(box: BoundingBox, point: Point) -> BoundingBox {
  BoundingBox(
    min: Point(float.min(box.min.x, point.x), float.min(box.min.y, point.y)),
    max: Point(float.max(box.max.x, point.x), float.max(box.max.y, point.y)),
  )
}

fn sort_unique_progresses(points: List(Float)) -> List(Float) {
  case points {
    [] -> []
    [first, ..rest] ->
      sort_unique_progresses(rest) |> insert_unique_progress(first)
  }
}

fn sort_unique_close_progresses(points: List(Float)) -> List(Float) {
  case list.sort(points, by: float.compare) {
    [] -> []
    [first, ..rest] ->
      unique_close_progresses(rest, previous: first, kept: [first])
      |> list.reverse
  }
}

fn unique_close_progresses(
  points: List(Float),
  previous previous: Float,
  kept kept: List(Float),
) -> List(Float) {
  case points {
    [] -> kept
    [point, ..rest] -> {
      case float.absolute_value(point -. previous) <=. root_tolerance {
        True -> unique_close_progresses(rest, previous:, kept:)
        False ->
          unique_close_progresses(rest, previous: point, kept: [point, ..kept])
      }
    }
  }
}

fn trim_start_progress(points: List(Float)) -> List(Float) {
  case points {
    [0.0, ..rest] -> trim_start_progress(rest)
    _ -> points
  }
}

fn trim_end_progress(points: List(Float)) -> List(Float) {
  points
  |> list.reverse
  |> trim_reversed_end_progress
  |> list.reverse
}

fn trim_reversed_end_progress(points: List(Float)) -> List(Float) {
  case points {
    [1.0, ..rest] -> trim_reversed_end_progress(rest)
    _ -> points
  }
}

fn insert_unique_progress(sorted: List(Float), point: Float) -> List(Float) {
  case sorted {
    [] -> [point]
    [first, ..rest] -> {
      case point == first {
        True -> sorted
        False -> {
          case point <=. first {
            True -> [point, ..sorted]
            False -> [first, ..insert_unique_progress(rest, point)]
          }
        }
      }
    }
  }
}

fn interpolate(start: Point, end: Point, t: Float) -> Point {
  Point(
    start.x +. { end.x -. start.x } *. t,
    start.y +. { end.y -. start.y } *. t,
  )
}

fn difference(left: Point, right: Point) -> Point {
  Point(left.x -. right.x, left.y -. right.y)
}

fn add(left: Point, right: Point) -> Point {
  Point(left.x +. right.x, left.y +. right.y)
}

fn scale(point: Point, factor: Float) -> Point {
  Point(point.x *. factor, point.y *. factor)
}

fn offset(point: Point, direction: Point, distance: Float) -> Point {
  Point(point.x +. direction.x *. distance, point.y +. direction.y *. distance)
}

fn cross(left: Point, right: Point) -> Float {
  left.x *. right.y -. left.y *. right.x
}
