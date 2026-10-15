import gleam/io
import gleam/string
import svg_path.{Line, Point, QuadraticBezier}
import svg_path/encounters
import svg_path/intersections
import svg_path/overlaps

pub fn main() {
  let line = Line(Point(1.0, 1.0), Point(2.0, 2.0))
  let curve = QuadraticBezier(Point(0.0, 0.0), Point(3.0, 3.0), Point(0.5, 0.5))
  io.println("line then quadratic: overlaps, intersections, encounters")
  show(overlaps.segment(line, curve))
  show(intersections.segment(line, curve))
  show(encounters.segment(line, curve))
  io.println("quadratic then line: overlaps, intersections, encounters")
  show(overlaps.segment(curve, line))
  show(intersections.segment(curve, line))
  show(encounters.segment(curve, line))
}

fn show(value) {
  io.println(string.inspect(value))
}
