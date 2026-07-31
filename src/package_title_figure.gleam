//// Scratch renderer for the package title offset case.
////
//// This is intentionally a top-level debug module, not part of `svg_path`.

import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import svg_path
import svg_path/offset
import svg_path/parse
import svg_path/robust_union
import svg_path/svg

const input = "examples/debug/package_title.svg"

const output = "examples/debug/package_title_offset.svg"

const union_output = "examples/debug/package_title_offset_union.svg"

pub fn main() -> Dynamic {
  let assert Ok(contents) = read_file(input)
  let assert Ok(source) = parse.path(first_path_data(contents))
  let assert Ok(offset_path) =
    offset.path_with(source, distance: 1.0, options: offset.default_options())
  let assert Ok(source_box) = svg_path.path_bounding_box(source)
  let assert Ok(offset_box) = svg_path.path_bounding_box(offset_path)
  let view_box = padded_box([source_box, offset_box], margin: 2.0)

  let _ = write_file(output, render(source, offset_path, view_box))
  let union_result = robust_union.union_nonzero(offset_path)
  write_file(union_output, case union_result {
    Ok(offset_union) -> render(source, offset_union, view_box)
    Error(error) ->
      render_error(source, offset_path, view_box, error, "face walk")
  })
}

fn render(
  source: svg_path.Path,
  outline: svg_path.Path,
  view_box: svg_path.BoundingBox,
) -> String {
  svg.document(
    things: [
      background(view_box),
      svg.StyledPath(source, "fill: #000000; stroke: none"),
      svg.StyledPath(
        outline,
        "fill: none; stroke: #000000; stroke-width: 0.2; stroke-linecap: butt; stroke-linejoin: miter",
      ),
    ],
    view_box:,
  )
  |> with_root_size(width: 1600, height: 360)
}

fn render_error(
  source: svg_path.Path,
  outline: svg_path.Path,
  view_box: svg_path.BoundingBox,
  error: svg_path.Error,
  stage: String,
) -> String {
  let svg_path.BoundingBox(min:, max:) = view_box

  svg.document(
    things: [
      background(view_box),
      svg.StyledPath(source, "fill: #000000; stroke: none"),
      svg.StyledPath(
        outline,
        "fill: none; stroke: #000000; stroke-width: 0.2; stroke-linecap: butt; stroke-linejoin: miter",
      ),
      svg.Text(
        "union failed in " <> stage <> ": " <> error_label(error),
        "fill: #b91c1c; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-weight: 700",
        svg_path.Point(min.x +. 1.0, max.y -. 2.0),
        2,
      ),
    ],
    view_box:,
  )
  |> with_root_size(width: 1600, height: 360)
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
  <> int_string(width)
  <> "\" height=\""
  <> int_string(height)
  <> "\">"
  <> rest
}

fn int_string(value: Int) -> String {
  int.to_string(value)
}

fn background(view_box: svg_path.BoundingBox) -> svg.ThingToDraw {
  svg.Rectangle(
    view_box.min,
    svg_path.bounding_box_width(view_box),
    svg_path.bounding_box_height(view_box),
    "fill: #ffffff; stroke: none",
  )
}

fn error_label(error: svg_path.Error) -> String {
  case error {
    svg_path.OverlappingSegments -> "OverlappingSegments"
    _ -> "svg_path.Error"
  }
}

fn first_path_data(contents: String) -> String {
  let assert [_, after_attribute] = string.split(contents, on: " d=\"")
  let assert [data, ..] = string.split(after_attribute, on: "\"")
  data
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

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(String, Dynamic)

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
