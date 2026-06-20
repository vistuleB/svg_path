//// Core SVG path data structures and constructors.
////
//// This module models paths as a list of subpaths, and subpaths as continuous
//// segment lists. Use `svg_path/parse` and `svg_path/serialize` when working
//// directly with SVG path data strings.

import gleam/float
import gleam/list
import svg_path/ellipse
import vec/vec2.{type Vec2, Vec2}

const default_wiggle_tolerance = 0.000000001

/// A 2D point.
///
/// This is a `vec.Vec2(Float)`, so its coordinates are available as `.x` and
/// `.y`.
pub type Point =
  Vec2(Float)

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

  /// The operation requires a path with at least one subpath.
  EmptyPath

  /// The operation requires a path with at least one non-empty subpath.
  EmptySubpaths

  /// A wiggle operation could not reconcile two horizontal line segments.
  IncompatibleHorizontalWiggle(previous_end: Point, next_start: Point)

  /// A wiggle operation could not reconcile two vertical line segments.
  IncompatibleVerticalWiggle(previous_end: Point, next_start: Point)

  /// A splice was requested with invalid bounds.
  ///
  /// This is returned when `start` is negative, `delete` is negative, or
  /// `start` is greater than the subpath length.
  InvalidSplice(start: Int, delete: Int, length: Int)

  /// The path contains more than one non-empty subpath.
  MultipleNonemptySubpaths

  /// Two points were too far apart for a wiggle operation to merge them.
  NotCloseEnough(expected: Point, got: Point, tolerance: Float)
}

/// Create a point from `x` and `y` coordinates.
pub fn point(x: Float, y: Float) -> Point {
  Vec2(x, y)
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
