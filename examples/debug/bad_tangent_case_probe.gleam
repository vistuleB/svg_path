//// Scratch runner for a captured high-error loop tangent diagnostic case.
////
//// This module is parked in `examples/debug` so it is not compiled as part of
//// the package. To run it again, temporarily copy it to the project `src` root
//// and run:
////
////     gleam run -m bad_tangent_case_probe > bad_tangent_case_probe.svg

import gleam/io
import svg_path
import svg_path/svg

pub fn main() -> Nil {
  io.println(drawing_svg())
}

pub fn drawing_svg() -> String {
  let loop_a_start = svg_path.point(4.48, 9.06)
  let loop_a_vertex = svg_path.point(36.91, 89.67)
  let loop_b_point = svg_path.point(94.16, 49.8)

  svg.document(
    [
      svg.Rectangle(
        svg_path.point(0.0, 0.0),
        115.0,
        105.0,
        "fill: #fbfbf8; stroke: #d8d3c8; stroke-width: 0.4",
      ),
      path(
        svg_path.Path([
          svg_path.assert_subpath([
            svg_path.Line(start: loop_a_start, end: loop_a_vertex),
            svg_path.Line(start: loop_a_vertex, end: loop_a_start),
          ])
          |> svg_path.assert_set_closed(closed: True),
        ]),
        "fill: none; stroke: #2f6fbb; stroke-width: 1.2; stroke-linecap: round",
      ),
      path(
        line_path(loop_a_vertex, loop_b_point),
        "fill: none; stroke: #d64545; stroke-width: 1.2; stroke-dasharray: 2 2",
      ),
      svg.Circle(
        loop_a_start,
        1.2,
        "fill: #2f6fbb; stroke: white; stroke-width: 0.4",
      ),
      svg.Circle(
        loop_a_vertex,
        1.8,
        "fill: #f4b400; stroke: #5c4a00; stroke-width: 0.5",
      ),
      svg.Circle(
        loop_b_point,
        1.8,
        "fill: #2b2b2b; stroke: white; stroke-width: 0.5",
      ),
      svg.Text(
        "loop A is line-like",
        "fill: #2f6fbb; font-family: system-ui, sans-serif",
        svg_path.point(7.0, 16.0),
        4,
      ),
      svg.Text(
        "reported hull connector",
        "fill: #d64545; font-family: system-ui, sans-serif",
        svg_path.point(56.0, 74.0),
        4,
      ),
      svg.Text(
        "point-like loop B",
        "fill: #2b2b2b; font-family: system-ui, sans-serif",
        svg_path.point(73.0, 45.0),
        4,
      ),
      svg.Text(
        "same-segment refinement: None",
        "fill: #5b4a00; font-family: system-ui, sans-serif",
        svg_path.point(24.0, 98.0),
        4,
      ),
      svg.Text(
        "the red connector is the suspect hull line, not a tangent refinement",
        "fill: #5b4a00; font-family: system-ui, sans-serif",
        svg_path.point(10.0, 103.0),
        4,
      ),
    ],
    view_box: svg_path.BoundingBox(
      min: svg_path.point(0.0, 0.0),
      max: svg_path.point(115.0, 105.0),
    ),
  )
}

fn line_path(start: svg_path.Point, end: svg_path.Point) -> svg_path.Path {
  svg_path.Path([
    svg_path.assert_subpath([svg_path.Line(start:, end:)]),
  ])
}

fn path(path path: svg_path.Path, style style: String) -> svg.ThingToDraw {
  svg.StyledPath(path, style)
}
