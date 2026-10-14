//// SVG transform attribute serializer.
////
//// This module serializes affine matrices as SVG transform attribute strings.
//// It prefers readable transform functions such as `translate`, `scale`,
//// `rotate`, and `skew`. Simple forms are recognized directly; general matrices
//// use `affine.decompose` in Translation × Rotation × ShearX × Scale order.
//// Rounded factors are checked by parsing the actual output. If decomposition
//// or the formatting check fails, ordinary serialization falls back to
//// `matrix(a b c d e f)`. Output is deterministic, not necessarily shortest,
//// and does not preserve construction history or provide animation continuity.

import gleam/float
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import svg_path/affine
import svg_path/internal/format as number_format
import svg_path/internal/number as numeric
import svg_path/transform as path_transform
import svg_path/transform/parse as transform_parse
import svg_path/trig

const identity_scale_epsilon = 0.0000000000001

type LinearTransform {
  Matrix2x2
  Identity2x2
  Scale2x2(x: Float, y: Float)
  SkewX2x2(tangent: Float)
  SkewY2x2(tangent: Float)
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
/// Uses the formatting budget documented on `to_string_in_order`. Matrix
/// fallback still rounds coefficients according to these options; neither form
/// promises exact equivalence. Pure `skewY` retains its direct representation.
pub fn to_string_with(
  transform transform: path_transform.Matrix,
  options options: Options,
) -> String {
  let #(a, b, c, d, e, f) = path_transform.to_tuple(transform)
  // Exact matrix-shape recognition must not depend on the sign of zero.
  let a = numeric.normalize_zero(a)
  let b = numeric.normalize_zero(b)
  let c = numeric.normalize_zero(c)
  let d = numeric.normalize_zero(d)
  let e = numeric.normalize_zero(e)
  let f = numeric.normalize_zero(f)

  case options.force_matrix {
    True -> matrix_transform(a, b, c, d, e, f, options)
    False -> {
      let original = affine.matrix(a:, b:, c:, d:, e:, f:)
      let candidate = case analyze_linear_transform(a, b, c, d) {
        Matrix2x2 ->
          ordered_string(
            original,
            affine.TranslationRotationShearXScale,
            options,
          )
        linear ->
          check_text(affine_transform(linear, e, f, options), original, options)
      }
      case candidate {
        Ok(text) -> text
        Error(_) -> matrix_transform(a, b, c, d, e, f, options)
      }
    }
  }
}

/// Failures from strict, ordered transform serialization.
pub type Error {
  /// An explicit order conflicts with `force_matrix: True`.
  ConflictingMatrixOption
  /// The affine solver could not produce the requested factors.
  FactorizationFailed(reason: affine.DecompositionError)
  /// Rounded SVG factors could not reconstruct the input within the documented
  /// formatting budget, or could not be parsed as finite SVG transforms.
  InsufficientPrecision
}

/// Serialize in an explicitly requested algebraic order (rightmost acts first).
/// Identity factors and verified negligible arithmetic noise may be omitted.
/// Never substitutes another order or matrix
/// notation. `force_matrix: True` is an error, not an override.
///
/// The generated text is parsed and compared with the input. For each linear
/// column and the translation vector, max-norm error must be at most
/// `max(1, input vector norm) * max(1e-12, 10^-decimal_places)`.
/// With `decimal_places: None`, the budget is `1e-12` instead. Negative decimal
/// places mean zero. This is a formatting budget, not exact equivalence or the
/// affine solver's tighter relative reconstruction guarantee.
pub fn to_string_in_order(
  transform: path_transform.Matrix,
  order order: affine.DecompositionOrder,
  options options: Options,
) -> Result(String, Error) {
  case options.force_matrix {
    True -> Error(ConflictingMatrixOption)
    False ->
      ordered_string(
        transform |> path_transform.to_tuple |> affine.from_tuple,
        order,
        options,
      )
  }
}

fn ordered_string(
  m: affine.Affine,
  order: affine.DecompositionOrder,
  options: Options,
) -> Result(String, Error) {
  use factors <- result.try(
    affine.decompose_with_order(m, order:)
    |> result.map_error(fn(reason) { FactorizationFailed(reason:) }),
  )
  case check_text(factor_string(factors, options, True), m, options) {
    Ok(text) -> Ok(text)
    Error(_) -> check_text(factor_string(factors, options, False), m, options)
  }
}

fn factor_string(
  f: affine.Decomposition,
  options: Options,
  simplify: Bool,
) -> String {
  let t =
    translate_optional_transform(f.translation_x, f.translation_y, options)
  let r = case numeric.is_zero(f.rotation_degrees) {
    True -> ""
    False -> rotate_transform(f.rotation_degrees, options)
  }
  // Omit arithmetic noise only; check_text validates the resulting expression.
  let h = case
    numeric.is_zero(f.shear_x)
    || { simplify && float.absolute_value(f.shear_x) <=. 1.0e-13 }
  {
    True -> ""
    False -> skew_x_transform(f.shear_x, options)
  }
  let s = case simplify {
    True -> scale_optional_transform(f.scale_x, f.scale_y, options)
    False ->
      case f.scale_x == 1.0 && f.scale_y == 1.0 {
        True -> ""
        False -> scale_transform(f.scale_x, f.scale_y, options)
      }
  }
  let parts = case f.order {
    affine.TranslationRotationShearXScale -> [t, r, h, s]
    affine.TranslationRotationScaleShearX -> [t, r, s, h]
    affine.TranslationShearXRotationScale -> [t, h, r, s]
    affine.TranslationShearXScaleRotation -> [t, h, s, r]
    affine.TranslationScaleRotationShearX -> [t, s, r, h]
    affine.TranslationScaleShearXRotation -> [t, s, h, r]
    affine.RotationTranslationShearXScale -> [r, t, h, s]
    affine.RotationTranslationScaleShearX -> [r, t, s, h]
    affine.RotationShearXTranslationScale -> [r, h, t, s]
    affine.RotationShearXScaleTranslation -> [r, h, s, t]
    affine.RotationScaleTranslationShearX -> [r, s, t, h]
    affine.RotationScaleShearXTranslation -> [r, s, h, t]
    affine.ShearXTranslationRotationScale -> [h, t, r, s]
    affine.ShearXTranslationScaleRotation -> [h, t, s, r]
    affine.ShearXRotationTranslationScale -> [h, r, t, s]
    affine.ShearXRotationScaleTranslation -> [h, r, s, t]
    affine.ShearXScaleTranslationRotation -> [h, s, t, r]
    affine.ShearXScaleRotationTranslation -> [h, s, r, t]
    affine.ScaleTranslationRotationShearX -> [s, t, r, h]
    affine.ScaleTranslationShearXRotation -> [s, t, h, r]
    affine.ScaleRotationTranslationShearX -> [s, r, t, h]
    affine.ScaleRotationShearXTranslation -> [s, r, h, t]
    affine.ScaleShearXTranslationRotation -> [s, h, t, r]
    affine.ScaleShearXRotationTranslation -> [s, h, r, t]
  }
  case list.fold(parts, "", join_transforms) {
    "" -> translate_transform(0.0, 0.0, options)
    text -> text
  }
}

fn check_text(
  text: String,
  original: affine.Affine,
  options: Options,
) -> Result(String, Error) {
  numeric.with_arithmetic_errors(
    fn() {
      use parsed <- result.try(
        transform_parse.attribute(text)
        |> result.map_error(fn(_) { InsufficientPrecision }),
      )
      let rebuilt = parsed |> path_transform.to_tuple |> affine.from_tuple
      let budget = case options.decimal_places {
        None -> 1.0e-12
        Some(places) -> decimal_budget(places, 1.0)
      }
      case
        affine.is_finite(original)
        && affine.is_finite(rebuilt)
        && vector_matches(original.a, original.b, rebuilt.a, rebuilt.b, budget)
        && vector_matches(original.c, original.d, rebuilt.c, rebuilt.d, budget)
        && vector_matches(original.e, original.f, rebuilt.e, rebuilt.f, budget)
      {
        True -> Ok(text)
        False -> Error(InsufficientPrecision)
      }
    },
    InsufficientPrecision,
  )
}

fn decimal_budget(places: Int, value: Float) -> Float {
  case places <= 0 || value <=. 1.0e-12 {
    True -> float.max(value, 1.0e-12)
    False -> decimal_budget(places - 1, value /. 10.0)
  }
}

fn vector_matches(
  x: Float,
  y: Float,
  u: Float,
  v: Float,
  budget: Float,
) -> Bool {
  let scale =
    float.max(1.0, float.max(float.absolute_value(x), float.absolute_value(y)))
  float.absolute_value(x /. scale -. u /. scale) <=. budget
  && float.absolute_value(y /. scale -. v /. scale) <=. budget
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
                False -> Matrix2x2
              }
            }
          }
        }
      }
    }
  }
}

fn scale_optional_transform(x: Float, y: Float, options: Options) -> String {
  case close_to_identity_scale(x) && close_to_identity_scale(y) {
    True -> ""
    False -> scale_transform(x, y, options)
  }
}

fn close_to_identity_scale(value: Float) -> Bool {
  float.absolute_value(value -. 1.0) <=. identity_scale_epsilon
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
