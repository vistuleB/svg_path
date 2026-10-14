import gleam/int
import gleam/list
import gleam/string
import svg_path
import svg_path/parse

// Implicit repetitions exercise the tokenizer without the separate command
// dispatch recursion. Check every segment, including token order and signs.
pub fn long_implicit_line_arguments_test() {
  let input = "M0 0h" <> string.repeat("1,-2,3,", times: 2500) <> "4"
  let assert Ok(path) = parse.path(input)
  let assert Ok(subpath) = svg_path.path_as_subpath(path)
  let segments = svg_path.subpath_segments(subpath)
  assert list.length(segments) == 7501
  list.each(
    list.index_map(segments, fn(segment, i) { #(i, segment) }),
    fn(entry) {
      let #(i, segment) = entry
      let group = i / 3
      let start = case i % 3 {
        0 -> group * 2
        1 -> group * 2 + 1
        _ -> group * 2 - 1
      }
      let delta = case i == 7500, i % 3 {
        True, _ -> 4
        False, 0 -> 1
        False, 1 -> -2
        _, _ -> 3
      }
      assert segment
        == svg_path.Line(
          svg_path.Point(int.to_float(start), 0.0),
          svg_path.Point(int.to_float(start + delta), 0.0),
        )
    },
  )
}

// The public parser tokenizes the complete input before validating commands.
// Starting with L deliberately isolates successful tokenization of many explicit
// commands from the still-recursive command dispatcher.
pub fn many_command_tokens_reach_command_validation_test() {
  let input = "L0 0 " <> string.repeat("L1 2 ", times: 10_000)
  assert parse.path(input) == Error(parse.ParseError(parse.ExpectedMove, input))
}

pub fn late_token_errors_preserve_suffix_test() {
  let prefix = "M0 0 " <> string.repeat("L1,2 ", times: 10_000)
  list.each(
    [
      #("@tail", parse.UnsupportedCommand("@")),
      #("1e+ tail", parse.InvalidNumber("1e+")),
      #(",,1", parse.InvalidSeparator),
    ],
    fn(pair) {
      let #(suffix, reason) = pair
      assert parse.path(prefix <> suffix)
        == Error(parse.ParseError(reason, suffix))
    },
  )
}

pub fn compact_arc_flags_and_repetitions_reach_late_error_test() {
  // Both flags must consume one digit, then signed coordinates and a repeated
  // arc reset the argument position. Commands reset that position as well.
  let prefix =
    "M0 0 "
    <> string.repeat(
      "A1,2,3,0110-20 4,5,6,10-7-8 L1,2 a1 2 3 014-5 ",
      times: 1000,
    )
  assert parse.path(prefix <> "?")
    == Error(parse.ParseError(parse.UnsupportedCommand("?"), "?"))
}

pub fn compact_arc_tokens_preserve_geometry_test() {
  let assert Ok(expected) =
    parse.path(
      "M 0 0 A 1 2 3 0 1 10 -20 4 5 6 1 0 -7 -8 L 1 2 a 1 2 3 0 1 4 -5",
    )
  assert parse.path("M0,0A1,2,3,0110-20 4,5,6,10-7-8L1,2a1 2 3 014-5")
    == Ok(expected)
}
