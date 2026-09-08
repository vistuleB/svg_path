import gleam/list
import svg_path/internal/number
import svg_path/transform/parse as transform_parse

const maximum = 1.7976931348623157e308

pub fn checked_product_rejects_rounded_guard_boundary_test() {
  let boundary = maximum /. 3.0
  list.each([1.0, -1.0], fn(sign) {
    assert number.checked_product(sign *. boundary, 3.0) == Error(Nil)
    assert number.checked_product(3.0, sign *. boundary) == Error(Nil)
  })
}

pub fn checked_sum_rejects_rounded_guard_boundary_test() {
  let a = 1.7658771479739417e308
  let b = 3.181598688837415e306
  list.each([1.0, -1.0], fn(sign) {
    assert number.checked_sum(sign *. a, sign *. b) == Error(Nil)
    assert number.checked_sum(sign *. b, sign *. a) == Error(Nil)
  })
}

pub fn checked_arithmetic_accepts_finite_extremes_test() {
  assert number.checked_product(maximum, 1.0) == Ok(maximum)
  assert number.checked_product(maximum, -1.0) == Ok(0.0 -. maximum)
  assert number.checked_product(maximum /. 2.0, 2.0) == Ok(maximum)
  assert number.checked_sum(maximum /. 2.0, maximum /. 2.0) == Ok(maximum)
  assert number.checked_sum(maximum, 0.0 -. maximum) == Ok(0.0)
  assert number.checked_sum(maximum, 0.0) == Ok(maximum)
  assert number.checked_product(maximum, 0.0) == Ok(0.0)
}

pub fn checked_arithmetic_accepts_ordinary_values_and_underflow_test() {
  assert number.checked_sum(1.25, 2.5) == Ok(3.75)
  assert number.checked_product(-2.0, 3.0) == Ok(-6.0)
  assert number.checked_product(1.0e-300, 1.0e-300) == Ok(0.0)
}

pub fn transform_parser_reports_product_overflow_without_raising_test() {
  // Full decimal spelling avoids the parser's separate exponent-scaling
  // rounding, and reproduces exactly the maximum / 3 multiplication boundary.
  let input =
    "scale(59923104495410526931242990468434471693311377570012608978724592993481656097588250315549672659195735698776762138897629303648851849283980134210219162890501940227302967333569461225424618281939237177254825243423356618523788986540947638273286944978825097573024722814788503568114237186566502697680960059301391499264) scale(3)"
  let assert Error(transform_parse.ParseError(kind, _)) =
    transform_parse.attribute(input)
  assert kind == transform_parse.NonFiniteTransform
}
