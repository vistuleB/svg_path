import gleam/list
import svg_path
import svg_path/encounters
import svg_path/overlaps
import svg_path_encounter_validation

const tolerance = 0.000000001

pub fn disjoint_segments_have_no_encounters_test() {
  let left = line(0.0, 0.0, 10.0, 0.0)
  let right = line(0.0, 2.0, 10.0, 2.0)

  let assert Ok(found) = encounters.segment(left, right)
  assert found == encounters.Encounters(overlaps: [], intersections: [])
  assert svg_path_encounter_validation.segment_encounters_are_valid(
      left,
      right,
      found,
      tolerance:,
    )
    == Ok(True)
}

pub fn crossing_segments_have_one_point_intersection_test() {
  let left = line(0.0, 0.0, 10.0, 10.0)
  let right = line(0.0, 10.0, 10.0, 0.0)

  let assert Ok(result) = encounters.segment(left, right)
  let assert encounters.Encounters(overlaps: [], intersections: [found]) =
    result
  assert found
    == svg_path.SegmentIntersection(
      left_t: 0.5,
      right_t: 0.5,
      point: svg_path.Point(5.0, 5.0),
    )
  assert svg_path_encounter_validation.segment_encounters_are_valid(
      left,
      right,
      result,
      tolerance:,
    )
    == Ok(True)
}

pub fn endpoint_touch_is_a_point_intersection_test() {
  let left = line(0.0, 0.0, 10.0, 0.0)
  let right = line(10.0, 0.0, 10.0, 10.0)

  let assert Ok(result) = encounters.segment(left, right)
  let assert encounters.Encounters(overlaps: [], intersections: [_]) = result
  assert svg_path_encounter_validation.segment_encounters_are_valid(
      left,
      right,
      result,
      tolerance:,
    )
    == Ok(True)
}

pub fn partial_line_overlap_has_overlap_and_no_reported_points_test() {
  let left = line(0.0, 0.0, 10.0, 0.0)
  let right = line(5.0, 0.0, 15.0, 0.0)

  let assert Ok(result) = encounters.segment(left, right)
  let assert encounters.Encounters(overlaps: [_], intersections: []) = result
  assert svg_path_encounter_validation.segment_encounters_are_valid(
      left,
      right,
      result,
      tolerance:,
    )
    == Ok(True)
}

pub fn reversed_partial_line_overlap_is_valid_test() {
  let left = line(0.0, 0.0, 10.0, 0.0)
  let right = line(15.0, 0.0, 5.0, 0.0)

  let assert Ok(result) = encounters.segment(left, right)
  let assert encounters.Encounters(overlaps: [overlap], intersections: []) =
    result
  let overlaps.SegmentOverlap(right_from:, right_to:, ..) = overlap
  assert right_from >. right_to
  assert svg_path_encounter_validation.segment_encounters_are_valid(
      left,
      right,
      result,
      tolerance:,
    )
    == Ok(True)
}

pub fn overlap_validator_rejects_out_of_range_parameters_test() {
  let segment = line(0.0, 0.0, 10.0, 0.0)
  let invalid =
    overlaps.SegmentOverlap(
      left_from: -0.1,
      left_to: 1.0,
      right_from: 0.0,
      right_to: 1.0,
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 0.0),
    )

  assert svg_path_encounter_validation.segment_overlap_is_valid(
      segment,
      segment,
      invalid,
      tolerance:,
    )
    == Ok(False)
}

pub fn overlap_validator_rejects_noncoincident_interiors_test() {
  let left = line(0.0, 0.0, 10.0, 0.0)
  let right =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.0),
      control: svg_path.Point(5.0, 5.0),
      end: svg_path.Point(10.0, 0.0),
    )
  let invalid =
    overlaps.SegmentOverlap(
      left_from: 0.0,
      left_to: 1.0,
      right_from: 0.0,
      right_to: 1.0,
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 0.0),
    )

  assert svg_path_encounter_validation.segment_overlap_is_valid(
      left,
      right,
      invalid,
      tolerance:,
    )
    == Ok(False)
}

pub fn encounter_validator_reports_intersection_contained_in_overlap_test() {
  let segment = line(0.0, 0.0, 10.0, 0.0)
  let overlap =
    overlaps.SegmentOverlap(
      left_from: 0.0,
      left_to: 1.0,
      right_from: 1.0,
      right_to: 0.0,
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 0.0),
    )
  let intersection =
    svg_path.SegmentIntersection(
      left_t: 0.5,
      right_t: 0.5,
      point: svg_path.Point(5.0, 0.0),
    )
  let found =
    encounters.Encounters(overlaps: [overlap], intersections: [intersection])

  assert svg_path_encounter_validation.segment_intersection_is_contained_in_overlap(
    intersection,
    overlap,
  )
  assert svg_path_encounter_validation.segment_encounters_are_valid(
      segment,
      svg_path.segment_reverse(segment),
      found,
      tolerance:,
    )
    == Ok(False)
}

pub fn intersection_validator_rejects_wrong_recorded_point_test() {
  let left = line(0.0, 0.0, 10.0, 10.0)
  let right = line(0.0, 10.0, 10.0, 0.0)
  let invalid =
    svg_path.SegmentIntersection(
      left_t: 0.5,
      right_t: 0.5,
      point: svg_path.Point(6.0, 5.0),
    )

  assert svg_path_encounter_validation.segment_intersection_is_valid(
      left,
      right,
      invalid,
      tolerance:,
    )
    == Ok(False)
}

pub fn subpaths_retain_overlap_and_intersections_from_other_segment_pairs_test() {
  let assert Ok(left) =
    svg_path.subpath([
      line(0.0, 0.0, 10.0, 0.0),
      line(10.0, 0.0, 10.0, 10.0),
    ])
  let assert Ok(right) =
    svg_path.subpath([
      line(0.0, 0.0, 5.0, 0.0),
      line(5.0, 0.0, 15.0, 10.0),
    ])

  let assert Ok(result) = encounters.subpath(left, right)
  let assert encounters.Encounters(overlaps: [_], intersections: intersections) =
    result

  // The overlap boundary at (5, 0) is deliberately not filtered from the
  // point results. The other point, (10, 5), is an isolated intersection.
  assert intersections
    == [
      svg_path.SubpathIntersection(
        point: svg_path.Point(5.0, 0.0),
        left_parameters: [svg_path.SubpathParameter(segment_index: 0, t: 0.5)],
        right_parameters: [svg_path.SubpathParameter(segment_index: 1, t: 0.0)],
      ),
      svg_path.SubpathIntersection(
        point: svg_path.Point(10.0, 5.0),
        left_parameters: [svg_path.SubpathParameter(segment_index: 1, t: 0.5)],
        right_parameters: [svg_path.SubpathParameter(segment_index: 1, t: 0.5)],
      ),
    ]
}

pub fn segment_subpath_retains_addresses_for_overlap_and_points_test() {
  let segment = line(0.0, 0.0, 10.0, 0.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      line(0.0, 0.0, 5.0, 0.0),
      line(5.0, 0.0, 5.0, 5.0),
      line(5.0, 5.0, 10.0, -5.0),
    ])

  let assert Ok(result) = encounters.segment_subpath(segment, subpath)
  let assert encounters.Encounters(
    overlaps: [overlap],
    intersections: intersections,
  ) = result
  assert overlap
    == overlaps.SegmentSubpathOverlap(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(5.0, 0.0),
      segment_from: 0.0,
      segment_to: 0.5,
      subpath_from: svg_path.SubpathParameter(segment_index: 0, t: 0.0),
      subpath_to: svg_path.SubpathParameter(segment_index: 0, t: 1.0),
    )
  assert intersections
    == [
      #(svg_path.Point(5.0, 0.0), 0.5, [
        svg_path.SubpathParameter(segment_index: 1, t: 0.0),
      ]),
      #(svg_path.Point(7.5, 0.0), 0.75, [
        svg_path.SubpathParameter(segment_index: 2, t: 0.5),
      ]),
    ]
}

pub fn path_encounters_retain_subpath_and_segment_addresses_test() {
  let assert Ok(left_subpath) =
    svg_path.subpath([
      line(0.0, 0.0, 10.0, 0.0),
      line(10.0, 0.0, 10.0, 10.0),
    ])
  let assert Ok(right_subpath) =
    svg_path.subpath([
      line(0.0, 0.0, 5.0, 0.0),
      line(5.0, 0.0, 15.0, 10.0),
    ])
  let left = svg_path.Path([left_subpath])
  let right = svg_path.Path([right_subpath])

  let assert Ok(result) = encounters.path(left, right)
  let assert encounters.Encounters(
    overlaps: [overlap],
    intersections: intersections,
  ) = result
  assert overlap
    == overlaps.PathOverlap(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(5.0, 0.0),
      left_from: svg_path.PathParameter(
        subpath_index: 0,
        at: svg_path.SubpathParameter(segment_index: 0, t: 0.0),
      ),
      left_to: svg_path.PathParameter(
        subpath_index: 0,
        at: svg_path.SubpathParameter(segment_index: 0, t: 0.5),
      ),
      right_from: svg_path.PathParameter(
        subpath_index: 0,
        at: svg_path.SubpathParameter(segment_index: 0, t: 0.0),
      ),
      right_to: svg_path.PathParameter(
        subpath_index: 0,
        at: svg_path.SubpathParameter(segment_index: 0, t: 1.0),
      ),
    )
  assert list.length(intersections) == 2
}

fn line(start_x: Float, start_y: Float, end_x: Float, end_y: Float) {
  svg_path.Line(
    start: svg_path.Point(start_x, start_y),
    end: svg_path.Point(end_x, end_y),
  )
}
