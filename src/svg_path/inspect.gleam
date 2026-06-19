//// Human-readable structural inspection for path values.
////
//// This module is for debugging and tests, not for producing valid SVG path
//// data. Use `svg_path/serialize` when you need a `d` attribute string.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import svg_path

/// Options for structural inspection output.
pub type Options {
  Options(
    /// Decimal places used when formatting numbers.
    decimal_places: Option(Int),
    /// Whether formatted numbers should keep trailing zeroes.
    fixed_decimals: Bool,
    /// Whether numbers should be padded on the left for visual alignment.
    left_padding: LeftPadding,
  )
}

/// Left-side number padding for structural inspection output.
pub type LeftPadding {
  /// Do not pad numbers on the left.
  NoLeftPadding

  /// Pre-scan the inspected value and choose the smallest shared left width
  /// that aligns its numbers.
  AutoLeftPadding

  /// Pad numbers to the given left width.
  ///
  /// The width includes a leading minus sign for negative numbers.
  LeftPadding(Int)
}

/// Default inspection options.
///
/// Defaults to raw float formatting with trailing decimal zeroes stripped.
pub fn default_options() -> Options {
  Options(
    decimal_places: None,
    fixed_decimals: False,
    left_padding: NoLeftPadding,
  )
}

/// Create options that round numbers to the given number of decimal places.
///
/// Trailing zeroes are stripped. Negative decimal places are clamped to zero.
pub fn decimal_options(decimal_places: Int) -> Options {
  Options(
    decimal_places: Some(decimal_places),
    fixed_decimals: False,
    left_padding: NoLeftPadding,
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
    left_padding: NoLeftPadding,
  )
}

/// Set left-side number padding for inspection options.
pub fn with_left_padding(
  options options: Options,
  left_padding left_padding: LeftPadding,
) -> Options {
  Options(..options, left_padding:)
}

/// Inspect a path as a multiline structural string.
pub fn path(path: svg_path.Path) -> String {
  path_with_options(path, default_options())
}

/// Inspect a path as a multiline structural string with custom options.
pub fn path_with_options(
  path path: svg_path.Path,
  options options: Options,
) -> String {
  let format = number_format(options, path_numbers(path))
  do_path(path, format)
}

fn do_path(path: svg_path.Path, format: NumberFormat) -> String {
  case svg_path.subpaths(path) {
    [] -> "Path([])"
    subpaths -> {
      "Path([\n"
      <> indent_lines(
        subpaths
        |> list.map(do_subpath(_, format))
        |> string.join(",\n"),
      )
      <> "\n])"
    }
  }
}

/// Inspect a path as copy-pasteable Gleam code.
///
/// The generated code assumes the `svg_path` package is imported as
/// `svg_path`.
pub fn path_code(path: svg_path.Path) -> String {
  path_code_with_options(path, default_options())
}

/// Inspect a path as copy-pasteable Gleam code with custom options.
pub fn path_code_with_options(
  path path: svg_path.Path,
  options options: Options,
) -> String {
  let format = number_format(options, path_numbers(path))
  do_path_code(path, format)
}

fn do_path_code(path: svg_path.Path, format: NumberFormat) -> String {
  case svg_path.subpaths(path) {
    [] -> "svg_path.empty_path()"
    subpaths -> {
      "svg_path.path([\n"
      <> indent_lines(
        subpaths
        |> list.map(do_subpath_code(_, format))
        |> string.join(",\n"),
      )
      <> "\n])"
    }
  }
}

/// Inspect a subpath as a multiline structural string.
pub fn subpath(subpath: svg_path.Subpath) -> String {
  subpath_with_options(subpath, default_options())
}

/// Inspect a subpath as a multiline structural string with custom options.
pub fn subpath_with_options(
  subpath subpath: svg_path.Subpath,
  options options: Options,
) -> String {
  let format = number_format(options, subpath_numbers(subpath))
  do_subpath(subpath, format)
}

fn do_subpath(subpath: svg_path.Subpath, format: NumberFormat) -> String {
  let state = case svg_path.is_closed(subpath) {
    True -> "closed"
    False -> "open"
  }

  case svg_path.segments(subpath) {
    [] -> "Subpath(" <> state <> ", [])"
    segments -> {
      "Subpath("
      <> state
      <> ", [\n"
      <> indent_lines(
        segments
        |> list.map(do_segment(_, format))
        |> string.join(",\n"),
      )
      <> "\n])"
    }
  }
}

/// Inspect a subpath as copy-pasteable Gleam code.
///
/// The generated code assumes the `svg_path` package is imported as
/// `svg_path`.
pub fn subpath_code(subpath: svg_path.Subpath) -> String {
  subpath_code_with_options(subpath, default_options())
}

/// Inspect a subpath as copy-pasteable Gleam code with custom options.
pub fn subpath_code_with_options(
  subpath subpath: svg_path.Subpath,
  options options: Options,
) -> String {
  let format = number_format(options, subpath_numbers(subpath))
  do_subpath_code(subpath, format)
}

fn do_subpath_code(subpath: svg_path.Subpath, format: NumberFormat) -> String {
  case svg_path.segments(subpath) {
    [] -> "svg_path.empty_subpath()"
    segments -> {
      let constructor =
        "svg_path.assert_subpath([\n"
        <> indent_lines(
          segments
          |> list.map(do_segment_code(_, format))
          |> string.join(",\n"),
        )
        <> "\n])"

      case svg_path.is_closed(subpath) {
        False -> constructor
        True -> {
          constructor <> "\n|> svg_path.assert_set_closed(closed: True)"
        }
      }
    }
  }
}

/// Inspect a segment as a single-line structural string.
pub fn segment(segment: svg_path.Segment) -> String {
  segment_with_options(segment, default_options())
}

/// Inspect a segment as a single-line structural string with custom options.
pub fn segment_with_options(
  segment segment: svg_path.Segment,
  options options: Options,
) -> String {
  let format = number_format(options, segment_numbers(segment))
  do_segment(segment, format)
}

fn do_segment(segment: svg_path.Segment, format: NumberFormat) -> String {
  case segment {
    svg_path.Line(start:, end:) -> {
      "Line(start="
      <> do_point(start, format)
      <> " end="
      <> do_point(end, format)
      <> ")"
    }

    svg_path.QuadraticBezier(start:, control:, end:) -> {
      "QuadraticBezier(start="
      <> do_point(start, format)
      <> " control="
      <> do_point(control, format)
      <> " end="
      <> do_point(end, format)
      <> ")"
    }

    svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      "CubicBezier(start="
      <> do_point(start, format)
      <> " control1="
      <> do_point(control1, format)
      <> " control2="
      <> do_point(control2, format)
      <> " end="
      <> do_point(end, format)
      <> ")"
    }

    svg_path.Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:) -> {
      "Arc(start="
      <> do_point(start, format)
      <> " radius="
      <> do_point(radius, format)
      <> " x_axis_rotation="
      <> number(x_axis_rotation, format)
      <> " large_arc="
      <> bool(large_arc)
      <> " sweep="
      <> bool(sweep)
      <> " end="
      <> do_point(end, format)
      <> ")"
    }
  }
}

/// Inspect a segment as copy-pasteable Gleam code.
///
/// The generated code assumes the `svg_path` package is imported as
/// `svg_path`.
pub fn segment_code(segment: svg_path.Segment) -> String {
  segment_code_with_options(segment, default_options())
}

/// Inspect a segment as copy-pasteable Gleam code with custom options.
pub fn segment_code_with_options(
  segment segment: svg_path.Segment,
  options options: Options,
) -> String {
  let format = number_format(options, segment_numbers(segment))
  do_segment_code(segment, format)
}

fn do_segment_code(segment: svg_path.Segment, format: NumberFormat) -> String {
  case segment {
    svg_path.Line(start:, end:) -> {
      "svg_path.line(start: "
      <> do_point_code(start, format)
      <> ", end: "
      <> do_point_code(end, format)
      <> ")"
    }

    svg_path.QuadraticBezier(start:, control:, end:) -> {
      "svg_path.quadratic_bezier(start: "
      <> do_point_code(start, format)
      <> ", control: "
      <> do_point_code(control, format)
      <> ", end: "
      <> do_point_code(end, format)
      <> ")"
    }

    svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      "svg_path.cubic_bezier(start: "
      <> do_point_code(start, format)
      <> ", control1: "
      <> do_point_code(control1, format)
      <> ", control2: "
      <> do_point_code(control2, format)
      <> ", end: "
      <> do_point_code(end, format)
      <> ")"
    }

    svg_path.Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:) -> {
      "svg_path.arc(start: "
      <> do_point_code(start, format)
      <> ", radius: "
      <> do_point_code(radius, format)
      <> ", x_axis_rotation: "
      <> code_number(x_axis_rotation, format)
      <> ", large_arc: "
      <> bool(large_arc)
      <> ", sweep: "
      <> bool(sweep)
      <> ", end: "
      <> do_point_code(end, format)
      <> ")"
    }
  }
}

/// Inspect a point as `x,y`.
pub fn point(point: svg_path.Point) -> String {
  point_with_options(point, default_options())
}

/// Inspect a point as `x,y` with custom options.
pub fn point_with_options(
  point point: svg_path.Point,
  options options: Options,
) -> String {
  let format = number_format(options, point_numbers(point))
  do_point(point, format)
}

fn do_point(point: svg_path.Point, format: NumberFormat) -> String {
  number(point.x, format) <> "," <> number(point.y, format)
}

/// Inspect a point as copy-pasteable Gleam code.
///
/// The generated code assumes the `svg_path` package is imported as
/// `svg_path`.
pub fn point_code(point: svg_path.Point) -> String {
  point_code_with_options(point, default_options())
}

/// Inspect a point as copy-pasteable Gleam code with custom options.
pub fn point_code_with_options(
  point point: svg_path.Point,
  options options: Options,
) -> String {
  let format = number_format(options, point_numbers(point))
  do_point_code(point, format)
}

fn do_point_code(point: svg_path.Point, format: NumberFormat) -> String {
  "svg_path.point("
  <> code_number(point.x, format)
  <> ", "
  <> code_number(point.y, format)
  <> ")"
}

type NumberFormat {
  NumberFormat(options: Options, left_padding_width: Option(Int))
}

fn number_format(options: Options, numbers: List(Float)) -> NumberFormat {
  let left_padding_width = case options.left_padding {
    NoLeftPadding -> None
    LeftPadding(width) -> Some(int.max(width, 0))
    AutoLeftPadding -> Some(auto_left_padding_width(numbers, options))
  }

  NumberFormat(options:, left_padding_width:)
}

fn auto_left_padding_width(numbers: List(Float), options: Options) -> Int {
  numbers
  |> list.map(fn(number) { number |> raw_number(options) |> left_width })
  |> list.fold(0, int.max)
}

fn path_numbers(path: svg_path.Path) -> List(Float) {
  path
  |> svg_path.subpaths
  |> list.fold([], fn(accumulated, subpath) {
    list.append(accumulated, subpath_numbers(subpath))
  })
}

fn subpath_numbers(subpath: svg_path.Subpath) -> List(Float) {
  subpath
  |> svg_path.segments
  |> list.fold([], fn(accumulated, segment) {
    list.append(accumulated, segment_numbers(segment))
  })
}

fn segment_numbers(segment: svg_path.Segment) -> List(Float) {
  case segment {
    svg_path.Line(start:, end:) ->
      list.append(point_numbers(start), point_numbers(end))
    svg_path.QuadraticBezier(start:, control:, end:) ->
      point_numbers(start)
      |> list.append(point_numbers(control))
      |> list.append(point_numbers(end))
    svg_path.CubicBezier(start:, control1:, control2:, end:) ->
      point_numbers(start)
      |> list.append(point_numbers(control1))
      |> list.append(point_numbers(control2))
      |> list.append(point_numbers(end))
    svg_path.Arc(start:, radius:, x_axis_rotation:, end:, ..) ->
      point_numbers(start)
      |> list.append(point_numbers(radius))
      |> list.append([x_axis_rotation])
      |> list.append(point_numbers(end))
  }
}

fn point_numbers(point: svg_path.Point) -> List(Float) {
  [point.x, point.y]
}

fn indent_lines(lines: String) -> String {
  lines
  |> string.split(on: "\n")
  |> list.map(fn(line) { "  " <> line })
  |> string.join("\n")
}

fn bool(value: Bool) -> String {
  case value {
    True -> "True"
    False -> "False"
  }
}

fn number(number: Float, format: NumberFormat) -> String {
  number
  |> raw_number(format.options)
  |> left_pad(format)
}

fn raw_number(number: Float, options: Options) -> String {
  case options.decimal_places {
    None -> number |> float.to_string |> strip_trailing_decimal_zeros
    Some(decimal_places) ->
      decimal(number, decimal_places, options.fixed_decimals)
  }
}

fn code_number(value: Float, format: NumberFormat) -> String {
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

fn left_pad(number: String, format: NumberFormat) -> String {
  case format.left_padding_width {
    None -> number
    Some(width) -> pad_left_side(number, width)
  }
}

fn pad_left_side(number: String, width: Int) -> String {
  let #(whole, suffix) = case string.split_once(number, on: ".") {
    Ok(#(whole, fractional)) -> #(whole, "." <> fractional)
    Error(_) -> #(number, "")
  }

  let whole = case string.starts_with(whole, "-") {
    True -> {
      "-"
      <> {
        whole
        |> string.drop_start(up_to: 1)
        |> string.pad_start(to: int.max(width - 1, 0), with: "0")
      }
    }
    False -> string.pad_start(whole, to: width, with: "0")
  }

  whole <> suffix
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
  case string.split_once(number, on: ".") {
    Error(_) -> number
    Ok(#(whole, fractional)) -> {
      let fractional = strip_trailing_zeros(fractional)

      case fractional {
        "" -> whole
        _ -> whole <> "." <> fractional
      }
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
  case exponent {
    0 -> 1
    _ -> 10 * power_of_ten_int(exponent - 1)
  }
}
