import gleam/io
import gleam/list
import gleam/option.{Some}
import gleam/result
import gleam/string
import svg_path
import svg_path/basic_shapes
import svg_path/offset
import svg_path/parse
import svg_path/stroke

fn report(label, source) {
  let output =
    stroke.subpath(source, width: 2.0, join: offset.Round, cap: offset.Butt)
    |> result.map(fn(p) { list.length(svg_path.path_subpaths(p)) })
  io.println(label <> ": " <> string.inspect(output))
}

pub fn main() {
  list.each(
    [
      #("line", "M0 0L20 0"),
      #("line with interior duplicate", "M0 0L10 0L10 0L20 0"),
      #("line with leading duplicate", "M0 0L0 0L20 0"),
      #("line with trailing duplicate", "M0 0L20 0L20 0"),
      #("arc", "M10 0A10 10 0 0 1 0 10"),
      #("arc with leading duplicate", "M10 0L10 0A10 10 0 0 1 0 10"),
    ],
    fn(item) {
      let assert Ok(svg_path.Path([s])) = parse.path(item.1)
      report(item.0, s)
    },
  )
  list.each([89.0, 90.0, 100.0], fn(radius) {
    let assert Ok(s) =
      basic_shapes.rect(
        x: 0.0,
        y: 0.0,
        width: 300.0,
        height: 180.0,
        rx: Some(radius),
        ry: Some(radius),
      )
    report("rounded radius " <> string.inspect(radius), s)
  })
}
