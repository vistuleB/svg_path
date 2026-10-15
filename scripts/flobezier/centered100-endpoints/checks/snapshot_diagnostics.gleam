import gleam/io
import svg_path_geometry_test as geometry
import svg_path_intersections_test as intersections
import svg_path_conditioned_intersections_test as conditioned
import svg_path_intersection_scale_test as scale
pub fn main() {
  geometry.segment_intersections_prefers_shared_endpoint_over_near_endpoint_minimum_test()
  io.println("PASS shared endpoint: raw/snapped counts, validity, exact endpoint, separation")
  intersections.production_off_center_kissing_quadratics_test()
  io.println("PASS off-center contact: known parameters, residual, count")
  intersections.flat_cubic_crossing_regression_test()
  io.println("PASS flat crossing: known parameters, residual, count")
  conditioned.conditioned_search_recovers_thin_curve_root_test()
  io.println("PASS thin-curve root, both orientations")
  conditioned.conditioned_search_preserves_original_candidates_test()
  io.println("PASS remaining original-candidate test geometric assertions")
  let _ = conditioned.conditioned_search_does_not_override_overlap_or_certification_test()
  io.println("PASS overlap and strict certification")
  let _ = scale.unrepresentable_tolerance_reports_error_instead_of_empty_result_test()
  io.println("PASS unrepresentable tolerance error")
}
