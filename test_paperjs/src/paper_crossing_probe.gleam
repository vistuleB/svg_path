// Diagnostic reduction of Paper.js Boolean fixture 16; no expected-error assertions.
import gleam/io
import gleam/list
import gleam/string
import svg_path
import svg_path/containment

pub fn main() {
  let start = svg_path.Point(150.0, 160.0)
  let end = svg_path.Point(150.0, 80.0)
  let cubic = svg_path.CubicBezier(start, start, end, end)
  let line = svg_path.Line(start, end)
  list.each([80.0, 80.00000000006969, 79.99999999993031], fn(y) {
    list.each([#("cubic", cubic), #("line", line)], fn(pair) {
      io.println(
        string.inspect(#(
          pair.0,
          y,
          containment.segment_ray_crossings_with(
            pair.1,
            origin: svg_path.Point(150.0, y),
            direction: svg_path.Point(1.0, 0.0),
            options: svg_path.CrossingOptions(
              samples: 100,
              signed_line_distance_tolerance: 0.000000000001,
              max_iterations: 100,
            ),
          ),
        )),
      )
    })
  })
}
