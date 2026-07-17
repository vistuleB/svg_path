import gleam/float
import gleam/list
import svg_path
import svg_path/effects

const tolerance = 0.000001

pub fn round_corners_rounds_closed_square_test() {
  let square =
    svg_path.assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
      svg_path.point(0.0, 10.0),
    ])

  let assert Ok(rounded) = effects.round_subpath_corners(square, radius: 2.0)
  let segments = svg_path.segments(rounded)

  assert svg_path.is_closed(rounded)
  assert list.length(segments) == 8
  assert arc_count(segments) == 4
  assert has_line(segments, svg_path.point(2.0, 0.0), svg_path.point(8.0, 0.0))
  assert has_line(
    segments,
    svg_path.point(10.0, 2.0),
    svg_path.point(10.0, 8.0),
  )
}

pub fn round_corners_rounds_open_polyline_interior_join_test() {
  let subpath =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
    ])

  let assert Ok(rounded) = effects.round_subpath_corners(subpath, radius: 2.0)
  let segments = svg_path.segments(rounded)

  assert !svg_path.is_closed(rounded)
  assert list.length(segments) == 3
  assert has_line(segments, svg_path.point(0.0, 0.0), svg_path.point(8.0, 0.0))
  assert has_arc(segments, svg_path.point(8.0, 0.0), svg_path.point(10.0, 2.0))
  assert has_line(
    segments,
    svg_path.point(10.0, 2.0),
    svg_path.point(10.0, 10.0),
  )
}

pub fn round_corners_supports_curve_incident_segments_test() {
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 0.0),
      ),
      svg_path.QuadraticBezier(
        start: svg_path.point(10.0, 0.0),
        control: svg_path.point(10.0, 10.0),
        end: svg_path.point(20.0, 10.0),
      ),
    ])

  let assert Ok(rounded) = effects.round_subpath_corners(subpath, radius: 2.0)
  let segments = svg_path.segments(rounded)

  assert list.length(segments) == 3
  assert arc_count(segments) == 1
  assert has_arc_start(segments, svg_path.point(8.0, 0.0))
  assert has_quadratic(segments)
}

pub fn round_corners_errors_when_radius_does_not_fit_test() {
  let subpath =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
    ])

  assert effects.round_subpath_corners(subpath, radius: 20.0)
    == Error(effects.CannotRoundCorner(0))
}

pub fn round_corners_can_leave_unfittable_corner_test() {
  let subpath =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
    ])
  let options =
    effects.RoundCornerOptions(
      ..effects.default_round_corner_options(),
      failure: effects.LeaveCorner,
    )

  assert effects.round_subpath_corners_with(subpath, radius: 20.0, options:)
    == Ok(subpath)
}

pub fn round_corners_can_adapt_radius_to_fit_short_segments_test() {
  let square =
    svg_path.assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
      svg_path.point(0.0, 10.0),
    ])
  let options =
    effects.RoundCornerOptions(
      ..effects.default_round_corner_options(),
      failure: effects.AdaptRadius,
    )

  let assert Ok(rounded) =
    effects.round_subpath_corners_with(square, radius: 20.0, options:)
  let segments = svg_path.segments(rounded)

  assert svg_path.is_closed(rounded)
  assert list.length(segments) == 8
  assert arc_count(segments) == 4
  assert all_arc_radii_near(segments, expected: 4.999999)
}

fn arc_count(segments: List(svg_path.Segment)) -> Int {
  segments
  |> list.filter(keeping: fn(segment) {
    case segment {
      svg_path.Arc(..) -> True
      _ -> False
    }
  })
  |> list.length
}

fn all_arc_radii_near(
  segments: List(svg_path.Segment),
  expected expected: Float,
) -> Bool {
  segments
  |> list.filter_map(fn(segment) {
    case segment {
      svg_path.Arc(radius:, ..) -> Ok(radius.x)
      _ -> Error(Nil)
    }
  })
  |> list.all(fn(radius) {
    float.absolute_value(radius -. expected) <=. tolerance
  })
}

fn has_line(
  segments: List(svg_path.Segment),
  start: svg_path.Point,
  end: svg_path.Point,
) -> Bool {
  list.any(segments, fn(segment) {
    case segment {
      svg_path.Line(start: actual_start, end: actual_end) ->
        same_point(actual_start, start) && same_point(actual_end, end)
      _ -> False
    }
  })
}

fn has_arc(
  segments: List(svg_path.Segment),
  start: svg_path.Point,
  end: svg_path.Point,
) -> Bool {
  list.any(segments, fn(segment) {
    case segment {
      svg_path.Arc(start: actual_start, end: actual_end, ..) ->
        same_point(actual_start, start) && same_point(actual_end, end)
      _ -> False
    }
  })
}

fn has_arc_start(
  segments: List(svg_path.Segment),
  start: svg_path.Point,
) -> Bool {
  list.any(segments, fn(segment) {
    case segment {
      svg_path.Arc(start: actual_start, ..) -> same_point(actual_start, start)
      _ -> False
    }
  })
}

fn has_quadratic(segments: List(svg_path.Segment)) -> Bool {
  list.any(segments, fn(segment) {
    case segment {
      svg_path.QuadraticBezier(..) -> True
      _ -> False
    }
  })
}

fn same_point(left: svg_path.Point, right: svg_path.Point) -> Bool {
  float.absolute_value(left.x -. right.x) <=. tolerance
  && float.absolute_value(left.y -. right.y) <=. tolerance
}
