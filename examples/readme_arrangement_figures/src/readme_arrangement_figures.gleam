//// Generate ArrangementGraph figures used by the README.

import gleam/dynamic.{type Dynamic}
import gleam/list
import svg_path
import svg_path/arrangement_graph
import svg_path/arrangement_graph/drawing
import svg_path/svg

const tolerance = 0.000001

const minimum_chord = 0.00001

pub fn main() -> Dynamic {
  let _ =
    write_file(
      "../debug/arrangement_graph_overlapping_squares.svg",
      overlapping_squares(),
    )
  write_file(
    "../debug/arrangement_graph_semantic_circle_overlap.svg",
    semantic_circle_overlap(),
  )
}

fn semantic_circle_overlap() -> String {
  let phase_offset = 91.92388155425118
  let left_clockwise =
    circle_path(
      svg_path.Point(365.0, 240.0),
      svg_path.Point(105.0, 240.0),
      130.0,
      True,
    )
  let left_counterclockwise =
    circle_path(
      svg_path.Point(235.0 +. phase_offset, 240.0 +. phase_offset),
      svg_path.Point(235.0 -. phase_offset, 240.0 -. phase_offset),
      130.0,
      False,
    )
  let graph_source =
    svg_path.Path([
      circle_subpath(
        svg_path.Point(835.0, 240.0),
        svg_path.Point(575.0, 240.0),
        130.0,
        True,
      ),
      circle_subpath(
        svg_path.Point(705.0 +. phase_offset, 240.0 +. phase_offset),
        svg_path.Point(705.0 -. phase_offset, 240.0 -. phase_offset),
        130.0,
        False,
      ),
    ])
  let assert Ok(arrangement_graph.ArrangementGraphBuild(
    graph:,
    normalized_paths: [normalized_source],
  )) = arrangement_graph.build([graph_source], tolerance:, minimum_chord:)
  let assert Ok(graph_things) =
    drawing.annotated_drawing(graph, normalized_source, tolerance:)

  svg.document(
    list.flatten([
      [
        svg.Rectangle(
          svg_path.Point(0.0, 0.0),
          940.0,
          520.0,
          "fill: #f8fafc; stroke: none",
        ),
        svg.StyledPath(
          svg_path.Path([
            svg_path.subpath_assert([
              svg_path.Line(
                start: svg_path.Point(470.0, 30.0),
                end: svg_path.Point(470.0, 470.0),
              ),
            ]),
          ]),
          "fill: none; stroke: #cbd5e1; stroke-width: 1",
        ),
        svg.Text(
          "Two input subpaths",
          heading_style(),
          svg_path.Point(235.0, 48.0),
          20,
        ),
        svg.Text(
          "Arrangement graph",
          heading_style(),
          svg_path.Point(705.0, 48.0),
          20,
        ),
        svg.StyledPath(left_clockwise, source_style("#2563eb")),
        svg.StyledPath(left_counterclockwise, source_style("#ea580c")),
        svg.Circle(
          svg_path.Point(115.0, 405.0),
          7.0,
          "fill: #2563eb; fill-opacity: 0.72; stroke: none",
        ),
        svg.Text(
          "subpath 1: clockwise",
          legend_style("#1d4ed8", "start"),
          svg_path.Point(130.0, 410.0),
          14,
        ),
        svg.Circle(
          svg_path.Point(115.0, 431.0),
          7.0,
          "fill: #ea580c; fill-opacity: 0.72; stroke: none",
        ),
        svg.Text(
          "subpath 2: counterclockwise, +45° phase",
          legend_style("#c2410c", "start"),
          svg_path.Point(130.0, 436.0),
          14,
        ),
        svg.Text(
          "4 vertices · 4 geometric edges · every edge has one occurrence per direction",
          legend_style("#475569", "middle"),
          svg_path.Point(705.0, 424.0),
          14,
        ),
        svg.Text(
          "Adversarial semantic-overlap case: equal circles, incompatible arc subdivision",
          legend_style("#64748b", "middle"),
          svg_path.Point(470.0, 493.0),
          14,
        ),
      ],
      drawing.path_direction_arrows_with(
        left_clockwise,
        "#2563eb",
        length_scale: 4.0,
        width_scale: 4.0,
        arrival_offset: 0.0,
        opacity: 0.58,
      ),
      drawing.path_direction_arrows_with(
        left_counterclockwise,
        "#ea580c",
        length_scale: 4.0,
        width_scale: 4.0,
        arrival_offset: 0.0,
        opacity: 0.58,
      ),
      graph_things,
    ]),
    view_box: svg_path.BoundingBox(
      min: svg_path.Point(0.0, 0.0),
      max: svg_path.Point(940.0, 520.0),
    ),
  )
}

fn overlapping_squares() -> String {
  let left_first = square(80.0, 90.0, 260.0, 270.0)
  let left_second = square(170.0, 180.0, 350.0, 360.0)
  let graph_source =
    svg_path.Path([
      square_subpath(560.0, 90.0, 740.0, 270.0),
      square_subpath(650.0, 180.0, 830.0, 360.0),
    ])
  let assert Ok(arrangement_graph.ArrangementGraphBuild(
    graph:,
    normalized_paths: [normalized_source],
  )) = arrangement_graph.build([graph_source], tolerance:, minimum_chord:)
  let assert Ok(graph_things) =
    drawing.annotated_drawing(graph, normalized_source, tolerance:)

  svg.document(
    list.flatten([
      [
        svg.Rectangle(
          svg_path.Point(0.0, 0.0),
          960.0,
          500.0,
          "fill: #f8fafc; stroke: none",
        ),
        svg.StyledPath(
          svg_path.Path([
            svg_path.subpath_assert([
              svg_path.Line(
                start: svg_path.Point(455.0, 30.0),
                end: svg_path.Point(455.0, 450.0),
              ),
            ]),
          ]),
          "fill: none; stroke: #cbd5e1; stroke-width: 1",
        ),
        svg.Text(
          "Two input subpaths",
          heading_style(),
          svg_path.Point(225.0, 48.0),
          20,
        ),
        svg.Text(
          "Arrangement graph",
          heading_style(),
          svg_path.Point(705.0, 48.0),
          20,
        ),
        svg.StyledPath(left_first, source_style("#2563eb")),
        svg.StyledPath(left_second, source_style("#ea580c")),
        svg.Circle(
          svg_path.Point(110.0, 410.0),
          6.0,
          "fill: #2563eb; fill-opacity: 0.7; stroke: none",
        ),
        svg.Text(
          "subpath 1",
          legend_style("#1d4ed8", "start"),
          svg_path.Point(123.0, 415.0),
          13,
        ),
        svg.Circle(
          svg_path.Point(250.0, 410.0),
          6.0,
          "fill: #ea580c; fill-opacity: 0.7; stroke: none",
        ),
        svg.Text(
          "subpath 2",
          legend_style("#c2410c", "start"),
          svg_path.Point(263.0, 415.0),
          13,
        ),
        svg.Text(
          "10 vertices · 12 edges · no geometric overlaps",
          legend_style("#475569", "middle"),
          svg_path.Point(705.0, 410.0),
          13,
        ),
        svg.Text(
          "black: winding L/R · red: ↑forward/reverse↓ multiplicity",
          legend_style("#64748b", "start"),
          svg_path.Point(480.0, 478.0),
          12,
        ),
      ],
      drawing.path_direction_arrows_with(
        left_first,
        "#2563eb",
        length_scale: 4.0,
        width_scale: 4.0,
        arrival_offset: 0.0,
        opacity: 0.58,
      ),
      drawing.path_direction_arrows_with(
        left_second,
        "#ea580c",
        length_scale: 4.0,
        width_scale: 4.0,
        arrival_offset: 0.0,
        opacity: 0.58,
      ),
      graph_things,
    ]),
    view_box: svg_path.BoundingBox(
      min: svg_path.Point(0.0, 0.0),
      max: svg_path.Point(960.0, 500.0),
    ),
  )
}

fn square(
  min_x: Float,
  min_y: Float,
  max_x: Float,
  max_y: Float,
) -> svg_path.Path {
  svg_path.Path([square_subpath(min_x, min_y, max_x, max_y)])
}

fn square_subpath(
  min_x: Float,
  min_y: Float,
  max_x: Float,
  max_y: Float,
) -> svg_path.Subpath {
  svg_path.subpath_assert_polygon([
    svg_path.Point(min_x, min_y),
    svg_path.Point(max_x, min_y),
    svg_path.Point(max_x, max_y),
    svg_path.Point(min_x, max_y),
  ])
}

fn circle_path(
  start: svg_path.Point,
  opposite: svg_path.Point,
  radius: Float,
  sweep: Bool,
) -> svg_path.Path {
  svg_path.Path([circle_subpath(start, opposite, radius, sweep)])
}

fn circle_subpath(
  start: svg_path.Point,
  opposite: svg_path.Point,
  radius: Float,
  sweep: Bool,
) -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.Arc(
      start:,
      radius: svg_path.Point(radius, radius),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep:,
      end: opposite,
    ),
    svg_path.Arc(
      start: opposite,
      radius: svg_path.Point(radius, radius),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep:,
      end: start,
    ),
  ])
  |> svg_path.subpath_assert_set_closed(closed: True)
}

fn heading_style() -> String {
  "fill: #0f172a; font-family: system-ui, sans-serif; font-weight: 650; text-anchor: middle"
}

fn source_style(color: String) -> String {
  "fill: none; stroke: " <> color <> "; stroke-width: 7; stroke-opacity: 0.58"
}

fn legend_style(color: String, anchor: String) -> String {
  "fill: "
  <> color
  <> "; font-family: system-ui, sans-serif; text-anchor: "
  <> anchor
}

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
