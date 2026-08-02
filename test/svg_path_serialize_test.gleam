import gleam/float
import gleam/list
import gleam/string
import gleeunit
import svg_path
import svg_path/parse
import svg_path/serialize

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn empty_path_serializes_to_empty_string_test() {
  assert serialize.path(svg_path.path_empty()) == ""
}

pub fn empty_subpath_serializes_to_move_test() {
  assert serialize.subpath(svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)))
    == "M 0 0"
}

pub fn closed_empty_subpath_serializes_to_move_and_z_test() {
  let subpath =
    svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0))
    |> svg_path.subpath_assert_set_closed(closed: True)

  assert serialize.subpath(subpath) == "M 0 0 Z"
}

pub fn path_serializes_empty_subpaths_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let assert Ok(subpath) = svg_path.subpath([svg_path.Line(start: a, end: b)])
  let path =
    svg_path.Path([
      svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)),
      subpath,
      svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0)),
    ])

  assert serialize.path(path) == "M 0 0 M 0 0 H 10 M 0 0"
}

pub fn open_subpath_serializes_absolute_commands_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 20.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert serialize.subpath(subpath) == "M 0 0 H 10 V 20"
}

pub fn closed_subpath_serializes_with_z_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 20.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])
    |> result_try_set_closed_with_bridge

  assert serialize.subpath(subpath) == "M 0 0 H 10 V 20 Z"
}

pub fn closed_subpath_keeps_final_curve_before_z_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 10.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.QuadraticBezier(start: b, control: c, end: a),
    ])
    |> result_try_set_closed_true

  assert serialize.subpath(subpath) == "M 0 0 H 10 Q 20 10 0 0 Z"
}

pub fn closed_subpath_keeps_final_zero_length_line_test() {
  let a = svg_path.Point(0.0, 0.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: a),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)

  assert serialize.subpath(subpath) == "M 0 0 H 0 Z"
}

pub fn closed_subpath_keeps_final_zero_length_line_after_curve_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.QuadraticBezier(start: a, control: b, end: a),
      svg_path.Line(start: a, end: a),
    ])
    |> result_try_set_closed_true

  assert serialize.subpath(subpath) == "M 0 0 Q 10 0 0 0 H 0 Z"
}

pub fn relative_closed_subpath_keeps_final_zero_length_line_test() {
  let a = svg_path.Point(10.0, 10.0)
  let b = svg_path.Point(20.0, 10.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
      svg_path.Line(start: a, end: a),
    ])
    |> result_try_set_closed_true

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.relative_decimal_options(0),
    )
    == "m 10 10 h 10 h -10 h 0 z"
}

pub fn bezier_and_arc_segments_serialize_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 10.0)
  let d = svg_path.Point(30.0, 0.0)
  let e = svg_path.Point(40.0, 20.0)
  let radius = svg_path.Point(5.0, 8.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.QuadraticBezier(start: a, control: b, end: c),
      svg_path.CubicBezier(start: c, control1: d, control2: e, end: b),
      svg_path.Arc(
        start: b,
        radius: radius,
        x_axis_rotation: 45.0,
        large_arc: True,
        sweep: False,
        end: a,
      ),
    ])

  assert serialize.subpath(subpath)
    == "M 0 0 Q 10 0 20 10 C 30 0 40 20 10 0 A 5 8 45 1 0 0 0"
}

pub fn fixed_decimal_options_round_and_pad_numbers_test() {
  let a = svg_path.Point(0.0, 1.2)
  let b = svg_path.Point(10.234, -20.235)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.fixed_decimal_options(2),
    )
    == "M 0.00 1.20 L 10.23 -20.24"
}

pub fn decimal_options_round_and_strip_trailing_zeros_test() {
  let a = svg_path.Point(0.0, 1.2)
  let b = svg_path.Point(10.234, -20.235)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.decimal_options(3),
    )
    == "M 0 1.2 L 10.234 -20.235"
}

pub fn fixed_decimal_options_keep_trailing_zeros_test() {
  let a = svg_path.Point(1.0, 1.2)
  let b = svg_path.Point(10.0, -20.0)

  assert serialize.segment_with_options(
      svg_path.Line(start: a, end: b),
      options: serialize.fixed_decimal_options(3),
    )
    == "M 1.000 1.200 L 10.000 -20.000"
}

pub fn fixed_decimal_options_can_use_zero_places_test() {
  let a = svg_path.Point(0.4, 1.5)
  let b = svg_path.Point(10.49, -20.5)

  assert serialize.segment_with_options(
      svg_path.Line(start: a, end: b),
      options: serialize.fixed_decimal_options(0),
    )
    == "M 0 2 L 10 -21"
}

pub fn left_padding_pads_serialized_numbers_test() {
  let a = svg_path.Point(0.0, -2.0)
  let b = svg_path.Point(12.2, 10.2)

  assert serialize.segment_with_options(
      svg_path.Line(start: a, end: b),
      options: serialize.fixed_decimal_options(1)
        |> serialize.with_left_padding(serialize.LeftPadding(3, serialize.Zero)),
    )
    == "M 000.0 -02.0 L 012.2 010.2"
}

pub fn space_left_padding_pads_serialized_numbers_test() {
  let a = svg_path.Point(0.0, -2.0)
  let b = svg_path.Point(12.2, 10.2)

  assert serialize.segment_with_options(
      svg_path.Line(start: a, end: b),
      options: serialize.fixed_decimal_options(1)
        |> serialize.with_left_padding(serialize.LeftPadding(3, serialize.Space)),
    )
    == "M   0.0  -2.0 L  12.2  10.2"
}

pub fn auto_left_padding_aligns_serialized_path_numbers_test() {
  let a = svg_path.Point(0.0, -5.0)
  let b = svg_path.Point(120.0, 10.0)
  let c = svg_path.Point(2.0, -30.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.fixed_decimal_options(1)
        |> serialize.with_left_padding(serialize.AutoLeftPadding(serialize.Zero)),
    )
    == "M 000.0 -05.0 L 120.0 010.0 L 002.0 -30.0"
}

pub fn minimize_whitespace_removes_command_spacing_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 20.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.decimal_options(0) |> serialize.minimize_whitespace,
    )
    == "M0 0H10V20"
}

pub fn repeat_commands_false_omits_repeated_line_commands_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 10.0)
  let c = svg_path.Point(20.0, 20.0)
  let d = svg_path.Point(30.0, 30.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.default_options() |> serialize.repeat_commands(False),
    )
    == "M 0 0 L 10 10 20 20 30 30"
}

pub fn repeat_commands_false_omits_repeated_h_and_v_commands_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let d = svg_path.Point(20.0, 10.0)
  let e = svg_path.Point(20.0, 20.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
      svg_path.Line(start: d, end: e),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.default_options() |> serialize.repeat_commands(False),
    )
    == "M 0 0 H 10 20 V 10 20"
}

pub fn repeat_commands_false_omits_repeated_curve_commands_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 10.0)
  let d = svg_path.Point(30.0, 0.0)
  let e = svg_path.Point(40.0, 10.0)
  let f = svg_path.Point(50.0, 0.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.QuadraticBezier(start: a, control: b, end: c),
      svg_path.QuadraticBezier(start: c, control: d, end: e),
      svg_path.CubicBezier(start: e, control1: d, control2: b, end: f),
      svg_path.CubicBezier(start: f, control1: b, control2: d, end: a),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.default_options() |> serialize.repeat_commands(False),
    )
    == "M 0 0 Q 10 0 20 10 30 0 40 10 C 30 0 10 0 50 0 10 0 30 0 0 0"
}

pub fn repeat_commands_false_omits_repeated_arc_commands_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 0.0)
  let radius = svg_path.Point(5.0, 5.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Arc(
        start: a,
        radius:,
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: b,
      ),
      svg_path.Arc(
        start: b,
        radius:,
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: c,
      ),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.default_options() |> serialize.repeat_commands(False),
    )
    == "M 0 0 A 5 5 0 0 1 10 0 5 5 0 0 1 20 0"
}

pub fn at_subpaths_puts_each_subpath_on_its_own_line_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 10.0)
  let c = svg_path.Point(20.0, 20.0)
  let d = svg_path.Point(100.0, 100.0)
  let e = svg_path.Point(110.0, 110.0)
  let f = svg_path.Point(120.0, 120.0)
  let assert Ok(first) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])
    |> result_try_set_closed_with_bridge
  let assert Ok(second) =
    svg_path.subpath([
      svg_path.Line(start: d, end: e),
      svg_path.Line(start: e, end: f),
    ])
    |> result_try_set_closed_with_bridge

  assert serialize.path_with_options(
      svg_path.Path([first, second]),
      options: serialize.default_options()
        |> serialize.with_newlines(serialize.AtSubpaths),
    )
    == "M 0 0 L 10 10 L 20 20 Z\nM 100 100 L 110 110 L 120 120 Z"
}

pub fn at_segments_with_repeat_commands_true_starts_lines_with_commands_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 10.0)
  let c = svg_path.Point(20.0, 20.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])
    |> result_try_set_closed_with_bridge

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.default_options()
        |> serialize.with_newlines(serialize.AtSegments),
    )
    == "M 0 0\nL 10 10\nL 20 20\nZ"
}

pub fn at_segments_with_repeat_commands_false_trails_emitted_commands_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 10.0)
  let c = svg_path.Point(20.0, 20.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])
    |> result_try_set_closed_with_bridge

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.default_options()
        |> serialize.repeat_commands(False)
        |> serialize.with_newlines(serialize.AtSegments),
    )
    == "M\n0 0 L\n10 10\n20 20 Z"
}

pub fn at_segments_with_repeat_commands_false_starts_moves_on_new_lines_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 10.0)
  let c = svg_path.Point(100.0, 100.0)
  let d = svg_path.Point(110.0, 110.0)
  let assert Ok(first) = svg_path.subpath([svg_path.Line(start: a, end: b)])
  let assert Ok(second) = svg_path.subpath([svg_path.Line(start: c, end: d)])

  assert serialize.path_with_options(
      svg_path.Path([first, second]),
      options: serialize.default_options()
        |> serialize.repeat_commands(False)
        |> serialize.with_newlines(serialize.AtSegments),
    )
    == "M\n0 0 L\n10 10\nM\n100 100 L\n110 110"
}

pub fn at_segments_with_repeat_commands_true_starts_curve_lines_with_commands_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 10.0)
  let d = svg_path.Point(30.0, 0.0)
  let e = svg_path.Point(40.0, 10.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.CubicBezier(start: a, control1: b, control2: c, end: d),
      svg_path.CubicBezier(start: d, control1: c, control2: b, end: e),
    ])
    |> result_try_set_closed_with_bridge

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.default_options()
        |> serialize.with_newlines(serialize.AtSegments),
    )
    == "M 0 0\nC 10 0 20 10 30 0\nC 20 10 10 0 40 10\nZ"
}

pub fn at_segments_with_repeat_commands_false_trails_curve_commands_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(20.0, 10.0)
  let d = svg_path.Point(30.0, 0.0)
  let e = svg_path.Point(40.0, 10.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.CubicBezier(start: a, control1: b, control2: c, end: d),
      svg_path.CubicBezier(start: d, control1: c, control2: b, end: e),
    ])
    |> result_try_set_closed_with_bridge

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.default_options()
        |> serialize.repeat_commands(False)
        |> serialize.with_newlines(serialize.AtSegments),
    )
    == "M\n0 0 C\n10 0 20 10 30 0\n20 10 10 0 40 10 Z"
}

pub fn commas_separate_coordinates_inside_point_pairs_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 10.0)
  let c = svg_path.Point(20.0, 20.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])
    |> result_try_set_closed_with_bridge

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.default_options()
        |> serialize.with_commas(True)
        |> serialize.repeat_commands(False)
        |> serialize.with_newlines(serialize.AtSegments),
    )
    == "M\n0,0 L\n10,10\n20,20 Z"
}

pub fn commas_preserve_spaces_between_curve_point_pairs_test() {
  let a = svg_path.Point(20.0, -30.0)
  let b = svg_path.Point(140.0, 20.0)
  let c = svg_path.Point(480.0, -60.0)
  let d = svg_path.Point(840.0, -90.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.CubicBezier(
        start: a,
        control1: svg_path.Point(-15.0, 40.0),
        control2: svg_path.Point(80.0, -90.0),
        end: b,
      ),
      svg_path.CubicBezier(
        start: b,
        control1: svg_path.Point(260.0, 30.0),
        control2: svg_path.Point(-320.0, 45.0),
        end: c,
      ),
      svg_path.CubicBezier(
        start: c,
        control1: svg_path.Point(600.5, -70.25),
        control2: svg_path.Point(720.0, 80.0),
        end: d,
      ),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.fixed_decimal_options(2)
        |> serialize.with_left_padding(serialize.AutoLeftPadding(
          serialize.Space,
        ))
        |> serialize.with_commas(True)
        |> serialize.repeat_commands(False)
        |> serialize.with_newlines(serialize.AtSegments),
    )
    == "M\n  20.00, -30.00 C\n -15.00,  40.00   80.00, -90.00  140.00,  20.00\n 260.00,  30.00 -320.00,  45.00  480.00, -60.00\n 600.50, -70.25  720.00,  80.00  840.00, -90.00"
}

pub fn commas_apply_to_arc_radius_and_endpoint_pairs_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.Point(10.0, 20.0),
      radius: svg_path.Point(5.0, 8.0),
      x_axis_rotation: 45.0,
      large_arc: True,
      sweep: False,
      end: svg_path.Point(13.0, 18.0),
    )

  assert serialize.segment_with_options(
      arc,
      options: serialize.relative_decimal_options(0)
        |> serialize.with_commas(True),
    )
    == "m 10,20 a 5,8 45 1 0 3,-2"
}

pub fn relative_options_use_relative_line_commands_test() {
  let a = svg_path.Point(10.0, 20.0)
  let b = svg_path.Point(13.0, 18.0)

  assert serialize.segment_with_options(
      svg_path.Line(start: a, end: b),
      options: serialize.relative_decimal_options(0),
    )
    == "m 10 20 l 3 -2"
}

pub fn relative_options_use_relative_curve_commands_test() {
  let start = svg_path.Point(10.0, 20.0)
  let quadratic =
    svg_path.QuadraticBezier(
      start: start,
      control: svg_path.Point(12.0, 23.0),
      end: svg_path.Point(15.0, 25.0),
    )
  let cubic =
    svg_path.CubicBezier(
      start: start,
      control1: svg_path.Point(11.0, 21.0),
      control2: svg_path.Point(14.0, 24.0),
      end: svg_path.Point(18.0, 28.0),
    )

  assert serialize.segment_with_options(
      quadratic,
      options: serialize.relative_decimal_options(0),
    )
    == "m 10 20 q 2 3 5 5"
  assert serialize.segment_with_options(
      cubic,
      options: serialize.relative_decimal_options(0),
    )
    == "m 10 20 c 1 1 4 4 8 8"
}

pub fn relative_options_use_relative_arc_endpoint_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.Point(10.0, 20.0),
      radius: svg_path.Point(5.0, 8.0),
      x_axis_rotation: 45.0,
      large_arc: True,
      sweep: False,
      end: svg_path.Point(13.0, 18.0),
    )

  assert serialize.segment_with_options(
      arc,
      options: serialize.relative_decimal_options(0),
    )
    == "m 10 20 a 5 8 45 1 0 3 -2"
}

pub fn relative_minimize_whitespace_removes_command_spacing_test() {
  let a = svg_path.Point(10.0, 20.0)
  let b = svg_path.Point(13.0, 18.0)

  assert serialize.segment_with_options(
      svg_path.Line(start: a, end: b),
      options: serialize.relative_decimal_options(0)
        |> serialize.minimize_whitespace,
    )
    == "m10 20l3-2"
}

pub fn relative_repeat_commands_false_omits_repeated_commands_test() {
  let a = svg_path.Point(10.0, 20.0)
  let b = svg_path.Point(13.0, 18.0)
  let c = svg_path.Point(16.0, 16.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.relative_decimal_options(0)
        |> serialize.repeat_commands(False),
    )
    == "m 10 20 l 3 -2 3 -2"
}

pub fn minimized_repeat_commands_false_omits_repeated_commands_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 10.0)
  let c = svg_path.Point(20.0, 20.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.decimal_options(0)
        |> serialize.minimize_whitespace
        |> serialize.repeat_commands(False),
    )
    == "M0 0L10 10 20 20"
}

pub fn minifying_options_use_relative_minimized_output_test() {
  let a = svg_path.Point(10.0, 20.0)
  let b = svg_path.Point(13.0, 18.0)
  let c = svg_path.Point(16.0, 16.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.minifying_options(0),
    )
    == "m10 20 3-2 3-2"
}

pub fn explicit_initial_lineto_can_be_omitted_absolute_test() {
  let a = svg_path.Point(10.0, 20.0)
  let b = svg_path.Point(13.0, 18.0)
  let subpath = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.default_options()
        |> serialize.explicit_initial_lineto(False),
    )
    == "M 10 20 13 18"
}

pub fn explicit_initial_lineto_can_be_omitted_relative_test() {
  let a = svg_path.Point(10.0, 20.0)
  let b = svg_path.Point(13.0, 18.0)
  let subpath = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.relative_options()
        |> serialize.explicit_initial_lineto(False),
    )
    == "m 10 20 3 -2"
}

pub fn minimized_fractions_omit_leading_zero_and_use_decimal_boundary_test() {
  let a = svg_path.Point(0.6, 0.5)
  let b = svg_path.Point(0.4, 0.3)
  let subpath = svg_path.subpath_assert([svg_path.Line(start: a, end: b)])
  let serialized =
    serialize.subpath_with_options(
      subpath,
      options: serialize.decimal_options(1)
        |> serialize.use_h_v(False)
        |> serialize.minimize_whitespace,
    )

  assert serialized == "M.6.5L.4.3"
  assert parse.path(serialized) == Ok(svg_path.Path([subpath]))
}

pub fn minifying_options_concatenate_arc_flags_and_endpoint_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(3.0, -2.0)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Arc(
        start: a,
        radius: svg_path.Point(5.0, 8.0),
        x_axis_rotation: 45.0,
        large_arc: True,
        sweep: False,
        end: b,
      ),
    ])
  let serialized =
    serialize.subpath_with_options(
      subpath,
      options: serialize.minifying_options(0),
    )

  assert serialized == "m0 0a5 8 45 103-2"
  assert parse.path(serialized) == Ok(svg_path.Path([subpath]))
}

pub fn minifying_options_roundtrip_many_negative_fraction_vertices_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(-0.97, -0.94),
      svg_path.Point(-0.82, -0.71),
      svg_path.Point(-0.65, -0.89),
      svg_path.Point(-0.48, -0.62),
      svg_path.Point(-0.31, -0.83),
      svg_path.Point(-0.14, -0.55),
      svg_path.Point(-0.02, -0.76),
      svg_path.Point(-0.19, -0.43),
      svg_path.Point(-0.37, -0.68),
      svg_path.Point(-0.53, -0.34),
      svg_path.Point(-0.72, -0.58),
      svg_path.Point(-0.88, -0.27),
      svg_path.Point(-0.99, -0.49),
      svg_path.Point(-0.79, -0.08),
      svg_path.Point(-0.56, -0.29),
      svg_path.Point(-0.33, -0.01),
    ])
  let path = svg_path.Path([subpath])
  let options = serialize.minifying_options(2)
  let serialized = serialize.path_with_options(path, options:)
  let assert Ok(parsed) = parse.path(serialized)

  assert serialize.path_with_options(parsed, options:) == serialized
}

pub fn minifying_options_roundtrip_preserves_structural_path_equality_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(-1.0, -1.0),
      svg_path.Point(-0.75, -0.5),
      svg_path.Point(-0.5, -0.75),
      svg_path.Point(-0.25, -0.25),
      svg_path.Point(0.0, -0.5),
      svg_path.Point(-0.25, -1.0),
      svg_path.Point(-0.5, -0.25),
      svg_path.Point(-0.75, -0.75),
      svg_path.Point(-1.0, -0.25),
      svg_path.Point(-0.75, 0.0),
      svg_path.Point(-0.5, -0.5),
      svg_path.Point(-0.25, -0.75),
      svg_path.Point(0.0, -1.0),
      svg_path.Point(-0.25, 0.0),
      svg_path.Point(-0.5, -1.0),
      svg_path.Point(-1.0, -0.5),
    ])
  let path = svg_path.Path([subpath])
  let serialized =
    serialize.path_with_options(path, options: serialize.minifying_options(2))

  assert parse.path(serialized) == Ok(path)
}

pub fn use_h_v_can_be_disabled_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 20.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.default_options()
        |> serialize.use_h_v(False),
    )
    == "M 0 0 L 10 0 L 10 20"
}

pub fn use_s_t_uses_s_and_t_by_default_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 20.0)
  let c = svg_path.Point(30.0, 40.0)
  let d = svg_path.Point(50.0, 60.0)
  let e = svg_path.Point(70.0, 80.0)
  let assert Ok(quadratic_subpath) =
    svg_path.subpath([
      svg_path.QuadraticBezier(start: a, control: b, end: c),
      svg_path.QuadraticBezier(start: c, control: d, end: e),
    ])

  let p = svg_path.Point(1.0, 2.0)
  let q = svg_path.Point(3.0, 4.0)
  let r = svg_path.Point(5.0, 6.0)
  let s = svg_path.Point(7.0, 8.0)
  let t = svg_path.Point(9.0, 10.0)
  let u = svg_path.Point(11.0, 12.0)
  let assert Ok(cubic_subpath) =
    svg_path.subpath([
      svg_path.CubicBezier(start: a, control1: p, control2: q, end: r),
      svg_path.CubicBezier(start: r, control1: s, control2: t, end: u),
    ])

  assert serialize.subpath(quadratic_subpath) == "M 0 0 Q 10 20 30 40 T 70 80"
  assert serialize.subpath(cubic_subpath) == "M 0 0 C 1 2 3 4 5 6 S 9 10 11 12"
}

pub fn use_s_t_can_be_disabled_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 20.0)
  let c = svg_path.Point(30.0, 40.0)
  let d = svg_path.Point(50.0, 60.0)
  let e = svg_path.Point(70.0, 80.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.QuadraticBezier(start: a, control: b, end: c),
      svg_path.QuadraticBezier(start: c, control: d, end: e),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.default_options() |> serialize.use_s_t(False),
    )
    == "M 0 0 Q 10 20 30 40 Q 50 60 70 80"
}

pub fn use_s_t_discovers_shorthand_after_decimal_formatting_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 20.0)
  let c = svg_path.Point(30.0, 40.0)
  let d = svg_path.Point(50.0004, 60.0004)
  let e = svg_path.Point(70.0, 80.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.QuadraticBezier(start: a, control: b, end: c),
      svg_path.QuadraticBezier(start: c, control: d, end: e),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.decimal_options(3),
    )
    == "M 0 0 Q 10 20 30 40 T 70 80"
}

pub fn relative_options_make_moves_relative_between_subpaths_test() {
  let a = svg_path.Point(10.0, 10.0)
  let b = svg_path.Point(20.0, 10.0)
  let c = svg_path.Point(25.0, 30.0)
  let d = svg_path.Point(30.0, 30.0)
  let assert Ok(first) = svg_path.subpath([svg_path.Line(start: a, end: b)])
  let assert Ok(second) = svg_path.subpath([svg_path.Line(start: c, end: d)])

  assert serialize.path_with_options(
      svg_path.Path([
        first,
        svg_path.subpath_empty(at: b),
        second,
      ]),
      options: serialize.relative_decimal_options(0),
    )
    == "m 10 10 h 10 m 0 0 m 5 20 h 5"
}

pub fn relative_options_move_from_closed_subpath_start_after_z_test() {
  let a = svg_path.Point(10.0, 10.0)
  let b = svg_path.Point(20.0, 10.0)
  let c = svg_path.Point(30.0, 10.0)
  let d = svg_path.Point(40.0, 10.0)
  let assert Ok(first) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])
    |> result_try_set_closed_true
  let assert Ok(second) = svg_path.subpath([svg_path.Line(start: c, end: d)])

  assert serialize.path_with_options(
      svg_path.Path([first, second]),
      options: serialize.relative_decimal_options(0),
    )
    == "m 10 10 h 10 z m 20 0 h 10"
}

pub fn minimized_relative_path_with_multiple_subpaths_test() {
  let a = svg_path.Point(10.0, 10.0)
  let b = svg_path.Point(20.0, 10.0)
  let c = svg_path.Point(25.0, 30.0)
  let d = svg_path.Point(30.0, 30.0)
  let assert Ok(first) = svg_path.subpath([svg_path.Line(start: a, end: b)])
  let assert Ok(second) = svg_path.subpath([svg_path.Line(start: c, end: d)])

  assert serialize.path_with_options(
      svg_path.Path([first, second]),
      options: serialize.relative_decimal_options(0)
        |> serialize.minimize_whitespace,
    )
    == "m10 10h10m5 20h5"
}

pub fn decimal_options_clamp_negative_decimal_places_to_zero_test() {
  let segment =
    svg_path.Line(
      start: svg_path.Point(0.4, 1.5),
      end: svg_path.Point(10.49, -20.5),
    )

  assert serialize.segment_with_options(
      segment,
      options: serialize.decimal_options(-3),
    )
    == "M 0 2 L 10 -21"
}

pub fn rounded_absolute_line_uses_h_or_v_after_formatting_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.000001)
  let c = svg_path.Point(10.000001, 20.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.decimal_options(5),
    )
    == "M 0 0 H 10 V 20"
}

pub fn rounded_relative_line_uses_h_or_v_after_formatting_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.000001)
  let c = svg_path.Point(10.000001, 20.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.relative_decimal_options(5),
    )
    == "m 0 0 h 10 v 20"
}

pub fn parser_tracked_relative_lines_correct_rounding_drift_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(0.34, 0.34)
  let c = svg_path.Point(0.68, 0.68)
  let d = svg_path.Point(1.02, 1.02)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ])
  let path = svg_path.Path([subpath])
  let options =
    serialize.relative_decimal_options(1) |> serialize.use_h_v(False)

  assert serialize.path_with_independent_relative_options(path, options)
    == "m 0 0 l 0.3 0.3 l 0.3 0.3 l 0.3 0.3"
  assert serialize.path_with_options(path, options)
    == "m 0 0 l 0.3 0.3 l 0.4 0.4 l 0.3 0.3"
}

pub fn parser_tracked_auto_padding_uses_corrected_numbers_test() {
  let a = svg_path.Point(0.14, 0.0)
  let b = svg_path.Point(10.06, 0.0)
  let assert Ok(subpath) = svg_path.subpath([svg_path.Line(start: a, end: b)])

  assert serialize.path_with_parser_tracked_relative_options(
      svg_path.Path([subpath]),
      serialize.relative_decimal_options(1)
        |> serialize.with_left_padding(serialize.AutoLeftPadding(serialize.Zero)),
    )
    == "m 00.1 00 h 10"
}

pub fn parser_tracked_relative_lines_preserve_axis_constraints_test() {
  let a = svg_path.Point(0.04, 0.04)
  let b = svg_path.Point(0.34, 0.34)
  let c = svg_path.Point(0.68, 0.34)
  let d = svg_path.Point(0.68, 0.68)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
    ])
  let serialized =
    serialize.path_with_parser_tracked_relative_options(
      svg_path.Path([subpath]),
      serialize.relative_decimal_options(1),
    )

  assert serialized == "m 0 0 l 0.3 0.3 h 0.4 v 0.4"
  let assert Ok(svg_path.Path([parsed])) = parse.path(serialized)
  let assert [
    _,
    svg_path.Line(start: horizontal_start, end: horizontal_end),
    svg_path.Line(start: vertical_start, end: vertical_end),
  ] = svg_path.subpath_segments(parsed)
  assert horizontal_start.y == horizontal_end.y
  assert vertical_start.x == vertical_end.x
}

pub fn parser_tracked_relative_cubic_uses_similarity_correction_test() {
  let start = svg_path.Point(0.34, 0.0)
  let end = svg_path.Point(1.39, 0.0)
  let cubic =
    svg_path.CubicBezier(
      start:,
      control1: svg_path.Point(0.34, 1.0),
      control2: svg_path.Point(1.39, 1.0),
      end:,
    )
  let assert Ok(subpath) = svg_path.subpath([cubic])
  let serialized =
    serialize.path_with_parser_tracked_relative_options(
      svg_path.Path([subpath]),
      serialize.relative_decimal_options(1),
    )

  assert serialized == "m 0.3 0 c 0 1 1.1 1 1.1 0"
  let assert Ok(svg_path.Path([parsed])) = parse.path(serialized)
  let assert [svg_path.CubicBezier(start: parsed_start, end: parsed_end, ..)] =
    svg_path.subpath_segments(parsed)
  assert parsed_start == svg_path.Point(0.3, 0.0)
  assert float.absolute_value(parsed_end.x -. 1.4) <. 0.000000000001
  assert parsed_end.y == 0.0
}

pub fn parser_tracked_relative_close_resets_the_parser_current_test() {
  let a = svg_path.Point(0.34, 0.34)
  let b = svg_path.Point(0.68, 0.34)
  let c = svg_path.Point(1.02, 0.34)
  let assert Ok(first) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: a),
    ])
    |> result_try_set_closed_true
  let assert Ok(second) = svg_path.subpath([svg_path.Line(start: c, end: b)])

  assert serialize.path_with_parser_tracked_relative_options(
      svg_path.Path([first, second]),
      serialize.relative_decimal_options(1),
    )
    == "m 0.3 0.3 h 0.4 z m 0.7 0 h -0.3"
}

pub fn parser_tracked_relative_arc_applies_chord_similarity_test() {
  let start = svg_path.Point(0.34, 0.0)
  let end = svg_path.Point(1.39, 0.0)
  let arc =
    svg_path.Arc(
      start:,
      radius: svg_path.Point(2.0, 1.0),
      x_axis_rotation: 15.0,
      large_arc: False,
      sweep: True,
      end:,
    )
  let assert Ok(subpath) = svg_path.subpath([arc])

  assert serialize.path_with_parser_tracked_relative_options(
      svg_path.Path([subpath]),
      serialize.relative_decimal_options(1),
    )
    == "m 0.3 0 a 2.1 1 15 0 1 1.1 0"
}

pub fn parser_tracked_relative_smooth_commands_use_parser_controls_test() {
  let a = svg_path.Point(0.04, 0.0)
  let b = svg_path.Point(1.04, 0.0)
  let c = svg_path.Point(2.08, 0.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.CubicBezier(
        start: a,
        control1: svg_path.Point(0.34, 1.0),
        control2: svg_path.Point(0.74, 1.0),
        end: b,
      ),
      svg_path.CubicBezier(
        start: b,
        control1: svg_path.Point(1.323, -0.945),
        control2: svg_path.Point(1.74, -1.0),
        end: c,
      ),
    ])

  let serialized =
    serialize.path_with_parser_tracked_relative_options(
      svg_path.Path([subpath]),
      serialize.relative_decimal_options(1),
    )
  assert string.contains(serialized, " s ")
}

pub fn parser_tracked_relative_smooth_quadratic_uses_parser_control_test() {
  let a = svg_path.Point(0.04, 0.0)
  let b = svg_path.Point(1.04, 0.0)
  let c = svg_path.Point(2.08, 0.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.QuadraticBezier(
        start: a,
        control: svg_path.Point(0.54, 1.0),
        end: b,
      ),
      svg_path.QuadraticBezier(
        start: b,
        control: svg_path.Point(1.513, -0.945),
        end: c,
      ),
    ])

  let serialized =
    serialize.path_with_parser_tracked_relative_options(
      svg_path.Path([subpath]),
      serialize.relative_decimal_options(1),
    )
  assert string.contains(serialized, " t ")
}

pub fn parser_tracked_relative_collapsed_arc_preserves_arc_fields_test() {
  let start = svg_path.Point(0.04, 0.0)
  let end = svg_path.Point(0.049, 0.0)
  let arc =
    svg_path.Arc(
      start:,
      radius: svg_path.Point(2.0, 1.0),
      x_axis_rotation: 15.0,
      large_arc: False,
      sweep: True,
      end:,
    )
  let assert Ok(subpath) = svg_path.subpath([arc])

  assert serialize.path_with_parser_tracked_relative_options(
      svg_path.Path([subpath]),
      serialize.relative_decimal_options(1),
    )
    == "m 0 0 a 2 1 15 0 1 0 0"
}

pub fn parser_tracked_relative_unstable_cubic_uses_progressive_correction_test() {
  let point = svg_path.Point(0.04, 0.0)
  let cubic =
    svg_path.CubicBezier(
      start: point,
      control1: svg_path.Point(0.34, 1.0),
      control2: svg_path.Point(0.34, -1.0),
      end: point,
    )
  let assert Ok(subpath) = svg_path.subpath([cubic])

  assert serialize.path_with_parser_tracked_relative_options(
      svg_path.Path([subpath]),
      serialize.relative_decimal_options(1),
    )
    == "m 0 0 c 0.3 1 0.3 -1 0 0"
}

pub fn parser_tracked_relative_serialization_is_stable_after_parsing_test() {
  let source = "M 0.04 0 C 0.34 1 0.74 1 1.04 0 A 2 1 15 0 1 2.08 0 L 2.42 0.34"
  let assert Ok(path) = parse.path(source)
  let options = serialize.relative_decimal_options(1)
  let once = serialize.path_with_parser_tracked_relative_options(path, options)
  let assert Ok(reparsed) = parse.path(once)
  let twice =
    serialize.path_with_parser_tracked_relative_options(reparsed, options)

  assert once == twice
}

pub fn parser_tracked_relative_full_arc_is_subdivided_test() {
  let point = svg_path.Point(0.34, 0.0)
  let arc =
    svg_path.Arc(
      start: point,
      radius: svg_path.Point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: point,
    )
  let assert Ok(subpath) = svg_path.subpath([arc])
  let serialized =
    serialize.path_with_parser_tracked_relative_options(
      svg_path.Path([subpath]),
      serialize.relative_decimal_options(1),
    )

  assert string.split(serialized, on: "a") |> list.length == 3
  let assert Ok(svg_path.Path([parsed])) = parse.path(serialized)
  let assert [
    svg_path.Arc(
      start: _,
      radius: _,
      x_axis_rotation: _,
      large_arc: _,
      sweep: _,
      end: _,
    ),
    svg_path.Arc(
      start: _,
      radius: _,
      x_axis_rotation: _,
      large_arc: _,
      sweep: _,
      end: _,
    ),
  ] = svg_path.subpath_segments(parsed)
}

fn result_try_set_closed_with_bridge(
  result_subpath: Result(svg_path.Subpath, svg_path.Error),
) -> Result(svg_path.Subpath, svg_path.Error) {
  case result_subpath {
    Ok(subpath) ->
      svg_path.subpath_set_closed_with(
        subpath,
        closed: True,
        policy: svg_path.Bridge,
      )
    Error(error) -> Error(error)
  }
}

fn result_try_set_closed_true(
  result_subpath: Result(svg_path.Subpath, svg_path.Error),
) -> Result(svg_path.Subpath, svg_path.Error) {
  case result_subpath {
    Ok(subpath) -> svg_path.subpath_set_closed(subpath, closed: True)
    Error(error) -> Error(error)
  }
}
