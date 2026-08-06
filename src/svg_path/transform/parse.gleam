//// SVG transform attribute parser.
////
//// This module parses SVG transform lists such as
//// `translate(10 20)rotate(30)scale(2)`. Commas are accepted where SVG allows
//// separators, and adjacent signed numbers such as `translate(10-20)` are
//// handled.

import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import svg_path/transform

/// Errors returned while parsing an SVG transform attribute.
pub type Error {
  /// Parsing failed for `reason` at the start of `remaining`.
  ///
  /// `remaining` is the exact suffix of the original input beginning at the
  /// failure location. It is empty when the failure is at end of input. A
  /// UTF-8 byte offset can be recovered by subtracting the byte size of
  /// `remaining` from the byte size of the original input.
  ParseError(reason: ErrorReason, remaining: String)
}

/// The reason SVG transform parsing failed.
pub type ErrorReason {
  /// A closing parenthesis was expected.
  ExpectedClose

  /// An opening parenthesis was expected.
  ExpectedOpen

  /// A transform function name was expected.
  ExpectedTransform

  /// A transform function received the wrong number of arguments.
  InvalidArgumentCount(String, Int)

  /// A numeric token could not be parsed as a float.
  InvalidNumber(String)

  /// A token appeared where it is not valid.
  UnexpectedToken(String)

  /// The transform function is not part of SVG's supported transform set.
  UnknownTransform(String)
}

type Token {
  Close(at: Int)
  Name(String, at: Int)
  Number(Float, at: Int)
  Open(at: Int)
}

type LocatedError {
  LocatedError(reason: ErrorReason, at: Int)
}

/// Parse an SVG transform attribute into a matrix.
///
/// Empty strings parse as the identity matrix.
pub fn attribute(input: String) -> Result(transform.Matrix, Error) {
  case tokenize(input) {
    Error(error) -> Error(public_error(input, error))
    Ok(tokens) ->
      parse_transforms(tokens, transform.identity(), string.length(input))
      |> result.map_error(public_error(input, _))
  }
}

fn public_error(input: String, error: LocatedError) -> Error {
  let LocatedError(reason:, at:) = error
  ParseError(reason:, remaining: string.drop_start(input, up_to: at))
}

fn parse_transforms(
  tokens: List(Token),
  accumulated: transform.Matrix,
  end_at: Int,
) -> Result(transform.Matrix, LocatedError) {
  case tokens {
    [] -> Ok(accumulated)
    [Name(name, name_at), Open(_), ..rest] -> {
      case take_arguments(rest, [], end_at) {
        Error(error) -> Error(error)
        Ok(#(arguments, rest)) -> {
          case transform_from_arguments(name, arguments, at: name_at) {
            Error(error) -> Error(error)
            Ok(next) -> {
              parse_transforms(
                rest,
                transform.chain(first: next, then: accumulated),
                end_at,
              )
            }
          }
        }
      }
    }
    [Name(_, _), ..rest] ->
      Error(LocatedError(ExpectedOpen, token_at(rest, or: end_at)))
    [Open(at), ..] | [Close(at), ..] | [Number(_, at), ..] ->
      Error(LocatedError(ExpectedTransform, at))
  }
}

fn take_arguments(
  tokens: List(Token),
  arguments: List(Float),
  end_at: Int,
) -> Result(#(List(Float), List(Token)), LocatedError) {
  case tokens {
    [] -> Error(LocatedError(ExpectedClose, end_at))
    [Close(_), ..rest] -> Ok(#(list.reverse(arguments), rest))
    [Number(number, _), ..rest] ->
      take_arguments(rest, [number, ..arguments], end_at)
    [Name(name, at), ..] -> Error(LocatedError(UnexpectedToken(name), at))
    [Open(at), ..] -> Error(LocatedError(UnexpectedToken("("), at))
  }
}

fn token_at(tokens: List(Token), or fallback: Int) -> Int {
  case tokens {
    [] -> fallback
    [Close(at), ..]
    | [Name(_, at), ..]
    | [Number(_, at), ..]
    | [Open(at), ..] -> at
  }
}

fn transform_from_arguments(
  name: String,
  arguments: List(Float),
  at at: Int,
) -> Result(transform.Matrix, LocatedError) {
  case name {
    "matrix" -> matrix_transform(name, arguments, at:)
    "translate" -> translate_transform(name, arguments, at:)
    "scale" -> scale_transform(name, arguments, at:)
    "rotate" -> rotate_transform(name, arguments, at:)
    "skewX" -> skew_x_transform(name, arguments, at:)
    "skewY" -> skew_y_transform(name, arguments, at:)
    _ -> Error(LocatedError(UnknownTransform(name), at))
  }
}

fn matrix_transform(
  name: String,
  arguments: List(Float),
  at at: Int,
) -> Result(transform.Matrix, LocatedError) {
  case arguments {
    [a, b, c, d, e, f] -> Ok(transform.matrix(a:, b:, c:, d:, e:, f:))
    _ ->
      Error(LocatedError(InvalidArgumentCount(name, list.length(arguments)), at))
  }
}

fn translate_transform(
  name: String,
  arguments: List(Float),
  at at: Int,
) -> Result(transform.Matrix, LocatedError) {
  case arguments {
    [x] -> Ok(transform.translate(x:, y: 0.0))
    [x, y] -> Ok(transform.translate(x:, y:))
    _ ->
      Error(LocatedError(InvalidArgumentCount(name, list.length(arguments)), at))
  }
}

fn scale_transform(
  name: String,
  arguments: List(Float),
  at at: Int,
) -> Result(transform.Matrix, LocatedError) {
  case arguments {
    [factor] -> Ok(transform.scale(factor:))
    [x, y] -> Ok(transform.scale_xy(x:, y:))
    _ ->
      Error(LocatedError(InvalidArgumentCount(name, list.length(arguments)), at))
  }
}

fn rotate_transform(
  name: String,
  arguments: List(Float),
  at at: Int,
) -> Result(transform.Matrix, LocatedError) {
  case arguments {
    [degrees] -> Ok(transform.rotate(degrees:))
    [degrees, cx, cy] -> {
      let move_to_origin = transform.translate(x: 0.0 -. cx, y: 0.0 -. cy)
      let rotate = transform.rotate(degrees:)
      let move_back = transform.translate(x: cx, y: cy)

      Ok(
        move_to_origin
        |> transform.chain(first: _, then: rotate)
        |> transform.chain(first: _, then: move_back),
      )
    }
    _ ->
      Error(LocatedError(InvalidArgumentCount(name, list.length(arguments)), at))
  }
}

fn skew_x_transform(
  name: String,
  arguments: List(Float),
  at at: Int,
) -> Result(transform.Matrix, LocatedError) {
  case arguments {
    [degrees] -> Ok(transform.skew_x(degrees:))
    _ ->
      Error(LocatedError(InvalidArgumentCount(name, list.length(arguments)), at))
  }
}

fn skew_y_transform(
  name: String,
  arguments: List(Float),
  at at: Int,
) -> Result(transform.Matrix, LocatedError) {
  case arguments {
    [degrees] -> Ok(transform.skew_y(degrees:))
    _ ->
      Error(LocatedError(InvalidArgumentCount(name, list.length(arguments)), at))
  }
}

fn tokenize(input: String) -> Result(List(Token), LocatedError) {
  input
  |> string.to_graphemes
  |> tokenize_loop([], at: 0)
}

fn tokenize_loop(
  graphemes: List(String),
  tokens: List(Token),
  at at: Int,
) -> Result(List(Token), LocatedError) {
  case graphemes {
    [] -> Ok(list.reverse(tokens))
    [grapheme, ..rest] -> {
      case is_separator(grapheme) {
        True -> tokenize_loop(rest, tokens, at: at + 1)
        False -> {
          case grapheme {
            "(" -> tokenize_loop(rest, [Open(at), ..tokens], at: at + 1)
            ")" -> tokenize_loop(rest, [Close(at), ..tokens], at: at + 1)
            _ -> {
              case is_name_start(grapheme) {
                True -> {
                  let #(name, rest) = read_name(graphemes, [])
                  tokenize_loop(
                    rest,
                    [Name(name, at), ..tokens],
                    at: at + string.length(name),
                  )
                }
                False -> {
                  case is_number_start(grapheme) {
                    True -> {
                      let #(raw, rest) =
                        read_number(graphemes, [], previous_was_exponent: False)

                      case parse_number(raw) {
                        Ok(number) ->
                          tokenize_loop(
                            rest,
                            [Number(number, at), ..tokens],
                            at: at + string.length(raw),
                          )
                        Error(_) -> Error(LocatedError(InvalidNumber(raw), at))
                      }
                    }
                    False -> Error(LocatedError(UnexpectedToken(grapheme), at))
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
