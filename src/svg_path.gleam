//// Core SVG path data structures and constructors.
////
//// This module models paths as a list of subpaths, and subpaths as continuous
//// segment lists. Use `svg_path/parse` and `svg_path/serialize` when working
//// directly with SVG path data strings.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import svg_path/bezier
import svg_path/ellipse
import svg_path/root
import vec/vec2.{type Vec2, Vec2}

const default_wiggle_tolerance = 0.000000001

const default_crossing_samples = 100

const default_crossing_tolerance = 0.000000001

const default_crossing_max_iterations = 100

const default_minimize_samples = 100

const default_minimize_tolerance = 0.000000001

const default_minimize_max_iterations = 100

const golden_section_ratio = 0.6180339887498949

const default_distance_samples = 100

const default_distance_tolerance = 0.000000001

const default_distance_max_iterations = 100

const default_intersection_tolerance = 0.000000001

const default_intersection_max_depth = 48

/// A 2D point.
///
/// This is a `vec.Vec2(Float)`, so its coordinates are available as `.x` and
/// `.y`.
pub type Point =
  Vec2(Float)

/// An axis-aligned bounding box.
pub type BoundingBox {
  BoundingBox(min: Point, max: Point)
}

/// Return the width of a bounding box.
pub fn bounding_box_width(box: BoundingBox) -> Float {
  box.max.x -. box.min.x
}

/// Return the height of a bounding box.
pub fn bounding_box_height(box: BoundingBox) -> Float {
  box.max.y -. box.min.y
}

/// Return the center point of a bounding box.
pub fn bounding_box_center(box: BoundingBox) -> Point {
  point(
    box.min.x +. bounding_box_width(box) /. 2.0,
    box.min.y +. bounding_box_height(box) /. 2.0,
  )
}

/// Return the taxicab diameter of a bounding box.
///
/// This is the box width plus the box height.
pub fn bounding_box_diameter(box: BoundingBox) -> Float {
  bounding_box_width(box) +. bounding_box_height(box)
}

/// Options for detecting scalar zero crossings along a segment.
pub type CrossingOptions {
  CrossingOptions(samples: Int, tolerance: Float, max_iterations: Int)
}

/// Options for minimizing a scalar function along a segment.
pub type MinimizeOptions {
  MinimizeOptions(samples: Int, tolerance: Float, max_iterations: Int)
}

/// Options for finding the distance from a point to a segment.
pub type DistanceOptions {
  DistanceOptions(samples: Int, tolerance: Float, max_iterations: Int)
}

/// Options for finding segment intersections.
pub type IntersectionOptions {
  IntersectionOptions(tolerance: Float, max_depth: Int)
}

/// A point intersection between two segments.
pub type SegmentIntersection {
  SegmentIntersection(left_t: Float, right_t: Float, point: Point)
}

type MinimizeCandidate {
  MinimizeCandidate(t: Float, value: Float)
}

type IntersectionPiece {
  IntersectionPiece(segment: Segment, from: Float, to: Float)
}

/// An SVG path, made of zero or more subpaths.
pub type Path {
  Path(subpaths: List(Subpath))
}

/// A continuous sequence of path segments, optionally closed.
///
/// The constructor is opaque so that subpaths cannot be created in an invalid
/// discontinuous state. Use `subpath`, `empty_subpath`, `append_segment`, or
/// their `_with` variants to build values.
pub opaque type Subpath {
  Subpath(segments: List(Segment), closed: Bool)
}

/// How construction and editing helpers reconcile segment endpoints.
pub type EndpointPolicy {
  /// Endpoints must already match exactly.
  Strict

  /// Move nearby endpoints together within the default wiggle tolerance.
  Wiggle

  /// Keep endpoints unchanged and insert a straight line if needed.
  Bridge

  /// Try `Wiggle`; if that fails, use `Bridge`.
  WiggleThenBridge
}

/// A single SVG path segment.
pub type Segment {
  /// A straight line segment.
  Line(start: Point, end: Point)

  /// A quadratic Bezier curve segment.
  QuadraticBezier(start: Point, control: Point, end: Point)

  /// A cubic Bezier curve segment.
  CubicBezier(start: Point, control1: Point, control2: Point, end: Point)

  /// An elliptical arc segment.
  Arc(
    start: Point,
    radius: Point,
    x_axis_rotation: Float,
    large_arc: Bool,
    sweep: Bool,
    end: Point,
  )
}

/// Errors returned by path construction and editing helpers.
pub type Error {
  /// The subpath is already closed and cannot accept more segments.
  AlreadyClosed

  /// An operation would produce a closed subpath with no segments.
  ///
  /// Empty open subpaths are valid, but this package does not represent a
  /// closed empty subpath.
  ClosedEmptySubpath

  /// A segment starts somewhere other than the previous segment's end point.
  ///
  /// `previous_index` is the segment whose end point was expected. `next_index`
  /// is the segment whose start point did not match. `distance` is the distance
  /// between `expected` and `got`.
  Discontinuous(
    previous_index: Int,
    next_index: Int,
    expected: Point,
    got: Point,
    distance: Float,
  )

  /// The operation requires a non-empty subpath.
  EmptySubpath

  /// The operation requires a closed subpath.
  NotClosed

  /// The operation requires a path with at least one subpath.
  EmptyPath

  /// The operation requires a path with at least one non-empty subpath.
  EmptySubpaths

  /// The arc cannot be converted to center-parameter form.
  DegenerateArc

  /// Nonlinear point mapping cannot preserve an SVG arc segment.
  CannotMapArcNonlinearly

  /// A wiggle operation could not reconcile two horizontal line segments.
  IncompatibleHorizontalWiggle(previous_end: Point, next_start: Point)

  /// A wiggle operation could not reconcile two vertical line segments.
  IncompatibleVerticalWiggle(previous_end: Point, next_start: Point)

  /// A splice was requested with invalid bounds.
  ///
  /// This is returned when `start` is negative, `delete` is negative, or
  /// `start` is greater than the subpath length.
  InvalidSplice(start: Int, delete: Int, length: Int)

  /// An open index was outside the valid range for a closed subpath.
  ///
  /// `index` must be between `-length` and `length`, inclusive.
  InvalidOpenIndex(index: Int, length: Int)

  /// The number of crossing scan samples must be greater than zero.
  InvalidCrossingSamples(samples: Int)

  /// The crossing tolerance must be greater than zero.
  InvalidCrossingTolerance(tolerance: Float)

  /// The crossing bisection iteration limit must be greater than zero.
  InvalidCrossingMaxIterations(max_iterations: Int)

  /// A bracketed crossing could not be refined within the iteration limit.
  CrossingMaxIterationsReached(estimate: Float, value: Float)

  /// The number of minimization scan samples must be greater than zero.
  InvalidMinimizeSamples(samples: Int)

  /// The minimization tolerance must be greater than zero.
  InvalidMinimizeTolerance(tolerance: Float)

  /// The minimization iteration limit must be greater than zero.
  InvalidMinimizeMaxIterations(max_iterations: Int)

  /// A minimization window could not be refined within the iteration limit.
  MinimizeMaxIterationsReached(estimate: Float, value: Float)

  /// The number of distance scan samples must be greater than zero.
  InvalidDistanceSamples(samples: Int)

  /// The distance tolerance must be greater than zero.
  InvalidDistanceTolerance(tolerance: Float)

  /// The distance bisection iteration limit must be greater than zero.
  InvalidDistanceMaxIterations(max_iterations: Int)

  /// A bracketed distance candidate could not be refined within the iteration limit.
  DistanceMaxIterationsReached(estimate: Float, value: Float)

  /// The intersection tolerance must be greater than zero.
  InvalidIntersectionTolerance(tolerance: Float)

  /// The intersection subdivision depth must be greater than zero.
  InvalidIntersectionMaxDepth(max_depth: Int)

  /// The two segments overlap in more than a single point.
  OverlappingSegments

  /// The path contains more than one non-empty subpath.
  MultipleNonemptySubpaths

  /// Two points were too far apart for a wiggle operation to merge them.
  NotCloseEnough(expected: Point, got: Point, tolerance: Float)

  /// The requested split point is outside the segment's `0.0..1.0` parameter range.
  SplitOutsideSegment
}

/// Create a point from `x` and `y` coordinates.
pub fn point(x: Float, y: Float) -> Point {
  Vec2(x, y)
}

/// Return the default options for segment crossing detection.
pub fn default_crossing_options() -> CrossingOptions {
  CrossingOptions(
    samples: default_crossing_samples,
    tolerance: default_crossing_tolerance,
    max_iterations: default_crossing_max_iterations,
  )
}

/// Return the default options for segment minimization.
pub fn default_minimize_options() -> MinimizeOptions {
  MinimizeOptions(
    samples: default_minimize_samples,
    tolerance: default_minimize_tolerance,
    max_iterations: default_minimize_max_iterations,
  )
}

/// Return the default options for point-to-segment distance measurement.
pub fn default_distance_options() -> DistanceOptions {
  DistanceOptions(
    samples: default_distance_samples,
    tolerance: default_distance_tolerance,
    max_iterations: default_distance_max_iterations,
  )
}

/// Return the default options for segment intersection detection.
pub fn default_intersection_options() -> IntersectionOptions {
  IntersectionOptions(
    tolerance: default_intersection_tolerance,
    max_depth: default_intersection_max_depth,
  )
}

/// Create an empty path.
pub fn empty_path() -> Path {
  Path([])
}

/// Create a path from a list of subpaths.
pub fn path(subpaths: List(Subpath)) -> Path {
  Path(subpaths:)
}

/// Return the subpaths in a path.
pub fn subpaths(path: Path) -> List(Subpath) {
  path.subpaths
}

/// Create a path containing a single subpath.
pub fn from_subpath(subpath: Subpath) -> Path {
  path([subpath])
}

/// Append a subpath to the end of a path.
pub fn append_subpath(path: Path, subpath: Subpath) -> Path {
  Path(subpaths: list.append(path.subpaths, [subpath]))
}

/// Convert a path with zero or one non-empty subpaths into a subpath.
///
/// Empty subpaths are ignored. If more than one non-empty subpath is present,
/// this returns `MultipleNonemptySubpaths`.
pub fn as_subpath(path: Path) -> Result(Subpath, Error) {
  case nonempty_subpaths(path.subpaths) {
    [] -> Ok(empty_subpath())
    [subpath] -> Ok(subpath)
    [_, _, ..] -> Error(MultipleNonemptySubpaths)
  }
}

/// Create an empty open subpath.
pub fn empty_subpath() -> Subpath {
  Subpath(segments: [], closed: False)
}

/// Create an open subpath from a continuous list of segments.
///
/// Returns `Discontinuous` if any segment starts somewhere other than the
/// previous segment's end point. The error includes the two segment indices
/// that failed to meet.
pub fn subpath(segments: List(Segment)) -> Result(Subpath, Error) {
  subpath_with(segments, policy: Strict)
}

/// Create an open subpath using the given endpoint reconciliation policy.
pub fn subpath_with(
  segments: List(Segment),
  policy endpoint_policy: EndpointPolicy,
) -> Result(Subpath, Error) {
  open_subpath_with_segments(segments, endpoint_policy)
}

/// Create an open subpath from a continuous list of segments, panicking if the
/// segments are invalid.
///
/// This is useful for hand-authored paths where invalid continuity would be a
/// programmer error. Use `subpath` when you want to handle construction errors.
pub fn assert_subpath(segments: List(Segment)) -> Subpath {
  assert_subpath_with(segments, policy: Strict)
}

/// Create an open subpath with an endpoint policy, panicking if construction fails.
pub fn assert_subpath_with(
  segments: List(Segment),
  policy endpoint_policy: EndpointPolicy,
) -> Subpath {
  case subpath_with(segments, policy: endpoint_policy) {
    Ok(subpath) -> subpath
    Error(_) -> panic as "svg_path.assert_subpath received invalid segments"
  }
}

/// Return the segments in a subpath.
pub fn segments(subpath: Subpath) -> List(Segment) {
  subpath.segments
}

/// Remove zero-length line segments from a subpath.
///
/// If the subpath contains only one zero-length line, it is preserved so the
/// subpath does not become empty.
pub fn clean_subpath(subpath: Subpath) -> Subpath {
  let cleaned =
    subpath.segments
    |> list.filter(keeping: fn(segment) { !is_zero_length_line(segment) })

  case cleaned {
    [] -> {
      case subpath.segments {
        [] -> subpath
        [first, ..] -> Subpath(segments: [first], closed: subpath.closed)
      }
    }
    _ -> Subpath(segments: cleaned, closed: subpath.closed)
  }
}

/// Remove empty subpaths and clean each remaining subpath.
///
/// This drops subpaths with no segments and applies `clean_subpath` to the
/// rest.
pub fn clean_path(path: Path) -> Path {
  path.subpaths
  |> nonempty_subpaths
  |> list.map(clean_subpath)
  |> Path
}

/// Replace a range of segments in a subpath.
///
/// `start` is a zero-based segment index and `delete` is the number of
/// segments to remove. If `start + delete` extends past the end of the subpath,
/// everything from `start` onward is deleted. Negative `start`, negative
/// `delete`, and `start` greater than the subpath length return
/// `InvalidSplice`.
///
/// The edited subpath must remain continuous. Closed subpaths preserve their
/// closed state; if the splice would make a closed subpath empty,
/// `ClosedEmptySubpath` is returned.
pub fn splice(
  subpath: Subpath,
  start start: Int,
  delete delete: Int,
  insert insert: List(Segment),
) -> Result(Subpath, Error) {
  splice_with(subpath, start:, delete:, insert:, policy: Strict)
}

/// Replace a range of segments in a subpath using the given endpoint policy.
pub fn splice_with(
  subpath: Subpath,
  start start: Int,
  delete delete: Int,
  insert insert: List(Segment),
  policy endpoint_policy: EndpointPolicy,
) -> Result(Subpath, Error) {
  let length = list.length(subpath.segments)

  case start < 0 || delete < 0 || start > length {
    True -> Error(InvalidSplice(start:, delete:, length:))
    False -> {
      let segments = splice_segments(subpath.segments, start, delete, insert)

      case subpath.closed && list.is_empty(segments) {
        True -> Error(ClosedEmptySubpath)
        False ->
          validate_spliced_subpath(segments, subpath.closed, endpoint_policy)
      }
    }
  }
}

/// Replace a range of segments, panicking if the splice is invalid.
pub fn assert_splice(
  subpath: Subpath,
  start start: Int,
  delete delete: Int,
  insert insert: List(Segment),
) -> Subpath {
  assert_splice_with(subpath, start:, delete:, insert:, policy: Strict)
}

/// Replace a range of segments with an endpoint policy, panicking if invalid.
pub fn assert_splice_with(
  subpath: Subpath,
  start start: Int,
  delete delete: Int,
  insert insert: List(Segment),
  policy endpoint_policy: EndpointPolicy,
) -> Subpath {
  case splice_with(subpath, start:, delete:, insert:, policy: endpoint_policy) {
    Ok(subpath) -> subpath
    Error(_) -> panic as "svg_path.assert_splice received an invalid splice"
  }
}

/// Convert every arc in a subpath to cubic Bezier curves.
///
/// Lines, quadratic Beziers, and cubic Beziers are preserved. Elliptical arcs
/// are approximated with one or more cubic Beziers, split into chunks of at
/// most a quarter turn. Degenerate arcs fall back to a straight-line cubic
/// Bezier between their endpoints.
pub fn subpath_arcs_to_cubic_beziers(subpath: Subpath) -> Subpath {
  Subpath(
    segments: segments_arcs_to_cubic_beziers(subpath.segments, []),
    closed: subpath.closed,
  )
}

/// Convert every arc in a path to cubic Bezier curves.
///
/// This applies `subpath_arcs_to_cubic_beziers` to each subpath.
pub fn path_arcs_to_cubic_beziers(path: Path) -> Path {
  Path(subpaths: list.map(path.subpaths, subpath_arcs_to_cubic_beziers))
}

/// Reverse the traversal direction of every segment in a subpath.
///
/// The subpath's closed state is preserved.
pub fn reverse_subpath(subpath: Subpath) -> Subpath {
  Subpath(
    segments: subpath.segments |> list.reverse |> list.map(reverse_segment),
    closed: subpath.closed,
  )
}

/// Reverse the traversal direction of a path.
///
/// This reverses each subpath and reverses the path's subpath order.
pub fn reverse_path(path: Path) -> Path {
  Path(subpaths: path.subpaths |> list.reverse |> list.map(reverse_subpath))
}

/// Map the defining points of every segment in a subpath.
///
/// The subpath's closed state is preserved. For nonlinear functions, this maps
/// endpoints and control points, not the exact image of every point on each
/// rendered curve. If any segment is an arc, this returns
/// `CannotMapArcNonlinearly`.
pub fn map_subpath_points(
  subpath: Subpath,
  with f: fn(Point) -> Point,
) -> Result(Subpath, Error) {
  case map_segments_points(subpath.segments, f, []) {
    Error(error) -> Error(error)
    Ok(segments) -> Ok(Subpath(segments:, closed: subpath.closed))
  }
}

/// Map the defining points of every segment in a path.
///
/// Each subpath's closed state is preserved. For nonlinear functions, this maps
/// endpoints and control points, not the exact image of every point on each
/// rendered curve. If any segment is an arc, this returns
/// `CannotMapArcNonlinearly`.
pub fn map_path_points(
  path: Path,
  with f: fn(Point) -> Point,
) -> Result(Path, Error) {
  case map_subpaths_points(path.subpaths, f, []) {
    Error(error) -> Error(error)
    Ok(subpaths) -> Ok(Path(subpaths:))
  }
}

/// Convert an arc segment to cubic Bezier curves, preserving other segments.
///
/// Non-arc segments are returned unchanged as a single-item list. An arc may
/// become several cubic Bezier segments.
pub fn segment_arcs_to_cubic_beziers(segment: Segment) -> List(Segment) {
  case segment {
    Line(..) | QuadraticBezier(..) | CubicBezier(..) -> [segment]
    Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:) -> {
      case
        ellipse.arc_to_cubics(
          start: to_ellipse_point(start),
          radius: to_ellipse_point(radius),
          x_axis_rotation:,
          large_arc:,
          sweep:,
          end: to_ellipse_point(end),
        )
      {
        Ok(cubics) -> cubic_segments_from_ellipse(cubics, start, end)
        Error(_) -> [line_to_cubic(start, end)]
      }
    }
  }
}

/// Convert every segment in a subpath to cubic Bezier curves.
///
/// Lines and quadratic Beziers are converted exactly. Cubic Beziers are
/// preserved. Elliptical arcs are approximated with one or more cubic Beziers,
/// split into chunks of at most a quarter turn.
pub fn subpath_to_cubic_beziers(subpath: Subpath) -> Subpath {
  Subpath(
    segments: segments_to_cubic_beziers(subpath.segments, []),
    closed: subpath.closed,
  )
}

/// Convert every segment in a path to cubic Bezier curves.
///
/// This applies `subpath_to_cubic_beziers` to each subpath.
pub fn path_to_cubic_beziers(path: Path) -> Path {
  Path(subpaths: list.map(path.subpaths, subpath_to_cubic_beziers))
}

/// Convert a segment to one or more cubic Bezier curves.
///
/// Lines and quadratic Beziers are converted exactly. Cubic Beziers are
/// returned unchanged. Arcs may become several cubic Bezier segments.
pub fn segment_to_cubic_beziers(segment: Segment) -> List(Segment) {
  case segment {
    Line(start:, end:) -> [line_to_cubic(start, end)]
    QuadraticBezier(start:, control:, end:) -> [
      quadratic_to_cubic(start, control, end),
    ]
    CubicBezier(..) -> [segment]
    Arc(..) -> segment_arcs_to_cubic_beziers(segment)
  }
}

/// Check whether a subpath is closed.
pub fn is_closed(subpath: Subpath) -> Bool {
  subpath.closed
}

/// Set a subpath's semantic closed state.
///
/// Setting `closed` to `False` only clears the semantic closed flag. Setting it
/// to `True` requires the subpath's end point to exactly match its start point.
pub fn set_closed(
  subpath: Subpath,
  closed closed: Bool,
) -> Result(Subpath, Error) {
  set_closed_with(subpath, closed:, policy: Strict)
}

/// Set a subpath's semantic closed state with an endpoint policy.
///
/// Setting `closed` to `False` only clears the semantic closed flag. Setting it
/// to `True` uses the given endpoint policy to reconcile the subpath's end point
/// with its start point.
pub fn set_closed_with(
  subpath: Subpath,
  closed closed: Bool,
  policy endpoint_policy: EndpointPolicy,
) -> Result(Subpath, Error) {
  case closed {
    False -> Ok(Subpath(segments: subpath.segments, closed: False))
    True -> close_subpath_with(subpath, endpoint_policy)
  }
}

/// Set a subpath's semantic closed state, panicking if invalid.
pub fn assert_set_closed(subpath: Subpath, closed closed: Bool) -> Subpath {
  assert_set_closed_with(subpath, closed:, policy: Strict)
}

/// Set a subpath's semantic closed state with an endpoint policy, panicking if invalid.
pub fn assert_set_closed_with(
  subpath: Subpath,
  closed closed: Bool,
  policy endpoint_policy: EndpointPolicy,
) -> Subpath {
  case set_closed_with(subpath, closed:, policy: endpoint_policy) {
    Ok(subpath) -> subpath
    Error(_) ->
      panic as "svg_path.assert_set_closed received an invalid subpath"
  }
}

/// Break open a closed subpath at the given segment index.
///
/// The index denotes the segment that will become the first segment of the
/// returned open subpath. Negative indices count from the end. `index` must be
/// between `-length` and `length`, inclusive, where `length` is the number of
/// segments in the subpath. After validation, the index is taken modulo the
/// length, so `length`, `0`, and `-length` all open at the first segment.
pub fn open_at(subpath: Subpath, index index: Int) -> Result(Subpath, Error) {
  let length = list.length(subpath.segments)

  case subpath.closed {
    False -> Error(NotClosed)
    True -> {
      case index < 0 - length || index > length {
        True -> Error(InvalidOpenIndex(index:, length:))
        False -> {
          let index = normalize_open_index(index, length)
          Ok(Subpath(
            segments: rotate_segments(subpath.segments, index),
            closed: False,
          ))
        }
      }
    }
  }
}

/// Return the start point of a non-empty subpath.
pub fn start(subpath: Subpath) -> Result(Point, Error) {
  case subpath.segments {
    [] -> Error(EmptySubpath)
    [first, ..] -> Ok(segment_start(first))
  }
}

/// Return the end point of a non-empty subpath.
pub fn end(subpath: Subpath) -> Result(Point, Error) {
  case list.last(subpath.segments) {
    Ok(last) -> Ok(segment_end(last))
    Error(_) -> Error(EmptySubpath)
  }
}

/// Return the start point of the first non-empty subpath in a path.
pub fn path_start(path: Path) -> Result(Point, Error) {
  case path.subpaths {
    [] -> Error(EmptyPath)
    subpaths -> first_subpath_start(subpaths)
  }
}

/// Return the end point of the last non-empty subpath in a path.
pub fn path_end(path: Path) -> Result(Point, Error) {
  case path.subpaths {
    [] -> Error(EmptyPath)
    subpaths -> first_subpath_end(list.reverse(subpaths))
  }
}

/// Append a segment to an open subpath.
///
/// The new segment must start exactly at the current end point.
pub fn append_segment(
  subpath: Subpath,
  segment: Segment,
) -> Result(Subpath, Error) {
  append_segment_with(subpath, segment, policy: Strict)
}

/// Append a segment to an open subpath using the given endpoint policy.
pub fn append_segment_with(
  subpath: Subpath,
  segment: Segment,
  policy endpoint_policy: EndpointPolicy,
) -> Result(Subpath, Error) {
  case subpath.closed {
    True -> Error(AlreadyClosed)
    False ->
      open_subpath_with_segments(
        list.append(subpath.segments, [segment]),
        endpoint_policy,
      )
  }
}

/// Append a segment to an open subpath, panicking if invalid.
pub fn assert_append_segment(subpath: Subpath, segment: Segment) -> Subpath {
  assert_append_segment_with(subpath, segment, policy: Strict)
}

/// Append a segment with an endpoint policy, panicking if invalid.
pub fn assert_append_segment_with(
  subpath: Subpath,
  segment: Segment,
  policy endpoint_policy: EndpointPolicy,
) -> Subpath {
  case append_segment_with(subpath, segment, policy: endpoint_policy) {
    Ok(subpath) -> subpath
    Error(_) ->
      panic as "svg_path.assert_append_segment received an invalid segment"
  }
}

/// Join open subpaths into one open subpath.
///
/// Each subpath's end point must exactly match the next subpath's start point.
/// Empty open subpaths are treated as identity values.
pub fn join(subpaths: List(Subpath)) -> Result(Subpath, Error) {
  join_with(subpaths, policy: Strict)
}

/// Join open subpaths using the given endpoint policy.
pub fn join_with(
  subpaths: List(Subpath),
  policy endpoint_policy: EndpointPolicy,
) -> Result(Subpath, Error) {
  case list.any(subpaths, fn(subpath) { subpath.closed }) {
    True -> Error(AlreadyClosed)
    False ->
      open_subpath_with_segments(
        list.flat_map(subpaths, segments),
        endpoint_policy,
      )
  }
}

/// Join open subpaths, panicking if invalid.
pub fn assert_join(subpaths: List(Subpath)) -> Subpath {
  assert_join_with(subpaths, policy: Strict)
}

/// Join open subpaths with an endpoint policy, panicking if invalid.
pub fn assert_join_with(
  subpaths: List(Subpath),
  policy endpoint_policy: EndpointPolicy,
) -> Subpath {
  case join_with(subpaths, policy: endpoint_policy) {
    Ok(subpath) -> subpath
    Error(_) -> panic as "svg_path.assert_join received invalid subpaths"
  }
}

/// Return the start point of a segment.
pub fn segment_start(segment: Segment) -> Point {
  case segment {
    Line(start:, ..)
    | QuadraticBezier(start:, ..)
    | CubicBezier(start:, ..)
    | Arc(start:, ..) -> start
  }
}

/// Return the end point of a segment.
pub fn segment_end(segment: Segment) -> Point {
  case segment {
    Line(end:, ..)
    | QuadraticBezier(end:, ..)
    | CubicBezier(end:, ..)
    | Arc(end:, ..) -> end
  }
}

/// Reverse the traversal direction of a segment.
pub fn reverse_segment(segment: Segment) -> Segment {
  case segment {
    Line(start:, end:) -> Line(start: end, end: start)
    QuadraticBezier(start:, control:, end:) -> {
      QuadraticBezier(start: end, control:, end: start)
    }
    CubicBezier(start:, control1:, control2:, end:) -> {
      CubicBezier(
        start: end,
        control1: control2,
        control2: control1,
        end: start,
      )
    }
    Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:) -> {
      Arc(
        start: end,
        radius:,
        x_axis_rotation:,
        large_arc:,
        sweep: !sweep,
        end: start,
      )
    }
  }
}

/// Evaluate a segment at parameter `t`.
///
/// `t` is not clamped. Values outside `0.0..1.0` extrapolate along the same
/// segment.
pub fn segment_point(segment: Segment, at t: Float) -> Result(Point, Error) {
  case segment {
    Line(..) | QuadraticBezier(..) | CubicBezier(..) -> {
      Ok(
        segment_to_bezier_data(segment)
        |> bezier.bezier_point(at: t)
        |> from_bezier_point,
      )
    }
    Arc(..) -> {
      case segment_to_center_arc_data(segment) {
        Error(error) -> Error(error)
        Ok(arc) -> Ok(ellipse.arc_point(arc, at: t) |> from_ellipse_point)
      }
    }
  }
}

/// Return a segment's derivative with respect to parameter `t`.
///
/// `t` is not clamped.
pub fn segment_derivative(
  segment: Segment,
  at t: Float,
) -> Result(Point, Error) {
  case segment {
    Line(..) | QuadraticBezier(..) | CubicBezier(..) -> {
      Ok(
        segment_to_bezier_data(segment)
        |> bezier.bezier_derivative(at: t)
        |> from_bezier_point,
      )
    }
    Arc(..) -> {
      case segment_to_center_arc_data(segment) {
        Error(error) -> Error(error)
        Ok(arc) -> Ok(ellipse.arc_derivative(arc, at: t) |> from_ellipse_point)
      }
    }
  }
}

/// Return a segment's exact axis-aligned bounding box.
pub fn segment_bounding_box(segment: Segment) -> Result(BoundingBox, Error) {
  case segment {
    Line(start:, end:) ->
      Ok(BoundingBox(min: min_point(start, end), max: max_point(start, end)))
    QuadraticBezier(..) | CubicBezier(..) -> {
      let bezier.BoundingBox(min:, max:) =
        segment_to_bezier_data(segment) |> bezier.bezier_bounding_box

      Ok(BoundingBox(min: from_bezier_point(min), max: from_bezier_point(max)))
    }
    Arc(..) -> {
      case segment_to_center_arc_data(segment) {
        Error(error) -> Error(error)
        Ok(arc) -> {
          let ellipse.BoundingBox(min:, max:) = ellipse.arc_bounding_box(arc)

          Ok(BoundingBox(
            min: from_ellipse_point(min),
            max: from_ellipse_point(max),
          ))
        }
      }
    }
  }
}

/// Find scalar sign-change crossings along a segment using default options.
///
/// This samples `t` in `0.0..1.0`, detects sign changes of `f(segment_point(t))`,
/// and refines each bracket with bisection. It finds crossings visible at the
/// configured sampling resolution; tangent roots and pairs of crossings inside
/// one sample window may be missed.
pub fn segment_crossings(
  segment: Segment,
  where f: fn(Point) -> Float,
) -> Result(List(Float), Error) {
  segment_crossings_with(segment, where: f, options: default_crossing_options())
}

/// Find scalar sign-change crossings along a segment using explicit options.
pub fn segment_crossings_with(
  segment: Segment,
  where f: fn(Point) -> Float,
  options options: CrossingOptions,
) -> Result(List(Float), Error) {
  case validate_crossing_options(options) {
    Error(error) -> Error(error)
    Ok(Nil) -> {
      case crossing_value(segment, f, 0.0) {
        Error(error) -> Error(error)
        Ok(first_value) -> {
          scan_crossings(
            segment,
            f,
            options,
            index: 1,
            previous_t: 0.0,
            previous_value: first_value,
            crossings: [],
          )
        }
      }
    }
  }
}

/// Return the segment parameter where a scalar function is minimized.
///
/// This numerically minimizes `f(segment_point(t))` for `t` in `0.0..1.0`.
pub fn segment_minimize(
  segment: Segment,
  measure f: fn(Point) -> Float,
) -> Result(Float, Error) {
  segment_minimize_with(
    segment,
    measure: f,
    options: default_minimize_options(),
  )
}

/// Return the segment parameter where a scalar function is minimized using
/// explicit options.
pub fn segment_minimize_with(
  segment: Segment,
  measure f: fn(Point) -> Float,
  options options: MinimizeOptions,
) -> Result(Float, Error) {
  case validate_minimize_options(options) {
    Error(error) -> Error(error)
    Ok(Nil) -> {
      case minimize_value(segment, f, 0.0) {
        Error(error) -> Error(error)
        Ok(first) -> {
          case
            scan_minimize_windows(
              segment,
              f,
              options,
              index: 1,
              previous_t: 0.0,
              best: first,
            )
          {
            Error(error) -> Error(error)
            Ok(best) -> Ok(best.t)
          }
        }
      }
    }
  }
}

/// Return the shortest distance from a point to a segment.
///
/// Lines are measured exactly. Quadratic Beziers, cubic Beziers, and arcs are
/// measured by finding stationary points of squared distance in `0.0..1.0`.
pub fn segment_distance(
  point: Point,
  to segment: Segment,
) -> Result(Float, Error) {
  segment_distance_with(point, to: segment, options: default_distance_options())
}

/// Return the shortest distance from a point to a segment using explicit options.
pub fn segment_distance_with(
  point: Point,
  to segment: Segment,
  options options: DistanceOptions,
) -> Result(Float, Error) {
  case validate_distance_options(options) {
    Error(error) -> Error(error)
    Ok(Nil) -> {
      case segment {
        Line(start:, end:) -> Ok(point_to_line_distance(point, start, end))
        QuadraticBezier(..) | CubicBezier(..) | Arc(..) -> {
          case distance_candidates(point, segment, options) {
            Error(error) -> Error(error)
            Ok(candidates) ->
              smallest_segment_distance(point, segment, candidates)
          }
        }
      }
    }
  }
}

/// Return point intersections between two segments.
///
/// Overlapping segments return `OverlappingSegments`, since they have more than
/// a finite list of point intersections.
pub fn segment_intersections(
  left: Segment,
  right: Segment,
) -> Result(List(SegmentIntersection), Error) {
  segment_intersections_with(
    left,
    right,
    options: default_intersection_options(),
  )
}

/// Return point intersections between two segments using explicit options.
pub fn segment_intersections_with(
  left: Segment,
  right: Segment,
  options options: IntersectionOptions,
) -> Result(List(SegmentIntersection), Error) {
  case validate_intersection_options(options) {
    Error(error) -> Error(error)
    Ok(Nil) -> {
      case left, right {
        Line(start: left_start, end: left_end),
          Line(start: right_start, end: right_end)
        ->
          line_line_intersections(
            left_start,
            left_end,
            right_start,
            right_end,
            options.tolerance,
          )
        Line(start:, end:), _ ->
          line_segment_intersections(
            line_start: start,
            line_end: end,
            line_is_left: True,
            segment: right,
            options:,
          )
        _, Line(start:, end:) ->
          line_segment_intersections(
            line_start: start,
            line_end: end,
            line_is_left: False,
            segment: left,
            options:,
          )
        _, _ -> curve_curve_intersections(left, right, options)
      }
    }
  }
}

/// Return a non-empty subpath's exact axis-aligned bounding box.
pub fn subpath_bounding_box(subpath: Subpath) -> Result(BoundingBox, Error) {
  case subpath.segments {
    [] -> Error(EmptySubpath)
    [first, ..rest] -> {
      case segment_bounding_box(first) {
        Error(error) -> Error(error)
        Ok(box) -> combine_segment_bounding_boxes(rest, box)
      }
    }
  }
}

/// Return the exact axis-aligned bounding box of all non-empty subpaths.
pub fn path_bounding_box(path: Path) -> Result(BoundingBox, Error) {
  case path.subpaths {
    [] -> Error(EmptyPath)
    subpaths -> combine_subpath_bounding_boxes(subpaths, None)
  }
}

/// Map the defining points of a segment.
///
/// Lines, quadratic Beziers, and cubic Beziers are mapped by applying `f` to
/// their endpoints and control points. For nonlinear functions, this is not the
/// exact image of every point on the rendered curve. Arc segments return
/// `CannotMapArcNonlinearly` because an arbitrary nonlinear mapping does not
/// generally preserve SVG arc parameters.
pub fn map_segment_points(
  segment: Segment,
  with f: fn(Point) -> Point,
) -> Result(Segment, Error) {
  case segment {
    Line(..) | QuadraticBezier(..) | CubicBezier(..) -> {
      Ok(
        segment
        |> segment_to_bezier_data
        |> bezier.map_points(with: fn(point) {
          point |> from_bezier_point |> f |> to_bezier_point
        })
        |> segment_from_bezier_data,
      )
    }
    Arc(..) -> Error(CannotMapArcNonlinearly)
  }
}

/// Split a segment at parameter `t`.
///
/// `t` is not clamped. Values outside `0.0..1.0` extrapolate along the same
/// segment.
pub fn split_segment(
  segment: Segment,
  at t: Float,
) -> Result(#(Segment, Segment), Error) {
  case segment {
    Line(..) | QuadraticBezier(..) | CubicBezier(..) -> {
      let #(left, right) =
        segment_to_bezier_data(segment) |> bezier.split_bezier(at: t)

      Ok(#(segment_from_bezier_data(left), segment_from_bezier_data(right)))
    }
    Arc(..) -> {
      case segment_to_center_arc_data(segment) {
        Error(error) -> Error(error)
        Ok(arc) -> {
          let #(left, right) = ellipse.split_arc(arc, at: t)

          Ok(#(arc_from_center_data(left), arc_from_center_data(right)))
        }
      }
    }
  }
}

/// Split a segment at parameter `t`, returning an error outside `0.0..1.0`.
///
/// Values exactly at `0.0` or `1.0` are accepted and produce one zero-length
/// segment.
pub fn split_segment_inside(
  segment: Segment,
  at t: Float,
) -> Result(#(Segment, Segment), Error) {
  case segment {
    Line(..) | QuadraticBezier(..) | CubicBezier(..) -> {
      case
        segment_to_bezier_data(segment) |> bezier.split_bezier_inside(at: t)
      {
        Error(_) -> Error(SplitOutsideSegment)
        Ok(#(left, right)) -> {
          Ok(#(segment_from_bezier_data(left), segment_from_bezier_data(right)))
        }
      }
    }
    Arc(..) -> {
      case segment_to_center_arc_data(segment) {
        Error(error) -> Error(error)
        Ok(arc) -> {
          case ellipse.split_arc_inside(arc, at: t) {
            Error(_) -> Error(SplitOutsideSegment)
            Ok(#(left, right)) -> {
              Ok(#(arc_from_center_data(left), arc_from_center_data(right)))
            }
          }
        }
      }
    }
  }
}

/// Create a straight line segment.
pub fn line(start start: Point, end end: Point) -> Segment {
  Line(start:, end:)
}

fn is_zero_length_line(segment: Segment) -> Bool {
  case segment {
    Line(start:, end:) -> start == end
    _ -> False
  }
}

fn validate_crossing_options(options: CrossingOptions) -> Result(Nil, Error) {
  case options.samples <= 0 {
    True -> Error(InvalidCrossingSamples(options.samples))
    False -> {
      case options.tolerance <=. 0.0 {
        True -> Error(InvalidCrossingTolerance(options.tolerance))
        False -> {
          case options.max_iterations <= 0 {
            True -> Error(InvalidCrossingMaxIterations(options.max_iterations))
            False -> Ok(Nil)
          }
        }
      }
    }
  }
}

fn scan_crossings(
  segment: Segment,
  f: fn(Point) -> Float,
  options: CrossingOptions,
  index index: Int,
  previous_t previous_t: Float,
  previous_value previous_value: Float,
  crossings crossings: List(Float),
) -> Result(List(Float), Error) {
  case index > options.samples {
    True -> Ok(list.reverse(crossings))
    False -> {
      let next_t = int.to_float(index) /. int.to_float(options.samples)

      case crossing_value(segment, f, next_t) {
        Error(error) -> Error(error)
        Ok(next_value) -> {
          case
            crossing_for_window(
              segment,
              f,
              options,
              previous_t,
              previous_value,
              next_t,
              next_value,
            )
          {
            Error(error) -> Error(error)
            Ok(None) ->
              scan_crossings(
                segment,
                f,
                options,
                index: index + 1,
                previous_t: next_t,
                previous_value: next_value,
                crossings:,
              )
            Ok(Some(crossing)) ->
              scan_crossings(
                segment,
                f,
                options,
                index: index + 1,
                previous_t: next_t,
                previous_value: next_value,
                crossings: insert_near_unique(
                  crossings,
                  crossing,
                  options.tolerance,
                ),
              )
          }
        }
      }
    }
  }
}

fn crossing_for_window(
  segment: Segment,
  f: fn(Point) -> Float,
  options: CrossingOptions,
  previous_t: Float,
  previous_value: Float,
  next_t: Float,
  next_value: Float,
) -> Result(Option(Float), Error) {
  case is_close_to_zero(previous_value, options.tolerance) {
    True -> Ok(Some(previous_t))
    False -> {
      case is_close_to_zero(next_value, options.tolerance) {
        True -> Ok(Some(next_t))
        False -> {
          case same_sign(previous_value, next_value) {
            True -> Ok(None)
            False -> refine_crossing(segment, f, options, previous_t, next_t)
          }
        }
      }
    }
  }
}

fn refine_crossing(
  segment: Segment,
  f: fn(Point) -> Float,
  options: CrossingOptions,
  previous_t: Float,
  next_t: Float,
) -> Result(Option(Float), Error) {
  let solver_options =
    root.Options(
      tolerance: options.tolerance,
      max_iterations: options.max_iterations,
    )

  case
    root.bisect_with(
      fn(t) { crossing_value_unsafe(segment, f, t) },
      from: previous_t,
      to: next_t,
      options: solver_options,
    )
  {
    Ok(t) -> Ok(Some(t))
    Error(root.MaxIterationsReached(estimate:, value:)) ->
      Error(CrossingMaxIterationsReached(estimate:, value:))
    Error(_) -> Ok(None)
  }
}

fn crossing_value(
  segment: Segment,
  f: fn(Point) -> Float,
  t: Float,
) -> Result(Float, Error) {
  case segment_point(segment, at: t) {
    Error(error) -> Error(error)
    Ok(point) -> Ok(f(point))
  }
}

fn crossing_value_unsafe(
  segment: Segment,
  f: fn(Point) -> Float,
  t: Float,
) -> Float {
  let assert Ok(value) = crossing_value(segment, f, t)

  value
}

fn insert_near_unique(
  values: List(Float),
  value: Float,
  tolerance: Float,
) -> List(Float) {
  case values {
    [previous, ..] -> {
      case float.absolute_value(previous -. value) <=. tolerance {
        True -> values
        False -> [value, ..values]
      }
    }
    _ -> [value, ..values]
  }
}

fn is_close_to_zero(value: Float, tolerance: Float) -> Bool {
  float.absolute_value(value) <=. tolerance
}

fn same_sign(a: Float, b: Float) -> Bool {
  a <. 0.0 && b <. 0.0 || a >. 0.0 && b >. 0.0
}

fn validate_minimize_options(options: MinimizeOptions) -> Result(Nil, Error) {
  case options.samples <= 0 {
    True -> Error(InvalidMinimizeSamples(options.samples))
    False -> {
      case options.tolerance <=. 0.0 {
        True -> Error(InvalidMinimizeTolerance(options.tolerance))
        False -> {
          case options.max_iterations <= 0 {
            True -> Error(InvalidMinimizeMaxIterations(options.max_iterations))
            False -> Ok(Nil)
          }
        }
      }
    }
  }
}

fn scan_minimize_windows(
  segment: Segment,
  f: fn(Point) -> Float,
  options: MinimizeOptions,
  index index: Int,
  previous_t previous_t: Float,
  best best: MinimizeCandidate,
) -> Result(MinimizeCandidate, Error) {
  case index > options.samples {
    True -> Ok(best)
    False -> {
      let next_t = int.to_float(index) /. int.to_float(options.samples)

      case minimize_value(segment, f, next_t) {
        Error(error) -> Error(error)
        Ok(next) -> {
          case
            golden_section_minimize(
              segment,
              f,
              left: previous_t,
              right: next_t,
              options:,
            )
          {
            Error(error) -> Error(error)
            Ok(window_best) ->
              scan_minimize_windows(
                segment,
                f,
                options,
                index: index + 1,
                previous_t: next_t,
                best: best_candidate(best, next) |> best_candidate(window_best),
              )
          }
        }
      }
    }
  }
}

fn golden_section_minimize(
  segment: Segment,
  f: fn(Point) -> Float,
  left left: Float,
  right right: Float,
  options options: MinimizeOptions,
) -> Result(MinimizeCandidate, Error) {
  let span = right -. left
  let inner_left = right -. golden_section_ratio *. span
  let inner_right = left +. golden_section_ratio *. span

  case minimize_value(segment, f, inner_left) {
    Error(error) -> Error(error)
    Ok(left_candidate) -> {
      case minimize_value(segment, f, inner_right) {
        Error(error) -> Error(error)
        Ok(right_candidate) ->
          golden_section_loop(
            segment,
            f,
            left:,
            right:,
            inner_left:,
            inner_left_candidate: left_candidate,
            inner_right:,
            inner_right_candidate: right_candidate,
            tolerance: options.tolerance,
            remaining_iterations: options.max_iterations,
          )
      }
    }
  }
}

fn golden_section_loop(
  segment: Segment,
  f: fn(Point) -> Float,
  left left: Float,
  right right: Float,
  inner_left inner_left: Float,
  inner_left_candidate inner_left_candidate: MinimizeCandidate,
  inner_right inner_right: Float,
  inner_right_candidate inner_right_candidate: MinimizeCandidate,
  tolerance tolerance: Float,
  remaining_iterations remaining_iterations: Int,
) -> Result(MinimizeCandidate, Error) {
  case right -. left <=. tolerance {
    True -> Ok(best_candidate(inner_left_candidate, inner_right_candidate))
    False -> {
      case remaining_iterations <= 0 {
        True -> {
          let best = best_candidate(inner_left_candidate, inner_right_candidate)

          Error(MinimizeMaxIterationsReached(best.t, best.value))
        }
        False -> {
          case inner_left_candidate.value <. inner_right_candidate.value {
            True -> {
              let next_right = inner_right
              let next_inner_right = inner_left
              let next_inner_right_candidate = inner_left_candidate
              let next_inner_left =
                next_right -. golden_section_ratio *. { next_right -. left }

              case minimize_value(segment, f, next_inner_left) {
                Error(error) -> Error(error)
                Ok(next_inner_left_candidate) ->
                  golden_section_loop(
                    segment,
                    f,
                    left:,
                    right: next_right,
                    inner_left: next_inner_left,
                    inner_left_candidate: next_inner_left_candidate,
                    inner_right: next_inner_right,
                    inner_right_candidate: next_inner_right_candidate,
                    tolerance:,
                    remaining_iterations: remaining_iterations - 1,
                  )
              }
            }
            False -> {
              let next_left = inner_left
              let next_inner_left = inner_right
              let next_inner_left_candidate = inner_right_candidate
              let next_inner_right =
                next_left +. golden_section_ratio *. { right -. next_left }

              case minimize_value(segment, f, next_inner_right) {
                Error(error) -> Error(error)
                Ok(next_inner_right_candidate) ->
                  golden_section_loop(
                    segment,
                    f,
                    left: next_left,
                    right:,
                    inner_left: next_inner_left,
                    inner_left_candidate: next_inner_left_candidate,
                    inner_right: next_inner_right,
                    inner_right_candidate: next_inner_right_candidate,
                    tolerance:,
                    remaining_iterations: remaining_iterations - 1,
                  )
              }
            }
          }
        }
      }
    }
  }
}

fn minimize_value(
  segment: Segment,
  f: fn(Point) -> Float,
  t: Float,
) -> Result(MinimizeCandidate, Error) {
  case segment_point(segment, at: t) {
    Error(error) -> Error(error)
    Ok(point) -> Ok(MinimizeCandidate(t:, value: f(point)))
  }
}

fn best_candidate(
  a: MinimizeCandidate,
  b: MinimizeCandidate,
) -> MinimizeCandidate {
  case a.value <=. b.value {
    True -> a
    False -> b
  }
}

fn validate_distance_options(options: DistanceOptions) -> Result(Nil, Error) {
  case options.samples <= 0 {
    True -> Error(InvalidDistanceSamples(options.samples))
    False -> {
      case options.tolerance <=. 0.0 {
        True -> Error(InvalidDistanceTolerance(options.tolerance))
        False -> {
          case options.max_iterations <= 0 {
            True -> Error(InvalidDistanceMaxIterations(options.max_iterations))
            False -> Ok(Nil)
          }
        }
      }
    }
  }
}

fn distance_candidates(
  point: Point,
  segment: Segment,
  options: DistanceOptions,
) -> Result(List(Float), Error) {
  case distance_stationary_value(point, segment, 0.0) {
    Error(error) -> Error(error)
    Ok(first_value) -> {
      scan_distance_candidates(
        point,
        segment,
        options,
        index: 1,
        previous_t: 0.0,
        previous_value: first_value,
        candidates: [1.0, 0.0],
      )
    }
  }
}

fn scan_distance_candidates(
  point: Point,
  segment: Segment,
  options: DistanceOptions,
  index index: Int,
  previous_t previous_t: Float,
  previous_value previous_value: Float,
  candidates candidates: List(Float),
) -> Result(List(Float), Error) {
  case index > options.samples {
    True -> Ok(candidates)
    False -> {
      let next_t = int.to_float(index) /. int.to_float(options.samples)

      case distance_stationary_value(point, segment, next_t) {
        Error(error) -> Error(error)
        Ok(next_value) -> {
          case
            distance_candidate_for_window(
              point,
              segment,
              options,
              previous_t,
              previous_value,
              next_t,
              next_value,
            )
          {
            Error(error) -> Error(error)
            Ok(None) ->
              scan_distance_candidates(
                point,
                segment,
                options,
                index: index + 1,
                previous_t: next_t,
                previous_value: next_value,
                candidates:,
              )
            Ok(Some(candidate)) ->
              scan_distance_candidates(
                point,
                segment,
                options,
                index: index + 1,
                previous_t: next_t,
                previous_value: next_value,
                candidates: insert_near_unique(
                  candidates,
                  candidate,
                  options.tolerance,
                ),
              )
          }
        }
      }
    }
  }
}

fn distance_candidate_for_window(
  point: Point,
  segment: Segment,
  options: DistanceOptions,
  previous_t: Float,
  previous_value: Float,
  next_t: Float,
  next_value: Float,
) -> Result(Option(Float), Error) {
  case is_close_to_zero(previous_value, options.tolerance) {
    True -> Ok(Some(previous_t))
    False -> {
      case is_close_to_zero(next_value, options.tolerance) {
        True -> Ok(Some(next_t))
        False -> {
          case same_sign(previous_value, next_value) {
            True -> Ok(None)
            False ->
              refine_distance_candidate(
                point,
                segment,
                options,
                previous_t,
                next_t,
              )
          }
        }
      }
    }
  }
}

fn refine_distance_candidate(
  point: Point,
  segment: Segment,
  options: DistanceOptions,
  previous_t: Float,
  next_t: Float,
) -> Result(Option(Float), Error) {
  let solver_options =
    root.Options(
      tolerance: options.tolerance,
      max_iterations: options.max_iterations,
    )

  case
    root.bisect_with(
      fn(t) { distance_stationary_value_unsafe(point, segment, t) },
      from: previous_t,
      to: next_t,
      options: solver_options,
    )
  {
    Ok(t) -> Ok(Some(t))
    Error(root.MaxIterationsReached(estimate:, value:)) ->
      Error(DistanceMaxIterationsReached(estimate:, value:))
    Error(_) -> Ok(None)
  }
}

fn distance_stationary_value(
  point: Point,
  segment: Segment,
  t: Float,
) -> Result(Float, Error) {
  case segment_point(segment, at: t) {
    Error(error) -> Error(error)
    Ok(segment_point) -> {
      case segment_derivative(segment, at: t) {
        Error(error) -> Error(error)
        Ok(derivative) -> {
          let offset = point_difference(segment_point, point)

          Ok(dot(offset, derivative))
        }
      }
    }
  }
}

fn distance_stationary_value_unsafe(
  point: Point,
  segment: Segment,
  t: Float,
) -> Float {
  let assert Ok(value) = distance_stationary_value(point, segment, t)

  value
}

fn smallest_segment_distance(
  point: Point,
  segment: Segment,
  candidates: List(Float),
) -> Result(Float, Error) {
  case candidates {
    [] -> Ok(0.0)
    [first, ..rest] -> {
      case squared_segment_distance_at(point, segment, first) {
        Error(error) -> Error(error)
        Ok(first_distance) ->
          smallest_segment_distance_loop(point, segment, rest, first_distance)
      }
    }
  }
}

fn smallest_segment_distance_loop(
  point: Point,
  segment: Segment,
  candidates: List(Float),
  smallest: Float,
) -> Result(Float, Error) {
  case candidates {
    [] -> Ok(float_square_root(smallest))
    [first, ..rest] -> {
      case squared_segment_distance_at(point, segment, first) {
        Error(error) -> Error(error)
        Ok(distance) ->
          smallest_segment_distance_loop(
            point,
            segment,
            rest,
            float.min(smallest, distance),
          )
      }
    }
  }
}

fn squared_segment_distance_at(
  point: Point,
  segment: Segment,
  t: Float,
) -> Result(Float, Error) {
  case segment_point(segment, at: t) {
    Error(error) -> Error(error)
    Ok(segment_point) -> Ok(squared_distance(point, segment_point))
  }
}

fn point_to_line_distance(point: Point, start: Point, end: Point) -> Float {
  let line = point_difference(end, start)
  let length_squared = dot(line, line)

  case length_squared == 0.0 {
    True -> distance(point, start)
    False -> {
      let progress =
        dot(point_difference(point, start), line) /. length_squared
        |> clamp01
      let projection = offset(start, line, progress)

      distance(point, projection)
    }
  }
}

fn clamp01(value: Float) -> Float {
  value |> float.max(0.0) |> float.min(1.0)
}

fn point_difference(a: Point, b: Point) -> Point {
  point(a.x -. b.x, a.y -. b.y)
}

fn offset(origin: Point, direction: Point, distance: Float) -> Point {
  point(
    origin.x +. direction.x *. distance,
    origin.y +. direction.y *. distance,
  )
}

fn dot(a: Point, b: Point) -> Float {
  a.x *. b.x +. a.y *. b.y
}

fn squared_distance(a: Point, b: Point) -> Float {
  let dx = a.x -. b.x
  let dy = a.y -. b.y
  dx *. dx +. dy *. dy
}

fn validate_intersection_options(
  options: IntersectionOptions,
) -> Result(Nil, Error) {
  case options.tolerance <=. 0.0 {
    True -> Error(InvalidIntersectionTolerance(options.tolerance))
    False -> {
      case options.max_depth <= 0 {
        True -> Error(InvalidIntersectionMaxDepth(options.max_depth))
        False -> Ok(Nil)
      }
    }
  }
}

fn line_line_intersections(
  left_start: Point,
  left_end: Point,
  right_start: Point,
  right_end: Point,
  tolerance: Float,
) -> Result(List(SegmentIntersection), Error) {
  let left_direction = point_difference(left_end, left_start)
  let right_direction = point_difference(right_end, right_start)
  let left_length_squared = dot(left_direction, left_direction)
  let right_length_squared = dot(right_direction, right_direction)

  case
    left_length_squared <=. tolerance *. tolerance,
    right_length_squared <=. tolerance *. tolerance
  {
    True, True -> {
      case distance(left_start, right_start) <=. tolerance {
        True ->
          Ok([
            SegmentIntersection(
              left_t: 0.0,
              right_t: 0.0,
              point: midpoint(left_start, right_start),
            ),
          ])
        False -> Ok([])
      }
    }
    True, False -> {
      case
        point_on_line_segment(left_start, right_start, right_end, tolerance)
      {
        True ->
          Ok([
            SegmentIntersection(
              left_t: 0.0,
              right_t: line_projection_t(left_start, right_start, right_end),
              point: left_start,
            ),
          ])
        False -> Ok([])
      }
    }
    False, True -> {
      case point_on_line_segment(right_start, left_start, left_end, tolerance) {
        True ->
          Ok([
            SegmentIntersection(
              left_t: line_projection_t(right_start, left_start, left_end),
              right_t: 0.0,
              point: right_start,
            ),
          ])
        False -> Ok([])
      }
    }
    False, False -> {
      let start_difference = point_difference(right_start, left_start)
      let denominator = cross(left_direction, right_direction)

      case float.absolute_value(denominator) <=. tolerance {
        True -> {
          case
            float.absolute_value(cross(start_difference, left_direction))
            <=. tolerance
          {
            True ->
              collinear_line_intersections(
                left_start,
                left_end,
                right_start,
                right_end,
                tolerance,
              )
            False -> Ok([])
          }
        }
        False -> {
          let left_t = cross(start_difference, right_direction) /. denominator
          let right_t = cross(start_difference, left_direction) /. denominator

          case
            in_unit_range(left_t, tolerance)
            && in_unit_range(right_t, tolerance)
          {
            True -> {
              let left_t = clamp01(left_t)
              let right_t = clamp01(right_t)

              Ok([
                SegmentIntersection(
                  left_t:,
                  right_t:,
                  point: interpolate(left_start, left_end, left_t),
                ),
              ])
            }
            False -> Ok([])
          }
        }
      }
    }
  }
}

fn collinear_line_intersections(
  left_start: Point,
  left_end: Point,
  right_start: Point,
  right_end: Point,
  tolerance: Float,
) -> Result(List(SegmentIntersection), Error) {
  let right_start_t = line_projection_t(right_start, left_start, left_end)
  let right_end_t = line_projection_t(right_end, left_start, left_end)
  let overlap_start = float.max(0.0, float.min(right_start_t, right_end_t))
  let overlap_end = float.min(1.0, float.max(right_start_t, right_end_t))

  case overlap_end <. overlap_start -. tolerance {
    True -> Ok([])
    False -> {
      case overlap_end -. overlap_start <=. tolerance {
        True -> {
          let left_t = clamp01({ overlap_start +. overlap_end } /. 2.0)
          let point = interpolate(left_start, left_end, left_t)

          Ok([
            SegmentIntersection(
              left_t:,
              right_t: line_projection_t(point, right_start, right_end)
                |> clamp01,
              point:,
            ),
          ])
        }
        False -> Error(OverlappingSegments)
      }
    }
  }
}

fn line_segment_intersections(
  line_start line_start: Point,
  line_end line_end: Point,
  line_is_left line_is_left: Bool,
  segment segment: Segment,
  options options: IntersectionOptions,
) -> Result(List(SegmentIntersection), Error) {
  let line_direction = point_difference(line_end, line_start)

  case segment_lies_on_line(segment, line_start, line_end, options.tolerance) {
    True -> Error(OverlappingSegments)
    False -> {
      case
        segment_crossings_with(
          segment,
          where: fn(point) {
            cross(line_direction, point_difference(point, line_start))
          },
          options: CrossingOptions(
            samples: 100,
            tolerance: options.tolerance,
            max_iterations: options.max_depth * 4,
          ),
        )
      {
        Error(error) -> Error(error)
        Ok(segment_ts) -> {
          line_segment_intersections_from_ts(
            line_start,
            line_end,
            line_is_left,
            segment,
            segment_ts,
            options.tolerance,
            [],
          )
        }
      }
    }
  }
}

fn line_segment_intersections_from_ts(
  line_start: Point,
  line_end: Point,
  line_is_left: Bool,
  segment: Segment,
  segment_ts: List(Float),
  tolerance: Float,
  intersections: List(SegmentIntersection),
) -> Result(List(SegmentIntersection), Error) {
  case segment_ts {
    [] -> Ok(intersections)
    [segment_t, ..rest] -> {
      case segment_point(segment, at: segment_t) {
        Error(error) -> Error(error)
        Ok(point) -> {
          let line_t = line_projection_t(point, line_start, line_end)

          case in_unit_range(line_t, tolerance) {
            True -> {
              let intersection = case line_is_left {
                True ->
                  SegmentIntersection(
                    left_t: clamp01(line_t),
                    right_t: clamp01(segment_t),
                    point:,
                  )
                False ->
                  SegmentIntersection(
                    left_t: clamp01(segment_t),
                    right_t: clamp01(line_t),
                    point:,
                  )
              }

              line_segment_intersections_from_ts(
                line_start,
                line_end,
                line_is_left,
                segment,
                rest,
                tolerance,
                insert_intersection(intersections, intersection, tolerance),
              )
            }
            False ->
              line_segment_intersections_from_ts(
                line_start,
                line_end,
                line_is_left,
                segment,
                rest,
                tolerance,
                intersections,
              )
          }
        }
      }
    }
  }
}

fn curve_curve_intersections(
  left: Segment,
  right: Segment,
  options: IntersectionOptions,
) -> Result(List(SegmentIntersection), Error) {
  collect_curve_curve_intersections(
    IntersectionPiece(segment: left, from: 0.0, to: 1.0),
    IntersectionPiece(segment: right, from: 0.0, to: 1.0),
    options,
    remaining_depth: options.max_depth,
    intersections: [],
  )
}

fn collect_curve_curve_intersections(
  left: IntersectionPiece,
  right: IntersectionPiece,
  options: IntersectionOptions,
  remaining_depth remaining_depth: Int,
  intersections intersections: List(SegmentIntersection),
) -> Result(List(SegmentIntersection), Error) {
  case segment_bounding_box(left.segment), segment_bounding_box(right.segment) {
    Error(error), _ | _, Error(error) -> Error(error)
    Ok(left_box), Ok(right_box) -> {
      case boxes_overlap(left_box, right_box, options.tolerance) {
        False -> Ok(intersections)
        True -> {
          case
            remaining_depth <= 0
            || {
              bounding_box_diameter(left_box) <=. options.tolerance
              && bounding_box_diameter(right_box) <=. options.tolerance
            }
          {
            True -> {
              case
                chord_intersections_from_pieces(left, right, options.tolerance)
              {
                Error(error) -> Error(error)
                Ok(found) ->
                  Ok(insert_intersections(
                    intersections,
                    found,
                    intersection_dedupe_tolerance(options.tolerance),
                  ))
              }
            }
            False -> {
              let split_left =
                bounding_box_diameter(left_box)
                >=. bounding_box_diameter(right_box)

              case split_left {
                True -> {
                  let #(first, second) = split_intersection_piece(left)

                  case
                    collect_curve_curve_intersections(
                      first,
                      right,
                      options,
                      remaining_depth: remaining_depth - 1,
                      intersections:,
                    )
                  {
                    Error(error) -> Error(error)
                    Ok(intersections) ->
                      collect_curve_curve_intersections(
                        second,
                        right,
                        options,
                        remaining_depth: remaining_depth - 1,
                        intersections:,
                      )
                  }
                }
                False -> {
                  let #(first, second) = split_intersection_piece(right)

                  case
                    collect_curve_curve_intersections(
                      left,
                      first,
                      options,
                      remaining_depth: remaining_depth - 1,
                      intersections:,
                    )
                  {
                    Error(error) -> Error(error)
                    Ok(intersections) ->
                      collect_curve_curve_intersections(
                        left,
                        second,
                        options,
                        remaining_depth: remaining_depth - 1,
                        intersections:,
                      )
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

fn split_intersection_piece(
  piece: IntersectionPiece,
) -> #(IntersectionPiece, IntersectionPiece) {
  let assert Ok(#(left, right)) = split_segment(piece.segment, at: 0.5)
  let middle = { piece.from +. piece.to } /. 2.0

  #(
    IntersectionPiece(segment: left, from: piece.from, to: middle),
    IntersectionPiece(segment: right, from: middle, to: piece.to),
  )
}

fn intersection_from_pieces(
  left: IntersectionPiece,
  right: IntersectionPiece,
) -> Result(SegmentIntersection, Error) {
  let left_t = { left.from +. left.to } /. 2.0
  let right_t = { right.from +. right.to } /. 2.0

  case
    segment_point(left.segment, at: 0.5),
    segment_point(right.segment, at: 0.5)
  {
    Error(error), _ | _, Error(error) -> Error(error)
    Ok(left_point), Ok(right_point) ->
      Ok(SegmentIntersection(
        left_t:,
        right_t:,
        point: midpoint(left_point, right_point),
      ))
  }
}

fn chord_intersections_from_pieces(
  left: IntersectionPiece,
  right: IntersectionPiece,
  tolerance: Float,
) -> Result(List(SegmentIntersection), Error) {
  let left_start = segment_start(left.segment)
  let left_end = segment_end(left.segment)
  let right_start = segment_start(right.segment)
  let right_end = segment_end(right.segment)

  case
    line_line_intersections(
      left_start,
      left_end,
      right_start,
      right_end,
      tolerance,
    )
  {
    Ok(intersections) ->
      Ok(
        list.map(intersections, fn(intersection) {
          SegmentIntersection(
            left_t: interpolate_float(left.from, left.to, intersection.left_t),
            right_t: interpolate_float(
              right.from,
              right.to,
              intersection.right_t,
            ),
            point: intersection.point,
          )
        }),
      )
    Error(OverlappingSegments) -> {
      case intersection_from_pieces(left, right) {
        Error(error) -> Error(error)
        Ok(intersection) -> Ok([intersection])
      }
    }
    Error(error) -> Error(error)
  }
}

fn boxes_overlap(
  left: BoundingBox,
  right: BoundingBox,
  tolerance: Float,
) -> Bool {
  left.min.x <=. right.max.x +. tolerance
  && left.max.x +. tolerance >=. right.min.x
  && left.min.y <=. right.max.y +. tolerance
  && left.max.y +. tolerance >=. right.min.y
}

fn segment_lies_on_line(
  segment: Segment,
  line_start: Point,
  line_end: Point,
  tolerance: Float,
) -> Bool {
  let direction = point_difference(line_end, line_start)

  case segment_defining_points(segment) {
    None -> False
    Some(points) -> {
      list.all(points, fn(point) {
        float.absolute_value(cross(
          direction,
          point_difference(point, line_start),
        ))
        <=. tolerance
      })
      && segment_projection_overlaps_line(
        points,
        line_start,
        line_end,
        tolerance,
      )
    }
  }
}

fn segment_projection_overlaps_line(
  points: List(Point),
  line_start: Point,
  line_end: Point,
  tolerance: Float,
) -> Bool {
  case points {
    [] -> False
    [first, ..rest] -> {
      let first_t = line_projection_t(first, line_start, line_end)
      let #(min_t, max_t) =
        list.fold(rest, #(first_t, first_t), fn(range, point) {
          let #(min_t, max_t) = range
          let t = line_projection_t(point, line_start, line_end)

          #(float.min(min_t, t), float.max(max_t, t))
        })

      float.min(1.0, max_t) -. float.max(0.0, min_t) >. tolerance
    }
  }
}

fn segment_defining_points(segment: Segment) -> Option(List(Point)) {
  case segment {
    Line(start:, end:) -> Some([start, end])
    QuadraticBezier(start:, control:, end:) -> Some([start, control, end])
    CubicBezier(start:, control1:, control2:, end:) ->
      Some([start, control1, control2, end])
    Arc(..) -> None
  }
}

fn point_on_line_segment(
  point: Point,
  start: Point,
  end: Point,
  tolerance: Float,
) -> Bool {
  let direction = point_difference(end, start)
  float.absolute_value(cross(direction, point_difference(point, start)))
  <=. tolerance
  && in_unit_range(line_projection_t(point, start, end), tolerance)
}

fn line_projection_t(point: Point, start: Point, end: Point) -> Float {
  let direction = point_difference(end, start)
  let length_squared = dot(direction, direction)

  case length_squared == 0.0 {
    True -> 0.0
    False -> dot(point_difference(point, start), direction) /. length_squared
  }
}

fn in_unit_range(value: Float, tolerance: Float) -> Bool {
  value >=. 0.0 -. tolerance && value <=. 1.0 +. tolerance
}

fn insert_intersection(
  intersections: List(SegmentIntersection),
  intersection: SegmentIntersection,
  tolerance: Float,
) -> List(SegmentIntersection) {
  case intersections {
    [] -> [intersection]
    [first, ..rest] -> {
      case
        distance(first.point, intersection.point) <=. tolerance
        || {
          float.absolute_value(first.left_t -. intersection.left_t)
          <=. tolerance
          && float.absolute_value(first.right_t -. intersection.right_t)
          <=. tolerance
        }
      {
        True -> [merge_intersections(first, intersection), ..rest]
        False -> [first, ..insert_intersection(rest, intersection, tolerance)]
      }
    }
  }
}

fn merge_intersections(
  a: SegmentIntersection,
  b: SegmentIntersection,
) -> SegmentIntersection {
  SegmentIntersection(
    left_t: { a.left_t +. b.left_t } /. 2.0,
    right_t: { a.right_t +. b.right_t } /. 2.0,
    point: midpoint(a.point, b.point),
  )
}

fn insert_intersections(
  intersections: List(SegmentIntersection),
  new_intersections: List(SegmentIntersection),
  tolerance: Float,
) -> List(SegmentIntersection) {
  list.fold(new_intersections, intersections, fn(intersections, intersection) {
    insert_intersection(intersections, intersection, tolerance)
  })
}

fn intersection_dedupe_tolerance(tolerance: Float) -> Float {
  float.max(tolerance *. 1_000_000.0, 0.000001)
}

fn cross(a: Point, b: Point) -> Float {
  a.x *. b.y -. a.y *. b.x
}

fn interpolate_float(start: Float, end: Float, t: Float) -> Float {
  start +. { end -. start } *. t
}

fn combine_segment_bounding_boxes(
  segments: List(Segment),
  box: BoundingBox,
) -> Result(BoundingBox, Error) {
  case segments {
    [] -> Ok(box)
    [first, ..rest] -> {
      case segment_bounding_box(first) {
        Error(error) -> Error(error)
        Ok(next) ->
          combine_segment_bounding_boxes(rest, combine_boxes(box, next))
      }
    }
  }
}

fn combine_subpath_bounding_boxes(
  subpaths: List(Subpath),
  box: Option(BoundingBox),
) -> Result(BoundingBox, Error) {
  case subpaths {
    [] -> {
      case box {
        None -> Error(EmptySubpaths)
        Some(box) -> Ok(box)
      }
    }
    [first, ..rest] -> {
      case subpath_bounding_box(first) {
        Error(EmptySubpath) -> combine_subpath_bounding_boxes(rest, box)
        Error(error) -> Error(error)
        Ok(next) -> {
          let box = case box {
            None -> next
            Some(box) -> combine_boxes(box, next)
          }

          combine_subpath_bounding_boxes(rest, Some(box))
        }
      }
    }
  }
}

fn combine_boxes(first: BoundingBox, second: BoundingBox) -> BoundingBox {
  BoundingBox(
    min: min_point(first.min, second.min),
    max: max_point(first.max, second.max),
  )
}

fn min_point(a: Point, b: Point) -> Point {
  point(float.min(a.x, b.x), float.min(a.y, b.y))
}

fn max_point(a: Point, b: Point) -> Point {
  point(float.max(a.x, b.x), float.max(a.y, b.y))
}

fn splice_segments(
  segments: List(Segment),
  start: Int,
  delete: Int,
  insert: List(Segment),
) -> List(Segment) {
  splice_segments_loop(segments, start, delete, insert, index: 0, before: [])
}

fn first_subpath_start(subpaths: List(Subpath)) -> Result(Point, Error) {
  case subpaths {
    [] -> Error(EmptySubpaths)
    [subpath, ..rest] -> {
      case start(subpath) {
        Ok(point) -> Ok(point)
        Error(EmptySubpath) -> first_subpath_start(rest)
        Error(error) -> Error(error)
      }
    }
  }
}

fn first_subpath_end(subpaths: List(Subpath)) -> Result(Point, Error) {
  case subpaths {
    [] -> Error(EmptySubpaths)
    [subpath, ..rest] -> {
      case end(subpath) {
        Ok(point) -> Ok(point)
        Error(EmptySubpath) -> first_subpath_end(rest)
        Error(error) -> Error(error)
      }
    }
  }
}

fn map_subpaths_points(
  subpaths: List(Subpath),
  f: fn(Point) -> Point,
  mapped: List(Subpath),
) -> Result(List(Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(mapped))
    [first, ..rest] -> {
      case map_subpath_points(first, with: f) {
        Error(error) -> Error(error)
        Ok(subpath) -> map_subpaths_points(rest, f, [subpath, ..mapped])
      }
    }
  }
}

fn map_segments_points(
  segments: List(Segment),
  f: fn(Point) -> Point,
  mapped: List(Segment),
) -> Result(List(Segment), Error) {
  case segments {
    [] -> Ok(list.reverse(mapped))
    [first, ..rest] -> {
      case map_segment_points(first, with: f) {
        Error(error) -> Error(error)
        Ok(segment) -> map_segments_points(rest, f, [segment, ..mapped])
      }
    }
  }
}

fn splice_segments_loop(
  segments: List(Segment),
  start: Int,
  delete: Int,
  insert: List(Segment),
  index index: Int,
  before before: List(Segment),
) -> List(Segment) {
  case segments {
    [] -> list.append(list.reverse(before), insert)
    [first, ..rest] -> {
      case index < start {
        True ->
          splice_segments_loop(rest, start, delete, insert, index + 1, [
            first,
            ..before
          ])
        False ->
          list.append(
            list.reverse(before),
            list.append(insert, drop(segments, delete)),
          )
      }
    }
  }
}

fn drop(segments: List(Segment), count: Int) -> List(Segment) {
  case count <= 0 {
    True -> segments
    False -> {
      case segments {
        [] -> []
        [_, ..rest] -> drop(rest, count - 1)
      }
    }
  }
}

fn take(segments: List(Segment), count: Int) -> List(Segment) {
  case count <= 0 {
    True -> []
    False -> {
      case segments {
        [] -> []
        [first, ..rest] -> [first, ..take(rest, count - 1)]
      }
    }
  }
}

fn normalize_open_index(index: Int, length: Int) -> Int {
  case index {
    0 -> 0
    _ if index == length -> 0
    _ if index == 0 - length -> 0
    _ if index < 0 -> index + length
    _ -> index
  }
}

fn rotate_segments(segments: List(Segment), index: Int) -> List(Segment) {
  list.append(drop(segments, index), take(segments, index))
}

fn validate_spliced_subpath(
  segments: List(Segment),
  closed: Bool,
  policy: EndpointPolicy,
) -> Result(Subpath, Error) {
  case open_subpath_with_segments(segments, policy) {
    Ok(subpath) -> {
      case closed {
        False -> Ok(subpath)
        True -> close_subpath_with(subpath, policy)
      }
    }
    Error(error) -> Error(error)
  }
}

fn open_subpath_with_segments(
  segments: List(Segment),
  policy: EndpointPolicy,
) -> Result(Subpath, Error) {
  case policy {
    Strict -> strict_open_subpath(segments)
    Wiggle -> wiggle_open_subpath(segments)
    Bridge -> Ok(Subpath(segments: line_join_segments(segments), closed: False))
    WiggleThenBridge -> {
      case wiggle_open_subpath(segments) {
        Ok(subpath) -> Ok(subpath)
        Error(_) ->
          Ok(Subpath(segments: line_join_segments(segments), closed: False))
      }
    }
  }
}

fn strict_open_subpath(segments: List(Segment)) -> Result(Subpath, Error) {
  case continuous(segments) {
    Ok(Nil) -> Ok(Subpath(segments:, closed: False))
    Error(error) -> Error(error)
  }
}

fn wiggle_open_subpath(segments: List(Segment)) -> Result(Subpath, Error) {
  case segments {
    [] | [_] -> strict_open_subpath(segments)
    [first, ..rest] -> {
      case wiggle_segments(rest, first, []) {
        Ok(segments) -> Ok(Subpath(segments:, closed: False))
        Error(error) -> Error(error)
      }
    }
  }
}

fn line_join_segments(segments: List(Segment)) -> List(Segment) {
  case segments {
    [] -> []
    [first, ..rest] -> line_join_segments_loop(rest, first, [])
  }
}

fn line_join_segments_loop(
  remaining: List(Segment),
  previous: Segment,
  joined: List(Segment),
) -> List(Segment) {
  case remaining {
    [] -> list.reverse([previous, ..joined])
    [next, ..rest] -> {
      let previous_end = segment_end(previous)
      let next_start = segment_start(next)

      case previous_end == next_start {
        True -> line_join_segments_loop(rest, next, [previous, ..joined])
        False -> {
          line_join_segments_loop(rest, next, [
            Line(start: previous_end, end: next_start),
            previous,
            ..joined
          ])
        }
      }
    }
  }
}

fn segments_arcs_to_cubic_beziers(
  segments: List(Segment),
  converted: List(Segment),
) -> List(Segment) {
  case segments {
    [] -> list.reverse(converted)
    [first, ..rest] -> {
      segments_arcs_to_cubic_beziers(
        rest,
        list.append(
          list.reverse(segment_arcs_to_cubic_beziers(first)),
          converted,
        ),
      )
    }
  }
}

fn segments_to_cubic_beziers(
  segments: List(Segment),
  converted: List(Segment),
) -> List(Segment) {
  case segments {
    [] -> list.reverse(converted)
    [first, ..rest] -> {
      segments_to_cubic_beziers(
        rest,
        list.append(list.reverse(segment_to_cubic_beziers(first)), converted),
      )
    }
  }
}

fn line_to_cubic(start: Point, end: Point) -> Segment {
  CubicBezier(
    start:,
    control1: interpolate(start, end, 1.0 /. 3.0),
    control2: interpolate(start, end, 2.0 /. 3.0),
    end:,
  )
}

fn quadratic_to_cubic(start: Point, control: Point, end: Point) -> Segment {
  CubicBezier(
    start:,
    control1: point(
      start.x +. 2.0 /. 3.0 *. { control.x -. start.x },
      start.y +. 2.0 /. 3.0 *. { control.y -. start.y },
    ),
    control2: point(
      end.x +. 2.0 /. 3.0 *. { control.x -. end.x },
      end.y +. 2.0 /. 3.0 *. { control.y -. end.y },
    ),
    end:,
  )
}

fn cubic_from_ellipse(cubic: ellipse.Cubic) -> Segment {
  let ellipse.Cubic(start:, control1:, control2:, end:) = cubic

  CubicBezier(
    start: from_ellipse_point(start),
    control1: from_ellipse_point(control1),
    control2: from_ellipse_point(control2),
    end: from_ellipse_point(end),
  )
}

fn cubic_segments_from_ellipse(
  cubics: List(ellipse.Cubic),
  start: Point,
  end: Point,
) -> List(Segment) {
  cubics
  |> list.map(cubic_from_ellipse)
  |> force_cubic_start(start)
  |> force_cubic_end(end)
}

fn force_cubic_start(segments: List(Segment), start: Point) -> List(Segment) {
  case segments {
    [] -> []
    [CubicBezier(control1:, control2:, end:, ..), ..rest] -> [
      CubicBezier(start:, control1:, control2:, end:),
      ..rest
    ]
    [first, ..rest] -> [first, ..rest]
  }
}

fn force_cubic_end(segments: List(Segment), end: Point) -> List(Segment) {
  case segments {
    [] -> []
    [only] -> [segment_with_end(only, end)]
    [first, ..rest] -> [first, ..force_cubic_end(rest, end)]
  }
}

fn to_ellipse_point(point: Point) -> ellipse.Point {
  ellipse.Point(point.x, point.y)
}

fn from_ellipse_point(point: ellipse.Point) -> Point {
  Vec2(point.x, point.y)
}

fn to_bezier_point(point: Point) -> bezier.Point {
  bezier.Point(point.x, point.y)
}

fn from_bezier_point(point: bezier.Point) -> Point {
  Vec2(point.x, point.y)
}

fn segment_to_bezier_data(segment: Segment) -> bezier.BezierData {
  case segment {
    Line(start:, end:) -> {
      bezier.linear_bezier_data(
        start: to_bezier_point(start),
        end: to_bezier_point(end),
      )
    }
    QuadraticBezier(start:, control:, end:) -> {
      bezier.quadratic_bezier_data(
        start: to_bezier_point(start),
        control: to_bezier_point(control),
        end: to_bezier_point(end),
      )
    }
    CubicBezier(start:, control1:, control2:, end:) -> {
      bezier.cubic_bezier_data(
        start: to_bezier_point(start),
        control1: to_bezier_point(control1),
        control2: to_bezier_point(control2),
        end: to_bezier_point(end),
      )
    }
    Arc(..) -> panic as "svg_path.segment_to_bezier_data received an arc"
  }
}

fn segment_from_bezier_data(data: bezier.BezierData) -> Segment {
  case data {
    bezier.LinearBezierData(start:, end:) -> {
      Line(start: from_bezier_point(start), end: from_bezier_point(end))
    }
    bezier.QuadraticBezierData(start:, control:, end:) -> {
      QuadraticBezier(
        start: from_bezier_point(start),
        control: from_bezier_point(control),
        end: from_bezier_point(end),
      )
    }
    bezier.CubicBezierData(start:, control1:, control2:, end:) -> {
      CubicBezier(
        start: from_bezier_point(start),
        control1: from_bezier_point(control1),
        control2: from_bezier_point(control2),
        end: from_bezier_point(end),
      )
    }
  }
}

fn segment_to_center_arc_data(
  segment: Segment,
) -> Result(ellipse.CenterArcData, Error) {
  case segment {
    Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:) -> {
      let endpoint =
        ellipse.endpoint_arc_data(
          start: to_ellipse_point(start),
          radius: to_ellipse_point(radius),
          x_axis_rotation:,
          large_arc:,
          sweep:,
          end: to_ellipse_point(end),
        )

      case ellipse.endpoint_to_center(endpoint) {
        Error(_) -> Error(DegenerateArc)
        Ok(arc) -> Ok(arc)
      }
    }
    Line(..) | QuadraticBezier(..) | CubicBezier(..) -> {
      Error(DegenerateArc)
    }
  }
}

fn interpolate(start: Point, end: Point, t: Float) -> Point {
  point(
    start.x +. { end.x -. start.x } *. t,
    start.y +. { end.y -. start.y } *. t,
  )
}

/// Create a quadratic Bezier segment.
pub fn quadratic_bezier(
  start start: Point,
  control control: Point,
  end end: Point,
) -> Segment {
  QuadraticBezier(start:, control:, end:)
}

/// Create a cubic Bezier segment.
pub fn cubic_bezier(
  start start: Point,
  control1 control1: Point,
  control2 control2: Point,
  end end: Point,
) -> Segment {
  CubicBezier(start:, control1:, control2:, end:)
}

/// Create an elliptical arc segment.
pub fn arc(
  start start: Point,
  radius radius: Point,
  x_axis_rotation x_axis_rotation: Float,
  large_arc large_arc: Bool,
  sweep sweep: Bool,
  end end: Point,
) -> Segment {
  Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:)
}

/// Create an elliptical arc segment from endpoint-parameter arc data.
pub fn arc_from_endpoint_data(data: ellipse.EndpointArcData) -> Segment {
  Arc(
    start: from_ellipse_point(data.start),
    radius: from_ellipse_point(data.radius),
    x_axis_rotation: data.x_axis_rotation,
    large_arc: data.large_arc,
    sweep: data.sweep,
    end: from_ellipse_point(data.end),
  )
}

/// Create an elliptical arc segment from center-parameter arc data.
pub fn arc_from_center_data(data: ellipse.CenterArcData) -> Segment {
  let endpoint = ellipse.center_to_endpoint(data)

  arc_from_endpoint_data(endpoint)
}

fn nonempty_subpaths(subpaths: List(Subpath)) -> List(Subpath) {
  subpaths
  |> list.filter(keeping: fn(subpath) { !list.is_empty(subpath.segments) })
}

fn continuous(segments: List(Segment)) -> Result(Nil, Error) {
  continuous_from(segments, previous_index: 0)
}

fn continuous_from(
  segments: List(Segment),
  previous_index previous_index: Int,
) -> Result(Nil, Error) {
  case segments {
    [] | [_] -> Ok(Nil)
    [left, right, ..rest] -> {
      let left_end = segment_end(left)
      let right_start = segment_start(right)

      case left_end == right_start {
        True -> continuous_from([right, ..rest], previous_index + 1)
        False ->
          Error(Discontinuous(
            previous_index:,
            next_index: previous_index + 1,
            expected: left_end,
            got: right_start,
            distance: distance(left_end, right_start),
          ))
      }
    }
  }
}

fn wiggle_segments(
  remaining: List(Segment),
  previous: Segment,
  segments: List(Segment),
) -> Result(List(Segment), Error) {
  case remaining {
    [] -> Ok(list.reverse([previous, ..segments]))
    [next, ..rest] -> {
      let previous_end = segment_end(previous)
      let next_start = segment_start(next)

      case previous_end == next_start {
        True -> wiggle_segments(rest, next, [previous, ..segments])
        False -> {
          case distance(previous_end, next_start) <=. default_wiggle_tolerance {
            False -> {
              Error(NotCloseEnough(
                expected: previous_end,
                got: next_start,
                tolerance: default_wiggle_tolerance,
              ))
            }
            True -> {
              case wiggle_overlap(previous, next) {
                Error(error) -> Error(error)
                Ok(overlap) -> {
                  wiggle_segments(rest, segment_with_start(next, overlap), [
                    segment_with_end(previous, overlap),
                    ..segments
                  ])
                }
              }
            }
          }
        }
      }
    }
  }
}

fn close_subpath_with(
  subpath: Subpath,
  policy: EndpointPolicy,
) -> Result(Subpath, Error) {
  case subpath.closed {
    True -> Ok(subpath)
    False -> close_open_subpath_with(subpath, policy)
  }
}

fn close_open_subpath_with(
  subpath: Subpath,
  policy: EndpointPolicy,
) -> Result(Subpath, Error) {
  case policy {
    Strict -> strict_close_open_subpath(subpath)
    Wiggle -> wiggle_close_open_subpath(subpath)
    Bridge -> line_close_open_subpath(subpath)
    WiggleThenBridge -> {
      case wiggle_close_open_subpath(subpath) {
        Ok(subpath) -> Ok(subpath)
        Error(_) -> line_close_open_subpath(subpath)
      }
    }
  }
}

fn strict_close_open_subpath(subpath: Subpath) -> Result(Subpath, Error) {
  case start_and_end(subpath) {
    Error(error) -> Error(error)
    Ok(#(first, last)) if first == last -> {
      Ok(Subpath(segments: subpath.segments, closed: True))
    }
    Ok(#(first, last)) -> {
      let previous_index = list.length(subpath.segments) - 1

      Error(Discontinuous(
        previous_index:,
        next_index: 0,
        expected: first,
        got: last,
        distance: distance(first, last),
      ))
    }
  }
}

fn wiggle_close_open_subpath(subpath: Subpath) -> Result(Subpath, Error) {
  case start_and_end(subpath) {
    Error(error) -> Error(error)
    Ok(#(first, last)) -> {
      case distance(first, last) <=. default_wiggle_tolerance {
        False -> {
          Error(NotCloseEnough(
            expected: first,
            got: last,
            tolerance: default_wiggle_tolerance,
          ))
        }
        True -> {
          case first_and_last_segments(subpath) {
            Error(error) -> Error(error)
            Ok(#(first_segment, last_segment)) -> {
              case wiggle_overlap(last_segment, first_segment) {
                Ok(overlap) -> Ok(wiggle_ends_to(subpath, overlap))
                Error(error) -> Error(error)
              }
            }
          }
        }
      }
    }
  }
}

fn line_close_open_subpath(subpath: Subpath) -> Result(Subpath, Error) {
  case start_and_end(subpath) {
    Error(error) -> Error(error)
    Ok(#(first, last)) if first == last -> strict_close_open_subpath(subpath)
    Ok(#(first, last)) -> {
      Ok(Subpath(
        segments: list.append(subpath.segments, [
          Line(start: last, end: first),
        ]),
        closed: True,
      ))
    }
  }
}

fn start_and_end(subpath: Subpath) -> Result(#(Point, Point), Error) {
  case start(subpath) {
    Error(error) -> Error(error)
    Ok(first) -> {
      case end(subpath) {
        Error(error) -> Error(error)
        Ok(last) -> Ok(#(first, last))
      }
    }
  }
}

fn first_and_last_segments(
  subpath: Subpath,
) -> Result(#(Segment, Segment), Error) {
  case subpath.segments {
    [] -> Error(EmptySubpath)
    [only] -> Ok(#(only, only))
    [first, ..rest] -> {
      case list.last(rest) {
        Ok(last) -> Ok(#(first, last))
        Error(_) -> Ok(#(first, first))
      }
    }
  }
}

fn distance(a: Point, b: Point) -> Float {
  let dx = a.x -. b.x
  let dy = a.y -. b.y
  dx *. dx +. dy *. dy |> float_square_root
}

fn float_square_root(value: Float) -> Float {
  let assert Ok(root) = float.square_root(value)
  root
}

fn midpoint(a: Point, b: Point) -> Point {
  point({ a.x +. b.x } /. 2.0, { a.y +. b.y } /. 2.0)
}

fn wiggle_overlap(previous: Segment, next: Segment) -> Result(Point, Error) {
  let previous_end = segment_end(previous)
  let next_start = segment_start(next)
  let verticals_misaligned =
    segment_is_vertical(previous)
    && segment_is_vertical(next)
    && previous_end.x != next_start.x
  let horizontals_misaligned =
    segment_is_horizontal(previous)
    && segment_is_horizontal(next)
    && previous_end.y != next_start.y

  case verticals_misaligned {
    True -> Error(IncompatibleVerticalWiggle(previous_end:, next_start:))
    False -> {
      case horizontals_misaligned {
        True -> Error(IncompatibleHorizontalWiggle(previous_end:, next_start:))
        False -> {
          Ok(point(
            wiggle_x(previous, next, previous_end, next_start),
            wiggle_y(previous, next, previous_end, next_start),
          ))
        }
      }
    }
  }
}

fn wiggle_x(
  previous: Segment,
  next: Segment,
  previous_end: Point,
  next_start: Point,
) -> Float {
  case segment_is_vertical(previous) {
    True -> previous_end.x
    False -> {
      case segment_is_vertical(next) {
        True -> next_start.x
        False -> midpoint(previous_end, next_start).x
      }
    }
  }
}

fn wiggle_y(
  previous: Segment,
  next: Segment,
  previous_end: Point,
  next_start: Point,
) -> Float {
  case segment_is_horizontal(previous) {
    True -> previous_end.y
    False -> {
      case segment_is_horizontal(next) {
        True -> next_start.y
        False -> midpoint(previous_end, next_start).y
      }
    }
  }
}

fn segment_is_vertical(segment: Segment) -> Bool {
  case segment {
    Line(start:, end:) -> start.x == end.x
    _ -> False
  }
}

fn segment_is_horizontal(segment: Segment) -> Bool {
  case segment {
    Line(start:, end:) -> start.y == end.y
    _ -> False
  }
}

fn wiggle_ends_to(subpath: Subpath, overlap: Point) -> Subpath {
  case subpath.segments {
    [] -> subpath
    [only] -> {
      Subpath(
        segments: [segment_with_start_and_end(only, overlap, overlap)],
        closed: True,
      )
    }
    [first, ..rest] -> {
      let assert Ok(#(middle, last)) = split_last(rest)

      Subpath(
        segments: [
          segment_with_start(first, overlap),
          ..list.append(middle, [
            segment_with_end(last, overlap),
          ])
        ],
        closed: True,
      )
    }
  }
}

fn split_last(items: List(a)) -> Result(#(List(a), a), Error) {
  case items {
    [] -> Error(EmptySubpath)
    [only] -> Ok(#([], only))
    [first, ..rest] -> {
      case split_last(rest) {
        Ok(#(middle, last)) -> Ok(#([first, ..middle], last))
        Error(error) -> Error(error)
      }
    }
  }
}

fn segment_with_start(segment: Segment, new_start: Point) -> Segment {
  case segment {
    Line(end:, ..) -> Line(start: new_start, end:)
    QuadraticBezier(control:, end:, ..) -> {
      QuadraticBezier(start: new_start, control:, end:)
    }
    CubicBezier(control1:, control2:, end:, ..) -> {
      CubicBezier(start: new_start, control1:, control2:, end:)
    }
    Arc(radius:, x_axis_rotation:, large_arc:, sweep:, end:, ..) -> {
      Arc(start: new_start, radius:, x_axis_rotation:, large_arc:, sweep:, end:)
    }
  }
}

fn segment_with_end(segment: Segment, new_end: Point) -> Segment {
  case segment {
    Line(start:, ..) -> Line(start:, end: new_end)
    QuadraticBezier(start:, control:, ..) -> {
      QuadraticBezier(start:, control:, end: new_end)
    }
    CubicBezier(start:, control1:, control2:, ..) -> {
      CubicBezier(start:, control1:, control2:, end: new_end)
    }
    Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, ..) -> {
      Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end: new_end)
    }
  }
}

fn segment_with_start_and_end(
  segment: Segment,
  new_start: Point,
  new_end: Point,
) -> Segment {
  segment
  |> segment_with_start(new_start)
  |> segment_with_end(new_end)
}
