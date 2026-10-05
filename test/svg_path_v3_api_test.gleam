import gleam/float
import gleam/list
import svg_path
import svg_path/area
import svg_path/bounds
import svg_path/containment
import svg_path/csg
import svg_path/distance
import svg_path/fit
import svg_path/measure
import svg_path/offset
import svg_path/parse
import svg_path/serialize
import svg_path/stroke
import svg_path/transform

pub fn boolean_paths_compose_with_transform_measure_and_serialize_test() {
  let assert Ok(left) = parse.path("M0 0H10V10H0Z")
  let assert Ok(right) = parse.path("M5 0H15V10H5Z")
  list.each(
    [
      #(csg.union_path(left, right, using: svg_path.Nonzero), 150.0),
      #(csg.intersection_path(left, right, using: svg_path.Nonzero), 50.0),
      #(csg.difference_path(left, minus: right, using: svg_path.Nonzero), 50.0),
      #(
        csg.symmetric_difference_path(left, right, using: svg_path.Nonzero),
        100.0,
      ),
    ],
    fn(case_) {
      let assert Ok(path) = case_.0
      let assert Ok(scaled) =
        transform.path(path, by: transform.scale(factor: 2.0))
      let assert Ok(round_trip) = parse.path(serialize.path(scaled))
      let assert Ok(actual_area) =
        area.path(round_trip, using: svg_path.Nonzero)
      assert float.absolute_value(actual_area -. case_.1 *. 4.0) <. 0.000001
      let assert Ok(length) = measure.path_length(round_trip)
      assert length >. 0.0
    },
  )
}

pub fn path_only_boolean_options_preserve_failure_and_winding_contracts_test() {
  let assert Ok(path) = parse.path("M0 0H10V10H0Z")
  let doubled = svg_path.path_combine([path, path])
  let assert Ok(empty) =
    csg.union_path_with(
      doubled,
      svg_path.path_empty(),
      using: svg_path.EvenOdd,
      options: csg.default_options(),
    )
  assert svg_path.path_subpaths(empty) == []
  let assert Ok(contours) = csg.nested_contours_path(doubled)
  let assert Ok(winding) =
    containment.path_winding(svg_path.Point(5.0, 5.0), within: contours)
  let assert Ok(original_winding) =
    containment.path_winding(svg_path.Point(5.0, 5.0), within: doubled)
  assert winding == original_winding
  let invalid = csg.Options(..csg.default_options(), tolerance: 0.0)
  let assert Error(error) =
    csg.union_path_with(path, path, using: svg_path.Nonzero, options: invalid)
  let assert Error(detailed_error) =
    csg.union_with(path, path, using: svg_path.Nonzero, options: invalid)
  assert error == detailed_error
}

pub fn measurement_subdivision_preserves_closed_geometry_test() {
  let assert Ok(path) = parse.path("M0 0H10V10H0Z")
  let assert Ok(divided) =
    measure.path_subdivide_to_max_length(path, max_length: 3.0)
  let assert [subpath] = svg_path.path_subpaths(divided)
  assert svg_path.subpath_is_closed(subpath)
  assert measure.path_length(divided) == Ok(40.0)
  assert bounds.path_bounding_box(divided) == bounds.path_bounding_box(path)
  list.each(svg_path.subpath_segments(subpath), fn(segment) {
    let assert Ok(length) = measure.segment_length(segment)
    assert length <=. 3.0
  })
}

pub fn fitted_geometry_supports_projection_and_configurable_strokes_test() {
  let assert Ok(subpath) =
    fit.subpath_from_parametric(from: 0.0, to: 1.0, point: fn(t) {
      svg_path.Point(t *. 10.0, 0.0)
    })
  let assert Ok(projection) =
    distance.subpath_projection(svg_path.Point(5.0, 3.0), to: subpath)
  assert float.absolute_value(projection.distance -. 3.0) <. 0.000001
  let assert Ok(outline) =
    stroke.subpath_with(
      subpath,
      width: 2.0,
      join: offset.Round,
      cap: offset.Butt,
      options: offset.default_options(),
    )
  let assert Ok(box) = bounds.path_bounding_box(outline)
  assert float.absolute_value(bounds.bounding_box_height(box) -. 2.0)
    <. 0.000001
}

pub fn closest_pair_options_validate_even_for_empty_geometry_test() {
  let line = svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(10.0, 0.0))
  let assert Ok(subpath) = svg_path.subpath([line])
  let empty = svg_path.path_empty()
  list.each(
    [
      #(
        distance.ClosestPairOptions(0.0, 48),
        svg_path.InvalidIntersectionTolerance(0.0),
      ),
      #(
        distance.ClosestPairOptions(0.000000001, 0),
        svg_path.InvalidIntersectionMaxDepth(0),
      ),
    ],
    fn(case_) {
      let #(options, expected) = case_
      assert distance.segment_segment_closest_pair_with(line, line, options:)
        == Error(expected)
      assert distance.segment_subpath_closest_pair_with(line, subpath, options:)
        == Error(expected)
      assert distance.segment_path_closest_pair_with(line, empty, options:)
        == Error(expected)
      assert distance.subpath_subpath_closest_pair_with(
          subpath,
          subpath,
          options:,
        )
        == Error(expected)
      assert distance.subpath_path_closest_pair_with(subpath, empty, options:)
        == Error(expected)
      assert distance.path_path_closest_pair_with(empty, empty, options:)
        == Error(expected)
    },
  )
}

fn projected_point(projection: svg_path.Projection(address)) -> svg_path.Point {
  let svg_path.Projection(point:, ..) = projection
  point
}

fn closest_distance(pair: svg_path.ClosestPair(left, right)) -> Float {
  pair.distance
}

pub fn generic_projection_records_compose_across_geometry_levels_test() {
  let line = svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(10.0, 0.0))
  let assert Ok(subpath) = svg_path.subpath([line])
  let path = svg_path.subpath_as_path(subpath)
  let query = svg_path.Point(5.0, 3.0)
  let assert Ok(segment_hit) = distance.segment_projection(query, to: line)
  let assert Ok(path_hit) = distance.path_projection(query, to: path)
  assert projected_point(segment_hit) == projected_point(path_hit)
  assert svg_path.segment_point(line, at: segment_hit.at)
    == Ok(segment_hit.point)
  assert svg_path.path_point(path, at: path_hit.at) == Ok(path_hit.point)
  let parallel =
    svg_path.Line(svg_path.Point(0.0, 3.0), svg_path.Point(10.0, 3.0))
  let assert Ok(segment_pair) =
    distance.segment_segment_closest_pair(line, parallel)
  let assert Ok(mixed_pair) = distance.segment_path_closest_pair(parallel, path)
  assert closest_distance(segment_pair) == 3.0
  assert closest_distance(mixed_pair) == 3.0
  assert svg_path.segment_point(parallel, at: mixed_pair.left_at)
    == Ok(mixed_pair.left_point)
  assert svg_path.path_point(path, at: mixed_pair.right_at)
    == Ok(mixed_pair.right_point)
}

pub fn default_trimming_entrypoints_match_explicit_policies_test() {
  let assert Ok(path) = parse.path("M0 0H10V10")
  let assert [source] = svg_path.path_subpaths(path)
  let options = offset.default_options()
  let single = offset.default_single_offset_trimming()
  let band = offset.default_band_trimming()
  assert offset.subpath(
      source,
      offset: 1.0,
      join: offset.Round,
      cap: offset.Butt,
    )
    == offset.subpath_with(
      source,
      offset: 1.0,
      join: offset.Round,
      cap: offset.Butt,
      options:,
      trimming: single,
    )
  assert offset.path(path, offset: 1.0, join: offset.Round, cap: offset.Butt)
    == offset.path_with(
      path,
      offset: 1.0,
      join: offset.Round,
      cap: offset.Butt,
      options:,
      trimming: single,
    )
  assert offset.subpath_band(
      source,
      inner_offset: -1.0,
      outer_offset: 1.0,
      join: offset.Round,
      cap: offset.Butt,
    )
    == offset.subpath_band_with(
      source,
      inner_offset: -1.0,
      outer_offset: 1.0,
      join: offset.Round,
      cap: offset.Butt,
      options:,
      trimming: band,
    )
  assert offset.path_band(
      path,
      inner_offset: -1.0,
      outer_offset: 1.0,
      join: offset.Round,
      cap: offset.Butt,
    )
    == offset.path_band_with(
      path,
      inner_offset: -1.0,
      outer_offset: 1.0,
      join: offset.Round,
      cap: offset.Butt,
      options:,
      trimming: band,
    )
}

pub fn path_band_propagates_custom_trimming_to_every_subpath_test() {
  let assert Ok(path) = parse.path("M0 0H10V10 M20 0H30V10")
  let options = offset.default_options()
  let trimming = offset.BandTrimming(False, False, False)
  let expected =
    path
    |> svg_path.path_subpaths
    |> list.map(fn(source) {
      let assert Ok(band) =
        offset.subpath_band_with(
          source,
          inner_offset: -1.0,
          outer_offset: 1.0,
          join: offset.Round,
          cap: offset.Square,
          options:,
          trimming:,
        )
      band
    })
    |> svg_path.path_combine
  assert offset.path_band_with(
      path,
      inner_offset: -1.0,
      outer_offset: 1.0,
      join: offset.Round,
      cap: offset.Square,
      options:,
      trimming:,
    )
    == Ok(expected)
}
