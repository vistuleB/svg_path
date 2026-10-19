import gleam/float
import gleam/list
import svg_path.{Point}
import svg_path/bounds
import svg_path/measure
import svg_path/offset

pub fn cavalier_clipped_open_endpoint_can_become_cycle_seam_test() {
  // Cavalier non_tangent_open_endpoint_clip (CC01558 and reversed variants).
  let assert Ok(source) =
    svg_path.subpath_polyline([
      Point(0.0, 0.0),
      Point(10.0, 0.0),
      Point(10.0, 10.0),
      Point(0.0, 10.0),
      Point(0.0, 1.0),
    ])
  list.each(
    [#(source, -1.0), #(svg_path.subpath_reverse(source), 1.0)],
    fn(case_) {
      let assert Ok(path) =
        offset.subpath(case_.0, case_.1, offset.Round, offset.Butt)
      let assert [s] = path.subpaths
      let assert Ok(length) = measure.subpath_length(s)
      assert float.absolute_value(length -. 32.0) <. 0.00000001
      let assert Ok(box) = bounds.subpath_bounding_box(s)
      assert box.min == Point(1.0, 1.0)
      assert box.max == Point(9.0, 9.0)
      assert svg_path.subpath_is_closed(s)
      let assert Ok(_) = svg_path.subpath(svg_path.subpath_segments(s))
    },
  )
}

pub fn intact_open_offset_terminals_remain_open_test() {
  let assert Ok(source) =
    svg_path.subpath_polyline([Point(0.0, 0.0), Point(10.0, 0.0)])
  list.each(
    [#(source, -1.0), #(svg_path.subpath_reverse(source), 1.0)],
    fn(case_) {
      let assert Ok(path) =
        offset.subpath(case_.0, case_.1, offset.Round, offset.Butt)
      let assert [s] = path.subpaths
      assert !svg_path.subpath_is_closed(s)
      let assert Ok(length) = measure.subpath_length(s)
      assert length == 10.0
    },
  )
}
