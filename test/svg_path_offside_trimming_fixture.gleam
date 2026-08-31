import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/list
import svg_path
import svg_path/offset
import svg_path/serialize

const output = "examples/debug/concentric_rectangles_single_offset_offside_comparison.svg"

pub fn main() -> Nil {
  let source = concentric_rectangles()
  let without_offside = single_offset(source, offside: False)
  let with_offside = single_offset(source, offside: True)
  let _ = write_file(output, drawing(source, without_offside, with_offside))
  Nil
}

fn concentric_rectangles() -> svg_path.Path {
  let outer =
    rectangle(left: -2.0, top: -1.5, right: 2.0, bottom: 1.5, clockwise: True)
  let inner =
    rectangle(left: -1.0, top: -0.5, right: 1.0, bottom: 0.5, clockwise: False)
  svg_path.Path([outer, inner])
}

fn rectangle(
  left left: Float,
  top top: Float,
  right right: Float,
  bottom bottom: Float,
  clockwise clockwise: Bool,
) -> svg_path.Subpath {
  let top_left = svg_path.Point(left, top)
  let top_right = svg_path.Point(right, top)
  let bottom_right = svg_path.Point(right, bottom)
  let bottom_left = svg_path.Point(left, bottom)
  let points = case clockwise {
    True -> [top_left, top_right, bottom_right, bottom_left]
    False -> [top_left, bottom_left, bottom_right, top_right]
  }
  svg_path.subpath_assert_polyline(list.append(points, [top_left]))
  |> svg_path.subpath_assert_set_closed(closed: True)
}

fn single_offset(
  source: svg_path.Path,
  offside offside: Bool,
) -> svg_path.Path {
  let options =
    offset.Options(
      ..offset.default_options(),
      join: offset.Round,
      single_offset_trimming: offset.SingleOffsetTrimming(
        offside:,
        final_trimming: offset.NoTrimming,
      ),
    )
  let assert Ok(path) = offset.path_with(source, offset: 1.2, options:)
  path
}

fn drawing(
  source: svg_path.Path,
  without_offside: svg_path.Path,
  with_offside: svg_path.Path,
) -> String {
  let view_box =
    svg_path.BoundingBox(
      min: svg_path.Point(0.0, 0.0),
      max: svg_path.Point(15.0, 7.0),
    )
  document_start(view_box)
  <> background(view_box)
  <> panel(source, without_offside, "offside: False", center_x: 3.75)
  <> panel(source, with_offside, "offside: True", center_x: 11.25)
  <> "</svg>\n"
}

fn panel(
  source: svg_path.Path,
  offset_path: svg_path.Path,
  label: String,
  center_x center_x: Float,
) -> String {
  let geometry =
    svg_path.Path(list.append(
      svg_path.path_subpaths(source),
      svg_path.path_subpaths(offset_path),
    ))
  let assert Ok(svg_path.BoundingBox(min:, max:)) =
    svg_path.path_bounding_box(geometry)
  let geometry_center_x = { min.x +. max.x } /. 2.0
  let geometry_center_y = { min.y +. max.y } /. 2.0
  "  <g transform=\"translate("
  <> float.to_string(center_x)
  <> " 3.65) scale(0.9) translate("
  <> float.to_string(0.0 -. geometry_center_x)
  <> " "
  <> float.to_string(0.0 -. geometry_center_y)
  <> ")\">\n"
  <> "    <path d=\""
  <> serialize.path(source)
  <> "\" fill=\"none\" stroke=\"#94a3b8\" stroke-width=\"0.055\" stroke-linejoin=\"round\" />\n"
  <> "    <path d=\""
  <> serialize.path(offset_path)
  <> "\" fill=\"none\" stroke=\"#2563eb\" stroke-width=\"0.04\" stroke-linejoin=\"round\" />\n"
  <> orientation_arrows()
  <> "  </g>\n"
  <> "  <text x=\""
  <> float.to_string(center_x)
  <> "\" y=\"0.35\" font-family=\"sans-serif\" font-size=\"0.24\" font-weight=\"600\" fill=\"#111827\" text-anchor=\"middle\">"
  <> label
  <> "</text>\n"
}

fn orientation_arrows() -> String {
  // On the left edges, the clockwise outer rectangle travels upward and the
  // counterclockwise inner rectangle travels downward.
  "    <path d=\"M -2 -0.18 L -2.156 0.09 L -1.844 0.09 Z\" fill=\"#94a3b8\" />\n"
  <> "    <path d=\"M -1 0.18 L -1.156 -0.09 L -0.844 -0.09 Z\" fill=\"#94a3b8\" />\n"
}

fn document_start(view_box: svg_path.BoundingBox) -> String {
  let svg_path.BoundingBox(min:, max:) = view_box
  "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1500\" height=\"700\" viewBox=\""
  <> float.to_string(min.x)
  <> " "
  <> float.to_string(min.y)
  <> " "
  <> float.to_string(max.x -. min.x)
  <> " "
  <> float.to_string(max.y -. min.y)
  <> "\">\n"
}

fn background(view_box: svg_path.BoundingBox) -> String {
  let svg_path.BoundingBox(min:, max:) = view_box
  "  <rect x=\""
  <> float.to_string(min.x)
  <> "\" y=\""
  <> float.to_string(min.y)
  <> "\" width=\""
  <> float.to_string(max.x -. min.x)
  <> "\" height=\""
  <> float.to_string(max.y -. min.y)
  <> "\" fill=\"white\" />\n"
}

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
