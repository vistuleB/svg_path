import gleam/float
import gleam/list
import gleeunit/should
import svg_path
import svg_path/containment

fn options() {
  svg_path.CrossingOptions(
    samples: 100,
    signed_line_distance_tolerance: 0.000000000001,
    max_iterations: 100,
  )
}

fn crossings(segment: svg_path.Segment, y: Float) {
  containment.segment_ray_crossings_with(
    segment,
    origin: svg_path.Point(0.0, y),
    direction: svg_path.Point(1.0, 0.0),
    options: options(),
  )
}

fn curves() {
  let start = svg_path.Point(150.0, 160.0)
  let end = svg_path.Point(150.0, 80.0)
  [
    svg_path.CubicBezier(start, start, end, end),
    svg_path.CubicBezier(end, end, start, start),
    svg_path.QuadraticBezier(start, end, end),
    svg_path.QuadraticBezier(end, end, start),
    // Monotone projection, but not a geometrically straight curve.
    svg_path.CubicBezier(
      start,
      svg_path.Point(170.0, 160.0),
      svg_path.Point(170.0, 80.0),
      end,
    ),
  ]
}

pub fn near_endpoint_inside_recovers_geometrically_valid_root_test() {
  list.each(curves(), fn(segment) {
    let y = 80.00000000006969
    let assert Ok([#(t, _)]) = crossings(segment, y)
    assert t >. 0.0 && t <. 1.0
    let assert Ok(point) = svg_path.segment_point(segment, at: t)
    assert float.absolute_value(point.y -. y) <=. 0.000000000001
  })
}

pub fn near_endpoint_outside_discards_spurious_root_test() {
  list.each(curves(), fn(segment) {
    crossings(segment, 79.99999999993031) |> should.equal(Ok([]))
  })
}

pub fn exact_endpoint_contact_is_preserved_test() {
  list.each(curves(), fn(segment) {
    let assert Ok([#(t, _)]) = crossings(segment, 80.0)
    let assert Ok(point) = svg_path.segment_point(segment, at: t)
    assert float.absolute_value(point.y -. 80.0) <=. 0.000000000001
    assert t <. 0.000001 || t >. 0.999999
  })
}

pub fn interior_tangent_contact_is_preserved_test() {
  let curve =
    svg_path.QuadraticBezier(
      svg_path.Point(0.0, 1.0),
      svg_path.Point(1.0, -1.0),
      svg_path.Point(2.0, 1.0),
    )
  let assert Ok([#(t, _)]) = crossings(curve, 0.0)
  assert float.absolute_value(t -. 0.5) <. 0.000000001
}

pub fn nonmonotone_projection_preserves_two_crossings_test() {
  let curve =
    svg_path.QuadraticBezier(
      svg_path.Point(0.0, 1.0),
      svg_path.Point(1.0, -1.0),
      svg_path.Point(2.0, 1.0),
    )
  let assert Ok([#(a, _), #(b, _)]) = crossings(curve, 0.25)
  assert float.absolute_value(a -. 0.25) <. 0.000000001
  assert float.absolute_value(b -. 0.75) <. 0.000000001
}

pub fn endpoint_recovery_respects_iteration_limit_test() {
  let assert [curve, ..] = curves()
  let assert Error(svg_path.CrossingMaxIterationsReached(..)) =
    containment.segment_ray_crossings_with(
      curve,
      origin: svg_path.Point(0.0, 80.00000000006969),
      direction: svg_path.Point(1.0, 0.0),
      options: svg_path.CrossingOptions(..options(), max_iterations: 1),
    )
}
