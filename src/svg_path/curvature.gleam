//// Signed curvature, radius, inflection points, and offset-cusp diagnostics.
////
//// Signs refer to the visual left normal in SVG coordinates (positive y down).
//// Curvature has inverse-length units; radius, target distances, and margins
//// have length units. Parameters refer to the segment's `0.0..1.0` interval.
////
//// Pointwise queries evaluate segment derivatives directly. Cusp-parameter and
//// near-radius-band discovery use sampling and are not exhaustive root or
//// interval solvers; their individual contracts describe the limitations.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import svg_path
import svg_path/bezier
import svg_path/internal/number

const default_tolerance = 0.000000001

const default_samples = 100

const default_max_depth = 32

/// Error returned by curvature helpers.
///
/// Cases distinguish invalid options (carrying the supplied value), underlying
/// path-operation failures, and degenerate or infinite curvature geometry.
pub type Error {
  /// An underlying segment derivative query failed, for example arc conversion.
  PathError(error: svg_path.Error)
  /// A curvature `tolerance` option was invalid (not finite or negative).
  InvalidCurvatureTolerance(tolerance: Float)
  /// A curvature `samples` option was invalid (not positive).
  InvalidCurvatureSamples(samples: Int)
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
}

/// Options for sampled cusp/root/band discovery.
/// All fields are validated by discovery functions. Band discovery uses only
/// `samples`; inflection discovery is algebraic and uses none of these fields
/// after validation.
pub type Options {
  Options(
    /// Numeric tolerance for roots and interval widths in parameter space.
    tolerance: Float,
    /// Initial number of sample windows on `0.0..1.0`.
    samples: Int,
    /// Maximum bisection/subdivision depth.
    max_depth: Int,
  )
}

/// First and second derivative data at a segment parameter.
pub type Derivatives {
  Derivatives(first: svg_path.Point, second: svg_path.Point)
}

/// A sampled interval where the signed radius of curvature is close to a target
/// offset distance.
pub type CurvatureBand {
  CurvatureBand(from: Float, to: Float)
}

/// Return default curvature options.
pub fn default_options() -> Options {
  Options(
    tolerance: default_tolerance,
    samples: default_samples,
    max_depth: default_max_depth,
  )
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

/// Sample and refine parameters where visual-left-normal signed radius equals
/// `distance`.
///
/// Samples the cusp residual on a uniform grid and bisects sign-changing
/// windows. Exact sampled zeros are included. Multiple roots within one window
/// and non-sign-changing roots between samples may be missed. Windows whose
/// evaluations fail are skipped, including failed bisections. At `max_depth`,
/// bisection returns the current midpoint without an accuracy guarantee.
/// Results are sorted and merged within `options.tolerance` in parameter space.
pub fn segment_left_normal_cusp_parameters(
  segment: svg_path.Segment,
  distance distance: Float,
  options options: Options,
) -> Result(List(Float), Error) {
  use _ <- result.try(validate_options(options))
  let residual = fn(t) {
    segment_left_normal_cusp_residual(segment, distance:, at: t)
  }
  sampled_roots(residual, options)
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

/// Sample intervals where visual-left-normal signed radius is within `margin` of
/// `distance`.
///
/// Adjacent close samples on a uniform grid are merged into parameter bands.
/// A band starts at its first close sample and ends at the first subsequent
/// non-close sample (or `1.0`). Evaluation errors count as non-close samples.
/// These bands are approximate: narrow intervals may be missed, and not every
/// point inside a returned band is guaranteed to satisfy the predicate.
pub fn segment_left_normal_radius_close_bands(
  segment: svg_path.Segment,
  distance distance: Float,
  margin margin: Float,
  options options: Options,
) -> Result(List(CurvatureBand), Error) {
  use _ <- result.try(validate_options(options))
  case margin <. 0.0 || !number.is_finite(margin) {
    True -> Error(InvalidCurvatureMargin(margin))
    False -> {
      let close = fn(t) {
        segment_left_normal_radius_close_to(segment, distance:, margin:, at: t)
      }
      sampled_bands(close, options)
    }
  }
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

fn sampled_roots(
  f: fn(Float) -> Result(Float, Error),
  options: Options,
) -> Result(List(Float), Error) {
  sampled_roots_loop(f, options, index: 0, roots: [])
  |> result.map(unique_sorted_parameters(_, options.tolerance))
}

fn sampled_roots_loop(
  f: fn(Float) -> Result(Float, Error),
  options: Options,
  index index: Int,
  roots roots: List(Float),
) -> Result(List(Float), Error) {
  case index >= options.samples {
    True -> Ok(roots)
    False -> {
      let a = int_to_float(index) /. int_to_float(options.samples)
      let b = int_to_float(index + 1) /. int_to_float(options.samples)
      let roots = case f(a), f(b) {
        Ok(va), Ok(vb) -> {
          let roots = case number.is_zero(va) {
            True -> [a, ..roots]
            False -> roots
          }
          let roots = case number.is_zero(vb) {
            True -> [b, ..roots]
            False -> roots
          }
          case sign_change(va, vb) {
            True -> {
              case refine_root(f, a, b, va, vb, options, depth: 0) {
                Ok(root) -> [root, ..roots]
                Error(_) -> roots
              }
            }
            False -> roots
          }
        }
        _, _ -> roots
      }
      sampled_roots_loop(f, options, index: index + 1, roots:)
    }
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
  case
    depth >= options.max_depth
    || float.absolute_value(b -. a) <=. options.tolerance
  {
    True -> Ok({ a +. b } /. 2.0)
    False -> {
      let mid = { a +. b } /. 2.0
      use vm <- result.try(f(mid))
      case number.is_zero(vm) {
        True -> Ok(mid)
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

fn sampled_bands(
  close: fn(Float) -> Result(Bool, Error),
  options: Options,
) -> Result(List(CurvatureBand), Error) {
  sampled_bands_loop(close, options, index: 0, open: None, bands: [])
}

fn sampled_bands_loop(
  close: fn(Float) -> Result(Bool, Error),
  options: Options,
  index index: Int,
  open open: Option(Float),
  bands bands: List(CurvatureBand),
) -> Result(List(CurvatureBand), Error) {
  case index > options.samples {
    True -> {
      let bands = case open {
        Some(from) -> [CurvatureBand(from:, to: 1.0), ..bands]
        None -> bands
      }
      Ok(list.reverse(bands))
    }
    False -> {
      let t = int_to_float(index) /. int_to_float(options.samples)
      let is_close = case close(t) {
        Ok(True) -> True
        _ -> False
      }
      case is_close, open {
        True, None ->
          sampled_bands_loop(
            close,
            options,
            index: index + 1,
            open: Some(t),
            bands:,
          )
        True, Some(_) ->
          sampled_bands_loop(close, options, index: index + 1, open:, bands:)
        False, Some(from) ->
          sampled_bands_loop(
            close,
            options,
            index: index + 1,
            open: None,
            bands: [CurvatureBand(from:, to: t), ..bands],
          )
        False, None ->
          sampled_bands_loop(close, options, index: index + 1, open:, bands:)
      }
    }
  }
}

fn validate_options(options: Options) -> Result(Nil, Error) {
  case options.tolerance <. 0.0 || !number.is_finite(options.tolerance) {
    True -> Error(InvalidCurvatureTolerance(options.tolerance))
    False ->
      case options.samples <= 0 {
        True -> Error(InvalidCurvatureSamples(options.samples))
        False ->
          case options.max_depth <= 0 {
            True -> Error(InvalidCurvatureMaxDepth(options.max_depth))
            False -> Ok(Nil)
          }
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

fn int_to_float(value: Int) -> Float {
  int.to_float(value)
}
