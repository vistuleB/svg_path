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
  svg_path.subpath_assert([svg_path.Line(start:, end:)])
}

pub fn transverse_lines_classify_clockwise_crossing_test() {
  let left = line_subpath(svg_path.Point(-1.0, 0.0), svg_path.Point(1.0, 0.0))
  let right = line_subpath(svg_path.Point(0.0, -1.0), svg_path.Point(0.0, 1.0))

  let assert Ok(intersections.Crossing(
    intersections.Clockwise,
    apertures: intersections.IntersectionApertures(
      left_incoming_to_right_incoming: 90.0,
      left_incoming_to_right_outgoing: 90.0,
      left_outgoing_to_right_incoming: 90.0,
      left_outgoing_to_right_outgoing: 90.0,
    ),
  )) =
    intersections.classify_subpath_intersection(
      left,
      right,
      left_parameter: svg_path.SubpathParameter(0, 0.5),
      right_parameter: svg_path.SubpathParameter(0, 0.5),
    )
}

pub fn reversing_right_traversal_reverses_crossing_direction_test() {
  let left = line_subpath(svg_path.Point(-1.0, 0.0), svg_path.Point(1.0, 0.0))
  let right = line_subpath(svg_path.Point(0.0, 1.0), svg_path.Point(0.0, -1.0))

  let assert Ok(intersections.Crossing(intersections.Counterclockwise, ..)) =
    intersections.classify_subpath_intersection(
      left,
      right,
      left_parameter: svg_path.SubpathParameter(0, 0.5),
      right_parameter: svg_path.SubpathParameter(0, 0.5),
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

  let assert Ok(intersections.Touching(intersections.SimilarlyDirected, ..)) =
    intersections.classify_subpath_intersection(
      parabola,
      line,
      left_parameter: svg_path.SubpathParameter(0, 0.5),
      right_parameter: svg_path.SubpathParameter(0, 0.5),
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
      left_parameter: svg_path.SubpathParameter(0, 0.5),
      right_parameter: svg_path.SubpathParameter(0, 0.5),
    )
}

pub fn open_endpoint_to_interior_is_reported_before_direction_topology_test() {
  let left = line_subpath(svg_path.Point(0.0, 0.0), svg_path.Point(1.0, 0.0))
  let right = line_subpath(svg_path.Point(0.0, -1.0), svg_path.Point(0.0, 1.0))

  assert intersections.classify_subpath_intersection(
      left,
      right,
      left_parameter: svg_path.SubpathParameter(0, 0.0),
      right_parameter: svg_path.SubpathParameter(0, 0.5),
    )
    == Ok(
      intersections.EndpointContact(intersections.LeftEndpointToRightInterior(
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
      left_parameter: svg_path.SubpathParameter(0, 0.5),
      right_parameter: svg_path.SubpathParameter(0, 0.5),
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
      left_parameter: svg_path.SubpathParameter(0, 0.5),
      right_parameter: svg_path.SubpathParameter(0, 0.5),
      options: intersections.ClassificationOptions(
        direction_options: svg_path.default_direction_options(),
        angular_tolerance: 180.0,
      ),
    )
    == Error(intersections.InvalidAngularTolerance(180.0))
}
