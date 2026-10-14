import gleam/list
import gleeunit/should
import svg_path.{CubicBezier, Line, Point}
import svg_path/distance

// Reduced from FloBezier tolerance-zero.spec.ts (FB007 in scripts/flobezier).
// y(t) = 3t(1-t) has its maximum 3/4 at t = 1/2, so the gap is 1/4.
pub fn broad_closest_pair_search_does_not_overflow_test() {
  let curve =
    CubicBezier(
      Point(0.0, 0.0),
      Point(0.0, 1.0),
      Point(1.0, 1.0),
      Point(1.0, 0.0),
    )
  let line = Line(Point(0.0, 1.0), Point(1.0, 1.0))
  list.each([#(curve, line), #(line, curve)], fn(pair) {
    let assert Ok(projection) =
      distance.segment_segment_closest_pair(pair.0, pair.1)
    projection.left_at |> should.equal(0.5)
    projection.right_at |> should.equal(0.5)
    projection.distance |> should.equal(0.25)
  })
}
