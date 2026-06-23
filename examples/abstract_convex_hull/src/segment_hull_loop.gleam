//// Approximate support wrapper around the real `svg_path.segment_hull`.
////
//// This hydrates the abstract loop-union experiment with actual library
//// geometry. Curved support is sampled rather than solved exactly; that is
//// enough for exploring the loop-union shape without touching production code.

import abstract_union
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import svg_path
import svg_path/convex_hull

const curve_support_samples = 180

pub type Param {
  Param(piece_index: Int, t: Float)
}

type Piece {
  Piece(index: Int, hull_piece: convex_hull.HullPiece)
}

pub fn loop(
  name: String,
  segment: svg_path.Segment,
) -> Result(abstract_union.Loop(Param), convex_hull.HullError) {
  use hull <- result.try(convex_hull.segment_hull(segment))
  let #(_, hull_pieces) = hull
  let pieces =
    hull_pieces
    |> list.index_map(fn(piece, index) { Piece(index:, hull_piece: piece) })

  Ok(abstract_union.Loop(
    name:,
    support: fn(angle) { support(segment, pieces, angle) },
    point: fn(param) { point_at(segment, param) },
    piece_segments: fn(from, to) { piece_segments(segment, pieces, from, to) },
    param_label: param_label,
  ))
}

fn support(
  segment: svg_path.Segment,
  pieces: List(Piece),
  angle: Float,
) -> abstract_union.Support(Param) {
  let direction = abstract_union.direction(angle)
  let assert [first, ..rest] = pieces
  let first_support = piece_support(segment, first, direction)

  rest
  |> list.fold(first_support, fn(best, piece) {
    let candidate = piece_support(segment, piece, direction)
    case candidate.value >. best.value {
      True -> candidate
      False -> best
    }
  })
}

fn piece_support(
  segment: svg_path.Segment,
  piece: Piece,
  direction: svg_path.Point,
) -> abstract_union.Support(Param) {
  case piece.hull_piece {
    convex_hull.HullLine(a, b) -> {
      let point_a = segment_point(segment, a)
      let point_b = segment_point(segment, b)
      let value_a = abstract_union.dot(point_a, direction)
      let value_b = abstract_union.dot(point_b, direction)
      case value_a >=. value_b {
        True ->
          abstract_union.Support(
            param: Param(piece.index, a),
            point: point_a,
            value: value_a,
          )
        False ->
          abstract_union.Support(
            param: Param(piece.index, b),
            point: point_b,
            value: value_b,
          )
      }
    }
    convex_hull.HullCurve(a, b) -> {
      int.range(
        from: 0,
        to: curve_support_samples,
        with: [],
        run: fn(samples, i) {
          let fraction = int.to_float(i) /. int.to_float(curve_support_samples)
          let t = a +. fraction *. { b -. a }
          let point = segment_point(segment, t)
          let value = abstract_union.dot(point, direction)
          [
            abstract_union.Support(param: Param(piece.index, t), point:, value:),
            ..samples
          ]
        },
      )
      |> best_support
    }
  }
}

fn best_support(
  samples: List(abstract_union.Support(Param)),
) -> abstract_union.Support(Param) {
  let assert [first, ..rest] = samples
  list.fold(rest, first, fn(best, sample) {
    case sample.value >. best.value {
      True -> sample
      False -> best
    }
  })
}

fn point_at(segment: svg_path.Segment, param: Param) -> svg_path.Point {
  segment_point(segment, param.t)
}

fn segment_point(segment: svg_path.Segment, t: Float) -> svg_path.Point {
  let assert Ok(point) = svg_path.segment_point(segment, at: t)
  point
}

fn piece_segments(
  segment: svg_path.Segment,
  pieces: List(Piece),
  from: Param,
  to: Param,
) -> List(svg_path.Segment) {
  case from.piece_index == to.piece_index {
    True -> [
      partial_piece_segment(
        segment,
        piece_at(pieces, from.piece_index),
        from.t,
        to.t,
      ),
    ]
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
          True, _ ->
            partial_piece_segment(segment, piece, from.t, piece_to(piece))
          _, True ->
            partial_piece_segment(segment, piece, piece_from(piece), to.t)
          _, _ ->
            partial_piece_segment(
              segment,
              piece,
              piece_from(piece),
              piece_to(piece),
            )
        }
      })
  }
}

fn partial_piece_segment(
  segment: svg_path.Segment,
  piece: Piece,
  from: Float,
  to: Float,
) -> svg_path.Segment {
  case piece.hull_piece {
    convex_hull.HullLine(_, _) ->
      svg_path.line(
        start: segment_point(segment, from),
        end: segment_point(segment, to),
      )
    convex_hull.HullCurve(_, _) -> {
      let assert Ok(sub_segment) =
        svg_path.sub_segment(segment, from: from, to: to)
      sub_segment
    }
  }
}

fn piece_from(piece: Piece) -> Float {
  case piece.hull_piece {
    convex_hull.HullLine(from, _) | convex_hull.HullCurve(from, _) -> from
  }
}

fn piece_to(piece: Piece) -> Float {
  case piece.hull_piece {
    convex_hull.HullLine(_, to) | convex_hull.HullCurve(_, to) -> to
  }
}

fn piece_at(pieces: List(Piece), index: Int) -> Piece {
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

fn param_label(param: Param) -> String {
  "p" <> int.to_string(param.piece_index) <> "@t=" <> float.to_string(param.t)
}

fn nth(items: List(a), index: Int) -> Result(a, Nil) {
  case items, index {
    [], _ -> Error(Nil)
    [item, ..], 0 -> Ok(item)
    [_, ..rest], _ -> nth(rest, index - 1)
  }
}
