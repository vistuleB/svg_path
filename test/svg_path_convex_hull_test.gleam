import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam_community/maths
import svg_path
import svg_path/convex_hull

const tolerance = 0.000001

pub fn angle_support_finds_line_endpoint_in_direction_test() {
  let segment =
    svg_path.line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  let assert Ok(#(right_t, right_point)) =
    convex_hull.angle_support(segment, angle: 0.0)
  let assert Ok(#(left_t, left_point)) =
    convex_hull.angle_support(segment, angle: 180.0)

  assert near(right_t, 1.0)
  assert point_near(right_point, svg_path.point(10.0, 0.0))
  assert near(left_t, 0.0)
  assert point_near(left_point, svg_path.point(0.0, 0.0))
}

pub fn angle_support_breaks_horizontal_line_tie_by_min_t_test() {
  let segment =
    svg_path.line(
      start: svg_path.point(0.0, 10.0),
      end: svg_path.point(20.0, 10.0),
    )

  let assert Ok(#(t, point)) = convex_hull.angle_support(segment, angle: 90.0)

  assert near(t, 0.0)
  assert point_near(point, svg_path.point(0.0, 10.0))
}

pub fn angle_support_can_break_horizontal_line_tie_by_max_t_test() {
  let segment =
    svg_path.line(
      start: svg_path.point(0.0, 10.0),
      end: svg_path.point(20.0, 10.0),
    )

  let assert Ok(#(t, point)) =
    convex_hull.angle_support_with(
      segment,
      angle: 90.0,
      options: convex_hull.AngleSupportOptions(
        samples: 100,
        tolerance: 0.000000001,
        max_iterations: 100,
        tie_break: convex_hull.MaxT,
      ),
    )

  assert near(t, 1.0)
  assert point_near(point, svg_path.point(20.0, 10.0))
}

pub fn angle_support_breaks_vertical_line_tie_by_min_t_test() {
  let segment =
    svg_path.line(
      start: svg_path.point(10.0, 0.0),
      end: svg_path.point(10.0, 20.0),
    )

  let assert Ok(#(t, point)) = convex_hull.angle_support(segment, angle: 0.0)

  assert near(t, 0.0)
  assert point_near(point, svg_path.point(10.0, 0.0))
}

pub fn angle_support_finds_stem_rightmost_point_test() {
  let assert Ok(#(t, point)) =
    convex_hull.angle_support(convex_hull.stem(), angle: 0.0)

  assert near(t, 1.0)
  assert point_near(point, svg_path.point(95.0, 30.0))
}

pub fn angle_support_rejects_invalid_options_test() {
  assert convex_hull.angle_support_with(
      convex_hull.stem(),
      angle: 0.0,
      options: convex_hull.AngleSupportOptions(
        samples: 0,
        tolerance: 0.000000001,
        max_iterations: 100,
        tie_break: convex_hull.MinT,
      ),
    )
    == Error(svg_path.InvalidMinimizeSamples(0))
}

pub fn support_sample_pair_reports_t_close_points_close_test() {
  let pair =
    convex_hull.support_sample_pair(
      #(0.0, 0.0, svg_path.point(0.0, 0.0)),
      #(1.0, 0.5, svg_path.point(3.0, 4.0)),
      distance_tolerance: 5.0,
      t_tolerance: 1.0,
    )

  assert pair == convex_hull.TClosePointsClose(0.5, 5.0)
}

pub fn support_sample_pair_reports_t_close_points_far_test() {
  let pair =
    convex_hull.support_sample_pair(
      #(0.0, 0.4, svg_path.point(0.0, 0.0)),
      #(1.0, 0.45, svg_path.point(10.0, 0.0)),
      distance_tolerance: 1.0,
      t_tolerance: 0.1,
    )

  let assert convex_hull.TClosePointsFar(distance) = pair
  assert near(distance, 0.05)
}

pub fn support_sample_pair_reports_t_far_even_when_points_are_close_test() {
  let pair =
    convex_hull.support_sample_pair(
      #(0.0, 0.0, svg_path.point(0.0, 0.0)),
      #(1.0, 0.5, svg_path.point(0.5, 0.0)),
      distance_tolerance: 1.0,
      t_tolerance: 0.1,
    )

  assert pair == convex_hull.TFar
}

pub fn support_sample_pair_reports_t_far_points_far_test() {
  let pair =
    convex_hull.support_sample_pair(
      #(0.0, 0.0, svg_path.point(0.0, 0.0)),
      #(1.0, 0.5, svg_path.point(10.0, 0.0)),
      distance_tolerance: 1.0,
      t_tolerance: 0.1,
    )

  assert pair == convex_hull.TFar
}

pub fn sample_pair_contextually_refined_accepts_t_close_middle_test() {
  assert convex_hull.sample_pair_contextually_refined(
    convex_hull.TFar,
    convex_hull.TClosePointsFar(0.02),
    convex_hull.TFar,
  )
}

pub fn sample_pair_contextually_refined_accepts_far_between_close_point_pairs_test() {
  assert convex_hull.sample_pair_contextually_refined(
    convex_hull.TClosePointsClose(0.02, 0.5),
    convex_hull.TFar,
    convex_hull.TClosePointsClose(0.02, 0.5),
  )
}

pub fn sample_pair_far_unrefined_requires_t_far_middle_without_close_context_test() {
  assert convex_hull.sample_pair_far_unrefined(
    convex_hull.TClosePointsClose(0.02, 0.5),
    convex_hull.TFar,
    convex_hull.TClosePointsFar(0.02),
  )
}

pub fn assert_ordered_support_sample_angles_accepts_in_range_increasing_angles_test() {
  convex_hull.assert_ordered_support_sample_angles([
    #(0.0, 0.0, svg_path.point(0.0, 0.0)),
    #(120.0, 0.5, svg_path.point(1.0, 0.0)),
    #(359.0, 1.0, svg_path.point(2.0, 0.0)),
  ])
}

pub fn bisect_t_far_pairs_once_inserts_midpoints_and_keeps_smallest_angle_first_test() {
  let segment =
    svg_path.line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )
  let samples = [
    #(10.0, 0.1, svg_path.point(1.0, 0.0)),
    #(20.0, 0.2, svg_path.point(2.0, 0.0)),
    #(350.0, 0.3, svg_path.point(3.0, 0.0)),
  ]

  let assert Ok(samples) =
    convex_hull.bisect_t_far_pairs_once(
      segment,
      samples: samples,
      distance_tolerance: 0.0,
      t_tolerance: 0.0,
    )

  convex_hull.assert_ordered_support_sample_angles(samples)

  let angles =
    list.map(samples, fn(sample) {
      let #(angle, _, _) = sample
      angle
    })
  let assert [a, b, c, d, e, f] = angles

  assert near(a, 0.0)
  assert near(b, 10.0)
  assert near(c, 15.0)
  assert near(d, 20.0)
  assert near(e, 185.0)
  assert near(f, 350.0)
}

pub fn refine_support_samples_once_skips_t_far_pair_between_t_close_points_close_pairs_test() {
  let segment =
    svg_path.line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )
  let samples = [
    #(0.0, 0.0, svg_path.point(0.0, 0.0)),
    #(10.0, 0.02, svg_path.point(0.1, 0.0)),
    #(20.0, 1.0, svg_path.point(0.2, 0.0)),
    #(30.0, 1.02, svg_path.point(0.3, 0.0)),
  ]

  let assert Ok(refined) =
    convex_hull.refine_support_samples_once(
      segment,
      samples: samples,
      distance_tolerance: 1.0,
      t_tolerance: 0.1,
    )

  assert list.length(refined) == list.length(samples)
}

pub fn refine_support_samples_once_adds_midpoint_for_far_unrefined_pair_test() {
  let segment =
    svg_path.line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )
  let samples = [
    #(0.0, 0.0, svg_path.point(0.0, 0.0)),
    #(10.0, 0.5, svg_path.point(0.5, 0.0)),
    #(20.0, 1.0, svg_path.point(20.0, 0.0)),
    #(30.0, 1.5, svg_path.point(40.0, 0.0)),
  ]

  let assert Ok(refined) =
    convex_hull.refine_support_samples_once(
      segment,
      samples: samples,
      distance_tolerance: 1.0,
      t_tolerance: 0.1,
    )

  assert contains_angle(refined, 15.0)
  convex_hull.assert_ordered_support_sample_angles(refined)
}

pub fn far_unrefined_pairs_include_neighbor_point_distances_test() {
  let samples = [
    #(0.0, 0.0, svg_path.point(0.0, 0.0)),
    #(10.0, 0.5, svg_path.point(0.5, 0.0)),
    #(20.0, 1.0, svg_path.point(20.0, 0.0)),
    #(30.0, 1.5, svg_path.point(40.0, 0.0)),
  ]

  let pairs =
    convex_hull.far_unrefined_pairs(
      samples,
      distance_tolerance: 1.0,
      t_tolerance: 0.1,
    )

  assert list.any(pairs, fn(pair) {
    let #(first, second, left_point_distance, right_point_distance) = pair
    let #(first_angle, _, _) = first
    let #(second_angle, _, _) = second

    near(first_angle, 10.0)
    && near(second_angle, 20.0)
    && near(left_point_distance, 0.5)
    && near(right_point_distance, 20.0)
  })
}

pub fn first_iteration_without_refinement_returns_zero_when_no_refinement_occurs_test() {
  let segment =
    svg_path.line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )
  let samples = [
    #(0.0, 0.0, svg_path.point(0.0, 0.0)),
    #(10.0, 0.02, svg_path.point(0.1, 0.0)),
    #(20.0, 0.04, svg_path.point(0.2, 0.0)),
    #(30.0, 0.06, svg_path.point(0.3, 0.0)),
  ]

  assert convex_hull.first_iteration_without_refinement(
      segment,
      samples: samples,
      distance_tolerance: 1.0,
      t_tolerance: 0.1,
      max_iterations: 100,
    )
    == Ok(0)
}

pub fn first_iteration_without_refinement_errors_at_max_iterations_test() {
  let segment =
    svg_path.line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )
  let samples = [
    #(0.0, 0.0, svg_path.point(0.0, 0.0)),
    #(10.0, 0.5, svg_path.point(0.5, 0.0)),
    #(20.0, 1.0, svg_path.point(20.0, 0.0)),
    #(30.0, 1.5, svg_path.point(40.0, 0.0)),
  ]

  assert convex_hull.first_iteration_without_refinement(
      segment,
      samples: samples,
      distance_tolerance: 1.0,
      t_tolerance: 0.1,
      max_iterations: 0,
    )
    == Error(convex_hull.RefinementReachedMaxIterations(0))
}

pub fn purify_support_samples_once_removes_first_sample_when_context_stays_resolved_test() {
  let samples = [
    #(0.0, 0.0, svg_path.point(0.0, 0.0)),
    #(10.0, 0.02, svg_path.point(0.1, 0.0)),
    #(20.0, 0.04, svg_path.point(0.2, 0.0)),
    #(30.0, 0.06, svg_path.point(0.3, 0.0)),
  ]

  let purified =
    convex_hull.purify_support_samples_once(
      samples,
      distance_tolerance: 1.0,
      t_tolerance: 0.1,
    )

  assert list.length(purified) == list.length(samples) - 1
  let assert [first, ..] = purified
  let #(angle, _, _) = first
  assert near(angle, 10.0)
}

pub fn purify_support_samples_once_removes_adjacent_duplicate_t_values_test() {
  let samples = [
    #(0.0, 0.0, svg_path.point(0.0, 0.0)),
    #(10.0, 0.0, svg_path.point(0.0, 0.0)),
    #(20.0, 0.5, svg_path.point(0.5, 0.0)),
    #(30.0, 1.0, svg_path.point(1.0, 0.0)),
    #(40.0, 0.0, svg_path.point(0.0, 0.0)),
  ]

  let purified =
    convex_hull.purify_support_samples_once(
      samples,
      distance_tolerance: 0.0,
      t_tolerance: 0.0,
    )

  assert list.map(purified, fn(sample) {
      let #(angle, _, _) = sample
      angle
    })
    == [20.0, 30.0, 40.0]
}

pub fn purify_support_samples_keeps_minimum_two_samples_test() {
  let samples = [
    #(0.0, 0.0, svg_path.point(0.0, 0.0)),
    #(10.0, 0.02, svg_path.point(0.1, 0.0)),
    #(20.0, 0.04, svg_path.point(0.2, 0.0)),
    #(30.0, 0.06, svg_path.point(0.3, 0.0)),
  ]

  let assert Ok(purified) =
    convex_hull.purify_support_samples(
      samples,
      distance_tolerance: 1.0,
      t_tolerance: 0.1,
      max_iterations: 100,
    )

  assert list.length(purified) == 2
}

pub fn purify_support_samples_keeps_line_endpoint_samples_test() {
  let samples = [
    #(0.0, 1.0, svg_path.point(120.0, 15.0)),
    #(1.0, 1.0, svg_path.point(120.0, 15.0)),
    #(2.0, 1.0, svg_path.point(120.0, 15.0)),
    #(181.0, 0.0, svg_path.point(10.0, 85.0)),
    #(182.0, 0.0, svg_path.point(10.0, 85.0)),
  ]

  let assert Ok(purified) =
    convex_hull.purify_support_samples(
      samples,
      distance_tolerance: 0.1,
      t_tolerance: 0.05,
      max_iterations: 100,
    )

  assert list.length(purified) == 2
}

pub fn tiny_line_under_distance_tolerance_still_completes_hull_pipeline_test() {
  let segment =
    svg_path.line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(0.00001, 0.0),
    )
  let assert Ok(samples) = initial_support_samples(segment)
  let assert Ok(refined) =
    refine_until_stable(
      segment,
      samples,
      distance_tolerance: 0.001,
      t_tolerance: 0.05,
      max_iterations: 100,
    )
  let assert Ok(purified) =
    convex_hull.purify_support_samples(
      refined,
      distance_tolerance: 0.001,
      t_tolerance: 0.05,
      max_iterations: 100,
    )
  let assert Ok(pieces) =
    convex_hull.support_samples_to_hull_pieces(purified, t_tolerance: 0.05)

  assert list.length(samples) == 100
  assert list.length(refined) == 100
  assert list.length(purified) == 2
  assert list.length(pieces) == 2
}

pub fn debug_specimen_hulls_survive_strict_subpath_constructor_test() {
  assert list.all(debug_specimens(), fn(specimen) {
    let #(_, segment) = specimen

    case convex_hull.hull_subpath(segment) {
      Ok(_) -> True
      Error(_) -> False
    }
  })
}

pub fn debug_specimen_hulls_have_at_least_two_segments_test() {
  assert list.all(debug_specimens(), fn(specimen) {
    let #(_, segment) = specimen

    case convex_hull.hull_subpath(segment) {
      Ok(subpath) -> list.length(svg_path.segments(subpath)) >= 2
      Error(_) -> False
    }
  })
}

pub fn debug_specimen_hull_derivative_angles_are_nondecreasing_test() {
  assert list.all(debug_specimens(), fn(specimen) {
    let #(_, segment) = specimen

    case convex_hull.hull_subpath(segment) {
      Ok(subpath) ->
        subpath
        |> svg_path.segments
        |> segment_derivative_angles
        |> rotate_to_smallest_positive_angle
        |> unwrap_angles
        |> nondecreasing(tolerance: 0.0)

      Error(_) -> False
    }
  })
}

pub fn debug_specimen_hull_support_matches_original_at_10_degree_steps_test() {
  assert list.all(debug_specimens(), fn(specimen) {
    let #(_, segment) = specimen

    case convex_hull.hull_subpath(segment) {
      Ok(hull) ->
        multiples_of_10_degrees()
        |> list.all(fn(angle) {
          case
            original_support_value(segment, angle),
            hull_support_value(svg_path.segments(hull), angle)
          {
            Ok(original), Ok(hull) -> near(original, hull)
            _, _ -> False
          }
        })

      Error(_) -> False
    }
  })
}

pub fn purify_support_samples_errors_at_max_iterations_test() {
  let samples = [
    #(0.0, 0.0, svg_path.point(0.0, 0.0)),
    #(10.0, 0.02, svg_path.point(0.1, 0.0)),
    #(20.0, 0.04, svg_path.point(0.2, 0.0)),
    #(30.0, 0.06, svg_path.point(0.3, 0.0)),
  ]

  assert convex_hull.purify_support_samples(
      samples,
      distance_tolerance: 1.0,
      t_tolerance: 0.1,
      max_iterations: 0,
    )
    == Error(convex_hull.PurificationReachedMaxIterations(0))
}

pub fn assert_no_adjacent_duplicate_t_values_accepts_distinct_neighbors_test() {
  convex_hull.assert_no_adjacent_duplicate_t_values([
    #(0.0, 0.0, svg_path.point(0.0, 0.0)),
    #(10.0, 0.02, svg_path.point(1.0, 0.0)),
    #(20.0, 0.04, svg_path.point(2.0, 0.0)),
    #(30.0, 0.5, svg_path.point(3.0, 0.0)),
  ])
}

pub fn support_samples_to_hull_pieces_classifies_lines_and_globbed_curves_test() {
  let samples = [
    #(0.0, 0.0, svg_path.point(0.0, 0.0)),
    #(10.0, 0.02, svg_path.point(1.0, 0.0)),
    #(20.0, 0.04, svg_path.point(2.0, 0.0)),
    #(30.0, 0.5, svg_path.point(3.0, 0.0)),
  ]

  let assert Ok(pieces) =
    convex_hull.support_samples_to_hull_pieces(samples, t_tolerance: 0.05)

  assert pieces
    == [
      convex_hull.HullCurve(0.0, 0.04),
      convex_hull.HullLine(0.04, 0.5),
      convex_hull.HullLine(0.5, 0.0),
    ]
}

pub fn support_samples_to_hull_pieces_rejects_consecutive_curves_after_globbing_test() {
  let samples = [
    #(0.0, 0.0, svg_path.point(0.0, 0.0)),
    #(10.0, 0.02, svg_path.point(1.0, 0.0)),
    #(20.0, 0.01, svg_path.point(2.0, 0.0)),
    #(30.0, 0.03, svg_path.point(3.0, 0.0)),
  ]

  assert convex_hull.support_samples_to_hull_pieces(samples, t_tolerance: 0.05)
    == Error(convex_hull.ConsecutiveCurves)
}

pub fn drawing_svg_delegates_to_segment_drawing_svg_test() {
  let view_box =
    svg_path.BoundingBox(
      min: svg_path.point(-30.0, -30.0),
      max: svg_path.point(200.0, 115.0),
    )

  assert convex_hull.drawing_svg()
    == convex_hull.segment_drawing_svg(convex_hull.stem(), view_box:)
}

pub fn segment_drawing_svg_with_padding_uses_segment_bounding_box_test() {
  let segment =
    svg_path.line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  let assert Ok(svg) =
    convex_hull.segment_drawing_svg_with_padding(segment, padding: 5.0)

  assert string.contains(svg, "viewBox=\"-5 -5 20 10\"")
  assert string.contains(svg, "M 0 0 H 10")
}

fn initial_support_samples(
  segment: svg_path.Segment,
) -> Result(List(convex_hull.SupportSample), svg_path.Error) {
  int.range(from: 0, to: 100, with: [], run: fn(samples, i) { [i, ..samples] })
  |> list.reverse
  |> list.try_map(fn(i) {
    let angle = int.to_float(i) *. 360.0 /. 100.0
    convex_hull.support_sample(segment, angle:)
  })
}

fn refine_until_stable(
  segment: svg_path.Segment,
  samples: List(convex_hull.SupportSample),
  distance_tolerance distance_tolerance: Float,
  t_tolerance t_tolerance: Float,
  max_iterations max_iterations: Int,
) -> Result(List(convex_hull.SupportSample), svg_path.Error) {
  case max_iterations <= 0 {
    True -> Ok(samples)
    False -> {
      use refined <- result.try(convex_hull.refine_support_samples_once(
        segment,
        samples: samples,
        distance_tolerance: distance_tolerance,
        t_tolerance: t_tolerance,
      ))

      case list.length(refined) == list.length(samples) {
        True -> Ok(refined)
        False ->
          refine_until_stable(
            segment,
            refined,
            distance_tolerance: distance_tolerance,
            t_tolerance: t_tolerance,
            max_iterations: max_iterations - 1,
          )
      }
    }
  }
}

fn debug_specimens() -> List(#(String, svg_path.Segment)) {
  list.append(curve_and_line_specimens(), arc_specimens())
}

fn curve_and_line_specimens() -> List(#(String, svg_path.Segment)) {
  [
    #("stem", convex_hull.stem()),
    #("horseshoe", horseshoe()),
    #("horseshoe_wide", horseshoe_wide()),
    #("diagonal_line", diagonal_line()),
    #("reverse_diagonal_line", reverse_diagonal_line()),
    #("horizontal_line", horizontal_line()),
    #("vertical_line", vertical_line()),
    #("snake_cubic", snake_cubic()),
    #("fish_cubic", fish_cubic()),
    #("del_cubic", del_cubic()),
    #("flourish_cubic", flourish_cubic()),
    #("left_hook_cubic", left_hook_cubic()),
  ]
}

fn arc_specimens() -> List(#(String, svg_path.Segment)) {
  [
    #("half_circle_arc", half_circle_arc(sweep: True)),
    #("half_circle_arc_reverse", half_circle_arc(sweep: False)),
    #("rotated_arc", rotated_arc(sweep: True)),
    #("rotated_arc_reverse", rotated_arc(sweep: False)),
    #("large_arc", large_arc(sweep: True)),
    #("large_arc_reverse", large_arc(sweep: False)),
  ]
}

fn horseshoe() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(20.0, 80.0),
    control1: svg_path.point(20.0, 5.0),
    control2: svg_path.point(100.0, 5.0),
    end: svg_path.point(100.0, 80.0),
  )
}

fn horseshoe_wide() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(20.0, 90.0),
    control1: svg_path.point(-25.0, 0.0),
    control2: svg_path.point(145.0, 0.0),
    end: svg_path.point(100.0, 90.0),
  )
}

fn diagonal_line() -> svg_path.Segment {
  svg_path.line(
    start: svg_path.point(10.0, 85.0),
    end: svg_path.point(120.0, 15.0),
  )
}

fn reverse_diagonal_line() -> svg_path.Segment {
  svg_path.line(
    start: svg_path.point(10.0, 15.0),
    end: svg_path.point(120.0, 85.0),
  )
}

fn horizontal_line() -> svg_path.Segment {
  svg_path.line(
    start: svg_path.point(10.0, 50.0),
    end: svg_path.point(120.0, 50.0),
  )
}

fn vertical_line() -> svg_path.Segment {
  svg_path.line(
    start: svg_path.point(65.0, 10.0),
    end: svg_path.point(65.0, 90.0),
  )
}

fn snake_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(15.0, 55.0),
    control1: svg_path.point(135.0, 0.0),
    control2: svg_path.point(-20.0, 110.0),
    end: svg_path.point(105.0, 55.0),
  )
}

fn fish_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(25.0, 40.0),
    control1: svg_path.point(155.0, 100.0),
    control2: svg_path.point(155.0, 10.0),
    end: svg_path.point(25.0, 70.0),
  )
}

fn del_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(100.0, 20.0),
    control1: svg_path.point(120.0, 60.0),
    control2: svg_path.point(0.0, 140.0),
    end: svg_path.point(100.0, 40.0),
  )
}

fn flourish_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(100.0, 20.0),
    control1: svg_path.point(120.0, 60.0),
    control2: svg_path.point(20.0, 140.0),
    end: svg_path.point(120.0, 40.0),
  )
}

fn left_hook_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(120.0, 120.0),
    control1: svg_path.point(121.0, 120.0),
    control2: svg_path.point(20.0, 20.0),
    end: svg_path.point(120.0, 20.0),
  )
}

fn half_circle_arc(sweep sweep: Bool) -> svg_path.Segment {
  svg_path.arc(
    start: svg_path.point(20.0, 80.0),
    radius: svg_path.point(40.0, 40.0),
    x_axis_rotation: 0.0,
    large_arc: False,
    sweep: sweep,
    end: svg_path.point(100.0, 80.0),
  )
}

fn rotated_arc(sweep sweep: Bool) -> svg_path.Segment {
  svg_path.arc(
    start: svg_path.point(30.0, 80.0),
    radius: svg_path.point(55.0, 25.0),
    x_axis_rotation: 30.0,
    large_arc: False,
    sweep: sweep,
    end: svg_path.point(120.0, 40.0),
  )
}

fn large_arc(sweep sweep: Bool) -> svg_path.Segment {
  svg_path.arc(
    start: svg_path.point(20.0, 70.0),
    radius: svg_path.point(50.0, 35.0),
    x_axis_rotation: 0.0,
    large_arc: True,
    sweep: sweep,
    end: svg_path.point(100.0, 70.0),
  )
}

fn segment_derivative_angles(segments: List(svg_path.Segment)) -> List(Float) {
  segments
  |> list.flat_map(fn(segment) {
    [
      segment_derivative_angle(segment, at: 0.1),
      segment_derivative_angle(segment, at: 0.9),
    ]
  })
}

fn segment_derivative_angle(segment: svg_path.Segment, at t: Float) -> Float {
  let assert Ok(derivative) = svg_path.segment_derivative(segment, at: t)

  maths.atan2(derivative.y, derivative.x)
  |> radians_to_degrees
  |> normalize_degrees
}

fn radians_to_degrees(radians: Float) -> Float {
  radians *. 180.0 /. maths.pi()
}

fn normalize_degrees(degrees: Float) -> Float {
  case degrees <. 0.0 {
    True -> degrees +. 360.0
    False ->
      case degrees >=. 360.0 {
        True -> degrees -. 360.0
        False -> degrees
      }
  }
}

fn rotate_to_smallest_positive_angle(angles: List(Float)) -> List(Float) {
  case smallest_positive_angle_index(angles, 0, -1, 0.0) {
    -1 -> angles
    index -> rotate_list(angles, at: index)
  }
}

fn smallest_positive_angle_index(
  angles: List(Float),
  position: Int,
  best_index: Int,
  best_angle: Float,
) -> Int {
  case angles {
    [] -> best_index
    [angle, ..rest]
      if angle >. 0.0 && { best_index < 0 || angle <. best_angle }
    -> smallest_positive_angle_index(rest, position + 1, position, angle)
    [_, ..rest] ->
      smallest_positive_angle_index(rest, position + 1, best_index, best_angle)
  }
}

fn unwrap_angles(angles: List(Float)) -> List(Float) {
  case angles {
    [] -> []
    [first, ..rest] ->
      unwrap_angles_loop(rest, previous: first, offset: 0.0, unwrapped: [first])
  }
}

fn unwrap_angles_loop(
  angles: List(Float),
  previous previous: Float,
  offset offset: Float,
  unwrapped unwrapped: List(Float),
) -> List(Float) {
  case angles {
    [] -> list.reverse(unwrapped)
    [angle, ..rest] -> {
      let offset = case angle +. offset <. previous {
        True -> offset +. 360.0
        False -> offset
      }
      let angle = angle +. offset

      unwrap_angles_loop(rest, previous: angle, offset: offset, unwrapped: [
        angle,
        ..unwrapped
      ])
    }
  }
}

fn nondecreasing(values: List(Float), tolerance tolerance: Float) -> Bool {
  case values {
    [] | [_] -> True
    [first, second, ..rest] ->
      first <=. second +. tolerance
      && nondecreasing([second, ..rest], tolerance: tolerance)
  }
}

fn rotate_list(items: List(a), at index: Int) -> List(a) {
  list.append(list.drop(items, index), take(items, index))
}

fn take(items: List(a), count: Int) -> List(a) {
  take_loop(items, count, [])
}

fn take_loop(items: List(a), count: Int, taken: List(a)) -> List(a) {
  case count <= 0 {
    True -> list.reverse(taken)
    False ->
      case items {
        [] -> list.reverse(taken)
        [first, ..rest] -> take_loop(rest, count - 1, [first, ..taken])
      }
  }
}

fn multiples_of_10_degrees() -> List(Float) {
  int.range(from: 0, to: 35, with: [], run: fn(angles, i) { [i, ..angles] })
  |> list.reverse
  |> list.map(fn(i) { int.to_float(i) *. 10.0 })
}

fn original_support_value(
  segment: svg_path.Segment,
  angle: Float,
) -> Result(Float, svg_path.Error) {
  use #(_, point) <- result.try(convex_hull.angle_support(segment, angle:))

  Ok(support_value(point, angle: angle))
}

fn hull_support_value(
  segments: List(svg_path.Segment),
  angle: Float,
) -> Result(Float, svg_path.Error) {
  use supports <- result.try(
    list.try_map(segments, fn(segment) {
      use #(_, point) <- result.try(convex_hull.angle_support(segment, angle:))

      Ok(support_value(point, angle: angle))
    }),
  )

  Ok(maximum(supports))
}

fn support_value(point: svg_path.Point, angle angle: Float) -> Float {
  let radians = angle *. maths.pi() /. 180.0

  point.x *. maths.cos(radians) +. point.y *. maths.sin(radians)
}

fn maximum(values: List(Float)) -> Float {
  let assert [first, ..rest] = values

  list.fold(rest, first, fn(max, value) {
    case value >. max {
      True -> value
      False -> max
    }
  })
}

fn point_near(a: svg_path.Point, b: svg_path.Point) -> Bool {
  near(a.x, b.x) && near(a.y, b.y)
}

fn contains_angle(
  samples: List(convex_hull.SupportSample),
  angle: Float,
) -> Bool {
  list.any(samples, fn(sample) {
    let #(sample_angle, _, _) = sample
    near(sample_angle, angle)
  })
}

fn near(a: Float, b: Float) -> Bool {
  float.absolute_value(a -. b) <. tolerance
}
