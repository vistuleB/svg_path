//// Refined source and joined untrimmed offset diagnostic for the S
//// package-title outline.

import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import svg_path
import svg_path/curvature
import svg_path/offset
import svg_path/parse
import svg_path/svg

const input = "examples/debug/package_title.svg"

const output = "examples/debug/offset_s_joined_untrimmed.svg"

const offset_distance = 1.0

pub fn main() -> Nil {
  let assert Ok(contents) = read_file(input)
  let assert Ok(full) = parse.path(first_path_data(contents))
  let assert [s, ..] = svg_path.path_subpaths(full)
  let source = svg_path.Path([s])
  let options =
    offset.Options(
      ..offset.default_options(),
      fitting: offset.FittingOptions(tolerance: 0.01, samples: 5, max_depth: 12),
      trimming: svg_path.DistanceOptions(
        ..svg_path.default_distance_options(),
        tolerance: 0.000000001,
      ),
    )
  let assert Ok(source_trace) =
    offset.internal_offset_source_trace(s, distance: offset_distance, options:)
  let assert Ok(joined) =
    offset.subpath_untrimmed_with(s, distance: offset_distance, options:)
  io.println(
    "joined untrimmed segments: "
    <> int.to_string(list.length(svg_path.subpath_segments(joined))),
  )
  io.println(
    "joined untrimmed closed: "
    <> bool_string(svg_path.subpath_is_closed(joined)),
  )
  let offset_path = svg_path.Path([joined])
  let assert Ok(source_box) = svg_path.path_bounding_box(source)
  let assert Ok(offset_box) = svg_path.path_bounding_box(offset_path)
  let view_box = padded_box([source_box, offset_box], margin: 4.0)
  write_file(
    output,
    render(source, source_trace_pieces(source_trace), joined, view_box),
  )
}

fn bool_string(value: Bool) -> String {
  case value {
    True -> "True"
    False -> "False"
  }
}

fn render(
  source: svg_path.Path,
  source_pieces: List(offset.OffsetSourceTracePiece),
  joined: svg_path.Subpath,
  view_box: svg_path.BoundingBox,
) -> String {
  svg.document(
    things: [
      background(view_box),
      svg.StyledPath(
        source,
        "fill: none; stroke: #e5e7eb; stroke-width: 0.04; stroke-linecap: round; stroke-linejoin: round",
      ),
      ..list.append(
        refined_source_piece_paths(source_pieces),
        list.append(boundary_dots(source_pieces), [joined_offset_path(joined)]),
      )
    ],
    view_box:,
  )
  |> with_root_size(width: 3600, height: 3600)
}

fn source_trace_pieces(
  portions: List(offset.OffsetSourceTracePortion),
) -> List(offset.OffsetSourceTracePiece) {
  portions
  |> list.flat_map(fn(portion) {
    let offset.OffsetSourceTracePortion(pieces:, ..) = portion
    pieces
  })
}

fn refined_source_piece_paths(
  pieces: List(offset.OffsetSourceTracePiece),
) -> List(svg.ThingToDraw) {
  pieces
  |> list.map(fn(piece) {
    let segment = trace_piece_segment(piece)
    let style = case piece {
      offset.OffsetSourceTraceDRefined(..) ->
        "fill: none; stroke: "
        <> residual_sign_color(segment)
        <> "; stroke-width: 0.0267; stroke-linecap: round; stroke-linejoin: round"
      offset.OffsetSourceTraceStalled(..) ->
        "fill: none; stroke: #f97316; stroke-width: 0.0367; stroke-linecap: round; stroke-linejoin: round"
    }
    svg.StyledPath(svg_path.Path([svg_path.subpath_assert([segment])]), style)
  })
}

fn trace_piece_segment(
  piece: offset.OffsetSourceTracePiece,
) -> svg_path.Segment {
  case piece {
    offset.OffsetSourceTraceDRefined(segment:, ..) -> segment
    offset.OffsetSourceTraceStalled(segment:, ..) -> segment
  }
}

fn residual_sign_color(segment: svg_path.Segment) -> String {
  case
    curvature.segment_right_normal_cusp_residual(
      segment,
      distance: offset_distance,
      at: 0.5,
    )
  {
    Ok(value) ->
      case value <. 0.0 {
        True -> "#2563eb"
        False -> "#16a34a"
      }
    Error(_) -> "#6b7280"
  }
}

fn boundary_dots(
  pieces: List(offset.OffsetSourceTracePiece),
) -> List(svg.ThingToDraw) {
  pieces
  |> list.flat_map(fn(piece) {
    let segment = trace_piece_segment(piece)
    let start = svg_path.segment_start(segment)
    let end = svg_path.segment_end(segment)
    let #(start_is_reversal, end_is_reversal) = trace_piece_reversals(piece)
    [
      svg.Circle(start, 0.025, dot_style(start_is_reversal)),
      svg.Circle(end, 0.025, dot_style(end_is_reversal)),
    ]
  })
}

fn trace_piece_reversals(piece: offset.OffsetSourceTracePiece) -> #(Bool, Bool) {
  case piece {
    offset.OffsetSourceTraceDRefined(start_is_reversal:, end_is_reversal:, ..) -> #(
      start_is_reversal,
      end_is_reversal,
    )
    offset.OffsetSourceTraceStalled(..) -> #(False, False)
  }
}

fn dot_style(is_reversal: Bool) -> String {
  case is_reversal {
    True -> "fill: #dc2626; stroke: #ffffff; stroke-width: 0.006"
    False -> "fill: #2563eb; stroke: #ffffff; stroke-width: 0.006"
  }
}

fn joined_offset_path(joined: svg_path.Subpath) -> svg.ThingToDraw {
  svg.StyledPath(
    svg_path.Path([joined]),
    "fill: none; stroke: #111827; stroke-width: 0.002; stroke-linecap: round; stroke-linejoin: round",
  )
}

fn background(view_box: svg_path.BoundingBox) -> svg.ThingToDraw {
  svg.Rectangle(
    view_box.min,
    svg_path.bounding_box_width(view_box),
    svg_path.bounding_box_height(view_box),
    "fill: #ffffff; stroke: none",
  )
}

fn padded_box(
  boxes: List(svg_path.BoundingBox),
  margin margin: Float,
) -> svg_path.BoundingBox {
  let assert [first, ..] = boxes
  let combined = list.fold(boxes, first, combine_boxes)
  let svg_path.BoundingBox(min:, max:) = combined
  svg_path.BoundingBox(
    min: svg_path.Point(min.x -. margin, min.y -. margin),
    max: svg_path.Point(max.x +. margin, max.y +. margin),
  )
}

fn combine_boxes(
  left: svg_path.BoundingBox,
  right: svg_path.BoundingBox,
) -> svg_path.BoundingBox {
  svg_path.BoundingBox(
    min: svg_path.Point(
      float.min(left.min.x, right.min.x),
      float.min(left.min.y, right.min.y),
    ),
    max: svg_path.Point(
      float.max(left.max.x, right.max.x),
      float.max(left.max.y, right.max.y),
    ),
  )
}

fn with_root_size(
  svg_document: String,
  width width: Int,
  height height: Int,
) -> String {
  let assert Ok(#(before_width, after_width)) =
    string.split_once(svg_document, on: "\" width=\"")
  let assert Ok(#(_, after_height)) =
    string.split_once(after_width, on: "\" height=\"")
  let assert Ok(#(_, rest)) = string.split_once(after_height, on: "\">")
  before_width
  <> "\" width=\""
  <> int.to_string(width)
  <> "\" height=\""
  <> int.to_string(height)
  <> "\">"
  <> rest
}

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(String, Dynamic)

@external(erlang, "offset_sv_probe_ffi", "write_file")
fn write_file(path: String, contents: String) -> Nil

fn first_path_data(contents: String) -> String {
  let assert [_, after_attribute] = string.split(contents, on: " d=\"")
  let assert [data, ..] = string.split(after_attribute, on: "\"")
  data
}
