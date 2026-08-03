//// Focused fixtures for classifying overlap/intersection coexistence.

import svg_path
import svg_path/encounters
import svg_path/intersections
import svg_path/overlaps
import svg_path/point
import svg_path_encounter_validation as validation

const tolerance = 0.000001

pub fn point_strictly_inside_overlap_fixture_test() {
  let segment = line(0.0, 10.0)
  let overlap = segment_overlap(0.2, 0.8)
  let intersection = intersection(0.5)
  let found =
    encounters.Encounters(overlaps: [overlap], intersections: [intersection])

  assert validation.segment_intersection_is_contained_in_overlap(
    intersection,
    overlap,
  )
  assert validation.segment_encounters_are_valid(
      segment,
      segment,
      found,
      tolerance:,
    )
    == Ok(False)
}

pub fn point_at_overlap_boundary_with_same_address_fixture_test() {
  let segment = line(0.0, 10.0)
  let overlap = segment_overlap(0.2, 0.8)
  let intersection = intersection(0.2)
  let found =
    encounters.Encounters(overlaps: [overlap], intersections: [intersection])

  assert validation.segment_intersection_is_contained_in_overlap(
    intersection,
    overlap,
  )
  assert validation.segment_encounters_are_valid(
      segment,
      segment,
      found,
      tolerance:,
    )
    == Ok(False)
}

pub fn point_at_overlap_boundary_through_adjacent_alias_fixture_test() {
  let assert Ok(left) =
    svg_path.subpath([line(0.0, 10.0), vertical(10.0, 0.0, 10.0)])
  let assert Ok(right) =
    svg_path.subpath([line(0.0, 5.0), vertical(5.0, 0.0, 10.0)])
  let assert Ok(encounter) = encounters.subpath(left, right)
  let assert encounters.Encounters(
    overlaps: [overlap],
    intersections: [boundary],
  ) = encounter

  let assert svg_path.SubpathIntersection(
    left_parameters: [left_at],
    right_parameters: [right_at],
    ..,
  ) = boundary
  assert left_at == svg_path.SubpathParameter(segment_index: 0, t: 0.5)
  assert right_at == svg_path.SubpathParameter(segment_index: 1, t: 0.0)
  assert validation.subpath_intersection_is_contained_in_overlap(
    left,
    right,
    boundary,
    overlap,
  )
}

pub fn isolated_intersection_elsewhere_in_same_query_fixture_test() {
  let assert Ok(left) =
    svg_path.subpath([
      line(0.0, 10.0),
      vertical(10.0, 0.0, 10.0),
    ])
  let assert Ok(right) =
    svg_path.subpath([
      line(0.0, 5.0),
      svg_path.Line(
        start: svg_path.Point(5.0, 0.0),
        end: svg_path.Point(15.0, 10.0),
      ),
    ])
  let assert Ok(encounter) = encounters.subpath(left, right)
  let assert encounters.Encounters(
    overlaps: [overlap],
    intersections: [boundary, isolated],
  ) = encounter

  assert validation.subpath_intersection_is_contained_in_overlap(
    left,
    right,
    boundary,
    overlap,
  )
  assert !validation.subpath_intersection_is_contained_in_overlap(
    left,
    right,
    isolated,
    overlap,
  )
  assert isolated.point == svg_path.Point(10.0, 5.0)
}

pub fn cubic_overlap_can_mask_another_isolated_intersection_fixture_test() {
  let curve = self_crossing_cubic()
  let overlap =
    overlaps.SegmentOverlap(
      start: svg_path.segment_start(curve),
      end: svg_path.segment_end(curve),
      left_from: 0.0,
      left_to: 1.0,
      right_from: 0.0,
      right_to: 1.0,
    )
  assert validation.segment_overlap_is_valid(curve, curve, overlap, tolerance:)
    == Ok(True)

  // The same full-range overlap also has a distinct-parameter crossing. This
  // is the relation a complete segment encounter query eventually needs to
  // preserve rather than masking it behind the overlap result.
  let assert Ok([crossing]) = intersections.segment_self(curve)
  assert crossing.left_t == 0.25
  assert crossing.right_t == 0.75
  let assert Ok(expected) = svg_path.segment_point(curve, at: 0.25)
  assert point.near(crossing.point, expected, tolerance:)
}

pub fn one_sided_overlap_containment_is_flagged_fixture_test() {
  let whole = self_crossing_cubic()
  let assert Ok(branch) =
    svg_path.segment_between_inside(whole, from: 0.1, to: 0.5)
  let assert Ok(start) = svg_path.segment_point(whole, at: 0.1)
  let assert Ok(end) = svg_path.segment_point(whole, at: 0.5)
  let overlap =
    overlaps.SegmentOverlap(
      start:,
      end:,
      left_from: 0.1,
      left_to: 0.5,
      right_from: 0.0,
      right_to: 1.0,
    )
  let assert Ok(crossing) = svg_path.segment_point(whole, at: 0.75)
  let intersection =
    svg_path.SegmentIntersection(point: crossing, left_t: 0.75, right_t: 0.375)
  let found =
    encounters.Encounters(overlaps: [overlap], intersections: [intersection])

  assert validation.segment_overlap_is_valid(whole, branch, overlap, tolerance:)
    == Ok(True)
  assert validation.segment_intersection_is_valid(
      whole,
      branch,
      intersection,
      tolerance:,
    )
    == Ok(True)
  assert validation.segment_intersection_overlap_interval_containment(
      intersection,
      overlap,
    )
    == validation.RightSideOnly
  assert validation.segment_encounters_are_valid(
      whole,
      branch,
      found,
      tolerance:,
    )
    == Ok(False)

  let reversed_overlap =
    overlaps.SegmentOverlap(
      start:,
      end:,
      left_from: 0.0,
      left_to: 1.0,
      right_from: 0.1,
      right_to: 0.5,
    )
  let reversed_intersection =
    svg_path.SegmentIntersection(point: crossing, left_t: 0.375, right_t: 0.75)
  assert validation.segment_intersection_overlap_interval_containment(
      reversed_intersection,
      reversed_overlap,
    )
    == validation.LeftSideOnly
}

fn segment_overlap(from: Float, to: Float) {
  overlaps.SegmentOverlap(
    start: svg_path.Point(from *. 10.0, 0.0),
    end: svg_path.Point(to *. 10.0, 0.0),
    left_from: from,
    left_to: to,
    right_from: from,
    right_to: to,
  )
}

fn intersection(t: Float) {
  svg_path.SegmentIntersection(
    point: svg_path.Point(t *. 10.0, 0.0),
    left_t: t,
    right_t: t,
  )
}

fn line(from: Float, to: Float) {
  svg_path.Line(start: svg_path.Point(from, 0.0), end: svg_path.Point(to, 0.0))
}

fn vertical(x: Float, from: Float, to: Float) {
  svg_path.Line(start: svg_path.Point(x, from), end: svg_path.Point(x, to))
}

fn self_crossing_cubic() {
  svg_path.CubicBezier(
    start: svg_path.Point(0.0, 0.0),
    control1: svg_path.Point(-0.2708333333333333, -0.3333333333333333),
    control2: svg_path.Point(-0.5416666666666666, -0.3333333333333333),
    end: svg_path.Point(0.1875, 0.0),
  )
}
