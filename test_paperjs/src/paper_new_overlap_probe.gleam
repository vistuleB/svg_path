// Diagnostic inputs adapted from pinned Paper.js; MIT license in
// scripts/paperjs/upstream/LICENSE.txt. Errors are printed, not asserted correct.
import gleam/io
import gleam/result
import gleam/string
import svg_path
import svg_path/csg

pub fn main() {
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
}
