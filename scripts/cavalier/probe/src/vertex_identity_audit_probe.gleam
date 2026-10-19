import gleam/list
import svg_path.{Line, Point}
import svg_path/arrangement

pub fn main() {
  let a = Point(0.0, 0.0)
  let segments = [
    Line(a, Point(0.0, 10.0)),
    Line(Point(2.6, 0.0), Point(2.6, 20.0)),
    Line(Point(-2.36, 0.0), Point(-2.36, 30.0)),
    Line(a, Point(0.0, -10.0)),
    Line(a, Point(10.0, -10.0)),
  ]
  let _ =
    list.fold(segments, arrangement.empty(), fn(graph, segment) {
      let assert Ok(graph) =
        arrangement.insert_atomic_segment(graph, segment, 2.0, 0.01)
      let _ =
        echo list.filter(graph.vertices, fn(v) {
          list.contains(v.endpoint_samples, a)
        })
      graph
    })
  let _ = echo arrangement.build_with(segments, 2.0, 0.01, 0.0)
  Nil
}
