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

const output = "examples/debug/package_title_s_first_offset_offside_ambiguity.svg"

pub fn main() -> Nil {
  let assert Ok(contents) = read_file(input)
  let assert Ok(title) = parse.path(first_path_data(contents))
  let assert [s, ..] = svg_path.path_subpaths(title)
  let source = svg_path.Path([s])
  let options =
    offset.Options(
      ..offset.default_options(),
      fitting: offset.FittingOptions(tolerance: 0.01, samples: 5, max_depth: 12),
      distance_options: svg_path.DistanceOptions(
        ..svg_path.default_distance_options(),
        tolerance: 0.000000001,
      ),
    )
  let assert Ok(trace) =
    offset.internal_path_single_offset_contamination_arrangement_trace(
      source,
      offset: 1.0,
      options:,
    )
  let _ = write_file(output, drawing(source, trace))
  Nil
}

fn drawing(
  source: svg_path.Path,
  trace: List(offset.SingleOffsetContaminationTraceEdge),
) -> String {
  let edge_subpaths =
    list.map(trace, fn(edge) {
      let offset.SingleOffsetContaminationTraceEdge(segment:, ..) = edge
      svg_path.segment_as_subpath(segment)
    })
  let geometry =
    svg_path.Path(list.append(svg_path.path_subpaths(source), edge_subpaths))
  let view_box = padded_box(geometry, 0.5)
  document_start(view_box)
  <> background(view_box)
  <> "  <path d=\""
  <> serialize.path(source)
  <> "\" fill=\"none\" stroke=\"#94a3b8\" stroke-width=\"0.025\" opacity=\"0.55\" />\n"
  <> list.fold(trace, "", fn(markup, edge) {
    let offset.SingleOffsetContaminationTraceEdge(
      id:,
      segment:,
      start_vertex:,
      end_vertex:,
      offside:,
      ..,
    ) = edge
    let color = case offside {
      True -> "#dc2626"
      False -> "#16a34a"
    }
    let assert Ok(midpoint) = svg_path.segment_point(segment, at: 0.5)
    markup
    <> "  <path d=\""
    <> serialize.segment(segment)
    <> "\" fill=\"none\" stroke=\""
    <> color
    <> "\" stroke-width=\"0.035\" stroke-linecap=\"round\" />\n"
    <> vertex(svg_path.segment_start(segment), start_vertex)
    <> vertex(svg_path.segment_end(segment), end_vertex)
    <> label(midpoint, "a" <> int.to_string(id), "#1e3a8a")
  })
  <> ambiguous_vertex_label(trace, 19)
  <> ambiguous_vertex_label(trace, 94)
  <> "</svg>\n"
}

fn vertex(point: svg_path.Point, id: Int) -> String {
  let ambiguous = id == 19 || id == 94
  let radius = case ambiguous {
    True -> 0.07
    False -> 0.025
  }
  let fill = case ambiguous {
    True -> "#f59e0b"
    False -> "#111827"
  }
  "  <circle cx=\""
  <> float.to_string(point.x)
  <> "\" cy=\""
  <> float.to_string(point.y)
  <> "\" r=\""
  <> float.to_string(radius)
  <> "\" fill=\""
  <> fill
  <> "\" />\n"
}

fn ambiguous_vertex_label(
  trace: List(offset.SingleOffsetContaminationTraceEdge),
  id: Int,
) -> String {
  let point =
    trace
    |> list.find_map(fn(edge) {
      let offset.SingleOffsetContaminationTraceEdge(
        segment:,
        start_vertex:,
        end_vertex:,
        ..,
      ) = edge
      case start_vertex == id, end_vertex == id {
        True, _ -> Ok(svg_path.segment_start(segment))
        _, True -> Ok(svg_path.segment_end(segment))
        False, False -> Error(Nil)
      }
    })
  case point {
    Ok(point) -> label(point, "v" <> int.to_string(id), "#92400e")
    Error(_) -> ""
  }
}

fn label(point: svg_path.Point, text: String, color: String) -> String {
  "  <text x=\""
  <> float.to_string(point.x)
  <> "\" y=\""
  <> float.to_string(point.y -. 0.06)
  <> "\" font-family=\"sans-serif\" font-size=\"0.09\" fill=\""
  <> color
  <> "\" stroke=\"white\" stroke-width=\"0.018\" paint-order=\"stroke fill\" text-anchor=\"middle\">"
  <> text
  <> "</text>\n"
}

fn padded_box(path: svg_path.Path, padding: Float) -> svg_path.BoundingBox {
  let assert Ok(svg_path.BoundingBox(min:, max:)) =
    svg_path.path_bounding_box(path)
  svg_path.BoundingBox(
    min: svg_path.Point(min.x -. padding, min.y -. padding),
    max: svg_path.Point(max.x +. padding, max.y +. padding),
  )
}

fn document_start(view_box: svg_path.BoundingBox) -> String {
  let svg_path.BoundingBox(min:, max:) = view_box
  "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1200\" height=\"700\" viewBox=\""
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
