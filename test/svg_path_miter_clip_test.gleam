import gleam/float
import gleam/list
import svg_path.{Point}
import svg_path/offset
import svg_path/point
import svg_path/serialize
import svg_path/stroke

fn corner() -> svg_path.Subpath {
  svg_path.subpath_assert_polyline([
    Point(-10.0, 0.0),
    Point(0.0, 0.0),
    Point(0.0, 10.0),
  ])
}

fn near(a: svg_path.Point, b: svg_path.Point) -> Bool {
  point.distance(a, b) <. 0.000000001
}

fn has_edge(
  subpath: svg_path.Subpath,
  a: svg_path.Point,
  b: svg_path.Point,
) -> Bool {
  list.any(svg_path.subpath_segments(subpath), fn(segment) {
    near(svg_path.segment_start(segment), a)
    && near(svg_path.segment_end(segment), b)
  })
}

pub fn miter_clip_high_limit_matches_miter_test() {
  assert offset.subpath_untrimmed(corner(), 1.0, offset.MiterClip(4.0))
    == offset.subpath_untrimmed(corner(), 1.0, offset.Miter(4.0))
}

pub fn miter_clip_acute_corner_test() {
  let source =
    svg_path.subpath_assert_polyline([
      Point(-10.0, 0.0),
      Point(0.0, 0.0),
      Point(-8.0, 6.0),
    ])
  let assert Ok(path) =
    offset.subpath_untrimmed(source, 1.0, offset.MiterClip(2.0))
  let assert [_, _, clip, _, _] = svg_path.subpath_segments(path)
  let assert Ok(axis) = point.normalize(Point(3.0, -1.0))
  list.each([svg_path.segment_start(clip), svg_path.segment_end(clip)], fn(p) {
    assert float.absolute_value(point.dot(p, axis) -. 2.0) <. 0.000000001
  })
  assert near(svg_path.subpath_start(path), Point(-10.0, -1.0))
  assert near(svg_path.subpath_end(path), Point(-7.4, 6.8))
}

pub fn miter_clip_plane_is_measured_from_pivot_test() {
  let assert Ok(path) =
    offset.subpath_untrimmed(corner(), 1.0, offset.MiterClip(1.2))
  let assert Ok(root_two) = float.square_root(2.0)
  let x = 1.2 *. root_two -. 1.0
  assert has_edge(path, Point(0.0, -1.0), Point(x, -1.0))
  assert has_edge(path, Point(x, -1.0), Point(1.0, 0.0 -. x))
  assert has_edge(path, Point(1.0, 0.0 -. x), Point(1.0, 0.0))
  // A fraction limit/tip measured from the bevel endpoints gives the wrong
  // clipping distance. Both clipped vertices must lie on x-y = limit*sqrt(2).
  assert !has_edge(path, Point(0.0, -1.0), Point(1.0, -1.0))
}

pub fn miter_clip_low_limit_does_not_trim_neighbors_test() {
  list.each([0.1, 0.5], fn(limit) {
    assert offset.subpath_untrimmed(corner(), 1.0, offset.MiterClip(limit))
      == offset.subpath_untrimmed(corner(), 1.0, offset.Bevel)
  })
}

pub fn miter_clip_diverging_rays_match_miter_fallback_test() {
  assert offset.subpath_untrimmed(corner(), -1.0, offset.MiterClip(1.2))
    == offset.subpath_untrimmed(corner(), -1.0, offset.Miter(1.2))
}

pub fn miter_clip_mirrored_corner_negative_offset_test() {
  let source =
    svg_path.subpath_assert_polyline([
      Point(-10.0, 0.0),
      Point(0.0, 0.0),
      Point(0.0, -10.0),
    ])
  let assert Ok(path) =
    offset.subpath_untrimmed(source, -1.0, offset.MiterClip(1.2))
  let assert Ok(root_two) = float.square_root(2.0)
  let x = 1.2 *. root_two -. 1.0
  assert has_edge(path, Point(x, 1.0), Point(1.0, x))
}

pub fn miter_clip_translated_scaled_corner_test() {
  let source =
    svg_path.subpath_assert_polyline([
      Point(-13.0, -3.0),
      Point(7.0, -3.0),
      Point(7.0, 17.0),
    ])
  let assert Ok(path) =
    offset.subpath_untrimmed(source, 2.0, offset.MiterClip(1.2))
  let assert Ok(root_two) = float.square_root(2.0)
  let x = 2.0 *. { 1.2 *. root_two -. 1.0 }
  assert has_edge(path, Point(7.0 +. x, -5.0), Point(9.0, -3.0 -. x))
}

pub fn miter_clip_zero_offset_and_straight_source_test() {
  assert offset.subpath_untrimmed(corner(), 0.0, offset.MiterClip(1.2))
    == offset.subpath_untrimmed(corner(), 0.0, offset.Miter(1.2))
  let source =
    svg_path.subpath_assert_polyline([
      Point(0.0, 0.0),
      Point(5.0, 0.0),
      Point(10.0, 0.0),
    ])
  assert offset.subpath_untrimmed(source, 1.0, offset.MiterClip(1.2))
    == offset.subpath_untrimmed(source, 1.0, offset.Miter(1.2))
}

pub fn miter_clip_invalid_limit_test() {
  list.each([0.0, -1.0], fn(limit) {
    assert offset.subpath_untrimmed(corner(), 1.0, offset.MiterClip(limit))
      == Error(offset.InvalidMiterLimit(limit))
    assert stroke.subpath(corner(), 2.0, stroke.MiterClip(limit), stroke.Butt)
      == Error(stroke.OffsetError(offset.InvalidMiterLimit(limit)))
  })
}

pub fn miter_clip_stroke_produces_closed_outline_test() {
  let assert Ok(path) =
    stroke.subpath(corner(), 2.0, stroke.MiterClip(1.2), stroke.Butt)
  let assert [outline] = svg_path.path_subpaths(path)
  assert svg_path.subpath_is_closed(outline)
  let assert Ok(root_two) = float.square_root(2.0)
  let x = 1.2 *. root_two -. 1.0
  assert has_edge(outline, Point(x, -1.0), Point(1.0, 0.0 -. x))
  let assert Ok(bevel) =
    stroke.subpath(corner(), 2.0, stroke.Bevel, stroke.Butt)
  assert serialize.path(path) != serialize.path(bevel)
}
