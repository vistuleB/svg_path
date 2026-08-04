//// Test-only validation for segment overlaps and encounters.
////
//// These checks validate reported geometry and parameter bookkeeping. They do
//// not attempt to prove overlap maximality or completeness.

import gleam/float
import gleam/list
import gleam/option.{None, Some}
import gleam/order
import gleam/result
import svg_path
import svg_path/encounters
import svg_path/overlaps
import svg_path/point

const samples = [0.0, 0.25, 0.5, 0.75, 1.0]

/// Diagnostic containment of an intersection's two parameter addresses in an
/// overlap's two parameter intervals.
pub type OverlapIntervalContainment {
  NeitherSide
  LeftSideOnly
  RightSideOnly
  BothSides
}

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
          use affine_is_near <- result.try(paired_overlap_samples_are_near(
            left,
            right,
            overlap,
            tolerance,
          ))
          Ok(left_is_near && right_is_near && affine_is_near)
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
  segment_intersection_overlap_interval_containment(intersection, overlap)
  == BothSides
}

pub fn segment_intersection_overlap_interval_containment(
  intersection: svg_path.SegmentIntersection,
  overlap: overlaps.SegmentOverlap,
) -> OverlapIntervalContainment {
  let svg_path.SegmentIntersection(left_t:, right_t:, ..) = intersection
  let overlaps.SegmentOverlap(left_from:, left_to:, right_from:, right_to:, ..) =
    overlap
  classify_interval_containment(
    float_between(left_t, left_from, left_to),
    float_between(right_t, right_from, right_to),
  )
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
      list.all(overlap_intervals, fn(overlap) {
        case
          segment_intersection_overlap_interval_containment(
            intersection,
            overlap,
          )
        {
          NeitherSide -> True
          LeftSideOnly | RightSideOnly -> False
          BothSides ->
            !segment_intersection_follows_overlap_correspondence(
              intersection,
              overlap,
              tolerance,
            )
        }
      })
    })
  Ok(overlaps_valid && intersections_valid && none_contained)
}

fn segment_intersection_follows_overlap_correspondence(
  intersection: svg_path.SegmentIntersection,
  overlap: overlaps.SegmentOverlap,
  tolerance: Float,
) -> Bool {
  let svg_path.SegmentIntersection(left_t:, right_t:, ..) = intersection
  float.absolute_value(
    overlaps.segment_overlap_right_parameter(overlap, left_t) -. right_t,
  )
  <=. tolerance
}

pub fn segment_subpath_overlap_is_valid(
  segment: svg_path.Segment,
  subpath: svg_path.Subpath,
  overlap: overlaps.SegmentSubpathOverlap,
  tolerance tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  let overlaps.SegmentSubpathOverlap(
    start:,
    end:,
    segment_from:,
    segment_to:,
    subpath_from: svg_path.SubpathParameter(
      segment_index: from_index,
      t: from_t,
    ),
    subpath_to: svg_path.SubpathParameter(segment_index: to_index, t: to_t),
  ) = overlap
  case
    from_index == to_index,
    nth(svg_path.subpath_segments(subpath), from_index)
  {
    True, Some(subpath_segment) ->
      segment_overlap_is_valid(
        segment,
        subpath_segment,
        overlaps.SegmentOverlap(
          start:,
          end:,
          left_from: segment_from,
          left_to: segment_to,
          right_from: from_t,
          right_to: to_t,
        ),
        tolerance:,
      )
    _, _ -> Ok(False)
  }
}

pub fn subpath_overlap_is_valid(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
  overlap: overlaps.SubpathOverlap,
  tolerance tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  let overlaps.SubpathOverlap(start:, end:, pieces:) = overlap
  case pieces {
    [] -> Ok(False)
    [first, ..] -> {
      let assert Ok(last) = list.last(pieces)
      let overlaps.SubpathOverlapPiece(
        correspondence: overlaps.SegmentOverlap(start: first_start, ..),
        ..,
      ) = first
      let overlaps.SubpathOverlapPiece(
        correspondence: overlaps.SegmentOverlap(end: last_end, ..),
        ..,
      ) = last
      case
        point.distance(start, first_start) <=. tolerance,
        point.distance(end, last_end) <=. tolerance
      {
        True, True ->
          subpath_overlap_pieces_are_valid(
            svg_path.subpath_segments(left),
            svg_path.subpath_segments(right),
            pieces,
            tolerance,
          )
        _, _ -> Ok(False)
      }
    }
  }
}

fn subpath_overlap_pieces_are_valid(
  left: List(svg_path.Segment),
  right: List(svg_path.Segment),
  pieces: List(overlaps.SubpathOverlapPiece),
  tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  case pieces {
    [] -> Ok(True)
    [piece, ..rest] -> {
      let overlaps.SubpathOverlapPiece(
        left_segment_index:,
        right_segment_index:,
        correspondence:,
      ) = piece
      case nth(left, left_segment_index), nth(right, right_segment_index) {
        Some(left_segment), Some(right_segment) -> {
          use valid <- result.try(segment_overlap_is_valid(
            left_segment,
            right_segment,
            correspondence,
            tolerance:,
          ))
          case valid {
            False -> Ok(False)
            True ->
              subpath_overlap_pieces_are_valid(left, right, rest, tolerance)
          }
        }
        _, _ -> Ok(False)
      }
    }
  }
}

pub fn path_overlap_is_valid(
  left: svg_path.Path,
  right: svg_path.Path,
  overlap: overlaps.PathOverlap,
  tolerance tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  let overlaps.PathOverlap(
    start:,
    end:,
    left_from: svg_path.PathParameter(
      subpath_index: left_from_index,
      at: left_from,
    ),
    left_to: svg_path.PathParameter(subpath_index: left_to_index, at: left_to),
    right_from: svg_path.PathParameter(
      subpath_index: right_from_index,
      at: right_from,
    ),
    right_to: svg_path.PathParameter(
      subpath_index: right_to_index,
      at: right_to,
    ),
  ) = overlap
  case
    left_from_index == left_to_index,
    right_from_index == right_to_index,
    nth(svg_path.path_subpaths(left), left_from_index),
    nth(svg_path.path_subpaths(right), right_from_index)
  {
    True, True, Some(left_subpath), Some(right_subpath) ->
      subpath_overlap_is_valid(
        left_subpath,
        right_subpath,
        overlaps.SubpathOverlap(start:, end:, pieces: [
          overlaps.SubpathOverlapPiece(
            left_segment_index: left_from.segment_index,
            right_segment_index: right_from.segment_index,
            correspondence: overlaps.SegmentOverlap(
              start:,
              end:,
              left_from: left_from.t,
              left_to: left_to.t,
              right_from: right_from.t,
              right_to: right_to.t,
            ),
          ),
        ]),
        tolerance:,
      )
    _, _, _, _ -> Ok(False)
  }
}

pub fn segment_subpath_intersection_is_valid(
  segment: svg_path.Segment,
  subpath: svg_path.Subpath,
  intersection: #(svg_path.Point, Float, List(svg_path.SubpathParameter)),
  tolerance tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  let #(found, segment_t, subpath_parameters) = intersection
  case tolerance <. 0.0 || !in_unit_interval(segment_t), subpath_parameters {
    True, _ | _, [] -> Ok(False)
    False, [_, ..] -> {
      use segment_point <- result.try(svg_path.segment_point(
        segment,
        at: segment_t,
      ))
      use parameters_valid <- result.try(all_subpath_parameters_match(
        subpath,
        subpath_parameters,
        found,
        tolerance,
      ))
      Ok(point.near(segment_point, found, tolerance:) && parameters_valid)
    }
  }
}

pub fn subpath_intersection_is_valid(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
  intersection: svg_path.SubpathIntersection,
  tolerance tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  let svg_path.SubpathIntersection(
    point: found,
    left_parameters:,
    right_parameters:,
  ) = intersection
  case tolerance <. 0.0, left_parameters, right_parameters {
    True, _, _ | _, [], _ | _, _, [] -> Ok(False)
    False, [_, ..], [_, ..] -> {
      use left_valid <- result.try(all_subpath_parameters_match(
        left,
        left_parameters,
        found,
        tolerance,
      ))
      use right_valid <- result.try(all_subpath_parameters_match(
        right,
        right_parameters,
        found,
        tolerance,
      ))
      Ok(left_valid && right_valid)
    }
  }
}

pub fn path_intersection_is_valid(
  left: svg_path.Path,
  right: svg_path.Path,
  intersection: svg_path.PathIntersection,
  tolerance tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  let svg_path.PathIntersection(
    point: found,
    left_parameters:,
    right_parameters:,
  ) = intersection
  case tolerance <. 0.0, left_parameters, right_parameters {
    True, _, _ | _, [], _ | _, _, [] -> Ok(False)
    False, [_, ..], [_, ..] -> {
      use left_valid <- result.try(all_path_parameters_match(
        left,
        left_parameters,
        found,
        tolerance,
      ))
      use right_valid <- result.try(all_path_parameters_match(
        right,
        right_parameters,
        found,
        tolerance,
      ))
      Ok(left_valid && right_valid)
    }
  }
}

pub fn segment_subpath_intersection_is_contained_in_overlap(
  subpath: svg_path.Subpath,
  intersection: #(svg_path.Point, Float, List(svg_path.SubpathParameter)),
  overlap: overlaps.SegmentSubpathOverlap,
) -> Bool {
  segment_subpath_intersection_overlap_interval_containment(
    subpath,
    intersection,
    overlap,
  )
  == BothSides
}

pub fn segment_subpath_intersection_overlap_interval_containment(
  subpath: svg_path.Subpath,
  intersection: #(svg_path.Point, Float, List(svg_path.SubpathParameter)),
  overlap: overlaps.SegmentSubpathOverlap,
) -> OverlapIntervalContainment {
  let #(_, segment_t, subpath_parameters) = intersection
  let overlaps.SegmentSubpathOverlap(
    segment_from:,
    segment_to:,
    subpath_from:,
    subpath_to:,
    ..,
  ) = overlap
  classify_interval_containment(
    float_between(segment_t, segment_from, segment_to),
    list.any(subpath_parameters, subpath_parameter_between(
      subpath,
      _,
      subpath_from,
      subpath_to,
    )),
  )
}

pub fn subpath_intersection_is_contained_in_overlap(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
  intersection: svg_path.SubpathIntersection,
  overlap: overlaps.SubpathOverlap,
) -> Bool {
  subpath_intersection_overlap_interval_containment(
    left,
    right,
    intersection,
    overlap,
  )
  == BothSides
}

pub fn subpath_intersection_overlap_interval_containment(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
  intersection: svg_path.SubpathIntersection,
  overlap: overlaps.SubpathOverlap,
) -> OverlapIntervalContainment {
  let svg_path.SubpathIntersection(left_parameters:, right_parameters:, ..) =
    intersection
  let assert Some(left_from) = overlaps.subpath_overlap_left_start(overlap)
  let assert Some(left_to) = overlaps.subpath_overlap_left_end(overlap)
  let assert Some(right_from) = overlaps.subpath_overlap_right_start(overlap)
  let assert Some(right_to) = overlaps.subpath_overlap_right_end(overlap)
  classify_interval_containment(
    list.any(left_parameters, subpath_parameter_between(
      left,
      _,
      left_from,
      left_to,
    )),
    list.any(right_parameters, subpath_parameter_between(
      right,
      _,
      right_from,
      right_to,
    )),
  )
}

pub fn path_intersection_is_contained_in_overlap(
  left: svg_path.Path,
  right: svg_path.Path,
  intersection: svg_path.PathIntersection,
  overlap: overlaps.PathOverlap,
) -> Bool {
  path_intersection_overlap_interval_containment(
    left,
    right,
    intersection,
    overlap,
  )
  == BothSides
}

pub fn path_intersection_overlap_interval_containment(
  left: svg_path.Path,
  right: svg_path.Path,
  intersection: svg_path.PathIntersection,
  overlap: overlaps.PathOverlap,
) -> OverlapIntervalContainment {
  let svg_path.PathIntersection(left_parameters:, right_parameters:, ..) =
    intersection
  let overlaps.PathOverlap(left_from:, left_to:, right_from:, right_to:, ..) =
    overlap
  classify_interval_containment(
    list.any(left_parameters, path_parameter_between(
      left,
      _,
      left_from,
      left_to,
    )),
    list.any(right_parameters, path_parameter_between(
      right,
      _,
      right_from,
      right_to,
    )),
  )
}

pub fn segment_subpath_encounters_are_valid(
  segment: svg_path.Segment,
  subpath: svg_path.Subpath,
  found: encounters.Encounters(
    overlaps.SegmentSubpathOverlap,
    #(svg_path.Point, Float, List(svg_path.SubpathParameter)),
  ),
  tolerance tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  let encounters.Encounters(overlaps: overlap_intervals, intersections:) = found
  use overlaps_valid <- result.try(all_segment_subpath_overlaps_valid(
    segment,
    subpath,
    overlap_intervals,
    tolerance,
  ))
  use intersections_valid <- result.try(all_segment_subpath_intersections_valid(
    segment,
    subpath,
    intersections,
    tolerance,
  ))
  let none_contained =
    list.all(intersections, fn(intersection) {
      list.all(overlap_intervals, fn(overlap) {
        segment_subpath_intersection_overlap_interval_containment(
          subpath,
          intersection,
          overlap,
        )
        == NeitherSide
      })
    })
  Ok(overlaps_valid && intersections_valid && none_contained)
}

pub fn subpath_encounters_are_valid(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
  found: encounters.Encounters(
    overlaps.SubpathOverlap,
    svg_path.SubpathIntersection,
  ),
  tolerance tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  let encounters.Encounters(overlaps: overlap_intervals, intersections:) = found
  use overlaps_valid <- result.try(all_subpath_overlaps_valid(
    left,
    right,
    overlap_intervals,
    tolerance,
  ))
  use intersections_valid <- result.try(all_subpath_intersections_valid(
    left,
    right,
    intersections,
    tolerance,
  ))
  let none_contained =
    list.all(intersections, fn(intersection) {
      list.all(overlap_intervals, fn(overlap) {
        subpath_intersection_overlap_interval_containment(
          left,
          right,
          intersection,
          overlap,
        )
        == NeitherSide
      })
    })
  Ok(overlaps_valid && intersections_valid && none_contained)
}

pub fn path_encounters_are_valid(
  left: svg_path.Path,
  right: svg_path.Path,
  found: encounters.Encounters(overlaps.PathOverlap, svg_path.PathIntersection),
  tolerance tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  let encounters.Encounters(overlaps: overlap_intervals, intersections:) = found
  use overlaps_valid <- result.try(all_path_overlaps_valid(
    left,
    right,
    overlap_intervals,
    tolerance,
  ))
  use intersections_valid <- result.try(all_path_intersections_valid(
    left,
    right,
    intersections,
    tolerance,
  ))
  let none_contained =
    list.all(intersections, fn(intersection) {
      list.all(overlap_intervals, fn(overlap) {
        path_intersection_overlap_interval_containment(
          left,
          right,
          intersection,
          overlap,
        )
        == NeitherSide
      })
    })
  Ok(overlaps_valid && intersections_valid && none_contained)
}

fn classify_interval_containment(
  left_is_contained: Bool,
  right_is_contained: Bool,
) -> OverlapIntervalContainment {
  case left_is_contained, right_is_contained {
    False, False -> NeitherSide
    True, False -> LeftSideOnly
    False, True -> RightSideOnly
    True, True -> BothSides
  }
}

fn samples_are_near(
  source: svg_path.Segment,
  target: svg_path.Segment,
  tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  samples_are_near_loop(samples, source, target, tolerance)
}

fn paired_overlap_samples_are_near(
  left: svg_path.Segment,
  right: svg_path.Segment,
  overlap: overlaps.SegmentOverlap,
  tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  let overlaps.SegmentOverlap(left_from:, left_to:, ..) = overlap
  paired_overlap_samples_are_near_loop(
    samples,
    left,
    right,
    overlap,
    left_from,
    left_to,
    tolerance,
  )
}

fn paired_overlap_samples_are_near_loop(
  sample_parameters: List(Float),
  left: svg_path.Segment,
  right: svg_path.Segment,
  overlap: overlaps.SegmentOverlap,
  left_from: Float,
  left_to: Float,
  tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  case sample_parameters {
    [] -> Ok(True)
    [portion, ..rest] -> {
      let left_t = left_from +. { left_to -. left_from } *. portion
      let right_t = overlaps.segment_overlap_right_parameter(overlap, left_t)
      use left_point <- result.try(svg_path.segment_point(left, at: left_t))
      use right_point <- result.try(svg_path.segment_point(right, at: right_t))
      case point.near(left_point, right_point, tolerance:) {
        False -> Ok(False)
        True ->
          paired_overlap_samples_are_near_loop(
            rest,
            left,
            right,
            overlap,
            left_from,
            left_to,
            tolerance,
          )
      }
    }
  }
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

fn all_segment_subpath_overlaps_valid(segment, subpath, values, tolerance) {
  case values {
    [] -> Ok(True)
    [first, ..rest] -> {
      use valid <- result.try(segment_subpath_overlap_is_valid(
        segment,
        subpath,
        first,
        tolerance:,
      ))
      case valid {
        False -> Ok(False)
        True ->
          all_segment_subpath_overlaps_valid(segment, subpath, rest, tolerance)
      }
    }
  }
}

fn all_segment_subpath_intersections_valid(
  segment,
  subpath,
  values,
  tolerance,
) {
  case values {
    [] -> Ok(True)
    [first, ..rest] -> {
      use valid <- result.try(segment_subpath_intersection_is_valid(
        segment,
        subpath,
        first,
        tolerance:,
      ))
      case valid {
        False -> Ok(False)
        True ->
          all_segment_subpath_intersections_valid(
            segment,
            subpath,
            rest,
            tolerance,
          )
      }
    }
  }
}

fn all_subpath_overlaps_valid(left, right, values, tolerance) {
  case values {
    [] -> Ok(True)
    [first, ..rest] -> {
      use valid <- result.try(subpath_overlap_is_valid(
        left,
        right,
        first,
        tolerance:,
      ))
      case valid {
        False -> Ok(False)
        True -> all_subpath_overlaps_valid(left, right, rest, tolerance)
      }
    }
  }
}

fn all_subpath_intersections_valid(left, right, values, tolerance) {
  case values {
    [] -> Ok(True)
    [first, ..rest] -> {
      use valid <- result.try(subpath_intersection_is_valid(
        left,
        right,
        first,
        tolerance:,
      ))
      case valid {
        False -> Ok(False)
        True -> all_subpath_intersections_valid(left, right, rest, tolerance)
      }
    }
  }
}

fn all_path_overlaps_valid(left, right, values, tolerance) {
  case values {
    [] -> Ok(True)
    [first, ..rest] -> {
      use valid <- result.try(path_overlap_is_valid(
        left,
        right,
        first,
        tolerance:,
      ))
      case valid {
        False -> Ok(False)
        True -> all_path_overlaps_valid(left, right, rest, tolerance)
      }
    }
  }
}

fn all_path_intersections_valid(left, right, values, tolerance) {
  case values {
    [] -> Ok(True)
    [first, ..rest] -> {
      use valid <- result.try(path_intersection_is_valid(
        left,
        right,
        first,
        tolerance:,
      ))
      case valid {
        False -> Ok(False)
        True -> all_path_intersections_valid(left, right, rest, tolerance)
      }
    }
  }
}

fn all_subpath_parameters_match(subpath, parameters, found, tolerance) {
  case parameters {
    [] -> Ok(True)
    [first, ..rest] -> {
      use evaluated <- result.try(svg_path.subpath_point(subpath, at: first))
      case point.near(evaluated, found, tolerance:) {
        False -> Ok(False)
        True -> all_subpath_parameters_match(subpath, rest, found, tolerance)
      }
    }
  }
}

fn all_path_parameters_match(path, parameters, found, tolerance) {
  case parameters {
    [] -> Ok(True)
    [first, ..rest] -> {
      use evaluated <- result.try(svg_path.path_point(path, at: first))
      case point.near(evaluated, found, tolerance:) {
        False -> Ok(False)
        True -> all_path_parameters_match(path, rest, found, tolerance)
      }
    }
  }
}

fn subpath_parameter_between(subpath, parameter, from, to) {
  parameter_between(
    svg_path.subpath_parameters_compare,
    canonical_subpath_boundary(subpath, parameter),
    canonical_subpath_boundary(subpath, from),
    canonical_subpath_boundary(subpath, to),
  )
}

fn path_parameter_between(path, parameter, from, to) {
  parameter_between(
    svg_path.path_parameters_compare,
    canonical_path_boundary(path, parameter),
    canonical_path_boundary(path, from),
    canonical_path_boundary(path, to),
  )
}

fn canonical_subpath_boundary(subpath, parameter) {
  let svg_path.SubpathParameter(segment_index:, t:) = parameter
  let length = list.length(svg_path.subpath_segments(subpath))
  case
    t == 1.0,
    segment_index >= 0,
    segment_index < length - 1,
    segment_index == length - 1,
    svg_path.subpath_is_closed(subpath)
  {
    True, True, True, _, _ ->
      svg_path.SubpathParameter(segment_index: segment_index + 1, t: 0.0)
    True, True, False, True, True ->
      svg_path.SubpathParameter(segment_index: 0, t: 0.0)
    _, _, _, _, _ -> parameter
  }
}

fn canonical_path_boundary(path, parameter) {
  let svg_path.PathParameter(subpath_index:, at:) = parameter
  case nth(svg_path.path_subpaths(path), subpath_index) {
    Some(subpath) ->
      svg_path.PathParameter(
        subpath_index:,
        at: canonical_subpath_boundary(subpath, at),
      )
    None -> parameter
  }
}

fn parameter_between(compare, parameter, from, to) {
  case compare(from, to) {
    order.Gt ->
      compare(to, parameter) != order.Gt && compare(parameter, from) != order.Gt
    order.Lt | order.Eq ->
      compare(from, parameter) != order.Gt && compare(parameter, to) != order.Gt
  }
}

fn float_between(value, from, to) {
  float_min(from, to) <=. value && value <=. float_max(from, to)
}

fn nth(values: List(a), index: Int) -> option.Option(a) {
  case values, index {
    _, index if index < 0 -> None
    [], _ -> None
    [first, ..], 0 -> Some(first)
    [_, ..rest], index -> nth(rest, index - 1)
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
