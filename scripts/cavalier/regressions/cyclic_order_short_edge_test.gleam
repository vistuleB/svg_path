// Original candidate regression from the pre-fix investigation.
// Permanent expanded coverage: test/svg_path_cyclic_order_short_edge_test.gleam.
import svg_path.{Line, Point}
import svg_path/arrangement

pub fn perpendicular_short_edge_cyclic_order_test() {
  let assert Ok(_) =
    arrangement.build_with(
      [
        Line(Point(0.0, 0.0), Point(1.0, 0.0)),
        Line(Point(0.0, 0.0), Point(0.0, 0.000003)),
      ],
      vertex_tolerance: 0.000001,
      minimum_length: 0.00000001,
      endpoint_sliver_tolerance: 0.0,
    )
}

pub fn perpendicular_slightly_longer_edge_control_test() {
  let assert Ok(_) =
    arrangement.build_with(
      [
        Line(Point(0.0, 0.0), Point(1.0, 0.0)),
        Line(Point(0.0, 0.0), Point(0.0, 0.0000031)),
      ],
      vertex_tolerance: 0.000001,
      minimum_length: 0.00000001,
      endpoint_sliver_tolerance: 0.0,
    )
}
