import gleam/float
import svg_path
import svg_path/affine
import svg_path/ellipse
import svg_path/transform

pub fn collapsed_quarter_preserves_direction_and_endpoints_test() {
  let arc =
    svg_path.Arc(
      svg_path.Point(1.0, 0.0),
      svg_path.Point(1.0, 1.0),
      0.0,
      False,
      True,
      svg_path.Point(0.0, 1.0),
    )
  assert transform.segment_with_arc_collapse(
      arc,
      by: transform.scale_xy(1.0, 0.0),
    )
    == Ok(svg_path.Line(svg_path.Point(1.0, 0.0), svg_path.Point(0.0, 0.0)))
  assert transform.segment_with_arc_collapse(
      arc,
      by: transform.scale_xy(-1.0, 0.0),
    )
    == Ok(svg_path.Line(svg_path.Point(-1.0, 0.0), svg_path.Point(0.0, 0.0)))
}

pub fn small_rotated_ellipse_identity_preserves_axes_test() {
  let assert Ok(#(radius, angle)) =
    ellipse.transformed_axes(
      radius: ellipse.EllipsePoint(0.00001, 0.00002),
      x_axis_rotation: 17.0,
      by: affine.identity(),
    )
  assert float.absolute_value(radius.x -. 0.00001) <. 1.0e-15
  assert float.absolute_value(radius.y -. 0.00002) <. 1.0e-15
  assert float.absolute_value(angle -. 17.0) <. 1.0e-9
}

pub fn coincident_signed_zero_endpoints_are_degenerate_test() {
  assert ellipse.endpoint_to_center(ellipse.EndpointArcData(
      ellipse.EllipsePoint(0.0, 0.0),
      ellipse.EllipsePoint(10.0, 10.0),
      0.0,
      False,
      True,
      ellipse.EllipsePoint(-0.0, 0.0),
    ))
    == Error(ellipse.DegenerateInputArc)
}

pub fn multi_turn_projection_extrema_include_each_visit_test() {
  let quarter =
    ellipse.CenterArcData(
      ellipse.EllipsePoint(0.0, 0.0),
      ellipse.EllipsePoint(1.0, 1.0),
      0.0,
      0.0,
      90.0,
    )
  let #(two_turns, _) = ellipse.arc_split(quarter, at: 8.0)
  assert ellipse.arc_projection_extrema(
      two_turns,
      ellipse.EllipsePoint(1.0, 0.0),
    )
    == [0.0, 0.25, 0.5, 0.75, 1.0]
  let #(reverse_turns, _) = ellipse.arc_split(quarter, at: -8.0)
  assert ellipse.arc_projection_extrema(
      reverse_turns,
      ellipse.EllipsePoint(1.0, 0.0),
    )
    == [0.0, 0.25, 0.5, 0.75, 1.0]
}

pub fn zero_sweep_has_no_isolated_projection_extrema_test() {
  let arc =
    ellipse.CenterArcData(
      ellipse.EllipsePoint(0.0, 0.0),
      ellipse.EllipsePoint(1.0, 1.0),
      0.0,
      0.0,
      0.0,
    )
  assert ellipse.arc_projection_extrema(arc, ellipse.EllipsePoint(1.0, 0.0))
    == []
}
