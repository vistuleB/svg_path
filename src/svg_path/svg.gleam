//// Small helpers for rendering paths as complete SVG documents.

import gleam/int
import gleam/list
import gleam/string
import svg_path
import svg_path/number_format
import svg_path/serialize

pub type ThingToDraw {
  StyledPath(svg_path.Path, String)
  Text(String, String, svg_path.Point, Int)
}

pub type ThingsToDraw =
  List(ThingToDraw)

pub fn labeled_point(
  label: String,
  color: String,
  point: svg_path.Point,
  font_size: Int,
) -> ThingsToDraw {
  let side = int.to_float(font_size)
  let half_side = side /. 2.0
  let left = point.x -. half_side
  let right = point.x +. half_side
  let top = point.y -. half_side
  let bottom = point.y +. half_side
  let top_left = svg_path.point(left, top)
  let top_right = svg_path.point(right, top)
  let bottom_right = svg_path.point(right, bottom)
  let bottom_left = svg_path.point(left, bottom)
  let marker =
    svg_path.Path([
      svg_path.assert_subpath([
        svg_path.Line(start: top_left, end: top_right),
        svg_path.Line(start: top_right, end: bottom_right),
        svg_path.Line(start: bottom_right, end: bottom_left),
        svg_path.Line(start: bottom_left, end: top_left),
      ])
        |> svg_path.assert_set_closed(closed: True),
      svg_path.assert_subpath([
        svg_path.Line(start: top_left, end: bottom_right),
      ]),
      svg_path.assert_subpath([
        svg_path.Line(start: bottom_left, end: top_right),
      ]),
    ])

  [
    StyledPath(
      marker,
      "fill: none; stroke: "
        <> color
        <> "; stroke-width: 1; stroke-linecap: square; stroke-linejoin: miter",
    ),
    Text(
      label,
      "fill: " <> color <> "; font-family: system-ui, sans-serif",
      svg_path.point(right +. half_side, point.y +. half_side),
      font_size,
    ),
  ]
}

/// Render styled paths and text labels as a complete SVG document.
///
/// The supplied bounding box is used directly as the document `viewBox`.
/// `StyledPath` contains a path and a raw CSS declaration string for its
/// `style` attribute. `Text` contains text, a raw CSS declaration string for
/// its `style` attribute, a position, and a font size.
pub fn document(
  things things: ThingsToDraw,
  view_box view_box: svg_path.BoundingBox,
) -> String {
  let svg_path.BoundingBox(min:, max: _) = view_box
  let format =
    number_format.prepare(
      number_format.Options(
        left_decimals: number_format.Succinct,
        right_decimals: number_format.AtMost(5),
      ),
      [
        min.x,
        min.y,
        svg_path.bounding_box_width(view_box),
        svg_path.bounding_box_height(view_box),
      ],
    )

  "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\""
  <> view_box_value(view_box, format)
  <> "\">\n"
  <> {
    things
    |> list.map(thing_element(_, format))
    |> string.join("\n")
  }
  <> "\n</svg>"
}

/// Render styled paths and text labels as a complete SVG document.
///
/// This is an older name for `document`.
pub fn paths(
  things things: ThingsToDraw,
  view_box view_box: svg_path.BoundingBox,
) -> String {
  document(things, view_box:)
}

fn thing_element(
  thing: ThingToDraw,
  format: number_format.NumberFormat,
) -> String {
  case thing {
    StyledPath(path, style) -> path_element(path, style)
    Text(label, style, point, font_size) ->
      text_element(label, style, point, font_size, format)
  }
}

fn path_element(path: svg_path.Path, style: String) -> String {
  "  <path d=\""
  <> attribute_escape(serialize.path(path))
  <> "\" style=\""
  <> attribute_escape(style)
  <> "\" />"
}

fn text_element(
  label: String,
  style: String,
  point: svg_path.Point,
  font_size: Int,
  format: number_format.NumberFormat,
) -> String {
  "  <text x=\""
  <> number_format.number(point.x, with: format)
  <> "\" y=\""
  <> number_format.number(point.y, with: format)
  <> "\" font-size=\""
  <> int.to_string(font_size)
  <> "\" style=\""
  <> attribute_escape(style)
  <> "\">"
  <> text_escape(label)
  <> "</text>"
}

fn view_box_value(
  box: svg_path.BoundingBox,
  format: number_format.NumberFormat,
) -> String {
  let svg_path.BoundingBox(min:, max: _) = box

  [
    min.x,
    min.y,
    svg_path.bounding_box_width(box),
    svg_path.bounding_box_height(box),
  ]
  |> list.map(number_format.number(_, with: format))
  |> string.join(" ")
}

fn attribute_escape(value: String) -> String {
  value
  |> replace("&", "&amp;")
  |> replace("\"", "&quot;")
  |> replace("<", "&lt;")
  |> replace(">", "&gt;")
}

fn text_escape(value: String) -> String {
  value
  |> replace("&", "&amp;")
  |> replace("<", "&lt;")
  |> replace(">", "&gt;")
}

fn replace(value: String, pattern: String, replacement: String) -> String {
  value
  |> string.split(on: pattern)
  |> string.join(replacement)
}
