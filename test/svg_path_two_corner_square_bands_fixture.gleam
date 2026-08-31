import gleam/dynamic.{type Dynamic}
import gleam/float
import svg_path
import svg_path/offset
import svg_path/serialize

const output = "examples/debug/four_concave_corner_square_band_trimming_comparison.svg"

const readme_output = "test/generated/readme/band_cusp_trimming.svg"

pub fn main() -> Nil {
  let source = source_subpath()
  let all = band(source, inner_cusps: True, outer_cusps: True)
  let outer_only = band(source, inner_cusps: False, outer_cusps: True)
  let neither = band(source, inner_cusps: False, outer_cusps: False)
  let contents = drawing(source, all, outer_only, neither)
  let _ = write_file(output, contents)
  let _ = write_file(readme_output, contents)
  Nil
}

fn band(
  source: svg_path.Subpath,
  inner_cusps inner_cusps: Bool,
  outer_cusps outer_cusps: Bool,
) -> svg_path.Path {
  let options =
    offset.Options(
      ..offset.default_options(),
      join: offset.Round,
      band_trimming: offset.BandTrimming(
        inner_cusps:,
        outer_cusps:,
        in_band: True,
      ),
    )
  let assert Ok(band) =
    offset.subpath_band_with(
      source,
      inner_offset: 1.7,
      outer_offset: 1.8,
      options:,
    )
  band
}

fn source_subpath() -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.Line(svg_path.Point(1.0, 0.0), svg_path.Point(3.0, 0.0)),
    inward_arc(svg_path.Point(3.0, 0.0), svg_path.Point(4.0, 1.0)),
    svg_path.Line(svg_path.Point(4.0, 1.0), svg_path.Point(4.0, 3.0)),
    inward_arc(svg_path.Point(4.0, 3.0), svg_path.Point(3.0, 4.0)),
    svg_path.Line(svg_path.Point(3.0, 4.0), svg_path.Point(1.0, 4.0)),
    inward_arc(svg_path.Point(1.0, 4.0), svg_path.Point(0.0, 3.0)),
    svg_path.Line(svg_path.Point(0.0, 3.0), svg_path.Point(0.0, 1.0)),
    inward_arc(svg_path.Point(0.0, 1.0), svg_path.Point(1.0, 0.0)),
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

fn drawing(
  source: svg_path.Subpath,
  all: svg_path.Path,
  outer_only: svg_path.Path,
  neither: svg_path.Path,
) -> String {
  let view_box =
    svg_path.BoundingBox(
      min: svg_path.Point(0.0, 0.0),
      max: svg_path.Point(22.0, 7.5),
    )
  document_start(view_box)
  <> background(view_box)
  <> panel(
    source,
    all,
    "inner_cusps: True · outer_cusps: True · in_band: True",
    center_x: 3.75,
  )
  <> panel(
    source,
    outer_only,
    "inner_cusps: False · outer_cusps: True · in_band: True",
    center_x: 11.0,
  )
  <> panel(
    source,
    neither,
    "inner_cusps: False · outer_cusps: False · in_band: True",
    center_x: 18.25,
  )
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
  let center_y = { min.y +. max.y } /. 2.0
  let geometry_center_x = { min.x +. max.x } /. 2.0
  "  <g transform=\"translate("
  <> float.to_string(center_x)
  <> " 4.05) scale(0.72) translate("
  <> float.to_string(0.0 -. geometry_center_x)
  <> " "
  <> float.to_string(0.0 -. center_y)
  <> ")\">\n"
  <> "    <path d=\""
  <> serialize.path(band)
  <> "\" fill=\"#f97316\" fill-opacity=\"0.48\" fill-rule=\"nonzero\" stroke=\"#c2410c\" stroke-width=\"0.025\" stroke-linejoin=\"round\" />\n"
  <> "    <path d=\""
  <> serialize.subpath(source)
  <> "\" fill=\"none\" stroke=\"#2563eb\" stroke-width=\"0.035\" stroke-dasharray=\"0.10 0.08\" stroke-linejoin=\"round\" />\n"
  <> "  </g>\n"
  <> "  <text x=\""
  <> float.to_string(center_x)
  <> "\" y=\"0.38\" font-family=\"sans-serif\" font-size=\"0.16\" font-weight=\"600\" fill=\"#111827\" text-anchor=\"middle\">"
  <> label
  <> "</text>\n"
}

fn document_start(view_box: svg_path.BoundingBox) -> String {
  let svg_path.BoundingBox(min:, max:) = view_box
  "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1800\" height=\"620\" viewBox=\""
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
