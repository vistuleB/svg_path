import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import svg_path

pub type Options {
  Options(
    decimal_places: Option(Int),
    fixed_decimals: Bool,
    relative: Bool,
    minimize_whitespace: Bool,
    compact_commands: Bool,
  )
}

pub fn default_options() -> Options {
  Options(
    decimal_places: Some(5),
    fixed_decimals: False,
    relative: False,
    minimize_whitespace: False,
    compact_commands: False,
  )
}

pub fn decimal_options(decimal_places: Int) -> Options {
  Options(
    decimal_places: Some(decimal_places),
    fixed_decimals: False,
    relative: False,
    minimize_whitespace: False,
    compact_commands: False,
  )
}

pub fn fixed_decimal_options(decimal_places: Int) -> Options {
  Options(
    decimal_places: Some(decimal_places),
    fixed_decimals: True,
    relative: False,
    minimize_whitespace: False,
    compact_commands: False,
  )
}

pub fn relative_options() -> Options {
  Options(
    decimal_places: Some(5),
    fixed_decimals: False,
    relative: True,
    minimize_whitespace: False,
    compact_commands: False,
  )
}

pub fn relative_decimal_options(decimal_places: Int) -> Options {
  Options(
    decimal_places: Some(decimal_places),
    fixed_decimals: False,
    relative: True,
    minimize_whitespace: False,
    compact_commands: False,
  )
}

pub fn relative_fixed_decimal_options(decimal_places: Int) -> Options {
  Options(
    decimal_places: Some(decimal_places),
    fixed_decimals: True,
    relative: True,
    minimize_whitespace: False,
    compact_commands: False,
  )
}

pub fn minimize_whitespace(options: Options) -> Options {
  Options(..options, minimize_whitespace: True)
}

pub fn compact_commands(options: Options) -> Options {
  Options(..options, compact_commands: True)
}

pub fn path(path: svg_path.Path) -> String {
  path_with_options(path, default_options())
}

pub fn path_with_options(
  path path: svg_path.Path,
  options options: Options,
) -> String {
  case options.relative {
    True -> relative_path(svg_path.subpaths(path), options)
    False -> {
      path
      |> svg_path.subpaths
      |> list.map(with: subpath_with_options(_, options:))
      |> list.filter(keeping: fn(serialized) { serialized != "" })
      |> join_commands(options)
    }
  }
}

pub fn subpath(subpath: svg_path.Subpath) -> String {
  subpath_with_options(subpath, default_options())
}

pub fn subpath_with_options(
  subpath subpath: svg_path.Subpath,
  options options: Options,
) -> String {
  case options.relative {
    True -> subpath_from_current(subpath, origin(), options)
    False -> {
      case svg_path.segments(subpath) {
        [] -> ""
        [first, ..rest] -> {
          let start = svg_path.segment_start(first)
          let commands = [
            command("M", point(start, options), options),
            absolute_segment_without_move(first, options),
          ]
          let commands =
            list.append(
              commands,
              list.map(rest, absolute_segment_without_move(_, options)),
            )
          let commands = case svg_path.is_closed(subpath) {
            True -> list.append(commands, ["Z"])
            False -> commands
          }

          join_commands(commands, options)
        }
      }
    }
  }
}

pub fn segment(segment: svg_path.Segment) -> String {
  segment_with_options(segment, default_options())
}

pub fn segment_with_options(
  segment segment: svg_path.Segment,
  options options: Options,
) -> String {
  let start = svg_path.segment_start(segment)
  case options.relative {
    True -> {
      join_commands(
        [
          command("m", point(start, options), options),
          relative_segment_without_move(segment, options),
        ],
        options,
      )
    }
    False -> {
      join_commands(
        [
          command("M", point(start, options), options),
          absolute_segment_without_move(segment, options),
        ],
        options,
      )
    }
  }
}

fn relative_path(subpaths: List(svg_path.Subpath), options: Options) -> String {
  relative_path_loop(subpaths, origin(), [], options)
}

fn relative_path_loop(
  subpaths: List(svg_path.Subpath),
  current: svg_path.Point,
  serialized: List(String),
  options: Options,
) -> String {
  case subpaths {
    [] -> {
      serialized
      |> list.reverse
      |> list.filter(keeping: fn(subpath) { subpath != "" })
      |> join_commands(options)
    }
    [subpath, ..rest] -> {
      relative_path_loop(
        rest,
        current_after_subpath(subpath, current),
        [subpath_from_current(subpath, current, options), ..serialized],
        options,
      )
    }
  }
}

fn subpath_from_current(
  subpath: svg_path.Subpath,
  current: svg_path.Point,
  options: Options,
) -> String {
  case svg_path.segments(subpath) {
    [] -> ""
    [first, ..rest] -> {
      let start = svg_path.segment_start(first)
      let commands = [
        command("m", point(delta(start, current), options), options),
        relative_segment_without_move(first, options),
      ]
      let commands =
        list.append(
          commands,
          list.map(rest, relative_segment_without_move(_, options)),
        )
      let commands = case svg_path.is_closed(subpath) {
        True -> list.append(commands, ["Z"])
        False -> commands
      }

      join_commands(commands, options)
    }
  }
}

fn absolute_segment_without_move(
  segment: svg_path.Segment,
  options: Options,
) -> String {
  case segment {
    svg_path.Line(start:, end:) -> absolute_line(start, end, options)
    svg_path.QuadraticBezier(control:, end:, ..) -> {
      command(
        "Q",
        point(control, options) <> " " <> point(end, options),
        options,
      )
    }
    svg_path.CubicBezier(control1:, control2:, end:, ..) -> {
      command(
        "C",
        point(control1, options)
          <> " "
          <> point(control2, options)
          <> " "
          <> point(end, options),
        options,
      )
    }
    svg_path.Arc(radius:, x_axis_rotation:, large_arc:, sweep:, end:, ..) -> {
      command(
        "A",
        point(radius, options)
          <> " "
          <> number(x_axis_rotation, options)
          <> " "
          <> flag(large_arc)
          <> " "
          <> flag(sweep)
          <> " "
          <> point(end, options),
        options,
      )
    }
  }
}

fn relative_segment_without_move(
  segment: svg_path.Segment,
  options: Options,
) -> String {
  let start = svg_path.segment_start(segment)

  case segment {
    svg_path.Line(end:, ..) -> {
      relative_line(start, end, options)
    }
    svg_path.QuadraticBezier(control:, end:, ..) -> {
      command(
        "q",
        point(delta(control, start), options)
          <> " "
          <> point(delta(end, start), options),
        options,
      )
    }
    svg_path.CubicBezier(control1:, control2:, end:, ..) -> {
      command(
        "c",
        point(delta(control1, start), options)
          <> " "
          <> point(delta(control2, start), options)
          <> " "
          <> point(delta(end, start), options),
        options,
      )
    }
    svg_path.Arc(radius:, x_axis_rotation:, large_arc:, sweep:, end:, ..) -> {
      command(
        "a",
        point(radius, options)
          <> " "
          <> number(x_axis_rotation, options)
          <> " "
          <> flag(large_arc)
          <> " "
          <> flag(sweep)
          <> " "
          <> point(delta(end, start), options),
        options,
      )
    }
  }
}

fn absolute_line(
  start: svg_path.Point,
  end: svg_path.Point,
  options: Options,
) -> String {
  let start_x = number(start.x, options)
  let start_y = number(start.y, options)
  let end_x = number(end.x, options)
  let end_y = number(end.y, options)

  case start_y == end_y {
    True -> command("H", end_x, options)
    False -> {
      case start_x == end_x {
        True -> command("V", end_y, options)
        False -> command("L", end_x <> " " <> end_y, options)
      }
    }
  }
}

fn relative_line(
  start: svg_path.Point,
  end: svg_path.Point,
  options: Options,
) -> String {
  let difference = delta(end, start)
  let dx = number(difference.x, options)
  let dy = number(difference.y, options)
  let zero = number(0.0, options)

  case dy == zero {
    True -> command("h", dx, options)
    False -> {
      case dx == zero {
        True -> command("v", dy, options)
        False -> command("l", dx <> " " <> dy, options)
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

fn point(point: svg_path.Point, options: Options) -> String {
  number(point.x, options) <> " " <> number(point.y, options)
}

fn command(command: String, arguments: String, options: Options) -> String {
  command <> command_argument_separator(options) <> arguments
}

fn command_argument_separator(options: Options) -> String {
  case options.minimize_whitespace {
    True -> ""
    False -> " "
  }
}

fn join_commands(commands: List(String), options: Options) -> String {
  case options.compact_commands {
    False -> string.join(commands, command_separator(options))
    True -> {
      commands
      |> compact_repeated_commands(previous: "", options:)
      |> string.join(command_separator(options))
    }
  }
}

fn compact_repeated_commands(
  commands: List(String),
  previous previous: String,
  options options: Options,
) -> List(String) {
  case commands {
    [] -> []
    [command, ..rest] -> {
      let current = command_name(command)
      let compacted = case current == previous && can_repeat_command(current) {
        True -> compacted_command_arguments(command, options)
        False -> command
      }

      [
        compacted,
        ..compact_repeated_commands(rest, previous: current, options:)
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

fn number(number: Float, options: Options) -> String {
  case options.decimal_places {
    None -> float.to_string(number)
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
  power_of_ten_int(exponent) |> int.to_float
}

fn power_of_ten_int(exponent: Int) -> Int {
  case exponent <= 0 {
    True -> 1
    False -> 10 * power_of_ten_int(exponent - 1)
  }
}

fn flag(flag: Bool) -> String {
  case flag {
    True -> "1"
    False -> "0"
  }
}
