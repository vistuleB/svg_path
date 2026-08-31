import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import svg_path
import svg_path/offset
import svg_path/parse
import svg_path/serialize

const input = "examples/debug/package_title.svg"

const first_output = "examples/debug/v_second_offset_1_04_fixture.svg"

const arrangement_output = "examples/debug/v_third_offset_i_to_m_arrangement_1_04.svg"

const third_output = "examples/debug/v_third_offset_1_04_final.svg"

pub fn main() -> Nil {
  let assert Ok(contents) = read_file(input)
  let assert Ok(title) = parse.path(first_path_data(contents))
  let assert [_, v, ..] = svg_path.path_subpaths(title)
  let options = offset.default_options()
  let assert Ok(first) = offset.subpath_with(v, offset: 1.04, options:)
  let assert Ok(second) = offset.path_with(first, offset: 1.04, options:)
  let assert Ok(trace) =
    offset.internal_path_single_offset_contamination_arrangement_trace(
      second,
      offset: 1.04,
      options:,
    )
  let assert Ok(third) = offset.path_with(second, offset: 1.04, options:)
  let _ = write_file(first_output, first_offset_drawing(first, second))
  let _ = write_file(arrangement_output, arrangement_drawing(second, trace))
  let _ = write_file(third_output, third_offset_drawing(first, second, third))
  Nil
}

fn third_offset_drawing(
  first: svg_path.Path,
  second: svg_path.Path,
  third: svg_path.Path,
) -> String {
  let geometry =
    svg_path.Path(
      list.flatten([
        svg_path.path_subpaths(first),
        svg_path.path_subpaths(second),
        svg_path.path_subpaths(third),
      ]),
    )
  let view_box = padded_box(geometry, 0.8)
  document_start(view_box, 900, 900)
  <> background(view_box)
  <> "  <path d=\""
  <> serialize.path(first)
  <> "\" fill=\"none\" stroke=\"#cbd5e1\" stroke-width=\"0.055\" />\n"
  <> "  <path d=\""
  <> serialize.path(second)
  <> "\" fill=\"none\" stroke=\"#2563eb\" stroke-width=\"0.045\" />\n"
  <> "  <path d=\""
  <> serialize.path(third)
  <> "\" fill=\"none\" stroke=\"#dc2626\" stroke-width=\"0.045\" />\n"
  <> "</svg>\n"
}

fn first_offset_drawing(
  source: svg_path.Path,
  offset: svg_path.Path,
) -> String {
  let geometry =
    svg_path.Path(list.append(
      svg_path.path_subpaths(source),
      svg_path.path_subpaths(offset),
    ))
  let view_box = padded_box(geometry, 0.8)
  document_start(view_box, 900, 900)
  <> background(view_box)
  <> "  <path d=\""
  <> serialize.path(source)
  <> "\" fill=\"none\" stroke=\"#94a3b8\" stroke-width=\"0.045\" />\n"
  <> "  <path d=\""
  <> serialize.path(offset)
  <> "\" fill=\"none\" stroke=\"#2563eb\" stroke-width=\"0.04\" stroke-linejoin=\"round\" />\n"
  <> "</svg>\n"
}

fn arrangement_drawing(
  first: svg_path.Path,
  trace: List(offset.SingleOffsetContaminationTraceEdge),
) -> String {
  let edge_subpaths =
    list.map(trace, fn(edge) {
      let offset.SingleOffsetContaminationTraceEdge(segment:, ..) = edge
      svg_path.segment_as_subpath(segment)
    })
  let geometry =
    svg_path.Path(list.append(svg_path.path_subpaths(first), edge_subpaths))
  let view_box = padded_box(geometry, 0.8)
  let edge_markup =
    trace
    |> list.fold("", fn(markup, edge) {
      let offset.SingleOffsetContaminationTraceEdge(
        id:,
        segment:,
        offside:,
        survives:,
        ..,
      ) = edge
      let color = case offside, survives {
        True, _ -> "#dc2626"
        False, True -> "#9333ea"
        False, False -> "#16a34a"
      }
      let start = svg_path.segment_start(segment)
      let end = svg_path.segment_end(segment)
      let assert Ok(midpoint) = svg_path.segment_point(segment, at: 0.5)
      markup
      <> "  <path d=\""
      <> serialize.segment(segment)
      <> "\" fill=\"none\" stroke=\""
      <> color
      <> "\" stroke-width=\"0.025\" stroke-linecap=\"round\" />\n"
      <> point(start)
      <> point(end)
      <> "  <text x=\""
      <> float.to_string(midpoint.x)
      <> "\" y=\""
      <> float.to_string(midpoint.y)
      <> "\" font-family=\"sans-serif\" font-size=\"0.08\" fill=\"#1e3a8a\" stroke=\"white\" stroke-width=\"0.0125\" paint-order=\"stroke fill\" text-anchor=\"middle\">"
      <> int.to_string(id)
      <> "</text>\n"
    })
  document_start(view_box, 900, 900)
  <> background(view_box)
  <> "  <path d=\""
  <> serialize.path(first)
  <> "\" fill=\"none\" stroke=\"#94a3b8\" stroke-width=\"0.055\" opacity=\"0.5\" />\n"
  <> edge_markup
  <> "</svg>\n"
}

fn point(point: svg_path.Point) -> String {
  "  <circle cx=\""
  <> float.to_string(point.x)
  <> "\" cy=\""
  <> float.to_string(point.y)
  <> "\" r=\"0.025\" fill=\"#111827\" />\n"
}

fn padded_box(path: svg_path.Path, padding: Float) -> svg_path.BoundingBox {
  let assert Ok(svg_path.BoundingBox(min:, max:)) =
    svg_path.path_bounding_box(path)
  svg_path.BoundingBox(
    min: svg_path.Point(min.x -. padding, min.y -. padding),
    max: svg_path.Point(max.x +. padding, max.y +. padding),
  )
}

fn document_start(
  view_box: svg_path.BoundingBox,
  width: Int,
  height: Int,
) -> String {
  let svg_path.BoundingBox(min:, max:) = view_box
  "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\""
  <> int.to_string(width)
  <> "\" height=\""
  <> int.to_string(height)
  <> "\" viewBox=\""
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

fn first_path_data(contents: String) -> String {
  let assert [_, after_attribute] = string.split(contents, on: " d=\"")
  let assert [data, ..] = string.split(after_attribute, on: "\"")
  data
}

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(String, Dynamic)

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
