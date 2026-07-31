import gleam/float
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleeunit/should
import svg_path
import svg_path/area
import svg_path/planar_graph

const tolerance = 0.000001

const minimum_chord = 0.00001

type IntersectionAdapterCase {
  IntersectionAdapterCase(
    left: svg_path.Path,
    right: svg_path.Path,
    fill_rule: svg_path.FillRule,
    samples: List(svg_path.Point),
    expected_area: Option(Float),
    expected_subpaths: Option(Int),
  )
}

pub fn overlapping_rectangles_match_legacy_union_geometry_test() {
  let left = rectangle(0.0, 0.0, 2.0, 2.0)
  let right = rectangle(1.0, 0.0, 3.0, 2.0)
  let assert Ok(union) = graph_union(left, right)

  assert_area(union, 6.0)
  list.length(svg_path.path_subpaths(union)) |> should.equal(1)
}

pub fn adjacent_rectangles_drop_legacy_shared_edge_slit_test() {
  let left = rectangle(0.0, 0.0, 1.0, 1.0)
  let right = rectangle(1.0, 0.0, 2.0, 1.0)
  let assert Ok(union) = graph_union(left, right)

  assert_area(union, 2.0)
  list.length(svg_path.path_subpaths(union)) |> should.equal(1)
  union
  |> svg_path.path_subpaths
  |> list.flat_map(svg_path.subpath_segments)
  |> list.length
  |> should.equal(6)
}

pub fn reversed_coincident_operands_remain_filled_test() {
  let left = rectangle(0.0, 0.0, 2.0, 2.0)
  let right = svg_path.path_reverse(left)
  let assert Ok(union) = graph_union(left, right)

  assert_area(union, 4.0)
  assert_containment(union, svg_path.Point(1.0, 1.0), svg_path.Inside)
  list.length(svg_path.path_subpaths(union)) |> should.equal(1)
}

pub fn three_coincident_contributors_emit_one_boolean_boundary_test() {
  let contour = rectangle_subpath(0.0, 0.0, 2.0, 2.0)
  let input = svg_path.Path([contour, contour, contour])
  let assert Ok(union) = graph_union(input, svg_path.path_empty())

  assert_area(union, 4.0)
  list.length(svg_path.path_subpaths(union)) |> should.equal(1)
}

pub fn decreasing_concentric_winding_emits_outer_boundary_and_hole_test() {
  let input =
    svg_path.Path([
      circle_subpath(40.0),
      circle_subpath(30.0),
      circle_subpath(20.0) |> svg_path.subpath_reverse,
      circle_subpath(10.0) |> svg_path.subpath_reverse,
    ])
  let assert Ok(union) = graph_union(input, svg_path.path_empty())

  list.length(svg_path.path_subpaths(union)) |> should.equal(2)
  assert_containment(union, svg_path.Point(0.0, 0.0), svg_path.Outside)
  assert_containment(union, svg_path.Point(15.0, 0.0), svg_path.Inside)
  assert_containment(union, svg_path.Point(25.0, 0.0), svg_path.Inside)
  assert_containment(union, svg_path.Point(35.0, 0.0), svg_path.Inside)
}

pub fn disjoint_rectangles_return_two_components_test() {
  let left = rectangle(0.0, 0.0, 10.0, 10.0)
  let right = rectangle(20.0, 0.0, 30.0, 10.0)
  let assert Ok(union) = graph_union(left, right)

  assert_area(union, 200.0)
  list.length(svg_path.path_subpaths(union)) |> should.equal(2)
}

pub fn offset_adjacent_rectangles_stitch_canonical_boundary_test() {
  let left = rectangle(0.0, 0.0, 1.0, 1.0)
  let right = rectangle(1.0, 0.5, 2.0, 1.5)
  let assert Ok(union) = graph_union(left, right)

  assert_area(union, 2.0)
  list.length(svg_path.path_subpaths(union)) |> should.equal(1)
  assert_containment(union, svg_path.Point(0.5, 0.5), svg_path.Inside)
  assert_containment(union, svg_path.Point(1.5, 1.0), svg_path.Inside)
  assert_containment(union, svg_path.Point(1.5, 0.25), svg_path.Outside)
}

pub fn four_square_union_matches_legacy_boolean_semantics_test() {
  let paths = [
    rectangle(0.0, 0.0, 2.0, 2.0),
    rectangle(2.0, 1.0, 4.0, 3.0),
    rectangle(1.0, 3.0, 3.0, 5.0),
    rectangle(-1.0, 2.0, 1.0, 4.0),
  ]
  let assert [first, ..rest] = paths
  let assert Ok(union) = graph_union_list(rest, first)

  assert_area(union, 16.0)
  assert_containment(union, svg_path.Point(1.0, 1.0), svg_path.Inside)
  assert_containment(union, svg_path.Point(3.0, 2.0), svg_path.Inside)
  assert_containment(union, svg_path.Point(2.0, 4.0), svg_path.Inside)
  assert_containment(union, svg_path.Point(0.0, 3.0), svg_path.Inside)
}

pub fn circle_rectangle_union_preserves_arc_and_line_edges_test() {
  let circle = svg_path.path_from_subpath(circle_subpath(10.0))
  let rectangle = rectangle(0.0, -5.0, 15.0, 5.0)
  let assert Ok(union) = graph_union(circle, rectangle)

  list.length(svg_path.path_subpaths(union)) |> should.equal(1)
  assert_containment(union, svg_path.Point(-7.0, 0.0), svg_path.Inside)
  assert_containment(union, svg_path.Point(13.0, 0.0), svg_path.Inside)
  assert_containment(union, svg_path.Point(0.0, 11.0), svg_path.Outside)
  assert has_arc(union)
  assert has_line(union)
}

pub fn quadratic_loop_rectangle_union_preserves_quadratics_and_lines_test() {
  let loop = svg_path.path_from_subpath(quadratic_loop())
  let rectangle = rectangle(5.0, -4.0, 14.0, 4.0)
  let assert Ok(union) = graph_union(loop, rectangle)

  list.length(svg_path.path_subpaths(union)) |> should.equal(1)
  assert_containment(union, svg_path.Point(0.0, 0.0), svg_path.Inside)
  assert_containment(union, svg_path.Point(12.0, 0.0), svg_path.Inside)
  assert_containment(union, svg_path.Point(0.0, 12.0), svg_path.Outside)
  assert has_quadratic(union)
  assert has_line(union)
}

pub fn cubic_loop_rectangle_union_preserves_cubics_and_lines_test() {
  let loop = svg_path.path_from_subpath(cubic_loop())
  let rectangle = rectangle(-14.0, -4.0, -5.0, 4.0)
  let assert Ok(union) = graph_union(loop, rectangle)

  list.length(svg_path.path_subpaths(union)) |> should.equal(1)
  assert_containment(union, svg_path.Point(0.0, 0.0), svg_path.Inside)
  assert_containment(union, svg_path.Point(-12.0, 0.0), svg_path.Inside)
  assert_containment(union, svg_path.Point(0.0, 12.0), svg_path.Outside)
  assert has_cubic(union)
  assert has_line(union)
}

pub fn overlapping_rectangles_intersection_matches_legacy_geometry_test() {
  let left = rectangle(0.0, 0.0, 10.0, 10.0)
  let right = rectangle(5.0, 0.0, 15.0, 10.0)
  let assert Ok(intersection) =
    graph_intersection(left, right, svg_path.Nonzero)

  assert_area(intersection, 50.0)
  list.length(svg_path.path_subpaths(intersection)) |> should.equal(1)
  assert_containment(intersection, svg_path.Point(2.5, 5.0), svg_path.Outside)
  assert_containment(intersection, svg_path.Point(7.5, 5.0), svg_path.Inside)
  assert_containment(intersection, svg_path.Point(12.5, 5.0), svg_path.Outside)
}

pub fn disjoint_and_tangent_intersections_are_empty_test() {
  let left = rectangle(0.0, 0.0, 10.0, 10.0)
  let disjoint = rectangle(20.0, 0.0, 30.0, 10.0)
  let edge_tangent = rectangle(10.0, 0.0, 20.0, 10.0)
  let point_tangent = rectangle(10.0, 10.0, 20.0, 20.0)
  let assert Ok(disjoint_result) =
    graph_intersection(left, disjoint, svg_path.Nonzero)
  let assert Ok(edge_result) =
    graph_intersection(left, edge_tangent, svg_path.Nonzero)
  let assert Ok(point_result) =
    graph_intersection(left, point_tangent, svg_path.Nonzero)

  list.length(svg_path.path_subpaths(disjoint_result)) |> should.equal(0)
  list.length(svg_path.path_subpaths(edge_result)) |> should.equal(0)
  list.length(svg_path.path_subpaths(point_result)) |> should.equal(0)
}

pub fn identical_rectangles_intersection_keeps_one_boundary_test() {
  let rectangle = rectangle(0.0, 0.0, 10.0, 10.0)
  let assert Ok(intersection) =
    graph_intersection(rectangle, rectangle, svg_path.Nonzero)

  assert_area(intersection, 100.0)
  list.length(svg_path.path_subpaths(intersection)) |> should.equal(1)
}

pub fn circle_rectangle_intersection_preserves_arc_and_line_edges_test() {
  let circle =
    svg_path.path_from_subpath(circle_subpath_at(
      svg_path.Point(10.0, 10.0),
      10.0,
    ))
  let rectangle = rectangle(5.0, 0.0, 20.0, 20.0)
  let assert Ok(intersection) =
    graph_intersection(circle, rectangle, svg_path.Nonzero)

  list.length(svg_path.path_subpaths(intersection)) |> should.equal(1)
  assert_containment(intersection, svg_path.Point(12.5, 10.0), svg_path.Inside)
  assert_containment(intersection, svg_path.Point(2.5, 10.0), svg_path.Outside)
  assert has_arc(intersection)
  assert has_line(intersection)
}

pub fn intersection_applies_nonzero_and_evenodd_fill_rules_test() {
  let nested =
    svg_path.Path([
      rectangle_subpath(0.0, 0.0, 20.0, 20.0),
      rectangle_subpath(5.0, 5.0, 15.0, 15.0),
    ])
  let probe = rectangle(7.0, 7.0, 13.0, 13.0)
  let assert Ok(nonzero) = graph_intersection(nested, probe, svg_path.Nonzero)
  let assert Ok(even_odd) = graph_intersection(nested, probe, svg_path.EvenOdd)

  assert_area(nonzero, 36.0)
  list.length(svg_path.path_subpaths(even_odd)) |> should.equal(0)
}

pub fn intersection_adapter_runs_old_semantic_matrix_test() {
  assert_intersection_adapter_cases([
    adapter_case(
      rectangle(0.0, 0.0, 10.0, 10.0),
      rectangle(5.0, 0.0, 15.0, 10.0),
      svg_path.Nonzero,
      grid([2.5, 7.5, 12.5, 20.0], [-2.5, 5.0, 12.5]),
    ),
    adapter_case(
      svg_path.path_from_subpath(circle_subpath_at(
        svg_path.Point(10.0, 10.0),
        10.0,
      )),
      rectangle(5.0, 0.0, 20.0, 20.0),
      svg_path.Nonzero,
      grid([2.5, 7.5, 12.5, 17.5, 22.5], [2.5, 7.5, 12.5, 17.5]),
    ),
    adapter_case(
      nested_rectangles(),
      rectangle(7.0, 7.0, 13.0, 13.0),
      svg_path.Nonzero,
      grid([2.5, 7.5, 10.0, 12.5, 17.5], [2.5, 7.5, 10.0, 12.5, 17.5]),
    ),
    adapter_case(
      nested_rectangles(),
      rectangle(7.0, 7.0, 13.0, 13.0),
      svg_path.EvenOdd,
      grid([2.5, 7.5, 10.0, 12.5, 17.5], [2.5, 7.5, 10.0, 12.5, 17.5]),
    ),
    adapter_case(
      svg_path.path_from_subpath(circle_subpath_at(
        svg_path.Point(50.0, 60.0),
        40.0,
      )),
      rectangle(90.0, 20.0, 124.0, 100.0),
      svg_path.Nonzero,
      grid([12.5, 50.0, 88.0, 92.0, 110.0], [30.0, 60.0, 90.0]),
    ),
    adapter_case(
      bowtie(),
      rectangle(36.0, 28.0, 86.0, 92.0),
      svg_path.Nonzero,
      grid([16.0, 44.0, 62.0, 78.0, 100.0], [
        16.0,
        40.0,
        60.0,
        84.0,
        104.0,
      ]),
    ),
  ])
}

pub fn intersection_adapter_runs_old_operation_table_test() {
  assert_intersection_adapter_cases([
    adapter_case_with_expectation(
      rectangle(0.0, 0.0, 10.0, 10.0),
      rectangle(5.0, 0.0, 15.0, 10.0),
      svg_path.Nonzero,
      [
        svg_path.Point(2.5, 5.0),
        svg_path.Point(7.5, 5.0),
        svg_path.Point(12.5, 5.0),
      ],
      50.0,
      None,
    ),
    adapter_case_with_expectation(
      rectangle(0.0, 0.0, 10.0, 10.0),
      rectangle(20.0, 0.0, 30.0, 10.0),
      svg_path.Nonzero,
      [svg_path.Point(5.0, 5.0), svg_path.Point(25.0, 5.0)],
      0.0,
      Some(0),
    ),
    adapter_case_with_expectation(
      rectangle(0.0, 0.0, 10.0, 10.0),
      rectangle(0.0, 0.0, 10.0, 10.0),
      svg_path.Nonzero,
      [svg_path.Point(5.0, 5.0)],
      100.0,
      None,
    ),
    adapter_case_with_expectation(
      rectangle(0.0, 0.0, 10.0, 10.0),
      rectangle(10.0, 0.0, 20.0, 10.0),
      svg_path.Nonzero,
      [svg_path.Point(5.0, 5.0), svg_path.Point(15.0, 5.0)],
      0.0,
      None,
    ),
  ])
}

fn graph_union(
  left: svg_path.Path,
  right: svg_path.Path,
) -> Result(svg_path.Path, planar_graph.Error) {
  planar_graph.union_paths(
    left,
    right,
    using: svg_path.Nonzero,
    tolerance:,
    minimum_chord:,
  )
}

fn graph_intersection(
  left: svg_path.Path,
  right: svg_path.Path,
  fill_rule: svg_path.FillRule,
) -> Result(svg_path.Path, planar_graph.Error) {
  planar_graph.intersection_paths(
    left,
    right,
    using: fill_rule,
    tolerance:,
    minimum_chord:,
  )
}

fn adapter_case(
  left: svg_path.Path,
  right: svg_path.Path,
  fill_rule: svg_path.FillRule,
  samples: List(svg_path.Point),
) -> IntersectionAdapterCase {
  IntersectionAdapterCase(
    left:,
    right:,
    fill_rule:,
    samples:,
    expected_area: None,
    expected_subpaths: None,
  )
}

fn adapter_case_with_expectation(
  left: svg_path.Path,
  right: svg_path.Path,
  fill_rule: svg_path.FillRule,
  samples: List(svg_path.Point),
  expected_area: Float,
  expected_subpaths: Option(Int),
) -> IntersectionAdapterCase {
  IntersectionAdapterCase(
    left:,
    right:,
    fill_rule:,
    samples:,
    expected_area: Some(expected_area),
    expected_subpaths:,
  )
}

fn assert_intersection_adapter_cases(
  cases: List(IntersectionAdapterCase),
) -> Nil {
  cases |> list.each(assert_intersection_adapter_case)
}

fn assert_intersection_adapter_case(
  adapter_case: IntersectionAdapterCase,
) -> Nil {
  let IntersectionAdapterCase(
    left:,
    right:,
    fill_rule:,
    samples:,
    expected_area:,
    expected_subpaths:,
  ) = adapter_case
  let assert Ok(forward) = graph_intersection(left, right, fill_rule)
  let assert Ok(reverse) = graph_intersection(right, left, fill_rule)

  [forward, reverse]
  |> list.each(fn(intersection) {
    case expected_area {
      Some(expected) -> assert_area(intersection, expected)
      None -> Nil
    }
    case expected_subpaths {
      Some(expected) ->
        list.length(svg_path.path_subpaths(intersection))
        |> should.equal(expected)
      None -> Nil
    }
    samples
    |> list.each(fn(point) {
      let assert Ok(left_containment) =
        svg_path.path_containment(point, within: left, using: fill_rule)
      let assert Ok(right_containment) =
        svg_path.path_containment(point, within: right, using: fill_rule)
      let assert Ok(result_containment) =
        svg_path.path_containment(point, within: intersection, using: fill_rule)
      assert containment_is_inside(result_containment)
        == {
          containment_is_inside(left_containment)
          && containment_is_inside(right_containment)
        }
    })
  })
}

fn containment_is_inside(containment: svg_path.PointContainment) -> Bool {
  containment == svg_path.Inside
}

fn graph_union_list(
  paths: List(svg_path.Path),
  accumulated: svg_path.Path,
) -> Result(svg_path.Path, planar_graph.Error) {
  case paths {
    [] -> Ok(accumulated)
    [first, ..rest] -> {
      use next <- result.try(graph_union(accumulated, first))
      graph_union_list(rest, next)
    }
  }
}

fn rectangle(
  left: Float,
  top: Float,
  right: Float,
  bottom: Float,
) -> svg_path.Path {
  svg_path.path_from_subpath(rectangle_subpath(left, top, right, bottom))
}

fn rectangle_subpath(
  left: Float,
  top: Float,
  right: Float,
  bottom: Float,
) -> svg_path.Subpath {
  svg_path.subpath_assert_polygon([
    svg_path.Point(left, top),
    svg_path.Point(right, top),
    svg_path.Point(right, bottom),
    svg_path.Point(left, bottom),
  ])
}

fn nested_rectangles() -> svg_path.Path {
  svg_path.Path([
    rectangle_subpath(0.0, 0.0, 20.0, 20.0),
    rectangle_subpath(5.0, 5.0, 15.0, 15.0),
  ])
}

fn bowtie() -> svg_path.Path {
  svg_path.path_from_subpath(
    svg_path.subpath_assert_polygon([
      svg_path.Point(8.0, 8.0),
      svg_path.Point(114.0, 112.0),
      svg_path.Point(114.0, 8.0),
      svg_path.Point(8.0, 112.0),
    ]),
  )
}

fn grid(xs: List(Float), ys: List(Float)) -> List(svg_path.Point) {
  xs
  |> list.flat_map(fn(x) { ys |> list.map(fn(y) { svg_path.Point(x, y) }) })
}

fn circle_subpath(radius: Float) -> svg_path.Subpath {
  circle_subpath_at(svg_path.Point(0.0, 0.0), radius)
}

fn circle_subpath_at(
  center: svg_path.Point,
  radius: Float,
) -> svg_path.Subpath {
  let left = svg_path.Point(center.x -. radius, center.y)
  let right = svg_path.Point(center.x +. radius, center.y)
  svg_path.subpath_assert([
    svg_path.Arc(
      start: right,
      radius: svg_path.Point(radius, radius),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: left,
    ),
    svg_path.Arc(
      start: left,
      radius: svg_path.Point(radius, radius),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: right,
    ),
  ])
  |> svg_path.subpath_assert_set_closed(closed: True)
}

fn quadratic_loop() -> svg_path.Subpath {
  let left = svg_path.Point(-10.0, 0.0)
  let top = svg_path.Point(0.0, -10.0)
  let right = svg_path.Point(10.0, 0.0)
  let bottom = svg_path.Point(0.0, 10.0)
  svg_path.subpath_assert([
    svg_path.QuadraticBezier(
      start: left,
      control: svg_path.Point(-10.0, -10.0),
      end: top,
    ),
    svg_path.QuadraticBezier(
      start: top,
      control: svg_path.Point(10.0, -10.0),
      end: right,
    ),
    svg_path.QuadraticBezier(
      start: right,
      control: svg_path.Point(10.0, 10.0),
      end: bottom,
    ),
    svg_path.QuadraticBezier(
      start: bottom,
      control: svg_path.Point(-10.0, 10.0),
      end: left,
    ),
  ])
  |> svg_path.subpath_assert_set_closed(closed: True)
}

fn cubic_loop() -> svg_path.Subpath {
  let radius = 10.0
  let handle = 5.522847498307936
  let left = svg_path.Point(0.0 -. radius, 0.0)
  let top = svg_path.Point(0.0, 0.0 -. radius)
  let right = svg_path.Point(radius, 0.0)
  let bottom = svg_path.Point(0.0, radius)
  svg_path.subpath_assert([
    svg_path.CubicBezier(
      start: left,
      control1: svg_path.Point(0.0 -. radius, 0.0 -. handle),
      control2: svg_path.Point(0.0 -. handle, 0.0 -. radius),
      end: top,
    ),
    svg_path.CubicBezier(
      start: top,
      control1: svg_path.Point(handle, 0.0 -. radius),
      control2: svg_path.Point(radius, 0.0 -. handle),
      end: right,
    ),
    svg_path.CubicBezier(
      start: right,
      control1: svg_path.Point(radius, handle),
      control2: svg_path.Point(handle, radius),
      end: bottom,
    ),
    svg_path.CubicBezier(
      start: bottom,
      control1: svg_path.Point(0.0 -. handle, radius),
      control2: svg_path.Point(0.0 -. radius, handle),
      end: left,
    ),
  ])
  |> svg_path.subpath_assert_set_closed(closed: True)
}

fn has_arc(path: svg_path.Path) -> Bool {
  path
  |> svg_path.path_subpaths
  |> list.flat_map(svg_path.subpath_segments)
  |> list.any(fn(segment) {
    case segment {
      svg_path.Arc(..) -> True
      _ -> False
    }
  })
}

fn has_quadratic(path: svg_path.Path) -> Bool {
  path
  |> svg_path.path_subpaths
  |> list.flat_map(svg_path.subpath_segments)
  |> list.any(fn(segment) {
    case segment {
      svg_path.QuadraticBezier(..) -> True
      _ -> False
    }
  })
}

fn has_cubic(path: svg_path.Path) -> Bool {
  path
  |> svg_path.path_subpaths
  |> list.flat_map(svg_path.subpath_segments)
  |> list.any(fn(segment) {
    case segment {
      svg_path.CubicBezier(..) -> True
      _ -> False
    }
  })
}

fn has_line(path: svg_path.Path) -> Bool {
  path
  |> svg_path.path_subpaths
  |> list.flat_map(svg_path.subpath_segments)
  |> list.any(fn(segment) {
    case segment {
      svg_path.Line(..) -> True
      _ -> False
    }
  })
}

fn assert_area(path: svg_path.Path, expected: Float) {
  let assert Ok(actual) = area.path(path, using: svg_path.Nonzero)
  let difference = float.absolute_value(actual -. expected)
  assert difference <=. tolerance
}

fn assert_containment(
  path: svg_path.Path,
  point: svg_path.Point,
  expected: svg_path.PointContainment,
) {
  svg_path.path_containment(point, within: path, using: svg_path.Nonzero)
  |> should.equal(Ok(expected))
}
