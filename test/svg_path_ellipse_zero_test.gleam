import gleam/list
import svg_path/ellipse

pub fn signed_zero_split_parameters_are_canonical_test() {
  let arc = arc()
  assert ellipse.arc_split_many(arc, at: [-0.0, 0.0]) == [arc]
  assert ellipse.arc_split_many_inside(arc, at: [-0.0, 0.0]) == Ok([arc])
  let expected = ellipse.arc_split_many(arc, at: [-0.5, 0.0, 0.5])
  assert list.length(expected) == 4
  assert ellipse.arc_split_many(arc, at: [-0.5, -0.0, 0.0, 0.5]) == expected
}

pub fn either_zero_direction_has_no_projection_extrema_test() {
  list.each([0.0, -0.0], fn(x) {
    list.each([0.0, -0.0], fn(y) {
      assert ellipse.arc_projection_extrema(
          arc(),
          direction: ellipse.EllipsePoint(x, y),
        )
        == []
    })
  })
}

fn arc() -> ellipse.CenterArcData {
  ellipse.CenterArcData(
    center: ellipse.EllipsePoint(0.0, 0.0),
    radius: ellipse.EllipsePoint(1.0, 1.0),
    x_axis_rotation: 0.0,
    start_angle: 0.0,
    delta_angle: 360.0,
  )
}
