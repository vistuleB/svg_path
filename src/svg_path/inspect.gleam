//// Human-readable structural inspection for path values.
////
//// This module is for debugging and tests, not for producing valid SVG path
//// data. Use `svg_path/serialize` when you need a `d` attribute string.

import gleam/list
import gleam/string
import svg_path
import svg_path/number_format

/// Options for structural inspection output.
pub type Options {
  Options(
    /// Formatting for digits to the left of the decimal point.
    left_decimals: LeftDecimalOptions,
    /// Formatting for digits to the right of the decimal point.
    right_decimals: RightDecimalOptions,
  )
}

/// Formatting for digits to the left of the decimal point.
pub type LeftDecimalOptions {
  /// Do not pad numbers on the left.
  Succinct

  /// Pre-scan the inspected value and choose the smallest shared left width
  /// that aligns its numbers.
  AutoLeftPadding

  /// Pad numbers to the given left width.
  ///
  /// The width includes a leading minus sign for negative numbers.
  LeftPadding(Int)
}

/// Formatting for digits to the right of the decimal point.
pub type RightDecimalOptions {
  /// Use the system float formatter, stripped of purely trailing decimal zeroes.
  System

  /// Use at most this many decimal places, stripping trailing zeroes.
  AtMost(Int)

  /// Use exactly this many decimal places.
  Fixed(Int)
}

/// Default inspection options.
///
/// Defaults to raw float formatting with trailing decimal zeroes stripped.
pub fn default_options() -> Options {
  Options(left_decimals: Succinct, right_decimals: System)
}

/// Create options that round numbers to the given number of decimal places.
///
/// Trailing zeroes are stripped. Negative decimal places are clamped to zero.
pub fn decimal_options(decimal_places: Int) -> Options {
  Options(left_decimals: Succinct, right_decimals: AtMost(decimal_places))
}

/// Create options that round numbers and keep exactly the given number of
/// decimal places.
///
/// Negative decimal places are clamped to zero.
pub fn fixed_decimal_options(decimal_places: Int) -> Options {
  Options(left_decimals: Succinct, right_decimals: Fixed(decimal_places))
}

/// Set left-side decimal formatting for inspection options.
pub fn with_left_decimals(
  options options: Options,
  left_decimals left_decimals: LeftDecimalOptions,
) -> Options {
  Options(..options, left_decimals:)
}

/// Set right-side decimal formatting for inspection options.
pub fn with_right_decimals(
  options options: Options,
  right_decimals right_decimals: RightDecimalOptions,
) -> Options {
  Options(..options, right_decimals:)
}

/// Set left-side number padding for inspection options.
pub fn with_left_padding(
  options options: Options,
  left_padding left_padding: LeftDecimalOptions,
) -> Options {
  with_left_decimals(options, left_padding)
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

fn do_path(path: svg_path.Path, format: number_format.NumberFormat) -> String {
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

fn do_path_code(
  path: svg_path.Path,
  format: number_format.NumberFormat,
) -> String {
  case svg_path.subpaths(path) {
    [] -> "svg_path.empty_path()"
    subpaths -> {
      "svg_path.Path([\n"
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

fn do_subpath(
  subpath: svg_path.Subpath,
  format: number_format.NumberFormat,
) -> String {
  let state = case svg_path.is_closed(subpath) {
    True -> "closed"
    False -> "open"
  }

  let assert Ok(start) = svg_path.start(subpath)
  let start = "start=" <> do_point(start, format)

  case svg_path.segments(subpath) {
    [] -> "Subpath(" <> state <> ", " <> start <> ", [])"
    segments -> {
      "Subpath("
      <> state
      <> ", "
      <> start
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

fn do_subpath_code(
  subpath: svg_path.Subpath,
  format: number_format.NumberFormat,
) -> String {
  let assert Ok(start) = svg_path.start(subpath)

  case svg_path.segments(subpath) {
    [] -> {
      let constructor =
        "svg_path.empty_subpath(at: " <> do_point_code(start, format) <> ")"

      case svg_path.is_closed(subpath) {
        False -> constructor
        True -> {
          constructor <> "\n|> svg_path.assert_set_closed(closed: True)"
        }
      }
    }
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

fn do_segment(
  segment: svg_path.Segment,
  format: number_format.NumberFormat,
) -> String {
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

fn do_segment_code(
  segment: svg_path.Segment,
  format: number_format.NumberFormat,
) -> String {
  case segment {
    svg_path.Line(start:, end:) -> {
      "svg_path.Line(start: "
      <> do_point_code(start, format)
      <> ", end: "
      <> do_point_code(end, format)
      <> ")"
    }

    svg_path.QuadraticBezier(start:, control:, end:) -> {
      "svg_path.QuadraticBezier(start: "
      <> do_point_code(start, format)
      <> ", control: "
      <> do_point_code(control, format)
      <> ", end: "
      <> do_point_code(end, format)
      <> ")"
    }

    svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      "svg_path.CubicBezier(start: "
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
      "svg_path.Arc(start: "
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

fn do_point(
  point: svg_path.Point,
  format: number_format.NumberFormat,
) -> String {
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

fn do_point_code(
  point: svg_path.Point,
  format: number_format.NumberFormat,
) -> String {
  "svg_path.point("
  <> code_number(point.x, format)
  <> ", "
  <> code_number(point.y, format)
  <> ")"
}

fn number_format(
  options: Options,
  numbers: List(Float),
) -> number_format.NumberFormat {
  number_format.prepare(number_options(options), numbers)
}

fn number_options(options: Options) -> number_format.Options {
  number_format.Options(
    left_decimals: left_decimals(options.left_decimals),
    right_decimals: right_decimals(options.right_decimals),
  )
}

fn left_decimals(
  left_decimals: LeftDecimalOptions,
) -> number_format.LeftDecimalOptions {
  case left_decimals {
    Succinct -> number_format.Succinct
    AutoLeftPadding -> number_format.AutoLeftPadding
    LeftPadding(width) -> number_format.LeftPadding(width)
  }
}

fn right_decimals(
  right_decimals: RightDecimalOptions,
) -> number_format.RightDecimalOptions {
  case right_decimals {
    System -> number_format.System
    AtMost(decimal_places) -> number_format.AtMost(decimal_places)
    Fixed(decimal_places) -> number_format.Fixed(decimal_places)
  }
}

fn path_numbers(path: svg_path.Path) -> List(Float) {
  path
  |> svg_path.subpaths
  |> list.fold([], fn(accumulated, subpath) {
    list.append(accumulated, subpath_numbers(subpath))
  })
}

fn subpath_numbers(subpath: svg_path.Subpath) -> List(Float) {
  let assert Ok(start) = svg_path.start(subpath)

  subpath
  |> svg_path.segments
  |> list.fold(point_numbers(start), fn(accumulated, segment) {
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

fn number(number: Float, format: number_format.NumberFormat) -> String {
  number_format.number(number, with: format)
}

fn code_number(value: Float, format: number_format.NumberFormat) -> String {
  number_format.code_number(value, with: format)
}
