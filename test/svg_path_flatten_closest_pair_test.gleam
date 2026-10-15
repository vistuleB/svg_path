import gleam/float
import gleam/list
import gleeunit/should
import svg_path.{Arc, Line, Point}
import svg_path/distance
import svg_path/point

fn quarter_circle() {
  Arc(Point(3.0, 0.0), Point(3.0, 3.0), 0.0, False, True, Point(0.0, 3.0))
}

// FL001: reduced from Flatten's Segment.distanceTo(Circle) fixtures.
// The intersection is (sqrt(5), 2); endpoint projections alone gave a loose
// bound and a seed list large enough to overflow the JavaScript call stack.
pub fn crossing_line_arc_closest_pair_test() {
  let line = Line(Point(0.0, 2.0), Point(4.0, 2.0))
  let arc = quarter_circle()
  list.each([#(line, arc), #(arc, line)], fn(pair) {
    let assert Ok(hit) = distance.segment_segment_closest_pair(pair.0, pair.1)
    let assert Ok(left) = svg_path.segment_point(pair.0, hit.left_at)
    let assert Ok(right) = svg_path.segment_point(pair.1, hit.right_at)
    point.distance(left, hit.left_point) |> should.equal(0.0)
    point.distance(right, hit.right_point) |> should.equal(0.0)
    let assert True = hit.distance <. 0.00000001
    let assert True =
      float.absolute_value(hit.left_point.x *. hit.left_point.x -. 5.0)
      <. 0.00000001
    let assert True =
      float.absolute_value(hit.left_point.y -. 2.0) <. 0.00000001
  })
}

pub fn crossing_line_arc_path_closest_pair_test() {
  let line = Line(Point(0.0, 2.0), Point(4.0, 2.0))
  let assert Ok(hit) =
    distance.path_path_closest_pair(
      svg_path.segment_as_path(line),
      svg_path.segment_as_path(quarter_circle()),
    )
  let assert True = hit.distance <. 0.00000001
  point.distance(hit.left_point, hit.right_point) |> should.equal(hit.distance)
  hit.left_at.subpath_index |> should.equal(0)
  hit.right_at.subpath_index |> should.equal(0)
}

pub fn near_tangent_distance_keeps_actual_positive_gap_test() {
  let y = 3.0 +. 0.0000000001
  let line = Line(Point(-1.0, y), Point(1.0, y))
  let assert Ok(hit) =
    distance.segment_segment_closest_pair(line, quarter_circle())
  let assert True = hit.distance >. 0.0
  let assert True =
    float.absolute_value(hit.distance -. { y -. 3.0 }) <. 0.0000000000001
  point.distance(hit.left_point, hit.right_point) |> should.equal(hit.distance)
}

pub fn disjoint_line_arc_distance_preserves_fallback_test() {
  let line = Line(Point(-1.0, 4.0), Point(1.0, 4.0))
  let assert Ok(hit) =
    distance.segment_segment_closest_pair(line, quarter_circle())
  let assert True = float.absolute_value(hit.distance -. 1.0) <. 0.00000001
}

// FL005: a disjoint line/quarter-circle previously exhausted the search on JS.
// The center projects onto the line at t = 0.46; the closest circle point is
// 50 units towards that projection from (250, 300).
pub fn disjoint_oblique_line_arc_interior_minimum_test() {
  let line = Line(Point(170.0, 200.0), Point(120.0, 350.0))
  let arc =
    Arc(
      Point(200.0, 300.0),
      Point(50.0, 50.0),
      0.0,
      False,
      True,
      Point(250.0, 250.0),
    )
  let assert Ok(radius_distance) =
    float.square_root(102.0 *. 102.0 +. 34.0 *. 34.0)
  list.each([#(line, arc), #(arc, line)], fn(pair) {
    let assert Ok(hit) = distance.segment_segment_closest_pair(pair.0, pair.1)
    let assert True =
      float.absolute_value(hit.distance -. { radius_distance -. 50.0 })
      <. 0.000000001
    let assert Ok(a) = svg_path.segment_point(pair.0, hit.left_at)
    let assert Ok(b) = svg_path.segment_point(pair.1, hit.right_at)
    point.distance(a, hit.left_point) |> should.equal(0.0)
    point.distance(b, hit.right_point) |> should.equal(0.0)
    let assert True = hit.left_at >. 0.0 && hit.left_at <. 1.0
    let assert True = hit.right_at >. 0.0 && hit.right_at <. 1.0
  })
}

pub fn line_arc_minimum_clamps_to_finite_line_test() {
  let line = Line(Point(-5.0, 4.0), Point(-1.0, 4.0))
  let assert Ok(hit) =
    distance.segment_segment_closest_pair(line, quarter_circle())
  let assert Ok(expected) = float.square_root(2.0)
  let assert True =
    float.absolute_value(hit.distance -. expected) <. 0.000000001
  hit.left_at |> should.equal(1.0)
  hit.right_at |> should.equal(1.0)
}

pub fn zero_length_line_arc_minimum_test() {
  let line = Line(Point(0.0, 4.0), Point(0.0, 4.0))
  let assert Ok(hit) =
    distance.segment_segment_closest_pair(line, quarter_circle())
  let assert True = float.absolute_value(hit.distance -. 1.0) <. 0.000000001
}

// Noncircular ellipse: the support in direction (1,1) is sqrt(4² + 2²).
// Its closest point to x+y=10 lies strictly inside this quarter ellipse.
pub fn oblique_line_ellipse_minimum_test() {
  let line = Line(Point(0.0, 10.0), Point(10.0, 0.0))
  let arc =
    Arc(Point(4.0, 0.0), Point(4.0, 2.0), 0.0, False, True, Point(0.0, 2.0))
  let assert Ok(support) = float.square_root(20.0)
  let assert Ok(root_two) = float.square_root(2.0)
  let assert Ok(hit) = distance.segment_segment_closest_pair(line, arc)
  let assert True =
    float.absolute_value(hit.distance -. { { 10.0 -. support } /. root_two })
    <. 0.000000001
}

// FL005's remaining arc/arc pair. The facing points on the two circles lie
// inside both quarter arcs, with distance |(75,150)| - 30 - 50.
pub fn disjoint_oblique_arc_pair_minimum_test() {
  let left =
    Arc(
      Point(205.0, 150.0),
      Point(30.0, 30.0),
      0.0,
      False,
      True,
      Point(175.0, 180.0),
    )
  let right =
    Arc(
      Point(200.0, 300.0),
      Point(50.0, 50.0),
      0.0,
      False,
      True,
      Point(250.0, 250.0),
    )
  let assert Ok(center_distance) =
    float.square_root(75.0 *. 75.0 +. 150.0 *. 150.0)
  list.each(
    [
      #(left, right),
      #(right, left),
      #(svg_path.segment_reverse(left), svg_path.segment_reverse(right)),
    ],
    fn(pair) {
      let assert Ok(hit) = distance.segment_segment_closest_pair(pair.0, pair.1)
      let assert True =
        float.absolute_value(hit.distance -. { center_distance -. 80.0 })
        <. 0.000000001
      let assert Ok(a) = svg_path.segment_point(pair.0, hit.left_at)
      let assert Ok(b) = svg_path.segment_point(pair.1, hit.right_at)
      point.distance(a, hit.left_point) |> should.equal(0.0)
      point.distance(b, hit.right_point) |> should.equal(0.0)
      let assert True = hit.left_at >. 0.0 && hit.left_at <. 1.0
      let assert True = hit.right_at >. 0.0 && hit.right_at <. 1.0
    },
  )
}

// Construct parallel supporting lines separated by 10 along (1,1). The
// supporting ellipse points are interior to the first/third quadrant arcs.
pub fn disjoint_elliptical_arc_pair_minimum_test() {
  let assert Ok(root_two) = float.square_root(2.0)
  let assert Ok(root_twenty) = float.square_root(20.0)
  let cx = 32.0 /. root_twenty +. 10.0 /. root_two
  let cy = 8.0 /. root_twenty +. 10.0 /. root_two
  let left =
    Arc(Point(4.0, 0.0), Point(4.0, 2.0), 0.0, False, True, Point(0.0, 2.0))
  let right =
    Arc(
      Point(cx -. 4.0, cy),
      Point(4.0, 2.0),
      0.0,
      False,
      True,
      Point(cx, cy -. 2.0),
    )
  let assert Ok(hit) = distance.segment_segment_closest_pair(left, right)
  let assert True = float.absolute_value(hit.distance -. 10.0) <. 0.000000001
}

pub fn arc_pair_bound_preserves_positive_near_tangent_gap_test() {
  let cx = 10.0 +. 0.00000001
  let left =
    Arc(Point(0.0, -5.0), Point(5.0, 5.0), 0.0, False, True, Point(0.0, 5.0))
  let right =
    Arc(Point(cx, 5.0), Point(5.0, 5.0), 0.0, False, True, Point(cx, -5.0))
  let assert Ok(hit) = distance.segment_segment_closest_pair(left, right)
  let assert True = hit.distance >. 0.0
  let assert True =
    float.absolute_value(hit.distance -. { cx -. 10.0 }) <. 0.000000000001
}
