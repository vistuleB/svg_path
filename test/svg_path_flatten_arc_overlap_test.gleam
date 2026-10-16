// Flatten.js Boolean issue #3, call 4295. See scripts/flatten/provenance.json.
import gleam/float
import gleam/list
import svg_path as g
import svg_path/area
import svg_path/csg
import svg_path/intersections as ix
import svg_path/overlaps

fn short_pair() {
  #(
    g.Arc(
      g.Point(59.76247350201103, 59.7377048577821),
      g.Point(84.49938828627135, 84.49938828627135),
      0.0,
      False,
      True,
      g.Point(59.70692262458793, 59.79322713698864),
    ),
    g.Arc(
      g.Point(59.76247342962466, 59.73770478542024),
      g.Point(85.20624291591454, 85.20624291591454),
      0.0,
      False,
      False,
      g.Point(59.70695115012889, 59.79325542571751),
    ),
  )
}

pub fn fl006_endpoint_arc_overlap_does_not_hide_crossing_test() {
  let #(left, right) = short_pair()
  list.each([left, g.segment_reverse(left)], fn(a) {
    list.each([right, g.segment_reverse(right)], fn(b) {
      list.each([#(a, b), #(b, a)], fn(pair) {
        assert overlaps.segment_with(pair.0, pair.1, 0.0000005) == Ok([])
        let assert Ok([hit]) =
          ix.segment_with(
            pair.0,
            pair.1,
            ix.IntersectionOptions(..ix.default_options(), tolerance: 0.0000005),
          )
        assert float.absolute_value(hit.point.x -. 59.73753072787354)
          <. 0.000000001
        assert float.absolute_value(hit.point.y -. 59.76264755924401)
          <. 0.000000001
      })
    })
  })
}

pub fn fl006_arc_direction_guard_preserves_partial_reversed_overlap_test() {
  let #(left, _) = short_pair()
  let assert Ok(part) = g.segment_between(left, 0.2, 0.8)
  list.each([part, g.segment_reverse(part)], fn(right) {
    list.each([#(left, right), #(right, left)], fn(pair) {
      let assert Ok([overlap]) =
        overlaps.segment_with(pair.0, pair.1, 0.0000005)
      list.each([0.0, 0.25, 0.5, 0.75, 1.0], fn(t) {
        let u =
          overlap.left_from +. t *. { overlap.left_to -. overlap.left_from }
        let v = overlaps.segment_overlap_right_parameter(overlap, u)
        let assert Ok(p) = g.segment_point(pair.0, u)
        let assert Ok(q) = g.segment_point(pair.1, v)
        assert float.absolute_value(p.x -. q.x) <. 0.0000005
        assert float.absolute_value(p.y -. q.y) <. 0.0000005
      })
      assert ix.segment_with(
          pair.0,
          pair.1,
          ix.IntersectionOptions(..ix.default_options(), tolerance: 0.0000005),
        )
        == Error(g.OverlappingSegments)
    })
  })
}

pub fn fl006_boolean_keeps_interior_arc_crossing_test() {
  let assert Ok(path) =
    csg.intersection_path(left_4295(), right_4295(), g.EvenOdd)
  assert float.absolute_value(area.signed_path(path) -. 0.006167841542276564)
    <. 0.00000001
  assert list.any(path.subpaths, fn(s) {
    list.any(g.subpath_segments(s), fn(segment) {
      let p = g.segment_start(segment)
      float.absolute_value(p.x -. 59.73753072787354) <. 0.0000001
      && float.absolute_value(p.y -. 59.76264755924401) <. 0.0000001
    })
  })
}

fn left_4295() {
  g.Path([
    g.subpath_assert([
      g.Arc(
        g.Point(59.70692262458793, 59.79322713698864),
        g.Point(84.79252389141845, 84.79252389141845),
        0.0,
        False,
        True,
        g.Point(59.762664600825765, 59.84855755939034),
      ),
      g.Arc(
        g.Point(59.762664600825765, 59.84855755939034),
        g.Point(84.5779281026111, 84.5779281026111),
        0.0,
        False,
        False,
        g.Point(59.81821506960193, 59.79303528018376),
      ),
      g.Arc(
        g.Point(59.81821506960193, 59.79303528018376),
        g.Point(84.8710637077582, 84.8710637077582),
        0.0,
        False,
        False,
        g.Point(59.76247350201103, 59.7377048577821),
      ),
      g.Arc(
        g.Point(59.76247350201103, 59.7377048577821),
        g.Point(84.49938828627135, 84.49938828627135),
        0.0,
        False,
        True,
        g.Point(59.70692262458793, 59.79322713698864),
      ),
    ]),
  ])
}

fn right_4295() {
  g.Path([
    g.subpath_assert([
      g.Arc(
        g.Point(205.20624291591454, 120.0),
        g.Point(85.20624291591454, 85.20624291591454),
        0.0,
        False,
        False,
        g.Point(120.0, 34.793757084085456),
      ),
      g.Arc(
        g.Point(120.0, 34.793757084085456),
        g.Point(85.20624291591454, 85.20624291591454),
        0.0,
        False,
        False,
        g.Point(34.793757084085456, 119.99999999999999),
      ),
      g.Arc(
        g.Point(34.793757084085456, 119.99999999999999),
        g.Point(85.20624291591454, 85.20624291591454),
        0.0,
        False,
        False,
        g.Point(119.99999999999999, 205.20624291591454),
      ),
      g.Arc(
        g.Point(119.99999999999999, 205.20624291591454),
        g.Point(85.20624291591454, 85.20624291591454),
        0.0,
        False,
        False,
        g.Point(205.20624291591454, 120.0),
      ),
    ]),
  ])
}
