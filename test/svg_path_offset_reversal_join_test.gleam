import gleam/float
import gleam/list
import svg_path.{Arc, Line, Point}
import svg_path/area
import svg_path/offset
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
