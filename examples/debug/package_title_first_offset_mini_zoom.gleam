//// Package-title mini first-offset zoom probe.

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

const output = "examples/debug/package_title_first_offset_mini_zoom.svg"

const offset_distance = 1.05

const highlighted_edge_id = 408

pub fn main() -> Nil {
  let assert Ok(contents) = read_file(input)
  let assert Ok(source) = parse.path(first_path_data(contents))
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
  io.println(
    "untrimmed first offset subpaths: "
    <> int.to_string(
      list.length(svg_path.path_subpaths(untrimmed_first_offset)),
    ),
  )
  let assert Ok(trimmed_first_offset) =
    offset.path_with(source, distance: offset_distance, options:)

  write_file(
    output,
    render(source, untrimmed_first_offset, trimmed_first_offset),
  )
  Nil
}

fn render(
  source: svg_path.Path,
  untrimmed_first_offset: svg_path.Path,
  trimmed_first_offset: svg_path.Path,
) -> String {
  let assert Ok(mini) =
    subpath_at(svg_path.path_subpaths(trimmed_first_offset), 4)
  let assert Ok(mini_box) = svg_path.subpath_bounding_box(mini)
  let assert Ok(source_box) = svg_path.path_bounding_box(source)
  let assert Ok(untrimmed_box) =
    svg_path.path_bounding_box(untrimmed_first_offset)
  let full_box = combine_boxes(source_box, untrimmed_box)
  let view_box =
    zoom_from_full_box(
      full_box,
      around: svg_path.bounding_box_center(mini_box),
      zoom: 25.0,
    )
  let assert Ok(build) =
    arrangement.build(
      [untrimmed_first_offset, source],
      tolerance: 0.000000002,
      minimum_chord: 0.000000002,
    )
  let arrangement.ArrangementGraphBuild(graph:, segment_images:) = build
  report_edge_source(segment_images, highlighted_edge_id)
  let graph_edges =
    first_path_edges(graph, segment_images)
    |> edges_intersecting_box(view_box)
  let highlighted_source =
    highlighted_source_segment(
      untrimmed_first_offset,
      segment_images,
      highlighted_edge_id,
    )
  let things = [
    background(full_box),
    svg.StyledPath(source, "fill: #d1d5db; stroke: none; opacity: 0.55"),
    svg.StyledPath(
      untrimmed_first_offset,
      "fill: none; stroke: #2563eb; stroke-width: 0.0005; stroke-linecap: round; stroke-linejoin: round",
    ),
    ..highlighted_source_segment_path(highlighted_source)
  ]
  let things =
    list.append(things, [
      svg.Text(
        "25x zoom: source + untrimmed first offset + arrangement edge ids",
        "fill: #111827; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace",
        svg_path.Point(
          view_box.min.x +. svg_path.bounding_box_width(view_box) *. 0.02,
          view_box.min.y +. svg_path.bounding_box_height(view_box) *. 0.08,
        ),
        svg_path.bounding_box_height(view_box) *. 0.035,
      ),
      ..list.append(
        graph_edge_paths(graph_edges),
        list.append(graph_edge_labels(graph_edges), graph_vertices(graph_edges)),
      )
    ])

  svg.document(things:, view_box:)
  |> with_root_size(width: 900, height: 650)
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

fn report_edge_source(
  images: List(arrangement.ArrangementSegmentImage),
  edge_id: Int,
) -> Nil {
  case image_containing_edge(images, edge_id) {
    Error(_) ->
      io.println("edge " <> int.to_string(edge_id) <> " source: not found")
    Ok(image) -> {
      let arrangement.ArrangementSegmentImage(
        path_index:,
        subpath_index:,
        segment_index:,
        ..,
      ) = image
      io.println(
        "edge "
        <> int.to_string(edge_id)
        <> " source path="
        <> int.to_string(path_index)
        <> " subpath="
        <> int.to_string(subpath_index)
        <> " segment="
        <> int.to_string(segment_index),
      )
    }
  }
}

fn highlighted_source_segment(
  path: svg_path.Path,
  images: List(arrangement.ArrangementSegmentImage),
  edge_id: Int,
) -> Result(svg_path.Segment, Nil) {
  use image <- result.try(image_containing_edge(images, edge_id))
  let arrangement.ArrangementSegmentImage(
    path_index:,
    subpath_index:,
    segment_index:,
    ..,
  ) = image
  case path_index {
    0 -> {
      use subpath <- result.try(subpath_at(
        svg_path.path_subpaths(path),
        subpath_index,
      ))
      segment_at(svg_path.subpath_segments(subpath), segment_index)
    }
    _ -> Error(Nil)
  }
}

fn image_containing_edge(
  images: List(arrangement.ArrangementSegmentImage),
  edge_id: Int,
) -> Result(arrangement.ArrangementSegmentImage, Nil) {
  case images {
    [] -> Error(Nil)
    [first, ..rest] -> {
      let arrangement.ArrangementSegmentImage(edges:, ..) = first
      case references_contain_edge(edges, edge_id) {
        True -> Ok(first)
        False -> image_containing_edge(rest, edge_id)
      }
    }
  }
}

fn references_contain_edge(
  refs: List(arrangement.DirectedEdgeReference),
  edge_id: Int,
) -> Bool {
  case refs {
    [] -> False
    [first, ..rest] -> {
      let arrangement.DirectedEdgeReference(edge_id: id, ..) = first
      case id == edge_id {
        True -> True
        False -> references_contain_edge(rest, edge_id)
      }
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

fn highlighted_source_segment_path(
  segment: Result(svg_path.Segment, Nil),
) -> svg.ThingsToDraw {
  case segment {
    Error(_) -> []
    Ok(segment) -> [
      svg.StyledPath(
        svg_path.segment_as_path(segment),
        "fill: none; stroke: #7c3aed; stroke-width: 0.006; stroke-linecap: round; stroke-linejoin: round; opacity: 0.95",
      ),
    ]
  }
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

fn boxes_intersect(
  left: svg_path.BoundingBox,
  right: svg_path.BoundingBox,
) -> Bool {
  left.min.x <=. right.max.x
  && left.max.x >=. right.min.x
  && left.min.y <=. right.max.y
  && left.max.y >=. right.min.y
}

fn graph_edge_paths(
  edges: List(arrangement.ArrangementEdge),
) -> svg.ThingsToDraw {
  edges
  |> list.map(fn(edge) {
    let arrangement.ArrangementEdge(segment:, ..) = edge
    svg.StyledPath(
      svg_path.segment_as_path(segment),
      "fill: none; stroke: #ef4444; stroke-width: 0.0012; stroke-linecap: round; stroke-linejoin: round; opacity: 0.75",
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
    let center = svg_path.bounding_box_center(box)
    Ok(svg.Text(
      int.to_string(id),
      "fill: #1e3a8a; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; text-anchor: middle; dominant-baseline: central",
      center,
      0.018,
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
        0.0022,
        "fill: #111827; stroke: none; opacity: 0.9",
      ),
      svg.Circle(
        svg_path.segment_end(segment),
        0.0022,
        "fill: #111827; stroke: none; opacity: 0.9",
      ),
    ]
  })
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
