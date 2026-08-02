//// Deterministically generated SVG path grammar boundary cases.

import gleam/int
import gleam/list
import gleeunit
import svg_path/parse

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn generated_valid_coordinate_separator_cases_test() {
  let separators = [" ", "  ", "\t", "\n", "\r", "\u{000c}", ",", " , "]
  let numbers = ["0", "-1", "+2", ".5", "-.25", "1e2", "2E-1"]

  separators
  |> list.each(fn(separator) {
    numbers
    |> list.each(fn(number) {
      let source = "M" <> number <> separator <> number
      let assert Ok(_) = parse.path(source)
    })
  })
}

pub fn generated_valid_signed_number_boundaries_test() {
  [
    "M0-1",
    "M0+1",
    "M.5-.25",
    "M1e2-2e1",
    "M1e-2+3e-4",
    "M0 0L1-2-3+4",
  ]
  |> list.each(fn(source) {
    let assert Ok(_) = parse.path(source)
  })
}

pub fn generated_valid_compact_arc_flag_cases_test() {
  [0, 1]
  |> list.each(fn(large_arc) {
    [0, 1]
    |> list.each(fn(sweep) {
      ["10 20", "-10-20", "+10+20"]
      |> list.each(fn(endpoint) {
        let source =
          "M0 0A5 8 30 "
          <> int.to_string(large_arc)
          <> int.to_string(sweep)
          <> endpoint
        let assert Ok(_) = parse.path(source)
      })
    })
  })
}

pub fn generated_invalid_comma_placement_cases_test() {
  [
    ",M0 0",
    "M,0 0",
    "M0,,0",
    "M0, ,0",
    "M0 0,",
    "M0 0,L1 1",
    "M0 0 L,1 1",
    "M0 0 Z,",
  ]
  |> list.each(fn(source) {
    let assert Error(_) = parse.path(source)
  })
}

pub fn generated_invalid_arc_flag_cases_test() {
  [-3, -2, -1, 2, 3, 4, 5, 6, 7, 8, 9]
  |> list.each(fn(flag) {
    let flag = int.to_string(flag)
    let assert Error(_) = parse.path("M0 0A5 5 0 " <> flag <> " 0 10 10")
    let assert Error(_) = parse.path("M0 0A5 5 0 0 " <> flag <> " 10 10")
  })
}
