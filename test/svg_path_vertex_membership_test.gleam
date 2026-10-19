import gleam/list
import svg_path.{Line, Point}
import svg_path/arrangement

fn segments() {
  [
    Line(Point(0.0, 0.0), Point(0.0, 10.0)),
    Line(Point(2.6, 0.0), Point(2.6, 20.0)),
    Line(Point(-2.36, 0.0), Point(-2.36, 30.0)),
    Line(Point(0.0, 0.0), Point(0.0, -10.0)),
    Line(Point(0.0, 0.0), Point(10.0, -10.0)),
  ]
}

pub fn repeated_endpoint_retains_its_original_vertex_test() {
  let _ =
    list.fold(segments(), arrangement.empty(), fn(graph, segment) {
      let assert Ok(graph) =
        arrangement.insert_atomic_segment(graph, segment, 2.0, 0.01)
      let assert [owner] =
        list.filter(graph.vertices, fn(v) {
          list.contains(v.endpoint_samples, Point(0.0, 0.0))
        })
      assert owner.id == 0
      graph
    })
}

pub fn repeated_endpoint_does_not_make_progressive_build_ambiguous_test() {
  let assert Ok(build) = arrangement.build_with(segments(), 2.0, 0.01, 0.0)
  let assert [owner] =
    list.filter(build.graph.vertices, fn(v) {
      list.contains(v.endpoint_samples, Point(0.0, 0.0))
    })
  assert owner.point == Point(1.3, 0.0)
}
