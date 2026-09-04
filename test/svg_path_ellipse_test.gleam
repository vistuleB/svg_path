import gleam/float
import gleeunit
import svg_path
import svg_path/affine
import svg_path/ellipse
import svg_path_arc_bbox_fixtures

const tolerance = 0.000001

const bbox_tolerance = 0.00001

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn endpoint_to_center_exposes_corrected_center_parameters_test() {
  let start = ellipse.EllipsePoint(0.0, 0.0)
  let end = ellipse.EllipsePoint(20.0, 0.0)
  let assert Ok(arc) =
    ellipse.EndpointArcData(
      start:,
      radius: ellipse.EllipsePoint(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end:,
    )
    |> ellipse.endpoint_to_center

  assert point_near(arc.center, ellipse.EllipsePoint(10.0, 0.0))
  assert point_near(arc.radius, ellipse.EllipsePoint(10.0, 10.0))
  assert near(arc.x_axis_rotation, 0.0)
  assert arc.start_angle >=. -180.0
  assert arc.start_angle <=. 180.0
  assert near(arc.delta_angle, 180.0)
}

pub fn arc_point_uses_angular_progress_test() {
  let start = ellipse.EllipsePoint(0.0, 0.0)
  let end = ellipse.EllipsePoint(20.0, 0.0)
  let assert Ok(arc) =
    ellipse.EndpointArcData(
      start:,
      radius: ellipse.EllipsePoint(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end:,
    )
    |> ellipse.endpoint_to_center

  assert point_near(ellipse.arc_point(arc, at: 0.0), start)
  assert point_near(
    ellipse.arc_point(arc, at: 0.5),
    ellipse.EllipsePoint(10.0, -10.0),
  )
  assert point_near(ellipse.arc_point(arc, at: 1.0), end)
  assert near(ellipse.angle_at(arc, t: 0.5), arc.start_angle +. 90.0)
  assert near(ellipse.arc_end_angle(arc), arc.start_angle +. arc.delta_angle)
}

pub fn arc_derivative_follows_arc_traversal_direction_test() {
  let start = ellipse.EllipsePoint(0.0, 0.0)
  let end = ellipse.EllipsePoint(20.0, 0.0)
  let assert Ok(sweep_arc) =
    ellipse.EndpointArcData(
      start:,
      radius: ellipse.EllipsePoint(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end:,
    )
    |> ellipse.endpoint_to_center
  let assert Ok(non_sweep_arc) =
    ellipse.EndpointArcData(
      start:,
      radius: ellipse.EllipsePoint(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: False,
      end:,
    )
    |> ellipse.endpoint_to_center

  assert ellipse.arc_derivative(sweep_arc, at: 0.5).x >. 0.0
  assert near(ellipse.arc_derivative(sweep_arc, at: 0.5).y, 0.0)
  assert ellipse.arc_derivative(non_sweep_arc, at: 0.5).x >. 0.0
  assert near(ellipse.arc_derivative(non_sweep_arc, at: 0.5).y, 0.0)
}

pub fn transformed_axes_accepts_radii_below_old_squared_threshold_test() {
  let assert Ok(#(radius, _rotation)) =
    ellipse.transformed_axes(
      radius: ellipse.EllipsePoint(0.00001, 0.00002),
      x_axis_rotation: 17.0,
      by: affine.identity(),
    )

  assert near(float.min(radius.x, radius.y), 0.00001)
  assert near(float.max(radius.x, radius.y), 0.00002)
}

pub fn collapsed_arc_collinearity_is_scale_relative_test() {
  let nearly_rank_one =
    affine.matrix(a: 1.0, b: 0.0, c: 1.0, d: 0.0000000001, e: 0.0, f: 0.0)

  let assert Ok(_) =
    ellipse.collapsed_arc_line(
      start: ellipse.EllipsePoint(1.0, 0.0),
      radius: ellipse.EllipsePoint(1.0, 1.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: ellipse.EllipsePoint(-1.0, 0.0),
      by: nearly_rank_one,
    )
  let assert Ok(_) =
    ellipse.collapsed_arc_line(
      start: ellipse.EllipsePoint(1.0e9, 0.0),
      radius: ellipse.EllipsePoint(1.0e9, 1.0e9),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: ellipse.EllipsePoint(-1.0e9, 0.0),
      by: nearly_rank_one,
    )
}

pub fn arc_bounding_box_of_sweep_half_circle_uses_lower_half_test() {
  let assert Ok(arc) =
    ellipse.EndpointArcData(
      start: ellipse.EllipsePoint(0.0, 0.0),
      radius: ellipse.EllipsePoint(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: ellipse.EllipsePoint(20.0, 0.0),
    )
    |> ellipse.endpoint_to_center

  assert bbox_near(
    ellipse.arc_bounding_box(arc),
    min: ellipse.EllipsePoint(0.0, -10.0),
    max: ellipse.EllipsePoint(20.0, 0.0),
  )
}

pub fn arc_bounding_box_of_non_sweep_half_circle_uses_upper_half_test() {
  let assert Ok(arc) =
    ellipse.EndpointArcData(
      start: ellipse.EllipsePoint(0.0, 0.0),
      radius: ellipse.EllipsePoint(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: False,
      end: ellipse.EllipsePoint(20.0, 0.0),
    )
    |> ellipse.endpoint_to_center

  assert bbox_near(
    ellipse.arc_bounding_box(arc),
    min: ellipse.EllipsePoint(0.0, 0.0),
    max: ellipse.EllipsePoint(20.0, 10.0),
  )
}

pub fn arc_bounding_box_of_rotated_arc_includes_interior_extrema_test() {
  let arc =
    ellipse.CenterArcData(
      center: ellipse.EllipsePoint(2.0, -3.0),
      radius: ellipse.EllipsePoint(12.0, 5.0),
      x_axis_rotation: 30.0,
      start_angle: -68.75493541569878,
      delta_angle: 252.1015816987223,
    )

  assert bbox_near(
    ellipse.arc_bounding_box(arc),
    min: ellipse.EllipsePoint(-8.688779, -9.242547),
    max: ellipse.EllipsePoint(12.688779, 4.399324),
  )
}

pub fn arc_bounding_box_matches_generated_fixtures_test() {
  assert_bounding_boxes(svg_path_arc_bbox_fixtures.fixtures())
}

pub fn split_arc_divides_center_data_at_t_test() {
  let arc =
    ellipse.CenterArcData(
      center: ellipse.EllipsePoint(2.0, 3.0),
      radius: ellipse.EllipsePoint(5.0, 7.0),
      x_axis_rotation: 30.0,
      start_angle: 0.25,
      delta_angle: 2.0,
    )

  let #(left, right) = ellipse.split_arc(arc, at: 0.25)

  assert point_near(left.center, arc.center)
  assert point_near(left.radius, arc.radius)
  assert near(left.x_axis_rotation, arc.x_axis_rotation)
  assert near(left.start_angle, arc.start_angle)
  assert near(left.delta_angle, 0.5)
  assert point_near(right.center, arc.center)
  assert point_near(right.radius, arc.radius)
  assert near(right.x_axis_rotation, arc.x_axis_rotation)
  assert near(right.start_angle, arc.start_angle +. 0.5)
  assert near(right.delta_angle, 1.5)
  assert point_near(
    ellipse.arc_point(left, at: 1.0),
    ellipse.arc_point(arc, at: 0.25),
  )
  assert point_near(
    ellipse.arc_point(right, at: 0.0),
    ellipse.arc_point(arc, at: 0.25),
  )
}

pub fn split_arc_allows_endpoint_splits_test() {
  let arc =
    ellipse.CenterArcData(
      center: ellipse.EllipsePoint(0.0, 0.0),
      radius: ellipse.EllipsePoint(5.0, 5.0),
      x_axis_rotation: 0.0,
      start_angle: 1.0,
      delta_angle: -2.0,
    )

  let #(zero_start, whole_after) = ellipse.split_arc(arc, at: 0.0)
  let #(whole_before, zero_end) = ellipse.split_arc(arc, at: 1.0)

  assert near(zero_start.delta_angle, 0.0)
  assert near(zero_start.start_angle, arc.start_angle)
  assert near(whole_after.start_angle, arc.start_angle)
  assert near(whole_after.delta_angle, arc.delta_angle)
  assert near(whole_before.start_angle, arc.start_angle)
  assert near(whole_before.delta_angle, arc.delta_angle)
  assert near(zero_end.start_angle, ellipse.arc_end_angle(arc))
  assert near(zero_end.delta_angle, 0.0)
}

pub fn split_arc_extrapolates_outside_t_test() {
  let arc =
    ellipse.CenterArcData(
      center: ellipse.EllipsePoint(0.0, 0.0),
      radius: ellipse.EllipsePoint(5.0, 5.0),
      x_axis_rotation: 0.0,
      start_angle: 1.0,
      delta_angle: 2.0,
    )

  let #(before, through_end) = ellipse.split_arc(arc, at: -0.25)
  let #(through_past_end, back_to_end) = ellipse.split_arc(arc, at: 1.25)

  assert near(before.delta_angle, -0.5)
  assert near(through_end.start_angle, 0.5)
  assert near(through_end.delta_angle, 2.5)
  assert near(through_past_end.delta_angle, 2.5)
  assert near(back_to_end.start_angle, 3.5)
  assert near(back_to_end.delta_angle, -0.5)
}

pub fn split_arc_inside_rejects_outside_t_test() {
  let arc =
    ellipse.CenterArcData(
      center: ellipse.EllipsePoint(0.0, 0.0),
      radius: ellipse.EllipsePoint(5.0, 5.0),
      x_axis_rotation: 0.0,
      start_angle: 1.0,
      delta_angle: 2.0,
    )

  let assert Error(ellipse.SplitOutsideArc) =
    ellipse.split_arc_inside(arc, at: -0.01)
  let assert Error(ellipse.SplitOutsideArc) =
    ellipse.split_arc_inside(arc, at: 1.01)
  let assert Ok(_) = ellipse.split_arc_inside(arc, at: 0.0)
  let assert Ok(_) = ellipse.split_arc_inside(arc, at: 1.0)
}

pub fn split_arc_many_sorts_and_removes_duplicate_points_test() {
  let arc =
    ellipse.CenterArcData(
      center: ellipse.EllipsePoint(0.0, 0.0),
      radius: ellipse.EllipsePoint(5.0, 5.0),
      x_axis_rotation: 0.0,
      start_angle: 1.0,
      delta_angle: 4.0,
    )

  let pieces = ellipse.split_arc_many(arc, at: [0.75, -0.25, 0.25, 0.25])
  let assert [first, second, third, fourth] = pieces

  assert near(first.start_angle, 1.0)
  assert near(first.delta_angle, -1.0)
  assert near(second.start_angle, 0.0)
  assert near(second.delta_angle, 2.0)
  assert near(third.start_angle, 2.0)
  assert near(third.delta_angle, 2.0)
  assert near(fourth.start_angle, 4.0)
  assert near(fourth.delta_angle, 1.0)
}

pub fn split_arc_many_without_points_returns_original_arc_test() {
  let arc =
    ellipse.CenterArcData(
      center: ellipse.EllipsePoint(0.0, 0.0),
      radius: ellipse.EllipsePoint(5.0, 5.0),
      x_axis_rotation: 0.0,
      start_angle: 1.0,
      delta_angle: 4.0,
    )

  let assert [piece] = ellipse.split_arc_many(arc, at: [])

  assert near(piece.start_angle, arc.start_angle)
  assert near(piece.delta_angle, arc.delta_angle)
}

pub fn split_arc_inside_many_rejects_any_outside_point_test() {
  let arc =
    ellipse.CenterArcData(
      center: ellipse.EllipsePoint(0.0, 0.0),
      radius: ellipse.EllipsePoint(5.0, 5.0),
      x_axis_rotation: 0.0,
      start_angle: 1.0,
      delta_angle: 4.0,
    )

  let assert Error(ellipse.SplitOutsideArc) =
    ellipse.split_arc_inside_many(arc, at: [0.25, 1.01])
  let assert Error(ellipse.SplitOutsideArc) =
    ellipse.split_arc_inside_many(arc, at: [-0.01, 0.75])
}

pub fn split_arc_inside_many_accepts_endpoint_points_test() {
  let arc =
    ellipse.CenterArcData(
      center: ellipse.EllipsePoint(0.0, 0.0),
      radius: ellipse.EllipsePoint(5.0, 5.0),
      x_axis_rotation: 0.0,
      start_angle: 1.0,
      delta_angle: 4.0,
    )

  let assert Ok(pieces) =
    ellipse.split_arc_inside_many(arc, at: [1.0, 0.0, 0.5, 0.5])
  let assert [first_half, second_half] = pieces

  assert near(first_half.start_angle, 1.0)
  assert near(first_half.delta_angle, 2.0)
  assert near(second_half.start_angle, 3.0)
  assert near(second_half.delta_angle, 2.0)
}

pub fn split_arc_many_keeps_boundary_points_when_they_are_interior_test() {
  let arc =
    ellipse.CenterArcData(
      center: ellipse.EllipsePoint(0.0, 0.0),
      radius: ellipse.EllipsePoint(5.0, 5.0),
      x_axis_rotation: 0.0,
      start_angle: 1.0,
      delta_angle: 4.0,
    )

  let pieces = ellipse.split_arc_many(arc, at: [1.25, 1.0, 0.0, -0.25])
  let assert [before_start, to_start, original_arc, past_end, back_to_end] =
    pieces

  assert near(before_start.start_angle, 1.0)
  assert near(before_start.delta_angle, -1.0)
  assert near(to_start.start_angle, 0.0)
  assert near(to_start.delta_angle, 1.0)
  assert near(original_arc.start_angle, 1.0)
  assert near(original_arc.delta_angle, 4.0)
  assert near(past_end.start_angle, 5.0)
  assert near(past_end.delta_angle, 1.0)
  assert near(back_to_end.start_angle, 6.0)
  assert near(back_to_end.delta_angle, -1.0)
}

pub fn large_arc_and_sweep_are_derived_from_delta_angle_test() {
  let assert Ok(large_sweep_arc) =
    ellipse.EndpointArcData(
      start: ellipse.EllipsePoint(0.0, 0.0),
      radius: ellipse.EllipsePoint(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: True,
      sweep: True,
      end: ellipse.EllipsePoint(10.0, 0.0),
    )
    |> ellipse.endpoint_to_center
  let assert Ok(small_non_sweep_arc) =
    ellipse.EndpointArcData(
      start: ellipse.EllipsePoint(0.0, 0.0),
      radius: ellipse.EllipsePoint(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: False,
      end: ellipse.EllipsePoint(10.0, 0.0),
    )
    |> ellipse.endpoint_to_center

  assert ellipse.arc_large_arc(large_sweep_arc)
  assert ellipse.arc_sweep(large_sweep_arc)
  assert large_sweep_arc.delta_angle >. 180.0
  assert !ellipse.arc_large_arc(small_non_sweep_arc)
  assert !ellipse.arc_sweep(small_non_sweep_arc)
  assert small_non_sweep_arc.delta_angle <. 0.0
  assert float.absolute_value(small_non_sweep_arc.delta_angle) <. 180.0
}

pub fn endpoint_to_center_scales_small_radii_up_test() {
  let assert Ok(arc) =
    ellipse.EndpointArcData(
      start: ellipse.EllipsePoint(0.0, 0.0),
      radius: ellipse.EllipsePoint(1.0, 1.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: ellipse.EllipsePoint(20.0, 0.0),
    )
    |> ellipse.endpoint_to_center

  assert point_near(arc.radius, ellipse.EllipsePoint(10.0, 10.0))
}

pub fn endpoint_to_center_rejects_coincident_endpoints_test() {
  let point = ellipse.EllipsePoint(3.0, 4.0)
  let endpoint =
    ellipse.EndpointArcData(
      start: point,
      radius: ellipse.EllipsePoint(10.0, 20.0),
      x_axis_rotation: 30.0,
      large_arc: True,
      sweep: False,
      end: point,
    )

  assert ellipse.endpoint_to_center(endpoint)
    == Error(ellipse.DegenerateInputArc)
}

pub fn center_to_endpoint_round_trips_arc_data_test() {
  let endpoint =
    ellipse.EndpointArcData(
      start: ellipse.EllipsePoint(0.0, 0.0),
      radius: ellipse.EllipsePoint(8.0, 12.0),
      x_axis_rotation: 30.0,
      large_arc: True,
      sweep: False,
      end: ellipse.EllipsePoint(10.0, 5.0),
    )
  let assert Ok(center) = ellipse.endpoint_to_center(endpoint)
  let converted = ellipse.center_to_endpoint(center)

  assert point_near(converted.start, endpoint.start)
  assert point_near(converted.end, endpoint.end)
  assert point_near(converted.radius, center.radius)
  assert near(converted.x_axis_rotation, endpoint.x_axis_rotation)
  assert converted.large_arc == ellipse.arc_large_arc(center)
  assert converted.sweep == ellipse.arc_sweep(center)
}

pub fn arc_from_center_data_creates_svg_path_arc_test() {
  let center =
    ellipse.CenterArcData(
      center: ellipse.EllipsePoint(10.0, 0.0),
      radius: ellipse.EllipsePoint(10.0, 10.0),
      x_axis_rotation: 0.0,
      start_angle: 180.0,
      delta_angle: 180.0,
    )

  let assert svg_path.Arc(
    start:,
    radius:,
    x_axis_rotation:,
    large_arc:,
    sweep:,
    end:,
  ) = svg_path.arc_from_center_data(center)

  assert svg_path_point_near(start, svg_path.Point(0.0, 0.0))
  assert svg_path_point_near(radius, svg_path.Point(10.0, 10.0))
  assert near(x_axis_rotation, 0.0)
  assert !large_arc
  assert sweep
  assert svg_path_point_near(end, svg_path.Point(20.0, 0.0))
}

pub fn arc_from_endpoint_data_creates_svg_path_arc_test() {
  let endpoint =
    ellipse.EndpointArcData(
      start: ellipse.EllipsePoint(0.0, 1.0),
      radius: ellipse.EllipsePoint(2.0, 3.0),
      x_axis_rotation: 15.0,
      large_arc: True,
      sweep: False,
      end: ellipse.EllipsePoint(4.0, 5.0),
    )

  let assert svg_path.Arc(
    start:,
    radius:,
    x_axis_rotation:,
    large_arc:,
    sweep:,
    end:,
  ) = svg_path.arc_from_endpoint_data(endpoint)

  assert svg_path_point_near(start, svg_path.Point(0.0, 1.0))
  assert svg_path_point_near(radius, svg_path.Point(2.0, 3.0))
  assert near(x_axis_rotation, 15.0)
  assert large_arc
  assert !sweep
  assert svg_path_point_near(end, svg_path.Point(4.0, 5.0))
}

fn point_near(a: ellipse.EllipsePoint, b: ellipse.EllipsePoint) -> Bool {
  near(a.x, b.x) && near(a.y, b.y)
}

fn bbox_near(
  box: ellipse.BoundingBox,
  min expected_min: ellipse.EllipsePoint,
  max expected_max: ellipse.EllipsePoint,
) -> Bool {
  let ellipse.BoundingBox(min:, max:) = box
  bbox_point_near(min, expected_min) && bbox_point_near(max, expected_max)
}

fn bbox_point_near(a: ellipse.EllipsePoint, b: ellipse.EllipsePoint) -> Bool {
  float.absolute_value(a.x -. b.x) <=. bbox_tolerance
  && float.absolute_value(a.y -. b.y) <=. bbox_tolerance
}

fn assert_bounding_boxes(
  fixtures: List(svg_path_arc_bbox_fixtures.ArcBBoxFixture),
) -> Nil {
  case fixtures {
    [] -> Nil
    [fixture, ..rest] -> {
      let svg_path_arc_bbox_fixtures.ArcBBoxFixture(
        arc:,
        min: expected_min,
        max: expected_max,
        ..,
      ) = fixture
      assert bbox_near(
        ellipse.arc_bounding_box(arc),
        min: expected_min,
        max: expected_max,
      )
      assert_bounding_boxes(rest)
    }
  }
}

fn svg_path_point_near(a: svg_path.Point, b: svg_path.Point) -> Bool {
  near(a.x, b.x) && near(a.y, b.y)
}

fn near(a: Float, b: Float) -> Bool {
  float.absolute_value(a -. b) <=. tolerance
}
