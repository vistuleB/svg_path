import gleam/float
import gleam/list
import gleeunit/should
import svg_path
import svg_path/area
import svg_path/arrangement
import svg_path/csg

// Exactly representable binary values: radius = 1/8, gap = 3/16.
// Each endpoint is 3/32 from its cluster center, but the pair is 3/16 apart.
const tolerance = 0.125

const minimum_length = 0.00001

fn rectangle(left: Float, right: Float) {
  svg_path.subpath_assert_polygon([
    svg_path.Point(left, 0.0),
    svg_path.Point(right, 0.0),
    svg_path.Point(right, 10.0),
    svg_path.Point(left, 10.0),
  ])
  |> svg_path.subpath_as_path
}

pub fn arrangement_accepts_endpoint_gap_larger_than_cluster_radius_test() {
  let assert Ok(build) =
    arrangement.build(
      [rectangle(0.0, 10.0), rectangle(10.1875, 20.0)],
      tolerance: tolerance,
      minimum_length: minimum_length,
    )
  arrangement.validate_representation(
    build.graph,
    tolerance: tolerance,
    minimum_length: minimum_length,
  )
  |> should.equal(Ok(Nil))

  list.each([0.0, 10.0], fn(y) {
    let a = svg_path.Point(10.0, y)
    let b = svg_path.Point(10.1875, y)
    let assert Ok(vertex) =
      list.find(build.graph.vertices, fn(vertex) {
        list.contains(vertex.endpoint_samples, a)
        && list.contains(vertex.endpoint_samples, b)
      })
    vertex.point |> should.equal(svg_path.Point(10.09375, y))
    assert float.absolute_value(a.x -. vertex.point.x) <. tolerance
    assert float.absolute_value(b.x -. vertex.point.x) <. tolerance
    assert b.x -. a.x >. tolerance
  })
}

pub fn csg_joins_endpoints_in_the_same_valid_cluster_test() {
  // The arrangement joins the rectangles at their nearby vertical sides.
  // CSG must reconstruct its outer boundary, not reject that valid cluster
  // because its endpoint diameter exceeds the cluster-radius tolerance.
  let assert Ok(output) =
    csg.union_with(
      rectangle(0.0, 10.0),
      rectangle(10.1875, 20.0),
      using: svg_path.Nonzero,
      options: csg.Options(tolerance: tolerance, minimum_length: minimum_length),
    )
  // Output construction must not replace the geometry in the returned graph.
  let assert Ok(original_build) =
    arrangement.build(
      [rectangle(0.0, 10.0), rectangle(10.1875, 20.0)],
      tolerance: tolerance,
      minimum_length: minimum_length,
    )
  output.build.graph |> should.equal(original_build.graph)
  let assert [subpath] = svg_path.path_subpaths(output.path)
  svg_path.subpath_is_closed(subpath) |> should.be_true
  let segments = svg_path.subpath_segments(subpath)
  list.each(segments, fn(segment) {
    list.any(output.build.graph.vertices, fn(vertex) {
      vertex.point == svg_path.segment_start(segment)
    })
    |> should.be_true
    list.any(output.build.graph.vertices, fn(vertex) {
      vertex.point == svg_path.segment_end(segment)
    })
    |> should.be_true
  })
  let assert [first, ..rest] = segments
  let assert Ok(last) = list.last(segments)
  svg_path.segment_end(last) |> should.equal(svg_path.segment_start(first))
  list.each(list.zip(segments, rest), fn(pair) {
    svg_path.segment_end(pair.0)
    |> should.equal(svg_path.segment_start(pair.1))
  })
  assert float.absolute_value(
      float.absolute_value(area.signed_path(output.path)) -. 200.0,
    )
    <. 0.000000001
}
