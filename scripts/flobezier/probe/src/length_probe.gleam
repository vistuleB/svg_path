import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import svg_path.{CubicBezier, Point, QuadraticBezier}
import svg_path/bezier
import svg_path/measure

pub fn main() {
  let curves = [
    #(
      "quadratic",
      QuadraticBezier(Point(0.0, 0.0), Point(3.0, 1.0), Point(1.0, 1.0 /. 3.0)),
    ),
    #(
      "cubic",
      CubicBezier(
        Point(0.0, 0.0),
        Point(3.0, 0.0),
        Point(-1.0, 0.0),
        Point(2.0, 0.0),
      ),
    ),
  ]
  list.each(curves, fn(named) {
    list.each([#(0.0, 1.0), #(0.25, 0.75)], fn(interval) {
      let assert Ok(piece) =
        svg_path.segment_between(named.1, from: interval.0, to: interval.1)
      io.println(named.0 <> " " <> string.inspect(interval))
      io.println("default " <> string.inspect(measure.segment_length(piece)))
      list.each([20, 24, 32, 48], fn(depth) {
        let options =
          svg_path.LengthOptions(
            ..measure.default_length_options(),
            max_depth: depth,
          )
        io.println(
          "depth "
          <> string.inspect(depth)
          <> " "
          <> string.inspect(measure.segment_length_with(piece, options:)),
        )
      })
      let turns =
        bezier.projection_extrema(
          svg_path.segment_to_bezier_data(piece),
          direction: bezier.BezierPoint(1.0, 0.0),
        )
      io.println("turns " <> string.inspect(turns))
      let boundaries = list.sort([0.0, 1.0, ..turns], by: float.compare)
      io.println(
        "split "
        <> string.inspect(split_length(
          piece,
          boundaries,
          list.length(boundaries) - 1,
          20,
        )),
      )
      io.println(
        "split depth 1 "
        <> string.inspect(split_length(
          piece,
          boundaries,
          list.length(boundaries) - 1,
          1,
        )),
      )
      io.println(
        "reverse "
        <> string.inspect(
          measure.segment_length(svg_path.segment_reverse(piece)),
        ),
      )
    })
  })
}

fn split_length(segment, boundaries, count, depth) {
  case boundaries {
    [a, b, ..rest] -> {
      use piece <- result.try(svg_path.segment_between(segment, from: a, to: b))
      let options = measure.default_length_options()
      use length <- result.try(measure.segment_length_with(
        piece,
        options: svg_path.LengthOptions(
          ..options,
          tolerance: options.tolerance /. { count |> int.to_float },
          max_depth: depth,
        ),
      ))
      use remaining <- result.try(split_length(
        segment,
        [b, ..rest],
        count,
        depth,
      ))
      Ok(length +. remaining)
    }
    _ -> Ok(0.0)
  }
}
