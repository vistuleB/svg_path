import gleam/option.{Some}
import svg_path
import svg_path/degeneracy

pub fn negative_zero_length_returns_exact_start_parameter_test() {
  let curve =
    svg_path.QuadraticBezier(
      svg_path.Point(0.0, 0.0),
      svg_path.Point(1.0, 1.0),
      svg_path.Point(2.0, 0.0),
    )
  let assert Ok(subpath) = svg_path.subpath([curve])
  assert svg_path.segment_parameter_at_length(curve, distance: -0.0) == Ok(0.0)
  assert svg_path.subpath_parameter_at_length(subpath, distance: -0.0)
    == Ok(svg_path.SubpathParameter(0, 0.0))
}

pub fn negative_zero_radius_degenerates_to_line_test() {
  let start = svg_path.Point(1.0, 1.0)
  let end = svg_path.Point(2.0, 2.0)
  let arc =
    svg_path.Arc(start, svg_path.Point(-0.0, 1.0), 0.0, False, True, end)
  assert degeneracy.segment_linearize_if_degenerate(arc, tolerance: 0.0)
    == Ok(Some([svg_path.Line(start, end)]))
}
