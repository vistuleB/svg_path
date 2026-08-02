//// Path-data cases adapted from Web Platform Tests.
////
//// Upstream directory:
//// https://github.com/web-platform-tests/wpt/tree/master/svg/path/parsing
////
//// Keep the upstream filename beside each group so changes can be compared
//// against WPT. These tests translate browser geometry checks into the
//// library's canonical serialized path representation.

import gleam/list
import gleeunit
import svg_path
import svg_path/parse
import svg_path/serialize

pub fn main() -> Nil {
  gleeunit.main()
}

// WPT: svg/path/parsing/whitespace-basic.html
pub fn wpt_whitespace_basic_cases_test() {
  [
    "M 100 100 L 200 200",
    "M\t100\t100\tL\t200\t200",
    "M\n100\n100\nL\n200\n200",
    "M\r100\r100\rL\r200\r200",
    "M\u{000c}100\u{000c}100\u{000c}L\u{000c}200\u{000c}200",
    "M \t\n\r\u{000c} 100 \t\n\r\u{000c} 100 \t\n\r\u{000c} L \t\n\r\u{000c} 200 \t\n\r\u{000c} 200",
    "   \t\n\r  M 100,100 L 200,200",
    "M 100,100 L 200,200   \t\n\r  ",
    "M100,100L200,200",
    "M     100     100     L     200     200",
    "M 100 , 100 L 200 , 200",
    "M 100,100 L 200,200",
    "M 100 ,100 L 200 ,200",
    "M 100, 100 L 200, 200",
  ]
  |> list.each(fn(source) {
    let assert Ok(path) = parse.path(source)
    assert serialize.path(path) == "M 100 100 L 200 200"
  })
}

// WPT: svg/path/parsing/arc-commands.html
pub fn wpt_arc_command_syntax_cases_test() {
  [
    "M 100,100 A 50,50 0 0,1 200,100",
    "M 100,100 A 50,50 0 01 200,100",
    "M 100,100 A 50,50 0 0 1 200,100",
  ]
  |> list.each(fn(source) {
    let assert Ok(path) = parse.path(source)
    assert serialize.path(path) == "M 100 100 A 50 50 0 0 1 200 100"
  })
}

// WPT: svg/path/parsing/arc-commands.html
pub fn wpt_repeated_arc_arguments_test() {
  let assert Ok(path) =
    parse.path("M 50,350 A 25,25 0 0,1 100,350 25,25 0 0,1 150,350")

  assert serialize.path(path)
    == "M 50 350 A 25 25 0 0 1 100 350 A 25 25 0 0 1 150 350"
}

// WPT: svg/path/parsing/arc-commands.html
pub fn wpt_negative_arc_radius_uses_absolute_value_test() {
  let assert Ok(path) = parse.path("M 200,300 A -50,50 0 0,1 300,300")

  assert serialize.path(path) == "M 200 300 A 50 50 0 0 1 300 300"
}

// WPT: svg/path/parsing/arc-commands.html
pub fn wpt_zero_arc_radius_becomes_line_test() {
  let assert Ok(path) = parse.path("M 200,250 A 0,0 0 0,1 300,250")

  assert serialize.path(path) == "M 200 250 H 300"
}

// SVG 2, 9.5.1: an arc whose endpoint equals its start is omitted.
pub fn svg_same_endpoint_arc_is_omitted_test() {
  let assert Ok(path) = parse.path("M 20,30 A 10,10 0 1,1 20,30")

  assert serialize.path(path) == "M 20 30"
}

// WPT: svg/path/parsing/number-edge-case-consecutive.html
pub fn wpt_consecutive_signed_number_cases_test() {
  [
    #("M 100-200 L 200-100", "M 100 -200 L 200 -100"),
    #("M 50+100 L 150+200", "M 50 100 L 150 200"),
    #("M 10-20+30-40", "M 10 -20 L 30 -40"),
  ]
  |> list.each(fn(example) {
    let #(source, expected) = example
    let assert Ok(path) = parse.path(source)
    assert serialize.path(path) == expected
  })
}

// WPT: svg/path/parsing/number-edge-case-decimal.html
pub fn wpt_consecutive_decimal_number_cases_test() {
  [
    #("M 0.6.5 L 10.5.6", "M 0.6 0.5 L 10.5 0.6"),
    #("M .5.6 L .7.8", "M 0.5 0.6 L 0.7 0.8"),
    #("M 1.2.3.4.5", "M 1.2 0.3 L 0.4 0.5"),
  ]
  |> list.each(fn(example) {
    let #(source, expected) = example
    let assert Ok(path) = parse.path(source)
    assert serialize.path(path) == expected
  })
}

// WPT: svg/path/parsing/number-exponent.html
pub fn wpt_exponent_number_cases_test() {
  [
    #("M 1e2,1e2 L 2E2,1.5e2", "M 100 100 L 200 150"),
    #("M 1e+2,2e+1", "M 100 20"),
    #("M 1e-1,5e-2", "M 0.1 0.05"),
    #("M 1.5e2,2.5e1", "M 150 25"),
    #("M 5e0,10e0", "M 5 10"),
    #("M 1e2-1e2", "M 100 -100"),
  ]
  |> list.each(fn(example) {
    let #(source, expected) = example
    let assert Ok(path) = parse.path(source)
    assert serialize.path(path) == expected
  })
}

// WPT: svg/path/parsing/number-error-trailing-decimal.html
pub fn wpt_trailing_decimal_cases_are_rejected_test() {
  [
    "M 10,10 L 50,50 L 23.,100",
    "M 0,0 L 10,10 L 20.,30.",
    "M 0,0 L 15. 20",
    "M 100,100 L 150,100 L 150,150 L 100,150 Z M 200.,200.",
  ]
  |> list.each(fn(source) {
    let assert Error(_) = parse.path(source)
  })
}

// WPT: svg/path/parsing/error-handling.html
// The browser suite verifies rendering of the valid prefix. This strict parser
// returns an error instead of returning a partial Path.
pub fn wpt_invalid_path_data_cases_are_rejected_test() {
  [
    "M 10,10 L 50,50 X 100,100",
    "M 10,60 L 50,60 L 100",
    "M 10,110 L 50,110 60,110 70",
    "M 10,160 L 50,160 C 60,150 70,170",
    "M 10,210 L 50,210 A 25,25 0 2,1 100,210",
    "L 100,260",
    "M 10,310 L 50,310 X 60,310 Y 70,310",
    "M 0,0 L 50,50 C 60,40 70,60 80,50 C 90,40 100,60",
    "M 10,360 L 50,360 L 60 L 100,360",
    "M 100,10 x 150,10",
  ]
  |> list.each(fn(source) {
    let assert Error(_) = parse.path(source)
  })
}

// WPT: svg/path/parsing/error-handling.html
pub fn wpt_empty_and_none_path_data_disable_rendering_test() {
  assert parse.path("") == Ok(svg_path.path_empty())
  assert parse.path("none") == Ok(svg_path.path_empty())
}

// WPT: svg/path/parsing/moveto-absolute.html
pub fn wpt_absolute_moveto_cases_test() {
  [
    #("M 100,100", "M 100 100"),
    #("M 50,50 150,50 150,150 50,150 Z", "M 50 50 H 150 V 150 H 50 Z"),
    #("M 10,10 20,20 30,30", "M 10 10 L 20 20 L 30 30"),
    #("M100,100", "M 100 100"),
    #("M 10,10 L 20,20 M 30,30 L 40,40", "M 10 10 L 20 20 M 30 30 L 40 40"),
    #("M 100 , 200", "M 100 200"),
    #("M 100 200", "M 100 200"),
  ]
  |> assert_canonical_cases
}

// WPT: svg/path/parsing/moveto-relative.html
pub fn wpt_relative_moveto_cases_test() {
  [
    #("m 100,100 L 150,150", "M 100 100 L 150 150"),
    #("M 50,50 L 100,50 m 0,50 L 150,150", "M 50 50 H 100 M 100 100 L 150 150"),
    #("M 0,0 L 50,0 m 10,10 L 100,50", "M 0 0 H 50 M 60 10 L 100 50"),
    #("m 10,10 20,20 30,30", "M 10 10 L 30 30 L 60 60"),
    #("M 100,100 m -50,-50 L 100,100", "M 100 100 M 50 50 L 100 100"),
    #("M 50,50 m 0,0 L 100,100", "M 50 50 M 50 50 L 100 100"),
    #(
      "M 0,0 L 10,10 m 5,5 m 5,5 L 30,30",
      "M 0 0 L 10 10 M 15 15 M 20 20 L 30 30",
    ),
  ]
  |> assert_canonical_cases
}

// WPT: svg/path/parsing/lineto-commands.html
pub fn wpt_lineto_command_cases_test() {
  [
    #("M 50,50 L 150,150", "M 50 50 L 150 150"),
    #("M 50,50 l 100,100", "M 50 50 L 150 150"),
    #("M 50,200 H 150", "M 50 200 H 150"),
    #("M 200,50 V 150", "M 200 50 V 150"),
    #("M 0,0 L 10,0 20,0 30,0", "M 0 0 H 10 H 20 H 30"),
    #("M 0,50 H 10 20 30", "M 0 50 H 10 H 20 H 30"),
    #("M 50,0 V 10 20 30", "M 50 0 V 10 V 20 V 30"),
    #("M 50,50 h 100", "M 50 50 H 150"),
    #("M 50,50 v 100", "M 50 50 V 150"),
    #("M 100,100 h -50 v -50", "M 100 100 H 50 V 50"),
    #("M 50,50 L 100,50 L 100,100 L 50,100 Z", "M 50 50 H 100 V 100 H 50 Z"),
    #("M 0,0 L 50,0 l 50,0 L 150,0", "M 0 0 H 50 H 100 H 150"),
    #("M 0,0 L 100,0 L 100,100 z", "M 0 0 H 100 V 100 Z"),
  ]
  |> assert_canonical_cases
}

// WPT: svg/path/parsing/curveto-commands.html
pub fn wpt_cubic_curveto_command_cases_test() {
  [
    #("M 50,50 C 100,25 150,75 200,50", "M 50 50 C 100 25 150 75 200 50"),
    #("M 50,50 c 50,-25 100,25 150,0", "M 50 50 C 100 25 150 75 200 50"),
    #(
      "M 0,50 C 25,0 50,0 75,50 100,100 125,100 150,50",
      "M 0 50 C 25 0 50 0 75 50 S 125 100 150 50",
    ),
    #(
      "M 50,150 C 75,100 100,100 125,150 S 175,200 200,150",
      "M 50 150 C 75 100 100 100 125 150 S 175 200 200 150",
    ),
    #(
      "M 50,50 C 75,25 100,75 125,50 s 50,-25 75,0",
      "M 50 50 C 75 25 100 75 125 50 S 175 25 200 50",
    ),
    #("M 50,50 S 100,25 150,50", "M 50 50 S 100 25 150 50"),
    #(
      "M 0,50 C 25,0 50,0 75,50 S 125,100 150,50 175,0 200,50",
      "M 0 50 C 25 0 50 0 75 50 S 125 100 150 50 S 175 0 200 50",
    ),
    #("M 50 50 C 75 25 100 75 125 50", "M 50 50 C 75 25 100 75 125 50"),
    #("M 50,50 C 75,25,100,75,125,50", "M 50 50 C 75 25 100 75 125 50"),
  ]
  |> assert_canonical_cases
}

// WPT: svg/path/parsing/quadratic-bezier-commands.html
pub fn wpt_quadratic_curveto_command_cases_test() {
  [
    #("M 50,50 Q 100,25 150,50", "M 50 50 Q 100 25 150 50"),
    #("M 50,50 q 50,-25 100,0", "M 50 50 Q 100 25 150 50"),
    #("M 0,50 Q 25,25 50,50 75,75 100,50", "M 0 50 Q 25 25 50 50 T 100 50"),
    #(
      "M 50,150 Q 75,125 100,150 T 150,150",
      "M 50 150 Q 75 125 100 150 T 150 150",
    ),
    #("M 50,50 Q 75,25 100,50 t 50,0", "M 50 50 Q 75 25 100 50 T 150 50"),
    #("M 50,200 T 100,200", "M 50 200 T 100 200"),
    #(
      "M 0,150 Q 25,125 50,150 T 100,150 150,150",
      "M 0 150 Q 25 125 50 150 T 100 150 T 150 150",
    ),
    #(
      "M 0,200 Q 12.5,187.5 25,200 T 50,200 T 75,200",
      "M 0 200 Q 12.5 187.5 25 200 T 50 200 T 75 200",
    ),
    #("M 50 250 Q 75 225 100 250", "M 50 250 Q 75 225 100 250"),
    #("M 50,300 Q 75,275,100,300", "M 50 300 Q 75 275 100 300"),
    #(
      "M 0,250 C 12.5,237.5 25,237.5 37.5,250 T 75,250",
      "M 0 250 C 12.5 237.5 25 237.5 37.5 250 T 75 250",
    ),
    #(
      "M 0,300 Q 12.5,287.5 25,300 T 50,300 Q 62.5,287.5 75,300",
      "M 0 300 Q 12.5 287.5 25 300 T 50 300 T 75 300",
    ),
  ]
  |> assert_canonical_cases
}

fn assert_canonical_cases(cases: List(#(String, String))) -> Nil {
  cases
  |> list.each(fn(example) {
    let #(source, expected) = example
    let assert Ok(path) = parse.path(source)
    assert serialize.path(path) == expected
  })
}
