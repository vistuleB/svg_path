import gleam/int
import gleam/io
import gleam/list
import gleam/result
import svg_path
import svg_path/measure

pub fn main() {
  let points = list.repeat(svg_path.Point(0.0, 0.0), 100_000)
  let assert Ok(big) = svg_path.subpath_polyline(points)
  assert list.length(svg_path.subpath_segments(big)) == 99_999
  assert svg_path.subpath_start(big) == svg_path.Point(0.0, 0.0)
  assert svg_path.subpath_end(big) == svg_path.Point(0.0, 0.0)
  assert measure.subpath_length(big) == Ok(0.0)
  assert construct(100_000, True) == Ok(99_999)
  io.println("PASS #1493: 100000 point construction, 99999 edges, zero length")
}

pub fn construct(count: Int, distinct: Bool) {
  let points =
    list.repeat(Nil, count)
    |> list.index_map(fn(_, i) {
      svg_path.Point(
        case distinct {
          True -> int.to_float(i)
          False -> 0.0
        },
        0.0,
      )
    })
  svg_path.subpath_polyline(points)
  |> result.map(fn(s) { list.length(svg_path.subpath_segments(s)) })
}
