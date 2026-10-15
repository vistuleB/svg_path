import gleam/io
import gleam/string
import svg_path.{CubicBezier, Line, Point}
import svg_path/distance

pub fn main() {
  let curve =
    CubicBezier(
      Point(0.0, 0.0),
      Point(0.0, 1.0),
      Point(1.0, 1.0),
      Point(1.0, 0.0),
    )
  let line = Line(Point(0.0, 1.0), Point(1.0, 1.0))
  io.println(string.inspect(distance.segment_segment_closest_pair(curve, line)))
}
