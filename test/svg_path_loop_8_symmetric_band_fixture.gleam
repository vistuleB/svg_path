import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/io
import gleam/list
import gleam/string
import svg_path
import svg_path/offset
import svg_path/parse
import svg_path/serialize

const input = "examples/debug/loop_8_symmetric_arcs.svg"

const output = "examples/debug/loop_8_symmetric_band_minus_5_plus_25.svg"

const arrangement_output = "examples/debug/loop_8_symmetric_band_minus_5_plus_25_arrangement.svg"

const k_arrangement_output = "examples/debug/loop_8_symmetric_band_minus_5_plus_25_k_arrangement.svg"

const a24_closeup_output = "examples/debug/loop_8_symmetric_band_minus_5_plus_25_a24_closeup.svg"

pub fn main() -> Nil {
  let assert Ok(contents) = read_file(input)
  let assert Ok(svg_path.Path([source])) = parse.path(first_path_data(contents))
  let options = offset.default_options()
  let untrimmed =
    offset.subpath_band_untrimmed_with(
      source,
      inner_offset: -5.0,
      outer_offset: 25.0,
      options:,
    )
  io.println(case untrimmed {
    Ok(path) ->
      "untrimmed completed with "
      <> string.inspect(list.length(svg_path.path_subpaths(path)))
      <> " subpaths"
    Error(error) -> "untrimmed error: " <> string.inspect(error)
  })
  let assert Ok(trace) =
    offset.internal_subpath_band_arrangement_trace(
      source,
      inner_offset: -5.0,
      outer_offset: 25.0,
      options:,
    )
  let assert Ok(k_trace) =
    offset.internal_subpath_band_k_trimming_arrangement_trace(
      source,
      inner_offset: -5.0,
      outer_offset: 25.0,
      options:,
    )
  let assert Ok(band) =
    offset.subpath_band_with(
      source,
      inner_offset: -5.0,
      outer_offset: 25.0,
      options:,
    )
  let _ = write_file(output, drawing(source, band))
  let _ = write_file(arrangement_output, arrangement_drawing(source, trace))
  let _ =
    write_file(k_arrangement_output, k_arrangement_drawing(source, k_trace))
  let _ = write_file(a24_closeup_output, a24_closeup_drawing(k_trace))
  Nil
}

fn k_arrangement_drawing(
  source: svg_path.Subpath,
  trace: List(offset.KTrimmingArrangementTraceEdge),
) -> String {
  let edge_subpaths =
    list.map(trace, fn(item) {
      let offset.KTrimmingArrangementTraceEdge(segment:, ..) = item
      svg_path.segment_as_subpath(segment)
    })
  let assert Ok(svg_path.BoundingBox(min:, max:)) =
    svg_path.path_bounding_box(svg_path.Path([source, ..edge_subpaths]))
  let padding = 18.0
  let x = min.x -. padding
  let y = min.y -. padding
  let width = max.x -. min.x +. 2.0 *. padding
  let height = max.y -. min.y +. 2.0 *. padding
  let edges =
    list.fold(trace, "", fn(markup, item) {
      let offset.KTrimmingArrangementTraceEdge(
        side_index:,
        id:,
        segment:,
        offset_image:,
        submerged:,
      ) = item
      let color = case offset_image, submerged {
        False, _ -> "#6b7280"
        True, True -> "#dc2626"
        True, False -> "#16a34a"
      }
      let side = case side_index {
        0 -> "a"
        _ -> "b"
      }
      markup
      <> "  <path d=\""
      <> serialize.segment(segment)
      <> "\" fill=\"none\" stroke=\""
      <> color
      <> "\" stroke-width=\"0.8\" stroke-linecap=\"round\" stroke-opacity=\"0.58\" />\n"
      <> graph_point(svg_path.segment_start(segment))
      <> graph_point(svg_path.segment_end(segment))
      <> graph_label_text(segment, side <> string.inspect(id), color, 3.0)
    })
  svg_open(x, y, width, height, 900, 900)
  <> "  <path d=\""
  <> serialize.subpath(source)
  <> "\" fill=\"none\" stroke=\"#94a3b8\" stroke-width=\"0.6\" opacity=\"0.45\" />\n"
  <> edges
  <> "</svg>\n"
}

fn a24_closeup_drawing(
  trace: List(offset.KTrimmingArrangementTraceEdge),
) -> String {
  let neighborhood =
    list.filter(trace, fn(item) {
      let offset.KTrimmingArrangementTraceEdge(side_index:, id:, ..) = item
      side_index == 0 && id >= 23 && id <= 25
    })
  let assert [_, _, _] = neighborhood
  let center_x = 43.20435011275111
  let center_y = 213.4740799012965
  let width = 0.11225813683736932
  let height = 0.12395782397117387
  let x = center_x -. width /. 2.0
  let y = center_y -. height /. 2.0
  let edges =
    list.fold(neighborhood, "", fn(markup, item) {
      let offset.KTrimmingArrangementTraceEdge(id:, segment:, submerged:, ..) =
        item
      let color = case submerged {
        True -> "#dc2626"
        False -> "#16a34a"
      }
      markup
      <> "  <path d=\""
      <> serialize.segment(segment)
      <> "\" fill=\"none\" stroke=\""
      <> color
      <> "\" stroke-width=\"0.0012\" stroke-linecap=\"round\" stroke-opacity=\"0.58\" />\n"
      <> closeup_point(svg_path.segment_start(segment))
      <> closeup_point(svg_path.segment_end(segment))
      <> closeup_label(segment, id, color)
    })
  svg_open(x, y, width, height, 900, 500) <> edges <> "</svg>\n"
}

fn svg_open(
  x: Float,
  y: Float,
  width: Float,
  height: Float,
  pixel_width: Int,
  pixel_height: Int,
) -> String {
  "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\""
  <> string.inspect(pixel_width)
  <> "\" height=\""
  <> string.inspect(pixel_height)
  <> "\" viewBox=\""
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
}

fn closeup_point(point: svg_path.Point) -> String {
  "  <circle cx=\""
  <> float.to_string(point.x)
  <> "\" cy=\""
  <> float.to_string(point.y)
  <> "\" r=\"0.0022\" fill=\"#111827\" />\n"
}

fn closeup_label(segment: svg_path.Segment, id: Int, color: String) -> String {
  let assert Ok(svg_path.BoundingBox(min:, max:)) =
    svg_path.segment_bounding_box(segment)
  let mx = { min.x +. max.x } /. 2.0
  let my = { min.y +. max.y } /. 2.0
  let dx = case id {
    23 -> -0.022
    24 -> 0.02
    _ -> 0.025
  }
  let dy = case id {
    23 -> -0.014
    24 -> -0.003
    _ -> 0.014
  }
  let lx = mx +. dx
  let ly = my +. dy
  "  <text x=\""
  <> float.to_string(lx)
  <> "\" y=\""
  <> float.to_string(ly)
  <> "\" fill=\""
  <> color
  <> "\" font-size=\"0.0085\" text-anchor=\"middle\">a"
  <> string.inspect(id)
  <> "</text>\n"
}

fn graph_label_text(
  segment: svg_path.Segment,
  text: String,
  color: String,
  size: Float,
) -> String {
  let assert Ok(point) = svg_path.segment_point(segment, at: 0.5)
  "  <text x=\""
  <> float.to_string(point.x)
  <> "\" y=\""
  <> float.to_string(point.y)
  <> "\" fill=\""
  <> color
  <> "\" font-size=\""
  <> float.to_string(size)
  <> "\" text-anchor=\"middle\">"
  <> text
  <> "</text>\n"
}

fn arrangement_drawing(
  source: svg_path.Subpath,
  trace: List(offset.BandArrangementTraceEdge),
) -> String {
  let edge_subpaths =
    list.map(trace, fn(item) {
      let offset.BandArrangementTraceEdge(segment:, ..) = item
      svg_path.segment_as_subpath(segment)
    })
  let geometry = svg_path.Path([source, ..edge_subpaths])
  let assert Ok(svg_path.BoundingBox(min:, max:)) =
    svg_path.path_bounding_box(geometry)
  let padding = 18.0
  let x = min.x -. padding
  let y = min.y -. padding
  let width = max.x -. min.x +. 2.0 *. padding
  let height = max.y -. min.y +. 2.0 *. padding
  let edges =
    list.fold(trace, "", fn(markup, item) {
      let offset.BandArrangementTraceEdge(id:, segment:, submerged:) = item
      let color = case submerged {
        True -> "#dc2626"
        False -> "#16a34a"
      }
      let start = svg_path.segment_start(segment)
      let end = svg_path.segment_end(segment)
      markup
      <> "  <path d=\""
      <> serialize.segment(segment)
      <> "\" fill=\"none\" stroke=\""
      <> color
      <> "\" stroke-width=\"0.8\" stroke-linecap=\"round\" />\n"
      <> graph_point(start)
      <> graph_point(end)
      <> graph_label(segment, id, color)
    })
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
  <> serialize.subpath(source)
  <> "\" fill=\"none\" stroke=\"#94a3b8\" stroke-width=\"0.6\" opacity=\"0.45\" />\n"
  <> edges
  <> "</svg>\n"
}

fn graph_point(point: svg_path.Point) -> String {
  "  <circle cx=\""
  <> float.to_string(point.x)
  <> "\" cy=\""
  <> float.to_string(point.y)
  <> "\" r=\"1.2\" fill=\"#111827\" />\n"
}

fn graph_label(segment: svg_path.Segment, id: Int, color: String) -> String {
  let assert Ok(point) = svg_path.segment_point(segment, at: 0.5)
  "  <text x=\""
  <> float.to_string(point.x)
  <> "\" y=\""
  <> float.to_string(point.y)
  <> "\" fill=\""
  <> color
  <> "\" font-size=\"3\" text-anchor=\"middle\">"
  <> string.inspect(id)
  <> "</text>\n"
}

fn drawing(source: svg_path.Subpath, band: svg_path.Path) -> String {
  let geometry = svg_path.Path([source, ..svg_path.path_subpaths(band)])
  let assert Ok(svg_path.BoundingBox(min:, max:)) =
    svg_path.path_bounding_box(geometry)
  let padding = 18.0
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
  <> "\" fill=\"#d946ef\" fill-opacity=\"0.48\" fill-rule=\"nonzero\" stroke=\"#a21caf\" stroke-width=\"0.7\" />\n"
  <> "  <path d=\""
  <> serialize.subpath(source)
  <> "\" fill=\"none\" stroke=\"#111827\" stroke-width=\"0.8\" stroke-dasharray=\"3 3\" />\n"
  <> "</svg>\n"
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
