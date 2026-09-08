import gleam/float
import gleam/int
import gleam/list
import svg_path
import svg_path/curvature

fn arch() -> svg_path.Segment {
  svg_path.CubicBezier(
    svg_path.Point(0.0, 0.0),
    svg_path.Point(1.0, 0.0),
    svg_path.Point(1.0, 0.0),
    svg_path.Point(1.0, -1.0),
  )
}

fn parabola() -> svg_path.Segment {
  svg_path.QuadraticBezier(
    svg_path.Point(0.0, 0.0),
    svg_path.Point(0.5, 0.0),
    svg_path.Point(1.0, 1.0),
  )
}

pub fn cusp_depth_exhaustion_reports_remaining_bracket_test() {
  assert curvature.segment_left_normal_cusp_parameters(
      parabola(),
      distance: -1.0,
      options: curvature.Options(1.0e-12, 1),
    )
    == Error(curvature.CurvatureMaxDepthReached(lower: 0.0, upper: 0.5))
}

pub fn cusp_exact_root_at_depth_limit_succeeds_test() {
  let assert Ok(speed) = float.square_root(1.25)
  let distance = 0.0 -. 1.25 *. speed /. 2.0
  assert curvature.segment_left_normal_cusp_parameters(
      parabola(),
      distance:,
      options: curvature.Options(0.0, 1),
    )
    == Ok([0.25])
}

pub fn cusp_interval_converged_at_depth_limit_succeeds_test() {
  assert curvature.segment_left_normal_cusp_parameters(
      parabola(),
      distance: -1.0,
      options: curvature.Options(0.5, 1),
    )
    == Ok([0.25])
}

pub fn shifted_stationary_cubics_keep_both_neighboring_intervals_test() {
  // One velocity coordinate has a simple zero; the other a double zero.
  // Solving only the latter can miss the stationary boundary through rounding.
  let assert Ok(speed_factor) = float.square_root(4.09)
  let distance = 0.0 -. 4.09 *. speed_factor *. 0.1 /. 6.0
  int.range(1, 99, with: Nil, run: fn(_, i) {
    let r = int.to_float(i) /. 100.0
    let start = svg_path.Point(r *. r, 0.0 -. r *. r *. r)
    let control1 = svg_path.Point(start.x -. 2.0 *. r /. 3.0, start.y +. r *. r)
    let control2 =
      svg_path.Point(
        1.0 /. 3.0 +. 2.0 *. control1.x -. start.x,
        0.0 -. r +. 2.0 *. control1.y -. start.y,
      )
    let u = 1.0 -. r
    let curve =
      svg_path.CubicBezier(
        start,
        control1,
        control2,
        svg_path.Point(u *. u, u *. u *. u),
      )
    let assert Ok(actual) =
      curvature.segment_left_normal_cusp_parameters(
        curve,
        distance:,
        options: curvature.Options(1.0e-10, 48),
      )
    let expected =
      list.filter([r -. 0.1, r +. 0.1], fn(t) { t >=. 0.0 && t <=. 1.0 })
    assert list.length(actual) == list.length(expected)
    list.each(list.zip(actual, expected), fn(pair) {
      let #(a, b) = pair
      assert float.absolute_value(a -. b) <. 1.0e-6
    })
  })
}

pub fn touching_cusp_between_sample_points_test() {
  let curve = arch()
  let assert Ok(distance) = curvature.segment_left_normal_radius(curve, at: 0.5)
  let assert Ok([t]) =
    curvature.segment_left_normal_cusp_parameters(
      curve,
      distance:,
      options: curvature.Options(1.0e-9, 48),
    )
  assert float.absolute_value(t -. 0.5) <. 1.0e-8
}

pub fn two_cusps_in_one_old_sample_window_test() {
  let curve = arch()
  let assert Ok(radius) = curvature.segment_left_normal_radius(curve, at: 0.5)
  let assert Ok([left, right]) =
    curvature.segment_left_normal_cusp_parameters(
      curve,
      distance: radius +. 0.000001,
      options: curvature.Options(1.0e-10, 48),
    )
  assert left >. 49.0 /. 99.0 && left <. 0.5
  assert right >. 0.5 && right <. 50.0 /. 99.0
}

pub fn touching_cusp_close_miss_is_rejected_test() {
  let curve = arch()
  let assert Ok(radius) = curvature.segment_left_normal_radius(curve, at: 0.5)
  assert curvature.segment_left_normal_cusp_parameters(
      curve,
      distance: radius -. 0.000001,
      options: curvature.default_options(),
    )
    == Ok([])
}

pub fn stationary_cubic_endpoint_does_not_hide_cusp_test() {
  // p(t)=(t^2,t^3), zero speed at t=0; R(.5)=-125/96.
  let curve =
    svg_path.CubicBezier(
      svg_path.Point(0.0, 0.0),
      svg_path.Point(0.0, 0.0),
      svg_path.Point(1.0 /. 3.0, 0.0),
      svg_path.Point(1.0, 1.0),
    )
  let assert Ok([t]) =
    curvature.segment_left_normal_cusp_parameters(
      curve,
      distance: -125.0 /. 96.0,
      options: curvature.Options(1.0e-10, 48),
    )
  assert float.absolute_value(t -. 0.5) <. 1.0e-8
}

pub fn stationary_interior_is_not_a_cusp_root_test() {
  // p(t)=((t-.5)^2,(t-.5)^3); t=.5 has zero speed.
  let curve =
    svg_path.CubicBezier(
      svg_path.Point(0.25, -0.125),
      svg_path.Point(-1.0 /. 12.0, 0.125),
      svg_path.Point(-1.0 /. 12.0, -0.125),
      svg_path.Point(0.25, 0.125),
    )
  let assert Ok([left, right]) =
    curvature.segment_left_normal_cusp_parameters(
      curve,
      distance: -1.0,
      options: curvature.Options(1.0e-10, 48),
    )
  assert left <. 0.5 && right >. 0.5
  assert float.absolute_value(left +. right -. 1.0) <. 1.0e-8
  assert curvature.segment_left_normal_cusp_parameters(
      curve,
      distance: 0.0,
      options: curvature.default_options(),
    )
    == Ok([])
}

pub fn circle_constant_cusp_returns_interval_endpoints_test() {
  let arc =
    svg_path.Arc(
      svg_path.Point(4.0, 0.0),
      svg_path.Point(4.0, 4.0),
      0.0,
      False,
      True,
      svg_path.Point(0.0, 4.0),
    )
  assert curvature.segment_left_normal_cusp_parameters(
      arc,
      distance: -4.0,
      options: curvature.default_options(),
    )
    == Ok([0.0, 1.0])
  assert curvature.segment_left_normal_cusp_parameters(
      arc,
      distance: 4.0,
      options: curvature.default_options(),
    )
    == Ok([])
}

pub fn elliptical_touch_between_sample_points_test() {
  let arc =
    svg_path.Arc(
      svg_path.Point(4.0, 0.0),
      svg_path.Point(4.0, 2.0),
      0.0,
      False,
      True,
      svg_path.Point(-4.0, 0.0),
    )
  let assert Ok([t]) =
    curvature.segment_left_normal_cusp_parameters(
      arc,
      distance: -8.0,
      options: curvature.Options(1.0e-9, 48),
    )
  assert float.absolute_value(t -. 0.5) <. 1.0e-8
}
