import gleeunit
import svg_path
import svg_path/parse
import svg_path/serialize

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn empty_string_parses_as_empty_path_test() {
  assert parse.path("") == Ok(svg_path.empty_path())
}

pub fn absolute_lines_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 L 10 0 V 20 H 0")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 H 10 V 20 H 0"
}

pub fn relative_lines_parse_to_absolute_segments_test() {
  let assert Ok(path) = parse.path("m 10 10 l 5 0 v 20 h -5")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 10 10 H 15 V 30 H 10"
}

pub fn relative_move_after_close_uses_closed_subpath_start_test() {
  let assert Ok(path) = parse.path("M 0 0 L 10 0 z m 5 5 l 5 0")

  assert serialize.path(path) == "M 0 0 H 10 H 0 Z M 5 5 H 10"
}

pub fn repeated_line_horizontal_and_vertical_values_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 L 10 0 10 10 H 5 0 V 5 0")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 H 10 V 10 H 5 H 0 V 5 V 0"
}

pub fn repeated_absolute_line_coordinate_pairs_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 L 5 10 3 2 4 5 2 2 V 3")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 L 5 10 L 3 2 L 4 5 L 2 2 V 3"
}

pub fn repeated_relative_line_coordinate_pairs_parse_test() {
  let assert Ok(path) = parse.path("m 0 0 l 5 10 3 2 4 5 2 2 v 3")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath)
    == "M 0 0 L 5 10 L 8 12 L 12 17 L 14 19 V 22"
}

pub fn repeated_line_pairs_can_switch_to_horizontal_command_test() {
  let assert Ok(path) = parse.path("M 1 1 L 5 10 3 2 4 5 H 9")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 1 1 L 5 10 L 3 2 L 4 5 H 9"
}

pub fn absolute_quadratic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 Q 10 20 30 40")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 Q 10 20 30 40"
}

pub fn relative_quadratic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 10 10 q 5 10 20 30")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 10 10 Q 15 20 30 40"
}

pub fn repeated_quadratic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 Q 10 20 30 40 50 60 70 80")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 Q 10 20 30 40 Q 50 60 70 80"
}

pub fn absolute_smooth_quadratic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 Q 10 20 30 40 T 50 60")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 Q 10 20 30 40 Q 50 60 50 60"
}

pub fn relative_smooth_quadratic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 10 10 q 5 10 20 30 t 20 20")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 10 10 Q 15 20 30 40 Q 45 60 50 60"
}

pub fn repeated_smooth_quadratic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 Q 10 20 30 40 T 50 60 70 80")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath)
    == "M 0 0 Q 10 20 30 40 Q 50 60 50 60 Q 50 60 70 80"
}

pub fn smooth_quadratic_without_previous_quadratic_uses_current_point_test() {
  let assert Ok(path) = parse.path("M 0 0 L 5 5 T 10 10")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 L 5 5 Q 5 5 10 10"
}

pub fn absolute_cubic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 C 10 20 30 40 50 60")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 C 10 20 30 40 50 60"
}

pub fn relative_cubic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 10 10 c 1 2 3 4 5 6")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 10 10 C 11 12 13 14 15 16"
}

pub fn repeated_cubic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 C 1 2 3 4 5 6 7 8 9 10 11 12")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 C 1 2 3 4 5 6 C 7 8 9 10 11 12"
}

pub fn absolute_smooth_cubic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 C 1 2 3 4 5 6 S 9 10 11 12")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 C 1 2 3 4 5 6 C 7 8 9 10 11 12"
}

pub fn relative_smooth_cubic_beziers_parse_test() {
  let assert Ok(path) = parse.path("M 10 10 c 1 2 3 4 5 6 s 4 4 6 6")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath)
    == "M 10 10 C 11 12 13 14 15 16 C 17 18 19 20 21 22"
}

pub fn repeated_smooth_cubic_beziers_parse_test() {
  let assert Ok(path) =
    parse.path("M 0 0 C 1 2 3 4 5 6 S 9 10 11 12 15 16 17 18")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath)
    == "M 0 0 C 1 2 3 4 5 6 C 7 8 9 10 11 12 C 13 14 15 16 17 18"
}

pub fn smooth_cubic_without_previous_cubic_uses_current_point_test() {
  let assert Ok(path) = parse.path("M 0 0 L 5 5 S 10 10 15 15")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 L 5 5 C 5 5 10 10 15 15"
}

pub fn absolute_arcs_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 A 5 10 30 0 1 20 40")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 A 5 10 30 0 1 20 40"
}

pub fn relative_arcs_parse_test() {
  let assert Ok(path) = parse.path("M 10 10 a 5 10 30 1 0 20 40")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 10 10 A 5 10 30 1 0 30 50"
}

pub fn repeated_arcs_parse_test() {
  let assert Ok(path) = parse.path("M 0 0 A 5 10 30 0 1 20 40 7 8 45 1 0 30 50")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath)
    == "M 0 0 A 5 10 30 0 1 20 40 A 7 8 45 1 0 30 50"
}

pub fn repeated_move_coordinates_become_implicit_lines_test() {
  let assert Ok(path) = parse.path("M0 0 10 0 10 20")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 H 10 V 20"
}

pub fn relative_move_implicit_lines_stay_relative_test() {
  let assert Ok(path) = parse.path("m 10 10 5 0 0 5")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 10 10 H 15 V 15"
}

pub fn closepath_adds_closing_line_and_semantic_close_test() {
  let assert Ok(path) = parse.path("M 0 0 L 10 0 z")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert svg_path.is_closed(subpath)
  assert serialize.subpath(subpath) == "M 0 0 H 10 H 0 Z"
}

pub fn compact_numbers_parse_test() {
  let assert Ok(path) = parse.path("M0-1L10-1V9")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 -1 H 10 V 9"
}

pub fn comma_separated_coordinate_pairs_parse_test() {
  let assert Ok(path) = parse.path("M0,0 L10,20 30,40")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 L 10 20 L 30 40"
}

pub fn commas_parse_between_curve_coordinates_test() {
  let assert Ok(path) = parse.path("M0,0 C1,2,3,4,5,6 Q7,8,9,10")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 C 1 2 3 4 5 6 Q 7 8 9 10"
}

pub fn commas_parse_between_arc_arguments_test() {
  let assert Ok(path) = parse.path("M0,0 A25,50 -30 0,1 50,-25")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 A 25 50 -30 0 1 50 -25"
}

pub fn exponent_and_plus_signed_numbers_parse_test() {
  let assert Ok(path) = parse.path("M +1e1 -2E1 L 1.5e1 -2e1")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 10 -20 H 15"
}

pub fn move_only_subpath_is_ignored_test() {
  assert parse.path("M 0 0") == Ok(svg_path.empty_path())
}

pub fn move_only_subpaths_are_ignored_among_real_subpaths_test() {
  let assert Ok(path) = parse.path("M 0 0 M 10 10 L 20 10")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 10 10 H 20"
}

pub fn invalid_arc_flags_are_rejected_test() {
  assert parse.path("M 0 0 A 5 5 0 2 1 10 0") == Error(parse.ExpectedArcFlag)
}

pub fn unsupported_commands_are_rejected_test() {
  assert parse.path("M 0 0 R 1 2 3 4") == Error(parse.UnsupportedCommand("R"))
}

pub fn drawing_command_before_move_is_rejected_test() {
  assert parse.path("L 10 10") == Error(parse.ExpectedMove)
}

pub fn command_without_required_number_is_rejected_test() {
  assert parse.path("M 0 0 L") == Error(parse.ExpectedNumber)
}

pub fn invalid_number_is_rejected_test() {
  assert parse.path("M . 0") == Error(parse.InvalidNumber("."))
}
