// Diagnostic fixtures adapted from Paper.js; MIT license in scripts/paperjs/upstream/LICENSE.txt.
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import svg_path
import svg_path/csg

pub fn main() {
  io.println("Fixture 16: frame.intersect(rect)")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(140.0, 310.0),
          svg_path.Point(140.0, 310.0),
          svg_path.Point(140.0, 10.0),
          svg_path.Point(140.0, 10.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(140.0, 10.0),
          svg_path.Point(140.0, 10.0),
          svg_path.Point(240.0, 10.0),
          svg_path.Point(240.0, 10.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(240.0, 10.0),
          svg_path.Point(240.0, 10.0),
          svg_path.Point(240.0, 310.0),
          svg_path.Point(240.0, 310.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(240.0, 310.0),
          svg_path.Point(240.0, 310.0),
          svg_path.Point(140.0, 310.0),
          svg_path.Point(140.0, 310.0),
        ),
      ])
        |> svg_path.subpath_assert_close
        |> svg_path.subpath_as_path,
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(150.0, 160.0),
          svg_path.Point(150.0, 160.0),
          svg_path.Point(150.0, 80.0),
          svg_path.Point(150.0, 80.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 80.0),
          svg_path.Point(150.0, 80.0),
          svg_path.Point(200.0, 80.0),
          svg_path.Point(200.0, 80.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 80.0),
          svg_path.Point(200.0, 80.0),
          svg_path.Point(200.0, 160.0),
          svg_path.Point(200.0, 160.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 160.0),
          svg_path.Point(200.0, 160.0),
          svg_path.Point(150.0, 160.0),
          svg_path.Point(150.0, 160.0),
        ),
      ])
        |> svg_path.subpath_assert_close
        |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(50.0, 200.0),
          svg_path.Point(50.0, 200.0),
          svg_path.Point(50.0, 50.0),
          svg_path.Point(50.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(50.0, 50.0),
          svg_path.Point(50.0, 50.0),
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 50.0),
          svg_path.Point(150.0, 200.0),
          svg_path.Point(150.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 200.0),
          svg_path.Point(150.0, 200.0),
          svg_path.Point(50.0, 200.0),
          svg_path.Point(50.0, 200.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 16: exact same rectangles represented by Line segments")
  csg.intersection_path(
    svg_path.path_combine([
      svg_path.subpath_assert_polygon([
        svg_path.Point(140.0, 310.0),
        svg_path.Point(140.0, 10.0),
        svg_path.Point(240.0, 10.0),
        svg_path.Point(240.0, 310.0),
      ])
        |> svg_path.subpath_as_path,
      svg_path.subpath_assert_polygon([
        svg_path.Point(150.0, 160.0),
        svg_path.Point(150.0, 80.0),
        svg_path.Point(200.0, 80.0),
        svg_path.Point(200.0, 160.0),
      ])
        |> svg_path.subpath_as_path,
    ]),
    svg_path.path_combine([
      svg_path.subpath_assert_polygon([
        svg_path.Point(50.0, 200.0),
        svg_path.Point(50.0, 50.0),
        svg_path.Point(150.0, 50.0),
        svg_path.Point(150.0, 200.0),
      ])
      |> svg_path.subpath_as_path,
    ]),
    svg_path.Nonzero,
  )
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 69: #1123")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(29.562573408343212, 132.54192488999095),
          svg_path.Point(28.14463782726017, 132.71602548770286),
          svg_path.Point(16.453914351064725, 123.13028232750008),
          svg_path.Point(2.5662795205536213, 124.83546947214427),
        ),
        svg_path.CubicBezier(
          svg_path.Point(2.5662795205536213, 124.83546947214427),
          svg_path.Point(2.5662795205536213, 124.83546947214427),
          svg_path.Point(18.447017946814753, 122.88555997766193),
          svg_path.Point(18.447017946814753, 122.88555997766193),
        ),
        svg_path.CubicBezier(
          svg_path.Point(18.447017946814753, 122.88555997766193),
          svg_path.Point(32.334652777325914, 121.18037283301771),
          svg_path.Point(44.0253762535213, 130.7661159932205),
          svg_path.Point(45.443311834604344, 130.5920153955086),
        ),
        svg_path.CubicBezier(
          svg_path.Point(45.443311834604344, 130.5920153955086),
          svg_path.Point(45.443311834604344, 130.5920153955086),
          svg_path.Point(29.562573408343212, 132.54192488999095),
          svg_path.Point(29.562573408343212, 132.54192488999095),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(5.684341886080802e-14, 132.07000000000002),
          svg_path.Point(21.125000000000057, 110.95000000000005),
          svg_path.Point(44.59500000000003, 132.87000000000006),
          svg_path.Point(44.59500000000003, 130.54000000000005),
        ),
        svg_path.CubicBezier(
          svg_path.Point(44.59500000000003, 130.54000000000005),
          svg_path.Point(49.4116697921923, 126.03811256974566),
          svg_path.Point(53.224727842758284, 121.2665981044083),
          svg_path.Point(56.887403180177614, 116.74936916538223),
        ),
        svg_path.CubicBezier(
          svg_path.Point(56.887403180177614, 116.74936916538223),
          svg_path.Point(56.889931541592034, 166.74936916538223),
          svg_path.Point(12.910000000000082, 159.14500000000004),
          svg_path.Point(5.684341886080802e-14, 132.07000000000002),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 172: #1506")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(250.0, 175.0),
          svg_path.Point(277.61424, 175.0),
          svg_path.Point(300.0, 197.38576),
          svg_path.Point(300.0, 225.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.0, 225.0),
          svg_path.Point(300.0, 252.61424),
          svg_path.Point(277.61424, 275.0),
          svg_path.Point(250.0, 275.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(250.0, 275.0),
          svg_path.Point(240.89282, 275.0),
          svg_path.Point(232.35433, 272.56514),
          svg_path.Point(225.0, 268.31089),
        ),
        svg_path.CubicBezier(
          svg_path.Point(225.0, 268.31089),
          svg_path.Point(239.94503, 259.66564999999997),
          svg_path.Point(250.0, 243.50705999999997),
          svg_path.Point(250.0, 224.99999999999997),
        ),
        svg_path.CubicBezier(
          svg_path.Point(250.0, 224.99999999999997),
          svg_path.Point(250.0, 206.49293999999998),
          svg_path.Point(239.94503, 190.33434999999997),
          svg_path.Point(225.0, 181.68910999999997),
        ),
        svg_path.CubicBezier(
          svg_path.Point(225.0, 181.68910999999997),
          svg_path.Point(232.35433, 177.43485999999996),
          svg_path.Point(240.89282, 175.0),
          svg_path.Point(250.0, 175.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(250.0, 225.0),
          svg_path.Point(250.0, 197.38576),
          svg_path.Point(272.38576, 175.0),
          svg_path.Point(300.0, 175.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.0, 175.0),
          svg_path.Point(327.61424, 175.0),
          svg_path.Point(350.0, 197.38576),
          svg_path.Point(350.0, 225.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(350.0, 225.0),
          svg_path.Point(350.0, 252.61424),
          svg_path.Point(327.61424, 275.0),
          svg_path.Point(300.0, 275.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.0, 275.0),
          svg_path.Point(272.38576, 275.0),
          svg_path.Point(250.0, 252.61424),
          svg_path.Point(250.0, 225.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.difference_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  list.each([False, True], fn(cubic) {
    io.println("Reduced touching rectangles, cubic=" <> string.inspect(cubic))
    csg.intersection_path(
      rectangle(150.0, 80.0, 200.0, 160.0, cubic),
      rectangle(50.0, 50.0, 150.0, 200.0, cubic),
      svg_path.Nonzero,
    )
    |> result.map(fn(p) { list.length(svg_path.path_subpaths(p)) })
    |> string.inspect
    |> io.println
  })
  Nil
}

fn rectangle(x0: Float, y0: Float, x1: Float, y1: Float, cubic: Bool) {
  let a = svg_path.Point(x0, y1)
  let b = svg_path.Point(x0, y0)
  let c = svg_path.Point(x1, y0)
  let d = svg_path.Point(x1, y1)
  [#(a, b), #(b, c), #(c, d), #(d, a)]
  |> list.map(fn(pair) {
    let #(start, end) = pair
    case cubic {
      True -> svg_path.CubicBezier(start, start, end, end)
      False -> svg_path.Line(start, end)
    }
  })
  |> svg_path.subpath_assert
  |> svg_path.subpath_assert_close
  |> svg_path.subpath_as_path
}
