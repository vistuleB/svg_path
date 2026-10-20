import gleam/list
import svg_path.{Point}
import svg_path/area
import svg_path/offset
import svg_path/serialize

pub fn main() {
  let assert Ok(source) =
    svg_path.subpath_polygon([
      Point(-1.0, -1.0),
      Point(1.0, -1.0),
      Point(1.0, 1.0),
      Point(-1.0, 1.0),
    ])
  list.each([0.5, 1.0, 1.25, 1.5, 2.0, 2.5], fn(distance) {
    echo #(
      distance,
      case offset.subpath(source, 0.0 -. distance, offset.Round, offset.Butt) {
        Ok(path) ->
          Ok(
            list.map(path.subpaths, fn(s) {
              #(area.signed_subpath(s), serialize.subpath(s))
            }),
          )
        Error(error) -> Error(error)
      },
    )
  })
}
