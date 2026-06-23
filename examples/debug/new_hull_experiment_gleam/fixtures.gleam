import gleam/float
import gleam/int
import gleam/list
import gleam_community/maths
import svg_path
import svg_path/transform

pub fn arc_specimens() -> List(#(String, svg_path.Segment)) {
  [
    #("half_circle_arc", half_circle_arc(sweep: True)),
    #("half_circle_arc_reverse", half_circle_arc(sweep: False)),
    #("rotated_arc", rotated_arc(sweep: True)),
    #("rotated_arc_reverse", rotated_arc(sweep: False)),
    #("large_arc", large_arc(sweep: True)),
    #("large_arc_reverse", large_arc(sweep: False)),
    #("flat_arc", flat_arc(sweep: True)),
    #("flat_arc_reverse", flat_arc(sweep: False)),
    #("tall_arc", tall_arc(sweep: True)),
    #("tall_arc_reverse", tall_arc(sweep: False)),
    #("rotated_large_arc", rotated_large_arc(sweep: True)),
    #("rotated_large_arc_reverse", rotated_large_arc(sweep: False)),
    #("near_endpoint_arc", near_endpoint_arc(sweep: True)),
    #("near_endpoint_arc_reverse", near_endpoint_arc(sweep: False)),
    #("generated_arc_3", generated_arc(3)),
    #("generated_arc_11", generated_arc(11)),
    #("generated_arc_22", generated_arc(22)),
    #("generated_arc_3_reverse", svg_path.reverse_segment(generated_arc(3))),
    #("generated_arc_11_reverse", svg_path.reverse_segment(generated_arc(11))),
    #("generated_arc_22_reverse", svg_path.reverse_segment(generated_arc(22))),
  ]
}

pub fn cubic_specimens() -> List(#(String, svg_path.Segment)) {
  [
    #("endpoint_control_cubic", endpoint_control_cubic()),
    #(
      "endpoint_control_cubic_translated",
      transform_segment(
        endpoint_control_cubic(),
        transform.translate(x: 37.0, y: -19.0),
      ),
    ),
    #(
      "endpoint_control_cubic_rotated",
      transform_segment(
        endpoint_control_cubic(),
        transform.rotate(degrees: 37.0),
      ),
    ),
    #("near_cusp_cubic", near_cusp_cubic()),
    #(
      "near_cusp_cubic_translated",
      transform_segment(
        near_cusp_cubic(),
        transform.translate(x: 37.0, y: -19.0),
      ),
    ),
    #(
      "near_cusp_cubic_scaled",
      transform_segment(near_cusp_cubic(), transform.scale(factor: 1.7)),
    ),
    #("far_control_cubic", far_control_cubic()),
    #("opposite_far_controls_cubic", opposite_far_controls_cubic()),
    #("wide_loop_cubic", wide_loop_cubic()),
    #("narrow_loop_cubic", narrow_loop_cubic()),
    ..generated_cubic_specimens()
  ]
}

fn half_circle_arc(sweep sweep: Bool) -> svg_path.Segment {
  svg_path.arc(
    start: svg_path.point(20.0, 80.0),
    radius: svg_path.point(40.0, 40.0),
    x_axis_rotation: 0.0,
    large_arc: False,
    sweep: sweep,
    end: svg_path.point(100.0, 80.0),
  )
}

fn rotated_arc(sweep sweep: Bool) -> svg_path.Segment {
  svg_path.arc(
    start: svg_path.point(30.0, 80.0),
    radius: svg_path.point(55.0, 25.0),
    x_axis_rotation: 30.0,
    large_arc: False,
    sweep: sweep,
    end: svg_path.point(120.0, 40.0),
  )
}

fn large_arc(sweep sweep: Bool) -> svg_path.Segment {
  svg_path.arc(
    start: svg_path.point(20.0, 70.0),
    radius: svg_path.point(50.0, 35.0),
    x_axis_rotation: 0.0,
    large_arc: True,
    sweep: sweep,
    end: svg_path.point(100.0, 70.0),
  )
}

fn flat_arc(sweep sweep: Bool) -> svg_path.Segment {
  svg_path.arc(
    start: svg_path.point(-100.0, 0.0),
    radius: svg_path.point(120.0, 1.0),
    x_axis_rotation: 0.0,
    large_arc: False,
    sweep: sweep,
    end: svg_path.point(100.0, 0.0),
  )
}

fn tall_arc(sweep sweep: Bool) -> svg_path.Segment {
  svg_path.arc(
    start: svg_path.point(0.0, -100.0),
    radius: svg_path.point(1.0, 120.0),
    x_axis_rotation: 0.0,
    large_arc: False,
    sweep: sweep,
    end: svg_path.point(0.0, 100.0),
  )
}

fn rotated_large_arc(sweep sweep: Bool) -> svg_path.Segment {
  svg_path.arc(
    start: svg_path.point(-70.0, 20.0),
    radius: svg_path.point(95.0, 20.0),
    x_axis_rotation: 73.0,
    large_arc: True,
    sweep: sweep,
    end: svg_path.point(80.0, -10.0),
  )
}

fn near_endpoint_arc(sweep sweep: Bool) -> svg_path.Segment {
  svg_path.arc(
    start: svg_path.point(10.0, 10.0),
    radius: svg_path.point(40.0, 30.0),
    x_axis_rotation: 15.0,
    large_arc: False,
    sweep: sweep,
    end: svg_path.point(10.0001, 10.0001),
  )
}

fn generated_arc(i: Int) -> svg_path.Segment {
  let x = int.to_float(i) +. 1.0
  let scale = case i % 4 {
    0 -> 1.0
    1 -> 0.05
    2 -> 40.0
    _ -> 8.0
  }

  svg_path.arc(
    start: svg_path.point(scale *. wave(x, 5.0), scale *. wave(x, 7.0)),
    radius: svg_path.point(
      1.0 +. scale *. float.absolute_value(wave(x, 11.0)),
      1.0 +. scale *. float.absolute_value(wave(x, 13.0)),
    ),
    x_axis_rotation: normalize_degrees(wave(x, 17.0)),
    large_arc: i % 3 == 0,
    sweep: i % 2 == 0,
    end: svg_path.point(
      scale *. { wave(x, 19.0) +. 0.5 },
      scale *. { wave(x, 23.0) -. 0.5 },
    ),
  )
}

fn normalize_degrees(angle: Float) -> Float {
  case angle <. 0.0 {
    True -> normalize_degrees(angle +. 360.0)
    False ->
      case angle >=. 360.0 {
        True -> normalize_degrees(angle -. 360.0)
        False -> angle
      }
  }
}

fn transform_segment(
  segment: svg_path.Segment,
  matrix: transform.Matrix,
) -> svg_path.Segment {
  let assert Ok(segment) = transform.segment(segment, by: matrix)
  segment
}

fn endpoint_control_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(0.0, 0.0),
    control1: svg_path.point(0.0, 0.0),
    control2: svg_path.point(100.0, 0.0),
    end: svg_path.point(100.0, 0.0),
  )
}

fn near_cusp_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(0.0, 0.0),
    control1: svg_path.point(100.0, 0.0),
    control2: svg_path.point(-100.0, 0.0),
    end: svg_path.point(0.001, 0.0),
  )
}

fn far_control_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(0.0, 0.0),
    control1: svg_path.point(1000.0, 600.0),
    control2: svg_path.point(-900.0, 700.0),
    end: svg_path.point(100.0, 0.0),
  )
}

fn opposite_far_controls_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(-20.0, -10.0),
    control1: svg_path.point(500.0, -450.0),
    control2: svg_path.point(-520.0, 470.0),
    end: svg_path.point(30.0, 20.0),
  )
}

fn wide_loop_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(-80.0, 0.0),
    control1: svg_path.point(180.0, 160.0),
    control2: svg_path.point(-180.0, 160.0),
    end: svg_path.point(80.0, 0.0),
  )
}

fn narrow_loop_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(-5.0, 0.0),
    control1: svg_path.point(95.0, 120.0),
    control2: svg_path.point(-95.0, 120.0),
    end: svg_path.point(5.0, 0.0),
  )
}

fn generated_cubic_specimens() -> List(#(String, svg_path.Segment)) {
  int.range(from: 0, to: 35, with: [], run: fn(specimens, i) {
    [#("generated_cubic_" <> int.to_string(i), generated_cubic(i)), ..specimens]
  })
  |> list.reverse
}

fn generated_cubic(i: Int) -> svg_path.Segment {
  let x = int.to_float(i)
  let scale = case i % 4 {
    0 -> 1.0
    1 -> 0.01
    2 -> 100.0
    _ -> 10.0
  }

  svg_path.cubic_bezier(
    start: svg_path.point(scale *. wave(x, 3.0), scale *. wave(x, 11.0)),
    control1: svg_path.point(
      scale *. 4.0 *. wave(x, 17.0),
      scale *. 3.0 *. wave(x, 23.0),
    ),
    control2: svg_path.point(
      scale *. 4.0 *. wave(x, 31.0),
      scale *. 3.0 *. wave(x, 41.0),
    ),
    end: svg_path.point(scale *. wave(x, 47.0), scale *. wave(x, 59.0)),
  )
}

fn wave(i: Float, salt: Float) -> Float {
  maths.sin(i *. salt *. 12.9898) *. 50.0
}
