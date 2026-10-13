// Diagnostic inputs adapted from pinned Paper.js; MIT license in
// scripts/paperjs/upstream/LICENSE.txt. Errors are printed, not asserted correct.
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import svg_path
import svg_path/csg
import svg_path/overlaps

pub fn main() {
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
  list.each([0.00001, 0.0000001], fn(minimum) {
    io.println("minimum=" <> string.inspect(minimum))
    csg.union_path_with(
      left,
      right,
      svg_path.Nonzero,
      csg.Options(0.000001, minimum),
    )
    |> result.map(fn(_) { Nil })
    |> string.inspect
    |> io.println
  })
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
  list.each([0.00001, 0.0000001], fn(minimum) {
    io.println("minimum=" <> string.inspect(minimum))
    csg.intersection_path_with(
      left,
      right,
      svg_path.Nonzero,
      csg.Options(0.000001, minimum),
    )
    |> result.map(fn(_) { Nil })
    |> string.inspect
    |> io.println
  })
  // Axis-aligned reduction of a curve piece reached by fixture 107.
  // A nondegenerate monotone cubic must overlap itself over its full domain.
  let ys = [
    337.7804798720905,
    337.780485777646,
    337.7804916832015,
    337.780497588757,
  ]
  list.each([0.0, 337.7804798720905], fn(origin) {
    let assert [a, b, c, d] =
      list.map(ys, fn(y) { svg_path.Point(736.0, y -. origin) })
    let curve = svg_path.CubicBezier(a, b, c, d)
    io.println("107 self-overlap; y origin=" <> string.inspect(origin))
    overlaps.segment_with(curve, curve, tolerance: 0.0000005)
    |> result.map(fn(hits) {
      list.map(hits, fn(hit) {
        #(hit.left_from, hit.left_to, hit.right_from, hit.right_to)
      })
    })
    |> string.inspect
    |> io.println
  })
}
