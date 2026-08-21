//// Continuous coincident intervals between path traversals.
////
//// Every returned overlap is represented as one or more `SegmentOverlap`
//// correspondences. Within each piece, the left and right segment parameters
//// have one affine, monotone relationship. Multiply traced or non-monotone
//// coincident geometry that cannot satisfy this contract returns
//// `svg_path.NonAffineOverlapCorrespondence`; normalize or linearize those
//// segments before overlap detection.
////
//// A supplied `tolerance` is finite and non-negative. It is used as a
//// Euclidean distance in path coordinates when testing coincidence and,
//// during interval merging, as a normalized segment-parameter tolerance.
//// Invalid tolerances return `svg_path.InvalidOverlapTolerance`.
////
//// Opposite-parameter lookup is exact with respect to a returned overlap. It
//// accepts exact segment-end aliases and canonicalizes the returned address,
//// but it does not snap nearby parameters or move them geometrically. The
//// tolerance-based arc-length clamping used by encounter filtering belongs to
//// `svg_path/encounters`, not this module.

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

/// Find sampled overlap intervals proposed by endpoint projections.
///
/// This algorithm assumes non-degenerate segments and that every overlap
/// boundary is an endpoint of at least one input segment. `tolerance` follows
/// this module's mixed geometric/normalized-parameter convention. `samples`
/// must be positive.
@internal
pub fn segment_with_samples(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance tolerance: Float,
  samples samples: Int,
) -> Result(List(SegmentOverlap), svg_path.Error) {
  use detected <- result.try(overlap_detection.detect_with_samples(
    left,
    right,
    tolerance:,
    samples:,
  ))
  Ok(list.map(detected, raw_overlap))
}

/// Check one proposed endpoint-parameter correspondence.
///
/// `Ok(Some(_))` means the proposed parameter interval is a positive-span
/// affine overlap. `Ok(None)` means the proposed interval is not coincident
/// under the supplied tolerance.
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
) -> Result(Option(SegmentOverlap), svg_path.Error) {
  use detected <- result.try(overlap_detection.check_parameter_correspondence(
    left,
    right,
    left_from:,
    left_to:,
    right_from:,
    right_to:,
    tolerance:,
    samples:,
  ))
  Ok(option.map(detected, raw_overlap))
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

/// Find segment overlaps using an explicit finite, non-negative tolerance.
///
/// The tolerance is measured in path-coordinate distance for coincidence
/// tests and in normalized segment parameters while merging candidates.
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

/// One affine piece of a continuous overlap between a standalone segment and
/// a subpath traversal.
pub type SegmentSubpathOverlapPiece {
  SegmentSubpathOverlapPiece(
    subpath_segment_index: Int,
    correspondence: SegmentOverlap,
  )
}

/// One continuous overlap between a standalone segment and a subpath.
///
/// `pieces` follows the standalone segment's traversal and preserves the full
/// piecewise-affine parameter correspondence to the subpath.
pub type SegmentSubpathOverlap {
  SegmentSubpathOverlap(
    start: svg_path.Point,
    end: svg_path.Point,
    pieces: List(SegmentSubpathOverlapPiece),
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
/// Overlaps follow the standalone segment's traversal. Adjacent constituent
/// segment overlaps are joined when their parameter correspondences connect.
/// `tolerance` has the module-wide geometric and normalized-parameter meaning.
pub fn segment_subpath_with(
  segment: svg_path.Segment,
  subpath: svg_path.Subpath,
  tolerance tolerance: Float,
) -> Result(List(SegmentSubpathOverlap), svg_path.Error) {
  use segment_subpath <- result.try(svg_path.subpath([segment]))
  use found <- result.try(subpath_with(segment_subpath, subpath, tolerance:))
  Ok(list.map(found, segment_subpath_overlap_from_subpath_overlap))
}

fn segment_subpath_overlap_from_subpath_overlap(
  overlap: SubpathOverlap,
) -> SegmentSubpathOverlap {
  let SubpathOverlap(start:, end:, pieces:) = overlap
  let pieces =
    list.map(pieces, fn(piece) {
      let SubpathOverlapPiece(
        left_segment_index:,
        right_segment_index: subpath_segment_index,
        correspondence:,
      ) = piece
      let assert 0 = left_segment_index
      SegmentSubpathOverlapPiece(subpath_segment_index:, correspondence:)
    })
  SegmentSubpathOverlap(start:, end:, pieces:)
}

/// First parameter of a segment-subpath overlap on the standalone segment.
pub fn segment_subpath_overlap_segment_start(
  overlap: SegmentSubpathOverlap,
) -> Option(Float) {
  let SegmentSubpathOverlap(pieces:, ..) = overlap
  case pieces {
    [
      SegmentSubpathOverlapPiece(
        correspondence: SegmentOverlap(left_from:, ..),
        ..,
      ),
      ..
    ] -> Some(left_from)
    [] -> None
  }
}

/// Last parameter of a segment-subpath overlap on the standalone segment.
pub fn segment_subpath_overlap_segment_end(
  overlap: SegmentSubpathOverlap,
) -> Option(Float) {
  let SegmentSubpathOverlap(pieces:, ..) = overlap
  case list.last(pieces) {
    Ok(SegmentSubpathOverlapPiece(
      correspondence: SegmentOverlap(left_to:, ..),
      ..,
    )) -> Some(left_to)
    Error(_) -> None
  }
}

/// First parameter of a segment-subpath overlap on the subpath traversal.
pub fn segment_subpath_overlap_subpath_start(
  overlap: SegmentSubpathOverlap,
) -> Option(svg_path.SubpathParameter) {
  let SegmentSubpathOverlap(pieces:, ..) = overlap
  case pieces {
    [
      SegmentSubpathOverlapPiece(
        subpath_segment_index:,
        correspondence: SegmentOverlap(right_from:, ..),
      ),
      ..
    ] -> Some(svg_path.SubpathParameter(subpath_segment_index, right_from))
    [] -> None
  }
}

/// Last parameter of a segment-subpath overlap on the subpath traversal.
pub fn segment_subpath_overlap_subpath_end(
  overlap: SegmentSubpathOverlap,
) -> Option(svg_path.SubpathParameter) {
  let SegmentSubpathOverlap(pieces:, ..) = overlap
  case list.last(pieces) {
    Ok(SegmentSubpathOverlapPiece(
      subpath_segment_index:,
      correspondence: SegmentOverlap(right_to:, ..),
    )) -> Some(svg_path.SubpathParameter(subpath_segment_index, right_to))
    Error(_) -> None
  }
}

/// Map a standalone-segment parameter to its exact opposite subpath address.
pub fn segment_subpath_overlap_subpath_parameter(
  overlap: SegmentSubpathOverlap,
  segment_parameter: Float,
  segment: svg_path.Segment,
  subpath: svg_path.Subpath,
) -> Result(Option(svg_path.SubpathParameter), svg_path.Error) {
  use segment_subpath <- result.try(svg_path.subpath([segment]))
  subpath_overlap_right_parameter(
    segment_subpath_overlap_as_subpath_overlap(overlap),
    svg_path.SubpathParameter(segment_index: 0, t: segment_parameter),
    left_subpath: segment_subpath,
    right_subpath: subpath,
  )
}

/// Map a subpath address to its exact opposite standalone-segment parameter.
pub fn segment_subpath_overlap_segment_parameter(
  overlap: SegmentSubpathOverlap,
  subpath_parameter: svg_path.SubpathParameter,
  segment: svg_path.Segment,
  subpath: svg_path.Subpath,
) -> Result(Option(Float), svg_path.Error) {
  use segment_subpath <- result.try(svg_path.subpath([segment]))
  use parameter <- result.try(subpath_overlap_left_parameter(
    segment_subpath_overlap_as_subpath_overlap(overlap),
    subpath_parameter,
    left_subpath: segment_subpath,
    right_subpath: subpath,
  ))
  Ok(option.map(parameter, fn(parameter) { parameter.t }))
}

fn segment_subpath_overlap_as_subpath_overlap(
  overlap: SegmentSubpathOverlap,
) -> SubpathOverlap {
  let SegmentSubpathOverlap(start:, end:, pieces:) = overlap
  SubpathOverlap(
    start:,
    end:,
    pieces: list.map(pieces, fn(piece) {
      let SegmentSubpathOverlapPiece(subpath_segment_index:, correspondence:) =
        piece
      SubpathOverlapPiece(
        left_segment_index: 0,
        right_segment_index: subpath_segment_index,
        correspondence:,
      )
    }),
  )
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

/// Return continuous overlaps between two subpath traversals.
///
/// Each result follows the left traversal and contains its complete
/// piecewise-affine correspondence to the right traversal.
pub fn subpath(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
) -> Result(List(SubpathOverlap), svg_path.Error) {
  subpath_with(left, right, tolerance: default_overlap_tolerance)
}

/// Return subpath overlaps using an explicit finite, non-negative tolerance.
///
/// The tolerance has the module-wide geometric and normalized-parameter
/// meaning. Continuous pieces may cross segment boundaries but never join
/// across a discontinuity in either traversal.
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

/// One continuous overlap between a specific ordered pair of path subpaths.
///
/// `correspondence` preserves the complete piecewise-affine parameter map.
pub type PathOverlap {
  PathOverlap(
    left_subpath_index: Int,
    right_subpath_index: Int,
    correspondence: SubpathOverlap,
  )
}

/// First parameter of a path overlap on the left path traversal.
pub fn path_overlap_left_start(
  overlap: PathOverlap,
) -> Option(svg_path.PathParameter) {
  let PathOverlap(left_subpath_index:, correspondence:, ..) = overlap
  option.map(subpath_overlap_left_start(correspondence), fn(at) {
    svg_path.PathParameter(subpath_index: left_subpath_index, at:)
  })
}

/// Last parameter of a path overlap on the left path traversal.
pub fn path_overlap_left_end(
  overlap: PathOverlap,
) -> Option(svg_path.PathParameter) {
  let PathOverlap(left_subpath_index:, correspondence:, ..) = overlap
  option.map(subpath_overlap_left_end(correspondence), fn(at) {
    svg_path.PathParameter(subpath_index: left_subpath_index, at:)
  })
}

/// First parameter of a path overlap on the right path traversal.
pub fn path_overlap_right_start(
  overlap: PathOverlap,
) -> Option(svg_path.PathParameter) {
  let PathOverlap(right_subpath_index:, correspondence:, ..) = overlap
  option.map(subpath_overlap_right_start(correspondence), fn(at) {
    svg_path.PathParameter(subpath_index: right_subpath_index, at:)
  })
}

/// Last parameter of a path overlap on the right path traversal.
pub fn path_overlap_right_end(
  overlap: PathOverlap,
) -> Option(svg_path.PathParameter) {
  let PathOverlap(right_subpath_index:, correspondence:, ..) = overlap
  option.map(subpath_overlap_right_end(correspondence), fn(at) {
    svg_path.PathParameter(subpath_index: right_subpath_index, at:)
  })
}

/// Map a left-path address to its exact opposite right-path address.
pub fn path_overlap_right_parameter(
  overlap: PathOverlap,
  left_parameter: svg_path.PathParameter,
  left_path: svg_path.Path,
  right_path: svg_path.Path,
) -> Result(Option(svg_path.PathParameter), svg_path.Error) {
  let PathOverlap(left_subpath_index:, right_subpath_index:, correspondence:) =
    overlap
  case
    left_parameter.subpath_index == left_subpath_index,
    list_item(left_path.subpaths, left_subpath_index),
    list_item(right_path.subpaths, right_subpath_index)
  {
    True, Some(left_subpath), Some(right_subpath) -> {
      use parameter <- result.try(subpath_overlap_right_parameter(
        correspondence,
        left_parameter.at,
        left_subpath:,
        right_subpath:,
      ))
      Ok(
        option.map(parameter, fn(at) {
          svg_path.PathParameter(subpath_index: right_subpath_index, at:)
        }),
      )
    }
    _, _, _ -> Ok(None)
  }
}

/// Map a right-path address to its exact opposite left-path address.
pub fn path_overlap_left_parameter(
  overlap: PathOverlap,
  right_parameter: svg_path.PathParameter,
  left_path: svg_path.Path,
  right_path: svg_path.Path,
) -> Result(Option(svg_path.PathParameter), svg_path.Error) {
  let PathOverlap(left_subpath_index:, right_subpath_index:, correspondence:) =
    overlap
  case
    right_parameter.subpath_index == right_subpath_index,
    list_item(left_path.subpaths, left_subpath_index),
    list_item(right_path.subpaths, right_subpath_index)
  {
    True, Some(left_subpath), Some(right_subpath) -> {
      use parameter <- result.try(subpath_overlap_left_parameter(
        correspondence,
        right_parameter.at,
        left_subpath:,
        right_subpath:,
      ))
      Ok(
        option.map(parameter, fn(at) {
          svg_path.PathParameter(subpath_index: left_subpath_index, at:)
        }),
      )
    }
    _, _, _ -> Ok(None)
  }
}

fn list_item(items: List(a), index: Int) -> Option(a) {
  case items, index {
    _, index if index < 0 -> None
    [], _ -> None
    [first, ..], 0 -> Some(first)
    [_, ..rest], index -> list_item(rest, index - 1)
  }
}

/// Return overlaps between two paths.
pub fn path(
  left: svg_path.Path,
  right: svg_path.Path,
) -> Result(List(PathOverlap), svg_path.Error) {
  path_with(left, right, tolerance: default_overlap_tolerance)
}

/// Return path overlaps using an explicit finite, non-negative tolerance.
///
/// Results retain the complete subpath correspondence and the two source
/// subpath indices. Continuous overlaps never join across subpath boundaries.
/// The tolerance has the module-wide geometric and normalized-parameter
/// meaning.
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
        list.fold(subpath_overlaps, found, fn(found, correspondence) {
          [
            PathOverlap(
              left_subpath_index:,
              right_subpath_index:,
              correspondence:,
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
