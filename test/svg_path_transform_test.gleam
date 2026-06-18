import gleeunit
import svg_path
import svg_path/serialize
import svg_path/transform

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn matrix_transforms_points_test() {
  let point = svg_path.point(2.0, 3.0)
  let matrix =
    transform.matrix(a: 2.0, b: 3.0, c: 5.0, d: 7.0, e: 11.0, f: 13.0)

  assert transform.point(point, by: matrix) == svg_path.point(30.0, 40.0)
}

pub fn line_transform_test() {
  let matrix =
    transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 10.0, f: -5.0)
  let assert Ok(segment) =
    svg_path.line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(5.0, 0.0),
    )
    |> transform.segment(by: matrix)

  assert serialize.segment(segment) == "M 10 -5 H 15"
}

pub fn quadratic_and_cubic_bezier_transform_test() {
  let matrix = transform.matrix(a: 2.0, b: 0.0, c: 0.0, d: 3.0, e: 0.0, f: 0.0)
  let assert Ok(quadratic) =
    svg_path.quadratic_bezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(1.0, 2.0),
      end: svg_path.point(3.0, 4.0),
    )
    |> transform.segment(by: matrix)
  let assert Ok(cubic) =
    svg_path.cubic_bezier(
      start: svg_path.point(0.0, 0.0),
      control1: svg_path.point(1.0, 2.0),
      control2: svg_path.point(3.0, 4.0),
      end: svg_path.point(5.0, 6.0),
    )
    |> transform.segment(by: matrix)

  assert serialize.segment(quadratic) == "M 0 0 Q 2 6 6 12"
  assert serialize.segment(cubic) == "M 0 0 C 2 6 6 12 10 18"
}

pub fn closed_subpath_transform_preserves_semantic_closure_test() {
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 10.0, f: 0.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 0.0),
      ),
      svg_path.line(
        start: svg_path.point(10.0, 0.0),
        end: svg_path.point(0.0, 0.0),
      ),
    ])
    |> result_try_close
  let assert Ok(transformed) = transform.subpath(subpath, by: matrix)

  assert svg_path.is_closed(transformed)
  assert serialize.subpath(transformed) == "M 10 0 H 20 H 10 Z"
}

pub fn path_transform_test() {
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 1.0, f: 2.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(10.0, 0.0),
      ),
    ])
  let assert Ok(path) =
    svg_path.path([svg_path.empty_subpath(), subpath])
    |> transform.path(by: matrix)

  assert serialize.path(path) == "M 1 2 H 11"
}

pub fn arc_identity_transform_preserves_arc_test() {
  let arc =
    svg_path.arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: False,
      end: svg_path.point(10.0, 0.0),
    )
  let assert Ok(transformed) = transform.segment(arc, by: transform.identity())

  assert serialize.segment(transformed) == "M 0 0 A 5 5 0 0 0 10 0"
}

pub fn arc_non_uniform_scale_transform_test() {
  let arc =
    svg_path.arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(5.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: True,
      sweep: False,
      end: svg_path.point(5.0, 10.0),
    )
  let matrix = transform.matrix(a: 2.0, b: 0.0, c: 0.0, d: 3.0, e: 0.0, f: 0.0)
  let assert Ok(transformed) = transform.segment(arc, by: matrix)

  assert serialize.segment(transformed) == "M 0 0 A 10 30 0 1 0 10 30"
}

pub fn arc_shear_transform_test() {
  let arc =
    svg_path.arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(10.0, 0.0),
    )
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 1.0, d: 1.0, e: 0.0, f: 0.0)
  let assert Ok(transformed) = transform.segment(arc, by: matrix)

  assert serialize.segment_with_options(
      transformed,
      options: serialize.decimal_options(3),
    )
    == "M 0 0 A 8.09 3.09 31.717 0 1 10 0"
}

pub fn arc_reflection_flips_sweep_test() {
  let arc =
    svg_path.arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(10.0, 0.0),
    )
  let matrix = transform.matrix(a: -1.0, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: 0.0)
  let assert Ok(transformed) = transform.segment(arc, by: matrix)

  assert serialize.segment(transformed) == "M 0 0 A 5 5 0 0 0 -10 0"
}

pub fn arc_degenerate_transform_errors_test() {
  let arc =
    svg_path.arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: False,
      end: svg_path.point(10.0, 0.0),
    )
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 0.0, e: 0.0, f: 0.0)

  assert transform.segment(arc, by: matrix)
    == Error(transform.DegenerateArcTransform)
}

pub fn strict_subpath_transform_errors_on_collapsed_arc_test() {
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.arc(
        start: svg_path.point(5.0, 0.0),
        radius: svg_path.point(5.0, 5.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.point(-5.0, 0.0),
      ),
    ])
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 0.0, e: 0.0, f: 0.0)

  assert transform.subpath(subpath, by: matrix)
    == Error(transform.DegenerateArcTransform)
}

pub fn graceful_arc_transform_returns_collapsed_line_test() {
  let arc =
    svg_path.arc(
      start: svg_path.point(5.0, 0.0),
      radius: svg_path.point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(-5.0, 0.0),
    )
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 0.0, e: 0.0, f: 0.0)
  let assert Ok(segment) = transform.segment_gracefully(arc, by: matrix)

  assert serialize.segment(segment) == "M -5 0 H 5"
}

pub fn graceful_arc_transform_follows_full_collapse_to_point_test() {
  let arc =
    svg_path.arc(
      start: svg_path.point(5.0, 0.0),
      radius: svg_path.point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(-5.0, 0.0),
    )
  let matrix = transform.matrix(a: 0.0, b: 0.0, c: 0.0, d: 0.0, e: 7.0, f: 11.0)
  let assert Ok(segment) = transform.segment_gracefully(arc, by: matrix)

  assert serialize.segment(segment) == "M 7 11 H 7"
}

pub fn graceful2_arc_transform_preserves_transformed_endpoints_test() {
  let arc =
    svg_path.arc(
      start: svg_path.point(5.0, 0.0),
      radius: svg_path.point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(-5.0, 0.0),
    )
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 0.0, e: 0.0, f: 0.0)
  let assert Ok(subpath) = transform.segment_gracefully2(arc, by: matrix)

  assert serialize.subpath(subpath) == "M 5 0 H -5"
}

pub fn graceful2_line_transform_returns_single_segment_subpath_test() {
  let line =
    svg_path.line(
      start: svg_path.point(1.0, 2.0),
      end: svg_path.point(4.0, 2.0),
    )
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 10.0, f: 0.0)
  let assert Ok(subpath) = transform.segment_gracefully2(line, by: matrix)

  assert serialize.subpath(subpath) == "M 11 2 H 14"
}

pub fn graceful2_arc_transform_preserves_out_and_back_motion_test() {
  let arc =
    svg_path.arc(
      start: svg_path.point(3.5355339059, -3.5355339059),
      radius: svg_path.point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(3.5355339059, 3.5355339059),
    )
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 0.0, e: 0.0, f: 0.0)
  let assert Ok(subpath) = transform.segment_gracefully2(arc, by: matrix)

  assert serialize.subpath(subpath) == "M 3.53553 0 H 5 H 3.53553"
}

pub fn graceful2_arc_transform_follows_full_collapse_to_point_test() {
  let arc =
    svg_path.arc(
      start: svg_path.point(5.0, 0.0),
      radius: svg_path.point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.point(-5.0, 0.0),
    )
  let matrix = transform.matrix(a: 0.0, b: 0.0, c: 0.0, d: 0.0, e: 7.0, f: 11.0)
  let assert Ok(subpath) = transform.segment_gracefully2(arc, by: matrix)

  assert serialize.subpath(subpath) == "M 7 11 H 7"
}

pub fn graceful_subpath_transform_keeps_surrounding_continuity_test() {
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(
        start: svg_path.point(-10.0, 0.0),
        end: svg_path.point(5.0, 0.0),
      ),
      svg_path.arc(
        start: svg_path.point(5.0, 0.0),
        radius: svg_path.point(5.0, 5.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.point(-5.0, 0.0),
      ),
      svg_path.line(
        start: svg_path.point(-5.0, 0.0),
        end: svg_path.point(-10.0, 0.0),
      ),
    ])
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 0.0, e: 0.0, f: 0.0)
  let assert Ok(transformed) = transform.subpath_gracefully(subpath, by: matrix)

  assert serialize.subpath(transformed) == "M -10 0 H 5 H -5 H -10"
}

pub fn graceful_closed_subpath_transform_preserves_semantic_closure_test() {
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.arc(
        start: svg_path.point(5.0, 0.0),
        radius: svg_path.point(5.0, 5.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: svg_path.point(-5.0, 0.0),
      ),
      svg_path.line(
        start: svg_path.point(-5.0, 0.0),
        end: svg_path.point(5.0, 0.0),
      ),
    ])
    |> result_try_close
  let matrix = transform.matrix(a: 1.0, b: 0.0, c: 0.0, d: 0.0, e: 0.0, f: 0.0)
  let assert Ok(transformed) = transform.subpath_gracefully(subpath, by: matrix)

  assert svg_path.is_closed(transformed)
  assert serialize.subpath(transformed) == "M 5 0 H -5 H 5 Z"
}

pub fn graceful_arc_transform_returns_vertical_collapsed_line_test() {
  let arc =
    svg_path.arc(
      start: svg_path.point(0.0, 5.0),
      radius: svg_path.point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: False,
      end: svg_path.point(0.0, -5.0),
    )
  let matrix = transform.matrix(a: 0.0, b: 0.0, c: 0.0, d: 1.0, e: 10.0, f: 0.0)
  let assert Ok(segment) = transform.segment_gracefully(arc, by: matrix)

  assert serialize.segment(segment) == "M 10 -5 V 5"
}

pub fn graceful_non_degenerate_arc_transform_returns_arc_test() {
  let arc =
    svg_path.arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(5.0, 5.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: False,
      end: svg_path.point(10.0, 0.0),
    )
  let assert Ok(segment) =
    transform.segment_gracefully(arc, by: transform.identity())

  assert serialize.segment(segment) == "M 0 0 A 5 5 0 0 0 10 0"
}

fn result_try_close(
  result_subpath: Result(svg_path.Subpath, svg_path.Error),
) -> Result(svg_path.Subpath, svg_path.Error) {
  case result_subpath {
    Ok(subpath) -> svg_path.close(subpath)
    Error(error) -> Error(error)
  }
}
