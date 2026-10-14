import gleam/float
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import svg_path
import svg_path/basic_shapes
import svg_path/containment
import svg_path/distance
import svg_path/offset
import svg_path/parse
import svg_path/point
import svg_path/serialize
import svg_path/stroke

fn near(a: Float, b: Float) {
  assert float.absolute_value(a -. b) <. 0.00000001
}

fn contains(path, p) {
  let assert Ok(c) = containment.path_containment(p, path, svg_path.Nonzero)
  c != svg_path.Outside
}

fn rect(x, y, w, h, r) {
  let assert Ok(s) =
    basic_shapes.rect(x:, y:, width: w, height: h, rx: r, ry: r)
  s
}

pub fn main() {
  let assert Ok(circle) = basic_shapes.circle(cx: 0.0, cy: 0.0, r: 100.0)
  let assert Ok(ellipse) =
    basic_shapes.ellipse(cx: 0.0, cy: 0.0, rx: 50.0, ry: 100.0)
  let rectangle = rect(-50.0, -100.0, 100.0, 200.0, None)
  list.each(
    [
      #("circle", svg_path.Point(0.0, 0.0), True),
      #("circle", svg_path.Point(0.0, -100.0), True),
      #("circle", svg_path.Point(70.00357133746822, 70.0035713374682), True),
      #("circle", svg_path.Point(70.71067811865476, 70.71067811865474), True),
      #("circle", svg_path.Point(71.41778489984131, 71.4177848998413), False),
      #("ellipse", svg_path.Point(0.0, 0.0), True),
      #("ellipse", svg_path.Point(0.0, -100.0), True),
      #("ellipse", svg_path.Point(31.819805153394643, 63.63961030678927), True),
      #("ellipse", svg_path.Point(35.35533905932738, 70.71067811865474), True),
      #("ellipse", svg_path.Point(38.89087296526012, 77.78174593052023), False),
      #("rectangle", svg_path.Point(0.0, 0.0), True),
      #("rectangle", svg_path.Point(0.0, 90.0), True),
      #("rectangle", svg_path.Point(0.0, 100.0), True),
      #("rectangle", svg_path.Point(0.0, 110.00000000000001), False),
      #("rectangle", svg_path.Point(45.0, 0.0), True),
      #("rectangle", svg_path.Point(50.0, 0.0), True),
      #("rectangle", svg_path.Point(55.00000000000001, 0.0), False),
    ],
    fn(sample) {
      let s = case sample.0 {
        "circle" -> circle
        "ellipse" -> ellipse
        _ -> rectangle
      }
      let path = svg_path.subpath_as_path(s)
      list.each([svg_path.Nonzero, svg_path.EvenOdd], fn(rule) {
        let assert Ok(c) = containment.path_containment(sample.1, path, rule)
        assert { c != svg_path.Outside } == sample.2
      })
    },
  )
  io.println("PASS Shape containment: 17 upstream points, both fill rules")
  assert !contains(svg_path.path_empty(), svg_path.Point(0.0, 0.0))
  io.println("PASS empty-path containment (geometry portion of #1651)")
  let r = svg_path.subpath_as_path(rect(0.0, 0.0, 100.0, 100.0, None))
  let q = svg_path.Point(0.00000000000002842, 0.0)
  let assert Ok(d) = distance.path_distance(q, r)
  near(d, 0.0)
  assert contains(r, q)
  io.println("PASS HitResult near-endpoint geometry")
  let r = svg_path.subpath_as_path(rect(50.0, 50.0, 150.0, 150.0, None))
  let q = svg_path.Point(207.07106781186548, 207.07106781186548)
  let assert Ok(d) = distance.path_distance(q, r)
  near(d, 10.0)
  io.println("PASS HitResult tolerance distance")
  let r = rect(100.0, 100.0, 300.0, 200.0, None)
  let assert Ok(outline) =
    stroke.subpath(r, width: 20.0, join: offset.Miter(10.0), cap: offset.Butt)
  assert contains(outline, svg_path.Point(410.0, 90.0))
  io.println("PASS HitResult miter-corner stroke containment")
  let r = rect(0.0, 0.0, 300.0, 180.0, Some(90.0))
  let raw = stroke.subpath(r, width: 30.0, join: offset.Round, cap: offset.Butt)
  case raw {
    Error(e) -> io.println("FAIL rounded stroke: " <> string.inspect(e))
    Ok(_) -> io.println("PASS rounded stroke")
  }
  let cleaned =
    svg_path.subpath_segments(r)
    |> list.filter(fn(s) {
      case s {
        svg_path.Line(start:, end:) -> start != end
        _ -> True
      }
    })
    |> svg_path.subpath_assert
    |> svg_path.subpath_assert_close
  let assert Ok(outline) =
    stroke.subpath(cleaned, width: 30.0, join: offset.Round, cap: offset.Butt)
  list.each(
    [
      svg_path.Point(90.0, -10.0),
      svg_path.Point(90.0, 190.0),
      svg_path.Point(-10.0, 90.0),
    ],
    fn(p) {
      assert contains(outline, p)
    },
  )
  io.println("PASS #1207 after removing only two zero-length lines")
  let assert Ok(unit) = point.normalize(svg_path.Point(0.0, 10.0))
  assert unit == svg_path.Point(0.0, 1.0)
  assert point.rotate_90_clockwise(svg_path.Point(100.0, 50.0))
    == svg_path.Point(-50.0, 100.0)
  io.println("PASS Point normalize and quarter rotation")
  let assert Ok(p) = parse.path("M0.123456789,1.9l0.8,1.1")
  list.each([#(5, "M0.12346 1.9l0.8 1.1"), #(0, "M0 2l1 1")], fn(item) {
    let serialized =
      serialize.path_with(p, serialize.relative_decimal_options(item.0))
    let assert Ok(actual) = parse.path(serialized)
    let assert Ok(expected) = parse.path(item.1)
    assert actual == expected
  })
  io.println("PASS SvgExport precision 5 and 0 path geometry")
}
