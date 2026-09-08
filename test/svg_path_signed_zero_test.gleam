import gleam/list
import svg_path
import svg_path/affine
import svg_path/degeneracy
import svg_path/internal/number
import svg_path/parse
import svg_path/point
import svg_path/root
import svg_path/trig

pub fn is_zero_accepts_both_signs_without_a_tolerance_test() {
  assert number.is_zero(0.0)
  assert number.is_zero(-0.0)
  assert number.is_zero(0.0 *. -1.0)
  assert !number.is_zero(1.0)
  assert !number.is_zero(-1.0)
  assert !number.is_zero(1.0e-310)
  assert !number.is_zero(-1.0e-310)
}

pub fn signed_zero_vectors_have_zero_heading_and_no_direction_test() {
  list.each([0.0, -0.0], fn(x) {
    list.each([0.0, -0.0], fn(y) {
      let zero = svg_path.Point(x, y)
      assert point.heading(zero) == 0.0
      assert point.normalize(zero) == Error(Nil)
      assert point.project(point.right, onto: zero) == Error(Nil)
      assert point.scalar_projection(point.right, onto: zero) == Error(Nil)
    })
  })
  assert point.heading(point.scale(point.zero, by: -1.0)) == 0.0
}

pub fn atan2_handles_signed_zero_axes_test() {
  assert trig.atan2_degrees(1.0, -0.0) == 90.0
  assert trig.atan2_degrees(-1.0, -0.0) == -90.0
  assert trig.atan2_degrees(-0.0, 1.0) == 0.0
  assert trig.atan2_degrees(-0.0, -1.0) == 180.0
  // When both coordinates vanish, atan2 retains platform signed-zero semantics;
  // point.heading, not atan2, supplies the library's zero-heading convention.
  assert trig.atan2_degrees(-0.0, -0.0) == -180.0
}

pub fn affine_rejects_negative_zero_determinants_test() {
  // The input contains no negative zeros: multiplication creates one.
  assert affine.point_triple_map(
      #(0.0, 0.0),
      #(-1.0, 0.0),
      #(1.0, 0.0),
      #(0.0, 0.0),
      #(1.0, 0.0),
      #(0.0, 1.0),
    )
    == Error(affine.DegenerateSourceTriple)
}

pub fn roots_reduce_degree_for_both_signs_of_zero_test() {
  assert root.linear(-0.0, 1.0) == []
  assert root.linear(-0.0, -0.0) == []
  assert root.quadratic(-0.0, 1.0, -1.0) == [1.0]
  assert root.quadratic(-0.0, -0.0, 1.0) == []
  assert root.quadratic_with(
      -0.0,
      1.0,
      -1.0,
      root.QuadraticOptions(-0.0, root.ConsolidateRepeatedRoot),
    )
    == [1.0]
}

pub fn bisection_accepts_negative_zero_at_endpoint_test() {
  let assert Ok(isolation) =
    root.bisect_isolation_until(
      fn(t) { t *. -1.0 },
      from: 0.0,
      to: 1.0,
      max_iterations: 2,
      certified: fn(_, _) { False },
    )
  assert number.is_zero(isolation.estimate)
}

pub fn negative_zero_exponents_stop_after_underflow_test() {
  // An astronomical exponent makes iteration after underflow impractical.
  // No wall-clock assertion: success itself requires the zero early exit.
  let assert Ok(value) = number.parse("-1e-1000000000000000")
  assert number.is_zero(value)
  let assert Ok(value) = number.parse("-0e1000000000000000")
  assert number.is_zero(value)
}

pub fn negative_zero_line_does_not_erase_polyline_corners_test() {
  let assert Ok(path) = parse.path("M0 0 L-0 -0 L1 0 L1 1 L2 1")
  let assert [source] = svg_path.path_subpaths(path)
  let assert Ok(normalized) =
    degeneracy.normalize_degenerate_segments(source, tolerance: 0.0)
  assert svg_path.subpath_segments(normalized)
    == [
      svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(1.0, 0.0)),
      svg_path.Line(svg_path.Point(1.0, 0.0), svg_path.Point(1.0, 1.0)),
      svg_path.Line(svg_path.Point(1.0, 1.0), svg_path.Point(2.0, 1.0)),
    ]
}
