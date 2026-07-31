//// Explicit finite encounters between path segments.
////
//// This module supplements `intersections`: a coincident span is returned as
//// an `Overlap` encounter instead of being surfaced as `OverlappingSegments`.

import gleam/float
import gleam/int
import gleam/list
import gleam/result
import svg_path
import svg_path/intersections

/// One non-zero-length overlap interval between the same ordered pair of
/// segments. The left parameters and points follow the left segment's
/// traversal. The right parameters retain the corresponding traversal
/// direction and may therefore decrease.
pub type SegmentOverlap {
  SegmentOverlap(
    left_from: Float,
    left_to: Float,
    right_from: Float,
    right_to: Float,
    start: svg_path.Point,
    end: svg_path.Point,
  )
}

/// The result of combining two overlap intervals for the same ordered segment
/// pair.
pub type SegmentOverlapMerge {
  Disjoint
  Merged(SegmentOverlap)
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

pub type SegmentEncounter {
  Intersection(left_t: Float, right_t: Float, point: svg_path.Point)
  Overlap(
    left_from: Float,
    left_to: Float,
    right_from: Float,
    right_to: Float,
    start: svg_path.Point,
    end: svg_path.Point,
  )
}

/// Orient an overlap by increasing parameter on the left segment.
///
/// Reorientation swaps both right parameters as well as the geometric
/// endpoints, preserving the correspondence between the two traversals.
pub fn canonicalize_segment_overlap(overlap: SegmentOverlap) -> SegmentOverlap {
  let SegmentOverlap(left_from:, left_to:, right_from:, right_to:, start:, end:) =
    overlap
  case left_from <=. left_to {
    True -> overlap
    False ->
      SegmentOverlap(
        left_from: left_to,
        left_to: left_from,
        right_from: right_to,
        right_to: right_from,
        start: end,
        end: start,
      )
  }
}

/// Whether an overlap has a strictly larger parameter span than `minimum_span`
/// on both segments.
pub fn segment_overlap_exceeds_minimum_span(
  overlap: SegmentOverlap,
  minimum_span minimum_span: Float,
) -> Bool {
  let SegmentOverlap(left_from:, left_to:, right_from:, right_to:, ..) = overlap
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
pub fn merge_segment_overlaps(
  first: SegmentOverlap,
  second: SegmentOverlap,
  tolerance tolerance: Float,
) -> SegmentOverlapMerge {
  let SegmentOverlap(
    left_from: first_left_from,
    left_to: first_left_to,
    right_from: first_right_from,
    right_to: first_right_to,
    start: first_start,
    end: first_end,
  ) = first
  let SegmentOverlap(
    left_from: second_left_from,
    left_to: second_left_to,
    right_from: second_right_from,
    right_to: second_right_to,
    start: second_start,
    end: second_end,
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
              Merged(SegmentOverlap(
                left_from:,
                left_to:,
                right_from:,
                right_to:,
                start:,
                end:,
              ))
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
pub fn merge_segment_overlap_list(
  overlaps: List(SegmentOverlap),
  tolerance tolerance: Float,
) -> Result(List(SegmentOverlap), Nil) {
  merge_segment_overlap_list_loop(overlaps, tolerance, [])
}

fn merge_segment_overlap_list_loop(
  overlaps: List(SegmentOverlap),
  tolerance: Float,
  merged: List(SegmentOverlap),
) -> Result(List(SegmentOverlap), Nil) {
  case overlaps {
    [] -> Ok(list.reverse(merged))
    [first, ..rest] -> {
      use merged <- result.try(insert_segment_overlap(first, merged, tolerance))
      merge_segment_overlap_list_loop(rest, tolerance, merged)
    }
  }
}

fn insert_segment_overlap(
  overlap: SegmentOverlap,
  overlaps: List(SegmentOverlap),
  tolerance: Float,
) -> Result(List(SegmentOverlap), Nil) {
  insert_segment_overlap_loop(overlap, overlaps, tolerance, [])
}

fn insert_segment_overlap_loop(
  overlap: SegmentOverlap,
  overlaps: List(SegmentOverlap),
  tolerance: Float,
  disjoint: List(SegmentOverlap),
) -> Result(List(SegmentOverlap), Nil) {
  case overlaps {
    [] -> Ok([overlap, ..disjoint])
    [first, ..rest] ->
      case merge_segment_overlaps(overlap, first, tolerance:) {
        Contradiction -> Error(Nil)
        Disjoint ->
          insert_segment_overlap_loop(overlap, rest, tolerance, [
            first,
            ..disjoint
          ])
        Merged(combined) ->
          insert_segment_overlap_loop(
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
pub fn segment_overlaps_by_endpoint_projection_with(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance tolerance: Float,
  samples samples: Int,
) -> Result(List(SegmentOverlap), svg_path.Error) {
  case tolerance <. 0.0 || samples <= 0 {
    True -> Ok([])
    False -> {
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
      case merge_segment_overlap_list(candidates, tolerance:) {
        Ok(merged) -> Ok(merged)
        Error(Nil) -> Ok([])
      }
    }
  }
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
  candidates: List(SegmentOverlap),
) -> Result(List(SegmentOverlap), svg_path.Error) {
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
  candidates: List(SegmentOverlap),
) -> Result(List(SegmentOverlap), svg_path.Error) {
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
          case
            segment_overlap_exceeds_minimum_span(
              overlap,
              minimum_span: tolerance,
            )
          {
            False -> Ok(Error(Nil))
            True -> {
              use valid <- result.try(sampled_overlap_valid(
                overlap,
                left,
                right,
                tolerance,
                samples,
              ))
              Ok(case valid {
                True -> Ok(overlap)
                False -> Error(Nil)
              })
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
) -> Result(Result(SegmentOverlap, Nil), svg_path.Error) {
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
      canonicalize_segment_overlap(SegmentOverlap(
        left_from:,
        left_to:,
        right_from:,
        right_to:,
        start:,
        end:,
      )),
    ),
  )
}

fn sampled_overlap_valid(
  overlap: SegmentOverlap,
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
  samples: Int,
) -> Result(Bool, svg_path.Error) {
  let SegmentOverlap(left_from:, left_to:, right_from:, right_to:, ..) = overlap
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

/// A finite encounter between two subpath traversals. Unlike the point-only
/// intersection API, overlap endpoints retain an address on both subpaths.
pub type SubpathEncounter {
  SubpathIntersection(
    point: svg_path.Point,
    left: svg_path.SubpathParameter,
    right: svg_path.SubpathParameter,
  )
  SubpathOverlap(
    start: svg_path.Point,
    end: svg_path.Point,
    left_from: svg_path.SubpathParameter,
    left_to: svg_path.SubpathParameter,
    right_from: svg_path.SubpathParameter,
    right_to: svg_path.SubpathParameter,
  )
}

pub fn segment(
  left: svg_path.Segment,
  right: svg_path.Segment,
) -> Result(List(SegmentEncounter), svg_path.Error) {
  segment_with(left, right, options: intersections.default_options())
}

pub fn segment_with(
  left: svg_path.Segment,
  right: svg_path.Segment,
  options options: intersections.IntersectionOptions,
) -> Result(List(SegmentEncounter), svg_path.Error) {
  case exact_coincident_segment(left, right) {
    Ok(encounter) -> Ok([encounter])
    Error(Nil) -> segment_encounters_from_intersections(left, right, options)
  }
}

fn segment_encounters_from_intersections(
  left: svg_path.Segment,
  right: svg_path.Segment,
  options: intersections.IntersectionOptions,
) -> Result(List(SegmentEncounter), svg_path.Error) {
  case intersections.segment_with(left, right, options:) {
    Ok(found) ->
      found
      |> list.map(fn(hit) {
        let svg_path.SegmentIntersection(left_t:, right_t:, point:) = hit
        Intersection(left_t:, right_t:, point:)
      })
      |> Ok
    Error(svg_path.OverlappingSegments) ->
      line_overlap(left, right, options.tolerance)
    Error(error) -> Error(error)
  }
}

fn exact_coincident_segment(
  left: svg_path.Segment,
  right: svg_path.Segment,
) -> Result(SegmentEncounter, Nil) {
  let start = svg_path.segment_start(left)
  let end = svg_path.segment_end(left)
  case left == right {
    True ->
      Ok(Overlap(
        left_from: 0.0,
        left_to: 1.0,
        right_from: 0.0,
        right_to: 1.0,
        start:,
        end:,
      ))
    False ->
      case left == svg_path.segment_reverse(right) {
        True ->
          Ok(Overlap(
            left_from: 0.0,
            left_to: 1.0,
            right_from: 1.0,
            right_to: 0.0,
            start:,
            end:,
          ))
        False -> Error(Nil)
      }
  }
}

pub fn subpath(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
) -> Result(List(SubpathEncounter), svg_path.Error) {
  subpath_with(left, right, options: intersections.default_options())
}

pub fn subpath_with(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
  options options: intersections.IntersectionOptions,
) -> Result(List(SubpathEncounter), svg_path.Error) {
  subpath_left_segments(
    svg_path.subpath_segments(left),
    svg_path.subpath_segments(right),
    options,
    left_index: 0,
    found: [],
  )
}

fn subpath_left_segments(
  left: List(svg_path.Segment),
  right: List(svg_path.Segment),
  options: intersections.IntersectionOptions,
  left_index left_index: Int,
  found found: List(SubpathEncounter),
) -> Result(List(SubpathEncounter), svg_path.Error) {
  case left {
    [] -> Ok(list.reverse(found))
    [first, ..rest] -> {
      use found <- result.try(subpath_right_segments(
        first,
        right,
        options,
        left_index:,
        right_index: 0,
        found:,
      ))
      subpath_left_segments(
        rest,
        right,
        options,
        left_index: left_index + 1,
        found:,
      )
    }
  }
}

fn subpath_right_segments(
  left: svg_path.Segment,
  right: List(svg_path.Segment),
  options: intersections.IntersectionOptions,
  left_index left_index: Int,
  right_index right_index: Int,
  found found: List(SubpathEncounter),
) -> Result(List(SubpathEncounter), svg_path.Error) {
  case right {
    [] -> Ok(found)
    [first, ..rest] -> {
      use encounters <- result.try(segment_with(left, first, options:))
      let found =
        list.fold(encounters, found, fn(found, encounter) {
          case encounter {
            Intersection(left_t:, right_t:, point:) -> [
              SubpathIntersection(
                point:,
                left: svg_path.SubpathParameter(
                  segment_index: left_index,
                  t: left_t,
                ),
                right: svg_path.SubpathParameter(
                  segment_index: right_index,
                  t: right_t,
                ),
              ),
              ..found
            ]
            Overlap(start:, end:, left_from:, left_to:, right_from:, right_to:) -> [
              SubpathOverlap(
                start:,
                end:,
                left_from: svg_path.SubpathParameter(
                  segment_index: left_index,
                  t: left_from,
                ),
                left_to: svg_path.SubpathParameter(
                  segment_index: left_index,
                  t: left_to,
                ),
                right_from: svg_path.SubpathParameter(
                  segment_index: right_index,
                  t: right_from,
                ),
                right_to: svg_path.SubpathParameter(
                  segment_index: right_index,
                  t: right_to,
                ),
              ),
              ..found
            ]
          }
        })
      subpath_right_segments(
        left,
        rest,
        options,
        left_index:,
        right_index: right_index + 1,
        found:,
      )
    }
  }
}

fn line_overlap(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
) -> Result(List(SegmentEncounter), svg_path.Error) {
  case left, right {
    svg_path.Line(start: left_start, end: left_end),
      svg_path.Line(start: right_start, end: right_end)
    -> {
      let left_dx = left_end.x -. left_start.x
      let left_dy = left_end.y -. left_start.y
      let right_dx = right_end.x -. right_start.x
      let right_dy = right_end.y -. right_start.y
      case
        near_zero(left_dx *. left_dx +. left_dy *. left_dy, tolerance)
        || near_zero(right_dx *. right_dx +. right_dy *. right_dy, tolerance)
      {
        True -> Ok([])
        False -> {
          let right_start_t =
            line_parameter(left_start, left_dx, left_dy, right_start)
          let right_end_t =
            line_parameter(left_start, left_dx, left_dy, right_end)
          let left_from = max_float(0.0, min_float(right_start_t, right_end_t))
          let left_to = min_float(1.0, max_float(right_start_t, right_end_t))
          case left_to -. left_from <=. tolerance {
            True -> Ok([])
            False -> {
              let assert Ok(start) = svg_path.segment_point(left, at: left_from)
              let assert Ok(end) = svg_path.segment_point(left, at: left_to)
              Ok([
                Overlap(
                  left_from:,
                  left_to:,
                  right_from: line_parameter(
                    right_start,
                    right_dx,
                    right_dy,
                    start,
                  ),
                  right_to: line_parameter(right_start, right_dx, right_dy, end),
                  start:,
                  end:,
                ),
              ])
            }
          }
        }
      }
    }
    _, _ -> Ok([])
  }
}

fn line_parameter(
  start: svg_path.Point,
  dx: Float,
  dy: Float,
  point: svg_path.Point,
) -> Float {
  case float.absolute_value(dx) >=. float.absolute_value(dy) {
    True -> { point.x -. start.x } /. dx
    False -> { point.y -. start.y } /. dy
  }
}

fn near_zero(value: Float, tolerance: Float) -> Bool {
  float.absolute_value(value) <=. tolerance *. tolerance
}

fn min_float(a: Float, b: Float) -> Float {
  case a <=. b {
    True -> a
    False -> b
  }
}

fn max_float(a: Float, b: Float) -> Float {
  case a >=. b {
    True -> a
    False -> b
  }
}
