import gleam/dynamic.{type Dynamic}
import gleam/float
import svg_path
import svg_path/offset
import svg_path/serialize

const output = "examples/debug/figure_eight_band_in_band_comparison.svg"

const readme_output = "test/generated/readme/band_in_band_trimming.svg"

pub fn main() -> Nil {
  let source = figure_eight()
  let without_in_band = band(source, in_band: False)
  let with_in_band = band(source, in_band: True)
  let contents = drawing(source, without_in_band, with_in_band)
  let _ = write_file(output, contents)
  let _ = write_file(readme_output, contents)
  Nil
}

fn band(source: svg_path.Subpath, in_band in_band: Bool) -> svg_path.Path {
  let options =
    offset.Options(
      ..offset.default_options(),
      join: offset.Round,
      band_trimming: offset.BandTrimming(
        inner_cusps: True,
        outer_cusps: True,
        in_band:,
      ),
    )
  let assert Ok(band) =
    offset.subpath_band_with(
      source,
      inner_offset: 18.0,
      outer_offset: 34.0,
      options:,
    )
  band
}

fn figure_eight() -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(-336.0, -234.0),
      control2: svg_path.Point(-336.0, 234.0),
      end: svg_path.Point(0.0, 0.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(336.0, -234.0),
      control2: svg_path.Point(336.0, 234.0),
      end: svg_path.Point(0.0, 0.0),
    ),
  ])
  |> svg_path.subpath_assert_set_closed(closed: True)
}

fn drawing(
  source: svg_path.Subpath,
  without_in_band: svg_path.Path,
  with_in_band: svg_path.Path,
) -> String {
  let view_box =
    svg_path.BoundingBox(
      min: svg_path.Point(0.0, 0.0),
      max: svg_path.Point(1280.0, 460.0),
    )
  document_start(view_box)
  <> background(view_box)
  <> panel(source, without_in_band, "in_band: False", center_x: 320.0)
  <> panel(source, with_in_band, "in_band: True", center_x: 960.0)
  <> "</svg>\n"
}

fn panel(
  source: svg_path.Subpath,
  band: svg_path.Path,
  label: String,
  center_x center_x: Float,
) -> String {
  let geometry = svg_path.Path([source, ..svg_path.path_subpaths(band)])
  let assert Ok(svg_path.BoundingBox(min:, max:)) =
    svg_path.path_bounding_box(geometry)
  let center =
    svg_path.Point({ min.x +. max.x } /. 2.0, { min.y +. max.y } /. 2.0)
  let available_width = 500.0
  let available_height = 365.0
  let scale =
    float.min(
      available_width /. { max.x -. min.x },
      available_height /. { max.y -. min.y },
    )
  "  <text x=\""
  <> float.to_string(center_x)
  <> "\" y=\"38\" text-anchor=\"middle\" font-family=\"sans-serif\" font-size=\"22\" font-weight=\"600\" fill=\"#14532d\">"
  <> label
  <> "</text>\n"
  <> "  <g transform=\"translate("
  <> float.to_string(center_x)
  <> " 250) scale("
  <> float.to_string(scale)
  <> ") translate("
  <> float.to_string(0.0 -. center.x)
  <> " "
  <> float.to_string(0.0 -. center.y)
  <> ")\">\n"
  <> "    <path d=\""
  <> serialize.path(band)
  <> "\" fill=\"#bbf7d0\" stroke=\"#14532d\" stroke-width=\"3.2\" vector-effect=\"non-scaling-stroke\" stroke-linejoin=\"round\" />\n"
  <> "    <path d=\""
  <> serialize.subpath(source)
  <> "\" fill=\"none\" stroke=\"#be123c\" stroke-width=\"2.2\" vector-effect=\"non-scaling-stroke\" stroke-dasharray=\"7 6\" stroke-linecap=\"round\" />\n"
  <> "  </g>\n"
}

fn document_start(view_box: svg_path.BoundingBox) -> String {
  let svg_path.BoundingBox(min:, max:) = view_box
  "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1280\" height=\"460\" viewBox=\""
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
