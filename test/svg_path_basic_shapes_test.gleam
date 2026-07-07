import gleam/option.{None, Some}
import gleeunit
import svg_path
import svg_path/serialize
import svg_path/basic_shapes

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn rect_converts_to_svg_equivalent_path_test() {
  let assert Ok(subpath) =
    basic_shapes.rect(
      x: 10.0,
      y: 20.0,
      width: 100.0,
      height: 50.0,
      rx: None,
      ry: None,
    )

  assert serialize.subpath(subpath) == "M 10 20 H 110 V 70 H 10 Z"
}

pub fn rounded_rect_converts_to_svg_equivalent_path_test() {
  let assert Ok(subpath) =
    basic_shapes.rect(
      x: 10.0,
      y: 20.0,
      width: 100.0,
      height: 50.0,
      rx: Some(10.0),
      ry: Some(5.0),
    )

  assert serialize.subpath(subpath)
    == "M 20 20 H 100 A 10 5 0 0 1 110 25 V 65 A 10 5 0 0 1 100 70 H 20 A 10 5 0 0 1 10 65 V 25 A 10 5 0 0 1 20 20 Z"
}

pub fn rect_uses_single_radius_for_both_axes_test() {
  let assert Ok(subpath) =
    basic_shapes.rect(
      x: 0.0,
      y: 0.0,
      width: 20.0,
      height: 20.0,
      rx: Some(5.0),
      ry: None,
    )

  assert serialize.subpath(subpath)
    == "M 5 0 H 15 A 5 5 0 0 1 20 5 V 15 A 5 5 0 0 1 15 20 H 5 A 5 5 0 0 1 0 15 V 5 A 5 5 0 0 1 5 0 Z"
}

pub fn rect_clamps_corner_radii_test() {
  let assert Ok(subpath) =
    basic_shapes.rect(
      x: 0.0,
      y: 0.0,
      width: 20.0,
      height: 10.0,
      rx: Some(50.0),
      ry: Some(50.0),
    )

  assert serialize.subpath(subpath)
    == "M 10 0 H 10 A 10 5 0 0 1 20 5 H 20 A 10 5 0 0 1 10 10 H 10 A 10 5 0 0 1 0 5 H 0 A 10 5 0 0 1 10 0 Z"
}

pub fn circle_converts_to_svg_equivalent_path_test() {
  let assert Ok(subpath) = basic_shapes.circle(cx: 10.0, cy: 20.0, r: 5.0)

  assert serialize.subpath(subpath)
    == "M 15 20 A 5 5 0 0 0 10 25 A 5 5 0 0 0 5 20 A 5 5 0 0 0 10 15 A 5 5 0 0 0 15 20 Z"
}

pub fn ellipse_converts_to_svg_equivalent_path_test() {
  let assert Ok(subpath) =
    basic_shapes.ellipse(cx: 10.0, cy: 20.0, rx: 7.0, ry: 3.0)

  assert serialize.subpath(subpath)
    == "M 17 20 A 7 3 0 0 0 10 23 A 7 3 0 0 0 3 20 A 7 3 0 0 0 10 17 A 7 3 0 0 0 17 20 Z"
}

pub fn line_converts_to_subpath_test() {
  let assert Ok(subpath) =
    basic_shapes.line(x1: 1.0, y1: 2.0, x2: 3.0, y2: 4.0)

  assert serialize.subpath(subpath) == "M 1 2 L 3 4"
}

pub fn polyline_converts_points_to_open_subpath_test() {
  let assert Ok(subpath) =
    basic_shapes.polyline([
      svg_path.point(1.0, 2.0),
      svg_path.point(3.0, 4.0),
      svg_path.point(5.0, 4.0),
    ])

  assert serialize.subpath(subpath) == "M 1 2 L 3 4 H 5"
}

pub fn polygon_converts_points_to_closed_subpath_test() {
  let assert Ok(subpath) =
    basic_shapes.polygon([
      svg_path.point(1.0, 2.0),
      svg_path.point(3.0, 4.0),
      svg_path.point(5.0, 4.0),
    ])

  assert serialize.subpath(subpath) == "M 1 2 L 3 4 H 5 Z"
}

pub fn invalid_dimensions_return_errors_test() {
  assert basic_shapes.rect(
      x: 0.0,
      y: 0.0,
      width: -1.0,
      height: 2.0,
      rx: None,
      ry: None,
    )
    == Error(basic_shapes.InvalidRectWidth(-1.0))

  assert basic_shapes.circle(cx: 0.0, cy: 0.0, r: -1.0)
    == Error(basic_shapes.InvalidCircleRadius(-1.0))

  assert basic_shapes.ellipse(cx: 0.0, cy: 0.0, rx: 1.0, ry: -1.0)
    == Error(basic_shapes.InvalidEllipseRadiusY(-1.0))
}

pub fn disabled_rendering_returns_error_test() {
  assert basic_shapes.rect(
      x: 0.0,
      y: 0.0,
      width: 0.0,
      height: 2.0,
      rx: None,
      ry: None,
    )
    == Error(basic_shapes.DisabledRendering)

  assert basic_shapes.circle(cx: 0.0, cy: 0.0, r: 0.0)
    == Error(basic_shapes.DisabledRendering)

  assert basic_shapes.ellipse(cx: 0.0, cy: 0.0, rx: 1.0, ry: 0.0)
    == Error(basic_shapes.DisabledRendering)
}

pub fn invalid_point_lists_return_core_errors_test() {
  assert basic_shapes.polyline([])
    == Error(basic_shapes.Core(svg_path.EmptySubpath))

  assert basic_shapes.polygon([svg_path.point(1.0, 2.0)])
    == Error(basic_shapes.Core(svg_path.EmptySubpath))
}
