//// Nearest-point projections and closest pairs between geometries.
//// Point queries return an address, point, and distance; pair queries address both operands.

import svg_path
import svg_path/internal/query
import svg_path/intersections

/// Return the default options for point-to-segment distance measurement.
pub fn default_distance_options() -> svg_path.DistanceOptions {
  svg_path.default_distance_options()
}

/// Return the shortest distance from a point to a segment.
///
/// Lines are measured exactly. Quadratic Beziers, cubic Beziers, and arcs are
/// measured by finding stationary points of squared distance in `0.0..1.0`.
pub fn segment_distance(
  point: svg_path.Point,
  to segment: svg_path.Segment,
) -> Result(Float, svg_path.Error) {
  query.segment_distance(point, to: segment)
}

/// Return the shortest distance from a point to a segment using explicit options.
pub fn segment_distance_with(
  point: svg_path.Point,
  to segment: svg_path.Segment,
  options options: svg_path.DistanceOptions,
) -> Result(Float, svg_path.Error) {
  query.segment_distance_with(point, to: segment, options: options)
}

/// Return the nearest point on a segment to an input point.
pub fn segment_projection(
  point: svg_path.Point,
  to segment: svg_path.Segment,
) -> Result(svg_path.SegmentProjection, svg_path.Error) {
  query.segment_projection(point, to: segment)
}

/// Return the nearest point on a segment to an input point using explicit options.
pub fn segment_projection_with(
  point: svg_path.Point,
  to segment: svg_path.Segment,
  options options: svg_path.DistanceOptions,
) -> Result(svg_path.SegmentProjection, svg_path.Error) {
  svg_path.segment_projection_with(point, to: segment, options: options)
}

/// Return the nearest point on a subpath to an input point.
pub fn subpath_projection(
  point: svg_path.Point,
  to subpath: svg_path.Subpath,
) -> Result(svg_path.SubpathProjection, svg_path.Error) {
  svg_path.subpath_projection(point, to: subpath)
}

/// Return the nearest point on a subpath to an input point using explicit options.
pub fn subpath_projection_with(
  point: svg_path.Point,
  to subpath: svg_path.Subpath,
  options options: svg_path.DistanceOptions,
) -> Result(svg_path.SubpathProjection, svg_path.Error) {
  svg_path.subpath_projection_with(point, to: subpath, options: options)
}

/// Return the shortest distance from a point to a subpath.
pub fn subpath_distance(
  point: svg_path.Point,
  to subpath: svg_path.Subpath,
) -> Result(Float, svg_path.Error) {
  query.subpath_distance(point, to: subpath)
}

/// Return the shortest distance from a point to a subpath using explicit
/// options.
pub fn subpath_distance_with(
  point: svg_path.Point,
  to subpath: svg_path.Subpath,
  options options: svg_path.DistanceOptions,
) -> Result(Float, svg_path.Error) {
  query.subpath_distance_with(point, to: subpath, options: options)
}

/// Return the shortest distance from a point to a path.
///
/// Move-only subpaths are skipped.
pub fn path_distance(
  point: svg_path.Point,
  to path: svg_path.Path,
) -> Result(Float, svg_path.Error) {
  query.path_distance(point, to: path)
}

/// Return the shortest distance from a point to a path using explicit options.
pub fn path_distance_with(
  point: svg_path.Point,
  to path: svg_path.Path,
  options options: svg_path.DistanceOptions,
) -> Result(Float, svg_path.Error) {
  query.path_distance_with(point, to: path, options: options)
}

/// Return the nearest point on a path to an input point.
///
/// Move-only subpaths are skipped. An empty path returns `EmptyPath`; a path
/// containing only move-only subpaths returns `EmptySubpaths`.
pub fn path_projection(
  point: svg_path.Point,
  to path: svg_path.Path,
) -> Result(svg_path.PathProjection, svg_path.Error) {
  query.path_projection(point, to: path)
}

/// Return the nearest point on a path to an input point using explicit options.
pub fn path_projection_with(
  point: svg_path.Point,
  to path: svg_path.Path,
  options options: svg_path.DistanceOptions,
) -> Result(svg_path.PathProjection, svg_path.Error) {
  query.path_projection_with(point, to: path, options: options)
}

/// Controls for geometry-to-geometry closest-pair searches.
///
/// Intersection parameter snapping does not apply to distance minimization.
/// Invalid values retain the existing `InvalidIntersectionTolerance` and
/// `InvalidIntersectionMaxDepth` errors from the shared numerical engine.
pub type ClosestPairOptions {
  ClosestPairOptions(
    /// Finite, positive path-coordinate tolerance for overlap detection and
    /// numerical refinement. This is not a certified global distance-error bound.
    tolerance: Float,
    /// Positive search subdivision limit; also bounds boundary projection
    /// refinement. Analytic line-line searches need no subdivision.
    max_depth: Int,
  )
}

/// Default controls for geometry-to-geometry closest-pair searches.
/// The tolerance is `0.000000001` and the maximum subdivision depth is `48`.
pub fn default_closest_pair_options() -> ClosestPairOptions {
  let defaults = intersections.default_options()
  ClosestPairOptions(defaults.tolerance, defaults.max_depth)
}

fn pair_search_options(
  options: ClosestPairOptions,
) -> intersections.IntersectionOptions {
  intersections.IntersectionOptions(
    tolerance: options.tolerance,
    max_depth: options.max_depth,
    parameter_snap: intersections.NoParameterSnap,
  )
}

/// Return one closest-point pair between two segments.
///
/// This uses a distance-minimization search, separate from the bounded
/// intersection search, and returns the best pair even when the segments do
/// not intersect. Overlapping segments return one coincident pair with distance
/// zero. Tied minima need not have canonical parameters.
pub fn segment_segment_closest_pair(
  left: svg_path.Segment,
  right: svg_path.Segment,
) -> Result(svg_path.SegmentSegmentProjection, svg_path.Error) {
  intersections.segment_segment_closest_pair(left, right)
}

/// Return one closest-point pair between two segments using explicit options.
pub fn segment_segment_closest_pair_with(
  left: svg_path.Segment,
  right: svg_path.Segment,
  options options: ClosestPairOptions,
) -> Result(svg_path.SegmentSegmentProjection, svg_path.Error) {
  intersections.segment_segment_closest_pair_with(
    left,
    right,
    options: pair_search_options(options),
  )
}

/// Return one closest-point pair between a segment and a subpath.
pub fn segment_subpath_closest_pair(
  left: svg_path.Segment,
  right: svg_path.Subpath,
) -> Result(svg_path.SegmentSubpathProjection, svg_path.Error) {
  intersections.segment_subpath_closest_pair(left, right)
}

/// Return one closest-point pair between a segment and a subpath using
/// explicit options.
pub fn segment_subpath_closest_pair_with(
  left: svg_path.Segment,
  right: svg_path.Subpath,
  options options: ClosestPairOptions,
) -> Result(svg_path.SegmentSubpathProjection, svg_path.Error) {
  intersections.segment_subpath_closest_pair_with(
    left,
    right,
    options: pair_search_options(options),
  )
}

/// Return one closest-point pair between a segment and a path.
pub fn segment_path_closest_pair(
  left: svg_path.Segment,
  right: svg_path.Path,
) -> Result(svg_path.SegmentPathProjection, svg_path.Error) {
  intersections.segment_path_closest_pair(left, right)
}

/// Return one closest-point pair between a segment and a path using explicit
/// options.
pub fn segment_path_closest_pair_with(
  left: svg_path.Segment,
  right: svg_path.Path,
  options options: ClosestPairOptions,
) -> Result(svg_path.SegmentPathProjection, svg_path.Error) {
  intersections.segment_path_closest_pair_with(
    left,
    right,
    options: pair_search_options(options),
  )
}

/// Return one closest-point pair between two subpaths.
pub fn subpath_subpath_closest_pair(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
) -> Result(svg_path.SubpathSubpathProjection, svg_path.Error) {
  intersections.subpath_subpath_closest_pair(left, right)
}

/// Return one closest-point pair between two subpaths using explicit options.
pub fn subpath_subpath_closest_pair_with(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
  options options: ClosestPairOptions,
) -> Result(svg_path.SubpathSubpathProjection, svg_path.Error) {
  intersections.subpath_subpath_closest_pair_with(
    left,
    right,
    options: pair_search_options(options),
  )
}

/// Return one closest-point pair between a subpath and a path.
pub fn subpath_path_closest_pair(
  left: svg_path.Subpath,
  right: svg_path.Path,
) -> Result(svg_path.SubpathPathProjection, svg_path.Error) {
  intersections.subpath_path_closest_pair(left, right)
}

/// Return one closest-point pair between a subpath and a path using explicit
/// options.
pub fn subpath_path_closest_pair_with(
  left: svg_path.Subpath,
  right: svg_path.Path,
  options options: ClosestPairOptions,
) -> Result(svg_path.SubpathPathProjection, svg_path.Error) {
  intersections.subpath_path_closest_pair_with(
    left,
    right,
    options: pair_search_options(options),
  )
}

/// Return one closest-point pair between two paths.
pub fn path_path_closest_pair(
  left: svg_path.Path,
  right: svg_path.Path,
) -> Result(svg_path.PathPathProjection, svg_path.Error) {
  intersections.path_path_closest_pair(left, right)
}

/// Return one closest-point pair between two paths using explicit options.
pub fn path_path_closest_pair_with(
  left: svg_path.Path,
  right: svg_path.Path,
  options options: ClosestPairOptions,
) -> Result(svg_path.PathPathProjection, svg_path.Error) {
  intersections.path_path_closest_pair_with(
    left,
    right,
    options: pair_search_options(options),
  )
}
