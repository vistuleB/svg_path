//// Bracketed root-finding helpers for scalar functions.
////
//// `bisect` implements standard bracketed bisection. Polynomial root isolation
//// partitions an interval at derivative roots, then refines each sign-changing
//// monotone window with bracketed bisection.

import gleam/float
import gleam/int
import gleam/list
import gleam/result
import svg_path/internal/number

const default_tolerance = 0.000000001

const default_max_iterations = 100

/// Options for bracketed bisection.
@internal
pub type Options {
  Options(tolerance: Float, max_iterations: Int)
}

/// Errors returned by root-finding helpers.
@internal
pub type Error {
  /// The tolerance must be greater than zero.
  InvalidTolerance(tolerance: Float)

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
@internal
pub type PolynomialOptions {
  PolynomialOptions(
    coefficient_tolerance: Float,
    root_tolerance: Float,
    value_tolerance: Float,
    max_iterations: Int,
  )
}

/// A real polynomial root isolated inside a closed parameter interval.
///
/// Exact, endpoint, and repeated-root isolations may have equal bounds.
@internal
pub type RootIsolation {
  RootIsolation(lower: Float, estimate: Float, upper: Float)
}

/// Return the default bisection options.
fn default_options() -> Options {
  Options(tolerance: default_tolerance, max_iterations: default_max_iterations)
}

/// Return the default options for polynomial root isolation.
@internal
pub fn default_polynomial_options() -> PolynomialOptions {
  PolynomialOptions(
    coefficient_tolerance: 0.000000000001,
    root_tolerance: default_tolerance,
    value_tolerance: default_tolerance,
    max_iterations: default_max_iterations,
  )
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
            False, _ -> [
              { 0.0 -. b -. root_discriminant } /. denominator,
              { 0.0 -. b +. root_discriminant } /. denominator,
            ]
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
  case
    options.root_tolerance <=. 0.0 || !number.is_finite(options.root_tolerance)
  {
    True -> Error(InvalidTolerance(options.root_tolerance))
    False ->
      case options.max_iterations <= 0 {
        True -> Error(InvalidMaxIterations(options.max_iterations))
        False -> {
          let tolerance = float.max(options.coefficient_tolerance, 0.0)
          let coefficients =
            normalize_polynomial_coefficients(coefficients, tolerance)
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
  case
    options.root_tolerance <=. 0.0 || !number.is_finite(options.root_tolerance)
  {
    True -> Error(InvalidTolerance(options.root_tolerance))
    False ->
      case options.max_iterations <= 0 {
        True -> Error(InvalidMaxIterations(options.max_iterations))
        False -> {
          let coefficients =
            normalize_polynomial_coefficients(
              coefficients,
              float.max(options.coefficient_tolerance, 0.0),
            )
          let #(lower, upper) = ordered_bracket(lower, upper)
          polynomial_root_isolations_valid(coefficients, lower, upper, options)
        }
      }
  }
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
  case
    options.root_tolerance <=. 0.0 || !number.is_finite(options.root_tolerance),
    options.max_iterations <= 0
  {
    True, _ -> Error(InvalidTolerance(options.root_tolerance))
    _, True -> Error(InvalidMaxIterations(options.max_iterations))
    False, False -> {
      let coefficients =
        normalize_polynomial_coefficients(
          [a, b, c, d],
          float.max(options.coefficient_tolerance, 0.0),
        )
      case coefficients {
        [] | [_] -> Ok([])
        [linear_a, linear_b] -> Ok(linear(linear_a, linear_b))
        [quadratic_a, quadratic_b, quadratic_c] ->
          Ok(quadratic_with(
            quadratic_a,
            quadratic_b,
            quadratic_c,
            options: QuadraticOptions(
              coefficient_tolerance: options.coefficient_tolerance,
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

fn consolidate_isolations(
  isolations: List(RootIsolation),
  tolerance: Float,
) -> List(RootIsolation) {
  isolations
  |> list.sort(by: fn(left, right) {
    float.compare(left.estimate, right.estimate)
  })
  |> consolidate_sorted_isolations(float.max(tolerance, 0.0), kept: [])
}

fn consolidate_sorted_isolations(
  isolations: List(RootIsolation),
  tolerance: Float,
  kept kept: List(RootIsolation),
) -> List(RootIsolation) {
  case isolations, kept {
    [], _ -> list.reverse(kept)
    [first, ..rest], [] ->
      consolidate_sorted_isolations(rest, tolerance, kept: [first])
    [first, ..rest], [previous, ..] ->
      case
        float.absolute_value(first.estimate -. previous.estimate) <=. tolerance
      {
        True -> consolidate_sorted_isolations(rest, tolerance, kept:)
        False ->
          consolidate_sorted_isolations(rest, tolerance, kept: [first, ..kept])
      }
  }
}

fn polynomial_root_isolations_valid(
  coefficients: List(Float),
  lower: Float,
  upper: Float,
  options: PolynomialOptions,
) -> Result(List(RootIsolation), Error) {
  case coefficients {
    [] | [_] -> Ok([])
    [a, b] ->
      Ok(
        linear_with_tolerance(a, b, options.coefficient_tolerance)
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
      let critical = consolidate_isolations(critical, options.root_tolerance)
      let critical_values =
        list.map(critical, fn(isolation) {
          let RootIsolation(estimate:, ..) = isolation
          estimate
        })
      let repeated =
        critical
        |> list.filter(fn(isolation) {
          let RootIsolation(estimate:, ..) = isolation
          is_close_to_zero(
            evaluate_polynomial(coefficients, at: estimate),
            options.value_tolerance,
          )
        })
      let endpoints =
        [lower, upper]
        |> list.filter(fn(value) {
          is_close_to_zero(
            evaluate_polynomial(coefficients, at: value),
            options.value_tolerance,
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
        |> consolidate_isolations(options.root_tolerance),
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
      case
        same_sign(left_value, right_value)
        || left_value == 0.0
        || right_value == 0.0
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
            options.root_tolerance,
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
  case { right -. left } /. 2.0 <=. tolerance {
    True -> Ok(RootIsolation(left, midpoint, right))
    False ->
      case remaining_iterations <= 1 {
        True -> Error(MaxIterationsReached(midpoint, midpoint_value))
        False -> {
          let proposal = midpoint
          let proposal_value = evaluate_polynomial(coefficients, at: proposal)
          case proposal_value == 0.0 {
            True -> Ok(RootIsolation(proposal, proposal, proposal))
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

fn normalize_polynomial_coefficients(
  coefficients: List(Float),
  tolerance: Float,
) -> List(Float) {
  case coefficients {
    [] | [_] -> coefficients
    [first, ..rest] ->
      case coefficient_is_zero(first, tolerance) {
        True -> normalize_polynomial_coefficients(rest, tolerance)
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

/// Find a root of `f` in a bracket using default options.
///
/// `f(from)` and `f(to)` must have opposite signs, unless either endpoint is
/// already within tolerance of zero. `from` may be greater than `to`; the
/// bracket is normalized before solving.
@internal
pub fn bisect(
  f: fn(Float) -> Float,
  from left: Float,
  to right: Float,
) -> Result(Float, Error) {
  bisect_with(f, from: left, to: right, options: default_options())
}

/// Find a root of `f` in a bracket using explicit options.
///
/// The returned value is an approximation. Convergence succeeds when either
/// `abs(f(estimate)) <= tolerance` or the current bracket width is no larger
/// than `tolerance`.
@internal
pub fn bisect_with(
  f: fn(Float) -> Float,
  from left: Float,
  to right: Float,
  options options: Options,
) -> Result(Float, Error) {
  case options.tolerance <=. 0.0 || !number.is_finite(options.tolerance) {
    True -> Error(InvalidTolerance(options.tolerance))
    False -> {
      case options.max_iterations <= 0 {
        True -> Error(InvalidMaxIterations(options.max_iterations))
        False -> {
          let #(left, right) = ordered_bracket(left, right)
          let left_value = f(left)
          let right_value = f(right)

          case is_close_to_zero(left_value, options.tolerance) {
            True -> Ok(left)
            False -> {
              case is_close_to_zero(right_value, options.tolerance) {
                True -> Ok(right)
                False -> {
                  case same_sign(left_value, right_value) {
                    True ->
                      Error(NotBracketed(left, right, left_value, right_value))
                    False ->
                      bisect_loop(
                        f,
                        left,
                        left_value,
                        right,
                        options.tolerance,
                        options.max_iterations,
                      )
                  }
                }
              }
            }
          }
        }
      }
    }
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

fn bisect_loop(
  f: fn(Float) -> Float,
  left: Float,
  left_value: Float,
  right: Float,
  tolerance: Float,
  remaining_iterations: Int,
) -> Result(Float, Error) {
  let midpoint = left +. { right -. left } /. 2.0
  let midpoint_value = f(midpoint)

  case
    is_close_to_zero(midpoint_value, tolerance)
    || { right -. left } /. 2.0 <=. tolerance
  {
    True -> Ok(midpoint)
    False -> {
      case remaining_iterations <= 1 {
        True -> Error(MaxIterationsReached(midpoint, midpoint_value))
        False -> {
          case same_sign(left_value, midpoint_value) {
            True ->
              bisect_loop(
                f,
                midpoint,
                midpoint_value,
                right,
                tolerance,
                remaining_iterations - 1,
              )
            False ->
              bisect_loop(
                f,
                left,
                left_value,
                midpoint,
                tolerance,
                remaining_iterations - 1,
              )
          }
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

fn is_close_to_zero(value: Float, tolerance: Float) -> Bool {
  float.absolute_value(value) <=. tolerance
}

fn same_sign(a: Float, b: Float) -> Bool {
  a <. 0.0 && b <. 0.0 || a >. 0.0 && b >. 0.0
}
