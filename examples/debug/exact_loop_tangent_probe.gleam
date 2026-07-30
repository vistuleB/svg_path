//// Scratch runner for the exact point-loop tangent probe drawing.
////
//// This module is parked in `examples/debug` so it is not compiled as part of
//// the package. To run it again, temporarily copy it to the project `src` root
//// and run:
////
////     gleam run -m exact_loop_tangent_probe > examples/debug/exact_loop_tangent_probe.svg

import gleam/io
import svg_path
import svg_path/svg

pub fn main() -> Nil {
  io.println(drawing_svg())
}

pub fn drawing_svg() -> String {
  svg.document(
    [
      panel(20.0, 20.0, 410.0, 320.0),
      panel(470.0, 20.0, 410.0, 320.0),
      axes(48.0, 180.0, 400.0, 180.0, 70.0, 290.0, 70.0, 70.0),
      axes(500.0, 290.0, 840.0, 290.0, 520.0, 310.0, 520.0, 30.0),
      styled_path(
        guide_rays(
          svg_path.Point(378.0, 180.0),
          svg_path.Point(213.367, 100.097),
          svg_path.Point(213.367, 259.903),
        ),
        guide_style(),
      ),
      styled_path(
        guide_rays(
          svg_path.Point(800.0, 190.0),
          svg_path.Point(740.0, 267.46),
          svg_path.Point(740.0, 112.54),
        ),
        guide_style(),
      ),
      styled_path(quadratic_lens_inside(), inside_style()),
      styled_path(quadratic_lens_outside(), outside_style()),
      styled_path(rounded_triangle_inside(), inside_style()),
      styled_path(rounded_triangle_outside(), outside_style()),
      marker(svg_path.Point(378.0, 180.0), 2.2, "#2b2b2b", "#2b2b2b"),
      marker(svg_path.Point(800.0, 190.0), 2.2, "#2b2b2b", "#2b2b2b"),
      marker(svg_path.Point(213.367, 100.097), 2.6, "#f4b400", "#5c4a00"),
      marker(svg_path.Point(213.367, 259.903), 2.6, "#f4b400", "#5c4a00"),
      marker(svg_path.Point(740.0, 267.46), 2.6, "#f4b400", "#5c4a00"),
      marker(svg_path.Point(740.0, 112.54), 2.6, "#f4b400", "#5c4a00"),
      svg.Text("Quadratic lens", label_style(), svg_path.Point(42.0, 48.0), 14),
      svg.Text(
        "both tangencies land inside curve pieces",
        small_label_style(),
        svg_path.Point(42.0, 70.0),
        12,
      ),
      svg.Text("Quadratic loop", label_style(), svg_path.Point(492.0, 48.0), 14),
      svg.Text(
        "exact tangent split lands inside the curve",
        small_label_style(),
        svg_path.Point(492.0, 70.0),
        12,
      ),
    ],
    view_box: svg_path.BoundingBox(
      min: svg_path.Point(0.0, 0.0),
      max: svg_path.Point(900.0, 360.0),
    ),
  )
}

fn panel(x: Float, y: Float, width: Float, height: Float) -> svg.ThingToDraw {
  svg.Rectangle(
    svg_path.Point(x, y),
    width,
    height,
    "fill: #fbfbf8; stroke: #d8d3c8; stroke-width: 1",
  )
}

fn axes(
  x1: Float,
  y1: Float,
  x2: Float,
  y2: Float,
  x3: Float,
  y3: Float,
  x4: Float,
  y4: Float,
) -> svg.ThingToDraw {
  styled_path(
    svg_path.Path([
      svg_path.subpath_assert([
        svg_path.Line(
          start: svg_path.Point(x1, y1),
          end: svg_path.Point(x2, y2),
        ),
      ]),
      svg_path.subpath_assert([
        svg_path.Line(
          start: svg_path.Point(x3, y3),
          end: svg_path.Point(x4, y4),
        ),
      ]),
    ]),
    "fill: none; stroke: #ded8cc; stroke-width: 0.75",
  )
}

fn guide_rays(
  point: svg_path.Point,
  first: svg_path.Point,
  second: svg_path.Point,
) -> svg_path.Path {
  svg_path.Path([
    svg_path.subpath_assert([svg_path.Line(start: point, end: first)]),
    svg_path.subpath_assert([svg_path.Line(start: point, end: second)]),
  ])
}

fn quadratic_lens_inside() -> svg_path.Path {
  svg_path.Path([
    svg_path.subpath_assert([
      svg_path.QuadraticBezier(
        start: svg_path.Point(213.367, 259.903),
        control: svg_path.Point(141.684, 294.694),
        end: svg_path.Point(70.0, 180.0),
      ),
      svg_path.QuadraticBezier(
        start: svg_path.Point(70.0, 180.0),
        control: svg_path.Point(141.684, 65.306),
        end: svg_path.Point(213.367, 100.097),
      ),
    ]),
  ])
}

fn quadratic_lens_outside() -> svg_path.Path {
  svg_path.Path([
    svg_path.subpath_assert([
      svg_path.QuadraticBezier(
        start: svg_path.Point(213.367, 100.097),
        control: svg_path.Point(251.684, 118.694),
        end: svg_path.Point(290.0, 180.0),
      ),
      svg_path.QuadraticBezier(
        start: svg_path.Point(290.0, 180.0),
        control: svg_path.Point(251.684, 241.306),
        end: svg_path.Point(213.367, 259.903),
      ),
    ]),
  ])
}

fn rounded_triangle_inside() -> svg_path.Path {
  svg_path.Path([
    svg_path.subpath_assert([
      svg_path.QuadraticBezier(
        start: svg_path.Point(740.0, 112.54),
        control: svg_path.Point(731.27, 101.27),
        end: svg_path.Point(720.0, 90.0),
      ),
      svg_path.Line(
        start: svg_path.Point(720.0, 90.0),
        end: svg_path.Point(520.0, 290.0),
      ),
      svg_path.Line(
        start: svg_path.Point(520.0, 290.0),
        end: svg_path.Point(720.0, 290.0),
      ),
      svg_path.QuadraticBezier(
        start: svg_path.Point(720.0, 290.0),
        control: svg_path.Point(731.27, 278.73),
        end: svg_path.Point(740.0, 267.46),
      ),
    ]),
  ])
}

fn rounded_triangle_outside() -> svg_path.Path {
  svg_path.Path([
    svg_path.subpath_assert([
      svg_path.QuadraticBezier(
        start: svg_path.Point(740.0, 267.46),
        control: svg_path.Point(800.0, 190.0),
        end: svg_path.Point(740.0, 112.54),
      ),
    ]),
  ])
}

fn marker(
  center: svg_path.Point,
  radius: Float,
  fill: String,
  stroke: String,
) -> svg.ThingToDraw {
  svg.Circle(
    center,
    radius,
    "fill: " <> fill <> "; stroke: " <> stroke <> "; stroke-width: 1",
  )
}

fn styled_path(path: svg_path.Path, style: String) -> svg.ThingToDraw {
  svg.StyledPath(path, style)
}

fn inside_style() -> String {
  "fill: none; stroke: #2f6fbb; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round"
}

fn outside_style() -> String {
  "fill: none; stroke: #d64545; stroke-width: 2.25; stroke-linecap: round; stroke-linejoin: round"
}

fn guide_style() -> String {
  "fill: none; stroke: #777; stroke-width: 1; stroke-dasharray: 4 4"
}

fn label_style() -> String {
  "fill: #2b2b2b; font-family: system-ui, sans-serif"
}

fn small_label_style() -> String {
  "fill: #595959; font-family: system-ui, sans-serif"
}
