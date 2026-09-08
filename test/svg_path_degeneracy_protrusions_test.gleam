import gleam/list
import svg_path
import svg_path/degeneracy
import svg_path/parse

fn normalize(source: String, tolerance: Float) -> svg_path.Subpath {
  let assert Ok(path) = parse.path(source)
  let assert [subpath] = svg_path.path_subpaths(path)
  let assert Ok(normalized) =
    degeneracy.normalize_degenerate_segments(subpath, tolerance:)
  assert svg_path.subpath_start(normalized) == svg_path.subpath_start(subpath)
  assert svg_path.subpath_end(normalized) == svg_path.subpath_end(subpath)
  assert svg_path.subpath_is_closed(normalized)
    == svg_path.subpath_is_closed(subpath)
  normalized
}

fn vertices(subpath: svg_path.Subpath) -> List(svg_path.Point) {
  [
    svg_path.subpath_start(subpath),
    ..list.map(svg_path.subpath_segments(subpath), svg_path.segment_end)
  ]
}

pub fn zero_line_does_not_introduce_a_middle_stop_test() {
  assert normalize("M0 0 L0 0 L1 0 L2 0", 0.0) |> vertices
    == [svg_path.Point(0.0, 0.0), svg_path.Point(2.0, 0.0)]
}

pub fn constant_beziers_do_not_introduce_a_middle_stop_test() {
  list.each(
    [
      "M0 0 Q0 0 0 0 L1 0 L2 0",
      "M0 0 C0 0 0 0 0 0 L1 0 L2 0",
    ],
    fn(source) {
      assert normalize(source, 0.0) |> vertices
        == [svg_path.Point(0.0, 0.0), svg_path.Point(2.0, 0.0)]
    },
  )
}

pub fn zero_line_does_not_erase_longitudinal_extents_test() {
  assert normalize(
      "M0 0 L0 0 L-10 0 L1 0.0000000001 L2 0.0000000001 L10 0 L3 0",
      0.000001,
    )
    |> vertices
    == [
      svg_path.Point(0.0, 0.0),
      svg_path.Point(-10.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(3.0, 0.0),
    ]
}

pub fn line_encoded_as_quadratic_preserves_longitudinal_extents_test() {
  assert normalize(
      "M0 0 Q-5 0 -10 0 L1 0.0000000001 L2 0.0000000001 L10 0 L3 0",
      0.000001,
    )
    |> vertices
    == [
      svg_path.Point(0.0, 0.0),
      svg_path.Point(-10.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(3.0, 0.0),
    ]
}

pub fn longitudinal_extents_follow_traversal_not_coordinate_order_test() {
  assert normalize(
      "M3 0 Q6.5 0 10 0 L2 0.0000000001 L1 0.0000000001 L-10 0 L0 0",
      0.000001,
    )
    |> vertices
    == [
      svg_path.Point(3.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(-10.0, 0.0),
      svg_path.Point(0.0, 0.0),
    ]
}

pub fn longitudinal_support_finds_bezier_interior_extremum_test() {
  assert normalize("M0 0 Q-20 0 0 0 L3 0", 0.000001) |> vertices
    == [
      svg_path.Point(0.0, 0.0),
      svg_path.Point(-10.0, 0.0),
      svg_path.Point(3.0, 0.0),
    ]
}

pub fn endpoint_anchors_take_priority_over_nearby_extrema_test() {
  assert normalize("M0 0 Q-0.00025 0 -0.0005 0 L10.0005 0 L10 0", 0.001)
    |> vertices
    == [svg_path.Point(0.0, 0.0), svg_path.Point(10.0, 0.0)]
}

pub fn hull_union_keeps_short_connectors_until_reconstruction_test() {
  assert normalize(
      "M0 0 Q-0.00000025 0 -0.0000005 0 L10.0000005 0 L10 0",
      0.000001,
    )
    |> vertices
    == [svg_path.Point(0.0, 0.0), svg_path.Point(10.0, 0.0)]
}

pub fn coincident_endpoint_anchors_preserve_closed_traversal_test() {
  assert normalize("M0 0 Q-5 0 -10 0 L10 0 L0 0 Z", 0.0) |> vertices
    == [
      svg_path.Point(0.0, 0.0),
      svg_path.Point(-10.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(0.0, 0.0),
    ]
}

pub fn two_extrema_inside_one_cubic_follow_parameter_order_test() {
  let cleaned = normalize("M0 0 C-9 0 9 0 0 0 L0 0", 0.0)
  let assert [start, minimum, maximum, end] = vertices(cleaned)
  assert start == svg_path.Point(0.0, 0.0)
  assert minimum.x <. -2.5
  assert maximum.x >. 2.5
  assert end == start
}

pub fn nearby_but_distinct_endpoint_anchors_are_not_merged_test() {
  assert normalize("M0 0 Q0 0 0 0 L0.0000001 0", 0.000001)
    |> vertices
    == [svg_path.Point(0.0, 0.0), svg_path.Point(0.0000001, 0.0)]
}

pub fn vertical_strip_uses_longitudinal_not_transverse_support_test() {
  assert normalize(
      "M0 0 Q0 -5 0 -10 L0.0000000001 1 L0.0000000001 2 L0 10 L0 3",
      0.000001,
    )
    |> vertices
    == [
      svg_path.Point(0.0, 0.0),
      svg_path.Point(0.0, -10.0),
      svg_path.Point(0.0, 10.0),
      svg_path.Point(0.0, 3.0),
    ]
}
