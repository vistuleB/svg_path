import gleam/float
import gleam/list
import svg_path
import svg_path/point

// These are numerical candidates, not certified distinct mathematical roots.
pub fn assert_candidates(
  hits: List(svg_path.SegmentIntersection),
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
) {
  list.each(hits, fn(hit) {
    assert hit.left_t >=. 0.0 && hit.left_t <=. 1.0
    assert hit.right_t >=. 0.0 && hit.right_t <=. 1.0
    let assert Ok(a) = svg_path.segment_point(left, hit.left_t)
    let assert Ok(b) = svg_path.segment_point(right, hit.right_t)
    assert point.distance(a, b) <=. tolerance
    assert point.distance(a, hit.point) <=. tolerance
    assert point.distance(b, hit.point) <=. tolerance
  })
  assert_separated(hits)
}

fn assert_separated(hits: List(svg_path.SegmentIntersection)) {
  case hits {
    [] -> Nil
    [first, ..rest] -> {
      list.each(rest, fn(other) {
        // The final selector uses a square in parameter space. Allow only
        // floating-point roundoff at its boundary, including decimal snapping.
        let separation =
          float.max(
            float.absolute_value(first.left_t -. other.left_t),
            float.absolute_value(first.right_t -. other.right_t),
          )
        assert separation >=. 0.0000001 -. 0.000000000000001
      })
      assert_separated(rest)
    }
  }
}

pub fn assert_known(
  hits: List(svg_path.SegmentIntersection),
  left_t: Float,
  right_t: Float,
  tolerance: Float,
) {
  assert list.any(hits, fn(hit) {
    float.absolute_value(hit.left_t -. left_t) <=. tolerance
    && float.absolute_value(hit.right_t -. right_t) <=. tolerance
  })
}
