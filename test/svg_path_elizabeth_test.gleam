import gleam/float
import gleam/list
import svg_path
import svg_path/intersections as ix
import svg_path_intersection_contract_support as contract

fn horizontal() -> svg_path.Segment {
  svg_path.QuadraticBezier(
    svg_path.Point(0.0, 0.0),
    svg_path.Point(0.5, 0.0),
    svg_path.Point(1.0, 0.0),
  )
}

fn diagonal() -> svg_path.Segment {
  svg_path.QuadraticBezier(
    svg_path.Point(0.0, -0.5),
    svg_path.Point(0.5, 0.0),
    svg_path.Point(1.0, 0.5),
  )
}

pub fn elizabeth_endpoint_keeps_multiple_target_parameters_test() {
  let retraced =
    svg_path.QuadraticBezier(
      svg_path.Point(0.25, 0.0),
      svg_path.Point(-0.25, 0.0),
      svg_path.Point(0.25, 0.0),
    )
  let endpoint =
    svg_path.Line(svg_path.Point(0.0625, 0.0), svg_path.Point(0.0625, 1.0))
  let assert Ok(report) =
    ix.elizabeth_beam_intersections(endpoint, retraced, ix.default_options())
  assert list.length(report.intersections) == 2
  list.each([0.25, 0.75], fn(t) {
    assert list.any(report.intersections, fn(hit) {
      hit.left_t == 0.0 && float.absolute_value(hit.right_t -. t) <. 0.0000001
    })
  })
}

pub fn elizabeth_beam_simple_crossing_needs_no_culling_test() {
  let assert Ok(report) =
    ix.elizabeth_beam_intersections(
      horizontal(),
      diagonal(),
      ix.default_options(),
    )
  assert list.length(report.intersections) == 1
  assert report.discarded_crossing == 0
  assert report.discarded_other == 0
  assert report.peak_retained <= 1000
}

pub fn elizabeth_beam_still_reports_depth_exhaustion_test() {
  let options = ix.IntersectionOptions(..ix.default_options(), max_depth: 1)
  let assert Error(ix.CurveSolverDepthLimit(..)) =
    ix.elizabeth_beam_intersections(horizontal(), diagonal(), options)
}

pub fn elizabeth_beam_flat_crossing_completes_with_explicit_loss_test() {
  let curve =
    svg_path.CubicBezier(
      svg_path.Point(0.0, -0.125),
      svg_path.Point(1.0 /. 3.0, 0.125),
      svg_path.Point(2.0 /. 3.0, -0.125),
      svg_path.Point(1.0, 0.125),
    )
  let options =
    ix.IntersectionOptions(
      ..ix.default_options(),
      tolerance: 0.00000000000005,
      max_depth: 48,
    )
  let assert Ok(report) =
    ix.elizabeth_beam_intersections(curve, horizontal(), options)
  assert report.discarded_other > 0
  // Decaying budgets keep this fixture below the former stepwise peak of
  // 250, while retaining a representative of the exact crossing.
  assert report.peak_retained <= 250
  // Count snapshot, not a mathematical root count: flag either increases or
  // decreases for review when the solver or floating-point backend changes.
  assert list.length(report.intersections) == 6
  assert report.discarded_candidates > 0
  contract.assert_candidates(
    report.intersections,
    curve,
    horizontal(),
    options.tolerance,
  )
  assert list.any(report.intersections, fn(hit) {
    float.absolute_value(hit.left_t -. 0.5) <. 0.0000001
    && float.absolute_value(hit.right_t -. 0.5) <. 0.0000001
  })
  list.each(report.intersections, fn(hit) {
    let assert Ok(p) = svg_path.segment_point(curve, hit.left_t)
    let assert Ok(q) = svg_path.segment_point(horizontal(), hit.right_t)
    let dx = p.x -. q.x
    let dy = p.y -. q.y
    assert dx *. dx +. dy *. dy <=. options.tolerance *. options.tolerance
  })
}

pub fn elizabeth_beam_join_line_selection_keeps_endpoint_test() {
  let arc =
    svg_path.Arc(
      svg_path.Point(430.66681589309076, 178.69245771161582),
      svg_path.Point(3.0, 3.0),
      0.0,
      False,
      False,
      svg_path.Point(430.670203101245, 178.69477431938788),
    )
  let line =
    svg_path.Line(
      svg_path.Point(430.670203101245, 178.69477431938788),
      svg_path.Point(430.22232031893986, 178.38890397610967),
    )
  let options =
    ix.IntersectionOptions(
      ..ix.default_options(),
      tolerance: 0.00000000000005,
      max_depth: 48,
    )
  let assert Ok(report) = ix.elizabeth_beam_intersections(arc, line, options)
  let assert [interior, endpoint] = report.intersections
  assert report.discarded_candidates > 0
  assert endpoint.left_t == 1.0 && endpoint.right_t == 0.0
  assert interior.left_t <. 1.0 && interior.right_t >. 0.0
  // All candidates in this cloud have zero computed residual. Selection is
  // deterministic, but does not certify the interior root's parameter error.
  list.each(report.intersections, fn(hit) {
    let assert Ok(p) = svg_path.segment_point(arc, hit.left_t)
    let assert Ok(q) = svg_path.segment_point(line, hit.right_t)
    let dx = p.x -. q.x
    let dy = p.y -. q.y
    assert dx *. dx +. dy *. dy <=. options.tolerance *. options.tolerance
  })
}

pub fn elizabeth_transverse_crossing_test() {
  let assert Ok(found) =
    ix.segment_with(horizontal(), diagonal(), options: ix.default_options())
  assert list.length(found) == 1
  let assert [hit] = found
  assert float.absolute_value(hit.left_t -. 0.5) <. 0.000000001
  assert float.absolute_value(hit.right_t -. 0.5) <. 0.000000001
}

pub fn elizabeth_candidate_does_not_finish_coarse_window_test() {
  let options = ix.IntersectionOptions(..ix.default_options(), max_depth: 1)
  let assert Error(svg_path.IntersectionDepthLimitReached(..)) =
    ix.segment_with(horizontal(), diagonal(), options: options)
}

pub fn elizabeth_clustered_crossings_test() {
  // x=t, y=(t-.2)(t-.21)(t-.22); the horizontal quadratic deliberately avoids
  // the production Line-specific algebraic route.
  let d = -0.2 *. 0.21 *. 0.22
  let c = 0.2 *. 0.21 +. 0.2 *. 0.22 +. 0.21 *. 0.22
  let b = -0.63
  let curve =
    svg_path.CubicBezier(
      svg_path.Point(0.0, d),
      svg_path.Point(1.0 /. 3.0, d +. c /. 3.0),
      svg_path.Point(2.0 /. 3.0, d +. 2.0 *. c /. 3.0 +. b /. 3.0),
      svg_path.Point(1.0, d +. c +. b +. 1.0),
    )
  let assert Ok(found) =
    ix.segment_with(curve, horizontal(), options: ix.default_options())
  assert list.length(found) == 3
  list.each([0.2, 0.21, 0.22], fn(t) {
    assert list.any(found, fn(hit) {
      float.absolute_value(hit.left_t -. t) <=. 0.0000001
      && float.absolute_value(hit.right_t -. t) <=. 0.0000001
    })
  })
}

pub fn elizabeth_endpoint_preference_test() {
  let rising =
    svg_path.QuadraticBezier(
      svg_path.Point(0.0, 0.0),
      svg_path.Point(0.5, 0.5),
      svg_path.Point(1.0, 1.0),
    )
  let assert Ok(found) =
    ix.segment_with(horizontal(), rising, options: ix.default_options())
  let assert [hit] = found
  assert hit.left_t == 0.0 && hit.right_t == 0.0
}

pub fn elizabeth_kissing_candidates_obey_resolution_contract_test() {
  let tangent =
    svg_path.QuadraticBezier(
      svg_path.Point(0.0, 0.25),
      svg_path.Point(0.5, -0.25),
      svg_path.Point(1.0, 0.25),
    )
  let flat = horizontal()
  let assert Ok(found) =
    ix.segment_with(flat, tangent, options: ix.default_options())
  assert !list.is_empty(found)
  assert list.any(found, fn(hit) { hit.left_t == 0.5 && hit.right_t == 0.5 })
  list.index_map(found, fn(hit, index) {
    let assert Ok(a) = svg_path.segment_point(flat, hit.left_t)
    let assert Ok(b) = svg_path.segment_point(tangent, hit.right_t)
    let dx = a.x -. b.x
    let dy = a.y -. b.y
    assert dx *. dx +. dy *. dy <=. 0.000000000001 *. 0.000000000001
    list.each(list.drop(found, index + 1), fn(other) {
      assert float.absolute_value(hit.left_t -. other.left_t) >. 0.0000001
        || float.absolute_value(hit.right_t -. other.right_t) >. 0.0000001
    })
  })
  Nil
}

pub fn elizabeth_disjoint_windows_need_no_refinement_test() {
  let other =
    svg_path.QuadraticBezier(
      svg_path.Point(0.0, 1.0),
      svg_path.Point(0.5, 1.0),
      svg_path.Point(1.0, 1.0),
    )
  let options = ix.IntersectionOptions(..ix.default_options(), max_depth: 1)
  assert ix.segment_with(horizontal(), other, options: options) == Ok([])
}
