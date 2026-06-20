import gleam/float
import gleam/list
import gleeunit
import svg_path

const tolerance = 0.000001

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

pub fn reverse_segment_reverses_lines_quadratics_cubics_and_arcs_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)

  assert svg_path.reverse_segment(svg_path.line(start: a, end: b))
    == svg_path.line(start: b, end: a)
  assert svg_path.reverse_segment(svg_path.quadratic_bezier(
      start: a,
      control: b,
      end: c,
    ))
    == svg_path.quadratic_bezier(start: c, control: b, end: a)
  assert svg_path.reverse_segment(svg_path.cubic_bezier(
      start: a,
      control1: b,
      control2: c,
      end: d,
    ))
    == svg_path.cubic_bezier(start: d, control1: c, control2: b, end: a)
  assert svg_path.reverse_segment(svg_path.arc(
      start: a,
      radius: svg_path.point(4.0, 5.0),
      x_axis_rotation: 30.0,
      large_arc: True,
      sweep: False,
      end: b,
    ))
    == svg_path.arc(
      start: b,
      radius: svg_path.point(4.0, 5.0),
      x_axis_rotation: 30.0,
      large_arc: True,
      sweep: True,
      end: a,
    )
}

pub fn reverse_segment_swaps_start_and_end_test() {
  let segment =
    svg_path.cubic_bezier(
      start: svg_path.point(0.0, 0.0),
      control1: svg_path.point(1.0, 2.0),
      control2: svg_path.point(3.0, 4.0),
      end: svg_path.point(5.0, 6.0),
    )
  let reversed = svg_path.reverse_segment(segment)

  assert svg_path.segment_start(reversed) == svg_path.segment_end(segment)
  assert svg_path.segment_end(reversed) == svg_path.segment_start(segment)
}

pub fn segment_point_evaluates_lines_quadratics_cubics_and_arcs_test() {
  let assert Ok(line_point) =
    svg_path.segment_point(
      svg_path.line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 20.0),
      ),
      at: 0.5,
    )
  let assert Ok(quadratic_point) =
    svg_path.segment_point(
      svg_path.quadratic_bezier(
        start: svg_path.point(0.0, 0.0),
        control: svg_path.point(10.0, 20.0),
        end: svg_path.point(20.0, 0.0),
      ),
      at: 0.5,
    )
  let assert Ok(cubic_point) =
    svg_path.segment_point(
      svg_path.cubic_bezier(
        start: svg_path.point(0.0, 0.0),
        control1: svg_path.point(0.0, 30.0),
        control2: svg_path.point(30.0, 30.0),
        end: svg_path.point(30.0, 0.0),
      ),
      at: 0.5,
    )
  let assert Ok(arc_point) =
    svg_path.segment_point(
      svg_path.arc(
        start: svg_path.point(0.0, 0.0),
        radius: svg_path.point(10.0, 10.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.point(20.0, 0.0),
      ),
      at: 0.5,
    )

  assert point_near(line_point, svg_path.point(5.0, 10.0))
  assert point_near(quadratic_point, svg_path.point(10.0, 10.0))
  assert point_near(cubic_point, svg_path.point(15.0, 22.5))
  assert point_near(arc_point, svg_path.point(10.0, -10.0))
}

pub fn segment_derivative_evaluates_lines_quadratics_cubics_and_arcs_test() {
  let assert Ok(line_derivative) =
    svg_path.segment_derivative(
      svg_path.line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 20.0),
      ),
      at: 0.5,
    )
  let assert Ok(quadratic_derivative) =
    svg_path.segment_derivative(
      svg_path.quadratic_bezier(
        start: svg_path.point(0.0, 0.0),
        control: svg_path.point(10.0, 20.0),
        end: svg_path.point(20.0, 0.0),
      ),
      at: 0.5,
    )
  let assert Ok(cubic_derivative) =
    svg_path.segment_derivative(
      svg_path.cubic_bezier(
        start: svg_path.point(0.0, 0.0),
        control1: svg_path.point(0.0, 30.0),
        control2: svg_path.point(30.0, 30.0),
        end: svg_path.point(30.0, 0.0),
      ),
      at: 0.5,
    )
  let assert Ok(arc_derivative) =
    svg_path.segment_derivative(
      svg_path.arc(
        start: svg_path.point(0.0, 0.0),
        radius: svg_path.point(10.0, 10.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.point(20.0, 0.0),
      ),
      at: 0.5,
    )

  assert point_near(line_derivative, svg_path.point(10.0, 20.0))
  assert point_near(quadratic_derivative, svg_path.point(20.0, 0.0))
  assert point_near(cubic_derivative, svg_path.point(45.0, 0.0))
  assert arc_derivative.x >. 0.0
  assert near(arc_derivative.y, 0.0)
}

pub fn map_segment_points_maps_line_quadratic_and_cubic_defining_points_test() {
  let map = fn(point: svg_path.Point) {
    svg_path.point(point.x +. 1.0, point.y *. 2.0)
  }
  let assert Ok(line) =
    svg_path.map_segment_points(
      svg_path.line(
        start: svg_path.point(0.0, 1.0),
        end: svg_path.point(2.0, 3.0),
      ),
      with: map,
    )
  let assert Ok(quadratic) =
    svg_path.map_segment_points(
      svg_path.quadratic_bezier(
        start: svg_path.point(0.0, 1.0),
        control: svg_path.point(2.0, 3.0),
        end: svg_path.point(4.0, 5.0),
      ),
      with: map,
    )
  let assert Ok(cubic) =
    svg_path.map_segment_points(
      svg_path.cubic_bezier(
        start: svg_path.point(0.0, 1.0),
        control1: svg_path.point(2.0, 3.0),
        control2: svg_path.point(4.0, 5.0),
        end: svg_path.point(6.0, 7.0),
      ),
      with: map,
    )

  assert line
    == svg_path.line(
      start: svg_path.point(1.0, 2.0),
      end: svg_path.point(3.0, 6.0),
    )
  assert quadratic
    == svg_path.quadratic_bezier(
      start: svg_path.point(1.0, 2.0),
      control: svg_path.point(3.0, 6.0),
      end: svg_path.point(5.0, 10.0),
    )
  assert cubic
    == svg_path.cubic_bezier(
      start: svg_path.point(1.0, 2.0),
      control1: svg_path.point(3.0, 6.0),
      control2: svg_path.point(5.0, 10.0),
      end: svg_path.point(7.0, 14.0),
    )
}

pub fn map_segment_points_rejects_arcs_test() {
  let segment =
    svg_path.arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(20.0, 0.0),
    )

  assert svg_path.map_segment_points(segment, with: fn(point) { point })
    == Error(svg_path.CannotMapArcNonlinearly)
}

pub fn map_subpath_points_maps_segments_and_preserves_closed_state_test() {
  let map = fn(point: svg_path.Point) {
    svg_path.point(point.x +. 1.0, point.y *. 2.0)
  }
  let subpath =
    svg_path.assert_subpath([
      svg_path.line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 0.0),
      ),
      svg_path.quadratic_bezier(
        start: svg_path.point(10.0, 0.0),
        control: svg_path.point(15.0, 5.0),
        end: svg_path.point(0.0, 0.0),
      ),
    ])
    |> svg_path.assert_set_closed(closed: True)

  let assert Ok(mapped) = svg_path.map_subpath_points(subpath, with: map)

  assert svg_path.is_closed(mapped)
  assert svg_path.segments(mapped)
    == [
      svg_path.line(
        start: svg_path.point(1.0, 0.0),
        end: svg_path.point(11.0, 0.0),
      ),
      svg_path.quadratic_bezier(
        start: svg_path.point(11.0, 0.0),
        control: svg_path.point(16.0, 10.0),
        end: svg_path.point(1.0, 0.0),
      ),
    ]
}

pub fn map_subpath_points_maps_empty_subpath_test() {
  let assert Ok(mapped) =
    svg_path.map_subpath_points(svg_path.empty_subpath(), with: fn(point) {
      svg_path.point(point.x +. 1.0, point.y +. 1.0)
    })

  assert svg_path.segments(mapped) == []
  assert !svg_path.is_closed(mapped)
}

pub fn map_subpath_points_rejects_arcs_test() {
  let subpath =
    svg_path.assert_subpath([
      svg_path.arc(
        start: svg_path.point(0.0, 0.0),
        radius: svg_path.point(10.0, 10.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.point(20.0, 0.0),
      ),
    ])

  assert svg_path.map_subpath_points(subpath, with: fn(point) { point })
    == Error(svg_path.CannotMapArcNonlinearly)
}

pub fn map_path_points_maps_each_subpath_test() {
  let map = fn(point: svg_path.Point) {
    svg_path.point(point.x +. 1.0, point.y +. 1.0)
  }
  let first =
    svg_path.assert_subpath([
      svg_path.line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 0.0),
      ),
    ])
  let second =
    svg_path.assert_subpath([
      svg_path.cubic_bezier(
        start: svg_path.point(10.0, 0.0),
        control1: svg_path.point(15.0, 5.0),
        control2: svg_path.point(20.0, 5.0),
        end: svg_path.point(25.0, 0.0),
      ),
    ])
  let path = svg_path.path([first, second])

  let assert Ok(mapped) = svg_path.map_path_points(path, with: map)
  let assert [mapped_first, mapped_second] = svg_path.subpaths(mapped)

  assert svg_path.segments(mapped_first)
    == [
      svg_path.line(
        start: svg_path.point(1.0, 1.0),
        end: svg_path.point(11.0, 1.0),
      ),
    ]
  assert svg_path.segments(mapped_second)
    == [
      svg_path.cubic_bezier(
        start: svg_path.point(11.0, 1.0),
        control1: svg_path.point(16.0, 6.0),
        control2: svg_path.point(21.0, 6.0),
        end: svg_path.point(26.0, 1.0),
      ),
    ]
}

pub fn map_path_points_rejects_arcs_test() {
  let subpath =
    svg_path.assert_subpath([
      svg_path.arc(
        start: svg_path.point(0.0, 0.0),
        radius: svg_path.point(10.0, 10.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.point(20.0, 0.0),
      ),
    ])
  let path = svg_path.path([svg_path.empty_subpath(), subpath])

  assert svg_path.map_path_points(path, with: fn(point) { point })
    == Error(svg_path.CannotMapArcNonlinearly)
}

pub fn reverse_subpath_reverses_segment_order_and_preserves_closed_state_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let first = svg_path.line(start: a, end: b)
  let second = svg_path.line(start: b, end: c)
  let third = svg_path.line(start: c, end: a)
  let subpath =
    svg_path.assert_subpath([first, second, third])
    |> svg_path.assert_set_closed(closed: True)

  let reversed = svg_path.reverse_subpath(subpath)

  assert svg_path.is_closed(reversed)
  assert svg_path.segments(reversed)
    == [
      svg_path.reverse_segment(third),
      svg_path.reverse_segment(second),
      svg_path.reverse_segment(first),
    ]
}

pub fn reverse_subpath_preserves_empty_open_subpath_test() {
  assert svg_path.reverse_subpath(svg_path.empty_subpath())
    == svg_path.empty_subpath()
}

pub fn reverse_path_reverses_subpaths_and_their_segments_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let first =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
    ])
  let second =
    svg_path.assert_subpath([
      svg_path.line(start: c, end: d),
    ])
  let path = svg_path.path([first, second])

  let reversed = svg_path.reverse_path(path)
  let assert [reversed_second, reversed_first] = svg_path.subpaths(reversed)

  assert svg_path.segments(reversed_second)
    == svg_path.segments(svg_path.reverse_subpath(second))
  assert svg_path.segments(reversed_first)
    == svg_path.segments(svg_path.reverse_subpath(first))
}

pub fn segment_point_and_split_extrapolate_outside_t_test() {
  let segment =
    svg_path.line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 20.0),
    )
  let assert Ok(point) = svg_path.segment_point(segment, at: -0.5)
  let assert Ok(#(before, through_end)) =
    svg_path.split_segment(segment, at: -0.5)

  assert point_near(point, svg_path.point(-5.0, -10.0))
  assert point_near(svg_path.segment_start(before), svg_path.point(0.0, 0.0))
  assert point_near(svg_path.segment_end(before), svg_path.point(-5.0, -10.0))
  assert point_near(
    svg_path.segment_start(through_end),
    svg_path.point(-5.0, -10.0),
  )
  assert point_near(
    svg_path.segment_end(through_end),
    svg_path.point(10.0, 20.0),
  )
}

pub fn split_segment_divides_quadratic_test() {
  let segment =
    svg_path.quadratic_bezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(10.0, 20.0),
      end: svg_path.point(20.0, 0.0),
    )
  let assert Ok(#(left, right)) = svg_path.split_segment(segment, at: 0.25)
  let assert svg_path.QuadraticBezier(
    start: left_start,
    control: left_control,
    end: split,
  ) = left
  let assert svg_path.QuadraticBezier(
    start: right_start,
    control: right_control,
    end: right_end,
  ) = right

  assert point_near(left_start, svg_path.point(0.0, 0.0))
  assert point_near(left_control, svg_path.point(2.5, 5.0))
  assert point_near(split, svg_path.point(5.0, 7.5))
  assert point_near(right_start, split)
  assert point_near(right_control, svg_path.point(12.5, 15.0))
  assert point_near(right_end, svg_path.point(20.0, 0.0))
}

pub fn split_segment_divides_arc_test() {
  let segment =
    svg_path.arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(20.0, 0.0),
    )
  let assert Ok(#(left, right)) = svg_path.split_segment(segment, at: 0.5)

  assert point_near(svg_path.segment_start(left), svg_path.point(0.0, 0.0))
  assert point_near(svg_path.segment_end(left), svg_path.point(10.0, -10.0))
  assert point_near(svg_path.segment_start(right), svg_path.point(10.0, -10.0))
  assert point_near(svg_path.segment_end(right), svg_path.point(20.0, 0.0))
}

pub fn split_segment_inside_rejects_outside_t_test() {
  let segment =
    svg_path.cubic_bezier(
      start: svg_path.point(0.0, 0.0),
      control1: svg_path.point(0.0, 30.0),
      control2: svg_path.point(30.0, 30.0),
      end: svg_path.point(30.0, 0.0),
    )

  assert svg_path.split_segment_inside(segment, at: -0.01)
    == Error(svg_path.SplitOutsideSegment)
  assert svg_path.split_segment_inside(segment, at: 1.01)
    == Error(svg_path.SplitOutsideSegment)
  let assert Ok(_) = svg_path.split_segment_inside(segment, at: 0.0)
  let assert Ok(_) = svg_path.split_segment_inside(segment, at: 1.0)
}

pub fn segment_eval_and_split_return_degenerate_arc_error_test() {
  let segment =
    svg_path.arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(0.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(20.0, 0.0),
    )

  assert svg_path.segment_point(segment, at: 0.5)
    == Error(svg_path.DegenerateArc)
  assert svg_path.segment_derivative(segment, at: 0.5)
    == Error(svg_path.DegenerateArc)
  assert svg_path.split_segment(segment, at: 0.5)
    == Error(svg_path.DegenerateArc)
}

pub fn path_can_be_built_from_empty_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let assert Ok(subpath) =
    svg_path.empty_subpath()
    |> svg_path.append_segment(svg_path.line(start: a, end: b))
  let path =
    svg_path.empty_path()
    |> svg_path.append_subpath(subpath)

  assert path |> svg_path.subpaths |> list.length == 1
  assert svg_path.from_subpath(subpath) |> svg_path.subpaths == [subpath]
}

pub fn path_start_and_end_use_first_and_last_nonempty_subpaths_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let first = svg_path.assert_subpath([svg_path.line(start: a, end: b)])
  let second = svg_path.assert_subpath([svg_path.line(start: c, end: d)])
  let path =
    svg_path.path([
      svg_path.empty_subpath(),
      first,
      svg_path.empty_subpath(),
      second,
      svg_path.empty_subpath(),
    ])

  assert svg_path.path_start(path) == Ok(a)
  assert svg_path.path_end(path) == Ok(d)
}

pub fn empty_path_has_no_start_or_end_test() {
  assert svg_path.path_start(svg_path.empty_path()) == Error(svg_path.EmptyPath)
  assert svg_path.path_end(svg_path.empty_path()) == Error(svg_path.EmptyPath)
}

pub fn path_with_only_empty_subpaths_has_no_start_or_end_test() {
  let path =
    svg_path.path([
      svg_path.empty_subpath(),
      svg_path.empty_subpath(),
    ])

  assert svg_path.path_start(path) == Error(svg_path.EmptySubpaths)
  assert svg_path.path_end(path) == Error(svg_path.EmptySubpaths)
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
    |> svg_path.append_segment(svg_path.line(start:, end:))

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
    == Error(svg_path.Discontinuous(
      previous_index: 0,
      next_index: 1,
      expected: b,
      got: c,
      distance: 10.0,
    ))
}

pub fn subpath_discontinuous_error_reports_later_segment_indices_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let e = svg_path.point(40.0, 0.0)
  let f = svg_path.point(50.0, 0.0)

  assert svg_path.subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
      svg_path.line(start: d, end: e),
      svg_path.line(start: e, end: f),
    ])
    == Error(svg_path.Discontinuous(
      previous_index: 1,
      next_index: 2,
      expected: c,
      got: d,
      distance: 10.0,
    ))
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

pub fn set_closed_false_clears_closed_state_without_changing_segments_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let segments = [
    svg_path.line(start: a, end: b),
    svg_path.line(start: b, end: a),
  ]
  let closed =
    svg_path.assert_subpath(segments)
    |> svg_path.assert_set_closed(closed: True)

  let assert Ok(opened) = svg_path.set_closed(closed, closed: False)

  assert !svg_path.is_closed(opened)
  assert svg_path.segments(opened) == segments
}

pub fn set_closed_false_accepts_open_and_empty_subpaths_test() {
  let empty = svg_path.empty_subpath()
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let open_subpath = svg_path.assert_subpath([svg_path.line(start: a, end: b)])

  assert svg_path.set_closed(empty, closed: False) == Ok(empty)
  assert svg_path.set_closed(open_subpath, closed: False) == Ok(open_subpath)
}

pub fn set_closed_false_opens_subpath_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let closed =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)

  let assert Ok(opened) = svg_path.set_closed(closed, closed: False)

  assert !svg_path.is_closed(opened)
  assert svg_path.segments(opened) == svg_path.segments(closed)
}

pub fn set_closed_true_closes_matching_subpath_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: a),
    ])

  let assert Ok(closed) = svg_path.set_closed(subpath, closed: True)

  assert svg_path.is_closed(closed)
}

pub fn set_closed_true_rejects_uncloseable_subpath_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0, 10.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
    ])

  assert svg_path.set_closed(subpath, closed: True)
    == Error(svg_path.Discontinuous(
      previous_index: 1,
      next_index: 0,
      expected: a,
      got: c,
      distance: 14.142135623730951,
    ))
}

pub fn set_closed_with_wiggle_true_reconciles_nearby_endpoints_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let near_a = svg_path.point(0.0000000001, 0.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: near_a),
    ])

  let assert Ok(closed) =
    svg_path.set_closed_with(subpath, closed: True, policy: svg_path.Wiggle)

  assert svg_path.is_closed(closed)
  assert svg_path.start(closed) == svg_path.end(closed)
}

pub fn set_closed_with_wiggle_false_opens_subpath_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let closed =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)

  let assert Ok(opened) =
    svg_path.set_closed_with(closed, closed: False, policy: svg_path.Wiggle)

  assert !svg_path.is_closed(opened)
}

pub fn append_segment_rejects_closed_subpath_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: a),
    ])
    |> result_try_set_closed_with_bridge

  assert svg_path.append_segment(subpath, svg_path.line(start: a, end: c))
    == Error(svg_path.AlreadyClosed)
}

pub fn subpath_with_wiggle_replaces_nearby_sequential_endpoints_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let near_b = svg_path.point(10.0000000001, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let assert Ok(subpath) =
    svg_path.subpath_with(
      [
        svg_path.line(start: a, end: b),
        svg_path.line(start: near_b, end: c),
      ],
      policy: svg_path.Wiggle,
    )

  let assert [first, second] = svg_path.segments(subpath)
  let overlap = svg_path.segment_end(first)

  assert svg_path.segment_start(first) == a
  assert svg_path.segment_start(second) == overlap
  assert svg_path.segment_end(second) == c
  assert overlap != b
  assert overlap != near_b
}

pub fn subpath_with_wiggle_accepts_empty_and_single_segment_inputs_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let line = svg_path.line(start: a, end: b)

  assert svg_path.subpath_with([], policy: svg_path.Wiggle)
    == Ok(svg_path.empty_subpath())
  let assert Ok(subpath) =
    svg_path.subpath_with([line], policy: svg_path.Wiggle)
  assert svg_path.segments(subpath) == [line]
}

pub fn subpath_with_wiggle_then_line_prefers_wiggle_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let near_b = svg_path.point(10.0000000001, 0.0)
  let c = svg_path.point(20.0, 0.0)

  let assert Ok(subpath) =
    svg_path.subpath_with(
      [
        svg_path.line(start: a, end: b),
        svg_path.line(start: near_b, end: c),
      ],
      policy: svg_path.WiggleThenBridge,
    )

  assert subpath |> svg_path.segments |> list.length == 2
  assert continuous_segments(svg_path.segments(subpath))
}

pub fn subpath_with_wiggle_then_line_falls_back_to_bridge_line_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)

  let assert Ok(subpath) =
    svg_path.subpath_with(
      [
        svg_path.line(start: a, end: b),
        svg_path.line(start: c, end: d),
      ],
      policy: svg_path.WiggleThenBridge,
    )

  assert svg_path.segments(subpath)
    == [
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
      svg_path.line(start: c, end: d),
    ]
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
    |> svg_path.assert_set_closed(closed: True)

  let cleaned = svg_path.clean_subpath(subpath)

  assert svg_path.is_closed(cleaned)
  assert svg_path.segments(cleaned)
    == [
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: a),
    ]
}

pub fn splice_replaces_segment_range_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let e = svg_path.point(40.0, 0.0)
  let first = svg_path.line(start: a, end: b)
  let replacement = svg_path.line(start: b, end: d)
  let last = svg_path.line(start: d, end: e)
  let subpath =
    svg_path.assert_subpath([
      first,
      svg_path.line(start: b, end: c),
      svg_path.line(start: c, end: d),
      last,
    ])

  let assert Ok(spliced) =
    svg_path.splice(subpath, start: 1, delete: 2, insert: [replacement])

  assert svg_path.segments(spliced) == [first, replacement, last]
}

pub fn splice_inserts_without_deleting_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let first = svg_path.line(start: a, end: b)
  let inserted = svg_path.line(start: b, end: c)
  let subpath = svg_path.assert_subpath([first])

  let assert Ok(spliced) =
    svg_path.splice(subpath, start: 1, delete: 0, insert: [inserted])

  assert svg_path.segments(spliced) == [first, inserted]
}

pub fn splice_deletes_through_end_when_delete_is_too_large_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let first = svg_path.line(start: a, end: b)
  let subpath =
    svg_path.assert_subpath([
      first,
      svg_path.line(start: b, end: c),
    ])

  let assert Ok(spliced) =
    svg_path.splice(subpath, start: 1, delete: 99, insert: [])

  assert svg_path.segments(spliced) == [first]
}

pub fn splice_rejects_invalid_bounds_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let subpath = svg_path.assert_subpath([svg_path.line(start: a, end: b)])

  assert svg_path.splice(subpath, start: -1, delete: 0, insert: [])
    == Error(svg_path.InvalidSplice(start: -1, delete: 0, length: 1))
  assert svg_path.splice(subpath, start: 2, delete: 0, insert: [])
    == Error(svg_path.InvalidSplice(start: 2, delete: 0, length: 1))
  assert svg_path.splice(subpath, start: 0, delete: -1, insert: [])
    == Error(svg_path.InvalidSplice(start: 0, delete: -1, length: 1))
}

pub fn splice_rejects_discontinuous_result_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
    ])

  assert svg_path.splice(subpath, start: 1, delete: 1, insert: [
      svg_path.line(start: d, end: c),
    ])
    == Error(svg_path.Discontinuous(
      previous_index: 0,
      next_index: 1,
      expected: b,
      got: d,
      distance: 20.0,
    ))
}

pub fn splice_with_wiggle_reconciles_tiny_endpoint_gaps_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let near_b = svg_path.point(10.0000000001, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
    ])

  let assert Error(svg_path.Discontinuous(
    previous_index: 0,
    next_index: 1,
    expected:,
    got:,
    distance:,
  )) =
    svg_path.splice(subpath, start: 1, delete: 1, insert: [
      svg_path.line(start: near_b, end: c),
    ])
  assert expected == b
  assert got == near_b
  assert distance <. 0.000000001

  let assert Ok(spliced) =
    svg_path.splice_with(
      subpath,
      start: 1,
      delete: 1,
      insert: [
        svg_path.line(start: near_b, end: c),
      ],
      policy: svg_path.Wiggle,
    )

  assert svg_path.end(spliced) == Ok(c)
  assert continuous_segments(svg_path.segments(spliced))
}

pub fn splice_with_wiggle_preserves_closed_state_with_tiny_endpoint_gap_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let near_a = svg_path.point(0.0000000001, 0.0)
  let closed =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
      svg_path.line(start: c, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)

  let assert Ok(spliced) =
    svg_path.splice_with(
      closed,
      start: 2,
      delete: 1,
      insert: [
        svg_path.line(start: c, end: near_a),
      ],
      policy: svg_path.Wiggle,
    )

  assert svg_path.is_closed(spliced)
  assert svg_path.start(spliced) == svg_path.end(spliced)
}

pub fn splice_with_wiggle_reuses_splice_bounds_errors_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let subpath = svg_path.assert_subpath([svg_path.line(start: a, end: b)])

  assert svg_path.splice_with(
      subpath,
      start: 2,
      delete: 0,
      insert: [],
      policy: svg_path.Wiggle,
    )
    == Error(svg_path.InvalidSplice(start: 2, delete: 0, length: 1))
}

pub fn splice_preserves_closed_state_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let closed =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
      svg_path.line(start: c, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)
  let replacement = svg_path.line(start: b, end: c)

  let assert Ok(spliced) =
    svg_path.splice(closed, start: 1, delete: 1, insert: [replacement])

  assert svg_path.is_closed(spliced)
}

pub fn splice_rejects_closed_empty_result_test() {
  let a = svg_path.point(0.0, 0.0)
  let closed =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)

  assert svg_path.splice(closed, start: 0, delete: 1, insert: [])
    == Error(svg_path.ClosedEmptySubpath)
}

pub fn segment_arcs_to_cubic_beziers_preserves_lines_test() {
  let start = svg_path.point(0.0, 0.0)
  let end = svg_path.point(9.0, 0.0)
  let line = svg_path.line(start:, end:)

  assert svg_path.segment_arcs_to_cubic_beziers(line) == [line]
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

pub fn segment_arcs_to_cubic_beziers_preserves_quadratics_test() {
  let start = svg_path.point(0.0, 0.0)
  let control = svg_path.point(3.0, 6.0)
  let end = svg_path.point(9.0, 0.0)
  let quadratic = svg_path.quadratic_bezier(start:, control:, end:)

  assert svg_path.segment_arcs_to_cubic_beziers(quadratic) == [quadratic]
}

pub fn segment_arcs_to_cubic_beziers_preserves_cubics_test() {
  let start = svg_path.point(0.0, 0.0)
  let control1 = svg_path.point(2.0, 4.0)
  let control2 = svg_path.point(5.0, 4.0)
  let end = svg_path.point(9.0, 0.0)
  let cubic = svg_path.cubic_bezier(start:, control1:, control2:, end:)

  assert svg_path.segment_arcs_to_cubic_beziers(cubic) == [cubic]
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

pub fn segment_arcs_to_cubic_beziers_splits_half_turn_into_two_cubics_test() {
  let start = svg_path.point(0.0, 0.0)
  let end = svg_path.point(20.0, 0.0)
  let cubics =
    svg_path.segment_arcs_to_cubic_beziers(svg_path.arc(
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

pub fn segment_arcs_to_cubic_beziers_large_arc_uses_more_than_two_cubics_test() {
  let start = svg_path.point(0.0, 0.0)
  let end = svg_path.point(10.0, 10.0)
  let cubics =
    svg_path.segment_arcs_to_cubic_beziers(svg_path.arc(
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

pub fn segment_arcs_to_cubic_beziers_degenerate_arc_falls_back_to_line_cubic_test() {
  let start = svg_path.point(0.0, 0.0)
  let end = svg_path.point(9.0, 0.0)

  assert svg_path.segment_arcs_to_cubic_beziers(svg_path.arc(
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

pub fn subpath_arcs_to_cubic_beziers_preserves_closed_state_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)

  let converted = svg_path.subpath_arcs_to_cubic_beziers(subpath)

  assert svg_path.is_closed(converted)
  assert svg_path.segments(converted) == svg_path.segments(subpath)
}

pub fn subpath_arcs_to_cubic_beziers_replaces_only_arcs_test() {
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

  let converted = svg_path.subpath_arcs_to_cubic_beziers(subpath)

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
    |> svg_path.assert_set_closed(closed: True)

  let converted = svg_path.subpath_to_cubic_beziers(subpath)

  assert svg_path.is_closed(converted)
  assert all_cubic(svg_path.segments(converted))
}

pub fn path_arcs_to_cubic_beziers_converts_each_subpath_test() {
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

  let converted =
    svg_path.path_arcs_to_cubic_beziers(svg_path.path([first, second]))
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

pub fn subpath_with_wiggle_rejects_gaps_beyond_tolerance_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.1, 0.0)
  let d = svg_path.point(20.0, 0.0)

  assert svg_path.subpath_with(
      [
        svg_path.line(start: a, end: b),
        svg_path.line(start: c, end: d),
      ],
      policy: svg_path.Wiggle,
    )
    == Error(svg_path.NotCloseEnough(
      expected: b,
      got: c,
      tolerance: 0.000000001,
    ))
}

pub fn subpath_with_wiggle_rejects_misaligned_vertical_lines_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(0.0, 10.0)
  let c = svg_path.point(0.0000000001, 10.0000000001)
  let d = svg_path.point(0.0000000001, 20.0)

  assert svg_path.subpath_with(
      [
        svg_path.line(start: a, end: b),
        svg_path.line(start: c, end: d),
      ],
      policy: svg_path.Wiggle,
    )
    == Error(svg_path.IncompatibleVerticalWiggle(previous_end: b, next_start: c))
}

pub fn subpath_with_wiggle_rejects_misaligned_horizontal_lines_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0000000001, 0.0000000001)
  let d = svg_path.point(20.0, 0.0000000001)

  assert svg_path.subpath_with(
      [
        svg_path.line(start: a, end: b),
        svg_path.line(start: c, end: d),
      ],
      policy: svg_path.Wiggle,
    )
    == Error(svg_path.IncompatibleHorizontalWiggle(
      previous_end: b,
      next_start: c,
    ))
}

pub fn append_segment_discontinuous_error_reports_segment_indices_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let subpath = svg_path.assert_subpath([svg_path.line(start: a, end: b)])

  assert svg_path.append_segment(subpath, svg_path.line(start: c, end: d))
    == Error(svg_path.Discontinuous(
      previous_index: 0,
      next_index: 1,
      expected: b,
      got: c,
      distance: 10.0,
    ))
}

pub fn join_combines_open_subpaths_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let first = svg_path.assert_subpath([svg_path.line(start: a, end: b)])
  let second = svg_path.assert_subpath([svg_path.line(start: b, end: c)])
  let third = svg_path.assert_subpath([svg_path.line(start: c, end: d)])

  let assert Ok(joined) = svg_path.join([first, second, third])

  assert svg_path.segments(joined)
    == [
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
      svg_path.line(start: c, end: d),
    ]
}

pub fn join_treats_empty_open_subpaths_as_identity_values_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let subpath = svg_path.assert_subpath([svg_path.line(start: a, end: b)])
  let empty = svg_path.empty_subpath()

  assert svg_path.join([]) == Ok(empty)
  assert svg_path.join([empty, subpath]) == Ok(subpath)
  assert svg_path.join([subpath, empty]) == Ok(subpath)
  assert svg_path.join([empty, empty]) == Ok(empty)
}

pub fn join_treats_interleaved_empty_subpaths_as_identity_values_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let first = svg_path.assert_subpath([svg_path.line(start: a, end: b)])
  let second = svg_path.assert_subpath([svg_path.line(start: b, end: c)])
  let empty = svg_path.empty_subpath()

  let assert Ok(joined) = svg_path.join([empty, first, empty, second, empty])

  assert svg_path.segments(joined)
    == [
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
    ]
}

pub fn join_rejects_discontinuous_subpaths_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let first = svg_path.assert_subpath([svg_path.line(start: a, end: b)])
  let second = svg_path.assert_subpath([svg_path.line(start: c, end: d)])

  assert svg_path.join([first, second])
    == Error(svg_path.Discontinuous(
      previous_index: 0,
      next_index: 1,
      expected: b,
      got: c,
      distance: 10.0,
    ))
}

pub fn join_discontinuous_error_reports_flattened_segment_indices_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let e = svg_path.point(40.0, 0.0)
  let first =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
    ])
  let second = svg_path.assert_subpath([svg_path.line(start: d, end: e)])

  assert svg_path.join([first, second])
    == Error(svg_path.Discontinuous(
      previous_index: 1,
      next_index: 2,
      expected: c,
      got: d,
      distance: 10.0,
    ))
}

pub fn join_rejects_closed_inputs_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let open = svg_path.assert_subpath([svg_path.line(start: a, end: b)])
  let closed =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)

  assert svg_path.join([closed, open]) == Error(svg_path.AlreadyClosed)
  assert svg_path.join([open, closed]) == Error(svg_path.AlreadyClosed)
}

pub fn join_with_wiggle_reconciles_tiny_endpoint_gap_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let near_b = svg_path.point(10.0000000001, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let first = svg_path.assert_subpath([svg_path.line(start: a, end: b)])
  let second = svg_path.assert_subpath([svg_path.line(start: near_b, end: c)])

  let assert Ok(joined) =
    svg_path.join_with([first, second], policy: svg_path.Wiggle)

  assert svg_path.start(joined) == Ok(a)
  assert svg_path.end(joined) == Ok(c)
  assert continuous_segments(svg_path.segments(joined))
}

pub fn assert_join_with_wiggle_reconciles_tiny_endpoint_gap_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let near_b = svg_path.point(10.0000000001, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let first = svg_path.assert_subpath([svg_path.line(start: a, end: b)])
  let second = svg_path.assert_subpath([svg_path.line(start: near_b, end: c)])

  let joined =
    svg_path.assert_join_with([first, second], policy: svg_path.Wiggle)

  assert svg_path.start(joined) == Ok(a)
  assert svg_path.end(joined) == Ok(c)
  assert continuous_segments(svg_path.segments(joined))
}

pub fn join_with_wiggle_rejects_closed_inputs_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let open = svg_path.assert_subpath([svg_path.line(start: a, end: b)])
  let closed =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)

  assert svg_path.join_with([closed, open], policy: svg_path.Wiggle)
    == Error(svg_path.AlreadyClosed)
  assert svg_path.join_with([open, closed], policy: svg_path.Wiggle)
    == Error(svg_path.AlreadyClosed)
}

pub fn append_segment_with_line_bridges_a_gap_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let assert Ok(subpath) =
    svg_path.empty_subpath()
    |> svg_path.append_segment(svg_path.line(start: a, end: b))
    |> result_try_append_segment_with_line(svg_path.line(start: c, end: d))

  assert subpath |> svg_path.segments |> list.length == 3
  assert svg_path.end(subpath) == Ok(d)
}

pub fn join_with_line_bridges_a_gap_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(30.0, 0.0)
  let first = svg_path.assert_subpath([svg_path.line(start: a, end: b)])
  let second = svg_path.assert_subpath([svg_path.line(start: c, end: d)])

  let assert Ok(joined) =
    svg_path.join_with([first, second], policy: svg_path.Bridge)

  assert svg_path.segments(joined)
    == [
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
      svg_path.line(start: c, end: d),
    ]
}

pub fn join_with_line_rejects_closed_inputs_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let open = svg_path.assert_subpath([svg_path.line(start: a, end: b)])
  let closed =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)

  assert svg_path.join_with([closed, open], policy: svg_path.Bridge)
    == Error(svg_path.AlreadyClosed)
  assert svg_path.join_with([open, closed], policy: svg_path.Bridge)
    == Error(svg_path.AlreadyClosed)
}

pub fn set_closed_with_bridge_appends_a_final_line_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0, 10.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
    ])
    |> result_try_set_closed_with_bridge

  assert svg_path.is_closed(subpath)
  assert subpath |> svg_path.segments |> list.length == 3
  assert svg_path.end(subpath) == Ok(a)
}

pub fn set_closed_true_empty_subpath_errors_test() {
  assert svg_path.set_closed(svg_path.empty_subpath(), closed: True)
    == Error(svg_path.EmptySubpath)
}

pub fn set_closed_true_discontinuous_error_reports_last_to_first_indices_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(0.0, 10.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
    ])

  assert svg_path.set_closed(subpath, closed: True)
    == Error(svg_path.Discontinuous(
      previous_index: 1,
      next_index: 0,
      expected: a,
      got: c,
      distance: 10.0,
    ))
}

pub fn assert_set_closed_true_closes_matching_endpoints_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: a),
    ])

  let closed = svg_path.assert_set_closed(subpath, closed: True)

  assert svg_path.is_closed(closed)
}

pub fn set_closed_with_wiggle_replaces_nearby_endpoints_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let near_a = svg_path.point(0.0000000001, 0.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: near_a),
    ])
    |> result_try_set_closed_with_wiggle

  assert svg_path.is_closed(subpath)
  assert svg_path.start(subpath) == svg_path.end(subpath)
}

pub fn set_closed_with_wiggle_rejects_misaligned_vertical_lines_test() {
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

  assert svg_path.set_closed_with(
      subpath,
      closed: True,
      policy: svg_path.Wiggle,
    )
    == Error(svg_path.IncompatibleVerticalWiggle(previous_end: d, next_start: a))
}

pub fn set_closed_with_wiggle_rejects_misaligned_horizontal_lines_test() {
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

  assert svg_path.set_closed_with(
      subpath,
      closed: True,
      policy: svg_path.Wiggle,
    )
    == Error(svg_path.IncompatibleHorizontalWiggle(
      previous_end: d,
      next_start: a,
    ))
}

fn result_try_append_segment_with_line(
  result_subpath: Result(svg_path.Subpath, svg_path.Error),
  segment: svg_path.Segment,
) -> Result(svg_path.Subpath, svg_path.Error) {
  case result_subpath {
    Ok(subpath) ->
      svg_path.append_segment_with(subpath, segment, policy: svg_path.Bridge)
    Error(error) -> Error(error)
  }
}

fn result_try_set_closed_with_bridge(
  result_subpath: Result(svg_path.Subpath, svg_path.Error),
) -> Result(svg_path.Subpath, svg_path.Error) {
  case result_subpath {
    Ok(subpath) ->
      svg_path.set_closed_with(subpath, closed: True, policy: svg_path.Bridge)
    Error(error) -> Error(error)
  }
}

fn result_try_set_closed_with_wiggle(
  result_subpath: Result(svg_path.Subpath, svg_path.Error),
) -> Result(svg_path.Subpath, svg_path.Error) {
  case result_subpath {
    Ok(subpath) ->
      svg_path.set_closed_with(subpath, closed: True, policy: svg_path.Wiggle)
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

fn point_near(a: svg_path.Point, b: svg_path.Point) -> Bool {
  near(a.x, b.x) && near(a.y, b.y)
}

fn near(a: Float, b: Float) -> Bool {
  float.absolute_value(a -. b) <=. tolerance
}
