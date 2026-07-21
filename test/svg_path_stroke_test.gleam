import gleam/list
import svg_path
import svg_path/serialize
import svg_path/stroke

pub fn segment_stroke_with_butt_caps_returns_closed_outline_test() {
  let segment =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  let assert Ok(path) = stroke.segment(segment, width: 2.0)
  let assert [outline] = svg_path.subpaths(path)

  assert svg_path.is_closed(outline)
  assert serialize.subpath(outline) == "M 0 -1 H 10 V 1 H 0 Z"
}

pub fn subpath_stroke_with_round_caps_adds_two_cap_arcs_test() {
  let subpath =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
    ])
  let options =
    stroke.Options(..stroke.default_options(), width: 2.0, cap: stroke.Round)

  let assert Ok(path) = stroke.subpath_with(subpath, options:)
  let assert [outline] = svg_path.subpaths(path)

  assert svg_path.is_closed(outline)
  assert arc_count(svg_path.segments(outline)) == 2
}

pub fn subpath_stroke_with_square_caps_extends_by_half_width_test() {
  let subpath =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
    ])
  let options =
    stroke.Options(..stroke.default_options(), width: 2.0, cap: stroke.Square)

  let assert Ok(path) = stroke.subpath_with(subpath, options:)
  let assert [outline] = svg_path.subpaths(path)

  assert serialize.subpath(outline)
    == "M 0 -1 H 10 H 11 V 1 H 10 H 0 H -1 V -1 Z"
}

pub fn closed_subpath_stroke_returns_two_closed_contours_test() {
  let square =
    svg_path.assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
      svg_path.point(0.0, 10.0),
    ])

  let assert Ok(path) = stroke.subpath(square, width: 2.0)
  let subpaths = svg_path.subpaths(path)

  assert list.length(subpaths) == 2
  assert list.all(subpaths, svg_path.is_closed)
}

pub fn self_meeting_closed_subpath_stroke_uses_band_sections_test() {
  let figure_eight =
    svg_path.assert_subpath([
      svg_path.CubicBezier(
        start: svg_path.point(76.0, 0.0),
        control1: svg_path.point(-2.0, -62.0),
        control2: svg_path.point(-2.0, 62.0),
        end: svg_path.point(76.0, 0.0),
      ),
      svg_path.CubicBezier(
        start: svg_path.point(76.0, 0.0),
        control1: svg_path.point(154.0, -62.0),
        control2: svg_path.point(154.0, 62.0),
        end: svg_path.point(76.0, 0.0),
      ),
    ])
    |> svg_path.assert_set_closed(closed: True)

  let assert Ok(path) = stroke.subpath(figure_eight, width: 26.0)
  let subpaths = svg_path.subpaths(path)

  assert list.length(subpaths) == 3
  assert list.all(subpaths, svg_path.is_closed)
  assert svg_path.path_containment(
      svg_path.point(76.0, 0.0),
      within: path,
      using: svg_path.Nonzero,
    )
    == Ok(svg_path.Inside)
  assert svg_path.path_containment(
      svg_path.point(76.0, 0.0),
      within: path,
      using: svg_path.EvenOdd,
    )
    == Ok(svg_path.Inside)
}

pub fn path_stroke_strokes_each_subpath_test() {
  let first =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
    ])
  let second =
    svg_path.assert_polyline([
      svg_path.point(0.0, 10.0),
      svg_path.point(10.0, 10.0),
    ])

  let assert Ok(path) =
    stroke.path(svg_path.Path(subpaths: [first, second]), width: 2.0)

  assert list.length(svg_path.subpaths(path)) == 2
}

pub fn subpath_dashes_extracts_line_intervals_test() {
  let subpath =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(12.0, 0.0),
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

pub fn subpath_dashes_applies_positive_dash_offset_test() {
  let subpath =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
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
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
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
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(12.0, 0.0),
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

pub fn subpath_dashes_skips_zero_entries_in_nonzero_patterns_test() {
  let subpath =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(8.0, 0.0),
    ])

  let assert Ok(dashes) =
    stroke.subpath_dashes(subpath, pattern: [0.0, 2.0, 3.0, 2.0], offset: 0.0)

  assert dashes |> list.map(serialize.subpath)
    == [
      "M 2 0 H 5",
    ]
}

pub fn subpath_dashes_crosses_segment_boundaries_test() {
  let subpath =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
    ])

  let assert Ok([dash]) =
    stroke.subpath_dashes(subpath, pattern: [15.0, 5.0], offset: 0.0)

  assert serialize.subpath(dash) == "M 0 0 H 10 V 5"
  assert list.length(svg_path.segments(dash)) == 2
}

pub fn subpath_dashes_preserves_closed_none_semantics_test() {
  let subpath =
    svg_path.assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
      svg_path.point(0.0, 10.0),
    ])

  let assert Ok([dash]) =
    stroke.subpath_dashes(subpath, pattern: [0.0, 0.0], offset: 0.0)

  assert svg_path.is_closed(dash)
  assert serialize.subpath(dash) == serialize.subpath(subpath)
}

pub fn subpath_dashes_opens_full_closed_dash_when_pattern_is_active_test() {
  let subpath =
    svg_path.assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
      svg_path.point(0.0, 10.0),
    ])

  let assert Ok([dash]) =
    stroke.subpath_dashes(subpath, pattern: [100.0, 5.0], offset: 0.0)

  assert !svg_path.is_closed(dash)
  assert serialize.subpath(dash) == "M 0 0 H 10 V 10 H 0 V 0"
}

pub fn path_dashes_resets_pattern_per_subpath_test() {
  let first =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
    ])
  let second =
    svg_path.assert_polyline([
      svg_path.point(0.0, 10.0),
      svg_path.point(10.0, 10.0),
    ])

  let assert Ok(path) =
    stroke.path_dashes(
      svg_path.Path([first, second]),
      pattern: [3.0, 100.0],
      offset: 0.0,
    )

  assert svg_path.subpaths(path) |> list.map(serialize.subpath)
    == [
      "M 0 0 H 3",
      "M 0 10 H 3",
    ]
}

pub fn subpath_dashed_strokes_each_dash_test() {
  let subpath =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
    ])

  let assert Ok(path) =
    stroke.subpath_dashed(subpath, width: 2.0, pattern: [3.0, 2.0], offset: 0.0)

  assert list.length(svg_path.subpaths(path)) == 2
  assert svg_path.subpaths(path) |> list.map(serialize.subpath)
    == [
      "M 0 -1 H 3 V 1 H 0 Z",
      "M 5 -1 H 8 V 1 H 5 Z",
    ]
}

pub fn subpath_dashes_rejects_invalid_pattern_and_offset_test() {
  let subpath =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
    ])

  assert stroke.subpath_dashes(subpath, pattern: [-1.0, 2.0], offset: 0.0)
    == Error(stroke.InvalidDashLength(-1.0))
}

pub fn stroke_rejects_non_positive_width_test() {
  let segment =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  assert stroke.segment(segment, width: 0.0) == Error(stroke.InvalidWidth(0.0))
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
