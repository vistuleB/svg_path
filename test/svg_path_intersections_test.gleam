import gleam/float
import gleam/list
import gleeunit/should
import svg_path
import svg_path/intersections
import svg_path/point
import svg_path/transform

pub fn cubic_line_crossing_is_polished_to_geometric_tolerance_test() {
  let cubic =
    svg_path.CubicBezier(
      start: svg_path.Point(414.88052040592544, -47.067344225071885),
      control1: svg_path.Point(426.1136826390859, -57.05005309466557),
      control2: svg_path.Point(449.164205229028, -77.53651654700472),
      end: svg_path.Point(451.6059453674826, -80.02528267799268),
    )
  let line =
    svg_path.Line(
      start: svg_path.Point(451.57604163009046, -79.71204505188506),
      end: svg_path.Point(450.98094163009046, -80.60954505188505),
    )

  let assert Ok([intersection]) = intersections.segment(cubic, line)
  let assert Ok(cubic_point) =
    svg_path.segment_point(cubic, at: intersection.left_t)
  let assert Ok(line_point) =
    svg_path.segment_point(line, at: intersection.right_t)

  should.be_true(point.distance(cubic_point, line_point) <=. 1.0e-9)
}

fn arc_pair() -> #(svg_path.Segment, svg_path.Segment) {
  #(
    svg_path.Arc(
      start: svg_path.Point(82.60920101224798, 220.34092587189474),
      radius: svg_path.Point(20.01, 20.01),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(43.21295323581002, 213.39430445023285),
    ),
    svg_path.Arc(
      start: svg_path.Point(43.190371867436326, 213.5338826899446),
      radius: svg_path.Point(210.0, 210.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(454.61771360489934, 202.76027858778826),
    ),
  )
}

pub fn arc_arc_crossing_regression_test() {
  let #(left, right) = arc_pair()
  let assert Ok(found) = intersections.segment(left, right)
  list.length(found)
  |> should.equal(1)
}

pub fn production_arc_arc_crossing_regression_both_orders_test() {
  let #(left, right) = arc_pair()
  let assert Ok([forward]) = intersections.segment(left, right)
  let assert Ok([backward]) = intersections.segment(right, left)
  should.be_true(
    float.absolute_value(forward.left_t -. backward.right_t) <=. 0.0000001,
  )
  should.be_true(
    float.absolute_value(forward.right_t -. backward.left_t) <=. 0.0000001,
  )
}

pub fn cubic_cubic_crossing_regression_test() {
  let #(left_arc, right_arc) = arc_pair()
  let left_cubics = svg_path.segment_arcs_to_cubic_beziers(left_arc)
  let right_cubics = svg_path.segment_arcs_to_cubic_beziers(right_arc)
  let assert Ok(left) = list.last(left_cubics)
  let assert [right, ..] = right_cubics
  let assert Ok(found) = intersections.segment(left, right)
  list.length(found)
  |> should.equal(1)
}

pub fn symmetric_kissing_quadratics_regression_test() {
  let upper =
    svg_path.QuadraticBezier(
      start: svg_path.Point(-1.0, 1.0),
      control: svg_path.Point(0.0, -1.0),
      end: svg_path.Point(1.0, 1.0),
    )
  let lower =
    svg_path.QuadraticBezier(
      start: svg_path.Point(-1.0, -1.0),
      control: svg_path.Point(0.0, 1.0),
      end: svg_path.Point(1.0, -1.0),
    )
  let assert Ok([intersection]) = intersections.segment(upper, lower)
  should.be_true(float.absolute_value(intersection.left_t -. 0.5) <=. 0.0000001)
  should.be_true(
    float.absolute_value(intersection.right_t -. 0.5) <=. 0.0000001,
  )
}

pub fn production_symmetric_kissing_quadratics_test() {
  let upper =
    svg_path.QuadraticBezier(
      start: svg_path.Point(-1.0, 1.0),
      control: svg_path.Point(0.0, -1.0),
      end: svg_path.Point(1.0, 1.0),
    )
  let lower =
    svg_path.QuadraticBezier(
      start: svg_path.Point(-1.0, -1.0),
      control: svg_path.Point(0.0, 1.0),
      end: svg_path.Point(1.0, -1.0),
    )
  let assert Ok([intersection]) = intersections.segment(upper, lower)
  should.be_true(float.absolute_value(intersection.left_t -. 0.5) <=. 0.0000001)
  should.be_true(
    float.absolute_value(intersection.right_t -. 0.5) <=. 0.0000001,
  )
}

pub fn production_off_center_kissing_quadratics_test() {
  // left(t) = #(t, (t - 0.37)^2)
  let left =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.1369),
      control: svg_path.Point(0.5, -0.2331),
      end: svg_path.Point(1.0, 0.3969),
    )
  // right(t) = #(t - 0.26, -(t - 0.63)^2)
  let right =
    svg_path.QuadraticBezier(
      start: svg_path.Point(-0.26, -0.3969),
      control: svg_path.Point(0.24, 0.2331),
      end: svg_path.Point(0.74, -0.1369),
    )
  let assert Ok([intersection]) = intersections.segment(left, right)
  // At a quadratic contact, a 1e-9 geometric tolerance implies parameter
  // uncertainty on the order of sqrt(1e-9).
  should.be_true(float.absolute_value(intersection.left_t -. 0.37) <=. 0.00002)
  should.be_true(float.absolute_value(intersection.right_t -. 0.63) <=. 0.00002)
}

pub fn production_two_close_quadratic_crossings_test() {
  let axis =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.0),
      control: svg_path.Point(0.5, 0.0),
      end: svg_path.Point(1.0, 0.0),
    )
  // y = (t - 0.5)^2 - 1e-8, with roots at 0.4999 and 0.5001.
  let curve =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.24999999),
      control: svg_path.Point(0.5, -0.25000001),
      end: svg_path.Point(1.0, 0.24999999),
    )
  let assert Ok(found) = intersections.segment(axis, curve)
  list.length(found) |> should.equal(2)
}

pub fn flat_cubic_crossing_regression_test() {
  let rising =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, -0.125),
      control1: svg_path.Point(1.0 /. 3.0, 0.125),
      control2: svg_path.Point(2.0 /. 3.0, -0.125),
      end: svg_path.Point(1.0, 0.125),
    )
  let falling =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.125),
      control1: svg_path.Point(1.0 /. 3.0, -0.125),
      control2: svg_path.Point(2.0 /. 3.0, 0.125),
      end: svg_path.Point(1.0, -0.125),
    )
  let assert Ok([intersection]) = intersections.segment(rising, falling)
  should.be_true(float.absolute_value(intersection.left_t -. 0.5) <=. 0.000001)
  should.be_true(float.absolute_value(intersection.right_t -. 0.5) <=. 0.000001)
}

pub fn disjoint_quadratics_regression_test() {
  let upper =
    svg_path.QuadraticBezier(
      start: svg_path.Point(-1.0, 2.0),
      control: svg_path.Point(0.0, 1.0),
      end: svg_path.Point(1.0, 2.0),
    )
  let lower =
    svg_path.QuadraticBezier(
      start: svg_path.Point(-1.0, -2.0),
      control: svg_path.Point(0.0, -1.0),
      end: svg_path.Point(1.0, -2.0),
    )
  intersections.segment(upper, lower)
  |> should.equal(Ok([]))
}

pub fn adjacent_quadratic_crossing_regression_test() {
  let previous =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.0),
      control: svg_path.Point(0.5, 2.0),
      end: svg_path.Point(1.0, 0.0),
    )
  let next =
    svg_path.QuadraticBezier(
      start: svg_path.Point(1.0, 0.0),
      control: svg_path.Point(0.5, -1.0),
      end: svg_path.Point(0.0, 1.0),
    )
  let assert Ok(found) = intersections.segment(previous, next)
  list.length(found) |> should.equal(2)
}

pub fn window_guard_fallback_regression_test() {
  let previous =
    svg_path.CubicBezier(
      start: svg_path.Point(3.7326908112839723, 3.0798423879604986),
      control1: svg_path.Point(3.7326908112839723, 3.0798423879604986),
      control2: svg_path.Point(3.732979794442744, 3.079321742790136),
      end: svg_path.Point(3.7326907230069644, 3.079843411893102),
    )
  let next =
    svg_path.CubicBezier(
      start: svg_path.Point(3.7326907230069644, 3.079843411893102),
      control1: svg_path.Point(3.7867214554038764, 2.9802982971613803),
      control2: svg_path.Point(3.813617440000867, 2.8517024128302615),
      end: svg_path.Point(3.8148384145946803, 2.834959380847173),
    )
  let assert Ok(found) = intersections.segment(previous, next)
  should.be_true(list.length(found) >= 1)
}

pub fn near_parallel_line_projection_is_scale_invariant_test() {
  let left =
    svg_path.Line(
      start: svg_path.Point(-1.0, -0.00000001),
      end: svg_path.Point(1.0, 0.00000001),
    )
  let right =
    svg_path.Line(
      start: svg_path.Point(-1.0, 0.00000001),
      end: svg_path.Point(1.0, -0.00000001),
    )

  [0.000001, 1.0, 1_000_000.0]
  |> list.each(fn(scale) {
    let assert Ok(scaled_left) = transform.scale_segment(left, factor: scale)
    let assert Ok(scaled_right) = transform.scale_segment(right, factor: scale)
    let assert Ok(projection) =
      intersections.segment_segment_projection_with(
        scaled_left,
        scaled_right,
        options: intersections.IntersectionOptions(
          tolerance: 0.000000000001 *. scale,
          max_depth: 48,
          parameter_snap: intersections.NoParameterSnap,
        ),
      )
    should.be_true(float.absolute_value(projection.left_t -. 0.5) <=. 0.000001)
    should.be_true(float.absolute_value(projection.right_t -. 0.5) <=. 0.000001)
    projection.distance |> should.equal(0.0)
  })
}
