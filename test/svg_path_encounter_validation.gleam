//// Test-only validation for segment overlaps and encounters.
////
//// These checks validate reported geometry and parameter bookkeeping. They do
//// not attempt to prove overlap maximality or completeness.

import gleam/list
import gleam/result
import svg_path
import svg_path/encounters
import svg_path/overlaps
import svg_path/point

const samples = [0.0, 0.25, 0.5, 0.75, 1.0]

pub fn segment_overlap_is_valid(
  left: svg_path.Segment,
  right: svg_path.Segment,
  overlap: overlaps.SegmentOverlap,
  tolerance tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  let overlaps.SegmentOverlap(
    left_from:,
    left_to:,
    right_from:,
    right_to:,
    start:,
    end:,
  ) = overlap

  case
    tolerance <. 0.0
    || !in_unit_interval(left_from)
    || !in_unit_interval(left_to)
    || !in_unit_interval(right_from)
    || !in_unit_interval(right_to)
    || left_from >=. left_to
    || right_from == right_to
  {
    True -> Ok(False)
    False -> {
      use left_start <- result.try(svg_path.segment_point(left, at: left_from))
      use left_end <- result.try(svg_path.segment_point(left, at: left_to))
      use right_start <- result.try(svg_path.segment_point(
        right,
        at: right_from,
      ))
      use right_end <- result.try(svg_path.segment_point(right, at: right_to))

      case
        point.near(left_start, start, tolerance:)
        && point.near(right_start, start, tolerance:)
        && point.near(left_end, end, tolerance:)
        && point.near(right_end, end, tolerance:)
      {
        False -> Ok(False)
        True -> {
          use left_portion <- result.try(svg_path.segment_between_inside(
            left,
            from: left_from,
            to: left_to,
          ))
          use right_portion <- result.try(svg_path.segment_between_inside(
            right,
            from: right_from,
            to: right_to,
          ))
          use left_is_near <- result.try(samples_are_near(
            left_portion,
            right_portion,
            tolerance,
          ))
          use right_is_near <- result.try(samples_are_near(
            right_portion,
            left_portion,
            tolerance,
          ))
          Ok(left_is_near && right_is_near)
        }
      }
    }
  }
}

pub fn segment_intersection_is_valid(
  left: svg_path.Segment,
  right: svg_path.Segment,
  intersection: svg_path.SegmentIntersection,
  tolerance tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  let svg_path.SegmentIntersection(left_t:, right_t:, point: found) =
    intersection
  case
    tolerance <. 0.0 || !in_unit_interval(left_t) || !in_unit_interval(right_t)
  {
    True -> Ok(False)
    False -> {
      use left_point <- result.try(svg_path.segment_point(left, at: left_t))
      use right_point <- result.try(svg_path.segment_point(right, at: right_t))
      Ok(
        point.near(left_point, found, tolerance:)
        && point.near(right_point, found, tolerance:),
      )
    }
  }
}

/// Whether both parameters of an intersection belong to an overlap's closed
/// parameter intervals. This is an exact bookkeeping check; geometric
/// tolerance is not used as a parameter tolerance.
pub fn segment_intersection_is_contained_in_overlap(
  intersection: svg_path.SegmentIntersection,
  overlap: overlaps.SegmentOverlap,
) -> Bool {
  let svg_path.SegmentIntersection(left_t:, right_t:, ..) = intersection
  let overlaps.SegmentOverlap(left_from:, left_to:, right_from:, right_to:, ..) =
    overlap
  left_from <=. left_t
  && left_t <=. left_to
  && float_min(right_from, right_to) <=. right_t
  && right_t <=. float_max(right_from, right_to)
}

pub fn segment_encounters_are_valid(
  left: svg_path.Segment,
  right: svg_path.Segment,
  found: encounters.Encounters(
    overlaps.SegmentOverlap,
    svg_path.SegmentIntersection,
  ),
  tolerance tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  let encounters.Encounters(overlaps: overlap_intervals, intersections:) = found
  use overlaps_valid <- result.try(all_overlaps_valid(
    left,
    right,
    overlap_intervals,
    tolerance,
  ))
  use intersections_valid <- result.try(all_intersections_valid(
    left,
    right,
    intersections,
    tolerance,
  ))
  let none_contained =
    list.all(intersections, fn(intersection) {
      !list.any(overlap_intervals, fn(overlap) {
        segment_intersection_is_contained_in_overlap(intersection, overlap)
      })
    })
  Ok(overlaps_valid && intersections_valid && none_contained)
}

fn samples_are_near(
  source: svg_path.Segment,
  target: svg_path.Segment,
  tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  samples_are_near_loop(samples, source, target, tolerance)
}

fn samples_are_near_loop(
  sample_parameters: List(Float),
  source: svg_path.Segment,
  target: svg_path.Segment,
  tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  case sample_parameters {
    [] -> Ok(True)
    [first, ..rest] -> {
      use sample <- result.try(svg_path.segment_point(source, at: first))
      use distance <- result.try(svg_path.segment_distance(sample, to: target))
      case distance <=. tolerance {
        False -> Ok(False)
        True -> samples_are_near_loop(rest, source, target, tolerance)
      }
    }
  }
}

fn all_overlaps_valid(
  left: svg_path.Segment,
  right: svg_path.Segment,
  overlap_intervals: List(overlaps.SegmentOverlap),
  tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  case overlap_intervals {
    [] -> Ok(True)
    [first, ..rest] -> {
      use first_valid <- result.try(segment_overlap_is_valid(
        left,
        right,
        first,
        tolerance:,
      ))
      case first_valid {
        False -> Ok(False)
        True -> all_overlaps_valid(left, right, rest, tolerance)
      }
    }
  }
}

fn all_intersections_valid(
  left: svg_path.Segment,
  right: svg_path.Segment,
  intersections: List(svg_path.SegmentIntersection),
  tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  case intersections {
    [] -> Ok(True)
    [first, ..rest] -> {
      use first_valid <- result.try(segment_intersection_is_valid(
        left,
        right,
        first,
        tolerance:,
      ))
      case first_valid {
        False -> Ok(False)
        True -> all_intersections_valid(left, right, rest, tolerance)
      }
    }
  }
}

fn in_unit_interval(value: Float) -> Bool {
  0.0 <=. value && value <=. 1.0
}

fn float_min(left: Float, right: Float) -> Float {
  case left <=. right {
    True -> left
    False -> right
  }
}

fn float_max(left: Float, right: Float) -> Float {
  case left >=. right {
    True -> left
    False -> right
  }
}
