import gleam/list
import svg_path.{Arc, Point}
import svg_path/intersections

pub fn short_exact_arc_overlap_survives_endpoint_rounding_test() {
  list.each([0.0000001, 0.00000001, 0.000000001], fn(chord) {
    list.each([True, False], fn(sweep) {
      let arc =
        Arc(
          Point(0.0, 0.0),
          Point(1.0, 1.0),
          0.0,
          False,
          sweep,
          Point(chord, 0.0),
        )
      assert intersections.segment(arc, arc)
        == Error(svg_path.OverlappingSegments)
      assert intersections.segment(arc, svg_path.segment_reverse(arc))
        == Error(svg_path.OverlappingSegments)
    })
  })
}

pub fn short_exact_elliptical_arc_overlap_test() {
  let arc =
    Arc(
      Point(0.0, 0.0),
      Point(2.0, 1.0),
      30.0,
      False,
      True,
      Point(0.00000001, 0.0),
    )
  assert intersections.segment(arc, arc) == Error(svg_path.OverlappingSegments)
  assert intersections.segment(arc, svg_path.segment_reverse(arc))
    == Error(svg_path.OverlappingSegments)
}

pub fn exact_arc_overlap_still_validates_degenerate_source_test() {
  let p = Point(1.0, 1.0)
  let arc = Arc(p, Point(1.0, 1.0), 0.0, False, True, p)
  assert intersections.segment(arc, arc) == Error(svg_path.DegenerateArc)
  assert intersections.segment(arc, svg_path.segment_reverse(arc))
    == Error(svg_path.DegenerateArc)
}

pub fn shared_endpoints_do_not_certify_distinct_arc_overlap_test() {
  let upper =
    Arc(Point(-1.0, 0.0), Point(1.0, 1.0), 0.0, False, True, Point(1.0, 0.0))
  let lower =
    Arc(Point(-1.0, 0.0), Point(1.0, 1.0), 0.0, False, False, Point(1.0, 0.0))
  let assert Ok([a, b]) = intersections.segment(upper, lower)
  assert #(a.left_t, a.right_t) == #(0.0, 0.0)
  assert #(b.left_t, b.right_t) == #(1.0, 1.0)
}
