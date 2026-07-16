//// Boolean operations on filled SVG paths.
////
//// The `using` fill rule is part of the operation: both input paths are first
//// interpreted as filled sets under that rule, the Boolean operation is
//// applied to those sets, and the returned path fills as the resulting set
//// under the same rule.
////
//// Open subpaths are treated as implicitly closed for fill purposes. Empty
//// paths and move-only subpaths contribute no filled area.
////
//// The implementation preserves original segment types where possible. It
//// splits original path segments at point intersections, classifies each
//// resulting directed piece by the filled state on its left and right sides,
//// orients retained pieces with the result interior on their left, and
//// assembles closed subpaths from those retained pieces. Curved segments
//// remain curved between real encounters; only implicit closing edges are
//// added as lines. Coincident line edges are split at their overlap endpoints
//// and resolved by deterministic boundary ownership rules.

import gleam/float
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import svg_path
import svg_path/trig

const default_tolerance = 0.000001

type Operation {
  Union
  Intersection
  Difference
}

type Edge {
  Edge(id: Int, segment: svg_path.Segment)
}

type Piece {
  Piece(segment: svg_path.Segment)
}

type Chain {
  Chain(segments: List(svg_path.Segment))
}

type Separation {
  NoSeparation
  InteriorOnLeft
  InteriorOnRight
}

/// Options for path CSG operations.
pub type Options {
  Options(
    intersection: svg_path.IntersectionOptions,
    containment: svg_path.ContainmentOptions,
    tolerance: Float,
  )
}

/// Return default CSG options.
pub fn default_options() -> Options {
  Options(
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

  pieces_to_path(
    list.append(left_pieces, right_pieces),
    assembly_tolerance(options.tolerance),
  )
}

type Side {
  LeftSide
  RightSide
}

fn path_edges(path: svg_path.Path, offset offset: Int) -> List(Edge) {
  path
  |> svg_path.subpaths
  |> list.flat_map(subpath_edges)
  |> list.index_map(fn(segment, index) { Edge(id: offset + index, segment:) })
}

fn subpath_edges(subpath: svg_path.Subpath) -> List(svg_path.Segment) {
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
    [edge, ..rest] -> {
      use pieces <- result.try(split_edge(
        edge,
        split_edges,
        options.intersection,
        options.tolerance,
      ))
      use retained <- result.try(retain_edge_pieces(
        pieces,
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
  intersection_options: svg_path.IntersectionOptions,
  tolerance: Float,
) -> Result(List(svg_path.Segment), svg_path.Error) {
  let Edge(segment:, ..) = edge
  use ts <- result.try(
    split_parameters(edge, split_edges, intersection_options, [0.0, 1.0]),
  )
  let ts = ts |> list.sort(by: float.compare) |> unique_floats(tolerance, [])
  svg_path.segments_between_inside(segment, between: ts)
}

fn split_parameters(
  edge: Edge,
  against_edges: List(Edge),
  intersection_options: svg_path.IntersectionOptions,
  parameters: List(Float),
) -> Result(List(Float), svg_path.Error) {
  let Edge(id:, segment:) = edge
  case against_edges {
    [] -> Ok(parameters)
    [Edge(id: against_id, segment: against), ..rest] -> {
      case id == against_id {
        True -> split_parameters(edge, rest, intersection_options, parameters)
        False -> {
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
          use retained_piece <- result.try(keep_piece(
            piece,
            oriented:,
            own_path:,
            against_path:,
            using: fill_rule,
            operation:,
            side:,
            options:,
          ))
          Ok(case retained_piece {
            None -> retained
            Some(segment) -> [Piece(segment:), ..retained]
          })
        }
      })
      retain_edge_pieces(
        rest,
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
  own_path own_path: svg_path.Path,
  against_path against_path: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  operation operation: Operation,
  side side: Side,
  options options: Options,
) -> Result(Option(svg_path.Segment), svg_path.Error) {
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

  case separation {
    NoSeparation -> Ok(None)
    _ -> {
      case containment, operation, side {
        svg_path.Boundary, Union, RightSide -> Ok(None)
        svg_path.Boundary, Intersection, RightSide -> Ok(None)
        svg_path.Boundary, Difference, RightSide -> Ok(None)
        _, _, _ -> {
          let output_segment = case separation {
            InteriorOnLeft -> oriented
            InteriorOnRight -> svg_path.reverse_segment(oriented)
            NoSeparation -> oriented
          }
          Ok(Some(output_segment))
        }
      }
    }
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
        svg_path.point(
          { 0.0 -. derivative.y } /. length *. offset,
          derivative.x /. length *. offset,
        )
      let first = svg_path.point(midpoint.x +. normal.x, midpoint.y +. normal.y)
      let second =
        svg_path.point(midpoint.x -. normal.x, midpoint.y -. normal.y)
      use first_inside <- result.try(result_contains(
        first,
        own_path:,
        against_path:,
        using: fill_rule,
        operation:,
        side:,
        options:,
      ))
      use second_inside <- result.try(result_contains(
        second,
        own_path:,
        against_path:,
        using: fill_rule,
        operation:,
        side:,
        options:,
      ))
      Ok(case first_inside, second_inside {
        True, False -> InteriorOnLeft
        False, True -> InteriorOnRight
        _, _ -> NoSeparation
      })
    }
  }
}

fn result_contains(
  point: svg_path.Point,
  own_path own_path: svg_path.Path,
  against_path against_path: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  operation operation: Operation,
  side side: Side,
  options options: Options,
) -> Result(Bool, svg_path.Error) {
  use own <- result.try(svg_path.path_containment_with(
    point,
    within: own_path,
    using: fill_rule,
    options: options.containment,
  ))
  use against <- result.try(svg_path.path_containment_with(
    point,
    within: against_path,
    using: fill_rule,
    options: options.containment,
  ))
  let a_inside = case side {
    LeftSide -> containment_inside(own)
    RightSide -> containment_inside(against)
  }
  let b_inside = case side {
    LeftSide -> containment_inside(against)
    RightSide -> containment_inside(own)
  }

  Ok(case operation {
    Union -> a_inside || b_inside
    Intersection -> a_inside && b_inside
    Difference -> a_inside && !b_inside
  })
}

fn containment_inside(containment: svg_path.PointContainment) -> Bool {
  case containment {
    svg_path.Inside | svg_path.Boundary -> True
    svg_path.Outside -> False
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
  use chains <- result.try(chains(pieces, tolerance))
  chains
  |> list.map(chain_to_subpath(tolerance))
  |> collect_subpaths([])
  |> result.map(fn(subpaths) { svg_path.Path(subpaths:) })
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
    [Piece(segment: first), ..rest] -> {
      use #(chain, remaining) <- result.try(grow_chain([first], rest, tolerance))
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
) -> Result(#(List(svg_path.Segment), List(Piece)), svg_path.Error) {
  let assert [last, ..] = chain
  let chain_end = svg_path.segment_end(last)
  let chain_start =
    chain |> list.last |> result.unwrap(last) |> svg_path.segment_start

  case same_point(chain_end, chain_start, tolerance) {
    True -> Ok(#(chain, remaining))
    False -> {
      use incoming_angle <- result.try(segment_end_angle(last))
      case
        take_connecting_piece(
          remaining,
          chain_end,
          incoming_angle,
          tolerance,
          checked: [],
          best: None,
        )
      {
        None ->
          Error(svg_path.Discontinuous(
            previous_index: 0,
            next_index: 1,
            expected: chain_end,
            got: chain_start,
            distance: distance(chain_end, chain_start),
          ))
        Some(#(next, remaining)) -> {
          grow_chain([next, ..chain], remaining, tolerance)
        }
      }
    }
  }
}

fn take_connecting_piece(
  pieces: List(Piece),
  point: svg_path.Point,
  incoming_angle: Float,
  tolerance: Float,
  checked checked: List(Piece),
  best best: Option(#(svg_path.Segment, List(Piece), Float)),
) -> Option(#(svg_path.Segment, List(Piece))) {
  case pieces {
    [] -> {
      case best {
        None -> None
        Some(#(segment, remaining, _score)) -> Some(#(segment, remaining))
      }
    }
    [Piece(segment:), ..rest] -> {
      case same_point(svg_path.segment_start(segment), point, tolerance) {
        True -> {
          let remaining = list.append(list.reverse(checked), rest)
          let score = outgoing_turn_score(segment, incoming_angle)
          let best =
            better_connection(best, candidate: #(segment, remaining, score))
          take_connecting_piece(
            rest,
            point,
            incoming_angle,
            tolerance,
            checked: [Piece(segment:), ..checked],
            best:,
          )
        }
        False ->
          take_connecting_piece(
            rest,
            point,
            incoming_angle,
            tolerance,
            checked: [Piece(segment:), ..checked],
            best:,
          )
      }
    }
  }
}

fn better_connection(
  best: Option(#(svg_path.Segment, List(Piece), Float)),
  candidate candidate: #(svg_path.Segment, List(Piece), Float),
) -> Option(#(svg_path.Segment, List(Piece), Float)) {
  case best {
    None -> Some(candidate)
    Some(#(_segment, _remaining, best_score)) -> {
      let #(_candidate_segment, _candidate_remaining, score) = candidate
      case score <. best_score {
        True -> Some(candidate)
        False -> best
      }
    }
  }
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
  case turn <. 0.0 {
    True -> positive_turn(from, to +. 360.0)
    False ->
      case turn >=. 360.0 {
        True -> positive_turn(from, to -. 360.0)
        False -> turn
      }
  }
}

fn chain_to_subpath(
  tolerance: Float,
) -> fn(Chain) -> Result(svg_path.Subpath, svg_path.Error) {
  fn(chain) {
    let Chain(segments:) = chain
    use segments <- result.try(snap_chain(segments, tolerance))
    use subpath <- result.try(svg_path.subpath_with(
      segments,
      policy: svg_path.Strict,
    ))
    use closed <- result.try(svg_path.set_closed_with(
      subpath,
      closed: True,
      policy: svg_path.Strict,
    ))
    Ok(closed)
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

fn distance(a: svg_path.Point, b: svg_path.Point) -> Float {
  let dx = a.x -. b.x
  let dy = a.y -. b.y
  let assert Ok(root) = float.square_root(dx *. dx +. dy *. dy)
  root
}

fn assembly_tolerance(tolerance: Float) -> Float {
  tolerance *. 32.0
}
