import gleam/list
import gleam/string
import gleeunit
import svg_path
import svg_path/parse
import svg_path/serialize

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn empty_string_parses_as_empty_path_test() {
  assert parse.path("") == Ok(svg_path.path_empty())
}

pub fn absolute_lines_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 L 10 0 V 20 H 0")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 H 10 V 20 H 0"
}

pub fn relative_lines_parse_to_absolute_segments_test() {
  let assert Ok(path) = parse.path("m 10 10 l 5 0 v 20 h -5")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 10 10 H 15 V 30 H 10"
}

pub fn relative_move_after_close_uses_closed_subpath_start_test() {
  let assert Ok(path) = parse.path("M 0 0 L 10 0 z m 5 5 l 5 0")

  assert serialize.path(path) == "M 0 0 H 10 Z M 5 5 H 10"
}

pub fn repeated_line_horizontal_and_vertical_values_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 L 10 0 10 10 H 5 0 V 5 0")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 H 10 V 10 H 5 H 0 V 5 V 0"
}

pub fn repeated_absolute_line_coordinate_pairs_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 L 5 10 3 2 4 5 2 2 V 3")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 L 5 10 L 3 2 L 4 5 L 2 2 V 3"
}

pub fn repeated_relative_line_coordinate_pairs_parse_test() {
  let assert Ok(path) = parse.path("m 0 0 l 5 10 3 2 4 5 2 2 v 3")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath)
    == "M 0 0 L 5 10 L 8 12 L 12 17 L 14 19 V 22"
}

pub fn repeated_line_pairs_can_switch_to_horizontal_command_test() {
  let assert Ok(path) = parse.path("M 1 1 L 5 10 3 2 4 5 H 9")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 1 1 L 5 10 L 3 2 L 4 5 H 9"
}

pub fn absolute_quadratic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 Q 10 20 30 40")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 Q 10 20 30 40"
}

pub fn relative_quadratic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 10 10 q 5 10 20 30")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 10 10 Q 15 20 30 40"
}

pub fn repeated_quadratic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 Q 10 20 30 40 50 60 70 80")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 Q 10 20 30 40 T 70 80"
}

pub fn absolute_smooth_quadratic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 Q 10 20 30 40 T 50 60")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 Q 10 20 30 40 T 50 60"
}

pub fn relative_smooth_quadratic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 10 10 q 5 10 20 30 t 20 20")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 10 10 Q 15 20 30 40 T 50 60"
}

pub fn repeated_smooth_quadratic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 Q 10 20 30 40 T 50 60 70 80")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 Q 10 20 30 40 T 50 60 T 70 80"
}

pub fn smooth_quadratic_without_previous_quadratic_uses_current_point_test() {
  let assert Ok(path) = parse.path("M 0 0 L 5 5 T 10 10")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 L 5 5 T 10 10"
}

pub fn absolute_cubic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 C 10 20 30 40 50 60")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 C 10 20 30 40 50 60"
}

pub fn relative_cubic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 10 10 c 1 2 3 4 5 6")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 10 10 C 11 12 13 14 15 16"
}

pub fn repeated_cubic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 C 1 2 3 4 5 6 7 8 9 10 11 12")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 C 1 2 3 4 5 6 S 9 10 11 12"
}

pub fn absolute_smooth_cubic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 C 1 2 3 4 5 6 S 9 10 11 12")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 C 1 2 3 4 5 6 S 9 10 11 12"
}

pub fn relative_smooth_cubic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 10 10 c 1 2 3 4 5 6 s 4 4 6 6")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath)
    == "M 10 10 C 11 12 13 14 15 16 S 19 20 21 22"
}

pub fn repeated_smooth_cubic_beziers_parse_test() {
  let assert Ok(path) =
    parse.path("M 0 0 C 1 2 3 4 5 6 S 9 10 11 12 15 16 17 18")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath)
    == "M 0 0 C 1 2 3 4 5 6 S 9 10 11 12 S 15 16 17 18"
}

pub fn smooth_cubic_without_previous_cubic_uses_current_point_test() {
  let assert Ok(path) = parse.path("M 0 0 L 5 5 S 10 10 15 15")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 L 5 5 S 10 10 15 15"
}

pub fn absolute_arcs_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 A 5 10 30 0 1 20 40")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 A 5 10 30 0 1 20 40"
}

pub fn relative_arcs_parse_test() {
  let assert Ok(path) = parse.path("M 10 10 a 5 10 30 1 0 20 40")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 10 10 A 5 10 30 1 0 30 50"
}

pub fn repeated_arcs_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 A 5 10 30 0 1 20 40 7 8 45 1 0 30 50")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath)
    == "M 0 0 A 5 10 30 0 1 20 40 A 7 8 45 1 0 30 50"
}

pub fn repeated_move_coordinates_become_implicit_lines_test() {
  let assert Ok(path) = parse.path("M0 0 10 0 10 20")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 H 10 V 20"
}

pub fn relative_move_implicit_lines_stay_relative_test() {
  let assert Ok(path) = parse.path("m 10 10 5 0 0 5")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 10 10 H 15 V 15"
}

pub fn closepath_adds_closing_line_and_semantic_close_test() {
  let assert Ok(path) = parse.path("M 0 0 L 10 0 z")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert svg_path.subpath_is_closed(subpath)
  assert serialize.subpath(subpath) == "M 0 0 H 10 Z"
}

pub fn closepath_and_explicit_line_home_parse_to_same_subpath_test() {
  let assert Ok(direct_path) = parse.path("M 0 0 L 10 0 Z")
  let assert Ok(explicit_path) = parse.path("M 0 0 L 10 0 L 0 0 Z")
  let assert Ok(direct_subpath) = svg_path.path_as_subpath(direct_path)
  let assert Ok(explicit_subpath) = svg_path.path_as_subpath(explicit_path)

  assert direct_subpath == explicit_subpath
  assert serialize.subpath(direct_subpath) == "M 0 0 H 10 Z"
}

pub fn compact_numbers_parse_test() {
  let assert Ok(path) = parse.path("M0-1L10-1V9")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 -1 H 10 V 9"
}

pub fn comma_separated_coordinate_pairs_parse_test() {
  let assert Ok(path) = parse.path("M0,0 L10,20 30,40")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 L 10 20 L 30 40"
}

pub fn commas_parse_between_curve_coordinates_test() {
  let assert Ok(path) = parse.path("M0,0 C1,2,3,4,5,6 Q7,8,9,10")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 C 1 2 3 4 5 6 Q 7 8 9 10"
}

pub fn commas_parse_between_arc_arguments_test() {
  let assert Ok(path) = parse.path("M0,0 A25,50 -30 0,1 50,-25")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 A 25 50 -30 0 1 50 -25"
}

pub fn exponent_and_plus_signed_numbers_parse_test() {
  let assert Ok(path) = parse.path("M +1e1 -2E1 L 1.5e1 -2e1")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 10 -20 H 15"
}

pub fn overflowing_path_number_is_rejected_test() {
  assert parse.path("M 1e400 0")
    == Error(parse.ParseError(parse.InvalidNumber("1e400"), "1e400 0"))
}

pub fn path_exponent_scaling_preserves_finite_compensated_values_test() {
  let assert Ok(_) = parse.path("M 0.1e309 0")
}

pub fn overflowing_path_integer_syntax_is_rejected_test() {
  let input = "M " <> string.repeat("9", times: 400) <> " 0"
  let assert Error(_) = parse.path(input)
}

pub fn large_path_exponents_do_not_require_linear_recursion_test() {
  let assert Error(_) = parse.path("M 1e1000000000 0")
  let assert Ok(path) = parse.path("M 1e-1000000000 0")

  assert serialize.path(path) == "M 0 0"
}

pub fn move_only_subpath_is_preserved_test() {
  let assert Ok(path) = parse.path("M 0 0")

  assert serialize.path(path) == "M 0 0"
}

pub fn zero_length_line_subpath_is_not_move_only_test() {
  let a = svg_path.Point(0.0, 0.0)
  let assert Ok(path) = parse.path("M 0 0 L 0 0")
  let assert [subpath] = svg_path.path_subpaths(path)

  assert svg_path.subpath_start(subpath) == a
  assert svg_path.subpath_end(subpath) == a
  assert svg_path.subpath_segments(subpath) == [svg_path.Line(start: a, end: a)]
  assert serialize.path(path) == "M 0 0 H 0"
}

pub fn move_only_subpaths_are_ignored_among_real_subpaths_test() {
  let assert Ok(path) = parse.path("M 0 0 M 10 10 L 20 10")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 10 10 H 20"
}

pub fn invalid_arc_flags_are_rejected_test() {
  assert parse.path("M 0 0 A 5 5 0 2 1 10 0")
    == Error(parse.ParseError(parse.ExpectedArcFlag, "2 1 10 0"))
}

pub fn concatenated_arc_flags_and_endpoint_parse_test() {
  let assert Ok(path) = parse.path("M0 0A10 10 0 0110 20")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 A 10 10 0 0 1 10 20"
}

pub fn every_concatenated_arc_flag_pair_parses_test() {
  ["0010 20", "0110 20", "1010 20", "1110 20"]
  |> list.each(fn(arguments) {
    let assert Ok(_) = parse.path("M0 0A10 10 0 " <> arguments)
  })
}

pub fn concatenated_arc_flags_parse_in_repeated_argument_sets_test() {
  let assert Ok(path) = parse.path("M0 0A10 10 0 0110 20 5 5 0 10-4-6")
  let assert Ok(subpath) = svg_path.path_as_subpath(path)

  assert serialize.subpath(subpath)
    == "M 0 0 A 10 10 0 0 1 10 20 A 5 5 0 1 0 -4 -6"
}

pub fn unsupported_commands_are_rejected_test() {
  assert parse.path("M 0 0 R 1 2 3 4")
    == Error(parse.ParseError(parse.UnsupportedCommand("R"), "R 1 2 3 4"))
}

pub fn drawing_command_before_move_is_rejected_test() {
  assert parse.path("L 10 10")
    == Error(parse.ParseError(parse.ExpectedMove, "L 10 10"))
}

pub fn command_without_required_number_is_rejected_test() {
  assert parse.path("M 0 0 L")
    == Error(parse.ParseError(parse.ExpectedNumber, ""))
}

pub fn invalid_number_is_rejected_test() {
  assert parse.path("M . 0")
    == Error(parse.ParseError(parse.InvalidNumber("."), ". 0"))
}

pub fn comma_immediately_after_command_is_rejected_test() {
  assert parse.path("M,0,0")
    == Error(parse.ParseError(parse.InvalidSeparator, ",0,0"))
}

pub fn repeated_comma_is_rejected_test() {
  assert parse.path("M0,,0")
    == Error(parse.ParseError(parse.InvalidSeparator, ",,0"))
}

pub fn trailing_comma_is_rejected_test() {
  assert parse.path("M0 0,")
    == Error(parse.ParseError(parse.InvalidSeparator, ","))
}

pub fn comma_before_command_is_rejected_test() {
  assert parse.path("M0 0,L1 1")
    == Error(parse.ParseError(parse.InvalidSeparator, ",L1 1"))
}

pub fn error_remaining_preserves_unicode_suffix_test() {
  assert parse.path("M0 0 émore")
    == Error(parse.ParseError(parse.UnsupportedCommand("é"), "émore"))
}

pub fn comma_with_surrounding_whitespace_between_numbers_parses_test() {
  let assert Ok(path) = parse.path("M 0 , 0 L 1 , 1")

  assert serialize.path(path) == "M 0 0 L 1 1"
}

pub fn svg_form_feed_whitespace_parses_test() {
  let assert Ok(path) = parse.path("M\u{000c}0\u{000c}0L\u{000c}1\u{000c}1")

  assert serialize.path(path) == "M 0 0 L 1 1"
}
