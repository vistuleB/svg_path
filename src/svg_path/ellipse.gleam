//// Lower-level helpers for SVG elliptical arcs.
////
//// Most users should work with `svg_path.Arc` values through the root module.
//// This module is the more technical layer for users who want the ellipse math
//// behind SVG arcs.
////
//// SVG path data uses endpoint parameterization for elliptical arcs,
//// represented here by `EndpointArcData`. An `A` command stores the current
//// point, an end point, two radii, an `x_axis_rotation`, a `large_arc` flag,
//// and a `sweep` flag. The radii are the ellipse's semi-axes.
//// `x_axis_rotation` is the angle, in degrees, from the current coordinate
//// system's x-axis to the ellipse's x-axis. The `large_arc` flag selects an
//// arc spanning more than 180 degrees when it is `True`, and an arc spanning
//// at most 180 degrees when it is `False`. The `sweep` flag selects increasing
//// ellipse angles when it is `True`, and decreasing ellipse angles when it is
//// `False`.
////
//// This endpoint form is compact and fits SVG paths nicely, but it is not the
//// most convenient form for evaluation, splitting, or analysis. SVG's
//// implementation notes also define center parameterization, represented here
//// by `CenterArcData`: an ellipse `center`, a corrected `radius`, the same
//// `x_axis_rotation`, a `start_angle`, and a signed `delta_angle`.
////
//// `endpoint_to_center` converts `EndpointArcData` into `CenterArcData`. It
//// follows SVG's forgiving radius rules: radii are made
//// positive, and if the requested ellipse is too small to connect the
//// endpoints, both radii are scaled up uniformly until there is exactly one
//// solution. `CenterArcData.radius` is therefore the corrected radius, not
//// necessarily the input radius.
////
//// All public angles are in degrees because SVG path data uses degrees.
//// `start_angle` is the angle before the ellipse is stretched and rotated.
//// `delta_angle` is the signed angular travel from the start point to the end
//// point.
////
//// For values returned by `endpoint_to_center`, these invariants hold:
////
//// - `arc_sweep(arc)` is `True` when `delta_angle >= 0.0`.
//// - `arc_large_arc(arc)` is `True` when `abs(delta_angle) > 180`.
//// - `arc_end_angle(arc) == arc.start_angle + arc.delta_angle`.
//// - `arc_point(arc, at: 0.0)` is the arc start point, modulo floating-point
////   roundoff.
//// - `arc_point(arc, at: 1.0)` is the arc end point, modulo floating-point
////   roundoff.
//// - `split_arc(arc, at: t)` preserves `center`, `radius`, and
////   `x_axis_rotation`, and divides `delta_angle` at angular progress `t`.
////
//// The public `CenterArcData` constructor is intentionally available for
//// advanced callers. The invariants above are guaranteed for values produced by
//// `endpoint_to_center`; if you construct `CenterArcData` yourself, these
//// helpers will use the values you provide without trying to repair them.
////
//// Evaluation with `arc_point(arc, at: t)` uses angular progress through
//// `CenterArcData`:
////
//// ```gleam
//// angle = arc.start_angle +. t *. arc.delta_angle
//// ```
////
//// This is not arc-length parameterization. Equal `t` steps correspond to
//// equal angle steps in the unstretched ellipse coordinate system, not equal
//// distances along the rendered curve. The `at` value is not clamped; values
//// outside `0.0..1.0` extrapolate along the same ellipse. `split_arc` follows
//// the same unclamped policy; use `split_arc_inside` when outside values should
//// return an error. `split_arc_many` and `split_arc_inside_many` sort their
//// split points, remove exact duplicates, and trim boundary `0.0` or `1.0`
//// split points that would only create zero-length boundary arcs.

import gleam/float
import gleam/list
import svg_path/trig

const epsilon = 0.000000001

const quarter_turn = 90.0

const half_turn = 180.0

const full_turn = 360.0

/// A lightweight point used by the ellipse math helpers.
pub type Point {
  Point(x: Float, y: Float)
}

/// An axis-aligned bounding box for an elliptical arc.
pub type BoundingBox {
  BoundingBox(min: Point, max: Point)
}

/// Endpoint-parameter representation of an SVG elliptical arc.
///
/// This is the same shape as an SVG `A` path command plus its explicit start
/// point. `radius` values are not corrected until conversion to `CenterArcData`.
pub type EndpointArcData {
  EndpointArcData(
    start: Point,
    radius: Point,
    x_axis_rotation: Float,
    large_arc: Bool,
    sweep: Bool,
    end: Point,
  )
}

/// Center-parameter representation of an SVG elliptical arc.
///
/// Values returned by `endpoint_to_center` use corrected positive radii and a
/// sweep-consistent `delta_angle`. The constructor is public for advanced
/// callers; hand-constructed values are not normalized or repaired by this
/// module.
pub type CenterArcData {
  CenterArcData(
    center: Point,
    radius: Point,
    x_axis_rotation: Float,
    start_angle: Float,
    delta_angle: Float,
  )
}

/// A cubic Bezier curve produced by the ellipse math helpers.
pub type Cubic {
  Cubic(start: Point, control1: Point, control2: Point, end: Point)
}

/// Equivalent of `transform.Matrix`, redefined by the ellipse module to avoid
/// a circular dependency.
///
/// Has the same six-value layout as SVG `matrix(a b c d e f)`.
pub opaque type Affine {
  Affine(a: Float, b: Float, c: Float, d: Float, e: Float, f: Float)
}

/// Errors returned by ellipse and collapsed-arc helpers.
pub type Error {
  /// The source arc cannot be converted to center-parameter form.
  DegenerateInputArc

  /// The transformed arc did not collapse to a line.
  NotCollapsedToLine

  /// The requested split point is outside the arc's `0.0..1.0` parameter range.
  SplitOutsideArc
}

/// Create an affine matrix for ellipse helpers.
pub fn ellipse_affine(
  a a: Float,
  b b: Float,
  c c: Float,
  d d: Float,
  e e: Float,
  f f: Float,
) -> Affine {
  Affine(a:, b:, c:, d:, e:, f:)
}

/// Transform a point by an affine matrix.
pub fn point(point: Point, by transform: Affine) -> Point {
  Point(
    transform.a *. point.x +. transform.c *. point.y +. transform.e,
    transform.b *. point.x +. transform.d *. point.y +. transform.f,
  )
}

/// Transform an arc's radius and x-axis rotation.
///
/// Returns the new radius and x-axis rotation for the transformed ellipse.
pub fn transformed_axes(
  radius radius: Point,
  x_axis_rotation x_axis_rotation: Float,
  by transform: Affine,
) -> Result(#(Point, Float), Error) {
  case arc_axes(radius, x_axis_rotation) {
    Error(error) -> Error(error)
    Ok(#(x_axis, y_axis)) -> {
      let x_axis = linear_point(x_axis, transform)
      let y_axis = linear_point(y_axis, transform)

      extract_axes(x_axis, y_axis)
    }
  }
}

/// Convert an arc collapsed by an affine transform into a single line segment.
///
/// If the collapsed arc's extrema require more than one segment to preserve its
/// out-and-back motion, use `collapsed_arc_subpath`.
pub fn collapsed_arc_line(
  start start: Point,
  radius radius: Point,
  x_axis_rotation x_axis_rotation: Float,
  large_arc large_arc: Bool,
  sweep sweep: Bool,
  end end: Point,
  by transform: Affine,
) -> Result(#(Point, Point), Error) {
  case
    do_endpoint_to_center(start, radius, x_axis_rotation, large_arc, sweep, end)
  {
    Error(error) -> Error(error)
    Ok(arc) -> {
      let assert Ok(#(x_axis, y_axis)) =
        arc_axes(arc.radius, arc.x_axis_rotation)
      let x_axis = linear_point(x_axis, transform)
      let y_axis = linear_point(y_axis, transform)

      case fully_collapsed(x_axis, y_axis) {
        True -> Ok(#(point(start, by: transform), point(end, by: transform)))
        False -> {
          case collapsed_axis(x_axis, y_axis) {
            Error(error) -> Error(error)
            Ok(axis) -> {
              let center = point(arc.center, by: transform)
              let alpha = dot(x_axis, axis)
              let beta = dot(y_axis, axis)
              let angles =
                collapsed_candidate_angles(
                  arc.start_angle,
                  arc.delta_angle,
                  alpha,
                  beta,
                )
              let scalars =
                list.map(angles, fn(angle) {
                  alpha
                  *. trig.cos_degrees(angle)
                  +. beta
                  *. trig.sin_degrees(angle)
                })
              let assert Ok(first) = list.first(scalars)
              let #(low, high) =
                list.fold(scalars, #(first, first), fn(bounds, scalar) {
                  let #(low, high) = bounds
                  #(float.min(low, scalar), float.max(high, scalar))
                })

              Ok(#(offset(center, axis, low), offset(center, axis, high)))
            }
          }
        }
      }
    }
  }
}

/// Convert an arc collapsed by an affine transform into a line-based subpath.
pub fn collapsed_arc_subpath(
  start start: Point,
  radius radius: Point,
  x_axis_rotation x_axis_rotation: Float,
  large_arc large_arc: Bool,
  sweep sweep: Bool,
  end end: Point,
  by transform: Affine,
) -> Result(List(Point), Error) {
  collapsed_arc_points(
    start,
    radius,
    x_axis_rotation,
    large_arc,
    sweep,
    end,
    transform,
  )
}

/// Convert an elliptical arc to one or more cubic Bezier curves.
///
/// The arc is split into chunks of at most a quarter turn. This is the common
/// deterministic SVG arc approximation strategy. This function does not accept
/// a tolerance; use a higher-level helper if you want SVG path segments back.
pub fn arc_to_cubics(
  start start: Point,
  radius radius: Point,
  x_axis_rotation x_axis_rotation: Float,
  large_arc large_arc: Bool,
  sweep sweep: Bool,
  end end: Point,
) -> Result(List(Cubic), Error) {
  case
    do_endpoint_to_center(start, radius, x_axis_rotation, large_arc, sweep, end)
  {
    Error(error) -> Error(error)
    Ok(arc) -> {
      case split_arc_inside_many(arc, at: cubic_split_progresses(arc)) {
        Error(error) -> Error(error)
        Ok(chunks) -> Ok(list.map(chunks, cubic_for_arc))
      }
    }
  }
}

/// Convert endpoint arc data to center parameterization.
///
/// Radii are corrected according to SVG's implementation notes: negative radii
/// are made positive, and radii that are too small to reach between the
/// endpoints are scaled up uniformly.
pub fn endpoint_to_center(
  data: EndpointArcData,
) -> Result(CenterArcData, Error) {
  do_endpoint_to_center(
    data.start,
    data.radius,
    data.x_axis_rotation,
    data.large_arc,
    data.sweep,
    data.end,
  )
}

/// Convert center arc data back to endpoint arc data.
///
/// The returned endpoint data uses corrected radii from the center form, and
/// derives `large_arc` and `sweep` from `delta_angle`.
pub fn center_to_endpoint(data: CenterArcData) -> EndpointArcData {
  EndpointArcData(
    start: point_at_angle(data, angle: data.start_angle),
    radius: data.radius,
    x_axis_rotation: data.x_axis_rotation,
    large_arc: arc_large_arc(data),
    sweep: arc_sweep(data),
    end: point_at_angle(data, angle: arc_end_angle(data)),
  )
}

/// Evaluate an arc at angular progress `t`.
///
/// `t` is not clamped. `0.0` evaluates the start of the arc, `1.0` evaluates
/// the end of the arc, and values outside that range extrapolate along the
/// same ellipse.
pub fn arc_point(arc: CenterArcData, at t: Float) -> Point {
  point_at_angle(arc, angle_at(arc, t))
}

/// Return the derivative with respect to angular progress `t`.
///
/// This is the tangent direction followed from the arc start to the arc end.
/// For the raw derivative with respect to the ellipse angle, use
/// `derivative_at_angle`.
pub fn arc_derivative(arc: CenterArcData, at t: Float) -> Point {
  scale(derivative_at_angle(arc, angle_at(arc, t)), arc.delta_angle)
}

/// Return the arc's exact axis-aligned bounding box.
pub fn arc_bounding_box(arc: CenterArcData) -> BoundingBox {
  let points =
    arc_bounding_box_candidate_angles(arc)
    |> list.map(fn(angle) { point_at_angle(arc, angle: angle) })
  let assert [first, ..rest] = points

  rest
  |> list.fold(BoundingBox(min: first, max: first), include_point)
}

/// Split an arc at angular progress `t`.
///
/// `t` is not clamped. Values outside `0.0..1.0` extrapolate along the same
/// ellipse, matching `arc_point`.
pub fn split_arc(
  arc: CenterArcData,
  at t: Float,
) -> #(CenterArcData, CenterArcData) {
  #(arc_between(arc, from: 0.0, to: t), arc_between(arc, from: t, to: 1.0))
}

/// Split an arc at angular progress `t`, returning an error outside `0.0..1.0`.
///
/// Values exactly at `0.0` or `1.0` are accepted and produce one zero-length
/// arc.
pub fn split_arc_inside(
  arc: CenterArcData,
  at t: Float,
) -> Result(#(CenterArcData, CenterArcData), Error) {
  case t <. 0.0 || t >. 1.0 {
    True -> Error(SplitOutsideArc)
    False -> Ok(split_arc(arc, at: t))
  }
}

/// Split an arc at multiple angular progress values.
///
/// Split points are sorted, exact duplicates are removed, and boundary `0.0`
/// or `1.0` split points are trimmed when they would only create zero-length
/// boundary arcs. Values outside `0.0..1.0` are allowed and extrapolate along
/// the same ellipse, matching `split_arc`.
pub fn split_arc_many(
  arc: CenterArcData,
  at points: List(Float),
) -> List(CenterArcData) {
  split_arc_at_progresses(arc, normalized_progresses(points))
}

/// Split an arc at multiple angular progress values, erroring outside `0.0..1.0`.
///
/// Split points are sorted, exact duplicates are removed, and boundary `0.0`
/// or `1.0` split points are trimmed when they would only create zero-length
/// boundary arcs. Values exactly at `0.0` or `1.0` are accepted.
pub fn split_arc_inside_many(
  arc: CenterArcData,
  at points: List(Float),
) -> Result(List(CenterArcData), Error) {
  let points = normalized_progresses(points)

  case list.any(points, fn(t) { t <. 0.0 || t >. 1.0 }) {
    True -> Error(SplitOutsideArc)
    False -> Ok(split_arc_at_progresses(arc, points))
  }
}

/// Evaluate an arc at a center-parameter angle in degrees.
pub fn point_at_angle(arc: CenterArcData, angle angle: Float) -> Point {
  ellipse_point(arc, angle)
}

/// Return the derivative with respect to the center-parameter angle in degrees.
pub fn derivative_at_angle(arc: CenterArcData, angle angle: Float) -> Point {
  scale(ellipse_derivative_radians(arc, angle), trig.degrees_to_radians(1.0))
}

/// Return the angle at `t` using this module's angular-progress parameterization.
pub fn angle_at(arc: CenterArcData, t t: Float) -> Float {
  arc.start_angle +. t *. arc.delta_angle
}

/// Return the arc's end angle in degrees.
pub fn arc_end_angle(arc: CenterArcData) -> Float {
  arc.start_angle +. arc.delta_angle
}

/// Return whether the arc spans more than 180 degrees.
pub fn arc_large_arc(arc: CenterArcData) -> Bool {
  float.absolute_value(arc.delta_angle) >. half_turn
}

/// Return whether the arc sweeps through increasing center-parameter angles.
pub fn arc_sweep(arc: CenterArcData) -> Bool {
  arc.delta_angle >=. 0.0
}

fn arc_between(
  arc: CenterArcData,
  from from: Float,
  to to: Float,
) -> CenterArcData {
  CenterArcData(
    center: arc.center,
    radius: arc.radius,
    x_axis_rotation: arc.x_axis_rotation,
    start_angle: angle_at(arc, t: from),
    delta_angle: arc.delta_angle *. { to -. from },
  )
}

fn split_arc_at_progresses(
  arc: CenterArcData,
  points: List(Float),
) -> List(CenterArcData) {
  split_arc_between_progresses(arc, previous: 0.0, points:, pieces: [])
}

fn split_arc_between_progresses(
  arc: CenterArcData,
  previous previous: Float,
  points points: List(Float),
  pieces pieces: List(CenterArcData),
) -> List(CenterArcData) {
  case points {
    [] -> list.reverse([arc_between(arc, from: previous, to: 1.0), ..pieces])
    [next, ..rest] -> {
      split_arc_between_progresses(arc, previous: next, points: rest, pieces: [
        arc_between(arc, from: previous, to: next),
        ..pieces
      ])
    }
  }
}

fn normalized_progresses(points: List(Float)) -> List(Float) {
  points
  |> sort_unique_progresses
  |> trim_start_progress
  |> trim_end_progress
}

fn sort_unique_progresses(points: List(Float)) -> List(Float) {
  case points {
    [] -> []
    [first, ..rest] ->
      sort_unique_progresses(rest) |> insert_unique_progress(first)
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

fn collapsed_arc_points(
  start: Point,
  radius: Point,
  x_axis_rotation: Float,
  large_arc: Bool,
  sweep: Bool,
  end: Point,
  transform: Affine,
) -> Result(List(Point), Error) {
  case
    do_endpoint_to_center(start, radius, x_axis_rotation, large_arc, sweep, end)
  {
    Error(error) -> Error(error)
    Ok(arc) -> {
      let assert Ok(#(x_axis, y_axis)) =
        arc_axes(arc.radius, arc.x_axis_rotation)
      let x_axis = linear_point(x_axis, transform)
      let y_axis = linear_point(y_axis, transform)

      case fully_collapsed(x_axis, y_axis) {
        True -> Ok([point(start, by: transform), point(end, by: transform)])
        False -> {
          case collapsed_axis(x_axis, y_axis) {
            Error(error) -> Error(error)
            Ok(axis) -> {
              let center = point(arc.center, by: transform)
              let alpha = dot(x_axis, axis)
              let beta = dot(y_axis, axis)
              let angles =
                collapsed_ordered_angles(
                  arc.start_angle,
                  arc.delta_angle,
                  alpha,
                  beta,
                )

              Ok(
                list.map(angles, fn(angle) {
                  offset(
                    center,
                    axis,
                    alpha
                      *. trig.cos_degrees(angle)
                      +. beta
                      *. trig.sin_degrees(angle),
                  )
                }),
              )
            }
          }
        }
      }
    }
  }
}

fn cubic_split_progresses(arc: CenterArcData) -> List(Float) {
  let delta = float.absolute_value(arc.delta_angle)

  case delta <=. quarter_turn +. epsilon {
    True -> []
    False ->
      cubic_split_progresses_from(
        next: quarter_turn /. delta,
        step: quarter_turn /. delta,
        points: [],
      )
  }
}

fn cubic_split_progresses_from(
  next next: Float,
  step step: Float,
  points points: List(Float),
) -> List(Float) {
  case next >=. 1.0 -. epsilon {
    True -> list.reverse(points)
    False ->
      cubic_split_progresses_from(next: next +. step, step:, points: [
        next,
        ..points
      ])
  }
}

fn cubic_for_arc(arc: CenterArcData) -> Cubic {
  let start_angle = arc.start_angle
  let end_angle = arc_end_angle(arc)
  let delta = arc.delta_angle
  let alpha = 4.0 /. 3.0 *. trig.tan_degrees(delta /. 4.0)
  let start = ellipse_point(arc, start_angle)
  let end = ellipse_point(arc, end_angle)
  let start_tangent = ellipse_derivative_radians(arc, start_angle)
  let end_tangent = ellipse_derivative_radians(arc, end_angle)

  Cubic(
    start:,
    control1: offset(start, start_tangent, alpha),
    control2: offset(end, end_tangent, 0.0 -. alpha),
    end:,
  )
}

fn arc_bounding_box_candidate_angles(arc: CenterArcData) -> List(Float) {
  let x_alpha = arc.radius.x *. trig.cos_degrees(arc.x_axis_rotation)
  let x_beta = 0.0 -. arc.radius.y *. trig.sin_degrees(arc.x_axis_rotation)
  let y_alpha = arc.radius.x *. trig.sin_degrees(arc.x_axis_rotation)
  let y_beta = arc.radius.y *. trig.cos_degrees(arc.x_axis_rotation)

  [
    start_angle_extremum(x_alpha, x_beta),
    opposite_angle_extremum(x_alpha, x_beta),
    start_angle_extremum(y_alpha, y_beta),
    opposite_angle_extremum(y_alpha, y_beta),
  ]
  |> list.filter(fn(angle) {
    angle_in_sweep(angle, arc.start_angle, arc.delta_angle)
  })
  |> list.append([arc.start_angle, arc_end_angle(arc)])
}

fn start_angle_extremum(alpha: Float, beta: Float) -> Float {
  trig.atan2_degrees(beta, alpha)
}

fn opposite_angle_extremum(alpha: Float, beta: Float) -> Float {
  start_angle_extremum(alpha, beta) +. half_turn
}

fn include_point(box: BoundingBox, point: Point) -> BoundingBox {
  BoundingBox(
    min: Point(float.min(box.min.x, point.x), float.min(box.min.y, point.y)),
    max: Point(float.max(box.max.x, point.x), float.max(box.max.y, point.y)),
  )
}

fn ellipse_point(arc: CenterArcData, angle: Float) -> Point {
  let cos_phi = trig.cos_degrees(arc.x_axis_rotation)
  let sin_phi = trig.sin_degrees(arc.x_axis_rotation)
  let cos_angle = trig.cos_degrees(angle)
  let sin_angle = trig.sin_degrees(angle)
  let x = arc.radius.x *. cos_angle
  let y = arc.radius.y *. sin_angle

  Point(
    arc.center.x +. cos_phi *. x -. sin_phi *. y,
    arc.center.y +. sin_phi *. x +. cos_phi *. y,
  )
}

fn ellipse_derivative_radians(arc: CenterArcData, angle: Float) -> Point {
  let cos_phi = trig.cos_degrees(arc.x_axis_rotation)
  let sin_phi = trig.sin_degrees(arc.x_axis_rotation)
  let x = 0.0 -. arc.radius.x *. trig.sin_degrees(angle)
  let y = arc.radius.y *. trig.cos_degrees(angle)

  Point(cos_phi *. x -. sin_phi *. y, sin_phi *. x +. cos_phi *. y)
}

fn do_endpoint_to_center(
  start: Point,
  radius: Point,
  x_axis_rotation: Float,
  large_arc: Bool,
  sweep: Bool,
  end: Point,
) -> Result(CenterArcData, Error) {
  let rx = float.absolute_value(radius.x)
  let ry = float.absolute_value(radius.y)

  case rx <=. epsilon || ry <=. epsilon {
    True -> Error(DegenerateInputArc)
    False -> {
      let cos_phi = trig.cos_degrees(x_axis_rotation)
      let sin_phi = trig.sin_degrees(x_axis_rotation)
      let midpoint =
        Point({ start.x +. end.x } /. 2.0, { start.y +. end.y } /. 2.0)
      let half_delta =
        Point({ start.x -. end.x } /. 2.0, { start.y -. end.y } /. 2.0)
      let x1p = cos_phi *. half_delta.x +. sin_phi *. half_delta.y
      let y1p = 0.0 -. sin_phi *. half_delta.x +. cos_phi *. half_delta.y
      let radius_scale =
        float.max(1.0, x1p *. x1p /. { rx *. rx } +. y1p *. y1p /. { ry *. ry })
      let scale = square_root(radius_scale)
      let rx = rx *. scale
      let ry = ry *. scale
      let center_prime = center_prime(rx, ry, x1p, y1p, large_arc, sweep)
      let center =
        Point(
          cos_phi *. center_prime.x -. sin_phi *. center_prime.y +. midpoint.x,
          sin_phi *. center_prime.x +. cos_phi *. center_prime.y +. midpoint.y,
        )
      let start_vector =
        Point({ x1p -. center_prime.x } /. rx, { y1p -. center_prime.y } /. ry)
      let end_vector =
        Point(
          { 0.0 -. x1p -. center_prime.x } /. rx,
          { 0.0 -. y1p -. center_prime.y } /. ry,
        )
      let start_angle = vector_angle(Point(1.0, 0.0), start_vector)
      let delta_angle = swept_delta_angle(start_vector, end_vector, sweep)

      Ok(CenterArcData(
        center:,
        radius: Point(rx, ry),
        x_axis_rotation:,
        start_angle:,
        delta_angle:,
      ))
    }
  }
}

fn center_prime(
  rx: Float,
  ry: Float,
  x1p: Float,
  y1p: Float,
  large_arc: Bool,
  sweep: Bool,
) -> Point {
  let numerator =
    rx *. rx *. ry *. ry -. rx *. rx *. y1p *. y1p -. ry *. ry *. x1p *. x1p
  let denominator = rx *. rx *. y1p *. y1p +. ry *. ry *. x1p *. x1p
  let sign = case large_arc == sweep {
    True -> -1.0
    False -> 1.0
  }
  let coefficient =
    sign *. square_root(float.max(0.0, numerator /. denominator))

  Point(coefficient *. rx *. y1p /. ry, 0.0 -. coefficient *. ry *. x1p /. rx)
}

fn swept_delta_angle(
  start_vector: Point,
  end_vector: Point,
  sweep: Bool,
) -> Float {
  let delta_angle = vector_angle(start_vector, end_vector)

  case sweep {
    True -> {
      case delta_angle <. 0.0 {
        True -> delta_angle +. full_turn
        False -> delta_angle
      }
    }
    False -> {
      case delta_angle >. 0.0 {
        True -> delta_angle -. full_turn
        False -> delta_angle
      }
    }
  }
}

fn collapsed_axis(x_axis: Point, y_axis: Point) -> Result(Point, Error) {
  case float.absolute_value(cross(x_axis, y_axis)) <=. epsilon {
    False -> Error(NotCollapsedToLine)
    True -> {
      let x_length = length(x_axis)
      let y_length = length(y_axis)

      case x_length >. epsilon || y_length >. epsilon {
        True -> {
          case x_length >=. y_length {
            True -> Ok(scale(x_axis, 1.0 /. x_length))
            False -> Ok(scale(y_axis, 1.0 /. y_length))
          }
        }
        False -> Error(NotCollapsedToLine)
      }
    }
  }
}

fn fully_collapsed(x_axis: Point, y_axis: Point) -> Bool {
  length(x_axis) <=. epsilon && length(y_axis) <=. epsilon
}

fn collapsed_candidate_angles(
  start_angle: Float,
  delta_angle: Float,
  alpha: Float,
  beta: Float,
) -> List(Float) {
  let end_angle = start_angle +. delta_angle
  let maximum_angle = trig.atan2_degrees(beta, alpha)
  let minimum_angle = maximum_angle +. half_turn

  [minimum_angle, maximum_angle]
  |> list.filter(fn(angle) { angle_in_sweep(angle, start_angle, delta_angle) })
  |> list.append([start_angle, end_angle])
}

fn collapsed_ordered_angles(
  start_angle: Float,
  delta_angle: Float,
  alpha: Float,
  beta: Float,
) -> List(Float) {
  let end_angle = start_angle +. delta_angle
  let maximum_angle = trig.atan2_degrees(beta, alpha)
  let minimum_angle = maximum_angle +. half_turn
  let interior_extrema =
    [minimum_angle, maximum_angle]
    |> list.filter(fn(angle) {
      let progress = angle_progress(angle, start_angle, delta_angle)
      progress >. epsilon
      && progress <. float.absolute_value(delta_angle) -. epsilon
    })
    |> list.map(fn(angle) {
      #(angle_progress(angle, start_angle, delta_angle), angle)
    })
    |> insert_sort_angles([])
    |> list.map(fn(pair) {
      let #(_, angle) = pair
      angle
    })

  [start_angle, ..list.append(interior_extrema, [end_angle])]
}

fn insert_sort_angles(
  angles: List(#(Float, Float)),
  sorted: List(#(Float, Float)),
) -> List(#(Float, Float)) {
  case angles {
    [] -> sorted
    [first, ..rest] -> insert_sort_angles(rest, insert_angle(first, sorted))
  }
}

fn insert_angle(
  angle: #(Float, Float),
  sorted: List(#(Float, Float)),
) -> List(#(Float, Float)) {
  case sorted {
    [] -> [angle]
    [first, ..rest] -> {
      let #(progress, _) = angle
      let #(first_progress, _) = first

      case progress <=. first_progress {
        True -> [angle, ..sorted]
        False -> [first, ..insert_angle(angle, rest)]
      }
    }
  }
}

fn angle_progress(
  angle: Float,
  start_angle: Float,
  delta_angle: Float,
) -> Float {
  case delta_angle >=. 0.0 {
    True -> positive_remainder(angle -. start_angle)
    False -> positive_remainder(start_angle -. angle)
  }
}

fn angle_in_sweep(
  angle: Float,
  start_angle: Float,
  delta_angle: Float,
) -> Bool {
  case delta_angle >=. 0.0 {
    True -> positive_remainder(angle -. start_angle) <=. delta_angle +. epsilon
    False ->
      positive_remainder(start_angle -. angle)
      <=. { 0.0 -. delta_angle } +. epsilon
  }
}

fn positive_remainder(angle: Float) -> Float {
  case angle <. 0.0 {
    True -> positive_remainder(angle +. full_turn)
    False -> {
      case angle >=. full_turn {
        True -> positive_remainder(angle -. full_turn)
        False -> angle
      }
    }
  }
}

fn arc_axes(
  radius: Point,
  x_axis_rotation: Float,
) -> Result(#(Point, Point), Error) {
  let rx = float.absolute_value(radius.x)
  let ry = float.absolute_value(radius.y)

  case rx <=. epsilon || ry <=. epsilon {
    True -> Error(DegenerateInputArc)
    False -> {
      let cos_phi = trig.cos_degrees(x_axis_rotation)
      let sin_phi = trig.sin_degrees(x_axis_rotation)

      Ok(#(
        Point(rx *. cos_phi, rx *. sin_phi),
        Point(0.0 -. ry *. sin_phi, ry *. cos_phi),
      ))
    }
  }
}

fn extract_axes(
  x_axis: Point,
  y_axis: Point,
) -> Result(#(Point, Float), Error) {
  let sxx = x_axis.x *. x_axis.x +. y_axis.x *. y_axis.x
  let sxy = x_axis.x *. x_axis.y +. y_axis.x *. y_axis.y
  let syy = x_axis.y *. x_axis.y +. y_axis.y *. y_axis.y
  let discriminant =
    square_root({ sxx -. syy } *. { sxx -. syy } +. 4.0 *. sxy *. sxy)
  let lambda1 = { sxx +. syy +. discriminant } /. 2.0
  let lambda2 = { sxx +. syy -. discriminant } /. 2.0

  case lambda1 <=. epsilon || lambda2 <=. epsilon {
    True -> Error(DegenerateInputArc)
    False -> {
      let axis1 = eigenvector(sxx, sxy, syy, lambda1)
      let axis2 = Point(0.0 -. axis1.y, axis1.x)
      let choose_axis1 =
        float.absolute_value(dot(axis1, x_axis))
        >=. float.absolute_value(dot(axis2, x_axis))

      case choose_axis1 {
        True -> {
          Ok(#(
            Point(square_root(lambda1), square_root(lambda2)),
            normalize_axis_rotation(trig.atan2_degrees(axis1.y, axis1.x)),
          ))
        }
        False -> {
          Ok(#(
            Point(square_root(lambda2), square_root(lambda1)),
            normalize_axis_rotation(trig.atan2_degrees(axis2.y, axis2.x)),
          ))
        }
      }
    }
  }
}

fn eigenvector(sxx: Float, sxy: Float, syy: Float, lambda: Float) -> Point {
  case float.absolute_value(sxy) >. epsilon {
    True -> normalize(Point(sxy, lambda -. sxx))
    False -> {
      case sxx >=. syy {
        True -> Point(1.0, 0.0)
        False -> Point(0.0, 1.0)
      }
    }
  }
}

fn vector_angle(a: Point, b: Point) -> Float {
  trig.atan2_degrees(cross(a, b), dot(a, b))
}

fn offset(point: Point, direction: Point, distance: Float) -> Point {
  Point(point.x +. direction.x *. distance, point.y +. direction.y *. distance)
}

fn linear_point(point: Point, transform: Affine) -> Point {
  Point(
    transform.a *. point.x +. transform.c *. point.y,
    transform.b *. point.x +. transform.d *. point.y,
  )
}

fn dot(a: Point, b: Point) -> Float {
  a.x *. b.x +. a.y *. b.y
}

fn cross(a: Point, b: Point) -> Float {
  a.x *. b.y -. a.y *. b.x
}

fn length(point: Point) -> Float {
  square_root(point.x *. point.x +. point.y *. point.y)
}

fn normalize(point: Point) -> Point {
  let point_length = length(point)

  case point_length <=. epsilon {
    True -> Point(1.0, 0.0)
    False -> scale(point, 1.0 /. point_length)
  }
}

fn scale(point: Point, factor: Float) -> Point {
  Point(point.x *. factor, point.y *. factor)
}

fn normalize_axis_rotation(degrees: Float) -> Float {
  case degrees <. 0.0 {
    True -> normalize_axis_rotation(degrees +. 180.0)
    False -> {
      case degrees >=. 180.0 {
        True -> normalize_axis_rotation(degrees -. 180.0)
        False -> degrees
      }
    }
  }
}

fn square_root(value: Float) -> Float {
  let assert Ok(root) = float.square_root(value)
  root
}
