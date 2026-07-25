//// These tests use two checks for most point-cloud hulls:
//// every original point must be inside/on the hull, and sampled support values
//// must match. Most cases also run through the public point-cloud API plus the
//// explicit dumb and ambitious final repair modes.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{None}
import gleam_community/maths
import gleeunit
import svg_path
import svg_path/convex_hull
import svg_path_convex_hull_support as support

const tolerance = 0.000001

const repair_modes_to_check = ["dumb", "ambitious"]

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn point_cloud_hull_handles_10_point_cloud_test() {
  assert point_cloud_hull_is_valid_for_count(10)
}

pub fn point_cloud_hull_rejects_empty_point_cloud_test() {
  assert convex_hull.points_hull([])
    == Error(convex_hull.PathError(svg_path.EmptyPath))
}

pub fn point_cloud_hull_handles_points_test() {
  assert public_point_cloud_hull_is_valid([
    svg_path.point(-2.0, 1.0),
    svg_path.point(5.0, 1.0),
    svg_path.point(0.0, 4.0),
    svg_path.point(1.0, 2.0),
  ])
}

pub fn point_cloud_hull_handles_single_point_cloud_test() {
  assert point_cloud_is_valid_in_all_modes([svg_path.point(4.0, -3.0)])
}

pub fn point_cloud_hull_handles_duplicate_single_point_cloud_test() {
  let point = svg_path.point(4.0, -3.0)
  assert point_cloud_is_valid_in_all_modes([point, point, point])
}

pub fn point_cloud_hull_handles_two_point_cloud_test() {
  assert point_cloud_is_valid_in_all_modes([
    svg_path.point(-2.0, 1.0),
    svg_path.point(5.0, 1.0),
  ])
}

pub fn point_cloud_hull_handles_duplicate_two_point_cloud_test() {
  let a = svg_path.point(-2.0, 1.0)
  let b = svg_path.point(5.0, 1.0)
  assert point_cloud_is_valid_in_all_modes([a, b, a, b, a])
}

pub fn point_cloud_hull_handles_horizontal_collinear_point_cloud_test() {
  assert point_cloud_is_valid_in_all_modes([
    svg_path.point(-2.0, 1.0),
    svg_path.point(0.0, 1.0),
    svg_path.point(3.0, 1.0),
    svg_path.point(5.0, 1.0),
  ])
}

pub fn point_cloud_hull_handles_vertical_collinear_point_cloud_test() {
  assert point_cloud_is_valid_in_all_modes([
    svg_path.point(2.0, -3.0),
    svg_path.point(2.0, -1.0),
    svg_path.point(2.0, 4.0),
    svg_path.point(2.0, 8.0),
  ])
}

pub fn point_cloud_hull_handles_positive_diagonal_collinear_point_cloud_test() {
  assert point_cloud_is_valid_in_all_modes([
    svg_path.point(-2.0, -1.0),
    svg_path.point(0.0, 1.0),
    svg_path.point(3.0, 4.0),
    svg_path.point(5.0, 6.0),
  ])
}

pub fn point_cloud_hull_handles_negative_diagonal_collinear_point_cloud_test() {
  assert point_cloud_is_valid_in_all_modes([
    svg_path.point(-2.0, 6.0),
    svg_path.point(0.0, 4.0),
    svg_path.point(3.0, 1.0),
    svg_path.point(5.0, -1.0),
  ])
}

pub fn point_cloud_hull_handles_duplicate_collinear_point_cloud_test() {
  let a = svg_path.point(-2.0, -1.0)
  let b = svg_path.point(0.0, 1.0)
  let c = svg_path.point(3.0, 4.0)
  let d = svg_path.point(5.0, 6.0)
  assert point_cloud_is_valid_in_all_modes([b, a, c, b, d, a, c])
}

pub fn point_cloud_hull_handles_100_point_cloud_test() {
  assert point_cloud_hull_is_valid_for_count(100)
}

pub fn point_cloud_hull_handles_1000_point_cloud_test() {
  assert point_cloud_hull_is_valid_for_count(1000)
}

pub fn point_cloud_hull_handles_1000_unit_circle_point_cloud_test() {
  assert unit_circle_point_cloud_hull_is_valid(1000)
}

pub fn point_cloud_hull_handles_one_sided_1_degree_crescent_point_cloud_test() {
  assert point_cloud_is_valid_in_all_modes(one_sided_1_degree_crescent_points(
    100,
  ))
}

pub fn point_cloud_hull_handles_two_sided_1_degree_crescent_point_cloud_test() {
  assert point_cloud_is_valid_in_all_modes(two_sided_1_degree_crescent_points(
    100,
  ))
}

pub fn path_hull_handles_one_sided_1_degree_crescent_points_and_chord_test() {
  assert crescent_path_is_valid_in_all_modes(
    one_sided_1_degree_crescent_points(100),
    start_angle: 0.0,
    end_angle: 1.0,
  )
}

pub fn path_hull_handles_two_sided_1_degree_crescent_points_and_chord_test() {
  assert crescent_path_is_valid_in_all_modes(
    two_sided_1_degree_crescent_points(100),
    start_angle: -0.5,
    end_angle: 0.5,
  )
}

fn point_cloud_hull_is_valid_for_count(count: Int) -> Bool {
  let points = random_points(count)
  point_cloud_is_valid_in_all_modes(points)
}

fn unit_circle_point_cloud_hull_is_valid(count: Int) -> Bool {
  let points = unit_circle_points(count)
  point_cloud_is_valid_in_all_modes(points)
}

fn public_point_cloud_hull_is_valid(points: List(svg_path.Point)) -> Bool {
  case convex_hull.points_hull(points) {
    Error(_) -> False
    Ok(hull) -> point_cloud_hull_is_valid(points, hull)
  }
}

fn point_cloud_is_valid_in_all_modes(points: List(svg_path.Point)) -> Bool {
  public_point_cloud_hull_is_valid(points)
  && repair_modes_to_check
  |> list.all(fn(repair_mode) {
    path_point_cloud_is_valid_with_repair_mode(points, repair_mode:)
  })
}

fn path_point_cloud_is_valid_with_repair_mode(
  points: List(svg_path.Point),
  repair_mode repair_mode: String,
) -> Bool {
  let path =
    points
    |> list.map(fn(point) { svg_path.subpath_empty(at: point) })
    |> svg_path.Path

  case convex_hull.internal_path_hull_with_repair_mode(path, repair_mode:) {
    Error(_) -> False
    Ok(hull) -> point_cloud_hull_is_valid(points, hull)
  }
}

fn crescent_path_is_valid_in_all_modes(
  points: List(svg_path.Point),
  start_angle start_angle: Float,
  end_angle end_angle: Float,
) -> Bool {
  let start = radius_1000_point(start_angle)
  let end = radius_1000_point(end_angle)
  let support_points = [start, end, ..points]

  repair_modes_to_check
  |> list.all(fn(repair_mode) {
    case
      convex_hull.internal_path_hull_with_repair_mode(
        crescent_path(points, line_start: start, line_end: end),
        repair_mode:,
      )
    {
      Error(_) -> False
      Ok(hull) -> point_cloud_hull_is_valid(support_points, hull)
    }
  })
}

fn crescent_path(
  points: List(svg_path.Point),
  line_start line_start: svg_path.Point,
  line_end line_end: svg_path.Point,
) -> svg_path.Path {
  let line =
    svg_path.subpath_assert([
      svg_path.Line(start: line_start, end: line_end),
    ])
  let point_subpaths =
    points
    |> list.map(fn(point) { svg_path.subpath_empty(at: point) })

  svg_path.Path([line, ..point_subpaths])
}

fn point_cloud_hull_is_valid(
  points: List(svg_path.Point),
  hull: svg_path.Subpath,
) -> Bool {
  svg_path.subpath_is_closed(hull)
  && original_points_are_inside_hull(points, hull)
  && support.ten_degree_angles()
  |> list.all(fn(angle) {
    case
      support.point_cloud_support_value(points, angle),
      support.segments_support_value(svg_path.subpath_segments(hull), angle)
    {
      Ok(original), Ok(hull) -> support.values_near(original, hull, tolerance:)
      _, _ -> False
    }
  })
}

fn original_points_are_inside_hull(
  points: List(svg_path.Point),
  hull: svg_path.Subpath,
) -> Bool {
  points
  |> list.all(fn(point) {
    convex_hull.internal_point_chord_polygon_loop_separation(
      svg_path.subpath_segments(hull),
      point:,
    )
    == None
  })
}

fn random_points(count: Int) -> List(svg_path.Point) {
  int.range(from: 0, to: count, with: [], run: fn(points, index) {
    [random_point(index), ..points]
  })
  |> list.reverse
}

fn random_point(index: Int) -> svg_path.Point {
  svg_path.point(
    int.to_float({ { index * 73 + 19 } * { index * 17 + 23 } + 11 } % 10_001)
      /. 100.0,
    int.to_float({ { index * 41 + 29 } * { index * 97 + 31 } + 7 } % 10_001)
      /. 100.0,
  )
}

fn unit_circle_points(count: Int) -> List(svg_path.Point) {
  int.range(from: 0, to: count, with: [], run: fn(points, index) {
    [unit_circle_point(index), ..points]
  })
  |> list.reverse
}

fn unit_circle_point(index: Int) -> svg_path.Point {
  let angle =
    int.to_float({ index * 97 + 13 } % 10_000) /. 10_000.0 *. maths.pi() *. 2.0
  let radius =
    int.to_float({ { index * 37 + 17 } * { index * 53 + 29 } + 5 } % 10_000)
    /. 10_000.0
  let assert Ok(radius) = float.square_root(radius)

  svg_path.point(radius *. maths.cos(angle), radius *. maths.sin(angle))
}

fn one_sided_1_degree_crescent_points(count: Int) -> List(svg_path.Point) {
  crescent_points(count, start_angle: 0.0, end_angle: 1.0)
}

fn two_sided_1_degree_crescent_points(count: Int) -> List(svg_path.Point) {
  crescent_points(count, start_angle: -0.5, end_angle: 0.5)
}

fn crescent_points(
  count: Int,
  start_angle start_angle: Float,
  end_angle end_angle: Float,
) -> List(svg_path.Point) {
  let line_start = radius_1000_point(start_angle)
  let line_end = radius_1000_point(end_angle)

  candidate_indexes(count * 20)
  |> list.filter_map(fn(index) {
    let point = crescent_candidate_point(index, start_angle:, end_angle:)
    case point_inside_crescent(point, line_start:, line_end:) {
      True -> Ok(point)
      False -> Error(Nil)
    }
  })
  |> take_first(count)
}

fn candidate_indexes(count: Int) -> List(Int) {
  int.range(from: 0, to: count, with: [], run: fn(indexes, index) {
    [index, ..indexes]
  })
  |> list.reverse
}

fn crescent_candidate_point(
  index: Int,
  start_angle start_angle: Float,
  end_angle end_angle: Float,
) -> svg_path.Point {
  let angle_span = end_angle -. start_angle
  let angle =
    start_angle
    +. angle_span
    *. int.to_float({ index * 89 + 37 } % 10_000)
    /. 10_000.0
  let radians = angle *. maths.pi() /. 180.0
  let circle =
    svg_path.point(1000.0 *. maths.cos(radians), 1000.0 *. maths.sin(radians))
  let line_start = radius_1000_point(start_angle)
  let line_end = radius_1000_point(end_angle)
  let chord = chord_point_at_y(circle.y, line_start:, line_end:)
  let fraction =
    0.05
    +. 0.9
    *. int.to_float({ { index * 61 + 43 } * { index * 31 + 29 } + 17 } % 10_000)
    /. 10_000.0

  svg_path.point(
    chord.x +. fraction *. { circle.x -. chord.x },
    chord.y +. fraction *. { circle.y -. chord.y },
  )
}

fn chord_point_at_y(
  y: Float,
  line_start line_start: svg_path.Point,
  line_end line_end: svg_path.Point,
) -> svg_path.Point {
  let t = { y -. line_start.y } /. { line_end.y -. line_start.y }
  svg_path.point(line_start.x +. t *. { line_end.x -. line_start.x }, y)
}

fn point_inside_crescent(
  point: svg_path.Point,
  line_start line_start: svg_path.Point,
  line_end line_end: svg_path.Point,
) -> Bool {
  let radius_squared = point.x *. point.x +. point.y *. point.y
  radius_squared <=. 1000.0 *. 1000.0 +. 0.000001
  && chord_side(point, line_start:, line_end:) <=. 0.000001
}

fn chord_side(
  point: svg_path.Point,
  line_start line_start: svg_path.Point,
  line_end line_end: svg_path.Point,
) -> Float {
  { line_end.x -. line_start.x }
  *. { point.y -. line_start.y }
  -. { line_end.y -. line_start.y }
  *. { point.x -. line_start.x }
}

fn take_first(
  points: List(svg_path.Point),
  count: Int,
) -> List(svg_path.Point) {
  take_first_loop(points, count, [])
}

fn take_first_loop(
  points: List(svg_path.Point),
  count: Int,
  taken: List(svg_path.Point),
) -> List(svg_path.Point) {
  case points, count {
    _, count if count <= 0 -> list.reverse(taken)
    [], _ -> list.reverse(taken)
    [point, ..rest], _ -> take_first_loop(rest, count - 1, [point, ..taken])
  }
}

fn radius_1000_point(angle: Float) -> svg_path.Point {
  let radians = angle *. maths.pi() /. 180.0
  svg_path.point(1000.0 *. maths.cos(radians), 1000.0 *. maths.sin(radians))
}
