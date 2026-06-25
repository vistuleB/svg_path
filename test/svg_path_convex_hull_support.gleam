import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam_community/maths
import svg_path
import svg_path/convex_hull

pub fn octant_angles() -> List(Float) {
  [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
}

pub fn ten_degree_angles() -> List(Float) {
  int.range(from: 0, to: 36, with: [], run: fn(angles, index) {
    [int.to_float(index) *. 10.0, ..angles]
  })
  |> list.reverse
}

pub fn point_cloud_support_value(
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

pub fn segments_support_value(
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

pub fn values_near(a: Float, b: Float, tolerance tolerance: Float) -> Bool {
  float.absolute_value(a -. b) <=. tolerance
}

fn angle_direction(angle: Float) -> svg_path.Point {
  let radians = angle *. maths.pi() /. 180.0
  svg_path.point(maths.cos(radians), maths.sin(radians))
}

fn dot(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.x +. a.y *. b.y
}
