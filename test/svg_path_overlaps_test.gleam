import gleam/list
import svg_path
import svg_path/encounters
import svg_path/intersections
import svg_path/overlaps

const tolerance = 0.000001

pub fn segment_overlap_and_intersection_agree_on_partial_line_test() {
  let left = line()
  let right =
    svg_path.Line(
      start: svg_path.Point(5.0, 0.0),
      end: svg_path.Point(15.0, 0.0),
    )

  assert_overlap_contract(left, right, expected_overlap: True)
}

pub fn segment_overlap_and_intersection_agree_on_semantic_arc_test() {
  let same_geometry =
    svg_path.Arc(
      start: svg_path.Point(0.0, 0.0),
      radius: svg_path.Point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: True,
      sweep: True,
      end: svg_path.Point(10.0, 0.0),
    )

  assert_overlap_contract(arc(), same_geometry, expected_overlap: True)
}

pub fn semantic_arc_overlap_survives_nine_decimal_tolerance_test() {
  let same_geometry =
    svg_path.Arc(
      start: svg_path.Point(0.0, 0.0),
      radius: svg_path.Point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: True,
      sweep: True,
      end: svg_path.Point(10.0, 0.0),
    )
  let strict_tolerance = 0.000000001

  let assert Ok([_]) =
    overlaps.segment_with(arc(), same_geometry, tolerance: strict_tolerance)
  assert intersections.segment_with(
      arc(),
      same_geometry,
      options: intersections.IntersectionOptions(
        tolerance: strict_tolerance,
        max_depth: 48,
      ),
    )
    == Error(svg_path.OverlappingSegments)
}

pub fn segment_overlap_and_intersection_agree_on_endpoint_touch_test() {
  let right =
    svg_path.Line(
      start: svg_path.Point(10.0, 0.0),
      end: svg_path.Point(10.0, 10.0),
    )

  assert_overlap_contract(line(), right, expected_overlap: False)
}

pub fn segment_overlap_and_intersection_agree_on_disjoint_segments_test() {
  let right =
    svg_path.Line(
      start: svg_path.Point(0.0, 2.0),
      end: svg_path.Point(10.0, 2.0),
    )

  assert_overlap_contract(line(), right, expected_overlap: False)
}

fn assert_overlap_contract(
  left: svg_path.Segment,
  right: svg_path.Segment,
  expected_overlap expected_overlap: Bool,
) {
  let options = intersections.IntersectionOptions(tolerance:, max_depth: 48)
  let assert Ok(found_overlaps) =
    overlaps.segment_with(left, right, tolerance: options.tolerance)
  let reports_overlap = !list.is_empty(found_overlaps)
  let intersection_reports_overlap =
    intersections.segment_with(left, right, options:)
    == Error(svg_path.OverlappingSegments)

  assert reports_overlap == expected_overlap
  assert intersection_reports_overlap == expected_overlap
}

pub fn segment_overlap_merge_is_idempotent_test() {
  let overlap = segment_overlap(0.1, 0.9, 0.2, 0.8)

  assert overlaps.merge_segment_overlaps(overlap, overlap, tolerance:)
    == overlaps.Merged(overlap)
}

pub fn segment_overlap_merge_keeps_containing_interval_test() {
  let outer = segment_overlap(0.0, 1.0, 0.0, 1.0)
  let inner = segment_overlap(0.2, 0.8, 0.2, 0.8)

  assert overlaps.merge_segment_overlaps(inner, outer, tolerance:)
    == overlaps.Merged(outer)
}

pub fn segment_overlap_merge_combines_partial_intervals_test() {
  let first = segment_overlap(0.0, 0.6, 0.0, 0.6)
  let second = segment_overlap(0.4, 1.0, 0.4, 1.0)
  let expected = segment_overlap(0.0, 1.0, 0.0, 1.0)

  assert overlaps.merge_segment_overlaps(first, second, tolerance:)
    == overlaps.Merged(expected)
  assert overlaps.merge_segment_overlaps(second, first, tolerance:)
    == overlaps.Merged(expected)
}

pub fn segment_overlap_merge_combines_touching_intervals_test() {
  let first = segment_overlap(0.0, 0.5, 0.0, 0.5)
  let second = segment_overlap(0.5, 1.0, 0.5, 1.0)

  assert overlaps.merge_segment_overlaps(first, second, tolerance:)
    == overlaps.Merged(segment_overlap(0.0, 1.0, 0.0, 1.0))
}

pub fn segment_overlap_merge_preserves_reversed_traversal_test() {
  let first = segment_overlap(0.0, 0.6, 1.0, 0.4)
  let second = segment_overlap(0.4, 1.0, 0.6, 0.0)

  assert overlaps.merge_segment_overlaps(first, second, tolerance:)
    == overlaps.Merged(segment_overlap(0.0, 1.0, 1.0, 0.0))
}

pub fn segment_overlap_merge_reports_disjoint_intervals_test() {
  let first = segment_overlap(0.0, 0.2, 0.0, 0.2)
  let second = segment_overlap(0.8, 1.0, 0.8, 1.0)

  assert overlaps.merge_segment_overlaps(first, second, tolerance:)
    == overlaps.Disjoint
}

pub fn segment_overlap_merge_rejects_one_sided_overlap_test() {
  let first = segment_overlap(0.0, 0.6, 0.0, 0.2)
  let second = segment_overlap(0.4, 1.0, 0.8, 1.0)

  assert overlaps.merge_segment_overlaps(first, second, tolerance:)
    == overlaps.Contradiction
}

pub fn segment_overlap_merge_rejects_direction_change_test() {
  let first = segment_overlap(0.0, 0.6, 0.0, 0.6)
  let second = segment_overlap(0.4, 1.0, 0.6, 0.0)

  assert overlaps.merge_segment_overlaps(first, second, tolerance:)
    == overlaps.Contradiction
}

pub fn segment_overlap_merge_rejects_zero_length_interval_test() {
  let point = segment_overlap(0.5, 0.5, 0.5, 0.5)
  let interval = segment_overlap(0.0, 1.0, 0.0, 1.0)

  assert overlaps.merge_segment_overlaps(point, interval, tolerance:)
    == overlaps.Contradiction
}

pub fn canonicalize_segment_overlap_orients_by_left_segment_test() {
  let overlap =
    overlaps.SegmentOverlap(
      left_from: 0.8,
      left_to: 0.2,
      right_from: 0.1,
      right_to: 0.7,
      start: svg_path.Point(8.0, 0.0),
      end: svg_path.Point(2.0, 0.0),
    )

  assert overlaps.canonicalize_segment_overlap(overlap)
    == overlaps.SegmentOverlap(
      left_from: 0.2,
      left_to: 0.8,
      right_from: 0.7,
      right_to: 0.1,
      start: svg_path.Point(2.0, 0.0),
      end: svg_path.Point(8.0, 0.0),
    )
}

pub fn segment_overlap_minimum_span_filter_is_separate_test() {
  let overlap = segment_overlap(0.2, 0.2001, 0.4, 0.4001)

  assert overlaps.canonicalize_segment_overlap(overlap) == overlap
  assert !overlaps.segment_overlap_exceeds_minimum_span(
    overlap,
    minimum_span: 0.001,
  )
}

pub fn segment_overlap_list_merge_closes_transitive_chain_test() {
  let first = segment_overlap(0.0, 0.4, 0.0, 0.4)
  let second = segment_overlap(0.3, 0.7, 0.3, 0.7)
  let third = segment_overlap(0.6, 1.0, 0.6, 1.0)

  assert overlaps.merge_segment_overlap_list([third, first, second], tolerance:)
    == Ok([segment_overlap(0.0, 1.0, 0.0, 1.0)])
}

pub fn endpoint_projection_overlap_finds_partial_line_overlap_test() {
  let left =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 0.0),
    )
  let right =
    svg_path.Line(
      start: svg_path.Point(3.0, 0.0),
      end: svg_path.Point(7.0, 0.0),
    )

  let assert Ok([overlap]) =
    overlaps.segment_overlaps_by_endpoint_projection_with(
      left,
      right,
      tolerance:,
      samples: 5,
    )
  let overlaps.SegmentOverlap(left_from:, left_to:, right_from:, right_to:, ..) =
    overlap
  assert near(left_from, 0.3)
  assert near(left_to, 0.7)
  assert near(right_from, 0.0)
  assert near(right_to, 1.0)
}

pub fn endpoint_projection_overlap_preserves_reversed_line_overlap_test() {
  let left =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 0.0),
    )
  let right =
    svg_path.Line(
      start: svg_path.Point(7.0, 0.0),
      end: svg_path.Point(3.0, 0.0),
    )

  let assert Ok([overlap]) =
    overlaps.segment_overlaps_by_endpoint_projection_with(
      left,
      right,
      tolerance:,
      samples: 5,
    )
  let overlaps.SegmentOverlap(right_from:, right_to:, ..) = overlap
  assert near(right_from, 1.0)
  assert near(right_to, 0.0)
}

pub fn endpoint_projection_overlap_finds_semantically_equal_arcs_test() {
  let same_geometry =
    svg_path.Arc(
      start: svg_path.Point(0.0, 0.0),
      radius: svg_path.Point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: True,
      sweep: True,
      end: svg_path.Point(10.0, 0.0),
    )

  let assert Ok([overlap]) =
    overlaps.segment_overlaps_by_endpoint_projection_with(
      arc(),
      same_geometry,
      tolerance:,
      samples: 9,
    )
  assert overlap == segment_overlap(0.0, 1.0, 0.0, 1.0)
}

pub fn endpoint_projection_overlap_rejects_opposite_semicircles_test() {
  let opposite =
    svg_path.Arc(
      start: svg_path.Point(0.0, 0.0),
      radius: svg_path.Point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: False,
      end: svg_path.Point(10.0, 0.0),
    )

  assert overlaps.segment_overlaps_by_endpoint_projection_with(
      arc(),
      opposite,
      tolerance:,
      samples: 9,
    )
    == Ok([])
}

pub fn identical_line_is_one_full_overlap_test() {
  assert_full_overlap(line(), line(), 0.0, 1.0)
}

pub fn reversed_line_is_one_full_overlap_test() {
  assert_full_overlap(line(), svg_path.segment_reverse(line()), 1.0, 0.0)
}

pub fn identical_quadratic_is_one_full_overlap_test() {
  let segment =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.0),
      control: svg_path.Point(5.0, 8.0),
      end: svg_path.Point(10.0, 0.0),
    )
  assert_full_overlap(segment, segment, 0.0, 1.0)
}

pub fn reversed_quadratic_is_one_full_overlap_test() {
  let segment =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.0),
      control: svg_path.Point(5.0, 8.0),
      end: svg_path.Point(10.0, 0.0),
    )
  assert_full_overlap(segment, svg_path.segment_reverse(segment), 1.0, 0.0)
}

pub fn identical_cubic_is_one_full_overlap_test() {
  let segment =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(2.0, 9.0),
      control2: svg_path.Point(8.0, -9.0),
      end: svg_path.Point(10.0, 0.0),
    )
  assert_full_overlap(segment, segment, 0.0, 1.0)
}

pub fn reversed_cubic_is_one_full_overlap_test() {
  let segment =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(2.0, 9.0),
      control2: svg_path.Point(8.0, -9.0),
      end: svg_path.Point(10.0, 0.0),
    )
  assert_full_overlap(segment, svg_path.segment_reverse(segment), 1.0, 0.0)
}

pub fn non_affinely_parameterized_line_cubics_are_rejected_test() {
  let linear_speed =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(1.0 /. 3.0, 0.0),
      control2: svg_path.Point(2.0 /. 3.0, 0.0),
      end: svg_path.Point(1.0, 0.0),
    )
  let cubic_speed =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(0.0, 0.0),
      control2: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(1.0, 0.0),
    )

  assert overlaps.segment(linear_speed, cubic_speed)
    == Error(svg_path.NonAffineOverlapCorrespondence)
  assert intersections.segment(linear_speed, cubic_speed)
    == Error(svg_path.NonAffineOverlapCorrespondence)
  assert encounters.segment(linear_speed, cubic_speed)
    == Error(svg_path.NonAffineOverlapCorrespondence)
}

pub fn segment_overlap_exposes_affine_parameter_correspondence_test() {
  let overlap =
    overlaps.SegmentOverlap(
      start: svg_path.Point(2.0, 0.0),
      end: svg_path.Point(8.0, 0.0),
      left_from: 0.2,
      left_to: 0.8,
      right_from: 0.9,
      right_to: 0.3,
    )

  assert near(overlaps.segment_overlap_right_parameter(overlap, 0.5), 0.6)
  assert near(overlaps.segment_overlap_left_parameter(overlap, 0.6), 0.5)
}

pub fn identical_arc_is_one_full_overlap_test() {
  let segment = arc()
  assert_full_overlap(segment, segment, 0.0, 1.0)
}

pub fn reversed_arc_is_one_full_overlap_test() {
  let segment = arc()
  assert_full_overlap(segment, svg_path.segment_reverse(segment), 1.0, 0.0)
}

fn assert_full_overlap(
  left: svg_path.Segment,
  right: svg_path.Segment,
  expected_right_from: Float,
  expected_right_to: Float,
) {
  assert intersections.segment(left, right)
    == Error(svg_path.OverlappingSegments)
  let assert Ok([encounter]) = overlaps.segment(left, right)
  let overlaps.SegmentOverlap(
    left_from:,
    left_to:,
    right_from:,
    right_to:,
    start:,
    end:,
  ) = encounter
  assert left_from == 0.0
  assert left_to == 1.0
  assert right_from == expected_right_from
  assert right_to == expected_right_to
  assert start == svg_path.segment_start(left)
  assert end == svg_path.segment_end(left)
}

fn line() -> svg_path.Segment {
  svg_path.Line(start: svg_path.Point(0.0, 0.0), end: svg_path.Point(10.0, 0.0))
}

fn segment_overlap(
  left_from: Float,
  left_to: Float,
  right_from: Float,
  right_to: Float,
) -> overlaps.SegmentOverlap {
  overlaps.SegmentOverlap(
    left_from:,
    left_to:,
    right_from:,
    right_to:,
    start: svg_path.Point(left_from *. 10.0, 0.0),
    end: svg_path.Point(left_to *. 10.0, 0.0),
  )
}

fn near(first: Float, second: Float) -> Bool {
  let difference = first -. second
  difference *. difference <=. tolerance *. tolerance
}

fn arc() -> svg_path.Segment {
  svg_path.Arc(
    start: svg_path.Point(0.0, 0.0),
    radius: svg_path.Point(5.0, 5.0),
    x_axis_rotation: 0.0,
    large_arc: False,
    sweep: True,
    end: svg_path.Point(10.0, 0.0),
  )
}
