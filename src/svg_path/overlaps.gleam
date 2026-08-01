//// Continuous coincident intervals between path segments.

import gleam/float
import gleam/list
import gleam/result
import svg_path
import svg_path/overlap_detection

const default_overlap_tolerance = 0.000000001

/// One non-zero-length overlap interval between the same ordered pair of
/// segments. The left parameters and points follow the left segment's
/// traversal. The right parameters retain the corresponding traversal
/// direction and may therefore decrease.
pub type SegmentOverlap {
  SegmentOverlap(
    left_from: Float,
    left_to: Float,
    right_from: Float,
    right_to: Float,
    start: svg_path.Point,
    end: svg_path.Point,
  )
}

/// The result of combining two overlap intervals for the same ordered segment
/// pair.
pub type SegmentOverlapMerge {
  Disjoint
  Merged(SegmentOverlap)
  Contradiction
}

/// Orient an overlap by increasing parameter on the left segment.
///
/// Reorientation swaps both right parameters as well as the geometric
/// endpoints, preserving the correspondence between the two traversals.
pub fn canonicalize_segment_overlap(overlap: SegmentOverlap) -> SegmentOverlap {
  let SegmentOverlap(left_from:, left_to:, right_from:, right_to:, start:, end:) =
    overlap
  case left_from <=. left_to {
    True -> overlap
    False ->
      SegmentOverlap(
        left_from: left_to,
        left_to: left_from,
        right_from: right_to,
        right_to: right_from,
        start: end,
        end: start,
      )
  }
}

/// Whether an overlap has a strictly larger parameter span than `minimum_span`
/// on both segments.
pub fn segment_overlap_exceeds_minimum_span(
  overlap: SegmentOverlap,
  minimum_span minimum_span: Float,
) -> Bool {
  let SegmentOverlap(left_from:, left_to:, right_from:, right_to:, ..) = overlap
  left_to -. left_from >. minimum_span
  && float.absolute_value(right_to -. right_from) >. minimum_span
}

/// Combine two overlap intervals belonging to the same ordered segment pair.
///
/// Canonical inputs have increasing left parameters, non-zero spans on both
/// segments, and endpoints ordered by the left segment. Intervals merge when
/// they overlap or touch consistently in both parameter spaces. A mismatch
/// between the two parameter spaces or their traversal directions is a
/// contradiction.
pub fn merge_segment_overlaps(
  first: SegmentOverlap,
  second: SegmentOverlap,
  tolerance tolerance: Float,
) -> SegmentOverlapMerge {
  let SegmentOverlap(
    left_from: first_left_from,
    left_to: first_left_to,
    right_from: first_right_from,
    right_to: first_right_to,
    start: first_start,
    end: first_end,
  ) = first
  let SegmentOverlap(
    left_from: second_left_from,
    left_to: second_left_to,
    right_from: second_right_from,
    right_to: second_right_to,
    start: second_start,
    end: second_end,
  ) = second
  let first_right_increases = first_right_to >. first_right_from
  let second_right_increases = second_right_to >. second_right_from
  let valid =
    tolerance >=. 0.0
    && first_left_to -. first_left_from >. tolerance
    && second_left_to -. second_left_from >. tolerance
    && float.absolute_value(first_right_to -. first_right_from) >. tolerance
    && float.absolute_value(second_right_to -. second_right_from) >. tolerance
  case valid {
    False -> Contradiction
    True -> {
      let lefts_touch =
        intervals_touch(
          first_left_from,
          first_left_to,
          second_left_from,
          second_left_to,
          tolerance,
        )
      let rights_touch =
        intervals_touch(
          min_float(first_right_from, first_right_to),
          max_float(first_right_from, first_right_to),
          min_float(second_right_from, second_right_to),
          max_float(second_right_from, second_right_to),
          tolerance,
        )
      case lefts_touch, rights_touch {
        False, False -> Disjoint
        False, True | True, False -> Contradiction
        True, True -> {
          let compatible =
            first_right_increases == second_right_increases
            && parameter_order_compatible(
              first_left_from,
              second_left_from,
              first_right_from,
              second_right_from,
              first_right_increases,
              tolerance,
            )
            && parameter_order_compatible(
              first_left_to,
              second_left_to,
              first_right_to,
              second_right_to,
              first_right_increases,
              tolerance,
            )
            && coincident_boundary_compatible(
              first_left_from,
              second_left_from,
              first_right_from,
              second_right_from,
              first_start,
              second_start,
              tolerance,
            )
            && coincident_boundary_compatible(
              first_left_to,
              second_left_to,
              first_right_to,
              second_right_to,
              first_end,
              second_end,
              tolerance,
            )
            && coincident_boundary_compatible(
              first_left_to,
              second_left_from,
              first_right_to,
              second_right_from,
              first_end,
              second_start,
              tolerance,
            )
            && coincident_boundary_compatible(
              first_left_from,
              second_left_to,
              first_right_from,
              second_right_to,
              first_start,
              second_end,
              tolerance,
            )
          case compatible {
            False -> Contradiction
            True -> {
              let #(left_from, right_from, start) = case
                first_left_from <=. second_left_from
              {
                True -> #(first_left_from, first_right_from, first_start)
                False -> #(second_left_from, second_right_from, second_start)
              }
              let #(left_to, right_to, end) = case
                first_left_to >=. second_left_to
              {
                True -> #(first_left_to, first_right_to, first_end)
                False -> #(second_left_to, second_right_to, second_end)
              }
              Merged(SegmentOverlap(
                left_from:,
                left_to:,
                right_from:,
                right_to:,
                start:,
                end:,
              ))
            }
          }
        }
      }
    }
  }
}

/// Merge every compatible overlap interval for one ordered segment pair.
///
/// Disjoint intervals remain separate. Any contradictory pair rejects the
/// collection.
pub fn merge_segment_overlap_list(
  overlaps: List(SegmentOverlap),
  tolerance tolerance: Float,
) -> Result(List(SegmentOverlap), Nil) {
  merge_segment_overlap_list_loop(overlaps, tolerance, [])
}

fn merge_segment_overlap_list_loop(
  overlaps: List(SegmentOverlap),
  tolerance: Float,
  merged: List(SegmentOverlap),
) -> Result(List(SegmentOverlap), Nil) {
  case overlaps {
    [] -> Ok(list.reverse(merged))
    [first, ..rest] -> {
      use merged <- result.try(insert_segment_overlap(first, merged, tolerance))
      merge_segment_overlap_list_loop(rest, tolerance, merged)
    }
  }
}

fn insert_segment_overlap(
  overlap: SegmentOverlap,
  overlaps: List(SegmentOverlap),
  tolerance: Float,
) -> Result(List(SegmentOverlap), Nil) {
  insert_segment_overlap_loop(overlap, overlaps, tolerance, [])
}

fn insert_segment_overlap_loop(
  overlap: SegmentOverlap,
  overlaps: List(SegmentOverlap),
  tolerance: Float,
  disjoint: List(SegmentOverlap),
) -> Result(List(SegmentOverlap), Nil) {
  case overlaps {
    [] -> Ok([overlap, ..disjoint])
    [first, ..rest] ->
      case merge_segment_overlaps(overlap, first, tolerance:) {
        Contradiction -> Error(Nil)
        Disjoint ->
          insert_segment_overlap_loop(overlap, rest, tolerance, [
            first,
            ..disjoint
          ])
        Merged(combined) ->
          insert_segment_overlap_loop(
            combined,
            list.append(rest, disjoint),
            tolerance,
            [],
          )
      }
  }
}

/// Find sampled overlap intervals proposed by endpoint projections.
///
/// This algorithm assumes non-degenerate segments and that every overlap
/// boundary is an endpoint of at least one input segment.
pub fn segment_overlaps_by_endpoint_projection_with(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance tolerance: Float,
  samples samples: Int,
) -> Result(List(SegmentOverlap), svg_path.Error) {
  use detected <- result.try(overlap_detection.detect_with(
    left,
    right,
    tolerance:,
    samples:,
  ))
  Ok(list.map(detected, raw_overlap))
}

/// Find overlap intervals using the shared five-sample policy.
pub fn segment(
  left: svg_path.Segment,
  right: svg_path.Segment,
) -> Result(List(SegmentOverlap), svg_path.Error) {
  segment_with(left, right, tolerance: default_overlap_tolerance)
}

pub fn segment_with(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance tolerance: Float,
) -> Result(List(SegmentOverlap), svg_path.Error) {
  use detected <- result.try(overlap_detection.detect(left, right, tolerance:))
  Ok(list.map(detected, raw_overlap))
}

fn raw_overlap(raw: overlap_detection.RawOverlap) -> SegmentOverlap {
  let #(left_from, left_to, right_from, right_to, start, end) = raw
  SegmentOverlap(left_from:, left_to:, right_from:, right_to:, start:, end:)
}

/// One continuous overlap between two subpath traversals. Its endpoints retain
/// an address on both subpaths.
pub type SubpathOverlap {
  SubpathOverlap(
    start: svg_path.Point,
    end: svg_path.Point,
    left_from: svg_path.SubpathParameter,
    left_to: svg_path.SubpathParameter,
    right_from: svg_path.SubpathParameter,
    right_to: svg_path.SubpathParameter,
  )
}

pub fn subpath(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
) -> Result(List(SubpathOverlap), svg_path.Error) {
  subpath_with(left, right, tolerance: default_overlap_tolerance)
}

pub fn subpath_with(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
  tolerance tolerance: Float,
) -> Result(List(SubpathOverlap), svg_path.Error) {
  subpath_left_segments(
    svg_path.subpath_segments(left),
    svg_path.subpath_segments(right),
    tolerance,
    left_index: 0,
    found: [],
  )
}

fn subpath_left_segments(
  left: List(svg_path.Segment),
  right: List(svg_path.Segment),
  tolerance: Float,
  left_index left_index: Int,
  found found: List(SubpathOverlap),
) -> Result(List(SubpathOverlap), svg_path.Error) {
  case left {
    [] -> Ok(list.reverse(found))
    [first, ..rest] -> {
      use found <- result.try(subpath_right_segments(
        first,
        right,
        tolerance,
        left_index:,
        right_index: 0,
        found:,
      ))
      subpath_left_segments(
        rest,
        right,
        tolerance,
        left_index: left_index + 1,
        found:,
      )
    }
  }
}

fn subpath_right_segments(
  left: svg_path.Segment,
  right: List(svg_path.Segment),
  tolerance: Float,
  left_index left_index: Int,
  right_index right_index: Int,
  found found: List(SubpathOverlap),
) -> Result(List(SubpathOverlap), svg_path.Error) {
  case right {
    [] -> Ok(found)
    [first, ..rest] -> {
      use segment_overlaps <- result.try(segment_with(left, first, tolerance:))
      let found =
        list.fold(segment_overlaps, found, fn(found, overlap) {
          let SegmentOverlap(
            start:,
            end:,
            left_from:,
            left_to:,
            right_from:,
            right_to:,
          ) = overlap
          [
            SubpathOverlap(
              start:,
              end:,
              left_from: svg_path.SubpathParameter(
                segment_index: left_index,
                t: left_from,
              ),
              left_to: svg_path.SubpathParameter(
                segment_index: left_index,
                t: left_to,
              ),
              right_from: svg_path.SubpathParameter(
                segment_index: right_index,
                t: right_from,
              ),
              right_to: svg_path.SubpathParameter(
                segment_index: right_index,
                t: right_to,
              ),
            ),
            ..found
          ]
        })
      subpath_right_segments(
        left,
        rest,
        tolerance,
        left_index:,
        right_index: right_index + 1,
        found:,
      )
    }
  }
}

fn intervals_touch(
  first_from: Float,
  first_to: Float,
  second_from: Float,
  second_to: Float,
  tolerance: Float,
) -> Bool {
  first_from <=. second_to +. tolerance && second_from <=. first_to +. tolerance
}

fn parameter_order_compatible(
  first_left: Float,
  second_left: Float,
  first_right: Float,
  second_right: Float,
  right_increases: Bool,
  tolerance: Float,
) -> Bool {
  case
    first_left <. second_left -. tolerance,
    first_left >. second_left +. tolerance
  {
    True, _ ->
      case right_increases {
        True -> first_right <=. second_right +. tolerance
        False -> first_right +. tolerance >=. second_right
      }
    _, True ->
      case right_increases {
        True -> first_right +. tolerance >=. second_right
        False -> first_right <=. second_right +. tolerance
      }
    False, False ->
      float.absolute_value(first_right -. second_right) <=. tolerance
  }
}

fn coincident_boundary_compatible(
  first_left: Float,
  second_left: Float,
  first_right: Float,
  second_right: Float,
  first_point: svg_path.Point,
  second_point: svg_path.Point,
  tolerance: Float,
) -> Bool {
  case float.absolute_value(first_left -. second_left) <=. tolerance {
    False -> True
    True ->
      float.absolute_value(first_right -. second_right) <=. tolerance
      && points_near(first_point, second_point, tolerance)
  }
}

fn points_near(
  first: svg_path.Point,
  second: svg_path.Point,
  tolerance: Float,
) -> Bool {
  let dx = first.x -. second.x
  let dy = first.y -. second.y
  dx *. dx +. dy *. dy <=. tolerance *. tolerance
}

fn min_float(a: Float, b: Float) -> Float {
  case a <=. b {
    True -> a
    False -> b
  }
}

fn max_float(a: Float, b: Float) -> Float {
  case a >=. b {
    True -> a
    False -> b
  }
}
