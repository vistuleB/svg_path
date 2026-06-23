import gleeunit
import svg_path
import svg_path/serialize

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn empty_path_serializes_to_empty_string_test() {
  assert serialize.path(svg_path.empty_path()) == ""
}

pub fn empty_subpath_serializes_to_empty_string_test() {
  assert serialize.subpath(svg_path.empty_subpath()) == ""
}

pub fn path_ignores_empty_subpaths_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let assert Ok(subpath) = svg_path.subpath([svg_path.Line(start: a, end: b)])
  let path =
    svg_path.Path([
      svg_path.empty_subpath(),
      subpath,
      svg_path.empty_subpath(),
    ])

  assert serialize.path(path) == "M 0 0 H 10"
}

pub fn open_subpath_serializes_absolute_commands_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0, 20.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert serialize.subpath(subpath) == "M 0 0 H 10 V 20"
}

pub fn closed_subpath_serializes_with_z_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0, 20.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])
    |> result_try_set_closed_with_bridge

  assert serialize.subpath(subpath) == "M 0 0 H 10 V 20 Z"
}

pub fn closed_subpath_keeps_final_curve_before_z_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 10.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.QuadraticBezier(start: b, control: c, end: a),
    ])
    |> result_try_set_closed_true

  assert serialize.subpath(subpath) == "M 0 0 H 10 Q 20 10 0 0 Z"
}

pub fn closed_subpath_keeps_final_zero_length_line_test() {
  let a = svg_path.point(0.0, 0.0)
  let subpath =
    svg_path.assert_subpath([
      svg_path.Line(start: a, end: a),
    ])
    |> svg_path.assert_set_closed(closed: True)

  assert serialize.subpath(subpath) == "M 0 0 H 0 Z"
}

pub fn closed_subpath_keeps_final_zero_length_line_after_curve_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.QuadraticBezier(start: a, control: b, end: a),
      svg_path.Line(start: a, end: a),
    ])
    |> result_try_set_closed_true

  assert serialize.subpath(subpath) == "M 0 0 Q 10 0 0 0 H 0 Z"
}

pub fn relative_closed_subpath_keeps_final_zero_length_line_test() {
  let a = svg_path.point(10.0, 10.0)
  let b = svg_path.point(20.0, 10.0)
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
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 10.0)
  let d = svg_path.point(30.0, 0.0)
  let e = svg_path.point(40.0, 20.0)
  let radius = svg_path.point(5.0, 8.0)
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
  let a = svg_path.point(0.0, 1.2)
  let b = svg_path.point(10.234, -20.235)
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
  let a = svg_path.point(0.0, 1.2)
  let b = svg_path.point(10.234, -20.235)
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
  let a = svg_path.point(1.0, 1.2)
  let b = svg_path.point(10.0, -20.0)

  assert serialize.segment_with_options(
      svg_path.Line(start: a, end: b),
      options: serialize.fixed_decimal_options(3),
    )
    == "M 1.000 1.200 L 10.000 -20.000"
}

pub fn fixed_decimal_options_can_use_zero_places_test() {
  let a = svg_path.point(0.4, 1.5)
  let b = svg_path.point(10.49, -20.5)

  assert serialize.segment_with_options(
      svg_path.Line(start: a, end: b),
      options: serialize.fixed_decimal_options(0),
    )
    == "M 0 2 L 10 -21"
}

pub fn left_padding_pads_serialized_numbers_test() {
  let a = svg_path.point(0.0, -2.0)
  let b = svg_path.point(12.2, 10.2)

  assert serialize.segment_with_options(
      svg_path.Line(start: a, end: b),
      options: serialize.fixed_decimal_options(1)
        |> serialize.with_left_padding(serialize.LeftPadding(3)),
    )
    == "M   0.0  -2.0 L  12.2  10.2"
}

pub fn auto_left_padding_aligns_serialized_path_numbers_test() {
  let a = svg_path.point(0.0, -5.0)
  let b = svg_path.point(120.0, 10.0)
  let c = svg_path.point(2.0, -30.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.fixed_decimal_options(1)
        |> serialize.with_left_padding(serialize.AutoLeftPadding),
    )
    == "M   0.0  -5.0 L 120.0  10.0 L   2.0 -30.0"
}

pub fn minimize_whitespace_removes_command_spacing_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0, 20.0)
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
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 10.0)
  let c = svg_path.point(20.0, 20.0)
  let d = svg_path.point(30.0, 30.0)
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
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let d = svg_path.point(20.0, 10.0)
  let e = svg_path.point(20.0, 20.0)
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
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 10.0)
  let d = svg_path.point(30.0, 0.0)
  let e = svg_path.point(40.0, 10.0)
  let f = svg_path.point(50.0, 0.0)
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
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 0.0)
  let radius = svg_path.point(5.0, 5.0)
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
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 10.0)
  let c = svg_path.point(20.0, 20.0)
  let d = svg_path.point(100.0, 100.0)
  let e = svg_path.point(110.0, 110.0)
  let f = svg_path.point(120.0, 120.0)
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
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 10.0)
  let c = svg_path.point(20.0, 20.0)
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
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 10.0)
  let c = svg_path.point(20.0, 20.0)
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
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 10.0)
  let c = svg_path.point(100.0, 100.0)
  let d = svg_path.point(110.0, 110.0)
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
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 10.0)
  let d = svg_path.point(30.0, 0.0)
  let e = svg_path.point(40.0, 10.0)
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
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(20.0, 10.0)
  let d = svg_path.point(30.0, 0.0)
  let e = svg_path.point(40.0, 10.0)
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
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 10.0)
  let c = svg_path.point(20.0, 20.0)
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
  let a = svg_path.point(20.0, -30.0)
  let b = svg_path.point(140.0, 20.0)
  let c = svg_path.point(480.0, -60.0)
  let d = svg_path.point(840.0, -90.0)
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.CubicBezier(
        start: a,
        control1: svg_path.point(-15.0, 40.0),
        control2: svg_path.point(80.0, -90.0),
        end: b,
      ),
      svg_path.CubicBezier(
        start: b,
        control1: svg_path.point(260.0, 30.0),
        control2: svg_path.point(-320.0, 45.0),
        end: c,
      ),
      svg_path.CubicBezier(
        start: c,
        control1: svg_path.point(600.5, -70.25),
        control2: svg_path.point(720.0, 80.0),
        end: d,
      ),
    ])

  assert serialize.subpath_with_options(
      subpath,
      options: serialize.fixed_decimal_options(2)
        |> serialize.with_left_padding(serialize.AutoLeftPadding)
        |> serialize.with_commas(True)
        |> serialize.repeat_commands(False)
        |> serialize.with_newlines(serialize.AtSegments),
    )
    == "M\n  20.00, -30.00 C\n -15.00,  40.00   80.00, -90.00  140.00,  20.00\n 260.00,  30.00 -320.00,  45.00  480.00, -60.00\n 600.50, -70.25  720.00,  80.00  840.00, -90.00"
}

pub fn commas_apply_to_arc_radius_and_endpoint_pairs_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.point(10.0, 20.0),
      radius: svg_path.point(5.0, 8.0),
      x_axis_rotation: 45.0,
      large_arc: True,
      sweep: False,
      end: svg_path.point(13.0, 18.0),
    )

  assert serialize.segment_with_options(
      arc,
      options: serialize.relative_decimal_options(0)
        |> serialize.with_commas(True),
    )
    == "m 10,20 a 5,8 45 1 0 3,-2"
}

pub fn relative_options_use_relative_line_commands_test() {
  let a = svg_path.point(10.0, 20.0)
  let b = svg_path.point(13.0, 18.0)

  assert serialize.segment_with_options(
      svg_path.Line(start: a, end: b),
      options: serialize.relative_decimal_options(0),
    )
    == "m 10 20 l 3 -2"
}

pub fn relative_options_use_relative_curve_commands_test() {
  let start = svg_path.point(10.0, 20.0)
  let quadratic =
    svg_path.QuadraticBezier(
      start: start,
      control: svg_path.point(12.0, 23.0),
      end: svg_path.point(15.0, 25.0),
    )
  let cubic =
    svg_path.CubicBezier(
      start: start,
      control1: svg_path.point(11.0, 21.0),
      control2: svg_path.point(14.0, 24.0),
      end: svg_path.point(18.0, 28.0),
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
      start: svg_path.point(10.0, 20.0),
      radius: svg_path.point(5.0, 8.0),
      x_axis_rotation: 45.0,
      large_arc: True,
      sweep: False,
      end: svg_path.point(13.0, 18.0),
    )

  assert serialize.segment_with_options(
      arc,
      options: serialize.relative_decimal_options(0),
    )
    == "m 10 20 a 5 8 45 1 0 3 -2"
}

pub fn relative_minimize_whitespace_removes_command_spacing_test() {
  let a = svg_path.point(10.0, 20.0)
  let b = svg_path.point(13.0, 18.0)

  assert serialize.segment_with_options(
      svg_path.Line(start: a, end: b),
      options: serialize.relative_decimal_options(0)
        |> serialize.minimize_whitespace,
    )
    == "m10 20l3 -2"
}

pub fn relative_repeat_commands_false_omits_repeated_commands_test() {
  let a = svg_path.point(10.0, 20.0)
  let b = svg_path.point(13.0, 18.0)
  let c = svg_path.point(16.0, 16.0)
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
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 10.0)
  let c = svg_path.point(20.0, 20.0)
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

pub fn relative_options_make_moves_relative_between_subpaths_test() {
  let a = svg_path.point(10.0, 10.0)
  let b = svg_path.point(20.0, 10.0)
  let c = svg_path.point(25.0, 30.0)
  let d = svg_path.point(30.0, 30.0)
  let assert Ok(first) = svg_path.subpath([svg_path.Line(start: a, end: b)])
  let assert Ok(second) = svg_path.subpath([svg_path.Line(start: c, end: d)])

  assert serialize.path_with_options(
      svg_path.Path([first, svg_path.empty_subpath(), second]),
      options: serialize.relative_decimal_options(0),
    )
    == "m 10 10 h 10 m 5 20 h 5"
}

pub fn relative_options_move_from_closed_subpath_start_after_z_test() {
  let a = svg_path.point(10.0, 10.0)
  let b = svg_path.point(20.0, 10.0)
  let c = svg_path.point(30.0, 10.0)
  let d = svg_path.point(40.0, 10.0)
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
  let a = svg_path.point(10.0, 10.0)
  let b = svg_path.point(20.0, 10.0)
  let c = svg_path.point(25.0, 30.0)
  let d = svg_path.point(30.0, 30.0)
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
      start: svg_path.point(0.4, 1.5),
      end: svg_path.point(10.49, -20.5),
    )

  assert serialize.segment_with_options(
      segment,
      options: serialize.decimal_options(-3),
    )
    == "M 0 2 L 10 -21"
}

pub fn rounded_absolute_line_uses_h_or_v_after_formatting_test() {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.000001)
  let c = svg_path.point(10.000001, 20.0)
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
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.000001)
  let c = svg_path.point(10.000001, 20.0)
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

fn result_try_set_closed_with_bridge(
  result_subpath: Result(svg_path.Subpath, svg_path.Error),
) -> Result(svg_path.Subpath, svg_path.Error) {
  case result_subpath {
    Ok(subpath) ->
      svg_path.set_closed_with(subpath, closed: True, policy: svg_path.Bridge)
    Error(error) -> Error(error)
  }
}

fn result_try_set_closed_true(
  result_subpath: Result(svg_path.Subpath, svg_path.Error),
) -> Result(svg_path.Subpath, svg_path.Error) {
  case result_subpath {
    Ok(subpath) -> svg_path.set_closed(subpath, closed: True)
    Error(error) -> Error(error)
  }
}
