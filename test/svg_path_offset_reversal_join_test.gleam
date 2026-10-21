import gleam/float
import gleam/list
import svg_path.{Arc, Line, Point}
import svg_path/area
import svg_path/offset
import svg_path/parse
import svg_path/trig

fn turn(x: Float, y: Float, angle: Float, scale: Float) -> svg_path.Point {
  Point(
    scale *. { x *. trig.cos_degrees(angle) -. y *. trig.sin_degrees(angle) },
    scale *. { x *. trig.sin_degrees(angle) +. y *. trig.cos_degrees(angle) },
  )
}

fn source(angle: Float, scale: Float) -> svg_path.Subpath {
  let p = fn(x, y) { turn(x, y, angle, scale) }
  let assert Ok(source) =
    svg_path.subpath([
      Arc(p(-2.0, 0.0), Point(scale, scale), 0.0, False, True, p(0.0, 0.0)),
      Arc(p(0.0, 0.0), Point(scale, scale), 0.0, False, True, p(2.0, 0.0)),
      Line(p(2.0, 0.0), p(2.0, 2.0)),
      Line(p(2.0, 2.0), p(-2.0, 2.0)),
      Line(p(-2.0, 2.0), p(-2.0, 0.0)),
    ])
  let assert Ok(source) = svg_path.subpath_close(source)
  source
}

pub fn inward_reversal_join_preserves_contour_test() {
  list.each([0.1, 1.0, 100.0], fn(scale) {
    list.each([0.0, 37.0, 90.0, 180.0, 270.0], fn(angle) {
      let source = source(angle, scale)
      let assert Ok(forward) =
        offset.subpath(source, -0.25 *. scale, offset.Round, offset.Butt)
      let assert Ok(backward) =
        offset.subpath(
          svg_path.subpath_reverse(source),
          0.25 *. scale,
          offset.Round,
          offset.Butt,
        )
      let assert [forward] = forward.subpaths
      let assert [backward] = backward.subpaths
      assert svg_path.subpath_is_closed(forward)
      assert svg_path.subpath_is_closed(backward)
      // Rotation and endpoint reconstruction introduce floating-point area drift.
      let forward_area = area.signed_subpath(forward) /. scale /. scale
      let backward_area = area.signed_subpath(backward) /. scale /. scale
      assert float.absolute_value(forward_area -. 7.793971097219577) <. 1.0e-6
      assert float.absolute_value(forward_area +. backward_area) <. 1.0e-6
    })
  })
}

pub fn round_join_near_reversal_keeps_endpoint_turn_test() {
  // Perturbations exceed the tie tolerance; either turn direction remains valid.
  list.each([-0.00001, 0.00001], fn(angle) {
    let assert Ok(source) =
      svg_path.subpath([
        Arc(
          Point(-2.0, 0.0),
          Point(1.0, 1.0),
          0.0,
          False,
          True,
          Point(0.0, 0.0),
        ),
        Arc(
          Point(0.0, 0.0),
          Point(1.0, 1.0),
          0.0,
          False,
          True,
          turn(2.0, 0.0, angle, 1.0),
        ),
      ])
    list.each([-0.25, 0.25], fn(distance) {
      let assert Ok(raw) =
        offset.subpath_untrimmed(source, distance, offset.Round)
      let assert [_, Arc(sweep:, ..), _, ..] = svg_path.subpath_segments(raw)
      assert sweep == { angle <. 0.0 }
    })
  })
}

pub fn curved_cusp_round_join_uses_source_side_test() {
  list.each([0.1, 1.0, 100.0], fn(scale) {
    list.each([0.0, 37.0, 90.0], fn(angle) {
      let p = fn(x, y) { turn(x, y, angle, scale) }
      let assert Ok(source) =
        svg_path.subpath([
          Arc(
            p(-4.0, 0.0),
            Point(2.0 *. scale, 2.0 *. scale),
            angle,
            False,
            True,
            p(0.0, 0.0),
          ),
          Arc(p(0.0, 0.0), Point(scale, scale), angle, False, True, p(2.0, 0.0)),
        ])
      list.each([-0.25, 0.25], fn(distance) {
        let assert Ok(raw) =
          offset.subpath_untrimmed(source, distance *. scale, offset.Round)
        let assert [_, join, _] = svg_path.subpath_segments(raw)
        let assert Ok(middle) = svg_path.segment_point(join, 0.5)
        let expected = p(0.0, 0.0 -. distance)
        assert float.absolute_value(middle.x -. expected.x) <. 0.000001 *. scale
        assert float.absolute_value(middle.y -. expected.y) <. 0.000001 *. scale
        let assert Ok(backward) =
          offset.subpath_untrimmed(
            svg_path.subpath_reverse(source),
            0.0 -. distance *. scale,
            offset.Round,
          )
        let assert [_, reverse_join, _] = svg_path.subpath_segments(backward)
        list.each([0.0, 0.25, 0.5, 0.75, 1.0], fn(t) {
          let assert Ok(a) = svg_path.segment_point(join, t)
          let assert Ok(b) = svg_path.segment_point(reverse_join, 1.0 -. t)
          assert float.absolute_value(a.x -. b.x) <. 0.000001 *. scale
          assert float.absolute_value(a.y -. b.y) <. 0.000001 *. scale
        })
      })
    })
  })
}

pub fn straight_retrace_round_join_keeps_previous_side_test() {
  let source =
    svg_path.subpath_assert_polyline([
      Point(-2.0, 0.0),
      Point(0.0, 0.0),
      Point(-2.0, 0.0),
    ])
  list.each([-0.25, 0.25], fn(distance) {
    let assert Ok(raw) =
      offset.subpath_untrimmed(source, distance, offset.Round)
    let assert [_, Arc(sweep:, ..), _] = svg_path.subpath_segments(raw)
    assert sweep == { distance >. 0.0 }
  })
}

pub fn curved_cusp_join_reversal_metadata_matches_side_test() {
  list.each([0.0, 37.0, 90.0], fn(angle) {
    let p = fn(x, y) { turn(x, y, angle, 1.0) }
    let assert Ok(source) =
      svg_path.subpath([
        Arc(p(-4.0, 0.0), Point(2.0, 2.0), angle, False, True, p(0.0, 0.0)),
        Arc(p(0.0, 0.0), Point(1.0, 1.0), angle, False, True, p(2.0, 0.0)),
      ])
    list.each(
      [offset.Round, offset.Miter(4.0), offset.MiterClip(4.0)],
      fn(style) {
        let assert Ok([forward]) =
          offset.internal_synchronized_join_trace(
            source,
            -0.25,
            0.25,
            style,
            offset.default_options(),
          )
        assert !forward.inner_reversed
        assert forward.outer_reversed
        let assert Ok([backward]) =
          offset.internal_synchronized_join_trace(
            svg_path.subpath_reverse(source),
            0.25,
            -0.25,
            style,
            offset.default_options(),
          )
        assert !backward.inner_reversed
        assert backward.outer_reversed
      },
    )
  })
}

// Cavalier case 11: competing routes between the same arrangement vertices.
// The upper route is submerged; retaining it used to remove the lower arc.
pub fn offside_prefers_non_submerged_cusp_route_test() {
  let assert Ok(source) =
    parse.path(
      "M -225 0 L -175 0 A 12.5 12.5 0 0 1 -150 0 A 12.5 12.5 0 0 1 -125 0 A 12.5 12.5 0 0 1 -100 0 L -75 0 A 12.5 12.5 0 0 0 -50 0 A 12.5 12.5 0 0 0 -25 0 A 12.5 12.5 0 0 0 0 0 L 25 0 A 12.5 12.5 0 0 1 50 0 L 75 0 A 12.5 12.5 0 0 1 100 0 L 125 0 A 12.5 12.5 0 0 1 150 0 A 7.5 7.5 0 0 1 165 0 A 12.5 12.5 0 0 1 190 0 L 215 0 A 7.5 7.5 0 0 1 230 0 A 12.5 12.5 0 0 1 255 0 A 7.5 7.5 0 0 1 270 0 L 280 0 L 390 200 L 365 200 A 12.5 12.5 0 0 1 340 200 A 6.25 6.25 0 0 1 352.5 200 A 31.25 31.25 0 0 0 290 200 L 310 200 A 20 20 0 0 1 270 200 A 5 5 0 0 0 280 200 A 27.5 27.5 0 0 0 225 200 A 12.5 12.5 0 0 1 200 200 A 12.5 12.5 0 0 0 175 200 A 12.5 12.5 0 0 1 150 200 L -340 200 L -225 0 Z",
    )
  let assert Ok(actual) =
    offset.path_with(
      source,
      9.0,
      offset.Round,
      offset.Butt,
      offset.default_options(),
      offset.SingleOffsetTrimming(True, offset.CuspTrimming),
    )
  let assert [contour] = actual.subpaths
  assert svg_path.subpath_is_closed(contour)
  assert float.absolute_value(
      area.signed_subpath(contour) -. 141_959.84850931115,
    )
    <. 1.0e-6
  // The lower arc connects the two outer-arc intersections directly.
  assert list.any(svg_path.subpath_segments(contour), fn(segment) {
    case segment {
      Arc(start:, radius:, end:, ..) ->
        float.absolute_value(radius.x -. 16.5) <. 1.0e-8
        && float.absolute_value(start.x -. 152.25) <. 1.0e-8
        && float.absolute_value(end.x -. 162.75) <. 1.0e-8
      _ -> False
    }
  })
}

// Both competing routes contain submerged pieces. Prefer neither on that
// basis: minimizing submerged span used to split this into three contours.
pub fn offside_mixed_routes_preserve_inner_rectangle_walk_test() {
  let assert Ok(source) = parse.path("M -1 -0.5 L -1 0.5 L 1 0.5 L 1 -0.5 Z")
  let assert Ok(actual) =
    offset.path_with(
      source,
      1.2,
      offset.Round,
      offset.Butt,
      offset.default_options(),
      offset.SingleOffsetTrimming(True, offset.NoTrimming),
    )
  let assert [contour] = actual.subpaths
  assert svg_path.subpath_is_closed(contour)
  assert list.length(svg_path.subpath_segments(contour)) == 18
  assert float.absolute_value(
      area.signed_subpath(contour) -. 0.03987555098556522,
    )
    <. 1.0e-9
}
