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
