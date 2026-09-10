import gleam/float
import gleam/list
import gleam/option.{None, Some}
import svg_path.{Arc, Line, Point}
import svg_path/internal/arcs_join as arcs
import svg_path/offset
import svg_path/point
import svg_path/stroke

fn near(a, b) {
  assert point.distance(a, b) <. 1.0e-8
}

fn axis() {
  let assert Ok(v) = point.normalize(Point(1.0, -1.0))
  v
}

fn pair(ra, rb, limit) {
  arcs.join(
    arcs.Continuation(Point(0.0, -1.0), Point(1.0, 0.0), ra),
    arcs.Continuation(Point(1.0, 0.0), Point(0.0, 1.0), rb),
    axis(),
    limit,
  )
}

fn continuous(segments) {
  let assert Ok(subpath) =
    svg_path.subpath_with(segments, policy: svg_path.Strict)
  near(svg_path.subpath_start(subpath), Point(0.0, -1.0))
  near(svg_path.subpath_end(subpath), Point(1.0, 0.0))
}

pub fn arcs_intersecting_circles_preserve_radii_and_tangents_test() {
  let assert Ok([a, b]) = pair(Some(-4.0), Some(-4.0), 10.0)
  let assert Arc(radius: ar, sweep: True, ..) = a
  let assert Arc(radius: br, sweep: True, ..) = b
  assert ar == Point(4.0, 4.0)
  assert br == ar
  continuous([a, b])
  let assert Ok(da) = svg_path.segment_derivative(a, at: 0.0)
  let assert Ok(db) = svg_path.segment_derivative(b, at: 1.0)
  let assert Ok(da) = point.normalize(da)
  let assert Ok(db) = point.normalize(db)
  near(da, Point(1.0, 0.0))
  near(db, Point(0.0, 1.0))
}

pub fn arcs_disjoint_circles_grow_equally_until_touching_test() {
  let assert Ok([a, b]) = pair(Some(0.5), Some(0.5), 10.0)
  let assert Arc(radius: ar, sweep: False, ..) = a
  let assert Arc(radius: br, sweep: False, ..) = b
  let assert Ok(two) = float.square_root(2.0)
  assert float.absolute_value(ar.x -. { 1.0 +. two }) <. 1.0e-8
  assert ar == br
  near(
    svg_path.segment_end(a),
    Point({ 2.0 +. two } /. 2.0, 0.0 -. { 2.0 +. two } /. 2.0),
  )
  continuous([a, b])
}

pub fn arcs_nested_circles_shrink_large_and_grow_small_equally_test() {
  let assert Ok([a, b]) =
    arcs.join(
      arcs.Continuation(Point(0.0, -1.0), Point(1.0, 0.0), Some(-10.0)),
      arcs.Continuation(Point(1.2, 0.0), Point(0.0, 1.0), Some(-0.5)),
      axis(),
      10.0,
    )
  let assert Arc(radius: ar, ..) = a
  let assert Arc(radius: br, ..) = b
  assert ar.x <. 10.0
  assert br.x >. 0.5
  assert float.absolute_value({ 10.0 -. ar.x } -. { br.x -. 0.5 }) <. 1.0e-8
  let assert Ok(_) = svg_path.subpath_with([a, b], policy: svg_path.Strict)
}

pub fn arcs_line_circle_adjustment_test() {
  let assert Ok([a, b]) = pair(Some(0.5), None, 10.0)
  let assert Arc(radius:, ..) = a
  let assert Line(..) = b
  assert radius == Point(1.0, 1.0)
  near(svg_path.segment_end(a), Point(1.0, -2.0))
  continuous([a, b])
}

pub fn arcs_clip_plane_and_low_limit_test() {
  let assert Ok([a, clip, b]) = pair(Some(10.0), Some(10.0), 1.2)
  let assert Line(start:, end:) = clip
  assert float.absolute_value(point.dot(start, axis()) -. 1.2) <. 1.0e-8
  assert float.absolute_value(point.dot(end, axis()) -. 1.2) <. 1.0e-8
  continuous([a, clip, b])
  assert pair(Some(10.0), Some(10.0), 0.1)
    == Ok([Line(Point(0.0, -1.0), Point(1.0, 0.0))])
}

fn corner() {
  svg_path.subpath_assert_polyline([
    Point(-10.0, 0.0),
    Point(0.0, 0.0),
    Point(0.0, 10.0),
  ])
}

pub fn arcs_asymmetric_clipping_uses_auxiliary_arc_length_test() {
  let assert Ok([a, _]) = pair(Some(10.0), Some(5.0), 10.0)
  let tip = svg_path.segment_end(a)
  let n = point.rotate_counterclockwise(axis())
  let r = point.dot(tip, tip) /. { 2.0 *. point.dot(tip, n) }
  let radius = float.absolute_value(r)
  let helper =
    Arc(Point(0.0, 0.0), Point(radius, radius), 0.0, False, r <. 0.0, tip)
  let assert Ok(length) = svg_path.segment_length(helper)
  let assert Ok(cut) = svg_path.segment_point(helper, at: 1.2 /. length)
  let assert Ok(direction) =
    svg_path.segment_derivative(helper, at: 1.2 /. length)
  let assert Ok(direction) = point.normalize(direction)
  let assert Ok([_, Line(start:, end:), _]) = pair(Some(10.0), Some(5.0), 1.2)
  list.each([start, end], fn(q) {
    assert float.absolute_value(point.dot(point.subtract(q, cut), direction))
      <. 1.0e-8
  })
}

pub fn arcs_reflection_changes_sweep_not_shape_test() {
  let assert Ok(original) = pair(Some(10.0), Some(5.0), 1.2)
  let assert Ok(mirrored) =
    arcs.join(
      arcs.Continuation(Point(0.0, 1.0), Point(1.0, 0.0), Some(-10.0)),
      arcs.Continuation(Point(1.0, 0.0), Point(0.0, -1.0), Some(-5.0)),
      Point(axis().x, 0.0 -. axis().y),
      1.2,
    )
  assert list.length(original) == list.length(mirrored)
  list.each(list.zip(original, mirrored), fn(pair) {
    let #(a, b) = pair
    list.each([0.0, 0.5, 1.0], fn(t) {
      let assert Ok(a) = svg_path.segment_point(a, at: t)
      let assert Ok(b) = svg_path.segment_point(b, at: t)
      near(Point(a.x, 0.0 -. a.y), b)
    })
  })
}

pub fn arcs_circle_line_and_line_circle_are_reversal_symmetric_test() {
  let assert Ok(forward) = pair(Some(0.5), None, 10.0)
  let assert Ok(backward) =
    arcs.join(
      arcs.Continuation(Point(1.0, 0.0), Point(0.0, -1.0), None),
      arcs.Continuation(Point(0.0, -1.0), Point(-1.0, 0.0), Some(-0.5)),
      axis(),
      10.0,
    )
  assert backward
    == forward |> list.reverse |> list.map(svg_path.segment_reverse)
}

pub fn arcs_public_straight_join_matches_miter_clip_test() {
  list.each([0.5, 1.2, 4.0], fn(limit) {
    assert offset.subpath_untrimmed(corner(), 1.0, offset.Arcs(limit))
      == offset.subpath_untrimmed(corner(), 1.0, offset.MiterClip(limit))
  })
}

pub fn arcs_inner_corner_defaults_to_bevel_test() {
  assert offset.subpath_untrimmed(corner(), -1.0, offset.Arcs(4.0))
    == offset.subpath_untrimmed(corner(), -1.0, offset.Bevel)
}

pub fn arcs_invalid_limits_test() {
  list.each([0.0, -1.0], fn(limit) {
    assert offset.subpath_untrimmed(corner(), 1.0, offset.Arcs(limit))
      == Error(offset.InvalidMiterLimit(limit))
    let assert Error(_) =
      stroke.subpath(corner(), 2.0, stroke.Arcs(limit), stroke.Butt)
  })
}

pub fn arcs_public_curved_source_and_stroke_test() {
  let source =
    svg_path.subpath_assert([
      Arc(Point(-3.0, 3.0), Point(3.0, 3.0), 0.0, False, True, Point(0.0, 0.0)),
      Arc(Point(0.0, 0.0), Point(3.0, 3.0), 0.0, False, True, Point(-3.0, 3.0)),
    ])
  let assert Ok(outline) =
    offset.subpath_untrimmed(source, 1.0, offset.Arcs(4.0))
  let segments = svg_path.subpath_segments(outline)
  assert list.length(segments) == 4
  list.each(segments, fn(segment) {
    let assert Arc(radius:, ..) = segment
    near(radius, Point(4.0, 4.0))
  })
  let assert Ok(band) =
    stroke.subpath(source, 2.0, stroke.Arcs(4.0), stroke.Butt)
  assert !list.is_empty(svg_path.path_subpaths(band))
  assert list.all(svg_path.path_subpaths(band), svg_path.subpath_is_closed)
}

pub fn arcs_public_bezier_source_preserves_translated_endpoints_test() {
  let p = fn(x, y) { Point(127.345 +. x, -23.567 +. y) }
  let source =
    svg_path.subpath_assert([
      svg_path.CubicBezier(
        p(-6.0, 5.0),
        p(-5.0, 3.0),
        p(-1.0, 0.0),
        p(0.0, 0.0),
      ),
      svg_path.CubicBezier(p(0.0, 0.0), p(0.0, 1.0), p(-3.0, 5.0), p(-5.0, 5.0)),
    ])
  let assert Ok(arcs) = offset.subpath_untrimmed(source, 0.5, offset.Arcs(4.0))
  let assert Ok(bevel) = offset.subpath_untrimmed(source, 0.5, offset.Bevel)
  assert svg_path.subpath_start(arcs) == svg_path.subpath_start(bevel)
  assert svg_path.subpath_end(arcs) == svg_path.subpath_end(bevel)
  assert list.length(svg_path.subpath_segments(arcs))
    > list.length(svg_path.subpath_segments(bevel))
}
