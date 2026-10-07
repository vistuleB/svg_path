//// Line construction with an explicit adjacent-point tolerance.

import svg_path
import svg_path/point as point_helpers

@internal
pub fn segments(
  tolerance: Float,
  points: List(svg_path.Point),
) -> List(svg_path.Segment) {
  case points {
    [] | [_] -> []
    [first, second, ..rest] -> {
      let tail = segments(tolerance, [second, ..rest])
      case point_helpers.near(first, second, tolerance:) {
        True -> tail
        False -> [svg_path.Line(start: first, end: second), ..tail]
      }
    }
  }
}
