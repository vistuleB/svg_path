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

pub fn circle_radial_projection_with_minimal_budget_test() {
  let arc =
    Arc(Point(5.0, 0.0), Point(5.0, 5.0), 0.0, False, True, Point(0.0, 5.0))
  circle_check(arc, Point(6.0, 8.0), Point(3.0, 4.0), 5.0)
  circle_check(arc, Point(0.6, 0.8), Point(3.0, 4.0), 4.0)
  circle_check(arc, Point(3.0e-10, 4.0e-10), Point(3.0, 4.0), 4.9999999995)
}

pub fn circle_projection_clamps_outside_sweep_test() {
  let arc =
    Arc(Point(5.0, 0.0), Point(5.0, 5.0), 0.0, False, True, Point(0.0, 5.0))
  circle_check(arc, Point(8.0, -4.0), Point(5.0, 0.0), 5.0)
  circle_check(arc, Point(-4.0, 8.0), Point(0.0, 5.0), 5.0)
}

pub fn circle_projection_large_and_wrapped_sweeps_test() {
  let major =
    Arc(Point(5.0, 0.0), Point(5.0, 5.0), 0.0, True, False, Point(0.0, 5.0))
  circle_check(major, Point(-6.0, -8.0), Point(-3.0, -4.0), 5.0)
  let wrapped =
    Arc(Point(0.0, -5.0), Point(5.0, 5.0), 0.0, False, True, Point(5.0, 0.0))
  circle_check(wrapped, Point(6.0, -8.0), Point(3.0, -4.0), 5.0)
}

pub fn circle_projection_center_tie_test() {
  let arc =
    Arc(Point(5.0, 0.0), Point(5.0, 5.0), 0.0, False, True, Point(0.0, 5.0))
  let assert Ok(svg_path.Projection(at:, point:, distance: actual)) =
    distance.segment_projection_with(Point(0.0, 0.0), arc, minimal_options())
  assert at >=. 0.0 && at <=. 1.0
  assert float.absolute_value(actual -. 5.0) <. 1.0e-12
  assert float.absolute_value(point.x *. point.x +. point.y *. point.y -. 25.0)
    <. 1.0e-12
}

pub fn circle_projection_corrected_negative_radii_test() {
  let arc =
    Arc(Point(0.0, 0.0), Point(-1.0, -1.0), 0.0, False, True, Point(10.0, 0.0))
  circle_check(arc, Point(5.0, -10.0), Point(5.0, -5.0), 5.0)
}

pub fn shallow_circle_analytic_projection_test() {
  let arc =
    Arc(
      Point(0.0, 0.0),
      Point(10_000_000.0, 10_000_000.0),
      0.0,
      False,
      True,
      Point(10.0, 0.0),
    )
  circle_check(
    arc,
    Point(3.0, 1.0),
    Point(2.99999979999977, -0.000001049999960000028),
    1.00000104999998,
  )
}

pub fn circle_projection_still_validates_options_test() {
  let arc =
    Arc(Point(5.0, 0.0), Point(5.0, 5.0), 0.0, False, True, Point(0.0, 5.0))
  assert distance.segment_projection_with(
      Point(6.0, 8.0),
      arc,
      svg_path.DistanceOptions(..minimal_options(), samples: 0),
    )
    == Error(svg_path.InvalidDistanceSamples(0))
  assert distance.segment_projection_with(
      Point(6.0, 8.0),
      arc,
      svg_path.DistanceOptions(..minimal_options(), max_iterations: 0),
    )
    == Error(svg_path.InvalidDistanceMaxIterations(0))
}

fn minimal_options() -> svg_path.DistanceOptions {
  svg_path.DistanceOptions(
    ..distance.default_distance_options(),
    samples: 1,
    max_iterations: 1,
  )
}

fn circle_check(
  arc: svg_path.Segment,
  query: Point,
  foot: Point,
  expected: Float,
) {
  let assert Ok(svg_path.Projection(at:, point:, distance: actual)) =
    distance.segment_projection_with(query, arc, minimal_options())
  let assert Ok(svg_path.Projection(
    at: reversed_at,
    point: reversed_point,
    distance: reversed_distance,
  )) =
    distance.segment_projection_with(
      query,
      svg_path.segment_reverse(arc),
      minimal_options(),
    )
  assert float.absolute_value(point.x -. foot.x) <. 1.0e-9
  assert float.absolute_value(point.y -. foot.y) <. 1.0e-9
  assert float.absolute_value(actual -. expected) <. 1.0e-9
  assert float.absolute_value(reversed_point.x -. foot.x) <. 1.0e-9
  assert float.absolute_value(reversed_point.y -. foot.y) <. 1.0e-9
  assert float.absolute_value(reversed_distance -. expected) <. 1.0e-9
  assert float.absolute_value(at +. reversed_at -. 1.0) <. 1.0e-9
}
