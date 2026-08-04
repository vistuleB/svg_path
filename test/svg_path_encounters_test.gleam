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

  // The raw result retains both the overlap boundary at (5, 0) and the
  // isolated intersection at (10, 5).
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
  assert svg_path_encounter_validation.subpath_encounters_are_valid(
      left,
      right,
      result,
      tolerance:,
    )
    == Ok(False)
}

pub fn subpath_encounters_retain_piecewise_overlap_correspondence_test() {
  let assert Ok(left) = svg_path.subpath([line(0.0, 0.0, 10.0, 0.0)])
  let assert Ok(right) =
    svg_path.subpath([
      line(0.0, 0.0, 5.0, 0.0),
      line(5.0, 0.0, 10.0, 0.0),
    ])

  let assert Ok(encounters.Encounters(
    overlaps: [overlaps.SubpathOverlap(pieces: [first, second], ..)],
    intersections: [],
  )) = encounters.subpath(left, right)
  let assert overlaps.SubpathOverlapPiece(
    left_segment_index: 0,
    right_segment_index: 0,
    ..,
  ) = first
  let assert overlaps.SubpathOverlapPiece(
    left_segment_index: 0,
    right_segment_index: 1,
    ..,
  ) = second
}

pub fn subpath_parameters_are_complementary_through_overlap_test() {
  let assert Ok(left) = svg_path.subpath([line(0.0, 0.0, 10.0, 0.0)])
  let assert Ok(right) = svg_path.subpath([line(2.0, 0.0, 8.0, 0.0)])
  let assert Ok([overlap]) = overlaps.subpath(left, right)

  assert filter_removes_parameter_pair(
      svg_path.SubpathParameter(segment_index: 0, t: 0.5),
      svg_path.SubpathParameter(segment_index: 0, t: 0.5),
      left,
      right,
      [overlap],
      tolerance,
    )
    == Ok(True)
  assert filter_removes_parameter_pair(
      svg_path.SubpathParameter(segment_index: 0, t: 0.0),
      svg_path.SubpathParameter(segment_index: 0, t: 0.0),
      left,
      right,
      [overlap],
      tolerance,
    )
    == Ok(False)
}

pub fn subpath_parameter_complementarity_clamps_by_arc_length_test() {
  let assert Ok(left) = svg_path.subpath([line(0.0, 0.0, 10.0, 0.0)])
  let assert Ok(right) = svg_path.subpath([line(2.0, 0.0, 8.0, 0.0)])
  let assert Ok([overlap]) = overlaps.subpath(left, right)
  let geometric_tolerance = 0.000001

  assert filter_removes_parameter_pair(
      svg_path.SubpathParameter(segment_index: 0, t: 0.19999999),
      svg_path.SubpathParameter(segment_index: 0, t: 0.0),
      left,
      right,
      [overlap],
      geometric_tolerance,
    )
    == Ok(True)
  assert filter_removes_parameter_pair(
      svg_path.SubpathParameter(segment_index: 0, t: 0.19),
      svg_path.SubpathParameter(segment_index: 0, t: 0.0),
      left,
      right,
      [overlap],
      geometric_tolerance,
    )
    == Ok(False)
}

pub fn subpath_parameter_complementarity_uses_short_closed_seam_motion_test() {
  let left =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
      svg_path.Point(0.0, 10.0),
      svg_path.Point(0.0, 0.0),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)
  let assert Ok(right) = svg_path.subpath([line(0.0, 5.0, 0.0, 0.0)])
  let assert Ok([overlap]) = overlaps.subpath(left, right)

  assert filter_removes_parameter_pair(
      svg_path.SubpathParameter(segment_index: 0, t: 0.00000001),
      svg_path.SubpathParameter(segment_index: 0, t: 1.0),
      left,
      right,
      [overlap],
      0.000001,
    )
    == Ok(True)
}

pub fn subpath_parameter_complementarity_searches_all_overlaps_test() {
  let assert Ok(left) = svg_path.subpath([line(0.0, 0.0, 10.0, 0.0)])
  let right =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(4.0, 0.0),
      svg_path.Point(4.0, 2.0),
      svg_path.Point(6.0, 2.0),
      svg_path.Point(6.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])
  let assert Ok(overlap_intervals) = overlaps.subpath(left, right)
  assert list.length(overlap_intervals) == 2

  assert filter_removes_parameter_pair(
      svg_path.SubpathParameter(segment_index: 0, t: 0.8),
      svg_path.SubpathParameter(segment_index: 4, t: 0.5),
      left,
      right,
      overlap_intervals,
      tolerance,
    )
    == Ok(True)
}

pub fn subpath_parameter_complementarity_rejects_invalid_tolerance_test() {
  let assert Ok(subpath) = svg_path.subpath([line(0.0, 0.0, 10.0, 0.0)])

  assert filter_removes_parameter_pair(
      svg_path.SubpathParameter(segment_index: 0, t: 0.5),
      svg_path.SubpathParameter(segment_index: 0, t: 0.5),
      subpath,
      subpath,
      [],
      0.0,
    )
    == Error(svg_path.InvalidIntersectionTolerance(0.0))
}

pub fn subpath_intersection_entirely_explained_by_overlap_is_removed_test() {
  let assert Ok(left) = svg_path.subpath([line(0.0, 0.0, 10.0, 0.0)])
  let assert Ok(right) = svg_path.subpath([line(2.0, 0.0, 8.0, 0.0)])
  let assert Ok(overlap_intervals) = overlaps.subpath(left, right)
  let intersection =
    svg_path.SubpathIntersection(
      point: svg_path.Point(5.0, 0.0),
      left_parameters: [svg_path.SubpathParameter(segment_index: 0, t: 0.5)],
      right_parameters: [svg_path.SubpathParameter(segment_index: 0, t: 0.5)],
    )

  let found =
    encounters.Encounters(overlaps: overlap_intervals, intersections: [
      intersection,
    ])
  assert encounters.filter_fully_overlap_explained_subpath_intersection_parameters(
      found,
      left,
      right,
      tolerance,
    )
    == Ok(encounters.Encounters(overlaps: overlap_intervals, intersections: []))
}

pub fn subpath_intersection_retains_parameters_with_non_overlap_claim_test() {
  let assert Ok(left) = svg_path.subpath([line(0.0, 0.0, 10.0, 0.0)])
  let assert Ok(right) = svg_path.subpath([line(2.0, 0.0, 8.0, 0.0)])
  let assert Ok(overlap_intervals) = overlaps.subpath(left, right)
  let complementary_left = svg_path.SubpathParameter(segment_index: 0, t: 0.5)
  let non_complementary_left =
    svg_path.SubpathParameter(segment_index: 0, t: 0.8)
  let right_parameter = svg_path.SubpathParameter(segment_index: 0, t: 0.5)
  let intersection =
    svg_path.SubpathIntersection(
      point: svg_path.Point(5.0, 0.0),
      left_parameters: [complementary_left, non_complementary_left],
      right_parameters: [right_parameter],
    )

  let found =
    encounters.Encounters(overlaps: overlap_intervals, intersections: [
      intersection,
    ])
  assert encounters.filter_fully_overlap_explained_subpath_intersection_parameters(
      found,
      left,
      right,
      tolerance,
    )
    == Ok(
      encounters.Encounters(overlaps: overlap_intervals, intersections: [
        svg_path.SubpathIntersection(
          point: svg_path.Point(5.0, 0.0),
          left_parameters: [non_complementary_left],
          right_parameters: [right_parameter],
        ),
      ]),
    )
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
      pieces: [
        overlaps.SegmentSubpathOverlapPiece(
          subpath_segment_index: 0,
          correspondence: overlaps.SegmentOverlap(
            start: svg_path.Point(0.0, 0.0),
            end: svg_path.Point(5.0, 0.0),
            left_from: 0.0,
            left_to: 0.5,
            right_from: 0.0,
            right_to: 1.0,
          ),
        ),
      ],
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
  assert svg_path_encounter_validation.segment_subpath_encounters_are_valid(
      segment,
      subpath,
      result,
      tolerance:,
    )
    == Ok(False)
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
      left_subpath_index: 0,
      right_subpath_index: 0,
      correspondence: overlaps.SubpathOverlap(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(5.0, 0.0),
        pieces: [
          overlaps.SubpathOverlapPiece(
            left_segment_index: 0,
            right_segment_index: 0,
            correspondence: overlaps.SegmentOverlap(
              start: svg_path.Point(0.0, 0.0),
              end: svg_path.Point(5.0, 0.0),
              left_from: 0.0,
              left_to: 0.5,
              right_from: 0.0,
              right_to: 1.0,
            ),
          ),
        ],
      ),
    )
  assert list.length(intersections) == 2
  assert svg_path_encounter_validation.path_encounters_are_valid(
      left,
      right,
      result,
      tolerance:,
    )
    == Ok(False)
}

pub fn higher_level_validators_accept_pure_overlap_results_test() {
  let segment = line(0.0, 0.0, 10.0, 0.0)
  let assert Ok(subpath) = svg_path.subpath([segment])
  let path = svg_path.Path([subpath])

  let assert Ok(segment_subpath_result) =
    encounters.segment_subpath(segment, subpath)
  assert svg_path_encounter_validation.segment_subpath_encounters_are_valid(
      segment,
      subpath,
      segment_subpath_result,
      tolerance:,
    )
    == Ok(True)

  let assert Ok(subpath_result) = encounters.subpath(subpath, subpath)
  assert svg_path_encounter_validation.subpath_encounters_are_valid(
      subpath,
      subpath,
      subpath_result,
      tolerance:,
    )
    == Ok(True)

  let assert Ok(path_result) = encounters.path(path, path)
  assert svg_path_encounter_validation.path_encounters_are_valid(
      path,
      path,
      path_result,
      tolerance:,
    )
    == Ok(True)
}

pub fn higher_level_overlap_validators_reject_invalid_segment_index_test() {
  let segment = line(0.0, 0.0, 10.0, 0.0)
  let assert Ok(subpath) =
    svg_path.subpath([segment, line(10.0, 0.0, 20.0, 0.0)])
  let invalid =
    overlaps.SegmentSubpathOverlap(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 0.0),
      pieces: [
        overlaps.SegmentSubpathOverlapPiece(
          subpath_segment_index: 99,
          correspondence: overlaps.SegmentOverlap(
            start: svg_path.Point(0.0, 0.0),
            end: svg_path.Point(10.0, 0.0),
            left_from: 0.0,
            left_to: 1.0,
            right_from: 0.0,
            right_to: 1.0,
          ),
        ),
      ],
    )

  assert svg_path_encounter_validation.segment_subpath_overlap_is_valid(
      segment,
      subpath,
      invalid,
      tolerance:,
    )
    == Ok(False)
}

fn line(start_x: Float, start_y: Float, end_x: Float, end_y: Float) {
  svg_path.Line(
    start: svg_path.Point(start_x, start_y),
    end: svg_path.Point(end_x, end_y),
  )
}

fn filter_removes_parameter_pair(
  left_parameter: svg_path.SubpathParameter,
  right_parameter: svg_path.SubpathParameter,
  left: svg_path.Subpath,
  right: svg_path.Subpath,
  overlap_intervals: List(overlaps.SubpathOverlap),
  tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  let found =
    encounters.Encounters(overlaps: overlap_intervals, intersections: [
      svg_path.SubpathIntersection(
        point: svg_path.Point(0.0, 0.0),
        left_parameters: [left_parameter],
        right_parameters: [right_parameter],
      ),
    ])
  case
    encounters.filter_fully_overlap_explained_subpath_intersection_parameters(
      found,
      left,
      right,
      tolerance,
    )
  {
    Ok(encounters.Encounters(intersections: [], ..)) -> Ok(True)
    Ok(_) -> Ok(False)
    Error(error) -> Error(error)
  }
}
