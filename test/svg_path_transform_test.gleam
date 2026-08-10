import gleam/float
import gleeunit
import svg_path
import svg_path/serialize
import svg_path/transform

const tolerance = 0.000001

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn matrix_transforms_points_test() {
  let point = svg_path.Point(2.0, 3.0)
  let matrix =
    transform.matrix(a: 2.0, b: 3.0, c: 5.0, d: 7.0, e: 11.0, f: 13.0)

  assert transform.point(point, by: matrix) == svg_path.Point(30.0, 40.0)
}

pub fn translate_matrix_transforms_points_test() {
  let point = svg_path.Point(2.0, 3.0)

  assert transform.point(point, by: transform.translate(x: 5.0, y: -7.0))
    == svg_path.Point(7.0, -4.0)
  assert transform.translate_point(point, x: 5.0, y: -7.0)
    == svg_path.Point(7.0, -4.0)
}

pub fn matrix_transforms_bounding_boxes_test() {
  let box =
    svg_path.BoundingBox(
      min: svg_path.Point(1.0, 2.0),
      max: svg_path.Point(3.0, 5.0),
    )

  assert transform.bounding_box(box, by: transform.translate(x: 4.0, y: -3.0))
    == Ok(svg_path.BoundingBox(
      min: svg_path.Point(5.0, -1.0),
      max: svg_path.Point(7.0, 2.0),
    ))
}

pub fn rotated_matrix_transforms_bounding_box_corners_test() {
  let box =
    svg_path.BoundingBox(
      min: svg_path.Point(0.0, 0.0),
      max: svg_path.Point(2.0, 1.0),
    )
  let assert Ok(transformed) =
    transform.bounding_box(box, by: transform.rotate(degrees: 90.0))

  assert bbox_near(
    transformed,
    min: svg_path.Point(-1.0, 0.0),
    max: svg_path.Point(0.0, 2.0),
  )
}

pub fn scale_matrix_transforms_points_test() {
  let point = svg_path.Point(2.0, 3.0)

  assert transform.point(point, by: transform.scale(factor: 4.0))
    == svg_path.Point(8.0, 12.0)
  assert transform.scale_point(point, factor: 4.0) == svg_path.Point(8.0, 12.0)
}

pub fn scale_xy_matrix_transforms_points_test() {
  let point = svg_path.Point(2.0, 3.0)

  assert transform.point(point, by: transform.scale_xy(x: 4.0, y: -2.0))
    == svg_path.Point(8.0, -6.0)
  assert transform.scale_xy_point(point, x: 4.0, y: -2.0)
    == svg_path.Point(8.0, -6.0)
}

pub fn about_point_matrix_transforms_points_about_point_test() {
  let point = svg_path.Point(3.0, 4.0)
  let center = svg_path.Point(1.0, 2.0)

  assert transform.point(
      point,
      by: transform.about_point(
        transform.scale_xy(x: 2.0, y: 3.0),
        point: center,
      ),
    )
    == svg_path.Point(5.0, 8.0)
}

pub fn point_pair_map_maps_source_points_to_targets_test() {
  let source_start = svg_path.Point(1.0, 2.0)
  let source_end = svg_path.Point(4.0, 2.0)
  let target_start = svg_path.Point(10.0, -5.0)
  let target_end = svg_path.Point(10.0, 1.0)
  let assert Ok(matrix) =
    transform.point_pair_map(
      source_start,
      source_end,
      target_start,
      target_end,
      tolerance:,
    )

  assert point_near(transform.point(source_start, by: matrix), target_start)
  assert point_near(transform.point(source_end, by: matrix), target_end)
  assert transform.to_tuple(matrix) == #(0.0, 2.0, -2.0, 0.0, 14.0, -7.0)
}

pub fn point_pair_map_maps_distinct_source_to_collapsed_target_test() {
  let source_start = svg_path.Point(1.0, 2.0)
  let source_end = svg_path.Point(4.0, 2.0)
  let target_start = svg_path.Point(10.0, -5.0)
  let target_end = svg_path.Point(10.0, -5.0)
  let assert Ok(matrix) =
    transform.point_pair_map(
      source_start,
      source_end,
      target_start,
      target_end,
      tolerance:,
    )

  assert point_near(transform.point(source_start, by: matrix), target_start)
  assert point_near(transform.point(source_end, by: matrix), target_end)
  assert transform.to_tuple(matrix) == #(0.0, 0.0, 0.0, 0.0, 10.0, -5.0)
}

pub fn point_pair_map_rejects_points_outside_tolerance_test() {
  assert transform.point_pair_map(
      svg_path.Point(1.0, 2.0),
      svg_path.Point(1.0, 2.0),
      svg_path.Point(10.0, -5.0),
      svg_path.Point(10.0, 1.0),
      tolerance:,
    )
    == Error(Nil)
}

pub fn point_pair_map_rejects_negative_tolerance_test() {
  assert transform.point_pair_map(
      svg_path.Point(0.0, 0.0),
      svg_path.Point(1.0, 0.0),
      svg_path.Point(0.0, 0.0),
      svg_path.Point(1.0, 0.0),
      tolerance: -0.001,
    )
    == Error(Nil)
}

pub fn point_triple_map_maps_source_points_to_targets_test() {
  let source_a = svg_path.Point(1.0, 2.0)
  let source_b = svg_path.Point(3.0, 2.0)
  let source_c = svg_path.Point(1.0, 5.0)
  let target_a = svg_path.Point(10.0, -5.0)
  let target_b = svg_path.Point(14.0, -3.0)
  let target_c = svg_path.Point(7.0, 1.0)
  let assert Ok(matrix) =
    transform.point_triple_map(
      source_a,
      source_b,
      source_c,
      target_a,
      target_b,
      target_c,
      tolerance:,
    )

  assert point_near(transform.point(source_a, by: matrix), target_a)
  assert point_near(transform.point(source_b, by: matrix), target_b)
  assert point_near(transform.point(source_c, by: matrix), target_c)
  assert transform.to_tuple(matrix) == #(2.0, 1.0, -1.0, 2.0, 10.0, -10.0)
}

pub fn point_triple_map_rejects_points_outside_tolerance_test() {
  assert transform.point_triple_map(
      svg_path.Point(1.0, 2.0),
      svg_path.Point(1.0, 2.0),
      svg_path.Point(1.0, 2.0),
      svg_path.Point(10.0, -5.0),
      svg_path.Point(14.0, -3.0),
      svg_path.Point(7.0, 1.0),
      tolerance:,
    )
    == Error(Nil)
}

pub fn rotate_matrix_uses_degrees_test() {
  let line =
    svg_path.Line(
      start: svg_path.Point(1.0, 0.0),
      end: svg_path.Point(1.0, 2.0),
    )
  let assert Ok(segment) = transform.rotate_segment(line, degrees: 90.0)

  assert serialize.segment(segment) == "M 0 1 H -2"
}

pub fn transform_about_rotation_rotates_about_point_test() {
  let point = svg_path.Point(3.0, 2.0)
  let center = svg_path.Point(1.0, 2.0)

  assert point_near(
    transform.point(
      point,
      by: transform.about_point(transform.rotate(degrees: 90.0), point: center),
    ),
    svg_path.Point(1.0, 4.0),
  )
}

pub fn path_about_point_transforms_path_about_point_test() {
  let center = svg_path.Point(1.0, 2.0)
  let assert Ok(path) =
    svg_path.Path([
      svg_path.subpath_assert([
        svg_path.Line(
          start: svg_path.Point(3.0, 2.0),
          end: svg_path.Point(3.0, 4.0),
        ),
      ]),
    ])
    |> transform.path_about_point(
      by: transform.rotate(degrees: 90.0),
      point: center,
    )

  assert serialize.path(path) == "M 1 4 H -1"
}

pub fn segment_about_anchor_transforms_segment_about_anchor_test() {
  let segment =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 0.0),
    )
  let assert Ok(transformed) =
    transform.segment_about_anchor(
      segment,
      by: transform.rotate(degrees: 90.0),
      anchor: transform.TopLeft,
    )

  assert serialize.segment(transformed) == "M 0 0 V 10"
}

pub fn subpath_about_anchor_transforms_subpath_about_anchor_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(0.0, 10.0),
      ),
    ])
  let assert Ok(transformed) =
    transform.subpath_about_anchor(
      subpath,
      by: transform.scale_xy(x: 1.0, y: -1.0),
      anchor: transform.Center,
    )

  assert serialize.subpath(transformed) == "M 0 10 V 0"
}

pub fn path_about_anchor_transforms_path_about_anchor_test() {
  let path =
    svg_path.Path([
      svg_path.subpath_assert([
        svg_path.Line(
          start: svg_path.Point(0.0, 0.0),
          end: svg_path.Point(10.0, 0.0),
        ),
      ]),
    ])
  let assert Ok(transformed) =
    transform.path_about_anchor(
      path,
      by: transform.scale_xy(x: -1.0, y: 1.0),
      anchor: transform.Center,
    )

  assert serialize.path(transformed) == "M 10 0 H 0"
}

pub fn skew_matrices_use_degrees_test() {
  let point = svg_path.Point(2.0, 3.0)

  assert transform.point(point, by: transform.skew_x(degrees: 45.0))
    == svg_path.Point(5.0, 3.0)
  assert transform.skew_y_point(point, degrees: 45.0)
    == svg_path.Point(2.0, 5.0)
}

pub fn chain_applies_first_then_second_test() {
  let point = svg_path.Point(1.0, 1.0)
  let scale = transform.scale(factor: 2.0)
  let translate = transform.translate(x: 10.0, y: 20.0)

  assert transform.point(
      point,
      by: transform.chain(first: scale, then: translate),
    )
    == svg_path.Point(12.0, 22.0)
}

pub fn multiply_uses_algebraic_left_times_right_order_test() {
  let point = svg_path.Point(1.0, 1.0)
  let scale = transform.scale(factor: 2.0)
  let translate = transform.translate(x: 10.0, y: 20.0)

  assert transform.point(
      point,
      by: transform.multiply(left: translate, right: scale),
    )
    == svg_path.Point(12.0, 22.0)
  assert transform.point(
      point,
      by: transform.multiply(left: scale, right: translate),
    )
    == svg_path.Point(22.0, 42.0)
}

pub fn direct_subpath_and_path_helpers_delegate_to_matrices_test() {
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(5.0, 0.0),
      ),
    ])
  let path = svg_path.subpath_as_path(subpath)
  let assert Ok(translated_subpath) =
    transform.translate_subpath(subpath, x: 10.0, y: 20.0)
  let assert Ok(scaled_path) = transform.scale_path(path, factor: 2.0)

  assert serialize.subpath(translated_subpath) == "M 10 20 H 15"
  assert serialize.path(scaled_path) == "M 0 0 H 10"
}

pub fn to_tuple_exposes_svg_matrix_values_test() {
  let values =
    transform.matrix(a: 2.0, b: 3.0, c: 5.0, d: 7.0, e: 11.0, f: 13.0)
    |> transform.to_tuple

  assert values == #(2.0, 3.0, 5.0, 7.0, 11.0, 13.0)
}

pub fn from_tuple_creates_matrix_from_svg_matrix_values_test() {
  let matrix = transform.from_tuple(#(2.0, 3.0, 5.0, 7.0, 11.0, 13.0))

  assert transform.to_tuple(matrix) == #(2.0, 3.0, 5.0, 7.0, 11.0, 13.0)
}

pub fn line_transform_test() {
  let matrix =
    transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 10.0, f: -5.0)
  let assert Ok(segment) =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(5.0, 0.0),
    )
    |> transform.segment(by: matrix)

  assert serialize.segment(segment) == "M 10 -5 H 15"
}

pub fn quadratic_and_cubic_bezier_transform_test() {
  let matrix = transform.matrix(a: 2.0, b: 0.0, c: 0.0, d: 3.0, e: 0.0, f: 0.0)
  let assert Ok(quadratic) =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.0),
      control: svg_path.Point(1.0, 2.0),
      end: svg_path.Point(3.0, 4.0),
    )
    |> transform.segment(by: matrix)
  let assert Ok(cubic) =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(1.0, 2.0),
      control2: svg_path.Point(3.0, 4.0),
      end: svg_path.Point(5.0, 6.0),
    )
    |> transform.segment(by: matrix)

  assert serialize.segment(quadratic) == "M 0 0 Q 2 6 6 12"
  assert serialize.segment(cubic) == "M 0 0 C 2 6 6 12 10 18"
}

pub fn closed_subpath_transform_preserves_semantic_closure_test() {
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 10.0, f: 0.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(10.0, 0.0),
        end: svg_path.Point(0.0, 0.0),
      ),
    ])
    |> result_try_set_closed_true
  let assert Ok(transformed) = transform.subpath(subpath, by: matrix)

  assert svg_path.subpath_is_closed(transformed)
  assert serialize.subpath(transformed) == "M 10 0 H 20 Z"
}

pub fn path_transform_test() {
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 1.0, f: 2.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
    ])
  let assert Ok(path) =
    svg_path.Path([
      svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)),
      subpath,
    ])
    |> transform.path(by: matrix)

  assert serialize.path(path) == "M 1 2 M 1 2 H 11"
}

pub fn arc_identity_transform_preserves_arc_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.Point(0.0, 0.0),
      radius: svg_path.Point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: False,
      end: svg_path.Point(10.0, 0.0),
    )
  let assert Ok(transformed) = transform.segment(arc, by: transform.identity())

  assert serialize.segment(transformed) == "M 0 0 A 5 5 0 0 0 10 0"
}

pub fn arc_non_uniform_scale_transform_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.Point(0.0, 0.0),
      radius: svg_path.Point(5.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: True,
      sweep: False,
      end: svg_path.Point(5.0, 10.0),
    )
  let matrix = transform.matrix(a: 2.0, b: 0.0, c: 0.0, d: 3.0, e: 0.0, f: 0.0)
  let assert Ok(transformed) = transform.segment(arc, by: matrix)

  assert serialize.segment(transformed) == "M 0 0 A 10 30 0 1 0 10 30"
}

pub fn arc_shear_transform_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.Point(0.0, 0.0),
      radius: svg_path.Point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(10.0, 0.0),
    )
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 1.0, d: 1.0, e: 0.0, f: 0.0)
  let assert Ok(transformed) = transform.segment(arc, by: matrix)

  assert serialize.segment_with(
      transformed,
      options: serialize.decimal_options(3),
    )
    == "M 0 0 A 8.09 3.09 31.717 0 1 10 0"
}

pub fn arc_reflection_flips_sweep_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.Point(0.0, 0.0),
      radius: svg_path.Point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(10.0, 0.0),
    )
  let matrix = transform.matrix(a: -1.0, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: 0.0)
  let assert Ok(transformed) = transform.segment(arc, by: matrix)

  assert serialize.segment(transformed) == "M 0 0 A 5 5 0 0 0 -10 0"
}

pub fn arc_degenerate_transform_errors_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.Point(0.0, 0.0),
      radius: svg_path.Point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: False,
      end: svg_path.Point(10.0, 0.0),
    )
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 0.0, e: 0.0, f: 0.0)

  assert transform.segment(arc, by: matrix)
    == Error(transform.DegenerateArcTransform)
}

pub fn strict_subpath_transform_errors_on_collapsed_arc_test() {
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Arc(
        start: svg_path.Point(5.0, 0.0),
        radius: svg_path.Point(5.0, 5.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.Point(-5.0, 0.0),
      ),
    ])
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 0.0, e: 0.0, f: 0.0)

  assert transform.subpath(subpath, by: matrix)
    == Error(transform.DegenerateArcTransform)
}

pub fn graceful_arc_transform_returns_collapsed_line_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.Point(5.0, 0.0),
      radius: svg_path.Point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(-5.0, 0.0),
    )
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 0.0, e: 0.0, f: 0.0)
  let assert Ok(segment) = transform.segment_gracefully(arc, by: matrix)

  assert serialize.segment(segment) == "M -5 0 H 5"
}

pub fn graceful_arc_transform_follows_full_collapse_to_point_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.Point(5.0, 0.0),
      radius: svg_path.Point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(-5.0, 0.0),
    )
  let matrix = transform.matrix(a: 0.0, b: 0.0, c: 0.0, d: 0.0, e: 7.0, f: 11.0)
  let assert Ok(segment) = transform.segment_gracefully(arc, by: matrix)

  assert serialize.segment(segment) == "M 7 11 H 7"
}

pub fn graceful2_arc_transform_preserves_transformed_endpoints_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.Point(5.0, 0.0),
      radius: svg_path.Point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(-5.0, 0.0),
    )
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 0.0, e: 0.0, f: 0.0)
  let assert Ok(subpath) =
    transform.segment_to_subpath_gracefully(arc, by: matrix)

  assert serialize.subpath(subpath) == "M 5 0 H -5"
}

pub fn graceful2_line_transform_returns_single_segment_subpath_test() {
  let line =
    svg_path.Line(
      start: svg_path.Point(1.0, 2.0),
      end: svg_path.Point(4.0, 2.0),
    )
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 10.0, f: 0.0)
  let assert Ok(subpath) =
    transform.segment_to_subpath_gracefully(line, by: matrix)

  assert serialize.subpath(subpath) == "M 11 2 H 14"
}

pub fn graceful2_arc_transform_preserves_out_and_back_motion_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.Point(3.5355339059, -3.5355339059),
      radius: svg_path.Point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(3.5355339059, 3.5355339059),
    )
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 0.0, e: 0.0, f: 0.0)
  let assert Ok(subpath) =
    transform.segment_to_subpath_gracefully(arc, by: matrix)

  assert serialize.subpath(subpath) == "M 3.53553 0 H 5 H 3.53553"
}

pub fn graceful2_arc_transform_follows_full_collapse_to_point_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.Point(5.0, 0.0),
      radius: svg_path.Point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(-5.0, 0.0),
    )
  let matrix = transform.matrix(a: 0.0, b: 0.0, c: 0.0, d: 0.0, e: 7.0, f: 11.0)
  let assert Ok(subpath) =
    transform.segment_to_subpath_gracefully(arc, by: matrix)

  assert serialize.subpath(subpath) == "M 7 11 H 7"
}

pub fn graceful_subpath_transform_keeps_surrounding_continuity_test() {
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(
        start: svg_path.Point(-10.0, 0.0),
        end: svg_path.Point(5.0, 0.0),
      ),
      svg_path.Arc(
        start: svg_path.Point(5.0, 0.0),
        radius: svg_path.Point(5.0, 5.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.Point(-5.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(-5.0, 0.0),
        end: svg_path.Point(-10.0, 0.0),
      ),
    ])
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 0.0, e: 0.0, f: 0.0)
  let assert Ok(transformed) = transform.subpath_gracefully(subpath, by: matrix)

  assert serialize.subpath(transformed) == "M -10 0 H 5 H -5 H -10"
}

pub fn graceful_closed_subpath_transform_preserves_semantic_closure_test() {
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Arc(
        start: svg_path.Point(5.0, 0.0),
        radius: svg_path.Point(5.0, 5.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.Point(-5.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(-5.0, 0.0),
        end: svg_path.Point(5.0, 0.0),
      ),
    ])
    |> result_try_set_closed_true
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 0.0, e: 0.0, f: 0.0)
  let assert Ok(transformed) = transform.subpath_gracefully(subpath, by: matrix)

  assert svg_path.subpath_is_closed(transformed)
  assert serialize.subpath(transformed) == "M 5 0 H -5 Z"
}

pub fn graceful_path_transform_converts_collapsed_arcs_in_each_subpath_test() {
  let assert Ok(first) =
    svg_path.subpath([
      svg_path.Arc(
        start: svg_path.Point(5.0, 0.0),
        radius: svg_path.Point(5.0, 5.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.Point(-5.0, 0.0),
      ),
    ])
  let assert Ok(second) =
    svg_path.subpath([
      svg_path.Line(
        start: svg_path.Point(0.0, 2.0),
        end: svg_path.Point(4.0, 2.0),
      ),
    ])
  let source = svg_path.Path([first, second])
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 0.0, e: 0.0, f: 3.0)
  let assert Ok(transformed) = transform.path_gracefully(source, by: matrix)

  assert serialize.path(transformed) == "M 5 3 H -5 M 0 3 H 4"
}

pub fn graceful_arc_transform_returns_vertical_collapsed_line_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.Point(0.0, 5.0),
      radius: svg_path.Point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: False,
      end: svg_path.Point(0.0, -5.0),
    )
  let matrix = transform.matrix(a: 0.0, b: 0.0, c: 0.0, d: 1.0, e: 10.0, f: 0.0)
  let assert Ok(segment) = transform.segment_gracefully(arc, by: matrix)

  assert serialize.segment(segment) == "M 10 -5 V 5"
}

pub fn graceful_non_degenerate_arc_transform_returns_arc_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.Point(0.0, 0.0),
      radius: svg_path.Point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: False,
      end: svg_path.Point(10.0, 0.0),
    )
  let assert Ok(segment) =
    transform.segment_gracefully(arc, by: transform.identity())

  assert serialize.segment(segment) == "M 0 0 A 5 5 0 0 0 10 0"
}

fn result_try_set_closed_true(
  result_subpath: Result(svg_path.Subpath, svg_path.Error),
) -> Result(svg_path.Subpath, svg_path.Error) {
  case result_subpath {
    Ok(subpath) -> svg_path.subpath_set_closed(subpath, closed: True)
    Error(error) -> Error(error)
  }
}

fn point_near(a: svg_path.Point, b: svg_path.Point) -> Bool {
  near(a.x, b.x) && near(a.y, b.y)
}

fn bbox_near(
  box: svg_path.BoundingBox,
  min min: svg_path.Point,
  max max: svg_path.Point,
) -> Bool {
  point_near(box.min, min) && point_near(box.max, max)
}

fn near(a: Float, b: Float) -> Bool {
  float.absolute_value(a -. b) <=. tolerance
}
