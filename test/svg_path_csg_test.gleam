import gleam/float
import gleam/list
import gleam/result
import gleeunit
import svg_path
import svg_path/area
import svg_path/csg
import svg_path/transform

const tolerance = 0.000001

type SemanticCase {
  SemanticCase(
    left: svg_path.Path,
    right: svg_path.Path,
    fill_rule: svg_path.FillRule,
    samples: List(svg_path.Point),
  )
}

type OperationCase {
  OperationCase(
    left: svg_path.Path,
    right: svg_path.Path,
    fill_rule: svg_path.FillRule,
    union: OperationExpectation,
    intersection: OperationExpectation,
    left_minus_right: OperationExpectation,
    right_minus_left: OperationExpectation,
  )
}

type OperationExpectation {
  OperationExpectation(
    area: Float,
    subpaths: SubpathExpectation,
    points: List(PointExpectation),
  )
}

type SubpathExpectation {
  AnySubpathCount
  ExactSubpathCount(Int)
}

type PointExpectation {
  ExpectInside(svg_path.Point)
  ExpectOutside(svg_path.Point)
  ExpectBoundary(svg_path.Point)
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

pub fn four_square_union_nonzero_test() {
  let paths = four_translated_square_paths()
  let assert Ok(union) = union_paths(paths)

  assert_area(union, 16.0)
  assert list.length(svg_path.subpaths(union)) == 6
  assert count_back_and_forth_subpaths(union) == 4
  assert_inside(union, svg_path.point(1.0, 1.0))
  assert_inside(union, svg_path.point(3.0, 2.0))
  assert_inside(union, svg_path.point(2.0, 4.0))
  assert_inside(union, svg_path.point(0.0, 3.0))
  assert_boundary(union, svg_path.point(2.0, 1.0))
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

pub fn adjacent_unit_square_union_preserves_shared_edge_slit_test() {
  let left = rectangle(0.0, 0.0, 1.0, 1.0)
  let right = rectangle(1.0, 0.0, 2.0, 1.0)

  let assert Ok(union) = csg.union(left, right, using: svg_path.Nonzero)

  assert_area(union, 2.0)
  assert_inside(union, svg_path.point(0.5, 0.5))
  assert_inside(union, svg_path.point(1.5, 0.5))
  assert_outside(union, svg_path.point(2.5, 0.5))
  assert union_has_rectangle_and_slit(union)
}

pub fn offset_adjacent_unit_square_union_stitches_outer_boundary_test() {
  let left = rectangle(0.0, 0.0, 1.0, 1.0)
  let right = rectangle(1.0, 0.5, 2.0, 1.5)

  let assert Ok(union) = csg.union(left, right, using: svg_path.Nonzero)

  assert_area(union, 2.0)
  assert_inside(union, svg_path.point(0.5, 0.5))
  assert_inside(union, svg_path.point(1.5, 1.0))
  assert_outside(union, svg_path.point(1.5, 0.25))
  assert offset_union_has_outer_boundary_and_slit(union)
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

pub fn nonzero_union_orients_internal_depth_contours_clockwise_test() {
  let left = nested_rectangles()
  let right = rectangle(-5.0, 8.0, 25.0, 12.0)

  let assert Ok(union) = csg.union(left, right, using: svg_path.Nonzero)

  assert_all_clockwise(union)
}

pub fn nonzero_union_preserves_reversed_internal_winding_levels_test() {
  let left = nested_rectangles()
  let right = rectangle(-5.0, 8.0, 25.0, 12.0) |> svg_path.reverse_path

  let assert Ok(union) = csg.union(left, right, using: svg_path.Nonzero)

  assert_inside(union, svg_path.point(10.0, 10.0))
  assert_winding_depth(union, svg_path.point(10.0, 10.0), 3)
  assert list.length(svg_path.subpaths(union)) > 1
}

pub fn nonzero_difference_keeps_forced_hole_orientation_test() {
  let outer = nested_rectangles()
  let inner = rectangle(7.0, 7.0, 13.0, 13.0)

  let assert Ok(difference) =
    csg.difference(outer, minus: inner, using: svg_path.Nonzero)

  assert_outside(difference, svg_path.point(10.0, 10.0))
  assert_has_clockwise_and_counterclockwise_contours(difference)
}

pub fn evenodd_difference_uses_canonical_hole_orientation_test() {
  let outer = rectangle(0.0, 0.0, 20.0, 20.0)
  let inner = rectangle(5.0, 5.0, 15.0, 15.0)

  let assert Ok(difference) =
    csg.difference(outer, minus: inner, using: svg_path.EvenOdd)

  assert_has_clockwise_and_counterclockwise_contours(difference)
}

pub fn simplify_nonzero_output_removes_internal_contour_depths_test() {
  let left = nested_rectangles()
  let right = rectangle(-5.0, 8.0, 25.0, 12.0)

  let assert Ok(union) = csg.union(left, right, using: svg_path.Nonzero)
  let assert Ok(simplified) = csg.simplify_nonzero_output(union)

  assert_inside(simplified, svg_path.point(10.0, 10.0))
  assert_inside(simplified, svg_path.point(-2.5, 10.0))
  assert_inside(simplified, svg_path.point(22.5, 10.0))
  assert_outside(simplified, svg_path.point(30.0, 10.0))
  assert_winding_depth(simplified, svg_path.point(10.0, 10.0), 1)
  assert list.length(svg_path.subpaths(simplified)) == 1
}

pub fn simplify_nonzero_output_preserves_holes_test() {
  let outer = rectangle(0.0, 0.0, 20.0, 20.0)
  let inner = rectangle(5.0, 5.0, 15.0, 15.0)

  let assert Ok(difference) =
    csg.difference(outer, minus: inner, using: svg_path.Nonzero)
  let assert Ok(simplified) = csg.simplify_nonzero_output(difference)

  assert_inside(simplified, svg_path.point(2.5, 2.5))
  assert_outside(simplified, svg_path.point(10.0, 10.0))
  assert_inside(simplified, svg_path.point(17.5, 17.5))
  assert list.length(svg_path.subpaths(simplified)) == 2
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

pub fn paper_style_csg_operation_table_test() {
  assert_operation_cases([
    OperationCase(
      left: rectangle(0.0, 0.0, 10.0, 10.0),
      right: rectangle(5.0, 0.0, 15.0, 10.0),
      fill_rule: svg_path.Nonzero,
      union: OperationExpectation(
        area: 150.0,
        subpaths: AnySubpathCount,
        points: [
          ExpectInside(svg_path.point(2.5, 5.0)),
          ExpectInside(svg_path.point(7.5, 5.0)),
          ExpectInside(svg_path.point(12.5, 5.0)),
          ExpectOutside(svg_path.point(20.0, 5.0)),
        ],
      ),
      intersection: OperationExpectation(
        area: 50.0,
        subpaths: AnySubpathCount,
        points: [
          ExpectOutside(svg_path.point(2.5, 5.0)),
          ExpectInside(svg_path.point(7.5, 5.0)),
          ExpectOutside(svg_path.point(12.5, 5.0)),
        ],
      ),
      left_minus_right: OperationExpectation(
        area: 50.0,
        subpaths: AnySubpathCount,
        points: [
          ExpectInside(svg_path.point(2.5, 5.0)),
          ExpectOutside(svg_path.point(7.5, 5.0)),
          ExpectOutside(svg_path.point(12.5, 5.0)),
        ],
      ),
      right_minus_left: OperationExpectation(
        area: 50.0,
        subpaths: AnySubpathCount,
        points: [
          ExpectOutside(svg_path.point(2.5, 5.0)),
          ExpectOutside(svg_path.point(7.5, 5.0)),
          ExpectInside(svg_path.point(12.5, 5.0)),
        ],
      ),
    ),
    OperationCase(
      left: rectangle(0.0, 0.0, 10.0, 10.0),
      right: rectangle(20.0, 0.0, 30.0, 10.0),
      fill_rule: svg_path.Nonzero,
      union: OperationExpectation(
        area: 200.0,
        subpaths: ExactSubpathCount(2),
        points: [
          ExpectInside(svg_path.point(5.0, 5.0)),
          ExpectOutside(svg_path.point(15.0, 5.0)),
          ExpectInside(svg_path.point(25.0, 5.0)),
        ],
      ),
      intersection: OperationExpectation(
        area: 0.0,
        subpaths: ExactSubpathCount(0),
        points: [
          ExpectOutside(svg_path.point(5.0, 5.0)),
          ExpectOutside(svg_path.point(25.0, 5.0)),
        ],
      ),
      left_minus_right: OperationExpectation(
        area: 100.0,
        subpaths: AnySubpathCount,
        points: [
          ExpectInside(svg_path.point(5.0, 5.0)),
          ExpectOutside(svg_path.point(25.0, 5.0)),
        ],
      ),
      right_minus_left: OperationExpectation(
        area: 100.0,
        subpaths: AnySubpathCount,
        points: [
          ExpectOutside(svg_path.point(5.0, 5.0)),
          ExpectInside(svg_path.point(25.0, 5.0)),
        ],
      ),
    ),
    OperationCase(
      left: rectangle(0.0, 0.0, 10.0, 10.0),
      right: rectangle(0.0, 0.0, 10.0, 10.0),
      fill_rule: svg_path.Nonzero,
      union: OperationExpectation(
        area: 100.0,
        subpaths: AnySubpathCount,
        points: [ExpectInside(svg_path.point(5.0, 5.0))],
      ),
      intersection: OperationExpectation(
        area: 100.0,
        subpaths: AnySubpathCount,
        points: [ExpectInside(svg_path.point(5.0, 5.0))],
      ),
      left_minus_right: OperationExpectation(
        area: 0.0,
        subpaths: ExactSubpathCount(0),
        points: [ExpectOutside(svg_path.point(5.0, 5.0))],
      ),
      right_minus_left: OperationExpectation(
        area: 0.0,
        subpaths: ExactSubpathCount(0),
        points: [ExpectOutside(svg_path.point(5.0, 5.0))],
      ),
    ),
    OperationCase(
      left: rectangle(0.0, 0.0, 10.0, 10.0),
      right: rectangle(10.0, 0.0, 20.0, 10.0),
      fill_rule: svg_path.Nonzero,
      union: OperationExpectation(
        area: 200.0,
        subpaths: ExactSubpathCount(2),
        points: [
          ExpectInside(svg_path.point(5.0, 5.0)),
          ExpectBoundary(svg_path.point(10.0, 5.0)),
          ExpectInside(svg_path.point(15.0, 5.0)),
        ],
      ),
      intersection: OperationExpectation(
        area: 0.0,
        subpaths: AnySubpathCount,
        points: [
          ExpectOutside(svg_path.point(5.0, 5.0)),
          ExpectOutside(svg_path.point(15.0, 5.0)),
        ],
      ),
      left_minus_right: OperationExpectation(
        area: 100.0,
        subpaths: AnySubpathCount,
        points: [
          ExpectInside(svg_path.point(5.0, 5.0)),
          ExpectOutside(svg_path.point(15.0, 5.0)),
        ],
      ),
      right_minus_left: OperationExpectation(
        area: 100.0,
        subpaths: AnySubpathCount,
        points: [
          ExpectOutside(svg_path.point(5.0, 5.0)),
          ExpectInside(svg_path.point(15.0, 5.0)),
        ],
      ),
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

fn four_translated_square_paths() -> List(svg_path.Path) {
  let square = rectangle(0.0, 0.0, 2.0, 2.0)
  translated_copy_list(square, [
    #(0.0, 0.0),
    #(2.0, 1.0),
    #(1.0, 3.0),
    #(-1.0, 2.0),
  ])
}

fn translated_copy_list(
  path: svg_path.Path,
  offsets: List(#(Float, Float)),
) -> List(svg_path.Path) {
  offsets
  |> list.map(fn(offset) {
    let #(x, y) = offset
    let assert Ok(translated) = transform.translate_path(path, x:, y:)
    translated
  })
}

fn union_paths(
  paths: List(svg_path.Path),
) -> Result(svg_path.Path, svg_path.Error) {
  case paths {
    [] -> Ok(svg_path.empty_path())
    [first, ..rest] -> union_paths_loop(rest, first)
  }
}

fn union_paths_loop(
  paths: List(svg_path.Path),
  accumulated: svg_path.Path,
) -> Result(svg_path.Path, svg_path.Error) {
  case paths {
    [] -> Ok(accumulated)
    [path, ..rest] -> {
      use accumulated <- result.try(csg.union(
        accumulated,
        path,
        using: svg_path.Nonzero,
      ))
      union_paths_loop(rest, accumulated)
    }
  }
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

fn assert_operation_cases(cases: List(OperationCase)) -> Nil {
  case cases {
    [] -> Nil
    [operation_case, ..rest] -> {
      assert_operation_case(operation_case)
      assert_operation_cases(rest)
    }
  }
}

fn assert_operation_case(operation_case: OperationCase) -> Nil {
  let OperationCase(
    left:,
    right:,
    fill_rule:,
    union: union_expectation,
    intersection: intersection_expectation,
    left_minus_right: left_minus_right_expectation,
    right_minus_left: right_minus_left_expectation,
  ) = operation_case

  let assert Ok(union) = csg.union(left, right, using: fill_rule)
  let assert Ok(reversed_union) = csg.union(right, left, using: fill_rule)
  assert_operation_expectation(union, union_expectation, fill_rule)
  assert_operation_expectation(reversed_union, union_expectation, fill_rule)

  let assert Ok(intersection) =
    csg.intersection(left, right, using: fill_rule)
  let assert Ok(reversed_intersection) =
    csg.intersection(right, left, using: fill_rule)
  assert_operation_expectation(
    intersection,
    intersection_expectation,
    fill_rule,
  )
  assert_operation_expectation(
    reversed_intersection,
    intersection_expectation,
    fill_rule,
  )

  let assert Ok(left_minus_right) =
    csg.difference(left, minus: right, using: fill_rule)
  let assert Ok(right_minus_left) =
    csg.difference(right, minus: left, using: fill_rule)
  assert_operation_expectation(
    left_minus_right,
    left_minus_right_expectation,
    fill_rule,
  )
  assert_operation_expectation(
    right_minus_left,
    right_minus_left_expectation,
    fill_rule,
  )
}

fn assert_operation_expectation(
  path: svg_path.Path,
  expectation: OperationExpectation,
  fill_rule: svg_path.FillRule,
) -> Nil {
  let OperationExpectation(area:, subpaths:, points:) = expectation
  assert_area_using(path, area, fill_rule)
  assert_subpath_expectation(path, subpaths)
  assert_point_expectations(path, points, fill_rule)
}

fn assert_subpath_expectation(
  path: svg_path.Path,
  expectation: SubpathExpectation,
) -> Nil {
  case expectation {
    AnySubpathCount -> Nil
    ExactSubpathCount(expected) -> {
      assert list.length(svg_path.subpaths(path)) == expected
    }
  }
}

fn assert_point_expectations(
  path: svg_path.Path,
  points: List(PointExpectation),
  fill_rule: svg_path.FillRule,
) -> Nil {
  case points {
    [] -> Nil
    [point, ..rest] -> {
      assert_point_expectation(path, point, fill_rule)
      assert_point_expectations(path, rest, fill_rule)
    }
  }
}

fn assert_point_expectation(
  path: svg_path.Path,
  point: PointExpectation,
  fill_rule: svg_path.FillRule,
) -> Nil {
  case point {
    ExpectInside(point) -> {
      assert svg_path.path_containment(point, within: path, using: fill_rule)
        == Ok(svg_path.Inside)
    }
    ExpectOutside(point) -> {
      assert svg_path.path_containment(point, within: path, using: fill_rule)
        == Ok(svg_path.Outside)
    }
    ExpectBoundary(point) -> {
      assert svg_path.path_containment(point, within: path, using: fill_rule)
        == Ok(svg_path.Boundary)
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

fn union_has_rectangle_and_slit(path: svg_path.Path) -> Bool {
  let subpaths = svg_path.subpaths(path)
  list.length(subpaths) == 2
  && list.any(subpaths, is_adjacent_union_outer_rectangle)
  && list.any(subpaths, is_adjacent_union_slit)
}

fn is_adjacent_union_outer_rectangle(subpath: svg_path.Subpath) -> Bool {
  let segments = svg_path.segments(subpath)
  list.length(segments) == 6
  && has_line(segments, svg_path.point(0.0, 0.0), svg_path.point(1.0, 0.0))
  && has_line(segments, svg_path.point(1.0, 0.0), svg_path.point(2.0, 0.0))
  && has_line(segments, svg_path.point(2.0, 0.0), svg_path.point(2.0, 1.0))
  && has_line(segments, svg_path.point(2.0, 1.0), svg_path.point(1.0, 1.0))
  && has_line(segments, svg_path.point(1.0, 1.0), svg_path.point(0.0, 1.0))
  && has_line(segments, svg_path.point(0.0, 1.0), svg_path.point(0.0, 0.0))
}

fn is_adjacent_union_slit(subpath: svg_path.Subpath) -> Bool {
  let segments = svg_path.segments(subpath)
  list.length(segments) == 2
  && has_line(segments, svg_path.point(1.0, 0.0), svg_path.point(1.0, 1.0))
  && has_line(segments, svg_path.point(1.0, 1.0), svg_path.point(1.0, 0.0))
}

fn offset_union_has_outer_boundary_and_slit(path: svg_path.Path) -> Bool {
  let subpaths = svg_path.subpaths(path)
  list.length(subpaths) == 2
  && list.any(subpaths, is_offset_union_outer_boundary)
  && list.any(subpaths, is_offset_union_slit)
}

fn is_offset_union_outer_boundary(subpath: svg_path.Subpath) -> Bool {
  let segments = svg_path.segments(subpath)
  list.length(segments) == 8
  && has_line(segments, svg_path.point(0.0, 0.0), svg_path.point(1.0, 0.0))
  && has_line(segments, svg_path.point(1.0, 0.0), svg_path.point(1.0, 0.5))
  && has_line(segments, svg_path.point(1.0, 0.5), svg_path.point(2.0, 0.5))
  && has_line(segments, svg_path.point(2.0, 0.5), svg_path.point(2.0, 1.5))
  && has_line(segments, svg_path.point(2.0, 1.5), svg_path.point(1.0, 1.5))
  && has_line(segments, svg_path.point(1.0, 1.5), svg_path.point(1.0, 1.0))
  && has_line(segments, svg_path.point(1.0, 1.0), svg_path.point(0.0, 1.0))
  && has_line(segments, svg_path.point(0.0, 1.0), svg_path.point(0.0, 0.0))
}

fn is_offset_union_slit(subpath: svg_path.Subpath) -> Bool {
  let segments = svg_path.segments(subpath)
  list.length(segments) == 2
  && has_line(segments, svg_path.point(1.0, 0.5), svg_path.point(1.0, 1.0))
  && has_line(segments, svg_path.point(1.0, 1.0), svg_path.point(1.0, 0.5))
}

fn count_back_and_forth_subpaths(path: svg_path.Path) -> Int {
  path
  |> svg_path.subpaths
  |> list.filter(is_back_and_forth_subpath)
  |> list.length
}

fn is_back_and_forth_subpath(subpath: svg_path.Subpath) -> Bool {
  case svg_path.segments(subpath) {
    [
      svg_path.Line(start: first_start, end: first_end),
      svg_path.Line(start: second_start, end: second_end),
    ] ->
      same_point(first_start, second_end) && same_point(first_end, second_start)
    _ -> False
  }
}

fn has_line(
  segments: List(svg_path.Segment),
  start: svg_path.Point,
  end: svg_path.Point,
) -> Bool {
  list.any(segments, fn(segment) {
    case segment {
      svg_path.Line(start: actual_start, end: actual_end) ->
        same_point(actual_start, start) && same_point(actual_end, end)
      _ -> False
    }
  })
}

fn same_point(left: svg_path.Point, right: svg_path.Point) -> Bool {
  float.absolute_value(left.x -. right.x) <=. tolerance
  && float.absolute_value(left.y -. right.y) <=. tolerance
}

fn assert_area(path: svg_path.Path, expected: Float) {
  assert_area_using(path, expected, svg_path.Nonzero)
}

fn assert_area_using(
  path: svg_path.Path,
  expected: Float,
  fill_rule: svg_path.FillRule,
) {
  let assert Ok(actual) = area.path(path, using: fill_rule)
  assert float.absolute_value(actual -. expected) <=. tolerance
}

fn assert_inside(path: svg_path.Path, point: svg_path.Point) {
  assert svg_path.path_containment(point, within: path, using: svg_path.Nonzero)
    == Ok(svg_path.Inside)
}

fn assert_boundary(path: svg_path.Path, point: svg_path.Point) {
  assert svg_path.path_containment(point, within: path, using: svg_path.Nonzero)
    == Ok(svg_path.Boundary)
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

fn assert_all_clockwise(path: svg_path.Path) {
  assert path
    |> svg_path.subpaths
    |> list.all(fn(subpath) { area.signed_subpath(subpath) >=. 0.0 })
}

fn assert_has_clockwise_and_counterclockwise_contours(path: svg_path.Path) {
  let subpaths = svg_path.subpaths(path)
  assert list.any(subpaths, fn(subpath) {
    area.signed_subpath(subpath) >. tolerance
  })
  assert list.any(subpaths, fn(subpath) {
    area.signed_subpath(subpath) <. 0.0 -. tolerance
  })
}

fn int_absolute_value(value: Int) -> Int {
  case value < 0 {
    True -> 0 - value
    False -> value
  }
}
