import gleam/list
import gleeunit/should
import svg_path
import svg_path/smallest_enclosing_circle

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
