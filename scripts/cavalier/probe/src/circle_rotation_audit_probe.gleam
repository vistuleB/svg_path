import gleam/list
import svg_path/ellipse

pub fn main() {
  list.each([0.0, 17.0, 37.0, 73.0, 90.0, 137.0, 359.0], fn(rotation) {
    let assert Ok(arc) =
      ellipse.endpoint_to_center(ellipse.EndpointArcData(
        ellipse.EllipsePoint(-555.8531980329952, -831.2804714634476),
        ellipse.EllipsePoint(1000.0, 1000.0),
        rotation,
        False,
        True,
        ellipse.EllipsePoint(555.8531980329952, 831.2804714634476),
      ))
    echo #(rotation, arc.center)
  })
}
