import gleam/list
import svg_path.{Line, Point}
import svg_path/intersections
import svg_path/overlaps

fn rounded_lines() {
  #(
    Line(
      Point(1_336_017_144.7222269, 514_632.0777871349),
      Point(1_336_017_149.883367, 514_641.78073088516),
    ),
    Line(
      Point(1_336_017_144.722227, 514_632.077786993),
      Point(1_336_017_149.8833673, 514_641.780730718),
    ),
  )
}

// FL002: endpoint differences are below 3e-7, but separately rounded interior
// samples can differ by more than 5e-7. The affine endpoint bound certifies
// the two lines without relying on those samples.
pub fn large_coordinate_line_overlap_uses_endpoint_bound_test() {
  let #(left, right) = rounded_lines()
  let options =
    intersections.IntersectionOptions(
      ..intersections.default_options(),
      tolerance: 0.0000005,
    )
  list.each([left, svg_path.segment_reverse(left)], fn(a) {
    list.each([right, svg_path.segment_reverse(right)], fn(b) {
      list.each([#(a, b), #(b, a)], fn(pair) {
        let assert Ok([overlap]) =
          overlaps.segment_with(pair.0, pair.1, 0.0000005)
        assert overlap.left_from == 0.0
        assert overlap.left_to == 1.0
        assert #(overlap.right_from, overlap.right_to) == #(0.0, 1.0)
          || #(overlap.right_from, overlap.right_to) == #(1.0, 0.0)
        assert intersections.segment_with(pair.0, pair.1, options)
          == Error(svg_path.OverlappingSegments)
      })
    })
  })
}

pub fn large_coordinate_line_overlap_respects_tighter_tolerance_test() {
  let #(left, right) = rounded_lines()
  assert overlaps.segment_with(left, right, 0.0000001) == Ok([])
  assert overlaps.segment_with(right, left, 0.0000001) == Ok([])
}

pub fn crossing_lines_are_not_continuous_overlap_test() {
  let left = Line(Point(0.0, 0.0), Point(10.0, 0.0))
  let right = Line(Point(0.0, -1.0), Point(10.0, 1.0))
  assert overlaps.segment_with(left, right, 0.0000005) == Ok([])
  let assert Ok([hit]) = intersections.segment(left, right)
  assert hit.left_t == 0.5
  assert hit.right_t == 0.5
}
