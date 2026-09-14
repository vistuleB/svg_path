import gleam/list
import gleam/option.{None, Some}
import svg_path
import svg_path/degeneracy
import svg_path/parse
import svg_path/serialize

fn arc(radius: svg_path.Point, end: svg_path.Point) -> svg_path.Segment {
  svg_path.Arc(
    start: svg_path.Point(0.0, 0.0),
    radius:,
    x_axis_rotation: 30.0,
    large_arc: True,
    sweep: False,
    end:,
  )
}

pub fn strict_cubic_conversion_accepts_empty_and_non_arc_paths_test() {
  assert svg_path.path_to_cubic_beziers_strict(svg_path.path_empty())
    == Ok(svg_path.path_empty())
  let assert Ok(path) = parse.path("M1 2 M0 0L0 0Q1 2 3 4C4 5 6 7 8 9")
  assert svg_path.path_to_cubic_beziers_strict(path)
    == Ok(svg_path.path_to_cubic_beziers(path))
}

pub fn strict_cubic_conversion_matches_forgiving_for_correctable_radii_test() {
  let assert Ok(path) =
    parse.path("M0 0A-2 -3 30 1 0 10 0 M20 20A5 5 0 0 1 25 25")
  let before = serialize.path(path)
  assert svg_path.path_to_cubic_beziers_strict(path)
    == Ok(svg_path.path_to_cubic_beziers(path))
  assert serialize.path(path) == before
  let assert [first, _] = svg_path.path_subpaths(path)
  let assert [svg_path.Arc(radius:, ..)] = svg_path.subpath_segments(first)
  assert radius == svg_path.Point(-2.0, -3.0)
}

pub fn strict_cubic_conversion_rejects_zero_small_and_coincident_arcs_test() {
  list.each(
    [
      "M0 0A0 10 0 0 1 10 0",
      "M0 0A10 0 0 0 1 10 0",
      "M0 0A0.000000001 10 0 0 1 10 0",
      "M0 0A10 -0.000000001 0 0 1 10 0",
      "M0 0A10 10 0 1 1 0 0",
    ],
    fn(source) {
      let assert Ok(path) = parse.path(source)
      assert svg_path.path_to_cubic_beziers_strict(path)
        == Error(svg_path.DegenerateArc)
      let assert [subpath] = svg_path.path_subpaths(path)
      let assert [segment] = svg_path.subpath_segments(subpath)
      assert svg_path.subpath_to_cubic_beziers_strict(subpath)
        == Error(svg_path.DegenerateArc)
      assert svg_path.segment_to_cubic_beziers_strict(segment)
        == Error(svg_path.DegenerateArc)
      assert svg_path.segment_arcs_to_cubic_beziers_strict(segment)
        == Error(svg_path.DegenerateArc)
      let assert [svg_path.CubicBezier(start:, end:, ..)] =
        svg_path.segment_to_cubic_beziers(segment)
      assert start == svg_path.segment_start(segment)
      assert end == svg_path.segment_end(segment)
    },
  )
}

pub fn strict_cubic_conversion_propagates_later_arc_error_test() {
  let assert Ok(path) =
    parse.path("M0 0A5 5 0 0 1 10 0 M20 0L21 0A0 10 0 0 1 22 0")
  assert svg_path.path_to_cubic_beziers_strict(path)
    == Error(svg_path.DegenerateArc)
  let normalized = svg_path.path_normalize_svg_arcs(path)
  assert svg_path.path_to_cubic_beziers_strict(normalized)
    == Ok(svg_path.path_to_cubic_beziers(normalized))
}

pub fn strict_arc_only_conversion_preserves_non_arcs_test() {
  let assert Ok(svg_path.Path([subpath])) =
    parse.path("M0 0L1 2Q3 4 5 6C7 8 9 10 11 12")
  list.each(svg_path.subpath_segments(subpath), fn(segment) {
    assert svg_path.segment_arcs_to_cubic_beziers_strict(segment)
      == Ok([segment])
    assert svg_path.segment_to_cubic_beziers_strict(segment)
      == Ok(svg_path.segment_to_cubic_beziers(segment))
  })
}

pub fn strict_cubic_conversion_preserves_closure_and_exact_endpoints_test() {
  let assert Ok(path) = parse.path("M2 3Z M0.3 0.7A5 3 15 1 1 8.2 4.6Z")
  let assert Ok(converted) = svg_path.path_to_cubic_beziers_strict(path)
  assert converted == svg_path.path_to_cubic_beziers(path)
  let assert [empty, curve] = svg_path.path_subpaths(converted)
  assert svg_path.subpath_is_closed(empty)
  assert svg_path.subpath_is_empty(empty)
  assert svg_path.subpath_start(empty) == svg_path.Point(2.0, 3.0)
  assert svg_path.subpath_is_closed(curve)
  assert svg_path.subpath_start(curve) == svg_path.Point(0.3, 0.7)
  assert svg_path.subpath_end(curve) == svg_path.Point(0.3, 0.7)
  let assert [_, source] = svg_path.path_subpaths(path)
  let assert [arc, _] = svg_path.subpath_segments(source)
  assert svg_path.segment_arcs_to_cubic_beziers_strict(arc)
    == Ok(svg_path.segment_arcs_to_cubic_beziers(arc))
}

pub fn parser_preserves_signed_arc_arguments_test() {
  let expected = arc(svg_path.Point(-2.0, -3.0), svg_path.Point(10.0, 0.0))
  assert parse.path("M0 0A-2 -3 30 1 0 10 0")
    == Ok(svg_path.Path([svg_path.subpath_assert([expected])]))
}

pub fn manually_constructed_unusual_arcs_roundtrip_test() {
  list.each(
    [
      arc(svg_path.Point(0.0, 1_000_000.0), svg_path.Point(10.0, 0.0)),
      arc(svg_path.Point(1_000_000.0, 0.0), svg_path.Point(10.0, 0.0)),
      arc(svg_path.Point(-2.0, -3.0), svg_path.Point(10.0, 0.0)),
      arc(svg_path.Point(2.0, 3.0), svg_path.Point(0.0, 0.0)),
      arc(svg_path.Point(0.0, 3.0), svg_path.Point(0.0, 0.0)),
    ],
    fn(segment) {
      let path = svg_path.Path([svg_path.subpath_assert([segment])])
      assert parse.path(serialize.path(path)) == Ok(path)
      assert parse.path(serialize.path_with(path, serialize.relative_options()))
        == Ok(path)
    },
  )
}

pub fn coincident_arc_after_close_preserves_new_subpath_test() {
  let assert Ok(path) = parse.path("M0 0L1 0Z A2 3 0 1 0 0 0")
  let assert [closed, open] = svg_path.path_subpaths(path)
  assert svg_path.subpath_is_closed(closed)
  assert !svg_path.subpath_is_closed(open)
  assert list.length(svg_path.subpath_segments(open)) == 1
  assert parse.path(serialize.path(path)) == Ok(path)
}

pub fn preserved_arc_resets_smooth_control_test() {
  assert parse.path("M0 0Q1 2 3 4A0 8 0 0 1 3 4T6 7")
    == parse.path("M0 0Q1 2 3 4A0 8 0 0 1 3 4Q3 4 6 7")
}

pub fn zero_radius_normalizes_to_exact_chord_test() {
  list.each(
    [svg_path.Point(0.0, 1_000_000.0), svg_path.Point(1_000_000.0, 0.0)],
    fn(radius) {
      assert svg_path.segment_normalize_svg_arc(arc(
          radius,
          svg_path.Point(10.0, 0.0),
        ))
        == Some(svg_path.Line(
          svg_path.Point(0.0, 0.0),
          svg_path.Point(10.0, 0.0),
        ))
    },
  )
}

pub fn coincidence_takes_precedence_over_zero_radius_test() {
  assert svg_path.segment_normalize_svg_arc(arc(
      svg_path.Point(0.0, 1_000_000.0),
      svg_path.Point(0.0, 0.0),
    ))
    == None
}

pub fn negative_radii_normalize_without_enlargement_test() {
  let segment = arc(svg_path.Point(-2.0, -3.0), svg_path.Point(10.0, 0.0))
  assert svg_path.segment_normalize_svg_arc(segment)
    == Some(arc(svg_path.Point(2.0, 3.0), svg_path.Point(10.0, 0.0)))
}

pub fn normalization_preserves_empty_subpaths_and_closure_test() {
  let assert Ok(path) =
    parse.path("M2 3A0 8 0 1 1 2 3Z M4 5A7 8 0 1 1 4 5 M6 7")
  let normalized = svg_path.path_normalize_svg_arcs(path)
  assert normalized
    == svg_path.Path([
      svg_path.subpath_empty(svg_path.Point(2.0, 3.0))
        |> svg_path.subpath_assert_close,
      svg_path.subpath_empty(svg_path.Point(4.0, 5.0)),
      svg_path.subpath_empty(svg_path.Point(6.0, 7.0)),
    ])
  assert svg_path.path_normalize_svg_arcs(normalized) == normalized
}

pub fn normalization_preserves_zero_length_lines_test() {
  let line = svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(0.0, 0.0))
  assert svg_path.segment_normalize_svg_arc(line) == Some(line)
  let path = svg_path.Path([svg_path.subpath_assert([line])])
  assert svg_path.path_normalize_svg_arcs(path) == path
}

pub fn mixed_arc_normalization_preserves_continuity_test() {
  let assert Ok(path) =
    parse.path("M0 0A0 8 0 0 1 10 0A2 3 0 1 1 10 0A-2 -3 0 0 1 20 0Z")
  let normalized = svg_path.path_normalize_svg_arcs(path)
  assert serialize.path(normalized) == "M 0 0 H 10 A 2 3 0 0 1 20 0 Z"
  assert svg_path.path_normalize_svg_arcs(normalized) == normalized
}

pub fn geometric_degeneracy_rejects_undefined_arcs_test() {
  list.each(
    [
      arc(svg_path.Point(0.0, 1_000_000.0), svg_path.Point(10.0, 0.0)),
      arc(svg_path.Point(1_000_000.0, 0.0), svg_path.Point(10.0, 0.0)),
      arc(svg_path.Point(2.0, 3.0), svg_path.Point(0.0, 0.0)),
      arc(svg_path.Point(0.0, 3.0), svg_path.Point(0.0, 0.0)),
    ],
    fn(segment) {
      let subpath = svg_path.subpath_assert([segment])
      assert svg_path.segment_to_lines(segment) == Error(svg_path.DegenerateArc)
      assert svg_path.subpath_to_lines(subpath) == Error(svg_path.DegenerateArc)
      assert svg_path.path_to_lines(svg_path.Path([subpath]))
        == Error(svg_path.DegenerateArc)
      assert degeneracy.segment_linearize_if_degenerate(segment, 0.001)
        == Error(degeneracy.PathError(svg_path.DegenerateArc))
      assert degeneracy.subpath_linearize_if_degenerate(subpath, 0.001)
        == Error(degeneracy.PathError(svg_path.DegenerateArc))
      assert degeneracy.normalize_degenerate_segments(subpath, 0.001)
        == Error(degeneracy.PathError(svg_path.DegenerateArc))
    },
  )
}

pub fn undefined_arc_in_thin_run_cannot_be_hidden_by_hull_test() {
  let assert Ok(svg_path.Path([subpath])) =
    parse.path("M0 0L1 0A0 100 0 0 1 2 0L3 0")
  assert degeneracy.normalize_degenerate_segments(subpath, 0.001)
    == Error(degeneracy.PathError(svg_path.DegenerateArc))
  let normalized = svg_path.subpath_normalize_svg_arcs(subpath)
  let assert Ok(simplified) =
    degeneracy.normalize_degenerate_segments(normalized, 0.001)
  assert svg_path.subpath_segments(simplified)
    == [svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(3.0, 0.0))]
}

pub fn valid_narrow_arc_can_still_be_simplified_test() {
  let segment =
    svg_path.Arc(
      svg_path.Point(0.0, 0.0),
      svg_path.Point(0.0001, 10.0),
      0.0,
      True,
      True,
      svg_path.Point(0.0, 10.0),
    )
  let assert Ok(Some(lines)) =
    degeneracy.segment_linearize_if_degenerate(segment, 0.001)
  assert list.length(lines) > 1
  let simplified = svg_path.subpath_assert(lines)
  assert svg_path.subpath_start(simplified) == svg_path.segment_start(segment)
  assert svg_path.subpath_end(simplified) == svg_path.segment_end(segment)
}
