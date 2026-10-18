import gleam/io
import gleam/string
import svg_path.{Arc, Point}
import svg_path/distance

pub fn main() {
  let query = Point(3.0, 1.0)
  let control = Arc(Point(0.0, 0.0), Point(1_000_000.0, 1_000_000.0), 0.0, False, True, Point(10.0, 0.0))
  let arc = Arc(Point(0.0, 0.0), Point(10_000_000.0, 10_000_000.0), 0.0, False, True, Point(10.0, 0.0))
  io.println("radius 1e6 control")
  io.println(string.inspect(distance.segment_projection(query, control)))
  io.println("radius 1e7 default")
  io.println(string.inspect(distance.segment_projection(query, arc)))
  io.println("radius 1e7 with 1000 iterations")
  let options = distance.default_distance_options()
  io.println(string.inspect(distance.segment_projection_with(query, arc, svg_path.DistanceOptions(..options, max_iterations: 1000))))
}
