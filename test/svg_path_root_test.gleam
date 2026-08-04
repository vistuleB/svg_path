import gleam/float
import gleeunit
import svg_path/root

pub fn linear_root_test() {
  assert root.linear(2.0, -1.0) == [0.5]
  assert root.linear(0.0, 1.0) == []
  assert root.linear(0.0, 0.0) == []
}

pub fn quadratic_real_roots_test() {
  assert root.quadratic(1.0, -3.0, 2.0) == [1.0, 2.0]
}

pub fn quadratic_reduces_to_linear_test() {
  assert root.quadratic(0.0, 2.0, -1.0) == [0.5]
}

pub fn quadratic_repeated_root_policy_test() {
  let preserve =
    root.QuadraticOptions(
      coefficient_tolerance: 0.0,
      repeated_root_policy: root.PreserveRepeatedRoot,
    )
  assert root.quadratic(1.0, -2.0, 1.0) == [1.0]
  assert root.quadratic_with(1.0, -2.0, 1.0, options: preserve) == [1.0, 1.0]
}

pub fn quadratic_coefficient_tolerance_test() {
  let options =
    root.QuadraticOptions(
      coefficient_tolerance: 0.000001,
      repeated_root_policy: root.ConsolidateRepeatedRoot,
    )
  assert root.quadratic_with(0.0000001, 2.0, -1.0, options:) == [0.5]
}

pub fn root_interval_filters_and_sorts_test() {
  let values = [1.0, 0.75, -0.1, 0.25, 0.0]
  assert root.strictly_inside(values, from: 0.0, to: 1.0) == [0.25, 0.75]
  assert root.inside(values, from: 1.0, to: 0.0) == [0.0, 0.25, 0.75, 1.0]
}

pub fn polynomial_value_and_derivative_test() {
  let coefficients = [2.0, -3.0, 4.0]
  assert root.polynomial_value(coefficients, at: 2.0) == 6.0
  assert root.polynomial_derivative(coefficients) == [4.0, -3.0]
}

pub fn cubic_finds_three_real_roots_test() {
  let assert Ok(roots) = root.cubic(1.0, -6.0, 11.0, -6.0)
  assert roots_are_near(roots, [1.0, 2.0, 3.0])
}

pub fn cubic_preserves_repeated_root_test() {
  let assert Ok(roots) = root.cubic(1.0, 0.0, -3.0, 2.0)
  assert roots_are_near(roots, [-2.0, 1.0])
}

pub fn polynomial_roots_find_even_multiplicity_root_test() {
  let options = root.default_polynomial_options()
  let assert Ok(roots) =
    root.polynomial_roots_with([1.0, -2.0, 1.0], from: 0.0, to: 2.0, options:)
  assert roots_are_near(roots, [1.0])
}

pub fn quintic_roots_in_unit_interval_test() {
  // (x - 0.1) * (x - 0.3) * (x - 0.5) * (x - 0.7) * (x - 0.9)
  let coefficients = [1.0, -2.5, 2.3, -0.95, 0.1689, -0.00945]
  let assert Ok(roots) =
    root.polynomial_roots_with(
      coefficients,
      from: 0.0,
      to: 1.0,
      options: root.default_polynomial_options(),
    )
  assert roots_are_near(roots, [0.1, 0.3, 0.5, 0.7, 0.9])
}

pub fn polynomial_polishing_reduces_residual_after_required_tolerance_test() {
  let unpolished_options =
    root.PolynomialOptions(
      coefficient_tolerance: 0.000000000001,
      root_tolerance: 0.01,
      value_tolerance: 0.000000000001,
      max_iterations: 100,
      polish_iterations: 0,
    )
  let polished_options =
    root.PolynomialOptions(..unpolished_options, polish_iterations: 3)
  let coefficients = [1.0, 0.0, 0.0, -2.0]
  let assert Ok([unpolished]) =
    root.polynomial_roots_with(
      coefficients,
      from: 0.0,
      to: 2.0,
      options: unpolished_options,
    )
  let assert Ok([polished]) =
    root.polynomial_roots_with(
      coefficients,
      from: 0.0,
      to: 2.0,
      options: polished_options,
    )

  assert float.absolute_value(root.polynomial_value(coefficients, at: polished))
    <. float.absolute_value(root.polynomial_value(coefficients, at: unpolished))
}

pub fn polynomial_safeguarded_newton_falls_back_at_zero_derivative_test() {
  let assert Ok([solution]) =
    root.polynomial_roots_with(
      [1.0, 0.0, 0.0, -0.001],
      from: -1.0,
      to: 1.0,
      options: root.default_polynomial_options(),
    )
  assert near(solution, 0.1)
}

pub fn polynomial_roots_reject_negative_polish_iterations_test() {
  let options =
    root.PolynomialOptions(
      ..root.default_polynomial_options(),
      polish_iterations: -1,
    )
  assert root.polynomial_roots_with([1.0, -1.0], from: 0.0, to: 1.0, options:)
    == Error(root.InvalidPolishIterations(-1))
}

const tolerance = 0.000001

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn bisect_finds_bracketed_root_test() {
  let assert Ok(solution) =
    root.bisect(fn(x) { x *. x -. 2.0 }, from: 0.0, to: 2.0)

  assert near(solution, 1.414213562)
}

pub fn bisect_accepts_reversed_bracket_test() {
  let assert Ok(solution) = root.bisect(fn(x) { x -. 0.25 }, from: 1.0, to: 0.0)

  assert near(solution, 0.25)
}

pub fn bisect_accepts_endpoint_root_test() {
  assert root.bisect(fn(x) { x }, from: 0.0, to: 1.0) == Ok(0.0)
  assert root.bisect(fn(x) { x -. 1.0 }, from: 0.0, to: 1.0) == Ok(1.0)
}

pub fn bisect_rejects_unbracketed_roots_test() {
  let assert Error(root.NotBracketed(
    left: 0.0,
    right: 2.0,
    left_value: 1.0,
    right_value: 5.0,
  )) = root.bisect(fn(x) { x *. x +. 1.0 }, from: 0.0, to: 2.0)
}

pub fn bisect_with_rejects_invalid_options_test() {
  let invalid_tolerance = root.Options(tolerance: 0.0, max_iterations: 100)
  let invalid_iterations = root.Options(tolerance: 0.000001, max_iterations: 0)

  assert root.bisect_with(
      fn(x) { x },
      from: -1.0,
      to: 1.0,
      options: invalid_tolerance,
    )
    == Error(root.InvalidTolerance(0.0))
  assert root.bisect_with(
      fn(x) { x },
      from: -1.0,
      to: 1.0,
      options: invalid_iterations,
    )
    == Error(root.InvalidMaxIterations(0))
}

pub fn bisect_with_reports_max_iterations_test() {
  let options = root.Options(tolerance: 0.000000001, max_iterations: 1)

  let assert Error(root.MaxIterationsReached(estimate:, value:)) =
    root.bisect_with(fn(x) { x -. 0.3 }, from: 0.0, to: 1.0, options:)

  assert near(estimate, 0.5)
  assert near(value, 0.2)
}

fn near(a: Float, b: Float) -> Bool {
  float.absolute_value(a -. b) <=. tolerance
}

fn roots_are_near(found: List(Float), expected: List(Float)) -> Bool {
  case found, expected {
    [], [] -> True
    [found, ..found_rest], [expected, ..expected_rest] ->
      near(found, expected) && roots_are_near(found_rest, expected_rest)
    _, _ -> False
  }
}
