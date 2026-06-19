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
