import gleam/list
import svg_path.{Arc, Line, Point}
import svg_path/arrangement

fn narrow_component(size: Float) -> List(svg_path.Segment) {
  let p = Point(0.0, 0.0)
  let q = Point(size, 0.0 -. size)
  [
    Line(p, Point(1.0, 0.0)),
    Line(Point(1.0, 0.0), Point(0.0, 1.0)),
    Line(Point(0.0, 1.0), p),
    Arc(p, Point(1.0, 1.0), 0.0, False, True, q),
    Line(q, p),
  ]
}

fn check_bridge(bridge: svg_path.Segment, outside: Bool) {
  list.each([0.001, 0.0001, 0.00001], fn(size) {
    list.each([False, True], fn(reverse) {
      list.each([False, True], fn(reorder) {
        let segments = [bridge, ..narrow_component(size)]
        let segments = case reverse {
          True -> list.map(segments, svg_path.segment_reverse)
          False -> segments
        }
        let segments = case reorder {
          True -> list.reverse(segments)
          False -> segments
        }
        let assert Ok(built) =
          arrangement.build_with(
            segments,
            vertex_tolerance: 0.000000000001,
            minimum_length: 0.000000000001,
            endpoint_sliver_tolerance: 0.0,
          )
        let assert Ok(dual) = arrangement.dual(built.graph)
        assert list.length(dual.faces) == 3
        let assert Ok(bridge_edge) =
          list.find(built.graph.edges, fn(edge) {
            edge.segment == bridge
            || edge.segment == svg_path.segment_reverse(bridge)
          })
        let assert Ok(bridge_faces) =
          list.find(dual.edge_faces, fn(edge) { edge.edge_id == bridge_edge.id })
        assert bridge_faces.left_face == bridge_faces.right_face
        let assert Ok(host) =
          list.find(dual.faces, fn(face) { face.id == bridge_faces.left_face })
        assert host.outer == outside
        assert list.length(host.walks) == 2
        assert list.length(dual.edge_faces) == list.length(built.graph.edges)
      })
    })
  })
}

pub fn remote_bridge_preserves_narrow_local_face_test() {
  check_bridge(Line(Point(3.0, 0.0), Point(3.0, 1.0)), True)
}

pub fn enclosed_bridge_uses_correct_local_face_test() {
  check_bridge(Line(Point(0.2, 0.2), Point(0.3, 0.2)), False)
}

pub fn enclosing_component_preserves_narrow_local_face_test() {
  let square = [
    Line(Point(-1.0, -1.0), Point(2.0, -1.0)),
    Line(Point(2.0, -1.0), Point(2.0, 2.0)),
    Line(Point(2.0, 2.0), Point(-1.0, 2.0)),
    Line(Point(-1.0, 2.0), Point(-1.0, -1.0)),
  ]
  list.each([False, True], fn(reverse) {
    let inner = narrow_component(0.00001)
    let inner = case reverse {
      True -> list.map(inner, svg_path.segment_reverse)
      False -> inner
    }
    let assert Ok(built) =
      arrangement.build_with(
        list.append(square, inner),
        vertex_tolerance: 0.000000000001,
        minimum_length: 0.000000000001,
        endpoint_sliver_tolerance: 0.0,
      )
    let assert Ok(dual) = arrangement.dual(built.graph)
    assert list.length(dual.faces) == 4
    let assert [annulus] =
      list.filter(dual.faces, fn(face) { list.length(face.walks) == 2 })
    assert !annulus.outer
    let assert [outer, island] = annulus.walks
    assert outer.outer && !island.outer
  })
}
