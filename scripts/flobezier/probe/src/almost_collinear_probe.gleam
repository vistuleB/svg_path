import gleam/io
import gleam/list
import gleam/string
import svg_path.{CubicBezier, Point}
import svg_path/intersections
import svg_path/overlaps

pub fn main() {
  {
    let a =
      CubicBezier(
        Point(0.9646201687528162, 1.4210854715202004e-14),
        Point(0.6772878019443311, 2.1316282072803006e-14),
        Point(0.34565238552668376, 1.4210854715202004e-14),
        Point(0.43502028382843605, 1.4210854715202004e-14),
      )
    let b =
      CubicBezier(
        Point(0.4954801054242637, 2.1316282072803006e-14),
        Point(0.7755793433895946, 1.4210854715202004e-14),
        Point(0.013640682690727601, 0.0),
        Point(0.8957075918855395, 1.4210854715202004e-14),
      )
    io.println("Y SCALE 1")
    list.each(
      [0.000000001, 0.000000000001, 0.00000000000001, 0.0000000000000001],
      fn(tolerance) {
        io.println("TOL " <> string.inspect(tolerance))
        let options =
          intersections.IntersectionOptions(
            ..intersections.default_options(),
            tolerance:,
          )
        list.each([#(a, b), #(b, a)], fn(pair) {
          io.println(
            "overlap "
            <> string.inspect(overlaps.segment_with(pair.0, pair.1, tolerance:)),
          )
          io.println(
            "points "
            <> string.inspect(intersections.segment_with(
              pair.0,
              pair.1,
              options:,
            )),
          )
        })
      },
    )
  }
  {
    let a =
      CubicBezier(
        Point(0.9646201687528162, 1.0),
        Point(0.6772878019443311, 1.5),
        Point(0.34565238552668376, 1.0),
        Point(0.43502028382843605, 1.0),
      )
    let b =
      CubicBezier(
        Point(0.4954801054242637, 1.5),
        Point(0.7755793433895946, 1.0),
        Point(0.013640682690727601, 0.0),
        Point(0.8957075918855395, 1.0),
      )
    io.println("Y SCALE 70368744177664")
    list.each(
      [0.000000001, 0.000000000001, 0.00000000000001, 0.0000000000000001],
      fn(tolerance) {
        io.println("TOL " <> string.inspect(tolerance))
        let options =
          intersections.IntersectionOptions(
            ..intersections.default_options(),
            tolerance:,
          )
        list.each([#(a, b), #(b, a)], fn(pair) {
          io.println(
            "overlap "
            <> string.inspect(overlaps.segment_with(pair.0, pair.1, tolerance:)),
          )
          io.println(
            "points "
            <> string.inspect(intersections.segment_with(
              pair.0,
              pair.1,
              options:,
            )),
          )
        })
      },
    )
  }
}
