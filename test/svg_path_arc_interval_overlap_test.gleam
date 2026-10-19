import gleam/list
import gleam/option.{Some}
import svg_path.{Arc, Point}
import svg_path/internal/overlap_detection

fn short_arc() {
  Arc(
    Point(44.65470741897046, -2.0000001287369904),
    Point(1.0, 1.0),
    0.0,
    False,
    True,
    Point(44.65470741271587, -2.0000001287338165),
  )
}

pub fn overlap_can_validate_arc_interval_without_representable_slice_test() {
  let arc = short_arc()
  list.each([#(0.9999995858161379, 1.0), #(1.0, 0.9999995858161379)], fn(range) {
    let assert Ok(Some(_)) =
      overlap_detection.check_parameter_correspondence(
        arc,
        arc,
        range.0,
        range.1,
        range.0,
        range.1,
        0.000001,
        5,
      )
  })
}

pub fn overlap_witnesses_do_not_validate_invalid_source_arc_test() {
  let p = Point(10.0, 10.0)
  let arc = Arc(p, Point(1.0, 1.0), 0.0, False, True, p)
  assert overlap_detection.check_parameter_correspondence(
      arc,
      arc,
      0.5,
      1.0,
      0.5,
      1.0,
      0.000001,
      5,
    )
    == Error(svg_path.DegenerateArc)
}

pub fn overlap_witness_failure_remains_inconclusive_test() {
  let arc = short_arc()
  let assert Ok(p) = svg_path.segment_point(arc, 1.0)
  let excursion = svg_path.QuadraticBezier(p, Point(p.x +. 1.0, p.y), p)
  assert overlap_detection.check_parameter_correspondence(
      excursion,
      arc,
      0.0,
      1.0,
      0.9999995858161379,
      1.0,
      0.000001,
      5,
    )
    == Error(svg_path.DegenerateArc)
}
