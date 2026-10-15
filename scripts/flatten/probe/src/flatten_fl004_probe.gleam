// Reduced FL004 diagnostic; this is not a passing regression test.
import gleam/io
import gleam/string
import svg_path.{Line, Point}
import svg_path/arrangement
import svg_path/intersections
import svg_path/overlaps

pub fn main() {
  let left = Line(Point(0.0, 0.0), Point(1.0, 1.0))
  let right = Line(Point(-0.0000002, 0.0000002), Point(1.0, 0.999997))
  io.println(
    "overlaps: "
    <> string.inspect(overlaps.segment_with(left, right, 0.0000005)),
  )
  io.println(
    "intersections: "
    <> string.inspect(intersections.segment_with(
      left,
      right,
      intersections.IntersectionOptions(
        ..intersections.default_options(),
        tolerance: 0.0000005,
      ),
    )),
  )
  io.println(
    "arrangement: "
    <> string.inspect(arrangement.build_with(
      [left, right],
      vertex_tolerance: 0.000001,
      minimum_length: 0.000000001,
      endpoint_sliver_tolerance: 0.0,
    )),
  )
}
