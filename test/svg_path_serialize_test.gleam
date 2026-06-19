import gleeunit
import svg_path
import svg_path/serialize
import svg_path/transform
import svg_path/transform/parse as transform_parse

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn empty_path_serializes_to_empty_string_test() {
  assert serialize.path(svg_path.empty_path()) == ""
}

pub fn empty_subpath_serializes_to_empty_string_test() {
  assert serialize.subpath(svg_path.empty_subpath()) == ""
}

pub fn path_ignores_empty_subpaths_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let assert Ok(subpath) = svg_path.subpath([svg_path.line(start: a, end: b)])
  let path =
    svg_path.path([
      svg_path.empty_subpath(),
      subpath,
      svg_path.empty_subpath(),
    ])

  assert serialize.path(path) == "M 0 0 H 10"
}

pub fn open_subpath_serializes_absolute_commands_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0, 20.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
    ])

  assert serialize.subpath(subpath) == "M 0 0 H 10 V 20"
}

pub fn closed_subpath_serializes_with_z_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0, 20.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
    ])
    |> result_try_force_close

  assert serialize.subpath(subpath) == "M 0 0 H 10 V 20 L 0 0 Z"
}

pub fn bezier_and_arc_segments_serialize_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 10.0)
  let d = svg_path.point(30.0, 0.0)
  let e = svg_path.point(40.0, 20.0)
  let radius = svg_path.point(5.0, 8.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.quadratic_bezier(start: a, control: b, end: c),
      svg_path.cubic_bezier(start: c, control1: d, control2: e, end: b),
      svg_path.arc(
        start: b,
        radius: radius,
        x_axis_rotation: 45.0,
        large_arc: True,
        sweep: False,
        end: a,
      ),
    ])

  assert serialize.subpath(subpath)
    == "M 0 0 Q 10 0 20 10 C 30 0 40 20 10 0 A 5 8 45 1 0 0 0"
}

pub fn fixed_decimal_options_round_and_pad_numbers_test() {
  let a = svg_path.point(0.0, 1.2)
  let b = svg_path.point(10.234, -20.235)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(start: a, end: b),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.fixed_decimal_options(2),
    )
    == "M 0.00 1.20 L 10.23 -20.24"
}

pub fn decimal_options_round_and_strip_trailing_zeros_test() {
  let a = svg_path.point(0.0, 1.2)
  let b = svg_path.point(10.234, -20.235)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(start: a, end: b),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.decimal_options(3),
    )
    == "M 0 1.2 L 10.234 -20.235"
}

pub fn fixed_decimal_options_keep_trailing_zeros_test() {
  let a = svg_path.point(1.0, 1.2)
  let b = svg_path.point(10.0, -20.0)

  assert serialize.segment_with_options(
      svg_path.line(start: a, end: b),
      options: serialize.fixed_decimal_options(3),
    )
    == "M 1.000 1.200 L 10.000 -20.000"
}

pub fn fixed_decimal_options_can_use_zero_places_test() {
  let a = svg_path.point(0.4, 1.5)
  let b = svg_path.point(10.49, -20.5)

  assert serialize.segment_with_options(
      svg_path.line(start: a, end: b),
      options: serialize.fixed_decimal_options(0),
    )
    == "M 0 2 L 10 -21"
}

pub fn minimize_whitespace_removes_command_spacing_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0, 20.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.decimal_options(0) |> serialize.minimize_whitespace,
    )
    == "M0 0H10V20"
}

pub fn relative_options_use_relative_line_commands_test() {
  let a = svg_path.point(10.0, 20.0)
  let b = svg_path.point(13.0, 18.0)

  assert serialize.segment_with_options(
      svg_path.line(start: a, end: b),
      options: serialize.relative_decimal_options(0),
    )
    == "m 10 20 l 3 -2"
}

pub fn relative_options_use_relative_curve_commands_test() {
  let start = svg_path.point(10.0, 20.0)
  let quadratic =
    svg_path.quadratic_bezier(
      start: start,
      control: svg_path.point(12.0, 23.0),
      end: svg_path.point(15.0, 25.0),
    )
  let cubic =
    svg_path.cubic_bezier(
      start: start,
      control1: svg_path.point(11.0, 21.0),
      control2: svg_path.point(14.0, 24.0),
      end: svg_path.point(18.0, 28.0),
    )

  assert serialize.segment_with_options(
      quadratic,
      options: serialize.relative_decimal_options(0),
    )
    == "m 10 20 q 2 3 5 5"
  assert serialize.segment_with_options(
      cubic,
      options: serialize.relative_decimal_options(0),
    )
    == "m 10 20 c 1 1 4 4 8 8"
}

pub fn transform_translate_serializes_nicely_test() {
  assert serialize.transform(transform.translate(x: 10.0, y: 0.0))
    == "translate(10)"
  assert serialize.transform(transform.translate(x: 10.0, y: 20.0))
    == "translate(10 20)"
}

pub fn transform_scale_serializes_nicely_test() {
  assert serialize.transform(transform.scale(factor: 2.0)) == "scale(2)"
  assert serialize.transform(transform.scale_xy(x: 2.0, y: 3.0)) == "scale(2 3)"
}

pub fn transform_translate_scale_serializes_nicely_test() {
  let matrix =
    transform.scale(factor: 2.0)
    |> transform.compose(first: _, then: transform.translate(x: 10.0, y: 20.0))

  assert serialize.transform(matrix) == "translate(10 20)scale(2)"
}

pub fn transform_translate_scale_xy_serializes_nicely_test() {
  let matrix =
    transform.scale_xy(x: 2.0, y: 3.0)
    |> transform.compose(first: _, then: transform.translate(x: 10.0, y: 20.0))

  assert serialize.transform(matrix) == "translate(10 20)scale(2 3)"
}

pub fn transform_skew_serializes_nicely_test() {
  assert serialize.transform_with_options(
      transform.skew_x(degrees: 45.0),
      options: serialize.decimal_options(3),
    )
    == "skewX(45)"
  assert serialize.transform_with_options(
      transform.skew_y(degrees: -30.0),
      options: serialize.decimal_options(3),
    )
    == "skewY(-30)"
}

pub fn transform_matrix_fallback_serializes_test() {
  let matrix =
    transform.matrix(a: 2.0, b: 3.0, c: 5.0, d: 7.0, e: 11.0, f: 13.0)

  assert serialize.transform(matrix) == "matrix(2 3 5 7 11 13)"
}

pub fn transform_serialization_uses_decimal_options_test() {
  let matrix = transform.translate(x: 10.234, y: -20.235)

  assert serialize.transform_with_options(
      matrix,
      options: serialize.fixed_decimal_options(2),
    )
    == "translate(10.23 -20.24)"
}

pub fn transform_serialization_can_force_matrix_output_test() {
  let options = serialize.default_options() |> serialize.force_matrix_transform

  assert serialize.transform_with_options(
      transform.translate(x: 10.0, y: 20.0),
      options:,
    )
    == "matrix(1 0 0 1 10 20)"
  assert serialize.transform_with_options(
      transform.scale(factor: 2.0),
      options:,
    )
    == "matrix(2 0 0 2 0 0)"
}

pub fn transform_translate_scale_can_force_matrix_output_test() {
  let options = serialize.default_options() |> serialize.force_matrix_transform
  let matrix =
    transform.scale_xy(x: 2.0, y: 3.0)
    |> transform.compose(first: _, then: transform.translate(x: 10.0, y: 20.0))

  assert serialize.transform_with_options(matrix, options:)
    == "matrix(2 0 0 3 10 20)"
}

pub fn parsed_transform_serializes_to_canonical_translate_scale_test() {
  let assert Ok(matrix) = transform_parse.attribute("translate(10,20) scale(2)")

  assert serialize.transform(matrix) == "translate(10 20)scale(2)"
}

pub fn parsed_transform_serializes_to_canonical_scale_translate_test() {
  let assert Ok(matrix) = transform_parse.attribute("scale(2)translate(10 20)")

  assert serialize.transform(matrix) == "translate(20 40)scale(2)"
}

pub fn parsed_matrix_serializes_to_nicer_transform_test() {
  let assert Ok(matrix) = transform_parse.attribute("matrix(2 0 0 3 10 20)")

  assert serialize.transform(matrix) == "translate(10 20)scale(2 3)"
}

pub fn parsed_unmatched_transform_serializes_to_matrix_test() {
  let assert Ok(matrix) = transform_parse.attribute("skewX(30)scale(2)")

  assert serialize.transform_with_options(
      matrix,
      options: serialize.decimal_options(3),
    )
    == "matrix(2 0 1.155 2 0 0)"
}

pub fn relative_options_use_relative_arc_endpoint_test() {
  let arc =
    svg_path.arc(
      start: svg_path.point(10.0, 20.0),
      radius: svg_path.point(5.0, 8.0),
      x_axis_rotation: 45.0,
      large_arc: True,
      sweep: False,
      end: svg_path.point(13.0, 18.0),
    )

  assert serialize.segment_with_options(
      arc,
      options: serialize.relative_decimal_options(0),
    )
    == "m 10 20 a 5 8 45 1 0 3 -2"
}

pub fn relative_minimize_whitespace_removes_command_spacing_test() {
  let a = svg_path.point(10.0, 20.0)
  let b = svg_path.point(13.0, 18.0)

  assert serialize.segment_with_options(
      svg_path.line(start: a, end: b),
      options: serialize.relative_decimal_options(0)
        |> serialize.minimize_whitespace,
    )
    == "m10 20l3 -2"
}

pub fn relative_options_make_moves_relative_between_subpaths_test() {
  let a = svg_path.point(10.0, 10.0)
  let b = svg_path.point(20.0, 10.0)
  let c = svg_path.point(25.0, 30.0)
  let d = svg_path.point(30.0, 30.0)
  let assert Ok(first) = svg_path.subpath([svg_path.line(start: a, end: b)])
  let assert Ok(second) = svg_path.subpath([svg_path.line(start: c, end: d)])

  assert serialize.path_with_options(
      svg_path.path([first, svg_path.empty_subpath(), second]),
      options: serialize.relative_decimal_options(0),
    )
    == "m 10 10 h 10 m 5 20 h 5"
}

pub fn relative_options_move_from_closed_subpath_start_after_z_test() {
  let a = svg_path.point(10.0, 10.0)
  let b = svg_path.point(20.0, 10.0)
  let c = svg_path.point(30.0, 10.0)
  let d = svg_path.point(40.0, 10.0)
  let assert Ok(first) =
    svg_path.subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: a),
    ])
    |> result_try_close
  let assert Ok(second) = svg_path.subpath([svg_path.line(start: c, end: d)])

  assert serialize.path_with_options(
      svg_path.path([first, second]),
      options: serialize.relative_decimal_options(0),
    )
    == "m 10 10 h 10 h -10 Z m 20 0 h 10"
}

pub fn minimized_relative_path_with_multiple_subpaths_test() {
  let a = svg_path.point(10.0, 10.0)
  let b = svg_path.point(20.0, 10.0)
  let c = svg_path.point(25.0, 30.0)
  let d = svg_path.point(30.0, 30.0)
  let assert Ok(first) = svg_path.subpath([svg_path.line(start: a, end: b)])
  let assert Ok(second) = svg_path.subpath([svg_path.line(start: c, end: d)])

  assert serialize.path_with_options(
      svg_path.path([first, second]),
      options: serialize.relative_decimal_options(0)
        |> serialize.minimize_whitespace,
    )
    == "m10 10h10m5 20h5"
}

pub fn decimal_options_clamp_negative_decimal_places_to_zero_test() {
  let segment =
    svg_path.line(
      start: svg_path.point(0.4, 1.5),
      end: svg_path.point(10.49, -20.5),
    )

  assert serialize.segment_with_options(
      segment,
      options: serialize.decimal_options(-3),
    )
    == "M 0 2 L 10 -21"
}

pub fn rounded_absolute_line_uses_h_or_v_after_formatting_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.000001)
  let c = svg_path.point(10.000001, 20.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.decimal_options(5),
    )
    == "M 0 0 H 10 V 20"
}

pub fn rounded_relative_line_uses_h_or_v_after_formatting_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.000001)
  let c = svg_path.point(10.000001, 20.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(start: a, end: b),
      svg_path.line(start: b, end: c),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.relative_decimal_options(5),
    )
    == "m 0 0 h 10 v 20"
}

fn result_try_force_close(
  result_subpath: Result(svg_path.Subpath, svg_path.Error),
) -> Result(svg_path.Subpath, svg_path.Error) {
  case result_subpath {
    Ok(subpath) -> svg_path.force_close(subpath)
    Error(error) -> Error(error)
  }
}

fn result_try_close(
  result_subpath: Result(svg_path.Subpath, svg_path.Error),
) -> Result(svg_path.Subpath, svg_path.Error) {
  case result_subpath {
    Ok(subpath) -> svg_path.close(subpath)
    Error(error) -> Error(error)
  }
}
