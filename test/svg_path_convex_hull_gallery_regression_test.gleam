import gleam/list
import svg_path
import svg_path/convex_hull
import svg_path_convex_hull_gallery_fixture as fixture
import svg_path_convex_hull_support as support

const support_tolerance = 0.00001

pub fn figure_eight_hull_preserves_source_support_test() {
  let source = fixture.figure_eight()
  let assert Ok(hull) = convex_hull.subpath_hull(source)

  assert svg_path.subpath_is_closed(hull)
  assert support_matches(
    svg_path.subpath_segments(source),
    svg_path.subpath_segments(hull),
  )
}

pub fn figure_eight_band_hull_preserves_band_support_test() {
  let assert Ok(band) = fixture.figure_eight_band()
  let assert Ok(hull) = convex_hull.path_hull(band)

  assert svg_path.subpath_is_closed(hull)
  assert support_matches(path_segments(band), svg_path.subpath_segments(hull))
}

pub fn figure_eight_and_band_hull_preserves_combined_support_test() {
  let assert Ok(combined) = fixture.combined_path()
  let assert Ok(hull) = convex_hull.path_hull(combined)

  assert svg_path.subpath_is_closed(hull)
  assert support_matches(
    path_segments(combined),
    svg_path.subpath_segments(hull),
  )
}

fn path_segments(path: svg_path.Path) -> List(svg_path.Segment) {
  path
  |> svg_path.path_subpaths
  |> list.flat_map(svg_path.subpath_segments)
}

fn support_matches(
  original: List(svg_path.Segment),
  hull: List(svg_path.Segment),
) -> Bool {
  support.ten_degree_angles()
  |> list.all(fn(angle) {
    case
      support.segments_support_value(original, angle),
      support.segments_support_value(hull, angle)
    {
      Ok(original), Ok(hull) ->
        support.values_near(original, hull, tolerance: support_tolerance)
      _, _ -> False
    }
  })
}
