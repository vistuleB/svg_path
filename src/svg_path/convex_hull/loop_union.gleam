//// Internal support-sampled union of two convex loops.

import gleam/float
import gleam/int
import gleam/list
import gleam_community/maths
import svg_path

const tie_tolerance = 0.0000001

const point_tolerance = 0.000001

const bisection_steps = 32

const same_t = 0.000001

type Support {
  Support(param: Param, point: svg_path.Point, value: Float)
}

type Param {
  Param(segment_index: Int, t: Float)
}

type Loop {
  Loop(segments: List(svg_path.Segment))
}

type Piece {
  HullLineAB(Param, Param)
  HullLineBA(Param, Param)
  LoopPieceA(Param, Param)
  LoopPieceB(Param, Param)
}

type Winner {
  A
  B
}

type Sample {
  Sample(
    angle: Float,
    winner: Winner,
    a: Support,
    b: Support,
    difference: Float,
  )
}

type Boundary {
  Boundary(angle: Float, a: Support, b: Support, from: Winner, to: Winner)
}

pub fn segments(
  left: List(svg_path.Segment),
  right: List(svg_path.Segment),
  sample_count sample_count: Int,
) -> List(svg_path.Segment) {
  let loop_a = Loop(left)
  let loop_b = Loop(right)
  union(loop_a, loop_b, sample_count:)
  |> piece_segments(loop_a, loop_b)
}

fn union(
  loop_a: Loop,
  loop_b: Loop,
  sample_count sample_count: Int,
) -> List(Piece) {
  let samples = initial_samples(loop_a, loop_b, sample_count)
  let boundaries = transition_boundaries(loop_a, loop_b, samples)

  case boundaries {
    [] -> all_one_loop(samples)
    _ ->
      pieces_from_boundaries(boundaries)
      |> compact(loop_a, loop_b)
  }
}

fn piece_segments(
  pieces: List(Piece),
  loop_a: Loop,
  loop_b: Loop,
) -> List(svg_path.Segment) {
  pieces
  |> list.flat_map(fn(piece) {
    case piece {
      LoopPieceA(from, to) -> loop_piece_segments(loop_a, from, to)
      LoopPieceB(from, to) -> loop_piece_segments(loop_b, from, to)
      HullLineAB(a, b) -> [
        svg_path.line(start: point(loop_a, a), end: point(loop_b, b)),
      ]
      HullLineBA(b, a) -> [
        svg_path.line(start: point(loop_b, b), end: point(loop_a, a)),
      ]
    }
  })
}

fn initial_samples(
  loop_a: Loop,
  loop_b: Loop,
  sample_count: Int,
) -> List(Sample) {
  int.range(from: 0, to: sample_count - 1, with: [], run: fn(samples, i) {
    let angle = int.to_float(i) *. 360.0 /. int.to_float(sample_count)
    [sample(loop_a, loop_b, angle), ..samples]
  })
  |> list.reverse
}

fn sample(loop_a: Loop, loop_b: Loop, angle: Float) -> Sample {
  let a = support(loop_a, angle)
  let b = support(loop_b, angle)
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
  loop_a: Loop,
  loop_b: Loop,
  samples: List(Sample),
) -> List(Boundary) {
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
  loop_a: Loop,
  loop_b: Loop,
  left_angle: Float,
  right_angle: Float,
  left_winner: Winner,
) -> Boundary {
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
  loop_a: Loop,
  loop_b: Loop,
  left: Sample,
  right: Sample,
  remaining: Int,
) -> Sample {
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

fn pieces_from_boundaries(boundaries: List(Boundary)) -> List(Piece) {
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

fn compact(pieces: List(Piece), loop_a: Loop, loop_b: Loop) -> List(Piece) {
  pieces
  |> list.filter(fn(piece) {
    case piece {
      LoopPieceA(from, to) -> points_far(point(loop_a, from), point(loop_a, to))
      LoopPieceB(from, to) -> points_far(point(loop_b, from), point(loop_b, to))
      HullLineAB(a, b) -> points_far(point(loop_a, a), point(loop_b, b))
      HullLineBA(b, a) -> points_far(point(loop_b, b), point(loop_a, a))
    }
  })
}

fn points_far(a: svg_path.Point, b: svg_path.Point) -> Bool {
  let dx = a.x -. b.x
  let dy = a.y -. b.y
  dx *. dx +. dy *. dy >. point_tolerance *. point_tolerance
}

fn all_one_loop(samples: List(Sample)) -> List(Piece) {
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

fn support(loop: Loop, angle: Float) -> Support {
  let Loop(segments:) = loop
  let assert [first, ..rest] = segments
  let first_support = segment_support(first, 0, angle)
  rest
  |> list.index_fold(first_support, fn(best, segment, index) {
    let candidate = segment_support(segment, index + 1, angle)
    case candidate.value >. best.value {
      True -> candidate
      False -> best
    }
  })
}

fn segment_support(
  segment: svg_path.Segment,
  index: Int,
  angle: Float,
) -> Support {
  let direction = direction(angle)
  let assert Ok(t) =
    svg_path.segment_minimize(segment, measure: fn(point) {
      0.0 -. dot(point, direction)
    })
  let assert Ok(point) = svg_path.segment_point(segment, at: t)
  Support(
    param: Param(segment_index: index, t: t),
    point:,
    value: dot(point, direction),
  )
}

fn point(loop: Loop, param: Param) -> svg_path.Point {
  let Loop(segments:) = loop
  let Param(segment_index:, t:) = param
  let assert Ok(segment) = nth(segments, segment_index)
  let assert Ok(point) = svg_path.segment_point(segment, at: t)
  point
}

fn loop_piece_segments(
  loop: Loop,
  from: Param,
  to: Param,
) -> List(svg_path.Segment) {
  let Loop(segments:) = loop
  let Param(segment_index: from_index, t: from_t) = from
  let Param(segment_index: to_index, t: to_t) = to
  case
    from_index == to_index && float.absolute_value(from_t -. to_t) <=. same_t
  {
    True -> segments
    False ->
      case from_index == to_index {
        True ->
          case from_t <=. to_t {
            True -> [
              partial_segment(segment_at(segments, from_index), from_t, to_t),
            ]
            False ->
              wrapped_same_segment_piece(segments, from_index, from_t, to_t)
          }
        False ->
          walk_segment_indices(from_index, to_index, list.length(segments), [])
          |> list.reverse
          |> list.map(fn(index) {
            let segment = segment_at(segments, index)
            case index == from_index, index == to_index {
              True, _ -> partial_segment(segment, from_t, 1.0)
              _, True -> partial_segment(segment, 0.0, to_t)
              _, _ -> partial_segment(segment, 0.0, 1.0)
            }
          })
      }
  }
}

fn wrapped_same_segment_piece(
  segments: List(svg_path.Segment),
  index: Int,
  from: Float,
  to: Float,
) -> List(svg_path.Segment) {
  let count = list.length(segments)
  let middle =
    walk_segment_indices(next_index(index, count), index, count, [])
    |> list.reverse
    |> drop_last
    |> list.map(fn(index) {
      partial_segment(segment_at(segments, index), 0.0, 1.0)
    })

  list.append(
    [partial_segment(segment_at(segments, index), from, 1.0)],
    list.append(middle, [
      partial_segment(segment_at(segments, index), 0.0, to),
    ]),
  )
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

fn circular_pairs(items: List(t)) -> List(#(t, t)) {
  case items {
    [] | [_] -> []
    [first, ..] -> circular_pairs_loop(items, first, [])
  }
}

fn circular_pairs_loop(
  items: List(t),
  first: t,
  pairs: List(#(t, t)),
) -> List(#(t, t)) {
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

fn normalize_angle(angle: Float) -> Float {
  let turns = float.floor(angle /. 360.0)
  let normalized = angle -. turns *. 360.0
  case normalized <. 0.0 {
    True -> normalized +. 360.0
    False -> normalized
  }
}

fn direction(angle: Float) -> svg_path.Point {
  let radians = angle *. maths.pi() /. 180.0
  svg_path.point(maths.cos(radians), maths.sin(radians))
}

fn dot(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.x +. a.y *. b.y
}

fn drop_last(items: List(a)) -> List(a) {
  case items {
    [] -> []
    [_] -> []
    [first, ..rest] -> [first, ..drop_last(rest)]
  }
}

fn nth(items: List(a), index: Int) -> Result(a, Nil) {
  case items, index {
    [], _ -> Error(Nil)
    [item, ..], 0 -> Ok(item)
    [_, ..rest], _ -> nth(rest, index - 1)
  }
}
