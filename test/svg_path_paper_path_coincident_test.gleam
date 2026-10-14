// Adapted from pinned Paper.js Path.js. See scripts/paperjs/PATH_COINCIDENT.md.
import svg_path
import svg_path/degeneracy
import svg_path/measure

pub fn paper_three_coincident_nodes_normalize_to_move_test() {
  let point = svg_path.Point(20.0, 20.0)
  // Three Paper nodes without handles describe two zero-length edges.
  let source =
    svg_path.subpath_assert([
      svg_path.Line(point, point),
      svg_path.Line(point, point),
    ])
  let assert Ok(cleaned) =
    degeneracy.normalize_degenerate_segments(source, tolerance: 0.0)
  assert cleaned == svg_path.subpath_empty(at: point)
  assert !svg_path.subpath_is_closed(cleaned)
  assert svg_path.subpath_start(cleaned) == point
  assert svg_path.subpath_segments(cleaned) == []
  assert measure.subpath_length(cleaned) == Ok(0.0)
  assert degeneracy.normalize_degenerate_segments(cleaned, tolerance: 0.0)
    == Ok(cleaned)
}
