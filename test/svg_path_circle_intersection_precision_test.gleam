import gleam/float
import gleam/list
import svg_path.{Arc, Line, Point}
import svg_path/area
import svg_path/intersections
import svg_path/measure
import svg_path/offset

fn pair(shift: Float) -> #(svg_path.Segment, svg_path.Segment) {
  let r = 1.4142135623730951
  #(
    Arc(
      Point(10.585786437626904, 10.0),
      Point(r, r),
      0.0,
      False,
      False,
      Point(12.0, 11.414213562373096),
    ),
    Arc(
      Point(11.414213562373096 +. shift, 12.0),
      Point(r, r),
      0.0,
      False,
      False,
      Point(10.0 +. shift, 10.585786437626904),
    ),
  )
}

pub fn near_tangent_circles_preserve_both_roots_test() {
  // 80-digit circle intersections of these exact binary64 SVG inputs.
  // See scripts/cavalier/tangent-timeout-circle-oracle.py.
  let #(a, b) = pair(0.0)
  list.each([False, True], fn(reverse) {
    let a = case reverse {
      True -> svg_path.segment_reverse(a)
      False -> a
    }
    let b = case reverse {
      True -> svg_path.segment_reverse(b)
      False -> b
    }
    let assert Ok(hits) = intersections.segment(a, b)
    assert list.length(hits) == 2
    let xs = hits |> list.map(fn(h) { h.point.x }) |> list.sort(float.compare)
    let assert [lo, hi] = xs
    assert float.absolute_value(lo -. 10.999999961672676) <. 1.0e-10
    assert float.absolute_value(hi -. 11.000000038327324) <. 1.0e-10
  })
}

pub fn nearby_circle_separation_and_intersection_test() {
  let #(a, b) = pair(-0.00001)
  let assert Ok([]) = intersections.segment(a, b)
  let #(a, b) = pair(0.00001)
  let assert Ok(hits) = intersections.segment(a, b)
  assert list.length(hits) == 2
  list.each(hits, fn(hit) {
    let assert Ok(p) = svg_path.segment_point(a, hit.left_t)
    let assert Ok(q) = svg_path.segment_point(b, hit.right_t)
    assert float.absolute_value(p.x -. q.x) <. 1.0e-9
    assert float.absolute_value(p.y -. q.y) <. 1.0e-9
  })
}

pub fn near_tangent_offset_avoids_fragment_growth_test() {
  let points = [
    Point(0.0, 0.0),
    Point(12.0, 0.0),
    Point(12.0, 10.0),
    Point(22.0, 10.0),
    Point(22.0, 22.0),
    Point(10.0, 22.0),
    Point(10.0, 12.0),
    Point(0.0, 12.0),
    Point(0.0, 0.0),
  ]
  let assert Ok(source) = svg_path.subpath(lines(points))
  let assert Ok(source) = svg_path.subpath_close(source)
  list.each([False, True], fn(reverse) {
    let source = case reverse {
      True -> svg_path.subpath_reverse(source)
      False -> source
    }
    let distance = case reverse {
      True -> 1.4142135623730951
      False -> -1.4142135623730951
    }
    let assert Ok(path) =
      offset.subpath(source, distance, offset.Round, offset.Butt)
    let assert [contour] = path.subpaths
    let assert Ok(length) = measure.subpath_length(contour)
    assert float.absolute_value(length -. 75.47232018968121) <. 1.0e-7
    assert float.absolute_value(
        float.absolute_value(area.signed_subpath(contour)) -. 168.40761385757781,
      )
      <. 1.0e-7
    // Bound fragmentation rather than asserting machine-dependent elapsed time.
    assert list.length(svg_path.subpath_segments(contour)) <= 32
  })
}

fn lines(points: List(svg_path.Point)) -> List(svg_path.Segment) {
  case points {
    [a, b, ..rest] -> [Line(a, b), ..lines([b, ..rest])]
    _ -> []
  }
}

pub fn circular_intersections_scale_translate_and_reverse_test() {
  list.each([0.125, 1.0, 8.0], fn(scale) {
    list.each([0.0, 128.0], fn(translation) {
      list.each([-0.00001, 0.00001], fn(shift) {
        let #(a, b) = pair(shift)
        let map = fn(p: svg_path.Point) {
          Point(p.x *. scale +. translation, p.y *. scale -. translation)
        }
        let assert Arc(start: pa, end: qa, radius: ra, ..) = a
        let assert Arc(start: pb, end: qb, radius: rb, ..) = b
        let a =
          Arc(
            map(pa),
            Point(ra.x *. scale, ra.y *. scale),
            37.0,
            False,
            False,
            map(qa),
          )
        let b =
          Arc(
            map(pb),
            Point(rb.x *. scale, rb.y *. scale),
            -21.0,
            False,
            False,
            map(qb),
          )
        list.each([False, True], fn(reverse) {
          let a = case reverse {
            True -> svg_path.segment_reverse(a)
            False -> a
          }
          let b = case reverse {
            True -> svg_path.segment_reverse(b)
            False -> b
          }
          let assert Ok(hits) = intersections.segment(a, b)
          assert list.length(hits)
            == case shift >. 0.0 {
              True -> 2
              False -> 0
            }
        })
      })
    })
  })
}
