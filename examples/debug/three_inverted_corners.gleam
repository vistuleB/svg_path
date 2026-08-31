//// A 4 x 4 square-like loop with two inward circular corners and two diagonals.

import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/list
import gleam/string
import svg_path
import svg_path/offset
import svg_path/serialize

const output_1_2 = "examples/debug/three_inverted_corners_1_2.svg"

const output_1_8 = "examples/debug/three_inverted_corners_1_8.svg"

const output_1_8_round = "examples/debug/three_inverted_corners_1_8_round.svg"

pub fn subpath() -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.Line(
      start: svg_path.Point(1.0, 0.0),
      end: svg_path.Point(3.0, 0.0),
    ),
    inward_arc(svg_path.Point(3.0, 0.0), svg_path.Point(4.0, 1.0)),
    svg_path.Line(
      start: svg_path.Point(4.0, 1.0),
      end: svg_path.Point(4.0, 3.0),
    ),
    svg_path.Line(
      start: svg_path.Point(4.0, 3.0),
      end: svg_path.Point(3.0, 4.0),
    ),
    svg_path.Line(
      start: svg_path.Point(3.0, 4.0),
      end: svg_path.Point(1.0, 4.0),
    ),
    inward_arc(svg_path.Point(1.0, 4.0), svg_path.Point(0.0, 3.0)),
    svg_path.Line(
      start: svg_path.Point(0.0, 3.0),
      end: svg_path.Point(0.0, 1.0),
    ),
    svg_path.Line(
      start: svg_path.Point(0.0, 1.0),
      end: svg_path.Point(1.0, 0.0),
    ),
  ])
  |> svg_path.subpath_assert_set_closed(closed: True)
}

fn inward_arc(start: svg_path.Point, end: svg_path.Point) -> svg_path.Segment {
  circular_arc(start, end, sweep: False)
}

fn circular_arc(
  start: svg_path.Point,
  end: svg_path.Point,
  sweep sweep: Bool,
) -> svg_path.Segment {
  svg_path.Arc(
    start:,
    radius: svg_path.Point(1.0, 1.0),
    x_axis_rotation: 0.0,
    large_arc: False,
    sweep:,
    end:,
  )
}

pub fn main() -> Nil {
  let source = subpath()
  let assert Ok(untrimmed_1_2) =
    offset.subpath_untrimmed_with(
      source,
      offset: 1.2,
      options: offset.default_options(),
    )
  let assert Ok(untrimmed_1_8) =
    offset.subpath_untrimmed_with(
      source,
      offset: 1.8,
      options: offset.default_options(),
    )
  let assert Ok(untrimmed_1_8_round) =
    offset.subpath_untrimmed_with(
      source,
      offset: 1.8,
      options: offset.Options(..offset.default_options(), join: offset.Round),
    )
  let _ =
    write_file(
      output_1_2,
      drawing(serialize.subpath(source), serialize.subpath(untrimmed_1_2)),
    )
  let _ =
    write_file(
      output_1_8,
      drawing(serialize.subpath(source), serialize.subpath(untrimmed_1_8)),
    )
  let _ =
    write_file(
      output_1_8_round,
      drawing(serialize.subpath(source), serialize.subpath(untrimmed_1_8_round)),
    )
  Nil
}

fn drawing(source_data: String, offset_data: String) -> String {
  "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"800\" height=\"800\" viewBox=\"-2.4 -2.4 8.8 8.8\">\n"
  <> "  <rect x=\"-2.4\" y=\"-2.4\" width=\"8.8\" height=\"8.8\" fill=\"white\" />\n"
  <> "  <rect x=\"0\" y=\"0\" width=\"4\" height=\"4\" fill=\"none\" stroke=\"#cbd5e1\" stroke-width=\"0.022\" stroke-dasharray=\"0.12 0.10\" />\n"
  <> "  <path d=\""
  <> source_data
  <> "\" fill=\"#dbeafe\" fill-opacity=\"0.55\" stroke=\"#1d4ed8\" stroke-width=\"0.04\" stroke-linecap=\"round\" stroke-linejoin=\"round\" />\n"
  <> endpoint_dots()
  <> "  <path d=\""
  <> offset_data
  <> "\" fill=\"none\" stroke=\"#ea580c\" stroke-width=\"0.045\" stroke-linecap=\"round\" stroke-linejoin=\"round\" />\n"
  <> "</svg>\n"
}

fn endpoint_dots() -> String {
  [
    svg_path.Point(1.0, 0.0),
    svg_path.Point(3.0, 0.0),
    svg_path.Point(4.0, 1.0),
    svg_path.Point(4.0, 3.0),
    svg_path.Point(3.0, 4.0),
    svg_path.Point(1.0, 4.0),
    svg_path.Point(0.0, 3.0),
    svg_path.Point(0.0, 1.0),
  ]
  |> list.map(fn(point) {
    "  <circle cx=\""
    <> float.to_string(point.x)
    <> "\" cy=\""
    <> float.to_string(point.y)
    <> "\" r=\"0.055\" fill=\"#111827\" />\n"
  })
  |> string.concat
}

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
