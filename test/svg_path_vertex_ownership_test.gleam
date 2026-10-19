import gleam/list
import svg_path.{Line, Point}
import svg_path/arrangement as a
import svg_path/bounds

fn graph() -> a.ArrangementGraph {
  let segment0 = Line(Point(-0.9, 0.0), Point(4.0, 3.0))
  let segment1 = Line(Point(0.9, 0.0), Point(2.0, 0.0))
  let assert Ok(bounds0) = bounds.segment_bounding_box(segment0)
  let assert Ok(bounds1) = bounds.segment_bounding_box(segment1)
  a.ArrangementGraph(
    vertices: [
      a.ArrangementVertex(0, Point(0.0, 0.0), [
        Point(-0.9, 0.0),
        Point(0.9, 0.0),
      ]),
      a.ArrangementVertex(1, Point(2.0, 0.0), [Point(2.0, 0.0)]),
      a.ArrangementVertex(2, Point(4.0, 3.0), [Point(4.0, 3.0)]),
    ],
    edges: [
      a.ArrangementEdge(0, segment0, bounds0, 0, 2, 1, 0),
      a.ArrangementEdge(1, segment1, bounds1, 0, 1, 1, 0),
    ],
    cyclic_orders: [],
  )
}

fn owner(start: svg_path.Point) -> Int {
  let source = graph()
  let segment = Line(start, Point(0.0, -4.0))
  let assert Ok(result) =
    a.insert_atomic_segment(
      source,
      segment,
      tolerance: 1.0,
      minimum_length: 0.1,
    )
  let assert Ok(edge) = list.find(result.edges, fn(e) { e.id == 2 })
  assert edge.segment == segment
  assert list.take(result.edges, 2) == source.edges
  edge.start_vertex
}

pub fn unique_center_owner_precedes_smaller_enclosing_circle_test() {
  // Vertex 0 is the only center within tolerance; enlarging vertex 1 would
  // produce a smaller circle, but must not change the previously matched owner.
  assert owner(Point(0.900000000000001, -0.000000000000001)) == 0
}

pub fn exact_sample_keeps_owner_test() {
  assert owner(Point(0.9, 0.0)) == 0
}

pub fn ambiguous_or_missing_center_match_keeps_clustering_fallback_test() {
  assert owner(Point(1.0, 0.0)) == 1
  assert owner(Point(3.1, 0.0)) == 1
}

pub fn matching_both_endpoints_does_not_create_spurious_bridge_test() {
  let segment =
    Line(
      Point(0.900000000000001, -0.000000000000001),
      Point(-0.8, -0.000000000000001),
    )
  assert a.insert_atomic_segment(
      graph(),
      segment,
      tolerance: 1.0,
      minimum_length: 0.1,
    )
    == Error(a.InternalSegmentCollapsedToVertex(0))
}
