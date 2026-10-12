// Diagnostic inputs adapted from pinned Paper.js; MIT license in
// scripts/paperjs/upstream/LICENSE.txt. Errors are printed, not asserted correct.
import gleam/io
import gleam/result
import gleam/string
import svg_path
import svg_path/csg

pub fn main() {
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
  io.println("Fixture 104")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(512.0, 563.0515712),
          svg_path.Point(512.0, 563.0515712),
          svg_path.Point(462.4499456000001, 563.0515712),
          svg_path.Point(462.4499456000001, 563.0515712),
        ),
        svg_path.CubicBezier(
          svg_path.Point(462.4499456000001, 563.0515712),
          svg_path.Point(459.41844574400005, 563.0515712),
          svg_path.Point(456.94438400000007, 560.580950432),
          svg_path.Point(456.94438400000007, 557.549450576),
        ),
        svg_path.CubicBezier(
          svg_path.Point(456.94438400000007, 557.549450576),
          svg_path.Point(456.94438400000007, 557.549450576),
          svg_path.Point(512.0, 563.0515712),
          svg_path.Point(512.0, 563.0515712),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(462.4499456000001, 563.0515712),
          svg_path.Point(459.4195928158211, 563.0515712),
          svg_path.Point(456.9462563718413, 560.5793813938075),
          svg_path.Point(456.94438506256495, 557.5494505759262),
        ),
        svg_path.CubicBezier(
          svg_path.Point(456.94438506256495, 557.5494505759262),
          svg_path.Point(456.94438506256495, 557.5494505759262),
          svg_path.Point(567.0556160000001, 564.0),
          svg_path.Point(567.0556160000001, 564.0),
        ),
        svg_path.CubicBezier(
          svg_path.Point(567.0556160000001, 564.0),
          svg_path.Point(567.0556160000001, 564.0),
          svg_path.Point(459.41844574400005, 563.0515712),
          svg_path.Point(462.4499456000001, 563.0515712),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
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
  io.println("Fixture 136")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(517.5047187481108, 202.91541735696418),
          svg_path.Point(517.5047187481108, 202.91541735696418),
          svg_path.Point(545.7583411018326, 213.0016798561104),
          svg_path.Point(545.7583411018326, 213.0016798561104),
        ),
        svg_path.CubicBezier(
          svg_path.Point(545.7583411018326, 213.0016798561104),
          svg_path.Point(545.7583411018326, 213.0016798561104),
          svg_path.Point(549.5166428206164, 181.87876844776818),
          svg_path.Point(557.8431595513716, 185.5433980031361),
        ),
        svg_path.CubicBezier(
          svg_path.Point(557.8431595513716, 185.5433980031361),
          svg_path.Point(557.8431595513716, 185.5433980031361),
          svg_path.Point(545.7583424843119, 213.00167993223172),
          svg_path.Point(545.7583424843119, 213.00167993223172),
        ),
        svg_path.CubicBezier(
          svg_path.Point(545.7583424843119, 213.00167993223172),
          svg_path.Point(545.7583424843118, 213.00167993223172),
          svg_path.Point(524.0178589455097, 184.67081947050943),
          svg_path.Point(517.5047187481108, 202.91541735696418),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(550.3546243594556, 242.6474912770306),
          svg_path.Point(561.5256472266337, 240.91553715218237),
          svg_path.Point(529.9815193821828, 185.0892963250077),
          svg_path.Point(541.1620576122966, 183.35586693936358),
        ),
        svg_path.CubicBezier(
          svg_path.Point(541.1620576122966, 183.35586693936358),
          svg_path.Point(541.1620576122966, 183.35586693936358),
          svg_path.Point(550.3546243594556, 242.6474912770306),
          svg_path.Point(550.3546243594556, 242.6474912770306),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  csg.union_path(left, right, svg_path.Nonzero)
  |> result.map(fn(_) { Nil })
  |> string.inspect
  |> io.println
  io.println("Fixture 137")
  let left =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(517.5047187481108, 202.91541735696418),
          svg_path.Point(517.5047187481108, 202.91541735696418),
          svg_path.Point(545.7583411018326, 213.0016798561104),
          svg_path.Point(545.7583411018326, 213.0016798561104),
        ),
        svg_path.CubicBezier(
          svg_path.Point(545.7583411018326, 213.0016798561104),
          svg_path.Point(545.7583411018326, 213.0016798561104),
          svg_path.Point(549.5166428206164, 181.87876844776818),
          svg_path.Point(557.8431595513716, 185.5433980031361),
        ),
        svg_path.CubicBezier(
          svg_path.Point(557.8431595513716, 185.5433980031361),
          svg_path.Point(557.8431595513716, 185.5433980031361),
          svg_path.Point(545.7583424843119, 213.00167993223172),
          svg_path.Point(545.7583424843119, 213.00167993223172),
        ),
        svg_path.CubicBezier(
          svg_path.Point(545.7583424843119, 213.00167993223172),
          svg_path.Point(545.7583424843118, 213.00167993223172),
          svg_path.Point(524.0178589455097, 184.67081947050943),
          svg_path.Point(517.5047187481108, 202.91541735696418),
        ),
      ])
      |> svg_path.subpath_assert_close
      |> svg_path.subpath_as_path,
    ])
  let right =
    svg_path.path_combine([
      svg_path.subpath_assert([
        svg_path.CubicBezier(
          svg_path.Point(550.3546243594556, 242.6474912770306),
          svg_path.Point(561.5256472266337, 240.91553715218237),
          svg_path.Point(529.9815193821828, 185.0892963250077),
          svg_path.Point(541.1620576122966, 183.35586693936358),
        ),
        svg_path.CubicBezier(
          svg_path.Point(541.1620576122966, 183.35586693936358),
          svg_path.Point(541.1620576122966, 183.35586693936358),
          svg_path.Point(550.3546243594556, 242.6474912770306),
          svg_path.Point(550.3546243594556, 242.6474912770306),
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
}
