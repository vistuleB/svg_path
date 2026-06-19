import gleam/float
import gleam/int
import gleam/list
import gleam/string
import svg_path/transform

pub type Error {
  ExpectedClose
  ExpectedOpen
  ExpectedTransform
  InvalidArgumentCount(String, Int)
  InvalidNumber(String)
  UnexpectedToken(String)
  UnknownTransform(String)
}

type Token {
  Close
  Name(String)
  Number(Float)
  Open
}

pub fn attribute(input: String) -> Result(transform.Matrix, Error) {
  case tokenize(input) {
    Error(error) -> Error(error)
    Ok(tokens) -> parse_transforms(tokens, transform.identity())
  }
}

fn parse_transforms(
  tokens: List(Token),
  accumulated: transform.Matrix,
) -> Result(transform.Matrix, Error) {
  case tokens {
    [] -> Ok(accumulated)
    [Name(name), Open, ..rest] -> {
      case take_arguments(rest, []) {
        Error(error) -> Error(error)
        Ok(#(arguments, rest)) -> {
          case transform_from_arguments(name, arguments) {
            Error(error) -> Error(error)
            Ok(next) -> {
              parse_transforms(
                rest,
                transform.compose(first: next, then: accumulated),
              )
            }
          }
        }
      }
    }
    [Name(_), ..] -> Error(ExpectedOpen)
    [Open, ..] | [Close, ..] | [Number(_), ..] -> Error(ExpectedTransform)
  }
}

fn take_arguments(
  tokens: List(Token),
  arguments: List(Float),
) -> Result(#(List(Float), List(Token)), Error) {
  case tokens {
    [] -> Error(ExpectedClose)
    [Close, ..rest] -> Ok(#(list.reverse(arguments), rest))
    [Number(number), ..rest] -> take_arguments(rest, [number, ..arguments])
    [Name(name), ..] -> Error(UnexpectedToken(name))
    [Open, ..] -> Error(UnexpectedToken("("))
  }
}

fn transform_from_arguments(
  name: String,
  arguments: List(Float),
) -> Result(transform.Matrix, Error) {
  case name {
    "matrix" -> matrix_transform(name, arguments)
    "translate" -> translate_transform(name, arguments)
    "scale" -> scale_transform(name, arguments)
    "rotate" -> rotate_transform(name, arguments)
    "skewX" -> skew_x_transform(name, arguments)
    "skewY" -> skew_y_transform(name, arguments)
    _ -> Error(UnknownTransform(name))
  }
}

fn matrix_transform(
  name: String,
  arguments: List(Float),
) -> Result(transform.Matrix, Error) {
  case arguments {
    [a, b, c, d, e, f] -> Ok(transform.matrix(a:, b:, c:, d:, e:, f:))
    _ -> Error(InvalidArgumentCount(name, list.length(arguments)))
  }
}

fn translate_transform(
  name: String,
  arguments: List(Float),
) -> Result(transform.Matrix, Error) {
  case arguments {
    [x] -> Ok(transform.translate(x:, y: 0.0))
    [x, y] -> Ok(transform.translate(x:, y:))
    _ -> Error(InvalidArgumentCount(name, list.length(arguments)))
  }
}

fn scale_transform(
  name: String,
  arguments: List(Float),
) -> Result(transform.Matrix, Error) {
  case arguments {
    [factor] -> Ok(transform.scale(factor:))
    [x, y] -> Ok(transform.scale_xy(x:, y:))
    _ -> Error(InvalidArgumentCount(name, list.length(arguments)))
  }
}

fn rotate_transform(
  name: String,
  arguments: List(Float),
) -> Result(transform.Matrix, Error) {
  case arguments {
    [degrees] -> Ok(transform.rotate(degrees:))
    [degrees, cx, cy] -> {
      let move_to_origin = transform.translate(x: 0.0 -. cx, y: 0.0 -. cy)
      let rotate = transform.rotate(degrees:)
      let move_back = transform.translate(x: cx, y: cy)

      Ok(
        move_to_origin
        |> transform.compose(first: _, then: rotate)
        |> transform.compose(first: _, then: move_back),
      )
    }
    _ -> Error(InvalidArgumentCount(name, list.length(arguments)))
  }
}

fn skew_x_transform(
  name: String,
  arguments: List(Float),
) -> Result(transform.Matrix, Error) {
  case arguments {
    [degrees] -> Ok(transform.skew_x(degrees:))
    _ -> Error(InvalidArgumentCount(name, list.length(arguments)))
  }
}

fn skew_y_transform(
  name: String,
  arguments: List(Float),
) -> Result(transform.Matrix, Error) {
  case arguments {
    [degrees] -> Ok(transform.skew_y(degrees:))
    _ -> Error(InvalidArgumentCount(name, list.length(arguments)))
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
          case grapheme {
            "(" -> tokenize_loop(rest, [Open, ..tokens])
            ")" -> tokenize_loop(rest, [Close, ..tokens])
            _ -> {
              case is_name_start(grapheme) {
                True -> {
                  let #(name, rest) = read_name(graphemes, [])
                  tokenize_loop(rest, [Name(name), ..tokens])
                }
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
                    False -> Error(UnexpectedToken(grapheme))
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

fn read_name(
  graphemes: List(String),
  name: List(String),
) -> #(String, List(String)) {
  case graphemes {
    [] -> #(string.join(list.reverse(name), ""), [])
    [grapheme, ..rest] -> {
      case is_name_part(grapheme) {
        True -> read_name(rest, [grapheme, ..name])
        False -> #(string.join(list.reverse(name), ""), graphemes)
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

fn is_name_start(grapheme: String) -> Bool {
  is_ascii_letter(grapheme)
}

fn is_name_part(grapheme: String) -> Bool {
  is_ascii_letter(grapheme)
}

fn is_ascii_letter(grapheme: String) -> Bool {
  list.contains(
    [
      "A",
      "B",
      "C",
      "D",
      "E",
      "F",
      "G",
      "H",
      "I",
      "J",
      "K",
      "L",
      "M",
      "N",
      "O",
      "P",
      "Q",
      "R",
      "S",
      "T",
      "U",
      "V",
      "W",
      "X",
      "Y",
      "Z",
      "a",
      "b",
      "c",
      "d",
      "e",
      "f",
      "g",
      "h",
      "i",
      "j",
      "k",
      "l",
      "m",
      "n",
      "o",
      "p",
      "q",
      "r",
      "s",
      "t",
      "u",
      "v",
      "w",
      "x",
      "y",
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
  let raw = normalize_decimal(raw)

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

fn normalize_decimal(raw: String) -> String {
  case string.starts_with(raw, ".") {
    True -> "0" <> raw
    False -> {
      case string.starts_with(raw, "+.") {
        True -> "0" <> string.drop_start(raw, up_to: 1)
        False -> {
          case string.starts_with(raw, "-.") {
            True -> "-0" <> string.drop_start(raw, up_to: 1)
            False -> strip_leading_plus(raw)
          }
        }
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
