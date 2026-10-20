import gleam/list
import svg_path.{Arc, Point}
import svg_path/degeneracy

pub fn main() {
  let shallow =
    Arc(Point(0.0, 0.0), Point(1.0, 1.0), 0.0, False, True, Point(0.00003, 0.0))
  let quarter =
    Arc(Point(1.0, 0.0), Point(1.0, 1.0), 0.0, False, True, Point(0.0, 1.0))
  let thin =
    Arc(
      Point(-10.0, 0.0),
      Point(10.0, 0.0001),
      0.0,
      False,
      True,
      Point(10.0, 0.0),
    )
  list.each(
    [#("shallow", shallow), #("quarter", quarter), #("thin ellipse", thin)],
    fn(pair) {
      let #(name, arc) = pair
      echo #(name, degeneracy.segment_linearize_if_degenerate(arc, 0.001))
      echo #(name, "zero", degeneracy.segment_linearize_if_degenerate(arc, 0.0))
    },
  )
}
