import gleam/list
import svg_path
import svg_path/convex_hull
import svg_path_convex_hull_support as support

const tolerance = 0.000001

pub fn segment_hull_returns_closed_subpath_for_line_test() {
  let segment =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 0.0),
    )
  let assert Ok(subpath) = convex_hull.segment_hull(segment)

  assert svg_path.subpath_is_closed(subpath)
  assert list.length(svg_path.subpath_segments(subpath)) == 2
  assert support_values_match(segment, subpath)
}

pub fn segment_hull_returns_closed_hull_for_quadratic_test() {
  let segment =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.0),
      control: svg_path.Point(5.0, 10.0),
      end: svg_path.Point(10.0, 0.0),
    )
  let assert Ok(subpath) = convex_hull.segment_hull(segment)

  assert svg_path.subpath_is_closed(subpath)
  assert list.length(svg_path.subpath_segments(subpath)) == 2
  assert support_values_match(segment, subpath)
}

pub fn subpath_hull_returns_closed_hull_for_l_shaped_polyline_test() {
  let segments = [
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(20.0, 0.0),
    ),
    svg_path.Line(
      start: svg_path.Point(20.0, 0.0),
      end: svg_path.Point(20.0, 15.0),
    ),
  ]
  let assert Ok(subpath) = svg_path.subpath(segments)
  let assert Ok(hull) = convex_hull.subpath_hull(subpath)

  assert svg_path.subpath_is_closed(hull)
  assert list.length(svg_path.subpath_segments(hull)) >= 3
  assert subpath_support_matches(segments, hull)
}

pub fn subpath_hull_treats_empty_subpath_as_single_point_test() {
  let point = svg_path.Point(4.0, -3.0)
  let assert Ok(hull) =
    convex_hull.subpath_hull(svg_path.subpath_empty(at: point))

  assert svg_path.subpath_is_closed(hull)
  assert svg_path.subpath_segments(hull)
    == svg_path.subpath_segments(svg_path.subpath_assert_set_closed(
      svg_path.subpath_assert([
        svg_path.Line(start: point, end: point),
        svg_path.Line(start: point, end: point),
      ]),
      closed: True,
    ))
}

pub fn path_hull_includes_empty_subpath_start_points_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(2.0, 0.0)
  let far = svg_path.Point(10.0, 0.0)
  let path =
    svg_path.Path([
      svg_path.subpath_assert([svg_path.Line(start: a, end: b)]),
      svg_path.subpath_empty(at: far),
    ])
  let assert Ok(hull) = convex_hull.path_hull(path)

  assert svg_path.subpath_is_closed(hull)
  assert near_value(
    support.segments_support_value(svg_path.subpath_segments(hull), 0.0),
    10.0,
  )
}

pub fn path_hull_rejects_empty_path_test() {
  assert convex_hull.path_hull(svg_path.path_empty())
    == Error(convex_hull.PathError(svg_path.EmptyPath))
}

fn support_values_match(
  segment: svg_path.Segment,
  hull: svg_path.Subpath,
) -> Bool {
  support.octant_angles()
  |> list.all(fn(angle) {
    case
      convex_hull.internal_segment_support(segment, angle: angle),
      support.segments_support_value(svg_path.subpath_segments(hull), angle)
    {
      Ok(#(_, _, original)), Ok(hull) ->
        support.values_near(original, hull, tolerance:)
      _, _ -> False
    }
  })
}

fn subpath_support_matches(
  original_segments: List(svg_path.Segment),
  hull: svg_path.Subpath,
) -> Bool {
  support.octant_angles()
  |> list.all(fn(angle) {
    case
      support.segments_support_value(original_segments, angle),
      support.segments_support_value(svg_path.subpath_segments(hull), angle)
    {
      Ok(original), Ok(hull) -> support.values_near(original, hull, tolerance:)
      _, _ -> False
    }
  })
}

fn near_value(value: Result(Float, svg_path.Error), expected: Float) -> Bool {
  case value {
    Ok(value) -> support.values_near(value, expected, tolerance:)
    Error(_) -> False
  }
}
