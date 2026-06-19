//// Core SVG path data structures and constructors.
////
//// This module models paths as a list of subpaths, and subpaths as continuous
//// segment lists. Use `svg_path/parse` and `svg_path/serialize` when working
//// directly with SVG path data strings.

import gleam/float
import gleam/list
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
/// discontinuous state. Use `subpath`, `empty_subpath`, `append`, or
/// `force_append` to build values.
pub opaque type Subpath {
  Subpath(segments: List(Segment), closed: Bool)
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

  /// A segment starts somewhere other than the previous segment's end point.
  Discontinuous(expected: Point, got: Point)

  /// The operation requires a non-empty subpath.
  EmptySubpath

  /// A wiggle operation could not reconcile two horizontal line segments.
  IncompatibleHorizontalWiggle(previous_end: Point, next_start: Point)

  /// A wiggle operation could not reconcile two vertical line segments.
  IncompatibleVerticalWiggle(previous_end: Point, next_start: Point)

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
/// previous segment's end point.
pub fn subpath(segments: List(Segment)) -> Result(Subpath, Error) {
  case continuous(segments) {
    Ok(Nil) -> Ok(Subpath(segments:, closed: False))
    Error(error) -> Error(error)
  }
}

/// Create an open subpath while gently reconciling tiny endpoint gaps.
///
/// This is useful after floating-point transformations. If adjacent segment
/// endpoints are within the default wiggle tolerance, the overlap point is used
/// to make the segments continuous.
pub fn wiggle_subpath(segments: List(Segment)) -> Result(Subpath, Error) {
  case segments {
    [] | [_] -> subpath(segments)
    [first, ..rest] -> {
      case wiggle_segments(rest, first, []) {
        Ok(segments) -> Ok(Subpath(segments:, closed: False))
        Error(error) -> Error(error)
      }
    }
  }
}

/// Return the segments in a subpath.
pub fn segments(subpath: Subpath) -> List(Segment) {
  subpath.segments
}

/// Check whether a subpath is closed.
pub fn is_closed(subpath: Subpath) -> Bool {
  subpath.closed
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

/// Append a segment to an open subpath.
///
/// The new segment must start exactly at the current end point.
pub fn append(subpath: Subpath, segment: Segment) -> Result(Subpath, Error) {
  case subpath.closed {
    True -> Error(AlreadyClosed)
    False -> append_open_subpath(subpath, segment)
  }
}

/// Append a segment to an open subpath, inserting a connecting line if needed.
///
/// If the subpath is empty, this behaves like `append`. If the new segment does
/// not start at the current end point, a line segment is inserted between them.
pub fn force_append(
  subpath: Subpath,
  segment: Segment,
) -> Result(Subpath, Error) {
  case subpath.closed {
    True -> Error(AlreadyClosed)
    False -> {
      case end(subpath) {
        Error(EmptySubpath) -> append_open_subpath(subpath, segment)
        Ok(previous_end) -> {
          let next_start = segment_start(segment)

          case previous_end == next_start {
            True -> append_open_subpath(subpath, segment)
            False -> {
              Ok(Subpath(
                segments: list.append(subpath.segments, [
                  Line(start: previous_end, end: next_start),
                  segment,
                ]),
                closed: False,
              ))
            }
          }
        }
        Error(error) -> Error(error)
      }
    }
  }
}

/// Close a subpath if its start and end points already match.
pub fn close(subpath: Subpath) -> Result(Subpath, Error) {
  case subpath.closed {
    True -> Ok(subpath)
    False -> {
      case start_and_end(subpath) {
        Error(error) -> Error(error)
        Ok(#(first, last)) if first == last -> {
          Ok(Subpath(segments: subpath.segments, closed: True))
        }
        Ok(#(first, last)) -> Error(Discontinuous(expected: first, got: last))
      }
    }
  }
}

/// Close a subpath, inserting a line back to the start point if needed.
pub fn force_close(subpath: Subpath) -> Result(Subpath, Error) {
  case subpath.closed {
    True -> Ok(subpath)
    False -> {
      case start_and_end(subpath) {
        Error(error) -> Error(error)
        Ok(#(first, last)) if first == last -> close(subpath)
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
  }
}

/// Close a subpath while gently reconciling tiny endpoint gaps.
///
/// This is useful after floating-point transformations that should preserve
/// closure but leave endpoints off by a very small amount.
pub fn wiggle_close(subpath: Subpath) -> Result(Subpath, Error) {
  case subpath.closed {
    True -> Ok(subpath)
    False -> {
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

fn append_open_subpath(
  subpath: Subpath,
  segment: Segment,
) -> Result(Subpath, Error) {
  case end(subpath) {
    Error(EmptySubpath) -> {
      Ok(Subpath(segments: [segment], closed: False))
    }
    Ok(previous_end) -> {
      let next_start = segment_start(segment)

      case previous_end == next_start {
        True -> {
          Ok(Subpath(
            segments: list.append(subpath.segments, [segment]),
            closed: False,
          ))
        }
        False -> Error(Discontinuous(expected: previous_end, got: next_start))
      }
    }
    Error(error) -> Error(error)
  }
}

fn nonempty_subpaths(subpaths: List(Subpath)) -> List(Subpath) {
  subpaths
  |> list.filter(keeping: fn(subpath) { !list.is_empty(subpath.segments) })
}

fn continuous(segments: List(Segment)) -> Result(Nil, Error) {
  case segments {
    [] | [_] -> Ok(Nil)
    [left, right, ..rest] -> {
      let left_end = segment_end(left)
      let right_start = segment_start(right)

      case left_end == right_start {
        True -> continuous([right, ..rest])
        False -> Error(Discontinuous(expected: left_end, got: right_start))
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
