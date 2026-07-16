//// Signed and fill-rule area calculations for SVG path geometry.
////
//// Signed area is computed directly from segment line integrals. Fill-rule
//// area linearizes curves, builds a planar line arrangement, and integrates
//// the filled vertical intervals of each arrangement slab.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import svg_path
import svg_path/trig

type Edge {
  Edge(start: svg_path.Point, end: svg_path.Point)
}

type Crossing {
  Crossing(edge: Edge, y: Float, winding: Int)
}

type CrossingGroup {
  CrossingGroup(edge: Edge, y: Float, winding: Int, crossings: Int)
}

const arrangement_relative_tolerance = 0.000000000001

/// Return the signed area of a polygonal point loop.
///
/// The final point is implicitly connected to the first. Lists with fewer than
/// three points have zero area. Positive and negative signs represent opposite
/// traversal directions.
pub fn signed_points(points: List(svg_path.Point)) -> Float {
  case points {
    [] | [_] | [_, _] -> 0.0
    [first, ..rest] ->
      signed_points_loop(rest, first: first, previous: first, integral: 0.0)
      /. 2.0
  }
}

/// Return one segment's contribution to a closed curve's signed area.
///
/// Lines and Beziers are integrated exactly as polynomials. Elliptical arcs use
/// their exact center parameterization. A degenerate arc contributes the same
/// value as the straight line between its endpoints.
pub fn signed_segment(segment: svg_path.Segment) -> Float {
  case segment {
    svg_path.Line(start:, end:) -> cross(start, end) /. 2.0
    svg_path.QuadraticBezier(start:, control:, end:) ->
      quadratic_signed_segment(start, control, end)
    svg_path.CubicBezier(start:, control1:, control2:, end:) ->
      cubic_signed_segment(start, control1, control2, end)
    svg_path.Arc(start:, end:, ..) -> {
      case svg_path.arc_center_data(segment) {
        Error(_) -> cross(start, end) /. 2.0
        Ok(arc) -> {
          let delta = trig.degrees_to_radians(arc.delta_angle)
          {
            cross(
              svg_path.point(arc.center.x, arc.center.y),
              difference(end, start),
            )
            +. arc.radius.x
            *. arc.radius.y
            *. delta
          }
          /. 2.0
        }
      }
    }
  }
}

/// Return a subpath's signed area, implicitly closing it when necessary.
///
/// The subpath's `closed` field does not affect the result. Move-only subpaths
/// have zero area.
pub fn signed_subpath(subpath: svg_path.Subpath) -> Float {
  let segments = svg_path.segments(subpath)
  case segments {
    [] -> 0.0
    _ -> {
      let start =
        svg_path.start(subpath) |> result.unwrap(svg_path.point(0.0, 0.0))
      let end = svg_path.end(subpath) |> result.unwrap(start)
      list.fold(segments, 0.0, fn(area, segment) {
        area +. signed_segment(segment)
      })
      +. cross(end, start)
      /. 2.0
    }
  }
}

/// Return the sum of the signed areas of a path's subpaths.
///
/// This is algebraic area: repeated loops can multiply the value and opposite
/// loops can cancel. Use `path` for SVG fill-rule area.
pub fn signed_path(path: svg_path.Path) -> Float {
  path
  |> svg_path.subpaths
  |> list.fold(0.0, fn(area, subpath) { area +. signed_subpath(subpath) })
}

/// Approximate a subpath's filled area using the default linearization options.
pub fn subpath(
  subpath: svg_path.Subpath,
  using fill_rule: svg_path.FillRule,
) -> Result(Float, svg_path.Error) {
  subpath_with(
    subpath,
    using: fill_rule,
    options: svg_path.default_linearize_options(),
  )
}

/// Approximate a subpath's filled area using explicit linearization options.
///
/// `options.tolerance` is a geometric curve-to-line tolerance, not a direct
/// bound on the final area error.
pub fn subpath_with(
  subpath: svg_path.Subpath,
  using fill_rule: svg_path.FillRule,
  options options: svg_path.LinearizeOptions,
) -> Result(Float, svg_path.Error) {
  path_with(svg_path.from_subpath(subpath), using: fill_rule, options:)
}

/// Approximate a path's combined filled area using the default linearization
/// options.
pub fn path(
  path: svg_path.Path,
  using fill_rule: svg_path.FillRule,
) -> Result(Float, svg_path.Error) {
  path_with(
    path,
    using: fill_rule,
    options: svg_path.default_linearize_options(),
  )
}

/// Approximate a path's combined filled area using explicit linearization
/// options.
///
/// Every nonempty subpath is implicitly closed. Move-only subpaths contribute
/// no area. Curves are linearized before their line arrangement is decomposed
/// into vertical slabs; each slab is then integrated exactly.
pub fn path_with(
  path: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  options options: svg_path.LinearizeOptions,
) -> Result(Float, svg_path.Error) {
  use linearized <- result.try(svg_path.path_to_lines_with(path, options:))
  let edges = linearized |> svg_path.subpaths |> subpath_edges(accumulated: [])
  case edges {
    [] -> Ok(0.0)
    _ -> {
      let tolerance = arrangement_tolerance(edges)
      let xs = arrangement_xs(edges, tolerance)
      Ok(slabs_area(xs, edges, fill_rule, tolerance, area: 0.0))
    }
  }
}

fn signed_points_loop(
  points: List(svg_path.Point),
  first first: svg_path.Point,
  previous previous: svg_path.Point,
  integral integral: Float,
) -> Float {
  case points {
    [] -> integral +. cross(previous, first)
    [point, ..rest] ->
      signed_points_loop(
        rest,
        first:,
        previous: point,
        integral: integral +. cross(previous, point),
      )
  }
}

fn quadratic_signed_segment(
  start: svg_path.Point,
  control: svg_path.Point,
  end: svg_path.Point,
) -> Float {
  let a = combine3(start, 1.0, control, -2.0, end, 1.0)
  let b = combine2(control, 2.0, start, -2.0)
  let c = start

  { { 0.0 -. cross(a, b) } /. 3.0 +. cross(c, a) +. cross(c, b) } /. 2.0
}

fn cubic_signed_segment(
  start: svg_path.Point,
  control1: svg_path.Point,
  control2: svg_path.Point,
  end: svg_path.Point,
) -> Float {
  let a = combine4(start, -1.0, control1, 3.0, control2, -3.0, end, 1.0)
  let b = combine3(start, 3.0, control1, -6.0, control2, 3.0)
  let c = combine2(control1, 3.0, start, -3.0)
  let d = start

  {
    { 0.0 -. cross(a, b) }
    /. 5.0
    -. cross(a, c)
    /. 2.0
    +. { { 0.0 -. cross(b, c) } +. 3.0 *. cross(d, a) }
    /. 3.0
    +. cross(d, b)
    +. cross(d, c)
  }
  /. 2.0
}

fn subpath_edges(
  subpaths: List(svg_path.Subpath),
  accumulated accumulated: List(Edge),
) -> List(Edge) {
  case subpaths {
    [] -> list.reverse(accumulated)
    [subpath, ..rest] -> {
      let segments = svg_path.segments(subpath)
      case segments {
        [] -> subpath_edges(rest, accumulated:)
        _ -> {
          let accumulated =
            list.fold(segments, accumulated, fn(edges, segment) {
              let assert svg_path.Line(start:, end:) = segment
              add_edge(start, end, edges)
            })
          let start =
            svg_path.start(subpath) |> result.unwrap(svg_path.point(0.0, 0.0))
          let end = svg_path.end(subpath) |> result.unwrap(start)

          subpath_edges(rest, accumulated: add_edge(end, start, accumulated))
        }
      }
    }
  }
}

fn add_edge(
  start: svg_path.Point,
  end: svg_path.Point,
  edges: List(Edge),
) -> List(Edge) {
  case start == end {
    True -> edges
    False -> [Edge(start:, end:), ..edges]
  }
}

fn arrangement_xs(edges: List(Edge), tolerance: Float) -> List(Float) {
  let endpoint_xs =
    list.flat_map(edges, fn(edge) { [edge.start.x, edge.end.x] })
  let intersection_xs = pair_intersection_xs(edges, tolerance, accumulated: [])

  list.append(endpoint_xs, intersection_xs)
  |> list.sort(by: float.compare)
  |> dedupe_sorted_floats(tolerance, accumulated: [])
}

fn pair_intersection_xs(
  edges: List(Edge),
  tolerance: Float,
  accumulated accumulated: List(Float),
) -> List(Float) {
  case edges {
    [] -> accumulated
    [first, ..rest] -> {
      let accumulated =
        list.fold(rest, accumulated, fn(xs, second) {
          case edge_intersection_x(first, second, tolerance) {
            None -> xs
            Some(x) -> [x, ..xs]
          }
        })
      pair_intersection_xs(rest, tolerance, accumulated:)
    }
  }
}

fn edge_intersection_x(
  left: Edge,
  right: Edge,
  tolerance: Float,
) -> Option(Float) {
  let left_direction = difference(left.end, left.start)
  let right_direction = difference(right.end, right.start)
  let denominator = cross(left_direction, right_direction)
  let denominator_tolerance =
    arrangement_relative_tolerance
    *. float.max(1.0, length(left_direction) *. length(right_direction))
  case float.absolute_value(denominator) <=. denominator_tolerance {
    True -> None
    False -> {
      let offset = difference(right.start, left.start)
      let left_t = cross(offset, right_direction) /. denominator
      let right_t = cross(offset, left_direction) /. denominator
      case
        left_t >=. 0.0 -. tolerance
        && left_t <=. 1.0 +. tolerance
        && right_t >=. 0.0 -. tolerance
        && right_t <=. 1.0 +. tolerance
      {
        True -> Some(left.start.x +. left_direction.x *. clamp01(left_t))
        False -> None
      }
    }
  }
}

fn dedupe_sorted_floats(
  values: List(Float),
  tolerance: Float,
  accumulated accumulated: List(Float),
) -> List(Float) {
  case values, accumulated {
    [], _ -> list.reverse(accumulated)
    [first, ..rest], [] ->
      dedupe_sorted_floats(rest, tolerance, accumulated: [first])
    [first, ..rest], [previous, ..] -> {
      case float.absolute_value(first -. previous) <=. tolerance {
        True -> dedupe_sorted_floats(rest, tolerance, accumulated:)
        False ->
          dedupe_sorted_floats(rest, tolerance, accumulated: [
            first,
            ..accumulated
          ])
      }
    }
  }
}

fn slabs_area(
  xs: List(Float),
  edges: List(Edge),
  fill_rule: svg_path.FillRule,
  tolerance: Float,
  area area: Float,
) -> Float {
  case xs {
    [] | [_] -> area
    [left, right, ..rest] -> {
      let width = right -. left
      let slab_area = case width <=. 0.0 {
        True -> 0.0
        False -> {
          let middle = { left +. right } /. 2.0
          let groups = crossing_groups(edges, middle, tolerance)
          crossing_groups_area(
            groups,
            left,
            right,
            fill_rule,
            winding: 0,
            crossings: 0,
            previous: None,
            area: 0.0,
          )
        }
      }

      slabs_area(
        [right, ..rest],
        edges,
        fill_rule,
        tolerance,
        area: area +. slab_area,
      )
    }
  }
}

fn crossing_groups(
  edges: List(Edge),
  x: Float,
  tolerance: Float,
) -> List(CrossingGroup) {
  edges
  |> list.filter_map(fn(edge) {
    let min_x = float.min(edge.start.x, edge.end.x)
    let max_x = float.max(edge.start.x, edge.end.x)
    case x >. min_x && x <. max_x {
      False -> Error(Nil)
      True ->
        Ok(
          Crossing(
            edge:,
            y: edge_y_at(edge, x),
            winding: case edge.end.x >. edge.start.x {
              True -> 1
              False -> -1
            },
          ),
        )
    }
  })
  |> list.sort(by: fn(a, b) { float.compare(a.y, b.y) })
  |> group_crossings(tolerance, accumulated: [])
}

fn group_crossings(
  crossings: List(Crossing),
  tolerance: Float,
  accumulated accumulated: List(CrossingGroup),
) -> List(CrossingGroup) {
  case crossings, accumulated {
    [], _ -> list.reverse(accumulated)
    [first, ..rest], [] ->
      group_crossings(rest, tolerance, accumulated: [
        CrossingGroup(
          edge: first.edge,
          y: first.y,
          winding: first.winding,
          crossings: 1,
        ),
      ])
    [first, ..rest], [previous, ..previous_groups] -> {
      case float.absolute_value(first.y -. previous.y) <=. tolerance {
        True ->
          group_crossings(rest, tolerance, accumulated: [
            CrossingGroup(
              ..previous,
              winding: previous.winding + first.winding,
              crossings: previous.crossings + 1,
            ),
            ..previous_groups
          ])
        False ->
          group_crossings(rest, tolerance, accumulated: [
            CrossingGroup(
              edge: first.edge,
              y: first.y,
              winding: first.winding,
              crossings: 1,
            ),
            ..accumulated
          ])
      }
    }
  }
}

fn crossing_groups_area(
  groups: List(CrossingGroup),
  left: Float,
  right: Float,
  fill_rule: svg_path.FillRule,
  winding winding: Int,
  crossings crossings: Int,
  previous previous: Option(CrossingGroup),
  area area: Float,
) -> Float {
  case groups {
    [] -> area
    [current, ..rest] -> {
      let area = case previous, is_filled(winding, crossings, fill_rule) {
        Some(previous), True ->
          area +. interval_area(previous.edge, current.edge, left, right)
        _, _ -> area
      }

      crossing_groups_area(
        rest,
        left,
        right,
        fill_rule,
        winding: winding + current.winding,
        crossings: crossings + current.crossings,
        previous: Some(current),
        area:,
      )
    }
  }
}

fn is_filled(
  winding: Int,
  crossings: Int,
  fill_rule: svg_path.FillRule,
) -> Bool {
  case fill_rule {
    svg_path.Nonzero -> winding != 0
    svg_path.EvenOdd -> {
      let assert Ok(remainder) = int.remainder(crossings, by: 2)
      remainder == 1
    }
  }
}

fn interval_area(lower: Edge, upper: Edge, left: Float, right: Float) -> Float {
  let left_height =
    float.max(0.0, edge_y_at(upper, left) -. edge_y_at(lower, left))
  let right_height =
    float.max(0.0, edge_y_at(upper, right) -. edge_y_at(lower, right))

  { right -. left } *. { left_height +. right_height } /. 2.0
}

fn edge_y_at(edge: Edge, x: Float) -> Float {
  let dx = edge.end.x -. edge.start.x
  case dx == 0.0 {
    True -> edge.start.y
    False ->
      edge.start.y
      +. { edge.end.y -. edge.start.y }
      *. { x -. edge.start.x }
      /. dx
  }
}

fn arrangement_tolerance(edges: List(Edge)) -> Float {
  edges
  |> list.fold(1.0, fn(scale, edge) {
    scale
    |> float.max(float.absolute_value(edge.start.x))
    |> float.max(float.absolute_value(edge.start.y))
    |> float.max(float.absolute_value(edge.end.x))
    |> float.max(float.absolute_value(edge.end.y))
  })
  |> fn(scale) { scale *. arrangement_relative_tolerance }
}

fn combine2(
  a: svg_path.Point,
  a_scale: Float,
  b: svg_path.Point,
  b_scale: Float,
) -> svg_path.Point {
  svg_path.point(
    a.x *. a_scale +. b.x *. b_scale,
    a.y *. a_scale +. b.y *. b_scale,
  )
}

fn combine3(
  a: svg_path.Point,
  a_scale: Float,
  b: svg_path.Point,
  b_scale: Float,
  c: svg_path.Point,
  c_scale: Float,
) -> svg_path.Point {
  svg_path.point(
    a.x *. a_scale +. b.x *. b_scale +. c.x *. c_scale,
    a.y *. a_scale +. b.y *. b_scale +. c.y *. c_scale,
  )
}

fn combine4(
  a: svg_path.Point,
  a_scale: Float,
  b: svg_path.Point,
  b_scale: Float,
  c: svg_path.Point,
  c_scale: Float,
  d: svg_path.Point,
  d_scale: Float,
) -> svg_path.Point {
  svg_path.point(
    a.x *. a_scale +. b.x *. b_scale +. c.x *. c_scale +. d.x *. d_scale,
    a.y *. a_scale +. b.y *. b_scale +. c.y *. c_scale +. d.y *. d_scale,
  )
}

fn difference(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.point(a.x -. b.x, a.y -. b.y)
}

fn cross(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.y -. a.y *. b.x
}

fn length(vector: svg_path.Point) -> Float {
  let assert Ok(root) =
    vector.x *. vector.x +. vector.y *. vector.y |> float.square_root
  root
}

fn clamp01(value: Float) -> Float {
  value |> float.max(0.0) |> float.min(1.0)
}
