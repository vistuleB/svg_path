import gleam/list
import svg_path.{Arc, Line, Point}
import svg_path/offset

pub fn collapsed_arc_between_tangent_lines_test() {
  let assert Ok(source) =
    svg_path.subpath([
      Line(Point(45.0, -100.0), Point(45.0, 0.0)),
      Arc(
        Point(45.0, 0.0),
        Point(45.0, 45.0),
        0.0,
        False,
        True,
        Point(0.0, 45.0),
      ),
      Line(Point(0.0, 45.0), Point(-100.0, 45.0)),
    ])
  list.each([False, True], fn(reverse) {
    let #(source, distance) = case reverse {
      False -> #(source, -45.0)
      True -> #(svg_path.subpath_reverse(source), 45.0)
    }
    let assert Ok(raw) =
      offset.subpath_untrimmed_with(
        source,
        distance,
        offset.Round,
        offset.default_options(),
      )
    let expected = [
      Line(Point(0.0, -100.0), Point(0.0, 0.0)),
      Line(Point(0.0, 0.0), Point(-100.0, 0.0)),
    ]
    let assert Ok(expected) = svg_path.subpath(expected)
    let expected = case reverse {
      False -> expected
      True -> svg_path.subpath_reverse(expected)
    }
    assert raw == expected
    let assert Ok(trimmed) =
      offset.subpath(source, distance, offset.Round, offset.Butt)
    assert svg_path.path_subpaths(trimmed) == [expected]
  })
}

pub fn collapsed_arc_between_corners_keeps_both_joins_test() {
  let assert Ok(source) =
    svg_path.subpath([
      Line(Point(130.0, 0.0), Point(230.0, 0.0)),
      Arc(
        Point(230.0, 0.0),
        Point(45.0, 45.0),
        0.0,
        False,
        True,
        Point(320.0, 0.0),
      ),
      Line(Point(320.0, 0.0), Point(420.0, 0.0)),
    ])
  list.each([False, True], fn(reverse) {
    let #(source, distance) = case reverse {
      False -> #(source, -45.0)
      True -> #(svg_path.subpath_reverse(source), 45.0)
    }
    let assert Ok(raw) =
      offset.subpath_untrimmed_with(
        source,
        distance,
        offset.Round,
        offset.default_options(),
      )
    let assert [Line(..), Arc(..), Arc(..), Line(..)] =
      svg_path.subpath_segments(raw)
    assert list.all(svg_path.subpath_segments(raw), fn(s) {
      svg_path.segment_start(s) != svg_path.segment_end(s)
    })
    let assert Ok(_) =
      offset.subpath(source, distance, offset.Round, offset.Butt)
  })
}
