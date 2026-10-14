// Native winding regressions originating in audit fixtures 79 and 113.
// Provenance: scripts/paperjs/files/Path_Boolean.js.md.
import gleam/float
import gleam/list
import gleeunit/should
import svg_path
import svg_path/area
import svg_path/csg

fn triangle(a, b, c) {
  svg_path.subpath_assert_polygon([a, b, c]) |> svg_path.subpath_as_path
}

fn check_area(result, expected) {
  let assert Ok(path) = result
  assert float.absolute_value(
      float.absolute_value(area.signed_path(path)) -. expected,
    )
    <. 1.0e-10
  list.each(svg_path.path_subpaths(path), fn(subpath) {
    svg_path.subpath_is_closed(subpath) |> should.be_true
    let edges = svg_path.subpath_segments(subpath)
    let assert [first, ..rest] = edges
    let assert Ok(last) = list.last(edges)
    svg_path.segment_end(last) |> should.equal(svg_path.segment_start(first))
    list.each(list.zip(edges, rest), fn(pair) {
      svg_path.segment_end(pair.0)
      |> should.equal(svg_path.segment_start(pair.1))
    })
  })
}

pub fn nested_close_boundaries_test() {
  let origin = svg_path.Point(0.0, 0.0)
  let top = svg_path.Point(0.0, 2.0)
  let inner = triangle(origin, svg_path.Point(1.0, 1.0), top)
  let outer = triangle(origin, svg_path.Point(1.00004, 1.0), top)
  list.each([svg_path.Nonzero, svg_path.EvenOdd], fn(rule) {
    list.each([outer, svg_path.path_reverse(outer)], fn(outer) {
      check_area(csg.union_path(inner, outer, using: rule), 1.00004)
      check_area(csg.intersection_path(inner, outer, using: rule), 1.0)
      check_area(csg.difference_path(outer, inner, using: rule), 0.00004)
      check_area(
        csg.symmetric_difference_path(inner, outer, using: rule),
        0.00004,
      )
    })
  })
}

pub fn thin_shared_edge_triangles_test() {
  let origin = svg_path.Point(0.0, 0.0)
  let short = svg_path.Point(0.0, -0.00004)
  let left = triangle(origin, short, svg_path.Point(-1.0, -1.0))
  let right = triangle(short, origin, svg_path.Point(1.0, -1.0))
  list.each([svg_path.Nonzero, svg_path.EvenOdd], fn(rule) {
    check_area(csg.union_path(left, right, using: rule), 0.00004)
    check_area(csg.intersection_path(left, right, using: rule), 0.0)
    check_area(csg.difference_path(left, right, using: rule), 0.00002)
    check_area(csg.symmetric_difference_path(left, right, using: rule), 0.00004)
  })
}

pub fn source_multiplicity_and_implicit_closure_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(2.0, 0.0)
  let c = svg_path.Point(0.0, 2.0)
  let open =
    svg_path.subpath_assert([svg_path.Line(a, b), svg_path.Line(b, c)])
    |> svg_path.subpath_as_path
  let doubled = svg_path.path_combine([open, open])
  let cancelled = svg_path.path_combine([open, svg_path.path_reverse(open)])
  let empty = svg_path.path_empty()
  check_area(csg.union_path(doubled, empty, using: svg_path.Nonzero), 2.0)
  check_area(csg.union_path(doubled, empty, using: svg_path.EvenOdd), 0.0)
  check_area(csg.union_path(cancelled, empty, using: svg_path.Nonzero), 0.0)
  check_area(csg.intersection_path(open, doubled, using: svg_path.Nonzero), 2.0)
  check_area(csg.union_path(empty, open, using: svg_path.Nonzero), 2.0)
}
