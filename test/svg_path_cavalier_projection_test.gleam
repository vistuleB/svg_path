import gleam/float
import svg_path.{type Point, Arc, Point}
import svg_path/distance

// Reduced from Cavalier Contours CX00881 and related shallow-arc failures.
// Expected values computed independently with 80-digit circle geometry.
pub fn shallow_circle_projection_test() {
  let arc =
    Arc(
      Point(0.0, 0.0),
      Point(10_000_000.0, 10_000_000.0),
      0.0,
      False,
      True,
      Point(10.0, 0.0),
    )
  check(
    arc,
    Point(3.0, 1.0),
    Point(2.99999979999977, -0.000001049999960000028),
    1.00000104999998,
  )
  check(
    svg_path.segment_reverse(arc),
    Point(3.0, 1.0),
    Point(2.99999979999977, -0.000001049999960000028),
    1.00000104999998,
  )
}

// An independently chosen ellipse point plus its outward unit normal gives
// a unique nearest point and distance one; this is not a circular special case.
pub fn shallow_ellipse_projection_test() {
  let arc =
    Arc(
      Point(0.0, 0.0),
      Point(10_000_000.0, 20_000_000.0),
      0.0,
      False,
      True,
      Point(10.0, 0.0),
    )
  let query = Point(2.999999600000000000024, -1.00000209999992000015)
  let foot = Point(3.0, -0.00000210000000000015225)
  check(arc, query, foot, 1.0)
  check(svg_path.segment_reverse(arc), query, foot, 1.0)
}

pub fn rotated_translated_shallow_ellipse_projection_test() {
  let arc =
    Arc(
      Point(100.0, -40.0),
      Point(10_000_000.0, 20_000_000.0),
      90.0,
      False,
      True,
      Point(100.0, -30.0),
    )
  check(
    arc,
    Point(101.00000209999992, -37.0000004),
    Point(100.0000021, -37.0),
    1.0,
  )
  check(
    svg_path.segment_reverse(arc),
    Point(101.00000209999992, -37.0000004),
    Point(100.0000021, -37.0),
    1.0,
  )
}

pub fn shallow_arc_endpoint_projection_test() {
  let arc =
    Arc(
      Point(0.0, 0.0),
      Point(10_000_000.0, 20_000_000.0),
      0.0,
      False,
      True,
      Point(10.0, 0.0),
    )
  check(arc, Point(-3.0, 4.0), Point(0.0, 0.0), 5.0)
  check(arc, Point(13.0, 4.0), Point(10.0, 0.0), 5.0)
}

fn check(arc: svg_path.Segment, query: Point, foot: Point, expected: Float) {
  let assert Ok(svg_path.Projection(at:, point:, distance: actual)) =
    distance.segment_projection(query, arc)
  assert at >=. 0.0 && at <=. 1.0
  assert float.absolute_value(point.x -. foot.x) <. 1.0e-9
  assert float.absolute_value(point.y -. foot.y) <. 1.0e-9
  assert float.absolute_value(actual -. expected) <. 1.0e-9
}
