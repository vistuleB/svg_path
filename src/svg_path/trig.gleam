//// Trigonometry helpers for SVG-facing degree angles.

import gleam/float
import gleam/result
import gleam_community/maths

const pi = 3.141592653589793

const half_turn_degrees = 180.0

const full_turn_degrees = 360.0

/// Convert degrees to radians.
pub fn degrees_to_radians(degrees: Float) -> Float {
  degrees *. pi /. half_turn_degrees
}

/// Convert radians to degrees.
pub fn radians_to_degrees(radians: Float) -> Float {
  radians *. half_turn_degrees /. pi
}

/// Return the sine of an angle in degrees.
pub fn sin_degrees(degrees: Float) -> Float {
  case normalized_quarter_turn(degrees) {
    0.0 -> 0.0
    90.0 -> 1.0
    180.0 -> 0.0
    270.0 -> -1.0
    _ -> maths.sin(degrees_to_radians(degrees))
  }
}

/// Return the cosine of an angle in degrees.
pub fn cos_degrees(degrees: Float) -> Float {
  case normalized_quarter_turn(degrees) {
    0.0 -> 1.0
    90.0 -> 0.0
    180.0 -> -1.0
    270.0 -> 0.0
    _ -> maths.cos(degrees_to_radians(degrees))
  }
}

/// Return the tangent of an angle in degrees.
pub fn tan_degrees(degrees: Float) -> Float {
  case normalized_eighth_turn(degrees) {
    0.0 -> 0.0
    45.0 -> 1.0
    135.0 -> -1.0
    180.0 -> 0.0
    225.0 -> 1.0
    315.0 -> -1.0
    _ -> maths.tan(degrees_to_radians(degrees))
  }
}

/// Return `atan(x)` in degrees.
pub fn atan_degrees(x: Float) -> Float {
  radians_to_degrees(maths.atan(x))
}

/// Return `atan2(y, x)` in degrees.
pub fn atan2_degrees(y: Float, x: Float) -> Float {
  case x, y {
    0.0, 0.0 -> radians_to_degrees(maths.atan2(y, x))
    0.0, _ -> {
      case y >. 0.0 {
        True -> 90.0
        False -> -90.0
      }
    }
    _, 0.0 -> {
      case x >. 0.0 {
        True -> 0.0
        False -> 180.0
      }
    }
    _, _ -> {
      case float.absolute_value(x) == float.absolute_value(y) {
        True -> diagonal_atan2(y, x)
        False -> radians_to_degrees(maths.atan2(y, x))
      }
    }
  }
}

/// Return `acos(x)` in degrees.
pub fn acos_degrees(x: Float) -> Result(Float, Nil) {
  maths.acos(x) |> result.map(radians_to_degrees)
}

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

fn normalized_quarter_turn(degrees: Float) -> Float {
  let normalized = positive_remainder(degrees, full_turn_degrees)

  case normalized {
    0.0 | 90.0 | 180.0 | 270.0 -> normalized
    _ -> degrees
  }
}

fn normalized_eighth_turn(degrees: Float) -> Float {
  let normalized = positive_remainder(degrees, full_turn_degrees)

  case normalized {
    0.0 | 45.0 | 90.0 | 135.0 | 180.0 | 225.0 | 270.0 | 315.0 -> normalized
    _ -> degrees
  }
}

fn positive_remainder(value: Float, modulus: Float) -> Float {
  case value <. 0.0 {
    True -> positive_remainder(value +. modulus, modulus)
    False -> {
      case value >=. modulus {
        True -> positive_remainder(value -. modulus, modulus)
        False -> value
      }
    }
  }
}
