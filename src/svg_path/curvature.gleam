//// Signed curvature, radius, inflection points, and offset-cusp diagnostics.
////
//// Signs refer to the visual left normal in SVG coordinates (positive y down).
//// Curvature has inverse-length units; radius, target distances, and margins
//// have length units. Parameters refer to the segment's `0.0..1.0` interval.
////
//// Pointwise queries evaluate segment derivatives directly. Cusp discovery
//// partitions at curvature extrema before bisection. Individual contracts
//// describe numerical limitations.

import gleam/float
import gleam/list
import gleam/result
import svg_path
import svg_path/bezier
import svg_path/ellipse
import svg_path/internal/number
import svg_path/root
import svg_path/trig

const default_tolerance = 0.000000001

const default_max_depth = 32

const cusp_relative_tolerance = 0.000000000001

const root_parameter_tolerance = 0.000000001

/// Error returned by curvature helpers.
///
/// Cases distinguish invalid options (carrying the supplied value), underlying
/// path-operation failures, and degenerate or infinite curvature geometry.
pub type Error {
  /// An underlying segment derivative query failed, for example arc conversion.
  PathError(error: svg_path.Error)
  /// A curvature `tolerance` option was invalid (not finite or negative).
  InvalidCurvatureTolerance(tolerance: Float)
  /// A curvature `max_depth` option was invalid (not positive).
  InvalidCurvatureMaxDepth(max_depth: Int)
  /// A curvature `margin` argument was invalid (not finite or negative).
  InvalidCurvatureMargin(margin: Float)
  /// The segment has a degenerate zero-speed parameter, so its curvature is
  /// undefined there.
  DegenerateCurvatureDerivative
  /// The radius of curvature is infinite at this parameter (a line or an
  /// inflection/flat point).
  InfiniteRadiusOfCurvature
  /// Polynomial isolation could not determine the curvature partition points.
  CurvatureRootIsolationFailed
  /// Cusp bisection exhausted its depth before satisfying the parameter
  /// tolerance or finding an exact root. Bounds are the remaining bracket.
  CurvatureMaxDepthReached(lower: Float, upper: Float)
}

/// Options for cusp discovery.
/// All fields are validated by discovery functions. Inflection discovery is
/// algebraic and uses none of these fields after validation.
pub type Options {
  Options(
    /// Numeric tolerance for roots and interval widths in parameter space.
    tolerance: Float,
    /// Maximum bisection/subdivision depth.
    max_depth: Int,
  )
}

/// First and second derivative data at a segment parameter.
pub type Derivatives {
  Derivatives(first: svg_path.Point, second: svg_path.Point)
}

/// Return default curvature options.
pub fn default_options() -> Options {
  Options(tolerance: default_tolerance, max_depth: default_max_depth)
}

/// Return first and second parameter derivatives for a segment at `t`.
///
/// Lines return zero second derivative. Arcs use exact ellipse derivatives.
pub fn segment_derivatives(
  segment: svg_path.Segment,
  at t: Float,
) -> Result(Derivatives, svg_path.Error) {
  use first <- result.try(svg_path.segment_derivative(segment, at: t))
  use second <- result.try(svg_path.segment_second_derivative(segment, at: t))
  Ok(Derivatives(first:, second:))
}

/// Return visual-left-normal signed curvature at a segment parameter.
///
/// Positive values mean the curve bends toward the visual left of its tangent;
/// negative values mean it bends toward the visual right. Directional words
/// use SVG page coordinates, where positive y points down.
/// Lines return `0.0`. Degenerate zero-speed parameters return an error.
pub fn segment_left_normal_curvature(
  segment: svg_path.Segment,
  at t: Float,
) -> Result(Float, Error) {
  use data <- result.try(segment_derivatives_curvature(segment, at: t))
  left_normal_curvature_from_derivatives(data)
}

/// Return visual-left-normal signed radius of curvature at a segment parameter.
///
/// Lines and inflection points return `Error(InfiniteRadiusOfCurvature)` because
/// their radius is infinite. Degenerate zero-speed parameters return
/// `Error(DegenerateCurvatureDerivative)`.
pub fn segment_left_normal_radius(
  segment: svg_path.Segment,
  at t: Float,
) -> Result(Float, Error) {
  use curvature <- result.try(segment_left_normal_curvature(segment, at: t))
  case number.is_zero(curvature) {
    True -> Error(InfiniteRadiusOfCurvature)
    False -> Ok(1.0 /. curvature)
  }
}

/// Return `abs(R_left(t) - distance) < margin` without evaluating `R_left(t)`
/// directly.
///
/// Algebraically, for finite nonzero curvature this is equivalent to:
///
/// `abs(|p'|^3 + distance * cross(p', p'')) < margin * abs(cross(p', p''))`.
pub fn segment_left_normal_radius_close_to(
  segment: svg_path.Segment,
  distance distance: Float,
  margin margin: Float,
  at t: Float,
) -> Result(Bool, Error) {
  case margin <. 0.0 || !number.is_finite(margin) {
    True -> Error(InvalidCurvatureMargin(margin))
    False -> {
      use data <- result.try(segment_derivatives_curvature(segment, at: t))
      left_normal_radius_close_to(data, distance: distance, margin: margin)
    }
  }
}

/// Return the visual-left-normal cusp residual
/// `|p'|^3 + distance * cross(p', p'')`.
///
/// A zero residual means the visual-left-normal signed radius equals `distance`,
/// assuming finite nonzero curvature.
/// Its magnitude depends on parameter speed: it has cubed-length units for a
/// dimensionless parameter and is not a geometric distance error. Lines return
/// `|p'|^3`; zero-speed parameters return `DegenerateCurvatureDerivative`.
pub fn segment_left_normal_cusp_residual(
  segment: svg_path.Segment,
  distance distance: Float,
  at t: Float,
) -> Result(Float, Error) {
  use data <- result.try(segment_derivatives_curvature(segment, at: t))
  left_normal_cusp_residual_from_derivatives(data, distance: distance)
}

/// Find parameters where visual-left-normal signed radius equals
/// `distance`.
///
/// Polynomial curvature extrema (degree at most five for cubics) and zero-speed
/// parameters partition Beziers into monotone-curvature intervals. Ellipses use
/// their axis extrema. Partition points are checked for touching roots, and
/// crossings are bisected.
///
/// Touches use a `1e-12` relative cancellation threshold in the cusp residual;
/// sufficiently close misses cannot be distinguished from exact touches.
/// Completeness is subject to polynomial isolation and floating-point accuracy.
/// Zero-speed parameters are excluded, using one-sided residual signs to search
/// their neighboring intervals. Lines and zero offsets return `[]`. A circular
/// arc whose entire radius matches the target returns `[0.0, 1.0]`.
/// Bisection returns `CurvatureMaxDepthReached` with the remaining bracket if
/// `max_depth` is exhausted before convergence. An exact midpoint root or an
/// interval within tolerance still succeeds at the depth limit.
/// Polynomial-isolation failures and arc-conversion errors also propagate.
/// Results are sorted and merged within `options.tolerance` in parameter space.
pub fn segment_left_normal_cusp_parameters(
  segment: svg_path.Segment,
  distance distance: Float,
  options options: Options,
) -> Result(List(Float), Error) {
  use _ <- result.try(validate_options(options))
  case number.is_zero(distance), segment {
    True, _ | _, svg_path.Line(..) -> Ok([])
    False, svg_path.QuadraticBezier(start:, control:, end:) -> {
      let first = point_scale(point_subtract(control, start), 2.0)
      let last = point_scale(point_subtract(end, control), 2.0)
      polynomial_cusps(
        first,
        point_subtract(last, first),
        svg_path.Point(0.0, 0.0),
        distance,
        options,
      )
    }
    False, svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      let first = point_scale(point_subtract(control1, start), 3.0)
      let middle = point_scale(point_subtract(control2, control1), 3.0)
      let last = point_scale(point_subtract(end, control2), 3.0)
      polynomial_cusps(
        first,
        point_scale(point_subtract(middle, first), 2.0),
        point_add(point_subtract(last, point_scale(middle, 2.0)), first),
        distance,
        options,
      )
    }
    False, svg_path.Arc(..) -> {
      use arc <- result.try(
        svg_path.arc_center_data(segment) |> result.map_error(PathError),
      )
      let evaluate = fn(t) {
        let first = ellipse.arc_derivative(arc, t)
        let second = ellipse.arc_second_derivative(arc, t)
        relative_cusp_residual(
          svg_path.Point(first.x, first.y),
          svg_path.Point(second.x, second.y),
          distance,
        )
      }
      case arc.radius.x == arc.radius.y {
        True ->
          case float.absolute_value(evaluate(0.5)) <=. cusp_relative_tolerance {
            True -> Ok([0.0, 1.0])
            False -> Ok([])
          }
        False -> {
          let cos = trig.cos_degrees(arc.x_axis_rotation)
          let sin = trig.sin_degrees(arc.x_axis_rotation)
          let parameters =
            list.append(
              ellipse.arc_projection_extrema(
                arc,
                ellipse.EllipsePoint(cos, sin),
              ),
              ellipse.arc_projection_extrema(
                arc,
                ellipse.EllipsePoint(0.0 -. sin, cos),
              ),
            )
          partitioned_cusp_roots(evaluate, parameters, [], options)
        }
      }
    }
  }
}

/// Return algebraically computed interior inflection parameters.
///
/// This solves `cross(p'(t), p''(t)) = 0`. Lines and identically flat pieces
/// return an empty list. Roots at the segment endpoints are filtered out.
/// Cubics use the Bezier inflection solver; lines, quadratics, and arcs return
/// an empty list. Options are validated but do not affect the algebraic solve.
pub fn segment_inflection_parameters(
  segment: svg_path.Segment,
  options options: Options,
) -> Result(List(Float), Error) {
  use _ <- result.try(validate_options(options))
  case segment {
    svg_path.Line(..) | svg_path.QuadraticBezier(..) | svg_path.Arc(..) ->
      Ok([])
    svg_path.CubicBezier(start:, control1:, control2:, end:) ->
      bezier.CubicBezierData(
        start: to_bezier_point(start),
        control1: to_bezier_point(control1),
        control2: to_bezier_point(control2),
        end: to_bezier_point(end),
      )
      |> bezier.cubic_inflection_parameters
      |> Ok
  }
}

fn to_bezier_point(point: svg_path.Point) -> bezier.BezierPoint {
  bezier.BezierPoint(point.x, point.y)
}

fn segment_derivatives_curvature(
  segment: svg_path.Segment,
  at t: Float,
) -> Result(Derivatives, Error) {
  segment_derivatives(segment, at: t)
  |> result.map_error(PathError)
}

fn left_normal_curvature_from_derivatives(
  data: Derivatives,
) -> Result(Float, Error) {
  let Derivatives(first:, second:) = data
  let speed_squared = dot(first, first)
  case speed_squared <=. 0.0 || !number.is_finite(speed_squared) {
    True -> Error(DegenerateCurvatureDerivative)
    False -> {
      let assert Ok(speed) = float.square_root(speed_squared)
      Ok({ 0.0 -. cross(first, second) } /. { speed_squared *. speed })
    }
  }
}

fn left_normal_radius_close_to(
  data: Derivatives,
  distance distance: Float,
  margin margin: Float,
) -> Result(Bool, Error) {
  let Derivatives(first:, second:) = data
  let speed_squared = dot(first, first)
  let c = cross(first, second)
  case speed_squared <=. 0.0 || !number.is_finite(speed_squared) {
    True -> Error(DegenerateCurvatureDerivative)
    False ->
      case number.is_zero(c) {
        True -> Error(InfiniteRadiusOfCurvature)
        False -> {
          let assert Ok(speed) = float.square_root(speed_squared)
          let speed_cubed = speed_squared *. speed
          Ok(
            float.absolute_value(speed_cubed +. distance *. c)
            <. margin *. float.absolute_value(c),
          )
        }
      }
  }
}

fn left_normal_cusp_residual_from_derivatives(
  data: Derivatives,
  distance distance: Float,
) -> Result(Float, Error) {
  let Derivatives(first:, second:) = data
  let speed_squared = dot(first, first)
  case speed_squared <=. 0.0 || !number.is_finite(speed_squared) {
    True -> Error(DegenerateCurvatureDerivative)
    False -> {
      let assert Ok(speed) = float.square_root(speed_squared)
      Ok(speed_squared *. speed +. distance *. cross(first, second))
    }
  }
}

// Velocity is v0 + v1*t + v2*t^2. Coefficient lists below are ascending;
// root.gleam takes descending order, so reverse only at that boundary.
fn polynomial_cusps(
  v0: svg_path.Point,
  v1: svg_path.Point,
  v2: svg_path.Point,
  distance: Float,
  options: Options,
) -> Result(List(Float), Error) {
  let c = [cross(v0, v1), 2.0 *. cross(v0, v2), cross(v1, v2)]
  case list.all(c, number.is_zero) {
    True -> Ok([])
    False -> {
      let q = [
        dot(v0, v0),
        2.0 *. dot(v0, v1),
        dot(v1, v1) +. 2.0 *. dot(v0, v2),
        2.0 *. dot(v1, v2),
        dot(v2, v2),
      ]
      // k=-C/Q^(3/2); k'=0 iff 2*C'*Q - 3*C*Q'=0 where Q>0.
      let extrema_polynomial =
        polynomial_add(
          polynomial_scale(
            polynomial_multiply(polynomial_derivative(c), q),
            2.0,
          ),
          polynomial_scale(
            polynomial_multiply(c, polynomial_derivative(q)),
            -3.0,
          ),
        )
      use extrema <- result.try(polynomial_roots(extrema_polynomial))
      let xs = [v0.x, v1.x, v2.x]
      let ys = [v0.y, v1.y, v2.y]
      // Solve both coordinates: one can have a numerically delicate double
      // root while the other has a simple root at the same stationary point.
      use x_roots <- result.try(polynomial_roots(xs))
      use y_roots <- result.try(polynomial_roots(ys))
      let candidates = list.append(x_roots, y_roots)
      let velocity = fn(t) {
        point_add(v0, point_scale(point_add(v1, point_scale(v2, t)), t))
      }
      let stationary =
        list.filter(candidates, fn(t) {
          let v = velocity(t)
          float.absolute_value(v.x)
          <=. cusp_relative_tolerance *. coefficient_scale(xs)
          && float.absolute_value(v.y)
          <=. cusp_relative_tolerance *. coefficient_scale(ys)
        })
        |> unique_sorted_parameters(root_parameter_tolerance)
      let evaluate = fn(t) {
        case list.contains(stationary, t) {
          True -> {
            // At a simple stationary cubic point, C has a double zero with
            // leading coefficient cross(v1,v2), while |v|^3 has a triple zero.
            // For nonzero offset the residual has this same limiting sign on
            // both sides. A collinear velocity (including a double zero) was
            // rejected above. Never count the stationary point as a cusp root.
            case distance *. cross(v1, v2) <. 0.0 {
              True -> -1.0
              False -> 1.0
            }
          }
          False ->
            relative_cusp_residual(
              velocity(t),
              point_add(v1, point_scale(v2, 2.0 *. t)),
              distance,
            )
        }
      }
      // A zero-speed root also occurs in the extrema polynomial. Prefer the
      // directly solved velocity root over its higher-multiplicity estimate.
      let extrema =
        list.filter(extrema, fn(t) {
          !list.any(stationary, fn(zero) {
            float.absolute_value(t -. zero) <=. root_parameter_tolerance
          })
        })
      partitioned_cusp_roots(
        evaluate,
        list.append(extrema, stationary),
        stationary,
        options,
      )
    }
  }
}

fn relative_cusp_residual(
  first: svg_path.Point,
  second: svg_path.Point,
  distance: Float,
) -> Float {
  let speed_squared = dot(first, first)
  let assert Ok(speed) = float.square_root(speed_squared)
  let speed_cubed = speed_squared *. speed
  let term = distance *. cross(first, second)
  let scale = speed_cubed +. float.absolute_value(term)
  case number.is_zero(scale) {
    True -> 1.0
    False -> { speed_cubed +. term } /. scale
  }
}

fn polynomial_roots(coefficients: List(Float)) -> Result(List(Float), Error) {
  root.polynomial_roots_with(
    list.reverse(coefficients),
    from: 0.0,
    to: 1.0,
    options: root.default_polynomial_options(),
  )
  |> result.map_error(fn(_) { CurvatureRootIsolationFailed })
}

fn coefficient_scale(values: List(Float)) -> Float {
  list.fold(values, 0.0, fn(sum, value) { sum +. float.absolute_value(value) })
}

fn polynomial_derivative(values: List(Float)) -> List(Float) {
  values |> list.reverse |> root.polynomial_derivative |> list.reverse
}

fn polynomial_scale(values: List(Float), factor: Float) -> List(Float) {
  list.map(values, fn(value) { value *. factor })
}

fn polynomial_add(a: List(Float), b: List(Float)) -> List(Float) {
  case a, b {
    [], _ -> b
    _, [] -> a
    [x, ..xs], [y, ..ys] -> [x +. y, ..polynomial_add(xs, ys)]
  }
}

fn polynomial_multiply(a: List(Float), b: List(Float)) -> List(Float) {
  case a {
    [] -> []
    [x, ..xs] ->
      polynomial_add(polynomial_scale(b, x), [0.0, ..polynomial_multiply(xs, b)])
  }
}

fn point_add(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.Point(a.x +. b.x, a.y +. b.y)
}

fn point_subtract(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.Point(a.x -. b.x, a.y -. b.y)
}

fn point_scale(a: svg_path.Point, scale: Float) -> svg_path.Point {
  svg_path.Point(a.x *. scale, a.y *. scale)
}

fn partitioned_cusp_roots(
  f: fn(Float) -> Float,
  parameters: List(Float),
  stationary: List(Float),
  options: Options,
) -> Result(List(Float), Error) {
  let parameters = unique_sorted_parameters([0.0, 1.0, ..parameters], 0.0)
  let values =
    list.map(parameters, fn(t) {
      let value = f(t)
      let value = case
        !list.contains(stationary, t)
        && float.absolute_value(value) <=. cusp_relative_tolerance
      {
        True -> 0.0
        False -> value
      }
      #(t, value)
    })
  let roots =
    list.filter_map(values, fn(pair) {
      let #(t, value) = pair
      case number.is_zero(value) {
        True -> Ok(t)
        False -> Error(Nil)
      }
    })
  partition_crossings(f, values, options, roots)
  |> result.map(unique_sorted_parameters(_, options.tolerance))
}

fn partition_crossings(
  f: fn(Float) -> Float,
  values: List(#(Float, Float)),
  options: Options,
  roots: List(Float),
) -> Result(List(Float), Error) {
  case values {
    [#(a, va), #(b, vb) as next, ..rest] -> {
      use roots <- result.try(case sign_change(va, vb) {
        True ->
          refine_root(fn(t) { Ok(f(t)) }, a, b, va, vb, options, depth: 0)
          |> result.map(fn(t) { [t, ..roots] })
        False -> Ok(roots)
      })
      partition_crossings(f, [next, ..rest], options, roots)
    }
    _ -> Ok(roots)
  }
}

fn refine_root(
  f: fn(Float) -> Result(Float, Error),
  a: Float,
  b: Float,
  va: Float,
  vb: Float,
  options: Options,
  depth depth: Int,
) -> Result(Float, Error) {
  let mid = { a +. b } /. 2.0
  use vm <- result.try(f(mid))
  // Test success first, including on the final permitted subdivision.
  case
    number.is_zero(vm) || float.absolute_value(b -. a) <=. options.tolerance
  {
    True -> Ok(mid)
    False -> {
      case depth >= options.max_depth {
        True -> Error(CurvatureMaxDepthReached(lower: a, upper: b))
        False ->
          case sign_change(va, vm) {
            True -> refine_root(f, a, mid, va, vm, options, depth: depth + 1)
            False ->
              case sign_change(vm, vb) {
                True ->
                  refine_root(f, mid, b, vm, vb, options, depth: depth + 1)
                False -> Ok(mid)
              }
          }
      }
    }
  }
}

fn validate_options(options: Options) -> Result(Nil, Error) {
  case options.tolerance <. 0.0 || !number.is_finite(options.tolerance) {
    True -> Error(InvalidCurvatureTolerance(options.tolerance))
    False ->
      case options.max_depth <= 0 {
        True -> Error(InvalidCurvatureMaxDepth(options.max_depth))
        False -> Ok(Nil)
      }
  }
}

fn unique_sorted_parameters(
  values: List(Float),
  tolerance: Float,
) -> List(Float) {
  values
  |> list.filter(fn(value) { value >=. 0.0 && value <=. 1.0 })
  |> list.sort(float.compare)
  |> unique_parameters(tolerance, unique: [])
}

fn unique_parameters(
  values: List(Float),
  tolerance: Float,
  unique unique: List(Float),
) -> List(Float) {
  case values {
    [] -> list.reverse(unique)
    [first, ..rest] ->
      case unique {
        [previous, ..] ->
          case float.absolute_value(first -. previous) <=. tolerance {
            True -> unique_parameters(rest, tolerance, unique:)
            False ->
              unique_parameters(rest, tolerance, unique: [first, ..unique])
          }
        _ -> unique_parameters(rest, tolerance, unique: [first, ..unique])
      }
  }
}

fn sign_change(a: Float, b: Float) -> Bool {
  { a <. 0.0 && b >. 0.0 } || { a >. 0.0 && b <. 0.0 }
}

fn dot(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.x +. a.y *. b.y
}

fn cross(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.y -. a.y *. b.x
}
