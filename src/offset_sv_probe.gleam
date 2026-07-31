//// Global-offset diagnostic for the S and V package-title subpaths.

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

const output = "examples/debug/offset_sv_global.svg"

pub fn main() -> Dynamic {
  let assert Ok(contents) = read_file(input)
  let assert Ok(full) = parse.path(first_path_data(contents))
  let source = svg_path.Path(svg_path.path_subpaths(full) |> list.take(2))
  let assert Ok(sections) =
    offset.path_sections_with(
      source,
      distance: 1.0,
      options: offset.default_options(),
    )
  let assert Ok(source_box) = svg_path.path_bounding_box(source)
  let assert Ok(sections_box) = svg_path.path_bounding_box(sections)
  let view_box = padded_box([source_box, sections_box], margin: 2.0)
  write_file(output, render(source, sections, view_box))
}

fn render(
  source: svg_path.Path,
  sections: svg_path.Path,
  view_box: svg_path.BoundingBox,
) -> String {
  svg.document(
    things: list.append(
      [
        background(view_box),
        svg.StyledPath(
          source,
          "fill: none; stroke: #111827; stroke-width: 0.18; stroke-dasharray: 0.7 0.45; stroke-linecap: butt; stroke-linejoin: miter",
        ),
      ],
      section_things(svg_path.path_subpaths(sections), 0),
    ),
    view_box:,
  )
  |> with_root_size(width: 16_000, height: 3600)
}

fn section_things(
  sections: List(svg_path.Subpath),
  index: Int,
) -> List(svg.ThingToDraw) {
  case sections {
    [] -> []
    [first, ..rest] -> [
      svg.StyledPath(
        svg_path.Path([first]),
        "fill: none; stroke: "
          <> section_color(index)
          <> "; stroke-width: 0.28; stroke-linecap: butt; stroke-linejoin: miter",
      ),
      ..section_things(rest, index + 1)
    ]
  }
}

fn section_color(index: Int) -> String {
  let assert Ok(remainder) = int.remainder(index, by: 8)
  case remainder {
    0 -> "#e11d48"
    1 -> "#2563eb"
    2 -> "#16a34a"
    3 -> "#9333ea"
    4 -> "#ea580c"
    5 -> "#0891b2"
    6 -> "#ca8a04"
    _ -> "#db2777"
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
  let combined = list.fold(boxes, first, combine_boxes)
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

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(String, Dynamic)

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic

fn first_path_data(contents: String) -> String {
  let assert [_, after_attribute] = string.split(contents, on: " d=\"")
  let assert [data, ..] = string.split(after_attribute, on: "\"")
  data
}
