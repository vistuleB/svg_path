import gleam/float
import gleam/list
import svg_path
import svg_path/offset
import svg_path/parse
import svg_path/serialize
import svg_path/stroke

pub fn stroke_delegates_to_symmetric_band_for_open_and_closed_sources_test() {
  let open =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
    ])
  let closed =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
      svg_path.Point(0.0, 10.0),
    ])
  let band_options =
    offset.Options(
      ..offset.default_options(),
      band_trimming: offset.BandTrimming(
        inner_cusps: False,
        outer_cusps: False,
        in_band: True,
      ),
    )
  // Stroke's existing API ignores band trimming choices and retains its
  // always-on final trim. Make that compatibility choice explicit here.
  let stroke_options =
    stroke.Options(
      width: 2.0,
      offset: offset.Options(
        ..offset.default_options(),
        band_trimming: offset.BandTrimming(
          inner_cusps: True,
          outer_cusps: True,
          in_band: False,
        ),
      ),
    )
  list.each([open, closed], fn(source) {
    list.each(
      [
        #(stroke.Butt, offset.Butt),
        #(stroke.RoundCap, offset.RoundCap),
        #(stroke.Square, offset.Square),
      ],
      fn(caps) {
        let assert Ok(expected) =
          offset.subpath_band_with(
            source,
            inner_offset: -1.0,
            outer_offset: 1.0,
            join: offset.Round,
            cap: caps.1,
            options: band_options,
          )
        assert stroke.subpath_with(
            source,
            join: stroke.Round,
            cap: caps.0,
            options: stroke_options,
          )
          == Ok(expected)
      },
    )
  })
}

pub fn signed_zero_dash_patterns_are_continuous_test() {
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(1.0, 0.0)),
    ])
  list.each([[-0.0], [0.0, -0.0], [-0.0, 0.0, -0.0]], fn(pattern) {
    assert stroke.subpath_dashes(subpath, pattern:, offset: 0.0)
      == Ok([subpath])
  })
}

pub fn empty_path_stroke_validates_join_test() {
  let empty = svg_path.path_empty()
  assert stroke.path_with(
      empty,
      join: stroke.Miter(0.0),
      cap: stroke.Butt,
      options: stroke.default_options(),
    )
    == Error(stroke.OffsetError(offset.InvalidMiterLimit(0.0)))
  assert stroke.path_with(
      empty,
      join: stroke.Miter(0.0),
      cap: stroke.Butt,
      options: stroke.Options(..stroke.default_options(), width: 0.0),
    )
    == Error(stroke.InvalidWidth(0.0))
  let source =
    svg_path.subpath_assert([
      svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(10.0, 0.0)),
    ])
  assert stroke.path_with(
      svg_path.subpath_as_path(source),
      join: stroke.Miter(0.0),
      cap: stroke.Butt,
      options: stroke.default_options(),
    )
    == Error(stroke.OffsetError(offset.InvalidMiterLimit(0.0)))
}

pub fn empty_dashed_path_stroke_validates_join_test() {
  let source =
    svg_path.subpath_assert([
      svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(10.0, 0.0)),
    ])
  assert stroke.path_dashed_with(
      svg_path.subpath_as_path(source),
      join: stroke.Miter(0.0),
      cap: stroke.Butt,
      options: stroke.default_options(),
      dash_options: stroke.default_dash_options(
        pattern: [0.0, 20.0],
        offset: 0.0,
      ),
    )
    == Error(stroke.OffsetError(offset.InvalidMiterLimit(0.0)))
}

pub fn empty_path_stroke_validates_fitting_options_test() {
  let defaults = stroke.default_options()
  let fitting = offset.FittingOptions(..defaults.offset.fitting, samples: 0)
  let options =
    stroke.Options(
      ..defaults,
      offset: offset.Options(..defaults.offset, fitting:),
    )
  assert stroke.path_with(
      svg_path.path_empty(),
      join: stroke.Round,
      cap: stroke.Butt,
      options:,
    )
    == Error(stroke.OffsetError(offset.InvalidSamples(0)))
}

// Gallery round-cap dash piece 5: its inner offset can disappear under
// independent cusp trimming, but its complete stroke must remain visible.
pub fn stroke_preserves_gallery_hairpin_dash_test() {
  let source =
    svg_path.subpath_assert([
      svg_path.CubicBezier(
        start: svg_path.Point(720.8878345566945, 136.73890607319447),
        control1: svg_path.Point(725.5345471691022, 152.13173280113733),
        control2: svg_path.Point(724.2017606479264, 168.46101515319256),
        end: svg_path.Point(714.3795973596922, 163.26995325089777),
      ),
    ])
  let assert Ok(path) =
    stroke.subpath(
      source,
      width: 16.0,
      join: stroke.Round,
      cap: stroke.RoundCap,
    )
  let assert [outline] = svg_path.path_subpaths(path)
  assert svg_path.subpath_is_closed(outline)
  assert arc_count(svg_path.subpath_segments(outline)) >= 2
  let assert Ok(svg_path.Inside) =
    svg_path.path_containment(
      svg_path.subpath_start(source),
      within: path,
      using: svg_path.Nonzero,
    )
  let assert Ok(svg_path.Inside) =
    svg_path.path_containment(
      svg_path.subpath_end(source),
      within: path,
      using: svg_path.Nonzero,
    )
}

pub fn segment_stroke_with_butt_caps_returns_closed_outline_test() {
  let segment =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 0.0),
    )

  let assert Ok(path) =
    stroke.segment(
      segment,
      width: 2.0,
      join: stroke.Miter(offset.default_miter_limit),
      cap: stroke.Butt,
    )
  let assert [outline] = svg_path.path_subpaths(path)

  assert svg_path.subpath_is_closed(outline)
  assert serialize.subpath(outline) == "M 0 -1 H 10 V 1 H 0 Z"
}

pub fn subpath_stroke_with_round_caps_adds_two_cap_arcs_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])
  let options = stroke.Options(..stroke.default_options(), width: 2.0)

  let assert Ok(path) =
    stroke.subpath_with(
      subpath,
      join: stroke.Miter(offset.default_miter_limit),
      cap: stroke.RoundCap,
      options:,
    )
  let assert [outline] = svg_path.path_subpaths(path)

  assert svg_path.subpath_is_closed(outline)
  assert arc_count(svg_path.subpath_segments(outline)) == 2
}

pub fn subpath_stroke_with_round_cap_serializes_semicircles_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])
  let options = stroke.Options(..stroke.default_options(), width: 2.0)

  let assert Ok(path) =
    stroke.subpath_with(
      subpath,
      join: stroke.Miter(offset.default_miter_limit),
      cap: stroke.RoundCap,
      options:,
    )
  let assert [outline] = svg_path.path_subpaths(path)

  assert serialize.subpath(outline)
    == "M 0 -1 H 10 A 1 1 0 0 1 10 1 H 0 A 1 1 0 0 1 0 -1 Z"
}

pub fn round_caps_use_normalized_source_endpoint_directions_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.CubicBezier(
        start: svg_path.Point(119.39091517239682, 120.68941214016728),
        control1: svg_path.Point(119.99661582931833, 120.39944456042525),
        control2: svg_path.Point(120.60455242265807, 120.1171740145196),
        end: svg_path.Point(121.21463749128954, 119.84268982753466),
      ),
    ])
  let options = stroke.Options(width: 6.0, offset: offset.default_options())

  let assert Ok(path) =
    stroke.subpath_with(
      subpath,
      join: stroke.Round,
      cap: stroke.RoundCap,
      options:,
    )
  let assert [outline] = svg_path.path_subpaths(path)

  assert svg_path.subpath_is_closed(outline)
}

pub fn stroke_accepts_a_directed_cubic_with_a_stationary_start_parameter_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.CubicBezier(
        start: svg_path.Point(438.1699, -68.829),
        control1: svg_path.Point(438.1699, -68.829),
        control2: svg_path.Point(410.55765339720045, -44.345920281737655),
        end: svg_path.Point(408.4367, -42.4248),
      ),
    ])

  let assert Ok(path) =
    stroke.subpath(
      subpath,
      width: 0.5,
      join: stroke.Miter(offset.default_miter_limit),
      cap: stroke.Butt,
    )
  let assert [outline] = svg_path.path_subpaths(path)

  assert svg_path.subpath_is_closed(outline)
}

pub fn stroke_accepts_stationary_start_and_steep_crossing_regression_test() {
  let source =
    "M 52.0515 277.5936 C 60.8159 269.8805 69.4564 262.0312 78.0103 254.0832 C 90.3339 242.6296 103.2476 231.8349 115.7828 220.6132 C 130.2062 207.6966 145.0563 195.2589 159.5077 182.3759 C 174.8593 168.6928 190.2079 155.0085 205.5564 141.3241 C 221.3130 127.2946 236.5355 112.9876 252.5219 98.9002 C 269.0418 84.3451 285.5518 69.4646 301.8246 54.9526 C 315.7254 42.5566 329.1876 29.6822 343.2148 17.4364 C 355.3230 6.8667 367.4950 -3.6205 379.2403 -14.5886 C 389.0271 -23.7278 399.1082 -32.5430 409.0340 -41.5293 C 411.1546 -43.4486 448.6067 -76.6113 451.7844 -79.8502 L 451.1893 -80.7477 L 438.1699 -68.8290 S 410.5574 -44.3462 408.4367 -42.4248 C 398.5096 -33.4354 388.4254 -24.6214 378.6363 -15.4802 C 366.8934 -4.5162 354.7278 5.9713 342.6241 16.5370 C 328.5969 28.7828 315.0311 41.5393 301.2383 54.0513 C 284.6189 69.1310 268.4477 83.4487 251.9223 98.0067 C 236.0946 111.9500 220.7179 126.3970 204.9624 140.4256 L 158.9147 181.4785 C 144.4612 194.3614 129.6131 206.8013 115.1878 219.7157 C 102.6522 230.9416 89.7322 241.7360 77.4054 253.1905 C 68.8548 261.1355 60.2187 268.9829 51.4564 276.6961 L 52.0505 277.5924 Z"
  let assert Ok(path) = parse.path(source)

  let assert Ok(stroked) =
    stroke.path(
      path,
      width: 0.5,
      join: stroke.Miter(offset.default_miter_limit),
      cap: stroke.Butt,
    )

  assert svg_path.path_subpaths(stroked) != []
}

pub fn zero_length_subpath_stroke_with_butt_cap_returns_empty_path_test() {
  let a = svg_path.Point(3.0, 4.0)
  let subpath = svg_path.subpath_assert([svg_path.Line(start: a, end: a)])

  let assert Ok(path) =
    stroke.subpath(
      subpath,
      width: 2.0,
      join: stroke.Miter(offset.default_miter_limit),
      cap: stroke.Butt,
    )

  assert svg_path.path_subpaths(path) == []
}

pub fn zero_length_subpath_stroke_with_round_cap_returns_circle_test() {
  let a = svg_path.Point(3.0, 4.0)
  let subpath = svg_path.subpath_assert([svg_path.Line(start: a, end: a)])
  let options = stroke.Options(..stroke.default_options(), width: 2.0)

  let assert Ok(path) =
    stroke.subpath_with(
      subpath,
      join: stroke.Miter(offset.default_miter_limit),
      cap: stroke.RoundCap,
      options:,
    )
  let assert [outline] = svg_path.path_subpaths(path)

  assert svg_path.subpath_is_closed(outline)
  assert serialize.subpath(outline) == "M 4 4 A 1 1 0 0 1 2 4 A 1 1 0 0 1 4 4 Z"
}

pub fn subpath_stroke_with_square_caps_extends_by_half_width_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])
  let options = stroke.Options(..stroke.default_options(), width: 2.0)

  let assert Ok(path) =
    stroke.subpath_with(
      subpath,
      join: stroke.Miter(offset.default_miter_limit),
      cap: stroke.Square,
      options:,
    )
  let assert [outline] = svg_path.path_subpaths(path)

  assert serialize.subpath(outline)
    == "M 0 -1 H 10 H 11 V 1 H 10 H 0 H -1 V -1 Z"
}

pub fn subpath_stroke_with_bevel_join_keeps_corner_cut_test() {
  let subpath = right_angle_subpath()
  let options = stroke.Options(..stroke.default_options(), width: 2.0)

  let assert Ok(path) =
    stroke.subpath_with(subpath, join: stroke.Bevel, cap: stroke.Butt, options:)
  let assert [outline] = svg_path.path_subpaths(path)

  assert serialize.subpath(outline) == "M 0 -1 H 10 L 11 0 V 10 H 9 V 1 H 0 Z"
}

pub fn subpath_stroke_with_round_join_adds_join_arcs_test() {
  let subpath = right_angle_subpath()
  let options = stroke.Options(..stroke.default_options(), width: 2.0)

  let assert Ok(path) =
    stroke.subpath_with(subpath, join: stroke.Round, cap: stroke.Butt, options:)
  let assert [outline] = svg_path.path_subpaths(path)

  assert arc_count(svg_path.subpath_segments(outline)) == 1
  assert serialize.subpath(outline)
    == "M 0 -1 H 10 A 1 1 0 0 1 11 0 V 10 H 9 V 1 H 0 Z"
}

pub fn subpath_stroke_with_miter_join_extends_to_apex_test() {
  let subpath = right_angle_subpath()
  let options = stroke.Options(..stroke.default_options(), width: 2.0)

  let assert Ok(path) =
    stroke.subpath_with(
      subpath,
      join: stroke.Miter(4.0),
      cap: stroke.Butt,
      options:,
    )
  let assert [outline] = svg_path.path_subpaths(path)

  assert serialize.subpath(outline) == "M 0 -1 H 10 H 11 V 0 V 10 H 9 V 1 H 0 Z"
}

pub fn subpath_stroke_with_low_miter_limit_falls_back_to_bevel_test() {
  let subpath = right_angle_subpath()
  let options = stroke.Options(..stroke.default_options(), width: 2.0)

  let assert Ok(low_miter_path) =
    stroke.subpath_with(
      subpath,
      join: stroke.Miter(1.0),
      cap: stroke.Butt,
      options:,
    )
  let assert Ok(bevel_path) =
    stroke.subpath_with(subpath, join: stroke.Bevel, cap: stroke.Butt, options:)

  assert serialize.path(low_miter_path) == serialize.path(bevel_path)
}

pub fn zero_length_subpath_stroke_with_square_cap_returns_square_test() {
  let a = svg_path.Point(3.0, 4.0)
  let subpath = svg_path.subpath_assert([svg_path.Line(start: a, end: a)])
  let options = stroke.Options(..stroke.default_options(), width: 2.0)

  let assert Ok(path) =
    stroke.subpath_with(
      subpath,
      join: stroke.Miter(offset.default_miter_limit),
      cap: stroke.Square,
      options:,
    )
  let assert [outline] = svg_path.path_subpaths(path)

  assert svg_path.subpath_is_closed(outline)
  assert serialize.subpath(outline) == "M 2 3 H 4 V 5 H 2 Z"
}

pub fn closed_subpath_stroke_returns_two_closed_contours_test() {
  let square =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
      svg_path.Point(0.0, 10.0),
    ])

  let assert Ok(path) =
    stroke.subpath(
      square,
      width: 2.0,
      join: stroke.Miter(offset.default_miter_limit),
      cap: stroke.Butt,
    )
  let subpaths = svg_path.path_subpaths(path)

  assert list.length(subpaths) == 2
  assert list.all(subpaths, svg_path.subpath_is_closed)
}

pub fn self_meeting_closed_subpath_stroke_uses_band_sections_test() {
  let figure_eight =
    svg_path.subpath_assert([
      svg_path.CubicBezier(
        start: svg_path.Point(76.0, 0.0),
        control1: svg_path.Point(-2.0, -62.0),
        control2: svg_path.Point(-2.0, 62.0),
        end: svg_path.Point(76.0, 0.0),
      ),
      svg_path.CubicBezier(
        start: svg_path.Point(76.0, 0.0),
        control1: svg_path.Point(154.0, -62.0),
        control2: svg_path.Point(154.0, 62.0),
        end: svg_path.Point(76.0, 0.0),
      ),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)

  let assert Ok(path) =
    stroke.subpath(
      figure_eight,
      width: 26.0,
      join: stroke.Miter(offset.default_miter_limit),
      cap: stroke.Butt,
    )
  let subpaths = svg_path.path_subpaths(path)

  assert list.length(subpaths) == 3
  assert list.all(subpaths, svg_path.subpath_is_closed)
  assert svg_path.path_containment(
      svg_path.Point(76.0, 0.0),
      within: path,
      using: svg_path.Nonzero,
    )
    == Ok(svg_path.Inside)
  assert svg_path.path_containment(
      svg_path.Point(76.0, 0.0),
      within: path,
      using: svg_path.EvenOdd,
    )
    == Ok(svg_path.Inside)
}

pub fn path_stroke_strokes_each_subpath_test() {
  let first =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])
  let second =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 10.0),
      svg_path.Point(10.0, 10.0),
    ])

  let assert Ok(path) =
    stroke.path(
      svg_path.Path(subpaths: [first, second]),
      width: 2.0,
      join: stroke.Miter(offset.default_miter_limit),
      cap: stroke.Butt,
    )

  assert list.length(svg_path.path_subpaths(path)) == 2
}

pub fn subpath_dashes_extracts_line_intervals_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(12.0, 0.0),
    ])

  let assert Ok(dashes) =
    stroke.subpath_dashes(subpath, pattern: [3.0, 2.0], offset: 0.0)

  assert dashes |> list.map(serialize.subpath)
    == [
      "M 0 0 H 3",
      "M 5 0 H 8",
      "M 10 0 H 12",
    ]
}

pub fn subpath_dashes_preserves_small_scale_intervals_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(0.000000001, 0.0),
    ])

  let assert Ok([dash]) =
    stroke.subpath_dashes(
      subpath,
      pattern: [0.0000000005, 0.0000000005],
      offset: 0.0,
    )

  assert svg_path.subpath_end(dash) == svg_path.Point(0.0000000005, 0.0)
}

pub fn subpath_dashes_applies_positive_dash_offset_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])

  let assert Ok(dashes) =
    stroke.subpath_dashes(subpath, pattern: [3.0, 2.0], offset: 1.0)

  assert dashes |> list.map(serialize.subpath)
    == [
      "M 0 0 H 2",
      "M 4 0 H 7",
      "M 9 0 H 10",
    ]
}

pub fn subpath_dashes_applies_negative_dash_offset_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])

  let assert Ok(dashes) =
    stroke.subpath_dashes(subpath, pattern: [3.0, 2.0], offset: -1.0)

  assert dashes |> list.map(serialize.subpath)
    == [
      "M 1 0 H 4",
      "M 6 0 H 9",
    ]
}

pub fn subpath_dashes_duplicates_odd_patterns_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(12.0, 0.0),
    ])

  let assert Ok(dashes) =
    stroke.subpath_dashes(subpath, pattern: [2.0, 1.0, 3.0], offset: 0.0)

  assert dashes |> list.map(serialize.subpath)
    == [
      "M 0 0 H 2",
      "M 3 0 H 6",
      "M 8 0 H 9",
    ]
}

pub fn subpath_dashes_preserves_zero_visible_entries_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(8.0, 0.0),
    ])

  let assert Ok(dashes) =
    stroke.subpath_dashes(subpath, pattern: [0.0, 2.0, 3.0, 2.0], offset: 0.0)

  assert dashes |> list.map(serialize.subpath)
    == [
      "M 0 0 H 0",
      "M 2 0 H 5",
      "M 7 0 H 7",
    ]
}

pub fn zero_visible_dashes_keep_caps_and_phase_test() {
  let source =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(4.0, 0.0),
    ])
  list.each(
    [#(0.0, [0.0, 2.0, 4.0]), #(1.0, [1.0, 3.0]), #(-1.0, [1.0, 3.0])],
    fn(case_) {
      let #(phase, positions) = case_
      let assert Ok(dashes) =
        stroke.subpath_dashes(source, pattern: [0.0, 2.0], offset: phase)
      assert list.map(dashes, fn(dash) { svg_path.subpath_start(dash).x })
        == positions
      list.each([stroke.Butt, stroke.RoundCap, stroke.Square], fn(cap) {
        let assert Ok(result) =
          stroke.subpath_dashed(
            source,
            width: 0.5,
            pattern: [0.0, 2.0],
            offset: phase,
            join: stroke.Bevel,
            cap:,
          )
        assert list.length(svg_path.path_subpaths(result))
          == case cap {
            stroke.Butt -> 0
            _ -> list.length(positions)
          }
      })
    },
  )
}

pub fn zero_dash_square_cap_uses_source_direction_test() {
  let source =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(3.0, 4.0),
    ])
  let assert Ok(result) =
    stroke.subpath_dashed(
      source,
      width: 2.0,
      pattern: [0.0, 2.0],
      offset: 0.0,
      join: stroke.Bevel,
      cap: stroke.Square,
    )
  let assert [first, ..] = svg_path.path_subpaths(result)
  let corner = svg_path.subpath_start(first)
  assert float.absolute_value(corner.x -. 0.2) <. 0.000000001
  assert float.absolute_value(corner.y +. 1.4) <. 0.000000001
  assert stroke.path_dashed(
      svg_path.subpath_as_path(source),
      width: 2.0,
      pattern: [0.0, 2.0],
      offset: 0.0,
      join: stroke.Bevel,
      cap: stroke.Square,
    )
    == Ok(result)
}

pub fn zero_visible_dashes_on_closed_source_are_points_not_full_loops_test() {
  let source =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(2.0, 0.0),
      svg_path.Point(2.0, 2.0),
      svg_path.Point(0.0, 2.0),
      svg_path.Point(0.0, 0.0),
    ])
  let assert Ok(source) =
    svg_path.subpath_set_closed_with(
      source,
      closed: True,
      policy: svg_path.Strict,
    )
  let assert Ok(dashes) =
    stroke.subpath_dashes(source, pattern: [0.0, 3.0], offset: 0.0)
  assert list.length(dashes) == 3
  list.each(dashes, fn(dash) {
    assert !svg_path.subpath_is_closed(dash)
    assert svg_path.subpath_length(dash) == Ok(0.0)
  })
  let assert Ok(stroked) =
    stroke.subpath_dashed(
      source,
      width: 0.5,
      pattern: [0.0, 3.0],
      offset: 0.0,
      join: stroke.Bevel,
      cap: stroke.RoundCap,
    )
  assert list.length(svg_path.path_subpaths(stroked)) == 3
}

pub fn consecutive_zero_visible_dashes_advance_pattern_test() {
  let source =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(4.0, 0.0),
    ])
  let assert Ok(dashes) =
    stroke.subpath_dashes(source, pattern: [0.0, 0.0, 0.0, 2.0], offset: 0.0)
  assert list.map(dashes, fn(dash) { svg_path.subpath_start(dash).x })
    == [0.0, 0.0, 2.0, 2.0, 4.0, 4.0]
}

pub fn subpath_dashes_treats_empty_pattern_as_none_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(8.0, 0.0),
    ])

  let assert Ok(dashes) =
    stroke.subpath_dashes(subpath, pattern: [], offset: 3.0)

  assert dashes |> list.map(serialize.subpath) == ["M 0 0 H 8"]
}

pub fn subpath_dashes_crosses_segment_boundaries_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
    ])

  let assert Ok([dash]) =
    stroke.subpath_dashes(subpath, pattern: [15.0, 5.0], offset: 0.0)

  assert serialize.subpath(dash) == "M 0 0 H 10 V 5"
  assert list.length(svg_path.subpath_segments(dash)) == 2
}

pub fn subpath_dashes_preserves_closed_none_semantics_test() {
  let subpath =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
      svg_path.Point(0.0, 10.0),
    ])

  let assert Ok([dash]) =
    stroke.subpath_dashes(subpath, pattern: [0.0, 0.0], offset: 0.0)

  assert svg_path.subpath_is_closed(dash)
  assert serialize.subpath(dash) == serialize.subpath(subpath)
}

pub fn subpath_dashes_opens_full_closed_dash_when_pattern_is_active_test() {
  let subpath =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
      svg_path.Point(0.0, 10.0),
    ])

  let assert Ok([dash]) =
    stroke.subpath_dashes(subpath, pattern: [100.0, 5.0], offset: 0.0)

  assert !svg_path.subpath_is_closed(dash)
  assert serialize.subpath(dash) == "M 0 0 H 10 V 10 H 0 V 0"
}

pub fn path_dashes_resets_pattern_per_subpath_test() {
  let first =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])
  let second =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 10.0),
      svg_path.Point(10.0, 10.0),
    ])

  let assert Ok(path) =
    stroke.path_dashes(
      svg_path.Path([first, second]),
      pattern: [3.0, 100.0],
      offset: 0.0,
    )

  assert svg_path.path_subpaths(path) |> list.map(serialize.subpath)
    == [
      "M 0 0 H 3",
      "M 0 10 H 3",
    ]
}

pub fn path_dashes_empty_path_still_validates_options_test() {
  assert stroke.path_dashes(
      svg_path.Path([]),
      pattern: [-1.0, 2.0],
      offset: 0.0,
    )
    == Error(stroke.InvalidDashLength(-1.0))

  assert stroke.path_dashes_with(
      svg_path.Path([]),
      dash_options: stroke.DashOptions(
        pattern: [1.0, 1.0],
        offset: 0.0,
        length_options: svg_path.LengthOptions(tolerance: 0.0, max_depth: 20),
      ),
    )
    == Error(stroke.PathError(svg_path.InvalidLengthTolerance(0.0)))
}

pub fn subpath_dashed_strokes_each_dash_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])

  let assert Ok(path) =
    stroke.subpath_dashed(
      subpath,
      width: 2.0,
      pattern: [3.0, 2.0],
      offset: 0.0,
      join: stroke.Miter(offset.default_miter_limit),
      cap: stroke.Butt,
    )

  assert list.length(svg_path.path_subpaths(path)) == 2
  assert svg_path.path_subpaths(path) |> list.map(serialize.subpath)
    == [
      "M 0 -1 H 3 V 1 H 0 Z",
      "M 5 -1 H 8 V 1 H 5 Z",
    ]
}

pub fn subpath_dashes_rejects_invalid_pattern_and_offset_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])

  assert stroke.subpath_dashes(subpath, pattern: [-1.0, 2.0], offset: 0.0)
    == Error(stroke.InvalidDashLength(-1.0))
}

pub fn subpath_dashes_rejects_a_non_finite_pattern_total_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])

  assert stroke.subpath_dashes(
      subpath,
      pattern: [1.0e308, 1.0e308],
      offset: 0.0,
    )
    == Error(stroke.InvalidDashPatternLength)
}

pub fn stroke_rejects_non_positive_width_test() {
  let segment =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 0.0),
    )

  assert stroke.segment(
      segment,
      width: 0.0,
      join: stroke.Miter(offset.default_miter_limit),
      cap: stroke.Butt,
    )
    == Error(stroke.InvalidWidth(0.0))
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
