import svg_path
import svg_path/parse

// Paper.js Path.js #1613 only asserts that coincident-endpoint arcTo does
// not throw. The pinned runtime leaves one move node and no curves.
// Our raw parser preserves the Arc; explicit SVG normalization removes it.
pub fn paper_1613_coincident_endpoint_arc_normalizes_to_move_test() {
  let assert Ok(path) = parse.path("M10 10 A10 10 0 1 1 10 10")
  let assert [subpath] = svg_path.path_subpaths(path)
  let assert [svg_path.Arc(start:, end:, ..)] =
    svg_path.subpath_segments(subpath)
  assert start == svg_path.Point(10.0, 10.0)
  assert end == start
  assert svg_path.path_to_cubic_beziers_strict(path)
    == Error(svg_path.DegenerateArc)
  let normalized = svg_path.path_normalize_svg_arcs(path)
  let assert Ok(move_only) = parse.path("M10 10")
  assert normalized == move_only
  assert svg_path.path_to_cubic_beziers_strict(normalized) == Ok(move_only)
  assert svg_path.path_normalize_svg_arcs(normalized) == normalized
}
