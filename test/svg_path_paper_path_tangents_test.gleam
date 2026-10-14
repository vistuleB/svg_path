// Adapted from pinned Paper.js Path.js; see scripts/paperjs/PATH_TANGENTS.md.
import gleam/float
import gleam/list
import svg_path
import svg_path/bezier
import svg_path/measure

fn circle() {
  svg_path.subpath_assert([
    svg_path.CubicBezier(
      svg_path.Point(-50.0, 0.0),
      svg_path.Point(-50.0, -27.61423749153968),
      svg_path.Point(-27.61423749153968, -50.0),
      svg_path.Point(0.0, -50.0),
    ),
    svg_path.CubicBezier(
      svg_path.Point(0.0, -50.0),
      svg_path.Point(27.61423749153968, -50.0),
      svg_path.Point(50.0, -27.61423749153968),
      svg_path.Point(50.0, 0.0),
    ),
    svg_path.CubicBezier(
      svg_path.Point(50.0, 0.0),
      svg_path.Point(50.0, 27.61423749153968),
      svg_path.Point(27.61423749153968, 50.0),
      svg_path.Point(0.0, 50.0),
    ),
    svg_path.CubicBezier(
      svg_path.Point(0.0, 50.0),
      svg_path.Point(-27.61423749153968, 50.0),
      svg_path.Point(-50.0, 27.61423749153968),
      svg_path.Point(-50.0, 0.0),
    ),
  ])
  |> svg_path.subpath_assert_close
}

fn near(a: Float, b: Float) {
  assert float.absolute_value(a -. b) <. 0.00000001
}

// Fixture-only adapter: no general path tangent-search API is claimed.
fn compare(
  direction: svg_path.Point,
  expected_raw: Int,
  expected: List(Float),
) {
  let subpath = circle()
  let segments = svg_path.subpath_segments(subpath)
  let raw =
    list.index_map(segments, fn(segment, index) {
      let assert svg_path.CubicBezier(a, b, c, d) = segment
      let data =
        bezier.CubicBezierData(
          bezier.BezierPoint(a.x, a.y),
          bezier.BezierPoint(b.x, b.y),
          bezier.BezierPoint(c.x, c.y),
          bezier.BezierPoint(d.x, d.y),
        )
      bezier.projection_extrema(
        data,
        direction: bezier.BezierPoint(0.0 -. direction.y, direction.x),
      )
      |> list.map(fn(t) {
        let assert Ok(derivative) = svg_path.segment_derivative(segment, at: t)
        assert derivative.x *. derivative.x +. derivative.y *. derivative.y
          >. 0.0
        near(derivative.x *. direction.y -. derivative.y *. direction.x, 0.0)
        let assert Ok(address) =
          svg_path.subpath_parameter_canonicalize(
            subpath,
            svg_path.SubpathParameter(index, t),
          )
        address
      })
    })
    |> list.flatten
  assert list.length(raw) == expected_raw
  let unique = list.unique(raw)
  assert list.length(unique) == 2
  let offsets =
    list.map(unique, fn(address) {
      let prefix = list.take(segments, address.segment_index)
      let assert Ok(segment) =
        list.drop(segments, address.segment_index) |> list.first
      let assert Ok(#(left, _)) = svg_path.segment_split(segment, at: address.t)
      list.fold([left, ..prefix], 0.0, fn(total, piece) {
        let assert Ok(length) = measure.segment_length(piece)
        total +. length
      })
    })
  assert list.length(offsets) == list.length(expected)
  list.each(list.zip(offsets, expected), fn(pair) { near(pair.0, pair.1) })
  offsets
}

pub fn paper_horizontal_tangent_offsets_at_joins_test() {
  let offsets =
    compare(svg_path.Point(1.0, 0.0), 4, [78.55083490369279, 235.65250471107836])
  let assert Ok(length) = measure.subpath_length(circle())
  let assert [first, second] = offsets
  near(first, 0.25 *. length)
  near(second, 0.75 *. length)
}

pub fn paper_diagonal_tangent_offsets_inside_curves_test() {
  let _ =
    compare(svg_path.Point(1.0, 1.0), 2, [
      117.82625235553917,
      274.92792216292474,
    ])
}
