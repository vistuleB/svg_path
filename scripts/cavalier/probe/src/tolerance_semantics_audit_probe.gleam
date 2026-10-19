import svg_path.{Line, Point, QuadraticBezier}
import svg_path/intersections

pub fn main() {
  let a = Line(Point(0.0, 0.0), Point(1.0, 0.0))
  let b = Line(Point(1.0000000001, 0.0000000001), Point(1.0000000001, 1.0))
  let qa = QuadraticBezier(a.start, Point(0.5, 0.0), a.end)
  let qb = QuadraticBezier(b.start, Point(1.0000000001, 0.50000000005), b.end)
  echo #("line/line", intersections.segment(a, b))
  echo #("quadratic/quadratic", intersections.segment(qa, qb))
  echo #("line/quadratic", intersections.segment(a, qb))
  echo #(
    "constant points",
    intersections.segment(
      Line(Point(0.0, 0.0), Point(0.0, 0.0)),
      Line(Point(0.0000000001, 0.0), Point(0.0000000001, 0.0)),
    ),
  )
  echo #(
    "parallel lines",
    intersections.segment(
      a,
      Line(Point(0.0, 0.0000000001), Point(1.0, 0.0000000001)),
    ),
  )
}
