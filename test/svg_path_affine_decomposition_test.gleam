import gleam/float
import gleam/list
import svg_path/affine

fn column_close(a: Float, b: Float, x: Float, y: Float) {
  let scale = float.max(float.absolute_value(a), float.absolute_value(b))
  case scale == 0.0 {
    True -> {
      assert x == 0.0 || x == -0.0
      assert y == 0.0 || y == -0.0
    }
    False -> {
      assert float.absolute_value(a /. scale -. x /. scale) <. 1.0e-12
      assert float.absolute_value(b /. scale -. y /. scale) <. 1.0e-12
    }
  }
}

fn round_trip(m: affine.Affine) {
  let assert Ok(factors) = affine.decompose(m)
  let rebuilt = affine.recompose(factors)
  column_close(m.a, m.b, rebuilt.a, rebuilt.b)
  column_close(m.c, m.d, rebuilt.c, rebuilt.d)
  assert rebuilt.e == m.e
  assert rebuilt.f == m.f
  factors
}

pub fn identity_has_canonical_factors_test() {
  assert affine.decompose(affine.identity())
    == Ok(affine.Decomposition(
      affine.TranslationRotationShearXScale,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      1.0,
    ))
}

pub fn standard_order_and_shear_coefficient_are_explicit_test() {
  // T(11,13) R(90) Hx(2) S(3,5), independently multiplied by hand.
  let input = affine.Affine(0.0, 3.0, -5.0, 10.0, 11.0, 13.0)
  let factors = round_trip(input)
  assert factors
    == affine.Decomposition(
      affine.TranslationRotationShearXScale,
      11.0,
      13.0,
      90.0,
      2.0,
      3.0,
      5.0,
    )
  assert affine.point(affine.recompose(factors), x: 2.0, y: 4.0)
    == #(-9.0, 59.0)
}

pub fn arbitrary_invertible_matrices_round_trip_test() {
  list.each(
    [
      affine.Affine(2.0, 3.0, 5.0, 7.0, 11.0, 13.0),
      affine.Affine(1.0, 1.0, 0.0, 1.0, -10.0, 20.0),
      affine.Affine(-3.0, 2.0, 7.0, 5.0, 0.0, 0.0),
      affine.Affine(1.0, 0.0, 1_000_000.0, 1.0, 1.0e200, -1.0e200),
    ],
    fn(m) {
      let _ = round_trip(m)
    },
  )
}

pub fn rotation_shear_scale_grid_round_trips_test() {
  list.each([-179.0, -90.0, -12.5, 0.0, 37.0, 90.0, 180.0], fn(angle) {
    list.each([-2.0, 0.0, 3.0], fn(shear) {
      list.each([-5.0, 0.25, 7.0], fn(sx) {
        list.each([-3.0, 0.5, 4.0], fn(sy) {
          // Compose using the existing matrix API, independently of recompose.
          let m =
            affine.translate(x: 17.0, y: -23.0)
            |> affine.multiply(left: _, right: affine.rotate(degrees: angle))
            |> affine.multiply(
              left: _,
              right: affine.Affine(1.0, 0.0, shear, 1.0, 0.0, 0.0),
            )
            |> affine.multiply(left: _, right: affine.scale_xy(x: sx, y: sy))
          let factors = round_trip(m)
          assert factors.scale_x >. 0.0
          assert { factors.scale_y <. 0.0 } == { sx *. sy <. 0.0 }
        })
      })
    })
  })
}

pub fn reflections_are_assigned_to_y_scale_test() {
  let factors = round_trip(affine.scale_xy(x: -2.0, y: 3.0))
  assert factors.scale_x == 2.0
  assert factors.scale_y == -3.0
  assert float.absolute_value(factors.rotation_degrees) == 180.0
}

pub fn zero_and_single_zero_columns_are_supported_test() {
  list.each(
    [
      affine.Affine(0.0, 0.0, 0.0, 0.0, 7.0, 9.0),
      affine.Affine(3.0, 4.0, 0.0, 0.0, 7.0, 9.0),
      affine.Affine(0.0, 0.0, -3.0, 4.0, 7.0, 9.0),
      affine.Affine(0.0, 0.0, 3.0, -4.0, 7.0, 9.0),
    ],
    fn(m) {
      let factors = round_trip(m)
      assert factors.shear_x == 0.0
      assert factors.scale_x >=. 0.0 && factors.scale_y >=. 0.0
    },
  )
}

pub fn rank_one_with_two_nonzero_columns_has_no_finite_rhs_factors_test() {
  list.each(
    [
      affine.Affine(1.0, 0.0, 1.0, 0.0, 0.0, 0.0),
      affine.Affine(1.0, 2.0, 3.0, 6.0, 0.0, 0.0),
    ],
    fn(m) {
      assert affine.decompose(m)
        == Error(affine.NoFactorizationInOrder(
          affine.TranslationRotationShearXScale,
        ))
    },
  )
}

pub fn determinant_overflow_and_underflow_do_not_prevent_decomposition_test() {
  list.each([1.0e-200, 1.0e200], fn(k) {
    let _ =
      round_trip(affine.Affine(
        3.0 *. k,
        4.0 *. k,
        -2.0 *. k,
        6.0 *. k,
        0.0,
        0.0,
      ))
  })
}

pub fn anisotropic_columns_keep_separate_scales_test() {
  let _ =
    round_trip(affine.Affine(3.0e-200, 4.0e-200, -2.0e200, 6.0e200, 0.0, 0.0))
  let _ =
    round_trip(affine.Affine(3.0e200, 4.0e200, -2.0e-200, 6.0e-200, 0.0, 0.0))
}

pub fn near_singular_invertible_matrix_is_not_snapped_to_singular_test() {
  let _ = round_trip(affine.Affine(1.0, 0.0, 1.0, 1.0e-14, 0.0, 0.0))
}

pub fn unrepresentable_factor_magnitude_reports_error_test() {
  assert affine.decompose(affine.Affine(1.7e308, 1.7e308, 0.0, 1.0, 0.0, 0.0))
    == Error(affine.DecompositionNonFinite)
}

pub fn signed_zero_columns_are_supported_test() {
  let factors = round_trip(affine.Affine(-0.0, 0.0, -0.0, 0.0, 2.0, 3.0))
  assert factors.scale_x == 0.0 && factors.scale_y == 0.0
}
