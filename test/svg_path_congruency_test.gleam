import gleam/float
import gleeunit
import svg_path
import svg_path/congruency
import svg_path/transform

const tolerance = 0.000001

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn line_returns_transform_mapping_source_to_target_test() {
  let source =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )
  let target =
    svg_path.Line(
      start: svg_path.point(3.0, 4.0),
      end: svg_path.point(3.0, 24.0),
    )

  let assert Ok(matrix) = congruency.segment(source:, target:, tolerance:)
  let assert Ok(mapped) = transform.segment(source, by: matrix)

  assert same_segment(mapped, target)
}

pub fn segment_rejects_different_constructors_test() {
  let source =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )
  let target =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(5.0, 5.0),
      end: svg_path.point(10.0, 0.0),
    )

  assert congruency.segment(source:, target:, tolerance:) == Error(Nil)
}

pub fn line_congruency_allows_zero_scale_directionally_test() {
  let source =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )
  let target =
    svg_path.Line(
      start: svg_path.point(5.0, 5.0),
      end: svg_path.point(5.0, 5.0),
    )

  assert result_is_ok(congruency.segment(source:, target:, tolerance:))
  assert congruency.segment(source: target, target: source, tolerance:)
    == Error(Nil)
}

pub fn quadratic_uses_control_points_in_final_check_test() {
  let source =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(5.0, 10.0),
      end: svg_path.point(10.0, 0.0),
    )
  let target =
    svg_path.QuadraticBezier(
      start: svg_path.point(10.0, 20.0),
      control: svg_path.point(-10.0, 30.0),
      end: svg_path.point(10.0, 40.0),
    )
  let wrong_control =
    svg_path.QuadraticBezier(
      start: svg_path.point(10.0, 20.0),
      control: svg_path.point(-9.0, 30.0),
      end: svg_path.point(10.0, 40.0),
    )

  assert result_is_ok(congruency.segment(source:, target:, tolerance:))
  assert congruency.segment(source:, target: wrong_control, tolerance:)
    == Error(Nil)
}

pub fn cubic_returns_transform_mapping_source_to_target_test() {
  let source =
    svg_path.CubicBezier(
      start: svg_path.point(0.0, 0.0),
      control1: svg_path.point(2.0, 8.0),
      control2: svg_path.point(8.0, 8.0),
      end: svg_path.point(10.0, 0.0),
    )
  let matrix =
    transform.translate(x: 12.0, y: -3.0)
    |> transform.chain(first: transform.rotate(degrees: 90.0), then: _)
    |> transform.chain(first: transform.scale(factor: 2.0), then: _)
  let assert Ok(target) = transform.segment(source, by: matrix)

  let assert Ok(found) = congruency.segment(source:, target:, tolerance:)
  let assert Ok(mapped) = transform.segment(source, by: found)

  assert same_segment(mapped, target)
}

pub fn arc_returns_transform_mapping_source_to_target_test() {
  let source =
    svg_path.Arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(10.0, 5.0),
      x_axis_rotation: 30.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(20.0, 0.0),
    )
  let matrix =
    transform.translate(x: 3.0, y: -7.0)
    |> transform.chain(first: transform.rotate(degrees: 45.0), then: _)
    |> transform.chain(first: transform.scale(factor: 1.5), then: _)
  let assert Ok(target) = transform.segment(source, by: matrix)

  let assert Ok(found) = congruency.segment(source:, target:, tolerance:)
  let assert Ok(mapped) = transform.segment(source, by: found)

  assert same_segment(mapped, target)
}

pub fn arc_rejects_mismatched_flags_test() {
  let source =
    svg_path.Arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(20.0, 0.0),
    )
  let target =
    svg_path.Arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: False,
      end: svg_path.point(20.0, 0.0),
    )

  assert congruency.segment(source:, target:, tolerance:) == Error(Nil)
}

fn result_is_ok(result: Result(a, b)) -> Bool {
  case result {
    Ok(_) -> True
    Error(_) -> False
  }
}

fn same_segment(actual: svg_path.Segment, expected: svg_path.Segment) -> Bool {
  case actual, expected {
    svg_path.Line(start: actual_start, end: actual_end),
      svg_path.Line(start: expected_start, end: expected_end)
    -> {
      point_near(actual_start, expected_start)
      && point_near(actual_end, expected_end)
    }

    svg_path.CubicBezier(
      start: actual_start,
      control1: actual_control1,
      control2: actual_control2,
      end: actual_end,
    ),
      svg_path.CubicBezier(
        start: expected_start,
        control1: expected_control1,
        control2: expected_control2,
        end: expected_end,
      )
    -> {
      point_near(actual_start, expected_start)
      && point_near(actual_control1, expected_control1)
      && point_near(actual_control2, expected_control2)
      && point_near(actual_end, expected_end)
    }

    svg_path.Arc(
      start: actual_start,
      radius: actual_radius,
      x_axis_rotation: actual_rotation,
      large_arc: actual_large_arc,
      sweep: actual_sweep,
      end: actual_end,
    ),
      svg_path.Arc(
        start: expected_start,
        radius: expected_radius,
        x_axis_rotation: expected_rotation,
        large_arc: expected_large_arc,
        sweep: expected_sweep,
        end: expected_end,
      )
    -> {
      actual_large_arc == expected_large_arc
      && actual_sweep == expected_sweep
      && point_near(actual_start, expected_start)
      && point_near(actual_radius, expected_radius)
      && near(actual_rotation, expected_rotation)
      && point_near(actual_end, expected_end)
    }

    _, _ -> False
  }
}

fn point_near(a: svg_path.Point, b: svg_path.Point) -> Bool {
  near(a.x, b.x) && near(a.y, b.y)
}

fn near(a: Float, b: Float) -> Bool {
  float.absolute_value(a -. b) <=. tolerance
}
