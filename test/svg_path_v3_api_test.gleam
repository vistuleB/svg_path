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
      join: stroke.Round,
      cap: stroke.Butt,
      options: stroke.default_options(),
    )
  let assert Ok(box) = bounds.path_bounding_box(outline)
  assert float.absolute_value(bounds.bounding_box_height(box) -. 2.0)
    <. 0.000001
}
