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

pub fn path_hull_handles_10_point_cloud_test() {
  assert point_cloud_hull_matches_support(10)
}

pub fn path_hull_handles_100_point_cloud_test() {
  assert point_cloud_hull_matches_support(100)
}

pub fn path_hull_handles_1000_point_cloud_test() {
  assert point_cloud_hull_matches_support(1000)
}

pub fn path_hull_handles_1000_unit_circle_point_cloud_test() {
  assert unit_circle_point_cloud_hull_matches_support(1000)
}

fn point_cloud_hull_matches_support(count: Int) -> Bool {
  let points = random_points(count)
  point_cloud_matches_support(points)
}

fn unit_circle_point_cloud_hull_matches_support(count: Int) -> Bool {
  let points = unit_circle_points(count)
  point_cloud_matches_support(points)
}

fn point_cloud_matches_support(points: List(svg_path.Point)) -> Bool {
  let path =
    points
    |> list.map(fn(point) { svg_path.empty_subpath(at: point) })
    |> svg_path.Path

  case convex_hull.path_hull(path) {
    Error(_) -> False
    Ok(hull) -> {
      svg_path.is_closed(hull)
      && points
      |> list.all(fn(point) {
        convex_hull.test_point_chord_polygon_loop_separation(
          svg_path.segments(hull),
          point:,
        )
        == None
      })
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
  }
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
