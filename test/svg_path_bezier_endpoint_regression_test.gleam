import gleam/list
import svg_path/bezier

pub fn evaluation_preserves_exact_endpoints_test() {
  list.each(curves(), fn(curve) {
    assert bezier.point(curve, at: 0.0) == bezier.start(curve)
    assert bezier.point(curve, at: -0.0) == bezier.start(curve)
    assert bezier.point(curve, at: 1.0) == bezier.end(curve)
  })
}

pub fn endpoint_splits_preserve_whole_curve_and_collapse_all_controls_test() {
  list.each(curves(), fn(curve) {
    list.each([0.0, -0.0], fn(t) {
      let assert Ok(#(collapsed, whole)) = bezier.split_inside(curve, at: t)
      assert whole == curve
      assert collapsed
        == bezier.map_points(curve, with: fn(_) { bezier.start(curve) })
    })
    let assert Ok(#(whole, collapsed)) = bezier.split_inside(curve, at: 1.0)
    assert whole == curve
    assert collapsed
      == bezier.map_points(curve, with: fn(_) { bezier.end(curve) })
  })
}

fn curves() -> List(bezier.BezierData) {
  // Exact equality matters: 1 + (0.1 - 1) is not exactly 0.1.
  let start = bezier.BezierPoint(1.0, -0.0)
  let end = bezier.BezierPoint(0.1, 0.2)
  [
    bezier.LinearBezierData(start:, end:),
    bezier.QuadraticBezierData(
      start:,
      control: bezier.BezierPoint(0.3, 1.0),
      end:,
    ),
    bezier.CubicBezierData(
      start:,
      control1: bezier.BezierPoint(0.3, 1.0),
      control2: bezier.BezierPoint(-1.0, 0.7),
      end:,
    ),
  ]
}

pub fn split_many_trims_both_signed_zero_boundaries_test() {
  let curve =
    bezier.LinearBezierData(
      bezier.BezierPoint(1.0, 0.0),
      bezier.BezierPoint(0.1, 0.2),
    )
  assert bezier.split_many(curve, at: [-0.0]) == [curve]
  assert bezier.split_many(curve, at: [0.0, -0.0, 0.0, 1.0]) == [curve]
  assert bezier.split_many_inside(curve, at: [-0.0, 0.0, -0.0, 1.0])
    == Ok([curve])
}

pub fn split_many_deduplicates_signed_zero_inside_extrapolated_range_test() {
  let curve =
    bezier.LinearBezierData(
      bezier.BezierPoint(0.0, 0.0),
      bezier.BezierPoint(1.0, 0.0),
    )
  // Here zero is an interior cut, so boundary trimming cannot hide duplicates.
  let expected = bezier.split_many(curve, at: [-0.5, 0.0, 0.5])
  assert list.length(expected) == 4
  assert bezier.split_many(curve, at: [0.5, -0.0, -0.5, 0.0, -0.0]) == expected
}
