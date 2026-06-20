import gleam/float
import gleeunit
import svg_path/root

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
