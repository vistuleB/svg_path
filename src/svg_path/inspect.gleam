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
  )
}

/// Default inspection options.
///
/// Defaults to raw float formatting with trailing decimal zeroes stripped.
pub fn default_options() -> Options {
  Options(decimal_places: None, fixed_decimals: False)
}

/// Create options that round numbers to the given number of decimal places.
///
/// Trailing zeroes are stripped. Negative decimal places are clamped to zero.
pub fn decimal_options(decimal_places: Int) -> Options {
  Options(decimal_places: Some(decimal_places), fixed_decimals: False)
}

/// Create options that round numbers and keep exactly the given number of
/// decimal places.
///
/// Negative decimal places are clamped to zero.
pub fn fixed_decimal_options(decimal_places: Int) -> Options {
  Options(decimal_places: Some(decimal_places), fixed_decimals: True)
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
  case svg_path.subpaths(path) {
    [] -> "Path([])"
    subpaths -> {
      "Path([\n"
      <> indent_lines(
        subpaths
        |> list.map(subpath_with_options(_, options:))
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
        |> list.map(segment_with_options(_, options:))
        |> string.join(",\n"),
      )
      <> "\n])"
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
  case segment {
    svg_path.Line(start:, end:) -> {
      "Line(start="
      <> point_with_options(start, options:)
      <> " end="
      <> point_with_options(end, options:)
      <> ")"
    }

    svg_path.QuadraticBezier(start:, control:, end:) -> {
      "QuadraticBezier(start="
      <> point_with_options(start, options:)
      <> " control="
      <> point_with_options(control, options:)
      <> " end="
      <> point_with_options(end, options:)
      <> ")"
    }

    svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      "CubicBezier(start="
      <> point_with_options(start, options:)
      <> " control1="
      <> point_with_options(control1, options:)
      <> " control2="
      <> point_with_options(control2, options:)
      <> " end="
      <> point_with_options(end, options:)
      <> ")"
    }

    svg_path.Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:) -> {
      "Arc(start="
      <> point_with_options(start, options:)
      <> " radius="
      <> point_with_options(radius, options:)
      <> " x_axis_rotation="
      <> number(x_axis_rotation, options)
      <> " large_arc="
      <> bool(large_arc)
      <> " sweep="
      <> bool(sweep)
      <> " end="
      <> point_with_options(end, options:)
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
  number(point.x, options) <> "," <> number(point.y, options)
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

fn number(number: Float, options: Options) -> String {
  case options.decimal_places {
    None -> number |> float.to_string |> strip_trailing_decimal_zeros
    Some(decimal_places) ->
      decimal(number, decimal_places, options.fixed_decimals)
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
