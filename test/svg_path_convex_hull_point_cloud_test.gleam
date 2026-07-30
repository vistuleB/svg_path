//// These tests use two checks for most point-cloud hulls:
//// every original point must be inside/on the hull, and sampled support values
//// must match. Most cases also run through the public point-cloud API plus the
//// explicit dumb and ambitious final repair modes.

import gleam/int
import gleam/list
import gleam/option.{None}
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
    svg_path.Point(-2.0, 1.0),
    svg_path.Point(5.0, 1.0),
    svg_path.Point(0.0, 4.0),
    svg_path.Point(1.0, 2.0),
  ])
}

pub fn point_cloud_hull_handles_single_point_cloud_test() {
  assert point_cloud_is_valid_in_all_modes([svg_path.Point(4.0, -3.0)])
}

pub fn point_cloud_hull_handles_duplicate_single_point_cloud_test() {
  let point = svg_path.Point(4.0, -3.0)
  assert point_cloud_is_valid_in_all_modes([point, point, point])
}

pub fn point_cloud_hull_handles_two_point_cloud_test() {
  assert point_cloud_is_valid_in_all_modes([
    svg_path.Point(-2.0, 1.0),
    svg_path.Point(5.0, 1.0),
  ])
}

pub fn point_cloud_hull_handles_duplicate_two_point_cloud_test() {
  let a = svg_path.Point(-2.0, 1.0)
  let b = svg_path.Point(5.0, 1.0)
  assert point_cloud_is_valid_in_all_modes([a, b, a, b, a])
}

pub fn point_cloud_hull_handles_horizontal_collinear_point_cloud_test() {
  assert point_cloud_is_valid_in_all_modes([
    svg_path.Point(-2.0, 1.0),
    svg_path.Point(0.0, 1.0),
    svg_path.Point(3.0, 1.0),
    svg_path.Point(5.0, 1.0),
  ])
}

pub fn point_cloud_hull_handles_vertical_collinear_point_cloud_test() {
  assert point_cloud_is_valid_in_all_modes([
    svg_path.Point(2.0, -3.0),
    svg_path.Point(2.0, -1.0),
    svg_path.Point(2.0, 4.0),
    svg_path.Point(2.0, 8.0),
  ])
}

pub fn point_cloud_hull_handles_positive_diagonal_collinear_point_cloud_test() {
  assert point_cloud_is_valid_in_all_modes([
    svg_path.Point(-2.0, -1.0),
    svg_path.Point(0.0, 1.0),
    svg_path.Point(3.0, 4.0),
    svg_path.Point(5.0, 6.0),
  ])
}

pub fn point_cloud_hull_handles_negative_diagonal_collinear_point_cloud_test() {
  assert point_cloud_is_valid_in_all_modes([
    svg_path.Point(-2.0, 6.0),
    svg_path.Point(0.0, 4.0),
    svg_path.Point(3.0, 1.0),
    svg_path.Point(5.0, -1.0),
  ])
}

pub fn point_cloud_hull_handles_duplicate_collinear_point_cloud_test() {
  let a = svg_path.Point(-2.0, -1.0)
  let b = svg_path.Point(0.0, 1.0)
  let c = svg_path.Point(3.0, 4.0)
  let d = svg_path.Point(5.0, 6.0)
  assert point_cloud_is_valid_in_all_modes([b, a, c, b, d, a, c])
}

pub fn point_cloud_hull_handles_100_point_cloud_test() {
  assert point_cloud_hull_is_valid_for_count(100)
}

fn point_cloud_hull_is_valid_for_count(count: Int) -> Bool {
  let points = random_points(count)
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
  svg_path.Point(
    int.to_float({ { index * 73 + 19 } * { index * 17 + 23 } + 11 } % 10_001)
      /. 100.0,
    int.to_float({ { index * 41 + 29 } * { index * 97 + 31 } + 7 } % 10_001)
      /. 100.0,
  )
}
