import gleam/int
import gleam/list
import gleam_community/maths
import svg_path
import svg_path/transform

pub fn cubic_specimens() -> List(#(String, svg_path.Segment)) {
  [
    #("endpoint_control_cubic", endpoint_control_cubic()),
    #("endpoint_control_cubic_translated", transform_segment(endpoint_control_cubic(), transform.translate(x: 37.0, y: -19.0))),
    #("endpoint_control_cubic_rotated", transform_segment(endpoint_control_cubic(), transform.rotate(degrees: 37.0))),
    #("near_cusp_cubic", near_cusp_cubic()),
    #("near_cusp_cubic_translated", transform_segment(near_cusp_cubic(), transform.translate(x: 37.0, y: -19.0))),
    #("near_cusp_cubic_scaled", transform_segment(near_cusp_cubic(), transform.scale(factor: 1.7))),
    #("far_control_cubic", far_control_cubic()),
    #("opposite_far_controls_cubic", opposite_far_controls_cubic()),
    #("wide_loop_cubic", wide_loop_cubic()),
    #("narrow_loop_cubic", narrow_loop_cubic()),
    ..generated_cubic_specimens()
  ]
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
