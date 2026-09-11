import gleam/list
import gleeunit/should
import svg_path
import svg_path/internal/smallest_enclosing_circle
import svg_path/point
import svg_path/trig

const tolerance = 0.000000001

pub fn one_point_preserves_exact_center_test() {
  let sample = svg_path.Point(3.0, -7.0)

  smallest_enclosing_circle.points([sample])
  |> should.equal(
    Ok(smallest_enclosing_circle.EnclosingCircle(
      center: sample,
      radius_squared: 0.0,
    )),
  )
}

pub fn equal_points_preserve_exact_center_test() {
  let sample = svg_path.Point(3.0, -7.0)

  smallest_enclosing_circle.points([sample, sample, sample])
  |> should.equal(
    Ok(smallest_enclosing_circle.EnclosingCircle(
      center: sample,
      radius_squared: 0.0,
    )),
  )
}

pub fn two_points_use_midpoint_test() {
  let assert Ok(smallest_enclosing_circle.EnclosingCircle(
    center:,
    radius_squared:,
  )) =
    smallest_enclosing_circle.points([
      svg_path.Point(2.0, 1.0),
      svg_path.Point(6.0, 5.0),
    ])

  center |> should.equal(svg_path.Point(4.0, 3.0))
  near(radius_squared, 8.0) |> should.be_true
}

pub fn collinear_points_use_farthest_pair_test() {
  assert_circle(
    [
      svg_path.Point(0.0, 0.0),
      svg_path.Point(1.0, 0.0),
      svg_path.Point(4.0, 0.0),
      svg_path.Point(2.0, 0.0),
    ],
    svg_path.Point(2.0, 0.0),
    4.0,
  )
}

pub fn obtuse_triangle_uses_longest_side_test() {
  assert_circle(
    [
      svg_path.Point(0.0, 0.0),
      svg_path.Point(4.0, 0.0),
      svg_path.Point(1.0, 1.0),
    ],
    svg_path.Point(2.0, 0.0),
    4.0,
  )
}

pub fn acute_triangle_uses_circumcircle_test() {
  assert_circle(
    [
      svg_path.Point(0.0, 0.0),
      svg_path.Point(2.0, 0.0),
      svg_path.Point(1.0, 2.0),
    ],
    svg_path.Point(1.0, 0.75),
    1.5625,
  )
}

pub fn point_permutations_produce_same_circle_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(2.0, 0.0)
  let c = svg_path.Point(1.0, 2.0)
  let permutations = [
    [a, b, c],
    [a, c, b],
    [b, a, c],
    [b, c, a],
    [c, a, b],
    [c, b, a],
  ]
  let assert Ok(expected) = smallest_enclosing_circle.points([a, b, c])

  permutations
  |> list.all(fn(samples) {
    smallest_enclosing_circle.points(samples) == Ok(expected)
  })
  |> should.be_true
}

pub fn close_collinear_points_still_find_the_smallest_circle_test() {
  assert_circle(
    [
      svg_path.Point(0.0, 0.0),
      svg_path.Point(0.0000000000001, 0.0),
      svg_path.Point(0.0000000000002, 0.0),
    ],
    svg_path.Point(0.0000000000001, 0.0),
    0.00000000000000000000000001,
  )
}

pub fn circumcircle_is_stable_after_large_translation_test() {
  let origin = 1.0e12
  assert_circle(
    [
      svg_path.Point(origin, origin),
      svg_path.Point(origin +. 2.0, origin),
      svg_path.Point(origin +. 1.0, origin +. 2.0),
    ],
    svg_path.Point(origin +. 1.0, origin +. 0.75),
    1.5625,
  )
}

pub fn cocircular_trapezoid_preserves_previous_support_points_test() {
  // All four points lie on the same circle. A boundary-rounding rejection
  // previously replaced it with a diameter circle that forgot (-7, 8), then
  // expanded the radius around the wrong center to 171.25.
  assert_circle(
    [
      svg_path.Point(6.0, 8.0),
      svg_path.Point(0.0, -10.0),
      svg_path.Point(-1.0, -10.0),
      svg_path.Point(-7.0, 8.0),
    ],
    svg_path.Point(-0.5, 1.0 /. 6.0),
    3730.0 /. 36.0,
  )
}

pub fn cocircular_points_preserve_radius_under_rotation_and_scaling_test() {
  list.each([0.0, 7.0, 43.0, 90.0, 137.0], fn(rotation) {
    list.each([0.000000001, 1.0, 1000.0], fn(scale) {
      let samples =
        list.map([0.0, 29.0, 83.0, 145.0, 191.0, 239.0, 301.0], fn(angle) {
          svg_path.Point(
            scale *. { 3.0 +. 7.0 *. trig.cos_degrees(angle +. rotation) },
            scale *. { -2.0 +. 7.0 *. trig.sin_degrees(angle +. rotation) },
          )
        })
      let assert Ok(circle) = smallest_enclosing_circle.points(samples)
      near(circle.center.x /. scale, 3.0) |> should.be_true
      near(circle.center.y /. scale, -2.0) |> should.be_true
      near(circle.radius_squared /. { scale *. scale }, 49.0)
      |> should.be_true
      list.all(samples, fn(sample) {
        point.distance_squared(circle.center, sample) <=. circle.radius_squared
      })
      |> should.be_true
      smallest_enclosing_circle.points(list.reverse(samples))
      |> should.equal(Ok(circle))
    })
  })
}

fn assert_circle(
  samples: List(svg_path.Point),
  expected_center: svg_path.Point,
  expected_radius_squared: Float,
) {
  let assert Ok(smallest_enclosing_circle.EnclosingCircle(
    center:,
    radius_squared:,
  )) = smallest_enclosing_circle.points(samples)

  near(center.x, expected_center.x) |> should.be_true
  near(center.y, expected_center.y) |> should.be_true
  near(radius_squared, expected_radius_squared) |> should.be_true
}

fn near(first: Float, second: Float) -> Bool {
  let difference = first -. second
  difference *. difference <=. tolerance *. tolerance
}
