import gleam/float
import gleam/int
import gleam/list
import svg_path
import svg_path/area
import svg_path/overlaps
import svg_path/robust_union

const tolerance = 0.000001

pub fn segment_encounters_reports_line_overlap_with_reversed_right_test() {
  let left = line(0.0, 0.0, 10.0, 0.0)
  let right = line(7.0, 0.0, 3.0, 0.0)

  let assert Ok([encounter]) = overlaps.segment(left, right)
  let assert overlaps.Overlap(
    left_from:,
    left_to:,
    right_from:,
    right_to:,
    start:,
    end:,
  ) = encounter

  assert near(left_from, 0.3)
  assert near(left_to, 0.7)
  assert near(right_from, 1.0)
  assert near(right_to, 0.0)
  assert start == svg_path.Point(3.0, 0.0)
  assert end == svg_path.Point(7.0, 0.0)
}

pub fn segment_encounters_reports_crossing_point_test() {
  let horizontal = line(0.0, 0.0, 10.0, 0.0)
  let vertical = line(5.0, -5.0, 5.0, 5.0)

  let assert Ok([encounter]) = overlaps.segment(horizontal, vertical)
  let assert overlaps.Intersection(left_t:, right_t:, point:) = encounter

  assert near(left_t, 0.5)
  assert near(right_t, 0.5)
  assert point == svg_path.Point(5.0, 0.0)
}

pub fn node_segments_splits_at_crossing_without_mutating_inputs_test() {
  let horizontal = line(0.0, 0.0, 10.0, 0.0)
  let vertical = line(5.0, -5.0, 5.0, 5.0)

  let assert Ok(segments) = robust_union.node_segments([horizontal, vertical])

  assert list.length(segments) == 4
  assert contains_segment(segments, line(0.0, 0.0, 5.0, 0.0))
  assert contains_segment(segments, line(5.0, 0.0, 10.0, 0.0))
  assert contains_segment(segments, line(5.0, -5.0, 5.0, 0.0))
  assert contains_segment(segments, line(5.0, 0.0, 5.0, 5.0))
}

pub fn node_segments_canonicalizes_partial_overlap_as_two_copies_test() {
  let left = line(0.0, 0.0, 10.0, 0.0)
  let right = line(3.0, 0.0, 7.0, 0.0)

  let assert Ok(segments) = robust_union.node_segments([left, right])

  assert list.length(segments) == 4
  assert contains_segment(segments, line(0.0, 0.0, 3.0, 0.0))
  assert contains_segment(segments, line(7.0, 0.0, 10.0, 0.0))
  assert count_segment(segments, line(3.0, 0.0, 7.0, 0.0)) == 2
}

pub fn node_segments_canonicalizes_reversed_overlap_as_same_copies_test() {
  let left = line(0.0, 0.0, 10.0, 0.0)
  let right = line(7.0, 0.0, 3.0, 0.0)

  let assert Ok(segments) = robust_union.node_segments([left, right])

  assert list.length(segments) == 4
  assert contains_segment(segments, line(0.0, 0.0, 3.0, 0.0))
  assert contains_segment(segments, line(7.0, 0.0, 10.0, 0.0))
  assert count_segment(segments, line(3.0, 0.0, 7.0, 0.0)) == 2
}

pub fn node_segments_handles_overlap_and_crossing_together_test() {
  let base = line(0.0, 0.0, 10.0, 0.0)
  let overlap = line(2.0, 0.0, 8.0, 0.0)
  let crossing = line(5.0, -5.0, 5.0, 5.0)

  let assert Ok(segments) =
    robust_union.node_segments([base, overlap, crossing])

  assert list.length(segments) == 8
  assert count_segment(segments, line(2.0, 0.0, 5.0, 0.0)) == 2
  assert count_segment(segments, line(5.0, 0.0, 8.0, 0.0)) == 2
  assert contains_segment(segments, line(0.0, 0.0, 2.0, 0.0))
  assert contains_segment(segments, line(8.0, 0.0, 10.0, 0.0))
  assert contains_segment(segments, line(5.0, -5.0, 5.0, 0.0))
  assert contains_segment(segments, line(5.0, 0.0, 5.0, 5.0))
}

pub fn node_subpaths_uses_same_segment_engine_test() {
  let left =
    svg_path.subpath_assert([
      line(0.0, 0.0, 10.0, 0.0),
      line(10.0, 0.0, 10.0, 10.0),
    ])
  let right =
    svg_path.subpath_assert([
      line(3.0, 0.0, 7.0, 0.0),
      line(7.0, 0.0, 7.0, 4.0),
    ])

  let assert Ok(segments) = robust_union.node_subpaths(left, right)

  assert count_segment(segments, line(3.0, 0.0, 7.0, 0.0)) == 2
  assert contains_segment(segments, line(0.0, 0.0, 3.0, 0.0))
  assert contains_segment(segments, line(7.0, 0.0, 10.0, 0.0))
}

pub fn union_nonzero_paths_resolves_owned_overlap_occurrences_test() {
  let left = rectangle(0.0, 0.0, 2.0, 2.0)
  let right = rectangle(1.0, 0.0, 3.0, 2.0)

  let assert Ok(union) = robust_union.union_nonzero_paths(left, right)

  assert_area(union, 6.0)
  assert list.length(svg_path.path_subpaths(union)) == 2
  assert_winding_depth(union, svg_path.Point(1.5, 1.0), 2)
}

pub fn union_nonzero_paths_keeps_equal_level_shared_edge_slit_test() {
  let left = rectangle(0.0, 0.0, 1.0, 1.0)
  let right = rectangle(1.0, 0.0, 2.0, 1.0)

  let assert Ok(union) = robust_union.union_nonzero_paths(left, right)
  let subpaths = svg_path.path_subpaths(union)

  assert_area(union, 2.0)
  assert list.length(subpaths) == 2
  assert list.any(subpaths, fn(subpath) {
    let segments = svg_path.subpath_segments(subpath)
    list.length(segments) == 2
    && contains_segment(segments, line(1.0, 0.0, 1.0, 1.0))
    && contains_segment(segments, line(1.0, 1.0, 1.0, 0.0))
  })
}

pub fn union_nonzero_paths_preserves_reversed_coincident_levels_test() {
  let left = rectangle(0.0, 0.0, 2.0, 2.0)
  let right = left |> svg_path.path_reverse

  let assert Ok(union) = robust_union.union_nonzero_paths(left, right)

  assert_area(union, 4.0)
  assert_winding_depth(union, svg_path.Point(1.0, 1.0), 2)
}

pub fn union_nonzero_composes_three_coincident_contributors_test() {
  let contour = rectangle_subpath(0.0, 0.0, 2.0, 2.0)
  let input = svg_path.Path([contour, contour, contour])

  let assert Ok(union) = robust_union.union_nonzero(input)

  assert_area(union, 4.0)
  assert_winding_depth(union, svg_path.Point(1.0, 1.0), 3)
}

fn line(x1: Float, y1: Float, x2: Float, y2: Float) -> svg_path.Segment {
  svg_path.Line(start: svg_path.Point(x1, y1), end: svg_path.Point(x2, y2))
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

fn assert_area(path: svg_path.Path, expected: Float) {
  let assert Ok(actual) = area.path(path, using: svg_path.Nonzero)
  assert near(actual, expected)
}

fn assert_winding_depth(
  path: svg_path.Path,
  point: svg_path.Point,
  expected: Int,
) {
  let assert Ok(svg_path.Winding(winding)) =
    svg_path.path_winding(point, within: path)
  assert int.absolute_value(winding) == expected
}

fn contains_segment(
  segments: List(svg_path.Segment),
  segment: svg_path.Segment,
) -> Bool {
  count_segment(segments, segment) > 0
}

fn count_segment(
  segments: List(svg_path.Segment),
  wanted: svg_path.Segment,
) -> Int {
  segments
  |> list.filter(keeping: fn(segment) { segment == wanted })
  |> list.length
}

fn near(a: Float, b: Float) -> Bool {
  float.absolute_value(a -. b) <=. tolerance
}
