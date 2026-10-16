//// ArrangementGraph-based operations on SVG paths.
////
//// Binary operations propagate each operand's winding across arrangement faces
//// and interpret both operands with one fill rule. The unary
//// `nested_contours` operation instead preserves the complete signed integer
//// winding field and therefore takes no fill rule.
//// Open subpaths are implicitly closed by a straight line for filling; those
//// closing lines are also included in the returned arrangement build.

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/result
import svg_path
import svg_path/arrangement.{
  type ArrangementEdge, type ArrangementGraph, ArrangementEdge,
}
import svg_path/point

const default_minimum_length = 0.00001

/// Numeric options used while constructing and classifying an arrangement.
///
/// `tolerance` is a distance in path coordinates used for endpoint clustering,
/// intersection and overlap detection, and final cycle
/// endpoint adjustments to their shared vertex positions. `minimum_length` is a
/// size threshold: refined pieces are discarded when their segment length upper bound is below it,
/// not merely when their endpoints are close. Both values must be finite and
/// greater than zero. If discarding pieces opens an operand boundary, the
/// operation returns `ArrangementGraphError(arrangement.ConstructionFailed)`;
/// it does not silently lower
/// the threshold or widen endpoint clustering.
pub type Options {
  Options(tolerance: Float, minimum_length: Float)
}

/// Errors returned by arrangement-graph CSG operations.
pub type Error {
  /// Arrangement construction, dual certification, or winding consistency failed.
  ArrangementGraphError(error: arrangement.Error)

  /// An underlying path operation failed.
  PathError(error: svg_path.Error)

  /// Boundary classification produced topology that could not be reconstructed.
  /// This indicates an internal consistency failure rather than invalid caller
  /// syntax.
  InternalBoundaryTopologyError(vertex: Int, reason: BoundaryTopologyFailure)
}

// Deferred public diagnostic: see DEFERRED-API.md (API-001).
// Keep the reason internally while preserving the 3.x public error union.
type RefinedBoundaryFailure {
  RefinedBoundaryNotClosed(path_index: Int, vertex: Int, net_flow: Int)
}

/// The stage at which classified boundary topology became inconsistent.
pub type BoundaryTopologyFailure {
  /// A boundary ray did not have the required filled-sector successor.
  SectorMismatch

  /// Linked boundary edges did not form a complete closed cycle.
  TraceFailed
}

/// A CSG output together with the exact arrangement used to derive it.
///
/// Returning the build makes graph refinement visible to the caller: the result
/// path follows the arrangement's geometry rather than silently claiming the
/// original input geometry as its source of truth. Binary operations construct
/// output segments with endpoints at the corresponding arrangement vertex points;
/// each endpoint moves by at most the build tolerance. Control points and arc
/// parameters are retained. This endpoint bound is not a bound on the interior
/// displacement of an elliptical arc. Stored arrangement edges remain unchanged.
pub type CsgResult {
  CsgResult(
    /// The reconstructed result path for the requested operation.
    path: svg_path.Path,
    /// The arrangement graph and source-ordered input segment images used to
    /// classify and reconstruct `path`.
    build: arrangement.ArrangementSegmentBuild,
  )
}

/// Return default arrangement-graph CSG options.
///
/// The default tolerance is `0.000001` path-coordinate units and the default
/// minimum segment-size threshold is `0.00001` path-coordinate units.
pub fn default_options() -> Options {
  Options(tolerance: 0.000001, minimum_length: default_minimum_length)
}

/// Return the Boolean union of two paths under `using`.
///
/// Each operand is filled independently using the supplied rule. The result
/// follows the refined geometry exposed through `CsgResult.build`.
pub fn union(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
) -> Result(CsgResult, Error) {
  union_with(left, right, using: fill_rule, options: default_options())
}

/// Return the Boolean union using explicit arrangement options.
pub fn union_with(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  options options: Options,
) -> Result(CsgResult, Error) {
  use built <- result.try(csg_arrangement_build([left, right], options))
  use path <- result.try(boolean_from_arrangement(
    built,
    list.length(csg_path_segments([left], segments: [])),
    fill_rule,
    UnionOperation,
  ))
  Ok(CsgResult(path:, build: built))
}

/// Return the Boolean intersection of two paths under `using`.
///
/// Each operand is filled independently using the supplied rule. The result
/// follows the refined geometry exposed through `CsgResult.build`.
pub fn intersection(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
) -> Result(CsgResult, Error) {
  intersection_with(left, right, using: fill_rule, options: default_options())
}

/// Return the Boolean intersection using explicit arrangement options.
pub fn intersection_with(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  options options: Options,
) -> Result(CsgResult, Error) {
  use built <- result.try(csg_arrangement_build([left, right], options))
  use path <- result.try(boolean_from_arrangement(
    built,
    list.length(csg_path_segments([left], segments: [])),
    fill_rule,
    IntersectionOperation,
  ))
  Ok(CsgResult(path:, build: built))
}

/// Return `left` minus `right` under `using`.
///
/// Each operand is filled independently using the supplied rule. The result
/// follows the refined geometry exposed through `CsgResult.build`.
pub fn difference(
  left: svg_path.Path,
  minus right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
) -> Result(CsgResult, Error) {
  difference_with(
    left,
    minus: right,
    using: fill_rule,
    options: default_options(),
  )
}

/// Return `left` minus `right` using explicit arrangement options.
pub fn difference_with(
  left: svg_path.Path,
  minus right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  options options: Options,
) -> Result(CsgResult, Error) {
  use built <- result.try(csg_arrangement_build([left, right], options))
  use path <- result.try(boolean_from_arrangement(
    built,
    list.length(csg_path_segments([left], segments: [])),
    fill_rule,
    DifferenceOperation,
  ))
  Ok(CsgResult(path:, build: built))
}

/// Return the Boolean symmetric difference of two paths under `using`.
///
/// Each operand is filled independently using the supplied rule. The result
/// follows the refined geometry exposed through `CsgResult.build`.
pub fn symmetric_difference(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
) -> Result(CsgResult, Error) {
  symmetric_difference_with(
    left,
    right,
    using: fill_rule,
    options: default_options(),
  )
}

/// Return the Boolean symmetric difference using explicit arrangement options.
pub fn symmetric_difference_with(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  options options: Options,
) -> Result(CsgResult, Error) {
  use built <- result.try(csg_arrangement_build([left, right], options))
  use path <- result.try(boolean_from_arrangement(
    built,
    list.length(csg_path_segments([left], segments: [])),
    fill_rule,
    SymmetricDifferenceOperation,
  ))
  Ok(CsgResult(path:, build: built))
}

/// Return nested or disjoint unit-level contours with the same signed winding
/// field as `path`.
///
/// This operation preserves signed integer winding levels rather than applying
/// a fill rule. The result follows the normalized and refined geometry exposed
/// through `CsgResult.build`.
pub fn nested_contours(path: svg_path.Path) -> Result(CsgResult, Error) {
  nested_contours_with(path, options: default_options())
}

/// Return nested contours using explicit arrangement options.
pub fn nested_contours_with(
  path: svg_path.Path,
  options options: Options,
) -> Result(CsgResult, Error) {
  use built <- result.try(csg_arrangement_build([path], options))
  let arrangement.ArrangementSegmentBuild(graph:, ..) = built
  use path <- result.try(nested_contours_from_arrangement_graph(
    graph,
    path,
    tolerance: options.tolerance,
  ))
  Ok(CsgResult(path:, build: built))
}

fn csg_arrangement_build(
  paths: List(svg_path.Path),
  options: Options,
) -> Result(arrangement.ArrangementSegmentBuild, Error) {
  use built <- result.try(
    arrangement.build_with(
      csg_path_segments(paths, segments: []),
      vertex_tolerance: options.tolerance,
      minimum_length: options.minimum_length,
      endpoint_sliver_tolerance: 0.0,
    )
    |> result.map_error(fn(error) {
      ArrangementGraphError(arrangement.public_error(error))
    }),
  )
  let edges =
    dict.from_list(list.map(built.graph.edges, fn(edge) { #(edge.id, edge) }))
  use _ <- result.try(
    validate_refined_boundaries(paths, built.edge_images, edges, 0, 0)
    |> result.map_error(fn(_) {
      ArrangementGraphError(arrangement.ConstructionFailed)
    }),
  )
  Ok(built)
}

fn validate_refined_boundaries(
  paths: List(svg_path.Path),
  images: List(arrangement.ArrangementEdgeImage),
  edges: Dict(Int, ArrangementEdge),
  path_index: Int,
  first_segment: Int,
) -> Result(Nil, RefinedBoundaryFailure) {
  case paths {
    [] -> Ok(Nil)
    [path, ..rest] -> {
      let next_segment =
        first_segment + list.length(csg_path_segments([path], []))
      let flows =
        list.fold(images, dict.new(), fn(flows, image) {
          let weight =
            list.fold(image.sources, 0, fn(total, source) {
              case
                source.segment_index >= first_segment
                && source.segment_index < next_segment
              {
                False -> total
                True ->
                  total
                  + case source.reversed {
                    True -> -1
                    False -> 1
                  }
              }
            })
          case dict.get(edges, image.edge_id) {
            Error(_) -> flows
            Ok(edge) -> {
              let start =
                result.unwrap(dict.get(flows, edge.start_vertex), 0) - weight
              let flows = dict.insert(flows, edge.start_vertex, start)
              let end =
                result.unwrap(dict.get(flows, edge.end_vertex), 0) + weight
              dict.insert(flows, edge.end_vertex, end)
            }
          }
        })
      // Vertex order makes diagnostics deterministic across runtime targets.
      use _ <- result.try(
        list.try_each(
          dict.to_list(flows) |> list.sort(fn(a, b) { int.compare(a.0, b.0) }),
          fn(entry) {
            case entry.1 {
              0 -> Ok(Nil)
              flow -> Error(RefinedBoundaryNotClosed(path_index, entry.0, flow))
            }
          },
        ),
      )
      validate_refined_boundaries(
        rest,
        images,
        edges,
        path_index + 1,
        next_segment,
      )
    }
  }
}

fn csg_path_segments(
  paths: List(svg_path.Path),
  segments segments: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case paths {
    [] -> list.reverse(segments)
    [path, ..rest] ->
      csg_path_segments(
        rest,
        segments: csg_subpath_segments(svg_path.path_subpaths(path), segments:),
      )
  }
}

fn csg_subpath_segments(
  subpaths: List(svg_path.Subpath),
  segments segments: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case subpaths {
    [] -> segments
    [subpath, ..rest] -> {
      let source = svg_path.subpath_segments(subpath)
      let segments = prepend_reversed(source, segments)
      let start = svg_path.subpath_start(subpath)
      let end = svg_path.subpath_end(subpath)
      // Fill geometry includes the implicit end-to-start line, even when the
      // source is open. Prepend it to this reversed accumulator so its image
      // follows the source segments in the final build inventory.
      let segments = case source == [] || point.near(start, end, 0.0) {
        True -> segments
        False -> [svg_path.Line(start: end, end: start), ..segments]
      }
      csg_subpath_segments(rest, segments:)
    }
  }
}

fn prepend_reversed(items: List(a), onto onto: List(a)) -> List(a) {
  case items {
    [] -> onto
    [first, ..rest] -> prepend_reversed(rest, onto: [first, ..onto])
  }
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
  BoundaryRay(edge_id: Int, starts: Bool)
}

type BooleanOperation {
  UnionOperation
  IntersectionOperation
  DifferenceOperation
  SymmetricDifferenceOperation
}

/// Compute a Boolean boundary from its arrangement and source images.
///
/// Propagate each operand's signed source multiplicities from the outer face.
/// Face membership does not depend on a displaced point fitting between edges.
fn boolean_from_arrangement(
  built: arrangement.ArrangementSegmentBuild,
  left_segment_count: Int,
  fill_rule: svg_path.FillRule,
  operation: BooleanOperation,
) -> Result(svg_path.Path, Error) {
  let graph = built.graph
  use dual <- result.try(
    arrangement.dual(graph) |> result.map_error(ArrangementGraphError),
  )
  use left <- result.try(operand_face_windings(
    built,
    dual,
    left_segment_count,
    True,
  ))
  use right <- result.try(operand_face_windings(
    built,
    dual,
    left_segment_count,
    False,
  ))
  let faces =
    dict.from_list(
      list.map(dual.edge_faces, fn(edge) { #(edge.edge_id, edge) }),
    )
  use boundary <- result.try(
    classify_boolean_edges(
      graph.edges,
      faces,
      left,
      right,
      fill_rule,
      operation,
      [],
    ),
  )
  use links <- result.try(pair_boundary_sectors(graph, boundary))
  use subpaths <- result.try(
    trace_boundary_edges(boundary, links, vertex_points(graph), []),
  )
  Ok(svg_path.Path(subpaths))
}

fn operand_face_windings(
  built: arrangement.ArrangementSegmentBuild,
  dual: arrangement.DualArrangementGraph,
  left_segment_count: Int,
  left_operand: Bool,
) -> Result(Dict(Int, Int), Error) {
  let changes =
    list.map(built.edge_images, fn(image) {
      let change =
        list.fold(image.sources, 0, fn(total, source) {
          case source.segment_index < left_segment_count == left_operand {
            False -> total
            True ->
              case source.reversed {
                True -> total - 1
                False -> total + 1
              }
          }
        })
      arrangement.EdgeWindingChange(image.edge_id, change)
    })
  use values <- result.try(
    arrangement.face_windings(dual, changes)
    |> result.replace_error(ArrangementGraphError(
      arrangement.ConstructionFailed,
    )),
  )
  Ok(dict.from_list(list.map(values, fn(face) { #(face.face_id, face.value) })))
}

/// Reconstruct the signed winding field of `path` as nested or disjoint
/// unit-level contours using an arrangement built from that path.
///
/// Winding-neutral edge multiplicity is omitted. Every retained contour adds
/// either `1` or `-1` to the winding field inside it.
fn nested_contours_from_arrangement_graph(
  graph: ArrangementGraph,
  path: svg_path.Path,
  tolerance tolerance: Float,
) -> Result(svg_path.Path, Error) {
  use subpaths <- result.try(
    arrangement.nested_contours_from_graph(graph, path, tolerance)
    |> result.map_error(fn(error) {
      ArrangementGraphError(arrangement.public_error(error))
    }),
  )
  Ok(svg_path.Path(subpaths))
}

fn classify_boolean_edges(
  edges: List(ArrangementEdge),
  faces: Dict(Int, arrangement.ArrangementEdgeFaces),
  left: Dict(Int, Int),
  right: Dict(Int, Int),
  fill_rule: svg_path.FillRule,
  operation: BooleanOperation,
  boundary: List(BoundaryEdge),
) -> Result(List(BoundaryEdge), Error) {
  case edges {
    [] -> Ok(list.reverse(boundary))
    [ArrangementEdge(id:, segment:, start_vertex:, end_vertex:, ..), ..rest] -> {
      let invalid = ArrangementGraphError(arrangement.ConstructionFailed)
      use face <- result.try(
        dict.get(faces, id) |> result.replace_error(invalid),
      )
      use left_a <- result.try(
        dict.get(left, face.left_face) |> result.replace_error(invalid),
      )
      use right_a <- result.try(
        dict.get(left, face.right_face) |> result.replace_error(invalid),
      )
      use left_b <- result.try(
        dict.get(right, face.left_face) |> result.replace_error(invalid),
      )
      use right_b <- result.try(
        dict.get(right, face.right_face) |> result.replace_error(invalid),
      )
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
        False, True -> [
          BoundaryEdge(id:, layer: 0, segment:, start_vertex:, end_vertex:),
          ..boundary
        ]
        _, _ -> boundary
      }
      classify_boolean_edges(
        rest,
        faces,
        left,
        right,
        fill_rule,
        operation,
        boundary,
      )
    }
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
  graph: ArrangementGraph,
  edges: List(BoundaryEdge),
) -> Result(List(BoundaryLink), Error) {
  let boundary =
    edges |> list.map(fn(edge) { #(edge.id, edge) }) |> dict.from_list
  let orders = dict.from_list(graph.cyclic_orders)
  list.try_map(edges, fn(incoming) {
    let vertex = incoming.end_vertex
    use groups <- result.try(
      dict.get(orders, vertex)
      |> result.replace_error(InternalBoundaryTopologyError(
        vertex:,
        reason: SectorMismatch,
      )),
    )
    // Retain the arrangement's geometric clockwise order, including its
    // deterministic order within unresolved groups. Sorting endpoint tangent
    // angles again loses the separation of curves sharing a tangent.
    let ordered =
      groups
      |> list.flatten
      |> list.filter_map(fn(incident) {
        use edge <- result.try(dict.get(boundary, incident.edge_id))
        case edge.layer == incoming.layer {
          True ->
            // Classification may reverse an edge relative to the graph.
            Ok(BoundaryRay(
              edge_id: edge.id,
              starts: edge.start_vertex == vertex,
            ))
          False -> Error(Nil)
        }
      })
    use successor <- result.try(cyclic_successor(
      ordered,
      incoming.id,
      first: list.first(ordered),
      vertex:,
    ))
    case successor.starts {
      True ->
        Ok(BoundaryLink(edge_id: incoming.id, successor_id: successor.edge_id))
      False ->
        Error(InternalBoundaryTopologyError(vertex:, reason: SectorMismatch))
    }
  })
}

fn cyclic_successor(
  rays: List(BoundaryRay),
  incoming_id: Int,
  first first_ray: Result(BoundaryRay, Nil),
  vertex vertex: Int,
) -> Result(BoundaryRay, Error) {
  case rays {
    [] -> Error(InternalBoundaryTopologyError(vertex:, reason: SectorMismatch))
    [first, ..rest] -> {
      let BoundaryRay(edge_id:, starts:) = first
      case edge_id == incoming_id && !starts {
        True ->
          case rest {
            [next, ..] -> Ok(next)
            [] ->
              first_ray
              |> result.map_error(fn(_) {
                InternalBoundaryTopologyError(vertex:, reason: SectorMismatch)
              })
          }
        False -> cyclic_successor(rest, incoming_id, first: first_ray, vertex:)
      }
    }
  }
}

fn vertex_points(graph: ArrangementGraph) -> Dict(Int, svg_path.Point) {
  graph.vertices
  |> list.map(fn(vertex) { #(vertex.id, vertex.point) })
  |> dict.from_list
}

// Construct output geometry only after classification and sector pairing. The
// source edges and their endpoint samples keep their original geometry. Using
// the shared vertex bounds each endpoint adjustment by the cluster radius,
// rather than incorrectly bounding the distance between two cluster members.
fn boundary_output_segment(
  edge: BoundaryEdge,
  vertices: Dict(Int, svg_path.Point),
) -> svg_path.Segment {
  let assert Ok(start) = dict.get(vertices, edge.start_vertex)
  let assert Ok(end) = dict.get(vertices, edge.end_vertex)
  case edge.segment {
    svg_path.Line(..) -> svg_path.Line(start:, end:)
    svg_path.QuadraticBezier(control:, ..) ->
      svg_path.QuadraticBezier(start:, control:, end:)
    svg_path.CubicBezier(control1:, control2:, ..) ->
      svg_path.CubicBezier(start:, control1:, control2:, end:)
    svg_path.Arc(radius:, x_axis_rotation:, large_arc:, sweep:, ..) ->
      svg_path.Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:)
  }
}

fn trace_boundary_edges(
  remaining: List(BoundaryEdge),
  links: List(BoundaryLink),
  vertices: Dict(Int, svg_path.Point),
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
      let segments =
        list.map(cycle, fn(edge) { boundary_output_segment(edge, vertices) })
      // Distinct source edges can collapse to an exact opposite pair when
      // their endpoints are reconstructed at cluster centers. Such a closed
      // retrace has no filled boundary. Do not discard loops by signed area:
      // a self-crossing loop can have zero signed area and nonempty fill.
      let reduced =
        list.fold(segments, [], fn(stack, segment) {
          case stack {
            [previous, ..rest] ->
              case previous == svg_path.segment_reverse(segment) {
                True -> rest
                False -> [segment, ..stack]
              }
            [] -> [segment]
          }
        })
      case reduced {
        [] -> trace_boundary_edges(remaining, links, vertices, subpaths)
        _ -> {
          use subpath <- result.try(
            svg_path.subpath(segments) |> result.map_error(PathError),
          )
          use closed <- result.try(
            svg_path.subpath_close(subpath) |> result.map_error(PathError),
          )
          trace_boundary_edges(remaining, links, vertices, [closed, ..subpaths])
        }
      }
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
        True ->
          Error(InternalBoundaryTopologyError(
            vertex: end_vertex,
            reason: TraceFailed,
          ))
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
    [] -> Error(InternalBoundaryTopologyError(vertex:, reason: TraceFailed))
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
    [] -> Error(InternalBoundaryTopologyError(vertex:, reason: TraceFailed))
    [first, ..rest] -> {
      let BoundaryEdge(id: candidate, ..) = first
      case candidate == id {
        True -> Ok(#(first, list.append(list.reverse(retained), rest)))
        False -> take_boundary_edge(rest, id, vertex, [first, ..retained])
      }
    }
  }
}

/// Return only the reconstructed union path.
/// Use `union` when arrangement geometry and source correspondence are needed.
pub fn union_path(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
) -> Result(svg_path.Path, Error) {
  union_path_with(left, right, using: fill_rule, options: default_options())
}

/// Return only the reconstructed path using explicit numerical options.
/// This has the same geometry and failure behavior as `union_with`.
pub fn union_path_with(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  union_with(left, right, using: fill_rule, options:)
  |> result.map(fn(output) { output.path })
}

/// Return only the reconstructed intersection path.
/// Use `intersection` when arrangement geometry and source correspondence are needed.
pub fn intersection_path(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
) -> Result(svg_path.Path, Error) {
  intersection_path_with(
    left,
    right,
    using: fill_rule,
    options: default_options(),
  )
}

/// Return only the reconstructed path using explicit numerical options.
/// This has the same geometry and failure behavior as `intersection_with`.
pub fn intersection_path_with(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  intersection_with(left, right, using: fill_rule, options:)
  |> result.map(fn(output) { output.path })
}

/// Return only the reconstructed difference path.
/// Use `difference` when arrangement geometry and source correspondence are needed.
pub fn difference_path(
  left: svg_path.Path,
  minus right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
) -> Result(svg_path.Path, Error) {
  difference_path_with(
    left,
    minus: right,
    using: fill_rule,
    options: default_options(),
  )
}

/// Return only the reconstructed path using explicit numerical options.
/// This has the same geometry and failure behavior as `difference_with`.
pub fn difference_path_with(
  left: svg_path.Path,
  minus right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  difference_with(left, minus: right, using: fill_rule, options:)
  |> result.map(fn(output) { output.path })
}

/// Return only the reconstructed symmetric difference path.
/// Use `symmetric_difference` when arrangement geometry and source correspondence are needed.
pub fn symmetric_difference_path(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
) -> Result(svg_path.Path, Error) {
  symmetric_difference_path_with(
    left,
    right,
    using: fill_rule,
    options: default_options(),
  )
}

/// Return only the reconstructed path using explicit numerical options.
/// This has the same geometry and failure behavior as `symmetric_difference_with`.
pub fn symmetric_difference_path_with(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  symmetric_difference_with(left, right, using: fill_rule, options:)
  |> result.map(fn(output) { output.path })
}

/// Return nested contours without retaining the arrangement build.
pub fn nested_contours_path(
  path: svg_path.Path,
) -> Result(svg_path.Path, Error) {
  nested_contours_path_with(path, options: default_options())
}

/// Return nested contours using explicit options, without the arrangement build.
pub fn nested_contours_path_with(
  path: svg_path.Path,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  nested_contours_with(path, options:) |> result.map(fn(output) { output.path })
}
