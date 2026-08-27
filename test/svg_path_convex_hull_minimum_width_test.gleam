import gleam/float
import gleam/list
import gleam/option.{None, Some}
import svg_path
import svg_path/convex_hull
import svg_path/degeneracy
import svg_path/point

const tolerance = 0.000000001

pub fn point_and_line_polygons_have_zero_width_test() {
  assert width([svg_path.Point(3.0, 4.0)]) == 0.0
  assert near(
    width([
      svg_path.Point(-2.0, 1.0),
      svg_path.Point(5.0, 4.0),
    ]),
    0.0,
  )
}

pub fn rectangle_width_is_its_shorter_side_test() {
  assert near(
    width([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(7.0, 0.0),
      svg_path.Point(7.0, 2.0),
      svg_path.Point(0.0, 2.0),
    ]),
    2.0,
  )
}

pub fn rotated_rectangle_width_is_its_shorter_side_test() {
  let assert Ok(expected) = float.square_root(2.0)
  let vertices = [
    svg_path.Point(0.0, 0.0),
    svg_path.Point(4.0, 4.0),
    svg_path.Point(3.0, 5.0),
    svg_path.Point(-1.0, 1.0),
  ]
  assert near(width(vertices), expected)
}

pub fn triangle_width_is_its_shortest_altitude_test() {
  assert near(
    width([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(4.0, 0.0),
      svg_path.Point(0.0, 3.0),
    ]),
    2.4,
  )
}

pub fn width_tolerates_duplicates_and_traversal_changes_test() {
  let base = [
    svg_path.Point(0.0, 0.0),
    svg_path.Point(6.0, 0.0),
    svg_path.Point(6.0, 2.0),
    svg_path.Point(0.0, 2.0),
  ]
  let shifted = [
    svg_path.Point(16.0, -1.0),
    svg_path.Point(16.0, 1.0),
    svg_path.Point(10.0, 1.0),
    svg_path.Point(10.0, -1.0),
    svg_path.Point(10.0, -1.0),
    svg_path.Point(16.0, -1.0),
  ]
  assert near(width(base), width(shifted))
  assert near(width(base), width(list.reverse(base)))
}

pub fn five_way_search_accepts_a_rotated_thin_rectangle_test() {
  let vertices =
    rectangle_at_angle(
      center: svg_path.Point(3.0, -2.0),
      length: 12.0,
      width: 0.4,
      angle: 31.7,
    )
  assert_fits(vertices, tolerance: 0.401, max_depth: 5)
}

pub fn five_way_search_finds_a_minimum_across_the_angle_seam_test() {
  let vertices =
    rectangle_at_angle(
      center: svg_path.Point(-5.0, 8.0),
      length: 9.0,
      width: 0.3,
      angle: 89.3,
    )
  assert_fits(vertices, tolerance: 0.301, max_depth: 6)
}

pub fn five_way_search_rejects_from_the_support_inventory_test() {
  let vertices =
    rectangle_at_angle(
      center: svg_path.Point(0.0, 0.0),
      length: 8.0,
      width: 1.5,
      angle: 19.0,
    )
  assert_exceeds(vertices, tolerance: 1.49, max_depth: 5)
}

pub fn five_way_search_handles_an_irregular_convex_polygon_test() {
  let vertices = [
    svg_path.Point(-4.0, -1.0),
    svg_path.Point(-1.0, -3.0),
    svg_path.Point(4.0, -2.0),
    svg_path.Point(6.0, 1.0),
    svg_path.Point(2.0, 4.0),
    svg_path.Point(-3.0, 3.0),
  ]
  let exact = width(vertices)
  assert_fits(vertices, tolerance: exact +. 0.01, max_depth: 6)
  assert_exceeds(vertices, tolerance: exact -. 0.01, max_depth: 6)
}

pub fn five_way_search_does_not_guess_at_the_exact_threshold_test() {
  let vertices =
    rectangle_at_angle(
      center: svg_path.Point(0.0, 0.0),
      length: 7.0,
      width: 2.0,
      angle: 13.0,
    )
  let decision =
    convex_hull.internal_convex_polygon_minimum_width_decision(
      vertices,
      tolerance: width(vertices),
      max_depth: 3,
    )
  let assert convex_hull.MinimumWidthUnresolved(..) = decision
}

pub fn five_way_decisions_are_translation_and_reversal_invariant_test() {
  let base =
    rectangle_at_angle(
      center: svg_path.Point(0.0, 0.0),
      length: 10.0,
      width: 0.75,
      angle: 47.0,
    )
  let translated =
    base
    |> list.map(fn(vertex) {
      svg_path.Point(vertex.x +. 120.0, vertex.y -. 90.0)
    })
    |> list.reverse
  assert_fits(base, tolerance: 0.751, max_depth: 6)
  assert_fits(translated, tolerance: 0.751, max_depth: 6)
  assert_exceeds(base, tolerance: 0.749, max_depth: 6)
  assert_exceeds(translated, tolerance: 0.749, max_depth: 6)
}

pub fn curved_circle_hull_uses_exact_directional_support_test() {
  let circle = circle_subpath(radius: 2.0)
  let assert Ok(hull) = convex_hull.subpath_hull(circle)
  let assert Ok(fits) =
    convex_hull.internal_convex_subpath_minimum_width_decision(
      hull,
      tolerance: 4.001,
    )
  let assert convex_hull.MinimumWidthFits(strip:) = fits
  assert near(strip.width, 4.0)

  let assert Ok(exceeds) =
    convex_hull.internal_convex_subpath_minimum_width_decision(
      hull,
      tolerance: 3.999,
    )
  let assert convex_hull.MinimumWidthExceeds(lower_bound:) = exceeds
  assert lower_bound >. 3.999
}

pub fn curved_hull_search_certifies_an_arbitrary_line_at_graph_tolerance_test() {
  let end = point.direction(degrees: 31.7) |> point.scale(by: 10.0)
  let segment = svg_path.Line(start: svg_path.Point(0.0, 0.0), end:)
  let assert Ok(hull) = convex_hull.segment_hull(segment)
  let assert Ok(decision) =
    convex_hull.internal_convex_subpath_minimum_width_decision(
      hull,
      tolerance: 0.000000001,
    )
  let assert convex_hull.MinimumWidthFits(strip:) = decision
  assert strip.width <=. 0.000000001
}

pub fn adding_a_segment_returns_the_augmented_hull_and_width_decision_test() {
  let first = line(0.0, 0.0, 1.0, 0.0)
  let second = line(1.0, 0.0, 2.0, 0.0)
  let third = line(2.0, 0.0, 2.0, 2.0)
  let assert Ok(first_hull) = convex_hull.segment_hull(first)
  let assert Ok(#(second_hull, second_decision)) =
    convex_hull.internal_convex_subpath_add_segment_and_test_width(
      first_hull,
      second,
      tolerance: 0.01,
    )
  let assert convex_hull.MinimumWidthFits(second_strip) = second_decision
  assert second_strip.width <=. 0.01

  let assert Ok(#(_, third_decision)) =
    convex_hull.internal_convex_subpath_add_segment_and_test_width(
      second_hull,
      third,
      tolerance: 0.01,
    )
  let assert convex_hull.MinimumWidthExceeds(..) = third_decision
}

pub fn public_minimum_width_finds_rotated_rectangle_thickness_test() {
  let vertices =
    rectangle_at_angle(
      center: svg_path.Point(3.0, -2.0),
      length: 12.0,
      width: 0.4,
      angle: 31.7,
    )
  let subpath = polygon_subpath(vertices)
  let assert Ok(extremum) =
    convex_hull.subpath_minimum_width_with(
      subpath,
      options: convex_hull.WidthSearchOptions(accuracy: 0.000001, max_depth: 12),
    )
  let convex_hull.WidthExtremum(
    width:,
    lower_bound:,
    upper_bound:,
    converged:,
    ..,
  ) = extremum
  assert converged
  assert float.absolute_value(width -. 0.4) <=. 0.000001
  assert lower_bound <=. 0.4
  assert upper_bound >=. 0.4
  assert upper_bound -. lower_bound <=. 0.0000011
}

pub fn public_diameter_returns_witness_pair_and_midpoint_test() {
  let subpath =
    polygon_subpath([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(3.0, 4.0),
      svg_path.Point(0.0, 1.0),
    ])
  let assert Ok(extremum) =
    convex_hull.subpath_diameter_with(
      subpath,
      options: convex_hull.WidthSearchOptions(accuracy: 0.000001, max_depth: 12),
    )
  let convex_hull.WidthExtremum(
    lower_point:,
    upper_point:,
    center:,
    width:,
    lower_bound:,
    upper_bound:,
    converged:,
    ..,
  ) = extremum
  assert converged
  assert float.absolute_value(width -. 5.0) <=. 0.000001
  assert float.absolute_value(point.distance(lower_point, upper_point) -. 5.0)
    <=. 0.000001
  assert point.distance(center, svg_path.Point(1.5, 2.0)) <=. 0.000001
  assert lower_bound <=. 5.0
  assert upper_bound >=. 5.0
  assert upper_bound -. lower_bound <=. 0.0000011
}

pub fn path_diameter_uses_direct_support_across_move_only_subpaths_test() {
  let path =
    svg_path.Path([
      svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)),
      svg_path.subpath_empty(at: svg_path.Point(3.0, 4.0)),
    ])
  let assert Ok(extremum) = convex_hull.path_diameter(path)
  let convex_hull.WidthExtremum(
    lower_point:,
    upper_point:,
    width:,
    converged:,
    ..,
  ) = extremum
  assert converged
  assert float.absolute_value(width -. 5.0) <=. tolerance
  assert float.absolute_value(point.distance(lower_point, upper_point) -. 5.0)
    <=. tolerance
}

pub fn width_extremum_reports_depth_limit_before_convergence_test() {
  let subpath =
    rectangle_at_angle(
      center: svg_path.Point(0.0, 0.0),
      length: 7.0,
      width: 2.0,
      angle: 13.0,
    )
    |> polygon_subpath
  let assert Ok(extremum) =
    convex_hull.subpath_minimum_width_with(
      subpath,
      options: convex_hull.WidthSearchOptions(accuracy: 0.0, max_depth: 0),
    )
  let convex_hull.WidthExtremum(converged:, lower_bound:, upper_bound:, ..) =
    extremum
  assert !converged
  assert lower_bound <. upper_bound
}

pub fn longest_thin_prefix_stops_before_the_first_wide_addition_test() {
  let first = line(0.0, 0.0, 1.0, 0.0)
  let second = line(1.0, 0.0, 2.0, 0.0)
  let third = line(2.0, 0.0, 2.0, 2.0)
  let fourth = line(2.0, 2.0, 3.0, 2.0)
  let subpath = svg_path.subpath_assert([first, second, third, fourth])
  let assert Ok(prefix) =
    degeneracy.internal_longest_thin_prefix(subpath, tolerance: 0.01)
  let degeneracy.ThinPrefix(segments:, remaining:, hull:, strip:) = prefix
  assert segments == [first, second]
  assert remaining == [third, fourth]
  let assert Some(_) = hull
  let assert Some(accepted_strip) = strip
  assert accepted_strip.width <=. 0.01
}

pub fn longest_thin_prefix_can_be_empty_test() {
  let first =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.0),
      control: svg_path.Point(0.5, 1.0),
      end: svg_path.Point(1.0, 0.0),
    )
  let subpath = svg_path.subpath_assert([first])
  let assert Ok(prefix) =
    degeneracy.internal_longest_thin_prefix(subpath, tolerance: 0.1)
  let degeneracy.ThinPrefix(segments:, remaining:, hull:, strip:) = prefix
  assert segments == []
  assert remaining == [first]
  assert hull == None
  assert strip == None
}

fn width(vertices: List(svg_path.Point)) -> Float {
  let convex_hull.MinimumWidthStrip(width:, ..) =
    convex_hull.internal_convex_polygon_minimum_width_strip(vertices)
  width
}

fn near(left: Float, right: Float) -> Bool {
  float.absolute_value(left -. right) <=. tolerance
}

fn assert_fits(
  vertices: List(svg_path.Point),
  tolerance tolerance: Float,
  max_depth max_depth: Int,
) -> Nil {
  let exact = width(vertices)
  let decision =
    convex_hull.internal_convex_polygon_minimum_width_decision(
      vertices,
      tolerance:,
      max_depth:,
    )
  let assert convex_hull.MinimumWidthFits(strip:) = decision
  assert exact <=. tolerance
  assert strip.width <=. tolerance
}

fn assert_exceeds(
  vertices: List(svg_path.Point),
  tolerance tolerance: Float,
  max_depth max_depth: Int,
) -> Nil {
  let exact = width(vertices)
  let decision =
    convex_hull.internal_convex_polygon_minimum_width_decision(
      vertices,
      tolerance:,
      max_depth:,
    )
  let assert convex_hull.MinimumWidthExceeds(lower_bound:) = decision
  assert exact >. tolerance
  assert lower_bound >. tolerance
}

fn rectangle_at_angle(
  center center: svg_path.Point,
  length length: Float,
  width width: Float,
  angle angle: Float,
) -> List(svg_path.Point) {
  let along = point.direction(degrees: angle) |> point.scale(by: length /. 2.0)
  let across =
    point.rotate_counterclockwise(along)
    |> point.normalize
    |> fn(result) {
      let assert Ok(direction) = result
      point.scale(direction, by: width /. 2.0)
    }
  [
    add(
      add(center, point.scale(along, by: -1.0)),
      point.scale(across, by: -1.0),
    ),
    add(add(center, along), point.scale(across, by: -1.0)),
    add(add(center, along), across),
    add(add(center, point.scale(along, by: -1.0)), across),
  ]
}

fn polygon_subpath(vertices: List(svg_path.Point)) -> svg_path.Subpath {
  let assert [first, ..rest] = vertices
  let segments = case rest {
    [] -> []
    [second, ..remaining] ->
      polygon_segments(first, second, remaining, [
        svg_path.Line(start: first, end: second),
      ])
  }
  svg_path.subpath_assert_set_closed(
    svg_path.subpath_assert(segments),
    closed: True,
  )
}

fn polygon_segments(
  first: svg_path.Point,
  previous: svg_path.Point,
  remaining: List(svg_path.Point),
  reversed: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case remaining {
    [] -> list.reverse([svg_path.Line(start: previous, end: first), ..reversed])
    [next, ..rest] ->
      polygon_segments(first, next, rest, [
        svg_path.Line(start: previous, end: next),
        ..reversed
      ])
  }
}

fn add(left: svg_path.Point, right: svg_path.Point) -> svg_path.Point {
  svg_path.Point(left.x +. right.x, left.y +. right.y)
}

fn line(
  start_x: Float,
  start_y: Float,
  end_x: Float,
  end_y: Float,
) -> svg_path.Segment {
  svg_path.Line(
    start: svg_path.Point(start_x, start_y),
    end: svg_path.Point(end_x, end_y),
  )
}

fn circle_subpath(radius radius: Float) -> svg_path.Subpath {
  let right = svg_path.Point(radius, 0.0)
  let left = svg_path.Point(0.0 -. radius, 0.0)
  svg_path.subpath_assert_set_closed(
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
    ]),
    closed: True,
  )
}
