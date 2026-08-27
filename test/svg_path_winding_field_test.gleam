import svg_path
import svg_path/winding_field

pub fn side_levels_reject_nonpositive_sampling_distance_test() {
  let segment =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(1.0, 0.0),
    )
  let path = svg_path.path_empty()
  let options = svg_path.default_containment_options()

  assert winding_field.segment_side_nonzero_levels(
      segment,
      within: path,
      side_sampling_distance: 0.0,
      options:,
    )
    == Error(svg_path.InvalidContainmentTolerance(0.0))
  assert winding_field.segment_side_nonzero_levels(
      segment,
      within: path,
      side_sampling_distance: -0.001,
      options:,
    )
    == Error(svg_path.InvalidContainmentTolerance(-0.001))
}

pub fn side_levels_fall_back_from_a_midpoint_cusp_test() {
  let cusp =
    svg_path.CubicBezier(
      start: svg_path.Point(-1.0, 0.0),
      control1: svg_path.Point(1.0, 1.0),
      control2: svg_path.Point(-1.0, 1.0),
      end: svg_path.Point(1.0, 0.0),
    )
  let open =
    svg_path.subpath_assert([
      cusp,
      svg_path.Line(
        start: svg_path.Point(1.0, 0.0),
        end: svg_path.Point(-1.0, 0.0),
      ),
    ])
  let assert Ok(subpath) = svg_path.subpath_set_closed(open, closed: True)
  let path = svg_path.subpath_as_path(subpath)

  assert svg_path.segment_derivative(cusp, at: 0.5)
    == Ok(svg_path.Point(0.0, 0.0))
  assert winding_field.segment_side_nonzero_levels(
      cusp,
      within: path,
      side_sampling_distance: 0.0001,
      options: svg_path.default_containment_options(),
    )
    == Ok(#(-1, 0))
}

pub fn side_levels_reject_a_segment_without_a_regular_sample_test() {
  let point = svg_path.Point(1.0, 2.0)
  let collapsed = svg_path.Line(start: point, end: point)

  assert winding_field.segment_side_nonzero_levels(
      collapsed,
      within: svg_path.path_empty(),
      side_sampling_distance: 0.0001,
      options: svg_path.default_containment_options(),
    )
    == Error(svg_path.IndeterminateWindingSideLevels)
}
