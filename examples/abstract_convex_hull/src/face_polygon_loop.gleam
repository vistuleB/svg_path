//// Face-aware convex polygon loop.

import face_union
import gleam/float
import gleam/int
import gleam/list
import svg_path

const support_tolerance = 0.0000001

pub type Param {
  Vertex(Int)
}

pub fn loop(
  name: String,
  points: List(svg_path.Point),
) -> face_union.Loop(Param) {
  face_union.Loop(
    name:,
    support: fn(angle) { support(points, angle) },
    point: fn(param) { point_at(points, param) },
    param_label: param_label,
  )
}

fn support(
  points: List(svg_path.Point),
  angle: Float,
) -> face_union.Support(Param) {
  let direction = face_union.direction(angle)
  let assert [first, ..rest] = points
  let first_value = face_union.dot(first, direction)
  let max_value =
    rest
    |> list.fold(first_value, fn(best, point) {
      float.max(best, face_union.dot(point, direction))
    })

  let max_vertices =
    points
    |> list.index_fold([], fn(vertices, point, index) {
      case
        float.absolute_value(face_union.dot(point, direction) -. max_value)
        <=. support_tolerance
      {
        True -> [#(index, point), ..vertices]
        False -> vertices
      }
    })
    |> list.reverse

  face_union.Support(value: max_value, set: support_set(points, max_vertices))
}

fn support_set(
  points: List(svg_path.Point),
  max_vertices: List(#(Int, svg_path.Point)),
) -> face_union.SupportSet(Param) {
  case max_vertices {
    [#(index, point)] -> face_union.SupportPoint(Vertex(index), point)
    [first, second] -> {
      let #(from, to) =
        order_face_endpoints(first, second, count: list.length(points))
      let #(from_index, from_point) = from
      let #(to_index, to_point) = to
      face_union.SupportFace(
        from: Vertex(from_index),
        to: Vertex(to_index),
        from_point: from_point,
        to_point: to_point,
      )
    }
    [first, ..] -> {
      let #(index, point) = first
      face_union.SupportPoint(Vertex(index), point)
    }
    [] -> face_union.SupportPoint(Vertex(0), point_at(points, Vertex(0)))
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

fn point_at(points: List(svg_path.Point), param: Param) -> svg_path.Point {
  let Vertex(index) = param
  let assert Ok(point) = nth(points, index)
  point
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
