import gleam/list
import svg_path.{
  Arc, CubicBezier, Line, Point, QuadraticBezier, SegmentIntersection,
}
import svg_path/encounters
import svg_path/intersections
import svg_path/overlaps

fn constants(p) {
  [Line(p, p), QuadraticBezier(p, p, p), CubicBezier(p, p, p, p)]
}

pub fn constant_pairs_have_one_canonical_contact_test() {
  let p = Point(1.0, 1.0)
  list.each(constants(p), fn(a) {
    list.each(constants(p), fn(b) {
      let expected = [SegmentIntersection(left_t: 0.0, right_t: 0.0, point: p)]
      assert intersections.segment(a, b) == Ok(expected)
      assert overlaps.segment(a, b) == Ok([])
      let assert Ok(found) = encounters.segment(a, b)
      assert found.overlaps == []
      assert found.intersections == expected
    })
    list.each(constants(Point(2.0, 1.0)), fn(b) {
      assert intersections.segment(a, b) == Ok([])
      assert intersections.segment(b, a) == Ok([])
    })
  })
}

pub fn constant_arc_queries_are_symmetric_test() {
  let arc =
    Arc(Point(2.0, 1.0), Point(1.0, 1.0), 0.0, False, True, Point(0.0, 1.0))
  list.each([#(Point(2.0, 1.0), 0.0), #(Point(1.0, 2.0), 0.5)], fn(contact) {
    list.each(constants(contact.0), fn(a) {
      assert intersections.segment(a, arc)
        == Ok([SegmentIntersection(0.0, contact.1, contact.0)])
      assert intersections.segment(arc, a)
        == Ok([SegmentIntersection(contact.1, 0.0, contact.0)])
      let assert Ok(found) = encounters.segment(a, arc)
      assert found.overlaps == []
      assert found.intersections
        == [SegmentIntersection(0.0, contact.1, contact.0)]
    })
  })
  list.each([Point(1.0, 1.0), Point(3.0, 3.0)], fn(p) {
    list.each(constants(p), fn(a) {
      assert intersections.segment(a, arc) == Ok([])
      assert intersections.segment(arc, a) == Ok([])
    })
  })
}

pub fn constant_line_queries_are_symmetric_test() {
  let p = Point(1.0, 1.0)
  let line = Line(Point(0.0, 1.0), Point(2.0, 1.0))
  list.each(constants(p), fn(a) {
    assert intersections.segment(a, line)
      == Ok([SegmentIntersection(0.0, 0.5, p)])
    assert intersections.segment(line, a)
      == Ok([SegmentIntersection(0.5, 0.0, p)])
  })
}

pub fn constant_contacts_preserve_other_curve_addresses_test() {
  let origin = Point(0.0, 0.0)
  let loop = CubicBezier(origin, Point(2.0, 2.0), Point(-2.0, 2.0), origin)
  let assert Ok(found) = intersections.segment(Line(origin, origin), loop)
  assert list.any(found, fn(hit) { hit.left_t == 0.0 && hit.right_t == 0.0 })
  assert list.any(found, fn(hit) { hit.left_t == 0.0 && hit.right_t == 1.0 })
  let folded = QuadraticBezier(origin, Point(4.0, 0.0), origin)
  let p = Point(1.0, 0.0)
  let assert Ok([a, b]) = intersections.segment(Line(p, p), folded)
  assert a.left_t == 0.0 && b.left_t == 0.0
  assert a.right_t <. 0.5 && b.right_t >. 0.5
  let endpoint = Point(0.0000000001, 0.0)
  let short = Line(origin, endpoint)
  let assert Ok(hits) = intersections.segment(Line(endpoint, endpoint), short)
  assert list.any(hits, fn(hit) { hit.right_t == 1.0 })
}

pub fn constant_contacts_validate_options_and_arc_geometry_test() {
  let p = Point(0.0, 0.0)
  let a = Line(p, p)
  let invalid =
    intersections.IntersectionOptions(
      ..intersections.default_options(),
      tolerance: -1.0,
    )
  assert intersections.segment_with(a, a, options: invalid)
    == Error(svg_path.InvalidIntersectionTolerance(-1.0))
  assert encounters.segment_with(a, a, options: invalid)
    == Error(svg_path.InvalidIntersectionTolerance(-1.0))
  assert overlaps.segment_with(a, a, tolerance: -1.0)
    == Error(svg_path.InvalidOverlapTolerance(-1.0))
  let arc = Arc(p, Point(0.0, 1.0), 0.0, False, True, Point(1.0, 0.0))
  assert intersections.segment(a, arc) == Error(svg_path.DegenerateArc)
  assert overlaps.segment(a, arc) == Error(svg_path.DegenerateArc)
  let options =
    intersections.IntersectionOptions(
      ..intersections.default_options(),
      tolerance: 0.125,
    )
  assert intersections.segment_with(
      a,
      Line(Point(0.125, 0.0), Point(0.125, 0.0)),
      options:,
    )
    == Ok([SegmentIntersection(0.0, 0.0, p)])
  assert intersections.segment_with(
      a,
      Line(Point(0.25, 0.0), Point(0.25, 0.0)),
      options:,
    )
    == Ok([])
}
