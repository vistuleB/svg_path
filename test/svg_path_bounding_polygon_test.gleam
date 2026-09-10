import gleam/int
import gleam/list
import svg_path.{type Point, Point}

fn cross(a: Point, b: Point, p: Point) -> Float {
  { b.x -. a.x } *. { p.y -. a.y } -. { b.y -. a.y } *. { p.x -. a.x }
}

fn check_enclosure(segment: svg_path.Segment, from: Float, to: Float) {
  let assert Ok(points) =
    svg_path.segment_bounding_polygon_between(segment, from, to)
  let assert [first, ..rest] = points
  let edges = list.zip(points, list.append(rest, [first]))
  assert list.length(points) >= 3
  assert list.length(list.unique(points)) == list.length(points)
  list.each(edges, fn(edge) {
    list.each(points, fn(p) {
      assert cross(edge.0, edge.1, p) >=. -0.000000001
    })
    list.each(list.index_map(list.repeat(Nil, 201), fn(_, i) { i }), fn(i) {
      let t = from +. { to -. from } *. int.to_float(i) /. 200.0
      let assert Ok(p) = svg_path.segment_point(segment, t)
      assert cross(edge.0, edge.1, p) >=. -0.000000001
    })
  })
}

pub fn bounding_polygon_line_and_point_test() {
  let a = Point(4.0, 2.0)
  let b = Point(-1.0, 3.0)
  assert svg_path.segment_bounding_polygon(svg_path.Line(a, b)) == Ok([a, b])
  assert svg_path.segment_bounding_polygon(svg_path.Line(a, a)) == Ok([a])
  assert svg_path.segment_bounding_polygon_between(
      svg_path.Line(a, b),
      1.0,
      0.0,
    )
    == Ok([b, a])
}

pub fn bounding_polygon_bezier_order_and_interior_start_test() {
  let a = Point(0.0, 0.0)
  let q = svg_path.QuadraticBezier(a, Point(2.0, -3.0), Point(4.0, 0.0))
  let assert Ok([first, ..]) = svg_path.segment_bounding_polygon(q)
  assert first == a
  check_enclosure(q, 0.0, 1.0)
  let c =
    svg_path.CubicBezier(
      a,
      Point(-3.0, -2.0),
      Point(3.0, -2.0),
      Point(0.0, 4.0),
    )
  let assert Ok(points) = svg_path.segment_bounding_polygon(c)
  assert points == [Point(-3.0, -2.0), Point(3.0, -2.0), Point(0.0, 4.0)]
  check_enclosure(c, 0.0, 1.0)
  check_enclosure(c, 0.8, 0.2)
}

pub fn bounding_polygon_collinear_controls_test() {
  let a = Point(0.0, 0.0)
  let c = svg_path.CubicBezier(a, Point(-3.0, 0.0), Point(5.0, 0.0), a)
  assert svg_path.segment_bounding_polygon(c)
    == Ok([Point(-3.0, 0.0), Point(5.0, 0.0)])
  assert svg_path.segment_bounding_polygon_between(c, 0.0, 0.0) == Ok([a])
}

pub fn bounding_polygon_arcs_test() {
  list.each([True, False], fn(sweep) {
    list.each([True, False], fn(large) {
      let arc =
        svg_path.Arc(
          Point(4.0, 0.0),
          Point(5.0, 2.0),
          37.0,
          large,
          sweep,
          Point(-1.0, 3.0),
        )
      check_enclosure(arc, 0.0, 1.0)
      check_enclosure(arc, 0.9, 0.15)
      check_enclosure(arc, 0.5, 0.500001)
    })
  })
  // Endpoint encoding requires SVG radius correction.
  check_enclosure(
    svg_path.Arc(
      Point(-4.0, 0.0),
      Point(1.0, 1.0),
      0.0,
      False,
      True,
      Point(4.0, 0.0),
    ),
    0.0,
    1.0,
  )
}

pub fn bounding_polygon_invalid_interval_and_arc_test() {
  let a = Point(0.0, 0.0)
  assert svg_path.segment_bounding_polygon_between(
      svg_path.Line(a, a),
      -0.1,
      1.0,
    )
    == Error(svg_path.SplitOutsideSegment)
  assert svg_path.segment_bounding_polygon(svg_path.Arc(
      a,
      Point(1.0, 1.0),
      0.0,
      False,
      True,
      a,
    ))
    == Error(svg_path.DegenerateArc)
}
