import gleam/list
import svg_path/root

pub fn repeated_quartic_roots_retain_touch_classification_test() {
  // (t - 1/4)^2 (t - 3/4)^2; all coefficients are exact binary fractions.
  list.each([1.0, -1.0], fn(sign) {
    let coefficients =
      list.map([1.0, -2.0, 1.375, -0.375, 0.03515625], fn(c) { sign *. c })
    let assert Ok([first, second]) =
      root.classified_polynomial_roots_with(
        coefficients,
        from: 0.0,
        to: 1.0,
        options: root.default_polynomial_options(),
      )
    let expected = case sign >. 0.0 {
      True -> root.PositiveToPositive
      False -> root.NegativeToNegative
    }
    assert first.kind == expected
    assert second.kind == expected
    assert first.isolation.lower <=. 0.25 && first.isolation.upper >=. 0.25
    assert second.isolation.lower <=. 0.75 && second.isolation.upper >=. 0.75
  })
}

pub fn inherited_odd_multiplicity_still_crosses_test() {
  // (t - 1/4)^3 (t - 3/4)(t - 7/8).
  let assert Ok([first, second, third]) =
    root.classified_polynomial_roots_with(
      [1.0, -2.375, 2.0625, -0.8125, 0.1484375, -0.01025390625],
      from: 0.0,
      to: 1.0,
      options: root.default_polynomial_options(),
    )
  assert first.kind == root.NegativeToPositive
  assert second.kind == root.PositiveToNegative
  assert third.kind == root.NegativeToPositive
}

pub fn repeated_endpoint_keeps_derivative_information_test() {
  // t^2 (t - 1/2)^2, including the duplicated endpoint/critical-point candidate.
  let assert Ok([first, second]) =
    root.classified_polynomial_roots_with(
      [1.0, -1.0, 0.25, 0.0, 0.0],
      from: 0.0,
      to: 1.0,
      options: root.default_polynomial_options(),
    )
  assert first.isolation.estimate == 0.0
  assert first.kind == root.PositiveToPositive
  assert second.kind == root.PositiveToPositive
}

pub fn exact_bisection_root_receives_centered_window_test() {
  let assert Ok([isolation]) =
    root.polynomial_root_isolations_with(
      [1.0, 0.0, 1.0, -0.625],
      from: 0.0,
      to: 1.0,
      options: root.default_polynomial_options(),
    )
  assert isolation.estimate == 0.5
  assert isolation.lower == 0.5 -. 0.5e-9
  assert isolation.upper == 0.5 +. 0.5e-9
}

pub fn exact_root_on_last_polynomial_iteration_succeeds_test() {
  let assert Ok([isolation]) =
    root.polynomial_root_isolations_with(
      [1.0, 0.0, 1.0, -0.625],
      from: 0.0,
      to: 1.0,
      options: root.PolynomialOptions(max_iterations: 1),
    )
  assert isolation.estimate == 0.5
}

pub fn exact_root_on_last_certified_bisection_iteration_succeeds_test() {
  assert root.bisect_isolation_until(
      fn(t) { t -. 0.5 },
      from: 0.0,
      to: 1.0,
      max_iterations: 1,
      certified: fn(_, _) { False },
    )
    == Ok(root.RootIsolation(0.5, 0.5, 0.5))
}
