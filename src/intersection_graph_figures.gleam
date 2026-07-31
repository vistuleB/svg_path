//// Debug figure generator for arrangement-graph Boolean cases.

import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/list
import svg_path
import svg_path/planar_graph
import svg_path/svg
import svg_path/transform

const tolerance = 0.000001

const minimum_chord = 0.00001

type FigureOperation {
  IntersectionFigure
  DifferenceFigure
}

pub fn main() -> Dynamic {
  let cases = [
    #(
      "intersection_rectangles.svg",
      "overlapping rectangles",
      rectangle(0.0, 0.0, 80.0, 80.0),
      rectangle(40.0, 0.0, 120.0, 80.0),
      svg_path.Nonzero,
      IntersectionFigure,
    ),
    #(
      "intersection_circle_rectangle.svg",
      "circle and rectangle",
      circle(svg_path.Point(55.0, 50.0), 45.0),
      rectangle(45.0, 0.0, 105.0, 100.0),
      svg_path.Nonzero,
      IntersectionFigure,
    ),
    #(
      "intersection_nested_nonzero.svg",
      "nested contours · nonzero",
      nested_rectangles(),
      rectangle(42.0, 32.0, 78.0, 68.0),
      svg_path.Nonzero,
      IntersectionFigure,
    ),
    #(
      "intersection_nested_evenodd.svg",
      "nested contours · even–odd",
      nested_rectangles(),
      rectangle(42.0, 32.0, 78.0, 68.0),
      svg_path.EvenOdd,
      IntersectionFigure,
    ),
    #(
      "intersection_bowtie_rectangle.svg",
      "self-crossing contour",
      bowtie(),
      rectangle(35.0, 25.0, 88.0, 82.0),
      svg_path.Nonzero,
      IntersectionFigure,
    ),
    #(
      "intersection_edge_tangent.svg",
      "edge-tangent rectangles",
      rectangle(0.0, 0.0, 60.0, 80.0),
      rectangle(60.0, 15.0, 120.0, 65.0),
      svg_path.Nonzero,
      IntersectionFigure,
    ),
    #(
      "difference_rectangles.svg",
      "overlapping rectangles",
      rectangle(0.0, 0.0, 80.0, 80.0),
      rectangle(40.0, 0.0, 120.0, 80.0),
      svg_path.Nonzero,
      DifferenceFigure,
    ),
    #(
      "difference_hole.svg",
      "contained rectangle cutout",
      rectangle(0.0, 0.0, 120.0, 100.0),
      rectangle(32.0, 22.0, 88.0, 78.0),
      svg_path.Nonzero,
      DifferenceFigure,
    ),
    #(
      "difference_circle_rectangle.svg",
      "circle minus rectangle",
      circle(svg_path.Point(55.0, 50.0), 45.0),
      rectangle(45.0, 0.0, 105.0, 100.0),
      svg_path.Nonzero,
      DifferenceFigure,
    ),
    #(
      "difference_nested_nonzero.svg",
      "nested contours · nonzero",
      nested_rectangles(),
      rectangle(42.0, 32.0, 78.0, 68.0),
      svg_path.Nonzero,
      DifferenceFigure,
    ),
    #(
      "difference_nested_evenodd.svg",
      "nested contours · even–odd",
      nested_rectangles(),
      rectangle(42.0, 32.0, 78.0, 68.0),
      svg_path.EvenOdd,
      DifferenceFigure,
    ),
    #(
      "difference_bowtie_rectangle.svg",
      "self-crossing contour minus rectangle",
      bowtie(),
      rectangle(35.0, 25.0, 88.0, 82.0),
      svg_path.Nonzero,
      DifferenceFigure,
    ),
  ]
  list.each(cases, fn(entry) {
    let #(name, title, left, right, rule, operation) = entry
    let _ =
      write_file(
        "examples/debug/" <> name,
        render_case(title, left, right, rule, operation),
      )
  })
  let figure_left =
    svg_path.Path([
      rectangle_subpath(0.0, 0.0, 4.0, 4.0),
      rectangle_subpath(3.0, 3.0, 6.0, 5.0),
    ])
  let figure_right =
    svg_path.Path([
      rectangle_subpath(1.0, 4.0, 6.0, 6.0),
      rectangle_subpath(2.0, 2.0, 5.0, 5.0),
    ])
  let _ =
    write_file(
      "examples/debug/arrangement_boolean_nonzero.svg",
      render_boolean_table(figure_left, figure_right, svg_path.Nonzero),
    )
  let _ =
    write_file(
      "examples/debug/arrangement_boolean_evenodd.svg",
      render_boolean_table(figure_left, figure_right, svg_path.EvenOdd),
    )
  dyn_nil()
}

fn render_boolean_table(
  left: svg_path.Path,
  right: svg_path.Path,
  rule: svg_path.FillRule,
) -> String {
  let rule_name = case rule {
    svg_path.Nonzero -> "nonzero"
    svg_path.EvenOdd -> "even–odd"
  }
  let fill_rule_style = case rule {
    svg_path.Nonzero -> "nonzero"
    svg_path.EvenOdd -> "evenodd"
  }
  let source =
    svg_path.Path(list.append(
      svg_path.path_subpaths(left),
      svg_path.path_subpaths(right),
    ))
  let panel_y = 185.0
  let panel_width = 225.0
  let panel_height = 225.0
  let assert Ok(source_placed) =
    place_like(source, source, 140.0, panel_y, panel_width, panel_height)
  let source_parts = svg_path.path_subpaths(source_placed)
  let left_count = list.length(svg_path.path_subpaths(left))
  let left_placed = svg_path.Path(list.take(source_parts, left_count))
  let right_placed = svg_path.Path(list.drop(source_parts, left_count))

  let assert Ok(graph_source) =
    place_like(source, source, 420.0, panel_y, panel_width, panel_height)
  let assert Ok(graph) =
    planar_graph.from_subpaths(
      svg_path.path_subpaths(graph_source),
      tolerance:,
      minimum_chord:,
    )
  let assert Ok(graph_drawing) =
    planar_graph.annotated_things_to_draw(graph, graph_source, tolerance:)

  let assert Ok(union) =
    planar_graph.union_paths(
      left,
      right,
      using: rule,
      tolerance:,
      minimum_chord:,
    )
  let assert Ok(intersection) =
    planar_graph.intersection_paths(
      left,
      right,
      using: rule,
      tolerance:,
      minimum_chord:,
    )
  let assert Ok(difference) =
    planar_graph.difference_paths(
      left,
      minus: right,
      using: rule,
      tolerance:,
      minimum_chord:,
    )
  let assert Ok(reverse_difference) =
    planar_graph.difference_paths(
      right,
      minus: left,
      using: rule,
      tolerance:,
      minimum_chord:,
    )
  let assert Ok(symmetric_difference) =
    planar_graph.symmetric_difference_paths(
      left,
      right,
      using: rule,
      tolerance:,
      minimum_chord:,
    )
  let assert Ok(union_placed) =
    place_like(union, source, 700.0, panel_y, panel_width, panel_height)
  let assert Ok(intersection_placed) =
    place_like(intersection, source, 980.0, panel_y, panel_width, panel_height)
  let assert Ok(difference_placed) =
    place_like(difference, source, 1260.0, panel_y, panel_width, panel_height)
  let assert Ok(reverse_difference_placed) =
    place_like(
      reverse_difference,
      source,
      1540.0,
      panel_y,
      panel_width,
      panel_height,
    )
  let assert Ok(symmetric_difference_placed) =
    place_like(
      symmetric_difference,
      source,
      1820.0,
      panel_y,
      panel_width,
      panel_height,
    )

  let path_style = fn(fill: String, stroke: String) {
    "fill: "
    <> fill
    <> "; fill-opacity: 0.22; fill-rule: "
    <> fill_rule_style
    <> "; stroke: "
    <> stroke
    <> "; stroke-width: 2"
  }
  let base = [
    svg.Rectangle(
      svg_path.Point(0.0, 0.0),
      1960.0,
      350.0,
      "fill: #f8fafc; stroke: none",
    ),
    svg.Text(
      "ArrangementGraph Boolean operations · " <> rule_name,
      "fill: #0f172a; font-family: system-ui; font-weight: 600",
      svg_path.Point(24.0, 31.0),
      17,
    ),
    svg.Text(
      "source paths: 2x 2 rectangles",
      label_style(),
      svg_path.Point(140.0, 328.0),
      12,
    ),
    svg.Text(
      "arrangement graph",
      label_style(),
      svg_path.Point(420.0, 328.0),
      12,
    ),
    svg.Text(
      "union(path1, path2)",
      label_style(),
      svg_path.Point(700.0, 328.0),
      12,
    ),
    svg.Text(
      "intersection(path1, path2)",
      label_style(),
      svg_path.Point(980.0, 328.0),
      12,
    ),
    svg.Text(
      "difference(path1, path2)",
      label_style(),
      svg_path.Point(1260.0, 328.0),
      12,
    ),
    svg.Text(
      "difference(path2, path1)",
      label_style(),
      svg_path.Point(1540.0, 328.0),
      12,
    ),
    svg.Text(
      "symmetric_difference(path1, path2)",
      label_style(),
      svg_path.Point(1820.0, 328.0),
      12,
    ),
  ]
  let backdrops =
    list.flatten([
      panel_backdrop(source, 140.0, panel_y, panel_width, panel_height),
      panel_backdrop(source, 420.0, panel_y, panel_width, panel_height),
      panel_backdrop(source, 700.0, panel_y, panel_width, panel_height),
      panel_backdrop(source, 980.0, panel_y, panel_width, panel_height),
      panel_backdrop(source, 1260.0, panel_y, panel_width, panel_height),
      panel_backdrop(source, 1540.0, panel_y, panel_width, panel_height),
      panel_backdrop(source, 1820.0, panel_y, panel_width, panel_height),
    ])
  let geometry = [
    svg.StyledPath(left_placed, path_style("#2563eb", "#2563eb")),
    svg.StyledPath(right_placed, path_style("#e11d48", "#e11d48")),
    svg.StyledPath(union_placed, path_style("#16a34a", "#15803d")),
    svg.StyledPath(intersection_placed, path_style("#7c3aed", "#6d28d9")),
    svg.StyledPath(difference_placed, path_style("#d97706", "#b45309")),
    svg.StyledPath(reverse_difference_placed, path_style("#0891b2", "#0e7490")),
    svg.StyledPath(
      symmetric_difference_placed,
      path_style("#db2777", "#be185d"),
    ),
  ]
  let source_arrows =
    list.append(
      planar_graph.path_direction_arrows(left_placed, "#2563eb"),
      planar_graph.path_direction_arrows(right_placed, "#e11d48"),
    )
  let result_arrows =
    list.flatten([
      planar_graph.path_direction_arrows(union_placed, "#15803d"),
      planar_graph.path_direction_arrows(intersection_placed, "#6d28d9"),
      planar_graph.path_direction_arrows(difference_placed, "#b45309"),
      planar_graph.path_direction_arrows(reverse_difference_placed, "#0e7490"),
      planar_graph.path_direction_arrows(symmetric_difference_placed, "#be185d"),
    ])
  svg.document(
    list.flatten([
      base,
      backdrops,
      geometry,
      source_arrows,
      graph_drawing,
      result_arrows,
    ]),
    view_box: svg_path.BoundingBox(
      min: svg_path.Point(0.0, 0.0),
      max: svg_path.Point(1960.0, 350.0),
    ),
  )
}

fn render_case(
  title: String,
  left: svg_path.Path,
  right: svg_path.Path,
  rule: svg_path.FillRule,
  operation: FigureOperation,
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
  let assert Ok(boolean_result) = case operation {
    IntersectionFigure ->
      planar_graph.intersection_paths(
        left,
        right,
        using: rule,
        tolerance:,
        minimum_chord:,
      )
    DifferenceFigure ->
      planar_graph.difference_paths(
        left,
        minus: right,
        using: rule,
        tolerance:,
        minimum_chord:,
      )
  }
  let result_placed = case svg_path.path_subpaths(boolean_result) {
    [] -> boolean_result
    _ -> {
      let assert Ok(value) = fit(boolean_result, 750.0, 132.0)
      value
    }
  }
  let operation_label = case operation {
    IntersectionFigure -> "intersection"
    DifferenceFigure -> "difference"
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
    svg.Text(operation_label, label_style(), svg_path.Point(750.0, 48.0), 11),
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
      result_placed,
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
    planar_graph.path_direction_arrows(result_placed, "#7c3aed")
  let empty_note = case svg_path.path_subpaths(boolean_result) {
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
  fit_with_bounds(path, center_x, center_y, 190.0, 150.0)
}

fn fit_with_bounds(
  path: svg_path.Path,
  center_x: Float,
  center_y: Float,
  maximum_width: Float,
  maximum_height: Float,
) -> Result(svg_path.Path, Nil) {
  let assert Ok(box) = svg_path.path_bounding_box(path)
  let width = svg_path.bounding_box_width(box)
  let height = svg_path.bounding_box_height(box)
  let factor = float.min(maximum_width /. width, maximum_height /. height)
  let middle_x = { box.min.x +. box.max.x } /. 2.0
  let middle_y = { box.min.y +. box.max.y } /. 2.0
  let assert Ok(centered) =
    transform.translate_path(path, x: 0.0 -. middle_x, y: 0.0 -. middle_y)
  let assert Ok(scaled) = transform.scale_path(centered, factor:)
  let assert Ok(placed) =
    transform.translate_path(scaled, x: center_x, y: center_y)
  Ok(placed)
}

// Place `path` using the bounding box and scale of `reference`. This keeps
// coordinates aligned across Boolean result panels instead of refitting each
// result independently.
fn place_like(
  path: svg_path.Path,
  reference: svg_path.Path,
  center_x: Float,
  center_y: Float,
  maximum_width: Float,
  maximum_height: Float,
) -> Result(svg_path.Path, Nil) {
  let assert Ok(box) = svg_path.path_bounding_box(reference)
  let factor =
    float.min(
      maximum_width /. svg_path.bounding_box_width(box),
      maximum_height /. svg_path.bounding_box_height(box),
    )
  let middle_x = { box.min.x +. box.max.x } /. 2.0
  let middle_y = { box.min.y +. box.max.y } /. 2.0
  let assert Ok(centered) =
    transform.translate_path(path, x: 0.0 -. middle_x, y: 0.0 -. middle_y)
  let assert Ok(scaled) = transform.scale_path(centered, factor:)
  let assert Ok(placed) =
    transform.translate_path(scaled, x: center_x, y: center_y)
  Ok(placed)
}

fn panel_backdrop(
  reference: svg_path.Path,
  center_x: Float,
  center_y: Float,
  maximum_width: Float,
  maximum_height: Float,
) -> svg.ThingsToDraw {
  let assert Ok(square) =
    place_like(
      rectangle(0.0, 0.0, 6.0, 6.0),
      reference,
      center_x,
      center_y,
      maximum_width,
      maximum_height,
    )
  let assert Ok(hatch) =
    place_like(
      dense_hatch_square(),
      reference,
      center_x,
      center_y,
      maximum_width,
      maximum_height,
    )
  [
    svg.StyledPath(square, "fill: #cbd5e1; fill-opacity: 0.13; stroke: none"),
    svg.StyledPath(
      hatch,
      "fill: none; stroke: #94a3b8; stroke-opacity: 0.22; stroke-width: 0.55",
    ),
  ]
}

fn dense_hatch_square() -> svg_path.Path {
  svg_path.Path(dense_hatch_lines(-6.0, []))
}

fn dense_hatch_lines(
  offset: Float,
  accumulated: List(svg_path.Subpath),
) -> List(svg_path.Subpath) {
  case offset >. 6.00001 {
    True -> list.reverse(accumulated)
    False -> {
      let line = case offset <. 0.0 {
        True -> hatch_line(0.0, 0.0 -. offset, 6.0 +. offset, 6.0)
        False -> hatch_line(offset, 0.0, 6.0, 6.0 -. offset)
      }
      dense_hatch_lines(offset +. 1.0 /. 3.0, [line, ..accumulated])
    }
  }
}

fn hatch_line(
  start_x: Float,
  start_y: Float,
  end_x: Float,
  end_y: Float,
) -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.Line(
      start: svg_path.Point(start_x, start_y),
      end: svg_path.Point(end_x, end_y),
    ),
  ])
}

fn label_style() -> String {
  "fill: #475569; font-family: system-ui; text-anchor: middle"
}

fn rectangle(l: Float, t: Float, r: Float, b: Float) -> svg_path.Path {
  svg_path.path_from_subpath(rectangle_subpath(l, t, r, b))
}

fn rectangle_subpath(
  l: Float,
  t: Float,
  r: Float,
  b: Float,
) -> svg_path.Subpath {
  svg_path.subpath_assert_polygon([
    svg_path.Point(l, t),
    svg_path.Point(r, t),
    svg_path.Point(r, b),
    svg_path.Point(l, b),
  ])
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
