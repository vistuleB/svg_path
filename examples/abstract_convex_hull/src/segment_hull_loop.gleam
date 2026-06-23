//// Approximate support wrapper around the real `svg_path.segment_hull`.
////
//// This hydrates the abstract loop-union experiment with actual library
//// geometry. It now wraps the materialized hull subpath only; production no
//// longer exposes the trace pieces that originally powered this experiment.

import abstract_union
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import svg_path
import svg_path/convex_hull

pub type Param {
  Param(segment_index: Int, t: Float)
}

pub fn loop(
  name: String,
  segment: svg_path.Segment,
) -> Result(abstract_union.Loop(Param), convex_hull.HullError) {
  use hull <- result.try(convex_hull.segment_hull(segment))
  let segments = svg_path.segments(hull)

  Ok(abstract_union.Loop(
    name:,
    support: fn(angle) { support(segments, angle) },
    point: fn(param) { point_at(segments, param) },
    piece_segments: fn(from, to) { piece_segments(segments, from, to) },
    param_label: param_label,
  ))
}

fn support(
  segments: List(svg_path.Segment),
  angle: Float,
) -> abstract_union.Support(Param) {
  let direction = abstract_union.direction(angle)
  let assert [first, ..rest] = segments
  let first_support = segment_support(first, 0, direction)

  rest
  |> list.index_fold(first_support, fn(best, segment, index) {
    let candidate = segment_support(segment, index + 1, direction)
    case candidate.value >. best.value {
      True -> candidate
      False -> best
    }
  })
}

fn segment_support(
  segment: svg_path.Segment,
  index: Int,
  direction: svg_path.Point,
) -> abstract_union.Support(Param) {
  let assert Ok(t) =
    svg_path.segment_minimize(segment, measure: fn(point) {
      0.0 -. abstract_union.dot(point, direction)
    })
  let assert Ok(point) = svg_path.segment_point(segment, at: t)
  abstract_union.Support(
    param: Param(segment_index: index, t: t),
    point:,
    value: abstract_union.dot(point, direction),
  )
}

fn point_at(segments: List(svg_path.Segment), param: Param) -> svg_path.Point {
  let assert Ok(segment) = nth(segments, param.segment_index)
  let assert Ok(point) = svg_path.segment_point(segment, at: param.t)
  point
}

fn piece_segments(
  segments: List(svg_path.Segment),
  from: Param,
  to: Param,
) -> List(svg_path.Segment) {
  case from.segment_index == to.segment_index {
    True -> [
      partial_segment(segment_at(segments, from.segment_index), from.t, to.t),
    ]
    False ->
      walk_segment_indices(
        from.segment_index,
        to.segment_index,
        list.length(segments),
        [],
      )
      |> list.reverse
      |> list.map(fn(index) {
        let segment = segment_at(segments, index)
        case index == from.segment_index, index == to.segment_index {
          True, _ -> partial_segment(segment, from.t, 1.0)
          _, True -> partial_segment(segment, 0.0, to.t)
          _, _ -> partial_segment(segment, 0.0, 1.0)
        }
      })
  }
}

fn partial_segment(
  segment: svg_path.Segment,
  from: Float,
  to: Float,
) -> svg_path.Segment {
  let assert Ok(part) = svg_path.sub_segment(segment, from: from, to: to)
  part
}

fn segment_at(
  segments: List(svg_path.Segment),
  index: Int,
) -> svg_path.Segment {
  let assert Ok(segment) = nth(segments, index)
  segment
}

fn walk_segment_indices(
  current: Int,
  target: Int,
  count: Int,
  indices: List(Int),
) -> List(Int) {
  case current == target {
    True -> [current, ..indices]
    False ->
      walk_segment_indices(next_index(current, count), target, count, [
        current,
        ..indices
      ])
  }
}

fn next_index(index: Int, count: Int) -> Int {
  case index + 1 >= count {
    True -> 0
    False -> index + 1
  }
}

fn param_label(param: Param) -> String {
  "segment "
  <> int.to_string(param.segment_index)
  <> "@t="
  <> float.to_string(param.t)
}

fn nth(items: List(a), index: Int) -> Result(a, Nil) {
  case items, index {
    [], _ -> Error(Nil)
    [item, ..], 0 -> Ok(item)
    [_, ..rest], _ -> nth(rest, index - 1)
  }
}
