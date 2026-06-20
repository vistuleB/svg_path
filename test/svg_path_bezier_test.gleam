import gleam/float
import gleeunit
import svg_path/bezier

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

fn point_near(a: bezier.Point, b: bezier.Point) -> Bool {
  near(a.x, b.x) && near(a.y, b.y)
}

fn near(a: Float, b: Float) -> Bool {
  float.absolute_value(a -. b) <=. tolerance
}
