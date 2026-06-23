import gleam/float
import gleeunit
import svg_path/bezier
import svg_path_bezier_bbox_fixtures

const tolerance = 0.000001

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn bezier_point_evaluates_linear_quadratic_and_cubic_test() {
  let linear =
    bezier.linear_bezier_data(
      start: bezier.Point(0.0, 0.0),
      end: bezier.Point(10.0, 20.0),
    )
  let quadratic =
    bezier.quadratic_bezier_data(
      start: bezier.Point(0.0, 0.0),
      control: bezier.Point(10.0, 20.0),
      end: bezier.Point(20.0, 0.0),
    )
  let cubic =
    bezier.cubic_bezier_data(
      start: bezier.Point(0.0, 0.0),
      control1: bezier.Point(0.0, 30.0),
      control2: bezier.Point(30.0, 30.0),
      end: bezier.Point(30.0, 0.0),
    )

  assert point_near(
    bezier.bezier_point(linear, at: 0.5),
    bezier.Point(5.0, 10.0),
  )
  assert point_near(
    bezier.bezier_point(quadratic, at: 0.5),
    bezier.Point(10.0, 10.0),
  )
  assert point_near(
    bezier.bezier_point(cubic, at: 0.5),
    bezier.Point(15.0, 22.5),
  )
}

pub fn bezier_point_extrapolates_outside_t_test() {
  let linear =
    bezier.linear_bezier_data(
      start: bezier.Point(0.0, 0.0),
      end: bezier.Point(10.0, 20.0),
    )

  assert point_near(
    bezier.bezier_point(linear, at: -0.5),
    bezier.Point(-5.0, -10.0),
  )
  assert point_near(
    bezier.bezier_point(linear, at: 1.5),
    bezier.Point(15.0, 30.0),
  )
}

pub fn bezier_derivative_uses_parameter_t_test() {
  let quadratic =
    bezier.quadratic_bezier_data(
      start: bezier.Point(0.0, 0.0),
      control: bezier.Point(10.0, 20.0),
      end: bezier.Point(20.0, 0.0),
    )
  let cubic =
    bezier.cubic_bezier_data(
      start: bezier.Point(0.0, 0.0),
      control1: bezier.Point(0.0, 30.0),
      control2: bezier.Point(30.0, 30.0),
      end: bezier.Point(30.0, 0.0),
    )

  assert point_near(
    bezier.bezier_derivative(quadratic, at: 0.0),
    bezier.Point(20.0, 40.0),
  )
  assert point_near(
    bezier.bezier_derivative(quadratic, at: 0.5),
    bezier.Point(20.0, 0.0),
  )
  assert point_near(
    bezier.bezier_derivative(cubic, at: 0.5),
    bezier.Point(45.0, 0.0),
  )
}

pub fn bezier_bounding_box_of_line_uses_endpoint_extents_test() {
  let curve =
    bezier.linear_bezier_data(
      start: bezier.Point(1.0, 2.0),
      end: bezier.Point(5.0, -3.0),
    )

  assert bbox_near(
    bezier.bezier_bounding_box(curve),
    min: bezier.Point(1.0, -3.0),
    max: bezier.Point(5.0, 2.0),
  )
}

pub fn bezier_bounding_box_of_quadratic_includes_interior_extremum_test() {
  let curve =
    bezier.quadratic_bezier_data(
      start: bezier.Point(0.0, 0.0),
      control: bezier.Point(10.0, 10.0),
      end: bezier.Point(20.0, 0.0),
    )

  assert bbox_near(
    bezier.bezier_bounding_box(curve),
    min: bezier.Point(0.0, 0.0),
    max: bezier.Point(20.0, 5.0),
  )
}

pub fn bezier_bounding_box_of_cubic_includes_interior_extrema_test() {
  let curve =
    bezier.cubic_bezier_data(
      start: bezier.Point(0.0, 0.0),
      control1: bezier.Point(0.0, 30.0),
      control2: bezier.Point(30.0, 30.0),
      end: bezier.Point(30.0, 0.0),
    )

  assert bbox_near(
    bezier.bezier_bounding_box(curve),
    min: bezier.Point(0.0, 0.0),
    max: bezier.Point(30.0, 22.5),
  )
}

pub fn bezier_bounding_box_matches_generated_fixtures_test() {
  assert_bounding_boxes(svg_path_bezier_bbox_fixtures.fixtures())
}

pub fn map_points_maps_bezier_defining_points_test() {
  let curve =
    bezier.cubic_bezier_data(
      start: bezier.Point(0.0, 0.0),
      control1: bezier.Point(0.0, 30.0),
      control2: bezier.Point(30.0, 30.0),
      end: bezier.Point(30.0, 0.0),
    )

  let mapped =
    bezier.map_points(curve, with: fn(point) {
      bezier.Point(point.x +. 1.0, point.y *. 2.0)
    })
  let assert bezier.CubicBezierData(start:, control1:, control2:, end:) = mapped

  assert point_near(start, bezier.Point(1.0, 0.0))
  assert point_near(control1, bezier.Point(1.0, 60.0))
  assert point_near(control2, bezier.Point(31.0, 60.0))
  assert point_near(end, bezier.Point(31.0, 0.0))
}

pub fn split_bezier_divides_quadratic_at_t_test() {
  let curve =
    bezier.quadratic_bezier_data(
      start: bezier.Point(0.0, 0.0),
      control: bezier.Point(10.0, 20.0),
      end: bezier.Point(20.0, 0.0),
    )

  let #(left, right) = bezier.split_bezier(curve, at: 0.25)
  let assert bezier.QuadraticBezierData(
    start: left_start,
    control: left_control,
    end: split,
  ) = left
  let assert bezier.QuadraticBezierData(
    start: right_start,
    control: right_control,
    end: right_end,
  ) = right

  assert point_near(left_start, bezier.Point(0.0, 0.0))
  assert point_near(left_control, bezier.Point(2.5, 5.0))
  assert point_near(split, bezier.bezier_point(curve, at: 0.25))
  assert point_near(right_start, split)
  assert point_near(right_control, bezier.Point(12.5, 15.0))
  assert point_near(right_end, bezier.Point(20.0, 0.0))
}

pub fn split_bezier_allows_endpoint_splits_test() {
  let curve =
    bezier.cubic_bezier_data(
      start: bezier.Point(0.0, 0.0),
      control1: bezier.Point(0.0, 30.0),
      control2: bezier.Point(30.0, 30.0),
      end: bezier.Point(30.0, 0.0),
    )

  let #(zero_start, whole_after) = bezier.split_bezier(curve, at: 0.0)
  let #(whole_before, zero_end) = bezier.split_bezier(curve, at: 1.0)

  assert point_near(bezier.bezier_start(zero_start), bezier.Point(0.0, 0.0))
  assert point_near(bezier.bezier_end(zero_start), bezier.Point(0.0, 0.0))
  assert point_near(bezier.bezier_start(whole_after), bezier.Point(0.0, 0.0))
  assert point_near(bezier.bezier_end(whole_after), bezier.Point(30.0, 0.0))
  assert point_near(bezier.bezier_start(whole_before), bezier.Point(0.0, 0.0))
  assert point_near(bezier.bezier_end(whole_before), bezier.Point(30.0, 0.0))
  assert point_near(bezier.bezier_start(zero_end), bezier.Point(30.0, 0.0))
  assert point_near(bezier.bezier_end(zero_end), bezier.Point(30.0, 0.0))
}

pub fn split_bezier_inside_rejects_outside_t_test() {
  let curve =
    bezier.linear_bezier_data(
      start: bezier.Point(0.0, 0.0),
      end: bezier.Point(10.0, 20.0),
    )

  let assert Error(bezier.SplitOutsideBezier) =
    bezier.split_bezier_inside(curve, at: -0.01)
  let assert Error(bezier.SplitOutsideBezier) =
    bezier.split_bezier_inside(curve, at: 1.01)
  let assert Ok(_) = bezier.split_bezier_inside(curve, at: 0.0)
  let assert Ok(_) = bezier.split_bezier_inside(curve, at: 1.0)
}

pub fn split_bezier_many_sorts_and_removes_duplicate_points_test() {
  let curve =
    bezier.linear_bezier_data(
      start: bezier.Point(0.0, 0.0),
      end: bezier.Point(40.0, 0.0),
    )

  let pieces = bezier.split_bezier_many(curve, at: [0.75, -0.25, 0.25, 0.25])
  let assert [first, second, third, fourth] = pieces

  assert point_near(bezier.bezier_start(first), bezier.Point(0.0, 0.0))
  assert point_near(bezier.bezier_end(first), bezier.Point(-10.0, 0.0))
  assert point_near(bezier.bezier_start(second), bezier.Point(-10.0, 0.0))
  assert point_near(bezier.bezier_end(second), bezier.Point(10.0, 0.0))
  assert point_near(bezier.bezier_start(third), bezier.Point(10.0, 0.0))
  assert point_near(bezier.bezier_end(third), bezier.Point(30.0, 0.0))
  assert point_near(bezier.bezier_start(fourth), bezier.Point(30.0, 0.0))
  assert point_near(bezier.bezier_end(fourth), bezier.Point(40.0, 0.0))
}

pub fn split_bezier_inside_many_rejects_any_outside_point_test() {
  let curve =
    bezier.linear_bezier_data(
      start: bezier.Point(0.0, 0.0),
      end: bezier.Point(40.0, 0.0),
    )

  let assert Error(bezier.SplitOutsideBezier) =
    bezier.split_bezier_inside_many(curve, at: [0.25, 1.01])
  let assert Error(bezier.SplitOutsideBezier) =
    bezier.split_bezier_inside_many(curve, at: [-0.01, 0.75])
}

pub fn split_bezier_inside_many_trims_boundary_points_test() {
  let curve =
    bezier.linear_bezier_data(
      start: bezier.Point(0.0, 0.0),
      end: bezier.Point(40.0, 0.0),
    )

  let assert Ok(pieces) =
    bezier.split_bezier_inside_many(curve, at: [1.0, 0.0, 0.5, 0.5])
  let assert [first_half, second_half] = pieces

  assert point_near(bezier.bezier_start(first_half), bezier.Point(0.0, 0.0))
  assert point_near(bezier.bezier_end(first_half), bezier.Point(20.0, 0.0))
  assert point_near(bezier.bezier_start(second_half), bezier.Point(20.0, 0.0))
  assert point_near(bezier.bezier_end(second_half), bezier.Point(40.0, 0.0))
}

pub fn split_bezier_many_keeps_boundary_points_when_they_are_interior_test() {
  let curve =
    bezier.linear_bezier_data(
      start: bezier.Point(0.0, 0.0),
      end: bezier.Point(40.0, 0.0),
    )

  let pieces = bezier.split_bezier_many(curve, at: [1.25, 1.0, 0.0, -0.25])
  let assert [before_start, to_start, original_curve, past_end, back_to_end] =
    pieces

  assert point_near(bezier.bezier_start(before_start), bezier.Point(0.0, 0.0))
  assert point_near(bezier.bezier_end(before_start), bezier.Point(-10.0, 0.0))
  assert point_near(bezier.bezier_start(to_start), bezier.Point(-10.0, 0.0))
  assert point_near(bezier.bezier_end(to_start), bezier.Point(0.0, 0.0))
  assert point_near(bezier.bezier_start(original_curve), bezier.Point(0.0, 0.0))
  assert point_near(bezier.bezier_end(original_curve), bezier.Point(40.0, 0.0))
  assert point_near(bezier.bezier_start(past_end), bezier.Point(40.0, 0.0))
  assert point_near(bezier.bezier_end(past_end), bezier.Point(50.0, 0.0))
  assert point_near(bezier.bezier_start(back_to_end), bezier.Point(50.0, 0.0))
  assert point_near(bezier.bezier_end(back_to_end), bezier.Point(40.0, 0.0))
}

pub fn split_bezier_many_preserves_cubic_degree_test() {
  let curve =
    bezier.cubic_bezier_data(
      start: bezier.Point(0.0, 0.0),
      control1: bezier.Point(0.0, 30.0),
      control2: bezier.Point(30.0, 30.0),
      end: bezier.Point(30.0, 0.0),
    )

  let pieces = bezier.split_bezier_many(curve, at: [0.25, 0.75])
  let assert [
    bezier.CubicBezierData(..),
    bezier.CubicBezierData(..),
    bezier.CubicBezierData(..),
  ] = pieces
}

pub fn cubic_inflection_parameters_finds_an_s_curve_inflection_test() {
  let curve =
    bezier.cubic_bezier_data(
      start: bezier.Point(0.0, 0.0),
      control1: bezier.Point(0.0, 100.0),
      control2: bezier.Point(100.0, -100.0),
      end: bezier.Point(100.0, 0.0),
    )

  let assert [t] = bezier.cubic_inflection_parameters(curve)
  let pieces = bezier.split_bezier_many(curve, at: [t])
  let assert [bezier.CubicBezierData(end: split, ..), second] = pieces

  assert near(t, 0.5)
  assert point_near(split, bezier.Point(50.0, 0.0))
  assert point_near(bezier.bezier_start(second), split)
}

pub fn cubic_inflection_parameters_ignores_non_inflecting_curves_test() {
  let cubic =
    bezier.cubic_bezier_data(
      start: bezier.Point(0.0, 0.0),
      control1: bezier.Point(0.0, 30.0),
      control2: bezier.Point(30.0, 30.0),
      end: bezier.Point(30.0, 0.0),
    )
  let quadratic =
    bezier.quadratic_bezier_data(
      start: bezier.Point(0.0, 0.0),
      control: bezier.Point(10.0, 10.0),
      end: bezier.Point(20.0, 0.0),
    )

  assert bezier.cubic_inflection_parameters(cubic) == []
  assert bezier.cubic_inflection_parameters(quadratic) == []
}

fn point_near(a: bezier.Point, b: bezier.Point) -> Bool {
  near(a.x, b.x) && near(a.y, b.y)
}

fn bbox_near(
  box: bezier.BoundingBox,
  min expected_min: bezier.Point,
  max expected_max: bezier.Point,
) -> Bool {
  let bezier.BoundingBox(min:, max:) = box
  point_near(min, expected_min) && point_near(max, expected_max)
}

fn assert_bounding_boxes(
  fixtures: List(svg_path_bezier_bbox_fixtures.BezierBBoxFixture),
) -> Nil {
  case fixtures {
    [] -> Nil
    [fixture, ..rest] -> {
      let svg_path_bezier_bbox_fixtures.BezierBBoxFixture(
        curve:,
        min: expected_min,
        max: expected_max,
        ..,
      ) = fixture
      assert bbox_near(
        bezier.bezier_bounding_box(curve),
        min: expected_min,
        max: expected_max,
      )
      assert_bounding_boxes(rest)
    }
  }
}

fn near(a: Float, b: Float) -> Bool {
  float.absolute_value(a -. b) <=. tolerance
}
