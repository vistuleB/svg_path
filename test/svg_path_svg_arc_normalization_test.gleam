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
      assert degeneracy.segment_normalize_svg_arc(arc(
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
  assert degeneracy.segment_normalize_svg_arc(arc(
      svg_path.Point(0.0, 1_000_000.0),
      svg_path.Point(0.0, 0.0),
    ))
    == None
}

pub fn negative_radii_normalize_without_enlargement_test() {
  let segment = arc(svg_path.Point(-2.0, -3.0), svg_path.Point(10.0, 0.0))
  assert degeneracy.segment_normalize_svg_arc(segment)
    == Some(arc(svg_path.Point(2.0, 3.0), svg_path.Point(10.0, 0.0)))
}

pub fn normalization_preserves_empty_subpaths_and_closure_test() {
  let assert Ok(path) =
    parse.path("M2 3A0 8 0 1 1 2 3Z M4 5A7 8 0 1 1 4 5 M6 7")
  let normalized = degeneracy.path_normalize_svg_arcs(path)
  assert normalized
    == svg_path.Path([
      svg_path.subpath_empty(svg_path.Point(2.0, 3.0))
        |> svg_path.subpath_assert_close,
      svg_path.subpath_empty(svg_path.Point(4.0, 5.0)),
      svg_path.subpath_empty(svg_path.Point(6.0, 7.0)),
    ])
  assert degeneracy.path_normalize_svg_arcs(normalized) == normalized
}

pub fn normalization_preserves_zero_length_lines_test() {
  let line = svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(0.0, 0.0))
  assert degeneracy.segment_normalize_svg_arc(line) == Some(line)
  let path = svg_path.Path([svg_path.subpath_assert([line])])
  assert degeneracy.path_normalize_svg_arcs(path) == path
}

pub fn mixed_arc_normalization_preserves_continuity_test() {
  let assert Ok(path) =
    parse.path("M0 0A0 8 0 0 1 10 0A2 3 0 1 1 10 0A-2 -3 0 0 1 20 0Z")
  let normalized = degeneracy.path_normalize_svg_arcs(path)
  assert serialize.path(normalized) == "M 0 0 H 10 A 2 3 0 0 1 20 0 Z"
  assert degeneracy.path_normalize_svg_arcs(normalized) == normalized
}
