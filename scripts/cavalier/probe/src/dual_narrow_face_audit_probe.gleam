import gleam/list
import svg_path.{Arc, Line, Point}
import svg_path/arrangement

pub fn main() {
  list.each([0.001, 0.0001, 0.00001], fn(size) {
    list.each([False, True], fn(remote) {
      let p = Point(0.0, 0.0)
      let q = Point(size, 0.0 -. size)
      let segments = [
        Line(p, Point(1.0, 0.0)),
        Line(Point(1.0, 0.0), Point(0.0, 1.0)),
        Line(Point(0.0, 1.0), p),
        Arc(p, Point(1.0, 1.0), 0.0, False, True, q),
        Line(q, p),
      ]
      let segments = case remote {
        True -> [Line(Point(3.0, 0.0), Point(3.0, 1.0)), ..segments]
        False -> segments
      }
      let assert Ok(built) =
        arrangement.build_with(
          segments,
          vertex_tolerance: 0.000000000001,
          minimum_length: 0.000000000001,
          endpoint_sliver_tolerance: 0.0,
        )
      let result = case arrangement.dual(built.graph) {
        Ok(dual) -> Ok(list.length(dual.faces))
        Error(error) -> Error(error)
      }
      echo #(size, remote, result)
    })
  })
}
