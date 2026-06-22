//// Experimental convex hull helpers for path segments.

import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam_community/maths
import svg_path
import svg_path/number_format
import svg_path/svg

const initial_sample_number = 100

const unit_diameter_distance_tolerance = 0.000001

const t_tolerance = 0.05

const debug_refinement_iterations = 2

pub type AngleSupportOptions {
  AngleSupportOptions(samples: Int, tolerance: Float, max_iterations: Int)
}

/// A support sample: `#(angle, t, segment_point(t))`.
pub type SupportSample =
  #(Float, Float, svg_path.Point)

/// How an adjacent pair of support samples has been resolved.
pub type PairResolution {
  /// The two sampled points are close enough in drawing space.
  PointsClose(Float)

  /// The two sampled `t` values are close enough in parameter space.
  TsClose(Float)

  /// Neither sampled points nor `t` values are close enough.
  PairNoResolution
}

pub type SampleResolution {
  BothVanillaResolved(PairResolution, PairResolution)

  LeftPointsCloseResolved(PairResolution)

  RightPointsCloseResolved(PairResolution)

  NoResolution
}

pub type ContextualPairNoResolution {
  ContextualPairNoResolution(
    first: SupportSample,
    second: SupportSample,
    left_point_distance: Float,
    right_point_distance: Float,
  )
}

pub type RefinementStopError {
  RefinementReachedMaxIterations(Int)

  RefinementStepError(svg_path.Error)
}

pub type PurificationError {
  PurificationReachedMaxIterations(Int)
}

pub type HullPiece {
  HullCurve(Float, Float)

  HullLine(Float, Float)
}

pub type HullPieceError {
  ConsecutiveCurves
}

pub fn main() -> Nil {
  io.println(drawing_svg())
}

pub fn default_angle_support_options() -> AngleSupportOptions {
  AngleSupportOptions(samples: 100, tolerance: 0.000000001, max_iterations: 100)
}

pub fn angle_support(
  segment: svg_path.Segment,
  angle angle: Float,
) -> Result(#(Float, svg_path.Point), svg_path.Error) {
  angle_support_with(segment, angle:, options: default_angle_support_options())
}

pub fn angle_support_with(
  segment: svg_path.Segment,
  angle angle: Float,
  options options: AngleSupportOptions,
) -> Result(#(Float, svg_path.Point), svg_path.Error) {
  let direction = angle_direction(angle)
  let minimize_options =
    svg_path.MinimizeOptions(
      samples: options.samples,
      tolerance: options.tolerance,
      max_iterations: options.max_iterations,
    )

  case
    svg_path.segment_minimize_with(
      segment,
      measure: fn(point) { 0.0 -. dot(point, direction) },
      options: minimize_options,
    )
  {
    Error(error) -> Error(error)
    Ok(t) -> {
      case svg_path.segment_point(segment, at: t) {
        Error(error) -> Error(error)
        Ok(point) -> Ok(#(t, point))
      }
    }
  }
}

pub fn support_sample(
  segment: svg_path.Segment,
  angle angle: Float,
) -> Result(SupportSample, svg_path.Error) {
  case angle_support(segment, angle:) {
    Error(error) -> Error(error)
    Ok(#(t, point)) -> Ok(#(angle, t, point))
  }
}

pub fn support_sample_resolution(
  first: SupportSample,
  second: SupportSample,
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
) -> PairResolution {
  let #(_, first_t, first_point) = first
  let #(_, second_t, second_point) = second
  let distance = point_distance(first_point, second_point)
  let t_distance = float.absolute_value(first_t -. second_t)

  case distance <=. distance_tolerance {
    True -> PointsClose(distance)
    False -> {
      case t_distance <=. t_tolerance {
        True -> TsClose(t_distance)
        False -> PairNoResolution
      }
    }
  }
}

pub fn middle_support_sample_resolution(
  left: SupportSample,
  middle: SupportSample,
  right: SupportSample,
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
) -> SampleResolution {
  let left_resolution =
    support_sample_resolution(
      left,
      middle,
      distance_tolerance: distance_tolerance,
      t_tolerance: t_tolerance,
    )
  let right_resolution =
    support_sample_resolution(
      middle,
      right,
      distance_tolerance: distance_tolerance,
      t_tolerance: t_tolerance,
    )

  case left_resolution, right_resolution {
    PairNoResolution, PointsClose(_) ->
      RightPointsCloseResolved(right_resolution)
    PointsClose(_), PairNoResolution -> LeftPointsCloseResolved(left_resolution)
    PairNoResolution, _ -> NoResolution
    _, PairNoResolution -> NoResolution
    _, _ -> BothVanillaResolved(left_resolution, right_resolution)
  }
}

pub fn assert_ordered_support_sample_angles(
  samples: List(SupportSample),
) -> Nil {
  case support_sample_angles_are_ordered(samples) {
    True -> Nil
    False ->
      panic as "svg_path/convex_hull.assert_ordered_support_sample_angles received invalid angles"
  }
}

pub fn bisect_unresolved_pairs_once(
  segment: svg_path.Segment,
  samples samples: List(SupportSample),
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
) -> Result(List(SupportSample), svg_path.Error) {
  case samples {
    [] -> Ok([])
    [first, ..rest] -> {
      case
        bisect_unresolved_pairs_loop(
          segment,
          current: first,
          rest: rest,
          first: first,
          distance_tolerance: distance_tolerance,
          t_tolerance: t_tolerance,
          output: [],
        )
      {
        Error(error) -> Error(error)
        Ok(output) -> Ok(rotate_smallest_angle_to_front(output))
      }
    }
  }
}

pub fn refine_support_samples_once(
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

pub fn first_iteration_without_refinement(
  segment: svg_path.Segment,
  samples samples: List(SupportSample),
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
  max_iterations max_iterations: Int,
) -> Result(Int, RefinementStopError) {
  first_iteration_without_refinement_loop(
    segment,
    samples: samples,
    distance_tolerance: distance_tolerance,
    t_tolerance: t_tolerance,
    max_iterations: max_iterations,
    iteration: 0,
  )
}

pub fn contextual_pair_no_resolutions(
  samples: List(SupportSample),
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
) -> List(ContextualPairNoResolution) {
  case samples {
    [] -> []
    [_] -> []
    [first, second, ..] -> {
      let assert Ok(last) = list.last(samples)
      let window_samples = list.append([last, ..samples], [first, second])
      collect_contextual_pair_no_resolutions(
        window_samples: window_samples,
        remaining: list.length(samples),
        distance_tolerance: distance_tolerance,
        t_tolerance: t_tolerance,
        resolutions: [],
      )
    }
  }
}

pub fn purify_support_samples_once(
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

pub fn purify_support_samples(
  samples: List(SupportSample),
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
  max_iterations max_iterations: Int,
) -> Result(List(SupportSample), PurificationError) {
  purify_support_samples_loop(
    samples,
    distance_tolerance: distance_tolerance,
    t_tolerance: t_tolerance,
    max_iterations: max_iterations,
    iteration: 0,
  )
}

pub fn support_samples_to_hull_pieces(
  samples: List(SupportSample),
  t_tolerance t_tolerance: Float,
) -> Result(List(HullPiece), HullPieceError) {
  assert_no_adjacent_duplicate_t_values(samples)

  samples
  |> adjacent_hull_pieces(t_tolerance)
  |> glob_hull_curves
  |> reject_consecutive_curves
}

pub fn drawing_svg() -> String {
  let stem = stem()
  let subpath = svg_path.assert_subpath([stem])
  let hull_things = hull_piece_things(stem)
  let things =
    []
    |> list.append([
      svg.StyledPath(
        svg_path.path([subpath]),
        "fill: none; stroke: #adb5bd; stroke-width: 5; stroke-linecap: round",
      ),
    ])
    |> list.append(hull_things)
  let box =
    svg_path.BoundingBox(
      min: svg_path.point(-30.0, -30.0),
      max: svg_path.point(200.0, 115.0),
    )

  svg.paths(things, view_box: box)
}

fn hull_piece_things(segment: svg_path.Segment) -> svg.ThingsToDraw {
  let assert Ok(box) = svg_path.segment_bounding_box(segment)
  let distance_tolerance =
    svg_path.bounding_box_diameter(box) *. unit_diameter_distance_tolerance
  let assert Ok(samples) = initial_support_samples(segment)
  let assert Ok(refined) =
    refine_until_contextually_resolved(
      segment,
      samples: samples,
      distance_tolerance: distance_tolerance,
      t_tolerance: t_tolerance,
      max_iterations: 100,
    )
  let assert Ok(purified) =
    purify_support_samples(
      refined,
      distance_tolerance: distance_tolerance,
      t_tolerance: t_tolerance,
      max_iterations: 1000,
    )
  let assert Ok(pieces) =
    support_samples_to_hull_pieces(purified, t_tolerance: t_tolerance)

  hull_piece_things_loop(
    segment,
    pieces,
    colors: hull_piece_colors(),
    things: [],
  )
}

fn refine_until_contextually_resolved(
  segment: svg_path.Segment,
  samples samples: List(SupportSample),
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
  max_iterations max_iterations: Int,
) -> Result(List(SupportSample), svg_path.Error) {
  case
    contextual_pair_no_resolutions(
      samples,
      distance_tolerance: distance_tolerance,
      t_tolerance: t_tolerance,
    )
  {
    [] -> Ok(samples)
    _ -> {
      case max_iterations <= 0 {
        True -> Ok(samples)
        False ->
          case
            refine_support_samples_once(
              segment,
              samples: samples,
              distance_tolerance: distance_tolerance,
              t_tolerance: t_tolerance,
            )
          {
            Error(error) -> Error(error)
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
        True -> kept |> list.reverse |> list.drop(1)
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

fn hull_piece_things_loop(
  segment: svg_path.Segment,
  pieces: List(HullPiece),
  colors colors: List(String),
  things things: svg.ThingsToDraw,
) -> svg.ThingsToDraw {
  case pieces {
    [] -> list.reverse(things)
    [piece, ..pieces] -> {
      let assert [color, ..next_colors] = colors
      let assert Ok(segment_to_draw) = hull_piece_segment(segment, piece)
      let subpath = svg_path.assert_subpath([segment_to_draw])
      let things = [
        svg.StyledPath(
          svg_path.path([subpath]),
          "fill: none; stroke: "
            <> color
            <> "; stroke-width: 2.5; stroke-linecap: round; stroke-linejoin: round",
        ),
        ..things
      ]
      let colors = case next_colors {
        [] -> hull_piece_colors()
        _ -> next_colors
      }

      hull_piece_things_loop(segment, pieces, colors: colors, things: things)
    }
  }
}

fn hull_piece_segment(
  segment: svg_path.Segment,
  piece: HullPiece,
) -> Result(svg_path.Segment, svg_path.Error) {
  case piece {
    HullCurve(from, to) -> svg_path.sub_segment(segment, from: from, to: to)
    HullLine(from, to) -> {
      use start <- result.try(svg_path.segment_point(segment, at: from))
      use end <- result.try(svg_path.segment_point(segment, at: to))
      Ok(svg_path.line(start:, end:))
    }
  }
}

fn hull_piece_colors() -> List(String) {
  ["#e63946", "#0077b6", "#2d6a4f", "#f77f00", "#7209b7", "#9d0208"]
}

pub fn stem() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(5.0, 70.0),
    control1: svg_path.point(30.0, 20.0),
    control2: svg_path.point(65.0, 105.0),
    end: svg_path.point(95.0, 30.0),
  )
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

fn bisect_unresolved_pairs_loop(
  segment: svg_path.Segment,
  current current: SupportSample,
  rest rest: List(SupportSample),
  first first: SupportSample,
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
  output output: List(SupportSample),
) -> Result(List(SupportSample), svg_path.Error) {
  case rest {
    [] ->
      case
        add_sample_and_maybe_bisection(
          segment,
          current,
          first,
          distance_tolerance: distance_tolerance,
          t_tolerance: t_tolerance,
          output: output,
        )
      {
        Error(error) -> Error(error)
        Ok(output) -> Ok(list.reverse(output))
      }
    [next, ..rest] ->
      case
        add_sample_and_maybe_bisection(
          segment,
          current,
          next,
          distance_tolerance: distance_tolerance,
          t_tolerance: t_tolerance,
          output: output,
        )
      {
        Error(error) -> Error(error)
        Ok(output) ->
          bisect_unresolved_pairs_loop(
            segment,
            current: next,
            rest: rest,
            first: first,
            distance_tolerance: distance_tolerance,
            t_tolerance: t_tolerance,
            output: output,
          )
      }
  }
}

fn add_sample_and_maybe_bisection(
  segment: svg_path.Segment,
  first: SupportSample,
  second: SupportSample,
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
  output output: List(SupportSample),
) -> Result(List(SupportSample), svg_path.Error) {
  case
    support_sample_resolution(
      first,
      second,
      distance_tolerance: distance_tolerance,
      t_tolerance: t_tolerance,
    )
  {
    PairNoResolution ->
      case support_sample(segment, angle: midpoint_angle(first, second)) {
        Error(error) -> Error(error)
        Ok(middle) -> Ok([middle, first, ..output])
      }
    _ -> Ok([first, ..output])
  }
}

fn purify_support_samples_loop(
  samples: List(SupportSample),
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
  max_iterations max_iterations: Int,
  iteration iteration: Int,
) -> Result(List(SupportSample), PurificationError) {
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

      case
        contextual_pair_no_resolutions(
          without_sample,
          distance_tolerance: distance_tolerance,
          t_tolerance: t_tolerance,
        )
      {
        [] -> Ok(without_sample)
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

pub fn assert_no_adjacent_duplicate_t_values(
  samples: List(SupportSample),
) -> Nil {
  case support_samples_have_no_adjacent_duplicate_t_values(samples) {
    True -> Nil
    False ->
      panic as "svg_path/convex_hull.assert_no_adjacent_duplicate_t_values received duplicate adjacent t values"
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
) -> Result(List(HullPiece), HullPieceError) {
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

fn first_iteration_without_refinement_loop(
  segment: svg_path.Segment,
  samples samples: List(SupportSample),
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
  max_iterations max_iterations: Int,
  iteration iteration: Int,
) -> Result(Int, RefinementStopError) {
  case
    support_samples_to_add_for_refinement(
      segment,
      samples: samples,
      distance_tolerance: distance_tolerance,
      t_tolerance: t_tolerance,
    )
  {
    Error(error) -> Error(RefinementStepError(error))
    Ok([]) -> Ok(iteration)
    Ok(additions) -> {
      case iteration >= max_iterations {
        True -> Error(RefinementReachedMaxIterations(max_iterations))
        False ->
          first_iteration_without_refinement_loop(
            segment,
            samples: insert_support_samples(samples, additions),
            distance_tolerance: distance_tolerance,
            t_tolerance: t_tolerance,
            max_iterations: max_iterations,
            iteration: iteration + 1,
          )
      }
    }
  }
}

fn collect_contextual_pair_no_resolutions(
  window_samples window_samples: List(SupportSample),
  remaining remaining: Int,
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
  resolutions resolutions: List(ContextualPairNoResolution),
) -> List(ContextualPairNoResolution) {
  case remaining <= 0 {
    True -> list.reverse(resolutions)
    False -> {
      case window_samples {
        [left, middle_left, middle_right, right, ..rest] -> {
          let left_resolution =
            support_sample_resolution(
              left,
              middle_left,
              distance_tolerance: distance_tolerance,
              t_tolerance: t_tolerance,
            )
          let middle_resolution =
            support_sample_resolution(
              middle_left,
              middle_right,
              distance_tolerance: distance_tolerance,
              t_tolerance: t_tolerance,
            )
          let right_resolution =
            support_sample_resolution(
              middle_right,
              right,
              distance_tolerance: distance_tolerance,
              t_tolerance: t_tolerance,
            )
          let resolutions = case
            should_refine_pair(
              left_resolution,
              middle_resolution,
              right_resolution,
            )
          {
            True -> [
              ContextualPairNoResolution(
                first: middle_left,
                second: middle_right,
                left_point_distance: support_sample_point_distance(
                  left,
                  middle_left,
                ),
                right_point_distance: support_sample_point_distance(
                  middle_right,
                  right,
                ),
              ),
              ..resolutions
            ]
            False -> resolutions
          }

          collect_contextual_pair_no_resolutions(
            window_samples: [middle_left, middle_right, right, ..rest],
            remaining: remaining - 1,
            distance_tolerance: distance_tolerance,
            t_tolerance: t_tolerance,
            resolutions: resolutions,
          )
        }
        _ -> list.reverse(resolutions)
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
      let assert Ok(last) = list.last(samples)
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
          let left_resolution =
            support_sample_resolution(
              left,
              middle_left,
              distance_tolerance: distance_tolerance,
              t_tolerance: t_tolerance,
            )
          let middle_resolution =
            support_sample_resolution(
              middle_left,
              middle_right,
              distance_tolerance: distance_tolerance,
              t_tolerance: t_tolerance,
            )
          let right_resolution =
            support_sample_resolution(
              middle_right,
              right,
              distance_tolerance: distance_tolerance,
              t_tolerance: t_tolerance,
            )

          case
            should_refine_pair(
              left_resolution,
              middle_resolution,
              right_resolution,
            )
          {
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

fn should_refine_pair(
  left_resolution: PairResolution,
  middle_resolution: PairResolution,
  right_resolution: PairResolution,
) -> Bool {
  case middle_resolution {
    PairNoResolution ->
      case left_resolution, right_resolution {
        PointsClose(_), PointsClose(_) -> False
        _, _ -> True
      }
    _ -> False
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

pub fn refined_unresolved_pairs_to_draw(
  segment: svg_path.Segment,
) -> Result(svg.ThingsToDraw, svg_path.Error) {
  case svg_path.segment_bounding_box(segment) {
    Error(error) -> Error(error)
    Ok(box) -> {
      let distance_tolerance =
        svg_path.bounding_box_diameter(box) *. unit_diameter_distance_tolerance
      case initial_support_samples(segment) {
        Error(error) -> Error(error)
        Ok(samples) -> {
          case
            refine_support_samples(
              segment,
              samples: samples,
              distance_tolerance: distance_tolerance,
              t_tolerance: t_tolerance,
              iterations: debug_refinement_iterations,
            )
          {
            Error(error) -> Error(error)
            Ok(samples) -> {
              assert_ordered_support_sample_angles(samples)
              Ok(
                unresolved_pairs_to_draw(unresolved_pairs(
                  samples,
                  distance_tolerance,
                  t_tolerance,
                )),
              )
            }
          }
        }
      }
    }
  }
}

fn refine_support_samples(
  segment: svg_path.Segment,
  samples samples: List(SupportSample),
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
  iterations iterations: Int,
) -> Result(List(SupportSample), svg_path.Error) {
  case iterations <= 0 {
    True -> Ok(samples)
    False -> {
      case
        refine_support_samples_once(
          segment,
          samples: samples,
          distance_tolerance: distance_tolerance,
          t_tolerance: t_tolerance,
        )
      {
        Error(error) -> Error(error)
        Ok(samples) ->
          refine_support_samples(
            segment,
            samples: samples,
            distance_tolerance: distance_tolerance,
            t_tolerance: t_tolerance,
            iterations: iterations - 1,
          )
      }
    }
  }
}

fn unresolved_pairs(
  samples: List(SupportSample),
  distance_tolerance: Float,
  t_tolerance: Float,
) -> List(#(SupportSample, SupportSample)) {
  case samples {
    [] -> []
    [first, ..rest] ->
      collect_unresolved_pairs(
        first,
        current: first,
        rest: rest,
        distance_tolerance: distance_tolerance,
        t_tolerance: t_tolerance,
        pairs: [],
      )
  }
}

fn collect_unresolved_pairs(
  first first: SupportSample,
  current current: SupportSample,
  rest rest: List(SupportSample),
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
  pairs pairs: List(#(SupportSample, SupportSample)),
) -> List(#(SupportSample, SupportSample)) {
  case rest {
    [] ->
      maybe_prepend_unresolved_pair(
        current,
        first,
        distance_tolerance,
        t_tolerance,
        pairs,
      )
      |> list.reverse
    [next, ..rest] -> {
      let pairs =
        maybe_prepend_unresolved_pair(
          current,
          next,
          distance_tolerance,
          t_tolerance,
          pairs,
        )
      collect_unresolved_pairs(
        first,
        current: next,
        rest: rest,
        distance_tolerance: distance_tolerance,
        t_tolerance: t_tolerance,
        pairs: pairs,
      )
    }
  }
}

fn maybe_prepend_unresolved_pair(
  first: SupportSample,
  second: SupportSample,
  distance_tolerance: Float,
  t_tolerance: Float,
  pairs: List(#(SupportSample, SupportSample)),
) -> List(#(SupportSample, SupportSample)) {
  case
    support_sample_resolution(
      first,
      second,
      distance_tolerance: distance_tolerance,
      t_tolerance: t_tolerance,
    )
  {
    PairNoResolution -> [#(first, second), ..pairs]
    _ -> pairs
  }
}

fn unresolved_pairs_to_draw(
  pairs: List(#(SupportSample, SupportSample)),
) -> svg.ThingsToDraw {
  let colors = [
    #("#e63946", "#0077b6"),
    #("#7209b7", "#f77f00"),
    #("#2a9d8f", "#9b5de5"),
    #("#bc6c25", "#0081a7"),
    #("#d00000", "#588157"),
  ]

  pairs
  |> list.index_map(fn(pair, index) {
    let #(first, second) = pair
    let #(first_color, second_color) = color_pair_at(colors, index)

    list.append(
      support_sample_to_draw(first, first_color),
      support_sample_to_draw(second, second_color),
    )
  })
  |> list.flatten
}

fn color_pair_at(
  colors: List(#(String, String)),
  index: Int,
) -> #(String, String) {
  case list.drop(colors, index) {
    [colors, ..] -> colors
    [] -> color_pair_at(colors, index - list.length(colors))
  }
}

fn support_sample_to_draw(
  sample: SupportSample,
  color: String,
) -> svg.ThingsToDraw {
  let #(angle, t, point) = sample
  let format =
    number_format.prepare(
      number_format.Options(
        left_decimals: number_format.Succinct,
        right_decimals: number_format.Fixed(2),
      ),
      [],
    )

  svg.labeled_point(
    number_format.number(angle, with: format)
      <> "deg t="
      <> number_format.number(t, with: format),
    color,
    point,
    5,
  )
}

fn support_sample_point_distance(
  first: SupportSample,
  second: SupportSample,
) -> Float {
  let #(_, _, first_point) = first
  let #(_, _, second_point) = second

  point_distance(first_point, second_point)
}

fn support_sample_angles_are_ordered(samples: List(SupportSample)) -> Bool {
  case samples {
    [] -> True
    [first, ..rest] -> {
      let angle = sample_angle(first)
      angle_is_in_range(angle)
      && support_sample_angles_increase(rest, previous: angle)
    }
  }
}

fn support_sample_angles_increase(
  samples: List(SupportSample),
  previous previous: Float,
) -> Bool {
  case samples {
    [] -> True
    [first, ..rest] -> {
      let angle = sample_angle(first)
      angle_is_in_range(angle)
      && angle >. previous
      && support_sample_angles_increase(rest, previous: angle)
    }
  }
}

fn angle_is_in_range(angle: Float) -> Bool {
  angle >=. 0.0 && angle <. 360.0
}

fn midpoint_angle(first: SupportSample, second: SupportSample) -> Float {
  let first_angle = sample_angle(first)
  let second_angle = sample_angle(second)

  case second_angle <. first_angle {
    True -> normalize_angle({ first_angle +. second_angle +. 360.0 } /. 2.0)
    False -> { first_angle +. second_angle } /. 2.0
  }
}

fn rotate_smallest_angle_to_front(
  samples: List(SupportSample),
) -> List(SupportSample) {
  case samples {
    [] -> []
    [first, ..rest] -> {
      let smallest = smallest_angle(rest, sample_angle(first))
      rotate_angle_to_front(samples, smallest, before: [])
    }
  }
}

fn smallest_angle(samples: List(SupportSample), smallest: Float) -> Float {
  case samples {
    [] -> smallest
    [first, ..rest] -> {
      let angle = sample_angle(first)
      smallest_angle(rest, float.min(smallest, angle))
    }
  }
}

fn rotate_angle_to_front(
  samples: List(SupportSample),
  angle: Float,
  before before: List(SupportSample),
) -> List(SupportSample) {
  case samples {
    [] -> list.reverse(before)
    [first, ..rest] -> {
      case sample_angle(first) == angle {
        True -> list.append([first, ..rest], list.reverse(before))
        False -> rotate_angle_to_front(rest, angle, before: [first, ..before])
      }
    }
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

fn point_distance(a: svg_path.Point, b: svg_path.Point) -> Float {
  let dx = a.x -. b.x
  let dy = a.y -. b.y

  let assert Ok(distance) = float.square_root(dx *. dx +. dy *. dy)
  distance
}
