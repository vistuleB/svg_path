import gleam/io
import gleam/list
import gleam/string
import svg_path.{Arc, CubicBezier, Line, Point, QuadraticBezier}
import svg_path/encounters
import svg_path/intersections
import svg_path/overlaps

pub fn main() {
  let arc =
    Arc(Point(2.0, 1.0), Point(1.0, 1.0), 0.0, False, True, Point(0.0, 1.0))
  list.each(
    [
      #("center", Point(1.0, 1.0)),
      #("arc endpoint", Point(2.0, 1.0)),
      #("arc interior", Point(1.0, 2.0)),
      #("outside", Point(3.0, 3.0)),
    ],
    fn(named) {
      let p = named.1
      list.each(
        [
          #("line", Line(p, p)),
          #("quadratic", QuadraticBezier(p, p, p)),
          #("cubic", CubicBezier(p, p, p, p)),
        ],
        fn(constant) {
          io.println(named.0 <> " / " <> constant.0)
          list.each([#(constant.1, arc), #(arc, constant.1)], fn(pair) {
            io.println(string.inspect(intersections.segment(pair.0, pair.1)))
          })
        },
      )
    },
  )
  let p = Point(1.0, 1.0)
  let constants = [
    Line(p, p),
    QuadraticBezier(p, p, p),
    CubicBezier(p, p, p, p),
  ]
  list.each(constants, fn(a) {
    list.each(constants, fn(b) {
      io.println("constant pair " <> string.inspect(#(a, b)))
      io.println(
        "intersections " <> string.inspect(intersections.segment(a, b)),
      )
      io.println("overlaps " <> string.inspect(overlaps.segment(a, b)))
      io.println("encounters " <> string.inspect(encounters.segment(a, b)))
    })
    io.println("constant versus nondegenerate line")
    let line = Line(Point(0.0, 1.0), Point(2.0, 1.0))
    io.println(string.inspect(intersections.segment(a, line)))
    io.println(string.inspect(intersections.segment(line, a)))
  })
}
