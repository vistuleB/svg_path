//// Current-worktree SVG_PATH iterated-offset verification.

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

  let levels_0_4 = offset_levels(source, 0.4, 5, options, [])
  let levels_1_04 = offset_levels(source, 1.04, 2, options, [])
  let levels_1_0 = offset_levels(source, 1.0, 2, options, [])

  io.println("0.4 completed levels: " <> int.to_string(list.length(levels_0_4)))
  io.println(
    "1.04 completed levels: " <> int.to_string(list.length(levels_1_04)),
  )
  io.println("1.0 completed levels: " <> int.to_string(list.length(levels_1_0)))

  write_file(
    "examples/debug/package_title_five_offsets_0_4_current.svg",
    render(source, levels_0_4, [
      "#2563eb",
      "#dc2626",
      "#16a34a",
      "#9333ea",
      "#ea580c",
    ]),
  )
  write_file(
    "examples/debug/package_title_two_offsets_1_04_current.svg",
    render(source, levels_1_04, ["#2563eb", "#dc2626"]),
  )
  write_file(
    "examples/debug/package_title_two_offsets_1_0_current.svg",
    render(source, levels_1_0, ["#2563eb", "#dc2626"]),
  )
  Nil
}

fn offset_levels(
  current: svg_path.Path,
  distance: Float,
  remaining: Int,
  options: offset.Options,
  reversed: List(svg_path.Path),
) -> List(svg_path.Path) {
  case remaining {
    0 -> list.reverse(reversed)
    _ ->
      case offset.path_with(current, offset:, options:) {
        Ok(next) ->
          offset_levels(next, distance, remaining - 1, options, [
            next,
            ..reversed
          ])
        Error(error) -> {
          io.println(
            "distance "
            <> float.to_string(distance)
            <> " level "
            <> int.to_string(list.length(reversed) + 1)
            <> " error: "
            <> string.inspect(error),
          )
          list.reverse(reversed)
        }
      }
  }
}

fn render(
  source: svg_path.Path,
  levels: List(svg_path.Path),
  colors: List(String),
) -> String {
  let paths = [source, ..levels]
  let view_box =
    padded_box(list.filter_map(paths, svg_path.path_bounding_box), 2.0)
  let offset_things =
    list.map2(levels, colors, fn(path, color) {
      svg.StyledPath(
        path,
        "fill: none; stroke: "
          <> color
          <> "; stroke-width: 0.055; stroke-linecap: round; stroke-linejoin: round",
      )
    })
  svg.document(
    things: [
      background(view_box),
      svg.StyledPath(source, "fill: #111827; stroke: none; opacity: 0.14"),
      ..offset_things
    ],
    view_box:,
  )
  |> with_root_size(1800, 440)
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
  margin: Float,
) -> svg_path.BoundingBox {
  let assert [first, ..] = boxes
  let combined = list.fold(boxes, first, combine_boxes)
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

fn with_root_size(document: String, width: Int, height: Int) -> String {
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
  let assert [_, after_attribute] = string.split(contents, on: " d=\"")
  let assert [data, ..] = string.split(after_attribute, on: "\"")
  data
}

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(String, Dynamic)

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
