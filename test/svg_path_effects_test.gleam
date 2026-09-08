import gleam/float
import gleam/list
import svg_path
import svg_path/degeneracy
import svg_path/effects

const tolerance = 0.000001

pub fn leave_corner_preserves_untrimmed_zero_length_segments_test() {
  let options = effects.default_round_corner_options()
  let options =
    effects.RoundCornerOptions(..options, failure: effects.LeaveCorner)
  list.each(
    [
      [
        svg_path.Point(0.0, 0.0),
        svg_path.Point(0.0, 0.0),
        svg_path.Point(10.0, 0.0),
        svg_path.Point(10.0, 10.0),
      ],
      [
        svg_path.Point(0.0, 0.0),
        svg_path.Point(10.0, 0.0),
        svg_path.Point(10.0, 0.0),
        svg_path.Point(10.0, 10.0),
      ],
      [
        svg_path.Point(0.0, 0.0),
        svg_path.Point(10.0, 0.0),
        svg_path.Point(10.0, 10.0),
        svg_path.Point(10.0, 10.0),
      ],
    ],
    fn(points) {
      let source = svg_path.subpath_assert_polyline(points)
      let assert Ok(rounded) =
        effects.round_subpath_corners_with(source, 1.0, options)
      assert svg_path.subpath_start(rounded) == svg_path.subpath_start(source)
      assert svg_path.subpath_end(rounded) == svg_path.subpath_end(source)
      let original_zero =
        svg_path.subpath_segments(source)
        |> list.filter(fn(s) {
          svg_path.segment_start(s) == svg_path.segment_end(s)
        })
      let remaining_zero =
        svg_path.subpath_segments(rounded)
        |> list.filter(fn(s) {
          svg_path.segment_start(s) == svg_path.segment_end(s)
        })
      assert remaining_zero == original_zero
    },
  )
}

pub fn normalize_degenerate_segments_accepts_zero_tolerance_test() {
  let subpath =
    svg_path.segment_as_subpath(svg_path.Line(
      svg_path.Point(0.0, 0.0),
      svg_path.Point(1.0, 0.0),
    ))

  let assert Ok(normalized) =
    degeneracy.normalize_degenerate_segments(subpath, 0.0)

  assert svg_path.subpath_segments(normalized)
    == [svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(1.0, 0.0))]
}

pub fn normalize_degenerate_segments_rejects_negative_tolerance_test() {
  let subpath =
    svg_path.segment_as_subpath(svg_path.Line(
      svg_path.Point(0.0, 0.0),
      svg_path.Point(1.0, 0.0),
    ))

  assert degeneracy.normalize_degenerate_segments(subpath, -0.000001)
    == Error(degeneracy.InvalidTolerance(-0.000001))
}

pub fn normalize_degenerate_segments_with_zero_tolerance_collapses_exact_collinear_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(1.0, 0.0)),
      svg_path.Line(svg_path.Point(1.0, 0.0), svg_path.Point(2.0, 0.0)),
      svg_path.Line(svg_path.Point(2.0, 0.0), svg_path.Point(3.0, 0.0)),
    ])

  let assert Ok(normalized) =
    degeneracy.normalize_degenerate_segments(subpath, 0.0)

  assert svg_path.subpath_segments(normalized)
    == [svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(3.0, 0.0))]
}

pub fn normalize_degenerate_segments_with_zero_tolerance_keeps_near_collinear_lines_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(1.0, 0.0)),
      svg_path.Line(svg_path.Point(1.0, 0.0), svg_path.Point(2.0, 1.0e-9)),
      svg_path.Line(svg_path.Point(2.0, 1.0e-9), svg_path.Point(3.0, 0.0)),
    ])

  let assert Ok(normalized) =
    degeneracy.normalize_degenerate_segments(subpath, 0.0)

  assert svg_path.subpath_segments(normalized)
    == svg_path.subpath_segments(subpath)
}

pub fn normalize_degenerate_segments_with_zero_tolerance_collapses_exact_collinear_quadratic_test() {
  let curve =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.0),
      control: svg_path.Point(3.0, 3.0),
      end: svg_path.Point(6.0, 6.0),
    )
  let subpath = svg_path.subpath_assert([curve])

  let assert Ok(normalized) =
    degeneracy.normalize_degenerate_segments(subpath, 0.0)

  assert svg_path.subpath_segments(normalized)
    == [svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(6.0, 6.0))]
}

pub fn normalize_degenerate_segments_with_zero_tolerance_keeps_near_collinear_quadratic_test() {
  let curve =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.0),
      control: svg_path.Point(3.0, 3.0000001),
      end: svg_path.Point(6.0, 6.0),
    )
  let subpath = svg_path.subpath_assert([curve])

  let assert Ok(strict) = degeneracy.normalize_degenerate_segments(subpath, 0.0)

  assert svg_path.subpath_segments(strict) == [curve]
  assert has_quadratic(svg_path.subpath_segments(strict))

  let assert Ok(loose) =
    degeneracy.normalize_degenerate_segments(subpath, 0.000001)

  assert svg_path.subpath_segments(loose)
    == [svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(6.0, 6.0))]
}

pub fn normalize_degenerate_segments_with_zero_tolerance_collapses_exact_collinear_cubic_test() {
  let curve =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(1.0, 1.0),
      control2: svg_path.Point(2.0, 2.0),
      end: svg_path.Point(3.0, 3.0),
    )
  let subpath = svg_path.subpath_assert([curve])

  let assert Ok(normalized) =
    degeneracy.normalize_degenerate_segments(subpath, 0.0)

  assert svg_path.subpath_segments(normalized)
    == [svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(3.0, 3.0))]
}

pub fn normalize_degenerate_segments_with_zero_tolerance_collapses_horizontal_cubic_test() {
  let curve =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(1.0, 0.0),
      control2: svg_path.Point(2.0, 0.0),
      end: svg_path.Point(3.0, 0.0),
    )
  let subpath = svg_path.subpath_assert([curve])

  let assert Ok(normalized) =
    degeneracy.normalize_degenerate_segments(subpath, 0.0)

  assert svg_path.subpath_segments(normalized)
    == [svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(3.0, 0.0))]
}

pub fn normalize_degenerate_segments_with_zero_tolerance_keeps_near_collinear_cubic_test() {
  let curve =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(1.0, 1.0),
      control2: svg_path.Point(2.0, 2.0000001),
      end: svg_path.Point(3.0, 3.0),
    )
  let subpath = svg_path.subpath_assert([curve])

  let assert Ok(strict) = degeneracy.normalize_degenerate_segments(subpath, 0.0)

  assert svg_path.subpath_segments(strict) == [curve]
  assert has_cubic(svg_path.subpath_segments(strict))

  let assert Ok(loose) =
    degeneracy.normalize_degenerate_segments(subpath, 0.000001)

  assert svg_path.subpath_segments(loose)
    == [svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(3.0, 3.0))]
}

pub fn normalize_degenerate_segments_with_zero_tolerance_collapses_stretched_cubic_test() {
  let curve =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(2.0, 1.0),
      control2: svg_path.Point(4.0, 2.0),
      end: svg_path.Point(6.0, 3.0),
    )
  let subpath = svg_path.subpath_assert([curve])

  let assert Ok(normalized) =
    degeneracy.normalize_degenerate_segments(subpath, 0.0)

  assert svg_path.subpath_segments(normalized)
    == [svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(6.0, 3.0))]
}

pub fn round_corners_rounds_closed_square_test() {
  let square =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
      svg_path.Point(0.0, 10.0),
    ])

  let assert Ok(rounded) = effects.round_subpath_corners(square, radius: 2.0)
  let segments = svg_path.subpath_segments(rounded)

  assert svg_path.subpath_is_closed(rounded)
  assert list.length(segments) == 8
  assert arc_count(segments) == 4
  assert has_line(segments, svg_path.Point(2.0, 0.0), svg_path.Point(8.0, 0.0))
  assert has_line(
    segments,
    svg_path.Point(10.0, 2.0),
    svg_path.Point(10.0, 8.0),
  )
}

pub fn round_corners_rounds_open_polyline_interior_join_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
    ])

  let assert Ok(rounded) = effects.round_subpath_corners(subpath, radius: 2.0)
  let segments = svg_path.subpath_segments(rounded)

  assert !svg_path.subpath_is_closed(rounded)
  assert list.length(segments) == 3
  assert has_line(segments, svg_path.Point(0.0, 0.0), svg_path.Point(8.0, 0.0))
  assert has_arc(segments, svg_path.Point(8.0, 0.0), svg_path.Point(10.0, 2.0))
  assert has_line(
    segments,
    svg_path.Point(10.0, 2.0),
    svg_path.Point(10.0, 10.0),
  )
}

pub fn angular_tolerance_controls_corner_eligibility_in_degrees_test() {
  let subpath = right_angle_subpath()
  let skipped_options =
    effects.RoundCornerOptions(
      ..effects.default_round_corner_options(),
      failure: effects.LeaveCorner,
      angular_tolerance: 90.0,
    )
  let rounded_options =
    effects.RoundCornerOptions(..skipped_options, angular_tolerance: 89.999)

  assert effects.round_subpath_corners_with(
      subpath,
      radius: 2.0,
      options: skipped_options,
    )
    == Ok(subpath)
  let assert Ok(rounded) =
    effects.round_subpath_corners_with(
      subpath,
      radius: 2.0,
      options: rounded_options,
    )
  assert arc_count(svg_path.subpath_segments(rounded)) == 1
}

pub fn distance_tolerance_controls_minimum_trim_distance_test() {
  let subpath = right_angle_subpath()
  let skipped_options =
    effects.RoundCornerOptions(
      ..effects.default_round_corner_options(),
      failure: effects.LeaveCorner,
      distance_tolerance: 2.0,
    )
  let rounded_options =
    effects.RoundCornerOptions(..skipped_options, distance_tolerance: 1.999)

  assert effects.round_subpath_corners_with(
      subpath,
      radius: 2.0,
      options: skipped_options,
    )
    == Ok(subpath)
  let assert Ok(rounded) =
    effects.round_subpath_corners_with(
      subpath,
      radius: 2.0,
      options: rounded_options,
    )
  assert arc_count(svg_path.subpath_segments(rounded)) == 1
}

pub fn round_corners_supports_curve_incident_segments_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
      svg_path.QuadraticBezier(
        start: svg_path.Point(10.0, 0.0),
        control: svg_path.Point(10.0, 10.0),
        end: svg_path.Point(20.0, 10.0),
      ),
    ])

  let assert Ok(rounded) = effects.round_subpath_corners(subpath, radius: 2.0)
  let segments = svg_path.subpath_segments(rounded)

  assert list.length(segments) == 3
  assert arc_count(segments) == 1
  assert has_arc_start(segments, svg_path.Point(8.0, 0.0))
  assert has_quadratic(segments)
}

pub fn round_corners_rounds_closed_one_segment_cusp_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.CubicBezier(
        start: svg_path.Point(0.0, 0.0),
        control1: svg_path.Point(-40.0, -30.0),
        control2: svg_path.Point(-40.0, 30.0),
        end: svg_path.Point(0.0, 0.0),
      ),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)
  let options =
    effects.RoundCornerOptions(
      ..effects.default_round_corner_options(),
      failure: effects.AdaptRadius,
    )

  let assert Ok(rounded) =
    effects.round_subpath_corners_with(subpath, radius: 4.0, options:)
  let segments = svg_path.subpath_segments(rounded)

  assert svg_path.subpath_is_closed(rounded)
  assert list.length(segments) == 2
  assert arc_count(segments) == 1
  assert has_cubic(segments)
}

pub fn stretch_to_join_endpoint_policy_meets_at_midpoint_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)

  let assert Ok(subpath) =
    svg_path.subpath_with(
      [svg_path.Line(start: a, end: b), svg_path.Line(start: c, end: d)],
      policy: effects.stretch_to_join_endpoint_policy(),
    )

  assert svg_path.subpath_segments(subpath)
    == [
      svg_path.Line(start: a, end: svg_path.Point(15.0, 0.0)),
      svg_path.Line(start: svg_path.Point(15.0, 0.0), end: d),
    ]
}

pub fn stretch_to_join_endpoint_policy_closes_by_dragging_last_end_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 10.0)
  let near_a = svg_path.Point(1.0, 0.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: near_a),
    ])

  let assert Ok(closed) =
    svg_path.subpath_set_closed_with(
      subpath,
      closed: True,
      policy: effects.stretch_to_join_endpoint_policy(),
    )

  assert svg_path.subpath_is_closed(closed)
  assert svg_path.subpath_segments(closed)
    == [
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: a),
    ]
}

pub fn stretch_to_join_endpoint_policy_closes_near_loop_single_segment_test() {
  let a = svg_path.Point(0.0, 0.0)
  let near_a = svg_path.Point(0.01, 0.0)
  let subpath = svg_path.subpath_assert([svg_path.Line(start: a, end: near_a)])

  let assert Ok(closed) =
    svg_path.subpath_set_closed_with(
      subpath,
      closed: True,
      policy: effects.stretch_to_join_endpoint_policy(),
    )

  assert svg_path.subpath_is_closed(closed)
  assert svg_path.subpath_segments(closed) == [svg_path.Line(start: a, end: a)]
}

pub fn round_corners_errors_when_radius_does_not_fit_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
    ])

  assert effects.round_subpath_corners(subpath, radius: 20.0)
    == Error(effects.CannotRoundCorner(0))
}

pub fn round_corners_can_leave_unfittable_corner_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
    ])
  let options =
    effects.RoundCornerOptions(
      ..effects.default_round_corner_options(),
      failure: effects.LeaveCorner,
    )

  assert effects.round_subpath_corners_with(subpath, radius: 20.0, options:)
    == Ok(subpath)
}

pub fn round_corners_can_adapt_radius_to_fit_short_segments_test() {
  let square =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
      svg_path.Point(0.0, 10.0),
    ])
  let options =
    effects.RoundCornerOptions(
      ..effects.default_round_corner_options(),
      failure: effects.AdaptRadius,
    )

  let assert Ok(rounded) =
    effects.round_subpath_corners_with(square, radius: 20.0, options:)
  let segments = svg_path.subpath_segments(rounded)

  assert svg_path.subpath_is_closed(rounded)
  assert list.length(segments) == 8
  assert arc_count(segments) == 4
  assert all_arc_radii_near(segments, expected: 4.999999)
}

pub fn round_corners_adapts_tight_inward_spiral_test() {
  let spiral =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(8.0, 0.0),
      svg_path.Point(8.0, 8.0),
      svg_path.Point(2.0, 8.0),
      svg_path.Point(2.0, 2.0),
      svg_path.Point(6.0, 2.0),
      svg_path.Point(6.0, 6.0),
      svg_path.Point(4.0, 6.0),
      svg_path.Point(4.0, 4.0),
      svg_path.Point(4.0, 10.0),
      svg_path.Point(0.0, 10.0),
    ])
  let options =
    effects.RoundCornerOptions(
      ..effects.default_round_corner_options(),
      failure: effects.AdaptRadius,
      distance_tolerance: 1.0,
    )

  let assert Ok(rounded) =
    effects.round_subpath_corners_with(spiral, radius: 2.0, options:)
  let segments = svg_path.subpath_segments(rounded)

  assert svg_path.subpath_is_closed(rounded)
  assert arc_count(segments) == 4
  assert all_arc_radii_near(segments, expected: 2.0)
}

pub fn round_corners_accepts_zero_distance_tolerance_test() {
  let square =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(4.0, 0.0),
      svg_path.Point(4.0, 4.0),
      svg_path.Point(0.0, 4.0),
    ])
  let zero_options =
    effects.RoundCornerOptions(
      ..effects.default_round_corner_options(),
      distance_tolerance: 0.0,
    )
  let wide_options =
    effects.RoundCornerOptions(
      ..effects.default_round_corner_options(),
      distance_tolerance: 1.0,
    )

  let assert Ok(rounded) =
    effects.round_subpath_corners_with(
      square,
      radius: 1.0,
      options: zero_options,
    )
  let segments = svg_path.subpath_segments(rounded)
  assert arc_count(segments) == 4
  assert all_arc_radii_near(segments, expected: 1.0)

  assert effects.round_subpath_corners_with(
      square,
      radius: 1.0,
      options: wide_options,
    )
    == Error(effects.CannotRoundCorner(0))
}

pub fn round_corners_rejects_negative_distance_tolerance_test() {
  let square =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(4.0, 0.0),
      svg_path.Point(4.0, 4.0),
      svg_path.Point(0.0, 4.0),
    ])
  let options =
    effects.RoundCornerOptions(
      ..effects.default_round_corner_options(),
      distance_tolerance: -0.000001,
    )

  assert effects.round_subpath_corners_with(square, radius: 1.0, options:)
    == Error(effects.InvalidDistanceTolerance(-0.000001))
}

pub fn round_corners_zero_tolerance_errors_on_exact_trim_consume_test() {
  let polyline =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(4.0, 0.0),
      svg_path.Point(4.0, 4.0),
      svg_path.Point(8.0, 4.0),
    ])
  let options =
    effects.RoundCornerOptions(
      ..effects.default_round_corner_options(),
      distance_tolerance: 0.0,
    )

  assert effects.round_subpath_corners_with(polyline, radius: 2.0, options:)
    == Error(effects.CornerTrimsOverlap(1))
}

pub fn round_corners_adapt_zero_tolerance_rejects_exact_center_consume_test() {
  let spiral =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(8.0, 0.0),
      svg_path.Point(8.0, 8.0),
      svg_path.Point(2.0, 8.0),
      svg_path.Point(2.0, 2.0),
      svg_path.Point(6.0, 2.0),
      svg_path.Point(6.0, 6.0),
      svg_path.Point(4.0, 6.0),
      svg_path.Point(4.0, 4.0),
      svg_path.Point(4.0, 10.0),
      svg_path.Point(0.0, 10.0),
    ])
  let options =
    effects.RoundCornerOptions(
      ..effects.default_round_corner_options(),
      failure: effects.AdaptRadius,
      distance_tolerance: 0.0,
    )

  assert effects.round_subpath_corners_with(spiral, radius: 2.0, options:)
    == Error(effects.CornerTrimsOverlap(4))
}

pub fn normalize_degenerate_segments_replaces_degenerate_segments_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.QuadraticBezier(
        start: svg_path.Point(0.0, 0.0),
        control: svg_path.Point(10.0, 0.0),
        end: svg_path.Point(0.0, 0.0),
      ),
    ])

  let assert Ok(cleaned) =
    effects.normalize_degenerate_segments(subpath, tolerance: 0.001)
  assert list.length(svg_path.subpath_segments(cleaned)) == 2
}

pub fn normalize_degenerate_segments_preserves_closed_one_line_replacement_test() {
  let open =
    svg_path.subpath_assert([
      svg_path.QuadraticBezier(
        start: svg_path.Point(0.0, 0.0),
        control: svg_path.Point(5.0, 0.0001),
        end: svg_path.Point(10.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(10.0, 0.0),
        end: svg_path.Point(0.0, 10.0),
      ),
      svg_path.Line(
        start: svg_path.Point(0.0, 10.0),
        end: svg_path.Point(0.0, 0.0),
      ),
    ])
  let subpath = svg_path.subpath_assert_set_closed(open, closed: True)

  let assert Ok(cleaned) =
    effects.normalize_degenerate_segments(subpath, tolerance: 0.001)
  assert svg_path.subpath_is_closed(cleaned)
  assert list.length(svg_path.subpath_segments(cleaned)) == 3
  assert has_line(
    svg_path.subpath_segments(cleaned),
    svg_path.Point(0.0, 0.0),
    svg_path.Point(10.0, 0.0),
  )
}

pub fn normalize_degenerate_segments_coalesces_thin_line_window_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(1.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(1.0, 0.0),
        end: svg_path.Point(2.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(2.0, 0.0),
        end: svg_path.Point(3.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(3.0, 0.0),
        end: svg_path.Point(4.0, 0.0),
      ),
    ])

  let assert Ok(cleaned) =
    effects.normalize_degenerate_segments(subpath, tolerance: 0.001)
  assert svg_path.subpath_segments(cleaned)
    == [
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(4.0, 0.0),
      ),
    ]
}

pub fn normalize_degenerate_segments_preserves_closed_two_line_backtracking_test() {
  let open =
    svg_path.subpath_assert([
      svg_path.QuadraticBezier(
        start: svg_path.Point(0.0, 0.0),
        control: svg_path.Point(5.0, 0.0),
        end: svg_path.Point(0.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(0.0, 10.0),
      ),
      svg_path.Line(
        start: svg_path.Point(0.0, 10.0),
        end: svg_path.Point(0.0, 0.0),
      ),
    ])
  let subpath = svg_path.subpath_assert_set_closed(open, closed: True)

  let assert Ok(cleaned) =
    effects.normalize_degenerate_segments(subpath, tolerance: 0.001)
  assert svg_path.subpath_is_closed(cleaned)
  assert list.length(svg_path.subpath_segments(cleaned)) == 4
  assert has_line(
    svg_path.subpath_segments(cleaned),
    svg_path.Point(0.0, 0.0),
    svg_path.Point(2.5, 0.0),
  )
  assert has_line(
    svg_path.subpath_segments(cleaned),
    svg_path.Point(2.5, 0.0),
    svg_path.Point(0.0, 0.0),
  )
}

pub fn normalize_degenerate_segments_keeps_closed_three_line_traversal_test() {
  let open =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(10.0, 0.0),
        end: svg_path.Point(0.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(0.0, 10.0),
      ),
      svg_path.Line(
        start: svg_path.Point(0.0, 10.0),
        end: svg_path.Point(0.0, 0.0),
      ),
    ])
  let subpath = svg_path.subpath_assert_set_closed(open, closed: True)

  let assert Ok(cleaned) =
    effects.normalize_degenerate_segments(subpath, tolerance: 0.001)
  assert svg_path.subpath_is_closed(cleaned)
  assert list.length(svg_path.subpath_segments(cleaned)) == 4
}

fn arc_count(segments: List(svg_path.Segment)) -> Int {
  segments
  |> list.filter(keeping: fn(segment) {
    case segment {
      svg_path.Arc(..) -> True
      _ -> False
    }
  })
  |> list.length
}

fn right_angle_subpath() -> svg_path.Subpath {
  svg_path.subpath_assert_polyline([
    svg_path.Point(0.0, 0.0),
    svg_path.Point(10.0, 0.0),
    svg_path.Point(10.0, 10.0),
  ])
}

fn all_arc_radii_near(
  segments: List(svg_path.Segment),
  expected expected: Float,
) -> Bool {
  segments
  |> list.filter_map(fn(segment) {
    case segment {
      svg_path.Arc(radius:, ..) -> Ok(radius.x)
      _ -> Error(Nil)
    }
  })
  |> list.all(fn(radius) {
    float.absolute_value(radius -. expected) <=. tolerance
  })
}

fn has_line(
  segments: List(svg_path.Segment),
  start: svg_path.Point,
  end: svg_path.Point,
) -> Bool {
  list.any(segments, fn(segment) {
    case segment {
      svg_path.Line(start: actual_start, end: actual_end) ->
        same_point(actual_start, start) && same_point(actual_end, end)
      _ -> False
    }
  })
}

fn has_arc(
  segments: List(svg_path.Segment),
  start: svg_path.Point,
  end: svg_path.Point,
) -> Bool {
  list.any(segments, fn(segment) {
    case segment {
      svg_path.Arc(start: actual_start, end: actual_end, ..) ->
        same_point(actual_start, start) && same_point(actual_end, end)
      _ -> False
    }
  })
}

fn has_arc_start(
  segments: List(svg_path.Segment),
  start: svg_path.Point,
) -> Bool {
  list.any(segments, fn(segment) {
    case segment {
      svg_path.Arc(start: actual_start, ..) -> same_point(actual_start, start)
      _ -> False
    }
  })
}

fn has_quadratic(segments: List(svg_path.Segment)) -> Bool {
  list.any(segments, fn(segment) {
    case segment {
      svg_path.QuadraticBezier(..) -> True
      _ -> False
    }
  })
}

fn has_cubic(segments: List(svg_path.Segment)) -> Bool {
  list.any(segments, fn(segment) {
    case segment {
      svg_path.CubicBezier(..) -> True
      _ -> False
    }
  })
}

fn same_point(left: svg_path.Point, right: svg_path.Point) -> Bool {
  float.absolute_value(left.x -. right.x) <=. tolerance
  && float.absolute_value(left.y -. right.y) <=. tolerance
}
