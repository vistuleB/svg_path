import gleam/float
import gleam/list
import gleeunit
import svg_path/trig

const tolerance = 0.000001

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn sin_degrees_returns_exact_values_at_quarter_turns_test() {
  assert trig.sin_degrees(0.0) == 0.0
  assert trig.sin_degrees(90.0) == 1.0
  assert trig.sin_degrees(180.0) == 0.0
  assert trig.sin_degrees(270.0) == -1.0
  assert trig.sin_degrees(360.0) == 0.0
  assert trig.sin_degrees(-90.0) == -1.0
}

pub fn cos_degrees_returns_exact_values_at_quarter_turns_test() {
  assert trig.cos_degrees(0.0) == 1.0
  assert trig.cos_degrees(90.0) == 0.0
  assert trig.cos_degrees(180.0) == -1.0
  assert trig.cos_degrees(270.0) == 0.0
  assert trig.cos_degrees(360.0) == 1.0
  assert trig.cos_degrees(-90.0) == 0.0
}

pub fn tan_degrees_returns_exact_values_at_safe_eighth_turns_test() {
  assert trig.tan_degrees(0.0) == 0.0
  assert trig.tan_degrees(45.0) == 1.0
  assert trig.tan_degrees(135.0) == -1.0
  assert trig.tan_degrees(180.0) == 0.0
  assert trig.tan_degrees(225.0) == 1.0
  assert trig.tan_degrees(315.0) == -1.0
  assert trig.tan_degrees(-45.0) == -1.0
}

pub fn atan2_degrees_returns_exact_axis_angles_test() {
  assert trig.atan2_degrees(0.0, 1.0) == 0.0
  assert trig.atan2_degrees(1.0, 0.0) == 90.0
  assert trig.atan2_degrees(0.0, -1.0) == 180.0
  assert trig.atan2_degrees(-1.0, 0.0) == -90.0
}

pub fn atan2_degrees_returns_exact_diagonal_angles_test() {
  assert trig.atan2_degrees(1.0, 1.0) == 45.0
  assert trig.atan2_degrees(1.0, -1.0) == 135.0
  assert trig.atan2_degrees(-1.0, -1.0) == -135.0
  assert trig.atan2_degrees(-1.0, 1.0) == -45.0
}

pub fn trig_degrees_uses_math_for_other_angles_test() {
  assert near(trig.sin_degrees(30.0), 0.5)
  assert near(trig.cos_degrees(60.0), 0.5)
  assert near(trig.tan_degrees(30.0), 0.577350269)
  assert near(trig.atan_degrees(1.0), 45.0)
  assert near(trig.atan2_degrees(2.0, 1.0), 63.434948823)
  let assert Ok(acos) = trig.acos_degrees(0.5)
  assert near(acos, 60.0)
}

pub fn degree_functions_reduce_large_finite_angles_test() {
  // Remainders of the exact integers represented by these binary64 values,
  // independently computed with integer arithmetic (not decimal approximations).
  list.each(
    [
      #(1.0e20, 280.0),
      #(1.0e100, 64.0),
      #(1.0e308, 296.0),
      #(1.7976931348623157e308, 128.0),
    ],
    fn(pair) {
      let #(angle, reduced) = pair
      list.each([1.0, -1.0], fn(sign) {
        assert trig.sin_degrees(sign *. angle)
          == trig.sin_degrees(sign *. reduced)
        assert trig.cos_degrees(sign *. angle)
          == trig.cos_degrees(sign *. reduced)
        assert trig.tan_degrees(sign *. angle)
          == trig.tan_degrees(sign *. reduced)
      })
    },
  )
}

pub fn degree_functions_preserve_small_negative_angles_test() {
  let angle = 1.0e-16
  assert trig.sin_degrees(0.0 -. angle) <. 0.0
  assert trig.tan_degrees(0.0 -. angle) <. 0.0
  assert trig.sin_degrees(0.0 -. angle) == 0.0 -. trig.sin_degrees(angle)
  assert trig.tan_degrees(0.0 -. angle) == 0.0 -. trig.tan_degrees(angle)
}

pub fn degree_functions_preserve_exact_negative_turns_test() {
  assert trig.sin_degrees(-360.0) == 0.0
  assert trig.cos_degrees(-360.0) == 1.0
  assert trig.tan_degrees(-360.0) == 0.0
  assert trig.sin_degrees(-270.0) == 1.0
  assert trig.cos_degrees(-180.0) == -1.0
  assert trig.tan_degrees(-135.0) == 1.0
  assert trig.tan_degrees(-225.0) == -1.0
  assert trig.tan_degrees(-315.0) == 1.0
}

pub fn angle_conversions_avoid_intermediate_overflow_test() {
  list.each([1.0, -1.0], fn(sign) {
    let radians = trig.degrees_to_radians(sign *. 1.0e308)
    assert float.absolute_value(
        radians /. 1.0e308 -. sign *. 0.017453292519943295,
      )
      <. 1.0e-16
    let degrees = trig.radians_to_degrees(sign *. 1.0e306)
    assert float.absolute_value(degrees /. 1.0e306 -. sign *. 57.29577951308232)
      <. 1.0e-12
  })
}

pub fn acos_degrees_rejects_values_outside_its_domain_test() {
  let assert Error(Nil) = trig.acos_degrees(-1.000001)
  let assert Error(Nil) = trig.acos_degrees(1.000001)
}

fn near(a: Float, b: Float) -> Bool {
  float.absolute_value(a -. b) <=. tolerance
}
