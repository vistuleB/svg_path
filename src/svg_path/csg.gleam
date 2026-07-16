//// Boolean operations on filled SVG paths.
////
//// This first implementation works by linearizing input paths, splitting line
//// pieces at point intersections, classifying each piece against the other
//// operand, and assembling closed line subpaths from the retained pieces.
//// Coincident line edges are split at their overlap endpoints and resolved by
//// deterministic boundary ownership rules.

import gleam/float
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import svg_path

const default_tolerance = 0.000000001

type Operation {
  Union
  Intersection
  Difference
}

type Edge {
  Edge(segment: svg_path.Segment)
}

type Piece {
  Piece(segment: svg_path.Segment)
}

type Chain {
  Chain(segments: List(svg_path.Segment))
}

/// Options for path CSG operations.
pub type Options {
  Options(
    linearize: svg_path.LinearizeOptions,
    intersection: svg_path.IntersectionOptions,
    containment: svg_path.ContainmentOptions,
    tolerance: Float,
  )
}

/// Return default CSG options.
pub fn default_options() -> Options {
  Options(
    linearize: svg_path.default_linearize_options(),
    intersection: svg_path.default_intersection_options(),
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
  csg(left, right, using: fill_rule, operation: Union, options:)
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

fn csg(
  left: svg_path.Path,
  right: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  operation operation: Operation,
  options options: Options,
) -> Result(svg_path.Path, svg_path.Error) {
  use linear_left <- result.try(svg_path.path_to_lines_with(
    left,
    options: options.linearize,
  ))
  use linear_right <- result.try(svg_path.path_to_lines_with(
    right,
    options: options.linearize,
  ))

  let left_edges = path_edges(linear_left)
  let right_edges = path_edges(linear_right)

  use left_pieces <- result.try(retained_pieces(
    left_edges,
    against_edges: right_edges,
    against_path: linear_right,
    using: fill_rule,
    operation: operation,
    side: LeftSide,
    options:,
  ))
  use right_pieces <- result.try(retained_pieces(
    right_edges,
    against_edges: left_edges,
    against_path: linear_left,
    using: fill_rule,
    operation: operation,
    side: RightSide,
    options:,
  ))

  pieces_to_path(list.append(left_pieces, right_pieces), options.tolerance)
}

type Side {
  LeftSide
  RightSide
}

fn path_edges(path: svg_path.Path) -> List(Edge) {
  path
  |> svg_path.subpaths
  |> list.flat_map(subpath_edges)
}

fn subpath_edges(subpath: svg_path.Subpath) -> List(Edge) {
  let segments = svg_path.segments(subpath)
  case segments {
    [] -> []
    _ -> {
      let start =
        svg_path.start(subpath) |> result.unwrap(svg_path.point(0.0, 0.0))
      let end = svg_path.end(subpath) |> result.unwrap(start)
      let edges =
        segments
        |> list.filter_map(fn(segment) {
          case segment {
            svg_path.Line(start:, end:) -> {
              case same_point(start, end, 0.0) {
                True -> Error(Nil)
                False -> Ok(Edge(segment:))
              }
            }
            _ -> Error(Nil)
          }
        })

      case same_point(start, end, 0.0) {
        True -> edges
        False ->
          list.append(edges, [Edge(svg_path.Line(start: end, end: start))])
      }
    }
  }
}

fn retained_pieces(
  edges: List(Edge),
  against_edges against_edges: List(Edge),
  against_path against_path: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  operation operation: Operation,
  side side: Side,
  options options: Options,
) -> Result(List(Piece), svg_path.Error) {
  retained_pieces_loop(
    edges,
    against_edges:,
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
  against_edges against_edges: List(Edge),
  against_path against_path: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  operation operation: Operation,
  side side: Side,
  options options: Options,
  retained retained: List(Piece),
) -> Result(List(Piece), svg_path.Error) {
  case edges {
    [] -> Ok(list.reverse(retained))
    [edge, ..rest] -> {
      use pieces <- result.try(split_edge(
        edge,
        against_edges,
        options.intersection,
        options.tolerance,
      ))
      use retained <- result.try(retain_edge_pieces(
        pieces,
        against_path:,
        using: fill_rule,
        operation:,
        side:,
        options:,
        retained:,
      ))
      retained_pieces_loop(
        rest,
        against_edges:,
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
  against_edges: List(Edge),
  intersection_options: svg_path.IntersectionOptions,
  tolerance: Float,
) -> Result(List(svg_path.Segment), svg_path.Error) {
  let Edge(segment:) = edge
  use ts <- result.try(
    split_parameters(segment, against_edges, intersection_options, [0.0, 1.0]),
  )
  let ts = ts |> list.sort(by: float.compare) |> unique_floats(tolerance, [])
  svg_path.segments_between_inside(segment, between: ts)
}

fn split_parameters(
  segment: svg_path.Segment,
  against_edges: List(Edge),
  intersection_options: svg_path.IntersectionOptions,
  parameters: List(Float),
) -> Result(List(Float), svg_path.Error) {
  case against_edges {
    [] -> Ok(parameters)
    [Edge(segment: against), ..rest] -> {
      use parameters <- result.try(
        case
          svg_path.segment_intersections_with(
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
      split_parameters(segment, rest, intersection_options, parameters)
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
      use keep <- result.try(keep_piece(
        piece,
        against_path:,
        using: fill_rule,
        operation:,
        side:,
        options:,
      ))
      let retained = case keep {
        False -> retained
        True -> [
          Piece(segment: orient_piece(piece, operation, side)),
          ..retained
        ]
      }
      retain_edge_pieces(
        rest,
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

fn keep_piece(
  piece: svg_path.Segment,
  against_path against_path: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  operation operation: Operation,
  side side: Side,
  options options: Options,
) -> Result(Bool, svg_path.Error) {
  use midpoint <- result.try(svg_path.segment_point(piece, at: 0.5))
  use containment <- result.try(svg_path.path_containment_with(
    midpoint,
    within: against_path,
    using: fill_rule,
    options: options.containment,
  ))
  let inside = case containment {
    svg_path.Inside -> True
    svg_path.Boundary -> True
    svg_path.Outside -> False
  }

  case containment {
    svg_path.Boundary ->
      Ok(case operation, side {
        Union, LeftSide -> True
        Union, RightSide -> False
        Intersection, LeftSide -> True
        Intersection, RightSide -> False
        Difference, LeftSide | Difference, RightSide -> False
      })
    _ ->
      Ok(case operation, side {
        Union, LeftSide | Union, RightSide -> !inside
        Intersection, LeftSide | Intersection, RightSide -> inside
        Difference, LeftSide -> !inside
        Difference, RightSide -> inside
      })
  }
}

fn orient_piece(
  piece: svg_path.Segment,
  operation: Operation,
  side: Side,
) -> svg_path.Segment {
  case operation, side {
    Difference, RightSide -> svg_path.reverse_segment(piece)
    _, _ -> piece
  }
}

fn pieces_to_path(
  pieces: List(Piece),
  tolerance: Float,
) -> Result(svg_path.Path, svg_path.Error) {
  pieces
  |> chains(tolerance)
  |> list.map(chain_to_subpath(tolerance))
  |> collect_subpaths([])
  |> result.map(fn(subpaths) { svg_path.Path(subpaths:) })
}

fn chains(pieces: List(Piece), tolerance: Float) -> List(Chain) {
  chains_loop(pieces, tolerance, [])
}

fn chains_loop(
  pieces: List(Piece),
  tolerance: Float,
  chains: List(Chain),
) -> List(Chain) {
  case pieces {
    [] -> list.reverse(chains)
    [Piece(segment: first), ..rest] -> {
      let #(chain, remaining) = grow_chain([first], rest, tolerance)
      chains_loop(remaining, tolerance, [
        Chain(segments: list.reverse(chain)),
        ..chains
      ])
    }
  }
}

fn grow_chain(
  chain: List(svg_path.Segment),
  remaining: List(Piece),
  tolerance: Float,
) -> #(List(svg_path.Segment), List(Piece)) {
  let assert [last, ..] = chain
  let chain_end = svg_path.segment_end(last)
  let chain_start =
    chain |> list.last |> result.unwrap(last) |> svg_path.segment_start

  case same_point(chain_end, chain_start, tolerance) {
    True -> #(chain, remaining)
    False -> {
      case take_connecting_piece(remaining, chain_end, tolerance, checked: []) {
        None -> #(chain, remaining)
        Some(#(next, remaining)) ->
          grow_chain([next, ..chain], remaining, tolerance)
      }
    }
  }
}

fn take_connecting_piece(
  pieces: List(Piece),
  point: svg_path.Point,
  tolerance: Float,
  checked checked: List(Piece),
) -> Option(#(svg_path.Segment, List(Piece))) {
  case pieces {
    [] -> None
    [Piece(segment:), ..rest] -> {
      case same_point(svg_path.segment_start(segment), point, tolerance) {
        True -> Some(#(segment, list.append(list.reverse(checked), rest)))
        False -> {
          case same_point(svg_path.segment_end(segment), point, tolerance) {
            True ->
              Some(#(
                svg_path.reverse_segment(segment),
                list.append(list.reverse(checked), rest),
              ))
            False ->
              take_connecting_piece(rest, point, tolerance, checked: [
                Piece(segment:),
                ..checked
              ])
          }
        }
      }
    }
  }
}

fn chain_to_subpath(
  _tolerance: Float,
) -> fn(Chain) -> Result(svg_path.Subpath, svg_path.Error) {
  fn(chain) {
    let Chain(segments:) = chain
    use subpath <- result.try(svg_path.subpath_with(
      segments,
      policy: svg_path.WiggleThenBridge,
    ))
    use closed <- result.try(svg_path.set_closed_with(
      subpath,
      closed: True,
      policy: svg_path.Bridge,
    ))
    Ok(closed)
  }
}

fn collect_subpaths(
  results: List(Result(svg_path.Subpath, svg_path.Error)),
  subpaths: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), svg_path.Error) {
  case results {
    [] -> Ok(list.reverse(subpaths))
    [result, ..rest] -> {
      use subpath <- result.try(result)
      collect_subpaths(rest, [subpath, ..subpaths])
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
  let dx = a.x -. b.x
  let dy = a.y -. b.y
  dx *. dx +. dy *. dy <=. tolerance *. tolerance
}
