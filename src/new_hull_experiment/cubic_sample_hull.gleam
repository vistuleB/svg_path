import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam_community/maths
import svg_path
import svg_path/convex_hull

const same_t = 0.000001

const t_close = 0.08

pub type CandidateError {
  NotCubic
  PathError(svg_path.Error)
}

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

pub fn hull(
  segment: svg_path.Segment,
  sample_count sample_count: Int,
) -> Result(#(svg_path.Subpath, List(convex_hull.HullPiece)), CandidateError) {
  case segment {
    svg_path.CubicBezier(..) -> {
      let pieces =
        raw_samples(segment, sample_count)
        |> collapse_runs
        |> pieces_from_runs
        |> refine_pieces(segment)

      use segments <- result.try(pieces_to_segments(segment, pieces))
      use subpath <- result.try(
        svg_path.subpath_with(segments, policy: svg_path.Wiggle)
        |> result.map_error(PathError),
      )

      use closed <- result.try(
        svg_path.set_closed_with(subpath, closed: True, policy: svg_path.Wiggle)
        |> result.map_error(PathError),
      )

      Ok(#(closed, pieces))
    }
    _ -> Error(NotCubic)
  }
}

pub fn max_support_error(
  segment: svg_path.Segment,
  pieces pieces: List(convex_hull.HullPiece),
  sample_count sample_count: Int,
) -> Result(Float, CandidateError) {
  use worst <- result.try(worst_support_error(segment, pieces: pieces, sample_count: sample_count))
  Ok(worst.1)
}

pub fn worst_support_error(
  segment: svg_path.Segment,
  pieces pieces: List(convex_hull.HullPiece),
  sample_count sample_count: Int,
) -> Result(#(Float, Float, Float, Float), CandidateError) {
  int.range(from: 0, to: sample_count - 1, with: Ok(#(0.0, 0.0, 0.0, 0.0)), run: fn(worst, i) {
    use worst <- result.try(worst)
    let angle = int.to_float(i) *. 360.0 /. int.to_float(sample_count)
    use original <- result.try(support(segment, angle: angle))
    use candidate <- result.try(hull_piece_support(segment, pieces, angle))
    let error = float.absolute_value(original.value -. candidate)
    case error >. worst.1 {
      True -> Ok(#(angle, error, original.value, candidate))
      False -> Ok(worst)
    }
  })
}

pub fn piece_supports(
  segment: svg_path.Segment,
  pieces pieces: List(convex_hull.HullPiece),
  angle angle: Float,
) -> Result(List(#(convex_hull.HullPiece, Float)), CandidateError) {
  list.fold(pieces, Ok([]), fn(values, piece) {
    use values <- result.try(values)
    use value <- result.try(piece_support(segment, piece, angle))
    Ok([#(piece, value), ..values])
  })
  |> result.map(list.reverse)
}

fn raw_samples(segment: svg_path.Segment, sample_count: Int) -> List(SupportSample) {
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
          collapse_runs_loop(
            rest,
            current: Run(ts: [sample.t]),
            runs: [reverse_run(current), ..runs],
          )
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

fn pieces_from_runs(runs: List(Run)) -> List(convex_hull.HullPiece) {
  let endpoints = list.map(runs, run_endpoint)

  case endpoints {
    [] -> []
    [first, ..rest] ->
      pieces_from_endpoints_loop(
        endpoints,
        first,
        rest,
        pieces: [],
      )
      |> list.reverse
  }
}

fn refine_pieces(
  pieces: List(convex_hull.HullPiece),
  segment: svg_path.Segment,
) -> List(convex_hull.HullPiece) {
  case pieces {
    [] -> []
    [_] -> pieces
    [first, .._rest] -> {
      let assert Ok(last) = list.last(pieces)
      let window = list.append([last, ..pieces], [first])
      refine_pieces_loop(segment, window, remaining: list.length(pieces), refined: [])
      |> list.reverse
      |> sync_line_endpoints
    }
  }
}

fn sync_line_endpoints(pieces: List(convex_hull.HullPiece)) -> List(convex_hull.HullPiece) {
  case pieces {
    [] -> []
    [_] -> pieces
    [first, .._] -> {
      let assert Ok(last) = list.last(pieces)
      let window = list.append([last, ..pieces], [first])
      sync_line_endpoints_loop(window, remaining: list.length(pieces), synced: [])
      |> list.reverse
    }
  }
}

fn sync_line_endpoints_loop(
  window: List(convex_hull.HullPiece),
  remaining remaining: Int,
  synced synced: List(convex_hull.HullPiece),
) -> List(convex_hull.HullPiece) {
  case remaining <= 0 {
    True -> synced
    False -> {
      let assert [previous, current, next, ..rest] = window
      let current = case current {
        convex_hull.HullLine(from, to) -> {
          let from = case previous {
            convex_hull.HullCurve(_, curve_to) -> curve_to
            _ -> from
          }
          let to = case next {
            convex_hull.HullCurve(curve_from, _) -> curve_from
            _ -> to
          }
          convex_hull.HullLine(from, to)
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

fn refine_pieces_loop(
  segment: svg_path.Segment,
  window: List(convex_hull.HullPiece),
  remaining remaining: Int,
  refined refined: List(convex_hull.HullPiece),
) -> List(convex_hull.HullPiece) {
  case remaining <= 0 {
    True -> refined
    False -> {
      let assert [previous, current, next, ..rest] = window
      let refined_current = case current {
        convex_hull.HullCurve(from, to) -> {
          let from = case previous {
            convex_hull.HullLine(other, _) ->
              refine_chord_tangent(segment, approximate: from, other: other)
            _ -> from
          }
          let to = case next {
            convex_hull.HullLine(_, other) ->
              refine_chord_tangent(segment, approximate: to, other: other)
            _ -> to
          }
          convex_hull.HullCurve(from, to)
        }
        convex_hull.HullLine(from, to) -> {
          let from = case previous {
            convex_hull.HullCurve(_, _) ->
              refine_chord_tangent(segment, approximate: from, other: to)
            _ -> from
          }
          let to = case next {
            convex_hull.HullCurve(_, _) ->
              refine_chord_tangent(segment, approximate: to, other: from)
            _ -> to
          }
          convex_hull.HullLine(from, to)
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
        False -> refine_chord_tangent_scan(
          segment,
          approximate: approximate,
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
  approximate _approximate: Float,
  other other: Float,
  left left: Float,
  right right: Float,
  steps steps: Int,
  best best: Float,
  best_value best_value: Float,
) -> Float {
  let initial_value = chord_tangent_value(segment, left, other)
  int.range(from: 1, to: steps, with: Continue(#(left, initial_value, best, best_value)), run: fn(state, i) {
    case state {
      Done(root) -> Done(root)
      Continue(#(previous_t, previous_value, best, best_value)) -> {
        let t = left +. { right -. left } *. int.to_float(i) /. int.to_float(steps)
        let value = chord_tangent_value(segment, t, other)
        let #(best, best_value) = case float.absolute_value(value) <. best_value {
          True -> #(t, float.absolute_value(value))
          False -> #(best, best_value)
        }
        case value == 0.0 || previous_value == 0.0 || same_sign(value, previous_value) == False {
          True ->
            Done(bisect_chord_tangent(segment, other, left: previous_t, right: t))
          False -> Continue(#(t, value, best, best_value))
        }
      }
    }
  })
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

fn pieces_from_endpoints_loop(
  endpoints: List(RunEndpoint),
  first first: RunEndpoint,
  rest rest: List(RunEndpoint),
  pieces pieces: List(convex_hull.HullPiece),
) -> List(convex_hull.HullPiece) {
  case endpoints, rest {
    [], _ -> pieces
    [current, .._remaining], [] -> {
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
  pieces: List(convex_hull.HullPiece),
  endpoint: RunEndpoint,
) -> List(convex_hull.HullPiece) {
  case endpoint {
    PointEndpoint(_) -> pieces
    CurveEndpoint(from, to) ->
      case float.absolute_value(from -. to) <=. same_t {
        True -> pieces
        False -> [convex_hull.HullCurve(from, to), ..pieces]
      }
  }
}

fn add_line(
  pieces: List(convex_hull.HullPiece),
  from: Float,
  to: Float,
) -> List(convex_hull.HullPiece) {
  [convex_hull.HullLine(from, to), ..pieces]
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

fn support(
  segment: svg_path.Segment,
  angle angle: Float,
) -> Result(SupportSample, CandidateError) {
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
        list.fold(rest, #(first, cubic_scalar(p0, p1, p2, p3, first)), fn(
          best,
          t,
        ) {
          let value = cubic_scalar(p0, p1, p2, p3, t)
          case value >. best.1 {
            True -> #(t, value)
            False -> best
          }
        })

      Ok(SupportSample(angle: angle, t: best.0, value: best.1))
    }
    _ -> Error(NotCubic)
  }
}

fn hull_piece_support(
  segment: svg_path.Segment,
  pieces: List(convex_hull.HullPiece),
  angle: Float,
) -> Result(Float, CandidateError) {
  case pieces {
    [] -> Ok(-1.0 /. 0.0)
    [piece, ..rest] -> {
      use first <- result.try(piece_support(segment, piece, angle))
      list.fold(rest, Ok(first), fn(worst, piece) {
        use worst <- result.try(worst)
        use value <- result.try(piece_support(segment, piece, angle))
        Ok(float.max(worst, value))
      })
    }
  }
}

fn piece_support(
  segment: svg_path.Segment,
  piece: convex_hull.HullPiece,
  angle: Float,
) -> Result(Float, CandidateError) {
  case piece {
    convex_hull.HullLine(from, to) -> {
      use first <- result.try(segment_point(segment, from))
      use second <- result.try(segment_point(segment, to))
      let direction = angle_direction(angle)
      Ok(float.max(dot(first, direction), dot(second, direction)))
    }
    convex_hull.HullCurve(from, to) ->
      curve_interval_support(segment, angle, from: from, to: to)
  }
}

fn curve_interval_support(
  segment: svg_path.Segment,
  angle: Float,
  from from: Float,
  to to: Float,
) -> Result(Float, CandidateError) {
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
      let lo = float.min(from, to)
      let hi = float.max(from, to)
      let candidates =
        [from, to, ..quadratic_roots(3.0 *. a, 2.0 *. b, c)]
        |> list.filter(fn(t) { t >=. lo && t <=. hi })

      let assert [first, ..rest] = candidates
      Ok(
        list.fold(rest, cubic_scalar(p0, p1, p2, p3, first), fn(worst, t) {
          float.max(worst, cubic_scalar(p0, p1, p2, p3, t))
        }),
      )
    }
    _ -> Error(NotCubic)
  }
}

fn pieces_to_segments(
  segment: svg_path.Segment,
  pieces: List(convex_hull.HullPiece),
) -> Result(List(svg_path.Segment), CandidateError) {
  list.fold(pieces, Ok([]), fn(segments, piece) {
    use segments <- result.try(segments)
    use segment <- result.try(piece_to_segment(segment, piece))
    Ok([segment, ..segments])
  })
  |> result.map(list.reverse)
}

fn piece_to_segment(
  segment: svg_path.Segment,
  piece: convex_hull.HullPiece,
) -> Result(svg_path.Segment, CandidateError) {
  case piece {
    convex_hull.HullCurve(from, to) ->
      svg_path.sub_segment(segment, from: from, to: to)
      |> result.map_error(PathError)
    convex_hull.HullLine(from, to) -> {
      use start <- result.try(segment_point(segment, from))
      use end <- result.try(segment_point(segment, to))
      Ok(svg_path.line(start: start, end: end))
    }
  }
}

fn segment_point(
  segment: svg_path.Segment,
  t: Float,
) -> Result(svg_path.Point, CandidateError) {
  svg_path.segment_point(segment, at: t)
  |> result.map_error(PathError)
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
  p0 *. mt *. mt *. mt
  +. 3.0 *. p1 *. mt *. mt *. t
  +. 3.0 *. p2 *. mt *. t *. t
  +. p3 *. t *. t *. t
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

fn drop_last(items: List(a)) -> List(a) {
  case items {
    [] -> []
    [_] -> []
    [first, ..rest] -> [first, ..drop_last(rest)]
  }
}
