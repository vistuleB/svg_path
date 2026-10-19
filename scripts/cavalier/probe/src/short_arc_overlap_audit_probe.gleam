import gleam/list
import svg_path.{Arc, Point}
import svg_path/intersections

pub fn main() {
  list.each([0.0000001, 0.00000001], fn(chord) {
    let arc =
      Arc(Point(0.0, 0.0), Point(1.0, 1.0), 0.0, False, True, Point(chord, 0.0))
    echo #(
      chord,
      intersections.segment(arc, arc),
      intersections.segment(arc, svg_path.segment_reverse(arc)),
    )
  })
}
