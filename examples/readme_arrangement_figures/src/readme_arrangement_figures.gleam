//// Generate ArrangementGraph figures used by the README.

import gleam/dynamic.{type Dynamic}
import gleam/list
import svg_path
import svg_path/arrangement as arrangement_graph
import svg_path/arrangement/drawing
import svg_path/svg

const tolerance = 0.000001

const minimum_chord = 0.00001

const output_dir = "../../test/generated/readme"

pub fn main() -> Dynamic {
  let _ =
    write_file(
      output_dir <> "/arrangement_graph_overlapping_squares.svg",
      overlapping_squares(),
    )
  let _ =
    write_file(
      output_dir <> "/arrangement_graph_semantic_circle_overlap.svg",
      semantic_circle_overlap(),
    )
  write_file(
    output_dir <> "/zero_length_closepath_probe.svg",
    zero_length_closepath_probe(),
  )
}

fn zero_length_closepath_probe() -> String {
  let background =
    svg.Rectangle(
      svg_path.Point(-80.0, 0.0),
      500.0,
      360.0,
      "fill: white; stroke: none",
    )
  let guides =
    [50.0, 120.0, 230.0, 300.0]
    |> list.map(fn(y) {
      svg.StyledPath(
        svg_path.Path([
          svg_path.subpath_assert([
            svg_path.Line(
              start: svg_path.Point(20.0, y),
              end: svg_path.Point(390.0, y),
            ),
          ]),
        ]),
        "fill: none; stroke: #ddd; stroke-width: 1",
      )
    })
  let points =
    [50.0, 120.0, 230.0, 300.0]
    |> list.flat_map(fn(y) {
      [
        svg.Circle(svg_path.Point(90.0, y), 2.0, "fill: red; stroke: none"),
        svg.Circle(svg_path.Point(260.0, y), 2.0, "fill: red; stroke: none"),
      ]
    })
  let move_only = fn(x, y) {
    svg_path.Path([svg_path.subpath_empty(at: svg_path.Point(x, y))])
  }
  let zero_line = fn(x, y) {
    svg_path.Path([
      svg_path.subpath_assert([
        svg_path.Line(start: svg_path.Point(x, y), end: svg_path.Point(x, y)),
      ]),
    ])
  }
  let closed_move = fn(x, y) {
    svg_path.Path([
      svg_path.subpath_empty(at: svg_path.Point(x, y))
      |> svg_path.subpath_assert_set_closed(closed: True),
    ])
  }
  let round_style =
    "fill: none; stroke: #2563eb; stroke-width: 24; stroke-linecap: round"
  let square_style =
    "fill: none; stroke: #2563eb; stroke-width: 24; stroke-linecap: square"
  let close_round_style =
    "fill: none; stroke: #111827; stroke-width: 24; stroke-linecap: round"
  let close_square_style =
    "fill: none; stroke: #111827; stroke-width: 24; stroke-linecap: square"
  let labels = [
    svg.Text("M only", probe_heading_style(), svg_path.Point(90.0, 25.0), 12),
    svg.Text(
      "M then zero-length L",
      probe_heading_style(),
      svg_path.Point(260.0, 25.0),
      12,
    ),
    svg.Text("M only", probe_heading_style(), svg_path.Point(90.0, 205.0), 12),
    svg.Text(
      "M then Z",
      probe_heading_style(),
      svg_path.Point(260.0, 205.0),
      12,
    ),
    svg.Text(
      "linecap: round",
      probe_row_style(),
      svg_path.Point(10.0, 54.0),
      12,
    ),
    svg.Text(
      "linecap: square",
      probe_row_style(),
      svg_path.Point(10.0, 124.0),
      12,
    ),
    svg.Text(
      "linecap: round",
      probe_row_style(),
      svg_path.Point(10.0, 234.0),
      12,
    ),
    svg.Text(
      "linecap: square",
      probe_row_style(),
      svg_path.Point(10.0, 304.0),
      12,
    ),
    svg.Text("M 90,50", probe_code_style(), svg_path.Point(90.0, 78.0), 10),
    svg.Text(
      "M 260,50 L 260,50",
      probe_code_style(),
      svg_path.Point(260.0, 78.0),
      10,
    ),
    svg.Text("M 90,120", probe_code_style(), svg_path.Point(90.0, 148.0), 10),
    svg.Text(
      "M 260,120 L 260,120",
      probe_code_style(),
      svg_path.Point(260.0, 148.0),
      10,
    ),
    svg.Text("M 90,230", probe_code_style(), svg_path.Point(90.0, 258.0), 10),
    svg.Text(
      "M 260,230 Z",
      probe_code_style(),
      svg_path.Point(260.0, 258.0),
      10,
    ),
    svg.Text("M 90,300", probe_code_style(), svg_path.Point(90.0, 328.0), 10),
    svg.Text(
      "M 260,300 Z",
      probe_code_style(),
      svg_path.Point(260.0, 328.0),
      10,
    ),
  ]

  svg.document(
    [
      background,
      ..list.flatten([
        guides,
        points,
        labels,
        [
          svg.StyledPath(move_only(90.0, 50.0), round_style),
          svg.StyledPath(zero_line(260.0, 50.0), round_style),
          svg.StyledPath(move_only(90.0, 120.0), square_style),
          svg.StyledPath(zero_line(260.0, 120.0), square_style),
          svg.StyledPath(move_only(90.0, 230.0), close_round_style),
          svg.StyledPath(closed_move(260.0, 230.0), close_round_style),
          svg.StyledPath(move_only(90.0, 300.0), close_square_style),
          svg.StyledPath(closed_move(260.0, 300.0), close_square_style),
        ],
      ])
    ],
    view_box: svg_path.BoundingBox(
      min: svg_path.Point(-80.0, 0.0),
      max: svg_path.Point(420.0, 360.0),
    ),
  )
}

fn probe_heading_style() -> String {
  "fill: #111827; font-family: system-ui, sans-serif; font-weight: 700; text-anchor: middle"
}

fn probe_row_style() -> String {
  "fill: #111827; font-family: system-ui, sans-serif; text-anchor: end"
}

fn probe_code_style() -> String {
  "fill: #111827; font-family: monospace; text-anchor: middle"
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
    ..,
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
          "4 vertices · 4 geometric edges",
          legend_style("#475569", "middle"),
          svg_path.Point(705.0, 410.0),
          14,
        ),
        svg.Text(
          "every edge has one occurrence per direction",
          legend_style("#475569", "middle"),
          svg_path.Point(705.0, 436.0),
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
    ..,
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
