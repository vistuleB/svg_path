import gleam/int
import gleeunit
import svg_path
import svg_path/parse
import svg_path/serialize

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn absolute_line_subset_canonicalizes_test() {
  assert parse_and_serialize("M 0 0 L 10 0 V 20 H 0")
    == Ok("M 0 0 H 10 V 20 H 0")
}

pub fn relative_line_subset_canonicalizes_to_absolute_by_default_test() {
  assert parse_and_serialize("m 10 10 l 5 0 v 20 h -5")
    == Ok("M 10 10 H 15 V 30 H 10")
}

pub fn compact_input_canonicalizes_test() {
  assert parse_and_serialize("M0-1L10-1V9H0z") == Ok("M 0 -1 H 10 V 9 H 0 Z")
}

pub fn comma_separated_input_canonicalizes_test() {
  assert parse_and_serialize("M0,0 L10,0 10,20") == Ok("M 0 0 H 10 V 20")
}

pub fn move_only_subpaths_are_preserved_test() {
  assert parse_and_serialize("M 0 0 M 10 10 L 20 10 M 30 30")
    == Ok("M 0 0 M 10 10 H 20 M 30 30")
}

pub fn relative_serialization_after_parsing_test() {
  assert parse_and_serialize_with_options(
      "M 10 10 L 20 10 L 20 30",
      serialize.relative_decimal_options(0),
    )
    == Ok("m 10 10 h 10 v 20")
}

pub fn minimized_serialization_after_parsing_test() {
  assert parse_and_serialize_with_options(
      "M 0 0 L 10 0 L 10 20",
      serialize.decimal_options(0) |> serialize.minimize_whitespace,
    )
    == Ok("M0 0H10V20")
}

pub fn decimal_rounding_after_parsing_test() {
  assert parse_and_serialize_with_options(
      "M 0.000001 1.234567 L 10.000001 1.234568",
      serialize.decimal_options(5),
    )
    == Ok("M 0 1.23457 H 10")
}

pub fn generated_paths_round_trip_with_default_options_test() {
  assert_paths_round_trip(generated_paths(), serialize.default_options())
}

pub fn generated_paths_round_trip_with_relative_options_test() {
  assert_paths_round_trip(
    generated_paths(),
    serialize.relative_decimal_options(0),
  )
}

pub fn generated_paths_round_trip_with_minimized_options_test() {
  assert_paths_round_trip(
    generated_paths(),
    serialize.decimal_options(0) |> serialize.minimize_whitespace,
  )
}

pub fn generated_paths_round_trip_with_repeat_commands_false_options_test() {
  assert_paths_round_trip(
    generated_paths(),
    serialize.default_options() |> serialize.repeat_commands(False),
  )
}

pub fn generated_paths_round_trip_with_commas_test() {
  assert_paths_round_trip(
    generated_paths(),
    serialize.default_options() |> serialize.with_commas(True),
  )
}

pub fn generated_paths_round_trip_with_minimized_repeat_commands_false_options_test() {
  assert_paths_round_trip(
    generated_paths(),
    serialize.decimal_options(0)
      |> serialize.minimize_whitespace
      |> serialize.repeat_commands(False),
  )
}

pub fn generated_paths_round_trip_with_subpath_newlines_and_repeat_commands_test() {
  assert_paths_multiline_round_trip(
    generated_paths(),
    serialize.default_options()
      |> serialize.repeat_commands(True)
      |> serialize.with_newlines(serialize.AtSubpaths),
  )
}

pub fn generated_paths_round_trip_with_subpath_newlines_and_omitted_repeat_commands_test() {
  assert_paths_multiline_round_trip(
    generated_paths(),
    serialize.default_options()
      |> serialize.repeat_commands(False)
      |> serialize.with_newlines(serialize.AtSubpaths),
  )
}

pub fn generated_paths_round_trip_with_segment_newlines_and_repeat_commands_test() {
  assert_paths_multiline_round_trip(
    generated_paths(),
    serialize.default_options()
      |> serialize.repeat_commands(True)
      |> serialize.with_newlines(serialize.AtSegments),
  )
}

pub fn generated_paths_round_trip_with_segment_newlines_and_omitted_repeat_commands_test() {
  assert_paths_multiline_round_trip(
    generated_paths(),
    serialize.default_options()
      |> serialize.repeat_commands(False)
      |> serialize.with_newlines(serialize.AtSegments),
  )
}

pub fn generated_paths_round_trip_with_commas_segment_newlines_and_omitted_repeat_commands_test() {
  assert_paths_multiline_round_trip(
    generated_paths(),
    serialize.default_options()
      |> serialize.with_commas(True)
      |> serialize.repeat_commands(False)
      |> serialize.with_newlines(serialize.AtSegments),
  )
}

pub fn generated_paths_round_trip_with_commas_and_minimized_whitespace_test() {
  assert_paths_round_trip(
    generated_paths(),
    serialize.decimal_options(0)
      |> serialize.with_commas(True)
      |> serialize.minimize_whitespace,
  )
}

fn parse_and_serialize(input: String) -> Result(String, parse.Error) {
  parse_and_serialize_with_options(input, serialize.default_options())
}

fn parse_and_serialize_with_options(
  input: String,
  options: serialize.Options,
) -> Result(String, parse.Error) {
  case parse.path(input) {
    Error(error) -> Error(error)
    Ok(path) -> Ok(serialize.path_with(path, options:))
  }
}

fn assert_paths_round_trip(
  paths: List(svg_path.Path),
  options: serialize.Options,
) -> Nil {
  case paths {
    [] -> Nil
    [path, ..rest] -> {
      assert_path_round_trips(path, options)
      assert_paths_round_trip(rest, options)
    }
  }
}

fn assert_path_round_trips(
  path: svg_path.Path,
  options: serialize.Options,
) -> Nil {
  let serialized = serialize.path_with(path, options:)

  assert parse_and_serialize_with_options(serialized, options) == Ok(serialized)
}

fn assert_paths_multiline_round_trip(
  paths: List(svg_path.Path),
  options: serialize.Options,
) -> Nil {
  case paths {
    [] -> Nil
    [path, ..rest] -> {
      assert_path_multiline_round_trips(path, options)
      assert_paths_multiline_round_trip(rest, options)
    }
  }
}

fn assert_path_multiline_round_trips(
  path: svg_path.Path,
  options: serialize.Options,
) -> Nil {
  let serialized = serialize.path_with(path, options:)

  assert parse_and_serialize_with_options(serialized, options) == Ok(serialized)

  let assert Ok(parsed) = parse.path(serialized)
  assert serialize.path(parsed) == serialize.path(path)
}

fn generated_paths() -> List(svg_path.Path) {
  [
    path_from_segments([
      svg_path.Line(point(0, 0), point(10, 0)),
      svg_path.Line(point(10, 0), point(10, 20)),
      svg_path.Line(point(10, 20), point(-5, 20)),
    ]),
    path_from_segments([
      svg_path.Line(point(-10, -10), point(-5, -5)),
      svg_path.QuadraticBezier(point(-5, -5), point(0, 15), point(10, 0)),
      svg_path.QuadraticBezier(point(10, 0), point(20, -15), point(25, 5)),
    ]),
    path_from_segments([
      svg_path.CubicBezier(
        point(0, 0),
        point(5, 10),
        point(15, -10),
        point(20, 0),
      ),
      svg_path.CubicBezier(
        point(20, 0),
        point(30, 10),
        point(35, -10),
        point(40, 0),
      ),
    ]),
    path_from_segments([
      svg_path.Arc(
        start: point(0, 0),
        radius: point(10, 5),
        x_axis_rotation: 30.0,
        large_arc: False,
        sweep: True,
        end: point(20, 10),
      ),
      svg_path.Arc(
        start: point(20, 10),
        radius: point(8, 8),
        x_axis_rotation: -45.0,
        large_arc: True,
        sweep: False,
        end: point(40, 0),
      ),
    ]),
    path_from_segments([
      svg_path.Line(point(0, 0), point(12, 0)),
      svg_path.QuadraticBezier(point(12, 0), point(18, 8), point(24, 0)),
      svg_path.CubicBezier(
        point(24, 0),
        point(30, -8),
        point(36, 8),
        point(42, 0),
      ),
      svg_path.Arc(
        start: point(42, 0),
        radius: point(6, 10),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: False,
        end: point(50, 0),
      ),
    ]),
    closed_path_from_segments([
      svg_path.Line(point(0, 0), point(20, 0)),
      svg_path.Line(point(20, 0), point(20, 20)),
      svg_path.Line(point(20, 20), point(0, 20)),
      svg_path.Line(point(0, 20), point(0, 0)),
    ]),
    svg_path.Path([
      subpath_from_segments([
        svg_path.Line(point(0, 0), point(10, 0)),
        svg_path.Line(point(10, 0), point(10, 10)),
      ]),
      subpath_from_segments([
        svg_path.Line(point(30, 30), point(40, 30)),
        svg_path.Line(point(40, 30), point(40, 40)),
      ]),
    ]),
  ]
}

fn path_from_segments(segments: List(svg_path.Segment)) -> svg_path.Path {
  svg_path.subpath_as_path(subpath_from_segments(segments))
}

fn closed_path_from_segments(
  segments: List(svg_path.Segment),
) -> svg_path.Path {
  let assert Ok(subpath) = svg_path.subpath(segments)
  let assert Ok(closed) = svg_path.subpath_set_closed(subpath, closed: True)

  svg_path.subpath_as_path(closed)
}

fn subpath_from_segments(segments: List(svg_path.Segment)) -> svg_path.Subpath {
  let assert Ok(subpath) = svg_path.subpath(segments)

  subpath
}

fn point(x: Int, y: Int) -> svg_path.Point {
  svg_path.Point(int.to_float(x), int.to_float(y))
}
