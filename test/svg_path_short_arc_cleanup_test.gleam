import gleam/list
import gleam/option
import svg_path.{Arc, Line, Point}
import svg_path/degeneracy
import svg_path/offset

fn short_arc() {
  Arc(Point(0.0, 0.0), Point(1.0, 1.0), 0.0, False, True, Point(0.00003, 0.0))
}

pub fn short_arc_cleanup_preserves_distinct_endpoints_test() {
  let arc = short_arc()
  list.each([arc, svg_path.segment_reverse(arc)], fn(segment) {
    let assert Ok(source) = svg_path.subpath([segment])
    let assert Ok(cleaned) =
      degeneracy.normalize_degenerate_segments(source, 0.001)
    assert svg_path.subpath_start(cleaned) == svg_path.segment_start(segment)
    assert svg_path.subpath_end(cleaned) == svg_path.segment_end(segment)
    let assert [Line(start:, end:)] = svg_path.subpath_segments(cleaned)
    assert start != end
    assert degeneracy.segment_linearize_if_degenerate(segment, 0.001)
      == Ok(option.Some([Line(start, end)]))
  })
}

pub fn short_arc_cleanup_keeps_offset_source_connected_test() {
  let arc = short_arc()
  let assert Ok(source) =
    svg_path.subpath([
      Line(Point(-1.0, 0.0), arc.start),
      arc,
      Line(svg_path.segment_end(arc), Point(0.00003, 1.0)),
    ])
  list.each([source, svg_path.subpath_reverse(source)], fn(source) {
    let assert Ok(cleaned) = offset.normalize_short_source_runs(source, 0.001)
    assert svg_path.subpath_start(cleaned) == svg_path.subpath_start(source)
    assert svg_path.subpath_end(cleaned) == svg_path.subpath_end(source)
    let assert Ok(_) = svg_path.subpath(svg_path.subpath_segments(cleaned))
    let assert Ok(result) =
      offset.subpath(source, 0.1, offset.Round, offset.Butt)
    assert !list.is_empty(result.subpaths)
  })
}

pub fn short_line_cleanup_distinguishes_no_movement_test() {
  let start = Point(0.0, 0.0)
  let end = Point(0.00003, 0.0)
  let assert Ok(short) = svg_path.subpath([Line(start, end)])
  assert degeneracy.subpath_linearize_if_degenerate(short, 0.001)
    == Ok(option.Some([Line(start, end)]))
  let assert Ok(zero) = svg_path.subpath([Line(start, start)])
  assert degeneracy.subpath_linearize_if_degenerate(zero, 0.001)
    == Ok(option.Some([]))
}
