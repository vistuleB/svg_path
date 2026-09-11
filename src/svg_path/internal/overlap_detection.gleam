//// Dependency-neutral raw segment-overlap detection.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import svg_path
import svg_path/internal/number
import svg_path/point

const overlap_samples = 5

const overlap_parameter_tolerance = 0.000000000001

type OverlapCandidates {
  OverlapCandidates(affine: List(RawOverlap), non_affine: List(RawOverlap))
}

/// Internal transport representation. The public nominal type belongs to
/// `svg_path/overlaps`.
@internal
pub type RawOverlap =
  #(Float, Float, Float, Float, svg_path.Point, svg_path.Point)

/// The result of combining two overlap intervals for the same ordered segment
/// pair.
type RawOverlapMerge {
  Disjoint
  Merged(RawOverlap)
  Contradiction
}

type ProjectionSource {
  LeftEndpoint
  RightEndpoint
}

type EndpointProjection {
  EndpointProjection(
    source: ProjectionSource,
    source_t: Float,
    target_t: Float,
    distance: Float,
  )
}

fn canonicalize_overlap(overlap: RawOverlap) -> RawOverlap {
  let #(left_from, left_to, right_from, right_to, start, end) = overlap
  case left_from <=. left_to {
    True -> overlap
    False -> #(left_to, left_from, right_to, right_from, end, start)
  }
}

/// Whether an overlap has a positive parameter span on both segments.
fn overlap_has_positive_span(overlap: RawOverlap) -> Bool {
  let #(left_from, left_to, right_from, right_to, _, _) = overlap
  left_to >. left_from && right_to != right_from
}

/// Combine two overlap intervals belonging to the same ordered segment pair.
///
/// Canonical inputs have increasing left parameters, non-zero spans on both
/// segments, and endpoints ordered by the left segment. Intervals merge when
/// they overlap or touch consistently in both parameter spaces. A mismatch
/// between the two parameter spaces or their traversal directions is a
/// contradiction.
fn merge_overlaps(
  first: RawOverlap,
  second: RawOverlap,
  tolerance tolerance: Float,
) -> RawOverlapMerge {
  let #(
    first_left_from,
    first_left_to,
    first_right_from,
    first_right_to,
    first_start,
    first_end,
  ) = first
  let #(
    second_left_from,
    second_left_to,
    second_right_from,
    second_right_to,
    second_start,
    second_end,
  ) = second
  let first_right_increases = first_right_to >. first_right_from
  let second_right_increases = second_right_to >. second_right_from
  let valid =
    tolerance >=. 0.0
    && first_left_to >. first_left_from
    && second_left_to >. second_left_from
    && first_right_to != first_right_from
    && second_right_to != second_right_from
  case valid {
    False -> Contradiction
    True -> {
      let endpoints_touch =
        points_near(first_end, second_start, tolerance)
        || points_near(first_start, second_end, tolerance)
      let lefts_touch =
        endpoints_touch
        || intervals_overlap(
          first_left_from,
          first_left_to,
          second_left_from,
          second_left_to,
        )
      let rights_touch =
        endpoints_touch
        || intervals_overlap(
          min_float(first_right_from, first_right_to),
          max_float(first_right_from, first_right_to),
          min_float(second_right_from, second_right_to),
          max_float(second_right_from, second_right_to),
        )
      case lefts_touch, rights_touch {
        False, False -> Disjoint
        False, True | True, False -> Contradiction
        True, True -> {
          let compatible =
            first_right_increases == second_right_increases
            && parameter_order_compatible(
              first_left_from,
              second_left_from,
              first_right_from,
              second_right_from,
              first_right_increases,
            )
            && parameter_order_compatible(
              first_left_to,
              second_left_to,
              first_right_to,
              second_right_to,
              first_right_increases,
            )
            && coincident_boundary_compatible(
              first_left_from,
              second_left_from,
              first_right_from,
              second_right_from,
              first_start,
              second_start,
              tolerance,
            )
            && coincident_boundary_compatible(
              first_left_to,
              second_left_to,
              first_right_to,
              second_right_to,
              first_end,
              second_end,
              tolerance,
            )
            && coincident_boundary_compatible(
              first_left_to,
              second_left_from,
              first_right_to,
              second_right_from,
              first_end,
              second_start,
              tolerance,
            )
            && coincident_boundary_compatible(
              first_left_from,
              second_left_to,
              first_right_from,
              second_right_to,
              first_start,
              second_end,
              tolerance,
            )
          case compatible {
            False -> Contradiction
            True -> {
              let #(left_from, right_from, start) = case
                first_left_from <=. second_left_from
              {
                True -> #(first_left_from, first_right_from, first_start)
                False -> #(second_left_from, second_right_from, second_start)
              }
              let #(left_to, right_to, end) = case
                first_left_to >=. second_left_to
              {
                True -> #(first_left_to, first_right_to, first_end)
                False -> #(second_left_to, second_right_to, second_end)
              }
              Merged(#(left_from, left_to, right_from, right_to, start, end))
            }
          }
        }
      }
    }
  }
}

/// Merge every compatible overlap interval for one ordered segment pair.
///
/// Disjoint intervals remain separate. Any contradictory pair rejects the
/// collection.
fn merge_overlap_list(
  overlaps: List(RawOverlap),
  tolerance tolerance: Float,
) -> Result(List(RawOverlap), Nil) {
  merge_overlap_list_loop(overlaps, tolerance, [])
}

fn merge_overlap_list_loop(
  overlaps: List(RawOverlap),
  tolerance: Float,
  merged: List(RawOverlap),
) -> Result(List(RawOverlap), Nil) {
  case overlaps {
    [] -> Ok(list.reverse(merged))
    [first, ..rest] -> {
      use merged <- result.try(insert_overlap(first, merged, tolerance))
      merge_overlap_list_loop(rest, tolerance, merged)
    }
  }
}

fn insert_overlap(
  overlap: RawOverlap,
  overlaps: List(RawOverlap),
  tolerance: Float,
) -> Result(List(RawOverlap), Nil) {
  insert_overlap_loop(overlap, overlaps, tolerance, [])
}

fn insert_overlap_loop(
  overlap: RawOverlap,
  overlaps: List(RawOverlap),
  tolerance: Float,
  disjoint: List(RawOverlap),
) -> Result(List(RawOverlap), Nil) {
  case overlaps {
    [] -> Ok([overlap, ..disjoint])
    [first, ..rest] ->
      case merge_overlaps(overlap, first, tolerance:) {
        Contradiction -> Error(Nil)
        Disjoint ->
          insert_overlap_loop(overlap, rest, tolerance, [first, ..disjoint])
        Merged(combined) ->
          insert_overlap_loop(
            combined,
            list.append(rest, disjoint),
            tolerance,
            [],
          )
      }
  }
}

/// Find sampled overlap intervals proposed by endpoint matches.
///
/// This sampled overlap detector assumes non-degenerate segments and that every
/// overlap boundary is an endpoint of at least one input segment. Every pair
/// of endpoint matches within `tolerance` proposes an interval. Matches include
/// explicit target endpoints and roots of both coordinate equations, alongside
/// the closest projection. Interior
/// samples on the proposed left interval must remain within `tolerance` of the
/// proposed right interval. Compatible proposals are merged into maximal
/// intervals.
@internal
pub fn detect_with_samples(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance tolerance: Float,
  samples samples: Int,
) -> Result(List(RawOverlap), svg_path.Error) {
  case tolerance <. 0.0 || tolerance -. tolerance != 0.0, samples <= 0 {
    True, _ -> Error(svg_path.InvalidOverlapTolerance(tolerance))
    _, True -> Error(svg_path.InvalidOverlapSamples(samples))
    False, False -> {
      use projections <- result.try(endpoint_projections(left, right, tolerance))
      let close =
        projections
        |> list.filter(fn(projection) {
          let EndpointProjection(distance:, ..) = projection
          distance <=. tolerance
        })
      use candidates <- result.try(overlap_candidates_from_projection_pairs(
        close,
        left,
        right,
        tolerance,
        samples,
        OverlapCandidates([], []),
      ))
      // A failed parameter pairing is not proof of non-affinity when another
      // pairing explains the same two parameter intervals (e.g. a closed
      // curve has two endpoint addresses at the same geometric point).
      case
        list.any(candidates.non_affine, fn(rejected) {
          !candidate_covered(rejected, candidates.affine)
        })
      {
        True -> Error(svg_path.NonAffineOverlapCorrespondence)
        False ->
          case merge_overlap_list(candidates.affine, tolerance:) {
            Ok(merged) -> Ok(merged)
            Error(Nil) -> Ok([])
          }
      }
    }
  }
}

/// Find overlap intervals using the shared five-sample policy.
@internal
pub fn detect(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance tolerance: Float,
) -> Result(List(RawOverlap), svg_path.Error) {
  detect_with_samples(left, right, tolerance:, samples: overlap_samples)
}

/// Check one proposed endpoint-parameter correspondence.
///
/// `Ok(Some(_))` means the proposed parameter interval is a positive-span
/// affine overlap. `Ok(None)` means the proposed interval is not coincident
/// under the supplied tolerance. A non-affine coincident correspondence is an
/// error, matching the module-wide overlap contract.
/// Both endpoint pairs are checked explicitly, in addition to interior samples.
@internal
pub fn check_parameter_correspondence(
  left: svg_path.Segment,
  right: svg_path.Segment,
  left_from left_from: Float,
  left_to left_to: Float,
  right_from right_from: Float,
  right_to right_to: Float,
  tolerance tolerance: Float,
  samples samples: Int,
) -> Result(Option(RawOverlap), svg_path.Error) {
  case tolerance <. 0.0 || tolerance -. tolerance != 0.0, samples <= 0 {
    True, _ -> Error(svg_path.InvalidOverlapTolerance(tolerance))
    _, True -> Error(svg_path.InvalidOverlapSamples(samples))
    False, False -> {
      use start <- result.try(svg_path.segment_point(left, at: left_from))
      use end <- result.try(svg_path.segment_point(left, at: left_to))
      let overlap =
        canonicalize_overlap(#(
          left_from,
          left_to,
          right_from,
          right_to,
          start,
          end,
        ))
      case overlap_has_positive_span(overlap) {
        False -> Ok(None)
        True -> {
          use right_start <- result.try(svg_path.segment_point(
            right,
            at: right_from,
          ))
          use right_end <- result.try(svg_path.segment_point(
            right,
            at: right_to,
          ))
          // Unlike endpoint-projection proposals, supplied correspondences
          // have not yet established endpoint coincidence. Interior samples
          // alone can miss an endpoint mismatch, even between two lines.
          use valid_sampled <- result.try(
            case
              points_near(start, right_start, tolerance)
              && points_near(end, right_end, tolerance)
            {
              False -> Ok(False)
              True ->
                sampled_overlap_valid(overlap, left, right, tolerance, samples)
            },
          )
          case valid_sampled {
            False -> Ok(None)
            True -> {
              use valid_affine <- result.try(affine_correspondence_valid(
                overlap,
                left,
                right,
                tolerance,
                samples,
              ))
              case valid_affine {
                True -> Ok(Some(overlap))
                False -> Error(svg_path.NonAffineOverlapCorrespondence)
              }
            }
          }
        }
      }
    }
  }
}

// Coverage is about the parameter domains, not the rejected orientation.
// Require both domains to be explained; an unrelated accepted overlap must
// not suppress a genuine non-affine overlap elsewhere on the curves.
fn candidate_covered(
  candidate: RawOverlap,
  accepted: List(RawOverlap),
) -> Bool {
  let #(lf, lt, rf, rt, _, _) = candidate
  let left =
    list.map(accepted, fn(item) {
      let #(a, b, _, _, _, _) = item
      #(min_float(a, b), max_float(a, b))
    })
  let right =
    list.map(accepted, fn(item) {
      let #(_, _, a, b, _, _) = item
      #(min_float(a, b), max_float(a, b))
    })
  intervals_cover(
    list.sort(left, fn(a, b) { float.compare(a.0, b.0) }),
    min_float(lf, lt),
    max_float(lf, lt),
  )
  && intervals_cover(
    list.sort(right, fn(a, b) { float.compare(a.0, b.0) }),
    min_float(rf, rt),
    max_float(rf, rt),
  )
}

fn intervals_cover(
  intervals: List(#(Float, Float)),
  from: Float,
  to: Float,
) -> Bool {
  case from >=. to, intervals {
    True, _ -> True
    False, [] -> False
    False, [#(start, end), ..rest] ->
      case start >. from {
        True -> False
        False -> intervals_cover(rest, max_float(from, end), to)
      }
  }
}

fn endpoint_projections(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
) -> Result(List(EndpointProjection), svg_path.Error) {
  use left_start <- result.try(endpoint_projection_alternatives(
    LeftEndpoint,
    0.0,
    svg_path.segment_start(left),
    right,
    tolerance,
  ))
  use left_end <- result.try(endpoint_projection_alternatives(
    LeftEndpoint,
    1.0,
    svg_path.segment_end(left),
    right,
    tolerance,
  ))
  use right_start <- result.try(endpoint_projection_alternatives(
    RightEndpoint,
    0.0,
    svg_path.segment_start(right),
    left,
    tolerance,
  ))
  use right_end <- result.try(endpoint_projection_alternatives(
    RightEndpoint,
    1.0,
    svg_path.segment_end(right),
    left,
    tolerance,
  ))
  Ok(list.unique(list.flatten([left_start, left_end, right_start, right_end])))
}

fn endpoint_projection_alternatives(
  source: ProjectionSource,
  source_t: Float,
  point: svg_path.Point,
  target: svg_path.Segment,
  tolerance: Float,
) -> Result(List(EndpointProjection), svg_path.Error) {
  use matches <- result.try(point_parameters(target, point, tolerance))
  list.try_map(matches, fn(target_t) {
    use at <- result.try(svg_path.segment_point(target, at: target_t))
    Ok(EndpointProjection(
      source:,
      source_t:,
      target_t:,
      distance: point.distance(point, at),
    ))
  })
}

// Shared endpoint-on-segment inventory: coordinate roots plus closest-point
// candidates, geometrically checked and deduplicated by parameter, not point.
// Exact endpoints have priority. Constant/overlapping inputs do not have a
// finite all-parameters inventory; callers retain their overlap prechecks.
@internal
pub fn point_parameters(
  target: svg_path.Segment,
  point: svg_path.Point,
  tolerance: Float,
) -> Result(List(Float), svg_path.Error) {
  let x = coordinate_matches(target, point, True, tolerance)
  let y = coordinate_matches(target, point, False, tolerance)
  use coordinates <- result.try(combine_coordinate_matches(x, y))
  // Keep closest projection for approximate coincidences too. A complete
  // coordinate inventory can replace a failed projection, but not an arbitrary
  // partial collection of geometric matches.
  let projection = svg_path.segment_projection(point, to: target)
  use projected <- result.try(case projection {
    Ok(found) -> Ok([found.t])
    Error(svg_path.DistanceMaxIterationsReached(..) as error) ->
      case complete_coordinate(x) || complete_coordinate(y) {
        True -> Ok([])
        False -> Error(error)
      }
    Error(error) -> Error(error)
  })
  matching_parameters(
    target,
    point,
    [0.0, 1.0, ..list.append(coordinates, projected)],
    tolerance,
  )
}

// The existing supporting-line query solves coordinate polynomials for
// Béziers, and uses the ellipse's angular representation for arcs.
fn coordinate_matches(
  segment: svg_path.Segment,
  at: svg_path.Point,
  x: Bool,
  tolerance: Float,
) -> Result(#(List(Float), Int), svg_path.Error) {
  let degree = coordinate_degree(segment, x)
  case degree == 0 {
    True -> Ok(#([], 0))
    False -> {
      let options =
        svg_path.CrossingOptions(
          ..svg_path.default_crossing_options(),
          signed_line_distance_tolerance: float.max(
            tolerance *. 0.25,
            0.000000000001,
          ),
        )
      use roots <- result.try(svg_path.segment_ray_crossings_with(
        segment,
        origin: at,
        direction: case x {
          True -> svg_path.Point(0.0, 1.0)
          False -> svg_path.Point(1.0, 0.0)
        },
        options:,
      ))
      use matches <- result.try(matching_parameters(
        segment,
        at,
        [0.0, 1.0, ..list.map(roots, fn(pair) { pair.0 })],
        tolerance,
      ))
      Ok(#(matches, degree))
    }
  }
}

fn complete_coordinate(
  found: Result(#(List(Float), Int), svg_path.Error),
) -> Bool {
  // A degree-d coordinate has at most d distinct roots. Only geometrically
  // verified, deduplicated matches count toward exhausting this bound.
  case found {
    Ok(#(matches, degree)) -> degree > 0 && list.length(matches) == degree
    Error(_) -> False
  }
}

fn combine_coordinate_matches(
  x: Result(#(List(Float), Int), svg_path.Error),
  y: Result(#(List(Float), Int), svg_path.Error),
) -> Result(List(Float), svg_path.Error) {
  case x, y {
    Ok(#(xs, _)), Ok(#(ys, _)) -> Ok(list.append(xs, ys))
    Ok(#(xs, _)), Error(svg_path.CrossingMaxIterationsReached(..)) ->
      case complete_coordinate(x) {
        True -> Ok(xs)
        False -> result.map(y, fn(pair) { pair.0 })
      }
    Error(svg_path.CrossingMaxIterationsReached(..)), Ok(#(ys, _)) ->
      case complete_coordinate(y) {
        True -> Ok(ys)
        False -> result.map(x, fn(pair) { pair.0 })
      }
    Error(error), _ | _, Error(error) -> Error(error)
  }
}

// Deduplicate addresses, never positions. Endpoint candidates go first so
// exact 0/1 win over nearby numerical roots after geometric verification.
fn matching_parameters(
  segment: svg_path.Segment,
  at: svg_path.Point,
  parameters: List(Float),
  tolerance: Float,
) -> Result(List(Float), svg_path.Error) {
  list.try_fold(parameters, [], fn(found, t) {
    use candidate <- result.try(svg_path.segment_point(segment, at: t))
    case
      point.distance(at, candidate) <=. tolerance
      && !list.any(found, fn(previous) {
        float.absolute_value(previous -. t) <=. 0.000000001
      })
    {
      True -> Ok(list.append(found, [t]))
      False -> Ok(found)
    }
  })
}

fn coordinate_degree(segment: svg_path.Segment, x: Bool) -> Int {
  let component = fn(p: svg_path.Point) {
    case x {
      True -> p.x
      False -> p.y
    }
  }
  case segment {
    svg_path.Line(a, b) ->
      case number.is_zero(component(b) -. component(a)) {
        True -> 0
        False -> 1
      }
    svg_path.QuadraticBezier(a, b, c) ->
      coordinate_control_degree([component(a), component(b), component(c)])
    svg_path.CubicBezier(a, b, c, d) ->
      coordinate_control_degree([
        component(a),
        component(b),
        component(c),
        component(d),
      ])
    // No polynomial completeness claim for arcs. Their angular solver still
    // supplies candidates, including both visits to a closed seam.
    svg_path.Arc(..) -> -1
  }
}

fn coordinate_control_degree(values: List(Float)) -> Int {
  let differences = control_differences(values)
  case list.any(differences, fn(value) { !number.is_zero(value) }) {
    False -> 0
    True -> 1 + coordinate_control_degree(differences)
  }
}

fn control_differences(values: List(Float)) -> List(Float) {
  case values {
    [a, b, ..rest] -> [b -. a, ..control_differences([b, ..rest])]
    _ -> []
  }
}

fn overlap_candidates_from_projection_pairs(
  projections: List(EndpointProjection),
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
  samples: Int,
  candidates: OverlapCandidates,
) -> Result(OverlapCandidates, svg_path.Error) {
  case projections {
    [] -> Ok(candidates)
    [first, ..rest] -> {
      use candidates <- result.try(overlap_candidates_against(
        first,
        rest,
        left,
        right,
        tolerance,
        samples,
        candidates,
      ))
      overlap_candidates_from_projection_pairs(
        rest,
        left,
        right,
        tolerance,
        samples,
        candidates,
      )
    }
  }
}

fn overlap_candidates_against(
  first: EndpointProjection,
  projections: List(EndpointProjection),
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
  samples: Int,
  candidates: OverlapCandidates,
) -> Result(OverlapCandidates, svg_path.Error) {
  case projections {
    [] -> Ok(candidates)
    [second, ..rest] -> {
      use candidate <- result.try(overlap_from_projection_pair(
        first,
        second,
        left,
      ))
      use accepted <- result.try(case candidate {
        Error(Nil) -> Ok(Error(Nil))
        Ok(overlap) ->
          case overlap_has_positive_span(overlap) {
            False -> Ok(Error(Nil))
            True -> {
              use valid <- result.try(sampled_overlap_valid(
                overlap,
                left,
                right,
                tolerance,
                samples,
              ))
              case valid {
                False -> Ok(Error(Nil))
                True -> {
                  use affine <- result.try(affine_correspondence_valid(
                    overlap,
                    left,
                    right,
                    tolerance,
                    samples,
                  ))
                  case affine {
                    True -> Ok(Ok(#(overlap, True)))
                    False -> {
                      // One-sided containment can accept a wrong pairing whose
                      // target interval includes an extra loop. That is not
                      // evidence of a non-affine overlap between the intervals.
                      let #(lf, lt, rf, rt, start, end) = overlap
                      let opposite =
                        canonicalize_overlap(#(rf, rt, lf, lt, start, end))
                      use reciprocal <- result.try(sampled_overlap_valid(
                        opposite,
                        right,
                        left,
                        tolerance,
                        samples,
                      ))
                      case reciprocal {
                        True -> Ok(Ok(#(overlap, False)))
                        False -> Ok(Error(Nil))
                      }
                    }
                  }
                }
              }
            }
          }
      })
      let candidates = case accepted {
        Ok(#(overlap, True)) ->
          OverlapCandidates(..candidates, affine: [overlap, ..candidates.affine])
        Ok(#(overlap, False)) ->
          OverlapCandidates(..candidates, non_affine: [
            overlap,
            ..candidates.non_affine
          ])
        Error(Nil) -> candidates
      }
      overlap_candidates_against(
        first,
        rest,
        left,
        right,
        tolerance,
        samples,
        candidates,
      )
    }
  }
}

fn overlap_from_projection_pair(
  first: EndpointProjection,
  second: EndpointProjection,
  left: svg_path.Segment,
) -> Result(Result(RawOverlap, Nil), svg_path.Error) {
  let EndpointProjection(
    source: first_source,
    source_t: first_source_t,
    target_t: first_target_t,
    ..,
  ) = first
  let EndpointProjection(
    source: second_source,
    source_t: second_source_t,
    target_t: second_target_t,
    ..,
  ) = second
  let #(left_from, left_to, right_from, right_to) = case
    first_source,
    second_source
  {
    LeftEndpoint, LeftEndpoint -> #(
      first_source_t,
      second_source_t,
      first_target_t,
      second_target_t,
    )
    RightEndpoint, RightEndpoint -> #(
      first_target_t,
      second_target_t,
      first_source_t,
      second_source_t,
    )
    LeftEndpoint, RightEndpoint -> #(
      first_source_t,
      second_target_t,
      first_target_t,
      second_source_t,
    )
    RightEndpoint, LeftEndpoint -> #(
      first_target_t,
      second_source_t,
      first_source_t,
      second_target_t,
    )
  }
  use start <- result.try(svg_path.segment_point(left, at: left_from))
  use end <- result.try(svg_path.segment_point(left, at: left_to))
  Ok(
    Ok(
      canonicalize_overlap(#(
        left_from,
        left_to,
        right_from,
        right_to,
        start,
        end,
      )),
    ),
  )
}

fn sampled_overlap_valid(
  overlap: RawOverlap,
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
  samples: Int,
) -> Result(Bool, svg_path.Error) {
  let #(left_from, left_to, right_from, right_to, _, _) = overlap
  use right_piece <- result.try(svg_path.segment_between_inside(
    right,
    from: min_float(right_from, right_to),
    to: max_float(right_from, right_to),
  ))
  sampled_overlap_valid_loop(
    left,
    right_piece,
    left_from,
    left_to,
    tolerance,
    samples,
    1,
  )
}

fn sampled_overlap_valid_loop(
  left: svg_path.Segment,
  right_piece: svg_path.Segment,
  left_from: Float,
  left_to: Float,
  tolerance: Float,
  samples: Int,
  index: Int,
) -> Result(Bool, svg_path.Error) {
  case index > samples {
    True -> Ok(True)
    False -> {
      let portion = int.to_float(index) /. int.to_float(samples + 1)
      let t = left_from +. { left_to -. left_from } *. portion
      use point <- result.try(svg_path.segment_point(left, at: t))
      use distance <- result.try(svg_path.segment_distance(
        point,
        to: right_piece,
      ))
      case distance <=. tolerance {
        False -> Ok(False)
        True ->
          sampled_overlap_valid_loop(
            left,
            right_piece,
            left_from,
            left_to,
            tolerance,
            samples,
            index + 1,
          )
      }
    }
  }
}

fn affine_correspondence_valid(
  overlap: RawOverlap,
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
  samples: Int,
) -> Result(Bool, svg_path.Error) {
  let #(left_from, left_to, right_from, right_to, _, _) = overlap
  affine_correspondence_valid_loop(
    left,
    right,
    left_from,
    left_to,
    right_from,
    right_to,
    tolerance,
    samples,
    1,
  )
}

fn affine_correspondence_valid_loop(
  left: svg_path.Segment,
  right: svg_path.Segment,
  left_from: Float,
  left_to: Float,
  right_from: Float,
  right_to: Float,
  tolerance: Float,
  samples: Int,
  index: Int,
) -> Result(Bool, svg_path.Error) {
  case index > samples {
    True -> Ok(True)
    False -> {
      let portion = int.to_float(index) /. int.to_float(samples + 1)
      let left_t = left_from +. { left_to -. left_from } *. portion
      let right_t = right_from +. { right_to -. right_from } *. portion
      use left_point <- result.try(svg_path.segment_point(left, at: left_t))
      use right_point <- result.try(svg_path.segment_point(right, at: right_t))
      case points_near(left_point, right_point, tolerance) {
        False -> Ok(False)
        True ->
          affine_correspondence_valid_loop(
            left,
            right,
            left_from,
            left_to,
            right_from,
            right_to,
            tolerance,
            samples,
            index + 1,
          )
      }
    }
  }
}

fn intervals_overlap(
  first_from: Float,
  first_to: Float,
  second_from: Float,
  second_to: Float,
) -> Bool {
  first_from <=. second_to && second_from <=. first_to
}

fn parameter_order_compatible(
  first_left: Float,
  second_left: Float,
  first_right: Float,
  second_right: Float,
  right_increases: Bool,
) -> Bool {
  case first_left <. second_left, first_left >. second_left {
    True, _ ->
      case right_increases {
        True -> first_right <=. second_right
        False -> first_right >=. second_right
      }
    _, True ->
      case right_increases {
        True -> first_right >=. second_right
        False -> first_right <=. second_right
      }
    False, False ->
      float.absolute_value(first_right -. second_right)
      <=. overlap_parameter_tolerance
  }
}

fn coincident_boundary_compatible(
  first_left: Float,
  second_left: Float,
  first_right: Float,
  second_right: Float,
  first_point: svg_path.Point,
  second_point: svg_path.Point,
  tolerance: Float,
) -> Bool {
  case first_left == second_left {
    False -> True
    True ->
      float.absolute_value(first_right -. second_right)
      <=. overlap_parameter_tolerance
      && points_near(first_point, second_point, tolerance)
  }
}

fn points_near(
  first: svg_path.Point,
  second: svg_path.Point,
  tolerance: Float,
) -> Bool {
  let dx = first.x -. second.x
  let dy = first.y -. second.y
  dx *. dx +. dy *. dy <=. tolerance *. tolerance
}

fn min_float(a: Float, b: Float) -> Float {
  case a <. b {
    True -> a
    False -> b
  }
}

fn max_float(a: Float, b: Float) -> Float {
  case a >. b {
    True -> a
    False -> b
  }
}
