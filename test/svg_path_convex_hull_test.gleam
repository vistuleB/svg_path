import gleam/float
import gleam/list
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

pub fn purify_support_samples_repeats_until_vacuously_resolved_test() {
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

  assert purified == []
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
