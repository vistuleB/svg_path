//// Curvature helpers for offset construction and diagnostics.
////
//// This module is intentionally more experimental than the root `svg_path`
//// API. Offset code needs curvature values, cusp residuals, and near-cusp band
//// classifiers before we know which helpers deserve a stable public surface.

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

/// Options for sampled cusp/root/band discovery.
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
/// Lines return zero second derivative. Arcs are converted to cubic Bezier
/// pieces only as a fallback for now; callers that need exact ellipse curvature
/// should use a later arc-specialized helper.
pub fn segment_derivatives(
  segment: svg_path.Segment,
  at t: Float,
) -> Result(Derivatives, svg_path.Error) {
  case segment {
    svg_path.Line(start:, end:) ->
      Ok(Derivatives(first: subtract(end, start), second: point(0.0, 0.0)))

    svg_path.QuadraticBezier(start:, control:, end:) -> {
      let first =
        add(
          scale(subtract(control, start), 2.0 *. { 1.0 -. t }),
          scale(subtract(end, control), 2.0 *. t),
        )
      let second =
        scale(add(subtract(end, control), subtract(start, control)), 2.0)
      Ok(Derivatives(first:, second:))
    }

    svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      let mt = 1.0 -. t
      let first =
        add3(
          scale(subtract(control1, start), 3.0 *. mt *. mt),
          scale(subtract(control2, control1), 6.0 *. mt *. t),
          scale(subtract(end, control2), 3.0 *. t *. t),
        )
      let second =
        add(
          scale(add(subtract(control2, scale(control1, 2.0)), start), 6.0 *. mt),
          scale(add(subtract(end, scale(control2, 2.0)), control1), 6.0 *. t),
        )
      Ok(Derivatives(first:, second:))
    }

    svg_path.Arc(..) -> arc_derivatives_by_cubic_fallback(segment, at: t)
  }
}

/// Return right-normal signed curvature at a segment parameter.
///
/// Positive values mean the curve bends toward the right normal used by
/// `svg_path/offset`; negative values mean it bends toward the left normal.
/// Lines return `0.0`. Degenerate zero-speed parameters return an error.
pub fn segment_right_normal_curvature(
  segment: svg_path.Segment,
  at t: Float,
) -> Result(Float, Nil) {
  use data <- result.try(segment_derivatives_nil(segment, at: t))
  use curvature <- result.try(left_normal_curvature_from_derivatives(data))
  Ok(0.0 -. curvature)
}

/// Return right-normal signed radius of curvature at a segment parameter.
///
/// Lines and inflection points return `Error(Nil)` because their radius is
/// infinite. Degenerate zero-speed parameters also return `Error(Nil)`.
pub fn segment_right_normal_radius(
  segment: svg_path.Segment,
  at t: Float,
) -> Result(Float, Nil) {
  use curvature <- result.try(segment_right_normal_curvature(segment, at: t))
  case curvature == 0.0 {
    True -> Error(Nil)
    False -> Ok(1.0 /. curvature)
  }
}

/// Return `abs(R_right(t) - distance) < margin` without evaluating `R_right(t)`
/// directly.
///
/// Algebraically, for finite nonzero curvature this is equivalent to:
///
/// `abs(|p'|^3 + distance * cross(p', p'')) < margin * abs(cross(p', p''))`.
pub fn segment_right_normal_radius_close_to(
  segment: svg_path.Segment,
  distance distance: Float,
  margin margin: Float,
  at t: Float,
) -> Result(Bool, Nil) {
  case margin <. 0.0 || !number.is_finite(margin) {
    True -> Error(Nil)
    False -> {
      use data <- result.try(segment_derivatives_nil(segment, at: t))
      right_normal_radius_close_to(data, distance: distance, margin: margin)
    }
  }
}

/// Return the right-normal cusp residual
/// `|p'|^3 + distance * cross(p', p'')`.
///
/// A zero residual means the right-normal signed radius equals `distance`,
/// assuming finite nonzero curvature.
@internal
pub fn segment_right_normal_cusp_residual(
  segment: svg_path.Segment,
  distance distance: Float,
  at t: Float,
) -> Result(Float, Nil) {
  use data <- result.try(segment_derivatives_nil(segment, at: t))
  right_normal_cusp_residual_from_derivatives(data, distance: distance)
}

/// Sample and refine parameters where right-normal signed radius equals
/// `distance`.
///
/// This is conservative root discovery over the cusp residual. It detects
/// sign-changing roots and exact sampled roots. Repeated roots that do not
/// change sign can be added later using polynomial candidates.
pub fn segment_right_normal_cusp_parameters(
  segment: svg_path.Segment,
  distance distance: Float,
  options options: Options,
) -> Result(List(Float), Nil) {
  use _ <- result.try(validate_options(options))
  let residual = fn(t) {
    segment_right_normal_cusp_residual(segment, distance:, at: t)
  }
  sampled_roots(residual, options)
}

/// Sample and refine interior inflection parameters.
///
/// This solves `cross(p'(t), p''(t)) = 0`. Lines and identically flat pieces
/// return an empty list. Roots at the segment endpoints are filtered out.
pub fn segment_inflection_parameters(
  segment: svg_path.Segment,
  options options: Options,
) -> Result(List(Float), Nil) {
  use _ <- result.try(validate_options(options))
  case segment {
    svg_path.Line(..) -> Ok([])
    svg_path.CubicBezier(start:, control1:, control2:, end:) ->
      bezier.CubicBezierData(
        start: to_bezier_point(start),
        control1: to_bezier_point(control1),
        control2: to_bezier_point(control2),
        end: to_bezier_point(end),
      )
      |> bezier.cubic_inflection_parameters
      |> Ok

    _ ->
      case segment_inflection_residual_is_flat(segment, options.tolerance) {
        True -> Ok([])
        False -> {
          let residual = fn(t) { segment_inflection_residual(segment, at: t) }
          use roots <- result.try(sampled_roots(residual, options))
          Ok(
            roots
            |> list.filter(fn(t) {
              t >. options.tolerance && t <. 1.0 -. options.tolerance
            }),
          )
        }
      }
  }
}

fn to_bezier_point(point: svg_path.Point) -> bezier.BezierPoint {
  bezier.BezierPoint(point.x, point.y)
}

/// Sample intervals where right-normal signed radius is within `margin` of
/// `distance`.
///
/// This is a conservative sampled classifier. Adjacent close samples are merged
/// into parameter bands. It is intended as a first staging helper for offset
/// stalled-run detection, not as a final exact algebraic interval solver.
pub fn segment_right_normal_radius_close_bands(
  segment: svg_path.Segment,
  distance distance: Float,
  margin margin: Float,
  options options: Options,
) -> Result(List(CurvatureBand), Nil) {
  use _ <- result.try(validate_options(options))
  case margin <. 0.0 || !number.is_finite(margin) {
    True -> Error(Nil)
    False -> {
      let close = fn(t) {
        segment_right_normal_radius_close_to(segment, distance:, margin:, at: t)
      }
      sampled_bands(close, options)
    }
  }
}

fn segment_derivatives_nil(
  segment: svg_path.Segment,
  at t: Float,
) -> Result(Derivatives, Nil) {
  segment_derivatives(segment, at: t)
  |> result.map_error(fn(_) { Nil })
}

fn left_normal_curvature_from_derivatives(
  data: Derivatives,
) -> Result(Float, Nil) {
  let Derivatives(first:, second:) = data
  let speed_squared = dot(first, first)
  case speed_squared <=. 0.0 || !number.is_finite(speed_squared) {
    True -> Error(Nil)
    False -> {
      let assert Ok(speed) = float.square_root(speed_squared)
      Ok(cross(first, second) /. { speed_squared *. speed })
    }
  }
}

fn right_normal_radius_close_to(
  data: Derivatives,
  distance distance: Float,
  margin margin: Float,
) -> Result(Bool, Nil) {
  let Derivatives(first:, second:) = data
  let speed_squared = dot(first, first)
  let c = cross(first, second)
  case speed_squared <=. 0.0 || c == 0.0 || !number.is_finite(speed_squared) {
    True -> Error(Nil)
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

fn right_normal_cusp_residual_from_derivatives(
  data: Derivatives,
  distance distance: Float,
) -> Result(Float, Nil) {
  let Derivatives(first:, second:) = data
  let speed_squared = dot(first, first)
  case speed_squared <=. 0.0 || !number.is_finite(speed_squared) {
    True -> Error(Nil)
    False -> {
      let assert Ok(speed) = float.square_root(speed_squared)
      Ok(speed_squared *. speed +. distance *. cross(first, second))
    }
  }
}

fn segment_inflection_residual(
  segment: svg_path.Segment,
  at t: Float,
) -> Result(Float, Nil) {
  use data <- result.try(segment_derivatives_nil(segment, at: t))
  let Derivatives(first:, second:) = data
  Ok(cross(first, second))
}

fn segment_inflection_residual_is_flat(
  segment: svg_path.Segment,
  tolerance: Float,
) -> Bool {
  [0.0, 0.25, 0.5, 0.75, 1.0]
  |> list.all(fn(t) {
    case segment_inflection_residual(segment, at: t) {
      Ok(value) -> float.absolute_value(value) <=. tolerance
      Error(_) -> False
    }
  })
}

fn sampled_roots(
  f: fn(Float) -> Result(Float, Nil),
  options: Options,
) -> Result(List(Float), Nil) {
  sampled_roots_loop(f, options, index: 0, roots: [])
  |> result.map(unique_sorted_parameters(_, options.tolerance))
}

fn sampled_roots_loop(
  f: fn(Float) -> Result(Float, Nil),
  options: Options,
  index index: Int,
  roots roots: List(Float),
) -> Result(List(Float), Nil) {
  case index >= options.samples {
    True -> Ok(roots)
    False -> {
      let a = int_to_float(index) /. int_to_float(options.samples)
      let b = int_to_float(index + 1) /. int_to_float(options.samples)
      let roots = case f(a), f(b) {
        Ok(va), Ok(vb) -> {
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
  f: fn(Float) -> Result(Float, Nil),
  a: Float,
  b: Float,
  va: Float,
  vb: Float,
  options: Options,
  depth depth: Int,
) -> Result(Float, Nil) {
  case
    depth >= options.max_depth
    || float.absolute_value(b -. a) <=. options.tolerance
  {
    True -> Ok({ a +. b } /. 2.0)
    False -> {
      let mid = { a +. b } /. 2.0
      use vm <- result.try(f(mid))
      case vm == 0.0 {
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
  close: fn(Float) -> Result(Bool, Nil),
  options: Options,
) -> Result(List(CurvatureBand), Nil) {
  sampled_bands_loop(close, options, index: 0, open: None, bands: [])
}

fn sampled_bands_loop(
  close: fn(Float) -> Result(Bool, Nil),
  options: Options,
  index index: Int,
  open open: Option(Float),
  bands bands: List(CurvatureBand),
) -> Result(List(CurvatureBand), Nil) {
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

fn validate_options(options: Options) -> Result(Nil, Nil) {
  case
    options.tolerance <=. 0.0
    || !number.is_finite(options.tolerance)
    || options.samples <= 0
    || options.max_depth <= 0
  {
    True -> Error(Nil)
    False -> Ok(Nil)
  }
}

fn arc_derivatives_by_cubic_fallback(
  segment: svg_path.Segment,
  at t: Float,
) -> Result(Derivatives, svg_path.Error) {
  case svg_path.segment_to_cubic_beziers(segment) {
    [] -> Error(svg_path.DegenerateArc)
    [first, ..] -> segment_derivatives(first, at: clamp(t, min: 0.0, max: 1.0))
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

fn point(x: Float, y: Float) -> svg_path.Point {
  svg_path.Point(x, y)
}

fn add(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  point(a.x +. b.x, a.y +. b.y)
}

fn add3(
  a: svg_path.Point,
  b: svg_path.Point,
  c: svg_path.Point,
) -> svg_path.Point {
  add(add(a, b), c)
}

fn subtract(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  point(a.x -. b.x, a.y -. b.y)
}

fn scale(a: svg_path.Point, factor: Float) -> svg_path.Point {
  point(a.x *. factor, a.y *. factor)
}

fn dot(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.x +. a.y *. b.y
}

fn cross(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.y -. a.y *. b.x
}

fn clamp(value: Float, min min: Float, max max: Float) -> Float {
  float.max(min, float.min(max, value))
}

fn int_to_float(value: Int) -> Float {
  int.to_float(value)
}
