import gleam/float
import gleam/list
import gleeunit/should
import svg_path
import svg_path/containment
import svg_path/internal/root

pub fn signed_zero_root_candidates_are_merged_test() {
  // t²(t + 1): an endpoint and a derivative root describe the same contact.
  let assert Ok([candidate]) =
    root.real_cubic_01_roots(
      1.0,
      1.0,
      0.0,
      0.0,
      options: root.default_polynomial_options(),
    )
  assert candidate.isolation.estimate == 0.0
  assert candidate.kind == root.PositiveToPositive
}

pub fn signed_zero_candidates_do_not_duplicate_a_recovered_crossing_test() {
  let curve =
    svg_path.CubicBezier(
      svg_path.Point(0.0, 0.0),
      svg_path.Point(1.0 /. 3.0, 0.0),
      svg_path.Point(2.0 /. 3.0, 1.9),
      svg_path.Point(1.0, 8.0),
    )
  let assert Ok([#(t, _)]) =
    containment.segment_ray_crossings_with(
      curve,
      origin: svg_path.Point(0.0, 5.0e-12),
      direction: svg_path.Point(-1.0, 0.0),
      options: options(),
    )
  let assert Ok(point) = svg_path.segment_point(curve, at: t)
  assert float.absolute_value(point.y -. 5.0e-12) <=. 1.0e-12
}

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

// Projected cubic witnesses reduced from Paper.js Boolean fixtures 103, 107,
// 128/129, 130/131, 168/169. Upstream MIT: scripts/paperjs/upstream/LICENSE.txt.
pub fn paper_near_endpoint_root_witnesses_test() {
  list.each(
    [
      #(
        svg_path.CubicBezier(
          svg_path.Point(312.1968, 265.6776),
          svg_path.Point(309.55039999999997, 271.324),
          svg_path.Point(299.9904, 273.3128),
          svg_path.Point(294.4, 273.3128),
        ),
        svg_path.Point(0.0, 273.3127999999945),
        svg_path.Point(1.0, 0.0),
        [0.9999990436442556],
      ),
      #(
        svg_path.CubicBezier(
          svg_path.Point(512.0, 640.0),
          svg_path.Point(512.0, 640.0),
          svg_path.Point(388.0405751528448, 332.07994673131026),
          svg_path.Point(288.04, 332.0799999999999),
        ),
        svg_path.Point(0.0, 332.0799999999999),
        svg_path.Point(1.0, 0.0),
        [0.9999998270048149, 1.0],
      ),
      #(
        svg_path.CubicBezier(
          svg_path.Point(487.8821067425946, 340.2688405948006),
          svg_path.Point(487.8821067425946, 340.2688405948006),
          svg_path.Point(529.4025393039343, 348.4286400051758),
          svg_path.Point(529.4025393039343, 348.4286400051758),
        ),
        svg_path.Point(529.402539303881, 0.0),
        svg_path.Point(0.0, 1.0),
        [0.9999993457404852],
      ),
      #(
        svg_path.CubicBezier(
          svg_path.Point(100.10301277238074, 299.8360064274938),
          svg_path.Point(100.10301277238074, 299.8360064274938),
          svg_path.Point(192.98476439737567, 381.03840618337944),
          svg_path.Point(192.98476439737567, 381.03840618337944),
        ),
        svg_path.Point(0.0, 381.03840618333726),
        svg_path.Point(1.0, 0.0),
        [0.9999995839006389],
      ),
      #(
        svg_path.CubicBezier(
          svg_path.Point(479.86630925710153, 107.76493242524054),
          svg_path.Point(465.2684050136691, 111.21284998937328),
          svg_path.Point(450.6709242911992, 114.66066752097116),
          svg_path.Point(450.6709242911992, 114.66066752097116),
        ),
        svg_path.Point(450.67092429122897, 0.0),
        svg_path.Point(0.0, 1.0),
        [0.9999991752805898],
      ),
    ],
    fn(witness) {
      let #(segment, origin, direction, expected) = witness
      let assert Ok(actual) =
        containment.segment_ray_crossings_with(
          segment,
          origin:,
          direction:,
          options: options(),
        )
      assert list.length(actual) == list.length(expected)
      list.map2(actual, expected, fn(found, wanted) {
        let #(t, _) = found
        assert float.absolute_value(t -. wanted) <. 1.0e-12
        let assert Ok(p) = svg_path.segment_point(segment, at: t)
        let residual =
          { p.x -. origin.x }
          *. direction.y
          -. { p.y -. origin.y }
          *. direction.x
        assert float.absolute_value(residual) <=. 1.0e-12
      })
    },
  )
}

pub fn bernstein_isolation_preserves_three_crossings_and_true_tangent_test() {
  let assert Ok([a, b, c]) =
    root.bernstein_roots_with(
      [-0.08, 0.14, -0.14, 0.08],
      options: root.default_polynomial_options(),
    )
  assert float.absolute_value(a -. 0.2) <. 1.0e-12
  assert float.absolute_value(b -. 0.5) <. 1.0e-12
  assert float.absolute_value(c -. 0.8) <. 1.0e-12
  assert root.bernstein_roots_with(
      [1.0, -1.0, 1.0],
      options: root.default_polynomial_options(),
    )
    == Ok([0.5])
}

pub fn two_close_roots_survive_both_orientations_and_scaling_test() {
  list.each([0.001, 1.0, 1000.0], fn(scale) {
    let controls = [
      svg_path.Point(0.0, -1000.0 *. scale),
      svg_path.Point(1.0 /. 3.0, -1000.0 *. scale),
      svg_path.Point(2.0 /. 3.0, 0.0001 *. scale),
      svg_path.Point(1.0, 0.0),
    ]
    list.each([controls, list.reverse(controls)], fn(points) {
      let assert [a, b, c, d] = points
      let segment = svg_path.CubicBezier(a, b, c, d)
      let assert Ok([#(first, _), #(second, _)]) =
        containment.segment_ray_crossings_with(
          segment,
          origin: svg_path.Point(0.0, 0.0),
          direction: svg_path.Point(1.0, 0.0),
          options: svg_path.CrossingOptions(
            ..options(),
            signed_line_distance_tolerance: scale *. 1.0e-12,
          ),
        )
      assert second -. first >. 9.0e-8
      assert second -. first <. 1.1e-7
      assert first == 0.0 || second == 1.0
    })
  })
}

pub fn monotone_near_endpoint_roots_survive_orientation_test() {
  let points = [
    svg_path.Point(0.0, 8.0),
    svg_path.Point(1.0 /. 3.0, 1.9),
    svg_path.Point(2.0 /. 3.0, 0.0),
    svg_path.Point(1.0, 0.0),
  ]
  list.each([points, list.reverse(points)], fn(points) {
    let assert [a, b, c, d] = points
    let segment = svg_path.CubicBezier(a, b, c, d)
    let assert Ok([#(t, _)]) = crossings(segment, 5.0e-12)
    let assert Ok(p) = svg_path.segment_point(segment, at: t)
    assert float.absolute_value(p.y -. 5.0e-12) <=. 1.0e-12
  })
}

pub fn separated_control_polygon_has_no_line_roots_test() {
  assert containment.segment_ray_crossings_with(
      svg_path.CubicBezier(
        svg_path.Point(518.8256109308445, 384.2317022309883),
        svg_path.Point(518.8256109308445, 384.2317022309883),
        svg_path.Point(487.8821067425946, 340.2688405948006),
        svg_path.Point(487.8821067425946, 340.2688405948006),
      ),
      origin: svg_path.Point(487.8821067425581, 340.26884059479363),
      direction: svg_path.Point(0.0, 1.0),
      options: options(),
    )
    == Ok([])
}
