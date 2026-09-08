import gleam/float
import gleam/int
import gleam/list
import svg_path
import svg_path/offset

fn p(x: Float) -> svg_path.Point {
  svg_path.Point(x, 0.0)
}

fn normalize(path: svg_path.Subpath) -> svg_path.Subpath {
  let assert Ok(normalized) =
    offset.normalize_short_source_runs(path, tolerance: 0.001)
  assert svg_path.subpath_start(normalized) == svg_path.subpath_start(path)
  assert svg_path.subpath_end(normalized) == svg_path.subpath_end(path)
  assert svg_path.subpath_is_closed(normalized)
    == svg_path.subpath_is_closed(path)
  normalized
}

pub fn balanced_short_run_has_no_greedy_remainder_test() {
  let points =
    int.range(0, 8, with: [], run: fn(acc, i) {
      [p(int.to_float(i) *. 0.0009), ..acc]
    })
    |> list.reverse
  let assert Ok(source) =
    svg_path.subpath_polyline([p(-1.0), ..list.append(points, [p(1.0)])])
  let normalized = normalize(source)
  let segments = svg_path.subpath_segments(normalized)
  assert list.length(segments) == 5
  assert list.first(segments) == list.first(svg_path.subpath_segments(source))
  assert list.last(segments) == list.last(svg_path.subpath_segments(source))
  let chunks = segments |> list.drop(1) |> list.take(3)
  list.each(chunks, fn(segment) {
    let assert Ok(bound) = svg_path.segment_length_upper_bound(segment)
    assert bound >. 0.001
    assert bound <=. 0.003
  })
}

pub fn long_short_run_preserves_large_backtracking_extent_test() {
  let outward =
    int.range(0, 101, with: [], run: fn(acc, i) {
      [p(int.to_float(i) *. 0.0009), ..acc]
    })
    |> list.reverse
  let inward = outward |> list.reverse |> list.drop(1)
  let points = [p(-1.0), ..list.append(outward, list.append(inward, [p(-1.0)]))]
  let assert Ok(source) = svg_path.subpath_polyline(points)
  let normalized = normalize(source)
  let assert Ok(original_box) = svg_path.subpath_bounding_box(source)
  let assert Ok(box) = svg_path.subpath_bounding_box(normalized)
  assert box == original_box
  let assert Ok(length) = svg_path.subpath_length(normalized)
  let assert Ok(original_length) = svg_path.subpath_length(source)
  assert float.absolute_value(length -. original_length) <. 0.000000000001
}

pub fn short_run_preserves_neighbors_instead_of_moving_them_test() {
  let first = svg_path.Line(p(-1.0), p(0.0))
  let last = svg_path.Line(p(0.001), p(1.0))
  let source =
    svg_path.subpath_assert([
      first,
      svg_path.Line(p(0.0), p(0.0005)),
      svg_path.Line(p(0.0005), p(0.001)),
      last,
    ])
  assert svg_path.subpath_segments(normalize(source))
    == [first, svg_path.Line(p(0.0), p(0.001)), last]
}

pub fn coincident_endpoint_curve_is_not_mistaken_for_short_segment_test() {
  let curve = svg_path.QuadraticBezier(p(0.0), p(10.0), p(0.0))
  let source =
    svg_path.subpath_assert([
      svg_path.Line(p(-1.0), p(0.0)),
      curve,
      svg_path.Line(p(0.0), p(1.0)),
    ])
  assert normalize(source) == source
}

pub fn short_run_keeps_small_first_and_last_segments_test() {
  let first = svg_path.Line(p(0.0), p(0.0001))
  let last = svg_path.Line(p(1.0), p(1.0001))
  let source =
    svg_path.subpath_assert([first, svg_path.Line(p(0.0001), p(1.0)), last])
  assert normalize(source) == source
}

pub fn short_run_preserves_closed_empty_and_singleton_subpaths_test() {
  let empty = svg_path.subpath_empty(at: p(1.0))
  let singleton = svg_path.subpath_assert([svg_path.Line(p(0.0), p(0.0))])
  let assert Ok(closed) = svg_path.subpath_set_closed(singleton, closed: True)
  assert normalize(empty) == empty
  assert normalize(singleton) == singleton
  assert normalize(closed) == closed
  let source =
    svg_path.subpath_assert([
      svg_path.Line(p(0.0), p(0.0004)),
      svg_path.Line(p(0.0004), p(0.0006)),
      svg_path.Line(p(0.0006), p(0.0008)),
      svg_path.Line(p(0.0008), p(0.0)),
    ])
  let assert Ok(source) = svg_path.subpath_set_closed(source, closed: True)
  let normalized = normalize(source)
  assert list.length(svg_path.subpath_segments(normalized)) == 3
}

pub fn zero_length_run_is_handled_without_division_by_zero_test() {
  let source =
    svg_path.subpath_assert([
      svg_path.Line(p(-1.0), p(0.0)),
      svg_path.Line(p(0.0), p(0.0)),
      svg_path.Line(p(0.0), p(0.0)),
      svg_path.Line(p(0.0), p(1.0)),
    ])
  let normalized = normalize(source)
  let assert Ok(length) = svg_path.subpath_length(normalized)
  assert length == 2.0
}

pub fn short_run_rejects_invalid_tolerance_test() {
  assert offset.normalize_short_source_runs(
      svg_path.subpath_empty(at: p(0.0)),
      tolerance: 0.0,
    )
    == Error(offset.InternalInvalidTolerance(0.0))
}
