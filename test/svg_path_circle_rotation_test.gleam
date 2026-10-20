import gleam/float
import gleam/list
import svg_path/ellipse.{EllipsePoint, EndpointArcData}

pub fn near_semicircle_circle_rotation_invariance_test() {
  list.each([0.0, 10_000.0], fn(shift) {
    list.each([False, True], fn(large) {
      list.each([False, True], fn(sweep) {
        let input =
          EndpointArcData(
            EllipsePoint(shift -. 555.8531980329952, shift -. 831.2804714634476),
            EllipsePoint(1000.0, 1000.0),
            0.0,
            large,
            sweep,
            EllipsePoint(shift +. 555.8531980329952, shift +. 831.2804714634476),
          )
        let assert Ok(reference) = ellipse.endpoint_to_center(input)
        list.each(
          [17.0, 37.0, 73.0, 90.0, 137.0, 359.0, -37.0, 397.0],
          fn(rotation) {
            let assert Ok(actual) =
              ellipse.endpoint_to_center(
                EndpointArcData(..input, x_axis_rotation: rotation),
              )
            assert actual.center == reference.center
            assert actual.radius == reference.radius
            assert actual.delta_angle == reference.delta_angle
            assert actual.x_axis_rotation == rotation
            list.each([0.0, 0.25, 0.5, 0.75, 1.0], fn(at) {
              close_point(
                ellipse.arc_point(actual, at),
                ellipse.arc_point(reference, at),
              )
            })
            let a = ellipse.arc_bounding_box(actual)
            let b = ellipse.arc_bounding_box(reference)
            close_point(a.min, b.min)
            close_point(a.max, b.max)
          },
        )
      })
    })
  })
}

pub fn rotated_circle_radius_correction_and_sign_test() {
  list.each([0.5, 1.0, -0.5, -1.0], fn(radius) {
    list.each([37.0, -37.0, 450.0], fn(rotation) {
      let assert Ok(arc) =
        ellipse.endpoint_to_center(EndpointArcData(
          EllipsePoint(-1.0, 0.0),
          EllipsePoint(radius, 0.0 -. radius),
          rotation,
          False,
          True,
          EllipsePoint(1.0, 0.0),
        ))
      assert arc.center == EllipsePoint(0.0, 0.0)
      assert arc.radius == EllipsePoint(1.0, 1.0)
      close_point(ellipse.arc_point(arc, 0.0), EllipsePoint(-1.0, 0.0))
      close_point(ellipse.arc_point(arc, 1.0), EllipsePoint(1.0, 0.0))
    })
  })
}

fn close_point(a: ellipse.EllipsePoint, b: ellipse.EllipsePoint) {
  assert float.absolute_value(a.x -. b.x) <. 0.00000000002
  assert float.absolute_value(a.y -. b.y) <. 0.00000000002
}
