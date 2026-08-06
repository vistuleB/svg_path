import gleam/list
import gleeunit
import svg_path
import svg_path/intersections

pub fn main() -> Nil {
  gleeunit.main()
}

fn line_subpath(
  start: svg_path.Point,
  end: svg_path.Point,
) -> svg_path.Subpath {
  svg_path.Line(start:, end:) |> svg_path.segment_as_subpath
}

fn quarter_arc_circle(
  center: svg_path.Point,
  radius: Float,
  start_on_right start_on_right: Bool,
  sweep sweep: Bool,
) -> svg_path.Subpath {
  let right = svg_path.Point(center.x +. radius, center.y)
  let bottom = svg_path.Point(center.x, center.y +. radius)
  let left = svg_path.Point(center.x -. radius, center.y)
  let top = svg_path.Point(center.x, center.y -. radius)
  let points = case start_on_right, sweep {
    True, True -> [right, bottom, left, top, right]
    True, False -> [right, top, left, bottom, right]
    False, True -> [left, top, right, bottom, left]
    False, False -> [left, bottom, right, top, left]
  }
  let assert [a, b, c, d, e] = points
  [#(a, b), #(b, c), #(c, d), #(d, e)]
  |> list.map(fn(pair) {
    svg_path.Arc(
      start: pair.0,
      radius: svg_path.Point(radius, radius),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep:,
      end: pair.1,
    )
  })
  |> svg_path.subpath_assert
  |> svg_path.subpath_assert_set_closed(closed: True)
}

pub fn transverse_lines_classify_clockwise_crossing_test() {
  let left = line_subpath(svg_path.Point(-1.0, 0.0), svg_path.Point(1.0, 0.0))
  let right = line_subpath(svg_path.Point(0.0, -1.0), svg_path.Point(0.0, 1.0))

  let assert Ok(intersections.Crossing(
    intersections.Clockwise,
    apertures: intersections.IntersectionApertures(
      first_incoming_to_second_incoming: 90.0,
      first_incoming_to_second_outgoing: 90.0,
      first_outgoing_to_second_incoming: 90.0,
      first_outgoing_to_second_outgoing: 90.0,
    ),
  )) =
    intersections.classify_subpath_intersection(
      left,
      right,
      first_parameter: svg_path.SubpathParameter(0, 0.5),
      second_parameter: svg_path.SubpathParameter(0, 0.5),
    )
}

pub fn reversing_right_traversal_reverses_crossing_direction_test() {
  let left = line_subpath(svg_path.Point(-1.0, 0.0), svg_path.Point(1.0, 0.0))
  let right = line_subpath(svg_path.Point(0.0, 1.0), svg_path.Point(0.0, -1.0))

  let assert Ok(intersections.Crossing(intersections.Counterclockwise, ..)) =
    intersections.classify_subpath_intersection(
      left,
      right,
      first_parameter: svg_path.SubpathParameter(0, 0.5),
      second_parameter: svg_path.SubpathParameter(0, 0.5),
    )
}

pub fn tangent_parabola_and_line_classify_touching_test() {
  let parabola =
    svg_path.subpath_assert([
      svg_path.QuadraticBezier(
        start: svg_path.Point(-1.0, 1.0),
        control: svg_path.Point(0.0, -1.0),
        end: svg_path.Point(1.0, 1.0),
      ),
    ])
  let line = line_subpath(svg_path.Point(-1.0, 0.0), svg_path.Point(1.0, 0.0))

  let assert Ok(intersections.Touching(
    direction: intersections.SimilarlyDirected,
    incoming_order: intersections.ClockwiseFromFirstToSecond,
    outgoing_order: intersections.ClockwiseFromSecondToFirst,
    ..,
  )) =
    intersections.classify_subpath_intersection(
      parabola,
      line,
      first_parameter: svg_path.SubpathParameter(0, 0.5),
      second_parameter: svg_path.SubpathParameter(0, 0.5),
    )
}

pub fn tangential_cubic_crossing_has_same_order_on_both_sides_test() {
  let line = line_subpath(svg_path.Point(-1.0, 0.0), svg_path.Point(1.0, 0.0))
  let cubic =
    svg_path.CubicBezier(
      start: svg_path.Point(-1.0, -1.0),
      control1: svg_path.Point(-0.3333333333333333, 1.0),
      control2: svg_path.Point(0.3333333333333333, -1.0),
      end: svg_path.Point(1.0, 1.0),
    )
    |> svg_path.segment_as_subpath

  let assert Ok(intersections.Touching(
    direction: intersections.SimilarlyDirected,
    incoming_order: intersections.ClockwiseFromFirstToSecond,
    outgoing_order: intersections.ClockwiseFromFirstToSecond,
    ..,
  )) =
    intersections.classify_subpath_intersection(
      line,
      cubic,
      first_parameter: svg_path.SubpathParameter(0, 0.5),
      second_parameter: svg_path.SubpathParameter(0, 0.5),
    )
}

pub fn opposite_tangent_traversals_classify_oppositely_directed_test() {
  let parabola =
    svg_path.subpath_assert([
      svg_path.QuadraticBezier(
        start: svg_path.Point(-1.0, 1.0),
        control: svg_path.Point(0.0, -1.0),
        end: svg_path.Point(1.0, 1.0),
      ),
    ])
  let line = line_subpath(svg_path.Point(1.0, 0.0), svg_path.Point(-1.0, 0.0))

  let assert Ok(intersections.Touching(intersections.OppositelyDirected, ..)) =
    intersections.classify_subpath_intersection(
      parabola,
      line,
      first_parameter: svg_path.SubpathParameter(0, 0.5),
      second_parameter: svg_path.SubpathParameter(0, 0.5),
    )
}

pub fn unequal_externally_kissing_quarter_arc_circles_report_orders_test() {
  [#(1.0, 3.0), #(3.0, 1.0), #(0.25, 8.0)]
  |> list.each(fn(radii) {
    let #(first_radius, second_radius) = radii
    let contact = svg_path.Point(first_radius, 0.0)
    let first =
      quarter_arc_circle(
        svg_path.Point(0.0, 0.0),
        first_radius,
        start_on_right: True,
        sweep: True,
      )
    let second =
      quarter_arc_circle(
        svg_path.Point(first_radius +. second_radius, 0.0),
        second_radius,
        start_on_right: False,
        sweep: False,
      )
    let assert Ok(intersections.Touching(
      direction: intersections.SimilarlyDirected,
      incoming_order: intersections.ClockwiseFromFirstToSecond,
      outgoing_order: intersections.ClockwiseFromSecondToFirst,
      ..,
    )) =
      intersections.classify_subpath_intersection(
        first,
        second,
        first_parameter: svg_path.SubpathParameter(0, 0.0),
        second_parameter: svg_path.SubpathParameter(0, 0.0),
      )
    assert svg_path.subpath_point(first, at: svg_path.SubpathParameter(0, 0.0))
      == Ok(contact)
  })
}

pub fn swapping_kissing_quarter_arc_arguments_reverses_orders_test() {
  let first_radius = 2.0
  let second_radius = 5.0
  let first =
    quarter_arc_circle(
      svg_path.Point(0.0, 0.0),
      first_radius,
      start_on_right: True,
      sweep: True,
    )
  let second =
    quarter_arc_circle(
      svg_path.Point(first_radius +. second_radius, 0.0),
      second_radius,
      start_on_right: False,
      sweep: False,
    )

  let assert Ok(intersections.Touching(
    incoming_order: intersections.ClockwiseFromSecondToFirst,
    outgoing_order: intersections.ClockwiseFromFirstToSecond,
    ..,
  )) =
    intersections.classify_subpath_intersection(
      second,
      first,
      first_parameter: svg_path.SubpathParameter(0, 0.0),
      second_parameter: svg_path.SubpathParameter(0, 0.0),
    )
}

pub fn oppositely_traversed_kissing_quarter_arcs_pair_geometric_sides_test() {
  let first_radius = 4.0
  let second_radius = 1.5
  let first =
    quarter_arc_circle(
      svg_path.Point(0.0, 0.0),
      first_radius,
      start_on_right: True,
      sweep: True,
    )
  let second =
    quarter_arc_circle(
      svg_path.Point(first_radius +. second_radius, 0.0),
      second_radius,
      start_on_right: False,
      sweep: True,
    )

  let assert Ok(intersections.Touching(
    direction: intersections.OppositelyDirected,
    incoming_order: intersections.ClockwiseFromFirstToSecond,
    outgoing_order: intersections.ClockwiseFromSecondToFirst,
    ..,
  )) =
    intersections.classify_subpath_intersection(
      first,
      second,
      first_parameter: svg_path.SubpathParameter(0, 0.0),
      second_parameter: svg_path.SubpathParameter(0, 0.0),
    )
}

pub fn unequal_internally_kissing_quarter_arc_circles_need_equal_chords_test() {
  [#(8.0, 1.0), #(8.0, 3.0), #(100.0, 0.5)]
  |> list.each(fn(radii) {
    let #(outer_radius, inner_radius) = radii
    let outer =
      quarter_arc_circle(
        svg_path.Point(0.0, 0.0),
        outer_radius,
        start_on_right: True,
        sweep: True,
      )
    let inner =
      quarter_arc_circle(
        svg_path.Point(outer_radius -. inner_radius, 0.0),
        inner_radius,
        start_on_right: True,
        sweep: True,
      )

    let assert Ok(intersections.Touching(
      direction: intersections.SimilarlyDirected,
      incoming_order: intersections.ClockwiseFromSecondToFirst,
      outgoing_order: intersections.ClockwiseFromFirstToSecond,
      ..,
    )) =
      intersections.classify_subpath_intersection(
        outer,
        inner,
        first_parameter: svg_path.SubpathParameter(0, 0.0),
        second_parameter: svg_path.SubpathParameter(0, 0.0),
      )
  })
}

pub fn open_endpoint_to_interior_is_reported_before_direction_topology_test() {
  let left = line_subpath(svg_path.Point(0.0, 0.0), svg_path.Point(1.0, 0.0))
  let right = line_subpath(svg_path.Point(0.0, -1.0), svg_path.Point(0.0, 1.0))

  assert intersections.classify_subpath_intersection(
      left,
      right,
      first_parameter: svg_path.SubpathParameter(0, 0.0),
      second_parameter: svg_path.SubpathParameter(0, 0.5),
    )
    == Ok(
      intersections.EndpointContact(intersections.FirstEndpointToSecondInterior(
        intersections.StartEndpoint,
      )),
    )
}

pub fn directionless_interior_is_indeterminate_test() {
  let point = svg_path.Point(0.0, 0.0)
  let left = svg_path.subpath_assert([svg_path.Line(point, point)])
  let right = line_subpath(svg_path.Point(0.0, -1.0), svg_path.Point(0.0, 1.0))

  assert intersections.classify_subpath_intersection(
      left,
      right,
      first_parameter: svg_path.SubpathParameter(0, 0.5),
      second_parameter: svg_path.SubpathParameter(0, 0.5),
    )
    == Ok(intersections.Indeterminate)
}

pub fn grouped_intersection_expands_parameter_cartesian_product_test() {
  let horizontal =
    line_subpath(svg_path.Point(-1.0, 0.0), svg_path.Point(1.0, 0.0))
  let vertical =
    line_subpath(svg_path.Point(0.0, -1.0), svg_path.Point(0.0, 1.0))
  let intersection =
    svg_path.SubpathIntersection(
      point: svg_path.Point(0.0, 0.0),
      left_parameters: [
        svg_path.SubpathParameter(0, 0.25),
        svg_path.SubpathParameter(0, 0.75),
      ],
      right_parameters: [
        svg_path.SubpathParameter(0, 0.25),
        svg_path.SubpathParameter(0, 0.75),
      ],
    )

  let assert Ok(classified) =
    intersections.classify_grouped_subpath_intersection(
      horizontal,
      vertical,
      intersection,
    )
  assert list.length(classified) == 4
}

pub fn classification_rejects_out_of_range_angular_tolerance_test() {
  let left = line_subpath(svg_path.Point(-1.0, 0.0), svg_path.Point(1.0, 0.0))
  let right = line_subpath(svg_path.Point(0.0, -1.0), svg_path.Point(0.0, 1.0))
  assert intersections.classify_subpath_intersection_with(
      left,
      right,
      first_parameter: svg_path.SubpathParameter(0, 0.5),
      second_parameter: svg_path.SubpathParameter(0, 0.5),
      options: intersections.ClassificationOptions(
        direction_options: svg_path.default_direction_options(),
        angular_tolerance: 180.0,
        distance_tolerance: 0.000000000001,
        length_options: svg_path.default_length_options(),
        initial_arc_length: 0.000001,
        maximum_arc_length: 0.25,
        max_sampling_steps: 18,
      ),
    )
    == Error(intersections.InvalidAngularTolerance(180.0))
}
