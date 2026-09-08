import gleeunit
import svg_path/affine

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn point_pair_similarity_reports_degenerate_source_test() {
  assert affine.point_pair_similarity(
      source_start: #(1.0, 2.0),
      source_end: #(1.0, 2.0),
      target_start: #(0.0, 0.0),
      target_end: #(1.0, 0.0),
    )
    == Error(affine.DegenerateSourcePair)
}

pub fn point_triple_map_reports_degenerate_source_test() {
  assert affine.point_triple_map(
      source_a: #(0.0, 0.0),
      source_b: #(1.0, 0.0),
      source_c: #(2.0, 0.0),
      target_a: #(0.0, 0.0),
      target_b: #(1.0, 0.0),
      target_c: #(0.0, 1.0),
    )
    == Error(affine.DegenerateSourceTriple)
  assert affine.point_triple_map(
      source_a: #(0.0, 0.0),
      source_b: #(0.0, 0.0),
      source_c: #(0.0, 0.0),
      target_a: #(0.0, 0.0),
      target_b: #(0.0, 0.0),
      target_c: #(0.0, 0.0),
    )
    == Error(affine.DegenerateSourceTriple)
}

pub fn point_pair_similarity_reports_nonfinite_transform_test() {
  assert affine.point_pair_similarity(
      source_start: #(1.0e200, 0.0),
      source_end: #(1.0e200, 1.0),
      target_start: #(0.0, 0.0),
      target_end: #(0.0, 1.0e150),
    )
    == Error(affine.NonFiniteTransform)
}

pub fn point_triple_map_reports_nonfinite_transform_test() {
  assert affine.point_triple_map(
      source_a: #(0.0, 0.0),
      source_b: #(0.5, 0.0),
      source_c: #(0.0, 0.5),
      target_a: #(0.0, 0.0),
      target_b: #(1.0e308, 0.0),
      target_c: #(0.0, 1.0e308),
    )
    == Error(affine.NonFiniteTransform)
}

pub fn point_correspondence_maps_allow_collapsed_targets_test() {
  let assert Ok(pair) =
    affine.point_pair_similarity(
      source_start: #(0.0, 0.0),
      source_end: #(1.0, 0.0),
      target_start: #(2.0, 3.0),
      target_end: #(2.0, 3.0),
    )
  let assert Ok(triple) =
    affine.point_triple_map(
      source_a: #(0.0, 0.0),
      source_b: #(1.0, 0.0),
      source_c: #(0.0, 1.0),
      target_a: #(2.0, 3.0),
      target_b: #(2.0, 3.0),
      target_c: #(2.0, 3.0),
    )
  assert affine.point(pair, x: 5.0, y: 6.0) == #(2.0, 3.0)
  assert affine.point(triple, x: 5.0, y: 6.0) == #(2.0, 3.0)
}

pub fn matrix_transforms_raw_coordinates_test() {
  let matrix = affine.matrix(a: 2.0, b: 3.0, c: 5.0, d: 7.0, e: 11.0, f: 13.0)

  assert affine.point(matrix, x: 2.0, y: 3.0) == #(30.0, 40.0)
  assert affine.linear_point(matrix, x: 2.0, y: 3.0) == #(19.0, 27.0)
}

pub fn point_pair_similarity_maps_coordinates_test() {
  let assert Ok(matrix) =
    affine.point_pair_similarity(
      source_start: #(1.0, 2.0),
      source_end: #(4.0, 2.0),
      target_start: #(10.0, -5.0),
      target_end: #(10.0, 1.0),
    )

  assert affine.point(matrix, x: 1.0, y: 2.0) == #(10.0, -5.0)
  assert affine.point(matrix, x: 4.0, y: 2.0) == #(10.0, 1.0)
}

pub fn point_triple_map_maps_coordinates_test() {
  let assert Ok(matrix) =
    affine.point_triple_map(
      source_a: #(0.0, 0.0),
      source_b: #(1.0, 0.0),
      source_c: #(0.0, 1.0),
      target_a: #(10.0, 20.0),
      target_b: #(12.0, 20.0),
      target_c: #(10.0, 23.0),
    )

  assert affine.point(matrix, x: 0.0, y: 0.0) == #(10.0, 20.0)
  assert affine.point(matrix, x: 1.0, y: 0.0) == #(12.0, 20.0)
  assert affine.point(matrix, x: 0.0, y: 1.0) == #(10.0, 23.0)
}
