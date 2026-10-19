import gleam/list
import svg_path.{Arc, Point}
import svg_path/intersections

pub fn main() {
  list.each([0.0, 0.000000000001, 0.0000000001, 0.000000002], fn(gap) {
    let a =
      Arc(Point(1.0, 0.0), Point(1.0, 1.0), 0.0, False, True, Point(0.0, 1.0))
    let b =
      Arc(
        Point(0.0, 1.0 +. gap),
        Point(1.0, 1.0),
        0.0,
        False,
        True,
        Point(-1.0, 2.0 +. gap),
      )
    echo #(gap, intersections.segment(a, b))
  })
}
