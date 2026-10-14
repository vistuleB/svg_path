import gleam/float
import gleam/list
import svg_path/affine

type Factor {
  T
  R
  H
  S
}

fn orders() {
  [
    #(affine.TranslationRotationShearXScale, [T, R, H, S]),
    #(affine.TranslationRotationScaleShearX, [T, R, S, H]),
    #(affine.TranslationShearXRotationScale, [T, H, R, S]),
    #(affine.TranslationShearXScaleRotation, [T, H, S, R]),
    #(affine.TranslationScaleRotationShearX, [T, S, R, H]),
    #(affine.TranslationScaleShearXRotation, [T, S, H, R]),
    #(affine.RotationTranslationShearXScale, [R, T, H, S]),
    #(affine.RotationTranslationScaleShearX, [R, T, S, H]),
    #(affine.RotationShearXTranslationScale, [R, H, T, S]),
    #(affine.RotationShearXScaleTranslation, [R, H, S, T]),
    #(affine.RotationScaleTranslationShearX, [R, S, T, H]),
    #(affine.RotationScaleShearXTranslation, [R, S, H, T]),
    #(affine.ShearXTranslationRotationScale, [H, T, R, S]),
    #(affine.ShearXTranslationScaleRotation, [H, T, S, R]),
    #(affine.ShearXRotationTranslationScale, [H, R, T, S]),
    #(affine.ShearXRotationScaleTranslation, [H, R, S, T]),
    #(affine.ShearXScaleTranslationRotation, [H, S, T, R]),
    #(affine.ShearXScaleRotationTranslation, [H, S, R, T]),
    #(affine.ScaleTranslationRotationShearX, [S, T, R, H]),
    #(affine.ScaleTranslationShearXRotation, [S, T, H, R]),
    #(affine.ScaleRotationTranslationShearX, [S, R, T, H]),
    #(affine.ScaleRotationShearXTranslation, [S, R, H, T]),
    #(affine.ScaleShearXTranslationRotation, [S, H, T, R]),
    #(affine.ScaleShearXRotationTranslation, [S, H, R, T]),
  ]
}

// Use ordinary public matrix multiplication, independent of recompose's formulas.
fn compose(
  sequence: List(Factor),
  angle: Float,
  h: Float,
  sx: Float,
  sy: Float,
) {
  list.fold(sequence, affine.identity(), fn(m, factor) {
    let next = case factor {
      T -> affine.translate(x: 7.0, y: -11.0)
      R -> affine.rotate(degrees: angle)
      H -> affine.Affine(1.0, 0.0, h, 1.0, 0.0, 0.0)
      S -> affine.scale_xy(x: sx, y: sy)
    }
    affine.multiply(left: m, right: next)
  })
}

fn column_close(a: Float, b: Float, x: Float, y: Float) {
  let scale = float.max(float.absolute_value(a), float.absolute_value(b))
  case scale >. 0.0 {
    True -> {
      assert float.absolute_value(a /. scale -. x /. scale) <=. 1.0e-12
      assert float.absolute_value(b /. scale -. y /. scale) <=. 1.0e-12
    }
    False -> {
      assert x == 0.0 || x == -0.0
      assert y == 0.0 || y == -0.0
    }
  }
}

fn assert_round_trip(m: affine.Affine, order: affine.DecompositionOrder) {
  let result = affine.decompose_with_order(m, order: order)
  let assert Ok(f) = result
  assert f.order == order
  let rebuilt = affine.recompose(f)
  column_close(m.a, m.b, rebuilt.a, rebuilt.b)
  column_close(m.c, m.d, rebuilt.c, rebuilt.d)
  column_close(m.e, m.f, rebuilt.e, rebuilt.f)
  f
}

pub fn all_orders_preserve_their_order_and_identity_test() {
  list.each(orders(), fn(pair) {
    let f = assert_round_trip(affine.identity(), pair.0)
    assert f.shear_x == 0.0
    assert f.rotation_degrees == 0.0
  })
}

pub fn all_orders_recover_independently_composed_matrices_test() {
  list.each(orders(), fn(pair) {
    list.each(
      [-170.0, -90.0, -45.0, -12.5, 0.0, 30.0, 45.0, 90.0, 150.0, 180.0],
      fn(angle) {
        list.each([-2.0, 0.0, 1.5], fn(h) {
          list.each(
            [#(2.0, 3.0), #(-2.0, 3.0), #(2.0, -3.0), #(-2.0, -3.0)],
            fn(scales) {
              let m = compose(pair.1, angle, h, scales.0, scales.1)
              let _ = assert_round_trip(m, pair.0)
              Nil
            },
          )
        })
      },
    )
  })
}

pub fn all_orders_recover_representable_singular_maps_test() {
  list.each(orders(), fn(pair) {
    list.each([0.0, 30.0, 90.0], fn(angle) {
      list.each([-2.0, 0.0, 1.5], fn(h) {
        list.each([#(0.0, 0.0), #(0.0, 3.0), #(2.0, 0.0)], fn(scales) {
          let m = compose(pair.1, angle, h, scales.0, scales.1)
          let _ = assert_round_trip(m, pair.0)
          Nil
        })
      })
    })
  })
}

fn translation_before_scale(sequence: List(Factor)) -> Bool {
  case sequence {
    [T, ..] -> True
    [S, ..] -> False
    [_, ..rest] -> translation_before_scale(rest)
    [] -> panic
  }
}

pub fn singular_translation_compatibility_depends_on_position_test() {
  let m = affine.Affine(1.0, 0.0, 0.0, 0.0, 0.0, 1.0)
  list.each(orders(), fn(pair) {
    case translation_before_scale(pair.1) {
      True -> {
        let _ = assert_round_trip(m, pair.0)
        Nil
      }
      False -> {
        assert affine.decompose_with_order(m, order: pair.0)
          == Error(affine.NoFactorizationInOrder(pair.0))
      }
    }
  })
}

pub fn restricted_orders_reject_invertible_counterexample_test() {
  let m = affine.Affine(1.0, 1.0, 0.0, 1.0, 2.0, 3.0)
  list.each(orders(), fn(pair) {
    let linear = list.filter(pair.1, fn(f) { f != T })
    case linear == [S, R, H] || linear == [H, R, S] {
      True -> {
        assert affine.decompose_with_order(m, order: pair.0)
          == Error(affine.NoFactorizationInOrder(pair.0))
      }
      False -> {
        let _ = assert_round_trip(m, pair.0)
        Nil
      }
    }
  })
}

pub fn singular_map_can_be_available_in_one_order_but_not_another_test() {
  let m = affine.Affine(1.0, 0.0, 2.0, 0.0, 0.0, 0.0)
  assert affine.decompose(m)
    == Error(affine.NoFactorizationInOrder(
      affine.TranslationRotationShearXScale,
    ))
  let f = assert_round_trip(m, affine.TranslationRotationScaleShearX)
  assert f.shear_x == 2.0
  assert f.scale_x == 1.0
  assert f.scale_y == 0.0
}

pub fn standard_wrapper_agrees_with_explicit_order_test() {
  let m = affine.Affine(2.0, 3.0, 5.0, 7.0, 11.0, 13.0)
  assert affine.decompose(m)
    == affine.decompose_with_order(
      m,
      order: affine.TranslationRotationShearXScale,
    )
}

pub fn all_orders_handle_large_and_small_common_scales_test() {
  list.each(orders(), fn(pair) {
    list.each([1.0e-150, 1.0e150], fn(k) {
      let m = compose(pair.1, 30.0, 0.5, 2.0 *. k, 3.0 *. k)
      let _ = assert_round_trip(m, pair.0)
      Nil
    })
  })
}

pub fn quadratic_branch_selection_is_deterministic_test() {
  let m = compose([T, S, R, H], 30.0, 1.0, 2.0, 3.0)
  let f = assert_round_trip(m, affine.TranslationScaleRotationShearX)
  assert float.absolute_value(f.rotation_degrees -. 30.0) <. 1.0e-10
  assert affine.decompose_with_order(m, order: f.order) == Ok(f)
}

pub fn zero_translation_remains_zero_in_every_order_test() {
  list.each(orders(), fn(pair) {
    let m = compose(pair.1, 30.0, 0.5, 2.0, -3.0)
    let f = assert_round_trip(affine.Affine(..m, e: 0.0, f: 0.0), pair.0)
    assert f.translation_x == 0.0 || f.translation_x == -0.0
    assert f.translation_y == 0.0 || f.translation_y == -0.0
  })
}

pub fn near_half_turn_does_not_divide_scale_by_small_sine_test() {
  let m =
    affine.Affine(
      -0.3651838632260481,
      0.000010556228948517661,
      -1.0865702276357765,
      -2.25492845028511,
      2.556287042610347,
      -24.8045584525913,
    )
  let _ = assert_round_trip(m, affine.ScaleTranslationRotationShearX)
  let dual = affine.Affine(m.d, m.b, m.c, m.a, m.e, m.f)
  let _ = assert_round_trip(dual, affine.TranslationShearXRotationScale)
}

pub fn normalization_underflow_is_numerical_not_impossible_test() {
  let cases = [
    #(
      affine.Affine(1.0e-300, 1.0e-300, 1.0e300, 2.0e300, 0.0, 0.0),
      affine.TranslationScaleRotationShearX,
    ),
    #(
      affine.Affine(1.0e300, 0.0, 1.0e300, 1.0e-300, 0.0, 0.0),
      affine.TranslationRotationShearXScale,
    ),
    // Reversed dual orders must classify the same numerical loss.
    #(
      affine.Affine(2.0e300, 1.0e-300, 1.0e300, 1.0e-300, 0.0, 0.0),
      affine.TranslationShearXRotationScale,
    ),
    #(
      affine.Affine(1.0e-300, 0.0, 1.0e300, 1.0e300, 0.0, 0.0),
      affine.TranslationScaleShearXRotation,
    ),
  ]
  list.each(cases, fn(entry) {
    assert affine.decompose_with_order(entry.0, order: entry.1)
      == Error(affine.DecompositionUnstable)
  })
}

pub fn quadratic_boundary_is_backward_error_not_exact_solvability_test() {
  list.each([1.0e-300, 1.0e-150, 1.0, 1.0e150, 1.0e300], fn(top) {
    list.each([1.0e-300, 1.0e-150, 1.0, 1.0e150, 1.0e300], fn(bottom) {
      list.each(
        [-1.0e-10, -1.0e-13, -1.0e-14, 0.0, 1.0e-14, 1.0e-13, 1.0e-10],
        fn(delta) {
          let m =
            affine.Affine(
              top,
              bottom,
              0.0,
              bottom *. { 2.0 +. delta },
              0.0,
              0.0,
            )
          let dual = affine.Affine(m.d, m.b, m.c, m.a, 0.0, 0.0)
          list.each(
            [
              #(m, affine.TranslationScaleRotationShearX),
              #(dual, affine.TranslationShearXRotationScale),
            ],
            fn(entry) {
              case delta <. -1.0e-14 {
                True -> {
                  assert affine.decompose_with_order(entry.0, order: entry.1)
                    == Error(affine.NoFactorizationInOrder(order: entry.1))
                }
                False -> {
                  case affine.decompose_with_order(entry.0, order: entry.1) {
                    Ok(_) -> {
                      let _ = assert_round_trip(entry.0, entry.1)
                      Nil
                    }
                    Error(error) -> {
                      // At strongly unequal row scales, cancellation can fail
                      // reconstruction. It must remain a numerical failure.
                      assert top != bottom
                      assert error == affine.DecompositionUnstable
                    }
                  }
                }
              }
            },
          )
        },
      )
    })
  })
}

pub fn near_double_root_factors_are_sensitive_test() {
  let order = affine.TranslationScaleRotationShearX
  let m = affine.Affine(1.0, 1.0, 0.0, 2.0, 0.0, 0.0)
  let perturbed = affine.Affine(..m, d: 2.0 +. 1.0e-10)
  let assert Ok(first) = affine.decompose_with_order(m, order:)
  let assert Ok(second) = affine.decompose_with_order(perturbed, order:)
  assert_round_trip(m, order)
  assert_round_trip(perturbed, order)
  // 1e-10 in the matrix moves the canonical angle by roughly 0.000286 degrees.
  assert float.absolute_value(first.rotation_degrees -. second.rotation_degrees)
    >. 0.0002
  assert float.absolute_value(first.rotation_degrees -. second.rotation_degrees)
    <. 0.0004
}

pub fn extreme_quadratic_range_fails_numerically_test() {
  // The products forming the quadratic coefficients lose precision/underflow.
  // The reconstruction check must reject rather than return inaccurate factors.
  list.each([1.0e-160, 1.0e-170, 1.0e-200, 1.0e-300], fn(value) {
    let m = affine.Affine(value, value, 1.0, 2.0, 0.0, 0.0)
    assert affine.decompose_with_order(
        m,
        order: affine.TranslationScaleRotationShearX,
      )
      == Error(affine.DecompositionUnstable)
  })
}
