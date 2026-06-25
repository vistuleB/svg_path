//// Convex hull helpers for paths, subpaths, and segments.
////
//// This module computes closed hulls. Lines, quadratic Beziers, and arcs have
//// semantic hulls: the primitive itself plus the chord joining its endpoints,
//// with tiny/point-like cases collapsed to lines. Cubic Beziers use a
//// cubic-specific support/event solver.

import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam_community/maths
import svg_path

const cubic_sample_count = 3600

const loop_union_sample_count = 720

const loop_union_tie_tolerance = 0.0000001

const loop_union_point_tolerance = 0.000001

const loop_union_bisection_steps = 32

const loop_prefilter_enabled = True

const loop_prefilter_sample_count = 36

const same_t = 0.000001

const t_close = 0.08

const point_tolerance = 0.000000001

const loop_diagnostics_enabled = False

const orientation_turn_tolerance = 0.000000001

const tangent_turn_sample_count = 24

type SupportSample {
  SupportSample(angle: Float, t: Float, point: svg_path.Point, value: Float)
}

type Run {
  Run(ts: List(Float))
}

type RunEndpoint {
  PointEndpoint(t: Float)
  CurveEndpoint(from: Float, to: Float)
}

type LoopSupport {
  LoopSupport(param: LoopParam, point: svg_path.Point, value: Float)
}

type LoopParam {
  LoopParam(segment_index: Int, t: Float)
}

type Loop {
  Loop(segments: List(svg_path.Segment))
}

type ConvexPolygon {
  ConvexPolygon(vertices: List(svg_path.Point))
}

type ConvexLoop {
  ConvexLoop(loop: Loop, enclosure: ConvexPolygon)
}

type UnionPiece {
  HullLineAB(LoopParam, LoopParam)
  HullLineBA(LoopParam, LoopParam)
  LoopPieceA(LoopParam, LoopParam)
  LoopPieceB(LoopParam, LoopParam)
}

type LoopWinner {
  LoopA
  LoopB
}

type LoopSample {
  LoopSample(
    angle: Float,
    winner: LoopWinner,
    a: LoopSupport,
    b: LoopSupport,
    difference: Float,
  )
}

type LoopBoundary {
  LoopBoundary(
    angle: Float,
    a: LoopSupport,
    b: LoopSupport,
    from: LoopWinner,
    to: LoopWinner,
  )
}

type HullPiece {
  HullCurve(Float, Float)
  HullLine(Float, Float)
}

pub type HullError {
  /// The generated hull segments could not be converted into a valid closed
  /// `Subpath`.
  PathError(svg_path.Error)

  /// The final hull-piece sequence failed the invariant that curve pieces must
  /// be separated by line pieces.
  ConsecutiveCurves

  /// The refined support samples still contained adjacent duplicate segment
  /// parameters.
  DuplicateAdjacentTValues

  /// Support-sample refinement did not settle before the iteration limit.
  RefinementReachedMaxIterations(Int)

  /// Support-sample simplification did not settle before the iteration limit.
  PurificationReachedMaxIterations(Int)

  /// Convex-loop union collapsed to no boundary pieces.
  LoopUnionCollapsed
}

/// Compute the convex hull of a subpath.
///
/// The result is a closed subpath. Move-only subpaths are treated as a single
/// point at their start. Otherwise each individual segment is first converted
/// to its own convex hull, then those convex loops are unioned one at a time.
pub fn subpath_hull(
  subpath: svg_path.Subpath,
) -> Result(svg_path.Subpath, HullError) {
  subpath
  |> hull_input_segments
  |> segments_hull
}

/// Compute the convex hull of a path.
///
/// Move-only subpaths are treated as single points at their starts. The result
/// is a single closed subpath containing the hull of every subpath in the input
/// path.
pub fn path_hull(path: svg_path.Path) -> Result(svg_path.Subpath, HullError) {
  case svg_path.subpaths(path) {
    [] -> Error(PathError(svg_path.EmptyPath))
    subpaths -> {
      subpaths
      |> list.flat_map(hull_input_segments)
      |> segments_hull
    }
  }
}

pub fn segment_hull(
  segment: svg_path.Segment,
) -> Result(svg_path.Subpath, HullError) {
  case segment {
    svg_path.Line(..) -> line_hull(segment)
    svg_path.QuadraticBezier(..) | svg_path.Arc(..) ->
      simple_curve_hull(segment)
    svg_path.CubicBezier(..) -> cubic_hull(segment)
  }
}

@internal
pub fn test_segment_support(
  segment: svg_path.Segment,
  angle angle: Float,
) -> Result(#(Float, svg_path.Point, Float), svg_path.Error) {
  use sample <- result.try(segment_support(segment, angle: angle))
  Ok(#(sample.t, sample.point, sample.value))
}

@internal
pub fn test_brute_segment_support(
  segment: svg_path.Segment,
  angle angle: Float,
) -> Result(#(Float, svg_path.Point, Float), svg_path.Error) {
  use sample <- result.try(brute_segment_support(segment, angle: angle))
  Ok(#(sample.t, sample.point, sample.value))
}

fn segments_hull(
  segments: List(svg_path.Segment),
) -> Result(svg_path.Subpath, HullError) {
  use loops <- result.try(segment_convex_loops(segments))
  use convex_loop <- result.try(
    loops
    |> maybe_prefilter_convex_loops
    |> union_convex_loop_list,
  )
  let ConvexLoop(loop:, enclosure: _) = convex_loop
  let Loop(segments:) = loop
  build_closed_subpath(segments)
}

fn segment_convex_loops(
  segments: List(svg_path.Segment),
) -> Result(List(ConvexLoop), HullError) {
  segments
  |> list.fold(Ok([]), fn(loops, segment) {
    use loops <- result.try(loops)
    use loop <- result.try(segment_convex_loop(segment))
    Ok([loop, ..loops])
  })
  |> result.map(list.reverse)
}

fn hull_input_segments(subpath: svg_path.Subpath) -> List(svg_path.Segment) {
  case svg_path.segments(subpath) {
    [] -> {
      let assert Ok(start) = svg_path.start(subpath)
      [point_segment(start)]
    }
    segments -> segments
  }
}

fn point_segment(point: svg_path.Point) -> svg_path.Segment {
  svg_path.Line(start: point, end: point)
}

fn segment_hull_segments(
  segment: svg_path.Segment,
) -> Result(List(svg_path.Segment), HullError) {
  use subpath <- result.try(segment_hull(segment))
  Ok(svg_path.segments(subpath))
}

fn segment_convex_loop(
  segment: svg_path.Segment,
) -> Result(ConvexLoop, HullError) {
  use segments <- result.try(segment_hull_segments(segment))
  Ok(convex_loop(segments))
}

fn convex_loop(segments: List(svg_path.Segment)) -> ConvexLoop {
  let loop = Loop(segments)
  ConvexLoop(loop:, enclosure: loop_enclosure(loop))
}

fn union_convex_loop_list(
  loops: List(ConvexLoop),
) -> Result(ConvexLoop, HullError) {
  case loops {
    [] -> Error(LoopUnionCollapsed)
    [first, ..rest] ->
      rest
      |> list.fold(Ok(first), fn(hull, loop) {
        use hull <- result.try(hull)
        union_convex_loops(hull, loop)
      })
  }
}

fn union_convex_loops(
  left: ConvexLoop,
  right: ConvexLoop,
) -> Result(ConvexLoop, HullError) {
  let ConvexLoop(loop: Loop(left_segments), enclosure: _) = left
  let ConvexLoop(loop: Loop(right_segments), enclosure: _) = right
  use segments <- result.try(union_loop_segments(left_segments, right_segments))
  Ok(convex_loop(segments))
}

fn maybe_prefilter_convex_loops(loops: List(ConvexLoop)) -> List(ConvexLoop) {
  case loop_prefilter_enabled {
    True -> prefilter_convex_loops(loops)
    False -> loops
  }
}

fn prefilter_convex_loops(loops: List(ConvexLoop)) -> List(ConvexLoop) {
  case loops {
    [] | [_] -> loops
    _ -> {
      let envelope = first_pass_envelope(loops)
      case convex_polygon_orientation(envelope) {
        DegenerateOrientation -> loops
        orientation -> {
          let filtered =
            loops
            |> list.filter(fn(loop) {
              convex_loop_strictly_inside(loop, envelope, orientation) == False
            })

          case filtered {
            [] -> loops
            _ -> filtered
          }
        }
      }
    }
  }
}

fn first_pass_envelope(loops: List(ConvexLoop)) -> ConvexPolygon {
  let points =
    int.range(
      from: 0,
      to: loop_prefilter_sample_count - 1,
      with: [],
      run: fn(points, i) {
        let angle =
          int.to_float(i) *. 360.0 /. int.to_float(loop_prefilter_sample_count)

        case convex_loop_family_support(loops, angle) {
          Ok(support) -> [support.point, ..points]
          Error(_) -> points
        }
      },
    )
    |> list.reverse
    |> remove_closing_duplicate
    |> remove_near_adjacent_duplicates

  ConvexPolygon(vertices: points)
}

fn convex_loop_family_support(
  loops: List(ConvexLoop),
  angle: Float,
) -> Result(LoopSupport, Nil) {
  case loops {
    [] -> Error(Nil)
    [first, ..rest] -> {
      let first = convex_loop_exact_support(first, angle)
      convex_loop_family_support_loop(
        rest,
        angle,
        best: Ok(first),
        value_to_beat: first.value,
      )
    }
  }
}

fn convex_loop_family_support_loop(
  loops: List(ConvexLoop),
  angle: Float,
  best best: Result(LoopSupport, Nil),
  value_to_beat value_to_beat: Float,
) -> Result(LoopSupport, Nil) {
  case loops {
    [] -> best
    [loop, ..rest] -> {
      let #(best, value_to_beat) = case
        convex_loop_support(loop, angle, value_to_beat:)
      {
        Error(_) -> #(best, value_to_beat)
        Ok(candidate) -> #(Ok(candidate), candidate.value)
      }

      convex_loop_family_support_loop(rest, angle, best:, value_to_beat:)
    }
  }
}

fn convex_loop_support(
  convex_loop: ConvexLoop,
  angle: Float,
  value_to_beat value_to_beat: Float,
) -> Result(LoopSupport, Nil) {
  let ConvexLoop(loop:, enclosure:) = convex_loop
  case convex_polygon_support_value(enclosure, angle) <=. value_to_beat {
    True -> Error(Nil)
    False -> {
      let support = loop_support(loop, angle)
      case support.value >. value_to_beat {
        True -> Ok(support)
        False -> Error(Nil)
      }
    }
  }
}

fn convex_loop_exact_support(
  convex_loop: ConvexLoop,
  angle: Float,
) -> LoopSupport {
  let ConvexLoop(loop:, enclosure: _) = convex_loop
  loop_support(loop, angle)
}

fn convex_loop_strictly_inside(
  convex_loop: ConvexLoop,
  envelope: ConvexPolygon,
  orientation: LoopOrientation,
) -> Bool {
  let ConvexLoop(enclosure: ConvexPolygon(vertices:), loop: _) = convex_loop
  case vertices {
    [] -> False
    _ ->
      list.all(vertices, fn(point) {
        convex_polygon_strictly_contains_point(envelope, point, orientation)
      })
  }
}

fn convex_polygon_strictly_contains_point(
  polygon: ConvexPolygon,
  point: svg_path.Point,
  orientation: LoopOrientation,
) -> Bool {
  let ConvexPolygon(vertices:) = polygon
  case vertices {
    [] | [_] | [_, _] -> False
    [first, ..] ->
      convex_polygon_strictly_contains_point_loop(
        list.append(vertices, [first]),
        point,
        orientation,
      )
  }
}

fn convex_polygon_strictly_contains_point_loop(
  points: List(svg_path.Point),
  point: svg_path.Point,
  orientation: LoopOrientation,
) -> Bool {
  case points {
    [a, b, ..rest] -> {
      let edge = subtract(b, a)
      let offset = subtract(point, a)
      let turn = cross(edge, offset)
      let scale = point_length(edge) *. point_length(offset)
      case point_is_strictly_inside_edge(turn, scale, orientation) {
        True ->
          convex_polygon_strictly_contains_point_loop(
            [b, ..rest],
            point,
            orientation,
          )
        False -> False
      }
    }
    _ -> True
  }
}

fn point_is_strictly_inside_edge(
  turn: Float,
  scale: Float,
  orientation: LoopOrientation,
) -> Bool {
  let tolerance = orientation_turn_tolerance *. scale
  case orientation {
    CounterClockwise -> turn >. tolerance
    Clockwise -> turn <. 0.0 -. tolerance
    DegenerateOrientation -> False
  }
}

fn convex_polygon_orientation(polygon: ConvexPolygon) -> LoopOrientation {
  let ConvexPolygon(vertices:) = polygon
  let area = signed_area(vertices)
  case float.absolute_value(area) <=. point_tolerance *. point_tolerance {
    True -> DegenerateOrientation
    False ->
      case area >. 0.0 {
        True -> CounterClockwise
        False -> Clockwise
      }
  }
}

fn convex_polygon_support_value(polygon: ConvexPolygon, angle: Float) -> Float {
  let ConvexPolygon(vertices:) = polygon
  let direction = angle_direction(angle)
  case vertices {
    [] -> -1.0 /. 0.0
    [first, ..rest] ->
      rest
      |> list.fold(dot(first, direction), fn(best, point) {
        float.max(best, dot(point, direction))
      })
  }
}

fn loop_enclosure(loop: Loop) -> ConvexPolygon {
  let Loop(segments:) = loop
  case loop_bounding_box(segments) {
    Error(_) -> ConvexPolygon(vertices: loop_vertices(segments))
    Ok(box) -> bounding_box_polygon(box)
  }
}

fn loop_bounding_box(
  segments: List(svg_path.Segment),
) -> Result(svg_path.BoundingBox, svg_path.Error) {
  case segments {
    [] -> Error(svg_path.EmptySubpath)
    [first, ..rest] -> {
      use box <- result.try(svg_path.segment_bounding_box(first))
      loop_bounding_box_loop(rest, box)
    }
  }
}

fn loop_bounding_box_loop(
  segments: List(svg_path.Segment),
  box: svg_path.BoundingBox,
) -> Result(svg_path.BoundingBox, svg_path.Error) {
  case segments {
    [] -> Ok(box)
    [segment, ..rest] -> {
      use next <- result.try(svg_path.segment_bounding_box(segment))
      loop_bounding_box_loop(rest, combine_boxes(box, next))
    }
  }
}

fn combine_boxes(
  first: svg_path.BoundingBox,
  second: svg_path.BoundingBox,
) -> svg_path.BoundingBox {
  svg_path.BoundingBox(
    min: svg_path.point(
      float.min(first.min.x, second.min.x),
      float.min(first.min.y, second.min.y),
    ),
    max: svg_path.point(
      float.max(first.max.x, second.max.x),
      float.max(first.max.y, second.max.y),
    ),
  )
}

fn bounding_box_polygon(box: svg_path.BoundingBox) -> ConvexPolygon {
  ConvexPolygon(vertices: [
    svg_path.point(box.min.x, box.min.y),
    svg_path.point(box.max.x, box.min.y),
    svg_path.point(box.max.x, box.max.y),
    svg_path.point(box.min.x, box.max.y),
  ])
}

fn line_hull(segment: svg_path.Segment) -> Result(svg_path.Subpath, HullError) {
  case segment_is_point_like(segment) {
    True -> build_hull(segment, [HullLine(0.0, 0.0), HullLine(0.0, 0.0)])
    False -> build_hull(segment, [HullLine(0.0, 1.0), HullLine(1.0, 0.0)])
  }
}

fn simple_curve_hull(
  segment: svg_path.Segment,
) -> Result(svg_path.Subpath, HullError) {
  case segment_is_point_like(segment) {
    True -> build_hull(segment, [HullLine(0.0, 0.0), HullLine(0.0, 0.0)])
    False -> build_hull(segment, [HullCurve(0.0, 1.0), HullLine(1.0, 0.0)])
  }
}

fn cubic_hull(
  segment: svg_path.Segment,
) -> Result(svg_path.Subpath, HullError) {
  case segment_is_point_like(segment) {
    True -> build_hull(segment, [HullLine(0.0, 0.0), HullLine(0.0, 0.0)])
    False -> {
      let pieces =
        raw_samples(segment, cubic_sample_count)
        |> collapse_runs
        |> pieces_from_runs
        |> refine_pieces(segment)

      use pieces <- result.try(reject_consecutive_curves(pieces))
      build_hull(segment, pieces)
    }
  }
}

fn build_hull(
  segment: svg_path.Segment,
  pieces: List(HullPiece),
) -> Result(svg_path.Subpath, HullError) {
  use segments <- result.try(pieces_to_segments(segment, pieces))
  build_closed_subpath(segments)
}

fn build_closed_subpath(
  segments: List(svg_path.Segment),
) -> Result(svg_path.Subpath, HullError) {
  use subpath <- result.try(
    svg_path.subpath_with(segments, policy: svg_path.WiggleThenBridge)
    |> map_path_error,
  )
  case
    svg_path.set_closed_with(
      subpath,
      closed: True,
      policy: svg_path.WiggleThenBridge,
    )
    |> map_path_error
  {
    Error(error) -> Error(error)
    Ok(subpath) -> {
      diagnose_closed_loop(svg_path.segments(subpath))
      Ok(subpath)
    }
  }
}

fn union_loop_segments(
  left: List(svg_path.Segment),
  right: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), HullError) {
  let loop_a = Loop(left)
  let loop_b = Loop(right)
  let pieces = loop_union(loop_a, loop_b, sample_count: loop_union_sample_count)
  case union_piece_segments(pieces, loop_a, loop_b) {
    [] -> {
      use segments <- result.try(dominant_loop_segments(loop_a, loop_b))
      diagnose_closed_loop(segments)
      Ok(segments)
    }
    segments -> {
      diagnose_closed_loop(segments)
      Ok(segments)
    }
  }
}

fn dominant_loop_segments(
  loop_a: Loop,
  loop_b: Loop,
) -> Result(List(svg_path.Segment), HullError) {
  case loop_support_dominance(loop_a, loop_b, loop_union_sample_count) {
    LoopADominates -> {
      let Loop(segments:) = loop_a
      Ok(segments)
    }
    LoopBDominates -> {
      let Loop(segments:) = loop_b
      Ok(segments)
    }
    NoLoopDominates -> Error(LoopUnionCollapsed)
  }
}

type LoopDominance {
  LoopADominates
  LoopBDominates
  NoLoopDominates
}

fn loop_support_dominance(
  loop_a: Loop,
  loop_b: Loop,
  sample_count: Int,
) -> LoopDominance {
  let initial = #(True, True)
  let #(a_contains_b, b_contains_a) =
    int.range(from: 0, to: sample_count - 1, with: initial, run: fn(state, i) {
      let #(a_contains_b, b_contains_a) = state
      let angle = int.to_float(i) *. 360.0 /. int.to_float(sample_count)
      let sample = loop_sample(loop_a, loop_b, angle)
      #(
        a_contains_b && sample.difference >=. 0.0 -. loop_union_tie_tolerance,
        b_contains_a && sample.difference <=. loop_union_tie_tolerance,
      )
    })

  case a_contains_b, b_contains_a {
    True, _ -> LoopADominates
    False, True -> LoopBDominates
    False, False -> NoLoopDominates
  }
}

fn loop_union(
  loop_a: Loop,
  loop_b: Loop,
  sample_count sample_count: Int,
) -> List(UnionPiece) {
  let samples = loop_initial_samples(loop_a, loop_b, sample_count)
  let boundaries = loop_transition_boundaries(loop_a, loop_b, samples)

  case boundaries {
    [] -> all_one_loop(samples)
    _ ->
      loop_pieces_from_boundaries(boundaries)
      |> compact_loop_pieces(loop_a, loop_b)
  }
}

fn union_piece_segments(
  pieces: List(UnionPiece),
  loop_a: Loop,
  loop_b: Loop,
) -> List(svg_path.Segment) {
  pieces
  |> list.flat_map(fn(piece) {
    case piece {
      LoopPieceA(from, to) -> loop_piece_segments(loop_a, from, to)
      LoopPieceB(from, to) -> loop_piece_segments(loop_b, from, to)
      HullLineAB(a, b) -> [
        svg_path.Line(start: loop_point(loop_a, a), end: loop_point(loop_b, b)),
      ]
      HullLineBA(b, a) -> [
        svg_path.Line(start: loop_point(loop_b, b), end: loop_point(loop_a, a)),
      ]
    }
  })
}

fn loop_initial_samples(
  loop_a: Loop,
  loop_b: Loop,
  sample_count: Int,
) -> List(LoopSample) {
  int.range(from: 0, to: sample_count - 1, with: [], run: fn(samples, i) {
    let angle = int.to_float(i) *. 360.0 /. int.to_float(sample_count)
    [loop_sample(loop_a, loop_b, angle), ..samples]
  })
  |> list.reverse
}

fn loop_sample(loop_a: Loop, loop_b: Loop, angle: Float) -> LoopSample {
  let a = loop_support(loop_a, angle)
  let b = loop_support(loop_b, angle)
  let difference = a.value -. b.value
  LoopSample(angle:, winner: loop_winner(difference), a:, b:, difference:)
}

fn loop_winner(difference: Float) -> LoopWinner {
  case difference >=. 0.0 {
    True -> LoopA
    False -> LoopB
  }
}

fn loop_transition_boundaries(
  loop_a: Loop,
  loop_b: Loop,
  samples: List(LoopSample),
) -> List(LoopBoundary) {
  circular_pairs(samples)
  |> list.filter_map(fn(pair) {
    let #(left, right) = pair
    case left.winner == right.winner {
      True -> Error(Nil)
      False ->
        Ok(loop_refine_boundary(
          loop_a,
          loop_b,
          left.angle,
          right.angle,
          left.winner,
        ))
    }
  })
}

fn loop_refine_boundary(
  loop_a: Loop,
  loop_b: Loop,
  left_angle: Float,
  right_angle: Float,
  left_winner: LoopWinner,
) -> LoopBoundary {
  let right_angle = unwrap_angle_after(left_angle, right_angle)
  let left = loop_sample(loop_a, loop_b, left_angle)
  let right = loop_sample(loop_a, loop_b, right_angle)
  let refined =
    loop_bisect_boundary(
      loop_a,
      loop_b,
      left,
      right,
      loop_union_bisection_steps,
    )
  let angle = normalize_angle(refined.angle)
  let at_boundary = loop_sample(loop_a, loop_b, angle)
  let to = case left_winner {
    LoopA -> LoopB
    LoopB -> LoopA
  }

  LoopBoundary(
    angle:,
    a: at_boundary.a,
    b: at_boundary.b,
    from: left_winner,
    to:,
  )
}

fn loop_bisect_boundary(
  loop_a: Loop,
  loop_b: Loop,
  left: LoopSample,
  right: LoopSample,
  remaining: Int,
) -> LoopSample {
  case
    remaining <= 0
    || float.absolute_value(left.difference) <=. loop_union_tie_tolerance
  {
    True -> left
    False -> {
      let middle_angle = { left.angle +. right.angle } /. 2.0
      let middle = loop_sample(loop_a, loop_b, middle_angle)
      case middle.winner == left.winner {
        True ->
          loop_bisect_boundary(loop_a, loop_b, middle, right, remaining - 1)
        False ->
          loop_bisect_boundary(loop_a, loop_b, left, middle, remaining - 1)
      }
    }
  }
}

fn loop_pieces_from_boundaries(
  boundaries: List(LoopBoundary),
) -> List(UnionPiece) {
  boundaries
  |> circular_pairs
  |> list.map(fn(boundary_pair) {
    let #(start_boundary, end_boundary) = boundary_pair
    let loop_piece = case start_boundary.to {
      LoopA -> LoopPieceA(start_boundary.a.param, end_boundary.a.param)
      LoopB -> LoopPieceB(start_boundary.b.param, end_boundary.b.param)
    }
    let line_piece = case end_boundary.from, end_boundary.to {
      LoopA, LoopB -> HullLineAB(end_boundary.a.param, end_boundary.b.param)
      LoopB, LoopA -> HullLineBA(end_boundary.b.param, end_boundary.a.param)
      _, _ -> loop_piece
    }
    [loop_piece, line_piece]
  })
  |> list.flatten
}

fn compact_loop_pieces(
  pieces: List(UnionPiece),
  loop_a: Loop,
  loop_b: Loop,
) -> List(UnionPiece) {
  pieces
  |> list.filter(fn(piece) {
    case piece {
      LoopPieceA(from, to) ->
        loop_points_far(loop_point(loop_a, from), loop_point(loop_a, to))
      LoopPieceB(from, to) ->
        loop_points_far(loop_point(loop_b, from), loop_point(loop_b, to))
      HullLineAB(a, b) ->
        loop_points_far(loop_point(loop_a, a), loop_point(loop_b, b))
      HullLineBA(b, a) ->
        loop_points_far(loop_point(loop_b, b), loop_point(loop_a, a))
    }
  })
}

fn loop_points_far(a: svg_path.Point, b: svg_path.Point) -> Bool {
  let dx = a.x -. b.x
  let dy = a.y -. b.y
  dx *. dx +. dy *. dy
  >. loop_union_point_tolerance *. loop_union_point_tolerance
}

fn all_one_loop(samples: List(LoopSample)) -> List(UnionPiece) {
  case samples {
    [] -> []
    [first, ..] -> {
      case first.winner {
        LoopA -> [LoopPieceA(first.a.param, first.a.param)]
        LoopB -> [LoopPieceB(first.b.param, first.b.param)]
      }
    }
  }
}

fn loop_support(loop: Loop, angle: Float) -> LoopSupport {
  let Loop(segments:) = loop
  let assert [first, ..rest] = segments
  let first_support = segment_loop_support(first, 0, angle)
  rest
  |> list.index_fold(first_support, fn(best, segment, index) {
    let candidate = segment_loop_support(segment, index + 1, angle)
    case candidate.value >. best.value {
      True -> candidate
      False -> best
    }
  })
}

fn segment_loop_support(
  segment: svg_path.Segment,
  index: Int,
  angle: Float,
) -> LoopSupport {
  let assert Ok(sample) = segment_support(segment, angle: angle)
  LoopSupport(
    param: LoopParam(segment_index: index, t: sample.t),
    point: sample.point,
    value: sample.value,
  )
}

fn loop_point(loop: Loop, param: LoopParam) -> svg_path.Point {
  let Loop(segments:) = loop
  let LoopParam(segment_index:, t:) = param
  let assert Ok(segment) = nth(segments, segment_index)
  let assert Ok(point) = svg_path.segment_point(segment, at: t)
  point
}

fn loop_piece_segments(
  loop: Loop,
  from: LoopParam,
  to: LoopParam,
) -> List(svg_path.Segment) {
  let Loop(segments:) = loop
  let LoopParam(segment_index: from_index, t: from_t) = from
  let LoopParam(segment_index: to_index, t: to_t) = to
  case
    from_index == to_index && float.absolute_value(from_t -. to_t) <=. same_t
  {
    True -> segments
    False ->
      case from_index == to_index {
        True ->
          case from_t <=. to_t {
            True -> [
              loop_partial_segment(
                segment_at(segments, from_index),
                from_t,
                to_t,
              ),
            ]
            False ->
              loop_wrapped_same_segment_piece(
                segments,
                from_index,
                from_t,
                to_t,
              )
          }
        False ->
          walk_segment_indices(from_index, to_index, list.length(segments), [])
          |> list.reverse
          |> list.map(fn(index) {
            let segment = segment_at(segments, index)
            case index == from_index, index == to_index {
              True, _ -> loop_partial_segment(segment, from_t, 1.0)
              _, True -> loop_partial_segment(segment, 0.0, to_t)
              _, _ -> loop_partial_segment(segment, 0.0, 1.0)
            }
          })
      }
  }
}

fn loop_wrapped_same_segment_piece(
  segments: List(svg_path.Segment),
  index: Int,
  from: Float,
  to: Float,
) -> List(svg_path.Segment) {
  let count = list.length(segments)
  let middle =
    walk_segment_indices(next_index(index, count), index, count, [])
    |> list.reverse
    |> drop_last
    |> list.map(fn(index) {
      loop_partial_segment(segment_at(segments, index), 0.0, 1.0)
    })

  list.append(
    [loop_partial_segment(segment_at(segments, index), from, 1.0)],
    list.append(middle, [
      loop_partial_segment(segment_at(segments, index), 0.0, to),
    ]),
  )
}

fn loop_partial_segment(
  segment: svg_path.Segment,
  from: Float,
  to: Float,
) -> svg_path.Segment {
  let assert Ok(part) = svg_path.sub_segment(segment, from: from, to: to)
  part
}

fn segment_at(
  segments: List(svg_path.Segment),
  index: Int,
) -> svg_path.Segment {
  let assert Ok(segment) = nth(segments, index)
  segment
}

fn walk_segment_indices(
  current: Int,
  target: Int,
  count: Int,
  indices: List(Int),
) -> List(Int) {
  case current == target {
    True -> [current, ..indices]
    False ->
      walk_segment_indices(next_index(current, count), target, count, [
        current,
        ..indices
      ])
  }
}

fn next_index(index: Int, count: Int) -> Int {
  case index + 1 >= count {
    True -> 0
    False -> index + 1
  }
}

fn circular_pairs(items: List(t)) -> List(#(t, t)) {
  case items {
    [] | [_] -> []
    [first, ..] -> circular_pairs_loop(items, first, [])
  }
}

fn circular_pairs_loop(
  items: List(t),
  first: t,
  pairs: List(#(t, t)),
) -> List(#(t, t)) {
  case items {
    [] -> pairs |> list.reverse
    [last] -> [#(last, first), ..pairs] |> list.reverse
    [left, right, ..rest] ->
      circular_pairs_loop([right, ..rest], first, [#(left, right), ..pairs])
  }
}

fn unwrap_angle_after(left: Float, right: Float) -> Float {
  case right <=. left {
    True -> right +. 360.0
    False -> right
  }
}

fn normalize_angle(angle: Float) -> Float {
  let turns = float.floor(angle /. 360.0)
  let normalized = angle -. turns *. 360.0
  case normalized <. 0.0 {
    True -> normalized +. 360.0
    False -> normalized
  }
}

fn segment_is_point_like(segment: svg_path.Segment) -> Bool {
  case svg_path.segment_bounding_box(segment) {
    Error(_) -> True
    Ok(box) -> svg_path.bounding_box_diameter(box) <=. point_tolerance
  }
}

fn raw_samples(
  segment: svg_path.Segment,
  sample_count: Int,
) -> List(SupportSample) {
  int.range(from: 0, to: sample_count - 1, with: [], run: fn(samples, i) {
    let angle = int.to_float(i) *. 360.0 /. int.to_float(sample_count)
    case segment_support(segment, angle: angle) {
      Ok(sample) -> [sample, ..samples]
      Error(_) -> samples
    }
  })
  |> list.reverse
}

fn collapse_runs(samples: List(SupportSample)) -> List(Run) {
  case samples {
    [] -> []
    [first, ..rest] -> {
      let runs =
        collapse_runs_loop(rest, current: Run(ts: [first.t]), runs: [])
        |> list.reverse

      merge_circular_run_boundary(runs)
    }
  }
}

fn collapse_runs_loop(
  samples: List(SupportSample),
  current current: Run,
  runs runs: List(Run),
) -> List(Run) {
  case samples {
    [] -> [reverse_run(current), ..runs]
    [sample, ..rest] -> {
      let assert [previous_t, ..] = current.ts
      case float.absolute_value(sample.t -. previous_t) <=. t_close {
        True ->
          collapse_runs_loop(
            rest,
            current: Run(ts: [sample.t, ..current.ts]),
            runs: runs,
          )
        False ->
          collapse_runs_loop(rest, current: Run(ts: [sample.t]), runs: [
            reverse_run(current),
            ..runs
          ])
      }
    }
  }
}

fn reverse_run(run: Run) -> Run {
  Run(ts: list.reverse(run.ts))
}

fn merge_circular_run_boundary(runs: List(Run)) -> List(Run) {
  case runs {
    [] | [_] -> runs
    [first, ..rest] -> {
      case list.last(rest), first.ts {
        Ok(last), [first_t, ..] -> {
          let assert Ok(last_t) = list.last(last.ts)
          case float.absolute_value(first_t -. last_t) <=. t_close {
            True -> [Run(ts: list.append(last.ts, first.ts)), ..drop_last(rest)]
            False -> runs
          }
        }
        _, _ -> runs
      }
    }
  }
}

fn pieces_from_runs(runs: List(Run)) -> List(HullPiece) {
  let endpoints = list.map(runs, run_endpoint)

  case endpoints {
    [] -> []
    [first, ..rest] ->
      pieces_from_endpoints_loop(endpoints, first, rest, pieces: [])
      |> list.reverse
  }
}

fn pieces_from_endpoints_loop(
  endpoints: List(RunEndpoint),
  first first: RunEndpoint,
  rest rest: List(RunEndpoint),
  pieces pieces: List(HullPiece),
) -> List(HullPiece) {
  case endpoints, rest {
    [], _ -> pieces
    [current, ..], [] -> {
      let pieces = add_endpoint_curve(pieces, current)
      add_line(pieces, end_t(current), start_t(first))
    }
    [current, ..remaining], [next, ..next_rest] -> {
      let pieces = add_endpoint_curve(pieces, current)
      let pieces = add_line(pieces, end_t(current), start_t(next))

      pieces_from_endpoints_loop(
        remaining,
        first: first,
        rest: next_rest,
        pieces: pieces,
      )
    }
  }
}

fn run_endpoint(run: Run) -> RunEndpoint {
  let min = list.fold(run.ts, 1.0 /. 0.0, float.min)
  let max = list.fold(run.ts, -1.0 /. 0.0, float.max)

  case max -. min <. same_t {
    True -> PointEndpoint(average(run.ts))
    False -> {
      let assert [from, ..] = run.ts
      let assert Ok(to) = list.last(run.ts)
      CurveEndpoint(from, to)
    }
  }
}

fn add_endpoint_curve(
  pieces: List(HullPiece),
  endpoint: RunEndpoint,
) -> List(HullPiece) {
  case endpoint {
    PointEndpoint(_) -> pieces
    CurveEndpoint(from, to) ->
      case float.absolute_value(from -. to) <=. same_t {
        True -> pieces
        False -> [HullCurve(from, to), ..pieces]
      }
  }
}

fn add_line(
  pieces: List(HullPiece),
  from: Float,
  to: Float,
) -> List(HullPiece) {
  [HullLine(from, to), ..pieces]
}

fn start_t(endpoint: RunEndpoint) -> Float {
  case endpoint {
    PointEndpoint(t) -> t
    CurveEndpoint(from, _) -> from
  }
}

fn end_t(endpoint: RunEndpoint) -> Float {
  case endpoint {
    PointEndpoint(t) -> t
    CurveEndpoint(_, to) -> to
  }
}

fn refine_pieces(
  pieces: List(HullPiece),
  segment: svg_path.Segment,
) -> List(HullPiece) {
  case pieces {
    [] -> []
    [_] -> pieces
    [first, ..] -> {
      let assert Ok(last) = list.last(pieces)
      let window = list.append([last, ..pieces], [first])
      refine_pieces_loop(
        segment,
        window,
        remaining: list.length(pieces),
        refined: [],
      )
      |> list.reverse
      |> sync_line_endpoints
    }
  }
}

fn refine_pieces_loop(
  segment: svg_path.Segment,
  window: List(HullPiece),
  remaining remaining: Int,
  refined refined: List(HullPiece),
) -> List(HullPiece) {
  case remaining <= 0 {
    True -> refined
    False -> {
      let assert [previous, current, next, ..rest] = window
      let refined_current = case current {
        HullCurve(from, to) -> {
          let from = case previous {
            HullLine(other, _) ->
              refine_chord_tangent(segment, approximate: from, other: other)
            _ -> from
          }
          let to = case next {
            HullLine(_, other) ->
              refine_chord_tangent(segment, approximate: to, other: other)
            _ -> to
          }
          HullCurve(from, to)
        }
        HullLine(from, to) -> {
          let from = case previous {
            HullCurve(_, _) ->
              refine_chord_tangent(segment, approximate: from, other: to)
            _ -> from
          }
          let to = case next {
            HullCurve(_, _) ->
              refine_chord_tangent(segment, approximate: to, other: from)
            _ -> to
          }
          HullLine(from, to)
        }
      }

      refine_pieces_loop(
        segment,
        [current, next, ..rest],
        remaining: remaining - 1,
        refined: [refined_current, ..refined],
      )
    }
  }
}

fn sync_line_endpoints(pieces: List(HullPiece)) -> List(HullPiece) {
  case pieces {
    [] -> []
    [_] -> pieces
    [first, ..] -> {
      let assert Ok(last) = list.last(pieces)
      let window = list.append([last, ..pieces], [first])
      sync_line_endpoints_loop(
        window,
        remaining: list.length(pieces),
        synced: [],
      )
      |> list.reverse
    }
  }
}

fn sync_line_endpoints_loop(
  window: List(HullPiece),
  remaining remaining: Int,
  synced synced: List(HullPiece),
) -> List(HullPiece) {
  case remaining <= 0 {
    True -> synced
    False -> {
      let assert [previous, current, next, ..rest] = window
      let current = case current {
        HullLine(from, to) -> {
          let from = case previous {
            HullCurve(_, curve_to) -> curve_to
            _ -> from
          }
          let to = case next {
            HullCurve(curve_from, _) -> curve_from
            _ -> to
          }
          HullLine(from, to)
        }
        _ -> current
      }
      sync_line_endpoints_loop(
        [current, next, ..rest],
        remaining: remaining - 1,
        synced: [current, ..synced],
      )
    }
  }
}

fn refine_chord_tangent(
  segment: svg_path.Segment,
  approximate approximate: Float,
  other other: Float,
) -> Float {
  case approximate <. same_t || approximate >. 1.0 -. same_t {
    True -> approximate
    False -> {
      let initial = chord_tangent_value(segment, approximate, other)
      case float.absolute_value(initial) <. 0.000000000001 {
        True -> approximate
        False ->
          refine_chord_tangent_scan(
            segment,
            other: other,
            left: float.max(0.0, approximate -. 0.08),
            right: float.min(1.0, approximate +. 0.08),
            steps: 64,
            best: approximate,
            best_value: float.absolute_value(initial),
          )
      }
    }
  }
}

fn refine_chord_tangent_scan(
  segment: svg_path.Segment,
  other other: Float,
  left left: Float,
  right right: Float,
  steps steps: Int,
  best best: Float,
  best_value best_value: Float,
) -> Float {
  let initial_value = chord_tangent_value(segment, left, other)
  int.range(
    from: 1,
    to: steps,
    with: Continue(#(left, initial_value, best, best_value)),
    run: fn(state, i) {
      case state {
        Done(root) -> Done(root)
        Continue(#(previous_t, previous_value, best, best_value)) -> {
          let t =
            left +. { right -. left } *. int.to_float(i) /. int.to_float(steps)
          let value = chord_tangent_value(segment, t, other)
          let #(best, best_value) = case
            float.absolute_value(value) <. best_value
          {
            True -> #(t, float.absolute_value(value))
            False -> #(best, best_value)
          }
          case
            value == 0.0
            || previous_value == 0.0
            || same_sign(value, previous_value) == False
          {
            True ->
              Done(bisect_chord_tangent(
                segment,
                other,
                left: previous_t,
                right: t,
              ))
            False -> Continue(#(t, value, best, best_value))
          }
        }
      }
    },
  )
  |> finish_refinement_scan
}

type RefinementScan {
  Done(Float)
  Continue(#(Float, Float, Float, Float))
}

fn finish_refinement_scan(scan: RefinementScan) -> Float {
  case scan {
    Done(root) -> root
    Continue(#(_, _, best, _)) -> best
  }
}

fn bisect_chord_tangent(
  segment: svg_path.Segment,
  other: Float,
  left left: Float,
  right right: Float,
) -> Float {
  let left_value = chord_tangent_value(segment, left, other)
  bisect_chord_tangent_loop(
    segment,
    left,
    left_value,
    right,
    other,
    remaining: 80,
  )
}

fn bisect_chord_tangent_loop(
  segment: svg_path.Segment,
  left: Float,
  left_value: Float,
  right: Float,
  other: Float,
  remaining remaining: Int,
) -> Float {
  let midpoint = left +. { right -. left } /. 2.0
  let midpoint_value = chord_tangent_value(segment, midpoint, other)
  case
    remaining <= 0
    || float.absolute_value(midpoint_value) <. 0.00000000000001
    || float.absolute_value(right -. left) <. 0.000000000001
  {
    True -> midpoint
    False ->
      case same_sign(left_value, midpoint_value) {
        True ->
          bisect_chord_tangent_loop(
            segment,
            midpoint,
            midpoint_value,
            right,
            other,
            remaining: remaining - 1,
          )
        False ->
          bisect_chord_tangent_loop(
            segment,
            left,
            left_value,
            midpoint,
            other,
            remaining: remaining - 1,
          )
      }
  }
}

fn same_sign(a: Float, b: Float) -> Bool {
  a <. 0.0 && b <. 0.0 || a >. 0.0 && b >. 0.0
}

fn segment_support(
  segment: svg_path.Segment,
  angle angle: Float,
) -> Result(SupportSample, svg_path.Error) {
  let direction = angle_direction(angle)
  case segment {
    svg_path.Line(start:, end:) -> {
      let start_value = dot(start, direction)
      let end_value = dot(end, direction)
      case end_value >. start_value {
        True ->
          Ok(SupportSample(angle: angle, t: 1.0, point: end, value: end_value))
        False ->
          Ok(SupportSample(
            angle: angle,
            t: 0.0,
            point: start,
            value: start_value,
          ))
      }
    }
    svg_path.QuadraticBezier(start:, control:, end:) -> {
      let p0 = dot(start, direction)
      let p1 = dot(control, direction)
      let p2 = dot(end, direction)
      let a = p0 -. 2.0 *. p1 +. p2
      let b = -2.0 *. p0 +. 2.0 *. p1
      let candidates =
        [0.0, 1.0, ..quadratic_roots(0.0, 2.0 *. a, b)]
        |> list.filter(fn(t) { t >=. 0.0 && t <=. 1.0 })

      best_segment_support(segment, angle, candidates)
    }
    svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      let p0 = dot(start, direction)
      let p1 = dot(control1, direction)
      let p2 = dot(control2, direction)
      let p3 = dot(end, direction)
      let a = 0.0 -. p0 +. 3.0 *. p1 -. 3.0 *. p2 +. p3
      let b = 3.0 *. p0 -. 6.0 *. p1 +. 3.0 *. p2
      let c = -3.0 *. p0 +. 3.0 *. p1
      let candidates =
        [0.0, 1.0, ..quadratic_roots(3.0 *. a, 2.0 *. b, c)]
        |> list.filter(fn(t) { t >=. 0.0 && t <=. 1.0 })

      best_segment_support(segment, angle, candidates)
    }
    svg_path.Arc(..) -> brute_segment_support(segment, angle: angle)
  }
}

fn brute_segment_support(
  segment: svg_path.Segment,
  angle angle: Float,
) -> Result(SupportSample, svg_path.Error) {
  let direction = angle_direction(angle)
  use t <- result.try(
    svg_path.segment_minimize(segment, measure: fn(point) {
      0.0 -. dot(point, direction)
    }),
  )
  use point <- result.try(svg_path.segment_point(segment, at: t))
  Ok(SupportSample(
    angle: angle,
    t: t,
    point: point,
    value: dot(point, direction),
  ))
}

fn best_segment_support(
  segment: svg_path.Segment,
  angle: Float,
  candidates: List(Float),
) -> Result(SupportSample, svg_path.Error) {
  let assert [first, ..rest] = candidates
  use first <- result.try(support_candidate(segment, angle, first))
  rest
  |> list.fold(Ok(first), fn(best, t) {
    use best <- result.try(best)
    use candidate <- result.try(support_candidate(segment, angle, t))
    case candidate.value >. best.value {
      True -> Ok(candidate)
      False -> Ok(best)
    }
  })
}

fn support_candidate(
  segment: svg_path.Segment,
  angle: Float,
  t: Float,
) -> Result(SupportSample, svg_path.Error) {
  let direction = angle_direction(angle)
  use point <- result.try(svg_path.segment_point(segment, at: t))
  Ok(SupportSample(
    angle: angle,
    t: t,
    point: point,
    value: dot(point, direction),
  ))
}

fn reject_consecutive_curves(
  pieces: List(HullPiece),
) -> Result(List(HullPiece), HullError) {
  case has_consecutive_curves(pieces) {
    True -> Error(ConsecutiveCurves)
    False -> Ok(pieces)
  }
}

fn has_consecutive_curves(pieces: List(HullPiece)) -> Bool {
  case pieces {
    [] -> False
    [first, ..rest] ->
      has_consecutive_curves_loop(first, previous: first, rest: rest)
  }
}

fn has_consecutive_curves_loop(
  first: HullPiece,
  previous previous: HullPiece,
  rest rest: List(HullPiece),
) -> Bool {
  case rest {
    [] -> hull_pieces_are_consecutive_curves(previous, first)
    [current, ..rest] ->
      case hull_pieces_are_consecutive_curves(previous, current) {
        True -> True
        False ->
          has_consecutive_curves_loop(first, previous: current, rest: rest)
      }
  }
}

fn hull_pieces_are_consecutive_curves(
  first: HullPiece,
  second: HullPiece,
) -> Bool {
  case first, second {
    HullCurve(_, _), HullCurve(_, _) -> True
    _, _ -> False
  }
}

fn pieces_to_segments(
  segment: svg_path.Segment,
  pieces: List(HullPiece),
) -> Result(List(svg_path.Segment), HullError) {
  list.fold(pieces, Ok([]), fn(segments, piece) {
    use segments <- result.try(segments)
    use segment <- result.try(piece_to_segment(segment, piece))
    Ok([segment, ..segments])
  })
  |> result.map(list.reverse)
}

fn piece_to_segment(
  segment: svg_path.Segment,
  piece: HullPiece,
) -> Result(svg_path.Segment, HullError) {
  case piece {
    HullCurve(from, to) ->
      svg_path.sub_segment(segment, from: from, to: to)
      |> map_path_error
    HullLine(from, to) -> {
      use start <- result.try(
        svg_path.segment_point(segment, at: from)
        |> map_path_error,
      )
      use end <- result.try(
        svg_path.segment_point(segment, at: to)
        |> map_path_error,
      )
      Ok(svg_path.Line(start: start, end: end))
    }
  }
}

type LoopOrientation {
  CounterClockwise
  Clockwise
  DegenerateOrientation
}

fn diagnose_closed_loop(segments: List(svg_path.Segment)) -> Nil {
  case loop_diagnostics_enabled {
    False -> Nil
    True -> {
      case loop_orientation(segments) {
        DegenerateOrientation -> Nil
        orientation -> {
          diagnose_endpoint_turns(segments, orientation)
          diagnose_segment_tangent_turns(segments, orientation)
        }
      }
    }
  }
}

fn diagnose_endpoint_turns(
  segments: List(svg_path.Segment),
  orientation: LoopOrientation,
) -> Nil {
  case loop_vertices(segments) {
    [] | [_] | [_, _] -> Nil
    [first, second, ..] as vertices -> {
      vertices
      |> list.append([first, second])
      |> diagnose_endpoint_turns_loop(orientation, 0)
    }
  }
}

fn diagnose_endpoint_turns_loop(
  points: List(svg_path.Point),
  orientation: LoopOrientation,
  index: Int,
) -> Nil {
  case points {
    [a, b, c, ..rest] -> {
      let ab = subtract(b, a)
      let bc = subtract(c, b)
      let turn = cross(ab, bc)
      let scale = point_length(ab) *. point_length(bc)

      case turn_is_against_orientation(turn, scale, orientation) {
        True ->
          io.println(
            "[convex_hull diagnostic] endpoint right turn at vertex "
            <> int.to_string(index)
            <> " turn="
            <> float.to_string(turn)
            <> " scale="
            <> float.to_string(scale)
            <> " point="
            <> point_string(b),
          )
        False -> Nil
      }

      diagnose_endpoint_turns_loop([b, c, ..rest], orientation, index + 1)
    }
    _ -> Nil
  }
}

fn diagnose_segment_tangent_turns(
  segments: List(svg_path.Segment),
  orientation: LoopOrientation,
) -> Nil {
  diagnose_segment_tangent_turns_loop(segments, orientation, 0)
}

fn diagnose_segment_tangent_turns_loop(
  segments: List(svg_path.Segment),
  orientation: LoopOrientation,
  index: Int,
) -> Nil {
  case segments {
    [] -> Nil
    [segment, ..rest] -> {
      diagnose_segment_tangent_turn(segment, orientation, index)
      diagnose_segment_tangent_turns_loop(rest, orientation, index + 1)
    }
  }
}

fn diagnose_segment_tangent_turn(
  segment: svg_path.Segment,
  orientation: LoopOrientation,
  segment_index: Int,
) -> Nil {
  case segment {
    svg_path.Line(..) -> Nil
    _ -> {
      let sample_count = tangent_turn_sample_count
      case segment_derivative_sample(segment, 0, sample_count) {
        Error(_) -> Nil
        Ok(first) ->
          diagnose_segment_tangent_turn_loop(
            segment,
            orientation,
            segment_index,
            sample_count: sample_count,
            sample_index: 1,
            previous: first,
          )
      }
    }
  }
}

fn diagnose_segment_tangent_turn_loop(
  segment: svg_path.Segment,
  orientation: LoopOrientation,
  segment_index: Int,
  sample_count sample_count: Int,
  sample_index sample_index: Int,
  previous previous: svg_path.Point,
) -> Nil {
  case sample_index > sample_count {
    True -> Nil
    False -> {
      case segment_derivative_sample(segment, sample_index, sample_count) {
        Error(_) -> Nil
        Ok(current) -> {
          let turn = cross(previous, current)
          let scale = point_length(previous) *. point_length(current)

          case turn_is_against_orientation(turn, scale, orientation) {
            True ->
              io.println(
                "[convex_hull diagnostic] segment tangent reversal at segment "
                <> int.to_string(segment_index)
                <> " ("
                <> segment_kind(segment)
                <> ") sample="
                <> int.to_string(sample_index)
                <> " turn="
                <> float.to_string(turn)
                <> " scale="
                <> float.to_string(scale),
              )
            False -> Nil
          }

          diagnose_segment_tangent_turn_loop(
            segment,
            orientation,
            segment_index,
            sample_count: sample_count,
            sample_index: sample_index + 1,
            previous: current,
          )
        }
      }
    }
  }
}

fn segment_derivative_sample(
  segment: svg_path.Segment,
  index: Int,
  sample_count: Int,
) -> Result(svg_path.Point, svg_path.Error) {
  let t = int.to_float(index) /. int.to_float(sample_count)
  svg_path.segment_derivative(segment, at: t)
}

fn loop_orientation(segments: List(svg_path.Segment)) -> LoopOrientation {
  let vertices = loop_vertices(segments)
  let area = signed_area(vertices)
  case float.absolute_value(area) <=. point_tolerance *. point_tolerance {
    True -> DegenerateOrientation
    False ->
      case area >. 0.0 {
        True -> CounterClockwise
        False -> Clockwise
      }
  }
}

fn loop_vertices(segments: List(svg_path.Segment)) -> List(svg_path.Point) {
  case segments {
    [] -> []
    [first, ..] -> {
      let points = [
        svg_path.segment_start(first),
        ..segment_endpoints(segments)
      ]
      points
      |> remove_closing_duplicate
      |> remove_near_adjacent_duplicates
    }
  }
}

fn segment_endpoints(segments: List(svg_path.Segment)) -> List(svg_path.Point) {
  case segments {
    [] -> []
    [segment, ..rest] -> [
      svg_path.segment_end(segment),
      ..segment_endpoints(rest)
    ]
  }
}

fn remove_closing_duplicate(
  points: List(svg_path.Point),
) -> List(svg_path.Point) {
  case points {
    [] -> []
    [first, ..] -> {
      case list.last(points) {
        Ok(last) ->
          case points_near(first, last) {
            True -> drop_last(points)
            False -> points
          }
        _ -> points
      }
    }
  }
}

fn remove_near_adjacent_duplicates(
  points: List(svg_path.Point),
) -> List(svg_path.Point) {
  case points {
    [] -> []
    [first, ..rest] ->
      remove_near_adjacent_duplicates_loop(rest, previous: first, kept: [first])
  }
}

fn remove_near_adjacent_duplicates_loop(
  points: List(svg_path.Point),
  previous previous: svg_path.Point,
  kept kept: List(svg_path.Point),
) -> List(svg_path.Point) {
  case points {
    [] -> list.reverse(kept)
    [point, ..rest] -> {
      case points_near(previous, point) {
        True -> remove_near_adjacent_duplicates_loop(rest, previous:, kept:)
        False ->
          remove_near_adjacent_duplicates_loop(rest, previous: point, kept: [
            point,
            ..kept
          ])
      }
    }
  }
}

fn signed_area(points: List(svg_path.Point)) -> Float {
  case points {
    [] | [_] | [_, _] -> 0.0
    [first, ..rest] ->
      signed_area_loop(rest, first: first, previous: first, area: 0.0)
  }
}

fn signed_area_loop(
  points: List(svg_path.Point),
  first first: svg_path.Point,
  previous previous: svg_path.Point,
  area area: Float,
) -> Float {
  case points {
    [] -> { area +. cross(previous, first) } /. 2.0
    [point, ..rest] ->
      signed_area_loop(
        rest,
        first:,
        previous: point,
        area: area +. cross(previous, point),
      )
  }
}

fn turn_is_against_orientation(
  turn: Float,
  scale: Float,
  orientation: LoopOrientation,
) -> Bool {
  let tolerance = orientation_turn_tolerance *. scale
  case orientation {
    CounterClockwise -> turn <. 0.0 -. tolerance
    Clockwise -> turn >. tolerance
    DegenerateOrientation -> False
  }
}

fn points_near(a: svg_path.Point, b: svg_path.Point) -> Bool {
  point_distance_squared(a, b) <=. point_tolerance *. point_tolerance
}

fn point_distance_squared(a: svg_path.Point, b: svg_path.Point) -> Float {
  let difference = subtract(a, b)
  dot(difference, difference)
}

fn point_length(point: svg_path.Point) -> Float {
  let assert Ok(length) = float.square_root(dot(point, point))
  length
}

fn point_string(point: svg_path.Point) -> String {
  "(" <> float.to_string(point.x) <> ", " <> float.to_string(point.y) <> ")"
}

fn segment_kind(segment: svg_path.Segment) -> String {
  case segment {
    svg_path.Line(..) -> "Line"
    svg_path.QuadraticBezier(..) -> "QuadraticBezier"
    svg_path.CubicBezier(..) -> "CubicBezier"
    svg_path.Arc(..) -> "Arc"
  }
}

fn chord_tangent_value(
  segment: svg_path.Segment,
  t: Float,
  other: Float,
) -> Float {
  let assert Ok(point) = svg_path.segment_point(segment, at: t)
  let assert Ok(other_point) = svg_path.segment_point(segment, at: other)
  cross(cubic_derivative(segment, t), subtract(other_point, point))
}

fn cubic_derivative(segment: svg_path.Segment, t: Float) -> svg_path.Point {
  case segment {
    svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      let mt = 1.0 -. t
      add_points(
        add_points(
          scale_point(subtract(control1, start), 3.0 *. mt *. mt),
          scale_point(subtract(control2, control1), 6.0 *. mt *. t),
        ),
        scale_point(subtract(end, control2), 3.0 *. t *. t),
      )
    }
    _ -> svg_path.point(0.0, 0.0)
  }
}

fn add_points(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.point(a.x +. b.x, a.y +. b.y)
}

fn subtract(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.point(a.x -. b.x, a.y -. b.y)
}

fn scale_point(a: svg_path.Point, factor: Float) -> svg_path.Point {
  svg_path.point(a.x *. factor, a.y *. factor)
}

fn cross(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.y -. a.y *. b.x
}

fn quadratic_roots(a: Float, b: Float, c: Float) -> List(Float) {
  case float.absolute_value(a) <. 0.000000000001 {
    True ->
      case float.absolute_value(b) <. 0.000000000001 {
        True -> []
        False -> [{ 0.0 -. c } /. b]
      }
    False -> {
      let discriminant = b *. b -. 4.0 *. a *. c
      case discriminant <. 0.0 {
        True -> []
        False -> {
          let assert Ok(root) = float.square_root(discriminant)
          [
            { 0.0 -. b -. root } /. { 2.0 *. a },
            { 0.0 -. b +. root } /. { 2.0 *. a },
          ]
        }
      }
    }
  }
}

fn average(values: List(Float)) -> Float {
  list.fold(values, 0.0, fn(total, value) { total +. value })
  /. int.to_float(list.length(values))
}

fn angle_direction(angle: Float) -> svg_path.Point {
  let radians = angle *. maths.pi() /. 180.0
  svg_path.point(maths.cos(radians), maths.sin(radians))
}

fn dot(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.x +. a.y *. b.y
}

fn map_path_error(result: Result(a, svg_path.Error)) -> Result(a, HullError) {
  result.map_error(result, PathError)
}

fn drop_last(items: List(a)) -> List(a) {
  case items {
    [] -> []
    [_] -> []
    [first, ..rest] -> [first, ..drop_last(rest)]
  }
}

fn nth(items: List(a), index: Int) -> Result(a, Nil) {
  case items, index {
    [], _ -> Error(Nil)
    [item, ..], 0 -> Ok(item)
    [_, ..rest], _ -> nth(rest, index - 1)
  }
}
