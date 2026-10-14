import gleam/float
import gleam/list
import svg_path.{CubicBezier, Point, QuadraticBezier}
import svg_path/measure

fn fixtures() {
  let quadratic =
    QuadraticBezier(Point(0.0, 0.0), Point(3.0, 1.0), Point(1.0, 1.0 /. 3.0))
  let cubic =
    CubicBezier(
      Point(0.0, 0.0),
      Point(3.0, 0.0),
      Point(-1.0, 0.0),
      Point(2.0, 0.0),
    )
  let assert Ok(q_middle) =
    svg_path.segment_between(quadratic, from: 0.25, to: 0.75)
  let assert Ok(c_middle) =
    svg_path.segment_between(cubic, from: 0.25, to: 0.75)
  // Independent total-variation formulas at the scalar derivative roots.
  [
    #(quadratic, 2.7406406388125954),
    #(q_middle, 0.7642171012073583),
    #(cubic, 2.7559289460184545),
    #(c_middle, 0.44342894601845445),
  ]
}

pub fn folded_lengths_succeed_with_default_options_test() {
  list.each(fixtures(), fn(fixture) {
    let assert Ok(length) = measure.segment_length(fixture.0)
    assert float.absolute_value(length -. fixture.1) <. 0.000000001
    let assert Ok(reversed) =
      measure.segment_length(svg_path.segment_reverse(fixture.0))
    assert float.absolute_value(reversed -. fixture.1) <. 0.000000001
  })
}

pub fn folded_lengths_partition_before_depth_is_spent_test() {
  list.each(fixtures(), fn(fixture) {
    let assert Ok(length) =
      measure.segment_length_with(
        fixture.0,
        options: svg_path.LengthOptions(tolerance: 0.000000001, max_depth: 1),
      )
    assert float.absolute_value(length -. fixture.1) <. 0.000000001
  })
}

pub fn folded_lengths_preserve_scale_translation_and_axis_test() {
  list.each(fixtures(), fn(fixture) {
    list.each([0.001, 1.0, 1000.0], fn(scale) {
      list.each([False, True], fn(swap) {
        let assert Ok(moved) =
          svg_path.segment_map_points(fixture.0, with: fn(p) {
            case swap {
              True -> Point(17.0 +. scale *. p.y, -23.0 +. scale *. p.x)
              False -> Point(17.0 +. scale *. p.x, -23.0 +. scale *. p.y)
            }
          })
        let assert Ok(length) = measure.segment_length(moved)
        assert float.absolute_value(length -. scale *. fixture.1) <. 0.000000001
      })
    })
  })
}

pub fn folded_length_inversion_preserves_traveled_distance_test() {
  // x=6t-5t² turns at .6. At t=.8 the traveled distance is
  // x(.6) + [x(.6)-x(.8)] = 2, on the return traversal.
  let curve = QuadraticBezier(Point(0.0, 0.0), Point(3.0, 0.0), Point(1.0, 0.0))
  let assert Ok(t) = measure.segment_parameter_at_length(curve, distance: 2.0)
  assert float.absolute_value(t -. 0.8) <. 0.000000001
  let assert Ok(p) = measure.segment_point_at_length(curve, distance: 2.0)
  assert float.absolute_value(p.x -. 1.6) <. 0.000000001
  assert p.y == 0.0
}

pub fn zero_length_and_near_collinear_lengths_test() {
  let p = Point(17.0, -23.0)
  assert measure.segment_length(CubicBezier(p, p, p, p)) == Ok(0.0)
  let curve =
    CubicBezier(
      Point(0.0, 0.0),
      Point(3.0, 0.00000001),
      Point(-1.0, -0.00000001),
      Point(2.0, 0.0),
    )
  let assert Ok(length) = measure.segment_length(curve)
  assert float.absolute_value(length -. 2.7559289460184545) <. 0.0000001
}
