//// Standalone 3-panel figure for a Boolean union of two filled squares that
//// touch at a single corner. The union boundary is traced clockwise; the two
//// squares merge into one self-touching loop that visits the pinch point
//// twice. Generated with `gleam run -m svg_path_corner_pinch_fixture`.

import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/list
import svg_path
import svg_path/arrangement as arrangement_graph
import svg_path/arrangement/drawing as arrangement_graph_drawing
import svg_path/csg
import svg_path/svg
import svg_path/transform

const tolerance = 0.000001

const minimum_chord = 0.00001

const output = "examples/debug/square_corner_pinch_union_clockwise.svg"

pub fn main() {
  let first = square(0.0, 0.0, 10.0)
  let second = square(10.0, 10.0, 10.0)
  let left = svg_path.subpath_as_path(first)
  let right = svg_path.subpath_as_path(second)
  let source =
    svg_path.Path(list.append(
      svg_path.path_subpaths(left),
      svg_path.path_subpaths(right),
    ))
  let assert Ok(source_placed) = fit(source, 150.0, 147.0)
  let source_parts = svg_path.path_subpaths(source_placed)
  let left_count = list.length(svg_path.path_subpaths(left))
  let left_placed = svg_path.Path(list.take(source_parts, left_count))
  let right_placed = svg_path.Path(list.drop(source_parts, left_count))

  let assert Ok(graph_source) = fit(source, 450.0, 147.0)
  let assert Ok(arrangement_graph.ArrangementGraphBuild(graph:, ..)) =
    arrangement_graph.build([graph_source], tolerance:, minimum_chord:)
  let assert Ok(graph_drawing) =
    arrangement_graph_drawing.annotated_drawing(graph, graph_source, tolerance:)

  let assert Ok(csg.CsgResult(path: union, ..)) =
    csg.union(left, right, using: svg_path.Nonzero)
  let assert Ok(union_placed) =
    place_like(union, source, 750.0, 147.0, 190.0, 150.0)

  let base = [
    svg.Rectangle(
      svg_path.Point(0.0, 0.0),
      900.0,
      260.0,
      "fill: #f8fafc; stroke: none",
    ),
    svg.Text(
      "union of corner-touching squares · clockwise orientation",
      "fill: #0f172a; font-family: system-ui; font-weight: 600",
      svg_path.Point(18.0, 25.0),
      15.0,
    ),
    svg.Text("operands", label_style(), svg_path.Point(150.0, 48.0), 11.0),
    svg.Text(
      "arrangement graph",
      label_style(),
      svg_path.Point(450.0, 48.0),
      11.0,
    ),
    svg.Text(
      "union · one self-touching loop",
      label_style(),
      svg_path.Point(750.0, 48.0),
      11.0,
    ),
    svg.StyledPath(
      left_placed,
      "fill: #2563eb; fill-opacity: 0.16; fill-rule: nonzero; stroke: #2563eb; stroke-width: 1.5",
    ),
    svg.StyledPath(
      right_placed,
      "fill: #e11d48; fill-opacity: 0.16; fill-rule: nonzero; stroke: #e11d48; stroke-width: 1.5",
    ),
    svg.StyledPath(
      union_placed,
      "fill: #7c3aed; fill-opacity: 0.24; fill-rule: nonzero; stroke: #7c3aed; stroke-width: 2",
    ),
  ]
  let arrows =
    list.append(
      arrangement_graph_drawing.path_direction_arrows(left_placed, "#2563eb"),
      arrangement_graph_drawing.path_direction_arrows(right_placed, "#e11d48"),
    )
  let result_arrows =
    arrangement_graph_drawing.path_direction_arrows(union_placed, "#7c3aed")
  let _ =
    write_file(
      output,
      svg.document(
        list.flatten([base, arrows, graph_drawing, result_arrows]),
        view_box: svg_path.BoundingBox(
          min: svg_path.Point(0.0, 0.0),
          max: svg_path.Point(900.0, 260.0),
        ),
      ),
    )
  dyn_nil()
}

fn square(x: Float, y: Float, side: Float) -> svg_path.Subpath {
  rectangle_subpath(x, y, x +. side, y +. side)
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

fn label_style() -> String {
  "fill: #475569; font-family: system-ui; text-anchor: middle"
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
// coordinates aligned across panels instead of refitting the result
// independently.
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

@external(erlang, "erlang", "self")
fn dyn_nil() -> Dynamic

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic