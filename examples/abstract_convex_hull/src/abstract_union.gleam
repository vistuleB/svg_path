//// Experimental abstract convex-loop union.
////
//// The point of this file is not to be production-ready. It is a typed
//// playground for the idea that a convex body can be represented by a loop
//// capable of answering support queries, and that the convex hull of two such
//// bodies can be returned as provenance-rich abstract pieces.

import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam_community/maths
import svg_path

pub const default_sample_count = 720

const tie_tolerance = 0.0000001

const point_tolerance = 0.000001

const bisection_steps = 32

pub type Support(param) {
  Support(param: param, point: svg_path.Point, value: Float)
}

pub type Loop(param) {
  Loop(
    name: String,
    support: fn(Float) -> Support(param),
    point: fn(param) -> svg_path.Point,
    piece_segments: fn(param, param) -> List(svg_path.Segment),
    param_label: fn(param) -> String,
  )
}

pub type UnionPiece(a, b) {
  HullLineAB(a, b)
  HullLineBA(b, a)
  LoopPieceA(a, a)
  LoopPieceB(b, b)
}

type Winner {
  A
  B
}

type Sample(a, b) {
  Sample(
    angle: Float,
    winner: Winner,
    a: Support(a),
    b: Support(b),
    difference: Float,
  )
}

type Boundary(a, b) {
  Boundary(angle: Float, a: Support(a), b: Support(b), from: Winner, to: Winner)
}

pub fn union(
  loop_a: Loop(a),
  loop_b: Loop(b),
  sample_count sample_count: Int,
) -> List(UnionPiece(a, b)) {
  let samples = initial_samples(loop_a, loop_b, sample_count)
  let boundaries = transition_boundaries(loop_a, loop_b, samples)

  case boundaries {
    [] -> all_one_loop(samples)
    _ ->
      pieces_from_boundaries(boundaries)
      |> compact(loop_a, loop_b)
  }
}

pub fn union_segments(
  pieces: List(UnionPiece(a, b)),
  loop_a: Loop(a),
  loop_b: Loop(b),
) -> List(svg_path.Segment) {
  pieces
  |> list.flat_map(fn(piece) {
    case piece {
      LoopPieceA(from, to) -> loop_a.piece_segments(from, to)
      LoopPieceB(from, to) -> loop_b.piece_segments(from, to)
      HullLineAB(a, b) -> [
        svg_path.Line(start: loop_a.point(a), end: loop_b.point(b)),
      ]
      HullLineBA(b, a) -> [
        svg_path.Line(start: loop_b.point(b), end: loop_a.point(a)),
      ]
    }
  })
}

pub fn union_subpath(
  pieces: List(UnionPiece(a, b)),
  loop_a: Loop(a),
  loop_b: Loop(b),
) -> Result(svg_path.Subpath, svg_path.Error) {
  use subpath <- result.try(
    union_segments(pieces, loop_a, loop_b)
    |> svg_path.subpath_with(policy: svg_path.Wiggle),
  )
  svg_path.subpath_set_closed_with(
    subpath,
    closed: True,
    policy: svg_path.Wiggle,
  )
}

fn initial_samples(
  loop_a: Loop(a),
  loop_b: Loop(b),
  sample_count: Int,
) -> List(Sample(a, b)) {
  int.range(from: 0, to: sample_count - 1, with: [], run: fn(samples, i) {
    let angle = int.to_float(i) *. 360.0 /. int.to_float(sample_count)
    [sample(loop_a, loop_b, angle), ..samples]
  })
  |> list.reverse
}

fn sample(loop_a: Loop(a), loop_b: Loop(b), angle: Float) -> Sample(a, b) {
  let a = loop_a.support(angle)
  let b = loop_b.support(angle)
  let difference = a.value -. b.value
  Sample(angle:, winner: winner(difference), a:, b:, difference:)
}

fn winner(difference: Float) -> Winner {
  case difference >=. 0.0 {
    True -> A
    False -> B
  }
}

fn transition_boundaries(
  loop_a: Loop(a),
  loop_b: Loop(b),
  samples: List(Sample(a, b)),
) -> List(Boundary(a, b)) {
  circular_pairs(samples)
  |> list.filter_map(fn(pair) {
    let #(left, right) = pair
    case left.winner == right.winner {
      True -> Error(Nil)
      False ->
        Ok(refine_boundary(loop_a, loop_b, left.angle, right.angle, left.winner))
    }
  })
}

fn refine_boundary(
  loop_a: Loop(a),
  loop_b: Loop(b),
  left_angle: Float,
  right_angle: Float,
  left_winner: Winner,
) -> Boundary(a, b) {
  let right_angle = unwrap_angle_after(left_angle, right_angle)
  let left = sample(loop_a, loop_b, left_angle)
  let right = sample(loop_a, loop_b, right_angle)
  let refined = bisect_boundary(loop_a, loop_b, left, right, bisection_steps)
  let angle = normalize_angle(refined.angle)
  let at_boundary = sample(loop_a, loop_b, angle)
  let to = case left_winner {
    A -> B
    B -> A
  }

  Boundary(angle:, a: at_boundary.a, b: at_boundary.b, from: left_winner, to:)
}

fn bisect_boundary(
  loop_a: Loop(a),
  loop_b: Loop(b),
  left: Sample(a, b),
  right: Sample(a, b),
  remaining: Int,
) -> Sample(a, b) {
  case
    remaining <= 0 || float.absolute_value(left.difference) <=. tie_tolerance
  {
    True -> left
    False -> {
      let middle_angle = { left.angle +. right.angle } /. 2.0
      let middle = sample(loop_a, loop_b, middle_angle)
      case middle.winner == left.winner {
        True -> bisect_boundary(loop_a, loop_b, middle, right, remaining - 1)
        False -> bisect_boundary(loop_a, loop_b, left, middle, remaining - 1)
      }
    }
  }
}

fn pieces_from_boundaries(
  boundaries: List(Boundary(a, b)),
) -> List(UnionPiece(a, b)) {
  boundaries
  |> circular_pairs
  |> list.map(fn(boundary_pair) {
    let #(start_boundary, end_boundary) = boundary_pair
    let loop_piece = case start_boundary.to {
      A -> LoopPieceA(start_boundary.a.param, end_boundary.a.param)
      B -> LoopPieceB(start_boundary.b.param, end_boundary.b.param)
    }
    let line_piece = case end_boundary.from, end_boundary.to {
      A, B -> HullLineAB(end_boundary.a.param, end_boundary.b.param)
      B, A -> HullLineBA(end_boundary.b.param, end_boundary.a.param)
      _, _ -> loop_piece
    }
    [loop_piece, line_piece]
  })
  |> list.flatten
}

fn compact(
  pieces: List(UnionPiece(a, b)),
  loop_a: Loop(a),
  loop_b: Loop(b),
) -> List(UnionPiece(a, b)) {
  pieces
  |> list.filter(fn(piece) {
    case piece {
      LoopPieceA(from, to) -> points_far(loop_a.point(from), loop_a.point(to))
      LoopPieceB(from, to) -> points_far(loop_b.point(from), loop_b.point(to))
      HullLineAB(a, b) -> points_far(loop_a.point(a), loop_b.point(b))
      HullLineBA(b, a) -> points_far(loop_b.point(b), loop_a.point(a))
    }
  })
}

fn points_far(a: svg_path.Point, b: svg_path.Point) -> Bool {
  let dx = a.x -. b.x
  let dy = a.y -. b.y
  dx *. dx +. dy *. dy >. point_tolerance *. point_tolerance
}

fn all_one_loop(samples: List(Sample(a, b))) -> List(UnionPiece(a, b)) {
  case samples {
    [] -> []
    [first, ..] -> {
      case first.winner {
        A -> [LoopPieceA(first.a.param, first.a.param)]
        B -> [LoopPieceB(first.b.param, first.b.param)]
      }
    }
  }
}

fn circular_pairs(items: List(t)) -> List(#(t, t)) {
  case items {
    [] | [_] -> []
    [first, ..] -> circular_pairs_loop(items, first, [])
  }
}

fn circular_pairs_loop(items: List(t), first: t, pairs: List(#(t, t))) {
  case items {
    [] -> pairs |> list.reverse
    [last] -> [#(last, first), ..pairs] |> list.reverse
    [left, right, ..rest] ->
      circular_pairs_loop([right, ..rest], first, [#(left, right), ..pairs])
  }
}

fn unwrap_angle_after(left: Float, right: Float) -> Float {
  case right <=. left {
    True -> right +. 360.0
    False -> right
  }
}

pub fn normalize_angle(angle: Float) -> Float {
  let turns = float.floor(angle /. 360.0)
  let normalized = angle -. turns *. 360.0
  case normalized <. 0.0 {
    True -> normalized +. 360.0
    False -> normalized
  }
}

pub fn direction(angle: Float) -> svg_path.Point {
  let radians = angle *. 3.141592653589793 /. 180.0
  svg_path.Point(maths.cos(radians), maths.sin(radians))
}

pub fn dot(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.x +. a.y *. b.y
}
