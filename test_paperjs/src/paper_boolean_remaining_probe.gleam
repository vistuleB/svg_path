// Diagnostic inputs adapted from pinned Paper.js; MIT license in
// scripts/paperjs/upstream/LICENSE.txt. Errors are printed, not asserted correct.
import gleam/io
import gleam/result
import gleam/string
import svg_path
import svg_path/csg

pub fn main() {
  io.println("Fixture 16")
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
  io.println("Fixture 17")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(100.0, 300.0),
          svg_path.Point(100.0, 300.0),
          svg_path.Point(100.0, 250.0),
          svg_path.Point(100.0, 250.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(100.0, 250.0),
          svg_path.Point(100.0, 250.0),
          svg_path.Point(150.0, 200.0),
          svg_path.Point(150.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 200.0),
          svg_path.Point(150.0, 200.0),
          svg_path.Point(100.0, 200.0),
          svg_path.Point(100.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(100.0, 200.0),
          svg_path.Point(100.0, 200.0),
          svg_path.Point(250.0, 200.0),
          svg_path.Point(250.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(250.0, 200.0),
          svg_path.Point(250.0, 200.0),
          svg_path.Point(100.0, 200.0),
          svg_path.Point(100.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(100.0, 200.0),
          svg_path.Point(100.0, 200.0),
          svg_path.Point(150.0, 200.0),
          svg_path.Point(150.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 200.0),
          svg_path.Point(150.0, 200.0),
          svg_path.Point(100.0, 200.0),
          svg_path.Point(100.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(100.0, 200.0),
          svg_path.Point(100.0, 200.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 200.0),
          svg_path.Point(200.0, 200.0),
          svg_path.Point(100.0, 200.0),
          svg_path.Point(100.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(100.0, 200.0),
          svg_path.Point(100.0, 200.0),
          svg_path.Point(100.0, 100.0),
          svg_path.Point(100.0, 100.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(100.0, 100.0),
          svg_path.Point(100.0, 100.0),
          svg_path.Point(300.0, 100.0),
          svg_path.Point(300.0, 100.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.0, 100.0),
          svg_path.Point(300.0, 100.0),
          svg_path.Point(300.0, 300.0),
          svg_path.Point(300.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.0, 300.0),
          svg_path.Point(300.0, 300.0),
          svg_path.Point(100.0, 300.0),
          svg_path.Point(100.0, 300.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right = svg_path.path_empty()
  csg.union_path(left, right, svg_path.EvenOdd)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 20")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(570.0, 290.0),
          svg_path.Point(570.0, 290.0),
          svg_path.Point(575.8176000300452, 323.5855681222093),
          svg_path.Point(575.8176000300452, 323.5855681222093),
        ),
        svg_path.CubicBezier(
          svg_path.Point(575.8176000300452, 323.5855681222093),
          svg_path.Point(575.8176000300452, 323.5855681222093),
          svg_path.Point(547.6444566349796, 309.1465641549448),
          svg_path.Point(547.6444566349796, 309.1465641549448),
        ),
        svg_path.CubicBezier(
          svg_path.Point(547.6444566349796, 309.1465641549448),
          svg_path.Point(547.6444566349796, 309.1465641549448),
          svg_path.Point(578.8341920603752, 304.57835489946484),
          svg_path.Point(578.8341920603752, 304.57835489946484),
        ),
        svg_path.CubicBezier(
          svg_path.Point(578.8341920603752, 304.57835489946484),
          svg_path.Point(578.8341920546527, 304.57835486039346),
          svg_path.Point(519.4675806753132, 313.27349449897866),
          svg_path.Point(519.4675806753132, 313.27349449897866),
        ),
        svg_path.CubicBezier(
          svg_path.Point(519.4675806753132, 313.27349449897866),
          svg_path.Point(519.4675806753132, 313.27349449897866),
          svg_path.Point(570.0, 290.0),
          svg_path.Point(570.0, 290.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right = svg_path.path_empty()
  csg.union_path(left, right, svg_path.EvenOdd)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 29")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(400.0, 300.0),
          svg_path.Point(400.0, 300.0),
          svg_path.Point(396.4240965757225, 386.760212367686),
          svg_path.Point(396.4240965757225, 386.760212367686),
        ),
        svg_path.CubicBezier(
          svg_path.Point(396.4240965757225, 386.760212367686),
          svg_path.Point(396.4240965757225, 386.760212367686),
          svg_path.Point(363.8902430603039, 336.3464406833805),
          svg_path.Point(363.8902430603039, 336.3464406833805),
        ),
        svg_path.CubicBezier(
          svg_path.Point(363.8902430603039, 336.3464406833805),
          svg_path.Point(363.8902430603039, 336.3464406833805),
          svg_path.Point(400.0, 300.0),
          svg_path.Point(400.0, 300.0),
        ),
      ])
        |> svg_path.subpath_assert_close
        |> svg_path.subpath_as_path,
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(380.15716053320796, 361.5533174872367),
          svg_path.Point(380.15716053320796, 361.5533174872367),
          svg_path.Point(368.9579765078272, 389.3845783631412),
          svg_path.Point(368.9579765078272, 389.3845783631412),
        ),
        svg_path.CubicBezier(
          svg_path.Point(368.9579765078272, 389.3845783631412),
          svg_path.Point(368.9579765078272, 389.3845783631412),
          svg_path.Point(352.11749924000907, 372.22000125020173),
          svg_path.Point(352.11749924000907, 372.22000125020173),
        ),
        svg_path.CubicBezier(
          svg_path.Point(352.11749924000907, 372.22000125020173),
          svg_path.Point(352.11749924000907, 372.22000125020173),
          svg_path.Point(380.15716053320796, 361.5533174872367),
          svg_path.Point(380.15716053320796, 361.5533174872367),
        ),
      ])
        |> svg_path.subpath_assert_close
        |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(381.9248139754118, 360.88087710036456),
          svg_path.Point(381.9248139754118, 360.88087710036456),
          svg_path.Point(352.11749931845384, 372.22000145641056),
          svg_path.Point(352.11749931845384, 372.22000145641056),
        ),
        svg_path.CubicBezier(
          svg_path.Point(352.11749931845384, 372.22000145641056),
          svg_path.Point(352.11749931845384, 372.22000145641056),
          svg_path.Point(353.8723170322086, 346.9400510828104),
          svg_path.Point(353.8723170322086, 346.9400510828104),
        ),
        svg_path.CubicBezier(
          svg_path.Point(353.8723170322086, 346.9400510828104),
          svg_path.Point(353.8723170322086, 346.9400510828104),
          svg_path.Point(381.9248139754118, 360.88087710036456),
          svg_path.Point(381.9248139754118, 360.88087710036456),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 31")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(401.77542835664826, 286.9803609495646),
          svg_path.Point(401.77542835664826, 286.9803609495646),
          svg_path.Point(410.6261525310172, 207.97354059345616),
          svg_path.Point(410.6261525310172, 207.97354059345616),
        ),
        svg_path.CubicBezier(
          svg_path.Point(410.6261525310172, 207.97354059345616),
          svg_path.Point(410.6261525310172, 207.97354059345616),
          svg_path.Point(460.3783408790767, 174.43669899386418),
          svg_path.Point(460.3783408790767, 174.43669899386418),
        ),
        svg_path.CubicBezier(
          svg_path.Point(460.3783408790767, 174.43669899386418),
          svg_path.Point(460.3783408790767, 174.43669899386418),
          svg_path.Point(401.77542835664826, 286.9803609495646),
          svg_path.Point(401.77542835664826, 286.9803609495646),
        ),
      ])
        |> svg_path.subpath_assert_close
        |> svg_path.subpath_as_path,
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(410.6261524612045, 207.9735406405153),
          svg_path.Point(410.6261524612045, 207.9735406405153),
          svg_path.Point(410.62564661421885, 207.97277197764396),
          svg_path.Point(410.6261525310172, 207.97354059345614),
        ),
        svg_path.CubicBezier(
          svg_path.Point(410.6261525310172, 207.97354059345614),
          svg_path.Point(410.6261525310172, 207.97354059345614),
          svg_path.Point(410.6261524612045, 207.9735406405153),
          svg_path.Point(410.6261524612045, 207.9735406405153),
        ),
      ])
        |> svg_path.subpath_assert_close
        |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(410.6261524612047, 207.97354064051552),
          svg_path.Point(410.8251999563934, 208.26882928424274),
          svg_path.Point(410.84674387259815, 207.8701141694839),
          svg_path.Point(409.163896522797, 207.2586618457598),
        ),
        svg_path.CubicBezier(
          svg_path.Point(409.163896522797, 207.2586618457598),
          svg_path.Point(409.163896522797, 207.2586618457598),
          svg_path.Point(460.3783408790765, 174.43669899386396),
          svg_path.Point(460.3783408790765, 174.43669899386396),
        ),
        svg_path.CubicBezier(
          svg_path.Point(460.3783408790765, 174.43669899386396),
          svg_path.Point(460.3783408790765, 174.43669899386396),
          svg_path.Point(410.6261524612047, 207.97354064051552),
          svg_path.Point(410.6261524612047, 207.97354064051552),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 36")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(300.0, 100.0),
          svg_path.Point(300.0, 100.0),
          svg_path.Point(300.0, 350.0),
          svg_path.Point(300.0, 350.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.0, 350.0),
          svg_path.Point(300.0, 350.0),
          svg_path.Point(256.00000000000006, 350.0),
          svg_path.Point(256.00000000000006, 350.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(256.00000000000006, 350.0),
          svg_path.Point(256.00000000000006, 350.0),
          svg_path.Point(256.00000000000006, 250.0),
          svg_path.Point(256.00000000000006, 250.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(256.00000000000006, 250.0),
          svg_path.Point(256.00000000000006, 250.0),
          svg_path.Point(230.0, 224.0),
          svg_path.Point(230.0, 224.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(230.0, 224.0),
          svg_path.Point(230.0, 224.0),
          svg_path.Point(256.00000000000006, 200.0),
          svg_path.Point(256.00000000000006, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(256.00000000000006, 200.0),
          svg_path.Point(256.00000000000006, 200.0),
          svg_path.Point(256.00000000000006, 100.0),
          svg_path.Point(256.00000000000006, 100.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(256.00000000000006, 100.0),
          svg_path.Point(256.00000000000006, 100.0),
          svg_path.Point(300.0, 100.0),
          svg_path.Point(300.0, 100.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(256.0, 150.0),
          svg_path.Point(256.0, 150.0),
          svg_path.Point(256.0, 300.0),
          svg_path.Point(256.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(256.0, 300.0),
          svg_path.Point(256.0, 300.0),
          svg_path.Point(200.0, 300.0),
          svg_path.Point(200.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 300.0),
          svg_path.Point(200.0, 300.0),
          svg_path.Point(200.0, 150.0),
          svg_path.Point(200.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 150.0),
          svg_path.Point(200.0, 150.0),
          svg_path.Point(256.0, 150.0),
          svg_path.Point(256.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.difference_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 37")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(299.9999999, 100.0),
          svg_path.Point(299.9999999, 100.0),
          svg_path.Point(299.9999999, 350.0),
          svg_path.Point(299.9999999, 350.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(299.9999999, 350.0),
          svg_path.Point(299.9999999, 350.0),
          svg_path.Point(255.99999990000003, 350.0),
          svg_path.Point(255.99999990000003, 350.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(255.99999990000003, 350.0),
          svg_path.Point(255.99999990000003, 350.0),
          svg_path.Point(255.99999990000003, 250.0),
          svg_path.Point(255.99999990000003, 250.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(255.99999990000003, 250.0),
          svg_path.Point(255.99999990000003, 250.0),
          svg_path.Point(229.99999989999998, 224.0),
          svg_path.Point(229.99999989999998, 224.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(229.99999989999998, 224.0),
          svg_path.Point(229.99999989999998, 224.0),
          svg_path.Point(255.99999990000003, 200.0),
          svg_path.Point(255.99999990000003, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(255.99999990000003, 200.0),
          svg_path.Point(255.99999990000003, 200.0),
          svg_path.Point(255.99999990000003, 100.0),
          svg_path.Point(255.99999990000003, 100.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(255.99999990000003, 100.0),
          svg_path.Point(255.99999990000003, 100.0),
          svg_path.Point(299.9999999, 100.0),
          svg_path.Point(299.9999999, 100.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(256.0, 150.0),
          svg_path.Point(256.0, 150.0),
          svg_path.Point(256.0, 300.0),
          svg_path.Point(256.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(256.0, 300.0),
          svg_path.Point(256.0, 300.0),
          svg_path.Point(200.0, 300.0),
          svg_path.Point(200.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 300.0),
          svg_path.Point(200.0, 300.0),
          svg_path.Point(200.0, 150.0),
          svg_path.Point(200.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 150.0),
          svg_path.Point(200.0, 150.0),
          svg_path.Point(256.0, 150.0),
          svg_path.Point(256.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.difference_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 38")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(300.0000001, 100.0),
          svg_path.Point(300.0000001, 100.0),
          svg_path.Point(300.0000001, 350.0),
          svg_path.Point(300.0000001, 350.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.0000001, 350.0),
          svg_path.Point(300.0000001, 350.0),
          svg_path.Point(256.0000001000001, 350.0),
          svg_path.Point(256.0000001000001, 350.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(256.0000001000001, 350.0),
          svg_path.Point(256.0000001000001, 350.0),
          svg_path.Point(256.0000001000001, 250.0),
          svg_path.Point(256.0000001000001, 250.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(256.0000001000001, 250.0),
          svg_path.Point(256.0000001000001, 250.0),
          svg_path.Point(230.00000010000002, 224.0),
          svg_path.Point(230.00000010000002, 224.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(230.00000010000002, 224.0),
          svg_path.Point(230.00000010000002, 224.0),
          svg_path.Point(256.0000001000001, 200.0),
          svg_path.Point(256.0000001000001, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(256.0000001000001, 200.0),
          svg_path.Point(256.0000001000001, 200.0),
          svg_path.Point(256.0000001000001, 100.0),
          svg_path.Point(256.0000001000001, 100.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(256.0000001000001, 100.0),
          svg_path.Point(256.0000001000001, 100.0),
          svg_path.Point(300.0000001, 100.0),
          svg_path.Point(300.0000001, 100.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(256.0, 150.0),
          svg_path.Point(256.0, 150.0),
          svg_path.Point(256.0, 300.0),
          svg_path.Point(256.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(256.0, 300.0),
          svg_path.Point(256.0, 300.0),
          svg_path.Point(200.0, 300.0),
          svg_path.Point(200.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 300.0),
          svg_path.Point(200.0, 300.0),
          svg_path.Point(200.0, 150.0),
          svg_path.Point(200.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 150.0),
          svg_path.Point(200.0, 150.0),
          svg_path.Point(256.0, 150.0),
          svg_path.Point(256.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.difference_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 39")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(299.999999999, 100.0),
          svg_path.Point(299.999999999, 100.0),
          svg_path.Point(299.999999999, 350.0),
          svg_path.Point(299.999999999, 350.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(299.999999999, 350.0),
          svg_path.Point(299.999999999, 350.0),
          svg_path.Point(255.99999999900007, 350.0),
          svg_path.Point(255.99999999900007, 350.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(255.99999999900007, 350.0),
          svg_path.Point(255.99999999900007, 350.0),
          svg_path.Point(255.99999999900007, 250.0),
          svg_path.Point(255.99999999900007, 250.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(255.99999999900007, 250.0),
          svg_path.Point(255.99999999900007, 250.0),
          svg_path.Point(229.999999999, 224.0),
          svg_path.Point(229.999999999, 224.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(229.999999999, 224.0),
          svg_path.Point(229.999999999, 224.0),
          svg_path.Point(255.99999999900007, 200.0),
          svg_path.Point(255.99999999900007, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(255.99999999900007, 200.0),
          svg_path.Point(255.99999999900007, 200.0),
          svg_path.Point(255.99999999900007, 100.0),
          svg_path.Point(255.99999999900007, 100.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(255.99999999900007, 100.0),
          svg_path.Point(255.99999999900007, 100.0),
          svg_path.Point(299.999999999, 100.0),
          svg_path.Point(299.999999999, 100.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(256.0, 150.0),
          svg_path.Point(256.0, 150.0),
          svg_path.Point(256.0, 300.0),
          svg_path.Point(256.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(256.0, 300.0),
          svg_path.Point(256.0, 300.0),
          svg_path.Point(200.0, 300.0),
          svg_path.Point(200.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 300.0),
          svg_path.Point(200.0, 300.0),
          svg_path.Point(200.0, 150.0),
          svg_path.Point(200.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 150.0),
          svg_path.Point(200.0, 150.0),
          svg_path.Point(256.0, 150.0),
          svg_path.Point(256.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.difference_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 40")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(300.000000001, 100.0),
          svg_path.Point(300.000000001, 100.0),
          svg_path.Point(300.000000001, 350.0),
          svg_path.Point(300.000000001, 350.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.000000001, 350.0),
          svg_path.Point(300.000000001, 350.0),
          svg_path.Point(256.00000000100005, 350.0),
          svg_path.Point(256.00000000100005, 350.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(256.00000000100005, 350.0),
          svg_path.Point(256.00000000100005, 350.0),
          svg_path.Point(256.00000000100005, 250.0),
          svg_path.Point(256.00000000100005, 250.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(256.00000000100005, 250.0),
          svg_path.Point(256.00000000100005, 250.0),
          svg_path.Point(230.000000001, 224.0),
          svg_path.Point(230.000000001, 224.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(230.000000001, 224.0),
          svg_path.Point(230.000000001, 224.0),
          svg_path.Point(256.00000000100005, 200.0),
          svg_path.Point(256.00000000100005, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(256.00000000100005, 200.0),
          svg_path.Point(256.00000000100005, 200.0),
          svg_path.Point(256.00000000100005, 100.0),
          svg_path.Point(256.00000000100005, 100.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(256.00000000100005, 100.0),
          svg_path.Point(256.00000000100005, 100.0),
          svg_path.Point(300.000000001, 100.0),
          svg_path.Point(300.000000001, 100.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(256.0, 150.0),
          svg_path.Point(256.0, 150.0),
          svg_path.Point(256.0, 300.0),
          svg_path.Point(256.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(256.0, 300.0),
          svg_path.Point(256.0, 300.0),
          svg_path.Point(200.0, 300.0),
          svg_path.Point(200.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 300.0),
          svg_path.Point(200.0, 300.0),
          svg_path.Point(200.0, 150.0),
          svg_path.Point(200.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 150.0),
          svg_path.Point(200.0, 150.0),
          svg_path.Point(256.0, 150.0),
          svg_path.Point(256.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.difference_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 41")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(50.0, 100.0),
          svg_path.Point(50.0, 100.0),
          svg_path.Point(50.0, 50.0),
          svg_path.Point(50.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(50.0, 50.0),
          svg_path.Point(50.0, 50.0),
          svg_path.Point(200.0, 50.0),
          svg_path.Point(200.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 50.0),
          svg_path.Point(200.0, 50.0),
          svg_path.Point(200.0, 100.0),
          svg_path.Point(200.0, 100.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 100.0),
          svg_path.Point(200.0, 100.0),
          svg_path.Point(50.0, 100.0),
          svg_path.Point(50.0, 100.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(70.0, 100.0),
          svg_path.Point(70.0, 100.0),
          svg_path.Point(70.0, 50.0),
          svg_path.Point(70.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(70.0, 50.0),
          svg_path.Point(70.0, 50.0),
          svg_path.Point(220.0, 50.0),
          svg_path.Point(220.0, 50.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(220.0, 50.0),
          svg_path.Point(220.0, 50.0),
          svg_path.Point(220.0, 100.0),
          svg_path.Point(220.0, 100.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(220.0, 100.0),
          svg_path.Point(220.0, 100.0),
          svg_path.Point(70.0, 100.0),
          svg_path.Point(70.0, 100.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 42")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(50.0, 250.0),
          svg_path.Point(50.0, 250.0),
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(50.0, 150.0),
          svg_path.Point(50.0, 150.0),
          svg_path.Point(100.0, 150.0),
          svg_path.Point(100.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(100.0, 150.0),
          svg_path.Point(100.0, 150.0),
          svg_path.Point(100.0, 250.0),
          svg_path.Point(100.0, 250.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(100.0, 250.0),
          svg_path.Point(100.0, 250.0),
          svg_path.Point(50.0, 250.0),
          svg_path.Point(50.0, 250.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(50.0, 275.0),
          svg_path.Point(50.0, 275.0),
          svg_path.Point(50.0, 175.0),
          svg_path.Point(50.0, 175.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(50.0, 175.0),
          svg_path.Point(50.0, 175.0),
          svg_path.Point(100.0, 175.0),
          svg_path.Point(100.0, 175.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(100.0, 175.0),
          svg_path.Point(100.0, 175.0),
          svg_path.Point(100.0, 275.0),
          svg_path.Point(100.0, 275.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(100.0, 275.0),
          svg_path.Point(100.0, 275.0),
          svg_path.Point(50.0, 275.0),
          svg_path.Point(50.0, 275.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 45")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(431.90000000000003, 479.99999999999994),
          svg_path.Point(431.90000000000003, 479.99999999999994),
          svg_path.Point(128.00000000000003, 370.0),
          svg_path.Point(128.00000000000003, 370.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(128.00000000000003, 370.0),
          svg_path.Point(128.00000000000003, 370.0),
          svg_path.Point(80.00000000000003, 479.99999999999994),
          svg_path.Point(80.00000000000003, 479.99999999999994),
        ),
        svg_path.CubicBezier(
          svg_path.Point(80.00000000000003, 479.99999999999994),
          svg_path.Point(80.00000000000003, 479.99999999999994),
          svg_path.Point(431.90000000000003, 479.99999999999994),
          svg_path.Point(431.90000000000003, 479.99999999999994),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(400.0, 480.0),
          svg_path.Point(400.0, 480.0),
          svg_path.Point(140.0, 480.0),
          svg_path.Point(140.0, 480.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(140.0, 480.0),
          svg_path.Point(130.0, 480.0),
          svg_path.Point(300.0, 300.0),
          svg_path.Point(300.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.0, 300.0),
          svg_path.Point(300.0, 300.0),
          svg_path.Point(410.0, 480.0),
          svg_path.Point(400.0, 480.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 46")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(431.90000000000003, 479.99999999999994),
          svg_path.Point(431.90000000000003, 479.99999999999994),
          svg_path.Point(128.00000000000003, 370.0),
          svg_path.Point(128.00000000000003, 370.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(128.00000000000003, 370.0),
          svg_path.Point(128.00000000000003, 370.0),
          svg_path.Point(80.00000000000003, 479.99999999999994),
          svg_path.Point(80.00000000000003, 479.99999999999994),
        ),
        svg_path.CubicBezier(
          svg_path.Point(80.00000000000003, 479.99999999999994),
          svg_path.Point(80.00000000000003, 479.99999999999994),
          svg_path.Point(431.90000000000003, 479.99999999999994),
          svg_path.Point(431.90000000000003, 479.99999999999994),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(400.0, 480.0),
          svg_path.Point(400.0, 480.0),
          svg_path.Point(140.0, 480.0),
          svg_path.Point(140.0, 480.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(140.0, 480.0),
          svg_path.Point(130.0, 480.0),
          svg_path.Point(300.0, 300.0),
          svg_path.Point(300.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.0, 300.0),
          svg_path.Point(300.0, 300.0),
          svg_path.Point(410.0, 480.0),
          svg_path.Point(400.0, 480.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.difference_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 58")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(100.0, 220.0),
          svg_path.Point(100.0, 220.0),
          svg_path.Point(100.0, 100.0),
          svg_path.Point(100.0, 100.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(100.0, 100.0),
          svg_path.Point(100.0, 100.0),
          svg_path.Point(300.0, 100.0),
          svg_path.Point(300.0, 100.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.0, 100.0),
          svg_path.Point(300.0, 100.0),
          svg_path.Point(300.0, 220.0),
          svg_path.Point(300.0, 220.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.0, 220.0),
          svg_path.Point(300.0, 220.0),
          svg_path.Point(100.0, 220.0),
          svg_path.Point(100.0, 220.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(100.0, 220.0),
          svg_path.Point(100.0, 220.0),
          svg_path.Point(100.0, 200.0),
          svg_path.Point(100.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(100.0, 200.0),
          svg_path.Point(100.0, 200.0),
          svg_path.Point(300.0, 200.0),
          svg_path.Point(300.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.0, 200.0),
          svg_path.Point(300.0, 200.0),
          svg_path.Point(300.0, 220.0),
          svg_path.Point(300.0, 220.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.0, 220.0),
          svg_path.Point(300.0, 220.0),
          svg_path.Point(100.0, 220.0),
          svg_path.Point(100.0, 220.0),
        ),
      ])
        |> svg_path.subpath_assert_close
        |> svg_path.subpath_as_path,
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(140.0, 120.0),
          svg_path.Point(140.0, 120.0),
          svg_path.Point(140.0, 100.0),
          svg_path.Point(140.0, 100.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(140.0, 100.0),
          svg_path.Point(140.0, 100.0),
          svg_path.Point(160.0, 100.0),
          svg_path.Point(160.0, 100.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(160.0, 100.0),
          svg_path.Point(160.0, 100.0),
          svg_path.Point(160.0, 120.0),
          svg_path.Point(160.0, 120.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(160.0, 120.0),
          svg_path.Point(160.0, 120.0),
          svg_path.Point(140.0, 120.0),
          svg_path.Point(140.0, 120.0),
        ),
      ])
        |> svg_path.subpath_assert_close
        |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 59")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(352.0, 280.0),
          svg_path.Point(352.0, 280.0),
          svg_path.Point(352.0, 356.0),
          svg_path.Point(352.0, 356.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(352.0, 356.0),
          svg_path.Point(352.0, 358.2),
          svg_path.Point(350.2, 360.0),
          svg_path.Point(348.0, 360.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(348.0, 360.0),
          svg_path.Point(276.0, 360.0),
          svg_path.Point(352.0, 253.5),
          svg_path.Point(352.0, 280.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(352.0, 344.0),
          svg_path.Point(352.0, 344.0),
          svg_path.Point(352.0, 356.0),
          svg_path.Point(352.0, 356.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(352.0, 356.0),
          svg_path.Point(352.0, 358.2),
          svg_path.Point(350.2, 360.0),
          svg_path.Point(348.0, 360.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(348.0, 360.0),
          svg_path.Point(348.0, 360.0),
          svg_path.Point(232.0, 360.0),
          svg_path.Point(232.0, 360.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(232.0, 360.0),
          svg_path.Point(229.8, 360.0),
          svg_path.Point(352.0, 344.0),
          svg_path.Point(352.0, 344.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.difference_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 61")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(310.0, 170.0),
          svg_path.Point(310.0, 170.0),
          svg_path.Point(200.0, 170.0),
          svg_path.Point(200.0, 170.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 170.0),
          svg_path.Point(200.0, 170.0),
          svg_path.Point(200.0, 350.0),
          svg_path.Point(200.0, 350.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 350.0),
          svg_path.Point(200.0, 350.0),
          svg_path.Point(190.0, 350.0),
          svg_path.Point(190.0, 350.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(190.0, 350.0),
          svg_path.Point(190.0, 350.0),
          svg_path.Point(190.0, 160.0),
          svg_path.Point(190.0, 160.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(190.0, 160.0),
          svg_path.Point(190.0, 160.0),
          svg_path.Point(320.0, 160.0),
          svg_path.Point(320.0, 160.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(320.0, 160.0),
          svg_path.Point(320.0, 160.0),
          svg_path.Point(320.0, 350.0),
          svg_path.Point(320.0, 350.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(320.0, 350.0),
          svg_path.Point(320.0, 350.0),
          svg_path.Point(310.0, 350.0),
          svg_path.Point(310.0, 350.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(310.0, 350.0),
          svg_path.Point(310.0, 350.0),
          svg_path.Point(310.0, 170.0),
          svg_path.Point(310.0, 170.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(195.0, 165.0),
          svg_path.Point(195.0, 165.0),
          svg_path.Point(315.0, 165.0),
          svg_path.Point(315.0, 165.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(315.0, 165.0),
          svg_path.Point(315.0, 165.0),
          svg_path.Point(315.0, 350.0),
          svg_path.Point(315.0, 350.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(315.0, 350.0),
          svg_path.Point(315.0, 350.0),
          svg_path.Point(195.0, 350.0),
          svg_path.Point(195.0, 350.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(195.0, 350.0),
          svg_path.Point(195.0, 350.0),
          svg_path.Point(195.0, 165.0),
          svg_path.Point(195.0, 165.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 62")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(150.0, 100.0),
          svg_path.Point(150.0, 100.0),
          svg_path.Point(150.0, 150.0),
          svg_path.Point(150.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 150.0),
          svg_path.Point(150.0, 150.0),
          svg_path.Point(100.0, 150.0),
          svg_path.Point(100.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(100.0, 150.0),
          svg_path.Point(100.0, 150.0),
          svg_path.Point(100.0, 100.0),
          svg_path.Point(100.0, 100.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(100.0, 100.0),
          svg_path.Point(100.0, 100.0),
          svg_path.Point(150.0, 100.0),
          svg_path.Point(150.0, 100.0),
        ),
      ])
        |> svg_path.subpath_assert_close
        |> svg_path.subpath_as_path,
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(200.0, 150.0),
          svg_path.Point(200.0, 150.0),
          svg_path.Point(200.0, 100.0),
          svg_path.Point(200.0, 100.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 100.0),
          svg_path.Point(200.0, 100.0),
          svg_path.Point(220.0, 100.0),
          svg_path.Point(220.0, 100.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(220.0, 100.0),
          svg_path.Point(220.0, 100.0),
          svg_path.Point(220.0, 150.0),
          svg_path.Point(220.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(220.0, 150.0),
          svg_path.Point(220.0, 150.0),
          svg_path.Point(200.0, 150.0),
          svg_path.Point(200.0, 150.0),
        ),
      ])
        |> svg_path.subpath_assert_close
        |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(200.0, 100.0),
          svg_path.Point(200.0, 100.0),
          svg_path.Point(200.0, 150.0),
          svg_path.Point(200.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 150.0),
          svg_path.Point(200.0, 150.0),
          svg_path.Point(120.0, 150.0),
          svg_path.Point(120.0, 150.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(120.0, 150.0),
          svg_path.Point(120.0, 150.0),
          svg_path.Point(120.0, 100.0),
          svg_path.Point(120.0, 100.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(120.0, 100.0),
          svg_path.Point(120.0, 100.0),
          svg_path.Point(200.0, 100.0),
          svg_path.Point(200.0, 100.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 63")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(428.48408954611784, 189.03444010371618),
          svg_path.Point(407.02237431615686, 189.03444010371618),
          svg_path.Point(385.560659086196, 197.22244406442567),
          svg_path.Point(369.18465116477694, 213.5984519858447),
        ),
        svg_path.CubicBezier(
          svg_path.Point(369.18465116477694, 213.5984519858447),
          svg_path.Point(369.18465116477694, 213.5984519858447),
          svg_path.Point(209.1846511647769, 213.5984519858447),
          svg_path.Point(209.1846511647769, 213.5984519858447),
        ),
        svg_path.CubicBezier(
          svg_path.Point(209.1846511647769, 213.5984519858447),
          svg_path.Point(225.56065908619593, 197.22244406442567),
          svg_path.Point(247.02237431615688, 189.03444010371618),
          svg_path.Point(268.48408954611784, 189.03444010371618),
        ),
        svg_path.CubicBezier(
          svg_path.Point(268.48408954611784, 189.03444010371618),
          svg_path.Point(268.48408954611784, 189.03444010371618),
          svg_path.Point(428.48408954611784, 189.03444010371618),
          svg_path.Point(428.48408954611784, 189.03444010371618),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(369.18465470031083, 213.59844845031083),
          svg_path.Point(336.43263885747285, 246.35046429314883),
          svg_path.Point(336.4326388574728, 299.44530937015463),
          svg_path.Point(369.18465470031083, 332.1973252129927),
        ),
        svg_path.CubicBezier(
          svg_path.Point(369.18465470031083, 332.1973252129927),
          svg_path.Point(369.18465470031083, 332.1973252129927),
          svg_path.Point(209.1846547003108, 332.1973252129927),
          svg_path.Point(209.1846547003108, 332.1973252129927),
        ),
        svg_path.CubicBezier(
          svg_path.Point(209.1846547003108, 332.1973252129927),
          svg_path.Point(209.1846547003108, 332.1973252129927),
          svg_path.Point(176.43263885747282, 246.35046429314883),
          svg_path.Point(209.1846547003108, 213.59844845031083),
        ),
        svg_path.CubicBezier(
          svg_path.Point(209.1846547003108, 213.59844845031083),
          svg_path.Point(209.1846547003108, 213.59844845031083),
          svg_path.Point(369.18465470031083, 213.59844845031083),
          svg_path.Point(369.18465470031083, 213.59844845031083),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 64")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(150.0, 120.0),
          svg_path.Point(150.0, 120.0),
          svg_path.Point(150.0, 85.0),
          svg_path.Point(150.0, 85.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(150.0, 85.0),
          svg_path.Point(150.0, 85.0),
          svg_path.Point(178.0, 85.0),
          svg_path.Point(178.0, 85.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(178.0, 85.0),
          svg_path.Point(178.0, 85.0),
          svg_path.Point(178.0, 110.0),
          svg_path.Point(178.0, 110.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(178.0, 110.0),
          svg_path.Point(178.0, 110.0),
          svg_path.Point(315.0, 110.0),
          svg_path.Point(315.0, 110.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(315.0, 110.0),
          svg_path.Point(315.0, 110.0),
          svg_path.Point(315.0, 85.0),
          svg_path.Point(315.0, 85.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(315.0, 85.0),
          svg_path.Point(315.0, 85.0),
          svg_path.Point(342.0, 85.0),
          svg_path.Point(342.0, 85.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(342.0, 85.0),
          svg_path.Point(342.0, 85.0),
          svg_path.Point(342.0, 120.0),
          svg_path.Point(342.0, 120.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(342.0, 120.0),
          svg_path.Point(342.0, 120.0),
          svg_path.Point(150.0, 120.0),
          svg_path.Point(150.0, 120.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(350.0, 60.0),
          svg_path.Point(350.0, 60.0),
          svg_path.Point(350.0, 125.0),
          svg_path.Point(350.0, 125.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(350.0, 125.0),
          svg_path.Point(350.0, 125.0),
          svg_path.Point(315.0, 125.0),
          svg_path.Point(315.0, 125.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(315.0, 125.0),
          svg_path.Point(315.0, 125.0),
          svg_path.Point(315.0, 85.0),
          svg_path.Point(315.0, 85.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(315.0, 85.0),
          svg_path.Point(315.0, 85.0),
          svg_path.Point(178.0, 85.0),
          svg_path.Point(178.0, 85.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(178.0, 85.0),
          svg_path.Point(178.0, 85.0),
          svg_path.Point(178.0, 125.0),
          svg_path.Point(178.0, 125.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(178.0, 125.0),
          svg_path.Point(178.0, 125.0),
          svg_path.Point(140.0, 125.0),
          svg_path.Point(140.0, 125.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(140.0, 125.0),
          svg_path.Point(140.0, 125.0),
          svg_path.Point(140.0, 60.0),
          svg_path.Point(140.0, 60.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(140.0, 60.0),
          svg_path.Point(140.0, 60.0),
          svg_path.Point(350.0, 60.0),
          svg_path.Point(350.0, 60.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 65")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(91.24228100000002, 396.894),
          svg_path.Point(91.24228100000002, 396.894),
          svg_path.Point(223.670298, 396.894),
          svg_path.Point(223.670298, 396.894),
        ),
        svg_path.CubicBezier(
          svg_path.Point(223.670298, 396.894),
          svg_path.Point(198.476653, 396.894),
          svg_path.Point(178.05029800000003, 417.318074),
          svg_path.Point(178.05029800000003, 442.514),
        ),
        svg_path.CubicBezier(
          svg_path.Point(178.05029800000003, 442.514),
          svg_path.Point(178.05029800000003, 417.32035500000006),
          svg_path.Point(198.476653, 396.894),
          svg_path.Point(223.670298, 396.894),
        ),
        svg_path.CubicBezier(
          svg_path.Point(223.670298, 396.894),
          svg_path.Point(304.29611274114285, 396.894),
          svg_path.Point(362.81257416175026, 332.62336666900046),
          svg_path.Point(362.813579, 244.06928100000002),
        ),
        svg_path.CubicBezier(
          svg_path.Point(362.813579, 244.06928100000002),
          svg_path.Point(362.813579, 244.06928100000002),
          svg_path.Point(362.8135789870579, 244.06699999999998),
          svg_path.Point(362.8135789870579, 244.06699999999998),
        ),
        svg_path.CubicBezier(
          svg_path.Point(362.8135789870579, 244.06699999999998),
          svg_path.Point(362.8125741324018, 155.5160303441156),
          svg_path.Point(304.29721638772895, 91.24349322616985),
          svg_path.Point(223.672579, 91.242281),
        ),
        svg_path.CubicBezier(
          svg_path.Point(223.672579, 91.242281),
          svg_path.Point(223.67181973699346, 91.242281),
          svg_path.Point(223.6710604783168, 91.24228103709967),
          svg_path.Point(223.6703012239704, 91.24228100000002),
        ),
        svg_path.CubicBezier(
          svg_path.Point(223.6703012239704, 91.24228100000002),
          svg_path.Point(223.6703012239704, 91.24228100000002),
          svg_path.Point(223.672579, 91.24228101714786),
          svg_path.Point(223.672579, 91.24228101714786),
        ),
        svg_path.CubicBezier(
          svg_path.Point(223.672579, 91.24228101714786),
          svg_path.Point(223.6718197432842, 91.24228100573211),
          svg_path.Point(223.6710604846076, 91.24228094436644),
          svg_path.Point(223.67030122397037, 91.24228094435031),
        ),
        svg_path.CubicBezier(
          svg_path.Point(223.67030122397037, 91.24228094435031),
          svg_path.Point(198.47770283698154, 91.24104995158079),
          svg_path.Point(178.052579, 70.81744766825076),
          svg_path.Point(178.052579, 45.622281),
        ),
        svg_path.CubicBezier(
          svg_path.Point(178.052579, 45.622281),
          svg_path.Point(178.052579, 20.42678555993408),
          svg_path.Point(198.4782358954835, 0.0006981118779711169),
          svg_path.Point(223.6712874413145, 0.000000017894381658664943),
        ),
        svg_path.CubicBezier(
          svg_path.Point(223.6712874413145, 0.000000017894381658664943),
          svg_path.Point(223.67019728230278, 0.000000005963652725251903),
          svg_path.Point(223.66910713518774, -0.000000000000007105427357601002),
          svg_path.Point(223.66801700000002, -0.000000000000007105427357601002),
        ),
        svg_path.CubicBezier(
          svg_path.Point(223.66801700000002, -0.000000000000007105427357601002),
          svg_path.Point(198.47437200000002, -0.000000000000007105427357601002),
          svg_path.Point(178.04801700000002, 20.424073999999994),
          svg_path.Point(178.04801700000002, 45.622281),
        ),
        svg_path.CubicBezier(
          svg_path.Point(178.04801700000002, 45.622281),
          svg_path.Point(178.05257899995144, 70.81820673158461),
          svg_path.Point(198.47665256483947, 91.24228056483946),
          svg_path.Point(223.67029719482673, 91.24228099999996),
        ),
        svg_path.CubicBezier(
          svg_path.Point(223.67029719482673, 91.24228099999996),
          svg_path.Point(223.67029719482673, 91.24228099999996),
          svg_path.Point(91.24228100000002, 91.24228100000002),
          svg_path.Point(91.24228100000002, 91.24228100000002),
        ),
        svg_path.CubicBezier(
          svg_path.Point(91.24228100000002, 91.24228100000002),
          svg_path.Point(91.24228100000002, 91.24228100000002),
          svg_path.Point(91.24228100000002, 396.894),
          svg_path.Point(91.24228100000002, 396.894),
        ),
      ])
        |> svg_path.subpath_assert_close
        |> svg_path.subpath_as_path,
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(226.669813, 488.118033),
          svg_path.Point(226.238704, 488.129438),
          svg_path.Point(225.80531399999998, 488.13628100000005),
          svg_path.Point(225.369643, 488.13628100000005),
        ),
        svg_path.CubicBezier(
          svg_path.Point(225.369643, 488.13628100000005),
          svg_path.Point(225.369643, 488.13628100000005),
          svg_path.Point(45.62456155805048, 488.1362809442144),
          svg_path.Point(45.62456155805048, 488.1362809442144),
        ),
        svg_path.CubicBezier(
          svg_path.Point(45.62456155805048, 488.1362809442144),
          svg_path.Point(45.62380137637646, 488.1362809814047),
          svg_path.Point(45.623041190359494, 488.13628100000005),
          svg_path.Point(45.62228100000001, 488.13628100000005),
        ),
        svg_path.CubicBezier(
          svg_path.Point(45.62228100000001, 488.13628100000005),
          svg_path.Point(45.621520704695165, 488.1362810000001),
          svg_path.Point(45.62076041373866, 488.1362809814041),
          svg_path.Point(45.620000127131, 488.1362809442129),
        ),
        svg_path.CubicBezier(
          svg_path.Point(45.620000127131, 488.1362809442129),
          svg_path.Point(45.620000127131, 488.1362809442129),
          svg_path.Point(45.620000000000005, 488.1362809442129),
          svg_path.Point(45.620000000000005, 488.1362809442129),
        ),
        svg_path.CubicBezier(
          svg_path.Point(45.620000000000005, 488.1362809442129),
          svg_path.Point(20.422841592908977, 488.13504843231345),
          svg_path.Point(0.00228100000000353, 467.71144666231777),
          svg_path.Point(0.00228100000000353, 442.514),
        ),
        svg_path.CubicBezier(
          svg_path.Point(0.00228100000000353, 442.514),
          svg_path.Point(0.00228100000000353, 442.514),
          svg_path.Point(0.00228100000000353, 45.624562000000026),
          svg_path.Point(0.00228100000000353, 45.624562000000026),
        ),
        svg_path.CubicBezier(
          svg_path.Point(0.00228100000000353, 45.624562000000026),
          svg_path.Point(0.00228100000000353, 20.426355000000015),
          svg_path.Point(20.424074, 0.002281000000017741),
          svg_path.Point(45.62228100000001, 0.002281000000017741),
        ),
        svg_path.CubicBezier(
          svg_path.Point(45.62228100000001, 0.002281000000017741),
          svg_path.Point(60.516828732375274, 0.002281000000017741),
          svg_path.Point(73.74431370480866, 7.140913172069363),
          svg_path.Point(82.07040134995883, 18.183842953361133),
        ),
        svg_path.CubicBezier(
          svg_path.Point(82.07040134995883, 18.183842953361133),
          svg_path.Point(73.7445968179095, 7.139787976170702),
          svg_path.Point(60.51627029316186, -0.000000000000007105427357601002),
          svg_path.Point(45.62000000000003, -0.000000000000007105427357601002),
        ),
        svg_path.CubicBezier(
          svg_path.Point(45.62000000000003, -0.000000000000007105427357601002),
          svg_path.Point(45.62000000000003, -0.000000000000007105427357601002),
          svg_path.Point(225.28752700000004, -0.000000000000007105427357601002),
          svg_path.Point(225.28752700000004, -0.000000000000007105427357601002),
        ),
        svg_path.CubicBezier(
          svg_path.Point(225.28752700000004, -0.000000000000007105427357601002),
          svg_path.Point(225.70412903848555, -0.000000000000007105427357601002),
          svg_path.Point(226.11845904086675, 0.004544073144742401),
          svg_path.Point(226.53278457428638, 0.015899787475213575),
        ),
        svg_path.CubicBezier(
          svg_path.Point(226.53278457428638, 0.015899787475213575),
          svg_path.Point(226.53512178484004, 0.015922177834606508),
          svg_path.Point(226.53745892684609, 0.0159445820320892),
          svg_path.Point(226.53979600000002, 0.015966999999992897),
        ),
        svg_path.CubicBezier(
          svg_path.Point(226.53979600000002, 0.015966999999992897),
          svg_path.Point(226.54037366574403, 0.015982574977432662),
          svg_path.Point(226.54095132882438, 0.01599816069145474),
          svg_path.Point(226.54152898921066, 0.016013757141513225),
        ),
        svg_path.CubicBezier(
          svg_path.Point(226.54152898921066, 0.016013757141513225),
          svg_path.Point(356.4577271596976, 1.5304122584409818),
          svg_path.Point(454.0547855540279, 105.93903712072131),
          svg_path.Point(454.05586000000005, 244.067),
        ),
        svg_path.CubicBezier(
          svg_path.Point(454.05586000000005, 244.067),
          svg_path.Point(454.05586000000005, 244.067),
          svg_path.Point(454.0558599911274, 244.06928099999996),
          svg_path.Point(454.0558599911274, 244.06928099999996),
        ),
        svg_path.CubicBezier(
          svg_path.Point(454.0558599911274, 244.06928099999996),
          svg_path.Point(454.0547857967345, 382.1484845857518),
          svg_path.Point(356.51502300812484, 486.5327467293694),
          svg_path.Point(226.669813, 488.118033),
        ),
      ])
        |> svg_path.subpath_assert_close
        |> svg_path.subpath_as_path,
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(408.43586000000005, 289.687),
          svg_path.Point(433.6287447999727, 289.687),
          svg_path.Point(454.0546272946646, 269.2664394070911),
          svg_path.Point(454.05585994420665, 244.06928100000005),
        ),
        svg_path.CubicBezier(
          svg_path.Point(454.05585994420665, 244.06928100000005),
          svg_path.Point(454.0558599814021, 244.06852067101585),
          svg_path.Point(454.05585994421284, 244.06776033768233),
          svg_path.Point(454.05585994421284, 244.06699999999998),
        ),
        svg_path.CubicBezier(
          svg_path.Point(454.05585994421284, 244.06699999999998),
          svg_path.Point(454.0546274323121, 218.86984173055862),
          svg_path.Point(433.6310257311431, 198.45156200000002),
          svg_path.Point(408.43586000000005, 198.45156200000002),
        ),
        svg_path.CubicBezier(
          svg_path.Point(408.43586000000005, 198.45156200000002),
          svg_path.Point(383.23841340651484, 198.45156200000002),
          svg_path.Point(362.81481167926995, 218.87212248134233),
          svg_path.Point(362.8135790557972, 244.06699999999998),
        ),
        svg_path.CubicBezier(
          svg_path.Point(362.8135790557972, 244.06699999999998),
          svg_path.Point(362.8135790185992, 244.06776032898546),
          svg_path.Point(362.81357905578716, 244.06852066231897),
          svg_path.Point(362.81357905578716, 244.06928100000005),
        ),
        svg_path.CubicBezier(
          svg_path.Point(362.81357905578716, 244.06928100000005),
          svg_path.Point(362.8148115676867, 269.2664394070911),
          svg_path.Point(383.2384133376824, 289.687),
          svg_path.Point(408.43586000000005, 289.687),
        ),
      ])
        |> svg_path.subpath_assert_close
        |> svg_path.subpath_as_path,
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(45.620000000000005, 488.13628100000005),
          svg_path.Point(20.421793, 488.13628100000005),
          svg_path.Point(0.0, 467.71220700000003),
          svg_path.Point(0.0, 442.514),
        ),
        svg_path.CubicBezier(
          svg_path.Point(0.0, 442.514),
          svg_path.Point(0.0, 467.709926),
          svg_path.Point(20.421793, 488.13628100000005),
          svg_path.Point(45.620000000000005, 488.13628100000005),
        ),
      ])
        |> svg_path.subpath_assert_close
        |> svg_path.subpath_as_path,
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(226.5168174615896, 0.015747049574606885),
          svg_path.Point(225.57995698083076, 0.00460232418622002),
          svg_path.Point(224.63216412726047, 0.00007983746901670059),
          svg_path.Point(223.69304576270648, 0.0000010492289166958563),
        ),
        svg_path.CubicBezier(
          svg_path.Point(223.69304576270648, 0.0000010492289166958563),
          svg_path.Point(224.63213236996017, 0.00009725062803408256),
          svg_path.Point(225.57992514806625, 0.006798260775516034),
          svg_path.Point(226.5168174615896, 0.015747049574606885),
        ),
      ])
        |> svg_path.subpath_assert_close
        |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(408.43586000000005, 289.687),
          svg_path.Point(383.237653, 289.687),
          svg_path.Point(362.813579, 269.26520700000003),
          svg_path.Point(362.813579, 244.067),
        ),
        svg_path.CubicBezier(
          svg_path.Point(362.813579, 244.067),
          svg_path.Point(362.813579, 244.067),
          svg_path.Point(362.813579, 244.067),
          svg_path.Point(362.813579, 244.067),
        ),
        svg_path.CubicBezier(
          svg_path.Point(362.813579, 244.067),
          svg_path.Point(362.813579, 244.067),
          svg_path.Point(362.813579, 244.067),
          svg_path.Point(362.813579, 244.067),
        ),
        svg_path.CubicBezier(
          svg_path.Point(362.813579, 244.067),
          svg_path.Point(362.813579, 218.868793),
          svg_path.Point(383.237653, 198.449281),
          svg_path.Point(408.43586000000005, 198.449281),
        ),
        svg_path.CubicBezier(
          svg_path.Point(408.43586000000005, 198.449281),
          svg_path.Point(433.629505, 198.449281),
          svg_path.Point(454.05586000000005, 218.87107400000002),
          svg_path.Point(454.05586000000005, 244.067),
        ),
        svg_path.CubicBezier(
          svg_path.Point(454.05586000000005, 244.067),
          svg_path.Point(454.05586000000005, 244.067),
          svg_path.Point(454.05586000000005, 244.067),
          svg_path.Point(454.05586000000005, 244.067),
        ),
        svg_path.CubicBezier(
          svg_path.Point(454.05586000000005, 244.067),
          svg_path.Point(454.05586000000005, 244.067),
          svg_path.Point(454.05586000000005, 244.067),
          svg_path.Point(454.05586000000005, 244.067),
        ),
        svg_path.CubicBezier(
          svg_path.Point(454.05586000000005, 244.067),
          svg_path.Point(454.05586000000005, 269.26520700000003),
          svg_path.Point(433.63178600000003, 289.687),
          svg_path.Point(408.43586000000005, 289.687),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 68")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(200.0, 300.0),
          svg_path.Point(200.0, 300.0),
          svg_path.Point(200.0, 100.0),
          svg_path.Point(200.0, 100.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 100.0),
          svg_path.Point(200.0, 100.0),
          svg_path.Point(400.0, 100.0),
          svg_path.Point(400.0, 100.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(400.0, 100.0),
          svg_path.Point(400.0, 100.0),
          svg_path.Point(400.0, 300.0),
          svg_path.Point(400.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(400.0, 300.0),
          svg_path.Point(400.0, 300.0),
          svg_path.Point(200.0, 300.0),
          svg_path.Point(200.0, 300.0),
        ),
      ])
        |> svg_path.subpath_assert_close
        |> svg_path.subpath_as_path,
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(274.616046379547, 215.30654471841746),
          svg_path.Point(274.616046379547, 215.30654471841746),
          svg_path.Point(296.47810618021146, 202.68940186127458),
          svg_path.Point(296.47810618021146, 202.68940186127458),
        ),
        svg_path.CubicBezier(
          svg_path.Point(296.47810618021146, 202.68940186127458),
          svg_path.Point(296.47810618021146, 202.68940186127458),
          svg_path.Point(297.0266776087829, 160.32607960213838),
          svg_path.Point(297.0266776087829, 160.32607960213838),
        ),
        svg_path.CubicBezier(
          svg_path.Point(297.0266776087829, 160.32607960213838),
          svg_path.Point(297.0266776087829, 160.32607960213838),
          svg_path.Point(260.5870762798793, 181.99677727655697),
          svg_path.Point(260.5870762798793, 181.99677727655697),
        ),
        svg_path.CubicBezier(
          svg_path.Point(260.5870762798793, 181.99677727655697),
          svg_path.Point(260.5870762798793, 181.99677727655697),
          svg_path.Point(260.5870762798793, 207.20554804067655),
          svg_path.Point(260.5870762798793, 207.20554804067655),
        ),
        svg_path.CubicBezier(
          svg_path.Point(260.5870762798793, 207.20554804067655),
          svg_path.Point(260.5870762798793, 207.20554804067655),
          svg_path.Point(274.616046379547, 215.30654471841746),
          svg_path.Point(274.616046379547, 215.30654471841746),
        ),
      ])
        |> svg_path.subpath_assert_close
        |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(210.0, 290.0),
          svg_path.Point(210.0, 290.0),
          svg_path.Point(210.0, 110.0),
          svg_path.Point(210.0, 110.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(210.0, 110.0),
          svg_path.Point(210.0, 110.0),
          svg_path.Point(390.0, 110.0),
          svg_path.Point(390.0, 110.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(390.0, 110.0),
          svg_path.Point(390.0, 110.0),
          svg_path.Point(390.0, 290.0),
          svg_path.Point(390.0, 290.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(390.0, 290.0),
          svg_path.Point(390.0, 290.0),
          svg_path.Point(210.0, 290.0),
          svg_path.Point(210.0, 290.0),
        ),
      ])
        |> svg_path.subpath_assert_close
        |> svg_path.subpath_as_path,
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(296.47810618021146, 202.68940186127458),
          svg_path.Point(296.47810618021146, 202.68940186127458),
          svg_path.Point(297.0266776087829, 160.32607960213838),
          svg_path.Point(297.0266776087829, 160.32607960213838),
        ),
        svg_path.CubicBezier(
          svg_path.Point(297.0266776087829, 160.32607960213838),
          svg_path.Point(297.0266776087829, 160.32607960213838),
          svg_path.Point(260.5870762798793, 181.99677727655697),
          svg_path.Point(260.5870762798793, 181.99677727655697),
        ),
        svg_path.CubicBezier(
          svg_path.Point(260.5870762798793, 181.99677727655697),
          svg_path.Point(260.5870762798793, 181.99677727655697),
          svg_path.Point(260.5870762798793, 200.0),
          svg_path.Point(260.5870762798793, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(260.5870762798793, 200.0),
          svg_path.Point(260.5870762798793, 200.0),
          svg_path.Point(265.5870762798793, 201.0),
          svg_path.Point(265.5870762798793, 201.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(265.5870762798793, 201.0),
          svg_path.Point(265.5870762798793, 201.0),
          svg_path.Point(260.5870762798793, 202.0),
          svg_path.Point(260.5870762798793, 202.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(260.5870762798793, 202.0),
          svg_path.Point(260.5870762798793, 202.0),
          svg_path.Point(260.5870762798793, 207.20554804067655),
          svg_path.Point(260.5870762798793, 207.20554804067655),
        ),
        svg_path.CubicBezier(
          svg_path.Point(260.5870762798793, 207.20554804067655),
          svg_path.Point(260.5870762798793, 207.20554804067655),
          svg_path.Point(274.616046379547, 215.30654471841746),
          svg_path.Point(274.616046379547, 215.30654471841746),
        ),
        svg_path.CubicBezier(
          svg_path.Point(274.616046379547, 215.30654471841746),
          svg_path.Point(274.616046379547, 215.30654471841746),
          svg_path.Point(296.47810618021146, 202.68940186127458),
          svg_path.Point(296.47810618021146, 202.68940186127458),
        ),
      ])
        |> svg_path.subpath_assert_close
        |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 69")
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
          svg_path.Point(0.00000000000005684341886080802, 132.07000000000002),
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
          svg_path.Point(0.00000000000005684341886080802, 132.07000000000002),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 79")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(923.0174999999999, 265.80499999999995),
          svg_path.Point(944.3699999999999, 289.30999999999995),
          svg_path.Point(956.29, 320.10999999999996),
          svg_path.Point(956.29, 351.86999999999995),
        ),
        svg_path.CubicBezier(
          svg_path.Point(956.29, 351.86999999999995),
          svg_path.Point(956.29, 383.6574999999999),
          svg_path.Point(944.3499999999999, 414.48499999999996),
          svg_path.Point(922.9625, 437.99499999999995),
        ),
        svg_path.CubicBezier(
          svg_path.Point(922.9625, 437.99499999999995),
          svg_path.Point(922.9625, 437.99499999999995),
          svg_path.Point(911.15, 427.24499999999995),
          svg_path.Point(911.15, 427.24499999999995),
        ),
        svg_path.CubicBezier(
          svg_path.Point(911.15, 427.24499999999995),
          svg_path.Point(929.95, 406.5775),
          svg_path.Point(940.29, 379.80749999999995),
          svg_path.Point(940.29, 351.86999999999995),
        ),
        svg_path.CubicBezier(
          svg_path.Point(940.29, 351.86999999999995),
          svg_path.Point(940.29, 323.9625),
          svg_path.Point(929.97, 297.2149999999999),
          svg_path.Point(911.2025, 276.55499999999995),
        ),
        svg_path.CubicBezier(
          svg_path.Point(911.2025, 276.55499999999995),
          svg_path.Point(911.2025, 276.55499999999995),
          svg_path.Point(923.0174999999999, 265.80499999999995),
          svg_path.Point(923.0174999999999, 265.80499999999995),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(940.29, 351.92499999999995),
          svg_path.Point(940.29, 351.92499999999995),
          svg_path.Point(956.29, 351.92499999999995),
          svg_path.Point(956.29, 351.92499999999995),
        ),
        svg_path.CubicBezier(
          svg_path.Point(956.29, 351.92499999999995),
          svg_path.Point(956.275, 383.69249999999994),
          svg_path.Point(944.3375, 414.49999999999994),
          svg_path.Point(922.9625, 437.99499999999995),
        ),
        svg_path.CubicBezier(
          svg_path.Point(922.9625, 437.99499999999995),
          svg_path.Point(922.9625, 437.99499999999995),
          svg_path.Point(911.15, 427.24499999999995),
          svg_path.Point(911.15, 427.24499999999995),
        ),
        svg_path.CubicBezier(
          svg_path.Point(911.15, 427.24499999999995),
          svg_path.Point(929.9375, 406.5925),
          svg_path.Point(940.275, 379.8449999999999),
          svg_path.Point(940.29, 351.92499999999995),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 88")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(239.6, 157.4),
          svg_path.Point(239.6, 157.4),
          svg_path.Point(239.6, 443.0),
          svg_path.Point(239.6, 443.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(239.6, 443.0),
          svg_path.Point(239.6, 443.0),
          svg_path.Point(273.6, 443.0),
          svg_path.Point(273.6, 443.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(273.6, 443.0),
          svg_path.Point(273.6, 443.0),
          svg_path.Point(273.6, 326.2),
          svg_path.Point(273.6, 326.2),
        ),
        svg_path.CubicBezier(
          svg_path.Point(273.6, 326.2),
          svg_path.Point(273.6, 316.8666666666667),
          svg_path.Point(274.8666666666667, 308.26666666666665),
          svg_path.Point(277.4, 300.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(277.4, 300.4),
          svg_path.Point(279.93333333333334, 292.53333333333336),
          svg_path.Point(283.73333333333335, 285.6666666666667),
          svg_path.Point(288.8, 279.8),
        ),
        svg_path.CubicBezier(
          svg_path.Point(288.8, 279.8),
          svg_path.Point(293.8666666666667, 273.93333333333334),
          svg_path.Point(300.2, 269.4),
          svg_path.Point(307.8, 266.2),
        ),
        svg_path.CubicBezier(
          svg_path.Point(307.8, 266.2),
          svg_path.Point(315.4, 263.0),
          svg_path.Point(324.4, 261.4),
          svg_path.Point(334.8, 261.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(334.8, 261.4),
          svg_path.Point(347.8666666666667, 261.4),
          svg_path.Point(358.1333333333333, 265.1333333333333),
          svg_path.Point(365.6, 272.6),
        ),
        svg_path.CubicBezier(
          svg_path.Point(365.6, 272.6),
          svg_path.Point(373.06666666666666, 280.06666666666666),
          svg_path.Point(376.8, 290.2),
          svg_path.Point(376.8, 303.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(376.8, 303.0),
          svg_path.Point(376.8, 303.0),
          svg_path.Point(376.8, 443.0),
          svg_path.Point(376.8, 443.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(376.8, 443.0),
          svg_path.Point(376.8, 443.0),
          svg_path.Point(410.8, 443.0),
          svg_path.Point(410.8, 443.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(410.8, 443.0),
          svg_path.Point(410.8, 443.0),
          svg_path.Point(410.8, 307.0),
          svg_path.Point(410.8, 307.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(410.8, 307.0),
          svg_path.Point(410.8, 295.8),
          svg_path.Point(409.6666666666667, 285.59999999999997),
          svg_path.Point(407.4, 276.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(407.4, 276.4),
          svg_path.Point(405.1333333333333, 267.2),
          svg_path.Point(401.2, 259.26666666666665),
          svg_path.Point(395.6, 252.6),
        ),
        svg_path.CubicBezier(
          svg_path.Point(395.6, 252.6),
          svg_path.Point(390.0, 245.93333333333334),
          svg_path.Point(382.6666666666667, 240.73333333333332),
          svg_path.Point(373.6, 237.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(373.6, 237.0),
          svg_path.Point(364.53333333333336, 233.26666666666668),
          svg_path.Point(353.2, 231.4),
          svg_path.Point(339.6, 231.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(339.6, 231.4),
          svg_path.Point(333.46666666666664, 231.4),
          svg_path.Point(327.1333333333333, 232.06666666666666),
          svg_path.Point(320.6, 233.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(320.6, 233.4),
          svg_path.Point(314.06666666666666, 234.73333333333335),
          svg_path.Point(307.8, 236.8),
          svg_path.Point(301.8, 239.6),
        ),
        svg_path.CubicBezier(
          svg_path.Point(301.8, 239.6),
          svg_path.Point(295.8, 242.4),
          svg_path.Point(290.40000000000003, 246.0),
          svg_path.Point(285.6, 250.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(285.6, 250.4),
          svg_path.Point(280.8, 254.8),
          svg_path.Point(277.06666666666666, 260.2),
          svg_path.Point(274.4, 266.6),
        ),
        svg_path.CubicBezier(
          svg_path.Point(274.4, 266.6),
          svg_path.Point(274.4, 266.6),
          svg_path.Point(273.6, 266.6),
          svg_path.Point(273.6, 266.6),
        ),
        svg_path.CubicBezier(
          svg_path.Point(273.6, 266.6),
          svg_path.Point(273.6, 266.6),
          svg_path.Point(273.6, 157.4),
          svg_path.Point(273.6, 157.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(273.6, 157.4),
          svg_path.Point(273.6, 157.4),
          svg_path.Point(239.6, 157.4),
          svg_path.Point(239.6, 157.4),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(255.73, 157.4),
          svg_path.Point(246.05666666666667, 157.4),
          svg_path.Point(236.90333333333334, 159.54666666666668),
          svg_path.Point(228.27, 163.84),
        ),
        svg_path.CubicBezier(
          svg_path.Point(228.27, 163.84),
          svg_path.Point(219.52333333333334, 168.18),
          svg_path.Point(211.88333333333333, 175.69666666666666),
          svg_path.Point(205.35, 186.39),
        ),
        svg_path.CubicBezier(
          svg_path.Point(205.35, 186.39),
          svg_path.Point(200.20333333333332, 194.81),
          svg_path.Point(197.54333333333332, 202.87333333333333),
          svg_path.Point(197.37, 210.58),
        ),
        svg_path.CubicBezier(
          svg_path.Point(197.37, 210.58),
          svg_path.Point(197.19, 218.28666666666666),
          svg_path.Point(198.62666666666667, 225.64999999999998),
          svg_path.Point(201.68, 232.67),
        ),
        svg_path.CubicBezier(
          svg_path.Point(201.68, 232.67),
          svg_path.Point(204.73333333333332, 239.69),
          svg_path.Point(209.03666666666666, 246.45999999999998),
          svg_path.Point(214.59, 252.98),
        ),
        svg_path.CubicBezier(
          svg_path.Point(214.59, 252.98),
          svg_path.Point(220.13666666666666, 259.49333333333334),
          svg_path.Point(226.06666666666666, 265.77),
          svg_path.Point(232.38, 271.81),
        ),
        svg_path.CubicBezier(
          svg_path.Point(232.38, 271.81),
          svg_path.Point(238.23333333333332, 277.57666666666665),
          svg_path.Point(244.12, 283.2833333333333),
          svg_path.Point(250.04, 288.93),
        ),
        svg_path.CubicBezier(
          svg_path.Point(250.04, 288.93),
          svg_path.Point(255.96666666666667, 294.58333333333337),
          svg_path.Point(261.0, 300.16),
          svg_path.Point(265.14, 305.66),
        ),
        svg_path.CubicBezier(
          svg_path.Point(265.14, 305.66),
          svg_path.Point(269.28000000000003, 311.1533333333333),
          svg_path.Point(272.1066666666667, 316.62666666666667),
          svg_path.Point(273.62, 322.08),
        ),
        svg_path.CubicBezier(
          svg_path.Point(273.62, 322.08),
          svg_path.Point(275.12666666666667, 327.53999999999996),
          svg_path.Point(274.35333333333335, 332.7733333333333),
          svg_path.Point(271.3, 337.78),
        ),
        svg_path.CubicBezier(
          svg_path.Point(271.3, 337.78),
          svg_path.Point(268.52, 342.32666666666665),
          svg_path.Point(265.12333333333333, 345.32666666666665),
          svg_path.Point(261.11, 346.78),
        ),
        svg_path.CubicBezier(
          svg_path.Point(261.11, 346.78),
          svg_path.Point(258.15000000000003, 347.8533333333333),
          svg_path.Point(255.0066666666667, 348.39),
          svg_path.Point(251.68, 348.39),
        ),
        svg_path.CubicBezier(
          svg_path.Point(251.68, 348.39),
          svg_path.Point(250.5, 348.39),
          svg_path.Point(249.29333333333332, 348.3233333333333),
          svg_path.Point(248.06, 348.19),
        ),
        svg_path.CubicBezier(
          svg_path.Point(248.06, 348.19),
          svg_path.Point(243.38, 347.67),
          svg_path.Point(238.60999999999999, 346.3966666666667),
          svg_path.Point(233.75, 344.37),
        ),
        svg_path.CubicBezier(
          svg_path.Point(233.75, 344.37),
          svg_path.Point(228.89666666666668, 342.3433333333333),
          svg_path.Point(224.31, 340.01),
          svg_path.Point(219.99, 337.37),
        ),
        svg_path.CubicBezier(
          svg_path.Point(219.99, 337.37),
          svg_path.Point(215.21, 334.45),
          svg_path.Point(210.79999999999998, 331.05333333333334),
          svg_path.Point(206.76, 327.18),
        ),
        svg_path.CubicBezier(
          svg_path.Point(206.76, 327.18),
          svg_path.Point(202.72, 323.3066666666667),
          svg_path.Point(199.45999999999998, 319.05),
          svg_path.Point(196.98, 314.41),
        ),
        svg_path.CubicBezier(
          svg_path.Point(196.98, 314.41),
          svg_path.Point(194.5, 309.77),
          svg_path.Point(193.15666666666667, 304.8066666666667),
          svg_path.Point(192.95, 299.52),
        ),
        svg_path.CubicBezier(
          svg_path.Point(192.95, 299.52),
          svg_path.Point(192.7433333333333, 294.24),
          svg_path.Point(194.14999999999998, 288.6166666666667),
          svg_path.Point(197.17, 282.65),
        ),
        svg_path.CubicBezier(
          svg_path.Point(197.17, 282.65),
          svg_path.Point(197.17, 282.65),
          svg_path.Point(168.15, 264.92),
          svg_path.Point(168.15, 264.92),
        ),
        svg_path.CubicBezier(
          svg_path.Point(168.15, 264.92),
          svg_path.Point(162.30333333333334, 276.0333333333333),
          svg_path.Point(159.12333333333333, 286.3566666666666),
          svg_path.Point(158.61, 295.89),
        ),
        svg_path.CubicBezier(
          svg_path.Point(158.61, 295.89),
          svg_path.Point(158.09666666666666, 305.4166666666667),
          svg_path.Point(159.8, 314.26666666666665),
          svg_path.Point(163.72, 322.44),
        ),
        svg_path.CubicBezier(
          svg_path.Point(163.72, 322.44),
          svg_path.Point(167.63333333333333, 330.61333333333334),
          svg_path.Point(173.27666666666667, 338.12666666666667),
          svg_path.Point(180.65, 344.98),
        ),
        svg_path.CubicBezier(
          svg_path.Point(180.65, 344.98),
          svg_path.Point(188.03, 351.82666666666665),
          svg_path.Point(196.72666666666666, 358.31),
          svg_path.Point(206.74, 364.43),
        ),
        svg_path.CubicBezier(
          svg_path.Point(206.74, 364.43),
          svg_path.Point(214.47333333333333, 369.15666666666664),
          svg_path.Point(222.85666666666665, 372.95),
          svg_path.Point(231.89, 375.81),
        ),
        svg_path.CubicBezier(
          svg_path.Point(231.89, 375.81),
          svg_path.Point(240.45, 378.5233333333333),
          svg_path.Point(248.85333333333332, 379.88),
          svg_path.Point(257.1, 379.88),
        ),
        svg_path.CubicBezier(
          svg_path.Point(257.1, 379.88),
          svg_path.Point(257.56, 379.88),
          svg_path.Point(258.02000000000004, 379.87333333333333),
          svg_path.Point(258.48, 379.86),
        ),
        svg_path.CubicBezier(
          svg_path.Point(258.48, 379.86),
          svg_path.Point(267.1666666666667, 379.7),
          svg_path.Point(275.44666666666666, 377.65333333333336),
          svg_path.Point(283.32, 373.72),
        ),
        svg_path.CubicBezier(
          svg_path.Point(283.32, 373.72),
          svg_path.Point(291.2, 369.78000000000003),
          svg_path.Point(297.84999999999997, 363.37333333333333),
          svg_path.Point(303.27, 354.5),
        ),
        svg_path.CubicBezier(
          svg_path.Point(303.27, 354.5),
          svg_path.Point(310.2233333333333, 343.12),
          svg_path.Point(312.8, 332.50666666666666),
          svg_path.Point(311.0, 322.66),
        ),
        svg_path.CubicBezier(
          svg_path.Point(311.0, 322.66),
          svg_path.Point(309.20666666666665, 312.81333333333333),
          svg_path.Point(305.12, 303.52),
          svg_path.Point(298.74, 294.78),
        ),
        svg_path.CubicBezier(
          svg_path.Point(298.74, 294.78),
          svg_path.Point(292.36, 286.04),
          svg_path.Point(284.75333333333333, 277.6433333333333),
          svg_path.Point(275.92, 269.59),
        ),
        svg_path.CubicBezier(
          svg_path.Point(275.92, 269.59),
          svg_path.Point(267.09333333333336, 261.53666666666663),
          svg_path.Point(259.1433333333333, 253.71),
          svg_path.Point(252.07, 246.11),
        ),
        svg_path.CubicBezier(
          svg_path.Point(252.07, 246.11),
          svg_path.Point(244.99666666666667, 238.50333333333333),
          svg_path.Point(239.79666666666668, 231.03),
          svg_path.Point(236.47, 223.69),
        ),
        svg_path.CubicBezier(
          svg_path.Point(236.47, 223.69),
          svg_path.Point(233.14333333333332, 216.34333333333333),
          svg_path.Point(233.77333333333334, 208.91666666666666),
          svg_path.Point(238.36, 201.41),
        ),
        svg_path.CubicBezier(
          svg_path.Point(238.36, 201.41),
          svg_path.Point(241.69333333333336, 195.95),
          svg_path.Point(245.80333333333334, 192.29),
          svg_path.Point(250.69, 190.43),
        ),
        svg_path.CubicBezier(
          svg_path.Point(250.69, 190.43),
          svg_path.Point(254.17, 189.10333333333332),
          svg_path.Point(257.76, 188.44),
          svg_path.Point(261.46, 188.44),
        ),
        svg_path.CubicBezier(
          svg_path.Point(261.46, 188.44),
          svg_path.Point(262.96, 188.44),
          svg_path.Point(264.4733333333333, 188.55),
          svg_path.Point(266.0, 188.77),
        ),
        svg_path.CubicBezier(
          svg_path.Point(266.0, 188.77),
          svg_path.Point(271.32666666666665, 189.51666666666665),
          svg_path.Point(276.7, 191.07999999999998),
          svg_path.Point(282.12, 193.46),
        ),
        svg_path.CubicBezier(
          svg_path.Point(282.12, 193.46),
          svg_path.Point(287.5466666666667, 195.83333333333334),
          svg_path.Point(292.5333333333333, 198.41),
          svg_path.Point(297.08, 201.19),
        ),
        svg_path.CubicBezier(
          svg_path.Point(297.08, 201.19),
          svg_path.Point(303.0, 204.80333333333334),
          svg_path.Point(308.4, 208.88333333333335),
          svg_path.Point(313.28, 213.43),
        ),
        svg_path.CubicBezier(
          svg_path.Point(313.28, 213.43),
          svg_path.Point(318.16, 217.97),
          svg_path.Point(322.02000000000004, 222.90666666666667),
          svg_path.Point(324.86, 228.24),
        ),
        svg_path.CubicBezier(
          svg_path.Point(324.86, 228.24),
          svg_path.Point(327.7, 233.56666666666666),
          svg_path.Point(329.13, 239.28333333333333),
          svg_path.Point(329.15, 245.39),
        ),
        svg_path.CubicBezier(
          svg_path.Point(329.15, 245.39),
          svg_path.Point(329.17, 251.48999999999998),
          svg_path.Point(327.3466666666667, 257.7966666666667),
          svg_path.Point(323.68, 264.31),
        ),
        svg_path.CubicBezier(
          svg_path.Point(323.68, 264.31),
          svg_path.Point(323.68, 264.31),
          svg_path.Point(352.69, 282.04),
          svg_path.Point(352.69, 282.04),
        ),
        svg_path.CubicBezier(
          svg_path.Point(352.69, 282.04),
          svg_path.Point(358.90999999999997, 270.83333333333337),
          svg_path.Point(362.3, 260.17),
          svg_path.Point(362.86, 250.05),
        ),
        svg_path.CubicBezier(
          svg_path.Point(362.86, 250.05),
          svg_path.Point(363.42, 239.92333333333335),
          svg_path.Point(361.7133333333333, 230.44),
          svg_path.Point(357.74, 221.6),
        ),
        svg_path.CubicBezier(
          svg_path.Point(357.74, 221.6),
          svg_path.Point(353.76, 212.76666666666665),
          svg_path.Point(347.96, 204.61666666666667),
          svg_path.Point(340.34, 197.15),
        ),
        svg_path.CubicBezier(
          svg_path.Point(340.34, 197.15),
          svg_path.Point(332.7133333333333, 189.67666666666668),
          svg_path.Point(324.00666666666666, 182.95),
          svg_path.Point(314.22, 176.97),
        ),
        svg_path.CubicBezier(
          svg_path.Point(314.22, 176.97),
          svg_path.Point(305.3466666666667, 171.55),
          svg_path.Point(295.8933333333334, 166.94666666666666),
          svg_path.Point(285.86, 163.16),
        ),
        svg_path.CubicBezier(
          svg_path.Point(285.86, 163.16),
          svg_path.Point(275.8333333333333, 159.38),
          svg_path.Point(265.91333333333336, 157.46),
          svg_path.Point(256.1, 157.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(256.1, 157.4),
          svg_path.Point(255.98, 157.4),
          svg_path.Point(255.85666666666665, 157.4),
          svg_path.Point(255.73, 157.4),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 89")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(239.6, 157.4),
          svg_path.Point(239.6, 157.4),
          svg_path.Point(239.6, 443.0),
          svg_path.Point(239.6, 443.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(239.6, 443.0),
          svg_path.Point(239.6, 443.0),
          svg_path.Point(273.6, 443.0),
          svg_path.Point(273.6, 443.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(273.6, 443.0),
          svg_path.Point(273.6, 443.0),
          svg_path.Point(273.6, 326.2),
          svg_path.Point(273.6, 326.2),
        ),
        svg_path.CubicBezier(
          svg_path.Point(273.6, 326.2),
          svg_path.Point(273.6, 316.8666666666667),
          svg_path.Point(274.8666666666667, 308.26666666666665),
          svg_path.Point(277.4, 300.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(277.4, 300.4),
          svg_path.Point(279.93333333333334, 292.53333333333336),
          svg_path.Point(283.73333333333335, 285.6666666666667),
          svg_path.Point(288.8, 279.8),
        ),
        svg_path.CubicBezier(
          svg_path.Point(288.8, 279.8),
          svg_path.Point(293.8666666666667, 273.93333333333334),
          svg_path.Point(300.2, 269.4),
          svg_path.Point(307.8, 266.2),
        ),
        svg_path.CubicBezier(
          svg_path.Point(307.8, 266.2),
          svg_path.Point(315.4, 263.0),
          svg_path.Point(324.4, 261.4),
          svg_path.Point(334.8, 261.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(334.8, 261.4),
          svg_path.Point(347.8666666666667, 261.4),
          svg_path.Point(358.1333333333333, 265.1333333333333),
          svg_path.Point(365.6, 272.6),
        ),
        svg_path.CubicBezier(
          svg_path.Point(365.6, 272.6),
          svg_path.Point(373.06666666666666, 280.06666666666666),
          svg_path.Point(376.8, 290.2),
          svg_path.Point(376.8, 303.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(376.8, 303.0),
          svg_path.Point(376.8, 303.0),
          svg_path.Point(376.8, 443.0),
          svg_path.Point(376.8, 443.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(376.8, 443.0),
          svg_path.Point(376.8, 443.0),
          svg_path.Point(410.8, 443.0),
          svg_path.Point(410.8, 443.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(410.8, 443.0),
          svg_path.Point(410.8, 443.0),
          svg_path.Point(410.8, 307.0),
          svg_path.Point(410.8, 307.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(410.8, 307.0),
          svg_path.Point(410.8, 295.8),
          svg_path.Point(409.6666666666667, 285.59999999999997),
          svg_path.Point(407.4, 276.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(407.4, 276.4),
          svg_path.Point(405.1333333333333, 267.2),
          svg_path.Point(401.2, 259.26666666666665),
          svg_path.Point(395.6, 252.6),
        ),
        svg_path.CubicBezier(
          svg_path.Point(395.6, 252.6),
          svg_path.Point(390.0, 245.93333333333334),
          svg_path.Point(382.6666666666667, 240.73333333333332),
          svg_path.Point(373.6, 237.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(373.6, 237.0),
          svg_path.Point(364.53333333333336, 233.26666666666668),
          svg_path.Point(353.2, 231.4),
          svg_path.Point(339.6, 231.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(339.6, 231.4),
          svg_path.Point(333.46666666666664, 231.4),
          svg_path.Point(327.1333333333333, 232.06666666666666),
          svg_path.Point(320.6, 233.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(320.6, 233.4),
          svg_path.Point(314.06666666666666, 234.73333333333335),
          svg_path.Point(307.8, 236.8),
          svg_path.Point(301.8, 239.6),
        ),
        svg_path.CubicBezier(
          svg_path.Point(301.8, 239.6),
          svg_path.Point(295.8, 242.4),
          svg_path.Point(290.40000000000003, 246.0),
          svg_path.Point(285.6, 250.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(285.6, 250.4),
          svg_path.Point(280.8, 254.8),
          svg_path.Point(277.06666666666666, 260.2),
          svg_path.Point(274.4, 266.6),
        ),
        svg_path.CubicBezier(
          svg_path.Point(274.4, 266.6),
          svg_path.Point(274.4, 266.6),
          svg_path.Point(273.6, 266.6),
          svg_path.Point(273.6, 266.6),
        ),
        svg_path.CubicBezier(
          svg_path.Point(273.6, 266.6),
          svg_path.Point(273.6, 266.6),
          svg_path.Point(273.6, 157.4),
          svg_path.Point(273.6, 157.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(273.6, 157.4),
          svg_path.Point(273.6, 157.4),
          svg_path.Point(239.6, 157.4),
          svg_path.Point(239.6, 157.4),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(255.73, 157.4),
          svg_path.Point(246.05666666666667, 157.4),
          svg_path.Point(236.90333333333334, 159.54666666666668),
          svg_path.Point(228.27, 163.84),
        ),
        svg_path.CubicBezier(
          svg_path.Point(228.27, 163.84),
          svg_path.Point(219.52333333333334, 168.18),
          svg_path.Point(211.88333333333333, 175.69666666666666),
          svg_path.Point(205.35, 186.39),
        ),
        svg_path.CubicBezier(
          svg_path.Point(205.35, 186.39),
          svg_path.Point(200.20333333333332, 194.81),
          svg_path.Point(197.54333333333332, 202.87333333333333),
          svg_path.Point(197.37, 210.58),
        ),
        svg_path.CubicBezier(
          svg_path.Point(197.37, 210.58),
          svg_path.Point(197.19, 218.28666666666666),
          svg_path.Point(198.62666666666667, 225.64999999999998),
          svg_path.Point(201.68, 232.67),
        ),
        svg_path.CubicBezier(
          svg_path.Point(201.68, 232.67),
          svg_path.Point(204.73333333333332, 239.69),
          svg_path.Point(209.03666666666666, 246.45999999999998),
          svg_path.Point(214.59, 252.98),
        ),
        svg_path.CubicBezier(
          svg_path.Point(214.59, 252.98),
          svg_path.Point(220.13666666666666, 259.49333333333334),
          svg_path.Point(226.06666666666666, 265.77),
          svg_path.Point(232.38, 271.81),
        ),
        svg_path.CubicBezier(
          svg_path.Point(232.38, 271.81),
          svg_path.Point(238.23333333333332, 277.57666666666665),
          svg_path.Point(244.12, 283.2833333333333),
          svg_path.Point(250.04, 288.93),
        ),
        svg_path.CubicBezier(
          svg_path.Point(250.04, 288.93),
          svg_path.Point(255.96666666666667, 294.58333333333337),
          svg_path.Point(261.0, 300.16),
          svg_path.Point(265.14, 305.66),
        ),
        svg_path.CubicBezier(
          svg_path.Point(265.14, 305.66),
          svg_path.Point(269.28000000000003, 311.1533333333333),
          svg_path.Point(272.1066666666667, 316.62666666666667),
          svg_path.Point(273.62, 322.08),
        ),
        svg_path.CubicBezier(
          svg_path.Point(273.62, 322.08),
          svg_path.Point(275.12666666666667, 327.53999999999996),
          svg_path.Point(274.35333333333335, 332.7733333333333),
          svg_path.Point(271.3, 337.78),
        ),
        svg_path.CubicBezier(
          svg_path.Point(271.3, 337.78),
          svg_path.Point(268.52, 342.32666666666665),
          svg_path.Point(265.12333333333333, 345.32666666666665),
          svg_path.Point(261.11, 346.78),
        ),
        svg_path.CubicBezier(
          svg_path.Point(261.11, 346.78),
          svg_path.Point(258.15000000000003, 347.8533333333333),
          svg_path.Point(255.0066666666667, 348.39),
          svg_path.Point(251.68, 348.39),
        ),
        svg_path.CubicBezier(
          svg_path.Point(251.68, 348.39),
          svg_path.Point(250.5, 348.39),
          svg_path.Point(249.29333333333332, 348.3233333333333),
          svg_path.Point(248.06, 348.19),
        ),
        svg_path.CubicBezier(
          svg_path.Point(248.06, 348.19),
          svg_path.Point(243.38, 347.67),
          svg_path.Point(238.60999999999999, 346.3966666666667),
          svg_path.Point(233.75, 344.37),
        ),
        svg_path.CubicBezier(
          svg_path.Point(233.75, 344.37),
          svg_path.Point(228.89666666666668, 342.3433333333333),
          svg_path.Point(224.31, 340.01),
          svg_path.Point(219.99, 337.37),
        ),
        svg_path.CubicBezier(
          svg_path.Point(219.99, 337.37),
          svg_path.Point(215.21, 334.45),
          svg_path.Point(210.79999999999998, 331.05333333333334),
          svg_path.Point(206.76, 327.18),
        ),
        svg_path.CubicBezier(
          svg_path.Point(206.76, 327.18),
          svg_path.Point(202.72, 323.3066666666667),
          svg_path.Point(199.45999999999998, 319.05),
          svg_path.Point(196.98, 314.41),
        ),
        svg_path.CubicBezier(
          svg_path.Point(196.98, 314.41),
          svg_path.Point(194.5, 309.77),
          svg_path.Point(193.15666666666667, 304.8066666666667),
          svg_path.Point(192.95, 299.52),
        ),
        svg_path.CubicBezier(
          svg_path.Point(192.95, 299.52),
          svg_path.Point(192.7433333333333, 294.24),
          svg_path.Point(194.14999999999998, 288.6166666666667),
          svg_path.Point(197.17, 282.65),
        ),
        svg_path.CubicBezier(
          svg_path.Point(197.17, 282.65),
          svg_path.Point(197.17, 282.65),
          svg_path.Point(168.15, 264.92),
          svg_path.Point(168.15, 264.92),
        ),
        svg_path.CubicBezier(
          svg_path.Point(168.15, 264.92),
          svg_path.Point(162.30333333333334, 276.0333333333333),
          svg_path.Point(159.12333333333333, 286.3566666666666),
          svg_path.Point(158.61, 295.89),
        ),
        svg_path.CubicBezier(
          svg_path.Point(158.61, 295.89),
          svg_path.Point(158.09666666666666, 305.4166666666667),
          svg_path.Point(159.8, 314.26666666666665),
          svg_path.Point(163.72, 322.44),
        ),
        svg_path.CubicBezier(
          svg_path.Point(163.72, 322.44),
          svg_path.Point(167.63333333333333, 330.61333333333334),
          svg_path.Point(173.27666666666667, 338.12666666666667),
          svg_path.Point(180.65, 344.98),
        ),
        svg_path.CubicBezier(
          svg_path.Point(180.65, 344.98),
          svg_path.Point(188.03, 351.82666666666665),
          svg_path.Point(196.72666666666666, 358.31),
          svg_path.Point(206.74, 364.43),
        ),
        svg_path.CubicBezier(
          svg_path.Point(206.74, 364.43),
          svg_path.Point(214.47333333333333, 369.15666666666664),
          svg_path.Point(222.85666666666665, 372.95),
          svg_path.Point(231.89, 375.81),
        ),
        svg_path.CubicBezier(
          svg_path.Point(231.89, 375.81),
          svg_path.Point(240.45, 378.5233333333333),
          svg_path.Point(248.85333333333332, 379.88),
          svg_path.Point(257.1, 379.88),
        ),
        svg_path.CubicBezier(
          svg_path.Point(257.1, 379.88),
          svg_path.Point(257.56, 379.88),
          svg_path.Point(258.02000000000004, 379.87333333333333),
          svg_path.Point(258.48, 379.86),
        ),
        svg_path.CubicBezier(
          svg_path.Point(258.48, 379.86),
          svg_path.Point(267.1666666666667, 379.7),
          svg_path.Point(275.44666666666666, 377.65333333333336),
          svg_path.Point(283.32, 373.72),
        ),
        svg_path.CubicBezier(
          svg_path.Point(283.32, 373.72),
          svg_path.Point(291.2, 369.78000000000003),
          svg_path.Point(297.84999999999997, 363.37333333333333),
          svg_path.Point(303.27, 354.5),
        ),
        svg_path.CubicBezier(
          svg_path.Point(303.27, 354.5),
          svg_path.Point(310.2233333333333, 343.12),
          svg_path.Point(312.8, 332.50666666666666),
          svg_path.Point(311.0, 322.66),
        ),
        svg_path.CubicBezier(
          svg_path.Point(311.0, 322.66),
          svg_path.Point(309.20666666666665, 312.81333333333333),
          svg_path.Point(305.12, 303.52),
          svg_path.Point(298.74, 294.78),
        ),
        svg_path.CubicBezier(
          svg_path.Point(298.74, 294.78),
          svg_path.Point(292.36, 286.04),
          svg_path.Point(284.75333333333333, 277.6433333333333),
          svg_path.Point(275.92, 269.59),
        ),
        svg_path.CubicBezier(
          svg_path.Point(275.92, 269.59),
          svg_path.Point(267.09333333333336, 261.53666666666663),
          svg_path.Point(259.1433333333333, 253.71),
          svg_path.Point(252.07, 246.11),
        ),
        svg_path.CubicBezier(
          svg_path.Point(252.07, 246.11),
          svg_path.Point(244.99666666666667, 238.50333333333333),
          svg_path.Point(239.79666666666668, 231.03),
          svg_path.Point(236.47, 223.69),
        ),
        svg_path.CubicBezier(
          svg_path.Point(236.47, 223.69),
          svg_path.Point(233.14333333333332, 216.34333333333333),
          svg_path.Point(233.77333333333334, 208.91666666666666),
          svg_path.Point(238.36, 201.41),
        ),
        svg_path.CubicBezier(
          svg_path.Point(238.36, 201.41),
          svg_path.Point(241.69333333333336, 195.95),
          svg_path.Point(245.80333333333334, 192.29),
          svg_path.Point(250.69, 190.43),
        ),
        svg_path.CubicBezier(
          svg_path.Point(250.69, 190.43),
          svg_path.Point(254.17, 189.10333333333332),
          svg_path.Point(257.76, 188.44),
          svg_path.Point(261.46, 188.44),
        ),
        svg_path.CubicBezier(
          svg_path.Point(261.46, 188.44),
          svg_path.Point(262.96, 188.44),
          svg_path.Point(264.4733333333333, 188.55),
          svg_path.Point(266.0, 188.77),
        ),
        svg_path.CubicBezier(
          svg_path.Point(266.0, 188.77),
          svg_path.Point(271.32666666666665, 189.51666666666665),
          svg_path.Point(276.7, 191.07999999999998),
          svg_path.Point(282.12, 193.46),
        ),
        svg_path.CubicBezier(
          svg_path.Point(282.12, 193.46),
          svg_path.Point(287.5466666666667, 195.83333333333334),
          svg_path.Point(292.5333333333333, 198.41),
          svg_path.Point(297.08, 201.19),
        ),
        svg_path.CubicBezier(
          svg_path.Point(297.08, 201.19),
          svg_path.Point(303.0, 204.80333333333334),
          svg_path.Point(308.4, 208.88333333333335),
          svg_path.Point(313.28, 213.43),
        ),
        svg_path.CubicBezier(
          svg_path.Point(313.28, 213.43),
          svg_path.Point(318.16, 217.97),
          svg_path.Point(322.02000000000004, 222.90666666666667),
          svg_path.Point(324.86, 228.24),
        ),
        svg_path.CubicBezier(
          svg_path.Point(324.86, 228.24),
          svg_path.Point(327.7, 233.56666666666666),
          svg_path.Point(329.13, 239.28333333333333),
          svg_path.Point(329.15, 245.39),
        ),
        svg_path.CubicBezier(
          svg_path.Point(329.15, 245.39),
          svg_path.Point(329.17, 251.48999999999998),
          svg_path.Point(327.3466666666667, 257.7966666666667),
          svg_path.Point(323.68, 264.31),
        ),
        svg_path.CubicBezier(
          svg_path.Point(323.68, 264.31),
          svg_path.Point(323.68, 264.31),
          svg_path.Point(352.69, 282.04),
          svg_path.Point(352.69, 282.04),
        ),
        svg_path.CubicBezier(
          svg_path.Point(352.69, 282.04),
          svg_path.Point(358.90999999999997, 270.83333333333337),
          svg_path.Point(362.3, 260.17),
          svg_path.Point(362.86, 250.05),
        ),
        svg_path.CubicBezier(
          svg_path.Point(362.86, 250.05),
          svg_path.Point(363.42, 239.92333333333335),
          svg_path.Point(361.7133333333333, 230.44),
          svg_path.Point(357.74, 221.6),
        ),
        svg_path.CubicBezier(
          svg_path.Point(357.74, 221.6),
          svg_path.Point(353.76, 212.76666666666665),
          svg_path.Point(347.96, 204.61666666666667),
          svg_path.Point(340.34, 197.15),
        ),
        svg_path.CubicBezier(
          svg_path.Point(340.34, 197.15),
          svg_path.Point(332.7133333333333, 189.67666666666668),
          svg_path.Point(324.00666666666666, 182.95),
          svg_path.Point(314.22, 176.97),
        ),
        svg_path.CubicBezier(
          svg_path.Point(314.22, 176.97),
          svg_path.Point(305.3466666666667, 171.55),
          svg_path.Point(295.8933333333334, 166.94666666666666),
          svg_path.Point(285.86, 163.16),
        ),
        svg_path.CubicBezier(
          svg_path.Point(285.86, 163.16),
          svg_path.Point(275.8333333333333, 159.38),
          svg_path.Point(265.91333333333336, 157.46),
          svg_path.Point(256.1, 157.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(256.1, 157.4),
          svg_path.Point(255.98, 157.4),
          svg_path.Point(255.85666666666665, 157.4),
          svg_path.Point(255.73, 157.4),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.difference_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 90")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(239.6, 157.4),
          svg_path.Point(239.6, 157.4),
          svg_path.Point(239.6, 443.0),
          svg_path.Point(239.6, 443.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(239.6, 443.0),
          svg_path.Point(239.6, 443.0),
          svg_path.Point(273.6, 443.0),
          svg_path.Point(273.6, 443.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(273.6, 443.0),
          svg_path.Point(273.6, 443.0),
          svg_path.Point(273.6, 326.2),
          svg_path.Point(273.6, 326.2),
        ),
        svg_path.CubicBezier(
          svg_path.Point(273.6, 326.2),
          svg_path.Point(273.6, 316.8666666666667),
          svg_path.Point(274.8666666666667, 308.26666666666665),
          svg_path.Point(277.4, 300.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(277.4, 300.4),
          svg_path.Point(279.93333333333334, 292.53333333333336),
          svg_path.Point(283.73333333333335, 285.6666666666667),
          svg_path.Point(288.8, 279.8),
        ),
        svg_path.CubicBezier(
          svg_path.Point(288.8, 279.8),
          svg_path.Point(293.8666666666667, 273.93333333333334),
          svg_path.Point(300.2, 269.4),
          svg_path.Point(307.8, 266.2),
        ),
        svg_path.CubicBezier(
          svg_path.Point(307.8, 266.2),
          svg_path.Point(315.4, 263.0),
          svg_path.Point(324.4, 261.4),
          svg_path.Point(334.8, 261.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(334.8, 261.4),
          svg_path.Point(347.8666666666667, 261.4),
          svg_path.Point(358.1333333333333, 265.1333333333333),
          svg_path.Point(365.6, 272.6),
        ),
        svg_path.CubicBezier(
          svg_path.Point(365.6, 272.6),
          svg_path.Point(373.06666666666666, 280.06666666666666),
          svg_path.Point(376.8, 290.2),
          svg_path.Point(376.8, 303.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(376.8, 303.0),
          svg_path.Point(376.8, 303.0),
          svg_path.Point(376.8, 443.0),
          svg_path.Point(376.8, 443.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(376.8, 443.0),
          svg_path.Point(376.8, 443.0),
          svg_path.Point(410.8, 443.0),
          svg_path.Point(410.8, 443.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(410.8, 443.0),
          svg_path.Point(410.8, 443.0),
          svg_path.Point(410.8, 307.0),
          svg_path.Point(410.8, 307.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(410.8, 307.0),
          svg_path.Point(410.8, 295.8),
          svg_path.Point(409.6666666666667, 285.59999999999997),
          svg_path.Point(407.4, 276.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(407.4, 276.4),
          svg_path.Point(405.1333333333333, 267.2),
          svg_path.Point(401.2, 259.26666666666665),
          svg_path.Point(395.6, 252.6),
        ),
        svg_path.CubicBezier(
          svg_path.Point(395.6, 252.6),
          svg_path.Point(390.0, 245.93333333333334),
          svg_path.Point(382.6666666666667, 240.73333333333332),
          svg_path.Point(373.6, 237.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(373.6, 237.0),
          svg_path.Point(364.53333333333336, 233.26666666666668),
          svg_path.Point(353.2, 231.4),
          svg_path.Point(339.6, 231.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(339.6, 231.4),
          svg_path.Point(333.46666666666664, 231.4),
          svg_path.Point(327.1333333333333, 232.06666666666666),
          svg_path.Point(320.6, 233.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(320.6, 233.4),
          svg_path.Point(314.06666666666666, 234.73333333333335),
          svg_path.Point(307.8, 236.8),
          svg_path.Point(301.8, 239.6),
        ),
        svg_path.CubicBezier(
          svg_path.Point(301.8, 239.6),
          svg_path.Point(295.8, 242.4),
          svg_path.Point(290.40000000000003, 246.0),
          svg_path.Point(285.6, 250.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(285.6, 250.4),
          svg_path.Point(280.8, 254.8),
          svg_path.Point(277.06666666666666, 260.2),
          svg_path.Point(274.4, 266.6),
        ),
        svg_path.CubicBezier(
          svg_path.Point(274.4, 266.6),
          svg_path.Point(274.4, 266.6),
          svg_path.Point(273.6, 266.6),
          svg_path.Point(273.6, 266.6),
        ),
        svg_path.CubicBezier(
          svg_path.Point(273.6, 266.6),
          svg_path.Point(273.6, 266.6),
          svg_path.Point(273.6, 157.4),
          svg_path.Point(273.6, 157.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(273.6, 157.4),
          svg_path.Point(273.6, 157.4),
          svg_path.Point(239.6, 157.4),
          svg_path.Point(239.6, 157.4),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(255.73, 157.4),
          svg_path.Point(246.05666666666667, 157.4),
          svg_path.Point(236.90333333333334, 159.54666666666668),
          svg_path.Point(228.27, 163.84),
        ),
        svg_path.CubicBezier(
          svg_path.Point(228.27, 163.84),
          svg_path.Point(219.52333333333334, 168.18),
          svg_path.Point(211.88333333333333, 175.69666666666666),
          svg_path.Point(205.35, 186.39),
        ),
        svg_path.CubicBezier(
          svg_path.Point(205.35, 186.39),
          svg_path.Point(200.20333333333332, 194.81),
          svg_path.Point(197.54333333333332, 202.87333333333333),
          svg_path.Point(197.37, 210.58),
        ),
        svg_path.CubicBezier(
          svg_path.Point(197.37, 210.58),
          svg_path.Point(197.19, 218.28666666666666),
          svg_path.Point(198.62666666666667, 225.64999999999998),
          svg_path.Point(201.68, 232.67),
        ),
        svg_path.CubicBezier(
          svg_path.Point(201.68, 232.67),
          svg_path.Point(204.73333333333332, 239.69),
          svg_path.Point(209.03666666666666, 246.45999999999998),
          svg_path.Point(214.59, 252.98),
        ),
        svg_path.CubicBezier(
          svg_path.Point(214.59, 252.98),
          svg_path.Point(220.13666666666666, 259.49333333333334),
          svg_path.Point(226.06666666666666, 265.77),
          svg_path.Point(232.38, 271.81),
        ),
        svg_path.CubicBezier(
          svg_path.Point(232.38, 271.81),
          svg_path.Point(238.23333333333332, 277.57666666666665),
          svg_path.Point(244.12, 283.2833333333333),
          svg_path.Point(250.04, 288.93),
        ),
        svg_path.CubicBezier(
          svg_path.Point(250.04, 288.93),
          svg_path.Point(255.96666666666667, 294.58333333333337),
          svg_path.Point(261.0, 300.16),
          svg_path.Point(265.14, 305.66),
        ),
        svg_path.CubicBezier(
          svg_path.Point(265.14, 305.66),
          svg_path.Point(269.28000000000003, 311.1533333333333),
          svg_path.Point(272.1066666666667, 316.62666666666667),
          svg_path.Point(273.62, 322.08),
        ),
        svg_path.CubicBezier(
          svg_path.Point(273.62, 322.08),
          svg_path.Point(275.12666666666667, 327.53999999999996),
          svg_path.Point(274.35333333333335, 332.7733333333333),
          svg_path.Point(271.3, 337.78),
        ),
        svg_path.CubicBezier(
          svg_path.Point(271.3, 337.78),
          svg_path.Point(268.52, 342.32666666666665),
          svg_path.Point(265.12333333333333, 345.32666666666665),
          svg_path.Point(261.11, 346.78),
        ),
        svg_path.CubicBezier(
          svg_path.Point(261.11, 346.78),
          svg_path.Point(258.15000000000003, 347.8533333333333),
          svg_path.Point(255.0066666666667, 348.39),
          svg_path.Point(251.68, 348.39),
        ),
        svg_path.CubicBezier(
          svg_path.Point(251.68, 348.39),
          svg_path.Point(250.5, 348.39),
          svg_path.Point(249.29333333333332, 348.3233333333333),
          svg_path.Point(248.06, 348.19),
        ),
        svg_path.CubicBezier(
          svg_path.Point(248.06, 348.19),
          svg_path.Point(243.38, 347.67),
          svg_path.Point(238.60999999999999, 346.3966666666667),
          svg_path.Point(233.75, 344.37),
        ),
        svg_path.CubicBezier(
          svg_path.Point(233.75, 344.37),
          svg_path.Point(228.89666666666668, 342.3433333333333),
          svg_path.Point(224.31, 340.01),
          svg_path.Point(219.99, 337.37),
        ),
        svg_path.CubicBezier(
          svg_path.Point(219.99, 337.37),
          svg_path.Point(215.21, 334.45),
          svg_path.Point(210.79999999999998, 331.05333333333334),
          svg_path.Point(206.76, 327.18),
        ),
        svg_path.CubicBezier(
          svg_path.Point(206.76, 327.18),
          svg_path.Point(202.72, 323.3066666666667),
          svg_path.Point(199.45999999999998, 319.05),
          svg_path.Point(196.98, 314.41),
        ),
        svg_path.CubicBezier(
          svg_path.Point(196.98, 314.41),
          svg_path.Point(194.5, 309.77),
          svg_path.Point(193.15666666666667, 304.8066666666667),
          svg_path.Point(192.95, 299.52),
        ),
        svg_path.CubicBezier(
          svg_path.Point(192.95, 299.52),
          svg_path.Point(192.7433333333333, 294.24),
          svg_path.Point(194.14999999999998, 288.6166666666667),
          svg_path.Point(197.17, 282.65),
        ),
        svg_path.CubicBezier(
          svg_path.Point(197.17, 282.65),
          svg_path.Point(197.17, 282.65),
          svg_path.Point(168.15, 264.92),
          svg_path.Point(168.15, 264.92),
        ),
        svg_path.CubicBezier(
          svg_path.Point(168.15, 264.92),
          svg_path.Point(162.30333333333334, 276.0333333333333),
          svg_path.Point(159.12333333333333, 286.3566666666666),
          svg_path.Point(158.61, 295.89),
        ),
        svg_path.CubicBezier(
          svg_path.Point(158.61, 295.89),
          svg_path.Point(158.09666666666666, 305.4166666666667),
          svg_path.Point(159.8, 314.26666666666665),
          svg_path.Point(163.72, 322.44),
        ),
        svg_path.CubicBezier(
          svg_path.Point(163.72, 322.44),
          svg_path.Point(167.63333333333333, 330.61333333333334),
          svg_path.Point(173.27666666666667, 338.12666666666667),
          svg_path.Point(180.65, 344.98),
        ),
        svg_path.CubicBezier(
          svg_path.Point(180.65, 344.98),
          svg_path.Point(188.03, 351.82666666666665),
          svg_path.Point(196.72666666666666, 358.31),
          svg_path.Point(206.74, 364.43),
        ),
        svg_path.CubicBezier(
          svg_path.Point(206.74, 364.43),
          svg_path.Point(214.47333333333333, 369.15666666666664),
          svg_path.Point(222.85666666666665, 372.95),
          svg_path.Point(231.89, 375.81),
        ),
        svg_path.CubicBezier(
          svg_path.Point(231.89, 375.81),
          svg_path.Point(240.45, 378.5233333333333),
          svg_path.Point(248.85333333333332, 379.88),
          svg_path.Point(257.1, 379.88),
        ),
        svg_path.CubicBezier(
          svg_path.Point(257.1, 379.88),
          svg_path.Point(257.56, 379.88),
          svg_path.Point(258.02000000000004, 379.87333333333333),
          svg_path.Point(258.48, 379.86),
        ),
        svg_path.CubicBezier(
          svg_path.Point(258.48, 379.86),
          svg_path.Point(267.1666666666667, 379.7),
          svg_path.Point(275.44666666666666, 377.65333333333336),
          svg_path.Point(283.32, 373.72),
        ),
        svg_path.CubicBezier(
          svg_path.Point(283.32, 373.72),
          svg_path.Point(291.2, 369.78000000000003),
          svg_path.Point(297.84999999999997, 363.37333333333333),
          svg_path.Point(303.27, 354.5),
        ),
        svg_path.CubicBezier(
          svg_path.Point(303.27, 354.5),
          svg_path.Point(310.2233333333333, 343.12),
          svg_path.Point(312.8, 332.50666666666666),
          svg_path.Point(311.0, 322.66),
        ),
        svg_path.CubicBezier(
          svg_path.Point(311.0, 322.66),
          svg_path.Point(309.20666666666665, 312.81333333333333),
          svg_path.Point(305.12, 303.52),
          svg_path.Point(298.74, 294.78),
        ),
        svg_path.CubicBezier(
          svg_path.Point(298.74, 294.78),
          svg_path.Point(292.36, 286.04),
          svg_path.Point(284.75333333333333, 277.6433333333333),
          svg_path.Point(275.92, 269.59),
        ),
        svg_path.CubicBezier(
          svg_path.Point(275.92, 269.59),
          svg_path.Point(267.09333333333336, 261.53666666666663),
          svg_path.Point(259.1433333333333, 253.71),
          svg_path.Point(252.07, 246.11),
        ),
        svg_path.CubicBezier(
          svg_path.Point(252.07, 246.11),
          svg_path.Point(244.99666666666667, 238.50333333333333),
          svg_path.Point(239.79666666666668, 231.03),
          svg_path.Point(236.47, 223.69),
        ),
        svg_path.CubicBezier(
          svg_path.Point(236.47, 223.69),
          svg_path.Point(233.14333333333332, 216.34333333333333),
          svg_path.Point(233.77333333333334, 208.91666666666666),
          svg_path.Point(238.36, 201.41),
        ),
        svg_path.CubicBezier(
          svg_path.Point(238.36, 201.41),
          svg_path.Point(241.69333333333336, 195.95),
          svg_path.Point(245.80333333333334, 192.29),
          svg_path.Point(250.69, 190.43),
        ),
        svg_path.CubicBezier(
          svg_path.Point(250.69, 190.43),
          svg_path.Point(254.17, 189.10333333333332),
          svg_path.Point(257.76, 188.44),
          svg_path.Point(261.46, 188.44),
        ),
        svg_path.CubicBezier(
          svg_path.Point(261.46, 188.44),
          svg_path.Point(262.96, 188.44),
          svg_path.Point(264.4733333333333, 188.55),
          svg_path.Point(266.0, 188.77),
        ),
        svg_path.CubicBezier(
          svg_path.Point(266.0, 188.77),
          svg_path.Point(271.32666666666665, 189.51666666666665),
          svg_path.Point(276.7, 191.07999999999998),
          svg_path.Point(282.12, 193.46),
        ),
        svg_path.CubicBezier(
          svg_path.Point(282.12, 193.46),
          svg_path.Point(287.5466666666667, 195.83333333333334),
          svg_path.Point(292.5333333333333, 198.41),
          svg_path.Point(297.08, 201.19),
        ),
        svg_path.CubicBezier(
          svg_path.Point(297.08, 201.19),
          svg_path.Point(303.0, 204.80333333333334),
          svg_path.Point(308.4, 208.88333333333335),
          svg_path.Point(313.28, 213.43),
        ),
        svg_path.CubicBezier(
          svg_path.Point(313.28, 213.43),
          svg_path.Point(318.16, 217.97),
          svg_path.Point(322.02000000000004, 222.90666666666667),
          svg_path.Point(324.86, 228.24),
        ),
        svg_path.CubicBezier(
          svg_path.Point(324.86, 228.24),
          svg_path.Point(327.7, 233.56666666666666),
          svg_path.Point(329.13, 239.28333333333333),
          svg_path.Point(329.15, 245.39),
        ),
        svg_path.CubicBezier(
          svg_path.Point(329.15, 245.39),
          svg_path.Point(329.17, 251.48999999999998),
          svg_path.Point(327.3466666666667, 257.7966666666667),
          svg_path.Point(323.68, 264.31),
        ),
        svg_path.CubicBezier(
          svg_path.Point(323.68, 264.31),
          svg_path.Point(323.68, 264.31),
          svg_path.Point(352.69, 282.04),
          svg_path.Point(352.69, 282.04),
        ),
        svg_path.CubicBezier(
          svg_path.Point(352.69, 282.04),
          svg_path.Point(358.90999999999997, 270.83333333333337),
          svg_path.Point(362.3, 260.17),
          svg_path.Point(362.86, 250.05),
        ),
        svg_path.CubicBezier(
          svg_path.Point(362.86, 250.05),
          svg_path.Point(363.42, 239.92333333333335),
          svg_path.Point(361.7133333333333, 230.44),
          svg_path.Point(357.74, 221.6),
        ),
        svg_path.CubicBezier(
          svg_path.Point(357.74, 221.6),
          svg_path.Point(353.76, 212.76666666666665),
          svg_path.Point(347.96, 204.61666666666667),
          svg_path.Point(340.34, 197.15),
        ),
        svg_path.CubicBezier(
          svg_path.Point(340.34, 197.15),
          svg_path.Point(332.7133333333333, 189.67666666666668),
          svg_path.Point(324.00666666666666, 182.95),
          svg_path.Point(314.22, 176.97),
        ),
        svg_path.CubicBezier(
          svg_path.Point(314.22, 176.97),
          svg_path.Point(305.3466666666667, 171.55),
          svg_path.Point(295.8933333333334, 166.94666666666666),
          svg_path.Point(285.86, 163.16),
        ),
        svg_path.CubicBezier(
          svg_path.Point(285.86, 163.16),
          svg_path.Point(275.8333333333333, 159.38),
          svg_path.Point(265.91333333333336, 157.46),
          svg_path.Point(256.1, 157.4),
        ),
        svg_path.CubicBezier(
          svg_path.Point(256.1, 157.4),
          svg_path.Point(255.98, 157.4),
          svg_path.Point(255.85666666666665, 157.4),
          svg_path.Point(255.73, 157.4),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 103")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(276.60479999999995, 265.6776),
          svg_path.Point(277.8256, 264.8264),
          svg_path.Point(278.9504, 263.94),
          svg_path.Point(279.9632, 262.924),
        ),
        svg_path.CubicBezier(
          svg_path.Point(279.9632, 262.924),
          svg_path.Point(279.9824, 266.2264),
          svg_path.Point(287.15999999999997, 269.31440000000003),
          svg_path.Point(294.4, 269.31440000000003),
        ),
        svg_path.CubicBezier(
          svg_path.Point(294.4, 269.31440000000003),
          svg_path.Point(301.64, 269.31440000000003),
          svg_path.Point(308.81759999999997, 266.2264),
          svg_path.Point(308.8384, 262.924),
        ),
        svg_path.CubicBezier(
          svg_path.Point(308.8384, 262.924),
          svg_path.Point(309.8496, 263.94),
          svg_path.Point(310.97439999999995, 264.8264),
          svg_path.Point(312.1968, 265.6776),
        ),
        svg_path.CubicBezier(
          svg_path.Point(312.1968, 265.6776),
          svg_path.Point(309.55039999999997, 271.324),
          svg_path.Point(299.9904, 273.3128),
          svg_path.Point(294.4, 273.3128),
        ),
        svg_path.CubicBezier(
          svg_path.Point(294.4, 273.3128),
          svg_path.Point(288.8096, 273.3128),
          svg_path.Point(279.2512, 271.324),
          svg_path.Point(276.60479999999995, 265.6776),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(294.4, 273.3128),
          svg_path.Point(287.15999999999997, 273.3128),
          svg_path.Point(279.9952, 270.2088),
          svg_path.Point(279.9808, 266.9064),
        ),
        svg_path.CubicBezier(
          svg_path.Point(279.9808, 266.9064),
          svg_path.Point(279.9808, 266.9064),
          svg_path.Point(279.91999999999996, 253.31279999999998),
          svg_path.Point(279.91999999999996, 253.31279999999998),
        ),
        svg_path.CubicBezier(
          svg_path.Point(279.91999999999996, 253.31279999999998),
          svg_path.Point(289.5728, 253.31279999999998),
          svg_path.Point(299.2272, 253.31279999999998),
          svg_path.Point(308.88, 253.31279999999998),
        ),
        svg_path.CubicBezier(
          svg_path.Point(308.88, 253.31279999999998),
          svg_path.Point(308.88, 253.31279999999998),
          svg_path.Point(308.82079999999996, 266.9064),
          svg_path.Point(308.82079999999996, 266.9064),
        ),
        svg_path.CubicBezier(
          svg_path.Point(308.82079999999996, 266.9064),
          svg_path.Point(308.8059342595336, 269.9746888322623),
          svg_path.Point(302.61991607787985, 272.87171022882166),
          svg_path.Point(295.93610344888236, 273.2670371105283),
        ),
        svg_path.CubicBezier(
          svg_path.Point(295.93610344888236, 273.2670371105283),
          svg_path.Point(301.6187025235303, 272.9401923294607),
          svg_path.Point(309.784534650048, 270.8237660798976),
          svg_path.Point(312.1968, 265.6776),
        ),
        svg_path.CubicBezier(
          svg_path.Point(312.1968, 265.6776),
          svg_path.Point(320.6032, 271.5336),
          svg_path.Point(310.4, 307.188),
          svg_path.Point(294.4, 307.1864),
        ),
        svg_path.CubicBezier(
          svg_path.Point(294.4, 307.1864),
          svg_path.Point(294.4, 307.1864),
          svg_path.Point(294.4, 273.3128),
          svg_path.Point(294.4, 273.3128),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 107")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(512.0, 96.0),
          svg_path.Point(680.0, 96.0),
          svg_path.Point(736.0, 216.89),
          svg_path.Point(736.0, 337.78),
        ),
        svg_path.CubicBezier(
          svg_path.Point(736.0, 337.78),
          svg_path.Point(736.0, 359.57),
          svg_path.Point(733.66, 381.35999999999996),
          svg_path.Point(729.34, 402.7),
        ),
        svg_path.CubicBezier(
          svg_path.Point(729.34, 402.7),
          svg_path.Point(703.69, 529.3299999999999),
          svg_path.Point(607.85, 640.0),
          svg_path.Point(512.0, 640.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(512.0, 640.0),
          svg_path.Point(512.0, 640.0),
          svg_path.Point(388.0405751528448, 332.07994673131026),
          svg_path.Point(288.04, 332.0799999999999),
        ),
        svg_path.CubicBezier(
          svg_path.Point(288.04, 332.0799999999999),
          svg_path.Point(288.45767160812744, 303.6878774269481),
          svg_path.Point(292.01401143835795, 275.4005670050518),
          svg_path.Point(299.43514767699014, 248.78534185388617),
        ),
        svg_path.CubicBezier(
          svg_path.Point(299.43514767699014, 248.78534185388617),
          svg_path.Point(323.1077898156607, 163.88557985196766),
          svg_path.Point(386.10638692568807, 96.0),
          svg_path.Point(512.0, 96.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(512.0, 96.0),
          svg_path.Point(680.0, 96.0),
          svg_path.Point(736.0, 216.89),
          svg_path.Point(736.0, 337.78),
        ),
        svg_path.CubicBezier(
          svg_path.Point(736.0, 337.78),
          svg_path.Point(736.0, 488.89),
          svg_path.Point(624.0, 640.0),
          svg_path.Point(512.0, 640.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(512.0, 640.0),
          svg_path.Point(400.0, 640.0),
          svg_path.Point(288.0, 488.89),
          svg_path.Point(288.0, 337.78),
        ),
        svg_path.CubicBezier(
          svg_path.Point(288.0, 337.78),
          svg_path.Point(288.0, 335.8797902318473),
          svg_path.Point(288.01383599398065, 333.9795804636947),
          svg_path.Point(288.04172546304807, 332.07984018287976),
        ),
        svg_path.CubicBezier(
          svg_path.Point(288.04172546304807, 332.07984018287976),
          svg_path.Point(288.4585407872972, 303.6877306299307),
          svg_path.Point(292.0143508640645, 275.40048612142664),
          svg_path.Point(299.4351476773096, 248.7853418527407),
        ),
        svg_path.CubicBezier(
          svg_path.Point(299.4351476773096, 248.7853418527407),
          svg_path.Point(323.1068236079989, 163.88541993972265),
          svg_path.Point(386.10677836347935, 96.0),
          svg_path.Point(512.0, 96.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 108")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(240.0, 270.0),
          svg_path.Point(240.0, 270.0),
          svg_path.Point(250.53466323186618, 221.0057178821544),
          svg_path.Point(250.53466323186618, 221.0057178821544),
        ),
        svg_path.CubicBezier(
          svg_path.Point(250.53466323186618, 221.0057178821544),
          svg_path.Point(250.53466323186618, 221.0057178821544),
          svg_path.Point(237.67824477332854, 193.79795691566554),
          svg_path.Point(237.67824477332854, 193.79795691566554),
        ),
        svg_path.CubicBezier(
          svg_path.Point(237.67824477332854, 193.79795691566554),
          svg_path.Point(237.67824477332854, 193.79795691566554),
          svg_path.Point(320.0, 240.0),
          svg_path.Point(320.0, 240.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(320.0, 240.0),
          svg_path.Point(320.0, 240.0),
          svg_path.Point(240.0, 270.0),
          svg_path.Point(240.0, 270.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(263.31216874462405, 248.04647709671602),
          svg_path.Point(263.31216874462405, 248.04647709671602),
          svg_path.Point(230.0, 250.0),
          svg_path.Point(230.0, 250.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(230.0, 250.0),
          svg_path.Point(230.0, 250.0),
          svg_path.Point(237.6782447781314, 193.79795691339606),
          svg_path.Point(237.6782447781314, 193.79795691339606),
        ),
        svg_path.CubicBezier(
          svg_path.Point(237.6782447781314, 193.79795691339606),
          svg_path.Point(237.6782447781314, 193.79795691339606),
          svg_path.Point(263.31216874462405, 248.04647709671602),
          svg_path.Point(263.31216874462405, 248.04647709671602),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 109")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(240.0, 270.0),
          svg_path.Point(240.0, 270.0),
          svg_path.Point(250.53466323186618, 221.0057178821544),
          svg_path.Point(250.53466323186618, 221.0057178821544),
        ),
        svg_path.CubicBezier(
          svg_path.Point(250.53466323186618, 221.0057178821544),
          svg_path.Point(250.53466323186618, 221.0057178821544),
          svg_path.Point(237.67824477332854, 193.79795691566554),
          svg_path.Point(237.67824477332854, 193.79795691566554),
        ),
        svg_path.CubicBezier(
          svg_path.Point(237.67824477332854, 193.79795691566554),
          svg_path.Point(237.67824477332854, 193.79795691566554),
          svg_path.Point(320.0, 240.0),
          svg_path.Point(320.0, 240.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(320.0, 240.0),
          svg_path.Point(320.0, 240.0),
          svg_path.Point(240.0, 270.0),
          svg_path.Point(240.0, 270.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(263.31216874462405, 248.04647709671602),
          svg_path.Point(263.31216874462405, 248.04647709671602),
          svg_path.Point(230.0, 250.0),
          svg_path.Point(230.0, 250.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(230.0, 250.0),
          svg_path.Point(230.0, 250.0),
          svg_path.Point(237.6782447781314, 193.79795691339606),
          svg_path.Point(237.6782447781314, 193.79795691339606),
        ),
        svg_path.CubicBezier(
          svg_path.Point(237.6782447781314, 193.79795691339606),
          svg_path.Point(237.6782447781314, 193.79795691339606),
          svg_path.Point(263.31216874462405, 248.04647709671602),
          svg_path.Point(263.31216874462405, 248.04647709671602),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 113")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(211.76470809030513, 391.5530064242439),
          svg_path.Point(210.63405192900547, 380.26844238024336),
          svg_path.Point(215.58447413351976, 403.809885103234),
          svg_path.Point(206.28516988159765, 416.3206370377553),
        ),
        svg_path.CubicBezier(
          svg_path.Point(206.28516988159765, 416.3206370377553),
          svg_path.Point(206.28516988159765, 416.3206370377553),
          svg_path.Point(142.17355611649077, 367.3087985311291),
          svg_path.Point(142.17355611649077, 367.3087985311291),
        ),
        svg_path.CubicBezier(
          svg_path.Point(142.17355611649077, 367.3087985311291),
          svg_path.Point(142.17355611649077, 367.3087985311291),
          svg_path.Point(211.76470809030513, 391.5530064242439),
          svg_path.Point(211.76470809030513, 391.5530064242439),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(152.06363005021922, 397.5347520600572),
          svg_path.Point(152.06363005021922, 397.5347520600572),
          svg_path.Point(218.65631922872535, 332.74836297575644),
          svg_path.Point(218.65631922872535, 332.74836297575644),
        ),
        svg_path.CubicBezier(
          svg_path.Point(218.65631922872535, 332.74836297575644),
          svg_path.Point(209.07530645304462, 342.84627507910966),
          svg_path.Point(209.87329570856824, 372.67568112776195),
          svg_path.Point(211.76470809030513, 391.55300642424385),
        ),
        svg_path.CubicBezier(
          svg_path.Point(211.76470809030513, 391.55300642424385),
          svg_path.Point(211.76470809030513, 391.55300642424385),
          svg_path.Point(152.06363005021922, 397.5347520600572),
          svg_path.Point(152.06363005021922, 397.5347520600572),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 116")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(260.5630488345416, 240.11728335016855),
          svg_path.Point(260.5630488345416, 240.11728335016855),
          svg_path.Point(230.82205831331396, 236.1805613638536),
          svg_path.Point(230.82205831331396, 236.1805613638536),
        ),
        svg_path.CubicBezier(
          svg_path.Point(230.82205831331396, 236.1805613638536),
          svg_path.Point(230.82205831331396, 236.1805613638536),
          svg_path.Point(300.041224753361, 200.0),
          svg_path.Point(300.041224753361, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.041224753361, 200.0),
          svg_path.Point(300.041224753361, 200.0),
          svg_path.Point(300.0, 300.0),
          svg_path.Point(300.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.0, 300.0),
          svg_path.Point(300.0, 300.0),
          svg_path.Point(260.5630488345416, 240.11728335016855),
          svg_path.Point(260.5630488345416, 240.11728335016855),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(290.30323645974596, 244.0538990495128),
          svg_path.Point(290.30323645974596, 244.0538990495128),
          svg_path.Point(320.0, 280.0),
          svg_path.Point(320.0, 280.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(320.0, 280.0),
          svg_path.Point(320.0, 280.0),
          svg_path.Point(230.82205831199582, 236.18056137381197),
          svg_path.Point(230.82205831199582, 236.18056137381197),
        ),
        svg_path.CubicBezier(
          svg_path.Point(230.82205831199582, 236.18056137381197),
          svg_path.Point(230.82205831199582, 236.18056137381197),
          svg_path.Point(290.30323645974596, 244.0538990495128),
          svg_path.Point(290.30323645974596, 244.0538990495128),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 117")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(260.5630488345416, 240.11728335016855),
          svg_path.Point(260.5630488345416, 240.11728335016855),
          svg_path.Point(230.82205831331396, 236.1805613638536),
          svg_path.Point(230.82205831331396, 236.1805613638536),
        ),
        svg_path.CubicBezier(
          svg_path.Point(230.82205831331396, 236.1805613638536),
          svg_path.Point(230.82205831331396, 236.1805613638536),
          svg_path.Point(300.041224753361, 200.0),
          svg_path.Point(300.041224753361, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.041224753361, 200.0),
          svg_path.Point(300.041224753361, 200.0),
          svg_path.Point(300.0, 300.0),
          svg_path.Point(300.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.0, 300.0),
          svg_path.Point(300.0, 300.0),
          svg_path.Point(260.5630488345416, 240.11728335016855),
          svg_path.Point(260.5630488345416, 240.11728335016855),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(290.30323645974596, 244.0538990495128),
          svg_path.Point(290.30323645974596, 244.0538990495128),
          svg_path.Point(320.0, 280.0),
          svg_path.Point(320.0, 280.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(320.0, 280.0),
          svg_path.Point(320.0, 280.0),
          svg_path.Point(230.82205831199582, 236.18056137381197),
          svg_path.Point(230.82205831199582, 236.18056137381197),
        ),
        svg_path.CubicBezier(
          svg_path.Point(230.82205831199582, 236.18056137381197),
          svg_path.Point(230.82205831199582, 236.18056137381197),
          svg_path.Point(290.30323645974596, 244.0538990495128),
          svg_path.Point(290.30323645974596, 244.0538990495128),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 118")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(266.2339624919457, 249.28592706878334),
          svg_path.Point(266.2339624919457, 249.28592706878334),
          svg_path.Point(236.42561910533144, 245.88969337410168),
          svg_path.Point(236.42561910533144, 245.88969337410168),
        ),
        svg_path.CubicBezier(
          svg_path.Point(236.42561910533144, 245.88969337410168),
          svg_path.Point(236.42561910533144, 245.88969337410168),
          svg_path.Point(320.0, 240.0),
          svg_path.Point(320.0, 240.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(320.0, 240.0),
          svg_path.Point(320.0, 240.0),
          svg_path.Point(280.0, 300.0),
          svg_path.Point(280.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(280.0, 300.0),
          svg_path.Point(280.0, 300.0),
          svg_path.Point(266.2339624919457, 249.28592706878334),
          svg_path.Point(266.2339624919457, 249.28592706878334),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(296.03993000559, 252.68189006496056),
          svg_path.Point(296.03993000559, 252.68189006496056),
          svg_path.Point(320.0, 300.0),
          svg_path.Point(320.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(320.0, 300.0),
          svg_path.Point(320.0, 300.0),
          svg_path.Point(236.42561910512714, 245.8896933758947),
          svg_path.Point(236.42561910512714, 245.8896933758947),
        ),
        svg_path.CubicBezier(
          svg_path.Point(236.42561910512714, 245.8896933758947),
          svg_path.Point(236.42561910512714, 245.8896933758947),
          svg_path.Point(296.03993000559, 252.68189006496056),
          svg_path.Point(296.03993000559, 252.68189006496056),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 119")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(266.2339624919457, 249.28592706878334),
          svg_path.Point(266.2339624919457, 249.28592706878334),
          svg_path.Point(236.42561910533144, 245.88969337410168),
          svg_path.Point(236.42561910533144, 245.88969337410168),
        ),
        svg_path.CubicBezier(
          svg_path.Point(236.42561910533144, 245.88969337410168),
          svg_path.Point(236.42561910533144, 245.88969337410168),
          svg_path.Point(320.0, 240.0),
          svg_path.Point(320.0, 240.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(320.0, 240.0),
          svg_path.Point(320.0, 240.0),
          svg_path.Point(280.0, 300.0),
          svg_path.Point(280.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(280.0, 300.0),
          svg_path.Point(280.0, 300.0),
          svg_path.Point(266.2339624919457, 249.28592706878334),
          svg_path.Point(266.2339624919457, 249.28592706878334),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(296.03993000559, 252.68189006496056),
          svg_path.Point(296.03993000559, 252.68189006496056),
          svg_path.Point(320.0, 300.0),
          svg_path.Point(320.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(320.0, 300.0),
          svg_path.Point(320.0, 300.0),
          svg_path.Point(236.42561910512714, 245.8896933758947),
          svg_path.Point(236.42561910512714, 245.8896933758947),
        ),
        svg_path.CubicBezier(
          svg_path.Point(236.42561910512714, 245.8896933758947),
          svg_path.Point(236.42561910512714, 245.8896933758947),
          svg_path.Point(296.03993000559, 252.68189006496056),
          svg_path.Point(296.03993000559, 252.68189006496056),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 122")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(249.53400844979302, 269.5706278725207),
          svg_path.Point(244.33170861157976, 270.9140716451985),
          svg_path.Point(243.00452415088105, 272.48265939629516),
          svg_path.Point(243.02912232136828, 272.45353289318496),
        ),
        svg_path.CubicBezier(
          svg_path.Point(243.02912232136828, 272.45353289318496),
          svg_path.Point(243.02912232136828, 272.45353289318496),
          svg_path.Point(197.1892333604494, 233.7404268430289),
          svg_path.Point(197.1892333604494, 233.7404268430289),
        ),
        svg_path.CubicBezier(
          svg_path.Point(197.1892333604494, 233.7404268430289),
          svg_path.Point(197.1892333604494, 233.7404268430289),
          svg_path.Point(249.53400844979302, 269.5706278725207),
          svg_path.Point(249.53400844979302, 269.5706278725207),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(243.02912232136822, 272.453532893185),
          svg_path.Point(243.4747836873187, 271.925828722332),
          svg_path.Point(242.49969041721653, 272.2693581998174),
          svg_path.Point(242.66927041668393, 276.2408467361064),
        ),
        svg_path.CubicBezier(
          svg_path.Point(242.66927041668393, 276.2408467361064),
          svg_path.Point(242.66927041668393, 276.2408467361064),
          svg_path.Point(197.18923336044946, 233.74042684302884),
          svg_path.Point(197.18923336044946, 233.74042684302884),
        ),
        svg_path.CubicBezier(
          svg_path.Point(197.18923336044946, 233.74042684302884),
          svg_path.Point(197.18923336044946, 233.74042684302884),
          svg_path.Point(243.02912232136822, 272.453532893185),
          svg_path.Point(243.02912232136822, 272.453532893185),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 123")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(249.53400844979302, 269.5706278725207),
          svg_path.Point(244.33170861157976, 270.9140716451985),
          svg_path.Point(243.00452415088105, 272.48265939629516),
          svg_path.Point(243.02912232136828, 272.45353289318496),
        ),
        svg_path.CubicBezier(
          svg_path.Point(243.02912232136828, 272.45353289318496),
          svg_path.Point(243.02912232136828, 272.45353289318496),
          svg_path.Point(197.1892333604494, 233.7404268430289),
          svg_path.Point(197.1892333604494, 233.7404268430289),
        ),
        svg_path.CubicBezier(
          svg_path.Point(197.1892333604494, 233.7404268430289),
          svg_path.Point(197.1892333604494, 233.7404268430289),
          svg_path.Point(249.53400844979302, 269.5706278725207),
          svg_path.Point(249.53400844979302, 269.5706278725207),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(243.02912232136822, 272.453532893185),
          svg_path.Point(243.4747836873187, 271.925828722332),
          svg_path.Point(242.49969041721653, 272.2693581998174),
          svg_path.Point(242.66927041668393, 276.2408467361064),
        ),
        svg_path.CubicBezier(
          svg_path.Point(242.66927041668393, 276.2408467361064),
          svg_path.Point(242.66927041668393, 276.2408467361064),
          svg_path.Point(197.18923336044946, 233.74042684302884),
          svg_path.Point(197.18923336044946, 233.74042684302884),
        ),
        svg_path.CubicBezier(
          svg_path.Point(197.18923336044946, 233.74042684302884),
          svg_path.Point(197.18923336044946, 233.74042684302884),
          svg_path.Point(243.02912232136822, 272.453532893185),
          svg_path.Point(243.02912232136822, 272.453532893185),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 126")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(231.45710796909526, 304.56978671182316),
          svg_path.Point(238.42230307565868, 293.87147830004744),
          svg_path.Point(235.1421035656843, 279.2500478974647),
          svg_path.Point(230.61969090209206, 265.2654116388295),
        ),
        svg_path.CubicBezier(
          svg_path.Point(230.61969090209206, 265.2654116388295),
          svg_path.Point(230.61969090209206, 265.2654116388295),
          svg_path.Point(287.7087867546365, 246.8036908431129),
          svg_path.Point(287.7087867546365, 246.8036908431129),
        ),
        svg_path.CubicBezier(
          svg_path.Point(287.7087867546365, 246.8036908431129),
          svg_path.Point(287.7087867546365, 246.8036908431129),
          svg_path.Point(231.45710796909526, 304.56978671182316),
          svg_path.Point(231.45710796909526, 304.56978671182316),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(267.0542186716473, 253.4830551491999),
          svg_path.Point(267.0542186716473, 253.4830551491999),
          svg_path.Point(230.61969090209206, 265.26541163882956),
          svg_path.Point(230.61969090209206, 265.26541163882956),
        ),
        svg_path.CubicBezier(
          svg_path.Point(230.61969090209206, 265.26541163882956),
          svg_path.Point(232.63418634214727, 271.49482679164174),
          svg_path.Point(224.63017272140536, 253.25076606712474),
          svg_path.Point(229.4516168394906, 239.90168380046367),
        ),
        svg_path.CubicBezier(
          svg_path.Point(229.4516168394906, 239.90168380046367),
          svg_path.Point(229.4516168394906, 239.90168380046367),
          svg_path.Point(267.0542186716473, 253.4830551491999),
          svg_path.Point(267.0542186716473, 253.4830551491999),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 127")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(231.45710796909526, 304.56978671182316),
          svg_path.Point(238.42230307565868, 293.87147830004744),
          svg_path.Point(235.1421035656843, 279.2500478974647),
          svg_path.Point(230.61969090209206, 265.2654116388295),
        ),
        svg_path.CubicBezier(
          svg_path.Point(230.61969090209206, 265.2654116388295),
          svg_path.Point(230.61969090209206, 265.2654116388295),
          svg_path.Point(287.7087867546365, 246.8036908431129),
          svg_path.Point(287.7087867546365, 246.8036908431129),
        ),
        svg_path.CubicBezier(
          svg_path.Point(287.7087867546365, 246.8036908431129),
          svg_path.Point(287.7087867546365, 246.8036908431129),
          svg_path.Point(231.45710796909526, 304.56978671182316),
          svg_path.Point(231.45710796909526, 304.56978671182316),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(267.0542186716473, 253.4830551491999),
          svg_path.Point(267.0542186716473, 253.4830551491999),
          svg_path.Point(230.61969090209206, 265.26541163882956),
          svg_path.Point(230.61969090209206, 265.26541163882956),
        ),
        svg_path.CubicBezier(
          svg_path.Point(230.61969090209206, 265.26541163882956),
          svg_path.Point(232.63418634214727, 271.49482679164174),
          svg_path.Point(224.63017272140536, 253.25076606712474),
          svg_path.Point(229.4516168394906, 239.90168380046367),
        ),
        svg_path.CubicBezier(
          svg_path.Point(229.4516168394906, 239.90168380046367),
          svg_path.Point(229.4516168394906, 239.90168380046367),
          svg_path.Point(267.0542186716473, 253.4830551491999),
          svg_path.Point(267.0542186716473, 253.4830551491999),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 128")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(534.4141795042503, 349.4135521611639),
          svg_path.Point(535.409446930124, 344.34922006692875),
          svg_path.Point(532.2519642059839, 374.7814889523282),
          svg_path.Point(518.8256109308445, 384.2317022309883),
        ),
        svg_path.CubicBezier(
          svg_path.Point(518.8256109308445, 384.2317022309883),
          svg_path.Point(518.8256109308445, 384.2317022309883),
          svg_path.Point(487.8821067425946, 340.2688405948006),
          svg_path.Point(487.8821067425946, 340.2688405948006),
        ),
        svg_path.CubicBezier(
          svg_path.Point(487.8821067425946, 340.2688405948006),
          svg_path.Point(487.8821067425946, 340.2688405948006),
          svg_path.Point(529.4025393039343, 348.4286400051758),
          svg_path.Point(529.4025393039343, 348.4286400051758),
        ),
        svg_path.CubicBezier(
          svg_path.Point(529.4025393039343, 348.4286400051758),
          svg_path.Point(528.4635317914656, 346.28789153865404),
          svg_path.Point(534.4141795042503, 349.4135521611639),
          svg_path.Point(534.4141795042503, 349.4135521611639),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(475.5403232814915, 337.8433726698194),
          svg_path.Point(475.5403232814915, 337.8433726698194),
          svg_path.Point(538.3223483008236, 152.20174200302918),
          svg_path.Point(538.3223483008236, 152.20174200302918),
        ),
        svg_path.CubicBezier(
          svg_path.Point(538.3223483008236, 152.20174200302918),
          svg_path.Point(538.3223483008236, 152.20174200302918),
          svg_path.Point(576.6459309452254, 198.36777944721226),
          svg_path.Point(576.6459309452254, 198.36777944721226),
        ),
        svg_path.CubicBezier(
          svg_path.Point(576.6459309452254, 198.36777944721226),
          svg_path.Point(564.1742218009836, 208.72085721968014),
          svg_path.Point(544.2840867339382, 299.1913840774857),
          svg_path.Point(534.4141795042503, 349.41355216116364),
        ),
        svg_path.CubicBezier(
          svg_path.Point(534.4141795042503, 349.41355216116364),
          svg_path.Point(534.4141795042503, 349.41355216116364),
          svg_path.Point(475.5403232814915, 337.8433726698194),
          svg_path.Point(475.5403232814915, 337.8433726698194),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 129")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(534.4141795042503, 349.4135521611639),
          svg_path.Point(535.409446930124, 344.34922006692875),
          svg_path.Point(532.2519642059839, 374.7814889523282),
          svg_path.Point(518.8256109308445, 384.2317022309883),
        ),
        svg_path.CubicBezier(
          svg_path.Point(518.8256109308445, 384.2317022309883),
          svg_path.Point(518.8256109308445, 384.2317022309883),
          svg_path.Point(487.8821067425946, 340.2688405948006),
          svg_path.Point(487.8821067425946, 340.2688405948006),
        ),
        svg_path.CubicBezier(
          svg_path.Point(487.8821067425946, 340.2688405948006),
          svg_path.Point(487.8821067425946, 340.2688405948006),
          svg_path.Point(529.4025393039343, 348.4286400051758),
          svg_path.Point(529.4025393039343, 348.4286400051758),
        ),
        svg_path.CubicBezier(
          svg_path.Point(529.4025393039343, 348.4286400051758),
          svg_path.Point(528.4635317914656, 346.28789153865404),
          svg_path.Point(534.4141795042503, 349.4135521611639),
          svg_path.Point(534.4141795042503, 349.4135521611639),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(475.5403232814915, 337.8433726698194),
          svg_path.Point(475.5403232814915, 337.8433726698194),
          svg_path.Point(538.3223483008236, 152.20174200302918),
          svg_path.Point(538.3223483008236, 152.20174200302918),
        ),
        svg_path.CubicBezier(
          svg_path.Point(538.3223483008236, 152.20174200302918),
          svg_path.Point(538.3223483008236, 152.20174200302918),
          svg_path.Point(576.6459309452254, 198.36777944721226),
          svg_path.Point(576.6459309452254, 198.36777944721226),
        ),
        svg_path.CubicBezier(
          svg_path.Point(576.6459309452254, 198.36777944721226),
          svg_path.Point(564.1742218009836, 208.72085721968014),
          svg_path.Point(544.2840867339382, 299.1913840774857),
          svg_path.Point(534.4141795042503, 349.41355216116364),
        ),
        svg_path.CubicBezier(
          svg_path.Point(534.4141795042503, 349.41355216116364),
          svg_path.Point(534.4141795042503, 349.41355216116364),
          svg_path.Point(475.5403232814915, 337.8433726698194),
          svg_path.Point(475.5403232814915, 337.8433726698194),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 130")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(100.10301277238074, 299.8360064274938),
          svg_path.Point(100.10301277238074, 299.8360064274938),
          svg_path.Point(192.98476439737567, 381.03840618337944),
          svg_path.Point(192.98476439737567, 381.03840618337944),
        ),
        svg_path.CubicBezier(
          svg_path.Point(192.98476439737567, 381.03840618337944),
          svg_path.Point(192.98476439737567, 381.03840618337944),
          svg_path.Point(191.58826071683484, 405.5453629318501),
          svg_path.Point(191.58826071683484, 405.5453629318501),
        ),
        svg_path.CubicBezier(
          svg_path.Point(191.58826071683484, 405.5453629318501),
          svg_path.Point(193.3494388304626, 405.64572185209516),
          svg_path.Point(170.15428858619887, 406.3726082377748),
          svg_path.Point(158.80881838193744, 396.40041814383164),
        ),
        svg_path.CubicBezier(
          svg_path.Point(158.80881838193744, 396.40041814383164),
          svg_path.Point(158.80881838193744, 396.40041814383164),
          svg_path.Point(100.10301277238074, 299.8360064274938),
          svg_path.Point(100.10301277238074, 299.8360064274938),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(195.00176127688619, 345.64254151310115),
          svg_path.Point(195.00176127688619, 345.64254151310115),
          svg_path.Point(481.252611684097, 441.78388187198607),
          svg_path.Point(481.252611684097, 441.78388187198607),
        ),
        svg_path.CubicBezier(
          svg_path.Point(481.252611684097, 441.78388187198607),
          svg_path.Point(481.252611684097, 441.78388187198607),
          svg_path.Point(448.747388315903, 492.21611812801393),
          svg_path.Point(448.747388315903, 492.21611812801393),
        ),
        svg_path.CubicBezier(
          svg_path.Point(448.747388315903, 492.21611812801393),
          svg_path.Point(325.77772873403677, 412.95815637658376),
          svg_path.Point(226.83276465234826, 407.55373467583854),
          svg_path.Point(191.5882607168351, 405.54536293185015),
        ),
        svg_path.CubicBezier(
          svg_path.Point(191.5882607168351, 405.54536293185015),
          svg_path.Point(191.5882607168351, 405.54536293185015),
          svg_path.Point(195.00176127688619, 345.64254151310115),
          svg_path.Point(195.00176127688619, 345.64254151310115),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 131")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(100.10301277238074, 299.8360064274938),
          svg_path.Point(100.10301277238074, 299.8360064274938),
          svg_path.Point(192.98476439737567, 381.03840618337944),
          svg_path.Point(192.98476439737567, 381.03840618337944),
        ),
        svg_path.CubicBezier(
          svg_path.Point(192.98476439737567, 381.03840618337944),
          svg_path.Point(192.98476439737567, 381.03840618337944),
          svg_path.Point(191.58826071683484, 405.5453629318501),
          svg_path.Point(191.58826071683484, 405.5453629318501),
        ),
        svg_path.CubicBezier(
          svg_path.Point(191.58826071683484, 405.5453629318501),
          svg_path.Point(193.3494388304626, 405.64572185209516),
          svg_path.Point(170.15428858619887, 406.3726082377748),
          svg_path.Point(158.80881838193744, 396.40041814383164),
        ),
        svg_path.CubicBezier(
          svg_path.Point(158.80881838193744, 396.40041814383164),
          svg_path.Point(158.80881838193744, 396.40041814383164),
          svg_path.Point(100.10301277238074, 299.8360064274938),
          svg_path.Point(100.10301277238074, 299.8360064274938),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(195.00176127688619, 345.64254151310115),
          svg_path.Point(195.00176127688619, 345.64254151310115),
          svg_path.Point(481.252611684097, 441.78388187198607),
          svg_path.Point(481.252611684097, 441.78388187198607),
        ),
        svg_path.CubicBezier(
          svg_path.Point(481.252611684097, 441.78388187198607),
          svg_path.Point(481.252611684097, 441.78388187198607),
          svg_path.Point(448.747388315903, 492.21611812801393),
          svg_path.Point(448.747388315903, 492.21611812801393),
        ),
        svg_path.CubicBezier(
          svg_path.Point(448.747388315903, 492.21611812801393),
          svg_path.Point(325.77772873403677, 412.95815637658376),
          svg_path.Point(226.83276465234826, 407.55373467583854),
          svg_path.Point(191.5882607168351, 405.54536293185015),
        ),
        svg_path.CubicBezier(
          svg_path.Point(191.5882607168351, 405.54536293185015),
          svg_path.Point(191.5882607168351, 405.54536293185015),
          svg_path.Point(195.00176127688619, 345.64254151310115),
          svg_path.Point(195.00176127688619, 345.64254151310115),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 132")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(201.4099970302107, 456.883477028569),
          svg_path.Point(201.4099970302107, 456.883477028569),
          svg_path.Point(226.29027430947582, 456.0825533500981),
          svg_path.Point(226.29027430947582, 456.0825533500981),
        ),
        svg_path.CubicBezier(
          svg_path.Point(226.29027430947582, 456.0825533500981),
          svg_path.Point(226.00697836246925, 447.2821121806332),
          svg_path.Point(229.31363967716354, 471.7592647771981),
          svg_path.Point(219.2838668275147, 483.73556312076016),
        ),
        svg_path.CubicBezier(
          svg_path.Point(219.2838668275147, 483.73556312076016),
          svg_path.Point(219.2838668275147, 483.73556312076016),
          svg_path.Point(200.0, 500.0),
          svg_path.Point(200.0, 500.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 500.0),
          svg_path.Point(200.0, 500.0),
          svg_path.Point(201.4099970302107, 456.883477028569),
          svg_path.Point(201.4099970302107, 456.883477028569),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(166.32133819059692, 458.01301981440685),
          svg_path.Point(166.32133819059692, 458.01301981440685),
          svg_path.Point(204.6120898437701, 320.4482218772343),
          svg_path.Point(204.6120898437701, 320.4482218772343),
        ),
        svg_path.CubicBezier(
          svg_path.Point(204.6120898437701, 320.4482218772343),
          svg_path.Point(204.6120898437701, 320.4482218772343),
          svg_path.Point(244.3462523224993, 365.40593903584846),
          svg_path.Point(244.3462523224993, 365.40593903584846),
        ),
        svg_path.CubicBezier(
          svg_path.Point(244.3462523224993, 365.40593903584846),
          svg_path.Point(226.25938134969346, 381.39132965143),
          svg_path.Point(225.39711139376217, 428.3369121662385),
          svg_path.Point(226.29027430947582, 456.08255335009807),
        ),
        svg_path.CubicBezier(
          svg_path.Point(226.29027430947582, 456.08255335009807),
          svg_path.Point(226.29027430947582, 456.08255335009807),
          svg_path.Point(166.32133819059692, 458.01301981440685),
          svg_path.Point(166.32133819059692, 458.01301981440685),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 133")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(201.4099970302107, 456.883477028569),
          svg_path.Point(201.4099970302107, 456.883477028569),
          svg_path.Point(226.29027430947582, 456.0825533500981),
          svg_path.Point(226.29027430947582, 456.0825533500981),
        ),
        svg_path.CubicBezier(
          svg_path.Point(226.29027430947582, 456.0825533500981),
          svg_path.Point(226.00697836246925, 447.2821121806332),
          svg_path.Point(229.31363967716354, 471.7592647771981),
          svg_path.Point(219.2838668275147, 483.73556312076016),
        ),
        svg_path.CubicBezier(
          svg_path.Point(219.2838668275147, 483.73556312076016),
          svg_path.Point(219.2838668275147, 483.73556312076016),
          svg_path.Point(200.0, 500.0),
          svg_path.Point(200.0, 500.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(200.0, 500.0),
          svg_path.Point(200.0, 500.0),
          svg_path.Point(201.4099970302107, 456.883477028569),
          svg_path.Point(201.4099970302107, 456.883477028569),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(166.32133819059692, 458.01301981440685),
          svg_path.Point(166.32133819059692, 458.01301981440685),
          svg_path.Point(204.6120898437701, 320.4482218772343),
          svg_path.Point(204.6120898437701, 320.4482218772343),
        ),
        svg_path.CubicBezier(
          svg_path.Point(204.6120898437701, 320.4482218772343),
          svg_path.Point(204.6120898437701, 320.4482218772343),
          svg_path.Point(244.3462523224993, 365.40593903584846),
          svg_path.Point(244.3462523224993, 365.40593903584846),
        ),
        svg_path.CubicBezier(
          svg_path.Point(244.3462523224993, 365.40593903584846),
          svg_path.Point(226.25938134969346, 381.39132965143),
          svg_path.Point(225.39711139376217, 428.3369121662385),
          svg_path.Point(226.29027430947582, 456.08255335009807),
        ),
        svg_path.CubicBezier(
          svg_path.Point(226.29027430947582, 456.08255335009807),
          svg_path.Point(226.29027430947582, 456.08255335009807),
          svg_path.Point(166.32133819059692, 458.01301981440685),
          svg_path.Point(166.32133819059692, 458.01301981440685),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 138")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(290.1253327484206, 287.90652074109494),
          svg_path.Point(290.1253327484206, 287.90652074109494),
          svg_path.Point(342.6480156335393, 281.88796157138086),
          svg_path.Point(342.6480156335393, 281.88796157138086),
        ),
        svg_path.CubicBezier(
          svg_path.Point(342.6480156335393, 281.88796157138086),
          svg_path.Point(342.6480156335393, 281.88796157138086),
          svg_path.Point(340.20645047153664, 251.98747653472907),
          svg_path.Point(340.20645047153664, 251.98747653472907),
        ),
        svg_path.CubicBezier(
          svg_path.Point(340.20645047153664, 251.98747653472907),
          svg_path.Point(340.20645047153664, 251.98747653472907),
          svg_path.Point(370.8816252545162, 292.03012917196776),
          svg_path.Point(370.8816252545162, 292.03012917196776),
        ),
        svg_path.CubicBezier(
          svg_path.Point(370.8816252545162, 292.03012917196776),
          svg_path.Point(370.8816252545162, 292.03012917196776),
          svg_path.Point(290.1253327484206, 287.90652074109494),
          svg_path.Point(290.1253327484206, 287.90652074109494),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(345.08958029318296, 311.78843842619824),
          svg_path.Point(345.08958029318296, 311.78843842619824),
          svg_path.Point(300.0082518321038, 300.98900280805503),
          svg_path.Point(300.0082518321038, 300.98900280805503),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.0082518321038, 300.98900280805503),
          svg_path.Point(300.0082518321038, 300.98900280805503),
          svg_path.Point(340.20645030689445, 251.98747654817316),
          svg_path.Point(340.20645030689445, 251.98747654817316),
        ),
        svg_path.CubicBezier(
          svg_path.Point(340.20645030689445, 251.98747654817316),
          svg_path.Point(340.20645030689445, 251.98747654817316),
          svg_path.Point(345.08958029318296, 311.78843842619824),
          svg_path.Point(345.08958029318296, 311.78843842619824),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 139")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(290.1253327484206, 287.90652074109494),
          svg_path.Point(290.1253327484206, 287.90652074109494),
          svg_path.Point(342.6480156335393, 281.88796157138086),
          svg_path.Point(342.6480156335393, 281.88796157138086),
        ),
        svg_path.CubicBezier(
          svg_path.Point(342.6480156335393, 281.88796157138086),
          svg_path.Point(342.6480156335393, 281.88796157138086),
          svg_path.Point(340.20645047153664, 251.98747653472907),
          svg_path.Point(340.20645047153664, 251.98747653472907),
        ),
        svg_path.CubicBezier(
          svg_path.Point(340.20645047153664, 251.98747653472907),
          svg_path.Point(340.20645047153664, 251.98747653472907),
          svg_path.Point(370.8816252545162, 292.03012917196776),
          svg_path.Point(370.8816252545162, 292.03012917196776),
        ),
        svg_path.CubicBezier(
          svg_path.Point(370.8816252545162, 292.03012917196776),
          svg_path.Point(370.8816252545162, 292.03012917196776),
          svg_path.Point(290.1253327484206, 287.90652074109494),
          svg_path.Point(290.1253327484206, 287.90652074109494),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(345.08958029318296, 311.78843842619824),
          svg_path.Point(345.08958029318296, 311.78843842619824),
          svg_path.Point(300.0082518321038, 300.98900280805503),
          svg_path.Point(300.0082518321038, 300.98900280805503),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.0082518321038, 300.98900280805503),
          svg_path.Point(300.0082518321038, 300.98900280805503),
          svg_path.Point(340.20645030689445, 251.98747654817316),
          svg_path.Point(340.20645030689445, 251.98747654817316),
        ),
        svg_path.CubicBezier(
          svg_path.Point(340.20645030689445, 251.98747654817316),
          svg_path.Point(340.20645030689445, 251.98747654817316),
          svg_path.Point(345.08958029318296, 311.78843842619824),
          svg_path.Point(345.08958029318296, 311.78843842619824),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 144")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(292.9399983081827, 321.04496242335836),
          svg_path.Point(292.9399983081827, 321.04496242335836),
          svg_path.Point(301.41124169557446, 297.40574481030876),
          svg_path.Point(301.41124169557446, 297.40574481030876),
        ),
        svg_path.CubicBezier(
          svg_path.Point(301.41124169557446, 297.40574481030876),
          svg_path.Point(301.41124169557446, 297.40574481030876),
          svg_path.Point(271.4382902635834, 296.1319728479751),
          svg_path.Point(271.4382902635834, 296.1319728479751),
        ),
        svg_path.CubicBezier(
          svg_path.Point(271.4382902635834, 296.1319728479751),
          svg_path.Point(271.4382902635834, 296.1319728479751),
          svg_path.Point(319.88255402047366, 273.7665574434494),
          svg_path.Point(319.88255402047366, 273.7665574434494),
        ),
        svg_path.CubicBezier(
          svg_path.Point(319.88255402047366, 273.7665574434494),
          svg_path.Point(319.88255402047366, 273.7665574434494),
          svg_path.Point(292.9399983081827, 321.04496242335836),
          svg_path.Point(292.9399983081827, 321.04496242335836),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(331.38418270096264, 298.67951674085646),
          svg_path.Point(331.38418270096264, 298.67951674085646),
          svg_path.Point(350.0, 345.76013009266507),
          svg_path.Point(350.0, 345.76013009266507),
        ),
        svg_path.CubicBezier(
          svg_path.Point(350.0, 345.76013009266507),
          svg_path.Point(350.0, 345.76013009266507),
          svg_path.Point(271.4382902810318, 296.1319724373992),
          svg_path.Point(271.4382902810318, 296.1319724373992),
        ),
        svg_path.CubicBezier(
          svg_path.Point(271.4382902810318, 296.1319724373992),
          svg_path.Point(271.4382902810318, 296.1319724373992),
          svg_path.Point(331.38418270096264, 298.67951674085646),
          svg_path.Point(331.38418270096264, 298.67951674085646),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 145")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(292.9399983081827, 321.04496242335836),
          svg_path.Point(292.9399983081827, 321.04496242335836),
          svg_path.Point(301.41124169557446, 297.40574481030876),
          svg_path.Point(301.41124169557446, 297.40574481030876),
        ),
        svg_path.CubicBezier(
          svg_path.Point(301.41124169557446, 297.40574481030876),
          svg_path.Point(301.41124169557446, 297.40574481030876),
          svg_path.Point(271.4382902635834, 296.1319728479751),
          svg_path.Point(271.4382902635834, 296.1319728479751),
        ),
        svg_path.CubicBezier(
          svg_path.Point(271.4382902635834, 296.1319728479751),
          svg_path.Point(271.4382902635834, 296.1319728479751),
          svg_path.Point(319.88255402047366, 273.7665574434494),
          svg_path.Point(319.88255402047366, 273.7665574434494),
        ),
        svg_path.CubicBezier(
          svg_path.Point(319.88255402047366, 273.7665574434494),
          svg_path.Point(319.88255402047366, 273.7665574434494),
          svg_path.Point(292.9399983081827, 321.04496242335836),
          svg_path.Point(292.9399983081827, 321.04496242335836),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(331.38418270096264, 298.67951674085646),
          svg_path.Point(331.38418270096264, 298.67951674085646),
          svg_path.Point(350.0, 345.76013009266507),
          svg_path.Point(350.0, 345.76013009266507),
        ),
        svg_path.CubicBezier(
          svg_path.Point(350.0, 345.76013009266507),
          svg_path.Point(350.0, 345.76013009266507),
          svg_path.Point(271.4382902810318, 296.1319724373992),
          svg_path.Point(271.4382902810318, 296.1319724373992),
        ),
        svg_path.CubicBezier(
          svg_path.Point(271.4382902810318, 296.1319724373992),
          svg_path.Point(271.4382902810318, 296.1319724373992),
          svg_path.Point(331.38418270096264, 298.67951674085646),
          svg_path.Point(331.38418270096264, 298.67951674085646),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 146")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(349.2988989052917, 302.360122358839),
          svg_path.Point(349.2988989052917, 302.360122358839),
          svg_path.Point(306.8847250793194, 310.8417788081535),
          svg_path.Point(306.8847250793194, 310.8417788081535),
        ),
        svg_path.CubicBezier(
          svg_path.Point(306.8847250793194, 310.8417788081535),
          svg_path.Point(306.8847250793194, 310.8417788081535),
          svg_path.Point(317.34865046978905, 286.0848942283935),
          svg_path.Point(317.34865046978905, 286.0848942283935),
        ),
        svg_path.CubicBezier(
          svg_path.Point(317.34865046978905, 286.0848942283935),
          svg_path.Point(317.34865046978905, 286.0848942283935),
          svg_path.Point(295.03238113332606, 289.30770347326694),
          svg_path.Point(295.03238113332606, 289.30770347326694),
        ),
        svg_path.CubicBezier(
          svg_path.Point(295.03238113332606, 289.30770347326694),
          svg_path.Point(295.03238113332606, 289.30770347326694),
          svg_path.Point(349.2988989052917, 302.360122358839),
          svg_path.Point(349.2988989052917, 302.360122358839),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(306.8847250793191, 310.8417788081534),
          svg_path.Point(306.8847250793191, 310.8417788081534),
          svg_path.Point(308.40196713650136, 308.29790890842884),
          svg_path.Point(308.40196713650136, 308.29790890842884),
        ),
        svg_path.CubicBezier(
          svg_path.Point(308.40196713650136, 308.29790890842884),
          svg_path.Point(308.40196713650136, 308.29790890842884),
          svg_path.Point(297.432392604982, 249.3091944403423),
          svg_path.Point(297.432392604982, 249.3091944403423),
        ),
        svg_path.CubicBezier(
          svg_path.Point(297.432392604982, 249.3091944403423),
          svg_path.Point(297.432392604982, 249.3091944403423),
          svg_path.Point(330.2439214313423, 255.57562328972034),
          svg_path.Point(330.2439214313423, 255.57562328972034),
        ),
        svg_path.CubicBezier(
          svg_path.Point(330.2439214313423, 255.57562328972034),
          svg_path.Point(330.2439214313423, 255.57562328972034),
          svg_path.Point(306.8847250793191, 310.8417788081534),
          svg_path.Point(306.8847250793191, 310.8417788081534),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 147")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(349.2988989052917, 302.360122358839),
          svg_path.Point(349.2988989052917, 302.360122358839),
          svg_path.Point(306.8847250793194, 310.8417788081535),
          svg_path.Point(306.8847250793194, 310.8417788081535),
        ),
        svg_path.CubicBezier(
          svg_path.Point(306.8847250793194, 310.8417788081535),
          svg_path.Point(306.8847250793194, 310.8417788081535),
          svg_path.Point(317.34865046978905, 286.0848942283935),
          svg_path.Point(317.34865046978905, 286.0848942283935),
        ),
        svg_path.CubicBezier(
          svg_path.Point(317.34865046978905, 286.0848942283935),
          svg_path.Point(317.34865046978905, 286.0848942283935),
          svg_path.Point(295.03238113332606, 289.30770347326694),
          svg_path.Point(295.03238113332606, 289.30770347326694),
        ),
        svg_path.CubicBezier(
          svg_path.Point(295.03238113332606, 289.30770347326694),
          svg_path.Point(295.03238113332606, 289.30770347326694),
          svg_path.Point(349.2988989052917, 302.360122358839),
          svg_path.Point(349.2988989052917, 302.360122358839),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(306.8847250793191, 310.8417788081534),
          svg_path.Point(306.8847250793191, 310.8417788081534),
          svg_path.Point(308.40196713650136, 308.29790890842884),
          svg_path.Point(308.40196713650136, 308.29790890842884),
        ),
        svg_path.CubicBezier(
          svg_path.Point(308.40196713650136, 308.29790890842884),
          svg_path.Point(308.40196713650136, 308.29790890842884),
          svg_path.Point(297.432392604982, 249.3091944403423),
          svg_path.Point(297.432392604982, 249.3091944403423),
        ),
        svg_path.CubicBezier(
          svg_path.Point(297.432392604982, 249.3091944403423),
          svg_path.Point(297.432392604982, 249.3091944403423),
          svg_path.Point(330.2439214313423, 255.57562328972034),
          svg_path.Point(330.2439214313423, 255.57562328972034),
        ),
        svg_path.CubicBezier(
          svg_path.Point(330.2439214313423, 255.57562328972034),
          svg_path.Point(330.2439214313423, 255.57562328972034),
          svg_path.Point(306.8847250793191, 310.8417788081534),
          svg_path.Point(306.8847250793191, 310.8417788081534),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 150")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(299.7385339651986, 102.20556080028058),
          svg_path.Point(299.7385339651986, 102.20556080028058),
          svg_path.Point(324.85949771228013, 85.81468459475798),
          svg_path.Point(324.85949771228013, 85.81468459475798),
        ),
        svg_path.CubicBezier(
          svg_path.Point(324.85949771228013, 85.81468459475798),
          svg_path.Point(324.85949771228013, 85.81468459475798),
          svg_path.Point(331.26017128225755, 56.500458549069435),
          svg_path.Point(331.26017128225755, 56.500458549069435),
        ),
        svg_path.CubicBezier(
          svg_path.Point(331.26017128225755, 56.500458549069435),
          svg_path.Point(331.26017128225755, 56.500458549069435),
          svg_path.Point(349.988176980811, 69.4187741812245),
          svg_path.Point(349.988176980811, 69.4187741812245),
        ),
        svg_path.CubicBezier(
          svg_path.Point(349.988176980811, 69.4187741812245),
          svg_path.Point(359.0513106194836, 83.30910247833779),
          svg_path.Point(290.89167960074064, 88.64670616806892),
          svg_path.Point(299.7385339651986, 102.20556080028058),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(318.4609036471463, 115.11938678905685),
          svg_path.Point(318.4609036471463, 115.11938678905685),
          svg_path.Point(340.9228398583517, 111.1463404606569),
          svg_path.Point(340.9228398583517, 111.1463404606569),
        ),
        svg_path.CubicBezier(
          svg_path.Point(340.9228398583517, 111.1463404606569),
          svg_path.Point(340.9228398583517, 111.1463404606569),
          svg_path.Point(308.7912208820021, 60.47525341924158),
          svg_path.Point(308.7912208820021, 60.47525341924158),
        ),
        svg_path.CubicBezier(
          svg_path.Point(308.7912208820021, 60.47525341924158),
          svg_path.Point(308.7912208820021, 60.47525341924158),
          svg_path.Point(331.2601712818937, 56.50045854899),
          svg_path.Point(331.2601712818937, 56.50045854899),
        ),
        svg_path.CubicBezier(
          svg_path.Point(331.2601712818937, 56.50045854899),
          svg_path.Point(331.2601712818937, 56.50045854899),
          svg_path.Point(318.4609036471463, 115.11938678905685),
          svg_path.Point(318.4609036471463, 115.11938678905685),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 151")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(299.7385339651986, 102.20556080028058),
          svg_path.Point(299.7385339651986, 102.20556080028058),
          svg_path.Point(324.85949771228013, 85.81468459475798),
          svg_path.Point(324.85949771228013, 85.81468459475798),
        ),
        svg_path.CubicBezier(
          svg_path.Point(324.85949771228013, 85.81468459475798),
          svg_path.Point(324.85949771228013, 85.81468459475798),
          svg_path.Point(331.26017128225755, 56.500458549069435),
          svg_path.Point(331.26017128225755, 56.500458549069435),
        ),
        svg_path.CubicBezier(
          svg_path.Point(331.26017128225755, 56.500458549069435),
          svg_path.Point(331.26017128225755, 56.500458549069435),
          svg_path.Point(349.988176980811, 69.4187741812245),
          svg_path.Point(349.988176980811, 69.4187741812245),
        ),
        svg_path.CubicBezier(
          svg_path.Point(349.988176980811, 69.4187741812245),
          svg_path.Point(359.0513106194836, 83.30910247833779),
          svg_path.Point(290.89167960074064, 88.64670616806892),
          svg_path.Point(299.7385339651986, 102.20556080028058),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(318.4609036471463, 115.11938678905685),
          svg_path.Point(318.4609036471463, 115.11938678905685),
          svg_path.Point(340.9228398583517, 111.1463404606569),
          svg_path.Point(340.9228398583517, 111.1463404606569),
        ),
        svg_path.CubicBezier(
          svg_path.Point(340.9228398583517, 111.1463404606569),
          svg_path.Point(340.9228398583517, 111.1463404606569),
          svg_path.Point(308.7912208820021, 60.47525341924158),
          svg_path.Point(308.7912208820021, 60.47525341924158),
        ),
        svg_path.CubicBezier(
          svg_path.Point(308.7912208820021, 60.47525341924158),
          svg_path.Point(308.7912208820021, 60.47525341924158),
          svg_path.Point(331.2601712818937, 56.50045854899),
          svg_path.Point(331.2601712818937, 56.50045854899),
        ),
        svg_path.CubicBezier(
          svg_path.Point(331.2601712818937, 56.50045854899),
          svg_path.Point(331.2601712818937, 56.50045854899),
          svg_path.Point(318.4609036471463, 115.11938678905685),
          svg_path.Point(318.4609036471463, 115.11938678905685),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 152")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(388.9213889025063, 223.3215931867822),
          svg_path.Point(509.19751906181426, 221.07790621479464),
          svg_path.Point(597.6181955110758, 242.94850207232983),
          svg_path.Point(597.6181955110758, 242.94850207232983),
        ),
        svg_path.CubicBezier(
          svg_path.Point(597.6181955110758, 242.94850207232983),
          svg_path.Point(597.6181955110758, 242.94850207232983),
          svg_path.Point(628.0354673841999, 243.03685701873312),
          svg_path.Point(628.0354673841999, 243.03685701873312),
        ),
        svg_path.CubicBezier(
          svg_path.Point(628.0354673841999, 243.03685701873312),
          svg_path.Point(628.0044262657246, 253.72314203550712),
          svg_path.Point(419.2789142850017, 364.27077547853787),
          svg_path.Point(419.2789142850017, 364.27077547853787),
        ),
        svg_path.CubicBezier(
          svg_path.Point(419.2789142850017, 364.27077547853787),
          svg_path.Point(419.2789142850017, 364.27077547853787),
          svg_path.Point(388.9213889025063, 223.3215931867822),
          svg_path.Point(388.9213889025063, 223.3215931867822),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(568.0357205119291, 242.86257201242702),
          svg_path.Point(568.0357205119291, 242.86257201242702),
          svg_path.Point(576.294245114903, 263.4873716612576),
          svg_path.Point(576.294245114903, 263.4873716612576),
        ),
        svg_path.CubicBezier(
          svg_path.Point(576.294245114903, 263.4873716612576),
          svg_path.Point(576.294245114903, 263.4873716612576),
          svg_path.Point(619.5200435607698, 221.87571045051882),
          svg_path.Point(619.5200435607698, 221.87571045051882),
        ),
        svg_path.CubicBezier(
          svg_path.Point(619.5200435607698, 221.87571045051882),
          svg_path.Point(619.5200435607698, 221.87571045051882),
          svg_path.Point(628.0657700157852, 232.60480515822775),
          svg_path.Point(628.0354673841999, 243.03685701876972),
        ),
        svg_path.CubicBezier(
          svg_path.Point(628.0354673841999, 243.03685701876972),
          svg_path.Point(628.0354673841999, 243.03685701876972),
          svg_path.Point(568.0357205119291, 242.86257201242702),
          svg_path.Point(568.0357205119291, 242.86257201242702),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 153")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(388.9213889025063, 223.3215931867822),
          svg_path.Point(509.19751906181426, 221.07790621479464),
          svg_path.Point(597.6181955110758, 242.94850207232983),
          svg_path.Point(597.6181955110758, 242.94850207232983),
        ),
        svg_path.CubicBezier(
          svg_path.Point(597.6181955110758, 242.94850207232983),
          svg_path.Point(597.6181955110758, 242.94850207232983),
          svg_path.Point(628.0354673841999, 243.03685701873312),
          svg_path.Point(628.0354673841999, 243.03685701873312),
        ),
        svg_path.CubicBezier(
          svg_path.Point(628.0354673841999, 243.03685701873312),
          svg_path.Point(628.0044262657246, 253.72314203550712),
          svg_path.Point(419.2789142850017, 364.27077547853787),
          svg_path.Point(419.2789142850017, 364.27077547853787),
        ),
        svg_path.CubicBezier(
          svg_path.Point(419.2789142850017, 364.27077547853787),
          svg_path.Point(419.2789142850017, 364.27077547853787),
          svg_path.Point(388.9213889025063, 223.3215931867822),
          svg_path.Point(388.9213889025063, 223.3215931867822),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(568.0357205119291, 242.86257201242702),
          svg_path.Point(568.0357205119291, 242.86257201242702),
          svg_path.Point(576.294245114903, 263.4873716612576),
          svg_path.Point(576.294245114903, 263.4873716612576),
        ),
        svg_path.CubicBezier(
          svg_path.Point(576.294245114903, 263.4873716612576),
          svg_path.Point(576.294245114903, 263.4873716612576),
          svg_path.Point(619.5200435607698, 221.87571045051882),
          svg_path.Point(619.5200435607698, 221.87571045051882),
        ),
        svg_path.CubicBezier(
          svg_path.Point(619.5200435607698, 221.87571045051882),
          svg_path.Point(619.5200435607698, 221.87571045051882),
          svg_path.Point(628.0657700157852, 232.60480515822775),
          svg_path.Point(628.0354673841999, 243.03685701876972),
        ),
        svg_path.CubicBezier(
          svg_path.Point(628.0354673841999, 243.03685701876972),
          svg_path.Point(628.0354673841999, 243.03685701876972),
          svg_path.Point(568.0357205119291, 242.86257201242702),
          svg_path.Point(568.0357205119291, 242.86257201242702),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 158")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(525.0, 345.0),
          svg_path.Point(525.0, 345.0),
          svg_path.Point(557.3179687742295, 363.04379418599376),
          svg_path.Point(557.3179687742295, 363.04379418599376),
        ),
        svg_path.CubicBezier(
          svg_path.Point(557.3179687742295, 363.04379418599376),
          svg_path.Point(557.3179687742295, 363.04379418599376),
          svg_path.Point(587.1223034990716, 366.54087021669767),
          svg_path.Point(587.1223034990716, 366.54087021669767),
        ),
        svg_path.CubicBezier(
          svg_path.Point(587.1223034990716, 366.54087021669767),
          svg_path.Point(587.1223034990716, 366.54087021669767),
          svg_path.Point(500.0, 400.0),
          svg_path.Point(500.0, 400.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(500.0, 400.0),
          svg_path.Point(500.0, 400.0),
          svg_path.Point(525.0, 345.0),
          svg_path.Point(525.0, 345.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(527.5311085637297, 359.5487685170587),
          svg_path.Point(527.5311085637297, 359.5487685170587),
          svg_path.Point(533.6060904205631, 381.4080959083297),
          svg_path.Point(533.6060904205631, 381.4080959083297),
        ),
        svg_path.CubicBezier(
          svg_path.Point(533.6060904205631, 381.4080959083297),
          svg_path.Point(533.6060904205631, 381.4080959083297),
          svg_path.Point(581.0430044030195, 344.66929908778826),
          svg_path.Point(581.0430044030195, 344.66929908778826),
        ),
        svg_path.CubicBezier(
          svg_path.Point(581.0430044030195, 344.66929908778826),
          svg_path.Point(581.0430044030195, 344.66929908778826),
          svg_path.Point(587.1223034989287, 366.54087021791537),
          svg_path.Point(587.1223034989287, 366.54087021791537),
        ),
        svg_path.CubicBezier(
          svg_path.Point(587.1223034989287, 366.54087021791537),
          svg_path.Point(587.1223034989287, 366.54087021791537),
          svg_path.Point(527.5311085637297, 359.5487685170587),
          svg_path.Point(527.5311085637297, 359.5487685170587),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 159")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(525.0, 345.0),
          svg_path.Point(525.0, 345.0),
          svg_path.Point(557.3179687742295, 363.04379418599376),
          svg_path.Point(557.3179687742295, 363.04379418599376),
        ),
        svg_path.CubicBezier(
          svg_path.Point(557.3179687742295, 363.04379418599376),
          svg_path.Point(557.3179687742295, 363.04379418599376),
          svg_path.Point(587.1223034990716, 366.54087021669767),
          svg_path.Point(587.1223034990716, 366.54087021669767),
        ),
        svg_path.CubicBezier(
          svg_path.Point(587.1223034990716, 366.54087021669767),
          svg_path.Point(587.1223034990716, 366.54087021669767),
          svg_path.Point(500.0, 400.0),
          svg_path.Point(500.0, 400.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(500.0, 400.0),
          svg_path.Point(500.0, 400.0),
          svg_path.Point(525.0, 345.0),
          svg_path.Point(525.0, 345.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(527.5311085637297, 359.5487685170587),
          svg_path.Point(527.5311085637297, 359.5487685170587),
          svg_path.Point(533.6060904205631, 381.4080959083297),
          svg_path.Point(533.6060904205631, 381.4080959083297),
        ),
        svg_path.CubicBezier(
          svg_path.Point(533.6060904205631, 381.4080959083297),
          svg_path.Point(533.6060904205631, 381.4080959083297),
          svg_path.Point(581.0430044030195, 344.66929908778826),
          svg_path.Point(581.0430044030195, 344.66929908778826),
        ),
        svg_path.CubicBezier(
          svg_path.Point(581.0430044030195, 344.66929908778826),
          svg_path.Point(581.0430044030195, 344.66929908778826),
          svg_path.Point(587.1223034989287, 366.54087021791537),
          svg_path.Point(587.1223034989287, 366.54087021791537),
        ),
        svg_path.CubicBezier(
          svg_path.Point(587.1223034989287, 366.54087021791537),
          svg_path.Point(587.1223034989287, 366.54087021791537),
          svg_path.Point(527.5311085637297, 359.5487685170587),
          svg_path.Point(527.5311085637297, 359.5487685170587),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 160")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 150.0),
          svg_path.Point(234.74625221124325, 182.05024235296503),
          svg_path.Point(234.74625221124325, 182.05024235296503),
        ),
        svg_path.CubicBezier(
          svg_path.Point(234.74625221124325, 182.05024235296503),
          svg_path.Point(234.74625221124325, 182.05024235296503),
          svg_path.Point(205.60227766791786, 189.2546311484904),
          svg_path.Point(205.60227766791786, 189.2546311484904),
        ),
        svg_path.CubicBezier(
          svg_path.Point(205.60227766791786, 189.2546311484904),
          svg_path.Point(205.60227766791786, 189.2546311484904),
          svg_path.Point(205.60227766791786, 189.4546311484904),
          svg_path.Point(205.60227766791786, 189.4546311484904),
        ),
        svg_path.CubicBezier(
          svg_path.Point(205.60227766791786, 189.4546311484904),
          svg_path.Point(205.60227766791786, 189.4546311484904),
          svg_path.Point(205.61255586021304, 189.25209037995552),
          svg_path.Point(205.61255586021304, 189.25209037995552),
        ),
        svg_path.CubicBezier(
          svg_path.Point(205.61255586021304, 189.25209037995552),
          svg_path.Point(205.61255586021304, 189.25209037995552),
          svg_path.Point(263.84900039629053, 174.85604471078497),
          svg_path.Point(263.84900039629053, 174.85604471078497),
        ),
        svg_path.CubicBezier(
          svg_path.Point(263.84900039629053, 174.85604471078497),
          svg_path.Point(263.84900039629053, 174.85604471078497),
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(225.84313834895474, 153.1048226009985),
          svg_path.Point(225.84313834895474, 153.1048226009985),
          svg_path.Point(180.0, 190.0),
          svg_path.Point(180.0, 190.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(180.0, 190.0),
          svg_path.Point(180.0, 190.0),
          svg_path.Point(243.48255333255608, 210.4533277169673),
          svg_path.Point(243.48255333255608, 210.4533277169673),
        ),
        svg_path.CubicBezier(
          svg_path.Point(243.48255333255608, 210.4533277169673),
          svg_path.Point(243.48255333255608, 210.4533277169673),
          svg_path.Point(225.84313834895474, 153.1048226009985),
          svg_path.Point(225.84313834895474, 153.1048226009985),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 161")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 150.0),
          svg_path.Point(234.74625221124325, 182.05024235296503),
          svg_path.Point(234.74625221124325, 182.05024235296503),
        ),
        svg_path.CubicBezier(
          svg_path.Point(234.74625221124325, 182.05024235296503),
          svg_path.Point(234.74625221124325, 182.05024235296503),
          svg_path.Point(205.60227766791786, 189.2546311484904),
          svg_path.Point(205.60227766791786, 189.2546311484904),
        ),
        svg_path.CubicBezier(
          svg_path.Point(205.60227766791786, 189.2546311484904),
          svg_path.Point(205.60227766791786, 189.2546311484904),
          svg_path.Point(205.60227766791786, 189.4546311484904),
          svg_path.Point(205.60227766791786, 189.4546311484904),
        ),
        svg_path.CubicBezier(
          svg_path.Point(205.60227766791786, 189.4546311484904),
          svg_path.Point(205.60227766791786, 189.4546311484904),
          svg_path.Point(205.61255586021304, 189.25209037995552),
          svg_path.Point(205.61255586021304, 189.25209037995552),
        ),
        svg_path.CubicBezier(
          svg_path.Point(205.61255586021304, 189.25209037995552),
          svg_path.Point(205.61255586021304, 189.25209037995552),
          svg_path.Point(263.84900039629053, 174.85604471078497),
          svg_path.Point(263.84900039629053, 174.85604471078497),
        ),
        svg_path.CubicBezier(
          svg_path.Point(263.84900039629053, 174.85604471078497),
          svg_path.Point(263.84900039629053, 174.85604471078497),
          svg_path.Point(250.0, 150.0),
          svg_path.Point(250.0, 150.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(225.84313834895474, 153.1048226009985),
          svg_path.Point(225.84313834895474, 153.1048226009985),
          svg_path.Point(180.0, 190.0),
          svg_path.Point(180.0, 190.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(180.0, 190.0),
          svg_path.Point(180.0, 190.0),
          svg_path.Point(243.48255333255608, 210.4533277169673),
          svg_path.Point(243.48255333255608, 210.4533277169673),
        ),
        svg_path.CubicBezier(
          svg_path.Point(243.48255333255608, 210.4533277169673),
          svg_path.Point(243.48255333255608, 210.4533277169673),
          svg_path.Point(225.84313834895474, 153.1048226009985),
          svg_path.Point(225.84313834895474, 153.1048226009985),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 164")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(570.0, 290.0),
          svg_path.Point(570.0, 290.0),
          svg_path.Point(575.8176000300452, 323.5855681222093),
          svg_path.Point(575.8176000300452, 323.5855681222093),
        ),
        svg_path.CubicBezier(
          svg_path.Point(575.8176000300452, 323.5855681222093),
          svg_path.Point(575.8176000300452, 323.5855681222093),
          svg_path.Point(547.6444566349796, 309.1465641549448),
          svg_path.Point(547.6444566349796, 309.1465641549448),
        ),
        svg_path.CubicBezier(
          svg_path.Point(547.6444566349796, 309.1465641549448),
          svg_path.Point(547.6444566349796, 309.1465641549448),
          svg_path.Point(578.8341920603752, 304.57835489946484),
          svg_path.Point(578.8341920603752, 304.57835489946484),
        ),
        svg_path.CubicBezier(
          svg_path.Point(578.8341920603752, 304.57835489946484),
          svg_path.Point(578.8341920546527, 304.57835486039346),
          svg_path.Point(519.4675806753132, 313.27349449897866),
          svg_path.Point(519.4675806753132, 313.27349449897866),
        ),
        svg_path.CubicBezier(
          svg_path.Point(519.4675806753132, 313.27349449897866),
          svg_path.Point(519.4675806753132, 313.27349449897866),
          svg_path.Point(570.0, 290.0),
          svg_path.Point(570.0, 290.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(575.8176000300631, 323.58556812217466),
          svg_path.Point(575.8176000300631, 323.58556812217466),
          svg_path.Point(560.0, 300.0),
          svg_path.Point(560.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(560.0, 300.0),
          svg_path.Point(560.0, 300.0),
          svg_path.Point(522.421811145802, 296.21971842903645),
          svg_path.Point(522.421811145802, 296.21971842903645),
        ),
        svg_path.CubicBezier(
          svg_path.Point(522.421811145802, 296.21971842903645),
          svg_path.Point(522.421811145802, 296.21971842903645),
          svg_path.Point(575.8176000300631, 323.58556812217466),
          svg_path.Point(575.8176000300631, 323.58556812217466),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 165")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(570.0, 290.0),
          svg_path.Point(570.0, 290.0),
          svg_path.Point(575.8176000300452, 323.5855681222093),
          svg_path.Point(575.8176000300452, 323.5855681222093),
        ),
        svg_path.CubicBezier(
          svg_path.Point(575.8176000300452, 323.5855681222093),
          svg_path.Point(575.8176000300452, 323.5855681222093),
          svg_path.Point(547.6444566349796, 309.1465641549448),
          svg_path.Point(547.6444566349796, 309.1465641549448),
        ),
        svg_path.CubicBezier(
          svg_path.Point(547.6444566349796, 309.1465641549448),
          svg_path.Point(547.6444566349796, 309.1465641549448),
          svg_path.Point(578.8341920603752, 304.57835489946484),
          svg_path.Point(578.8341920603752, 304.57835489946484),
        ),
        svg_path.CubicBezier(
          svg_path.Point(578.8341920603752, 304.57835489946484),
          svg_path.Point(578.8341920546527, 304.57835486039346),
          svg_path.Point(519.4675806753132, 313.27349449897866),
          svg_path.Point(519.4675806753132, 313.27349449897866),
        ),
        svg_path.CubicBezier(
          svg_path.Point(519.4675806753132, 313.27349449897866),
          svg_path.Point(519.4675806753132, 313.27349449897866),
          svg_path.Point(570.0, 290.0),
          svg_path.Point(570.0, 290.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(575.8176000300631, 323.58556812217466),
          svg_path.Point(575.8176000300631, 323.58556812217466),
          svg_path.Point(560.0, 300.0),
          svg_path.Point(560.0, 300.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(560.0, 300.0),
          svg_path.Point(560.0, 300.0),
          svg_path.Point(522.421811145802, 296.21971842903645),
          svg_path.Point(522.421811145802, 296.21971842903645),
        ),
        svg_path.CubicBezier(
          svg_path.Point(522.421811145802, 296.21971842903645),
          svg_path.Point(522.421811145802, 296.21971842903645),
          svg_path.Point(575.8176000300631, 323.58556812217466),
          svg_path.Point(575.8176000300631, 323.58556812217466),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 166")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(87.34388521634615, 0.0),
          svg_path.Point(89.47692985417628, 0.0),
          svg_path.Point(90.69686869177849, 0.0),
          svg_path.Point(93.61538461538461, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(93.61538461538461, 0.0),
          svg_path.Point(95.86924970121808, 0.0),
          svg_path.Point(98.06228692291116, 0.0),
          svg_path.Point(100.17943209134619, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(100.17943209134619, 0.0),
          svg_path.Point(108.57190504807696, 0.0),
          svg_path.Point(96.04819300962139, 0.0),
          svg_path.Point(100.17943209134613, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(100.17943209134613, 0.0),
          svg_path.Point(97.99141626602561, 0.0),
          svg_path.Point(95.80340044070509, 0.0),
          svg_path.Point(93.61538461538458, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(93.61538461538458, 0.0),
          svg_path.Point(91.52488481570511, 0.0),
          svg_path.Point(83.40564808627371, 0.0),
          svg_path.Point(87.34388521634615, 0.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(163.8269230769231, 0.0),
          svg_path.Point(163.8269230769231, 0.0),
          svg_path.Point(162.51045673076925, 0.0),
          svg_path.Point(160.90144230769232, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(160.90144230769232, 0.0),
          svg_path.Point(160.90144230769232, 0.0),
          svg_path.Point(2.9254807692307696, 0.0),
          svg_path.Point(2.9254807692307696, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(2.9254807692307696, 0.0),
          svg_path.Point(1.3164663461538462, 0.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(163.8269230769231, 0.0),
          svg_path.Point(163.8269230769231, 0.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 167")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(87.34388521634615, 0.0),
          svg_path.Point(89.47692985417628, 0.0),
          svg_path.Point(90.69686869177849, 0.0),
          svg_path.Point(93.61538461538461, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(93.61538461538461, 0.0),
          svg_path.Point(95.86924970121808, 0.0),
          svg_path.Point(98.06228692291116, 0.0),
          svg_path.Point(100.17943209134619, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(100.17943209134619, 0.0),
          svg_path.Point(108.57190504807696, 0.0),
          svg_path.Point(96.04819300962139, 0.0),
          svg_path.Point(100.17943209134613, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(100.17943209134613, 0.0),
          svg_path.Point(97.99141626602561, 0.0),
          svg_path.Point(95.80340044070509, 0.0),
          svg_path.Point(93.61538461538458, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(93.61538461538458, 0.0),
          svg_path.Point(91.52488481570511, 0.0),
          svg_path.Point(83.40564808627371, 0.0),
          svg_path.Point(87.34388521634615, 0.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(163.8269230769231, 0.0),
          svg_path.Point(163.8269230769231, 0.0),
          svg_path.Point(162.51045673076925, 0.0),
          svg_path.Point(160.90144230769232, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(160.90144230769232, 0.0),
          svg_path.Point(160.90144230769232, 0.0),
          svg_path.Point(2.9254807692307696, 0.0),
          svg_path.Point(2.9254807692307696, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(2.9254807692307696, 0.0),
          svg_path.Point(1.3164663461538462, 0.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(0.0, 0.0),
          svg_path.Point(0.0, 0.0),
          svg_path.Point(163.8269230769231, 0.0),
          svg_path.Point(163.8269230769231, 0.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 168")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(419.20344565830516, 384.34607379092466),
          svg_path.Point(425.04815926971787, 387.6591327004702),
          svg_path.Point(427.941075223922, 387.9468747851167),
          svg_path.Point(428.86729335526616, 387.89185123961016),
        ),
        svg_path.CubicBezier(
          svg_path.Point(428.86729335526616, 387.89185123961016),
          svg_path.Point(429.29228095238165, 387.65969641347436),
          svg_path.Point(432.001694493485, 385.99168124442735),
          svg_path.Point(435.779815245083, 378.8642364642914),
        ),
        svg_path.CubicBezier(
          svg_path.Point(435.779815245083, 378.8642364642914),
          svg_path.Point(469.13789458845304, 315.93404335421235),
          svg_path.Point(450.82863362289356, 115.32838236029176),
          svg_path.Point(450.67092429122897, 114.66066752109714),
        ),
        svg_path.CubicBezier(
          svg_path.Point(450.67092429122897, 114.66066752109714),
          svg_path.Point(450.67092429122897, 114.66066752109714),
          svg_path.Point(509.0642354962074, 100.86859709934615),
          svg_path.Point(509.0642354962074, 100.86859709934615),
        ),
        svg_path.CubicBezier(
          svg_path.Point(509.0642354962074, 100.86859709934615),
          svg_path.Point(509.4488553957749, 102.49701319673306),
          svg_path.Point(533.3782915770553, 322.85371008213895),
          svg_path.Point(488.7924194877915, 406.96519359044566),
        ),
        svg_path.CubicBezier(
          svg_path.Point(488.7924194877915, 406.96519359044566),
          svg_path.Point(481.0126918137529, 421.6416909940165),
          svg_path.Point(468.94869065290186, 436.8369131229404),
          svg_path.Point(450.18891090883824, 443.98419110432206),
        ),
        svg_path.CubicBezier(
          svg_path.Point(450.18891090883824, 443.98419110432206),
          svg_path.Point(429.4968216603384, 451.8676586019289),
          svg_path.Point(408.35881253873276, 447.16792138717295),
          svg_path.Point(389.6155630157278, 436.5433649153602),
        ),
        svg_path.CubicBezier(
          svg_path.Point(389.6155630157278, 436.5433649153602),
          svg_path.Point(389.6155630157278, 436.5433649153602),
          svg_path.Point(419.20344565830516, 384.34607379092466),
          svg_path.Point(419.20344565830516, 384.34607379092466),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(450.6709242911992, 114.66066752097116),
          svg_path.Point(444.9391376686797, 90.39324502522116),
          svg_path.Point(448.6487274879711, 141.038293563678),
          svg_path.Point(482.8570018902509, 137.6104246789113),
        ),
        svg_path.CubicBezier(
          svg_path.Point(482.8570018902509, 137.6104246789113),
          svg_path.Point(482.8570018902509, 137.6104246789113),
          svg_path.Point(476.874611665169, 77.90941122692003),
          svg_path.Point(476.874611665169, 77.90941122692003),
        ),
        svg_path.CubicBezier(
          svg_path.Point(476.874611665169, 77.90941122692003),
          svg_path.Point(511.0837452375008, 74.48145624829624),
          svg_path.Point(514.7945182846138, 125.12965261387531),
          svg_path.Point(509.0642354962372, 100.8685970994721),
        ),
        svg_path.CubicBezier(
          svg_path.Point(509.0642354962372, 100.8685970994721),
          svg_path.Point(509.0642354962372, 100.8685970994721),
          svg_path.Point(450.6709242911992, 114.66066752097116),
          svg_path.Point(450.6709242911992, 114.66066752097116),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 169")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(419.20344565830516, 384.34607379092466),
          svg_path.Point(425.04815926971787, 387.6591327004702),
          svg_path.Point(427.941075223922, 387.9468747851167),
          svg_path.Point(428.86729335526616, 387.89185123961016),
        ),
        svg_path.CubicBezier(
          svg_path.Point(428.86729335526616, 387.89185123961016),
          svg_path.Point(429.29228095238165, 387.65969641347436),
          svg_path.Point(432.001694493485, 385.99168124442735),
          svg_path.Point(435.779815245083, 378.8642364642914),
        ),
        svg_path.CubicBezier(
          svg_path.Point(435.779815245083, 378.8642364642914),
          svg_path.Point(469.13789458845304, 315.93404335421235),
          svg_path.Point(450.82863362289356, 115.32838236029176),
          svg_path.Point(450.67092429122897, 114.66066752109714),
        ),
        svg_path.CubicBezier(
          svg_path.Point(450.67092429122897, 114.66066752109714),
          svg_path.Point(450.67092429122897, 114.66066752109714),
          svg_path.Point(509.0642354962074, 100.86859709934615),
          svg_path.Point(509.0642354962074, 100.86859709934615),
        ),
        svg_path.CubicBezier(
          svg_path.Point(509.0642354962074, 100.86859709934615),
          svg_path.Point(509.4488553957749, 102.49701319673306),
          svg_path.Point(533.3782915770553, 322.85371008213895),
          svg_path.Point(488.7924194877915, 406.96519359044566),
        ),
        svg_path.CubicBezier(
          svg_path.Point(488.7924194877915, 406.96519359044566),
          svg_path.Point(481.0126918137529, 421.6416909940165),
          svg_path.Point(468.94869065290186, 436.8369131229404),
          svg_path.Point(450.18891090883824, 443.98419110432206),
        ),
        svg_path.CubicBezier(
          svg_path.Point(450.18891090883824, 443.98419110432206),
          svg_path.Point(429.4968216603384, 451.8676586019289),
          svg_path.Point(408.35881253873276, 447.16792138717295),
          svg_path.Point(389.6155630157278, 436.5433649153602),
        ),
        svg_path.CubicBezier(
          svg_path.Point(389.6155630157278, 436.5433649153602),
          svg_path.Point(389.6155630157278, 436.5433649153602),
          svg_path.Point(419.20344565830516, 384.34607379092466),
          svg_path.Point(419.20344565830516, 384.34607379092466),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(450.6709242911992, 114.66066752097116),
          svg_path.Point(444.9391376686797, 90.39324502522116),
          svg_path.Point(448.6487274879711, 141.038293563678),
          svg_path.Point(482.8570018902509, 137.6104246789113),
        ),
        svg_path.CubicBezier(
          svg_path.Point(482.8570018902509, 137.6104246789113),
          svg_path.Point(482.8570018902509, 137.6104246789113),
          svg_path.Point(476.874611665169, 77.90941122692003),
          svg_path.Point(476.874611665169, 77.90941122692003),
        ),
        svg_path.CubicBezier(
          svg_path.Point(476.874611665169, 77.90941122692003),
          svg_path.Point(511.0837452375008, 74.48145624829624),
          svg_path.Point(514.7945182846138, 125.12965261387531),
          svg_path.Point(509.0642354962372, 100.8685970994721),
        ),
        svg_path.CubicBezier(
          svg_path.Point(509.0642354962372, 100.8685970994721),
          svg_path.Point(509.0642354962372, 100.8685970994721),
          svg_path.Point(450.6709242911992, 114.66066752097116),
          svg_path.Point(450.6709242911992, 114.66066752097116),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.intersection_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 172")
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
  io.println("Fixture 173")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(100.0, 200.0),
          svg_path.Point(100.0, 200.0),
          svg_path.Point(100.0, 100.0),
          svg_path.Point(100.0, 100.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(100.0, 100.0),
          svg_path.Point(100.0, 100.0),
          svg_path.Point(300.0, 100.0),
          svg_path.Point(300.0, 100.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.0, 100.0),
          svg_path.Point(300.0, 100.0),
          svg_path.Point(300.0, 200.0),
          svg_path.Point(300.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.0, 200.0),
          svg_path.Point(300.0, 200.0),
          svg_path.Point(100.0, 200.0),
          svg_path.Point(100.0, 200.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(200.0, 100.0),
          svg_path.Point(255.22847000000002, 100.0),
          svg_path.Point(300.0, 144.77152999999998),
          svg_path.Point(300.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(300.0, 200.0),
          svg_path.Point(300.0, 200.0),
          svg_path.Point(100.0, 200.0),
          svg_path.Point(100.0, 200.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(100.0, 200.0),
          svg_path.Point(100.0, 144.77152999999998),
          svg_path.Point(144.77152999999998, 100.0),
          svg_path.Point(200.0, 100.0),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.difference_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 175")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(10.0, 10.0),
          svg_path.Point(10.0, 10.0),
          svg_path.Point(100.0, 100.0),
          svg_path.Point(100.0, 100.0),
        ),
      ])
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(20.0, 80.0),
          svg_path.Point(20.0, 80.0),
          svg_path.Point(80.0, 20.0),
          svg_path.Point(80.0, 20.0),
        ),
      ])
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
}
