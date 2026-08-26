//// Package-title source-subpath-6 refined-source zoom probe.

import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import svg_path
import svg_path/arrangement
import svg_path/offset
import svg_path/parse
import svg_path/svg

const input = "examples/debug/package_title.svg"

const output = "examples/debug/package_title_subpath6_segment48_zoom.svg"

const offset_distance = 1.05

const source_subpath_index = 6

const highlighted_offset_segment_index = 48

const focus_join_free_index = 10

const focus_source_segment_index = 1

const focus_refined_piece_index = 2

const focus_arrangement_edge_id = 68

pub fn main() -> Nil {
  let assert Ok(contents) = read_file(input)
  let assert Ok(full_source) = parse.path(first_path_data(contents))
  let assert Ok(source_subpath) =
    subpath_at(svg_path.path_subpaths(full_source), source_subpath_index)
  let source = svg_path.subpath_as_path(source_subpath)
  let options =
    offset.Options(
      ..offset.default_options(),
      fitting: offset.FittingOptions(tolerance: 0.01, samples: 5, max_depth: 12),
      trimming: svg_path.DistanceOptions(
        ..svg_path.default_distance_options(),
        tolerance: 0.000000001,
      ),
    )

  let assert Ok(untrimmed_first_offset) =
    offset.path_untrimmed_with(source, distance: offset_distance, options:)
  let assert Ok(trace) =
    offset.internal_offset_source_trace(
      source_subpath,
      distance: offset_distance,
      options:,
    )
  write_file(
    output,
    render(
      source,
      untrimmed_first_offset,
      trace,
      highlighted_offset_segment_index,
    ),
  )
  io.println("wrote " <> output)
  Nil
}

fn render(
  source: svg_path.Path,
  untrimmed_first_offset: svg_path.Path,
  trace: List(offset.OffsetSourceTracePortion),
  highlighted_offset_segment_index: Int,
) -> String {
  let assert Ok(first_untrimmed_subpath) =
    subpath_at(svg_path.path_subpaths(untrimmed_first_offset), 0)
  let assert Ok(highlighted_offset_segment) =
    segment_at(
      svg_path.subpath_segments(first_untrimmed_subpath),
      highlighted_offset_segment_index,
    )
  let assert Ok(build) =
    arrangement.build(
      [untrimmed_first_offset, source],
      tolerance: 0.000000002,
      minimum_chord: 0.000000002,
    )
  let arrangement.ArrangementGraphBuild(graph:, segment_images:) = build
  let arrangement.ArrangementGraph(edges: arrangement_edges, ..) = graph
  let assert Ok(preimage_box) = case
    trace_refined_source_piece(
      trace,
      join_free_index: focus_join_free_index,
      source_index: focus_source_segment_index,
      refined_index: focus_refined_piece_index,
    )
  {
    Ok(offset.OffsetSourceTraceDRefined(segment:, ..)) ->
      svg_path.segment_bounding_box(segment)
    _ -> Error(svg_path.SplitOutsideSegment)
  }
  let assert Ok(focus_edge) =
    edge_with_id(arrangement_edges, focus_arrangement_edge_id)
  let arrangement.ArrangementEdge(segment: focus_edge_segment, ..) = focus_edge
  let assert Ok(edge_box) = svg_path.segment_bounding_box(focus_edge_segment)
  let focus_box = combine_boxes(edge_box, preimage_box) |> pad_box(margin: 0.2)
  let assert Ok(source_box) = svg_path.path_bounding_box(source)
  let assert Ok(offset_box) = svg_path.path_bounding_box(untrimmed_first_offset)
  let full_box = combine_boxes(source_box, offset_box)
  let view_box =
    zoom_from_full_box(
      full_box,
      around: svg_path.bounding_box_center(focus_box),
      zoom: 25.0,
    )
    |> combine_boxes(focus_box)

  let visible_portions = trace |> trace_portions_intersecting_box(view_box)
  let visible_pieces =
    visible_portions
    |> list.flat_map(fn(portion) {
      let offset.OffsetSourceTracePortion(index:, pieces:, ..) = portion
      indexed_trace_pieces(pieces, 0)
      |> list.map(fn(entry) {
        let #(piece_index, piece) = entry
        #(index, piece_index, piece)
      })
    })
    |> trace_pieces_intersecting_box(view_box)
  let graph_edges =
    first_path_edges(graph, segment_images)
    |> edges_intersecting_box(view_box)

  let things = [
    background(full_box),
    svg.StyledPath(
      source,
      "fill: none; stroke: #9ca3af; stroke-width: 0.00035; opacity: 0.35",
    ),
    svg.StyledPath(
      untrimmed_first_offset,
      "fill: none; stroke: #2563eb; stroke-width: 0.00025; stroke-linecap: round; stroke-linejoin: round; opacity: 0.75",
    ),
  ]
  let things =
    list.append(things, trace_piece_overlays(visible_pieces, view_box))
  let things =
    list.append(things, [
      svg.StyledPath(
        svg_path.segment_as_path(highlighted_offset_segment),
        "fill: none; stroke: #7c3aed; stroke-width: 0.003; stroke-linecap: round; stroke-linejoin: round; opacity: 0.95",
      ),
      ..list.append(
        graph_edge_paths(graph_edges),
        list.append(graph_edge_labels(graph_edges), graph_vertices(graph_edges)),
      )
    ])

  svg.document(things:, view_box:)
  |> with_root_size(width: 900, height: 650)
}

fn trace_refined_source_piece(
  portions: List(offset.OffsetSourceTracePortion),
  join_free_index join_free_index: Int,
  source_index source_index: Int,
  refined_index refined_index: Int,
) -> Result(offset.OffsetSourceTracePiece, Nil) {
  case portions {
    [] -> Error(Nil)
    [first, ..rest] -> {
      let offset.OffsetSourceTracePortion(index:, pieces:, ..) = first
      case index == join_free_index {
        True -> find_refined_source_piece(pieces, source_index, refined_index)
        False ->
          trace_refined_source_piece(
            rest,
            join_free_index:,
            source_index:,
            refined_index:,
          )
      }
    }
  }
}

fn find_refined_source_piece(
  pieces: List(offset.OffsetSourceTracePiece),
  source_index: Int,
  refined_index: Int,
) -> Result(offset.OffsetSourceTracePiece, Nil) {
  case pieces {
    [] -> Error(Nil)
    [first, ..rest] ->
      case first {
        offset.OffsetSourceTraceDRefined(
          source_segment_index:,
          refined_piece_index:,
          ..,
        )
          if source_segment_index == source_index
          && refined_piece_index == refined_index
        -> Ok(first)
        _ -> find_refined_source_piece(rest, source_index, refined_index)
      }
  }
}

fn trace_portions_intersecting_box(
  portions: List(offset.OffsetSourceTracePortion),
  box: svg_path.BoundingBox,
) -> List(offset.OffsetSourceTracePortion) {
  portions
  |> list.filter(fn(portion) {
    let offset.OffsetSourceTracePortion(subpath:, ..) = portion
    case svg_path.subpath_bounding_box(subpath) {
      Error(_) -> False
      Ok(subpath_box) -> boxes_intersect(subpath_box, box)
    }
  })
}

fn indexed_trace_pieces(
  pieces: List(offset.OffsetSourceTracePiece),
  index: Int,
) -> List(#(Int, offset.OffsetSourceTracePiece)) {
  case pieces {
    [] -> []
    [first, ..rest] -> [
      #(index, first),
      ..indexed_trace_pieces(rest, index + 1)
    ]
  }
}

fn trace_pieces_intersecting_box(
  pieces: List(#(Int, Int, offset.OffsetSourceTracePiece)),
  box: svg_path.BoundingBox,
) -> List(#(Int, Int, offset.OffsetSourceTracePiece)) {
  pieces
  |> list.filter(fn(entry) {
    let #(_, _, piece) = entry
    case trace_piece_segment(piece) |> svg_path.segment_bounding_box {
      Error(_) -> False
      Ok(segment_box) -> boxes_intersect(segment_box, box)
    }
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

fn trace_piece_overlays(
  pieces: List(#(Int, Int, offset.OffsetSourceTracePiece)),
  view_box: svg_path.BoundingBox,
) -> svg.ThingsToDraw {
  pieces
  |> list.flat_map(fn(entry) {
    let #(portion_index, piece_index, piece) = entry
    let segment = trace_piece_segment(piece)
    let start = svg_path.segment_start(segment)
    let end = svg_path.segment_end(segment)
    let label_point = case svg_path.segment_bounding_box(segment) {
      Ok(box) -> svg_path.bounding_box_center(box)
      Error(_) ->
        svg_path.Point(
          start.x +. { end.x -. start.x } /. 2.0,
          start.y +. { end.y -. start.y } /. 2.0,
        )
    }
    let label_point = clamp_point_to_box(label_point, view_box, margin: 0.02)
    let #(label, color) = case piece {
      offset.OffsetSourceTraceDRefined(refined_piece_index:, ..) -> #(
        "J" <> int.to_string(portion_index) <> "." <> int.to_string(piece_index),
        case refined_piece_index % 2 == 0 {
          True -> "#16a34a"
          False -> "#ca8a04"
        },
      )
      offset.OffsetSourceTraceStalled(..) -> #(
        "J" <> int.to_string(portion_index) <> "." <> int.to_string(piece_index),
        "#dc2626",
      )
    }
    [
      svg.StyledPath(
        svg_path.segment_as_path(segment),
        "fill: none; stroke: "
          <> color
          <> "; stroke-width: 0.00225; stroke-linecap: round; stroke-linejoin: round; opacity: 0.9",
      ),
      svg.Circle(
        start,
        0.0015,
        "fill: #ffffff; stroke: " <> color <> "; stroke-width: 0.0008",
      ),
      svg.Circle(
        end,
        0.0015,
        "fill: " <> color <> "; stroke: #ffffff; stroke-width: 0.0008",
      ),
      svg.Text(
        label,
        "fill: "
          <> color
          <> "; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; text-anchor: middle; dominant-baseline: central",
        label_point,
        0.0065,
      ),
    ]
  })
}

fn first_path_edges(
  graph: arrangement.ArrangementGraph,
  images: List(arrangement.ArrangementSegmentImage),
) -> List(arrangement.ArrangementEdge) {
  let arrangement.ArrangementGraph(edges:, ..) = graph
  images
  |> list.filter(fn(image) {
    let arrangement.ArrangementSegmentImage(path_index:, ..) = image
    path_index == 0
  })
  |> list.flat_map(fn(image) {
    let arrangement.ArrangementSegmentImage(edges: refs, ..) = image
    refs
  })
  |> unique_edge_ids([])
  |> list.filter_map(fn(id) { edge_with_id(edges, id) })
}

fn unique_edge_ids(
  refs: List(arrangement.DirectedEdgeReference),
  seen: List(Int),
) -> List(Int) {
  case refs {
    [] -> list.reverse(seen)
    [first, ..rest] -> {
      let arrangement.DirectedEdgeReference(edge_id:, ..) = first
      case int_in_list(edge_id, seen) {
        True -> unique_edge_ids(rest, seen)
        False -> unique_edge_ids(rest, [edge_id, ..seen])
      }
    }
  }
}

fn edge_with_id(
  edges: List(arrangement.ArrangementEdge),
  id: Int,
) -> Result(arrangement.ArrangementEdge, Nil) {
  case edges {
    [] -> Error(Nil)
    [first, ..rest] -> {
      let arrangement.ArrangementEdge(id: edge_id, ..) = first
      case edge_id == id {
        True -> Ok(first)
        False -> edge_with_id(rest, id)
      }
    }
  }
}

fn int_in_list(needle: Int, values: List(Int)) -> Bool {
  case values {
    [] -> False
    [first, ..rest] ->
      case first == needle {
        True -> True
        False -> int_in_list(needle, rest)
      }
  }
}

fn segment_at(
  segments: List(svg_path.Segment),
  index: Int,
) -> Result(svg_path.Segment, Nil) {
  case segments, index {
    [], _ -> Error(Nil)
    [first, ..], 0 -> Ok(first)
    [_, ..rest], _ -> segment_at(rest, index - 1)
  }
}

fn edges_intersecting_box(
  edges: List(arrangement.ArrangementEdge),
  box: svg_path.BoundingBox,
) -> List(arrangement.ArrangementEdge) {
  edges
  |> list.filter(fn(edge) {
    let arrangement.ArrangementEdge(bounds:, ..) = edge
    boxes_intersect(bounds, box)
  })
}

fn graph_edge_paths(
  edges: List(arrangement.ArrangementEdge),
) -> svg.ThingsToDraw {
  edges
  |> list.map(fn(edge) {
    let arrangement.ArrangementEdge(segment:, ..) = edge
    svg.StyledPath(
      svg_path.segment_as_path(segment),
      "fill: none; stroke: #ef4444; stroke-width: 0.0006; stroke-linecap: round; stroke-linejoin: round; opacity: 0.62",
    )
  })
}

fn graph_edge_labels(
  edges: List(arrangement.ArrangementEdge),
) -> svg.ThingsToDraw {
  edges
  |> list.filter_map(fn(edge) {
    let arrangement.ArrangementEdge(id:, segment:, ..) = edge
    use box <- result.try(svg_path.segment_bounding_box(segment))
    Ok(svg.Text(
      "A" <> int.to_string(id),
      "fill: #1e3a8a; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; text-anchor: middle; dominant-baseline: central",
      svg_path.bounding_box_center(box),
      0.009,
    ))
  })
}

fn graph_vertices(
  edges: List(arrangement.ArrangementEdge),
) -> svg.ThingsToDraw {
  edges
  |> list.flat_map(fn(edge) {
    let arrangement.ArrangementEdge(segment:, ..) = edge
    [
      svg.Circle(
        svg_path.segment_start(segment),
        0.0011,
        "fill: #111827; stroke: none; opacity: 0.9",
      ),
      svg.Circle(
        svg_path.segment_end(segment),
        0.0011,
        "fill: #111827; stroke: none; opacity: 0.9",
      ),
    ]
  })
}

fn boxes_intersect(
  left: svg_path.BoundingBox,
  right: svg_path.BoundingBox,
) -> Bool {
  left.min.x <=. right.max.x
  && left.max.x >=. right.min.x
  && left.min.y <=. right.max.y
  && left.max.y >=. right.min.y
}

fn background(view_box: svg_path.BoundingBox) -> svg.ThingToDraw {
  svg.Rectangle(
    view_box.min,
    svg_path.bounding_box_width(view_box),
    svg_path.bounding_box_height(view_box),
    "fill: #ffffff; stroke: none",
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

fn pad_box(
  box: svg_path.BoundingBox,
  margin margin: Float,
) -> svg_path.BoundingBox {
  svg_path.BoundingBox(
    min: svg_path.Point(box.min.x -. margin, box.min.y -. margin),
    max: svg_path.Point(box.max.x +. margin, box.max.y +. margin),
  )
}

fn clamp_point_to_box(
  point: svg_path.Point,
  box: svg_path.BoundingBox,
  margin margin: Float,
) -> svg_path.Point {
  svg_path.Point(
    float.max(box.min.x +. margin, float.min(point.x, box.max.x -. margin)),
    float.max(box.min.y +. margin, float.min(point.y, box.max.y -. margin)),
  )
}

fn zoom_from_full_box(
  full_box: svg_path.BoundingBox,
  around center: svg_path.Point,
  zoom zoom: Float,
) -> svg_path.BoundingBox {
  let width = svg_path.bounding_box_width(full_box) /. zoom
  let height = svg_path.bounding_box_height(full_box) /. zoom

  svg_path.BoundingBox(
    min: svg_path.Point(center.x -. width /. 2.0, center.y -. height /. 2.0),
    max: svg_path.Point(center.x +. width /. 2.0, center.y +. height /. 2.0),
  )
}

fn subpath_at(
  subpaths: List(svg_path.Subpath),
  index: Int,
) -> Result(svg_path.Subpath, Nil) {
  case subpaths, index {
    [], _ -> Error(Nil)
    [first, ..], 0 -> Ok(first)
    [_, ..rest], _ -> subpath_at(rest, index - 1)
  }
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

fn first_path_data(contents: String) -> String {
  let assert [_, after_attribute] = string.split(contents, on: " d=\"")
  let assert [data, ..] = string.split(after_attribute, on: "\"")
  data
}

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(String, Dynamic)

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
