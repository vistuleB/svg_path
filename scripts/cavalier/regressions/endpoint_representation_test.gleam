// Original experiment regression; permanent expanded suite placement:
// test/svg_path_endpoint_representation_test.gleam.
import gleam/list
import svg_path.{Line, Point, QuadraticBezier}
import svg_path/intersections

pub fn straight_edge_endpoint_matching_agrees_across_representations_test() {
  list.each([0.0, 0.0000000001, 0.000000002], fn(gap) {
    let a = Line(Point(0.0, 0.0), Point(1.0, 0.0))
    let b = Line(Point(1.0 +. gap, gap), Point(1.0 +. gap, 1.0))
    let qa = QuadraticBezier(a.start, Point(0.5, 0.0), a.end)
    let qb =
      QuadraticBezier(b.start, Point(1.0 +. gap, { 1.0 +. gap } /. 2.0), b.end)
    list.each([a, qa], fn(left) {
      list.each([b, qb], fn(right) {
        list.each([False, True], fn(reverse) {
          let left = case reverse {
            True -> svg_path.segment_reverse(left)
            False -> left
          }
          let right = case reverse {
            True -> svg_path.segment_reverse(right)
            False -> right
          }
          let assert Ok(found) = intersections.segment(left, right)
          assert list.length(found)
            == case gap == 0.0 {
              True -> 1
              False -> 0
            }
        })
      })
    })
  })
}
