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
                crossings: insert_crossing(
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

fn insert_crossing(
  crossings: List(Float),
  crossing: Float,
  tolerance: Float,
) -> List(Float) {
  case crossings {
    [previous, ..] -> {
      case float.absolute_value(previous -. crossing) <=. tolerance {
        True -> crossings
        False -> [crossing, ..crossings]
      }
    }
    _ -> [crossing, ..crossings]
  }
}

fn is_close_to_zero(value: Float, tolerance: Float) -> Bool {
  float.absolute_value(value) <=. tolerance
}

fn same_sign(a: Float, b: Float) -> Bool {
  a <. 0.0 && b <. 0.0 || a >. 0.0 && b >. 0.0
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
