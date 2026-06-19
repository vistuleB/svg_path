//// Lower-level helpers for transforming SVG elliptical arcs.
////
//// Most users should use `svg_path/transform` instead. This module exposes the
//// ellipse-specific math helpers used to transform arc axes and represent arcs
//// that collapse under affine transforms.

import gleam/float
import gleam/list
import gleam_community/maths

const epsilon = 0.000000001

/// A lightweight point used by the ellipse math helpers.
pub type Point {
  Point(x: Float, y: Float)
}

type ArcParameters {
  ArcParameters(
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
    endpoint_to_center(start, radius, x_axis_rotation, large_arc, sweep, end)
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
                  alpha *. maths.cos(angle) +. beta *. maths.sin(angle)
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
    endpoint_to_center(start, radius, x_axis_rotation, large_arc, sweep, end)
  {
    Error(error) -> Error(error)
    Ok(arc) -> Ok(cubic_chunks(arc.start_angle, arc.delta_angle, arc, []))
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
    endpoint_to_center(start, radius, x_axis_rotation, large_arc, sweep, end)
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
                    alpha *. maths.cos(angle) +. beta *. maths.sin(angle),
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

fn cubic_chunks(
  start_angle: Float,
  remaining_delta: Float,
  arc: ArcParameters,
  cubics: List(Cubic),
) -> List(Cubic) {
  let quarter_turn = maths.pi() /. 2.0

  case float.absolute_value(remaining_delta) <=. quarter_turn +. epsilon {
    True -> {
      list.reverse([
        cubic_for_angle_range(start_angle, start_angle +. remaining_delta, arc),
        ..cubics
      ])
    }
    False -> {
      let chunk_delta = case remaining_delta >=. 0.0 {
        True -> quarter_turn
        False -> 0.0 -. quarter_turn
      }
      cubic_chunks(
        start_angle +. chunk_delta,
        remaining_delta -. chunk_delta,
        arc,
        [
          cubic_for_angle_range(start_angle, start_angle +. chunk_delta, arc),
          ..cubics
        ],
      )
    }
  }
}

fn cubic_for_angle_range(
  start_angle: Float,
  end_angle: Float,
  arc: ArcParameters,
) -> Cubic {
  let delta = end_angle -. start_angle
  let alpha = 4.0 /. 3.0 *. maths.tan(delta /. 4.0)
  let start = ellipse_point(arc, start_angle)
  let end = ellipse_point(arc, end_angle)
  let start_tangent = ellipse_derivative(arc, start_angle)
  let end_tangent = ellipse_derivative(arc, end_angle)

  Cubic(
    start:,
    control1: offset(start, start_tangent, alpha),
    control2: offset(end, end_tangent, 0.0 -. alpha),
    end:,
  )
}

fn ellipse_point(arc: ArcParameters, angle: Float) -> Point {
  let phi = degrees_to_radians(arc.x_axis_rotation)
  let cos_phi = maths.cos(phi)
  let sin_phi = maths.sin(phi)
  let cos_angle = maths.cos(angle)
  let sin_angle = maths.sin(angle)
  let x = arc.radius.x *. cos_angle
  let y = arc.radius.y *. sin_angle

  Point(
    arc.center.x +. cos_phi *. x -. sin_phi *. y,
    arc.center.y +. sin_phi *. x +. cos_phi *. y,
  )
}

fn ellipse_derivative(arc: ArcParameters, angle: Float) -> Point {
  let phi = degrees_to_radians(arc.x_axis_rotation)
  let cos_phi = maths.cos(phi)
  let sin_phi = maths.sin(phi)
  let x = 0.0 -. arc.radius.x *. maths.sin(angle)
  let y = arc.radius.y *. maths.cos(angle)

  Point(cos_phi *. x -. sin_phi *. y, sin_phi *. x +. cos_phi *. y)
}

fn endpoint_to_center(
  start: Point,
  radius: Point,
  x_axis_rotation: Float,
  large_arc: Bool,
  sweep: Bool,
  end: Point,
) -> Result(ArcParameters, Error) {
  let rx = float.absolute_value(radius.x)
  let ry = float.absolute_value(radius.y)

  case rx <=. epsilon || ry <=. epsilon {
    True -> Error(DegenerateInputArc)
    False -> {
      let phi = degrees_to_radians(x_axis_rotation)
      let cos_phi = maths.cos(phi)
      let sin_phi = maths.sin(phi)
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

      Ok(ArcParameters(
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
        True -> delta_angle +. 2.0 *. maths.pi()
        False -> delta_angle
      }
    }
    False -> {
      case delta_angle >. 0.0 {
        True -> delta_angle -. 2.0 *. maths.pi()
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
  let maximum_angle = maths.atan2(beta, alpha)
  let minimum_angle = maximum_angle +. maths.pi()

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
  let maximum_angle = maths.atan2(beta, alpha)
  let minimum_angle = maximum_angle +. maths.pi()
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
  let turn = 2.0 *. maths.pi()

  case angle <. 0.0 {
    True -> positive_remainder(angle +. turn)
    False -> {
      case angle >=. turn {
        True -> positive_remainder(angle -. turn)
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
      let phi = degrees_to_radians(x_axis_rotation)
      let cos_phi = maths.cos(phi)
      let sin_phi = maths.sin(phi)

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
            normalize_axis_rotation(
              radians_to_degrees(maths.atan2(axis1.y, axis1.x)),
            ),
          ))
        }
        False -> {
          Ok(#(
            Point(square_root(lambda2), square_root(lambda1)),
            normalize_axis_rotation(
              radians_to_degrees(maths.atan2(axis2.y, axis2.x)),
            ),
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
  maths.atan2(cross(a, b), dot(a, b))
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

fn degrees_to_radians(degrees: Float) -> Float {
  degrees *. maths.pi() /. 180.0
}

fn radians_to_degrees(radians: Float) -> Float {
  radians *. 180.0 /. maths.pi()
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
