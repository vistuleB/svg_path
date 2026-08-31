import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/list
import svg_path
import svg_path/offset
import svg_path/serialize

const inner_18_outer_34_output = "examples/debug/figure_eight_band_inner_18_outer_34.svg"

const inner_34_outer_18_output = "examples/debug/figure_eight_band_inner_34_outer_18.svg"

const inner_minus_18_outer_minus_34_output = "examples/debug/figure_eight_band_inner_minus_18_outer_minus_34.svg"

const inner_minus_34_outer_minus_18_output = "examples/debug/figure_eight_band_inner_minus_34_outer_minus_18.svg"

pub fn main() -> Nil {
  let source = figure_eight()
  let options = offset.Options(..offset.default_options(), join: offset.Round)
  let assert Ok(inner_18_outer_34) =
    offset.subpath_band_with(
      source,
      inner_offset: 18.0,
      outer_offset: 34.0,
      options:,
    )
  let assert Ok(inner_34_outer_18) =
    offset.subpath_band_with(
      source,
      inner_offset: 34.0,
      outer_offset: 18.0,
      options:,
    )
  let assert Ok(inner_minus_18_outer_minus_34) =
    offset.subpath_band_with(
      source,
      inner_offset: -18.0,
      outer_offset: -34.0,
      options:,
    )
  let assert Ok(inner_minus_34_outer_minus_18) =
    offset.subpath_band_with(
      source,
      inner_offset: -34.0,
      outer_offset: -18.0,
      options:,
    )
  let band_subpaths =
    [
      inner_18_outer_34,
      inner_34_outer_18,
      inner_minus_18_outer_minus_34,
      inner_minus_34_outer_minus_18,
    ]
    |> list.flat_map(svg_path.path_subpaths)
  let geometry = svg_path.Path([source, ..band_subpaths])
  let assert Ok(svg_path.BoundingBox(min:, max:)) =
    svg_path.path_bounding_box(geometry)
  let padding = 0.15 *. float.max(max.x -. min.x, max.y -. min.y)
  let view_box =
    svg_path.BoundingBox(
      min: svg_path.Point(min.x -. padding, min.y -. padding),
      max: svg_path.Point(max.x +. padding, max.y +. padding),
    )

  let _ = ensure_dir(inner_18_outer_34_output)
  let _ =
    write_file(
      inner_18_outer_34_output,
      drawing(source, inner_18_outer_34, view_box),
    )
  let _ =
    write_file(
      inner_34_outer_18_output,
      drawing(source, inner_34_outer_18, view_box),
    )
  let _ =
    write_file(
      inner_minus_18_outer_minus_34_output,
      drawing(source, inner_minus_18_outer_minus_34, view_box),
    )
  let _ =
    write_file(
      inner_minus_34_outer_minus_18_output,
      drawing(source, inner_minus_34_outer_minus_18, view_box),
    )
  Nil
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
  band: svg_path.Path,
  view_box: svg_path.BoundingBox,
) -> String {
  let svg_path.BoundingBox(min:, max:) = view_box
  let width = max.x -. min.x
  let height = max.y -. min.y
  "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1000\" height=\"700\" viewBox=\""
  <> float.to_string(min.x)
  <> " "
  <> float.to_string(min.y)
  <> " "
  <> float.to_string(width)
  <> " "
  <> float.to_string(height)
  <> "\">\n"
  <> "  <rect x=\""
  <> float.to_string(min.x)
  <> "\" y=\""
  <> float.to_string(min.y)
  <> "\" width=\""
  <> float.to_string(width)
  <> "\" height=\""
  <> float.to_string(height)
  <> "\" fill=\"white\" />\n"
  <> "  <path d=\""
  <> serialize.path(band)
  <> "\" fill=\"#86efac\" fill-opacity=\"0.62\" fill-rule=\"nonzero\" stroke=\"#15803d\" stroke-width=\"2.5\" stroke-linejoin=\"round\" />\n"
  <> "  <path d=\""
  <> serialize.subpath(source)
  <> "\" fill=\"none\" stroke=\"#dc2626\" stroke-width=\"2.0\" stroke-dasharray=\"8 6\" />\n"
  <> "</svg>\n"
}

@external(erlang, "filelib", "ensure_dir")
fn ensure_dir(path: String) -> Dynamic

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
