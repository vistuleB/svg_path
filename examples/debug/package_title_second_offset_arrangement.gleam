//// Second-offset arrangement graph probe for package_title.svg.

import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import svg_path
import svg_path/arrangement
import svg_path/offset
import svg_path/parse
import svg_path/point
import svg_path/svg

const input = "examples/debug/package_title.svg"

const output = "examples/debug/package_title_second_offset_arrangement.svg"

const zoom_output = "examples/debug/package_title_second_offset_arrangement_zoom.svg"

const offset_distance = 1.05

const side_sampling_distance = 0.00000005

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

  let assert Ok(first_offset) =
    offset.path_with(source, distance: offset_distance, options:)
  let assert Ok(untrimmed) =
    offset.path_untrimmed_with(
      first_offset,
      distance: offset_distance,
      options:,
    )
  io.println(
    "first offset subpaths: "
    <> int.to_string(list.length(svg_path.path_subpaths(first_offset))),
  )
  io.println(
    "second untrimmed offset subpaths: "
    <> int.to_string(list.length(svg_path.path_subpaths(untrimmed))),
  )
  let assert Ok(build) =
    arrangement.build(
      [untrimmed, first_offset],
      tolerance: 0.000000002,
      minimum_chord: 0.000000002,
    )
  let arrangement.ArrangementGraphBuild(graph:, segment_images:) = build
  let assert Ok(bands) =
    single_offset_bands(svg_path.path_subpaths(first_offset), options, [])
  let assert Ok(inside) = offset.internal_band_inside_function(bands)
  let graph_edges = first_path_edges(graph, segment_images)
  let assert Ok(colored_edges) = classify_edges(graph_edges, inside, [])
  let survivor_ids = final_survivor_ids(graph, colored_edges)
  let first_round_burn_ids = immediate_burn_ids(graph, colored_edges)
  io_report(
    graph,
    untrimmed,
    colored_edges,
    survivor_ids,
    first_round_burn_ids,
    bands,
  )
  write_file(
    output,
    render(
      source,
      first_offset,
      untrimmed,
      colored_edges,
      survivor_ids,
      first_round_burn_ids,
    ),
  )
  Nil
}

fn single_offset_bands(
  subpaths: List(svg_path.Subpath),
  options: offset.Options,
  converted: List(offset.OneSubpathBand),
) -> Result(List(offset.OneSubpathBand), offset.Error) {
  case subpaths {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use band <- result.try(offset.internal_single_offset_band_candidate(
        first,
        distance: offset_distance,
        options:,
      ))
      single_offset_bands(rest, options, [band, ..converted])
    }
  }
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

type ColoredEdge {
  ColoredEdge(edge: arrangement.ArrangementEdge, submerged: Bool)
}

fn classify_edges(
  edges: List(arrangement.ArrangementEdge),
  inside: fn(svg_path.Point) -> Result(Bool, offset.Error),
  converted: List(ColoredEdge),
) -> Result(List(ColoredEdge), offset.Error) {
  case edges {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      let arrangement.ArrangementEdge(segment:, ..) = first
      use submerged <- result.try(offset.internal_segment_is_submerged(
        segment,
        inside:,
        side_sampling_distance:,
      ))
      classify_edges(rest, inside, [ColoredEdge(first, submerged), ..converted])
    }
  }
}

fn final_survivor_ids(
  graph: arrangement.ArrangementGraph,
  colored_edges: List(ColoredEdge),
) -> List(Int) {
  let arrangement.UndirectedArrangementGraph(edges: undirected_edges, ..) =
    arrangement.to_undirected(graph)
  let candidate_edges =
    non_submerged_first_path_edges(undirected_edges, colored_edges)
  let burned = burn_unsupported_edges(candidate_edges, protected_vertices: [])
  burned
  |> list.map(fn(edge) {
    let arrangement.UndirectedArrangementEdge(id:, ..) = edge
    id
  })
}

fn immediate_burn_ids(
  graph: arrangement.ArrangementGraph,
  colored_edges: List(ColoredEdge),
) -> List(Int) {
  let arrangement.UndirectedArrangementGraph(edges: undirected_edges, ..) =
    arrangement.to_undirected(graph)
  let candidate_edges =
    non_submerged_first_path_edges(undirected_edges, colored_edges)
  candidate_edges
  |> list.filter(fn(edge) {
    undirected_edge_is_burned(edge, candidate_edges, [])
  })
  |> list.map(fn(edge) {
    let arrangement.UndirectedArrangementEdge(id:, ..) = edge
    id
  })
}

fn non_submerged_first_path_edges(
  undirected_edges: List(arrangement.UndirectedArrangementEdge),
  colored_edges: List(ColoredEdge),
) -> List(arrangement.UndirectedArrangementEdge) {
  let first_path_ids =
    colored_edges
    |> list.map(fn(edge) {
      let ColoredEdge(edge: arrangement.ArrangementEdge(id:, ..), ..) = edge
      id
    })
  let non_submerged_ids =
    colored_edges
    |> list.filter_map(fn(edge) {
      let ColoredEdge(edge: arrangement.ArrangementEdge(id:, ..), submerged:) =
        edge
      case submerged {
        True -> Error(Nil)
        False -> Ok(id)
      }
    })
  undirected_edges
  |> list.filter(fn(edge) {
    let arrangement.UndirectedArrangementEdge(id:, ..) = edge
    int_in_list(id, first_path_ids) && int_in_list(id, non_submerged_ids)
  })
}

fn burn_unsupported_edges(
  edges: List(arrangement.UndirectedArrangementEdge),
  protected_vertices protected_vertices: List(Int),
) -> List(arrangement.UndirectedArrangementEdge) {
  let retained =
    edges
    |> list.filter(fn(edge) {
      !undirected_edge_is_burned(edge, edges, protected_vertices)
    })
  case list.length(retained) == list.length(edges) {
    True -> retained
    False -> burn_unsupported_edges(retained, protected_vertices:)
  }
}

fn undirected_edge_is_burned(
  edge: arrangement.UndirectedArrangementEdge,
  edges: List(arrangement.UndirectedArrangementEdge),
  protected_vertices: List(Int),
) -> Bool {
  let arrangement.UndirectedArrangementEdge(start_vertex:, end_vertex:, ..) =
    edge
  endpoint_burns(start_vertex, edges, protected_vertices)
  || endpoint_burns(end_vertex, edges, protected_vertices)
}

fn endpoint_burns(
  vertex: Int,
  edges: List(arrangement.UndirectedArrangementEdge),
  protected_vertices: List(Int),
) -> Bool {
  !list.contains(protected_vertices, vertex)
  && undirected_incidence_degree(edges, vertex) == 1
}

fn undirected_incidence_degree(
  edges: List(arrangement.UndirectedArrangementEdge),
  vertex: Int,
) -> Int {
  case edges {
    [] -> 0
    [edge, ..rest] -> {
      let arrangement.UndirectedArrangementEdge(start_vertex:, end_vertex:, ..) =
        edge
      let contribution = case start_vertex == vertex, end_vertex == vertex {
        True, True -> 2
        True, False -> 1
        False, True -> 1
        False, False -> 0
      }
      contribution + undirected_incidence_degree(rest, vertex)
    }
  }
}

fn io_report(
  graph: arrangement.ArrangementGraph,
  untrimmed: svg_path.Path,
  edges: List(ColoredEdge),
  survivor_ids: List(Int),
  immediate_burn_ids: List(Int),
  _bands: List(offset.OneSubpathBand),
) -> Nil {
  io.println(
    "untrimmed first offset subpaths: "
    <> int.to_string(list.length(svg_path.path_subpaths(untrimmed))),
  )
  io.println(
    "first offset arrangement edges: " <> int.to_string(list.length(edges)),
  )
  io.println(
    "submerged red edges: "
    <> int.to_string(
      list.length(
        list.filter(edges, fn(edge) {
          let ColoredEdge(submerged:, ..) = edge
          submerged
        }),
      ),
    ),
  )
  io.println(
    "final survivor purple edges: " <> int.to_string(list.length(survivor_ids)),
  )
  io.println("final survivor purple edge ids: " <> ints_string(survivor_ids))
  io.println(
    "immediate dangling yellow edges: "
    <> int.to_string(list.length(immediate_burn_ids)),
  )
  io.println(
    "immediate dangling yellow edge ids: " <> ints_string(immediate_burn_ids),
  )
  report_edges_131_133(graph, edges, survivor_ids)
  report_edge_pair_adjacency(graph, 256, 257)
  report_edge(
    258,
    edges,
    survivor_ids,
    candidate_undirected_edges(arrangement.to_undirected(graph).edges, edges),
  )
  report_zoom_vertices_and_incident_edges(graph, edges)
  report_outside_incident_edges(edges)
}

fn report_outside_incident_edges(edges: List(ColoredEdge)) -> Nil {
  let angle_options = svg_path.default_containment_options()
  let svg_path.ContainmentOptions(fallback_ray_angles:, ..) = angle_options
  let graph_segments =
    edges
    |> list.map(fn(edge) {
      let ColoredEdge(edge: arrangement.ArrangementEdge(segment:, ..), ..) =
        edge
      segment
    })
  let outside_ids =
    edges
    |> list.filter_map(fn(edge) {
      let ColoredEdge(edge: arrangement.ArrangementEdge(id:, segment:, ..), ..) =
        edge
      case edge_has_outside_side(segment, graph_segments, fallback_ray_angles) {
        Ok(True) -> Ok(id)
        _ -> Error(Nil)
      }
    })
  io.println("")
  io.println(
    "outside-incident first-offset edge ids: " <> ints_string(outside_ids),
  )
}

fn edge_has_outside_side(
  segment: svg_path.Segment,
  graph_segments: List(svg_path.Segment),
  angles: List(Float),
) -> Result(Bool, svg_path.Error) {
  use midpoint <- result.try(svg_path.segment_point(segment, at: 0.5))
  use normal <- result.try(segment_unit_normal(segment, at: 0.5))
  let first =
    point.add(midpoint, point.scale(normal, by: side_sampling_distance))
  let second =
    point.add(midpoint, point.scale(normal, by: 0.0 -. side_sampling_distance))
  use first_outside <- result.try(point_has_empty_ray(
    first,
    graph_segments,
    angles,
  ))
  case first_outside {
    True -> Ok(True)
    False -> point_has_empty_ray(second, graph_segments, angles)
  }
}

fn point_has_empty_ray(
  origin: svg_path.Point,
  graph_segments: List(svg_path.Segment),
  angles: List(Float),
) -> Result(Bool, svg_path.Error) {
  case angles {
    [] -> Ok(False)
    [angle, ..rest] -> {
      use counts <- result.try(ray_crossing_counts(
        origin,
        graph_segments,
        angle,
      ))
      let #(forward_count, backward_count) = counts
      case forward_count == 0 || backward_count == 0 {
        True -> Ok(True)
        False -> point_has_empty_ray(origin, graph_segments, rest)
      }
    }
  }
}

fn ray_crossing_counts(
  origin: svg_path.Point,
  graph_segments: List(svg_path.Segment),
  angle: Float,
) -> Result(#(Int, Int), svg_path.Error) {
  segments_ray_crossing_counts(graph_segments, origin, angle, 0, 0)
}

fn segments_ray_crossing_counts(
  graph_segments: List(svg_path.Segment),
  origin: svg_path.Point,
  angle: Float,
  forward_count: Int,
  backward_count: Int,
) -> Result(#(Int, Int), svg_path.Error) {
  case graph_segments {
    [] -> Ok(#(forward_count, backward_count))
    [first, ..rest] -> {
      use crossings <- result.try(
        svg_path.internal_segment_ray_crossings_for_angle(
          first,
          origin:,
          ray_angle: angle,
          options: svg_path.default_containment_options(),
        ),
      )
      let #(forward, backward) = crossings
      segments_ray_crossing_counts(
        rest,
        origin,
        angle,
        forward_count + list.length(forward),
        backward_count + list.length(backward),
      )
    }
  }
}

fn segment_unit_normal(
  segment: svg_path.Segment,
  at t: Float,
) -> Result(svg_path.Point, svg_path.Error) {
  use directions <- result.try(svg_path.segment_directions(segment, at: t))
  let direction = case t {
    0.0 -> directions.outgoing
    1.0 -> directions.incoming
    _ -> directions.outgoing
  }
  case direction {
    Some(tangent) -> Ok(point.rotate_clockwise(tangent))
    None -> Error(svg_path.IndeterminateDirection)
  }
}

fn ints_string(ids: List(Int)) -> String {
  ids
  |> list.map(int.to_string)
  |> string.join(", ")
}

fn report_edges_131_133(
  graph: arrangement.ArrangementGraph,
  edges: List(ColoredEdge),
  survivor_ids: List(Int),
) -> Nil {
  let arrangement.UndirectedArrangementGraph(edges: undirected_edges, ..) =
    arrangement.to_undirected(graph)
  let candidate_edges = candidate_undirected_edges(undirected_edges, edges)
  io.println("")
  io.println("edge 131/133 pruning report:")
  report_edge(131, edges, survivor_ids, candidate_edges)
  report_edge(133, edges, survivor_ids, candidate_edges)
  report_burn_rounds([131, 133], candidate_edges, 0)
}

fn candidate_undirected_edges(
  undirected_edges: List(arrangement.UndirectedArrangementEdge),
  colored_edges: List(ColoredEdge),
) -> List(arrangement.UndirectedArrangementEdge) {
  let first_path_ids =
    colored_edges
    |> list.map(fn(edge) {
      let ColoredEdge(edge: arrangement.ArrangementEdge(id:, ..), ..) = edge
      id
    })
  let non_submerged_ids =
    colored_edges
    |> list.filter_map(fn(edge) {
      let ColoredEdge(edge: arrangement.ArrangementEdge(id:, ..), submerged:) =
        edge
      case submerged {
        True -> Error(Nil)
        False -> Ok(id)
      }
    })
  undirected_edges
  |> list.filter(fn(edge) {
    let arrangement.UndirectedArrangementEdge(id:, ..) = edge
    int_in_list(id, first_path_ids) && int_in_list(id, non_submerged_ids)
  })
}

fn report_edge(
  id: Int,
  edges: List(ColoredEdge),
  survivor_ids: List(Int),
  candidate_edges: List(arrangement.UndirectedArrangementEdge),
) -> Nil {
  let submerged = edge_submerged(edges, id)
  let survivor = int_in_list(id, survivor_ids)
  let detail = undirected_edge_detail(candidate_edges, candidate_edges, id)
  io.println(
    "edge "
    <> int.to_string(id)
    <> " submerged="
    <> bool_string(submerged)
    <> " survivor="
    <> bool_string(survivor)
    <> " "
    <> detail,
  )
}

fn report_edge_pair_adjacency(
  graph: arrangement.ArrangementGraph,
  first_id: Int,
  second_id: Int,
) -> Nil {
  let arrangement.ArrangementGraph(edges:, ..) = graph
  io.println("")
  io.println(
    "edge "
    <> int.to_string(first_id)
    <> "/"
    <> int.to_string(second_id)
    <> " adjacency report:",
  )
  case
    directed_edge_with_id(edges, first_id),
    directed_edge_with_id(edges, second_id)
  {
    Ok(first), Ok(second) -> {
      let arrangement.ArrangementEdge(
        start_vertex: first_start,
        end_vertex: first_end,
        segment: first_segment,
        ..,
      ) = first
      let arrangement.ArrangementEdge(
        start_vertex: second_start,
        end_vertex: second_end,
        segment: second_segment,
        ..,
      ) = second
      io.println(
        "edge "
        <> int.to_string(first_id)
        <> " v"
        <> int.to_string(first_start)
        <> "->v"
        <> int.to_string(first_end),
      )
      io.println(
        "edge "
        <> int.to_string(second_id)
        <> " v"
        <> int.to_string(second_start)
        <> "->v"
        <> int.to_string(second_end),
      )
      io.println(
        "share vertex: "
        <> bool_string(edges_share_vertex(
          first_start,
          first_end,
          second_start,
          second_end,
        )),
      )
      report_endpoint_distances(first_segment, second_segment)
    }
    _, _ -> io.println("one edge was not found")
  }
}

fn report_zoom_vertices_and_incident_edges(
  graph: arrangement.ArrangementGraph,
  colored_edges: List(ColoredEdge),
) -> Nil {
  let arrangement.ArrangementGraph(vertices:, edges:) = graph
  let assert Ok(center) = near_duplicate_center(colored_edges, 256, 257)
  let boxes = colored_edges_to_boxes(colored_edges)
  let assert [first_box, ..] = boxes
  let combined_box =
    list.fold(boxes, first_box, fn(acc, box) { combine_boxes(acc, box) })
  let full_box = padded_box([combined_box], margin: 3.0)
  let view_box = zoom_box(full_box, center, zoom: 50.0)
  let local_vertices =
    vertices
    |> list.filter(fn(vertex) {
      let arrangement.ArrangementVertex(point:, ..) = vertex
      point_inside_box(point, view_box)
    })
  io.println("")
  io.println("vertices in 256/257 zoom viewbox:")
  local_vertices
  |> list.each(fn(vertex) {
    let arrangement.ArrangementVertex(id:, point:, ..) = vertex
    io.println(
      "v"
      <> int.to_string(id)
      <> " at ("
      <> float.to_string(point.x)
      <> ", "
      <> float.to_string(point.y)
      <> ") incident_edges="
      <> ints_string(incident_edge_ids(edges, id)),
    )
  })
}

fn colored_edges_to_boxes(
  edges: List(ColoredEdge),
) -> List(svg_path.BoundingBox) {
  edges
  |> list.filter_map(fn(edge) {
    let ColoredEdge(edge: arrangement.ArrangementEdge(bounds:, ..), ..) = edge
    Ok(bounds)
  })
}

fn point_inside_box(point: svg_path.Point, box: svg_path.BoundingBox) -> Bool {
  point.x >=. box.min.x
  && point.x <=. box.max.x
  && point.y >=. box.min.y
  && point.y <=. box.max.y
}

fn incident_edge_ids(
  edges: List(arrangement.ArrangementEdge),
  vertex_id: Int,
) -> List(Int) {
  edges
  |> list.filter_map(fn(edge) {
    let arrangement.ArrangementEdge(id:, start_vertex:, end_vertex:, ..) = edge
    case start_vertex == vertex_id || end_vertex == vertex_id {
      True -> Ok(id)
      False -> Error(Nil)
    }
  })
}

fn directed_edge_with_id(
  edges: List(arrangement.ArrangementEdge),
  id: Int,
) -> Result(arrangement.ArrangementEdge, Nil) {
  case edges {
    [] -> Error(Nil)
    [first, ..rest] -> {
      let arrangement.ArrangementEdge(id: edge_id, ..) = first
      case edge_id == id {
        True -> Ok(first)
        False -> directed_edge_with_id(rest, id)
      }
    }
  }
}

fn edges_share_vertex(a0: Int, a1: Int, b0: Int, b1: Int) -> Bool {
  a0 == b0 || a0 == b1 || a1 == b0 || a1 == b1
}

fn report_endpoint_distances(
  first: svg_path.Segment,
  second: svg_path.Segment,
) -> Nil {
  let assert Ok(first_start) = svg_path.segment_point(first, at: 0.0)
  let assert Ok(first_end) = svg_path.segment_point(first, at: 1.0)
  let assert Ok(second_start) = svg_path.segment_point(second, at: 0.0)
  let assert Ok(second_end) = svg_path.segment_point(second, at: 1.0)
  io.println(
    "endpoint distances: "
    <> "a0-b0="
    <> float.to_string(point.distance(first_start, second_start))
    <> " a0-b1="
    <> float.to_string(point.distance(first_start, second_end))
    <> " a1-b0="
    <> float.to_string(point.distance(first_end, second_start))
    <> " a1-b1="
    <> float.to_string(point.distance(first_end, second_end)),
  )
}

fn edge_submerged(edges: List(ColoredEdge), id: Int) -> Bool {
  case edges {
    [] -> False
    [edge, ..rest] -> {
      let ColoredEdge(
        edge: arrangement.ArrangementEdge(id: edge_id, ..),
        submerged:,
      ) = edge
      case edge_id == id {
        True -> submerged
        False -> edge_submerged(rest, id)
      }
    }
  }
}

fn undirected_edge_detail(
  all_edges: List(arrangement.UndirectedArrangementEdge),
  edges: List(arrangement.UndirectedArrangementEdge),
  id: Int,
) -> String {
  case edges {
    [] -> "not_candidate"
    [edge, ..rest] -> {
      let arrangement.UndirectedArrangementEdge(
        id: edge_id,
        start_vertex:,
        end_vertex:,
        multiplicity:,
        ..,
      ) = edge
      case edge_id == id {
        True ->
          "v"
          <> int.to_string(start_vertex)
          <> "->v"
          <> int.to_string(end_vertex)
          <> " mult="
          <> int.to_string(multiplicity)
          <> " degree_start="
          <> int.to_string(undirected_incidence_degree(all_edges, start_vertex))
          <> " degree_end="
          <> int.to_string(undirected_incidence_degree(all_edges, end_vertex))
        False -> undirected_edge_detail(all_edges, rest, id)
      }
    }
  }
}

fn report_burn_rounds(
  ids: List(Int),
  edges: List(arrangement.UndirectedArrangementEdge),
  round: Int,
) -> Nil {
  case edges {
    [] -> Nil
    _ -> {
      let burned =
        edges
        |> list.filter(fn(edge) { undirected_edge_is_burned(edge, edges, []) })
      let burned_ids =
        burned
        |> list.map(fn(edge) {
          let arrangement.UndirectedArrangementEdge(id:, ..) = edge
          id
        })
      ids
      |> list.each(fn(id) {
        case int_in_list(id, burned_ids) {
          True ->
            io.println(
              "edge "
              <> int.to_string(id)
              <> " burns at round "
              <> int.to_string(round)
              <> " "
              <> undirected_edge_detail(edges, edges, id),
            )
          False -> Nil
        }
      })
      let retained =
        edges
        |> list.filter(fn(edge) { !undirected_edge_is_burned(edge, edges, []) })
      case list.length(retained) == list.length(edges) {
        True -> Nil
        False -> report_burn_rounds(ids, retained, round + 1)
      }
    }
  }
}

fn bool_string(value: Bool) -> String {
  case value {
    True -> "True"
    False -> "False"
  }
}

fn render(
  source: svg_path.Path,
  first_offset: svg_path.Path,
  untrimmed: svg_path.Path,
  edges: List(ColoredEdge),
  survivor_ids: List(Int),
  immediate_burn_ids: List(Int),
) -> String {
  let boxes = path_boxes([source, first_offset, untrimmed])
  let view_box = padded_box(boxes, margin: 3.0)
  let things = [
    background(view_box),
    svg.StyledPath(source, "fill: #111827; stroke: none; opacity: 0.16"),
    svg.StyledPath(
      first_offset,
      "fill: none; stroke: #2563eb; stroke-width: 0.07; stroke-linecap: round; stroke-linejoin: round",
    ),
    svg.StyledPath(
      untrimmed,
      "fill: none; stroke: #cbd5e1; stroke-width: 0.05; stroke-linecap: round; stroke-linejoin: round",
    ),
    ..list.append(
      edge_paths(edges),
      list.append(
        immediate_burn_paths(edges, immediate_burn_ids),
        list.append(
          survivor_paths(edges, survivor_ids),
          list.append(edge_labels(edges, survivor_ids), graph_vertices(edges)),
        ),
      ),
    )
  ]

  svg.document(things:, view_box:)
  |> with_root_size(width: 1800, height: 420)
}

fn render_zoom(
  source: svg_path.Path,
  untrimmed: svg_path.Path,
  edges: List(ColoredEdge),
  survivor_ids: List(Int),
  immediate_burn_ids: List(Int),
) -> String {
  let boxes = path_boxes([source, untrimmed])
  let full_box = padded_box(boxes, margin: 3.0)
  let assert Ok(center) = near_duplicate_center(edges, 256, 257)
  let view_box = zoom_box(full_box, center, zoom: 50.0)
  let local_edges = edges_intersecting_box(edges, view_box)
  let things = [
    background(view_box),
    svg.StyledPath(source, "fill: #111827; stroke: none; opacity: 0.10"),
    svg.StyledPath(
      untrimmed,
      "fill: none; stroke: #cbd5e1; stroke-width: 0.005; stroke-linecap: round; stroke-linejoin: round",
    ),
    ..list.append(
      zoom_edge_paths(local_edges),
      list.append(
        zoom_immediate_burn_paths(local_edges, immediate_burn_ids),
        list.append(
          zoom_survivor_paths(local_edges, survivor_ids),
          list.append(
            zoom_edge_labels(local_edges),
            zoom_graph_vertices(local_edges),
          ),
        ),
      ),
    )
  ]

  svg.document(things:, view_box:)
  |> with_root_size(width: 1800, height: 420)
}

fn near_duplicate_center(
  edges: List(ColoredEdge),
  first_id: Int,
  second_id: Int,
) -> Result(svg_path.Point, Nil) {
  use first <- result.try(colored_edge_with_id(edges, first_id))
  use second <- result.try(colored_edge_with_id(edges, second_id))
  let ColoredEdge(
    edge: arrangement.ArrangementEdge(segment: first_segment, ..),
    ..,
  ) = first
  let ColoredEdge(
    edge: arrangement.ArrangementEdge(segment: second_segment, ..),
    ..,
  ) = second
  let assert Ok(first_end) = svg_path.segment_point(first_segment, at: 1.0)
  let assert Ok(second_start) = svg_path.segment_point(second_segment, at: 0.0)
  Ok(svg_path.Point(
    { first_end.x +. second_start.x } /. 2.0,
    { first_end.y +. second_start.y } /. 2.0,
  ))
}

fn colored_edge_with_id(
  edges: List(ColoredEdge),
  id: Int,
) -> Result(ColoredEdge, Nil) {
  case edges {
    [] -> Error(Nil)
    [first, ..rest] -> {
      let ColoredEdge(edge: arrangement.ArrangementEdge(id: edge_id, ..), ..) =
        first
      case edge_id == id {
        True -> Ok(first)
        False -> colored_edge_with_id(rest, id)
      }
    }
  }
}

fn zoom_box(
  full_box: svg_path.BoundingBox,
  center: svg_path.Point,
  zoom zoom: Float,
) -> svg_path.BoundingBox {
  let width = svg_path.bounding_box_width(full_box) /. zoom
  let height = svg_path.bounding_box_height(full_box) /. zoom
  svg_path.BoundingBox(
    min: svg_path.Point(center.x -. width /. 2.0, center.y -. height /. 2.0),
    max: svg_path.Point(center.x +. width /. 2.0, center.y +. height /. 2.0),
  )
}

fn edges_intersecting_box(
  edges: List(ColoredEdge),
  box: svg_path.BoundingBox,
) -> List(ColoredEdge) {
  edges
  |> list.filter(fn(edge) {
    let ColoredEdge(edge: arrangement.ArrangementEdge(segment:, ..), ..) = edge
    case svg_path.segment_bounding_box(segment) {
      Ok(segment_box) -> boxes_intersect(segment_box, box)
      Error(_) -> False
    }
  })
}

fn boxes_intersect(
  left: svg_path.BoundingBox,
  right: svg_path.BoundingBox,
) -> Bool {
  left.max.x >=. right.min.x
  && left.min.x <=. right.max.x
  && left.max.y >=. right.min.y
  && left.min.y <=. right.max.y
}

fn zoom_edge_paths(edges: List(ColoredEdge)) -> svg.ThingsToDraw {
  edges
  |> list.map(fn(edge) {
    let ColoredEdge(edge: arrangement.ArrangementEdge(segment:, ..), submerged:) =
      edge
    let color = case submerged {
      True -> "#dc2626"
      False -> "#16a34a"
    }
    svg.StyledPath(
      svg_path.segment_as_path(segment),
      "fill: none; stroke: "
        <> color
        <> "; stroke-width: 0.009; stroke-linecap: round; stroke-linejoin: round; opacity: 0.82",
    )
  })
}

fn zoom_immediate_burn_paths(
  edges: List(ColoredEdge),
  immediate_burn_ids: List(Int),
) -> svg.ThingsToDraw {
  edges
  |> list.filter(fn(edge) {
    let ColoredEdge(edge: arrangement.ArrangementEdge(id:, ..), ..) = edge
    int_in_list(id, immediate_burn_ids)
  })
  |> list.map(fn(edge) {
    let ColoredEdge(edge: arrangement.ArrangementEdge(segment:, ..), ..) = edge
    svg.StyledPath(
      svg_path.segment_as_path(segment),
      "fill: none; stroke: #facc15; stroke-width: 0.022; stroke-linecap: round; stroke-linejoin: round; opacity: 0.98",
    )
  })
}

fn zoom_survivor_paths(
  edges: List(ColoredEdge),
  survivor_ids: List(Int),
) -> svg.ThingsToDraw {
  edges
  |> list.filter(fn(edge) {
    let ColoredEdge(edge: arrangement.ArrangementEdge(id:, ..), ..) = edge
    int_in_list(id, survivor_ids)
  })
  |> list.map(fn(edge) {
    let ColoredEdge(edge: arrangement.ArrangementEdge(segment:, ..), ..) = edge
    svg.StyledPath(
      svg_path.segment_as_path(segment),
      "fill: none; stroke: #7c3aed; stroke-width: 0.016; stroke-linecap: round; stroke-linejoin: round; opacity: 0.95",
    )
  })
}

fn zoom_edge_labels(edges: List(ColoredEdge)) -> svg.ThingsToDraw {
  edges
  |> list.filter_map(fn(edge) {
    let ColoredEdge(edge: arrangement.ArrangementEdge(id:, segment:, ..), ..) =
      edge
    use box <- result.try(svg_path.segment_bounding_box(segment))
    let svg_path.BoundingBox(min:, max:) = box
    let center =
      svg_path.Point({ min.x +. max.x } /. 2.0, { min.y +. max.y } /. 2.0)
    Ok(svg.Text(
      int.to_string(id),
      "fill: #1e3a8a; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; text-anchor: middle; dominant-baseline: central",
      center,
      0.03,
    ))
  })
}

fn zoom_graph_vertices(edges: List(ColoredEdge)) -> svg.ThingsToDraw {
  edges
  |> list.flat_map(fn(edge) {
    let ColoredEdge(edge: arrangement.ArrangementEdge(segment:, ..), ..) = edge
    [
      svg.Circle(
        svg_path.segment_start(segment),
        0.0035,
        "fill: #111827; stroke: none; opacity: 0.8",
      ),
      svg.Circle(
        svg_path.segment_end(segment),
        0.0035,
        "fill: #111827; stroke: none; opacity: 0.8",
      ),
    ]
  })
}

fn immediate_burn_paths(
  edges: List(ColoredEdge),
  immediate_burn_ids: List(Int),
) -> svg.ThingsToDraw {
  edges
  |> list.filter(fn(edge) {
    let ColoredEdge(edge: arrangement.ArrangementEdge(id:, ..), ..) = edge
    int_in_list(id, immediate_burn_ids)
  })
  |> list.map(fn(edge) {
    let ColoredEdge(edge: arrangement.ArrangementEdge(segment:, ..), ..) = edge
    svg.StyledPath(
      svg_path.segment_as_path(segment),
      "fill: none; stroke: #facc15; stroke-width: 0.22; stroke-linecap: round; stroke-linejoin: round; opacity: 0.98",
    )
  })
}

fn survivor_paths(
  edges: List(ColoredEdge),
  survivor_ids: List(Int),
) -> svg.ThingsToDraw {
  edges
  |> list.filter(fn(edge) {
    let ColoredEdge(edge: arrangement.ArrangementEdge(id:, ..), ..) = edge
    int_in_list(id, survivor_ids)
  })
  |> list.map(fn(edge) {
    let ColoredEdge(edge: arrangement.ArrangementEdge(segment:, ..), ..) = edge
    svg.StyledPath(
      svg_path.segment_as_path(segment),
      "fill: none; stroke: #7c3aed; stroke-width: 0.16; stroke-linecap: round; stroke-linejoin: round; opacity: 0.95",
    )
  })
}

fn edge_labels(
  edges: List(ColoredEdge),
  survivor_ids: List(Int),
) -> svg.ThingsToDraw {
  edges
  |> list.filter(fn(edge) {
    let ColoredEdge(edge: arrangement.ArrangementEdge(id:, ..), submerged:) =
      edge
    !submerged || int_in_list(id, survivor_ids)
  })
  |> list.filter_map(fn(edge) {
    let ColoredEdge(edge: arrangement.ArrangementEdge(id:, segment:, ..), ..) =
      edge
    use box <- result.try(svg_path.segment_bounding_box(segment))
    let svg_path.BoundingBox(min:, max:) = box
    let center =
      svg_path.Point({ min.x +. max.x } /. 2.0, { min.y +. max.y } /. 2.0)
    Ok(svg.Text(
      int.to_string(id),
      "fill: #1e3a8a; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; text-anchor: middle; dominant-baseline: central",
      center,
      0.3,
    ))
  })
}

fn edge_paths(edges: List(ColoredEdge)) -> svg.ThingsToDraw {
  edges
  |> list.map(fn(edge) {
    let ColoredEdge(edge: arrangement.ArrangementEdge(segment:, ..), submerged:) =
      edge
    let color = case submerged {
      True -> "#dc2626"
      False -> "#16a34a"
    }
    svg.StyledPath(
      svg_path.segment_as_path(segment),
      "fill: none; stroke: "
        <> color
        <> "; stroke-width: 0.09; stroke-linecap: round; stroke-linejoin: round; opacity: 0.82",
    )
  })
}

fn graph_vertices(edges: List(ColoredEdge)) -> svg.ThingsToDraw {
  edges
  |> list.flat_map(fn(edge) {
    let ColoredEdge(edge: arrangement.ArrangementEdge(segment:, ..), ..) = edge
    [
      svg.Circle(
        svg_path.segment_start(segment),
        0.035,
        "fill: #111827; stroke: none; opacity: 0.8",
      ),
      svg.Circle(
        svg_path.segment_end(segment),
        0.035,
        "fill: #111827; stroke: none; opacity: 0.8",
      ),
    ]
  })
}

fn path_boxes(paths: List(svg_path.Path)) -> List(svg_path.BoundingBox) {
  paths
  |> list.filter_map(svg_path.path_bounding_box)
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
  let combined =
    list.fold(boxes, first, fn(acc, box) { combine_boxes(acc, box) })
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

fn first_path_data(contents: String) -> String {
  let assert [_, after_attribute] = string.split(contents, on: " d=\"")
  let assert [data, ..] = string.split(after_attribute, on: "\"")
  data
}

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(String, Dynamic)

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
