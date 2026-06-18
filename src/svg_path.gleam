import gleam/float
import gleam/list
import vec/vec2.{type Vec2, Vec2}

const default_wiggle_tolerance = 0.000000001

pub type Point =
  Vec2(Float)

pub type Path {
  Path(subpaths: List(Subpath))
}

pub opaque type Subpath {
  Subpath(segments: List(Segment), closed: Bool)
}

pub type Segment {
  Line(start: Point, end: Point)
  QuadraticBezier(start: Point, control: Point, end: Point)
  CubicBezier(start: Point, control1: Point, control2: Point, end: Point)
  Arc(
    start: Point,
    radius: Point,
    x_axis_rotation: Float,
    large_arc: Bool,
    sweep: Bool,
    end: Point,
  )
}

pub type Error {
  AlreadyClosed
  Discontinuous(expected: Point, got: Point)
  EmptySubpath
  IncompatibleHorizontalWiggle(previous_end: Point, next_start: Point)
  IncompatibleVerticalWiggle(previous_end: Point, next_start: Point)
  MultipleNonemptySubpaths
  NotCloseEnough(expected: Point, got: Point, tolerance: Float)
}

pub fn point(x: Float, y: Float) -> Point {
  Vec2(x, y)
}

pub fn empty_path() -> Path {
  Path([])
}

pub fn path(subpaths: List(Subpath)) -> Path {
  Path(subpaths:)
}

pub fn subpaths(path: Path) -> List(Subpath) {
  path.subpaths
}

pub fn from_subpath(subpath: Subpath) -> Path {
  path([subpath])
}

pub fn append_subpath(path: Path, subpath: Subpath) -> Path {
  Path(subpaths: list.append(path.subpaths, [subpath]))
}

pub fn as_subpath(path: Path) -> Result(Subpath, Error) {
  case nonempty_subpaths(path.subpaths) {
    [] -> Ok(empty_subpath())
    [subpath] -> Ok(subpath)
    [_, _, ..] -> Error(MultipleNonemptySubpaths)
  }
}

pub fn empty_subpath() -> Subpath {
  Subpath(segments: [], closed: False)
}

pub fn subpath(segments: List(Segment)) -> Result(Subpath, Error) {
  case continuous(segments) {
    Ok(Nil) -> Ok(Subpath(segments:, closed: False))
    Error(error) -> Error(error)
  }
}

pub fn segments(subpath: Subpath) -> List(Segment) {
  subpath.segments
}

pub fn is_closed(subpath: Subpath) -> Bool {
  subpath.closed
}

pub fn start(subpath: Subpath) -> Result(Point, Error) {
  case subpath.segments {
    [] -> Error(EmptySubpath)
    [first, ..] -> Ok(segment_start(first))
  }
}

pub fn end(subpath: Subpath) -> Result(Point, Error) {
  case list.last(subpath.segments) {
    Ok(last) -> Ok(segment_end(last))
    Error(_) -> Error(EmptySubpath)
  }
}

pub fn append(subpath: Subpath, segment: Segment) -> Result(Subpath, Error) {
  case subpath.closed {
    True -> Error(AlreadyClosed)
    False -> append_open_subpath(subpath, segment)
  }
}

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

pub fn segment_start(segment: Segment) -> Point {
  case segment {
    Line(start:, ..)
    | QuadraticBezier(start:, ..)
    | CubicBezier(start:, ..)
    | Arc(start:, ..) -> start
  }
}

pub fn segment_end(segment: Segment) -> Point {
  case segment {
    Line(end:, ..)
    | QuadraticBezier(end:, ..)
    | CubicBezier(end:, ..)
    | Arc(end:, ..) -> end
  }
}

pub fn line(start start: Point, end end: Point) -> Segment {
  Line(start:, end:)
}

pub fn quadratic_bezier(
  start start: Point,
  control control: Point,
  end end: Point,
) -> Segment {
  QuadraticBezier(start:, control:, end:)
}

pub fn cubic_bezier(
  start start: Point,
  control1 control1: Point,
  control2 control2: Point,
  end end: Point,
) -> Segment {
  CubicBezier(start:, control1:, control2:, end:)
}

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
