//// Arrangement-graph primitives for Boolean path operations.
////
//// This module provides arrangement construction, endpoint clustering,
//// coincident-edge multiplicity, validation, Boolean boundary extraction, and
//// diagnostic drawing. `build` refines intersections and endpoint-bounded
//// overlaps into atomic segments before inserting them as graph edges.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import svg_path
import svg_path/effects
import svg_path/intersections
import svg_path/overlaps
import svg_path/point
import svg_path/smallest_enclosing_circle
import svg_path/svg
import svg_path/trig
import svg_path/winding_field

/// One endpoint cluster in the embedded arrangement.
///
/// `point` is the center of the smallest circle enclosing `endpoint_samples`.
/// Construction accepts a sample only when that circle's squared radius does
/// not exceed the graph's squared endpoint tolerance.
pub type ArrangementVertex {
  ArrangementVertex(
    id: Int,
    point: svg_path.Point,
    endpoint_samples: List(svg_path.Point),
  )
}

pub type ArrangementEdge {
  ArrangementEdge(
    id: Int,
    segment: svg_path.Segment,
    start_vertex: Int,
    end_vertex: Int,
    forward_multiplicity: Int,
    reverse_multiplicity: Int,
  )
}

pub type ArrangementGraph {
  ArrangementGraph(
    vertices: List(ArrangementVertex),
    edges: List(ArrangementEdge),
  )
}

/// An arrangement graph and the normalized source paths from which it was
/// constructed. Source-path order is preserved.
pub type ArrangementGraphBuild {
  ArrangementGraphBuild(
    graph: ArrangementGraph,
    normalized_paths: List(svg_path.Path),
  )
}

/// Placement of an edge annotation derived from the stored segment itself.
/// `rotation` is an SVG rotation angle for which the annotation's local up
/// direction follows the segment tangent.
pub type EdgeAnnotationPose {
  EdgeAnnotationPose(point: svg_path.Point, rotation: Float)
}

pub type Error {
  PathError(svg_path.Error)
  EffectError(effects.Error)
  InvalidTolerance(Float)
  SegmentTooShort(chord: Float, minimum: Float)
  LoopEdge(vertex: Int)
  MissingVertex(vertex: Int)
  IsolatedVertex(vertex: Int)
  InvalidMultiplicity(edge: Int)
  OddWeightedDegree(vertex: Int, degree: Int)
  EdgeEndpointMismatch(edge: Int, vertex: Int, distance: Float)
  VertexWithoutEndpointSamples(vertex: Int)
  VertexCenterMismatch(vertex: Int, distance_squared: Float)
  VertexSampleOutsideTolerance(
    vertex: Int,
    distance_squared: Float,
    tolerance_squared: Float,
  )
}

type IndexedSegment {
  IndexedSegment(index: Int, segment: svg_path.Segment)
}

type VertexAttachment {
  VertexAttachment(
    vertex: ArrangementVertex,
    center: svg_path.Point,
    radius_squared: Float,
  )
}

type SegmentCut {
  SegmentCut(index: Int, t: Float)
}

@internal
pub fn empty() -> ArrangementGraph {
  ArrangementGraph(vertices: [], edges: [])
}

/// Replace line-degenerate segment sequences before arrangement construction.
fn normalize_subpaths(
  subpaths: List(svg_path.Subpath),
  tolerance tolerance: Float,
) -> Result(List(svg_path.Subpath), Error) {
  case tolerance <=. 0.0 {
    True -> Error(InvalidTolerance(tolerance))
    False ->
      subpaths
      |> list.map(effects.subpath_colinearize(_, tolerance:))
      |> result.all
      |> result.map_error(EffectError)
  }
}

fn normalize_paths(
  paths: List(svg_path.Path),
  tolerance: Float,
) -> Result(List(svg_path.Path), Error) {
  paths
  |> list.map(fn(path) {
    path
    |> svg_path.path_subpaths
    |> normalize_subpaths(tolerance:)
    |> result.map(svg_path.Path)
  })
  |> result.all
}

/// Insert one atomic segment directly as an arrangement edge.
///
/// Endpoints within `tolerance` join the same vertex. A structurally identical
/// edge increments its forward multiplicity; its structural reverse increments
/// reverse multiplicity. An atomic segment has no proper intersection or
/// partial overlap with any existing edge; callers must establish that
/// precondition before using this trusting insertion primitive.
@internal
pub fn insert_atomic_segment(
  graph: ArrangementGraph,
  segment: svg_path.Segment,
  tolerance tolerance: Float,
  minimum_chord minimum_chord: Float,
) -> Result(ArrangementGraph, Error) {
  case tolerance <=. 0.0 || minimum_chord <=. 0.0 {
    True -> Error(InvalidTolerance(float_min(tolerance, minimum_chord)))
    False -> {
      let start = svg_path.segment_start(segment)
      let end = svg_path.segment_end(segment)
      let chord = point.distance(start, end)
      case chord <. minimum_chord {
        True -> Error(SegmentTooShort(chord:, minimum: minimum_chord))
        False -> {
          let ArrangementGraph(vertices:, edges:) = graph
          let #(vertices, start_id) = attach_vertex(vertices, start, tolerance)
          let #(vertices, end_id) = attach_vertex(vertices, end, tolerance)
          case start_id == end_id {
            True -> Error(LoopEdge(vertex: start_id))
            False ->
              Ok(ArrangementGraph(
                vertices:,
                edges: insert_or_increment_edge(
                  edges,
                  segment,
                  start_id,
                  end_id,
                ),
              ))
          }
        }
      }
    }
  }
}

/// Build an arrangement graph from independently normalized source paths.
///
/// Source-path order is retained in the result. Construction flattens their
/// segments, refines them at point intersections and endpoint-bounded overlap
/// boundaries, and inserts the resulting atomic segments. Its output is
/// independent of input processing order. Overlap detection uses endpoint
/// projection, so semantically equal arcs need not have structurally equal SVG
/// flags or matching original subdivision points.
pub fn build(
  paths: List(svg_path.Path),
  tolerance tolerance: Float,
  minimum_chord minimum_chord: Float,
) -> Result(ArrangementGraphBuild, Error) {
  use normalized_paths <- result.try(normalize_paths(paths, tolerance))
  let segments =
    normalized_paths
    |> list.flat_map(svg_path.path_subpaths)
    |> list.flat_map(svg_path.subpath_segments)
  use atomic_segments <- result.try(refine_segments_to_atomic(
    segments,
    tolerance,
    minimum_chord,
  ))
  use graph <- result.try(insert_semantic_pieces(
    atomic_segments,
    empty(),
    tolerance,
    minimum_chord,
  ))
  Ok(ArrangementGraphBuild(graph:, normalized_paths:))
}

fn refine_segments_to_atomic(
  segments: List(svg_path.Segment),
  tolerance: Float,
  minimum_chord: Float,
) -> Result(List(svg_path.Segment), Error) {
  let indexed = index_segments(segments, 0, [])
  use cuts <- result.try(collect_all_cuts(indexed, tolerance, []))
  split_indexed_segments(indexed, cuts, tolerance, minimum_chord, [])
}

fn index_segments(
  segments: List(svg_path.Segment),
  index: Int,
  indexed: List(IndexedSegment),
) -> List(IndexedSegment) {
  case segments {
    [] -> list.reverse(indexed)
    [first, ..rest] ->
      index_segments(rest, index + 1, [
        IndexedSegment(index:, segment: first),
        ..indexed
      ])
  }
}

fn collect_all_cuts(
  segments: List(IndexedSegment),
  tolerance: Float,
  cuts: List(SegmentCut),
) -> Result(List(SegmentCut), Error) {
  case segments {
    [] -> Ok(cuts)
    [first, ..rest] -> {
      use cuts <- result.try(collect_cuts_against(first, rest, tolerance, cuts))
      collect_all_cuts(rest, tolerance, cuts)
    }
  }
}

fn collect_cuts_against(
  left: IndexedSegment,
  rights: List(IndexedSegment),
  tolerance: Float,
  cuts: List(SegmentCut),
) -> Result(List(SegmentCut), Error) {
  case rights {
    [] -> Ok(cuts)
    [right, ..rest] -> {
      use pair_cuts <- result.try(pair_cuts(left, right, tolerance))
      collect_cuts_against(left, rest, tolerance, list.append(pair_cuts, cuts))
    }
  }
}

fn pair_cuts(
  left: IndexedSegment,
  right: IndexedSegment,
  tolerance: Float,
) -> Result(List(SegmentCut), Error) {
  let IndexedSegment(index: left_index, segment: left_segment) = left
  let IndexedSegment(index: right_index, segment: right_segment) = right
  use found_overlaps <- result.try(
    overlaps.segment_overlaps_by_endpoint_projection_with(
      left_segment,
      right_segment,
      tolerance:,
      samples: 7,
    )
    |> result.map_error(PathError),
  )
  case found_overlaps {
    [_, ..] ->
      Ok(
        found_overlaps
        |> list.flat_map(fn(overlap) {
          let overlaps.SegmentOverlap(
            left_from:,
            left_to:,
            right_from:,
            right_to:,
            ..,
          ) = overlap
          [
            SegmentCut(index: left_index, t: left_from),
            SegmentCut(index: left_index, t: left_to),
            SegmentCut(index: right_index, t: right_from),
            SegmentCut(index: right_index, t: right_to),
          ]
        }),
      )
    [] -> {
      use found <- result.try(
        intersections.segment_with(
          left_segment,
          right_segment,
          options: intersections.default_options(),
        )
        |> result.map_error(PathError),
      )
      Ok(
        found
        |> list.flat_map(fn(hit) {
          let svg_path.SegmentIntersection(left_t:, right_t:, ..) = hit
          [
            SegmentCut(index: left_index, t: left_t),
            SegmentCut(index: right_index, t: right_t),
          ]
        }),
      )
    }
  }
}

fn split_indexed_segments(
  indexed: List(IndexedSegment),
  cuts: List(SegmentCut),
  tolerance: Float,
  minimum_chord: Float,
  pieces: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), Error) {
  case indexed {
    [] -> Ok(list.reverse(pieces))
    [IndexedSegment(index:, segment:), ..rest] -> {
      let parameters =
        [0.0, 1.0, ..cut_parameters(cuts, index, [])]
        |> list.sort(by: float_compare)
        |> distinct_parameters(tolerance, [])
      use split <- result.try(
        svg_path.segment_between_many_inside(segment, between: parameters)
        |> result.map_error(PathError),
      )
      let retained =
        split
        |> list.filter(fn(piece) {
          point.distance(
            svg_path.segment_start(piece),
            svg_path.segment_end(piece),
          )
          >=. minimum_chord
        })
      split_indexed_segments(
        rest,
        cuts,
        tolerance,
        minimum_chord,
        list.append(list.reverse(retained), pieces),
      )
    }
  }
}

fn cut_parameters(
  cuts: List(SegmentCut),
  index: Int,
  parameters: List(Float),
) -> List(Float) {
  case cuts {
    [] -> parameters
    [SegmentCut(index: candidate, t:), ..rest] ->
      cut_parameters(
        rest,
        index,
        case candidate == index && t >. 0.0 && t <. 1.0 {
          True -> [t, ..parameters]
          False -> parameters
        },
      )
  }
}

fn distinct_parameters(
  parameters: List(Float),
  tolerance: Float,
  distinct: List(Float),
) -> List(Float) {
  case parameters, distinct {
    [], _ -> list.reverse(distinct)
    [first, ..rest], [] -> distinct_parameters(rest, tolerance, [first])
    [first, ..rest], [previous, ..] ->
      case first -. previous <=. tolerance {
        True -> distinct_parameters(rest, tolerance, distinct)
        False -> distinct_parameters(rest, tolerance, [first, ..distinct])
      }
  }
}

fn float_compare(left: Float, right: Float) -> order.Order {
  case left <. right {
    True -> order.Lt
    False ->
      case left >. right {
        True -> order.Gt
        False -> order.Eq
      }
  }
}

fn insert_semantic_pieces(
  pieces: List(svg_path.Segment),
  graph: ArrangementGraph,
  tolerance: Float,
  minimum_chord: Float,
) -> Result(ArrangementGraph, Error) {
  case pieces {
    [] -> Ok(graph)
    [first, ..rest] -> {
      use next <- result.try(insert_semantic_piece(
        graph,
        first,
        tolerance,
        minimum_chord,
      ))
      insert_semantic_pieces(rest, next, tolerance, minimum_chord)
    }
  }
}

fn insert_semantic_piece(
  graph: ArrangementGraph,
  segment: svg_path.Segment,
  tolerance: Float,
  minimum_chord: Float,
) -> Result(ArrangementGraph, Error) {
  let ArrangementGraph(edges:, ..) = graph
  use match <- result.try(find_semantic_edge(edges, segment, tolerance))
  case match {
    None -> insert_atomic_segment(graph, segment, tolerance:, minimum_chord:)
    Some(#(edge_id, same_direction)) ->
      Ok(increment_edge_by_id(graph, edge_id, same_direction))
  }
}

fn find_semantic_edge(
  edges: List(ArrangementEdge),
  segment: svg_path.Segment,
  tolerance: Float,
) -> Result(Option(#(Int, Bool)), Error) {
  case edges {
    [] -> Ok(None)
    [ArrangementEdge(id:, segment: existing, ..), ..rest] -> {
      use found <- result.try(
        overlaps.segment_overlaps_by_endpoint_projection_with(
          existing,
          segment,
          tolerance:,
          samples: 7,
        )
        |> result.map_error(PathError),
      )
      case found {
        [overlap] -> {
          let overlaps.SegmentOverlap(
            left_from:,
            left_to:,
            right_from:,
            right_to:,
            ..,
          ) = overlap
          case
            left_from <=. tolerance
            && 1.0 -. left_to <=. tolerance
            && float_absolute(right_from -. right_to) >=. 1.0 -. tolerance
          {
            True -> Ok(Some(#(id, right_to >. right_from)))
            False -> find_semantic_edge(rest, segment, tolerance)
          }
        }
        _ -> find_semantic_edge(rest, segment, tolerance)
      }
    }
  }
}

fn increment_edge_by_id(
  graph: ArrangementGraph,
  edge_id: Int,
  forward: Bool,
) -> ArrangementGraph {
  let ArrangementGraph(vertices:, edges:) = graph
  ArrangementGraph(
    vertices:,
    edges: edges
      |> list.map(fn(edge) {
        let ArrangementEdge(
          id:,
          segment:,
          start_vertex:,
          end_vertex:,
          forward_multiplicity: forward_count,
          reverse_multiplicity: reverse_count,
        ) = edge
        case id == edge_id {
          False -> edge
          True ->
            ArrangementEdge(
              id:,
              segment:,
              start_vertex:,
              end_vertex:,
              forward_multiplicity: case forward {
                True -> forward_count + 1
                False -> forward_count
              },
              reverse_multiplicity: case forward {
                True -> reverse_count
                False -> reverse_count + 1
              },
            )
        }
      }),
  )
}

fn float_absolute(value: Float) -> Float {
  case value <. 0.0 {
    True -> 0.0 -. value
    False -> value
  }
}

fn attach_vertex(
  vertices: List(ArrangementVertex),
  endpoint: svg_path.Point,
  tolerance: Float,
) -> #(List(ArrangementVertex), Int) {
  case best_vertex_attachment(vertices, endpoint, tolerance, None) {
    Some(VertexAttachment(
      vertex: ArrangementVertex(id:, endpoint_samples:, ..),
      center:,
      ..,
    )) -> {
      #(
        replace_vertex(
          vertices,
          ArrangementVertex(id:, point: center, endpoint_samples: [
            endpoint,
            ..endpoint_samples
          ]),
        ),
        id,
      )
    }
    None -> {
      let id = list.length(vertices)
      #(
        list.append(vertices, [
          ArrangementVertex(id:, point: endpoint, endpoint_samples: [endpoint]),
        ]),
        id,
      )
    }
  }
}

fn best_vertex_attachment(
  vertices: List(ArrangementVertex),
  endpoint: svg_path.Point,
  tolerance: Float,
  best: Option(VertexAttachment),
) -> Option(VertexAttachment) {
  case vertices {
    [] -> best
    [first, ..rest] -> {
      let ArrangementVertex(endpoint_samples:, ..) = first
      let assert Ok(smallest_enclosing_circle.EnclosingCircle(
        center:,
        radius_squared:,
      )) = smallest_enclosing_circle.points([endpoint, ..endpoint_samples])
      let candidate = VertexAttachment(vertex: first, center:, radius_squared:)
      let best = case radius_squared <=. tolerance *. tolerance {
        False -> best
        True ->
          case best {
            None -> Some(candidate)
            Some(previous) ->
              case attachment_precedes(candidate, previous) {
                True -> Some(candidate)
                False -> best
              }
          }
      }
      best_vertex_attachment(rest, endpoint, tolerance, best)
    }
  }
}

fn attachment_precedes(
  candidate: VertexAttachment,
  previous: VertexAttachment,
) -> Bool {
  let VertexAttachment(
    vertex: ArrangementVertex(id: candidate_id, ..),
    radius_squared: candidate_radius,
    ..,
  ) = candidate
  let VertexAttachment(
    vertex: ArrangementVertex(id: previous_id, ..),
    radius_squared: previous_radius,
    ..,
  ) = previous
  candidate_radius <. previous_radius
  || { candidate_radius == previous_radius && candidate_id < previous_id }
}

fn replace_vertex(
  vertices: List(ArrangementVertex),
  replacement: ArrangementVertex,
) -> List(ArrangementVertex) {
  let ArrangementVertex(id: wanted, ..) = replacement
  vertices
  |> list.map(fn(vertex) {
    let ArrangementVertex(id:, ..) = vertex
    case id == wanted {
      True -> replacement
      False -> vertex
    }
  })
}

fn insert_or_increment_edge(
  edges: List(ArrangementEdge),
  segment: svg_path.Segment,
  start_id: Int,
  end_id: Int,
) -> List(ArrangementEdge) {
  case increment_matching_edge(edges, segment, start_id, end_id, []) {
    #(True, updated) -> updated
    #(False, _) ->
      list.append(edges, [
        ArrangementEdge(
          id: list.length(edges),
          segment:,
          start_vertex: start_id,
          end_vertex: end_id,
          forward_multiplicity: 1,
          reverse_multiplicity: 0,
        ),
      ])
  }
}

fn increment_matching_edge(
  edges: List(ArrangementEdge),
  segment: svg_path.Segment,
  start_id: Int,
  end_id: Int,
  before: List(ArrangementEdge),
) -> #(Bool, List(ArrangementEdge)) {
  case edges {
    [] -> #(False, list.reverse(before))
    [first, ..rest] -> {
      let ArrangementEdge(
        id:,
        segment: existing,
        start_vertex: existing_start,
        end_vertex: existing_end,
        forward_multiplicity: forward,
        reverse_multiplicity: reverse,
      ) = first
      case
        existing_start == start_id
        && existing_end == end_id
        && existing == segment
      {
        True -> #(
          True,
          list.append(list.reverse(before), [
            ArrangementEdge(
              id:,
              segment: existing,
              start_vertex: existing_start,
              end_vertex: existing_end,
              forward_multiplicity: forward + 1,
              reverse_multiplicity: reverse,
            ),
            ..rest
          ]),
        )
        False ->
          case
            existing_start == end_id
            && existing_end == start_id
            && existing == svg_path.segment_reverse(segment)
          {
            True -> #(
              True,
              list.append(list.reverse(before), [
                ArrangementEdge(
                  id:,
                  segment: existing,
                  start_vertex: existing_start,
                  end_vertex: existing_end,
                  forward_multiplicity: forward,
                  reverse_multiplicity: reverse + 1,
                ),
                ..rest
              ]),
            )
            False ->
              increment_matching_edge(rest, segment, start_id, end_id, [
                first,
                ..before
              ])
          }
      }
    }
  }
}

/// Validate representation invariants that do not require intersection tests.
pub fn validate(
  graph: ArrangementGraph,
  tolerance tolerance: Float,
  minimum_chord minimum_chord: Float,
) -> Result(Nil, Error) {
  let ArrangementGraph(vertices:, edges:) = graph
  use _ <- result.try(validate_edges(edges, vertices, tolerance, minimum_chord))
  validate_vertices(vertices, edges, tolerance)
}

fn validate_edges(
  edges: List(ArrangementEdge),
  vertices: List(ArrangementVertex),
  tolerance: Float,
  minimum_chord: Float,
) -> Result(Nil, Error) {
  case edges {
    [] -> Ok(Nil)
    [
      ArrangementEdge(
        id:,
        segment:,
        start_vertex:,
        end_vertex:,
        forward_multiplicity:,
        reverse_multiplicity:,
      ),
      ..rest
    ] -> {
      case forward_multiplicity + reverse_multiplicity <= 0 {
        True -> Error(InvalidMultiplicity(edge: id))
        False ->
          case start_vertex == end_vertex {
            True -> Error(LoopEdge(vertex: start_vertex))
            False -> {
              use start <- result.try(vertex_point(vertices, start_vertex))
              use end <- result.try(vertex_point(vertices, end_vertex))
              let start_distance =
                point.distance(svg_path.segment_start(segment), start)
              let end_distance =
                point.distance(svg_path.segment_end(segment), end)
              case start_distance >. tolerance {
                True ->
                  Error(EdgeEndpointMismatch(
                    edge: id,
                    vertex: start_vertex,
                    distance: start_distance,
                  ))
                False ->
                  case end_distance >. tolerance {
                    True ->
                      Error(EdgeEndpointMismatch(
                        edge: id,
                        vertex: end_vertex,
                        distance: end_distance,
                      ))
                    False -> {
                      let chord =
                        point.distance(
                          svg_path.segment_start(segment),
                          svg_path.segment_end(segment),
                        )
                      case chord <. minimum_chord {
                        True ->
                          Error(SegmentTooShort(chord:, minimum: minimum_chord))
                        False ->
                          validate_edges(
                            rest,
                            vertices,
                            tolerance,
                            minimum_chord,
                          )
                      }
                    }
                  }
              }
            }
          }
      }
    }
  }
}

fn validate_vertices(
  vertices: List(ArrangementVertex),
  edges: List(ArrangementEdge),
  tolerance: Float,
) -> Result(Nil, Error) {
  case vertices {
    [] -> Ok(Nil)
    [ArrangementVertex(id:, point:, endpoint_samples:), ..rest] -> {
      use _ <- result.try(validate_vertex_samples(
        endpoint_samples,
        point,
        id,
        tolerance *. tolerance,
      ))
      let degree = weighted_degree(edges, id, 0)
      case degree == 0 {
        True -> Error(IsolatedVertex(vertex: id))
        False ->
          case int.modulo(degree, 2) != Ok(0) {
            True -> Error(OddWeightedDegree(vertex: id, degree:))
            False -> validate_vertices(rest, edges, tolerance)
          }
      }
    }
  }
}

fn validate_vertex_samples(
  samples: List(svg_path.Point),
  center: svg_path.Point,
  vertex: Int,
  tolerance_squared: Float,
) -> Result(Nil, Error) {
  case samples {
    [] -> Error(VertexWithoutEndpointSamples(vertex:))
    _ -> {
      let assert Ok(smallest_enclosing_circle.EnclosingCircle(
        center: expected_center,
        radius_squared:,
      )) = smallest_enclosing_circle.points(samples)
      case center == expected_center {
        False ->
          Error(VertexCenterMismatch(
            vertex:,
            distance_squared: point.distance_squared(center, expected_center),
          ))
        True ->
          case radius_squared <=. tolerance_squared {
            False ->
              Error(VertexSampleOutsideTolerance(
                vertex:,
                distance_squared: radius_squared,
                tolerance_squared:,
              ))
            True -> Ok(Nil)
          }
      }
    }
  }
}

fn weighted_degree(
  edges: List(ArrangementEdge),
  vertex: Int,
  total: Int,
) -> Int {
  case edges {
    [] -> total
    [
      ArrangementEdge(
        start_vertex:,
        end_vertex:,
        forward_multiplicity:,
        reverse_multiplicity:,
        ..,
      ),
      ..rest
    ] -> {
      let contribution = case start_vertex == vertex || end_vertex == vertex {
        True -> forward_multiplicity + reverse_multiplicity
        False -> 0
      }
      weighted_degree(rest, vertex, total + contribution)
    }
  }
}

fn vertex_point(
  vertices: List(ArrangementVertex),
  id: Int,
) -> Result(svg_path.Point, Error) {
  case
    list.find(vertices, fn(vertex) {
      let ArrangementVertex(id: candidate, ..) = vertex
      candidate == id
    })
  {
    Ok(ArrangementVertex(point:, ..)) -> Ok(point)
    Error(_) -> Error(MissingVertex(vertex: id))
  }
}

/// Draw edges, clustered vertices, vertex ids, and directional multiplicities.
pub fn drawing(graph: ArrangementGraph) -> svg.ThingsToDraw {
  let ArrangementGraph(vertices:, edges:) = graph
  let edge_things =
    edges
    |> list.flat_map(fn(edge) {
      let ArrangementEdge(
        segment:,
        forward_multiplicity:,
        reverse_multiplicity:,
        ..,
      ) = edge
      let midpoint =
        svg_path.segment_point(segment, at: 0.5)
        |> result.unwrap(svg_path.segment_start(segment))
      let label =
        int.to_string(forward_multiplicity)
        <> "/"
        <> int.to_string(reverse_multiplicity)
      [
        svg.StyledPath(
          svg_path.Path([svg_path.subpath_assert([segment])]),
          "fill: none; stroke: #334155; stroke-width: 1.5",
        ),
        svg.Rectangle(
          svg_path.Point(midpoint.x -. 11.0, midpoint.y -. 7.0),
          22.0,
          14.0,
          "fill: white; stroke: #94a3b8; stroke-width: 0.75",
        ),
        svg.Text(
          label,
          "fill: #0f172a; font-family: monospace; text-anchor: middle; dominant-baseline: central",
          svg_path.Point(midpoint.x, midpoint.y +. 0.5),
          8,
        ),
      ]
    })
  let vertex_things =
    vertices
    |> list.flat_map(fn(vertex) {
      let ArrangementVertex(id:, point:, ..) = vertex
      svg.labeled_point("v" <> int.to_string(id), "#dc2626", point, 8)
    })
  list.append(edge_things, vertex_things)
}

/// Draw an arrangement graph using the shared Boolean-debug style.
///
/// Each tangent-oriented cartouche shows global winding immediately to the
/// left/right of the edge in black, with forward/reverse multiplicity below in
/// red. Red arrowheads show the stored forward direction. Vertices use the
/// established white-circle/red-outline style. Cartouches are sized per edge
/// and never exceed 80% of the chord remaining between its endpoint nodes.
pub fn annotated_drawing(
  graph: ArrangementGraph,
  source: svg_path.Path,
  tolerance tolerance: Float,
) -> Result(svg.ThingsToDraw, Error) {
  let ArrangementGraph(vertices:, edges:) = graph
  use edge_things <- result.try(
    annotated_edge_things(edges, source, tolerance, []),
  )
  let vertex_things =
    vertices
    |> list.map(fn(vertex) {
      let ArrangementVertex(point:, ..) = vertex
      svg.Circle(point, 5.0, "fill: #fff; stroke: #dc2626; stroke-width: 2.25")
    })
  Ok(list.append(edge_things, vertex_things))
}

fn annotated_edge_things(
  edges: List(ArrangementEdge),
  source: svg_path.Path,
  tolerance: Float,
  accumulated: List(svg.ThingsToDraw),
) -> Result(svg.ThingsToDraw, Error) {
  case edges {
    [] -> Ok(list.reverse(accumulated) |> list.flatten)
    [edge, ..rest] -> {
      let ArrangementEdge(
        segment:,
        forward_multiplicity:,
        reverse_multiplicity:,
        ..,
      ) = edge
      use levels <- result.try(
        winding_field.segment_side_nonzero_levels(
          segment,
          within: source,
          tolerance:,
          options: svg_path.default_containment_options(),
        )
        |> result.map_error(PathError),
      )
      use pose <- result.try(
        edge_annotation_pose(edge) |> result.map_error(PathError),
      )
      let #(left_winding, right_winding) = levels
      let EdgeAnnotationPose(point: midpoint, rotation:) = pose
      // SVG's display Y axis is the reflection of the Cartesian Y axis used
      // by the side-level calculation. Swap the textual order so the first
      // number appears on the physical left of the directed edge.
      let winding_label =
        int.to_string(right_winding) <> "/" <> int.to_string(left_winding)
      let multiplicity_label =
        "↑"
        <> int.to_string(forward_multiplicity)
        <> "/"
        <> int.to_string(reverse_multiplicity)
        <> "↓"
      let arrow =
        segment_direction_arrow(segment, "#dc2626")
        |> result.unwrap(svg.StyledPath(svg_path.path_empty(), ""))
      let chord =
        point.distance(
          svg_path.segment_start(segment),
          svg_path.segment_end(segment),
        )
      let usable_chord = chord -. 10.0
      let label_scale = case usable_chord <=. 0.0 {
        True -> 0.0
        False -> float_min(0.5, usable_chord *. 0.8 /. 24.0)
      }
      let label_things = case label_scale <=. 0.0 {
        True -> []
        False -> {
          let width = 34.0 *. label_scale
          let height = 24.0 *. label_scale
          [
            svg.RotatedRectangle(
              svg_path.Point(
                midpoint.x -. width /. 2.0,
                midpoint.y -. height /. 2.0,
              ),
              width,
              height,
              "fill: #fff; stroke: #94a3b8; stroke-width: 0.75",
              rotation:,
              origin: midpoint,
            ),
            svg.RotatedText(
              winding_label,
              "fill: #0f172a; font-family: ui-monospace, monospace; font-weight: 700; text-anchor: middle",
              svg_path.Point(midpoint.x, midpoint.y -. 2.0 *. label_scale),
              scaled_font_size(9.0, label_scale),
              rotation:,
              origin: midpoint,
            ),
            svg.RotatedText(
              multiplicity_label,
              "fill: #dc2626; font-family: ui-monospace, monospace; font-weight: 700; text-anchor: middle",
              svg_path.Point(midpoint.x, midpoint.y +. 9.0 *. label_scale),
              scaled_font_size(8.0, label_scale),
              rotation:,
              origin: midpoint,
            ),
          ]
        }
      }
      let things =
        list.append(
          [
            svg.StyledPath(
              svg_path.Path([svg_path.subpath_assert([segment])]),
              "fill: none; stroke: #334155; stroke-width: 3.25",
            ),
            arrow,
          ],
          label_things,
        )
      annotated_edge_things(rest, source, tolerance, [things, ..accumulated])
    }
  }
}

fn scaled_font_size(base: Float, scale: Float) -> Int {
  let size = float.round(base *. scale)
  case size < 1 {
    True -> 1
    False -> size
  }
}

/// Draw one arrowhead whose tip is the head of a segment.
pub fn segment_direction_arrow(
  segment: svg_path.Segment,
  color: String,
) -> Result(svg.ThingToDraw, Nil) {
  use point <- result.try(
    svg_path.segment_point(segment, at: 1.0) |> result.replace_error(Nil),
  )
  use derivative <- result.try(
    svg_path.segment_derivative(segment, at: 1.0)
    |> result.replace_error(Nil),
  )
  let magnitude =
    float.square_root(
      derivative.x *. derivative.x +. derivative.y *. derivative.y,
    )
    |> result.unwrap(0.0)
  case magnitude <=. 0.000001 {
    True -> Error(Nil)
    False -> {
      let ux = derivative.x /. magnitude
      let uy = derivative.y /. magnitude
      let px = 0.0 -. uy
      let py = ux
      let left =
        svg_path.Point(
          point.x -. ux *. 9.0 +. px *. 3.5,
          point.y -. uy *. 9.0 +. py *. 3.5,
        )
      let right =
        svg_path.Point(
          point.x -. ux *. 9.0 -. px *. 3.5,
          point.y -. uy *. 9.0 -. py *. 3.5,
        )
      Ok(svg.StyledPath(
        svg_path.Path([svg_path.subpath_assert_polygon([point, left, right])]),
        "fill: " <> color <> "; stroke: none",
      ))
    }
  }
}

/// Draw endpoint arrowheads for every segment of a path.
pub fn path_direction_arrows(
  path: svg_path.Path,
  color: String,
) -> svg.ThingsToDraw {
  path
  |> svg_path.path_subpaths
  |> list.flat_map(svg_path.subpath_segments)
  |> list.filter_map(fn(segment) { segment_direction_arrow(segment, color) })
}

/// Return the midpoint and tangent-aligned orientation for an edge annotation.
pub fn edge_annotation_pose(
  edge: ArrangementEdge,
) -> Result(EdgeAnnotationPose, svg_path.Error) {
  let ArrangementEdge(segment:, ..) = edge
  use midpoint <- result.try(svg_path.segment_point(segment, at: 0.5))
  use tangent <- result.try(svg_path.segment_derivative(segment, at: 0.5))
  let tangent_angle = trig.atan2_degrees(tangent.y, tangent.x)
  Ok(EdgeAnnotationPose(point: midpoint, rotation: tangent_angle +. 90.0))
}

fn float_min(a: Float, b: Float) -> Float {
  case a <. b {
    True -> a
    False -> b
  }
}
