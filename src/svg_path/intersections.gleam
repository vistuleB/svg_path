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
  type PathParameter, type PathPathProjection, type PathSelfIntersection,
  type Point, type Segment, type SegmentIntersection, type SegmentPathProjection,
  type SegmentSegmentProjection, type SegmentSubpathProjection,
  type SelfIntersectionOptions, type Subpath, type SubpathIntersection,
  type SubpathParameter, type SubpathPathProjection,
  type SubpathSelfIntersection, type SubpathSubpathProjection, Arc, CubicBezier,
  EmptyPath, EmptySubpath, EmptySubpaths,
  InternalOverlapClassificationInconsistency,
  InternalUncertifiedSegmentIntersection, InvalidIntersectionMaxDepth,
  InvalidIntersectionParameterSnapExponent, InvalidIntersectionTolerance,
  InvalidSelfIntersectionDistanceTolerance,
  InvalidSelfIntersectionMinimumArcLengthSeparation, Line, OverlappingSegments,
  PathIntersection, PathParameter, PathPathProjection, PathSelfIntersection,
  Point, QuadraticBezier, SegmentIntersection, SegmentPathProjection,
  SegmentSegmentProjection, SegmentSubpathProjection, SubpathIntersection,
  SubpathParameter, SubpathPathProjection, SubpathSelfIntersection,
  SubpathSubpathProjection,
}
import svg_path/bezier
import svg_path/internal/number
import svg_path/overlap_detection
import svg_path/point

const default_intersection_tolerance = 0.000000001

const default_intersection_max_depth = 48

const parameter_snap_distance_tie_slack = 0.000000000001

const terminal_subdivision_tolerance = 0.01

const terminal_grid_margin = 0.0

const default_classification_angular_tolerance = 0.0000001

const default_classification_distance_tolerance = 0.000000000001

const default_classification_initial_arc_length = 0.000001

const default_classification_maximum_arc_length = 0.25

const default_classification_max_sampling_steps = 18

/// Options for classifying one addressed subpath intersection.
pub type ClassificationOptions {
  ClassificationOptions(
    /// Options used to recover singularity-safe path directions.
    direction_options: svg_path.DirectionOptions,
    /// Angles at or below this many degrees are treated as coincident.
    /// Zero compares direction headings exactly.
    angular_tolerance: Float,
    /// Minimum trusted path-coordinate distance from the intersection.
    distance_tolerance: Float,
    /// Length options used to locate samples along each subpath.
    length_options: svg_path.LengthOptions,
    /// First traveled distance used for nontransverse branch sampling.
    initial_arc_length: Float,
    /// Largest traveled distance permitted for local branch sampling.
    maximum_arc_length: Float,
    /// Maximum number of successively doubled arc-length samples.
    max_sampling_steps: Int,
  )
}

/// Errors returned while classifying subpath intersections.
pub type ClassificationError {
  /// An underlying path direction query failed.
  PathError(svg_path.Error)

  /// Angular tolerance must be finite and in `[0, 180)` degrees.
  InvalidAngularTolerance(Float)

  /// Distance tolerance must be finite and non-negative.
  InvalidClassificationDistanceTolerance(Float)

  /// Initial arc length must be finite and greater than zero.
  InvalidClassificationInitialArcLength(Float)

  /// Maximum arc length must be finite and at least the initial arc length.
  InvalidClassificationMaximumArcLength(Float)

  /// At least one sampling step is required.
  InvalidClassificationMaxSamplingSteps(Int)
}

/// The oriented sense in which the second traversal crosses the first.
pub type CrossingDirection {
  Clockwise
  Counterclockwise
}

/// The relative traversal direction at a tangential contact.
pub type TouchingDirection {
  SimilarlyDirected
  OppositelyDirected
}

/// Clockwise order of two outward-pointing sampled rays near a nontransverse
/// contact.
///
/// On the incoming side, each ray points from the intersection backward along
/// its traversal, opposite to the incoming traversal direction. On the
/// outgoing side, each ray points forward along its traversal. Oppositely
/// directed contacts compare the incoming branch of one traversal with the
/// outgoing branch of the other so that each value describes one geometric
/// side of the contact.
pub type TouchingOrder {
  ClockwiseFromFirstToSecond
  ClockwiseFromSecondToFirst
  IndeterminateTouchingOrder
}

/// An endpoint of an open subpath traversal.
pub type SubpathEndpoint {
  StartEndpoint
  EndEndpoint
}

/// Which endpoint/interior relationship occurs at an intersection.
pub type EndpointContact {
  FirstEndpointToSecondInterior(first: SubpathEndpoint)
  FirstInteriorToSecondEndpoint(second: SubpathEndpoint)
  EndpointToEndpoint(first: SubpathEndpoint, second: SubpathEndpoint)
}

/// The four clockwise apertures between the two subpath traversal directions.
///
/// Values are angles in degrees in `[0, 360)`. Unlike `TouchingOrder`, these
/// fields use traversal-oriented directions directly: an incoming direction
/// points toward the intersection and an outgoing direction points away from
/// it. In particular, the incoming apertures are not measured between the
/// negated, outward-pointing incoming directions.
pub type IntersectionApertures {
  IntersectionApertures(
    first_incoming_to_second_incoming: Float,
    first_incoming_to_second_outgoing: Float,
    first_outgoing_to_second_incoming: Float,
    first_outgoing_to_second_outgoing: Float,
  )
}

/// The local topology of one addressed subpath intersection.
pub type IntersectionClassification {
  /// The two traversals pass through one another.
  Crossing(direction: CrossingDirection, apertures: IntersectionApertures)

  /// The traversals meet without alternating around the intersection.
  ///
  /// `incoming_order` and `outgoing_order` describe the visible geometric
  /// branches using outward-pointing rays sampled at equal arc lengths. The
  /// `apertures` payload instead records the exact traversal-direction
  /// convention documented by `IntersectionApertures`.
  Touching(
    direction: TouchingDirection,
    incoming_order: TouchingOrder,
    outgoing_order: TouchingOrder,
    apertures: IntersectionApertures,
  )

  /// At least one address is an endpoint of an open subpath.
  EndpointContact(EndpointContact)

  /// A required local direction could not be recovered.
  Indeterminate
}

/// One parameter pair and its local intersection classification.
pub type ClassifiedSubpathIntersection {
  ClassifiedSubpathIntersection(
    first_parameter: SubpathParameter,
    second_parameter: SubpathParameter,
    classification: IntersectionClassification,
  )
}

/// Optional cleanup for segment-intersection parameters.
pub type ParameterSnap {
  /// Keep raw solver parameters.
  NoParameterSnap

  /// Suggest decimal-grid and third-tail parameter candidates at `10^-exponent`.
  ///
  /// Snapped candidates are only kept when their evaluated geometric distance
  /// is no worse than the raw candidate, up to a small internal tie slack.
  DecimalParameterSnap(exponent: Int)
}

/// Options for finding segment, subpath, and path intersections.
pub type IntersectionOptions {
  IntersectionOptions(
    /// Path-coordinate distance used for geometric coincidence tests.
    tolerance: Float,
    /// Maximum recursive subdivision depth for one segment pair.
    max_depth: Int,
    /// Optional parameter cleanup applied before final deduplication.
    parameter_snap: ParameterSnap,
  )
}

/// Return the default options for segment, subpath, and path intersection
/// detection.
///
/// The default tolerance is `0.000000001` path-coordinate units, the default
/// maximum subdivision depth is `48`, and parameter snapping is disabled.
pub fn default_options() -> IntersectionOptions {
  IntersectionOptions(
    tolerance: default_intersection_tolerance,
    max_depth: default_intersection_max_depth,
    parameter_snap: NoParameterSnap,
  )
}

/// Return the default options for intersection classification.
///
/// The direction-relative tolerance is `0.000000001`; the angular tolerance
/// is `0.0000001` degrees. Nontransverse contacts are sampled first at an arc
/// length of `0.000001`, doubling up to `0.25` path-coordinate units.
pub fn default_classification_options() -> ClassificationOptions {
  ClassificationOptions(
    direction_options: svg_path.default_direction_options(),
    angular_tolerance: default_classification_angular_tolerance,
    distance_tolerance: default_classification_distance_tolerance,
    length_options: svg_path.default_length_options(),
    initial_arc_length: default_classification_initial_arc_length,
    maximum_arc_length: default_classification_maximum_arc_length,
    max_sampling_steps: default_classification_max_sampling_steps,
  )
}

/// Classify one explicitly addressed intersection between two subpaths.
///
/// This operation does not search for or verify an intersection. The two
/// parameters are interpreted as addresses of the same already-known point.
/// Endpoint contacts are classified before local directions are evaluated.
/// Transverse intersections are classified from singularity-safe directions;
/// nontransverse branch order is determined from equal-arc-length samples.
pub fn classify_subpath_intersection(
  first: Subpath,
  second: Subpath,
  first_parameter first_parameter: SubpathParameter,
  second_parameter second_parameter: SubpathParameter,
) -> Result(IntersectionClassification, ClassificationError) {
  classify_subpath_intersection_with(
    first,
    second,
    first_parameter:,
    second_parameter:,
    options: default_classification_options(),
  )
}

/// Classify one explicitly addressed intersection using explicit options.
pub fn classify_subpath_intersection_with(
  first: Subpath,
  second: Subpath,
  first_parameter first_parameter: SubpathParameter,
  second_parameter second_parameter: SubpathParameter,
  options options: ClassificationOptions,
) -> Result(IntersectionClassification, ClassificationError) {
  use _ <- result.try(validate_classification_options(options))
  use first_endpoint <- result.try(
    map_path_error(subpath_endpoint(first, first_parameter)),
  )
  use second_endpoint <- result.try(
    map_path_error(subpath_endpoint(second, second_parameter)),
  )

  case first_endpoint, second_endpoint {
    Some(first), Some(second) ->
      Ok(EndpointContact(EndpointToEndpoint(first:, second:)))
    Some(first), None ->
      Ok(EndpointContact(FirstEndpointToSecondInterior(first:)))
    None, Some(second) ->
      Ok(EndpointContact(FirstInteriorToSecondEndpoint(second:)))
    None, None -> {
      use first_directions <- result.try(
        map_path_error(svg_path.subpath_directions_with(
          first,
          at: first_parameter,
          options: options.direction_options,
        )),
      )
      use second_directions <- result.try(
        map_path_error(svg_path.subpath_directions_with(
          second,
          at: second_parameter,
          options: options.direction_options,
        )),
      )
      map_path_error(classify_directions(
        first,
        second,
        first_parameter,
        second_parameter,
        first_directions,
        second_directions,
        options,
      ))
    }
  }
}

/// Classify every first/second parameter pair represented by one grouped
/// subpath intersection.
pub fn classify_grouped_subpath_intersection(
  first: Subpath,
  second: Subpath,
  intersection: SubpathIntersection,
) -> Result(List(ClassifiedSubpathIntersection), ClassificationError) {
  classify_grouped_subpath_intersection_with(
    first,
    second,
    intersection,
    options: default_classification_options(),
  )
}

/// Classify every parameter pair using explicit options.
pub fn classify_grouped_subpath_intersection_with(
  first: Subpath,
  second: Subpath,
  intersection: SubpathIntersection,
  options options: ClassificationOptions,
) -> Result(List(ClassifiedSubpathIntersection), ClassificationError) {
  let SubpathIntersection(left_parameters:, right_parameters:, ..) =
    intersection
  use classified <- result.try(
    left_parameters
    |> list.flat_map(fn(left_parameter) {
      right_parameters
      |> list.map(fn(right_parameter) {
        use classification <- result.try(classify_subpath_intersection_with(
          first,
          second,
          first_parameter: left_parameter,
          second_parameter: right_parameter,
          options:,
        ))
        Ok(ClassifiedSubpathIntersection(
          first_parameter: left_parameter,
          second_parameter: right_parameter,
          classification:,
        ))
      })
    })
    |> result.all,
  )
  Ok(classified)
}

/// Return the default options for subpath and path self-intersection detection.
pub fn default_self_intersection_options() -> SelfIntersectionOptions {
  svg_path.default_self_intersection_options()
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
  use _ <- result.try(validate_options(options))
  segment_intersections_checked_valid_options(left, right, options)
}

/// Return one closest-point pair between two segments.
///
/// This solves the same segment-pair distance problem used by point
/// intersection search, but it returns the best pair even when the segments do
/// not intersect. Overlapping segments return one coincident pair with distance
/// zero.
pub fn segment_segment_projection(
  left: Segment,
  right: Segment,
) -> Result(SegmentSegmentProjection, Error) {
  segment_segment_projection_with(left, right, options: default_options())
}

/// Return one closest-point pair between two segments using explicit options.
pub fn segment_segment_projection_with(
  left: Segment,
  right: Segment,
  options options: IntersectionOptions,
) -> Result(SegmentSegmentProjection, Error) {
  use _ <- result.try(validate_options(options))
  segment_segment_projection_valid_options(left, right, options)
}

/// Return one closest-point pair between a segment and a subpath.
pub fn segment_subpath_projection(
  left: Segment,
  right: Subpath,
) -> Result(SegmentSubpathProjection, Error) {
  segment_subpath_projection_with(left, right, options: default_options())
}

/// Return one closest-point pair between a segment and a subpath using
/// explicit options.
pub fn segment_subpath_projection_with(
  left: Segment,
  right: Subpath,
  options options: IntersectionOptions,
) -> Result(SegmentSubpathProjection, Error) {
  use _ <- result.try(validate_options(options))
  segment_subpath_projection_valid_options(left, right, options)
}

/// Return one closest-point pair between a segment and a path.
pub fn segment_path_projection(
  left: Segment,
  right: Path,
) -> Result(SegmentPathProjection, Error) {
  segment_path_projection_with(left, right, options: default_options())
}

/// Return one closest-point pair between a segment and a path using explicit
/// options.
pub fn segment_path_projection_with(
  left: Segment,
  right: Path,
  options options: IntersectionOptions,
) -> Result(SegmentPathProjection, Error) {
  use _ <- result.try(validate_options(options))
  segment_path_projection_valid_options(left, right, options)
}

/// Return one closest-point pair between two subpaths.
pub fn subpath_subpath_projection(
  left: Subpath,
  right: Subpath,
) -> Result(SubpathSubpathProjection, Error) {
  subpath_subpath_projection_with(left, right, options: default_options())
}

/// Return one closest-point pair between two subpaths using explicit options.
pub fn subpath_subpath_projection_with(
  left: Subpath,
  right: Subpath,
  options options: IntersectionOptions,
) -> Result(SubpathSubpathProjection, Error) {
  use _ <- result.try(validate_options(options))
  subpath_subpath_projection_valid_options(left, right, options)
}

/// Return one closest-point pair between a subpath and a path.
pub fn subpath_path_projection(
  left: Subpath,
  right: Path,
) -> Result(SubpathPathProjection, Error) {
  subpath_path_projection_with(left, right, options: default_options())
}

/// Return one closest-point pair between a subpath and a path using explicit
/// options.
pub fn subpath_path_projection_with(
  left: Subpath,
  right: Path,
  options options: IntersectionOptions,
) -> Result(SubpathPathProjection, Error) {
  use _ <- result.try(validate_options(options))
  subpath_path_projection_valid_options(left, right, options)
}

/// Return one closest-point pair between two paths.
pub fn path_path_projection(
  left: Path,
  right: Path,
) -> Result(PathPathProjection, Error) {
  path_path_projection_with(left, right, options: default_options())
}

/// Return one closest-point pair between two paths using explicit options.
pub fn path_path_projection_with(
  left: Path,
  right: Path,
  options options: IntersectionOptions,
) -> Result(PathPathProjection, Error) {
  use _ <- result.try(validate_options(options))
  path_path_projection_valid_options(left, right, options)
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
  use _ <- result.try(validate_options(options))
  use intersections <- result.try(segment_intersections_valid_options(
    left,
    right,
    options,
  ))
  certify_segment_intersections(left, right, intersections, options.tolerance)
}

fn polish_and_certify_segment_intersections(
  left: Segment,
  right: Segment,
  intersections: List(SegmentIntersection),
  options: IntersectionOptions,
) -> Result(List(SegmentIntersection), Error) {
  use intersections <- result.try(polish_segment_intersections(
    left,
    right,
    intersections,
    options.parameter_snap,
    options.tolerance,
  ))
  certify_segment_intersections(left, right, intersections, options.tolerance)
}

fn certify_segment_intersections(
  left: Segment,
  right: Segment,
  intersections: List(SegmentIntersection),
  tolerance: Float,
) -> Result(List(SegmentIntersection), Error) {
  use certified <- result.try(
    certify_segment_intersections_loop(
      left,
      right,
      intersections,
      tolerance,
      certified: [],
    ),
  )
  Ok(list.reverse(certified))
}

fn certify_segment_intersections_loop(
  left: Segment,
  right: Segment,
  intersections: List(SegmentIntersection),
  tolerance: Float,
  certified certified: List(SegmentIntersection),
) -> Result(List(SegmentIntersection), Error) {
  case intersections {
    [] -> Ok(certified)
    [intersection, ..rest] -> {
      let SegmentIntersection(left_t:, right_t:, point:) = intersection

      use left_point <- result.try(svg_path.segment_point(left, at: left_t))
      use right_point <- result.try(svg_path.segment_point(right, at: right_t))

      let left_distance = distance(left_point, point)
      let right_distance = distance(right_point, point)

      case left_distance <=. tolerance && right_distance <=. tolerance {
        True ->
          certify_segment_intersections_loop(
            left,
            right,
            rest,
            tolerance,
            certified: [intersection, ..certified],
          )
        False ->
          Error(InternalUncertifiedSegmentIntersection(
            left_distance:,
            right_distance:,
            tolerance:,
          ))
      }
    }
  }
}

fn polish_segment_intersections(
  left: Segment,
  right: Segment,
  intersections: List(SegmentIntersection),
  parameter_snap: ParameterSnap,
  tolerance: Float,
) -> Result(List(SegmentIntersection), Error) {
  case parameter_snap {
    NoParameterSnap -> Ok(sort_segment_intersections(intersections))
    DecimalParameterSnap(exponent:) -> {
      use polished <- result.try(
        polish_segment_intersections_loop(
          left,
          right,
          intersections,
          exponent,
          polished: [],
        ),
      )
      Ok(
        dedupe_segment_intersections(polished, tolerance)
        |> sort_segment_intersections,
      )
    }
  }
}

fn sort_segment_intersections(
  intersections: List(SegmentIntersection),
) -> List(SegmentIntersection) {
  intersections
  |> list.sort(by: fn(a, b) {
    case float.compare(a.left_t, b.left_t) {
      order.Eq -> float.compare(a.right_t, b.right_t)
      order -> order
    }
  })
}

fn polish_segment_intersections_loop(
  left: Segment,
  right: Segment,
  intersections: List(SegmentIntersection),
  exponent: Int,
  polished polished: List(SegmentIntersection),
) -> Result(List(SegmentIntersection), Error) {
  case intersections {
    [] -> Ok(list.reverse(polished))
    [intersection, ..rest] -> {
      use polished_intersection <- result.try(polish_segment_intersection(
        left,
        right,
        intersection,
        exponent,
      ))
      polish_segment_intersections_loop(left, right, rest, exponent, polished: [
        polished_intersection,
        ..polished
      ])
    }
  }
}

fn dedupe_segment_intersections(
  intersections: List(SegmentIntersection),
  tolerance: Float,
) -> List(SegmentIntersection) {
  list.fold(intersections, [], fn(deduped, intersection) {
    insert_intersection(
      deduped,
      intersection,
      point_tolerance: tolerance,
      parameter_tolerance: intersection_parameter_dedupe_tolerance,
    )
  })
  |> list.reverse
}

fn polish_segment_intersection(
  left: Segment,
  right: Segment,
  intersection: SegmentIntersection,
  exponent: Int,
) -> Result(SegmentIntersection, Error) {
  let scale = parameter_snap_scale(exponent)
  let SegmentIntersection(left_t:, right_t:, ..) = intersection
  let left_candidates = parameter_snap_candidates(left_t, scale)
  let right_candidates = parameter_snap_candidates(right_t, scale)
  use original <- result.try(snapped_intersection_candidate(
    left,
    right,
    left_t,
    right_t,
    rank: 100,
  ))
  use best <- result.try(best_snapped_intersection_candidate(
    left,
    right,
    left_candidates,
    right_candidates,
    best: original,
  ))
  Ok(best.intersection)
}

fn best_snapped_intersection_candidate(
  left: Segment,
  right: Segment,
  left_candidates: List(ParameterSnapCandidate),
  right_candidates: List(ParameterSnapCandidate),
  best best: SnappedIntersectionCandidate,
) -> Result(SnappedIntersectionCandidate, Error) {
  case left_candidates {
    [] -> Ok(best)
    [left_candidate, ..rest] -> {
      use best <- result.try(best_snapped_intersection_for_left_candidate(
        left,
        right,
        left_candidate,
        right_candidates,
        best:,
      ))
      best_snapped_intersection_candidate(
        left,
        right,
        rest,
        right_candidates,
        best:,
      )
    }
  }
}

fn best_snapped_intersection_for_left_candidate(
  left: Segment,
  right: Segment,
  left_candidate: ParameterSnapCandidate,
  right_candidates: List(ParameterSnapCandidate),
  best best: SnappedIntersectionCandidate,
) -> Result(SnappedIntersectionCandidate, Error) {
  case right_candidates {
    [] -> Ok(best)
    [right_candidate, ..rest] -> {
      use candidate <- result.try(snapped_intersection_candidate(
        left,
        right,
        left_candidate.t,
        right_candidate.t,
        rank: left_candidate.rank + right_candidate.rank,
      ))
      let best = better_snapped_intersection(best, candidate)
      best_snapped_intersection_for_left_candidate(
        left,
        right,
        left_candidate,
        rest,
        best:,
      )
    }
  }
}

fn snapped_intersection_candidate(
  left: Segment,
  right: Segment,
  left_t: Float,
  right_t: Float,
  rank rank: Int,
) -> Result(SnappedIntersectionCandidate, Error) {
  use left_point <- result.try(svg_path.segment_point(left, at: left_t))
  use right_point <- result.try(svg_path.segment_point(right, at: right_t))
  let distance_squared = distance_squared(left_point, right_point)
  Ok(SnappedIntersectionCandidate(
    intersection: SegmentIntersection(
      left_t:,
      right_t:,
      point: midpoint(left_point, right_point),
    ),
    distance_squared:,
    rank:,
  ))
}

fn better_snapped_intersection(
  best: SnappedIntersectionCandidate,
  candidate: SnappedIntersectionCandidate,
) -> SnappedIntersectionCandidate {
  let candidate_ties_best =
    candidate.distance_squared
    <=. distance_squared_with_linear_slack(
      best.distance_squared,
      parameter_snap_distance_tie_slack,
    )
  let best_ties_candidate =
    best.distance_squared
    <=. distance_squared_with_linear_slack(
      candidate.distance_squared,
      parameter_snap_distance_tie_slack,
    )

  case candidate.distance_squared <. best.distance_squared {
    True -> {
      case best_ties_candidate && candidate.rank >= best.rank {
        True -> best
        False -> candidate
      }
    }
    False -> {
      case candidate_ties_best && candidate.rank < best.rank {
        True -> candidate
        False -> best
      }
    }
  }
}

fn distance_squared_with_linear_slack(
  distance_squared: Float,
  distance_slack: Float,
) -> Float {
  let assert Ok(distance) = float.square_root(distance_squared)
  distance_squared
  +. 2.0
  *. distance_slack
  *. distance
  +. distance_slack
  *. distance_slack
}

fn parameter_snap_candidates(
  t: Float,
  scale: Float,
) -> List(ParameterSnapCandidate) {
  let base = float.floor(t /. scale)
  let raw = [
    parameter_snap_candidate(0.0, rank: 0),
    parameter_snap_candidate({ base +. 0.0 } *. scale, rank: 0),
    parameter_snap_candidate({ base +. 1.0 } *. scale, rank: 0),
    parameter_snap_candidate({ base +. 1.0 /. 3.0 } *. scale, rank: 1),
    parameter_snap_candidate({ base +. 2.0 /. 3.0 } *. scale, rank: 1),
    parameter_snap_candidate(1.0, rank: 0),
  ]
  keep_parameter_snap_candidates(raw, t, scale, candidates: [])
}

fn parameter_snap_candidate(
  t: Float,
  rank rank: Int,
) -> ParameterSnapCandidate {
  let rank = case t == 0.0 || t == 1.0 {
    True -> -1
    False -> rank
  }
  ParameterSnapCandidate(t:, rank:)
}

fn keep_parameter_snap_candidates(
  raw: List(ParameterSnapCandidate),
  original_t: Float,
  scale: Float,
  candidates candidates: List(ParameterSnapCandidate),
) -> List(ParameterSnapCandidate) {
  case raw {
    [] -> list.reverse(candidates)
    [candidate, ..rest] -> {
      case
        candidate.t >=. 0.0
        && candidate.t <=. 1.0
        && float.absolute_value(candidate.t -. original_t) <=. scale
      {
        True ->
          keep_parameter_snap_candidates(rest, original_t, scale, candidates: [
            candidate,
            ..candidates
          ])
        False ->
          keep_parameter_snap_candidates(rest, original_t, scale, candidates:)
      }
    }
  }
}

fn parameter_snap_scale(exponent: Int) -> Float {
  nonnegative_integer_power(0.1, exponent, 1.0)
}

fn nonnegative_integer_power(
  base: Float,
  exponent: Int,
  result: Float,
) -> Float {
  case exponent {
    0 -> result
    _ if exponent % 2 == 0 ->
      nonnegative_integer_power(base *. base, exponent / 2, result)
    _ -> nonnegative_integer_power(base, exponent - 1, result *. base)
  }
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
        Error(error) -> Error(error)
        Ok(intersections) ->
          polish_and_certify_segment_intersections(
            left,
            right,
            intersections,
            options,
          )
      }
  }
}

fn segment_segment_projection_valid_options(
  left: Segment,
  right: Segment,
  options: IntersectionOptions,
) -> Result(SegmentSegmentProjection, Error) {
  use overlaps <- result.try(overlap_detection.detect(
    left,
    right,
    tolerance: options.tolerance,
  ))
  case overlaps {
    [overlap, ..] ->
      segment_segment_projection_from_overlap(left, right, overlap)
    [] -> {
      case left, right {
        Line(..), Line(..) -> line_line_segment_projection(left, right, options)
        _, _ -> {
          use minima <- result.try(segment_pair_projection_minima(
            left,
            right,
            options,
          ))
          let assert Ok(best) = best_distance_minimum(minima)
          segment_segment_projection_from_minimum(left, right, best)
        }
      }
    }
  }
}

fn segment_subpath_projection_valid_options(
  left: Segment,
  right: Subpath,
  options: IntersectionOptions,
) -> Result(SegmentSubpathProjection, Error) {
  let right_segments = svg_path.subpath_segments(right)
  case right_segments {
    [] -> Error(EmptySubpath)
    _ -> {
      use projection <- result.try(segment_list_projection(
        [left],
        right_segments,
        options,
      ))
      let SegmentListProjection(projection:, right_index:, ..) = projection
      Ok(segment_subpath_projection_from_segment_projection(
        projection,
        right_index:,
      ))
    }
  }
}

fn segment_subpath_projection_from_segment_projection(
  projection: SegmentSegmentProjection,
  right_index right_index: Int,
) -> SegmentSubpathProjection {
  let SegmentSegmentProjection(
    left_t:,
    right_t:,
    left_point:,
    right_point:,
    distance:,
  ) = projection
  let candidate =
    SegmentSubpathProjection(
      left_t:,
      right_at: SubpathParameter(segment_index: right_index, t: right_t),
      left_point:,
      right_point:,
      distance:,
    )
  candidate
}

fn segment_path_projection_valid_options(
  left: Segment,
  right: Path,
  options: IntersectionOptions,
) -> Result(SegmentPathProjection, Error) {
  use right <- result.try(path_projection_segments(right))
  let #(right_segments, right_addresses) = right
  use projection <- result.try(segment_list_projection(
    [left],
    right_segments,
    options,
  ))
  let SegmentListProjection(projection:, right_index:, ..) = projection
  use right_at <- result.try(nth_path_projection_address(
    right_addresses,
    right_index,
  ))
  Ok(segment_path_projection_from_segment_projection(projection, right_at:))
}

fn segment_path_projection_from_segment_projection(
  projection: SegmentSegmentProjection,
  right_at right_at: PathParameter,
) -> SegmentPathProjection {
  let SegmentSegmentProjection(
    left_t:,
    right_t:,
    left_point:,
    right_point:,
    distance:,
  ) = projection
  let candidate =
    SegmentPathProjection(
      left_t:,
      right_at: path_projection_address_with_t(right_at, right_t),
      left_point:,
      right_point:,
      distance:,
    )
  candidate
}

fn subpath_subpath_projection_valid_options(
  left: Subpath,
  right: Subpath,
  options: IntersectionOptions,
) -> Result(SubpathSubpathProjection, Error) {
  let left_segments = svg_path.subpath_segments(left)
  let right_segments = svg_path.subpath_segments(right)
  case left_segments, right_segments {
    [], _ | _, [] -> Error(EmptySubpath)
    _, _ -> {
      use projection <- result.try(segment_list_projection(
        left_segments,
        right_segments,
        options,
      ))
      let SegmentListProjection(left_index:, right_index:, projection:) =
        projection
      Ok(subpath_subpath_projection_from_segment_projection(
        projection,
        left_index:,
        right_index:,
      ))
    }
  }
}

fn subpath_subpath_projection_from_segment_projection(
  projection: SegmentSegmentProjection,
  left_index left_index: Int,
  right_index right_index: Int,
) -> SubpathSubpathProjection {
  let SegmentSegmentProjection(
    left_t:,
    right_t:,
    left_point:,
    right_point:,
    distance:,
  ) = projection
  let candidate =
    SubpathSubpathProjection(
      left_at: SubpathParameter(segment_index: left_index, t: left_t),
      right_at: SubpathParameter(segment_index: right_index, t: right_t),
      left_point:,
      right_point:,
      distance:,
    )
  candidate
}

fn subpath_path_projection_valid_options(
  left: Subpath,
  right: Path,
  options: IntersectionOptions,
) -> Result(SubpathPathProjection, Error) {
  let left_segments = svg_path.subpath_segments(left)
  case left_segments {
    [] -> Error(EmptySubpath)
    _ -> {
      use right <- result.try(path_projection_segments(right))
      let #(right_segments, right_addresses) = right
      use projection <- result.try(segment_list_projection(
        left_segments,
        right_segments,
        options,
      ))
      let SegmentListProjection(left_index:, right_index:, projection:) =
        projection
      use right_at <- result.try(nth_path_projection_address(
        right_addresses,
        right_index,
      ))
      Ok(subpath_path_projection_from_segment_projection(
        projection,
        left_index:,
        right_at:,
      ))
    }
  }
}

fn subpath_path_projection_from_segment_projection(
  projection: SegmentSegmentProjection,
  left_index left_index: Int,
  right_at right_at: PathParameter,
) -> SubpathPathProjection {
  let SegmentSegmentProjection(
    left_t:,
    right_t:,
    left_point:,
    right_point:,
    distance:,
  ) = projection
  let candidate =
    SubpathPathProjection(
      left_at: SubpathParameter(segment_index: left_index, t: left_t),
      right_at: path_projection_address_with_t(right_at, right_t),
      left_point:,
      right_point:,
      distance:,
    )
  candidate
}

fn path_path_projection_valid_options(
  left: Path,
  right: Path,
  options: IntersectionOptions,
) -> Result(PathPathProjection, Error) {
  use left <- result.try(path_projection_segments(left))
  use right <- result.try(path_projection_segments(right))
  let #(left_segments, left_addresses) = left
  let #(right_segments, right_addresses) = right
  use projection <- result.try(segment_list_projection(
    left_segments,
    right_segments,
    options,
  ))
  let SegmentListProjection(left_index:, right_index:, projection:) = projection
  use left_at <- result.try(nth_path_projection_address(
    left_addresses,
    left_index,
  ))
  use right_at <- result.try(nth_path_projection_address(
    right_addresses,
    right_index,
  ))
  Ok(path_path_projection_from_segment_projection(
    projection,
    left_at:,
    right_at:,
  ))
}

fn path_path_projection_from_segment_projection(
  projection: SegmentSegmentProjection,
  left_at left_at: PathParameter,
  right_at right_at: PathParameter,
) -> PathPathProjection {
  let SegmentSegmentProjection(
    left_t:,
    right_t:,
    left_point:,
    right_point:,
    distance:,
  ) = projection
  let candidate =
    PathPathProjection(
      left_at: path_projection_address_with_t(left_at, left_t),
      right_at: path_projection_address_with_t(right_at, right_t),
      left_point:,
      right_point:,
      distance:,
    )
  candidate
}

fn path_projection_address_with_t(
  parameter: PathParameter,
  t: Float,
) -> PathParameter {
  let PathParameter(subpath_index:, at:) = parameter
  let SubpathParameter(segment_index:, ..) = at
  PathParameter(subpath_index:, at: SubpathParameter(segment_index:, t:))
}

fn segment_list_projection(
  left: List(Segment),
  right: List(Segment),
  options: IntersectionOptions,
) -> Result(SegmentListProjection, Error) {
  use left <- result.try(index_projection_segments(left, index: 0, indexed: []))
  use right <- result.try(
    index_projection_segments(right, index: 0, indexed: []),
  )
  segment_list_projection_loop(left, right, right, options, best: None)
}

fn index_projection_segments(
  segments: List(Segment),
  index index: Int,
  indexed indexed: List(IndexedProjectionSegment),
) -> Result(List(IndexedProjectionSegment), Error) {
  case segments {
    [] -> Ok(list.reverse(indexed))
    [segment, ..rest] -> {
      use bounds <- result.try(coarse_segment_bounding_box(segment))
      index_projection_segments(rest, index: index + 1, indexed: [
        IndexedProjectionSegment(index:, segment:, bounds:),
        ..indexed
      ])
    }
  }
}

fn segment_list_projection_loop(
  left: List(IndexedProjectionSegment),
  all_right: List(IndexedProjectionSegment),
  remaining_right: List(IndexedProjectionSegment),
  options: IntersectionOptions,
  best best: Option(SegmentListProjection),
) -> Result(SegmentListProjection, Error) {
  case left, remaining_right {
    [], _ ->
      case best {
        Some(best) -> Ok(best)
        None ->
          Error(InternalUncertifiedSegmentIntersection(
            left_distance: 1.0e100,
            right_distance: 1.0e100,
            tolerance: options.tolerance,
          ))
      }
    [_, ..left_rest], [] ->
      segment_list_projection_loop(
        left_rest,
        all_right,
        all_right,
        options,
        best:,
      )
    [left_segment, ..], [right_segment, ..right_rest] -> {
      use best <- result.try(project_indexed_segment_pair(
        left_segment,
        right_segment,
        options,
        best:,
      ))
      segment_list_projection_loop(left, all_right, right_rest, options, best:)
    }
  }
}

fn project_indexed_segment_pair(
  left: IndexedProjectionSegment,
  right: IndexedProjectionSegment,
  options: IntersectionOptions,
  best best: Option(SegmentListProjection),
) -> Result(Option(SegmentListProjection), Error) {
  let skip = case best {
    None -> False
    Some(best) -> {
      let SegmentListProjection(projection:, ..) = best
      bounding_box_distance_squared(left.bounds, right.bounds)
      >=. projection.distance *. projection.distance
    }
  }

  case skip {
    True -> Ok(best)
    False -> {
      use projection <- result.try(segment_segment_projection_valid_options(
        left.segment,
        right.segment,
        options,
      ))
      let candidate =
        SegmentListProjection(
          left_index: left.index,
          right_index: right.index,
          projection:,
        )
      Ok(closer_segment_list_projection(best, candidate))
    }
  }
}

fn closer_segment_list_projection(
  best: Option(SegmentListProjection),
  candidate: SegmentListProjection,
) -> Option(SegmentListProjection) {
  case best {
    None -> Some(candidate)
    Some(best) -> {
      let SegmentListProjection(projection: best_projection, ..) = best
      let SegmentListProjection(projection: candidate_projection, ..) =
        candidate
      case candidate_projection.distance <. best_projection.distance {
        True -> Some(candidate)
        False -> Some(best)
      }
    }
  }
}

fn path_projection_segments(
  path: Path,
) -> Result(#(List(Segment), List(PathParameter)), Error) {
  case path.subpaths {
    [] -> Error(EmptyPath)
    subpaths ->
      path_projection_segments_loop(
        subpaths,
        subpath_index: 0,
        segments: [],
        addresses: [],
      )
  }
}

fn path_projection_segments_loop(
  subpaths: List(Subpath),
  subpath_index subpath_index: Int,
  segments segments: List(Segment),
  addresses addresses: List(PathParameter),
) -> Result(#(List(Segment), List(PathParameter)), Error) {
  case subpaths {
    [] -> {
      case segments {
        [] -> Error(EmptySubpaths)
        _ -> Ok(#(list.reverse(segments), list.reverse(addresses)))
      }
    }
    [subpath, ..rest] -> {
      let subpath_segments = svg_path.subpath_segments(subpath)
      let #(segments, addresses) =
        prepend_path_projection_segments(
          subpath_segments,
          subpath_index:,
          segment_index: 0,
          segments:,
          addresses:,
        )
      path_projection_segments_loop(
        rest,
        subpath_index: subpath_index + 1,
        segments:,
        addresses:,
      )
    }
  }
}

fn prepend_path_projection_segments(
  subpath_segments: List(Segment),
  subpath_index subpath_index: Int,
  segment_index segment_index: Int,
  segments segments: List(Segment),
  addresses addresses: List(PathParameter),
) -> #(List(Segment), List(PathParameter)) {
  case subpath_segments {
    [] -> #(segments, addresses)
    [segment, ..rest] ->
      prepend_path_projection_segments(
        rest,
        subpath_index:,
        segment_index: segment_index + 1,
        segments: [segment, ..segments],
        addresses: [
          PathParameter(
            subpath_index:,
            at: SubpathParameter(segment_index:, t: 0.0),
          ),
          ..addresses
        ],
      )
  }
}

fn nth_path_projection_address(
  addresses: List(PathParameter),
  index: Int,
) -> Result(PathParameter, Error) {
  case addresses, index {
    [], _ ->
      Error(InternalUncertifiedSegmentIntersection(
        left_distance: 1.0e100,
        right_distance: 1.0e100,
        tolerance: 0.0,
      ))
    [first, ..], 0 -> Ok(first)
    [_, ..rest], _ -> nth_path_projection_address(rest, index - 1)
  }
}

fn line_line_segment_projection(
  left: Segment,
  right: Segment,
  options: IntersectionOptions,
) -> Result(SegmentSegmentProjection, Error) {
  let assert Line(start: left_start, end: left_end) = left
  let assert Line(start: right_start, end: right_end) = right
  let left_direction = point_difference(left_end, left_start)
  let right_direction = point_difference(right_end, right_start)
  let denominator = cross(left_direction, right_direction)

  case float.absolute_value(denominator) >. options.tolerance {
    True -> {
      let between_starts = point_difference(right_start, left_start)
      let left_t = cross(between_starts, right_direction) /. denominator
      let right_t = cross(between_starts, left_direction) /. denominator
      case in_unit_range(left_t, 0.0) && in_unit_range(right_t, 0.0) {
        True -> {
          use left_point <- result.try(svg_path.segment_point(left, at: left_t))
          use right_point <- result.try(svg_path.segment_point(
            right,
            at: right_t,
          ))
          Ok(SegmentSegmentProjection(
            left_t:,
            right_t:,
            left_point:,
            right_point:,
            distance: 0.0,
          ))
        }
        False -> line_line_endpoint_projection(left, right, options)
      }
    }
    False -> line_line_endpoint_projection(left, right, options)
  }
}

fn line_line_endpoint_projection(
  left: Segment,
  right: Segment,
  options: IntersectionOptions,
) -> Result(SegmentSegmentProjection, Error) {
  use minima <- result.try(boundary_edge_minima(left, right, options))
  let assert Ok(best) = best_distance_minimum(minima)
  segment_segment_projection_from_minimum(left, right, best)
}

fn segment_segment_projection_from_overlap(
  left: Segment,
  right: Segment,
  overlap: overlap_detection.RawOverlap,
) -> Result(SegmentSegmentProjection, Error) {
  let #(left_from, _, right_from, _, _, _) = overlap
  use left_point <- result.try(svg_path.segment_point(left, at: left_from))
  use right_point <- result.try(svg_path.segment_point(right, at: right_from))
  Ok(SegmentSegmentProjection(
    left_t: left_from,
    right_t: right_from,
    left_point:,
    right_point:,
    distance: 0.0,
  ))
}

fn segment_segment_projection_from_minimum(
  left: Segment,
  right: Segment,
  minimum: DistanceMinimum,
) -> Result(SegmentSegmentProjection, Error) {
  let DistanceMinimum(left_t:, right_t:, distance_squared:) = minimum
  use left_point <- result.try(svg_path.segment_point(left, at: left_t))
  use right_point <- result.try(svg_path.segment_point(right, at: right_t))
  let assert Ok(distance) = float.square_root(distance_squared)
  Ok(SegmentSegmentProjection(
    left_t:,
    right_t:,
    left_point:,
    right_point:,
    distance:,
  ))
}

fn best_distance_minimum(
  minima: List(DistanceMinimum),
) -> Result(DistanceMinimum, Error) {
  case minima {
    [] ->
      Error(InternalUncertifiedSegmentIntersection(
        left_distance: 1.0e100,
        right_distance: 1.0e100,
        tolerance: 0.0,
      ))
    [first, ..rest] ->
      Ok(
        list.fold(rest, first, fn(best, candidate) {
          case candidate.distance_squared <. best.distance_squared {
            True -> candidate
            False -> best
          }
        }),
      )
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
  segment_self_with(segment, options: default_self_intersection_options())
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
  use _ <- result.try(validate_options(options))
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
  use _ <- result.try(validate_options(options))
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
  subpath_self_with(subpath, options: default_self_intersection_options())
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
  use _ <- result.try(validate_options(options))
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
  use _ <- result.try(validate_options(options))
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
  use _ <- result.try(validate_options(options))
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
  use _ <- result.try(validate_options(options))
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
  path_self_with(path, options: default_self_intersection_options())
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

fn validate_classification_options(
  options: ClassificationOptions,
) -> Result(Nil, ClassificationError) {
  let svg_path.LengthOptions(tolerance: length_tolerance, max_depth:) =
    options.length_options

  case
    options.angular_tolerance >=. 0.0
    && options.angular_tolerance <. 180.0
    && number.is_finite(options.angular_tolerance)
  {
    True ->
      case
        options.distance_tolerance >=. 0.0
        && number.is_finite(options.distance_tolerance)
      {
        False ->
          Error(InvalidClassificationDistanceTolerance(
            options.distance_tolerance,
          ))
        True ->
          case length_tolerance >. 0.0 && number.is_finite(length_tolerance) {
            False ->
              Error(
                PathError(svg_path.InvalidLengthTolerance(length_tolerance)),
              )
            True ->
              case max_depth >= 0 {
                False ->
                  Error(PathError(svg_path.InvalidLengthMaxDepth(max_depth)))
                True ->
                  case
                    options.initial_arc_length >. 0.0
                    && number.is_finite(options.initial_arc_length)
                  {
                    False ->
                      Error(InvalidClassificationInitialArcLength(
                        options.initial_arc_length,
                      ))
                    True ->
                      case
                        options.maximum_arc_length
                        >=. options.initial_arc_length
                        && number.is_finite(options.maximum_arc_length)
                      {
                        False ->
                          Error(InvalidClassificationMaximumArcLength(
                            options.maximum_arc_length,
                          ))
                        True ->
                          case options.max_sampling_steps > 0 {
                            True -> Ok(Nil)
                            False ->
                              Error(InvalidClassificationMaxSamplingSteps(
                                options.max_sampling_steps,
                              ))
                          }
                      }
                  }
              }
          }
      }
    False -> Error(InvalidAngularTolerance(options.angular_tolerance))
  }
}

fn map_path_error(
  result: Result(value, svg_path.Error),
) -> Result(value, ClassificationError) {
  result.map_error(result, PathError)
}

fn subpath_endpoint(
  subpath: Subpath,
  parameter: SubpathParameter,
) -> Result(Option(SubpathEndpoint), svg_path.Error) {
  use parameter <- result.try(svg_path.subpath_parameter_canonicalize(
    subpath,
    parameter:,
  ))
  let SubpathParameter(segment_index:, t:) = parameter
  let segment_count = list.length(svg_path.subpath_segments(subpath))

  case svg_path.subpath_is_closed(subpath) {
    True -> Ok(None)
    False ->
      case segment_index, t {
        0, 0.0 -> Ok(Some(StartEndpoint))
        index, 1.0 if index == segment_count - 1 -> Ok(Some(EndEndpoint))
        _, _ -> Ok(None)
      }
  }
}

fn classify_directions(
  first: Subpath,
  second: Subpath,
  first_parameter: SubpathParameter,
  second_parameter: SubpathParameter,
  left: svg_path.Directions,
  right: svg_path.Directions,
  options: ClassificationOptions,
) -> Result(IntersectionClassification, svg_path.Error) {
  let svg_path.Directions(incoming: left_incoming, outgoing: left_outgoing) =
    left
  let svg_path.Directions(incoming: right_incoming, outgoing: right_outgoing) =
    right

  case left_incoming, left_outgoing, right_incoming, right_outgoing {
    Some(left_incoming),
      Some(left_outgoing),
      Some(right_incoming),
      Some(right_outgoing)
    -> {
      let apertures =
        intersection_apertures(
          left_incoming,
          left_outgoing,
          right_incoming,
          right_outgoing,
        )
      let left_before = point.negate(left_incoming)
      let right_before = point.negate(right_incoming)
      let alternating =
        separated_by_rays(
          left_before,
          left_outgoing,
          right_before,
          right_outgoing,
          options.angular_tolerance,
        )
        && separated_by_rays(
          right_before,
          right_outgoing,
          left_before,
          left_outgoing,
          options.angular_tolerance,
        )

      case alternating {
        True ->
          Ok(Crossing(
            crossing_direction(left_outgoing, right_outgoing),
            apertures:,
          ))
        False -> {
          let direction = touching_direction(left_outgoing, right_outgoing)
          use intersection_point <- result.try(intersection_reference_point(
            first,
            second,
            first_parameter,
            second_parameter,
          ))
          use first_location <- result.try(subpath_arc_length_location(
            first,
            first_parameter,
            options.length_options,
          ))
          use second_location <- result.try(subpath_arc_length_location(
            second,
            second_parameter,
            options.length_options,
          ))
          let #(
            first_incoming,
            second_incoming,
            first_outgoing,
            second_outgoing,
          ) = touching_branch_pairing(direction)
          use incoming_order <- result.try(sample_touching_order(
            first_location,
            second_location,
            intersection_point,
            first_branch: first_incoming,
            second_branch: second_incoming,
            options:,
          ))
          use outgoing_order <- result.try(sample_touching_order(
            first_location,
            second_location,
            intersection_point,
            first_branch: first_outgoing,
            second_branch: second_outgoing,
            options:,
          ))
          Ok(Touching(direction:, incoming_order:, outgoing_order:, apertures:))
        }
      }
    }
    _, _, _, _ -> Ok(Indeterminate)
  }
}

type TraversalBranch {
  IncomingBranch
  OutgoingBranch
}

fn touching_branch_pairing(
  direction: TouchingDirection,
) -> #(TraversalBranch, TraversalBranch, TraversalBranch, TraversalBranch) {
  case direction {
    SimilarlyDirected -> #(
      IncomingBranch,
      IncomingBranch,
      OutgoingBranch,
      OutgoingBranch,
    )
    OppositelyDirected -> #(
      IncomingBranch,
      OutgoingBranch,
      OutgoingBranch,
      IncomingBranch,
    )
  }
}

fn intersection_reference_point(
  first: Subpath,
  second: Subpath,
  first_parameter: SubpathParameter,
  second_parameter: SubpathParameter,
) -> Result(Point, svg_path.Error) {
  use first_point <- result.try(svg_path.subpath_point(
    first,
    at: first_parameter,
  ))
  use second_point <- result.try(svg_path.subpath_point(
    second,
    at: second_parameter,
  ))
  Ok(point.scale(point.add(first_point, second_point), by: 0.5))
}

type ArcLengthLocation {
  ArcLengthLocation(subpath: Subpath, at: Float, total: Float, closed: Bool)
}

fn subpath_arc_length_location(
  subpath: Subpath,
  parameter: SubpathParameter,
  length_options: svg_path.LengthOptions,
) -> Result(ArcLengthLocation, svg_path.Error) {
  use parameter <- result.try(svg_path.subpath_parameter_canonicalize(
    subpath,
    parameter:,
  ))
  use total <- result.try(svg_path.subpath_length_with(
    subpath,
    options: length_options,
  ))
  let start = SubpathParameter(segment_index: 0, t: 0.0)
  use at <- result.try(case parameter == start {
    True -> Ok(0.0)
    False -> {
      use portion <- result.try(svg_path.subpath_between(
        subpath,
        from: start,
        to: parameter,
      ))
      svg_path.subpath_length_with(portion, options: length_options)
    }
  })
  Ok(ArcLengthLocation(
    subpath:,
    at:,
    total:,
    closed: svg_path.subpath_is_closed(subpath),
  ))
}

fn sample_touching_order(
  first: ArcLengthLocation,
  second: ArcLengthLocation,
  intersection_point: Point,
  first_branch first_branch: TraversalBranch,
  second_branch second_branch: TraversalBranch,
  options options: ClassificationOptions,
) -> Result(TouchingOrder, svg_path.Error) {
  sample_touching_order_loop(
    first,
    second,
    intersection_point,
    first_branch,
    second_branch,
    options,
    arc_length: options.initial_arc_length,
    remaining: options.max_sampling_steps,
  )
}

fn sample_touching_order_loop(
  first: ArcLengthLocation,
  second: ArcLengthLocation,
  intersection_point: Point,
  first_branch: TraversalBranch,
  second_branch: TraversalBranch,
  options: ClassificationOptions,
  arc_length arc_length: Float,
  remaining remaining: Int,
) -> Result(TouchingOrder, svg_path.Error) {
  case remaining <= 0 {
    True -> Ok(IndeterminateTouchingOrder)
    False -> {
      use first_point <- result.try(sample_subpath_branch_at_arc_length(
        first,
        first_branch,
        arc_length,
        options.length_options,
      ))
      use second_point <- result.try(sample_subpath_branch_at_arc_length(
        second,
        second_branch,
        arc_length,
        options.length_options,
      ))
      let first_ray = point.subtract(first_point, intersection_point)
      let second_ray = point.subtract(second_point, intersection_point)
      let order = touching_order_from_rays(first_ray, second_ray, options)

      case order {
        IndeterminateTouchingOrder
          if arc_length <. options.maximum_arc_length
        ->
          sample_touching_order_loop(
            first,
            second,
            intersection_point,
            first_branch,
            second_branch,
            options,
            arc_length: float.min(options.maximum_arc_length, arc_length *. 2.0),
            remaining: remaining - 1,
          )
        IndeterminateTouchingOrder -> Ok(IndeterminateTouchingOrder)
        order -> Ok(order)
      }
    }
  }
}

fn sample_subpath_branch_at_arc_length(
  location: ArcLengthLocation,
  branch: TraversalBranch,
  arc_length: Float,
  length_options: svg_path.LengthOptions,
) -> Result(Point, svg_path.Error) {
  let ArcLengthLocation(subpath:, at:, total:, closed:) = location
  let distance = case branch {
    IncomingBranch -> at -. arc_length
    OutgoingBranch -> at +. arc_length
  }
  let distance = case closed, total >. 0.0 {
    True, True -> positive_remainder(distance, total)
    _, _ -> distance |> float.max(0.0) |> float.min(total)
  }
  svg_path.subpath_point_at_length_with(
    subpath,
    distance:,
    options: length_options,
  )
}

fn touching_order_from_rays(
  first_ray: Point,
  second_ray: Point,
  options: ClassificationOptions,
) -> TouchingOrder {
  let minimum_length_squared =
    options.distance_tolerance *. options.distance_tolerance
  case
    point.norm_squared(first_ray) <=. minimum_length_squared
    || point.norm_squared(second_ray) <=. minimum_length_squared
  {
    True -> IndeterminateTouchingOrder
    False -> {
      let signed_order =
        point.clockwise_aperture(from: first_ray, to: second_ray) -. 180.0
      let distance_from_coincidence =
        180.0 -. float.absolute_value(signed_order)

      case
        float.absolute_value(signed_order) <=. options.angular_tolerance
        || distance_from_coincidence <=. options.angular_tolerance
      {
        True -> IndeterminateTouchingOrder
        False ->
          case signed_order <. 0.0 {
            True -> ClockwiseFromFirstToSecond
            False -> ClockwiseFromSecondToFirst
          }
      }
    }
  }
}

fn positive_remainder(value: Float, modulus: Float) -> Float {
  value -. float.floor(value /. modulus) *. modulus
}

fn intersection_apertures(
  left_incoming: Point,
  left_outgoing: Point,
  right_incoming: Point,
  right_outgoing: Point,
) -> IntersectionApertures {
  IntersectionApertures(
    first_incoming_to_second_incoming: point.clockwise_aperture(
      from: left_incoming,
      to: right_incoming,
    ),
    first_incoming_to_second_outgoing: point.clockwise_aperture(
      from: left_incoming,
      to: right_outgoing,
    ),
    first_outgoing_to_second_incoming: point.clockwise_aperture(
      from: left_outgoing,
      to: right_incoming,
    ),
    first_outgoing_to_second_outgoing: point.clockwise_aperture(
      from: left_outgoing,
      to: right_outgoing,
    ),
  )
}

fn separated_by_rays(
  boundary_from: Point,
  boundary_to: Point,
  first: Point,
  second: Point,
  tolerance: Float,
) -> Bool {
  let aperture = point.clockwise_aperture(from: boundary_from, to: boundary_to)
  case aperture <=. tolerance || 360.0 -. aperture <=. tolerance {
    True -> False
    False -> {
      let first_aperture =
        point.clockwise_aperture(from: boundary_from, to: first)
      let second_aperture =
        point.clockwise_aperture(from: boundary_from, to: second)
      let first_inside =
        first_aperture >. tolerance && first_aperture <. aperture -. tolerance
      let second_inside =
        second_aperture >. tolerance && second_aperture <. aperture -. tolerance
      first_inside != second_inside
    }
  }
}

fn crossing_direction(
  left_outgoing: Point,
  right_outgoing: Point,
) -> CrossingDirection {
  case
    point.clockwise_aperture(from: left_outgoing, to: right_outgoing) <. 180.0
  {
    True -> Clockwise
    False -> Counterclockwise
  }
}

fn touching_direction(
  left_outgoing: Point,
  right_outgoing: Point,
) -> TouchingDirection {
  let aperture =
    point.clockwise_aperture(from: left_outgoing, to: right_outgoing)
  case aperture <=. 90.0 || aperture >=. 270.0 {
    True -> SimilarlyDirected
    False -> OppositelyDirected
  }
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

@internal
pub fn validate_options(options: IntersectionOptions) -> Result(Nil, Error) {
  case options.tolerance <=. 0.0 || !number.is_finite(options.tolerance) {
    True -> Error(InvalidIntersectionTolerance(options.tolerance))
    False -> {
      case options.max_depth <= 0 {
        True -> Error(InvalidIntersectionMaxDepth(options.max_depth))
        False -> validate_parameter_snap(options.parameter_snap)
      }
    }
  }
}

fn validate_parameter_snap(
  parameter_snap: ParameterSnap,
) -> Result(Nil, Error) {
  case parameter_snap {
    NoParameterSnap -> Ok(Nil)
    DecimalParameterSnap(exponent:) -> {
      case exponent < 1 || exponent > 15 {
        True -> Error(InvalidIntersectionParameterSnapExponent(exponent))
        False -> Ok(Nil)
      }
    }
  }
}

fn validate_self_intersection_options(
  options: SelfIntersectionOptions,
) -> Result(Nil, Error) {
  case
    options.minimum_arc_length_separation <=. 0.0
    || !number.is_finite(options.minimum_arc_length_separation)
  {
    True ->
      Error(InvalidSelfIntersectionMinimumArcLengthSeparation(
        options.minimum_arc_length_separation,
      ))
    False -> {
      case
        options.distance_tolerance <=. 0.0
        || !number.is_finite(options.distance_tolerance)
      {
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

type DistanceMinimum {
  DistanceMinimum(left_t: Float, right_t: Float, distance_squared: Float)
}

type IndexedProjectionSegment {
  IndexedProjectionSegment(index: Int, segment: Segment, bounds: BoundingBox)
}

type SegmentListProjection {
  SegmentListProjection(
    left_index: Int,
    right_index: Int,
    projection: SegmentSegmentProjection,
  )
}

type TerminalWindow {
  TerminalWindow(
    id: Int,
    left: IntersectionPiece,
    right: IntersectionPiece,
    start_left_t: Float,
    start_right_t: Float,
  )
}

type RawTerminalWindow {
  RawTerminalWindow(
    left: IntersectionPiece,
    right: IntersectionPiece,
    start_left_t: Float,
    start_right_t: Float,
  )
}

type ProjectionWindow {
  ProjectionWindow(
    left: IntersectionPiece,
    right: IntersectionPiece,
    remaining_depth: Int,
  )
}

type WindowRecord {
  WindowRecord(window: TerminalWindow)
}

type DescentStatus {
  Pending
  Finished(List(DistanceMinimum))
}

type DescentRecord {
  DescentRecord(
    id: Int,
    window_id: Int,
    current: DistanceMinimum,
    last_window: Option(Int),
    status: DescentStatus,
  )
}

type DescentState {
  DescentState(windows: List(WindowRecord), descents: List(DescentRecord))
}

type ParameterSnapCandidate {
  ParameterSnapCandidate(t: Float, rank: Int)
}

type SnappedIntersectionCandidate {
  SnappedIntersectionCandidate(
    intersection: SegmentIntersection,
    distance_squared: Float,
    rank: Int,
  )
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
          parameter_snap: NoParameterSnap,
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
        Error(error) -> Error(error)
        Ok(intersections) ->
          certify_segment_intersections(
            left,
            right,
            intersections,
            options.tolerance,
          )
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
          parameter_snap: NoParameterSnap,
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

fn line_segment_intersections(
  line_start line_start: Point,
  line_end line_end: Point,
  line_is_left line_is_left: Bool,
  segment segment: Segment,
  options options: IntersectionOptions,
) -> Result(List(SegmentIntersection), Error) {
  let line_direction = point_difference(line_end, line_start)
  let line_parameter_tolerance =
    parameter_tolerance_for_chord(line_direction, options.tolerance)

  case segment_lies_on_line(segment, line_start, line_end, options.tolerance) {
    True -> Error(OverlappingSegments)
    False -> {
      case segment {
        Line(start: segment_start, end: segment_end) -> {
          case
            line_segments_are_collinear(
              line_start,
              line_end,
              segment_start,
              segment_end,
              options.tolerance,
            )
          {
            True ->
              collinear_line_point_intersections(
                line_start,
                line_end,
                segment_start,
                segment_end,
                line_is_left,
                line_parameter_tolerance,
              )
            False ->
              line_segment_intersections_by_ray(
                line_start,
                line_direction,
                line_is_left,
                segment,
                options,
                line_parameter_tolerance,
              )
          }
        }
        _ ->
          line_segment_intersections_by_ray(
            line_start,
            line_direction,
            line_is_left,
            segment,
            options,
            line_parameter_tolerance,
          )
      }
    }
  }
}

fn line_segment_intersections_by_ray(
  line_start: Point,
  line_direction: Point,
  line_is_left: Bool,
  segment: Segment,
  options: IntersectionOptions,
  line_parameter_tolerance: Float,
) -> Result(List(SegmentIntersection), Error) {
  case
    svg_path.segment_ray_crossings_with(
      segment,
      origin: line_start,
      direction: line_direction,
      options: svg_path.CrossingOptions(
        samples: 1,
        signed_line_distance_tolerance: options.tolerance,
        max_iterations: options.max_depth * 4,
      ),
    )
  {
    Error(error) -> Error(error)
    Ok(crossings) -> {
      line_segment_intersections_from_crossings(
        line_is_left,
        segment,
        crossings,
        options.tolerance,
        line_parameter_tolerance,
        [],
      )
    }
  }
}

fn line_segments_are_collinear(
  line_start: Point,
  line_end: Point,
  segment_start: Point,
  segment_end: Point,
  tolerance: Float,
) -> Bool {
  let direction = point_difference(line_end, line_start)
  let direction_length = distance(Point(0.0, 0.0), direction)
  direction_length >. 0.0
  && float.absolute_value(cross(
    direction,
    point_difference(segment_start, line_start),
  ))
  /. direction_length
  <=. tolerance
  && float.absolute_value(cross(
    direction,
    point_difference(segment_end, line_start),
  ))
  /. direction_length
  <=. tolerance
}

fn collinear_line_point_intersections(
  line_start: Point,
  line_end: Point,
  segment_start: Point,
  segment_end: Point,
  line_is_left: Bool,
  line_parameter_tolerance: Float,
) -> Result(List(SegmentIntersection), Error) {
  let segment_start_line_t =
    line_projection_t(segment_start, line_start, line_end)
  let segment_end_line_t = line_projection_t(segment_end, line_start, line_end)
  let overlap_start =
    float.max(0.0, float.min(segment_start_line_t, segment_end_line_t))
  let overlap_end =
    float.min(1.0, float.max(segment_start_line_t, segment_end_line_t))

  case overlap_end <. overlap_start -. line_parameter_tolerance {
    True -> Ok([])
    False -> {
      case overlap_end -. overlap_start <=. line_parameter_tolerance {
        True -> {
          let line_t = clamp01({ overlap_start +. overlap_end } /. 2.0)
          let point = interpolate(line_start, line_end, line_t)
          let segment_t =
            line_projection_t(point, segment_start, segment_end)
            |> clamp01

          Ok([
            case line_is_left {
              True ->
                SegmentIntersection(left_t: line_t, right_t: segment_t, point:)
              False ->
                SegmentIntersection(left_t: segment_t, right_t: line_t, point:)
            },
          ])
        }
        False -> Error(OverlappingSegments)
      }
    }
  }
}

fn line_segment_intersections_from_crossings(
  line_is_left: Bool,
  segment: Segment,
  crossings: List(#(Float, Float)),
  point_tolerance: Float,
  line_parameter_tolerance: Float,
  intersections: List(SegmentIntersection),
) -> Result(List(SegmentIntersection), Error) {
  case crossings {
    [] -> Ok(intersections)
    [crossing, ..rest] -> {
      let #(segment_t, line_t) = crossing
      case svg_path.segment_point(segment, at: segment_t) {
        Error(error) -> Error(error)
        Ok(point) -> {
          case in_unit_range(line_t, line_parameter_tolerance) {
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

              line_segment_intersections_from_crossings(
                line_is_left,
                segment,
                rest,
                point_tolerance,
                line_parameter_tolerance,
                insert_intersection(
                  intersections,
                  intersection,
                  point_tolerance:,
                  parameter_tolerance: intersection_parameter_dedupe_tolerance,
                ),
              )
            }
            False ->
              line_segment_intersections_from_crossings(
                line_is_left,
                segment,
                rest,
                point_tolerance,
                line_parameter_tolerance,
                intersections,
              )
          }
        }
      }
    }
  }
}

fn parameter_tolerance_for_chord(direction: Point, tolerance: Float) -> Float {
  let chord = distance(Point(0.0, 0.0), direction)
  case chord <=. 0.0 {
    True -> intersection_parameter_dedupe_tolerance
    False -> tolerance /. chord
  }
}

fn curve_curve_intersections(
  left: Segment,
  right: Segment,
  options: IntersectionOptions,
) -> Result(List(SegmentIntersection), Error) {
  use minima <- result.try(segment_pair_intersection_minima(
    left,
    right,
    options,
  ))
  segment_intersections_from_minima(
    left,
    right,
    minima,
    tolerance: options.tolerance,
    intersections: [],
  )
}

fn segment_pair_intersection_minima(
  left: Segment,
  right: Segment,
  options: IntersectionOptions,
) -> Result(List(DistanceMinimum), Error) {
  use boundary_minima <- result.try(boundary_edge_minima(left, right, options))
  use raw_terminal_windows <- result.try(
    collect_intersection_terminal_windows(
      IntersectionPiece(segment: left, from: 0.0, to: 1.0),
      IntersectionPiece(segment: right, from: 0.0, to: 1.0),
      options,
      remaining_depth: options.max_depth,
      windows: [],
    ),
  )
  let terminal_windows =
    number_terminal_windows(list.reverse(raw_terminal_windows), next_id: 0)
  use terminal_minima <- result.try(minima_from_terminal_windows(
    terminal_windows,
    finish_tolerance: options.tolerance,
  ))
  Ok(list.append(boundary_minima, terminal_minima))
}

fn segment_pair_projection_minima(
  left: Segment,
  right: Segment,
  options: IntersectionOptions,
) -> Result(List(DistanceMinimum), Error) {
  use boundary_minima <- result.try(boundary_edge_minima(left, right, options))
  use best <- result.try(best_distance_minimum(boundary_minima))
  use #(raw_terminal_windows, best) <- result.try(
    collect_projection_terminal_windows(
      IntersectionPiece(segment: left, from: 0.0, to: 1.0),
      IntersectionPiece(segment: right, from: 0.0, to: 1.0),
      best:,
      remaining_depth: options.max_depth,
      windows: [],
    ),
  )
  let terminal_windows =
    number_terminal_windows(list.reverse(raw_terminal_windows), next_id: 0)
  use terminal_minima <- result.try(minima_from_terminal_windows(
    terminal_windows,
    finish_tolerance: options.tolerance,
  ))
  Ok([best, ..list.append(boundary_minima, terminal_minima)])
}

fn boundary_edge_minima(
  left: Segment,
  right: Segment,
  options: IntersectionOptions,
) -> Result(List(DistanceMinimum), Error) {
  use minima <- result.try(
    boundary_edge_intersections_for_left(
      left,
      right,
      left_t: 0.0,
      options:,
      minima: [],
    ),
  )
  use minima <- result.try(boundary_edge_intersections_for_left(
    left,
    right,
    left_t: 1.0,
    options:,
    minima:,
  ))
  use minima <- result.try(boundary_edge_intersections_for_right(
    left,
    right,
    right_t: 0.0,
    options:,
    minima:,
  ))
  boundary_edge_intersections_for_right(
    left,
    right,
    right_t: 1.0,
    options:,
    minima:,
  )
}

fn boundary_edge_intersections_for_left(
  left: Segment,
  right: Segment,
  left_t left_t: Float,
  options options: IntersectionOptions,
  minima minima: List(DistanceMinimum),
) -> Result(List(DistanceMinimum), Error) {
  use point <- result.try(svg_path.segment_point(left, at: left_t))
  use projection <- result.try(svg_path.segment_projection_with(
    point,
    to: right,
    options: distance_options_for_intersection_options(options),
  ))
  let svg_path.SegmentProjection(t: right_t, distance:, ..) = projection
  boundary_edge_minimum(left_t, right_t, distance:, minima:)
}

fn boundary_edge_minimum(
  left_t: Float,
  right_t: Float,
  distance distance: Float,
  minima minima: List(DistanceMinimum),
) -> Result(List(DistanceMinimum), Error) {
  Ok([
    DistanceMinimum(
      left_t: clamp01(left_t),
      right_t: clamp01(right_t),
      distance_squared: distance *. distance,
    ),
    ..minima
  ])
}

fn distance_options_for_intersection_options(
  options: IntersectionOptions,
) -> svg_path.DistanceOptions {
  svg_path.DistanceOptions(
    ..svg_path.default_distance_options(),
    tolerance: options.tolerance,
    max_iterations: options.max_depth,
  )
}

fn boundary_edge_intersections_for_right(
  left: Segment,
  right: Segment,
  right_t right_t: Float,
  options options: IntersectionOptions,
  minima minima: List(DistanceMinimum),
) -> Result(List(DistanceMinimum), Error) {
  use point <- result.try(svg_path.segment_point(right, at: right_t))
  use projection <- result.try(svg_path.segment_projection_with(
    point,
    to: left,
    options: distance_options_for_intersection_options(options),
  ))
  let svg_path.SegmentProjection(t: left_t, distance:, ..) = projection
  boundary_edge_minimum(left_t, right_t, distance:, minima:)
}

fn collect_intersection_terminal_windows(
  left: IntersectionPiece,
  right: IntersectionPiece,
  options: IntersectionOptions,
  remaining_depth remaining_depth: Int,
  windows windows: List(RawTerminalWindow),
) -> Result(List(RawTerminalWindow), Error) {
  case
    intersection_piece_bounding_box(left),
    intersection_piece_bounding_box(right)
  {
    Error(error), _ | _, Error(error) -> Error(error)
    Ok(left_box), Ok(right_box) -> {
      case boxes_overlap(left_box, right_box, options.tolerance) {
        False -> Ok(windows)
        True -> {
          case
            remaining_depth <= 0
            || {
              svg_path.bounding_box_diameter(left_box)
              <=. terminal_subdivision_tolerance
              && svg_path.bounding_box_diameter(right_box)
              <=. terminal_subdivision_tolerance
            }
          {
            True -> Ok(add_terminal_window_grid(left, right, windows))
            False -> {
              let split_left =
                svg_path.bounding_box_diameter(left_box)
                >=. svg_path.bounding_box_diameter(right_box)

              case split_left {
                True -> {
                  let #(first, second) = split_intersection_piece(left)

                  use windows <- result.try(
                    collect_intersection_terminal_windows(
                      first,
                      right,
                      options,
                      remaining_depth: remaining_depth - 1,
                      windows:,
                    ),
                  )
                  collect_intersection_terminal_windows(
                    second,
                    right,
                    options,
                    remaining_depth: remaining_depth - 1,
                    windows:,
                  )
                }
                False -> {
                  let #(first, second) = split_intersection_piece(right)

                  use windows <- result.try(
                    collect_intersection_terminal_windows(
                      left,
                      first,
                      options,
                      remaining_depth: remaining_depth - 1,
                      windows:,
                    ),
                  )
                  collect_intersection_terminal_windows(
                    left,
                    second,
                    options,
                    remaining_depth: remaining_depth - 1,
                    windows:,
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

fn collect_projection_terminal_windows(
  left: IntersectionPiece,
  right: IntersectionPiece,
  best best: DistanceMinimum,
  remaining_depth remaining_depth: Int,
  windows windows: List(RawTerminalWindow),
) -> Result(#(List(RawTerminalWindow), DistanceMinimum), Error) {
  collect_projection_terminal_windows_generation(
    this_generation: [ProjectionWindow(left:, right:, remaining_depth:)],
    next_generation: [],
    best:,
    windows:,
  )
}

fn collect_projection_terminal_windows_generation(
  this_generation this_generation: List(ProjectionWindow),
  next_generation next_generation: List(ProjectionWindow),
  best best: DistanceMinimum,
  windows windows: List(RawTerminalWindow),
) -> Result(#(List(RawTerminalWindow), DistanceMinimum), Error) {
  case this_generation {
    [] -> {
      case next_generation {
        [] -> Ok(#(windows, best))
        [_, ..] ->
          collect_projection_terminal_windows_generation(
            this_generation: next_generation,
            next_generation: [],
            best:,
            windows:,
          )
      }
    }
    [ProjectionWindow(left:, right:, remaining_depth:), ..rest] -> {
      use #(windows, best, next_generation) <- result.try(
        inspect_projection_window(
          left,
          right,
          remaining_depth:,
          best:,
          windows:,
          next_generation:,
        ),
      )
      collect_projection_terminal_windows_generation(
        this_generation: rest,
        next_generation:,
        best:,
        windows:,
      )
    }
  }
}

fn inspect_projection_window(
  left: IntersectionPiece,
  right: IntersectionPiece,
  remaining_depth remaining_depth: Int,
  best best: DistanceMinimum,
  windows windows: List(RawTerminalWindow),
  next_generation next_generation: List(ProjectionWindow),
) -> Result(
  #(List(RawTerminalWindow), DistanceMinimum, List(ProjectionWindow)),
  Error,
) {
  case
    intersection_piece_bounding_box(left),
    intersection_piece_bounding_box(right)
  {
    Error(error), _ | _, Error(error) -> Error(error)
    Ok(left_box), Ok(right_box) -> {
      case
        bounding_box_distance_squared(left_box, right_box)
        >. best.distance_squared
      {
        True -> Ok(#(windows, best, next_generation))
        False -> {
          case
            remaining_depth <= 0
            || {
              svg_path.bounding_box_diameter(left_box)
              <=. terminal_subdivision_tolerance
              && svg_path.bounding_box_diameter(right_box)
              <=. terminal_subdivision_tolerance
            }
          {
            True -> {
              let added = add_terminal_window_grid(left, right, windows)
              use best <- result.try(best_new_raw_terminal_window_start_minimum(
                added,
                count: 9,
                best:,
              ))
              Ok(#(added, best, next_generation))
            }
            False -> {
              let split_left =
                svg_path.bounding_box_diameter(left_box)
                >=. svg_path.bounding_box_diameter(right_box)

              case split_left {
                True -> {
                  let #(first, second) = split_intersection_piece(left)
                  Ok(
                    #(windows, best, [
                      ProjectionWindow(
                        left: second,
                        right:,
                        remaining_depth: remaining_depth - 1,
                      ),
                      ProjectionWindow(
                        left: first,
                        right:,
                        remaining_depth: remaining_depth - 1,
                      ),
                      ..next_generation
                    ]),
                  )
                }
                False -> {
                  let #(first, second) = split_intersection_piece(right)
                  Ok(
                    #(windows, best, [
                      ProjectionWindow(
                        left:,
                        right: second,
                        remaining_depth: remaining_depth - 1,
                      ),
                      ProjectionWindow(
                        left:,
                        right: first,
                        remaining_depth: remaining_depth - 1,
                      ),
                      ..next_generation
                    ]),
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

fn number_terminal_windows(
  windows: List(RawTerminalWindow),
  next_id next_id: Int,
) -> List(TerminalWindow) {
  case windows {
    [] -> []
    [RawTerminalWindow(left:, right:, start_left_t:, start_right_t:), ..rest] -> [
      TerminalWindow(id: next_id, left:, right:, start_left_t:, start_right_t:),
      ..number_terminal_windows(rest, next_id: next_id + 1)
    ]
  }
}

fn add_terminal_window_grid(
  left: IntersectionPiece,
  right: IntersectionPiece,
  windows: List(RawTerminalWindow),
) -> List(RawTerminalWindow) {
  let assert Ok(left_thirds) = split_intersection_piece_thirds(left)
  let assert Ok(right_thirds) = split_intersection_piece_thirds(right)
  add_terminal_window_grid_rows(left_thirds, right_thirds, windows)
}

fn best_new_raw_terminal_window_start_minimum(
  windows: List(RawTerminalWindow),
  count count: Int,
  best best: DistanceMinimum,
) -> Result(DistanceMinimum, Error) {
  case windows, count {
    _, 0 -> Ok(best)
    [], _ -> Ok(best)
    [RawTerminalWindow(left:, right:, start_left_t:, start_right_t:), ..rest], _
    -> {
      use candidate <- result.try(global_distance_minimum_at(
        left,
        right,
        interpolate_float(left.from, left.to, start_left_t),
        interpolate_float(right.from, right.to, start_right_t),
      ))
      let best = closer_distance_minimum(best, candidate)
      best_new_raw_terminal_window_start_minimum(rest, count: count - 1, best:)
    }
  }
}

fn closer_distance_minimum(
  best: DistanceMinimum,
  candidate: DistanceMinimum,
) -> DistanceMinimum {
  case candidate.distance_squared <. best.distance_squared {
    True -> candidate
    False -> best
  }
}

fn bounding_box_distance_squared(
  left: BoundingBox,
  right: BoundingBox,
) -> Float {
  let dx =
    float.max(
      0.0,
      float.max(left.min.x -. right.max.x, right.min.x -. left.max.x),
    )
  let dy =
    float.max(
      0.0,
      float.max(left.min.y -. right.max.y, right.min.y -. left.max.y),
    )
  dx *. dx +. dy *. dy
}

fn add_terminal_window_grid_rows(
  lefts: List(#(IntersectionPiece, Float)),
  rights: List(#(IntersectionPiece, Float)),
  windows: List(RawTerminalWindow),
) -> List(RawTerminalWindow) {
  case lefts {
    [] -> windows
    [#(left, start_left_t), ..rest] ->
      add_terminal_window_grid_rows(
        rest,
        rights,
        add_terminal_window_grid_columns(left, start_left_t, rights, windows),
      )
  }
}

fn add_terminal_window_grid_columns(
  left: IntersectionPiece,
  start_left_t: Float,
  rights: List(#(IntersectionPiece, Float)),
  windows: List(RawTerminalWindow),
) -> List(RawTerminalWindow) {
  case rights {
    [] -> windows
    [#(right, start_right_t), ..rest] ->
      add_terminal_window_grid_columns(left, start_left_t, rest, [
        RawTerminalWindow(left:, right:, start_left_t:, start_right_t:),
        ..windows
      ])
  }
}

fn split_intersection_piece_thirds(
  piece: IntersectionPiece,
) -> Result(List(#(IntersectionPiece, Float)), Error) {
  let first_to = interpolate_float(piece.from, piece.to, 1.0 /. 3.0)
  let second_to = interpolate_float(piece.from, piece.to, 2.0 /. 3.0)
  Ok([
    #(
      IntersectionPiece(segment: piece.segment, from: piece.from, to: first_to),
      terminal_grid_margin,
    ),
    #(
      IntersectionPiece(segment: piece.segment, from: first_to, to: second_to),
      0.5,
    ),
    #(
      IntersectionPiece(segment: piece.segment, from: second_to, to: piece.to),
      1.0 -. terminal_grid_margin,
    ),
  ])
}

fn minima_from_terminal_windows(
  windows: List(TerminalWindow),
  finish_tolerance finish_tolerance: Float,
) -> Result(List(DistanceMinimum), Error) {
  use descents <- result.try(initial_descent_records(windows))
  let state =
    DescentState(
      windows: windows |> list.map(fn(window) { WindowRecord(window:) }),
      descents:,
    )
  use final_state <- result.try(run_descents(
    windows,
    state,
    certification_tolerance: finish_tolerance,
  ))
  Ok(finished_minima(final_state.descents, minima: []))
}

fn initial_descent_records(
  windows: List(TerminalWindow),
) -> Result(List(DescentRecord), Error) {
  initial_descent_records_loop(windows, descents: [])
}

fn initial_descent_records_loop(
  windows: List(TerminalWindow),
  descents descents: List(DescentRecord),
) -> Result(List(DescentRecord), Error) {
  case windows {
    [] -> Ok(list.reverse(descents))
    [TerminalWindow(id:, left:, right:, start_left_t:, start_right_t:), ..rest] -> {
      use current <- result.try(global_distance_minimum_at(
        left,
        right,
        interpolate_float(left.from, left.to, start_left_t),
        interpolate_float(right.from, right.to, start_right_t),
      ))
      initial_descent_records_loop(rest, descents: [
        DescentRecord(
          id:,
          window_id: id,
          current:,
          last_window: Some(id),
          status: Pending,
        ),
        ..descents
      ])
    }
  }
}

fn run_descents(
  windows_to_run: List(TerminalWindow),
  state: DescentState,
  certification_tolerance certification_tolerance: Float,
) -> Result(DescentState, Error) {
  case windows_to_run {
    [] -> Ok(state)
    [window, ..rest] -> {
      let TerminalWindow(id:, ..) = window
      use state <- result.try(case find_descent(state.descents, id) {
        Ok(DescentRecord(status: Pending, ..)) ->
          run_one_descent(
            id,
            state,
            certification_tolerance:,
            step: 1.0,
            iterations: 45,
          )
        _ -> Ok(state)
      })
      run_descents(rest, state, certification_tolerance:)
    }
  }
}

fn run_one_descent(
  descent_id: Int,
  state: DescentState,
  certification_tolerance certification_tolerance: Float,
  step step: Float,
  iterations iterations: Int,
) -> Result(DescentState, Error) {
  use descent <- result.try(find_descent(state.descents, descent_id))
  case descent.status {
    Finished(_) -> Ok(state)
    Pending -> {
      case iterations <= 0 || step <=. 0.000000000001 {
        True ->
          finish_descent(
            descent,
            state,
            certification_tolerance,
            remaining_iterations: iterations,
          )
        False -> {
          use #(proposal, raw_left_t, raw_right_t) <- result.try(
            gradient_distance_proposal_unclamped(
              descent,
              state,
              step,
              use_tangent_line_crossing: iterations % 2 == 0,
            ),
          )
          let accepted =
            proposal.distance_squared <. descent.current.distance_squared
          case accepted {
            False ->
              run_one_descent(
                descent_id,
                state,
                certification_tolerance:,
                step: step /. 2.0,
                iterations: iterations - 1,
              )
            True -> {
              let improvement =
                descent.current.distance_squared -. proposal.distance_squared
              let descent = DescentRecord(..descent, current: proposal)
              let state = replace_descent(state, descent)
              use state <- result.try(handle_window_transition(
                descent,
                state,
                raw_left_t,
                raw_right_t,
              ))
              use descent <- result.try(find_descent(state.descents, descent_id))
              case descent.status {
                Finished(_) -> Ok(state)
                Pending -> {
                  case
                    descent.current.distance_squared == 0.0
                    || improvement
                    <=. certification_tolerance
                    *. certification_tolerance
                    *. 0.000001
                  {
                    True ->
                      finish_descent(
                        descent,
                        state,
                        certification_tolerance,
                        remaining_iterations: iterations,
                      )
                    False ->
                      run_one_descent(
                        descent_id,
                        state,
                        certification_tolerance:,
                        step:,
                        iterations: iterations - 1,
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

fn gradient_distance_proposal_unclamped(
  descent: DescentRecord,
  state: DescentState,
  step: Float,
  use_tangent_line_crossing use_tangent_line_crossing: Bool,
) -> Result(#(DistanceMinimum, Float, Float), Error) {
  use window <- result.try(find_window(state.windows, descent.window_id))
  let WindowRecord(window: TerminalWindow(left:, right:, ..)) = window
  let DistanceMinimum(left_t:, right_t:, ..) = descent.current
  use left_point <- result.try(global_piece_point(left, left_t))
  use right_point <- result.try(global_piece_point(right, right_t))
  use left_derivative <- result.try(svg_path.segment_derivative(
    left.segment,
    at: left_t,
  ))
  use right_derivative <- result.try(svg_path.segment_derivative(
    right.segment,
    at: right_t,
  ))
  let separation = point_difference(left_point, right_point)
  let left_speed_squared =
    float.max(dot(left_derivative, left_derivative), 0.000000000000000001)
  let right_speed_squared =
    float.max(dot(right_derivative, right_derivative), 0.000000000000000001)
  let left_gradient = 2.0 *. dot(separation, left_derivative)
  let right_gradient = -2.0 *. dot(separation, right_derivative)
  let raw_left_t = left_t -. step *. left_gradient /. left_speed_squared
  let raw_right_t = right_t -. step *. right_gradient /. right_speed_squared
  use gradient_proposal <- result.try(global_distance_minimum_at(
    left,
    right,
    clamp01(raw_left_t),
    clamp01(raw_right_t),
  ))
  use proposal <- result.try(best_gauss_newton_or_gradient_proposal(
    left,
    right,
    current: descent.current,
    separation:,
    left_derivative:,
    right_derivative:,
    gradient: #(gradient_proposal, raw_left_t, raw_right_t),
    use_tangent_line_crossing:,
  ))
  Ok(proposal)
}

fn best_gauss_newton_or_gradient_proposal(
  left: IntersectionPiece,
  right: IntersectionPiece,
  current current: DistanceMinimum,
  separation separation: Point,
  left_derivative left_derivative: Point,
  right_derivative right_derivative: Point,
  gradient gradient: #(DistanceMinimum, Float, Float),
  use_tangent_line_crossing use_tangent_line_crossing: Bool,
) -> Result(#(DistanceMinimum, Float, Float), Error) {
  case current.distance_squared <=. 0.0001 *. 0.0001 {
    False -> Ok(gradient)
    True ->
      best_alternating_local_crossing_polish(
        left,
        right,
        current:,
        separation:,
        left_derivative:,
        right_derivative:,
        gradient:,
        use_tangent_line_crossing:,
      )
  }
}

fn best_alternating_local_crossing_polish(
  left: IntersectionPiece,
  right: IntersectionPiece,
  current current: DistanceMinimum,
  separation separation: Point,
  left_derivative left_derivative: Point,
  right_derivative right_derivative: Point,
  gradient gradient: #(DistanceMinimum, Float, Float),
  use_tangent_line_crossing use_tangent_line_crossing: Bool,
) -> Result(#(DistanceMinimum, Float, Float), Error) {
  case use_tangent_line_crossing {
    True -> {
      use tangent <- result.try(tangent_line_crossing_proposal(
        left,
        right,
        current:,
        separation:,
        left_derivative:,
        right_derivative:,
      ))
      Ok(best_distance_proposal(gradient, tangent))
    }
    False ->
      best_gauss_newton_or_gradient_polish(
        left,
        right,
        current:,
        separation:,
        left_derivative:,
        right_derivative:,
        gradient:,
      )
  }
}

fn best_gauss_newton_or_gradient_polish(
  left: IntersectionPiece,
  right: IntersectionPiece,
  current current: DistanceMinimum,
  separation separation: Point,
  left_derivative left_derivative: Point,
  right_derivative right_derivative: Point,
  gradient gradient: #(DistanceMinimum, Float, Float),
) -> Result(#(DistanceMinimum, Float, Float), Error) {
  let a = dot(left_derivative, left_derivative)
  let b = 0.0 -. dot(left_derivative, right_derivative)
  let c = dot(right_derivative, right_derivative)
  let g1 = dot(left_derivative, separation)
  let g2 = 0.0 -. dot(right_derivative, separation)
  let determinant = a *. c -. b *. b

  case determinant <=. 0.000000000000000001 *. float.max(a *. c, 1.0) {
    True -> Ok(gradient)
    False -> {
      let delta_left = { b *. g2 -. c *. g1 } /. determinant
      let delta_right = { b *. g1 -. a *. g2 } /. determinant
      let raw_left_t = current.left_t +. delta_left
      let raw_right_t = current.right_t +. delta_right
      use candidate <- result.try(global_distance_minimum_at(
        left,
        right,
        clamp01(raw_left_t),
        clamp01(raw_right_t),
      ))
      let #(gradient_candidate, _, _) = gradient
      case candidate.distance_squared <. gradient_candidate.distance_squared {
        True -> Ok(#(candidate, raw_left_t, raw_right_t))
        False -> Ok(gradient)
      }
    }
  }
}

fn tangent_line_crossing_proposal(
  left: IntersectionPiece,
  right: IntersectionPiece,
  current current: DistanceMinimum,
  separation separation: Point,
  left_derivative left_derivative: Point,
  right_derivative right_derivative: Point,
) -> Result(#(DistanceMinimum, Float, Float), Error) {
  let determinant = cross(left_derivative, right_derivative)
  let scale =
    float.max(
      float.max(dot(left_derivative, left_derivative), 1.0)
        *. float.max(dot(right_derivative, right_derivative), 1.0),
      1.0,
    )

  case determinant *. determinant <=. 0.000000000000000001 *. scale {
    True -> Ok(#(current, current.left_t, current.right_t))
    False -> {
      let delta_left = 0.0 -. cross(separation, right_derivative) /. determinant
      let delta_right = 0.0 -. cross(separation, left_derivative) /. determinant
      let raw_left_t = current.left_t +. delta_left
      let raw_right_t = current.right_t +. delta_right
      use candidate <- result.try(global_distance_minimum_at(
        left,
        right,
        clamp01(raw_left_t),
        clamp01(raw_right_t),
      ))
      Ok(#(candidate, raw_left_t, raw_right_t))
    }
  }
}

fn best_distance_proposal(
  first: #(DistanceMinimum, Float, Float),
  second: #(DistanceMinimum, Float, Float),
) -> #(DistanceMinimum, Float, Float) {
  let #(first_minimum, _, _) = first
  let #(second_minimum, _, _) = second
  case second_minimum.distance_squared <. first_minimum.distance_squared {
    True -> second
    False -> first
  }
}

fn handle_window_transition(
  descent: DescentRecord,
  state: DescentState,
  raw_left_t: Float,
  raw_right_t: Float,
) -> Result(DescentState, Error) {
  let containing =
    window_containing_global_point(state.windows, raw_left_t, raw_right_t)

  case descent.last_window, containing {
    Some(last), Some(next) if last == next -> Ok(state)
    _, None ->
      Ok(replace_descent(state, DescentRecord(..descent, last_window: None)))
    _, Some(next_window_id) -> {
      move_descent_to_window(
        descent,
        next_window_id,
        state,
        raw_left_t,
        raw_right_t,
      )
    }
  }
}

fn move_descent_to_window(
  descent: DescentRecord,
  target_window_id: Int,
  state: DescentState,
  global_left_t: Float,
  global_right_t: Float,
) -> Result(DescentState, Error) {
  use window_record <- result.try(find_window(state.windows, target_window_id))
  use entrant_current <- result.try(distance_minimum_in_window(
    window_record.window,
    global_left_t,
    global_right_t,
  ))
  let entrant =
    DescentRecord(
      ..descent,
      window_id: target_window_id,
      current: entrant_current,
      last_window: Some(target_window_id),
    )

  Ok(replace_descent(state, entrant))
}

fn distance_minimum_in_window(
  window: TerminalWindow,
  global_left_t: Float,
  global_right_t: Float,
) -> Result(DistanceMinimum, Error) {
  global_distance_minimum_at(
    window.left,
    window.right,
    global_left_t,
    global_right_t,
  )
}

fn intersection_piece_bounding_box(
  piece: IntersectionPiece,
) -> Result(BoundingBox, Error) {
  use segment <- result.try(svg_path.segment_between(
    piece.segment,
    from: piece.from,
    to: piece.to,
  ))
  svg_path.segment_bounding_box(segment)
}

fn global_piece_point(
  piece: IntersectionPiece,
  global_t: Float,
) -> Result(Point, Error) {
  svg_path.segment_point(piece.segment, at: global_t)
}

fn global_distance_minimum_at(
  left: IntersectionPiece,
  right: IntersectionPiece,
  left_global_t: Float,
  right_global_t: Float,
) -> Result(DistanceMinimum, Error) {
  use left_point <- result.try(global_piece_point(left, left_global_t))
  use right_point <- result.try(global_piece_point(right, right_global_t))
  let dx = left_point.x -. right_point.x
  let dy = left_point.y -. right_point.y
  Ok(DistanceMinimum(
    left_t: left_global_t,
    right_t: right_global_t,
    distance_squared: dx *. dx +. dy *. dy,
  ))
}

fn finish_descent(
  descent: DescentRecord,
  state: DescentState,
  tolerance: Float,
  remaining_iterations _remaining_iterations: Int,
) -> Result(DescentState, Error) {
  let found = window_minima(descent.current, tolerance:)
  Ok(replace_descent(state, DescentRecord(..descent, status: Finished(found))))
}

fn window_minima(
  descent_minimum: DistanceMinimum,
  tolerance tolerance: Float,
) -> List(DistanceMinimum) {
  case descent_minimum.distance_squared <=. tolerance *. tolerance {
    True -> [descent_minimum]
    False -> [descent_minimum]
  }
}

fn segment_intersections_from_minima(
  left: Segment,
  right: Segment,
  minima: List(DistanceMinimum),
  tolerance tolerance: Float,
  intersections intersections: List(SegmentIntersection),
) -> Result(List(SegmentIntersection), Error) {
  case minima {
    [] -> Ok(intersections)
    [minimum, ..rest] -> {
      let DistanceMinimum(
        left_t: left_global_t,
        right_t: right_global_t,
        distance_squared:,
      ) = minimum
      case distance_squared <=. tolerance *. tolerance {
        False ->
          segment_intersections_from_minima(
            left,
            right,
            rest,
            tolerance:,
            intersections:,
          )
        True -> {
          use found <- result.try(segment_intersection_from_minimum(
            left,
            right,
            left_global_t,
            right_global_t,
          ))
          segment_intersections_from_minima(
            left,
            right,
            rest,
            tolerance:,
            intersections: insert_intersections(
              intersections,
              found,
              point_tolerance: intersection_dedupe_tolerance(tolerance),
              parameter_tolerance: intersection_parameter_dedupe_tolerance,
            ),
          )
        }
      }
    }
  }
}

fn finished_minima(
  descents: List(DescentRecord),
  minima minima: List(DistanceMinimum),
) -> List(DistanceMinimum) {
  case descents {
    [] -> minima
    [first, ..rest] -> {
      let minima = case first.status {
        Finished(found) -> list.append(found, minima)
        _ -> minima
      }
      finished_minima(rest, minima:)
    }
  }
}

fn find_window(
  windows: List(WindowRecord),
  id: Int,
) -> Result(WindowRecord, Error) {
  case windows {
    [] ->
      Error(InternalUncertifiedSegmentIntersection(
        left_distance: 1.0e100,
        right_distance: 1.0e100,
        tolerance: 0.0,
      ))
    [first, ..rest] -> {
      let WindowRecord(window: TerminalWindow(id: window_id, ..)) = first
      case window_id == id {
        True -> Ok(first)
        False -> find_window(rest, id)
      }
    }
  }
}

fn find_descent(
  descents: List(DescentRecord),
  id: Int,
) -> Result(DescentRecord, Error) {
  case descents {
    [] ->
      Error(InternalUncertifiedSegmentIntersection(
        left_distance: 1.0e100,
        right_distance: 1.0e100,
        tolerance: 0.0,
      ))
    [first, ..rest] -> {
      case first.id == id {
        True -> Ok(first)
        False -> find_descent(rest, id)
      }
    }
  }
}

fn replace_descent(
  state: DescentState,
  replacement: DescentRecord,
) -> DescentState {
  DescentState(
    ..state,
    descents: replace_descent_loop(state.descents, replacement),
  )
}

fn replace_descent_loop(
  descents: List(DescentRecord),
  replacement: DescentRecord,
) -> List(DescentRecord) {
  case descents {
    [] -> []
    [first, ..rest] -> {
      case first.id == replacement.id {
        True -> [replacement, ..rest]
        False -> [first, ..replace_descent_loop(rest, replacement)]
      }
    }
  }
}

fn window_containing_global_point(
  windows: List(WindowRecord),
  global_left_t: Float,
  global_right_t: Float,
) -> Option(Int) {
  case windows {
    [] -> None
    [first, ..rest] -> {
      let WindowRecord(window: TerminalWindow(id:, left:, right:, ..)) = first
      case
        global_left_t >=. left.from
        && global_left_t <=. left.to
        && global_right_t >=. right.from
        && global_right_t <=. right.to
      {
        True -> Some(id)
        False ->
          window_containing_global_point(rest, global_left_t, global_right_t)
      }
    }
  }
}

fn split_intersection_piece(
  piece: IntersectionPiece,
) -> #(IntersectionPiece, IntersectionPiece) {
  let middle = { piece.from +. piece.to } /. 2.0

  #(
    IntersectionPiece(segment: piece.segment, from: piece.from, to: middle),
    IntersectionPiece(segment: piece.segment, from: middle, to: piece.to),
  )
}

fn segment_intersection_from_minimum(
  left: Segment,
  right: Segment,
  left_global_t: Float,
  right_global_t: Float,
) -> Result(List(SegmentIntersection), Error) {
  case
    svg_path.segment_point(left, at: left_global_t),
    svg_path.segment_point(right, at: right_global_t)
  {
    Error(error), _ | _, Error(error) -> Error(error)
    Ok(left_point), Ok(right_point) ->
      Ok([
        SegmentIntersection(
          left_t: left_global_t,
          right_t: right_global_t,
          point: midpoint(left_point, right_point),
        ),
      ])
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
  let direction_length = distance(Point(0.0, 0.0), direction)

  case direction_length <=. 0.0, segment_defining_points(segment) {
    True, _ -> False
    False, None -> False
    False, Some(points) -> {
      list.all(points, fn(point) {
        float.absolute_value(cross(
          direction,
          point_difference(point, line_start),
        ))
        /. direction_length
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
  point_tolerance point_tolerance: Float,
  parameter_tolerance parameter_tolerance: Float,
) -> List(SegmentIntersection) {
  case intersections {
    [] -> [intersection]
    [first, ..rest] -> {
      case
        distance(first.point, intersection.point) <=. point_tolerance
        || {
          float.absolute_value(first.left_t -. intersection.left_t)
          <=. parameter_tolerance
          && float.absolute_value(first.right_t -. intersection.right_t)
          <=. parameter_tolerance
        }
      {
        True -> [preferred_duplicate_intersection(first, intersection), ..rest]
        False -> [
          first,
          ..insert_intersection(
            rest,
            intersection,
            point_tolerance:,
            parameter_tolerance:,
          )
        ]
      }
    }
  }
}

fn preferred_duplicate_intersection(
  first: SegmentIntersection,
  second: SegmentIntersection,
) -> SegmentIntersection {
  case endpoint_parameter_score(second) <. endpoint_parameter_score(first) {
    True -> second
    False -> first
  }
}

fn endpoint_parameter_score(intersection: SegmentIntersection) -> Float {
  let SegmentIntersection(left_t:, right_t:, ..) = intersection
  endpoint_distance_in_parameter(left_t)
  +. endpoint_distance_in_parameter(right_t)
}

fn endpoint_distance_in_parameter(t: Float) -> Float {
  float.min(float.absolute_value(t), float.absolute_value(1.0 -. t))
}

fn insert_intersections(
  intersections: List(SegmentIntersection),
  new_intersections: List(SegmentIntersection),
  point_tolerance point_tolerance: Float,
  parameter_tolerance parameter_tolerance: Float,
) -> List(SegmentIntersection) {
  list.fold(new_intersections, intersections, fn(intersections, intersection) {
    insert_intersection(
      intersections,
      intersection,
      point_tolerance:,
      parameter_tolerance:,
    )
  })
}

const intersection_parameter_dedupe_tolerance = 0.000000001

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
