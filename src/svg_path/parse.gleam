//// SVG path data parser.
////
//// This module parses the `d` attribute syntax used by SVG paths. It supports
//// comma and whitespace separators, compact signed numbers, relative commands,
//// implicit repeated commands, smooth curves, and arcs.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import svg_path

/// Errors returned while parsing SVG path data.
pub type Error {
  /// A parsed path was internally invalid according to the core path model.
  Core(svg_path.Error)

  /// An arc flag was not `0` or `1`.
  ExpectedArcFlag

  /// A command letter was expected.
  ExpectedCommand

  /// Path data must begin with a move command.
  ExpectedMove

  /// A numeric argument was expected.
  ExpectedNumber

  /// A numeric token could not be parsed as a float.
  InvalidNumber(String)

  /// The command letter is not supported by this library.
  UnsupportedCommand(String)
}

type Token {
  Command(String)
  Number(Float)
}

type State {
  State(
    subpaths: List(svg_path.Subpath),
    subpath: svg_path.Subpath,
    current: svg_path.Point,
    has_current: Bool,
    active: Bool,
    last_cubic_control: Option(svg_path.Point),
    last_quadratic_control: Option(svg_path.Point),
  )
}

/// Parse an SVG path data string into a `Path`.
///
/// Empty strings parse as an empty path. Move-only subpaths are preserved as
/// empty subpaths with start points. Closepath commands mark subpaths as
/// closed, inserting a straight line back to the subpath start when needed.
pub fn path(input: String) -> Result(svg_path.Path, Error) {
  case tokenize(input) {
    Error(error) -> Error(error)
    Ok(tokens) -> parse_tokens(tokens, initial_state())
  }
}

fn initial_state() -> State {
  State(
    subpaths: [],
    subpath: svg_path.subpath_empty(at: svg_path.point(0.0, 0.0)),
    current: svg_path.point(0.0, 0.0),
    has_current: False,
    active: False,
    last_cubic_control: None,
    last_quadratic_control: None,
  )
}

fn parse_tokens(
  tokens: List(Token),
  state: State,
) -> Result(svg_path.Path, Error) {
  case tokens {
    [] -> finish(state)
    [Command(command), ..rest] -> parse_command(command, rest, state)
    [Number(_), ..] -> Error(ExpectedCommand)
  }
}

fn parse_command(
  command: String,
  tokens: List(Token),
  state: State,
) -> Result(svg_path.Path, Error) {
  case command {
    "M" -> parse_move(tokens, state, relative: False)
    "m" -> parse_move(tokens, state, relative: True)
    "L" -> parse_line(tokens, state, relative: False)
    "l" -> parse_line(tokens, state, relative: True)
    "Q" -> parse_quadratic_bezier(tokens, state, relative: False)
    "q" -> parse_quadratic_bezier(tokens, state, relative: True)
    "T" -> parse_smooth_quadratic_bezier(tokens, state, relative: False)
    "t" -> parse_smooth_quadratic_bezier(tokens, state, relative: True)
    "C" -> parse_cubic_bezier(tokens, state, relative: False)
    "c" -> parse_cubic_bezier(tokens, state, relative: True)
    "S" -> parse_smooth_cubic_bezier(tokens, state, relative: False)
    "s" -> parse_smooth_cubic_bezier(tokens, state, relative: True)
    "A" -> parse_arc(tokens, state, relative: False)
    "a" -> parse_arc(tokens, state, relative: True)
    "H" -> parse_horizontal(tokens, state, relative: False)
    "h" -> parse_horizontal(tokens, state, relative: True)
    "V" -> parse_vertical(tokens, state, relative: False)
    "v" -> parse_vertical(tokens, state, relative: True)
    "Z" | "z" -> parse_close(tokens, state)
    _ -> Error(UnsupportedCommand(command))
  }
}

fn parse_move(
  tokens: List(Token),
  state: State,
  relative relative: Bool,
) -> Result(svg_path.Path, Error) {
  case take_pair(tokens) {
    Error(error) -> Error(error)
    Ok(#(x, y, rest)) -> {
      case finish_active_subpath(state) {
        Error(error) -> Error(error)
        Ok(state) -> {
          let base = case relative && state.has_current {
            True -> state.current
            False -> svg_path.point(0.0, 0.0)
          }
          let target = offset(base, x, y)
          let state =
            State(
              ..state,
              subpath: svg_path.subpath_empty(at: target),
              current: target,
              has_current: True,
              active: True,
              last_cubic_control: None,
              last_quadratic_control: None,
            )

          parse_implicit_lines(rest, state, relative)
        }
      }
    }
  }
}

fn parse_implicit_lines(
  tokens: List(Token),
  state: State,
  relative: Bool,
) -> Result(svg_path.Path, Error) {
  case tokens {
    [Number(_), ..] -> {
      case take_pair(tokens) {
        Error(error) -> Error(error)
        Ok(#(x, y, rest)) -> {
          case append_line_to(state, target_point(state, x, y, relative)) {
            Error(error) -> Error(error)
            Ok(state) -> parse_implicit_lines(rest, state, relative)
          }
        }
      }
    }
    _ -> parse_tokens(tokens, state)
  }
}

fn parse_line(
  tokens: List(Token),
  state: State,
  relative relative: Bool,
) -> Result(svg_path.Path, Error) {
  case ensure_active(state) {
    Error(error) -> Error(error)
    Ok(Nil) -> parse_line_loop(tokens, state, relative, parsed_any: False)
  }
}

fn parse_line_loop(
  tokens: List(Token),
  state: State,
  relative: Bool,
  parsed_any parsed_any: Bool,
) -> Result(svg_path.Path, Error) {
  case tokens {
    [Number(_), ..] -> {
      case take_pair(tokens) {
        Error(error) -> Error(error)
        Ok(#(x, y, rest)) -> {
          case append_line_to(state, target_point(state, x, y, relative)) {
            Error(error) -> Error(error)
            Ok(state) ->
              parse_line_loop(rest, state, relative, parsed_any: True)
          }
        }
      }
    }
    _ -> {
      case parsed_any {
        True -> parse_tokens(tokens, state)
        False -> Error(ExpectedNumber)
      }
    }
  }
}

fn parse_horizontal(
  tokens: List(Token),
  state: State,
  relative relative: Bool,
) -> Result(svg_path.Path, Error) {
  case ensure_active(state) {
    Error(error) -> Error(error)
    Ok(Nil) -> parse_horizontal_loop(tokens, state, relative, parsed_any: False)
  }
}

fn parse_horizontal_loop(
  tokens: List(Token),
  state: State,
  relative: Bool,
  parsed_any parsed_any: Bool,
) -> Result(svg_path.Path, Error) {
  case tokens {
    [Number(x), ..rest] -> {
      let target = case relative {
        True -> offset(state.current, x, 0.0)
        False -> svg_path.point(x, state.current.y)
      }

      case append_line_to(state, target) {
        Error(error) -> Error(error)
        Ok(state) ->
          parse_horizontal_loop(rest, state, relative, parsed_any: True)
      }
    }
    _ -> {
      case parsed_any {
        True -> parse_tokens(tokens, state)
        False -> Error(ExpectedNumber)
      }
    }
  }
}

fn parse_vertical(
  tokens: List(Token),
  state: State,
  relative relative: Bool,
) -> Result(svg_path.Path, Error) {
  case ensure_active(state) {
    Error(error) -> Error(error)
    Ok(Nil) -> parse_vertical_loop(tokens, state, relative, parsed_any: False)
  }
}

fn parse_vertical_loop(
  tokens: List(Token),
  state: State,
  relative: Bool,
  parsed_any parsed_any: Bool,
) -> Result(svg_path.Path, Error) {
  case tokens {
    [Number(y), ..rest] -> {
      let target = case relative {
        True -> offset(state.current, 0.0, y)
        False -> svg_path.point(state.current.x, y)
      }

      case append_line_to(state, target) {
        Error(error) -> Error(error)
        Ok(state) ->
          parse_vertical_loop(rest, state, relative, parsed_any: True)
      }
    }
    _ -> {
      case parsed_any {
        True -> parse_tokens(tokens, state)
        False -> Error(ExpectedNumber)
      }
    }
  }
}

fn parse_quadratic_bezier(
  tokens: List(Token),
  state: State,
  relative relative: Bool,
) -> Result(svg_path.Path, Error) {
  case ensure_active(state) {
    Error(error) -> Error(error)
    Ok(Nil) ->
      parse_quadratic_bezier_loop(tokens, state, relative, parsed_any: False)
  }
}

fn parse_quadratic_bezier_loop(
  tokens: List(Token),
  state: State,
  relative: Bool,
  parsed_any parsed_any: Bool,
) -> Result(svg_path.Path, Error) {
  case tokens {
    [Number(_), ..] -> {
      case take_quadratic_bezier(tokens) {
        Error(error) -> Error(error)
        Ok(#(control_x, control_y, end_x, end_y, rest)) -> {
          let control = target_point(state, control_x, control_y, relative)
          let end = target_point(state, end_x, end_y, relative)
          let segment =
            svg_path.QuadraticBezier(start: state.current, control:, end:)

          case append_segment(state, segment, end) {
            Error(error) -> Error(error)
            Ok(state) -> {
              let state = remember_quadratic_control(state, control)
              parse_quadratic_bezier_loop(
                rest,
                state,
                relative,
                parsed_any: True,
              )
            }
          }
        }
      }
    }
    _ -> {
      case parsed_any {
        True -> parse_tokens(tokens, state)
        False -> Error(ExpectedNumber)
      }
    }
  }
}

fn parse_smooth_quadratic_bezier(
  tokens: List(Token),
  state: State,
  relative relative: Bool,
) -> Result(svg_path.Path, Error) {
  case ensure_active(state) {
    Error(error) -> Error(error)
    Ok(Nil) ->
      parse_smooth_quadratic_bezier_loop(
        tokens,
        state,
        relative,
        parsed_any: False,
      )
  }
}

fn parse_smooth_quadratic_bezier_loop(
  tokens: List(Token),
  state: State,
  relative: Bool,
  parsed_any parsed_any: Bool,
) -> Result(svg_path.Path, Error) {
  case tokens {
    [Number(_), ..] -> {
      case take_pair(tokens) {
        Error(error) -> Error(error)
        Ok(#(end_x, end_y, rest)) -> {
          let control = reflected_quadratic_control(state)
          let end = target_point(state, end_x, end_y, relative)
          let segment =
            svg_path.QuadraticBezier(start: state.current, control:, end:)

          case append_segment(state, segment, end) {
            Error(error) -> Error(error)
            Ok(state) -> {
              let state = remember_quadratic_control(state, control)
              parse_smooth_quadratic_bezier_loop(
                rest,
                state,
                relative,
                parsed_any: True,
              )
            }
          }
        }
      }
    }
    _ -> {
      case parsed_any {
        True -> parse_tokens(tokens, state)
        False -> Error(ExpectedNumber)
      }
    }
  }
}

fn parse_cubic_bezier(
  tokens: List(Token),
  state: State,
  relative relative: Bool,
) -> Result(svg_path.Path, Error) {
  case ensure_active(state) {
    Error(error) -> Error(error)
    Ok(Nil) ->
      parse_cubic_bezier_loop(tokens, state, relative, parsed_any: False)
  }
}

fn parse_cubic_bezier_loop(
  tokens: List(Token),
  state: State,
  relative: Bool,
  parsed_any parsed_any: Bool,
) -> Result(svg_path.Path, Error) {
  case tokens {
    [Number(_), ..] -> {
      case take_cubic_bezier(tokens) {
        Error(error) -> Error(error)
        Ok(#(control1_x, control1_y, control2_x, control2_y, end_x, end_y, rest)) -> {
          let control1 = target_point(state, control1_x, control1_y, relative)
          let control2 = target_point(state, control2_x, control2_y, relative)
          let end = target_point(state, end_x, end_y, relative)
          let segment =
            svg_path.CubicBezier(
              start: state.current,
              control1:,
              control2:,
              end:,
            )

          case append_segment(state, segment, end) {
            Error(error) -> Error(error)
            Ok(state) -> {
              let state = remember_cubic_control(state, control2)
              parse_cubic_bezier_loop(rest, state, relative, parsed_any: True)
            }
          }
        }
      }
    }
    _ -> {
      case parsed_any {
        True -> parse_tokens(tokens, state)
        False -> Error(ExpectedNumber)
      }
    }
  }
}

fn parse_smooth_cubic_bezier(
  tokens: List(Token),
  state: State,
  relative relative: Bool,
) -> Result(svg_path.Path, Error) {
  case ensure_active(state) {
    Error(error) -> Error(error)
    Ok(Nil) ->
      parse_smooth_cubic_bezier_loop(tokens, state, relative, parsed_any: False)
  }
}

fn parse_smooth_cubic_bezier_loop(
  tokens: List(Token),
  state: State,
  relative: Bool,
  parsed_any parsed_any: Bool,
) -> Result(svg_path.Path, Error) {
  case tokens {
    [Number(_), ..] -> {
      case take_smooth_cubic_bezier(tokens) {
        Error(error) -> Error(error)
        Ok(#(control2_x, control2_y, end_x, end_y, rest)) -> {
          let control1 = reflected_cubic_control(state)
          let control2 = target_point(state, control2_x, control2_y, relative)
          let end = target_point(state, end_x, end_y, relative)
          let segment =
            svg_path.CubicBezier(
              start: state.current,
              control1:,
              control2:,
              end:,
            )

          case append_segment(state, segment, end) {
            Error(error) -> Error(error)
            Ok(state) -> {
              let state = remember_cubic_control(state, control2)
              parse_smooth_cubic_bezier_loop(
                rest,
                state,
                relative,
                parsed_any: True,
              )
            }
          }
        }
      }
    }
    _ -> {
      case parsed_any {
        True -> parse_tokens(tokens, state)
        False -> Error(ExpectedNumber)
      }
    }
  }
}

fn parse_arc(
  tokens: List(Token),
  state: State,
  relative relative: Bool,
) -> Result(svg_path.Path, Error) {
  case ensure_active(state) {
    Error(error) -> Error(error)
    Ok(Nil) -> parse_arc_loop(tokens, state, relative, parsed_any: False)
  }
}

fn parse_arc_loop(
  tokens: List(Token),
  state: State,
  relative: Bool,
  parsed_any parsed_any: Bool,
) -> Result(svg_path.Path, Error) {
  case tokens {
    [Number(_), ..] -> {
      case take_arc(tokens) {
        Error(error) -> Error(error)
        Ok(#(
          radius_x,
          radius_y,
          x_axis_rotation,
          large_arc,
          sweep,
          end_x,
          end_y,
          rest,
        )) -> {
          let end = target_point(state, end_x, end_y, relative)
          let segment =
            svg_path.Arc(
              start: state.current,
              radius: svg_path.point(radius_x, radius_y),
              x_axis_rotation:,
              large_arc:,
              sweep:,
              end:,
            )

          case append_segment(state, segment, end) {
            Error(error) -> Error(error)
            Ok(state) -> parse_arc_loop(rest, state, relative, parsed_any: True)
          }
        }
      }
    }
    _ -> {
      case parsed_any {
        True -> parse_tokens(tokens, state)
        False -> Error(ExpectedNumber)
      }
    }
  }
}

fn parse_close(
  tokens: List(Token),
  state: State,
) -> Result(svg_path.Path, Error) {
  case ensure_active(state) {
    Error(error) -> Error(error)
    Ok(Nil) -> {
      let assert Ok(start) = svg_path.subpath_start(state.subpath)
      case
        svg_path.subpath_set_closed_with(
          state.subpath,
          closed: True,
          policy: svg_path.Bridge,
        )
      {
        Error(error) -> Error(Core(error))
        Ok(subpath) -> {
          parse_tokens(
            tokens,
            State(
              subpaths: [subpath, ..state.subpaths],
              subpath: svg_path.subpath_empty(at: start),
              current: start,
              has_current: True,
              active: False,
              last_cubic_control: None,
              last_quadratic_control: None,
            ),
          )
        }
      }
    }
  }
}

fn finish(state: State) -> Result(svg_path.Path, Error) {
  case finish_active_subpath(state) {
    Error(error) -> Error(error)
    Ok(state) -> Ok(svg_path.Path(list.reverse(state.subpaths)))
  }
}

fn finish_active_subpath(state: State) -> Result(State, Error) {
  case state.active {
    False -> Ok(state)
    True ->
      Ok(
        State(
          ..state,
          subpaths: [state.subpath, ..state.subpaths],
          subpath: svg_path.subpath_empty(at: state.current),
          active: False,
        ),
      )
  }
}

fn append_line_to(
  state: State,
  target: svg_path.Point,
) -> Result(State, Error) {
  append_segment(
    state,
    svg_path.Line(start: state.current, end: target),
    target,
  )
}

fn append_segment(
  state: State,
  segment: svg_path.Segment,
  end: svg_path.Point,
) -> Result(State, Error) {
  case svg_path.subpath_append_segment(state.subpath, segment) {
    Error(error) -> Error(Core(error))
    Ok(subpath) -> {
      Ok(
        State(..state, subpath: subpath, current: end, active: True)
        |> clear_curve_controls,
      )
    }
  }
}

fn clear_curve_controls(state: State) -> State {
  State(..state, last_cubic_control: None, last_quadratic_control: None)
}

fn remember_cubic_control(state: State, control: svg_path.Point) -> State {
  State(
    ..state,
    last_cubic_control: Some(control),
    last_quadratic_control: None,
  )
}

fn remember_quadratic_control(state: State, control: svg_path.Point) -> State {
  State(
    ..state,
    last_cubic_control: None,
    last_quadratic_control: Some(control),
  )
}

fn reflected_cubic_control(state: State) -> svg_path.Point {
  case state.last_cubic_control {
    Some(control) -> reflect(control, around: state.current)
    None -> state.current
  }
}

fn reflected_quadratic_control(state: State) -> svg_path.Point {
  case state.last_quadratic_control {
    Some(control) -> reflect(control, around: state.current)
    None -> state.current
  }
}

fn reflect(
  point: svg_path.Point,
  around origin: svg_path.Point,
) -> svg_path.Point {
  svg_path.point(origin.x *. 2.0 -. point.x, origin.y *. 2.0 -. point.y)
}

fn ensure_active(state: State) -> Result(Nil, Error) {
  case state.active && state.has_current {
    True -> Ok(Nil)
    False -> Error(ExpectedMove)
  }
}

fn target_point(
  state: State,
  x: Float,
  y: Float,
  relative: Bool,
) -> svg_path.Point {
  case relative {
    True -> offset(state.current, x, y)
    False -> svg_path.point(x, y)
  }
}

fn offset(point: svg_path.Point, x: Float, y: Float) -> svg_path.Point {
  svg_path.point(point.x +. x, point.y +. y)
}

fn take_pair(
  tokens: List(Token),
) -> Result(#(Float, Float, List(Token)), Error) {
  case tokens {
    [Number(x), Number(y), ..rest] -> Ok(#(x, y, rest))
    _ -> Error(ExpectedNumber)
  }
}

fn take_quadratic_bezier(
  tokens: List(Token),
) -> Result(#(Float, Float, Float, Float, List(Token)), Error) {
  case tokens {
    [Number(control_x), Number(control_y), Number(end_x), Number(end_y), ..rest] -> {
      Ok(#(control_x, control_y, end_x, end_y, rest))
    }
    _ -> Error(ExpectedNumber)
  }
}

fn take_cubic_bezier(
  tokens: List(Token),
) -> Result(#(Float, Float, Float, Float, Float, Float, List(Token)), Error) {
  case tokens {
    [
      Number(control1_x),
      Number(control1_y),
      Number(control2_x),
      Number(control2_y),
      Number(end_x),
      Number(end_y),
      ..rest
    ] -> {
      Ok(#(control1_x, control1_y, control2_x, control2_y, end_x, end_y, rest))
    }
    _ -> Error(ExpectedNumber)
  }
}

fn take_smooth_cubic_bezier(
  tokens: List(Token),
) -> Result(#(Float, Float, Float, Float, List(Token)), Error) {
  case tokens {
    [
      Number(control2_x),
      Number(control2_y),
      Number(end_x),
      Number(end_y),
      ..rest
    ] -> {
      Ok(#(control2_x, control2_y, end_x, end_y, rest))
    }
    _ -> Error(ExpectedNumber)
  }
}

fn take_arc(
  tokens: List(Token),
) -> Result(
  #(Float, Float, Float, Bool, Bool, Float, Float, List(Token)),
  Error,
) {
  case tokens {
    [
      Number(radius_x),
      Number(radius_y),
      Number(x_axis_rotation),
      Number(large_arc),
      Number(sweep),
      Number(end_x),
      Number(end_y),
      ..rest
    ] -> {
      case arc_flag(large_arc) {
        Error(error) -> Error(error)
        Ok(large_arc) -> {
          case arc_flag(sweep) {
            Error(error) -> Error(error)
            Ok(sweep) -> {
              Ok(#(
                radius_x,
                radius_y,
                x_axis_rotation,
                large_arc,
                sweep,
                end_x,
                end_y,
                rest,
              ))
            }
          }
        }
      }
    }
    _ -> Error(ExpectedNumber)
  }
}

fn arc_flag(value: Float) -> Result(Bool, Error) {
  case value {
    0.0 -> Ok(False)
    1.0 -> Ok(True)
    _ -> Error(ExpectedArcFlag)
  }
}

fn tokenize(input: String) -> Result(List(Token), Error) {
  input
  |> string.to_graphemes
  |> tokenize_loop([])
}

fn tokenize_loop(
  graphemes: List(String),
  tokens: List(Token),
) -> Result(List(Token), Error) {
  case graphemes {
    [] -> Ok(list.reverse(tokens))
    [grapheme, ..rest] -> {
      case is_separator(grapheme) {
        True -> tokenize_loop(rest, tokens)
        False -> {
          case is_command(grapheme) {
            True -> tokenize_loop(rest, [Command(grapheme), ..tokens])
            False -> {
              case is_number_start(grapheme) {
                True -> {
                  let #(raw, rest) =
                    read_number(graphemes, [], previous_was_exponent: False)

                  case parse_number(raw) {
                    Ok(number) ->
                      tokenize_loop(rest, [Number(number), ..tokens])
                    Error(_) -> Error(InvalidNumber(raw))
                  }
                }
                False -> Error(UnsupportedCommand(grapheme))
              }
            }
          }
        }
      }
    }
  }
}

fn read_number(
  graphemes: List(String),
  number: List(String),
  previous_was_exponent previous_was_exponent: Bool,
) -> #(String, List(String)) {
  case graphemes {
    [] -> #(string.join(list.reverse(number), ""), [])
    [grapheme, ..rest] -> {
      case is_digit(grapheme) || grapheme == "." {
        True ->
          read_number(rest, [grapheme, ..number], previous_was_exponent: False)
        False -> {
          case grapheme == "e" || grapheme == "E" {
            True ->
              read_number(
                rest,
                [grapheme, ..number],
                previous_was_exponent: True,
              )
            False -> {
              case
                { previous_was_exponent || list.is_empty(number) }
                && { grapheme == "+" || grapheme == "-" }
              {
                True ->
                  read_number(
                    rest,
                    [grapheme, ..number],
                    previous_was_exponent: False,
                  )
                False -> #(string.join(list.reverse(number), ""), graphemes)
              }
            }
          }
        }
      }
    }
  }
}

fn is_separator(grapheme: String) -> Bool {
  grapheme == " "
  || grapheme == "\n"
  || grapheme == "\r"
  || grapheme == "\t"
  || grapheme == ","
}

fn is_command(grapheme: String) -> Bool {
  list.contains(
    [
      "M",
      "m",
      "L",
      "l",
      "Q",
      "q",
      "T",
      "t",
      "C",
      "c",
      "S",
      "s",
      "A",
      "a",
      "H",
      "h",
      "V",
      "v",
      "Z",
      "z",
    ],
    grapheme,
  )
}

fn is_number_start(grapheme: String) -> Bool {
  is_digit(grapheme) || grapheme == "+" || grapheme == "-" || grapheme == "."
}

fn is_digit(grapheme: String) -> Bool {
  list.contains(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"], grapheme)
}

fn parse_number(raw: String) -> Result(Float, Nil) {
  case string.split_once(raw, on: "e") {
    Ok(#(mantissa, exponent)) -> parse_exponent_number(mantissa, exponent)
    Error(_) -> {
      case string.split_once(raw, on: "E") {
        Ok(#(mantissa, exponent)) -> parse_exponent_number(mantissa, exponent)
        Error(_) -> parse_decimal_number(raw)
      }
    }
  }
}

fn parse_decimal_number(raw: String) -> Result(Float, Nil) {
  let raw = strip_leading_plus(raw)

  case float.parse(raw) {
    Ok(number) -> Ok(number)
    Error(_) -> {
      case int.parse(raw) {
        Ok(number) -> Ok(int.to_float(number))
        Error(_) -> Error(Nil)
      }
    }
  }
}

fn parse_exponent_number(
  mantissa: String,
  exponent: String,
) -> Result(Float, Nil) {
  case parse_decimal_number(mantissa) {
    Error(_) -> Error(Nil)
    Ok(mantissa) -> {
      case exponent |> strip_leading_plus |> int.parse {
        Error(_) -> Error(Nil)
        Ok(exponent) -> Ok(mantissa *. power_of_ten(exponent))
      }
    }
  }
}

fn strip_leading_plus(raw: String) -> String {
  case string.starts_with(raw, "+") {
    True -> string.drop_start(raw, up_to: 1)
    False -> raw
  }
}

fn power_of_ten(exponent: Int) -> Float {
  case exponent {
    0 -> 1.0
    _ if exponent > 0 -> 10.0 *. power_of_ten(exponent - 1)
    _ -> power_of_ten(exponent + 1) /. 10.0
  }
}
