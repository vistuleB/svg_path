//// Discoverable facade for point-intersection queries.
////
//// This module mirrors the root `svg_path` intersection helpers with shorter
//// names. Result types remain the root `svg_path` types, such as
//// `svg_path.SegmentIntersection`, `svg_path.SubpathIntersection`, and
//// `svg_path.PathIntersection`.

import svg_path

/// Return the default options for segment, subpath, and path intersection
/// detection.
pub fn default_options() -> svg_path.IntersectionOptions {
  svg_path.default_intersection_options()
}

/// Return the default options for subpath self-intersection detection.
pub fn default_self_options() -> svg_path.SelfIntersectionOptions {
  svg_path.default_self_intersection_options()
}

/// Return point intersections between two segments.
///
/// Overlapping segments return `OverlappingSegments`, since they have more than
/// a finite list of point intersections.
pub fn segment(
  left: svg_path.Segment,
  right: svg_path.Segment,
) -> Result(List(svg_path.SegmentIntersection), svg_path.Error) {
  svg_path.segment_intersections(left, right)
}

/// Return point intersections between two segments using explicit options.
pub fn segment_with(
  left: svg_path.Segment,
  right: svg_path.Segment,
  options options: svg_path.IntersectionOptions,
) -> Result(List(svg_path.SegmentIntersection), svg_path.Error) {
  svg_path.segment_intersections_with(left, right, options:)
}

/// Return the intersections between a segment and a subpath.
///
/// Each result contains an intersection point, its local parameter on the
/// standalone segment, and every corresponding parameter on the subpath.
pub fn segment_subpath(
  segment: svg_path.Segment,
  subpath: svg_path.Subpath,
) -> Result(
  List(#(svg_path.Point, Float, List(svg_path.SubpathParameter))),
  svg_path.Error,
) {
  svg_path.segment_subpath_intersections(segment, subpath)
}

/// Return the intersections between a segment and a subpath using explicit
/// options.
pub fn segment_subpath_with(
  segment: svg_path.Segment,
  subpath: svg_path.Subpath,
  options options: svg_path.IntersectionOptions,
) -> Result(
  List(#(svg_path.Point, Float, List(svg_path.SubpathParameter))),
  svg_path.Error,
) {
  svg_path.segment_subpath_intersections_with(segment, subpath, options:)
}

/// Return point intersections where a subpath intersects itself.
pub fn subpath_self(
  subpath: svg_path.Subpath,
) -> Result(List(svg_path.SubpathSelfIntersection), svg_path.Error) {
  svg_path.subpath_self_intersections(subpath)
}

/// Return point intersections where a subpath intersects itself using explicit
/// options.
pub fn subpath_self_with(
  subpath: svg_path.Subpath,
  options options: svg_path.SelfIntersectionOptions,
) -> Result(List(svg_path.SubpathSelfIntersection), svg_path.Error) {
  svg_path.subpath_self_intersections_with(subpath, options:)
}

/// Return the point intersections between two subpaths.
pub fn subpath(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
) -> Result(List(svg_path.SubpathIntersection), svg_path.Error) {
  svg_path.subpath_intersections(left, right)
}

/// Return the point intersections between two subpaths using explicit options.
pub fn subpath_with(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
  options options: svg_path.IntersectionOptions,
) -> Result(List(svg_path.SubpathIntersection), svg_path.Error) {
  svg_path.subpath_intersections_with(left, right, options:)
}

/// Return the point intersections between two paths.
pub fn path(
  left: svg_path.Path,
  right: svg_path.Path,
) -> Result(List(svg_path.PathIntersection), svg_path.Error) {
  svg_path.path_intersections(left, right)
}

/// Return the point intersections between two paths using explicit options.
pub fn path_with(
  left: svg_path.Path,
  right: svg_path.Path,
  options options: svg_path.IntersectionOptions,
) -> Result(List(svg_path.PathIntersection), svg_path.Error) {
  svg_path.path_intersections_with(left, right, options:)
}
