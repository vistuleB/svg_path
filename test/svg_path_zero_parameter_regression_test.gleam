import gleam/list
import gleam/option.{None, Some}
import svg_path

pub fn subpath_canonicalization_normalizes_negative_zero_test() {
  let subpath = corner()
  assert svg_path.subpath_parameter_canonicalize(
      subpath,
      parameter: svg_path.SubpathParameter(1, -0.0),
    )
    == Ok(svg_path.SubpathParameter(1, 0.0))
}

pub fn negative_zero_corner_preserves_both_directions_test() {
  assert svg_path.subpath_directions(
      corner(),
      at: svg_path.SubpathParameter(1, -0.0),
    )
    == Ok(svg_path.Directions(
      incoming: Some(svg_path.Point(1.0, 0.0)),
      outgoing: Some(svg_path.Point(0.0, 1.0)),
    ))
}

pub fn negative_zero_interval_end_does_not_add_a_segment_test() {
  let subpath = corner()
  let assert Ok(expected) =
    svg_path.subpath([
      svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(1.0, 0.0)),
    ])
  assert svg_path.subpath_between(
      subpath,
      from: svg_path.SubpathParameter(0, 0.0),
      to: svg_path.SubpathParameter(1, -0.0),
    )
    == Ok(expected)
}

pub fn arc_negative_zero_evaluates_to_exact_start_test() {
  assert svg_path.segment_point(arc(), at: -0.0)
    == Ok(svg_path.segment_start(arc()))
}

pub fn arc_negative_zero_has_no_incoming_direction_test() {
  let assert Ok(svg_path.Directions(incoming: None, outgoing: Some(direction))) =
    svg_path.segment_directions(arc(), at: 0.0)
  assert svg_path.segment_directions(arc(), at: -0.0)
    == Ok(svg_path.Directions(incoming: None, outgoing: Some(direction)))
}

pub fn mixed_signed_zero_interval_is_a_point_like_line_test() {
  let segment = arc()
  let start = svg_path.segment_start(segment)
  list.each([#(0.0, -0.0), #(-0.0, 0.0), #(-0.0, -0.0)], fn(interval) {
    let #(from, to) = interval
    assert svg_path.segment_between(segment, from:, to:)
      == Ok(svg_path.Line(start, start))
    assert svg_path.segment_between_inside(segment, from:, to:)
      == Ok(svg_path.Line(start, start))
  })
}

pub fn arc_split_treats_signed_zeros_identically_test() {
  let segment = arc()
  let assert Ok(expected) = svg_path.segment_split(segment, at: 0.0)
  assert svg_path.segment_split(segment, at: -0.0) == Ok(expected)
  assert svg_path.segment_split_inside(segment, at: -0.0) == Ok(expected)
}

fn corner() -> svg_path.Subpath {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(1.0, 0.0)
  let c = svg_path.Point(1.0, 1.0)
  let assert Ok(subpath) =
    svg_path.subpath([svg_path.Line(a, b), svg_path.Line(b, c)])
  subpath
}

fn arc() -> svg_path.Segment {
  svg_path.Arc(
    start: svg_path.Point(0.1, 0.2),
    radius: svg_path.Point(3.0, 2.0),
    x_axis_rotation: 17.0,
    large_arc: False,
    sweep: True,
    end: svg_path.Point(2.0, 3.0),
  )
}
