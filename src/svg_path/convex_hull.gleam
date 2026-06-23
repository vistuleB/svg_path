//// Convex hull helpers for paths, subpaths, and segments.
////
//// This module computes closed hulls. Lines, quadratic Beziers, and arcs have
//// semantic hulls: the primitive itself plus the chord joining its endpoints,
//// with tiny/point-like cases collapsed to lines. Cubic Beziers use a
//// cubic-specific support/event solver.

import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam_community/maths
import svg_path

const cubic_sample_count = 3600

const loop_union_sample_count = 720

const loop_union_tie_tolerance = 0.0000001

const loop_union_point_tolerance = 0.000001

const loop_union_bisection_steps = 32

const same_t = 0.000001

const t_close = 0.08

const point_tolerance = 0.000000001

type SupportSample {
  SupportSample(angle: Float, t: Float, value: Float)
}

type Run {
  Run(ts: List(Float))
}

type RunEndpoint {
  PointEndpoint(t: Float)
  CurveEndpoint(from: Float, to: Float)
}

type LoopSupport {
  LoopSupport(param: LoopParam, point: svg_path.Point, value: Float)
}

type LoopParam {
  LoopParam(segment_index: Int, t: Float)
}

type Loop {
  Loop(segments: List(svg_path.Segment))
}

type UnionPiece {
  HullLineAB(LoopParam, LoopParam)
  HullLineBA(LoopParam, LoopParam)
  LoopPieceA(LoopParam, LoopParam)
  LoopPieceB(LoopParam, LoopParam)
}

type LoopWinner {
  LoopA
  LoopB
}

type LoopSample {
  LoopSample(
    angle: Float,
    winner: LoopWinner,
    a: LoopSupport,
    b: LoopSupport,
    difference: Float,
  )
}

type LoopBoundary {
  LoopBoundary(
    angle: Float,
    a: LoopSupport,
    b: LoopSupport,
    from: LoopWinner,
    to: LoopWinner,
  )
}

type HullPiece {
  HullCurve(Float, Float)
  HullLine(Float, Float)
}

pub type HullError {
  /// The generated hull segments could not be converted into a valid closed
  /// `Subpath`.
  PathError(svg_path.Error)

  /// The final hull-piece sequence failed the invariant that curve pieces must
  /// be separated by line pieces.
  ConsecutiveCurves

  /// The refined support samples still contained adjacent duplicate segment
  /// parameters.
  DuplicateAdjacentTValues

  /// Support-sample refinement did not settle before the iteration limit.
  RefinementReachedMaxIterations(Int)

  /// Support-sample simplification did not settle before the iteration limit.
  PurificationReachedMaxIterations(Int)

  /// Convex-loop union collapsed to no boundary pieces.
  LoopUnionCollapsed
}

/// Compute the convex hull of all segments in a subpath.
///
/// The result is a closed subpath. Each individual segment is first converted
/// to its own convex hull, then those convex loops are unioned one at a time.
pub fn subpath_hull(
  subpath: svg_path.Subpath,
) -> Result(svg_path.Subpath, HullError) {
  case svg_path.segments(subpath) {
    [] -> Error(PathError(svg_path.EmptySubpath))
    segments -> segments_hull(segments)
  }
}

/// Compute the convex hull of all segments in a path.
///
/// Empty subpaths are ignored. The result is a single closed subpath containing
/// the hull of every non-empty subpath in the input path.
pub fn path_hull(path: svg_path.Path) -> Result(svg_path.Subpath, HullError) {
  case svg_path.subpaths(path) {
    [] -> Error(PathError(svg_path.EmptyPath))
    subpaths -> {
      case subpaths |> list.flat_map(svg_path.segments) {
        [] -> Error(PathError(svg_path.EmptySubpaths))
        segments -> segments_hull(segments)
      }
    }
  }
}

pub fn segment_hull(
  segment: svg_path.Segment,
) -> Result(svg_path.Subpath, HullError) {
  case segment {
    svg_path.Line(..) -> line_hull(segment)
    svg_path.QuadraticBezier(..) | svg_path.Arc(..) ->
      simple_curve_hull(segment)
    svg_path.CubicBezier(..) -> cubic_hull(segment)
  }
}

fn segments_hull(
  segments: List(svg_path.Segment),
) -> Result(svg_path.Subpath, HullError) {
  let assert [first, ..rest] = segments
  use initial <- result.try(segment_hull_segments(first))
  use segments <- result.try(
    rest
    |> list.fold(Ok(initial), fn(hull, segment) {
      use hull <- result.try(hull)
      use next <- result.try(segment_hull_segments(segment))
      union_loop_segments(hull, next)
    }),
  )
  build_closed_subpath(segments)
}

fn segment_hull_segments(
  segment: svg_path.Segment,
) -> Result(List(svg_path.Segment), HullError) {
  use subpath <- result.try(segment_hull(segment))
  Ok(svg_path.segments(subpath))
}

fn line_hull(segment: svg_path.Segment) -> Result(svg_path.Subpath, HullError) {
  case segment_is_point_like(segment) {
    True -> build_hull(segment, [HullLine(0.0, 0.0), HullLine(0.0, 0.0)])
    False -> build_hull(segment, [HullLine(0.0, 1.0), HullLine(1.0, 0.0)])
  }
}

fn simple_curve_hull(
  segment: svg_path.Segment,
) -> Result(svg_path.Subpath, HullError) {
  case segment_is_point_like(segment) {
    True -> build_hull(segment, [HullLine(0.0, 0.0), HullLine(0.0, 0.0)])
    False -> build_hull(segment, [HullCurve(0.0, 1.0), HullLine(1.0, 0.0)])
  }
}

fn cubic_hull(
  segment: svg_path.Segment,
) -> Result(svg_path.Subpath, HullError) {
  case segment_is_point_like(segment) {
    True -> build_hull(segment, [HullLine(0.0, 0.0), HullLine(0.0, 0.0)])
    False -> {
      let pieces =
        raw_samples(segment, cubic_sample_count)
        |> collapse_runs
        |> pieces_from_runs
        |> refine_pieces(segment)

      use pieces <- result.try(reject_consecutive_curves(pieces))
      build_hull(segment, pieces)
    }
  }
}

fn build_hull(
  segment: svg_path.Segment,
  pieces: List(HullPiece),
) -> Result(svg_path.Subpath, HullError) {
  use segments <- result.try(pieces_to_segments(segment, pieces))
  build_closed_subpath(segments)
}

fn build_closed_subpath(
  segments: List(svg_path.Segment),
) -> Result(svg_path.Subpath, HullError) {
  use subpath <- result.try(
    svg_path.subpath_with(segments, policy: svg_path.WiggleThenBridge)
    |> map_path_error,
  )
  svg_path.set_closed_with(
    subpath,
    closed: True,
    policy: svg_path.WiggleThenBridge,
  )
  |> map_path_error
}

fn union_loop_segments(
  left: List(svg_path.Segment),
  right: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), HullError) {
  let loop_a = Loop(left)
  let loop_b = Loop(right)
  let pieces = loop_union(loop_a, loop_b, sample_count: loop_union_sample_count)
  case union_piece_segments(pieces, loop_a, loop_b) {
    [] -> dominant_loop_segments(loop_a, loop_b)
    segments -> Ok(segments)
  }
}

fn dominant_loop_segments(
  loop_a: Loop,
  loop_b: Loop,
) -> Result(List(svg_path.Segment), HullError) {
  case loop_support_dominance(loop_a, loop_b, loop_union_sample_count) {
    LoopADominates -> {
      let Loop(segments:) = loop_a
      Ok(segments)
    }
    LoopBDominates -> {
      let Loop(segments:) = loop_b
      Ok(segments)
    }
    NoLoopDominates -> Error(LoopUnionCollapsed)
  }
}

type LoopDominance {
  LoopADominates
  LoopBDominates
  NoLoopDominates
}

fn loop_support_dominance(
  loop_a: Loop,
  loop_b: Loop,
  sample_count: Int,
) -> LoopDominance {
  let initial = #(True, True)
  let #(a_contains_b, b_contains_a) =
    int.range(from: 0, to: sample_count - 1, with: initial, run: fn(state, i) {
      let #(a_contains_b, b_contains_a) = state
      let angle = int.to_float(i) *. 360.0 /. int.to_float(sample_count)
      let sample = loop_sample(loop_a, loop_b, angle)
      #(
        a_contains_b && sample.difference >=. 0.0 -. loop_union_tie_tolerance,
        b_contains_a && sample.difference <=. loop_union_tie_tolerance,
      )
    })

  case a_contains_b, b_contains_a {
    True, _ -> LoopADominates
    False, True -> LoopBDominates
    False, False -> NoLoopDominates
  }
}

fn loop_union(
  loop_a: Loop,
  loop_b: Loop,
  sample_count sample_count: Int,
) -> List(UnionPiece) {
  let samples = loop_initial_samples(loop_a, loop_b, sample_count)
  let boundaries = loop_transition_boundaries(loop_a, loop_b, samples)

  case boundaries {
    [] -> all_one_loop(samples)
    _ ->
      loop_pieces_from_boundaries(boundaries)
      |> compact_loop_pieces(loop_a, loop_b)
  }
}

fn union_piece_segments(
  pieces: List(UnionPiece),
  loop_a: Loop,
  loop_b: Loop,
) -> List(svg_path.Segment) {
  pieces
  |> list.flat_map(fn(piece) {
    case piece {
      LoopPieceA(from, to) -> loop_piece_segments(loop_a, from, to)
      LoopPieceB(from, to) -> loop_piece_segments(loop_b, from, to)
      HullLineAB(a, b) -> [
        svg_path.line(start: loop_point(loop_a, a), end: loop_point(loop_b, b)),
      ]
      HullLineBA(b, a) -> [
        svg_path.line(start: loop_point(loop_b, b), end: loop_point(loop_a, a)),
      ]
    }
  })
}

fn loop_initial_samples(
  loop_a: Loop,
  loop_b: Loop,
  sample_count: Int,
) -> List(LoopSample) {
  int.range(from: 0, to: sample_count - 1, with: [], run: fn(samples, i) {
    let angle = int.to_float(i) *. 360.0 /. int.to_float(sample_count)
    [loop_sample(loop_a, loop_b, angle), ..samples]
  })
  |> list.reverse
}

fn loop_sample(loop_a: Loop, loop_b: Loop, angle: Float) -> LoopSample {
  let a = loop_support(loop_a, angle)
  let b = loop_support(loop_b, angle)
  let difference = a.value -. b.value
  LoopSample(angle:, winner: loop_winner(difference), a:, b:, difference:)
}

fn loop_winner(difference: Float) -> LoopWinner {
  case difference >=. 0.0 {
    True -> LoopA
    False -> LoopB
  }
}

fn loop_transition_boundaries(
  loop_a: Loop,
  loop_b: Loop,
  samples: List(LoopSample),
) -> List(LoopBoundary) {
  circular_pairs(samples)
  |> list.filter_map(fn(pair) {
    let #(left, right) = pair
    case left.winner == right.winner {
      True -> Error(Nil)
      False ->
        Ok(loop_refine_boundary(
          loop_a,
          loop_b,
          left.angle,
          right.angle,
          left.winner,
        ))
    }
  })
}

fn loop_refine_boundary(
  loop_a: Loop,
  loop_b: Loop,
  left_angle: Float,
  right_angle: Float,
  left_winner: LoopWinner,
) -> LoopBoundary {
  let right_angle = unwrap_angle_after(left_angle, right_angle)
  let left = loop_sample(loop_a, loop_b, left_angle)
  let right = loop_sample(loop_a, loop_b, right_angle)
  let refined =
    loop_bisect_boundary(
      loop_a,
      loop_b,
      left,
      right,
      loop_union_bisection_steps,
    )
  let angle = normalize_angle(refined.angle)
  let at_boundary = loop_sample(loop_a, loop_b, angle)
  let to = case left_winner {
    LoopA -> LoopB
    LoopB -> LoopA
  }

  LoopBoundary(
    angle:,
    a: at_boundary.a,
    b: at_boundary.b,
    from: left_winner,
    to:,
  )
}

fn loop_bisect_boundary(
  loop_a: Loop,
  loop_b: Loop,
  left: LoopSample,
  right: LoopSample,
  remaining: Int,
) -> LoopSample {
  case
    remaining <= 0
    || float.absolute_value(left.difference) <=. loop_union_tie_tolerance
  {
    True -> left
    False -> {
      let middle_angle = { left.angle +. right.angle } /. 2.0
      let middle = loop_sample(loop_a, loop_b, middle_angle)
      case middle.winner == left.winner {
        True ->
          loop_bisect_boundary(loop_a, loop_b, middle, right, remaining - 1)
        False ->
          loop_bisect_boundary(loop_a, loop_b, left, middle, remaining - 1)
      }
    }
  }
}

fn loop_pieces_from_boundaries(
  boundaries: List(LoopBoundary),
) -> List(UnionPiece) {
  boundaries
  |> circular_pairs
  |> list.map(fn(boundary_pair) {
    let #(start_boundary, end_boundary) = boundary_pair
    let loop_piece = case start_boundary.to {
      LoopA -> LoopPieceA(start_boundary.a.param, end_boundary.a.param)
      LoopB -> LoopPieceB(start_boundary.b.param, end_boundary.b.param)
    }
    let line_piece = case end_boundary.from, end_boundary.to {
      LoopA, LoopB -> HullLineAB(end_boundary.a.param, end_boundary.b.param)
      LoopB, LoopA -> HullLineBA(end_boundary.b.param, end_boundary.a.param)
      _, _ -> loop_piece
    }
    [loop_piece, line_piece]
  })
  |> list.flatten
}

fn compact_loop_pieces(
  pieces: List(UnionPiece),
  loop_a: Loop,
  loop_b: Loop,
) -> List(UnionPiece) {
  pieces
  |> list.filter(fn(piece) {
    case piece {
      LoopPieceA(from, to) ->
        loop_points_far(loop_point(loop_a, from), loop_point(loop_a, to))
      LoopPieceB(from, to) ->
        loop_points_far(loop_point(loop_b, from), loop_point(loop_b, to))
      HullLineAB(a, b) ->
        loop_points_far(loop_point(loop_a, a), loop_point(loop_b, b))
      HullLineBA(b, a) ->
        loop_points_far(loop_point(loop_b, b), loop_point(loop_a, a))
    }
  })
}

fn loop_points_far(a: svg_path.Point, b: svg_path.Point) -> Bool {
  let dx = a.x -. b.x
  let dy = a.y -. b.y
  dx *. dx +. dy *. dy
  >. loop_union_point_tolerance *. loop_union_point_tolerance
}

fn all_one_loop(samples: List(LoopSample)) -> List(UnionPiece) {
  case samples {
    [] -> []
    [first, ..] -> {
      case first.winner {
        LoopA -> [LoopPieceA(first.a.param, first.a.param)]
        LoopB -> [LoopPieceB(first.b.param, first.b.param)]
      }
    }
  }
}

fn loop_support(loop: Loop, angle: Float) -> LoopSupport {
  let Loop(segments:) = loop
  let assert [first, ..rest] = segments
  let first_support = segment_loop_support(first, 0, angle)
  rest
  |> list.index_fold(first_support, fn(best, segment, index) {
    let candidate = segment_loop_support(segment, index + 1, angle)
    case candidate.value >. best.value {
      True -> candidate
      False -> best
    }
  })
}

fn segment_loop_support(
  segment: svg_path.Segment,
  index: Int,
  angle: Float,
) -> LoopSupport {
  let direction = angle_direction(angle)
  case segment {
    svg_path.Line(start:, end:) -> {
      let start_value = dot(start, direction)
      let end_value = dot(end, direction)
      case end_value >. start_value {
        True ->
          LoopSupport(
            param: LoopParam(segment_index: index, t: 1.0),
            point: end,
            value: end_value,
          )
        False ->
          LoopSupport(
            param: LoopParam(segment_index: index, t: 0.0),
            point: start,
            value: start_value,
          )
      }
    }
    _ -> {
      let assert Ok(t) =
        svg_path.segment_minimize(segment, measure: fn(point) {
          0.0 -. dot(point, direction)
        })
      let assert Ok(point) = svg_path.segment_point(segment, at: t)
      LoopSupport(
        param: LoopParam(segment_index: index, t: t),
        point:,
        value: dot(point, direction),
      )
    }
  }
}

fn loop_point(loop: Loop, param: LoopParam) -> svg_path.Point {
  let Loop(segments:) = loop
  let LoopParam(segment_index:, t:) = param
  let assert Ok(segment) = nth(segments, segment_index)
  let assert Ok(point) = svg_path.segment_point(segment, at: t)
  point
}

fn loop_piece_segments(
  loop: Loop,
  from: LoopParam,
  to: LoopParam,
) -> List(svg_path.Segment) {
  let Loop(segments:) = loop
  let LoopParam(segment_index: from_index, t: from_t) = from
  let LoopParam(segment_index: to_index, t: to_t) = to
  case
    from_index == to_index && float.absolute_value(from_t -. to_t) <=. same_t
  {
    True -> segments
    False ->
      case from_index == to_index {
        True ->
          case from_t <=. to_t {
            True -> [
              loop_partial_segment(
                segment_at(segments, from_index),
                from_t,
                to_t,
              ),
            ]
            False ->
              loop_wrapped_same_segment_piece(
                segments,
                from_index,
                from_t,
                to_t,
              )
          }
        False ->
          walk_segment_indices(from_index, to_index, list.length(segments), [])
          |> list.reverse
          |> list.map(fn(index) {
            let segment = segment_at(segments, index)
            case index == from_index, index == to_index {
              True, _ -> loop_partial_segment(segment, from_t, 1.0)
              _, True -> loop_partial_segment(segment, 0.0, to_t)
              _, _ -> loop_partial_segment(segment, 0.0, 1.0)
            }
          })
      }
  }
}

fn loop_wrapped_same_segment_piece(
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
      loop_partial_segment(segment_at(segments, index), 0.0, 1.0)
    })

  list.append(
    [loop_partial_segment(segment_at(segments, index), from, 1.0)],
    list.append(middle, [
      loop_partial_segment(segment_at(segments, index), 0.0, to),
    ]),
  )
}

fn loop_partial_segment(
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

fn segment_is_point_like(segment: svg_path.Segment) -> Bool {
  case svg_path.segment_bounding_box(segment) {
    Error(_) -> True
    Ok(box) -> svg_path.bounding_box_diameter(box) <=. point_tolerance
  }
}

fn raw_samples(
  segment: svg_path.Segment,
  sample_count: Int,
) -> List(SupportSample) {
  int.range(from: 0, to: sample_count - 1, with: [], run: fn(samples, i) {
    let angle = int.to_float(i) *. 360.0 /. int.to_float(sample_count)
    case support(segment, angle: angle) {
      Ok(sample) -> [sample, ..samples]
      Error(_) -> samples
    }
  })
  |> list.reverse
}

fn collapse_runs(samples: List(SupportSample)) -> List(Run) {
  case samples {
    [] -> []
    [first, ..rest] -> {
      let runs =
        collapse_runs_loop(rest, current: Run(ts: [first.t]), runs: [])
        |> list.reverse

      merge_circular_run_boundary(runs)
    }
  }
}

fn collapse_runs_loop(
  samples: List(SupportSample),
  current current: Run,
  runs runs: List(Run),
) -> List(Run) {
  case samples {
    [] -> [reverse_run(current), ..runs]
    [sample, ..rest] -> {
      let assert [previous_t, ..] = current.ts
      case float.absolute_value(sample.t -. previous_t) <=. t_close {
        True ->
          collapse_runs_loop(
            rest,
            current: Run(ts: [sample.t, ..current.ts]),
            runs: runs,
          )
        False ->
          collapse_runs_loop(rest, current: Run(ts: [sample.t]), runs: [
            reverse_run(current),
            ..runs
          ])
      }
    }
  }
}

fn reverse_run(run: Run) -> Run {
  Run(ts: list.reverse(run.ts))
}

fn merge_circular_run_boundary(runs: List(Run)) -> List(Run) {
  case runs {
    [] | [_] -> runs
    [first, ..rest] -> {
      case list.last(rest), first.ts {
        Ok(last), [first_t, ..] -> {
          let assert Ok(last_t) = list.last(last.ts)
          case float.absolute_value(first_t -. last_t) <=. t_close {
            True -> [Run(ts: list.append(last.ts, first.ts)), ..drop_last(rest)]
            False -> runs
          }
        }
        _, _ -> runs
      }
    }
  }
}

fn pieces_from_runs(runs: List(Run)) -> List(HullPiece) {
  let endpoints = list.map(runs, run_endpoint)

  case endpoints {
    [] -> []
    [first, ..rest] ->
      pieces_from_endpoints_loop(endpoints, first, rest, pieces: [])
      |> list.reverse
  }
}

fn pieces_from_endpoints_loop(
  endpoints: List(RunEndpoint),
  first first: RunEndpoint,
  rest rest: List(RunEndpoint),
  pieces pieces: List(HullPiece),
) -> List(HullPiece) {
  case endpoints, rest {
    [], _ -> pieces
    [current, ..], [] -> {
      let pieces = add_endpoint_curve(pieces, current)
      add_line(pieces, end_t(current), start_t(first))
    }
    [current, ..remaining], [next, ..next_rest] -> {
      let pieces = add_endpoint_curve(pieces, current)
      let pieces = add_line(pieces, end_t(current), start_t(next))

      pieces_from_endpoints_loop(
        remaining,
        first: first,
        rest: next_rest,
        pieces: pieces,
      )
    }
  }
}

fn run_endpoint(run: Run) -> RunEndpoint {
  let min = list.fold(run.ts, 1.0 /. 0.0, float.min)
  let max = list.fold(run.ts, -1.0 /. 0.0, float.max)

  case max -. min <. same_t {
    True -> PointEndpoint(average(run.ts))
    False -> {
      let assert [from, ..] = run.ts
      let assert Ok(to) = list.last(run.ts)
      CurveEndpoint(from, to)
    }
  }
}

fn add_endpoint_curve(
  pieces: List(HullPiece),
  endpoint: RunEndpoint,
) -> List(HullPiece) {
  case endpoint {
    PointEndpoint(_) -> pieces
    CurveEndpoint(from, to) ->
      case float.absolute_value(from -. to) <=. same_t {
        True -> pieces
        False -> [HullCurve(from, to), ..pieces]
      }
  }
}

fn add_line(
  pieces: List(HullPiece),
  from: Float,
  to: Float,
) -> List(HullPiece) {
  [HullLine(from, to), ..pieces]
}

fn start_t(endpoint: RunEndpoint) -> Float {
  case endpoint {
    PointEndpoint(t) -> t
    CurveEndpoint(from, _) -> from
  }
}

fn end_t(endpoint: RunEndpoint) -> Float {
  case endpoint {
    PointEndpoint(t) -> t
    CurveEndpoint(_, to) -> to
  }
}

fn refine_pieces(
  pieces: List(HullPiece),
  segment: svg_path.Segment,
) -> List(HullPiece) {
  case pieces {
    [] -> []
    [_] -> pieces
    [first, ..] -> {
      let assert Ok(last) = list.last(pieces)
      let window = list.append([last, ..pieces], [first])
      refine_pieces_loop(
        segment,
        window,
        remaining: list.length(pieces),
        refined: [],
      )
      |> list.reverse
      |> sync_line_endpoints
    }
  }
}

fn refine_pieces_loop(
  segment: svg_path.Segment,
  window: List(HullPiece),
  remaining remaining: Int,
  refined refined: List(HullPiece),
) -> List(HullPiece) {
  case remaining <= 0 {
    True -> refined
    False -> {
      let assert [previous, current, next, ..rest] = window
      let refined_current = case current {
        HullCurve(from, to) -> {
          let from = case previous {
            HullLine(other, _) ->
              refine_chord_tangent(segment, approximate: from, other: other)
            _ -> from
          }
          let to = case next {
            HullLine(_, other) ->
              refine_chord_tangent(segment, approximate: to, other: other)
            _ -> to
          }
          HullCurve(from, to)
        }
        HullLine(from, to) -> {
          let from = case previous {
            HullCurve(_, _) ->
              refine_chord_tangent(segment, approximate: from, other: to)
            _ -> from
          }
          let to = case next {
            HullCurve(_, _) ->
              refine_chord_tangent(segment, approximate: to, other: from)
            _ -> to
          }
          HullLine(from, to)
        }
      }

      refine_pieces_loop(
        segment,
        [current, next, ..rest],
        remaining: remaining - 1,
        refined: [refined_current, ..refined],
      )
    }
  }
}

fn sync_line_endpoints(pieces: List(HullPiece)) -> List(HullPiece) {
  case pieces {
    [] -> []
    [_] -> pieces
    [first, ..] -> {
      let assert Ok(last) = list.last(pieces)
      let window = list.append([last, ..pieces], [first])
      sync_line_endpoints_loop(
        window,
        remaining: list.length(pieces),
        synced: [],
      )
      |> list.reverse
    }
  }
}

fn sync_line_endpoints_loop(
  window: List(HullPiece),
  remaining remaining: Int,
  synced synced: List(HullPiece),
) -> List(HullPiece) {
  case remaining <= 0 {
    True -> synced
    False -> {
      let assert [previous, current, next, ..rest] = window
      let current = case current {
        HullLine(from, to) -> {
          let from = case previous {
            HullCurve(_, curve_to) -> curve_to
            _ -> from
          }
          let to = case next {
            HullCurve(curve_from, _) -> curve_from
            _ -> to
          }
          HullLine(from, to)
        }
        _ -> current
      }
      sync_line_endpoints_loop(
        [current, next, ..rest],
        remaining: remaining - 1,
        synced: [current, ..synced],
      )
    }
  }
}

fn refine_chord_tangent(
  segment: svg_path.Segment,
  approximate approximate: Float,
  other other: Float,
) -> Float {
  case approximate <. same_t || approximate >. 1.0 -. same_t {
    True -> approximate
    False -> {
      let initial = chord_tangent_value(segment, approximate, other)
      case float.absolute_value(initial) <. 0.000000000001 {
        True -> approximate
        False ->
          refine_chord_tangent_scan(
            segment,
            other: other,
            left: float.max(0.0, approximate -. 0.08),
            right: float.min(1.0, approximate +. 0.08),
            steps: 64,
            best: approximate,
            best_value: float.absolute_value(initial),
          )
      }
    }
  }
}

fn refine_chord_tangent_scan(
  segment: svg_path.Segment,
  other other: Float,
  left left: Float,
  right right: Float,
  steps steps: Int,
  best best: Float,
  best_value best_value: Float,
) -> Float {
  let initial_value = chord_tangent_value(segment, left, other)
  int.range(
    from: 1,
    to: steps,
    with: Continue(#(left, initial_value, best, best_value)),
    run: fn(state, i) {
      case state {
        Done(root) -> Done(root)
        Continue(#(previous_t, previous_value, best, best_value)) -> {
          let t =
            left +. { right -. left } *. int.to_float(i) /. int.to_float(steps)
          let value = chord_tangent_value(segment, t, other)
          let #(best, best_value) = case
            float.absolute_value(value) <. best_value
          {
            True -> #(t, float.absolute_value(value))
            False -> #(best, best_value)
          }
          case
            value == 0.0
            || previous_value == 0.0
            || same_sign(value, previous_value) == False
          {
            True ->
              Done(bisect_chord_tangent(
                segment,
                other,
                left: previous_t,
                right: t,
              ))
            False -> Continue(#(t, value, best, best_value))
          }
        }
      }
    },
  )
  |> finish_refinement_scan
}

type RefinementScan {
  Done(Float)
  Continue(#(Float, Float, Float, Float))
}

fn finish_refinement_scan(scan: RefinementScan) -> Float {
  case scan {
    Done(root) -> root
    Continue(#(_, _, best, _)) -> best
  }
}

fn bisect_chord_tangent(
  segment: svg_path.Segment,
  other: Float,
  left left: Float,
  right right: Float,
) -> Float {
  let left_value = chord_tangent_value(segment, left, other)
  bisect_chord_tangent_loop(
    segment,
    left,
    left_value,
    right,
    other,
    remaining: 80,
  )
}

fn bisect_chord_tangent_loop(
  segment: svg_path.Segment,
  left: Float,
  left_value: Float,
  right: Float,
  other: Float,
  remaining remaining: Int,
) -> Float {
  let midpoint = left +. { right -. left } /. 2.0
  let midpoint_value = chord_tangent_value(segment, midpoint, other)
  case
    remaining <= 0
    || float.absolute_value(midpoint_value) <. 0.00000000000001
    || float.absolute_value(right -. left) <. 0.000000000001
  {
    True -> midpoint
    False ->
      case same_sign(left_value, midpoint_value) {
        True ->
          bisect_chord_tangent_loop(
            segment,
            midpoint,
            midpoint_value,
            right,
            other,
            remaining: remaining - 1,
          )
        False ->
          bisect_chord_tangent_loop(
            segment,
            left,
            left_value,
            midpoint,
            other,
            remaining: remaining - 1,
          )
      }
  }
}

fn same_sign(a: Float, b: Float) -> Bool {
  a <. 0.0 && b <. 0.0 || a >. 0.0 && b >. 0.0
}

fn support(
  segment: svg_path.Segment,
  angle angle: Float,
) -> Result(SupportSample, svg_path.Error) {
  let direction = angle_direction(angle)
  case segment {
    svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      let p0 = dot(start, direction)
      let p1 = dot(control1, direction)
      let p2 = dot(control2, direction)
      let p3 = dot(end, direction)
      let a = 0.0 -. p0 +. 3.0 *. p1 -. 3.0 *. p2 +. p3
      let b = 3.0 *. p0 -. 6.0 *. p1 +. 3.0 *. p2
      let c = -3.0 *. p0 +. 3.0 *. p1
      let candidates =
        [0.0, 1.0, ..quadratic_roots(3.0 *. a, 2.0 *. b, c)]
        |> list.filter(fn(t) { t >=. 0.0 && t <=. 1.0 })

      let assert [first, ..rest] = candidates
      let best =
        list.fold(
          rest,
          #(first, cubic_scalar(p0, p1, p2, p3, first)),
          fn(best, t) {
            let value = cubic_scalar(p0, p1, p2, p3, t)
            case value >. best.1 {
              True -> #(t, value)
              False -> best
            }
          },
        )

      Ok(SupportSample(angle: angle, t: best.0, value: best.1))
    }
    _ -> Error(svg_path.DegenerateArc)
  }
}

fn reject_consecutive_curves(
  pieces: List(HullPiece),
) -> Result(List(HullPiece), HullError) {
  case has_consecutive_curves(pieces) {
    True -> Error(ConsecutiveCurves)
    False -> Ok(pieces)
  }
}

fn has_consecutive_curves(pieces: List(HullPiece)) -> Bool {
  case pieces {
    [] -> False
    [first, ..rest] ->
      has_consecutive_curves_loop(first, previous: first, rest: rest)
  }
}

fn has_consecutive_curves_loop(
  first: HullPiece,
  previous previous: HullPiece,
  rest rest: List(HullPiece),
) -> Bool {
  case rest {
    [] -> hull_pieces_are_consecutive_curves(previous, first)
    [current, ..rest] ->
      case hull_pieces_are_consecutive_curves(previous, current) {
        True -> True
        False ->
          has_consecutive_curves_loop(first, previous: current, rest: rest)
      }
  }
}

fn hull_pieces_are_consecutive_curves(
  first: HullPiece,
  second: HullPiece,
) -> Bool {
  case first, second {
    HullCurve(_, _), HullCurve(_, _) -> True
    _, _ -> False
  }
}

fn pieces_to_segments(
  segment: svg_path.Segment,
  pieces: List(HullPiece),
) -> Result(List(svg_path.Segment), HullError) {
  list.fold(pieces, Ok([]), fn(segments, piece) {
    use segments <- result.try(segments)
    use segment <- result.try(piece_to_segment(segment, piece))
    Ok([segment, ..segments])
  })
  |> result.map(list.reverse)
}

fn piece_to_segment(
  segment: svg_path.Segment,
  piece: HullPiece,
) -> Result(svg_path.Segment, HullError) {
  case piece {
    HullCurve(from, to) ->
      svg_path.sub_segment(segment, from: from, to: to)
      |> map_path_error
    HullLine(from, to) -> {
      use start <- result.try(
        svg_path.segment_point(segment, at: from)
        |> map_path_error,
      )
      use end <- result.try(
        svg_path.segment_point(segment, at: to)
        |> map_path_error,
      )
      Ok(svg_path.line(start: start, end: end))
    }
  }
}

fn chord_tangent_value(
  segment: svg_path.Segment,
  t: Float,
  other: Float,
) -> Float {
  let assert Ok(point) = svg_path.segment_point(segment, at: t)
  let assert Ok(other_point) = svg_path.segment_point(segment, at: other)
  cross(cubic_derivative(segment, t), subtract(other_point, point))
}

fn cubic_derivative(segment: svg_path.Segment, t: Float) -> svg_path.Point {
  case segment {
    svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      let mt = 1.0 -. t
      add_points(
        add_points(
          scale_point(subtract(control1, start), 3.0 *. mt *. mt),
          scale_point(subtract(control2, control1), 6.0 *. mt *. t),
        ),
        scale_point(subtract(end, control2), 3.0 *. t *. t),
      )
    }
    _ -> svg_path.point(0.0, 0.0)
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

fn average(values: List(Float)) -> Float {
  list.fold(values, 0.0, fn(total, value) { total +. value })
  /. int.to_float(list.length(values))
}

fn angle_direction(angle: Float) -> svg_path.Point {
  let radians = angle *. maths.pi() /. 180.0
  svg_path.point(maths.cos(radians), maths.sin(radians))
}

fn dot(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.x +. a.y *. b.y
}

fn map_path_error(result: Result(a, svg_path.Error)) -> Result(a, HullError) {
  result.map_error(result, PathError)
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
