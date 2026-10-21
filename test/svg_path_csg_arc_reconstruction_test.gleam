import gleam/list
import gleeunit/should
import svg_path
import svg_path/internal/arc_reconstruction
import svg_path/point
import svg_path/trig

fn circle() {
  svg_path.Arc(
    svg_path.Point(100.0, 0.0),
    svg_path.Point(100.0, 100.0),
    0.0,
    False,
    True,
    svg_path.Point(-100.0, 0.0),
  )
}

pub fn unchanged_arc_is_identical_test() {
  let arc = circle()
  arc_reconstruction.adjust(
    arc,
    svg_path.segment_start(arc),
    svg_path.segment_end(arc),
  )
  |> should.equal(Ok(arc))
}

pub fn semicircle_midpoint_and_endpoints_test() {
  let arc = circle()
  let a = svg_path.Point(100.0000001, -0.0000001)
  let b = svg_path.Point(-100.0000001, 0.0000001)
  let assert Ok(out) = arc_reconstruction.adjust(arc, a, b)
  svg_path.segment_start(out) |> should.equal(a)
  svg_path.segment_end(out) |> should.equal(b)
  let assert Ok(before) = svg_path.segment_point(arc, 0.5)
  let assert Ok(after) = svg_path.segment_point(out, 0.5)
  assert point.distance(before, after) <. 0.00001
}

pub fn shallow_arc_uses_bounded_similarity_test() {
  let arc =
    svg_path.Arc(
      svg_path.Point(-1.0, 0.0),
      svg_path.Point(100_000_000.0, 100_000_000.0),
      0.0,
      False,
      True,
      svg_path.Point(1.0, 0.0),
    )
  let a = svg_path.Point(-1.0, 0.000001)
  let b = svg_path.Point(1.0, 0.000001)
  let assert Ok([out]) =
    arc_reconstruction.adjust_with_tolerance(arc, a, b, 0.000001)
  svg_path.segment_start(out) |> should.equal(a)
  svg_path.segment_end(out) |> should.equal(b)
  list.each([0.0, 0.25, 0.5, 0.75, 1.0], fn(t) {
    let assert Ok(before) = svg_path.segment_point(arc, t)
    let assert Ok(after) = svg_path.segment_point(out, t)
    assert point.distance(before, after) <=. 0.000001
  })
}

pub fn collapsed_target_fails_test() {
  arc_reconstruction.adjust(
    circle(),
    svg_path.Point(0.0, 0.0),
    svg_path.Point(0.0, 0.0),
  )
  |> should.equal(Error(Nil))
}

pub fn reverse_traversal_equivalence_test() {
  let arc = circle()
  let a = svg_path.Point(100.0000001, 0.0)
  let b = svg_path.Point(-100.0, 0.0000001)
  let assert Ok(forward) = arc_reconstruction.adjust(arc, a, b)
  let assert Ok(backward) =
    arc_reconstruction.adjust(svg_path.segment_reverse(arc), b, a)
  list.each([0.0, 0.25, 0.5, 0.75, 1.0], fn(t) {
    let assert Ok(p) = svg_path.segment_point(forward, t)
    let assert Ok(q) = svg_path.segment_point(backward, 1.0 -. t)
    assert point.distance(p, q) <. 0.00001
  })
}

pub fn rotated_eccentric_major_arc_midpoint_test() {
  let rotation = 37.0
  let c = trig.cos_degrees(rotation)
  let s = trig.sin_degrees(rotation)
  let arc =
    svg_path.Arc(
      svg_path.Point(100.0 *. c, 100.0 *. s),
      svg_path.Point(100.0, 1.0),
      rotation,
      True,
      True,
      svg_path.Point(s, 0.0 -. c),
    )
  let a = point.add(svg_path.segment_start(arc), svg_path.Point(0.0000001, 0.0))
  let b = point.add(svg_path.segment_end(arc), svg_path.Point(0.0, 0.0000001))
  let assert Ok(out) = arc_reconstruction.adjust(arc, a, b)
  let assert Ok(before) = svg_path.segment_point(arc, 0.5)
  let assert Ok(after) = svg_path.segment_point(out, 0.5)
  assert point.distance(before, after) <. 0.000001
  svg_path.segment_start(out) |> should.equal(a)
  svg_path.segment_end(out) |> should.equal(b)
}

pub fn bounded_near_full_ellipse_test() {
  let angle = 359.99999
  let arc =
    svg_path.Arc(
      svg_path.Point(100.0, 0.0),
      svg_path.Point(100.0, 1.0),
      0.0,
      True,
      True,
      svg_path.Point(100.0 *. trig.cos_degrees(angle), trig.sin_degrees(angle)),
    )
  let a =
    point.add(
      svg_path.segment_start(arc),
      svg_path.Point(0.0000001, -0.0000001),
    )
  let b =
    point.add(svg_path.segment_end(arc), svg_path.Point(-0.0000001, 0.0000001))
  let assert Ok(pieces) =
    arc_reconstruction.adjust_with_tolerance(arc, a, b, 0.000001)
  assert list.length(pieces) > 1
  assert list.length(pieces) <= 8
  let assert Ok(first) = list.first(pieces)
  let assert Ok(last) = list.last(pieces)
  svg_path.segment_start(first) |> should.equal(a)
  svg_path.segment_end(last) |> should.equal(b)
  list.fold(pieces, a, fn(previous, segment) {
    svg_path.segment_start(segment) |> should.equal(previous)
    svg_path.segment_end(segment)
  })
  |> should.equal(b)
}

pub fn endpoint_movement_exceeding_budget_fails_test() {
  arc_reconstruction.adjust_with_tolerance(
    circle(),
    svg_path.Point(101.0, 0.0),
    svg_path.Point(-100.0, 0.0),
    0.000001,
  )
  |> should.equal(Error(Nil))
}

pub fn bounded_unchanged_arc_is_identical_test() {
  let arc = circle()
  arc_reconstruction.adjust_with_tolerance(
    arc,
    svg_path.segment_start(arc),
    svg_path.segment_end(arc),
    0.000001,
  )
  |> should.equal(Ok([arc]))
}

pub fn shallow_rotated_and_eccentric_arcs_retain_success_test() {
  list.each([#(100.0, 100.0), #(100.0, 1.0), #(1.0, 100.0)], fn(radii) {
    let #(rx, ry) = radii
    list.each([0.0, 37.0], fn(rotation) {
      let c = trig.cos_degrees(rotation)
      let s = trig.sin_degrees(rotation)
      let x = rx *. trig.cos_degrees(0.00001)
      let y = ry *. trig.sin_degrees(0.00001)
      let arc =
        svg_path.Arc(
          svg_path.Point(rx *. c, rx *. s),
          svg_path.Point(rx, ry),
          rotation,
          False,
          True,
          svg_path.Point(x *. c -. y *. s, x *. s +. y *. c),
        )
      list.each([0.0000001, -0.0000001], fn(d) {
        let a =
          point.add(svg_path.segment_start(arc), svg_path.Point(d, 0.0 -. d))
        let b =
          point.add(svg_path.segment_end(arc), svg_path.Point(0.0 -. d, d))
        let assert Ok([out]) =
          arc_reconstruction.adjust_with_tolerance(arc, a, b, 0.000001)
        svg_path.segment_start(out) |> should.equal(a)
        svg_path.segment_end(out) |> should.equal(b)
        list.each([0.0, 0.25, 0.5, 0.75, 1.0], fn(t) {
          let assert Ok(before) = svg_path.segment_point(arc, t)
          let assert Ok(after) = svg_path.segment_point(out, t)
          assert point.distance(before, after) <=. 0.000001
        })
      })
    })
  })
}
