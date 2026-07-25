//// Small helpers for rendering paths as complete SVG documents.

import gleam/int
import gleam/list
import gleam/string
import svg_path
import svg_path/number_format
import svg_path/serialize

/// One item to render inside a generated SVG document.
///
/// This type is intentionally small. It supports styled paths, rectangles,
/// circles, ellipses, and text labels for quick debugging drawings and
/// examples.
pub type ThingToDraw {
  /// A `<path>` element.
  ///
  /// The first field is serialized as the element's `d` attribute. The second
  /// field is used directly as the element's `style` attribute after XML
  /// attribute escaping.
  StyledPath(svg_path.Path, String)

  /// A `<rect>` element.
  ///
  /// The fields are the top-left point, width, height, and raw CSS declarations
  /// for the `style` attribute.
  Rectangle(svg_path.Point, Float, Float, String)

  /// A `<circle>` element.
  ///
  /// The fields are the center point, radius, and raw CSS declarations for the
  /// `style` attribute.
  Circle(svg_path.Point, Float, String)

  /// An `<ellipse>` element.
  ///
  /// The fields are the center point, x/y radii, and raw CSS declarations for
  /// the `style` attribute.
  Ellipse(svg_path.Point, svg_path.Point, String)

  /// A `<text>` element.
  ///
  /// The fields are text content, raw CSS declarations for the `style`
  /// attribute, the text position, and the font size in SVG user units.
  Text(String, String, svg_path.Point, Int)
}

/// A list of items to render inside a generated SVG document.
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
      svg_path.subpath_assert([
        svg_path.Line(start: top_left, end: top_right),
        svg_path.Line(start: top_right, end: bottom_right),
        svg_path.Line(start: bottom_right, end: bottom_left),
        svg_path.Line(start: bottom_left, end: top_left),
      ])
        |> svg_path.subpath_assert_set_closed(closed: True),
      svg_path.subpath_assert([
        svg_path.Line(start: top_left, end: bottom_right),
      ]),
      svg_path.subpath_assert([
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
  <> "\" width=\""
  <> number_format.number(svg_path.bounding_box_width(view_box), with: format)
  <> "\" height=\""
  <> number_format.number(svg_path.bounding_box_height(view_box), with: format)
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
    Rectangle(top_left, width, height, style) ->
      rectangle_element(top_left, width, height, style, format)
    Circle(center, radius, style) ->
      circle_element(center, radius, style, format)
    Ellipse(center, radius, style) ->
      ellipse_element(center, radius, style, format)
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

fn rectangle_element(
  top_left: svg_path.Point,
  width: Float,
  height: Float,
  style: String,
  format: number_format.NumberFormat,
) -> String {
  "  <rect x=\""
  <> number_format.number(top_left.x, with: format)
  <> "\" y=\""
  <> number_format.number(top_left.y, with: format)
  <> "\" width=\""
  <> number_format.number(width, with: format)
  <> "\" height=\""
  <> number_format.number(height, with: format)
  <> "\" style=\""
  <> attribute_escape(style)
  <> "\" />"
}

fn circle_element(
  center: svg_path.Point,
  radius: Float,
  style: String,
  format: number_format.NumberFormat,
) -> String {
  "  <circle cx=\""
  <> number_format.number(center.x, with: format)
  <> "\" cy=\""
  <> number_format.number(center.y, with: format)
  <> "\" r=\""
  <> number_format.number(radius, with: format)
  <> "\" style=\""
  <> attribute_escape(style)
  <> "\" />"
}

fn ellipse_element(
  center: svg_path.Point,
  radius: svg_path.Point,
  style: String,
  format: number_format.NumberFormat,
) -> String {
  "  <ellipse cx=\""
  <> number_format.number(center.x, with: format)
  <> "\" cy=\""
  <> number_format.number(center.y, with: format)
  <> "\" rx=\""
  <> number_format.number(radius.x, with: format)
  <> "\" ry=\""
  <> number_format.number(radius.y, with: format)
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
