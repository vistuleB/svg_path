//// Convex polygon implementation of the explicit `ConvexLoop(id)` model.

import convex_loop
import gleam/float
import gleam/int
import gleam/list
import svg_path

const support_tolerance = 0.0000001

pub fn loop(
  name: String,
  points: List(svg_path.Point),
) -> convex_loop.ConvexLoop(Int) {
  let pieces = polygon_pieces(points)
  convex_loop.ConvexLoop(
    name:,
    pieces:,
    support: fn(angle) { support(points, angle) },
    point: fn(point) { point_at(points, point) },
    piece_segments: fn(piece) { piece_segments(points, piece) },
    point_label: point_label,
  )
}

fn polygon_pieces(
  points: List(svg_path.Point),
) -> List(convex_loop.LoopPiece(Int)) {
  int.range(
    from: 0,
    to: list.length(points) - 1,
    with: [],
    run: fn(pieces, index) {
      let from = convex_loop.SourcePoint(id: index, t: 0.0)
      let to =
        convex_loop.SourcePoint(
          id: next_index(index, list.length(points)),
          t: 0.0,
        )
      [convex_loop.Line(from:, to:), ..pieces]
    },
  )
  |> list.reverse
}

fn support(
  points: List(svg_path.Point),
  angle: Float,
) -> convex_loop.Support(Int) {
  let assert [first, ..rest] = points
  let direction = convex_loop.direction(angle)
  let first_value = convex_loop.dot(first, direction)
  let max_value =
    rest
    |> list.fold(first_value, fn(best, point) {
      float.max(best, convex_loop.dot(point, direction))
    })

  let max_vertices =
    points
    |> list.index_fold([], fn(vertices, point, index) {
      case
        float.absolute_value(convex_loop.dot(point, direction) -. max_value)
        <=. support_tolerance
      {
        True -> [#(index, point), ..vertices]
        False -> vertices
      }
    })
    |> list.reverse

  convex_loop.Support(
    value: max_value,
    set: support_set(max_vertices, count: list.length(points)),
  )
}

fn support_set(
  max_vertices: List(#(Int, svg_path.Point)),
  count count: Int,
) -> convex_loop.SupportSet(Int) {
  case max_vertices {
    [#(index, _)] ->
      convex_loop.SupportPoint(convex_loop.SourcePoint(id: index, t: 0.0))
    [first, second] -> {
      let #(from, to) = order_face_endpoints(first, second, count:)
      let #(from_index, _) = from
      let #(to_index, _) = to
      convex_loop.SupportFace(
        from: convex_loop.SourcePoint(id: from_index, t: 0.0),
        to: convex_loop.SourcePoint(id: to_index, t: 0.0),
      )
    }
    [#(index, _), ..] ->
      convex_loop.SupportPoint(convex_loop.SourcePoint(id: index, t: 0.0))
    [] -> convex_loop.SupportPoint(convex_loop.SourcePoint(id: 0, t: 0.0))
  }
}

fn order_face_endpoints(
  first: #(Int, svg_path.Point),
  second: #(Int, svg_path.Point),
  count count: Int,
) -> #(#(Int, svg_path.Point), #(Int, svg_path.Point)) {
  let #(first_index, _) = first
  let #(second_index, _) = second
  case next_index(first_index, count) == second_index {
    True -> #(first, second)
    False -> #(second, first)
  }
}

fn point_at(
  points: List(svg_path.Point),
  point: convex_loop.LoopPoint(Int),
) -> svg_path.Point {
  let convex_loop.SourcePoint(id:, t: _) = point
  let assert Ok(position) = nth(points, id)
  position
}

fn piece_segments(
  points: List(svg_path.Point),
  piece: convex_loop.LoopPiece(Int),
) -> List(svg_path.Segment) {
  case piece {
    convex_loop.Line(from:, to:) -> [
      svg_path.line(start: point_at(points, from), end: point_at(points, to)),
    ]
    convex_loop.Curve(..) -> []
  }
}

fn next_index(index: Int, count: Int) -> Int {
  case index + 1 >= count {
    True -> 0
    False -> index + 1
  }
}

fn point_label(point: convex_loop.LoopPoint(Int)) -> String {
  let convex_loop.SourcePoint(id:, t: _) = point
  "v" <> int.to_string(id)
}

fn nth(items: List(a), index: Int) -> Result(a, Nil) {
  case items, index {
    [], _ -> Error(Nil)
    [item, ..], 0 -> Ok(item)
    [_, ..rest], _ -> nth(rest, index - 1)
  }
}
