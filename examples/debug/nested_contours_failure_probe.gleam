//// Debug drawing for the undirected nested-contour discussion.

import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/list
import gleam/string
import svg_path
import svg_path/arrangement
import svg_path/arrangement/drawing as arrangement_drawing
import svg_path/svg
import svg_path/transform

const output = "examples/debug/nested_contours_failure_probe.svg"

pub fn main() -> Dynamic {
  let outer =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(100.0, 0.0),
      svg_path.Point(100.0, 100.0),
      svg_path.Point(0.0, 100.0),
    ])
  let inner =
    svg_path.subpath_assert_polygon([
      svg_path.Point(35.0, 35.0),
      svg_path.Point(65.0, 35.0),
      svg_path.Point(65.0, 65.0),
      svg_path.Point(35.0, 65.0),
    ])
  let source = svg_path.Path([outer, inner])
  let assert Ok(build) =
    arrangement.build([source], tolerance: 0.001, minimum_chord: 0.001)
  let arrangement.ArrangementGraphBuild(graph:, ..) = build
  let undirected = arrangement.to_undirected(graph)
  let assert Ok(traced) =
    arrangement.undirected_nested_contours(undirected, tolerance: 0.001)

  write_file(output, render(source, graph, traced))
}

fn render(
  source: svg_path.Path,
  graph: arrangement.ArrangementGraph,
  traced: List(svg_path.Subpath),
) -> String {
  let source_panel =
    panel(
      source,
      origin_x: 0.0,
      title: "source path: two same-direction nested squares",
      extra: source_arrows(source, 0.0),
    )
  let graph_panel =
    panel(
      graph_as_path(graph),
      origin_x: 150.0,
      title: "undirected even arrangement graph",
      extra: graph_vertices(graph, 150.0),
    )
  let traced_panel =
    panel(
      svg_path.Path(traced),
      origin_x: 300.0,
      title: "current undirected_nested_contours trace",
      extra: contour_arrows(traced, 300.0),
    )
  svg.document(
    things: list.flatten([source_panel, graph_panel, traced_panel]),
    view_box: svg_path.BoundingBox(
      min: svg_path.Point(-15.0, -25.0),
      max: svg_path.Point(430.0, 125.0),
    ),
  )
  |> with_root_size(width: 1600, height: 540)
}

fn panel(
  path: svg_path.Path,
  origin_x origin_x: Float,
  title title: String,
  extra extra: svg.ThingsToDraw,
) -> svg.ThingsToDraw {
  [
    svg.Rectangle(
      svg_path.Point(origin_x -. 10.0, -10.0),
      120.0,
      120.0,
      "fill: #f8fafc; stroke: #cbd5e1; stroke-width: 0.5",
    ),
    svg.StyledPath(
      translate_path(path, origin_x),
      "fill: none; stroke: #334155; stroke-width: 2.5; stroke-linejoin: round",
    ),
    svg.Text(
      title,
      "fill: #0f172a; font-family: ui-sans-serif, sans-serif; text-anchor: middle",
      svg_path.Point(origin_x +. 50.0, 120.0),
      5,
    ),
  ]
  |> list.append(extra)
}

fn graph_as_path(graph: arrangement.ArrangementGraph) -> svg_path.Path {
  let arrangement.ArrangementGraph(edges:, ..) = graph
  svg_path.Path(
    edges
    |> list.map(fn(edge) {
      let arrangement.ArrangementEdge(segment:, ..) = edge
      svg_path.subpath_assert([segment])
    }),
  )
}

fn source_arrows(path: svg_path.Path, origin_x: Float) -> svg.ThingsToDraw {
  arrangement_drawing.path_direction_arrows_with(
    translate_path(path, origin_x),
    "#2563eb",
    length_scale: 0.7,
    width_scale: 0.7,
    arrival_offset: 0.0,
    opacity: 0.9,
  )
}

fn contour_arrows(
  contours: List(svg_path.Subpath),
  origin_x: Float,
) -> svg.ThingsToDraw {
  arrangement_drawing.path_direction_arrows_with(
    translate_path(svg_path.Path(contours), origin_x),
    "#dc2626",
    length_scale: 0.7,
    width_scale: 0.7,
    arrival_offset: 0.0,
    opacity: 0.9,
  )
}

fn graph_vertices(
  graph: arrangement.ArrangementGraph,
  origin_x: Float,
) -> svg.ThingsToDraw {
  let arrangement.ArrangementGraph(vertices:, ..) = graph
  vertices
  |> list.map(fn(vertex) {
    let arrangement.ArrangementVertex(point:, ..) = vertex
    svg.Circle(
      svg_path.Point(point.x +. origin_x, point.y),
      2.0,
      "fill: #0f172a; stroke: white; stroke-width: 0.6",
    )
  })
}

fn translate_path(path: svg_path.Path, dx: Float) -> svg_path.Path {
  let assert Ok(translated) = transform.translate_path(path, x: dx, y: 0.0)
  translated
}

fn with_root_size(
  svg_document: String,
  width width: Int,
  height height: Int,
) -> String {
  let assert Ok(#(before_width, after_width)) =
    string.split_once(svg_document, on: "\" width=\"")
  let assert Ok(#(_, after_height)) =
    string.split_once(after_width, on: "\" height=\"")
  let assert Ok(#(_, rest)) = string.split_once(after_height, on: "\">")

  before_width
  <> "\" width=\""
  <> int.to_string(width)
  <> "\" height=\""
  <> int.to_string(height)
  <> "\">"
  <> rest
}

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
