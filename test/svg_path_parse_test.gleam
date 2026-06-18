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

pub fn repeated_move_coordinates_become_implicit_lines_test() {
  let assert Ok(path) = parse.path("M0 0 10 0 10 20")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 0 0 H 10 V 20"
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

pub fn move_only_subpath_is_ignored_test() {
  assert parse.path("M 0 0") == Ok(svg_path.empty_path())
}

pub fn move_only_subpaths_are_ignored_among_real_subpaths_test() {
  let assert Ok(path) = parse.path("M 0 0 M 10 10 L 20 10")
  let assert Ok(subpath) = svg_path.as_subpath(path)

  assert serialize.subpath(subpath) == "M 10 10 H 20"
}

pub fn unsupported_commands_are_rejected_test() {
  assert parse.path("M 0 0 C 1 2 3 4 5 6")
    == Error(parse.UnsupportedCommand("C"))
}
