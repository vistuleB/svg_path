//// SVG path data serializer.
////
//// This module turns paths, subpaths, and segments into SVG `d` attribute
//// strings. The default output favors readable canonical forms; options can be
//// used for relative commands, smaller whitespace, and omitted repeated command
//// letters.

import gleam/list
import gleam/string
import svg_path
import svg_path/number_format

/// Options for SVG path data serialization.
pub type Options {
  Options(
    /// Formatting for digits to the left of the decimal point.
    left_decimals: LeftDecimalOptions,
    /// Formatting for digits to the right of the decimal point.
    right_decimals: RightDecimalOptions,
    /// Whether to emit relative commands instead of absolute commands.
    relative: Bool,
    /// Whether to remove optional spaces between command letters and arguments.
    minimize_whitespace: Bool,
    /// Whether to repeat command letters when SVG syntax allows them to be
    /// omitted.
    repeat_commands: Bool,
  )
}

/// Formatting for digits to the left of the decimal point.
pub type LeftDecimalOptions {
  /// Do not pad numbers on the left.
  Succinct

  /// Pre-scan the serialized value and choose the smallest shared left width
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

/// Default serialization options.
///
/// Defaults to readable absolute commands, up to 5 decimal places, repeated
/// command letters, and normal whitespace.
pub fn default_options() -> Options {
  Options(
    left_decimals: Succinct,
    right_decimals: AtMost(5),
    relative: False,
    minimize_whitespace: False,
    repeat_commands: True,
  )
}

/// Create options that round numbers to the given number of decimal places.
///
/// Trailing zeroes are stripped. Negative decimal places are clamped to zero.
pub fn decimal_options(decimal_places: Int) -> Options {
  Options(
    left_decimals: Succinct,
    right_decimals: AtMost(decimal_places),
    relative: False,
    minimize_whitespace: False,
    repeat_commands: True,
  )
}

/// Create options that round numbers and keep exactly the given number of
/// decimal places.
///
/// Negative decimal places are clamped to zero.
pub fn fixed_decimal_options(decimal_places: Int) -> Options {
  Options(
    left_decimals: Succinct,
    right_decimals: Fixed(decimal_places),
    relative: False,
    minimize_whitespace: False,
    repeat_commands: True,
  )
}

/// Create options that serialize with relative commands.
pub fn relative_options() -> Options {
  Options(
    left_decimals: Succinct,
    right_decimals: AtMost(5),
    relative: True,
    minimize_whitespace: False,
    repeat_commands: True,
  )
}

/// Create relative serialization options with decimal rounding.
pub fn relative_decimal_options(decimal_places: Int) -> Options {
  Options(
    left_decimals: Succinct,
    right_decimals: AtMost(decimal_places),
    relative: True,
    minimize_whitespace: False,
    repeat_commands: True,
  )
}

/// Create relative serialization options with fixed decimal formatting.
pub fn relative_fixed_decimal_options(decimal_places: Int) -> Options {
  Options(
    left_decimals: Succinct,
    right_decimals: Fixed(decimal_places),
    relative: True,
    minimize_whitespace: False,
    repeat_commands: True,
  )
}

/// Remove optional spaces between command letters and their arguments.
pub fn minimize_whitespace(options: Options) -> Options {
  Options(..options, minimize_whitespace: True)
}

/// Configure whether repeated command letters should be emitted.
///
/// SVG allows some commands to omit the command letter when the same command
/// repeats. Pass `False` for smaller, less verbose output.
pub fn repeat_commands(options: Options, repeat_commands: Bool) -> Options {
  Options(..options, repeat_commands:)
}

/// Set left-side decimal formatting for serialization options.
pub fn with_left_decimals(
  options options: Options,
  left_decimals left_decimals: LeftDecimalOptions,
) -> Options {
  Options(..options, left_decimals:)
}

/// Set right-side decimal formatting for serialization options.
pub fn with_right_decimals(
  options options: Options,
  right_decimals right_decimals: RightDecimalOptions,
) -> Options {
  Options(..options, right_decimals:)
}

/// Set left-side number padding for serialization options.
pub fn with_left_padding(
  options options: Options,
  left_padding left_padding: LeftDecimalOptions,
) -> Options {
  with_left_decimals(options, left_padding)
}

/// Serialize a path with default options.
pub fn path(path: svg_path.Path) -> String {
  path_with_options(path, default_options())
}

/// Serialize a path with custom options.
pub fn path_with_options(
  path path: svg_path.Path,
  options options: Options,
) -> String {
  let format = serialization_format(options, path_numbers(path, options))

  case options.relative {
    True -> relative_path(svg_path.subpaths(path), format)
    False -> {
      path
      |> svg_path.subpaths
      |> list.map(with: serialize_absolute_subpath(_, format))
      |> list.filter(keeping: fn(serialized) { serialized != "" })
      |> join_commands(format)
    }
  }
}

/// Serialize a subpath with default options.
pub fn subpath(subpath: svg_path.Subpath) -> String {
  subpath_with_options(subpath, default_options())
}

/// Serialize a subpath with custom options.
pub fn subpath_with_options(
  subpath subpath: svg_path.Subpath,
  options options: Options,
) -> String {
  let format = serialization_format(options, subpath_numbers(subpath, options))

  case options.relative {
    True -> subpath_from_current(subpath, origin(), format)
    False -> serialize_absolute_subpath(subpath, format)
  }
}

/// Serialize a segment with default options.
pub fn segment(segment: svg_path.Segment) -> String {
  segment_with_options(segment, default_options())
}

/// Serialize a segment with custom options.
pub fn segment_with_options(
  segment segment: svg_path.Segment,
  options options: Options,
) -> String {
  let format =
    serialization_format(options, segment_with_move_numbers(segment, options))
  let start = svg_path.segment_start(segment)
  case options.relative {
    True -> {
      join_commands(
        [
          command("m", point(start, format), format),
          relative_segment_without_move(segment, format),
        ],
        format,
      )
    }
    False -> {
      join_commands(
        [
          command("M", point(start, format), format),
          absolute_segment_without_move(segment, format),
        ],
        format,
      )
    }
  }
}

fn serialize_absolute_subpath(
  subpath: svg_path.Subpath,
  format: Format,
) -> String {
  case svg_path.segments(subpath) {
    [] -> ""
    [first, ..] -> {
      let start = svg_path.segment_start(first)
      let segments = serializable_segments(subpath)
      let commands = [
        command("M", point(start, format), format),
      ]
      let commands =
        list.append(
          commands,
          list.map(segments, absolute_segment_without_move(_, format)),
        )
      let commands = case svg_path.is_closed(subpath) {
        True -> list.append(commands, ["Z"])
        False -> commands
      }

      join_commands(commands, format)
    }
  }
}

fn relative_path(subpaths: List(svg_path.Subpath), format: Format) -> String {
  relative_path_loop(subpaths, origin(), [], format)
}

fn relative_path_loop(
  subpaths: List(svg_path.Subpath),
  current: svg_path.Point,
  serialized: List(String),
  format: Format,
) -> String {
  case subpaths {
    [] -> {
      serialized
      |> list.reverse
      |> list.filter(keeping: fn(subpath) { subpath != "" })
      |> join_commands(format)
    }
    [subpath, ..rest] -> {
      relative_path_loop(
        rest,
        current_after_subpath(subpath, current),
        [subpath_from_current(subpath, current, format), ..serialized],
        format,
      )
    }
  }
}

fn subpath_from_current(
  subpath: svg_path.Subpath,
  current: svg_path.Point,
  format: Format,
) -> String {
  case svg_path.segments(subpath) {
    [] -> ""
    [first, ..] -> {
      let start = svg_path.segment_start(first)
      let segments = serializable_segments(subpath)
      let commands = [
        command("m", point(delta(start, current), format), format),
      ]
      let commands =
        list.append(
          commands,
          list.map(segments, relative_segment_without_move(_, format)),
        )
      let commands = case svg_path.is_closed(subpath) {
        True -> list.append(commands, ["z"])
        False -> commands
      }

      join_commands(commands, format)
    }
  }
}

fn serializable_segments(subpath: svg_path.Subpath) -> List(svg_path.Segment) {
  let segments = svg_path.segments(subpath)

  case svg_path.is_closed(subpath) {
    False -> segments
    True -> drop_closing_line(segments)
  }
}

fn drop_closing_line(
  segments: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case segments {
    [] -> []
    [first, ..] -> {
      let start = svg_path.segment_start(first)

      segments
      |> list.reverse
      |> drop_last_if_closing_line(start)
      |> list.reverse
    }
  }
}

fn drop_last_if_closing_line(
  reversed_segments: List(svg_path.Segment),
  start: svg_path.Point,
) -> List(svg_path.Segment) {
  case reversed_segments {
    [svg_path.Line(start: line_start, end: line_end), ..rest]
      if line_end == start && line_start != line_end
    -> rest
    _ -> reversed_segments
  }
}

fn absolute_segment_without_move(
  segment: svg_path.Segment,
  format: Format,
) -> String {
  case segment {
    svg_path.Line(start:, end:) -> absolute_line(start, end, format)
    svg_path.QuadraticBezier(control:, end:, ..) -> {
      command("Q", point(control, format) <> " " <> point(end, format), format)
    }
    svg_path.CubicBezier(control1:, control2:, end:, ..) -> {
      command(
        "C",
        point(control1, format)
          <> " "
          <> point(control2, format)
          <> " "
          <> point(end, format),
        format,
      )
    }
    svg_path.Arc(radius:, x_axis_rotation:, large_arc:, sweep:, end:, ..) -> {
      command(
        "A",
        point(radius, format)
          <> " "
          <> number(x_axis_rotation, format)
          <> " "
          <> flag(large_arc)
          <> " "
          <> flag(sweep)
          <> " "
          <> point(end, format),
        format,
      )
    }
  }
}

fn relative_segment_without_move(
  segment: svg_path.Segment,
  format: Format,
) -> String {
  let start = svg_path.segment_start(segment)

  case segment {
    svg_path.Line(end:, ..) -> {
      relative_line(start, end, format)
    }
    svg_path.QuadraticBezier(control:, end:, ..) -> {
      command(
        "q",
        point(delta(control, start), format)
          <> " "
          <> point(delta(end, start), format),
        format,
      )
    }
    svg_path.CubicBezier(control1:, control2:, end:, ..) -> {
      command(
        "c",
        point(delta(control1, start), format)
          <> " "
          <> point(delta(control2, start), format)
          <> " "
          <> point(delta(end, start), format),
        format,
      )
    }
    svg_path.Arc(radius:, x_axis_rotation:, large_arc:, sweep:, end:, ..) -> {
      command(
        "a",
        point(radius, format)
          <> " "
          <> number(x_axis_rotation, format)
          <> " "
          <> flag(large_arc)
          <> " "
          <> flag(sweep)
          <> " "
          <> point(delta(end, start), format),
        format,
      )
    }
  }
}

fn absolute_line(
  start: svg_path.Point,
  end: svg_path.Point,
  format: Format,
) -> String {
  let start_x = number(start.x, format)
  let start_y = number(start.y, format)
  let end_x = number(end.x, format)
  let end_y = number(end.y, format)

  case start_y == end_y {
    True -> command("H", end_x, format)
    False -> {
      case start_x == end_x {
        True -> command("V", end_y, format)
        False -> command("L", end_x <> " " <> end_y, format)
      }
    }
  }
}

fn relative_line(
  start: svg_path.Point,
  end: svg_path.Point,
  format: Format,
) -> String {
  let difference = delta(end, start)
  let dx = number(difference.x, format)
  let dy = number(difference.y, format)
  let zero = number(0.0, format)

  case dy == zero {
    True -> command("h", dx, format)
    False -> {
      case dx == zero {
        True -> command("v", dy, format)
        False -> command("l", dx <> " " <> dy, format)
      }
    }
  }
}

fn current_after_subpath(
  subpath: svg_path.Subpath,
  current: svg_path.Point,
) -> svg_path.Point {
  case svg_path.segments(subpath) {
    [] -> current
    [first, ..] -> {
      case svg_path.is_closed(subpath) {
        True -> svg_path.segment_start(first)
        False -> {
          case svg_path.end(subpath) {
            Ok(end) -> end
            Error(_) -> current
          }
        }
      }
    }
  }
}

fn origin() -> svg_path.Point {
  svg_path.point(0.0, 0.0)
}

fn delta(point: svg_path.Point, from origin: svg_path.Point) -> svg_path.Point {
  svg_path.point(point.x -. origin.x, point.y -. origin.y)
}

fn point(point: svg_path.Point, format: Format) -> String {
  number(point.x, format) <> " " <> number(point.y, format)
}

fn command(command: String, arguments: String, format: Format) -> String {
  command <> command_argument_separator(format.options) <> arguments
}

fn command_argument_separator(options: Options) -> String {
  case options.minimize_whitespace {
    True -> ""
    False -> " "
  }
}

fn join_commands(commands: List(String), format: Format) -> String {
  case format.options.repeat_commands {
    True -> string.join(commands, command_separator(format.options))
    False -> {
      commands
      |> compact_repeated_commands(previous: "", format:)
      |> string.join(command_separator(format.options))
    }
  }
}

fn compact_repeated_commands(
  commands: List(String),
  previous previous: String,
  format format: Format,
) -> List(String) {
  case commands {
    [] -> []
    [command, ..rest] -> {
      let current = command_name(command)
      let compacted = case current == previous && can_repeat_command(current) {
        True -> compacted_command_arguments(command, format.options)
        False -> command
      }

      [compacted, ..compact_repeated_commands(rest, previous: current, format:)]
    }
  }
}

fn command_name(command: String) -> String {
  case string.to_graphemes(command) {
    [name, ..] -> name
    [] -> ""
  }
}

fn command_arguments(command: String) -> String {
  command
  |> string.drop_start(up_to: 1)
  |> string.trim_start
}

fn compacted_command_arguments(command: String, options: Options) -> String {
  let arguments = command_arguments(command)

  case options.minimize_whitespace {
    True -> " " <> arguments
    False -> arguments
  }
}

fn can_repeat_command(command: String) -> Bool {
  list.contains(
    ["L", "l", "H", "h", "V", "v", "Q", "q", "C", "c", "A", "a"],
    command,
  )
}

fn command_separator(options: Options) -> String {
  case options.minimize_whitespace {
    True -> ""
    False -> " "
  }
}

fn path_numbers(path: svg_path.Path, options: Options) -> List(Float) {
  case options.relative {
    True ->
      relative_path_numbers(svg_path.subpaths(path), origin(), [], options)
    False -> {
      path
      |> svg_path.subpaths
      |> list.fold([], fn(accumulated, subpath) {
        list.append(accumulated, absolute_subpath_numbers(subpath, options))
      })
    }
  }
}

fn relative_path_numbers(
  subpaths: List(svg_path.Subpath),
  current: svg_path.Point,
  accumulated: List(Float),
  options: Options,
) -> List(Float) {
  case subpaths {
    [] -> accumulated
    [subpath, ..rest] -> {
      relative_path_numbers(
        rest,
        current_after_subpath(subpath, current),
        list.append(
          accumulated,
          relative_subpath_numbers(subpath, current, options),
        ),
        options,
      )
    }
  }
}

fn subpath_numbers(subpath: svg_path.Subpath, options: Options) -> List(Float) {
  case options.relative {
    True -> relative_subpath_numbers(subpath, origin(), options)
    False -> absolute_subpath_numbers(subpath, options)
  }
}

fn absolute_subpath_numbers(
  subpath: svg_path.Subpath,
  options: Options,
) -> List(Float) {
  case svg_path.segments(subpath) {
    [] -> []
    [first, ..] -> {
      let start = svg_path.segment_start(first)

      serializable_segments(subpath)
      |> list.fold(point_numbers(start), fn(accumulated, segment) {
        list.append(accumulated, absolute_segment_numbers(segment, options))
      })
    }
  }
}

fn relative_subpath_numbers(
  subpath: svg_path.Subpath,
  current: svg_path.Point,
  options: Options,
) -> List(Float) {
  case svg_path.segments(subpath) {
    [] -> []
    [first, ..] -> {
      let start = svg_path.segment_start(first)

      serializable_segments(subpath)
      |> list.fold(
        point_numbers(delta(start, current)),
        fn(accumulated, segment) {
          list.append(accumulated, relative_segment_numbers(segment, options))
        },
      )
    }
  }
}

fn segment_with_move_numbers(
  segment: svg_path.Segment,
  options: Options,
) -> List(Float) {
  let start = svg_path.segment_start(segment)

  case options.relative {
    True ->
      list.append(
        point_numbers(start),
        relative_segment_numbers(segment, options),
      )
    False ->
      list.append(
        point_numbers(start),
        absolute_segment_numbers(segment, options),
      )
  }
}

fn absolute_segment_numbers(
  segment: svg_path.Segment,
  options: Options,
) -> List(Float) {
  case segment {
    svg_path.Line(start:, end:) -> absolute_line_numbers(start, end, options)
    svg_path.QuadraticBezier(control:, end:, ..) ->
      point_numbers(control) |> list.append(point_numbers(end))
    svg_path.CubicBezier(control1:, control2:, end:, ..) ->
      point_numbers(control1)
      |> list.append(point_numbers(control2))
      |> list.append(point_numbers(end))
    svg_path.Arc(radius:, x_axis_rotation:, end:, ..) ->
      point_numbers(radius)
      |> list.append([x_axis_rotation])
      |> list.append(point_numbers(end))
  }
}

fn relative_segment_numbers(
  segment: svg_path.Segment,
  options: Options,
) -> List(Float) {
  let start = svg_path.segment_start(segment)

  case segment {
    svg_path.Line(end:, ..) -> relative_line_numbers(start, end, options)
    svg_path.QuadraticBezier(control:, end:, ..) ->
      point_numbers(delta(control, start))
      |> list.append(point_numbers(delta(end, start)))
    svg_path.CubicBezier(control1:, control2:, end:, ..) ->
      point_numbers(delta(control1, start))
      |> list.append(point_numbers(delta(control2, start)))
      |> list.append(point_numbers(delta(end, start)))
    svg_path.Arc(radius:, x_axis_rotation:, end:, ..) ->
      point_numbers(radius)
      |> list.append([x_axis_rotation])
      |> list.append(point_numbers(delta(end, start)))
  }
}

fn absolute_line_numbers(
  start: svg_path.Point,
  end: svg_path.Point,
  options: Options,
) -> List(Float) {
  let start_x = raw_number(start.x, options)
  let start_y = raw_number(start.y, options)
  let end_x = raw_number(end.x, options)
  let end_y = raw_number(end.y, options)

  case start_y == end_y {
    True -> [end.x]
    False -> {
      case start_x == end_x {
        True -> [end.y]
        False -> point_numbers(end)
      }
    }
  }
}

fn relative_line_numbers(
  start: svg_path.Point,
  end: svg_path.Point,
  options: Options,
) -> List(Float) {
  let difference = delta(end, start)
  let dx = raw_number(difference.x, options)
  let dy = raw_number(difference.y, options)
  let zero = raw_number(0.0, options)

  case dy == zero {
    True -> [difference.x]
    False -> {
      case dx == zero {
        True -> [difference.y]
        False -> point_numbers(difference)
      }
    }
  }
}

fn point_numbers(point: svg_path.Point) -> List(Float) {
  [point.x, point.y]
}

type Format {
  Format(options: Options, number_format: number_format.NumberFormat)
}

fn serialization_format(options: Options, numbers: List(Float)) -> Format {
  Format(
    options:,
    number_format: number_format.prepare(number_options(options), numbers),
  )
}

fn number(number: Float, format: Format) -> String {
  number_format.number(number, with: format.number_format)
}

fn raw_number(number: Float, options: Options) -> String {
  number_format.raw_number(number, number_options(options))
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

fn flag(flag: Bool) -> String {
  case flag {
    True -> "1"
    False -> "0"
  }
}
