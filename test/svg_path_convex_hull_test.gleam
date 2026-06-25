import gleam/float
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import svg_path
import svg_path/convex_hull

const tolerance = 0.000001

pub fn segment_hull_returns_closed_subpath_for_line_test() {
  let segment =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )
  let assert Ok(subpath) = convex_hull.segment_hull(segment)

  assert svg_path.is_closed(subpath)
  assert list.length(svg_path.segments(subpath)) == 2
  assert support_values_match(segment, subpath)
}

pub fn segment_hull_returns_closed_hull_for_quadratic_test() {
  let segment =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(5.0, 10.0),
      end: svg_path.point(10.0, 0.0),
    )
  let assert Ok(subpath) = convex_hull.segment_hull(segment)

  assert svg_path.is_closed(subpath)
  assert list.length(svg_path.segments(subpath)) == 2
  assert support_values_match(segment, subpath)
}

pub fn subpath_hull_returns_closed_hull_for_l_shaped_polyline_test() {
  let segments = [
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(20.0, 0.0),
    ),
    svg_path.Line(
      start: svg_path.point(20.0, 0.0),
      end: svg_path.point(20.0, 15.0),
    ),
  ]
  let assert Ok(subpath) = svg_path.subpath(segments)
  let assert Ok(hull) = convex_hull.subpath_hull(subpath)

  assert svg_path.is_closed(hull)
  assert list.length(svg_path.segments(hull)) >= 3
  assert subpath_support_matches(segments, hull)
}

pub fn subpath_hull_treats_empty_subpath_as_single_point_test() {
  let point = svg_path.point(4.0, -3.0)
  let assert Ok(hull) =
    convex_hull.subpath_hull(svg_path.empty_subpath(at: point))

  assert svg_path.is_closed(hull)
  assert svg_path.segments(hull)
    == svg_path.segments(svg_path.assert_set_closed(
      svg_path.assert_subpath([
        svg_path.Line(start: point, end: point),
        svg_path.Line(start: point, end: point),
      ]),
      closed: True,
    ))
}

pub fn path_hull_includes_empty_subpath_start_points_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(2.0, 0.0)
  let far = svg_path.point(10.0, 0.0)
  let path =
    svg_path.Path([
      svg_path.assert_subpath([svg_path.Line(start: a, end: b)]),
      svg_path.empty_subpath(at: far),
    ])
  let assert Ok(hull) = convex_hull.path_hull(path)

  assert svg_path.is_closed(hull)
  assert near_value(hull_support_value(svg_path.segments(hull), 0.0), 10.0)
}

pub fn path_hull_rejects_empty_path_test() {
  assert convex_hull.path_hull(svg_path.empty_path())
    == Error(convex_hull.PathError(svg_path.EmptyPath))
}

pub fn seeded_worst_direction_stays_put_at_local_maximum_test() {
  let a = point_loop(svg_path.point(0.0, 0.0))
  let b = point_loop(svg_path.point(1.0, 0.0))

  let assert Ok(#(lower, upper)) =
    convex_hull.test_find_seeded_worst_direction(
      a,
      b,
      direction: 0.0,
      threshold: 1.0,
    )

  assert near_float(lower, 0.0)
  assert near_float(upper, 0.0)
}

pub fn seeded_worst_direction_walks_to_local_maximum_test() {
  let a = point_loop(svg_path.point(0.0, 0.0))
  let b = point_loop(svg_path.point(1.0, 0.0))

  let assert Ok(#(lower, upper)) =
    convex_hull.test_find_seeded_worst_direction(
      a,
      b,
      direction: 5.0,
      threshold: 10.0,
    )

  assert near_float(lower, 0.0)
  assert near_float(upper, 0.0)
}

pub fn seeded_worst_direction_stays_within_max_drift_test() {
  let a = point_loop(svg_path.point(0.0, 0.0))
  let b = point_loop(svg_path.point(1.0, 0.0))

  let assert Ok(#(lower, upper)) =
    convex_hull.test_find_seeded_worst_direction(
      a,
      b,
      direction: 5.0,
      threshold: 1.0,
    )

  assert near_float(lower, 4.0)
  assert near_float(upper, 4.0)
}

pub fn loop_initial_sample_angles_merges_sorted_seed_angles_test() {
  assert convex_hull.test_loop_initial_sample_angles(4, seed_angles: [
      45.0,
      225.0,
    ])
    == [0.0, 45.0, 90.0, 180.0, 225.0, 270.0]
}

pub fn loop_initial_sample_angles_normalizes_seed_angles_test() {
  assert convex_hull.test_loop_initial_sample_angles(4, seed_angles: [
      -90.0,
      405.0,
    ])
    == [0.0, 45.0, 90.0, 180.0, 270.0]
}

pub fn loop_initial_sample_angles_removes_near_seed_angles_test() {
  assert convex_hull.test_loop_initial_sample_angles(4, seed_angles: [
      45.0,
      45.01,
    ])
    == [0.0, 45.0, 90.0, 180.0, 270.0]
}

pub fn loop_initial_sample_angles_removes_wraparound_duplicates_test() {
  assert convex_hull.test_loop_initial_sample_angles(4, seed_angles: [
      -0.0005,
    ])
    == [0.0, 90.0, 180.0, 270.0]
}

pub fn loop_union_with_seed_angles_removes_zero_length_endpoint_pieces_test() {
  let segments =
    convex_hull.test_loop_union_segments_with_seed_angles(
      big_line_loop(),
      tiny_arc_loop(),
      seed_angles: [
        0.49724434278326146,
        0.5027556573338349,
      ],
    )

  assert list.length(segments) == 4
  assert segments
    |> list.all(fn(segment) {
      points_near(
        svg_path.segment_start(segment),
        svg_path.segment_end(segment),
      )
      == False
    })
}

pub fn ambitious_repair_loop_with_loop_adds_tiny_arc_slice_test() {
  let assert Ok(segments) =
    convex_hull.test_ambitious_repair_loop_with_loop(
      big_line_loop(),
      addition: tiny_arc_loop(),
    )

  assert list.length(segments) == 4
  assert segments
    |> list.any(fn(segment) {
      case segment {
        svg_path.Arc(..) -> True
        _ -> False
      }
    })
}

pub fn point_chord_polygon_loop_separation_returns_none_for_inside_polygon_point_test() {
  let loop = square_loop()
  assert convex_hull.test_point_chord_polygon_loop_separation(
      loop,
      point: svg_path.point(5.0, 5.0),
    )
    == None
}

pub fn point_chord_polygon_loop_separation_returns_none_for_boundary_polygon_point_test() {
  let loop = square_loop()
  assert convex_hull.test_point_chord_polygon_loop_separation(
      loop,
      point: svg_path.point(10.0, 5.0),
    )
    == None
}

pub fn point_chord_polygon_loop_separation_finds_closest_point_on_polygon_edge_test() {
  let loop = square_loop()
  let assert Some(#(angle, closest)) =
    convex_hull.test_point_chord_polygon_loop_separation(
      loop,
      point: svg_path.point(15.0, 5.0),
    )

  assert near_float(angle, 0.0)
  assert points_near(closest, svg_path.point(10.0, 5.0))
}

pub fn point_chord_polygon_loop_separation_handles_clockwise_polygon_test() {
  let loop = clockwise_square_loop()
  let assert Some(#(angle, closest)) =
    convex_hull.test_point_chord_polygon_loop_separation(
      loop,
      point: svg_path.point(15.0, 5.0),
    )

  assert near_float(angle, 0.0)
  assert points_near(closest, svg_path.point(10.0, 5.0))
}

pub fn point_chord_polygon_loop_separation_finds_closest_point_on_polygon_vertex_test() {
  let loop = square_loop()
  let assert Some(#(angle, closest)) =
    convex_hull.test_point_chord_polygon_loop_separation(
      loop,
      point: svg_path.point(15.0, 15.0),
    )

  assert near_float(angle, 45.0)
  assert points_near(closest, svg_path.point(10.0, 10.0))
}

pub fn point_chord_polygon_loop_separation_handles_point_like_loop_test() {
  let point = svg_path.point(2.0, 3.0)
  let loop = [
    svg_path.Line(start: point, end: point),
    svg_path.Line(start: point, end: point),
  ]
  let assert Some(#(angle, closest)) =
    convex_hull.test_point_chord_polygon_loop_separation(
      loop,
      point: svg_path.point(7.0, 3.0),
    )

  assert near_float(angle, 0.0)
  assert points_near(closest, point)
}

pub fn point_chord_polygon_loop_separation_handles_line_like_loop_test() {
  let loop = [
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    ),
    svg_path.Line(
      start: svg_path.point(10.0, 0.0),
      end: svg_path.point(0.0, 0.0),
    ),
  ]
  let assert Some(#(angle, closest)) =
    convex_hull.test_point_chord_polygon_loop_separation(
      loop,
      point: svg_path.point(5.0, 4.0),
    )

  assert near_float(angle, 90.0)
  assert points_near(closest, svg_path.point(5.0, 0.0))
}

pub fn point_loop_view_classifies_ccw_outside_arc_point_test() {
  assert convex_hull.test_point_loop_view(
      point: svg_path.point(15.0, 5.0),
      at: svg_path.point(10.0, 5.0),
      arriving: svg_path.point(0.0, 1.0),
      leaving: svg_path.point(0.0, 1.0),
      clockwise: False,
    )
    == convex_hull.OutsidePoint
}

pub fn point_loop_view_classifies_ccw_inside_arc_point_test() {
  assert convex_hull.test_point_loop_view(
      point: svg_path.point(15.0, 5.0),
      at: svg_path.point(0.0, 5.0),
      arriving: svg_path.point(0.0, -1.0),
      leaving: svg_path.point(0.0, -1.0),
      clockwise: False,
    )
    == convex_hull.InsidePoint
}

pub fn point_loop_view_classifies_ccw_tangent_corner_test() {
  assert convex_hull.test_point_loop_view(
      point: svg_path.point(15.0, 5.0),
      at: svg_path.point(10.0, 10.0),
      arriving: svg_path.point(0.0, 1.0),
      leaving: svg_path.point(-1.0, 0.0),
      clockwise: False,
    )
    == convex_hull.TangentPoint
}

pub fn point_loop_view_classifies_clockwise_outside_arc_point_test() {
  assert convex_hull.test_point_loop_view(
      point: svg_path.point(15.0, 5.0),
      at: svg_path.point(10.0, 5.0),
      arriving: svg_path.point(0.0, -1.0),
      leaving: svg_path.point(0.0, -1.0),
      clockwise: True,
    )
    == convex_hull.OutsidePoint
}

pub fn point_chord_polygon_tangent_subpaths_split_square_test() {
  let assert Ok(#(outside, inside)) =
    convex_hull.test_point_chord_polygon_tangent_subpaths(
      square_loop(),
      point: svg_path.point(15.0, 5.0),
    )

  assert points_near(subpath_start(outside), svg_path.point(10.0, 0.0))
  assert points_near(subpath_end(outside), svg_path.point(10.0, 10.0))
  assert list.length(svg_path.segments(outside)) == 1
  assert points_near(subpath_start(inside), svg_path.point(10.0, 10.0))
  assert points_near(subpath_end(inside), svg_path.point(10.0, 0.0))
  assert list.length(svg_path.segments(inside)) == 3
}

pub fn point_chord_polygon_tangent_subpaths_reject_nonconvex_loop_test() {
  let loop = [
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    ),
    svg_path.Line(
      start: svg_path.point(10.0, 0.0),
      end: svg_path.point(5.0, 5.0),
    ),
    svg_path.Line(
      start: svg_path.point(5.0, 5.0),
      end: svg_path.point(10.0, 10.0),
    ),
    svg_path.Line(
      start: svg_path.point(10.0, 10.0),
      end: svg_path.point(0.0, 10.0),
    ),
    svg_path.Line(
      start: svg_path.point(0.0, 10.0),
      end: svg_path.point(0.0, 0.0),
    ),
  ]

  assert convex_hull.test_point_chord_polygon_tangent_subpaths(
      loop,
      point: svg_path.point(15.0, 5.0),
    )
    == Error(convex_hull.TangentSearchNonConvexVertex(2))
}

pub fn point_exact_loop_tangent_subpaths_split_square_test() {
  let assert Ok(#(outside, inside)) =
    convex_hull.test_point_exact_loop_tangent_subpaths(
      square_loop(),
      point: svg_path.point(15.0, 5.0),
    )

  assert points_near(subpath_start(outside), svg_path.point(10.0, 0.0))
  assert points_near(subpath_end(outside), svg_path.point(10.0, 10.0))
  assert list.length(svg_path.segments(outside)) == 1
  assert points_near(subpath_start(inside), svg_path.point(10.0, 10.0))
  assert points_near(subpath_end(inside), svg_path.point(10.0, 0.0))
  assert list.length(svg_path.segments(inside)) == 3
}

pub fn point_exact_loop_tangent_subpaths_finds_quadratic_interior_tangencies_test() {
  let assert Ok(#(outside, inside)) =
    convex_hull.test_point_exact_loop_tangent_subpaths(
      rounded_triangle_loop(),
      point: svg_path.point(14.0, 5.0),
    )

  let root_offset = {
    let assert Ok(root) = float.square_root(15.0)
    root
  }
  let lower = svg_path.point(11.0, 5.0 -. root_offset)
  let upper = svg_path.point(11.0, 5.0 +. root_offset)

  assert points_near(subpath_start(outside), lower)
  assert points_near(subpath_end(outside), upper)
  assert list.length(svg_path.segments(outside)) == 1
  assert points_near(subpath_start(inside), upper)
  assert points_near(subpath_end(inside), lower)
  assert list.length(svg_path.segments(inside)) == 4
}

pub fn loop_plus_point_hull_replaces_visible_square_edge_test() {
  let point = svg_path.point(15.0, 5.0)
  let assert Ok(segments) =
    convex_hull.test_loop_plus_point_hull(square_loop(), point:)

  assert list.length(segments) == 5
  let assert [first, _, _, connector_to_point, connector_from_point] = segments
  assert points_near(svg_path.segment_start(first), svg_path.point(10.0, 10.0))
  assert points_near(svg_path.segment_end(first), svg_path.point(0.0, 10.0))
  assert points_near(svg_path.segment_end(connector_to_point), point)
  assert points_near(svg_path.segment_start(connector_from_point), point)
  assert points_near(
    svg_path.segment_end(connector_from_point),
    svg_path.point(10.0, 10.0),
  )
}

pub fn loop_plus_point_hull_handles_quadratic_interior_tangencies_test() {
  let point = svg_path.point(14.0, 5.0)
  let assert Ok(segments) =
    convex_hull.test_loop_plus_point_hull(rounded_triangle_loop(), point:)

  let root_offset = {
    let assert Ok(root) = float.square_root(15.0)
    root
  }
  let lower = svg_path.point(11.0, 5.0 -. root_offset)
  let upper = svg_path.point(11.0, 5.0 +. root_offset)

  assert list.length(segments) == 6
  let assert Ok(first) = list.first(segments)
  let assert Ok(last) = list.last(segments)
  assert points_near(svg_path.segment_start(first), upper)
  assert points_near(svg_path.segment_start(last), point)
  assert points_near(svg_path.segment_end(last), upper)
  assert segments
    |> list.any(fn(segment) {
      points_near(svg_path.segment_start(segment), lower)
      && points_near(svg_path.segment_end(segment), point)
    })
}

pub fn loop_plus_points_hull_absorbs_outside_points_in_order_test() {
  let points = [
    svg_path.point(5.0, 5.0),
    svg_path.point(15.0, 5.0),
    svg_path.point(5.0, 15.0),
  ]
  let assert Ok(segments) =
    convex_hull.test_loop_plus_points_hull(square_loop(), points:)

  assert list.length(segments) == 6
  points
  |> list.each(fn(point) {
    assert convex_hull.test_point_chord_polygon_loop_separation(
        segments,
        point:,
      )
      == None
  })
}

pub fn loop_plus_point_hull_handles_line_like_loop_test() {
  let point = svg_path.point(5.0, 4.0)
  let assert Ok(segments) =
    convex_hull.test_loop_plus_point_hull(line_like_loop(), point:)

  assert list.length(segments) == 3
  assert segments
    |> list.any(fn(segment) {
      points_near(svg_path.segment_start(segment), point)
      || points_near(svg_path.segment_end(segment), point)
    })
}

pub fn loop_plus_point_hull_rejects_conflicting_tangent_orientation_test() {
  let point = svg_path.point(5.0, 4.0)

  assert convex_hull.test_loop_plus_point_hull(
      conflicting_tangent_line_like_loop(),
      point:,
    )
    == Error(convex_hull.TangentSearchDegenerateLoop)
}

pub fn path_hull_handles_scaled_two_arc_probe_test() {
  let large_arc =
    svg_path.Arc(
      start: svg_path.point(1000.0, 0.0),
      radius: svg_path.point(1000.0, 1000.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(999.84769516, 17.45240644),
    )
  let small_arc =
    svg_path.Arc(
      start: svg_path.point(999.94340504, 7.63106966),
      radius: svg_path.point(30.0, 30.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(999.92428935, 9.82151131),
    )
  let assert Ok(large_subpath) = svg_path.subpath([large_arc])
  let assert Ok(small_subpath) = svg_path.subpath([small_arc])

  let assert Ok(hull) =
    convex_hull.path_hull(svg_path.Path([large_subpath, small_subpath]))

  assert svg_path.is_closed(hull)
}

// This line/arc probe covers a narrow arc whose visible hull slice can sit
// between the first-pass sample angles. Dumb repair should still return a
// valid closed hull by adding visible arc endpoints as points, usually yielding
// a line-only triangle. Ambitious repair should reseed the loop union near the
// missed support directions and preserve a small arc slice in the final hull.
pub fn path_hull_with_dumb_repair_mode_handles_line_arc_probe_test() {
  let assert Ok(hull) =
    convex_hull.test_path_hull_with_repair_mode(
      line_arc_probe_path(),
      repair_mode: "dumb",
    )

  assert svg_path.is_closed(hull)
  assert line_arc_probe_arc_endpoints_are_inside_hull(hull)
}

pub fn path_hull_with_ambitious_repair_mode_handles_line_arc_probe_test() {
  let assert Ok(hull) =
    convex_hull.test_path_hull_with_repair_mode(
      line_arc_probe_path(),
      repair_mode: "ambitious",
    )

  assert svg_path.is_closed(hull)
  assert line_arc_probe_arc_endpoints_are_inside_hull(hull)
  assert svg_path.segments(hull)
    |> list.any(fn(segment) {
      case segment {
        svg_path.Arc(..) -> True
        _ -> False
      }
    })
}

pub fn point_exact_loop_tangent_subpaths_finds_cubic_interior_tangencies_test() {
  let loop = [
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.point(10.0, 0.0),
      control1: svg_path.point(15.0, 2.0),
      control2: svg_path.point(15.0, 8.0),
      end: svg_path.point(10.0, 10.0),
    ),
    svg_path.Line(
      start: svg_path.point(10.0, 10.0),
      end: svg_path.point(0.0, 0.0),
    ),
  ]

  let assert Ok(#(outside, inside)) =
    convex_hull.test_point_exact_loop_tangent_subpaths(
      loop,
      point: svg_path.point(14.0, 5.0),
    )

  assert points_near(
    subpath_start(outside),
    svg_path.point(13.510530985333089, 3.4999239353568505),
  )
  assert points_near(
    subpath_end(outside),
    svg_path.point(13.510530985333087, 6.5000760646431495),
  )
  assert list.length(svg_path.segments(outside)) == 1
  assert points_near(
    subpath_start(inside),
    svg_path.point(13.510530985333087, 6.5000760646431495),
  )
  assert points_near(
    subpath_end(inside),
    svg_path.point(13.510530985333089, 3.4999239353568505),
  )
  assert list.length(svg_path.segments(inside)) == 4
}

pub fn point_exact_loop_tangent_subpaths_finds_arc_interior_tangencies_test() {
  let loop = [
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    ),
    svg_path.Arc(
      start: svg_path.point(10.0, 0.0),
      radius: svg_path.point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(10.0, 10.0),
    ),
    svg_path.Line(
      start: svg_path.point(10.0, 10.0),
      end: svg_path.point(0.0, 0.0),
    ),
  ]
  let root_offset = {
    let assert Ok(root) = float.square_root(18.75)
    root
  }
  let lower = svg_path.point(12.5, 5.0 -. root_offset)
  let upper = svg_path.point(12.5, 5.0 +. root_offset)

  let assert Ok(#(outside, inside)) =
    convex_hull.test_point_exact_loop_tangent_subpaths(
      loop,
      point: svg_path.point(20.0, 5.0),
    )

  assert points_near(subpath_start(outside), lower)
  assert points_near(subpath_end(outside), upper)
  assert list.length(svg_path.segments(outside)) == 1
  assert points_near(subpath_start(inside), upper)
  assert points_near(subpath_end(inside), lower)
  assert list.length(svg_path.segments(inside)) == 4
}

pub fn segment_tangent_monotone_accepts_lines_test() {
  let segment =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  assert_monotone(segment, clockwise: False)
  assert_monotone(segment, clockwise: True)
}

pub fn segment_tangent_monotone_checks_quadratic_orientation_test() {
  let counterclockwise =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(1.0, -1.0),
      end: svg_path.point(2.0, 0.0),
    )
  let clockwise =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(1.0, 1.0),
      end: svg_path.point(2.0, 0.0),
    )

  assert_monotone(counterclockwise, clockwise: False)
  assert_not_monotone(counterclockwise, clockwise: True, by_at_least: 2.0)
  assert_monotone(clockwise, clockwise: True)
  assert_not_monotone(clockwise, clockwise: False, by_at_least: 2.0)
}

pub fn segment_tangent_monotone_accepts_monotone_cubic_test() {
  let segment =
    svg_path.CubicBezier(
      start: svg_path.point(1.0, 0.0),
      control1: svg_path.point(1.0, 0.5),
      control2: svg_path.point(0.5, 1.0),
      end: svg_path.point(0.0, 1.0),
    )

  assert_monotone(segment, clockwise: False)
  assert_not_monotone(segment, clockwise: True, by_at_least: 0.3)
}

pub fn segment_tangent_monotone_rejects_sign_changing_cubic_test() {
  let segment =
    svg_path.CubicBezier(
      start: svg_path.point(0.0, 0.0),
      control1: svg_path.point(1.0, 1.0),
      control2: svg_path.point(1.0, -1.0),
      end: svg_path.point(2.0, 0.0),
    )

  assert_not_monotone(segment, clockwise: False, by_at_least: 4.0)
  assert_not_monotone(segment, clockwise: True, by_at_least: 4.0)
}

pub fn segment_tangent_monotone_checks_arc_sweep_test() {
  let counterclockwise =
    svg_path.Arc(
      start: svg_path.point(1.0, 0.0),
      radius: svg_path.point(1.0, 1.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(0.0, 1.0),
    )
  let clockwise =
    svg_path.Arc(
      start: svg_path.point(1.0, 0.0),
      radius: svg_path.point(1.0, 1.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: False,
      end: svg_path.point(0.0, -1.0),
    )

  assert_monotone(counterclockwise, clockwise: False)
  assert_not_monotone(counterclockwise, clockwise: True, by_at_least: 1.0)
  assert_monotone(clockwise, clockwise: True)
  assert_not_monotone(clockwise, clockwise: False, by_at_least: 1.0)
}

fn square_loop() -> List(svg_path.Segment) {
  [
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    ),
    svg_path.Line(
      start: svg_path.point(10.0, 0.0),
      end: svg_path.point(10.0, 10.0),
    ),
    svg_path.Line(
      start: svg_path.point(10.0, 10.0),
      end: svg_path.point(0.0, 10.0),
    ),
    svg_path.Line(
      start: svg_path.point(0.0, 10.0),
      end: svg_path.point(0.0, 0.0),
    ),
  ]
}

fn clockwise_square_loop() -> List(svg_path.Segment) {
  [
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(0.0, 10.0),
    ),
    svg_path.Line(
      start: svg_path.point(0.0, 10.0),
      end: svg_path.point(10.0, 10.0),
    ),
    svg_path.Line(
      start: svg_path.point(10.0, 10.0),
      end: svg_path.point(10.0, 0.0),
    ),
    svg_path.Line(
      start: svg_path.point(10.0, 0.0),
      end: svg_path.point(0.0, 0.0),
    ),
  ]
}

fn rounded_triangle_loop() -> List(svg_path.Segment) {
  [
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    ),
    svg_path.QuadraticBezier(
      start: svg_path.point(10.0, 0.0),
      control: svg_path.point(15.0, 5.0),
      end: svg_path.point(10.0, 10.0),
    ),
    svg_path.Line(
      start: svg_path.point(10.0, 10.0),
      end: svg_path.point(0.0, 0.0),
    ),
  ]
}

fn line_like_loop() -> List(svg_path.Segment) {
  [
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    ),
    svg_path.Line(
      start: svg_path.point(10.0, 0.0),
      end: svg_path.point(0.0, 0.0),
    ),
  ]
}

fn conflicting_tangent_line_like_loop() -> List(svg_path.Segment) {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)

  [
    svg_path.CubicBezier(
      start: a,
      control1: svg_path.point(10.0 /. 3.0, 10.0 /. 3.0),
      control2: svg_path.point(20.0 /. 3.0, 10.0 /. 3.0),
      end: b,
    ),
    svg_path.CubicBezier(
      start: b,
      control1: svg_path.point(20.0 /. 3.0, 0.0),
      control2: svg_path.point(-10.0 /. 3.0, 0.0),
      end: a,
    ),
  ]
}

fn big_line_loop() -> List(svg_path.Segment) {
  let start = svg_path.point(1000.0, 0.0)
  let end = svg_path.point(999.84769516, 17.45240644)

  [
    svg_path.Line(start:, end:),
    svg_path.Line(start: end, end: start),
  ]
}

fn tiny_arc_loop() -> List(svg_path.Segment) {
  let start = svg_path.point(999.94340504, 7.63106966)
  let end = svg_path.point(999.92428935, 9.82151131)
  let arc =
    svg_path.Arc(
      start:,
      radius: svg_path.point(30.0, 30.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end:,
    )

  [
    arc,
    svg_path.Line(start: end, end: start),
  ]
}

fn line_arc_probe_path() -> svg_path.Path {
  let line =
    svg_path.Line(
      start: svg_path.point(1000.0, 0.0),
      end: svg_path.point(999.84769516, 17.45240644),
    )
  let arc =
    svg_path.Arc(
      start: svg_path.point(999.94340504, 7.63106966),
      radius: svg_path.point(30.0, 30.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(999.92428935, 9.82151131),
    )

  svg_path.Path([
    svg_path.assert_subpath([line]),
    svg_path.assert_subpath([arc]),
  ])
}

fn line_arc_probe_arc_endpoints_are_inside_hull(hull: svg_path.Subpath) -> Bool {
  line_arc_probe_arc_endpoints()
  |> list.all(fn(point) {
    convex_hull.test_point_chord_polygon_loop_separation(
      svg_path.segments(hull),
      point:,
    )
    == None
  })
}

fn line_arc_probe_arc_endpoints() -> List(svg_path.Point) {
  [
    svg_path.point(999.94340504, 7.63106966),
    svg_path.point(999.92428935, 9.82151131),
  ]
}

fn support_values_match(
  segment: svg_path.Segment,
  hull: svg_path.Subpath,
) -> Bool {
  [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
  |> list.all(fn(angle) {
    case
      convex_hull.test_segment_support(segment, angle: angle),
      hull_support_value(svg_path.segments(hull), angle)
    {
      Ok(#(_, _, original)), Ok(hull) ->
        float.absolute_value(original -. hull) <=. tolerance
      _, _ -> False
    }
  })
}

fn subpath_support_matches(
  original_segments: List(svg_path.Segment),
  hull: svg_path.Subpath,
) -> Bool {
  [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
  |> list.all(fn(angle) {
    case
      hull_support_value(original_segments, angle),
      hull_support_value(svg_path.segments(hull), angle)
    {
      Ok(original), Ok(hull) ->
        float.absolute_value(original -. hull) <=. tolerance
      _, _ -> False
    }
  })
}

fn hull_support_value(
  segments: List(svg_path.Segment),
  angle: Float,
) -> Result(Float, svg_path.Error) {
  case segments {
    [] -> Error(svg_path.EmptySubpath)
    [first, ..rest] -> {
      use first <- result.try(convex_hull.test_segment_support(first, angle:))
      let #(_, _, first_value) = first
      rest
      |> list.fold(Ok(first_value), fn(best, segment) {
        use best <- result.try(best)
        use sample <- result.try(convex_hull.test_segment_support(
          segment,
          angle:,
        ))
        let #(_, _, value) = sample
        Ok(float.max(best, value))
      })
    }
  }
}

fn near_value(value: Result(Float, svg_path.Error), expected: Float) -> Bool {
  case value {
    Ok(value) -> float.absolute_value(value -. expected) <=. tolerance
    Error(_) -> False
  }
}

fn subpath_start(subpath: svg_path.Subpath) -> svg_path.Point {
  let assert Ok(point) = svg_path.start(subpath)
  point
}

fn subpath_end(subpath: svg_path.Subpath) -> svg_path.Point {
  let assert Ok(point) = svg_path.end(subpath)
  point
}

fn point_loop(point: svg_path.Point) -> List(svg_path.Segment) {
  [
    svg_path.Line(start: point, end: point),
    svg_path.Line(start: point, end: point),
  ]
}

fn assert_monotone(
  segment: svg_path.Segment,
  clockwise clockwise: Bool,
) -> Nil {
  assert convex_hull.test_segment_tangent_monotone(segment, clockwise:)
    == Ok(Nil)
}

fn assert_not_monotone(
  segment: svg_path.Segment,
  clockwise clockwise: Bool,
  by_at_least by_at_least: Float,
) -> Nil {
  let assert Error(violation) =
    convex_hull.test_segment_tangent_monotone(segment, clockwise:)
  assert violation >=. by_at_least
}

fn near_float(value: Float, expected: Float) -> Bool {
  float.absolute_value(value -. expected) <=. tolerance
}

fn points_near(a: svg_path.Point, b: svg_path.Point) -> Bool {
  near_float(a.x, b.x) && near_float(a.y, b.y)
}
