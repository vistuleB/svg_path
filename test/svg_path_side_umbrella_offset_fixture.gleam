import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import svg_path
import svg_path/offset
import svg_path/serialize
import svg_path/transform

const output = "examples/debug/side_umbrella_round_offset_plus_0_2_trimming.svg"

const double_output = "examples/debug/double_side_umbrella_round_offset_plus_0_2_trimming.svg"

pub fn main() -> Nil {
  let source = side_umbrella()
  let cusp = offset_path(source, offset.CuspTrimming)
  let in_band = offset_path(source, offset.InBandTrimming)
  let none = offset_path(source, offset.NoTrimming)
  let _ = write_file(output, drawing(source, cusp, in_band, none))
  let double = double_side_umbrella(source)
  let assert Ok(double) = transform.rotate_subpath(double, degrees: -90.0)
  let double_cusp = offset_path(double, offset.CuspTrimming)
  let double_in_band = offset_path(double, offset.InBandTrimming)
  let double_none = offset_path(double, offset.NoTrimming)
  let _ =
    write_file(
      double_output,
      double_drawing(double, double_cusp, double_in_band, double_none),
    )
  Nil
}

fn offset_path(
  source: svg_path.Subpath,
  final_trimming: offset.SingleOffsetFinalTrimming,
) -> Result(svg_path.Path, offset.Error) {
  let options =
    offset.Options(
      ..offset.default_options(),
      join: offset.Round,
      single_offset_trimming: offset.SingleOffsetTrimming(
        offside: False,
        final_trimming:,
      ),
    )
  offset.subpath_with(source, offset: 0.2, options:)
}

fn side_umbrella() -> svg_path.Subpath {
  let p1 = svg_path.Point(0.0, -1.0)
  let p2 = svg_path.Point(0.8660254037844386, -0.5)
  let p3 = svg_path.Point(0.8660254037844386, 0.5)
  let p4 = svg_path.Point(0.0, 1.0)
  let p5 = svg_path.Point(-0.8660254037844386, 0.5)
  let p6 = svg_path.Point(-0.8660254037844386, -0.5)
  svg_path.subpath_assert([
    svg_path.Line(p1, p6),
    svg_path.Line(p6, p3),
    svg_path.Line(p3, p2),
    svg_path.Line(p2, p5),
    svg_path.Line(p5, p4),
  ])
}

fn double_side_umbrella(source: svg_path.Subpath) -> svg_path.Subpath {
  let translated =
    source
    |> svg_path.subpath_segments
    |> list.map(fn(segment) {
      transform.translate_segment(segment, x: 0.0, y: 2.0)
    })
    |> result.all
  let assert Ok(translated) = translated
  svg_path.subpath_assert(list.append(
    svg_path.subpath_segments(source),
    translated,
  ))
}

fn drawing(
  source: svg_path.Subpath,
  cusp: Result(svg_path.Path, offset.Error),
  in_band: Result(svg_path.Path, offset.Error),
  none: Result(svg_path.Path, offset.Error),
) -> String {
  let view_box =
    svg_path.BoundingBox(
      min: svg_path.Point(0.0, 0.0),
      max: svg_path.Point(9.0, 3.2),
    )
  document_start(view_box)
  <> background(view_box)
  <> panel(
    source,
    cusp,
    "Cusp trimming",
    center_x: 1.5,
    center_y: 1.72,
    status_y: 3.02,
    annotate: True,
    scale: 1.0,
  )
  <> panel(
    source,
    in_band,
    "In-band trimming",
    center_x: 4.5,
    center_y: 1.72,
    status_y: 3.02,
    annotate: True,
    scale: 1.0,
  )
  <> panel(
    source,
    none,
    "No final trimming",
    center_x: 7.5,
    center_y: 1.72,
    status_y: 3.02,
    annotate: True,
    scale: 1.0,
  )
  <> "</svg>\n"
}

fn double_drawing(
  source: svg_path.Subpath,
  cusp: Result(svg_path.Path, offset.Error),
  in_band: Result(svg_path.Path, offset.Error),
  none: Result(svg_path.Path, offset.Error),
) -> String {
  let view_box =
    svg_path.BoundingBox(
      min: svg_path.Point(0.0, 0.0),
      max: svg_path.Point(10.5, 3.2),
    )
  document_start(view_box)
  <> background(view_box)
  <> panel(
    source,
    none,
    "No final trimming",
    center_x: 1.75,
    center_y: 1.72,
    status_y: 3.02,
    annotate: False,
    scale: 0.75,
  )
  <> panel(
    source,
    cusp,
    "Cusp trimming",
    center_x: 5.25,
    center_y: 1.72,
    status_y: 3.02,
    annotate: False,
    scale: 0.75,
  )
  <> panel(
    source,
    in_band,
    "In-band trimming",
    center_x: 8.75,
    center_y: 1.72,
    status_y: 3.02,
    annotate: False,
    scale: 0.75,
  )
  <> "</svg>\n"
}

fn panel(
  source: svg_path.Subpath,
  result: Result(svg_path.Path, offset.Error),
  label: String,
  center_x center_x: Float,
  center_y center_y: Float,
  status_y status_y: Float,
  annotate annotate: Bool,
  scale scale: Float,
) -> String {
  let source_path = svg_path.Path([source])
  let #(offset_path, status) = case result {
    Ok(path) -> #(path, "")
    Error(_) -> #(svg_path.path_empty(), "Error: ForcedParityInfeasible(14)")
  }
  let geometry = svg_path.Path([source, ..svg_path.path_subpaths(offset_path)])
  let assert Ok(svg_path.BoundingBox(min:, max:)) =
    svg_path.path_bounding_box(geometry)
  let geometry_center_x = { min.x +. max.x } /. 2.0
  let geometry_center_y = { min.y +. max.y } /. 2.0
  "  <g transform=\"translate("
  <> float.to_string(center_x)
  <> " "
  <> float.to_string(center_y)
  <> ") scale("
  <> float.to_string(scale)
  <> ") translate("
  <> float.to_string(0.0 -. geometry_center_x)
  <> " "
  <> float.to_string(0.0 -. geometry_center_y)
  <> ")\">\n"
  <> "    <path d=\""
  <> serialize.path(source_path)
  <> "\" fill=\"none\" stroke=\"#94a3b8\" stroke-width=\"0.025\" stroke-linejoin=\"round\" />\n"
  <> "    <path d=\""
  <> serialize.path(offset_path)
  <> "\" fill=\"none\" stroke=\"#2563eb\" stroke-width=\"0.0175\" stroke-linecap=\"round\" stroke-linejoin=\"round\" />\n"
  <> case annotate {
    True -> source_vertices(source)
    False -> source_nodes(source)
  }
  <> "  </g>\n"
  <> "  <text x=\""
  <> float.to_string(center_x)
  <> "\" y=\"0.28\" font-family=\"sans-serif\" font-size=\"0.16\" font-weight=\"600\" fill=\"#111827\" text-anchor=\"middle\">"
  <> label
  <> "</text>\n"
  <> "  <text x=\""
  <> float.to_string(center_x)
  <> "\" y=\""
  <> float.to_string(status_y)
  <> "\" font-family=\"sans-serif\" font-size=\"0.13\" fill=\"#b91c1c\" text-anchor=\"middle\">"
  <> status
  <> "</text>\n"
}

fn source_nodes(source: svg_path.Subpath) -> String {
  let starts =
    source
    |> svg_path.subpath_segments
    |> list.fold("", fn(markup, segment) {
      node(svg_path.segment_start(segment), markup)
    })
  let assert Ok(end) = svg_path.subpath_end(source)
  node(end, starts)
}

fn node(point: svg_path.Point, markup: String) -> String {
  markup
  <> "  <circle cx=\""
  <> float.to_string(point.x)
  <> "\" cy=\""
  <> float.to_string(point.y)
  <> "\" r=\"0.028\" fill=\"#111827\" />\n"
}

fn source_vertices(source: svg_path.Subpath) -> String {
  let segments = svg_path.subpath_segments(source)
  let starts =
    segments
    |> list.index_fold("", fn(markup, segment, index) {
      vertex(svg_path.segment_start(segment), vertex_label(index), markup)
    })
  let assert Ok(end) = svg_path.subpath_end(source)
  vertex(end, 4, starts)
}

fn vertex(point: svg_path.Point, label: Int, markup: String) -> String {
  markup
  <> "  <circle cx=\""
  <> float.to_string(point.x)
  <> "\" cy=\""
  <> float.to_string(point.y)
  <> "\" r=\"0.028\" fill=\"#111827\" />\n"
  <> "  <text x=\""
  <> float.to_string(point.x)
  <> "\" y=\""
  <> float.to_string(point.y -. 0.085)
  <> "\" font-family=\"sans-serif\" font-size=\"0.11\" fill=\"#1e3a8a\" stroke=\"white\" stroke-width=\"0.025\" paint-order=\"stroke fill\" text-anchor=\"middle\">"
  <> int.to_string(label)
  <> "</text>\n"
}

fn vertex_label(index: Int) -> Int {
  case index {
    0 -> 1
    1 -> 6
    2 -> 3
    3 -> 2
    4 -> 5
    _ -> 0
  }
}

fn document_start(view_box: svg_path.BoundingBox) -> String {
  let svg_path.BoundingBox(min:, max:) = view_box
  "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1500\" height=\"540\" viewBox=\""
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
