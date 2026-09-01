//// SVG path data serializer.
////
//// This module turns paths, subpaths, and segments into SVG `d` attribute
//// strings. The default output favors readable canonical forms; options can be
//// used for relative commands, smaller whitespace, and omitted repeated command
//// letters.

import gleam/float
import gleam/list
import gleam/string
import svg_path
import svg_path/format as number_format
import svg_path/trig

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
    /// Whether the first line after a moveto has an explicit `L`/`l` command.
    explicit_initial_lineto: Bool,
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
  /// Scientific notation is used when fixed-point scaling would be unsafe.
  AtMost(Int)

  /// Use exactly this many decimal places. Scientific notation fixes the
  /// significand to this width when fixed-point scaling would be unsafe.
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
    explicit_initial_lineto: True,
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
    explicit_initial_lineto: True,
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
    explicit_initial_lineto: True,
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
    explicit_initial_lineto: True,
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
    explicit_initial_lineto: True,
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
  |> explicit_initial_lineto(False)
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
    explicit_initial_lineto: True,
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

type RelativeParserState {
  RelativeParserState(
    parser_current: svg_path.Point,
    parser_subpath_start: svg_path.Point,
    previous_curve: PreviousCurve,
  )
}

/// Remove whitespace wherever SVG number grammar makes the boundary clear.
///
/// This removes command-argument spaces and numeric separators before signs,
/// and emits fractions without a leading zero.
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

/// Control whether the first line after each moveto includes `L`/`l`.
///
/// When this is `False`, the line endpoint is emitted as a second coordinate
/// pair of the moveto command, as permitted by SVG path syntax.
pub fn explicit_initial_lineto(
  options: Options,
  explicit_initial_lineto: Bool,
) -> Options {
  Options(..options, explicit_initial_lineto:)
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
  path_with(path, default_options())
}

/// Serialize a path with custom options.
///
/// With relative options, closed subpaths end in `z`.
pub fn path_with(path path: svg_path.Path, options options: Options) -> String {
  case options.relative {
    True -> {
      let format = parser_tracked_serialization_format(path, options)
      parser_tracked_relative_path(svg_path.path_subpaths(path), format)
    }
    False -> {
      let format = serialization_format(options, path_numbers(path, options))
      path
      |> svg_path.path_subpaths
      |> list.map(with: serialize_absolute_subpath(_, format))
      |> list.filter(keeping: fn(serialized) { serialized != "" })
      |> join_commands(format)
    }
  }
}

/// Serialize a path with relative commands corrected against a simulated SVG
/// parser state.
///
/// This is an explicit relative-only spelling of the parser-tracked behavior
/// used by `path_with` whenever `options.relative == True`. The supplied
/// options still control formatting, shorthand commands, whitespace, and
/// newlines; relative commands are enabled regardless of `options.relative`.
@internal
pub fn path_with_parser_tracked_relative_options(
  path path: svg_path.Path,
  options options: Options,
) -> String {
  let options = Options(..options, relative: True)
  path_with(path, options)
}

/// Serialize a path using independently rounded relative segment parameters.
///
/// This preserves the relative serialization policy used before parser-tracked
/// drift compensation became the default. Relative commands are enabled
/// regardless of `options.relative`.
@internal
pub fn path_with_independent_relative_options(
  path path: svg_path.Path,
  options options: Options,
) -> String {
  let options = Options(..options, relative: True)
  let format = serialization_format(options, path_numbers(path, options))
  relative_path(svg_path.path_subpaths(path), format)
}

fn parser_tracked_serialization_format(
  path: svg_path.Path,
  options: Options,
) -> Format {
  case options.left_decimals {
    AutoLeftPadding(_) -> {
      let prepass_options =
        Options(
          ..options,
          left_decimals: Succinct,
          minimize_whitespace: False,
          commas: False,
          repeat_commands: True,
          newlines: OneLine,
        )
      let prepass_format = serialization_format(prepass_options, [])
      let emitted =
        parser_tracked_relative_path(
          svg_path.path_subpaths(path),
          prepass_format,
        )
      Format(
        options:,
        number_format: number_format.prepare_raw(
          number_options(options),
          serialized_number_tokens(emitted),
        ),
      )
    }
    _ -> serialization_format(options, path_numbers(path, options))
  }
}

fn serialized_number_tokens(serialized: String) -> List(String) {
  serialized
  |> string.replace(each: "\n", with: " ")
  |> string.replace(each: ",", with: " ")
  |> replace_svg_command_letters
  |> string.split(on: " ")
  |> list.filter(fn(token) { token != "" })
}

fn replace_svg_command_letters(serialized: String) -> String {
  [
    "M",
    "m",
    "L",
    "l",
    "H",
    "h",
    "V",
    "v",
    "Q",
    "q",
    "C",
    "c",
    "S",
    "s",
    "T",
    "t",
    "A",
    "a",
    "Z",
    "z",
  ]
  |> list.fold(serialized, fn(serialized, letter) {
    string.replace(serialized, each: letter, with: " ")
  })
}

/// Serialize a subpath with default options.
///
/// Empty subpaths serialize as move-only subpaths. Closed subpaths end in `Z`.
pub fn subpath(subpath: svg_path.Subpath) -> String {
  subpath_with(subpath, default_options())
}

/// Serialize a subpath with custom options.
///
/// With relative options, closed subpaths end in `z`.
pub fn subpath_with(
  subpath subpath: svg_path.Subpath,
  options options: Options,
) -> String {
  let format = serialization_format(options, subpath_numbers(subpath, options))

  case options.relative {
    True -> path_with(svg_path.Path([subpath]), options)
    False -> serialize_absolute_subpath(subpath, format)
  }
}

/// Serialize a segment with default options.
pub fn segment(segment: svg_path.Segment) -> String {
  segment_with(segment, default_options())
}

/// Serialize a segment with custom options.
pub fn segment_with(
  segment segment: svg_path.Segment,
  options options: Options,
) -> String {
  let format =
    serialization_format(options, segment_with_move_numbers(segment, options))
  let start = svg_path.segment_start(segment)
  case options.relative {
    True -> {
      let assert Ok(subpath) = svg_path.subpath([segment])
      path_with(svg_path.Path([subpath]), options)
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
  let start = svg_path.subpath_start(subpath)

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
      let #(move, segments) = case
        format.options.explicit_initial_lineto,
        segments
      {
        False, [svg_path.Line(end:, ..), ..rest] -> #(
          command(
            "M",
            join_number_groups(
              [point(start, format), point(end, format)],
              format,
            ),
            format,
          ),
          rest,
        )
        _, _ -> #(command("M", point(start, format), format), segments)
      }
      let commands = [move, ..absolute_segments(segments, format)]
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

fn parser_tracked_relative_path(
  subpaths: List(svg_path.Subpath),
  format: Format,
) -> String {
  parser_tracked_relative_path_loop(
    subpaths,
    RelativeParserState(
      parser_current: origin(),
      parser_subpath_start: origin(),
      previous_curve: NoPreviousCurve,
    ),
    [],
    format,
  )
}

fn parser_tracked_relative_path_loop(
  subpaths: List(svg_path.Subpath),
  state: RelativeParserState,
  serialized: List(String),
  format: Format,
) -> String {
  case subpaths {
    [] -> serialized |> list.reverse |> join_commands(format)
    [subpath, ..rest] -> {
      let #(commands, state) =
        parser_tracked_subpath_from_state(subpath, state, format)
      parser_tracked_relative_path_loop(
        rest,
        state,
        [join_commands(commands, format), ..serialized],
        format,
      )
    }
  }
}

fn parser_tracked_subpath_from_state(
  subpath: svg_path.Subpath,
  state: RelativeParserState,
  format: Format,
) -> #(List(String), RelativeParserState) {
  let source_start = svg_path.subpath_start(subpath)
  let RelativeParserState(parser_current:, ..) = state
  let move_delta =
    quantized_point(source_start, format)
    |> delta(from: parser_current)
    |> quantized_point(format)
  let parser_start = add(parser_current, move_delta)
  let move = command("m", point(move_delta, format), format)
  let state =
    RelativeParserState(
      parser_current: parser_start,
      parser_subpath_start: parser_start,
      previous_curve: NoPreviousCurve,
    )
  let #(move, segment_commands, state) = case
    format.options.explicit_initial_lineto,
    serializable_segments(subpath)
  {
    False, [svg_path.Line(start:, end:), ..rest] -> {
      let Format(options:, number_format:) = format
      let line_format =
        Format(options: Options(..options, use_h_v: False), number_format:)
      let assert #([line], state) =
        parser_tracked_line(start, end, state, line_format)
      let move =
        move
        <> command_chunk_separator(
          move,
          command_arguments(line, options),
          options,
        )
        <> command_arguments(line, options)
      let #(commands, state) = parser_tracked_segments(rest, state, [], format)
      #(move, commands, state)
    }
    _, segments -> {
      let #(commands, state) =
        parser_tracked_segments(segments, state, [], format)
      #(move, commands, state)
    }
  }
  let commands = [move, ..segment_commands]

  case svg_path.subpath_is_closed(subpath) {
    False -> #(commands, state)
    True -> {
      let RelativeParserState(parser_subpath_start:, ..) = state
      #(
        list.append(commands, ["z"]),
        RelativeParserState(
          parser_current: parser_subpath_start,
          parser_subpath_start:,
          previous_curve: NoPreviousCurve,
        ),
      )
    }
  }
}

fn parser_tracked_segments(
  segments: List(svg_path.Segment),
  state: RelativeParserState,
  serialized: List(String),
  format: Format,
) -> #(List(String), RelativeParserState) {
  case segments {
    [] -> #(list.reverse(serialized), state)
    [segment, ..rest] -> {
      let #(commands, state) = parser_tracked_segment(segment, state, format)
      parser_tracked_segments(
        rest,
        state,
        list.append(list.reverse(commands), serialized),
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
  let start = svg_path.subpath_start(subpath)

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
      let parser_start = quantized_point(start, format)
      let parser_control = quantized_point(control, format)
      let reflected = reflected_quadratic_control(parser_start, previous)
      let smooth = parser_control == reflected
      #(
        absolute_quadratic(control, end, smooth, format),
        PreviousQuadratic(case smooth {
          True -> reflected
          False -> parser_control
        }),
      )
    }
    svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      let parser_start = quantized_point(start, format)
      let parser_control1 = quantized_point(control1, format)
      let reflected = reflected_cubic_control(parser_start, previous)
      let smooth = parser_control1 == reflected
      #(
        absolute_cubic(control1, control2, end, smooth, format),
        PreviousCubic(quantized_point(control2, format)),
      )
    }
    svg_path.Arc(radius:, x_axis_rotation:, large_arc:, sweep:, end:, ..) -> {
      #(
        command(
          "A",
          arc_arguments(radius, x_axis_rotation, large_arc, sweep, end, format),
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
          arc_arguments(
            radius,
            x_axis_rotation,
            large_arc,
            sweep,
            delta(end, start),
            format,
          ),
          format,
        ),
        NoPreviousCurve,
      )
    }
  }
}

fn parser_tracked_segment(
  segment: svg_path.Segment,
  state: RelativeParserState,
  format: Format,
) -> #(List(String), RelativeParserState) {
  case segment {
    svg_path.Line(start:, end:) ->
      parser_tracked_line(start, end, state, format)
    svg_path.QuadraticBezier(start:, control:, end:) ->
      parser_tracked_quadratic(start, control, end, state, format)
    svg_path.CubicBezier(start:, control1:, control2:, end:) ->
      parser_tracked_cubic(start, control1, control2, end, state, format)
    svg_path.Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:) ->
      parser_tracked_arc(
        segment,
        start,
        radius,
        x_axis_rotation,
        large_arc,
        sweep,
        end,
        state,
        format,
      )
  }
}

fn parser_tracked_line(
  source_start: svg_path.Point,
  source_end: svg_path.Point,
  state: RelativeParserState,
  format: Format,
) -> #(List(String), RelativeParserState) {
  let RelativeParserState(parser_current:, parser_subpath_start:, ..) = state
  let intended_end = quantized_point(source_end, format)
  let source_horizontal = source_start.y == source_end.y
  let source_vertical = source_start.x == source_end.x
  let target = case source_horizontal, source_vertical {
    True, _ -> svg_path.Point(intended_end.x, parser_current.y)
    _, True -> svg_path.Point(parser_current.x, intended_end.y)
    _, _ -> intended_end
  }
  let target_horizontal =
    raw_number(target.y, format.options)
    == raw_number(parser_current.y, format.options)
  let target_vertical =
    raw_number(target.x, format.options)
    == raw_number(parser_current.x, format.options)
  let #(command_name, parser_end, arguments) = case
    format.options.use_h_v,
    target_horizontal,
    target_vertical
  {
    True, True, _ -> {
      let dx = quantized_number(intended_end.x -. parser_current.x, format)
      #(
        "h",
        svg_path.Point(parser_current.x +. dx, parser_current.y),
        number(dx, format),
      )
    }
    True, _, True -> {
      let dy = quantized_number(intended_end.y -. parser_current.y, format)
      #(
        "v",
        svg_path.Point(parser_current.x, parser_current.y +. dy),
        number(dy, format),
      )
    }
    _, _, _ -> {
      let difference =
        target |> delta(from: parser_current) |> quantized_point(format)
      #("l", add(parser_current, difference), point(difference, format))
    }
  }
  #(
    [command(command_name, arguments, format)],
    RelativeParserState(
      parser_current: parser_end,
      parser_subpath_start:,
      previous_curve: NoPreviousCurve,
    ),
  )
}

type ChordSimilarity {
  ChordSimilarity(
    source_start: svg_path.Point,
    parser_start: svg_path.Point,
    scale_cos: Float,
    scale_sin: Float,
  )
  UnstableChord
}

fn parser_tracked_quadratic(
  source_start: svg_path.Point,
  source_control: svg_path.Point,
  source_end: svg_path.Point,
  state: RelativeParserState,
  format: Format,
) -> #(List(String), RelativeParserState) {
  let RelativeParserState(
    parser_current:,
    parser_subpath_start:,
    previous_curve:,
  ) = state
  let intended_end = quantized_point(source_end, format)
  let similarity =
    chord_similarity(source_start, source_end, parser_current, intended_end)
  let corrected_control = case similarity {
    ChordSimilarity(..) -> similarity_point(source_control, similarity)
    UnstableChord -> {
      let drift = delta(parser_current, from: source_start)
      svg_path.Point(
        source_control.x +. drift.x *. 0.5,
        source_control.y +. drift.y *. 0.5,
      )
    }
  }
  let parser_control = quantized_point(corrected_control, format)
  let control_delta =
    parser_control |> delta(from: parser_current) |> quantized_point(format)
  let end_delta =
    intended_end |> delta(from: parser_current) |> quantized_point(format)
  let parser_end = add(parser_current, end_delta)
  let reflected = reflected_quadratic_control(parser_current, previous_curve)
  let smooth =
    format.options.use_s_t
    && formatted_points_equal(parser_control, reflected, format)
  let command = case smooth {
    True -> command("t", point(end_delta, format), format)
    False ->
      command(
        "q",
        join_number_groups(
          [point(control_delta, format), point(end_delta, format)],
          format,
        ),
        format,
      )
  }
  let effective_control = case smooth {
    True -> reflected
    False -> add(parser_current, control_delta)
  }
  #(
    [command],
    RelativeParserState(
      parser_current: parser_end,
      parser_subpath_start:,
      previous_curve: PreviousQuadratic(effective_control),
    ),
  )
}

fn parser_tracked_cubic(
  source_start: svg_path.Point,
  source_control1: svg_path.Point,
  source_control2: svg_path.Point,
  source_end: svg_path.Point,
  state: RelativeParserState,
  format: Format,
) -> #(List(String), RelativeParserState) {
  let RelativeParserState(
    parser_current:,
    parser_subpath_start:,
    previous_curve:,
  ) = state
  let intended_end = quantized_point(source_end, format)
  let similarity =
    chord_similarity(source_start, source_end, parser_current, intended_end)
  let #(corrected_control1, corrected_control2) = case similarity {
    ChordSimilarity(..) -> #(
      similarity_point(source_control1, similarity),
      similarity_point(source_control2, similarity),
    )
    UnstableChord -> {
      let drift = delta(parser_current, from: source_start)
      #(
        svg_path.Point(
          source_control1.x +. drift.x *. 2.0 /. 3.0,
          source_control1.y +. drift.y *. 2.0 /. 3.0,
        ),
        svg_path.Point(
          source_control2.x +. drift.x /. 3.0,
          source_control2.y +. drift.y /. 3.0,
        ),
      )
    }
  }
  let parser_control1 = quantized_point(corrected_control1, format)
  let parser_control2 = quantized_point(corrected_control2, format)
  let control1_delta =
    parser_control1 |> delta(from: parser_current) |> quantized_point(format)
  let control2_delta =
    parser_control2 |> delta(from: parser_current) |> quantized_point(format)
  let end_delta =
    intended_end |> delta(from: parser_current) |> quantized_point(format)
  let parser_end = add(parser_current, end_delta)
  let reflected = reflected_cubic_control(parser_current, previous_curve)
  let smooth =
    format.options.use_s_t
    && formatted_points_equal(parser_control1, reflected, format)
  let command = case smooth {
    True ->
      command(
        "s",
        join_number_groups(
          [point(control2_delta, format), point(end_delta, format)],
          format,
        ),
        format,
      )
    False ->
      command(
        "c",
        join_number_groups(
          [
            point(control1_delta, format),
            point(control2_delta, format),
            point(end_delta, format),
          ],
          format,
        ),
        format,
      )
  }
  #(
    [command],
    RelativeParserState(
      parser_current: parser_end,
      parser_subpath_start:,
      previous_curve: PreviousCubic(add(parser_current, control2_delta)),
    ),
  )
}

fn parser_tracked_arc(
  segment: svg_path.Segment,
  source_start: svg_path.Point,
  source_radius: svg_path.Point,
  source_rotation: Float,
  large_arc: Bool,
  sweep: Bool,
  source_end: svg_path.Point,
  state: RelativeParserState,
  format: Format,
) -> #(List(String), RelativeParserState) {
  case source_start == source_end {
    True ->
      case
        svg_path.segment_between(segment, from: 0.0, to: 0.5),
        svg_path.segment_between(segment, from: 0.5, to: 1.0)
      {
        Ok(first), Ok(second) -> {
          let #(first_commands, state) =
            parser_tracked_segment(first, state, format)
          let #(second_commands, state) =
            parser_tracked_segment(second, state, format)
          #(list.append(first_commands, second_commands), state)
        }
        _, _ ->
          parser_tracked_arc_command(
            source_start,
            source_radius,
            source_rotation,
            large_arc,
            sweep,
            source_end,
            state,
            format,
          )
      }
    False ->
      parser_tracked_arc_command(
        source_start,
        source_radius,
        source_rotation,
        large_arc,
        sweep,
        source_end,
        state,
        format,
      )
  }
}

fn parser_tracked_arc_command(
  source_start: svg_path.Point,
  source_radius: svg_path.Point,
  source_rotation: Float,
  large_arc: Bool,
  sweep: Bool,
  source_end: svg_path.Point,
  state: RelativeParserState,
  format: Format,
) -> #(List(String), RelativeParserState) {
  let RelativeParserState(parser_current:, parser_subpath_start:, ..) = state
  let intended_end = quantized_point(source_end, format)
  let similarity =
    chord_similarity(source_start, source_end, parser_current, intended_end)
  let #(radius, rotation) = case similarity {
    ChordSimilarity(scale_cos:, scale_sin:, ..) -> {
      let scale =
        float.square_root(scale_cos *. scale_cos +. scale_sin *. scale_sin)
        |> result_unwrap_float(1.0)
      #(
        svg_path.Point(source_radius.x *. scale, source_radius.y *. scale),
        source_rotation +. trig.atan2_degrees(scale_sin, scale_cos),
      )
    }
    UnstableChord -> #(source_radius, source_rotation)
  }
  let end_delta =
    intended_end |> delta(from: parser_current) |> quantized_point(format)
  let parser_end = add(parser_current, end_delta)
  let serialized =
    command(
      "a",
      arc_arguments(radius, rotation, large_arc, sweep, end_delta, format),
      format,
    )
  #(
    [serialized],
    RelativeParserState(
      parser_current: parser_end,
      parser_subpath_start:,
      previous_curve: NoPreviousCurve,
    ),
  )
}

fn chord_similarity(
  source_start: svg_path.Point,
  source_end: svg_path.Point,
  parser_start: svg_path.Point,
  parser_end: svg_path.Point,
) -> ChordSimilarity {
  let source_dx = source_end.x -. source_start.x
  let source_dy = source_end.y -. source_start.y
  let target_dx = parser_end.x -. parser_start.x
  let target_dy = parser_end.y -. parser_start.y
  let source_length_squared = source_dx *. source_dx +. source_dy *. source_dy
  let target_length_squared = target_dx *. target_dx +. target_dy *. target_dy
  case
    source_length_squared <=. 0.000000000001 || target_length_squared == 0.0
  {
    True -> UnstableChord
    False ->
      ChordSimilarity(
        source_start:,
        parser_start:,
        scale_cos: { source_dx *. target_dx +. source_dy *. target_dy }
          /. source_length_squared,
        scale_sin: { source_dx *. target_dy -. source_dy *. target_dx }
          /. source_length_squared,
      )
  }
}

fn similarity_point(
  point: svg_path.Point,
  similarity: ChordSimilarity,
) -> svg_path.Point {
  let assert ChordSimilarity(
    source_start:,
    parser_start:,
    scale_cos:,
    scale_sin:,
  ) = similarity
  let x = point.x -. source_start.x
  let y = point.y -. source_start.y
  svg_path.Point(
    parser_start.x +. scale_cos *. x -. scale_sin *. y,
    parser_start.y +. scale_sin *. x +. scale_cos *. y,
  )
}

fn absolute_quadratic(
  control: svg_path.Point,
  end: svg_path.Point,
  smooth: Bool,
  format: Format,
) -> String {
  case format.options.use_s_t && smooth {
    True -> command("T", point(end, format), format)
    False ->
      command(
        "Q",
        join_number_groups([point(control, format), point(end, format)], format),
        format,
      )
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
        join_number_groups(
          [
            point(delta(control, start), format),
            point(delta(end, start), format),
          ],
          format,
        ),
        format,
      )
  }
}

fn absolute_cubic(
  control1: svg_path.Point,
  control2: svg_path.Point,
  end: svg_path.Point,
  smooth: Bool,
  format: Format,
) -> String {
  case format.options.use_s_t && smooth {
    True ->
      command(
        "S",
        join_number_groups(
          [point(control2, format), point(end, format)],
          format,
        ),
        format,
      )
    False ->
      command(
        "C",
        join_number_groups(
          [point(control1, format), point(control2, format), point(end, format)],
          format,
        ),
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
        join_number_groups(
          [
            point(delta(control2, start), format),
            point(delta(end, start), format),
          ],
          format,
        ),
        format,
      )
    False ->
      command(
        "c",
        join_number_groups(
          [
            point(delta(control1, start), format),
            point(delta(control2, start), format),
            point(delta(end, start), format),
          ],
          format,
        ),
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
  svg_path.Point(2.0 *. center.x -. point.x, 2.0 *. center.y -. point.y)
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
        False -> command("L", point(end, format), format)
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
        False -> command("l", point(difference, format), format)
      }
    }
  }
}

fn current_after_subpath(
  subpath: svg_path.Subpath,
  _current: svg_path.Point,
) -> svg_path.Point {
  case svg_path.subpath_segments(subpath) {
    [] -> {
      let start = svg_path.subpath_start(subpath)
      start
    }
    [first, ..] -> {
      case svg_path.subpath_is_closed(subpath) {
        True -> svg_path.segment_start(first)
        False -> svg_path.subpath_end(subpath)
      }
    }
  }
}

fn origin() -> svg_path.Point {
  svg_path.Point(0.0, 0.0)
}

fn delta(point: svg_path.Point, from origin: svg_path.Point) -> svg_path.Point {
  svg_path.Point(point.x -. origin.x, point.y -. origin.y)
}

fn add(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.Point(a.x +. b.x, a.y +. b.y)
}

fn quantized_point(point: svg_path.Point, format: Format) -> svg_path.Point {
  svg_path.Point(
    quantized_number(point.x, format),
    quantized_number(point.y, format),
  )
}

fn quantized_number(value: Float, format: Format) -> Float {
  let parseable =
    number_format.code_number(value, with: format.number_format)
    |> string.trim
  case float.parse(parseable) {
    Ok(quantized) -> quantized
    Error(_) -> value
  }
}

fn result_unwrap_float(result: Result(Float, Nil), fallback: Float) -> Float {
  case result {
    Ok(value) -> value
    Error(_) -> fallback
  }
}

fn point(point: svg_path.Point, format: Format) -> String {
  let x = number(point.x, format)
  let y = number(point.y, format)
  x <> coordinate_value_separator(x, y, format.options) <> y
}

fn join_number_groups(groups: List(String), format: Format) -> String {
  case groups {
    [] -> ""
    [first, ..rest] -> join_number_groups_loop(rest, first, first, format)
  }
}

fn join_number_groups_loop(
  groups: List(String),
  previous: String,
  joined: String,
  format: Format,
) -> String {
  case groups {
    [] -> joined
    [next, ..rest] ->
      join_number_groups_loop(
        rest,
        next,
        joined <> number_group_separator(previous, next, format.options) <> next,
        format,
      )
  }
}

fn number_group_separator(
  left: String,
  right: String,
  options: Options,
) -> String {
  case options.minimize_whitespace {
    False -> " "
    True -> minimized_number_separator(left, right)
  }
}

fn coordinate_value_separator(
  left: String,
  right: String,
  options: Options,
) -> String {
  case options.minimize_whitespace {
    False -> coordinate_separator(options)
    True -> minimized_number_separator(left, right)
  }
}

fn minimized_number_separator(left: String, right: String) -> String {
  case string.starts_with(right, "-") || string.starts_with(right, "+") {
    True -> ""
    False -> {
      case string.starts_with(right, ".") && string.contains(left, ".") {
        True -> ""
        False -> " "
      }
    }
  }
}

fn arc_arguments(
  radius: svg_path.Point,
  rotation: Float,
  large_arc: Bool,
  sweep: Bool,
  end: svg_path.Point,
  format: Format,
) -> String {
  let before_flags =
    join_number_groups(
      [point(radius, format), number(rotation, format)],
      format,
    )
  let flags = flag(large_arc) <> flag_separator(format.options) <> flag(sweep)
  before_flags
  <> number_group_separator(before_flags, flags, format.options)
  <> flags
  <> flag_coordinate_separator(format.options)
  <> point(end, format)
}

fn flag_separator(options: Options) -> String {
  case options.minimize_whitespace {
    True -> ""
    False -> " "
  }
}

fn flag_coordinate_separator(options: Options) -> String {
  case options.minimize_whitespace {
    True -> ""
    False -> " "
  }
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
  let commands = case format.options.repeat_commands {
    True -> commands
    False -> compact_repeated_commands(commands, previous: "", format:)
  }
  join_command_chunks(commands, format.options)
}

fn join_command_chunks(commands: List(String), options: Options) -> String {
  case commands {
    [] -> ""
    [first, ..rest] ->
      list.fold(rest, first, fn(joined, next) {
        let separator = case is_command_name(command_name(next)) {
          True -> command_separator(options)
          False -> command_chunk_separator(joined, next, options)
        }
        joined <> separator <> next
      })
  }
}

fn command_chunk_separator(
  left: String,
  right: String,
  options: Options,
) -> String {
  let _ = left
  case
    options.minimize_whitespace
    && { string.starts_with(right, "-") || string.starts_with(right, "+") }
  {
    True -> ""
    False -> " "
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
      "M", "m", "L", "l", "H", "h", "V", "v", "Q", "q", "C", "c", "S", "s", "T",
      "t", "A", "a", "Z", "z",
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

      let effective_current = case
        is_move_command(current) && !format.options.explicit_initial_lineto
      {
        True ->
          case current {
            "M" -> "L"
            _ -> "l"
          }
        False -> current
      }

      [
        compacted,
        ..compact_repeated_commands(rest, previous: effective_current, format:)
      ]
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
  command_arguments(command, options)
}

fn can_repeat_command(command: String) -> Bool {
  list.contains(
    [
      "L", "l", "H", "h", "V", "v", "Q", "q", "C", "c", "S", "s", "T", "t", "A",
      "a",
    ],
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
    True -> {
      let #(_, groups) =
        path
        |> svg_path.path_subpaths
        |> list.map_fold(origin(), fn(current, subpath) {
          #(
            current_after_subpath(subpath, current),
            relative_subpath_numbers(subpath, current, options),
          )
        })
      list.flat_map(groups, fn(group) { group })
    }
    False ->
      path
      |> svg_path.path_subpaths
      |> list.flat_map(fn(subpath) {
        absolute_subpath_numbers(subpath, options)
      })
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
  let start = svg_path.subpath_start(subpath)

  case svg_path.subpath_segments(subpath) {
    [] -> point_numbers(start)
    [_, ..] -> {
      let segment_numbers =
        serializable_segments(subpath)
        |> list.flat_map(fn(segment) {
          absolute_segment_numbers(segment, options)
        })
      list.append(point_numbers(start), segment_numbers)
    }
  }
}

fn relative_subpath_numbers(
  subpath: svg_path.Subpath,
  current: svg_path.Point,
  options: Options,
) -> List(Float) {
  let start = svg_path.subpath_start(subpath)

  case svg_path.subpath_segments(subpath) {
    [] -> point_numbers(delta(start, current))
    [_, ..] -> {
      let segment_numbers =
        serializable_segments(subpath)
        |> list.flat_map(fn(segment) {
          relative_segment_numbers(segment, options)
        })
      list.append(point_numbers(delta(start, current)), segment_numbers)
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
  let formatted = number_format.number(number, with: format.number_format)
  case format.options.minimize_whitespace {
    False -> formatted
    True -> minimize_leading_zero(formatted)
  }
}

fn minimize_leading_zero(number: String) -> String {
  case string.starts_with(number, "0.") {
    True -> string.drop_start(number, up_to: 1)
    False -> {
      case string.starts_with(number, "-0.") {
        True -> "-" <> string.drop_start(number, up_to: 2)
        False -> number
      }
    }
  }
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
