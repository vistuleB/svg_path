//// Arrangement-graph primitives for Boolean path operations.
////
//// This module provides arrangement construction, endpoint clustering,
//// coincident-edge multiplicity, validation, Boolean boundary extraction, and
//// diagnostic drawing. `build` nodes intersections and endpoint-bounded
//// overlaps. The lower-level insertion functions require already-noded input.

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
import svg_path/svg
import svg_path/trig
import svg_path/winding_field

pub type ArrangementVertex {
  ArrangementVertex(id: Int, point: svg_path.Point, sample_count: Int)
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
  BoundaryTraceFailed(vertex: Int)
  BoundarySectorMismatch(vertex: Int)
}

type IndexedSegment {
  IndexedSegment(index: Int, segment: svg_path.Segment)
}

type SegmentCut {
  SegmentCut(index: Int, t: Float)
}

type BoundaryEdge {
  BoundaryEdge(
    id: Int,
    layer: Int,
    segment: svg_path.Segment,
    start_vertex: Int,
    end_vertex: Int,
  )
}

type BoundaryLink {
  BoundaryLink(edge_id: Int, successor_id: Int)
}

type BoundaryRay {
  BoundaryRay(edge_id: Int, starts: Bool, angle: Float)
}

type BooleanOperation {
  UnionOperation
  IntersectionOperation
  DifferenceOperation
  SymmetricDifferenceOperation
}

pub fn empty() -> ArrangementGraph {
  ArrangementGraph(vertices: [], edges: [])
}

/// Replace line-degenerate segment sequences before arrangement construction.
pub fn prepare_subpaths(
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

/// Insert one already-noded segment.
///
/// Endpoints within `tolerance` join the same vertex. A structurally identical
/// edge increments its forward multiplicity; its structural reverse increments
/// reverse multiplicity. Other crossings and partial overlaps must have been
/// resolved by a noding layer before calling this function.
pub fn insert_noded_segment(
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

pub fn build_from_noded_subpaths(
  subpaths: List(svg_path.Subpath),
  tolerance tolerance: Float,
  minimum_chord minimum_chord: Float,
) -> Result(ArrangementGraph, Error) {
  subpaths
  |> list.flat_map(svg_path.subpath_segments)
  |> insert_segments(empty(), tolerance, minimum_chord)
}

/// Build an arrangement graph by noding point intersections and
/// endpoint-bounded overlaps.
///
/// This first implementation performs arrangement-wide refinement before
/// insertion. Its output is independent of input processing order. Overlap
/// detection uses endpoint projection, so semantically equal arcs need not
/// have structurally equal SVG flags or matching original subdivision points.
pub fn build(
  subpaths: List(svg_path.Subpath),
  tolerance tolerance: Float,
  minimum_chord minimum_chord: Float,
) -> Result(ArrangementGraph, Error) {
  use cleaned <- result.try(prepare_subpaths(subpaths, tolerance:))
  let indexed =
    cleaned
    |> list.flat_map(svg_path.subpath_segments)
    |> index_segments(0, [])
  use cuts <- result.try(collect_all_cuts(indexed, tolerance, []))
  use pieces <- result.try(
    split_indexed_segments(indexed, cuts, tolerance, minimum_chord, []),
  )
  insert_semantic_pieces(pieces, empty(), tolerance, minimum_chord)
}

/// Compute the Boolean union boundary from an `ArrangementGraph`.
///
/// Winding is evaluated separately against both operands before the common
/// fill rule is applied. Necessary edges are oriented with filled space on the
/// right and consumed into closed cycles.
pub fn union_from_arrangement_graph(
  graph: ArrangementGraph,
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  tolerance tolerance: Float,
) -> Result(svg_path.Path, Error) {
  let ArrangementGraph(edges:, ..) = graph
  use boundary <- result.try(
    classify_boolean_edges(
      edges,
      left,
      right,
      fill_rule,
      UnionOperation,
      tolerance,
      [],
    ),
  )
  use links <- result.try(pair_boundary_sectors(boundary, []))
  use subpaths <- result.try(
    trace_boundary_edges(boundary, links, tolerance, []),
  )
  Ok(svg_path.Path(subpaths))
}

/// Compute the Boolean intersection boundary from an `ArrangementGraph`.
pub fn intersection_from_arrangement_graph(
  graph: ArrangementGraph,
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  tolerance tolerance: Float,
) -> Result(svg_path.Path, Error) {
  let ArrangementGraph(edges:, ..) = graph
  use boundary <- result.try(
    classify_boolean_edges(
      edges,
      left,
      right,
      fill_rule,
      IntersectionOperation,
      tolerance,
      [],
    ),
  )
  use links <- result.try(pair_boundary_sectors(boundary, []))
  use subpaths <- result.try(
    trace_boundary_edges(boundary, links, tolerance, []),
  )
  Ok(svg_path.Path(subpaths))
}

/// Compute the Boolean boundary of `left` minus `right` from an
/// `ArrangementGraph` constructed from both operands.
pub fn difference_from_arrangement_graph(
  graph: ArrangementGraph,
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  tolerance tolerance: Float,
) -> Result(svg_path.Path, Error) {
  let ArrangementGraph(edges:, ..) = graph
  use boundary <- result.try(
    classify_boolean_edges(
      edges,
      left,
      right,
      fill_rule,
      DifferenceOperation,
      tolerance,
      [],
    ),
  )
  use links <- result.try(pair_boundary_sectors(boundary, []))
  use subpaths <- result.try(
    trace_boundary_edges(boundary, links, tolerance, []),
  )
  Ok(svg_path.Path(subpaths))
}

/// Compute the Boolean symmetric-difference boundary from an
/// `ArrangementGraph` constructed from both operands.
pub fn symmetric_difference_from_arrangement_graph(
  graph: ArrangementGraph,
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  tolerance tolerance: Float,
) -> Result(svg_path.Path, Error) {
  let ArrangementGraph(edges:, ..) = graph
  use boundary <- result.try(
    classify_boolean_edges(
      edges,
      left,
      right,
      fill_rule,
      SymmetricDifferenceOperation,
      tolerance,
      [],
    ),
  )
  use links <- result.try(pair_boundary_sectors(boundary, []))
  use subpaths <- result.try(
    trace_boundary_edges(boundary, links, tolerance, []),
  )
  Ok(svg_path.Path(subpaths))
}

/// Reconstruct the signed winding field of `path` as nested or disjoint
/// unit-level contours using an arrangement built from that path.
///
/// Winding-neutral edge multiplicity is omitted. Every retained contour adds
/// either `1` or `-1` to the winding field inside it.
pub fn monotone_contours_from_arrangement_graph(
  graph: ArrangementGraph,
  path: svg_path.Path,
  tolerance tolerance: Float,
) -> Result(svg_path.Path, Error) {
  let ArrangementGraph(edges:, ..) = graph
  use boundary <- result.try(
    classify_winding_level_edges(edges, path, tolerance, 0, []),
  )
  use links <- result.try(pair_boundary_sectors(boundary, []))
  use subpaths <- result.try(
    trace_winding_level_edges(boundary, links, tolerance, []),
  )
  Ok(svg_path.Path(subpaths))
}

/// Build an arrangement graph for two paths and return their Boolean union
/// boundary.
pub fn union(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  tolerance tolerance: Float,
  minimum_chord minimum_chord: Float,
) -> Result(svg_path.Path, Error) {
  use graph <- result.try(build(
    list.append(svg_path.path_subpaths(left), svg_path.path_subpaths(right)),
    tolerance:,
    minimum_chord:,
  ))
  union_from_arrangement_graph(graph, left, right, using: fill_rule, tolerance:)
}

/// Build an arrangement graph for two paths and return their Boolean
/// intersection boundary.
pub fn intersection(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  tolerance tolerance: Float,
  minimum_chord minimum_chord: Float,
) -> Result(svg_path.Path, Error) {
  use graph <- result.try(build(
    list.append(svg_path.path_subpaths(left), svg_path.path_subpaths(right)),
    tolerance:,
    minimum_chord:,
  ))
  intersection_from_arrangement_graph(
    graph,
    left,
    right,
    using: fill_rule,
    tolerance:,
  )
}

/// Build an arrangement graph for two paths and return `left` minus `right`.
pub fn difference(
  left: svg_path.Path,
  minus right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  tolerance tolerance: Float,
  minimum_chord minimum_chord: Float,
) -> Result(svg_path.Path, Error) {
  use graph <- result.try(build(
    list.append(svg_path.path_subpaths(left), svg_path.path_subpaths(right)),
    tolerance:,
    minimum_chord:,
  ))
  difference_from_arrangement_graph(
    graph,
    left,
    right,
    using: fill_rule,
    tolerance:,
  )
}

/// Build an arrangement graph for two paths and return their Boolean symmetric
/// difference.
pub fn symmetric_difference(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  tolerance tolerance: Float,
  minimum_chord minimum_chord: Float,
) -> Result(svg_path.Path, Error) {
  use graph <- result.try(build(
    list.append(svg_path.path_subpaths(left), svg_path.path_subpaths(right)),
    tolerance:,
    minimum_chord:,
  ))
  symmetric_difference_from_arrangement_graph(
    graph,
    left,
    right,
    using: fill_rule,
    tolerance:,
  )
}

/// Return nested or disjoint unit-level contours with the same signed winding
/// field as `path`.
pub fn monotone_contours(
  path: svg_path.Path,
  tolerance tolerance: Float,
  minimum_chord minimum_chord: Float,
) -> Result(svg_path.Path, Error) {
  use graph <- result.try(build(
    svg_path.path_subpaths(path),
    tolerance:,
    minimum_chord:,
  ))
  monotone_contours_from_arrangement_graph(graph, path, tolerance:)
}

fn classify_boolean_edges(
  edges: List(ArrangementEdge),
  left_path: svg_path.Path,
  right_path: svg_path.Path,
  fill_rule: svg_path.FillRule,
  operation: BooleanOperation,
  tolerance: Float,
  boundary: List(BoundaryEdge),
) -> Result(List(BoundaryEdge), Error) {
  case edges {
    [] -> Ok(list.reverse(boundary))
    [ArrangementEdge(id:, segment:, start_vertex:, end_vertex:, ..), ..rest] -> {
      use left_levels <- result.try(
        winding_field.segment_side_nonzero_levels(
          segment,
          within: left_path,
          tolerance:,
          options: svg_path.default_containment_options(),
        )
        |> result.map_error(PathError),
      )
      use right_levels <- result.try(
        winding_field.segment_side_nonzero_levels(
          segment,
          within: right_path,
          tolerance:,
          options: svg_path.default_containment_options(),
        )
        |> result.map_error(PathError),
      )
      let #(left_a, right_a) = left_levels
      let #(left_b, right_b) = right_levels
      let filled_left =
        combine_filled(
          winding_filled(left_a, fill_rule),
          winding_filled(left_b, fill_rule),
          operation,
        )
      let filled_right =
        combine_filled(
          winding_filled(right_a, fill_rule),
          winding_filled(right_b, fill_rule),
          operation,
        )
      let boundary = case filled_left, filled_right {
        False, True -> [
          BoundaryEdge(id:, layer: 0, segment:, start_vertex:, end_vertex:),
          ..boundary
        ]
        True, False -> [
          BoundaryEdge(
            id:,
            layer: 0,
            segment: svg_path.segment_reverse(segment),
            start_vertex: end_vertex,
            end_vertex: start_vertex,
          ),
          ..boundary
        ]
        _, _ -> boundary
      }
      classify_boolean_edges(
        rest,
        left_path,
        right_path,
        fill_rule,
        operation,
        tolerance,
        boundary,
      )
    }
  }
}

fn classify_winding_level_edges(
  edges: List(ArrangementEdge),
  path: svg_path.Path,
  tolerance: Float,
  next_id: Int,
  boundary: List(BoundaryEdge),
) -> Result(List(BoundaryEdge), Error) {
  case edges {
    [] -> Ok(list.reverse(boundary))
    [edge, ..rest] -> {
      let ArrangementEdge(segment:, ..) = edge
      use levels <- result.try(
        winding_field.segment_side_nonzero_levels(
          segment,
          within: path,
          tolerance:,
          options: svg_path.default_containment_options(),
        )
        |> result.map_error(PathError),
      )
      let #(left, right) = levels
      let #(next_id, boundary) =
        emit_winding_thresholds(edge, left, right, 1, next_id, boundary)
      classify_winding_level_edges(rest, path, tolerance, next_id, boundary)
    }
  }
}

fn emit_winding_thresholds(
  edge: ArrangementEdge,
  left: Int,
  right: Int,
  level: Int,
  next_id: Int,
  boundary: List(BoundaryEdge),
) -> #(Int, List(BoundaryEdge)) {
  let maximum = int_max(int.absolute_value(left), int.absolute_value(right))
  case level > maximum {
    True -> #(next_id, boundary)
    False -> {
      let #(next_id, boundary) =
        emit_threshold_boundary(
          edge,
          left >= level,
          right >= level,
          level,
          next_id,
          boundary,
        )
      let #(next_id, boundary) =
        emit_threshold_boundary(
          edge,
          left <= 0 - level,
          right <= 0 - level,
          0 - level,
          next_id,
          boundary,
        )
      emit_winding_thresholds(edge, left, right, level + 1, next_id, boundary)
    }
  }
}

fn emit_threshold_boundary(
  edge: ArrangementEdge,
  active_left: Bool,
  active_right: Bool,
  layer: Int,
  next_id: Int,
  boundary: List(BoundaryEdge),
) -> #(Int, List(BoundaryEdge)) {
  let ArrangementEdge(segment:, start_vertex:, end_vertex:, ..) = edge
  case active_left, active_right {
    False, True -> #(next_id + 1, [
      BoundaryEdge(id: next_id, layer:, segment:, start_vertex:, end_vertex:),
      ..boundary
    ])
    True, False -> #(next_id + 1, [
      BoundaryEdge(
        id: next_id,
        layer:,
        segment: svg_path.segment_reverse(segment),
        start_vertex: end_vertex,
        end_vertex: start_vertex,
      ),
      ..boundary
    ])
    _, _ -> #(next_id, boundary)
  }
}

fn combine_filled(
  left: Bool,
  right: Bool,
  operation: BooleanOperation,
) -> Bool {
  case operation {
    UnionOperation -> left || right
    IntersectionOperation -> left && right
    DifferenceOperation -> left && !right
    SymmetricDifferenceOperation -> left != right
  }
}

fn winding_filled(winding: Int, fill_rule: svg_path.FillRule) -> Bool {
  case fill_rule {
    svg_path.Nonzero -> winding != 0
    svg_path.EvenOdd ->
      case int.remainder(winding, by: 2) {
        Ok(0) -> False
        _ -> True
      }
  }
}

fn pair_boundary_sectors(
  edges: List(BoundaryEdge),
  links: List(BoundaryLink),
) -> Result(List(BoundaryLink), Error) {
  pair_boundary_sectors_loop(edges, edges, links)
}

fn pair_boundary_sectors_loop(
  unpaired: List(BoundaryEdge),
  all_edges: List(BoundaryEdge),
  links: List(BoundaryLink),
) -> Result(List(BoundaryLink), Error) {
  case unpaired {
    [] -> Ok(list.reverse(links))
    [BoundaryEdge(id:, layer:, end_vertex:, ..), ..rest] -> {
      use successor <- result.try(filled_sector_successor(
        all_edges,
        id,
        end_vertex,
        layer,
      ))
      pair_boundary_sectors_loop(rest, all_edges, [
        BoundaryLink(edge_id: id, successor_id: successor),
        ..links
      ])
    }
  }
}

fn filled_sector_successor(
  edges: List(BoundaryEdge),
  incoming_id: Int,
  vertex: Int,
  layer: Int,
) -> Result(Int, Error) {
  use rays <- result.try(collect_boundary_rays(edges, vertex, layer, []))
  let ordered = rays |> list.sort(by: compare_boundary_rays)
  use successor <- result.try(cyclic_successor(
    ordered,
    incoming_id,
    first: list.first(ordered),
    vertex:,
  ))
  let BoundaryRay(edge_id:, starts:, ..) = successor
  case starts {
    True -> Ok(edge_id)
    False -> Error(BoundarySectorMismatch(vertex:))
  }
}

fn collect_boundary_rays(
  edges: List(BoundaryEdge),
  vertex: Int,
  layer: Int,
  rays: List(BoundaryRay),
) -> Result(List(BoundaryRay), Error) {
  case edges {
    [] -> Ok(rays)
    [
      BoundaryEdge(id:, layer: edge_layer, segment:, start_vertex:, end_vertex:),
      ..rest
    ] -> {
      use rays <- result.try(
        case edge_layer == layer && start_vertex == vertex {
          False -> Ok(rays)
          True -> {
            use derivative <- result.try(
              svg_path.segment_derivative(segment, at: 0.0)
              |> result.map_error(PathError),
            )
            Ok([
              BoundaryRay(
                edge_id: id,
                starts: True,
                angle: normalized_angle(trig.atan2_degrees(
                  derivative.y,
                  derivative.x,
                )),
              ),
              ..rays
            ])
          }
        },
      )
      use rays <- result.try(case edge_layer == layer && end_vertex == vertex {
        False -> Ok(rays)
        True -> {
          use derivative <- result.try(
            svg_path.segment_derivative(segment, at: 1.0)
            |> result.map_error(PathError),
          )
          Ok([
            BoundaryRay(
              edge_id: id,
              starts: False,
              angle: normalized_angle(trig.atan2_degrees(
                0.0 -. derivative.y,
                0.0 -. derivative.x,
              )),
            ),
            ..rays
          ])
        }
      })
      collect_boundary_rays(rest, vertex, layer, rays)
    }
  }
}

fn normalized_angle(angle: Float) -> Float {
  case angle <. 0.0 {
    True -> angle +. 360.0
    False -> angle
  }
}

fn compare_boundary_rays(left: BoundaryRay, right: BoundaryRay) -> order.Order {
  let BoundaryRay(angle: left_angle, ..) = left
  let BoundaryRay(angle: right_angle, ..) = right
  float_compare(left_angle, right_angle)
}

fn cyclic_successor(
  rays: List(BoundaryRay),
  incoming_id: Int,
  first first_ray: Result(BoundaryRay, Nil),
  vertex vertex: Int,
) -> Result(BoundaryRay, Error) {
  case rays {
    [] -> Error(BoundarySectorMismatch(vertex:))
    [first, ..rest] -> {
      let BoundaryRay(edge_id:, starts:, ..) = first
      case edge_id == incoming_id && !starts {
        True ->
          case rest {
            [next, ..] -> Ok(next)
            [] ->
              first_ray
              |> result.map_error(fn(_) { BoundarySectorMismatch(vertex:) })
          }
        False -> cyclic_successor(rest, incoming_id, first: first_ray, vertex:)
      }
    }
  }
}

fn trace_boundary_edges(
  remaining: List(BoundaryEdge),
  links: List(BoundaryLink),
  tolerance: Float,
  subpaths: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case remaining {
    [] -> Ok(list.reverse(subpaths))
    [seed, ..rest] -> {
      use traced <- result.try(trace_boundary_cycle(
        seed,
        rest,
        links,
        [seed],
        list.length(remaining) + 1,
      ))
      let #(cycle, remaining) = traced
      use subpath <- result.try(
        cycle
        |> list.map(fn(edge) {
          let BoundaryEdge(segment:, ..) = edge
          segment
        })
        |> svg_path.subpath_with(policy: svg_path.WiggleWith(tolerance))
        |> result.map_error(PathError),
      )
      use closed <- result.try(
        svg_path.subpath_set_closed_with(
          subpath,
          closed: True,
          policy: svg_path.WiggleWith(tolerance),
        )
        |> result.map_error(PathError),
      )
      trace_boundary_edges(remaining, links, tolerance, [closed, ..subpaths])
    }
  }
}

fn trace_winding_level_edges(
  remaining: List(BoundaryEdge),
  links: List(BoundaryLink),
  tolerance: Float,
  subpaths: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case remaining {
    [] -> Ok(list.reverse(subpaths))
    [seed, ..rest] -> {
      let BoundaryEdge(layer:, ..) = seed
      use traced <- result.try(trace_boundary_cycle(
        seed,
        rest,
        links,
        [seed],
        list.length(remaining) + 1,
      ))
      let #(cycle, remaining) = traced
      use subpath <- result.try(
        cycle
        |> list.map(fn(edge) {
          let BoundaryEdge(segment:, ..) = edge
          segment
        })
        |> svg_path.subpath_with(policy: svg_path.WiggleWith(tolerance))
        |> result.map_error(PathError),
      )
      use closed <- result.try(
        svg_path.subpath_set_closed_with(
          subpath,
          closed: True,
          policy: svg_path.WiggleWith(tolerance),
        )
        |> result.map_error(PathError),
      )
      let oriented = case layer > 0 {
        True -> svg_path.subpath_reverse(closed)
        False -> closed
      }
      trace_winding_level_edges(remaining, links, tolerance, [
        oriented,
        ..subpaths
      ])
    }
  }
}

fn trace_boundary_cycle(
  seed: BoundaryEdge,
  remaining: List(BoundaryEdge),
  links: List(BoundaryLink),
  reversed_cycle: List(BoundaryEdge),
  limit: Int,
) -> Result(#(List(BoundaryEdge), List(BoundaryEdge)), Error) {
  let BoundaryEdge(id: seed_id, ..) = seed
  let assert [current, ..] = reversed_cycle
  let BoundaryEdge(id: current_id, end_vertex:, ..) = current
  use successor_id <- result.try(boundary_successor(
    links,
    current_id,
    end_vertex,
  ))
  case successor_id == seed_id {
    True -> Ok(#(list.reverse(reversed_cycle), remaining))
    False ->
      case limit <= 0 {
        True -> Error(BoundaryTraceFailed(vertex: end_vertex))
        False -> {
          use selected <- result.try(
            take_boundary_edge(remaining, successor_id, end_vertex, []),
          )
          let #(next, rest) = selected
          trace_boundary_cycle(
            seed,
            rest,
            links,
            [next, ..reversed_cycle],
            limit - 1,
          )
        }
      }
  }
}

fn boundary_successor(
  links: List(BoundaryLink),
  edge_id: Int,
  vertex: Int,
) -> Result(Int, Error) {
  case links {
    [] -> Error(BoundaryTraceFailed(vertex:))
    [BoundaryLink(edge_id: candidate, successor_id:), ..rest] ->
      case candidate == edge_id {
        True -> Ok(successor_id)
        False -> boundary_successor(rest, edge_id, vertex)
      }
  }
}

fn take_boundary_edge(
  edges: List(BoundaryEdge),
  id: Int,
  vertex: Int,
  retained: List(BoundaryEdge),
) -> Result(#(BoundaryEdge, List(BoundaryEdge)), Error) {
  case edges {
    [] -> Error(BoundaryTraceFailed(vertex:))
    [first, ..rest] -> {
      let BoundaryEdge(id: candidate, ..) = first
      case candidate == id {
        True -> Ok(#(first, list.append(list.reverse(retained), rest)))
        False -> take_boundary_edge(rest, id, vertex, [first, ..retained])
      }
    }
  }
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
    None -> insert_noded_segment(graph, segment, tolerance:, minimum_chord:)
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

fn insert_segments(
  segments: List(svg_path.Segment),
  graph: ArrangementGraph,
  tolerance: Float,
  minimum_chord: Float,
) -> Result(ArrangementGraph, Error) {
  case segments {
    [] -> Ok(graph)
    [first, ..rest] -> {
      use next <- result.try(insert_noded_segment(
        graph,
        first,
        tolerance:,
        minimum_chord:,
      ))
      insert_segments(rest, next, tolerance, minimum_chord)
    }
  }
}

fn attach_vertex(
  vertices: List(ArrangementVertex),
  endpoint: svg_path.Point,
  tolerance: Float,
) -> #(List(ArrangementVertex), Int) {
  case nearest_vertex(vertices, endpoint, tolerance, None) {
    Some(ArrangementVertex(id:, point: existing, sample_count: count)) -> {
      let count_float = int.to_float(count)
      let next_count = count + 1
      let averaged =
        svg_path.Point(
          x: { existing.x *. count_float +. endpoint.x }
            /. int.to_float(next_count),
          y: { existing.y *. count_float +. endpoint.y }
            /. int.to_float(next_count),
        )
      #(
        replace_vertex(
          vertices,
          ArrangementVertex(id:, point: averaged, sample_count: next_count),
        ),
        id,
      )
    }
    None -> {
      let id = list.length(vertices)
      #(
        list.append(vertices, [
          ArrangementVertex(id:, point: endpoint, sample_count: 1),
        ]),
        id,
      )
    }
  }
}

fn nearest_vertex(
  vertices: List(ArrangementVertex),
  endpoint: svg_path.Point,
  tolerance: Float,
  nearest: Option(ArrangementVertex),
) -> Option(ArrangementVertex) {
  case vertices {
    [] -> nearest
    [first, ..rest] -> {
      let ArrangementVertex(point: candidate, ..) = first
      let nearest = case point.distance(candidate, endpoint) <=. tolerance {
        False -> nearest
        True ->
          case nearest {
            None -> Some(first)
            Some(previous) -> {
              let ArrangementVertex(point: previous_point, ..) = previous
              case
                point.distance(candidate, endpoint)
                <. point.distance(previous_point, endpoint)
              {
                True -> Some(first)
                False -> nearest
              }
            }
          }
      }
      nearest_vertex(rest, endpoint, tolerance, nearest)
    }
  }
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
  validate_vertices(vertices, edges)
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
) -> Result(Nil, Error) {
  case vertices {
    [] -> Ok(Nil)
    [ArrangementVertex(id:, ..), ..rest] -> {
      let degree = weighted_degree(edges, id, 0)
      case degree == 0 {
        True -> Error(IsolatedVertex(vertex: id))
        False ->
          case int.modulo(degree, 2) != Ok(0) {
            True -> Error(OddWeightedDegree(vertex: id, degree:))
            False -> validate_vertices(rest, edges)
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

/// Draw edges, averaged vertices, vertex ids, and directional multiplicities.
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

fn int_max(a: Int, b: Int) -> Int {
  case a > b {
    True -> a
    False -> b
  }
}
