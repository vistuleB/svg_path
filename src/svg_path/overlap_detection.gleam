//// Dependency-neutral raw segment-overlap detection.

import gleam/float
import gleam/int
import gleam/list
import gleam/result
import svg_path

const overlap_samples = 5

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

/// Whether an overlap has a strictly larger parameter span than `minimum_span`
/// on both segments.
fn overlap_exceeds_minimum_span(
  overlap: RawOverlap,
  minimum_span minimum_span: Float,
) -> Bool {
  let #(left_from, left_to, right_from, right_to, _, _) = overlap
  left_to -. left_from >. minimum_span
  && float.absolute_value(right_to -. right_from) >. minimum_span
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
    && first_left_to -. first_left_from >. tolerance
    && second_left_to -. second_left_from >. tolerance
    && float.absolute_value(first_right_to -. first_right_from) >. tolerance
    && float.absolute_value(second_right_to -. second_right_from) >. tolerance
  case valid {
    False -> Contradiction
    True -> {
      let lefts_touch =
        intervals_touch(
          first_left_from,
          first_left_to,
          second_left_from,
          second_left_to,
          tolerance,
        )
      let rights_touch =
        intervals_touch(
          min_float(first_right_from, first_right_to),
          max_float(first_right_from, first_right_to),
          min_float(second_right_from, second_right_to),
          max_float(second_right_from, second_right_to),
          tolerance,
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
              tolerance,
            )
            && parameter_order_compatible(
              first_left_to,
              second_left_to,
              first_right_to,
              second_right_to,
              first_right_increases,
              tolerance,
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

/// Find sampled overlap intervals proposed by endpoint projections.
///
/// This experimental algorithm assumes non-degenerate segments and that every
/// overlap boundary is an endpoint of at least one input segment. Every pair
/// of endpoint projections within `tolerance` proposes an interval. Interior
/// samples on the proposed left interval must remain within `tolerance` of the
/// proposed right interval. Compatible proposals are merged into maximal
/// intervals.
@internal
pub fn detect_with(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance tolerance: Float,
  samples samples: Int,
) -> Result(List(RawOverlap), svg_path.Error) {
  case tolerance <. 0.0, samples <= 0 {
    True, _ -> Error(svg_path.InvalidOverlapTolerance(tolerance))
    _, True -> Error(svg_path.InvalidOverlapSamples(samples))
    False, False -> {
      use projections <- result.try(endpoint_projections(left, right))
      let close =
        projections
        |> list.filter(fn(projection) {
          let EndpointProjection(distance:, ..) = projection
          distance <=. tolerance
        })
      use candidates <- result.try(
        overlap_candidates_from_projection_pairs(
          close,
          left,
          right,
          tolerance,
          samples,
          [],
        ),
      )
      case merge_overlap_list(candidates, tolerance:) {
        Ok(merged) -> Ok(merged)
        Error(Nil) -> Ok([])
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
  detect_with(left, right, tolerance:, samples: overlap_samples)
}

fn endpoint_projections(
  left: svg_path.Segment,
  right: svg_path.Segment,
) -> Result(List(EndpointProjection), svg_path.Error) {
  use left_start <- result.try(endpoint_projection(
    LeftEndpoint,
    0.0,
    svg_path.segment_start(left),
    right,
  ))
  use left_end <- result.try(endpoint_projection(
    LeftEndpoint,
    1.0,
    svg_path.segment_end(left),
    right,
  ))
  use right_start <- result.try(endpoint_projection(
    RightEndpoint,
    0.0,
    svg_path.segment_start(right),
    left,
  ))
  use right_end <- result.try(endpoint_projection(
    RightEndpoint,
    1.0,
    svg_path.segment_end(right),
    left,
  ))
  Ok([left_start, left_end, right_start, right_end])
}

fn endpoint_projection(
  source: ProjectionSource,
  source_t: Float,
  point: svg_path.Point,
  target: svg_path.Segment,
) -> Result(EndpointProjection, svg_path.Error) {
  use projection <- result.try(svg_path.segment_projection(point, to: target))
  let svg_path.SegmentProjection(t: target_t, distance:, ..) = projection
  Ok(EndpointProjection(source:, source_t:, target_t:, distance:))
}

fn overlap_candidates_from_projection_pairs(
  projections: List(EndpointProjection),
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
  samples: Int,
  candidates: List(RawOverlap),
) -> Result(List(RawOverlap), svg_path.Error) {
  case projections {
    [] -> Ok(list.reverse(candidates))
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
  candidates: List(RawOverlap),
) -> Result(List(RawOverlap), svg_path.Error) {
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
          case overlap_exceeds_minimum_span(overlap, minimum_span: tolerance) {
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
                    True -> Ok(Ok(overlap))
                    False -> Error(svg_path.NonAffineOverlapCorrespondence)
                  }
                }
              }
            }
          }
      })
      let candidates = case accepted {
        Ok(overlap) -> [overlap, ..candidates]
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

fn intervals_touch(
  first_from: Float,
  first_to: Float,
  second_from: Float,
  second_to: Float,
  tolerance: Float,
) -> Bool {
  first_from <=. second_to +. tolerance && second_from <=. first_to +. tolerance
}

fn parameter_order_compatible(
  first_left: Float,
  second_left: Float,
  first_right: Float,
  second_right: Float,
  right_increases: Bool,
  tolerance: Float,
) -> Bool {
  case
    first_left <. second_left -. tolerance,
    first_left >. second_left +. tolerance
  {
    True, _ ->
      case right_increases {
        True -> first_right <=. second_right +. tolerance
        False -> first_right +. tolerance >=. second_right
      }
    _, True ->
      case right_increases {
        True -> first_right +. tolerance >=. second_right
        False -> first_right <=. second_right +. tolerance
      }
    False, False ->
      float.absolute_value(first_right -. second_right) <=. tolerance
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
  case float.absolute_value(first_left -. second_left) <=. tolerance {
    False -> True
    True ->
      float.absolute_value(first_right -. second_right) <=. tolerance
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
