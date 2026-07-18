//// Path offset construction.
////
//// This module follows the same basic model as `svgpathsio`: lines are offset
//// exactly, while curves are converted to cubic Beziers and approximated by
//// endpoint-normal cubics. The approximation is checked by sampling the true
//// normal extrusion of the source curve and measuring its distance to the
//// proposed offset. If the error is too large, the source curve is split and
//// each half is offset recursively. Subpath and path offsets use this segment
//// primitive, then add explicit connector geometry between adjacent offset
//// pieces.
////
//// The `*_trimmed` helpers use the same segment offset primitive, but when
//// adjacent offset pieces intersect near a corner they trim those pieces to
//// their intersection instead of always appending connector geometry. Corners
//// that do not produce a usable local intersection still fall back to the
//// requested join style.
////
//// The `*_parametric` helpers are a separate experimental track: they create a
//// single provisional offset walk by connecting adjacent segment offsets with
//// synthetic circular turn arcs, split that walk at self-intersections, remove
//// pieces that lie inside the forbidden distance tube around the original
//// subpath, then keep the remaining pieces in provisional traversal order.

import gleam/float
import gleam/int
import gleam/list
import gleam/result
import svg_path
import svg_path/trig
import vec/vec2f

const default_tolerance = 0.01

const default_max_depth = 20

const default_samples = 10

const default_miter_limit = 4.0

const tangent_epsilon = 0.000001

const point_tolerance = 0.000000001

/// Errors returned by offset helpers.
pub type Error {
  /// An underlying path operation failed.
  PathError(svg_path.Error)

  /// The offset tolerance must be greater than zero.
  InvalidTolerance(tolerance: Float)

  /// The number of divergence samples must be greater than zero.
  InvalidSamples(samples: Int)

  /// The recursive subdivision limit must be greater than zero.
  InvalidMaxDepth(max_depth: Int)

  /// The miter limit must be greater than zero.
  InvalidMiterLimit(miter_limit: Float)

  /// A segment tangent was too small to define a stable normal direction.
  DegenerateTangent(t: Float)

  /// Refinement could not produce an offset within the requested tolerance.
  MaxDepthReached(error: Float)

  /// A calculation produced a non-finite coordinate.
  NonFinite

  /// Robust offset pieces could not be stitched into closed contours.
  CannotStitchRobustOffset
}

/// Join style used when offsetting adjacent subpath segments.
pub type Join {
  /// Connect adjacent offset segments with a straight line.
  Bevel

  /// Extend the offset tangents toward their intersection when the miter stays
  /// within `miter_limit`; otherwise fall back to `Bevel`.
  Miter(miter_limit: Float)

  /// Connect adjacent offset segments with a circular SVG arc.
  Round
}

/// Options for offset construction.
pub type Options {
  Options(
    tolerance: Float,
    max_depth: Int,
    samples: Int,
    distance: svg_path.DistanceOptions,
    join: Join,
  )
}

type OffsetSegment {
  OffsetSegment(source: svg_path.Segment, offset: List(svg_path.Segment))
}

type TrimJoin {
  TrimJoin(
    left: svg_path.Segment,
    join: List(svg_path.Segment),
    right: svg_path.Segment,
  )
}

type IndexedSegment {
  IndexedSegment(index: Int, segment: svg_path.Segment)
}

type SplitParameter {
  SplitParameter(t: Float, cut: Bool)
}

type SplitPiece {
  SplitPiece(segment: svg_path.Segment, end_is_cut: Bool)
}

/// Return default options for offset construction.
pub fn default_options() -> Options {
  Options(
    tolerance: default_tolerance,
    max_depth: default_max_depth,
    samples: default_samples,
    distance: svg_path.default_distance_options(),
    join: Miter(default_miter_limit),
  )
}

/// Offset one segment by a signed distance.
///
/// Positive distances offset to the right of the segment direction. For a line
/// from `(0, 0)` to `(10, 0)`, `distance: 2.0` returns a line from `(0, -2)` to
/// `(10, -2)`.
///
/// Curves return an open subpath because the result may need several cubic
/// pieces to stay within tolerance. Arcs and quadratic Beziers are converted to
/// cubic Beziers before offsetting.
pub fn segment(
  segment: svg_path.Segment,
  distance distance: Float,
) -> Result(svg_path.Subpath, Error) {
  segment_with(segment, distance:, options: default_options())
}

/// Offset one segment by a signed distance using explicit options.
pub fn segment_with(
  segment segment: svg_path.Segment,
  distance distance: Float,
  options options: Options,
) -> Result(svg_path.Subpath, Error) {
  use _ <- result.try(validate_options(options))
  case segment {
    svg_path.Line(..) -> {
      use offset_start <- result.try(offset_point(segment, t: 0.0, distance:))
      use offset_end <- result.try(offset_point(segment, t: 1.0, distance:))
      svg_path.subpath([
        svg_path.Line(start: offset_start, end: offset_end),
      ])
      |> result.map_error(PathError)
    }
    _ -> {
      use pieces <- result.try(
        offset_cubic_segments(
          svg_path.segment_to_cubic_beziers(segment),
          distance,
          options,
          converted: [],
        ),
      )
      svg_path.subpath_with(pieces, policy: svg_path.Wiggle)
      |> result.map_error(PathError)
    }
  }
}

/// Offset a subpath by a signed distance.
///
/// Positive distances offset to the right of the subpath direction. Open
/// subpaths remain open; closed subpaths remain closed. Adjacent offset
/// segments are connected using `default_options().join`.
pub fn subpath(
  subpath: svg_path.Subpath,
  distance distance: Float,
) -> Result(svg_path.Subpath, Error) {
  subpath_with(subpath, distance:, options: default_options())
}

/// Offset a subpath by a signed distance using explicit options.
pub fn subpath_with(
  subpath subpath: svg_path.Subpath,
  distance distance: Float,
  options options: Options,
) -> Result(svg_path.Subpath, Error) {
  use _ <- result.try(validate_options(options))
  case svg_path.segments(subpath) {
    [] -> {
      use start <- result.try(
        svg_path.start(subpath) |> result.map_error(PathError),
      )
      Ok(svg_path.empty_subpath(at: start))
    }
    segments -> {
      use offset_segments <- result.try(
        offset_subpath_segments(segments, distance, options, converted: []),
      )
      use output_segments <- result.try(joined_offset_segments(
        offset_segments,
        distance,
        options,
        closed: svg_path.is_closed(subpath),
      ))

      use offset_subpath <- result.try(
        svg_path.subpath_with(output_segments, policy: svg_path.Wiggle)
        |> result.map_error(PathError),
      )

      case svg_path.is_closed(subpath) {
        False -> Ok(offset_subpath)
        True ->
          svg_path.set_closed_with(
            offset_subpath,
            closed: True,
            policy: svg_path.Wiggle,
          )
          |> result.map_error(PathError)
      }
    }
  }
}

/// Offset a subpath, trimming adjacent offset pieces when they intersect.
///
/// This variant is closer to conventional stroke/outline construction than
/// `subpath`: when the two offset pieces beside a corner cross, the pieces are
/// cropped to the crossing point. If no crossing is found, the requested join
/// style is used as a connector. Open subpaths remain open; closed subpaths
/// remain closed.
pub fn subpath_trimmed(
  subpath: svg_path.Subpath,
  distance distance: Float,
) -> Result(svg_path.Subpath, Error) {
  subpath_trimmed_with(subpath, distance:, options: default_options())
}

/// Offset a subpath with trim-aware joins using explicit options.
pub fn subpath_trimmed_with(
  subpath subpath: svg_path.Subpath,
  distance distance: Float,
  options options: Options,
) -> Result(svg_path.Subpath, Error) {
  use _ <- result.try(validate_options(options))
  case svg_path.segments(subpath) {
    [] -> {
      use start <- result.try(
        svg_path.start(subpath) |> result.map_error(PathError),
      )
      Ok(svg_path.empty_subpath(at: start))
    }
    segments -> {
      use offset_segments <- result.try(
        offset_subpath_segments(segments, distance, options, converted: []),
      )
      use output_segments <- result.try(trim_joined_offset_segments(
        offset_segments,
        distance,
        options,
        closed: svg_path.is_closed(subpath),
      ))

      use offset_subpath <- result.try(
        svg_path.subpath_with(output_segments, policy: svg_path.Wiggle)
        |> result.map_error(PathError),
      )

      case svg_path.is_closed(subpath) {
        False -> Ok(offset_subpath)
        True ->
          svg_path.set_closed_with(
            offset_subpath,
            closed: True,
            policy: svg_path.Wiggle,
          )
          |> result.map_error(PathError)
      }
    }
  }
}

/// Offset a closed subpath using trim and validity pruning.
///
/// This variant first builds the local trim-aware offset, splits it at
/// self-intersections, removes pieces that are closer to the original subpath
/// than the requested offset distance or that lie on the wrong fill side, then
/// stitches the remaining pieces into closed contours. It returns a `Path`
/// because a robust inset can split into multiple contours or disappear.
///
/// Open subpaths are offset with `subpath_trimmed_with` and wrapped in a path;
/// the global pruning/stitching pass is only applied to closed subpaths.
pub fn subpath_robust(
  subpath: svg_path.Subpath,
  distance distance: Float,
) -> Result(svg_path.Path, Error) {
  subpath_robust_with(subpath, distance:, options: default_options())
}

/// Offset a subpath with robust trim pruning using explicit options.
pub fn subpath_robust_with(
  subpath subpath: svg_path.Subpath,
  distance distance: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use trimmed <- result.try(subpath_trimmed_with(subpath, distance:, options:))
  case svg_path.is_closed(subpath) {
    False -> Ok(svg_path.from_subpath(trimmed))
    True -> robust_closed_subpath(subpath, trimmed, distance, options)
  }
}

/// Offset a subpath as an ordered one-sided parametric walk.
///
/// Adjacent segment offsets are connected by synthetic circular turn arcs so
/// the provisional offset is continuous. Those synthetic turns are only
/// construction geometry: validity is measured against the original subpath.
/// After splitting the provisional walk at self-intersections, pieces whose
/// samples are all closer to the original subpath than `abs(distance)` are
/// removed. The surviving pieces are returned as zero or more ordered subpaths.
pub fn subpath_parametric(
  subpath: svg_path.Subpath,
  distance distance: Float,
) -> Result(svg_path.Path, Error) {
  subpath_parametric_with(subpath, distance:, options: default_options())
}

/// Offset a subpath as an ordered one-sided parametric walk using explicit
/// options.
pub fn subpath_parametric_with(
  subpath subpath: svg_path.Subpath,
  distance distance: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use provisional <- result.try(parametric_provisional_subpath(
    subpath,
    distance,
    options,
  ))
  parametric_pruned_subpath(subpath, provisional, distance, options)
}

/// Offset every subpath in a path by a signed distance.
pub fn path(
  path: svg_path.Path,
  distance distance: Float,
) -> Result(svg_path.Path, Error) {
  path_with(path, distance:, options: default_options())
}

/// Offset every subpath in a path by a signed distance using explicit options.
pub fn path_with(
  path path: svg_path.Path,
  distance distance: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use subpaths <- result.try(
    offset_path_subpaths(
      svg_path.subpaths(path),
      distance,
      options,
      converted: [],
    ),
  )
  Ok(svg_path.Path(subpaths:))
}

/// Offset every subpath in a path using trim-aware joins.
pub fn path_trimmed(
  path: svg_path.Path,
  distance distance: Float,
) -> Result(svg_path.Path, Error) {
  path_trimmed_with(path, distance:, options: default_options())
}

/// Offset every subpath in a path using trim-aware joins and explicit options.
pub fn path_trimmed_with(
  path path: svg_path.Path,
  distance distance: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use subpaths <- result.try(
    trim_offset_path_subpaths(
      svg_path.subpaths(path),
      distance,
      options,
      converted: [],
    ),
  )
  Ok(svg_path.Path(subpaths:))
}

/// Offset every subpath in a path using robust trim pruning.
pub fn path_robust(
  path: svg_path.Path,
  distance distance: Float,
) -> Result(svg_path.Path, Error) {
  path_robust_with(path, distance:, options: default_options())
}

/// Offset every subpath in a path using robust trim pruning and explicit options.
pub fn path_robust_with(
  path path: svg_path.Path,
  distance distance: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use subpaths <- result.try(
    robust_offset_path_subpaths(
      svg_path.subpaths(path),
      distance,
      options,
      converted: [],
    ),
  )
  Ok(svg_path.Path(subpaths:))
}

/// Offset every subpath in a path as ordered one-sided parametric walks.
pub fn path_parametric(
  path: svg_path.Path,
  distance distance: Float,
) -> Result(svg_path.Path, Error) {
  path_parametric_with(path, distance:, options: default_options())
}

/// Offset every subpath in a path as ordered one-sided parametric walks using
/// explicit options.
pub fn path_parametric_with(
  path path: svg_path.Path,
  distance distance: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use subpaths <- result.try(
    parametric_offset_path_subpaths(
      svg_path.subpaths(path),
      distance,
      options,
      converted: [],
    ),
  )
  Ok(svg_path.Path(subpaths:))
}

fn validate_options(options: Options) -> Result(Nil, Error) {
  case options.tolerance <=. 0.0 {
    True -> Error(InvalidTolerance(options.tolerance))
    False ->
      case options.samples <= 0 {
        True -> Error(InvalidSamples(options.samples))
        False ->
          case options.max_depth <= 0 {
            True -> Error(InvalidMaxDepth(options.max_depth))
            False -> validate_join(options.join)
          }
      }
  }
}

fn validate_join(join: Join) -> Result(Nil, Error) {
  case join {
    Miter(miter_limit) if miter_limit <=. 0.0 ->
      Error(InvalidMiterLimit(miter_limit))
    Bevel | Miter(..) | Round -> Ok(Nil)
  }
}

fn offset_path_subpaths(
  subpaths: List(svg_path.Subpath),
  distance: Float,
  options: Options,
  converted converted: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use offset <- result.try(subpath_with(first, distance:, options:))
      offset_path_subpaths(rest, distance, options, converted: [
        offset,
        ..converted
      ])
    }
  }
}

fn trim_offset_path_subpaths(
  subpaths: List(svg_path.Subpath),
  distance: Float,
  options: Options,
  converted converted: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use offset <- result.try(subpath_trimmed_with(first, distance:, options:))
      trim_offset_path_subpaths(rest, distance, options, converted: [
        offset,
        ..converted
      ])
    }
  }
}

fn robust_offset_path_subpaths(
  subpaths: List(svg_path.Subpath),
  distance: Float,
  options: Options,
  converted converted: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use offset <- result.try(subpath_robust_with(first, distance:, options:))
      robust_offset_path_subpaths(
        rest,
        distance,
        options,
        converted: list.append(
          list.reverse(svg_path.subpaths(offset)),
          converted,
        ),
      )
    }
  }
}

fn parametric_offset_path_subpaths(
  subpaths: List(svg_path.Subpath),
  distance: Float,
  options: Options,
  converted converted: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use offset <- result.try(subpath_parametric_with(
        first,
        distance:,
        options:,
      ))
      parametric_offset_path_subpaths(
        rest,
        distance,
        options,
        converted: list.append(
          list.reverse(svg_path.subpaths(offset)),
          converted,
        ),
      )
    }
  }
}

fn parametric_provisional_subpath(
  subpath: svg_path.Subpath,
  distance: Float,
  options: Options,
) -> Result(svg_path.Subpath, Error) {
  case svg_path.segments(subpath) {
    [] -> {
      use start <- result.try(
        svg_path.start(subpath) |> result.map_error(PathError),
      )
      Ok(svg_path.empty_subpath(at: start))
    }
    segments -> {
      use offset_segments <- result.try(
        offset_subpath_segments(segments, distance, options, converted: []),
      )
      use output_segments <- result.try(parametric_joined_offset_segments(
        offset_segments,
        distance,
        closed: svg_path.is_closed(subpath),
      ))
      use provisional <- result.try(
        svg_path.subpath_with(output_segments, policy: svg_path.Wiggle)
        |> result.map_error(PathError),
      )
      case svg_path.is_closed(subpath) {
        False -> Ok(provisional)
        True ->
          svg_path.set_closed_with(
            provisional,
            closed: True,
            policy: svg_path.Wiggle,
          )
          |> result.map_error(PathError)
      }
    }
  }
}

fn parametric_joined_offset_segments(
  offsets: List(OffsetSegment),
  distance: Float,
  closed closed: Bool,
) -> Result(List(svg_path.Segment), Error) {
  case offsets {
    [] -> Ok([])
    [first, ..rest] ->
      parametric_joined_offset_segments_loop(
        first,
        first,
        rest,
        distance,
        closed:,
        segments: first.offset,
      )
  }
}

fn parametric_joined_offset_segments_loop(
  first: OffsetSegment,
  previous: OffsetSegment,
  rest: List(OffsetSegment),
  distance: Float,
  closed closed: Bool,
  segments segments: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), Error) {
  case rest {
    [] -> {
      case closed {
        False -> Ok(segments)
        True -> {
          use turn <- result.try(synthetic_turn(previous, first, distance))
          Ok(list.append(segments, turn))
        }
      }
    }
    [next, ..remaining] -> {
      use turn <- result.try(synthetic_turn(previous, next, distance))
      parametric_joined_offset_segments_loop(
        first,
        next,
        remaining,
        distance,
        closed:,
        segments: list.append(segments, list.append(turn, next.offset)),
      )
    }
  }
}

fn synthetic_turn(
  left: OffsetSegment,
  right: OffsetSegment,
  distance: Float,
) -> Result(List(svg_path.Segment), Error) {
  use left_offset <- result.try(last_offset_segment(left))
  use right_offset <- result.try(first_offset_segment(right))
  let start = svg_path.segment_end(left_offset)
  let end = svg_path.segment_start(right_offset)
  case points_near(start, end) {
    True -> Ok([])
    False -> round_join(left, right, start, end, distance)
  }
}

fn parametric_pruned_subpath(
  source: svg_path.Subpath,
  provisional: svg_path.Subpath,
  distance: Float,
  options: Options,
) -> Result(svg_path.Path, Error) {
  use sections <- result.try(parametric_self_intersection_sections(
    provisional,
    svg_path.default_intersection_options(),
    options.tolerance,
  ))
  use retained <- result.try(
    retain_parametric_sections(
      sections,
      source:,
      distance:,
      options:,
      retained: [],
    ),
  )
  let retained = merge_touching_chunks(retained, options.tolerance)
  use subpaths <- result.try(chunks_to_subpaths(
    retained,
    options.tolerance,
    closed: svg_path.is_closed(source),
  ))
  Ok(svg_path.Path(subpaths:))
}

fn parametric_self_intersection_sections(
  subpath: svg_path.Subpath,
  intersection_options: svg_path.IntersectionOptions,
  tolerance: Float,
) -> Result(List(List(svg_path.Segment)), Error) {
  let segments = svg_path.segments(subpath)
  let indexed = indexed_segments(segments, index: 0, indexed: [])
  let closed = svg_path.is_closed(subpath)
  use sections <- result.try(split_parametric_indexed_segments(
    indexed,
    indexed,
    intersection_options,
    tolerance,
    total: list.length(indexed),
    closed:,
    current: [],
    sections: [],
  ))
  let sections = case closed {
    True -> merge_wrapping_chunks(sections, tolerance)
    False -> sections
  }
  Ok(sections)
}

fn split_parametric_indexed_segments(
  segments: List(IndexedSegment),
  all: List(IndexedSegment),
  intersection_options: svg_path.IntersectionOptions,
  tolerance: Float,
  total total: Int,
  closed closed: Bool,
  current current: List(svg_path.Segment),
  sections sections: List(List(svg_path.Segment)),
) -> Result(List(List(svg_path.Segment)), Error) {
  case segments {
    [] -> {
      case current {
        [] -> Ok(list.reverse(sections))
        _ -> Ok(list.reverse([list.reverse(current), ..sections]))
      }
    }
    [first, ..rest] -> {
      use parameters <- result.try(parametric_split_parameters(
        first,
        all,
        intersection_options,
        tolerance,
        total:,
        closed:,
        parameters: [SplitParameter(0.0, False), SplitParameter(1.0, False)],
      ))
      use pieces <- result.try(split_parametric_piece(first.segment, parameters))
      let #(current, sections) =
        append_split_pieces(pieces, current: current, sections: sections)
      split_parametric_indexed_segments(
        rest,
        all,
        intersection_options,
        tolerance,
        total:,
        closed:,
        current:,
        sections:,
      )
    }
  }
}

fn parametric_split_parameters(
  segment: IndexedSegment,
  all: List(IndexedSegment),
  intersection_options: svg_path.IntersectionOptions,
  tolerance: Float,
  total total: Int,
  closed closed: Bool,
  parameters parameters: List(SplitParameter),
) -> Result(List(SplitParameter), Error) {
  let IndexedSegment(index:, segment: left) = segment
  case all {
    [] ->
      Ok(
        parameters
        |> list.sort(by: fn(a, b) {
          let SplitParameter(t: left, cut: _) = a
          let SplitParameter(t: right, cut: _) = b
          float.compare(left, right)
        })
        |> unique_split_parameters(tolerance, []),
      )
    [IndexedSegment(index: other_index, segment: right), ..rest] -> {
      case other_index == index {
        True ->
          parametric_split_parameters(
            segment,
            rest,
            intersection_options,
            tolerance,
            total:,
            closed:,
            parameters:,
          )
        False -> {
          use parameters <- result.try(
            case
              svg_path.segment_intersections_with(
                left,
                right,
                options: intersection_options,
              )
            {
              Ok(intersections) ->
                Ok(add_parametric_split_parameters(
                  parameters,
                  intersections,
                  index,
                  other_index,
                  total:,
                  closed:,
                ))
              Error(svg_path.OverlappingSegments) ->
                overlapping_line_split_parameters(left, right, parameters)
                |> result.map_error(fn(error) { PathError(error) })
              Error(error) -> Error(PathError(error))
            },
          )
          parametric_split_parameters(
            segment,
            rest,
            intersection_options,
            tolerance,
            total:,
            closed:,
            parameters:,
          )
        }
      }
    }
  }
}

fn add_parametric_split_parameters(
  parameters: List(SplitParameter),
  intersections: List(svg_path.SegmentIntersection),
  left_index: Int,
  right_index: Int,
  total total: Int,
  closed closed: Bool,
) -> List(SplitParameter) {
  list.fold(intersections, parameters, fn(parameters, intersection) {
    case
      is_parametric_adjacent_endpoint_intersection(
        intersection,
        left_index,
        right_index,
        total:,
        closed:,
      )
    {
      True -> parameters
      False -> [SplitParameter(clamp01(intersection.left_t), True), ..parameters]
    }
  })
}

fn is_parametric_adjacent_endpoint_intersection(
  intersection: svg_path.SegmentIntersection,
  left_index: Int,
  right_index: Int,
  total total: Int,
  closed closed: Bool,
) -> Bool {
  is_adjacent_endpoint_intersection(intersection, left_index, right_index)
  || {
    closed
    && total > 1
    && left_index == 0
    && right_index == total - 1
    && intersection.left_t <=. point_tolerance
    && intersection.right_t >=. 1.0 -. point_tolerance
  }
  || {
    closed
    && total > 1
    && right_index == 0
    && left_index == total - 1
    && intersection.left_t >=. 1.0 -. point_tolerance
    && intersection.right_t <=. point_tolerance
  }
}

fn overlapping_line_split_parameters(
  segment: svg_path.Segment,
  against: svg_path.Segment,
  parameters: List(SplitParameter),
) -> Result(List(SplitParameter), svg_path.Error) {
  case overlapping_line_parameters(segment, against, []) {
    Ok(ts) ->
      Ok(list.fold(ts, parameters, fn(parameters, t) {
        [SplitParameter(t, True), ..parameters]
      }))
    Error(error) -> Error(error)
  }
}

fn unique_split_parameters(
  values: List(SplitParameter),
  tolerance: Float,
  unique unique: List(SplitParameter),
) -> List(SplitParameter) {
  case values {
    [] -> list.reverse(unique)
    [first, ..rest] -> {
      let SplitParameter(t: first_t, cut: first_cut) = first
      case unique {
        [previous, ..previous_rest] -> {
          let SplitParameter(t: previous_t, cut: previous_cut) = previous
          case float.absolute_value(first_t -. previous_t) <=. tolerance {
            True ->
              unique_split_parameters(rest, tolerance, unique: [
                SplitParameter(previous_t, first_cut || previous_cut),
                ..previous_rest
              ])
            False ->
              unique_split_parameters(rest, tolerance, unique: [first, ..unique])
          }
        }
        _ -> unique_split_parameters(rest, tolerance, unique: [first])
      }
    }
  }
}

fn split_parametric_piece(
  segment: svg_path.Segment,
  parameters: List(SplitParameter),
) -> Result(List(SplitPiece), Error) {
  case parameters {
    [] | [_] -> Ok([])
    [from, to, ..rest] -> {
      let SplitParameter(t: from_t, cut: _) = from
      let SplitParameter(t: to_t, cut: to_cut) = to
      use piece <- result.try(
        svg_path.segments_between_inside(segment, between: [from_t, to_t])
        |> result.map_error(PathError),
      )
      use pieces <- result.try(split_parametric_piece(segment, [to, ..rest]))
      Ok(list.append(
        piece |> list.map(fn(segment) { SplitPiece(segment, end_is_cut: to_cut) }),
        pieces,
      ))
    }
  }
}

fn append_split_pieces(
  pieces: List(SplitPiece),
  current current: List(svg_path.Segment),
  sections sections: List(List(svg_path.Segment)),
) -> #(List(svg_path.Segment), List(List(svg_path.Segment))) {
  case pieces {
    [] -> #(current, sections)
    [SplitPiece(segment:, end_is_cut:), ..rest] -> {
      let current = [segment, ..current]
      case end_is_cut {
        True ->
          append_split_pieces(
            rest,
            current: [],
            sections: [list.reverse(current), ..sections],
          )
        False -> append_split_pieces(rest, current:, sections:)
      }
    }
  }
}

fn retain_parametric_sections(
  sections: List(List(svg_path.Segment)),
  source source: svg_path.Subpath,
  distance distance: Float,
  options options: Options,
  retained retained: List(List(svg_path.Segment)),
) -> Result(List(List(svg_path.Segment)), Error) {
  case sections {
    [] -> Ok(list.reverse(retained))
    [first, ..rest] -> {
      use keep <- result.try(parametric_section_is_valid(
        first,
        source:,
        distance:,
        options:,
      ))
      let retained = case keep {
        True -> [first, ..retained]
        False -> retained
      }
      retain_parametric_sections(rest, source:, distance:, options:, retained:)
    }
  }
}

fn parametric_section_is_valid(
  section: List(svg_path.Segment),
  source source: svg_path.Subpath,
  distance distance: Float,
  options options: Options,
) -> Result(Bool, Error) {
  case section {
    [] -> Ok(False)
    [first, ..rest] -> {
      use valid <- result.try(parametric_piece_has_non_negative_sample(
        first,
        [0.2, 0.5, 0.8],
        source:,
        distance:,
        options:,
      ))
      case valid {
        True -> Ok(True)
        False ->
          parametric_section_is_valid(rest, source:, distance:, options:)
      }
    }
  }
}

fn parametric_piece_has_non_negative_sample(
  piece: svg_path.Segment,
  samples: List(Float),
  source source: svg_path.Subpath,
  distance distance: Float,
  options options: Options,
) -> Result(Bool, Error) {
  case samples {
    [] -> Ok(False)
    [first, ..rest] -> {
      use point <- result.try(
        svg_path.segment_point(piece, at: first) |> result.map_error(PathError),
      )
      use is_non_negative <- result.try(parametric_point_is_non_negative(
        point,
        source:,
        distance:,
        options:,
      ))
      case is_non_negative {
        True -> Ok(True)
        False ->
          parametric_piece_has_non_negative_sample(
            piece,
            rest,
            source:,
            distance:,
            options:,
          )
      }
    }
  }
}

fn parametric_point_is_non_negative(
  point: svg_path.Point,
  source source: svg_path.Subpath,
  distance distance: Float,
  options options: Options,
) -> Result(Bool, Error) {
  let margin = options.tolerance *. 8.0 +. point_tolerance
  use projection <- result.try(
    svg_path.subpath_projection_with(
      point,
      to: source,
      options: options.distance,
    )
    |> result.map_error(PathError),
  )
  Ok(projection.distance +. margin >=. float.absolute_value(distance))
}

fn merge_touching_chunks(
  chunks: List(List(svg_path.Segment)),
  tolerance: Float,
) -> List(List(svg_path.Segment)) {
  case chunks {
    [] | [_] -> chunks
    [first, second, ..rest] -> {
      case chunks_touch(first, second, tolerance) {
        True ->
          merge_touching_chunks([list.append(first, second), ..rest], tolerance)
        False -> [first, ..merge_touching_chunks([second, ..rest], tolerance)]
      }
    }
  }
}

fn chunks_to_subpaths(
  chunks: List(List(svg_path.Segment)),
  tolerance: Float,
  closed closed: Bool,
) -> Result(List(svg_path.Subpath), Error) {
  let chunks = case closed {
    True -> merge_wrapping_chunks(chunks, tolerance)
    False -> chunks
  }
  chunks_to_subpaths_loop(chunks, tolerance, closed:, subpaths: [])
}

fn chunks_to_subpaths_loop(
  chunks: List(List(svg_path.Segment)),
  tolerance: Float,
  closed closed: Bool,
  subpaths subpaths: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case chunks {
    [] -> Ok(list.reverse(subpaths))
    [first, ..rest] -> {
      let close = closed_chunk(first, tolerance) && closed
      use first <- result.try(normalize_chunk(first, tolerance))
      let first = case close {
        True -> snap_chunk_end_to_start(first)
        False -> first
      }
      use subpath <- result.try(
        svg_path.subpath_with(first, policy: svg_path.Wiggle)
        |> result.map_error(PathError),
      )
      use subpath <- result.try(case close {
        True ->
          svg_path.set_closed_with(
            subpath,
            closed: True,
            policy: svg_path.Wiggle,
          )
          |> result.map_error(PathError)
        False -> Ok(subpath)
      })
      chunks_to_subpaths_loop(rest, tolerance, closed:, subpaths: [
        subpath,
        ..subpaths
      ])
    }
  }
}

fn normalize_chunk(
  chunk: List(svg_path.Segment),
  tolerance: Float,
) -> Result(List(svg_path.Segment), Error) {
  case chunk {
    [] -> Ok([])
    [first, ..rest] ->
      normalize_chunk_loop(rest, tolerance, previous: first, normalized: [first])
  }
}

fn normalize_chunk_loop(
  rest: List(svg_path.Segment),
  tolerance: Float,
  previous previous: svg_path.Segment,
  normalized normalized: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), Error) {
  case rest {
    [] -> Ok(list.reverse(normalized))
    [first, ..remaining] -> {
      let previous_end = svg_path.segment_end(previous)
      let first = case
        same_point(previous_end, svg_path.segment_start(first), tolerance)
      {
        True -> snap_segment_start(first, previous_end)
        False -> first
      }
      normalize_chunk_loop(remaining, tolerance, previous: first, normalized: [
        first,
        ..normalized
      ])
    }
  }
}

fn snap_chunk_end_to_start(
  chunk: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case chunk {
    [] -> []
    [first, ..] -> {
      let start = svg_path.segment_start(first)
      let assert Ok(last) = list.last(chunk)
      replace_last_segment_unchecked(chunk, snap_segment_end(last, start))
    }
  }
}

fn replace_last_segment_unchecked(
  segments: List(svg_path.Segment),
  replacement: svg_path.Segment,
) -> List(svg_path.Segment) {
  case segments {
    [] -> []
    [_] -> [replacement]
    [first, ..rest] -> [
      first,
      ..replace_last_segment_unchecked(rest, replacement)
    ]
  }
}

fn snap_segment_start(
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

fn snap_segment_end(
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

fn merge_wrapping_chunks(
  chunks: List(List(svg_path.Segment)),
  tolerance: Float,
) -> List(List(svg_path.Segment)) {
  case chunks {
    [] | [_] -> chunks
    [first, ..rest] -> {
      let assert Ok(last) = list.last(rest)
      case chunks_touch(last, first, tolerance) {
        True -> {
          let rest_without_last = drop_last(rest)
          [list.append(last, first), ..rest_without_last]
        }
        False -> chunks
      }
    }
  }
}

fn chunks_touch(
  left: List(svg_path.Segment),
  right: List(svg_path.Segment),
  tolerance: Float,
) -> Bool {
  case list.last(left), right {
    Ok(left_last), [right_first, ..] ->
      same_point(
        svg_path.segment_end(left_last),
        svg_path.segment_start(right_first),
        tolerance,
      )
    _, _ -> False
  }
}

fn closed_chunk(chunk: List(svg_path.Segment), tolerance: Float) -> Bool {
  case chunk, list.last(chunk) {
    [first, ..], Ok(last) ->
      same_point(
        svg_path.segment_start(first),
        svg_path.segment_end(last),
        tolerance,
      )
    _, _ -> False
  }
}

fn drop_last(items: List(a)) -> List(a) {
  case items {
    [] | [_] -> []
    [first, ..rest] -> [first, ..drop_last(rest)]
  }
}

fn robust_closed_subpath(
  source: svg_path.Subpath,
  provisional: svg_path.Subpath,
  distance: Float,
  options: Options,
) -> Result(svg_path.Path, Error) {
  use target <- result.try(target_containment(source, provisional))
  use pieces <- result.try(
    split_self_intersections(
      provisional,
      svg_path.default_intersection_options(),
      options.tolerance,
    )
    |> result.map_error(PathError),
  )
  use retained <- result.try(
    retain_robust_pieces(
      pieces,
      source:,
      distance:,
      target:,
      options:,
      retained: [],
    ),
  )
  use contours <- result.try(stitch_closed_pieces(retained, options.tolerance))
  Ok(svg_path.Path(subpaths: contours))
}

fn target_containment(
  source: svg_path.Subpath,
  provisional: svg_path.Subpath,
) -> Result(svg_path.PointContainment, Error) {
  target_containment_loop(svg_path.segments(provisional), source)
}

fn target_containment_loop(
  segments: List(svg_path.Segment),
  source: svg_path.Subpath,
) -> Result(svg_path.PointContainment, Error) {
  case segments {
    [] -> Error(CannotStitchRobustOffset)
    [first, ..rest] -> {
      use midpoint <- result.try(
        svg_path.segment_point(first, at: 0.5) |> result.map_error(PathError),
      )
      use containment <- result.try(
        svg_path.subpath_containment(
          midpoint,
          within: source,
          using: svg_path.Nonzero,
        )
        |> result.map_error(PathError),
      )
      case containment {
        svg_path.Boundary -> target_containment_loop(rest, source)
        _ -> Ok(containment)
      }
    }
  }
}

fn split_self_intersections(
  subpath: svg_path.Subpath,
  intersection_options: svg_path.IntersectionOptions,
  tolerance: Float,
) -> Result(List(svg_path.Segment), svg_path.Error) {
  let indexed =
    indexed_segments(svg_path.segments(subpath), index: 0, indexed: [])
  split_indexed_segments(indexed, indexed, intersection_options, tolerance, [])
}

fn indexed_segments(
  segments: List(svg_path.Segment),
  index index: Int,
  indexed indexed: List(IndexedSegment),
) -> List(IndexedSegment) {
  case segments {
    [] -> list.reverse(indexed)
    [first, ..rest] ->
      indexed_segments(rest, index: index + 1, indexed: [
        IndexedSegment(index:, segment: first),
        ..indexed
      ])
  }
}

fn split_indexed_segments(
  segments: List(IndexedSegment),
  all: List(IndexedSegment),
  intersection_options: svg_path.IntersectionOptions,
  tolerance: Float,
  split split: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), svg_path.Error) {
  case segments {
    [] -> Ok(list.reverse(split))
    [first, ..rest] -> {
      use ts <- result.try(
        self_split_parameters(first, all, intersection_options, [0.0, 1.0]),
      )
      let ts =
        ts |> list.sort(by: float.compare) |> unique_floats(tolerance, [])
      use pieces <- result.try(svg_path.segments_between_inside(
        first.segment,
        between: ts,
      ))
      split_indexed_segments(
        rest,
        all,
        intersection_options,
        tolerance,
        split: list.append(list.reverse(pieces), split),
      )
    }
  }
}

fn self_split_parameters(
  segment: IndexedSegment,
  all: List(IndexedSegment),
  intersection_options: svg_path.IntersectionOptions,
  parameters: List(Float),
) -> Result(List(Float), svg_path.Error) {
  let IndexedSegment(index:, segment: left) = segment
  case all {
    [] -> Ok(parameters)
    [IndexedSegment(index: other_index, segment: right), ..rest] -> {
      case other_index == index {
        True ->
          self_split_parameters(segment, rest, intersection_options, parameters)
        False -> {
          use parameters <- result.try(
            case
              svg_path.segment_intersections_with(
                left,
                right,
                options: intersection_options,
              )
            {
              Ok(intersections) ->
                Ok(add_self_intersection_parameters(
                  parameters,
                  intersections,
                  index,
                  other_index,
                ))
              Error(svg_path.OverlappingSegments) ->
                overlapping_line_parameters(left, right, parameters)
              Error(error) -> Error(error)
            },
          )
          self_split_parameters(segment, rest, intersection_options, parameters)
        }
      }
    }
  }
}

fn add_self_intersection_parameters(
  parameters: List(Float),
  intersections: List(svg_path.SegmentIntersection),
  left_index: Int,
  right_index: Int,
) -> List(Float) {
  list.fold(intersections, parameters, fn(parameters, intersection) {
    case
      is_adjacent_endpoint_intersection(intersection, left_index, right_index)
    {
      True -> parameters
      False -> [clamp01(intersection.left_t), ..parameters]
    }
  })
}

fn is_adjacent_endpoint_intersection(
  intersection: svg_path.SegmentIntersection,
  left_index: Int,
  right_index: Int,
) -> Bool {
  {
    right_index == left_index + 1
    && intersection.left_t >=. 1.0 -. point_tolerance
    && intersection.right_t <=. point_tolerance
  }
  || {
    left_index == right_index + 1
    && intersection.left_t <=. point_tolerance
    && intersection.right_t >=. 1.0 -. point_tolerance
  }
}

fn overlapping_line_parameters(
  segment: svg_path.Segment,
  against: svg_path.Segment,
  parameters: List(Float),
) -> Result(List(Float), svg_path.Error) {
  case segment, against {
    svg_path.Line(start: left_start, end: left_end),
      svg_path.Line(start: right_start, end: right_end)
    -> {
      let dx = left_end.x -. left_start.x
      let dy = left_end.y -. left_start.y
      case dx == 0.0 && dy == 0.0 {
        True -> Ok(parameters)
        False -> {
          let t0 = line_parameter(left_start, dx, dy, right_start)
          let t1 = line_parameter(left_start, dx, dy, right_end)
          Ok([clamp01(t0), clamp01(t1), ..parameters])
        }
      }
    }
    _, _ -> Error(svg_path.OverlappingSegments)
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

fn unique_floats(
  values: List(Float),
  tolerance: Float,
  unique unique: List(Float),
) -> List(Float) {
  case values {
    [] -> list.reverse(unique)
    [first, ..rest] -> {
      case unique {
        [previous, ..] -> {
          case float.absolute_value(first -. previous) <=. tolerance {
            True -> unique_floats(rest, tolerance, unique:)
            False -> unique_floats(rest, tolerance, unique: [first, ..unique])
          }
        }
        _ -> unique_floats(rest, tolerance, unique: [first, ..unique])
      }
    }
  }
}

fn clamp01(value: Float) -> Float {
  float.min(1.0, float.max(0.0, value))
}

fn same_point(a: svg_path.Point, b: svg_path.Point, tolerance: Float) -> Bool {
  vec2f.distance_squared(a, with: b) <=. tolerance *. tolerance
}

fn retain_robust_pieces(
  pieces: List(svg_path.Segment),
  source source: svg_path.Subpath,
  distance distance: Float,
  target target: svg_path.PointContainment,
  options options: Options,
  retained retained: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), Error) {
  case pieces {
    [] -> Ok(list.reverse(retained))
    [first, ..rest] -> {
      use keep <- result.try(robust_piece_is_valid(
        first,
        source:,
        distance:,
        target:,
        options:,
      ))
      let retained = case keep {
        True -> [first, ..retained]
        False -> retained
      }
      retain_robust_pieces(
        rest,
        source:,
        distance:,
        target:,
        options:,
        retained:,
      )
    }
  }
}

fn robust_piece_is_valid(
  piece: svg_path.Segment,
  source source: svg_path.Subpath,
  distance distance: Float,
  target target: svg_path.PointContainment,
  options options: Options,
) -> Result(Bool, Error) {
  robust_piece_samples_valid(
    piece,
    [0.25, 0.5, 0.75],
    source:,
    distance:,
    target:,
    options:,
  )
}

fn robust_piece_samples_valid(
  piece: svg_path.Segment,
  samples: List(Float),
  source source: svg_path.Subpath,
  distance distance: Float,
  target target: svg_path.PointContainment,
  options options: Options,
) -> Result(Bool, Error) {
  case samples {
    [] -> Ok(True)
    [first, ..rest] -> {
      use point <- result.try(
        svg_path.segment_point(piece, at: first) |> result.map_error(PathError),
      )
      use valid <- result.try(robust_point_is_valid(
        point,
        source:,
        distance:,
        target:,
        options:,
      ))
      case valid {
        False -> Ok(False)
        True ->
          robust_piece_samples_valid(
            piece,
            rest,
            source:,
            distance:,
            target:,
            options:,
          )
      }
    }
  }
}

fn robust_point_is_valid(
  point: svg_path.Point,
  source source: svg_path.Subpath,
  distance distance: Float,
  target target: svg_path.PointContainment,
  options options: Options,
) -> Result(Bool, Error) {
  let margin = options.tolerance *. 8.0 +. point_tolerance
  use projection <- result.try(
    svg_path.subpath_projection_with(
      point,
      to: source,
      options: options.distance,
    )
    |> result.map_error(PathError),
  )
  use containment <- result.try(
    svg_path.subpath_containment(point, within: source, using: svg_path.Nonzero)
    |> result.map_error(PathError),
  )
  Ok(
    projection.distance +. margin >=. float.absolute_value(distance)
    && containment == target,
  )
}

fn stitch_closed_pieces(
  pieces: List(svg_path.Segment),
  tolerance: Float,
) -> Result(List(svg_path.Subpath), Error) {
  stitch_closed_pieces_loop(pieces, tolerance, contours: [])
}

fn stitch_closed_pieces_loop(
  pieces: List(svg_path.Segment),
  tolerance: Float,
  contours contours: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case pieces {
    [] -> Ok(list.reverse(contours))
    [first, ..rest] -> {
      use contour <- result.try(
        stitch_one_contour(first, rest, tolerance, chain: [first]),
      )
      let #(subpath, remaining) = contour
      stitch_closed_pieces_loop(remaining, tolerance, contours: [
        subpath,
        ..contours
      ])
    }
  }
}

fn stitch_one_contour(
  first: svg_path.Segment,
  remaining: List(svg_path.Segment),
  tolerance: Float,
  chain chain: List(svg_path.Segment),
) -> Result(#(svg_path.Subpath, List(svg_path.Segment)), Error) {
  use last <- result.try(last_segment(chain))
  let chain_start = svg_path.segment_start(first)
  let chain_end = svg_path.segment_end(last)
  case same_point(chain_start, chain_end, tolerance) {
    True -> {
      use subpath <- result.try(
        svg_path.subpath_with(chain, policy: svg_path.Wiggle)
        |> result.map_error(PathError),
      )
      use subpath <- result.try(
        svg_path.set_closed_with(subpath, closed: True, policy: svg_path.Wiggle)
        |> result.map_error(PathError),
      )
      Ok(#(subpath, remaining))
    }
    False -> {
      use match <- result.try(take_unique_next_segment(
        remaining,
        after: chain_end,
        tolerance:,
      ))
      let #(next, rest) = match
      stitch_one_contour(
        first,
        rest,
        tolerance,
        chain: list.append(chain, [next]),
      )
    }
  }
}

fn take_unique_next_segment(
  segments: List(svg_path.Segment),
  after point: svg_path.Point,
  tolerance tolerance: Float,
) -> Result(#(svg_path.Segment, List(svg_path.Segment)), Error) {
  take_unique_next_segment_loop(
    segments,
    after: point,
    tolerance:,
    prefix: [],
    found: [],
  )
}

fn take_unique_next_segment_loop(
  segments: List(svg_path.Segment),
  after point: svg_path.Point,
  tolerance tolerance: Float,
  prefix prefix: List(svg_path.Segment),
  found found: List(#(svg_path.Segment, List(svg_path.Segment))),
) -> Result(#(svg_path.Segment, List(svg_path.Segment)), Error) {
  case segments {
    [] -> {
      case found {
        [match] -> Ok(match)
        [] | [_, ..] -> Error(CannotStitchRobustOffset)
      }
    }
    [first, ..rest] -> {
      let found = case
        same_point(svg_path.segment_start(first), point, tolerance)
      {
        True -> [#(first, list.append(list.reverse(prefix), rest)), ..found]
        False -> found
      }
      take_unique_next_segment_loop(
        rest,
        after: point,
        tolerance:,
        prefix: [first, ..prefix],
        found:,
      )
    }
  }
}

fn offset_subpath_segments(
  segments: List(svg_path.Segment),
  distance: Float,
  options: Options,
  converted converted: List(OffsetSegment),
) -> Result(List(OffsetSegment), Error) {
  case segments {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use offset <- result.try(segment_with(first, distance:, options:))
      offset_subpath_segments(rest, distance, options, converted: [
        OffsetSegment(source: first, offset: svg_path.segments(offset)),
        ..converted
      ])
    }
  }
}

fn joined_offset_segments(
  offsets: List(OffsetSegment),
  distance: Float,
  options: Options,
  closed closed: Bool,
) -> Result(List(svg_path.Segment), Error) {
  case offsets {
    [] -> Ok([])
    [first, ..rest] -> {
      let initial = first.offset
      joined_offset_segments_loop(
        first,
        first,
        rest,
        distance,
        options,
        closed:,
        segments: initial,
      )
    }
  }
}

fn joined_offset_segments_loop(
  first: OffsetSegment,
  previous: OffsetSegment,
  rest: List(OffsetSegment),
  distance: Float,
  options: Options,
  closed closed: Bool,
  segments segments: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), Error) {
  case rest {
    [] -> {
      case closed {
        False -> Ok(segments)
        True -> {
          use join <- result.try(join_segments(
            previous,
            first,
            distance,
            options.join,
          ))
          Ok(list.append(segments, join))
        }
      }
    }
    [next, ..remaining] -> {
      use join <- result.try(join_segments(
        previous,
        next,
        distance,
        options.join,
      ))
      joined_offset_segments_loop(
        first,
        next,
        remaining,
        distance,
        options,
        closed:,
        segments: list.append(segments, list.append(join, next.offset)),
      )
    }
  }
}

fn join_segments(
  left: OffsetSegment,
  right: OffsetSegment,
  distance: Float,
  join: Join,
) -> Result(List(svg_path.Segment), Error) {
  use left_offset <- result.try(last_offset_segment(left))
  use right_offset <- result.try(first_offset_segment(right))

  let start = svg_path.segment_end(left_offset)
  let end = svg_path.segment_start(right_offset)

  case points_near(start, end) {
    True -> Ok([])
    False ->
      case join {
        Bevel -> Ok(line_segments_between([start, end]))
        Miter(miter_limit) ->
          miter_join(left, right, start, end, distance, miter_limit)
        Round -> round_join(left, right, start, end, distance)
      }
  }
}

fn trim_joined_offset_segments(
  offsets: List(OffsetSegment),
  distance: Float,
  options: Options,
  closed closed: Bool,
) -> Result(List(svg_path.Segment), Error) {
  case offsets {
    [] -> Ok([])
    [first, ..rest] -> {
      use open_segments <- result.try(trim_joined_offset_segments_loop(
        first,
        rest,
        distance,
        options,
        segments: first.offset,
      ))

      case closed {
        False -> Ok(open_segments)
        True -> trim_closed_join(offsets, open_segments, distance, options)
      }
    }
  }
}

fn trim_joined_offset_segments_loop(
  previous: OffsetSegment,
  rest: List(OffsetSegment),
  distance: Float,
  options: Options,
  segments segments: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), Error) {
  case rest {
    [] -> Ok(segments)
    [next, ..remaining] -> {
      use left_offset <- result.try(last_segment(segments))
      use right_offset <- result.try(first_offset_segment(next))
      use join <- result.try(trim_or_join_segments(
        previous.source,
        left_offset,
        next.source,
        right_offset,
        distance,
        options.join,
      ))
      use segments <- result.try(replace_last_segment(segments, join.left))
      let next_segments =
        replace_first_segment_unchecked(next.offset, join.right)
      trim_joined_offset_segments_loop(
        next,
        remaining,
        distance,
        options,
        segments: list.append(segments, list.append(join.join, next_segments)),
      )
    }
  }
}

fn trim_closed_join(
  offsets: List(OffsetSegment),
  segments: List(svg_path.Segment),
  distance: Float,
  options: Options,
) -> Result(List(svg_path.Segment), Error) {
  use first <- result.try(first_offset_segment_info(offsets))
  use last <- result.try(last_offset_segment_info(offsets))
  use first_offset <- result.try(first_segment(segments))
  use last_offset <- result.try(last_segment(segments))
  use join <- result.try(trim_or_join_segments(
    last.source,
    last_offset,
    first.source,
    first_offset,
    distance,
    options.join,
  ))
  use segments <- result.try(replace_first_segment(segments, join.right))
  use segments <- result.try(replace_last_segment(segments, join.left))
  Ok(list.append(segments, join.join))
}

fn trim_or_join_segments(
  left_source: svg_path.Segment,
  left_offset: svg_path.Segment,
  right_source: svg_path.Segment,
  right_offset: svg_path.Segment,
  distance: Float,
  join: Join,
) -> Result(TrimJoin, Error) {
  let start = svg_path.segment_end(left_offset)
  let end = svg_path.segment_start(right_offset)

  case points_near(start, end) {
    True -> Ok(TrimJoin(left: left_offset, join: [], right: right_offset))
    False -> {
      case trim_intersection(left_offset, right_offset) {
        Ok(#(left_t, right_t)) -> {
          use left <- result.try(
            svg_path.segment_between_inside(left_offset, from: 0.0, to: left_t)
            |> result.map_error(PathError),
          )
          use right <- result.try(
            svg_path.segment_between_inside(
              right_offset,
              from: right_t,
              to: 1.0,
            )
            |> result.map_error(PathError),
          )
          Ok(TrimJoin(left:, join: [], right:))
        }
        Error(_) -> {
          use connectors <- result.try(join_segments(
            OffsetSegment(source: left_source, offset: [left_offset]),
            OffsetSegment(source: right_source, offset: [right_offset]),
            distance,
            join,
          ))
          Ok(TrimJoin(left: left_offset, join: connectors, right: right_offset))
        }
      }
    }
  }
}

fn trim_intersection(
  left: svg_path.Segment,
  right: svg_path.Segment,
) -> Result(#(Float, Float), Nil) {
  case svg_path.segment_intersections(left, right) {
    Error(_) -> Error(Nil)
    Ok([]) -> Error(Nil)
    Ok(intersections) ->
      intersections
      |> best_trim_intersection
  }
}

fn best_trim_intersection(
  intersections: List(svg_path.SegmentIntersection),
) -> Result(#(Float, Float), Nil) {
  case intersections {
    [] -> Error(Nil)
    [first, ..rest] ->
      Ok(best_trim_intersection_loop(
        rest,
        best: #(first.left_t, first.right_t),
        best_score: trim_score(first.left_t, first.right_t),
      ))
  }
}

fn best_trim_intersection_loop(
  intersections: List(svg_path.SegmentIntersection),
  best best: #(Float, Float),
  best_score best_score: Float,
) -> #(Float, Float) {
  case intersections {
    [] -> best
    [first, ..rest] -> {
      let score = trim_score(first.left_t, first.right_t)
      case score <. best_score {
        True ->
          best_trim_intersection_loop(
            rest,
            best: #(first.left_t, first.right_t),
            best_score: score,
          )
        False -> best_trim_intersection_loop(rest, best:, best_score:)
      }
    }
  }
}

fn trim_score(left_t: Float, right_t: Float) -> Float {
  float.absolute_value(1.0 -. left_t) +. float.absolute_value(right_t)
}

fn first_offset_segment_info(
  offsets: List(OffsetSegment),
) -> Result(OffsetSegment, Error) {
  case offsets {
    [] -> Error(NonFinite)
    [first, ..] -> Ok(first)
  }
}

fn last_offset_segment_info(
  offsets: List(OffsetSegment),
) -> Result(OffsetSegment, Error) {
  offsets |> list.last |> result.map_error(fn(_) { NonFinite })
}

fn first_segment(
  segments: List(svg_path.Segment),
) -> Result(svg_path.Segment, Error) {
  case segments {
    [] -> Error(NonFinite)
    [first, ..] -> Ok(first)
  }
}

fn last_segment(
  segments: List(svg_path.Segment),
) -> Result(svg_path.Segment, Error) {
  segments |> list.last |> result.map_error(fn(_) { NonFinite })
}

fn replace_first_segment(
  segments: List(svg_path.Segment),
  replacement: svg_path.Segment,
) -> Result(List(svg_path.Segment), Error) {
  case segments {
    [] -> Error(NonFinite)
    [_, ..rest] -> Ok([replacement, ..rest])
  }
}

fn replace_first_segment_unchecked(
  segments: List(svg_path.Segment),
  replacement: svg_path.Segment,
) -> List(svg_path.Segment) {
  case segments {
    [] -> []
    [_, ..rest] -> [replacement, ..rest]
  }
}

fn replace_last_segment(
  segments: List(svg_path.Segment),
  replacement: svg_path.Segment,
) -> Result(List(svg_path.Segment), Error) {
  case segments {
    [] -> Error(NonFinite)
    [_] -> Ok([replacement])
    [first, ..rest] -> {
      use rest <- result.try(replace_last_segment(rest, replacement))
      Ok([first, ..rest])
    }
  }
}

fn miter_join(
  left: OffsetSegment,
  right: OffsetSegment,
  start: svg_path.Point,
  end: svg_path.Point,
  distance: Float,
  miter_limit: Float,
) -> Result(List(svg_path.Segment), Error) {
  use left_tangent <- result.try(unit_tangent(left.source, t: 1.0))
  use right_tangent <- result.try(unit_tangent(right.source, t: 0.0))

  case line_intersection(start, left_tangent, end, right_tangent) {
    Error(_) -> Ok(line_segments_between([start, end]))
    Ok(apex) -> {
      let corner = svg_path.segment_end(left.source)
      let miter_length = vec2f.distance(corner, with: apex)
      let offset_distance = float.absolute_value(distance)
      let within_limit = case offset_distance <=. point_tolerance {
        True -> True
        False -> miter_length /. offset_distance <=. miter_limit
      }

      case within_limit && point_is_finite(apex) {
        True -> Ok(line_segments_between([start, apex, end]))
        False -> Ok(line_segments_between([start, end]))
      }
    }
  }
}

fn round_join(
  left: OffsetSegment,
  right: OffsetSegment,
  start: svg_path.Point,
  end: svg_path.Point,
  distance: Float,
) -> Result(List(svg_path.Segment), Error) {
  let radius = float.absolute_value(distance)
  case radius <=. point_tolerance {
    True -> Ok(line_segments_between([start, end]))
    False -> {
      use left_normal <- result.try(unit_normal(left.source, t: 1.0))
      use right_normal <- result.try(unit_normal(right.source, t: 0.0))
      let angle = signed_angle(left_normal, right_normal)
      case float.absolute_value(angle) <=. point_tolerance {
        True -> Ok(line_segments_between([start, end]))
        False ->
          Ok([
            svg_path.Arc(
              start:,
              radius: svg_path.point(radius, radius),
              x_axis_rotation: 0.0,
              large_arc: float.absolute_value(angle) >. 180.0,
              sweep: angle >. 0.0,
              end:,
            ),
          ])
      }
    }
  }
}

fn first_offset_segment(
  offset: OffsetSegment,
) -> Result(svg_path.Segment, Error) {
  case offset.offset {
    [] -> Error(NonFinite)
    [first, ..] -> Ok(first)
  }
}

fn last_offset_segment(
  offset: OffsetSegment,
) -> Result(svg_path.Segment, Error) {
  offset.offset |> list.last |> result.map_error(fn(_) { NonFinite })
}

fn line_intersection(
  left_start: svg_path.Point,
  left_direction: svg_path.Point,
  right_start: svg_path.Point,
  right_direction: svg_path.Point,
) -> Result(svg_path.Point, Nil) {
  let delta = subtract(right_start, left_start)
  let determinant = cross(left_direction, right_direction)
  case float.absolute_value(determinant) <=. point_tolerance {
    True -> Error(Nil)
    False -> {
      let left_t = cross(delta, right_direction) /. determinant
      let point = add(left_start, scale(left_direction, left_t))
      case point_is_finite(point) {
        True -> Ok(point)
        False -> Error(Nil)
      }
    }
  }
}

fn line_segments_between(
  points: List(svg_path.Point),
) -> List(svg_path.Segment) {
  case points {
    [] | [_] -> []
    [first, second, ..rest] -> {
      let tail = line_segments_between([second, ..rest])
      case points_near(first, second) {
        True -> tail
        False -> [svg_path.Line(start: first, end: second), ..tail]
      }
    }
  }
}

fn offset_cubic_segments(
  segments: List(svg_path.Segment),
  distance: Float,
  options: Options,
  converted converted: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), Error) {
  case segments {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use offset <- result.try(offset_cubic_segment(first, distance, options))
      offset_cubic_segments(
        rest,
        distance,
        options,
        converted: list.append(list.reverse(offset), converted),
      )
    }
  }
}

fn offset_cubic_segment(
  segment: svg_path.Segment,
  distance: Float,
  options: Options,
) -> Result(List(svg_path.Segment), Error) {
  offset_cubic_segment_loop(
    segment,
    distance,
    options,
    depth: options.max_depth,
  )
}

fn offset_cubic_segment_loop(
  segment: svg_path.Segment,
  distance: Float,
  options: Options,
  depth depth: Int,
) -> Result(List(svg_path.Segment), Error) {
  use candidate <- result.try(naive_cubic_offset(segment, distance))
  use divergence <- result.try(offset_divergence(
    segment,
    candidate,
    distance,
    options,
  ))

  case divergence <=. options.tolerance {
    True -> Ok([candidate])
    False ->
      case depth <= 0 {
        True -> Error(MaxDepthReached(divergence))
        False -> {
          use split <- result.try(
            svg_path.split_segment(segment, at: 0.5)
            |> result.map_error(PathError),
          )
          let #(left, right) = split
          use left_offset <- result.try(offset_cubic_segment_loop(
            left,
            distance,
            options,
            depth: depth - 1,
          ))
          use right_offset <- result.try(offset_cubic_segment_loop(
            right,
            distance,
            options,
            depth: depth - 1,
          ))
          Ok(list.append(left_offset, right_offset))
        }
      }
  }
}

fn naive_cubic_offset(
  segment: svg_path.Segment,
  distance: Float,
) -> Result(svg_path.Segment, Error) {
  use start <- result.try(offset_point(segment, t: 0.0, distance:))
  use end <- result.try(offset_point(segment, t: 1.0, distance:))
  use start_derivative <- result.try(offset_derivative(
    segment,
    t: 0.0,
    distance:,
  ))
  use end_derivative <- result.try(offset_derivative(segment, t: 1.0, distance:))

  let candidate =
    svg_path.CubicBezier(
      start:,
      control1: add(start, scale(start_derivative, 1.0 /. 3.0)),
      control2: subtract(end, scale(end_derivative, 1.0 /. 3.0)),
      end:,
    )

  case segment_is_finite(candidate) {
    True -> Ok(candidate)
    False -> Error(NonFinite)
  }
}

fn offset_point(
  segment: svg_path.Segment,
  t t: Float,
  distance distance: Float,
) -> Result(svg_path.Point, Error) {
  use point <- result.try(
    svg_path.segment_point(segment, at: t) |> result.map_error(PathError),
  )
  use normal <- result.try(unit_normal(segment, t:))
  let point = add(point, scale(normal, distance))

  case point_is_finite(point) {
    True -> Ok(point)
    False -> Error(NonFinite)
  }
}

fn offset_derivative(
  segment: svg_path.Segment,
  t t: Float,
  distance distance: Float,
) -> Result(svg_path.Point, Error) {
  use derivative <- result.try(
    svg_path.segment_derivative(segment, at: t) |> result.map_error(PathError),
  )
  use second <- result.try(second_derivative(segment, t:))
  use speed <- result.try(length(derivative, t:))

  let tangent_change =
    subtract(
      scale(second, 1.0 /. speed),
      scale(derivative, dot(derivative, second) /. { speed *. speed *. speed }),
    )

  let candidate =
    subtract(derivative, scale(rotate_clockwise(tangent_change), distance))

  case point_is_finite(candidate) {
    True -> Ok(candidate)
    False -> Error(NonFinite)
  }
}

fn second_derivative(
  segment: svg_path.Segment,
  t t: Float,
) -> Result(svg_path.Point, Error) {
  case segment {
    svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      let left = add(subtract(start, scale(control1, 2.0)), control2)
      let right = add(subtract(control1, scale(control2, 2.0)), end)
      Ok(scale(interpolate(left, right, t), 6.0))
    }
    svg_path.QuadraticBezier(start:, control:, end:) ->
      Ok(scale(add(subtract(start, scale(control, 2.0)), end), 2.0))
    svg_path.Line(..) -> Ok(svg_path.point(0.0, 0.0))
    svg_path.Arc(..) -> Error(PathError(svg_path.DegenerateArc))
  }
}

fn offset_divergence(
  source: svg_path.Segment,
  candidate: svg_path.Segment,
  distance: Float,
  options: Options,
) -> Result(Float, Error) {
  offset_divergence_loop(
    source,
    candidate,
    distance,
    options,
    sample: 1,
    best: 0.0,
  )
}

fn offset_divergence_loop(
  source: svg_path.Segment,
  candidate: svg_path.Segment,
  distance: Float,
  options: Options,
  sample sample: Int,
  best best: Float,
) -> Result(Float, Error) {
  case sample > options.samples {
    True -> Ok(best)
    False -> {
      let t = int_to_float(sample) /. int_to_float(options.samples + 1)
      use point <- result.try(offset_point(source, t:, distance:))
      use projection <- result.try(
        svg_path.segment_projection_with(
          point,
          to: candidate,
          options: options.distance,
        )
        |> result.map_error(PathError),
      )
      let best = float.max(best, projection.distance)
      case best >. options.tolerance {
        True -> Ok(best)
        False ->
          offset_divergence_loop(
            source,
            candidate,
            distance,
            options,
            sample: sample + 1,
            best:,
          )
      }
    }
  }
}

fn unit_normal(
  segment: svg_path.Segment,
  t t: Float,
) -> Result(svg_path.Point, Error) {
  use tangent <- result.try(unit_tangent(segment, t:))
  Ok(rotate_clockwise(tangent))
}

fn unit_tangent(
  segment: svg_path.Segment,
  t t: Float,
) -> Result(svg_path.Point, Error) {
  case svg_path.segment_derivative(segment, at: t) {
    Ok(derivative) -> {
      case vec2f.length(derivative) >. tangent_epsilon {
        True -> Ok(scale(derivative, 1.0 /. vec2f.length(derivative)))
        False -> fallback_unit_tangent(segment, t:)
      }
    }
    Error(error) -> Error(PathError(error))
  }
}

fn fallback_unit_tangent(
  segment: svg_path.Segment,
  t t: Float,
) -> Result(svg_path.Point, Error) {
  let fallback_t = case t <=. 0.0 {
    True -> 0.001
    False ->
      case t >=. 1.0 {
        True -> 0.999
        False -> t +. 0.001
      }
  }

  use derivative <- result.try(
    svg_path.segment_derivative(segment, at: fallback_t)
    |> result.map_error(PathError),
  )

  case vec2f.length(derivative) >. tangent_epsilon {
    True -> Ok(scale(derivative, 1.0 /. vec2f.length(derivative)))
    False -> {
      let start = svg_path.segment_start(segment)
      let end = svg_path.segment_end(segment)
      let chord = subtract(end, start)
      case vec2f.length(chord) >. tangent_epsilon {
        True -> Ok(scale(chord, 1.0 /. vec2f.length(chord)))
        False -> Error(DegenerateTangent(t))
      }
    }
  }
}

fn length(point: svg_path.Point, t t: Float) -> Result(Float, Error) {
  let length = vec2f.length(point)
  case length >. tangent_epsilon {
    True -> Ok(length)
    False -> Error(DegenerateTangent(t))
  }
}

fn rotate_clockwise(point: svg_path.Point) -> svg_path.Point {
  svg_path.point(point.y, 0.0 -. point.x)
}

fn interpolate(
  a: svg_path.Point,
  b: svg_path.Point,
  t: Float,
) -> svg_path.Point {
  add(a, scale(subtract(b, a), t))
}

fn add(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.point(a.x +. b.x, a.y +. b.y)
}

fn subtract(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.point(a.x -. b.x, a.y -. b.y)
}

fn scale(point: svg_path.Point, factor: Float) -> svg_path.Point {
  svg_path.point(point.x *. factor, point.y *. factor)
}

fn dot(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.x +. a.y *. b.y
}

fn cross(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.y -. a.y *. b.x
}

fn signed_angle(a: svg_path.Point, b: svg_path.Point) -> Float {
  trig.atan2_degrees(cross(a, b), dot(a, b))
}

fn points_near(a: svg_path.Point, b: svg_path.Point) -> Bool {
  vec2f.distance_squared(a, with: b) <=. point_tolerance *. point_tolerance
}

fn segment_is_finite(segment: svg_path.Segment) -> Bool {
  case segment {
    svg_path.Line(start:, end:) ->
      point_is_finite(start) && point_is_finite(end)
    svg_path.QuadraticBezier(start:, control:, end:) ->
      point_is_finite(start) && point_is_finite(control) && point_is_finite(end)
    svg_path.CubicBezier(start:, control1:, control2:, end:) ->
      point_is_finite(start)
      && point_is_finite(control1)
      && point_is_finite(control2)
      && point_is_finite(end)
    svg_path.Arc(start:, radius:, x_axis_rotation:, end:, ..) ->
      point_is_finite(start)
      && point_is_finite(radius)
      && is_finite(x_axis_rotation)
      && point_is_finite(end)
  }
}

fn point_is_finite(point: svg_path.Point) -> Bool {
  is_finite(point.x) && is_finite(point.y)
}

fn is_finite(value: Float) -> Bool {
  !is_nan(value -. value)
}

fn is_nan(value: Float) -> Bool {
  !{ value <. 0.0 || value >=. 0.0 }
}

fn int_to_float(value: Int) -> Float {
  value |> int.to_float
}
