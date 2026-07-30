import gleeunit
import svg_path
import svg_path/point

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn basis_vectors_and_direction_test() {
  assert point.right == svg_path.Point(1.0, 0.0)
  assert point.left == svg_path.Point(-1.0, 0.0)
  assert point.up == svg_path.Point(0.0, -1.0)
  assert point.down == svg_path.Point(0.0, 1.0)
  assert point.direction(degrees: 0.0) == point.right
  assert point.direction(degrees: 90.0) == point.down
  assert point.direction(degrees: 180.0) == point.left
  assert point.direction(degrees: 270.0) == point.up
}

pub fn vector_arithmetic_test() {
  let a = svg_path.Point(3.0, 4.0)
  let b = svg_path.Point(1.0, -2.0)

  assert point.add(a, b) == svg_path.Point(4.0, 2.0)
  assert point.subtract(a, b) == svg_path.Point(2.0, 6.0)
  assert point.negate(b) == svg_path.Point(-1.0, 2.0)
  assert point.scale(a, by: 2.0) == svg_path.Point(6.0, 8.0)
}

pub fn dot_cross_norm_and_distance_test() {
  let a = svg_path.Point(3.0, 4.0)
  let b = svg_path.Point(6.0, 8.0)

  assert point.dot(a, b) == 50.0
  assert point.cross(a, b) == 0.0
  assert point.norm_squared(a) == 25.0
  assert point.norm(a) == 5.0
  assert point.distance_squared(a, b) == 25.0
  assert point.distance(a, b) == 5.0
}

pub fn midpoint_and_lerp_test() {
  let a = svg_path.Point(0.0, 10.0)
  let b = svg_path.Point(10.0, 30.0)

  assert point.midpoint(a, b) == svg_path.Point(5.0, 20.0)
  assert point.lerp(a, b, t: 0.25) == svg_path.Point(2.5, 15.0)
  assert point.lerp(a, b, t: 2.0) == svg_path.Point(20.0, 50.0)
}

pub fn normalize_test() {
  let assert Ok(unit) = point.normalize(svg_path.Point(3.0, 4.0))
  assert point.near(unit, svg_path.Point(0.6, 0.8), tolerance: 0.000000001)
  assert point.normalize(svg_path.Point(0.0, 0.0)) == Error(Nil)
}

pub fn projection_test() {
  let a = svg_path.Point(3.0, 4.0)
  let b = svg_path.Point(2.0, 0.0)

  assert point.project(a, onto: b) == Ok(svg_path.Point(3.0, 0.0))
  assert point.scalar_projection(a, onto: b) == Ok(3.0)
  assert point.project(a, onto: svg_path.Point(0.0, 0.0)) == Error(Nil)
  assert point.scalar_projection(a, onto: svg_path.Point(0.0, 0.0))
    == Error(Nil)
}

pub fn rotations_and_near_test() {
  let a = svg_path.Point(2.0, 3.0)

  assert point.rotate_clockwise(a) == svg_path.Point(3.0, -2.0)
  assert point.rotate_counterclockwise(a) == svg_path.Point(-3.0, 2.0)
  assert point.near(
    svg_path.Point(0.0, 0.0),
    svg_path.Point(3.0, 4.0),
    tolerance: 5.0,
  )
  assert !point.near(
    svg_path.Point(0.0, 0.0),
    svg_path.Point(3.0, 4.0),
    tolerance: 4.999,
  )
}
