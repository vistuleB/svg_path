import gleam/float
import gleam/list
import gleam/string
import readme_recipes
import svg_path
import svg_path/area
import svg_path/fit
import svg_path/measure
import svg_path/parse
import svg_path/serialize
import svg_path/stroke

pub fn fitted_recipe_trims_by_distance_test() {
  let point = fn(t) { svg_path.Point(10.0 *. t, 10.0 *. t *. t) }
  let assert Ok(full) = fit.subpath_from_parametric(from: 0.0, to: 1.0, point:)
  let assert Ok(middle) = readme_recipes.middle_half(point)
  let assert Ok(full_length) = measure.subpath_length(full)
  let assert Ok(middle_length) = measure.subpath_length(middle)
  assert float.absolute_value(middle_length -. full_length /. 2.0) <. 0.00001
  let assert Ok(expected_start) =
    measure.subpath_point_at_length(full, distance: full_length /. 4.0)
  assert svg_path.subpath_start(middle) == expected_start
}

pub fn projected_recipe_keeps_a_reusable_path_address_test() {
  let assert Ok(path) = parse.path("M0 0H10 M20 0V10")
  let assert Ok(#(projection, derivative)) =
    readme_recipes.nearest_location(svg_path.Point(23.0, 5.0), path)
  assert projection.distance == 3.0
  assert projection.point == svg_path.Point(20.0, 5.0)
  assert projection.at.subpath_index == 1
  assert svg_path.path_point(path, at: projection.at) == Ok(projection.point)
  assert derivative == svg_path.Point(0.0, 10.0)
}

pub fn stroke_union_recipe_preserves_geometry_and_errors_test() {
  let assert Ok(line) = parse.path("M0 0H10")
  let assert Ok(region) = parse.path("M5 -1H15V1H5Z")
  let assert Ok(combined) = readme_recipes.outline_union(line, 2.0, region)
  let assert Ok(size) = area.path(combined, using: svg_path.Nonzero)
  assert float.absolute_value(size -. 30.0) <. 0.000001
  assert readme_recipes.outline_union(line, 0.0, region)
    == Error(readme_recipes.StrokeFailure(stroke.InvalidWidth(0.0)))
}

pub fn smaller_path_data_recipe_selects_both_modes_and_keeps_ties_test() {
  // Absolute wins, relative wins, and equal-size spellings retain relative.
  list.each(
    [
      #("M10 50L0 50L80 50", "M"),
      #("M1000 1000L1001 1001", "m"),
      #("M0 0L1 1", "m"),
    ],
    fn(example) {
      let #(source, prefix) = example
      let assert Ok(path) = parse.path(source)
      let encoded = readme_recipes.smaller_path_data(path, 3)
      assert string.starts_with(encoded, prefix)
      assert parse.path(encoded) == Ok(path)
      let options = serialize.minifying_options(3)
      assert string.length(encoded)
        <= string.length(serialize.path_with(path, options))
      assert string.length(encoded)
        <= string.length(serialize.path_with(
          path,
          serialize.Options(..options, relative: False),
        ))
    },
  )
}
