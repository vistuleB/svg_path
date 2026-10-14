import gleam/io
import gleam/list
import gleam/string
import svg_path.{CubicBezier, Point, QuadraticBezier}
import svg_path/intersections

pub fn main() {
  {
    let a =
      QuadraticBezier(
        Point(98.0, 62.0),
        Point(-8.0, -25.0),
        Point(-25.0, -70.0),
      )
    let b =
      QuadraticBezier(
        Point(96.0, 18.0),
        Point(-114.0, -112.0),
        Point(98.0, 62.0),
      )
    io.println("CALL 1265")
    list.each([#(a, b), #(b, a)], fn(pair) {
      io.println(string.inspect(intersections.segment(pair.0, pair.1)))
    })
  }
  {
    let a =
      QuadraticBezier(Point(11.0, 40.0), Point(89.0, 67.0), Point(-7.0, 44.0))
    let b =
      QuadraticBezier(Point(19.0, 23.0), Point(185.0, 90.0), Point(-7.0, 44.0))
    io.println("CALL 1268")
    list.each([#(a, b), #(b, a)], fn(pair) {
      io.println(string.inspect(intersections.segment(pair.0, pair.1)))
    })
  }
  {
    let a =
      QuadraticBezier(
        Point(81.0, -18.0),
        Point(-96.0, -76.0),
        Point(-97.0, -98.0),
      )
    let b =
      QuadraticBezier(
        Point(81.0, -18.0),
        Point(-273.0, -134.0),
        Point(-100.0, -85.0),
      )
    io.println("CALL 1269")
    list.each([#(a, b), #(b, a)], fn(pair) {
      io.println(string.inspect(intersections.segment(pair.0, pair.1)))
    })
  }
  {
    let a =
      QuadraticBezier(
        Point(39.0, -34.0),
        Point(-94.0, 41.0),
        Point(-2.0, -40.0),
      )
    let b =
      QuadraticBezier(
        Point(-70.0, -76.0),
        Point(-186.0, 122.0),
        Point(-2.0, -40.0),
      )
    io.println("CALL 1271")
    list.each([#(a, b), #(b, a)], fn(pair) {
      io.println(string.inspect(intersections.segment(pair.0, pair.1)))
    })
  }
  {
    let a =
      QuadraticBezier(Point(35.0, -6.0), Point(71.0, 94.0), Point(-30.0, -79.0))
    let b =
      QuadraticBezier(
        Point(-45.0, 72.0),
        Point(172.0, 267.0),
        Point(-30.0, -79.0),
      )
    io.println("CALL 1276")
    list.each([#(a, b), #(b, a)], fn(pair) {
      io.println(string.inspect(intersections.segment(pair.0, pair.1)))
    })
  }
  {
    let a =
      QuadraticBezier(Point(50.0, 36.0), Point(23.0, -44.0), Point(70.0, 10.0))
    let b =
      CubicBezier(
        Point(52.0, -95.0),
        Point(81.0, -91.0),
        Point(-4.0, -124.0),
        Point(50.0, 36.0),
      )
    io.println("CALL 1283")
    list.each([#(a, b), #(b, a)], fn(pair) {
      io.println(string.inspect(intersections.segment(pair.0, pair.1)))
    })
  }
  {
    let a =
      QuadraticBezier(
        Point(-39.0, -30.0),
        Point(80.0, 96.0),
        Point(-73.0, -72.0),
      )
    let b =
      CubicBezier(
        Point(90.0, 66.0),
        Point(2.0, -32.0),
        Point(233.0, 264.0),
        Point(-73.0, -72.0),
      )
    io.println("CALL 1288")
    list.each([#(a, b), #(b, a)], fn(pair) {
      io.println(string.inspect(intersections.segment(pair.0, pair.1)))
    })
  }
  {
    let a =
      QuadraticBezier(
        Point(-10.0, 52.0),
        Point(89.0, -78.0),
        Point(-67.0, 85.0),
      )
    let b =
      CubicBezier(
        Point(-54.0, 41.0),
        Point(-27.0, 29.0),
        Point(245.0, -241.0),
        Point(-67.0, 85.0),
      )
    io.println("CALL 1294")
    list.each([#(a, b), #(b, a)], fn(pair) {
      io.println(string.inspect(intersections.segment(pair.0, pair.1)))
    })
  }
  {
    let a =
      QuadraticBezier(Point(4.0, -5.0), Point(45.0, -9.0), Point(-12.0, -16.0))
    let b =
      CubicBezier(
        Point(-12.0, -16.0),
        Point(45.0, -9.0),
        Point(56.0, -4.0),
        Point(-77.0, 39.0),
      )
    io.println("CALL 1297")
    list.each([#(a, b), #(b, a)], fn(pair) {
      io.println(string.inspect(intersections.segment(pair.0, pair.1)))
    })
  }
  {
    let a =
      CubicBezier(
        Point(-33.0, 23.0),
        Point(-24.0, -50.0),
        Point(0.0, -37.0),
        Point(74.0, -14.0),
      )
    let b =
      QuadraticBezier(
        Point(74.0, -14.0),
        Point(0.0, -37.0),
        Point(-99.0, -77.0),
      )
    io.println("CALL 1326")
    list.each([#(a, b), #(b, a)], fn(pair) {
      io.println(string.inspect(intersections.segment(pair.0, pair.1)))
    })
  }
  {
    let a =
      CubicBezier(
        Point(-62.0, -29.0),
        Point(-100.0, 13.0),
        Point(-53.0, -1.0),
        Point(-81.0, -37.0),
      )
    let b =
      QuadraticBezier(
        Point(-62.0, -29.0),
        Point(-100.0, 13.0),
        Point(0.0, -64.0),
      )
    io.println("CALL 1331")
    list.each([#(a, b), #(b, a)], fn(pair) {
      io.println(string.inspect(intersections.segment(pair.0, pair.1)))
    })
  }
  {
    let a =
      CubicBezier(
        Point(-42.0, 26.0),
        Point(-64.0, -31.0),
        Point(-12.0, 70.0),
        Point(59.0, 36.0),
      )
    let b =
      QuadraticBezier(
        Point(-42.0, 26.0),
        Point(-86.0, -88.0),
        Point(82.0, 42.0),
      )
    io.println("CALL 1335")
    list.each([#(a, b), #(b, a)], fn(pair) {
      io.println(string.inspect(intersections.segment(pair.0, pair.1)))
    })
  }
  {
    let a =
      CubicBezier(
        Point(67.0, 22.0),
        Point(35.0, 60.0),
        Point(21.0, -65.0),
        Point(10.0, 65.0),
      )
    let b =
      CubicBezier(
        Point(10.0, 65.0),
        Point(32.0, -195.0),
        Point(73.0, -32.0),
        Point(-38.0, -99.0),
      )
    io.println("CALL 1357")
    list.each([#(a, b), #(b, a)], fn(pair) {
      io.println(string.inspect(intersections.segment(pair.0, pair.1)))
    })
  }
  {
    let a =
      QuadraticBezier(
        Point(89.0, 47.0),
        Point(-53.0, -12.0),
        Point(-24.0, 24.0),
      )
    let b =
      QuadraticBezier(Point(-74.0, -17.0), Point(89.0, 47.0), Point(89.0, 47.0))
    io.println("CALL 1622")
    list.each([#(a, b), #(b, a)], fn(pair) {
      io.println(string.inspect(intersections.segment(pair.0, pair.1)))
    })
  }
  {
    let a =
      QuadraticBezier(Point(57.0, 69.0), Point(-5.0, -27.0), Point(11.0, 85.0))
    let b =
      QuadraticBezier(Point(-46.0, -89.0), Point(57.0, 69.0), Point(57.0, 69.0))
    io.println("CALL 1629")
    list.each([#(a, b), #(b, a)], fn(pair) {
      io.println(string.inspect(intersections.segment(pair.0, pair.1)))
    })
  }
  {
    let a =
      QuadraticBezier(Point(56.0, 12.0), Point(-91.0, 85.0), Point(81.0, 93.0))
    let b =
      QuadraticBezier(Point(81.0, 93.0), Point(81.0, 93.0), Point(-20.0, 78.0))
    io.println("CALL 1632")
    list.each([#(a, b), #(b, a)], fn(pair) {
      io.println(string.inspect(intersections.segment(pair.0, pair.1)))
    })
  }
  {
    let a =
      CubicBezier(
        Point(-74.0, 66.0),
        Point(95.0, 61.0),
        Point(85.0, -63.0),
        Point(98.0, 65.0),
      )
    let b =
      QuadraticBezier(
        Point(-66.0, 74.0),
        Point(-74.0, 66.0),
        Point(-74.0, 66.0),
      )
    io.println("CALL 1683")
    list.each([#(a, b), #(b, a)], fn(pair) {
      io.println(string.inspect(intersections.segment(pair.0, pair.1)))
    })
  }
  {
    let a =
      CubicBezier(
        Point(-71.0, 50.0),
        Point(-68.0, -61.0),
        Point(28.0, -33.0),
        Point(-60.0, 24.0),
      )
    let b =
      QuadraticBezier(
        Point(-60.0, 24.0),
        Point(-60.0, 24.0),
        Point(57.0, -42.0),
      )
    io.println("CALL 1690")
    list.each([#(a, b), #(b, a)], fn(pair) {
      io.println(string.inspect(intersections.segment(pair.0, pair.1)))
    })
  }
  {
    let a =
      CubicBezier(
        Point(67.0, -53.0),
        Point(-69.0, 12.0),
        Point(-44.0, -2.0),
        Point(98.0, 14.0),
      )
    let b =
      CubicBezier(
        Point(67.0, -53.0),
        Point(67.0, -53.0),
        Point(20.0, -29.0),
        Point(22.0, 35.0),
      )
    io.println("CALL 1705")
    list.each([#(a, b), #(b, a)], fn(pair) {
      io.println(string.inspect(intersections.segment(pair.0, pair.1)))
    })
  }
  {
    let a =
      CubicBezier(
        Point(-76.0, 68.0),
        Point(-57.0, 0.0),
        Point(41.0, -55.0),
        Point(47.0, 94.0),
      )
    let b =
      CubicBezier(
        Point(-84.0, 72.0),
        Point(45.0, 62.0),
        Point(47.0, 94.0),
        Point(47.0, 94.0),
      )
    io.println("CALL 1714")
    list.each([#(a, b), #(b, a)], fn(pair) {
      io.println(string.inspect(intersections.segment(pair.0, pair.1)))
    })
  }
}
