import gleam/option.{None, Some}
import gleeunit
import svg_path

const tolerance = 0.0000001

pub fn main() -> Nil {
  gleeunit.main()
}

fn point_near(a: svg_path.Point, b: svg_path.Point) -> Bool {
  let svg_path.Point(ax, ay) = a
  let svg_path.Point(bx, by) = b
  float_absolute(ax -. bx) <. tolerance && float_absolute(ay -. by) <. tolerance
}

fn float_absolute(value: Float) -> Float {
  case value <. 0.0 {
    True -> 0.0 -. value
    False -> value
  }
}

pub fn segment_directions_normalize_ordinary_tangent_test() {
  let segment =
    svg_path.Line(svg_path.Point(1.0, 2.0), svg_path.Point(4.0, 6.0))
  let assert Ok(svg_path.Directions(Some(incoming), Some(outgoing))) =
    svg_path.segment_directions(segment, at: 0.5)

  assert point_near(incoming, svg_path.Point(0.6, 0.8))
  assert point_near(outgoing, svg_path.Point(0.6, 0.8))
}

pub fn segment_directions_recover_collapsed_cubic_endpoint_tangent_test() {
  let segment =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(0.0, 0.0),
      control2: svg_path.Point(0.0, 10.0),
      end: svg_path.Point(10.0, 10.0),
    )
  let assert Ok(svg_path.Directions(None, Some(outgoing))) =
    svg_path.segment_directions(segment, at: 0.0)

  assert point_near(outgoing, svg_path.Point(0.0, 1.0))
}

pub fn segment_directions_distinguish_stationary_reversal_sides_test() {
  let segment =
    svg_path.QuadraticBezier(
      start: svg_path.Point(1.0, 0.0),
      control: svg_path.Point(-1.0, 0.0),
      end: svg_path.Point(1.0, 0.0),
    )
  let assert Ok(svg_path.Directions(Some(incoming), Some(outgoing))) =
    svg_path.segment_directions(segment, at: 0.5)

  assert point_near(incoming, svg_path.Point(-1.0, 0.0))
  assert point_near(outgoing, svg_path.Point(1.0, 0.0))
}

pub fn cubic_directions_distinguish_stationary_reversal_sides_test() {
  let segment =
    svg_path.CubicBezier(
      start: svg_path.Point(0.25, 0.0),
      control1: svg_path.Point(-0.08333333333333333, 0.0),
      control2: svg_path.Point(-0.08333333333333333, 0.0),
      end: svg_path.Point(0.25, 0.0),
    )
  let assert Ok(svg_path.Directions(Some(incoming), Some(outgoing))) =
    svg_path.segment_directions(segment, at: 0.5)

  assert point_near(incoming, svg_path.Point(-1.0, 0.0))
  assert point_near(outgoing, svg_path.Point(1.0, 0.0))
}

pub fn cubic_directions_recover_third_order_endpoint_direction_test() {
  let origin = svg_path.Point(0.0, 0.0)
  let segment =
    svg_path.CubicBezier(
      start: origin,
      control1: origin,
      control2: origin,
      end: svg_path.Point(3.0, 4.0),
    )
  let assert Ok(svg_path.Directions(None, Some(outgoing))) =
    svg_path.segment_directions(segment, at: 0.0)

  assert point_near(outgoing, svg_path.Point(0.6, 0.8))
}

pub fn exact_direction_options_keep_nonzero_first_candidate_test() {
  let segment =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(0.000000000001, 0.0),
      control2: svg_path.Point(0.0, 1.0),
      end: svg_path.Point(1.0, 1.0),
    )
  let assert Ok(svg_path.Directions(None, Some(default_direction))) =
    svg_path.segment_directions(segment, at: 0.0)
  let assert Ok(svg_path.Directions(None, Some(exact_direction))) =
    svg_path.segment_directions_with(
      segment,
      at: 0.0,
      options: svg_path.DirectionOptions(relative_tolerance: 0.0),
    )

  assert point_near(default_direction, svg_path.Point(0.0, 1.0))
  assert point_near(exact_direction, svg_path.Point(1.0, 0.0))
}

pub fn subpath_directions_use_both_sides_of_corner_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(1.0, 0.0)),
      svg_path.Line(svg_path.Point(1.0, 0.0), svg_path.Point(1.0, 1.0)),
    ])
  let assert Ok(svg_path.Directions(Some(incoming), Some(outgoing))) =
    svg_path.subpath_directions(
      subpath,
      at: svg_path.SubpathParameter(segment_index: 0, t: 1.0),
    )

  assert point_near(incoming, svg_path.Point(1.0, 0.0))
  assert point_near(outgoing, svg_path.Point(0.0, 1.0))
}

pub fn subpath_directions_skip_directionless_segments_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(1.0, 0.0)
  let c = svg_path.Point(1.0, 1.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(a, b),
      svg_path.Line(b, b),
      svg_path.Line(b, c),
    ])
  let assert Ok(svg_path.Directions(Some(incoming), Some(outgoing))) =
    svg_path.subpath_directions(
      subpath,
      at: svg_path.SubpathParameter(segment_index: 1, t: 0.0),
    )

  assert point_near(incoming, svg_path.Point(1.0, 0.0))
  assert point_near(outgoing, svg_path.Point(0.0, 1.0))
}

pub fn subpath_directions_report_open_ends_and_closed_seam_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(1.0, 0.0)
  let c = svg_path.Point(1.0, 1.0)
  let open = svg_path.subpath_assert([svg_path.Line(a, b), svg_path.Line(b, c)])
  let assert Ok(svg_path.Directions(None, Some(open_start))) =
    svg_path.subpath_directions(
      open,
      at: svg_path.SubpathParameter(segment_index: 0, t: 0.0),
    )
  let assert Ok(svg_path.Directions(Some(open_end), None)) =
    svg_path.subpath_directions(
      open,
      at: svg_path.SubpathParameter(segment_index: 1, t: 1.0),
    )

  let closed =
    svg_path.subpath_assert([
      svg_path.Line(a, b),
      svg_path.Line(b, c),
      svg_path.Line(c, a),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)
  let assert Ok(svg_path.Directions(Some(seam_in), Some(seam_out))) =
    svg_path.subpath_directions(
      closed,
      at: svg_path.SubpathParameter(segment_index: 0, t: 0.0),
    )

  assert point_near(open_start, svg_path.Point(1.0, 0.0))
  assert point_near(open_end, svg_path.Point(0.0, 1.0))
  assert point_near(seam_in, svg_path.Point(-0.70710678, -0.70710678))
  assert point_near(seam_out, svg_path.Point(1.0, 0.0))
}

pub fn path_directions_delegate_to_addressed_subpath_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(0.0, 2.0)),
    ])
  let path = svg_path.Path([subpath])
  let assert Ok(svg_path.Directions(Some(incoming), None)) =
    svg_path.path_directions(
      path,
      at: svg_path.PathParameter(
        subpath_index: 0,
        at: svg_path.SubpathParameter(segment_index: 0, t: 1.0),
      ),
    )

  assert point_near(incoming, svg_path.Point(0.0, 1.0))
}

pub fn direction_options_reject_negative_relative_tolerance_test() {
  let segment =
    svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(1.0, 0.0))

  assert svg_path.segment_directions_with(
      segment,
      at: 0.5,
      options: svg_path.DirectionOptions(relative_tolerance: -0.1),
    )
    == Error(svg_path.InvalidDirectionRelativeTolerance(-0.1))
}
