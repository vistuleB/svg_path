import svg_path
import svg_path/offset

pub fn negative_zero_endpoint_has_forward_unit_tangent_test() {
  let segment =
    svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(1.0, 0.0))
  assert offset.unit_tangent(segment, t: -0.0) == Ok(svg_path.Point(1.0, 0.0))
}
