//// Scratch runner for visually checking `svg_path/svg` debug drawing helpers.
////
//// This module is parked in `examples/debug` so it is not compiled as part of
//// the package. To run it again, temporarily copy it to the project `src` root
//// and run:
////
////     gleam run -m svg_path_debug_drawing
////
//// Redirect stdout into `examples/debug/debug_drawing.svg` to refresh the
//// drawing.

import gleam/io
import svg_path
import svg_path/svg

pub fn main() -> Nil {
  io.println(drawing_svg())
}

pub fn drawing_svg() -> String {
  let stem =
    svg_path.assert_subpath([
      svg_path.CubicBezier(
        start: svg_path.point(5.0, 70.0),
        control1: svg_path.point(30.0, 20.0),
        control2: svg_path.point(65.0, 105.0),
        end: svg_path.point(95.0, 30.0),
      ),
    ])

  let leaf =
    svg_path.assert_subpath([
      svg_path.CubicBezier(
        start: svg_path.point(45.0, 45.0),
        control1: svg_path.point(55.0, 10.0),
        control2: svg_path.point(95.0, 15.0),
        end: svg_path.point(100.0, 50.0),
      ),
      svg_path.CubicBezier(
        start: svg_path.point(100.0, 50.0),
        control1: svg_path.point(78.0, 65.0),
        control2: svg_path.point(58.0, 63.0),
        end: svg_path.point(45.0, 45.0),
      ),
    ])
    |> svg_path.assert_set_closed(closed: True)

  let vein =
    svg_path.assert_subpath([
      svg_path.QuadraticBezier(
        start: svg_path.point(50.0, 47.0),
        control: svg_path.point(72.0, 35.0),
        end: svg_path.point(96.0, 49.0),
      ),
    ])

  let box =
    svg_path.BoundingBox(
      min: svg_path.point(0.0, 0.0),
      max: svg_path.point(110.0, 85.0),
    )

  svg.document(
    [
      svg.StyledPath(
        svg_path.Path([leaf]),
        "fill: #d8f3dc; stroke: #2d6a4f; stroke-width: 2.5",
      ),
      svg.StyledPath(
        svg_path.Path([stem]),
        "fill: none; stroke: #1d3557; stroke-width: 4; stroke-linecap: round",
      ),
      svg.StyledPath(
        svg_path.Path([vein]),
        "fill: none; stroke: #40916c; stroke-width: 1.5; stroke-linecap: round",
      ),
      svg.Text(
        "leaf",
        "fill: #2d6a4f; font-family: system-ui, sans-serif; font-weight: 700",
        svg_path.point(73.0, 27.0),
        8,
      ),
      svg.Text(
        "stem gap?",
        "fill: #e63946; font-family: system-ui, sans-serif",
        svg_path.point(10.0, 82.0),
        6,
      ),
      svg.Text(
        "support",
        "fill: #7209b7; font-family: system-ui, sans-serif",
        svg_path.point(4.0, 10.0),
        5,
      ),
      svg.Text(
        "t = 0.42",
        "fill: #f77f00; font-family: ui-monospace, monospace",
        svg_path.point(36.0, 33.0),
        4,
      ),
      svg.Text(
        "curve piece",
        "fill: #0077b6; font-family: system-ui, sans-serif",
        svg_path.point(55.0, 78.0),
        5,
      ),
      svg.Text(
        "hull?",
        "fill: #9d0208; font-family: Georgia, serif; font-style: italic",
        svg_path.point(92.0, 10.0),
        6,
      ),
    ],
    view_box: box,
  )
}
