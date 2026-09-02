//// Bracketed root-finding helpers for scalar functions.
////
//// Polynomial root isolation partitions an interval at derivative roots, then
//// refines each sign-changing monotone window with bracketed bisection.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

const parameter_tolerance = 0.000000001

const relative_value_tolerance = 0.000000000001

const default_max_iterations = 100

/// Errors returned by root-finding helpers.
@internal
pub type Error {
  /// The maximum iteration count must be greater than zero.
  InvalidMaxIterations(max_iterations: Int)

  /// The function values at the bracket endpoints do not have opposite signs.
  NotBracketed(left: Float, right: Float, left_value: Float, right_value: Float)

  /// The solver did not converge within the configured iteration count.
  MaxIterationsReached(estimate: Float, value: Float)
}

/// Whether a repeated quadratic root is returned once or with its algebraic
/// multiplicity of two.
@internal
pub type RepeatedRootPolicy {
  ConsolidateRepeatedRoot
  PreserveRepeatedRoot
}

/// Options for solving a quadratic equation.
@internal
pub type QuadraticOptions {
  QuadraticOptions(
    coefficient_tolerance: Float,
    repeated_root_policy: RepeatedRootPolicy,
  )
}

/// Options for isolating and refining real polynomial roots.
///
/// Polynomial roots use a fixed parameter tolerance of `1e-9` and a fixed
/// coefficient-relative value tolerance of `1e-12` throughout the package.
@internal
pub type PolynomialOptions {
  PolynomialOptions(max_iterations: Int)
}

/// A real polynomial root and the final parameter window used by its caller.
///
/// Crossing roots retain their sign-changing bisection bracket. Direct and
/// repeated-root estimates receive a centered `1e-9` window, clamped to the
/// requested domain and away from neighboring root windows.
@internal
pub type RootIsolation {
  RootIsolation(lower: Float, estimate: Float, upper: Float)
}

/// The sign behavior of a scalar function around an isolated root.
@internal
pub type RootKind {
  NegativeToPositive
  PositiveToNegative
  NegativeToNegative
  PositiveToPositive
  Ambiguous
}

/// A real polynomial root with its local sign behavior.
@internal
pub type ClassifiedRoot {
  ClassifiedRoot(isolation: RootIsolation, kind: RootKind)
}

/// Return the default options for polynomial root isolation.
@internal
pub fn default_polynomial_options() -> PolynomialOptions {
  PolynomialOptions(max_iterations: default_max_iterations)
}

/// Solve `a * x + b = 0` using exact zero classification.
///
/// An identically zero or inconsistent constant equation returns no isolated
/// roots.
@internal
pub fn linear(a: Float, b: Float) -> List(Float) {
  linear_with_tolerance(a, b, 0.0)
}

/// Solve `a * x² + b * x + c = 0` using exact degree classification.
///
/// Real roots are returned in formula order. A repeated root is returned once.
@internal
pub fn quadratic(a: Float, b: Float, c: Float) -> List(Float) {
  quadratic_with(
    a,
    b,
    c,
    options: QuadraticOptions(
      coefficient_tolerance: 0.0,
      repeated_root_policy: ConsolidateRepeatedRoot,
    ),
  )
}

/// Solve `a * x² + b * x + c = 0` with explicit degree and multiplicity
/// policy.
///
/// Coefficients whose absolute value is less than `coefficient_tolerance` are
/// treated as zero. A zero or negative tolerance uses exact zero comparison.
@internal
pub fn quadratic_with(
  a: Float,
  b: Float,
  c: Float,
  options options: QuadraticOptions,
) -> List(Float) {
  let tolerance = float.max(options.coefficient_tolerance, 0.0)
  case coefficient_is_zero(a, tolerance) {
    True -> linear_with_tolerance(b, c, tolerance)
    False -> {
      let discriminant = b *. b -. { 4.0 *. a *. c }
      case discriminant <. 0.0 {
        True -> []
        False -> {
          let assert Ok(root_discriminant) = float.square_root(discriminant)
          let denominator = 2.0 *. a
          let root = { 0.0 -. b } /. denominator
          case root_discriminant == 0.0, options.repeated_root_policy {
            True, ConsolidateRepeatedRoot -> [root]
            True, PreserveRepeatedRoot -> [root, root]
            False, _ -> {
              // Choose the numerator that adds same-sign magnitudes, then use
              // the product of the roots, c / a, to recover the other root.
              // This avoids cancelling nearly equal values in the smaller
              // root's direct quadratic-formula numerator.
              let q = case b >=. 0.0 {
                True -> -0.5 *. { b +. root_discriminant }
                False -> -0.5 *. { b -. root_discriminant }
              }
              let stable_root = q /. a
              let recovered_root = c /. q

              // Preserve the documented direct-formula order: the root from
              // (-b - sqrt(discriminant)) precedes the root from
              // (-b + sqrt(discriminant)), regardless of the sign of a.
              case b >=. 0.0 {
                True -> [stable_root, recovered_root]
                False -> [recovered_root, stable_root]
              }
            }
          }
        }
      }
    }
  }
}

/// Keep roots strictly inside an interval and return them in ascending order.
@internal
pub fn strictly_inside(
  roots: List(Float),
  from lower: Float,
  to upper: Float,
) -> List(Float) {
  let #(lower, upper) = ordered_bracket(lower, upper)
  roots
  |> list.filter(fn(value) { value >. lower && value <. upper })
  |> list.sort(by: float.compare)
}

/// Keep roots inside a closed interval and return them in ascending order.
@internal
pub fn inside(
  roots: List(Float),
  from lower: Float,
  to upper: Float,
) -> List(Float) {
  let #(lower, upper) = ordered_bracket(lower, upper)
  roots
  |> list.filter(fn(value) { value >=. lower && value <=. upper })
  |> list.sort(by: float.compare)
}

/// Evaluate a power-basis polynomial whose coefficients are ordered from the
/// highest power to the constant term.
@internal
pub fn evaluate_polynomial(coefficients: List(Float), at x: Float) -> Float {
  list.fold(coefficients, 0.0, fn(value, coefficient) {
    value *. x +. coefficient
  })
}

/// Differentiate power-basis coefficients ordered from highest power to the
/// constant term.
@internal
pub fn polynomial_derivative(coefficients: List(Float)) -> List(Float) {
  polynomial_derivative_loop(
    coefficients,
    degree: list.length(coefficients) - 1,
    differentiated: [],
  )
}

/// Find all distinct real roots of a power-basis polynomial in a closed
/// interval.
///
/// Derivative roots partition the interval into monotone pieces. Sign-changing
/// roots are refined with bracketed bisection, while roots shared with the
/// derivative preserve even-multiplicity roots that do not change sign.
@internal
pub fn polynomial_roots_with(
  coefficients: List(Float),
  from lower: Float,
  to upper: Float,
  options options: PolynomialOptions,
) -> Result(List(Float), Error) {
  case options.max_iterations <= 0 {
    True -> Error(InvalidMaxIterations(options.max_iterations))
    False -> {
      let coefficients = normalize_polynomial_coefficients(coefficients)
      let #(lower, upper) = ordered_bracket(lower, upper)
      use isolations <- result.try(polynomial_root_isolations_valid(
        coefficients,
        lower,
        upper,
        options,
      ))
      Ok(list.map(isolations, fn(isolation) { isolation.estimate }))
    }
  }
}

/// Isolate every distinct real root in a closed interval.
///
/// This internal API preserves the final brackets used by geometric callers.
@internal
pub fn polynomial_root_isolations_with(
  coefficients: List(Float),
  from lower: Float,
  to upper: Float,
  options options: PolynomialOptions,
) -> Result(List(RootIsolation), Error) {
  case options.max_iterations <= 0 {
    True -> Error(InvalidMaxIterations(options.max_iterations))
    False -> {
      let coefficients = normalize_polynomial_coefficients(coefficients)
      let #(lower, upper) = ordered_bracket(lower, upper)
      use isolations <- result.try(polynomial_root_isolations_valid(
        coefficients,
        lower,
        upper,
        options,
      ))
      Ok(finalize_root_windows(isolations, lower, upper))
    }
  }
}

/// Find all distinct real roots of a power-basis polynomial in a closed
/// interval, preserving local sign behavior around each root.
@internal
pub fn classified_polynomial_roots_with(
  coefficients: List(Float),
  from lower: Float,
  to upper: Float,
  options options: PolynomialOptions,
) -> Result(List(ClassifiedRoot), Error) {
  case options.max_iterations <= 0 {
    True -> Error(InvalidMaxIterations(options.max_iterations))
    False -> {
      let coefficients = normalize_polynomial_coefficients(coefficients)
      let #(lower, upper) = ordered_bracket(lower, upper)
      use isolations <- result.try(polynomial_root_isolations_valid(
        coefficients,
        lower,
        upper,
        options,
      ))
      let isolations = finalize_root_windows(isolations, lower, upper)
      let value_scale = polynomial_value_scale(coefficients)
      Ok(
        list.map(isolations, fn(isolation) {
          ClassifiedRoot(
            isolation:,
            kind: classify_polynomial_root(coefficients, isolation, value_scale),
          )
        }),
      )
    }
  }
}

/// Find classified real roots of `a*x + b` in `[0, 1]`.
@internal
pub fn real_linear_01_roots(
  a: Float,
  b: Float,
  options options: PolynomialOptions,
) -> Result(List(ClassifiedRoot), Error) {
  classified_polynomial_roots_with([a, b], from: 0.0, to: 1.0, options:)
}

/// Find classified real roots of `a*x² + b*x + c` in `[0, 1]`.
@internal
pub fn real_quadratic_01_roots(
  a: Float,
  b: Float,
  c: Float,
  options options: PolynomialOptions,
) -> Result(List(ClassifiedRoot), Error) {
  classified_polynomial_roots_with([a, b, c], from: 0.0, to: 1.0, options:)
}

/// Find classified real roots of `a*x³ + b*x² + c*x + d` in `[0, 1]`.
@internal
pub fn real_cubic_01_roots(
  a: Float,
  b: Float,
  c: Float,
  d: Float,
  options options: PolynomialOptions,
) -> Result(List(ClassifiedRoot), Error) {
  classified_polynomial_roots_with([a, b, c, d], from: 0.0, to: 1.0, options:)
}

/// Whether a classified root changes sign.
@internal
pub fn is_sign_change_root(kind: RootKind) -> Bool {
  case kind {
    NegativeToPositive | PositiveToNegative -> True
    NegativeToNegative | PositiveToPositive | Ambiguous -> False
  }
}

/// Alias for `is_sign_change_root`.
@internal
pub fn is_crossing_root(kind: RootKind) -> Bool {
  is_sign_change_root(kind)
}

/// Find all distinct real roots of `a*x³ + b*x² + c*x + d`.
@internal
pub fn cubic(
  a: Float,
  b: Float,
  c: Float,
  d: Float,
) -> Result(List(Float), Error) {
  cubic_with(a, b, c, d, options: default_polynomial_options())
}

/// Find all distinct real roots of a cubic using explicit numerical options.
fn cubic_with(
  a: Float,
  b: Float,
  c: Float,
  d: Float,
  options options: PolynomialOptions,
) -> Result(List(Float), Error) {
  case options.max_iterations <= 0 {
    True -> Error(InvalidMaxIterations(options.max_iterations))
    False -> {
      let coefficients = normalize_polynomial_coefficients([a, b, c, d])
      case coefficients {
        [] | [_] -> Ok([])
        [linear_a, linear_b] -> Ok(linear(linear_a, linear_b))
        [quadratic_a, quadratic_b, quadratic_c] ->
          Ok(quadratic_with(
            quadratic_a,
            quadratic_b,
            quadratic_c,
            options: QuadraticOptions(
              coefficient_tolerance: polynomial_coefficient_tolerance(
                coefficients,
              ),
              repeated_root_policy: ConsolidateRepeatedRoot,
            ),
          ))
        [leading, ..rest] -> {
          let bound = polynomial_root_bound(leading, rest)
          polynomial_roots_with(
            coefficients,
            from: 0.0 -. bound,
            to: bound,
            options:,
          )
        }
      }
    }
  }
}

fn distinct_isolations(isolations: List(RootIsolation)) -> List(RootIsolation) {
  isolations
  |> list.sort(by: fn(left, right) {
    float.compare(left.estimate, right.estimate)
  })
  |> distinct_sorted_isolations(kept: [])
}

fn distinct_sorted_isolations(
  isolations: List(RootIsolation),
  kept kept: List(RootIsolation),
) -> List(RootIsolation) {
  case isolations, kept {
    [], _ -> list.reverse(kept)
    [first, ..rest], [] -> distinct_sorted_isolations(rest, kept: [first])
    [first, ..rest], [previous, ..] ->
      case first.estimate == previous.estimate {
        True -> distinct_sorted_isolations(rest, kept:)
        False -> distinct_sorted_isolations(rest, kept: [first, ..kept])
      }
  }
}

fn polynomial_root_isolations_valid(
  coefficients: List(Float),
  lower: Float,
  upper: Float,
  options: PolynomialOptions,
) -> Result(List(RootIsolation), Error) {
  let coefficient_tolerance = polynomial_coefficient_tolerance(coefficients)
  case coefficients {
    [] | [_] -> Ok([])
    [a, b] ->
      Ok(
        linear_with_tolerance(a, b, coefficient_tolerance)
        |> inside(from: lower, to: upper)
        |> list.map(fn(root) { RootIsolation(root, root, root) }),
      )
    [a, b, c] ->
      Ok(
        quadratic_with(
          a,
          b,
          c,
          options: QuadraticOptions(
            coefficient_tolerance:,
            repeated_root_policy: ConsolidateRepeatedRoot,
          ),
        )
        |> inside(from: lower, to: upper)
        |> list.map(fn(root) { RootIsolation(root, root, root) }),
      )
    _ -> {
      let derivative = polynomial_derivative(coefficients)
      use critical <- result.try(polynomial_root_isolations_valid(
        derivative,
        lower,
        upper,
        options,
      ))
      let critical = distinct_isolations(critical)
      let critical_values =
        list.map(critical, fn(isolation) {
          let RootIsolation(estimate:, ..) = isolation
          estimate
        })
      let repeated =
        critical
        |> list.filter(fn(isolation) {
          let RootIsolation(estimate:, ..) = isolation
          value_is_close_to_zero(
            evaluate_polynomial(coefficients, at: estimate),
            polynomial_value_scale(coefficients),
          )
        })
        |> list.map(fn(isolation) {
          RootIsolation(
            isolation.estimate,
            isolation.estimate,
            isolation.estimate,
          )
        })
      let endpoints =
        [lower, upper]
        |> list.filter(fn(value) {
          value_is_close_to_zero(
            evaluate_polynomial(coefficients, at: value),
            polynomial_value_scale(coefficients),
          )
        })
        |> list.map(fn(root) { RootIsolation(root, root, root) })
      use crossing <- result.try(
        polynomial_crossing_roots(
          coefficients,
          [lower, ..list.append(critical_values, [upper])],
          options,
          roots: [],
        ),
      )
      Ok(
        list.append(endpoints, list.append(repeated, crossing))
        |> distinct_isolations,
      )
    }
  }
}

fn polynomial_crossing_roots(
  coefficients: List(Float),
  boundaries: List(Float),
  options: PolynomialOptions,
  roots roots: List(RootIsolation),
) -> Result(List(RootIsolation), Error) {
  polynomial_crossing_roots_loop(coefficients, boundaries, options, roots:)
}

fn polynomial_crossing_roots_loop(
  coefficients: List(Float),
  boundaries: List(Float),
  options: PolynomialOptions,
  roots roots: List(RootIsolation),
) -> Result(List(RootIsolation), Error) {
  case boundaries {
    [] | [_] -> Ok(roots)
    [left, right, ..rest] -> {
      let left_value = evaluate_polynomial(coefficients, at: left)
      let right_value = evaluate_polynomial(coefficients, at: right)
      let value_scale = polynomial_value_scale(coefficients)
      case
        same_sign(left_value, right_value)
        || value_is_close_to_zero(left_value, value_scale)
        || value_is_close_to_zero(right_value, value_scale)
      {
        True ->
          polynomial_crossing_roots_loop(
            coefficients,
            [right, ..rest],
            options,
            roots:,
          )
        False -> {
          use found <- result.try(polynomial_refine_bracket(
            coefficients,
            left,
            left_value,
            right,
            parameter_tolerance,
            options.max_iterations,
          ))
          polynomial_crossing_roots_loop(
            coefficients,
            [right, ..rest],
            options,
            roots: [found, ..roots],
          )
        }
      }
    }
  }
}

fn polynomial_refine_bracket(
  coefficients: List(Float),
  left: Float,
  left_value: Float,
  right: Float,
  tolerance: Float,
  remaining_iterations: Int,
) -> Result(RootIsolation, Error) {
  let midpoint = left +. { right -. left } /. 2.0
  let midpoint_value = evaluate_polynomial(coefficients, at: midpoint)
  case right -. left <=. tolerance {
    True -> Ok(RootIsolation(left, midpoint, right))
    False ->
      case remaining_iterations <= 1 {
        True -> Error(MaxIterationsReached(midpoint, midpoint_value))
        False -> {
          let proposal = midpoint
          let proposal_value = evaluate_polynomial(coefficients, at: proposal)
          case proposal_value == 0.0 {
            True -> Ok(RootIsolation(left, proposal, right))
            False ->
              case same_sign(left_value, proposal_value) {
                True ->
                  polynomial_refine_bracket(
                    coefficients,
                    proposal,
                    proposal_value,
                    right,
                    tolerance,
                    remaining_iterations - 1,
                  )
                False ->
                  polynomial_refine_bracket(
                    coefficients,
                    left,
                    left_value,
                    proposal,
                    tolerance,
                    remaining_iterations - 1,
                  )
              }
          }
        }
      }
  }
}

fn classify_polynomial_root(
  coefficients: List(Float),
  isolation: RootIsolation,
  value_scale: Float,
) -> RootKind {
  let RootIsolation(lower:, estimate:, upper:) = isolation
  let sampled =
    classify_root_signs(
      evaluate_polynomial(coefficients, at: lower),
      evaluate_polynomial(coefficients, at: upper),
      value_scale,
    )
  case sampled {
    Ambiguous -> classify_root_from_derivatives(coefficients, estimate)
    kind -> kind
  }
}

fn classify_root_from_derivatives(
  coefficients: List(Float),
  estimate: Float,
) -> RootKind {
  classify_root_from_derivatives_loop(
    polynomial_derivative(coefficients),
    estimate,
    order: 1,
  )
}

fn classify_root_from_derivatives_loop(
  coefficients: List(Float),
  estimate: Float,
  order order: Int,
) -> RootKind {
  case coefficients {
    [] -> Ambiguous
    _ -> {
      let value = evaluate_polynomial(coefficients, at: estimate)
      case value_is_close_to_zero(value, polynomial_value_scale(coefficients)) {
        True ->
          classify_root_from_derivatives_loop(
            polynomial_derivative(coefficients),
            estimate,
            order: order + 1,
          )
        False ->
          case int.is_odd(order), value >. 0.0 {
            True, True -> NegativeToPositive
            True, False -> PositiveToNegative
            False, True -> PositiveToPositive
            False, False -> NegativeToNegative
          }
      }
    }
  }
}

fn classify_root_signs(
  left_value: Float,
  right_value: Float,
  value_scale: Float,
) -> RootKind {
  case
    signed_nonzero(left_value, value_scale),
    signed_nonzero(right_value, value_scale)
  {
    Ok(-1), Ok(1) -> NegativeToPositive
    Ok(1), Ok(-1) -> PositiveToNegative
    Ok(-1), Ok(-1) -> NegativeToNegative
    Ok(1), Ok(1) -> PositiveToPositive
    _, _ -> Ambiguous
  }
}

fn signed_nonzero(value: Float, scale: Float) -> Result(Int, Nil) {
  case value_is_close_to_zero(value, scale) {
    True -> Error(Nil)
    False ->
      case value <. 0.0 {
        True -> Ok(-1)
        False -> Ok(1)
      }
  }
}

fn polynomial_derivative_loop(
  coefficients: List(Float),
  degree degree: Int,
  differentiated differentiated: List(Float),
) -> List(Float) {
  case coefficients {
    [] | [_] -> list.reverse(differentiated)
    [first, ..rest] ->
      polynomial_derivative_loop(rest, degree: degree - 1, differentiated: [
        first *. int.to_float(degree),
        ..differentiated
      ])
  }
}

fn finalize_root_windows(
  isolations: List(RootIsolation),
  lower: Float,
  upper: Float,
) -> List(RootIsolation) {
  let isolations = distinct_isolations(isolations)
  finalize_root_windows_loop(
    isolations,
    lower,
    upper,
    previous_estimate: None,
    finalized: [],
  )
}

fn finalize_root_windows_loop(
  isolations: List(RootIsolation),
  domain_lower: Float,
  domain_upper: Float,
  previous_estimate previous_estimate: Option(Float),
  finalized finalized: List(RootIsolation),
) -> List(RootIsolation) {
  case isolations {
    [] -> list.reverse(finalized)
    [isolation, ..rest] -> {
      let RootIsolation(lower:, estimate:, upper:) = isolation
      let left_limit = case previous_estimate {
        None -> domain_lower
        Some(previous) -> previous +. { estimate -. previous } /. 2.0
      }
      let right_limit = case rest {
        [] -> domain_upper
        [next, ..] -> estimate +. { next.estimate -. estimate } /. 2.0
      }
      let #(window_lower, window_upper) = case lower == upper {
        True -> #(
          estimate -. parameter_tolerance /. 2.0,
          estimate +. parameter_tolerance /. 2.0,
        )
        False -> #(lower, upper)
      }
      let finalized_isolation =
        RootIsolation(
          lower: float.max(left_limit, window_lower),
          estimate:,
          upper: float.min(right_limit, window_upper),
        )
      finalize_root_windows_loop(
        rest,
        domain_lower,
        domain_upper,
        previous_estimate: Some(estimate),
        finalized: [finalized_isolation, ..finalized],
      )
    }
  }
}

fn polynomial_value_scale(coefficients: List(Float)) -> Float {
  list.fold(coefficients, 0.0, fn(scale, coefficient) {
    float.max(scale, float.absolute_value(coefficient))
  })
}

fn polynomial_coefficient_tolerance(coefficients: List(Float)) -> Float {
  polynomial_value_scale(coefficients) *. relative_value_tolerance
}

fn value_is_close_to_zero(value: Float, scale: Float) -> Bool {
  float.absolute_value(value) <=. scale *. relative_value_tolerance
}

fn normalize_polynomial_coefficients(coefficients: List(Float)) -> List(Float) {
  let tolerance = polynomial_coefficient_tolerance(coefficients)
  case coefficients {
    [] | [_] -> coefficients
    [first, ..rest] ->
      case coefficient_is_zero(first, tolerance) {
        True -> normalize_polynomial_coefficients(rest)
        False -> coefficients
      }
  }
}

fn polynomial_root_bound(leading: Float, rest: List(Float)) -> Float {
  1.0
  +. list.fold(rest, 0.0, fn(largest, coefficient) {
    float.max(largest, float.absolute_value(coefficient /. leading))
  })
}

fn linear_with_tolerance(a: Float, b: Float, tolerance: Float) -> List(Float) {
  case coefficient_is_zero(a, tolerance) {
    True -> []
    False -> [{ 0.0 -. b } /. a]
  }
}

fn coefficient_is_zero(value: Float, tolerance: Float) -> Bool {
  case tolerance == 0.0 {
    True -> value == 0.0
    False -> float.absolute_value(value) <. tolerance
  }
}

/// Refine a sign-changing bracket until a caller-defined certification holds.
///
/// The returned isolation preserves both endpoints of the certified bracket.
/// This internal variant is intended for geometric callers whose convergence
/// condition cannot be expressed as a scalar parameter tolerance.
@internal
pub fn bisect_isolation_until(
  f: fn(Float) -> Float,
  from left: Float,
  to right: Float,
  max_iterations max_iterations: Int,
  certified certified: fn(Float, Float) -> Bool,
) -> Result(RootIsolation, Error) {
  case max_iterations <= 0 {
    True -> Error(InvalidMaxIterations(max_iterations))
    False -> {
      let #(left, right) = ordered_bracket(left, right)
      let left_value = f(left)
      let right_value = f(right)
      case left_value == 0.0, right_value == 0.0 {
        True, _ -> Ok(RootIsolation(left, left, left))
        _, True -> Ok(RootIsolation(right, right, right))
        False, False ->
          case same_sign(left_value, right_value) {
            True -> Error(NotBracketed(left, right, left_value, right_value))
            False ->
              bisect_isolation_until_loop(
                f,
                left,
                left_value,
                right,
                max_iterations,
                certified,
              )
          }
      }
    }
  }
}

fn bisect_isolation_until_loop(
  f: fn(Float) -> Float,
  left: Float,
  left_value: Float,
  right: Float,
  remaining_iterations: Int,
  certified: fn(Float, Float) -> Bool,
) -> Result(RootIsolation, Error) {
  let midpoint = left +. { right -. left } /. 2.0
  let midpoint_value = f(midpoint)
  case certified(left, right) || midpoint == left || midpoint == right {
    True -> Ok(RootIsolation(left, midpoint, right))
    False ->
      case remaining_iterations <= 1 {
        True -> Error(MaxIterationsReached(midpoint, midpoint_value))
        False ->
          case midpoint_value == 0.0 {
            True -> Ok(RootIsolation(midpoint, midpoint, midpoint))
            False ->
              case same_sign(left_value, midpoint_value) {
                True ->
                  bisect_isolation_until_loop(
                    f,
                    midpoint,
                    midpoint_value,
                    right,
                    remaining_iterations - 1,
                    certified,
                  )
                False ->
                  bisect_isolation_until_loop(
                    f,
                    left,
                    left_value,
                    midpoint,
                    remaining_iterations - 1,
                    certified,
                  )
              }
          }
      }
  }
}

fn ordered_bracket(left: Float, right: Float) -> #(Float, Float) {
  case left <=. right {
    True -> #(left, right)
    False -> #(right, left)
  }
}

fn same_sign(a: Float, b: Float) -> Bool {
  a <. 0.0 && b <. 0.0 || a >. 0.0 && b >. 0.0
}
