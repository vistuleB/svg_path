//// Combined continuous-overlap and isolated point-intersection queries.
////
//// This module composes the existing `svg_path/overlaps` and
//// `svg_path/intersections` results without changing their payload types.

import gleam/float
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import svg_path
import svg_path/intersections
import svg_path/internal/number
import svg_path/overlaps

/// Continuous overlaps and point intersections reported for one query.
pub type Encounters(overlap, intersection) {
  Encounters(overlaps: List(overlap), intersections: List(intersection))
}

/// Return overlap intervals and point intersections between two segments.
///
/// Results from the underlying operations are returned unchanged. When the
/// existing point solver reports `OverlappingSegments` for a pair already
/// classified as overlapping, it supplied no point-intersection list, so this
/// result contains the detected overlaps and an empty intersection list.
pub fn segment(
  left: svg_path.Segment,
  right: svg_path.Segment,
) -> Result(
  Encounters(overlaps.SegmentOverlap, svg_path.SegmentIntersection),
  svg_path.Error,
) {
  segment_with(left, right, options: intersections.default_options())
}

/// Return segment encounters using explicit intersection options.
///
/// `options.tolerance` is also passed unchanged to overlap detection.
pub fn segment_with(
  left: svg_path.Segment,
  right: svg_path.Segment,
  options options: intersections.IntersectionOptions,
) -> Result(
  Encounters(overlaps.SegmentOverlap, svg_path.SegmentIntersection),
  svg_path.Error,
) {
  use _ <- result.try(intersections.validate_options(options))
  let intersections.IntersectionOptions(tolerance:, ..) = options
  use overlap_intervals <- result.try(overlaps.segment_with(
    left,
    right,
    tolerance:,
  ))

  use point_intersections <- result.try(segment_point_encounters(
    left,
    right,
    overlap_intervals,
    options,
  ))
  Ok(Encounters(overlaps: overlap_intervals, intersections: point_intersections))
}

type ParameterWindow {
  ParameterWindow(from: Float, to: Float)
}

fn segment_point_encounters(
  left: svg_path.Segment,
  right: svg_path.Segment,
  overlap_intervals: List(overlaps.SegmentOverlap),
  options: intersections.IntersectionOptions,
) -> Result(List(svg_path.SegmentIntersection), svg_path.Error) {
  case overlap_intervals {
    [] ->
      intersections.segment_without_overlap_precheck_with(left, right, options:)
    [_, ..] -> {
      let intersections.IntersectionOptions(tolerance:, ..) = options
      let left_windows =
        overlap_parameter_windows(overlap_intervals, left: True)
      let right_windows =
        overlap_parameter_windows(overlap_intervals, left: False)
      use window_intersections <- result.try(
        intersect_parameter_windows(
          left,
          right,
          left_windows,
          right_windows,
          overlap_intervals,
          options,
          found: [],
        ),
      )
      use overlap_self_intersections <- result.try(
        overlap_off_diagonal_self_intersections(
          left,
          right,
          overlap_intervals,
          tolerance,
        ),
      )
      let candidates =
        list.append(window_intersections, overlap_self_intersections)
      use candidates <- result.try(filter_intersections_following_overlaps(
        candidates,
        left,
        right,
        overlap_intervals,
        tolerance,
      ))
      use unique <- result.try(unique_segment_intersections(
        candidates,
        left,
        right,
        tolerance,
      ))
      Ok(list.sort(unique, by: fn(a, b) { float.compare(a.left_t, b.left_t) }))
    }
  }
}

fn overlap_parameter_windows(
  overlap_intervals: List(overlaps.SegmentOverlap),
  left left: Bool,
) -> List(ParameterWindow) {
  overlap_intervals
  |> list.flat_map(fn(overlap) {
    let overlaps.SegmentOverlap(
      left_from:,
      left_to:,
      right_from:,
      right_to:,
      ..,
    ) = overlap
    case left {
      True -> [left_from, left_to]
      False -> [right_from, right_to]
    }
  })
  |> list.append([0.0, 1.0])
  |> list.sort(by: float.compare)
  |> unique_parameters
  |> parameter_windows
}

fn unique_parameters(parameters: List(Float)) -> List(Float) {
  case parameters {
    [] -> []
    [first, ..rest] -> [first, ..unique_parameters_after(rest, previous: first)]
  }
}

fn unique_parameters_after(
  parameters: List(Float),
  previous previous: Float,
) -> List(Float) {
  case parameters {
    [] -> []
    [first, ..rest] ->
      case first == previous {
        True -> unique_parameters_after(rest, previous:)
        False -> [first, ..unique_parameters_after(rest, previous: first)]
      }
  }
}

fn parameter_windows(parameters: List(Float)) -> List(ParameterWindow) {
  case parameters {
    [from, to, ..rest] -> [
      ParameterWindow(from:, to:),
      ..parameter_windows([to, ..rest])
    ]
    _ -> []
  }
}

fn intersect_parameter_windows(
  left: svg_path.Segment,
  right: svg_path.Segment,
  left_windows: List(ParameterWindow),
  right_windows: List(ParameterWindow),
  overlap_intervals: List(overlaps.SegmentOverlap),
  options: intersections.IntersectionOptions,
  found found: List(svg_path.SegmentIntersection),
) -> Result(List(svg_path.SegmentIntersection), svg_path.Error) {
  case left_windows {
    [] -> Ok(found)
    [left_window, ..rest] -> {
      use found <- result.try(intersect_right_parameter_windows(
        left,
        right,
        left_window,
        right_windows,
        overlap_intervals,
        options,
        found,
      ))
      intersect_parameter_windows(
        left,
        right,
        rest,
        right_windows,
        overlap_intervals,
        options,
        found:,
      )
    }
  }
}

fn intersect_right_parameter_windows(
  left: svg_path.Segment,
  right: svg_path.Segment,
  left_window: ParameterWindow,
  right_windows: List(ParameterWindow),
  overlap_intervals: List(overlaps.SegmentOverlap),
  options: intersections.IntersectionOptions,
  found: List(svg_path.SegmentIntersection),
) -> Result(List(svg_path.SegmentIntersection), svg_path.Error) {
  case right_windows {
    [] -> Ok(found)
    [right_window, ..rest] -> {
      use found <- result.try(
        case
          windows_follow_an_overlap(
            left_window,
            right_window,
            overlap_intervals,
          )
        {
          True -> Ok(found)
          False -> {
            let ParameterWindow(from: left_from, to: left_to) = left_window
            let ParameterWindow(from: right_from, to: right_to) = right_window
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
            use local <- result.try(
              intersections.segment_without_overlap_precheck_with(
                left_portion,
                right_portion,
                options:,
              ),
            )
            Ok(
              list.fold(local, found, fn(found, intersection) {
                [
                  svg_path.SegmentIntersection(
                    point: intersection.point,
                    left_t: interpolate(left_from, left_to, intersection.left_t),
                    right_t: interpolate(
                      right_from,
                      right_to,
                      intersection.right_t,
                    ),
                  ),
                  ..found
                ]
              }),
            )
          }
        },
      )
      intersect_right_parameter_windows(
        left,
        right,
        left_window,
        rest,
        overlap_intervals,
        options,
        found,
      )
    }
  }
}

fn windows_follow_an_overlap(
  left: ParameterWindow,
  right: ParameterWindow,
  overlap_intervals: List(overlaps.SegmentOverlap),
) -> Bool {
  let ParameterWindow(from: left_from, to: left_to) = left
  let ParameterWindow(from: right_from, to: right_to) = right
  list.any(overlap_intervals, fn(overlap) {
    let overlaps.SegmentOverlap(
      left_from: overlap_left_from,
      left_to: overlap_left_to,
      right_from: overlap_right_from,
      right_to: overlap_right_to,
      ..,
    ) = overlap
    let mapped_from =
      overlaps.segment_overlap_right_parameter(overlap, left_from)
    let mapped_to = overlaps.segment_overlap_right_parameter(overlap, left_to)
    left_from >=. overlap_left_from
    && left_to <=. overlap_left_to
    && float.min(mapped_from, mapped_to) == right_from
    && float.max(mapped_from, mapped_to) == right_to
    && right_from >=. float.min(overlap_right_from, overlap_right_to)
    && right_to <=. float.max(overlap_right_from, overlap_right_to)
  })
}

fn overlap_off_diagonal_self_intersections(
  left: svg_path.Segment,
  right: svg_path.Segment,
  overlap_intervals: List(overlaps.SegmentOverlap),
  tolerance: Float,
) -> Result(List(svg_path.SegmentIntersection), svg_path.Error) {
  let self_options =
    svg_path.SelfIntersectionOptions(
      minimum_arc_length_separation: tolerance,
      distance_tolerance: tolerance,
    )
  use left_self <- result.try(intersections.segment_self_with(
    left,
    options: self_options,
  ))
  use right_self <- result.try(intersections.segment_self_with(
    right,
    options: self_options,
  ))
  let from_left =
    list.flat_map(overlap_intervals, fn(overlap) {
      list.flat_map(left_self, left_self_intersections_through_overlap(
        _,
        overlap,
      ))
    })
  let from_right =
    list.flat_map(overlap_intervals, fn(overlap) {
      list.flat_map(right_self, right_self_intersections_through_overlap(
        _,
        overlap,
      ))
    })
  Ok(list.append(from_left, from_right))
}

fn left_self_intersections_through_overlap(
  intersection: svg_path.SegmentIntersection,
  overlap: overlaps.SegmentOverlap,
) -> List(svg_path.SegmentIntersection) {
  let svg_path.SegmentIntersection(point:, left_t: first, right_t: second) =
    intersection
  [#(first, second), #(second, first)]
  |> list.filter_map(fn(parameters) {
    let #(through_overlap, remaining_left) = parameters
    case left_parameter_in_overlap(through_overlap, overlap) {
      False -> Error(Nil)
      True ->
        Ok(svg_path.SegmentIntersection(
          point:,
          left_t: remaining_left,
          right_t: overlaps.segment_overlap_right_parameter(
            overlap,
            through_overlap,
          ),
        ))
    }
  })
}

fn right_self_intersections_through_overlap(
  intersection: svg_path.SegmentIntersection,
  overlap: overlaps.SegmentOverlap,
) -> List(svg_path.SegmentIntersection) {
  let svg_path.SegmentIntersection(point:, left_t: first, right_t: second) =
    intersection
  [#(first, second), #(second, first)]
  |> list.filter_map(fn(parameters) {
    let #(through_overlap, remaining_right) = parameters
    case right_parameter_in_overlap(through_overlap, overlap) {
      False -> Error(Nil)
      True ->
        Ok(svg_path.SegmentIntersection(
          point:,
          left_t: overlaps.segment_overlap_left_parameter(
            overlap,
            through_overlap,
          ),
          right_t: remaining_right,
        ))
    }
  })
}

fn intersection_follows_an_overlap(
  intersection: svg_path.SegmentIntersection,
  left: svg_path.Segment,
  right: svg_path.Segment,
  overlap_intervals: List(overlaps.SegmentOverlap),
  tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  case overlap_intervals {
    [] -> Ok(False)
    [overlap, ..rest] ->
      case
        left_parameter_in_overlap(intersection.left_t, overlap)
        && right_parameter_in_overlap(intersection.right_t, overlap)
      {
        False ->
          intersection_follows_an_overlap(
            intersection,
            left,
            right,
            rest,
            tolerance,
          )
        True -> {
          let mapped_right =
            overlaps.segment_overlap_right_parameter(
              overlap,
              intersection.left_t,
            )
          let mapped_left =
            overlaps.segment_overlap_left_parameter(
              overlap,
              intersection.right_t,
            )
          use left_stalled <- result.try(segment_parameters_are_stalled(
            left,
            intersection.left_t,
            mapped_left,
            tolerance,
          ))
          use right_stalled <- result.try(segment_parameters_are_stalled(
            right,
            intersection.right_t,
            mapped_right,
            tolerance,
          ))
          case left_stalled && right_stalled {
            True -> Ok(True)
            False ->
              intersection_follows_an_overlap(
                intersection,
                left,
                right,
                rest,
                tolerance,
              )
          }
        }
      }
  }
}

fn filter_intersections_following_overlaps(
  intersections: List(svg_path.SegmentIntersection),
  left: svg_path.Segment,
  right: svg_path.Segment,
  overlap_intervals: List(overlaps.SegmentOverlap),
  tolerance: Float,
) -> Result(List(svg_path.SegmentIntersection), svg_path.Error) {
  case intersections {
    [] -> Ok([])
    [intersection, ..rest] -> {
      use follows <- result.try(intersection_follows_an_overlap(
        intersection,
        left,
        right,
        overlap_intervals,
        tolerance,
      ))
      use rest <- result.try(filter_intersections_following_overlaps(
        rest,
        left,
        right,
        overlap_intervals,
        tolerance,
      ))
      case follows {
        True -> Ok(rest)
        False -> Ok([intersection, ..rest])
      }
    }
  }
}

fn left_parameter_in_overlap(
  parameter: Float,
  overlap: overlaps.SegmentOverlap,
) -> Bool {
  let overlaps.SegmentOverlap(left_from:, left_to:, ..) = overlap
  parameter >=. left_from && parameter <=. left_to
}

fn right_parameter_in_overlap(
  parameter: Float,
  overlap: overlaps.SegmentOverlap,
) -> Bool {
  let overlaps.SegmentOverlap(right_from:, right_to:, ..) = overlap
  parameter >=. float.min(right_from, right_to)
  && parameter <=. float.max(right_from, right_to)
}

fn unique_segment_intersections(
  intersections: List(svg_path.SegmentIntersection),
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
) -> Result(List(svg_path.SegmentIntersection), svg_path.Error) {
  unique_segment_intersections_loop(intersections, [], left, right, tolerance)
}

fn unique_segment_intersections_loop(
  intersections: List(svg_path.SegmentIntersection),
  unique: List(svg_path.SegmentIntersection),
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
) -> Result(List(svg_path.SegmentIntersection), svg_path.Error) {
  case intersections {
    [] -> Ok(unique)
    [intersection, ..rest] -> {
      use duplicate <- result.try(intersection_has_geometric_duplicate(
        intersection,
        unique,
        left,
        right,
        tolerance,
      ))
      unique_segment_intersections_loop(
        rest,
        case duplicate {
          True -> unique
          False -> [intersection, ..unique]
        },
        left,
        right,
        tolerance,
      )
    }
  }
}

fn intersection_has_geometric_duplicate(
  intersection: svg_path.SegmentIntersection,
  existing: List(svg_path.SegmentIntersection),
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  case existing {
    [] -> Ok(False)
    [candidate, ..rest] -> {
      use left_stalled <- result.try(segment_parameters_are_stalled(
        left,
        candidate.left_t,
        intersection.left_t,
        tolerance,
      ))
      use right_stalled <- result.try(segment_parameters_are_stalled(
        right,
        candidate.right_t,
        intersection.right_t,
        tolerance,
      ))
      case left_stalled && right_stalled {
        True -> Ok(True)
        False ->
          intersection_has_geometric_duplicate(
            intersection,
            rest,
            left,
            right,
            tolerance,
          )
      }
    }
  }
}

fn segment_parameters_are_stalled(
  segment: svg_path.Segment,
  first: Float,
  second: Float,
  tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  case first == second {
    True -> Ok(True)
    False -> {
      use portion <- result.try(svg_path.segment_between_inside(
        segment,
        from: float.min(first, second),
        to: float.max(first, second),
      ))
      use motion <- result.try(svg_path.segment_length(portion))
      Ok(motion <=. tolerance)
    }
  }
}

fn interpolate(from: Float, to: Float, portion: Float) -> Float {
  from +. { to -. from } *. portion
}

fn subpath_arc_length_between_parameters(
  subpath: svg_path.Subpath,
  from: svg_path.SubpathParameter,
  to: svg_path.SubpathParameter,
) -> Result(Float, svg_path.Error) {
  use from <- result.try(svg_path.subpath_parameter_canonicalize(
    subpath,
    parameter: from,
  ))
  use to <- result.try(svg_path.subpath_parameter_canonicalize(
    subpath,
    parameter: to,
  ))
  case from == to {
    True -> Ok(0.0)
    False -> {
      use portion <- result.try(svg_path.subpath_between(subpath, from:, to:))
      svg_path.subpath_length(portion)
    }
  }
}

fn subpath_parameters_are_stalled(
  subpath: svg_path.Subpath,
  first: svg_path.SubpathParameter,
  second: svg_path.SubpathParameter,
  tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  use first <- result.try(svg_path.subpath_parameter_canonicalize(
    subpath,
    parameter: first,
  ))
  use second <- result.try(svg_path.subpath_parameter_canonicalize(
    subpath,
    parameter: second,
  ))
  case first == second, svg_path.subpath_is_closed(subpath) {
    True, _ -> Ok(True)
    False, False -> {
      let #(from, to) = case
        svg_path.subpath_parameters_compare(first, second)
      {
        order.Gt -> #(second, first)
        _ -> #(first, second)
      }
      use motion <- result.try(subpath_arc_length_between_parameters(
        subpath,
        from,
        to,
      ))
      Ok(motion <=. tolerance)
    }
    False, True -> {
      use forward <- result.try(subpath_arc_length_between_parameters(
        subpath,
        first,
        second,
      ))
      use reverse <- result.try(subpath_arc_length_between_parameters(
        subpath,
        second,
        first,
      ))
      Ok(float.min(forward, reverse) <=. tolerance)
    }
  }
}

fn clamp_subpath_parameter_to_overlap(
  parameter: svg_path.SubpathParameter,
  subpath: svg_path.Subpath,
  overlap: overlaps.SubpathOverlap,
  left left: Bool,
  tolerance tolerance: Float,
  other_subpath other_subpath: svg_path.Subpath,
) -> Result(Option(svg_path.SubpathParameter), svg_path.Error) {
  use inside <- result.try(case left {
    True ->
      overlaps.subpath_overlap_right_parameter(
        overlap,
        parameter,
        left_subpath: subpath,
        right_subpath: other_subpath,
      )
    False ->
      overlaps.subpath_overlap_left_parameter(
        overlap,
        parameter,
        left_subpath: other_subpath,
        right_subpath: subpath,
      )
  })
  case inside {
    Some(_) -> Ok(Some(parameter))
    None -> {
      let #(from, to) = case left {
        True -> #(
          overlaps.subpath_overlap_left_start(overlap),
          overlaps.subpath_overlap_left_end(overlap),
        )
        False -> #(
          overlaps.subpath_overlap_right_start(overlap),
          overlaps.subpath_overlap_right_end(overlap),
        )
      }
      case from, to {
        Some(from), Some(to) -> {
          use from_stalled <- result.try(subpath_parameters_are_stalled(
            subpath,
            parameter,
            from,
            tolerance,
          ))
          use to_stalled <- result.try(subpath_parameters_are_stalled(
            subpath,
            parameter,
            to,
            tolerance,
          ))
          case from_stalled, to_stalled {
            False, False -> Ok(None)
            True, False -> Ok(Some(from))
            False, True -> Ok(Some(to))
            True, True -> {
              use from_motion <- result.try(shortest_subpath_parameter_motion(
                subpath,
                parameter,
                from,
              ))
              use to_motion <- result.try(shortest_subpath_parameter_motion(
                subpath,
                parameter,
                to,
              ))
              Ok(
                Some(case from_motion <=. to_motion {
                  True -> from
                  False -> to
                }),
              )
            }
          }
        }
        _, _ -> Ok(None)
      }
    }
  }
}

fn shortest_subpath_parameter_motion(
  subpath: svg_path.Subpath,
  first: svg_path.SubpathParameter,
  second: svg_path.SubpathParameter,
) -> Result(Float, svg_path.Error) {
  case svg_path.subpath_is_closed(subpath) {
    True -> {
      use forward <- result.try(subpath_arc_length_between_parameters(
        subpath,
        first,
        second,
      ))
      use reverse <- result.try(subpath_arc_length_between_parameters(
        subpath,
        second,
        first,
      ))
      Ok(float.min(forward, reverse))
    }
    False -> {
      let #(from, to) = case
        svg_path.subpath_parameters_compare(first, second)
      {
        order.Gt -> #(second, first)
        _ -> #(first, second)
      }
      subpath_arc_length_between_parameters(subpath, from, to)
    }
  }
}

/// Return whether two subpath parameters are complementary through one
/// continuous overlap.
///
/// Parameters may move onto the overlap only when their intervening subpath
/// arc length is at most `tolerance`. Exact opposite addresses are obtained
/// from the overlap's piecewise-affine correspondence. This geometric clamp is
/// distinct from parameter-space snapping: for an open subpath it measures the
/// only traversal interval between the addresses; for a closed subpath it uses
/// the shorter of the two directed arc lengths.
fn subpath_parameters_are_complementary_with_overlap(
  left_parameter: svg_path.SubpathParameter,
  right_parameter: svg_path.SubpathParameter,
  left_subpath: svg_path.Subpath,
  right_subpath: svg_path.Subpath,
  overlap: overlaps.SubpathOverlap,
  tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  use _ <- result.try(validate_complementarity_tolerance(tolerance))
  use left_clamped <- result.try(clamp_subpath_parameter_to_overlap(
    left_parameter,
    left_subpath,
    overlap,
    left: True,
    tolerance:,
    other_subpath: right_subpath,
  ))
  use right_clamped <- result.try(clamp_subpath_parameter_to_overlap(
    right_parameter,
    right_subpath,
    overlap,
    left: False,
    tolerance:,
    other_subpath: left_subpath,
  ))
  use left_to_right <- result.try(case left_clamped {
    None -> Ok(False)
    Some(left_clamped) -> {
      use opposite <- result.try(overlaps.subpath_overlap_right_parameter(
        overlap,
        left_clamped,
        left_subpath:,
        right_subpath:,
      ))
      case opposite {
        None -> Ok(False)
        Some(opposite) ->
          subpath_parameters_are_stalled(
            right_subpath,
            opposite,
            right_parameter,
            tolerance,
          )
      }
    }
  })
  use right_to_left <- result.try(case right_clamped {
    None -> Ok(False)
    Some(right_clamped) -> {
      use opposite <- result.try(overlaps.subpath_overlap_left_parameter(
        overlap,
        right_clamped,
        left_subpath:,
        right_subpath:,
      ))
      case opposite {
        None -> Ok(False)
        Some(opposite) ->
          subpath_parameters_are_stalled(
            left_subpath,
            opposite,
            left_parameter,
            tolerance,
          )
      }
    }
  })
  case left_to_right, right_to_left {
    True, True -> Ok(True)
    False, False -> Ok(False)
    _, _ -> Error(svg_path.InternalOverlapParameterCorrespondenceInconsistency)
  }
}

/// Return whether any overlap makes two subpath parameters complementary.
fn subpath_parameters_are_complementary(
  left_parameter: svg_path.SubpathParameter,
  right_parameter: svg_path.SubpathParameter,
  left_subpath: svg_path.Subpath,
  right_subpath: svg_path.Subpath,
  overlap_intervals: List(overlaps.SubpathOverlap),
  tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  use _ <- result.try(validate_complementarity_tolerance(tolerance))
  subpath_parameters_are_complementary_loop(
    left_parameter,
    right_parameter,
    left_subpath,
    right_subpath,
    overlap_intervals,
    tolerance,
    saw_inconsistency: False,
  )
}

fn validate_complementarity_tolerance(
  tolerance: Float,
) -> Result(Nil, svg_path.Error) {
  case tolerance >. 0.0 && number.is_finite(tolerance) {
    True -> Ok(Nil)
    False -> Error(svg_path.InvalidIntersectionTolerance(tolerance))
  }
}

fn subpath_parameters_are_complementary_loop(
  left_parameter: svg_path.SubpathParameter,
  right_parameter: svg_path.SubpathParameter,
  left_subpath: svg_path.Subpath,
  right_subpath: svg_path.Subpath,
  overlap_intervals: List(overlaps.SubpathOverlap),
  tolerance: Float,
  saw_inconsistency saw_inconsistency: Bool,
) -> Result(Bool, svg_path.Error) {
  case overlap_intervals {
    [] ->
      case saw_inconsistency {
        True ->
          Error(svg_path.InternalOverlapParameterCorrespondenceInconsistency)
        False -> Ok(False)
      }
    [overlap, ..rest] ->
      case
        subpath_parameters_are_complementary_with_overlap(
          left_parameter,
          right_parameter,
          left_subpath,
          right_subpath,
          overlap,
          tolerance,
        )
      {
        Ok(True) -> Ok(True)
        Ok(False) ->
          subpath_parameters_are_complementary_loop(
            left_parameter,
            right_parameter,
            left_subpath,
            right_subpath,
            rest,
            tolerance,
            saw_inconsistency:,
          )
        Error(svg_path.InternalOverlapParameterCorrespondenceInconsistency) ->
          subpath_parameters_are_complementary_loop(
            left_parameter,
            right_parameter,
            left_subpath,
            right_subpath,
            rest,
            tolerance,
            saw_inconsistency: True,
          )
        Error(error) -> Error(error)
      }
  }
}

/// Remove parameter addresses explained entirely by continuous overlaps.
///
/// A left parameter is retained when at least one original right parameter is
/// not complementary to it through any overlap. Right parameters are treated
/// symmetrically against the original left parameter list. If no parameters
/// remain on either side, the whole point intersection is removed.
fn filter_subpath_intersection_overlap_derived_parameters(
  intersection: svg_path.SubpathIntersection,
  left_subpath: svg_path.Subpath,
  right_subpath: svg_path.Subpath,
  overlap_intervals: List(overlaps.SubpathOverlap),
  tolerance: Float,
) -> Result(Option(svg_path.SubpathIntersection), svg_path.Error) {
  let svg_path.SubpathIntersection(point:, left_parameters:, right_parameters:) =
    intersection
  use kept_left <- result.try(filter_non_complementary_parameters(
    left_parameters,
    right_parameters,
    left_subpath,
    right_subpath,
    overlap_intervals,
    tolerance,
    filtering_left: True,
  ))
  use kept_right <- result.try(filter_non_complementary_parameters(
    right_parameters,
    left_parameters,
    right_subpath,
    left_subpath,
    overlap_intervals,
    tolerance,
    filtering_left: False,
  ))
  case kept_left, kept_right {
    [], [] -> Ok(None)
    _, _ ->
      Ok(
        Some(svg_path.SubpathIntersection(
          point:,
          left_parameters: kept_left,
          right_parameters: kept_right,
        )),
      )
  }
}

fn filter_non_complementary_parameters(
  parameters: List(svg_path.SubpathParameter),
  opposite_parameters: List(svg_path.SubpathParameter),
  subpath: svg_path.Subpath,
  opposite_subpath: svg_path.Subpath,
  overlap_intervals: List(overlaps.SubpathOverlap),
  tolerance: Float,
  filtering_left filtering_left: Bool,
) -> Result(List(svg_path.SubpathParameter), svg_path.Error) {
  case parameters {
    [] -> Ok([])
    [parameter, ..rest] -> {
      use keep <- result.try(parameter_has_non_complementary_opposite(
        parameter,
        opposite_parameters,
        subpath,
        opposite_subpath,
        overlap_intervals,
        tolerance,
        filtering_left:,
      ))
      use kept_rest <- result.try(filter_non_complementary_parameters(
        rest,
        opposite_parameters,
        subpath,
        opposite_subpath,
        overlap_intervals,
        tolerance,
        filtering_left:,
      ))
      case keep {
        True -> Ok([parameter, ..kept_rest])
        False -> Ok(kept_rest)
      }
    }
  }
}

fn parameter_has_non_complementary_opposite(
  parameter: svg_path.SubpathParameter,
  opposite_parameters: List(svg_path.SubpathParameter),
  subpath: svg_path.Subpath,
  opposite_subpath: svg_path.Subpath,
  overlap_intervals: List(overlaps.SubpathOverlap),
  tolerance: Float,
  filtering_left filtering_left: Bool,
) -> Result(Bool, svg_path.Error) {
  case opposite_parameters {
    [] -> Ok(False)
    [opposite, ..rest] -> {
      use complementary <- result.try(case filtering_left {
        True ->
          subpath_parameters_are_complementary(
            parameter,
            opposite,
            subpath,
            opposite_subpath,
            overlap_intervals,
            tolerance,
          )
        False ->
          subpath_parameters_are_complementary(
            opposite,
            parameter,
            opposite_subpath,
            subpath,
            overlap_intervals,
            tolerance,
          )
      })
      use rest_has_non_complementary <- result.try(
        parameter_has_non_complementary_opposite(
          parameter,
          rest,
          subpath,
          opposite_subpath,
          overlap_intervals,
          tolerance,
          filtering_left:,
        ),
      )
      Ok(!complementary || rest_has_non_complementary)
    }
  }
}

fn filter_subpath_intersections(
  intersections: List(svg_path.SubpathIntersection),
  left_subpath: svg_path.Subpath,
  right_subpath: svg_path.Subpath,
  overlap_intervals: List(overlaps.SubpathOverlap),
  tolerance: Float,
) -> Result(List(svg_path.SubpathIntersection), svg_path.Error) {
  case intersections {
    [] -> Ok([])
    [intersection, ..rest] -> {
      use filtered <- result.try(
        filter_subpath_intersection_overlap_derived_parameters(
          intersection,
          left_subpath,
          right_subpath,
          overlap_intervals,
          tolerance,
        ),
      )
      use filtered_rest <- result.try(filter_subpath_intersections(
        rest,
        left_subpath,
        right_subpath,
        overlap_intervals,
        tolerance,
      ))
      case filtered {
        None -> Ok(filtered_rest)
        Some(intersection) -> Ok([intersection, ..filtered_rest])
      }
    }
  }
}

/// Remove intersection parameters explained entirely by the continuous
/// overlaps in an existing subpath encounter result.
///
/// This is an optional derived view. The ordinary subpath encounter functions
/// return their complete, unfiltered point-intersection results. A parameter is
/// removed only when it is complementary, after arc-length clamping by
/// `tolerance`, to every parameter on the opposite side. Both sides are
/// filtered against the original parameter lists.
pub fn filter_fully_overlap_explained_subpath_intersection_parameters(
  encounters: Encounters(overlaps.SubpathOverlap, svg_path.SubpathIntersection),
  left_subpath: svg_path.Subpath,
  right_subpath: svg_path.Subpath,
  tolerance: Float,
) -> Result(
  Encounters(overlaps.SubpathOverlap, svg_path.SubpathIntersection),
  svg_path.Error,
) {
  use _ <- result.try(validate_complementarity_tolerance(tolerance))
  let Encounters(overlaps: overlap_intervals, intersections:) = encounters
  use intersections <- result.try(filter_subpath_intersections(
    intersections,
    left_subpath,
    right_subpath,
    overlap_intervals,
    tolerance,
  ))
  Ok(Encounters(overlaps: overlap_intervals, intersections:))
}

/// Return overlap intervals and point intersections between two subpaths.
///
/// Point intersections are collected from every constituent segment pair.
/// Overlap-boundary intersections are retained; use
/// `filter_fully_overlap_explained_subpath_intersection_parameters` to derive
/// a filtered view.
pub fn subpath(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
) -> Result(
  Encounters(overlaps.SubpathOverlap, svg_path.SubpathIntersection),
  svg_path.Error,
) {
  subpath_with(left, right, options: intersections.default_options())
}

/// Return subpath encounters using explicit intersection options.
///
/// `options.tolerance` is passed unchanged to overlap detection.
pub fn subpath_with(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
  options options: intersections.IntersectionOptions,
) -> Result(
  Encounters(overlaps.SubpathOverlap, svg_path.SubpathIntersection),
  svg_path.Error,
) {
  use _ <- result.try(intersections.validate_options(options))
  let intersections.IntersectionOptions(tolerance:, ..) = options
  use overlap_intervals <- result.try(overlaps.subpath_with(
    left,
    right,
    tolerance:,
  ))
  use point_intersections <- result.try(
    intersections.subpath_without_overlap_precheck_with(left, right, options:),
  )
  Ok(Encounters(overlaps: overlap_intervals, intersections: point_intersections))
}

/// Return overlap intervals and point intersections between a standalone
/// segment and a subpath.
pub fn segment_subpath(
  segment: svg_path.Segment,
  subpath: svg_path.Subpath,
) -> Result(
  Encounters(
    overlaps.SegmentSubpathOverlap,
    #(svg_path.Point, Float, List(svg_path.SubpathParameter)),
  ),
  svg_path.Error,
) {
  segment_subpath_with(
    segment,
    subpath,
    options: intersections.default_options(),
  )
}

/// Return segment-subpath encounters using explicit intersection options.
pub fn segment_subpath_with(
  segment: svg_path.Segment,
  subpath: svg_path.Subpath,
  options options: intersections.IntersectionOptions,
) -> Result(
  Encounters(
    overlaps.SegmentSubpathOverlap,
    #(svg_path.Point, Float, List(svg_path.SubpathParameter)),
  ),
  svg_path.Error,
) {
  use _ <- result.try(intersections.validate_options(options))
  let intersections.IntersectionOptions(tolerance:, ..) = options
  use overlap_intervals <- result.try(overlaps.segment_subpath_with(
    segment,
    subpath,
    tolerance:,
  ))
  use point_intersections <- result.try(
    intersections.segment_subpath_without_overlap_precheck_with(
      segment,
      subpath,
      options:,
    ),
  )
  Ok(Encounters(overlaps: overlap_intervals, intersections: point_intersections))
}

/// Return overlap intervals and point intersections between two paths.
pub fn path(
  left: svg_path.Path,
  right: svg_path.Path,
) -> Result(
  Encounters(overlaps.PathOverlap, svg_path.PathIntersection),
  svg_path.Error,
) {
  path_with(left, right, options: intersections.default_options())
}

/// Return path encounters using explicit intersection options.
pub fn path_with(
  left: svg_path.Path,
  right: svg_path.Path,
  options options: intersections.IntersectionOptions,
) -> Result(
  Encounters(overlaps.PathOverlap, svg_path.PathIntersection),
  svg_path.Error,
) {
  use _ <- result.try(intersections.validate_options(options))
  let intersections.IntersectionOptions(tolerance:, ..) = options
  use overlap_intervals <- result.try(overlaps.path_with(
    left,
    right,
    tolerance:,
  ))
  use point_intersections <- result.try(
    intersections.path_without_overlap_precheck_with(left, right, options:),
  )
  Ok(Encounters(overlaps: overlap_intervals, intersections: point_intersections))
}
