import gleam/float
import gleam/list
import svg_path.{type Point, Arc, CrossingOptions, Point}
import svg_path/containment
import svg_path/intersections

pub fn separated_quarter_arc_endpoints_return_empty_test() {
  list.each([0.0000000000001, 0.000000001], fn(tolerance) {
    let a =
      Arc(Point(1.0, 0.0), Point(1.0, 1.0), 0.0, False, True, Point(0.0, 1.0))
    let b =
      Arc(
        Point(0.0, 1.000000000001),
        Point(1.0, 1.0),
        0.0,
        False,
        True,
        Point(-1.0, 2.000000000001),
      )
    let options =
      intersections.IntersectionOptions(
        ..intersections.default_options(),
        tolerance:,
      )
    assert intersections.segment_with(a, b, options:) == Ok([])
    assert intersections.segment_with(b, a, options:) == Ok([])
  })
}

fn rotate(point: Point, quarter: Int) -> Point {
  case quarter {
    0 -> point
    1 -> Point(0.0 -. point.y, point.x)
    2 -> Point(0.0 -. point.x, 0.0 -. point.y)
    _ -> Point(point.y, 0.0 -. point.x)
  }
}

pub fn arc_line_excess_distance_respects_tolerance_test() {
  list.each([0.0009765625, 1.0, 1024.0], fn(scale) {
    list.each([0, 1, 2, 3], fn(quarter) {
      let arc =
        Arc(
          rotate(Point(scale, 0.0), quarter),
          Point(scale, scale),
          0.0,
          False,
          True,
          rotate(Point(0.0, scale), quarter),
        )
      let tolerance = 0.000000000001 *. scale
      let options =
        CrossingOptions(
          ..containment.default_crossing_options(),
          signed_line_distance_tolerance: tolerance,
        )
      list.each([0.0, 0.0000000000005, 0.000000000001, 0.000000000002], fn(gap) {
        let height = { 1.0 +. gap } *. scale
        let result =
          containment.segment_ray_crossings_with(
            arc,
            origin: rotate(Point(0.0, height), quarter),
            direction: rotate(Point(1.0, 0.0), quarter),
            options:,
          )
        case height -. scale <=. tolerance {
          True -> {
            let assert Ok([#(at, _)]) = result
            assert float.absolute_value(at -. 1.0) <=. 0.000000000001
          }
          False -> {
            assert result == Ok([])
          }
        }
      })
    })
  })
}
