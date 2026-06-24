import gleam/float
import gleam/list
import gleeunit
import svg_path

const tolerance = 0.000001

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn line_keeps_its_endpoints_test() {
  let start = svg_path.point(0.0, 0.0)
  let end = svg_path.point(10.0, 20.0)
  let segment = svg_path.Line(start:, end:)

  assert svg_path.segment_start(segment) == start
  assert svg_path.segment_end(segment) == end
}

pub fn reverse_segment_reverses_lines_quadratics_cubics_and_arcs_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)

  assert svg_path.reverse_segment(svg_path.Line(start: a, end: b))
    == svg_path.Line(start: b, end: a)
  assert svg_path.reverse_segment(svg_path.QuadraticBezier(
      start: a,
      control: b,
      end: c,
    ))
    == svg_path.QuadraticBezier(start: c, control: b, end: a)
  assert svg_path.reverse_segment(svg_path.CubicBezier(
      start: a,
      control1: b,
      control2: c,
      end: d,
    ))
    == svg_path.CubicBezier(start: d, control1: c, control2: b, end: a)
  assert svg_path.reverse_segment(svg_path.Arc(
      start: a,
      radius: svg_path.point(4.0, 5.0),
      x_axis_rotation: 30.0,
      large_arc: True,
      sweep: False,
      end: b,
    ))
    == svg_path.Arc(
      start: b,
      radius: svg_path.point(4.0, 5.0),
      x_axis_rotation: 30.0,
      large_arc: True,
      sweep: True,
      end: a,
    )
}

pub fn reverse_segment_swaps_start_and_end_test() {
  let segment =
    svg_path.CubicBezier(
      start: svg_path.point(0.0, 0.0),
      control1: svg_path.point(1.0, 2.0),
      control2: svg_path.point(3.0, 4.0),
      end: svg_path.point(5.0, 6.0),
    )
  let reversed = svg_path.reverse_segment(segment)

  assert svg_path.segment_start(reversed) == svg_path.segment_end(segment)
  assert svg_path.segment_end(reversed) == svg_path.segment_start(segment)
}

pub fn segment_point_evaluates_lines_quadratics_cubics_and_arcs_test() {
  let assert Ok(line_point) =
    svg_path.segment_point(
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 20.0),
      ),
      at: 0.5,
    )
  let assert Ok(quadratic_point) =
    svg_path.segment_point(
      svg_path.QuadraticBezier(
        start: svg_path.point(0.0, 0.0),
        control: svg_path.point(10.0, 20.0),
        end: svg_path.point(20.0, 0.0),
      ),
      at: 0.5,
    )
  let assert Ok(cubic_point) =
    svg_path.segment_point(
      svg_path.CubicBezier(
        start: svg_path.point(0.0, 0.0),
        control1: svg_path.point(0.0, 30.0),
        control2: svg_path.point(30.0, 30.0),
        end: svg_path.point(30.0, 0.0),
      ),
      at: 0.5,
    )
  let assert Ok(arc_point) =
    svg_path.segment_point(
      svg_path.Arc(
        start: svg_path.point(0.0, 0.0),
        radius: svg_path.point(10.0, 10.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.point(20.0, 0.0),
      ),
      at: 0.5,
    )

  assert point_near(line_point, svg_path.point(5.0, 10.0))
  assert point_near(quadratic_point, svg_path.point(10.0, 10.0))
  assert point_near(cubic_point, svg_path.point(15.0, 22.5))
  assert point_near(arc_point, svg_path.point(10.0, -10.0))
}

pub fn segment_derivative_evaluates_lines_quadratics_cubics_and_arcs_test() {
  let assert Ok(line_derivative) =
    svg_path.segment_derivative(
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 20.0),
      ),
      at: 0.5,
    )
  let assert Ok(quadratic_derivative) =
    svg_path.segment_derivative(
      svg_path.QuadraticBezier(
        start: svg_path.point(0.0, 0.0),
        control: svg_path.point(10.0, 20.0),
        end: svg_path.point(20.0, 0.0),
      ),
      at: 0.5,
    )
  let assert Ok(cubic_derivative) =
    svg_path.segment_derivative(
      svg_path.CubicBezier(
        start: svg_path.point(0.0, 0.0),
        control1: svg_path.point(0.0, 30.0),
        control2: svg_path.point(30.0, 30.0),
        end: svg_path.point(30.0, 0.0),
      ),
      at: 0.5,
    )
  let assert Ok(arc_derivative) =
    svg_path.segment_derivative(
      svg_path.Arc(
        start: svg_path.point(0.0, 0.0),
        radius: svg_path.point(10.0, 10.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.point(20.0, 0.0),
      ),
      at: 0.5,
    )

  assert point_near(line_derivative, svg_path.point(10.0, 20.0))
  assert point_near(quadratic_derivative, svg_path.point(20.0, 0.0))
  assert point_near(cubic_derivative, svg_path.point(45.0, 0.0))
  assert arc_derivative.x >. 0.0
  assert near(arc_derivative.y, 0.0)
}

pub fn segment_bounding_box_handles_lines_beziers_and_arcs_test() {
  let assert Ok(line_box) =
    svg_path.segment_bounding_box(svg_path.Line(
      start: svg_path.point(1.0, 2.0),
      end: svg_path.point(5.0, -3.0),
    ))
  let assert Ok(quadratic_box) =
    svg_path.segment_bounding_box(svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(10.0, 10.0),
      end: svg_path.point(20.0, 0.0),
    ))
  let assert Ok(cubic_box) =
    svg_path.segment_bounding_box(svg_path.CubicBezier(
      start: svg_path.point(0.0, 0.0),
      control1: svg_path.point(0.0, 30.0),
      control2: svg_path.point(30.0, 30.0),
      end: svg_path.point(30.0, 0.0),
    ))
  let assert Ok(arc_box) =
    svg_path.segment_bounding_box(svg_path.Arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(20.0, 0.0),
    ))

  assert bbox_near(
    line_box,
    min: svg_path.point(1.0, -3.0),
    max: svg_path.point(5.0, 2.0),
  )
  assert bbox_near(
    quadratic_box,
    min: svg_path.point(0.0, 0.0),
    max: svg_path.point(20.0, 5.0),
  )
  assert bbox_near(
    cubic_box,
    min: svg_path.point(0.0, 0.0),
    max: svg_path.point(30.0, 22.5),
  )
  assert bbox_near(
    arc_box,
    min: svg_path.point(0.0, -10.0),
    max: svg_path.point(20.0, 0.0),
  )
}

pub fn bounding_box_dimensions_use_extents_test() {
  let box =
    svg_path.BoundingBox(
      min: svg_path.point(-2.0, 3.0),
      max: svg_path.point(8.0, 15.0),
    )

  assert svg_path.bounding_box_width(box) == 10.0
  assert svg_path.bounding_box_height(box) == 12.0
  assert svg_path.bounding_box_center(box) == svg_path.point(3.0, 9.0)
  assert svg_path.bounding_box_diameter(box) == 22.0
}

pub fn segment_bounding_box_returns_degenerate_arc_errors_test() {
  let segment =
    svg_path.Arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(0.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(20.0, 0.0),
    )

  assert svg_path.segment_bounding_box(segment) == Error(svg_path.DegenerateArc)
}

pub fn segment_crossings_finds_line_crossing_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  let assert Ok(crossings) =
    svg_path.segment_crossings(line, where: fn(point) { point.x -. 5.0 })
  let assert [crossing] = crossings

  assert near(crossing, 0.5)
}

pub fn segment_crossings_finds_multiple_quadratic_crossings_test() {
  let curve =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(10.0, 20.0),
      end: svg_path.point(20.0, 0.0),
    )
  let options =
    svg_path.CrossingOptions(
      samples: 20,
      tolerance: 0.000000001,
      max_iterations: 100,
    )

  let assert Ok(crossings) =
    svg_path.segment_crossings_with(
      curve,
      where: fn(point) { point.y -. 5.0 },
      options:,
    )
  let assert [first, second] = crossings

  assert near(first, 0.146446609)
  assert near(second, 0.853553391)
}

pub fn segment_crossings_finds_arc_crossing_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(20.0, 0.0),
    )

  let assert Ok(crossings) =
    svg_path.segment_crossings(arc, where: fn(point) { point.x -. 10.0 })
  let assert [crossing] = crossings

  assert near(crossing, 0.5)
}

pub fn segment_crossings_rejects_invalid_options_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  assert svg_path.segment_crossings_with(
      line,
      where: fn(point) { point.x -. 5.0 },
      options: svg_path.CrossingOptions(
        samples: 0,
        tolerance: 0.000000001,
        max_iterations: 100,
      ),
    )
    == Error(svg_path.InvalidCrossingSamples(0))
  assert svg_path.segment_crossings_with(
      line,
      where: fn(point) { point.x -. 5.0 },
      options: svg_path.CrossingOptions(
        samples: 10,
        tolerance: 0.0,
        max_iterations: 100,
      ),
    )
    == Error(svg_path.InvalidCrossingTolerance(0.0))
  assert svg_path.segment_crossings_with(
      line,
      where: fn(point) { point.x -. 5.0 },
      options: svg_path.CrossingOptions(
        samples: 10,
        tolerance: 0.000000001,
        max_iterations: 0,
      ),
    )
    == Error(svg_path.InvalidCrossingMaxIterations(0))
}

pub fn segment_crossings_returns_degenerate_arc_errors_test() {
  let segment =
    svg_path.Arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(0.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(20.0, 0.0),
    )

  assert svg_path.segment_crossings(segment, where: fn(point) { point.x })
    == Error(svg_path.DegenerateArc)
}

pub fn segment_minimize_finds_line_minimum_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  let assert Ok(t) =
    svg_path.segment_minimize(line, measure: fn(point) {
      let dx = point.x -. 7.0
      dx *. dx
    })

  assert near(t, 0.7)
}

pub fn segment_minimize_finds_quadratic_minimum_test() {
  let curve =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(10.0, 20.0),
      end: svg_path.point(20.0, 0.0),
    )

  let assert Ok(t) =
    svg_path.segment_minimize(curve, measure: fn(point) {
      let dx = point.x -. 10.0
      let dy = point.y -. 10.0
      dx *. dx +. dy *. dy
    })

  assert near(t, 0.5)
}

pub fn segment_minimize_finds_arc_minimum_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(20.0, 0.0),
    )

  let assert Ok(t) =
    svg_path.segment_minimize(arc, measure: fn(point) {
      let dx = point.x -. 10.0
      dx *. dx
    })

  assert near(t, 0.5)
}

pub fn segment_minimize_with_rejects_invalid_options_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  assert svg_path.segment_minimize_with(
      line,
      measure: fn(point) { point.x },
      options: svg_path.MinimizeOptions(
        samples: 0,
        tolerance: 0.000000001,
        max_iterations: 100,
      ),
    )
    == Error(svg_path.InvalidMinimizeSamples(0))
  assert svg_path.segment_minimize_with(
      line,
      measure: fn(point) { point.x },
      options: svg_path.MinimizeOptions(
        samples: 10,
        tolerance: 0.0,
        max_iterations: 100,
      ),
    )
    == Error(svg_path.InvalidMinimizeTolerance(0.0))
  assert svg_path.segment_minimize_with(
      line,
      measure: fn(point) { point.x },
      options: svg_path.MinimizeOptions(
        samples: 10,
        tolerance: 0.000000001,
        max_iterations: 0,
      ),
    )
    == Error(svg_path.InvalidMinimizeMaxIterations(0))
}

pub fn segment_minimize_returns_degenerate_arc_errors_test() {
  let segment =
    svg_path.Arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(0.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(20.0, 0.0),
    )

  assert svg_path.segment_minimize(segment, measure: fn(point) { point.x })
    == Error(svg_path.DegenerateArc)
}

pub fn segment_distance_measures_line_projection_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  let assert Ok(distance) =
    svg_path.segment_distance(svg_path.point(5.0, 4.0), to: line)

  assert near(distance, 4.0)
}

pub fn segment_distance_measures_line_endpoint_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  let assert Ok(distance) =
    svg_path.segment_distance(svg_path.point(13.0, 4.0), to: line)

  assert near(distance, 5.0)
}

pub fn segment_distance_measures_quadratic_curve_test() {
  let curve =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(10.0, 20.0),
      end: svg_path.point(20.0, 0.0),
    )

  let assert Ok(distance) =
    svg_path.segment_distance(svg_path.point(10.0, 15.0), to: curve)

  assert near(distance, 5.0)
}

pub fn segment_distance_measures_cubic_curve_test() {
  let curve =
    svg_path.CubicBezier(
      start: svg_path.point(0.0, 0.0),
      control1: svg_path.point(0.0, 10.0),
      control2: svg_path.point(10.0, 10.0),
      end: svg_path.point(10.0, 0.0),
    )

  let assert Ok(distance) =
    svg_path.segment_distance(svg_path.point(5.0, 7.5), to: curve)

  assert distance <. 0.0001
}

pub fn segment_distance_measures_arc_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(20.0, 0.0),
    )

  let assert Ok(distance) =
    svg_path.segment_distance(svg_path.point(10.0, -15.0), to: arc)

  assert near(distance, 5.0)
}

pub fn segment_distance_with_rejects_invalid_options_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  assert svg_path.segment_distance_with(
      svg_path.point(5.0, 4.0),
      to: line,
      options: svg_path.DistanceOptions(
        samples: 0,
        tolerance: 0.000000001,
        max_iterations: 100,
      ),
    )
    == Error(svg_path.InvalidDistanceSamples(0))
  assert svg_path.segment_distance_with(
      svg_path.point(5.0, 4.0),
      to: line,
      options: svg_path.DistanceOptions(
        samples: 10,
        tolerance: 0.0,
        max_iterations: 100,
      ),
    )
    == Error(svg_path.InvalidDistanceTolerance(0.0))
  assert svg_path.segment_distance_with(
      svg_path.point(5.0, 4.0),
      to: line,
      options: svg_path.DistanceOptions(
        samples: 10,
        tolerance: 0.000000001,
        max_iterations: 0,
      ),
    )
    == Error(svg_path.InvalidDistanceMaxIterations(0))
}

pub fn segment_distance_returns_degenerate_arc_errors_test() {
  let segment =
    svg_path.Arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(0.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(20.0, 0.0),
    )

  assert svg_path.segment_distance(svg_path.point(10.0, 0.0), to: segment)
    == Error(svg_path.DegenerateArc)
}

pub fn segment_intersections_finds_line_crossing_test() {
  let left =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 10.0),
    )
  let right =
    svg_path.Line(
      start: svg_path.point(0.0, 10.0),
      end: svg_path.point(10.0, 0.0),
    )

  let assert Ok(intersections) = svg_path.segment_intersections(left, right)
  let assert [intersection] = intersections

  assert float.absolute_value(intersection.left_t -. 0.5) <. 0.00001
  assert float.absolute_value(intersection.right_t -. 0.5) <. 0.00001
  assert near(intersection.point.x, 5.0)
  assert near(intersection.point.y, 5.0)
}

pub fn segment_intersections_finds_endpoint_touch_test() {
  let left =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )
  let right =
    svg_path.Line(
      start: svg_path.point(10.0, 0.0),
      end: svg_path.point(10.0, 10.0),
    )

  let assert Ok(intersections) = svg_path.segment_intersections(left, right)
  let assert [intersection] = intersections

  assert near(intersection.left_t, 1.0)
  assert near(intersection.right_t, 0.0)
  assert near(intersection.point.x, 10.0)
  assert near(intersection.point.y, 0.0)
}

pub fn segment_intersections_returns_empty_for_disjoint_lines_test() {
  let left =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )
  let right =
    svg_path.Line(
      start: svg_path.point(0.0, 5.0),
      end: svg_path.point(10.0, 5.0),
    )

  assert svg_path.segment_intersections(left, right) == Ok([])
}

pub fn segment_intersections_rejects_overlapping_lines_test() {
  let left =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )
  let right =
    svg_path.Line(
      start: svg_path.point(5.0, 0.0),
      end: svg_path.point(15.0, 0.0),
    )

  assert svg_path.segment_intersections(left, right)
    == Error(svg_path.OverlappingSegments)
}

pub fn segment_intersections_finds_line_curve_crossings_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 5.0),
      end: svg_path.point(20.0, 5.0),
    )
  let curve =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(10.0, 20.0),
      end: svg_path.point(20.0, 0.0),
    )

  let assert Ok(intersections) = svg_path.segment_intersections(line, curve)
  let assert [first, second] = intersections

  assert near(first.left_t, 0.146446609)
  assert near(first.right_t, 0.146446609)
  assert near(first.point.y, 5.0)
  assert near(second.left_t, 0.853553391)
  assert near(second.right_t, 0.853553391)
  assert near(second.point.y, 5.0)
}

pub fn segment_intersections_finds_curve_curve_crossing_test() {
  let left =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(10.0, 20.0),
      end: svg_path.point(20.0, 0.0),
    )
  let right =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 20.0),
      control: svg_path.point(10.0, 0.0),
      end: svg_path.point(20.0, 20.0),
    )

  let assert Ok(intersections) = svg_path.segment_intersections(left, right)
  let assert [intersection] = intersections

  assert float.absolute_value(intersection.left_t -. 0.5) <. 0.00001
  assert float.absolute_value(intersection.right_t -. 0.5) <. 0.00001
  assert float.absolute_value(intersection.point.x -. 10.0) <. 0.0001
  assert float.absolute_value(intersection.point.y -. 10.0) <. 0.0001
}

pub fn segment_intersections_with_rejects_invalid_options_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  assert svg_path.segment_intersections_with(
      line,
      line,
      options: svg_path.IntersectionOptions(tolerance: 0.0, max_depth: 32),
    )
    == Error(svg_path.InvalidIntersectionTolerance(0.0))
  assert svg_path.segment_intersections_with(
      line,
      line,
      options: svg_path.IntersectionOptions(
        tolerance: 0.000000001,
        max_depth: 0,
      ),
    )
    == Error(svg_path.InvalidIntersectionMaxDepth(0))
}

pub fn segment_intersections_match_returned_parameters_test() {
  let line_a =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(20.0, 20.0),
    )
  let line_b =
    svg_path.Line(
      start: svg_path.point(0.0, 20.0),
      end: svg_path.point(20.0, 0.0),
    )
  let quadratic_a =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(10.0, 20.0),
      end: svg_path.point(20.0, 0.0),
    )
  let quadratic_b =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 20.0),
      control: svg_path.point(10.0, 0.0),
      end: svg_path.point(20.0, 20.0),
    )
  let cubic =
    svg_path.CubicBezier(
      start: svg_path.point(0.0, 0.0),
      control1: svg_path.point(0.0, 20.0),
      control2: svg_path.point(20.0, 20.0),
      end: svg_path.point(20.0, 0.0),
    )
  let horizontal =
    svg_path.Line(
      start: svg_path.point(0.0, 10.0),
      end: svg_path.point(20.0, 10.0),
    )
  let arc =
    svg_path.Arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(20.0, 0.0),
    )

  assert segment_intersections_are_consistent(line_a, line_b)
  assert segment_intersections_are_consistent(horizontal, quadratic_a)
  assert segment_intersections_are_consistent(horizontal, cubic)
  assert segment_intersections_are_consistent(quadratic_a, quadratic_b)
  assert segment_intersections_are_consistent(
    svg_path.Line(
      start: svg_path.point(10.0, -20.0),
      end: svg_path.point(10.0, 5.0),
    ),
    arc,
  )
}

pub fn map_segment_points_maps_line_quadratic_and_cubic_defining_points_test() {
  let map = fn(point: svg_path.Point) {
    svg_path.point(point.x +. 1.0, point.y *. 2.0)
  }
  let assert Ok(line) =
    svg_path.map_segment_points(
      svg_path.Line(
        start: svg_path.point(0.0, 1.0),
        end: svg_path.point(2.0, 3.0),
      ),
      with: map,
    )
  let assert Ok(quadratic) =
    svg_path.map_segment_points(
      svg_path.QuadraticBezier(
        start: svg_path.point(0.0, 1.0),
        control: svg_path.point(2.0, 3.0),
        end: svg_path.point(4.0, 5.0),
      ),
      with: map,
    )
  let assert Ok(cubic) =
    svg_path.map_segment_points(
      svg_path.CubicBezier(
        start: svg_path.point(0.0, 1.0),
        control1: svg_path.point(2.0, 3.0),
        control2: svg_path.point(4.0, 5.0),
        end: svg_path.point(6.0, 7.0),
      ),
      with: map,
    )

  assert line
    == svg_path.Line(
      start: svg_path.point(1.0, 2.0),
      end: svg_path.point(3.0, 6.0),
    )
  assert quadratic
    == svg_path.QuadraticBezier(
      start: svg_path.point(1.0, 2.0),
      control: svg_path.point(3.0, 6.0),
      end: svg_path.point(5.0, 10.0),
    )
  assert cubic
    == svg_path.CubicBezier(
      start: svg_path.point(1.0, 2.0),
      control1: svg_path.point(3.0, 6.0),
      control2: svg_path.point(5.0, 10.0),
      end: svg_path.point(7.0, 14.0),
    )
}

pub fn map_segment_points_rejects_arcs_test() {
  let segment =
    svg_path.Arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(20.0, 0.0),
    )

  assert svg_path.map_segment_points(segment, with: fn(point) { point })
    == Error(svg_path.CannotMapArcNonlinearly)
}

pub fn map_subpath_points_maps_segments_and_preserves_closed_state_test() {
  let map = fn(point: svg_path.Point) {
    svg_path.point(point.x +. 1.0, point.y *. 2.0)
  }
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 0.0),
      ),
      svg_path.QuadraticBezier(
        start: svg_path.point(10.0, 0.0),
        control: svg_path.point(15.0, 5.0),
        end: svg_path.point(0.0, 0.0),
      ),
    ])
    |> svg_path.assert_set_closed(closed: True)

  let assert Ok(mapped) = svg_path.map_subpath_points(subpath, with: map)

  assert svg_path.is_closed(mapped)
  assert svg_path.segments(mapped)
    == [
      svg_path.Line(
        start: svg_path.point(1.0, 0.0),
        end: svg_path.point(11.0, 0.0),
      ),
      svg_path.QuadraticBezier(
        start: svg_path.point(11.0, 0.0),
        control: svg_path.point(16.0, 10.0),
        end: svg_path.point(1.0, 0.0),
      ),
    ]
}

pub fn map_subpath_points_maps_empty_subpath_test() {
  let assert Ok(mapped) =
    svg_path.map_subpath_points(
      svg_path.empty_subpath(at: svg_path.point(0.0, 0.0)),
      with: fn(point) { svg_path.point(point.x +. 1.0, point.y +. 1.0) },
    )

  assert svg_path.segments(mapped) == []
  assert !svg_path.is_closed(mapped)
}

pub fn map_subpath_points_rejects_arcs_test() {
  let subpath =
    svg_path.assert_subpath([
      svg_path.Arc(
        start: svg_path.point(0.0, 0.0),
        radius: svg_path.point(10.0, 10.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.point(20.0, 0.0),
      ),
    ])

  assert svg_path.map_subpath_points(subpath, with: fn(point) { point })
    == Error(svg_path.CannotMapArcNonlinearly)
}

pub fn map_path_points_maps_each_subpath_test() {
  let map = fn(point: svg_path.Point) {
    svg_path.point(point.x +. 1.0, point.y +. 1.0)
  }
  let first =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 0.0),
      ),
    ])
  let second =
    svg_path.assert_subpath([
      svg_path.CubicBezier(
        start: svg_path.point(10.0, 0.0),
        control1: svg_path.point(15.0, 5.0),
        control2: svg_path.point(20.0, 5.0),
        end: svg_path.point(25.0, 0.0),
      ),
    ])
  let path = svg_path.Path([first, second])

  let assert Ok(mapped) = svg_path.map_path_points(path, with: map)
  let assert [mapped_first, mapped_second] = svg_path.subpaths(mapped)

  assert svg_path.segments(mapped_first)
    == [
      svg_path.Line(
        start: svg_path.point(1.0, 1.0),
        end: svg_path.point(11.0, 1.0),
      ),
    ]
  assert svg_path.segments(mapped_second)
    == [
      svg_path.CubicBezier(
        start: svg_path.point(11.0, 1.0),
        control1: svg_path.point(16.0, 6.0),
        control2: svg_path.point(21.0, 6.0),
        end: svg_path.point(26.0, 1.0),
      ),
    ]
}

pub fn map_path_points_rejects_arcs_test() {
  let subpath =
    svg_path.assert_subpath([
      svg_path.Arc(
        start: svg_path.point(0.0, 0.0),
        radius: svg_path.point(10.0, 10.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.point(20.0, 0.0),
      ),
    ])
  let path =
    svg_path.Path([
      svg_path.empty_subpath(at: svg_path.point(0.0, 0.0)),
      subpath,
    ])

  assert svg_path.map_path_points(path, with: fn(point) { point })
    == Error(svg_path.CannotMapArcNonlinearly)
}

pub fn reverse_subpath_reverses_segment_order_and_preserves_closed_state_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let first = svg_path.Line(start: a, end: b)
  let second = svg_path.Line(start: b, end: c)
  let third = svg_path.Line(start: c, end: a)
  let subpath =
    svg_path.assert_subpath([first, second, third])
    |> svg_path.assert_set_closed(closed: True)

  let reversed = svg_path.reverse_subpath(subpath)

  assert svg_path.is_closed(reversed)
  assert svg_path.segments(reversed)
    == [
      svg_path.reverse_segment(third),
      svg_path.reverse_segment(second),
      svg_path.reverse_segment(first),
    ]
}

pub fn reverse_subpath_preserves_empty_open_subpath_test() {
  assert svg_path.reverse_subpath(
      svg_path.empty_subpath(at: svg_path.point(0.0, 0.0)),
    )
    == svg_path.empty_subpath(at: svg_path.point(0.0, 0.0))
}

pub fn reverse_path_reverses_subpaths_and_their_segments_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let first =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])
  let second =
    svg_path.assert_subpath([
      svg_path.Line(start: c, end: d),
    ])
  let path = svg_path.Path([first, second])

  let reversed = svg_path.reverse_path(path)
  let assert [reversed_second, reversed_first] = svg_path.subpaths(reversed)

  assert svg_path.segments(reversed_second)
    == svg_path.segments(svg_path.reverse_subpath(second))
  assert svg_path.segments(reversed_first)
    == svg_path.segments(svg_path.reverse_subpath(first))
}

pub fn segment_point_and_split_extrapolate_outside_t_test() {
  let segment =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 20.0),
    )
  let assert Ok(point) = svg_path.segment_point(segment, at: -0.5)
  let assert Ok(#(before, through_end)) =
    svg_path.split_segment(segment, at: -0.5)

  assert point_near(point, svg_path.point(-5.0, -10.0))
  assert point_near(svg_path.segment_start(before), svg_path.point(0.0, 0.0))
  assert point_near(svg_path.segment_end(before), svg_path.point(-5.0, -10.0))
  assert point_near(
    svg_path.segment_start(through_end),
    svg_path.point(-5.0, -10.0),
  )
  assert point_near(
    svg_path.segment_end(through_end),
    svg_path.point(10.0, 20.0),
  )
}

pub fn split_segment_divides_quadratic_test() {
  let segment =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(10.0, 20.0),
      end: svg_path.point(20.0, 0.0),
    )
  let assert Ok(#(left, right)) = svg_path.split_segment(segment, at: 0.25)
  let assert svg_path.QuadraticBezier(
    start: left_start,
    control: left_control,
    end: split,
  ) = left
  let assert svg_path.QuadraticBezier(
    start: right_start,
    control: right_control,
    end: right_end,
  ) = right

  assert point_near(left_start, svg_path.point(0.0, 0.0))
  assert point_near(left_control, svg_path.point(2.5, 5.0))
  assert point_near(split, svg_path.point(5.0, 7.5))
  assert point_near(right_start, split)
  assert point_near(right_control, svg_path.point(12.5, 15.0))
  assert point_near(right_end, svg_path.point(20.0, 0.0))
}

pub fn split_segment_divides_arc_test() {
  let segment =
    svg_path.Arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(20.0, 0.0),
    )
  let assert Ok(#(left, right)) = svg_path.split_segment(segment, at: 0.5)

  assert point_near(svg_path.segment_start(left), svg_path.point(0.0, 0.0))
  assert point_near(svg_path.segment_end(left), svg_path.point(10.0, -10.0))
  assert point_near(svg_path.segment_start(right), svg_path.point(10.0, -10.0))
  assert point_near(svg_path.segment_end(right), svg_path.point(20.0, 0.0))
}

pub fn split_segment_inside_rejects_outside_t_test() {
  let segment =
    svg_path.CubicBezier(
      start: svg_path.point(0.0, 0.0),
      control1: svg_path.point(0.0, 30.0),
      control2: svg_path.point(30.0, 30.0),
      end: svg_path.point(30.0, 0.0),
    )

  assert svg_path.split_segment_inside(segment, at: -0.01)
    == Error(svg_path.SplitOutsideSegment)
  assert svg_path.split_segment_inside(segment, at: 1.01)
    == Error(svg_path.SplitOutsideSegment)
  let assert Ok(_) = svg_path.split_segment_inside(segment, at: 0.0)
  let assert Ok(_) = svg_path.split_segment_inside(segment, at: 1.0)
}

pub fn sub_segment_returns_segment_between_parameters_test() {
  let segment =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 20.0),
    )
  let assert Ok(sub_segment) =
    svg_path.sub_segment(segment, from: 0.25, to: 0.75)

  assert point_near(
    svg_path.segment_start(sub_segment),
    svg_path.point(2.5, 5.0),
  )
  assert point_near(
    svg_path.segment_end(sub_segment),
    svg_path.point(7.5, 15.0),
  )
}

pub fn sub_segment_uses_exact_segment_point_endpoints_test() {
  let segment =
    svg_path.CubicBezier(
      start: svg_path.point(25.0, 40.0),
      control1: svg_path.point(155.0, 100.0),
      control2: svg_path.point(155.0, 10.0),
      end: svg_path.point(25.0, 70.0),
    )
  let assert Ok(sub_segment) =
    svg_path.sub_segment(segment, from: 0.123, to: 0.876)
  let assert Ok(start) = svg_path.segment_point(segment, at: 0.123)
  let assert Ok(end) = svg_path.segment_point(segment, at: 0.876)

  assert svg_path.segment_start(sub_segment) == start
  assert svg_path.segment_end(sub_segment) == end
}

pub fn sub_segment_reverses_when_from_is_after_to_test() {
  let segment =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 20.0),
    )
  let assert Ok(sub_segment) =
    svg_path.sub_segment(segment, from: 0.75, to: 0.25)

  assert point_near(
    svg_path.segment_start(sub_segment),
    svg_path.point(7.5, 15.0),
  )
  assert point_near(svg_path.segment_end(sub_segment), svg_path.point(2.5, 5.0))
}

pub fn sub_segment_returns_degenerate_line_when_parameters_are_equal_test() {
  let segment =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(10.0, 20.0),
      end: svg_path.point(20.0, 0.0),
    )
  let assert Ok(sub_segment) =
    svg_path.sub_segment(segment, from: 0.25, to: 0.25)

  assert point_near(
    svg_path.segment_start(sub_segment),
    svg_path.point(5.0, 7.5),
  )
  assert point_near(svg_path.segment_end(sub_segment), svg_path.point(5.0, 7.5))
}

pub fn sub_segment_inside_rejects_outside_t_test() {
  let segment =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 20.0),
    )

  assert svg_path.sub_segment_inside(segment, from: -0.01, to: 0.5)
    == Error(svg_path.SplitOutsideSegment)
  assert svg_path.sub_segment_inside(segment, from: 0.5, to: 1.01)
    == Error(svg_path.SplitOutsideSegment)
  let assert Ok(_) = svg_path.sub_segment_inside(segment, from: 0.0, to: 1.0)
  let assert Ok(_) = svg_path.sub_segment_inside(segment, from: 1.0, to: 0.0)
}

pub fn sub_segment_extrapolates_outside_t_test() {
  let segment =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 20.0),
    )
  let assert Ok(sub_segment) = svg_path.sub_segment(segment, from: 1.0, to: 1.5)

  assert point_near(
    svg_path.segment_start(sub_segment),
    svg_path.point(10.0, 20.0),
  )
  assert point_near(
    svg_path.segment_end(sub_segment),
    svg_path.point(15.0, 30.0),
  )
}

pub fn sub_segments_returns_segments_between_adjacent_parameters_test() {
  let segment =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 20.0),
    )
  let assert Ok([first, second]) =
    svg_path.sub_segments(segment, between: [0.25, 0.75, 0.5])

  assert point_near(svg_path.segment_start(first), svg_path.point(2.5, 5.0))
  assert point_near(svg_path.segment_end(first), svg_path.point(7.5, 15.0))
  assert point_near(svg_path.segment_start(second), svg_path.point(7.5, 15.0))
  assert point_near(svg_path.segment_end(second), svg_path.point(5.0, 10.0))
}

pub fn sub_segments_does_not_add_boundary_parameters_test() {
  let segment =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 20.0),
    )
  let assert Ok([sub_segment]) =
    svg_path.sub_segments(segment, between: [0.25, 0.75])

  assert point_near(
    svg_path.segment_start(sub_segment),
    svg_path.point(2.5, 5.0),
  )
  assert point_near(
    svg_path.segment_end(sub_segment),
    svg_path.point(7.5, 15.0),
  )
}

pub fn sub_segments_returns_empty_for_too_few_parameters_test() {
  let segment =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 20.0),
    )

  assert svg_path.sub_segments(segment, between: []) == Ok([])
  assert svg_path.sub_segments(segment, between: [0.5]) == Ok([])
}

pub fn sub_segments_inside_rejects_any_outside_t_test() {
  let segment =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 20.0),
    )

  assert svg_path.sub_segments_inside(segment, between: [0.0, 0.5, 1.01])
    == Error(svg_path.SplitOutsideSegment)
  let assert Ok([_]) =
    svg_path.sub_segments_inside(segment, between: [0.0, 1.0])
}

pub fn segment_eval_and_split_return_degenerate_arc_error_test() {
  let segment =
    svg_path.Arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(0.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(20.0, 0.0),
    )

  assert svg_path.segment_point(segment, at: 0.5)
    == Error(svg_path.DegenerateArc)
  assert svg_path.segment_derivative(segment, at: 0.5)
    == Error(svg_path.DegenerateArc)
  assert svg_path.split_segment(segment, at: 0.5)
    == Error(svg_path.DegenerateArc)
}

pub fn path_can_be_built_from_empty_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let assert Ok(subpath) =
    svg_path.empty_subpath(at: svg_path.point(0.0, 0.0))
    |> svg_path.append_segment(svg_path.Line(start: a, end: b))
  let path =
    svg_path.empty_path()
    |> svg_path.append_subpath(subpath)

  assert path |> svg_path.subpaths |> list.length == 1
  assert svg_path.from_subpath(subpath) |> svg_path.subpaths == [subpath]
}

pub fn combine_paths_concatenates_subpaths_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let first =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
    ])
  let second =
    svg_path.assert_subpath([
      svg_path.Line(start: c, end: d),
    ])

  let combined =
    svg_path.combine_paths([
      svg_path.Path([first]),
      svg_path.empty_path(),
      svg_path.Path([
        svg_path.empty_subpath(at: svg_path.point(0.0, 0.0)),
        second,
      ]),
    ])

  assert svg_path.subpaths(combined)
    == [first, svg_path.empty_subpath(at: svg_path.point(0.0, 0.0)), second]
}

pub fn clean_combine_paths_cleans_the_concatenated_path_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let first = svg_path.Line(start: a, end: b)
  let zero = svg_path.Line(start: b, end: b)
  let second = svg_path.Line(start: b, end: c)
  let subpath = svg_path.assert_subpath([first, zero, second])

  let combined =
    svg_path.clean_combine_paths([
      svg_path.Path([
        svg_path.empty_subpath(at: svg_path.point(0.0, 0.0)),
        subpath,
      ]),
      svg_path.Path([svg_path.empty_subpath(at: svg_path.point(0.0, 0.0))]),
    ])

  let assert [cleaned] = svg_path.subpaths(combined)
  assert svg_path.segments(cleaned) == [first, second]
}

pub fn path_start_and_end_use_first_and_last_subpaths_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let first = svg_path.assert_subpath([svg_path.Line(start: a, end: b)])
  let second = svg_path.assert_subpath([svg_path.Line(start: c, end: d)])
  let path =
    svg_path.Path([
      svg_path.empty_subpath(at: a),
      first,
      svg_path.empty_subpath(at: svg_path.point(0.0, 0.0)),
      second,
      svg_path.empty_subpath(at: d),
    ])

  assert svg_path.path_start(path) == Ok(a)
  assert svg_path.path_end(path) == Ok(d)
}

pub fn subpath_bounding_box_combines_segment_boxes_test() {
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(1.0, 2.0),
        end: svg_path.point(5.0, -3.0),
      ),
      svg_path.QuadraticBezier(
        start: svg_path.point(5.0, -3.0),
        control: svg_path.point(10.0, 10.0),
        end: svg_path.point(20.0, 0.0),
      ),
    ])

  let assert Ok(box) = svg_path.subpath_bounding_box(subpath)

  assert bbox_near(
    box,
    min: svg_path.point(1.0, -3.0),
    max: svg_path.point(20.0, 4.347826086956522),
  )
}

pub fn path_bounding_box_uses_nonempty_subpaths_test() {
  let first =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(1.0, 2.0),
        end: svg_path.point(5.0, -3.0),
      ),
    ])
  let second =
    svg_path.assert_subpath([
      svg_path.Arc(
        start: svg_path.point(0.0, 0.0),
        radius: svg_path.point(10.0, 10.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.point(20.0, 0.0),
      ),
    ])
  let path =
    svg_path.Path([
      svg_path.empty_subpath(at: svg_path.point(0.0, 0.0)),
      first,
      svg_path.empty_subpath(at: svg_path.point(0.0, 0.0)),
      second,
    ])

  let assert Ok(box) = svg_path.path_bounding_box(path)

  assert bbox_near(
    box,
    min: svg_path.point(0.0, -10.0),
    max: svg_path.point(20.0, 2.0),
  )
}

pub fn empty_path_has_no_start_or_end_test() {
  assert svg_path.path_start(svg_path.empty_path()) == Error(svg_path.EmptyPath)
  assert svg_path.path_end(svg_path.empty_path()) == Error(svg_path.EmptyPath)
  assert svg_path.path_bounding_box(svg_path.empty_path())
    == Error(svg_path.EmptyPath)
}

pub fn path_with_only_empty_subpaths_has_start_and_end_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let path =
    svg_path.Path([
      svg_path.empty_subpath(at: a),
      svg_path.empty_subpath(at: b),
    ])

  assert svg_path.path_start(path) == Ok(a)
  assert svg_path.path_end(path) == Ok(b)
  assert svg_path.path_bounding_box(path) == Error(svg_path.EmptySubpaths)
}

pub fn as_subpath_rejects_empty_path_test() {
  assert svg_path.as_subpath(svg_path.empty_path())
    == Error(svg_path.EmptySubpaths)
}

pub fn as_subpath_ignores_empty_subpaths_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let line = svg_path.Line(start: a, end: b)
  let assert Ok(subpath) = svg_path.subpath([line])
  let path =
    svg_path.Path([
      svg_path.empty_subpath(at: svg_path.point(0.0, 0.0)),
      subpath,
      svg_path.empty_subpath(at: svg_path.point(0.0, 0.0)),
    ])
  let assert Ok(only_subpath) = svg_path.as_subpath(path)

  assert svg_path.segments(only_subpath) == [line]
}

pub fn as_subpath_rejects_multiple_nonempty_subpaths_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let assert Ok(first) = svg_path.subpath([svg_path.Line(start: a, end: b)])
  let assert Ok(second) = svg_path.subpath([svg_path.Line(start: c, end: d)])

  assert svg_path.as_subpath(svg_path.Path([first, second]))
    == Error(svg_path.MultipleNonemptySubpaths)
}

pub fn subpath_can_be_built_from_empty_test() {
  let start = svg_path.point(0.0, 0.0)
  let end = svg_path.point(10.0, 0.0)
  let assert Ok(subpath) =
    svg_path.empty_subpath(at: svg_path.point(0.0, 0.0))
    |> svg_path.append_segment(svg_path.Line(start:, end:))

  assert svg_path.start(subpath) == Ok(start)
  assert svg_path.end(subpath) == Ok(end)
}

pub fn empty_subpath_has_start_and_end_test() {
  let start = svg_path.point(0.0, 0.0)

  assert svg_path.start(svg_path.empty_subpath(at: start)) == Ok(start)
  assert svg_path.end(svg_path.empty_subpath(at: start)) == Ok(start)
  assert svg_path.subpath_bounding_box(svg_path.empty_subpath(at: start))
    == Error(svg_path.EmptySubpath)
}

pub fn subpath_rejects_disconnected_segments_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)

  assert svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: c, end: d),
    ])
    == Error(svg_path.Discontinuous(
      previous_index: 0,
      next_index: 1,
      expected: b,
      got: c,
      distance: 10.0,
    ))
}

pub fn subpath_discontinuous_error_reports_later_segment_indices_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let e = svg_path.point(40.0, 0.0)
  let f = svg_path.point(50.0, 0.0)

  assert svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: d, end: e),
      svg_path.Line(start: e, end: f),
    ])
    == Error(svg_path.Discontinuous(
      previous_index: 1,
      next_index: 2,
      expected: c,
      got: d,
      distance: 10.0,
    ))
}

pub fn assert_subpath_builds_continuous_segments_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let segments = [
    svg_path.Line(start: a, end: b),
    svg_path.Line(start: b, end: c),
  ]

  let subpath = svg_path.assert_subpath(segments)

  assert svg_path.segments(subpath) == segments
}

pub fn set_closed_false_clears_closed_state_without_changing_segments_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let segments = [
    svg_path.Line(start: a, end: b),
    svg_path.Line(start: b, end: a),
  ]
  let closed =
    svg_path.assert_subpath(segments)
    |> svg_path.assert_set_closed(closed: True)

  let assert Ok(opened) = svg_path.set_closed(closed, closed: False)

  assert !svg_path.is_closed(opened)
  assert svg_path.segments(opened) == segments
}

pub fn set_closed_false_accepts_open_and_empty_subpaths_test() {
  let empty = svg_path.empty_subpath(at: svg_path.point(0.0, 0.0))
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let open_subpath = svg_path.assert_subpath([svg_path.Line(start: a, end: b)])

  assert svg_path.set_closed(empty, closed: False) == Ok(empty)
  assert svg_path.set_closed(open_subpath, closed: False) == Ok(open_subpath)
}

pub fn set_closed_false_opens_subpath_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let closed =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)

  let assert Ok(opened) = svg_path.set_closed(closed, closed: False)

  assert !svg_path.is_closed(opened)
  assert svg_path.segments(opened) == svg_path.segments(closed)
}

pub fn set_closed_true_closes_matching_subpath_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])

  let assert Ok(closed) = svg_path.set_closed(subpath, closed: True)

  assert svg_path.is_closed(closed)
}

pub fn set_closed_true_rejects_uncloseable_subpath_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0, 10.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert svg_path.set_closed(subpath, closed: True)
    == Error(svg_path.Discontinuous(
      previous_index: 1,
      next_index: 0,
      expected: a,
      got: c,
      distance: 14.142135623730951,
    ))
}

pub fn set_closed_with_wiggle_true_reconciles_nearby_endpoints_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let near_a = svg_path.point(0.0000000001, 0.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: near_a),
    ])

  let assert Ok(closed) =
    svg_path.set_closed_with(subpath, closed: True, policy: svg_path.Wiggle)

  assert svg_path.is_closed(closed)
  assert svg_path.start(closed) == svg_path.end(closed)
}

pub fn set_closed_with_wiggle_false_opens_subpath_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let closed =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)

  let assert Ok(opened) =
    svg_path.set_closed_with(closed, closed: False, policy: svg_path.Wiggle)

  assert !svg_path.is_closed(opened)
}

pub fn append_segment_rejects_closed_subpath_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])
    |> result_try_set_closed_with_bridge

  assert svg_path.append_segment(subpath, svg_path.Line(start: a, end: c))
    == Error(svg_path.AlreadyClosed)
}

pub fn subpath_with_wiggle_replaces_nearby_sequential_endpoints_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let near_b = svg_path.point(10.0000000001, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let assert Ok(subpath) =
    svg_path.subpath_with(
      [
        svg_path.Line(start: a, end: b),
        svg_path.Line(start: near_b, end: c),
      ],
      policy: svg_path.Wiggle,
    )

  let assert [first, second] = svg_path.segments(subpath)
  let overlap = svg_path.segment_end(first)

  assert svg_path.segment_start(first) == a
  assert svg_path.segment_start(second) == overlap
  assert svg_path.segment_end(second) == c
  assert overlap != b
  assert overlap != near_b
}

pub fn subpath_with_wiggle_rejects_empty_and_accepts_single_segment_inputs_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let line = svg_path.Line(start: a, end: b)

  assert svg_path.subpath_with([], policy: svg_path.Wiggle)
    == Error(svg_path.EmptySubpath)
  let assert Ok(subpath) =
    svg_path.subpath_with([line], policy: svg_path.Wiggle)
  assert svg_path.segments(subpath) == [line]
}

pub fn subpath_with_wiggle_then_line_prefers_wiggle_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let near_b = svg_path.point(10.0000000001, 0.0)
  let c = svg_path.point(20.0, 0.0)

  let assert Ok(subpath) =
    svg_path.subpath_with(
      [
        svg_path.Line(start: a, end: b),
        svg_path.Line(start: near_b, end: c),
      ],
      policy: svg_path.WiggleThenBridge,
    )

  assert subpath |> svg_path.segments |> list.length == 2
  assert continuous_segments(svg_path.segments(subpath))
}

pub fn subpath_with_wiggle_then_line_falls_back_to_bridge_line_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)

  let assert Ok(subpath) =
    svg_path.subpath_with(
      [
        svg_path.Line(start: a, end: b),
        svg_path.Line(start: c, end: d),
      ],
      policy: svg_path.WiggleThenBridge,
    )

  assert svg_path.segments(subpath)
    == [
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ]
}

pub fn clean_subpath_removes_zero_length_lines_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let first = svg_path.Line(start: a, end: b)
  let zero = svg_path.Line(start: b, end: b)
  let second = svg_path.Line(start: b, end: c)
  let subpath = svg_path.assert_subpath([first, zero, second])

  assert subpath |> svg_path.clean_subpath |> svg_path.segments
    == [first, second]
}

pub fn clean_subpath_keeps_single_zero_length_line_test() {
  let a = svg_path.point(0.0, 0.0)
  let zero = svg_path.Line(start: a, end: a)
  let subpath = svg_path.assert_subpath([zero])

  assert subpath |> svg_path.clean_subpath |> svg_path.segments == [zero]
}

pub fn clean_subpath_reduces_multiple_zero_length_lines_to_one_test() {
  let a = svg_path.point(0.0, 0.0)
  let zero = svg_path.Line(start: a, end: a)
  let subpath = svg_path.assert_subpath([zero, zero])

  assert subpath |> svg_path.clean_subpath |> svg_path.segments == [zero]
}

pub fn clean_subpath_preserves_closed_state_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
      svg_path.Line(start: a, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)

  let cleaned = svg_path.clean_subpath(subpath)

  assert svg_path.is_closed(cleaned)
  assert svg_path.segments(cleaned)
    == [
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ]
}

pub fn clean_path_removes_empty_subpaths_and_cleans_nonempty_subpaths_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let first = svg_path.Line(start: a, end: b)
  let zero = svg_path.Line(start: b, end: b)
  let second = svg_path.Line(start: b, end: c)
  let third = svg_path.Line(start: c, end: d)
  let first_subpath = svg_path.assert_subpath([first, zero, second])
  let second_subpath = svg_path.assert_subpath([third])
  let path =
    svg_path.Path([
      svg_path.empty_subpath(at: svg_path.point(0.0, 0.0)),
      first_subpath,
      svg_path.empty_subpath(at: svg_path.point(0.0, 0.0)),
      second_subpath,
    ])

  let cleaned = svg_path.clean_path(path)
  let assert [cleaned_first, cleaned_second] = svg_path.subpaths(cleaned)

  assert svg_path.segments(cleaned_first) == [first, second]
  assert svg_path.segments(cleaned_second) == [third]
}

pub fn clean_path_with_only_empty_subpaths_returns_empty_path_test() {
  let path =
    svg_path.Path([
      svg_path.empty_subpath(at: svg_path.point(0.0, 0.0)),
      svg_path.empty_subpath(at: svg_path.point(0.0, 0.0)),
    ])

  assert svg_path.clean_path(path) == svg_path.empty_path()
}

pub fn splice_replaces_segment_range_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let e = svg_path.point(40.0, 0.0)
  let first = svg_path.Line(start: a, end: b)
  let replacement = svg_path.Line(start: b, end: d)
  let last = svg_path.Line(start: d, end: e)
  let subpath =
    svg_path.assert_subpath([
      first,
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
      last,
    ])

  let assert Ok(spliced) =
    svg_path.splice(subpath, start: 1, delete: 2, insert: [replacement])

  assert svg_path.segments(spliced) == [first, replacement, last]
}

pub fn splice_inserts_without_deleting_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let first = svg_path.Line(start: a, end: b)
  let inserted = svg_path.Line(start: b, end: c)
  let subpath = svg_path.assert_subpath([first])

  let assert Ok(spliced) =
    svg_path.splice(subpath, start: 1, delete: 0, insert: [inserted])

  assert svg_path.segments(spliced) == [first, inserted]
}

pub fn splice_deletes_through_end_when_delete_is_too_large_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let first = svg_path.Line(start: a, end: b)
  let subpath =
    svg_path.assert_subpath([
      first,
      svg_path.Line(start: b, end: c),
    ])

  let assert Ok(spliced) =
    svg_path.splice(subpath, start: 1, delete: 99, insert: [])

  assert svg_path.segments(spliced) == [first]
}

pub fn splice_rejects_invalid_bounds_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let subpath = svg_path.assert_subpath([svg_path.Line(start: a, end: b)])

  assert svg_path.splice(subpath, start: -1, delete: 0, insert: [])
    == Error(svg_path.InvalidSplice(start: -1, delete: 0, length: 1))
  assert svg_path.splice(subpath, start: 2, delete: 0, insert: [])
    == Error(svg_path.InvalidSplice(start: 2, delete: 0, length: 1))
  assert svg_path.splice(subpath, start: 0, delete: -1, insert: [])
    == Error(svg_path.InvalidSplice(start: 0, delete: -1, length: 1))
}

pub fn splice_rejects_discontinuous_result_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert svg_path.splice(subpath, start: 1, delete: 1, insert: [
      svg_path.Line(start: d, end: c),
    ])
    == Error(svg_path.Discontinuous(
      previous_index: 0,
      next_index: 1,
      expected: b,
      got: d,
      distance: 20.0,
    ))
}

pub fn splice_with_wiggle_reconciles_tiny_endpoint_gaps_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let near_b = svg_path.point(10.0000000001, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  let assert Error(svg_path.Discontinuous(
    previous_index: 0,
    next_index: 1,
    expected:,
    got:,
    distance:,
  )) =
    svg_path.splice(subpath, start: 1, delete: 1, insert: [
      svg_path.Line(start: near_b, end: c),
    ])
  assert expected == b
  assert got == near_b
  assert distance <. 0.000000001

  let assert Ok(spliced) =
    svg_path.splice_with(
      subpath,
      start: 1,
      delete: 1,
      insert: [
        svg_path.Line(start: near_b, end: c),
      ],
      policy: svg_path.Wiggle,
    )

  assert svg_path.end(spliced) == Ok(c)
  assert continuous_segments(svg_path.segments(spliced))
}

pub fn splice_with_wiggle_preserves_closed_state_with_tiny_endpoint_gap_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let near_a = svg_path.point(0.0000000001, 0.0)
  let closed =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)

  let assert Ok(spliced) =
    svg_path.splice_with(
      closed,
      start: 2,
      delete: 1,
      insert: [
        svg_path.Line(start: c, end: near_a),
      ],
      policy: svg_path.Wiggle,
    )

  assert svg_path.is_closed(spliced)
  assert svg_path.start(spliced) == svg_path.end(spliced)
}

pub fn splice_with_wiggle_reuses_splice_bounds_errors_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let subpath = svg_path.assert_subpath([svg_path.Line(start: a, end: b)])

  assert svg_path.splice_with(
      subpath,
      start: 2,
      delete: 0,
      insert: [],
      policy: svg_path.Wiggle,
    )
    == Error(svg_path.InvalidSplice(start: 2, delete: 0, length: 1))
}

pub fn splice_preserves_closed_state_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let closed =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)
  let replacement = svg_path.Line(start: b, end: c)

  let assert Ok(spliced) =
    svg_path.splice(closed, start: 1, delete: 1, insert: [replacement])

  assert svg_path.is_closed(spliced)
}

pub fn splice_allows_closed_empty_result_test() {
  let a = svg_path.point(0.0, 0.0)
  let closed =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)

  assert svg_path.splice(closed, start: 0, delete: 1, insert: [])
    == Ok(
      svg_path.empty_subpath(at: a) |> svg_path.assert_set_closed(closed: True),
    )
}

pub fn segment_arcs_to_cubic_beziers_preserves_lines_test() {
  let start = svg_path.point(0.0, 0.0)
  let end = svg_path.point(9.0, 0.0)
  let line = svg_path.Line(start:, end:)

  assert svg_path.segment_arcs_to_cubic_beziers(line) == [line]
}

pub fn segment_to_cubic_beziers_converts_line_exactly_test() {
  let start = svg_path.point(0.0, 0.0)
  let end = svg_path.point(9.0, 0.0)

  assert svg_path.segment_to_cubic_beziers(svg_path.Line(start:, end:))
    == [
      svg_path.CubicBezier(
        start:,
        control1: svg_path.point(3.0, 0.0),
        control2: svg_path.point(6.0, 0.0),
        end:,
      ),
    ]
}

pub fn segment_arcs_to_cubic_beziers_preserves_quadratics_test() {
  let start = svg_path.point(0.0, 0.0)
  let control = svg_path.point(3.0, 6.0)
  let end = svg_path.point(9.0, 0.0)
  let quadratic = svg_path.QuadraticBezier(start:, control:, end:)

  assert svg_path.segment_arcs_to_cubic_beziers(quadratic) == [quadratic]
}

pub fn segment_arcs_to_cubic_beziers_preserves_cubics_test() {
  let start = svg_path.point(0.0, 0.0)
  let control1 = svg_path.point(2.0, 4.0)
  let control2 = svg_path.point(5.0, 4.0)
  let end = svg_path.point(9.0, 0.0)
  let cubic = svg_path.CubicBezier(start:, control1:, control2:, end:)

  assert svg_path.segment_arcs_to_cubic_beziers(cubic) == [cubic]
}

pub fn segment_to_cubic_beziers_converts_quadratic_exactly_test() {
  let start = svg_path.point(0.0, 0.0)
  let control = svg_path.point(3.0, 6.0)
  let end = svg_path.point(9.0, 0.0)

  assert svg_path.segment_to_cubic_beziers(svg_path.QuadraticBezier(
      start:,
      control:,
      end:,
    ))
    == [
      svg_path.CubicBezier(
        start:,
        control1: svg_path.point(2.0, 4.0),
        control2: svg_path.point(5.0, 4.0),
        end:,
      ),
    ]
}

pub fn segment_arcs_to_cubic_beziers_splits_half_turn_into_two_cubics_test() {
  let start = svg_path.point(0.0, 0.0)
  let end = svg_path.point(20.0, 0.0)
  let cubics =
    svg_path.segment_arcs_to_cubic_beziers(svg_path.Arc(
      start:,
      radius: svg_path.point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end:,
    ))

  assert list.length(cubics) == 2
  assert svg_path.segment_start(list.first(cubics) |> unwrap_segment) == start
  assert svg_path.segment_end(list.last(cubics) |> unwrap_segment) == end
  assert all_cubic(cubics)
  assert continuous_segments(cubics)
}

pub fn segment_arcs_to_cubic_beziers_large_arc_uses_more_than_two_cubics_test() {
  let start = svg_path.point(0.0, 0.0)
  let end = svg_path.point(10.0, 10.0)
  let cubics =
    svg_path.segment_arcs_to_cubic_beziers(svg_path.Arc(
      start:,
      radius: svg_path.point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: True,
      sweep: True,
      end:,
    ))

  assert list.length(cubics) > 2
  assert all_cubic(cubics)
  assert continuous_segments(cubics)
}

pub fn segment_arcs_to_cubic_beziers_degenerate_arc_falls_back_to_line_cubic_test() {
  let start = svg_path.point(0.0, 0.0)
  let end = svg_path.point(9.0, 0.0)

  assert svg_path.segment_arcs_to_cubic_beziers(svg_path.Arc(
      start:,
      radius: svg_path.point(0.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end:,
    ))
    == [
      svg_path.CubicBezier(
        start:,
        control1: svg_path.point(3.0, 0.0),
        control2: svg_path.point(6.0, 0.0),
        end:,
      ),
    ]
}

pub fn subpath_arcs_to_cubic_beziers_preserves_closed_state_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)

  let converted = svg_path.subpath_arcs_to_cubic_beziers(subpath)

  assert svg_path.is_closed(converted)
  assert svg_path.segments(converted) == svg_path.segments(subpath)
}

pub fn subpath_arcs_to_cubic_beziers_replaces_only_arcs_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let line = svg_path.Line(start: a, end: b)
  let arc =
    svg_path.Arc(
      start: b,
      radius: svg_path.point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: c,
    )
  let quadratic = svg_path.QuadraticBezier(start: c, control: c, end: d)
  let subpath = svg_path.assert_subpath([line, arc, quadratic])

  let converted = svg_path.subpath_arcs_to_cubic_beziers(subpath)

  assert svg_path.segment_start(
      list.first(svg_path.segments(converted)) |> unwrap_segment,
    )
    == a
  assert svg_path.segment_end(
      list.last(svg_path.segments(converted)) |> unwrap_segment,
    )
    == d
  assert no_arcs(svg_path.segments(converted))
  assert contains_line(svg_path.segments(converted), line)
  assert contains_quadratic(svg_path.segments(converted), quadratic)
  assert continuous_segments(svg_path.segments(converted))
}

pub fn subpath_to_cubic_beziers_preserves_closed_state_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)

  let converted = svg_path.subpath_to_cubic_beziers(subpath)

  assert svg_path.is_closed(converted)
  assert all_cubic(svg_path.segments(converted))
}

pub fn path_arcs_to_cubic_beziers_converts_each_subpath_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let first =
    svg_path.assert_subpath([
      svg_path.Arc(
        start: a,
        radius: svg_path.point(5.0, 5.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: b,
      ),
    ])
  let second = svg_path.assert_subpath([svg_path.Line(start: c, end: d)])

  let converted =
    svg_path.path_arcs_to_cubic_beziers(svg_path.Path([first, second]))
  let segments =
    converted
    |> svg_path.subpaths
    |> list.flat_map(svg_path.segments)

  assert no_arcs(segments)
  assert contains_line(segments, svg_path.Line(start: c, end: d))
}

pub fn path_to_cubic_beziers_converts_each_subpath_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let first = svg_path.assert_subpath([svg_path.Line(start: a, end: b)])
  let second = svg_path.assert_subpath([svg_path.Line(start: c, end: d)])

  let converted = svg_path.path_to_cubic_beziers(svg_path.Path([first, second]))
  let segments =
    converted
    |> svg_path.subpaths
    |> list.flat_map(svg_path.segments)

  assert all_cubic(segments)
}

pub fn subpath_with_wiggle_rejects_gaps_beyond_tolerance_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.1, 0.0)
  let d = svg_path.point(20.0, 0.0)

  assert svg_path.subpath_with(
      [
        svg_path.Line(start: a, end: b),
        svg_path.Line(start: c, end: d),
      ],
      policy: svg_path.Wiggle,
    )
    == Error(svg_path.NotCloseEnough(
      expected: b,
      got: c,
      tolerance: 0.000000001,
    ))
}

pub fn subpath_with_wiggle_rejects_misaligned_vertical_lines_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(0.0, 10.0)
  let c = svg_path.point(0.0000000001, 10.0000000001)
  let d = svg_path.point(0.0000000001, 20.0)

  assert svg_path.subpath_with(
      [
        svg_path.Line(start: a, end: b),
        svg_path.Line(start: c, end: d),
      ],
      policy: svg_path.Wiggle,
    )
    == Error(svg_path.IncompatibleVerticalWiggle(previous_end: b, next_start: c))
}

pub fn subpath_with_wiggle_rejects_misaligned_horizontal_lines_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0000000001, 0.0000000001)
  let d = svg_path.point(20.0, 0.0000000001)

  assert svg_path.subpath_with(
      [
        svg_path.Line(start: a, end: b),
        svg_path.Line(start: c, end: d),
      ],
      policy: svg_path.Wiggle,
    )
    == Error(svg_path.IncompatibleHorizontalWiggle(
      previous_end: b,
      next_start: c,
    ))
}

pub fn append_segment_discontinuous_error_reports_segment_indices_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let subpath = svg_path.assert_subpath([svg_path.Line(start: a, end: b)])

  assert svg_path.append_segment(subpath, svg_path.Line(start: c, end: d))
    == Error(svg_path.Discontinuous(
      previous_index: 0,
      next_index: 1,
      expected: b,
      got: c,
      distance: 10.0,
    ))
}

pub fn join_combines_open_subpaths_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let first = svg_path.assert_subpath([svg_path.Line(start: a, end: b)])
  let second = svg_path.assert_subpath([svg_path.Line(start: b, end: c)])
  let third = svg_path.assert_subpath([svg_path.Line(start: c, end: d)])

  let assert Ok(joined) = svg_path.join([first, second, third])

  assert svg_path.segments(joined)
    == [
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ]
}

pub fn join_treats_empty_open_subpaths_as_identity_values_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let subpath = svg_path.assert_subpath([svg_path.Line(start: a, end: b)])
  let empty_start = svg_path.empty_subpath(at: a)
  let empty_end = svg_path.empty_subpath(at: b)

  assert svg_path.join([]) == Error(svg_path.EmptySubpath)
  assert svg_path.join([empty_start, subpath]) == Ok(subpath)
  assert svg_path.join([subpath, empty_end]) == Ok(subpath)
  assert svg_path.join([empty_start, empty_end]) == Ok(empty_start)
}

pub fn join_treats_interleaved_empty_subpaths_as_identity_values_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let first = svg_path.assert_subpath([svg_path.Line(start: a, end: b)])
  let second = svg_path.assert_subpath([svg_path.Line(start: b, end: c)])
  let empty = svg_path.empty_subpath(at: svg_path.point(0.0, 0.0))

  let assert Ok(joined) = svg_path.join([empty, first, empty, second, empty])

  assert svg_path.segments(joined)
    == [
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ]
}

pub fn join_rejects_discontinuous_subpaths_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let first = svg_path.assert_subpath([svg_path.Line(start: a, end: b)])
  let second = svg_path.assert_subpath([svg_path.Line(start: c, end: d)])

  assert svg_path.join([first, second])
    == Error(svg_path.Discontinuous(
      previous_index: 0,
      next_index: 1,
      expected: b,
      got: c,
      distance: 10.0,
    ))
}

pub fn join_discontinuous_error_reports_flattened_segment_indices_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let e = svg_path.point(40.0, 0.0)
  let first =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])
  let second = svg_path.assert_subpath([svg_path.Line(start: d, end: e)])

  assert svg_path.join([first, second])
    == Error(svg_path.Discontinuous(
      previous_index: 1,
      next_index: 2,
      expected: c,
      got: d,
      distance: 10.0,
    ))
}

pub fn join_rejects_closed_inputs_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let open = svg_path.assert_subpath([svg_path.Line(start: a, end: b)])
  let closed =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)

  assert svg_path.join([closed, open]) == Error(svg_path.AlreadyClosed)
  assert svg_path.join([open, closed]) == Error(svg_path.AlreadyClosed)
}

pub fn join_with_wiggle_reconciles_tiny_endpoint_gap_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let near_b = svg_path.point(10.0000000001, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let first = svg_path.assert_subpath([svg_path.Line(start: a, end: b)])
  let second = svg_path.assert_subpath([svg_path.Line(start: near_b, end: c)])

  let assert Ok(joined) =
    svg_path.join_with([first, second], policy: svg_path.Wiggle)

  assert svg_path.start(joined) == Ok(a)
  assert svg_path.end(joined) == Ok(c)
  assert continuous_segments(svg_path.segments(joined))
}

pub fn assert_join_with_wiggle_reconciles_tiny_endpoint_gap_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let near_b = svg_path.point(10.0000000001, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let first = svg_path.assert_subpath([svg_path.Line(start: a, end: b)])
  let second = svg_path.assert_subpath([svg_path.Line(start: near_b, end: c)])

  let joined =
    svg_path.assert_join_with([first, second], policy: svg_path.Wiggle)

  assert svg_path.start(joined) == Ok(a)
  assert svg_path.end(joined) == Ok(c)
  assert continuous_segments(svg_path.segments(joined))
}

pub fn join_with_wiggle_rejects_closed_inputs_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let open = svg_path.assert_subpath([svg_path.Line(start: a, end: b)])
  let closed =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)

  assert svg_path.join_with([closed, open], policy: svg_path.Wiggle)
    == Error(svg_path.AlreadyClosed)
  assert svg_path.join_with([open, closed], policy: svg_path.Wiggle)
    == Error(svg_path.AlreadyClosed)
}

pub fn append_segment_with_line_bridges_a_gap_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let assert Ok(subpath) =
    svg_path.empty_subpath(at: svg_path.point(0.0, 0.0))
    |> svg_path.append_segment(svg_path.Line(start: a, end: b))
    |> result_try_append_segment_with_line(svg_path.Line(start: c, end: d))

  assert subpath |> svg_path.segments |> list.length == 3
  assert svg_path.end(subpath) == Ok(d)
}

pub fn join_with_line_bridges_a_gap_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let first = svg_path.assert_subpath([svg_path.Line(start: a, end: b)])
  let second = svg_path.assert_subpath([svg_path.Line(start: c, end: d)])

  let assert Ok(joined) =
    svg_path.join_with([first, second], policy: svg_path.Bridge)

  assert svg_path.segments(joined)
    == [
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ]
}

pub fn join_with_line_rejects_closed_inputs_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let open = svg_path.assert_subpath([svg_path.Line(start: a, end: b)])
  let closed =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)

  assert svg_path.join_with([closed, open], policy: svg_path.Bridge)
    == Error(svg_path.AlreadyClosed)
  assert svg_path.join_with([open, closed], policy: svg_path.Bridge)
    == Error(svg_path.AlreadyClosed)
}

pub fn subpath_with_custom_reconciles_a_gap_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)

  let assert Ok(subpath) =
    svg_path.subpath_with(
      [svg_path.Line(start: a, end: b), svg_path.Line(start: c, end: d)],
      policy: svg_path.Custom(fn(previous, next) {
        #(line_to_end(previous, c), next)
      }),
    )

  assert svg_path.segments(subpath)
    == [svg_path.Line(start: a, end: c), svg_path.Line(start: c, end: d)]
}

pub fn subpath_with_custom_rejects_invalid_results_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)

  assert svg_path.subpath_with(
      [svg_path.Line(start: a, end: b), svg_path.Line(start: c, end: d)],
      policy: svg_path.Custom(fn(previous, next) { #(previous, next) }),
    )
    == Error(svg_path.Discontinuous(
      previous_index: 0,
      next_index: 1,
      expected: b,
      got: c,
      distance: 10.0,
    ))
}

pub fn append_segment_with_custom_can_rewrite_the_incoming_segment_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let e = svg_path.point(40.0, 0.0)
  let subpath = svg_path.assert_subpath([svg_path.Line(start: a, end: b)])

  let assert Ok(appended) =
    svg_path.append_segment_with(
      subpath,
      svg_path.Line(start: c, end: d),
      policy: svg_path.Custom(fn(previous, _next) {
        #(
          previous,
          svg_path.Line(start: svg_path.segment_end(previous), end: e),
        )
      }),
    )

  assert svg_path.segments(appended)
    == [svg_path.Line(start: a, end: b), svg_path.Line(start: b, end: e)]
}

pub fn join_with_custom_reconciles_a_gap_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let first = svg_path.assert_subpath([svg_path.Line(start: a, end: b)])
  let second = svg_path.assert_subpath([svg_path.Line(start: c, end: d)])

  let assert Ok(joined) =
    svg_path.join_with(
      [first, second],
      policy: svg_path.Custom(fn(previous, next) {
        #(previous, line_from_start(next, svg_path.segment_end(previous)))
      }),
    )

  assert svg_path.segments(joined)
    == [svg_path.Line(start: a, end: b), svg_path.Line(start: b, end: d)]
}

pub fn set_closed_with_bridge_appends_a_final_line_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0, 10.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])
    |> result_try_set_closed_with_bridge

  assert svg_path.is_closed(subpath)
  assert subpath |> svg_path.segments |> list.length == 3
  assert svg_path.end(subpath) == Ok(a)
}

pub fn set_closed_with_custom_reconciles_the_closing_gap_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0, 10.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  let assert Ok(closed) =
    svg_path.set_closed_with(
      subpath,
      closed: True,
      policy: svg_path.Custom(fn(last, first) {
        #(line_to_end(last, svg_path.segment_start(first)), first)
      }),
    )

  assert svg_path.is_closed(closed)
  assert svg_path.segments(closed)
    == [svg_path.Line(start: a, end: b), svg_path.Line(start: b, end: a)]
}

pub fn set_closed_with_custom_rejects_invalid_results_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0, 10.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert svg_path.set_closed_with(
      subpath,
      closed: True,
      policy: svg_path.Custom(fn(last, first) { #(last, first) }),
    )
    == Error(svg_path.Discontinuous(
      previous_index: 1,
      next_index: 0,
      expected: a,
      got: c,
      distance: 14.142135623730951,
    ))
}

pub fn set_closed_true_empty_subpath_closes_test() {
  let subpath = svg_path.empty_subpath(at: svg_path.point(0.0, 0.0))

  assert svg_path.set_closed(subpath, closed: True)
    == Ok(svg_path.assert_set_closed(subpath, closed: True))
}

pub fn set_closed_true_discontinuous_error_reports_last_to_first_indices_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(0.0, 10.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert svg_path.set_closed(subpath, closed: True)
    == Error(svg_path.Discontinuous(
      previous_index: 1,
      next_index: 0,
      expected: a,
      got: c,
      distance: 10.0,
    ))
}

pub fn assert_set_closed_true_closes_matching_endpoints_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])

  let closed = svg_path.assert_set_closed(subpath, closed: True)

  assert svg_path.is_closed(closed)
}

pub fn open_at_rotates_a_closed_subpath_to_start_at_index_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0, 10.0)
  let d = svg_path.point(0.0, 10.0)
  let ab = svg_path.Line(start: a, end: b)
  let bc = svg_path.Line(start: b, end: c)
  let cd = svg_path.Line(start: c, end: d)
  let da = svg_path.Line(start: d, end: a)
  let subpath = closed_subpath([ab, bc, cd, da])

  let assert Ok(opened) = svg_path.open_at(subpath, index: 1)

  assert !svg_path.is_closed(opened)
  assert svg_path.segments(opened) == [bc, cd, da, ab]
  assert svg_path.start(opened) == Ok(b)
  assert svg_path.end(opened) == Ok(b)
}

pub fn open_at_accepts_negative_indices_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0, 10.0)
  let d = svg_path.point(0.0, 10.0)
  let ab = svg_path.Line(start: a, end: b)
  let bc = svg_path.Line(start: b, end: c)
  let cd = svg_path.Line(start: c, end: d)
  let da = svg_path.Line(start: d, end: a)
  let subpath = closed_subpath([ab, bc, cd, da])

  let assert Ok(opened) = svg_path.open_at(subpath, index: -1)

  assert svg_path.segments(opened) == [da, ab, bc, cd]
  assert svg_path.start(opened) == Ok(d)
  assert svg_path.end(opened) == Ok(d)
}

pub fn open_at_takes_boundary_indices_modulo_length_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0, 10.0)
  let d = svg_path.point(0.0, 10.0)
  let ab = svg_path.Line(start: a, end: b)
  let bc = svg_path.Line(start: b, end: c)
  let cd = svg_path.Line(start: c, end: d)
  let da = svg_path.Line(start: d, end: a)
  let segments = [ab, bc, cd, da]
  let subpath = closed_subpath(segments)

  let assert Ok(opened_at_length) = svg_path.open_at(subpath, index: 4)
  let assert Ok(opened_at_negative_length) =
    svg_path.open_at(subpath, index: -4)

  assert svg_path.segments(opened_at_length) == segments
  assert svg_path.segments(opened_at_negative_length) == segments
}

pub fn open_at_rejects_open_subpaths_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let subpath = svg_path.assert_subpath([svg_path.Line(start: a, end: b)])

  assert svg_path.open_at(subpath, index: 0) == Error(svg_path.NotClosed)
}

pub fn open_at_rejects_indices_outside_length_range_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0, 10.0)
  let ab = svg_path.Line(start: a, end: b)
  let bc = svg_path.Line(start: b, end: c)
  let ca = svg_path.Line(start: c, end: a)
  let subpath = closed_subpath([ab, bc, ca])

  assert svg_path.open_at(subpath, index: 4)
    == Error(svg_path.InvalidOpenIndex(index: 4, length: 3))
  assert svg_path.open_at(subpath, index: -4)
    == Error(svg_path.InvalidOpenIndex(index: -4, length: 3))
}

pub fn set_closed_with_wiggle_replaces_nearby_endpoints_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let near_a = svg_path.point(0.0000000001, 0.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: near_a),
    ])
    |> result_try_set_closed_with_wiggle

  assert svg_path.is_closed(subpath)
  assert svg_path.start(subpath) == svg_path.end(subpath)
}

pub fn set_closed_with_wiggle_rejects_misaligned_vertical_lines_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(0.0, 10.0)
  let c = svg_path.point(0.0000000001, 0.0000000001)
  let d = svg_path.point(0.0000000001, 0.00000000005)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ])

  assert svg_path.set_closed_with(
      subpath,
      closed: True,
      policy: svg_path.Wiggle,
    )
    == Error(svg_path.IncompatibleVerticalWiggle(previous_end: d, next_start: a))
}

pub fn set_closed_with_wiggle_rejects_misaligned_horizontal_lines_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(0.0000000001, 0.0000000001)
  let d = svg_path.point(0.00000000005, 0.0000000001)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ])

  assert svg_path.set_closed_with(
      subpath,
      closed: True,
      policy: svg_path.Wiggle,
    )
    == Error(svg_path.IncompatibleHorizontalWiggle(
      previous_end: d,
      next_start: a,
    ))
}

fn result_try_append_segment_with_line(
  result_subpath: Result(svg_path.Subpath, svg_path.Error),
  segment: svg_path.Segment,
) -> Result(svg_path.Subpath, svg_path.Error) {
  case result_subpath {
    Ok(subpath) ->
      svg_path.append_segment_with(subpath, segment, policy: svg_path.Bridge)
    Error(error) -> Error(error)
  }
}

fn closed_subpath(segments: List(svg_path.Segment)) -> svg_path.Subpath {
  svg_path.assert_subpath(segments)
  |> svg_path.assert_set_closed(closed: True)
}

fn result_try_set_closed_with_bridge(
  result_subpath: Result(svg_path.Subpath, svg_path.Error),
) -> Result(svg_path.Subpath, svg_path.Error) {
  case result_subpath {
    Ok(subpath) ->
      svg_path.set_closed_with(subpath, closed: True, policy: svg_path.Bridge)
    Error(error) -> Error(error)
  }
}

fn result_try_set_closed_with_wiggle(
  result_subpath: Result(svg_path.Subpath, svg_path.Error),
) -> Result(svg_path.Subpath, svg_path.Error) {
  case result_subpath {
    Ok(subpath) ->
      svg_path.set_closed_with(subpath, closed: True, policy: svg_path.Wiggle)
    Error(error) -> Error(error)
  }
}

fn line_from_start(segment: svg_path.Segment, start: svg_path.Point) {
  case segment {
    svg_path.Line(end:, ..) -> svg_path.Line(start:, end:)
    _ -> segment
  }
}

fn line_to_end(segment: svg_path.Segment, end: svg_path.Point) {
  case segment {
    svg_path.Line(start:, ..) -> svg_path.Line(start:, end:)
    _ -> segment
  }
}

fn unwrap_segment(result: Result(svg_path.Segment, Nil)) -> svg_path.Segment {
  let assert Ok(segment) = result
  segment
}

fn all_cubic(segments: List(svg_path.Segment)) -> Bool {
  list.all(segments, fn(segment) {
    case segment {
      svg_path.CubicBezier(..) -> True
      _ -> False
    }
  })
}

fn no_arcs(segments: List(svg_path.Segment)) -> Bool {
  list.all(segments, fn(segment) {
    case segment {
      svg_path.Arc(..) -> False
      _ -> True
    }
  })
}

fn contains_line(
  segments: List(svg_path.Segment),
  line: svg_path.Segment,
) -> Bool {
  list.any(segments, fn(segment) { segment == line })
}

fn contains_quadratic(
  segments: List(svg_path.Segment),
  quadratic: svg_path.Segment,
) -> Bool {
  list.any(segments, fn(segment) { segment == quadratic })
}

fn continuous_segments(segments: List(svg_path.Segment)) -> Bool {
  case segments {
    [] | [_] -> True
    [first, second, ..rest] -> {
      svg_path.segment_end(first) == svg_path.segment_start(second)
      && continuous_segments([second, ..rest])
    }
  }
}

fn point_near(a: svg_path.Point, b: svg_path.Point) -> Bool {
  near(a.x, b.x) && near(a.y, b.y)
}

fn bbox_near(
  box: svg_path.BoundingBox,
  min expected_min: svg_path.Point,
  max expected_max: svg_path.Point,
) -> Bool {
  let svg_path.BoundingBox(min:, max:) = box
  point_near(min, expected_min) && point_near(max, expected_max)
}

fn near(a: Float, b: Float) -> Bool {
  float.absolute_value(a -. b) <=. tolerance
}

fn segment_intersections_are_consistent(
  left: svg_path.Segment,
  right: svg_path.Segment,
) -> Bool {
  case svg_path.segment_intersections(left, right) {
    Error(_) -> False
    Ok([]) -> False
    Ok(intersections) -> {
      list.all(intersections, fn(intersection) {
        intersection_t_in_range(intersection.left_t)
        && intersection_t_in_range(intersection.right_t)
        && intersection_point_matches(
          left,
          intersection.left_t,
          intersection.point,
        )
        && intersection_point_matches(
          right,
          intersection.right_t,
          intersection.point,
        )
      })
    }
  }
}

fn intersection_t_in_range(t: Float) -> Bool {
  t >=. 0.0 -. tolerance && t <=. 1.0 +. tolerance
}

fn intersection_point_matches(
  segment: svg_path.Segment,
  t: Float,
  point: svg_path.Point,
) -> Bool {
  case svg_path.segment_point(segment, at: t) {
    Error(_) -> False
    Ok(actual) -> point_near_loose(actual, point)
  }
}

fn point_near_loose(a: svg_path.Point, b: svg_path.Point) -> Bool {
  let loose_tolerance = 0.0001

  float.absolute_value(a.x -. b.x) <=. loose_tolerance
  && float.absolute_value(a.y -. b.y) <=. loose_tolerance
}
