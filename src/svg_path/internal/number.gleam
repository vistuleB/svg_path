import gleam/float
import gleam/int
import gleam/result
import gleam/string

/// Test mathematical zero, accepting both signs without a tolerance.
/// Erlang exact equality distinguishes `0.0` from `-0.0`.
@internal
pub fn is_zero(value: Float) -> Bool {
  value == 0.0 || value == -0.0
}

/// Canonicalize either signed zero to `0.0`, leaving other values unchanged.
/// Useful before exact equality checks, such as deduplication on Erlang.
@internal
pub fn normalize_zero(value: Float) -> Float {
  case is_zero(value) {
    True -> 0.0
    False -> value
  }
}

/// Return `sqrt(x² + y²)` without overflowing when the result is representable.
@internal
pub fn hypot(x: Float, y: Float) -> Float {
  let x = float.absolute_value(x)
  let y = float.absolute_value(y)
  let largest = case x >=. y {
    True -> x
    False -> y
  }

  case is_zero(largest) || !is_finite(largest) {
    True -> largest
    False -> {
      let scaled_x = x /. largest
      let scaled_y = y /. largest
      let assert Ok(scaled_length) =
        float.square_root(scaled_x *. scaled_x +. scaled_y *. scaled_y)
      largest *. scaled_length
    }
  }
}

@internal
pub fn parse(raw: String) -> Result(Float, Nil) {
  case string.split_once(raw, on: "e") {
    Ok(#(mantissa, exponent)) -> parse_exponent(mantissa, exponent)
    Error(_) ->
      case string.split_once(raw, on: "E") {
        Ok(#(mantissa, exponent)) -> parse_exponent(mantissa, exponent)
        Error(_) -> parse_decimal(raw)
      }
  }
}

fn parse_decimal(raw: String) -> Result(Float, Nil) {
  let raw = normalize_decimal(raw)

  case float.parse(raw) {
    Ok(number) -> finite_number(number)
    // Erlang's float parser requires a decimal point. Parsing integer syntax
    // as a float directly avoids converting an arbitrarily large bigint.
    Error(_) -> {
      use number <- result.try(float.parse(raw <> ".0"))
      finite_number(number)
    }
  }
}

fn normalize_decimal(raw: String) -> String {
  case string.starts_with(raw, ".") {
    True -> "0" <> raw
    False ->
      case string.starts_with(raw, "+.") {
        True -> "0" <> string.drop_start(raw, up_to: 1)
        False ->
          case string.starts_with(raw, "-.") {
            True -> "-0" <> string.drop_start(raw, up_to: 1)
            False -> strip_leading_plus(raw)
          }
      }
  }
}

fn parse_exponent(mantissa: String, exponent: String) -> Result(Float, Nil) {
  use mantissa <- result.try(parse_decimal(mantissa))
  use exponent <- result.try(exponent |> strip_leading_plus |> int.parse)
  scale_by_power_of_ten(mantissa, exponent)
}

fn strip_leading_plus(raw: String) -> String {
  case string.starts_with(raw, "+") {
    True -> string.drop_start(raw, up_to: 1)
    False -> raw
  }
}

fn scale_by_power_of_ten(value: Float, exponent: Int) -> Result(Float, Nil) {
  case exponent == 0 || is_zero(value) {
    True -> Ok(value)
    False if exponent > 0 -> {
      let step = int.min(exponent, 100)
      use scaled <- result.try(checked_product(
        value,
        nonnegative_integer_power(10.0, step, 1.0),
      ))
      scale_by_power_of_ten(scaled, exponent - step)
    }
    False -> {
      let step = int.max(exponent, -100)
      let factor_exponent = 0 - step
      let scaled = value *. nonnegative_integer_power(0.1, factor_exponent, 1.0)
      scale_by_power_of_ten(scaled, exponent - step)
    }
  }
}

fn nonnegative_integer_power(
  base: Float,
  exponent: Int,
  result: Float,
) -> Float {
  case exponent {
    0 -> result
    _ if exponent % 2 == 0 ->
      nonnegative_integer_power(base *. base, exponent / 2, result)
    _ -> nonnegative_integer_power(base, exponent - 1, result *. base)
  }
}

/// Multiply two floats, rejecting arithmetic errors and non-finite results.
@internal
pub fn checked_product(first: Float, second: Float) -> Result(Float, Nil) {
  with_arithmetic_errors(fn() { finite_number(first *. second) }, Nil)
}

/// Add two finite floats, rejecting a result outside the finite Float range.
@internal
pub fn checked_sum(first: Float, second: Float) -> Result(Float, Nil) {
  with_arithmetic_errors(fn() { finite_number(first +. second) }, Nil)
}

// Overflow thresholds obtained by division or subtraction can round upward,
// admitting an overflowing operation at equality. Check the actual result on
// JavaScript; Erlang raises instead, so convert only its arithmetic errors.
// Keep the operation inside the callback, not in arguments evaluated before it.
@external(erlang, "number_ffi", "with_arithmetic_errors")
@internal
pub fn with_arithmetic_errors(
  compute: fn() -> Result(a, error),
  _overflow: error,
) -> Result(a, error) {
  compute()
}

fn finite_number(number: Float) -> Result(Float, Nil) {
  case is_finite(number) {
    True -> Ok(number)
    False -> Error(Nil)
  }
}

@internal
pub fn is_finite(value: Float) -> Bool {
  !is_nan(value -. value)
}

fn is_nan(value: Float) -> Bool {
  !{ value <. 0.0 || value >=. 0.0 }
}
