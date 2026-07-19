import gleam/float
import gleam/int
import gleam/list
import svg_path
import svg_path/offset
import svg_path/serialize

pub fn segment_offsets_line_to_the_right_of_direction_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  let assert Ok(offset) = offset.segment(line, distance: 2.0)

  assert svg_path.segments(offset)
    == [
      svg_path.Line(
        start: svg_path.point(0.0, -2.0),
        end: svg_path.point(10.0, -2.0),
      ),
    ]
}

pub fn segment_offsets_line_to_left_for_negative_distance_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(0.0, 10.0),
    )

  let assert Ok(offset) = offset.segment(line, distance: -3.0)

  assert svg_path.segments(offset)
    == [
      svg_path.Line(
        start: svg_path.point(-3.0, 0.0),
        end: svg_path.point(-3.0, 10.0),
      ),
    ]
}

pub fn segment_offsets_quadratic_to_cubic_pieces_within_tolerance_test() {
  let curve =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(50.0, -80.0),
      end: svg_path.point(100.0, 0.0),
    )
  let options =
    offset.Options(..offset.default_options(), tolerance: 0.001, samples: 12)

  let assert Ok(offset_subpath) =
    offset.segment_with(curve, distance: 5.0, options:)

  assert svg_path.segments(offset_subpath) != []
  assert max_offset_error(curve, offset_subpath, distance: 5.0) <=. 0.01
}

pub fn segment_offsets_arc_after_cubic_conversion_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.point(10.0, 0.0),
      radius: svg_path.point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(0.0, 10.0),
    )

  let assert Ok(offset_subpath) = offset.segment(arc, distance: 2.0)

  assert svg_path.segments(offset_subpath) != []
}

pub fn segment_rejects_invalid_options_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )
  let options = offset.Options(..offset.default_options(), tolerance: 0.0)

  assert offset.segment_with(line, distance: 1.0, options:)
    == Error(offset.InvalidTolerance(0.0))
}

pub fn segment_rejects_zero_length_line_test() {
  let line =
    svg_path.Line(
      start: svg_path.point(1.0, 2.0),
      end: svg_path.point(1.0, 2.0),
    )

  assert offset.segment(line, distance: 1.0)
    == Error(offset.DegenerateTangent(0.0))
}

pub fn subpath_untrimmed_offsets_open_polyline_with_bevel_join_test() {
  let subpath =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
    ])
  let options = offset.Options(..offset.default_options(), join: offset.Bevel)

  let assert Ok(offset_subpath) =
    offset.subpath_untrimmed_with(subpath, distance: 2.0, options:)

  assert serialize.subpath(offset_subpath) == "M 0 -2 H 10 L 12 0 V 10"
}

pub fn subpath_untrimmed_offsets_open_polyline_with_miter_join_by_default_test() {
  let subpath =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
    ])

  let assert Ok(offset_subpath) =
    offset.subpath_untrimmed(subpath, distance: 2.0)

  assert serialize.subpath(offset_subpath) == "M 0 -2 H 10 H 12 V 0 V 10"
}

pub fn subpath_untrimmed_offsets_open_polyline_with_round_join_test() {
  let subpath =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
    ])
  let options = offset.Options(..offset.default_options(), join: offset.Round)

  let assert Ok(offset_subpath) =
    offset.subpath_untrimmed_with(subpath, distance: 2.0, options:)

  assert has_arc(svg_path.segments(offset_subpath))
  assert serialize.subpath(offset_subpath)
    == "M 0 -2 H 10 A 2 2 0 0 1 12 0 V 10"
}

pub fn subpath_offsets_open_polyline_to_trimmed_intersection_test() {
  let subpath =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, -10.0),
    ])

  let assert Ok(offset_path) = offset.subpath(subpath, distance: 2.0)

  assert serialize.path(offset_path) == "M 0 -2 H 8 V -10"
}

pub fn subpath_offsets_closed_square_inset_test() {
  let square =
    svg_path.assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
      svg_path.point(0.0, 10.0),
    ])

  let assert Ok(offset_path) = offset.subpath(square, distance: -2.0)
  let assert [offset_subpath] = svg_path.subpaths(offset_path)

  assert svg_path.is_closed(offset_subpath)
  assert serialize.subpath(offset_subpath) == "M 2 2 H 8 V 8 H 2 Z"
}

pub fn subpath_untrimmed_offsets_closed_square_and_preserves_closed_state_test() {
  let square =
    svg_path.assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
      svg_path.point(0.0, 10.0),
    ])

  let assert Ok(offset_subpath) =
    offset.subpath_untrimmed(square, distance: 2.0)

  assert svg_path.is_closed(offset_subpath)
  assert list.length(svg_path.segments(offset_subpath)) == 12
}

pub fn path_untrimmed_offsets_every_subpath_test() {
  let first =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
    ])
  let second =
    svg_path.assert_polyline([
      svg_path.point(0.0, 10.0),
      svg_path.point(10.0, 10.0),
    ])
  let path = svg_path.Path(subpaths: [first, second])

  let assert Ok(offset_path) = offset.path_untrimmed(path, distance: 1.0)

  assert list.length(svg_path.subpaths(offset_path)) == 2
  assert serialize.path(offset_path) == "M 0 -1 H 10 M 0 9 H 10"
}

pub fn path_offsets_straight_subpaths_test() {
  let first =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, -10.0),
    ])
  let second =
    svg_path.assert_polyline([
      svg_path.point(0.0, 20.0),
      svg_path.point(10.0, 20.0),
      svg_path.point(10.0, 10.0),
    ])
  let path = svg_path.Path(subpaths: [first, second])

  let assert Ok(offset_path) = offset.path(path, distance: 2.0)

  assert list.length(svg_path.subpaths(offset_path)) == 2
  assert serialize.path(offset_path) == "M 0 -2 H 8 V -10 M 0 18 H 8 V 10"
}

pub fn subpath_between_open_line_returns_two_capless_sides_test() {
  let subpath =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
    ])

  let assert Ok(offset_path) =
    offset.subpath_between(subpath, distance_a: -1.0, distance_b: 2.0)

  assert list.length(svg_path.subpaths(offset_path)) == 2
  assert serialize.path(offset_path) == "M 0 1 H 10 M 0 -2 H 10"
}

pub fn subpath_between_closed_square_returns_two_closed_sides_test() {
  let square =
    svg_path.assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
      svg_path.point(0.0, 10.0),
    ])

  let assert Ok(offset_path) =
    offset.subpath_between(square, distance_a: -2.0, distance_b: 2.0)
  let assert [inner, outer] = svg_path.subpaths(offset_path)

  assert svg_path.is_closed(inner)
  assert svg_path.is_closed(outer)
  assert serialize.path(offset_path)
    == "M 2 2 H 8 V 8 H 2 Z M 0 -2 H 10 H 12 V 0 V 10 V 12 H 10 H 0 H -2 V 10 V 0 V -2 Z"
}

pub fn path_between_offsets_every_subpath_on_both_sides_test() {
  let first =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
    ])
  let second =
    svg_path.assert_polyline([
      svg_path.point(0.0, 10.0),
      svg_path.point(10.0, 10.0),
    ])
  let path = svg_path.Path(subpaths: [first, second])

  let assert Ok(offset_path) =
    offset.path_between(path, distance_a: -1.0, distance_b: 1.0)

  assert list.length(svg_path.subpaths(offset_path)) == 4
  assert serialize.path(offset_path)
    == "M 0 1 H 10 M 0 -1 H 10 M 0 11 H 10 M 0 9 H 10"
}

pub fn subpath_prunes_self_crossed_inset_sections_test() {
  let shape =
    svg_path.assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(120.0, 0.0),
      svg_path.point(120.0, 30.0),
      svg_path.point(70.0, 30.0),
      svg_path.point(70.0, 90.0),
      svg_path.point(120.0, 90.0),
      svg_path.point(120.0, 120.0),
      svg_path.point(0.0, 120.0),
    ])

  let options = offset.Options(..offset.default_options(), join: offset.Round)
  let assert Ok(trimmed) = offset.subpath_with(shape, distance: -24.0, options:)

  assert serialize.path(trimmed)
    == "M 24 24 H 46.7621 A 24 24 0 0 0 46 30 V 90 A 24 24 0 0 0 46.7621 96 H 24 Z"
}

pub fn path_offsets_closed_subpaths_test() {
  let first =
    svg_path.assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
      svg_path.point(0.0, 10.0),
    ])
  let second =
    svg_path.assert_polygon([
      svg_path.point(20.0, 0.0),
      svg_path.point(30.0, 0.0),
      svg_path.point(30.0, 10.0),
      svg_path.point(20.0, 10.0),
    ])
  let path = svg_path.Path(subpaths: [first, second])

  let assert Ok(trimmed) = offset.path(path, distance: -2.0)

  assert list.length(svg_path.subpaths(trimmed)) == 2
  assert serialize.path(trimmed) == "M 2 2 H 8 V 8 H 2 Z M 22 2 H 28 V 8 H 22 Z"
}

pub fn subpath_offsets_open_polyline_with_default_miter_test() {
  let subpath =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
    ])

  let assert Ok(offset_path) = offset.subpath(subpath, distance: 2.0)

  assert serialize.path(offset_path) == "M 0 -2 H 10 H 12 V 0 V 10"
}

pub fn subpath_can_use_round_join_test() {
  let subpath =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
    ])
  let options = offset.Options(..offset.default_options(), join: offset.Round)

  let assert Ok(offset_path) =
    offset.subpath_with(subpath, distance: 2.0, options:)

  assert serialize.path(offset_path) == "M 0 -2 H 10 A 2 2 0 0 1 12 0 V 10"
}

pub fn subpath_can_use_bevel_join_test() {
  let subpath =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
    ])
  let options = offset.Options(..offset.default_options(), join: offset.Bevel)

  let assert Ok(offset_path) =
    offset.subpath_with(subpath, distance: 2.0, options:)

  assert serialize.path(offset_path) == "M 0 -2 H 10 L 12 0 V 10"
}

pub fn subpath_prunes_negative_inset_sections_test() {
  let shape =
    svg_path.assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(120.0, 0.0),
      svg_path.point(120.0, 30.0),
      svg_path.point(70.0, 30.0),
      svg_path.point(70.0, 90.0),
      svg_path.point(120.0, 90.0),
      svg_path.point(120.0, 120.0),
      svg_path.point(0.0, 120.0),
    ])

  let options = offset.Options(..offset.default_options(), join: offset.Round)
  let assert Ok(parametric) =
    offset.subpath_with(shape, distance: -24.0, options:)

  assert list.length(svg_path.subpaths(parametric)) == 1
  assert serialize.path(parametric)
    == "M 24 24 H 46.7621 A 24 24 0 0 0 46 30 V 90 A 24 24 0 0 0 46.7621 96 H 24 Z"
}

pub fn subpath_ignores_adjacent_local_contacts_test() {
  let assert Ok(shape) =
    svg_path.subpath([
      svg_path.CubicBezier(
        start: svg_path.point(0.0, 0.0),
        control1: svg_path.point(60.0, -75.0),
        control2: svg_path.point(115.0, -75.0),
        end: svg_path.point(75.0, 0.0),
      ),
      svg_path.CubicBezier(
        start: svg_path.point(75.0, 0.0),
        control1: svg_path.point(115.0, 75.0),
        control2: svg_path.point(60.0, 75.0),
        end: svg_path.point(0.0, 0.0),
      ),
      svg_path.CubicBezier(
        start: svg_path.point(0.0, 0.0),
        control1: svg_path.point(-60.0, -75.0),
        control2: svg_path.point(-115.0, -75.0),
        end: svg_path.point(-75.0, 0.0),
      ),
      svg_path.CubicBezier(
        start: svg_path.point(-75.0, 0.0),
        control1: svg_path.point(-115.0, 75.0),
        control2: svg_path.point(-60.0, 75.0),
        end: svg_path.point(0.0, 0.0),
      ),
    ])

  let options = offset.Options(..offset.default_options(), join: offset.Round)
  let assert Ok(parametric) =
    offset.subpath_with(shape, distance: -16.0, options:)

  assert list.length(svg_path.subpaths(parametric)) == 1
}

pub fn path_offsets_every_subpath_test() {
  let first =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
    ])
  let second =
    svg_path.assert_polyline([
      svg_path.point(0.0, 10.0),
      svg_path.point(10.0, 10.0),
    ])
  let path = svg_path.Path(subpaths: [first, second])

  let assert Ok(offset_path) = offset.path(path, distance: 1.0)

  assert list.length(svg_path.subpaths(offset_path)) == 2
  assert serialize.path(offset_path) == "M 0 -1 H 10 M 0 9 H 10"
}

fn max_offset_error(
  source: svg_path.Segment,
  offset_subpath: svg_path.Subpath,
  distance distance: Float,
) -> Float {
  max_offset_error_loop(source, offset_subpath, distance, sample: 1, best: 0.0)
}

fn max_offset_error_loop(
  source: svg_path.Segment,
  offset_subpath: svg_path.Subpath,
  distance: Float,
  sample sample: Int,
  best best: Float,
) -> Float {
  case sample > 19 {
    True -> best
    False -> {
      let t = int.to_float(sample) /. 20.0
      let assert Ok(point) = svg_path.segment_point(source, at: t)
      let assert Ok(derivative) = svg_path.segment_derivative(source, at: t)
      let normal = right_unit_normal(derivative)
      let extruded =
        svg_path.point(
          point.x +. normal.x *. distance,
          point.y +. normal.y *. distance,
        )
      let assert Ok(projection) =
        svg_path.subpath_projection(extruded, to: offset_subpath)

      max_offset_error_loop(
        source,
        offset_subpath,
        distance,
        sample: sample + 1,
        best: float.max(best, projection.distance),
      )
    }
  }
}

fn right_unit_normal(point: svg_path.Point) -> svg_path.Point {
  let length = distance(svg_path.point(0.0, 0.0), point)
  svg_path.point(point.y /. length, { 0.0 -. point.x } /. length)
}

fn has_arc(segments: List(svg_path.Segment)) -> Bool {
  list.any(segments, fn(segment) {
    case segment {
      svg_path.Arc(..) -> True
      _ -> False
    }
  })
}

fn distance(a: svg_path.Point, b: svg_path.Point) -> Float {
  let assert Ok(distance) =
    float.square_root(
      { a.x -. b.x } *. { a.x -. b.x } +. { a.y -. b.y } *. { a.y -. b.y },
    )
  distance
}
