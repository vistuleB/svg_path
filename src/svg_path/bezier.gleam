//// Lower-level helpers for Bezier curves.
////
//// Most users should work with `svg_path.Line`, `svg_path.QuadraticBezier`,
//// and `svg_path.CubicBezier` values through the root module. This module is
//// the more technical layer for users who want the curve math behind line and
//// Bezier segments.
////
//// For cubic fitting with ordinary `svg_path.Point` values and root
//// `svg_path.Error`, use the root-module wrappers
//// `svg_path.fit_cubic_with_endpoint_tangents` and
//// `svg_path.fit_cubic_with_endpoints`.
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
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import svg_path/root

const root_tolerance = 0.000000001

/// A lightweight point used by the Bezier math helpers.
pub type BezierPoint {
  BezierPoint(x: Float, y: Float)
}

/// An axis-aligned bounding box for a Bezier curve.
pub type BoundingBox {
  BoundingBox(min: BezierPoint, max: BezierPoint)
}

/// Error measurements for a fitted cubic.
pub type CubicFitError {
  CubicFitError(
    /// `sqrt(sum(distance(sample, fitted)^2))`.
    root_sum_square: Float,
    /// `sqrt(sum(distance(sample, fitted)^2) / sample_count)`.
    root_mean_square: Float,
    /// The largest sample distance.
    max: Float,
  )
}

/// Options for direct cubic self-intersection detection.
pub type CubicSelfIntersectionOptions {
  CubicSelfIntersectionOptions(
    /// Minimum required arc length between the two visits to the intersection.
    minimum_arc_length_separation: Float,
    /// Maximum allowed distance between the two evaluated points.
    distance_tolerance: Float,
  )
}

/// A point where a cubic Bezier intersects itself.
pub type CubicSelfIntersection {
  CubicSelfIntersection(s: Float, t: Float, point: BezierPoint)
}

/// Bezier-parameter representation of line, quadratic, and cubic curves.
pub type BezierData {
  /// A degree-1 Bezier curve.
  LinearBezierData(start: BezierPoint, end: BezierPoint)

  /// A degree-2 Bezier curve.
  QuadraticBezierData(
    start: BezierPoint,
    control: BezierPoint,
    end: BezierPoint,
  )

  /// A degree-3 Bezier curve.
  CubicBezierData(
    start: BezierPoint,
    control1: BezierPoint,
    control2: BezierPoint,
    end: BezierPoint,
  )
}

/// Errors returned by Bezier helpers.
pub type Error {
  /// The requested split point is outside the curve's `0.0..1.0` parameter range.
  SplitOutsideBezier

  /// A tangent direction was too small to normalize.
  DegenerateTangent

  /// The provided samples do not determine stable cubic handle lengths.
  UnderdeterminedCubicFit

  /// Cubic self-intersection minimum arc length separation must be greater than zero.
  InvalidCubicSelfIntersectionMinimumArcLengthSeparation(Float)

  /// Cubic self-intersection distance tolerance must be greater than zero.
  InvalidCubicSelfIntersectionDistanceTolerance(Float)
}

/// Return the curve's start point.
pub fn bezier_start(curve: BezierData) -> BezierPoint {
  case curve {
    LinearBezierData(start:, ..)
    | QuadraticBezierData(start:, ..)
    | CubicBezierData(start:, ..) -> start
  }
}

/// Return the curve's end point.
pub fn bezier_end(curve: BezierData) -> BezierPoint {
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
pub fn bezier_point(curve: BezierData, at t: Float) -> BezierPoint {
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
pub fn bezier_derivative(curve: BezierData, at t: Float) -> BezierPoint {
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
pub fn map_points(
  curve: BezierData,
  with f: fn(BezierPoint) -> BezierPoint,
) -> BezierData {
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

/// Fit a cubic with fixed endpoints and endpoint tangent directions.
///
/// The fitted cubic has the form:
///
/// ```text
/// control1 = start + a * unit(start_tangent)
/// control2 = end - b * unit(end_tangent)
/// ```
///
/// `end_tangent` has the usual Bezier derivative direction at `t = 1`, so it
/// points in the direction the curve is travelling as it reaches `end`.
///
/// The scalar handle lengths `a` and `b` are chosen by least squares against
/// the provided `(t, point)` samples. Samples are allowed at any `t`, but
/// endpoint samples do not add handle information.
pub fn fit_cubic_with_endpoint_tangents(
  start start: BezierPoint,
  end end: BezierPoint,
  start_tangent start_tangent: BezierPoint,
  end_tangent end_tangent: BezierPoint,
  samples samples: List(#(Float, BezierPoint)),
) -> Result(#(BezierData, CubicFitError), Error) {
  use start_direction <- result.try(unit(start_tangent))
  use end_direction <- result.try(unit(end_tangent))
  use fit <- result.try(cubic_fit_normal_equations(
    samples,
    start:,
    end:,
    start_direction:,
    end_direction:,
    ata00: 0.0,
    ata01: 0.0,
    ata11: 0.0,
    atb0: 0.0,
    atb1: 0.0,
    count: 0,
  ))
  let #(a, b) = fit
  let curve =
    CubicBezierData(
      start:,
      control1: add(start, scale(start_direction, a)),
      control2: difference(end, scale(end_direction, b)),
      end:,
    )
  let error = cubic_fit_error(samples, curve)

  Ok(#(curve, error))
}

/// Fit a cubic with fixed endpoints and no tangent constraints.
///
/// The fitted cubic has exactly the provided `start` and `end`. Its two control
/// points are chosen by least squares against the provided `(t, point)` samples.
/// Samples are allowed at any `t`, but endpoint samples do not add control
/// point information.
pub fn fit_cubic_with_endpoints(
  start start: BezierPoint,
  end end: BezierPoint,
  samples samples: List(#(Float, BezierPoint)),
) -> Result(#(BezierData, CubicFitError), Error) {
  use controls <- result.try(cubic_endpoint_fit_normal_equations(
    samples,
    start:,
    end:,
    ata00: 0.0,
    ata01: 0.0,
    ata11: 0.0,
    atb0: BezierPoint(0.0, 0.0),
    atb1: BezierPoint(0.0, 0.0),
    count: 0,
  ))
  let #(control1, control2) = controls
  let curve = CubicBezierData(start:, control1:, control2:, end:)
  let error = cubic_fit_error(samples, curve)

  Ok(#(curve, error))
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

/// Return the default options for direct cubic self-intersection detection.
pub fn default_cubic_self_intersection_options() -> CubicSelfIntersectionOptions {
  CubicSelfIntersectionOptions(
    minimum_arc_length_separation: root_tolerance,
    distance_tolerance: root_tolerance,
  )
}

/// Return direct self-intersections of a cubic Bezier curve.
///
/// Linear and quadratic Beziers return an empty list. Cubics return either an
/// empty list or one ordinary self-intersection. Endpoint intersections are
/// treated the same as interior intersections: the two parameters only need to
/// be separated by `minimum_arc_length_separation` along the curve.
pub fn cubic_self_intersections(
  curve: BezierData,
) -> Result(List(CubicSelfIntersection), Error) {
  cubic_self_intersections_with(
    curve,
    options: default_cubic_self_intersection_options(),
  )
}

/// Return direct self-intersections of a cubic Bezier curve using explicit
/// options.
///
/// `minimum_arc_length_separation` is measured in the same coordinate units as
/// the curve. Larger values are stricter. `distance_tolerance` is also measured
/// in the same coordinate units. Smaller values are stricter.
pub fn cubic_self_intersections_with(
  curve: BezierData,
  options options: CubicSelfIntersectionOptions,
) -> Result(List(CubicSelfIntersection), Error) {
  use _ <- result.try(validate_cubic_self_intersection_options(options))

  case curve {
    LinearBezierData(..) | QuadraticBezierData(..) -> Ok([])
    CubicBezierData(start:, control1:, control2:, end:) -> {
      let #(a, b, c) = cubic_power_coefficients(start, control1, control2, end)
      let candidates =
        cubic_self_intersection_candidates(a, b, c, preferred_axis: XAxis)
        |> list.append(cubic_self_intersection_candidates(
          a,
          b,
          c,
          preferred_axis: YAxis,
        ))

      Ok(filter_cubic_self_intersections(candidates, curve, options, []))
    }
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

fn cubic_fit_normal_equations(
  samples: List(#(Float, BezierPoint)),
  start start: BezierPoint,
  end end: BezierPoint,
  start_direction start_direction: BezierPoint,
  end_direction end_direction: BezierPoint,
  ata00 ata00: Float,
  ata01 ata01: Float,
  ata11 ata11: Float,
  atb0 atb0: Float,
  atb1 atb1: Float,
  count count: Int,
) -> Result(#(Float, Float), Error) {
  case samples {
    [] -> solve_cubic_fit_equations(ata00, ata01, ata11, atb0, atb1, count)
    [sample, ..rest] -> {
      let #(t, point) = sample
      let one_minus_t = 1.0 -. t
      let start_basis = 3.0 *. one_minus_t *. one_minus_t *. t
      let end_basis = 3.0 *. one_minus_t *. t *. t
      let fixed_point =
        add(
          scale(start, one_minus_t *. one_minus_t *. one_minus_t +. start_basis),
          scale(end, end_basis +. t *. t *. t),
        )
      let target = difference(point, fixed_point)
      let left_column = scale(start_direction, start_basis)
      let right_column = scale(end_direction, 0.0 -. end_basis)

      cubic_fit_normal_equations(
        rest,
        start:,
        end:,
        start_direction:,
        end_direction:,
        ata00: ata00 +. dot(left_column, left_column),
        ata01: ata01 +. dot(left_column, right_column),
        ata11: ata11 +. dot(right_column, right_column),
        atb0: atb0 +. dot(left_column, target),
        atb1: atb1 +. dot(right_column, target),
        count: count + 1,
      )
    }
  }
}

fn solve_cubic_fit_equations(
  ata00: Float,
  ata01: Float,
  ata11: Float,
  atb0: Float,
  atb1: Float,
  count: Int,
) -> Result(#(Float, Float), Error) {
  case count == 0 {
    True -> Error(UnderdeterminedCubicFit)
    False -> {
      let determinant = ata00 *. ata11 -. ata01 *. ata01
      case float.absolute_value(determinant) <=. root_tolerance {
        True -> Error(UnderdeterminedCubicFit)
        False ->
          Ok(#(
            { atb0 *. ata11 -. atb1 *. ata01 } /. determinant,
            { ata00 *. atb1 -. ata01 *. atb0 } /. determinant,
          ))
      }
    }
  }
}

fn cubic_endpoint_fit_normal_equations(
  samples: List(#(Float, BezierPoint)),
  start start: BezierPoint,
  end end: BezierPoint,
  ata00 ata00: Float,
  ata01 ata01: Float,
  ata11 ata11: Float,
  atb0 atb0: BezierPoint,
  atb1 atb1: BezierPoint,
  count count: Int,
) -> Result(#(BezierPoint, BezierPoint), Error) {
  case samples {
    [] ->
      solve_cubic_endpoint_fit_equations(ata00, ata01, ata11, atb0, atb1, count)
    [sample, ..rest] -> {
      let #(t, point) = sample
      let one_minus_t = 1.0 -. t
      let start_basis = one_minus_t *. one_minus_t *. one_minus_t
      let control1_basis = 3.0 *. one_minus_t *. one_minus_t *. t
      let control2_basis = 3.0 *. one_minus_t *. t *. t
      let end_basis = t *. t *. t
      let fixed_point = add(scale(start, start_basis), scale(end, end_basis))
      let target = difference(point, fixed_point)

      cubic_endpoint_fit_normal_equations(
        rest,
        start:,
        end:,
        ata00: ata00 +. control1_basis *. control1_basis,
        ata01: ata01 +. control1_basis *. control2_basis,
        ata11: ata11 +. control2_basis *. control2_basis,
        atb0: add(atb0, scale(target, control1_basis)),
        atb1: add(atb1, scale(target, control2_basis)),
        count: count + 1,
      )
    }
  }
}

fn solve_cubic_endpoint_fit_equations(
  ata00: Float,
  ata01: Float,
  ata11: Float,
  atb0: BezierPoint,
  atb1: BezierPoint,
  count: Int,
) -> Result(#(BezierPoint, BezierPoint), Error) {
  case count == 0 {
    True -> Error(UnderdeterminedCubicFit)
    False -> {
      let determinant = ata00 *. ata11 -. ata01 *. ata01
      case float.absolute_value(determinant) <=. root_tolerance {
        True -> Error(UnderdeterminedCubicFit)
        False ->
          Ok(#(
            scale(
              difference(scale(atb0, ata11), scale(atb1, ata01)),
              1.0 /. determinant,
            ),
            scale(
              difference(scale(atb1, ata00), scale(atb0, ata01)),
              1.0 /. determinant,
            ),
          ))
      }
    }
  }
}

fn cubic_fit_error(
  samples: List(#(Float, BezierPoint)),
  curve: BezierData,
) -> CubicFitError {
  let #(sum_squared, max_squared, count) =
    cubic_fit_error_loop(
      samples,
      curve,
      sum_squared: 0.0,
      max_squared: 0.0,
      count: 0,
    )

  case count == 0 {
    True -> CubicFitError(root_sum_square: 0.0, root_mean_square: 0.0, max: 0.0)
    False -> {
      let root_sum_square = sqrt(sum_squared)
      CubicFitError(
        root_sum_square:,
        root_mean_square: sqrt(sum_squared /. int.to_float(count)),
        max: sqrt(max_squared),
      )
    }
  }
}

fn cubic_fit_error_loop(
  samples: List(#(Float, BezierPoint)),
  curve: BezierData,
  sum_squared sum_squared: Float,
  max_squared max_squared: Float,
  count count: Int,
) -> #(Float, Float, Int) {
  case samples {
    [] -> #(sum_squared, max_squared, count)
    [sample, ..rest] -> {
      let #(t, point) = sample
      let fitted = bezier_point(curve, at: t)
      let error_squared = distance_squared(point, fitted)
      cubic_fit_error_loop(
        rest,
        curve,
        sum_squared: sum_squared +. error_squared,
        max_squared: float.max(max_squared, error_squared),
        count: count + 1,
      )
    }
  }
}

type Axis {
  XAxis
  YAxis
}

fn validate_cubic_self_intersection_options(
  options: CubicSelfIntersectionOptions,
) -> Result(Nil, Error) {
  case options.minimum_arc_length_separation <=. 0.0 {
    True ->
      Error(InvalidCubicSelfIntersectionMinimumArcLengthSeparation(
        options.minimum_arc_length_separation,
      ))
    False -> {
      case options.distance_tolerance <=. 0.0 {
        True ->
          Error(InvalidCubicSelfIntersectionDistanceTolerance(
            options.distance_tolerance,
          ))
        False -> Ok(Nil)
      }
    }
  }
}

fn cubic_power_coefficients(
  start: BezierPoint,
  control1: BezierPoint,
  control2: BezierPoint,
  end: BezierPoint,
) -> #(BezierPoint, BezierPoint, BezierPoint) {
  #(
    add(
      difference(end, scale(control2, 3.0)),
      difference(scale(control1, 3.0), start),
    ),
    add(
      difference(scale(start, 3.0), scale(control1, 6.0)),
      scale(control2, 3.0),
    ),
    difference(scale(control1, 3.0), scale(start, 3.0)),
  )
}

fn cubic_self_intersection_candidates(
  a: BezierPoint,
  b: BezierPoint,
  c: BezierPoint,
  preferred_axis preferred_axis: Axis,
) -> List(#(Float, Float)) {
  let primary = component(a, preferred_axis)
  let secondary_axis = other_axis(preferred_axis)

  case float.absolute_value(primary) <=. root_tolerance {
    True -> []
    False -> {
      let secondary = component(a, secondary_axis)
      let linear =
        component(b, secondary_axis)
        -. secondary
        *. component(b, preferred_axis)
        /. primary
      let constant =
        component(c, secondary_axis)
        -. secondary
        *. component(c, preferred_axis)
        /. primary

      case float.absolute_value(linear) <=. root_tolerance {
        True -> []
        False -> {
          let u = { 0.0 -. constant } /. linear
          let v =
            u
            *. u
            +. {
              component(b, preferred_axis) *. u +. component(c, preferred_axis)
            }
            /. primary

          parameters_from_sum_and_product(u, v)
        }
      }
    }
  }
}

fn parameters_from_sum_and_product(
  u: Float,
  v: Float,
) -> List(#(Float, Float)) {
  let discriminant = u *. u -. 4.0 *. v

  case discriminant <. 0.0 {
    True -> []
    False -> {
      let root = sqrt(discriminant)
      let first = { u -. root } /. 2.0
      let second = { u +. root } /. 2.0

      case first <=. second {
        True -> [#(first, second)]
        False -> [#(second, first)]
      }
    }
  }
}

fn filter_cubic_self_intersections(
  candidates: List(#(Float, Float)),
  curve: BezierData,
  options: CubicSelfIntersectionOptions,
  found: List(CubicSelfIntersection),
) -> List(CubicSelfIntersection) {
  case candidates {
    [] -> list.reverse(found)
    [candidate, ..rest] -> {
      case cubic_self_intersection_from_candidate(candidate, curve, options) {
        None -> filter_cubic_self_intersections(rest, curve, options, found)
        Some(intersection) -> {
          case cubic_self_intersection_already_found(intersection, found) {
            True -> filter_cubic_self_intersections(rest, curve, options, found)
            False ->
              filter_cubic_self_intersections(rest, curve, options, [
                intersection,
                ..found
              ])
          }
        }
      }
    }
  }
}

fn cubic_self_intersection_from_candidate(
  candidate: #(Float, Float),
  curve: BezierData,
  options: CubicSelfIntersectionOptions,
) -> option.Option(CubicSelfIntersection) {
  let #(s, t) = candidate
  case s >=. 0.0 && t <=. 1.0 {
    False -> None
    True -> {
      let left = bezier_point(curve, at: s)
      let right = bezier_point(curve, at: t)
      let arc_length =
        bezier_between(curve, from: s, to: t) |> approximate_length
      case
        arc_length >=. options.minimum_arc_length_separation
        && distance_squared(left, right)
        <=. options.distance_tolerance *. options.distance_tolerance
      {
        False -> None
        True ->
          Some(CubicSelfIntersection(s:, t:, point: midpoint(left, right)))
      }
    }
  }
}

fn cubic_self_intersection_already_found(
  intersection: CubicSelfIntersection,
  found: List(CubicSelfIntersection),
) -> Bool {
  let CubicSelfIntersection(s:, t:, ..) = intersection
  list.any(found, fn(found_intersection) {
    let CubicSelfIntersection(s: found_s, t: found_t, ..) = found_intersection
    float.absolute_value(s -. found_s) <=. root_tolerance
    && float.absolute_value(t -. found_t) <=. root_tolerance
  })
}

fn component(point: BezierPoint, axis: Axis) -> Float {
  case axis {
    XAxis -> point.x
    YAxis -> point.y
  }
}

fn other_axis(axis: Axis) -> Axis {
  case axis {
    XAxis -> YAxis
    YAxis -> XAxis
  }
}

fn midpoint(left: BezierPoint, right: BezierPoint) -> BezierPoint {
  BezierPoint({ left.x +. right.x } /. 2.0, { left.y +. right.y } /. 2.0)
}

fn approximate_length(curve: BezierData) -> Float {
  approximate_length_loop(curve, remaining_depth: 16)
}

fn approximate_length_loop(
  curve: BezierData,
  remaining_depth remaining_depth: Int,
) -> Float {
  let chord = distance(bezier_start(curve), bezier_end(curve))
  let polygon = control_polygon_length(curve)

  case remaining_depth <= 0 || polygon -. chord <=. root_tolerance {
    True -> { polygon +. chord } /. 2.0
    False -> {
      let #(left, right) = split_bezier(curve, at: 0.5)
      approximate_length_loop(left, remaining_depth: remaining_depth - 1)
      +. approximate_length_loop(right, remaining_depth: remaining_depth - 1)
    }
  }
}

fn control_polygon_length(curve: BezierData) -> Float {
  case curve {
    LinearBezierData(start:, end:) -> distance(start, end)
    QuadraticBezierData(start:, control:, end:) ->
      distance(start, control) +. distance(control, end)
    CubicBezierData(start:, control1:, control2:, end:) ->
      distance(start, control1)
      +. distance(control1, control2)
      +. distance(control2, end)
  }
}

fn distance(left: BezierPoint, right: BezierPoint) -> Float {
  distance_squared(left, right) |> sqrt
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

  root.quadratic(3.0 *. a, 2.0 *. b, c)
}

fn inflection_roots(
  start: BezierPoint,
  control1: BezierPoint,
  control2: BezierPoint,
  end: BezierPoint,
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

  root.quadratic_with(
    -6.0 *. cross(a, b),
    6.0 *. cross(c, a),
    2.0 *. cross(c, b),
    options: root.QuadraticOptions(
      coefficient_tolerance: 0.000000000001,
      repeated_root_policy: root.PreserveRepeatedRoot,
    ),
  )
}

fn is_inside_unit_interval(t: Float) -> Bool {
  t >=. 0.0 && t <=. 1.0
}

fn include_point(box: BoundingBox, point: BezierPoint) -> BoundingBox {
  BoundingBox(
    min: BezierPoint(
      float.min(box.min.x, point.x),
      float.min(box.min.y, point.y),
    ),
    max: BezierPoint(
      float.max(box.max.x, point.x),
      float.max(box.max.y, point.y),
    ),
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

fn interpolate(start: BezierPoint, end: BezierPoint, t: Float) -> BezierPoint {
  BezierPoint(
    start.x +. { end.x -. start.x } *. t,
    start.y +. { end.y -. start.y } *. t,
  )
}

fn difference(left: BezierPoint, right: BezierPoint) -> BezierPoint {
  BezierPoint(left.x -. right.x, left.y -. right.y)
}

fn add(left: BezierPoint, right: BezierPoint) -> BezierPoint {
  BezierPoint(left.x +. right.x, left.y +. right.y)
}

fn scale(point: BezierPoint, factor: Float) -> BezierPoint {
  BezierPoint(point.x *. factor, point.y *. factor)
}

fn unit(point: BezierPoint) -> Result(BezierPoint, Error) {
  let length = sqrt(distance_squared(point, BezierPoint(0.0, 0.0)))
  case length <=. root_tolerance {
    True -> Error(DegenerateTangent)
    False -> Ok(scale(point, 1.0 /. length))
  }
}

fn dot(left: BezierPoint, right: BezierPoint) -> Float {
  left.x *. right.x +. left.y *. right.y
}

fn distance_squared(left: BezierPoint, right: BezierPoint) -> Float {
  let dx = left.x -. right.x
  let dy = left.y -. right.y
  dx *. dx +. dy *. dy
}

fn sqrt(value: Float) -> Float {
  let assert Ok(root) = float.square_root(value)
  root
}

fn offset(
  point: BezierPoint,
  direction: BezierPoint,
  distance: Float,
) -> BezierPoint {
  BezierPoint(
    point.x +. direction.x *. distance,
    point.y +. direction.y *. distance,
  )
}

fn cross(left: BezierPoint, right: BezierPoint) -> Float {
  left.x *. right.y -. left.y *. right.x
}
