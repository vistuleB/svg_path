//// Legacy Boolean operations on filled SVG paths.
////
//// The `using` fill rule is part of the operation: both input paths are first
//// interpreted as filled sets under that rule, the Boolean operation is
//// applied to those sets, and the returned path fills as the resulting set
//// under the same rule. For `Nonzero`, CSG preserves contour-depth level-set
//// boundaries inside the resulting set rather than collapsing the result to a
//// minimal filled outline.
////
//// Open subpaths are treated as implicitly closed for fill purposes. Empty
//// paths and move-only subpaths contribute no filled area.
////
//// The implementation preserves original segment types where possible. It
//// splits original path segments at point intersections, classifies each
//// resulting directed piece by the output contour depth on its left and right
//// sides, and assembles closed subpaths from those retained pieces. A depth
//// jump larger than one emits repeated pieces so the returned path can express
//// the same `Nonzero` field. Result contour orientation is normalized after
//// assembly: fill-forced boundaries keep the direction required by the output
//// winding field, and retained internal `Nonzero` level contours use clockwise
//// orientation when their direction is not forced by the fill. Curved segments
//// remain curved between real encounters; only implicit closing edges are added
//// as lines. Coincident line edges are split at their overlap endpoints and
//// resolved by deterministic boundary ownership rules.

import gleam/float
import gleam/int
import gleam/list
import gleam/order
import gleam/result
import svg_path
import svg_path/area
import svg_path/intersections
import svg_path/legacy/robust_union
import svg_path/point as point_helpers
import svg_path/trig

const default_tolerance = 0.000001

type Operation {
  Union
  Intersection
  Difference
}

type Edge {
  Edge(id: Int, source: Int, segment: svg_path.Segment)
}

type Piece {
  Piece(
    segment: svg_path.Segment,
    level: Int,
    role: PieceRole,
    internal: Bool,
    group: Int,
  )
}

type PieceRole {
  BoundaryPiece
  OverlapPiece
  SourcePiece
}

type Chain {
  Chain(pieces: List(Piece))
}

type OutputContour {
  OutputContour(
    subpath: svg_path.Subpath,
    level: Int,
    role: PieceRole,
    internal: Bool,
  )
}

type Candidate {
  Candidate(piece: Piece, remaining: List(Piece), score: Float)
}

type Separation {
  NoSeparation
  InteriorOnLeft(low_level: Int, high_level: Int)
  InteriorOnRight(low_level: Int, high_level: Int)
}

/// Options for path CSG operations.
pub type Options {
  Options(
    intersection: intersections.IntersectionOptions,
    containment: svg_path.ContainmentOptions,
    tolerance: Float,
  )
}

/// Return default CSG options.
pub fn default_options() -> Options {
  Options(
    intersection: intersections.default_options(),
    containment: svg_path.default_containment_options(),
    tolerance: default_tolerance,
  )
}

/// Return a path whose fill is the union of two input paths under `using`.
pub fn union(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
) -> Result(svg_path.Path, svg_path.Error) {
  union_with(left, right, using: fill_rule, options: default_options())
}

/// Return a path whose fill is the union of two input paths using explicit
/// options.
pub fn union_with(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  options options: Options,
) -> Result(svg_path.Path, svg_path.Error) {
  let _ = fill_rule
  let _ = options
  robust_union.union_nonzero_paths(left, right)
}

/// Return a path whose fill is the intersection of two input paths under
/// `using`.
pub fn intersection(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
) -> Result(svg_path.Path, svg_path.Error) {
  intersection_with(left, right, using: fill_rule, options: default_options())
}

/// Return a path whose fill is the intersection of two input paths using
/// explicit options.
pub fn intersection_with(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  options options: Options,
) -> Result(svg_path.Path, svg_path.Error) {
  csg(left, right, using: fill_rule, operation: Intersection, options:)
}

/// Return a path whose fill is `left` minus `right` under `using`.
pub fn difference(
  left: svg_path.Path,
  minus right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
) -> Result(svg_path.Path, svg_path.Error) {
  difference_with(
    left,
    minus: right,
    using: fill_rule,
    options: default_options(),
  )
}

/// Return a path whose fill is `left` minus `right` using explicit options.
pub fn difference_with(
  left: svg_path.Path,
  minus right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  options options: Options,
) -> Result(svg_path.Path, svg_path.Error) {
  csg(left, right, using: fill_rule, operation: Difference, options:)
}

/// Remove internal contour-depth boundaries from a CSG result while preserving
/// its `Nonzero` filled set.
///
/// CSG operations intentionally preserve `Nonzero` contour-depth level sets.
/// This helper is a post-processing convenience for callers who want the
/// simpler filled-set boundary instead.
pub fn simplify_nonzero_output(
  path: svg_path.Path,
) -> Result(svg_path.Path, svg_path.Error) {
  simplify_nonzero_output_with(path, options: default_options())
}

/// Remove internal contour-depth boundaries from a CSG result using explicit
/// options.
pub fn simplify_nonzero_output_with(
  path: svg_path.Path,
  options options: Options,
) -> Result(svg_path.Path, svg_path.Error) {
  let edges = path_edges(path, offset: 0)
  use pieces <- result.try(
    nonzero_boundary_pieces(
      edges,
      whole_path: path,
      split_edges: edges,
      options:,
      retained: [],
    ),
  )

  pieces
  |> unique_pieces(options.tolerance, [])
  |> pieces_to_path(assembly_tolerance(options.tolerance))
}

fn csg(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  operation operation: Operation,
  options options: Options,
) -> Result(svg_path.Path, svg_path.Error) {
  let left_edges = path_edges(left, offset: 0)
  let right_edges = path_edges(right, offset: list.length(left_edges))

  use left_pieces <- result.try(retained_pieces(
    left_edges,
    own_path: left,
    split_edges: list.append(left_edges, right_edges),
    against_path: right,
    using: fill_rule,
    operation: operation,
    side: LeftSide,
    options:,
  ))
  use right_pieces <- result.try(retained_pieces(
    right_edges,
    own_path: right,
    split_edges: list.append(right_edges, left_edges),
    against_path: left,
    using: fill_rule,
    operation: operation,
    side: RightSide,
    options:,
  ))

  pieces_to_csg_path(
    list.append(left_pieces, right_pieces),
    fill_rule,
    assembly_tolerance(options.tolerance),
  )
}

fn nonzero_boundary_pieces(
  edges: List(Edge),
  whole_path whole_path: svg_path.Path,
  split_edges split_edges: List(Edge),
  options options: Options,
  retained retained: List(Piece),
) -> Result(List(Piece), svg_path.Error) {
  case edges {
    [] -> Ok(list.reverse(retained))
    [edge, ..rest] -> {
      use pieces <- result.try(split_edge(
        edge,
        split_edges,
        options.intersection,
        options.tolerance,
      ))
      use retained <- result.try(retain_nonzero_boundary_pieces(
        pieces,
        whole_path:,
        options:,
        retained:,
      ))
      nonzero_boundary_pieces(
        rest,
        whole_path:,
        split_edges:,
        options:,
        retained:,
      )
    }
  }
}

fn retain_nonzero_boundary_pieces(
  pieces: List(svg_path.Segment),
  whole_path whole_path: svg_path.Path,
  options options: Options,
  retained retained: List(Piece),
) -> Result(List(Piece), svg_path.Error) {
  case pieces {
    [] -> Ok(retained)
    [piece, ..rest] -> {
      let Options(tolerance:, ..) = options
      use retained <- result.try(case degenerate_line(piece, tolerance) {
        True -> Ok(retained)
        False -> {
          use boundary_pieces <- result.try(nonzero_boundary_piece(
            piece,
            whole_path:,
            options:,
          ))
          Ok(list.append(boundary_pieces, retained))
        }
      })
      retain_nonzero_boundary_pieces(rest, whole_path:, options:, retained:)
    }
  }
}

fn nonzero_boundary_piece(
  piece: svg_path.Segment,
  whole_path whole_path: svg_path.Path,
  options options: Options,
) -> Result(List(Piece), svg_path.Error) {
  use midpoint <- result.try(svg_path.segment_point(piece, at: 0.5))
  use derivative <- result.try(svg_path.segment_derivative(piece, at: 0.5))
  let length_squared =
    derivative.x *. derivative.x +. derivative.y *. derivative.y
  case length_squared <=. 0.0 {
    True -> Ok([])
    False -> {
      let assert Ok(length) = float.square_root(length_squared)
      let offset = options.tolerance *. 16.0
      let normal =
        svg_path.Point(
          { 0.0 -. derivative.y } /. length *. offset,
          derivative.x /. length *. offset,
        )
      let first = svg_path.Point(midpoint.x +. normal.x, midpoint.y +. normal.y)
      let second =
        svg_path.Point(midpoint.x -. normal.x, midpoint.y -. normal.y)
      use first_inside <- result.try(nonzero_contains(
        first,
        within: whole_path,
        options: options.containment,
      ))
      use second_inside <- result.try(nonzero_contains(
        second,
        within: whole_path,
        options: options.containment,
      ))

      Ok(case first_inside, second_inside {
        True, False -> [
          Piece(
            segment: piece,
            level: 1,
            role: BoundaryPiece,
            internal: False,
            group: 0,
          ),
        ]
        False, True -> [
          Piece(
            segment: svg_path.segment_reverse(piece),
            level: 1,
            role: BoundaryPiece,
            internal: False,
            group: 0,
          ),
        ]
        _, _ -> []
      })
    }
  }
}

fn nonzero_contains(
  point: svg_path.Point,
  within path: svg_path.Path,
  options options: svg_path.ContainmentOptions,
) -> Result(Bool, svg_path.Error) {
  use containment <- result.try(svg_path.path_containment_with(
    point,
    within: path,
    using: svg_path.Nonzero,
    options:,
  ))
  Ok(case containment {
    svg_path.Inside | svg_path.Boundary -> True
    svg_path.Outside -> False
  })
}

type Side {
  LeftSide
  RightSide
}

fn path_edges(path: svg_path.Path, offset offset: Int) -> List(Edge) {
  path
  |> svg_path.path_subpaths
  |> list.index_map(fn(subpath, index) { #(offset + index, subpath) })
  |> list.flat_map(fn(source_subpath) {
    let #(source, subpath) = source_subpath
    subpath_edges(subpath)
    |> list.map(fn(segment) { Edge(id: 0, source:, segment:) })
  })
  |> list.index_map(fn(edge, index) {
    let Edge(source:, segment:, ..) = edge
    Edge(id: offset + index, source:, segment:)
  })
}

fn subpath_edges(subpath: svg_path.Subpath) -> List(svg_path.Segment) {
  let segments = svg_path.subpath_segments(subpath)
  case segments {
    [] -> []
    _ -> {
      let start =
        svg_path.subpath_start(subpath)
        |> result.unwrap(svg_path.Point(0.0, 0.0))
      let end = svg_path.subpath_end(subpath) |> result.unwrap(start)
      let edges =
        segments
        |> list.filter_map(fn(segment) {
          case segment {
            svg_path.Line(start:, end:) -> {
              case same_point(start, end, 0.0) {
                True -> Error(Nil)
                False -> Ok(segment)
              }
            }
            _ -> Ok(segment)
          }
        })

      case same_point(start, end, 0.0) {
        True -> edges
        False -> list.append(edges, [svg_path.Line(start: end, end: start)])
      }
    }
  }
}

fn retained_pieces(
  edges: List(Edge),
  own_path own_path: svg_path.Path,
  split_edges split_edges: List(Edge),
  against_path against_path: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  operation operation: Operation,
  side side: Side,
  options options: Options,
) -> Result(List(Piece), svg_path.Error) {
  retained_pieces_loop(
    edges,
    own_path:,
    split_edges:,
    against_path:,
    using: fill_rule,
    operation:,
    side:,
    options:,
    retained: [],
  )
}

fn retained_pieces_loop(
  edges: List(Edge),
  own_path own_path: svg_path.Path,
  split_edges split_edges: List(Edge),
  against_path against_path: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  operation operation: Operation,
  side side: Side,
  options options: Options,
  retained retained: List(Piece),
) -> Result(List(Piece), svg_path.Error) {
  case edges {
    [] -> Ok(list.reverse(retained))
    [Edge(source:, ..) as edge, ..rest] -> {
      use pieces <- result.try(split_edge(
        edge,
        split_edges,
        options.intersection,
        options.tolerance,
      ))
      use retained <- result.try(retain_edge_pieces(
        pieces,
        source:,
        own_path:,
        against_path:,
        using: fill_rule,
        operation:,
        side:,
        options:,
        retained:,
      ))
      retained_pieces_loop(
        rest,
        own_path:,
        split_edges:,
        against_path:,
        using: fill_rule,
        operation:,
        side:,
        options:,
        retained:,
      )
    }
  }
}

fn split_edge(
  edge: Edge,
  split_edges: List(Edge),
  intersection_options: intersections.IntersectionOptions,
  tolerance: Float,
) -> Result(List(svg_path.Segment), svg_path.Error) {
  let Edge(segment:, ..) = edge
  use ts <- result.try(
    split_parameters(edge, split_edges, intersection_options, [0.0, 1.0]),
  )
  let ts = ts |> list.sort(by: float.compare) |> unique_floats(tolerance, [])
  svg_path.segment_between_many_inside(segment, between: ts)
}

fn split_parameters(
  edge: Edge,
  against_edges: List(Edge),
  intersection_options: intersections.IntersectionOptions,
  parameters: List(Float),
) -> Result(List(Float), svg_path.Error) {
  let Edge(id:, segment:, ..) = edge
  case against_edges {
    [] -> Ok(parameters)
    [Edge(id: against_id, segment: against, ..), ..rest] -> {
      case id == against_id {
        True -> split_parameters(edge, rest, intersection_options, parameters)
        False -> {
          use parameters <- result.try(
            case
              intersections.segment_with(
                segment,
                against,
                options: intersection_options,
              )
            {
              Ok(intersections) ->
                Ok(add_intersection_parameters(parameters, intersections))
              Error(svg_path.OverlappingSegments) ->
                overlapping_line_parameters(segment, against, parameters)
              Error(error) -> Error(error)
            },
          )
          split_parameters(edge, rest, intersection_options, parameters)
        }
      }
    }
  }
}

fn add_intersection_parameters(
  parameters: List(Float),
  intersections: List(svg_path.SegmentIntersection),
) -> List(Float) {
  list.fold(intersections, parameters, fn(parameters, intersection) {
    [clamp01(intersection.left_t), ..parameters]
  })
}

fn overlapping_line_parameters(
  segment: svg_path.Segment,
  against: svg_path.Segment,
  parameters: List(Float),
) -> Result(List(Float), svg_path.Error) {
  case segment, against {
    svg_path.Line(start: left_start, end: left_end),
      svg_path.Line(start: right_start, end: right_end)
    -> {
      let dx = left_end.x -. left_start.x
      let dy = left_end.y -. left_start.y
      case dx == 0.0 && dy == 0.0 {
        True -> Ok(parameters)
        False -> {
          let t0 = line_parameter(left_start, dx, dy, right_start)
          let t1 = line_parameter(left_start, dx, dy, right_end)
          Ok([clamp01(t0), clamp01(t1), ..parameters])
        }
      }
    }
    _, _ -> Error(svg_path.OverlappingSegments)
  }
}

fn line_parameter(
  start: svg_path.Point,
  dx: Float,
  dy: Float,
  point: svg_path.Point,
) -> Float {
  case float.absolute_value(dx) >=. float.absolute_value(dy) {
    True -> { point.x -. start.x } /. dx
    False -> { point.y -. start.y } /. dy
  }
}

fn retain_edge_pieces(
  pieces: List(svg_path.Segment),
  source source: Int,
  own_path own_path: svg_path.Path,
  against_path against_path: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  operation operation: Operation,
  side side: Side,
  options options: Options,
  retained retained: List(Piece),
) -> Result(List(Piece), svg_path.Error) {
  case pieces {
    [] -> Ok(retained)
    [piece, ..rest] -> {
      let Options(tolerance:, ..) = options
      use retained <- result.try(case degenerate_line(piece, tolerance) {
        True -> Ok(retained)
        False -> {
          let oriented = orient_piece(piece, operation, side)
          use retained_pieces <- result.try(keep_piece(
            piece,
            oriented:,
            source:,
            own_path:,
            against_path:,
            using: fill_rule,
            operation:,
            side:,
            options:,
          ))
          Ok(list.append(retained_pieces, retained))
        }
      })
      retain_edge_pieces(
        rest,
        source:,
        own_path:,
        against_path:,
        using: fill_rule,
        operation:,
        side:,
        options:,
        retained:,
      )
    }
  }
}

fn degenerate_line(segment: svg_path.Segment, tolerance: Float) -> Bool {
  case segment {
    svg_path.Line(start:, end:) -> same_point(start, end, tolerance)
    _ -> False
  }
}

fn keep_piece(
  piece: svg_path.Segment,
  oriented oriented: svg_path.Segment,
  source source: Int,
  own_path own_path: svg_path.Path,
  against_path against_path: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  operation operation: Operation,
  side side: Side,
  options options: Options,
) -> Result(List(Piece), svg_path.Error) {
  use midpoint <- result.try(svg_path.segment_point(piece, at: 0.5))
  use containment <- result.try(svg_path.path_containment_with(
    midpoint,
    within: against_path,
    using: fill_rule,
    options: options.containment,
  ))
  use separation <- result.try(separation_result(
    oriented,
    own_path:,
    against_path:,
    using: fill_rule,
    operation:,
    side:,
    options:,
  ))

  case operation, fill_rule {
    Union, svg_path.Nonzero ->
      Ok(nonzero_union_pieces(
        oriented,
        separation,
        source:,
        containment:,
        side:,
        internal: containment != svg_path.Boundary,
      ))
    _, _ -> {
      case separation {
        NoSeparation -> {
          case containment, operation {
            svg_path.Boundary, Union ->
              Ok([
                Piece(
                  segment: oriented,
                  level: 1,
                  role: OverlapPiece,
                  internal: False,
                  group: 0,
                ),
              ])
            _, _ -> Ok([])
          }
        }
        _ -> {
          case containment, operation, side {
            svg_path.Boundary, Union, RightSide -> Ok([])
            svg_path.Boundary, Intersection, RightSide -> Ok([])
            svg_path.Boundary, Difference, RightSide -> Ok([])
            _, _, _ -> {
              Ok(output_pieces(oriented, separation))
            }
          }
        }
      }
    }
  }
}

fn nonzero_union_pieces(
  oriented: svg_path.Segment,
  separation: Separation,
  source source: Int,
  containment containment: svg_path.PointContainment,
  side side: Side,
  internal internal: Bool,
) -> List(Piece) {
  case separation {
    NoSeparation -> {
      case containment, side {
        svg_path.Boundary, RightSide -> []
        _, _ -> [
          Piece(
            segment: oriented,
            level: source,
            role: SourcePiece,
            internal:,
            group: source,
          ),
          Piece(
            segment: svg_path.segment_reverse(oriented),
            level: source,
            role: SourcePiece,
            internal:,
            group: source,
          ),
        ]
      }
    }
    _ -> {
      case containment, side {
        svg_path.Boundary, RightSide -> []
        _, _ -> output_pieces(oriented, separation)
      }
    }
  }
}

fn output_pieces(
  oriented: svg_path.Segment,
  separation: Separation,
) -> List(Piece) {
  case separation {
    InteriorOnLeft(low_level:, high_level:) ->
      threshold_pieces(oriented, low_level, high_level, [])
    InteriorOnRight(low_level:, high_level:) ->
      threshold_pieces(
        svg_path.segment_reverse(oriented),
        low_level,
        high_level,
        [],
      )
    NoSeparation -> []
  }
}

fn threshold_pieces(
  segment: svg_path.Segment,
  low_level: Int,
  high_level: Int,
  pieces: List(Piece),
) -> List(Piece) {
  case high_level <= low_level {
    True -> pieces
    False ->
      threshold_pieces(segment, low_level, high_level - 1, [
        Piece(
          segment:,
          level: high_level,
          role: BoundaryPiece,
          internal: low_level > 0,
          group: 0,
        ),
        ..pieces
      ])
  }
}

fn separation_result(
  piece: svg_path.Segment,
  own_path own_path: svg_path.Path,
  against_path against_path: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  operation operation: Operation,
  side side: Side,
  options options: Options,
) -> Result(Separation, svg_path.Error) {
  use midpoint <- result.try(svg_path.segment_point(piece, at: 0.5))
  use derivative <- result.try(svg_path.segment_derivative(piece, at: 0.5))
  let length_squared =
    derivative.x *. derivative.x +. derivative.y *. derivative.y
  case length_squared <=. 0.0 {
    True -> Ok(NoSeparation)
    False -> {
      let assert Ok(length) = float.square_root(length_squared)
      let offset = options.tolerance *. 16.0
      let normal =
        svg_path.Point(
          { 0.0 -. derivative.y } /. length *. offset,
          derivative.x /. length *. offset,
        )
      let first = svg_path.Point(midpoint.x +. normal.x, midpoint.y +. normal.y)
      let second =
        svg_path.Point(midpoint.x -. normal.x, midpoint.y -. normal.y)
      use first_level <- result.try(result_level(
        first,
        own_path:,
        against_path:,
        using: fill_rule,
        operation:,
        side:,
        options:,
      ))
      use second_level <- result.try(result_level(
        second,
        own_path:,
        against_path:,
        using: fill_rule,
        operation:,
        side:,
        options:,
      ))
      Ok(level_separation(first_level, second_level))
    }
  }
}

fn result_level(
  point: svg_path.Point,
  own_path own_path: svg_path.Path,
  against_path against_path: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  operation operation: Operation,
  side side: Side,
  options options: Options,
) -> Result(Int, svg_path.Error) {
  use own_level <- result.try(path_level(
    point,
    within: own_path,
    using: fill_rule,
    options: options.containment,
  ))
  use against_level <- result.try(path_level(
    point,
    within: against_path,
    using: fill_rule,
    options: options.containment,
  ))
  let a_level = case side {
    LeftSide -> own_level
    RightSide -> against_level
  }
  let b_level = case side {
    LeftSide -> against_level
    RightSide -> own_level
  }

  Ok(output_level(a_level, b_level, using: fill_rule, operation:))
}

fn path_level(
  point: svg_path.Point,
  within path: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  options options: svg_path.ContainmentOptions,
) -> Result(Int, svg_path.Error) {
  case fill_rule {
    svg_path.EvenOdd -> {
      use containment <- result.try(svg_path.path_containment_with(
        point,
        within: path,
        using: fill_rule,
        options:,
      ))
      Ok(case containment {
        svg_path.Inside | svg_path.Boundary -> 1
        svg_path.Outside -> 0
      })
    }
    svg_path.Nonzero -> {
      use winding <- result.try(svg_path.path_winding_with(
        point,
        within: path,
        options:,
      ))
      case winding {
        svg_path.Winding(winding) -> Ok(winding)
        svg_path.BoundaryWinding -> {
          use containment <- result.try(svg_path.path_containment_with(
            point,
            within: path,
            using: fill_rule,
            options:,
          ))
          Ok(case containment {
            svg_path.Inside | svg_path.Boundary -> 1
            svg_path.Outside -> 0
          })
        }
      }
    }
  }
}

fn output_level(
  a_level: Int,
  b_level: Int,
  using fill_rule: svg_path.FillRule,
  operation operation: Operation,
) -> Int {
  case fill_rule {
    svg_path.EvenOdd -> {
      let a_inside = a_level != 0
      let b_inside = b_level != 0
      case operation {
        Union -> bool_level(a_inside || b_inside)
        Intersection -> bool_level(a_inside && b_inside)
        Difference -> bool_level(a_inside && !b_inside)
      }
    }
    svg_path.Nonzero -> {
      let a_inside = a_level != 0
      let b_inside = b_level != 0
      case operation {
        Union ->
          case a_inside || b_inside {
            True -> total_level(a_level, b_level)
            False -> 0
          }
        Intersection ->
          case a_inside && b_inside {
            True -> total_level(a_level, b_level)
            False -> 0
          }
        Difference ->
          case a_inside && !b_inside {
            True -> a_level
            False -> 0
          }
      }
    }
  }
}

fn bool_level(value: Bool) -> Int {
  case value {
    True -> 1
    False -> 0
  }
}

fn total_level(a_level: Int, b_level: Int) -> Int {
  int_absolute_value(a_level) + int_absolute_value(b_level)
}

fn level_separation(first_level: Int, second_level: Int) -> Separation {
  case first_level == second_level {
    True -> NoSeparation
    False -> {
      let first_strength = int_absolute_value(first_level)
      let second_strength = int_absolute_value(second_level)
      case first_strength > second_strength {
        True ->
          InteriorOnLeft(low_level: second_strength, high_level: first_strength)
        False ->
          case second_strength > first_strength {
            True ->
              InteriorOnRight(
                low_level: first_strength,
                high_level: second_strength,
              )
            False -> NoSeparation
          }
      }
    }
  }
}

fn int_absolute_value(value: Int) -> Int {
  case value < 0 {
    True -> 0 - value
    False -> value
  }
}

fn orient_piece(
  piece: svg_path.Segment,
  operation: Operation,
  side: Side,
) -> svg_path.Segment {
  case operation, side {
    Difference, RightSide -> svg_path.segment_reverse(piece)
    _, _ -> piece
  }
}

fn unique_pieces(
  pieces: List(Piece),
  tolerance: Float,
  kept: List(Piece),
) -> List(Piece) {
  case pieces {
    [] -> list.reverse(kept)
    [piece, ..rest] -> {
      case
        kept
        |> list.any(fn(kept_piece) { same_piece(piece, kept_piece, tolerance) })
      {
        True -> unique_pieces(rest, tolerance, kept)
        False -> unique_pieces(rest, tolerance, [piece, ..kept])
      }
    }
  }
}

fn same_piece(left: Piece, right: Piece, tolerance: Float) -> Bool {
  left.level == right.level
  && left.role == right.role
  && same_piece_group(left, right)
  && same_segment_geometry(left.segment, right.segment, tolerance)
}

fn same_piece_group(left: Piece, right: Piece) -> Bool {
  case left.role, right.role {
    SourcePiece, SourcePiece -> True
    _, _ -> left.group == right.group
  }
}

fn same_segment_geometry(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
) -> Bool {
  case left, right {
    svg_path.Line(start: left_start, end: left_end),
      svg_path.Line(start: right_start, end: right_end)
    ->
      same_point(left_start, right_start, tolerance)
      && same_point(left_end, right_end, tolerance)

    svg_path.QuadraticBezier(
      start: left_start,
      control: left_control,
      end: left_end,
    ),
      svg_path.QuadraticBezier(
        start: right_start,
        control: right_control,
        end: right_end,
      )
    ->
      same_point(left_start, right_start, tolerance)
      && same_point(left_control, right_control, tolerance)
      && same_point(left_end, right_end, tolerance)

    svg_path.CubicBezier(
      start: left_start,
      control1: left_control1,
      control2: left_control2,
      end: left_end,
    ),
      svg_path.CubicBezier(
        start: right_start,
        control1: right_control1,
        control2: right_control2,
        end: right_end,
      )
    ->
      same_point(left_start, right_start, tolerance)
      && same_point(left_control1, right_control1, tolerance)
      && same_point(left_control2, right_control2, tolerance)
      && same_point(left_end, right_end, tolerance)

    svg_path.Arc(
      start: left_start,
      radius: left_radius,
      x_axis_rotation: left_rotation,
      large_arc: left_large_arc,
      sweep: left_sweep,
      end: left_end,
    ),
      svg_path.Arc(
        start: right_start,
        radius: right_radius,
        x_axis_rotation: right_rotation,
        large_arc: right_large_arc,
        sweep: right_sweep,
        end: right_end,
      )
    ->
      same_point(left_start, right_start, tolerance)
      && same_point(left_radius, right_radius, tolerance)
      && floats_near(left_rotation, right_rotation, tolerance)
      && left_large_arc == right_large_arc
      && left_sweep == right_sweep
      && same_point(left_end, right_end, tolerance)

    _, _ -> False
  }
}

fn floats_near(left: Float, right: Float, tolerance: Float) -> Bool {
  float.absolute_value(left -. right) <=. tolerance
}

fn pieces_to_path(
  pieces: List(Piece),
  tolerance: Float,
) -> Result(svg_path.Path, svg_path.Error) {
  use contours <- result.try(pieces_to_contours(pieces, tolerance))
  Ok(contours_to_path(contours))
}

fn pieces_to_csg_path(
  pieces: List(Piece),
  fill_rule: svg_path.FillRule,
  tolerance: Float,
) -> Result(svg_path.Path, svg_path.Error) {
  let pieces = unique_pieces(pieces, tolerance, [])
  use contours <- result.try(pieces_to_contours(pieces, tolerance))
  use oriented <- result.try(orient_csg_contours(contours, fill_rule))
  Ok(contours_to_path(oriented))
}

fn pieces_to_contours(
  pieces: List(Piece),
  tolerance: Float,
) -> Result(List(OutputContour), svg_path.Error) {
  use chains <- result.try(chains(pieces, tolerance))
  chains
  |> list.map(chain_to_contour(tolerance))
  |> collect_contours([])
}

fn contours_to_path(contours: List(OutputContour)) -> svg_path.Path {
  contours
  |> list.map(fn(contour) {
    let OutputContour(subpath:, ..) = contour
    subpath
  })
  |> svg_path.Path
}

fn orient_csg_contours(
  contours: List(OutputContour),
  fill_rule: svg_path.FillRule,
) -> Result(List(OutputContour), svg_path.Error) {
  case fill_rule {
    svg_path.Nonzero -> orient_nonzero_contours(contours)
    svg_path.EvenOdd -> orient_hierarchy_contours(contours)
  }
}

fn orient_nonzero_contours(
  contours: List(OutputContour),
) -> Result(List(OutputContour), svg_path.Error) {
  Ok(
    list.map(contours, fn(contour) {
      let OutputContour(role:, internal:, ..) = contour
      case internal && role == BoundaryPiece {
        True -> orient_contour(contour, clockwise: True)
        False -> contour
      }
    }),
  )
}

fn orient_hierarchy_contours(
  contours: List(OutputContour),
) -> Result(List(OutputContour), svg_path.Error) {
  orient_hierarchy_contours_loop(contours, contours, [])
}

fn orient_hierarchy_contours_loop(
  remaining: List(OutputContour),
  all: List(OutputContour),
  oriented: List(OutputContour),
) -> Result(List(OutputContour), svg_path.Error) {
  case remaining {
    [] -> Ok(list.reverse(oriented))
    [contour, ..rest] -> {
      use depth <- result.try(contour_depth(contour, all))
      let assert Ok(remainder) = int.remainder(depth, by: 2)
      orient_hierarchy_contours_loop(rest, all, [
        orient_contour(contour, clockwise: remainder == 0),
        ..oriented
      ])
    }
  }
}

fn contour_depth(
  contour: OutputContour,
  all: List(OutputContour),
) -> Result(Int, svg_path.Error) {
  let OutputContour(subpath:, ..) = contour
  use probe <- result.try(contour_probe(subpath))
  contour_depth_loop(all, probe, 0)
}

fn contour_depth_loop(
  contours: List(OutputContour),
  probe: svg_path.Point,
  depth: Int,
) -> Result(Int, svg_path.Error) {
  case contours {
    [] -> Ok(depth)
    [OutputContour(subpath:, ..), ..rest] -> {
      use containment <- result.try(svg_path.subpath_containment(
        probe,
        within: subpath,
        using: svg_path.Nonzero,
      ))
      let depth = case containment {
        svg_path.Inside -> depth + 1
        svg_path.Boundary -> depth
        svg_path.Outside -> depth
      }
      contour_depth_loop(rest, probe, depth)
    }
  }
}

fn contour_probe(
  subpath: svg_path.Subpath,
) -> Result(svg_path.Point, svg_path.Error) {
  let assert [segment, ..] = svg_path.subpath_segments(subpath)
  svg_path.segment_point(segment, at: 0.5)
}

fn orient_contour(
  contour: OutputContour,
  clockwise clockwise: Bool,
) -> OutputContour {
  let OutputContour(subpath:, level:, role:, internal:) = contour
  let is_clockwise = area.signed_subpath(subpath) >=. 0.0
  case is_clockwise == clockwise {
    True -> contour
    False ->
      OutputContour(
        subpath: svg_path.subpath_reverse(subpath),
        level:,
        role:,
        internal:,
      )
  }
}

fn chains(
  pieces: List(Piece),
  tolerance: Float,
) -> Result(List(Chain), svg_path.Error) {
  chains_loop(pieces, tolerance, [])
}

fn chains_loop(
  pieces: List(Piece),
  tolerance: Float,
  chains: List(Chain),
) -> Result(List(Chain), svg_path.Error) {
  case pieces {
    [] -> Ok(list.reverse(chains))
    [first, ..rest] -> {
      use #(chain, remaining) <- result.try(grow_chain([first], rest, tolerance))
      chains_loop(remaining, tolerance, [
        Chain(pieces: list.reverse(chain)),
        ..chains
      ])
    }
  }
}

fn grow_chain(
  chain: List(Piece),
  remaining: List(Piece),
  tolerance: Float,
) -> Result(#(List(Piece), List(Piece)), svg_path.Error) {
  let assert [
    Piece(
      segment: last_segment,
      level: chain_level,
      role: chain_role,
      group: chain_group,
      ..,
    ),
    ..
  ] = chain
  let segments = list.map(chain, fn(piece) { piece.segment })
  let chain_end = svg_path.segment_end(last_segment)
  let chain_start =
    segments
    |> list.last
    |> result.unwrap(last_segment)
    |> svg_path.segment_start

  case same_point(chain_end, chain_start, tolerance) {
    True -> Ok(#(chain, remaining))
    False -> {
      use incoming_angle <- result.try(segment_end_angle(last_segment))
      let candidates =
        connecting_pieces(
          remaining,
          chain_level,
          chain_role,
          chain_group,
          chain_end,
          incoming_angle,
          tolerance,
          checked: [],
          candidates: [],
        )
      try_grow_candidates(candidates, chain, tolerance, chain_end, chain_start)
    }
  }
}

fn try_grow_candidates(
  candidates: List(Candidate),
  chain: List(Piece),
  tolerance: Float,
  chain_end: svg_path.Point,
  chain_start: svg_path.Point,
) -> Result(#(List(Piece), List(Piece)), svg_path.Error) {
  case candidates {
    [] ->
      Error(svg_path.Discontinuous(
        previous_index: 0,
        next_index: 1,
        expected: chain_end,
        got: chain_start,
        distance: distance(chain_end, chain_start),
      ))
    [Candidate(piece:, remaining:, ..), ..rest] -> {
      case grow_chain([piece, ..chain], remaining, tolerance) {
        Ok(result) -> Ok(result)
        Error(_) ->
          try_grow_candidates(rest, chain, tolerance, chain_end, chain_start)
      }
    }
  }
}

fn connecting_pieces(
  pieces: List(Piece),
  chain_level: Int,
  chain_role: PieceRole,
  chain_group: Int,
  point: svg_path.Point,
  incoming_angle: Float,
  tolerance: Float,
  checked checked: List(Piece),
  candidates candidates: List(Candidate),
) -> List(Candidate) {
  case pieces {
    [] -> list.sort(candidates, by: compare_candidates)
    [
      Piece(
        segment:,
        level: piece_level,
        role: piece_role,
        group: piece_group,
        ..,
      ) as piece,
      ..rest
    ] -> {
      case
        piece_level == chain_level
        && piece_role == chain_role
        && piece_group == chain_group
        && same_point(svg_path.segment_start(segment), point, tolerance)
      {
        True -> {
          let remaining = list.append(list.reverse(checked), rest)
          let score = outgoing_turn_score(segment, incoming_angle)
          connecting_pieces(
            rest,
            chain_level,
            chain_role,
            chain_group,
            point,
            incoming_angle,
            tolerance,
            checked: [piece, ..checked],
            candidates: [Candidate(piece:, remaining:, score:), ..candidates],
          )
        }
        False ->
          connecting_pieces(
            rest,
            chain_level,
            chain_role,
            chain_group,
            point,
            incoming_angle,
            tolerance,
            checked: [piece, ..checked],
            candidates:,
          )
      }
    }
  }
}

fn compare_candidates(left: Candidate, right: Candidate) -> order.Order {
  float.compare(left.score, right.score)
}

fn outgoing_turn_score(
  segment: svg_path.Segment,
  incoming_angle: Float,
) -> Float {
  case segment_start_angle(segment) {
    Error(_) -> 360.0
    Ok(outgoing_angle) -> positive_turn(incoming_angle, outgoing_angle)
  }
}

fn segment_start_angle(
  segment: svg_path.Segment,
) -> Result(Float, svg_path.Error) {
  use derivative <- result.try(svg_path.segment_derivative(segment, at: 0.0))
  Ok(trig.atan2_degrees(derivative.y, derivative.x))
}

fn segment_end_angle(
  segment: svg_path.Segment,
) -> Result(Float, svg_path.Error) {
  use derivative <- result.try(svg_path.segment_derivative(segment, at: 1.0))
  Ok(trig.atan2_degrees(derivative.y, derivative.x))
}

fn positive_turn(from: Float, to: Float) -> Float {
  let turn = to -. from
  let turns = float.floor(turn /. 360.0)
  let normalized = turn -. turns *. 360.0
  case normalized <. 0.0 {
    True -> normalized +. 360.0
    False -> normalized
  }
}

fn chain_to_contour(
  tolerance: Float,
) -> fn(Chain) -> Result(OutputContour, svg_path.Error) {
  fn(chain) {
    let Chain(pieces:) = chain
    let assert [Piece(level:, role:, ..), ..] = pieces
    let internal = list.all(pieces, fn(piece) { piece.internal })
    let segments = list.map(pieces, fn(piece) { piece.segment })
    use segments <- result.try(snap_chain(segments, tolerance))
    use subpath <- result.try(svg_path.subpath_with(
      segments,
      policy: svg_path.Strict,
    ))
    use closed <- result.try(svg_path.subpath_set_closed_with(
      subpath,
      closed: True,
      policy: svg_path.Strict,
    ))
    Ok(OutputContour(subpath: closed, level:, role:, internal:))
  }
}

fn snap_chain(
  segments: List(svg_path.Segment),
  tolerance: Float,
) -> Result(List(svg_path.Segment), svg_path.Error) {
  case segments {
    [] -> Ok([])
    [first, ..rest] -> {
      use open <- result.try(snap_open_chain(rest, first, tolerance, [first]))
      snap_closed_chain(open, tolerance)
    }
  }
}

fn snap_open_chain(
  remaining: List(svg_path.Segment),
  previous: svg_path.Segment,
  tolerance: Float,
  snapped: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), svg_path.Error) {
  case remaining {
    [] -> Ok(list.reverse(snapped))
    [next, ..rest] -> {
      let expected = svg_path.segment_end(previous)
      let got = svg_path.segment_start(next)
      case same_point(expected, got, tolerance) {
        True -> {
          let next = segment_with_start(next, expected)
          snap_open_chain(rest, next, tolerance, [next, ..snapped])
        }
        False ->
          Error(svg_path.Discontinuous(
            previous_index: 0,
            next_index: 1,
            expected:,
            got:,
            distance: distance(expected, got),
          ))
      }
    }
  }
}

fn snap_closed_chain(
  segments: List(svg_path.Segment),
  tolerance: Float,
) -> Result(List(svg_path.Segment), svg_path.Error) {
  case segments {
    [] -> Ok([])
    [first, ..] -> {
      let first_start = svg_path.segment_start(first)
      let last = segments |> list.last |> result.unwrap(first)
      let last_end = svg_path.segment_end(last)
      case same_point(last_end, first_start, tolerance) {
        True -> Ok(replace_last_end(segments, first_start, []))
        False ->
          Error(svg_path.Discontinuous(
            previous_index: 0,
            next_index: 1,
            expected: first_start,
            got: last_end,
            distance: distance(first_start, last_end),
          ))
      }
    }
  }
}

fn replace_last_end(
  segments: List(svg_path.Segment),
  end: svg_path.Point,
  checked: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case segments {
    [] -> list.reverse(checked)
    [only] -> list.reverse([segment_with_end(only, end), ..checked])
    [first, ..rest] -> replace_last_end(rest, end, [first, ..checked])
  }
}

fn segment_with_start(
  segment: svg_path.Segment,
  new_start: svg_path.Point,
) -> svg_path.Segment {
  case segment {
    svg_path.Line(end:, ..) -> svg_path.Line(start: new_start, end:)
    svg_path.QuadraticBezier(control:, end:, ..) ->
      svg_path.QuadraticBezier(start: new_start, control:, end:)
    svg_path.CubicBezier(control1:, control2:, end:, ..) ->
      svg_path.CubicBezier(start: new_start, control1:, control2:, end:)
    svg_path.Arc(radius:, x_axis_rotation:, large_arc:, sweep:, end:, ..) ->
      svg_path.Arc(
        start: new_start,
        radius:,
        x_axis_rotation:,
        large_arc:,
        sweep:,
        end:,
      )
  }
}

fn segment_with_end(
  segment: svg_path.Segment,
  new_end: svg_path.Point,
) -> svg_path.Segment {
  case segment {
    svg_path.Line(start:, ..) -> svg_path.Line(start:, end: new_end)
    svg_path.QuadraticBezier(start:, control:, ..) ->
      svg_path.QuadraticBezier(start:, control:, end: new_end)
    svg_path.CubicBezier(start:, control1:, control2:, ..) ->
      svg_path.CubicBezier(start:, control1:, control2:, end: new_end)
    svg_path.Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, ..) ->
      svg_path.Arc(
        start:,
        radius:,
        x_axis_rotation:,
        large_arc:,
        sweep:,
        end: new_end,
      )
  }
}

fn collect_contours(
  results: List(Result(OutputContour, svg_path.Error)),
  contours: List(OutputContour),
) -> Result(List(OutputContour), svg_path.Error) {
  case results {
    [] -> Ok(list.reverse(contours))
    [result, ..rest] -> {
      use contour <- result.try(result)
      collect_contours(rest, [contour, ..contours])
    }
  }
}

fn unique_floats(
  values: List(Float),
  tolerance: Float,
  unique: List(Float),
) -> List(Float) {
  case values {
    [] -> list.reverse(unique)
    [value, ..rest] -> {
      case unique {
        [previous, ..] -> {
          case float.absolute_value(value -. previous) <=. tolerance {
            True -> unique_floats(rest, tolerance, unique)
            False -> unique_floats(rest, tolerance, [value, ..unique])
          }
        }
        _ -> unique_floats(rest, tolerance, [value, ..unique])
      }
    }
  }
}

fn clamp01(value: Float) -> Float {
  case value <. 0.0 {
    True -> 0.0
    False ->
      case value >. 1.0 {
        True -> 1.0
        False -> value
      }
  }
}

fn same_point(a: svg_path.Point, b: svg_path.Point, tolerance: Float) -> Bool {
  point_helpers.near(a, b, tolerance:)
}

fn distance(a: svg_path.Point, b: svg_path.Point) -> Float {
  point_helpers.distance(a, b)
}

fn assembly_tolerance(tolerance: Float) -> Float {
  tolerance *. 32.0
}
