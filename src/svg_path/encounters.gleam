//// Combined continuous-overlap and isolated point-intersection queries.
////
//// This module composes the existing `svg_path/overlaps` and
//// `svg_path/intersections` results without changing their payload types.

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

  case
    intersections.segment_without_overlap_precheck_with(left, right, options:)
  {
    Ok(point_intersections) ->
      Ok(Encounters(
        overlaps: overlap_intervals,
        intersections: point_intersections,
      ))
    Error(svg_path.OverlappingSegments) ->
      case overlap_intervals {
        [_, ..] ->
          Ok(Encounters(overlaps: overlap_intervals, intersections: []))
        [] -> Error(svg_path.InconsistentOverlapClassification)
      }
    Error(error) -> Error(error)
  }
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
