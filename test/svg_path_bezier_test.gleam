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
    bezier.LinearBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      end: bezier.BezierPoint(10.0, 20.0),
    )
  let quadratic =
    bezier.QuadraticBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control: bezier.BezierPoint(10.0, 20.0),
      end: bezier.BezierPoint(20.0, 0.0),
    )
  let cubic =
    bezier.CubicBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control1: bezier.BezierPoint(0.0, 30.0),
      control2: bezier.BezierPoint(30.0, 30.0),
      end: bezier.BezierPoint(30.0, 0.0),
    )

  assert point_near(
    bezier.bezier_point(linear, at: 0.5),
    bezier.BezierPoint(5.0, 10.0),
  )
  assert point_near(
    bezier.bezier_point(quadratic, at: 0.5),
    bezier.BezierPoint(10.0, 10.0),
  )
  assert point_near(
    bezier.bezier_point(cubic, at: 0.5),
    bezier.BezierPoint(15.0, 22.5),
  )
}

pub fn bezier_point_extrapolates_outside_t_test() {
  let linear =
    bezier.LinearBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      end: bezier.BezierPoint(10.0, 20.0),
    )

  assert point_near(
    bezier.bezier_point(linear, at: -0.5),
    bezier.BezierPoint(-5.0, -10.0),
  )
  assert point_near(
    bezier.bezier_point(linear, at: 1.5),
    bezier.BezierPoint(15.0, 30.0),
  )
}

pub fn bezier_derivative_uses_parameter_t_test() {
  let quadratic =
    bezier.QuadraticBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control: bezier.BezierPoint(10.0, 20.0),
      end: bezier.BezierPoint(20.0, 0.0),
    )
  let cubic =
    bezier.CubicBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control1: bezier.BezierPoint(0.0, 30.0),
      control2: bezier.BezierPoint(30.0, 30.0),
      end: bezier.BezierPoint(30.0, 0.0),
    )

  assert point_near(
    bezier.bezier_derivative(quadratic, at: 0.0),
    bezier.BezierPoint(20.0, 40.0),
  )
  assert point_near(
    bezier.bezier_derivative(quadratic, at: 0.5),
    bezier.BezierPoint(20.0, 0.0),
  )
  assert point_near(
    bezier.bezier_derivative(cubic, at: 0.5),
    bezier.BezierPoint(45.0, 0.0),
  )
}

pub fn bezier_bounding_box_of_line_uses_endpoint_extents_test() {
  let curve =
    bezier.LinearBezierData(
      start: bezier.BezierPoint(1.0, 2.0),
      end: bezier.BezierPoint(5.0, -3.0),
    )

  assert bbox_near(
    bezier.bezier_bounding_box(curve),
    min: bezier.BezierPoint(1.0, -3.0),
    max: bezier.BezierPoint(5.0, 2.0),
  )
}

pub fn bezier_bounding_box_of_quadratic_includes_interior_extremum_test() {
  let curve =
    bezier.QuadraticBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control: bezier.BezierPoint(10.0, 10.0),
      end: bezier.BezierPoint(20.0, 0.0),
    )

  assert bbox_near(
    bezier.bezier_bounding_box(curve),
    min: bezier.BezierPoint(0.0, 0.0),
    max: bezier.BezierPoint(20.0, 5.0),
  )
}

pub fn bezier_bounding_box_of_cubic_includes_interior_extrema_test() {
  let curve =
    bezier.CubicBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control1: bezier.BezierPoint(0.0, 30.0),
      control2: bezier.BezierPoint(30.0, 30.0),
      end: bezier.BezierPoint(30.0, 0.0),
    )

  assert bbox_near(
    bezier.bezier_bounding_box(curve),
    min: bezier.BezierPoint(0.0, 0.0),
    max: bezier.BezierPoint(30.0, 22.5),
  )
}

pub fn bezier_bounding_box_matches_generated_fixtures_test() {
  assert_bounding_boxes(svg_path_bezier_bbox_fixtures.fixtures())
}

pub fn map_points_maps_bezier_defining_points_test() {
  let curve =
    bezier.CubicBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control1: bezier.BezierPoint(0.0, 30.0),
      control2: bezier.BezierPoint(30.0, 30.0),
      end: bezier.BezierPoint(30.0, 0.0),
    )

  let mapped =
    bezier.map_points(curve, with: fn(point) {
      bezier.BezierPoint(point.x +. 1.0, point.y *. 2.0)
    })
  let assert bezier.CubicBezierData(start:, control1:, control2:, end:) = mapped

  assert point_near(start, bezier.BezierPoint(1.0, 0.0))
  assert point_near(control1, bezier.BezierPoint(1.0, 60.0))
  assert point_near(control2, bezier.BezierPoint(31.0, 60.0))
  assert point_near(end, bezier.BezierPoint(31.0, 0.0))
}

pub fn fit_cubic_with_endpoint_tangents_recovers_exact_cubic_test() {
  let original =
    bezier.CubicBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control1: bezier.BezierPoint(35.0, 65.0),
      control2: bezier.BezierPoint(90.0, -35.0),
      end: bezier.BezierPoint(130.0, 25.0),
    )
  let assert Ok(#(fit, error)) =
    bezier.fit_cubic_with_endpoint_tangents(
      start: bezier.bezier_start(original),
      end: bezier.bezier_end(original),
      start_tangent: bezier.bezier_derivative(original, at: 0.0),
      end_tangent: bezier.bezier_derivative(original, at: 1.0),
      samples: [
        #(0.25, bezier.bezier_point(original, at: 0.25)),
        #(0.5, bezier.bezier_point(original, at: 0.5)),
        #(0.75, bezier.bezier_point(original, at: 0.75)),
      ],
    )
  let assert bezier.CubicBezierData(start:, control1:, control2:, end:) = fit
  let bezier.CubicBezierData(
    start: original_start,
    control1: original_control1,
    control2: original_control2,
    end: original_end,
  ) = original
  let bezier.CubicFitReport(root_sum_square:, root_mean_square:, max:) = error

  assert point_near(start, original_start)
  assert point_near(control1, original_control1)
  assert point_near(control2, original_control2)
  assert point_near(end, original_end)
  assert near(root_sum_square, 0.0)
  assert near(root_mean_square, 0.0)
  assert near(max, 0.0)
}

pub fn fit_cubic_with_endpoint_tangents_uses_forward_end_tangent_test() {
  let original =
    bezier.CubicBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control1: bezier.BezierPoint(10.0, 20.0),
      control2: bezier.BezierPoint(80.0, 40.0),
      end: bezier.BezierPoint(100.0, 0.0),
    )
  let assert Ok(#(fit, _)) =
    bezier.fit_cubic_with_endpoint_tangents(
      start: bezier.bezier_start(original),
      end: bezier.bezier_end(original),
      start_tangent: bezier.bezier_derivative(original, at: 0.0),
      end_tangent: bezier.bezier_derivative(original, at: 1.0),
      samples: [
        #(0.2, bezier.bezier_point(original, at: 0.2)),
        #(0.6, bezier.bezier_point(original, at: 0.6)),
      ],
    )

  assert point_near(
    bezier.bezier_derivative(fit, at: 1.0),
    bezier.bezier_derivative(original, at: 1.0),
  )
}

pub fn fit_cubic_with_endpoint_tangents_rejects_degenerate_tangent_test() {
  let assert Error(bezier.DegenerateTangent) =
    bezier.fit_cubic_with_endpoint_tangents(
      start: bezier.BezierPoint(0.0, 0.0),
      end: bezier.BezierPoint(10.0, 0.0),
      start_tangent: bezier.BezierPoint(0.0, 0.0),
      end_tangent: bezier.BezierPoint(1.0, 0.0),
      samples: [#(0.5, bezier.BezierPoint(5.0, 1.0))],
    )
}

pub fn fit_cubic_with_endpoint_tangents_rejects_underdetermined_samples_test() {
  let assert Error(bezier.UnderdeterminedCubicFit) =
    bezier.fit_cubic_with_endpoint_tangents(
      start: bezier.BezierPoint(0.0, 0.0),
      end: bezier.BezierPoint(10.0, 0.0),
      start_tangent: bezier.BezierPoint(1.0, 0.0),
      end_tangent: bezier.BezierPoint(1.0, 0.0),
      samples: [],
    )
}

pub fn fit_cubic_with_endpoints_recovers_exact_cubic_test() {
  let original =
    bezier.CubicBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control1: bezier.BezierPoint(35.0, 65.0),
      control2: bezier.BezierPoint(90.0, -35.0),
      end: bezier.BezierPoint(130.0, 25.0),
    )
  let assert Ok(#(fit, error)) =
    bezier.fit_cubic_with_endpoints(
      start: bezier.bezier_start(original),
      end: bezier.bezier_end(original),
      samples: [
        #(0.25, bezier.bezier_point(original, at: 0.25)),
        #(0.5, bezier.bezier_point(original, at: 0.5)),
        #(0.75, bezier.bezier_point(original, at: 0.75)),
      ],
    )
  let assert bezier.CubicBezierData(start:, control1:, control2:, end:) = fit
  let bezier.CubicBezierData(
    start: original_start,
    control1: original_control1,
    control2: original_control2,
    end: original_end,
  ) = original
  let bezier.CubicFitReport(root_sum_square:, root_mean_square:, max:) = error

  assert point_near(start, original_start)
  assert point_near(control1, original_control1)
  assert point_near(control2, original_control2)
  assert point_near(end, original_end)
  assert near(root_sum_square, 0.0)
  assert near(root_mean_square, 0.0)
  assert near(max, 0.0)
}

pub fn fit_cubic_with_endpoints_fits_noisy_samples_test() {
  let original =
    bezier.CubicBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control1: bezier.BezierPoint(10.0, 30.0),
      control2: bezier.BezierPoint(80.0, -10.0),
      end: bezier.BezierPoint(100.0, 0.0),
    )
  let assert Ok(#(fit, error)) =
    bezier.fit_cubic_with_endpoints(
      start: bezier.bezier_start(original),
      end: bezier.bezier_end(original),
      samples: [
        #(0.2, add_point(bezier.bezier_point(original, at: 0.2), 1.0, -2.0)),
        #(0.4, add_point(bezier.bezier_point(original, at: 0.4), -1.0, 1.0)),
        #(0.7, add_point(bezier.bezier_point(original, at: 0.7), 2.0, 1.0)),
        #(0.9, add_point(bezier.bezier_point(original, at: 0.9), -1.0, -1.0)),
      ],
    )
  let bezier.CubicFitReport(root_sum_square:, root_mean_square:, max:) = error

  assert point_near(bezier.bezier_start(fit), bezier.bezier_start(original))
  assert point_near(bezier.bezier_end(fit), bezier.bezier_end(original))
  assert root_sum_square >. 0.0
  assert root_mean_square >. 0.0
  assert max >. 0.0
}

pub fn fit_cubic_with_endpoints_rejects_underdetermined_samples_test() {
  let assert Error(bezier.UnderdeterminedCubicFit) =
    bezier.fit_cubic_with_endpoints(
      start: bezier.BezierPoint(0.0, 0.0),
      end: bezier.BezierPoint(10.0, 0.0),
      samples: [#(0.5, bezier.BezierPoint(5.0, 1.0))],
    )
}

pub fn split_divides_quadratic_at_t_test() {
  let curve =
    bezier.QuadraticBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control: bezier.BezierPoint(10.0, 20.0),
      end: bezier.BezierPoint(20.0, 0.0),
    )

  let #(left, right) = bezier.split(curve, at: 0.25)
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

  assert point_near(left_start, bezier.BezierPoint(0.0, 0.0))
  assert point_near(left_control, bezier.BezierPoint(2.5, 5.0))
  assert point_near(split, bezier.bezier_point(curve, at: 0.25))
  assert point_near(right_start, split)
  assert point_near(right_control, bezier.BezierPoint(12.5, 15.0))
  assert point_near(right_end, bezier.BezierPoint(20.0, 0.0))
}

pub fn split_allows_endpoint_splits_test() {
  let curve =
    bezier.CubicBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control1: bezier.BezierPoint(0.0, 30.0),
      control2: bezier.BezierPoint(30.0, 30.0),
      end: bezier.BezierPoint(30.0, 0.0),
    )

  let #(zero_start, whole_after) = bezier.split(curve, at: 0.0)
  let #(whole_before, zero_end) = bezier.split(curve, at: 1.0)

  assert point_near(
    bezier.bezier_start(zero_start),
    bezier.BezierPoint(0.0, 0.0),
  )
  assert point_near(bezier.bezier_end(zero_start), bezier.BezierPoint(0.0, 0.0))
  assert point_near(
    bezier.bezier_start(whole_after),
    bezier.BezierPoint(0.0, 0.0),
  )
  assert point_near(
    bezier.bezier_end(whole_after),
    bezier.BezierPoint(30.0, 0.0),
  )
  assert point_near(
    bezier.bezier_start(whole_before),
    bezier.BezierPoint(0.0, 0.0),
  )
  assert point_near(
    bezier.bezier_end(whole_before),
    bezier.BezierPoint(30.0, 0.0),
  )
  assert point_near(
    bezier.bezier_start(zero_end),
    bezier.BezierPoint(30.0, 0.0),
  )
  assert point_near(bezier.bezier_end(zero_end), bezier.BezierPoint(30.0, 0.0))
}

pub fn split_inside_rejects_outside_t_test() {
  let curve =
    bezier.LinearBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      end: bezier.BezierPoint(10.0, 20.0),
    )

  let assert Error(bezier.SplitOutsideBezier) =
    bezier.split_inside(curve, at: -0.01)
  let assert Error(bezier.SplitOutsideBezier) =
    bezier.split_inside(curve, at: 1.01)
  let assert Ok(_) = bezier.split_inside(curve, at: 0.0)
  let assert Ok(_) = bezier.split_inside(curve, at: 1.0)
}

pub fn split_many_sorts_and_removes_duplicate_points_test() {
  let curve =
    bezier.LinearBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      end: bezier.BezierPoint(40.0, 0.0),
    )

  let pieces = bezier.split_many(curve, at: [0.75, -0.25, 0.25, 0.25])
  let assert [first, second, third, fourth] = pieces

  assert point_near(bezier.bezier_start(first), bezier.BezierPoint(0.0, 0.0))
  assert point_near(bezier.bezier_end(first), bezier.BezierPoint(-10.0, 0.0))
  assert point_near(bezier.bezier_start(second), bezier.BezierPoint(-10.0, 0.0))
  assert point_near(bezier.bezier_end(second), bezier.BezierPoint(10.0, 0.0))
  assert point_near(bezier.bezier_start(third), bezier.BezierPoint(10.0, 0.0))
  assert point_near(bezier.bezier_end(third), bezier.BezierPoint(30.0, 0.0))
  assert point_near(bezier.bezier_start(fourth), bezier.BezierPoint(30.0, 0.0))
  assert point_near(bezier.bezier_end(fourth), bezier.BezierPoint(40.0, 0.0))
}

pub fn split_inside_many_rejects_any_outside_point_test() {
  let curve =
    bezier.LinearBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      end: bezier.BezierPoint(40.0, 0.0),
    )

  let assert Error(bezier.SplitOutsideBezier) =
    bezier.split_inside_many(curve, at: [0.25, 1.01])
  let assert Error(bezier.SplitOutsideBezier) =
    bezier.split_inside_many(curve, at: [-0.01, 0.75])
}

pub fn split_inside_many_trims_boundary_points_test() {
  let curve =
    bezier.LinearBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      end: bezier.BezierPoint(40.0, 0.0),
    )

  let assert Ok(pieces) =
    bezier.split_inside_many(curve, at: [1.0, 0.0, 0.5, 0.5])
  let assert [first_half, second_half] = pieces

  assert point_near(
    bezier.bezier_start(first_half),
    bezier.BezierPoint(0.0, 0.0),
  )
  assert point_near(
    bezier.bezier_end(first_half),
    bezier.BezierPoint(20.0, 0.0),
  )
  assert point_near(
    bezier.bezier_start(second_half),
    bezier.BezierPoint(20.0, 0.0),
  )
  assert point_near(
    bezier.bezier_end(second_half),
    bezier.BezierPoint(40.0, 0.0),
  )
}

pub fn split_many_keeps_boundary_points_when_they_are_interior_test() {
  let curve =
    bezier.LinearBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      end: bezier.BezierPoint(40.0, 0.0),
    )

  let pieces = bezier.split_many(curve, at: [1.25, 1.0, 0.0, -0.25])
  let assert [before_start, to_start, original_curve, past_end, back_to_end] =
    pieces

  assert point_near(
    bezier.bezier_start(before_start),
    bezier.BezierPoint(0.0, 0.0),
  )
  assert point_near(
    bezier.bezier_end(before_start),
    bezier.BezierPoint(-10.0, 0.0),
  )
  assert point_near(
    bezier.bezier_start(to_start),
    bezier.BezierPoint(-10.0, 0.0),
  )
  assert point_near(bezier.bezier_end(to_start), bezier.BezierPoint(0.0, 0.0))
  assert point_near(
    bezier.bezier_start(original_curve),
    bezier.BezierPoint(0.0, 0.0),
  )
  assert point_near(
    bezier.bezier_end(original_curve),
    bezier.BezierPoint(40.0, 0.0),
  )
  assert point_near(
    bezier.bezier_start(past_end),
    bezier.BezierPoint(40.0, 0.0),
  )
  assert point_near(bezier.bezier_end(past_end), bezier.BezierPoint(50.0, 0.0))
  assert point_near(
    bezier.bezier_start(back_to_end),
    bezier.BezierPoint(50.0, 0.0),
  )
  assert point_near(
    bezier.bezier_end(back_to_end),
    bezier.BezierPoint(40.0, 0.0),
  )
}

pub fn split_many_preserves_cubic_degree_test() {
  let curve =
    bezier.CubicBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control1: bezier.BezierPoint(0.0, 30.0),
      control2: bezier.BezierPoint(30.0, 30.0),
      end: bezier.BezierPoint(30.0, 0.0),
    )

  let pieces = bezier.split_many(curve, at: [0.25, 0.75])
  let assert [
    bezier.CubicBezierData(..),
    bezier.CubicBezierData(..),
    bezier.CubicBezierData(..),
  ] = pieces
}

pub fn cubic_inflection_parameters_finds_an_s_curve_inflection_test() {
  let curve =
    bezier.CubicBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control1: bezier.BezierPoint(0.0, 100.0),
      control2: bezier.BezierPoint(100.0, -100.0),
      end: bezier.BezierPoint(100.0, 0.0),
    )

  let assert [t] = bezier.cubic_inflection_parameters(curve)
  let pieces = bezier.split_many(curve, at: [t])
  let assert [bezier.CubicBezierData(end: split, ..), second] = pieces

  assert near(t, 0.5)
  assert point_near(split, bezier.BezierPoint(50.0, 0.0))
  assert point_near(bezier.bezier_start(second), split)
}

pub fn cubic_inflection_parameters_are_independent_of_coordinate_scale_test() {
  let scale = 0.000000001
  let curve =
    bezier.CubicBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control1: bezier.BezierPoint(0.0, 100.0 *. scale),
      control2: bezier.BezierPoint(100.0 *. scale, -100.0 *. scale),
      end: bezier.BezierPoint(100.0 *. scale, 0.0),
    )

  let assert [t] = bezier.cubic_inflection_parameters(curve)
  assert near(t, 0.5)
}

pub fn cubic_inflection_parameters_ignores_non_inflecting_curves_test() {
  let cubic =
    bezier.CubicBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control1: bezier.BezierPoint(0.0, 30.0),
      control2: bezier.BezierPoint(30.0, 30.0),
      end: bezier.BezierPoint(30.0, 0.0),
    )
  let quadratic =
    bezier.QuadraticBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control: bezier.BezierPoint(10.0, 10.0),
      end: bezier.BezierPoint(20.0, 0.0),
    )

  assert bezier.cubic_inflection_parameters(cubic) == []
  assert bezier.cubic_inflection_parameters(quadratic) == []
}

pub fn cubic_self_intersections_finds_loop_test() {
  let curve =
    bezier.CubicBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control1: bezier.BezierPoint(100.0, 100.0),
      control2: bezier.BezierPoint(-100.0, 100.0),
      end: bezier.BezierPoint(0.0, 0.0),
    )

  let assert Ok([intersection]) = bezier.cubic_self_intersections(curve)
  let bezier.CubicSelfIntersection(s:, t:, point:) = intersection

  assert near(s, 0.0)
  assert near(t, 1.0)
  assert point_near(point, bezier.BezierPoint(0.0, 0.0))
}

pub fn cubic_self_intersections_finds_interior_crossing_test() {
  let curve =
    bezier.CubicBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control1: bezier.BezierPoint(-0.2708333333333333, -0.3333333333333333),
      control2: bezier.BezierPoint(-0.5416666666666666, -0.3333333333333333),
      end: bezier.BezierPoint(0.1875, 0.0),
    )

  let assert Ok([intersection]) = bezier.cubic_self_intersections(curve)
  let bezier.CubicSelfIntersection(s:, t:, point:) = intersection

  assert near(s, 0.25)
  assert near(t, 0.75)
  assert point_near(point, bezier.bezier_point(curve, at: 0.25))
}

pub fn cubic_self_intersections_are_independent_of_coordinate_scale_test() {
  let scale = 0.000000000001
  let curve =
    bezier.CubicBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control1: bezier.BezierPoint(
        -0.2708333333333333 *. scale,
        -0.3333333333333333 *. scale,
      ),
      control2: bezier.BezierPoint(
        -0.5416666666666666 *. scale,
        -0.3333333333333333 *. scale,
      ),
      end: bezier.BezierPoint(0.1875 *. scale, 0.0),
    )

  let assert Ok([bezier.CubicSelfIntersection(s:, t:, ..)]) =
    bezier.cubic_self_intersections_with(
      curve,
      options: bezier.CubicSelfIntersectionOptions(
        minimum_arc_length_separation: 0.000000000000001,
        distance_tolerance: 0.000000000000001,
      ),
    )

  assert near(s, 0.25)
  assert near(t, 0.75)
}

pub fn cubic_self_intersections_ignores_non_looping_cubic_test() {
  let curve =
    bezier.CubicBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control1: bezier.BezierPoint(0.0, 30.0),
      control2: bezier.BezierPoint(30.0, 30.0),
      end: bezier.BezierPoint(30.0, 0.0),
    )

  assert bezier.cubic_self_intersections(curve) == Ok([])
}

pub fn cubic_self_intersections_ignores_non_cubics_test() {
  let line =
    bezier.LinearBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      end: bezier.BezierPoint(10.0, 0.0),
    )
  let quadratic =
    bezier.QuadraticBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control: bezier.BezierPoint(10.0, 10.0),
      end: bezier.BezierPoint(20.0, 0.0),
    )

  assert bezier.cubic_self_intersections(line) == Ok([])
  assert bezier.cubic_self_intersections(quadratic) == Ok([])
}

pub fn cubic_self_intersections_respects_minimum_arc_length_separation_test() {
  let curve =
    bezier.CubicBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control1: bezier.BezierPoint(100.0, 100.0),
      control2: bezier.BezierPoint(-100.0, 100.0),
      end: bezier.BezierPoint(0.0, 0.0),
    )

  assert bezier.cubic_self_intersections_with(
      curve,
      options: bezier.CubicSelfIntersectionOptions(
        minimum_arc_length_separation: 301.0,
        distance_tolerance: 0.000001,
      ),
    )
    == Ok([])
}

pub fn cubic_self_intersections_rejects_invalid_options_test() {
  let curve =
    bezier.CubicBezierData(
      start: bezier.BezierPoint(0.0, 0.0),
      control1: bezier.BezierPoint(100.0, 100.0),
      control2: bezier.BezierPoint(-100.0, 100.0),
      end: bezier.BezierPoint(0.0, 0.0),
    )

  let assert Error(bezier.InvalidCubicSelfIntersectionMinimumArcLengthSeparation(
    0.0,
  )) =
    bezier.cubic_self_intersections_with(
      curve,
      options: bezier.CubicSelfIntersectionOptions(
        minimum_arc_length_separation: 0.0,
        distance_tolerance: 0.000001,
      ),
    )
  let assert Error(bezier.InvalidCubicSelfIntersectionDistanceTolerance(0.0)) =
    bezier.cubic_self_intersections_with(
      curve,
      options: bezier.CubicSelfIntersectionOptions(
        minimum_arc_length_separation: 0.000001,
        distance_tolerance: 0.0,
      ),
    )
}

fn point_near(a: bezier.BezierPoint, b: bezier.BezierPoint) -> Bool {
  near(a.x, b.x) && near(a.y, b.y)
}

fn add_point(
  point: bezier.BezierPoint,
  dx: Float,
  dy: Float,
) -> bezier.BezierPoint {
  bezier.BezierPoint(point.x +. dx, point.y +. dy)
}

fn bbox_near(
  box: bezier.BoundingBox,
  min expected_min: bezier.BezierPoint,
  max expected_max: bezier.BezierPoint,
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
