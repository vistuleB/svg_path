import gleam/float
import gleam/int
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam_community/maths
import gleeunit
import svg_path
import svg_path/convex_hull

const tolerance = 0.000001

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn point_cloud_hull_handles_10_point_cloud_test() {
  assert point_cloud_hull_matches_support(10)
}

pub fn point_cloud_hull_rejects_empty_point_cloud_test() {
  assert convex_hull.point_cloud_hull([])
    == Error(convex_hull.PathError(svg_path.EmptyPath))
}

pub fn point_cloud_hull_handles_points_test() {
  assert public_point_cloud_hull_matches_support([
    svg_path.point(-2.0, 1.0),
    svg_path.point(5.0, 1.0),
    svg_path.point(0.0, 4.0),
    svg_path.point(1.0, 2.0),
  ])
}

pub fn point_cloud_hull_handles_single_point_cloud_test() {
  assert point_cloud_matches_support([svg_path.point(4.0, -3.0)])
}

pub fn point_cloud_hull_handles_duplicate_single_point_cloud_test() {
  let point = svg_path.point(4.0, -3.0)
  assert point_cloud_matches_support([point, point, point])
}

pub fn point_cloud_hull_handles_two_point_cloud_test() {
  assert point_cloud_matches_support([
    svg_path.point(-2.0, 1.0),
    svg_path.point(5.0, 1.0),
  ])
}

pub fn point_cloud_hull_handles_duplicate_two_point_cloud_test() {
  let a = svg_path.point(-2.0, 1.0)
  let b = svg_path.point(5.0, 1.0)
  assert point_cloud_matches_support([a, b, a, b, a])
}

pub fn point_cloud_hull_handles_horizontal_collinear_point_cloud_test() {
  assert point_cloud_matches_support([
    svg_path.point(-2.0, 1.0),
    svg_path.point(0.0, 1.0),
    svg_path.point(3.0, 1.0),
    svg_path.point(5.0, 1.0),
  ])
}

pub fn point_cloud_hull_handles_vertical_collinear_point_cloud_test() {
  assert point_cloud_matches_support([
    svg_path.point(2.0, -3.0),
    svg_path.point(2.0, -1.0),
    svg_path.point(2.0, 4.0),
    svg_path.point(2.0, 8.0),
  ])
}

pub fn point_cloud_hull_handles_positive_diagonal_collinear_point_cloud_test() {
  assert point_cloud_matches_support([
    svg_path.point(-2.0, -1.0),
    svg_path.point(0.0, 1.0),
    svg_path.point(3.0, 4.0),
    svg_path.point(5.0, 6.0),
  ])
}

pub fn point_cloud_hull_handles_negative_diagonal_collinear_point_cloud_test() {
  assert point_cloud_matches_support([
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
  assert point_cloud_matches_support([b, a, c, b, d, a, c])
}

pub fn point_cloud_hull_handles_100_point_cloud_test() {
  assert point_cloud_hull_matches_support(100)
}

pub fn point_cloud_hull_handles_1000_point_cloud_test() {
  assert point_cloud_hull_matches_support(1000)
}

pub fn point_cloud_hull_handles_1000_unit_circle_point_cloud_test() {
  assert unit_circle_point_cloud_hull_matches_support(1000)
}

pub fn point_cloud_hull_handles_one_sided_1_degree_crescent_point_cloud_test() {
  assert point_cloud_matches_support(one_sided_1_degree_crescent_points(100))
}

pub fn point_cloud_hull_handles_two_sided_1_degree_crescent_point_cloud_test() {
  assert point_cloud_matches_support(two_sided_1_degree_crescent_points(100))
}

pub fn path_hull_handles_one_sided_1_degree_crescent_points_and_chord_test() {
  assert crescent_path_matches_support(
    one_sided_1_degree_crescent_points(100),
    start_angle: 0.0,
    end_angle: 1.0,
  )
}

pub fn path_hull_handles_two_sided_1_degree_crescent_points_and_chord_test() {
  assert crescent_path_matches_support(
    two_sided_1_degree_crescent_points(100),
    start_angle: -0.5,
    end_angle: 0.5,
  )
}

fn point_cloud_hull_matches_support(count: Int) -> Bool {
  let points = random_points(count)
  point_cloud_matches_support(points)
}

fn unit_circle_point_cloud_hull_matches_support(count: Int) -> Bool {
  let points = unit_circle_points(count)
  point_cloud_matches_support(points)
}

fn public_point_cloud_hull_matches_support(points: List(svg_path.Point)) -> Bool {
  case convex_hull.point_cloud_hull(points) {
    Error(_) -> False
    Ok(hull) -> point_cloud_hull_matches(points, hull)
  }
}

fn point_cloud_matches_support(points: List(svg_path.Point)) -> Bool {
  public_point_cloud_hull_matches_support(points)
  && ["dumb", "ambitious"]
  |> list.all(fn(repair_mode) {
    path_point_cloud_matches_support_with_repair_mode(points, repair_mode:)
  })
}

fn path_point_cloud_matches_support_with_repair_mode(
  points: List(svg_path.Point),
  repair_mode repair_mode: String,
) -> Bool {
  let path =
    points
    |> list.map(fn(point) { svg_path.empty_subpath(at: point) })
    |> svg_path.Path

  case convex_hull.test_path_hull_with_repair_mode(path, repair_mode:) {
    Error(_) -> False
    Ok(hull) -> point_cloud_hull_matches(points, hull)
  }
}

fn crescent_path_matches_support(
  points: List(svg_path.Point),
  start_angle start_angle: Float,
  end_angle end_angle: Float,
) -> Bool {
  let start = radius_1000_point(start_angle)
  let end = radius_1000_point(end_angle)
  let support_points = [start, end, ..points]

  ["dumb", "ambitious"]
  |> list.all(fn(repair_mode) {
    case
      convex_hull.test_path_hull_with_repair_mode(
        crescent_path(points, line_start: start, line_end: end),
        repair_mode:,
      )
    {
      Error(_) -> False
      Ok(hull) -> point_cloud_hull_matches(support_points, hull)
    }
  })
}

fn crescent_path(
  points: List(svg_path.Point),
  line_start line_start: svg_path.Point,
  line_end line_end: svg_path.Point,
) -> svg_path.Path {
  let line =
    svg_path.assert_subpath([
      svg_path.Line(start: line_start, end: line_end),
    ])
  let point_subpaths =
    points
    |> list.map(fn(point) { svg_path.empty_subpath(at: point) })

  svg_path.Path([line, ..point_subpaths])
}

fn point_cloud_hull_matches(
  points: List(svg_path.Point),
  hull: svg_path.Subpath,
) -> Bool {
  svg_path.is_closed(hull)
  && original_points_are_inside_hull(points, hull)
  && support_angles()
  |> list.all(fn(angle) {
    case
      point_cloud_support_value(points, angle),
      hull_support_value(svg_path.segments(hull), angle)
    {
      Ok(original), Ok(hull) ->
        float.absolute_value(original -. hull) <=. tolerance
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
    convex_hull.test_point_chord_polygon_loop_separation(
      svg_path.segments(hull),
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
  int.range(from: 0, to: count, with: [], run: fn(points, index) {
    [one_degree_crescent_point(index, 0.0, 1.0), ..points]
  })
  |> list.reverse
}

fn two_sided_1_degree_crescent_points(count: Int) -> List(svg_path.Point) {
  int.range(from: 0, to: count, with: [], run: fn(points, index) {
    [one_degree_crescent_point(index, -0.5, 1.0), ..points]
  })
  |> list.reverse
}

fn one_degree_crescent_point(
  index: Int,
  angle_start: Float,
  angle_span: Float,
) -> svg_path.Point {
  let angle =
    angle_start
    +. angle_span
    *. int.to_float({ index * 89 + 37 } % 10_000)
    /. 10_000.0
  let radians = angle *. maths.pi() /. 180.0
  let radius =
    1000.0
    +. int.to_float({ { index * 61 + 43 } * { index * 31 + 29 } + 17 } % 3000)
    /. 1000.0

  svg_path.point(radius *. maths.cos(radians), radius *. maths.sin(radians))
}

fn radius_1000_point(angle: Float) -> svg_path.Point {
  let radians = angle *. maths.pi() /. 180.0
  svg_path.point(1000.0 *. maths.cos(radians), 1000.0 *. maths.sin(radians))
}

fn support_angles() -> List(Float) {
  int.range(from: 0, to: 36, with: [], run: fn(angles, index) {
    [int.to_float(index) *. 10.0, ..angles]
  })
  |> list.reverse
}

fn point_cloud_support_value(
  points: List(svg_path.Point),
  angle: Float,
) -> Result(Float, Nil) {
  let direction = angle_direction(angle)
  case points {
    [] -> Error(Nil)
    [first, ..rest] ->
      rest
      |> list.fold(dot(first, direction), fn(best, point) {
        float.max(best, dot(point, direction))
      })
      |> Ok
  }
}

fn hull_support_value(
  segments: List(svg_path.Segment),
  angle: Float,
) -> Result(Float, svg_path.Error) {
  case segments {
    [] -> Error(svg_path.EmptySubpath)
    [first, ..rest] -> {
      use first <- result.try(convex_hull.test_segment_support(first, angle:))
      let #(_, _, first_value) = first
      rest
      |> list.fold(Ok(first_value), fn(best, segment) {
        use best <- result.try(best)
        use sample <- result.try(convex_hull.test_segment_support(
          segment,
          angle:,
        ))
        let #(_, _, value) = sample
        Ok(float.max(best, value))
      })
    }
  }
}

fn angle_direction(angle: Float) -> svg_path.Point {
  let radians = angle *. maths.pi() /. 180.0
  svg_path.point(maths.cos(radians), maths.sin(radians))
}

fn dot(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.x +. a.y *. b.y
}
