//// Legacy arrangement-based Nonzero union and segment noding.
////
//// The pipeline preserves occurrence and operand provenance through
//// intersection noding, overlap ownership, fill-level classification, and
//// role-aware contour tracing.

import gleam/float
import gleam/int
import gleam/list
import gleam/order
import gleam/result
import svg_path
import svg_path/area
import svg_path/intersections
import svg_path/overlaps
import svg_path/trig
import svg_path/winding_field

type Operand {
  SingleInput
  LeftOperand
  RightOperand
}

type BoundaryRole {
  Unclassified
  FillBoundary(zero_on_left: Bool)
  InternalLevelBoundary
  EqualLevelSlit
}

type IndexedSegment {
  IndexedSegment(
    index: Int,
    operand: Operand,
    source_subpath: Int,
    source_segment: Int,
    segment: svg_path.Segment,
  )
}

// Internal arrangement output. `source_occurrence` identifies the original
// input segment; `occurrence_id` identifies one emitted contour occurrence.
// Neither is a geometric identity, so coincident contributors remain distinct.
type AtomicPiece {
  AtomicPiece(
    occurrence_id: Int,
    source_occurrence: Int,
    operand: Operand,
    source_subpath: Int,
    source_segment: Int,
    overlap_group: Int,
    segment: svg_path.Segment,
    level_left: Int,
    level_right: Int,
    output_level: Int,
    role: BoundaryRole,
  )
}

type PairEncounter {
  PairEncounter(
    left_index: Int,
    right_index: Int,
    encounter: LegacySegmentEncounter,
  )
}

type LegacySegmentEncounter {
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

type SpanReplacement {
  SpanReplacement(
    index: Int,
    from: Float,
    to: Float,
    overlap_group: Int,
    segment: svg_path.Segment,
  )
}

type SpanPiece {
  SpanPiece(index: Int, from: Float, to: Float)
}

type BuiltPiece {
  BuiltPiece(segment: svg_path.Segment, overlap_group: Int)
}

type Junction {
  Junction(index: Int, t: Float, point: svg_path.Point)
}

type Candidate {
  Candidate(occurrence_id: Int, piece: AtomicPiece, turn: Float)
}

type OutputContour {
  OutputContour(
    subpath: svg_path.Subpath,
    output_level: Int,
    role: BoundaryRole,
  )
}

pub fn node_segments(
  segments: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), svg_path.Error) {
  node_segments_with(segments, options: intersections.default_options())
}

pub fn node_segments_with(
  segments: List(svg_path.Segment),
  options options: intersections.IntersectionOptions,
) -> Result(List(svg_path.Segment), svg_path.Error) {
  let indexed = index_segments(segments, 0, SingleInput, 0, 0, [])
  use pieces <- result.try(node_atomic_segments(indexed, options))
  Ok(
    pieces
    |> list.map(fn(piece) {
      let AtomicPiece(segment:, ..) = piece
      segment
    }),
  )
}

fn node_atomic_segments(
  indexed: List(IndexedSegment),
  options: intersections.IntersectionOptions,
) -> Result(List(AtomicPiece), svg_path.Error) {
  use encounters <- result.try(collect_pair_encounters(indexed, options, []))
  let cuts = collect_cuts(indexed, encounters, options.tolerance)
  let junctions = collect_junctions(encounters)
  let replacements =
    collect_replacements(encounters, 1, [])
    |> merge_replacement_groups(options.tolerance)
  build_noded_segments(
    indexed,
    cuts,
    replacements,
    junctions,
    options.tolerance,
    [],
  )
}

fn collect_junctions(encounters: List(PairEncounter)) -> List(Junction) {
  encounters
  |> list.flat_map(fn(pair) {
    let PairEncounter(left_index:, right_index:, encounter:) = pair
    case encounter {
      Intersection(left_t:, right_t:, point:) -> [
        Junction(index: left_index, t: left_t, point:),
        Junction(index: right_index, t: right_t, point:),
      ]
      Overlap(..) -> []
    }
  })
}

pub fn node_subpaths(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
) -> Result(List(svg_path.Segment), svg_path.Error) {
  node_subpaths_with(left, right, options: intersections.default_options())
}

pub fn node_subpaths_with(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
  options options: intersections.IntersectionOptions,
) -> Result(List(svg_path.Segment), svg_path.Error) {
  let segments =
    list.append(
      svg_path.subpath_segments(left),
      svg_path.subpath_segments(right),
    )
  node_segments_with(segments, options:)
}

/// Return the filled-set boundary of `input` under the nonzero rule.
///
/// This preview-stage operation first nodes each closed contour through the
/// arrangement primitive in this module. It then delegates only contour
/// assembly to the established nonzero boundary assembler. The existing CSG
/// implementation is not changed.
///
/// All contours are noded together while retaining their source locations.
pub fn union_nonzero(
  input: svg_path.Path,
) -> Result(svg_path.Path, svg_path.Error) {
  let options = intersections.default_options()
  let #(indexed, _) = index_path(input, SingleInput, starting_at: 0)
  use atomic_pieces <- result.try(node_atomic_segments(indexed, options))
  let tolerance = options.tolerance
  use boundaries <- result.try(
    nonzero_boundaries(atomic_pieces, input, tolerance, []),
  )
  trace_segments(boundaries, tolerance)
}

/// Return the Nonzero union of two operands. Atomic pieces are classified by
/// the output fill level on both sides before contour tracing.
pub fn union_nonzero_paths(
  left: svg_path.Path,
  right: svg_path.Path,
) -> Result(svg_path.Path, svg_path.Error) {
  let options = intersections.default_options()
  let #(left_indexed, next_index) =
    index_path(left, LeftOperand, starting_at: 0)
  let #(right_indexed, _) =
    index_path(right, RightOperand, starting_at: next_index)
  let indexed = list.append(left_indexed, right_indexed)
  use atomic_pieces <- result.try(node_atomic_segments(indexed, options))
  let tolerance = options.tolerance
  use boundaries <- result.try(
    union_boundaries(atomic_pieces, left, right, tolerance, []),
  )
  trace_segments(boundaries, tolerance)
}

fn union_boundaries(
  pieces: List(AtomicPiece),
  left_path: svg_path.Path,
  right_path: svg_path.Path,
  tolerance: Float,
  retained: List(AtomicPiece),
) -> Result(List(AtomicPiece), svg_path.Error) {
  case pieces {
    [] -> Ok(list.reverse(retained))
    [first, ..rest] -> {
      let AtomicPiece(
        occurrence_id:,
        source_occurrence:,
        operand:,
        source_subpath:,
        source_segment:,
        overlap_group:,
        segment:,
        ..,
      ) = first
      use left_levels <- result.try(winding_field.segment_side_nonzero_levels(
        segment,
        within: left_path,
        tolerance:,
        options: svg_path.default_containment_options(),
      ))
      use right_levels <- result.try(winding_field.segment_side_nonzero_levels(
        segment,
        within: right_path,
        tolerance:,
        options: svg_path.default_containment_options(),
      ))
      let #(left_a, right_a) = left_levels
      let #(left_b, right_b) = right_levels
      let left = union_level(left_a, left_b)
      let right = union_level(right_a, right_b)
      let lower_level = int.min(left, right)
      let higher_level = int.max(left, right)
      let role = boundary_role(left, right, overlap_group)
      let oriented = case left >= right {
        True ->
          AtomicPiece(
            occurrence_id:,
            source_occurrence:,
            operand:,
            source_subpath:,
            source_segment:,
            overlap_group:,
            segment:,
            level_left: left,
            level_right: right,
            output_level: higher_level,
            role:,
          )
        False ->
          AtomicPiece(
            occurrence_id:,
            source_occurrence:,
            operand:,
            source_subpath:,
            source_segment:,
            overlap_group:,
            segment: svg_path.segment_reverse(segment),
            level_left: right,
            level_right: left,
            output_level: higher_level,
            role: reverse_boundary_role(role),
          )
      }
      let retained = case
        lower_level == higher_level
        && higher_level > 0
        && first.overlap_group > 0
      {
        True -> [oriented, ..retained]
        False ->
          emit_atomic_levels(oriented, lower_level + 1, higher_level, retained)
      }
      union_boundaries(rest, left_path, right_path, tolerance, retained)
    }
  }
}

fn union_level(left: Int, right: Int) -> Int {
  case left != 0 || right != 0 {
    True -> int.absolute_value(left) + int.absolute_value(right)
    False -> 0
  }
}

fn boundary_role(
  left_level: Int,
  right_level: Int,
  overlap_group: Int,
) -> BoundaryRole {
  case left_level == right_level && overlap_group > 0 {
    True -> EqualLevelSlit
    False ->
      case left_level == 0 || right_level == 0 {
        True -> FillBoundary(zero_on_left: left_level == 0)
        False -> InternalLevelBoundary
      }
  }
}

fn reverse_boundary_role(role: BoundaryRole) -> BoundaryRole {
  case role {
    FillBoundary(zero_on_left:) -> FillBoundary(zero_on_left: !zero_on_left)
    other -> other
  }
}

fn nonzero_boundaries(
  pieces: List(AtomicPiece),
  input: svg_path.Path,
  tolerance: Float,
  retained: List(AtomicPiece),
) -> Result(List(AtomicPiece), svg_path.Error) {
  case pieces {
    [] -> Ok(list.reverse(retained))
    [first, ..rest] -> {
      let AtomicPiece(
        occurrence_id:,
        source_occurrence:,
        operand:,
        source_subpath:,
        source_segment:,
        overlap_group:,
        segment:,
        ..,
      ) = first
      use levels <- result.try(winding_field.segment_side_nonzero_levels(
        segment,
        within: input,
        tolerance:,
        options: svg_path.default_containment_options(),
      ))
      let #(left, right) = levels
      let lower_level = int.min(left, right)
      let higher_level = int.max(left, right)
      let role = boundary_role(left, right, overlap_group)
      let oriented = case left >= right {
        True ->
          AtomicPiece(
            occurrence_id:,
            source_occurrence:,
            operand:,
            source_subpath:,
            source_segment:,
            overlap_group:,
            segment:,
            level_left: left,
            level_right: right,
            output_level: higher_level,
            role:,
          )
        False ->
          AtomicPiece(
            occurrence_id:,
            source_occurrence:,
            operand:,
            source_subpath:,
            source_segment:,
            overlap_group:,
            segment: svg_path.segment_reverse(segment),
            level_left: right,
            level_right: left,
            output_level: higher_level,
            role: reverse_boundary_role(role),
          )
      }
      let retained =
        emit_atomic_levels(oriented, lower_level + 1, higher_level, retained)
      nonzero_boundaries(rest, input, tolerance, retained)
    }
  }
}

fn emit_atomic_levels(
  piece: AtomicPiece,
  level: Int,
  higher_level: Int,
  retained: List(AtomicPiece),
) -> List(AtomicPiece) {
  case level > higher_level {
    True -> retained
    False -> {
      let AtomicPiece(
        occurrence_id:,
        source_occurrence:,
        operand:,
        source_subpath:,
        source_segment:,
        overlap_group:,
        segment:,
        level_left:,
        level_right:,
        role:,
        ..,
      ) = piece
      let labelled =
        AtomicPiece(
          occurrence_id:,
          source_occurrence:,
          operand:,
          source_subpath:,
          source_segment:,
          overlap_group:,
          segment:,
          level_left:,
          level_right:,
          output_level: level,
          role:,
        )
      emit_atomic_levels(labelled, level + 1, higher_level, [
        labelled,
        ..retained
      ])
    }
  }
}

fn trace_segments(
  pieces: List(AtomicPiece),
  tolerance: Float,
) -> Result(svg_path.Path, svg_path.Error) {
  let pieces =
    pieces
    |> resolve_overlap_ownership([], [])
    |> list.index_map(fn(piece, occurrence_id) {
      set_occurrence_id(piece, occurrence_id)
    })
  use contours <- result.try(trace_all(pieces, tolerance, []))
  use contours <- result.try(orient_output_contours(contours, tolerance, []))
  Ok(
    contours
    |> list.map(fn(contour) {
      let OutputContour(subpath:, ..) = contour
      subpath
    })
    |> svg_path.Path,
  )
}

fn resolve_overlap_ownership(
  pieces: List(AtomicPiece),
  owned: List(#(Int, Int, BoundaryRole)),
  retained: List(AtomicPiece),
) -> List(AtomicPiece) {
  case pieces {
    [] -> list.reverse(retained)
    [piece, ..rest] -> {
      let AtomicPiece(overlap_group:, output_level:, role:, ..) = piece
      case overlap_group == 0 {
        True -> resolve_overlap_ownership(rest, owned, [piece, ..retained])
        False -> {
          let AtomicPiece(level_left:, level_right:, ..) = piece
          case level_left == level_right {
            True -> resolve_overlap_ownership(rest, owned, [piece, ..retained])
            False -> {
              let key = #(overlap_group, output_level, role)
              case list.contains(owned, key) {
                True -> resolve_overlap_ownership(rest, owned, retained)
                False ->
                  resolve_overlap_ownership(rest, [key, ..owned], [
                    piece,
                    ..retained
                  ])
              }
            }
          }
        }
      }
    }
  }
}

fn trace_all(
  remaining: List(AtomicPiece),
  tolerance: Float,
  contours: List(OutputContour),
) -> Result(List(OutputContour), svg_path.Error) {
  case remaining {
    [] -> Ok(list.reverse(contours))
    _ -> {
      let #(seed, rest) = take_outermost(remaining)
      use traced <- result.try(trace_contour(seed, rest, tolerance))
      let #(contour, remaining) = traced
      trace_all(remaining, tolerance, [contour, ..contours])
    }
  }
}

fn trace_contour(
  seed: AtomicPiece,
  remaining: List(AtomicPiece),
  tolerance: Float,
) -> Result(#(OutputContour, List(AtomicPiece)), svg_path.Error) {
  let AtomicPiece(segment:, ..) = seed
  let start = svg_path.segment_start(segment)
  trace_contour_loop(
    start,
    seed,
    remaining,
    tolerance,
    [seed],
    list.length(remaining) + 2,
  )
}

fn trace_contour_loop(
  start: svg_path.Point,
  current: AtomicPiece,
  remaining: List(AtomicPiece),
  tolerance: Float,
  reversed: List(AtomicPiece),
  limit: Int,
) -> Result(#(OutputContour, List(AtomicPiece)), svg_path.Error) {
  let AtomicPiece(segment: current_segment, ..) = current
  let end = svg_path.segment_end(current_segment)
  case same_point(end, start, tolerance) {
    True -> {
      let pieces = list.reverse(reversed)
      let assert [first, ..] = pieces
      let AtomicPiece(output_level:, role:, ..) = first
      use subpath <- result.try(assemble_contour(pieces))
      Ok(#(OutputContour(subpath:, output_level:, role:), remaining))
    }
    False -> {
      case limit <= 0 {
        True -> Error(svg_path.OverlappingSegments)
        False -> {
          use next <- result.try(next_piece(current, end, remaining, tolerance))
          let Candidate(occurrence_id:, piece:, ..) = next
          trace_contour_loop(
            start,
            piece,
            remove_occurrence_id(remaining, occurrence_id, []),
            tolerance,
            [piece, ..reversed],
            limit - 1,
          )
        }
      }
    }
  }
}

fn atomic_segments(pieces: List(AtomicPiece)) -> List(svg_path.Segment) {
  pieces
  |> list.map(fn(piece) {
    let AtomicPiece(segment:, ..) = piece
    segment
  })
}

fn next_piece(
  incoming: AtomicPiece,
  point: svg_path.Point,
  pieces: List(AtomicPiece),
  tolerance: Float,
) -> Result(Candidate, svg_path.Error) {
  let AtomicPiece(
    segment: incoming_segment,
    output_level: incoming_level,
    role: incoming_role,
    ..,
  ) = incoming
  use incoming_derivative <- result.try(svg_path.segment_derivative(
    incoming_segment,
    at: 1.0,
  ))
  let candidates =
    collect_candidates(
      pieces,
      point,
      incoming_derivative,
      incoming_level,
      incoming_role,
      tolerance,
      [],
    )
  let candidates = case list.filter(candidates, keeping: non_u_turn) {
    [] -> candidates
    non_u_turns -> non_u_turns
  }
  case candidates |> list.sort(by: compare_candidates) |> list.first {
    Ok(candidate) -> Ok(candidate)
    Error(Nil) -> Error(svg_path.OverlappingSegments)
  }
}

const u_turn_epsilon = 1.0e-6

fn non_u_turn(candidate: Candidate) -> Bool {
  float.absolute_value(float.absolute_value(candidate.turn) -. 180.0)
  >. u_turn_epsilon
}

fn collect_candidates(
  pieces: List(AtomicPiece),
  point: svg_path.Point,
  incoming: svg_path.Point,
  output_level: Int,
  role: BoundaryRole,
  tolerance: Float,
  candidates: List(Candidate),
) -> List(Candidate) {
  case pieces {
    [] -> candidates
    [piece, ..rest] -> {
      let AtomicPiece(occurrence_id:, segment:, output_level: piece_level, ..) =
        piece
      let oriented = case
        same_point(svg_path.segment_start(segment), point, tolerance)
      {
        True -> Ok(piece)
        False ->
          case same_point(svg_path.segment_end(segment), point, tolerance) {
            True -> Ok(reverse_atomic_piece(piece))
            False -> Error(Nil)
          }
      }
      let oriented = case oriented {
        Error(_) -> Error(Nil)
        Ok(oriented_piece) -> {
          let AtomicPiece(output_level: oriented_level, role: oriented_role, ..) =
            oriented_piece
          case
            piece_level == output_level
            && oriented_level == output_level
            && roles_compatible(role, oriented_role)
          {
            True -> Ok(oriented_piece)
            False -> Error(Nil)
          }
        }
      }
      let candidates = case oriented {
        Error(_) -> candidates
        Ok(oriented_piece) -> {
          let AtomicPiece(segment: oriented_segment, ..) = oriented_piece
          let turn = turn_score(incoming, oriented_segment)
          [
            Candidate(occurrence_id:, piece: oriented_piece, turn:),
            ..candidates
          ]
        }
      }
      collect_candidates(
        rest,
        point,
        incoming,
        output_level,
        role,
        tolerance,
        candidates,
      )
    }
  }
}

fn roles_compatible(left: BoundaryRole, right: BoundaryRole) -> Bool {
  case left, right {
    EqualLevelSlit, EqualLevelSlit -> True
    EqualLevelSlit, _ -> False
    _, EqualLevelSlit -> False
    Unclassified, Unclassified -> True
    Unclassified, _ -> False
    _, Unclassified -> False
    _, _ -> True
  }
}

fn reverse_atomic_piece(piece: AtomicPiece) -> AtomicPiece {
  let AtomicPiece(
    occurrence_id:,
    source_occurrence:,
    operand:,
    source_subpath:,
    source_segment:,
    overlap_group:,
    segment:,
    level_left:,
    level_right:,
    output_level:,
    role:,
  ) = piece
  AtomicPiece(
    occurrence_id:,
    source_occurrence:,
    operand:,
    source_subpath:,
    source_segment:,
    overlap_group:,
    segment: svg_path.segment_reverse(segment),
    level_left: level_right,
    level_right: level_left,
    output_level:,
    role: reverse_boundary_role(role),
  )
}

fn set_occurrence_id(piece: AtomicPiece, occurrence_id: Int) -> AtomicPiece {
  let AtomicPiece(
    source_occurrence:,
    operand:,
    source_subpath:,
    source_segment:,
    overlap_group:,
    segment:,
    level_left:,
    level_right:,
    output_level:,
    role:,
    ..,
  ) = piece
  AtomicPiece(
    occurrence_id:,
    source_occurrence:,
    operand:,
    source_subpath:,
    source_segment:,
    overlap_group:,
    segment:,
    level_left:,
    level_right:,
    output_level:,
    role:,
  )
}

// Signed turn from the incoming tangent to the candidate tangent. SVG has a
// downward Y axis, so visually counterclockwise turns have negative scores.
fn turn_score(incoming: svg_path.Point, outgoing: svg_path.Segment) -> Float {
  case svg_path.segment_derivative(outgoing, at: 0.0) {
    Error(_) -> 360.0
    Ok(derivative) ->
      trig.atan2_degrees(
        incoming.x *. derivative.y -. incoming.y *. derivative.x,
        incoming.x *. derivative.x +. incoming.y *. derivative.y,
      )
  }
}

fn compare_candidates(left: Candidate, right: Candidate) -> order.Order {
  float.compare(left.turn, right.turn)
}

fn take_outermost(
  pieces: List(AtomicPiece),
) -> #(AtomicPiece, List(AtomicPiece)) {
  let assert [first, ..rest] = pieces
  take_outermost_loop(rest, first, [])
}

fn take_outermost_loop(
  pieces: List(AtomicPiece),
  best: AtomicPiece,
  skipped: List(AtomicPiece),
) -> #(AtomicPiece, List(AtomicPiece)) {
  case pieces {
    [] -> #(best, list.reverse(skipped))
    [piece, ..rest] -> {
      let AtomicPiece(segment: piece_segment, ..) = piece
      let AtomicPiece(segment: best_segment, ..) = best
      case support_x(piece_segment) <. support_x(best_segment) {
        True -> take_outermost_loop(rest, piece, [best, ..skipped])
        False -> take_outermost_loop(rest, best, [piece, ..skipped])
      }
    }
  }
}

fn support_x(segment: svg_path.Segment) -> Float {
  float.min(svg_path.segment_start(segment).x, svg_path.segment_end(segment).x)
}

// Close a traced segment sequence. Orientation is assigned after every
// contour has been traced, when fill-boundary nesting is available.
fn assemble_contour(
  pieces: List(AtomicPiece),
) -> Result(svg_path.Subpath, svg_path.Error) {
  let segments = atomic_segments(pieces)
  use open <- result.try(svg_path.subpath_with(
    segments,
    policy: svg_path.WiggleThenBridge,
  ))
  use closed <- result.try(svg_path.subpath_set_closed_with(
    open,
    closed: True,
    policy: svg_path.WiggleThenBridge,
  ))
  Ok(closed)
}

fn orient_output_contours(
  remaining: List(OutputContour),
  tolerance: Float,
  oriented: List(OutputContour),
) -> Result(List(OutputContour), svg_path.Error) {
  case remaining {
    [] -> Ok(list.reverse(oriented))
    [contour, ..rest] -> {
      use oriented_contour <- result.try(orient_output_contour(
        contour,
        among: list.append(oriented, remaining),
        tolerance:,
      ))
      orient_output_contours(rest, tolerance, [oriented_contour, ..oriented])
    }
  }
}

fn orient_output_contour(
  contour: OutputContour,
  among contours: List(OutputContour),
  tolerance tolerance: Float,
) -> Result(OutputContour, svg_path.Error) {
  let OutputContour(subpath:, output_level:, role:) = contour
  use subpath <- result.try(case role {
    FillBoundary(_) -> {
      use hole <- result.try(fill_contour_is_hole(
        contour,
        among: contours,
        tolerance:,
      ))
      case hole {
        True -> orient_counterclockwise(subpath)
        False -> orient_clockwise(subpath)
      }
    }
    InternalLevelBoundary -> orient_clockwise(subpath)
    EqualLevelSlit -> Ok(subpath)
    Unclassified -> orient_clockwise(subpath)
  })
  Ok(OutputContour(subpath:, output_level:, role:))
}

fn fill_contour_is_hole(
  contour: OutputContour,
  among contours: List(OutputContour),
  tolerance tolerance: Float,
) -> Result(Bool, svg_path.Error) {
  let OutputContour(subpath:, ..) = contour
  let assert [first, ..] = svg_path.subpath_segments(subpath)
  use probe <- result.try(svg_path.segment_point(first, at: 0.5))
  use containers <- result.try(count_fill_containers(
    contours,
    probe,
    float.absolute_value(area.signed_subpath(subpath)),
    tolerance,
    0,
  ))
  let assert Ok(remainder) = int.modulo(containers, 2)
  Ok(remainder == 1)
}

fn count_fill_containers(
  contours: List(OutputContour),
  probe: svg_path.Point,
  target_area: Float,
  tolerance: Float,
  count: Int,
) -> Result(Int, svg_path.Error) {
  case contours {
    [] -> Ok(count)
    [OutputContour(subpath:, role:, ..), ..rest] -> {
      let candidate_area = float.absolute_value(area.signed_subpath(subpath))
      case role, candidate_area >. target_area +. tolerance {
        FillBoundary(_), True -> {
          use containment <- result.try(svg_path.path_containment(
            probe,
            within: svg_path.Path([subpath]),
            using: svg_path.Nonzero,
          ))
          count_fill_containers(
            rest,
            probe,
            target_area,
            tolerance,
            case containment {
              svg_path.Inside -> count + 1
              svg_path.Outside | svg_path.Boundary -> count
            },
          )
        }
        _, _ ->
          count_fill_containers(rest, probe, target_area, tolerance, count)
      }
    }
  }
}

fn orient_clockwise(
  subpath: svg_path.Subpath,
) -> Result(svg_path.Subpath, svg_path.Error) {
  case area.signed_subpath(subpath) >=. 0.0 {
    True -> Ok(subpath)
    False -> Ok(svg_path.subpath_reverse(subpath))
  }
}

fn orient_counterclockwise(
  subpath: svg_path.Subpath,
) -> Result(svg_path.Subpath, svg_path.Error) {
  case area.signed_subpath(subpath) <. 0.0 {
    True -> Ok(subpath)
    False -> Ok(svg_path.subpath_reverse(subpath))
  }
}

fn remove_occurrence_id(
  pieces: List(AtomicPiece),
  target: Int,
  kept: List(AtomicPiece),
) -> List(AtomicPiece) {
  case pieces {
    [] -> list.reverse(kept)
    [piece, ..rest] -> {
      let AtomicPiece(occurrence_id:, ..) = piece
      case occurrence_id == target {
        True -> list.append(list.reverse(kept), rest)
        False -> remove_occurrence_id(rest, target, [piece, ..kept])
      }
    }
  }
}

fn same_point(a: svg_path.Point, b: svg_path.Point, tolerance: Float) -> Bool {
  let dx = a.x -. b.x
  let dy = a.y -. b.y
  dx *. dx +. dy *. dy <=. tolerance *. tolerance
}

pub fn node_path(
  input: svg_path.Path,
) -> Result(svg_path.Path, svg_path.Error) {
  input
  |> svg_path.path_subpaths
  |> node_path_subpaths([])
  |> result.map(svg_path.path_combine)
}

fn node_path_subpaths(
  subpaths: List(svg_path.Subpath),
  noded: List(svg_path.Path),
) -> Result(List(svg_path.Path), svg_path.Error) {
  case subpaths {
    [] -> Ok(list.reverse(noded))
    [subpath, ..rest] -> {
      use segments <- result.try(
        node_segments(svg_path.subpath_segments(subpath)),
      )
      use rebuilt <- result.try(svg_path.subpath_with(
        segments,
        policy: svg_path.Wiggle,
      ))
      use rebuilt <- result.try(svg_path.subpath_set_closed_with(
        rebuilt,
        closed: svg_path.subpath_is_closed(subpath),
        policy: svg_path.Wiggle,
      ))
      node_path_subpaths(rest, [svg_path.path_from_subpath(rebuilt), ..noded])
    }
  }
}

fn collect_pair_encounters(
  indexed: List(IndexedSegment),
  options: intersections.IntersectionOptions,
  found: List(PairEncounter),
) -> Result(List(PairEncounter), svg_path.Error) {
  case indexed {
    [] -> Ok(list.reverse(found))
    [left, ..rest] -> {
      use found <- result.try(collect_against(left, rest, options, found))
      collect_pair_encounters(rest, options, found)
    }
  }
}

fn collect_against(
  left: IndexedSegment,
  rest: List(IndexedSegment),
  options: intersections.IntersectionOptions,
  found: List(PairEncounter),
) -> Result(List(PairEncounter), svg_path.Error) {
  case rest {
    [] -> Ok(found)
    [right, ..tail] -> {
      let IndexedSegment(index: left_index, segment: left_segment, ..) = left
      let IndexedSegment(index: right_index, segment: right_segment, ..) = right
      use encounters <- result.try(legacy_segment_encounters(
        left_segment,
        right_segment,
        options:,
      ))
      let found =
        list.fold(encounters, found, fn(found, encounter) {
          [PairEncounter(left_index:, right_index:, encounter:), ..found]
        })
      collect_against(left, tail, options, found)
    }
  }
}

fn legacy_segment_encounters(
  left: svg_path.Segment,
  right: svg_path.Segment,
  options options: intersections.IntersectionOptions,
) -> Result(List(LegacySegmentEncounter), svg_path.Error) {
  use found_overlaps <- result.try(overlaps.segment_with(
    left,
    right,
    tolerance: options.tolerance,
  ))
  case found_overlaps {
    [_, ..] ->
      Ok(
        list.map(found_overlaps, fn(overlap) {
          let overlaps.SegmentOverlap(
            left_from:,
            left_to:,
            right_from:,
            right_to:,
            start:,
            end:,
          ) = overlap
          Overlap(left_from:, left_to:, right_from:, right_to:, start:, end:)
        }),
      )
    [] -> {
      use found <- result.try(intersections.segment_with(left, right, options:))
      Ok(
        list.map(found, fn(intersection) {
          let svg_path.SegmentIntersection(left_t:, right_t:, point:) =
            intersection
          Intersection(left_t:, right_t:, point:)
        }),
      )
    }
  }
}

fn collect_cuts(
  indexed: List(IndexedSegment),
  encounters: List(PairEncounter),
  tolerance: Float,
) -> List(#(Int, List(Float))) {
  indexed
  |> list.map(fn(item) {
    let IndexedSegment(index:, ..) = item
    #(index, cuts_for(index, encounters, tolerance, [0.0, 1.0]))
  })
}

fn cuts_for(
  index: Int,
  encounters: List(PairEncounter),
  tolerance: Float,
  cuts: List(Float),
) -> List(Float) {
  let cuts =
    list.fold(encounters, cuts, fn(cuts, pair) {
      case pair {
        PairEncounter(left_index:, right_index:, encounter:) -> {
          case encounter {
            Intersection(left_t:, right_t:, ..) -> {
              case index == left_index, index == right_index {
                True, _ -> [left_t, ..cuts]
                _, True -> [right_t, ..cuts]
                _, _ -> cuts
              }
            }
            Overlap(left_from:, left_to:, right_from:, right_to:, ..) -> {
              case index == left_index, index == right_index {
                True, _ -> [left_from, left_to, ..cuts]
                _, True -> [right_from, right_to, ..cuts]
                _, _ -> cuts
              }
            }
          }
        }
      }
    })

  cuts
  |> list.map(clamp01)
  |> list.sort(by: float.compare)
  |> unique_floats(tolerance, [])
}

fn collect_replacements(
  encounters: List(PairEncounter),
  next_group: Int,
  replacements: List(SpanReplacement),
) -> List(SpanReplacement) {
  case encounters {
    [] -> list.reverse(replacements)
    [PairEncounter(left_index:, right_index:, encounter:), ..rest] -> {
      case encounter {
        Overlap(left_from:, left_to:, right_from:, right_to:, start:, end:) -> {
          let left_span = normalized_span(left_from, left_to)
          let right_span = normalized_span(right_from, right_to)
          let left_segment = case left_from <=. left_to {
            True -> svg_path.Line(start:, end:)
            False -> svg_path.Line(start: end, end: start)
          }
          let right_segment = case right_from <=. right_to {
            True -> svg_path.Line(start:, end:)
            False -> svg_path.Line(start: end, end: start)
          }
          collect_replacements(rest, next_group + 1, [
            SpanReplacement(
              index: right_index,
              from: right_span.0,
              to: right_span.1,
              overlap_group: next_group,
              segment: right_segment,
            ),
            SpanReplacement(
              index: left_index,
              from: left_span.0,
              to: left_span.1,
              overlap_group: next_group,
              segment: left_segment,
            ),
            ..replacements
          ])
        }
        _ -> collect_replacements(rest, next_group, replacements)
      }
    }
  }
}

fn merge_replacement_groups(
  replacements: List(SpanReplacement),
  tolerance: Float,
) -> List(SpanReplacement) {
  case find_group_merge(replacements, tolerance) {
    Error(Nil) -> replacements
    Ok(#(discarded, retained)) ->
      replacements
      |> replace_group(discarded, retained, [])
      |> merge_replacement_groups(tolerance)
  }
}

fn find_group_merge(
  replacements: List(SpanReplacement),
  tolerance: Float,
) -> Result(#(Int, Int), Nil) {
  case replacements {
    [] -> Error(Nil)
    [first, ..rest] ->
      case find_matching_member(first, rest, tolerance) {
        Ok(groups) -> Ok(groups)
        Error(Nil) -> find_group_merge(rest, tolerance)
      }
  }
}

fn find_matching_member(
  member: SpanReplacement,
  replacements: List(SpanReplacement),
  tolerance: Float,
) -> Result(#(Int, Int), Nil) {
  let SpanReplacement(
    index: member_index,
    from: member_from,
    to: member_to,
    overlap_group: member_group,
    ..,
  ) = member
  case replacements {
    [] -> Error(Nil)
    [candidate, ..rest] -> {
      let SpanReplacement(
        index: candidate_index,
        from: candidate_from,
        to: candidate_to,
        overlap_group: candidate_group,
        ..,
      ) = candidate
      case
        member_group != candidate_group
        && member_index == candidate_index
        && near(member_from, candidate_from, tolerance)
        && near(member_to, candidate_to, tolerance)
      {
        True ->
          case member_group > candidate_group {
            True -> Ok(#(member_group, candidate_group))
            False -> Ok(#(candidate_group, member_group))
          }
        False -> find_matching_member(member, rest, tolerance)
      }
    }
  }
}

fn replace_group(
  replacements: List(SpanReplacement),
  discarded: Int,
  retained: Int,
  updated: List(SpanReplacement),
) -> List(SpanReplacement) {
  case replacements {
    [] -> list.reverse(updated)
    [replacement, ..rest] -> {
      let SpanReplacement(index:, from:, to:, overlap_group:, segment:) =
        replacement
      let replacement = case overlap_group == discarded {
        True ->
          SpanReplacement(index:, from:, to:, overlap_group: retained, segment:)
        False -> replacement
      }
      replace_group(rest, discarded, retained, [replacement, ..updated])
    }
  }
}

fn build_noded_segments(
  indexed: List(IndexedSegment),
  cuts: List(#(Int, List(Float))),
  replacements: List(SpanReplacement),
  junctions: List(Junction),
  tolerance: Float,
  built: List(AtomicPiece),
) -> Result(List(AtomicPiece), svg_path.Error) {
  case indexed {
    [] -> Ok(list.reverse(built))
    [
      IndexedSegment(
        index:,
        operand:,
        source_subpath:,
        source_segment:,
        segment:,
      ),
      ..rest
    ] -> {
      let segment_cuts = lookup_cuts(index, cuts)
      use pieces <- result.try(build_segment_pieces(
        index,
        segment,
        segment_cuts,
        replacements,
        junctions,
        tolerance,
      ))
      build_noded_segments(
        rest,
        cuts,
        replacements,
        junctions,
        tolerance,
        list.append(
          list.map(list.reverse(pieces), fn(piece) {
            let BuiltPiece(segment:, overlap_group:) = piece
            AtomicPiece(
              occurrence_id: 0,
              source_occurrence: index,
              operand:,
              source_subpath:,
              source_segment:,
              overlap_group:,
              segment:,
              level_left: 0,
              level_right: 0,
              output_level: 0,
              role: Unclassified,
            )
          }),
          built,
        ),
      )
    }
  }
}

fn build_segment_pieces(
  index: Int,
  segment: svg_path.Segment,
  cuts: List(Float),
  replacements: List(SpanReplacement),
  junctions: List(Junction),
  tolerance: Float,
) -> Result(List(BuiltPiece), svg_path.Error) {
  let spans = spans_from_cuts(index, cuts, tolerance, [])
  build_span_segments(spans, segment, replacements, junctions, tolerance, [])
}

fn build_span_segments(
  spans: List(SpanPiece),
  segment: svg_path.Segment,
  replacements: List(SpanReplacement),
  junctions: List(Junction),
  tolerance: Float,
  built: List(BuiltPiece),
) -> Result(List(BuiltPiece), svg_path.Error) {
  case spans {
    [] -> Ok(list.reverse(built))
    [span, ..rest] -> {
      let SpanPiece(index:, from:, to:) = span
      use built_piece <- result.try(
        case find_replacement(index, from, to, replacements, tolerance) {
          Ok(replacement) -> {
            let SpanReplacement(segment:, overlap_group:, ..) = replacement
            Ok(BuiltPiece(segment:, overlap_group:))
          }
          Error(Nil) ->
            case svg_path.segment_between_inside(segment, from:, to:) {
              Ok(piece) -> Ok(BuiltPiece(segment: piece, overlap_group: 0))
              Error(_) ->
                atomic_line_fallback(segment, from, to)
                |> result.map(fn(piece) {
                  BuiltPiece(segment: piece, overlap_group: 0)
                })
            }
        },
      )
      let BuiltPiece(segment: piece, overlap_group:) = built_piece
      let snapped_piece =
        snap_atomic_piece(piece, index, from, to, junctions, tolerance)
      build_span_segments(rest, segment, replacements, junctions, tolerance, [
        BuiltPiece(segment: snapped_piece, overlap_group:),
        ..built
      ])
    }
  }
}

fn snap_atomic_piece(
  piece: svg_path.Segment,
  index: Int,
  from: Float,
  to: Float,
  junctions: List(Junction),
  tolerance: Float,
) -> svg_path.Segment {
  let start =
    canonical_junction(
      index,
      from,
      junctions,
      tolerance,
      svg_path.segment_start(piece),
    )
  let end =
    canonical_junction(
      index,
      to,
      junctions,
      tolerance,
      svg_path.segment_end(piece),
    )
  piece |> segment_with_start(start) |> segment_with_end(end)
}

fn canonical_junction(
  index: Int,
  t: Float,
  junctions: List(Junction),
  tolerance: Float,
  fallback: svg_path.Point,
) -> svg_path.Point {
  case junctions {
    [] -> fallback
    [Junction(index: junction_index, t: junction_t, point:), ..rest] ->
      case index == junction_index && near(t, junction_t, tolerance) {
        True -> point
        False -> canonical_junction(index, t, rest, tolerance, fallback)
      }
  }
}

fn segment_with_start(
  segment: svg_path.Segment,
  start: svg_path.Point,
) -> svg_path.Segment {
  case segment {
    svg_path.Line(end:, ..) -> svg_path.Line(start:, end:)
    svg_path.QuadraticBezier(control:, end:, ..) ->
      svg_path.QuadraticBezier(start:, control:, end:)
    svg_path.CubicBezier(control1:, control2:, end:, ..) ->
      svg_path.CubicBezier(start:, control1:, control2:, end:)
    svg_path.Arc(radius:, x_axis_rotation:, large_arc:, sweep:, end:, ..) ->
      svg_path.Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:)
  }
}

fn segment_with_end(
  segment: svg_path.Segment,
  end: svg_path.Point,
) -> svg_path.Segment {
  case segment {
    svg_path.Line(start:, ..) -> svg_path.Line(start:, end:)
    svg_path.QuadraticBezier(start:, control:, ..) ->
      svg_path.QuadraticBezier(start:, control:, end:)
    svg_path.CubicBezier(start:, control1:, control2:, ..) ->
      svg_path.CubicBezier(start:, control1:, control2:, end:)
    svg_path.Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, ..) ->
      svg_path.Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:)
  }
}

fn atomic_line_fallback(
  segment: svg_path.Segment,
  from: Float,
  to: Float,
) -> Result(svg_path.Segment, svg_path.Error) {
  use start <- result.try(svg_path.segment_point(segment, at: from))
  use end <- result.try(svg_path.segment_point(segment, at: to))
  Ok(svg_path.Line(start:, end:))
}

fn spans_from_cuts(
  index: Int,
  cuts: List(Float),
  tolerance: Float,
  spans: List(SpanPiece),
) -> List(SpanPiece) {
  case cuts {
    [] | [_] -> list.reverse(spans)
    [from, to, ..rest] -> {
      let spans = case to -. from <=. tolerance {
        True -> spans
        False -> [SpanPiece(index:, from:, to:), ..spans]
      }
      spans_from_cuts(index, [to, ..rest], tolerance, spans)
    }
  }
}

fn find_replacement(
  index: Int,
  from: Float,
  to: Float,
  replacements: List(SpanReplacement),
  tolerance: Float,
) -> Result(SpanReplacement, Nil) {
  case replacements {
    [] -> Error(Nil)
    [replacement, ..rest] -> {
      let SpanReplacement(
        index: replacement_index,
        from: replacement_from,
        to: replacement_to,
        ..,
      ) = replacement
      case
        index == replacement_index
        && near(from, replacement_from, tolerance)
        && near(to, replacement_to, tolerance)
      {
        True -> Ok(replacement)
        False -> find_replacement(index, from, to, rest, tolerance)
      }
    }
  }
}

fn lookup_cuts(index: Int, cuts: List(#(Int, List(Float)))) -> List(Float) {
  case cuts {
    [] -> [0.0, 1.0]
    [#(cut_index, values), ..rest] -> {
      case index == cut_index {
        True -> values
        False -> lookup_cuts(index, rest)
      }
    }
  }
}

fn index_segments(
  segments: List(svg_path.Segment),
  index: Int,
  operand: Operand,
  source_subpath: Int,
  source_segment: Int,
  indexed: List(IndexedSegment),
) -> List(IndexedSegment) {
  case segments {
    [] -> list.reverse(indexed)
    [segment, ..rest] ->
      index_segments(
        rest,
        index + 1,
        operand,
        source_subpath,
        source_segment + 1,
        [
          IndexedSegment(
            index:,
            operand:,
            source_subpath:,
            source_segment:,
            segment:,
          ),
          ..indexed
        ],
      )
  }
}

fn index_path(
  path: svg_path.Path,
  operand: Operand,
  starting_at starting_at: Int,
) -> #(List(IndexedSegment), Int) {
  index_subpaths(svg_path.path_subpaths(path), operand, 0, starting_at, [])
}

fn index_subpaths(
  subpaths: List(svg_path.Subpath),
  operand: Operand,
  source_subpath: Int,
  next_index: Int,
  indexed: List(IndexedSegment),
) -> #(List(IndexedSegment), Int) {
  case subpaths {
    [] -> #(list.reverse(indexed), next_index)
    [subpath, ..rest] -> {
      let subpath_segments = svg_path.subpath_segments(subpath)
      let additions =
        index_segments(
          subpath_segments,
          next_index,
          operand,
          source_subpath,
          0,
          [],
        )
      index_subpaths(
        rest,
        operand,
        source_subpath + 1,
        next_index + list.length(subpath_segments),
        list.append(list.reverse(additions), indexed),
      )
    }
  }
}

fn unique_floats(
  values: List(Float),
  tolerance: Float,
  unique: List(Float),
) -> List(Float) {
  case values {
    [] -> list.reverse(unique)
    [value, ..rest] -> {
      case unique {
        [previous, ..] -> {
          case near(value, previous, tolerance) {
            True -> unique_floats(rest, tolerance, unique)
            False -> unique_floats(rest, tolerance, [value, ..unique])
          }
        }
        _ -> unique_floats(rest, tolerance, [value, ..unique])
      }
    }
  }
}

fn normalized_span(a: Float, b: Float) -> #(Float, Float) {
  #(min_float(a, b), max_float(a, b))
}

fn clamp01(value: Float) -> Float {
  value |> max_float(0.0) |> min_float(1.0)
}

fn near(a: Float, b: Float, tolerance: Float) -> Bool {
  float.absolute_value(a -. b) <=. tolerance
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
