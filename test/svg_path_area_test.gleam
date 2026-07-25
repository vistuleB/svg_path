import gleam/float
import gleeunit
import svg_path
import svg_path/area

const tolerance = 0.000001

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn signed_points_implicitly_closes_the_loop_test() {
  let points = square_points(0.0, 0.0, 10.0)

  assert_close(area.signed_points(points), 100.0, tolerance)
  assert_close(area.signed_points(reverse(points)), -100.0, tolerance)
  assert area.signed_points([]) == 0.0
  assert area.signed_points([svg_path.point(0.0, 0.0)]) == 0.0
}

pub fn signed_subpath_ignores_the_closed_field_test() {
  let points = square_points(0.0, 0.0, 10.0)
  let open = svg_path.subpath_assert_polyline(points)
  let closed = svg_path.subpath_assert_polygon(points)

  assert_close(area.signed_subpath(open), 100.0, tolerance)
  assert_close(area.signed_subpath(closed), 100.0, tolerance)
}

pub fn signed_bezier_segments_use_exact_line_integrals_test() {
  let quadratic =
    svg_path.QuadraticBezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(10.0, 20.0),
      end: svg_path.point(20.0, 0.0),
    )
  let cubic =
    svg_path.CubicBezier(
      start: svg_path.point(0.0, 0.0),
      control1: svg_path.point(0.0, 10.0),
      control2: svg_path.point(10.0, 10.0),
      end: svg_path.point(10.0, 0.0),
    )

  assert_close(
    float.absolute_value(
      area.signed_subpath(
        svg_path.subpath_assert([
          quadratic,
        ]),
      ),
    ),
    133.33333333333334,
    tolerance,
  )
  assert_close(
    float.absolute_value(area.signed_subpath(svg_path.subpath_assert([cubic]))),
    60.0,
    tolerance,
  )
}

pub fn signed_arc_segment_uses_the_ellipse_integral_test() {
  let semicircle =
    svg_path.Arc(
      start: svg_path.point(-10.0, 0.0),
      radius: svg_path.point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(10.0, 0.0),
    )
  let subpath = svg_path.subpath_assert([semicircle])

  assert_close(
    float.absolute_value(area.signed_subpath(subpath)),
    157.07963267948966,
    tolerance,
  )
}

pub fn fill_area_implicitly_closes_open_subpaths_test() {
  let open = svg_path.subpath_assert_polyline(square_points(0.0, 0.0, 10.0))

  let assert Ok(nonzero) = area.subpath(open, using: svg_path.Nonzero)
  let assert Ok(even_odd) = area.subpath(open, using: svg_path.EvenOdd)

  assert_close(nonzero, 100.0, tolerance)
  assert_close(even_odd, 100.0, tolerance)
}

pub fn fill_rules_differ_for_a_twice_traced_loop_test() {
  let points = [
    svg_path.point(0.0, 0.0),
    svg_path.point(10.0, 0.0),
    svg_path.point(10.0, 10.0),
    svg_path.point(0.0, 10.0),
    svg_path.point(0.0, 0.0),
    svg_path.point(10.0, 0.0),
    svg_path.point(10.0, 10.0),
    svg_path.point(0.0, 10.0),
  ]
  let subpath = svg_path.subpath_assert_polyline(points)

  let assert Ok(nonzero) = area.subpath(subpath, using: svg_path.Nonzero)
  let assert Ok(even_odd) = area.subpath(subpath, using: svg_path.EvenOdd)
  let assert Ok(absolute) = area.absolute_subpath(subpath)

  assert_close(nonzero, 100.0, tolerance)
  assert_close(even_odd, 0.0, tolerance)
  assert_close(area.signed_subpath(subpath), 200.0, tolerance)
  assert_close(absolute, 200.0, tolerance)
}

pub fn self_intersecting_bow_tie_has_filled_but_no_signed_area_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 10.0),
      svg_path.point(0.0, 10.0),
      svg_path.point(10.0, 0.0),
    ])

  let assert Ok(nonzero) = area.subpath(subpath, using: svg_path.Nonzero)
  let assert Ok(even_odd) = area.subpath(subpath, using: svg_path.EvenOdd)
  let assert Ok(absolute) = area.absolute_subpath(subpath)

  assert_close(area.signed_subpath(subpath), 0.0, tolerance)
  assert_close(nonzero, 50.0, tolerance)
  assert_close(even_odd, 50.0, tolerance)
  assert_close(absolute, 50.0, tolerance)
}

pub fn path_fill_area_combines_subpaths_by_fill_rule_test() {
  let outer = svg_path.subpath_assert_polyline(square_points(0.0, 0.0, 20.0))
  let inner = svg_path.subpath_assert_polyline(square_points(5.0, 5.0, 10.0))
  let same_direction = svg_path.Path([outer, inner])
  let opposite_direction =
    svg_path.Path([
      outer,
      svg_path.subpath_assert_polyline(reverse(square_points(5.0, 5.0, 10.0))),
    ])

  let assert Ok(same_nonzero) =
    area.path(same_direction, using: svg_path.Nonzero)
  let assert Ok(same_even_odd) =
    area.path(same_direction, using: svg_path.EvenOdd)
  let assert Ok(same_absolute) = area.absolute_path(same_direction)
  let assert Ok(opposite_nonzero) =
    area.path(opposite_direction, using: svg_path.Nonzero)
  let assert Ok(opposite_even_odd) =
    area.path(opposite_direction, using: svg_path.EvenOdd)
  let assert Ok(opposite_absolute) = area.absolute_path(opposite_direction)

  assert_close(same_nonzero, 400.0, tolerance)
  assert_close(same_even_odd, 300.0, tolerance)
  assert_close(same_absolute, 500.0, tolerance)
  assert_close(opposite_nonzero, 300.0, tolerance)
  assert_close(opposite_even_odd, 300.0, tolerance)
  assert_close(opposite_absolute, 300.0, tolerance)
}

pub fn path_fill_area_cancels_overlapping_opposite_loops_test() {
  let forward = svg_path.subpath_assert_polyline(square_points(0.0, 0.0, 10.0))
  let backward =
    svg_path.subpath_assert_polyline(reverse(square_points(0.0, 0.0, 10.0)))
  let path = svg_path.Path([forward, backward])

  let assert Ok(nonzero) = area.path(path, using: svg_path.Nonzero)
  let assert Ok(even_odd) = area.path(path, using: svg_path.EvenOdd)
  let assert Ok(absolute) = area.absolute_path(path)

  assert_close(nonzero, 0.0, tolerance)
  assert_close(even_odd, 0.0, tolerance)
  assert_close(area.signed_path(path), 0.0, tolerance)
  assert_close(absolute, 0.0, tolerance)
}

pub fn absolute_path_counts_overlapping_winding_magnitude_test() {
  let outer = svg_path.subpath_assert_polyline(square_points(0.0, 0.0, 20.0))
  let inner = svg_path.subpath_assert_polyline(square_points(5.0, 5.0, 10.0))
  let path = svg_path.Path([outer, inner])

  let assert Ok(nonzero) = area.path(path, using: svg_path.Nonzero)
  let assert Ok(even_odd) = area.path(path, using: svg_path.EvenOdd)
  let assert Ok(absolute) = area.absolute_path(path)

  assert_close(nonzero, 400.0, tolerance)
  assert_close(even_odd, 300.0, tolerance)
  assert_close(area.signed_path(path), 500.0, tolerance)
  assert_close(absolute, 500.0, tolerance)
}

pub fn subpath_clockwiseness_reports_area_orientation_test() {
  let clockwise = svg_path.subpath_assert_polygon(square_points(0.0, 0.0, 10.0))
  let counterclockwise =
    svg_path.subpath_assert_polygon(reverse(square_points(0.0, 0.0, 10.0)))

  let assert Ok(clockwise_value) = area.subpath_clockwiseness(clockwise)
  let assert Ok(counterclockwise_value) =
    area.subpath_clockwiseness(counterclockwise)

  assert_close(clockwise_value, 1.0, tolerance)
  assert_close(counterclockwise_value, 0.0, tolerance)
}

pub fn subpath_clockwiseness_uses_implicit_closing_chord_test() {
  let open = svg_path.subpath_assert_polyline(square_points(0.0, 0.0, 10.0))
  let line =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 0.0),
      ),
    ])

  let assert Ok(open_value) = area.subpath_clockwiseness(open)
  let assert Ok(line_value) = area.subpath_clockwiseness(line)

  assert_close(open_value, 1.0, tolerance)
  assert_close(line_value, 0.5, tolerance)
}

pub fn subpath_clockwiseness_can_be_intermediate_test() {
  let bow_tie =
    svg_path.subpath_assert_polyline([
      svg_path.point(0.0, 0.0),
      svg_path.point(10.0, 10.0),
      svg_path.point(0.0, 10.0),
      svg_path.point(10.0, 0.0),
    ])

  let assert Ok(value) = area.subpath_clockwiseness(bow_tie)

  assert_close(value, 0.5, tolerance)
}

pub fn subpath_clockwiseness_rejects_invalid_linearization_options_test() {
  let subpath = svg_path.subpath_assert_polygon(square_points(0.0, 0.0, 10.0))

  assert area.subpath_clockwiseness_with(
      subpath,
      options: svg_path.LinearizeOptions(tolerance: 0.0, max_depth: 20),
    )
    == Error(svg_path.InvalidLinearizeTolerance(0.0))
}

pub fn move_only_paths_have_zero_area_test() {
  let move_only = svg_path.subpath_empty(at: svg_path.point(3.0, 4.0))
  let path = svg_path.Path([move_only])

  let assert Ok(nonzero) = area.path(path, using: svg_path.Nonzero)
  let assert Ok(even_odd) = area.path(path, using: svg_path.EvenOdd)

  assert area.signed_subpath(move_only) == 0.0
  assert area.signed_path(path) == 0.0
  assert nonzero == 0.0
  assert even_odd == 0.0
  assert area.absolute_path(path) == Ok(0.0)
}

pub fn curved_fill_area_uses_linearization_options_test() {
  let curve =
    svg_path.subpath_assert([
      svg_path.CubicBezier(
        start: svg_path.point(0.0, 0.0),
        control1: svg_path.point(0.0, 10.0),
        control2: svg_path.point(10.0, 10.0),
        end: svg_path.point(10.0, 0.0),
      ),
    ])
  let options = svg_path.LinearizeOptions(tolerance: 0.0001, max_depth: 20)

  let assert Ok(filled) =
    area.subpath_with(curve, using: svg_path.Nonzero, options:)

  assert_close(filled, 60.0, 0.01)
}

pub fn fill_area_rejects_invalid_linearization_options_test() {
  let subpath = svg_path.subpath_assert_polyline(square_points(0.0, 0.0, 10.0))

  assert area.subpath_with(
      subpath,
      using: svg_path.Nonzero,
      options: svg_path.LinearizeOptions(tolerance: 0.0, max_depth: 20),
    )
    == Error(svg_path.InvalidLinearizeTolerance(0.0))
  assert area.absolute_subpath_with(
      subpath,
      options: svg_path.LinearizeOptions(tolerance: 0.0, max_depth: 20),
    )
    == Error(svg_path.InvalidLinearizeTolerance(0.0))
}

fn square_points(x: Float, y: Float, size: Float) -> List(svg_path.Point) {
  [
    svg_path.point(x, y),
    svg_path.point(x +. size, y),
    svg_path.point(x +. size, y +. size),
    svg_path.point(x, y +. size),
  ]
}

fn reverse(items: List(a)) -> List(a) {
  reverse_loop(items, accumulated: [])
}

fn reverse_loop(items: List(a), accumulated accumulated: List(a)) -> List(a) {
  case items {
    [] -> accumulated
    [first, ..rest] -> reverse_loop(rest, accumulated: [first, ..accumulated])
  }
}

fn assert_close(
  actual: Float,
  expected: Float,
  within tolerance: Float,
) -> Nil {
  assert float.absolute_value(actual -. expected) <=. tolerance
}
