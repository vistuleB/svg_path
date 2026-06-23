//// Convex loop for a primitive curve plus the chord between its endpoints.

import abstract_union
import gleam/float
import gleam/int
import gleam/list
import svg_path

pub type Param {
  Param(piece_index: Int, t: Float)
}

pub fn loop(
  name: String,
  segment: svg_path.Segment,
) -> abstract_union.Loop(Param) {
  let pieces = primitive_pieces(segment)
  abstract_union.Loop(
    name:,
    support: fn(angle) { support(pieces, angle) },
    point: fn(param) { point_at(pieces, param) },
    piece_segments: fn(from, to) { piece_segments(pieces, from, to) },
    param_label: param_label,
  )
}

fn primitive_pieces(segment: svg_path.Segment) -> List(svg_path.Segment) {
  let start = segment_start(segment)
  let end = segment_end(segment)
  [segment, svg_path.line(start: end, end: start)]
}

fn support(
  pieces: List(svg_path.Segment),
  angle: Float,
) -> abstract_union.Support(Param) {
  let assert [first, ..rest] = pieces
  let first_support = piece_support(first, 0, angle)
  rest
  |> list.index_fold(first_support, fn(best, piece, index) {
    let candidate = piece_support(piece, index + 1, angle)
    case candidate.value >. best.value {
      True -> candidate
      False -> best
    }
  })
}

fn piece_support(
  piece: svg_path.Segment,
  index: Int,
  angle: Float,
) -> abstract_union.Support(Param) {
  let direction = abstract_union.direction(angle)
  let t = support_t(piece, direction)
  let assert Ok(point) = svg_path.segment_point(piece, at: t)
  abstract_union.Support(
    param: Param(piece_index: index, t: t),
    point:,
    value: abstract_union.dot(point, direction),
  )
}

fn support_t(piece: svg_path.Segment, direction: svg_path.Point) -> Float {
  case piece {
    svg_path.Line(start:, end:) -> {
      let start_value = abstract_union.dot(start, direction)
      let end_value = abstract_union.dot(end, direction)
      case start_value >=. end_value {
        True -> 0.0
        False -> 1.0
      }
    }
    svg_path.CubicBezier(start:, control1:, control2:, end:) ->
      cubic_support_t(start, control1, control2, end, direction)
    _ -> {
      let assert Ok(t) =
        svg_path.segment_minimize(piece, measure: fn(point) {
          0.0 -. abstract_union.dot(point, direction)
        })
      t
    }
  }
}

fn cubic_support_t(
  start: svg_path.Point,
  control1: svg_path.Point,
  control2: svg_path.Point,
  end: svg_path.Point,
  direction: svg_path.Point,
) -> Float {
  let p0 = abstract_union.dot(start, direction)
  let p1 = abstract_union.dot(control1, direction)
  let p2 = abstract_union.dot(control2, direction)
  let p3 = abstract_union.dot(end, direction)
  let a = 0.0 -. p0 +. 3.0 *. p1 -. 3.0 *. p2 +. p3
  let b = 3.0 *. p0 -. 6.0 *. p1 +. 3.0 *. p2
  let c = -3.0 *. p0 +. 3.0 *. p1

  let candidates =
    [0.0, 1.0, ..quadratic_roots(3.0 *. a, 2.0 *. b, c)]
    |> list.filter(fn(t) { t >=. 0.0 && t <=. 1.0 })

  let assert [first, ..rest] = candidates
  let best =
    list.fold(rest, #(first, cubic_scalar(p0, p1, p2, p3, first)), fn(best, t) {
      let value = cubic_scalar(p0, p1, p2, p3, t)
      case value >. best.1 {
        True -> #(t, value)
        False -> best
      }
    })

  best.0
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

fn cubic_scalar(p0: Float, p1: Float, p2: Float, p3: Float, t: Float) -> Float {
  let mt = 1.0 -. t
  p0
  *. mt
  *. mt
  *. mt
  +. 3.0
  *. p1
  *. mt
  *. mt
  *. t
  +. 3.0
  *. p2
  *. mt
  *. t
  *. t
  +. p3
  *. t
  *. t
  *. t
}

fn point_at(pieces: List(svg_path.Segment), param: Param) -> svg_path.Point {
  let assert Ok(piece) = nth(pieces, param.piece_index)
  let assert Ok(point) = svg_path.segment_point(piece, at: param.t)
  point
}

fn piece_segments(
  pieces: List(svg_path.Segment),
  from: Param,
  to: Param,
) -> List(svg_path.Segment) {
  case from.piece_index == to.piece_index {
    True -> [partial_piece(piece_at(pieces, from.piece_index), from.t, to.t)]
    False ->
      walk_piece_indices(
        from.piece_index,
        to.piece_index,
        list.length(pieces),
        [],
      )
      |> list.reverse
      |> list.map(fn(index) {
        let piece = piece_at(pieces, index)
        case index == from.piece_index, index == to.piece_index {
          True, _ -> partial_piece(piece, from.t, 1.0)
          _, True -> partial_piece(piece, 0.0, to.t)
          _, _ -> partial_piece(piece, 0.0, 1.0)
        }
      })
  }
}

fn partial_piece(
  piece: svg_path.Segment,
  from: Float,
  to: Float,
) -> svg_path.Segment {
  let assert Ok(segment) = svg_path.sub_segment(piece, from: from, to: to)
  segment
}

fn piece_at(pieces: List(svg_path.Segment), index: Int) -> svg_path.Segment {
  let assert Ok(piece) = nth(pieces, index)
  piece
}

fn walk_piece_indices(
  current: Int,
  target: Int,
  count: Int,
  indices: List(Int),
) -> List(Int) {
  case current == target {
    True -> [current, ..indices]
    False ->
      walk_piece_indices(next_index(current, count), target, count, [
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

fn param_label(param: Param) -> String {
  "piece "
  <> int.to_string(param.piece_index)
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
