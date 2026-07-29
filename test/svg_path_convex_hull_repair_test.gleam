import gleam/float
import gleam/list
import gleam/option.{None}
import svg_path
import svg_path/convex_hull

const tolerance = 0.000001

pub fn seeded_worst_direction_stays_put_at_local_maximum_test() {
  let a = point_loop(svg_path.Point(0.0, 0.0))
  let b = point_loop(svg_path.Point(1.0, 0.0))

  let assert Ok(#(lower, upper)) =
    convex_hull.internal_find_seeded_worst_direction(
      a,
      b,
      direction: 0.0,
      threshold: 1.0,
    )

  assert near_float(lower, 0.0)
  assert near_float(upper, 0.0)
}

pub fn seeded_worst_direction_walks_to_local_maximum_test() {
  let a = point_loop(svg_path.Point(0.0, 0.0))
  let b = point_loop(svg_path.Point(1.0, 0.0))

  let assert Ok(#(lower, upper)) =
    convex_hull.internal_find_seeded_worst_direction(
      a,
      b,
      direction: 5.0,
      threshold: 10.0,
    )

  assert near_float(lower, 0.0)
  assert near_float(upper, 0.0)
}

pub fn seeded_worst_direction_stays_within_max_drift_test() {
  let a = point_loop(svg_path.Point(0.0, 0.0))
  let b = point_loop(svg_path.Point(1.0, 0.0))

  let assert Ok(#(lower, upper)) =
    convex_hull.internal_find_seeded_worst_direction(
      a,
      b,
      direction: 5.0,
      threshold: 1.0,
    )

  assert near_float(lower, 4.0)
  assert near_float(upper, 4.0)
}

pub fn loop_initial_sample_angles_merges_sorted_seed_angles_test() {
  assert convex_hull.internal_loop_initial_sample_angles(4, seed_angles: [
      45.0,
      225.0,
    ])
    == [0.0, 45.0, 90.0, 180.0, 225.0, 270.0]
}

pub fn loop_initial_sample_angles_normalizes_seed_angles_test() {
  assert convex_hull.internal_loop_initial_sample_angles(4, seed_angles: [
      -90.0,
      405.0,
    ])
    == [0.0, 45.0, 90.0, 180.0, 270.0]
}

pub fn loop_initial_sample_angles_removes_near_seed_angles_test() {
  assert convex_hull.internal_loop_initial_sample_angles(4, seed_angles: [
      45.0,
      45.01,
    ])
    == [0.0, 45.0, 90.0, 180.0, 270.0]
}

pub fn loop_initial_sample_angles_removes_wraparound_duplicates_test() {
  assert convex_hull.internal_loop_initial_sample_angles(4, seed_angles: [
      -0.0005,
    ])
    == [0.0, 90.0, 180.0, 270.0]
}

pub fn loop_union_with_seed_angles_removes_zero_length_endpoint_pieces_test() {
  let segments =
    convex_hull.internal_loop_union_segments_with_seed_angles(
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
    convex_hull.internal_ambitious_repair_loop_with_loop(
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

pub fn path_hull_handles_scaled_two_arc_probe_test() {
  let large_arc =
    svg_path.Arc(
      start: svg_path.Point(1000.0, 0.0),
      radius: svg_path.Point(1000.0, 1000.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(999.84769516, 17.45240644),
    )
  let small_arc =
    svg_path.Arc(
      start: svg_path.Point(999.94340504, 7.63106966),
      radius: svg_path.Point(30.0, 30.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(999.92428935, 9.82151131),
    )
  let assert Ok(large_subpath) = svg_path.subpath([large_arc])
  let assert Ok(small_subpath) = svg_path.subpath([small_arc])

  let assert Ok(hull) =
    convex_hull.path_hull(svg_path.Path([large_subpath, small_subpath]))

  assert svg_path.subpath_is_closed(hull)
}

// This line/arc probe covers a narrow arc whose visible hull slice can sit
// between the first-pass sample angles. Dumb repair should still return a
// valid closed hull by adding visible arc endpoints as points, usually yielding
// a line-only triangle. Ambitious repair should reseed the loop union near the
// missed support directions and preserve a small arc slice in the final hull.
pub fn path_hull_with_dumb_repair_mode_handles_line_arc_probe_test() {
  let assert Ok(hull) =
    convex_hull.internal_path_hull_with_repair_mode(
      line_arc_probe_path(),
      repair_mode: "dumb",
    )

  assert svg_path.subpath_is_closed(hull)
  assert line_arc_probe_arc_endpoints_are_inside_hull(hull)
}

pub fn path_hull_with_ambitious_repair_mode_handles_line_arc_probe_test() {
  let assert Ok(hull) =
    convex_hull.internal_path_hull_with_repair_mode(
      line_arc_probe_path(),
      repair_mode: "ambitious",
    )

  assert svg_path.subpath_is_closed(hull)
  assert line_arc_probe_arc_endpoints_are_inside_hull(hull)
  assert svg_path.subpath_segments(hull)
    |> list.any(fn(segment) {
      case segment {
        svg_path.Arc(..) -> True
        _ -> False
      }
    })
}

fn big_line_loop() -> List(svg_path.Segment) {
  let start = svg_path.Point(1000.0, 0.0)
  let end = svg_path.Point(999.84769516, 17.45240644)

  [
    svg_path.Line(start:, end:),
    svg_path.Line(start: end, end: start),
  ]
}

fn tiny_arc_loop() -> List(svg_path.Segment) {
  let start = svg_path.Point(999.94340504, 7.63106966)
  let end = svg_path.Point(999.92428935, 9.82151131)
  let arc =
    svg_path.Arc(
      start:,
      radius: svg_path.Point(30.0, 30.0),
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
      start: svg_path.Point(1000.0, 0.0),
      end: svg_path.Point(999.84769516, 17.45240644),
    )
  let arc =
    svg_path.Arc(
      start: svg_path.Point(999.94340504, 7.63106966),
      radius: svg_path.Point(30.0, 30.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(999.92428935, 9.82151131),
    )

  svg_path.Path([
    svg_path.subpath_assert([line]),
    svg_path.subpath_assert([arc]),
  ])
}

fn line_arc_probe_arc_endpoints_are_inside_hull(
  hull: svg_path.Subpath,
) -> Bool {
  line_arc_probe_arc_endpoints()
  |> list.all(fn(point) {
    convex_hull.internal_point_chord_polygon_loop_separation(
      svg_path.subpath_segments(hull),
      point:,
    )
    == None
  })
}

fn line_arc_probe_arc_endpoints() -> List(svg_path.Point) {
  [
    svg_path.Point(999.94340504, 7.63106966),
    svg_path.Point(999.92428935, 9.82151131),
  ]
}

fn point_loop(point: svg_path.Point) -> List(svg_path.Segment) {
  [
    svg_path.Line(start: point, end: point),
    svg_path.Line(start: point, end: point),
  ]
}

fn near_float(value: Float, expected: Float) -> Bool {
  float.absolute_value(value -. expected) <=. tolerance
}

fn points_near(a: svg_path.Point, b: svg_path.Point) -> Bool {
  near_float(a.x, b.x) && near_float(a.y, b.y)
}
