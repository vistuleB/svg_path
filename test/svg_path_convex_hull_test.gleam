import gleam/float
import gleam/list
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
