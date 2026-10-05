import gleam/float
import gleam/list
import gleeunit/should
import svg_path
import svg_path/intersections as ix

fn crossing_pair(scale: Float, dx: Float, dy: Float) {
  let p = fn(x, y) { svg_path.Point(x *. scale +. dx, y *. scale +. dy) }
  #(
    svg_path.CubicBezier(
      p(60.0, 30.0),
      p(90.0, 30.0),
      p(90.0, 60.0),
      p(120.0, 30.0),
    ),
    svg_path.CubicBezier(
      p(20.0, -10.0),
      p(50.0, 40.0),
      p(80.0, -20.0),
      p(110.0, 50.0),
    ),
  )
}

fn check_crossing(scale: Float, dx: Float, dy: Float) {
  let #(left, right) = crossing_pair(scale, dx, dy)
  list.each(
    [
      ix.default_options(),
      ix.IntersectionOptions(..ix.default_options(), tolerance: 0.000001),
    ],
    fn(options) {
      let assert Ok([hit]) = ix.segment_with(left, right, options:)
      assert float.absolute_value(hit.left_t -. 0.8120634871623037)
        <. 0.00000001
      assert float.absolute_value(hit.right_t -. 0.9540694360628613)
        <. 0.00000001
      let allowed =
        scale
        *. 0.0000001
        +. float.max(float.absolute_value(dx), float.absolute_value(dy))
        *. 0.000000000001
      assert float.absolute_value(
          hit.point.x -. { 105.86624924565754 *. scale +. dx },
        )
        <. allowed
      assert float.absolute_value(
          hit.point.y -. { 41.15407707522564 *. scale +. dy },
        )
        <. allowed
    },
  )
}

pub fn transverse_cubics_preserve_intersection_across_scales_test() {
  list.each([1.0, 16.0, 30.0, 1000.0], fn(scale) {
    check_crossing(scale, 0.0, 0.0)
  })
}

pub fn transverse_cubics_preserve_intersection_after_translation_test() {
  list.each([-1_000_000.0, 1_000_000.0], fn(offset) {
    check_crossing(1.0, offset, 0.0 -. offset)
  })
}

pub fn roundoff_allowance_does_not_join_separated_curves_test() {
  list.each([0.0, -1_000_000.0, 1_000_000.0], fn(offset) {
    let curve = fn(gap) {
      svg_path.QuadraticBezier(
        svg_path.Point(offset, offset +. gap),
        svg_path.Point(offset +. 1.0, offset +. 1.0 +. gap),
        svg_path.Point(offset +. 2.0, offset +. gap),
      )
    }
    ix.segment(curve(0.0), curve(0.00001)) |> should.equal(Ok([]))
  })
}

pub fn unrepresentable_tolerance_reports_error_instead_of_empty_result_test() {
  let #(left, right) = crossing_pair(16.0, 0.0, 0.0)
  let assert Error(svg_path.InternalUncertifiedSegmentIntersection(..)) =
    ix.segment_with(
      left,
      right,
      options: ix.IntersectionOptions(
        ..ix.default_options(),
        tolerance: 0.00000000000001,
      ),
    )
}
