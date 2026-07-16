//// Convex hull helpers for path segments.
////
//// This module computes a closed hull for a single segment. The hull reuses
//// portions of the original segment when they lie on the hull boundary and
//// joins those portions with straight lines.
////
//// The algorithm is numerical. When it cannot refine or simplify its support
//// samples enough to certify the hull-piece sequence, it returns `HullError`
//// rather than guessing.

import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam_community/maths
import svg_path

const initial_sample_number = 100

const unit_diameter_distance_tolerance = 0.000001

const t_tolerance = 0.1

/// A support sample: `#(angle, t, segment_point(t))`.
type SupportSample =
  #(Float, Float, svg_path.Point)

/// How an adjacent pair of support samples compares.
type SamplePair {
  /// The two sampled `t` values are too far apart.
  TFar

  /// The two sampled `t` values are close, but their points are far apart.
  ///
  /// Carries the observed `t` distance.
  TClosePointsFar(Float)

  /// The two sampled `t` values are close, and their points are close.
  ///
  /// Carries the observed `t` distance and point distance.
  TClosePointsClose(Float, Float)
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

fn segment_support(
  segment: svg_path.Segment,
  degrees degrees: Float,
) -> Result(#(Float, svg_path.Point), svg_path.Error) {
  let direction = angle_direction(degrees)

  case segment {
    svg_path.Line(start:, end:) -> Ok(line_support(start, end, direction))
    svg_path.CubicBezier(start:, control1:, control2:, end:) ->
      cubic_support(
        svg_path.CubicBezier(start:, control1:, control2:, end:),
        start,
        control1,
        control2,
        end,
        direction,
      )
    _ -> numeric_support(segment, direction)
  }
}

fn line_support(
  start: svg_path.Point,
  end: svg_path.Point,
  direction: svg_path.Point,
) -> #(Float, svg_path.Point) {
  let start_support = dot(start, direction)
  let end_support = dot(end, direction)

  case float.absolute_value(start_support -. end_support) <=. 0.000000001 {
    True -> #(0.0, start)
    False ->
      case start_support >. end_support {
        True -> #(0.0, start)
        False -> #(1.0, end)
      }
  }
}

fn numeric_support(
  segment: svg_path.Segment,
  direction: svg_path.Point,
) -> Result(#(Float, svg_path.Point), svg_path.Error) {
  use t <- result.try(
    svg_path.segment_minimize(segment, measure: fn(point) {
      0.0 -. dot(point, direction)
    }),
  )
  use point <- result.try(svg_path.segment_point(segment, at: t))

  Ok(#(t, point))
}

fn cubic_support(
  segment: svg_path.Segment,
  start: svg_path.Point,
  control1: svg_path.Point,
  control2: svg_path.Point,
  end: svg_path.Point,
  direction: svg_path.Point,
) -> Result(#(Float, svg_path.Point), svg_path.Error) {
  case
    analytic_cubic_support(start, control1, control2, end, direction),
    numeric_support(segment, direction)
  {
    Ok(analytic), Ok(numeric) -> Ok(best_support(analytic, numeric, direction))
    Ok(analytic), Error(_) -> Ok(analytic)
    Error(_), Ok(numeric) -> Ok(numeric)
    Error(error), Error(_) -> Error(error)
  }
}

fn analytic_cubic_support(
  start: svg_path.Point,
  control1: svg_path.Point,
  control2: svg_path.Point,
  end: svg_path.Point,
  direction: svg_path.Point,
) -> Result(#(Float, svg_path.Point), svg_path.Error) {
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
    list.fold(rest, #(first, cubic_scalar(p0, p1, p2, p3, first)), fn(best, t) {
      let value = cubic_scalar(p0, p1, p2, p3, t)
      case value >. best.1 {
        True -> #(t, value)
        False -> best
      }
    })

  use point <- result.try(svg_path.segment_point(
    svg_path.CubicBezier(start:, control1:, control2:, end:),
    at: best.0,
  ))
  Ok(#(best.0, point))
}

fn best_support(
  first: #(Float, svg_path.Point),
  second: #(Float, svg_path.Point),
  direction: svg_path.Point,
) -> #(Float, svg_path.Point) {
  case dot(first.1, direction) >=. dot(second.1, direction) {
    True -> first
    False -> second
  }
}

fn support_sample(
  segment: svg_path.Segment,
  angle angle: Float,
) -> Result(SupportSample, svg_path.Error) {
  case segment_support(segment, degrees: angle) {
    Error(error) -> Error(error)
    Ok(#(t, point)) -> Ok(#(angle, t, point))
  }
}

fn support_sample_pair(
  first: SupportSample,
  second: SupportSample,
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
) -> SamplePair {
  let #(_, first_t, first_point) = first
  let #(_, second_t, second_point) = second
  let distance = point_distance(first_point, second_point)
  let t_distance = float.absolute_value(first_t -. second_t)

  case t_distance <=. t_tolerance {
    False -> TFar
    True -> {
      case distance <=. distance_tolerance {
        True -> TClosePointsClose(t_distance, distance)
        False -> TClosePointsFar(t_distance)
      }
    }
  }
}

fn sample_pair_contextually_refined(
  left_pair: SamplePair,
  middle_pair: SamplePair,
  right_pair: SamplePair,
) -> Bool {
  case middle_pair {
    TClosePointsFar(_) | TClosePointsClose(_, _) -> True
    TFar ->
      case left_pair, right_pair {
        TClosePointsClose(_, _), TClosePointsClose(_, _) -> True
        _, _ -> False
      }
  }
}

fn sample_pair_far_unrefined(
  left_pair: SamplePair,
  middle_pair: SamplePair,
  right_pair: SamplePair,
) -> Bool {
  !sample_pair_contextually_refined(left_pair, middle_pair, right_pair)
}

fn refine_support_samples_once(
  segment: svg_path.Segment,
  samples samples: List(SupportSample),
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
) -> Result(List(SupportSample), svg_path.Error) {
  let additions =
    support_samples_to_add_for_refinement(
      segment,
      samples: samples,
      distance_tolerance: distance_tolerance,
      t_tolerance: t_tolerance,
    )

  case additions {
    Error(error) -> Error(error)
    Ok(additions) -> Ok(insert_support_samples(samples, additions))
  }
}

fn far_unrefined_pairs(
  samples: List(SupportSample),
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
) -> List(#(SupportSample, SupportSample, Float, Float)) {
  case samples {
    [] -> []
    [_] -> []
    [first, second, ..] -> {
      case list.last(samples) {
        Error(_) -> []
        Ok(last) -> {
          let window_samples = list.append([last, ..samples], [first, second])
          collect_far_unrefined_pairs(
            window_samples: window_samples,
            remaining: list.length(samples),
            distance_tolerance: distance_tolerance,
            t_tolerance: t_tolerance,
            pairs: [],
          )
        }
      }
    }
  }
}

fn purify_support_samples_once(
  samples: List(SupportSample),
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
) -> List(SupportSample) {
  case list.length(samples) <= 2 {
    True -> samples
    False ->
      purify_support_samples_once_long(
        samples,
        distance_tolerance: distance_tolerance,
        t_tolerance: t_tolerance,
      )
  }
}

fn purify_support_samples_once_long(
  samples: List(SupportSample),
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
) -> List(SupportSample) {
  let without_duplicate_t_values = remove_adjacent_duplicate_t_values(samples)
  case list.length(without_duplicate_t_values) == list.length(samples) {
    False -> without_duplicate_t_values
    True ->
      case
        remove_first_unneeded_support_sample(
          remaining: samples,
          before: [],
          distance_tolerance: distance_tolerance,
          t_tolerance: t_tolerance,
        )
      {
        Ok(samples) -> samples
        Error(Nil) -> samples
      }
  }
}

fn purify_support_samples(
  samples: List(SupportSample),
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
  max_iterations max_iterations: Int,
) -> Result(List(SupportSample), HullError) {
  purify_support_samples_loop(
    samples,
    distance_tolerance: distance_tolerance,
    t_tolerance: t_tolerance,
    max_iterations: max_iterations,
    iteration: 0,
  )
}

fn support_samples_to_hull_pieces(
  samples: List(SupportSample),
  t_tolerance t_tolerance: Float,
) -> Result(List(HullPiece), HullError) {
  case support_samples_have_no_adjacent_duplicate_t_values(samples) {
    False -> Error(DuplicateAdjacentTValues)
    True ->
      samples
      |> adjacent_hull_pieces(t_tolerance)
      |> glob_hull_curves
      |> reject_consecutive_curves
  }
}

pub fn segment_hull(
  segment: svg_path.Segment,
) -> Result(#(svg_path.Subpath, List(HullPiece)), HullError) {
  use pieces <- result.try(segment_hull_pieces(segment))
  use segments <- result.try(hull_piece_segments(segment, pieces))
  use subpath <- result.try(map_path_error(svg_path.subpath(segments)))
  use subpath <- result.try(
    map_path_error(svg_path.set_closed(subpath, closed: True)),
  )

  Ok(#(subpath, pieces))
}

fn segment_hull_pieces(
  segment: svg_path.Segment,
) -> Result(List(HullPiece), HullError) {
  use #(purified, refined) <- result.try(segment_hull_sample_stages(segment))

  case degenerate_point_hull_pieces(purified, fallback: refined) {
    Ok(pieces) -> Ok(pieces)
    Error(Nil) ->
      support_samples_to_hull_pieces(purified, t_tolerance: t_tolerance)
  }
}

fn segment_hull_sample_stages(
  segment: svg_path.Segment,
) -> Result(#(List(SupportSample), List(SupportSample)), HullError) {
  use box <- result.try(map_path_error(svg_path.segment_bounding_box(segment)))
  let distance_tolerance =
    svg_path.bounding_box_diameter(box) *. unit_diameter_distance_tolerance
  use samples <- result.try(map_path_error(initial_support_samples(segment)))
  use refined <- result.try(refine_until_contextually_resolved(
    segment,
    samples: samples,
    distance_tolerance: distance_tolerance,
    t_tolerance: t_tolerance,
    max_iterations: 100,
  ))
  use purified <- result.try(purify_support_samples(
    refined,
    distance_tolerance: distance_tolerance,
    t_tolerance: t_tolerance,
    max_iterations: 1000,
  ))

  Ok(#(purified, refined))
}

fn degenerate_point_hull_pieces(
  samples: List(SupportSample),
  fallback fallback: List(SupportSample),
) -> Result(List(HullPiece), Nil) {
  case samples {
    [sample] -> Ok(two_point_hull_lines(sample))
    [] ->
      case fallback {
        [sample, ..] -> Ok(two_point_hull_lines(sample))
        [] -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

fn two_point_hull_lines(sample: SupportSample) -> List(HullPiece) {
  let #(_, t, _) = sample

  [HullLine(t, t), HullLine(t, t)]
}

fn hull_piece_segments(
  segment: svg_path.Segment,
  pieces: List(HullPiece),
) -> Result(List(svg_path.Segment), HullError) {
  pieces
  |> list.try_map(hull_piece_segment(segment, _))
}

fn refine_until_contextually_resolved(
  segment: svg_path.Segment,
  samples samples: List(SupportSample),
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
  max_iterations max_iterations: Int,
) -> Result(List(SupportSample), HullError) {
  case
    far_unrefined_pairs(
      samples,
      distance_tolerance: distance_tolerance,
      t_tolerance: t_tolerance,
    )
  {
    [] -> Ok(samples)
    _ -> {
      case max_iterations <= 0 {
        True -> Error(RefinementReachedMaxIterations(max_iterations))
        False ->
          case
            refine_support_samples_once(
              segment,
              samples: samples,
              distance_tolerance: distance_tolerance,
              t_tolerance: t_tolerance,
            )
          {
            Error(error) -> Error(PathError(error))
            Ok(samples) ->
              refine_until_contextually_resolved(
                segment,
                samples: samples,
                distance_tolerance: distance_tolerance,
                t_tolerance: t_tolerance,
                max_iterations: max_iterations - 1,
              )
          }
      }
    }
  }
}

fn remove_adjacent_duplicate_t_values(
  samples: List(SupportSample),
) -> List(SupportSample) {
  case samples {
    [] -> []
    [first, ..rest] ->
      remove_adjacent_duplicate_t_values_loop(
        first,
        previous: first,
        rest: rest,
        kept: [first],
      )
  }
}

fn remove_adjacent_duplicate_t_values_loop(
  first first: SupportSample,
  previous previous: SupportSample,
  rest rest: List(SupportSample),
  kept kept: List(SupportSample),
) -> List(SupportSample) {
  case rest {
    [] -> {
      let #(_, first_t, _) = first
      let #(_, previous_t, _) = previous
      case first_t == previous_t {
        True -> kept |> list.reverse |> drop_last
        False -> list.reverse(kept)
      }
    }
    [sample, ..rest] -> {
      let #(_, sample_t, _) = sample
      let #(_, previous_t, _) = previous
      let kept = case sample_t == previous_t {
        True -> kept
        False -> [sample, ..kept]
      }
      remove_adjacent_duplicate_t_values_loop(
        first,
        previous: sample,
        rest: rest,
        kept: kept,
      )
    }
  }
}

fn hull_piece_segment(
  segment: svg_path.Segment,
  piece: HullPiece,
) -> Result(svg_path.Segment, HullError) {
  case piece {
    HullCurve(from, to) ->
      map_path_error(svg_path.segment_between(segment, from: from, to: to))
    HullLine(from, to) -> {
      use start <- result.try(
        map_path_error(svg_path.segment_point(segment, at: from)),
      )
      use end <- result.try(
        map_path_error(svg_path.segment_point(segment, at: to)),
      )
      Ok(svg_path.Line(start:, end:))
    }
  }
}

fn initial_support_samples(
  segment: svg_path.Segment,
) -> Result(List(SupportSample), svg_path.Error) {
  int.range(from: 0, to: initial_sample_number, with: [], run: fn(samples, i) {
    let angle = int.to_float(i) *. 360.0 /. int.to_float(initial_sample_number)
    [angle, ..samples]
  })
  |> list.reverse
  |> list.try_map(fn(angle) { support_sample(segment, angle:) })
}

fn purify_support_samples_loop(
  samples: List(SupportSample),
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
  max_iterations max_iterations: Int,
  iteration iteration: Int,
) -> Result(List(SupportSample), HullError) {
  let purified =
    purify_support_samples_once(
      samples,
      distance_tolerance: distance_tolerance,
      t_tolerance: t_tolerance,
    )

  case list.length(purified) == list.length(samples) {
    True -> Ok(samples)
    False -> {
      case iteration >= max_iterations {
        True -> Error(PurificationReachedMaxIterations(max_iterations))
        False ->
          purify_support_samples_loop(
            purified,
            distance_tolerance: distance_tolerance,
            t_tolerance: t_tolerance,
            max_iterations: max_iterations,
            iteration: iteration + 1,
          )
      }
    }
  }
}

fn remove_first_unneeded_support_sample(
  remaining remaining: List(SupportSample),
  before before: List(SupportSample),
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
) -> Result(List(SupportSample), Nil) {
  case remaining {
    [] -> Error(Nil)
    [sample, ..after] -> {
      let without_sample = list.append(list.reverse(before), after)
      let normalized_without_sample =
        remove_adjacent_duplicate_t_values(without_sample)

      case
        sample_touches_two_far_pairs(
          sample,
          before: before,
          after: after,
          distance_tolerance: distance_tolerance,
          t_tolerance: t_tolerance,
        )
      {
        True ->
          remove_first_unneeded_support_sample(
            remaining: after,
            before: [sample, ..before],
            distance_tolerance: distance_tolerance,
            t_tolerance: t_tolerance,
          )

        False -> {
          case list.length(normalized_without_sample) <= 2 {
            True -> Ok(normalized_without_sample)
            False -> {
              case
                far_unrefined_pairs(
                  normalized_without_sample,
                  distance_tolerance: distance_tolerance,
                  t_tolerance: t_tolerance,
                )
              {
                [] -> Ok(normalized_without_sample)
                _ ->
                  remove_first_unneeded_support_sample(
                    remaining: after,
                    before: [sample, ..before],
                    distance_tolerance: distance_tolerance,
                    t_tolerance: t_tolerance,
                  )
              }
            }
          }
        }
      }
    }
  }
}

fn sample_touches_two_far_pairs(
  sample: SupportSample,
  before before: List(SupportSample),
  after after: List(SupportSample),
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
) -> Bool {
  let left = case before {
    [left, ..] -> Ok(left)
    [] -> list.last(after)
  }
  let right = case after {
    [right, ..] -> Ok(right)
    [] -> list.last(before)
  }

  case left, right {
    Ok(left), Ok(right) ->
      sample_pair_is_far(
        left,
        sample,
        distance_tolerance: distance_tolerance,
        t_tolerance: t_tolerance,
      )
      && sample_pair_is_far(
        sample,
        right,
        distance_tolerance: distance_tolerance,
        t_tolerance: t_tolerance,
      )

    _, _ -> False
  }
}

fn sample_pair_is_far(
  first: SupportSample,
  second: SupportSample,
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
) -> Bool {
  case
    support_sample_pair(
      first,
      second,
      distance_tolerance: distance_tolerance,
      t_tolerance: t_tolerance,
    )
  {
    TFar -> True
    TClosePointsFar(_) | TClosePointsClose(_, _) -> False
  }
}

fn support_samples_have_no_adjacent_duplicate_t_values(
  samples: List(SupportSample),
) -> Bool {
  case samples {
    [] -> True
    [first, ..rest] ->
      support_samples_have_no_adjacent_duplicate_t_values_loop(
        first,
        previous: first,
        rest: rest,
      )
  }
}

fn support_samples_have_no_adjacent_duplicate_t_values_loop(
  first first: SupportSample,
  previous previous: SupportSample,
  rest rest: List(SupportSample),
) -> Bool {
  case rest {
    [] -> !same_sample_t(previous, first)
    [next, ..rest] -> {
      case same_sample_t(previous, next) {
        True -> False
        False ->
          support_samples_have_no_adjacent_duplicate_t_values_loop(
            first,
            previous: next,
            rest: rest,
          )
      }
    }
  }
}

fn same_sample_t(first: SupportSample, second: SupportSample) -> Bool {
  let #(_, first_t, _) = first
  let #(_, second_t, _) = second

  first_t == second_t
}

fn adjacent_hull_pieces(
  samples: List(SupportSample),
  t_tolerance: Float,
) -> List(HullPiece) {
  case samples {
    [] -> []
    [first, ..rest] ->
      adjacent_hull_pieces_loop(
        first,
        current: first,
        rest: rest,
        t_tolerance: t_tolerance,
        pieces: [],
      )
  }
}

fn adjacent_hull_pieces_loop(
  first first: SupportSample,
  current current: SupportSample,
  rest rest: List(SupportSample),
  t_tolerance t_tolerance: Float,
  pieces pieces: List(HullPiece),
) -> List(HullPiece) {
  case rest {
    [] ->
      [hull_piece(current, first, t_tolerance), ..pieces]
      |> list.reverse
    [next, ..rest] ->
      adjacent_hull_pieces_loop(
        first,
        current: next,
        rest: rest,
        t_tolerance: t_tolerance,
        pieces: [hull_piece(current, next, t_tolerance), ..pieces],
      )
  }
}

fn hull_piece(
  first: SupportSample,
  second: SupportSample,
  t_tolerance: Float,
) -> HullPiece {
  let #(_, first_t, _) = first
  let #(_, second_t, _) = second

  case float.absolute_value(first_t -. second_t) <. t_tolerance {
    True -> HullCurve(first_t, second_t)
    False -> HullLine(first_t, second_t)
  }
}

fn glob_hull_curves(pieces: List(HullPiece)) -> List(HullPiece) {
  pieces
  |> glob_hull_curves_open
  |> glob_circular_hull_curves
}

fn glob_hull_curves_open(pieces: List(HullPiece)) -> List(HullPiece) {
  case pieces {
    [] -> []
    [first, ..rest] ->
      glob_hull_curves_open_loop(rest, current: first, pieces: [])
  }
}

fn glob_hull_curves_open_loop(
  remaining: List(HullPiece),
  current current: HullPiece,
  pieces pieces: List(HullPiece),
) -> List(HullPiece) {
  case remaining {
    [] -> [current, ..pieces] |> list.reverse
    [next, ..rest] -> {
      case glob_two_hull_pieces(current, next) {
        Ok(globbed) ->
          glob_hull_curves_open_loop(rest, current: globbed, pieces: pieces)
        Error(Nil) ->
          glob_hull_curves_open_loop(rest, current: next, pieces: [
            current,
            ..pieces
          ])
      }
    }
  }
}

fn glob_circular_hull_curves(pieces: List(HullPiece)) -> List(HullPiece) {
  case pieces {
    [] -> []
    [first, ..rest] -> {
      case list.last(rest) {
        Error(_) -> [first]
        Ok(last) -> {
          case glob_two_hull_pieces(last, first) {
            Error(Nil) -> pieces
            Ok(globbed) -> {
              let without_last = drop_last(rest)
              [globbed, ..without_last]
            }
          }
        }
      }
    }
  }
}

fn glob_two_hull_pieces(
  first: HullPiece,
  second: HullPiece,
) -> Result(HullPiece, Nil) {
  case first, second {
    HullCurve(first_from, first_to), HullCurve(second_from, second_to) -> {
      case
        first_to == second_from
        && same_t_direction(first_from, first_to, second_to)
      {
        True -> Ok(HullCurve(first_from, second_to))
        False -> Error(Nil)
      }
    }
    _, _ -> Error(Nil)
  }
}

fn same_t_direction(first: Float, second: Float, third: Float) -> Bool {
  second >. first && third >. second || second <. first && third <. second
}

fn drop_last(items: List(a)) -> List(a) {
  case items {
    [] -> []
    [_] -> []
    [first, ..rest] -> [first, ..drop_last(rest)]
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
  first first: HullPiece,
  previous previous: HullPiece,
  rest rest: List(HullPiece),
) -> Bool {
  case rest {
    [] -> both_curves(previous, first)
    [next, ..rest] -> {
      case both_curves(previous, next) {
        True -> True
        False -> has_consecutive_curves_loop(first, previous: next, rest: rest)
      }
    }
  }
}

fn both_curves(first: HullPiece, second: HullPiece) -> Bool {
  case first, second {
    HullCurve(_, _), HullCurve(_, _) -> True
    _, _ -> False
  }
}

fn support_sample_window_pairs(
  left: SupportSample,
  middle_left: SupportSample,
  middle_right: SupportSample,
  right: SupportSample,
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
) -> #(SamplePair, SamplePair, SamplePair) {
  #(
    support_sample_pair(
      left,
      middle_left,
      distance_tolerance: distance_tolerance,
      t_tolerance: t_tolerance,
    ),
    support_sample_pair(
      middle_left,
      middle_right,
      distance_tolerance: distance_tolerance,
      t_tolerance: t_tolerance,
    ),
    support_sample_pair(
      middle_right,
      right,
      distance_tolerance: distance_tolerance,
      t_tolerance: t_tolerance,
    ),
  )
}

fn collect_far_unrefined_pairs(
  window_samples window_samples: List(SupportSample),
  remaining remaining: Int,
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
  pairs pairs: List(#(SupportSample, SupportSample, Float, Float)),
) -> List(#(SupportSample, SupportSample, Float, Float)) {
  case remaining <= 0 {
    True -> list.reverse(pairs)
    False -> {
      case window_samples {
        [left, middle_left, middle_right, right, ..rest] -> {
          let #(left_pair, middle_pair, right_pair) =
            support_sample_window_pairs(
              left,
              middle_left,
              middle_right,
              right,
              distance_tolerance: distance_tolerance,
              t_tolerance: t_tolerance,
            )
          let pairs = case
            sample_pair_far_unrefined(left_pair, middle_pair, right_pair)
          {
            True -> [
              #(
                middle_left,
                middle_right,
                support_sample_point_distance(left, middle_left),
                support_sample_point_distance(middle_right, right),
              ),
              ..pairs
            ]
            False -> pairs
          }

          collect_far_unrefined_pairs(
            window_samples: [middle_left, middle_right, right, ..rest],
            remaining: remaining - 1,
            distance_tolerance: distance_tolerance,
            t_tolerance: t_tolerance,
            pairs: pairs,
          )
        }
        _ -> list.reverse(pairs)
      }
    }
  }
}

fn support_samples_to_add_for_refinement(
  segment: svg_path.Segment,
  samples samples: List(SupportSample),
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
) -> Result(List(SupportSample), svg_path.Error) {
  case samples {
    [] -> Ok([])
    [first, second, ..] -> {
      case list.last(samples) {
        Error(_) -> Ok([])
        Ok(last) -> {
          let window_samples = list.append([last, ..samples], [first, second])

          collect_refinement_additions(
            segment,
            window_samples: window_samples,
            remaining: list.length(samples),
            distance_tolerance: distance_tolerance,
            t_tolerance: t_tolerance,
            additions: [],
          )
        }
      }
    }
    [_] -> Ok([])
  }
}

fn collect_refinement_additions(
  segment: svg_path.Segment,
  window_samples window_samples: List(SupportSample),
  remaining remaining: Int,
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
  additions additions: List(SupportSample),
) -> Result(List(SupportSample), svg_path.Error) {
  case remaining <= 0 {
    True -> Ok(list.reverse(additions))
    False -> {
      case window_samples {
        [left, middle_left, middle_right, right, ..rest] -> {
          let #(left_pair, middle_pair, right_pair) =
            support_sample_window_pairs(
              left,
              middle_left,
              middle_right,
              right,
              distance_tolerance: distance_tolerance,
              t_tolerance: t_tolerance,
            )

          case sample_pair_far_unrefined(left_pair, middle_pair, right_pair) {
            True ->
              case
                support_sample(
                  segment,
                  angle: midpoint_angle(middle_left, middle_right),
                )
              {
                Error(error) -> Error(error)
                Ok(sample) ->
                  collect_refinement_additions(
                    segment,
                    window_samples: [middle_left, middle_right, right, ..rest],
                    remaining: remaining - 1,
                    distance_tolerance: distance_tolerance,
                    t_tolerance: t_tolerance,
                    additions: [sample, ..additions],
                  )
              }
            False ->
              collect_refinement_additions(
                segment,
                window_samples: [middle_left, middle_right, right, ..rest],
                remaining: remaining - 1,
                distance_tolerance: distance_tolerance,
                t_tolerance: t_tolerance,
                additions: additions,
              )
          }
        }
        _ -> Ok(list.reverse(additions))
      }
    }
  }
}

fn insert_support_samples(
  samples: List(SupportSample),
  additions: List(SupportSample),
) -> List(SupportSample) {
  case additions {
    [] -> samples
    [first, ..rest] ->
      insert_support_samples(insert_support_sample(samples, first), rest)
  }
}

fn insert_support_sample(
  samples: List(SupportSample),
  sample: SupportSample,
) -> List(SupportSample) {
  let angle = sample_angle(sample)

  case samples {
    [] -> [sample]
    [first, ..rest] -> {
      let first_angle = sample_angle(first)

      case angle <. first_angle {
        True -> [sample, first, ..rest]
        False -> {
          case angle == first_angle {
            True -> samples
            False -> [first, ..insert_support_sample(rest, sample)]
          }
        }
      }
    }
  }
}

fn support_sample_point_distance(
  first: SupportSample,
  second: SupportSample,
) -> Float {
  let #(_, _, first_point) = first
  let #(_, _, second_point) = second

  point_distance(first_point, second_point)
}

fn midpoint_angle(first: SupportSample, second: SupportSample) -> Float {
  let first_angle = sample_angle(first)
  let second_angle = sample_angle(second)

  case second_angle <. first_angle {
    True -> normalize_angle({ first_angle +. second_angle +. 360.0 } /. 2.0)
    False -> { first_angle +. second_angle } /. 2.0
  }
}

fn sample_angle(sample: SupportSample) -> Float {
  let #(angle, _, _) = sample
  angle
}

fn normalize_angle(angle: Float) -> Float {
  case angle <. 0.0 {
    True -> normalize_angle(angle +. 360.0)
    False -> {
      case angle >=. 360.0 {
        True -> normalize_angle(angle -. 360.0)
        False -> angle
      }
    }
  }
}

fn angle_direction(angle: Float) -> svg_path.Point {
  let radians = angle *. maths.pi() /. 180.0
  svg_path.point(maths.cos(radians), maths.sin(radians))
}

fn dot(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.x +. a.y *. b.y
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

fn map_path_error(result: Result(a, svg_path.Error)) -> Result(a, HullError) {
  result.map_error(result, PathError)
}

fn point_distance(a: svg_path.Point, b: svg_path.Point) -> Float {
  let dx = a.x -. b.x
  let dy = a.y -. b.y

  case float.square_root(dx *. dx +. dy *. dy) {
    Ok(distance) -> distance
    Error(_) -> 0.0
  }
}
