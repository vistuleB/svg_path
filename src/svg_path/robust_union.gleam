//// Isolated prototype for arrangement-style segment noding.
////
//// This module is intentionally separate from `svg_path/csg`. It experiments
//// with the segment-pair primitive needed before contour tracing: collect all
//// immutable pair encounters, split once, and canonicalize overlapping line
//// spans while preserving one output occurrence per contributor.

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

type IndexedSegment {
  IndexedSegment(index: Int, segment: svg_path.Segment)
}

type PairEncounter {
  PairEncounter(
    left_index: Int,
    right_index: Int,
    encounter: overlaps.SegmentEncounter,
  )
}

type SpanReplacement {
  SpanReplacement(index: Int, from: Float, to: Float, segment: svg_path.Segment)
}

type SpanPiece {
  SpanPiece(index: Int, from: Float, to: Float)
}

type Junction {
  Junction(index: Int, t: Float, point: svg_path.Point)
}

type Candidate {
  Candidate(index: Int, segment: svg_path.Segment, turn: Float)
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
  let indexed = index_segments(segments, 0, [])
  use encounters <- result.try(collect_pair_encounters(indexed, options, []))
  let cuts = collect_cuts(indexed, encounters, options.tolerance)
  let junctions = collect_junctions(encounters)
  let replacements = collect_replacements(encounters)
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
      overlaps.Intersection(left_t:, right_t:, point:) -> [
        Junction(index: left_index, t: left_t, point:),
        Junction(index: right_index, t: right_t, point:),
      ]
      overlaps.Overlap(..) -> []
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
/// Contours are noded independently for now; intersections between separate
/// contours will be included when the prototype gains path-level provenance.
pub fn union_nonzero(
  input: svg_path.Path,
) -> Result(svg_path.Path, svg_path.Error) {
  let segments =
    input
    |> svg_path.path_subpaths
    |> list.flat_map(svg_path.subpath_segments)
  use noded <- result.try(node_segments(segments))
  trace_segments(noded, intersections.default_options().tolerance)
}

fn trace_segments(
  pieces: List(svg_path.Segment),
  tolerance: Float,
) -> Result(svg_path.Path, svg_path.Error) {
  use contours <- result.try(trace_all(pieces, tolerance, []))
  Ok(svg_path.Path(contours))
}

fn trace_all(
  remaining: List(svg_path.Segment),
  tolerance: Float,
  contours: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), svg_path.Error) {
  case remaining {
    [] -> Ok(list.reverse(contours))
    _ -> {
      let #(seed, rest) = take_outermost(remaining)
      use contour <- result.try(trace_contour(seed, rest, tolerance))
      let used = svg_path.subpath_segments(contour)
      let remaining = remove_occurrences(remaining, used, tolerance)
      trace_all(remaining, tolerance, [contour, ..contours])
    }
  }
}

fn trace_contour(
  seed: svg_path.Segment,
  remaining: List(svg_path.Segment),
  tolerance: Float,
) -> Result(svg_path.Subpath, svg_path.Error) {
  let start = svg_path.segment_start(seed)
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
  current: svg_path.Segment,
  remaining: List(svg_path.Segment),
  tolerance: Float,
  reversed: List(svg_path.Segment),
  limit: Int,
) -> Result(svg_path.Subpath, svg_path.Error) {
  let end = svg_path.segment_end(current)
  case same_point(end, start, tolerance) {
    True -> assemble_contour(list.reverse(reversed))
    False -> {
      case limit <= 0 {
        True -> Error(svg_path.OverlappingSegments)
        False -> {
          use next <- result.try(next_piece(current, end, remaining, tolerance))
          let Candidate(index:, segment:, ..) = next
          trace_contour_loop(
            start,
            segment,
            remove_index(remaining, index, []),
            tolerance,
            [segment, ..reversed],
            limit - 1,
          )
        }
      }
    }
  }
}

fn next_piece(
  incoming: svg_path.Segment,
  point: svg_path.Point,
  pieces: List(svg_path.Segment),
  tolerance: Float,
) -> Result(Candidate, svg_path.Error) {
  use incoming_derivative <- result.try(svg_path.segment_derivative(
    incoming,
    at: 1.0,
  ))
  let candidates =
    collect_candidates(pieces, point, incoming_derivative, tolerance, 0, [])
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
  pieces: List(svg_path.Segment),
  point: svg_path.Point,
  incoming: svg_path.Point,
  tolerance: Float,
  index: Int,
  candidates: List(Candidate),
) -> List(Candidate) {
  case pieces {
    [] -> candidates
    [piece, ..rest] -> {
      let oriented = case
        same_point(svg_path.segment_start(piece), point, tolerance)
      {
        True -> Ok(piece)
        False ->
          case same_point(svg_path.segment_end(piece), point, tolerance) {
            True -> Ok(svg_path.segment_reverse(piece))
            False -> Error(Nil)
          }
      }
      let candidates = case oriented {
        Error(_) -> candidates
        Ok(segment) -> {
          let turn = turn_score(incoming, segment)
          [Candidate(index:, segment:, turn:), ..candidates]
        }
      }
      collect_candidates(
        rest,
        point,
        incoming,
        tolerance,
        index + 1,
        candidates,
      )
    }
  }
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
  pieces: List(svg_path.Segment),
) -> #(svg_path.Segment, List(svg_path.Segment)) {
  let assert [first, ..rest] = pieces
  take_outermost_loop(rest, first, [])
}

fn take_outermost_loop(
  pieces: List(svg_path.Segment),
  best: svg_path.Segment,
  skipped: List(svg_path.Segment),
) -> #(svg_path.Segment, List(svg_path.Segment)) {
  case pieces {
    [] -> #(best, list.reverse(skipped))
    [piece, ..rest] ->
      case support_x(piece) <. support_x(best) {
        True -> take_outermost_loop(rest, piece, [best, ..skipped])
        False -> take_outermost_loop(rest, best, [piece, ..skipped])
      }
  }
}

fn support_x(segment: svg_path.Segment) -> Float {
  float.min(svg_path.segment_start(segment).x, svg_path.segment_end(segment).x)
}

// Close a traced segment sequence into a subpath and normalize it clockwise.
//
// Union contract: every output loop is oriented clockwise (non-negative signed
// area in SVG's y-down space), regardless of the direction of the original
// input subpaths.
fn assemble_contour(
  segments: List(svg_path.Segment),
) -> Result(svg_path.Subpath, svg_path.Error) {
  use open <- result.try(svg_path.subpath_with(
    segments,
    policy: svg_path.WiggleThenBridge,
  ))
  use closed <- result.try(svg_path.subpath_set_closed_with(
    open,
    closed: True,
    policy: svg_path.WiggleThenBridge,
  ))
  case area.signed_subpath(closed) >=. 0.0 {
    True -> Ok(closed)
    False -> Ok(svg_path.subpath_reverse(closed))
  }
}

fn remove_index(
  pieces: List(svg_path.Segment),
  target: Int,
  kept: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case pieces {
    [] -> list.reverse(kept)
    [piece, ..rest] ->
      case target == 0 {
        True -> list.append(list.reverse(kept), rest)
        False -> remove_index(rest, target - 1, [piece, ..kept])
      }
  }
}

fn remove_occurrences(
  pieces: List(svg_path.Segment),
  used: List(svg_path.Segment),
  tolerance: Float,
) -> List(svg_path.Segment) {
  case used {
    [] -> pieces
    [segment, ..rest] ->
      remove_occurrences(
        remove_matching(pieces, segment, tolerance, []),
        rest,
        tolerance,
      )
  }
}

fn remove_matching(
  pieces: List(svg_path.Segment),
  target: svg_path.Segment,
  tolerance: Float,
  kept: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case pieces {
    [] -> list.reverse(kept)
    [piece, ..rest] ->
      case same_directed_piece(piece, target, tolerance) {
        True -> list.append(list.reverse(kept), rest)
        False -> remove_matching(rest, target, tolerance, [piece, ..kept])
      }
  }
}

fn same_directed_piece(
  a: svg_path.Segment,
  b: svg_path.Segment,
  tolerance: Float,
) -> Bool {
  let same_direction =
    same_point(svg_path.segment_start(a), svg_path.segment_start(b), tolerance)
    && same_point(svg_path.segment_end(a), svg_path.segment_end(b), tolerance)
  let reversed_direction =
    same_point(svg_path.segment_start(a), svg_path.segment_end(b), tolerance)
    && same_point(svg_path.segment_end(a), svg_path.segment_start(b), tolerance)
  same_direction || reversed_direction
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

fn line_overlap_encounters(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
) -> Result(List(overlaps.SegmentEncounter), svg_path.Error) {
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
          let right_start_left_t =
            line_parameter(left_start, left_dx, left_dy, right_start)
          let right_end_left_t =
            line_parameter(left_start, left_dx, left_dy, right_end)
          let overlap_from =
            max_float(0.0, min_float(right_start_left_t, right_end_left_t))
          let overlap_to =
            min_float(1.0, max_float(right_start_left_t, right_end_left_t))

          case overlap_to -. overlap_from <=. tolerance {
            True -> Ok([])
            False -> {
              let assert Ok(from_point) =
                svg_path.segment_point(left, at: overlap_from)
              let assert Ok(to_point) =
                svg_path.segment_point(left, at: overlap_to)
              let right_from =
                line_parameter(right_start, right_dx, right_dy, from_point)
              let right_to =
                line_parameter(right_start, right_dx, right_dy, to_point)

              Ok([
                overlaps.Overlap(
                  left_from: overlap_from,
                  left_to: overlap_to,
                  right_from:,
                  right_to:,
                  start: from_point,
                  end: to_point,
                ),
              ])
            }
          }
        }
      }
    }
    _, _ -> Error(svg_path.OverlappingSegments)
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
      let IndexedSegment(index: left_index, segment: left_segment) = left
      let IndexedSegment(index: right_index, segment: right_segment) = right
      use encounters <- result.try(overlaps.segment_with(
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
            overlaps.Intersection(left_t:, right_t:, ..) -> {
              case index == left_index, index == right_index {
                True, _ -> [left_t, ..cuts]
                _, True -> [right_t, ..cuts]
                _, _ -> cuts
              }
            }
            overlaps.Overlap(left_from:, left_to:, right_from:, right_to:, ..) -> {
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
) -> List(SpanReplacement) {
  encounters
  |> list.flat_map(fn(pair) {
    case pair {
      PairEncounter(left_index:, right_index:, encounter:) -> {
        case encounter {
          overlaps.Overlap(
            left_from:,
            left_to:,
            right_from:,
            right_to:,
            start:,
            end:,
          ) -> {
            let left_span = normalized_span(left_from, left_to)
            let right_span = normalized_span(right_from, right_to)
            [
              SpanReplacement(
                index: left_index,
                from: left_span.0,
                to: left_span.1,
                segment: svg_path.Line(start:, end:),
              ),
              SpanReplacement(
                index: right_index,
                from: right_span.0,
                to: right_span.1,
                segment: svg_path.Line(start:, end:),
              ),
            ]
          }
          _ -> []
        }
      }
    }
  })
}

fn build_noded_segments(
  indexed: List(IndexedSegment),
  cuts: List(#(Int, List(Float))),
  replacements: List(SpanReplacement),
  junctions: List(Junction),
  tolerance: Float,
  built: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), svg_path.Error) {
  case indexed {
    [] -> Ok(list.reverse(built))
    [IndexedSegment(index:, segment:), ..rest] -> {
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
        list.append(list.reverse(pieces), built),
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
) -> Result(List(svg_path.Segment), svg_path.Error) {
  let spans = spans_from_cuts(index, cuts, tolerance, [])
  build_span_segments(spans, segment, replacements, junctions, tolerance, [])
}

fn build_span_segments(
  spans: List(SpanPiece),
  segment: svg_path.Segment,
  replacements: List(SpanReplacement),
  junctions: List(Junction),
  tolerance: Float,
  built: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), svg_path.Error) {
  case spans {
    [] -> Ok(list.reverse(built))
    [span, ..rest] -> {
      let SpanPiece(index:, from:, to:) = span
      use piece <- result.try(
        case find_replacement(index, from, to, replacements, tolerance) {
          Ok(replacement) -> Ok(replacement)
          Error(Nil) ->
            case svg_path.segment_between_inside(segment, from:, to:) {
              Ok(piece) -> Ok(piece)
              Error(_) -> atomic_line_fallback(segment, from, to)
            }
        },
      )
      let piece =
        snap_atomic_piece(piece, index, from, to, junctions, tolerance)
      build_span_segments(rest, segment, replacements, junctions, tolerance, [
        piece,
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
) -> Result(svg_path.Segment, Nil) {
  case replacements {
    [] -> Error(Nil)
    [replacement, ..rest] -> {
      let SpanReplacement(
        index: replacement_index,
        from: replacement_from,
        to: replacement_to,
        segment:,
      ) = replacement
      case
        index == replacement_index
        && near(from, replacement_from, tolerance)
        && near(to, replacement_to, tolerance)
      {
        True -> Ok(segment)
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
  indexed: List(IndexedSegment),
) -> List(IndexedSegment) {
  case segments {
    [] -> list.reverse(indexed)
    [segment, ..rest] ->
      index_segments(rest, index + 1, [
        IndexedSegment(index:, segment:),
        ..indexed
      ])
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

fn normalized_span(a: Float, b: Float) -> #(Float, Float) {
  #(min_float(a, b), max_float(a, b))
}

fn clamp01(value: Float) -> Float {
  value |> max_float(0.0) |> min_float(1.0)
}

fn near(a: Float, b: Float, tolerance: Float) -> Bool {
  float.absolute_value(a -. b) <=. tolerance
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
