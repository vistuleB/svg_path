//// Arrangement-graph primitives for Boolean path operations.
////
//// This module provides arrangement construction, endpoint clustering,
//// coincident-edge multiplicity, and invariant validation. `build` refines
//// intersections and endpoint-bounded overlaps into atomic segments before
//// inserting them as graph edges.
////
//// An atomic segment has no proper intersection or partial overlap with any
//// other edge segment. Atomic segments may meet at their endpoint vertices.
//// Geometrically coincident atomic segments are represented by one edge with
//// directional multiplicities.
////
//// The public types are transparent so callers can inspect, serialize, and
//// draw an arrangement. `build` is the supported constructor: code that
//// assembles these representations directly is responsible for all documented
//// invariants.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import svg_path
import svg_path/area
import svg_path/internal/number
import svg_path/intersections
import svg_path/overlaps
import svg_path/point
import svg_path/smallest_enclosing_circle
import svg_path/winding_field

const cyclic_order_max_attempts = 3

const cyclic_order_minimum_angle_degrees = 0.1

/// One endpoint cluster in the embedded arrangement.
///
/// `point` is the center of the smallest circle enclosing `endpoint_samples`.
/// Construction accepts a sample only when that circle's squared radius does
/// not exceed the graph's squared endpoint tolerance. Consequently every
/// sample lies within `tolerance` of `point`, without making the result depend
/// on endpoint insertion order.
pub type ArrangementVertex {
  ArrangementVertex(
    /// The vertex identifier referenced by incident edges.
    id: Int,
    /// The representative location of this endpoint cluster.
    point: svg_path.Point,
    /// The original segment endpoints assigned to this cluster.
    endpoint_samples: List(svg_path.Point),
  )
}

/// One directed geometric edge of an arrangement.
///
/// The stored segment runs from `start_vertex` to `end_vertex`. Its endpoints
/// remain the source endpoints and are within the build tolerance
/// of the corresponding vertex points; construction does not move the segment
/// to the cluster centers. The segment's chord is at least `minimum_chord`.
///
/// `forward_multiplicity` counts coincident source segments oriented like the
/// stored segment, and `reverse_multiplicity` counts those oriented against it.
/// Both are non-negative and their sum is positive in a constructed graph.
pub type ArrangementEdge {
  ArrangementEdge(
    /// The edge's unique identifier in a graph returned by `build`.
    id: Int,
    /// The atomic segment, oriented from `start_vertex` to `end_vertex`.
    segment: svg_path.Segment,
    /// Exact axis-aligned bounding box of `segment`.
    bounds: svg_path.BoundingBox,
    /// Identifier of the segment's start endpoint cluster.
    start_vertex: Int,
    /// Identifier of the segment's end endpoint cluster.
    end_vertex: Int,
    /// Number of coincident source segments with the stored orientation.
    forward_multiplicity: Int,
    /// Number of coincident source segments with the reverse orientation.
    reverse_multiplicity: Int,
  )
}

/// One arrangement edge with an outward orientation from an incident vertex.
///
/// `reversed` is false when the oriented edge follows the stored edge direction
/// and true when it opposes it.
@internal
pub type OrientedArrangementEdge {
  OrientedArrangementEdge(edge_id: Int, reversed: Bool)
}

/// A possibly disconnected planar arrangement of source path segments.
///
/// Graphs returned by `build` have unique vertex and edge identifiers. Every
/// edge refers to two existing, distinct vertices, and every vertex is incident
/// to an edge. Different atomic edges have no proper intersections or partial
/// overlaps; they meet only through endpoint clusters. Coincident pieces are
/// consolidated into one edge with directional multiplicities.
///
/// `cyclic_orders` records every incident oriented edge in clockwise SVG order
/// at each vertex. Each edge is directed outward from its vertex. The outer
/// list gives the certified clockwise order of groups. Oriented edges within one
/// group could not be separated by the configured geometric tests; their
/// order is a deterministic best-effort majority order across sampled radii.
/// For closed-boundary input, the sum of incident edge multiplicities at every
/// vertex is positive and even. `validate` enforces this closed-boundary
/// condition, so an arrangement built from open subpaths may be inspectable but
/// fail validation.
pub type ArrangementGraph {
  ArrangementGraph(
    /// Endpoint clusters in the arrangement.
    vertices: List(ArrangementVertex),
    /// Non-intersecting atomic edges in the arrangement.
    edges: List(ArrangementEdge),
    /// Clockwise incident oriented-edge order for every vertex.
    cyclic_orders: List(#(Int, List(List(OrientedArrangementEdge)))),
  )
}

/// Undirected edge capacity produced by forced parity pruning.
@internal
pub type EdgeCapacityAssignment {
  EdgeCapacityAssignment(edge_id: Int, capacity: Int)
}

/// A requested parity for the total capacity incident to one vertex.
///
/// A required request remains an invariant even when incident capacity reaches
/// zero. A preferred request participates in the same forced reductions while
/// positive capacity remains, but permits the vertex to become isolated.
@internal
pub type VertexParityRequest {
  RequiredVertexParity(vertex: Int, parity: Int)
  PreferredVertexParity(vertex: Int, parity: Int)
}

/// Failure of forced parity pruning.
@internal
pub type ForcedParityError {
  ForcedParityMissingVertex(vertex: Int)
  ForcedParityDuplicateVertex(vertex: Int)
  ForcedParityInvalidVertexParity(vertex: Int, parity: Int)
  ForcedParityMissingEdgeCapacity(edge_id: Int)
  ForcedParityDuplicateEdgeCapacity(edge_id: Int)
  ForcedParityUnknownEdgeCapacity(edge_id: Int)
  ForcedParityInvalidEdgeCapacity(edge_id: Int, capacity: Int)
  ForcedParityInfeasible(vertex: Int)
  ForcedParityAmbiguous(vertices: List(Int))
}

type VertexParityState {
  VertexParityState(
    vertex: Int,
    parity: Int,
    preferred: Bool,
    incident_capacity: Int,
    positive_edges: List(Int),
  )
}

/// The planar dual derived from an `ArrangementGraph`.
///
/// `faces` contains exactly one infinite face, identified by `outer: True`,
/// and that face is first. `edge_faces` records the faces on the visual left
/// and right of every stored arrangement-edge direction.
pub type DualArrangementGraph {
  DualArrangementGraph(
    faces: List(ArrangementFace),
    edge_faces: List(ArrangementEdgeFaces),
  )
}

/// One connected open region of the plane complementary to an arrangement.
///
/// `outer` is true only for the infinite face. For a bounded face, the first
/// walk is its enclosing outer walk and any remaining walks surround islands.
/// The infinite face has no enclosing outer walk, so all of its walks have
/// `outer: False`.
pub type ArrangementFace {
  ArrangementFace(id: Int, outer: Bool, walks: List(ArrangementFaceWalk))
}

/// One connected boundary component of an arrangement face.
///
/// `outer` identifies the enclosing boundary of a bounded face. Such a walk is
/// always first in its face's walk list. Every edge is traversed with the face
/// on its visual left.
pub type ArrangementFaceWalk {
  ArrangementFaceWalk(outer: Bool, edges: List(ArrangementFaceEdge))
}

/// One arrangement edge used by a face boundary walk.
///
/// `left` is true when the face lies on the visual left of the edge's stored
/// direction. A face walk follows the stored direction when `left` is true and
/// reverses it otherwise.
pub type ArrangementFaceEdge {
  ArrangementFaceEdge(edge_id: Int, left: Bool)
}

/// The two dual faces incident to one arrangement edge.
///
/// A bridge has the same face on both sides.
pub type ArrangementEdgeFaces {
  ArrangementEdgeFaces(edge_id: Int, left_face: Int, right_face: Int)
}

/// An arrangement graph and source-segment images for the paths from which it
/// was constructed.
///
/// `segment_images` has one entry for every input segment, in path, subpath,
/// and segment order. Each image lists the atomic graph edges in that segment's
/// traversal order. A reference's `reversed` flag is true when that traversal
/// opposes the edge's stored direction. An image can be empty when every
/// refined piece is shorter than `minimum_chord`.
pub type ArrangementGraphBuild {
  ArrangementGraphBuild(
    /// The arrangement produced from the input paths.
    graph: ArrangementGraph,
    /// Ordered graph-edge images of every source segment.
    segment_images: List(ArrangementSegmentImage),
  )
}

/// One atomic graph edge in the image of one input segment.
///
/// `ta` and `tb` are parameters on the input segment. `reversed` records
/// whether the input traversal opposes the stored graph edge orientation.
/// `own` is true for the first input segment occurrence assigned to the edge.
pub type ArrangementSegmentEdgeImage {
  ArrangementSegmentEdgeImage(
    ta: Float,
    tb: Float,
    edge_id: Int,
    reversed: Bool,
    own: Bool,
  )
}

/// The ordered atomic graph-edge image of one input segment.
pub type ArrangementSourceSegmentImage {
  ArrangementSourceSegmentImage(
    segment_index: Int,
    edges: List(ArrangementSegmentEdgeImage),
  )
}

/// One input segment occurrence corresponding to an arrangement edge.
///
/// `ta <= tb` are parameters on the input segment. `reversed` records whether
/// the input segment traversal opposes the stored graph edge orientation.
pub type ArrangementEdgeSourceImage {
  ArrangementEdgeSourceImage(
    segment_index: Int,
    ta: Float,
    tb: Float,
    reversed: Bool,
  )
}

/// The input-segment occurrences corresponding to one arrangement edge.
///
/// The first source is the first occurrence found in source order and is the
/// provisional owner used by `ArrangementSegmentEdgeImage.own`.
pub type ArrangementEdgeImage {
  ArrangementEdgeImage(edge_id: Int, sources: List(ArrangementEdgeSourceImage))
}

/// Arrangement graph build result for direct segment-list construction.
///
/// This path does not normalize or rewrite caller input before construction.
pub type ArrangementSegmentBuild {
  ArrangementSegmentBuild(
    graph: ArrangementGraph,
    segments: List(svg_path.Segment),
    segment_images: List(ArrangementSourceSegmentImage),
    edge_images: List(ArrangementEdgeImage),
  )
}

/// One graph edge traversed as part of a source segment.
///
/// `edge_id` identifies an edge in the containing build's graph. `reversed`
/// records whether the source traversal opposes that edge's stored segment.
pub type DirectedEdgeReference {
  DirectedEdgeReference(edge_id: Int, reversed: Bool)
}

/// The ordered atomic graph edges produced from one source segment.
///
/// The three indices address the segment in the original input paths.
pub type ArrangementSegmentImage {
  ArrangementSegmentImage(
    path_index: Int,
    subpath_index: Int,
    segment_index: Int,
    edges: List(DirectedEdgeReference),
  )
}

/// Errors returned while constructing or validating an arrangement graph.
///
/// The numeric-option variants report invalid caller options. The remaining
/// variants report a path failure or a violated graph invariant.
pub type Error {
  /// An underlying path operation failed.
  PathError(svg_path.Error)

  /// Normalization failed for a reason outside its path-operation contract.
  InternalNormalizationError

  /// Endpoint tolerance must be greater than zero.
  InvalidTolerance(tolerance: Float)

  /// Minimum edge chord length must be greater than zero.
  InvalidMinimumChord(minimum_chord: Float)

  /// Endpoint-sliver tolerance is a parameter-space quantity and must be
  /// finite and non-negative.
  InvalidEndpointSliverTolerance(tolerance: Float)

  /// A segment is shorter than the required minimum chord length.
  SegmentTooShort(chord: Float, minimum: Float)

  /// Endpoint clustering collapsed an inserted segment to one vertex.
  SegmentCollapsedToVertex(vertex: Int)

  /// A graph edge refers to the same vertex at both ends.
  LoopEdge(vertex: Int)

  /// An edge refers to a vertex that is not in the graph.
  MissingVertex(vertex: Int)

  /// A segment image refers to an edge that is not in its build graph.
  MissingEdge(edge: Int)

  /// A vertex has no incident edge.
  IsolatedVertex(vertex: Int)

  /// An edge's total directional multiplicity is not positive.
  InvalidMultiplicity(edge: Int)

  /// A closed-boundary graph has an odd weighted degree at a vertex.
  OddWeightedDegree(vertex: Int, degree: Int)

  /// A segment endpoint is farther than tolerance from its vertex point.
  EdgeEndpointMismatch(edge: Int, vertex: Int, distance: Float)

  /// A vertex does not retain any source endpoints for its cluster.
  VertexWithoutEndpointSamples(vertex: Int)

  /// A vertex point is not the canonical center of its endpoint samples.
  VertexCenterMismatch(vertex: Int, distance_squared: Float)

  /// A vertex's endpoint cluster exceeds the graph tolerance.
  VertexSampleOutsideTolerance(
    vertex: Int,
    distance_squared: Float,
    tolerance_squared: Float,
  )

  /// A contour could not be traced into closed loops.
  ContourTraceFailed(vertex: Int)

  /// A cyclic edge order was requested for a vertex outside the graph.
  CyclicOrderMissingVertex(vertex: Int)

  /// No positive common sampling radius exists at a vertex.
  CyclicOrderRadiusUnavailable(vertex: Int)

  /// A cyclic-order search requires at least one sampling radius.
  InvalidCyclicOrderAttempts(max_attempts: Int)

  /// An incident edge did not yield a certified first circle intersection.
  CyclicOrderCircleIntersectionFailed(vertex: Int, edge: Int, radius: Float)

  /// A dual walk could not find the cyclic order at its arrival vertex.
  DualMissingCyclicOrder(vertex: Int)

  /// A dual walk could not find its incoming edge in a vertex's cyclic order.
  DualMissingIncidentEdge(vertex: Int, edge: Int)

  /// A dual walk repeated an edge side before returning to its start.
  DualWalkDidNotClose(edge: Int, left: Bool)

  /// A face boundary could not provide a non-boundary point on its left side.
  DualFaceSampleUnavailable(edge: Int, left: Bool)

  /// A bounded face did not have exactly one enclosing outer walk.
  DualInvalidOuterWalkCount(count: Int)

  /// An arrangement edge side was absent from the derived faces.
  DualMissingEdgeFace(edge: Int, left: Bool)

  /// Dual construction did not identify exactly one infinite face.
  DualInvalidOuterFaceCount(count: Int)
}

type CyclicOrderSample {
  CyclicOrderSample(
    oriented_edge: OrientedArrangementEdge,
    point: svg_path.Point,
    angle: Float,
  )
}

/// Compute clockwise cyclic oriented-edge orders without modifying the graph.
///
/// This is an experimental embedding helper. At each vertex it samples every
/// incident edge on a common circle, beginning at `0.8` times the least
/// opposite-endpoint distance and continuing at `0.8` times the previous
/// radius, up to `max_attempts` total radii. The largest successful radius
/// determines certified group boundaries. All successful radii vote on the
/// best-effort order within each uncertified group.
@internal
pub fn cyclic_orders_with(
  graph: ArrangementGraph,
  tolerance tolerance: Float,
  max_attempts max_attempts: Int,
) -> Result(List(#(Int, List(List(OrientedArrangementEdge)))), Error) {
  case tolerance >. 0.0 && number.is_finite(tolerance), max_attempts > 0 {
    False, _ -> Error(InvalidTolerance(tolerance))
    _, False -> Error(InvalidCyclicOrderAttempts(max_attempts))
    True, True -> {
      let ArrangementGraph(vertices:, ..) = graph
      cyclic_orders_for_vertices(
        vertices,
        graph,
        tolerance,
        max_attempts,
        orders: [],
      )
    }
  }
}

fn cyclic_orders_for_vertices(
  vertices: List(ArrangementVertex),
  graph: ArrangementGraph,
  tolerance: Float,
  max_attempts: Int,
  orders orders: List(#(Int, List(List(OrientedArrangementEdge)))),
) -> Result(List(#(Int, List(List(OrientedArrangementEdge)))), Error) {
  case vertices {
    [] -> Ok(list.reverse(orders))
    [ArrangementVertex(id:, ..), ..rest] -> {
      use cyclic_order <- result.try(vertex_cyclic_order_with(
        graph,
        vertex_id: id,
        tolerance:,
        max_attempts:,
      ))
      cyclic_orders_for_vertices(rest, graph, tolerance, max_attempts, orders: [
        #(id, cyclic_order),
        ..orders
      ])
    }
  }
}

/// Compute the clockwise cyclic oriented-edge order at one vertex.
@internal
pub fn vertex_cyclic_order_with(
  graph: ArrangementGraph,
  vertex_id vertex_id: Int,
  tolerance tolerance: Float,
  max_attempts max_attempts: Int,
) -> Result(List(List(OrientedArrangementEdge)), Error) {
  case tolerance >. 0.0 && number.is_finite(tolerance), max_attempts > 0 {
    False, _ -> Error(InvalidTolerance(tolerance))
    _, False -> Error(InvalidCyclicOrderAttempts(max_attempts))
    True, True -> {
      let ArrangementGraph(vertices:, edges:, ..) = graph
      use vertex <- result.try(
        list.find(vertices, fn(vertex) { vertex.id == vertex_id })
        |> result.map_error(fn(_) { CyclicOrderMissingVertex(vertex_id) }),
      )
      let incident =
        incident_oriented_edges(edges, vertex_id, oriented_edges: [])
      case incident {
        [] -> Error(IsolatedVertex(vertex_id))
        [only] -> Ok([[only]])
        _ -> {
          use radius <- result.try(initial_cyclic_order_radius(
            incident,
            edges,
            vertex.point,
            vertex_id,
          ))
          cyclic_order_attempts(
            incident,
            edges,
            vertex.point,
            vertex_id,
            radius,
            tolerance,
            remaining: max_attempts,
            previous_error: None,
            successful_samples: [],
          )
        }
      }
    }
  }
}

fn incident_oriented_edges(
  edges: List(ArrangementEdge),
  vertex_id: Int,
  oriented_edges oriented_edges: List(OrientedArrangementEdge),
) -> List(OrientedArrangementEdge) {
  case edges {
    [] -> list.reverse(oriented_edges)
    [edge, ..rest] -> {
      let oriented_edges = case edge.start_vertex == vertex_id {
        True -> [
          OrientedArrangementEdge(edge.id, reversed: False),
          ..oriented_edges
        ]
        False -> oriented_edges
      }
      let oriented_edges = case edge.end_vertex == vertex_id {
        True -> [
          OrientedArrangementEdge(edge.id, reversed: True),
          ..oriented_edges
        ]
        False -> oriented_edges
      }
      incident_oriented_edges(rest, vertex_id, oriented_edges:)
    }
  }
}

fn initial_cyclic_order_radius(
  oriented_edges: List(OrientedArrangementEdge),
  edges: List(ArrangementEdge),
  vertex: svg_path.Point,
  vertex_id: Int,
) -> Result(Float, Error) {
  use distances <- result.try(
    oriented_edges
    |> list.map(fn(oriented_edge) {
      use edge <- result.try(edge_for_oriented_edge(edges, oriented_edge))
      let segment = outward_oriented_edge_segment(edge, oriented_edge)
      Ok(point.distance(vertex, svg_path.segment_end(segment)))
    })
    |> result.all,
  )
  case distances {
    [] -> Error(CyclicOrderRadiusUnavailable(vertex_id))
    [first, ..rest] -> {
      let minimum = list.fold(rest, first, float.min)
      case minimum >. 0.0 && number.is_finite(minimum) {
        True -> Ok(0.8 *. minimum)
        False -> Error(CyclicOrderRadiusUnavailable(vertex_id))
      }
    }
  }
}

fn cyclic_order_attempts(
  oriented_edges: List(OrientedArrangementEdge),
  edges: List(ArrangementEdge),
  vertex: svg_path.Point,
  vertex_id: Int,
  radius: Float,
  tolerance: Float,
  remaining remaining: Int,
  previous_error previous_error: Option(Error),
  successful_samples successful_samples: List(List(CyclicOrderSample)),
) -> Result(List(List(OrientedArrangementEdge)), Error) {
  case remaining <= 0 || radius <=. tolerance /. 2.0 {
    True -> {
      case list.reverse(successful_samples) {
        [] ->
          case previous_error {
            Some(error) -> Error(error)
            None -> Error(CyclicOrderRadiusUnavailable(vertex_id))
          }
        [reference, ..] as samples_by_radius -> {
          let groups = group_cyclic_order_samples(reference, tolerance)
          Ok(order_ambiguous_cyclic_groups(groups, samples_by_radius))
        }
      }
    }
    False ->
      case
        cyclic_order_samples_at_radius(
          oriented_edges,
          edges,
          vertex,
          vertex_id,
          radius,
          tolerance,
        )
      {
        Ok(samples) ->
          cyclic_order_attempts(
            oriented_edges,
            edges,
            vertex,
            vertex_id,
            radius *. 0.8,
            tolerance,
            remaining: remaining - 1,
            previous_error:,
            successful_samples: [samples, ..successful_samples],
          )
        Error(error) ->
          cyclic_order_attempts(
            oriented_edges,
            edges,
            vertex,
            vertex_id,
            radius *. 0.8,
            tolerance,
            remaining: remaining - 1,
            previous_error: Some(error),
            successful_samples:,
          )
      }
  }
}

fn cyclic_order_samples_at_radius(
  oriented_edges: List(OrientedArrangementEdge),
  edges: List(ArrangementEdge),
  vertex: svg_path.Point,
  vertex_id: Int,
  radius: Float,
  tolerance: Float,
) -> Result(List(CyclicOrderSample), Error) {
  use samples <- result.try(
    oriented_edges
    |> list.map(fn(oriented_edge) {
      circle_sample_for_oriented_edge(
        edges,
        oriented_edge,
        vertex,
        vertex_id,
        radius,
        tolerance,
      )
    })
    |> result.all,
  )
  Ok(list.sort(samples, by: compare_cyclic_order_samples))
}

fn circle_sample_for_oriented_edge(
  edges: List(ArrangementEdge),
  oriented_edge: OrientedArrangementEdge,
  vertex: svg_path.Point,
  vertex_id: Int,
  radius: Float,
  tolerance: Float,
) -> Result(CyclicOrderSample, Error) {
  use edge <- result.try(edge_for_oriented_edge(edges, oriented_edge))
  let segment = outward_oriented_edge_segment(edge, oriented_edge)
  let radius_squared = radius *. radius
  let residual_tolerance = tolerance *. { 2.0 *. radius +. tolerance }
  use roots <- result.try(
    svg_path.segment_crossings_with(
      segment,
      where: fn(candidate) {
        point.distance_squared(candidate, vertex) -. radius_squared
      },
      options: svg_path.CrossingOptions(
        samples: 100,
        signed_line_distance_tolerance: residual_tolerance,
        max_iterations: 100,
      ),
    )
    |> result.map_error(PathError),
  )
  use t <- result.try(
    list.find(roots, fn(t) { t >. 0.0 && t <=. 1.0 })
    |> result.map_error(fn(_) {
      CyclicOrderCircleIntersectionFailed(vertex_id, edge.id, radius)
    }),
  )
  use sample <- result.try(
    svg_path.segment_point(segment, at: t)
    |> result.map_error(PathError),
  )
  Ok(CyclicOrderSample(
    oriented_edge:,
    point: sample,
    angle: point.heading(point.subtract(sample, vertex)),
  ))
}

fn edge_for_oriented_edge(
  edges: List(ArrangementEdge),
  oriented_edge: OrientedArrangementEdge,
) -> Result(ArrangementEdge, Error) {
  list.find(edges, fn(edge) { edge.id == oriented_edge.edge_id })
  |> result.map_error(fn(_) { MissingEdge(oriented_edge.edge_id) })
}

fn outward_oriented_edge_segment(
  edge: ArrangementEdge,
  oriented_edge: OrientedArrangementEdge,
) -> svg_path.Segment {
  case oriented_edge.reversed {
    True -> svg_path.segment_reverse(edge.segment)
    False -> edge.segment
  }
}

fn compare_cyclic_order_samples(
  left: CyclicOrderSample,
  right: CyclicOrderSample,
) -> order.Order {
  float_compare(left.angle, right.angle)
}

fn group_cyclic_order_samples(
  samples: List(CyclicOrderSample),
  tolerance: Float,
) -> List(List(OrientedArrangementEdge)) {
  case samples {
    [] -> []
    [first, ..rest] -> {
      let groups =
        group_linear_cyclic_order_samples(
          rest,
          previous: first,
          tolerance:,
          current: [first],
          groups: [],
        )
      let groups = list.reverse(groups)
      case groups {
        [] -> []
        [_] -> cyclic_sample_groups_to_oriented_edges(groups)
        [first_group, ..middle_and_last] -> {
          let assert Ok(last_group) = list.last(middle_and_last)
          let assert Ok(last_sample) = list.last(last_group)
          case
            cyclic_order_samples_are_separated(last_sample, first, tolerance)
          {
            True -> cyclic_sample_groups_to_oriented_edges(groups)
            False -> {
              let middle =
                list.take(middle_and_last, list.length(middle_and_last) - 1)
              cyclic_sample_groups_to_oriented_edges([
                list.append(last_group, first_group),
                ..middle
              ])
            }
          }
        }
      }
    }
  }
}

fn group_linear_cyclic_order_samples(
  samples: List(CyclicOrderSample),
  previous previous: CyclicOrderSample,
  tolerance tolerance: Float,
  current current: List(CyclicOrderSample),
  groups groups: List(List(CyclicOrderSample)),
) -> List(List(CyclicOrderSample)) {
  case samples {
    [] -> [list.reverse(current), ..groups]
    [next, ..rest] ->
      case cyclic_order_samples_are_separated(previous, next, tolerance) {
        True ->
          group_linear_cyclic_order_samples(
            rest,
            previous: next,
            tolerance:,
            current: [next],
            groups: [list.reverse(current), ..groups],
          )
        False ->
          group_linear_cyclic_order_samples(
            rest,
            previous: next,
            tolerance:,
            current: [next, ..current],
            groups:,
          )
      }
  }
}

fn cyclic_order_samples_are_separated(
  first: CyclicOrderSample,
  second: CyclicOrderSample,
  tolerance: Float,
) -> Bool {
  let distance = point.distance(first.point, second.point)
  let raw_angle = float.absolute_value(second.angle -. first.angle)
  let angle = float.min(raw_angle, 360.0 -. raw_angle)
  distance >. tolerance || angle >=. cyclic_order_minimum_angle_degrees
}

fn cyclic_sample_groups_to_oriented_edges(
  groups: List(List(CyclicOrderSample)),
) -> List(List(OrientedArrangementEdge)) {
  list.map(groups, fn(group) {
    list.map(group, fn(sample) { sample.oriented_edge })
  })
}

fn order_ambiguous_cyclic_groups(
  groups: List(List(OrientedArrangementEdge)),
  samples_by_radius: List(List(CyclicOrderSample)),
) -> List(List(OrientedArrangementEdge)) {
  list.map(groups, fn(group) {
    case group {
      [] -> []
      [_] -> group
      _ ->
        list.sort(group, by: fn(left, right) {
          let left_score = cyclic_majority_score(left, group, samples_by_radius)
          let right_score =
            cyclic_majority_score(right, group, samples_by_radius)
          case int.compare(right_score, left_score) {
            order.Eq -> compare_oriented_edge_identity(left, right)
            comparison -> comparison
          }
        })
    }
  })
}

fn cyclic_majority_score(
  candidate: OrientedArrangementEdge,
  group: List(OrientedArrangementEdge),
  samples_by_radius: List(List(CyclicOrderSample)),
) -> Int {
  list.fold(group, 0, fn(score, other) {
    case oriented_edges_equal(candidate, other) {
      True -> score
      False ->
        score
        + list.fold(samples_by_radius, 0, fn(wins, samples) {
          case
            cyclic_sample_angle(samples, candidate),
            cyclic_sample_angle(samples, other)
          {
            Ok(candidate_angle), Ok(other_angle) ->
              case clockwise_angle_precedes(candidate_angle, other_angle) {
                True -> wins + 1
                False -> wins
              }
            _, _ -> wins
          }
        })
    }
  })
}

fn cyclic_sample_angle(
  samples: List(CyclicOrderSample),
  oriented_edge: OrientedArrangementEdge,
) -> Result(Float, Nil) {
  use sample <- result.try(
    list.find(samples, fn(sample) {
      oriented_edges_equal(sample.oriented_edge, oriented_edge)
    }),
  )
  Ok(sample.angle)
}

fn clockwise_angle_precedes(left: Float, right: Float) -> Bool {
  let raw_delta = right -. left
  let delta = case raw_delta <. 0.0 {
    True -> raw_delta +. 360.0
    False -> raw_delta
  }
  delta >. 0.0 && delta <. 180.0
}

fn oriented_edges_equal(
  left: OrientedArrangementEdge,
  right: OrientedArrangementEdge,
) -> Bool {
  left.edge_id == right.edge_id && left.reversed == right.reversed
}

fn compare_oriented_edge_identity(
  left: OrientedArrangementEdge,
  right: OrientedArrangementEdge,
) -> order.Order {
  case int.compare(left.edge_id, right.edge_id) {
    order.Eq ->
      case left.reversed, right.reversed {
        False, True -> order.Lt
        True, False -> order.Gt
        _, _ -> order.Eq
      }
    comparison -> comparison
  }
}

type DualWalkCandidate {
  DualWalkCandidate(walk: ArrangementFaceWalk, signature: List(Bool))
}

/// Derive the planar dual without modifying the arrangement graph.
///
/// The existing clockwise cyclic orders determine face successors. Boundary
/// walks are grouped when points immediately on their visual-left sides occupy
/// the same combination of nested boundary regions.
pub fn dual(graph: ArrangementGraph) -> Result(DualArrangementGraph, Error) {
  let ArrangementGraph(edges:, ..) = graph
  case edges {
    [] ->
      Ok(
        DualArrangementGraph(
          faces: [ArrangementFace(id: 0, outer: True, walks: [])],
          edge_faces: [],
        ),
      )
    _ -> {
      use walks <- result.try(dual_face_walks(graph))
      use candidates <- result.try(dual_walk_candidates(walks, graph))
      use faces <- result.try(dual_faces(candidates))
      use edge_faces <- result.try(
        dual_edge_faces(edges, faces, edge_faces: []),
      )
      Ok(DualArrangementGraph(faces:, edge_faces:))
    }
  }
}

fn dual_face_walks(
  graph: ArrangementGraph,
) -> Result(List(ArrangementFaceWalk), Error) {
  let ArrangementGraph(edges:, ..) = graph
  let remaining =
    edges
    |> list.flat_map(fn(edge) {
      [
        ArrangementFaceEdge(edge.id, left: True),
        ArrangementFaceEdge(edge.id, left: False),
      ]
    })
  dual_face_walks_loop(graph, remaining, walks: [])
}

fn dual_face_walks_loop(
  graph: ArrangementGraph,
  remaining: List(ArrangementFaceEdge),
  walks walks: List(ArrangementFaceWalk),
) -> Result(List(ArrangementFaceWalk), Error) {
  case remaining {
    [] -> Ok(list.reverse(walks))
    [start, ..] -> {
      use edges <- result.try(dual_face_walk(
        graph,
        start,
        current: start,
        visited: [],
        remaining_steps: list.length(remaining) + list.length(walks) * 2 + 1,
      ))
      let remaining =
        list.filter(remaining, fn(candidate) {
          !list.any(edges, fn(edge) { dual_face_edges_equal(edge, candidate) })
        })
      dual_face_walks_loop(graph, remaining, walks: [
        ArrangementFaceWalk(outer: False, edges:),
        ..walks
      ])
    }
  }
}

fn dual_face_walk(
  graph: ArrangementGraph,
  start: ArrangementFaceEdge,
  current current: ArrangementFaceEdge,
  visited visited: List(ArrangementFaceEdge),
  remaining_steps remaining_steps: Int,
) -> Result(List(ArrangementFaceEdge), Error) {
  case remaining_steps <= 0 {
    True -> Error(DualWalkDidNotClose(start.edge_id, start.left))
    False -> {
      use next <- result.try(dual_face_successor(graph, current))
      let visited = [current, ..visited]
      case dual_face_edges_equal(next, start) {
        True -> Ok(list.reverse(visited))
        False ->
          case
            list.any(visited, fn(edge) { dual_face_edges_equal(edge, next) })
          {
            True -> Error(DualWalkDidNotClose(start.edge_id, start.left))
            False ->
              dual_face_walk(
                graph,
                start,
                current: next,
                visited:,
                remaining_steps: remaining_steps - 1,
              )
          }
      }
    }
  }
}

fn dual_face_successor(
  graph: ArrangementGraph,
  current: ArrangementFaceEdge,
) -> Result(ArrangementFaceEdge, Error) {
  let ArrangementGraph(edges:, cyclic_orders:, ..) = graph
  use edge <- result.try(
    list.find(edges, fn(edge) { edge.id == current.edge_id })
    |> result.replace_error(MissingEdge(current.edge_id)),
  )
  let arrival_vertex = case current.left {
    True -> edge.end_vertex
    False -> edge.start_vertex
  }
  let incoming_reversed = current.left
  use groups <- result.try(
    list.find_map(cyclic_orders, fn(entry) {
      let #(vertex, groups) = entry
      case vertex == arrival_vertex {
        True -> Ok(groups)
        False -> Error(Nil)
      }
    })
    |> result.replace_error(DualMissingCyclicOrder(arrival_vertex)),
  )
  let order = list.flatten(groups)
  use next <- result.try(dual_next_clockwise_edge(
    order,
    vertex: arrival_vertex,
    incoming_edge: current.edge_id,
    incoming_reversed:,
  ))
  Ok(ArrangementFaceEdge(edge_id: next.edge_id, left: !next.reversed))
}

fn dual_next_clockwise_edge(
  order: List(OrientedArrangementEdge),
  vertex vertex: Int,
  incoming_edge incoming_edge: Int,
  incoming_reversed incoming_reversed: Bool,
) -> Result(OrientedArrangementEdge, Error) {
  case order {
    [] -> Error(DualMissingIncidentEdge(vertex, incoming_edge))
    [first, ..] ->
      dual_next_clockwise_edge_loop(
        order,
        first,
        vertex,
        incoming_edge,
        incoming_reversed,
      )
  }
}

fn dual_next_clockwise_edge_loop(
  remaining: List(OrientedArrangementEdge),
  first: OrientedArrangementEdge,
  vertex: Int,
  incoming_edge: Int,
  incoming_reversed: Bool,
) -> Result(OrientedArrangementEdge, Error) {
  case remaining {
    [] -> Error(DualMissingIncidentEdge(vertex, incoming_edge))
    [current] ->
      case
        current.edge_id == incoming_edge
        && current.reversed == incoming_reversed
      {
        True -> Ok(first)
        False -> Error(DualMissingIncidentEdge(vertex, incoming_edge))
      }
    [current, next, ..rest] ->
      case
        current.edge_id == incoming_edge
        && current.reversed == incoming_reversed
      {
        True -> Ok(next)
        False ->
          dual_next_clockwise_edge_loop(
            [next, ..rest],
            first,
            vertex,
            incoming_edge,
            incoming_reversed,
          )
      }
  }
}

fn dual_walk_candidates(
  walks: List(ArrangementFaceWalk),
  graph: ArrangementGraph,
) -> Result(List(DualWalkCandidate), Error) {
  use prepared <- result.try(
    walks
    |> list.map(fn(walk) {
      use subpath <- result.try(dual_face_walk_subpath(walk, graph))
      Ok(#(walk, subpath))
    })
    |> result.all,
  )
  let subpaths = list.map(prepared, fn(item) { item.1 })
  prepared
  |> list.map(fn(item) {
    let #(walk, subpath) = item
    use sampled <- result.try(dual_face_walk_sample(
      walk,
      subpath,
      graph,
      subpaths,
    ))
    let #(_sample, signature) = sampled
    let outer = area.signed_subpath(subpath) <. 0.0
    Ok(DualWalkCandidate(walk: ArrangementFaceWalk(..walk, outer:), signature:))
  })
  |> result.all
}

fn dual_face_walk_subpath(
  walk: ArrangementFaceWalk,
  graph: ArrangementGraph,
) -> Result(svg_path.Subpath, Error) {
  use segments <- result.try(
    walk.edges
    |> list.map(fn(reference) { dual_face_edge_segment(reference, graph) })
    |> result.all,
  )
  use subpath <- result.try(
    svg_path.subpath(segments)
    |> result.map_error(PathError),
  )
  svg_path.subpath_set_closed(subpath, closed: True)
  |> result.map_error(PathError)
}

fn dual_face_edge_segment(
  reference: ArrangementFaceEdge,
  graph: ArrangementGraph,
) -> Result(svg_path.Segment, Error) {
  let ArrangementGraph(edges:, vertices:, ..) = graph
  use edge <- result.try(
    list.find(edges, fn(edge) { edge.id == reference.edge_id })
    |> result.replace_error(MissingEdge(reference.edge_id)),
  )
  let #(segment, start_vertex, end_vertex) = case reference.left {
    True -> #(edge.segment, edge.start_vertex, edge.end_vertex)
    False -> #(
      svg_path.segment_reverse(edge.segment),
      edge.end_vertex,
      edge.start_vertex,
    )
  }
  use start <- result.try(
    list.find(vertices, fn(vertex) { vertex.id == start_vertex })
    |> result.map(fn(vertex) { vertex.point })
    |> result.replace_error(MissingVertex(start_vertex)),
  )
  use end <- result.try(
    list.find(vertices, fn(vertex) { vertex.id == end_vertex })
    |> result.map(fn(vertex) { vertex.point })
    |> result.replace_error(MissingVertex(end_vertex)),
  )
  svg_path.segment_remap_endpoints(segment, new_start: start, new_end: end)
  |> result.map_error(PathError)
}

fn dual_face_walk_sample(
  walk: ArrangementFaceWalk,
  subpath: svg_path.Subpath,
  graph: ArrangementGraph,
  subpaths: List(svg_path.Subpath),
) -> Result(#(svg_path.Point, List(Bool)), Error) {
  case walk.edges {
    [] -> Error(DualFaceSampleUnavailable(-1, True))
    [first, ..] -> {
      use segment <- result.try(dual_face_edge_segment(first, graph))
      use midpoint <- result.try(
        svg_path.segment_point(segment, at: 0.5)
        |> result.map_error(PathError),
      )
      use derivative <- result.try(
        svg_path.segment_derivative(segment, at: 0.5)
        |> result.map_error(PathError),
      )
      let direction = case point.normalize(derivative) {
        Ok(direction) -> direction
        Error(Nil) ->
          point.subtract(
            svg_path.segment_end(segment),
            svg_path.segment_start(segment),
          )
          |> point.normalize
          |> result.unwrap(svg_path.Point(1.0, 0.0))
      }
      let distance = svg_path.segment_chord_length(segment) *. 0.0001
      dual_face_walk_sample_at_distance(
        first,
        midpoint,
        point.rotate_counterclockwise(direction),
        subpath,
        subpaths,
        distance,
        remaining_attempts: 12,
      )
    }
  }
}

fn dual_face_walk_sample_at_distance(
  edge: ArrangementFaceEdge,
  midpoint: svg_path.Point,
  normal: svg_path.Point,
  subpath: svg_path.Subpath,
  subpaths: List(svg_path.Subpath),
  distance: Float,
  remaining_attempts remaining_attempts: Int,
) -> Result(#(svg_path.Point, List(Bool)), Error) {
  case remaining_attempts <= 0 || distance <=. 0.0 {
    True -> Error(DualFaceSampleUnavailable(edge.edge_id, edge.left))
    False -> {
      let sample = point.add(midpoint, point.scale(normal, by: distance))
      let options =
        svg_path.ContainmentOptions(
          ..svg_path.default_containment_options(),
          tolerance: distance *. 0.01,
        )
      case
        svg_path.subpath_containment_with(
          sample,
          within: subpath,
          using: svg_path.Nonzero,
          options:,
        )
      {
        Ok(svg_path.Boundary) ->
          dual_face_walk_sample_at_distance(
            edge,
            midpoint,
            normal,
            subpath,
            subpaths,
            distance *. 0.5,
            remaining_attempts: remaining_attempts - 1,
          )
        Ok(_) ->
          case dual_containment_signature(sample, subpaths, options) {
            Ok(Some(signature)) -> Ok(#(sample, signature))
            Ok(None) ->
              dual_face_walk_sample_at_distance(
                edge,
                midpoint,
                normal,
                subpath,
                subpaths,
                distance *. 0.5,
                remaining_attempts: remaining_attempts - 1,
              )
            Error(error) -> Error(error)
          }
        Error(error) -> Error(PathError(error))
      }
    }
  }
}

fn dual_containment_signature(
  sample: svg_path.Point,
  subpaths: List(svg_path.Subpath),
  options: svg_path.ContainmentOptions,
) -> Result(Option(List(Bool)), Error) {
  dual_containment_signature_loop(sample, subpaths, options, signature: [])
}

fn dual_containment_signature_loop(
  sample: svg_path.Point,
  subpaths: List(svg_path.Subpath),
  options: svg_path.ContainmentOptions,
  signature signature: List(Bool),
) -> Result(Option(List(Bool)), Error) {
  case subpaths {
    [] -> Ok(Some(list.reverse(signature)))
    [subpath, ..rest] ->
      case
        svg_path.subpath_containment_with(
          sample,
          within: subpath,
          using: svg_path.Nonzero,
          options:,
        )
      {
        Ok(svg_path.Boundary) -> Ok(None)
        Ok(svg_path.Inside) ->
          dual_containment_signature_loop(sample, rest, options, signature: [
            True,
            ..signature
          ])
        Ok(svg_path.Outside) ->
          dual_containment_signature_loop(sample, rest, options, signature: [
            False,
            ..signature
          ])
        Error(error) -> Error(PathError(error))
      }
  }
}

fn dual_faces(
  candidates: List(DualWalkCandidate),
) -> Result(List(ArrangementFace), Error) {
  let groups = dual_group_walk_candidates(candidates, groups: [])
  let #(outer_groups, bounded_groups) =
    list.partition(groups, fn(group) {
      case group {
        [] -> False
        [candidate, ..] -> list.all(candidate.signature, fn(value) { !value })
      }
    })
  case outer_groups {
    [outer_group] ->
      [outer_group, ..bounded_groups]
      |> list.index_map(fn(group, id) { dual_face_from_group(group, id) })
      |> result.all
    groups -> Error(DualInvalidOuterFaceCount(list.length(groups)))
  }
}

fn dual_group_walk_candidates(
  candidates: List(DualWalkCandidate),
  groups groups: List(List(DualWalkCandidate)),
) -> List(List(DualWalkCandidate)) {
  case candidates {
    [] -> list.reverse(groups)
    [first, ..rest] -> {
      let #(same, different) =
        list.partition(rest, fn(candidate) {
          candidate.signature == first.signature
        })
      dual_group_walk_candidates(different, groups: [[first, ..same], ..groups])
    }
  }
}

fn dual_face_from_group(
  group: List(DualWalkCandidate),
  id: Int,
) -> Result(ArrangementFace, Error) {
  let #(outer_walks, island_walks) =
    group
    |> list.map(fn(candidate) { candidate.walk })
    |> list.partition(fn(walk) { walk.outer })
  let outer = case group {
    [] -> False
    [candidate, ..] -> list.all(candidate.signature, fn(value) { !value })
  }
  case outer, list.length(outer_walks) {
    True, 0 -> Ok(ArrangementFace(id:, outer: True, walks: island_walks))
    False, 1 ->
      Ok(ArrangementFace(
        id:,
        outer: False,
        walks: list.append(outer_walks, island_walks),
      ))
    _, count -> Error(DualInvalidOuterWalkCount(count))
  }
}

fn dual_edge_faces(
  edges: List(ArrangementEdge),
  faces: List(ArrangementFace),
  edge_faces edge_faces: List(ArrangementEdgeFaces),
) -> Result(List(ArrangementEdgeFaces), Error) {
  case edges {
    [] -> Ok(list.reverse(edge_faces))
    [edge, ..rest] -> {
      use left_face <- result.try(dual_find_edge_face(
        faces,
        edge.id,
        left: True,
      ))
      use right_face <- result.try(dual_find_edge_face(
        faces,
        edge.id,
        left: False,
      ))
      dual_edge_faces(rest, faces, edge_faces: [
        ArrangementEdgeFaces(edge.id, left_face:, right_face:),
        ..edge_faces
      ])
    }
  }
}

fn dual_find_edge_face(
  faces: List(ArrangementFace),
  edge_id: Int,
  left left: Bool,
) -> Result(Int, Error) {
  faces
  |> list.find(fn(face) {
    face.walks
    |> list.any(fn(walk) {
      walk.edges
      |> list.any(fn(edge) { edge.edge_id == edge_id && edge.left == left })
    })
  })
  |> result.map(fn(face) { face.id })
  |> result.replace_error(DualMissingEdgeFace(edge_id, left))
}

fn dual_face_edges_equal(
  left: ArrangementFaceEdge,
  right: ArrangementFaceEdge,
) -> Bool {
  left.edge_id == right.edge_id && left.left == right.left
}

/// Resolve one segment image to graph edges and traversal directions.
pub fn segment_image_edges(
  build: ArrangementGraphBuild,
  image: ArrangementSegmentImage,
) -> Result(List(#(ArrangementEdge, Bool)), Error) {
  let ArrangementGraphBuild(graph: ArrangementGraph(edges:, ..), ..) = build
  let ArrangementSegmentImage(edges: references, ..) = image
  references
  |> list.map(fn(reference) {
    let DirectedEdgeReference(edge_id:, reversed:) = reference
    case list.find(edges, fn(edge) { edge.id == edge_id }) {
      Ok(edge) -> Ok(#(edge, reversed))
      Error(Nil) -> Error(MissingEdge(edge_id))
    }
  })
  |> result.all
}

/// Reconstruct nested contours from a directed arrangement and source path.
///
/// This preserves signed nonzero winding levels by emitting one contour layer
/// for each integer winding threshold, then tracing those threshold edges by
/// cyclic filled-sector order. It is the arrangement-level primitive used by
/// CSG `nested_contours`.
@internal
pub fn nested_contours_from_graph(
  graph: ArrangementGraph,
  path path: svg_path.Path,
  tolerance tolerance: Float,
) -> Result(List(svg_path.Subpath), Error) {
  let ArrangementGraph(edges:, ..) = graph
  use boundary <- result.try(
    classify_nested_contour_edges(
      edges,
      path,
      tolerance,
      next_id: 0,
      boundary: [],
    ),
  )
  use links <- result.try(pair_nested_contour_sectors(boundary, links: []))
  trace_nested_contour_edges(boundary, links, tolerance, subpaths: [])
}

type NestedContourEdge {
  NestedContourEdge(
    id: Int,
    layer: Int,
    segment: svg_path.Segment,
    start_vertex: Int,
    end_vertex: Int,
  )
}

type NestedContourLink {
  NestedContourLink(edge_id: Int, successor_id: Int)
}

type NestedContourRay {
  NestedContourRay(edge_id: Int, starts: Bool, angle: Float)
}

fn classify_nested_contour_edges(
  edges: List(ArrangementEdge),
  path: svg_path.Path,
  tolerance: Float,
  next_id next_id: Int,
  boundary boundary: List(NestedContourEdge),
) -> Result(List(NestedContourEdge), Error) {
  case edges {
    [] -> Ok(list.reverse(boundary))
    [edge, ..rest] -> {
      let ArrangementEdge(segment:, ..) = edge
      use levels <- result.try(
        winding_field.segment_side_nonzero_levels(
          segment,
          within: path,
          side_sampling_distance: tolerance *. 16.0,
          options: svg_path.default_containment_options(),
        )
        |> result.map_error(PathError),
      )
      let #(left, right) = levels
      let #(next_id, boundary) =
        emit_nested_winding_thresholds(edge, left, right, 1, next_id, boundary)
      classify_nested_contour_edges(rest, path, tolerance, next_id:, boundary:)
    }
  }
}

fn emit_nested_winding_thresholds(
  edge: ArrangementEdge,
  left: Int,
  right: Int,
  level: Int,
  next_id: Int,
  boundary: List(NestedContourEdge),
) -> #(Int, List(NestedContourEdge)) {
  let maximum = int_max(int.absolute_value(left), int.absolute_value(right))
  case level > maximum {
    True -> #(next_id, boundary)
    False -> {
      let #(next_id, boundary) =
        emit_nested_threshold_edge(
          edge,
          left >= level,
          right >= level,
          level,
          next_id,
          boundary,
        )
      let #(next_id, boundary) =
        emit_nested_threshold_edge(
          edge,
          left <= 0 - level,
          right <= 0 - level,
          0 - level,
          next_id,
          boundary,
        )
      emit_nested_winding_thresholds(
        edge,
        left,
        right,
        level + 1,
        next_id,
        boundary,
      )
    }
  }
}

fn emit_nested_threshold_edge(
  edge: ArrangementEdge,
  active_left: Bool,
  active_right: Bool,
  layer: Int,
  next_id: Int,
  boundary: List(NestedContourEdge),
) -> #(Int, List(NestedContourEdge)) {
  let ArrangementEdge(segment:, start_vertex:, end_vertex:, ..) = edge
  case active_left, active_right {
    True, False -> #(next_id + 1, [
      NestedContourEdge(
        id: next_id,
        layer:,
        segment:,
        start_vertex:,
        end_vertex:,
      ),
      ..boundary
    ])
    False, True -> #(next_id + 1, [
      NestedContourEdge(
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

fn pair_nested_contour_sectors(
  edges: List(NestedContourEdge),
  links links: List(NestedContourLink),
) -> Result(List(NestedContourLink), Error) {
  pair_nested_contour_sectors_loop(edges, edges, links)
}

fn pair_nested_contour_sectors_loop(
  unpaired: List(NestedContourEdge),
  all_edges: List(NestedContourEdge),
  links: List(NestedContourLink),
) -> Result(List(NestedContourLink), Error) {
  case unpaired {
    [] -> Ok(list.reverse(links))
    [NestedContourEdge(id:, layer:, end_vertex:, ..), ..rest] -> {
      use successor <- result.try(nested_contour_successor(
        all_edges,
        incoming_id: id,
        vertex: end_vertex,
        layer:,
      ))
      pair_nested_contour_sectors_loop(rest, all_edges, [
        NestedContourLink(edge_id: id, successor_id: successor),
        ..links
      ])
    }
  }
}

fn nested_contour_successor(
  edges: List(NestedContourEdge),
  incoming_id incoming_id: Int,
  vertex vertex: Int,
  layer layer: Int,
) -> Result(Int, Error) {
  use rays <- result.try(
    collect_nested_contour_rays(edges, vertex, layer, rays: []),
  )
  let ordered = rays |> list.sort(by: compare_nested_contour_rays)
  use successor <- result.try(cyclic_nested_contour_successor(
    ordered,
    incoming_id,
    first: list.first(ordered),
    vertex:,
  ))
  let NestedContourRay(edge_id:, starts:, ..) = successor
  case starts {
    True -> Ok(edge_id)
    False -> Error(ContourTraceFailed(vertex:))
  }
}

fn collect_nested_contour_rays(
  edges: List(NestedContourEdge),
  vertex: Int,
  layer: Int,
  rays rays: List(NestedContourRay),
) -> Result(List(NestedContourRay), Error) {
  case edges {
    [] -> Ok(rays)
    [
      NestedContourEdge(
        id:,
        layer: edge_layer,
        segment:,
        start_vertex:,
        end_vertex:,
      ),
      ..rest
    ] -> {
      use rays <- result.try(
        case edge_layer == layer && start_vertex == vertex {
          False -> Ok(rays)
          True -> {
            use directions <- result.try(
              svg_path.segment_directions(segment, at: 0.0)
              |> result.map_error(PathError),
            )
            use direction <- result.try(contour_direction(
              directions.outgoing,
              vertex:,
            ))
            Ok([
              NestedContourRay(
                edge_id: id,
                starts: True,
                angle: point.heading(direction),
              ),
              ..rays
            ])
          }
        },
      )
      use rays <- result.try(case edge_layer == layer && end_vertex == vertex {
        False -> Ok(rays)
        True -> {
          use directions <- result.try(
            svg_path.segment_directions(segment, at: 1.0)
            |> result.map_error(PathError),
          )
          use direction <- result.try(contour_direction(
            directions.incoming,
            vertex:,
          ))
          Ok([
            NestedContourRay(
              edge_id: id,
              starts: False,
              angle: point.heading(point.negate(direction)),
            ),
            ..rays
          ])
        }
      })
      collect_nested_contour_rays(rest, vertex, layer, rays:)
    }
  }
}

fn contour_direction(
  direction: Option(svg_path.Point),
  vertex vertex: Int,
) -> Result(svg_path.Point, Error) {
  case direction {
    Some(direction) -> Ok(direction)
    None -> Error(ContourTraceFailed(vertex:))
  }
}

fn compare_nested_contour_rays(
  left: NestedContourRay,
  right: NestedContourRay,
) -> order.Order {
  let NestedContourRay(angle: left_angle, ..) = left
  let NestedContourRay(angle: right_angle, ..) = right
  float_compare(left_angle, right_angle)
}

fn cyclic_nested_contour_successor(
  rays: List(NestedContourRay),
  incoming_id: Int,
  first first_ray: Result(NestedContourRay, Nil),
  vertex vertex: Int,
) -> Result(NestedContourRay, Error) {
  case rays {
    [] -> Error(ContourTraceFailed(vertex:))
    [first, ..rest] -> {
      let NestedContourRay(edge_id:, starts:, ..) = first
      case edge_id == incoming_id && !starts {
        True ->
          case rest {
            [next, ..] -> Ok(next)
            [] ->
              first_ray
              |> result.map_error(fn(_) { ContourTraceFailed(vertex:) })
          }
        False ->
          cyclic_nested_contour_successor(
            rest,
            incoming_id,
            first: first_ray,
            vertex:,
          )
      }
    }
  }
}

fn trace_nested_contour_edges(
  remaining: List(NestedContourEdge),
  links: List(NestedContourLink),
  tolerance: Float,
  subpaths subpaths: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case remaining {
    [] -> Ok(list.reverse(subpaths))
    [seed, ..rest] -> {
      let NestedContourEdge(layer:, ..) = seed
      use traced <- result.try(trace_nested_contour_cycle(
        seed,
        rest,
        links,
        reversed_cycle: [seed],
        limit: list.length(remaining) + 1,
      ))
      let #(cycle, remaining) = traced
      use subpath <- result.try(
        cycle
        |> list.map(fn(edge) {
          let NestedContourEdge(segment:, ..) = edge
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
      trace_nested_contour_edges(remaining, links, tolerance, subpaths: [
        oriented,
        ..subpaths
      ])
    }
  }
}

fn trace_nested_contour_cycle(
  seed: NestedContourEdge,
  remaining: List(NestedContourEdge),
  links: List(NestedContourLink),
  reversed_cycle reversed_cycle: List(NestedContourEdge),
  limit limit: Int,
) -> Result(#(List(NestedContourEdge), List(NestedContourEdge)), Error) {
  let NestedContourEdge(id: seed_id, ..) = seed
  let assert [current, ..] = reversed_cycle
  let NestedContourEdge(id: current_id, end_vertex:, ..) = current
  use successor_id <- result.try(nested_boundary_successor(
    links,
    edge_id: current_id,
    vertex: end_vertex,
  ))
  case successor_id == seed_id {
    True -> Ok(#(list.reverse(reversed_cycle), remaining))
    False ->
      case limit <= 0 {
        True -> Error(ContourTraceFailed(vertex: end_vertex))
        False -> {
          use selected <- result.try(
            take_nested_contour_edge(
              remaining,
              successor_id,
              vertex: end_vertex,
              retained: [],
            ),
          )
          let #(next, rest) = selected
          trace_nested_contour_cycle(
            seed,
            rest,
            links,
            reversed_cycle: [next, ..reversed_cycle],
            limit: limit - 1,
          )
        }
      }
  }
}

fn nested_boundary_successor(
  links: List(NestedContourLink),
  edge_id edge_id: Int,
  vertex vertex: Int,
) -> Result(Int, Error) {
  case links {
    [] -> Error(ContourTraceFailed(vertex:))
    [NestedContourLink(edge_id: candidate, successor_id:), ..rest] ->
      case candidate == edge_id {
        True -> Ok(successor_id)
        False -> nested_boundary_successor(rest, edge_id:, vertex:)
      }
  }
}

fn take_nested_contour_edge(
  edges: List(NestedContourEdge),
  id: Int,
  vertex vertex: Int,
  retained retained: List(NestedContourEdge),
) -> Result(#(NestedContourEdge, List(NestedContourEdge)), Error) {
  case edges {
    [] -> Error(ContourTraceFailed(vertex:))
    [first, ..rest] -> {
      let NestedContourEdge(id: candidate, ..) = first
      case candidate == id {
        True -> Ok(#(first, list.append(list.reverse(retained), rest)))
        False ->
          take_nested_contour_edge(rest, id, vertex:, retained: [
            first,
            ..retained
          ])
      }
    }
  }
}

fn int_max(left: Int, right: Int) -> Int {
  case left > right {
    True -> left
    False -> right
  }
}

type IndexedSegment {
  IndexedSegment(
    index: Int,
    path_index: Int,
    subpath_index: Int,
    segment_index: Int,
    segment: svg_path.Segment,
  )
}

type AtomicPiece {
  AtomicPiece(
    source_index: Int,
    path_index: Int,
    subpath_index: Int,
    segment_index: Int,
    source_from: Float,
    source_to: Float,
    segment: svg_path.Segment,
  )
}

type IncomingContext {
  IncomingContext(
    piece: AtomicPiece,
    bounds: svg_path.BoundingBox,
    start_match: Option(Int),
    end_match: Option(Int),
  )
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

type EndpointSide {
  StartEndpoint
  EndEndpoint
}

@internal
pub fn empty() -> ArrangementGraph {
  ArrangementGraph(vertices: [], edges: [], cyclic_orders: [])
}

/// Apply every uniquely forced undirected parity-capacity reduction.
///
/// An omitted vertex has parity zero. The graph remains unchanged. A parity
/// mismatch forces a one-unit reduction only when exactly one positive-capacity
/// edge is incident to the vertex.
@internal
pub fn forced_parity_capacities(
  graph: ArrangementGraph,
  vertex_parities vertex_parities: List(VertexParityRequest),
) -> Result(List(EdgeCapacityAssignment), ForcedParityError) {
  let ArrangementGraph(edges:, ..) = graph
  let assignments =
    list.map(edges, fn(edge) {
      EdgeCapacityAssignment(
        edge_id: edge.id,
        capacity: edge.forward_multiplicity + edge.reverse_multiplicity,
      )
    })
  forced_parity_capacities_with(graph, assignments, vertex_parities:)
}

/// Apply forced parity reduction from explicit undirected edge capacities.
///
/// The graph supplies topology only. `initial_capacities` must contain exactly
/// one nonnegative assignment for every graph edge; zero-capacity edges remain
/// present in the graph but do not participate in a forced reduction.
@internal
pub fn forced_parity_capacities_with(
  graph: ArrangementGraph,
  initial_capacities: List(EdgeCapacityAssignment),
  vertex_parities vertex_parities: List(VertexParityRequest),
) -> Result(List(EdgeCapacityAssignment), ForcedParityError) {
  use _ <- result.try(validate_forced_parities(graph, vertex_parities))
  use _ <- result.try(validate_edge_capacities(graph, initial_capacities))
  forced_parity_reduce(graph, vertex_parities, initial_capacities)
}

fn validate_edge_capacities(
  graph: ArrangementGraph,
  assignments: List(EdgeCapacityAssignment),
) -> Result(Nil, ForcedParityError) {
  let ArrangementGraph(edges:, ..) = graph
  use _ <- result.try(
    assignments
    |> list.fold(Ok(Nil), fn(valid, assignment) {
      use _ <- result.try(valid)
      let EdgeCapacityAssignment(edge_id:, capacity:) = assignment
      case capacity < 0 {
        True -> Error(ForcedParityInvalidEdgeCapacity(edge_id, capacity))
        False ->
          case list.any(edges, fn(edge) { edge.id == edge_id }) {
            False -> Error(ForcedParityUnknownEdgeCapacity(edge_id))
            True ->
              case
                assignments
                |> list.filter(fn(other) { other.edge_id == edge_id })
                |> list.length
                |> fn(count) { count > 1 }
              {
                True -> Error(ForcedParityDuplicateEdgeCapacity(edge_id))
                False -> Ok(Nil)
              }
          }
      }
    }),
  )
  edges
  |> list.fold(Ok(Nil), fn(valid, edge) {
    use _ <- result.try(valid)
    case list.any(assignments, fn(candidate) { candidate.edge_id == edge.id }) {
      True -> Ok(Nil)
      False -> Error(ForcedParityMissingEdgeCapacity(edge.id))
    }
  })
}

fn validate_forced_parities(
  graph: ArrangementGraph,
  vertex_parities: List(VertexParityRequest),
) -> Result(Nil, ForcedParityError) {
  let ArrangementGraph(vertices:, ..) = graph
  case vertex_parities {
    [] -> Ok(Nil)
    [first, ..rest] -> {
      let #(vertex, parity) = vertex_parity_request(first)
      case parity == 0 || parity == 1 {
        False -> Error(ForcedParityInvalidVertexParity(vertex, parity))
        True ->
          case
            list.any(rest, fn(other) {
              let #(other_vertex, _) = vertex_parity_request(other)
              other_vertex == vertex
            })
          {
            True -> Error(ForcedParityDuplicateVertex(vertex))
            False ->
              case
                list.any(vertices, fn(candidate) { candidate.id == vertex })
              {
                False -> Error(ForcedParityMissingVertex(vertex))
                True -> validate_forced_parities(graph, rest)
              }
          }
      }
    }
  }
}

fn vertex_parity_request(request: VertexParityRequest) -> #(Int, Int) {
  case request {
    RequiredVertexParity(vertex:, parity:) -> #(vertex, parity)
    PreferredVertexParity(vertex:, parity:) -> #(vertex, parity)
  }
}

fn forced_parity_reduce(
  graph: ArrangementGraph,
  vertex_parities: List(VertexParityRequest),
  assignments: List(EdgeCapacityAssignment),
) -> Result(List(EdgeCapacityAssignment), ForcedParityError) {
  let ArrangementGraph(vertices:, ..) = graph
  let states =
    list.map(vertices, fn(vertex) {
      forced_parity_vertex_state(graph, assignments, vertex_parities, vertex.id)
    })
  let mismatched =
    list.filter(states, fn(state) {
      state.incident_capacity % 2 != state.parity
      && case state.preferred && state.incident_capacity == 0 {
        True -> False
        False -> True
      }
    })
  case list.find(mismatched, fn(state) { state.positive_edges == [] }) {
    Ok(state) -> Error(ForcedParityInfeasible(state.vertex))
    Error(_) ->
      case
        list.find_map(mismatched, fn(state) {
          forced_parity_reduction_edge(state, assignments, threshold: 1)
        })
      {
        Ok(edge_id) ->
          assignments
          |> reduce_edge_capacity(edge_id)
          |> forced_parity_reduce(graph, vertex_parities, _)
        Error(_) ->
          case mismatched {
            [] -> Ok(assignments)
            _ ->
              Error(
                ForcedParityAmbiguous(
                  list.map(mismatched, fn(state) { state.vertex }),
                ),
              )
          }
      }
  }
}

fn forced_parity_reduction_edge(
  state: VertexParityState,
  assignments: List(EdgeCapacityAssignment),
  threshold threshold: Int,
) -> Result(Int, Nil) {
  let qualifying =
    state.positive_edges
    |> list.filter(fn(edge_id) {
      let assert Ok(EdgeCapacityAssignment(capacity:, ..)) =
        list.find(assignments, fn(assignment) { assignment.edge_id == edge_id })
      capacity >= threshold
    })
  case qualifying {
    [edge_id] -> Ok(edge_id)
    [] -> Error(Nil)
    [_, _, ..] ->
      forced_parity_reduction_edge(state, assignments, threshold: threshold + 1)
  }
}

fn reduce_edge_capacity(
  assignments: List(EdgeCapacityAssignment),
  edge_id: Int,
) -> List(EdgeCapacityAssignment) {
  list.map(assignments, fn(assignment) {
    case assignment.edge_id == edge_id {
      True ->
        EdgeCapacityAssignment(..assignment, capacity: assignment.capacity - 1)
      False -> assignment
    }
  })
}

fn forced_parity_vertex_state(
  graph: ArrangementGraph,
  assignments: List(EdgeCapacityAssignment),
  vertex_parities: List(VertexParityRequest),
  vertex: Int,
) -> VertexParityState {
  let ArrangementGraph(edges:, ..) = graph
  let #(parity, preferred) = case
    list.find(vertex_parities, fn(request) {
      let #(request_vertex, _) = vertex_parity_request(request)
      request_vertex == vertex
    })
  {
    Ok(RequiredVertexParity(parity:, ..)) -> #(parity, False)
    Ok(PreferredVertexParity(parity:, ..)) -> #(parity, True)
    Error(_) -> #(0, False)
  }
  list.fold(
    edges,
    VertexParityState(
      vertex:,
      parity:,
      preferred:,
      incident_capacity: 0,
      positive_edges: [],
    ),
    fn(state, edge) {
      case edge.start_vertex == vertex || edge.end_vertex == vertex {
        False -> state
        True -> {
          let assert Ok(EdgeCapacityAssignment(capacity:, ..)) =
            list.find(assignments, fn(candidate) {
              candidate.edge_id == edge.id
            })
          VertexParityState(
            ..state,
            incident_capacity: state.incident_capacity + capacity,
            positive_edges: case capacity > 0 {
              True -> [edge.id, ..state.positive_edges]
              False -> state.positive_edges
            },
          )
        }
      }
    },
  )
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
  case
    tolerance <=. 0.0 || tolerance -. tolerance != 0.0,
    minimum_chord <=. 0.0 || minimum_chord -. minimum_chord != 0.0
  {
    True, _ -> Error(InvalidTolerance(tolerance))
    _, True -> Error(InvalidMinimumChord(minimum_chord))
    False, False -> {
      let start = svg_path.segment_start(segment)
      let end = svg_path.segment_end(segment)
      let chord = svg_path.segment_chord_length(segment)
      case chord <. minimum_chord {
        True -> Error(SegmentTooShort(chord:, minimum: minimum_chord))
        False -> {
          let ArrangementGraph(vertices:, edges:, ..) = graph
          let #(vertices, start_id) = attach_vertex(vertices, start, tolerance)
          let #(vertices, end_id) = attach_vertex(vertices, end, tolerance)
          case start_id == end_id {
            True -> Error(SegmentCollapsedToVertex(vertex: start_id))
            False ->
              Ok(
                ArrangementGraph(
                  vertices:,
                  edges: insert_or_increment_edge(
                    edges,
                    segment,
                    start_id,
                    end_id,
                  ),
                  cyclic_orders: [],
                ),
              )
          }
        }
      }
    }
  }
}

/// Build an arrangement graph from the input paths.
///
/// Construction flattens the input paths into their existing segments, then
/// nodes them progressively at intersections and endpoint-bounded overlap
/// boundaries.
pub fn build(
  paths: List(svg_path.Path),
  tolerance tolerance: Float,
  minimum_chord minimum_chord: Float,
) -> Result(ArrangementGraphBuild, Error) {
  let indexed = index_paths(paths)
  let segments =
    list.map(indexed, fn(item) {
      let IndexedSegment(segment:, ..) = item
      segment
    })
  use build <- result.try(build_with(
    segments,
    vertex_tolerance: tolerance,
    minimum_chord:,
    endpoint_sliver_tolerance: 0.0,
  ))
  let ArrangementSegmentBuild(graph:, segment_images:, ..) = build
  use segment_images <- result.try(
    public_segment_images(indexed, segment_images, images: []),
  )
  Ok(ArrangementGraphBuild(graph:, segment_images:))
}

/// Build an arrangement directly from a flat segment list.
///
/// This internal segment-list constructor does not normalize, split, or
/// otherwise rewrite the caller's input before the progressive pass. The
/// returned maps relate the original segment list to the final graph edges.
@internal
pub fn build_with(
  segments: List(svg_path.Segment),
  vertex_tolerance vertex_tolerance: Float,
  minimum_chord minimum_chord: Float,
  endpoint_sliver_tolerance endpoint_sliver_tolerance: Float,
) -> Result(ArrangementSegmentBuild, Error) {
  use _ <- result.try(validate_options(vertex_tolerance, minimum_chord))
  use _ <- result.try(validate_endpoint_cut_tolerance(endpoint_sliver_tolerance))
  let indexed = index_flat_segments(segments)
  let pieces = indexed_segments_as_atomic_pieces(indexed, minimum_chord, [])
  let images = initial_segment_images(indexed)
  use #(graph, images) <- result.try(progressive_insert_pieces_loop(
    pieces,
    empty(),
    images,
    vertex_tolerance,
    minimum_chord,
    endpoint_sliver_tolerance,
    iteration: 0,
  ))
  use segment_images <- result.try(source_segment_images(
    segments,
    graph,
    images,
    vertex_tolerance,
  ))
  let edge_images = edge_source_images(graph, segment_images)
  use _ <- result.try(certify_segment_build(
    graph,
    segments,
    segment_images,
    edge_images,
    vertex_tolerance,
  ))
  use cyclic_orders <- result.try(cyclic_orders_with(
    graph,
    tolerance: vertex_tolerance,
    max_attempts: cyclic_order_max_attempts,
  ))
  let ArrangementGraph(vertices:, edges:, ..) = graph
  let graph = ArrangementGraph(vertices:, edges:, cyclic_orders:)
  Ok(ArrangementSegmentBuild(graph:, segments:, segment_images:, edge_images:))
}

fn indexed_segments_as_atomic_pieces(
  segments: List(IndexedSegment),
  minimum_chord: Float,
  pieces pieces: List(AtomicPiece),
) -> List(AtomicPiece) {
  case segments {
    [] -> list.reverse(pieces)
    [
      IndexedSegment(
        index:,
        path_index:,
        subpath_index:,
        segment_index:,
        segment:,
      ),
      ..rest
    ] -> {
      let pieces = case
        svg_path.segment_chord_length(segment) >=. minimum_chord
      {
        True -> [
          AtomicPiece(
            source_index: index,
            path_index:,
            subpath_index:,
            segment_index:,
            source_from: 0.0,
            source_to: 1.0,
            segment:,
          ),
          ..pieces
        ]
        False -> pieces
      }
      indexed_segments_as_atomic_pieces(rest, minimum_chord, pieces:)
    }
  }
}

type ProgressivePieceResult {
  ProgressivePieceInserted(
    graph: ArrangementGraph,
    images: List(ArrangementSegmentImage),
  )
  ProgressivePieceReplaced(
    graph: ArrangementGraph,
    images: List(ArrangementSegmentImage),
    replacements: List(AtomicPiece),
  )
}

fn progressive_insert_piece_direct(
  context: IncomingContext,
  graph: ArrangementGraph,
  images: List(ArrangementSegmentImage),
  tolerance: Float,
  minimum_chord: Float,
) -> Result(ProgressivePieceResult, Error) {
  let IncomingContext(piece:, ..) = context
  let AtomicPiece(source_index:, ..) = piece
  case
    insert_corresponding_piece_with_ref(
      context,
      graph,
      tolerance,
      minimum_chord,
    )
  {
    Ok(#(graph, edge_id, reversed)) -> {
      let images =
        append_segment_image_reference(
          images,
          source_index,
          DirectedEdgeReference(edge_id:, reversed:),
        )
      Ok(ProgressivePieceInserted(graph, images))
    }
    Error(SegmentCollapsedToVertex(_vertex)) -> {
      Ok(ProgressivePieceInserted(graph, images))
    }
    Error(SegmentTooShort(_chord, _minimum)) -> {
      Ok(ProgressivePieceInserted(graph, images))
    }
    Error(error) -> Error(error)
  }
}

fn progressive_insert_pieces_loop(
  stack: List(AtomicPiece),
  graph: ArrangementGraph,
  images: List(ArrangementSegmentImage),
  vertex_tolerance: Float,
  minimum_chord: Float,
  endpoint_sliver_tolerance: Float,
  iteration iteration: Int,
) -> Result(#(ArrangementGraph, List(ArrangementSegmentImage)), Error) {
  case stack {
    [] -> Ok(#(graph, images))
    [first, ..rest] -> {
      use vertex_split <- result.try(split_piece_at_existing_vertex(
        first,
        graph,
        vertex_tolerance,
        minimum_chord,
      ))
      case vertex_split {
        Some(replacements) ->
          progressive_insert_pieces_loop(
            list.append(replacements, rest),
            graph,
            images,
            vertex_tolerance,
            minimum_chord,
            endpoint_sliver_tolerance,
            iteration: iteration + 1,
          )
        None -> {
          use _ <- result.try(validate_piece_endpoint_vertices(
            first,
            graph,
            vertex_tolerance,
          ))
          use result <- result.try(progressive_insert_piece(
            first,
            graph,
            images,
            vertex_tolerance,
            minimum_chord,
            endpoint_sliver_tolerance,
          ))
          case result {
            ProgressivePieceInserted(graph, images) ->
              progressive_insert_pieces_loop(
                rest,
                graph,
                images,
                vertex_tolerance,
                minimum_chord,
                endpoint_sliver_tolerance,
                iteration: iteration + 1,
              )
            ProgressivePieceReplaced(graph, images, replacements) ->
              progressive_insert_pieces_loop(
                list.append(replacements, rest),
                graph,
                images,
                vertex_tolerance,
                minimum_chord,
                endpoint_sliver_tolerance,
                iteration: iteration + 1,
              )
          }
        }
      }
    }
  }
}

fn validate_piece_endpoint_vertices(
  piece: AtomicPiece,
  graph: ArrangementGraph,
  vertex_tolerance: Float,
) -> Result(Nil, Error) {
  let AtomicPiece(segment:, ..) = piece
  let ArrangementGraph(vertices:, ..) = graph
  use _ <- result.try(unique_vertex_for_endpoint(
    vertices,
    svg_path.segment_start(segment),
    vertex_tolerance,
  ))
  use _ <- result.try(unique_vertex_for_endpoint(
    vertices,
    svg_path.segment_end(segment),
    vertex_tolerance,
  ))
  Ok(Nil)
}

fn split_piece_at_existing_vertex(
  piece: AtomicPiece,
  graph: ArrangementGraph,
  vertex_tolerance: Float,
  minimum_chord: Float,
) -> Result(Option(List(AtomicPiece)), Error) {
  let ArrangementGraph(vertices:, ..) = graph
  use bounds <- result.try(
    svg_path.segment_bounding_box(piece.segment) |> result.map_error(PathError),
  )
  use cut <- result.try(vertex_cut_parameter(
    piece,
    bounds,
    vertices,
    vertex_tolerance,
  ))
  case cut {
    Some(t) -> {
      split_atomic_piece(piece, [t], vertex_tolerance, minimum_chord)
      |> result.map(Some)
    }
    None -> Ok(None)
  }
}

fn vertex_cut_parameter(
  piece: AtomicPiece,
  bounds: svg_path.BoundingBox,
  vertices: List(ArrangementVertex),
  vertex_tolerance: Float,
) -> Result(Option(Float), Error) {
  let AtomicPiece(segment:, ..) = piece
  case vertices {
    [] -> Ok(None)
    [ArrangementVertex(point:, ..), ..rest] -> {
      use t <- result.try(
        case point_in_expanded_box(point, bounds, vertex_tolerance) {
          False -> Ok(None)
          True ->
            vertex_projects_to_piece_interior(point, segment, vertex_tolerance)
        },
      )
      case t {
        Some(_) -> Ok(t)
        None -> vertex_cut_parameter(piece, bounds, rest, vertex_tolerance)
      }
    }
  }
}

fn vertex_projects_to_piece_interior(
  vertex: svg_path.Point,
  segment: svg_path.Segment,
  vertex_tolerance: Float,
) -> Result(Option(Float), Error) {
  let start = svg_path.segment_start(segment)
  let end = svg_path.segment_end(segment)
  case
    point.distance(vertex, start) <=. vertex_tolerance
    || point.distance(vertex, end) <=. vertex_tolerance
  {
    True -> Ok(None)
    False ->
      vertex_projects_to_piece_interior_uncached(
        vertex,
        segment,
        vertex_tolerance,
      )
  }
}

fn vertex_projects_to_piece_interior_uncached(
  vertex: svg_path.Point,
  segment: svg_path.Segment,
  vertex_tolerance: Float,
) -> Result(Option(Float), Error) {
  case segment {
    svg_path.Line(start:, end:) ->
      vertex_projects_to_line_interior(vertex, start, end, vertex_tolerance)
    _ -> {
      use projection <- result.try(
        svg_path.segment_projection(vertex, to: segment)
        |> result.map_error(PathError),
      )
      let svg_path.SegmentProjection(t:, distance:, ..) = projection
      Ok(case distance <=. vertex_tolerance && t >. 0.0 && t <. 1.0 {
        True -> Some(t)
        False -> None
      })
    }
  }
}

fn vertex_projects_to_line_interior(
  vertex: svg_path.Point,
  start: svg_path.Point,
  end: svg_path.Point,
  vertex_tolerance: Float,
) -> Result(Option(Float), Error) {
  let line = point.subtract(end, start)
  let length_squared = point.dot(line, line)
  case length_squared <=. 0.0 {
    True -> Error(SegmentTooShort(chord: 0.0, minimum: vertex_tolerance))
    False -> {
      let raw_t =
        point.dot(point.subtract(vertex, start), line) /. length_squared
      let projected = point.add(start, point.scale(line, by: raw_t))
      let distance = point.distance(vertex, projected)
      case distance <=. vertex_tolerance {
        False -> Ok(None)
        True ->
          case raw_t >. 0.0 && raw_t <. 1.0 {
            True -> Ok(Some(raw_t))
            False -> Ok(None)
          }
      }
    }
  }
}

fn point_in_expanded_box(
  point: svg_path.Point,
  box: svg_path.BoundingBox,
  tolerance: Float,
) -> Bool {
  point.x >=. box.min.x -. tolerance
  && point.x <=. box.max.x +. tolerance
  && point.y >=. box.min.y -. tolerance
  && point.y <=. box.max.y +. tolerance
}

fn bounding_boxes_overlap(
  first: svg_path.BoundingBox,
  second: svg_path.BoundingBox,
  tolerance: Float,
) -> Bool {
  first.min.x <=. second.max.x +. tolerance
  && first.max.x >=. second.min.x -. tolerance
  && first.min.y <=. second.max.y +. tolerance
  && first.max.y >=. second.min.y -. tolerance
}

fn segment_bounding_box_assert(
  segment: svg_path.Segment,
) -> svg_path.BoundingBox {
  let assert Ok(bounds) = svg_path.segment_bounding_box(segment)
  bounds
}

fn progressive_insert_piece(
  piece: AtomicPiece,
  graph: ArrangementGraph,
  images: List(ArrangementSegmentImage),
  vertex_tolerance: Float,
  minimum_chord: Float,
  endpoint_sliver_tolerance: Float,
) -> Result(ProgressivePieceResult, Error) {
  use context <- result.try(incoming_context(piece, graph, vertex_tolerance))
  use endpoint_split <- result.try(split_existing_edge_at_incoming_endpoint(
    context,
    graph,
    images,
    vertex_tolerance,
    minimum_chord,
  ))
  case endpoint_split {
    Some(#(graph, images)) ->
      Ok(ProgressivePieceReplaced(graph, images, [piece]))
    None ->
      progressive_insert_piece_context(
        context,
        graph,
        images,
        vertex_tolerance,
        minimum_chord,
        endpoint_sliver_tolerance,
      )
  }
}

fn incoming_context(
  piece: AtomicPiece,
  graph: ArrangementGraph,
  vertex_tolerance: Float,
) -> Result(IncomingContext, Error) {
  let AtomicPiece(segment:, ..) = piece
  let ArrangementGraph(vertices:, ..) = graph
  use bounds <- result.try(
    svg_path.segment_bounding_box(segment) |> result.map_error(PathError),
  )
  use start_match <- result.try(unique_vertex_for_endpoint(
    vertices,
    svg_path.segment_start(segment),
    vertex_tolerance,
  ))
  use end_match <- result.try(unique_vertex_for_endpoint(
    vertices,
    svg_path.segment_end(segment),
    vertex_tolerance,
  ))
  Ok(IncomingContext(piece:, bounds:, start_match:, end_match:))
}

fn progressive_insert_piece_context(
  context: IncomingContext,
  graph: ArrangementGraph,
  images: List(ArrangementSegmentImage),
  vertex_tolerance: Float,
  minimum_chord: Float,
  endpoint_sliver_tolerance: Float,
) -> Result(ProgressivePieceResult, Error) {
  let ArrangementGraph(edges:, ..) = graph
  progressive_compare_edges(
    context,
    edges,
    graph,
    images,
    vertex_tolerance,
    minimum_chord,
    endpoint_sliver_tolerance,
  )
}

fn split_existing_edge_at_incoming_endpoint(
  context: IncomingContext,
  graph: ArrangementGraph,
  images: List(ArrangementSegmentImage),
  vertex_tolerance: Float,
  minimum_chord: Float,
) -> Result(Option(#(ArrangementGraph, List(ArrangementSegmentImage))), Error) {
  let IncomingContext(piece: AtomicPiece(segment:, ..), ..) = context
  let ArrangementGraph(edges:, ..) = graph
  use start_result <- result.try(split_existing_edge_at_endpoint(
    edges,
    svg_path.segment_start(segment),
    context,
    graph,
    images,
    vertex_tolerance,
    minimum_chord,
  ))
  case start_result {
    Some(_) -> Ok(start_result)
    None ->
      split_existing_edge_at_endpoint(
        edges,
        svg_path.segment_end(segment),
        context,
        graph,
        images,
        vertex_tolerance,
        minimum_chord,
      )
  }
}

fn split_existing_edge_at_endpoint(
  edges: List(ArrangementEdge),
  endpoint: svg_path.Point,
  context: IncomingContext,
  graph: ArrangementGraph,
  images: List(ArrangementSegmentImage),
  vertex_tolerance: Float,
  minimum_chord: Float,
) -> Result(Option(#(ArrangementGraph, List(ArrangementSegmentImage))), Error) {
  case edges {
    [] -> Ok(None)
    [edge, ..rest] -> {
      let IncomingContext(piece: AtomicPiece(source_index:, ..), ..) = context
      let ArrangementEdge(id: edge_id, segment:, bounds: edge_bounds, ..) = edge
      case edge_is_image_of_source(images, source_index, edge_id) {
        True ->
          split_existing_edge_at_endpoint(
            rest,
            endpoint,
            context,
            graph,
            images,
            vertex_tolerance,
            minimum_chord,
          )
        False -> {
          use t <- result.try(
            case
              point_in_expanded_box(endpoint, edge_bounds, vertex_tolerance)
            {
              False -> Ok(None)
              True ->
                vertex_projects_to_piece_interior(
                  endpoint,
                  segment,
                  vertex_tolerance,
                )
            },
          )
          case t {
            None ->
              split_existing_edge_at_endpoint(
                rest,
                endpoint,
                context,
                graph,
                images,
                vertex_tolerance,
                minimum_chord,
              )
            Some(t) -> {
              use cuts <- result.try(effective_cut_parameters(
                segment,
                [t],
                vertex_tolerance,
                minimum_chord,
              ))
              case cuts {
                [] ->
                  split_existing_edge_at_endpoint(
                    rest,
                    endpoint,
                    context,
                    graph,
                    images,
                    vertex_tolerance,
                    minimum_chord,
                  )
                [_, ..] -> {
                  use result <- result.try(split_progressive_graph_edge(
                    graph,
                    images,
                    edge_id,
                    cuts,
                    vertex_tolerance,
                    minimum_chord,
                  ))
                  Ok(Some(result))
                }
              }
            }
          }
        }
      }
    }
  }
}

fn progressive_compare_edges(
  context: IncomingContext,
  edges: List(ArrangementEdge),
  graph: ArrangementGraph,
  images: List(ArrangementSegmentImage),
  vertex_tolerance: Float,
  minimum_chord: Float,
  endpoint_sliver_tolerance: Float,
) -> Result(ProgressivePieceResult, Error) {
  case edges {
    [] ->
      progressive_insert_piece_direct(
        context,
        graph,
        images,
        vertex_tolerance,
        minimum_chord,
      )
    [edge, ..rest] -> {
      use step <- result.try(progressive_compare_edge(
        context,
        edge,
        graph,
        images,
        vertex_tolerance,
        minimum_chord,
        endpoint_sliver_tolerance,
      ))
      case step {
        ProgressiveContinue(graph, images) ->
          progressive_compare_edges(
            context,
            rest,
            graph,
            images,
            vertex_tolerance,
            minimum_chord,
            endpoint_sliver_tolerance,
          )
        ProgressiveReplaceIncoming(graph, images, replacements) ->
          Ok(ProgressivePieceReplaced(graph, images, replacements))
      }
    }
  }
}

fn progressive_compare_edge(
  context: IncomingContext,
  edge: ArrangementEdge,
  graph: ArrangementGraph,
  images: List(ArrangementSegmentImage),
  vertex_tolerance: Float,
  minimum_chord: Float,
  endpoint_sliver_tolerance: Float,
) -> Result(ProgressiveEdgeStep, Error) {
  let IncomingContext(piece:, bounds:, start_match:, end_match:) = context
  let AtomicPiece(source_index:, ..) = piece
  let ArrangementEdge(id: edge_id, bounds: existing_bounds, ..) = edge
  case edge_is_image_of_source(images, source_index, edge_id) {
    True -> {
      Ok(ProgressiveContinue(graph, images))
    }
    False -> {
      case bounding_boxes_overlap(bounds, existing_bounds, vertex_tolerance) {
        False -> Ok(ProgressiveContinue(graph, images))
        True -> {
          case edge_matches_incoming_endpoints(edge, start_match, end_match) {
            True -> Ok(ProgressiveContinue(graph, images))
            False -> {
              use cuts <- result.try(pair_cuts_with_common_endpoint_sliver(
                piece,
                edge,
                start_match,
                end_match,
                vertex_tolerance,
                endpoint_sliver_tolerance,
              ))
              progressive_compare_edge_cuts(
                piece,
                edge,
                graph,
                images,
                cuts,
                vertex_tolerance,
                minimum_chord,
              )
            }
          }
        }
      }
    }
  }
}

fn edge_matches_incoming_endpoints(
  edge: ArrangementEdge,
  start_match: Option(Int),
  end_match: Option(Int),
) -> Bool {
  let ArrangementEdge(start_vertex:, end_vertex:, ..) = edge
  case start_match, end_match {
    Some(start), Some(end) ->
      start_vertex == start
      && end_vertex == end
      || start_vertex == end
      && end_vertex == start
    _, _ -> False
  }
}

type ProgressiveEdgeStep {
  ProgressiveContinue(
    graph: ArrangementGraph,
    images: List(ArrangementSegmentImage),
  )
  ProgressiveReplaceIncoming(
    graph: ArrangementGraph,
    images: List(ArrangementSegmentImage),
    replacements: List(AtomicPiece),
  )
}

fn progressive_compare_edge_cuts(
  piece: AtomicPiece,
  edge: ArrangementEdge,
  graph: ArrangementGraph,
  images: List(ArrangementSegmentImage),
  cuts: List(SegmentCut),
  tolerance: Float,
  minimum_chord: Float,
) -> Result(ProgressiveEdgeStep, Error) {
  let AtomicPiece(segment: incoming, ..) = piece
  let ArrangementEdge(id: edge_id, segment: existing, ..) = edge
  let existing_parameters =
    cut_parameters(cuts, 0, [])
    |> list.sort(float_compare)
  let incoming_parameters =
    cut_parameters(cuts, 1, [])
    |> list.sort(float_compare)
  use existing_parameters <- result.try(effective_cut_parameters(
    existing,
    existing_parameters,
    tolerance,
    minimum_chord,
  ))
  use incoming_parameters <- result.try(effective_cut_parameters(
    incoming,
    incoming_parameters,
    tolerance,
    minimum_chord,
  ))
  case existing_parameters, incoming_parameters {
    [], [] -> Ok(ProgressiveContinue(graph, images))
    _, _ -> {
      use #(graph, images) <- result.try(case existing_parameters {
        [_, ..] -> {
          split_progressive_graph_edge(
            graph,
            images,
            edge_id,
            existing_parameters,
            tolerance,
            minimum_chord,
          )
        }
        [] -> Ok(#(graph, images))
      })
      case incoming_parameters {
        [_, ..] -> {
          use replacements <- result.try(split_atomic_piece(
            piece,
            incoming_parameters,
            tolerance,
            minimum_chord,
          ))
          Ok(ProgressiveReplaceIncoming(graph, images, replacements))
        }
        [] -> Ok(ProgressiveReplaceIncoming(graph, images, [piece]))
      }
    }
  }
}

fn edge_is_image_of_source(
  images: List(ArrangementSegmentImage),
  source_index: Int,
  edge_id: Int,
) -> Bool {
  edge_is_image_of_source_loop(images, source_index, edge_id, index: 0)
}

fn edge_is_image_of_source_loop(
  images: List(ArrangementSegmentImage),
  source_index: Int,
  edge_id: Int,
  index index: Int,
) -> Bool {
  case images {
    [] -> False
    [ArrangementSegmentImage(edges:, ..), ..rest] -> {
      case index == source_index && references_contain_edge(edges, edge_id) {
        True -> True
        False ->
          edge_is_image_of_source_loop(
            rest,
            source_index,
            edge_id,
            index: index + 1,
          )
      }
    }
  }
}

fn references_contain_edge(
  references: List(DirectedEdgeReference),
  edge_id: Int,
) -> Bool {
  case references {
    [] -> False
    [DirectedEdgeReference(edge_id: candidate, ..), ..rest] -> {
      case candidate == edge_id {
        True -> True
        False -> references_contain_edge(rest, edge_id)
      }
    }
  }
}

fn effective_cut_parameters(
  segment: svg_path.Segment,
  cuts: List(Float),
  tolerance: Float,
  minimum_chord: Float,
) -> Result(List(Float), Error) {
  use parameters <- result.try(
    [0.0, 1.0, ..cuts]
    |> list.sort(float_compare)
    |> distinct_parameters(segment, tolerance, []),
  )
  use parameters <- result.try(retain_minimum_chord_cuts(
    segment,
    parameters,
    minimum_chord,
  ))
  let cuts = interior_distinct_parameters(parameters, [])
  case cuts {
    [] -> Ok([])
    [_, ..] -> {
      use produces_split <- result.try(cuts_produce_retained_split(
        segment,
        cuts,
        minimum_chord,
      ))
      case produces_split {
        True -> Ok(cuts)
        False -> Ok([])
      }
    }
  }
}

fn interior_distinct_parameters(
  parameters: List(Float),
  interior interior: List(Float),
) -> List(Float) {
  case parameters {
    [] | [_] | [_, _] -> list.reverse(interior)
    [_start, first_interior, ..rest] ->
      interior_distinct_parameters([first_interior, ..rest], [
        first_interior,
        ..interior
      ])
  }
}

fn retain_minimum_chord_cuts(
  segment: svg_path.Segment,
  parameters: List(Float),
  minimum_chord: Float,
) -> Result(List(Float), Error) {
  case parameters {
    [] | [_] -> Ok(parameters)
    [start, ..rest] ->
      retain_minimum_chord_cuts_loop(
        segment,
        rest,
        previous: start,
        retained: [start],
        minimum_chord:,
      )
  }
}

fn retain_minimum_chord_cuts_loop(
  segment: svg_path.Segment,
  parameters: List(Float),
  previous previous: Float,
  retained retained: List(Float),
  minimum_chord minimum_chord: Float,
) -> Result(List(Float), Error) {
  case parameters {
    [] -> Ok(list.reverse(retained))
    [last] -> {
      use long_enough <- result.try(parameter_chord_long_enough(
        segment,
        previous,
        last,
        minimum_chord,
      ))
      let retained = case long_enough {
        True -> [last, ..retained]
        False -> replace_retained_end(retained, last)
      }
      Ok(list.reverse(retained))
    }
    [candidate, next, ..rest] -> {
      use before_long_enough <- result.try(parameter_chord_long_enough(
        segment,
        previous,
        candidate,
        minimum_chord,
      ))
      use after_long_enough <- result.try(parameter_chord_long_enough(
        segment,
        candidate,
        next,
        minimum_chord,
      ))
      case before_long_enough && after_long_enough {
        True ->
          retain_minimum_chord_cuts_loop(
            segment,
            [next, ..rest],
            previous: candidate,
            retained: [candidate, ..retained],
            minimum_chord:,
          )
        False ->
          retain_minimum_chord_cuts_loop(
            segment,
            [next, ..rest],
            previous:,
            retained:,
            minimum_chord:,
          )
      }
    }
  }
}

fn replace_retained_end(retained: List(Float), end: Float) -> List(Float) {
  case retained {
    [] -> [end]
    [_old_end, ..rest] -> [end, ..rest]
  }
}

fn parameter_chord_long_enough(
  segment: svg_path.Segment,
  from from: Float,
  to to: Float,
  minimum_chord minimum_chord: Float,
) -> Result(Bool, Error) {
  use start <- result.try(
    svg_path.segment_point(segment, at: from)
    |> result.map_error(PathError),
  )
  use end <- result.try(
    svg_path.segment_point(segment, at: to)
    |> result.map_error(PathError),
  )
  Ok(point.distance(start, end) >=. minimum_chord)
}

fn cuts_produce_retained_split(
  segment: svg_path.Segment,
  cuts: List(Float),
  minimum_chord: Float,
) -> Result(Bool, Error) {
  use split <- result.try(
    svg_path.segment_between_many_inside(
      segment,
      between: [0.0, 1.0, ..cuts] |> list.sort(float_compare),
    )
    |> result.map_error(PathError),
  )
  let retained = retained_split_segments(split, minimum_chord, retained: [])
  case retained {
    [_, _, ..] -> Ok(True)
    _ -> Ok(False)
  }
}

fn split_progressive_graph_edge(
  graph: ArrangementGraph,
  images: List(ArrangementSegmentImage),
  edge_id: Int,
  cuts: List(Float),
  tolerance: Float,
  minimum_chord: Float,
) -> Result(#(ArrangementGraph, List(ArrangementSegmentImage)), Error) {
  let ArrangementGraph(vertices:, edges:, ..) = graph
  use edge <- result.try(arrangement_edge_by_id(edges, edge_id))
  let ArrangementEdge(
    segment:,
    forward_multiplicity:,
    reverse_multiplicity:,
    ..,
  ) = edge
  use parameters <- result.try(
    [0.0, 1.0, ..cuts]
    |> list.sort(float_compare)
    |> distinct_parameters(segment, tolerance, []),
  )
  use split <- result.try(
    svg_path.segment_between_many_inside(segment, between: parameters)
    |> result.map_error(PathError),
  )
  let retained = retained_split_segments(split, minimum_chord, retained: [])
  case retained {
    [] -> Error(SegmentTooShort(chord: 0.0, minimum: minimum_chord))
    [_, ..] -> {
      let next_id = next_arrangement_edge_id(edges)
      use #(vertices, replacements, references) <- result.try(
        progressive_replacement_edges(
          retained,
          edge_id,
          next_id,
          forward_multiplicity,
          reverse_multiplicity,
          vertices,
          tolerance,
          minimum_chord,
          edges: [],
          references: [],
        ),
      )
      let graph =
        ArrangementGraph(
          vertices:,
          edges: replace_edge_with(edges, edge_id, list.reverse(replacements)),
          cyclic_orders: [],
        )
      let images =
        expand_edge_references(images, edge_id, list.reverse(references))
      Ok(#(graph, images))
    }
  }
}

fn next_arrangement_edge_id(edges: List(ArrangementEdge)) -> Int {
  edges
  |> list.fold(0, fn(max_id, edge) {
    let ArrangementEdge(id:, ..) = edge
    int.max(max_id, id + 1)
  })
}

fn retained_split_segments(
  segments: List(svg_path.Segment),
  minimum_chord: Float,
  retained retained: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case segments {
    [] -> list.reverse(retained)
    [first, ..rest] -> {
      let retained = case
        svg_path.segment_chord_length(first) >=. minimum_chord
      {
        True -> [first, ..retained]
        False -> retained
      }
      retained_split_segments(rest, minimum_chord, retained:)
    }
  }
}

fn progressive_replacement_edges(
  segments: List(svg_path.Segment),
  first_id: Int,
  next_id: Int,
  forward_multiplicity: Int,
  reverse_multiplicity: Int,
  vertices: List(ArrangementVertex),
  tolerance: Float,
  minimum_chord: Float,
  edges edges: List(ArrangementEdge),
  references references: List(DirectedEdgeReference),
) -> Result(
  #(List(ArrangementVertex), List(ArrangementEdge), List(DirectedEdgeReference)),
  Error,
) {
  case segments {
    [] -> Ok(#(vertices, edges, references))
    [segment, ..rest] -> {
      let id = case edges {
        [] -> first_id
        [_, ..] -> next_id + list.length(edges) - 1
      }
      let start = svg_path.segment_start(segment)
      let end = svg_path.segment_end(segment)
      let chord = svg_path.segment_chord_length(segment)
      case chord <. minimum_chord {
        True ->
          progressive_replacement_edges(
            rest,
            first_id,
            next_id,
            forward_multiplicity,
            reverse_multiplicity,
            vertices,
            tolerance,
            minimum_chord,
            edges:,
            references:,
          )
        False -> {
          let #(vertices, start_vertex) =
            attach_vertex(vertices, start, tolerance)
          let #(vertices, end_vertex) = attach_vertex(vertices, end, tolerance)
          case start_vertex == end_vertex {
            True ->
              progressive_replacement_edges(
                rest,
                first_id,
                next_id,
                forward_multiplicity,
                reverse_multiplicity,
                vertices,
                tolerance,
                minimum_chord,
                edges:,
                references:,
              )
            False ->
              progressive_replacement_edges(
                rest,
                first_id,
                next_id,
                forward_multiplicity,
                reverse_multiplicity,
                vertices,
                tolerance,
                minimum_chord,
                edges: [
                  ArrangementEdge(
                    id:,
                    segment:,
                    bounds: segment_bounding_box_assert(segment),
                    start_vertex:,
                    end_vertex:,
                    forward_multiplicity:,
                    reverse_multiplicity:,
                  ),
                  ..edges
                ],
                references: [
                  DirectedEdgeReference(edge_id: id, reversed: False),
                  ..references
                ],
              )
          }
        }
      }
    }
  }
}

fn arrangement_edge_by_id(
  edges: List(ArrangementEdge),
  edge_id: Int,
) -> Result(ArrangementEdge, Error) {
  case edges {
    [] -> Error(MissingEdge(edge_id))
    [first, ..rest] -> {
      let ArrangementEdge(id:, ..) = first
      case id == edge_id {
        True -> Ok(first)
        False -> arrangement_edge_by_id(rest, edge_id)
      }
    }
  }
}

fn replace_edge_with(
  edges: List(ArrangementEdge),
  edge_id: Int,
  replacements: List(ArrangementEdge),
) -> List(ArrangementEdge) {
  case edges {
    [] -> []
    [first, ..rest] -> {
      let ArrangementEdge(id:, ..) = first
      case id == edge_id {
        True -> list.append(replacements, rest)
        False -> [first, ..replace_edge_with(rest, edge_id, replacements)]
      }
    }
  }
}

fn expand_edge_references(
  images: List(ArrangementSegmentImage),
  edge_id: Int,
  replacements: List(DirectedEdgeReference),
) -> List(ArrangementSegmentImage) {
  images
  |> list.map(fn(image) {
    let ArrangementSegmentImage(
      path_index:,
      subpath_index:,
      segment_index:,
      edges:,
    ) = image
    ArrangementSegmentImage(
      path_index:,
      subpath_index:,
      segment_index:,
      edges: expand_references(edges, edge_id, replacements, expanded: []),
    )
  })
}

fn expand_references(
  references: List(DirectedEdgeReference),
  edge_id: Int,
  replacements: List(DirectedEdgeReference),
  expanded expanded: List(DirectedEdgeReference),
) -> List(DirectedEdgeReference) {
  case references {
    [] -> list.reverse(expanded)
    [first, ..rest] -> {
      let DirectedEdgeReference(edge_id: candidate, reversed:) = first
      let expanded = case candidate == edge_id {
        True -> {
          let replacement = case reversed {
            False -> replacements
            True -> reverse_directed_references(replacements)
          }
          list.append(list.reverse(replacement), expanded)
        }
        False -> [first, ..expanded]
      }
      expand_references(rest, edge_id, replacements, expanded:)
    }
  }
}

fn reverse_directed_references(
  references: List(DirectedEdgeReference),
) -> List(DirectedEdgeReference) {
  references
  |> list.reverse
  |> list.map(fn(reference) {
    let DirectedEdgeReference(edge_id:, reversed:) = reference
    DirectedEdgeReference(edge_id:, reversed: !reversed)
  })
}

fn index_paths(paths: List(svg_path.Path)) -> List(IndexedSegment) {
  index_paths_loop(paths, path_index: 0, index: 0, indexed: [])
}

fn index_flat_segments(
  segments: List(svg_path.Segment),
) -> List(IndexedSegment) {
  index_flat_segments_loop(segments, index: 0, indexed: [])
}

fn index_flat_segments_loop(
  segments: List(svg_path.Segment),
  index index: Int,
  indexed indexed: List(IndexedSegment),
) -> List(IndexedSegment) {
  case segments {
    [] -> list.reverse(indexed)
    [first, ..rest] ->
      index_flat_segments_loop(rest, index: index + 1, indexed: [
        IndexedSegment(
          index:,
          path_index: 0,
          subpath_index: 0,
          segment_index: index,
          segment: first,
        ),
        ..indexed
      ])
  }
}

fn public_segment_images(
  indexed: List(IndexedSegment),
  images: List(ArrangementSourceSegmentImage),
  images converted: List(ArrangementSegmentImage),
) -> Result(List(ArrangementSegmentImage), Error) {
  case images {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use converted_image <- result.try(public_segment_image(indexed, first))
      public_segment_images(indexed, rest, images: [
        converted_image,
        ..converted
      ])
    }
  }
}

fn public_segment_image(
  indexed: List(IndexedSegment),
  image: ArrangementSourceSegmentImage,
) -> Result(ArrangementSegmentImage, Error) {
  let ArrangementSourceSegmentImage(segment_index:, edges:) = image
  use source <- result.try(
    indexed_segment_at(indexed, segment_index)
    |> result.map_error(fn(_) { InternalNormalizationError }),
  )
  let IndexedSegment(path_index:, subpath_index:, segment_index:, ..) = source
  Ok(ArrangementSegmentImage(
    path_index:,
    subpath_index:,
    segment_index:,
    edges: list.map(edges, fn(edge) {
      let ArrangementSegmentEdgeImage(edge_id:, reversed:, ..) = edge
      DirectedEdgeReference(edge_id:, reversed:)
    }),
  ))
}

fn indexed_segment_at(
  indexed: List(IndexedSegment),
  target: Int,
) -> Result(IndexedSegment, Nil) {
  case indexed {
    [] -> Error(Nil)
    [first, ..rest] -> {
      let IndexedSegment(index:, ..) = first
      case index == target {
        True -> Ok(first)
        False -> indexed_segment_at(rest, target)
      }
    }
  }
}

fn index_paths_loop(
  paths: List(svg_path.Path),
  path_index path_index: Int,
  index index: Int,
  indexed indexed: List(IndexedSegment),
) -> List(IndexedSegment) {
  case paths {
    [] -> list.reverse(indexed)
    [first, ..rest] -> {
      let #(index, indexed) =
        index_subpaths(
          svg_path.path_subpaths(first),
          path_index,
          subpath_index: 0,
          index:,
          indexed:,
        )
      index_paths_loop(rest, path_index: path_index + 1, index:, indexed:)
    }
  }
}

fn index_subpaths(
  subpaths: List(svg_path.Subpath),
  path_index: Int,
  subpath_index subpath_index: Int,
  index index: Int,
  indexed indexed: List(IndexedSegment),
) -> #(Int, List(IndexedSegment)) {
  case subpaths {
    [] -> #(index, indexed)
    [first, ..rest] -> {
      let #(index, indexed) =
        index_segments(
          svg_path.subpath_segments(first),
          path_index,
          subpath_index,
          segment_index: 0,
          index:,
          indexed:,
        )
      index_subpaths(
        rest,
        path_index,
        subpath_index: subpath_index + 1,
        index:,
        indexed:,
      )
    }
  }
}

fn index_segments(
  segments: List(svg_path.Segment),
  path_index: Int,
  subpath_index: Int,
  segment_index segment_index: Int,
  index index: Int,
  indexed indexed: List(IndexedSegment),
) -> #(Int, List(IndexedSegment)) {
  case segments {
    [] -> #(index, indexed)
    [first, ..rest] ->
      index_segments(
        rest,
        path_index,
        subpath_index,
        segment_index: segment_index + 1,
        index: index + 1,
        indexed: [
          IndexedSegment(
            index:,
            path_index:,
            subpath_index:,
            segment_index:,
            segment: first,
          ),
          ..indexed
        ],
      )
  }
}

fn pair_cuts_with_common_endpoint_sliver(
  piece: AtomicPiece,
  edge: ArrangementEdge,
  incoming_start: Option(Int),
  incoming_end: Option(Int),
  vertex_tolerance: Float,
  endpoint_sliver_tolerance: Float,
) -> Result(List(SegmentCut), Error) {
  let AtomicPiece(segment: incoming, ..) = piece
  let ArrangementEdge(segment: existing, ..) = edge
  use found <- result.try(
    case
      intersections.segment_with(
        existing,
        incoming,
        options: intersection_options_for_graph_tolerance(vertex_tolerance),
      )
    {
      Error(svg_path.OverlappingSegments) ->
        case edge_shares_incoming_endpoint(edge, incoming_start, incoming_end) {
          True -> Ok([])
          False -> Error(PathError(svg_path.OverlappingSegments))
        }
      Ok(found) -> Ok(found)
      Error(error) -> Error(PathError(error))
    },
  )
  pair_cuts_from_hits(
    found,
    edge,
    incoming,
    incoming_start,
    incoming_end,
    endpoint_sliver_tolerance,
    [],
  )
}

fn edge_shares_incoming_endpoint(
  edge: ArrangementEdge,
  incoming_start: Option(Int),
  incoming_end: Option(Int),
) -> Bool {
  let ArrangementEdge(start_vertex:, end_vertex:, ..) = edge
  option_equals_int(incoming_start, start_vertex)
  || option_equals_int(incoming_start, end_vertex)
  || option_equals_int(incoming_end, start_vertex)
  || option_equals_int(incoming_end, end_vertex)
}

fn option_equals_int(value: Option(Int), target: Int) -> Bool {
  case value {
    Some(candidate) -> candidate == target
    None -> False
  }
}

fn pair_cuts_from_hits(
  hits: List(svg_path.SegmentIntersection),
  edge: ArrangementEdge,
  incoming: svg_path.Segment,
  incoming_start: Option(Int),
  incoming_end: Option(Int),
  endpoint_sliver_tolerance: Float,
  collected: List(SegmentCut),
) -> Result(List(SegmentCut), Error) {
  case hits {
    [] -> Ok(list.reverse(collected))
    [hit, ..rest] -> {
      use is_common_endpoint_sliver <- result.try(
        intersection_cut_is_common_endpoint_sliver(
          edge,
          incoming,
          incoming_start,
          incoming_end,
          hit,
          endpoint_sliver_tolerance,
        ),
      )
      case is_common_endpoint_sliver {
        True ->
          pair_cuts_from_hits(
            rest,
            edge,
            incoming,
            incoming_start,
            incoming_end,
            endpoint_sliver_tolerance,
            collected,
          )
        False -> {
          let svg_path.SegmentIntersection(left_t:, right_t:, ..) = hit
          pair_cuts_from_hits(
            rest,
            edge,
            incoming,
            incoming_start,
            incoming_end,
            endpoint_sliver_tolerance,
            [
              SegmentCut(index: 1, t: right_t),
              SegmentCut(index: 0, t: left_t),
              ..collected
            ],
          )
        }
      }
    }
  }
}

fn intersection_cut_is_common_endpoint_sliver(
  edge: ArrangementEdge,
  _incoming: svg_path.Segment,
  incoming_start: Option(Int),
  incoming_end: Option(Int),
  hit: svg_path.SegmentIntersection,
  endpoint_sliver_tolerance: Float,
) -> Result(Bool, Error) {
  case endpoint_sliver_tolerance <=. 0.0 {
    True -> Ok(False)
    False -> {
      let ArrangementEdge(start_vertex:, end_vertex:, ..) = edge
      let svg_path.SegmentIntersection(left_t:, right_t:, ..) = hit
      let left_sides = endpoint_sliver_sides(left_t, endpoint_sliver_tolerance)
      let right_sides =
        endpoint_sliver_sides(right_t, endpoint_sliver_tolerance)
      Ok(endpoint_side_lists_share_vertex(
        left_sides,
        right_sides,
        start_vertex,
        end_vertex,
        incoming_start,
        incoming_end,
      ))
    }
  }
}

fn endpoint_sliver_sides(
  t: Float,
  endpoint_sliver_tolerance: Float,
) -> List(EndpointSide) {
  let sides = case t <=. endpoint_sliver_tolerance {
    True -> [StartEndpoint]
    False -> []
  }
  case 1.0 -. t <=. endpoint_sliver_tolerance {
    True -> [EndEndpoint, ..sides]
    False -> sides
  }
}

fn endpoint_side_lists_share_vertex(
  left_sides: List(EndpointSide),
  right_sides: List(EndpointSide),
  left_start_vertex: Int,
  left_end_vertex: Int,
  right_start_vertex: Option(Int),
  right_end_vertex: Option(Int),
) -> Bool {
  left_sides
  |> list.any(fn(left) {
    right_sides
    |> list.any(fn(right) {
      endpoint_side_vertex(left, Some(left_start_vertex), Some(left_end_vertex))
      == endpoint_side_vertex(right, right_start_vertex, right_end_vertex)
    })
  })
}

fn endpoint_side_vertex(
  side: EndpointSide,
  start_vertex: Option(Int),
  end_vertex: Option(Int),
) -> Option(Int) {
  case side {
    StartEndpoint -> start_vertex
    EndEndpoint -> end_vertex
  }
}

fn unique_vertex_for_endpoint(
  vertices: List(ArrangementVertex),
  endpoint: svg_path.Point,
  vertex_tolerance: Float,
) -> Result(Option(Int), Error) {
  unique_vertex_for_endpoint_loop(
    vertices,
    endpoint,
    vertex_tolerance,
    found: None,
  )
}

fn unique_vertex_for_endpoint_loop(
  vertices: List(ArrangementVertex),
  endpoint: svg_path.Point,
  vertex_tolerance: Float,
  found found: Option(Int),
) -> Result(Option(Int), Error) {
  case vertices {
    [] -> Ok(found)
    [ArrangementVertex(id:, point:, ..), ..rest] -> {
      case point.distance(endpoint, point) <=. vertex_tolerance, found {
        True, None ->
          unique_vertex_for_endpoint_loop(
            rest,
            endpoint,
            vertex_tolerance,
            found: Some(id),
          )
        True, Some(_) -> Error(InternalNormalizationError)
        False, _ ->
          unique_vertex_for_endpoint_loop(
            rest,
            endpoint,
            vertex_tolerance,
            found:,
          )
      }
    }
  }
}

fn intersection_options_for_graph_tolerance(
  tolerance: Float,
) -> intersections.IntersectionOptions {
  let defaults = intersections.default_options()
  intersections.IntersectionOptions(
    tolerance: tolerance /. 2.0,
    max_depth: defaults.max_depth,
    parameter_snap: defaults.parameter_snap,
  )
}

fn split_atomic_piece(
  piece: AtomicPiece,
  cuts: List(Float),
  tolerance: Float,
  minimum_chord: Float,
) -> Result(List(AtomicPiece), Error) {
  let AtomicPiece(
    source_index:,
    path_index:,
    subpath_index:,
    segment_index:,
    source_from:,
    source_to:,
    segment:,
  ) = piece
  use parameters <- result.try(
    [0.0, 1.0, ..cuts]
    |> list.sort(float_compare)
    |> distinct_parameters(segment, tolerance, []),
  )
  use split <- result.try(
    svg_path.segment_between_many_inside(segment, between: parameters)
    |> result.map_error(PathError),
  )
  Ok(
    split_atomic_pieces_for_parameters(
      split,
      parameters,
      source_index,
      path_index,
      subpath_index,
      segment_index,
      source_from,
      source_to,
      minimum_chord,
      pieces: [],
    ),
  )
}

fn split_atomic_pieces_for_parameters(
  segments: List(svg_path.Segment),
  parameters: List(Float),
  source_index: Int,
  path_index: Int,
  subpath_index: Int,
  segment_index: Int,
  source_from: Float,
  source_to: Float,
  minimum_chord: Float,
  pieces pieces: List(AtomicPiece),
) -> List(AtomicPiece) {
  case segments, parameters {
    [segment, ..segment_rest], [from, to, ..parameter_rest] -> {
      let global_from = interpolate_float(source_from, source_to, from)
      let global_to = interpolate_float(source_from, source_to, to)
      let pieces = case
        point.distance(
          svg_path.segment_start(segment),
          svg_path.segment_end(segment),
        )
        >=. minimum_chord
      {
        True -> [
          AtomicPiece(
            source_index:,
            path_index:,
            subpath_index:,
            segment_index:,
            source_from: global_from,
            source_to: global_to,
            segment:,
          ),
          ..pieces
        ]
        False -> pieces
      }
      split_atomic_pieces_for_parameters(
        segment_rest,
        [to, ..parameter_rest],
        source_index,
        path_index,
        subpath_index,
        segment_index,
        source_from,
        source_to,
        minimum_chord,
        pieces:,
      )
    }
    _, _ -> list.reverse(pieces)
  }
}

fn interpolate_float(from: Float, to: Float, at t: Float) -> Float {
  from +. { to -. from } *. t
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
  segment: svg_path.Segment,
  tolerance: Float,
  distinct: List(Float),
) -> Result(List(Float), Error) {
  case parameters, distinct {
    [], _ -> Ok(list.reverse(distinct))
    [first, ..rest], [] ->
      distinct_parameters(rest, segment, tolerance, [first])
    [first, ..rest], [previous, ..] -> {
      use between <- result.try(
        svg_path.segment_between(segment, from: previous, to: first)
        |> result.map_error(PathError),
      )
      use motion <- result.try(segment_taxicab_diameter(between))
      case motion <=. tolerance {
        True -> distinct_parameters(rest, segment, tolerance, distinct)
        False ->
          distinct_parameters(rest, segment, tolerance, [first, ..distinct])
      }
    }
  }
}

fn segment_taxicab_diameter(segment: svg_path.Segment) -> Result(Float, Error) {
  case segment {
    svg_path.Arc(start:, end:, ..) if start == end -> Ok(0.0)
    _ -> {
      use bounds <- result.try(
        svg_path.segment_bounding_box(segment) |> result.map_error(PathError),
      )
      Ok(svg_path.bounding_box_diameter(bounds))
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

fn initial_segment_images(
  segments: List(IndexedSegment),
) -> List(ArrangementSegmentImage) {
  list.map(segments, fn(segment) {
    let IndexedSegment(path_index:, subpath_index:, segment_index:, ..) =
      segment
    ArrangementSegmentImage(
      path_index:,
      subpath_index:,
      segment_index:,
      edges: [],
    )
  })
}

fn insert_corresponding_piece_with_ref(
  context: IncomingContext,
  graph: ArrangementGraph,
  tolerance: Float,
  minimum_chord: Float,
) -> Result(#(ArrangementGraph, Int, Bool), Error) {
  let ArrangementGraph(edges:, ..) = graph
  let IncomingContext(piece: AtomicPiece(segment:, ..), ..) = context
  use match <- result.try(find_corresponding_edge(context, edges, tolerance))
  case match {
    None -> {
      let edge_id = next_arrangement_edge_id(edges)
      use graph <- result.try(insert_atomic_segment(
        graph,
        segment,
        tolerance:,
        minimum_chord:,
      ))
      Ok(#(graph, edge_id, False))
    }
    Some(#(edge_id, same_direction)) ->
      Ok(#(
        increment_edge_by_id(graph, edge_id, same_direction),
        edge_id,
        !same_direction,
      ))
  }
}

fn find_corresponding_edge(
  context: IncomingContext,
  edges: List(ArrangementEdge),
  tolerance: Float,
) -> Result(Option(#(Int, Bool)), Error) {
  let IncomingContext(
    piece: AtomicPiece(segment:, ..),
    start_match:,
    end_match:,
    ..,
  ) = context
  case start_match, end_match {
    Some(start_vertex), Some(end_vertex) ->
      find_corresponding_edge_loop(
        edges,
        segment,
        start_vertex,
        end_vertex,
        tolerance,
      )
    _, _ -> Ok(None)
  }
}

fn find_corresponding_edge_loop(
  edges: List(ArrangementEdge),
  segment: svg_path.Segment,
  start_vertex: Int,
  end_vertex: Int,
  tolerance: Float,
) -> Result(Option(#(Int, Bool)), Error) {
  case edges {
    [] -> Ok(None)
    [edge, ..rest] -> {
      let ArrangementEdge(
        id:,
        segment: existing,
        start_vertex: existing_start,
        end_vertex: existing_end,
        ..,
      ) = edge
      let direction = case
        existing_start == start_vertex && existing_end == end_vertex,
        existing_start == end_vertex && existing_end == start_vertex
      {
        True, _ -> Some(True)
        _, True -> Some(False)
        False, False -> None
      }
      case direction {
        None ->
          find_corresponding_edge_loop(
            rest,
            segment,
            start_vertex,
            end_vertex,
            tolerance,
          )
        Some(same_direction) -> {
          use overlaps <- result.try(check_edge_correspondence(
            existing,
            segment,
            same_direction,
            tolerance,
          ))
          case overlaps {
            True -> Ok(Some(#(id, same_direction)))
            False ->
              find_corresponding_edge_loop(
                rest,
                segment,
                start_vertex,
                end_vertex,
                tolerance,
              )
          }
        }
      }
    }
  }
}

fn check_edge_correspondence(
  existing: svg_path.Segment,
  segment: svg_path.Segment,
  same_direction: Bool,
  tolerance: Float,
) -> Result(Bool, Error) {
  let #(right_from, right_to) = case same_direction {
    True -> #(0.0, 1.0)
    False -> #(1.0, 0.0)
  }
  use overlap <- result.try(
    overlaps.check_parameter_correspondence(
      existing,
      segment,
      left_from: 0.0,
      left_to: 1.0,
      right_from:,
      right_to:,
      tolerance:,
      samples: 7,
    )
    |> result.map_error(PathError),
  )
  case overlap {
    Some(_) -> Ok(True)
    None -> Ok(False)
  }
}

fn append_segment_image_reference(
  images: List(ArrangementSegmentImage),
  source_index: Int,
  reference: DirectedEdgeReference,
) -> List(ArrangementSegmentImage) {
  images
  |> list.index_map(fn(image, index) {
    case index == source_index {
      False -> image
      True -> {
        let ArrangementSegmentImage(
          path_index:,
          subpath_index:,
          segment_index:,
          edges:,
        ) = image
        ArrangementSegmentImage(
          path_index:,
          subpath_index:,
          segment_index:,
          edges: list.append(edges, [reference]),
        )
      }
    }
  })
}

fn source_segment_images(
  segments: List(svg_path.Segment),
  graph: ArrangementGraph,
  images: List(ArrangementSegmentImage),
  tolerance: Float,
) -> Result(List(ArrangementSourceSegmentImage), Error) {
  images
  |> list.index_map(fn(image, index) {
    case segment_at(segments, index) {
      Ok(source) -> source_segment_image(source, graph, image, index, tolerance)
      Error(Nil) -> Error(InternalNormalizationError)
    }
  })
  |> result.all
  |> result.map(mark_segment_ownership)
}

fn source_segment_image(
  source: svg_path.Segment,
  graph: ArrangementGraph,
  image: ArrangementSegmentImage,
  index: Int,
  tolerance: Float,
) -> Result(ArrangementSourceSegmentImage, Error) {
  use edges <- result.try(segment_image_edges(
    ArrangementGraphBuild(graph:, segment_images: []),
    image,
  ))
  use edges <- result.try(
    edges
    |> list.map(fn(edge) {
      let #(edge, reversed) = edge
      source_segment_edge_image(source, edge, reversed, tolerance)
    })
    |> result.all,
  )
  let edges =
    list.filter_map(edges, fn(edge) {
      case edge {
        Some(edge) -> Ok(edge)
        None -> Error(Nil)
      }
    })
  Ok(ArrangementSourceSegmentImage(segment_index: index, edges:))
}

fn segment_at(
  segments: List(svg_path.Segment),
  target: Int,
) -> Result(svg_path.Segment, Nil) {
  case segments, target {
    [], _ -> Error(Nil)
    [first, ..], 0 -> Ok(first)
    [_, ..rest], _ -> segment_at(rest, target - 1)
  }
}

fn source_segment_edge_image(
  source: svg_path.Segment,
  edge: ArrangementEdge,
  reversed: Bool,
  tolerance: Float,
) -> Result(Option(ArrangementSegmentEdgeImage), Error) {
  let ArrangementEdge(id: edge_id, segment:, ..) = edge
  use start_projection <- result.try(source_projection(
    svg_path.segment_start(segment),
    source,
  ))
  use end_projection <- result.try(source_projection(
    svg_path.segment_end(segment),
    source,
  ))
  let svg_path.SegmentProjection(t: ta_start, distance: start_distance, ..) =
    start_projection
  let svg_path.SegmentProjection(t: ta_end, distance: end_distance, ..) =
    end_projection
  case start_distance <=. tolerance && end_distance <=. tolerance {
    False -> Ok(None)
    True -> {
      let #(ta, tb) = case reversed {
        True -> #(ta_end, ta_start)
        False -> #(ta_start, ta_end)
      }
      Ok(
        Some(ArrangementSegmentEdgeImage(
          ta:,
          tb:,
          edge_id:,
          reversed:,
          own: False,
        )),
      )
    }
  }
}

fn source_projection(
  point: svg_path.Point,
  source: svg_path.Segment,
) -> Result(svg_path.SegmentProjection, Error) {
  svg_path.segment_projection(point, to: source)
  |> result.map_error(PathError)
}

fn mark_segment_ownership(
  images: List(ArrangementSourceSegmentImage),
) -> List(ArrangementSourceSegmentImage) {
  let #(images, _) =
    images
    |> list.fold(#([], []), fn(state, image) {
      let #(collected, owned_edges) = state
      let #(image, owned_edges) = mark_image_ownership(image, owned_edges)
      #([image, ..collected], owned_edges)
    })
  list.reverse(images)
}

fn mark_image_ownership(
  image: ArrangementSourceSegmentImage,
  owned_edges: List(Int),
) -> #(ArrangementSourceSegmentImage, List(Int)) {
  let ArrangementSourceSegmentImage(segment_index:, edges:) = image
  let #(edges, owned_edges) =
    edges
    |> list.fold(#([], owned_edges), fn(state, edge) {
      let #(collected, owned_edges) = state
      let ArrangementSegmentEdgeImage(ta:, tb:, edge_id:, reversed:, ..) = edge
      let own = !int_list_contains(owned_edges, edge_id)
      let owned_edges = case own {
        True -> [edge_id, ..owned_edges]
        False -> owned_edges
      }
      #(
        [
          ArrangementSegmentEdgeImage(ta:, tb:, edge_id:, reversed:, own:),
          ..collected
        ],
        owned_edges,
      )
    })
  #(
    ArrangementSourceSegmentImage(segment_index:, edges: list.reverse(edges)),
    owned_edges,
  )
}

fn edge_source_images(
  graph: ArrangementGraph,
  segment_images: List(ArrangementSourceSegmentImage),
) -> List(ArrangementEdgeImage) {
  let ArrangementGraph(edges:, ..) = graph
  edges
  |> list.map(fn(edge) {
    let ArrangementEdge(id:, ..) = edge
    ArrangementEdgeImage(edge_id: id, sources: edge_sources(id, segment_images))
  })
}

fn edge_sources(
  edge_id: Int,
  images: List(ArrangementSourceSegmentImage),
) -> List(ArrangementEdgeSourceImage) {
  images
  |> list.fold([], fn(collected, image) {
    let ArrangementSourceSegmentImage(segment_index:, edges:) = image
    let matches =
      edges
      |> list.filter_map(fn(edge) {
        let ArrangementSegmentEdgeImage(ta:, tb:, edge_id: id, reversed:, ..) =
          edge
        case id == edge_id {
          True -> {
            let left = float.min(ta, tb)
            let right = float.max(ta, tb)
            Ok(ArrangementEdgeSourceImage(
              segment_index:,
              ta: left,
              tb: right,
              reversed:,
            ))
          }
          False -> Error(Nil)
        }
      })
    list.append(collected, matches)
  })
}

fn certify_segment_build(
  graph: ArrangementGraph,
  segments: List(svg_path.Segment),
  segment_images: List(ArrangementSourceSegmentImage),
  edge_images: List(ArrangementEdgeImage),
  tolerance: Float,
) -> Result(Nil, Error) {
  use _ <- result.try(certify_segment_edges_exist(graph, segment_images))
  use _ <- result.try(certify_source_segment_images_match_edge_images(
    segment_images,
    edge_images,
  ))
  use _ <- result.try(certify_edge_source_images_match_segment_images(
    edge_images,
    segment_images,
  ))
  certify_segment_image_geometry(graph, segments, segment_images, tolerance)
}

fn certify_segment_edges_exist(
  graph: ArrangementGraph,
  segment_images: List(ArrangementSourceSegmentImage),
) -> Result(Nil, Error) {
  let ArrangementGraph(edges:, ..) = graph
  segment_images
  |> list.map(fn(image) {
    let ArrangementSourceSegmentImage(edges: references, ..) = image
    references
    |> list.map(fn(reference) {
      let ArrangementSegmentEdgeImage(edge_id:, ..) = reference
      case list.find(edges, fn(edge) { edge.id == edge_id }) {
        Ok(_) -> Ok(Nil)
        Error(Nil) -> Error(MissingEdge(edge_id))
      }
    })
    |> result.all
    |> result.map(fn(_) { Nil })
  })
  |> result.all
  |> result.map(fn(_) { Nil })
}

fn certify_source_segment_images_match_edge_images(
  segment_images: List(ArrangementSourceSegmentImage),
  edge_images: List(ArrangementEdgeImage),
) -> Result(Nil, Error) {
  segment_images
  |> list.map(fn(image) {
    let ArrangementSourceSegmentImage(segment_index:, edges:) = image
    edges
    |> list.map(fn(edge) {
      let ArrangementSegmentEdgeImage(edge_id:, ta:, tb:, reversed:, ..) = edge
      case
        edge_source_images_contain_source(
          edge_images,
          edge_id,
          segment_index,
          float.min(ta, tb),
          float.max(ta, tb),
          reversed,
        )
      {
        True -> Ok(Nil)
        False -> Error(InternalNormalizationError)
      }
    })
    |> result.all
    |> result.map(fn(_) { Nil })
  })
  |> result.all
  |> result.map(fn(_) { Nil })
}

fn certify_edge_source_images_match_segment_images(
  edge_images: List(ArrangementEdgeImage),
  segment_images: List(ArrangementSourceSegmentImage),
) -> Result(Nil, Error) {
  edge_images
  |> list.map(fn(image) {
    let ArrangementEdgeImage(edge_id:, sources:) = image
    sources
    |> list.map(fn(source) {
      let ArrangementEdgeSourceImage(segment_index:, ta:, tb:, reversed:) =
        source
      case
        source_segment_images_contain_edge(
          segment_images,
          segment_index,
          edge_id,
          ta,
          tb,
          reversed,
        )
      {
        True -> Ok(Nil)
        False -> Error(InternalNormalizationError)
      }
    })
    |> result.all
    |> result.map(fn(_) { Nil })
  })
  |> result.all
  |> result.map(fn(_) { Nil })
}

fn edge_source_images_contain_source(
  edge_images: List(ArrangementEdgeImage),
  edge_id: Int,
  segment_index: Int,
  ta: Float,
  tb: Float,
  reversed: Bool,
) -> Bool {
  edge_images
  |> list.any(fn(image) {
    let ArrangementEdgeImage(edge_id: candidate, sources:) = image
    candidate == edge_id
    && sources
    |> list.any(fn(source) {
      let ArrangementEdgeSourceImage(
        segment_index: candidate_segment,
        ta: candidate_ta,
        tb: candidate_tb,
        reversed: candidate_reversed,
      ) = source
      candidate_segment == segment_index
      && candidate_ta == ta
      && candidate_tb == tb
      && candidate_reversed == reversed
    })
  })
}

fn source_segment_images_contain_edge(
  segment_images: List(ArrangementSourceSegmentImage),
  segment_index: Int,
  edge_id: Int,
  ta: Float,
  tb: Float,
  reversed: Bool,
) -> Bool {
  segment_images
  |> list.any(fn(image) {
    let ArrangementSourceSegmentImage(segment_index: candidate_segment, edges:) =
      image
    candidate_segment == segment_index
    && edges
    |> list.any(fn(edge) {
      let ArrangementSegmentEdgeImage(
        edge_id: candidate_edge,
        ta: candidate_ta,
        tb: candidate_tb,
        reversed: candidate_reversed,
        ..,
      ) = edge
      candidate_edge == edge_id
      && float.min(candidate_ta, candidate_tb) == ta
      && float.max(candidate_ta, candidate_tb) == tb
      && candidate_reversed == reversed
    })
  })
}

fn certify_segment_image_geometry(
  graph: ArrangementGraph,
  segments: List(svg_path.Segment),
  segment_images: List(ArrangementSourceSegmentImage),
  tolerance: Float,
) -> Result(Nil, Error) {
  segment_images
  |> list.map(fn(image) {
    let ArrangementSourceSegmentImage(segment_index:, edges:) = image
    use source <- result.try(
      segment_at(segments, segment_index)
      |> result.map_error(fn(_) { InternalNormalizationError }),
    )
    edges
    |> list.map(fn(edge) {
      certify_segment_edge_geometry(graph, source, edge, tolerance)
    })
    |> result.all
    |> result.map(fn(_) { Nil })
  })
  |> result.all
  |> result.map(fn(_) { Nil })
}

fn certify_segment_edge_geometry(
  graph: ArrangementGraph,
  source: svg_path.Segment,
  image: ArrangementSegmentEdgeImage,
  tolerance: Float,
) -> Result(Nil, Error) {
  let ArrangementGraph(edges:, ..) = graph
  let ArrangementSegmentEdgeImage(ta:, tb:, edge_id:, reversed:, ..) = image
  use edge <- result.try(arrangement_edge_by_id(edges, edge_id))
  let ArrangementEdge(segment:, ..) = edge
  use source_a <- result.try(
    svg_path.segment_point(source, at: ta)
    |> result.map_error(PathError),
  )
  use source_b <- result.try(
    svg_path.segment_point(source, at: tb)
    |> result.map_error(PathError),
  )
  let edge_a = case reversed {
    True -> svg_path.segment_end(segment)
    False -> svg_path.segment_start(segment)
  }
  let edge_b = case reversed {
    True -> svg_path.segment_start(segment)
    False -> svg_path.segment_end(segment)
  }
  case
    point.distance(source_a, edge_a) <=. tolerance
    && point.distance(source_b, edge_b) <=. tolerance
  {
    True -> Ok(Nil)
    False -> Error(InternalNormalizationError)
  }
}

fn int_list_contains(values: List(Int), target: Int) -> Bool {
  values
  |> list.any(fn(value) { value == target })
}

fn increment_edge_by_id(
  graph: ArrangementGraph,
  edge_id: Int,
  forward: Bool,
) -> ArrangementGraph {
  let ArrangementGraph(vertices:, edges:, cyclic_orders:) = graph
  ArrangementGraph(
    vertices:,
    edges: edges
      |> list.map(fn(edge) {
        let ArrangementEdge(
          id:,
          forward_multiplicity: forward_count,
          reverse_multiplicity: reverse_count,
          ..,
        ) = edge
        case id == edge_id {
          False -> edge
          True ->
            ArrangementEdge(
              ..edge,
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
    cyclic_orders:,
  )
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
          id: next_arrangement_edge_id(edges),
          segment:,
          bounds: segment_bounding_box_assert(segment),
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
        segment: existing,
        start_vertex: existing_start,
        end_vertex: existing_end,
        forward_multiplicity: forward,
        reverse_multiplicity: reverse,
        ..,
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
              ..first,
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
                  ..first,
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

/// Validate local representation and closed-boundary invariants.
///
/// This checks multiplicity totals, vertex references, non-loop edges, endpoint
/// tolerance, minimum chord length, endpoint-cluster centers and radii, vertex
/// incidence, and even weighted degree. It does not test pairwise edge
/// intersections, atomicity, identifier uniqueness, or individual directional
/// multiplicity signs; use `build` to establish those construction invariants.
pub fn validate(
  graph: ArrangementGraph,
  tolerance tolerance: Float,
  minimum_chord minimum_chord: Float,
) -> Result(Nil, Error) {
  use _ <- result.try(validate_options(tolerance, minimum_chord))
  let ArrangementGraph(vertices:, edges:, ..) = graph
  use _ <- result.try(validate_edges(edges, vertices, tolerance, minimum_chord))
  validate_vertices(vertices, edges, tolerance)
}

fn validate_options(
  tolerance: Float,
  minimum_chord: Float,
) -> Result(Nil, Error) {
  case
    tolerance <=. 0.0 || !number.is_finite(tolerance),
    minimum_chord <=. 0.0 || !number.is_finite(minimum_chord)
  {
    True, _ -> Error(InvalidTolerance(tolerance))
    _, True -> Error(InvalidMinimumChord(minimum_chord))
    False, False -> Ok(Nil)
  }
}

fn validate_endpoint_cut_tolerance(tolerance: Float) -> Result(Nil, Error) {
  case tolerance <. 0.0 || !number.is_finite(tolerance) {
    True -> Error(InvalidEndpointSliverTolerance(tolerance))
    False -> Ok(Nil)
  }
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
        ..,
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
