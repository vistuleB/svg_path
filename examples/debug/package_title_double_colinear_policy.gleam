//// Full package-title double-offset probe for endpoint reconciliation.

import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import svg_path
import svg_path/offset
import svg_path/parse
import svg_path/svg

const input = "examples/debug/package_title.svg"

const output = "examples/debug/package_title_double_colinear_policy.svg"

const offset_distance = 1.06

pub fn main() -> Nil {
  let assert Ok(contents) = read_file(input)
  let assert Ok(source) = parse.path(first_path_data(contents))
  let options =
    offset.Options(
      ..offset.default_options(),
      fitting: offset.FittingOptions(tolerance: 0.01, samples: 5, max_depth: 12),
      trimming: svg_path.DistanceOptions(
        ..svg_path.default_distance_options(),
        tolerance: 0.000000001,
      ),
    )

  let assert Ok(first_offset) =
    offset.path_with(source, distance: offset_distance, options:)
  io.println(
    "first offset subpaths: "
    <> int.to_string(list.length(svg_path.path_subpaths(first_offset))),
  )

  let second =
    offset.path_with(first_offset, distance: offset_distance, options:)
  case second {
    Ok(second_offset) -> {
      io.println(
        "second offset subpaths: "
        <> int.to_string(list.length(svg_path.path_subpaths(second_offset))),
      )
      write_file(output, render(source, first_offset, Ok(second_offset)))
      Nil
    }
    Error(error) -> {
      io.println("second offset error: " <> string.inspect(error))
      write_file(output, render(source, first_offset, Error(error)))
      Nil
    }
  }
}

fn render(
  source: svg_path.Path,
  first_offset: svg_path.Path,
  second_offset: Result(svg_path.Path, offset.Error),
) -> String {
  let boxes = case second_offset {
    Ok(second_offset) -> path_boxes([source, first_offset, second_offset])
    Error(_) -> path_boxes([source, first_offset])
  }
  let view_box = padded_box(boxes, margin: 3.0)
  let things = case second_offset {
    Ok(second_offset) -> [
      background(view_box),
      svg.StyledPath(source, "fill: #111827; stroke: none; opacity: 0.22"),
      svg.StyledPath(
        first_offset,
        "fill: none; stroke: #2563eb; stroke-width: 0.16; stroke-linecap: round; stroke-linejoin: round",
      ),
      svg.StyledPath(
        second_offset,
        "fill: none; stroke: #dc2626; stroke-width: 0.16; stroke-linecap: round; stroke-linejoin: round",
      ),
    ]
    Error(error) -> [
      background(view_box),
      svg.StyledPath(source, "fill: #111827; stroke: none; opacity: 0.22"),
      svg.StyledPath(
        first_offset,
        "fill: none; stroke: #2563eb; stroke-width: 0.16; stroke-linecap: round; stroke-linejoin: round",
      ),
      svg.Text(
        "second offset error: " <> string.inspect(error),
        "fill: #dc2626; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace",
        svg_path.Point(view_box.min.x +. 1.0, view_box.min.y +. 1.2),
        0.9,
      ),
    ]
  }

  svg.document(things:, view_box:)
  |> with_root_size(width: 1800, height: 420)
}

fn path_boxes(paths: List(svg_path.Path)) -> List(svg_path.BoundingBox) {
  paths
  |> list.filter_map(svg_path.path_bounding_box)
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
