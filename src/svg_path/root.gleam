//// Bracketed root-finding helpers for scalar functions.
////
//// This module intentionally keeps the numerical method small and explicit.
//// `bisect` implements the standard bisection method: for a continuous
//// function `f` and a bracket `[a, b]` where `f(a)` and `f(b)` have opposite
//// signs, repeatedly halve the interval until the root estimate is within the
//// requested tolerance.

import gleam/float
import gleam/list

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

/// Return the default bisection options.
pub fn default_options() -> Options {
  Options(tolerance: default_tolerance, max_iterations: default_max_iterations)
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
