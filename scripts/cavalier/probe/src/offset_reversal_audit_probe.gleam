import gleam/list
import svg_path.{Arc, Line, Point}
import svg_path/area
import svg_path/offset

pub fn main() {
  let assert Ok(source) =
    svg_path.subpath([
      Arc(Point(-2.0, 0.0), Point(1.0, 1.0), 0.0, False, True, Point(0.0, 0.0)),
      Arc(Point(0.0, 0.0), Point(1.0, 1.0), 0.0, False, True, Point(2.0, 0.0)),
      Line(Point(2.0, 0.0), Point(2.0, 2.0)),
      Line(Point(2.0, 2.0), Point(-2.0, 2.0)),
      Line(Point(-2.0, 2.0), Point(-2.0, 0.0)),
    ])
  let assert Ok(source) = svg_path.subpath_close(source)
  list.each([False, True], fn(reversed) {
    let #(source, distance) = case reversed {
      False -> #(source, -0.25)
      True -> #(svg_path.subpath_reverse(source), 0.25)
    }
    let result = offset.subpath(source, distance, offset.Round, offset.Butt)
    echo #(reversed, case result {
      Ok(path) -> Ok(list.map(path.subpaths, area.signed_subpath))
      Error(error) -> Error(error)
    })
  })
}
