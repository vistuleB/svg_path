//// Shared numeric formatting helpers.
////
//// This module keeps decimal rounding, fixed decimal formatting, and
//// left-padding behavior consistent across structural inspection and SVG path
//// serialization. Higher-level modules still decide which numbers should be
//// included in the lookahead list for automatic padding.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// Character used for left padding.
@internal
pub type LeftPaddingStyle {
  /// Pad with zeroes.
  Zero

  /// Pad with spaces.
  Space
}

/// Formatting for digits to the left of the decimal point.
@internal
pub type LeftDecimalOptions {
  /// Do not pad numbers on the left.
  Succinct

  /// Pre-scan the formatted value and choose the smallest shared left width
  /// that aligns its numbers.
  AutoLeftPadding(LeftPaddingStyle)

  /// Pad numbers to the given left width.
  ///
  /// The width includes a leading minus sign for negative numbers.
  LeftPadding(Int, LeftPaddingStyle)
}

/// Formatting for digits to the right of the decimal point.
@internal
pub type RightDecimalOptions {
  /// Use the system float formatter, stripped of purely trailing decimal zeroes.
  System

  /// Use at most this many decimal places, stripping trailing zeroes.
  AtMost(Int)

  /// Use exactly this many decimal places.
  Fixed(Int)
}

/// Options for numeric formatting.
@internal
pub type Options {
  Options(
    /// Formatting for digits to the left of the decimal point.
    left_decimals: LeftDecimalOptions,
    /// Formatting for digits to the right of the decimal point.
    right_decimals: RightDecimalOptions,
  )
}

/// A prepared numeric formatter.
@internal
pub opaque type NumberFormat {
  NumberFormat(options: Options, left_padding: Option(#(Int, LeftPaddingStyle)))
}

/// Prepare a formatter, using the supplied numbers to choose automatic padding.
@internal
pub fn prepare(options: Options, numbers: List(Float)) -> NumberFormat {
  let left_padding = case options.left_decimals {
    Succinct -> None
    LeftPadding(width, style) -> Some(#(int.max(width, 0), style))
    AutoLeftPadding(style) ->
      Some(#(auto_left_padding_width(numbers, options), style))
  }

  NumberFormat(options:, left_padding:)
}

/// Prepare a formatter from numbers that have already received right-decimal
/// formatting but no left-padding.
@internal
pub fn prepare_raw(options: Options, numbers: List(String)) -> NumberFormat {
  let left_padding = case options.left_decimals {
    Succinct -> None
    LeftPadding(width, style) -> Some(#(int.max(width, 0), style))
    AutoLeftPadding(style) ->
      Some(#(raw_auto_left_padding_width(numbers), style))
  }

  NumberFormat(options:, left_padding:)
}

/// Format a number.
@internal
pub fn number(number: Float, with format: NumberFormat) -> String {
  number
  |> raw_number(format.options)
  |> left_pad(format)
}

/// Format a number for copy-pasteable Gleam code.
///
/// Whole numbers are given an explicit `.0` suffix before left-padding is
/// applied.
@internal
pub fn code_number(value: Float, with format: NumberFormat) -> String {
  let number = raw_number(value, format.options)
  let number = case
    string.contains(number, ".")
    || string.contains(number, "e")
    || string.contains(number, "E")
  {
    True -> number
    False -> number <> ".0"
  }

  left_pad(number, format)
}

/// Format a number without applying left-padding.
///
/// This is useful when deciding which compact SVG command form a number would
/// use before padding is added.
@internal
pub fn raw_number(number: Float, options: Options) -> String {
  case options.right_decimals {
    System -> number |> float.to_string |> strip_trailing_decimal_zeros
    AtMost(decimal_places) -> decimal(number, decimal_places, False)
    Fixed(decimal_places) -> decimal(number, decimal_places, True)
  }
}

fn auto_left_padding_width(numbers: List(Float), options: Options) -> Int {
  numbers
  |> list.map(fn(number) { number |> raw_number(options) |> left_width })
  |> list.fold(0, int.max)
}

fn raw_auto_left_padding_width(numbers: List(String)) -> Int {
  numbers |> list.map(left_width) |> list.fold(0, int.max)
}

fn left_pad(number: String, format: NumberFormat) -> String {
  case format.left_padding {
    None -> number
    Some(#(width, style)) -> pad_left_side(number, width, style)
  }
}

fn pad_left_side(
  number: String,
  width: Int,
  style: LeftPaddingStyle,
) -> String {
  let #(whole, suffix) = case string.split_once(number, on: ".") {
    Ok(#(whole, fractional)) -> #(whole, "." <> fractional)
    Error(_) -> #(number, "")
  }

  let whole = case style {
    Space -> string.pad_start(whole, to: width, with: " ")
    Zero -> zero_pad_whole(whole, width)
  }

  whole <> suffix
}

fn zero_pad_whole(whole: String, width: Int) -> String {
  case string.starts_with(whole, "-") {
    True -> {
      let digits = string.drop_start(whole, 1)
      "-" <> string.pad_start(digits, to: int.max(width - 1, 0), with: "0")
    }
    False -> string.pad_start(whole, to: width, with: "0")
  }
}

fn left_width(number: String) -> Int {
  case string.split_once(number, on: ".") {
    Ok(#(whole, _)) -> string.length(whole)
    Error(_) -> string.length(number)
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
  let #(significand, exponent) = split_exponent(number)

  case string.split_once(significand, on: ".") {
    Error(_) -> number
    Ok(#(whole, fractional)) -> {
      let fractional = strip_trailing_zeros(fractional)

      case fractional {
        "" -> whole <> exponent
        _ -> whole <> "." <> fractional <> exponent
      }
    }
  }
}

fn split_exponent(number: String) -> #(String, String) {
  case string.split_once(number, on: "e") {
    Ok(#(significand, exponent)) -> #(significand, "e" <> exponent)
    Error(_) ->
      case string.split_once(number, on: "E") {
        Ok(#(significand, exponent)) -> #(significand, "E" <> exponent)
        Error(_) -> #(number, "")
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
  int.to_float(power_of_ten_int(exponent))
}

fn power_of_ten_int(exponent: Int) -> Int {
  case exponent <= 0 {
    True -> 1
    False -> 10 * power_of_ten_int(exponent - 1)
  }
}
