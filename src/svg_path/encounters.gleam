//// Combined continuous-overlap and isolated point-intersection queries.
////
//// This module composes the existing `svg_path/overlaps` and
//// `svg_path/intersections` results without changing their payload types.

import gleam/float
import gleam/list
import gleam/result
import svg_path
import svg_path/intersections
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
  Ok(Encounters(
    overlaps: overlap_intervals,
    intersections: point_intersections,
  ))
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
      let left_windows = overlap_parameter_windows(overlap_intervals, left: True)
      let right_windows = overlap_parameter_windows(overlap_intervals, left: False)
      use window_intersections <- result.try(intersect_parameter_windows(
        left,
        right,
        left_windows,
        right_windows,
        overlap_intervals,
        options,
        found: [],
      ))
      use overlap_self_intersections <- result.try(
        overlap_off_diagonal_self_intersections(
          left,
          right,
          overlap_intervals,
          tolerance,
        ),
      )
      Ok(
        list.append(window_intersections, overlap_self_intersections)
        |> list.filter(fn(intersection) {
          !intersection_follows_an_overlap(
            intersection,
            overlap_intervals,
            tolerance,
          )
        })
        |> unique_segment_intersections(tolerance)
        |> list.sort(by: fn(a, b) { float.compare(a.left_t, b.left_t) }),
      )
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
      ..
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
    [first, ..rest] ->
      [first, ..unique_parameters_after(rest, previous: first)]
  }
}

fn unique_parameters_after(
  parameters: List(Float),
  previous previous: Float,
) -> List(Float) {
  case parameters {
    [] -> []
    [first, ..rest] -> case first == previous {
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
      use found <- result.try(case windows_follow_an_overlap(
        left_window,
        right_window,
        overlap_intervals,
      ) {
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
          Ok(list.fold(local, found, fn(found, intersection) {
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
          }))
        }
      })
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
      ..
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
  let self_options = svg_path.SelfIntersectionOptions(
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
  let from_left = list.flat_map(overlap_intervals, fn(overlap) {
    list.flat_map(left_self, left_self_intersections_through_overlap(_, overlap))
  })
  let from_right = list.flat_map(overlap_intervals, fn(overlap) {
    list.flat_map(
      right_self,
      right_self_intersections_through_overlap(_, overlap),
    )
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
      True -> Ok(svg_path.SegmentIntersection(
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
      True -> Ok(svg_path.SegmentIntersection(
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
  overlap_intervals: List(overlaps.SegmentOverlap),
  tolerance: Float,
) -> Bool {
  list.any(overlap_intervals, fn(overlap) {
    left_parameter_in_overlap(intersection.left_t, overlap)
    && right_parameter_in_overlap(intersection.right_t, overlap)
    && float.absolute_value(
      overlaps.segment_overlap_right_parameter(overlap, intersection.left_t)
      -. intersection.right_t,
    )
      <=. tolerance
  })
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
  tolerance: Float,
) -> List(svg_path.SegmentIntersection) {
  list.fold(intersections, [], fn(unique, intersection) {
    case list.any(unique, fn(existing) {
      let svg_path.SegmentIntersection(
        left_t: existing_left,
        right_t: existing_right,
        ..
      ) = existing
      let svg_path.SegmentIntersection(left_t:, right_t:, ..) = intersection
      float.absolute_value(existing_left -. left_t) <=. tolerance
      && float.absolute_value(existing_right -. right_t) <=. tolerance
    }) {
      True -> unique
      False -> [intersection, ..unique]
    }
  })
}

fn interpolate(from: Float, to: Float, portion: Float) -> Float {
  from +. { to -. from } *. portion
}

/// Return overlap intervals and point intersections between two subpaths.
///
/// Point intersections are collected from every non-overlapping constituent
/// segment pair. Overlapping pairs contribute only their overlap payloads;
/// results from the two underlying operations are otherwise unchanged.
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
/// `options.tolerance` is also passed unchanged to overlap detection.
pub fn subpath_with(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
  options options: intersections.IntersectionOptions,
) -> Result(
  Encounters(overlaps.SubpathOverlap, svg_path.SubpathIntersection),
  svg_path.Error,
) {
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
