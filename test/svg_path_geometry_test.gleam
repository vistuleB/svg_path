import gleam/float
import gleam/int
import gleam/list
import gleam/result
import svg_path

const tolerance = 0.000001

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

pub fn segment_length_measures_line_exactly_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(3.0, 4.0),
    )

  let assert Ok(length) = svg_path.segment_length(line)

  assert near(length, 5.0)
}

pub fn segment_length_approximates_quadratic_curve_test() {
  let curve =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(10.0, 20.0),
      end: svg_path.point(20.0, 0.0),
    )

  let assert Ok(length) = svg_path.segment_length(curve)

  assert length >. 20.0
  assert length <. 40.0
}

pub fn segment_length_matches_sampled_curve_reference_test() {
  let curve =
    svg_path.CubicBezier(
      start: svg_path.point(0.0, 0.0),
      control1: svg_path.point(0.0, 30.0),
      control2: svg_path.point(40.0, -10.0),
      end: svg_path.point(40.0, 20.0),
    )

  let assert Ok(length) = svg_path.segment_length(curve)
  let assert Ok(reference) = sampled_segment_length(curve, samples: 1000)

  assert float.absolute_value(length -. reference) <. 0.001
}

pub fn segment_length_approximates_arc_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(20.0, 0.0),
    )

  let assert Ok(length) = svg_path.segment_length(arc)

  assert float.absolute_value(length -. 31.41592653589793) <. 0.01
}

pub fn segment_length_with_rejects_invalid_options_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  assert svg_path.segment_length_with(
      line,
      options: svg_path.LengthOptions(tolerance: 0.0, max_depth: 20),
    )
    == Error(svg_path.InvalidLengthTolerance(0.0))
  assert svg_path.segment_length_with(
      line,
      options: svg_path.LengthOptions(tolerance: 0.000000001, max_depth: 0),
    )
    == Error(svg_path.InvalidLengthMaxDepth(0))
}

pub fn subpath_length_sums_segment_lengths_test() {
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(3.0, 4.0),
      ),
      svg_path.Line(
        start: svg_path.point(3.0, 4.0),
        end: svg_path.point(8.0, 16.0),
      ),
    ])

  let assert Ok(length) = svg_path.subpath_length(subpath)

  assert near(length, 18.0)
}

pub fn subpath_length_returns_zero_for_empty_subpath_test() {
  let subpath = svg_path.empty_subpath(at: svg_path.point(0.0, 0.0))

  assert svg_path.subpath_length(subpath) == Ok(0.0)
}

pub fn segment_parameter_at_length_measures_line_exactly_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  assert svg_path.segment_parameter_at_length(line, distance: 4.0) == Ok(0.4)
}

pub fn segment_point_at_length_evaluates_line_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  let assert Ok(point) = svg_path.segment_point_at_length(line, distance: 4.0)

  assert point_near(point, svg_path.point(4.0, 0.0))
}

pub fn segment_parameter_at_length_inverts_symmetric_curve_test() {
  let curve =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(10.0, 20.0),
      end: svg_path.point(20.0, 0.0),
    )

  let assert Ok(length) = svg_path.segment_length(curve)
  let assert Ok(t) =
    svg_path.segment_parameter_at_length(curve, distance: length /. 2.0)

  assert near(t, 0.5)
}

pub fn segment_point_at_length_evaluates_arc_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(20.0, 0.0),
    )

  let assert Ok(length) = svg_path.segment_length(arc)
  let assert Ok(point) =
    svg_path.segment_point_at_length(arc, distance: length /. 2.0)
  let assert Ok(derivative) =
    svg_path.segment_derivative_at_length(arc, distance: length /. 2.0)

  assert point_near(point, svg_path.point(10.0, -10.0))
  assert derivative.x >. 0.0
  assert float.absolute_value(derivative.y) <. 0.000001
}

pub fn segment_parameter_at_length_rejects_invalid_distances_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  assert svg_path.segment_parameter_at_length(line, distance: -1.0)
    == Error(svg_path.InvalidLengthDistance(distance: -1.0, length: 10.0))
  assert svg_path.segment_parameter_at_length(line, distance: 11.0)
    == Error(svg_path.InvalidLengthDistance(distance: 11.0, length: 10.0))
}

pub fn segment_between_lengths_uses_traveled_distances_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  let assert Ok(forward) =
    svg_path.segment_between_lengths(line, from: 2.0, to: 7.0)
  let assert Ok(reverse) =
    svg_path.segment_between_lengths(line, from: 7.0, to: 2.0)

  assert svg_path.segment_start(forward) == svg_path.point(2.0, 0.0)
  assert svg_path.segment_end(forward) == svg_path.point(7.0, 0.0)
  assert svg_path.segment_start(reverse) == svg_path.point(7.0, 0.0)
  assert svg_path.segment_end(reverse) == svg_path.point(2.0, 0.0)
}

pub fn segments_between_lengths_uses_adjacent_distances_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  let assert Ok([first, second]) =
    svg_path.segments_between_lengths(line, between: [2.0, 7.0, 4.0])

  assert svg_path.segment_start(first) == svg_path.point(2.0, 0.0)
  assert svg_path.segment_end(first) == svg_path.point(7.0, 0.0)
  assert svg_path.segment_start(second) == svg_path.point(7.0, 0.0)
  assert svg_path.segment_end(second) == svg_path.point(4.0, 0.0)
}

pub fn segment_between_lengths_rejects_invalid_input_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  assert svg_path.segment_between_lengths(line, from: 0.0, to: 11.0)
    == Error(svg_path.InvalidLengthDistance(distance: 11.0, length: 10.0))
  assert svg_path.segment_between_lengths_with(
      line,
      from: 2.0,
      to: 7.0,
      options: svg_path.LengthOptions(tolerance: 0.0, max_depth: 20),
    )
    == Error(svg_path.InvalidLengthTolerance(0.0))
}

pub fn subpath_parameter_at_length_returns_public_parameter_test() {
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(3.0, 4.0),
      ),
      svg_path.Line(
        start: svg_path.point(3.0, 4.0),
        end: svg_path.point(3.0, 16.0),
      ),
    ])

  assert svg_path.subpath_parameter_at_length(subpath, distance: 11.0)
    == Ok(svg_path.SubpathParameter(segment_index: 1, t: 0.5))
  assert svg_path.subpath_parameter_at_length(subpath, distance: 17.0)
    == Ok(svg_path.SubpathParameter(segment_index: 1, t: 1.0))
}

pub fn subpath_point_and_derivative_at_length_evaluate_parameter_test() {
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(3.0, 4.0),
      ),
      svg_path.Line(
        start: svg_path.point(3.0, 4.0),
        end: svg_path.point(3.0, 16.0),
      ),
    ])

  let assert Ok(point) =
    svg_path.subpath_point_at_length(subpath, distance: 11.0)
  let assert Ok(derivative) =
    svg_path.subpath_derivative_at_length(subpath, distance: 11.0)

  assert point_near(point, svg_path.point(3.0, 10.0))
  assert point_near(derivative, svg_path.point(0.0, 12.0))
}

pub fn subpath_parameter_at_length_rejects_empty_subpaths_test() {
  let subpath = svg_path.empty_subpath(at: svg_path.point(0.0, 0.0))

  assert svg_path.subpath_parameter_at_length(subpath, distance: 0.0)
    == Error(svg_path.EmptySubpath)
}

pub fn subpath_between_lengths_crosses_segments_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ])

  let assert Ok(piece) =
    svg_path.subpath_between_lengths(subpath, from: 5.0, to: 25.0)

  assert svg_path.segments(piece)
    == [
      svg_path.Line(start: svg_path.point(5.0, 0.0), end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: svg_path.point(25.0, 0.0)),
    ]
}

pub fn subpaths_between_lengths_splits_open_subpath_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ])

  let assert Ok([first, second, third]) =
    svg_path.subpaths_between_lengths(subpath, between: [5.0, 25.0])

  assert svg_path.segments(first)
    == [svg_path.Line(start: a, end: svg_path.point(5.0, 0.0))]
  assert svg_path.segments(second)
    == [
      svg_path.Line(start: svg_path.point(5.0, 0.0), end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: svg_path.point(25.0, 0.0)),
    ]
  assert svg_path.segments(third)
    == [svg_path.Line(start: svg_path.point(25.0, 0.0), end: d)]
}

pub fn subpath_between_lengths_wraps_closed_subpaths_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0, 10.0)
  let d = svg_path.point(0.0, 10.0)
  let subpath =
    closed_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
      svg_path.Line(start: d, end: a),
    ])

  let assert Ok(piece) =
    svg_path.subpath_between_lengths(subpath, from: 25.0, to: 15.0)

  assert svg_path.segments(piece)
    == [
      svg_path.Line(start: svg_path.point(5.0, 10.0), end: d),
      svg_path.Line(start: d, end: a),
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: svg_path.point(10.0, 5.0)),
    ]
}

pub fn path_length_sums_subpath_lengths_test() {
  let first =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(3.0, 4.0),
      ),
    ])
  let second =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(10.0, 10.0),
        end: svg_path.point(10.0, 22.0),
      ),
    ])
  let path =
    svg_path.Path([
      svg_path.empty_subpath(at: svg_path.point(-1.0, -1.0)),
      first,
      second,
    ])

  let assert Ok(length) = svg_path.path_length(path)

  assert near(length, 17.0)
}

pub fn path_length_returns_zero_for_empty_path_test() {
  assert svg_path.path_length(svg_path.empty_path()) == Ok(0.0)
}

pub fn path_parameter_at_length_returns_public_parameter_test() {
  let first =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(3.0, 4.0),
      ),
    ])
  let second =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(10.0, 10.0),
        end: svg_path.point(10.0, 22.0),
      ),
    ])
  let path =
    svg_path.Path([
      svg_path.empty_subpath(at: svg_path.point(-1.0, -1.0)),
      first,
      second,
    ])

  assert svg_path.path_parameter_at_length(path, distance: 11.0)
    == Ok(svg_path.PathParameter(
      subpath_index: 2,
      at: svg_path.SubpathParameter(segment_index: 0, t: 0.5),
    ))
  assert svg_path.path_parameter_at_length(path, distance: 17.0)
    == Ok(svg_path.PathParameter(
      subpath_index: 2,
      at: svg_path.SubpathParameter(segment_index: 0, t: 1.0),
    ))
}

pub fn path_point_and_derivative_at_length_evaluate_parameter_test() {
  let first =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(3.0, 4.0),
      ),
    ])
  let second =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(10.0, 10.0),
        end: svg_path.point(10.0, 22.0),
      ),
    ])
  let path = svg_path.Path([first, second])

  let assert Ok(point) = svg_path.path_point_at_length(path, distance: 11.0)
  let assert Ok(derivative) =
    svg_path.path_derivative_at_length(path, distance: 11.0)

  assert point_near(point, svg_path.point(10.0, 16.0))
  assert point_near(derivative, svg_path.point(0.0, 12.0))
}

pub fn path_parameter_at_length_rejects_empty_paths_and_empty_subpaths_test() {
  let move_only = svg_path.empty_subpath(at: svg_path.point(0.0, 0.0))

  assert svg_path.path_parameter_at_length(svg_path.empty_path(), distance: 0.0)
    == Error(svg_path.EmptyPath)
  assert svg_path.path_parameter_at_length(
      svg_path.Path([move_only]),
      distance: 0.0,
    )
    == Error(svg_path.EmptySubpaths)
}

pub fn path_parameter_at_length_rejects_invalid_distances_test() {
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 0.0),
      ),
    ])
  let path = svg_path.from_subpath(subpath)

  assert svg_path.path_parameter_at_length(path, distance: -1.0)
    == Error(svg_path.InvalidLengthDistance(distance: -1.0, length: 10.0))
  assert svg_path.path_parameter_at_length(path, distance: 11.0)
    == Error(svg_path.InvalidLengthDistance(distance: 11.0, length: 10.0))
}

pub fn path_point_rejects_invalid_path_parameters_test() {
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 0.0),
      ),
    ])
  let path = svg_path.from_subpath(subpath)

  assert svg_path.path_point(
      path,
      at: svg_path.PathParameter(
        subpath_index: 1,
        at: svg_path.SubpathParameter(segment_index: 0, t: 0.0),
      ),
    )
    == Error(svg_path.InvalidPathParameter(subpath_index: 1, length: 1))
}

pub fn segment_projection_returns_line_parameter_point_and_distance_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  let assert Ok(svg_path.SegmentProjection(t:, point:, distance:)) =
    svg_path.segment_projection(svg_path.point(4.0, 3.0), to: line)

  assert near(t, 0.4)
  assert point_near(point, svg_path.point(4.0, 0.0))
  assert near(distance, 3.0)
}

pub fn segment_projection_clamps_to_line_endpoint_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  let assert Ok(svg_path.SegmentProjection(t:, point:, distance:)) =
    svg_path.segment_projection(svg_path.point(13.0, 4.0), to: line)

  assert near(t, 1.0)
  assert point_near(point, svg_path.point(10.0, 0.0))
  assert near(distance, 5.0)
}

pub fn segment_projection_returns_curve_parameter_point_and_distance_test() {
  let curve =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(10.0, 20.0),
      end: svg_path.point(20.0, 0.0),
    )

  let assert Ok(svg_path.SegmentProjection(t:, point:, distance:)) =
    svg_path.segment_projection(svg_path.point(10.0, 15.0), to: curve)

  assert near(t, 0.5)
  assert point_near(point, svg_path.point(10.0, 10.0))
  assert near(distance, 5.0)
}

pub fn segment_projection_with_rejects_invalid_options_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  assert svg_path.segment_projection_with(
      svg_path.point(5.0, 4.0),
      to: line,
      options: svg_path.DistanceOptions(
        samples: 0,
        tolerance: 0.000000001,
        max_iterations: 100,
      ),
    )
    == Error(svg_path.InvalidDistanceSamples(0))
}

pub fn subpath_projection_returns_subpath_parameter_point_and_distance_test() {
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.point(10.0, 0.0),
        end: svg_path.point(10.0, 20.0),
      ),
    ])

  let assert Ok(svg_path.SubpathProjection(at:, point:, distance:)) =
    svg_path.subpath_projection(svg_path.point(14.0, 8.0), to: subpath)

  assert at == svg_path.SubpathParameter(segment_index: 1, t: 0.4)
  assert point_near(point, svg_path.point(10.0, 8.0))
  assert near(distance, 4.0)
}

pub fn subpath_projection_rejects_empty_subpaths_test() {
  let subpath = svg_path.empty_subpath(at: svg_path.point(0.0, 0.0))

  assert svg_path.subpath_projection(svg_path.point(1.0, 1.0), to: subpath)
    == Error(svg_path.EmptySubpath)
}

pub fn subpath_containment_implicitly_closes_open_subpaths_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0, 10.0)
  let d = svg_path.point(0.0, 10.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ])

  assert !svg_path.is_closed(subpath)
  assert svg_path.subpath_containment(
      svg_path.point(5.0, 5.0),
      within: subpath,
      using: svg_path.Nonzero,
    )
    == Ok(svg_path.Inside)
  assert svg_path.subpath_containment(
      svg_path.point(15.0, 5.0),
      within: subpath,
      using: svg_path.Nonzero,
    )
    == Ok(svg_path.Outside)
  assert svg_path.subpath_containment(
      svg_path.point(0.0, 5.0),
      within: subpath,
      using: svg_path.Nonzero,
    )
    == Ok(svg_path.Boundary)
  assert svg_path.subpath_containment(
      svg_path.point(10.0, 5.0),
      within: subpath,
      using: svg_path.Nonzero,
    )
    == Ok(svg_path.Boundary)
}

pub fn subpath_containment_supports_both_fill_rules_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0, 10.0)
  let d = svg_path.point(0.0, 10.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
      svg_path.Line(start: d, end: a),
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
      svg_path.Line(start: d, end: a),
    ])

  assert svg_path.subpath_containment(
      svg_path.point(5.0, 5.0),
      within: subpath,
      using: svg_path.Nonzero,
    )
    == Ok(svg_path.Inside)
  assert svg_path.subpath_containment(
      svg_path.point(5.0, 5.0),
      within: subpath,
      using: svg_path.EvenOdd,
    )
    == Ok(svg_path.Outside)
}

pub fn subpath_containment_handles_ray_through_vertex_test() {
  let subpath =
    svg_path.assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 5.0),
      svg_path.point(0.0, 10.0),
    ])

  assert svg_path.subpath_containment(
      svg_path.point(2.0, 5.0),
      within: subpath,
      using: svg_path.Nonzero,
    )
    == Ok(svg_path.Inside)
  assert svg_path.subpath_containment(
      svg_path.point(12.0, 5.0),
      within: subpath,
      using: svg_path.Nonzero,
    )
    == Ok(svg_path.Outside)
}

pub fn subpath_containment_handles_curved_boundaries_test() {
  let curve =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(10.0, 20.0),
      end: svg_path.point(20.0, 0.0),
    )
  let subpath = svg_path.assert_subpath([curve])

  assert svg_path.subpath_containment(
      svg_path.point(10.0, 10.0),
      within: subpath,
      using: svg_path.Nonzero,
    )
    == Ok(svg_path.Boundary)
  assert svg_path.subpath_containment(
      svg_path.point(10.0, 5.0),
      within: subpath,
      using: svg_path.Nonzero,
    )
    == Ok(svg_path.Inside)
}

pub fn subpath_containment_uses_boundary_tolerance_test() {
  let subpath =
    svg_path.assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
      svg_path.point(0.0, 10.0),
    ])

  assert svg_path.subpath_containment_with(
      svg_path.point(-0.0005, 5.0),
      within: subpath,
      using: svg_path.Nonzero,
      options: svg_path.ContainmentOptions(
        tolerance: 0.001,
        samples: 100,
        max_iterations: 100,
      ),
    )
    == Ok(svg_path.Boundary)
}

pub fn subpath_containment_move_only_subpath_is_outside_test() {
  let point = svg_path.point(5.0, 5.0)
  let subpath = svg_path.empty_subpath(at: point)

  assert svg_path.subpath_containment(
      point,
      within: subpath,
      using: svg_path.Nonzero,
    )
    == Ok(svg_path.Outside)
}

pub fn subpath_containment_rejects_invalid_options_test() {
  let subpath = svg_path.empty_subpath(at: svg_path.point(0.0, 0.0))
  let point = svg_path.point(1.0, 1.0)

  assert svg_path.subpath_containment_with(
      point,
      within: subpath,
      using: svg_path.Nonzero,
      options: svg_path.ContainmentOptions(
        tolerance: 0.0,
        samples: 100,
        max_iterations: 100,
      ),
    )
    == Error(svg_path.InvalidContainmentTolerance(0.0))
  assert svg_path.subpath_containment_with(
      point,
      within: subpath,
      using: svg_path.Nonzero,
      options: svg_path.ContainmentOptions(
        tolerance: 0.000000001,
        samples: 0,
        max_iterations: 100,
      ),
    )
    == Error(svg_path.InvalidContainmentSamples(0))
  assert svg_path.subpath_containment_with(
      point,
      within: subpath,
      using: svg_path.Nonzero,
      options: svg_path.ContainmentOptions(
        tolerance: 0.000000001,
        samples: 100,
        max_iterations: 0,
      ),
    )
    == Error(svg_path.InvalidContainmentMaxIterations(0))
}

pub fn path_containment_combines_subpath_winding_and_parity_test() {
  let outer =
    svg_path.assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(20.0, 0.0),
      svg_path.point(20.0, 20.0),
      svg_path.point(0.0, 20.0),
    ])
  let inner_same_direction =
    svg_path.assert_polygon([
      svg_path.point(5.0, 5.0),
      svg_path.point(15.0, 5.0),
      svg_path.point(15.0, 15.0),
      svg_path.point(5.0, 15.0),
    ])
  let inner_opposite_direction =
    svg_path.assert_polygon([
      svg_path.point(5.0, 5.0),
      svg_path.point(5.0, 15.0),
      svg_path.point(15.0, 15.0),
      svg_path.point(15.0, 5.0),
    ])
  let same_direction = svg_path.Path([outer, inner_same_direction])
  let opposite_direction = svg_path.Path([outer, inner_opposite_direction])
  let center = svg_path.point(10.0, 10.0)

  assert svg_path.path_containment(
      center,
      within: same_direction,
      using: svg_path.Nonzero,
    )
    == Ok(svg_path.Inside)
  assert svg_path.path_containment(
      center,
      within: same_direction,
      using: svg_path.EvenOdd,
    )
    == Ok(svg_path.Outside)
  assert svg_path.path_containment(
      center,
      within: opposite_direction,
      using: svg_path.Nonzero,
    )
    == Ok(svg_path.Outside)
  assert svg_path.path_containment(
      center,
      within: opposite_direction,
      using: svg_path.EvenOdd,
    )
    == Ok(svg_path.Outside)
  assert svg_path.path_containment(
      svg_path.point(2.0, 2.0),
      within: opposite_direction,
      using: svg_path.Nonzero,
    )
    == Ok(svg_path.Inside)
}

pub fn path_containment_boundary_on_any_subpath_dominates_test() {
  let outer =
    svg_path.assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(20.0, 0.0),
      svg_path.point(20.0, 20.0),
      svg_path.point(0.0, 20.0),
    ])
  let inner =
    svg_path.assert_polygon([
      svg_path.point(5.0, 5.0),
      svg_path.point(15.0, 5.0),
      svg_path.point(15.0, 15.0),
      svg_path.point(5.0, 15.0),
    ])

  assert svg_path.path_containment(
      svg_path.point(5.0, 10.0),
      within: svg_path.Path([outer, inner]),
      using: svg_path.Nonzero,
    )
    == Ok(svg_path.Boundary)
}

pub fn path_winding_accumulates_subpath_winding_test() {
  let outer =
    svg_path.assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(20.0, 0.0),
      svg_path.point(20.0, 20.0),
      svg_path.point(0.0, 20.0),
    ])
  let inner_same_direction =
    svg_path.assert_polygon([
      svg_path.point(5.0, 5.0),
      svg_path.point(15.0, 5.0),
      svg_path.point(15.0, 15.0),
      svg_path.point(5.0, 15.0),
    ])
  let inner_opposite_direction =
    svg_path.assert_polygon([
      svg_path.point(5.0, 5.0),
      svg_path.point(5.0, 15.0),
      svg_path.point(15.0, 15.0),
      svg_path.point(15.0, 5.0),
    ])

  assert svg_path.path_winding(
      svg_path.point(10.0, 10.0),
      within: svg_path.Path([outer, inner_same_direction]),
    )
    == Ok(svg_path.Winding(2))
  assert svg_path.path_winding(
      svg_path.point(10.0, 10.0),
      within: svg_path.Path([outer, inner_opposite_direction]),
    )
    == Ok(svg_path.Winding(0))
  assert svg_path.path_winding(
      svg_path.point(5.0, 10.0),
      within: svg_path.Path([outer, inner_same_direction]),
    )
    == Ok(svg_path.BoundaryWinding)
}

pub fn path_containment_empty_and_move_only_paths_are_outside_test() {
  let point = svg_path.point(5.0, 5.0)
  let move_only = svg_path.empty_subpath(at: point)

  assert svg_path.path_containment(
      point,
      within: svg_path.empty_path(),
      using: svg_path.Nonzero,
    )
    == Ok(svg_path.Outside)
  assert svg_path.path_containment(
      point,
      within: svg_path.Path([move_only]),
      using: svg_path.Nonzero,
    )
    == Ok(svg_path.Outside)
}

pub fn path_containment_with_rejects_invalid_options_test() {
  assert svg_path.path_containment_with(
      svg_path.point(0.0, 0.0),
      within: svg_path.empty_path(),
      using: svg_path.Nonzero,
      options: svg_path.ContainmentOptions(
        tolerance: 0.0,
        samples: 100,
        max_iterations: 100,
      ),
    )
    == Error(svg_path.InvalidContainmentTolerance(0.0))
}

pub fn path_projection_returns_path_parameter_point_and_distance_test() {
  let first =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 0.0),
      ),
    ])
  let second =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(20.0, 0.0),
        end: svg_path.point(20.0, 10.0),
      ),
    ])
  let path =
    svg_path.Path([
      svg_path.empty_subpath(at: svg_path.point(-10.0, -10.0)),
      first,
      second,
    ])

  let assert Ok(svg_path.PathProjection(at:, point:, distance:)) =
    svg_path.path_projection(svg_path.point(17.0, 6.0), to: path)

  assert at
    == svg_path.PathParameter(
      subpath_index: 2,
      at: svg_path.SubpathParameter(segment_index: 0, t: 0.6),
    )
  assert point_near(point, svg_path.point(20.0, 6.0))
  assert near(distance, 3.0)
}

pub fn path_distance_returns_projection_distance_test() {
  let path =
    svg_path.Path([
      svg_path.assert_subpath([
        svg_path.Line(
          start: svg_path.point(0.0, 0.0),
          end: svg_path.point(10.0, 0.0),
        ),
      ]),
    ])

  let assert Ok(distance) =
    svg_path.path_distance(svg_path.point(4.0, 3.0), to: path)

  assert near(distance, 3.0)
}

pub fn path_projection_rejects_empty_paths_and_empty_subpaths_test() {
  let move_only = svg_path.empty_subpath(at: svg_path.point(0.0, 0.0))

  assert svg_path.path_projection(
      svg_path.point(1.0, 1.0),
      to: svg_path.empty_path(),
    )
    == Error(svg_path.EmptyPath)
  assert svg_path.path_projection(
      svg_path.point(1.0, 1.0),
      to: svg_path.Path([move_only]),
    )
    == Error(svg_path.EmptySubpaths)
}

pub fn path_projection_with_rejects_invalid_options_test() {
  let path =
    svg_path.Path([
      svg_path.assert_subpath([
        svg_path.Line(
          start: svg_path.point(0.0, 0.0),
          end: svg_path.point(10.0, 0.0),
        ),
      ]),
    ])

  assert svg_path.path_projection_with(
      svg_path.point(4.0, 3.0),
      to: path,
      options: svg_path.DistanceOptions(
        samples: 0,
        tolerance: 0.000000001,
        max_iterations: 100,
      ),
    )
    == Error(svg_path.InvalidDistanceSamples(0))
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

pub fn segment_subpath_intersections_groups_and_orders_results_test() {
  let segment =
    svg_path.Line(
      start: svg_path.point(20.0, 0.0),
      end: svg_path.point(0.0, 0.0),
    )
  let a = svg_path.point(5.0, -5.0)
  let b = svg_path.point(5.0, 5.0)
  let c = svg_path.point(10.0, 5.0)
  let d = svg_path.point(10.0, -5.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
      svg_path.Line(start: d, end: a),
      svg_path.Line(start: a, end: b),
    ])

  let assert Ok(intersections) =
    svg_path.segment_subpath_intersections(segment, subpath)
  let assert [first, second] = intersections
  let #(first_point, first_t, first_parameters) = first
  let #(second_point, second_t, second_parameters) = second

  assert near(first_point.x, 10.0)
  assert near(first_point.y, 0.0)
  assert near(first_t, 0.5)
  assert first_parameters == [svg_path.SubpathParameter(2, 0.5)]
  assert near(second_point.x, 5.0)
  assert near(second_point.y, 0.0)
  assert near(second_t, 0.75)
  assert second_parameters
    == [
      svg_path.SubpathParameter(0, 0.5),
      svg_path.SubpathParameter(4, 0.5),
    ]
}

pub fn segment_subpath_intersections_canonicalizes_boundary_aliases_test() {
  let segment =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )
  let a = svg_path.point(0.0, -5.0)
  let b = svg_path.point(5.0, 0.0)
  let c = svg_path.point(10.0, -5.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  let assert Ok([intersection]) =
    svg_path.segment_subpath_intersections(segment, subpath)
  let #(point, segment_t, parameters) = intersection

  assert point_near(point, b)
  assert near(segment_t, 0.5)
  assert parameters == [svg_path.SubpathParameter(1, 0.0)]
}

pub fn segment_subpath_intersections_canonicalizes_closed_boundary_aliases_test() {
  let segment =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )
  let a = svg_path.point(5.0, 0.0)
  let b = svg_path.point(0.0, -5.0)
  let c = svg_path.point(10.0, -5.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)

  let assert Ok([intersection]) =
    svg_path.segment_subpath_intersections(segment, subpath)
  let #(point, segment_t, parameters) = intersection

  assert point_near(point, a)
  assert near(segment_t, 0.5)
  assert parameters == [svg_path.SubpathParameter(0, 0.0)]
}

pub fn segment_subpath_intersections_empty_subpath_test() {
  let segment =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )
  let subpath = svg_path.empty_subpath(at: svg_path.point(5.0, 0.0))

  assert svg_path.segment_subpath_intersections(segment, subpath) == Ok([])
}

pub fn segment_subpath_intersections_propagates_errors_test() {
  let segment =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )
  let subpath = svg_path.assert_subpath([segment])

  assert svg_path.segment_subpath_intersections_with(
      segment,
      subpath,
      options: svg_path.IntersectionOptions(tolerance: 0.0, max_depth: 48),
    )
    == Error(svg_path.InvalidIntersectionTolerance(0.0))
  assert svg_path.segment_subpath_intersections(segment, subpath)
    == Error(svg_path.OverlappingSegments)
}

pub fn subpath_intersections_groups_and_orders_results_test() {
  let left =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(20.0, 0.0),
      svg_path.point(20.0, 10.0),
    ])
  let right =
    svg_path.assert_polyline([
      svg_path.point(5.0, -5.0),
      svg_path.point(5.0, 5.0),
      svg_path.point(15.0, 5.0),
      svg_path.point(15.0, -5.0),
    ])

  let assert Ok(intersections) = svg_path.subpath_intersections(left, right)
  let assert [first, second] = intersections

  assert point_near(first.point, svg_path.point(5.0, 0.0))
  assert first.left_parameters == [svg_path.SubpathParameter(0, 0.25)]
  assert first.right_parameters == [svg_path.SubpathParameter(0, 0.5)]
  assert point_near(second.point, svg_path.point(15.0, 0.0))
  assert second.left_parameters == [svg_path.SubpathParameter(0, 0.75)]
  assert second.right_parameters == [svg_path.SubpathParameter(2, 0.5)]
}

pub fn subpath_intersections_canonicalizes_boundary_aliases_on_both_sides_test() {
  let point = svg_path.point(5.0, 0.0)
  let left =
    svg_path.assert_subpath([
      svg_path.Line(start: svg_path.point(0.0, 0.0), end: point),
      svg_path.Line(start: point, end: svg_path.point(10.0, 0.0)),
    ])
  let right =
    svg_path.assert_subpath([
      svg_path.Line(start: svg_path.point(5.0, -5.0), end: point),
      svg_path.Line(start: point, end: svg_path.point(5.0, 5.0)),
    ])

  let assert Ok([intersection]) = svg_path.subpath_intersections(left, right)

  assert point_near(intersection.point, point)
  assert intersection.left_parameters == [svg_path.SubpathParameter(1, 0.0)]
  assert intersection.right_parameters == [svg_path.SubpathParameter(1, 0.0)]
}

pub fn subpath_intersections_empty_subpaths_test() {
  let empty = svg_path.empty_subpath(at: svg_path.point(0.0, 0.0))
  let line =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 0.0),
      ),
    ])

  assert svg_path.subpath_intersections(empty, line) == Ok([])
  assert svg_path.subpath_intersections(line, empty) == Ok([])
}

pub fn subpath_intersections_propagates_errors_test() {
  let line =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 0.0),
      ),
    ])

  assert svg_path.subpath_intersections_with(
      line,
      line,
      options: svg_path.IntersectionOptions(tolerance: 0.0, max_depth: 48),
    )
    == Error(svg_path.InvalidIntersectionTolerance(0.0))
  assert svg_path.subpath_intersections(line, line)
    == Error(svg_path.OverlappingSegments)
}

pub fn path_intersections_groups_and_orders_results_test() {
  let left =
    svg_path.Path([
      svg_path.assert_polyline([
        svg_path.point(20.0, 0.0),
        svg_path.point(0.0, 0.0),
      ]),
      svg_path.assert_polyline([
        svg_path.point(20.0, 10.0),
        svg_path.point(0.0, 10.0),
      ]),
    ])
  let right =
    svg_path.Path([
      svg_path.assert_polyline([
        svg_path.point(15.0, -5.0),
        svg_path.point(15.0, 5.0),
      ]),
      svg_path.assert_polyline([
        svg_path.point(5.0, -5.0),
        svg_path.point(5.0, 15.0),
      ]),
    ])

  let assert Ok(intersections) = svg_path.path_intersections(left, right)
  let assert [first, second, third] = intersections

  assert point_near(first.point, svg_path.point(15.0, 0.0))
  assert first.left_parameters
    == [
      svg_path.PathParameter(0, svg_path.SubpathParameter(0, 0.25)),
    ]
  assert first.right_parameters
    == [
      svg_path.PathParameter(0, svg_path.SubpathParameter(0, 0.5)),
    ]
  assert point_near(second.point, svg_path.point(5.0, 0.0))
  assert second.left_parameters
    == [
      svg_path.PathParameter(0, svg_path.SubpathParameter(0, 0.75)),
    ]
  assert second.right_parameters
    == [
      svg_path.PathParameter(1, svg_path.SubpathParameter(0, 0.25)),
    ]
  assert point_near(third.point, svg_path.point(5.0, 10.0))
  assert third.left_parameters
    == [
      svg_path.PathParameter(1, svg_path.SubpathParameter(0, 0.75)),
    ]
  assert third.right_parameters
    == [
      svg_path.PathParameter(1, svg_path.SubpathParameter(0, 0.75)),
    ]
}

pub fn path_intersections_canonicalizes_aliases_on_both_sides_test() {
  let point = svg_path.point(5.0, 0.0)
  let left =
    svg_path.Path([
      svg_path.assert_subpath([
        svg_path.Line(start: svg_path.point(0.0, 0.0), end: point),
        svg_path.Line(start: point, end: svg_path.point(10.0, 0.0)),
      ]),
    ])
  let right =
    svg_path.Path([
      svg_path.empty_subpath(at: svg_path.point(100.0, 100.0)),
      svg_path.assert_subpath([
        svg_path.Line(start: svg_path.point(5.0, -5.0), end: point),
        svg_path.Line(start: point, end: svg_path.point(5.0, 5.0)),
      ]),
    ])

  let assert Ok([intersection]) = svg_path.path_intersections(left, right)

  assert point_near(intersection.point, point)
  assert intersection.left_parameters
    == [svg_path.PathParameter(0, svg_path.SubpathParameter(1, 0.0))]
  assert intersection.right_parameters
    == [svg_path.PathParameter(1, svg_path.SubpathParameter(1, 0.0))]
}

pub fn path_intersections_canonicalizes_near_boundary_aliases_test() {
  let middle = svg_path.point(10.0, 0.0)
  let left =
    svg_path.Path([
      svg_path.assert_subpath([
        svg_path.Line(start: svg_path.point(0.0, 0.0), end: middle),
        svg_path.Line(start: middle, end: svg_path.point(20.0, 0.0)),
      ]),
    ])
  let right =
    svg_path.Path([
      svg_path.assert_subpath([
        svg_path.Line(
          start: svg_path.point(9.9999999999, -5.0),
          end: svg_path.point(9.9999999999, 5.0),
        ),
      ]),
      svg_path.assert_subpath([
        svg_path.Line(
          start: svg_path.point(10.0000000001, -5.0),
          end: svg_path.point(10.0000000001, 5.0),
        ),
      ]),
    ])

  let assert Ok([intersection]) =
    svg_path.path_intersections_with(
      left,
      right,
      options: svg_path.IntersectionOptions(tolerance: 0.000001, max_depth: 48),
    )

  assert point_near(intersection.point, middle)
  assert intersection.left_parameters
    == [svg_path.PathParameter(0, svg_path.SubpathParameter(1, 0.0))]
  assert intersection.right_parameters
    == [
      svg_path.PathParameter(0, svg_path.SubpathParameter(0, 0.5)),
      svg_path.PathParameter(1, svg_path.SubpathParameter(0, 0.5)),
    ]
}

pub fn path_intersections_empty_paths_test() {
  let empty = svg_path.Path([])
  let move_only =
    svg_path.Path([svg_path.empty_subpath(at: svg_path.point(0.0, 0.0))])
  let line =
    svg_path.Path([
      svg_path.assert_subpath([
        svg_path.Line(
          start: svg_path.point(0.0, 0.0),
          end: svg_path.point(10.0, 0.0),
        ),
      ]),
    ])

  assert svg_path.path_intersections(empty, line) == Ok([])
  assert svg_path.path_intersections(line, empty) == Ok([])
  assert svg_path.path_intersections(move_only, line) == Ok([])
  assert svg_path.path_intersections(line, move_only) == Ok([])
}

pub fn path_intersections_propagates_errors_test() {
  let path =
    svg_path.Path([
      svg_path.assert_subpath([
        svg_path.Line(
          start: svg_path.point(0.0, 0.0),
          end: svg_path.point(10.0, 0.0),
        ),
      ]),
    ])

  assert svg_path.path_intersections_with(
      path,
      path,
      options: svg_path.IntersectionOptions(tolerance: 0.0, max_depth: 48),
    )
    == Error(svg_path.InvalidIntersectionTolerance(0.0))
  assert svg_path.path_intersections(path, path)
    == Error(svg_path.OverlappingSegments)
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

fn closed_subpath(segments: List(svg_path.Segment)) -> svg_path.Subpath {
  svg_path.assert_subpath(segments)
  |> svg_path.assert_set_closed(closed: True)
}

fn point_near(a: svg_path.Point, b: svg_path.Point) -> Bool {
  near(a.x, b.x) && near(a.y, b.y)
}

fn sampled_segment_length(
  segment: svg_path.Segment,
  samples samples: Int,
) -> Result(Float, svg_path.Error) {
  use start <- result.try(svg_path.segment_point(segment, at: 0.0))

  sampled_segment_length_loop(
    segment,
    samples,
    index: 1,
    previous: start,
    total: 0.0,
  )
}

fn sampled_segment_length_loop(
  segment: svg_path.Segment,
  samples: Int,
  index index: Int,
  previous previous: svg_path.Point,
  total total: Float,
) -> Result(Float, svg_path.Error) {
  case index > samples {
    True -> Ok(total)
    False -> {
      let t = int.to_float(index) /. int.to_float(samples)
      use point <- result.try(svg_path.segment_point(segment, at: t))

      sampled_segment_length_loop(
        segment,
        samples,
        index: index + 1,
        previous: point,
        total: total +. point_distance(previous, point),
      )
    }
  }
}

fn point_distance(a: svg_path.Point, b: svg_path.Point) -> Float {
  let assert Ok(length) =
    { { a.x -. b.x } *. { a.x -. b.x } +. { a.y -. b.y } *. { a.y -. b.y } }
    |> float.square_root

  length
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
