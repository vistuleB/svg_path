import gleam/float
import gleam/int
import gleam/list
import gleam/string
import svg_path

pub type Error {
  Core(svg_path.Error)
  ExpectedCommand
  ExpectedMove
  ExpectedNumber
  InvalidNumber(String)
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
  )
}

pub fn path(input: String) -> Result(svg_path.Path, Error) {
  case tokenize(input) {
    Error(error) -> Error(error)
    Ok(tokens) -> parse_tokens(tokens, initial_state())
  }
}

fn initial_state() -> State {
  State(
    subpaths: [],
    subpath: svg_path.empty_subpath(),
    current: svg_path.point(0.0, 0.0),
    has_current: False,
    active: False,
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
              subpath: svg_path.empty_subpath(),
              current: target,
              has_current: True,
              active: True,
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

fn parse_close(
  tokens: List(Token),
  state: State,
) -> Result(svg_path.Path, Error) {
  case ensure_active(state) {
    Error(error) -> Error(error)
    Ok(Nil) -> {
      case svg_path.start(state.subpath) {
        Error(_) -> parse_tokens(tokens, State(..state, active: False))
        Ok(start) -> {
          case svg_path.force_close(state.subpath) {
            Error(error) -> Error(Core(error))
            Ok(subpath) -> {
              parse_tokens(
                tokens,
                State(
                  subpaths: [subpath, ..state.subpaths],
                  subpath: svg_path.empty_subpath(),
                  current: start,
                  has_current: True,
                  active: False,
                ),
              )
            }
          }
        }
      }
    }
  }
}

fn finish(state: State) -> Result(svg_path.Path, Error) {
  case finish_active_subpath(state) {
    Error(error) -> Error(error)
    Ok(state) -> Ok(svg_path.path(list.reverse(state.subpaths)))
  }
}

fn finish_active_subpath(state: State) -> Result(State, Error) {
  case state.active {
    False -> Ok(state)
    True -> {
      case subpath_is_empty(state.subpath) {
        True -> Ok(State(..state, active: False))
        False -> {
          Ok(
            State(
              ..state,
              subpaths: [state.subpath, ..state.subpaths],
              subpath: svg_path.empty_subpath(),
              active: False,
            ),
          )
        }
      }
    }
  }
}

fn append_line_to(
  state: State,
  target: svg_path.Point,
) -> Result(State, Error) {
  case
    svg_path.append(
      state.subpath,
      svg_path.line(start: state.current, end: target),
    )
  {
    Error(error) -> Error(Core(error))
    Ok(subpath) -> {
      Ok(State(..state, subpath: subpath, current: target, active: True))
    }
  }
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

fn subpath_is_empty(subpath: svg_path.Subpath) -> Bool {
  list.is_empty(svg_path.segments(subpath))
}

fn take_pair(
  tokens: List(Token),
) -> Result(#(Float, Float, List(Token)), Error) {
  case tokens {
    [Number(x), Number(y), ..rest] -> Ok(#(x, y, rest))
    _ -> Error(ExpectedNumber)
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
  list.contains(["M", "m", "L", "l", "H", "h", "V", "v", "Z", "z"], grapheme)
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
