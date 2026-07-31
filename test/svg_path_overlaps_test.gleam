import gleam/list
import svg_path
import svg_path/overlaps

pub fn identical_line_is_one_full_overlap_test() {
  assert_full_overlap(line(), line(), 0.0, 1.0)
}

pub fn reversed_line_is_one_full_overlap_test() {
  assert_full_overlap(line(), svg_path.segment_reverse(line()), 1.0, 0.0)
}

pub fn identical_quadratic_is_one_full_overlap_test() {
  let segment =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.0),
      control: svg_path.Point(5.0, 8.0),
      end: svg_path.Point(10.0, 0.0),
    )
  assert_full_overlap(segment, segment, 0.0, 1.0)
}

pub fn reversed_quadratic_is_one_full_overlap_test() {
  let segment =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.0),
      control: svg_path.Point(5.0, 8.0),
      end: svg_path.Point(10.0, 0.0),
    )
  assert_full_overlap(segment, svg_path.segment_reverse(segment), 1.0, 0.0)
}

pub fn identical_cubic_is_one_full_overlap_test() {
  let segment =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(2.0, 9.0),
      control2: svg_path.Point(8.0, -9.0),
      end: svg_path.Point(10.0, 0.0),
    )
  assert_full_overlap(segment, segment, 0.0, 1.0)
}

pub fn reversed_cubic_is_one_full_overlap_test() {
  let segment =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(2.0, 9.0),
      control2: svg_path.Point(8.0, -9.0),
      end: svg_path.Point(10.0, 0.0),
    )
  assert_full_overlap(segment, svg_path.segment_reverse(segment), 1.0, 0.0)
}

pub fn identical_arc_is_one_full_overlap_test() {
  let segment = arc()
  assert_full_overlap(segment, segment, 0.0, 1.0)
}

pub fn reversed_arc_is_one_full_overlap_test() {
  let segment = arc()
  assert_full_overlap(segment, svg_path.segment_reverse(segment), 1.0, 0.0)
}

pub fn arcs_sharing_two_endpoints_are_two_point_intersections_test() {
  let upper = arc()
  let lower =
    svg_path.Arc(
      start: svg_path.Point(0.0, 0.0),
      radius: svg_path.Point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: True,
      sweep: True,
      end: svg_path.Point(10.0, 0.0),
    )
  let assert Ok(encounters) = overlaps.segment(upper, lower)
  assert list.length(encounters) == 2
}

fn assert_full_overlap(
  left: svg_path.Segment,
  right: svg_path.Segment,
  expected_right_from: Float,
  expected_right_to: Float,
) {
  let assert Ok([encounter]) = overlaps.segment(left, right)
  let assert overlaps.Overlap(
    left_from:,
    left_to:,
    right_from:,
    right_to:,
    start:,
    end:,
  ) = encounter
  assert left_from == 0.0
  assert left_to == 1.0
  assert right_from == expected_right_from
  assert right_to == expected_right_to
  assert start == svg_path.segment_start(left)
  assert end == svg_path.segment_end(left)
}

fn line() -> svg_path.Segment {
  svg_path.Line(start: svg_path.Point(0.0, 0.0), end: svg_path.Point(10.0, 0.0))
}

fn arc() -> svg_path.Segment {
  svg_path.Arc(
    start: svg_path.Point(0.0, 0.0),
    radius: svg_path.Point(5.0, 5.0),
    x_axis_rotation: 0.0,
    large_arc: False,
    sweep: True,
    end: svg_path.Point(10.0, 0.0),
  )
}
