import gleeunit
import svg_path
import svg_path/inspect

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn point_inspects_as_comma_separated_coordinates_test() {
  assert inspect.point(svg_path.point(10.0, -2.5)) == "10,-2.5"
}

pub fn point_inspects_with_decimal_options_test() {
  assert inspect.point_with_options(
      svg_path.point(10.234, -2.235),
      options: inspect.decimal_options(2),
    )
    == "10.23,-2.24"
}

pub fn point_inspects_with_fixed_decimal_options_test() {
  assert inspect.point_with_options(
      svg_path.point(10.0, -2.5),
      options: inspect.fixed_decimal_options(2),
    )
    == "10.00,-2.50"
}

pub fn line_segment_inspects_on_one_line_test() {
  let segment =
    svg_path.line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(12.0, 10.0),
    )

  assert inspect.segment(segment) == "Line(start=0,0 end=12,10)"
}

pub fn segment_inspects_with_decimal_options_test() {
  let segment =
    svg_path.line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(12.234, 10.235),
    )

  assert inspect.segment_with_options(
      segment,
      options: inspect.fixed_decimal_options(1),
    )
    == "Line(start=0.0,0.0 end=12.2,10.2)"
}

pub fn segment_inspects_with_auto_left_padding_test() {
  let segment =
    svg_path.line(
      start: svg_path.point(0.0, -5.0),
      end: svg_path.point(120.0, 10.0),
    )
  let options =
    inspect.fixed_decimal_options(1)
    |> inspect.with_left_padding(inspect.AutoLeftPadding)

  assert inspect.segment_with_options(segment, options:)
    == "Line(start=000.0,-05.0 end=120.0,010.0)"
}

pub fn point_inspects_with_explicit_left_padding_test() {
  let options =
    inspect.fixed_decimal_options(1)
    |> inspect.with_left_padding(inspect.LeftPadding(4))

  assert inspect.point_with_options(svg_path.point(2.0, -3.0), options:)
    == "0002.0,-003.0"
}

pub fn curve_and_arc_segments_inspect_named_fields_test() {
  let quadratic =
    svg_path.quadratic_bezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(5.0, 10.0),
      end: svg_path.point(12.0, 10.0),
    )
  let cubic =
    svg_path.cubic_bezier(
      start: svg_path.point(0.0, 0.0),
      control1: svg_path.point(2.0, 4.0),
      control2: svg_path.point(6.0, 8.0),
      end: svg_path.point(10.0, 12.0),
    )
  let arc =
    svg_path.arc(
      start: svg_path.point(0.0, 0.0),
      radius: svg_path.point(5.0, 8.0),
      x_axis_rotation: 45.0,
      large_arc: True,
      sweep: False,
      end: svg_path.point(20.0, 0.0),
    )

  assert inspect.segment(quadratic)
    == "QuadraticBezier(start=0,0 control=5,10 end=12,10)"
  assert inspect.segment(cubic)
    == "CubicBezier(start=0,0 control1=2,4 control2=6,8 end=10,12)"
  assert inspect.segment(arc)
    == "Arc(start=0,0 radius=5,8 x_axis_rotation=45 large_arc=True sweep=False end=20,0)"
}

pub fn empty_path_and_subpath_inspect_compactly_test() {
  assert inspect.path(svg_path.empty_path()) == "Path([])"
  assert inspect.subpath(svg_path.empty_subpath()) == "Subpath(open, [])"
}

pub fn path_inspects_subpaths_and_segments_with_indentation_test() {
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(12.0, 10.0),
      ),
      svg_path.line(
        start: svg_path.point(12.0, 10.0),
        end: svg_path.point(20.0, 10.0),
      ),
    ])
    |> result_try_close_with_bridge
  let path = svg_path.from_subpath(subpath)

  assert inspect.path(path) == "Path([
  Subpath(closed, [
    Line(start=0,0 end=12,10),
    Line(start=12,10 end=20,10),
    Line(start=20,10 end=0,0)
  ])
])"
}

pub fn path_inspects_with_decimal_options_test() {
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(12.234, 10.235),
      ),
    ])
  let path = svg_path.from_subpath(subpath)

  assert inspect.path_with_options(path, options: inspect.decimal_options(1))
    == "Path([
  Subpath(open, [
    Line(start=0,0 end=12.2,10.2)
  ])
])"
}

pub fn point_code_inspects_as_copy_pasteable_gleam_test() {
  assert inspect.point_code(svg_path.point(10.0, -2.5))
    == "svg_path.point(10.0, -2.5)"
}

pub fn segment_code_inspects_as_copy_pasteable_gleam_test() {
  let segment =
    svg_path.cubic_bezier(
      start: svg_path.point(0.0, 0.0),
      control1: svg_path.point(2.0, 4.0),
      control2: svg_path.point(6.0, 8.0),
      end: svg_path.point(10.0, 12.0),
    )

  assert inspect.segment_code(segment)
    == "svg_path.cubic_bezier(start: svg_path.point(0.0, 0.0), control1: svg_path.point(2.0, 4.0), control2: svg_path.point(6.0, 8.0), end: svg_path.point(10.0, 12.0))"
}

pub fn subpath_code_inspects_as_copy_pasteable_gleam_test() {
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(12.0, 10.0),
      ),
    ])

  assert inspect.subpath_code(subpath) == "svg_path.assert_subpath([
  svg_path.line(start: svg_path.point(0.0, 0.0), end: svg_path.point(12.0, 10.0))
])"
}

pub fn closed_subpath_code_inspects_as_copy_pasteable_gleam_test() {
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(12.0, 10.0),
      ),
    ])
    |> result_try_close_with_bridge

  assert inspect.subpath_code(subpath) == "svg_path.assert_subpath([
  svg_path.line(start: svg_path.point(0.0, 0.0), end: svg_path.point(12.0, 10.0)),
  svg_path.line(start: svg_path.point(12.0, 10.0), end: svg_path.point(0.0, 0.0))
])
|> svg_path.assert_close"
}

pub fn path_code_inspects_as_copy_pasteable_gleam_test() {
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(
        start: svg_path.point(0.0, 0.0),
        end: svg_path.point(12.0, 10.0),
      ),
    ])
  let path = svg_path.from_subpath(subpath)

  assert inspect.path_code(path) == "svg_path.path([
  svg_path.assert_subpath([
    svg_path.line(start: svg_path.point(0.0, 0.0), end: svg_path.point(12.0, 10.0))
  ])
])"
}

pub fn code_inspection_respects_decimal_options_test() {
  let segment =
    svg_path.line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(12.234, 10.235),
    )

  assert inspect.segment_code_with_options(
      segment,
      options: inspect.decimal_options(1),
    )
    == "svg_path.line(start: svg_path.point(0.0, 0.0), end: svg_path.point(12.2, 10.2))"
}

pub fn code_inspection_respects_auto_left_padding_test() {
  let assert Ok(subpath) =
    svg_path.subpath([
      svg_path.line(
        start: svg_path.point(0.0, -5.0),
        end: svg_path.point(120.0, 10.0),
      ),
      svg_path.line(
        start: svg_path.point(120.0, 10.0),
        end: svg_path.point(2.0, -30.0),
      ),
    ])
  let path = svg_path.from_subpath(subpath)
  let options =
    inspect.fixed_decimal_options(1)
    |> inspect.with_left_padding(inspect.AutoLeftPadding)

  assert inspect.path_code_with_options(path, options:) == "svg_path.path([
  svg_path.assert_subpath([
    svg_path.line(start: svg_path.point(000.0, -05.0), end: svg_path.point(120.0, 010.0)),
    svg_path.line(start: svg_path.point(120.0, 010.0), end: svg_path.point(002.0, -30.0))
  ])
])"
}

fn result_try_close_with_bridge(
  result: Result(svg_path.Subpath, svg_path.Error),
) -> Result(svg_path.Subpath, svg_path.Error) {
  case result {
    Error(error) -> Error(error)
    Ok(subpath) -> svg_path.close_with(subpath, join: svg_path.Bridge)
  }
}
