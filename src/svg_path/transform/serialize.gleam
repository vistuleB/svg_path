import gleam/float
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam_community/maths
import svg_path/transform as path_transform

pub type Options {
  Options(
    decimal_places: Option(Int),
    fixed_decimals: Bool,
    relative: Bool,
    minimize_whitespace: Bool,
    force_matrix: Bool,
  )
}

pub fn default_options() -> Options {
  Options(
    decimal_places: Some(5),
    fixed_decimals: False,
    relative: False,
    minimize_whitespace: False,
    force_matrix: False,
  )
}

pub fn decimal_options(decimal_places: Int) -> Options {
  Options(
    decimal_places: Some(decimal_places),
    fixed_decimals: False,
    relative: False,
    minimize_whitespace: False,
    force_matrix: False,
  )
}

pub fn fixed_decimal_options(decimal_places: Int) -> Options {
  Options(
    decimal_places: Some(decimal_places),
    fixed_decimals: True,
    relative: False,
    minimize_whitespace: False,
    force_matrix: False,
  )
}

pub fn relative_options() -> Options {
  Options(
    decimal_places: Some(5),
    fixed_decimals: False,
    relative: True,
    minimize_whitespace: False,
    force_matrix: False,
  )
}

pub fn relative_decimal_options(decimal_places: Int) -> Options {
  Options(
    decimal_places: Some(decimal_places),
    fixed_decimals: False,
    relative: True,
    minimize_whitespace: False,
    force_matrix: False,
  )
}

pub fn relative_fixed_decimal_options(decimal_places: Int) -> Options {
  Options(
    decimal_places: Some(decimal_places),
    fixed_decimals: True,
    relative: True,
    minimize_whitespace: False,
    force_matrix: False,
  )
}

pub fn minimize_whitespace(options: Options) -> Options {
  Options(..options, minimize_whitespace: True)
}

pub fn force_matrix(options: Options) -> Options {
  Options(..options, force_matrix: True)
}

pub fn to_string(transform: path_transform.Matrix) -> String {
  to_string_with_options(transform, default_options())
}

pub fn to_string_with_options(
  transform transform: path_transform.Matrix,
  options options: Options,
) -> String {
  let #(a, b, c, d, e, f) = path_transform.to_tuple(transform)

  case options.force_matrix {
    True -> matrix_transform(a, b, c, d, e, f, options)
    False -> {
      case a == 1.0 && b == 0.0 && c == 0.0 && d == 1.0 {
        True -> translate_transform(e, f, options)
        False -> {
          case b == 0.0 && c == 0.0 && e == 0.0 && f == 0.0 {
            True -> scale_transform(a, d, options)
            False -> {
              case b == 0.0 && c == 0.0 {
                True -> translate_scale_transform(e, f, a, d, options)
                False -> {
                  case
                    a == 1.0 && b == 0.0 && d == 1.0 && e == 0.0 && f == 0.0
                  {
                    True -> skew_x_transform(c, options)
                    False -> {
                      case
                        a == 1.0 && c == 0.0 && d == 1.0 && e == 0.0 && f == 0.0
                      {
                        True -> skew_y_transform(b, options)
                        False -> matrix_transform(a, b, c, d, e, f, options)
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

fn translate_transform(x: Float, y: Float, options: Options) -> String {
  let arguments = case y == 0.0 {
    True -> number(x, options)
    False -> number(x, options) <> " " <> number(y, options)
  }

  transform_function("translate", arguments)
}

fn scale_transform(x: Float, y: Float, options: Options) -> String {
  let arguments = case x == y {
    True -> number(x, options)
    False -> number(x, options) <> " " <> number(y, options)
  }

  transform_function("scale", arguments)
}

fn translate_scale_transform(
  translate_x: Float,
  translate_y: Float,
  scale_x: Float,
  scale_y: Float,
  options: Options,
) -> String {
  translate_transform(translate_x, translate_y, options)
  <> scale_transform(scale_x, scale_y, options)
}

fn skew_x_transform(tangent: Float, options: Options) -> String {
  transform_function("skewX", number(degrees_from_tangent(tangent), options))
}

fn skew_y_transform(tangent: Float, options: Options) -> String {
  transform_function("skewY", number(degrees_from_tangent(tangent), options))
}

fn matrix_transform(
  a: Float,
  b: Float,
  c: Float,
  d: Float,
  e: Float,
  f: Float,
  options: Options,
) -> String {
  transform_function(
    "matrix",
    number(a, options)
      <> " "
      <> number(b, options)
      <> " "
      <> number(c, options)
      <> " "
      <> number(d, options)
      <> " "
      <> number(e, options)
      <> " "
      <> number(f, options),
  )
}

fn transform_function(name: String, arguments: String) -> String {
  name <> "(" <> arguments <> ")"
}

fn degrees_from_tangent(tangent: Float) -> Float {
  maths.atan(tangent) *. 180.0 /. maths.pi()
}

fn number(number: Float, options: Options) -> String {
  case options.decimal_places {
    None -> float.to_string(number)
    Some(decimal_places) ->
      decimal(number, decimal_places, options.fixed_decimals)
  }
}

fn decimal(number: Float, decimal_places: Int, fixed_decimals: Bool) -> String {
  let fixed = fixed_decimal(number, decimal_places)

  case fixed_decimals {
    True -> fixed
    False -> strip_trailing_decimal_zeros(fixed)
  }
}

fn fixed_decimal(number: Float, decimal_places: Int) -> String {
  let decimal_places = int.max(decimal_places, 0)
  let scale = power_of_ten(decimal_places)
  let scaled = number *. scale |> float.round
  let sign = case scaled < 0 {
    True -> "-"
    False -> ""
  }
  let absolute_scaled = int.absolute_value(scaled)

  case decimal_places {
    0 -> sign <> int.to_string(absolute_scaled)
    _ -> {
      let whole = absolute_scaled / power_of_ten_int(decimal_places)
      let fractional = absolute_scaled % power_of_ten_int(decimal_places)
      let fractional =
        fractional
        |> int.to_string
        |> string.pad_start(to: decimal_places, with: "0")

      sign <> int.to_string(whole) <> "." <> fractional
    }
  }
}

fn strip_trailing_decimal_zeros(number: String) -> String {
  case string.split_once(number, on: ".") {
    Error(_) -> number
    Ok(#(whole, fractional)) -> {
      let fractional = strip_trailing_zeros(fractional)

      case fractional {
        "" -> whole
        _ -> whole <> "." <> fractional
      }
    }
  }
}

fn strip_trailing_zeros(string: String) -> String {
  case string.ends_with(string, "0") {
    True -> {
      string
      |> string.drop_end(up_to: 1)
      |> strip_trailing_zeros
    }
    False -> string
  }
}

fn power_of_ten(exponent: Int) -> Float {
  power_of_ten_int(exponent) |> int.to_float
}

fn power_of_ten_int(exponent: Int) -> Int {
  case exponent <= 0 {
    True -> 1
    False -> 10 * power_of_ten_int(exponent - 1)
  }
}
