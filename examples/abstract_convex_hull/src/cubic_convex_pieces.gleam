//// Split cubics at inflection roots and union primitive-plus-chord loops.

import abstract_union
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import materialized_loop
import primitive_loop
import svg_path

const root_tolerance = 0.000000001

pub fn split_at_inflections(
  segment: svg_path.Segment,
) -> Result(List(svg_path.Segment), svg_path.Error) {
  case segment {
    svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      let ts =
        inflection_roots(start, control1, control2, end)
        |> list.filter(fn(t) {
          t >. root_tolerance && t <. 1.0 -. root_tolerance
        })
        |> sort_floats
        |> unique_close

      split_by_ts(segment, ts)
    }
    _ -> Ok([segment])
  }
}

fn split_by_ts(
  segment: svg_path.Segment,
  ts: List(Float),
) -> Result(List(svg_path.Segment), svg_path.Error) {
  let bounds = list.append([0.0, ..ts], [1.0])
  adjacent_pairs(bounds)
  |> list.try_map(fn(pair) {
    let #(from, to) = pair
    svg_path.sub_segment(segment, from: from, to: to)
  })
}

fn adjacent_pairs(values: List(Float)) -> List(#(Float, Float)) {
  case values {
    [] | [_] -> []
    [a, b, ..rest] -> [#(a, b), ..adjacent_pairs([b, ..rest])]
  }
}

pub fn hull_segments(
  segment: svg_path.Segment,
) -> Result(List(svg_path.Segment), svg_path.Error) {
  use pieces <- result.try(split_at_inflections(segment))
  case pieces {
    [] -> Ok([])
    [single] -> Ok(primitive_segments(single))
    [first, second, ..rest] -> {
      use segments <- result.try(union_to_segments(
        primitive_loop.loop("piece 0", first),
        primitive_loop.loop("piece 1", second),
      ))
      fold_remaining(rest, 2, segments)
    }
  }
}

fn fold_remaining(
  remaining: List(svg_path.Segment),
  index: Int,
  current_segments: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), svg_path.Error) {
  case remaining {
    [] -> Ok(current_segments)
    [segment, ..rest] -> {
      let current_loop = materialized_loop.loop("current", current_segments)
      let next_loop =
        primitive_loop.loop("piece " <> int.to_string(index), segment)
      use next_segments <- result.try(union_to_segments(current_loop, next_loop))
      fold_remaining(rest, index + 1, next_segments)
    }
  }
}

fn union_to_segments(
  loop_a: abstract_union.Loop(a),
  loop_b: abstract_union.Loop(b),
) -> Result(List(svg_path.Segment), svg_path.Error) {
  let pieces = abstract_union.union(loop_a, loop_b, sample_count: 720)
  use subpath <- result.try(abstract_union.union_subpath(pieces, loop_a, loop_b))
  Ok(svg_path.segments(subpath))
}

fn primitive_segments(segment: svg_path.Segment) -> List(svg_path.Segment) {
  let start = segment_start(segment)
  let end = segment_end(segment)
  [segment, svg_path.line(start: end, end: start)]
}

fn segment_start(segment: svg_path.Segment) -> svg_path.Point {
  case segment {
    svg_path.Line(start:, ..)
    | svg_path.QuadraticBezier(start:, ..)
    | svg_path.CubicBezier(start:, ..)
    | svg_path.Arc(start:, ..) -> start
  }
}

fn segment_end(segment: svg_path.Segment) -> svg_path.Point {
  case segment {
    svg_path.Line(end:, ..)
    | svg_path.QuadraticBezier(end:, ..)
    | svg_path.CubicBezier(end:, ..)
    | svg_path.Arc(end:, ..) -> end
  }
}

fn inflection_roots(
  p0: svg_path.Point,
  p1: svg_path.Point,
  p2: svg_path.Point,
  p3: svg_path.Point,
) -> List(Float) {
  let a =
    add_points(
      subtract(scale_point(p1, 3.0), p0),
      subtract(p3, scale_point(p2, 3.0)),
    )
  let b =
    add_points(
      subtract(scale_point(p0, 3.0), scale_point(p1, 6.0)),
      scale_point(p2, 3.0),
    )
  let c = subtract(scale_point(p1, 3.0), scale_point(p0, 3.0))

  quadratic_roots(-6.0 *. cross(a, b), 6.0 *. cross(c, a), 2.0 *. cross(c, b))
}

fn quadratic_roots(a: Float, b: Float, c: Float) -> List(Float) {
  case float.absolute_value(a) <. 0.000000000001 {
    True ->
      case float.absolute_value(b) <. 0.000000000001 {
        True -> []
        False -> [{ 0.0 -. c } /. b]
      }
    False -> {
      let discriminant = b *. b -. 4.0 *. a *. c
      case discriminant <. 0.0 {
        True -> []
        False -> {
          let assert Ok(root) = float.square_root(discriminant)
          [
            { 0.0 -. b -. root } /. { 2.0 *. a },
            { 0.0 -. b +. root } /. { 2.0 *. a },
          ]
        }
      }
    }
  }
}

fn sort_floats(values: List(Float)) -> List(Float) {
  list.sort(values, by: float.compare)
}

fn unique_close(values: List(Float)) -> List(Float) {
  case values {
    [] -> []
    [first, ..rest] -> unique_close_loop(rest, first, [first]) |> list.reverse
  }
}

fn unique_close_loop(
  values: List(Float),
  previous: Float,
  kept: List(Float),
) -> List(Float) {
  case values {
    [] -> kept
    [value, ..rest] -> {
      case float.absolute_value(value -. previous) <=. root_tolerance {
        True -> unique_close_loop(rest, previous, kept)
        False -> unique_close_loop(rest, value, [value, ..kept])
      }
    }
  }
}

fn add_points(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.point(a.x +. b.x, a.y +. b.y)
}

fn subtract(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.point(a.x -. b.x, a.y -. b.y)
}

fn scale_point(a: svg_path.Point, factor: Float) -> svg_path.Point {
  svg_path.point(a.x *. factor, a.y *. factor)
}

fn cross(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.y -. a.y *. b.x
}
