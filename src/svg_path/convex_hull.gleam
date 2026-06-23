//// Convex hull helpers for paths, subpaths, and segments.
////
//// This module computes closed hulls. Single-segment hulls can also report
//// the pieces used to build them. Lines, quadratic Beziers, and arcs have
//// semantic hulls: the primitive itself plus the chord joining its endpoints,
//// with tiny/point-like cases collapsed to lines. Cubic Beziers use a
//// cubic-specific support/event solver.

import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam_community/maths
import svg_path
import svg_path/convex_hull/loop_union

const cubic_sample_count = 3600

const loop_union_sample_count = 720

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

pub type HullPiece {
  /// A portion of the original segment, from one segment parameter to another.
  HullCurve(Float, Float)

  /// A straight line between two points on the original segment.
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
) -> Result(#(svg_path.Subpath, List(HullPiece)), HullError) {
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
  use hull <- result.try(segment_hull(segment))
  let #(subpath, _) = hull
  Ok(svg_path.segments(subpath))
}

fn line_hull(
  segment: svg_path.Segment,
) -> Result(#(svg_path.Subpath, List(HullPiece)), HullError) {
  case segment_is_point_like(segment) {
    True -> build_hull(segment, [HullLine(0.0, 0.0), HullLine(0.0, 0.0)])
    False -> build_hull(segment, [HullLine(0.0, 1.0), HullLine(1.0, 0.0)])
  }
}

fn simple_curve_hull(
  segment: svg_path.Segment,
) -> Result(#(svg_path.Subpath, List(HullPiece)), HullError) {
  case segment_is_point_like(segment) {
    True -> build_hull(segment, [HullLine(0.0, 0.0), HullLine(0.0, 0.0)])
    False -> build_hull(segment, [HullCurve(0.0, 1.0), HullLine(1.0, 0.0)])
  }
}

fn cubic_hull(
  segment: svg_path.Segment,
) -> Result(#(svg_path.Subpath, List(HullPiece)), HullError) {
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
) -> Result(#(svg_path.Subpath, List(HullPiece)), HullError) {
  use segments <- result.try(pieces_to_segments(segment, pieces))
  use closed <- result.try(build_closed_subpath(segments))

  Ok(#(closed, pieces))
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
  loop_union.segments(left, right, sample_count: loop_union_sample_count)
  |> Ok
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
