import gleam/option.{None}
import gleam/string
import gleeunit
import svg_path/transform
import svg_path/transform/parse as transform_parse
import svg_path/transform/serialize

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn transform_translate_serializes_nicely_test() {
  assert serialize.to_string(transform.translate(x: 10.0, y: 0.0))
    == "translate(10)"
  assert serialize.to_string(transform.translate(x: 10.0, y: 20.0))
    == "translate(10 20)"
}

pub fn transform_scale_serializes_nicely_test() {
  assert serialize.to_string(transform.scale(factor: 2.0)) == "scale(2)"
  assert serialize.to_string(transform.scale_xy(x: 2.0, y: 3.0)) == "scale(2 3)"
}

pub fn transform_rotate_serializes_nicely_test() {
  assert serialize.to_string(transform.rotate(degrees: 90.0)) == "rotate(90)"
}

pub fn transform_scaled_rotate_serializes_nicely_test() {
  let matrix =
    transform.scale_xy(x: 2.0, y: 3.0)
    |> transform.chain(first: _, then: transform.rotate(degrees: 90.0))

  assert serialize.to_string(matrix) == "rotate(90) scale(2 3)"
}

pub fn transform_rotation_scale_recognition_is_scale_independent_test() {
  let matrix =
    transform.scale_xy(x: 2.0e6, y: 3.0e6)
    |> transform.chain(first: _, then: transform.rotate(degrees: 30.0))

  assert serialize.to_string(matrix) == "rotate(30) scale(2000000 3000000)"
}

pub fn transform_serialization_preserves_near_identity_rotation_scale_test() {
  let matrix =
    transform.scale(factor: 1.0000005)
    |> transform.chain(first: _, then: transform.rotate(degrees: 90.0))
  let options =
    serialize.Options(
      decimal_places: None,
      fixed_decimals: False,
      force_matrix: False,
    )

  assert serialize.to_string_with(matrix, options:)
    == "rotate(90) scale(1.0000005)"

  let machine_epsilon_scale =
    transform.scale(factor: 1.00000000000005)
    |> transform.chain(first: _, then: transform.rotate(degrees: 30.125))

  assert !string.contains(
    serialize.to_string_with(machine_epsilon_scale, options:),
    "scale",
  )
}

pub fn transform_translate_scale_serializes_nicely_test() {
  let matrix =
    transform.scale(factor: 2.0)
    |> transform.chain(first: _, then: transform.translate(x: 10.0, y: 20.0))

  assert serialize.to_string(matrix) == "translate(10 20) scale(2)"
}

pub fn transform_translate_scale_xy_serializes_nicely_test() {
  let matrix =
    transform.scale_xy(x: 2.0, y: 3.0)
    |> transform.chain(first: _, then: transform.translate(x: 10.0, y: 20.0))

  assert serialize.to_string(matrix) == "translate(10 20) scale(2 3)"
}

pub fn transform_translate_scaled_rotate_serializes_nicely_test() {
  let matrix =
    transform.scale_xy(x: 2.0, y: 3.0)
    |> transform.chain(first: _, then: transform.rotate(degrees: 90.0))
    |> transform.chain(first: _, then: transform.translate(x: 10.0, y: 20.0))

  assert serialize.to_string(matrix) == "translate(10 20) rotate(90) scale(2 3)"
}

pub fn transform_skew_serializes_nicely_test() {
  assert serialize.to_string_with(
      transform.skew_x(degrees: 45.0),
      options: serialize.decimal_options(3),
    )
    == "skewX(45)"
  assert serialize.to_string_with(
      transform.skew_y(degrees: -30.0),
      options: serialize.decimal_options(3),
    )
    == "skewY(-30)"
}

pub fn transform_translate_skew_serializes_nicely_test() {
  let matrix =
    transform.skew_x(degrees: 45.0)
    |> transform.chain(first: _, then: transform.translate(x: 10.0, y: 20.0))

  assert serialize.to_string_with(matrix, options: serialize.decimal_options(3))
    == "translate(10 20) skewX(45)"
}

pub fn transform_matrix_fallback_serializes_test() {
  let matrix =
    transform.matrix(a: 2.0, b: 3.0, c: 5.0, d: 7.0, e: 11.0, f: 13.0)

  assert serialize.to_string(matrix) == "matrix(2 3 5 7 11 13)"
}

pub fn transform_serialization_uses_decimal_options_test() {
  let matrix = transform.translate(x: 10.234, y: -20.235)

  assert serialize.to_string_with(
      matrix,
      options: serialize.fixed_decimal_options(2),
    )
    == "translate(10.23 -20.24)"
}

pub fn transform_serialization_uses_scientific_notation_when_scaling_is_unsafe_test() {
  let matrix = transform.translate(x: 1.0e20, y: -2.5e20)

  assert serialize.to_string_with(
      matrix,
      options: serialize.fixed_decimal_options(2),
    )
    == "translate(1.00e20 -2.50e20)"
}

pub fn transform_serialization_can_force_matrix_output_test() {
  let options = serialize.default_options() |> serialize.force_matrix

  assert serialize.to_string_with(
      transform.translate(x: 10.0, y: 20.0),
      options:,
    )
    == "matrix(1 0 0 1 10 20)"
  assert serialize.to_string_with(transform.scale(factor: 2.0), options:)
    == "matrix(2 0 0 2 0 0)"
}

pub fn transform_translate_scale_can_force_matrix_output_test() {
  let options = serialize.default_options() |> serialize.force_matrix
  let matrix =
    transform.scale_xy(x: 2.0, y: 3.0)
    |> transform.chain(first: _, then: transform.translate(x: 10.0, y: 20.0))

  assert serialize.to_string_with(matrix, options:) == "matrix(2 0 0 3 10 20)"
}

pub fn parsed_transform_serializes_to_canonical_translate_scale_test() {
  let assert Ok(matrix) = transform_parse.attribute("translate(10,20) scale(2)")

  assert serialize.to_string(matrix) == "translate(10 20) scale(2)"
}

pub fn parsed_transform_serializes_to_canonical_scale_translate_test() {
  let assert Ok(matrix) = transform_parse.attribute("scale(2) translate(10 20)")

  assert serialize.to_string(matrix) == "translate(20 40) scale(2)"
}

pub fn parsed_matrix_serializes_to_nicer_transform_test() {
  let assert Ok(matrix) = transform_parse.attribute("matrix(2 0 0 3 10 20)")

  assert serialize.to_string(matrix) == "translate(10 20) scale(2 3)"
}

pub fn parsed_rotation_matrix_serializes_to_nicer_transform_test() {
  let assert Ok(matrix) = transform_parse.attribute("matrix(0 2 -3 0 10 20)")

  assert serialize.to_string(matrix) == "translate(10 20) rotate(90) scale(2 3)"
}

pub fn parsed_rotate_transform_serializes_nicely_test() {
  let assert Ok(matrix) = transform_parse.attribute("rotate(30.125)")

  assert serialize.to_string(matrix) == "rotate(30.125)"
}

pub fn parsed_translate_rotate_scale_transform_serializes_nicely_test() {
  let assert Ok(matrix) =
    transform_parse.attribute("translate(10 20) rotate(30.125) scale(2 3)")

  assert serialize.to_string(matrix)
    == "translate(10 20) rotate(30.125) scale(2 3)"
}

pub fn parsed_rotate_transform_uses_requested_decimal_options_test() {
  let assert Ok(matrix) = transform_parse.attribute("rotate(30.000001)")

  assert serialize.to_string_with(matrix, options: serialize.decimal_options(6))
    == "rotate(30.000001)"
}

pub fn reflected_rotation_matrix_uses_matrix_fallback_test() {
  let assert Ok(matrix) = transform_parse.attribute("matrix(0 2 3 0 10 20)")

  assert serialize.to_string(matrix) == "matrix(0 2 3 0 10 20)"
}

pub fn parsed_unmatched_transform_serializes_to_matrix_test() {
  let assert Ok(matrix) = transform_parse.attribute("skewX(30) scale(2)")

  assert serialize.to_string_with(matrix, options: serialize.decimal_options(3))
    == "matrix(2 0 1.155 2 0 0)"
}
