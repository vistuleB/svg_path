//// Arc length, distance-addressed evaluation, and subdivision.
//// Distances are in path-coordinate units; segment parameters are not length fractions.

import svg_path
import svg_path/internal/query

/// Return the default options for segment and subpath length approximation.
pub fn default_length_options() -> svg_path.LengthOptions {
  query.default_length_options()
}

/// Return the distance between a segment's start and end points.
///
/// This is the endpoint chord length. It can be zero even when a curve has
/// nonzero interior geometry.
pub fn segment_chord_length(segment: svg_path.Segment) -> Float {
  query.segment_chord_length(segment)
}

/// Return the squared distance between a segment's start and end points.
///
/// This is the square of the endpoint chord length. It can be zero even when a
/// curve has nonzero interior geometry.
pub fn segment_chord_length_squared(segment: svg_path.Segment) -> Float {
  query.segment_chord_length_squared(segment)
}

/// Return the approximate length of a segment.
///
/// Lines are measured exactly. Quadratic Beziers, cubic Beziers, and arcs are
/// approximated by adaptive Simpson integration of segment speed.
pub fn segment_length(
  segment: svg_path.Segment,
) -> Result(Float, svg_path.Error) {
  query.segment_length(segment)
}

/// Return a cheap upper bound on a segment's length.
///
/// Lines use their chord length. Beziers use the sum of their control-polygon
/// edge lengths. Arcs use absolute angular travel in radians times the larger
/// corrected ellipse radius. No numerical integration or subdivision is used.
/// These mathematical upper bounds are evaluated with ordinary floating-point
/// arithmetic, not outward-rounded interval arithmetic, and can substantially
/// overestimate length. Arcs rejected by `arc_center_data` return
/// `DegenerateArc`; see that function for endpoint and radius restrictions.
pub fn segment_length_upper_bound(
  segment: svg_path.Segment,
) -> Result(Float, svg_path.Error) {
  query.segment_length_upper_bound(segment)
}

/// Return the approximate length of a segment using explicit options.
pub fn segment_length_with(
  segment: svg_path.Segment,
  options options: svg_path.LengthOptions,
) -> Result(Float, svg_path.Error) {
  query.segment_length_with(segment, options: options)
}

/// Return whether a segment has length at most `tolerance`.
///
/// `tolerance` is measured in path coordinate units and may be exactly `0.0`
/// for an exact zero-length check. Lines are measured exactly. Quadratic
/// Beziers, cubic Beziers, and arcs are measured with default length options.
pub fn segment_is_zero_length(
  segment: svg_path.Segment,
  tolerance tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  query.segment_is_zero_length(segment, tolerance: tolerance)
}

/// Return the segment parameter at a traveled distance from the segment start.
///
/// The distance is measured in path coordinate units, not normalized. Lines are
/// inverted exactly. Quadratic Beziers, cubic Beziers, and arcs are inverted
/// numerically using the same length options as `segment_length_with`.
pub fn segment_parameter_at_length(
  segment: svg_path.Segment,
  distance distance: Float,
) -> Result(Float, svg_path.Error) {
  query.segment_parameter_at_length(segment, distance: distance)
}

/// Return the segment parameter at a traveled distance using explicit options.
pub fn segment_parameter_at_length_with(
  segment: svg_path.Segment,
  distance distance: Float,
  options options: svg_path.LengthOptions,
) -> Result(Float, svg_path.Error) {
  query.segment_parameter_at_length_with(
    segment,
    distance: distance,
    options: options,
  )
}

/// Return the segment point at a traveled distance from the segment start.
pub fn segment_point_at_length(
  segment: svg_path.Segment,
  distance distance: Float,
) -> Result(svg_path.Point, svg_path.Error) {
  query.segment_point_at_length(segment, distance: distance)
}

/// Return the segment point at a traveled distance using explicit options.
pub fn segment_point_at_length_with(
  segment: svg_path.Segment,
  distance distance: Float,
  options options: svg_path.LengthOptions,
) -> Result(svg_path.Point, svg_path.Error) {
  query.segment_point_at_length_with(
    segment,
    distance: distance,
    options: options,
  )
}

/// Return the segment derivative at a traveled distance from the segment start.
pub fn segment_derivative_at_length(
  segment: svg_path.Segment,
  distance distance: Float,
) -> Result(svg_path.Point, svg_path.Error) {
  query.segment_derivative_at_length(segment, distance: distance)
}

/// Return the segment derivative at a traveled distance using explicit options.
pub fn segment_derivative_at_length_with(
  segment: svg_path.Segment,
  distance distance: Float,
  options options: svg_path.LengthOptions,
) -> Result(svg_path.Point, svg_path.Error) {
  query.segment_derivative_at_length_with(
    segment,
    distance: distance,
    options: options,
  )
}

/// Return the portion of a segment between two traveled distances.
///
/// Distances are measured in path coordinate units from the segment start and
/// must be inside `0.0..length`, inclusive. If `from` is greater than `to`, the
/// returned segment traverses the interval in reverse.
pub fn segment_between_lengths(
  segment: svg_path.Segment,
  from from: Float,
  to to: Float,
) -> Result(svg_path.Segment, svg_path.Error) {
  query.segment_between_lengths(segment, from: from, to: to)
}

/// Return the portion of a segment between two traveled distances using
/// explicit length options.
pub fn segment_between_lengths_with(
  segment: svg_path.Segment,
  from from: Float,
  to to: Float,
  options options: svg_path.LengthOptions,
) -> Result(svg_path.Segment, svg_path.Error) {
  query.segment_between_lengths_with(
    segment,
    from: from,
    to: to,
    options: options,
  )
}

/// Return segment portions between adjacent traveled distances.
///
/// Distances are measured in path coordinate units from the segment start and
/// must be inside `0.0..length`, inclusive. Empty and singleton lists return an
/// empty list.
pub fn segment_between_lengths_many(
  segment: svg_path.Segment,
  between distances: List(Float),
) -> Result(List(svg_path.Segment), svg_path.Error) {
  query.segment_between_lengths_many(segment, between: distances)
}

/// Return segment portions between adjacent traveled distances using explicit
/// length options.
pub fn segment_between_lengths_many_with(
  segment: svg_path.Segment,
  between distances: List(Float),
  options options: svg_path.LengthOptions,
) -> Result(List(svg_path.Segment), svg_path.Error) {
  query.segment_between_lengths_many_with(
    segment,
    between: distances,
    options: options,
  )
}

/// Subdivide a segment into pieces of at most `max_length`.
///
/// Splits are chosen by traveled arc length, not by equal Bezier or arc
/// parameter spacing. Zero-length segments are returned unchanged.
pub fn segment_subdivide_to_max_length(
  segment: svg_path.Segment,
  max_length max_length: Float,
) -> Result(List(svg_path.Segment), svg_path.Error) {
  query.segment_subdivide_to_max_length(segment, max_length: max_length)
}

/// Subdivide a segment into pieces of at most `max_length` using explicit
/// length options.
pub fn segment_subdivide_to_max_length_with(
  segment: svg_path.Segment,
  max_length max_length: Float,
  options options: svg_path.LengthOptions,
) -> Result(List(svg_path.Segment), svg_path.Error) {
  query.segment_subdivide_to_max_length_with(
    segment,
    max_length: max_length,
    options: options,
  )
}

/// Subdivide every segment in a subpath into pieces of at most `max_length`.
///
/// Existing segment boundaries are preserved. The subpath's closed state is
/// preserved.
pub fn subpath_subdivide_to_max_length(
  subpath: svg_path.Subpath,
  max_length max_length: Float,
) -> Result(svg_path.Subpath, svg_path.Error) {
  query.subpath_subdivide_to_max_length(subpath, max_length: max_length)
}

/// Subdivide every segment in a subpath into pieces of at most `max_length`
/// using explicit length options.
pub fn subpath_subdivide_to_max_length_with(
  subpath: svg_path.Subpath,
  max_length max_length: Float,
  options options: svg_path.LengthOptions,
) -> Result(svg_path.Subpath, svg_path.Error) {
  query.subpath_subdivide_to_max_length_with(
    subpath,
    max_length: max_length,
    options: options,
  )
}

/// Subdivide every segment in a path into pieces of at most `max_length`.
///
/// Existing subpath boundaries and closed states are preserved.
pub fn path_subdivide_to_max_length(
  path: svg_path.Path,
  max_length max_length: Float,
) -> Result(svg_path.Path, svg_path.Error) {
  query.path_subdivide_to_max_length(path, max_length: max_length)
}

/// Subdivide every segment in a path into pieces of at most `max_length` using
/// explicit length options.
pub fn path_subdivide_to_max_length_with(
  path: svg_path.Path,
  max_length max_length: Float,
  options options: svg_path.LengthOptions,
) -> Result(svg_path.Path, svg_path.Error) {
  query.path_subdivide_to_max_length_with(
    path,
    max_length: max_length,
    options: options,
  )
}

/// Return the approximate length of a subpath.
///
/// Empty subpaths have length `0.0`.
pub fn subpath_length(
  subpath: svg_path.Subpath,
) -> Result(Float, svg_path.Error) {
  query.subpath_length(subpath)
}

/// Sum the cheap segment-length upper bounds of a subpath.
///
/// Empty subpaths return `0.0`. The closed flag adds no implicit segment.
/// See `segment_length_upper_bound` for the bounds and numerical limitations.
pub fn subpath_length_upper_bound(
  subpath: svg_path.Subpath,
) -> Result(Float, svg_path.Error) {
  query.subpath_length_upper_bound(subpath)
}

/// Return the approximate length of a subpath using explicit options.
pub fn subpath_length_with(
  subpath: svg_path.Subpath,
  options options: svg_path.LengthOptions,
) -> Result(Float, svg_path.Error) {
  query.subpath_length_with(subpath, options: options)
}

/// Return whether a subpath is a zero-length drawing subpath.
///
/// Empty subpaths are not considered zero-length drawing subpaths. A non-empty
/// subpath is zero-length when every segment has length at most `tolerance`.
pub fn subpath_is_zero_length(
  subpath: svg_path.Subpath,
  tolerance tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  query.subpath_is_zero_length(subpath, tolerance: tolerance)
}

/// Return the subpath parameter at a traveled distance from the subpath start.
///
/// The distance is measured in path coordinate units, not normalized. The
/// returned value is an ordinary public `SubpathParameter`.
pub fn subpath_parameter_at_length(
  subpath: svg_path.Subpath,
  distance distance: Float,
) -> Result(svg_path.SubpathParameter, svg_path.Error) {
  query.subpath_parameter_at_length(subpath, distance: distance)
}

/// Return the subpath parameter at a traveled distance using explicit options.
pub fn subpath_parameter_at_length_with(
  subpath: svg_path.Subpath,
  distance distance: Float,
  options options: svg_path.LengthOptions,
) -> Result(svg_path.SubpathParameter, svg_path.Error) {
  query.subpath_parameter_at_length_with(
    subpath,
    distance: distance,
    options: options,
  )
}

/// Return the subpath point at a traveled distance from the subpath start.
pub fn subpath_point_at_length(
  subpath: svg_path.Subpath,
  distance distance: Float,
) -> Result(svg_path.Point, svg_path.Error) {
  query.subpath_point_at_length(subpath, distance: distance)
}

/// Return the subpath point at a traveled distance using explicit options.
pub fn subpath_point_at_length_with(
  subpath: svg_path.Subpath,
  distance distance: Float,
  options options: svg_path.LengthOptions,
) -> Result(svg_path.Point, svg_path.Error) {
  query.subpath_point_at_length_with(
    subpath,
    distance: distance,
    options: options,
  )
}

/// Return the subpath derivative at a traveled distance from the subpath start.
pub fn subpath_derivative_at_length(
  subpath: svg_path.Subpath,
  distance distance: Float,
) -> Result(svg_path.Point, svg_path.Error) {
  query.subpath_derivative_at_length(subpath, distance: distance)
}

/// Return the subpath derivative at a traveled distance using explicit options.
pub fn subpath_derivative_at_length_with(
  subpath: svg_path.Subpath,
  distance distance: Float,
  options options: svg_path.LengthOptions,
) -> Result(svg_path.Point, svg_path.Error) {
  query.subpath_derivative_at_length_with(
    subpath,
    distance: distance,
    options: options,
  )
}

/// Return the open subpath between two traveled distances.
///
/// Distances are measured in path coordinate units from the subpath start and
/// must be inside `0.0..length`, inclusive. The resulting parameters follow
/// the same interval rules as `subpath_between`.
pub fn subpath_between_lengths(
  subpath: svg_path.Subpath,
  from from: Float,
  to to: Float,
) -> Result(svg_path.Subpath, svg_path.Error) {
  query.subpath_between_lengths(subpath, from: from, to: to)
}

/// Return the open subpath between two traveled distances using explicit
/// length options.
pub fn subpath_between_lengths_with(
  subpath: svg_path.Subpath,
  from from: Float,
  to to: Float,
  options options: svg_path.LengthOptions,
) -> Result(svg_path.Subpath, svg_path.Error) {
  query.subpath_between_lengths_with(
    subpath,
    from: from,
    to: to,
    options: options,
  )
}

/// Split a subpath at multiple traveled distances.
///
/// Distances are measured in path coordinate units from the subpath start and
/// must be inside `0.0..length`, inclusive. The resulting parameters follow
/// the same split-point rules as `subpath_split_many`.
pub fn subpath_split_at_lengths(
  subpath: svg_path.Subpath,
  at distances: List(Float),
) -> Result(List(svg_path.Subpath), svg_path.Error) {
  query.subpath_split_at_lengths(subpath, at: distances)
}

/// Split a subpath at multiple traveled distances using explicit length
/// options.
pub fn subpath_split_at_lengths_with(
  subpath: svg_path.Subpath,
  at distances: List(Float),
  options options: svg_path.LengthOptions,
) -> Result(List(svg_path.Subpath), svg_path.Error) {
  query.subpath_split_at_lengths_with(subpath, at: distances, options: options)
}

/// Return the approximate length of a path.
///
/// Empty paths have length `0.0`. Move-only subpaths contribute `0.0`.
pub fn path_length(path: svg_path.Path) -> Result(Float, svg_path.Error) {
  query.path_length(path)
}

/// Sum the cheap segment-length upper bounds across a path's subpaths.
///
/// Empty paths and move-only subpaths contribute `0.0`; gaps between subpaths
/// contribute nothing. See `segment_length_upper_bound` for numerical limits.
pub fn path_length_upper_bound(
  path: svg_path.Path,
) -> Result(Float, svg_path.Error) {
  query.path_length_upper_bound(path)
}

/// Return the approximate length of a path using explicit options.
pub fn path_length_with(
  path: svg_path.Path,
  options options: svg_path.LengthOptions,
) -> Result(Float, svg_path.Error) {
  query.path_length_with(path, options: options)
}

/// Return the path parameter at a traveled distance from the path start.
///
/// The distance is measured across subpaths in path order. Move-only subpaths
/// contribute no length and are skipped for lookup. The returned value is an
/// ordinary public `PathParameter`.
pub fn path_parameter_at_length(
  path: svg_path.Path,
  distance distance: Float,
) -> Result(svg_path.PathParameter, svg_path.Error) {
  query.path_parameter_at_length(path, distance: distance)
}

/// Return the path parameter at a traveled distance using explicit options.
pub fn path_parameter_at_length_with(
  path: svg_path.Path,
  distance distance: Float,
  options options: svg_path.LengthOptions,
) -> Result(svg_path.PathParameter, svg_path.Error) {
  query.path_parameter_at_length_with(
    path,
    distance: distance,
    options: options,
  )
}

/// Return the path point at a traveled distance from the path start.
pub fn path_point_at_length(
  path: svg_path.Path,
  distance distance: Float,
) -> Result(svg_path.Point, svg_path.Error) {
  query.path_point_at_length(path, distance: distance)
}

/// Return the path point at a traveled distance using explicit options.
pub fn path_point_at_length_with(
  path: svg_path.Path,
  distance distance: Float,
  options options: svg_path.LengthOptions,
) -> Result(svg_path.Point, svg_path.Error) {
  query.path_point_at_length_with(path, distance: distance, options: options)
}

/// Return the path derivative at a traveled distance from the path start.
pub fn path_derivative_at_length(
  path: svg_path.Path,
  distance distance: Float,
) -> Result(svg_path.Point, svg_path.Error) {
  query.path_derivative_at_length(path, distance: distance)
}

/// Return the path derivative at a traveled distance using explicit options.
pub fn path_derivative_at_length_with(
  path: svg_path.Path,
  distance distance: Float,
  options options: svg_path.LengthOptions,
) -> Result(svg_path.Point, svg_path.Error) {
  query.path_derivative_at_length_with(
    path,
    distance: distance,
    options: options,
  )
}

@internal
pub fn validate_length_options(
  options: svg_path.LengthOptions,
) -> Result(Nil, svg_path.Error) {
  query.validate_length_options(options)
}
