import gleam/float
import gleam/list
import svg_path.{CubicBezier, Point}
import svg_path/intersections

fn pair() {
  #(
    CubicBezier(
      Point(0.9646201687528162, 1.4210854715202004e-14),
      Point(0.6772878019443311, 2.1316282072803006e-14),
      Point(0.34565238552668376, 1.4210854715202004e-14),
      Point(0.43502028382843605, 1.4210854715202004e-14),
    ),
    CubicBezier(
      Point(0.4954801054242637, 2.1316282072803006e-14),
      Point(0.7755793433895946, 1.4210854715202004e-14),
      Point(0.013640682690727601, 0.0),
      Point(0.8957075918855395, 1.4210854715202004e-14),
    ),
  )
}

pub fn conditioned_search_recovers_thin_curve_root_test() {
  let #(a, b) = pair()
  let options =
    intersections.IntersectionOptions(
      ..intersections.default_options(),
      tolerance: 0.000000000001,
    )
  let assert Ok(forward) = intersections.segment_with(a, b, options:)
  let assert Ok(reverse) = intersections.segment_with(b, a, options:)
  assert list.any(forward, fn(hit) {
    float.absolute_value(hit.left_t -. 0.4962432835063433) <. 0.0000001
    && float.absolute_value(hit.right_t -. 0.18393974411322186) <. 0.0000001
  })
  assert list.any(reverse, fn(hit) {
    float.absolute_value(hit.right_t -. 0.4962432835063433) <. 0.0000001
    && float.absolute_value(hit.left_t -. 0.18393974411322186) <. 0.0000001
  })
}

pub fn conditioned_search_preserves_original_candidates_test() {
  let #(a, b) = pair()
  let options =
    intersections.IntersectionOptions(
      ..intersections.default_options(),
      tolerance: 0.000000000001,
    )
  let assert Ok(original) =
    intersections.elizabeth_beam_intersections(a, b, options)
  let assert Ok(found) = intersections.segment_with(a, b, options:)
  list.each(original.intersections, fn(candidate) {
    assert list.any(found, fn(hit) {
      hit.left_t == candidate.left_t && hit.right_t == candidate.right_t
    })
  })
  list.each(found, fn(hit) {
    let assert Ok(p) = svg_path.segment_point(a, hit.left_t)
    let assert Ok(q) = svg_path.segment_point(b, hit.right_t)
    assert float.absolute_value(p.x -. hit.point.x) <=. options.tolerance
    assert float.absolute_value(p.y -. hit.point.y) <=. options.tolerance
    assert float.absolute_value(q.x -. hit.point.x) <=. options.tolerance
    assert float.absolute_value(q.y -. hit.point.y) <=. options.tolerance
  })
}

pub fn conditioned_search_does_not_override_overlap_or_certification_test() {
  let #(a, b) = pair()
  assert intersections.segment(a, b)
    == Error(svg_path.NonAffineOverlapCorrespondence)
  let options =
    intersections.IntersectionOptions(
      ..intersections.default_options(),
      tolerance: 0.0000000000000001,
    )
  let assert Error(svg_path.InternalUncertifiedSegmentIntersection(..)) =
    intersections.segment_with(a, b, options:)
}
