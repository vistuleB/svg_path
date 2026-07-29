import gleeunit
import svg_path
import svg_path/serialize
import svg_path/transform
import svg_path/transform/parse as transform_parse

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn empty_attribute_is_identity_test() {
  let assert Ok(matrix) = transform_parse.attribute("")

  assert transform.point(svg_path.Point(2.0, 3.0), by: matrix)
    == svg_path.Point(2.0, 3.0)
}

pub fn matrix_transform_parses_test() {
  let assert Ok(matrix) = transform_parse.attribute("matrix(2 3 5 7 11 13)")

  assert transform.point(svg_path.Point(2.0, 3.0), by: matrix)
    == svg_path.Point(30.0, 40.0)
}

pub fn translate_accepts_one_or_two_arguments_test() {
  let assert Ok(x_only) = transform_parse.attribute("translate(5)")
  let assert Ok(xy) = transform_parse.attribute("translate(5 -7)")

  assert transform.point(svg_path.Point(2.0, 3.0), by: x_only)
    == svg_path.Point(7.0, 3.0)
  assert transform.point(svg_path.Point(2.0, 3.0), by: xy)
    == svg_path.Point(7.0, -4.0)
}

pub fn scale_accepts_one_or_two_arguments_test() {
  let assert Ok(uniform) = transform_parse.attribute("scale(4)")
  let assert Ok(xy) = transform_parse.attribute("scale(4 -2)")

  assert transform.point(svg_path.Point(2.0, 3.0), by: uniform)
    == svg_path.Point(8.0, 12.0)
  assert transform.point(svg_path.Point(2.0, 3.0), by: xy)
    == svg_path.Point(8.0, -6.0)
}

pub fn rotate_about_center_parses_test() {
  let line =
    svg_path.Line(
      start: svg_path.Point(2.0, 1.0),
      end: svg_path.Point(2.0, 3.0),
    )
  let assert Ok(matrix) = transform_parse.attribute("rotate(90 1 1)")
  let assert Ok(segment) = transform.segment(line, by: matrix)

  assert serialize.segment(segment) == "M 1 2 H -1"
}

pub fn skew_transforms_parse_test() {
  let assert Ok(matrix) = transform_parse.attribute("skewX(45) skewY(45)")

  assert transform.point(svg_path.Point(2.0, 3.0), by: matrix)
    == svg_path.Point(7.0, 5.0)
}

pub fn transform_list_uses_svg_matrix_order_test() {
  let assert Ok(matrix) = transform_parse.attribute("translate(10 20) scale(2)")

  assert transform.point(svg_path.Point(1.0, 1.0), by: matrix)
    == svg_path.Point(12.0, 22.0)
}

pub fn commas_whitespace_and_compact_numbers_parse_test() {
  let input = "translate(10,20)\nscale(.5 -2) rotate(+0e0)"
  let assert Ok(matrix) = transform_parse.attribute(input)

  assert transform.point(svg_path.Point(4.0, -3.0), by: matrix)
    == svg_path.Point(12.0, 26.0)
}

pub fn adjacent_signed_numbers_parse_test() {
  let assert Ok(matrix) = transform_parse.attribute("translate(10-20)")

  assert transform.point(svg_path.Point(1.0, 1.0), by: matrix)
    == svg_path.Point(11.0, -19.0)
}

pub fn unknown_transform_is_rejected_test() {
  assert transform_parse.attribute("perspective(1)")
    == Error(transform_parse.UnknownTransform("perspective"))
}

pub fn wrong_argument_count_is_rejected_test() {
  assert transform_parse.attribute("translate(1 2 3)")
    == Error(transform_parse.InvalidArgumentCount("translate", 3))
}

pub fn missing_close_is_rejected_test() {
  assert transform_parse.attribute("scale(2")
    == Error(transform_parse.ExpectedClose)
}
