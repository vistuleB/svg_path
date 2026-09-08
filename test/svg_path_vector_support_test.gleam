import gleam/float
import gleam/list
import svg_path
import svg_path/convex_hull

pub fn nonunit_line_support_returns_raw_dot_product_test() {
  let line = svg_path.Line(svg_path.Point(-2.0, 3.0), svg_path.Point(4.0, 1.0))
  assert convex_hull.internal_segment_support_in_direction(
      line,
      svg_path.Point(3.0, 4.0),
    )
    == Ok(#(1.0, svg_path.Point(4.0, 1.0), 16.0))
  assert convex_hull.internal_segment_support_in_direction(
      line,
      svg_path.Point(-3.0, -4.0),
    )
    == Ok(#(0.0, svg_path.Point(-2.0, 3.0), -6.0))
}

pub fn zero_direction_selects_start_test() {
  let curve =
    svg_path.QuadraticBezier(
      svg_path.Point(1.0, 2.0),
      svg_path.Point(3.0, 4.0),
      svg_path.Point(5.0, 6.0),
    )
  assert convex_hull.internal_segment_support_in_direction(
      curve,
      svg_path.Point(-0.0, 0.0),
    )
    == Ok(#(0.0, svg_path.Point(1.0, 2.0), 0.0))
}

pub fn quadratic_support_handles_extreme_direction_scales_test() {
  let curve =
    svg_path.QuadraticBezier(
      svg_path.Point(0.0, 0.0),
      svg_path.Point(1.0, 2.0),
      svg_path.Point(2.0, 0.0),
    )
  list.each(
    [0.00000000000000000001, 7.0, 100_000_000_000_000_000_000.0],
    fn(scale) {
      let assert Ok(#(t, point, value)) =
        convex_hull.internal_segment_support_in_direction(
          curve,
          svg_path.Point(0.0, scale),
        )
      assert t == 0.5
      assert point == svg_path.Point(1.0, 1.0)
      assert value == scale
    },
  )
}

pub fn cubic_nonunit_support_finds_interior_maximum_test() {
  let curve =
    svg_path.CubicBezier(
      svg_path.Point(0.0, 0.0),
      svg_path.Point(1.0, 4.0),
      svg_path.Point(2.0, 4.0),
      svg_path.Point(3.0, 0.0),
    )
  let assert Ok(#(t, point, value)) =
    convex_hull.internal_segment_support_in_direction(
      curve,
      svg_path.Point(0.0, 5.0),
    )
  assert t == 0.5
  assert point == svg_path.Point(1.5, 3.0)
  assert value == 15.0
}

pub fn arc_nonunit_support_finds_interior_maximum_test() {
  let arc =
    svg_path.Arc(
      svg_path.Point(1.0, 0.0),
      svg_path.Point(1.0, 1.0),
      0.0,
      False,
      True,
      svg_path.Point(-1.0, 0.0),
    )
  let assert Ok(#(t, point, value)) =
    convex_hull.internal_segment_support_in_direction(
      arc,
      svg_path.Point(0.0, 3.0),
    )
  assert float.absolute_value(t -. 0.5) <. 0.000000001
  assert float.absolute_value(point.y -. 1.0) <. 0.000000001
  assert float.absolute_value(value -. 3.0) <. 0.000000001
}

pub fn opposite_supports_give_width_after_one_norm_division_test() {
  let line = svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(10.0, 0.0))
  let assert Ok(#(_, _, upper)) =
    convex_hull.internal_segment_support_in_direction(
      line,
      svg_path.Point(3.0, 4.0),
    )
  let assert Ok(#(_, _, opposite)) =
    convex_hull.internal_segment_support_in_direction(
      line,
      svg_path.Point(-3.0, -4.0),
    )
  assert { upper +. opposite } /. 5.0 == 6.0
}
