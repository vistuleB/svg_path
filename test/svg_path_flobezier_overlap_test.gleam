import gleam/float
import gleam/list
import svg_path.{CubicBezier, Line, Point, QuadraticBezier}
import svg_path/encounters
import svg_path/intersections
import svg_path/overlaps

// FloBezier audit FB001 / FI003: scalar turning points can bound an overlap
// even though no original segment endpoint bounds it.
pub fn folded_collinear_overlap_rejects_non_affine_maps_test() {
  let fixtures = [
    #(
      Line(Point(1.0, 1.0), Point(2.0, 2.0)),
      QuadraticBezier(Point(0.0, 0.0), Point(3.0, 3.0), Point(0.5, 0.5)),
    ),
    #(
      QuadraticBezier(Point(0.0, 0.0), Point(1.0, 1.0), Point(0.25, 0.25)),
      CubicBezier(
        Point(2.0, 2.0),
        Point(0.5, 0.5),
        Point(0.25, 0.25),
        Point(-1.0, -1.0),
      ),
    ),
    #(
      QuadraticBezier(Point(0.1, 0.1), Point(0.8, 0.8), Point(0.2, 0.2)),
      QuadraticBezier(Point(1.0, 1.0), Point(0.5, 0.5), Point(0.3, 0.3)),
    ),
  ]
  list.each(fixtures, fn(pair) {
    assert_rejected(pair.0, pair.1)
    assert_rejected(pair.1, pair.0)
  })
}

fn assert_rejected(a, b) {
  assert overlaps.segment(a, b)
    == Error(svg_path.NonAffineOverlapCorrespondence)
  assert intersections.segment(a, b)
    == Error(svg_path.NonAffineOverlapCorrespondence)
  assert encounters.segment(a, b)
    == Error(svg_path.NonAffineOverlapCorrespondence)
}

pub fn folded_line_overlap_contact_and_separation_test() {
  list.each([0.01, 1.0, 1000.0], fn(scale) {
    list.each([False, True], fn(vertical) {
      let p = fn(x) {
        case vertical {
          True -> Point(17.0, -23.0 +. scale *. x)
          False -> Point(17.0 +. scale *. x, -23.0)
        }
      }
      list.each(
        [
          QuadraticBezier(p(0.0), p(4.0), p(0.0)),
          CubicBezier(p(0.0), p(8.0 /. 3.0), p(8.0 /. 3.0), p(0.0)),
        ],
        fn(curve) {
          let overlapping = Line(p(1.0), p(3.0))
          assert_rejected(overlapping, curve)
          assert_rejected(curve, overlapping)
          let touching = Line(p(2.0), p(3.0))
          assert overlaps.segment(touching, curve) == Ok([])
          let assert Ok([hit]) = intersections.segment(touching, curve)
          assert float.absolute_value(hit.left_t) <. 0.00000001
          assert float.absolute_value(hit.right_t -. 0.5) <. 0.00000001
          let assert Ok([reversed]) = intersections.segment(curve, touching)
          assert float.absolute_value(reversed.left_t -. 0.5) <. 0.00000001
          assert float.absolute_value(reversed.right_t) <. 0.00000001
          let separate = Line(p(3.0), p(4.0))
          assert overlaps.segment(separate, curve) == Ok([])
          assert intersections.segment(separate, curve) == Ok([])
          assert intersections.segment(curve, separate) == Ok([])
        },
      )
    })
  })
}

pub fn conflicting_retraced_overlap_is_not_empty_success_test() {
  let curve = QuadraticBezier(Point(0.0, 0.0), Point(4.0, 0.0), Point(0.0, 0.0))
  assert_rejected(curve, curve)
  assert_rejected(curve, svg_path.segment_reverse(curve))
}

pub fn affine_collinear_overlap_remains_supported_test() {
  let line = Line(Point(0.0, 0.0), Point(2.0, 0.0))
  let curve = QuadraticBezier(Point(0.0, 0.0), Point(1.0, 0.0), Point(2.0, 0.0))
  list.each([curve, svg_path.segment_reverse(curve)], fn(other) {
    let assert Ok([_]) = overlaps.segment(line, other)
    let assert Ok([_]) = overlaps.segment(other, line)
    assert intersections.segment(line, other)
      == Error(svg_path.OverlappingSegments)
  })
}
