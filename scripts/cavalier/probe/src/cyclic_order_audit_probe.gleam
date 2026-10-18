import gleam/io
import gleam/string
import svg_path.{Line, Point}
import svg_path/arrangement
import svg_path/containment

pub fn main() {
  let long = Line(Point(0.0, 0.0), Point(1.0, 0.0))
  let short = Line(Point(0.0, 0.0), Point(0.0, 0.000003))
  io.println(
    "two perpendicular lines, minimum_length 1e-8, vertex tolerance 1e-6",
  )
  io.println(
    string.inspect(arrangement.build_with(
      [long, short],
      0.000001,
      0.00000001,
      0.0,
    )),
  )
  io.println("long-edge circle roots, radius 2.4e-6")
  io.println(
    string.inspect(containment.segment_crossings_with(
      long,
      where: fn(p) { p.x *. p.x +. p.y *. p.y -. 0.0000024 *. 0.0000024 },
      options: svg_path.CrossingOptions(
        samples: 100,
        signed_line_distance_tolerance: 5.8e-12,
        max_iterations: 100,
      ),
    )),
  )
  io.println("control: short line length 3.1e-6")
  let control =
    arrangement.build_with(
      [long, Line(Point(0.0, 0.0), Point(0.0, 0.0000031))],
      0.000001,
      0.00000001,
      0.0,
    )
  io.println(case control {
    Ok(_) -> "Ok"
    Error(e) -> string.inspect(e)
  })
}
