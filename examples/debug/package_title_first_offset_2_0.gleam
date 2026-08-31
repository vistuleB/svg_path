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

const output = "examples/debug/package_title_first_offset_2_0.svg"

pub fn main() -> Nil {
  let assert Ok(contents) = read_file(input)
  let assert Ok(source) = parse.path(first_path_data(contents))
  let options =
    offset.Options(
      ..offset.default_options(),
      fitting: offset.FittingOptions(tolerance: 0.01, samples: 5, max_depth: 12),
      distance_options: svg_path.DistanceOptions(
        ..svg_path.default_distance_options(),
        tolerance: 0.000000001,
      ),
    )
  let assert Ok(first_offset) = offset.path_with(source, offset: 2.0, options:)
  let boxes =
    [
      svg_path.path_bounding_box(source),
      svg_path.path_bounding_box(first_offset),
    ]
    |> list.filter_map(fn(result) { result })
  let view_box = padded_box(boxes, margin: 2.0)
  let document =
    svg.document(
      things: [
        svg.Rectangle(
          view_box.min,
          svg_path.bounding_box_width(view_box),
          svg_path.bounding_box_height(view_box),
          "fill: #ffffff; stroke: none",
        ),
        svg.StyledPath(source, "fill: #111827; stroke: none; opacity: 0.16"),
        svg.StyledPath(
          first_offset,
          "fill: none; stroke: #2563eb; stroke-width: 0.08; stroke-linecap: round; stroke-linejoin: round",
        ),
      ],
      view_box:,
    )
    |> with_root_size(width: 1800, height: 420)
  write_file(output, document)
  Nil
}

fn padded_box(
  boxes: List(svg_path.BoundingBox),
  margin margin: Float,
) -> svg_path.BoundingBox {
  let assert [first, ..rest] = boxes
  let combined = list.fold(rest, first, combine_boxes)
  svg_path.BoundingBox(
    min: svg_path.Point(combined.min.x -. margin, combined.min.y -. margin),
    max: svg_path.Point(combined.max.x +. margin, combined.max.y +. margin),
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
  document: String,
  width width: Int,
  height height: Int,
) -> String {
  let assert Ok(#(before_width, after_width)) =
    string.split_once(document, on: "\" width=\"")
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
  let assert [_, after] = string.split(contents, on: " d=\"")
  let assert [data, ..] = string.split(after, on: "\"")
  data
}

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(String, Dynamic)

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
