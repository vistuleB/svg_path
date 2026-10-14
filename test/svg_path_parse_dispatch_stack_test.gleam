// Native parser stress tests from the follow-up to the #1493 construction audit.
// Provenance: scripts/paperjs/files/Path.js.md.
import gleam/int
import gleam/list
import gleam/string
import svg_path
import svg_path/parse

pub fn long_relative_move_sequence_test() {
  let assert Ok(svg_path.Path(subpaths)) =
    parse.path("M0 0" <> string.repeat("m1 2", times: 10_000))
  assert list.length(subpaths) == 10_001
  list.each(
    list.index_map(subpaths, fn(subpath, i) { #(subpath, i) }),
    fn(pair) {
      let #(subpath, i) = pair
      assert svg_path.subpath_segments(subpath) == []
      assert svg_path.subpath_start(subpath)
        == svg_path.Point(int.to_float(i), int.to_float(2 * i))
    },
  )
}

pub fn long_explicit_line_sequence_test() {
  let assert Ok(path) = parse.path("M0 0" <> string.repeat("h1", times: 5000))
  let assert Ok(subpath) = svg_path.path_as_subpath(path)
  let segments = svg_path.subpath_segments(subpath)
  assert list.length(segments) == 5000
  list.each(
    list.index_map(segments, fn(segment, i) { #(segment, i) }),
    fn(pair) {
      let #(segment, i) = pair
      assert segment
        == svg_path.Line(
          svg_path.Point(int.to_float(i), 0.0),
          svg_path.Point(int.to_float(i + 1), 0.0),
        )
    },
  )
}

pub fn long_mixed_command_sequence_test() {
  // All handler families, both relative and absolute, implicit repetitions,
  // smooth control reflection, compact arc flags, and closure.
  let block =
    "M0 0 1 1l1 0 0 1L4 4h1H6v1V8q1 2 3 4t2 3Q1 2 3 4T5 6c1 2 3 4 5 6s1 2 3 4C1 2 3 4 5 6S1 2 3 4a5 6 0 017 8A5 6 0 109 10z"
  let assert Ok(svg_path.Path([expected])) = parse.path(block)
  let assert Ok(svg_path.Path(subpaths)) =
    parse.path(string.repeat(block, times: 1000))
  assert list.length(subpaths) == 1000
  list.each(subpaths, fn(subpath) {
    assert subpath == expected
  })
}

pub fn repeated_close_then_draw_resets_controls_test() {
  let initial = "M10 20Q11 22 13 24T15 26C16 27 18 29 20 31Z"
  list.each(["t1 2", "s1 2 3 4", "l1 2"], fn(tail) {
    let assert Ok(expected) = parse.path(initial <> "M10 20" <> tail)
    assert parse.path(initial <> string.repeat("Zz", times: 5000) <> tail)
      == Ok(expected)
  })
}

pub fn late_command_errors_preserve_suffix_test() {
  let prefix = string.repeat("M0 0", times: 10_000)
  list.each(
    [
      #("L1", parse.ExpectedNumber, "1"),
      #("LZ", parse.ExpectedNumber, "Z"),
      #("A1 2 0 2 1 4 5", parse.ExpectedArcFlag, "2 1 4 5"),
      #("Z1", parse.ExpectedCommand, "1"),
    ],
    fn(example) {
      let #(tail, reason, remaining) = example
      assert parse.path(prefix <> tail)
        == Error(parse.ParseError(reason, remaining))
    },
  )
}
