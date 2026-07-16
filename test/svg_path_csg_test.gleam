import gleam/float
import gleam/list
import gleeunit
import svg_path
import svg_path/area
import svg_path/csg

const tolerance = 0.000001

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn union_combines_overlapping_rectangles_test() {
  let left = rectangle(0.0, 0.0, 10.0, 10.0)
  let right = rectangle(5.0, 0.0, 15.0, 10.0)

  let assert Ok(union) = csg.union(left, right, using: svg_path.Nonzero)

  assert_area(union, 150.0)
  assert_inside(union, svg_path.point(2.5, 5.0))
  assert_inside(union, svg_path.point(12.5, 5.0))
  assert_inside(union, svg_path.point(7.5, 5.0))
  assert_outside(union, svg_path.point(20.0, 5.0))
}

pub fn intersection_returns_overlap_of_rectangles_test() {
  let left = rectangle(0.0, 0.0, 10.0, 10.0)
  let right = rectangle(5.0, 0.0, 15.0, 10.0)

  let assert Ok(intersection) =
    csg.intersection(left, right, using: svg_path.Nonzero)

  assert_area(intersection, 50.0)
  assert_outside(intersection, svg_path.point(2.5, 5.0))
  assert_outside(intersection, svg_path.point(12.5, 5.0))
  assert_inside(intersection, svg_path.point(7.5, 5.0))
}

pub fn difference_cuts_right_rectangle_from_left_test() {
  let left = rectangle(0.0, 0.0, 10.0, 10.0)
  let right = rectangle(5.0, 0.0, 15.0, 10.0)

  let assert Ok(difference) =
    csg.difference(left, minus: right, using: svg_path.Nonzero)

  assert_area(difference, 50.0)
  assert_inside(difference, svg_path.point(2.5, 5.0))
  assert_outside(difference, svg_path.point(7.5, 5.0))
  assert_outside(difference, svg_path.point(12.5, 5.0))
}

pub fn difference_preserves_inner_hole_orientation_test() {
  let outer = rectangle(0.0, 0.0, 20.0, 20.0)
  let inner = rectangle(5.0, 5.0, 15.0, 15.0)

  let assert Ok(difference) =
    csg.difference(outer, minus: inner, using: svg_path.Nonzero)

  assert_area(difference, 300.0)
  assert_inside(difference, svg_path.point(2.5, 2.5))
  assert_outside(difference, svg_path.point(10.0, 10.0))
  assert_inside(difference, svg_path.point(17.5, 17.5))
}

pub fn disjoint_union_returns_both_components_test() {
  let left = rectangle(0.0, 0.0, 10.0, 10.0)
  let right = rectangle(20.0, 0.0, 30.0, 10.0)

  let assert Ok(union) = csg.union(left, right, using: svg_path.Nonzero)

  assert_area(union, 200.0)
  assert_inside(union, svg_path.point(5.0, 5.0))
  assert_inside(union, svg_path.point(25.0, 5.0))
  assert_outside(union, svg_path.point(15.0, 5.0))
}

pub fn intersection_preserves_curve_segments_test() {
  let left = circle(svg_path.point(10.0, 10.0), 10.0)
  let right = rectangle(5.0, 0.0, 20.0, 20.0)

  let assert Ok(intersection) =
    csg.intersection(left, right, using: svg_path.Nonzero)

  assert has_arc(intersection)
  assert_inside(intersection, svg_path.point(12.5, 10.0))
  assert_outside(intersection, svg_path.point(2.5, 10.0))
}

fn rectangle(
  min_x: Float,
  min_y: Float,
  max_x: Float,
  max_y: Float,
) -> svg_path.Path {
  svg_path.from_subpath(
    svg_path.assert_polygon([
      svg_path.point(min_x, min_y),
      svg_path.point(max_x, min_y),
      svg_path.point(max_x, max_y),
      svg_path.point(min_x, max_y),
    ]),
  )
}

fn circle(center: svg_path.Point, radius: Float) -> svg_path.Path {
  let left = svg_path.point(center.x -. radius, center.y)
  let right = svg_path.point(center.x +. radius, center.y)
  svg_path.from_subpath(
    svg_path.assert_subpath([
      svg_path.Arc(
        start: right,
        radius: svg_path.point(radius, radius),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: left,
      ),
      svg_path.Arc(
        start: left,
        radius: svg_path.point(radius, radius),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: right,
      ),
    ])
    |> svg_path.assert_set_closed(closed: True),
  )
}

fn has_arc(path: svg_path.Path) -> Bool {
  path
  |> svg_path.subpaths
  |> list.flat_map(svg_path.segments)
  |> list.any(fn(segment) {
    case segment {
      svg_path.Arc(..) -> True
      _ -> False
    }
  })
}

fn assert_area(path: svg_path.Path, expected: Float) {
  let assert Ok(actual) = area.path(path, using: svg_path.Nonzero)
  assert float.absolute_value(actual -. expected) <=. tolerance
}

fn assert_inside(path: svg_path.Path, point: svg_path.Point) {
  assert svg_path.path_containment(point, within: path, using: svg_path.Nonzero)
    == Ok(svg_path.Inside)
}

fn assert_outside(path: svg_path.Path, point: svg_path.Point) {
  assert svg_path.path_containment(point, within: path, using: svg_path.Nonzero)
    == Ok(svg_path.Outside)
}
