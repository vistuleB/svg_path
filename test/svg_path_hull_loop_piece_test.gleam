import gleam/float
import gleam/list
import svg_path
import svg_path/convex_hull
import svg_path/point

fn assert_polygon(hull: svg_path.Subpath, expected: List(svg_path.Point)) {
  assert svg_path.subpath_is_closed(hull)
  let segments = svg_path.subpath_segments(hull)
  // A hull may retain collinear subdivisions. Require the same boundary and
  // perimeter, not the same segmentation; an extra circuit must fail.
  assert list.length(segments) >= list.length(expected)
  let vertices = list.map(segments, svg_path.segment_start)
  list.each(expected, fn(vertex) {
    assert list.contains(vertices, vertex)
  })
  // Verify actual connectivity, not just a set of vertices or a closed flag.
  let assert [first, ..] = segments
  let next = list.append(list.drop(segments, 1), [first])
  list.each(list.zip(segments, next), fn(pair) {
    assert svg_path.segment_end(pair.0) == svg_path.segment_start(pair.1)
    let assert svg_path.Line(..) = pair.0
  })
  let expected_loop = svg_path.subpath_assert_polygon(expected)
  let expected_edges = svg_path.subpath_segments(expected_loop)
  list.each(vertices, fn(vertex) {
    assert list.any(expected_edges, fn(edge) {
      let a = svg_path.segment_start(edge)
      let b = svg_path.segment_end(edge)
      let ab = point.subtract(b, a)
      let av = point.subtract(vertex, a)
      let cross = ab.x *. av.y -. ab.y *. av.x
      let projection = point.dot(ab, av)
      cross == 0.0 && projection >=. 0.0 && projection <=. point.dot(ab, ab)
    })
  })
  let perimeter = fn(edges) {
    list.fold(edges, 0.0, fn(sum, edge) {
      sum
      +. point.distance(
        svg_path.segment_start(edge),
        svg_path.segment_end(edge),
      )
    })
  }
  assert float.absolute_value(perimeter(segments) -. perimeter(expected_edges))
    <. 0.000000001
}

pub fn vertex_contribution_does_not_expand_into_full_loop_test() {
  let source =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(1.0, 0.0),
      svg_path.Point(2.0, 1.0),
      svg_path.Point(3.0, 0.0),
    ])
  let assert Ok(hull) = convex_hull.subpath(source)
  assert list.length(svg_path.subpath_segments(hull)) == 3
  assert_polygon(hull, [
    svg_path.Point(0.0, 0.0),
    svg_path.Point(3.0, 0.0),
    svg_path.Point(2.0, 1.0),
  ])
}

pub fn reversed_input_preserves_triangle_without_extra_circuit_test() {
  let source =
    svg_path.subpath_assert_polyline([
      svg_path.Point(3.0, 0.0),
      svg_path.Point(2.0, 1.0),
      svg_path.Point(1.0, 0.0),
      svg_path.Point(0.0, 0.0),
    ])
  let assert Ok(hull) = convex_hull.subpath(source)
  assert_polygon(hull, [
    svg_path.Point(0.0, 0.0),
    svg_path.Point(3.0, 0.0),
    svg_path.Point(2.0, 1.0),
  ])
}

pub fn closure_address_aliases_preserve_triangle_test() {
  let vertices = [
    svg_path.Point(0.0, 0.0),
    svg_path.Point(1.0, 0.0),
    svg_path.Point(2.0, 1.0),
    svg_path.Point(3.0, 0.0),
  ]
  list.each([0, 1, 2, 3], fn(index) {
    let rotated =
      list.append(list.drop(vertices, index), list.take(vertices, index))
    let assert Ok(hull) =
      convex_hull.subpath(svg_path.subpath_assert_polygon(rotated))
    assert_polygon(hull, [
      svg_path.Point(0.0, 0.0),
      svg_path.Point(3.0, 0.0),
      svg_path.Point(2.0, 1.0),
    ])
  })
}

pub fn full_hull_is_retained_in_either_union_operand_test() {
  let vertices = [
    svg_path.Point(0.0, 0.0),
    svg_path.Point(4.0, 0.0),
    svg_path.Point(4.0, 4.0),
    svg_path.Point(0.0, 4.0),
  ]
  let square = svg_path.subpath_assert_polygon(vertices)
  let interior =
    svg_path.subpath_assert_polygon([
      svg_path.Point(1.0, 1.0),
      svg_path.Point(2.0, 1.0),
      svg_path.Point(1.0, 2.0),
    ])
  list.each(
    [[square, interior], [interior, square], [square, square]],
    fn(subpaths) {
      let assert Ok(hull) = convex_hull.path(svg_path.Path(subpaths))
      assert_polygon(hull, vertices)
    },
  )
}

pub fn narrow_triangle_vertex_contribution_preserves_extent_test() {
  let source =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(1.0, 0.0),
      svg_path.Point(2.0, 0.000000001),
      svg_path.Point(3.0, 0.0),
    ])
  let assert Ok(hull) = convex_hull.subpath(source)
  assert_polygon(hull, [
    svg_path.Point(0.0, 0.0),
    svg_path.Point(3.0, 0.0),
    svg_path.Point(2.0, 0.000000001),
  ])
}
