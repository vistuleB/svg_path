//// Trigonometry helpers for SVG-facing degree angles.

import gleam/float
import svg_path/internal/number

const pi = 3.141592653589793

const half_turn_degrees = 180.0

const full_turn_degrees = 360.0

/// Convert degrees to radians.
pub fn degrees_to_radians(degrees: Float) -> Float {
  // Form the conversion factor first; degrees * pi can overflow unnecessarily.
  degrees *. { pi /. half_turn_degrees }
}

/// Convert radians to degrees.
pub fn radians_to_degrees(radians: Float) -> Float {
  // The final result may fit even when radians * 180 does not.
  radians *. { half_turn_degrees /. pi }
}

/// Return the sine of an angle in degrees.
///
/// Finite angles are reduced modulo 360 before conversion to radians.
/// Non-finite inputs propagate through the platform trigonometric function
/// instead of causing angle normalization to panic.
pub fn sin_degrees(degrees: Float) -> Float {
  case reduced_degrees(degrees) {
    0.0 -> 0.0
    90.0 | -270.0 -> 1.0
    180.0 | -180.0 -> 0.0
    270.0 | -90.0 -> -1.0
    reduced -> sin_radians(degrees_to_radians(reduced))
  }
}

/// Return the cosine of an angle in degrees.
///
/// Finite angles are reduced modulo 360 before conversion to radians.
/// Non-finite inputs propagate through the platform trigonometric function
/// instead of causing angle normalization to panic.
pub fn cos_degrees(degrees: Float) -> Float {
  case reduced_degrees(degrees) {
    0.0 -> 1.0
    90.0 | -90.0 -> 0.0
    180.0 | -180.0 -> -1.0
    270.0 | -270.0 -> 0.0
    reduced -> cos_radians(degrees_to_radians(reduced))
  }
}

/// Return the tangent of an angle in degrees.
///
/// Finite angles are reduced modulo 360 before conversion to radians.
/// Non-finite inputs propagate through the platform trigonometric function
/// instead of causing angle normalization to panic.
pub fn tan_degrees(degrees: Float) -> Float {
  case reduced_degrees(degrees) {
    0.0 -> 0.0
    45.0 | -315.0 -> 1.0
    135.0 | -225.0 -> -1.0
    180.0 | -180.0 -> 0.0
    225.0 | -135.0 -> 1.0
    315.0 | -45.0 -> -1.0
    reduced -> tan_radians(degrees_to_radians(reduced))
  }
}

/// Return `atan(x)` in degrees.
pub fn atan_degrees(x: Float) -> Float {
  radians_to_degrees(atan_radians(x))
}

/// Return `atan2(y, x)` in degrees.
pub fn atan2_degrees(y: Float, x: Float) -> Float {
  case number.is_zero(x), number.is_zero(y) {
    True, True -> radians_to_degrees(atan2_radians(y, x))
    True, False -> {
      case y >. 0.0 {
        True -> 90.0
        False -> -90.0
      }
    }
    False, True -> {
      case x >. 0.0 {
        True -> 0.0
        False -> 180.0
      }
    }
    False, False -> {
      case float.absolute_value(x) == float.absolute_value(y) {
        True -> diagonal_atan2(y, x)
        False -> radians_to_degrees(atan2_radians(y, x))
      }
    }
  }
}

/// Return `acos(x)` in degrees.
pub fn acos_degrees(x: Float) -> Result(Float, Nil) {
  case x >=. -1.0 && x <=. 1.0 {
    True -> Ok(acos_radians(x) |> radians_to_degrees)
    False -> Error(Nil)
  }
}

@external(erlang, "math", "sin")
@external(javascript, "./trig_ffi.mjs", "sin")
fn sin_radians(radians: Float) -> Float

@external(erlang, "math", "cos")
@external(javascript, "./trig_ffi.mjs", "cos")
fn cos_radians(radians: Float) -> Float

@external(erlang, "math", "tan")
@external(javascript, "./trig_ffi.mjs", "tan")
fn tan_radians(radians: Float) -> Float

@external(erlang, "math", "atan")
@external(javascript, "./trig_ffi.mjs", "atan")
fn atan_radians(value: Float) -> Float

@external(erlang, "math", "atan2")
@external(javascript, "./trig_ffi.mjs", "atan2")
fn atan2_radians(y: Float, x: Float) -> Float

@external(erlang, "math", "acos")
@external(javascript, "./trig_ffi.mjs", "acos")
fn acos_radians(value: Float) -> Float

fn diagonal_atan2(y: Float, x: Float) -> Float {
  case x >. 0.0 {
    True -> {
      case y >. 0.0 {
        True -> 45.0
        False -> -45.0
      }
    }
    False -> {
      case y >. 0.0 {
        True -> 135.0
        False -> -135.0
      }
    }
  }
}

fn reduced_degrees(degrees: Float) -> Float {
  case number.is_finite(degrees) {
    False -> degrees
    True -> {
      // Computing value - floor(value / 360) * 360 loses the remainder for
      // large angles. Reduce before conversion to radians, using fmod instead.
      // Keep negative remainders: adding 360 can erase a small negative angle.
      let reduced = signed_remainder(degrees, full_turn_degrees)
      case number.is_zero(reduced) {
        True -> 0.0
        False -> reduced
      }
    }
  }
}

@external(erlang, "math", "fmod")
@external(javascript, "./trig_ffi.mjs", "remainder")
fn signed_remainder(value: Float, modulus: Float) -> Float
