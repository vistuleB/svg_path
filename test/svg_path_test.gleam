import gleam/float
import gleam/int
import gleam/list
import gleeunit
import svg_path
import svg_path/ellipse

const tolerance = 0.000001

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn line_keeps_its_endpoints_test() {
  let start = svg_path.Point(0.0, 0.0)
  let end = svg_path.Point(10.0, 20.0)
  let segment = svg_path.Line(start:, end:)

  assert svg_path.segment_start(segment) == start
  assert svg_path.segment_end(segment) == end
}

pub fn reverse_segment_reverses_lines_quadratics_cubics_and_arcs_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)

  assert svg_path.segment_reverse(svg_path.Line(start: a, end: b))
    == svg_path.Line(start: b, end: a)
  assert svg_path.segment_reverse(svg_path.QuadraticBezier(
      start: a,
      control: b,
      end: c,
    ))
    == svg_path.QuadraticBezier(start: c, control: b, end: a)
  assert svg_path.segment_reverse(svg_path.CubicBezier(
      start: a,
      control1: b,
      control2: c,
      end: d,
    ))
    == svg_path.CubicBezier(start: d, control1: c, control2: b, end: a)
  assert svg_path.segment_reverse(svg_path.Arc(
      start: a,
      radius: svg_path.Point(4.0, 5.0),
      x_axis_rotation: 30.0,
      large_arc: True,
      sweep: False,
      end: b,
    ))
    == svg_path.Arc(
      start: b,
      radius: svg_path.Point(4.0, 5.0),
      x_axis_rotation: 30.0,
      large_arc: True,
      sweep: True,
      end: a,
    )
}

pub fn reverse_segment_swaps_start_and_end_test() {
  let segment =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(1.0, 2.0),
      control2: svg_path.Point(3.0, 4.0),
      end: svg_path.Point(5.0, 6.0),
    )
  let reversed = svg_path.segment_reverse(segment)

  assert svg_path.segment_start(reversed) == svg_path.segment_end(segment)
  assert svg_path.segment_end(reversed) == svg_path.segment_start(segment)
}

pub fn segment_point_evaluates_lines_quadratics_cubics_and_arcs_test() {
  let assert Ok(line_point) =
    svg_path.segment_point(
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 20.0),
      ),
      at: 0.5,
    )
  let assert Ok(quadratic_point) =
    svg_path.segment_point(
      svg_path.QuadraticBezier(
        start: svg_path.Point(0.0, 0.0),
        control: svg_path.Point(10.0, 20.0),
        end: svg_path.Point(20.0, 0.0),
      ),
      at: 0.5,
    )
  let assert Ok(cubic_point) =
    svg_path.segment_point(
      svg_path.CubicBezier(
        start: svg_path.Point(0.0, 0.0),
        control1: svg_path.Point(0.0, 30.0),
        control2: svg_path.Point(30.0, 30.0),
        end: svg_path.Point(30.0, 0.0),
      ),
      at: 0.5,
    )
  let assert Ok(arc_point) =
    svg_path.segment_point(
      svg_path.Arc(
        start: svg_path.Point(0.0, 0.0),
        radius: svg_path.Point(10.0, 10.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.Point(20.0, 0.0),
      ),
      at: 0.5,
    )

  assert point_near(line_point, svg_path.Point(5.0, 10.0))
  assert point_near(quadratic_point, svg_path.Point(10.0, 10.0))
  assert point_near(cubic_point, svg_path.Point(15.0, 22.5))
  assert point_near(arc_point, svg_path.Point(10.0, -10.0))
}

pub fn segment_derivative_evaluates_lines_quadratics_cubics_and_arcs_test() {
  let assert Ok(line_derivative) =
    svg_path.segment_derivative(
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 20.0),
      ),
      at: 0.5,
    )
  let assert Ok(quadratic_derivative) =
    svg_path.segment_derivative(
      svg_path.QuadraticBezier(
        start: svg_path.Point(0.0, 0.0),
        control: svg_path.Point(10.0, 20.0),
        end: svg_path.Point(20.0, 0.0),
      ),
      at: 0.5,
    )
  let assert Ok(cubic_derivative) =
    svg_path.segment_derivative(
      svg_path.CubicBezier(
        start: svg_path.Point(0.0, 0.0),
        control1: svg_path.Point(0.0, 30.0),
        control2: svg_path.Point(30.0, 30.0),
        end: svg_path.Point(30.0, 0.0),
      ),
      at: 0.5,
    )
  let assert Ok(arc_derivative) =
    svg_path.segment_derivative(
      svg_path.Arc(
        start: svg_path.Point(0.0, 0.0),
        radius: svg_path.Point(10.0, 10.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.Point(20.0, 0.0),
      ),
      at: 0.5,
    )

  assert point_near(line_derivative, svg_path.Point(10.0, 20.0))
  assert point_near(quadratic_derivative, svg_path.Point(20.0, 0.0))
  assert point_near(cubic_derivative, svg_path.Point(45.0, 0.0))
  assert arc_derivative.x >. 0.0
  assert near(arc_derivative.y, 0.0)
}

pub fn segment_bounding_box_handles_lines_beziers_and_arcs_test() {
  let assert Ok(line_box) =
    svg_path.segment_bounding_box(svg_path.Line(
      start: svg_path.Point(1.0, 2.0),
      end: svg_path.Point(5.0, -3.0),
    ))
  let assert Ok(quadratic_box) =
    svg_path.segment_bounding_box(svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.0),
      control: svg_path.Point(10.0, 10.0),
      end: svg_path.Point(20.0, 0.0),
    ))
  let assert Ok(cubic_box) =
    svg_path.segment_bounding_box(svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(0.0, 30.0),
      control2: svg_path.Point(30.0, 30.0),
      end: svg_path.Point(30.0, 0.0),
    ))
  let assert Ok(arc_box) =
    svg_path.segment_bounding_box(svg_path.Arc(
      start: svg_path.Point(0.0, 0.0),
      radius: svg_path.Point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(20.0, 0.0),
    ))

  assert bbox_near(
    line_box,
    min: svg_path.Point(1.0, -3.0),
    max: svg_path.Point(5.0, 2.0),
  )
  assert bbox_near(
    quadratic_box,
    min: svg_path.Point(0.0, 0.0),
    max: svg_path.Point(20.0, 5.0),
  )
  assert bbox_near(
    cubic_box,
    min: svg_path.Point(0.0, 0.0),
    max: svg_path.Point(30.0, 22.5),
  )
  assert bbox_near(
    arc_box,
    min: svg_path.Point(0.0, -10.0),
    max: svg_path.Point(20.0, 0.0),
  )
}

pub fn bounding_box_dimensions_use_extents_test() {
  let box =
    svg_path.BoundingBox(
      min: svg_path.Point(-2.0, 3.0),
      max: svg_path.Point(8.0, 15.0),
    )

  assert svg_path.bounding_box_width(box) == 10.0
  assert svg_path.bounding_box_height(box) == 12.0
  assert svg_path.bounding_box_center(box) == svg_path.Point(3.0, 9.0)
  assert svg_path.bounding_box_diameter(box) == 22.0
}

pub fn bounding_box_union_covers_both_boxes_test() {
  let first =
    svg_path.BoundingBox(
      min: svg_path.Point(2.0, -3.0),
      max: svg_path.Point(5.0, 4.0),
    )
  let second =
    svg_path.BoundingBox(
      min: svg_path.Point(-7.0, 6.0),
      max: svg_path.Point(-2.0, 9.0),
    )

  assert svg_path.bounding_box_union(first, second)
    == svg_path.BoundingBox(
      min: svg_path.Point(-7.0, -3.0),
      max: svg_path.Point(5.0, 9.0),
    )
}

pub fn bounding_box_union_many_covers_every_box_test() {
  let first =
    svg_path.BoundingBox(
      min: svg_path.Point(2.0, -3.0),
      max: svg_path.Point(5.0, 4.0),
    )
  let second =
    svg_path.BoundingBox(
      min: svg_path.Point(-7.0, 6.0),
      max: svg_path.Point(-2.0, 9.0),
    )
  let third =
    svg_path.BoundingBox(
      min: svg_path.Point(3.0, -8.0),
      max: svg_path.Point(4.0, -6.0),
    )

  assert svg_path.bounding_box_union_many([first, second, third])
    == Ok(svg_path.BoundingBox(
      min: svg_path.Point(-7.0, -8.0),
      max: svg_path.Point(5.0, 9.0),
    ))
}

pub fn bounding_box_union_many_returns_error_for_empty_lists_test() {
  assert svg_path.bounding_box_union_many([]) == Error(Nil)
}

pub fn points_bounding_box_covers_every_point_test() {
  assert svg_path.points_bounding_box([
      svg_path.Point(2.0, -3.0),
      svg_path.Point(-7.0, 6.0),
      svg_path.Point(4.0, -8.0),
    ])
    == Ok(svg_path.BoundingBox(
      min: svg_path.Point(-7.0, -8.0),
      max: svg_path.Point(4.0, 6.0),
    ))
}

pub fn points_bounding_box_returns_error_for_empty_lists_test() {
  assert svg_path.points_bounding_box([]) == Error(Nil)
}

pub fn segment_bounding_box_returns_degenerate_arc_errors_test() {
  let segment =
    svg_path.Arc(
      start: svg_path.Point(0.0, 0.0),
      radius: svg_path.Point(0.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(20.0, 0.0),
    )

  assert svg_path.segment_bounding_box(segment) == Error(svg_path.DegenerateArc)
}

pub fn arc_center_data_converts_arc_segments_test() {
  let segment =
    svg_path.Arc(
      start: svg_path.Point(0.0, 0.0),
      radius: svg_path.Point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(20.0, 0.0),
    )

  let assert Ok(arc) = svg_path.arc_center_data(segment)

  assert center_arc_data_near(
    arc,
    ellipse.CenterArcData(
      center: ellipse.EllipsePoint(10.0, 0.0),
      radius: ellipse.EllipsePoint(10.0, 10.0),
      x_axis_rotation: 0.0,
      start_angle: 180.0,
      delta_angle: 180.0,
    ),
  )
}

pub fn arc_center_data_rejects_non_arc_segments_test() {
  let segment =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(1.0, 0.0),
    )

  assert svg_path.arc_center_data(segment) == Error(svg_path.DegenerateArc)
}

pub fn arc_wrappers_use_root_points_test() {
  let segment =
    svg_path.Arc(
      start: svg_path.Point(0.0, 0.0),
      radius: svg_path.Point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(20.0, 0.0),
    )

  let assert Ok(point) = svg_path.arc_point(segment, at: 0.5)
  let assert Ok(derivative) = svg_path.arc_derivative(segment, at: 0.5)
  let assert Ok(angle_point) =
    svg_path.arc_point_at_angle(segment, angle: 270.0)
  let assert Ok(angle_derivative) =
    svg_path.arc_derivative_at_angle(segment, angle: 270.0)
  let assert Ok(angle) = svg_path.arc_angle_at(segment, t: 0.5)
  let assert Ok(end_angle) = svg_path.arc_end_angle(segment)

  assert point_near(point, svg_path.Point(10.0, -10.0))
  assert derivative.x >. 0.0
  assert near(derivative.y, 0.0)
  assert point_near(angle_point, svg_path.Point(10.0, -10.0))
  assert angle_derivative.x >. 0.0
  assert near(angle_derivative.y, 0.0)
  assert near(angle, 270.0)
  assert near(end_angle, 360.0)
}

pub fn arc_wrappers_reject_non_arc_segments_test() {
  let segment =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(1.0, 0.0),
    )

  assert svg_path.arc_point(segment, at: 0.5) == Error(svg_path.DegenerateArc)
  assert svg_path.arc_derivative(segment, at: 0.5)
    == Error(svg_path.DegenerateArc)
  assert svg_path.arc_point_at_angle(segment, angle: 0.0)
    == Error(svg_path.DegenerateArc)
  assert svg_path.arc_derivative_at_angle(segment, angle: 0.0)
    == Error(svg_path.DegenerateArc)
  assert svg_path.arc_angle_at(segment, t: 0.5) == Error(svg_path.DegenerateArc)
  assert svg_path.arc_end_angle(segment) == Error(svg_path.DegenerateArc)
}

pub fn map_segment_points_maps_line_quadratic_and_cubic_defining_points_test() {
  let map = fn(point: svg_path.Point) {
    svg_path.Point(point.x +. 1.0, point.y *. 2.0)
  }
  let assert Ok(line) =
    svg_path.segment_map_points(
      svg_path.Line(
        start: svg_path.Point(0.0, 1.0),
        end: svg_path.Point(2.0, 3.0),
      ),
      with: map,
    )
  let assert Ok(quadratic) =
    svg_path.segment_map_points(
      svg_path.QuadraticBezier(
        start: svg_path.Point(0.0, 1.0),
        control: svg_path.Point(2.0, 3.0),
        end: svg_path.Point(4.0, 5.0),
      ),
      with: map,
    )
  let assert Ok(cubic) =
    svg_path.segment_map_points(
      svg_path.CubicBezier(
        start: svg_path.Point(0.0, 1.0),
        control1: svg_path.Point(2.0, 3.0),
        control2: svg_path.Point(4.0, 5.0),
        end: svg_path.Point(6.0, 7.0),
      ),
      with: map,
    )

  assert line
    == svg_path.Line(
      start: svg_path.Point(1.0, 2.0),
      end: svg_path.Point(3.0, 6.0),
    )
  assert quadratic
    == svg_path.QuadraticBezier(
      start: svg_path.Point(1.0, 2.0),
      control: svg_path.Point(3.0, 6.0),
      end: svg_path.Point(5.0, 10.0),
    )
  assert cubic
    == svg_path.CubicBezier(
      start: svg_path.Point(1.0, 2.0),
      control1: svg_path.Point(3.0, 6.0),
      control2: svg_path.Point(5.0, 10.0),
      end: svg_path.Point(7.0, 14.0),
    )
}

pub fn map_segment_points_rejects_arcs_test() {
  let segment =
    svg_path.Arc(
      start: svg_path.Point(0.0, 0.0),
      radius: svg_path.Point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(20.0, 0.0),
    )

  assert svg_path.segment_map_points(segment, with: fn(point) { point })
    == Error(svg_path.CannotMapArcNonlinearly)
}

pub fn map_subpath_points_maps_segments_and_preserves_closed_state_test() {
  let map = fn(point: svg_path.Point) {
    svg_path.Point(point.x +. 1.0, point.y *. 2.0)
  }
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
      svg_path.QuadraticBezier(
        start: svg_path.Point(10.0, 0.0),
        control: svg_path.Point(15.0, 5.0),
        end: svg_path.Point(0.0, 0.0),
      ),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)

  let assert Ok(mapped) = svg_path.subpath_map_points(subpath, with: map)

  assert svg_path.subpath_is_closed(mapped)
  assert svg_path.subpath_segments(mapped)
    == [
      svg_path.Line(
        start: svg_path.Point(1.0, 0.0),
        end: svg_path.Point(11.0, 0.0),
      ),
      svg_path.QuadraticBezier(
        start: svg_path.Point(11.0, 0.0),
        control: svg_path.Point(16.0, 10.0),
        end: svg_path.Point(1.0, 0.0),
      ),
    ]
}

pub fn map_subpath_points_maps_empty_subpath_test() {
  let assert Ok(mapped) =
    svg_path.subpath_map_points(
      svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)),
      with: fn(point) { svg_path.Point(point.x +. 1.0, point.y +. 1.0) },
    )

  assert svg_path.subpath_segments(mapped) == []
  assert !svg_path.subpath_is_closed(mapped)
}

pub fn map_subpath_points_rejects_arcs_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Arc(
        start: svg_path.Point(0.0, 0.0),
        radius: svg_path.Point(10.0, 10.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.Point(20.0, 0.0),
      ),
    ])

  assert svg_path.subpath_map_points(subpath, with: fn(point) { point })
    == Error(svg_path.CannotMapArcNonlinearly)
}

pub fn map_path_points_maps_each_subpath_test() {
  let map = fn(point: svg_path.Point) {
    svg_path.Point(point.x +. 1.0, point.y +. 1.0)
  }
  let first =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
    ])
  let second =
    svg_path.subpath_assert([
      svg_path.CubicBezier(
        start: svg_path.Point(10.0, 0.0),
        control1: svg_path.Point(15.0, 5.0),
        control2: svg_path.Point(20.0, 5.0),
        end: svg_path.Point(25.0, 0.0),
      ),
    ])
  let path = svg_path.Path([first, second])

  let assert Ok(mapped) = svg_path.path_map_points(path, with: map)
  let assert [mapped_first, mapped_second] = svg_path.path_subpaths(mapped)

  assert svg_path.subpath_segments(mapped_first)
    == [
      svg_path.Line(
        start: svg_path.Point(1.0, 1.0),
        end: svg_path.Point(11.0, 1.0),
      ),
    ]
  assert svg_path.subpath_segments(mapped_second)
    == [
      svg_path.CubicBezier(
        start: svg_path.Point(11.0, 1.0),
        control1: svg_path.Point(16.0, 6.0),
        control2: svg_path.Point(21.0, 6.0),
        end: svg_path.Point(26.0, 1.0),
      ),
    ]
}

pub fn map_path_points_rejects_arcs_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Arc(
        start: svg_path.Point(0.0, 0.0),
        radius: svg_path.Point(10.0, 10.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.Point(20.0, 0.0),
      ),
    ])
  let path =
    svg_path.Path([
      svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)),
      subpath,
    ])

  assert svg_path.path_map_points(path, with: fn(point) { point })
    == Error(svg_path.CannotMapArcNonlinearly)
}

pub fn try_map_segment_points_maps_line_quadratic_and_cubic_defining_points_test() {
  let map = fn(point: svg_path.Point) {
    Ok(svg_path.Point(point.x +. 1.0, point.y *. 2.0))
  }

  let assert Ok(line) =
    svg_path.segment_try_map_points(
      svg_path.Line(
        start: svg_path.Point(0.0, 1.0),
        end: svg_path.Point(2.0, 3.0),
      ),
      with: map,
    )
  let assert Ok(quadratic) =
    svg_path.segment_try_map_points(
      svg_path.QuadraticBezier(
        start: svg_path.Point(0.0, 1.0),
        control: svg_path.Point(2.0, 3.0),
        end: svg_path.Point(4.0, 5.0),
      ),
      with: map,
    )
  let assert Ok(cubic) =
    svg_path.segment_try_map_points(
      svg_path.CubicBezier(
        start: svg_path.Point(0.0, 1.0),
        control1: svg_path.Point(2.0, 3.0),
        control2: svg_path.Point(4.0, 5.0),
        end: svg_path.Point(6.0, 7.0),
      ),
      with: map,
    )

  assert line
    == svg_path.Line(
      start: svg_path.Point(1.0, 2.0),
      end: svg_path.Point(3.0, 6.0),
    )
  assert quadratic
    == svg_path.QuadraticBezier(
      start: svg_path.Point(1.0, 2.0),
      control: svg_path.Point(3.0, 6.0),
      end: svg_path.Point(5.0, 10.0),
    )
  assert cubic
    == svg_path.CubicBezier(
      start: svg_path.Point(1.0, 2.0),
      control1: svg_path.Point(3.0, 6.0),
      control2: svg_path.Point(5.0, 10.0),
      end: svg_path.Point(7.0, 14.0),
    )
}

pub fn try_map_segment_points_returns_mapper_error_test() {
  let segment =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(1.0, 0.0),
    )

  assert svg_path.segment_try_map_points(segment, with: fn(_point) {
      Error("failed")
    })
    == Error(svg_path.PointMapFunctionError("failed"))
}

pub fn try_map_segment_points_rejects_arcs_test() {
  let segment =
    svg_path.Arc(
      start: svg_path.Point(0.0, 0.0),
      radius: svg_path.Point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(20.0, 0.0),
    )

  assert svg_path.segment_try_map_points(segment, with: fn(point) { Ok(point) })
    == Error(svg_path.PointMapPathError(svg_path.CannotMapArcNonlinearly))
}

pub fn try_map_path_points_maps_each_subpath_test() {
  let path =
    svg_path.Path([
      svg_path.subpath_assert([
        svg_path.Line(
          start: svg_path.Point(0.0, 0.0),
          end: svg_path.Point(10.0, 0.0),
        ),
      ]),
      svg_path.subpath_assert([
        svg_path.Line(
          start: svg_path.Point(1.0, 2.0),
          end: svg_path.Point(3.0, 4.0),
        ),
      ]),
    ])

  let assert Ok(mapped) =
    svg_path.path_try_map_points(path, with: fn(point) {
      Ok(svg_path.Point(point.x +. 1.0, point.y +. 1.0))
    })

  assert svg_path.path_subpaths(mapped)
    == [
      svg_path.subpath_assert([
        svg_path.Line(
          start: svg_path.Point(1.0, 1.0),
          end: svg_path.Point(11.0, 1.0),
        ),
      ]),
      svg_path.subpath_assert([
        svg_path.Line(
          start: svg_path.Point(2.0, 3.0),
          end: svg_path.Point(4.0, 5.0),
        ),
      ]),
    ]
}

pub fn reverse_subpath_reverses_segment_order_and_preserves_closed_state_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let first = svg_path.Line(start: a, end: b)
  let second = svg_path.Line(start: b, end: c)
  let third = svg_path.Line(start: c, end: a)
  let subpath =
    svg_path.subpath_assert([first, second, third])
    |> svg_path.subpath_assert_set_closed(closed: True)

  let reversed = svg_path.subpath_reverse(subpath)

  assert svg_path.subpath_is_closed(reversed)
  assert svg_path.subpath_segments(reversed)
    == [
      svg_path.segment_reverse(third),
      svg_path.segment_reverse(second),
      svg_path.segment_reverse(first),
    ]
}

pub fn reverse_subpath_preserves_empty_open_subpath_test() {
  assert svg_path.subpath_reverse(
      svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)),
    )
    == svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0))
}

pub fn reverse_path_reverses_subpaths_and_their_segments_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let first =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])
  let second =
    svg_path.subpath_assert([
      svg_path.Line(start: c, end: d),
    ])
  let path = svg_path.Path([first, second])

  let reversed = svg_path.path_reverse(path)
  let assert [reversed_second, reversed_first] =
    svg_path.path_subpaths(reversed)

  assert svg_path.subpath_segments(reversed_second)
    == svg_path.subpath_segments(svg_path.subpath_reverse(second))
  assert svg_path.subpath_segments(reversed_first)
    == svg_path.subpath_segments(svg_path.subpath_reverse(first))
}

pub fn segment_point_and_split_extrapolate_outside_t_test() {
  let segment =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 20.0),
    )
  let assert Ok(point) = svg_path.segment_point(segment, at: -0.5)
  let assert Ok(#(before, through_end)) =
    svg_path.segment_split(segment, at: -0.5)

  assert point_near(point, svg_path.Point(-5.0, -10.0))
  assert point_near(svg_path.segment_start(before), svg_path.Point(0.0, 0.0))
  assert point_near(svg_path.segment_end(before), svg_path.Point(-5.0, -10.0))
  assert point_near(
    svg_path.segment_start(through_end),
    svg_path.Point(-5.0, -10.0),
  )
  assert point_near(
    svg_path.segment_end(through_end),
    svg_path.Point(10.0, 20.0),
  )
}

pub fn split_segment_divides_quadratic_test() {
  let segment =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.0),
      control: svg_path.Point(10.0, 20.0),
      end: svg_path.Point(20.0, 0.0),
    )
  let assert Ok(#(left, right)) = svg_path.segment_split(segment, at: 0.25)
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

  assert point_near(left_start, svg_path.Point(0.0, 0.0))
  assert point_near(left_control, svg_path.Point(2.5, 5.0))
  assert point_near(split, svg_path.Point(5.0, 7.5))
  assert point_near(right_start, split)
  assert point_near(right_control, svg_path.Point(12.5, 15.0))
  assert point_near(right_end, svg_path.Point(20.0, 0.0))
}

pub fn split_segment_divides_arc_test() {
  let segment =
    svg_path.Arc(
      start: svg_path.Point(0.0, 0.0),
      radius: svg_path.Point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(20.0, 0.0),
    )
  let assert Ok(#(left, right)) = svg_path.segment_split(segment, at: 0.5)

  assert point_near(svg_path.segment_start(left), svg_path.Point(0.0, 0.0))
  assert point_near(svg_path.segment_end(left), svg_path.Point(10.0, -10.0))
  assert point_near(svg_path.segment_start(right), svg_path.Point(10.0, -10.0))
  assert point_near(svg_path.segment_end(right), svg_path.Point(20.0, 0.0))
}

pub fn split_segment_inside_rejects_outside_t_test() {
  let segment =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(0.0, 30.0),
      control2: svg_path.Point(30.0, 30.0),
      end: svg_path.Point(30.0, 0.0),
    )

  assert svg_path.segment_split_inside(segment, at: -0.01)
    == Error(svg_path.SplitOutsideSegment)
  assert svg_path.segment_split_inside(segment, at: 1.01)
    == Error(svg_path.SplitOutsideSegment)
  let assert Ok(_) = svg_path.segment_split_inside(segment, at: 0.0)
  let assert Ok(_) = svg_path.segment_split_inside(segment, at: 1.0)
}

pub fn segment_between_returns_segment_between_parameters_test() {
  let segment =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 20.0),
    )
  let assert Ok(segment_between) =
    svg_path.segment_between(segment, from: 0.25, to: 0.75)

  assert point_near(
    svg_path.segment_start(segment_between),
    svg_path.Point(2.5, 5.0),
  )
  assert point_near(
    svg_path.segment_end(segment_between),
    svg_path.Point(7.5, 15.0),
  )
}

pub fn segment_between_uses_exact_segment_point_endpoints_test() {
  let segment =
    svg_path.CubicBezier(
      start: svg_path.Point(25.0, 40.0),
      control1: svg_path.Point(155.0, 100.0),
      control2: svg_path.Point(155.0, 10.0),
      end: svg_path.Point(25.0, 70.0),
    )
  let assert Ok(segment_between) =
    svg_path.segment_between(segment, from: 0.123, to: 0.876)
  let assert Ok(start) = svg_path.segment_point(segment, at: 0.123)
  let assert Ok(end) = svg_path.segment_point(segment, at: 0.876)

  assert svg_path.segment_start(segment_between) == start
  assert svg_path.segment_end(segment_between) == end
}

pub fn segment_between_reverses_when_from_is_after_to_test() {
  let segment =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 20.0),
    )
  let assert Ok(segment_between) =
    svg_path.segment_between(segment, from: 0.75, to: 0.25)

  assert point_near(
    svg_path.segment_start(segment_between),
    svg_path.Point(7.5, 15.0),
  )
  assert point_near(
    svg_path.segment_end(segment_between),
    svg_path.Point(2.5, 5.0),
  )
}

pub fn segment_between_returns_degenerate_line_when_parameters_are_equal_test() {
  let segment =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.0),
      control: svg_path.Point(10.0, 20.0),
      end: svg_path.Point(20.0, 0.0),
    )
  let assert Ok(segment_between) =
    svg_path.segment_between(segment, from: 0.25, to: 0.25)

  assert point_near(
    svg_path.segment_start(segment_between),
    svg_path.Point(5.0, 7.5),
  )
  assert point_near(
    svg_path.segment_end(segment_between),
    svg_path.Point(5.0, 7.5),
  )
}

pub fn segment_between_inside_rejects_outside_t_test() {
  let segment =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 20.0),
    )

  assert svg_path.segment_between_inside(segment, from: -0.01, to: 0.5)
    == Error(svg_path.SplitOutsideSegment)
  assert svg_path.segment_between_inside(segment, from: 0.5, to: 1.01)
    == Error(svg_path.SplitOutsideSegment)
  let assert Ok(_) =
    svg_path.segment_between_inside(segment, from: 0.0, to: 1.0)
  let assert Ok(_) =
    svg_path.segment_between_inside(segment, from: 1.0, to: 0.0)
}

pub fn segment_between_extrapolates_outside_t_test() {
  let segment =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 20.0),
    )
  let assert Ok(segment_between) =
    svg_path.segment_between(segment, from: 1.0, to: 1.5)

  assert point_near(
    svg_path.segment_start(segment_between),
    svg_path.Point(10.0, 20.0),
  )
  assert point_near(
    svg_path.segment_end(segment_between),
    svg_path.Point(15.0, 30.0),
  )
}

pub fn segments_between_returns_segments_between_adjacent_parameters_test() {
  let segment =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 20.0),
    )
  let assert Ok([first, second]) =
    svg_path.segment_between_many(segment, between: [0.25, 0.75, 0.5])

  assert point_near(svg_path.segment_start(first), svg_path.Point(2.5, 5.0))
  assert point_near(svg_path.segment_end(first), svg_path.Point(7.5, 15.0))
  assert point_near(svg_path.segment_start(second), svg_path.Point(7.5, 15.0))
  assert point_near(svg_path.segment_end(second), svg_path.Point(5.0, 10.0))
}

pub fn segments_between_does_not_add_boundary_parameters_test() {
  let segment =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 20.0),
    )
  let assert Ok([segment_between]) =
    svg_path.segment_between_many(segment, between: [0.25, 0.75])

  assert point_near(
    svg_path.segment_start(segment_between),
    svg_path.Point(2.5, 5.0),
  )
  assert point_near(
    svg_path.segment_end(segment_between),
    svg_path.Point(7.5, 15.0),
  )
}

pub fn segments_between_returns_empty_for_too_few_parameters_test() {
  let segment =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 20.0),
    )

  assert svg_path.segment_between_many(segment, between: []) == Ok([])
  assert svg_path.segment_between_many(segment, between: [0.5]) == Ok([])
}

pub fn segments_between_inside_rejects_any_outside_t_test() {
  let segment =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 20.0),
    )

  assert svg_path.segment_between_many_inside(segment, between: [0.0, 0.5, 1.01])
    == Error(svg_path.SplitOutsideSegment)
  let assert Ok([_]) =
    svg_path.segment_between_many_inside(segment, between: [0.0, 1.0])
}

pub fn segment_eval_and_split_return_degenerate_arc_error_test() {
  let segment =
    svg_path.Arc(
      start: svg_path.Point(0.0, 0.0),
      radius: svg_path.Point(0.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(20.0, 0.0),
    )

  assert svg_path.segment_point(segment, at: 0.5)
    == Error(svg_path.DegenerateArc)
  assert svg_path.segment_derivative(segment, at: 0.5)
    == Error(svg_path.DegenerateArc)
  assert svg_path.segment_split(segment, at: 0.5)
    == Error(svg_path.DegenerateArc)
}

pub fn path_can_be_built_from_empty_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let assert Ok(subpath) =
    svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0))
    |> svg_path.subpath_append_segment(svg_path.Line(start: a, end: b))
  let path =
    svg_path.path_empty()
    |> svg_path.path_append_subpath(subpath)

  assert path |> svg_path.path_subpaths |> list.length == 1
  assert svg_path.path_from_subpath(subpath) |> svg_path.path_subpaths
    == [subpath]
}

pub fn combine_paths_concatenates_subpaths_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let first =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
    ])
  let second =
    svg_path.subpath_assert([
      svg_path.Line(start: c, end: d),
    ])

  let combined =
    svg_path.path_combine([
      svg_path.Path([first]),
      svg_path.path_empty(),
      svg_path.Path([
        svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)),
        second,
      ]),
    ])

  assert svg_path.path_subpaths(combined)
    == [first, svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)), second]
}

pub fn path_map_and_filter_subpaths_compose_after_combine_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let first = svg_path.Line(start: a, end: b)
  let zero = svg_path.Line(start: b, end: b)
  let second = svg_path.Line(start: b, end: c)
  let subpath = svg_path.subpath_assert([first, zero, second])

  let combined =
    svg_path.path_combine([
      svg_path.Path([
        svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)),
        subpath,
      ]),
      svg_path.Path([svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0))]),
    ])
    |> svg_path.path_filter_subpaths(keeping: fn(subpath) {
      !list.is_empty(svg_path.subpath_segments(subpath))
    })
    |> svg_path.path_map_subpaths(with: svg_path.subpath_clean)

  let assert [cleaned] = svg_path.path_subpaths(combined)
  assert svg_path.subpath_segments(cleaned) == [first, second]
}

pub fn path_start_and_end_use_first_and_last_subpaths_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let first = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])
  let second = svg_path.subpath_assert([svg_path.Line(start: c, end: d)])
  let path =
    svg_path.Path([
      svg_path.subpath_empty(at: a),
      first,
      svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)),
      second,
      svg_path.subpath_empty(at: d),
    ])

  assert svg_path.path_start(path) == Ok(a)
  assert svg_path.path_end(path) == Ok(d)
}

pub fn subpath_bounding_box_combines_segment_boxes_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(1.0, 2.0),
        end: svg_path.Point(5.0, -3.0),
      ),
      svg_path.QuadraticBezier(
        start: svg_path.Point(5.0, -3.0),
        control: svg_path.Point(10.0, 10.0),
        end: svg_path.Point(20.0, 0.0),
      ),
    ])

  let assert Ok(box) = svg_path.subpath_bounding_box(subpath)

  assert bbox_near(
    box,
    min: svg_path.Point(1.0, -3.0),
    max: svg_path.Point(20.0, 4.347826086956522),
  )
}

pub fn path_bounding_box_uses_nonempty_subpaths_test() {
  let first =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(1.0, 2.0),
        end: svg_path.Point(5.0, -3.0),
      ),
    ])
  let second =
    svg_path.subpath_assert([
      svg_path.Arc(
        start: svg_path.Point(0.0, 0.0),
        radius: svg_path.Point(10.0, 10.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.Point(20.0, 0.0),
      ),
    ])
  let path =
    svg_path.Path([
      svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)),
      first,
      svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)),
      second,
    ])

  let assert Ok(box) = svg_path.path_bounding_box(path)

  assert bbox_near(
    box,
    min: svg_path.Point(0.0, -10.0),
    max: svg_path.Point(20.0, 2.0),
  )
}

pub fn empty_path_has_no_start_or_end_test() {
  assert svg_path.path_start(svg_path.path_empty()) == Error(svg_path.EmptyPath)
  assert svg_path.path_end(svg_path.path_empty()) == Error(svg_path.EmptyPath)
  assert svg_path.path_bounding_box(svg_path.path_empty())
    == Error(svg_path.EmptyPath)
}

pub fn path_with_only_empty_subpaths_has_start_and_end_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let path =
    svg_path.Path([
      svg_path.subpath_empty(at: a),
      svg_path.subpath_empty(at: b),
    ])

  assert svg_path.path_start(path) == Ok(a)
  assert svg_path.path_end(path) == Ok(b)
  assert svg_path.path_bounding_box(path) == Error(svg_path.EmptySubpaths)
}

pub fn as_subpath_rejects_empty_path_test() {
  assert svg_path.path_as_subpath(svg_path.path_empty())
    == Error(svg_path.EmptySubpaths)
}

pub fn as_subpath_ignores_empty_subpaths_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let line = svg_path.Line(start: a, end: b)
  let assert Ok(subpath) = svg_path.subpath([line])
  let path =
    svg_path.Path([
      svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)),
      subpath,
      svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)),
    ])
  let assert Ok(only_subpath) = svg_path.path_as_subpath(path)

  assert svg_path.subpath_segments(only_subpath) == [line]
}

pub fn as_subpath_rejects_multiple_nonempty_subpaths_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let assert Ok(first) = svg_path.subpath([svg_path.Line(start: a, end: b)])
  let assert Ok(second) = svg_path.subpath([svg_path.Line(start: c, end: d)])

  assert svg_path.path_as_subpath(svg_path.Path([first, second]))
    == Error(svg_path.MultipleNonemptySubpaths)
}

pub fn subpath_can_be_built_from_empty_test() {
  let start = svg_path.Point(0.0, 0.0)
  let end = svg_path.Point(10.0, 0.0)
  let assert Ok(subpath) =
    svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0))
    |> svg_path.subpath_append_segment(svg_path.Line(start:, end:))

  assert svg_path.subpath_start(subpath) == Ok(start)
  assert svg_path.subpath_end(subpath) == Ok(end)
}

pub fn subpath_rejects_empty_segment_list_test() {
  assert svg_path.subpath([]) == Error(svg_path.EmptySubpath)
}

pub fn polyline_rejects_empty_and_singleton_point_lists_test() {
  let point = svg_path.Point(0.0, 0.0)

  assert svg_path.subpath_polyline([]) == Error(svg_path.EmptySubpath)
  assert svg_path.subpath_polyline([point]) == Error(svg_path.EmptySubpath)
}

pub fn polyline_builds_open_line_subpath_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 20.0)
  let assert Ok(subpath) = svg_path.subpath_polyline([a, b, c])

  assert !svg_path.subpath_is_closed(subpath)
  assert svg_path.subpath_segments(subpath)
    == [
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ]
}

pub fn assert_polyline_builds_open_line_subpath_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let subpath = svg_path.subpath_assert_polyline([a, b])

  assert !svg_path.subpath_is_closed(subpath)
  assert svg_path.subpath_segments(subpath) == [svg_path.Line(start: a, end: b)]
}

pub fn polygon_rejects_empty_and_singleton_point_lists_test() {
  let point = svg_path.Point(0.0, 0.0)

  assert svg_path.subpath_polygon([]) == Error(svg_path.EmptySubpath)
  assert svg_path.subpath_polygon([point]) == Error(svg_path.EmptySubpath)
}

pub fn polygon_builds_closed_line_subpath_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 20.0)
  let assert Ok(subpath) = svg_path.subpath_polygon([a, b, c])

  assert svg_path.subpath_is_closed(subpath)
  assert svg_path.subpath_segments(subpath)
    == [
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: a),
    ]
}

pub fn assert_polygon_builds_closed_line_subpath_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let subpath = svg_path.subpath_assert_polygon([a, b])

  assert svg_path.subpath_is_closed(subpath)
  assert svg_path.subpath_segments(subpath)
    == [
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ]
}

pub fn polygon_does_not_add_zero_length_line_when_input_already_closes_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let assert Ok(subpath) = svg_path.subpath_polygon([a, b, a])

  assert svg_path.subpath_is_closed(subpath)
  assert svg_path.subpath_segments(subpath)
    == [
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ]
}

pub fn empty_subpath_has_start_and_end_test() {
  let start = svg_path.Point(0.0, 0.0)

  assert svg_path.subpath_start(svg_path.subpath_empty(at: start)) == Ok(start)
  assert svg_path.subpath_end(svg_path.subpath_empty(at: start)) == Ok(start)
  assert svg_path.subpath_bounding_box(svg_path.subpath_empty(at: start))
    == Error(svg_path.EmptySubpath)
}

pub fn subpath_rejects_disconnected_segments_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)

  assert svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: c, end: d),
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
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let e = svg_path.Point(40.0, 0.0)
  let f = svg_path.Point(50.0, 0.0)

  assert svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: d, end: e),
      svg_path.Line(start: e, end: f),
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
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let segments = [
    svg_path.Line(start: a, end: b),
    svg_path.Line(start: b, end: c),
  ]

  let subpath = svg_path.subpath_assert(segments)

  assert svg_path.subpath_segments(subpath) == segments
}

pub fn set_closed_false_clears_closed_state_without_changing_segments_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let segments = [
    svg_path.Line(start: a, end: b),
    svg_path.Line(start: b, end: a),
  ]
  let closed =
    svg_path.subpath_assert(segments)
    |> svg_path.subpath_assert_set_closed(closed: True)

  let assert Ok(opened) = svg_path.subpath_set_closed(closed, closed: False)

  assert !svg_path.subpath_is_closed(opened)
  assert svg_path.subpath_segments(opened) == segments
}

pub fn set_closed_false_accepts_open_and_empty_subpaths_test() {
  let empty = svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0))
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let open_subpath = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])

  assert svg_path.subpath_set_closed(empty, closed: False) == Ok(empty)
  assert svg_path.subpath_set_closed(open_subpath, closed: False)
    == Ok(open_subpath)
}

pub fn set_closed_false_opens_subpath_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let closed =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)

  let assert Ok(opened) = svg_path.subpath_set_closed(closed, closed: False)

  assert !svg_path.subpath_is_closed(opened)
  assert svg_path.subpath_segments(opened) == svg_path.subpath_segments(closed)
}

pub fn set_closed_true_closes_matching_subpath_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])

  let assert Ok(closed) = svg_path.subpath_set_closed(subpath, closed: True)

  assert svg_path.subpath_is_closed(closed)
}

pub fn set_closed_true_rejects_uncloseable_subpath_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 10.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert svg_path.subpath_set_closed(subpath, closed: True)
    == Error(svg_path.Discontinuous(
      previous_index: 1,
      next_index: 0,
      expected: a,
      got: c,
      distance: 14.142135623730951,
    ))
}

pub fn set_closed_with_wiggle_true_reconciles_nearby_endpoints_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let near_a = svg_path.Point(0.0000000001, 0.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: near_a),
    ])

  let assert Ok(closed) =
    svg_path.subpath_set_closed_with(
      subpath,
      closed: True,
      policy: svg_path.Wiggle,
    )

  assert svg_path.subpath_is_closed(closed)
  assert svg_path.subpath_start(closed) == svg_path.subpath_end(closed)
}

pub fn set_closed_with_wiggle_true_rejects_gaps_beyond_tolerance_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(0.1, 0.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert svg_path.subpath_set_closed_with(
      subpath,
      closed: True,
      policy: svg_path.Wiggle,
    )
    == Error(svg_path.Discontinuous(
      previous_index: 1,
      next_index: 0,
      expected: a,
      got: c,
      distance: 0.1,
    ))
}

pub fn set_closed_with_wiggle_false_opens_subpath_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let closed =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)

  let assert Ok(opened) =
    svg_path.subpath_set_closed_with(
      closed,
      closed: False,
      policy: svg_path.Wiggle,
    )

  assert !svg_path.subpath_is_closed(opened)
}

pub fn append_segment_rejects_closed_subpath_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])
    |> result_try_set_closed_with_bridge

  assert svg_path.subpath_append_segment(
      subpath,
      svg_path.Line(start: a, end: c),
    )
    == Error(svg_path.AlreadyClosed)
}

pub fn append_segment_with_wiggle_rejects_start_gaps_beyond_tolerance_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let subpath = svg_path.subpath_empty(at: a)

  assert svg_path.subpath_append_segment_with(
      subpath,
      svg_path.Line(start: b, end: c),
      policy: svg_path.Wiggle,
    )
    == Error(svg_path.Discontinuous(
      previous_index: -1,
      next_index: 0,
      expected: a,
      got: b,
      distance: 10.0,
    ))
}

pub fn subpath_with_wiggle_replaces_nearby_sequential_endpoints_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let near_b = svg_path.Point(10.0000000001, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let assert Ok(subpath) =
    svg_path.subpath_with(
      [
        svg_path.Line(start: a, end: b),
        svg_path.Line(start: near_b, end: c),
      ],
      policy: svg_path.Wiggle,
    )

  let assert [first, second] = svg_path.subpath_segments(subpath)
  let overlap = svg_path.segment_end(first)

  assert svg_path.segment_start(first) == a
  assert svg_path.segment_start(second) == overlap
  assert svg_path.segment_end(second) == c
  assert overlap != b
  assert overlap != near_b
}

pub fn subpath_with_wiggle_rejects_empty_and_accepts_single_segment_inputs_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let line = svg_path.Line(start: a, end: b)

  assert svg_path.subpath_with([], policy: svg_path.Wiggle)
    == Error(svg_path.EmptySubpath)
  let assert Ok(subpath) =
    svg_path.subpath_with([line], policy: svg_path.Wiggle)
  assert svg_path.subpath_segments(subpath) == [line]
}

pub fn subpath_with_wiggle_then_line_prefers_wiggle_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let near_b = svg_path.Point(10.0000000001, 0.0)
  let c = svg_path.Point(20.0, 0.0)

  let assert Ok(subpath) =
    svg_path.subpath_with(
      [
        svg_path.Line(start: a, end: b),
        svg_path.Line(start: near_b, end: c),
      ],
      policy: svg_path.WiggleThenBridge,
    )

  assert subpath |> svg_path.subpath_segments |> list.length == 2
  assert continuous_segments(svg_path.subpath_segments(subpath))
}

pub fn subpath_with_wiggle_then_line_falls_back_to_bridge_line_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)

  let assert Ok(subpath) =
    svg_path.subpath_with(
      [
        svg_path.Line(start: a, end: b),
        svg_path.Line(start: c, end: d),
      ],
      policy: svg_path.WiggleThenBridge,
    )

  assert svg_path.subpath_segments(subpath)
    == [
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ]
}

pub fn clean_subpath_removes_zero_length_lines_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let first = svg_path.Line(start: a, end: b)
  let zero = svg_path.Line(start: b, end: b)
  let second = svg_path.Line(start: b, end: c)
  let subpath = svg_path.subpath_assert([first, zero, second])

  assert subpath |> svg_path.subpath_clean |> svg_path.subpath_segments
    == [first, second]
}

pub fn clean_subpath_keeps_single_zero_length_line_test() {
  let a = svg_path.Point(0.0, 0.0)
  let zero = svg_path.Line(start: a, end: a)
  let subpath = svg_path.subpath_assert([zero])

  assert subpath |> svg_path.subpath_clean |> svg_path.subpath_segments
    == [zero]
}

pub fn clean_subpath_reduces_multiple_zero_length_lines_to_one_test() {
  let a = svg_path.Point(0.0, 0.0)
  let zero = svg_path.Line(start: a, end: a)
  let subpath = svg_path.subpath_assert([zero, zero])

  assert subpath |> svg_path.subpath_clean |> svg_path.subpath_segments
    == [zero]
}

pub fn clean_subpath_preserves_closed_state_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
      svg_path.Line(start: a, end: a),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)

  let cleaned = svg_path.subpath_clean(subpath)

  assert svg_path.subpath_is_closed(cleaned)
  assert svg_path.subpath_segments(cleaned)
    == [
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ]
}

pub fn segment_is_zero_length_detects_exact_zero_lines_test() {
  let a = svg_path.Point(0.0, 0.0)
  let zero = svg_path.Line(start: a, end: a)
  let nonzero = svg_path.Line(start: a, end: svg_path.Point(1.0, 0.0))

  assert svg_path.segment_is_zero_length(zero, tolerance: 0.0) == Ok(True)
  assert svg_path.segment_is_zero_length(nonzero, tolerance: 0.0) == Ok(False)
}

pub fn segment_is_zero_length_uses_tolerance_test() {
  let a = svg_path.Point(0.0, 0.0)
  let short = svg_path.Line(start: a, end: svg_path.Point(0.001, 0.0))

  assert svg_path.segment_is_zero_length(short, tolerance: 0.0009) == Ok(False)
  assert svg_path.segment_is_zero_length(short, tolerance: 0.0011) == Ok(True)
}

pub fn segment_is_zero_length_detects_collapsed_cubic_test() {
  let a = svg_path.Point(2.0, 3.0)
  let zero = svg_path.CubicBezier(start: a, control1: a, control2: a, end: a)

  assert svg_path.segment_is_zero_length(zero, tolerance: 0.0) == Ok(True)
}

pub fn subpath_is_zero_length_requires_non_empty_subpath_test() {
  let empty = svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0))

  assert svg_path.subpath_is_zero_length(empty, tolerance: 0.0) == Ok(False)
}

pub fn subpath_is_zero_length_checks_every_segment_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(1.0, 0.0)
  let zero = svg_path.Line(start: a, end: a)
  let nonzero = svg_path.Line(start: a, end: b)

  assert svg_path.subpath_is_zero_length(
      svg_path.subpath_assert([zero]),
      tolerance: 0.0,
    )
    == Ok(True)
  assert svg_path.subpath_is_zero_length(
      svg_path.subpath_assert([zero, zero]),
      tolerance: 0.0,
    )
    == Ok(True)
  assert svg_path.subpath_is_zero_length(
      svg_path.subpath_assert_with([zero, nonzero], policy: svg_path.Wiggle),
      tolerance: 0.0,
    )
    == Ok(False)
}

pub fn zero_length_predicates_reject_negative_tolerance_test() {
  let a = svg_path.Point(0.0, 0.0)
  let zero = svg_path.Line(start: a, end: a)

  assert svg_path.segment_is_zero_length(zero, tolerance: -0.1)
    == Error(svg_path.InvalidZeroLengthTolerance(-0.1))
}

pub fn path_map_subpaths_maps_each_subpath_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let first = svg_path.Line(start: a, end: b)
  let zero = svg_path.Line(start: b, end: b)
  let second = svg_path.Line(start: b, end: c)
  let third = svg_path.Line(start: c, end: d)
  let first_subpath = svg_path.subpath_assert([first, zero, second])
  let second_subpath = svg_path.subpath_assert([third])
  let path =
    svg_path.Path([
      svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)),
      first_subpath,
      svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)),
      second_subpath,
    ])

  let cleaned = path |> svg_path.path_map_subpaths(with: svg_path.subpath_clean)
  let assert [empty, cleaned_first, empty_again, cleaned_second] =
    svg_path.path_subpaths(cleaned)

  assert empty == svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0))
  assert empty_again == svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0))
  assert svg_path.subpath_segments(cleaned_first) == [first, second]
  assert svg_path.subpath_segments(cleaned_second) == [third]
}

pub fn path_filter_subpaths_keeps_matching_subpaths_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let first_subpath = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])
  let second_subpath =
    svg_path.subpath_assert([svg_path.Line(start: c, end: d)])
  let path =
    svg_path.Path([
      svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)),
      first_subpath,
      svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)),
      second_subpath,
    ])

  let filtered =
    path
    |> svg_path.path_filter_subpaths(keeping: fn(subpath) {
      !list.is_empty(svg_path.subpath_segments(subpath))
    })
  let assert [cleaned_first, cleaned_second] = svg_path.path_subpaths(filtered)

  assert cleaned_first == first_subpath
  assert cleaned_second == second_subpath
}

pub fn path_filter_subpaths_can_return_empty_path_test() {
  let path =
    svg_path.Path([
      svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)),
      svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)),
    ])

  assert path
    |> svg_path.path_filter_subpaths(keeping: fn(subpath) {
      !list.is_empty(svg_path.subpath_segments(subpath))
    })
    == svg_path.path_empty()
}

pub fn splice_replaces_segment_range_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let e = svg_path.Point(40.0, 0.0)
  let first = svg_path.Line(start: a, end: b)
  let replacement = svg_path.Line(start: b, end: d)
  let last = svg_path.Line(start: d, end: e)
  let subpath =
    svg_path.subpath_assert([
      first,
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
      last,
    ])

  let assert Ok(spliced) =
    svg_path.subpath_splice(subpath, start: 1, delete: 2, insert: [replacement])

  assert svg_path.subpath_segments(spliced) == [first, replacement, last]
}

pub fn splice_inserts_without_deleting_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let first = svg_path.Line(start: a, end: b)
  let inserted = svg_path.Line(start: b, end: c)
  let subpath = svg_path.subpath_assert([first])

  let assert Ok(spliced) =
    svg_path.subpath_splice(subpath, start: 1, delete: 0, insert: [inserted])

  assert svg_path.subpath_segments(spliced) == [first, inserted]
}

pub fn splice_deletes_through_end_when_delete_is_too_large_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let first = svg_path.Line(start: a, end: b)
  let subpath =
    svg_path.subpath_assert([
      first,
      svg_path.Line(start: b, end: c),
    ])

  let assert Ok(spliced) =
    svg_path.subpath_splice(subpath, start: 1, delete: 99, insert: [])

  assert svg_path.subpath_segments(spliced) == [first]
}

pub fn splice_rejects_invalid_bounds_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let subpath = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])

  assert svg_path.subpath_splice(subpath, start: -1, delete: 0, insert: [])
    == Error(svg_path.InvalidSplice(start: -1, delete: 0, length: 1))
  assert svg_path.subpath_splice(subpath, start: 2, delete: 0, insert: [])
    == Error(svg_path.InvalidSplice(start: 2, delete: 0, length: 1))
  assert svg_path.subpath_splice(subpath, start: 0, delete: -1, insert: [])
    == Error(svg_path.InvalidSplice(start: 0, delete: -1, length: 1))
}

pub fn splice_rejects_discontinuous_result_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert svg_path.subpath_splice(subpath, start: 1, delete: 1, insert: [
      svg_path.Line(start: d, end: c),
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
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let near_b = svg_path.Point(10.0000000001, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  let assert Error(svg_path.Discontinuous(
    previous_index: 0,
    next_index: 1,
    expected:,
    got:,
    distance:,
  )) =
    svg_path.subpath_splice(subpath, start: 1, delete: 1, insert: [
      svg_path.Line(start: near_b, end: c),
    ])
  assert expected == b
  assert got == near_b
  assert distance <. 0.000000001

  let assert Ok(spliced) =
    svg_path.subpath_splice_with(
      subpath,
      start: 1,
      delete: 1,
      insert: [
        svg_path.Line(start: near_b, end: c),
      ],
      policy: svg_path.Wiggle,
    )

  assert svg_path.subpath_end(spliced) == Ok(c)
  assert continuous_segments(svg_path.subpath_segments(spliced))
}

pub fn splice_with_wiggle_preserves_closed_state_with_tiny_endpoint_gap_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let near_a = svg_path.Point(0.0000000001, 0.0)
  let closed =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: a),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)

  let assert Ok(spliced) =
    svg_path.subpath_splice_with(
      closed,
      start: 2,
      delete: 1,
      insert: [
        svg_path.Line(start: c, end: near_a),
      ],
      policy: svg_path.Wiggle,
    )

  assert svg_path.subpath_is_closed(spliced)
  assert svg_path.subpath_start(spliced) == svg_path.subpath_end(spliced)
}

pub fn splice_with_wiggle_reuses_splice_bounds_errors_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let subpath = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])

  assert svg_path.subpath_splice_with(
      subpath,
      start: 2,
      delete: 0,
      insert: [],
      policy: svg_path.Wiggle,
    )
    == Error(svg_path.InvalidSplice(start: 2, delete: 0, length: 1))
}

pub fn splice_preserves_closed_state_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let closed =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: a),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)
  let replacement = svg_path.Line(start: b, end: c)

  let assert Ok(spliced) =
    svg_path.subpath_splice(closed, start: 1, delete: 1, insert: [replacement])

  assert svg_path.subpath_is_closed(spliced)
}

pub fn splice_allows_closed_empty_result_test() {
  let a = svg_path.Point(0.0, 0.0)
  let closed =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: a),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)

  assert svg_path.subpath_splice(closed, start: 0, delete: 1, insert: [])
    == Ok(
      svg_path.subpath_empty(at: a)
      |> svg_path.subpath_assert_set_closed(closed: True),
    )
}

pub fn segment_arcs_to_cubic_beziers_preserves_lines_test() {
  let start = svg_path.Point(0.0, 0.0)
  let end = svg_path.Point(9.0, 0.0)
  let line = svg_path.Line(start:, end:)

  assert svg_path.segment_arcs_to_cubic_beziers(line) == [line]
}

pub fn segment_to_cubic_beziers_converts_line_exactly_test() {
  let start = svg_path.Point(0.0, 0.0)
  let end = svg_path.Point(9.0, 0.0)

  assert svg_path.segment_to_cubic_beziers(svg_path.Line(start:, end:))
    == [
      svg_path.CubicBezier(
        start:,
        control1: svg_path.Point(3.0, 0.0),
        control2: svg_path.Point(6.0, 0.0),
        end:,
      ),
    ]
}

pub fn segment_arcs_to_cubic_beziers_preserves_quadratics_test() {
  let start = svg_path.Point(0.0, 0.0)
  let control = svg_path.Point(3.0, 6.0)
  let end = svg_path.Point(9.0, 0.0)
  let quadratic = svg_path.QuadraticBezier(start:, control:, end:)

  assert svg_path.segment_arcs_to_cubic_beziers(quadratic) == [quadratic]
}

pub fn segment_arcs_to_cubic_beziers_preserves_cubics_test() {
  let start = svg_path.Point(0.0, 0.0)
  let control1 = svg_path.Point(2.0, 4.0)
  let control2 = svg_path.Point(5.0, 4.0)
  let end = svg_path.Point(9.0, 0.0)
  let cubic = svg_path.CubicBezier(start:, control1:, control2:, end:)

  assert svg_path.segment_arcs_to_cubic_beziers(cubic) == [cubic]
}

pub fn segment_to_cubic_beziers_converts_quadratic_exactly_test() {
  let start = svg_path.Point(0.0, 0.0)
  let control = svg_path.Point(3.0, 6.0)
  let end = svg_path.Point(9.0, 0.0)

  assert svg_path.segment_to_cubic_beziers(svg_path.QuadraticBezier(
      start:,
      control:,
      end:,
    ))
    == [
      svg_path.CubicBezier(
        start:,
        control1: svg_path.Point(2.0, 4.0),
        control2: svg_path.Point(5.0, 4.0),
        end:,
      ),
    ]
}

pub fn segment_arcs_to_cubic_beziers_splits_half_turn_into_two_cubics_test() {
  let start = svg_path.Point(0.0, 0.0)
  let end = svg_path.Point(20.0, 0.0)
  let cubics =
    svg_path.segment_arcs_to_cubic_beziers(svg_path.Arc(
      start:,
      radius: svg_path.Point(10.0, 10.0),
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
  let start = svg_path.Point(0.0, 0.0)
  let end = svg_path.Point(10.0, 10.0)
  let cubics =
    svg_path.segment_arcs_to_cubic_beziers(svg_path.Arc(
      start:,
      radius: svg_path.Point(10.0, 10.0),
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
  let start = svg_path.Point(0.0, 0.0)
  let end = svg_path.Point(9.0, 0.0)

  assert svg_path.segment_arcs_to_cubic_beziers(svg_path.Arc(
      start:,
      radius: svg_path.Point(0.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end:,
    ))
    == [
      svg_path.CubicBezier(
        start:,
        control1: svg_path.Point(3.0, 0.0),
        control2: svg_path.Point(6.0, 0.0),
        end:,
      ),
    ]
}

pub fn subpath_arcs_to_cubic_beziers_preserves_closed_state_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)

  let converted = svg_path.subpath_arcs_to_cubic_beziers(subpath)

  assert svg_path.subpath_is_closed(converted)
  assert svg_path.subpath_segments(converted)
    == svg_path.subpath_segments(subpath)
}

pub fn subpath_arcs_to_cubic_beziers_replaces_only_arcs_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let line = svg_path.Line(start: a, end: b)
  let arc =
    svg_path.Arc(
      start: b,
      radius: svg_path.Point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: c,
    )
  let quadratic = svg_path.QuadraticBezier(start: c, control: c, end: d)
  let subpath = svg_path.subpath_assert([line, arc, quadratic])

  let converted = svg_path.subpath_arcs_to_cubic_beziers(subpath)

  assert svg_path.segment_start(
      list.first(svg_path.subpath_segments(converted)) |> unwrap_segment,
    )
    == a
  assert svg_path.segment_end(
      list.last(svg_path.subpath_segments(converted)) |> unwrap_segment,
    )
    == d
  assert no_arcs(svg_path.subpath_segments(converted))
  assert contains_line(svg_path.subpath_segments(converted), line)
  assert contains_quadratic(svg_path.subpath_segments(converted), quadratic)
  assert continuous_segments(svg_path.subpath_segments(converted))
}

pub fn subpath_to_cubic_beziers_preserves_closed_state_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)

  let converted = svg_path.subpath_to_cubic_beziers(subpath)

  assert svg_path.subpath_is_closed(converted)
  assert all_cubic(svg_path.subpath_segments(converted))
}

pub fn path_arcs_to_cubic_beziers_converts_each_subpath_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let first =
    svg_path.subpath_assert([
      svg_path.Arc(
        start: a,
        radius: svg_path.Point(5.0, 5.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: b,
      ),
    ])
  let second = svg_path.subpath_assert([svg_path.Line(start: c, end: d)])

  let converted =
    svg_path.path_arcs_to_cubic_beziers(svg_path.Path([first, second]))
  let segments =
    converted
    |> svg_path.path_subpaths
    |> list.flat_map(svg_path.subpath_segments)

  assert no_arcs(segments)
  assert contains_line(segments, svg_path.Line(start: c, end: d))
}

pub fn path_to_cubic_beziers_converts_each_subpath_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let first = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])
  let second = svg_path.subpath_assert([svg_path.Line(start: c, end: d)])

  let converted = svg_path.path_to_cubic_beziers(svg_path.Path([first, second]))
  let segments =
    converted
    |> svg_path.path_subpaths
    |> list.flat_map(svg_path.subpath_segments)

  assert all_cubic(segments)
}

pub fn segment_to_lines_preserves_lines_test() {
  let line =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 5.0),
    )

  assert svg_path.segment_to_lines(line) == Ok([line])
}

pub fn segment_to_lines_approximates_beziers_within_tolerance_test() {
  let tolerance = 0.05
  let options = svg_path.LinearizeOptions(tolerance:, max_depth: 20)
  let quadratic =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.0),
      control: svg_path.Point(10.0, 20.0),
      end: svg_path.Point(20.0, 0.0),
    )
  let cubic =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(0.0, 20.0),
      control2: svg_path.Point(20.0, 20.0),
      end: svg_path.Point(20.0, 0.0),
    )

  let assert Ok(quadratic_lines) =
    svg_path.segment_to_lines_with(quadratic, options:)
  let assert Ok(cubic_lines) = svg_path.segment_to_lines_with(cubic, options:)

  assert all_lines(quadratic_lines)
  assert all_lines(cubic_lines)
  assert continuous_segments(quadratic_lines)
  assert continuous_segments(cubic_lines)
  assert sampled_segment_within_lines(
    quadratic,
    quadratic_lines,
    tolerance,
    samples: 500,
  )
  assert sampled_segment_within_lines(
    cubic,
    cubic_lines,
    tolerance,
    samples: 500,
  )
}

pub fn segment_to_lines_detects_collinear_control_overshoot_test() {
  let curve =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.0),
      control: svg_path.Point(20.0, 0.0),
      end: svg_path.Point(10.0, 0.0),
    )

  let assert Ok(lines) =
    svg_path.segment_to_lines_with(
      curve,
      options: svg_path.LinearizeOptions(tolerance: 0.01, max_depth: 20),
    )

  assert list.length(lines) > 1
  assert list.any(lines, fn(line) { svg_path.segment_end(line).x >. 10.0 })
}

pub fn segment_to_lines_approximates_arcs_within_tolerance_test() {
  let tolerance = 0.05
  let arc =
    svg_path.Arc(
      start: svg_path.Point(0.0, 0.0),
      radius: svg_path.Point(10.0, 5.0),
      x_axis_rotation: 30.0,
      large_arc: True,
      sweep: True,
      end: svg_path.Point(20.0, 0.0),
    )

  let assert Ok(lines) =
    svg_path.segment_to_lines_with(
      arc,
      options: svg_path.LinearizeOptions(tolerance:, max_depth: 20),
    )

  assert all_lines(lines)
  assert continuous_segments(lines)
  assert svg_path.segment_start(list.first(lines) |> unwrap_segment)
    == svg_path.segment_start(arc)
  assert svg_path.segment_end(list.last(lines) |> unwrap_segment)
    == svg_path.segment_end(arc)
  assert sampled_segment_within_lines(arc, lines, tolerance, samples: 500)
}

pub fn segment_to_lines_degenerate_arc_falls_back_to_line_test() {
  let start = svg_path.Point(0.0, 0.0)
  let end = svg_path.Point(10.0, 0.0)
  let arc =
    svg_path.Arc(
      start:,
      radius: svg_path.Point(0.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end:,
    )

  assert svg_path.segment_to_lines(arc) == Ok([svg_path.Line(start:, end:)])
}

pub fn segment_to_lines_tighter_tolerance_does_not_use_fewer_lines_test() {
  let curve =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(0.0, 20.0),
      control2: svg_path.Point(20.0, 20.0),
      end: svg_path.Point(20.0, 0.0),
    )
  let assert Ok(coarse) =
    svg_path.segment_to_lines_with(
      curve,
      options: svg_path.LinearizeOptions(tolerance: 1.0, max_depth: 20),
    )
  let assert Ok(fine) =
    svg_path.segment_to_lines_with(
      curve,
      options: svg_path.LinearizeOptions(tolerance: 0.1, max_depth: 20),
    )

  assert list.length(fine) >= list.length(coarse)
}

pub fn segment_to_lines_rejects_invalid_options_and_depth_exhaustion_test() {
  let curve =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.0),
      control: svg_path.Point(10.0, 20.0),
      end: svg_path.Point(20.0, 0.0),
    )

  assert svg_path.segment_to_lines_with(
      curve,
      options: svg_path.LinearizeOptions(tolerance: 0.0, max_depth: 20),
    )
    == Error(svg_path.InvalidLinearizeTolerance(0.0))
  assert svg_path.segment_to_lines_with(
      curve,
      options: svg_path.LinearizeOptions(tolerance: 0.1, max_depth: 0),
    )
    == Error(svg_path.InvalidLinearizeMaxDepth(0))
  let assert Error(svg_path.LinearizeMaxDepthReached(error:)) =
    svg_path.segment_to_lines_with(
      curve,
      options: svg_path.LinearizeOptions(
        tolerance: 0.000000000001,
        max_depth: 1,
      ),
    )
  assert error >. 0.000000000001
}

pub fn subpath_and_path_to_lines_preserve_topology_test() {
  let a = svg_path.Point(0.0, 0.0)
  let curve =
    svg_path.QuadraticBezier(
      start: a,
      control: svg_path.Point(10.0, 20.0),
      end: a,
    )
  let closed =
    svg_path.subpath_assert([curve])
    |> svg_path.subpath_assert_set_closed(closed: True)
  let move_only = svg_path.subpath_empty(at: svg_path.Point(30.0, 40.0))

  let assert Ok(converted) =
    svg_path.path_to_lines(svg_path.Path([move_only, closed]))
  let assert [converted_move_only, converted_closed] =
    svg_path.path_subpaths(converted)

  assert svg_path.subpath_segments(converted_move_only) == []
  assert svg_path.subpath_start(converted_move_only)
    == svg_path.subpath_start(move_only)
  assert svg_path.subpath_is_closed(converted_closed)
  assert all_lines(svg_path.subpath_segments(converted_closed))
  assert continuous_segments(svg_path.subpath_segments(converted_closed))
  assert svg_path.subpath_start(converted_closed)
    == svg_path.subpath_end(converted_closed)
}

pub fn subpath_with_wiggle_rejects_gaps_beyond_tolerance_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.1, 0.0)
  let d = svg_path.Point(20.0, 0.0)

  assert svg_path.subpath_with(
      [
        svg_path.Line(start: a, end: b),
        svg_path.Line(start: c, end: d),
      ],
      policy: svg_path.Wiggle,
    )
    == Error(svg_path.Discontinuous(
      previous_index: 0,
      next_index: 1,
      expected: b,
      got: c,
      distance: 0.09999999999999964,
    ))
}

pub fn subpath_with_wiggle_rejects_misaligned_vertical_lines_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(0.0, 10.0)
  let c = svg_path.Point(0.0000000001, 10.0000000001)
  let d = svg_path.Point(0.0000000001, 20.0)

  assert svg_path.subpath_with(
      [
        svg_path.Line(start: a, end: b),
        svg_path.Line(start: c, end: d),
      ],
      policy: svg_path.Wiggle,
    )
    == Error(svg_path.IncompatibleVerticalWiggle(previous_end: b, next_start: c))
}

pub fn subpath_with_wiggle_rejects_misaligned_horizontal_lines_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0000000001, 0.0000000001)
  let d = svg_path.Point(20.0, 0.0000000001)

  assert svg_path.subpath_with(
      [
        svg_path.Line(start: a, end: b),
        svg_path.Line(start: c, end: d),
      ],
      policy: svg_path.Wiggle,
    )
    == Error(svg_path.IncompatibleHorizontalWiggle(
      previous_end: b,
      next_start: c,
    ))
}

pub fn append_segment_discontinuous_error_reports_segment_indices_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let subpath = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])

  assert svg_path.subpath_append_segment(
      subpath,
      svg_path.Line(start: c, end: d),
    )
    == Error(svg_path.Discontinuous(
      previous_index: 0,
      next_index: 1,
      expected: b,
      got: c,
      distance: 10.0,
    ))
}

pub fn join_combines_open_subpaths_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let first = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])
  let second = svg_path.subpath_assert([svg_path.Line(start: b, end: c)])
  let third = svg_path.subpath_assert([svg_path.Line(start: c, end: d)])

  let assert Ok(joined) = svg_path.subpath_join([first, second, third])

  assert svg_path.subpath_segments(joined)
    == [
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ]
}

pub fn join_treats_empty_open_subpaths_as_identity_values_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let subpath = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])
  let empty_start = svg_path.subpath_empty(at: a)
  let empty_end = svg_path.subpath_empty(at: b)

  assert svg_path.subpath_join([]) == Error(svg_path.EmptySubpath)
  assert svg_path.subpath_join([empty_start, subpath]) == Ok(subpath)
  assert svg_path.subpath_join([subpath, empty_end]) == Ok(subpath)
  assert svg_path.subpath_join([empty_start, empty_end]) == Ok(empty_start)
}

pub fn join_treats_interleaved_empty_subpaths_as_identity_values_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let first = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])
  let second = svg_path.subpath_assert([svg_path.Line(start: b, end: c)])
  let empty = svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0))

  let assert Ok(joined) =
    svg_path.subpath_join([empty, first, empty, second, empty])

  assert svg_path.subpath_segments(joined)
    == [
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ]
}

pub fn join_rejects_discontinuous_subpaths_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let first = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])
  let second = svg_path.subpath_assert([svg_path.Line(start: c, end: d)])

  assert svg_path.subpath_join([first, second])
    == Error(svg_path.Discontinuous(
      previous_index: 0,
      next_index: 1,
      expected: b,
      got: c,
      distance: 10.0,
    ))
}

pub fn join_discontinuous_error_reports_flattened_segment_indices_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let e = svg_path.Point(40.0, 0.0)
  let first =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])
  let second = svg_path.subpath_assert([svg_path.Line(start: d, end: e)])

  assert svg_path.subpath_join([first, second])
    == Error(svg_path.Discontinuous(
      previous_index: 1,
      next_index: 2,
      expected: c,
      got: d,
      distance: 10.0,
    ))
}

pub fn join_rejects_closed_inputs_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let open = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])
  let closed =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)

  assert svg_path.subpath_join([closed, open]) == Error(svg_path.AlreadyClosed)
  assert svg_path.subpath_join([open, closed]) == Error(svg_path.AlreadyClosed)
}

pub fn join_with_wiggle_reconciles_tiny_endpoint_gap_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let near_b = svg_path.Point(10.0000000001, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let first = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])
  let second = svg_path.subpath_assert([svg_path.Line(start: near_b, end: c)])

  let assert Ok(joined) =
    svg_path.subpath_join_with([first, second], policy: svg_path.Wiggle)

  assert svg_path.subpath_start(joined) == Ok(a)
  assert svg_path.subpath_end(joined) == Ok(c)
  assert continuous_segments(svg_path.subpath_segments(joined))
}

pub fn assert_join_with_wiggle_reconciles_tiny_endpoint_gap_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let near_b = svg_path.Point(10.0000000001, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let first = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])
  let second = svg_path.subpath_assert([svg_path.Line(start: near_b, end: c)])

  let joined =
    svg_path.subpath_assert_join_with([first, second], policy: svg_path.Wiggle)

  assert svg_path.subpath_start(joined) == Ok(a)
  assert svg_path.subpath_end(joined) == Ok(c)
  assert continuous_segments(svg_path.subpath_segments(joined))
}

pub fn join_with_wiggle_rejects_closed_inputs_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let open = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])
  let closed =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)

  assert svg_path.subpath_join_with([closed, open], policy: svg_path.Wiggle)
    == Error(svg_path.AlreadyClosed)
  assert svg_path.subpath_join_with([open, closed], policy: svg_path.Wiggle)
    == Error(svg_path.AlreadyClosed)
}

pub fn append_segment_with_line_bridges_a_gap_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let assert Ok(subpath) =
    svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0))
    |> svg_path.subpath_append_segment(svg_path.Line(start: a, end: b))
    |> result_try_append_segment_with_line(svg_path.Line(start: c, end: d))

  assert subpath |> svg_path.subpath_segments |> list.length == 3
  assert svg_path.subpath_end(subpath) == Ok(d)
}

pub fn join_with_line_bridges_a_gap_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let first = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])
  let second = svg_path.subpath_assert([svg_path.Line(start: c, end: d)])

  let assert Ok(joined) =
    svg_path.subpath_join_with([first, second], policy: svg_path.Bridge)

  assert svg_path.subpath_segments(joined)
    == [
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ]
}

pub fn join_with_line_rejects_closed_inputs_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let open = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])
  let closed =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)

  assert svg_path.subpath_join_with([closed, open], policy: svg_path.Bridge)
    == Error(svg_path.AlreadyClosed)
  assert svg_path.subpath_join_with([open, closed], policy: svg_path.Bridge)
    == Error(svg_path.AlreadyClosed)
}

pub fn subpath_with_custom_reconciles_a_gap_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)

  let assert Ok(subpath) =
    svg_path.subpath_with(
      [svg_path.Line(start: a, end: b), svg_path.Line(start: c, end: d)],
      policy: svg_path.Custom(fn(previous, next) {
        #(line_to_end(previous, c), [], next)
      }),
    )

  assert svg_path.subpath_segments(subpath)
    == [svg_path.Line(start: a, end: c), svg_path.Line(start: c, end: d)]
}

pub fn subpath_with_custom_can_insert_a_connector_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)

  let assert Ok(subpath) =
    svg_path.subpath_with(
      [svg_path.Line(start: a, end: b), svg_path.Line(start: c, end: d)],
      policy: svg_path.Custom(fn(previous, next) {
        #(
          previous,
          [
            svg_path.Line(
              start: svg_path.segment_end(previous),
              end: svg_path.segment_start(next),
            ),
          ],
          next,
        )
      }),
    )

  assert svg_path.subpath_segments(subpath)
    == [
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ]
}

pub fn subpath_with_custom_can_insert_multiple_connectors_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let elbow = svg_path.Point(10.0, 10.0)
  let c = svg_path.Point(20.0, 10.0)
  let d = svg_path.Point(30.0, 10.0)

  let assert Ok(subpath) =
    svg_path.subpath_with(
      [svg_path.Line(start: a, end: b), svg_path.Line(start: c, end: d)],
      policy: svg_path.Custom(fn(previous, next) {
        #(
          previous,
          [
            svg_path.Line(start: svg_path.segment_end(previous), end: elbow),
            svg_path.Line(start: elbow, end: svg_path.segment_start(next)),
          ],
          next,
        )
      }),
    )

  assert svg_path.subpath_segments(subpath)
    == [
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: elbow),
      svg_path.Line(start: elbow, end: c),
      svg_path.Line(start: c, end: d),
    ]
}

pub fn subpath_with_custom_rejects_invalid_results_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)

  assert svg_path.subpath_with(
      [svg_path.Line(start: a, end: b), svg_path.Line(start: c, end: d)],
      policy: svg_path.Custom(fn(previous, next) { #(previous, [], next) }),
    )
    == Error(svg_path.Discontinuous(
      previous_index: 0,
      next_index: 1,
      expected: b,
      got: c,
      distance: 10.0,
    ))
}

pub fn append_segment_with_custom_can_rewrite_the_incoming_segment_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let e = svg_path.Point(40.0, 0.0)
  let subpath = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])

  let assert Ok(appended) =
    svg_path.subpath_append_segment_with(
      subpath,
      svg_path.Line(start: c, end: d),
      policy: svg_path.Custom(fn(previous, _next) {
        #(
          previous,
          [],
          svg_path.Line(start: svg_path.segment_end(previous), end: e),
        )
      }),
    )

  assert svg_path.subpath_segments(appended)
    == [svg_path.Line(start: a, end: b), svg_path.Line(start: b, end: e)]
}

pub fn join_with_custom_reconciles_a_gap_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(30.0, 0.0)
  let first = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])
  let second = svg_path.subpath_assert([svg_path.Line(start: c, end: d)])

  let assert Ok(joined) =
    svg_path.subpath_join_with(
      [first, second],
      policy: svg_path.Custom(fn(previous, next) {
        #(previous, [], line_from_start(next, svg_path.segment_end(previous)))
      }),
    )

  assert svg_path.subpath_segments(joined)
    == [svg_path.Line(start: a, end: b), svg_path.Line(start: b, end: d)]
}

pub fn set_closed_with_bridge_appends_a_final_line_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 10.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])
    |> result_try_set_closed_with_bridge

  assert svg_path.subpath_is_closed(subpath)
  assert subpath |> svg_path.subpath_segments |> list.length == 3
  assert svg_path.subpath_end(subpath) == Ok(a)
}

pub fn set_closed_with_custom_reconciles_the_closing_gap_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 10.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  let assert Ok(closed) =
    svg_path.subpath_set_closed_with(
      subpath,
      closed: True,
      policy: svg_path.Custom(fn(last, first) {
        #(line_to_end(last, svg_path.segment_start(first)), [], first)
      }),
    )

  assert svg_path.subpath_is_closed(closed)
  assert svg_path.subpath_segments(closed)
    == [svg_path.Line(start: a, end: b), svg_path.Line(start: b, end: a)]
}

pub fn set_closed_with_custom_rejects_invalid_results_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 10.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert svg_path.subpath_set_closed_with(
      subpath,
      closed: True,
      policy: svg_path.Custom(fn(last, first) { #(last, [], first) }),
    )
    == Error(svg_path.Discontinuous(
      previous_index: 1,
      next_index: 0,
      expected: a,
      got: c,
      distance: 14.142135623730951,
    ))
}

pub fn set_closed_true_empty_subpath_closes_test() {
  let subpath = svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0))

  assert svg_path.subpath_set_closed(subpath, closed: True)
    == Ok(svg_path.subpath_assert_set_closed(subpath, closed: True))
}

pub fn set_closed_true_discontinuous_error_reports_last_to_first_indices_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(0.0, 10.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert svg_path.subpath_set_closed(subpath, closed: True)
    == Error(svg_path.Discontinuous(
      previous_index: 1,
      next_index: 0,
      expected: a,
      got: c,
      distance: 10.0,
    ))
}

pub fn assert_set_closed_true_closes_matching_endpoints_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])

  let closed = svg_path.subpath_assert_set_closed(subpath, closed: True)

  assert svg_path.subpath_is_closed(closed)
}

pub fn open_at_rotates_a_closed_subpath_to_start_at_parameter_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 10.0)
  let d = svg_path.Point(0.0, 10.0)
  let ab = svg_path.Line(start: a, end: b)
  let bc = svg_path.Line(start: b, end: c)
  let cd = svg_path.Line(start: c, end: d)
  let da = svg_path.Line(start: d, end: a)
  let subpath = closed_subpath([ab, bc, cd, da])

  let assert Ok(opened) =
    svg_path.subpath_open_at(subpath, at: svg_path.SubpathParameter(1, 0.0))

  assert !svg_path.subpath_is_closed(opened)
  assert svg_path.subpath_segments(opened) == [bc, cd, da, ab]
  assert svg_path.subpath_start(opened) == Ok(b)
  assert svg_path.subpath_end(opened) == Ok(b)
}

pub fn open_at_accepts_parameters_inside_segments_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 10.0)
  let d = svg_path.Point(0.0, 10.0)
  let subpath =
    closed_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
      svg_path.Line(start: d, end: a),
    ])

  let assert Ok(opened) =
    svg_path.subpath_open_at(subpath, at: svg_path.SubpathParameter(1, 0.5))

  assert !svg_path.subpath_is_closed(opened)
  assert svg_path.subpath_start(opened) == Ok(svg_path.Point(10.0, 5.0))
  assert svg_path.subpath_end(opened) == Ok(svg_path.Point(10.0, 5.0))
  assert svg_path.subpath_segments(opened)
    == [
      svg_path.Line(start: svg_path.Point(10.0, 5.0), end: c),
      svg_path.Line(start: c, end: d),
      svg_path.Line(start: d, end: a),
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: svg_path.Point(10.0, 5.0)),
    ]
}

pub fn open_at_accepts_last_segment_endpoint_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 10.0)
  let d = svg_path.Point(0.0, 10.0)
  let ab = svg_path.Line(start: a, end: b)
  let bc = svg_path.Line(start: b, end: c)
  let cd = svg_path.Line(start: c, end: d)
  let da = svg_path.Line(start: d, end: a)
  let segments = [ab, bc, cd, da]
  let subpath = closed_subpath(segments)

  let assert Ok(opened) =
    svg_path.subpath_open_at(subpath, at: svg_path.SubpathParameter(3, 1.0))

  assert svg_path.subpath_segments(opened) == segments
}

pub fn open_at_rejects_open_subpaths_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let subpath = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])

  assert svg_path.subpath_open_at(
      subpath,
      at: svg_path.SubpathParameter(0, 0.0),
    )
    == Error(svg_path.NotClosed)
}

pub fn open_at_rejects_invalid_parameters_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 10.0)
  let ab = svg_path.Line(start: a, end: b)
  let bc = svg_path.Line(start: b, end: c)
  let ca = svg_path.Line(start: c, end: a)
  let subpath = closed_subpath([ab, bc, ca])

  assert svg_path.subpath_open_at(
      subpath,
      at: svg_path.SubpathParameter(3, 0.0),
    )
    == Error(svg_path.InvalidSubpathParameter(
      segment_index: 3,
      t: 0.0,
      length: 3,
    ))
  assert svg_path.subpath_open_at(
      subpath,
      at: svg_path.SubpathParameter(0, -0.1),
    )
    == Error(svg_path.InvalidSubpathParameter(
      segment_index: 0,
      t: -0.1,
      length: 3,
    ))
}

pub fn set_closed_with_wiggle_replaces_nearby_endpoints_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let near_a = svg_path.Point(0.0000000001, 0.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: near_a),
    ])
    |> result_try_set_closed_with_wiggle

  assert svg_path.subpath_is_closed(subpath)
  assert svg_path.subpath_start(subpath) == svg_path.subpath_end(subpath)
}

pub fn set_closed_with_wiggle_rejects_misaligned_vertical_lines_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(0.0, 10.0)
  let c = svg_path.Point(0.0000000001, 0.0000000001)
  let d = svg_path.Point(0.0000000001, 0.00000000005)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ])

  assert svg_path.subpath_set_closed_with(
      subpath,
      closed: True,
      policy: svg_path.Wiggle,
    )
    == Error(svg_path.IncompatibleVerticalWiggle(previous_end: d, next_start: a))
}

pub fn set_closed_with_wiggle_rejects_misaligned_horizontal_lines_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(0.0000000001, 0.0000000001)
  let d = svg_path.Point(0.00000000005, 0.0000000001)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ])

  assert svg_path.subpath_set_closed_with(
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
      svg_path.subpath_append_segment_with(
        subpath,
        segment,
        policy: svg_path.Bridge,
      )
    Error(error) -> Error(error)
  }
}

fn closed_subpath(segments: List(svg_path.Segment)) -> svg_path.Subpath {
  svg_path.subpath_assert(segments)
  |> svg_path.subpath_assert_set_closed(closed: True)
}

fn result_try_set_closed_with_bridge(
  result_subpath: Result(svg_path.Subpath, svg_path.Error),
) -> Result(svg_path.Subpath, svg_path.Error) {
  case result_subpath {
    Ok(subpath) ->
      svg_path.subpath_set_closed_with(
        subpath,
        closed: True,
        policy: svg_path.Bridge,
      )
    Error(error) -> Error(error)
  }
}

fn result_try_set_closed_with_wiggle(
  result_subpath: Result(svg_path.Subpath, svg_path.Error),
) -> Result(svg_path.Subpath, svg_path.Error) {
  case result_subpath {
    Ok(subpath) ->
      svg_path.subpath_set_closed_with(
        subpath,
        closed: True,
        policy: svg_path.Wiggle,
      )
    Error(error) -> Error(error)
  }
}

fn line_from_start(segment: svg_path.Segment, start: svg_path.Point) {
  case segment {
    svg_path.Line(end:, ..) -> svg_path.Line(start:, end:)
    _ -> segment
  }
}

fn line_to_end(segment: svg_path.Segment, end: svg_path.Point) {
  case segment {
    svg_path.Line(start:, ..) -> svg_path.Line(start:, end:)
    _ -> segment
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

fn all_lines(segments: List(svg_path.Segment)) -> Bool {
  list.all(segments, fn(segment) {
    case segment {
      svg_path.Line(..) -> True
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

fn sampled_segment_within_lines(
  segment: svg_path.Segment,
  lines: List(svg_path.Segment),
  tolerance: Float,
  samples samples: Int,
) -> Bool {
  sampled_segment_within_lines_loop(
    segment,
    lines,
    tolerance,
    samples,
    index: 0,
  )
}

fn sampled_segment_within_lines_loop(
  segment: svg_path.Segment,
  lines: List(svg_path.Segment),
  tolerance: Float,
  samples: Int,
  index index: Int,
) -> Bool {
  case index > samples {
    True -> True
    False -> {
      let t = int.to_float(index) /. int.to_float(samples)
      let assert Ok(point) = svg_path.segment_point(segment, at: t)

      point_distance_to_lines(point, lines) <=. tolerance
      && sampled_segment_within_lines_loop(
        segment,
        lines,
        tolerance,
        samples,
        index: index + 1,
      )
    }
  }
}

fn point_distance_to_lines(
  point: svg_path.Point,
  lines: List(svg_path.Segment),
) -> Float {
  let assert [first, ..rest] = lines
  let assert Ok(first_distance) = svg_path.segment_distance(point, to: first)

  list.fold(rest, first_distance, fn(best, line) {
    let assert Ok(distance) = svg_path.segment_distance(point, to: line)
    float.min(best, distance)
  })
}

fn bbox_near(
  box: svg_path.BoundingBox,
  min expected_min: svg_path.Point,
  max expected_max: svg_path.Point,
) -> Bool {
  let svg_path.BoundingBox(min:, max:) = box
  point_near(min, expected_min) && point_near(max, expected_max)
}

fn center_arc_data_near(
  actual: ellipse.CenterArcData,
  expected: ellipse.CenterArcData,
) -> Bool {
  ellipse_point_near(actual.center, expected.center)
  && ellipse_point_near(actual.radius, expected.radius)
  && near(actual.x_axis_rotation, expected.x_axis_rotation)
  && near(actual.start_angle, expected.start_angle)
  && near(actual.delta_angle, expected.delta_angle)
}

fn ellipse_point_near(
  a: ellipse.EllipsePoint,
  b: ellipse.EllipsePoint,
) -> Bool {
  near(a.x, b.x) && near(a.y, b.y)
}

fn near(a: Float, b: Float) -> Bool {
  float.absolute_value(a -. b) <=. tolerance
}
