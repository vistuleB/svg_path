//// SVG transform attribute serializer.
////
//// This module serializes affine matrices as SVG transform attribute strings.
//// It prefers readable transform functions such as `translate`, `scale`,
//// `rotate`, and `skew` when a matrix clearly matches them, and falls back to
//// `matrix(a b c d e f)` otherwise.

import gleam/float
import gleam/option.{type Option, None, Some}
import svg_path/format as number_format
import svg_path/transform as path_transform
import svg_path/trig

const rotation_scale_epsilon = 0.000001

type LinearTransform {
  Matrix2x2
  Identity2x2
  Scale2x2(x: Float, y: Float)
  SkewX2x2(tangent: Float)
  SkewY2x2(tangent: Float)
  RotateScale2x2(degrees: Float, scale_x: Float, scale_y: Float)
}

/// Options for SVG transform serialization.
pub type Options {
  Options(decimal_places: Option(Int), fixed_decimals: Bool, force_matrix: Bool)
}

/// Default transform serialization options.
///
/// Defaults to up to 5 decimal places, stripped trailing zeroes, and readable
/// transform functions when possible.
pub fn default_options() -> Options {
  Options(decimal_places: Some(5), fixed_decimals: False, force_matrix: False)
}

/// Create options that round numbers to the given number of decimal places.
///
/// Trailing zeroes are stripped. Negative decimal places are clamped to zero.
pub fn decimal_options(decimal_places: Int) -> Options {
  Options(
    decimal_places: Some(decimal_places),
    fixed_decimals: False,
    force_matrix: False,
  )
}

/// Create options that round numbers and keep exactly the given number of
/// decimal places.
///
/// Negative decimal places are clamped to zero.
pub fn fixed_decimal_options(decimal_places: Int) -> Options {
  Options(
    decimal_places: Some(decimal_places),
    fixed_decimals: True,
    force_matrix: False,
  )
}

/// Force serialization as `matrix(a b c d e f)`.
///
/// This disables the nicer `translate`, `scale`, `rotate`, and `skew`
/// representations.
pub fn force_matrix(options: Options) -> Options {
  Options(..options, force_matrix: True)
}

/// Serialize a transform matrix with default options.
pub fn to_string(transform: path_transform.Matrix) -> String {
  to_string_with(transform, default_options())
}

/// Serialize a transform matrix with custom options.
pub fn to_string_with(
  transform transform: path_transform.Matrix,
  options options: Options,
) -> String {
  let #(a, b, c, d, e, f) = path_transform.to_tuple(transform)

  case options.force_matrix {
    True -> matrix_transform(a, b, c, d, e, f, options)
    False -> {
      case analyze_linear_transform(a, b, c, d) {
        Matrix2x2 -> matrix_transform(a, b, c, d, e, f, options)
        linear -> affine_transform(linear, e, f, options)
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

fn rotate_transform(degrees: Float, options: Options) -> String {
  transform_function("rotate", number(degrees, options))
}

fn translate_optional_transform(
  x: Float,
  y: Float,
  options: Options,
) -> String {
  case x == 0.0 && y == 0.0 {
    True -> ""
    False -> translate_transform(x, y, options)
  }
}

fn affine_transform(
  linear: LinearTransform,
  translate_x: Float,
  translate_y: Float,
  options: Options,
) -> String {
  case linear_transform(linear, options) {
    "" -> translate_transform(translate_x, translate_y, options)
    transform ->
      join_transforms(
        translate_optional_transform(translate_x, translate_y, options),
        transform,
      )
  }
}

fn linear_transform(linear: LinearTransform, options: Options) -> String {
  case linear {
    Matrix2x2 -> ""
    Identity2x2 -> ""
    Scale2x2(x:, y:) -> scale_transform(x, y, options)
    SkewX2x2(tangent:) -> skew_x_transform(tangent, options)
    SkewY2x2(tangent:) -> skew_y_transform(tangent, options)
    RotateScale2x2(degrees:, scale_x:, scale_y:) ->
      join_transforms(
        rotate_transform(degrees, options),
        scale_optional_transform(scale_x, scale_y, options),
      )
  }
}

fn join_transforms(first: String, second: String) -> String {
  case first, second {
    "", _ -> second
    _, "" -> first
    _, _ -> first <> " " <> second
  }
}

fn analyze_linear_transform(
  a: Float,
  b: Float,
  c: Float,
  d: Float,
) -> LinearTransform {
  case a == 1.0 && b == 0.0 && c == 0.0 && d == 1.0 {
    True -> Identity2x2
    False -> {
      case b == 0.0 && c == 0.0 {
        True -> Scale2x2(x: a, y: d)
        False -> {
          case a == 1.0 && b == 0.0 && d == 1.0 {
            True -> SkewX2x2(tangent: c)
            False -> {
              case a == 1.0 && c == 0.0 && d == 1.0 {
                True -> SkewY2x2(tangent: b)
                False -> analyze_rotation_scale(a, b, c, d)
              }
            }
          }
        }
      }
    }
  }
}

fn analyze_rotation_scale(
  a: Float,
  b: Float,
  c: Float,
  d: Float,
) -> LinearTransform {
  let scale_x = length(a, b)
  let scale_y = length(c, d)
  let determinant = a *. d -. b *. c
  let dot_product = a *. c +. b *. d

  case
    scale_x >. rotation_scale_epsilon
    && scale_y >. rotation_scale_epsilon
    && determinant >. rotation_scale_epsilon
    && close_to_zero(dot_product)
  {
    False -> Matrix2x2
    True -> {
      let rotation_degrees = trig.atan2_degrees(b, a)

      RotateScale2x2(degrees: rotation_degrees, scale_x:, scale_y:)
    }
  }
}

fn scale_optional_transform(x: Float, y: Float, options: Options) -> String {
  case x == 1.0 && y == 1.0 {
    True -> ""
    False -> scale_transform(x, y, options)
  }
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
  trig.atan_degrees(tangent)
}

fn length(x: Float, y: Float) -> Float {
  let assert Ok(result) = float.square_root(x *. x +. y *. y)

  result
}

fn close_to_zero(value: Float) -> Bool {
  float.absolute_value(value) <=. rotation_scale_epsilon
}

fn number(number: Float, options: Options) -> String {
  let right_decimals = case options.decimal_places, options.fixed_decimals {
    None, _ -> number_format.System
    Some(decimal_places), False -> number_format.AtMost(decimal_places)
    Some(decimal_places), True -> number_format.Fixed(decimal_places)
  }
  let format =
    number_format.prepare(
      number_format.Options(
        left_decimals: number_format.Succinct,
        right_decimals:,
      ),
      [number],
    )

  number_format.number(number, with: format)
}
