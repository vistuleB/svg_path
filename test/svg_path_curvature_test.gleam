import gleam/float
import gleeunit
import svg_path
import svg_path/curvature

const tolerance = 0.000000001

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn invalid_tolerance_reports_invalid_curvature_tolerance_test() {
  let invalid = curvature.Options(tolerance: -0.5, samples: 100, max_depth: 32)

  let assert Error(curvature.InvalidCurvatureTolerance(value)) =
    curvature.segment_left_normal_cusp_parameters(
      visually_upward_cubic(),
      distance: 0.27,
      options: invalid,
    )

  assert value == -0.5
}

pub fn zero_tolerance_options_are_accepted_test() {
  let exact = curvature.Options(tolerance: 0.0, samples: 100, max_depth: 32)

  let assert Ok(parameters) =
    curvature.segment_left_normal_cusp_parameters(
      visually_upward_cubic(),
      distance: 0.27,
      options: exact,
    )
  let assert [left, right] = parameters
  assert near(left, 0.4786978280544282)
  assert near(right, 0.5213021719455719)
}

pub fn invalid_samples_reports_invalid_curvature_samples_test() {
  let invalid =
    curvature.Options(tolerance: 0.000000001, samples: 0, max_depth: 32)

  let assert Error(curvature.InvalidCurvatureSamples(value)) =
    curvature.segment_left_normal_cusp_parameters(
      visually_upward_cubic(),
      distance: 0.27,
      options: invalid,
    )

  assert value == 0
}

pub fn invalid_max_depth_reports_invalid_curvature_max_depth_test() {
  let invalid =
    curvature.Options(tolerance: 0.000000001, samples: 100, max_depth: 0)

  let assert Error(curvature.InvalidCurvatureMaxDepth(value)) =
    curvature.segment_left_normal_cusp_parameters(
      visually_upward_cubic(),
      distance: 0.27,
      options: invalid,
    )

  assert value == 0
}

pub fn invalid_margin_reports_invalid_curvature_margin_test() {
  let assert Error(curvature.InvalidCurvatureMargin(value)) =
    curvature.segment_left_normal_radius_close_to(
      visually_upward_cubic(),
      distance: 0.27,
      margin: -1.0,
      at: 0.5,
    )

  assert value == -1.0
}

pub fn line_radius_reports_infinite_radius_of_curvature_test() {
  let line =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(1.0, 0.0),
    )

  let assert Error(curvature.InfiniteRadiusOfCurvature) =
    curvature.segment_left_normal_radius(line, at: 0.5)
}

pub fn collapsed_segment_reports_degenerate_curvature_derivative_test() {
  let collapsed =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(0.0, 0.0),
      control2: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(0.0, 0.0),
    )

  let assert Error(curvature.DegenerateCurvatureDerivative) =
    curvature.segment_left_normal_curvature(collapsed, at: 0.5)
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

pub fn arc_curvature_uses_exact_ellipse_derivatives_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.Point(4.0, 0.0),
      radius: svg_path.Point(4.0, 4.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(0.0, 4.0),
    )

  let assert Ok(radius) = curvature.segment_left_normal_radius(arc, at: 0.5)
  assert near(radius, -4.0)
}

pub fn cusp_parameters_retain_exact_sampled_root_test() {
  let parabola =
    svg_path.QuadraticBezier(
      start: svg_path.Point(-1.0, 1.0),
      control: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(1.0, 1.0),
    )

  let assert Ok(parameters) =
    curvature.segment_left_normal_cusp_parameters(
      parabola,
      distance: -1.0,
      options: curvature.default_options(),
    )
  assert list_contains_near(parameters, 0.5)
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

fn list_contains_near(values: List(Float), expected: Float) -> Bool {
  case values {
    [] -> False
    [first, ..rest] ->
      near(first, expected) || list_contains_near(rest, expected)
  }
}
