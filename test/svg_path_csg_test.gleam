import gleam/float
import gleam/list
import gleeunit
import svg_path
import svg_path/area
import svg_path/csg

const tolerance = 0.000001

type SemanticCase {
  SemanticCase(
    left: svg_path.Path,
    right: svg_path.Path,
    fill_rule: svg_path.FillRule,
    samples: List(svg_path.Point),
  )
}

type BooleanOperation {
  UnionOp
  IntersectionOp
  DifferenceOp
}

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

pub fn identical_rectangles_share_boundaries_test() {
  let left = rectangle(0.0, 0.0, 10.0, 10.0)
  let right = rectangle(0.0, 0.0, 10.0, 10.0)

  let assert Ok(union) = csg.union(left, right, using: svg_path.Nonzero)
  let assert Ok(intersection) =
    csg.intersection(left, right, using: svg_path.Nonzero)
  let assert Ok(difference) =
    csg.difference(left, minus: right, using: svg_path.Nonzero)

  assert_area(union, 100.0)
  assert_area(intersection, 100.0)
  assert_area(difference, 0.0)
  assert_inside(union, svg_path.point(5.0, 5.0))
  assert_inside(intersection, svg_path.point(5.0, 5.0))
  assert_outside(difference, svg_path.point(5.0, 5.0))
}

pub fn edge_tangent_rectangles_do_not_create_overlap_area_test() {
  let left = rectangle(0.0, 0.0, 10.0, 10.0)
  let right = rectangle(10.0, 0.0, 20.0, 10.0)

  let assert Ok(union) = csg.union(left, right, using: svg_path.Nonzero)
  let assert Ok(intersection) =
    csg.intersection(left, right, using: svg_path.Nonzero)
  let assert Ok(difference) =
    csg.difference(left, minus: right, using: svg_path.Nonzero)

  assert_area(union, 200.0)
  assert_area(intersection, 0.0)
  assert_area(difference, 100.0)
  assert_inside(union, svg_path.point(5.0, 5.0))
  assert_inside(union, svg_path.point(15.0, 5.0))
  assert_outside(intersection, svg_path.point(5.0, 5.0))
  assert_inside(difference, svg_path.point(5.0, 5.0))
  assert_outside(difference, svg_path.point(15.0, 5.0))
}

pub fn point_tangent_rectangles_do_not_create_overlap_area_test() {
  let left = rectangle(0.0, 0.0, 10.0, 10.0)
  let right = rectangle(10.0, 10.0, 20.0, 20.0)

  let assert Ok(union) = csg.union(left, right, using: svg_path.Nonzero)
  let assert Ok(intersection) =
    csg.intersection(left, right, using: svg_path.Nonzero)
  let assert Ok(difference) =
    csg.difference(left, minus: right, using: svg_path.Nonzero)

  assert_area(union, 200.0)
  assert_area(intersection, 0.0)
  assert_area(difference, 100.0)
  assert_inside(union, svg_path.point(5.0, 5.0))
  assert_inside(union, svg_path.point(15.0, 15.0))
  assert_outside(intersection, svg_path.point(5.0, 5.0))
  assert_inside(difference, svg_path.point(5.0, 5.0))
  assert_outside(difference, svg_path.point(15.0, 15.0))
}

pub fn operand_fill_rule_controls_nested_input_test() {
  let outer =
    svg_path.assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(20.0, 0.0),
      svg_path.point(20.0, 20.0),
      svg_path.point(0.0, 20.0),
    ])
  let inner =
    svg_path.assert_polygon([
      svg_path.point(5.0, 5.0),
      svg_path.point(15.0, 5.0),
      svg_path.point(15.0, 15.0),
      svg_path.point(5.0, 15.0),
    ])
  let nested = svg_path.Path([outer, inner])
  let probe = rectangle(7.0, 7.0, 13.0, 13.0)

  let assert Ok(nonzero_intersection) =
    csg.intersection(nested, probe, using: svg_path.Nonzero)
  let assert Ok(even_odd_intersection) =
    csg.intersection(nested, probe, using: svg_path.EvenOdd)

  assert_area(nonzero_intersection, 36.0)
  assert_area(even_odd_intersection, 0.0)
  assert_inside(nonzero_intersection, svg_path.point(10.0, 10.0))
  assert_outside(even_odd_intersection, svg_path.point(10.0, 10.0))
}

pub fn nonzero_union_preserves_internal_winding_levels_test() {
  let left = nested_rectangles()
  let right = rectangle(-5.0, 8.0, 25.0, 12.0)

  let assert Ok(union) = csg.union(left, right, using: svg_path.Nonzero)

  assert_inside(union, svg_path.point(10.0, 10.0))
  assert_winding_depth(union, svg_path.point(10.0, 10.0), 3)
  assert list.length(svg_path.subpaths(union)) > 1
}

pub fn nonzero_union_preserves_reversed_internal_winding_levels_test() {
  let left = nested_rectangles()
  let right = rectangle(-5.0, 8.0, 25.0, 12.0) |> svg_path.reverse_path

  let assert Ok(union) = csg.union(left, right, using: svg_path.Nonzero)

  assert_inside(union, svg_path.point(10.0, 10.0))
  assert_winding_depth(union, svg_path.point(10.0, 10.0), 3)
  assert list.length(svg_path.subpaths(union)) > 1
}

pub fn csg_matches_boolean_semantics_on_sample_points_test() {
  assert_semantic_cases([
    SemanticCase(
      left: rectangle(0.0, 0.0, 10.0, 10.0),
      right: rectangle(5.0, 0.0, 15.0, 10.0),
      fill_rule: svg_path.Nonzero,
      samples: grid([2.5, 7.5, 12.5, 20.0], [-2.5, 5.0, 12.5]),
    ),
    SemanticCase(
      left: circle(svg_path.point(10.0, 10.0), 10.0),
      right: rectangle(5.0, 0.0, 20.0, 20.0),
      fill_rule: svg_path.Nonzero,
      samples: grid([2.5, 7.5, 12.5, 17.5, 22.5], [2.5, 7.5, 12.5, 17.5]),
    ),
    SemanticCase(
      left: nested_rectangles(),
      right: rectangle(7.0, 7.0, 13.0, 13.0),
      fill_rule: svg_path.Nonzero,
      samples: grid([2.5, 7.5, 10.0, 12.5, 17.5], [2.5, 7.5, 10.0, 12.5, 17.5]),
    ),
    SemanticCase(
      left: nested_rectangles(),
      right: rectangle(7.0, 7.0, 13.0, 13.0),
      fill_rule: svg_path.EvenOdd,
      samples: grid([2.5, 7.5, 10.0, 12.5, 17.5], [2.5, 7.5, 10.0, 12.5, 17.5]),
    ),
    SemanticCase(
      left: circle(svg_path.point(50.0, 60.0), 40.0),
      right: rectangle(90.0, 20.0, 124.0, 100.0),
      fill_rule: svg_path.Nonzero,
      samples: grid([12.5, 50.0, 88.0, 92.0, 110.0], [30.0, 60.0, 90.0]),
    ),
    SemanticCase(
      left: bowtie(),
      right: rectangle(36.0, 28.0, 86.0, 92.0),
      fill_rule: svg_path.Nonzero,
      samples: grid([16.0, 44.0, 62.0, 78.0, 100.0], [
        16.0,
        40.0,
        60.0,
        84.0,
        104.0,
      ]),
    ),
  ])
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

fn nested_rectangles() -> svg_path.Path {
  svg_path.Path([
    svg_path.assert_polygon([
      svg_path.point(0.0, 0.0),
      svg_path.point(20.0, 0.0),
      svg_path.point(20.0, 20.0),
      svg_path.point(0.0, 20.0),
    ]),
    svg_path.assert_polygon([
      svg_path.point(5.0, 5.0),
      svg_path.point(15.0, 5.0),
      svg_path.point(15.0, 15.0),
      svg_path.point(5.0, 15.0),
    ]),
  ])
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

fn bowtie() -> svg_path.Path {
  svg_path.from_subpath(
    svg_path.assert_polygon([
      svg_path.point(8.0, 8.0),
      svg_path.point(114.0, 112.0),
      svg_path.point(114.0, 8.0),
      svg_path.point(8.0, 112.0),
    ]),
  )
}

fn grid(xs: List(Float), ys: List(Float)) -> List(svg_path.Point) {
  xs
  |> list.flat_map(fn(x) {
    ys
    |> list.map(fn(y) { svg_path.point(x, y) })
  })
}

fn assert_semantic_cases(cases: List(SemanticCase)) -> Nil {
  case cases {
    [] -> Nil
    [semantic_case, ..rest] -> {
      assert_semantic_case(semantic_case)
      assert_semantic_cases(rest)
    }
  }
}

fn assert_semantic_case(semantic_case: SemanticCase) -> Nil {
  let SemanticCase(left:, right:, fill_rule:, samples:) = semantic_case
  let operations = [UnionOp, IntersectionOp, DifferenceOp]
  assert_operations(operations, left:, right:, fill_rule:, samples:)
}

fn assert_operations(
  operations: List(BooleanOperation),
  left left: svg_path.Path,
  right right: svg_path.Path,
  fill_rule fill_rule: svg_path.FillRule,
  samples samples: List(svg_path.Point),
) -> Nil {
  case operations {
    [] -> Nil
    [operation, ..rest] -> {
      let assert Ok(result) = run_operation(left, right, operation, fill_rule)
      assert_samples(samples, left:, right:, result:, operation:, fill_rule:)
      assert_operations(rest, left:, right:, fill_rule:, samples:)
    }
  }
}

fn run_operation(
  left: svg_path.Path,
  right: svg_path.Path,
  operation: BooleanOperation,
  fill_rule: svg_path.FillRule,
) -> Result(svg_path.Path, svg_path.Error) {
  case operation {
    UnionOp -> csg.union(left, right, using: fill_rule)
    IntersectionOp -> csg.intersection(left, right, using: fill_rule)
    DifferenceOp -> csg.difference(left, minus: right, using: fill_rule)
  }
}

fn assert_samples(
  samples: List(svg_path.Point),
  left left: svg_path.Path,
  right right: svg_path.Path,
  result result: svg_path.Path,
  operation operation: BooleanOperation,
  fill_rule fill_rule: svg_path.FillRule,
) -> Nil {
  case samples {
    [] -> Nil
    [point, ..rest] -> {
      let assert Ok(left_inside) = contains(left, point, fill_rule)
      let assert Ok(right_inside) = contains(right, point, fill_rule)
      let assert Ok(result_inside) = contains(result, point, fill_rule)
      assert result_inside
        == expected_result(left_inside, right_inside, operation)
      assert_samples(rest, left:, right:, result:, operation:, fill_rule:)
    }
  }
}

fn contains(
  path: svg_path.Path,
  point: svg_path.Point,
  fill_rule: svg_path.FillRule,
) -> Result(Bool, Nil) {
  case svg_path.path_containment(point, within: path, using: fill_rule) {
    Ok(svg_path.Inside) -> Ok(True)
    Ok(svg_path.Outside) -> Ok(False)
    Ok(svg_path.Boundary) -> Error(Nil)
    Error(_) -> Error(Nil)
  }
}

fn expected_result(
  left_inside: Bool,
  right_inside: Bool,
  operation: BooleanOperation,
) -> Bool {
  case operation {
    UnionOp -> left_inside || right_inside
    IntersectionOp -> left_inside && right_inside
    DifferenceOp -> left_inside && !right_inside
  }
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

fn assert_winding_depth(
  path: svg_path.Path,
  point: svg_path.Point,
  expected: Int,
) {
  let assert Ok(svg_path.Winding(winding)) =
    svg_path.path_winding(point, within: path)
  assert int_absolute_value(winding) == expected
}

fn int_absolute_value(value: Int) -> Int {
  case value < 0 {
    True -> 0 - value
    False -> value
  }
}
