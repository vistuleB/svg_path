//// Bracketed root-finding helpers for scalar functions.
////
//// `bisect` implements standard bracketed bisection. Polynomial root isolation
//// partitions an interval at derivative roots, then refines each sign-changing
//// monotone window with safeguarded Newton steps and bisection fallback.

import gleam/float
import gleam/int
import gleam/list
import gleam/result

const default_tolerance = 0.000000001

const default_max_iterations = 100

/// Options for bracketed bisection.
pub type Options {
  Options(tolerance: Float, max_iterations: Int)
}

/// Errors returned by root-finding helpers.
pub type Error {
  /// The tolerance must be greater than zero.
  InvalidTolerance(tolerance: Float)

  /// The maximum iteration count must be greater than zero.
  InvalidMaxIterations(max_iterations: Int)

  /// Optional polishing iterations cannot be negative.
  InvalidPolishIterations(polish_iterations: Int)

  /// The function values at the bracket endpoints do not have opposite signs.
  NotBracketed(left: Float, right: Float, left_value: Float, right_value: Float)

  /// The solver did not converge within the configured iteration count.
  MaxIterationsReached(estimate: Float, value: Float)
}

/// Whether a repeated quadratic root is returned once or with its algebraic
/// multiplicity of two.
pub type RepeatedRootPolicy {
  ConsolidateRepeatedRoot
  PreserveRepeatedRoot
}

/// Options for solving a quadratic equation.
pub type QuadraticOptions {
  QuadraticOptions(
    coefficient_tolerance: Float,
    repeated_root_policy: RepeatedRootPolicy,
  )
}

/// Options for isolating and refining real polynomial roots.
pub type PolynomialOptions {
  PolynomialOptions(
    coefficient_tolerance: Float,
    root_tolerance: Float,
    value_tolerance: Float,
    max_iterations: Int,
    polish_iterations: Int,
  )
}

/// Return the default bisection options.
pub fn default_options() -> Options {
  Options(tolerance: default_tolerance, max_iterations: default_max_iterations)
}

/// Return the default options for polynomial root isolation.
pub fn default_polynomial_options() -> PolynomialOptions {
  PolynomialOptions(
    coefficient_tolerance: 0.000000000001,
    root_tolerance: default_tolerance,
    value_tolerance: default_tolerance,
    max_iterations: default_max_iterations,
    polish_iterations: 3,
  )
}

/// Solve `a * x + b = 0` using exact zero classification.
///
/// An identically zero or inconsistent constant equation returns no isolated
/// roots.
pub fn linear(a: Float, b: Float) -> List(Float) {
  linear_with_tolerance(a, b, 0.0)
}

/// Solve `a * x² + b * x + c = 0` using exact degree classification.
///
/// Real roots are returned in formula order. A repeated root is returned once.
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
pub fn polynomial_value(coefficients: List(Float), at x: Float) -> Float {
  list.fold(coefficients, 0.0, fn(value, coefficient) {
    value *. x +. coefficient
  })
}

/// Differentiate power-basis coefficients ordered from highest power to the
/// constant term.
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
/// roots are refined by safeguarded Newton steps with bisection fallback, while
/// roots shared with the derivative preserve even-multiplicity roots that do
/// not change sign. After the requested bracket tolerance is reached, optional
/// polishing steps are accepted only while the residual decreases.
pub fn polynomial_roots_with(
  coefficients: List(Float),
  from lower: Float,
  to upper: Float,
  options options: PolynomialOptions,
) -> Result(List(Float), Error) {
  case options.root_tolerance <=. 0.0 {
    True -> Error(InvalidTolerance(options.root_tolerance))
    False ->
      case options.max_iterations <= 0, options.polish_iterations < 0 {
        True, _ -> Error(InvalidMaxIterations(options.max_iterations))
        _, True -> Error(InvalidPolishIterations(options.polish_iterations))
        False, False -> {
          let tolerance = float.max(options.coefficient_tolerance, 0.0)
          let coefficients =
            normalize_polynomial_coefficients(coefficients, tolerance)
          let #(lower, upper) = ordered_bracket(lower, upper)
          polynomial_roots_valid(coefficients, lower, upper, options)
        }
      }
  }
}

/// Find all distinct real roots of `a*x³ + b*x² + c*x + d`.
pub fn cubic(
  a: Float,
  b: Float,
  c: Float,
  d: Float,
) -> Result(List(Float), Error) {
  cubic_with(a, b, c, d, options: default_polynomial_options())
}

/// Find all distinct real roots of a cubic using explicit numerical options.
pub fn cubic_with(
  a: Float,
  b: Float,
  c: Float,
  d: Float,
  options options: PolynomialOptions,
) -> Result(List(Float), Error) {
  case
    options.root_tolerance <=. 0.0,
    options.max_iterations <= 0,
    options.polish_iterations < 0
  {
    True, _, _ -> Error(InvalidTolerance(options.root_tolerance))
    _, True, _ -> Error(InvalidMaxIterations(options.max_iterations))
    _, _, True -> Error(InvalidPolishIterations(options.polish_iterations))
    False, False, False -> {
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

/// Sort roots and merge neighboring values within `tolerance`.
pub fn consolidate(
  roots: List(Float),
  tolerance tolerance: Float,
) -> List(Float) {
  roots
  |> list.sort(by: float.compare)
  |> consolidate_sorted(float.max(tolerance, 0.0), kept: [])
}

fn polynomial_roots_valid(
  coefficients: List(Float),
  lower: Float,
  upper: Float,
  options: PolynomialOptions,
) -> Result(List(Float), Error) {
  case coefficients {
    [] | [_] -> Ok([])
    [a, b] ->
      Ok(
        linear_with_tolerance(a, b, options.coefficient_tolerance)
        |> inside(from: lower, to: upper),
      )
    _ -> {
      let derivative = polynomial_derivative(coefficients)
      use critical <- result.try(polynomial_roots_valid(
        derivative,
        lower,
        upper,
        options,
      ))
      let critical = consolidate(critical, options.root_tolerance)
      let repeated =
        critical
        |> list.filter(fn(value) {
          is_close_to_zero(
            polynomial_value(coefficients, at: value),
            options.value_tolerance,
          )
        })
      let endpoints =
        [lower, upper]
        |> list.filter(fn(value) {
          is_close_to_zero(
            polynomial_value(coefficients, at: value),
            options.value_tolerance,
          )
        })
      use crossing <- result.try(
        polynomial_crossing_roots(
          coefficients,
          [lower, ..list.append(critical, [upper])],
          options,
          roots: [],
        ),
      )
      Ok(
        list.append(endpoints, list.append(repeated, crossing))
        |> consolidate(options.root_tolerance),
      )
    }
  }
}

fn polynomial_crossing_roots(
  coefficients: List(Float),
  boundaries: List(Float),
  options: PolynomialOptions,
  roots roots: List(Float),
) -> Result(List(Float), Error) {
  let derivative = polynomial_derivative(coefficients)
  polynomial_crossing_roots_with_derivative(
    coefficients,
    derivative,
    boundaries,
    options,
    roots:,
  )
}

fn polynomial_crossing_roots_with_derivative(
  coefficients: List(Float),
  derivative: List(Float),
  boundaries: List(Float),
  options: PolynomialOptions,
  roots roots: List(Float),
) -> Result(List(Float), Error) {
  case boundaries {
    [] | [_] -> Ok(roots)
    [left, right, ..rest] -> {
      let left_value = polynomial_value(coefficients, at: left)
      let right_value = polynomial_value(coefficients, at: right)
      case
        same_sign(left_value, right_value)
        || left_value == 0.0
        || right_value == 0.0
      {
        True ->
          polynomial_crossing_roots_with_derivative(
            coefficients,
            derivative,
            [right, ..rest],
            options,
            roots:,
          )
        False -> {
          use found <- result.try(polynomial_refine_bracket(
            coefficients,
            derivative,
            left,
            left_value,
            right,
            options.root_tolerance,
            options.max_iterations,
            options.polish_iterations,
          ))
          polynomial_crossing_roots_with_derivative(
            coefficients,
            derivative,
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
  derivative: List(Float),
  left: Float,
  left_value: Float,
  right: Float,
  tolerance: Float,
  remaining_iterations: Int,
  polish_iterations: Int,
) -> Result(Float, Error) {
  let midpoint = left +. { right -. left } /. 2.0
  let midpoint_value = polynomial_value(coefficients, at: midpoint)
  case { right -. left } /. 2.0 <=. tolerance {
    True ->
      polynomial_polish_root(
        coefficients,
        derivative,
        left,
        left_value,
        right,
        polynomial_value(coefficients, at: right),
        midpoint,
        midpoint_value,
        remaining: polish_iterations,
      )
    False ->
      case remaining_iterations <= 1 {
        True -> Error(MaxIterationsReached(midpoint, midpoint_value))
        False -> {
          let proposal =
            safeguarded_newton_proposal(
              derivative,
              midpoint,
              midpoint_value,
              left,
              right,
              margin_fraction: 0.1,
            )
          let proposal_value = polynomial_value(coefficients, at: proposal)
          case proposal_value == 0.0 {
            True -> Ok(proposal)
            False ->
              case same_sign(left_value, proposal_value) {
                True ->
                  polynomial_refine_bracket(
                    coefficients,
                    derivative,
                    proposal,
                    proposal_value,
                    right,
                    tolerance,
                    remaining_iterations - 1,
                    polish_iterations,
                  )
                False ->
                  polynomial_refine_bracket(
                    coefficients,
                    derivative,
                    left,
                    left_value,
                    proposal,
                    tolerance,
                    remaining_iterations - 1,
                    polish_iterations,
                  )
              }
          }
        }
      }
  }
}

fn safeguarded_newton_proposal(
  derivative: List(Float),
  estimate: Float,
  value: Float,
  left: Float,
  right: Float,
  margin_fraction margin_fraction: Float,
) -> Float {
  let derivative_value = polynomial_value(derivative, at: estimate)
  let newton = estimate -. value /. derivative_value
  let margin = { right -. left } *. margin_fraction
  case
    derivative_value != 0.0
    && is_finite(newton)
    && newton >. left +. margin
    && newton <. right -. margin
    && newton != estimate
  {
    True -> newton
    False -> left +. { right -. left } /. 2.0
  }
}

fn polynomial_polish_root(
  coefficients: List(Float),
  derivative: List(Float),
  left: Float,
  left_value: Float,
  right: Float,
  right_value: Float,
  estimate: Float,
  estimate_value: Float,
  remaining remaining: Int,
) -> Result(Float, Error) {
  case remaining <= 0 || estimate_value == 0.0 {
    True -> Ok(estimate)
    False -> {
      let proposal =
        safeguarded_newton_proposal(
          derivative,
          estimate,
          estimate_value,
          left,
          right,
          margin_fraction: 0.0,
        )
      let proposal_value = polynomial_value(coefficients, at: proposal)
      case
        proposal == estimate
        || float.absolute_value(proposal_value)
        >=. float.absolute_value(estimate_value)
      {
        True -> Ok(estimate)
        False -> {
          let #(next_left, next_left_value, next_right, next_right_value) = case
            same_sign(left_value, proposal_value)
          {
            True -> #(proposal, proposal_value, right, right_value)
            False -> #(left, left_value, proposal, proposal_value)
          }
          polynomial_polish_root(
            coefficients,
            derivative,
            next_left,
            next_left_value,
            next_right,
            next_right_value,
            proposal,
            proposal_value,
            remaining: remaining - 1,
          )
        }
      }
    }
  }
}

fn is_finite(value: Float) -> Bool {
  !is_nan(value -. value)
}

fn is_nan(value: Float) -> Bool {
  !{ value <. 0.0 || value >=. 0.0 }
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

fn consolidate_sorted(
  roots: List(Float),
  tolerance: Float,
  kept kept: List(Float),
) -> List(Float) {
  case roots, kept {
    [], _ -> list.reverse(kept)
    [first, ..rest], [] -> consolidate_sorted(rest, tolerance, kept: [first])
    [first, ..rest], [previous, ..] ->
      case float.absolute_value(first -. previous) <=. tolerance {
        True -> consolidate_sorted(rest, tolerance, kept:)
        False -> consolidate_sorted(rest, tolerance, kept: [first, ..kept])
      }
  }
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
pub fn bisect_with(
  f: fn(Float) -> Float,
  from left: Float,
  to right: Float,
  options options: Options,
) -> Result(Float, Error) {
  case options.tolerance <=. 0.0 {
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
