import gleam/list
import svg_path.{Arc, Point}
import svg_path/area
import svg_path/offset

pub fn main() {
  let assert Ok(source) =
    svg_path.subpath([
      Arc(Point(0.0, 0.0), Point(1.0, 1.0), 0.0, False, True, Point(2.0, 0.0)),
      Arc(Point(2.0, 0.0), Point(1.0, 1.0), 0.0, False, True, Point(0.0, 0.0)),
    ])
  let assert Ok(source) = svg_path.subpath_close(source)
  list.each([0.5, 1.0, 1.5, 2.0, 2.5, 3.0], fn(distance) {
    let result =
      offset.subpath(source, 0.0 -. distance, offset.Round, offset.Butt)
    echo #(distance, case result {
      Ok(path) -> Ok(list.map(path.subpaths, area.signed_subpath))
      Error(error) -> Error(error)
    })
  })
}
