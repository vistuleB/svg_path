import gleam/list
import gleam/option.{Some}
import svg_path
import svg_path/basic_shapes
import svg_path/containment
import svg_path/offset
import svg_path/parse
import svg_path/stroke

fn subpath(source: String) {
  let assert Ok(svg_path.Path([subpath])) = parse.path(source)
  subpath
}

pub fn normalize_zero_lines_beside_arcs_test() {
  list.each(
    [
      #("M10 0L10 0A10 10 0 0 1 0 10", "M10 0A10 10 0 0 1 0 10"),
      #("M10 0A10 10 0 0 1 0 10L0 10", "M10 0A10 10 0 0 1 0 10"),
      #("M10 0L10 0A10 10 0 0 1 0 10L0 10", "M10 0A10 10 0 0 1 0 10"),
      #(
        "M10 0A10 10 0 0 1 0 10L0 10A10 10 0 0 1 -10 0",
        "M10 0A10 10 0 0 1 0 10A10 10 0 0 1 -10 0",
      ),
    ],
    fn(pair) {
      let source = subpath(pair.0)
      let expected = subpath(pair.1)
      list.each(
        [
          #(source, expected),
          #(
            svg_path.subpath_reverse(source),
            svg_path.subpath_reverse(expected),
          ),
        ],
        fn(pair) {
          assert offset.normalize_source_subpath(
              pair.0,
              offset.default_options(),
            )
            == Ok(pair.1)
          list.each([offset.Butt, offset.RoundCap, offset.Square], fn(cap) {
            let assert Ok(expected) =
              stroke.subpath(pair.1, width: 2.0, join: offset.Round, cap:)
            assert stroke.subpath(pair.0, width: 2.0, join: offset.Round, cap:)
              == Ok(expected)
          })
        },
      )
    },
  )
}

pub fn rounded_rectangle_maximum_radius_strokes_test() {
  list.each([90.0, 100.0], fn(radius) {
    let assert Ok(source) =
      basic_shapes.rect(
        x: 0.0,
        y: 0.0,
        width: 300.0,
        height: 180.0,
        rx: Some(radius),
        ry: Some(radius),
      )
    let cleaned =
      svg_path.subpath_segments(source)
      |> list.filter(fn(segment) {
        case segment {
          svg_path.Line(start:, end:) -> start != end
          _ -> True
        }
      })
      |> svg_path.subpath_assert
      |> svg_path.subpath_assert_close
    let assert Ok(expected) =
      stroke.subpath(cleaned, width: 30.0, join: offset.Round, cap: offset.Butt)
    let assert Ok(actual) =
      stroke.subpath(source, width: 30.0, join: offset.Round, cap: offset.Butt)
    assert actual == expected
    // Three explicit seam probes from Paper.js HitResult.js #1207.
    list.each(
      [
        svg_path.Point(90.0, -10.0),
        svg_path.Point(90.0, 190.0),
        svg_path.Point(-10.0, 90.0),
      ],
      fn(point) {
        let assert Ok(classification) =
          containment.path_containment(point, actual, svg_path.Nonzero)
        assert classification != svg_path.Outside
      },
    )
  })
}

pub fn zero_line_cleanup_preserves_degenerate_input_contracts_test() {
  let point_line =
    svg_path.Line(svg_path.Point(3.0, 4.0), svg_path.Point(3.0, 4.0))
  assert offset.segment(point_line, offset: 1.0, join: offset.Round)
    == Error(offset.DegenerateTangent(0.0))
  let line =
    svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(0.0000000001, 0.0))
  let source = svg_path.subpath_assert([line])
  assert offset.normalize_source_subpath(source, offset.default_options())
    == Ok(source)
  let invalid = subpath("M0 0A10 10 0 0 1 0 0")
  let with_zero = subpath("M0 0L0 0A10 10 0 0 1 0 0")
  let assert Error(expected) =
    stroke.subpath(invalid, width: 2.0, join: offset.Round, cap: offset.Butt)
  assert stroke.subpath(
      with_zero,
      width: 2.0,
      join: offset.Round,
      cap: offset.Butt,
    )
    == Error(expected)
}
