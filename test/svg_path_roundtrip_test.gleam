import gleeunit
import svg_path/parse
import svg_path/serialize

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn absolute_line_subset_canonicalizes_test() {
  assert parse_and_serialize("M 0 0 L 10 0 V 20 H 0")
    == Ok("M 0 0 H 10 V 20 H 0")
}

pub fn relative_line_subset_canonicalizes_to_absolute_by_default_test() {
  assert parse_and_serialize("m 10 10 l 5 0 v 20 h -5")
    == Ok("M 10 10 H 15 V 30 H 10")
}

pub fn compact_input_canonicalizes_test() {
  assert parse_and_serialize("M0-1L10-1V9H0z")
    == Ok("M 0 -1 H 10 V 9 H 0 V -1 Z")
}

pub fn comma_separated_input_canonicalizes_test() {
  assert parse_and_serialize("M0,0 L10,0 10,20") == Ok("M 0 0 H 10 V 20")
}

pub fn move_only_subpaths_disappear_test() {
  assert parse_and_serialize("M 0 0 M 10 10 L 20 10 M 30 30")
    == Ok("M 10 10 H 20")
}

pub fn relative_serialization_after_parsing_test() {
  assert parse_and_serialize_with_options(
      "M 10 10 L 20 10 L 20 30",
      serialize.relative_decimal_options(0),
    )
    == Ok("m 10 10 h 10 v 20")
}

pub fn minimized_serialization_after_parsing_test() {
  assert parse_and_serialize_with_options(
      "M 0 0 L 10 0 L 10 20",
      serialize.decimal_options(0) |> serialize.minimize_whitespace,
    )
    == Ok("M0 0H10V20")
}

pub fn decimal_rounding_after_parsing_test() {
  assert parse_and_serialize_with_options(
      "M 0.000001 1.234567 L 10.000001 1.234568",
      serialize.decimal_options(5),
    )
    == Ok("M 0 1.23457 H 10")
}

fn parse_and_serialize(input: String) -> Result(String, parse.Error) {
  parse_and_serialize_with_options(input, serialize.default_options())
}

fn parse_and_serialize_with_options(
  input: String,
  options: serialize.Options,
) -> Result(String, parse.Error) {
  case parse.path(input) {
    Error(error) -> Error(error)
    Ok(path) -> Ok(serialize.path_with_options(path, options:))
  }
}
