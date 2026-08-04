//// Continuous coincident intervals between path segments.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import svg_path
import svg_path/overlap_detection
import svg_path/point

const default_overlap_tolerance = 0.000000001

/// One non-zero-length overlap interval between the same ordered pair of
/// segments. The left parameters and points follow the left segment's
/// traversal. The right parameters retain the corresponding traversal
/// direction and may therefore decrease.
///
/// The four endpoint parameters define an affine correspondence throughout
/// the overlap. For any parameter between `left_from` and `left_to`, linearly
/// interpolating between `right_from` and `right_to` identifies the same
/// geometric point on the right segment, within the overlap tolerance.
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

/// Map a left-segment parameter through an overlap's affine correspondence.
///
/// For overlap values returned by this module, parameters in the closed
/// `left_from..left_to` interval map to coincident points on the right segment.
pub fn segment_overlap_right_parameter(
  overlap: SegmentOverlap,
  left_parameter: Float,
) -> Float {
  let SegmentOverlap(left_from:, left_to:, right_from:, right_to:, ..) = overlap
  let portion = { left_parameter -. left_from } /. { left_to -. left_from }
  right_from +. { right_to -. right_from } *. portion
}

/// Map a right-segment parameter through an overlap's inverse affine
/// correspondence.
///
/// For overlap values returned by this module, parameters between
/// `right_from` and `right_to` map to coincident points on the left segment.
pub fn segment_overlap_left_parameter(
  overlap: SegmentOverlap,
  right_parameter: Float,
) -> Float {
  let SegmentOverlap(left_from:, left_to:, right_from:, right_to:, ..) = overlap
  let portion = { right_parameter -. right_from } /. { right_to -. right_from }
  left_from +. { left_to -. left_from } *. portion
}

/// The result of combining two overlap intervals for the same ordered segment
/// pair.
pub type SegmentOverlapMerge {
  Disjoint
  Merged(SegmentOverlap)
  Contradiction
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
/// This algorithm assumes non-degenerate segments and that every overlap
/// boundary is an endpoint of at least one input segment.
pub fn segment_overlaps_by_endpoint_projection_with(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance tolerance: Float,
  samples samples: Int,
) -> Result(List(SegmentOverlap), svg_path.Error) {
  use detected <- result.try(overlap_detection.detect_with(
    left,
    right,
    tolerance:,
    samples:,
  ))
  Ok(list.map(detected, raw_overlap))
}

/// Find overlap intervals using the shared five-sample policy.
///
/// Coincident portions whose parameter correspondence is not affine return
/// `svg_path.NonAffineOverlapCorrespondence`. Normalize or linearize
/// degenerate and multiply traced segments before retrying those cases.
pub fn segment(
  left: svg_path.Segment,
  right: svg_path.Segment,
) -> Result(List(SegmentOverlap), svg_path.Error) {
  segment_with(left, right, tolerance: default_overlap_tolerance)
}

pub fn segment_with(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance tolerance: Float,
) -> Result(List(SegmentOverlap), svg_path.Error) {
  use detected <- result.try(overlap_detection.detect(left, right, tolerance:))
  Ok(list.map(detected, raw_overlap))
}

fn raw_overlap(raw: overlap_detection.RawOverlap) -> SegmentOverlap {
  let #(left_from, left_to, right_from, right_to, start, end) = raw
  SegmentOverlap(left_from:, left_to:, right_from:, right_to:, start:, end:)
}

/// One overlap between a standalone segment and a constituent segment of a
/// subpath. Each constituent segment-pair overlap is returned separately.
pub type SegmentSubpathOverlap {
  SegmentSubpathOverlap(
    start: svg_path.Point,
    end: svg_path.Point,
    segment_from: Float,
    segment_to: Float,
    subpath_from: svg_path.SubpathParameter,
    subpath_to: svg_path.SubpathParameter,
  )
}

/// Return overlaps between a standalone segment and a subpath.
pub fn segment_subpath(
  segment: svg_path.Segment,
  subpath: svg_path.Subpath,
) -> Result(List(SegmentSubpathOverlap), svg_path.Error) {
  segment_subpath_with(segment, subpath, tolerance: default_overlap_tolerance)
}

/// Return segment-subpath overlaps using an explicit geometric tolerance.
///
/// Overlaps are ordered by constituent subpath segment. Adjacent overlaps are
/// not merged across segment boundaries.
pub fn segment_subpath_with(
  segment: svg_path.Segment,
  subpath: svg_path.Subpath,
  tolerance tolerance: Float,
) -> Result(List(SegmentSubpathOverlap), svg_path.Error) {
  segment_subpath_segments(
    segment,
    svg_path.subpath_segments(subpath),
    tolerance,
    segment_index: 0,
    found: [],
  )
}

fn segment_subpath_segments(
  segment: svg_path.Segment,
  subpath_segments: List(svg_path.Segment),
  tolerance: Float,
  segment_index segment_index: Int,
  found found: List(SegmentSubpathOverlap),
) -> Result(List(SegmentSubpathOverlap), svg_path.Error) {
  case subpath_segments {
    [] -> Ok(list.reverse(found))
    [first, ..rest] -> {
      use segment_overlaps <- result.try(segment_with(
        segment,
        first,
        tolerance:,
      ))
      let found =
        list.fold(segment_overlaps, found, fn(found, overlap) {
          let SegmentOverlap(
            start:,
            end:,
            left_from: segment_from,
            left_to: segment_to,
            right_from: subpath_from,
            right_to: subpath_to,
          ) = overlap
          [
            SegmentSubpathOverlap(
              start:,
              end:,
              segment_from:,
              segment_to:,
              subpath_from: svg_path.SubpathParameter(
                segment_index:,
                t: subpath_from,
              ),
              subpath_to: svg_path.SubpathParameter(
                segment_index:,
                t: subpath_to,
              ),
            ),
            ..found
          ]
        })
      segment_subpath_segments(
        segment,
        rest,
        tolerance,
        segment_index: segment_index + 1,
        found:,
      )
    }
  }
}

/// One affine piece of a continuous overlap between two subpath traversals.
pub type SubpathOverlapPiece {
  SubpathOverlapPiece(
    left_segment_index: Int,
    right_segment_index: Int,
    correspondence: SegmentOverlap,
  )
}

/// One continuous overlap between two subpath traversals.
///
/// `pieces` is non-empty for values returned by this module. It follows the
/// left subpath's traversal and supplies the complete piecewise-affine
/// parameter correspondence to the right subpath.
pub type SubpathOverlap {
  SubpathOverlap(
    start: svg_path.Point,
    end: svg_path.Point,
    pieces: List(SubpathOverlapPiece),
  )
}

/// First parameter of a subpath overlap on the left traversal.
pub fn subpath_overlap_left_start(
  overlap: SubpathOverlap,
) -> Option(svg_path.SubpathParameter) {
  let SubpathOverlap(pieces:, ..) = overlap
  case pieces {
    [SubpathOverlapPiece(left_segment_index:, correspondence:, ..), ..] -> {
      let SegmentOverlap(left_from:, ..) = correspondence
      Some(svg_path.SubpathParameter(left_segment_index, left_from))
    }
    [] -> None
  }
}

/// Last parameter of a subpath overlap on the left traversal.
pub fn subpath_overlap_left_end(
  overlap: SubpathOverlap,
) -> Option(svg_path.SubpathParameter) {
  let SubpathOverlap(pieces:, ..) = overlap
  case list.last(pieces) {
    Ok(SubpathOverlapPiece(left_segment_index:, correspondence:, ..)) -> {
      let SegmentOverlap(left_to:, ..) = correspondence
      Some(svg_path.SubpathParameter(left_segment_index, left_to))
    }
    Error(Nil) -> None
  }
}

/// First corresponding parameter on the right traversal.
pub fn subpath_overlap_right_start(
  overlap: SubpathOverlap,
) -> Option(svg_path.SubpathParameter) {
  let SubpathOverlap(pieces:, ..) = overlap
  case pieces {
    [SubpathOverlapPiece(right_segment_index:, correspondence:, ..), ..] -> {
      let SegmentOverlap(right_from:, ..) = correspondence
      Some(svg_path.SubpathParameter(right_segment_index, right_from))
    }
    [] -> None
  }
}

/// Last corresponding parameter on the right traversal.
pub fn subpath_overlap_right_end(
  overlap: SubpathOverlap,
) -> Option(svg_path.SubpathParameter) {
  let SubpathOverlap(pieces:, ..) = overlap
  case list.last(pieces) {
    Ok(SubpathOverlapPiece(right_segment_index:, correspondence:, ..)) -> {
      let SegmentOverlap(right_to:, ..) = correspondence
      Some(svg_path.SubpathParameter(right_segment_index, right_to))
    }
    Error(Nil) -> None
  }
}

/// Map a left-subpath address through an overlap's exact correspondence.
///
/// The left subpath is used to recognize exact equivalent input addresses. The
/// returned address is exactly canonicalized against the right subpath. This
/// function does not snap parameters or otherwise move them geometrically.
pub fn subpath_overlap_right_parameter(
  overlap: SubpathOverlap,
  left_parameter: svg_path.SubpathParameter,
  left_subpath left_subpath: svg_path.Subpath,
  right_subpath right_subpath: svg_path.Subpath,
) -> Result(Option(svg_path.SubpathParameter), svg_path.Error) {
  let SubpathOverlap(pieces:, ..) = overlap
  let opposite =
    subpath_overlap_opposite_parameter(
      pieces,
      left_parameter,
      left_subpath,
      source_is_left: True,
    )
  canonicalize_optional_subpath_parameter(opposite, right_subpath)
}

/// Map a right-subpath address through an overlap's exact correspondence.
///
/// The right subpath is used to recognize exact equivalent input addresses.
/// The returned address is exactly canonicalized against the left subpath.
/// This function does not snap parameters or otherwise move them geometrically.
pub fn subpath_overlap_left_parameter(
  overlap: SubpathOverlap,
  right_parameter: svg_path.SubpathParameter,
  left_subpath left_subpath: svg_path.Subpath,
  right_subpath right_subpath: svg_path.Subpath,
) -> Result(Option(svg_path.SubpathParameter), svg_path.Error) {
  let SubpathOverlap(pieces:, ..) = overlap
  let opposite =
    subpath_overlap_opposite_parameter(
      pieces,
      right_parameter,
      right_subpath,
      source_is_left: False,
    )
  canonicalize_optional_subpath_parameter(opposite, left_subpath)
}

fn canonicalize_optional_subpath_parameter(
  parameter: Option(svg_path.SubpathParameter),
  subpath: svg_path.Subpath,
) -> Result(Option(svg_path.SubpathParameter), svg_path.Error) {
  case parameter {
    None -> Ok(None)
    Some(parameter) ->
      svg_path.subpath_parameter_canonicalize(subpath, parameter:)
      |> result.map(Some)
  }
}

fn subpath_overlap_opposite_parameter(
  pieces: List(SubpathOverlapPiece),
  parameter: svg_path.SubpathParameter,
  source_subpath: svg_path.Subpath,
  source_is_left source_is_left: Bool,
) -> Option(svg_path.SubpathParameter) {
  case pieces {
    [] -> None
    [piece, ..rest] ->
      case
        subpath_overlap_piece_opposite_parameter(
          piece,
          parameter,
          source_subpath,
          source_is_left,
        )
      {
        Some(opposite) -> Some(opposite)
        None ->
          subpath_overlap_opposite_parameter(
            rest,
            parameter,
            source_subpath,
            source_is_left,
          )
      }
  }
}

fn subpath_overlap_piece_opposite_parameter(
  piece: SubpathOverlapPiece,
  parameter: svg_path.SubpathParameter,
  source_subpath: svg_path.Subpath,
  source_is_left: Bool,
) -> Option(svg_path.SubpathParameter) {
  let SubpathOverlapPiece(
    left_segment_index:,
    right_segment_index:,
    correspondence: overlap,
  ) = piece
  let SegmentOverlap(left_from:, left_to:, right_from:, right_to:, ..) = overlap
  let #(source_index, source_from, source_to, opposite_index) = case
    source_is_left
  {
    True -> #(left_segment_index, left_from, left_to, right_segment_index)
    False -> #(right_segment_index, right_from, right_to, left_segment_index)
  }
  let source_parameter =
    parameter_inside_piece(
      parameter,
      source_index,
      source_from,
      source_to,
      source_subpath,
    )
  case source_parameter {
    None -> None
    Some(source_t) -> {
      let opposite_t = case source_is_left {
        True -> segment_overlap_right_parameter(overlap, source_t)
        False -> segment_overlap_left_parameter(overlap, source_t)
      }
      Some(svg_path.SubpathParameter(opposite_index, opposite_t))
    }
  }
}

fn parameter_inside_piece(
  parameter: svg_path.SubpathParameter,
  piece_segment_index: Int,
  piece_from: Float,
  piece_to: Float,
  source_subpath: svg_path.Subpath,
) -> Option(Float) {
  let svg_path.SubpathParameter(segment_index:, t:) = parameter
  case
    segment_index == piece_segment_index,
    float_between_inclusive(t, piece_from, piece_to)
  {
    True, True -> Some(t)
    _, _ -> {
      let from = svg_path.SubpathParameter(piece_segment_index, piece_from)
      let to = svg_path.SubpathParameter(piece_segment_index, piece_to)
      case
        subpath_parameters_are_exact_endpoint_aliases(
          parameter,
          from,
          source_subpath,
        ),
        subpath_parameters_are_exact_endpoint_aliases(
          parameter,
          to,
          source_subpath,
        )
      {
        True, _ -> Some(piece_from)
        False, True -> Some(piece_to)
        False, False -> None
      }
    }
  }
}

fn subpath_parameters_are_exact_endpoint_aliases(
  first: svg_path.SubpathParameter,
  second: svg_path.SubpathParameter,
  subpath: svg_path.Subpath,
) -> Bool {
  let svg_path.SubpathParameter(segment_index: first_index, t: first_t) = first
  let svg_path.SubpathParameter(segment_index: second_index, t: second_t) =
    second
  let segment_count = list.length(svg_path.subpath_segments(subpath))
  first == second
  || {
    first_t == 1.0
    && second_t == 0.0
    && {
      second_index == first_index + 1
      || {
        svg_path.subpath_is_closed(subpath)
        && first_index == segment_count - 1
        && second_index == 0
      }
    }
  }
  || {
    second_t == 1.0
    && first_t == 0.0
    && {
      first_index == second_index + 1
      || {
        svg_path.subpath_is_closed(subpath)
        && second_index == segment_count - 1
        && first_index == 0
      }
    }
  }
}

fn float_between_inclusive(value: Float, first: Float, second: Float) -> Bool {
  value >=. float.min(first, second) && value <=. float.max(first, second)
}

pub fn subpath(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
) -> Result(List(SubpathOverlap), svg_path.Error) {
  subpath_with(left, right, tolerance: default_overlap_tolerance)
}

pub fn subpath_with(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
  tolerance tolerance: Float,
) -> Result(List(SubpathOverlap), svg_path.Error) {
  use pieces <- result.try(
    subpath_left_segments(
      svg_path.subpath_segments(left),
      svg_path.subpath_segments(right),
      tolerance,
      left_index: 0,
      found: [],
    ),
  )
  Ok(merge_subpath_overlap_pieces(pieces, tolerance))
}

fn subpath_left_segments(
  left: List(svg_path.Segment),
  right: List(svg_path.Segment),
  tolerance: Float,
  left_index left_index: Int,
  found found: List(SubpathOverlapPiece),
) -> Result(List(SubpathOverlapPiece), svg_path.Error) {
  case left {
    [] -> Ok(list.reverse(found))
    [first, ..rest] -> {
      use found <- result.try(subpath_right_segments(
        first,
        right,
        tolerance,
        left_index:,
        right_index: 0,
        found:,
      ))
      subpath_left_segments(
        rest,
        right,
        tolerance,
        left_index: left_index + 1,
        found:,
      )
    }
  }
}

fn subpath_right_segments(
  left: svg_path.Segment,
  right: List(svg_path.Segment),
  tolerance: Float,
  left_index left_index: Int,
  right_index right_index: Int,
  found found: List(SubpathOverlapPiece),
) -> Result(List(SubpathOverlapPiece), svg_path.Error) {
  case right {
    [] -> Ok(found)
    [first, ..rest] -> {
      use segment_overlaps <- result.try(segment_with(left, first, tolerance:))
      let found =
        list.fold(segment_overlaps, found, fn(found, overlap) {
          [
            SubpathOverlapPiece(
              left_segment_index: left_index,
              right_segment_index: right_index,
              correspondence: overlap,
            ),
            ..found
          ]
        })
      subpath_right_segments(
        left,
        rest,
        tolerance,
        left_index:,
        right_index: right_index + 1,
        found:,
      )
    }
  }
}

fn merge_subpath_overlap_pieces(
  pieces: List(SubpathOverlapPiece),
  tolerance: Float,
) -> List(SubpathOverlap) {
  pieces
  |> list.sort(by: compare_subpath_overlap_pieces)
  |> merge_subpath_overlap_pieces_loop(tolerance, current: [], merged: [])
}

fn compare_subpath_overlap_pieces(
  first: SubpathOverlapPiece,
  second: SubpathOverlapPiece,
) -> order.Order {
  let SubpathOverlapPiece(
    left_segment_index: first_index,
    correspondence: SegmentOverlap(left_from: first_from, ..),
    ..,
  ) = first
  let SubpathOverlapPiece(
    left_segment_index: second_index,
    correspondence: SegmentOverlap(left_from: second_from, ..),
    ..,
  ) = second
  case int.compare(first_index, second_index) {
    order.Eq -> float.compare(first_from, second_from)
    other -> other
  }
}

fn merge_subpath_overlap_pieces_loop(
  pieces: List(SubpathOverlapPiece),
  tolerance: Float,
  current current: List(SubpathOverlapPiece),
  merged merged: List(SubpathOverlap),
) -> List(SubpathOverlap) {
  case pieces, current {
    [], [] -> list.reverse(merged)
    [], _ ->
      list.reverse([subpath_overlap_from_reversed_pieces(current), ..merged])
    [piece, ..rest], [] ->
      merge_subpath_overlap_pieces_loop(
        rest,
        tolerance,
        current: [piece],
        merged:,
      )
    [piece, ..rest], [previous, ..] ->
      case subpath_overlap_pieces_connect(previous, piece, tolerance) {
        True ->
          merge_subpath_overlap_pieces_loop(
            rest,
            tolerance,
            current: [piece, ..current],
            merged:,
          )
        False ->
          merge_subpath_overlap_pieces_loop(
            rest,
            tolerance,
            current: [piece],
            merged: [subpath_overlap_from_reversed_pieces(current), ..merged],
          )
      }
  }
}

fn subpath_overlap_pieces_connect(
  left: SubpathOverlapPiece,
  right: SubpathOverlapPiece,
  tolerance: Float,
) -> Bool {
  let SubpathOverlapPiece(
    left_segment_index: left_left_index,
    right_segment_index: left_right_index,
    correspondence: left_overlap,
  ) = left
  let SubpathOverlapPiece(
    left_segment_index: right_left_index,
    right_segment_index: right_right_index,
    correspondence: right_overlap,
  ) = right
  let SegmentOverlap(
    end: left_end,
    left_to: left_left_to,
    right_to: left_right_to,
    ..,
  ) = left_overlap
  let SegmentOverlap(
    start: right_start,
    left_from: right_left_from,
    right_from: right_right_from,
    ..,
  ) = right_overlap
  point.distance(left_end, right_start) <=. tolerance
  && forward_subpath_parameters_connect(
    left_left_index,
    left_left_to,
    right_left_index,
    right_left_from,
  )
  && subpath_parameters_connect_either_direction(
    left_right_index,
    left_right_to,
    right_right_index,
    right_right_from,
  )
}

fn forward_subpath_parameters_connect(
  first_index: Int,
  first_t: Float,
  second_index: Int,
  second_t: Float,
) -> Bool {
  case first_index == second_index {
    True -> near_parameter(first_t, second_t)
    False ->
      second_index == first_index + 1
      && near_parameter(first_t, 1.0)
      && near_parameter(second_t, 0.0)
  }
}

fn subpath_parameters_connect_either_direction(
  first_index: Int,
  first_t: Float,
  second_index: Int,
  second_t: Float,
) -> Bool {
  forward_subpath_parameters_connect(
    first_index,
    first_t,
    second_index,
    second_t,
  )
  || forward_subpath_parameters_connect(
    second_index,
    second_t,
    first_index,
    first_t,
  )
}

fn near_parameter(first: Float, second: Float) -> Bool {
  float.absolute_value(first -. second) <=. default_overlap_tolerance
}

fn subpath_overlap_from_reversed_pieces(
  reversed_pieces: List(SubpathOverlapPiece),
) -> SubpathOverlap {
  let pieces = list.reverse(reversed_pieces)
  let assert [first, ..] = pieces
  let assert Ok(last) = list.last(pieces)
  let SubpathOverlapPiece(correspondence: SegmentOverlap(start:, ..), ..) =
    first
  let SubpathOverlapPiece(correspondence: SegmentOverlap(end:, ..), ..) = last
  SubpathOverlap(start:, end:, pieces:)
}

/// One overlap between constituent segments of two paths. Each constituent
/// segment-pair overlap is returned separately.
pub type PathOverlap {
  PathOverlap(
    start: svg_path.Point,
    end: svg_path.Point,
    left_from: svg_path.PathParameter,
    left_to: svg_path.PathParameter,
    right_from: svg_path.PathParameter,
    right_to: svg_path.PathParameter,
  )
}

/// Return overlaps between two paths.
pub fn path(
  left: svg_path.Path,
  right: svg_path.Path,
) -> Result(List(PathOverlap), svg_path.Error) {
  path_with(left, right, tolerance: default_overlap_tolerance)
}

/// Return path overlaps using an explicit geometric tolerance.
///
/// Results retain both subpath and segment addresses. Adjacent overlaps are
/// not merged across constituent segment or subpath boundaries.
pub fn path_with(
  left: svg_path.Path,
  right: svg_path.Path,
  tolerance tolerance: Float,
) -> Result(List(PathOverlap), svg_path.Error) {
  path_left_subpaths(
    left.subpaths,
    right.subpaths,
    tolerance,
    left_subpath_index: 0,
    found: [],
  )
}

fn path_left_subpaths(
  left: List(svg_path.Subpath),
  right: List(svg_path.Subpath),
  tolerance: Float,
  left_subpath_index left_subpath_index: Int,
  found found: List(PathOverlap),
) -> Result(List(PathOverlap), svg_path.Error) {
  case left {
    [] -> Ok(list.reverse(found))
    [first, ..rest] -> {
      use found <- result.try(path_right_subpaths(
        first,
        left_subpath_index,
        right,
        tolerance,
        right_subpath_index: 0,
        found:,
      ))
      path_left_subpaths(
        rest,
        right,
        tolerance,
        left_subpath_index: left_subpath_index + 1,
        found:,
      )
    }
  }
}

fn path_right_subpaths(
  left: svg_path.Subpath,
  left_subpath_index: Int,
  right: List(svg_path.Subpath),
  tolerance: Float,
  right_subpath_index right_subpath_index: Int,
  found found: List(PathOverlap),
) -> Result(List(PathOverlap), svg_path.Error) {
  case right {
    [] -> Ok(found)
    [first, ..rest] -> {
      use subpath_overlaps <- result.try(subpath_with(left, first, tolerance:))
      let found =
        list.fold(subpath_overlaps, found, fn(found, overlap) {
          let SubpathOverlap(start:, end:, ..) = overlap
          let assert Some(left_from) = subpath_overlap_left_start(overlap)
          let assert Some(left_to) = subpath_overlap_left_end(overlap)
          let assert Some(right_from) = subpath_overlap_right_start(overlap)
          let assert Some(right_to) = subpath_overlap_right_end(overlap)
          [
            PathOverlap(
              start:,
              end:,
              left_from: svg_path.PathParameter(
                subpath_index: left_subpath_index,
                at: left_from,
              ),
              left_to: svg_path.PathParameter(
                subpath_index: left_subpath_index,
                at: left_to,
              ),
              right_from: svg_path.PathParameter(
                subpath_index: right_subpath_index,
                at: right_from,
              ),
              right_to: svg_path.PathParameter(
                subpath_index: right_subpath_index,
                at: right_to,
              ),
            ),
            ..found
          ]
        })
      path_right_subpaths(
        left,
        left_subpath_index,
        rest,
        tolerance,
        right_subpath_index: right_subpath_index + 1,
        found:,
      )
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
