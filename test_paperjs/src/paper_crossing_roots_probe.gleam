// Diagnostic only: prints observed failures, not assertions that errors are correct.
// Paper.js-derived inputs: scripts/paperjs/upstream/LICENSE.txt.
import gleam/io
import gleam/string
import svg_path
import svg_path/internal/root

pub fn main() {
  io.println("reversed monotone root candidates")
  io.println(
    string.inspect(root.real_cubic_01_roots(
      0.0 -. 0.0 +. 3.0 *. 0.0 -. 3.0 *. 1.9 +. 8.0,
      3.0 *. { 0.0 -. 2.0 *. 0.0 +. 1.9 },
      0.0,
      -5.0e-12,
      options: root.PolynomialOptions(100),
    )),
  )
  io.println("Fixture 103")
  io.println(
    string.inspect(svg_path.segment_ray_crossings_with(
      svg_path.CubicBezier(
        svg_path.Point(312.1968, 265.6776),
        svg_path.Point(309.55039999999997, 271.324),
        svg_path.Point(299.9904, 273.3128),
        svg_path.Point(294.4, 273.3128),
      ),
      origin: svg_path.Point(0.0, 273.3127999999945),
      direction: svg_path.Point(1.0, 0.0),
      options: svg_path.CrossingOptions(100, 1.0e-12, 100),
    )),
  )
  io.println("Fixture 107")
  io.println(
    string.inspect(svg_path.segment_ray_crossings_with(
      svg_path.CubicBezier(
        svg_path.Point(512.0, 640.0),
        svg_path.Point(512.0, 640.0),
        svg_path.Point(388.0405751528448, 332.07994673131026),
        svg_path.Point(288.04, 332.0799999999999),
      ),
      origin: svg_path.Point(0.0, 332.0799999999999),
      direction: svg_path.Point(1.0, 0.0),
      options: svg_path.CrossingOptions(100, 1.0e-12, 100),
    )),
  )
  io.println("Fixture 128")
  io.println(
    string.inspect(svg_path.segment_ray_crossings_with(
      svg_path.CubicBezier(
        svg_path.Point(487.8821067425946, 340.2688405948006),
        svg_path.Point(487.8821067425946, 340.2688405948006),
        svg_path.Point(529.4025393039343, 348.4286400051758),
        svg_path.Point(529.4025393039343, 348.4286400051758),
      ),
      origin: svg_path.Point(529.402539303881, 0.0),
      direction: svg_path.Point(0.0, 1.0),
      options: svg_path.CrossingOptions(100, 1.0e-12, 100),
    )),
  )
  io.println("Fixture 129")
  io.println(
    string.inspect(svg_path.segment_ray_crossings_with(
      svg_path.CubicBezier(
        svg_path.Point(487.8821067425946, 340.2688405948006),
        svg_path.Point(487.8821067425946, 340.2688405948006),
        svg_path.Point(529.4025393039343, 348.4286400051758),
        svg_path.Point(529.4025393039343, 348.4286400051758),
      ),
      origin: svg_path.Point(529.402539303881, 0.0),
      direction: svg_path.Point(0.0, 1.0),
      options: svg_path.CrossingOptions(100, 1.0e-12, 100),
    )),
  )
  io.println("Fixture 130")
  io.println(
    string.inspect(svg_path.segment_ray_crossings_with(
      svg_path.CubicBezier(
        svg_path.Point(100.10301277238074, 299.8360064274938),
        svg_path.Point(100.10301277238074, 299.8360064274938),
        svg_path.Point(192.98476439737567, 381.03840618337944),
        svg_path.Point(192.98476439737567, 381.03840618337944),
      ),
      origin: svg_path.Point(0.0, 381.03840618333726),
      direction: svg_path.Point(1.0, 0.0),
      options: svg_path.CrossingOptions(100, 1.0e-12, 100),
    )),
  )
  io.println("Fixture 131")
  io.println(
    string.inspect(svg_path.segment_ray_crossings_with(
      svg_path.CubicBezier(
        svg_path.Point(100.10301277238074, 299.8360064274938),
        svg_path.Point(100.10301277238074, 299.8360064274938),
        svg_path.Point(192.98476439737567, 381.03840618337944),
        svg_path.Point(192.98476439737567, 381.03840618337944),
      ),
      origin: svg_path.Point(0.0, 381.03840618333726),
      direction: svg_path.Point(1.0, 0.0),
      options: svg_path.CrossingOptions(100, 1.0e-12, 100),
    )),
  )
  io.println("Fixture 168")
  io.println(
    string.inspect(svg_path.segment_ray_crossings_with(
      svg_path.CubicBezier(
        svg_path.Point(479.86630925710153, 107.76493242524054),
        svg_path.Point(465.2684050136691, 111.21284998937328),
        svg_path.Point(450.6709242911992, 114.66066752097116),
        svg_path.Point(450.6709242911992, 114.66066752097116),
      ),
      origin: svg_path.Point(450.67092429122897, 0.0),
      direction: svg_path.Point(0.0, 1.0),
      options: svg_path.CrossingOptions(100, 1.0e-12, 100),
    )),
  )
  io.println("Fixture 169")
  io.println(
    string.inspect(svg_path.segment_ray_crossings_with(
      svg_path.CubicBezier(
        svg_path.Point(479.86630925710153, 107.76493242524054),
        svg_path.Point(465.2684050136691, 111.21284998937328),
        svg_path.Point(450.6709242911992, 114.66066752097116),
        svg_path.Point(450.6709242911992, 114.66066752097116),
      ),
      origin: svg_path.Point(450.67092429122897, 0.0),
      direction: svg_path.Point(0.0, 1.0),
      options: svg_path.CrossingOptions(100, 1.0e-12, 100),
    )),
  )
  io.println("monotone")
  io.println(
    string.inspect(svg_path.segment_ray_crossings_with(
      svg_path.CubicBezier(
        svg_path.Point(0.0, 8.0),
        svg_path.Point(0.3333333333333333, 1.9),
        svg_path.Point(0.6666666666666666, 0.0),
        svg_path.Point(1.0, 0.0),
      ),
      origin: svg_path.Point(0.0, 5.0e-12),
      direction: svg_path.Point(-1.0, 0.0),
      options: svg_path.CrossingOptions(100, 1.0e-12, 100),
    )),
  )
  io.println("monotone_reversed")
  io.println(
    string.inspect(svg_path.segment_ray_crossings_with(
      svg_path.CubicBezier(
        svg_path.Point(0.0, 0.0),
        svg_path.Point(0.3333333333333333, 0.0),
        svg_path.Point(0.6666666666666666, 1.9),
        svg_path.Point(1.0, 8.0),
      ),
      origin: svg_path.Point(0.0, 5.0e-12),
      direction: svg_path.Point(-1.0, 0.0),
      options: svg_path.CrossingOptions(100, 1.0e-12, 100),
    )),
  )
  io.println("two_roots")
  io.println(
    string.inspect(svg_path.segment_ray_crossings_with(
      svg_path.CubicBezier(
        svg_path.Point(0.0, -1000.0),
        svg_path.Point(0.3333333333333333, -1000.0),
        svg_path.Point(0.6666666666666666, 0.0001),
        svg_path.Point(1.0, 0.0),
      ),
      origin: svg_path.Point(0.0, 0.0),
      direction: svg_path.Point(-1.0, 0.0),
      options: svg_path.CrossingOptions(100, 1.0e-12, 100),
    )),
  )
  io.println("two_roots_reversed")
  io.println(
    string.inspect(svg_path.segment_ray_crossings_with(
      svg_path.CubicBezier(
        svg_path.Point(0.0, 0.0),
        svg_path.Point(0.3333333333333333, 0.0001),
        svg_path.Point(0.6666666666666666, -1000.0),
        svg_path.Point(1.0, -1000.0),
      ),
      origin: svg_path.Point(0.0, 0.0),
      direction: svg_path.Point(-1.0, 0.0),
      options: svg_path.CrossingOptions(100, 1.0e-12, 100),
    )),
  )
  io.println("subsequent_128_no_root")
  io.println(
    string.inspect(svg_path.segment_ray_crossings_with(
      svg_path.CubicBezier(
        svg_path.Point(518.8256109308445, 384.2317022309883),
        svg_path.Point(518.8256109308445, 384.2317022309883),
        svg_path.Point(487.8821067425946, 340.2688405948006),
        svg_path.Point(487.8821067425946, 340.2688405948006),
      ),
      origin: svg_path.Point(487.8821067425581, 340.26884059479363),
      direction: svg_path.Point(0.0, 1.0),
      options: svg_path.CrossingOptions(100, 1.0e-12, 100),
    )),
  )
}
