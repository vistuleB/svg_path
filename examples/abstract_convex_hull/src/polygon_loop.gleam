//// Exact convex polygon loop implementation for the abstract union experiment.

import abstract_union
import gleam/int
import gleam/list
import svg_path

pub type Param {
  Vertex(Int)
}

pub fn loop(
  name: String,
  points: List(svg_path.Point),
) -> abstract_union.Loop(Param) {
  abstract_union.Loop(
    name:,
    support: fn(angle) { support(points, angle) },
    point: fn(param) { point_at(points, param) },
    piece_segments: fn(from, to) { piece_segments(points, from, to) },
    param_label: param_label,
  )
}

fn support(
  points: List(svg_path.Point),
  angle: Float,
) -> abstract_union.Support(Param) {
  let direction = abstract_union.direction(angle)
  let assert [first, ..rest] = points
  let best =
    rest
    |> list.index_fold(
      #(0, first, abstract_union.dot(first, direction)),
      fn(best, point, index) {
        let value = abstract_union.dot(point, direction)
        case value >. best.2 {
          True -> #(index + 1, point, value)
          False -> best
        }
      },
    )

  abstract_union.Support(param: Vertex(best.0), point: best.1, value: best.2)
}

fn point_at(points: List(svg_path.Point), param: Param) -> svg_path.Point {
  let Vertex(index) = param
  let assert Ok(point) = nth(points, index)
  point
}

fn piece_segments(
  points: List(svg_path.Point),
  from: Param,
  to: Param,
) -> List(svg_path.Segment) {
  let Vertex(from_index) = from
  let Vertex(to_index) = to
  let count = list.length(points)

  case from_index == to_index {
    True -> polygon_segments(points)
    False ->
      walk_indices(from_index, to_index, count, [])
      |> list.reverse
      |> adjacent_index_pairs
      |> list.map(fn(pair) {
        let #(a, b) = pair
        svg_path.line(
          start: point_at(points, Vertex(a)),
          end: point_at(points, Vertex(b)),
        )
      })
  }
}

fn polygon_segments(points: List(svg_path.Point)) -> List(svg_path.Segment) {
  int.range(
    from: 0,
    to: list.length(points) - 1,
    with: [],
    run: fn(indices, index) { [index, ..indices] },
  )
  |> list.reverse
  |> index_pairs
  |> list.map(fn(pair) {
    let #(a, b) = pair
    svg_path.line(
      start: point_at(points, Vertex(a)),
      end: point_at(points, Vertex(b)),
    )
  })
}

fn walk_indices(
  current: Int,
  target: Int,
  count: Int,
  indices: List(Int),
) -> List(Int) {
  case current == target {
    True -> [current, ..indices]
    False ->
      walk_indices(next_index(current, count), target, count, [
        current,
        ..indices
      ])
  }
}

fn index_pairs(indices: List(Int)) -> List(#(Int, Int)) {
  case indices {
    [] | [_] -> []
    [first, ..] -> index_pairs_loop(indices, first, [])
  }
}

fn adjacent_index_pairs(indices: List(Int)) -> List(#(Int, Int)) {
  case indices {
    [] | [_] -> []
    [left, right, ..rest] -> [
      #(left, right),
      ..adjacent_index_pairs([right, ..rest])
    ]
  }
}

fn index_pairs_loop(indices: List(Int), first: Int, pairs: List(#(Int, Int))) {
  case indices {
    [] -> pairs |> list.reverse
    [last] -> [#(last, first), ..pairs] |> list.reverse
    [left, right, ..rest] ->
      index_pairs_loop([right, ..rest], first, [#(left, right), ..pairs])
  }
}

fn next_index(index: Int, count: Int) -> Int {
  case index + 1 >= count {
    True -> 0
    False -> index + 1
  }
}

fn param_label(param: Param) -> String {
  let Vertex(index) = param
  "v" <> int.to_string(index)
}

fn nth(items: List(a), index: Int) -> Result(a, Nil) {
  case items, index {
    [], _ -> Error(Nil)
    [item, ..], 0 -> Ok(item)
    [_, ..rest], _ -> nth(rest, index - 1)
  }
}
