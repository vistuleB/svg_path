import gleam/float
import gleeunit
import svg_path
import svg_path/curvature

const tolerance = 0.000000001

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn left_normal_radius_uses_offset_normal_sign_test() {
  let visually_downward = visually_downward_cubic()
  let visually_upward = visually_upward_cubic()

  let assert Ok(visually_downward_radius) =
    curvature.segment_left_normal_radius(visually_downward, at: 0.5)
  let assert Ok(visually_upward_radius) =
    curvature.segment_left_normal_radius(visually_upward, at: 0.5)

  assert near(visually_downward_radius, -0.2651650429449553)
  assert near(visually_upward_radius, 0.2651650429449553)
}

pub fn left_normal_cusp_parameters_match_positive_offset_side_test() {
  let options = curvature.default_options()

  assert curvature.segment_left_normal_cusp_parameters(
      visually_downward_cubic(),
      distance: 0.27,
      options:,
    )
    == Ok([])

  let assert Ok(parameters) =
    curvature.segment_left_normal_cusp_parameters(
      visually_upward_cubic(),
      distance: 0.27,
      options:,
    )
  let assert [left, right] = parameters
  assert near(left, 0.4786978280544282)
  assert near(right, 0.5213021719455719)
}

pub fn segment_inflection_parameters_detect_cubic_inflection_test() {
  let segment =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(1.0, 1.0),
      control2: svg_path.Point(2.0, -1.0),
      end: svg_path.Point(3.0, 0.0),
    )

  let assert Ok(parameters) =
    curvature.segment_inflection_parameters(
      segment,
      options: curvature.default_options(),
    )

  let assert [parameter] = parameters
  assert near(parameter, 0.5)
}

pub fn segment_inflection_parameters_ignore_flat_cubic_test() {
  let segment =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(0.3333333333333333, 0.0),
      control2: svg_path.Point(0.6666666666666666, 0.0),
      end: svg_path.Point(1.0, 0.0),
    )

  assert curvature.segment_inflection_parameters(
      segment,
      options: curvature.default_options(),
    )
    == Ok([])
}

fn visually_downward_cubic() -> svg_path.Segment {
  svg_path.CubicBezier(
    start: svg_path.Point(0.0, 0.0),
    control1: svg_path.Point(1.0, 0.0),
    control2: svg_path.Point(1.0, 0.0),
    end: svg_path.Point(1.0, 1.0),
  )
}

fn visually_upward_cubic() -> svg_path.Segment {
  svg_path.CubicBezier(
    start: svg_path.Point(0.0, 0.0),
    control1: svg_path.Point(1.0, 0.0),
    control2: svg_path.Point(1.0, 0.0),
    end: svg_path.Point(1.0, -1.0),
  )
}

fn near(a: Float, b: Float) -> Bool {
  float.absolute_value(a -. b) <=. tolerance
}
