import gleam/io
import gleam/list
import gleam/string
import svg_path.{CubicBezier, Line, Point, QuadraticBezier}
import svg_path/intersections
import svg_path/overlaps

pub fn main() {
  let folded = QuadraticBezier(Point(0.0, 0.0), Point(4.0, 0.0), Point(0.0, 0.0))
  let fixtures = [
    #("positive overlap", Line(Point(1.0, 0.0), Point(3.0, 0.0)), folded),
    #("touch only", Line(Point(2.0, 0.0), Point(3.0, 0.0)), folded),
    #("disjoint", Line(Point(3.0, 0.0), Point(4.0, 0.0)), folded),
    #("FI003-a", QuadraticBezier(Point(0.0, 0.0), Point(1.0, 1.0), Point(0.25, 0.25)), CubicBezier(Point(2.0, 2.0), Point(0.5, 0.5), Point(0.25, 0.25), Point(-1.0, -1.0))),
    #("FI003-b", QuadraticBezier(Point(0.1, 0.1), Point(0.8, 0.8), Point(0.2, 0.2)), QuadraticBezier(Point(1.0, 1.0), Point(0.5, 0.5), Point(0.3, 0.3))),
  ]
  list.each(fixtures, fn(fixture) {
    let #(name, a, b) = fixture
    io.println(name)
    list.each([#(a, b), #(b, a)], fn(pair) {
      io.println(string.inspect(overlaps.segment(pair.0, pair.1)))
      io.println(string.inspect(intersections.segment(pair.0, pair.1)))
    })
  })
}
