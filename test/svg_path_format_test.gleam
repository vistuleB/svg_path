import gleam/string
import gleeunit
import svg_path/format

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn decimal_places_are_clamped_to_shared_target_limit_test() {
  let options = format.Options(
    left_decimals: format.Succinct,
    right_decimals: format.Fixed(101),
  )

  assert format.raw_number(1.0e20, options)
    == "1." <> string.repeat("0", times: 100) <> "e20"
}
