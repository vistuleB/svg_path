import gleam/dynamic.{type Dynamic}
import gleam/float
import svg_path
import svg_path/offset
import svg_path/serialize

const outside_output = "examples/debug/two_corner_square_band_1_7_1_8_current.svg"

const inside_output = "examples/debug/two_corner_square_band_minus_0_7_minus_0_8_current.svg"

pub fn main() -> Nil {
  let source = source_subpath()
  let options = offset.Options(..offset.default_options(), join: offset.Round)
  let assert Ok(outside) =
    offset.subpath_band_with(source, distance_a: 1.7, distance_b: 1.8, options:)
  let assert Ok(inside) =
    offset.subpath_band_with(
      source,
      distance_a: -0.7,
      distance_b: -0.8,
      options:,
    )
  let _ = write_file(outside_output, drawing(source, outside))
  let _ = write_file(inside_output, drawing(source, inside))
  Nil
}

fn source_subpath() -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.Line(svg_path.Point(1.0, 0.0), svg_path.Point(3.0, 0.0)),
    inward_arc(svg_path.Point(3.0, 0.0), svg_path.Point(4.0, 1.0)),
    svg_path.Line(svg_path.Point(4.0, 1.0), svg_path.Point(4.0, 3.0)),
    svg_path.Line(svg_path.Point(4.0, 3.0), svg_path.Point(3.0, 4.0)),
    svg_path.Line(svg_path.Point(3.0, 4.0), svg_path.Point(1.0, 4.0)),
    inward_arc(svg_path.Point(1.0, 4.0), svg_path.Point(0.0, 3.0)),
    svg_path.Line(svg_path.Point(0.0, 3.0), svg_path.Point(0.0, 1.0)),
    svg_path.Line(svg_path.Point(0.0, 1.0), svg_path.Point(1.0, 0.0)),
  ])
  |> svg_path.subpath_assert_set_closed(closed: True)
}

fn inward_arc(start: svg_path.Point, end: svg_path.Point) -> svg_path.Segment {
  svg_path.Arc(
    start:,
    radius: svg_path.Point(1.0, 1.0),
    x_axis_rotation: 0.0,
    large_arc: False,
    sweep: False,
    end:,
  )
}

fn drawing(source: svg_path.Subpath, band: svg_path.Path) -> String {
  let geometry = svg_path.Path([source, ..svg_path.path_subpaths(band)])
  let assert Ok(svg_path.BoundingBox(min:, max:)) =
    svg_path.path_bounding_box(geometry)
  let padding = 0.45
  let x = min.x -. padding
  let y = min.y -. padding
  let width = max.x -. min.x +. 2.0 *. padding
  let height = max.y -. min.y +. 2.0 *. padding
  "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"900\" height=\"900\" viewBox=\""
  <> float.to_string(x)
  <> " "
  <> float.to_string(y)
  <> " "
  <> float.to_string(width)
  <> " "
  <> float.to_string(height)
  <> "\">\n"
  <> "  <rect x=\""
  <> float.to_string(x)
  <> "\" y=\""
  <> float.to_string(y)
  <> "\" width=\""
  <> float.to_string(width)
  <> "\" height=\""
  <> float.to_string(height)
  <> "\" fill=\"white\" />\n"
  <> "  <path d=\""
  <> serialize.path(band)
  <> "\" fill=\"#f97316\" fill-opacity=\"0.48\" fill-rule=\"nonzero\" stroke=\"#c2410c\" stroke-width=\"0.025\" stroke-linejoin=\"round\" />\n"
  <> "  <path d=\""
  <> serialize.subpath(source)
  <> "\" fill=\"none\" stroke=\"#2563eb\" stroke-width=\"0.035\" stroke-dasharray=\"0.10 0.08\" stroke-linejoin=\"round\" />\n"
  <> "</svg>\n"
}

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
