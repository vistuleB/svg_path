import gleam/list
import svg_path.{Arc, CubicBezier, Line, Point}
import svg_path/offset

pub fn generated_nonuniform_cubic_straightens_with_original_preserved_test() {
  let original =
    CubicBezier(
      Point(0.0, 0.0),
      Point(0.0, 0.0),
      Point(2.0, 0.0),
      Point(10.0, 0.0),
    )
  let assert Ok(stage) = offset.straighten_generated_segment(original)
  assert stage.original == original
  assert stage.segment == Line(Point(0.0, 0.0), Point(10.0, 0.0))
}

pub fn generated_reversing_cubic_remains_one_curve_test() {
  let original =
    CubicBezier(
      Point(0.0, 0.0),
      Point(3.0, 0.0),
      Point(-2.0, 0.0),
      Point(1.0, 0.0),
    )
  let assert Ok(stage) = offset.straighten_generated_segment(original)
  assert stage.segment == original
}

pub fn generated_shallow_arc_straightens_but_semicircle_remains_test() {
  let shallow =
    Arc(
      Point(0.0, 0.0),
      Point(81.0, 81.0),
      0.0,
      False,
      True,
      Point(0.0001, 0.0),
    )
  let assert Ok(stage) = offset.straighten_generated_segment(shallow)
  assert stage.segment == Line(Point(0.0, 0.0), Point(0.0001, 0.0))
  let semicircle =
    Arc(
      Point(-81.0, 0.0),
      Point(81.0, 81.0),
      0.0,
      False,
      True,
      Point(81.0, 0.0),
    )
  let assert Ok(stage) = offset.straighten_generated_segment(semicircle)
  assert stage.segment == semicircle
}

pub fn generated_point_segment_is_retained_test() {
  let original = Line(Point(2.0, 3.0), Point(2.0, 3.0))
  let assert Ok(stage) = offset.straighten_generated_segment(original)
  assert stage.segment == original
}

pub fn stalled_reversal_offset_straightens_before_trimming_test() {
  let assert Ok(source) =
    svg_path.subpath_polyline(
      list.map([-1.0, 0.0, 0.0002, 0.0001, 0.0003, 1.0], fn(x) { Point(x, 0.0) }),
    )
  let assert Ok(raw) =
    offset.subpath_untrimmed_with(
      source,
      -1.0,
      offset.Round,
      offset.default_options(),
    )
  let segments = svg_path.subpath_segments(raw)
  assert list.length(segments) == 5
  assert list.all(segments, fn(segment) {
    case segment {
      Line(..) | Arc(..) -> True
      _ -> False
    }
  })
  let assert [_, _, middle, _, _] = segments
  assert middle == Line(Point(0.0002, -1.0), Point(0.0001, -1.0))
}

pub fn nonzero_ulp_line_has_an_offset_direction_test() {
  let segment =
    Line(
      Point(65.13497199999999, 13.465),
      Point(65.13497199999999, 13.464999999999996),
    )
  list.each([0.0, 0.25, 0.5, 1.0], fn(t) {
    let assert Ok(direction) = offset.unit_tangent(segment, t:)
    assert direction == Point(0.0, -1.0)
    let assert Ok(reverse) =
      offset.unit_tangent(svg_path.segment_reverse(segment), t:)
    assert reverse == Point(0.0, 1.0)
  })
  let assert Ok(source) =
    svg_path.subpath([
      Line(Point(64.0, 13.465), svg_path.segment_start(segment)),
      segment,
      Line(svg_path.segment_end(segment), Point(66.0, 13.464999999999996)),
    ])
  let assert Ok(_) =
    offset.subpath_untrimmed_with(
      source,
      1.04,
      offset.Miter(4.0),
      offset.default_options(),
    )
  let point = Line(Point(0.0, 0.0), Point(0.0, 0.0))
  let assert Error(_) = offset.unit_tangent(point, 0.25)
}
