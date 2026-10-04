//// Point containment, winding, and ray crossings.
//// Fill rules are explicit. Boundary points are distinct from inside/outside results.

import svg_path
import svg_path/internal/query

/// Return the default options for segment crossing detection.
pub fn default_crossing_options() -> svg_path.CrossingOptions {
  query.default_crossing_options()
}

/// Return the default options for point containment.
pub fn default_containment_options() -> svg_path.ContainmentOptions {
  query.default_containment_options()
}

/// Find scalar sign-change crossings along a segment using default options.
///
/// This samples `t` in `0.0..1.0`, detects sign changes of `f(segment_point(t))`,
/// and refines each bracket with bisection. It finds crossings visible at the
/// configured sampling resolution; tangent roots and pairs of crossings inside
/// one sample window may be missed.
pub fn segment_crossings(
  segment: svg_path.Segment,
  where f: fn(svg_path.Point) -> Float,
) -> Result(List(Float), svg_path.Error) {
  query.segment_crossings(segment, where: f)
}

/// Find scalar sign-change crossings along a segment using explicit options.
///
/// Once a sign-changing sample window is found, refinement succeeds only when
/// `abs(f(segment_point(t))) <= options.signed_line_distance_tolerance`.
pub fn segment_crossings_with(
  segment: svg_path.Segment,
  where f: fn(svg_path.Point) -> Float,
  options options: svg_path.CrossingOptions,
) -> Result(List(Float), svg_path.Error) {
  svg_path.segment_crossings_with(segment, where: f, options: options)
}

/// Find crossings with a ray's supporting line using default crossing options.
///
/// Like `segment_ray_crossings_with`, this includes negative ray parameters;
/// callers can filter those out when they need only the positive ray.
pub fn segment_ray_crossings(
  segment: svg_path.Segment,
  origin origin: svg_path.Point,
  direction direction: svg_path.Point,
) -> Result(List(#(Float, Float)), svg_path.Error) {
  query.segment_ray_crossings(segment, origin: origin, direction: direction)
}

/// Find crossings between a segment and a ray's supporting line.
///
/// The ray is represented by an origin and a direction vector. Returned values
/// are `#(segment_t, ray_t)` pairs where:
///
/// ```gleam
/// segment_point(segment, at: segment_t)
/// // is approximately
/// origin + ray_t * direction
/// ```
///
/// `ray_t >= 0.0` means the crossing lies on the positive ray. Negative
/// `ray_t` values are returned too, so callers can choose their own filtering
/// policy.
///
/// Unlike `segment_crossings_with`, this splits the segment at projection
/// extrema before refinement, so tangent line contacts are visible without a
/// fixed sampling grid.
pub fn segment_ray_crossings_with(
  segment: svg_path.Segment,
  origin origin: svg_path.Point,
  direction direction: svg_path.Point,
  options options: svg_path.CrossingOptions,
) -> Result(List(#(Float, Float)), svg_path.Error) {
  svg_path.segment_ray_crossings_with(
    segment,
    origin: origin,
    direction: direction,
    options: options,
  )
}

/// Classify a point relative to a subpath's fill area.
///
/// Open and closed subpaths use the same fill geometry: an open subpath is
/// implicitly closed by a straight line from its end to its start. Move-only
/// subpaths have no fill area or boundary.
pub fn subpath_containment(
  point: svg_path.Point,
  within subpath: svg_path.Subpath,
  using fill_rule: svg_path.FillRule,
) -> Result(svg_path.PointContainment, svg_path.Error) {
  query.subpath_containment(point, within: subpath, using: fill_rule)
}

/// Classify a point relative to a subpath's fill area using explicit options.
///
/// `tolerance` is measured in path coordinate units and determines the width
/// classified as `Boundary`. `samples` and `max_iterations` control numerical
/// projection and ray-crossing queries.
pub fn subpath_containment_with(
  point: svg_path.Point,
  within subpath: svg_path.Subpath,
  using fill_rule: svg_path.FillRule,
  options options: svg_path.ContainmentOptions,
) -> Result(svg_path.PointContainment, svg_path.Error) {
  query.subpath_containment_with(
    point,
    within: subpath,
    using: fill_rule,
    options: options,
  )
}

/// Classify a point relative to a path's combined fill area.
///
/// Winding and crossing counts are accumulated across all non-move-only
/// subpaths. Each open subpath is implicitly closed independently. A boundary
/// match on any subpath takes precedence. Empty and move-only paths are
/// `Outside`.
pub fn path_containment(
  point: svg_path.Point,
  within path: svg_path.Path,
  using fill_rule: svg_path.FillRule,
) -> Result(svg_path.PointContainment, svg_path.Error) {
  query.path_containment(point, within: path, using: fill_rule)
}

/// Classify a point relative to a path's combined fill area using explicit
/// options.
pub fn path_containment_with(
  point: svg_path.Point,
  within path: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  options options: svg_path.ContainmentOptions,
) -> Result(svg_path.PointContainment, svg_path.Error) {
  query.path_containment_with(
    point,
    within: path,
    using: fill_rule,
    options: options,
  )
}

/// Return the signed winding number of a path around a point.
///
/// Open subpaths are implicitly closed, matching `path_containment`. If the
/// point is within the boundary tolerance of any non-empty subpath, the result
/// is `BoundaryWinding` because the winding number is not numerically stable at
/// that point.
/// A visually clockwise loop contributes `+1`; a counterclockwise loop
/// contributes `-1`.
pub fn path_winding(
  point: svg_path.Point,
  within path: svg_path.Path,
) -> Result(svg_path.PathWinding, svg_path.Error) {
  query.path_winding(point, within: path)
}

/// Return the signed winding number of a path around a point using explicit
/// containment options.
pub fn path_winding_with(
  point: svg_path.Point,
  within path: svg_path.Path,
  options options: svg_path.ContainmentOptions,
) -> Result(svg_path.PathWinding, svg_path.Error) {
  query.path_winding_with(point, within: path, options: options)
}
