import gleam/float
import gleam/list
import svg_path.{Arc, Point}
import svg_path/intersections
import svg_path/offset

pub fn shared_circle_endpoint_does_not_create_interior_contacts_test() {
  // CC01267's first repeated cut: the circles' other intersection lies
  // outside both sweeps. The previous search reported an interior hit.
  let a =
    Arc(
      Point(42.88583436681323, -1.2670607979451385),
      Point(2.504034466969128, 2.504034466969128),
      0.0,
      False,
      True,
      Point(44.65470741897046, -2.0000001287369904),
    )
  let b =
    Arc(
      Point(44.65470741897046, -2.0000001287369904),
      Point(1.0, 1.0),
      0.0,
      False,
      True,
      Point(44.6542, -2.0),
    )
  let assert Ok([hit]) = intersections.segment(a, b)
  assert hit.left_t == 1.0
  assert hit.right_t == 0.0
  let assert Ok([hit]) =
    intersections.segment(
      svg_path.segment_reverse(b),
      svg_path.segment_reverse(a),
    )
  assert hit.left_t == 1.0
  assert hit.right_t == 0.0
}

pub fn shared_circle_endpoint_retains_second_interior_intersection_test() {
  let assert Ok(y) = float.square_root(0.75)
  let p = Point(0.5, y)
  let a = Arc(p, Point(1.0, 1.0), 0.0, True, False, Point(-1.0, 0.0))
  let b = Arc(p, Point(1.0, 1.0), 0.0, True, True, Point(2.0, 0.0))
  let assert Ok([first, second]) = intersections.segment(a, b)
  assert first.left_t == 0.0
  assert first.right_t == 0.0
  assert float.absolute_value(second.left_t -. 0.5) <. 0.00000001
  assert float.absolute_value(second.right_t -. 0.5) <. 0.00000001
  assert float.absolute_value(second.point.y +. y) <. 0.00000001
}

pub fn shared_circle_overlap_still_reports_overlap_test() {
  let a =
    Arc(Point(1.0, 0.0), Point(1.0, 1.0), 0.0, False, True, Point(0.0, 1.0))
  assert intersections.segment(a, a) == Error(svg_path.OverlappingSegments)
}

pub fn cavalier_near_tangent_offset_completes_in_both_directions_test() {
  // Cavalier Contours test_past_failures::near_tangent_line_arc_joins,
  // captured cases CC01267 / CC01271; native offset sign is reversed.
  let bulge = 0.198723
  let dx = 44.6542 -. 42.1788
  let dy = -3.0 -. -1.97424
  let assert Ok(chord) = float.square_root(dx *. dx +. dy *. dy)
  let radius = chord *. { 1.0 +. bulge *. bulge } /. { 4.0 *. bulge }
  let assert Ok(source) =
    svg_path.subpath([
      svg_path.Line(Point(28.4408, 11.7648), Point(42.1788, -1.97424)),
      Arc(
        Point(42.1788, -1.97424),
        Point(radius, radius),
        0.0,
        False,
        True,
        Point(44.6542, -3.0),
      ),
      svg_path.Line(Point(44.6542, -3.0), Point(49.6542, -3.0)),
    ])
  list.each(
    [#(source, -1.0), #(svg_path.subpath_reverse(source), 1.0)],
    fn(case_) {
      let assert Ok(path) =
        offset.subpath(case_.0, case_.1, offset.Round, offset.Butt)
      let assert [s] = path.subpaths
      assert !svg_path.subpath_is_closed(s)
      let assert Ok(_) = svg_path.subpath(svg_path.subpath_segments(s))
    },
  )
}

pub fn two_shared_circle_endpoints_are_the_complete_intersection_set_test() {
  let a =
    Arc(Point(-1.0, 0.0), Point(1.0, 1.0), 0.0, False, True, Point(1.0, 0.0))
  let b =
    Arc(Point(-1.0, 0.0), Point(2.0, 2.0), 0.0, False, True, Point(1.0, 0.0))
  let assert Ok([first, second]) = intersections.segment(a, b)
  assert #(first.left_t, first.right_t) == #(0.0, 0.0)
  assert #(second.left_t, second.right_t) == #(1.0, 1.0)
}
