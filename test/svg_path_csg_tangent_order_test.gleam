// Paper.js fixture 172 (#1506), MIT, copyright 2011–2020
// Jürg Lehni & Jonathan Puckey. See scripts/paperjs/upstream/LICENSE.txt.
import gleam/float
import gleam/list
import gleeunit/should
import svg_path
import svg_path/area
import svg_path/arrangement
import svg_path/containment
import svg_path/csg
import svg_path/distance
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

fn compare_boundary(from: svg_path.Path, to: svg_path.Path) {
  list.each(svg_path.path_subpaths(from), fn(subpath) {
    list.each(svg_path.subpath_segments(subpath), fn(segment) {
      list.each([0.0, 0.25, 0.5, 0.75, 1.0], fn(t) {
        let assert Ok(point) = svg_path.segment_point(segment, at: t)
        let assert Ok(distance) = distance.path_distance(point, to)
        assert distance <. 0.001
      })
    })
  })
}

pub fn paper_boolean_tangent_difference_172_test() {
  let assert Ok(left) =
    parse.path(
      "M250 175 C277.61424 175 300 197.38576 300 225 C300 252.61424 277.61424 275 250 275 C240.89282 275 232.35433 272.56514 225 268.31089 C239.94503 259.66564999999997 250 243.50705999999997 250 224.99999999999997 C250 206.49293999999998 239.94503 190.33434999999997 225 181.68910999999997 C232.35433 177.43485999999996 240.89282 175 250 175 Z",
    )
  let assert Ok(right) =
    parse.path(
      "M250 225 C250 197.38576 272.38576 175 300 175 C327.61424 175 350 197.38576 350 225 C350 252.61424 327.61424 275 300 275 C272.38576 275 250 252.61424 250 225 Z",
    )
  let assert Ok(expected) =
    parse.path(
      "M250,175c9.10718,0 17.64567,2.43486 25,6.68911c-14.94503,8.64523 -25,24.80383 -25,43.31089c0,18.50706 10.05497,34.66566 25,43.31089c-7.35433,4.25425 -15.89282,6.68911 -25,6.68911c-9.10718,0 -17.64567,-2.43486 -25,-6.68911c14.94503,-8.64524 25,-24.80383 25,-43.31089c0,-18.50706 -10.05497,-34.66565 -25,-43.31089c7.35433,-4.25425 15.89282,-6.68911 25,-6.68911z",
    )
  let assert Ok(actual) = csg.difference_path(left, right, svg_path.Nonzero)
  closed(actual)
  let want = float.absolute_value(area.signed_path(expected))
  assert float.absolute_value(
      float.absolute_value(area.signed_path(actual)) -. want,
    )
    <. 1.0e-5 *. want
  compare_boundary(actual, expected)
  compare_boundary(expected, actual)
  list.each([230.0, 240.0, 250.0, 260.0, 270.0], fn(x) {
    list.each([180.0, 200.0, 220.0, 240.0, 260.0, 270.0], fn(y) {
      let point = svg_path.Point(x, y)
      let assert Ok(a) = distance.path_distance(point, actual)
      let assert Ok(b) = distance.path_distance(point, expected)
      case a >. 0.001 && b >. 0.001 {
        True ->
          containment.path_containment(point, actual, svg_path.Nonzero)
          |> should.equal(containment.path_containment(
            point,
            expected,
            svg_path.Nonzero,
          ))
        False -> Nil
      }
    })
  })
}
