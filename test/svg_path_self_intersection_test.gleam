import gleam/list
import gleeunit
import svg_path
import svg_path/intersections

const tolerance = 0.000001

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn segment_self_intersections_finds_cubic_crossing_test() {
  let curve =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(-0.2708333333333333, -0.3333333333333333),
      control2: svg_path.Point(-0.5416666666666666, -0.3333333333333333),
      end: svg_path.Point(0.1875, 0.0),
    )

  let assert Ok([intersection]) = intersections.segment_self(curve)
  let svg_path.SegmentIntersection(left_t:, right_t:, point:) = intersection

  assert near(left_t, 0.25)
  assert near(right_t, 0.75)
  assert point_near(point, svg_path.segment_point(curve, at: 0.25) |> assert_ok)
}

pub fn segment_self_intersections_treats_same_endpoint_arc_as_empty_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.Point(0.0, 0.0),
      radius: svg_path.Point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: True,
      sweep: True,
      end: svg_path.Point(0.0, 0.0),
    )

  assert intersections.segment_self(arc) == Ok([])
}

pub fn subpath_self_intersections_finds_line_crossing_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 10.0)
  let c = svg_path.Point(0.0, 10.0)
  let d = svg_path.Point(10.0, 0.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ])

  let assert Ok([intersection]) = intersections.subpath_self(subpath)
  let svg_path.SubpathSelfIntersection(point:, parameters:) = intersection
  let #(first, second) = parameters
  let svg_path.SubpathParameter(segment_index: first_index, t: first_t) = first
  let svg_path.SubpathParameter(segment_index: second_index, t: second_t) =
    second

  assert point_near(point, svg_path.Point(5.0, 5.0))
  assert first_index == 0
  assert near(first_t, 0.5)
  assert second_index == 2
  assert near(second_t, 0.5)
}

pub fn subpath_self_intersections_reports_overlapping_line_endpoints_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(10.0, 0.0),
        end: svg_path.Point(10.0, 10.0),
      ),
      svg_path.Line(
        start: svg_path.Point(10.0, 10.0),
        end: svg_path.Point(8.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(8.0, 0.0),
        end: svg_path.Point(2.0, 0.0),
      ),
    ])

  let assert Ok(intersections) = intersections.subpath_self(subpath)

  assert list_contains_point(intersections, svg_path.Point(2.0, 0.0))
  assert list_contains_point(intersections, svg_path.Point(8.0, 0.0))
}

pub fn subpath_self_intersections_ignores_adjacent_segment_join_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 10.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert intersections.subpath_self(subpath) == Ok([])
}

pub fn subpath_self_intersections_ignores_closed_endpoint_join_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 10.0)
  let d = svg_path.Point(0.0, 10.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
      svg_path.Line(start: d, end: a),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)

  assert intersections.subpath_self(subpath) == Ok([])
}

pub fn subpath_self_intersections_finds_cubic_self_intersection_test() {
  let curve =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(-0.2708333333333333, -0.3333333333333333),
      control2: svg_path.Point(-0.5416666666666666, -0.3333333333333333),
      end: svg_path.Point(0.1875, 0.0),
    )
  let subpath = svg_path.subpath_assert([curve])

  let assert Ok([intersection]) = intersections.subpath_self(subpath)
  let svg_path.SubpathSelfIntersection(point:, parameters:) = intersection
  let #(first, second) = parameters
  let svg_path.SubpathParameter(segment_index: first_index, t: first_t) = first
  let svg_path.SubpathParameter(segment_index: second_index, t: second_t) =
    second

  assert point_near(point, svg_path.segment_point(curve, at: 0.25) |> assert_ok)
  assert first_index == 0
  assert near(first_t, 0.25)
  assert second_index == 0
  assert near(second_t, 0.75)
}

pub fn subpath_self_intersections_respects_minimum_arc_length_separation_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 10.0)
  let c = svg_path.Point(0.0, 10.0)
  let d = svg_path.Point(10.0, 0.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ])

  assert intersections.subpath_self_with(
      subpath,
      options: svg_path.SelfIntersectionOptions(
        minimum_arc_length_separation: 100.0,
        distance_tolerance: 0.000001,
      ),
    )
    == Ok([])
}

pub fn subpath_self_intersections_rejects_invalid_options_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(1.0, 0.0),
      ),
    ])

  let assert Error(svg_path.InvalidSelfIntersectionMinimumArcLengthSeparation(
    0.0,
  )) =
    intersections.subpath_self_with(
      subpath,
      options: svg_path.SelfIntersectionOptions(
        minimum_arc_length_separation: 0.0,
        distance_tolerance: 0.000001,
      ),
    )
  let assert Error(svg_path.InvalidSelfIntersectionDistanceTolerance(0.0)) =
    intersections.subpath_self_with(
      subpath,
      options: svg_path.SelfIntersectionOptions(
        minimum_arc_length_separation: 0.000001,
        distance_tolerance: 0.0,
      ),
    )
}

pub fn path_self_intersections_finds_crossing_subpaths_test() {
  let horizontal =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 5.0),
        end: svg_path.Point(10.0, 5.0),
      ),
    ])
  let vertical =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(5.0, 0.0),
        end: svg_path.Point(5.0, 10.0),
      ),
    ])

  let assert Ok([intersection]) =
    intersections.path_self(svg_path.Path([horizontal, vertical]))
  let svg_path.PathSelfIntersection(point:, parameters:) = intersection
  let #(first, second) = parameters
  let svg_path.PathParameter(subpath_index: first_subpath, at: first_at) = first
  let svg_path.PathParameter(subpath_index: second_subpath, at: second_at) =
    second
  let svg_path.SubpathParameter(segment_index: first_segment, t: first_t) =
    first_at
  let svg_path.SubpathParameter(segment_index: second_segment, t: second_t) =
    second_at

  assert point_near(point, svg_path.Point(5.0, 5.0))
  assert first_subpath == 0
  assert first_segment == 0
  assert near(first_t, 0.5)
  assert second_subpath == 1
  assert second_segment == 0
  assert near(second_t, 0.5)
}

pub fn path_self_intersections_includes_single_subpath_crossings_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 10.0),
      ),
      svg_path.Line(
        start: svg_path.Point(10.0, 10.0),
        end: svg_path.Point(0.0, 10.0),
      ),
      svg_path.Line(
        start: svg_path.Point(0.0, 10.0),
        end: svg_path.Point(10.0, 0.0),
      ),
    ])

  let assert Ok([intersection]) =
    intersections.path_self(
      svg_path.Path([
        subpath,
      ]),
    )
  let svg_path.PathSelfIntersection(point:, parameters:) = intersection
  let #(first, second) = parameters
  let svg_path.PathParameter(subpath_index: first_subpath, at: first_at) = first
  let svg_path.PathParameter(subpath_index: second_subpath, at: second_at) =
    second
  let svg_path.SubpathParameter(segment_index: first_segment, t: first_t) =
    first_at
  let svg_path.SubpathParameter(segment_index: second_segment, t: second_t) =
    second_at

  assert point_near(point, svg_path.Point(5.0, 5.0))
  assert first_subpath == 0
  assert first_segment == 0
  assert near(first_t, 0.5)
  assert second_subpath == 0
  assert second_segment == 2
  assert near(second_t, 0.5)
}

pub fn path_self_intersections_rejects_invalid_options_test() {
  let assert Error(svg_path.InvalidSelfIntersectionMinimumArcLengthSeparation(
    0.0,
  )) =
    intersections.path_self_with(
      svg_path.Path([]),
      options: svg_path.SelfIntersectionOptions(
        minimum_arc_length_separation: 0.0,
        distance_tolerance: 0.000001,
      ),
    )
}

fn point_near(a: svg_path.Point, b: svg_path.Point) -> Bool {
  near(a.x, b.x) && near(a.y, b.y)
}

fn list_contains_point(
  intersections: List(svg_path.SubpathSelfIntersection),
  point: svg_path.Point,
) -> Bool {
  list.any(intersections, fn(intersection) {
    let svg_path.SubpathSelfIntersection(point: intersection_point, ..) =
      intersection
    point_near(intersection_point, point)
  })
}

fn near(a: Float, b: Float) -> Bool {
  float_absolute_value(a -. b) <=. tolerance
}

fn float_absolute_value(value: Float) -> Float {
  case value <. 0.0 {
    True -> 0.0 -. value
    False -> value
  }
}

fn assert_ok(result: Result(a, b)) -> a {
  let assert Ok(value) = result
  value
}
