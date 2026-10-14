// Native reduced regression originating in Paper.js fixture 172 (#1506).
// Provenance: scripts/paperjs/files/Path_Boolean.js.md.
// MIT, copyright 2011–2020
// Jürg Lehni & Jonathan Puckey. See scripts/paperjs/upstream/LICENSE.txt.
import gleam/float
import gleam/list
import gleeunit/should
import svg_path
import svg_path/area
import svg_path/arrangement
import svg_path/containment
import svg_path/csg
import svg_path/parse

fn closed(path: svg_path.Path) {
  list.each(svg_path.path_subpaths(path), fn(subpath) {
    svg_path.subpath_is_closed(subpath) |> should.be_true
    let segments = svg_path.subpath_segments(subpath)
    let assert [first, ..rest] = segments
    let assert Ok(last) = list.last(segments)
    svg_path.segment_end(last) |> should.equal(svg_path.segment_start(first))
    list.each(list.zip(segments, rest), fn(pair) {
      svg_path.segment_end(pair.0)
      |> should.equal(svg_path.segment_start(pair.1))
    })
  })
}

pub fn difference_of_internally_tangent_cubic_loops_test() {
  // Four cubic segments, integer controls, and an exact shared vertical tangent.
  // The inner loop touches the outer at (0, 0); it must be removed without
  // confusing the two incoming/outgoing pairs at that vertex.
  let assert Ok(outer) = parse.path("M0 0 C0 -2 -4 -2 -4 0 C-4 2 0 2 0 0 Z")
  let assert Ok(inner) = parse.path("M0 0 C0 -1 -2 -1 -2 0 C-2 1 0 1 0 0 Z")
  list.each([outer, svg_path.path_reverse(outer)], fn(left) {
    list.each([inner, svg_path.path_reverse(inner)], fn(right) {
      let assert Ok(result) = csg.difference(left, right, svg_path.Nonzero)
      closed(result.path)
      // The two signed-area magnitudes are exactly 9.6 and 2.4 analytically.
      assert float.absolute_value(
          float.absolute_value(area.signed_path(result.path)) -. 7.2,
        )
        <. 1.0e-10
      list.each(
        [
          svg_path.Point(-3.0, 0.0),
          svg_path.Point(-1.0, 1.0),
          svg_path.Point(-1.0, -1.0),
        ],
        fn(point) {
          containment.path_containment(point, result.path, svg_path.Nonzero)
          |> should.equal(Ok(svg_path.Inside))
        },
      )
      containment.path_containment(
        svg_path.Point(-1.0, 0.0),
        result.path,
        svg_path.Nonzero,
      )
      |> should.equal(Ok(svg_path.Outside))
      let options = csg.default_options()
      let assert Ok(build) =
        arrangement.build(
          [left, right],
          tolerance: options.tolerance,
          minimum_length: options.minimum_length,
        )
      result.build.graph |> should.equal(build.graph)
    })
  })
}
