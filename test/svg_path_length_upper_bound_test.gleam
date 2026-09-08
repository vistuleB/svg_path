import gleam/float
import svg_path

pub fn line_length_upper_bound_is_chord_test() {
  assert svg_path.segment_length_upper_bound(svg_path.Line(
      svg_path.Point(0.0, 0.0),
      svg_path.Point(3.0, 4.0),
    ))
    == Ok(5.0)
}

pub fn bezier_length_upper_bounds_include_backtracking_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(3.0, 4.0)
  assert svg_path.segment_length_upper_bound(svg_path.QuadraticBezier(a, b, a))
    == Ok(10.0)
  assert svg_path.segment_length_upper_bound(svg_path.CubicBezier(a, b, a, b))
    == Ok(15.0)
  assert svg_path.segment_length_upper_bound(svg_path.CubicBezier(a, a, a, a))
    == Ok(0.0)
}

pub fn circular_arc_length_bound_is_exact_up_to_roundoff_test() {
  let arc =
    svg_path.Arc(
      svg_path.Point(2.0, 0.0),
      svg_path.Point(2.0, 2.0),
      0.0,
      False,
      True,
      svg_path.Point(0.0, 2.0),
    )
  let assert Ok(bound) = svg_path.segment_length_upper_bound(arc)
  assert float.absolute_value(bound -. 3.141592653589793) <. 0.000000000001
}

pub fn arc_length_bound_uses_corrected_radii_test() {
  let arc =
    svg_path.Arc(
      svg_path.Point(-2.0, 0.0),
      svg_path.Point(1.0, 1.0),
      0.0,
      False,
      True,
      svg_path.Point(2.0, 0.0),
    )
  let assert Ok(bound) = svg_path.segment_length_upper_bound(arc)
  assert float.absolute_value(bound -. 6.283185307179586) <. 0.000000000001
}

pub fn ellipse_length_bound_exceeds_integrated_length_test() {
  let arc =
    svg_path.Arc(
      svg_path.Point(3.0, 0.0),
      svg_path.Point(3.0, 1.0),
      0.0,
      False,
      True,
      svg_path.Point(0.0, 1.0),
    )
  let assert Ok(bound) = svg_path.segment_length_upper_bound(arc)
  let assert Ok(length) = svg_path.segment_length(arc)
  assert bound >=. length
  assert float.absolute_value(bound -. 4.71238898038469) <. 0.000000000001
}

pub fn length_bounds_sum_subpaths_without_counting_gaps_test() {
  let empty = svg_path.subpath_empty(at: svg_path.Point(100.0, 100.0))
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(3.0, 4.0)
  let subpath =
    svg_path.subpath_assert([svg_path.Line(a, b), svg_path.Line(b, a)])
  let assert Ok(closed) = svg_path.subpath_set_closed(subpath, closed: True)
  assert svg_path.subpath_length_upper_bound(empty) == Ok(0.0)
  assert svg_path.subpath_length_upper_bound(closed) == Ok(10.0)
  assert svg_path.path_length_upper_bound(svg_path.Path([])) == Ok(0.0)
  assert svg_path.path_length_upper_bound(
      svg_path.Path([closed, empty, subpath]),
    )
    == Ok(20.0)
}

pub fn length_bound_propagates_invalid_arc_test() {
  let a = svg_path.Point(0.0, 0.0)
  let arc = svg_path.Arc(a, svg_path.Point(1.0, 1.0), 0.0, False, True, a)
  let subpath = svg_path.subpath_assert([arc])
  assert svg_path.segment_length_upper_bound(arc)
    == Error(svg_path.DegenerateArc)
  assert svg_path.subpath_length_upper_bound(subpath)
    == Error(svg_path.DegenerateArc)
  assert svg_path.path_length_upper_bound(svg_path.Path([subpath]))
    == Error(svg_path.DegenerateArc)
}
