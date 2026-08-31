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

const output = "examples/debug/package_title_seven_offsets_1_04_current.svg"

pub fn main() -> Nil {
  let assert Ok(contents) = read_file(input)
  let assert Ok(source) = parse.path(first_path_data(contents))
  let options = offset.default_options()
  let levels = offset_levels(source, options, remaining: 7, completed: [])
  io.println("completed levels: " <> int.to_string(list.length(levels)))
  let _ = write_file(output, render(source, levels))
  Nil
}

fn offset_levels(
  current: svg_path.Path,
  options: offset.Options,
  remaining remaining: Int,
  completed completed: List(svg_path.Path),
) -> List(svg_path.Path) {
  case remaining {
    0 -> list.reverse(completed)
    _ ->
      case offset.path_with(current, offset: 1.04, options:) {
        Ok(next) -> {
          io.println("completed offset " <> int.to_string(8 - remaining))
          offset_levels(next, options, remaining: remaining - 1, completed: [
            next,
            ..completed
          ])
        }
        Error(error) -> {
          io.println("offset error: " <> string.inspect(error))
          list.reverse(completed)
        }
      }
  }
}

fn render(source: svg_path.Path, levels: List(svg_path.Path)) -> String {
  let colors = [
    "#2563eb",
    "#dc2626",
    "#16a34a",
    "#9333ea",
    "#ea580c",
    "#0891b2",
    "#be185d",
  ]
  let view_box =
    [source, ..levels]
    |> list.filter_map(svg_path.path_bounding_box)
    |> padded_box(2.0)
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
      svg.Rectangle(
        view_box.min,
        svg_path.bounding_box_width(view_box),
        svg_path.bounding_box_height(view_box),
        "fill: #ffffff; stroke: none",
      ),
      svg.StyledPath(source, "fill: #111827; stroke: none; opacity: 0.14"),
      ..offset_things
    ],
    view_box:,
  )
  |> with_root_size(1800, 440)
}

fn padded_box(
  boxes: List(svg_path.BoundingBox),
  margin: Float,
) -> svg_path.BoundingBox {
  let assert [first, ..rest] = boxes
  let combined =
    list.fold(rest, first, fn(left, right) {
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
    })
  svg_path.BoundingBox(
    min: svg_path.Point(combined.min.x -. margin, combined.min.y -. margin),
    max: svg_path.Point(combined.max.x +. margin, combined.max.y +. margin),
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
