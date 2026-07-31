//// Debug figure generator for graph-based intersection cases.

import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/list
import svg_path
import svg_path/planar_graph
import svg_path/svg
import svg_path/transform

const tolerance = 0.000001

const minimum_chord = 0.00001

pub fn main() -> Dynamic {
  let cases = [
    #(
      "intersection_rectangles.svg",
      "overlapping rectangles",
      rectangle(0.0, 0.0, 80.0, 80.0),
      rectangle(40.0, 0.0, 120.0, 80.0),
      svg_path.Nonzero,
    ),
    #(
      "intersection_circle_rectangle.svg",
      "circle and rectangle",
      circle(svg_path.Point(55.0, 50.0), 45.0),
      rectangle(45.0, 0.0, 105.0, 100.0),
      svg_path.Nonzero,
    ),
    #(
      "intersection_nested_nonzero.svg",
      "nested contours · nonzero",
      nested_rectangles(),
      rectangle(42.0, 32.0, 78.0, 68.0),
      svg_path.Nonzero,
    ),
    #(
      "intersection_nested_evenodd.svg",
      "nested contours · even–odd",
      nested_rectangles(),
      rectangle(42.0, 32.0, 78.0, 68.0),
      svg_path.EvenOdd,
    ),
    #(
      "intersection_bowtie_rectangle.svg",
      "self-crossing contour",
      bowtie(),
      rectangle(35.0, 25.0, 88.0, 82.0),
      svg_path.Nonzero,
    ),
    #(
      "intersection_edge_tangent.svg",
      "edge-tangent rectangles",
      rectangle(0.0, 0.0, 60.0, 80.0),
      rectangle(60.0, 15.0, 120.0, 65.0),
      svg_path.Nonzero,
    ),
  ]
  list.each(cases, fn(entry) {
    let #(name, title, left, right, rule) = entry
    let _ =
      write_file(
        "examples/debug/" <> name,
        render_case(title, left, right, rule),
      )
  })
  dyn_nil()
}

fn render_case(
  title: String,
  left: svg_path.Path,
  right: svg_path.Path,
  rule: svg_path.FillRule,
) -> String {
  let fill_rule_style = case rule {
    svg_path.Nonzero -> "nonzero"
    svg_path.EvenOdd -> "evenodd"
  }
  let source =
    svg_path.Path(list.append(
      svg_path.path_subpaths(left),
      svg_path.path_subpaths(right),
    ))
  let assert Ok(source_placed) = fit(source, 150.0, 132.0)
  let source_parts = svg_path.path_subpaths(source_placed)
  let left_count = list.length(svg_path.path_subpaths(left))
  let left_placed = svg_path.Path(list.take(source_parts, left_count))
  let right_placed = svg_path.Path(list.drop(source_parts, left_count))

  let assert Ok(graph_source) = fit(source, 450.0, 132.0)
  let assert Ok(graph) =
    planar_graph.from_subpaths(
      svg_path.path_subpaths(graph_source),
      tolerance:,
      minimum_chord:,
    )
  let assert Ok(graph_drawing) =
    planar_graph.annotated_things_to_draw(graph, graph_source, tolerance:)
  let assert Ok(intersection) =
    planar_graph.intersection_paths(
      left,
      right,
      using: rule,
      tolerance:,
      minimum_chord:,
    )
  let intersection_placed = case svg_path.path_subpaths(intersection) {
    [] -> intersection
    _ -> {
      let assert Ok(value) = fit(intersection, 750.0, 132.0)
      value
    }
  }

  let base = [
    svg.Rectangle(
      svg_path.Point(0.0, 0.0),
      900.0,
      260.0,
      "fill: #f8fafc; stroke: none",
    ),
    svg.Text(
      title,
      "fill: #0f172a; font-family: system-ui; font-weight: 600",
      svg_path.Point(18.0, 25.0),
      15,
    ),
    svg.Text("operands", label_style(), svg_path.Point(150.0, 48.0), 11),
    svg.Text("planar graph", label_style(), svg_path.Point(450.0, 48.0), 11),
    svg.Text("intersection", label_style(), svg_path.Point(750.0, 48.0), 11),
    svg.StyledPath(
      left_placed,
      "fill: #2563eb; fill-opacity: 0.16; fill-rule: "
        <> fill_rule_style
        <> "; stroke: #2563eb; stroke-width: 1.5",
    ),
    svg.StyledPath(
      right_placed,
      "fill: #e11d48; fill-opacity: 0.16; fill-rule: "
        <> fill_rule_style
        <> "; stroke: #e11d48; stroke-width: 1.5",
    ),
    svg.StyledPath(
      intersection_placed,
      "fill: #7c3aed; fill-opacity: 0.24; fill-rule: "
        <> fill_rule_style
        <> "; stroke: #7c3aed; stroke-width: 2",
    ),
  ]
  let arrows =
    list.append(
      planar_graph.path_direction_arrows(left_placed, "#2563eb"),
      planar_graph.path_direction_arrows(right_placed, "#e11d48"),
    )
  let result_arrows =
    planar_graph.path_direction_arrows(intersection_placed, "#7c3aed")
  let empty_note = case svg_path.path_subpaths(intersection) {
    [] -> [
      svg.Text(
        "∅",
        "fill: #7c3aed; font-family: system-ui; text-anchor: middle",
        svg_path.Point(750.0, 143.0),
        28,
      ),
    ]
    _ -> []
  }
  svg.document(
    list.flatten([
      base,
      arrows,
      graph_drawing,
      result_arrows,
      empty_note,
    ]),
    view_box: svg_path.BoundingBox(
      min: svg_path.Point(0.0, 0.0),
      max: svg_path.Point(900.0, 260.0),
    ),
  )
}

fn fit(
  path: svg_path.Path,
  center_x: Float,
  center_y: Float,
) -> Result(svg_path.Path, Nil) {
  let assert Ok(box) = svg_path.path_bounding_box(path)
  let width = svg_path.bounding_box_width(box)
  let height = svg_path.bounding_box_height(box)
  let factor = float.min(190.0 /. width, 150.0 /. height)
  let middle_x = { box.min.x +. box.max.x } /. 2.0
  let middle_y = { box.min.y +. box.max.y } /. 2.0
  let assert Ok(centered) =
    transform.translate_path(path, x: 0.0 -. middle_x, y: 0.0 -. middle_y)
  let assert Ok(scaled) = transform.scale_path(centered, factor:)
  let assert Ok(placed) =
    transform.translate_path(scaled, x: center_x, y: center_y)
  Ok(placed)
}

fn label_style() -> String {
  "fill: #475569; font-family: system-ui; text-anchor: middle"
}

fn rectangle(l: Float, t: Float, r: Float, b: Float) -> svg_path.Path {
  svg_path.path_from_subpath(
    svg_path.subpath_assert_polygon([
      svg_path.Point(l, t),
      svg_path.Point(r, t),
      svg_path.Point(r, b),
      svg_path.Point(l, b),
    ]),
  )
}

fn nested_rectangles() -> svg_path.Path {
  svg_path.Path(list.append(
    svg_path.path_subpaths(rectangle(0.0, 0.0, 120.0, 100.0)),
    svg_path.path_subpaths(rectangle(30.0, 22.0, 90.0, 78.0)),
  ))
}

fn bowtie() -> svg_path.Path {
  svg_path.path_from_subpath(
    svg_path.subpath_assert_polygon([
      svg_path.Point(5.0, 5.0),
      svg_path.Point(115.0, 95.0),
      svg_path.Point(115.0, 5.0),
      svg_path.Point(5.0, 95.0),
    ]),
  )
}

fn circle(center: svg_path.Point, radius: Float) -> svg_path.Path {
  let left = svg_path.Point(center.x -. radius, center.y)
  let right = svg_path.Point(center.x +. radius, center.y)
  svg_path.path_from_subpath(
    svg_path.subpath_assert([
      svg_path.Arc(
        start: right,
        radius: svg_path.Point(radius, radius),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: left,
      ),
      svg_path.Arc(
        start: left,
        radius: svg_path.Point(radius, radius),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: right,
      ),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True),
  )
}

@external(erlang, "erlang", "self")
fn dyn_nil() -> Dynamic

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
