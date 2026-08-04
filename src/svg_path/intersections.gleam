//// Point-intersection queries for SVG path geometry.
////
//// This module owns segment, subpath, path, and self-intersection search.
//// Result types are the root `svg_path` types, such as
//// `svg_path.SegmentIntersection`, `svg_path.SubpathIntersection`, and
//// `svg_path.PathIntersection`.

import gleam/float
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import svg_path.{
  type BoundingBox, type Error, type Path, type PathIntersection,
  type PathParameter, type PathSelfIntersection, type Point, type Segment,
  type SegmentIntersection, type SelfIntersectionOptions, type Subpath,
  type SubpathIntersection, type SubpathParameter, type SubpathSelfIntersection,
  Arc, CubicBezier, InternalOverlapClassificationInconsistency,
  InvalidIntersectionMaxDepth, InvalidIntersectionTolerance,
  InvalidSelfIntersectionDistanceTolerance,
  InvalidSelfIntersectionMinimumArcLengthSeparation, Line, OverlappingSegments,
  PathIntersection, PathParameter, PathSelfIntersection, Point, QuadraticBezier,
  SegmentIntersection, SelfIntersectionOptions, SubpathIntersection,
  SubpathParameter, SubpathSelfIntersection,
}
import svg_path/bezier
import svg_path/overlap_detection

const default_intersection_tolerance = 0.000000001

const default_intersection_max_depth = 48

/// Options for finding segment, subpath, and path intersections.
pub type IntersectionOptions {
  IntersectionOptions(tolerance: Float, max_depth: Int)
}

/// Return the default options for segment, subpath, and path intersection
/// detection.
pub fn default_options() -> IntersectionOptions {
  IntersectionOptions(
    tolerance: default_intersection_tolerance,
    max_depth: default_intersection_max_depth,
  )
}

/// Return the default options for subpath self-intersection detection.
pub fn default_self_options() -> SelfIntersectionOptions {
  SelfIntersectionOptions(
    minimum_arc_length_separation: default_intersection_tolerance,
    distance_tolerance: default_intersection_tolerance,
  )
}

/// Return point intersections between two segments.
///
/// Overlapping segments return `OverlappingSegments`, since they have more than
/// a finite list of point intersections.
pub fn segment(
  left: Segment,
  right: Segment,
) -> Result(List(SegmentIntersection), Error) {
  segment_with(left, right, options: default_options())
}

/// Return point intersections between two segments using explicit options.
pub fn segment_with(
  left: Segment,
  right: Segment,
  options options: IntersectionOptions,
) -> Result(List(SegmentIntersection), Error) {
  use _ <- result.try(validate_intersection_options(options))
  segment_intersections_checked_valid_options(left, right, options)
}

/// Run the existing point-intersection solver without first rejecting a pair
/// classified as overlapping.
///
/// This is an internal composition hook for `svg_path/encounters`. The solver
/// itself may still return `OverlappingSegments`.
@internal
pub fn segment_without_overlap_precheck_with(
  left: Segment,
  right: Segment,
  options options: IntersectionOptions,
) -> Result(List(SegmentIntersection), Error) {
  use _ <- result.try(validate_intersection_options(options))
  segment_intersections_valid_options(left, right, options)
}

fn segment_intersections_checked_valid_options(
  left: Segment,
  right: Segment,
  options: IntersectionOptions,
) -> Result(List(SegmentIntersection), Error) {
  use overlaps <- result.try(overlap_detection.detect(
    left,
    right,
    tolerance: options.tolerance,
  ))
  case overlaps {
    [_, ..] -> Error(OverlappingSegments)
    [] ->
      case segment_intersections_valid_options(left, right, options) {
        Error(OverlappingSegments) ->
          Error(InternalOverlapClassificationInconsistency)
        result -> result
      }
  }
}

/// Return point intersections where a segment intersects itself.
///
/// Straight lines and quadratic Beziers do not report self-intersections.
/// Cubic Beziers can self-intersect, including at separated parameters that
/// evaluate to the same endpoint. An arc whose start and end coincide reports
/// that endpoint pair when both radii are nonzero.
pub fn segment_self(
  segment: Segment,
) -> Result(List(SegmentIntersection), Error) {
  segment_self_with(segment, options: default_self_options())
}

/// Return point intersections where a segment intersects itself using explicit
/// options.
pub fn segment_self_with(
  segment: Segment,
  options options: SelfIntersectionOptions,
) -> Result(List(SegmentIntersection), Error) {
  use _ <- result.try(validate_self_intersection_options(options))
  segment_self_intersections_valid_options(segment, options)
}

/// Return the intersections between a segment and a subpath.
///
/// Each result contains an intersection point, its local parameter on the
/// standalone segment, and every corresponding parameter on the subpath.
/// Results are ordered by the standalone segment parameter. Segment-boundary
/// aliases are canonicalized to one traversal address. A continuous overlap
/// with any segment of the subpath returns `OverlappingSegments`.
pub fn segment_subpath(
  segment: Segment,
  subpath: Subpath,
) -> Result(List(#(Point, Float, List(SubpathParameter))), Error) {
  segment_subpath_with(segment, subpath, options: default_options())
}

/// Return the intersections between a segment and a subpath using explicit
/// options.
pub fn segment_subpath_with(
  segment: Segment,
  subpath: Subpath,
  options options: IntersectionOptions,
) -> Result(List(#(Point, Float, List(SubpathParameter))), Error) {
  use _ <- result.try(validate_intersection_options(options))
  use intersections <- result.try(
    collect_segment_subpath_intersections(
      segment,
      svg_path.subpath_segments(subpath),
      options,
      permit_overlapping_pairs: False,
      segment_index: 0,
      grouped: [],
    ),
  )

  Ok(sort_segment_subpath_intersections(
    intersections,
    subpath,
    options.tolerance,
  ))
}

/// Collect point intersections from non-overlapping constituent segment pairs
/// while permitting other pairs in the segment-subpath query to overlap.
///
/// This is an internal composition hook for `svg_path/encounters`.
@internal
pub fn segment_subpath_without_overlap_precheck_with(
  segment: Segment,
  subpath: Subpath,
  options options: IntersectionOptions,
) -> Result(List(#(Point, Float, List(SubpathParameter))), Error) {
  use _ <- result.try(validate_intersection_options(options))
  use found <- result.try(
    collect_segment_subpath_intersections(
      segment,
      svg_path.subpath_segments(subpath),
      options,
      permit_overlapping_pairs: True,
      segment_index: 0,
      grouped: [],
    ),
  )
  Ok(sort_segment_subpath_intersections(found, subpath, options.tolerance))
}

/// Return point intersections where a subpath intersects itself.
///
/// Results are ordered by the first parameter. Adjacent segment endpoints are
/// filtered by arc-length separation, so ordinary segment joins are not
/// reported as self-intersections. A continuous overlap between two distinct
/// constituent segments returns `OverlappingSegments`.
pub fn subpath_self(
  subpath: Subpath,
) -> Result(List(SubpathSelfIntersection), Error) {
  subpath_self_with(subpath, options: default_self_options())
}

/// Return point intersections where a subpath intersects itself using explicit
/// options.
pub fn subpath_self_with(
  subpath: Subpath,
  options options: SelfIntersectionOptions,
) -> Result(List(SubpathSelfIntersection), Error) {
  use _ <- result.try(validate_self_intersection_options(options))
  use total_length <- result.try(svg_path.subpath_length(subpath))
  use indexed_segments <- result.try(
    indexed_segments_with_lengths(
      svg_path.subpath_segments(subpath),
      index: 0,
      prefix: 0.0,
      accumulated: [],
    ),
  )
  use intersections <- result.try(
    collect_subpath_self_intersections(
      indexed_segments,
      svg_path.subpath_is_closed(subpath),
      total_length,
      options,
      found: [],
    ),
  )

  Ok(sort_subpath_self_intersections(intersections))
}

/// Return the point intersections between two subpaths.
///
/// Each result contains an intersection point and every corresponding
/// parameter on both subpaths. Results are ordered by the first left parameter.
/// Segment-boundary aliases are canonicalized to one traversal address. A
/// continuous overlap between any segment pair returns `OverlappingSegments`.
pub fn subpath(
  left: Subpath,
  right: Subpath,
) -> Result(List(SubpathIntersection), Error) {
  subpath_with(left, right, options: default_options())
}

/// Return the point intersections between two subpaths using explicit options.
pub fn subpath_with(
  left: Subpath,
  right: Subpath,
  options options: IntersectionOptions,
) -> Result(List(SubpathIntersection), Error) {
  use _ <- result.try(validate_intersection_options(options))
  use intersections <- result.try(
    collect_subpath_intersections(
      svg_path.subpath_segments(left),
      right,
      options,
      permit_overlapping_pairs: False,
      left_segment_index: 0,
      grouped: [],
    ),
  )

  Ok(sort_subpath_intersections(intersections, left, right, options.tolerance))
}

/// Collect point intersections from non-overlapping segment pairs while
/// permitting other segment pairs in the same subpath query to overlap.
///
/// This is an internal composition hook for `svg_path/encounters`.
@internal
pub fn subpath_without_overlap_precheck_with(
  left: Subpath,
  right: Subpath,
  options options: IntersectionOptions,
) -> Result(List(SubpathIntersection), Error) {
  use _ <- result.try(validate_intersection_options(options))
  use found <- result.try(
    collect_subpath_intersections(
      svg_path.subpath_segments(left),
      right,
      options,
      permit_overlapping_pairs: True,
      left_segment_index: 0,
      grouped: [],
    ),
  )
  Ok(sort_subpath_intersections(found, left, right, options.tolerance))
}

/// Return the point intersections between two paths.
///
/// Each result contains an intersection point and every corresponding
/// parameter on both paths. Results are ordered by the first left parameter.
/// Segment-boundary aliases are canonicalized to one traversal address. A
/// continuous overlap between any segment pair returns `OverlappingSegments`.
pub fn path(left: Path, right: Path) -> Result(List(PathIntersection), Error) {
  path_with(left, right, options: default_options())
}

/// Return the point intersections between two paths using explicit options.
pub fn path_with(
  left: Path,
  right: Path,
  options options: IntersectionOptions,
) -> Result(List(PathIntersection), Error) {
  use _ <- result.try(validate_intersection_options(options))
  use intersections <- result.try(
    collect_path_intersections(
      left.subpaths,
      right.subpaths,
      options,
      permit_overlapping_pairs: False,
      left_subpath_index: 0,
      grouped: [],
    ),
  )

  Ok(sort_path_intersections(intersections))
}

/// Collect point intersections from non-overlapping constituent segment pairs
/// while permitting other pairs in the path query to overlap.
///
/// This is an internal composition hook for `svg_path/encounters`.
@internal
pub fn path_without_overlap_precheck_with(
  left: Path,
  right: Path,
  options options: IntersectionOptions,
) -> Result(List(PathIntersection), Error) {
  use _ <- result.try(validate_intersection_options(options))
  use found <- result.try(
    collect_path_intersections(
      left.subpaths,
      right.subpaths,
      options,
      permit_overlapping_pairs: True,
      left_subpath_index: 0,
      grouped: [],
    ),
  )
  Ok(sort_path_intersections(found))
}

/// Return point intersections where a path intersects itself.
///
/// This includes self-intersections inside one subpath and intersections
/// between distinct subpaths in the same path. Results are ordered by the first
/// path parameter. A continuous overlap between distinct constituent segments
/// returns `OverlappingSegments`.
pub fn path_self(path: Path) -> Result(List(PathSelfIntersection), Error) {
  path_self_with(path, options: default_self_options())
}

/// Return point intersections where a path intersects itself using explicit
/// options.
pub fn path_self_with(
  path: Path,
  options options: SelfIntersectionOptions,
) -> Result(List(PathSelfIntersection), Error) {
  use _ <- result.try(validate_self_intersection_options(options))
  use intersections <- result.try(
    collect_path_self_intersections(
      path.subpaths,
      options,
      subpath_index: 0,
      found: [],
    ),
  )

  Ok(sort_path_self_intersections(intersections))
}

fn clamp01(value: Float) -> Float {
  value |> float.max(0.0) |> float.min(1.0)
}

fn point_difference(a: Point, b: Point) -> Point {
  Point(a.x -. b.x, a.y -. b.y)
}

fn dot(a: Point, b: Point) -> Float {
  a.x *. b.x +. a.y *. b.y
}

fn validate_intersection_options(
  options: IntersectionOptions,
) -> Result(Nil, Error) {
  case options.tolerance <=. 0.0 {
    True -> Error(InvalidIntersectionTolerance(options.tolerance))
    False -> {
      case options.max_depth <= 0 {
        True -> Error(InvalidIntersectionMaxDepth(options.max_depth))
        False -> Ok(Nil)
      }
    }
  }
}

fn validate_self_intersection_options(
  options: SelfIntersectionOptions,
) -> Result(Nil, Error) {
  case options.minimum_arc_length_separation <=. 0.0 {
    True ->
      Error(InvalidSelfIntersectionMinimumArcLengthSeparation(
        options.minimum_arc_length_separation,
      ))
    False -> {
      case options.distance_tolerance <=. 0.0 {
        True ->
          Error(InvalidSelfIntersectionDistanceTolerance(
            options.distance_tolerance,
          ))
        False -> Ok(Nil)
      }
    }
  }
}

fn segment_intersections_valid_options(
  left: Segment,
  right: Segment,
  options: IntersectionOptions,
) -> Result(List(SegmentIntersection), Error) {
  case left, right {
    Line(start: left_start, end: left_end),
      Line(start: right_start, end: right_end)
    ->
      line_line_intersections(
        left_start,
        left_end,
        right_start,
        right_end,
        options.tolerance,
      )
    Line(start:, end:), _ ->
      line_segment_intersections(
        line_start: start,
        line_end: end,
        line_is_left: True,
        segment: right,
        options:,
      )
    _, Line(start:, end:) ->
      line_segment_intersections(
        line_start: start,
        line_end: end,
        line_is_left: False,
        segment: left,
        options:,
      )
    _, _ -> curve_curve_intersections(left, right, options)
  }
}

fn segment_self_intersections_valid_options(
  segment: Segment,
  options: SelfIntersectionOptions,
) -> Result(List(SegmentIntersection), Error) {
  case segment {
    CubicBezier(..) -> {
      let bezier_options =
        bezier.CubicSelfIntersectionOptions(
          minimum_arc_length_separation: options.minimum_arc_length_separation,
          distance_tolerance: options.distance_tolerance,
        )
      case
        segment
        |> segment_to_bezier_data
        |> bezier.cubic_self_intersections_with(options: bezier_options)
      {
        Error(error) -> Error(bezier_self_intersection_error(error))
        Ok(intersections) ->
          Ok(
            list.map(intersections, fn(intersection) {
              let bezier.CubicSelfIntersection(s:, t:, point:) = intersection
              SegmentIntersection(
                left_t: s,
                right_t: t,
                point: from_bezier_point(point),
              )
            }),
          )
      }
    }
    Line(..) | QuadraticBezier(..) -> Ok([])
    Arc(start:, radius:, end:, ..) -> {
      case start == end && radius.x != 0.0 && radius.y != 0.0 {
        True ->
          Ok([
            SegmentIntersection(left_t: 0.0, right_t: 1.0, point: start),
          ])
        False -> Ok([])
      }
    }
  }
}

type IntersectionPiece {
  IntersectionPiece(segment: Segment, from: Float, to: Float)
}

type IndexedSegment {
  IndexedSegment(
    index: Int,
    segment: Segment,
    prefix_length: Float,
    length: Float,
  )
}

fn indexed_segments_with_lengths(
  segments: List(Segment),
  index index: Int,
  prefix prefix: Float,
  accumulated accumulated: List(IndexedSegment),
) -> Result(List(IndexedSegment), Error) {
  case segments {
    [] -> Ok(list.reverse(accumulated))
    [first, ..rest] -> {
      use length <- result.try(svg_path.segment_length(first))
      indexed_segments_with_lengths(
        rest,
        index: index + 1,
        prefix: prefix +. length,
        accumulated: [
          IndexedSegment(index:, segment: first, prefix_length: prefix, length:),
          ..accumulated
        ],
      )
    }
  }
}

fn collect_subpath_self_intersections(
  segments: List(IndexedSegment),
  closed: Bool,
  total_length: Float,
  options: SelfIntersectionOptions,
  found found: List(SubpathSelfIntersection),
) -> Result(List(SubpathSelfIntersection), Error) {
  case segments {
    [] -> Ok(found)
    [first, ..rest] -> {
      use found <- result.try(collect_single_segment_self_intersections(
        first,
        options,
        found:,
      ))
      use found <- result.try(collect_segment_pair_self_intersections(
        first,
        rest,
        closed,
        total_length,
        options,
        found:,
      ))
      collect_subpath_self_intersections(
        rest,
        closed,
        total_length,
        options,
        found:,
      )
    }
  }
}

fn collect_single_segment_self_intersections(
  segment: IndexedSegment,
  options: SelfIntersectionOptions,
  found found: List(SubpathSelfIntersection),
) -> Result(List(SubpathSelfIntersection), Error) {
  case segment.segment {
    CubicBezier(..) -> {
      let bezier_options =
        bezier.CubicSelfIntersectionOptions(
          minimum_arc_length_separation: options.minimum_arc_length_separation,
          distance_tolerance: options.distance_tolerance,
        )
      case
        segment.segment
        |> segment_to_bezier_data
        |> bezier.cubic_self_intersections_with(options: bezier_options)
      {
        Error(error) -> Error(bezier_self_intersection_error(error))
        Ok(intersections) -> {
          Ok(
            list.fold(intersections, found, fn(found, intersection) {
              let bezier.CubicSelfIntersection(s:, t:, point:) = intersection
              insert_subpath_self_intersection(
                found,
                point: from_bezier_point(point),
                first: SubpathParameter(segment_index: segment.index, t: s),
                second: SubpathParameter(segment_index: segment.index, t: t),
                tolerance: options.distance_tolerance,
              )
            }),
          )
        }
      }
    }
    Line(..) | QuadraticBezier(..) | Arc(..) -> Ok(found)
  }
}

fn collect_segment_pair_self_intersections(
  left: IndexedSegment,
  rights: List(IndexedSegment),
  closed: Bool,
  total_length: Float,
  options: SelfIntersectionOptions,
  found found: List(SubpathSelfIntersection),
) -> Result(List(SubpathSelfIntersection), Error) {
  case rights {
    [] -> Ok(found)
    [right, ..rest] -> {
      use found <- result.try(collect_segment_pair_self_intersections_one(
        left,
        right,
        closed,
        total_length,
        options,
        found:,
      ))
      collect_segment_pair_self_intersections(
        left,
        rest,
        closed,
        total_length,
        options,
        found:,
      )
    }
  }
}

fn collect_segment_pair_self_intersections_one(
  left: IndexedSegment,
  right: IndexedSegment,
  closed: Bool,
  total_length: Float,
  options: SelfIntersectionOptions,
  found found: List(SubpathSelfIntersection),
) -> Result(List(SubpathSelfIntersection), Error) {
  use left_box <- result.try(coarse_segment_bounding_box(left.segment))
  use right_box <- result.try(coarse_segment_bounding_box(right.segment))

  case boxes_overlap(left_box, right_box, options.distance_tolerance) {
    False -> Ok(found)
    True -> {
      let intersection_options =
        IntersectionOptions(
          tolerance: options.distance_tolerance,
          max_depth: default_intersection_max_depth,
        )
      use intersections <- result.try(
        segment_intersections_checked_valid_options(
          left.segment,
          right.segment,
          intersection_options,
        ),
      )

      Ok(
        list.fold(intersections, found, fn(found, intersection) {
          insert_segment_pair_self_intersection(
            found,
            intersection,
            left,
            right,
            closed,
            total_length,
            options,
          )
        }),
      )
    }
  }
}

fn insert_segment_pair_self_intersection(
  found: List(SubpathSelfIntersection),
  intersection: SegmentIntersection,
  left: IndexedSegment,
  right: IndexedSegment,
  closed: Bool,
  total_length: Float,
  options: SelfIntersectionOptions,
) -> List(SubpathSelfIntersection) {
  let first =
    SubpathParameter(segment_index: left.index, t: intersection.left_t)
  let second =
    SubpathParameter(segment_index: right.index, t: intersection.right_t)

  case
    subpath_arc_length_separation(
      left,
      intersection.left_t,
      right,
      intersection.right_t,
      closed,
      total_length,
    )
    >=. options.minimum_arc_length_separation
  {
    False -> found
    True ->
      insert_subpath_self_intersection(
        found,
        point: intersection.point,
        first:,
        second:,
        tolerance: options.distance_tolerance,
      )
  }
}

fn subpath_arc_length_separation(
  left: IndexedSegment,
  left_t: Float,
  right: IndexedSegment,
  right_t: Float,
  closed: Bool,
  total_length: Float,
) -> Float {
  let first = absolute_subpath_length_at(left, left_t)
  let second = absolute_subpath_length_at(right, right_t)
  let separation = float.absolute_value(second -. first)

  case closed && total_length >. 0.0 {
    True -> float.min(separation, total_length -. separation)
    False -> separation
  }
}

fn absolute_subpath_length_at(segment: IndexedSegment, t: Float) -> Float {
  segment.prefix_length +. segment_length_to_t(segment.segment, t)
}

fn segment_length_to_t(segment: Segment, t: Float) -> Float {
  case t <=. 0.0 {
    True -> 0.0
    False ->
      case t >=. 1.0 {
        True -> {
          let assert Ok(length) = svg_path.segment_length(segment)
          length
        }
        False -> {
          let assert Ok(piece) =
            svg_path.segment_between(segment, from: 0.0, to: t)
          let assert Ok(length) = svg_path.segment_length(piece)
          length
        }
      }
  }
}

fn insert_subpath_self_intersection(
  found: List(SubpathSelfIntersection),
  point point: Point,
  first first: SubpathParameter,
  second second: SubpathParameter,
  tolerance tolerance: Float,
) -> List(SubpathSelfIntersection) {
  let #(first, second) = ordered_subpath_parameter_pair(first, second)

  case found {
    [] -> [SubpathSelfIntersection(point:, parameters: #(first, second))]
    [existing, ..rest] -> {
      let SubpathSelfIntersection(point: existing_point, parameters:) = existing
      let #(existing_first, existing_second) = parameters
      case
        distance(existing_point, point) <=. tolerance
        && same_subpath_parameter_pair(
          first,
          second,
          existing_first,
          existing_second,
          tolerance,
        )
      {
        True -> found
        False -> [
          existing,
          ..insert_subpath_self_intersection(
            rest,
            point:,
            first:,
            second:,
            tolerance:,
          )
        ]
      }
    }
  }
}

fn same_subpath_parameter_pair(
  first: SubpathParameter,
  second: SubpathParameter,
  existing_first: SubpathParameter,
  existing_second: SubpathParameter,
  tolerance: Float,
) -> Bool {
  same_subpath_parameter(first, existing_first, tolerance)
  && same_subpath_parameter(second, existing_second, tolerance)
}

fn same_subpath_parameter(
  left: SubpathParameter,
  right: SubpathParameter,
  tolerance: Float,
) -> Bool {
  let SubpathParameter(segment_index: left_index, t: left_t) = left
  let SubpathParameter(segment_index: right_index, t: right_t) = right
  left_index == right_index
  && float.absolute_value(left_t -. right_t) <=. tolerance
}

fn ordered_subpath_parameter_pair(
  first: SubpathParameter,
  second: SubpathParameter,
) -> #(SubpathParameter, SubpathParameter) {
  case svg_path.subpath_parameters_compare(first, second) {
    order.Gt -> #(second, first)
    order.Lt | order.Eq -> #(first, second)
  }
}

fn sort_subpath_self_intersections(
  intersections: List(SubpathSelfIntersection),
) -> List(SubpathSelfIntersection) {
  intersections
  |> list.sort(by: fn(a, b) {
    let SubpathSelfIntersection(parameters: a_parameters, ..) = a
    let SubpathSelfIntersection(parameters: b_parameters, ..) = b
    let #(a_first, a_second) = a_parameters
    let #(b_first, b_second) = b_parameters

    case svg_path.subpath_parameters_compare(a_first, b_first) {
      order.Eq -> svg_path.subpath_parameters_compare(a_second, b_second)
      order -> order
    }
  })
}

fn coarse_segment_bounding_box(segment: Segment) -> Result(BoundingBox, Error) {
  case segment {
    Line(start:, end:) -> Ok(assert_points_bounding_box([start, end]))
    QuadraticBezier(start:, control:, end:) ->
      Ok(assert_points_bounding_box([start, control, end]))
    CubicBezier(start:, control1:, control2:, end:) ->
      Ok(assert_points_bounding_box([start, control1, control2, end]))
    Arc(..) -> svg_path.segment_bounding_box(segment)
  }
}

fn assert_points_bounding_box(points: List(Point)) -> BoundingBox {
  let assert Ok(box) = svg_path.points_bounding_box(points)
  box
}

fn bezier_self_intersection_error(error: bezier.Error) -> Error {
  case error {
    bezier.InvalidCubicSelfIntersectionMinimumArcLengthSeparation(value) ->
      InvalidSelfIntersectionMinimumArcLengthSeparation(value)
    bezier.InvalidCubicSelfIntersectionDistanceTolerance(value) ->
      InvalidSelfIntersectionDistanceTolerance(value)
    bezier.SplitOutsideBezier
    | bezier.DegenerateTangent
    | bezier.UnderdeterminedCubicFit ->
      InvalidSelfIntersectionDistanceTolerance(0.0)
  }
}

fn collect_segment_subpath_intersections(
  segment: Segment,
  segments: List(Segment),
  options: IntersectionOptions,
  permit_overlapping_pairs permit_overlapping_pairs: Bool,
  segment_index segment_index: Int,
  grouped grouped: List(#(Point, Float, List(SubpathParameter))),
) -> Result(List(#(Point, Float, List(SubpathParameter))), Error) {
  case segments {
    [] -> Ok(grouped)
    [first, ..rest] -> {
      use intersections <- result.try(segment_intersections_for_collection(
        segment,
        first,
        options,
        permit_overlapping_pairs,
      ))
      let grouped =
        list.fold(intersections, grouped, fn(grouped, intersection) {
          insert_segment_subpath_intersection(
            grouped,
            intersection,
            SubpathParameter(segment_index:, t: intersection.right_t),
            options.tolerance,
          )
        })

      collect_segment_subpath_intersections(
        segment,
        rest,
        options,
        permit_overlapping_pairs:,
        segment_index: segment_index + 1,
        grouped:,
      )
    }
  }
}

fn segment_intersections_for_collection(
  left: Segment,
  right: Segment,
  options: IntersectionOptions,
  permit_overlapping_pairs: Bool,
) -> Result(List(SegmentIntersection), Error) {
  case permit_overlapping_pairs {
    False -> segment_intersections_checked_valid_options(left, right, options)
    True ->
      case segment_intersections_valid_options(left, right, options) {
        Error(OverlappingSegments) -> Ok([])
        other -> other
      }
  }
}

fn insert_segment_subpath_intersection(
  grouped: List(#(Point, Float, List(SubpathParameter))),
  intersection: SegmentIntersection,
  at: SubpathParameter,
  tolerance: Float,
) -> List(#(Point, Float, List(SubpathParameter))) {
  case grouped {
    [] -> [#(intersection.point, intersection.left_t, [at])]
    [first, ..rest] -> {
      let #(point, segment_t, parameters) = first
      case
        float.absolute_value(segment_t -. intersection.left_t) <=. tolerance
        && distance(point, intersection.point) <=. tolerance
      {
        True -> [#(point, segment_t, list.append(parameters, [at])), ..rest]
        False -> [
          first,
          ..insert_segment_subpath_intersection(
            rest,
            intersection,
            at,
            tolerance,
          )
        ]
      }
    }
  }
}

fn sort_segment_subpath_intersections(
  intersections: List(#(Point, Float, List(SubpathParameter))),
  subpath: Subpath,
  tolerance: Float,
) -> List(#(Point, Float, List(SubpathParameter))) {
  intersections
  |> list.map(fn(intersection) {
    let #(point, segment_t, parameters) = intersection
    #(
      point,
      segment_t,
      sort_unique_subpath_parameters(parameters, subpath, tolerance),
    )
  })
  |> list.sort(by: fn(a, b) {
    let #(_, a_t, _) = a
    let #(_, b_t, _) = b
    float.compare(a_t, b_t)
  })
}

fn collect_subpath_intersections(
  left_segments: List(Segment),
  right: Subpath,
  options: IntersectionOptions,
  permit_overlapping_pairs permit_overlapping_pairs: Bool,
  left_segment_index left_segment_index: Int,
  grouped grouped: List(SubpathIntersection),
) -> Result(List(SubpathIntersection), Error) {
  case left_segments {
    [] -> Ok(grouped)
    [left_segment, ..rest] -> {
      use intersections <- result.try(
        collect_segment_subpath_intersections(
          left_segment,
          svg_path.subpath_segments(right),
          options,
          permit_overlapping_pairs:,
          segment_index: 0,
          grouped: [],
        ),
      )
      let grouped =
        list.fold(intersections, grouped, fn(grouped, intersection) {
          let #(point, left_t, right_parameters) = intersection
          insert_subpath_intersection(
            grouped,
            point,
            left_at: SubpathParameter(
              segment_index: left_segment_index,
              t: left_t,
            ),
            right_parameters:,
            tolerance: options.tolerance,
          )
        })

      collect_subpath_intersections(
        rest,
        right,
        options,
        permit_overlapping_pairs:,
        left_segment_index: left_segment_index + 1,
        grouped:,
      )
    }
  }
}

fn insert_subpath_intersection(
  grouped: List(SubpathIntersection),
  point: Point,
  left_at left_at: SubpathParameter,
  right_parameters right_parameters: List(SubpathParameter),
  tolerance tolerance: Float,
) -> List(SubpathIntersection) {
  case grouped {
    [] -> [
      SubpathIntersection(point:, left_parameters: [left_at], right_parameters:),
    ]
    [first, ..rest] -> {
      case distance(first.point, point) <=. tolerance {
        True -> [
          SubpathIntersection(
            ..first,
            left_parameters: [left_at, ..first.left_parameters],
            right_parameters: list.append(
              right_parameters,
              first.right_parameters,
            ),
          ),
          ..rest
        ]
        False -> [
          first,
          ..insert_subpath_intersection(
            rest,
            point,
            left_at:,
            right_parameters:,
            tolerance:,
          )
        ]
      }
    }
  }
}

fn sort_subpath_intersections(
  intersections: List(SubpathIntersection),
  left: Subpath,
  right: Subpath,
  tolerance: Float,
) -> List(SubpathIntersection) {
  intersections
  |> list.map(fn(intersection) {
    SubpathIntersection(
      ..intersection,
      left_parameters: sort_unique_subpath_parameters(
        intersection.left_parameters,
        left,
        tolerance,
      ),
      right_parameters: sort_unique_subpath_parameters(
        intersection.right_parameters,
        right,
        tolerance,
      ),
    )
  })
  |> list.sort(by: compare_subpath_intersections)
}

fn compare_subpath_intersections(
  a: SubpathIntersection,
  b: SubpathIntersection,
) -> order.Order {
  case a.left_parameters, b.left_parameters {
    [a_first, ..], [b_first, ..] ->
      svg_path.subpath_parameters_compare(a_first, b_first)
    _, _ -> order.Eq
  }
}

fn sort_unique_subpath_parameters(
  parameters: List(SubpathParameter),
  subpath: Subpath,
  tolerance: Float,
) -> List(SubpathParameter) {
  parameters
  |> list.map(canonicalize_subpath_parameter_unchecked(_, subpath, tolerance))
  |> list.sort(by: svg_path.subpath_parameters_compare)
  |> dedupe_sorted_subpath_parameters(subpath, tolerance, accumulated: [])
  |> drop_closed_wrap_duplicate(subpath, tolerance)
}

fn dedupe_sorted_subpath_parameters(
  parameters: List(SubpathParameter),
  subpath: Subpath,
  tolerance: Float,
  accumulated accumulated: List(SubpathParameter),
) -> List(SubpathParameter) {
  case parameters, accumulated {
    [], _ -> list.reverse(accumulated)
    [first, ..rest], [] ->
      dedupe_sorted_subpath_parameters(rest, subpath, tolerance, accumulated: [
        first,
      ])
    [first, ..rest], [previous, ..] -> {
      case subpath_parameters_near(first, previous, subpath, tolerance) {
        True ->
          dedupe_sorted_subpath_parameters(
            rest,
            subpath,
            tolerance,
            accumulated:,
          )
        _ ->
          dedupe_sorted_subpath_parameters(
            rest,
            subpath,
            tolerance,
            accumulated: [first, ..accumulated],
          )
      }
    }
  }
}

fn canonicalize_subpath_parameter_unchecked(
  parameter: SubpathParameter,
  subpath: Subpath,
  tolerance: Float,
) -> SubpathParameter {
  let length = list.length(svg_path.subpath_segments(subpath))
  case parameter {
    SubpathParameter(segment_index:, t:) if t <=. tolerance ->
      SubpathParameter(segment_index:, t: 0.0)
    SubpathParameter(segment_index:, t:) if 1.0 -. t <=. tolerance -> {
      case segment_index < length - 1, svg_path.subpath_is_closed(subpath) {
        True, _ -> SubpathParameter(segment_index + 1, 0.0)
        False, True -> SubpathParameter(0, 0.0)
        False, False -> SubpathParameter(segment_index:, t: 1.0)
      }
    }
    _ -> parameter
  }
}

fn drop_closed_wrap_duplicate(
  parameters: List(SubpathParameter),
  subpath: Subpath,
  tolerance: Float,
) -> List(SubpathParameter) {
  case svg_path.subpath_is_closed(subpath), parameters {
    True, [first, second, ..rest] -> {
      let last = list.last(parameters)
      case last {
        Ok(last) ->
          case subpath_parameters_near(first, last, subpath, tolerance) {
            True -> [second, ..rest]
            False -> parameters
          }
        _ -> parameters
      }
    }
    _, _ -> parameters
  }
}

fn subpath_parameters_near(
  a: SubpathParameter,
  b: SubpathParameter,
  subpath: Subpath,
  tolerance: Float,
) -> Bool {
  subpath_parameter_addresses_near(a, b, subpath, tolerance)
  && subpath_parameter_positions_near(a, b, subpath, tolerance)
}

fn subpath_parameter_addresses_near(
  a: SubpathParameter,
  b: SubpathParameter,
  subpath: Subpath,
  tolerance: Float,
) -> Bool {
  let SubpathParameter(segment_index: a_index, t: a_t) = a
  let SubpathParameter(segment_index: b_index, t: b_t) = b
  let length = list.length(svg_path.subpath_segments(subpath))
  case a_index == b_index {
    True -> float.absolute_value(a_t -. b_t) <=. tolerance
    False ->
      adjacent_boundary_parameters_near(a_index, a_t, b_index, b_t, tolerance)
      || {
        svg_path.subpath_is_closed(subpath)
        && closed_wrap_boundary_parameters_near(
          a_index,
          a_t,
          b_index,
          b_t,
          length,
          tolerance,
        )
      }
  }
}

fn adjacent_boundary_parameters_near(
  a_index: Int,
  a_t: Float,
  b_index: Int,
  b_t: Float,
  tolerance: Float,
) -> Bool {
  case a_index + 1 == b_index {
    True -> float.absolute_value(b_t -. a_t +. 1.0) <=. tolerance
    False ->
      case b_index + 1 == a_index {
        True -> float.absolute_value(a_t -. b_t +. 1.0) <=. tolerance
        False -> False
      }
  }
}

fn closed_wrap_boundary_parameters_near(
  a_index: Int,
  a_t: Float,
  b_index: Int,
  b_t: Float,
  length: Int,
  tolerance: Float,
) -> Bool {
  case a_index == 0 && b_index == length - 1 {
    True -> float.absolute_value(a_t -. b_t +. 1.0) <=. tolerance
    False ->
      case b_index == 0 && a_index == length - 1 {
        True -> float.absolute_value(b_t -. a_t +. 1.0) <=. tolerance
        False -> False
      }
  }
}

fn subpath_parameter_positions_near(
  a: SubpathParameter,
  b: SubpathParameter,
  subpath: Subpath,
  tolerance: Float,
) -> Bool {
  let a_point = svg_path.subpath_point(subpath, at: a)
  let b_point = svg_path.subpath_point(subpath, at: b)
  case a_point, b_point {
    Ok(a_point), Ok(b_point) ->
      distance_squared(a_point, b_point) <=. tolerance *. tolerance
    _, _ -> False
  }
}

fn collect_path_self_intersections(
  subpaths: List(Subpath),
  options: SelfIntersectionOptions,
  subpath_index subpath_index: Int,
  found found: List(PathSelfIntersection),
) -> Result(List(PathSelfIntersection), Error) {
  case subpaths {
    [] -> Ok(found)
    [first, ..rest] -> {
      use found <- result.try(collect_path_self_intersections_inside_subpath(
        first,
        subpath_index,
        options,
        found:,
      ))
      use found <- result.try(collect_path_self_intersections_against_rest(
        first,
        subpath_index,
        rest,
        options,
        right_subpath_index: subpath_index + 1,
        found:,
      ))

      collect_path_self_intersections(
        rest,
        options,
        subpath_index: subpath_index + 1,
        found:,
      )
    }
  }
}

fn collect_path_self_intersections_inside_subpath(
  subpath: Subpath,
  subpath_index: Int,
  options: SelfIntersectionOptions,
  found found: List(PathSelfIntersection),
) -> Result(List(PathSelfIntersection), Error) {
  use intersections <- result.try(subpath_self_with(subpath, options:))

  Ok(
    list.fold(intersections, found, fn(found, intersection) {
      let SubpathSelfIntersection(point:, parameters:) = intersection
      let #(first, second) = parameters
      insert_path_self_intersection(
        found,
        point:,
        first: PathParameter(subpath_index:, at: first),
        second: PathParameter(subpath_index:, at: second),
        tolerance: options.distance_tolerance,
      )
    }),
  )
}

fn collect_path_self_intersections_against_rest(
  left: Subpath,
  left_subpath_index: Int,
  rights: List(Subpath),
  options: SelfIntersectionOptions,
  right_subpath_index right_subpath_index: Int,
  found found: List(PathSelfIntersection),
) -> Result(List(PathSelfIntersection), Error) {
  case rights {
    [] -> Ok(found)
    [right, ..rest] -> {
      let intersection_options =
        IntersectionOptions(
          tolerance: options.distance_tolerance,
          max_depth: default_intersection_max_depth,
        )
      use intersections <- result.try(subpath_with(
        left,
        right,
        options: intersection_options,
      ))
      let found =
        list.fold(intersections, found, fn(found, intersection) {
          insert_subpath_pair_self_intersections(
            found,
            intersection,
            left_subpath_index,
            right_subpath_index,
            options.distance_tolerance,
          )
        })

      collect_path_self_intersections_against_rest(
        left,
        left_subpath_index,
        rest,
        options,
        right_subpath_index: right_subpath_index + 1,
        found:,
      )
    }
  }
}

fn insert_subpath_pair_self_intersections(
  found: List(PathSelfIntersection),
  intersection: SubpathIntersection,
  left_subpath_index: Int,
  right_subpath_index: Int,
  tolerance: Float,
) -> List(PathSelfIntersection) {
  insert_path_self_intersections_for_left_parameters(
    found,
    intersection.point,
    intersection.left_parameters,
    intersection.right_parameters,
    left_subpath_index,
    right_subpath_index,
    tolerance,
  )
}

fn insert_path_self_intersections_for_left_parameters(
  found: List(PathSelfIntersection),
  point: Point,
  left_parameters: List(SubpathParameter),
  right_parameters: List(SubpathParameter),
  left_subpath_index: Int,
  right_subpath_index: Int,
  tolerance: Float,
) -> List(PathSelfIntersection) {
  case left_parameters {
    [] -> found
    [left, ..rest] -> {
      let found =
        insert_path_self_intersections_for_right_parameters(
          found,
          point,
          left,
          right_parameters,
          left_subpath_index,
          right_subpath_index,
          tolerance,
        )
      insert_path_self_intersections_for_left_parameters(
        found,
        point,
        rest,
        right_parameters,
        left_subpath_index,
        right_subpath_index,
        tolerance,
      )
    }
  }
}

fn insert_path_self_intersections_for_right_parameters(
  found: List(PathSelfIntersection),
  point: Point,
  left: SubpathParameter,
  right_parameters: List(SubpathParameter),
  left_subpath_index: Int,
  right_subpath_index: Int,
  tolerance: Float,
) -> List(PathSelfIntersection) {
  case right_parameters {
    [] -> found
    [right, ..rest] -> {
      let found =
        insert_path_self_intersection(
          found,
          point:,
          first: PathParameter(subpath_index: left_subpath_index, at: left),
          second: PathParameter(subpath_index: right_subpath_index, at: right),
          tolerance:,
        )
      insert_path_self_intersections_for_right_parameters(
        found,
        point,
        left,
        rest,
        left_subpath_index,
        right_subpath_index,
        tolerance,
      )
    }
  }
}

fn insert_path_self_intersection(
  found: List(PathSelfIntersection),
  point point: Point,
  first first: PathParameter,
  second second: PathParameter,
  tolerance tolerance: Float,
) -> List(PathSelfIntersection) {
  let #(first, second) = ordered_path_parameter_pair(first, second)

  case found {
    [] -> [PathSelfIntersection(point:, parameters: #(first, second))]
    [existing, ..rest] -> {
      let PathSelfIntersection(point: existing_point, parameters:) = existing
      let #(existing_first, existing_second) = parameters
      case
        distance(existing_point, point) <=. tolerance
        && same_path_parameter_pair(
          first,
          second,
          existing_first,
          existing_second,
          tolerance,
        )
      {
        True -> found
        False -> [
          existing,
          ..insert_path_self_intersection(
            rest,
            point:,
            first:,
            second:,
            tolerance:,
          )
        ]
      }
    }
  }
}

fn same_path_parameter_pair(
  first: PathParameter,
  second: PathParameter,
  existing_first: PathParameter,
  existing_second: PathParameter,
  tolerance: Float,
) -> Bool {
  same_path_parameter(first, existing_first, tolerance)
  && same_path_parameter(second, existing_second, tolerance)
}

fn same_path_parameter(
  left: PathParameter,
  right: PathParameter,
  tolerance: Float,
) -> Bool {
  let PathParameter(subpath_index: left_index, at: left_at) = left
  let PathParameter(subpath_index: right_index, at: right_at) = right
  left_index == right_index
  && same_subpath_parameter(left_at, right_at, tolerance)
}

fn ordered_path_parameter_pair(
  first: PathParameter,
  second: PathParameter,
) -> #(PathParameter, PathParameter) {
  case svg_path.path_parameters_compare(first, second) {
    order.Gt -> #(second, first)
    order.Lt | order.Eq -> #(first, second)
  }
}

fn sort_path_self_intersections(
  intersections: List(PathSelfIntersection),
) -> List(PathSelfIntersection) {
  intersections
  |> list.sort(by: fn(a, b) {
    let PathSelfIntersection(parameters: a_parameters, ..) = a
    let PathSelfIntersection(parameters: b_parameters, ..) = b
    let #(a_first, a_second) = a_parameters
    let #(b_first, b_second) = b_parameters

    case svg_path.path_parameters_compare(a_first, b_first) {
      order.Eq -> svg_path.path_parameters_compare(a_second, b_second)
      order -> order
    }
  })
}

fn collect_path_intersections(
  left_subpaths: List(Subpath),
  right_subpaths: List(Subpath),
  options: IntersectionOptions,
  permit_overlapping_pairs permit_overlapping_pairs: Bool,
  left_subpath_index left_subpath_index: Int,
  grouped grouped: List(PathIntersection),
) -> Result(List(PathIntersection), Error) {
  case left_subpaths {
    [] -> Ok(grouped)
    [left_subpath, ..rest] -> {
      use grouped <- result.try(collect_path_intersections_for_left_subpath(
        left_subpath,
        left_subpath_index,
        right_subpaths,
        options,
        permit_overlapping_pairs:,
        right_subpath_index: 0,
        grouped:,
      ))

      collect_path_intersections(
        rest,
        right_subpaths,
        options,
        permit_overlapping_pairs:,
        left_subpath_index: left_subpath_index + 1,
        grouped:,
      )
    }
  }
}

fn collect_path_intersections_for_left_subpath(
  left_subpath: Subpath,
  left_subpath_index: Int,
  right_subpaths: List(Subpath),
  options: IntersectionOptions,
  permit_overlapping_pairs permit_overlapping_pairs: Bool,
  right_subpath_index right_subpath_index: Int,
  grouped grouped: List(PathIntersection),
) -> Result(List(PathIntersection), Error) {
  case right_subpaths {
    [] -> Ok(grouped)
    [right_subpath, ..rest] -> {
      use intersections <- result.try(
        collect_subpath_intersections(
          svg_path.subpath_segments(left_subpath),
          right_subpath,
          options,
          permit_overlapping_pairs:,
          left_segment_index: 0,
          grouped: [],
        ),
      )
      let intersections =
        sort_subpath_intersections(
          intersections,
          left_subpath,
          right_subpath,
          options.tolerance,
        )
      let grouped =
        list.fold(intersections, grouped, fn(grouped, intersection) {
          insert_path_intersection(
            grouped,
            lift_subpath_intersection(
              intersection,
              left_subpath_index:,
              right_subpath_index:,
            ),
            tolerance: options.tolerance,
          )
        })

      collect_path_intersections_for_left_subpath(
        left_subpath,
        left_subpath_index,
        rest,
        options,
        permit_overlapping_pairs:,
        right_subpath_index: right_subpath_index + 1,
        grouped:,
      )
    }
  }
}

fn lift_subpath_intersection(
  intersection: SubpathIntersection,
  left_subpath_index left_subpath_index: Int,
  right_subpath_index right_subpath_index: Int,
) -> PathIntersection {
  PathIntersection(
    point: intersection.point,
    left_parameters: list.map(intersection.left_parameters, fn(parameter) {
      PathParameter(subpath_index: left_subpath_index, at: parameter)
    }),
    right_parameters: list.map(intersection.right_parameters, fn(parameter) {
      PathParameter(subpath_index: right_subpath_index, at: parameter)
    }),
  )
}

fn insert_path_intersection(
  grouped: List(PathIntersection),
  intersection: PathIntersection,
  tolerance tolerance: Float,
) -> List(PathIntersection) {
  case grouped {
    [] -> [intersection]
    [first, ..rest] -> {
      case distance(first.point, intersection.point) <=. tolerance {
        True -> [
          PathIntersection(
            ..first,
            left_parameters: list.append(
              intersection.left_parameters,
              first.left_parameters,
            ),
            right_parameters: list.append(
              intersection.right_parameters,
              first.right_parameters,
            ),
          ),
          ..rest
        ]
        False -> [
          first,
          ..insert_path_intersection(rest, intersection, tolerance:)
        ]
      }
    }
  }
}

fn sort_path_intersections(
  intersections: List(PathIntersection),
) -> List(PathIntersection) {
  intersections
  |> list.map(fn(intersection) {
    PathIntersection(
      ..intersection,
      left_parameters: sort_unique_path_parameters(intersection.left_parameters),
      right_parameters: sort_unique_path_parameters(
        intersection.right_parameters,
      ),
    )
  })
  |> list.sort(by: compare_path_intersections)
}

fn compare_path_intersections(
  a: PathIntersection,
  b: PathIntersection,
) -> order.Order {
  case a.left_parameters, b.left_parameters {
    [a_first, ..], [b_first, ..] ->
      svg_path.path_parameters_compare(a_first, b_first)
    _, _ -> order.Eq
  }
}

fn sort_unique_path_parameters(
  parameters: List(PathParameter),
) -> List(PathParameter) {
  parameters
  |> list.sort(by: svg_path.path_parameters_compare)
  |> dedupe_sorted_path_parameters(accumulated: [])
}

fn dedupe_sorted_path_parameters(
  parameters: List(PathParameter),
  accumulated accumulated: List(PathParameter),
) -> List(PathParameter) {
  case parameters, accumulated {
    [], _ -> list.reverse(accumulated)
    [first, ..rest], [] ->
      dedupe_sorted_path_parameters(rest, accumulated: [first])
    [first, ..rest], [previous, ..] -> {
      case svg_path.path_parameters_compare(first, previous) {
        order.Eq -> dedupe_sorted_path_parameters(rest, accumulated:)
        _ ->
          dedupe_sorted_path_parameters(rest, accumulated: [
            first,
            ..accumulated
          ])
      }
    }
  }
}

fn line_line_intersections(
  left_start: Point,
  left_end: Point,
  right_start: Point,
  right_end: Point,
  tolerance: Float,
) -> Result(List(SegmentIntersection), Error) {
  let left_direction = point_difference(left_end, left_start)
  let right_direction = point_difference(right_end, right_start)
  let left_length_squared = dot(left_direction, left_direction)
  let right_length_squared = dot(right_direction, right_direction)

  case
    left_length_squared <=. tolerance *. tolerance,
    right_length_squared <=. tolerance *. tolerance
  {
    True, True -> {
      case distance(left_start, right_start) <=. tolerance {
        True ->
          Ok([
            SegmentIntersection(
              left_t: 0.0,
              right_t: 0.0,
              point: midpoint(left_start, right_start),
            ),
          ])
        False -> Ok([])
      }
    }
    True, False -> {
      case
        point_on_line_segment(left_start, right_start, right_end, tolerance)
      {
        True ->
          Ok([
            SegmentIntersection(
              left_t: 0.0,
              right_t: line_projection_t(left_start, right_start, right_end),
              point: left_start,
            ),
          ])
        False -> Ok([])
      }
    }
    False, True -> {
      case point_on_line_segment(right_start, left_start, left_end, tolerance) {
        True ->
          Ok([
            SegmentIntersection(
              left_t: line_projection_t(right_start, left_start, left_end),
              right_t: 0.0,
              point: right_start,
            ),
          ])
        False -> Ok([])
      }
    }
    False, False -> {
      let start_difference = point_difference(right_start, left_start)
      let denominator = cross(left_direction, right_direction)

      case float.absolute_value(denominator) <=. tolerance {
        True -> {
          case
            float.absolute_value(cross(start_difference, left_direction))
            <=. tolerance
          {
            True ->
              collinear_line_intersections(
                left_start,
                left_end,
                right_start,
                right_end,
                tolerance,
              )
            False -> Ok([])
          }
        }
        False -> {
          let left_t = cross(start_difference, right_direction) /. denominator
          let right_t = cross(start_difference, left_direction) /. denominator

          case
            in_unit_range(left_t, tolerance)
            && in_unit_range(right_t, tolerance)
          {
            True -> {
              let left_t = clamp01(left_t)
              let right_t = clamp01(right_t)

              Ok([
                SegmentIntersection(
                  left_t:,
                  right_t:,
                  point: interpolate(left_start, left_end, left_t),
                ),
              ])
            }
            False -> Ok([])
          }
        }
      }
    }
  }
}

fn collinear_line_intersections(
  left_start: Point,
  left_end: Point,
  right_start: Point,
  right_end: Point,
  tolerance: Float,
) -> Result(List(SegmentIntersection), Error) {
  let right_start_t = line_projection_t(right_start, left_start, left_end)
  let right_end_t = line_projection_t(right_end, left_start, left_end)
  let overlap_start = float.max(0.0, float.min(right_start_t, right_end_t))
  let overlap_end = float.min(1.0, float.max(right_start_t, right_end_t))

  case overlap_end <. overlap_start -. tolerance {
    True -> Ok([])
    False -> {
      case overlap_end -. overlap_start <=. tolerance {
        True -> {
          let left_t = clamp01({ overlap_start +. overlap_end } /. 2.0)
          let point = interpolate(left_start, left_end, left_t)

          Ok([
            SegmentIntersection(
              left_t:,
              right_t: line_projection_t(point, right_start, right_end)
                |> clamp01,
              point:,
            ),
          ])
        }
        False -> Error(OverlappingSegments)
      }
    }
  }
}

fn line_segment_intersections(
  line_start line_start: Point,
  line_end line_end: Point,
  line_is_left line_is_left: Bool,
  segment segment: Segment,
  options options: IntersectionOptions,
) -> Result(List(SegmentIntersection), Error) {
  let line_direction = point_difference(line_end, line_start)

  case segment_lies_on_line(segment, line_start, line_end, options.tolerance) {
    True -> Error(OverlappingSegments)
    False -> {
      case
        svg_path.segment_crossings_with(
          segment,
          where: fn(point) {
            cross(line_direction, point_difference(point, line_start))
          },
          options: svg_path.CrossingOptions(
            samples: 100,
            tolerance: options.tolerance,
            max_iterations: options.max_depth * 4,
          ),
        )
      {
        Error(error) -> Error(error)
        Ok(segment_ts) -> {
          line_segment_intersections_from_ts(
            line_start,
            line_end,
            line_is_left,
            segment,
            segment_ts,
            options.tolerance,
            [],
          )
        }
      }
    }
  }
}

fn line_segment_intersections_from_ts(
  line_start: Point,
  line_end: Point,
  line_is_left: Bool,
  segment: Segment,
  segment_ts: List(Float),
  tolerance: Float,
  intersections: List(SegmentIntersection),
) -> Result(List(SegmentIntersection), Error) {
  case segment_ts {
    [] -> Ok(intersections)
    [segment_t, ..rest] -> {
      case svg_path.segment_point(segment, at: segment_t) {
        Error(error) -> Error(error)
        Ok(point) -> {
          let line_t = line_projection_t(point, line_start, line_end)

          case in_unit_range(line_t, tolerance) {
            True -> {
              let intersection = case line_is_left {
                True ->
                  SegmentIntersection(
                    left_t: clamp01(line_t),
                    right_t: clamp01(segment_t),
                    point:,
                  )
                False ->
                  SegmentIntersection(
                    left_t: clamp01(segment_t),
                    right_t: clamp01(line_t),
                    point:,
                  )
              }

              line_segment_intersections_from_ts(
                line_start,
                line_end,
                line_is_left,
                segment,
                rest,
                tolerance,
                insert_intersection(intersections, intersection, tolerance),
              )
            }
            False ->
              line_segment_intersections_from_ts(
                line_start,
                line_end,
                line_is_left,
                segment,
                rest,
                tolerance,
                intersections,
              )
          }
        }
      }
    }
  }
}

fn curve_curve_intersections(
  left: Segment,
  right: Segment,
  options: IntersectionOptions,
) -> Result(List(SegmentIntersection), Error) {
  collect_curve_curve_intersections(
    IntersectionPiece(segment: left, from: 0.0, to: 1.0),
    IntersectionPiece(segment: right, from: 0.0, to: 1.0),
    options,
    remaining_depth: options.max_depth,
    intersections: [],
  )
}

fn collect_curve_curve_intersections(
  left: IntersectionPiece,
  right: IntersectionPiece,
  options: IntersectionOptions,
  remaining_depth remaining_depth: Int,
  intersections intersections: List(SegmentIntersection),
) -> Result(List(SegmentIntersection), Error) {
  case
    svg_path.segment_bounding_box(left.segment),
    svg_path.segment_bounding_box(right.segment)
  {
    Error(error), _ | _, Error(error) -> Error(error)
    Ok(left_box), Ok(right_box) -> {
      case boxes_overlap(left_box, right_box, options.tolerance) {
        False -> Ok(intersections)
        True -> {
          case
            remaining_depth <= 0
            || {
              svg_path.bounding_box_diameter(left_box) <=. options.tolerance
              && svg_path.bounding_box_diameter(right_box) <=. options.tolerance
            }
          {
            True -> {
              case
                minimized_intersections_from_pieces(
                  left,
                  right,
                  intersection_piece_tolerance(left, right, options.tolerance),
                )
              {
                Error(error) -> Error(error)
                Ok(found) ->
                  Ok(insert_intersections(
                    intersections,
                    found,
                    intersection_dedupe_tolerance(options.tolerance),
                  ))
              }
            }
            False -> {
              let split_left =
                svg_path.bounding_box_diameter(left_box)
                >=. svg_path.bounding_box_diameter(right_box)

              case split_left {
                True -> {
                  let #(first, second) = split_intersection_piece(left)

                  case
                    collect_curve_curve_intersections(
                      first,
                      right,
                      options,
                      remaining_depth: remaining_depth - 1,
                      intersections:,
                    )
                  {
                    Error(error) -> Error(error)
                    Ok(intersections) ->
                      collect_curve_curve_intersections(
                        second,
                        right,
                        options,
                        remaining_depth: remaining_depth - 1,
                        intersections:,
                      )
                  }
                }
                False -> {
                  let #(first, second) = split_intersection_piece(right)

                  case
                    collect_curve_curve_intersections(
                      left,
                      first,
                      options,
                      remaining_depth: remaining_depth - 1,
                      intersections:,
                    )
                  {
                    Error(error) -> Error(error)
                    Ok(intersections) ->
                      collect_curve_curve_intersections(
                        left,
                        second,
                        options,
                        remaining_depth: remaining_depth - 1,
                        intersections:,
                      )
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

fn split_intersection_piece(
  piece: IntersectionPiece,
) -> #(IntersectionPiece, IntersectionPiece) {
  let assert Ok(#(left, right)) = svg_path.segment_split(piece.segment, at: 0.5)
  let middle = { piece.from +. piece.to } /. 2.0

  #(
    IntersectionPiece(segment: left, from: piece.from, to: middle),
    IntersectionPiece(segment: right, from: middle, to: piece.to),
  )
}

fn minimized_intersections_from_pieces(
  left: IntersectionPiece,
  right: IntersectionPiece,
  tolerance: Float,
) -> Result(List(SegmentIntersection), Error) {
  use best <- result.try(best_piece_distance(
    left.segment,
    right.segment,
    tolerance,
  ))
  let #(left_local_t, right_local_t, distance_squared) = best

  case distance_squared <=. tolerance *. tolerance {
    False -> Ok([])
    True -> {
      case
        svg_path.segment_point(left.segment, at: left_local_t),
        svg_path.segment_point(right.segment, at: right_local_t)
      {
        Error(error), _ | _, Error(error) -> Error(error)
        Ok(left_point), Ok(right_point) ->
          Ok([
            SegmentIntersection(
              left_t: interpolate_float(left.from, left.to, left_local_t),
              right_t: interpolate_float(right.from, right.to, right_local_t),
              point: midpoint(left_point, right_point),
            ),
          ])
      }
    }
  }
}

fn intersection_piece_tolerance(
  left: IntersectionPiece,
  right: IntersectionPiece,
  tolerance: Float,
) -> Float {
  case
    svg_path.segment_bounding_box(left.segment),
    svg_path.segment_bounding_box(right.segment)
  {
    Ok(left_box), Ok(right_box) ->
      float.max(
        tolerance,
        float.max(
          svg_path.bounding_box_diameter(left_box),
          svg_path.bounding_box_diameter(right_box),
        ),
      )
    _, _ -> tolerance
  }
}

fn best_piece_distance(
  left: Segment,
  right: Segment,
  tolerance: Float,
) -> Result(#(Float, Float, Float), Error) {
  let starts = [#(0.0, 0.0), #(0.0, 1.0), #(1.0, 0.0), #(1.0, 1.0), #(0.5, 0.5)]
  use best <- result.try(best_piece_distance_raw_start(
    left,
    right,
    starts:,
    best: Error(Nil),
  ))
  case best.2 <=. tolerance *. tolerance {
    True -> Ok(best)
    False ->
      best_piece_distance_from_starts(left, right, starts:, best:, tolerance:)
  }
}

fn best_piece_distance_raw_start(
  left: Segment,
  right: Segment,
  starts starts: List(#(Float, Float)),
  best best: Result(#(Float, Float, Float), Nil),
) -> Result(#(Float, Float, Float), Error) {
  case starts {
    [] -> {
      let assert Ok(best) = best
      Ok(best)
    }
    [start, ..rest] -> {
      let #(left_t, right_t) = start
      use distance_squared <- result.try(segment_pair_distance_squared(
        left,
        left_t,
        right,
        right_t,
      ))
      let candidate = #(left_t, right_t, distance_squared)
      let best = case best {
        Error(_) -> Ok(candidate)
        Ok(best) ->
          case candidate.2 <. best.2 {
            True -> Ok(candidate)
            False -> Ok(best)
          }
      }
      best_piece_distance_raw_start(left, right, starts: rest, best:)
    }
  }
}

fn best_piece_distance_from_starts(
  left: Segment,
  right: Segment,
  starts starts: List(#(Float, Float)),
  best best: #(Float, Float, Float),
  tolerance tolerance: Float,
) -> Result(#(Float, Float, Float), Error) {
  case best.2 <=. tolerance *. tolerance, starts {
    True, _ -> Ok(best)
    _, [] -> Ok(best)
    False, [start, ..rest] -> {
      let #(left_t, right_t) = start
      use candidate <- result.try(minimize_piece_distance(
        left,
        right,
        left_t,
        right_t,
        tolerance:,
        step: 0.25,
        iterations: 24,
      ))
      let best = case candidate.2 <. best.2 {
        True -> candidate
        False -> best
      }
      best_piece_distance_from_starts(
        left,
        right,
        starts: rest,
        best:,
        tolerance:,
      )
    }
  }
}

fn minimize_piece_distance(
  left: Segment,
  right: Segment,
  left_t: Float,
  right_t: Float,
  tolerance tolerance: Float,
  step step: Float,
  iterations iterations: Int,
) -> Result(#(Float, Float, Float), Error) {
  use distance_squared <- result.try(segment_pair_distance_squared(
    left,
    left_t,
    right,
    right_t,
  ))
  minimize_piece_distance_loop(
    left,
    right,
    left_t,
    right_t,
    distance_squared,
    tolerance:,
    step:,
    iterations:,
  )
}

fn minimize_piece_distance_loop(
  left: Segment,
  right: Segment,
  left_t: Float,
  right_t: Float,
  best_distance_squared: Float,
  tolerance tolerance: Float,
  step step: Float,
  iterations iterations: Int,
) -> Result(#(Float, Float, Float), Error) {
  case
    best_distance_squared <=. tolerance *. tolerance
    || iterations <= 0
    || step <=. 0.000000000001
  {
    True -> Ok(#(left_t, right_t, best_distance_squared))
    False -> {
      use next <- result.try(best_piece_neighbor(
        left,
        right,
        left_t,
        right_t,
        best_distance_squared,
        step,
      ))
      let #(next_left_t, next_right_t, next_distance_squared) = next
      case next_distance_squared <. best_distance_squared {
        True ->
          minimize_piece_distance_loop(
            left,
            right,
            next_left_t,
            next_right_t,
            next_distance_squared,
            tolerance:,
            step:,
            iterations: iterations - 1,
          )
        False ->
          minimize_piece_distance_loop(
            left,
            right,
            left_t,
            right_t,
            best_distance_squared,
            tolerance:,
            step: step /. 2.0,
            iterations: iterations - 1,
          )
      }
    }
  }
}

fn best_piece_neighbor(
  left: Segment,
  right: Segment,
  left_t: Float,
  right_t: Float,
  best_distance_squared: Float,
  step: Float,
) -> Result(#(Float, Float, Float), Error) {
  best_piece_neighbor_loop(
    left,
    right,
    candidates: [
      #(left_t -. step, right_t),
      #(left_t +. step, right_t),
      #(left_t, right_t -. step),
      #(left_t, right_t +. step),
      #(left_t -. step, right_t -. step),
      #(left_t -. step, right_t +. step),
      #(left_t +. step, right_t -. step),
      #(left_t +. step, right_t +. step),
    ],
    best: #(left_t, right_t, best_distance_squared),
  )
}

fn best_piece_neighbor_loop(
  left: Segment,
  right: Segment,
  candidates candidates: List(#(Float, Float)),
  best best: #(Float, Float, Float),
) -> Result(#(Float, Float, Float), Error) {
  case candidates {
    [] -> Ok(best)
    [candidate, ..rest] -> {
      let #(left_t, right_t) = candidate
      let left_t = clamp01(left_t)
      let right_t = clamp01(right_t)
      use distance_squared <- result.try(segment_pair_distance_squared(
        left,
        left_t,
        right,
        right_t,
      ))
      let best = case distance_squared <. best.2 {
        True -> #(left_t, right_t, distance_squared)
        False -> best
      }
      best_piece_neighbor_loop(left, right, candidates: rest, best:)
    }
  }
}

fn segment_pair_distance_squared(
  left: Segment,
  left_t: Float,
  right: Segment,
  right_t: Float,
) -> Result(Float, Error) {
  case
    svg_path.segment_point(left, at: left_t),
    svg_path.segment_point(right, at: right_t)
  {
    Error(error), _ | _, Error(error) -> Error(error)
    Ok(left_point), Ok(right_point) -> {
      let dx = left_point.x -. right_point.x
      let dy = left_point.y -. right_point.y
      Ok(dx *. dx +. dy *. dy)
    }
  }
}

fn boxes_overlap(
  left: BoundingBox,
  right: BoundingBox,
  tolerance: Float,
) -> Bool {
  left.min.x <=. right.max.x +. tolerance
  && left.max.x +. tolerance >=. right.min.x
  && left.min.y <=. right.max.y +. tolerance
  && left.max.y +. tolerance >=. right.min.y
}

fn segment_lies_on_line(
  segment: Segment,
  line_start: Point,
  line_end: Point,
  tolerance: Float,
) -> Bool {
  let direction = point_difference(line_end, line_start)

  case segment_defining_points(segment) {
    None -> False
    Some(points) -> {
      list.all(points, fn(point) {
        float.absolute_value(cross(
          direction,
          point_difference(point, line_start),
        ))
        <=. tolerance
      })
      && segment_projection_overlaps_line(
        points,
        line_start,
        line_end,
        tolerance,
      )
    }
  }
}

fn segment_projection_overlaps_line(
  points: List(Point),
  line_start: Point,
  line_end: Point,
  tolerance: Float,
) -> Bool {
  case points {
    [] -> False
    [first, ..rest] -> {
      let first_t = line_projection_t(first, line_start, line_end)
      let #(min_t, max_t) =
        list.fold(rest, #(first_t, first_t), fn(range, point) {
          let #(min_t, max_t) = range
          let t = line_projection_t(point, line_start, line_end)

          #(float.min(min_t, t), float.max(max_t, t))
        })

      float.min(1.0, max_t) -. float.max(0.0, min_t) >. tolerance
    }
  }
}

fn segment_defining_points(segment: Segment) -> Option(List(Point)) {
  case segment {
    Line(start:, end:) -> Some([start, end])
    QuadraticBezier(start:, control:, end:) -> Some([start, control, end])
    CubicBezier(start:, control1:, control2:, end:) ->
      Some([start, control1, control2, end])
    Arc(..) -> None
  }
}

fn point_on_line_segment(
  point: Point,
  start: Point,
  end: Point,
  tolerance: Float,
) -> Bool {
  let direction = point_difference(end, start)
  float.absolute_value(cross(direction, point_difference(point, start)))
  <=. tolerance
  && in_unit_range(line_projection_t(point, start, end), tolerance)
}

fn line_projection_t(point: Point, start: Point, end: Point) -> Float {
  let direction = point_difference(end, start)
  let length_squared = dot(direction, direction)

  case length_squared == 0.0 {
    True -> 0.0
    False -> dot(point_difference(point, start), direction) /. length_squared
  }
}

fn in_unit_range(value: Float, tolerance: Float) -> Bool {
  value >=. 0.0 -. tolerance && value <=. 1.0 +. tolerance
}

fn insert_intersection(
  intersections: List(SegmentIntersection),
  intersection: SegmentIntersection,
  tolerance: Float,
) -> List(SegmentIntersection) {
  case intersections {
    [] -> [intersection]
    [first, ..rest] -> {
      case
        distance(first.point, intersection.point) <=. tolerance
        || {
          float.absolute_value(first.left_t -. intersection.left_t)
          <=. tolerance
          && float.absolute_value(first.right_t -. intersection.right_t)
          <=. tolerance
        }
      {
        True -> [first, ..rest]
        False -> [first, ..insert_intersection(rest, intersection, tolerance)]
      }
    }
  }
}

fn insert_intersections(
  intersections: List(SegmentIntersection),
  new_intersections: List(SegmentIntersection),
  tolerance: Float,
) -> List(SegmentIntersection) {
  list.fold(new_intersections, intersections, fn(intersections, intersection) {
    insert_intersection(intersections, intersection, tolerance)
  })
}

fn intersection_dedupe_tolerance(tolerance: Float) -> Float {
  float.max(tolerance *. 1_000_000.0, 0.000001)
}

fn cross(a: Point, b: Point) -> Float {
  a.x *. b.y -. a.y *. b.x
}

fn interpolate_float(start: Float, end: Float, t: Float) -> Float {
  start +. { end -. start } *. t
}

fn to_bezier_point(point: Point) -> bezier.BezierPoint {
  bezier.BezierPoint(point.x, point.y)
}

fn segment_to_bezier_data(segment: Segment) -> bezier.BezierData {
  case segment {
    Line(start:, end:) -> {
      bezier.LinearBezierData(
        start: to_bezier_point(start),
        end: to_bezier_point(end),
      )
    }
    QuadraticBezier(start:, control:, end:) -> {
      bezier.QuadraticBezierData(
        start: to_bezier_point(start),
        control: to_bezier_point(control),
        end: to_bezier_point(end),
      )
    }
    CubicBezier(start:, control1:, control2:, end:) -> {
      bezier.CubicBezierData(
        start: to_bezier_point(start),
        control1: to_bezier_point(control1),
        control2: to_bezier_point(control2),
        end: to_bezier_point(end),
      )
    }
    Arc(..) -> panic as "svg_path.segment_to_bezier_data received an arc"
  }
}

fn from_bezier_point(point: bezier.BezierPoint) -> Point {
  Point(point.x, point.y)
}

fn interpolate(start: Point, end: Point, t: Float) -> Point {
  Point(
    start.x +. { end.x -. start.x } *. t,
    start.y +. { end.y -. start.y } *. t,
  )
}

fn distance(a: Point, b: Point) -> Float {
  distance_squared(a, b) |> float_square_root
}

fn distance_squared(a: Point, b: Point) -> Float {
  let dx = a.x -. b.x
  let dy = a.y -. b.y
  dx *. dx +. dy *. dy
}

fn float_square_root(value: Float) -> Float {
  let assert Ok(root) = float.square_root(value)
  root
}

fn midpoint(a: Point, b: Point) -> Point {
  Point({ a.x +. b.x } /. 2.0, { a.y +. b.y } /. 2.0)
}
