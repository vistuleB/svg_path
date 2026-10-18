// Reduced native regression from the Cavalier Contours cyclic-order audit.
import gleam/list
import gleeunit/should
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

pub fn short_edge_order_is_scale_independent_test() {
  list.each([0.001, 1.0, 1000.0], fn(scale) {
    let assert Ok(arrangement.ArrangementSegmentBuild(graph:, ..)) =
      arrangement.build_with(
        [
          Line(Point(0.0, 0.0), Point(scale, 0.0)),
          Line(Point(0.0, 0.000003 *. scale), Point(0.0, 0.0)),
        ],
        vertex_tolerance: 0.000001 *. scale,
        minimum_length: 0.00000001 *. scale,
        endpoint_sliver_tolerance: 0.0,
      )
    let assert Ok(order) =
      arrangement.vertex_cyclic_order_with(
        graph,
        vertex_id: 0,
        tolerance: 0.000001 *. scale,
        max_attempts: 3,
      )
    order
    |> should.equal([
      [arrangement.OrientedArrangementEdge(0, False)],
      [arrangement.OrientedArrangementEdge(1, True)],
    ])
  })
}

pub fn short_arc_with_clustered_offset_start_test() {
  list.each([False, True], fn(reversed) {
    let start = Point(0.0, 0.0000009)
    let end = Point(0.0, 0.000003)
    let arc =
      svg_path.Arc(
        start: case reversed {
          True -> end
          False -> start
        },
        radius: Point(0.000003, 0.000003),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: !reversed,
        end: case reversed {
          True -> start
          False -> end
        },
      )
    let assert Ok(arrangement.ArrangementSegmentBuild(graph:, ..)) =
      arrangement.build_with(
        [Line(Point(0.0, 0.0), Point(1.0, 0.0)), arc],
        vertex_tolerance: 0.000001,
        minimum_length: 0.00000001,
        endpoint_sliver_tolerance: 0.0,
      )
    let assert Ok(order) =
      arrangement.vertex_cyclic_order_with(
        graph,
        vertex_id: 0,
        tolerance: 0.000001,
        max_attempts: 3,
      )
    order
    |> should.equal([
      [arrangement.OrientedArrangementEdge(1, reversed)],
      [arrangement.OrientedArrangementEdge(0, False)],
    ])
  })
}
