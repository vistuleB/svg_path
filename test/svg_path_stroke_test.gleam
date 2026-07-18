import gleam/list
import svg_path
import svg_path/serialize
import svg_path/stroke

pub fn segment_stroke_with_butt_caps_returns_closed_outline_test() {
  let segment =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  let assert Ok(path) = stroke.segment(segment, width: 2.0)
  let assert [outline] = svg_path.subpaths(path)

  assert svg_path.is_closed(outline)
  assert serialize.subpath(outline) == "M 0 -1 H 10 V 1 H 0 Z"
}

pub fn subpath_stroke_with_round_caps_adds_two_cap_arcs_test() {
  let subpath =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
    ])
  let options =
    stroke.Options(..stroke.default_options(), width: 2.0, cap: stroke.Round)

  let assert Ok(path) = stroke.subpath_with(subpath, options:)
  let assert [outline] = svg_path.subpaths(path)

  assert svg_path.is_closed(outline)
  assert arc_count(svg_path.segments(outline)) == 2
}

pub fn subpath_stroke_with_square_caps_extends_by_half_width_test() {
  let subpath =
    svg_path.assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
    ])
  let options =
    stroke.Options(..stroke.default_options(), width: 2.0, cap: stroke.Square)

  let assert Ok(path) = stroke.subpath_with(subpath, options:)
  let assert [outline] = svg_path.subpaths(path)

  assert serialize.subpath(outline)
    == "M -1 -1 H 0 H 10 H 11 V 1 H 10 H 0 H -1 Z"
}

pub fn closed_subpath_stroke_returns_two_closed_contours_test() {
  let square =
    svg_path.assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 0.0),
      svg_path.point(10.0, 10.0),
      svg_path.point(0.0, 10.0),
    ])

  let assert Ok(path) = stroke.subpath(square, width: 2.0)
  let subpaths = svg_path.subpaths(path)

  assert list.length(subpaths) == 2
  assert list.all(subpaths, svg_path.is_closed)
}

pub fn path_stroke_strokes_each_subpath_test() {
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

  let assert Ok(path) =
    stroke.path(svg_path.Path(subpaths: [first, second]), width: 2.0)

  assert list.length(svg_path.subpaths(path)) == 2
}

pub fn stroke_rejects_non_positive_width_test() {
  let segment =
    svg_path.Line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )

  assert stroke.segment(segment, width: 0.0) == Error(stroke.InvalidWidth(0.0))
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
