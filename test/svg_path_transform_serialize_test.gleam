import gleam/float
import gleam/list
import gleam/option.{None}
import gleam/string
import gleeunit
import svg_path/affine
import svg_path/transform
import svg_path/transform/parse as transform_parse
import svg_path/transform/serialize

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn signed_zero_matrix_entries_do_not_add_operations_test() {
  assert serialize.to_string(
      transform.from_tuple(#(1.0, -0.0, -0.0, 1.0, -0.0, -0.0)),
    )
    == "translate(0)"
  assert serialize.to_string(
      transform.from_tuple(#(2.0, -0.0, -0.0, 2.0, -0.0, -0.0)),
    )
    == "scale(2)"
  assert serialize.to_string(transform.translate(x: 10.0, y: -0.0))
    == "translate(10)"
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

pub fn transform_serialization_preserves_small_shear_test() {
  let options = serialize.Options(None, False, False)
  list.each(
    [#(2.0, 0.000001), #(2.0, -0.000001), #(2_000_000.0, 1.0)],
    fn(pair) {
      let #(scale, shear) = pair
      let matrix = transform.from_tuple(#(scale, 0.0, shear, scale, 0.0, 0.0))
      let text = serialize.to_string_with(matrix, options:)
      assert string.contains(text, "skewX(")
      let assert Ok(decoded) = transform_parse.attribute(text)
      let #(a, b, c, d, e, f) = transform.to_tuple(decoded)
      assert a == scale && b == 0.0 && d == scale && e == 0.0 && f == 0.0
      // Parsing a decimal need not recover the identical float bit pattern.
      assert float.absolute_value(c -. shear)
        <=. float.absolute_value(shear) *. 1.0e-12
    },
  )
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
    transform.matrix(a: 2.0, b: 3.0, c: 4.0, d: 6.0, e: 11.0, f: 13.0)

  assert serialize.to_string(matrix) == "matrix(2 3 4 6 11 13)"
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

pub fn reflected_rotation_matrix_uses_signed_scale_test() {
  let assert Ok(matrix) = transform_parse.attribute("matrix(0 2 3 0 10 20)")

  assert serialize.to_string(matrix)
    == "translate(10 20) rotate(90) scale(2 -3)"
}

pub fn parsed_shear_scale_uses_decomposition_test() {
  let assert Ok(matrix) = transform_parse.attribute("skewX(30) scale(2)")

  assert serialize.to_string_with(matrix, options: serialize.decimal_options(3))
    == "skewX(30) scale(2)"
}

pub fn general_transform_uses_all_four_factors_test() {
  let assert Ok(m) =
    transform_parse.attribute(
      "translate(11 13) rotate(90) skewX(45) scale(3 5)",
    )
  assert serialize.to_string(m)
    == "translate(11 13) rotate(90) skewX(45) scale(3 5)"
}

pub fn extreme_skews_fall_back_after_angle_rounding_test() {
  list.each(
    [#(1.0, 0.0, 1.0e12, 1.0, 0.0, 0.0), #(1.0, 1.0e12, 0.0, 1.0, 0.0, 0.0)],
    fn(values) {
      let m = transform.from_tuple(values)
      assert string.starts_with(serialize.to_string(m), "matrix(")
    },
  )
  let m = transform.from_tuple(#(1.0, 0.0, 1.0e12, 1.0, 0.0, 0.0))
  assert serialize.to_string_in_order(
      m,
      order: affine.TranslationRotationShearXScale,
      options: serialize.default_options(),
    )
    == Error(serialize.InsufficientPrecision)
}

pub fn ordered_precision_can_be_increased_test() {
  let m = transform.from_tuple(#(1.0, 0.0, 1000.0, 1.0, 0.0, 0.0))
  assert serialize.to_string_in_order(
      m,
      order: affine.TranslationRotationShearXScale,
      options: serialize.decimal_options(3),
    )
    == Error(serialize.InsufficientPrecision)
  let assert Ok(text) =
    serialize.to_string_in_order(
      m,
      order: affine.TranslationRotationShearXScale,
      options: serialize.Options(None, False, False),
    )
  assert string.starts_with(text, "skewX(")
}

pub fn ordered_formatting_reports_impossible_order_test() {
  let m = transform.from_tuple(#(1.0, 1.0, 0.0, 1.0, 0.0, 0.0))
  let order = affine.TranslationScaleRotationShearX
  assert serialize.to_string_in_order(
      m,
      order:,
      options: serialize.default_options(),
    )
    == Error(
      serialize.FactorizationFailed(affine.NoFactorizationInOrder(order:)),
    )
  // Ordinary output retains the simple skewY, without any factorization.
  assert serialize.to_string(m) == "skewY(45)"
}

pub fn explicit_order_rejects_force_matrix_test() {
  assert serialize.to_string_in_order(
      transform.identity(),
      order: affine.TranslationRotationShearXScale,
      options: serialize.default_options() |> serialize.force_matrix,
    )
    == Error(serialize.ConflictingMatrixOption)
}

pub fn skew_y_can_be_explicitly_factored_with_skew_x_test() {
  let m = transform.skew_y(degrees: 45.0)
  let assert Ok(text) =
    serialize.to_string_in_order(
      m,
      order: affine.TranslationRotationShearXScale,
      options: serialize.decimal_options(10),
    )
  assert string.contains(text, "skewX(")
  assert !string.contains(text, "skewY(")
  assert string.starts_with(text, "rotate(45)")
}

pub fn translated_skew_y_retains_simple_form_test() {
  let assert Ok(m) = transform_parse.attribute("translate(7 -11) skewY(30)")
  assert serialize.to_string(m) == "translate(7 -11) skewY(30)"
}

pub fn all_orders_serialize_in_requested_sequence_and_round_trip_test() {
  let orders = [
    #(
      affine.TranslationRotationShearXScale,
      "translate(7 -11) rotate(20) skewX(10) scale(2 3)",
      ["translate", "rotate", "skewX", "scale"],
    ),
    #(
      affine.TranslationRotationScaleShearX,
      "translate(7 -11) rotate(20) scale(2 3) skewX(10)",
      ["translate", "rotate", "scale", "skewX"],
    ),
    #(
      affine.TranslationShearXRotationScale,
      "translate(7 -11) skewX(10) rotate(20) scale(2 3)",
      ["translate", "skewX", "rotate", "scale"],
    ),
    #(
      affine.TranslationShearXScaleRotation,
      "translate(7 -11) skewX(10) scale(2 3) rotate(20)",
      ["translate", "skewX", "scale", "rotate"],
    ),
    #(
      affine.TranslationScaleRotationShearX,
      "translate(7 -11) scale(2 3) rotate(20) skewX(10)",
      ["translate", "scale", "rotate", "skewX"],
    ),
    #(
      affine.TranslationScaleShearXRotation,
      "translate(7 -11) scale(2 3) skewX(10) rotate(20)",
      ["translate", "scale", "skewX", "rotate"],
    ),
    #(
      affine.RotationTranslationShearXScale,
      "rotate(20) translate(7 -11) skewX(10) scale(2 3)",
      ["rotate", "translate", "skewX", "scale"],
    ),
    #(
      affine.RotationTranslationScaleShearX,
      "rotate(20) translate(7 -11) scale(2 3) skewX(10)",
      ["rotate", "translate", "scale", "skewX"],
    ),
    #(
      affine.RotationShearXTranslationScale,
      "rotate(20) skewX(10) translate(7 -11) scale(2 3)",
      ["rotate", "skewX", "translate", "scale"],
    ),
    #(
      affine.RotationShearXScaleTranslation,
      "rotate(20) skewX(10) scale(2 3) translate(7 -11)",
      ["rotate", "skewX", "scale", "translate"],
    ),
    #(
      affine.RotationScaleTranslationShearX,
      "rotate(20) scale(2 3) translate(7 -11) skewX(10)",
      ["rotate", "scale", "translate", "skewX"],
    ),
    #(
      affine.RotationScaleShearXTranslation,
      "rotate(20) scale(2 3) skewX(10) translate(7 -11)",
      ["rotate", "scale", "skewX", "translate"],
    ),
    #(
      affine.ShearXTranslationRotationScale,
      "skewX(10) translate(7 -11) rotate(20) scale(2 3)",
      ["skewX", "translate", "rotate", "scale"],
    ),
    #(
      affine.ShearXTranslationScaleRotation,
      "skewX(10) translate(7 -11) scale(2 3) rotate(20)",
      ["skewX", "translate", "scale", "rotate"],
    ),
    #(
      affine.ShearXRotationTranslationScale,
      "skewX(10) rotate(20) translate(7 -11) scale(2 3)",
      ["skewX", "rotate", "translate", "scale"],
    ),
    #(
      affine.ShearXRotationScaleTranslation,
      "skewX(10) rotate(20) scale(2 3) translate(7 -11)",
      ["skewX", "rotate", "scale", "translate"],
    ),
    #(
      affine.ShearXScaleTranslationRotation,
      "skewX(10) scale(2 3) translate(7 -11) rotate(20)",
      ["skewX", "scale", "translate", "rotate"],
    ),
    #(
      affine.ShearXScaleRotationTranslation,
      "skewX(10) scale(2 3) rotate(20) translate(7 -11)",
      ["skewX", "scale", "rotate", "translate"],
    ),
    #(
      affine.ScaleTranslationRotationShearX,
      "scale(2 3) translate(7 -11) rotate(20) skewX(10)",
      ["scale", "translate", "rotate", "skewX"],
    ),
    #(
      affine.ScaleTranslationShearXRotation,
      "scale(2 3) translate(7 -11) skewX(10) rotate(20)",
      ["scale", "translate", "skewX", "rotate"],
    ),
    #(
      affine.ScaleRotationTranslationShearX,
      "scale(2 3) rotate(20) translate(7 -11) skewX(10)",
      ["scale", "rotate", "translate", "skewX"],
    ),
    #(
      affine.ScaleRotationShearXTranslation,
      "scale(2 3) rotate(20) skewX(10) translate(7 -11)",
      ["scale", "rotate", "skewX", "translate"],
    ),
    #(
      affine.ScaleShearXTranslationRotation,
      "scale(2 3) skewX(10) translate(7 -11) rotate(20)",
      ["scale", "skewX", "translate", "rotate"],
    ),
    #(
      affine.ScaleShearXRotationTranslation,
      "scale(2 3) skewX(10) rotate(20) translate(7 -11)",
      ["scale", "skewX", "rotate", "translate"],
    ),
  ]
  list.each(orders, fn(entry) {
    let #(order, source, sequence) = entry
    let assert Ok(m) = transform_parse.attribute(source)
    let assert Ok(text) =
      serialize.to_string_in_order(
        m,
        order:,
        options: serialize.decimal_options(10),
      )
    // Every factor is nonidentity; check names and order independently of values.
    let names =
      text
      |> string.split(")")
      |> list.filter(fn(s) { s != "" })
      |> list.map(fn(s) {
        let assert Ok(#(name, _)) = string.split_once(string.trim(s), "(")
        name
      })
    assert names == sequence
    let assert Ok(rebuilt) = transform_parse.attribute(text)
    let #(a, b, c, d, e, f) = transform.to_tuple(m)
    let #(aa, bb, cc, dd, ee, ff) = transform.to_tuple(rebuilt)
    list.each(
      [#(a, aa), #(b, bb), #(c, cc), #(d, dd), #(e, ee), #(f, ff)],
      fn(pair) {
        assert float.absolute_value(pair.0 -. pair.1) <. 1.0e-8
      },
    )
  })
}

pub fn small_shear_is_retained_when_anisotropic_scale_amplifies_it_test() {
  let m = transform.from_tuple(#(1.0e12, 0.0, 0.01, 1.0, 0.0, 0.0))
  let assert Ok(text) =
    serialize.to_string_in_order(
      m,
      order: affine.TranslationRotationScaleShearX,
      options: serialize.Options(None, False, False),
    )
  assert string.contains(text, "skewX(")
  let assert Ok(rebuilt) = transform_parse.attribute(text)
  let #(_, _, c, _, _, _) = transform.to_tuple(rebuilt)
  assert float.absolute_value(c -. 0.01) <. 1.0e-14
}
