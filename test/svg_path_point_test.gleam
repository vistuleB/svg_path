import gleam/list
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
  assert point.zero == svg_path.Point(0.0, 0.0)
  assert point.direction(degrees: 0.0) == point.right
  assert point.direction(degrees: 90.0) == point.down
  assert point.direction(degrees: 180.0) == point.left
  assert point.direction(degrees: 270.0) == point.up
}

pub fn clockwise_aperture_test() {
  assert point.clockwise_aperture(from: point.right, to: point.right) == 0.0
  assert point.clockwise_aperture(from: point.right, to: point.down) == 90.0
  assert point.clockwise_aperture(from: point.down, to: point.right) == 270.0
  assert point.clockwise_aperture(from: point.right, to: point.left) == 180.0
  assert point.clockwise_aperture(from: point.up, to: point.right) == 90.0
  assert point.clockwise_aperture(
      from: svg_path.Point(0.0, 0.0),
      to: point.down,
    )
    == 90.0
}

pub fn heading_maps_rounded_full_turn_to_zero_test() {
  assert point.heading(svg_path.Point(1.0, -1.0e-16)) == 0.0
}

pub fn aperture_maps_independently_rounded_full_turn_to_zero_test() {
  let from = svg_path.Point(1.0, 1.0e-16)
  // Both headings are already in range; adding 360 to their negative
  // difference introduces the excluded endpoint independently of heading.
  assert point.heading(from) >. 0.0
  assert point.clockwise_aperture(from: from, to: point.right) == 0.0
}

pub fn near_full_turn_remains_distinct_when_representable_test() {
  let heading = point.heading(svg_path.Point(1.0, -1.0e-10))
  let aperture =
    point.clockwise_aperture(
      from: svg_path.Point(1.0, 1.0e-10),
      to: point.right,
    )
  assert heading >. 359.0 && heading <. 360.0
  assert aperture >. 359.0 && aperture <. 360.0
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

pub fn norm_and_distance_avoid_intermediate_overflow_test() {
  let large = svg_path.Point(1.0e200, 0.0)

  assert point.norm(large) == 1.0e200
  assert point.distance(svg_path.Point(0.0, 0.0), large) == 1.0e200
}

pub fn lerp_preserves_exact_end_despite_cancellation_test() {
  let a = svg_path.Point(1.0, 10_000_000_000_000_000.0)
  let b = svg_path.Point(0.1, 1.0)
  assert point.lerp(a, b, t: 1.0) == b
}

pub fn lerp_endpoints_avoid_overflowing_difference_test() {
  let a = svg_path.Point(-1.0e308, 1.0e308)
  let b = svg_path.Point(1.0e308, -1.0e308)
  assert point.lerp(a, b, t: 0.0) == a
  assert point.lerp(a, b, t: -0.0) == a
  assert point.lerp(a, b, t: 1.0) == b
}

pub fn lerp_preserves_signed_zero_endpoint_coordinates_test() {
  let a = svg_path.Point(-0.0, 0.0)
  let b = svg_path.Point(0.0, -0.0)
  assert point.lerp(a, b, t: 0.0) == a
  assert point.lerp(a, b, t: -0.0) == a
  assert point.lerp(a, b, t: 1.0) == b
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

pub fn normalize_extreme_cardinal_vectors_test() {
  list.each([1.0e-310, 1.7976931348623157e308], fn(magnitude) {
    assert point.normalize(svg_path.Point(magnitude, 0.0)) == Ok(point.right)
    assert point.normalize(svg_path.Point(0.0 -. magnitude, 0.0))
      == Ok(point.left)
    assert point.normalize(svg_path.Point(0.0, magnitude)) == Ok(point.down)
    assert point.normalize(svg_path.Point(0.0, 0.0 -. magnitude))
      == Ok(point.up)
  })
}

pub fn normalize_extreme_noncardinal_vectors_test() {
  list.each([1.0e-310, 1.7976931348623157e308], fn(magnitude) {
    list.each([1.0, -1.0], fn(sign_x) {
      list.each([1.0, -1.0], fn(sign_y) {
        let assert Ok(unit) =
          point.normalize(svg_path.Point(
            sign_x *. magnitude,
            sign_y *. magnitude,
          ))
        assert point.near(
          unit,
          svg_path.Point(
            sign_x *. 0.7071067811865475,
            sign_y *. 0.7071067811865475,
          ),
          tolerance: 1.0e-15,
        )
      })
    })
  })
  list.each(
    [svg_path.Point(3.0e-310, -4.0e-310), svg_path.Point(3.0e307, -4.0e307)],
    fn(vector) {
      let assert Ok(unit) = point.normalize(vector)
      assert point.near(unit, svg_path.Point(0.6, -0.8), tolerance: 1.0e-13)
    },
  )
}

pub fn normalize_signed_zero_vectors_test() {
  list.each([0.0, -0.0], fn(x) {
    list.each([0.0, -0.0], fn(y) {
      assert point.normalize(svg_path.Point(x, y)) == Error(Nil)
    })
  })
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

  assert point.rotate_clockwise(a) == svg_path.Point(-3.0, 2.0)
  assert point.rotate_counterclockwise(a) == svg_path.Point(3.0, -2.0)
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
  assert !point.near(a, a, tolerance: -0.001)
}
