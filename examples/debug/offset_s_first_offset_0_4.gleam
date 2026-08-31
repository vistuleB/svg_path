//// First-offset preview for the S package-title outline at distance 0.4.

import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import svg_path
import svg_path/offset
import svg_path/parse
import svg_path/svg

const input = "examples/debug/package_title.svg"

const output = "examples/debug/offset_s_first_offset_0_4.svg"

const offset_distance = 0.4

pub fn main() -> Nil {
  let assert Ok(contents) = read_file(input)
  let assert Ok(full_path) = parse.path(first_path_data(contents))
  let assert [s, ..] = svg_path.path_subpaths(full_path)
  let source = svg_path.Path([s])
  let options =
    offset.Options(
      ..offset.default_options(),
      fitting: offset.FittingOptions(tolerance: 0.01, samples: 5, max_depth: 12),
      distance_options: svg_path.DistanceOptions(
        ..svg_path.default_distance_options(),
        tolerance: 0.000000001,
      ),
    )

  let assert Ok(first_offset) =
    offset.path_with(source, offset: offset_distance, options:)

  let assert Ok(source_box) = svg_path.path_bounding_box(source)
  let assert Ok(offset_box) = svg_path.path_bounding_box(first_offset)
  let view_box = padded_box([source_box, offset_box], margin: 1.0)

  write_file(output, render(source, first_offset, view_box))
  Nil
}

fn render(
  source: svg_path.Path,
  first_offset: svg_path.Path,
  view_box: svg_path.BoundingBox,
) -> String {
  let offset_layers =
    first_offset
    |> svg_path.path_subpaths
    |> list.index_map(fn(subpath, index) {
      svg.StyledPath(
        svg_path.subpath_as_path(subpath),
        "fill: none; stroke: "
          <> color(index)
          <> "; stroke-width: 0.06; stroke-linecap: round; stroke-linejoin: round",
      )
    })

  svg.document(
    things: [
      background(view_box),
      svg.StyledPath(source, "fill: #111827; stroke: none; opacity: 0.14"),
      svg.StyledPath(
        source,
        "fill: none; stroke: #6b7280; stroke-width: 0.015; stroke-linecap: round; stroke-linejoin: round",
      ),
      svg.Text(
        "S first offset, distance 0.4",
        "fill: #111827; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace",
        svg_path.Point(view_box.min.x +. 0.25, view_box.min.y +. 0.45),
        0.25,
      ),
      ..offset_layers
    ],
    view_box:,
  )
  |> with_root_size(width: 900, height: 900)
}

fn color(index: Int) -> String {
  case index % 6 {
    0 -> "#2563eb"
    1 -> "#dc2626"
    2 -> "#16a34a"
    3 -> "#9333ea"
    4 -> "#f97316"
    _ -> "#0891b2"
  }
}

fn background(view_box: svg_path.BoundingBox) -> svg.ThingToDraw {
  svg.Rectangle(
    view_box.min,
    svg_path.bounding_box_width(view_box),
    svg_path.bounding_box_height(view_box),
    "fill: #ffffff; stroke: none",
  )
}

fn padded_box(
  boxes: List(svg_path.BoundingBox),
  margin margin: Float,
) -> svg_path.BoundingBox {
  let assert [first, ..] = boxes
  let combined =
    list.fold(boxes, first, fn(acc, box) { combine_boxes(acc, box) })
  let svg_path.BoundingBox(min:, max:) = combined

  svg_path.BoundingBox(
    min: svg_path.Point(min.x -. margin, min.y -. margin),
    max: svg_path.Point(max.x +. margin, max.y +. margin),
  )
}

fn combine_boxes(
  left: svg_path.BoundingBox,
  right: svg_path.BoundingBox,
) -> svg_path.BoundingBox {
  svg_path.BoundingBox(
    min: svg_path.Point(
      float.min(left.min.x, right.min.x),
      float.min(left.min.y, right.min.y),
    ),
    max: svg_path.Point(
      float.max(left.max.x, right.max.x),
      float.max(left.max.y, right.max.y),
    ),
  )
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

fn first_path_data(contents: String) -> String {
  let assert [_, after_attribute] = string.split(contents, on: " d=\"")
  let assert [data, ..] = string.split(after_attribute, on: "\"")
  data
}

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(String, Dynamic)

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
