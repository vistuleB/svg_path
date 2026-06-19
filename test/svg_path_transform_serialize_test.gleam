import gleeunit
import svg_path/transform
import svg_path/transform/parse as transform_parse
import svg_path/transform/serialize

pub fn main() -> Nil {
  gleeunit.main()
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
  let options = serialize.default_options() |> serialize.force_matrix

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
  let options = serialize.default_options() |> serialize.force_matrix
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
