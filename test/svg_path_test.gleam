import gleam/list
import gleeunit
import svg_path

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn line_keeps_its_endpoints_test() {
  let start = svg_path.point(0.0, 0.0)
  let end = svg_path.point(10.0, 20.0)
  let segment = svg_path.line(start:, end:)

  assert svg_path.segment_start(segment) == start
  assert svg_path.segment_end(segment) == end
}

pub fn path_can_be_built_from_empty_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let assert Ok(subpath) =
    svg_path.empty_subpath()
    |> svg_path.append(svg_path.line(start: a, end: b))
  let path =
    svg_path.empty_path()
    |> svg_path.append_subpath(subpath)

  assert path |> svg_path.subpaths |> list.length == 1
  assert svg_path.from_subpath(subpath) |> svg_path.subpaths == [subpath]
}

pub fn as_subpath_accepts_empty_path_test() {
  let assert Ok(subpath) = svg_path.as_subpath(svg_path.empty_path())

  assert svg_path.segments(subpath) == []
}

pub fn as_subpath_ignores_empty_subpaths_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let line = svg_path.line(start: a, end: b)
  let assert Ok(subpath) = svg_path.subpath([line])
  let path =
    svg_path.path([
      svg_path.empty_subpath(),
      subpath,
      svg_path.empty_subpath(),
    ])
  let assert Ok(only_subpath) = svg_path.as_subpath(path)

  assert svg_path.segments(only_subpath) == [line]
}

pub fn as_subpath_rejects_multiple_nonempty_subpaths_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let assert Ok(first) = svg_path.subpath([svg_path.line(start: a, end: b)])
  let assert Ok(second) = svg_path.subpath([svg_path.line(start: c, end: d)])

  assert svg_path.as_subpath(svg_path.path([first, second]))
    == Error(svg_path.MultipleNonemptySubpaths)
}

pub fn subpath_can_be_built_from_empty_test() {
  let start = svg_path.point(0.0, 0.0)
  let end = svg_path.point(10.0, 0.0)
  let assert Ok(subpath) =
    svg_path.empty_subpath()
    |> svg_path.append(svg_path.line(start:, end:))

  assert svg_path.start(subpath) == Ok(start)
  assert svg_path.end(subpath) == Ok(end)
}

pub fn empty_subpath_has_no_start_or_end_test() {
  assert svg_path.start(svg_path.empty_subpath())
    == Error(svg_path.EmptySubpath)
  assert svg_path.end(svg_path.empty_subpath()) == Error(svg_path.EmptySubpath)
}

pub fn subpath_rejects_disconnected_segments_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)

  assert svg_path.subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: c, end: d),
    ])
    == Error(svg_path.Discontinuous(expected: b, got: c))
}

pub fn assert_subpath_builds_continuous_segments_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let segments = [
    svg_path.line(start: a, end: b),
    svg_path.line(start: b, end: c),
  ]

  let subpath = svg_path.assert_subpath(segments)

  assert svg_path.segments(subpath) == segments
}

pub fn append_rejects_closed_subpath_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: a),
    ])
    |> result_try_force_close

  assert svg_path.append(subpath, svg_path.line(start: a, end: c))
    == Error(svg_path.AlreadyClosed)
}

pub fn wiggle_subpath_replaces_nearby_sequential_endpoints_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let near_b = svg_path.point(10.0000000001, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let assert Ok(subpath) =
    svg_path.wiggle_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: near_b, end: c),
    ])

  let assert [first, second] = svg_path.segments(subpath)
  let overlap = svg_path.segment_end(first)

  assert svg_path.segment_start(first) == a
  assert svg_path.segment_start(second) == overlap
  assert svg_path.segment_end(second) == c
  assert overlap != b
  assert overlap != near_b
}

pub fn wiggle_subpath_accepts_empty_and_single_segment_inputs_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let line = svg_path.line(start: a, end: b)

  assert svg_path.wiggle_subpath([]) == Ok(svg_path.empty_subpath())
  let assert Ok(subpath) = svg_path.wiggle_subpath([line])
  assert svg_path.segments(subpath) == [line]
}

pub fn clean_subpath_removes_zero_length_lines_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let first = svg_path.line(start: a, end: b)
  let zero = svg_path.line(start: b, end: b)
  let second = svg_path.line(start: b, end: c)
  let subpath = svg_path.assert_subpath([first, zero, second])

  assert subpath |> svg_path.clean_subpath |> svg_path.segments
    == [first, second]
}

pub fn clean_subpath_keeps_single_zero_length_line_test() {
  let a = svg_path.point(0.0, 0.0)
  let zero = svg_path.line(start: a, end: a)
  let subpath = svg_path.assert_subpath([zero])

  assert subpath |> svg_path.clean_subpath |> svg_path.segments == [zero]
}

pub fn clean_subpath_reduces_multiple_zero_length_lines_to_one_test() {
  let a = svg_path.point(0.0, 0.0)
  let zero = svg_path.line(start: a, end: a)
  let subpath = svg_path.assert_subpath([zero, zero])

  assert subpath |> svg_path.clean_subpath |> svg_path.segments == [zero]
}

pub fn clean_subpath_preserves_closed_state_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: a),
      svg_path.line(start: a, end: a),
    ])
    |> svg_path.assert_close

  let cleaned = svg_path.clean_subpath(subpath)

  assert svg_path.is_closed(cleaned)
  assert svg_path.segments(cleaned)
    == [
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: a),
    ]
}

pub fn segment_arcs_to_bezier_preserves_lines_test() {
  let start = svg_path.point(0.0, 0.0)
  let end = svg_path.point(9.0, 0.0)
  let line = svg_path.line(start:, end:)

  assert svg_path.segment_arcs_to_bezier(line) == [line]
}

pub fn segment_to_cubic_beziers_converts_line_exactly_test() {
  let start = svg_path.point(0.0, 0.0)
  let end = svg_path.point(9.0, 0.0)

  assert svg_path.segment_to_cubic_beziers(svg_path.line(start:, end:))
    == [
      svg_path.cubic_bezier(
        start:,
        control1: svg_path.point(3.0, 0.0),
        control2: svg_path.point(6.0, 0.0),
        end:,
      ),
    ]
}

pub fn segment_arcs_to_bezier_preserves_quadratics_test() {
  let start = svg_path.point(0.0, 0.0)
  let control = svg_path.point(3.0, 6.0)
  let end = svg_path.point(9.0, 0.0)
  let quadratic = svg_path.quadratic_bezier(start:, control:, end:)

  assert svg_path.segment_arcs_to_bezier(quadratic) == [quadratic]
}

pub fn segment_arcs_to_bezier_preserves_cubics_test() {
  let start = svg_path.point(0.0, 0.0)
  let control1 = svg_path.point(2.0, 4.0)
  let control2 = svg_path.point(5.0, 4.0)
  let end = svg_path.point(9.0, 0.0)
  let cubic = svg_path.cubic_bezier(start:, control1:, control2:, end:)

  assert svg_path.segment_arcs_to_bezier(cubic) == [cubic]
}

pub fn segment_to_cubic_beziers_converts_quadratic_exactly_test() {
  let start = svg_path.point(0.0, 0.0)
  let control = svg_path.point(3.0, 6.0)
  let end = svg_path.point(9.0, 0.0)

  assert svg_path.segment_to_cubic_beziers(svg_path.quadratic_bezier(
      start:,
      control:,
      end:,
    ))
    == [
      svg_path.cubic_bezier(
        start:,
        control1: svg_path.point(2.0, 4.0),
        control2: svg_path.point(5.0, 4.0),
        end:,
      ),
    ]
}

pub fn segment_arcs_to_bezier_splits_half_turn_into_two_cubics_test() {
  let start = svg_path.point(0.0, 0.0)
  let end = svg_path.point(20.0, 0.0)
  let cubics =
    svg_path.segment_arcs_to_bezier(svg_path.arc(
      start:,
      radius: svg_path.point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end:,
    ))

  assert list.length(cubics) == 2
  assert svg_path.segment_start(list.first(cubics) |> unwrap_segment) == start
  assert svg_path.segment_end(list.last(cubics) |> unwrap_segment) == end
  assert all_cubic(cubics)
  assert continuous_segments(cubics)
}

pub fn segment_arcs_to_bezier_large_arc_uses_more_than_two_cubics_test() {
  let start = svg_path.point(0.0, 0.0)
  let end = svg_path.point(10.0, 10.0)
  let cubics =
    svg_path.segment_arcs_to_bezier(svg_path.arc(
      start:,
      radius: svg_path.point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: True,
      sweep: True,
      end:,
    ))

  assert list.length(cubics) > 2
  assert all_cubic(cubics)
  assert continuous_segments(cubics)
}

pub fn segment_arcs_to_bezier_degenerate_arc_falls_back_to_line_cubic_test() {
  let start = svg_path.point(0.0, 0.0)
  let end = svg_path.point(9.0, 0.0)

  assert svg_path.segment_arcs_to_bezier(svg_path.arc(
      start:,
      radius: svg_path.point(0.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end:,
    ))
    == [
      svg_path.cubic_bezier(
        start:,
        control1: svg_path.point(3.0, 0.0),
        control2: svg_path.point(6.0, 0.0),
        end:,
      ),
    ]
}

pub fn subpath_arcs_to_bezier_preserves_closed_state_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: a),
    ])
    |> svg_path.assert_close

  let converted = svg_path.subpath_arcs_to_bezier(subpath)

  assert svg_path.is_closed(converted)
  assert svg_path.segments(converted) == svg_path.segments(subpath)
}

pub fn subpath_arcs_to_bezier_replaces_only_arcs_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let line = svg_path.line(start: a, end: b)
  let arc =
    svg_path.arc(
      start: b,
      radius: svg_path.point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: c,
    )
  let quadratic = svg_path.quadratic_bezier(start: c, control: c, end: d)
  let subpath = svg_path.assert_subpath([line, arc, quadratic])

  let converted = svg_path.subpath_arcs_to_bezier(subpath)

  assert svg_path.segment_start(
      list.first(svg_path.segments(converted)) |> unwrap_segment,
    )
    == a
  assert svg_path.segment_end(
      list.last(svg_path.segments(converted)) |> unwrap_segment,
    )
    == d
  assert no_arcs(svg_path.segments(converted))
  assert contains_line(svg_path.segments(converted), line)
  assert contains_quadratic(svg_path.segments(converted), quadratic)
  assert continuous_segments(svg_path.segments(converted))
}

pub fn subpath_to_cubic_beziers_preserves_closed_state_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: a),
    ])
    |> svg_path.assert_close

  let converted = svg_path.subpath_to_cubic_beziers(subpath)

  assert svg_path.is_closed(converted)
  assert all_cubic(svg_path.segments(converted))
}

pub fn path_arcs_to_bezier_converts_each_subpath_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let first =
    svg_path.assert_subpath([
      svg_path.arc(
        start: a,
        radius: svg_path.point(5.0, 5.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: b,
      ),
    ])
  let second = svg_path.assert_subpath([svg_path.line(start: c, end: d)])

  let converted = svg_path.path_arcs_to_bezier(svg_path.path([first, second]))
  let segments =
    converted
    |> svg_path.subpaths
    |> list.flat_map(svg_path.segments)

  assert no_arcs(segments)
  assert contains_line(segments, svg_path.line(start: c, end: d))
}

pub fn path_to_cubic_beziers_converts_each_subpath_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let first = svg_path.assert_subpath([svg_path.line(start: a, end: b)])
  let second = svg_path.assert_subpath([svg_path.line(start: c, end: d)])

  let converted = svg_path.path_to_cubic_beziers(svg_path.path([first, second]))
  let segments =
    converted
    |> svg_path.subpaths
    |> list.flat_map(svg_path.segments)

  assert all_cubic(segments)
}

pub fn wiggle_subpath_rejects_gaps_beyond_tolerance_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.1, 0.0)
  let d = svg_path.point(20.0, 0.0)

  assert svg_path.wiggle_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: c, end: d),
    ])
    == Error(svg_path.NotCloseEnough(
      expected: b,
      got: c,
      tolerance: 0.000000001,
    ))
}

pub fn wiggle_subpath_rejects_misaligned_vertical_lines_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(0.0, 10.0)
  let c = svg_path.point(0.0000000001, 10.0000000001)
  let d = svg_path.point(0.0000000001, 20.0)

  assert svg_path.wiggle_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: c, end: d),
    ])
    == Error(svg_path.IncompatibleVerticalWiggle(previous_end: b, next_start: c))
}

pub fn wiggle_subpath_rejects_misaligned_horizontal_lines_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0000000001, 0.0000000001)
  let d = svg_path.point(20.0, 0.0000000001)

  assert svg_path.wiggle_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: c, end: d),
    ])
    == Error(svg_path.IncompatibleHorizontalWiggle(
      previous_end: b,
      next_start: c,
    ))
}

pub fn force_append_bridges_a_gap_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let assert Ok(subpath) =
    svg_path.empty_subpath()
    |> svg_path.append(svg_path.line(start: a, end: b))
    |> result_try_force_append(svg_path.line(start: c, end: d))

  assert subpath |> svg_path.segments |> list.length == 3
  assert svg_path.end(subpath) == Ok(d)
}

pub fn force_close_appends_a_final_line_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0, 10.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
    ])
    |> result_try_force_close

  assert svg_path.is_closed(subpath)
  assert subpath |> svg_path.segments |> list.length == 3
  assert svg_path.end(subpath) == Ok(a)
}

pub fn close_empty_subpath_errors_test() {
  assert svg_path.close(svg_path.empty_subpath())
    == Error(svg_path.EmptySubpath)
}

pub fn assert_close_closes_matching_endpoints_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: a),
    ])

  let closed = svg_path.assert_close(subpath)

  assert svg_path.is_closed(closed)
}

pub fn wiggle_close_replaces_nearby_endpoints_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let near_a = svg_path.point(0.0000000001, 0.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: near_a),
    ])
    |> result_try_wiggle_close

  assert svg_path.is_closed(subpath)
  assert svg_path.start(subpath) == svg_path.end(subpath)
}

pub fn wiggle_close_rejects_misaligned_vertical_lines_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(0.0, 10.0)
  let c = svg_path.point(0.0000000001, 0.0000000001)
  let d = svg_path.point(0.0000000001, 0.00000000005)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
      svg_path.line(start: c, end: d),
    ])

  assert svg_path.wiggle_close(subpath)
    == Error(svg_path.IncompatibleVerticalWiggle(previous_end: d, next_start: a))
}

pub fn wiggle_close_rejects_misaligned_horizontal_lines_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(0.0000000001, 0.0000000001)
  let d = svg_path.point(0.00000000005, 0.0000000001)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
      svg_path.line(start: c, end: d),
    ])

  assert svg_path.wiggle_close(subpath)
    == Error(svg_path.IncompatibleHorizontalWiggle(
      previous_end: d,
      next_start: a,
    ))
}

fn result_try_force_append(
  result_subpath: Result(svg_path.Subpath, svg_path.Error),
  segment: svg_path.Segment,
) -> Result(svg_path.Subpath, svg_path.Error) {
  case result_subpath {
    Ok(subpath) -> svg_path.force_append(subpath, segment)
    Error(error) -> Error(error)
  }
}

fn result_try_force_close(
  result_subpath: Result(svg_path.Subpath, svg_path.Error),
) -> Result(svg_path.Subpath, svg_path.Error) {
  case result_subpath {
    Ok(subpath) -> svg_path.force_close(subpath)
    Error(error) -> Error(error)
  }
}

fn result_try_wiggle_close(
  result_subpath: Result(svg_path.Subpath, svg_path.Error),
) -> Result(svg_path.Subpath, svg_path.Error) {
  case result_subpath {
    Ok(subpath) -> svg_path.wiggle_close(subpath)
    Error(error) -> Error(error)
  }
}

fn unwrap_segment(result: Result(svg_path.Segment, Nil)) -> svg_path.Segment {
  let assert Ok(segment) = result
  segment
}

fn all_cubic(segments: List(svg_path.Segment)) -> Bool {
  list.all(segments, fn(segment) {
    case segment {
      svg_path.CubicBezier(..) -> True
      _ -> False
    }
  })
}

fn no_arcs(segments: List(svg_path.Segment)) -> Bool {
  list.all(segments, fn(segment) {
    case segment {
      svg_path.Arc(..) -> False
      _ -> True
    }
  })
}

fn contains_line(
  segments: List(svg_path.Segment),
  line: svg_path.Segment,
) -> Bool {
  list.any(segments, fn(segment) { segment == line })
}

fn contains_quadratic(
  segments: List(svg_path.Segment),
  quadratic: svg_path.Segment,
) -> Bool {
  list.any(segments, fn(segment) { segment == quadratic })
}

fn continuous_segments(segments: List(svg_path.Segment)) -> Bool {
  case segments {
    [] | [_] -> True
    [first, second, ..rest] -> {
      svg_path.segment_end(first) == svg_path.segment_start(second)
      && continuous_segments([second, ..rest])
    }
  }
}
