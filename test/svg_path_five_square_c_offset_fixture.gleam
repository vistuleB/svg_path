import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/list
import svg_path
import svg_path/degeneracy
import svg_path/offset
import svg_path/serialize

const output = "examples/debug/five_square_concave_c_offset_plus_0_5_normalized.svg"

pub fn main() -> Nil {
  let source =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(2.0, 0.0),
      svg_path.Point(2.0, 1.0),
      svg_path.Point(1.0, 1.0),
      svg_path.Point(1.0, 2.0),
      svg_path.Point(2.0, 2.0),
      svg_path.Point(2.0, 3.0),
      svg_path.Point(0.0, 3.0),
    ])
  let assert Ok(offset_path) = offset.subpath(source, offset: 0.5)
  let offset.FittingOptions(tolerance:, ..) = offset.default_fitting_options()
  let assert Ok(normalized_subpaths) =
    offset_path
    |> svg_path.path_subpaths
    |> list.try_map(degeneracy.normalize_degenerate_segments(_, tolerance:))
  let normalized = svg_path.Path(normalized_subpaths)
  let geometry = svg_path.Path([source, ..normalized_subpaths])
  let assert Ok(svg_path.BoundingBox(min:, max:)) =
    svg_path.path_bounding_box(geometry)
  let padding = 0.35
  let x = min.x -. padding
  let y = min.y -. padding
  let width = max.x -. min.x +. 2.0 *. padding
  let height = max.y -. min.y +. 2.0 *. padding

  let drawing =
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"640\" height=\"720\" viewBox=\""
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
    <> "\" fill=\"white\"/>\n"
    <> "  <path d=\""
    <> serialize.path(normalized)
    <> "\" fill=\"none\" stroke=\"#c2410c\" stroke-width=\"0.035\" stroke-linejoin=\"miter\"/>\n"
    <> "  <path d=\""
    <> serialize.subpath(source)
    <> "\" fill=\"none\" stroke=\"#18243a\" stroke-width=\"0.045\" stroke-linejoin=\"miter\"/>\n"
    <> "</svg>\n"

  let _ = write_file(output, drawing)
  Nil
}

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
