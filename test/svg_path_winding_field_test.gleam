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
