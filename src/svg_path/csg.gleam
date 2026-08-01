//// ArrangementGraph-based operations on SVG paths.
////
//// Binary operations interpret both operands with one fill rule. The unary
//// `monotone_contours` operation instead preserves the complete signed integer
//// winding field and therefore takes no fill rule.

import gleam/int
import gleam/list
import gleam/order
import gleam/result
import svg_path
import svg_path/arrangement_graph.{
  type ArrangementEdge, type ArrangementGraph, ArrangementEdge, ArrangementGraph,
}
import svg_path/trig
import svg_path/winding_field

const default_minimum_chord = 0.00001

/// Numeric options used while constructing and classifying an arrangement.
pub type Options {
  Options(tolerance: Float, minimum_chord: Float)
}

pub type Error {
  ArrangementError(arrangement_graph.Error)
  PathError(svg_path.Error)
  BoundaryTraceFailed(vertex: Int)
  BoundarySectorMismatch(vertex: Int)
}

/// A CSG output together with the exact arrangement used to derive it.
///
/// Returning the build makes normalization and graph refinement visible to the
/// caller: the result path follows the arrangement's geometry rather than
/// silently claiming the original input geometry as its source of truth.
pub type CsgResult {
  CsgResult(
    /// The reconstructed result path for the requested operation.
    path: svg_path.Path,
    /// The arrangement graph and source-ordered normalized input paths used to
    /// classify and reconstruct `path`.
    build: arrangement_graph.ArrangementGraphBuild,
  )
}

/// Return default ArrangementGraph CSG options.
pub fn default_options() -> Options {
  Options(tolerance: 0.000001, minimum_chord: default_minimum_chord)
}

/// Return the Boolean union of two paths under `using`.
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
  use built <- result.try(
    arrangement_graph.build(
      [left, right],
      tolerance: options.tolerance,
      minimum_chord: options.minimum_chord,
    )
    |> result.map_error(ArrangementError),
  )
  let arrangement_graph.ArrangementGraphBuild(graph:, normalized_paths:) = built
  let assert [normalized_left, normalized_right] = normalized_paths
  use path <- result.try(union_from_arrangement_graph(
    graph,
    normalized_left,
    normalized_right,
    using: fill_rule,
    tolerance: options.tolerance,
  ))
  Ok(CsgResult(path:, build: built))
}

/// Return the Boolean intersection of two paths under `using`.
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
  use built <- result.try(
    arrangement_graph.build(
      [left, right],
      tolerance: options.tolerance,
      minimum_chord: options.minimum_chord,
    )
    |> result.map_error(ArrangementError),
  )
  let arrangement_graph.ArrangementGraphBuild(graph:, normalized_paths:) = built
  let assert [normalized_left, normalized_right] = normalized_paths
  use path <- result.try(intersection_from_arrangement_graph(
    graph,
    normalized_left,
    normalized_right,
    using: fill_rule,
    tolerance: options.tolerance,
  ))
  Ok(CsgResult(path:, build: built))
}

/// Return `left` minus `right` under `using`.
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
  use built <- result.try(
    arrangement_graph.build(
      [left, right],
      tolerance: options.tolerance,
      minimum_chord: options.minimum_chord,
    )
    |> result.map_error(ArrangementError),
  )
  let arrangement_graph.ArrangementGraphBuild(graph:, normalized_paths:) = built
  let assert [normalized_left, normalized_right] = normalized_paths
  use path <- result.try(difference_from_arrangement_graph(
    graph,
    normalized_left,
    normalized_right,
    using: fill_rule,
    tolerance: options.tolerance,
  ))
  Ok(CsgResult(path:, build: built))
}

/// Return the Boolean symmetric difference of two paths under `using`.
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
  use built <- result.try(
    arrangement_graph.build(
      [left, right],
      tolerance: options.tolerance,
      minimum_chord: options.minimum_chord,
    )
    |> result.map_error(ArrangementError),
  )
  let arrangement_graph.ArrangementGraphBuild(graph:, normalized_paths:) = built
  let assert [normalized_left, normalized_right] = normalized_paths
  use path <- result.try(symmetric_difference_from_arrangement_graph(
    graph,
    normalized_left,
    normalized_right,
    using: fill_rule,
    tolerance: options.tolerance,
  ))
  Ok(CsgResult(path:, build: built))
}

/// Return nested or disjoint unit-level contours with the same signed winding
/// field as `path`.
pub fn monotone_contours(path: svg_path.Path) -> Result(CsgResult, Error) {
  monotone_contours_with(path, options: default_options())
}

/// Return monotone contours using explicit arrangement options.
pub fn monotone_contours_with(
  path: svg_path.Path,
  options options: Options,
) -> Result(CsgResult, Error) {
  use built <- result.try(
    arrangement_graph.build(
      [path],
      tolerance: options.tolerance,
      minimum_chord: options.minimum_chord,
    )
    |> result.map_error(ArrangementError),
  )
  let arrangement_graph.ArrangementGraphBuild(graph:, normalized_paths:) = built
  let assert [normalized_path] = normalized_paths
  use path <- result.try(monotone_contours_from_arrangement_graph(
    graph,
    normalized_path,
    tolerance: options.tolerance,
  ))
  Ok(CsgResult(path:, build: built))
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

/// Compute the Boolean union boundary from an `ArrangementGraph`.
///
/// Winding is evaluated separately against both operands before the common
/// fill rule is applied. Necessary edges are oriented with filled space on the
/// right and consumed into closed cycles.
fn union_from_arrangement_graph(
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
fn intersection_from_arrangement_graph(
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
fn difference_from_arrangement_graph(
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
fn symmetric_difference_from_arrangement_graph(
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
fn monotone_contours_from_arrangement_graph(
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

fn int_max(a: Int, b: Int) -> Int {
  case a > b {
    True -> a
    False -> b
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
