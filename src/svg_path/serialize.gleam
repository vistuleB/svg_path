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
    /// Whether to use commas inside coordinate pairs.
    commas: Bool,
    /// Whether to repeat command letters when SVG syntax allows them to be
    /// omitted.
    repeat_commands: Bool,
    /// Whether horizontal and vertical line segments should use `H`/`V` or
    /// `h`/`v` commands.
    use_h_v: Bool,
    /// Whether smooth cubic and quadratic curves should use `S`/`T` or `s`/`t`
    /// commands when their omitted control point matches after formatting.
    use_s_t: Bool,
    /// Where to insert newlines in the serialized path data.
    newlines: Newlines,
  )
}

/// Newline placement for serialized path data.
pub type Newlines {
  /// Keep serialized path data on one line.
  OneLine

  /// Put each subpath on its own line.
  AtSubpaths

  /// Put each segment on its own line.
  AtSegments
}

/// Character used for left padding.
pub type LeftPaddingStyle {
  /// Pad with zeroes.
  Zero

  /// Pad with spaces.
  Space
}

/// Formatting for digits to the left of the decimal point.
pub type LeftDecimalOptions {
  /// Do not pad numbers on the left.
  Succinct

  /// Pre-scan the serialized value and choose the smallest shared left width
  /// that aligns its numbers.
  AutoLeftPadding(LeftPaddingStyle)

  /// Pad numbers to the given left width.
  ///
  /// The width includes a leading minus sign for negative numbers.
  LeftPadding(Int, LeftPaddingStyle)
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
    commas: False,
    repeat_commands: True,
    use_h_v: True,
    use_s_t: True,
    newlines: OneLine,
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
    commas: False,
    repeat_commands: True,
    use_h_v: True,
    use_s_t: True,
    newlines: OneLine,
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
    commas: False,
    repeat_commands: True,
    use_h_v: True,
    use_s_t: True,
    newlines: OneLine,
  )
}

/// Create options that serialize with relative commands.
pub fn relative_options() -> Options {
  Options(
    left_decimals: Succinct,
    right_decimals: AtMost(5),
    relative: True,
    minimize_whitespace: False,
    commas: False,
    repeat_commands: True,
    use_h_v: True,
    use_s_t: True,
    newlines: OneLine,
  )
}

/// Create relative serialization options with decimal rounding.
pub fn relative_decimal_options(decimal_places: Int) -> Options {
  Options(
    left_decimals: Succinct,
    right_decimals: AtMost(decimal_places),
    relative: True,
    minimize_whitespace: False,
    commas: False,
    repeat_commands: True,
    use_h_v: True,
    use_s_t: True,
    newlines: OneLine,
  )
}

/// Create options for minifying serialized SVG path data.
///
/// This uses relative commands, rounds numbers to at most `decimal_places`
/// decimal places, removes optional command whitespace, keeps the path on one
/// line, and omits repeated command letters where SVG syntax allows it.
///
/// This is a deterministic small-output preset, not a full shortest-path-data
/// optimizer. It does not compare absolute and relative commands per segment.
/// Negative decimal places are clamped to zero.
pub fn minifying_options(decimal_places: Int) -> Options {
  relative_decimal_options(decimal_places)
  |> minimize_whitespace
  |> repeat_commands(False)
}

/// Create relative serialization options with fixed decimal formatting.
pub fn relative_fixed_decimal_options(decimal_places: Int) -> Options {
  Options(
    left_decimals: Succinct,
    right_decimals: Fixed(decimal_places),
    relative: True,
    minimize_whitespace: False,
    commas: False,
    repeat_commands: True,
    use_h_v: True,
    use_s_t: True,
    newlines: OneLine,
  )
}

type PreviousCurve {
  NoPreviousCurve
  PreviousCubic(control2: svg_path.Point)
  PreviousQuadratic(control: svg_path.Point)
}

/// Remove optional spaces between command letters and their arguments.
pub fn minimize_whitespace(options: Options) -> Options {
  Options(..options, minimize_whitespace: True)
}

/// Configure whether coordinate pairs should use a comma between `x` and `y`.
pub fn with_commas(options: Options, commas: Bool) -> Options {
  Options(..options, commas:)
}

/// Configure whether repeated command letters should be emitted.
///
/// SVG allows some commands to omit the command letter when the same command
/// repeats. Pass `False` for smaller, less verbose output.
pub fn repeat_commands(options: Options, repeat_commands: Bool) -> Options {
  Options(..options, repeat_commands:)
}

/// Configure whether horizontal and vertical lines should use `H`/`V` or
/// `h`/`v` commands.
pub fn use_h_v(options options: Options, use_h_v use_h_v: Bool) -> Options {
  Options(..options, use_h_v:)
}

/// Configure whether smooth curves should use `S`/`T` or `s`/`t` commands
/// when their omitted control point matches after formatting.
pub fn use_s_t(options options: Options, use_s_t use_s_t: Bool) -> Options {
  Options(..options, use_s_t:)
}

/// Configure where newlines should be inserted in serialized path data.
pub fn with_newlines(
  options options: Options,
  newlines newlines: Newlines,
) -> Options {
  Options(..options, newlines:)
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
///
/// Empty paths serialize to the empty string. Empty subpaths serialize as
/// move-only subpaths. Closed subpaths end in `Z`.
pub fn path(path: svg_path.Path) -> String {
  path_with_options(path, default_options())
}

/// Serialize a path with custom options.
///
/// With relative options, closed subpaths end in `z`.
pub fn path_with_options(
  path path: svg_path.Path,
  options options: Options,
) -> String {
  let format = serialization_format(options, path_numbers(path, options))

  case options.relative {
    True -> relative_path(svg_path.path_subpaths(path), format)
    False -> {
      path
      |> svg_path.path_subpaths
      |> list.map(with: serialize_absolute_subpath(_, format))
      |> list.filter(keeping: fn(serialized) { serialized != "" })
      |> join_commands(format)
    }
  }
}

/// Serialize a subpath with default options.
///
/// Empty subpaths serialize as move-only subpaths. Closed subpaths end in `Z`.
pub fn subpath(subpath: svg_path.Subpath) -> String {
  subpath_with_options(subpath, default_options())
}

/// Serialize a subpath with custom options.
///
/// With relative options, closed subpaths end in `z`.
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
          relative_single_segment_without_move(segment, format),
        ],
        format,
      )
    }
    False -> {
      join_commands(
        [
          command("M", point(start, format), format),
          absolute_single_segment_without_move(segment, format),
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
  let assert Ok(start) = svg_path.subpath_start(subpath)

  case svg_path.subpath_segments(subpath) {
    [] -> {
      let commands = [command("M", point(start, format), format)]
      let commands = case svg_path.subpath_is_closed(subpath) {
        True -> list.append(commands, ["Z"])
        False -> commands
      }

      join_commands(commands, format)
    }
    [_, ..] -> {
      let segments = serializable_segments(subpath)
      let commands = [
        command("M", point(start, format), format),
      ]
      let commands = list.append(commands, absolute_segments(segments, format))
      let commands = case svg_path.subpath_is_closed(subpath) {
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
  let assert Ok(start) = svg_path.subpath_start(subpath)

  case svg_path.subpath_segments(subpath) {
    [] -> {
      let commands = [
        command("m", point(delta(start, current), format), format),
      ]
      let commands = case svg_path.subpath_is_closed(subpath) {
        True -> list.append(commands, ["z"])
        False -> commands
      }

      join_commands(commands, format)
    }
    [_, ..] -> {
      let segments = serializable_segments(subpath)
      let commands = [
        command("m", point(delta(start, current), format), format),
      ]
      let commands = list.append(commands, relative_segments(segments, format))
      let commands = case svg_path.subpath_is_closed(subpath) {
        True -> list.append(commands, ["z"])
        False -> commands
      }

      join_commands(commands, format)
    }
  }
}

fn serializable_segments(subpath: svg_path.Subpath) -> List(svg_path.Segment) {
  let segments = svg_path.subpath_segments(subpath)

  case svg_path.subpath_is_closed(subpath) {
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

fn absolute_single_segment_without_move(
  segment: svg_path.Segment,
  format: Format,
) -> String {
  let #(serialized, _) =
    absolute_segment_without_move(segment, NoPreviousCurve, format)

  serialized
}

fn relative_single_segment_without_move(
  segment: svg_path.Segment,
  format: Format,
) -> String {
  let #(serialized, _) =
    relative_segment_without_move(segment, NoPreviousCurve, format)

  serialized
}

fn absolute_segments(
  segments: List(svg_path.Segment),
  format: Format,
) -> List(String) {
  absolute_segments_loop(segments, NoPreviousCurve, [], format)
}

fn absolute_segments_loop(
  segments: List(svg_path.Segment),
  previous: PreviousCurve,
  serialized: List(String),
  format: Format,
) -> List(String) {
  case segments {
    [] -> list.reverse(serialized)
    [segment, ..rest] -> {
      let #(command, previous) =
        absolute_segment_without_move(segment, previous, format)

      absolute_segments_loop(rest, previous, [command, ..serialized], format)
    }
  }
}

fn relative_segments(
  segments: List(svg_path.Segment),
  format: Format,
) -> List(String) {
  relative_segments_loop(segments, NoPreviousCurve, [], format)
}

fn relative_segments_loop(
  segments: List(svg_path.Segment),
  previous: PreviousCurve,
  serialized: List(String),
  format: Format,
) -> List(String) {
  case segments {
    [] -> list.reverse(serialized)
    [segment, ..rest] -> {
      let #(command, previous) =
        relative_segment_without_move(segment, previous, format)

      relative_segments_loop(rest, previous, [command, ..serialized], format)
    }
  }
}

fn absolute_segment_without_move(
  segment: svg_path.Segment,
  previous: PreviousCurve,
  format: Format,
) -> #(String, PreviousCurve) {
  case segment {
    svg_path.Line(start:, end:) -> #(
      absolute_line(start, end, format),
      NoPreviousCurve,
    )
    svg_path.QuadraticBezier(start:, control:, end:) -> {
      #(
        absolute_quadratic(start, control, end, previous, format),
        PreviousQuadratic(control),
      )
    }
    svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      #(
        absolute_cubic(start, control1, control2, end, previous, format),
        PreviousCubic(control2),
      )
    }
    svg_path.Arc(radius:, x_axis_rotation:, large_arc:, sweep:, end:, ..) -> {
      #(
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
        ),
        NoPreviousCurve,
      )
    }
  }
}

fn relative_segment_without_move(
  segment: svg_path.Segment,
  previous: PreviousCurve,
  format: Format,
) -> #(String, PreviousCurve) {
  let start = svg_path.segment_start(segment)

  case segment {
    svg_path.Line(end:, ..) -> {
      #(relative_line(start, end, format), NoPreviousCurve)
    }
    svg_path.QuadraticBezier(control:, end:, ..) -> {
      #(
        relative_quadratic(start, control, end, previous, format),
        PreviousQuadratic(control),
      )
    }
    svg_path.CubicBezier(control1:, control2:, end:, ..) -> {
      #(
        relative_cubic(start, control1, control2, end, previous, format),
        PreviousCubic(control2),
      )
    }
    svg_path.Arc(radius:, x_axis_rotation:, large_arc:, sweep:, end:, ..) -> {
      #(
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
        ),
        NoPreviousCurve,
      )
    }
  }
}

fn absolute_quadratic(
  start: svg_path.Point,
  control: svg_path.Point,
  end: svg_path.Point,
  previous: PreviousCurve,
  format: Format,
) -> String {
  case
    format.options.use_s_t
    && formatted_points_equal(
      control,
      reflected_quadratic_control(start, previous),
      format,
    )
  {
    True -> command("T", point(end, format), format)
    False ->
      command("Q", point(control, format) <> " " <> point(end, format), format)
  }
}

fn relative_quadratic(
  start: svg_path.Point,
  control: svg_path.Point,
  end: svg_path.Point,
  previous: PreviousCurve,
  format: Format,
) -> String {
  case
    format.options.use_s_t
    && formatted_points_equal(
      control,
      reflected_quadratic_control(start, previous),
      format,
    )
  {
    True -> command("t", point(delta(end, start), format), format)
    False ->
      command(
        "q",
        point(delta(control, start), format)
          <> " "
          <> point(delta(end, start), format),
        format,
      )
  }
}

fn absolute_cubic(
  start: svg_path.Point,
  control1: svg_path.Point,
  control2: svg_path.Point,
  end: svg_path.Point,
  previous: PreviousCurve,
  format: Format,
) -> String {
  case
    format.options.use_s_t
    && formatted_points_equal(
      control1,
      reflected_cubic_control(start, previous),
      format,
    )
  {
    True ->
      command("S", point(control2, format) <> " " <> point(end, format), format)
    False ->
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
}

fn relative_cubic(
  start: svg_path.Point,
  control1: svg_path.Point,
  control2: svg_path.Point,
  end: svg_path.Point,
  previous: PreviousCurve,
  format: Format,
) -> String {
  case
    format.options.use_s_t
    && formatted_points_equal(
      control1,
      reflected_cubic_control(start, previous),
      format,
    )
  {
    True ->
      command(
        "s",
        point(delta(control2, start), format)
          <> " "
          <> point(delta(end, start), format),
        format,
      )
    False ->
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
}

fn reflected_quadratic_control(
  start: svg_path.Point,
  previous: PreviousCurve,
) -> svg_path.Point {
  case previous {
    PreviousQuadratic(control) -> reflect(control, across: start)
    _ -> start
  }
}

fn reflected_cubic_control(
  start: svg_path.Point,
  previous: PreviousCurve,
) -> svg_path.Point {
  case previous {
    PreviousCubic(control2) -> reflect(control2, across: start)
    _ -> start
  }
}

fn reflect(
  point point: svg_path.Point,
  across center: svg_path.Point,
) -> svg_path.Point {
  svg_path.point(2.0 *. center.x -. point.x, 2.0 *. center.y -. point.y)
}

fn formatted_points_equal(
  a: svg_path.Point,
  b: svg_path.Point,
  format: Format,
) -> Bool {
  point(a, format) == point(b, format)
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

  case format.options.use_h_v && start_y == end_y {
    True -> command("H", end_x, format)
    False -> {
      case format.options.use_h_v && start_x == end_x {
        True -> command("V", end_y, format)
        False ->
          command(
            "L",
            end_x <> coordinate_separator(format.options) <> end_y,
            format,
          )
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

  case format.options.use_h_v && dy == zero {
    True -> command("h", dx, format)
    False -> {
      case format.options.use_h_v && dx == zero {
        True -> command("v", dy, format)
        False ->
          command("l", dx <> coordinate_separator(format.options) <> dy, format)
      }
    }
  }
}

fn current_after_subpath(
  subpath: svg_path.Subpath,
  current: svg_path.Point,
) -> svg_path.Point {
  case svg_path.subpath_segments(subpath) {
    [] -> {
      let assert Ok(start) = svg_path.subpath_start(subpath)
      start
    }
    [first, ..] -> {
      case svg_path.subpath_is_closed(subpath) {
        True -> svg_path.segment_start(first)
        False -> {
          case svg_path.subpath_end(subpath) {
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
  number(point.x, format)
  <> coordinate_separator(format.options)
  <> number(point.y, format)
}

fn command(command: String, arguments: String, format: Format) -> String {
  command <> command_argument_separator(format.options) <> arguments
}

fn coordinate_separator(options: Options) -> String {
  case options.commas {
    True -> ","
    False -> " "
  }
}

fn command_argument_separator(options: Options) -> String {
  case options.minimize_whitespace {
    True -> ""
    False -> " "
  }
}

fn join_commands(commands: List(String), format: Format) -> String {
  case format.options.newlines {
    OneLine -> join_one_line(commands, format)
    AtSubpaths -> join_subpath_lines(commands, format)
    AtSegments -> join_segment_lines(commands, format)
  }
}

fn join_one_line(commands: List(String), format: Format) -> String {
  case format.options.repeat_commands {
    True -> string.join(commands, command_separator(format.options))
    False ->
      commands
      |> compact_repeated_commands(previous: "", format:)
      |> string.join(command_separator(format.options))
  }
}

fn join_subpath_lines(commands: List(String), format: Format) -> String {
  let commands = case format.options.repeat_commands {
    True -> commands
    False -> compact_repeated_commands(commands, previous: "", format:)
  }

  join_with_subpath_separators(commands, previous: "", format:)
}

fn join_with_subpath_separators(
  commands: List(String),
  previous previous: String,
  format format: Format,
) -> String {
  case commands {
    [] -> ""
    [command] -> previous <> command
    [command, next, ..rest] -> {
      let separator = case is_move_command(command_name(next)) {
        True -> "\n"
        False -> command_separator(format.options)
      }

      join_with_subpath_separators(
        [next, ..rest],
        previous: previous <> command <> separator,
        format:,
      )
    }
  }
}

fn join_segment_lines(commands: List(String), format: Format) -> String {
  case format.options.repeat_commands {
    True -> string.join(commands, "\n")
    False ->
      commands
      |> compact_repeated_commands(previous: "", format:)
      |> join_segment_lines_with_command_newlines(
        lines: [],
        after_command: False,
        options: format.options,
      )
  }
}

fn join_segment_lines_with_command_newlines(
  commands: List(String),
  lines lines: List(String),
  after_command after_command: Bool,
  options options: Options,
) -> String {
  case commands {
    [] -> lines |> list.reverse |> string.join("\n")
    [command, ..rest] -> {
      let name = command_name(command)

      case is_command_name(name) {
        False -> {
          join_segment_lines_with_command_newlines(
            rest,
            lines: [command, ..lines],
            after_command: False,
            options:,
          )
        }
        True -> {
          let arguments = command_arguments(command, options)
          let lines = case lines == [] || after_command {
            True -> [name, ..lines]
            False -> {
              case is_move_command(name) {
                True -> [name, ..lines]
                False -> append_to_current_line(lines, name)
              }
            }
          }
          let lines = case arguments == "" {
            True -> lines
            False -> [arguments, ..lines]
          }

          join_segment_lines_with_command_newlines(
            rest,
            lines:,
            after_command: arguments == "",
            options:,
          )
        }
      }
    }
  }
}

fn append_to_current_line(lines: List(String), suffix: String) -> List(String) {
  case lines {
    [] -> [suffix]
    [line, ..rest] -> [line <> " " <> suffix, ..rest]
  }
}

fn is_move_command(command: String) -> Bool {
  command == "M" || command == "m"
}

fn is_command_name(command: String) -> Bool {
  list.contains(
    [
      "M", "m", "L", "l", "H", "h", "V", "v", "Q", "q", "C", "c", "A", "a", "Z",
      "z",
    ],
    command,
  )
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

fn command_arguments(command: String, options: Options) -> String {
  let arguments = string.drop_start(command, up_to: 1)

  case options.minimize_whitespace {
    True -> arguments
    False -> string.drop_start(arguments, up_to: 1)
  }
}

fn compacted_command_arguments(command: String, options: Options) -> String {
  let arguments = command_arguments(command, options)

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
      relative_path_numbers(svg_path.path_subpaths(path), origin(), [], options)
    False -> {
      path
      |> svg_path.path_subpaths
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
  let assert Ok(start) = svg_path.subpath_start(subpath)

  case svg_path.subpath_segments(subpath) {
    [] -> point_numbers(start)
    [_, ..] -> {
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
  let assert Ok(start) = svg_path.subpath_start(subpath)

  case svg_path.subpath_segments(subpath) {
    [] -> point_numbers(delta(start, current))
    [_, ..] -> {
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
    AutoLeftPadding(style) ->
      number_format.AutoLeftPadding(left_padding_style(style))
    LeftPadding(width, style) -> {
      number_format.LeftPadding(width, left_padding_style(style))
    }
  }
}

fn left_padding_style(
  style: LeftPaddingStyle,
) -> number_format.LeftPaddingStyle {
  case style {
    Zero -> number_format.Zero
    Space -> number_format.Space
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
