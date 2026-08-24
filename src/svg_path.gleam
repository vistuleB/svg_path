//// Core SVG path data structures and constructors.
////
//// This module models paths as a list of subpaths, and subpaths as continuous
//// segment lists. Use `svg_path/parse` and `svg_path/serialize` when working
//// directly with SVG path data strings.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import svg_path/affine
import svg_path/bezier
import svg_path/ellipse
import svg_path/internal/number
import svg_path/root
import svg_path/trig

const default_wiggle_tolerance = 0.000000001

const default_crossing_samples = 100

const default_crossing_tolerance = 0.000000001

const default_crossing_max_iterations = 100

const default_minimize_samples = 100

const default_minimize_tolerance = 0.000000001

const default_minimize_max_iterations = 100

const golden_section_ratio = 0.6180339887498949

const default_length_tolerance = 0.000000001

const default_length_max_depth = 20

const default_linearize_tolerance = 0.01

const default_linearize_max_depth = 20

const default_distance_samples = 100

const default_distance_tolerance = 0.000000001

const default_distance_max_iterations = 100

const default_direction_relative_tolerance = 0.000000001

const default_containment_tolerance = 0.000000001

const default_self_intersection_tolerance = 0.000000001

const default_containment_samples = 100

const default_containment_max_iterations = 100

const default_containment_horizontal_ray_angle = 0.0

const default_containment_vertical_ray_angle = 90.0

const default_parametric_tolerance = 0.01

const default_parametric_samples_per_piece = 5

const default_parametric_initial_piece_count = 1

const default_parametric_max_depth = 10

/// A 2D point.
pub type Point {
  Point(x: Float, y: Float)
}

/// Singularity-safe unit traversal directions at a path parameter.
///
/// `incoming` points in the direction of traversal as the parameter is
/// approached. `outgoing` points in the direction of traversal after the
/// parameter. Either side is absent when the addressed geometry has no
/// direction on that side.
pub type Directions {
  Directions(incoming: Option(Point), outgoing: Option(Point))
}

/// Options for singularity-safe direction queries.
pub type DirectionOptions {
  DirectionOptions(
    /// Candidate vectors at or below this fraction of the largest local
    /// candidate are treated as collapsed. This must be finite and
    /// non-negative; zero skips only exact zero vectors.
    relative_tolerance: Float,
  )
}

/// An axis-aligned bounding box.
pub type BoundingBox {
  BoundingBox(min: Point, max: Point)
}

/// Error measurements for a fitted cubic Bezier segment.
pub type CubicFitReport {
  CubicFitReport(
    /// `sqrt(sum(distance(sample, fitted)^2))`.
    root_sum_square: Float,
    /// `sqrt(sum(distance(sample, fitted)^2) / sample_count)`.
    root_mean_square: Float,
    /// The largest sample distance.
    max: Float,
  )
}

/// Return the width of a bounding box.
pub fn bounding_box_width(box: BoundingBox) -> Float {
  box.max.x -. box.min.x
}

/// Return the height of a bounding box.
pub fn bounding_box_height(box: BoundingBox) -> Float {
  box.max.y -. box.min.y
}

/// Return the center point of a bounding box.
pub fn bounding_box_center(box: BoundingBox) -> Point {
  Point(
    box.min.x +. bounding_box_width(box) /. 2.0,
    box.min.y +. bounding_box_height(box) /. 2.0,
  )
}

/// Return the taxicab diameter of a bounding box.
///
/// This is the box width plus the box height.
pub fn bounding_box_diameter(box: BoundingBox) -> Float {
  bounding_box_width(box) +. bounding_box_height(box)
}

/// Return the smallest axis-aligned bounding box containing both boxes.
pub fn bounding_box_union(
  first: BoundingBox,
  second: BoundingBox,
) -> BoundingBox {
  BoundingBox(
    min: min_point(first.min, second.min),
    max: max_point(first.max, second.max),
  )
}

/// Return the smallest axis-aligned bounding box containing every box.
pub fn bounding_box_union_many(
  boxes: List(BoundingBox),
) -> Result(BoundingBox, Nil) {
  case boxes {
    [] -> Error(Nil)
    [first, ..rest] ->
      Ok(
        list.fold(rest, first, fn(box, next) { bounding_box_union(box, next) }),
      )
  }
}

/// Return the smallest axis-aligned bounding box containing every point.
pub fn points_bounding_box(points: List(Point)) -> Result(BoundingBox, Nil) {
  case points {
    [] -> Error(Nil)
    [first, ..rest] ->
      Ok(
        list.fold(rest, BoundingBox(min: first, max: first), fn(box, point) {
          BoundingBox(
            min: min_point(box.min, point),
            max: max_point(box.max, point),
          )
        }),
      )
  }
}

/// Options for detecting scalar zero crossings along a segment.
pub type CrossingOptions {
  CrossingOptions(
    /// Number of equal parameter windows scanned before refinement.
    samples: Int,
    /// Maximum finite, positive signed line-distance residual accepted during refinement.
    signed_line_distance_tolerance: Float,
    /// Maximum bisection steps for one candidate window.
    max_iterations: Int,
  )
}

/// Options for minimizing a scalar function along a segment.
pub type MinimizeOptions {
  MinimizeOptions(
    /// Number of equal parameter windows scanned for local minima.
    samples: Int,
    /// Maximum finite, positive parameter-window width accepted during
    /// refinement.
    parameter_tolerance: Float,
    /// Maximum golden-section steps for one candidate window.
    max_iterations: Int,
  )
}

/// Options for approximating the length of a segment or subpath.
pub type LengthOptions {
  LengthOptions(
    /// Maximum finite, positive path-coordinate error in one length estimate.
    tolerance: Float,
    /// Maximum recursive subdivision depth.
    max_depth: Int,
  )
}

/// Options for building a subpath from a parametric curve.
pub type ParametricOptions {
  ParametricOptions(
    /// Maximum finite, positive sampled fitting error for one piece.
    tolerance: Float,
    /// Number of interior fitting samples used for each candidate piece.
    samples_per_piece: Int,
    /// Number of equal parameter pieces attempted before adaptive subdivision.
    initial_piece_count: Int,
    /// Maximum recursive subdivision depth.
    max_depth: Int,
    /// Optional derivative function used to constrain endpoint tangents.
    tangent: Option(fn(Float) -> Point),
  )
}

/// Errors returned by fallible point-mapping helpers.
pub type PointMapError(error) {
  /// The path structure could not be mapped.
  PointMapPathError(Error)

  /// The caller-provided point mapping function failed.
  PointMapFunctionError(error)
}

/// Options for approximating segments with straight lines.
pub type LinearizeOptions {
  LinearizeOptions(
    /// Maximum finite, positive deviation from the line approximation.
    tolerance: Float,
    /// Maximum recursive subdivision depth.
    max_depth: Int,
  )
}

/// Options for finding the distance from a point to a segment.
///
/// `samples` controls arc projection and the explicit sampling-based projection
/// API. Quadratic and cubic projection uses polynomial root isolation instead.
pub type DistanceOptions {
  DistanceOptions(
    /// Number of equal parameter windows used by sampling-based projection.
    samples: Int,
    /// Maximum finite, positive geometric window diameter during refinement.
    tolerance: Float,
    /// Maximum refinement steps for one projection candidate.
    max_iterations: Int,
  )
}

/// Options for classifying a point relative to a subpath's fill area.
pub type ContainmentOptions {
  ContainmentOptions(
    /// Finite, positive distance at which a point is classified as boundary.
    tolerance: Float,
    /// Number of scan samples used by projection and crossing queries.
    samples: Int,
    /// Maximum refinement steps for projection and crossing candidates.
    max_iterations: Int,
    /// Fallback ray angles, in degrees, tried when the heuristic ray gives
    /// inconsistent positive/negative containment answers.
    fallback_ray_angles: List(Float),
  )
}

/// The SVG fill rule used for point containment and filled area.
pub type FillRule {
  Nonzero
  EvenOdd
}

/// The position of a point relative to a filled subpath.
pub type PointContainment {
  Inside
  Outside
  Boundary
}

/// The signed winding number of a path around a point.
pub type PathWinding {
  Winding(Int)
  BoundaryWinding
}

/// Options for finding self-intersections in one subpath.
pub type SelfIntersectionOptions {
  SelfIntersectionOptions(
    /// Finite, positive arc-length separation between two reported addresses.
    minimum_arc_length_separation: Float,
    /// Finite, positive distance between coincident points.
    distance_tolerance: Float,
  )
}

/// A point intersection between two segments.
pub type SegmentIntersection {
  SegmentIntersection(left_t: Float, right_t: Float, point: Point)
}

/// A closest-point pair between two segments.
///
/// When multiple pairs are equally nearest, this records one valid pair. The
/// chosen parameters are not guaranteed to be canonical for ties or flat
/// minima.
pub type SegmentSegmentProjection {
  SegmentSegmentProjection(
    left_t: Float,
    right_t: Float,
    left_point: Point,
    right_point: Point,
    distance: Float,
  )
}

/// A closest-point pair between a segment and a subpath.
///
/// When multiple pairs are equally nearest, this records one valid pair. The
/// chosen parameters are not guaranteed to be canonical for ties or flat
/// minima.
pub type SegmentSubpathProjection {
  SegmentSubpathProjection(
    left_t: Float,
    right_at: SubpathParameter,
    left_point: Point,
    right_point: Point,
    distance: Float,
  )
}

/// A closest-point pair between a segment and a path.
///
/// Move-only subpaths are skipped. When multiple pairs are equally nearest,
/// this records one valid pair. The chosen parameters are not guaranteed to be
/// canonical for ties or flat minima.
pub type SegmentPathProjection {
  SegmentPathProjection(
    left_t: Float,
    right_at: PathParameter,
    left_point: Point,
    right_point: Point,
    distance: Float,
  )
}

/// A closest-point pair between two subpaths.
///
/// When multiple pairs are equally nearest, this records one valid pair. The
/// chosen parameters are not guaranteed to be canonical for ties or flat
/// minima.
pub type SubpathSubpathProjection {
  SubpathSubpathProjection(
    left_at: SubpathParameter,
    right_at: SubpathParameter,
    left_point: Point,
    right_point: Point,
    distance: Float,
  )
}

/// A closest-point pair between a subpath and a path.
///
/// Move-only subpaths are skipped. When multiple pairs are equally nearest,
/// this records one valid pair. The chosen parameters are not guaranteed to be
/// canonical for ties or flat minima.
pub type SubpathPathProjection {
  SubpathPathProjection(
    left_at: SubpathParameter,
    right_at: PathParameter,
    left_point: Point,
    right_point: Point,
    distance: Float,
  )
}

/// A closest-point pair between two paths.
///
/// Move-only subpaths are skipped. When multiple pairs are equally nearest,
/// this records one valid pair. The chosen parameters are not guaranteed to be
/// canonical for ties or flat minima.
pub type PathPathProjection {
  PathPathProjection(
    left_at: PathParameter,
    right_at: PathParameter,
    left_point: Point,
    right_point: Point,
    distance: Float,
  )
}

/// A point where a subpath intersects itself.
pub type SubpathSelfIntersection {
  SubpathSelfIntersection(
    point: Point,
    parameters: #(SubpathParameter, SubpathParameter),
  )
}

/// A point where a path intersects itself.
pub type PathSelfIntersection {
  PathSelfIntersection(
    point: Point,
    parameters: #(PathParameter, PathParameter),
  )
}

/// A point intersection between two subpaths.
///
/// Multiple parameters are retained on both subpaths because a single point can
/// be reached multiple times by a self-intersecting subpath. Segment-boundary
/// aliases are canonicalized to one traversal address.
pub type SubpathIntersection {
  SubpathIntersection(
    point: Point,
    left_parameters: List(SubpathParameter),
    right_parameters: List(SubpathParameter),
  )
}

/// A point intersection between two paths.
///
/// Multiple parameters are retained on both paths because a single point can be
/// reached through multiple subpaths or through self-intersecting subpaths.
/// Segment-boundary aliases are canonicalized to one traversal address.
pub type PathIntersection {
  PathIntersection(
    point: Point,
    left_parameters: List(PathParameter),
    right_parameters: List(PathParameter),
  )
}

/// The nearest point on a segment to an input point.
///
/// When multiple segment points are equally nearest, this records one valid
/// nearest point. The chosen point and parameter are not guaranteed to be
/// canonical for ties or flat minima.
pub type SegmentProjection {
  SegmentProjection(t: Float, point: Point, distance: Float)
}

/// The nearest point on a subpath to an input point.
///
/// When multiple subpath points are equally nearest, this records one valid
/// nearest point. The chosen point and parameter are not guaranteed to be
/// canonical for ties or flat minima.
pub type SubpathProjection {
  SubpathProjection(at: SubpathParameter, point: Point, distance: Float)
}

/// The nearest point on a path to an input point.
///
/// Move-only subpaths are skipped. When multiple path points are equally
/// nearest, this records one valid nearest point. The chosen point and
/// parameter are not guaranteed to be canonical for ties or flat minima.
pub type PathProjection {
  PathProjection(at: PathParameter, point: Point, distance: Float)
}

type MinimizeCandidate {
  MinimizeCandidate(t: Float, value: Float)
}

type ContainmentCalculation {
  CalculatedBoundary
  CalculatedWinding(winding: Int, crossings: Int)
}

type ContainmentRay {
  ContainmentRay(angle: Float, direction: Point)
}

/// An SVG path, made of zero or more subpaths.
pub type Path {
  Path(subpaths: List(Subpath))
}

/// A positioned sequence of path segments, optionally closed.
///
/// The first segment, when present, starts at the subpath start point. The last
/// segment of a closed subpath, when present, also ends at the subpath start
/// point. Empty subpaths may be open or closed.
///
/// The constructor is opaque so that these invariants are maintained. Use
/// `subpath`, `subpath_empty`, `subpath_append_segment`, or their `_with`
/// variants to build values.
pub opaque type Subpath {
  Subpath(start: Point, segments: List(Segment), closed: Bool)
}

/// A local address on a subpath segment.
///
/// `segment_index` addresses a segment in the subpath, and `t` is that
/// segment's local parameter. Subpath APIs require `t` to be inside
/// `0.0..1.0`; unlike segment APIs, subpath parameters do not extrapolate.
pub type SubpathParameter {
  SubpathParameter(segment_index: Int, t: Float)
}

/// A local address on a path.
///
/// `subpath_index` addresses a subpath in the path, and `at` addresses a
/// segment parameter inside that subpath.
pub type PathParameter {
  PathParameter(subpath_index: Int, at: SubpathParameter)
}

type CanonicalSubpathParameter {
  CanonicalSubpathParameter(segment_index: Int, t: Float)
}

/// How construction and editing helpers reconcile segment endpoints.
pub type EndpointPolicy {
  /// Endpoints must already match exactly.
  Strict

  /// Move nearby endpoints together within the default wiggle tolerance.
  ///
  /// Horizontal and vertical lines stay horizontal and vertical. If adjacent
  /// horizontal/horizontal or vertical/vertical lines are misaligned, a bridge
  /// is inserted regardless of endpoint distance.
  Wiggle

  /// Move nearby endpoints together within the supplied tolerance.
  ///
  /// Horizontal and vertical lines stay horizontal and vertical. If adjacent
  /// horizontal/horizontal or vertical/vertical lines are misaligned, a bridge
  /// is inserted regardless of endpoint distance.
  WiggleWith(Float)

  /// Keep endpoints unchanged and insert a straight line if needed.
  Bridge

  /// Try `Wiggle`; if that fails, use `Bridge`.
  WiggleThenBridge

  /// Try wiggle with the supplied tolerance; if that fails, use `Bridge`.
  WiggleThenBridgeWith(Float)

  /// Reconcile adjacent segments with a caller-provided function.
  ///
  /// For ordinary adjacent pairs, the returned segments replace the pair. For
  /// a closing join from the last segment back to the first segment, they
  /// replace only the last segment. An empty list deletes the replaced
  /// segment or pair. If the returned list is nonempty, its first segment must
  /// start where the previous segment started.
  /// The callback's third argument is `True` only for a closing join from the
  /// last segment back to the first segment.
  Custom(fn(Segment, Segment, Bool) -> List(Segment))
}

type CustomPolicy =
  fn(Segment, Segment, Bool) -> List(Segment)

/// Create a wiggle endpoint policy with a custom distance tolerance.
pub fn wiggle_with(tolerance: Float) -> EndpointPolicy {
  WiggleWith(tolerance)
}

/// Create a wiggle-then-bridge endpoint policy with a custom distance
/// tolerance.
pub fn wiggle_then_bridge_with(tolerance: Float) -> EndpointPolicy {
  WiggleThenBridgeWith(tolerance)
}

/// A single SVG path segment.
pub type Segment {
  /// A straight line segment.
  Line(start: Point, end: Point)

  /// A quadratic Bezier curve segment.
  QuadraticBezier(start: Point, control: Point, end: Point)

  /// A cubic Bezier curve segment.
  CubicBezier(start: Point, control1: Point, control2: Point, end: Point)

  /// An elliptical arc segment. `x_axis_rotation` is in degrees.
  Arc(
    start: Point,
    radius: Point,
    x_axis_rotation: Float,
    large_arc: Bool,
    sweep: Bool,
    end: Point,
  )
}

/// Errors returned by path construction and editing helpers.
pub type Error {
  /// The subpath is already closed and cannot accept more segments.
  AlreadyClosed

  /// A segment starts somewhere other than the previous segment's end point.
  ///
  /// `previous_index` is the segment whose end point was expected. `next_index`
  /// is the segment whose start point did not match. `distance` is the distance
  /// between `expected` and `got`.
  Discontinuous(
    previous_index: Int,
    next_index: Int,
    expected: Point,
    got: Point,
    distance: Float,
  )

  /// The operation requires a non-empty subpath.
  EmptySubpath

  /// The operation requires a closed subpath.
  NotClosed

  /// The operation requires a path with at least one subpath.
  EmptyPath

  /// The operation requires a path with at least one non-empty subpath.
  EmptySubpaths

  /// The arc cannot be converted to center-parameter form.
  DegenerateArc

  /// Nonlinear point mapping cannot preserve an SVG arc segment.
  CannotMapArcNonlinearly

  /// A point-pair similarity needs distinct source points.
  DegeneratePointPairSimilarity

  /// A splice was requested with invalid bounds.
  ///
  /// This is returned when `start` is negative, `delete` is negative, or
  /// `start` is greater than the subpath length.
  InvalidSplice(start: Int, delete: Int, length: Int)

  /// A subpath parameter was outside the valid segment index or `0.0..1.0` range.
  InvalidSubpathParameter(segment_index: Int, t: Float, length: Int)

  /// A path parameter was outside the valid subpath index range.
  InvalidPathParameter(subpath_index: Int, length: Int)

  /// A direction relative tolerance must be finite and non-negative.
  InvalidDirectionRelativeTolerance(Float)

  /// Geometry has no usable direction for the requested operation.
  IndeterminateDirection

  /// A custom endpoint wiggle tolerance must be finite and non-negative.
  InvalidWiggleTolerance(Float)

  /// A subpath interval would not produce a positive-length piece.
  InvalidSubpathInterval(from: SubpathParameter, to: SubpathParameter)

  /// The number of crossing scan samples must be greater than zero.
  InvalidCrossingSamples(samples: Int)

  /// The crossing tolerance must be finite and greater than zero.
  InvalidCrossingTolerance(tolerance: Float)

  /// The crossing bisection iteration limit must be greater than zero.
  InvalidCrossingMaxIterations(max_iterations: Int)

  /// A bracketed crossing could not be refined within the iteration limit.
  CrossingMaxIterationsReached(estimate: Float, value: Float)

  /// The number of minimization scan samples must be greater than zero.
  InvalidMinimizeSamples(samples: Int)

  /// The minimization tolerance must be finite and greater than zero.
  InvalidMinimizeTolerance(tolerance: Float)

  /// The minimization iteration limit must be greater than zero.
  InvalidMinimizeMaxIterations(max_iterations: Int)

  /// A minimization window could not be refined within the iteration limit.
  MinimizeMaxIterationsReached(estimate: Float, value: Float)

  /// The length approximation tolerance must be finite and greater than zero.
  InvalidLengthTolerance(tolerance: Float)

  /// The length approximation recursion limit must be greater than zero.
  InvalidLengthMaxDepth(max_depth: Int)

  /// A length approximation could not be refined within the recursion limit.
  LengthMaxDepthReached(estimate: Float, error: Float)

  /// The zero-length tolerance must be finite and zero or greater.
  InvalidZeroLengthTolerance(tolerance: Float)

  /// A requested arc-length distance was outside `0.0..length`.
  InvalidLengthDistance(distance: Float, length: Float)

  /// The maximum segment length must be finite and greater than zero.
  InvalidSubdivisionMaxLength(max_length: Float)

  /// Parametric fitting tolerance must be finite and greater than zero.
  InvalidParametricTolerance(tolerance: Float)

  /// Parametric fitting needs at least two interior samples per piece.
  InvalidParametricSamplesPerPiece(samples: Int)

  /// Parametric fitting initial piece count must be greater than zero.
  InvalidParametricInitialPieceCount(piece_count: Int)

  /// Parametric fitting recursion depth must be zero or greater.
  InvalidParametricMaxDepth(max_depth: Int)

  /// Parametric fitting needs distinct, finite start and end parameters.
  InvalidParametricInterval(start: Float, end: Float)

  /// The caller-provided parametric function produced a non-finite point.
  NonFiniteParametricPoint(parameter: Float, point: Point)

  /// The caller-provided tangent function produced a non-finite tangent.
  NonFiniteParametricTangent(parameter: Float, tangent: Point)

  /// A parametric interval could not be fitted within the recursion limit.
  ParametricMaxDepthReached(error: Float)

  /// A parametric interval could not determine a stable cubic fit.
  ParametricFitFailed

  /// A cubic fit tangent was too small to normalize.
  DegenerateCubicFitTangent

  /// A cubic fit did not have enough sample information to determine controls.
  UnderdeterminedCubicFit

  /// The line approximation tolerance must be finite and greater than zero.
  InvalidLinearizeTolerance(tolerance: Float)

  /// The line approximation recursion limit must be greater than zero.
  InvalidLinearizeMaxDepth(max_depth: Int)

  /// A segment could not be approximated within the recursion limit.
  LinearizeMaxDepthReached(error: Float)

  /// The number of distance scan samples must be greater than zero.
  InvalidDistanceSamples(samples: Int)

  /// The distance tolerance must be finite and greater than zero.
  InvalidDistanceTolerance(tolerance: Float)

  /// The distance bisection iteration limit must be greater than zero.
  InvalidDistanceMaxIterations(max_iterations: Int)

  /// A bracketed distance candidate could not be refined within the iteration limit.
  DistanceMaxIterationsReached(estimate: Float, value: Float)

  /// Polynomial distance-root isolation produced an inconsistent bracket.
  DistanceRootIsolationFailed

  /// The containment tolerance must be finite and greater than zero.
  InvalidContainmentTolerance(tolerance: Float)

  /// The number of containment samples must be greater than zero.
  InvalidContainmentSamples(samples: Int)

  /// The containment iteration limit must be greater than zero.
  InvalidContainmentMaxIterations(max_iterations: Int)

  /// A containment fallback ray angle must be finite.
  InvalidContainmentRayAngle(angle: Float)

  /// Every attempted containment ray gave inconsistent opposite-direction answers.
  InconsistentContainment

  /// No regular interior sample could determine a segment's winding sides.
  IndeterminateWindingSideLevels

  /// Symmetric regular samples disagreed about a segment's winding sides.
  InconsistentWindingSideLevels

  /// The intersection tolerance must be finite and greater than zero.
  InvalidIntersectionTolerance(tolerance: Float)

  /// The overlap tolerance must be finite and zero or greater.
  InvalidOverlapTolerance(tolerance: Float)

  /// Endpoint-projection overlap detection requires at least one sample.
  InvalidOverlapSamples(samples: Int)

  /// The intersection subdivision depth must be greater than zero.
  InvalidIntersectionMaxDepth(max_depth: Int)

  /// The intersection parameter snap exponent must be between 1 and 15.
  InvalidIntersectionParameterSnapExponent(exponent: Int)

  /// The self-intersection arc-length separation must be finite and positive.
  InvalidSelfIntersectionMinimumArcLengthSeparation(Float)

  /// The self-intersection distance tolerance must be finite and positive.
  InvalidSelfIntersectionDistanceTolerance(Float)

  /// The two segments overlap in more than a single point.
  OverlappingSegments

  /// Point-intersection logic reported an overlap that the shared overlap
  /// classifier did not confirm.
  InternalOverlapClassificationInconsistency

  /// Point-intersection logic returned parameters that do not evaluate back to
  /// the reported point within the requested tolerance.
  InternalUncertifiedSegmentIntersection(
    left_distance: Float,
    right_distance: Float,
    tolerance: Float,
  )

  /// Opposite-direction subpath overlap correspondence checks disagreed.
  InternalOverlapParameterCorrespondenceInconsistency

  /// Coincident segment portions do not have a single affine correspondence
  /// between their parameter intervals.
  ///
  /// Normalize or linearize degenerate, multiply traced, or non-monotone
  /// segments before retrying the overlap operation.
  NonAffineOverlapCorrespondence

  /// The path contains more than one non-empty subpath.
  MultipleNonemptySubpaths

  /// Two points were too far apart for a wiggle operation to merge them.
  NotCloseEnough(expected: Point, got: Point, tolerance: Float)

  /// The requested split point is outside the segment's `0.0..1.0` parameter range.
  SplitOutsideSegment
}

/// Return the default options for segment crossing detection.
pub fn default_crossing_options() -> CrossingOptions {
  CrossingOptions(
    samples: default_crossing_samples,
    signed_line_distance_tolerance: default_crossing_tolerance,
    max_iterations: default_crossing_max_iterations,
  )
}

/// Return the default options for segment minimization.
pub fn default_minimize_options() -> MinimizeOptions {
  MinimizeOptions(
    samples: default_minimize_samples,
    parameter_tolerance: default_minimize_tolerance,
    max_iterations: default_minimize_max_iterations,
  )
}

/// Return the default options for segment and subpath length approximation.
pub fn default_length_options() -> LengthOptions {
  LengthOptions(
    tolerance: default_length_tolerance,
    max_depth: default_length_max_depth,
  )
}

/// Return the default options for parametric subpath fitting.
pub fn default_parametric_options() -> ParametricOptions {
  ParametricOptions(
    tolerance: default_parametric_tolerance,
    samples_per_piece: default_parametric_samples_per_piece,
    initial_piece_count: default_parametric_initial_piece_count,
    max_depth: default_parametric_max_depth,
    tangent: None,
  )
}

/// Return the default options for straight-line approximation.
pub fn default_linearize_options() -> LinearizeOptions {
  LinearizeOptions(
    tolerance: default_linearize_tolerance,
    max_depth: default_linearize_max_depth,
  )
}

/// Return the default options for point-to-segment distance measurement.
pub fn default_distance_options() -> DistanceOptions {
  DistanceOptions(
    samples: default_distance_samples,
    tolerance: default_distance_tolerance,
    max_iterations: default_distance_max_iterations,
  )
}

/// Return the default options for point containment.
pub fn default_containment_options() -> ContainmentOptions {
  ContainmentOptions(
    tolerance: default_containment_tolerance,
    samples: default_containment_samples,
    max_iterations: default_containment_max_iterations,
    fallback_ray_angles: [
      0.0,
      15.0,
      30.0,
      45.0,
      60.0,
      75.0,
      90.0,
      105.0,
      120.0,
      135.0,
      150.0,
      165.0,
    ],
  )
}

/// Return the default options for subpath and path self-intersection detection.
pub fn default_self_intersection_options() -> SelfIntersectionOptions {
  SelfIntersectionOptions(
    minimum_arc_length_separation: default_self_intersection_tolerance,
    distance_tolerance: default_self_intersection_tolerance,
  )
}

/// Create an empty path.
pub fn path_empty() -> Path {
  Path([])
}

/// Return the subpaths in a path.
pub fn path_subpaths(path: Path) -> List(Subpath) {
  path.subpaths
}

/// View a segment as a one-segment open subpath.
///
/// This conversion is total because a single segment is necessarily a
/// continuous segment sequence.
pub fn segment_as_subpath(segment: Segment) -> Subpath {
  subpath_assert([segment])
}

/// View a segment as a path containing one one-segment open subpath.
pub fn segment_as_path(segment: Segment) -> Path {
  segment |> segment_as_subpath |> subpath_as_path
}

/// View a subpath as a path containing that single subpath.
pub fn subpath_as_path(subpath: Subpath) -> Path {
  Path([subpath])
}

/// Append a subpath to the end of a path.
pub fn path_append_subpath(path: Path, subpath: Subpath) -> Path {
  Path(subpaths: list.append(path.subpaths, [subpath]))
}

/// Combine paths by concatenating their subpaths.
pub fn path_combine(paths: List(Path)) -> Path {
  paths
  |> list.flat_map(path_subpaths)
  |> Path
}

/// Map over the subpaths in a path.
pub fn path_map_subpaths(path: Path, with f: fn(Subpath) -> Subpath) -> Path {
  path.subpaths
  |> list.map(f)
  |> Path
}

/// Rebuild every subpath in a path using an endpoint policy.
///
/// This re-runs endpoint reconciliation on each subpath's current segment list
/// and preserves each subpath's open/closed state. Empty subpaths are
/// preserved unchanged.
pub fn path_rebuild_with(
  path: Path,
  policy endpoint_policy: EndpointPolicy,
) -> Result(Path, Error) {
  use subpaths <- result.try(
    path_rebuild_subpaths_with(path.subpaths, endpoint_policy, rebuilt: []),
  )
  Ok(Path(subpaths:))
}

/// Keep only the subpaths that satisfy a predicate.
pub fn path_filter_subpaths(
  path: Path,
  keeping predicate: fn(Subpath) -> Bool,
) -> Path {
  path.subpaths
  |> list.filter(keeping: predicate)
  |> Path
}

/// Convert a path with zero or one non-empty subpaths into a subpath.
///
/// Empty subpaths are ignored. If more than one non-empty subpath is present,
/// this returns `MultipleNonemptySubpaths`. If a path has only empty subpaths,
/// the first empty subpath is returned.
pub fn path_as_subpath(path: Path) -> Result(Subpath, Error) {
  case path.subpaths {
    [] -> Error(EmptySubpaths)
    subpaths -> {
      case nonempty_subpaths(subpaths) {
        [] -> Ok(first_subpath(subpaths))
        [subpath] -> Ok(subpath)
        [_, _, ..] -> Error(MultipleNonemptySubpaths)
      }
    }
  }
}

/// Create an empty open subpath at a start point.
///
/// This represents a move-only subpath such as `M 0 0`.
pub fn subpath_empty(at start: Point) -> Subpath {
  Subpath(start:, segments: [], closed: False)
}

/// Create an open subpath from a non-empty continuous list of segments.
///
/// Returns `EmptySubpath` if the segment list is empty. Use `subpath_empty`
/// when you need to represent a move-only subpath.
///
/// Returns `Discontinuous` if any segment starts somewhere other than the
/// previous segment's end point. The error includes the two segment indices
/// that failed to meet.
pub fn subpath(segments: List(Segment)) -> Result(Subpath, Error) {
  subpath_with(segments, policy: Strict)
}

/// Create an open subpath using the given endpoint reconciliation policy.
///
/// Empty segment lists still return `EmptySubpath`.
pub fn subpath_with(
  segments: List(Segment),
  policy endpoint_policy: EndpointPolicy,
) -> Result(Subpath, Error) {
  open_subpath_with_segments(segments, endpoint_policy)
}

/// Rebuild a subpath using an endpoint policy.
///
/// This re-runs endpoint reconciliation on the subpath's current segment list
/// and preserves the subpath's open/closed state. Empty subpaths are preserved
/// unchanged.
pub fn subpath_rebuild_with(
  subpath: Subpath,
  policy endpoint_policy: EndpointPolicy,
) -> Result(Subpath, Error) {
  case subpath.segments {
    [] -> Ok(subpath)
    segments -> {
      use rebuilt <- result.try(open_subpath_with_segments(
        segments,
        endpoint_policy,
      ))
      case subpath.closed {
        False -> Ok(rebuilt)
        True ->
          subpath_set_closed_with(
            rebuilt,
            closed: True,
            policy: endpoint_policy,
          )
      }
    }
  }
}

/// Create an open subpath connecting the given points with line segments.
///
/// The input must contain at least two points.
pub fn subpath_polyline(points: List(Point)) -> Result(Subpath, Error) {
  case point_lines(points) {
    [] -> Error(EmptySubpath)
    segments -> subpath(segments)
  }
}

/// Create an open polyline subpath, panicking if the point list is invalid.
pub fn subpath_assert_polyline(points: List(Point)) -> Subpath {
  case subpath_polyline(points) {
    Ok(subpath) -> subpath
    Error(_) ->
      panic as "svg_path.subpath_assert_polyline received invalid points"
  }
}

/// Create a closed subpath connecting the given points with line segments.
///
/// The input must contain at least two points. If the last point equals the
/// first point, no extra zero-length closing line is added.
///
/// This is equivalent to constructing a `subpath_polyline` from the same points
/// and closing it with `subpath_set_closed_with(..., policy: Bridge)`.
pub fn subpath_polygon(points: List(Point)) -> Result(Subpath, Error) {
  case points {
    [] | [_] -> Error(EmptySubpath)
    [first, ..] -> {
      let segments = point_lines(close_polygon_points(points, first))

      case subpath(segments) {
        Error(error) -> Error(error)
        Ok(subpath) -> subpath_set_closed(subpath, closed: True)
      }
    }
  }
}

/// Create a closed polygon subpath, panicking if the point list is invalid.
pub fn subpath_assert_polygon(points: List(Point)) -> Subpath {
  case subpath_polygon(points) {
    Ok(subpath) -> subpath
    Error(_) ->
      panic as "svg_path.subpath_assert_polygon received invalid points"
  }
}

/// Approximate a parametric curve with a sequence of cubic Bezier segments.
///
/// The parameter interval is split uniformly into
/// `default_parametric_options().initial_piece_count` pieces. Each piece is
/// fitted with a cubic, then recursively bisected in parameter space until the
/// maximum sampled fitting error is within tolerance.
pub fn subpath_parametric(
  from start: Float,
  to end: Float,
  point point_function: fn(Float) -> Point,
) -> Result(Subpath, Error) {
  subpath_parametric_with(
    from: start,
    to: end,
    point: point_function,
    options: default_parametric_options(),
  )
}

/// Approximate a parametric curve with a sequence of cubic Bezier segments
/// using explicit options.
///
/// If `options.tangent` is `Some(tangent_function)`, each cubic is constrained
/// to match the endpoint tangent directions returned by that function. If it is
/// `None`, control points are fitted from samples while the endpoints are fixed.
pub fn subpath_parametric_with(
  from start: Float,
  to end: Float,
  point point_function: fn(Float) -> Point,
  options options: ParametricOptions,
) -> Result(Subpath, Error) {
  use _ <- result.try(validate_parametric_options(options))
  use _ <- result.try(validate_parametric_interval(start, end))
  use segments <- result.try(
    parametric_initial_segments(
      start,
      end,
      point_function,
      options,
      index: 0,
      segments: [],
    ),
  )
  subpath(segments)
}

/// Create an open subpath from a non-empty continuous list of segments,
/// panicking if the segments are invalid.
///
/// This is useful for hand-authored paths where invalid continuity would be a
/// programmer error. Use `subpath` when you want to handle construction errors.
pub fn subpath_assert(segments: List(Segment)) -> Subpath {
  subpath_assert_with(segments, policy: Strict)
}

/// Create an open subpath with an endpoint policy, panicking if construction fails.
pub fn subpath_assert_with(
  segments: List(Segment),
  policy endpoint_policy: EndpointPolicy,
) -> Subpath {
  case subpath_with(segments, policy: endpoint_policy) {
    Ok(subpath) -> subpath
    Error(_) -> panic as "svg_path.subpath_assert received invalid segments"
  }
}

/// Return the segments in a subpath.
pub fn subpath_segments(subpath: Subpath) -> List(Segment) {
  subpath.segments
}

/// Remove zero-length line segments from a subpath.
///
/// If cleanup would remove every segment, one zero-length line is preserved so
/// a zero-length drawing subpath does not become a move-only subpath.
pub fn subpath_normalize_zero_length_lines(subpath: Subpath) -> Subpath {
  let cleaned =
    subpath.segments
    |> list.filter(keeping: fn(segment) { !is_zero_length_line(segment) })

  case cleaned {
    [] -> {
      case subpath.segments {
        [] -> subpath
        [first, ..] ->
          Subpath(
            start: segment_start(first),
            segments: [first],
            closed: subpath.closed,
          )
      }
    }
    [first, ..] ->
      Subpath(
        start: segment_start(first),
        segments: cleaned,
        closed: subpath.closed,
      )
  }
}

/// Replace a range of segments in a subpath.
///
/// `start` is a zero-based segment index and `delete` is the number of
/// segments to remove. If `start + delete` extends past the end of the subpath,
/// everything from `start` onward is deleted. Negative `start`, negative
/// `delete`, and `start` greater than the subpath length return
/// `InvalidSplice`.
///
/// The edited subpath must remain continuous. Closed subpaths preserve their
/// closed state. If the splice result is nonempty, the subpath start is updated
/// to the first resulting segment's start point. If the splice result is empty,
/// the previous start point is preserved.
pub fn subpath_splice(
  subpath: Subpath,
  start start: Int,
  delete delete: Int,
  insert insert: List(Segment),
) -> Result(Subpath, Error) {
  subpath_splice_with(subpath, start:, delete:, insert:, policy: Strict)
}

/// Replace a range of segments in a subpath using the given endpoint policy.
pub fn subpath_splice_with(
  subpath: Subpath,
  start start: Int,
  delete delete: Int,
  insert insert: List(Segment),
  policy endpoint_policy: EndpointPolicy,
) -> Result(Subpath, Error) {
  let length = list.length(subpath.segments)

  case start < 0 || delete < 0 || start > length {
    True -> Error(InvalidSplice(start:, delete:, length:))
    False -> {
      let segments = splice_segments(subpath.segments, start, delete, insert)

      validate_spliced_subpath(
        segments,
        start: subpath.start,
        closed: subpath.closed,
        policy: endpoint_policy,
      )
    }
  }
}

/// Replace a range of segments, panicking if the splice is invalid.
pub fn subpath_assert_splice(
  subpath: Subpath,
  start start: Int,
  delete delete: Int,
  insert insert: List(Segment),
) -> Subpath {
  subpath_assert_splice_with(subpath, start:, delete:, insert:, policy: Strict)
}

/// Replace a range of segments with an endpoint policy, panicking if invalid.
pub fn subpath_assert_splice_with(
  subpath: Subpath,
  start start: Int,
  delete delete: Int,
  insert insert: List(Segment),
  policy endpoint_policy: EndpointPolicy,
) -> Subpath {
  case
    subpath_splice_with(
      subpath,
      start:,
      delete:,
      insert:,
      policy: endpoint_policy,
    )
  {
    Ok(subpath) -> subpath
    Error(_) -> panic as "svg_path.assert_splice received an invalid splice"
  }
}

/// Convert every arc in a subpath to cubic Bezier curves.
///
/// Lines, quadratic Beziers, and cubic Beziers are preserved. Elliptical arcs
/// are approximated with one or more cubic Beziers, split into chunks of at
/// most a quarter turn. Degenerate arcs fall back to a straight-line cubic
/// Bezier between their endpoints.
pub fn subpath_arcs_to_cubic_beziers(subpath: Subpath) -> Subpath {
  Subpath(
    start: subpath.start,
    segments: segments_arcs_to_cubic_beziers(subpath.segments, []),
    closed: subpath.closed,
  )
}

/// Convert every arc in a path to cubic Bezier curves.
///
/// This applies `subpath_arcs_to_cubic_beziers` to each subpath.
pub fn path_arcs_to_cubic_beziers(path: Path) -> Path {
  Path(subpaths: list.map(path.subpaths, subpath_arcs_to_cubic_beziers))
}

/// Reverse the traversal direction of every segment in a subpath.
///
/// The subpath's closed state is preserved.
pub fn subpath_reverse(subpath: Subpath) -> Subpath {
  let segments = subpath.segments |> list.reverse |> list.map(segment_reverse)
  subpath_from_valid_segments(
    segments,
    fallback_start: subpath.start,
    closed: subpath.closed,
  )
}

/// Reverse the traversal direction of a path.
///
/// This reverses each subpath and reverses the path's subpath order.
pub fn path_reverse(path: Path) -> Path {
  Path(subpaths: path.subpaths |> list.reverse |> list.map(subpath_reverse))
}

/// Map the defining points of every segment in a subpath.
///
/// The subpath's closed state is preserved. For nonlinear functions, this maps
/// endpoints and control points, not the exact image of every point on each
/// rendered curve. If any segment is an arc, this returns
/// `CannotMapArcNonlinearly`.
pub fn subpath_map_points(
  subpath: Subpath,
  with f: fn(Point) -> Point,
) -> Result(Subpath, Error) {
  case map_segments_points(subpath.segments, f, []) {
    Error(error) -> Error(error)
    Ok(segments) ->
      Ok(Subpath(start: f(subpath.start), segments:, closed: subpath.closed))
  }
}

/// Map the defining points of every segment in a subpath with a fallible
/// function.
///
/// This has the same geometry semantics as `subpath_map_points`, but the
/// mapping function may reject individual points.
pub fn subpath_try_map_points(
  subpath: Subpath,
  with f: fn(Point) -> Result(Point, error),
) -> Result(Subpath, PointMapError(error)) {
  use start <- result.try(
    f(subpath.start) |> result.map_error(PointMapFunctionError),
  )
  case try_map_segments_points(subpath.segments, f, []) {
    Error(error) -> Error(error)
    Ok(segments) -> Ok(Subpath(start:, segments:, closed: subpath.closed))
  }
}

/// Map the defining points of every segment in a path.
///
/// Each subpath's closed state is preserved. For nonlinear functions, this maps
/// endpoints and control points, not the exact image of every point on each
/// rendered curve. If any segment is an arc, this returns
/// `CannotMapArcNonlinearly`.
pub fn path_map_points(
  path: Path,
  with f: fn(Point) -> Point,
) -> Result(Path, Error) {
  case map_subpaths_points(path.subpaths, f, []) {
    Error(error) -> Error(error)
    Ok(subpaths) -> Ok(Path(subpaths:))
  }
}

/// Map the defining points of every segment in a path with a fallible function.
///
/// This has the same geometry semantics as `path_map_points`, but the mapping
/// function may reject individual points.
pub fn path_try_map_points(
  path: Path,
  with f: fn(Point) -> Result(Point, error),
) -> Result(Path, PointMapError(error)) {
  case try_map_subpaths_points(path.subpaths, f, []) {
    Error(error) -> Error(error)
    Ok(subpaths) -> Ok(Path(subpaths:))
  }
}

/// Map a point by the similarity taking `source_start` and `source_end` to
/// `target_start` and `target_end`.
///
/// If the input point is exactly `source_start` or `source_end`, the returned
/// point is exactly the corresponding target point.
pub fn point_by_point_pair_similarity(
  point: Point,
  source_start source_start: Point,
  source_end source_end: Point,
  target_start target_start: Point,
  target_end target_end: Point,
) -> Result(Point, Error) {
  use similarity <- result.try(point_pair_similarity(
    source_start:,
    source_end:,
    target_start:,
    target_end:,
  ))
  Ok(point_by_point_pair_similarity_transform(
    point,
    similarity,
    source_start:,
    source_end:,
    target_start:,
    target_end:,
  ))
}

/// Map a segment by the similarity taking `source_start` and `source_end` to
/// `target_start` and `target_end`.
///
/// Segment defining points exactly equal to `source_start` or `source_end` are
/// mapped exactly to the corresponding target point.
pub fn segment_by_point_pair_similarity(
  segment: Segment,
  source_start source_start: Point,
  source_end source_end: Point,
  target_start target_start: Point,
  target_end target_end: Point,
) -> Result(Segment, Error) {
  use similarity <- result.try(point_pair_similarity(
    source_start:,
    source_end:,
    target_start:,
    target_end:,
  ))
  segment_by_point_pair_similarity_transform(
    segment,
    similarity,
    source_start:,
    source_end:,
    target_start:,
    target_end:,
  )
}

/// Map a subpath by the similarity taking `source_start` and `source_end` to
/// `target_start` and `target_end`.
pub fn subpath_by_point_pair_similarity(
  subpath: Subpath,
  source_start source_start: Point,
  source_end source_end: Point,
  target_start target_start: Point,
  target_end target_end: Point,
) -> Result(Subpath, Error) {
  use similarity <- result.try(point_pair_similarity(
    source_start:,
    source_end:,
    target_start:,
    target_end:,
  ))
  use segments <- result.try(
    map_segments_by_point_pair_similarity(
      subpath.segments,
      similarity,
      source_start:,
      source_end:,
      target_start:,
      target_end:,
      mapped: [],
    ),
  )
  Ok(Subpath(
    start: point_by_point_pair_similarity_transform(
      subpath.start,
      similarity,
      source_start:,
      source_end:,
      target_start:,
      target_end:,
    ),
    segments:,
    closed: subpath.closed,
  ))
}

/// Map a path by the similarity taking `source_start` and `source_end` to
/// `target_start` and `target_end`.
pub fn path_by_point_pair_similarity(
  path: Path,
  source_start source_start: Point,
  source_end source_end: Point,
  target_start target_start: Point,
  target_end target_end: Point,
) -> Result(Path, Error) {
  use similarity <- result.try(point_pair_similarity(
    source_start:,
    source_end:,
    target_start:,
    target_end:,
  ))
  use subpaths <- result.try(
    map_subpaths_by_point_pair_similarity(
      path.subpaths,
      similarity,
      source_start:,
      source_end:,
      target_start:,
      target_end:,
      mapped: [],
    ),
  )
  Ok(Path(subpaths:))
}

/// Remap a segment so its current endpoints become `new_start` and `new_end`.
///
/// The returned segment starts exactly at `new_start` and ends exactly at
/// `new_end`.
pub fn segment_remap_endpoints(
  segment: Segment,
  new_start new_start: Point,
  new_end new_end: Point,
) -> Result(Segment, Error) {
  use mapped <- result.try(segment_by_point_pair_similarity(
    segment,
    source_start: segment_start(segment),
    source_end: segment_end(segment),
    target_start: new_start,
    target_end: new_end,
  ))
  Ok(segment_with_start_and_end(mapped, new_start, new_end))
}

/// Remap a subpath so its current endpoints become `new_start` and `new_end`.
///
/// Empty subpaths keep their empty segment list and move to `new_start`.
pub fn subpath_remap_endpoints(
  subpath: Subpath,
  new_start new_start: Point,
  new_end new_end: Point,
) -> Result(Subpath, Error) {
  case subpath.segments {
    [] -> Ok(Subpath(start: new_start, segments: [], closed: subpath.closed))
    _ -> {
      use current_end <- result.try(subpath_end(subpath))
      use mapped <- result.try(subpath_by_point_pair_similarity(
        subpath,
        source_start: subpath.start,
        source_end: current_end,
        target_start: new_start,
        target_end: new_end,
      ))
      let segments = case mapped.segments {
        [] -> []
        [first, ..rest] ->
          force_subpath_endpoints(
            [segment_with_start(first, new_start), ..rest],
            new_end,
          )
      }
      Ok(Subpath(start: new_start, segments:, closed: mapped.closed))
    }
  }
}

fn point_pair_similarity(
  source_start source_start: Point,
  source_end source_end: Point,
  target_start target_start: Point,
  target_end target_end: Point,
) -> Result(affine.Affine, Error) {
  affine.point_pair_similarity(
    source_start: point_tuple(source_start),
    source_end: point_tuple(source_end),
    target_start: point_tuple(target_start),
    target_end: point_tuple(target_end),
  )
  |> result.map_error(fn(_) { DegeneratePointPairSimilarity })
}

fn point_by_point_pair_similarity_transform(
  point: Point,
  similarity: affine.Affine,
  source_start source_start: Point,
  source_end source_end: Point,
  target_start target_start: Point,
  target_end target_end: Point,
) -> Point {
  case point == source_start {
    True -> target_start
    False ->
      case point == source_end {
        True -> target_end
        False -> point_by_similarity(point, similarity)
      }
  }
}

fn point_by_similarity(point: Point, similarity: affine.Affine) -> Point {
  let #(x, y) = affine.point(similarity, x: point.x, y: point.y)
  Point(x, y)
}

fn segment_by_point_pair_similarity_transform(
  segment: Segment,
  similarity: affine.Affine,
  source_start source_start: Point,
  source_end source_end: Point,
  target_start target_start: Point,
  target_end target_end: Point,
) -> Result(Segment, Error) {
  let f = fn(point) {
    point_by_point_pair_similarity_transform(
      point,
      similarity,
      source_start:,
      source_end:,
      target_start:,
      target_end:,
    )
  }
  case segment {
    Line(start:, end:) -> Ok(Line(start: f(start), end: f(end)))
    QuadraticBezier(start:, control:, end:) ->
      Ok(QuadraticBezier(start: f(start), control: f(control), end: f(end)))
    CubicBezier(start:, control1:, control2:, end:) ->
      Ok(CubicBezier(
        start: f(start),
        control1: f(control1),
        control2: f(control2),
        end: f(end),
      ))
    Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:) -> {
      let scale = point_pair_similarity_scale(similarity)
      case scale == 0.0 {
        True -> Error(CannotMapArcNonlinearly)
        False ->
          Ok(Arc(
            start: f(start),
            radius: Point(
              float.absolute_value(radius.x *. scale),
              float.absolute_value(radius.y *. scale),
            ),
            x_axis_rotation: x_axis_rotation
              +. point_pair_similarity_rotation(similarity),
            large_arc:,
            sweep: case scale >=. 0.0 {
              True -> sweep
              False -> !sweep
            },
            end: f(end),
          ))
      }
    }
  }
}

fn map_segments_by_point_pair_similarity(
  segments: List(Segment),
  similarity: affine.Affine,
  source_start source_start: Point,
  source_end source_end: Point,
  target_start target_start: Point,
  target_end target_end: Point,
  mapped mapped: List(Segment),
) -> Result(List(Segment), Error) {
  case segments {
    [] -> Ok(list.reverse(mapped))
    [segment, ..rest] -> {
      use mapped_segment <- result.try(
        segment_by_point_pair_similarity_transform(
          segment,
          similarity,
          source_start:,
          source_end:,
          target_start:,
          target_end:,
        ),
      )
      map_segments_by_point_pair_similarity(
        rest,
        similarity,
        source_start:,
        source_end:,
        target_start:,
        target_end:,
        mapped: [mapped_segment, ..mapped],
      )
    }
  }
}

fn map_subpaths_by_point_pair_similarity(
  subpaths: List(Subpath),
  similarity: affine.Affine,
  source_start source_start: Point,
  source_end source_end: Point,
  target_start target_start: Point,
  target_end target_end: Point,
  mapped mapped: List(Subpath),
) -> Result(List(Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(mapped))
    [subpath, ..rest] -> {
      use segments <- result.try(
        map_segments_by_point_pair_similarity(
          subpath.segments,
          similarity,
          source_start:,
          source_end:,
          target_start:,
          target_end:,
          mapped: [],
        ),
      )
      let mapped_subpath =
        Subpath(
          start: point_by_point_pair_similarity_transform(
            subpath.start,
            similarity,
            source_start:,
            source_end:,
            target_start:,
            target_end:,
          ),
          segments:,
          closed: subpath.closed,
        )
      map_subpaths_by_point_pair_similarity(
        rest,
        similarity,
        source_start:,
        source_end:,
        target_start:,
        target_end:,
        mapped: [mapped_subpath, ..mapped],
      )
    }
  }
}

fn point_pair_similarity_scale(similarity: affine.Affine) -> Float {
  let #(a, b, _, _, _, _) = affine.to_tuple(similarity)
  float_square_root(a *. a +. b *. b)
}

fn point_pair_similarity_rotation(similarity: affine.Affine) -> Float {
  let #(a, b, _, _, _, _) = affine.to_tuple(similarity)
  trig.atan2_degrees(b, a)
}

fn point_tuple(point: Point) -> #(Float, Float) {
  #(point.x, point.y)
}

fn force_subpath_endpoints(
  segments: List(Segment),
  end: Point,
) -> List(Segment) {
  case segments {
    [] -> []
    [last] -> [segment_with_end(last, end)]
    [first, ..rest] -> [first, ..force_subpath_endpoints(rest, end)]
  }
}

/// Convert an arc segment to cubic Bezier curves, preserving other segments.
///
/// Non-arc segments are returned unchanged as a single-item list. An arc may
/// become several cubic Bezier segments.
pub fn segment_arcs_to_cubic_beziers(segment: Segment) -> List(Segment) {
  case segment {
    Line(..) | QuadraticBezier(..) | CubicBezier(..) -> [segment]
    Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:) -> {
      case
        ellipse.arc_to_cubics(
          start: to_ellipse_point(start),
          radius: to_ellipse_point(radius),
          x_axis_rotation:,
          large_arc:,
          sweep:,
          end: to_ellipse_point(end),
        )
      {
        Ok(cubics) -> cubic_segments_from_ellipse(cubics, start, end)
        Error(_) -> [line_to_cubic(start, end)]
      }
    }
  }
}

/// Convert every segment in a subpath to cubic Bezier curves.
///
/// Lines and quadratic Beziers are converted exactly. Cubic Beziers are
/// preserved. Elliptical arcs are approximated with one or more cubic Beziers,
/// split into chunks of at most a quarter turn.
pub fn subpath_to_cubic_beziers(subpath: Subpath) -> Subpath {
  Subpath(
    start: subpath.start,
    segments: segments_to_cubic_beziers(subpath.segments, []),
    closed: subpath.closed,
  )
}

/// Convert every segment in a path to cubic Bezier curves.
///
/// This applies `subpath_to_cubic_beziers` to each subpath.
pub fn path_to_cubic_beziers(path: Path) -> Path {
  Path(subpaths: list.map(path.subpaths, subpath_to_cubic_beziers))
}

/// Convert a segment to one or more cubic Bezier curves.
///
/// Lines and quadratic Beziers are converted exactly. Cubic Beziers are
/// returned unchanged. Arcs may become several cubic Bezier segments.
pub fn segment_to_cubic_beziers(segment: Segment) -> List(Segment) {
  case segment {
    Line(start:, end:) -> [line_to_cubic(start, end)]
    QuadraticBezier(start:, control:, end:) -> [
      quadratic_to_cubic(start, control, end),
    ]
    CubicBezier(..) -> [segment]
    Arc(..) -> segment_arcs_to_cubic_beziers(segment)
  }
}

/// Fit a cubic Bezier segment with fixed endpoints and endpoint tangents.
///
/// This is a root-module convenience wrapper around
/// `bezier.fit_cubic_with_endpoint_tangents`. It accepts `svg_path.Point`
/// values, returns an `svg_path.CubicBezier` segment, and maps fit failures
/// into `svg_path.Error`.
pub fn fit_cubic_with_endpoint_tangents(
  start start: Point,
  end end: Point,
  start_tangent start_tangent: Point,
  end_tangent end_tangent: Point,
  samples samples: List(#(Float, Point)),
) -> Result(#(Segment, CubicFitReport), Error) {
  let samples =
    samples
    |> list.map(fn(sample) {
      let #(t, point) = sample
      #(t, to_bezier_point(point))
    })

  case
    bezier.fit_cubic_with_endpoint_tangents(
      start: to_bezier_point(start),
      end: to_bezier_point(end),
      start_tangent: to_bezier_point(start_tangent),
      end_tangent: to_bezier_point(end_tangent),
      samples:,
    )
  {
    Error(error) -> Error(from_bezier_error(error))
    Ok(#(curve, report)) -> {
      Ok(#(segment_from_bezier_data(curve), from_bezier_fit_report(report)))
    }
  }
}

/// Fit a cubic Bezier segment with fixed endpoints and no tangent constraints.
///
/// This is a root-module convenience wrapper around
/// `bezier.fit_cubic_with_endpoints`. It accepts `svg_path.Point` values,
/// returns an `svg_path.CubicBezier` segment, and maps fit failures into
/// `svg_path.Error`.
pub fn fit_cubic_with_endpoints(
  start start: Point,
  end end: Point,
  samples samples: List(#(Float, Point)),
) -> Result(#(Segment, CubicFitReport), Error) {
  let samples =
    samples
    |> list.map(fn(sample) {
      let #(t, point) = sample
      #(t, to_bezier_point(point))
    })

  case
    bezier.fit_cubic_with_endpoints(
      start: to_bezier_point(start),
      end: to_bezier_point(end),
      samples:,
    )
  {
    Error(error) -> Error(from_bezier_error(error))
    Ok(#(curve, report)) -> {
      Ok(#(segment_from_bezier_data(curve), from_bezier_fit_report(report)))
    }
  }
}

/// Approximate a segment with one or more straight lines.
///
/// Lines are returned unchanged. Beziers and arcs are subdivided until each
/// resulting chord is within the default geometric tolerance. Degenerate arcs
/// fall back to a straight line between their endpoints.
pub fn segment_to_lines(segment: Segment) -> Result(List(Segment), Error) {
  segment_to_lines_with(segment, options: default_linearize_options())
}

/// Approximate a segment with straight lines using explicit options.
pub fn segment_to_lines_with(
  segment: Segment,
  options options: LinearizeOptions,
) -> Result(List(Segment), Error) {
  use _ <- result.try(validate_linearize_options(options))
  segment_to_lines_valid_options(segment, options)
}

/// Detect a curve that is contained in an absolute-width strip and replace it
/// with ordered line segments when possible.
///
/// `tolerance` is the maximum distance from the replacement line or lines to
/// the curve, in path coordinate units. `Ok(None)` means that the segment is
/// not line-degenerate. `Ok(Some(lines))` preserves collinear backtracking;
/// `Some([])` represents a curve with no movement. Lines themselves return
/// `Ok(None)`. The tolerance must be finite and greater than zero.
pub fn segment_degenerate_lines(
  segment: Segment,
  tolerance tolerance: Float,
) -> Result(Option(List(Segment)), Error) {
  case tolerance <=. 0.0 || !number.is_finite(tolerance) {
    True -> Error(InvalidLinearizeTolerance(tolerance))
    False -> segment_degenerate_lines_valid(segment, tolerance)
  }
}

/// Detect whether an entire subpath fits inside one absolute-width line strip.
///
/// `Ok(Some(lines))` returns an ordered line replacement, preserving the
/// subpath's flattened traversal and backtracking. `Ok(None)` means that the
/// subpath is not line-degenerate. Empty subpaths return `Ok(Some([]))`.
pub fn subpath_degenerate_lines(
  subpath: Subpath,
  tolerance tolerance: Float,
) -> Result(Option(List(Segment)), Error) {
  case tolerance <=. 0.0 || !number.is_finite(tolerance) {
    True -> Error(InvalidLinearizeTolerance(tolerance))
    False -> {
      use replacements <- result.try(
        subpath_degenerate_line_replacements(subpath.segments, tolerance, []),
      )
      case replacements {
        None -> Ok(None)
        Some(lines) -> degenerate_line_list(lines, tolerance)
      }
    }
  }
}

fn subpath_degenerate_line_replacements(
  segments: List(Segment),
  tolerance: Float,
  lines lines: List(Segment),
) -> Result(Option(List(Segment)), Error) {
  case segments {
    [] -> Ok(Some(list.reverse(lines)))
    [first, ..rest] -> {
      use replacement <- result.try(segment_degenerate_lines(first, tolerance:))
      case first, replacement {
        Line(..), None ->
          subpath_degenerate_line_replacements(rest, tolerance, lines: [
            first,
            ..lines
          ])
        _, None -> Ok(None)
        _, Some(replacement) ->
          subpath_degenerate_line_replacements(
            rest,
            tolerance,
            lines: list.append(list.reverse(replacement), lines),
          )
      }
    }
  }
}

fn segment_degenerate_lines_valid(
  segment: Segment,
  tolerance: Float,
) -> Result(Option(List(Segment)), Error) {
  case segment {
    Line(..) -> Ok(None)
    QuadraticBezier(start:, control:, end:) ->
      bezier_degenerate_lines(
        segment,
        [start, control, end],
        quadratic_degenerate_breaks(start, control, end, start),
        tolerance,
      )
    CubicBezier(start:, control1:, control2:, end:) ->
      bezier_degenerate_lines(
        segment,
        [start, control1, control2, end],
        cubic_degenerate_breaks(start, control1, control2, end, start),
        tolerance,
      )
    Arc(start:, radius:, end:, ..) -> {
      case radius.x == 0.0 || radius.y == 0.0 {
        True -> {
          case start == end {
            True -> Ok(Some([]))
            False -> Ok(Some([Line(start:, end:)]))
          }
        }
        False -> {
          use lines <- result.try(segment_to_lines_with(
            segment,
            options: LinearizeOptions(
              tolerance:,
              max_depth: default_linearize_max_depth,
            ),
          ))
          degenerate_line_list(lines, tolerance)
        }
      }
    }
  }
}

fn bezier_degenerate_lines(
  segment: Segment,
  defining_points: List(Point),
  breaks: List(Float),
  tolerance: Float,
) -> Result(Option(List(Segment)), Error) {
  case degenerate_line_axis(defining_points, tolerance) {
    None -> Ok(None)
    Some(#(start, axis)) -> {
      case
        defining_points_are_in_strip(defining_points, start, axis, tolerance)
      {
        False -> Ok(None)
        True -> {
          let breaks = [0.0, ..breaks] |> list.append([1.0])
          use lines <- result.try(line_pieces_at_breaks(segment, breaks, []))
          Ok(Some(remove_zero_length_lines(lines)))
        }
      }
    }
  }
}

fn degenerate_line_axis(
  points: List(Point),
  tolerance: Float,
) -> Option(#(Point, Point)) {
  case points {
    [start, ..] -> {
      case farthest_point(points, start, start) {
        farthest -> {
          case distance_squared(farthest, start) <=. tolerance *. tolerance {
            True -> None
            False -> Some(#(start, point_difference(farthest, start)))
          }
        }
      }
    }
    [] -> None
  }
}

fn defining_points_are_in_strip(
  points: List(Point),
  start: Point,
  axis: Point,
  tolerance: Float,
) -> Bool {
  let axis_length_squared = distance_squared(axis, Point(0.0, 0.0))
  list.all(points, fn(point) {
    let relative = point_difference(point, start)
    let cross = relative.x *. axis.y -. relative.y *. axis.x
    float.absolute_value(cross) /. sqrt(axis_length_squared) <=. tolerance
  })
}

fn degenerate_line_list(
  lines: List(Segment),
  tolerance: Float,
) -> Result(Option(List(Segment)), Error) {
  let points = line_list_points(lines, [])
  case degenerate_line_axis(points, tolerance) {
    None -> Ok(Some([]))
    Some(#(start, axis)) -> {
      case defining_points_are_in_strip(points, start, axis, tolerance) {
        True -> Ok(Some(remove_zero_length_lines(lines)))
        False -> Ok(None)
      }
    }
  }
}

fn farthest_point(points: List(Point), origin: Point, best: Point) -> Point {
  case points {
    [] -> best
    [first, ..rest] -> {
      let best = case
        distance_squared(first, origin) >. distance_squared(best, origin)
      {
        True -> first
        False -> best
      }
      farthest_point(rest, origin, best)
    }
  }
}

fn line_list_points(lines: List(Segment), points: List(Point)) -> List(Point) {
  case lines {
    [] -> list.reverse(points)
    [Line(start:, end:), ..rest] ->
      line_list_points(rest, [end, start, ..points])
    [_first, ..rest] -> line_list_points(rest, points)
  }
}

fn remove_zero_length_lines(lines: List(Segment)) -> List(Segment) {
  list.filter(lines, fn(segment) {
    segment_start(segment) != segment_end(segment)
  })
}

fn line_pieces_at_breaks(
  segment: Segment,
  breaks: List(Float),
  lines: List(Segment),
) -> Result(List(Segment), Error) {
  case breaks {
    [] | [_] -> Ok(list.reverse(lines))
    [from, to, ..rest] -> {
      use start <- result.try(segment_point(segment, at: from))
      use end <- result.try(segment_point(segment, at: to))
      line_pieces_at_breaks(segment, [to, ..rest], [Line(start:, end:), ..lines])
    }
  }
}

fn quadratic_degenerate_breaks(
  start: Point,
  control: Point,
  end: Point,
  axis_start: Point,
) -> List(Float) {
  let axis =
    point_difference(
      farthest_point([start, control, end], axis_start, axis_start),
      axis_start,
    )
  let s = axis_coordinate(start, axis_start, axis)
  let c = axis_coordinate(control, axis_start, axis)
  let e = axis_coordinate(end, axis_start, axis)
  let denominator = s -. { 2.0 *. c } +. e
  case denominator == 0.0 {
    True -> []
    False -> {
      let root = { s -. c } /. denominator
      root.strictly_inside([root], from: 0.0, to: 1.0)
    }
  }
}

fn cubic_degenerate_breaks(
  start: Point,
  control1: Point,
  control2: Point,
  end: Point,
  axis_start: Point,
) -> List(Float) {
  let axis =
    point_difference(
      farthest_point([start, control1, control2, end], axis_start, axis_start),
      axis_start,
    )
  let s = axis_coordinate(start, axis_start, axis)
  let c1 = axis_coordinate(control1, axis_start, axis)
  let c2 = axis_coordinate(control2, axis_start, axis)
  let e = axis_coordinate(end, axis_start, axis)
  let a = 0.0 -. s +. { 3.0 *. c1 } -. { 3.0 *. c2 } +. e
  let b = { 3.0 *. s } -. { 6.0 *. c1 } +. { 3.0 *. c2 }
  let c = { 3.0 *. c1 } -. { 3.0 *. s }
  root.quadratic_with(
    3.0 *. a,
    2.0 *. b,
    c,
    options: root.QuadraticOptions(
      coefficient_tolerance: 0.0,
      repeated_root_policy: root.PreserveRepeatedRoot,
    ),
  )
  |> root.strictly_inside(from: 0.0, to: 1.0)
}

fn axis_coordinate(point: Point, origin: Point, axis: Point) -> Float {
  let relative = point_difference(point, origin)
  let denominator = distance_squared(axis, Point(0.0, 0.0))
  case denominator == 0.0 {
    True -> 0.0
    False -> dot(relative, axis) /. denominator
  }
}

fn sqrt(value: Float) -> Float {
  let assert Ok(root) = float.square_root(value)
  root
}

/// Approximate every segment in a subpath with straight lines.
///
/// The subpath's start point and closed state are preserved. Move-only
/// subpaths remain move-only.
pub fn subpath_to_lines(subpath: Subpath) -> Result(Subpath, Error) {
  subpath_to_lines_with(subpath, options: default_linearize_options())
}

/// Approximate every segment in a subpath with straight lines using explicit
/// options.
pub fn subpath_to_lines_with(
  subpath: Subpath,
  options options: LinearizeOptions,
) -> Result(Subpath, Error) {
  use _ <- result.try(validate_linearize_options(options))
  use segments <- result.try(
    segments_to_lines(subpath.segments, options, converted: []),
  )
  Ok(Subpath(..subpath, segments:))
}

/// Approximate every segment in a path with straight lines.
///
/// Subpath order, move-only subpaths, and closed states are preserved.
pub fn path_to_lines(path: Path) -> Result(Path, Error) {
  path_to_lines_with(path, options: default_linearize_options())
}

/// Approximate every segment in a path with straight lines using explicit
/// options.
pub fn path_to_lines_with(
  path: Path,
  options options: LinearizeOptions,
) -> Result(Path, Error) {
  use _ <- result.try(validate_linearize_options(options))
  use subpaths <- result.try(
    subpaths_to_lines(path.subpaths, options, converted: []),
  )
  Ok(Path(subpaths:))
}

/// Check whether a subpath is closed.
pub fn subpath_is_closed(subpath: Subpath) -> Bool {
  subpath.closed
}

/// Set a subpath's semantic closed state.
///
/// Setting `closed` to `False` always succeeds. Setting it to `True` requires a
/// non-empty subpath's end point to exactly match its start point. Empty
/// subpaths may be closed.
pub fn subpath_set_closed(
  subpath: Subpath,
  closed closed: Bool,
) -> Result(Subpath, Error) {
  subpath_set_closed_with(subpath, closed:, policy: Strict)
}

/// Set a subpath's semantic closed state with an endpoint policy.
///
/// Setting `closed` to `False` always succeeds. Setting it to `True` uses the
/// given endpoint policy to reconcile a non-empty subpath's end point with its
/// start point. Empty subpaths may be closed.
pub fn subpath_set_closed_with(
  subpath: Subpath,
  closed closed: Bool,
  policy endpoint_policy: EndpointPolicy,
) -> Result(Subpath, Error) {
  case closed {
    False -> Ok(Subpath(..subpath, closed: False))
    True -> close_subpath_with(subpath, endpoint_policy)
  }
}

/// Set a subpath's semantic closed state, panicking if invalid.
pub fn subpath_assert_set_closed(
  subpath: Subpath,
  closed closed: Bool,
) -> Subpath {
  subpath_assert_set_closed_with(subpath, closed:, policy: Strict)
}

/// Set a subpath's semantic closed state with an endpoint policy, panicking if invalid.
pub fn subpath_assert_set_closed_with(
  subpath: Subpath,
  closed closed: Bool,
  policy endpoint_policy: EndpointPolicy,
) -> Subpath {
  case subpath_set_closed_with(subpath, closed:, policy: endpoint_policy) {
    Ok(subpath) -> subpath
    Error(_) ->
      panic as "svg_path.subpath_assert_set_closed received an invalid subpath"
  }
}

/// Break open a closed subpath at the given subpath parameter.
///
/// The returned subpath is open and traverses the whole loop from the split
/// point back to itself. The parameter must address a segment in the closed
/// subpath, with `t` inside `0.0..1.0`.
pub fn subpath_open_at(
  subpath: Subpath,
  at parameter: SubpathParameter,
) -> Result(Subpath, Error) {
  case subpath.closed {
    False -> Error(NotClosed)
    True -> {
      use subpaths <- result.try(
        subpath_between_many(subpath, between: [parameter]),
      )
      case subpaths {
        [opened] -> Ok(opened)
        _ -> Error(EmptySubpath)
      }
    }
  }
}

/// Compare two subpath parameters by segment index and then local `t`.
pub fn subpath_parameters_compare(
  a: SubpathParameter,
  b: SubpathParameter,
) -> order.Order {
  let SubpathParameter(segment_index: a_index, t: a_t) = a
  let SubpathParameter(segment_index: b_index, t: b_t) = b

  case int.compare(a_index, b_index) {
    order.Eq -> float.compare(a_t, b_t)
    order -> order
  }
}

/// Compare two path parameters by subpath index, then subpath parameter.
pub fn path_parameters_compare(
  a: PathParameter,
  b: PathParameter,
) -> order.Order {
  let PathParameter(subpath_index: a_index, at: a_at) = a
  let PathParameter(subpath_index: b_index, at: b_at) = b

  case int.compare(a_index, b_index) {
    order.Eq -> subpath_parameters_compare(a_at, b_at)
    order -> order
  }
}

/// Return a validated subpath parameter addressed as if the subpath were reversed.
///
/// `segment_index` addresses the reversed segment list. `t` is also measured in
/// the reversed segment's direction, then converted back into the original
/// subpath's coordinates.
pub fn subpath_parameter_from_end(
  subpath: Subpath,
  segment_index segment_index: Int,
  t t: Float,
) -> Result(SubpathParameter, Error) {
  let reverse_parameter = SubpathParameter(segment_index:, t:)
  use _ <- result.try(validate_subpath_parameter(subpath, reverse_parameter))

  let length = list.length(subpath.segments)
  Ok(SubpathParameter(segment_index: length - 1 - segment_index, t: 1.0 -. t))
}

/// Return the exact canonical address of a subpath parameter.
///
/// An exact internal segment end canonicalizes to the next segment's `t =
/// 0.0`. The exact end of a closed subpath's last segment canonicalizes to
/// `SubpathParameter(0, 0.0)`. The end of an open subpath's last segment
/// remains at `t = 1.0`. Parameters merely near a boundary are unchanged.
pub fn subpath_parameter_canonicalize(
  subpath: Subpath,
  parameter parameter: SubpathParameter,
) -> Result(SubpathParameter, Error) {
  use parameter <- result.try(validate_subpath_parameter(subpath, parameter))
  Ok(canonical_to_subpath_parameter(parameter))
}

/// Snap a subpath parameter to a segment boundary in parameter space, then
/// return its canonical address.
///
/// `tolerance` is measured in the addressed segment's local parameter units,
/// not in path coordinate units. It must be finite and greater than zero.
pub fn subpath_parameter_snap_to_boundary(
  subpath: Subpath,
  parameter parameter: SubpathParameter,
  tolerance tolerance: Float,
) -> Result(SubpathParameter, Error) {
  case tolerance <=. 0.0 || !number.is_finite(tolerance) {
    True -> Error(InvalidIntersectionTolerance(tolerance))
    False -> {
      use _ <- result.try(validate_subpath_parameter(subpath, parameter))
      Ok(canonicalize_subpath_parameter_unchecked(parameter, subpath, tolerance))
    }
  }
}

/// Evaluate a subpath at a subpath parameter.
///
/// The parameter must address a segment in the subpath, with `t` inside
/// `0.0..1.0`. Internal segment-end parameters are evaluated through their
/// canonical next-segment start address.
pub fn subpath_point(
  subpath: Subpath,
  at parameter: SubpathParameter,
) -> Result(Point, Error) {
  use parameter <- result.try(validate_subpath_parameter(subpath, parameter))
  let CanonicalSubpathParameter(segment_index:, t:) = parameter
  use segment <- result.try(nth_segment(subpath.segments, segment_index))

  segment_point(segment, at: t)
}

/// Return a subpath's segment derivative at a subpath parameter.
///
/// The parameter must address a segment in the subpath, with `t` inside
/// `0.0..1.0`. Internal segment-end parameters are evaluated through their
/// canonical next-segment start address.
pub fn subpath_derivative(
  subpath: Subpath,
  at parameter: SubpathParameter,
) -> Result(Point, Error) {
  use parameter <- result.try(validate_subpath_parameter(subpath, parameter))
  let CanonicalSubpathParameter(segment_index:, t:) = parameter
  use segment <- result.try(nth_segment(subpath.segments, segment_index))

  segment_derivative(segment, at: t)
}

/// Return singularity-safe unit traversal directions at a subpath parameter.
///
/// At internal vertices and closed seams, directions are taken from the
/// adjacent segments. Directionless segments are skipped. Open subpath ends
/// have only the side supplied by the subpath.
pub fn subpath_directions(
  subpath: Subpath,
  at parameter: SubpathParameter,
) -> Result(Directions, Error) {
  subpath_directions_with(
    subpath,
    at: parameter,
    options: default_direction_options(),
  )
}

/// Return singularity-safe unit traversal directions using explicit options.
pub fn subpath_directions_with(
  subpath: Subpath,
  at parameter: SubpathParameter,
  options options: DirectionOptions,
) -> Result(Directions, Error) {
  use _ <- result.try(validate_direction_options(options))
  use parameter <- result.try(validate_subpath_parameter(subpath, parameter))
  let CanonicalSubpathParameter(segment_index:, t:) = parameter
  let segment_count = list.length(subpath.segments)

  case t {
    0.0 -> {
      use incoming <- result.try(subpath_direction_from_segments(
        subpath.segments,
        from: segment_index - 1,
        step: -1,
        remaining: segment_count,
        closed: subpath.closed,
        incoming: True,
        options:,
      ))
      use outgoing <- result.try(subpath_direction_from_segments(
        subpath.segments,
        from: segment_index,
        step: 1,
        remaining: segment_count,
        closed: subpath.closed,
        incoming: False,
        options:,
      ))
      Ok(Directions(incoming:, outgoing:))
    }
    1.0 -> {
      use incoming <- result.try(subpath_direction_from_segments(
        subpath.segments,
        from: segment_index,
        step: -1,
        remaining: segment_count,
        closed: subpath.closed,
        incoming: True,
        options:,
      ))
      use outgoing <- result.try(subpath_direction_from_segments(
        subpath.segments,
        from: segment_index + 1,
        step: 1,
        remaining: segment_count,
        closed: subpath.closed,
        incoming: False,
        options:,
      ))
      Ok(Directions(incoming:, outgoing:))
    }
    _ -> {
      use segment <- result.try(nth_segment(subpath.segments, segment_index))
      segment_directions_with(segment, at: t, options:)
    }
  }
}

/// Split an open subpath at a subpath parameter.
///
/// The split point must be inside the subpath: it cannot be the first point,
/// the last point, outside the segment list, or outside the addressed segment's
/// `0.0..1.0` parameter range. Closed and empty subpaths are rejected.
pub fn subpath_split(
  subpath: Subpath,
  at at: SubpathParameter,
) -> Result(#(Subpath, Subpath), Error) {
  case subpath.closed {
    True -> Error(AlreadyClosed)
    False -> {
      use at <- result.try(validate_subpath_parameter(subpath, at))
      case subpath_parameter_is_boundary(at, list.length(subpath.segments)) {
        True -> invalid_subpath_parameter(at, list.length(subpath.segments))
        False -> {
          use left_segments <- result.try(subpath_interval_segments(
            subpath,
            from: subpath_start_parameter(),
            to: at,
          ))
          use right_segments <- result.try(subpath_interval_segments(
            subpath,
            from: at,
            to: subpath_end_parameter(list.length(subpath.segments)),
          ))
          use left <- result.try(open_subpath_with_segments(
            left_segments,
            Strict,
          ))
          use right <- result.try(open_subpath_with_segments(
            right_segments,
            Strict,
          ))
          Ok(#(left, right))
        }
      }
    }
  }
}

/// Return the open subpath between two subpath parameters.
///
/// Parameters must be valid for the subpath and must describe a positive-length
/// interval. Open subpaths reject reversed intervals. Closed subpaths allow
/// wrapped intervals, but equal parameters are still rejected.
pub fn subpath_between(
  subpath: Subpath,
  from from: SubpathParameter,
  to to: SubpathParameter,
) -> Result(Subpath, Error) {
  use from <- result.try(validate_subpath_parameter(subpath, from))
  use to <- result.try(validate_subpath_parameter(subpath, to))
  subpath_between_valid_parameters(subpath, from:, to:)
}

/// Split a subpath at multiple subpath parameters.
///
/// Open subpaths return the outer pieces as well as the pieces between split
/// points, so an empty split list returns the original subpath. Open split
/// points must be strictly increasing and cannot include the very start or very
/// end. Closed split points must be cyclically increasing and distinct. For
/// closed subpaths, an empty split list returns an empty list, and a single
/// split point returns one open subpath traversing the whole loop from that
/// point back to itself.
pub fn subpath_between_many(
  subpath: Subpath,
  between points: List(SubpathParameter),
) -> Result(List(Subpath), Error) {
  let length = list.length(subpath.segments)
  use points <- result.try(validate_subpath_parameters(subpath, points))

  case subpath.closed {
    False ->
      case points {
        [] -> Ok([subpath])
        _ -> {
          use _ <- result.try(validate_open_subpath_split_points(points, length))
          subpaths_between_points(subpath, [
            subpath_start_parameter(),
            ..list.append(points, [subpath_end_parameter(length)])
          ])
        }
      }
    True ->
      case points {
        [] -> Ok([])
        [point] ->
          open_closed_subpath_at_parameter(subpath, point)
          |> result.map(fn(subpath) { [subpath] })
        _ -> {
          use _ <- result.try(validate_closed_subpath_split_points(points))
          subpaths_between_pairs(subpath, cyclic_parameter_pairs(points))
        }
      }
  }
}

/// Return the start point of a subpath.
pub fn subpath_start(subpath: Subpath) -> Result(Point, Error) {
  Ok(subpath.start)
}

/// Return the end point of a subpath.
pub fn subpath_end(subpath: Subpath) -> Result(Point, Error) {
  case list.last(subpath.segments) {
    Ok(last) -> Ok(segment_end(last))
    Error(_) -> Ok(subpath.start)
  }
}

/// Return the start point of the first subpath in a path.
pub fn path_start(path: Path) -> Result(Point, Error) {
  case path.subpaths {
    [] -> Error(EmptyPath)
    subpaths -> first_subpath_start(subpaths)
  }
}

/// Return the end point of the last subpath in a path.
pub fn path_end(path: Path) -> Result(Point, Error) {
  case path.subpaths {
    [] -> Error(EmptyPath)
    subpaths -> first_subpath_end(list.reverse(subpaths))
  }
}

/// Append a segment to an open subpath.
///
/// The new segment must start exactly at the current end point.
pub fn subpath_append_segment(
  subpath: Subpath,
  segment: Segment,
) -> Result(Subpath, Error) {
  subpath_append_segment_with(subpath, segment, policy: Strict)
}

/// Append a segment to an open subpath using the given endpoint policy.
pub fn subpath_append_segment_with(
  subpath: Subpath,
  segment: Segment,
  policy endpoint_policy: EndpointPolicy,
) -> Result(Subpath, Error) {
  case subpath.closed {
    True -> Error(AlreadyClosed)
    False -> {
      let segments = list.append(subpath.segments, [segment])
      open_subpath_with_start(segments, subpath.start, endpoint_policy)
    }
  }
}

/// Append a segment to an open subpath, panicking if invalid.
pub fn subpath_assert_append_segment(
  subpath: Subpath,
  segment: Segment,
) -> Subpath {
  subpath_assert_append_segment_with(subpath, segment, policy: Strict)
}

/// Append a segment with an endpoint policy, panicking if invalid.
pub fn subpath_assert_append_segment_with(
  subpath: Subpath,
  segment: Segment,
  policy endpoint_policy: EndpointPolicy,
) -> Subpath {
  case subpath_append_segment_with(subpath, segment, policy: endpoint_policy) {
    Ok(subpath) -> subpath
    Error(_) ->
      panic as "svg_path.subpath_assert_append_segment received an invalid segment"
  }
}

/// Join open subpaths into one open subpath.
///
/// Each subpath's end point must exactly match the next subpath's start point.
/// Empty open subpaths can act as identity values when their start points line
/// up with their neighbors.
pub fn subpath_join(subpaths: List(Subpath)) -> Result(Subpath, Error) {
  subpath_join_with(subpaths, policy: Strict)
}

/// Join open subpaths using the given endpoint policy.
pub fn subpath_join_with(
  subpaths: List(Subpath),
  policy endpoint_policy: EndpointPolicy,
) -> Result(Subpath, Error) {
  case list.any(subpaths, fn(subpath) { subpath.closed }) {
    True -> Error(AlreadyClosed)
    False -> join_open_subpaths(subpaths, endpoint_policy)
  }
}

/// Join open subpaths, panicking if invalid.
pub fn subpath_assert_join(subpaths: List(Subpath)) -> Subpath {
  subpath_assert_join_with(subpaths, policy: Strict)
}

/// Join open subpaths with an endpoint policy, panicking if invalid.
pub fn subpath_assert_join_with(
  subpaths: List(Subpath),
  policy endpoint_policy: EndpointPolicy,
) -> Subpath {
  case subpath_join_with(subpaths, policy: endpoint_policy) {
    Ok(subpath) -> subpath
    Error(_) ->
      panic as "svg_path.subpath_assert_join received invalid subpaths"
  }
}

/// Return the start point of a segment.
pub fn segment_start(segment: Segment) -> Point {
  case segment {
    Line(start:, ..)
    | QuadraticBezier(start:, ..)
    | CubicBezier(start:, ..)
    | Arc(start:, ..) -> start
  }
}

/// Return the end point of a segment.
pub fn segment_end(segment: Segment) -> Point {
  case segment {
    Line(end:, ..)
    | QuadraticBezier(end:, ..)
    | CubicBezier(end:, ..)
    | Arc(end:, ..) -> end
  }
}

/// Return the distance between a segment's start and end points.
///
/// This is the endpoint chord length. It can be zero even when a curve has
/// nonzero interior geometry.
pub fn segment_chord_length(segment: Segment) -> Float {
  distance(segment_start(segment), segment_end(segment))
}

/// Return the squared distance between a segment's start and end points.
///
/// This is the square of the endpoint chord length. It can be zero even when a
/// curve has nonzero interior geometry.
pub fn segment_chord_length_squared(segment: Segment) -> Float {
  distance_squared(segment_start(segment), segment_end(segment))
}

/// Reverse the traversal direction of a segment.
pub fn segment_reverse(segment: Segment) -> Segment {
  case segment {
    Line(start:, end:) -> Line(start: end, end: start)
    QuadraticBezier(start:, control:, end:) -> {
      QuadraticBezier(start: end, control:, end: start)
    }
    CubicBezier(start:, control1:, control2:, end:) -> {
      CubicBezier(
        start: end,
        control1: control2,
        control2: control1,
        end: start,
      )
    }
    Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:) -> {
      Arc(
        start: end,
        radius:,
        x_axis_rotation:,
        large_arc:,
        sweep: !sweep,
        end: start,
      )
    }
  }
}

/// Evaluate a segment at parameter `t`.
///
/// `t` is not clamped. Values outside `0.0..1.0` extrapolate along the same
/// segment.
pub fn segment_point(segment: Segment, at t: Float) -> Result(Point, Error) {
  case t {
    0.0 -> Ok(segment_start(segment))
    1.0 -> Ok(segment_end(segment))
    _ -> {
      case segment {
        Line(..) | QuadraticBezier(..) | CubicBezier(..) -> {
          Ok(
            segment_to_bezier_data(segment)
            |> bezier.bezier_point(at: t)
            |> from_bezier_point,
          )
        }
        Arc(..) -> {
          case arc_center_data(segment) {
            Error(error) -> Error(error)
            Ok(arc) -> Ok(ellipse.arc_point(arc, at: t) |> from_ellipse_point)
          }
        }
      }
    }
  }
}

/// Return a segment's derivative with respect to parameter `t`.
///
/// `t` is not clamped.
pub fn segment_derivative(
  segment: Segment,
  at t: Float,
) -> Result(Point, Error) {
  case segment {
    Line(..) | QuadraticBezier(..) | CubicBezier(..) -> {
      Ok(
        segment_to_bezier_data(segment)
        |> bezier.bezier_derivative(at: t)
        |> from_bezier_point,
      )
    }
    Arc(..) -> {
      case arc_center_data(segment) {
        Error(error) -> Error(error)
        Ok(arc) -> Ok(ellipse.arc_derivative(arc, at: t) |> from_ellipse_point)
      }
    }
  }
}

/// Return the default options for singularity-safe direction queries.
pub fn default_direction_options() -> DirectionOptions {
  DirectionOptions(relative_tolerance: default_direction_relative_tolerance)
}

/// Return singularity-safe unit traversal directions at a segment parameter.
///
/// The segment parameter may extrapolate as with `segment_point`. At `0.0`
/// only `outgoing` is present, and at `1.0` only `incoming` is present.
pub fn segment_directions(
  segment: Segment,
  at t: Float,
) -> Result(Directions, Error) {
  segment_directions_with(segment, at: t, options: default_direction_options())
}

/// Return singularity-safe unit traversal directions using explicit options.
///
/// A zero relative tolerance skips only exactly collapsed candidate vectors.
pub fn segment_directions_with(
  segment: Segment,
  at t: Float,
  options options: DirectionOptions,
) -> Result(Directions, Error) {
  use _ <- result.try(validate_direction_options(options))

  case segment {
    Arc(..) -> {
      use derivative <- result.try(segment_derivative(segment, at: t))
      let direction = vector_direction(derivative)
      Ok(case t {
        0.0 -> Directions(incoming: None, outgoing: direction)
        1.0 -> Directions(incoming: direction, outgoing: None)
        _ -> Directions(incoming: direction, outgoing: direction)
      })
    }
    Line(..) | QuadraticBezier(..) | CubicBezier(..) ->
      case t {
        0.0 ->
          Ok(Directions(
            incoming: None,
            outgoing: segment_endpoint_direction(
              segment,
              incoming: False,
              options:,
            ),
          ))
        1.0 ->
          Ok(Directions(
            incoming: segment_endpoint_direction(
              segment,
              incoming: True,
              options:,
            ),
            outgoing: None,
          ))
        _ -> {
          use split <- result.try(segment_split(segment, at: t))
          let #(left, right) = split
          Ok(Directions(
            incoming: segment_endpoint_direction(left, incoming: True, options:),
            outgoing: segment_endpoint_direction(
              right,
              incoming: False,
              options:,
            ),
          ))
        }
      }
  }
}

/// Return a segment's exact axis-aligned bounding box.
pub fn segment_bounding_box(segment: Segment) -> Result(BoundingBox, Error) {
  case segment {
    Line(start:, end:) ->
      Ok(BoundingBox(min: min_point(start, end), max: max_point(start, end)))
    QuadraticBezier(..) | CubicBezier(..) -> {
      let bezier.BoundingBox(min:, max:) =
        segment_to_bezier_data(segment) |> bezier.bezier_bounding_box

      Ok(BoundingBox(min: from_bezier_point(min), max: from_bezier_point(max)))
    }
    Arc(..) -> {
      case arc_center_data(segment) {
        Error(error) -> Error(error)
        Ok(arc) -> {
          let ellipse.BoundingBox(min:, max:) = ellipse.arc_bounding_box(arc)

          Ok(BoundingBox(
            min: from_ellipse_point(min),
            max: from_ellipse_point(max),
          ))
        }
      }
    }
  }
}

/// Find scalar sign-change crossings along a segment using default options.
///
/// This samples `t` in `0.0..1.0`, detects sign changes of `f(segment_point(t))`,
/// and refines each bracket with bisection. It finds crossings visible at the
/// configured sampling resolution; tangent roots and pairs of crossings inside
/// one sample window may be missed.
pub fn segment_crossings(
  segment: Segment,
  where f: fn(Point) -> Float,
) -> Result(List(Float), Error) {
  segment_crossings_with(segment, where: f, options: default_crossing_options())
}

/// Find scalar sign-change crossings along a segment using explicit options.
///
/// Once a sign-changing sample window is found, refinement succeeds only when
/// `abs(f(segment_point(t))) <= options.signed_line_distance_tolerance`.
pub fn segment_crossings_with(
  segment: Segment,
  where f: fn(Point) -> Float,
  options options: CrossingOptions,
) -> Result(List(Float), Error) {
  case validate_crossing_options(options) {
    Error(error) -> Error(error)
    Ok(Nil) -> {
      case crossing_value(segment, f, 0.0) {
        Error(error) -> Error(error)
        Ok(first_value) -> {
          scan_crossings(
            segment,
            f,
            options,
            index: 1,
            previous_t: 0.0,
            previous_value: first_value,
            crossings: [],
          )
        }
      }
    }
  }
}

/// Find crossings between a segment and a ray's supporting line.
///
/// The ray is represented by an origin and a direction vector. Returned values
/// are `#(segment_t, ray_t)` pairs where:
///
/// ```gleam
/// segment_point(segment, at: segment_t)
/// // is approximately
/// origin + ray_t * direction
/// ```
///
/// `ray_t >= 0.0` means the crossing lies on the positive ray. Negative
/// `ray_t` values are returned too, so callers can choose their own filtering
/// policy.
///
/// Unlike `segment_crossings_with`, this splits the segment at projection
/// extrema before refinement, so tangent line contacts are visible without a
/// fixed sampling grid.
pub fn segment_ray_crossings_with(
  segment: Segment,
  origin origin: Point,
  direction direction: Point,
  options options: CrossingOptions,
) -> Result(List(#(Float, Float)), Error) {
  use _ <- result.try(validate_crossing_options(options))
  use _ <- result.try(validate_ray_crossing_direction(direction))
  let normal = ray_supporting_line_normal(direction)
  use parameters <- result.try(segment_line_crossings_with(
    segment,
    point: origin,
    normal:,
    options:,
  ))

  ray_parameters_for_crossings(
    segment,
    origin,
    direction,
    parameters,
    crossings: [],
  )
}

fn segment_line_crossings_with(
  segment: Segment,
  point point: Point,
  normal normal: Point,
  options options: CrossingOptions,
) -> Result(List(Float), Error) {
  let signed_line_distance_tolerance =
    options.signed_line_distance_tolerance
    *. float_square_root(distance_squared(normal, Point(0.0, 0.0)))

  use roots <- result.try(segment_line_classified_roots(
    segment,
    point,
    normal,
    signed_line_distance_tolerance,
    options.max_iterations,
  ))

  Ok(classified_root_estimates(roots, crossings: []))
}

/// Return the segment parameter where a scalar function is minimized.
///
/// This numerically minimizes `f(segment_point(t))` for `t` in `0.0..1.0`.
pub fn segment_minimize(
  segment: Segment,
  measure f: fn(Point) -> Float,
) -> Result(Float, Error) {
  segment_minimize_with(
    segment,
    measure: f,
    options: default_minimize_options(),
  )
}

/// Return the segment parameter where a scalar function is minimized using
/// explicit options.
pub fn segment_minimize_with(
  segment: Segment,
  measure f: fn(Point) -> Float,
  options options: MinimizeOptions,
) -> Result(Float, Error) {
  case validate_minimize_options(options) {
    Error(error) -> Error(error)
    Ok(Nil) -> {
      case minimize_value(segment, f, 0.0) {
        Error(error) -> Error(error)
        Ok(first) -> {
          case
            scan_minimize_windows(
              segment,
              f,
              options,
              index: 1,
              previous_t: 0.0,
              best: first,
            )
          {
            Error(error) -> Error(error)
            Ok(best) -> Ok(best.t)
          }
        }
      }
    }
  }
}

/// Return the approximate length of a segment.
///
/// Lines are measured exactly. Quadratic Beziers, cubic Beziers, and arcs are
/// approximated by adaptive Simpson integration of segment speed.
pub fn segment_length(segment: Segment) -> Result(Float, Error) {
  segment_length_with(segment, options: default_length_options())
}

/// Return the approximate length of a segment using explicit options.
pub fn segment_length_with(
  segment: Segment,
  options options: LengthOptions,
) -> Result(Float, Error) {
  case validate_length_options(options) {
    Error(error) -> Error(error)
    Ok(Nil) -> {
      case segment {
        Line(start:, end:) -> Ok(distance(start, end))
        QuadraticBezier(..) | CubicBezier(..) | Arc(..) ->
          adaptive_segment_length(segment, options)
      }
    }
  }
}

/// Return whether a segment has length at most `tolerance`.
///
/// `tolerance` is measured in path coordinate units and may be exactly `0.0`
/// for an exact zero-length check. Lines are measured exactly. Quadratic
/// Beziers, cubic Beziers, and arcs are measured with default length options.
pub fn segment_is_zero_length(
  segment: Segment,
  tolerance tolerance: Float,
) -> Result(Bool, Error) {
  use _ <- result.try(validate_zero_length_tolerance(tolerance))
  use length <- result.try(segment_length(segment))
  Ok(length <=. tolerance)
}

/// Return the segment parameter at a traveled distance from the segment start.
///
/// The distance is measured in path coordinate units, not normalized. Lines are
/// inverted exactly. Quadratic Beziers, cubic Beziers, and arcs are inverted
/// numerically using the same length options as `segment_length_with`.
pub fn segment_parameter_at_length(
  segment: Segment,
  distance distance: Float,
) -> Result(Float, Error) {
  segment_parameter_at_length_with(
    segment,
    distance:,
    options: default_length_options(),
  )
}

/// Return the segment parameter at a traveled distance using explicit options.
pub fn segment_parameter_at_length_with(
  segment: Segment,
  distance distance: Float,
  options options: LengthOptions,
) -> Result(Float, Error) {
  use length <- result.try(segment_length_with(segment, options:))
  segment_parameter_at_known_length(segment, distance, length, options)
}

/// Return the segment point at a traveled distance from the segment start.
pub fn segment_point_at_length(
  segment: Segment,
  distance distance: Float,
) -> Result(Point, Error) {
  segment_point_at_length_with(
    segment,
    distance:,
    options: default_length_options(),
  )
}

/// Return the segment point at a traveled distance using explicit options.
pub fn segment_point_at_length_with(
  segment: Segment,
  distance distance: Float,
  options options: LengthOptions,
) -> Result(Point, Error) {
  use t <- result.try(segment_parameter_at_length_with(
    segment,
    distance:,
    options:,
  ))
  segment_point(segment, at: t)
}

/// Return the segment derivative at a traveled distance from the segment start.
pub fn segment_derivative_at_length(
  segment: Segment,
  distance distance: Float,
) -> Result(Point, Error) {
  segment_derivative_at_length_with(
    segment,
    distance:,
    options: default_length_options(),
  )
}

/// Return the segment derivative at a traveled distance using explicit options.
pub fn segment_derivative_at_length_with(
  segment: Segment,
  distance distance: Float,
  options options: LengthOptions,
) -> Result(Point, Error) {
  use t <- result.try(segment_parameter_at_length_with(
    segment,
    distance:,
    options:,
  ))
  segment_derivative(segment, at: t)
}

/// Return the portion of a segment between two traveled distances.
///
/// Distances are measured in path coordinate units from the segment start and
/// must be inside `0.0..length`, inclusive. If `from` is greater than `to`, the
/// returned segment traverses the interval in reverse.
pub fn segment_between_lengths(
  segment: Segment,
  from from: Float,
  to to: Float,
) -> Result(Segment, Error) {
  segment_between_lengths_with(
    segment,
    from:,
    to:,
    options: default_length_options(),
  )
}

/// Return the portion of a segment between two traveled distances using
/// explicit length options.
pub fn segment_between_lengths_with(
  segment: Segment,
  from from: Float,
  to to: Float,
  options options: LengthOptions,
) -> Result(Segment, Error) {
  use length <- result.try(segment_length_with(segment, options:))
  use from <- result.try(segment_parameter_at_known_length(
    segment,
    from,
    length,
    options,
  ))
  use to <- result.try(segment_parameter_at_known_length(
    segment,
    to,
    length,
    options,
  ))
  segment_between(segment, from:, to:)
}

/// Return segment portions between adjacent traveled distances.
///
/// Distances are measured in path coordinate units from the segment start and
/// must be inside `0.0..length`, inclusive. Empty and singleton lists return an
/// empty list.
pub fn segment_between_lengths_many(
  segment: Segment,
  between distances: List(Float),
) -> Result(List(Segment), Error) {
  segment_between_lengths_many_with(
    segment,
    between: distances,
    options: default_length_options(),
  )
}

/// Return segment portions between adjacent traveled distances using explicit
/// length options.
pub fn segment_between_lengths_many_with(
  segment: Segment,
  between distances: List(Float),
  options options: LengthOptions,
) -> Result(List(Segment), Error) {
  use length <- result.try(segment_length_with(segment, options:))
  use points <- result.try(
    segment_parameters_at_known_lengths(segment, distances, length, options, []),
  )
  segment_between_many(segment, between: points)
}

/// Subdivide a segment into pieces of at most `max_length`.
///
/// Splits are chosen by traveled arc length, not by equal Bezier or arc
/// parameter spacing. Zero-length segments are returned unchanged.
pub fn segment_subdivide_to_max_length(
  segment: Segment,
  max_length max_length: Float,
) -> Result(List(Segment), Error) {
  segment_subdivide_to_max_length_with(
    segment,
    max_length:,
    options: default_length_options(),
  )
}

/// Subdivide a segment into pieces of at most `max_length` using explicit
/// length options.
pub fn segment_subdivide_to_max_length_with(
  segment: Segment,
  max_length max_length: Float,
  options options: LengthOptions,
) -> Result(List(Segment), Error) {
  use _ <- result.try(validate_subdivision_max_length(max_length))
  use length <- result.try(segment_length_with(segment, options:))
  case length == 0.0 {
    True -> Ok([segment])
    False -> {
      let piece_count = float.ceiling(length /. max_length) |> float.truncate
      let step = length /. int.to_float(piece_count)
      segment_between_lengths_many_with(
        segment,
        between: subdivision_distances(length, piece_count, step),
        options:,
      )
    }
  }
}

/// Subdivide every segment in a subpath into pieces of at most `max_length`.
///
/// Existing segment boundaries are preserved. The subpath's closed state is
/// preserved.
pub fn subpath_subdivide_to_max_length(
  subpath: Subpath,
  max_length max_length: Float,
) -> Result(Subpath, Error) {
  subpath_subdivide_to_max_length_with(
    subpath,
    max_length:,
    options: default_length_options(),
  )
}

/// Subdivide every segment in a subpath into pieces of at most `max_length`
/// using explicit length options.
pub fn subpath_subdivide_to_max_length_with(
  subpath: Subpath,
  max_length max_length: Float,
  options options: LengthOptions,
) -> Result(Subpath, Error) {
  use segments <- result.try(
    subdivide_segments_to_max_length(subpath.segments, max_length, options, []),
  )
  Ok(Subpath(..subpath, segments:))
}

/// Subdivide every segment in a path into pieces of at most `max_length`.
///
/// Existing subpath boundaries and closed states are preserved.
pub fn path_subdivide_to_max_length(
  path: Path,
  max_length max_length: Float,
) -> Result(Path, Error) {
  path_subdivide_to_max_length_with(
    path,
    max_length:,
    options: default_length_options(),
  )
}

/// Subdivide every segment in a path into pieces of at most `max_length` using
/// explicit length options.
pub fn path_subdivide_to_max_length_with(
  path: Path,
  max_length max_length: Float,
  options options: LengthOptions,
) -> Result(Path, Error) {
  use subpaths <- result.try(
    subdivide_subpaths_to_max_length(path.subpaths, max_length, options, []),
  )
  Ok(Path(subpaths:))
}

/// Return the approximate length of a subpath.
///
/// Empty subpaths have length `0.0`.
pub fn subpath_length(subpath: Subpath) -> Result(Float, Error) {
  subpath_length_with(subpath, options: default_length_options())
}

/// Return the approximate length of a subpath using explicit options.
pub fn subpath_length_with(
  subpath: Subpath,
  options options: LengthOptions,
) -> Result(Float, Error) {
  case validate_length_options(options) {
    Error(error) -> Error(error)
    Ok(Nil) -> subpath_length_loop(subpath.segments, options, total: 0.0)
  }
}

/// Return whether a subpath is a zero-length drawing subpath.
///
/// Empty subpaths are not considered zero-length drawing subpaths. A non-empty
/// subpath is zero-length when every segment has length at most `tolerance`.
pub fn subpath_is_zero_length(
  subpath: Subpath,
  tolerance tolerance: Float,
) -> Result(Bool, Error) {
  use _ <- result.try(validate_zero_length_tolerance(tolerance))
  case subpath.segments {
    [] -> Ok(False)
    segments -> subpath_segments_are_zero_length(segments, tolerance)
  }
}

/// Return the subpath parameter at a traveled distance from the subpath start.
///
/// The distance is measured in path coordinate units, not normalized. The
/// returned value is an ordinary public `SubpathParameter`.
pub fn subpath_parameter_at_length(
  subpath: Subpath,
  distance distance: Float,
) -> Result(SubpathParameter, Error) {
  subpath_parameter_at_length_with(
    subpath,
    distance:,
    options: default_length_options(),
  )
}

/// Return the subpath parameter at a traveled distance using explicit options.
pub fn subpath_parameter_at_length_with(
  subpath: Subpath,
  distance distance: Float,
  options options: LengthOptions,
) -> Result(SubpathParameter, Error) {
  use length <- result.try(subpath_length_with(subpath, options:))
  subpath_parameter_at_known_length(subpath, distance, length, options)
}

/// Return the subpath point at a traveled distance from the subpath start.
pub fn subpath_point_at_length(
  subpath: Subpath,
  distance distance: Float,
) -> Result(Point, Error) {
  subpath_point_at_length_with(
    subpath,
    distance:,
    options: default_length_options(),
  )
}

/// Return the subpath point at a traveled distance using explicit options.
pub fn subpath_point_at_length_with(
  subpath: Subpath,
  distance distance: Float,
  options options: LengthOptions,
) -> Result(Point, Error) {
  use parameter <- result.try(subpath_parameter_at_length_with(
    subpath,
    distance:,
    options:,
  ))
  subpath_point(subpath, at: parameter)
}

/// Return the subpath derivative at a traveled distance from the subpath start.
pub fn subpath_derivative_at_length(
  subpath: Subpath,
  distance distance: Float,
) -> Result(Point, Error) {
  subpath_derivative_at_length_with(
    subpath,
    distance:,
    options: default_length_options(),
  )
}

/// Return the subpath derivative at a traveled distance using explicit options.
pub fn subpath_derivative_at_length_with(
  subpath: Subpath,
  distance distance: Float,
  options options: LengthOptions,
) -> Result(Point, Error) {
  use parameter <- result.try(subpath_parameter_at_length_with(
    subpath,
    distance:,
    options:,
  ))
  subpath_derivative(subpath, at: parameter)
}

/// Return the open subpath between two traveled distances.
///
/// Distances are measured in path coordinate units from the subpath start and
/// must be inside `0.0..length`, inclusive. The resulting parameters follow
/// the same interval rules as `subpath_between`.
pub fn subpath_between_lengths(
  subpath: Subpath,
  from from: Float,
  to to: Float,
) -> Result(Subpath, Error) {
  subpath_between_lengths_with(
    subpath,
    from:,
    to:,
    options: default_length_options(),
  )
}

/// Return the open subpath between two traveled distances using explicit
/// length options.
pub fn subpath_between_lengths_with(
  subpath: Subpath,
  from from: Float,
  to to: Float,
  options options: LengthOptions,
) -> Result(Subpath, Error) {
  use length <- result.try(subpath_length_with(subpath, options:))
  use from <- result.try(subpath_parameter_at_known_length(
    subpath,
    from,
    length,
    options,
  ))
  use to <- result.try(subpath_parameter_at_known_length(
    subpath,
    to,
    length,
    options,
  ))
  subpath_between(subpath, from:, to:)
}

/// Split a subpath at multiple traveled distances.
///
/// Distances are measured in path coordinate units from the subpath start and
/// must be inside `0.0..length`, inclusive. The resulting parameters follow
/// the same split-point rules as `subpath_between_many`.
pub fn subpath_between_lengths_many(
  subpath: Subpath,
  between distances: List(Float),
) -> Result(List(Subpath), Error) {
  subpath_between_lengths_many_with(
    subpath,
    between: distances,
    options: default_length_options(),
  )
}

/// Split a subpath at multiple traveled distances using explicit length
/// options.
pub fn subpath_between_lengths_many_with(
  subpath: Subpath,
  between distances: List(Float),
  options options: LengthOptions,
) -> Result(List(Subpath), Error) {
  use length <- result.try(subpath_length_with(subpath, options:))
  use points <- result.try(
    subpath_parameters_at_known_lengths(subpath, distances, length, options, []),
  )
  subpath_between_many(subpath, between: points)
}

/// Return the approximate length of a path.
///
/// Empty paths have length `0.0`. Move-only subpaths contribute `0.0`.
pub fn path_length(path: Path) -> Result(Float, Error) {
  path_length_with(path, options: default_length_options())
}

/// Return the approximate length of a path using explicit options.
pub fn path_length_with(
  path: Path,
  options options: LengthOptions,
) -> Result(Float, Error) {
  case validate_length_options(options) {
    Error(error) -> Error(error)
    Ok(Nil) -> path_length_loop(path.subpaths, options, total: 0.0)
  }
}

/// Return the path parameter at a traveled distance from the path start.
///
/// The distance is measured across subpaths in path order. Move-only subpaths
/// contribute no length and are skipped for lookup. The returned value is an
/// ordinary public `PathParameter`.
pub fn path_parameter_at_length(
  path: Path,
  distance distance: Float,
) -> Result(PathParameter, Error) {
  path_parameter_at_length_with(
    path,
    distance:,
    options: default_length_options(),
  )
}

/// Return the path parameter at a traveled distance using explicit options.
pub fn path_parameter_at_length_with(
  path: Path,
  distance distance: Float,
  options options: LengthOptions,
) -> Result(PathParameter, Error) {
  case path.subpaths {
    [] -> Error(EmptyPath)
    subpaths -> {
      case nonempty_subpaths(subpaths) {
        [] -> Error(EmptySubpaths)
        _ -> {
          use length <- result.try(path_length_with(path, options:))
          use _ <- result.try(validate_length_distance(distance, length:))
          case distance == length {
            True -> path_end_parameter_at_length(subpaths, options)
            False ->
              path_parameter_at_valid_length_loop(
                subpaths,
                distance:,
                options:,
                index: 0,
              )
          }
        }
      }
    }
  }
}

/// Return the path point at a traveled distance from the path start.
pub fn path_point_at_length(
  path: Path,
  distance distance: Float,
) -> Result(Point, Error) {
  path_point_at_length_with(path, distance:, options: default_length_options())
}

/// Return the path point at a traveled distance using explicit options.
pub fn path_point_at_length_with(
  path: Path,
  distance distance: Float,
  options options: LengthOptions,
) -> Result(Point, Error) {
  use parameter <- result.try(path_parameter_at_length_with(
    path,
    distance:,
    options:,
  ))
  path_point(path, at: parameter)
}

/// Return the path derivative at a traveled distance from the path start.
pub fn path_derivative_at_length(
  path: Path,
  distance distance: Float,
) -> Result(Point, Error) {
  path_derivative_at_length_with(
    path,
    distance:,
    options: default_length_options(),
  )
}

/// Return the path derivative at a traveled distance using explicit options.
pub fn path_derivative_at_length_with(
  path: Path,
  distance distance: Float,
  options options: LengthOptions,
) -> Result(Point, Error) {
  use parameter <- result.try(path_parameter_at_length_with(
    path,
    distance:,
    options:,
  ))
  path_derivative(path, at: parameter)
}

/// Evaluate a path at a path parameter.
pub fn path_point(
  path: Path,
  at parameter: PathParameter,
) -> Result(Point, Error) {
  let PathParameter(subpath_index:, at:) = parameter
  use subpath <- result.try(nth_subpath(path.subpaths, subpath_index))
  subpath_point(subpath, at:)
}

/// Return a path's subpath derivative at a path parameter.
pub fn path_derivative(
  path: Path,
  at parameter: PathParameter,
) -> Result(Point, Error) {
  let PathParameter(subpath_index:, at:) = parameter
  use subpath <- result.try(nth_subpath(path.subpaths, subpath_index))
  subpath_derivative(subpath, at:)
}

/// Return singularity-safe unit traversal directions at a path parameter.
pub fn path_directions(
  path: Path,
  at parameter: PathParameter,
) -> Result(Directions, Error) {
  path_directions_with(
    path,
    at: parameter,
    options: default_direction_options(),
  )
}

/// Return singularity-safe unit traversal directions using explicit options.
pub fn path_directions_with(
  path: Path,
  at parameter: PathParameter,
  options options: DirectionOptions,
) -> Result(Directions, Error) {
  let PathParameter(subpath_index:, at:) = parameter
  use subpath <- result.try(nth_subpath(path.subpaths, subpath_index))
  subpath_directions_with(subpath, at:, options:)
}

/// Return the shortest distance from a point to a segment.
///
/// Lines are measured exactly. Quadratic Beziers, cubic Beziers, and arcs are
/// measured by finding stationary points of squared distance in `0.0..1.0`.
pub fn segment_distance(
  point: Point,
  to segment: Segment,
) -> Result(Float, Error) {
  segment_distance_with(point, to: segment, options: default_distance_options())
}

/// Return the shortest distance from a point to a segment using explicit options.
pub fn segment_distance_with(
  point: Point,
  to segment: Segment,
  options options: DistanceOptions,
) -> Result(Float, Error) {
  segment_projection_with(point, to: segment, options:)
  |> result.map(fn(projection) { projection.distance })
}

/// Return the nearest point on a segment to an input point.
pub fn segment_projection(
  point: Point,
  to segment: Segment,
) -> Result(SegmentProjection, Error) {
  segment_projection_with(
    point,
    to: segment,
    options: default_distance_options(),
  )
}

/// Return the nearest point on a segment to an input point using explicit options.
pub fn segment_projection_with(
  point: Point,
  to segment: Segment,
  options options: DistanceOptions,
) -> Result(SegmentProjection, Error) {
  use _ <- result.try(validate_distance_options(options))
  case segment {
    Line(start:, end:) -> Ok(point_to_line_projection(point, start, end))
    Arc(..) -> arc_projection_with(point, segment, options)
    QuadraticBezier(..) | CubicBezier(..) ->
      bezier_projection_with(point, segment, options)
  }
}

fn arc_projection_with(
  point: Point,
  segment: Segment,
  options: DistanceOptions,
) -> Result(SegmentProjection, Error) {
  use candidates <- result.try(arc_projection_candidates(
    point,
    segment,
    options,
    options.max_iterations,
  ))
  smallest_segment_projection(point, segment, candidates)
}

fn bezier_projection_with(
  point: Point,
  segment: Segment,
  options: DistanceOptions,
) -> Result(SegmentProjection, Error) {
  use coefficients <- result.try(distance_stationary_polynomial(point, segment))
  let polynomial_options =
    root.PolynomialOptions(
      coefficient_tolerance: 0.000000000001,
      root_tolerance: options.tolerance,
      value_tolerance: 0.000000000001,
      max_iterations: options.max_iterations,
    )
  use isolations <- result.try(
    root.polynomial_root_isolations_with(
      coefficients,
      from: 0.0,
      to: 1.0,
      options: polynomial_options,
    )
    |> result.map_error(distance_root_error),
  )
  use polished_roots <- result.try(
    isolations
    |> list.try_map(fn(isolation) {
      refine_isolated_distance_root_by_bisection(
        point,
        segment,
        options,
        isolation,
      )
    }),
  )
  smallest_segment_projection(point, segment, [0.0, 1.0, ..polished_roots])
}

/// Return the nearest point on a subpath to an input point.
pub fn subpath_projection(
  point: Point,
  to subpath: Subpath,
) -> Result(SubpathProjection, Error) {
  subpath_projection_with(
    point,
    to: subpath,
    options: default_distance_options(),
  )
}

/// Return the nearest point on a subpath to an input point using explicit options.
pub fn subpath_projection_with(
  point: Point,
  to subpath: Subpath,
  options options: DistanceOptions,
) -> Result(SubpathProjection, Error) {
  case validate_distance_options(options) {
    Error(error) -> Error(error)
    Ok(Nil) ->
      subpath_projection_loop(
        point,
        subpath.segments,
        options,
        index: 0,
        best: None,
      )
  }
}

/// Classify a point relative to a subpath's fill area.
///
/// Open and closed subpaths use the same fill geometry: an open subpath is
/// implicitly closed by a straight line from its end to its start. Move-only
/// subpaths have no fill area or boundary.
pub fn subpath_containment(
  point: Point,
  within subpath: Subpath,
  using fill_rule: FillRule,
) -> Result(PointContainment, Error) {
  subpath_containment_with(
    point,
    within: subpath,
    using: fill_rule,
    options: default_containment_options(),
  )
}

/// Classify a point relative to a subpath's fill area using explicit options.
///
/// `tolerance` is measured in path coordinate units and determines the width
/// classified as `Boundary`. `samples` and `max_iterations` control numerical
/// projection and adaptive line approximation for curves.
pub fn subpath_containment_with(
  point: Point,
  within subpath: Subpath,
  using fill_rule: FillRule,
  options options: ContainmentOptions,
) -> Result(PointContainment, Error) {
  use _ <- result.try(validate_containment_options(options))
  case subpath.segments {
    [] -> Ok(Outside)
    _ -> {
      use calculation <- result.try(subpath_containment_calculation(
        point,
        subpath,
        options,
      ))
      Ok(containment_from_calculation(calculation, fill_rule))
    }
  }
}

/// Classify a point relative to a path's combined fill area.
///
/// Winding and crossing counts are accumulated across all non-move-only
/// subpaths. Each open subpath is implicitly closed independently. A boundary
/// match on any subpath takes precedence. Empty and move-only paths are
/// `Outside`.
pub fn path_containment(
  point: Point,
  within path: Path,
  using fill_rule: FillRule,
) -> Result(PointContainment, Error) {
  path_containment_with(
    point,
    within: path,
    using: fill_rule,
    options: default_containment_options(),
  )
}

/// Classify a point relative to a path's combined fill area using explicit
/// options.
pub fn path_containment_with(
  point: Point,
  within path: Path,
  using fill_rule: FillRule,
  options options: ContainmentOptions,
) -> Result(PointContainment, Error) {
  use _ <- result.try(validate_containment_options(options))
  path_containment_loop(
    point,
    path.subpaths,
    fill_rule,
    options,
    winding: 0,
    crossings: 0,
  )
}

@internal
pub fn internal_path_containment_with_initial_ray_angle(
  point: Point,
  within path: Path,
  using fill_rule: FillRule,
  options options: ContainmentOptions,
  ray_angle ray_angle: Float,
) -> Result(PointContainment, Error) {
  use _ <- result.try(validate_containment_options(options))
  path_containment_with_initial_ray_angle_loop(
    point,
    path.subpaths,
    fill_rule,
    options,
    ray_angle:,
    winding: 0,
    crossings: 0,
  )
}

@internal
pub fn internal_subpath_winding_pair_for_ray_angle(
  point: Point,
  within subpath: Subpath,
  options options: ContainmentOptions,
  ray_angle ray_angle: Float,
) -> Result(#(Int, Int, Int, Int), Error) {
  let ray = containment_ray_for_angle(ray_angle)
  original_subpath_bidirectional_winding(point, subpath, ray, options:)
}

@internal
pub fn internal_subpath_segment_winding_contributions_for_ray_angle(
  point: Point,
  within subpath: Subpath,
  options options: ContainmentOptions,
  ray_angle ray_angle: Float,
) -> Result(List(#(Int, Int, Int)), Error) {
  let ray = containment_ray_for_angle(ray_angle)
  subpath_segment_winding_contributions_for_ray(
    point,
    subpath.segments,
    ray,
    options:,
    index: 0,
    contributions: [],
  )
}

fn subpath_segment_winding_contributions_for_ray(
  point: Point,
  segments: List(Segment),
  ray: ContainmentRay,
  options options: ContainmentOptions,
  index index: Int,
  contributions contributions: List(#(Int, Int, Int)),
) -> Result(List(#(Int, Int, Int)), Error) {
  case segments {
    [] -> Ok(list.reverse(contributions))
    [segment, ..rest] -> {
      use forward <- result.try(segment_winding_contribution(
        point,
        segment,
        ray,
        options:,
      ))
      use backward <- result.try(segment_winding_contribution(
        point,
        segment,
        containment_ray_opposite(ray),
        options:,
      ))
      subpath_segment_winding_contributions_for_ray(
        point,
        rest,
        ray,
        options:,
        index: index + 1,
        contributions: [#(index, forward, backward), ..contributions],
      )
    }
  }
}

@internal
pub fn internal_segment_ray_crossings_for_angle(
  segment: Segment,
  origin origin: Point,
  ray_angle ray_angle: Float,
  options options: ContainmentOptions,
) -> Result(#(List(#(Float, Float)), List(#(Float, Float))), Error) {
  let ray = containment_ray_for_angle(ray_angle)
  let crossing_options =
    CrossingOptions(
      samples: options.samples,
      signed_line_distance_tolerance: options.tolerance,
      max_iterations: options.max_iterations,
    )
  use forward <- result.try(segment_ray_crossings_with(
    segment,
    origin:,
    direction: ray.direction,
    options: crossing_options,
  ))
  use backward <- result.try(segment_ray_crossings_with(
    segment,
    origin:,
    direction: containment_ray_opposite(ray).direction,
    options: crossing_options,
  ))
  Ok(#(forward, backward))
}

@internal
pub fn internal_segment_line_crossing_breakpoint_values_for_angle(
  segment: Segment,
  origin origin: Point,
  ray_angle ray_angle: Float,
  options options: ContainmentOptions,
) -> Result(List(#(Float, Float)), Error) {
  let ray = containment_ray_for_angle(ray_angle)
  let normal = ray_supporting_line_normal(ray.direction)
  let tolerance =
    options.tolerance
    *. float_square_root(distance_squared(normal, Point(0.0, 0.0)))
  use breakpoints <- result.try(line_crossing_breakpoints(
    segment,
    normal,
    tolerance,
  ))
  let f = line_crossing_function(origin, normal)
  Ok(
    breakpoints
    |> list.map(fn(t) { #(t, crossing_value_unsafe(segment, f, t)) }),
  )
}

@internal
pub fn internal_segment_ray_crossing_contributions_for_angle(
  segment: Segment,
  origin origin: Point,
  ray_angle ray_angle: Float,
  options options: ContainmentOptions,
) -> Result(List(#(Float, Float, Int)), Error) {
  let ray = containment_ray_for_angle(ray_angle)
  let crossing_options =
    CrossingOptions(
      samples: options.samples,
      signed_line_distance_tolerance: options.tolerance,
      max_iterations: options.max_iterations,
    )
  use crossings <- result.try(segment_ray_crossings_with(
    segment,
    origin:,
    direction: ray.direction,
    options: crossing_options,
  ))
  segment_ray_crossing_contributions(
    segment,
    origin:,
    ray:,
    crossings:,
    contributions: [],
  )
}

@internal
pub fn internal_curved_crossing_probe_values_for_angle(
  segment: Segment,
  origin origin: Point,
  ray_angle ray_angle: Float,
  t t: Float,
  probe probe: Float,
) -> Result(#(Float, Float), Error) {
  let ray = containment_ray_for_angle(ray_angle)
  use before <- result.try(segment_point(
    segment,
    at: float.max(0.0, t -. probe),
  ))
  use after <- result.try(segment_point(segment, at: float.min(1.0, t +. probe)))
  Ok(#(
    containment_ray_crossing_value(origin, before, ray),
    containment_ray_crossing_value(origin, after, ray),
  ))
}

fn segment_ray_crossing_contributions(
  segment: Segment,
  origin origin: Point,
  ray ray: ContainmentRay,
  crossings crossings: List(#(Float, Float)),
  contributions contributions: List(#(Float, Float, Int)),
) -> Result(List(#(Float, Float, Int)), Error) {
  case crossings {
    [] -> Ok(list.reverse(contributions))
    [crossing, ..rest] -> {
      let #(t, ray_t) = crossing
      use contribution <- result.try(ray_crossing_contribution(
        origin,
        segment,
        ray,
        t,
        ray_t,
      ))
      segment_ray_crossing_contributions(
        segment,
        origin:,
        ray:,
        crossings: rest,
        contributions: [#(t, ray_t, contribution), ..contributions],
      )
    }
  }
}

fn ray_crossing_contribution(
  origin: Point,
  segment: Segment,
  ray: ContainmentRay,
  t: Float,
  ray_t: Float,
) -> Result(Int, Error) {
  case segment {
    Line(start:, end:) ->
      case ray_t >. 0.0 {
        True -> Ok(line_winding_contribution(origin, start, end, ray))
        False ->
          case ray_t <. 0.0 {
            True ->
              Ok(line_winding_contribution(
                origin,
                start,
                end,
                containment_ray_opposite(ray),
              ))
            False -> Ok(0)
          }
      }
    _ -> {
      case ray_t >. 0.0 {
        True -> curved_crossing_contribution(origin, segment, ray, t, ray_t)
        False ->
          case ray_t <. 0.0 {
            True ->
              curved_crossing_contribution(
                origin,
                segment,
                containment_ray_opposite(ray),
                t,
                0.0 -. ray_t,
              )
            False -> Ok(0)
          }
      }
    }
  }
}

fn path_containment_with_initial_ray_angle_loop(
  point: Point,
  subpaths: List(Subpath),
  fill_rule: FillRule,
  options: ContainmentOptions,
  ray_angle ray_angle: Float,
  winding winding: Int,
  crossings crossings: Int,
) -> Result(PointContainment, Error) {
  case subpaths {
    [] -> Ok(containment_from_winding(winding, crossings, fill_rule))
    [subpath, ..rest] -> {
      case subpath.segments {
        [] ->
          path_containment_with_initial_ray_angle_loop(
            point,
            rest,
            fill_rule,
            options,
            ray_angle:,
            winding:,
            crossings:,
          )
        _ -> {
          use calculation <- result.try(
            subpath_containment_calculation_with_initial_ray_angle(
              point,
              subpath,
              options,
              ray_angle:,
            ),
          )
          case calculation {
            CalculatedBoundary -> Ok(Boundary)
            CalculatedWinding(
              winding: subpath_winding,
              crossings: subpath_crossings,
            ) ->
              path_containment_with_initial_ray_angle_loop(
                point,
                rest,
                fill_rule,
                options,
                ray_angle:,
                winding: winding + subpath_winding,
                crossings: crossings + subpath_crossings,
              )
          }
        }
      }
    }
  }
}

/// Return the signed winding number of a path around a point.
///
/// Open subpaths are implicitly closed, matching `path_containment`. If the
/// point is within the boundary tolerance of any non-empty subpath, the result
/// is `BoundaryWinding` because the winding number is not numerically stable at
/// that point.
pub fn path_winding(
  point: Point,
  within path: Path,
) -> Result(PathWinding, Error) {
  path_winding_with(point, within: path, options: default_containment_options())
}

/// Return the signed winding number of a path around a point using explicit
/// containment options.
pub fn path_winding_with(
  point: Point,
  within path: Path,
  options options: ContainmentOptions,
) -> Result(PathWinding, Error) {
  use _ <- result.try(validate_containment_options(options))
  path_winding_loop(point, path.subpaths, options, winding: 0)
}

/// Return the shortest distance from a point to a subpath.
pub fn subpath_distance(
  point: Point,
  to subpath: Subpath,
) -> Result(Float, Error) {
  subpath_distance_with(point, to: subpath, options: default_distance_options())
}

/// Return the shortest distance from a point to a subpath using explicit
/// options.
pub fn subpath_distance_with(
  point: Point,
  to subpath: Subpath,
  options options: DistanceOptions,
) -> Result(Float, Error) {
  subpath_projection_with(point, to: subpath, options:)
  |> result.map(fn(projection) { projection.distance })
}

/// Return the shortest distance from a point to a path.
///
/// Move-only subpaths are skipped.
pub fn path_distance(point: Point, to path: Path) -> Result(Float, Error) {
  path_distance_with(point, to: path, options: default_distance_options())
}

/// Return the shortest distance from a point to a path using explicit options.
pub fn path_distance_with(
  point: Point,
  to path: Path,
  options options: DistanceOptions,
) -> Result(Float, Error) {
  path_projection_with(point, to: path, options:)
  |> result.map(fn(projection) { projection.distance })
}

/// Return the nearest point on a path to an input point.
///
/// Move-only subpaths are skipped. An empty path returns `EmptyPath`; a path
/// containing only move-only subpaths returns `EmptySubpaths`.
pub fn path_projection(
  point: Point,
  to path: Path,
) -> Result(PathProjection, Error) {
  path_projection_with(point, to: path, options: default_distance_options())
}

/// Return the nearest point on a path to an input point using explicit options.
pub fn path_projection_with(
  point: Point,
  to path: Path,
  options options: DistanceOptions,
) -> Result(PathProjection, Error) {
  case path.subpaths {
    [] -> Error(EmptyPath)
    subpaths -> {
      use _ <- result.try(validate_distance_options(options))
      path_projection_loop(point, subpaths, options, index: 0, best: None)
    }
  }
}

/// Return a non-empty subpath's exact axis-aligned bounding box.
pub fn subpath_bounding_box(subpath: Subpath) -> Result(BoundingBox, Error) {
  case subpath.segments {
    [] -> Error(EmptySubpath)
    [first, ..rest] -> {
      case segment_bounding_box(first) {
        Error(error) -> Error(error)
        Ok(box) -> combine_segment_bounding_boxes(rest, box)
      }
    }
  }
}

/// Return the exact axis-aligned bounding box of all non-empty subpaths.
pub fn path_bounding_box(path: Path) -> Result(BoundingBox, Error) {
  case path.subpaths {
    [] -> Error(EmptyPath)
    subpaths -> combine_subpath_bounding_boxes(subpaths, None)
  }
}

/// Map the defining points of a segment.
///
/// Lines, quadratic Beziers, and cubic Beziers are mapped by applying `f` to
/// their endpoints and control points. For nonlinear functions, this is not the
/// exact image of every point on the rendered curve. Arc segments return
/// `CannotMapArcNonlinearly` because an arbitrary nonlinear mapping does not
/// generally preserve SVG arc parameters.
pub fn segment_map_points(
  segment: Segment,
  with f: fn(Point) -> Point,
) -> Result(Segment, Error) {
  case segment {
    Line(..) | QuadraticBezier(..) | CubicBezier(..) -> {
      Ok(
        segment
        |> segment_to_bezier_data
        |> bezier.map_points(with: fn(point) {
          point |> from_bezier_point |> f |> to_bezier_point
        })
        |> segment_from_bezier_data,
      )
    }
    Arc(..) -> Error(CannotMapArcNonlinearly)
  }
}

/// Map the defining points of a segment with a fallible function.
///
/// This has the same geometry semantics as `segment_map_points`, but the
/// mapping function may reject individual points.
pub fn segment_try_map_points(
  segment: Segment,
  with f: fn(Point) -> Result(Point, error),
) -> Result(Segment, PointMapError(error)) {
  case segment {
    Line(..) | QuadraticBezier(..) | CubicBezier(..) -> {
      use mapped <- result.try(
        segment_to_bezier_data(segment)
        |> try_map_bezier_points(with: f),
      )
      Ok(segment_from_bezier_data(mapped))
    }
    Arc(..) -> Error(PointMapPathError(CannotMapArcNonlinearly))
  }
}

/// Split a segment at parameter `t`.
///
/// `t` is not clamped. Values outside `0.0..1.0` extrapolate along the same
/// segment.
pub fn segment_split(
  segment: Segment,
  at t: Float,
) -> Result(#(Segment, Segment), Error) {
  case segment {
    Line(..) | QuadraticBezier(..) | CubicBezier(..) ->
      split_segment(segment, at: t)
    Arc(..) -> split_arc_segment(segment, at: t)
  }
}

/// Split a segment at parameter `t`, returning an error outside `0.0..1.0`.
///
/// Values exactly at `0.0` or `1.0` are accepted and produce one zero-length
/// segment.
pub fn segment_split_inside(
  segment: Segment,
  at t: Float,
) -> Result(#(Segment, Segment), Error) {
  case segment {
    Line(..) | QuadraticBezier(..) | CubicBezier(..) -> {
      case split_segment_inside(segment, at: t) {
        Error(_) -> Error(SplitOutsideSegment)
        Ok(split) -> Ok(split)
      }
    }
    Arc(..) -> {
      case split_arc_segment_inside(segment, at: t) {
        Error(SplitOutsideSegment) -> Error(SplitOutsideSegment)
        Error(error) -> Error(error)
        Ok(split) -> Ok(split)
      }
    }
  }
}

/// Return the portion of a segment between two parameters.
///
/// `from` and `to` are not clamped. Values outside `0.0..1.0` extrapolate
/// along the same segment. If `from` is greater than `to`, the returned segment
/// traverses the interval in reverse.
pub fn segment_between(
  segment: Segment,
  from from: Float,
  to to: Float,
) -> Result(Segment, Error) {
  case from == to {
    True -> {
      case segment_point(segment, at: from) {
        Error(error) -> Error(error)
        Ok(point) -> Ok(Line(start: point, end: point))
      }
    }
    False -> {
      case from >. to {
        True -> {
          case segment_between(segment, from: to, to: from) {
            Error(error) -> Error(error)
            Ok(segment) -> Ok(segment_reverse(segment))
          }
        }
        False -> forward_segment_between(segment, from: from, to: to)
      }
    }
  }
}

/// Return the portion of a segment between two parameters.
///
/// `from` and `to` must be inside `0.0..1.0`, inclusive. If `from` is greater
/// than `to`, the returned segment traverses the interval in reverse.
pub fn segment_between_inside(
  segment: Segment,
  from from: Float,
  to to: Float,
) -> Result(Segment, Error) {
  case from <. 0.0 || from >. 1.0 || to <. 0.0 || to >. 1.0 {
    True -> Error(SplitOutsideSegment)
    False -> segment_between(segment, from: from, to: to)
  }
}

/// Return segment portions between adjacent parameters.
///
/// Parameters are not clamped. Values outside `0.0..1.0` extrapolate along the
/// same segment. Empty and singleton lists return an empty list.
pub fn segment_between_many(
  segment: Segment,
  between points: List(Float),
) -> Result(List(Segment), Error) {
  segments_between_loop(segment, points, [])
}

/// Return segment portions between adjacent parameters.
///
/// All parameters must be inside `0.0..1.0`, inclusive. Empty and singleton
/// lists return an empty list.
pub fn segment_between_many_inside(
  segment: Segment,
  between points: List(Float),
) -> Result(List(Segment), Error) {
  case all_inside(points) {
    False -> Error(SplitOutsideSegment)
    True -> segment_between_many(segment, between: points)
  }
}

fn segments_between_loop(
  segment: Segment,
  points: List(Float),
  segments: List(Segment),
) -> Result(List(Segment), Error) {
  case points {
    [] | [_] -> Ok(list.reverse(segments))
    [from, to, ..rest] -> {
      case segment_between(segment, from: from, to: to) {
        Error(error) -> Error(error)
        Ok(segment_between) ->
          segments_between_loop(segment, [to, ..rest], [
            segment_between,
            ..segments
          ])
      }
    }
  }
}

fn all_inside(points: List(Float)) -> Bool {
  case points {
    [] -> True
    [first, ..rest] -> first >=. 0.0 && first <=. 1.0 && all_inside(rest)
  }
}

fn forward_segment_between(
  segment: Segment,
  from from: Float,
  to to: Float,
) -> Result(Segment, Error) {
  case from == 1.0 {
    True -> {
      case
        segment_reverse(segment)
        |> forward_segment_between(from: 1.0 -. to, to: 0.0)
      {
        Error(error) -> Error(error)
        Ok(segment) -> Ok(segment_reverse(segment))
      }
    }
    False -> {
      let local_to = { to -. from } /. { 1.0 -. from }

      case segment_split(segment, at: from) {
        Error(error) -> Error(error)
        Ok(#(_, after_from)) -> {
          case segment_split(after_from, at: local_to) {
            Error(error) -> Error(error)
            Ok(#(between, _)) -> {
              case segment_point(segment, at: from) {
                Error(error) -> Error(error)
                Ok(start) -> {
                  case segment_point(segment, at: to) {
                    Error(error) -> Error(error)
                    Ok(end) -> {
                      Ok(segment_with_start_and_end(between, start, end))
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
}

fn is_zero_length_line(segment: Segment) -> Bool {
  case segment {
    Line(start:, end:) -> start == end
    _ -> False
  }
}

fn split_segment(
  segment: Segment,
  at t: Float,
) -> Result(#(Segment, Segment), Error) {
  let #(left, right) = segment_to_bezier_data(segment) |> bezier.split(at: t)
  let left = segment_from_bezier_data(left)
  let right = segment_from_bezier_data(right)

  assert_split_segment_preserves_endpoints(segment, left, right)
  Ok(#(left, right))
}

fn split_segment_inside(
  segment: Segment,
  at t: Float,
) -> Result(#(Segment, Segment), Error) {
  case segment_to_bezier_data(segment) |> bezier.split_inside(at: t) {
    Error(_) -> Error(SplitOutsideSegment)
    Ok(#(left, right)) -> {
      let left = segment_from_bezier_data(left)
      let right = segment_from_bezier_data(right)

      assert_split_segment_preserves_endpoints(segment, left, right)
      Ok(#(left, right))
    }
  }
}

fn split_arc_segment(
  segment: Segment,
  at t: Float,
) -> Result(#(Segment, Segment), Error) {
  use arc <- result.try(arc_center_data(segment))
  let #(left, right) = ellipse.split_arc(arc, at: t)
  let left = arc_from_center_data(left)
  let right = arc_from_center_data(right)
  let #(left, right) = arc_split_with_exact_endpoints(segment, left, right, t)

  assert_split_segment_preserves_endpoints(segment, left, right)
  Ok(#(left, right))
}

fn split_arc_segment_inside(
  segment: Segment,
  at t: Float,
) -> Result(#(Segment, Segment), Error) {
  case arc_center_data(segment) {
    Error(error) -> Error(error)
    Ok(arc) -> {
      case ellipse.split_arc_inside(arc, at: t) {
        Error(_) -> Error(SplitOutsideSegment)
        Ok(#(left, right)) -> {
          let left = arc_from_center_data(left)
          let right = arc_from_center_data(right)
          let #(left, right) =
            arc_split_with_exact_endpoints(segment, left, right, t)

          assert_split_segment_preserves_endpoints(segment, left, right)
          Ok(#(left, right))
        }
      }
    }
  }
}

fn assert_split_segment_preserves_endpoints(
  original: Segment,
  left: Segment,
  right: Segment,
) -> Nil {
  assert segment_start(left) == segment_start(original)
  assert segment_end(left) == segment_start(right)
  assert segment_end(right) == segment_end(original)
  Nil
}

fn arc_split_with_exact_endpoints(
  original: Segment,
  left: Segment,
  right: Segment,
  t: Float,
) -> #(Segment, Segment) {
  let left = segment_with_start(left, segment_start(original))
  let assert Ok(split) = segment_point(original, at: t)
  let left = segment_with_end(left, split)
  let right = segment_with_start(right, split)
  let right = segment_with_end(right, segment_end(original))
  #(left, right)
}

fn validate_direction_options(options: DirectionOptions) -> Result(Nil, Error) {
  case
    options.relative_tolerance >=. 0.0
    && number.is_finite(options.relative_tolerance)
  {
    True -> Ok(Nil)
    False ->
      Error(InvalidDirectionRelativeTolerance(options.relative_tolerance))
  }
}

fn segment_endpoint_direction(
  segment: Segment,
  incoming incoming: Bool,
  options options: DirectionOptions,
) -> Option(Point) {
  let candidates = case segment, incoming {
    Line(start:, end:), _ -> [point_difference(end, start)]
    QuadraticBezier(start:, control:, end:), False -> [
      point_difference(control, start),
      point_difference(end, start),
    ]
    QuadraticBezier(start:, control:, end:), True -> [
      point_difference(end, control),
      point_difference(end, start),
    ]
    CubicBezier(start:, control1:, control2:, end:), False -> [
      point_difference(control1, start),
      point_difference(control2, start),
      point_difference(end, start),
    ]
    CubicBezier(start:, control1:, control2:, end:), True -> [
      point_difference(end, control2),
      point_difference(end, control1),
      point_difference(end, start),
    ]
    Arc(..), _ -> []
  }
  direction_from_candidates(candidates, options)
}

fn direction_from_candidates(
  candidates: List(Point),
  options: DirectionOptions,
) -> Option(Point) {
  let scale_squared =
    candidates
    |> list.fold(0.0, fn(scale, candidate) {
      float.max(scale, dot(candidate, candidate))
    })
  let threshold_squared =
    options.relative_tolerance *. options.relative_tolerance *. scale_squared
  direction_from_candidates_loop(candidates, threshold_squared)
}

fn direction_from_candidates_loop(
  candidates: List(Point),
  threshold_squared: Float,
) -> Option(Point) {
  case candidates {
    [] -> None
    [candidate, ..rest] -> {
      let magnitude_squared = dot(candidate, candidate)
      case magnitude_squared >. threshold_squared {
        True ->
          Some(point_scale(
            candidate,
            1.0 /. float_square_root(magnitude_squared),
          ))
        False -> direction_from_candidates_loop(rest, threshold_squared)
      }
    }
  }
}

fn vector_direction(vector: Point) -> Option(Point) {
  let magnitude_squared = dot(vector, vector)
  case magnitude_squared >. 0.0 {
    True ->
      Some(point_scale(vector, 1.0 /. float_square_root(magnitude_squared)))
    False -> None
  }
}

fn point_scale(point: Point, factor: Float) -> Point {
  Point(point.x *. factor, point.y *. factor)
}

fn subpath_direction_from_segments(
  segments: List(Segment),
  from index: Int,
  step step: Int,
  remaining remaining: Int,
  closed closed: Bool,
  incoming incoming: Bool,
  options options: DirectionOptions,
) -> Result(Option(Point), Error) {
  let length = list.length(segments)
  case remaining <= 0 || length == 0 {
    True -> Ok(None)
    False -> {
      let normalized_index = case index < 0, index >= length, closed {
        True, _, True -> length - 1
        _, True, True -> 0
        _, _, _ -> index
      }
      case normalized_index < 0 || normalized_index >= length {
        True -> Ok(None)
        False -> {
          use segment <- result.try(nth_segment(segments, normalized_index))
          use directions <- result.try(segment_directions_with(
            segment,
            at: case incoming {
              True -> 1.0
              False -> 0.0
            },
            options:,
          ))
          let Directions(incoming: before, outgoing: after) = directions
          let direction = case incoming {
            True -> before
            False -> after
          }
          case direction {
            Some(_) -> Ok(direction)
            None ->
              subpath_direction_from_segments(
                segments,
                from: normalized_index + step,
                step:,
                remaining: remaining - 1,
                closed:,
                incoming:,
                options:,
              )
          }
        }
      }
    }
  }
}

fn validate_crossing_options(options: CrossingOptions) -> Result(Nil, Error) {
  case options.samples <= 0 {
    True -> Error(InvalidCrossingSamples(options.samples))
    False -> {
      case
        options.signed_line_distance_tolerance <=. 0.0
        || !number.is_finite(options.signed_line_distance_tolerance)
      {
        True ->
          Error(InvalidCrossingTolerance(options.signed_line_distance_tolerance))
        False -> {
          case options.max_iterations <= 0 {
            True -> Error(InvalidCrossingMaxIterations(options.max_iterations))
            False -> Ok(Nil)
          }
        }
      }
    }
  }
}

fn scan_crossings(
  segment: Segment,
  f: fn(Point) -> Float,
  options: CrossingOptions,
  index index: Int,
  previous_t previous_t: Float,
  previous_value previous_value: Float,
  crossings crossings: List(Float),
) -> Result(List(Float), Error) {
  case index > options.samples {
    True -> Ok(list.reverse(crossings))
    False -> {
      let next_t = int.to_float(index) /. int.to_float(options.samples)

      case crossing_value(segment, f, next_t) {
        Error(error) -> Error(error)
        Ok(next_value) -> {
          case
            crossing_for_window(
              segment,
              f,
              options,
              previous_t,
              previous_value,
              next_t,
              next_value,
            )
          {
            Error(error) -> Error(error)
            Ok(None) ->
              scan_crossings(
                segment,
                f,
                options,
                index: index + 1,
                previous_t: next_t,
                previous_value: next_value,
                crossings:,
              )
            Ok(Some(crossing)) ->
              scan_crossings(
                segment,
                f,
                options,
                index: index + 1,
                previous_t: next_t,
                previous_value: next_value,
                crossings: insert_near_unique(
                  crossings,
                  crossing,
                  options.signed_line_distance_tolerance,
                ),
              )
          }
        }
      }
    }
  }
}

fn validate_ray_crossing_direction(direction: Point) -> Result(Nil, Error) {
  case
    number.is_finite(direction.x)
    && number.is_finite(direction.y)
    && distance_squared(direction, Point(0.0, 0.0)) >. 0.0
  {
    True -> Ok(Nil)
    False -> Error(IndeterminateDirection)
  }
}

fn ray_supporting_line_normal(direction: Point) -> Point {
  Point(direction.y, 0.0 -. direction.x)
}

fn ray_parameters_for_crossings(
  segment: Segment,
  origin: Point,
  direction: Point,
  parameters: List(Float),
  crossings crossings: List(#(Float, Float)),
) -> Result(List(#(Float, Float)), Error) {
  case parameters {
    [] -> Ok(list.reverse(crossings))
    [segment_t, ..rest] -> {
      use point <- result.try(segment_point(segment, at: segment_t))
      let ray_t =
        dot(point_difference(point, origin), direction)
        /. distance_squared(direction, Point(0.0, 0.0))
      ray_parameters_for_crossings(segment, origin, direction, rest, crossings: [
        #(segment_t, ray_t),
        ..crossings
      ])
    }
  }
}

fn line_crossing_function(point: Point, normal: Point) -> fn(Point) -> Float {
  fn(candidate: Point) { point_difference(candidate, point) |> dot(normal) }
}

fn line_crossing_breakpoints(
  segment: Segment,
  normal: Point,
  tolerance: Float,
) -> Result(List(Float), Error) {
  use extrema <- result.try(segment_projection_extrema(segment, normal))

  Ok(
    [0.0, 1.0, ..extrema]
    |> list.filter(fn(t) { t >=. 0.0 && t <=. 1.0 })
    |> list.sort(by: float.compare)
    |> unique_near_sorted(tolerance, previous: None, unique: [])
    |> list.reverse,
  )
}

fn segment_line_classified_roots(
  segment: Segment,
  point: Point,
  normal: Point,
  signed_line_distance_tolerance: Float,
  max_iterations: Int,
) -> Result(List(root.ClassifiedRoot), Error) {
  let options =
    root.PolynomialOptions(
      coefficient_tolerance: signed_line_distance_tolerance,
      root_tolerance: 0.000000000001,
      value_tolerance: signed_line_distance_tolerance,
      max_iterations:,
    )
  case segment {
    Line(start:, end:) -> {
      root.real_linear_01_roots(
        line_crossing_linear_coefficient(start, end, normal),
        line_crossing_constant(start, point, normal),
        options:,
      )
      |> result.map_error(crossing_root_error)
    }
    QuadraticBezier(start:, control:, end:) -> {
      let #(a, b, c) =
        line_crossing_quadratic_coefficients(start, control, end, point, normal)
      root.real_quadratic_01_roots(a, b, c, options:)
      |> result.map_error(crossing_root_error)
    }
    CubicBezier(start:, control1:, control2:, end:) -> {
      let #(a, b, c, d) =
        line_crossing_cubic_coefficients(
          start,
          control1,
          control2,
          end,
          point,
          normal,
        )
      root.real_cubic_01_roots(a, b, c, d, options:)
      |> result.map_error(crossing_root_error)
    }
    Arc(..) ->
      arc_line_classified_roots(
        segment,
        point,
        normal,
        signed_line_distance_tolerance,
        max_iterations,
      )
  }
}

fn classified_root_estimates(
  roots: List(root.ClassifiedRoot),
  crossings crossings: List(Float),
) -> List(Float) {
  case roots {
    [] -> list.reverse(crossings)
    [
      root.ClassifiedRoot(isolation: root.RootIsolation(estimate:, ..), ..),
      ..rest
    ] -> classified_root_estimates(rest, crossings: [estimate, ..crossings])
  }
}

fn line_crossing_linear_coefficient(
  start: Point,
  end: Point,
  normal: Point,
) -> Float {
  dot(point_difference(end, start), normal)
}

fn line_crossing_constant(start: Point, point: Point, normal: Point) -> Float {
  dot(point_difference(start, point), normal)
}

fn line_crossing_quadratic_coefficients(
  start: Point,
  control: Point,
  end: Point,
  point: Point,
  normal: Point,
) -> #(Float, Float, Float) {
  let a =
    dot(start, normal) -. { 2.0 *. dot(control, normal) } +. dot(end, normal)
  let b = 2.0 *. { dot(control, normal) -. dot(start, normal) }
  let c = line_crossing_constant(start, point, normal)
  #(a, b, c)
}

fn line_crossing_cubic_coefficients(
  start: Point,
  control1: Point,
  control2: Point,
  end: Point,
  point: Point,
  normal: Point,
) -> #(Float, Float, Float, Float) {
  let a =
    0.0
    -. dot(start, normal)
    +. { 3.0 *. dot(control1, normal) }
    -. { 3.0 *. dot(control2, normal) }
    +. dot(end, normal)
  let b =
    3.0
    *. {
      dot(start, normal)
      -. { 2.0 *. dot(control1, normal) }
      +. dot(control2, normal)
    }
  let c = 3.0 *. { dot(control1, normal) -. dot(start, normal) }
  let d = line_crossing_constant(start, point, normal)
  #(a, b, c, d)
}

fn arc_line_classified_roots(
  segment: Segment,
  point: Point,
  normal: Point,
  signed_line_distance_tolerance: Float,
  _max_iterations: Int,
) -> Result(List(root.ClassifiedRoot), Error) {
  use arc <- result.try(arc_center_data(segment))
  let x_axis = arc_x_axis(arc)
  let y_axis = arc_y_axis(arc)
  let alpha = dot(normal, x_axis)
  let beta = dot(normal, y_axis)
  let constant =
    dot(point_difference(from_ellipse_point(arc.center), point), normal)
  let radius = float_square_root(alpha *. alpha +. beta *. beta)

  case radius <=. signed_line_distance_tolerance {
    True -> Ok([])
    False -> {
      let cosine = { 0.0 -. constant } /. radius
      let cosine_tolerance = signed_line_distance_tolerance /. radius
      case cosine <. -1.0 || cosine >. 1.0 {
        True -> {
          case float.absolute_value(cosine) <=. 1.0 +. cosine_tolerance {
            True ->
              arc_line_roots_from_angle(
                arc,
                phase: trig.atan2_degrees(beta, alpha),
                aperture: case cosine <. 0.0 {
                  True -> 180.0
                  False -> 0.0
                },
              )
            False -> Ok([])
          }
        }
        False -> {
          use aperture <- result.try(
            trig.acos_degrees(cosine)
            |> result.map_error(fn(_) {
              InvalidCrossingTolerance(signed_line_distance_tolerance)
            }),
          )
          arc_line_roots_from_angle(
            arc,
            phase: trig.atan2_degrees(beta, alpha),
            aperture:,
          )
        }
      }
      |> result.map(fn(roots) {
        roots
        |> list.map(fn(t) {
          root.ClassifiedRoot(
            isolation: root.RootIsolation(lower: t, estimate: t, upper: t),
            kind: root.Ambiguous,
          )
        })
      })
    }
  }
}

fn arc_line_roots_from_angle(
  arc: ellipse.CenterArcData,
  phase phase: Float,
  aperture aperture: Float,
) -> Result(List(Float), Error) {
  Ok(
    [phase +. aperture, phase -. aperture]
    |> list.filter(fn(angle) {
      arc_angle_in_sweep(angle, arc.start_angle, arc.delta_angle)
    })
    |> list.map(fn(angle) {
      arc_angle_progress(angle, arc.start_angle, arc.delta_angle)
      /. float.absolute_value(arc.delta_angle)
    })
    |> list.filter(fn(t) { t >=. 0.0 && t <=. 1.0 })
    |> list.sort(by: float.compare)
    |> unique_near_sorted(0.000000000001, previous: None, unique: [])
    |> list.reverse,
  )
}

fn arc_x_axis(arc: ellipse.CenterArcData) -> Point {
  Point(
    arc.radius.x *. trig.cos_degrees(arc.x_axis_rotation),
    arc.radius.x *. trig.sin_degrees(arc.x_axis_rotation),
  )
}

fn arc_y_axis(arc: ellipse.CenterArcData) -> Point {
  Point(
    0.0 -. arc.radius.y *. trig.sin_degrees(arc.x_axis_rotation),
    arc.radius.y *. trig.cos_degrees(arc.x_axis_rotation),
  )
}

fn arc_angle_in_sweep(
  angle: Float,
  start_angle: Float,
  delta_angle: Float,
) -> Bool {
  case delta_angle >=. 0.0 {
    True ->
      positive_remainder_degrees(angle -. start_angle)
      <=. delta_angle +. 0.000000001
    False ->
      positive_remainder_degrees(start_angle -. angle)
      <=. { 0.0 -. delta_angle } +. 0.000000001
  }
}

fn arc_angle_progress(
  angle: Float,
  start_angle: Float,
  delta_angle: Float,
) -> Float {
  case delta_angle >=. 0.0 {
    True -> positive_remainder_degrees(angle -. start_angle)
    False -> positive_remainder_degrees(start_angle -. angle)
  }
}

fn positive_remainder_degrees(angle: Float) -> Float {
  case angle <. 0.0 {
    True -> positive_remainder_degrees(angle +. 360.0)
    False -> {
      case angle >=. 360.0 {
        True -> positive_remainder_degrees(angle -. 360.0)
        False -> angle
      }
    }
  }
}

fn crossing_root_error(error: root.Error) -> Error {
  case error {
    root.InvalidTolerance(tolerance) -> InvalidCrossingTolerance(tolerance)
    root.InvalidMaxIterations(max_iterations) ->
      InvalidCrossingMaxIterations(max_iterations)
    root.MaxIterationsReached(estimate:, value:) ->
      CrossingMaxIterationsReached(estimate:, value:)
    root.NotBracketed(left:, left_value:, ..) ->
      CrossingMaxIterationsReached(estimate: left, value: left_value)
  }
}

fn segment_projection_extrema(
  segment: Segment,
  normal: Point,
) -> Result(List(Float), Error) {
  case segment {
    Line(..) | QuadraticBezier(..) | CubicBezier(..) -> {
      Ok(bezier.projection_extrema(
        segment_to_bezier_data(segment),
        direction: to_bezier_point(normal),
      ))
    }
    Arc(..) -> {
      use arc <- result.try(arc_center_data(segment))
      Ok(ellipse.arc_projection_extrema(
        arc,
        direction: to_ellipse_point(normal),
      ))
    }
  }
}

fn unique_near_sorted(
  values: List(Float),
  tolerance tolerance: Float,
  previous previous: Option(Float),
  unique unique: List(Float),
) -> List(Float) {
  case values {
    [] -> unique
    [value, ..rest] -> {
      case previous {
        Some(previous_value) -> {
          case float.absolute_value(value -. previous_value) <=. tolerance {
            True -> unique_near_sorted(rest, tolerance:, previous:, unique:)
            False ->
              unique_near_sorted(
                rest,
                tolerance:,
                previous: Some(value),
                unique: [value, ..unique],
              )
          }
        }
        _ ->
          unique_near_sorted(rest, tolerance:, previous: Some(value), unique: [
            value,
            ..unique
          ])
      }
    }
  }
}

fn crossing_for_window(
  segment: Segment,
  f: fn(Point) -> Float,
  options: CrossingOptions,
  previous_t: Float,
  previous_value: Float,
  next_t: Float,
  next_value: Float,
) -> Result(Option(Float), Error) {
  case previous_value == 0.0 {
    True -> Ok(Some(previous_t))
    False -> {
      case next_value == 0.0 {
        True -> Ok(Some(next_t))
        False -> {
          case same_sign(previous_value, next_value) {
            True -> Ok(None)
            False ->
              refine_crossing(
                segment,
                f,
                options,
                options.signed_line_distance_tolerance,
                previous_t,
                next_t,
              )
          }
        }
      }
    }
  }
}

fn refine_crossing(
  segment: Segment,
  f: fn(Point) -> Float,
  options: CrossingOptions,
  signed_line_distance_tolerance: Float,
  previous_t: Float,
  next_t: Float,
) -> Result(Option(Float), Error) {
  let previous_value = crossing_value_unsafe(segment, f, previous_t)
  let next_value = crossing_value_unsafe(segment, f, next_t)

  case float.absolute_value(previous_value) <=. signed_line_distance_tolerance {
    True -> Ok(Some(previous_t))
    False -> {
      case float.absolute_value(next_value) <=. signed_line_distance_tolerance {
        True -> Ok(Some(next_t))
        False ->
          refine_crossing_loop(
            segment,
            f,
            left_t: previous_t,
            left_value: previous_value,
            right_t: next_t,
            tolerance: signed_line_distance_tolerance,
            remaining_iterations: options.max_iterations,
          )
      }
    }
  }
}

fn refine_crossing_loop(
  segment: Segment,
  f: fn(Point) -> Float,
  left_t left_t: Float,
  left_value left_value: Float,
  right_t right_t: Float,
  tolerance tolerance: Float,
  remaining_iterations remaining_iterations: Int,
) -> Result(Option(Float), Error) {
  let midpoint = left_t +. { right_t -. left_t } /. 2.0
  let midpoint_value = crossing_value_unsafe(segment, f, midpoint)

  case float.absolute_value(midpoint_value) <=. tolerance {
    True -> Ok(Some(midpoint))
    False -> {
      case
        remaining_iterations <= 1 || midpoint == left_t || midpoint == right_t
      {
        True ->
          Error(CrossingMaxIterationsReached(
            estimate: midpoint,
            value: midpoint_value,
          ))
        False -> {
          case same_sign(left_value, midpoint_value) {
            True ->
              refine_crossing_loop(
                segment,
                f,
                left_t: midpoint,
                left_value: midpoint_value,
                right_t:,
                tolerance:,
                remaining_iterations: remaining_iterations - 1,
              )
            False ->
              refine_crossing_loop(
                segment,
                f,
                left_t:,
                left_value:,
                right_t: midpoint,
                tolerance:,
                remaining_iterations: remaining_iterations - 1,
              )
          }
        }
      }
    }
  }
}

fn crossing_value(
  segment: Segment,
  f: fn(Point) -> Float,
  t: Float,
) -> Result(Float, Error) {
  case segment_point(segment, at: t) {
    Error(error) -> Error(error)
    Ok(point) -> Ok(f(point))
  }
}

fn crossing_value_unsafe(
  segment: Segment,
  f: fn(Point) -> Float,
  t: Float,
) -> Float {
  let assert Ok(value) = crossing_value(segment, f, t)

  value
}

fn insert_near_unique(
  values: List(Float),
  value: Float,
  tolerance: Float,
) -> List(Float) {
  case values {
    [previous, ..] -> {
      case float.absolute_value(previous -. value) <=. tolerance {
        True -> values
        False -> [value, ..values]
      }
    }
    _ -> [value, ..values]
  }
}

fn is_close_to_zero(value: Float, tolerance: Float) -> Bool {
  float.absolute_value(value) <=. tolerance
}

fn same_sign(a: Float, b: Float) -> Bool {
  a <. 0.0 && b <. 0.0 || a >. 0.0 && b >. 0.0
}

fn validate_minimize_options(options: MinimizeOptions) -> Result(Nil, Error) {
  case options.samples <= 0 {
    True -> Error(InvalidMinimizeSamples(options.samples))
    False -> {
      case
        options.parameter_tolerance <=. 0.0
        || !number.is_finite(options.parameter_tolerance)
      {
        True -> Error(InvalidMinimizeTolerance(options.parameter_tolerance))
        False -> {
          case options.max_iterations <= 0 {
            True -> Error(InvalidMinimizeMaxIterations(options.max_iterations))
            False -> Ok(Nil)
          }
        }
      }
    }
  }
}

fn scan_minimize_windows(
  segment: Segment,
  f: fn(Point) -> Float,
  options: MinimizeOptions,
  index index: Int,
  previous_t previous_t: Float,
  best best: MinimizeCandidate,
) -> Result(MinimizeCandidate, Error) {
  case index > options.samples {
    True -> Ok(best)
    False -> {
      let next_t = int.to_float(index) /. int.to_float(options.samples)

      case minimize_value(segment, f, next_t) {
        Error(error) -> Error(error)
        Ok(next) -> {
          case
            golden_section_minimize(
              segment,
              f,
              left: previous_t,
              right: next_t,
              options:,
            )
          {
            Error(error) -> Error(error)
            Ok(window_best) ->
              scan_minimize_windows(
                segment,
                f,
                options,
                index: index + 1,
                previous_t: next_t,
                best: best_candidate(best, next) |> best_candidate(window_best),
              )
          }
        }
      }
    }
  }
}

fn golden_section_minimize(
  segment: Segment,
  f: fn(Point) -> Float,
  left left: Float,
  right right: Float,
  options options: MinimizeOptions,
) -> Result(MinimizeCandidate, Error) {
  let span = right -. left
  let inner_left = right -. golden_section_ratio *. span
  let inner_right = left +. golden_section_ratio *. span

  case minimize_value(segment, f, inner_left) {
    Error(error) -> Error(error)
    Ok(left_candidate) -> {
      case minimize_value(segment, f, inner_right) {
        Error(error) -> Error(error)
        Ok(right_candidate) ->
          golden_section_loop(
            segment,
            f,
            left:,
            right:,
            inner_left:,
            inner_left_candidate: left_candidate,
            inner_right:,
            inner_right_candidate: right_candidate,
            tolerance: options.parameter_tolerance,
            remaining_iterations: options.max_iterations,
          )
      }
    }
  }
}

fn golden_section_loop(
  segment: Segment,
  f: fn(Point) -> Float,
  left left: Float,
  right right: Float,
  inner_left inner_left: Float,
  inner_left_candidate inner_left_candidate: MinimizeCandidate,
  inner_right inner_right: Float,
  inner_right_candidate inner_right_candidate: MinimizeCandidate,
  tolerance tolerance: Float,
  remaining_iterations remaining_iterations: Int,
) -> Result(MinimizeCandidate, Error) {
  case right -. left <=. tolerance {
    True -> Ok(best_candidate(inner_left_candidate, inner_right_candidate))
    False -> {
      case remaining_iterations <= 0 {
        True -> {
          let best = best_candidate(inner_left_candidate, inner_right_candidate)

          Error(MinimizeMaxIterationsReached(best.t, best.value))
        }
        False -> {
          case inner_left_candidate.value <. inner_right_candidate.value {
            True -> {
              let next_right = inner_right
              let next_inner_right = inner_left
              let next_inner_right_candidate = inner_left_candidate
              let next_inner_left =
                next_right -. golden_section_ratio *. { next_right -. left }

              case minimize_value(segment, f, next_inner_left) {
                Error(error) -> Error(error)
                Ok(next_inner_left_candidate) ->
                  golden_section_loop(
                    segment,
                    f,
                    left:,
                    right: next_right,
                    inner_left: next_inner_left,
                    inner_left_candidate: next_inner_left_candidate,
                    inner_right: next_inner_right,
                    inner_right_candidate: next_inner_right_candidate,
                    tolerance:,
                    remaining_iterations: remaining_iterations - 1,
                  )
              }
            }
            False -> {
              let next_left = inner_left
              let next_inner_left = inner_right
              let next_inner_left_candidate = inner_right_candidate
              let next_inner_right =
                next_left +. golden_section_ratio *. { right -. next_left }

              case minimize_value(segment, f, next_inner_right) {
                Error(error) -> Error(error)
                Ok(next_inner_right_candidate) ->
                  golden_section_loop(
                    segment,
                    f,
                    left: next_left,
                    right:,
                    inner_left: next_inner_left,
                    inner_left_candidate: next_inner_left_candidate,
                    inner_right: next_inner_right,
                    inner_right_candidate: next_inner_right_candidate,
                    tolerance:,
                    remaining_iterations: remaining_iterations - 1,
                  )
              }
            }
          }
        }
      }
    }
  }
}

fn minimize_value(
  segment: Segment,
  f: fn(Point) -> Float,
  t: Float,
) -> Result(MinimizeCandidate, Error) {
  case segment_point(segment, at: t) {
    Error(error) -> Error(error)
    Ok(point) -> Ok(MinimizeCandidate(t:, value: f(point)))
  }
}

fn best_candidate(
  a: MinimizeCandidate,
  b: MinimizeCandidate,
) -> MinimizeCandidate {
  case a.value <=. b.value {
    True -> a
    False -> b
  }
}

fn validate_distance_options(options: DistanceOptions) -> Result(Nil, Error) {
  case options.samples <= 0 {
    True -> Error(InvalidDistanceSamples(options.samples))
    False -> {
      case options.tolerance <=. 0.0 || !number.is_finite(options.tolerance) {
        True -> Error(InvalidDistanceTolerance(options.tolerance))
        False -> {
          case options.max_iterations <= 0 {
            True -> Error(InvalidDistanceMaxIterations(options.max_iterations))
            False -> Ok(Nil)
          }
        }
      }
    }
  }
}

@internal
pub fn validate_containment_options(
  options: ContainmentOptions,
) -> Result(Nil, Error) {
  case options.tolerance <=. 0.0 || !number.is_finite(options.tolerance) {
    True -> Error(InvalidContainmentTolerance(options.tolerance))
    False -> {
      case options.samples <= 0 {
        True -> Error(InvalidContainmentSamples(options.samples))
        False -> {
          case options.max_iterations <= 0 {
            True ->
              Error(InvalidContainmentMaxIterations(options.max_iterations))
            False ->
              validate_containment_ray_angles(options.fallback_ray_angles)
          }
        }
      }
    }
  }
}

fn validate_containment_ray_angles(angles: List(Float)) -> Result(Nil, Error) {
  case angles {
    [] -> Ok(Nil)
    [angle, ..rest] -> {
      case number.is_finite(angle) {
        True -> validate_containment_ray_angles(rest)
        False -> Error(InvalidContainmentRayAngle(angle))
      }
    }
  }
}

@internal
pub fn validate_length_options(options: LengthOptions) -> Result(Nil, Error) {
  case options.tolerance <=. 0.0 || !number.is_finite(options.tolerance) {
    True -> Error(InvalidLengthTolerance(options.tolerance))
    False -> {
      case options.max_depth <= 0 {
        True -> Error(InvalidLengthMaxDepth(options.max_depth))
        False -> Ok(Nil)
      }
    }
  }
}

fn validate_subdivision_max_length(max_length: Float) -> Result(Nil, Error) {
  case max_length <=. 0.0 || !number.is_finite(max_length) {
    True -> Error(InvalidSubdivisionMaxLength(max_length))
    False -> Ok(Nil)
  }
}

fn validate_parametric_options(
  options: ParametricOptions,
) -> Result(Nil, Error) {
  case options.tolerance <=. 0.0 || !number.is_finite(options.tolerance) {
    True -> Error(InvalidParametricTolerance(options.tolerance))
    False -> {
      case options.samples_per_piece < 2 {
        True ->
          Error(InvalidParametricSamplesPerPiece(options.samples_per_piece))
        False -> {
          case options.initial_piece_count <= 0 {
            True ->
              Error(InvalidParametricInitialPieceCount(
                options.initial_piece_count,
              ))
            False -> {
              case options.max_depth < 0 {
                True -> Error(InvalidParametricMaxDepth(options.max_depth))
                False -> Ok(Nil)
              }
            }
          }
        }
      }
    }
  }
}

fn validate_parametric_interval(
  start: Float,
  end: Float,
) -> Result(Nil, Error) {
  case start == end || !number.is_finite(start) || !number.is_finite(end) {
    True -> Error(InvalidParametricInterval(start:, end:))
    False -> Ok(Nil)
  }
}

fn parametric_initial_segments(
  start: Float,
  end: Float,
  point_function: fn(Float) -> Point,
  options: ParametricOptions,
  index index: Int,
  segments segments: List(Segment),
) -> Result(List(Segment), Error) {
  case index >= options.initial_piece_count {
    True -> Ok(list.reverse(segments))
    False -> {
      let piece_start =
        interpolate_float(
          start,
          end,
          int.to_float(index) /. int.to_float(options.initial_piece_count),
        )
      let piece_end =
        interpolate_float(
          start,
          end,
          int.to_float(index + 1) /. int.to_float(options.initial_piece_count),
        )
      use piece <- result.try(parametric_interval_segments(
        piece_start,
        piece_end,
        point_function,
        options,
        depth_remaining: options.max_depth,
      ))
      parametric_initial_segments(
        start,
        end,
        point_function,
        options,
        index: index + 1,
        segments: list.reverse(piece) |> list.append(segments),
      )
    }
  }
}

fn parametric_interval_segments(
  start: Float,
  end: Float,
  point_function: fn(Float) -> Point,
  options: ParametricOptions,
  depth_remaining depth_remaining: Int,
) -> Result(List(Segment), Error) {
  use fit <- result.try(parametric_fit_cubic(
    start,
    end,
    point_function,
    options,
  ))
  let #(segment, error) = fit
  case error <=. options.tolerance {
    True -> Ok([segment])
    False -> {
      case depth_remaining <= 0 {
        True -> Error(ParametricMaxDepthReached(error))
        False -> {
          let middle = interpolate_float(start, end, 0.5)
          use left <- result.try(parametric_interval_segments(
            start,
            middle,
            point_function,
            options,
            depth_remaining: depth_remaining - 1,
          ))
          use right <- result.try(parametric_interval_segments(
            middle,
            end,
            point_function,
            options,
            depth_remaining: depth_remaining - 1,
          ))
          Ok(list.append(left, right))
        }
      }
    }
  }
}

fn parametric_fit_cubic(
  start: Float,
  end: Float,
  point_function: fn(Float) -> Point,
  options: ParametricOptions,
) -> Result(#(Segment, Float), Error) {
  use start_point <- result.try(parametric_point(point_function, start))
  use end_point <- result.try(parametric_point(point_function, end))
  use samples <- result.try(
    parametric_samples(
      point_function,
      start,
      end,
      options.samples_per_piece,
      index: 1,
      samples: [],
    ),
  )
  use fit <- result.try(case options.tangent {
    None ->
      bezier.fit_cubic_with_endpoints(
        start: to_bezier_point(start_point),
        end: to_bezier_point(end_point),
        samples:,
      )
      |> result.map_error(fn(_) { ParametricFitFailed })
    Some(tangent_function) -> {
      use start_tangent <- result.try(parametric_tangent(
        tangent_function,
        start,
      ))
      use end_tangent <- result.try(parametric_tangent(tangent_function, end))
      bezier.fit_cubic_with_endpoint_tangents(
        start: to_bezier_point(start_point),
        end: to_bezier_point(end_point),
        start_tangent: to_bezier_point(start_tangent),
        end_tangent: to_bezier_point(end_tangent),
        samples:,
      )
      |> result.map_error(fn(_) { ParametricFitFailed })
    }
  })
  let #(curve, fit_error) = fit
  use segment <- result.try(parametric_cubic_segment(curve))
  Ok(#(segment, fit_error.max))
}

fn parametric_samples(
  point_function: fn(Float) -> Point,
  start: Float,
  end: Float,
  count: Int,
  index index: Int,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(List(#(Float, bezier.BezierPoint)), Error) {
  case index > count {
    True -> Ok(list.reverse(samples))
    False -> {
      let t = int.to_float(index) /. int.to_float(count + 1)
      let parameter = interpolate_float(start, end, t)
      use point <- result.try(parametric_point(point_function, parameter))
      parametric_samples(
        point_function,
        start,
        end,
        count,
        index: index + 1,
        samples: [#(t, to_bezier_point(point)), ..samples],
      )
    }
  }
}

fn parametric_point(
  point_function: fn(Float) -> Point,
  parameter: Float,
) -> Result(Point, Error) {
  let point = point_function(parameter)
  case finite_point(point) {
    True -> Ok(point)
    False -> Error(NonFiniteParametricPoint(parameter:, point:))
  }
}

fn parametric_tangent(
  tangent_function: fn(Float) -> Point,
  parameter: Float,
) -> Result(Point, Error) {
  let tangent = tangent_function(parameter)
  case finite_point(tangent) {
    True -> Ok(tangent)
    False -> Error(NonFiniteParametricTangent(parameter:, tangent:))
  }
}

fn parametric_cubic_segment(
  curve: bezier.BezierData,
) -> Result(Segment, Error) {
  case curve {
    bezier.CubicBezierData(start:, control1:, control2:, end:) -> {
      let segment =
        CubicBezier(
          start: from_bezier_point(start),
          control1: from_bezier_point(control1),
          control2: from_bezier_point(control2),
          end: from_bezier_point(end),
        )
      case
        [segment.start, segment.control1, segment.control2, segment.end]
        |> list.all(finite_point)
      {
        True -> Ok(segment)
        False -> Error(ParametricFitFailed)
      }
    }
    _ -> Error(ParametricFitFailed)
  }
}

fn validate_zero_length_tolerance(tolerance: Float) -> Result(Nil, Error) {
  case tolerance <. 0.0 || !number.is_finite(tolerance) {
    True -> Error(InvalidZeroLengthTolerance(tolerance))
    False -> Ok(Nil)
  }
}

fn finite_point(point: Point) -> Bool {
  number.is_finite(point.x) && number.is_finite(point.y)
}

fn subdivision_distances(
  length: Float,
  piece_count: Int,
  step: Float,
) -> List(Float) {
  subdivision_distances_loop(length, piece_count, step, index: 0, distances: [])
}

fn subdivision_distances_loop(
  length: Float,
  piece_count: Int,
  step: Float,
  index index: Int,
  distances distances: List(Float),
) -> List(Float) {
  case index > piece_count {
    True -> list.reverse(distances)
    False -> {
      let distance = case index == piece_count {
        True -> length
        False -> int.to_float(index) *. step
      }
      subdivision_distances_loop(
        length,
        piece_count,
        step,
        index: index + 1,
        distances: [distance, ..distances],
      )
    }
  }
}

fn subdivide_segments_to_max_length(
  segments: List(Segment),
  max_length: Float,
  options: LengthOptions,
  subdivided subdivided: List(Segment),
) -> Result(List(Segment), Error) {
  case segments {
    [] -> Ok(list.reverse(subdivided))
    [first, ..rest] -> {
      use pieces <- result.try(segment_subdivide_to_max_length_with(
        first,
        max_length:,
        options:,
      ))
      subdivide_segments_to_max_length(
        rest,
        max_length,
        options,
        subdivided: list.append(list.reverse(pieces), subdivided),
      )
    }
  }
}

fn subdivide_subpaths_to_max_length(
  subpaths: List(Subpath),
  max_length: Float,
  options: LengthOptions,
  subdivided subdivided: List(Subpath),
) -> Result(List(Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(subdivided))
    [first, ..rest] -> {
      use subpath <- result.try(subpath_subdivide_to_max_length_with(
        first,
        max_length:,
        options:,
      ))
      subdivide_subpaths_to_max_length(rest, max_length, options, subdivided: [
        subpath,
        ..subdivided
      ])
    }
  }
}

fn validate_linearize_options(options: LinearizeOptions) -> Result(Nil, Error) {
  case options.tolerance <=. 0.0 || !number.is_finite(options.tolerance) {
    True -> Error(InvalidLinearizeTolerance(options.tolerance))
    False -> {
      case options.max_depth <= 0 {
        True -> Error(InvalidLinearizeMaxDepth(options.max_depth))
        False -> Ok(Nil)
      }
    }
  }
}

fn validate_length_distance(
  distance distance: Float,
  length length: Float,
) -> Result(Nil, Error) {
  case distance <. 0.0 || distance >. length {
    True -> Error(InvalidLengthDistance(distance:, length:))
    False -> Ok(Nil)
  }
}

fn segment_parameter_at_known_length(
  segment: Segment,
  distance: Float,
  length: Float,
  options: LengthOptions,
) -> Result(Float, Error) {
  use _ <- result.try(validate_length_distance(distance, length:))
  segment_parameter_at_valid_length(segment, distance, length, options)
}

fn subpath_parameter_at_known_length(
  subpath: Subpath,
  distance: Float,
  length: Float,
  options: LengthOptions,
) -> Result(SubpathParameter, Error) {
  case subpath.segments {
    [] -> Error(EmptySubpath)
    _ -> {
      use _ <- result.try(validate_length_distance(distance, length:))
      case distance == 0.0 {
        True -> Ok(SubpathParameter(segment_index: 0, t: 0.0))
        False ->
          case distance == length {
            True ->
              Ok(
                canonical_to_subpath_parameter(
                  subpath_end_parameter(list.length(subpath.segments)),
                ),
              )
            False ->
              subpath_parameter_at_valid_length_loop(
                subpath.segments,
                distance:,
                options:,
                index: 0,
              )
          }
      }
    }
  }
}

fn segment_parameters_at_known_lengths(
  segment: Segment,
  distances: List(Float),
  length: Float,
  options: LengthOptions,
  parameters: List(Float),
) -> Result(List(Float), Error) {
  case distances {
    [] -> Ok(list.reverse(parameters))
    [distance, ..rest] -> {
      use parameter <- result.try(segment_parameter_at_known_length(
        segment,
        distance,
        length,
        options,
      ))
      segment_parameters_at_known_lengths(segment, rest, length, options, [
        parameter,
        ..parameters
      ])
    }
  }
}

fn subpath_parameters_at_known_lengths(
  subpath: Subpath,
  distances: List(Float),
  length: Float,
  options: LengthOptions,
  parameters: List(SubpathParameter),
) -> Result(List(SubpathParameter), Error) {
  case distances {
    [] -> Ok(list.reverse(parameters))
    [distance, ..rest] -> {
      use parameter <- result.try(subpath_parameter_at_known_length(
        subpath,
        distance,
        length,
        options,
      ))
      subpath_parameters_at_known_lengths(subpath, rest, length, options, [
        parameter,
        ..parameters
      ])
    }
  }
}

fn segment_parameter_at_valid_length(
  segment: Segment,
  distance distance: Float,
  length length: Float,
  options options: LengthOptions,
) -> Result(Float, Error) {
  case distance == 0.0 {
    True -> Ok(0.0)
    False ->
      case distance == length {
        True -> Ok(1.0)
        False ->
          case segment {
            Line(..) -> Ok(distance /. length)
            QuadraticBezier(..) | CubicBezier(..) | Arc(..) ->
              segment_parameter_at_valid_length_loop(
                segment,
                distance:,
                options:,
                low: 0.0,
                high: 1.0,
                iterations: 64,
              )
          }
      }
  }
}

fn segment_parameter_at_valid_length_loop(
  segment: Segment,
  distance distance: Float,
  options options: LengthOptions,
  low low: Float,
  high high: Float,
  iterations iterations: Int,
) -> Result(Float, Error) {
  let t = { low +. high } /. 2.0
  use length <- result.try(adaptive_segment_length_between(
    segment,
    from: 0.0,
    to: t,
    options:,
  ))

  case
    float.absolute_value(length -. distance) <=. options.tolerance
    || iterations <= 0
  {
    True -> Ok(t)
    False ->
      case length <. distance {
        True ->
          segment_parameter_at_valid_length_loop(
            segment,
            distance:,
            options:,
            low: t,
            high:,
            iterations: iterations - 1,
          )
        False ->
          segment_parameter_at_valid_length_loop(
            segment,
            distance:,
            options:,
            low:,
            high: t,
            iterations: iterations - 1,
          )
      }
  }
}

fn adaptive_segment_length(
  segment: Segment,
  options: LengthOptions,
) -> Result(Float, Error) {
  adaptive_segment_length_between(segment, from: 0.0, to: 1.0, options:)
}

fn adaptive_segment_length_between(
  segment: Segment,
  from from: Float,
  to to: Float,
  options options: LengthOptions,
) -> Result(Float, Error) {
  use whole <- result.try(length_simpson(segment, from:, to:))
  adaptive_segment_length_loop(
    segment,
    from:,
    to:,
    whole:,
    tolerance: options.tolerance,
    depth: options.max_depth,
  )
}

fn adaptive_segment_length_loop(
  segment: Segment,
  from from: Float,
  to to: Float,
  whole whole: Float,
  tolerance tolerance: Float,
  depth depth: Int,
) -> Result(Float, Error) {
  let middle = { from +. to } /. 2.0
  use left <- result.try(length_simpson(segment, from:, to: middle))
  use right <- result.try(length_simpson(segment, from: middle, to:))
  let estimate = left +. right
  let error = float.absolute_value(estimate -. whole)

  case error <=. 15.0 *. tolerance {
    True -> Ok(estimate +. { estimate -. whole } /. 15.0)
    False -> {
      case depth <= 1 {
        True -> Error(LengthMaxDepthReached(estimate: estimate, error:))
        False -> {
          use refined_left <- result.try(adaptive_segment_length_loop(
            segment,
            from:,
            to: middle,
            whole: left,
            tolerance: tolerance /. 2.0,
            depth: depth - 1,
          ))
          use refined_right <- result.try(adaptive_segment_length_loop(
            segment,
            from: middle,
            to:,
            whole: right,
            tolerance: tolerance /. 2.0,
            depth: depth - 1,
          ))

          Ok(refined_left +. refined_right)
        }
      }
    }
  }
}

fn length_simpson(
  segment: Segment,
  from from: Float,
  to to: Float,
) -> Result(Float, Error) {
  let middle = { from +. to } /. 2.0
  use start <- result.try(segment_speed(segment, at: from))
  use mid <- result.try(segment_speed(segment, at: middle))
  use end <- result.try(segment_speed(segment, at: to))

  Ok({ to -. from } *. { start +. 4.0 *. mid +. end } /. 6.0)
}

fn segment_speed(segment: Segment, at t: Float) -> Result(Float, Error) {
  case segment_derivative(segment, at: t) {
    Error(error) -> Error(error)
    Ok(derivative) -> distance(Point(0.0, 0.0), derivative) |> Ok
  }
}

fn subpath_length_loop(
  segments: List(Segment),
  options: LengthOptions,
  total total: Float,
) -> Result(Float, Error) {
  case segments {
    [] -> Ok(total)
    [first, ..rest] -> {
      use length <- result.try(segment_length_with(first, options:))
      subpath_length_loop(rest, options, total: total +. length)
    }
  }
}

fn path_length_loop(
  subpaths: List(Subpath),
  options: LengthOptions,
  total total: Float,
) -> Result(Float, Error) {
  case subpaths {
    [] -> Ok(total)
    [first, ..rest] -> {
      use length <- result.try(subpath_length_with(first, options:))
      path_length_loop(rest, options, total: total +. length)
    }
  }
}

fn subpath_segments_are_zero_length(
  segments: List(Segment),
  tolerance: Float,
) -> Result(Bool, Error) {
  case segments {
    [] -> Ok(True)
    [first, ..rest] -> {
      use zero <- result.try(segment_is_zero_length(first, tolerance:))
      case zero {
        False -> Ok(False)
        True -> subpath_segments_are_zero_length(rest, tolerance)
      }
    }
  }
}

fn subpath_parameter_at_valid_length_loop(
  segments: List(Segment),
  distance distance: Float,
  options options: LengthOptions,
  index index: Int,
) -> Result(SubpathParameter, Error) {
  case segments {
    [] -> Error(EmptySubpath)
    [first, ..rest] -> {
      use length <- result.try(segment_length_with(first, options:))
      case distance <=. length {
        True -> {
          use t <- result.try(segment_parameter_at_valid_length(
            first,
            distance:,
            length:,
            options:,
          ))
          Ok(SubpathParameter(segment_index: index, t:))
        }
        False ->
          subpath_parameter_at_valid_length_loop(
            rest,
            distance: distance -. length,
            options:,
            index: index + 1,
          )
      }
    }
  }
}

fn path_parameter_at_valid_length_loop(
  subpaths: List(Subpath),
  distance distance: Float,
  options options: LengthOptions,
  index index: Int,
) -> Result(PathParameter, Error) {
  case subpaths {
    [] -> Error(EmptySubpaths)
    [first, ..rest] -> {
      use length <- result.try(subpath_length_with(first, options:))
      case list.is_empty(first.segments) {
        True ->
          path_parameter_at_valid_length_loop(
            rest,
            distance:,
            options:,
            index: index + 1,
          )
        False -> {
          case distance <=. length {
            True -> {
              use at <- result.try(subpath_parameter_at_length_with(
                first,
                distance:,
                options:,
              ))
              Ok(PathParameter(subpath_index: index, at:))
            }
            False ->
              path_parameter_at_valid_length_loop(
                rest,
                distance: distance -. length,
                options:,
                index: index + 1,
              )
          }
        }
      }
    }
  }
}

fn path_end_parameter_at_length(
  subpaths: List(Subpath),
  options: LengthOptions,
) -> Result(PathParameter, Error) {
  path_end_parameter_at_length_loop(subpaths, options, index: 0, last: None)
}

fn path_end_parameter_at_length_loop(
  subpaths: List(Subpath),
  options: LengthOptions,
  index index: Int,
  last last: Option(PathParameter),
) -> Result(PathParameter, Error) {
  case subpaths {
    [] -> {
      case last {
        None -> Error(EmptySubpaths)
        Some(parameter) -> Ok(parameter)
      }
    }
    [first, ..rest] -> {
      case list.is_empty(first.segments) {
        True ->
          path_end_parameter_at_length_loop(
            rest,
            options,
            index: index + 1,
            last:,
          )
        False -> {
          use length <- result.try(subpath_length_with(first, options:))
          use at <- result.try(subpath_parameter_at_length_with(
            first,
            distance: length,
            options:,
          ))
          path_end_parameter_at_length_loop(
            rest,
            options,
            index: index + 1,
            last: Some(PathParameter(subpath_index: index, at:)),
          )
        }
      }
    }
  }
}

fn distance_stationary_polynomial(
  point: Point,
  segment: Segment,
) -> Result(List(Float), Error) {
  case segment {
    QuadraticBezier(start:, control:, end:) -> {
      let ax = start.x -. 2.0 *. control.x +. end.x
      let ay = start.y -. 2.0 *. control.y +. end.y
      let bx = 2.0 *. { control.x -. start.x }
      let by = 2.0 *. { control.y -. start.y }
      let cx = start.x -. point.x
      let cy = start.y -. point.y
      Ok([
        2.0 *. { ax *. ax +. ay *. ay },
        3.0 *. { ax *. bx +. ay *. by },
        bx *. bx +. by *. by +. 2.0 *. { ax *. cx +. ay *. cy },
        bx *. cx +. by *. cy,
      ])
    }
    CubicBezier(start:, control1:, control2:, end:) -> {
      let ax = 0.0 -. start.x +. 3.0 *. control1.x -. 3.0 *. control2.x +. end.x
      let ay = 0.0 -. start.y +. 3.0 *. control1.y -. 3.0 *. control2.y +. end.y
      let bx = 3.0 *. start.x -. 6.0 *. control1.x +. 3.0 *. control2.x
      let by = 3.0 *. start.y -. 6.0 *. control1.y +. 3.0 *. control2.y
      let cx = 3.0 *. { control1.x -. start.x }
      let cy = 3.0 *. { control1.y -. start.y }
      let dx = start.x -. point.x
      let dy = start.y -. point.y
      Ok([
        3.0 *. { ax *. ax +. ay *. ay },
        5.0 *. { ax *. bx +. ay *. by },
        4.0 *. { ax *. cx +. ay *. cy } +. 2.0 *. { bx *. bx +. by *. by },
        3.0 *. { ax *. dx +. ay *. dy } +. 3.0 *. { bx *. cx +. by *. cy },
        2.0 *. { bx *. dx +. by *. dy } +. cx *. cx +. cy *. cy,
        cx *. dx +. cy *. dy,
      ])
    }
    _ -> Error(DistanceRootIsolationFailed)
  }
}

fn distance_root_error(error: root.Error) -> Error {
  case error {
    root.InvalidTolerance(tolerance) -> InvalidDistanceTolerance(tolerance)
    root.InvalidMaxIterations(max_iterations) ->
      InvalidDistanceMaxIterations(max_iterations)
    root.MaxIterationsReached(estimate:, value:) ->
      DistanceMaxIterationsReached(estimate:, value:)
    root.NotBracketed(..) -> DistanceRootIsolationFailed
  }
}

fn arc_projection_candidates(
  point: Point,
  segment: Segment,
  options: DistanceOptions,
  polish_iterations: Int,
) -> Result(List(Float), Error) {
  case distance_stationary_value(point, segment, 0.0) {
    Error(error) -> Error(error)
    Ok(first_value) -> {
      scan_arc_projection_candidates(
        point,
        segment,
        options,
        polish_iterations,
        index: 1,
        previous_t: 0.0,
        previous_value: first_value,
        candidates: [1.0, 0.0],
      )
    }
  }
}

fn scan_arc_projection_candidates(
  point: Point,
  segment: Segment,
  options: DistanceOptions,
  polish_iterations: Int,
  index index: Int,
  previous_t previous_t: Float,
  previous_value previous_value: Float,
  candidates candidates: List(Float),
) -> Result(List(Float), Error) {
  case index > options.samples {
    True -> Ok(candidates)
    False -> {
      let next_t = int.to_float(index) /. int.to_float(options.samples)

      case distance_stationary_value(point, segment, next_t) {
        Error(error) -> Error(error)
        Ok(next_value) -> {
          case
            arc_projection_candidate_for_window(
              point,
              segment,
              options,
              polish_iterations,
              previous_t,
              previous_value,
              next_t,
              next_value,
            )
          {
            Error(error) -> Error(error)
            Ok(None) ->
              scan_arc_projection_candidates(
                point,
                segment,
                options,
                polish_iterations,
                index: index + 1,
                previous_t: next_t,
                previous_value: next_value,
                candidates:,
              )
            Ok(Some(candidate)) ->
              scan_arc_projection_candidates(
                point,
                segment,
                options,
                polish_iterations,
                index: index + 1,
                previous_t: next_t,
                previous_value: next_value,
                candidates: insert_near_unique(
                  candidates,
                  candidate,
                  options.tolerance,
                ),
              )
          }
        }
      }
    }
  }
}

fn arc_projection_candidate_for_window(
  point: Point,
  segment: Segment,
  options: DistanceOptions,
  polish_iterations: Int,
  previous_t: Float,
  previous_value: Float,
  next_t: Float,
  next_value: Float,
) -> Result(Option(Float), Error) {
  case is_close_to_zero(previous_value, options.tolerance) {
    True -> Ok(Some(previous_t))
    False -> {
      case is_close_to_zero(next_value, options.tolerance) {
        True -> Ok(Some(next_t))
        False -> {
          case same_sign(previous_value, next_value) {
            True -> Ok(None)
            False ->
              refine_arc_projection_window_by_bisection(
                point,
                segment,
                options,
                polish_iterations,
                previous_t,
                previous_value,
                next_t,
              )
          }
        }
      }
    }
  }
}

fn refine_arc_projection_window_by_bisection(
  point: Point,
  segment: Segment,
  options: DistanceOptions,
  polish_iterations: Int,
  left_t: Float,
  left_value: Float,
  right_t: Float,
) -> Result(Option(Float), Error) {
  refine_arc_projection_window_by_bisection_loop(
    point,
    segment,
    options.tolerance,
    left_t,
    left_value,
    right_t,
    options.max_iterations,
    polish_iterations,
  )
  |> result.map(Some)
}

fn refine_arc_projection_window_by_bisection_loop(
  point: Point,
  segment: Segment,
  tolerance: Float,
  left_t: Float,
  left_value: Float,
  right_t: Float,
  remaining_iterations: Int,
  polish_iterations: Int,
) -> Result(Float, Error) {
  use portion <- result.try(segment_between_inside(
    segment,
    from: left_t,
    to: right_t,
  ))
  use box <- result.try(segment_bounding_box(portion))
  case bounding_box_diameter(box) <=. tolerance {
    True -> {
      use estimate <- result.try(best_distance_parameter(
        point,
        segment,
        left_t,
        right_t,
      ))
      use estimate_value <- result.try(distance_stationary_value(
        point,
        segment,
        estimate,
      ))
      polish_arc_projection_window_by_bisection(
        point,
        segment,
        left_t,
        left_value,
        right_t,
        estimate,
        estimate_value,
        remaining: polish_iterations,
      )
    }
    False -> {
      let midpoint_t = left_t +. { right_t -. left_t } /. 2.0
      use midpoint_value <- result.try(distance_stationary_value(
        point,
        segment,
        midpoint_t,
      ))
      case remaining_iterations <= 1 {
        True ->
          Error(DistanceMaxIterationsReached(
            estimate: midpoint_t,
            value: midpoint_value,
          ))
        False ->
          case midpoint_value == 0.0 {
            True -> Ok(midpoint_t)
            False ->
              case same_sign(left_value, midpoint_value) {
                True ->
                  refine_arc_projection_window_by_bisection_loop(
                    point,
                    segment,
                    tolerance,
                    midpoint_t,
                    midpoint_value,
                    right_t,
                    remaining_iterations - 1,
                    polish_iterations,
                  )
                False ->
                  refine_arc_projection_window_by_bisection_loop(
                    point,
                    segment,
                    tolerance,
                    left_t,
                    left_value,
                    midpoint_t,
                    remaining_iterations - 1,
                    polish_iterations,
                  )
              }
          }
      }
    }
  }
}

fn polish_arc_projection_window_by_bisection(
  point: Point,
  segment: Segment,
  left_t: Float,
  left_value: Float,
  right_t: Float,
  estimate: Float,
  estimate_value: Float,
  remaining remaining: Int,
) -> Result(Float, Error) {
  case remaining <= 0 || estimate_value == 0.0 {
    True -> Ok(estimate)
    False -> {
      let midpoint_t = left_t +. { right_t -. left_t } /. 2.0
      use midpoint_value <- result.try(distance_stationary_value(
        point,
        segment,
        midpoint_t,
      ))
      let #(next_left, next_left_value, next_right) = case
        same_sign(left_value, midpoint_value)
      {
        True -> #(midpoint_t, midpoint_value, right_t)
        False -> #(left_t, left_value, midpoint_t)
      }
      use proposal <- result.try(best_distance_parameter(
        point,
        segment,
        next_left,
        next_right,
      ))
      use proposal_value <- result.try(distance_stationary_value(
        point,
        segment,
        proposal,
      ))
      use progressing <- result.try(tangential_error_is_improving(
        segment,
        estimate,
        estimate_value,
        proposal,
        proposal_value,
      ))
      case proposal == estimate || !progressing {
        True -> Ok(estimate)
        False ->
          polish_arc_projection_window_by_bisection(
            point,
            segment,
            next_left,
            next_left_value,
            next_right,
            proposal,
            proposal_value,
            remaining: remaining - 1,
          )
      }
    }
  }
}

fn refine_isolated_distance_root_by_bisection(
  point: Point,
  segment: Segment,
  options: DistanceOptions,
  isolation: root.RootIsolation,
) -> Result(Float, Error) {
  let root.RootIsolation(lower:, estimate:, upper:) = isolation
  case lower == upper {
    True -> Ok(estimate)
    False -> {
      use lower_value <- result.try(distance_stationary_value(
        point,
        segment,
        lower,
      ))
      use upper_value <- result.try(distance_stationary_value(
        point,
        segment,
        upper,
      ))
      case same_sign(lower_value, upper_value) {
        // Repeated roots inherited from derivative isolation do not provide a
        // crossing bracket for the parent polynomial.
        True -> Ok(estimate)
        False ->
          refine_arc_projection_window_by_bisection_loop(
            point,
            segment,
            options.tolerance,
            lower,
            lower_value,
            upper,
            options.max_iterations,
            options.max_iterations,
          )
      }
    }
  }
}

fn tangential_error_is_improving(
  segment: Segment,
  previous_t: Float,
  previous_value: Float,
  proposal_t: Float,
  proposal_value: Float,
) -> Result(Bool, Error) {
  use previous_derivative <- result.try(segment_derivative(
    segment,
    at: previous_t,
  ))
  use proposal_derivative <- result.try(segment_derivative(
    segment,
    at: proposal_t,
  ))
  let previous_speed_squared = dot(previous_derivative, previous_derivative)
  let proposal_speed_squared = dot(proposal_derivative, proposal_derivative)
  let reliable_speed_squared =
    segment_derivative_scale_squared(segment) *. 0.0000000001
  case
    previous_speed_squared >=. reliable_speed_squared,
    proposal_speed_squared >=. reliable_speed_squared
  {
    True, True ->
      Ok(
        proposal_value *. proposal_value *. previous_speed_squared
        <. previous_value *. previous_value *. proposal_speed_squared,
      )
    _, _ -> Ok(False)
  }
}

fn segment_derivative_scale_squared(segment: Segment) -> Float {
  let scale = case segment {
    Line(start:, end:) -> distance(start, end)
    QuadraticBezier(start:, control:, end:) ->
      2.0 *. float.max(distance(start, control), distance(control, end))
    CubicBezier(start:, control1:, control2:, end:) ->
      3.0
      *. float.max(
        distance(start, control1),
        float.max(distance(control1, control2), distance(control2, end)),
      )
    Arc(..) -> 1.0
  }
  scale *. scale
}

fn best_distance_parameter(
  point: Point,
  segment: Segment,
  left_t: Float,
  right_t: Float,
) -> Result(Float, Error) {
  let midpoint_t = left_t +. { right_t -. left_t } /. 2.0
  use left <- result.try(segment_point(segment, at: left_t))
  use midpoint <- result.try(segment_point(segment, at: midpoint_t))
  use right <- result.try(segment_point(segment, at: right_t))
  let left_distance = distance_squared(point, left)
  let midpoint_distance = distance_squared(point, midpoint)
  let right_distance = distance_squared(point, right)
  case left_distance <=. midpoint_distance && left_distance <=. right_distance {
    True -> Ok(left_t)
    False ->
      case midpoint_distance <=. right_distance {
        True -> Ok(midpoint_t)
        False -> Ok(right_t)
      }
  }
}

fn distance_stationary_value(
  point: Point,
  segment: Segment,
  t: Float,
) -> Result(Float, Error) {
  case segment_point(segment, at: t) {
    Error(error) -> Error(error)
    Ok(segment_point) -> {
      case segment_derivative(segment, at: t) {
        Error(error) -> Error(error)
        Ok(derivative) -> {
          let offset = point_difference(segment_point, point)

          Ok(dot(offset, derivative))
        }
      }
    }
  }
}

fn smallest_segment_projection(
  point: Point,
  segment: Segment,
  candidates: List(Float),
) -> Result(SegmentProjection, Error) {
  case candidates {
    [] -> {
      use segment_point <- result.try(segment_point(segment, at: 0.0))

      Ok(SegmentProjection(
        t: 0.0,
        point: segment_point,
        distance: distance(point, segment_point),
      ))
    }
    [first, ..rest] -> {
      case segment_projection_at(point, segment, first) {
        Error(error) -> Error(error)
        Ok(first_projection) ->
          smallest_segment_projection_loop(
            point,
            segment,
            rest,
            first_projection,
          )
      }
    }
  }
}

fn smallest_segment_projection_loop(
  point: Point,
  segment: Segment,
  candidates: List(Float),
  best: SegmentProjection,
) -> Result(SegmentProjection, Error) {
  case candidates {
    [] -> Ok(best)
    [first, ..rest] -> {
      case segment_projection_at(point, segment, first) {
        Error(error) -> Error(error)
        Ok(projection) -> {
          let best = case projection.distance <. best.distance {
            True -> projection
            False -> best
          }

          smallest_segment_projection_loop(point, segment, rest, best)
        }
      }
    }
  }
}

fn segment_projection_at(
  point: Point,
  segment: Segment,
  t: Float,
) -> Result(SegmentProjection, Error) {
  case segment_point(segment, at: t) {
    Error(error) -> Error(error)
    Ok(segment_point) ->
      Ok(SegmentProjection(
        t:,
        point: segment_point,
        distance: distance(point, segment_point),
      ))
  }
}

fn point_to_line_projection(
  point: Point,
  start: Point,
  end: Point,
) -> SegmentProjection {
  let line = point_difference(end, start)
  let length_squared = dot(line, line)

  case length_squared == 0.0 {
    True ->
      SegmentProjection(t: 0.0, point: start, distance: distance(point, start))
    False -> {
      let progress =
        dot(point_difference(point, start), line) /. length_squared
        |> clamp01
      let projection = offset(start, line, progress)

      SegmentProjection(
        t: progress,
        point: projection,
        distance: distance(point, projection),
      )
    }
  }
}

fn subpath_projection_loop(
  point: Point,
  segments: List(Segment),
  options: DistanceOptions,
  index index: Int,
  best best: Option(SubpathProjection),
) -> Result(SubpathProjection, Error) {
  case segments {
    [] ->
      case best {
        None -> Error(EmptySubpath)
        Some(projection) -> Ok(projection)
      }
    [segment, ..rest] -> {
      use projection <- result.try(segment_projection_with(
        point,
        to: segment,
        options:,
      ))
      let subpath_projection =
        SubpathProjection(
          at: SubpathParameter(segment_index: index, t: projection.t),
          point: projection.point,
          distance: projection.distance,
        )
      let best = case best {
        None -> Some(subpath_projection)
        Some(best) -> {
          case subpath_projection.distance <. best.distance {
            True -> Some(subpath_projection)
            False -> Some(best)
          }
        }
      }

      subpath_projection_loop(point, rest, options, index: index + 1, best:)
    }
  }
}

fn subpath_containment_calculation(
  point: Point,
  subpath: Subpath,
  options: ContainmentOptions,
) -> Result(ContainmentCalculation, Error) {
  let distance_options =
    DistanceOptions(
      samples: options.samples,
      tolerance: options.tolerance,
      max_iterations: options.max_iterations,
    )
  use projection <- result.try(subpath_projection_with(
    point,
    to: subpath,
    options: distance_options,
  ))
  let subpath_end = case list.last(subpath.segments) {
    Ok(last) -> segment_end(last)
    Error(_) -> subpath.start
  }
  let closing_distance =
    point_to_line_projection(point, subpath_end, subpath.start).distance
  let boundary_distance = float.min(projection.distance, closing_distance)

  case boundary_distance <=. options.tolerance {
    True -> Ok(CalculatedBoundary)
    False -> {
      let ray = containment_ray_for_subpath_projection(subpath, projection)
      use winding <- result.try(original_subpath_consistent_winding(
        point,
        subpath,
        ray,
        options.fallback_ray_angles,
        options,
      ))
      let #(winding, crossings) = winding
      Ok(CalculatedWinding(winding:, crossings:))
    }
  }
}

fn subpath_containment_calculation_with_initial_ray_angle(
  point: Point,
  subpath: Subpath,
  options: ContainmentOptions,
  ray_angle ray_angle: Float,
) -> Result(ContainmentCalculation, Error) {
  let distance_options =
    DistanceOptions(
      samples: options.samples,
      tolerance: options.tolerance,
      max_iterations: options.max_iterations,
    )
  use projection <- result.try(subpath_projection_with(
    point,
    to: subpath,
    options: distance_options,
  ))
  let subpath_end = case list.last(subpath.segments) {
    Ok(last) -> segment_end(last)
    Error(_) -> subpath.start
  }
  let closing_distance =
    point_to_line_projection(point, subpath_end, subpath.start).distance
  let boundary_distance = float.min(projection.distance, closing_distance)

  case boundary_distance <=. options.tolerance {
    True -> Ok(CalculatedBoundary)
    False -> {
      let ray = containment_ray_for_angle(ray_angle)
      use winding <- result.try(original_subpath_consistent_winding(
        point,
        subpath,
        ray,
        [],
        options,
      ))
      let #(winding, crossings) = winding
      Ok(CalculatedWinding(winding:, crossings:))
    }
  }
}

fn containment_ray_for_subpath_projection(
  subpath: Subpath,
  projection: SubpathProjection,
) -> ContainmentRay {
  let SubpathProjection(at:, ..) = projection
  case subpath_directions(subpath, at:) {
    Error(_) ->
      containment_ray_for_angle(default_containment_horizontal_ray_angle)
    Ok(directions) -> containment_ray_for_directions(directions)
  }
}

fn containment_ray_for_directions(directions: Directions) -> ContainmentRay {
  case directions.incoming, directions.outgoing {
    Some(incoming), Some(outgoing) ->
      containment_ray_for_direction(Point(
        incoming.x +. outgoing.x,
        incoming.y +. outgoing.y,
      ))
    Some(direction), None -> containment_ray_for_direction(direction)
    None, Some(direction) -> containment_ray_for_direction(direction)
    None, None ->
      containment_ray_for_angle(default_containment_horizontal_ray_angle)
  }
}

fn containment_ray_for_direction(direction: Point) -> ContainmentRay {
  case float.absolute_value(direction.x) >=. float.absolute_value(direction.y) {
    True -> containment_ray_for_angle(default_containment_vertical_ray_angle)
    False -> containment_ray_for_angle(default_containment_horizontal_ray_angle)
  }
}

fn containment_from_calculation(
  calculation: ContainmentCalculation,
  fill_rule: FillRule,
) -> PointContainment {
  case calculation {
    CalculatedBoundary -> Boundary
    CalculatedWinding(winding:, crossings:) ->
      containment_from_winding(winding, crossings, fill_rule)
  }
}

fn containment_from_winding(
  winding: Int,
  crossings: Int,
  fill_rule: FillRule,
) -> PointContainment {
  case fill_rule {
    Nonzero -> containment_from_bool(winding != 0)
    EvenOdd -> {
      let assert Ok(remainder) = int.remainder(crossings, by: 2)
      containment_from_bool(remainder == 1)
    }
  }
}

fn containment_from_bool(inside: Bool) -> PointContainment {
  case inside {
    True -> Inside
    False -> Outside
  }
}

fn original_subpath_consistent_winding(
  point: Point,
  subpath: Subpath,
  ray: ContainmentRay,
  fallback_ray_angles: List(Float),
  options options: ContainmentOptions,
) -> Result(#(Int, Int), Error) {
  case original_subpath_opposite_windings_agree(point, subpath, ray, options:) {
    Ok(winding) -> Ok(winding)
    Error(InconsistentContainment) ->
      original_subpath_fallback_winding(
        point,
        subpath,
        fallback_ray_angles,
        options:,
      )
    Error(error) -> Error(error)
  }
}

fn original_subpath_fallback_winding(
  point: Point,
  subpath: Subpath,
  fallback_ray_angles: List(Float),
  options options: ContainmentOptions,
) -> Result(#(Int, Int), Error) {
  case fallback_ray_angles {
    [] -> Error(InconsistentContainment)
    [angle, ..rest] -> {
      let ray = containment_ray_for_angle(angle)
      case
        original_subpath_opposite_windings_agree(point, subpath, ray, options:)
      {
        Ok(winding) -> Ok(winding)
        Error(InconsistentContainment) ->
          original_subpath_fallback_winding(point, subpath, rest, options:)
        Error(error) -> Error(error)
      }
    }
  }
}

fn original_subpath_opposite_windings_agree(
  point: Point,
  subpath: Subpath,
  ray: ContainmentRay,
  options options: ContainmentOptions,
) -> Result(#(Int, Int), Error) {
  use bidirectional <- result.try(original_subpath_bidirectional_winding(
    point,
    subpath,
    ray,
    options:,
  ))
  let #(
    forward_winding,
    forward_crossings,
    backward_winding,
    backward_crossings,
  ) = bidirectional
  case
    winding_answers_are_containment_compatible(
      forward_winding,
      forward_crossings,
      backward_winding,
      backward_crossings,
    )
  {
    True -> Ok(#(forward_winding, forward_crossings))
    False -> Error(InconsistentContainment)
  }
}

fn original_subpath_bidirectional_winding(
  point: Point,
  subpath: Subpath,
  ray: ContainmentRay,
  options options: ContainmentOptions,
) -> Result(#(Int, Int, Int, Int), Error) {
  use winding <- result.try(original_segments_bidirectional_winding(
    point,
    subpath.segments,
    ray,
    options:,
    forward_winding: 0,
    forward_crossings: 0,
    backward_winding: 0,
    backward_crossings: 0,
  ))
  let #(
    forward_winding,
    forward_crossings,
    backward_winding,
    backward_crossings,
  ) = winding
  let subpath_end = case list.last(subpath.segments) {
    Ok(last) -> segment_end(last)
    Error(_) -> subpath.start
  }
  let forward_closing =
    line_winding_contribution(point, subpath_end, subpath.start, ray)
  let backward_closing =
    line_winding_contribution(
      point,
      subpath_end,
      subpath.start,
      containment_ray_opposite(ray),
    )

  Ok(#(
    forward_winding + forward_closing,
    forward_crossings + crossing_count_for_contribution(forward_closing),
    backward_winding + backward_closing,
    backward_crossings + crossing_count_for_contribution(backward_closing),
  ))
}

fn winding_answers_are_containment_compatible(
  forward_winding: Int,
  forward_crossings: Int,
  backward_winding: Int,
  backward_crossings: Int,
) -> Bool {
  forward_winding == backward_winding
  && crossing_parity(forward_crossings) == crossing_parity(backward_crossings)
}

fn crossing_parity(crossings: Int) -> Int {
  let assert Ok(parity) = int.remainder(crossings, by: 2)
  parity
}

fn original_segments_bidirectional_winding(
  point: Point,
  segments: List(Segment),
  ray: ContainmentRay,
  options options: ContainmentOptions,
  forward_winding forward_winding: Int,
  forward_crossings forward_crossings: Int,
  backward_winding backward_winding: Int,
  backward_crossings backward_crossings: Int,
) -> Result(#(Int, Int, Int, Int), Error) {
  case segments {
    [] ->
      Ok(#(
        forward_winding,
        forward_crossings,
        backward_winding,
        backward_crossings,
      ))
    [segment, ..rest] -> {
      use contribution <- result.try(segment_bidirectional_winding_contribution(
        point,
        segment,
        ray,
        options:,
      ))
      let #(forward, backward) = contribution
      original_segments_bidirectional_winding(
        point,
        rest,
        ray,
        options:,
        forward_winding: forward_winding + forward,
        forward_crossings: forward_crossings
          + crossing_count_for_contribution(forward),
        backward_winding: backward_winding + backward,
        backward_crossings: backward_crossings
          + crossing_count_for_contribution(backward),
      )
    }
  }
}

fn segment_winding_contribution(
  point: Point,
  segment: Segment,
  ray: ContainmentRay,
  options options: ContainmentOptions,
) -> Result(Int, Error) {
  case segment {
    Line(start:, end:) -> Ok(line_winding_contribution(point, start, end, ray))
    _ -> curved_segment_winding_contribution(point, segment, ray, options)
  }
}

fn segment_bidirectional_winding_contribution(
  point: Point,
  segment: Segment,
  ray: ContainmentRay,
  options options: ContainmentOptions,
) -> Result(#(Int, Int), Error) {
  case segment {
    Line(start:, end:) ->
      Ok(#(
        line_winding_contribution(point, start, end, ray),
        line_winding_contribution(
          point,
          start,
          end,
          containment_ray_opposite(ray),
        ),
      ))
    _ ->
      curved_segment_bidirectional_winding_contribution(
        point,
        segment,
        ray,
        options,
      )
  }
}

fn curved_segment_winding_contribution(
  point: Point,
  segment: Segment,
  ray: ContainmentRay,
  options: ContainmentOptions,
) -> Result(Int, Error) {
  let crossing_options =
    CrossingOptions(
      samples: options.samples,
      signed_line_distance_tolerance: options.tolerance,
      max_iterations: options.max_iterations,
    )
  use crossings <- result.try(segment_ray_crossings_with(
    segment,
    origin: point,
    direction: ray.direction,
    options: crossing_options,
  ))
  curved_segment_crossings_winding(point, segment, ray, crossings, winding: 0)
}

fn curved_segment_bidirectional_winding_contribution(
  point: Point,
  segment: Segment,
  ray: ContainmentRay,
  options: ContainmentOptions,
) -> Result(#(Int, Int), Error) {
  let crossing_options =
    CrossingOptions(
      samples: options.samples,
      signed_line_distance_tolerance: options.tolerance,
      max_iterations: options.max_iterations,
    )
  use crossings <- result.try(segment_ray_crossings_with(
    segment,
    origin: point,
    direction: ray.direction,
    options: crossing_options,
  ))
  curved_segment_crossings_bidirectional_winding(
    point,
    segment,
    ray,
    crossings,
    forward_winding: 0,
    backward_winding: 0,
  )
}

fn curved_segment_crossings_winding(
  point: Point,
  segment: Segment,
  ray: ContainmentRay,
  crossings: List(#(Float, Float)),
  winding winding: Int,
) -> Result(Int, Error) {
  case crossings {
    [] -> Ok(winding)
    [crossing, ..rest] -> {
      let #(t, ray_t) = crossing
      case t <. 0.0 || t >. 1.0 {
        True ->
          curved_segment_crossings_winding(point, segment, ray, rest, winding:)
        False -> {
          use contribution <- result.try(curved_crossing_contribution(
            point,
            segment,
            ray,
            t,
            ray_t,
          ))
          curved_segment_crossings_winding(
            point,
            segment,
            ray,
            rest,
            winding: winding + contribution,
          )
        }
      }
    }
  }
}

fn curved_segment_crossings_bidirectional_winding(
  point: Point,
  segment: Segment,
  ray: ContainmentRay,
  crossings: List(#(Float, Float)),
  forward_winding forward_winding: Int,
  backward_winding backward_winding: Int,
) -> Result(#(Int, Int), Error) {
  case crossings {
    [] -> Ok(#(forward_winding, backward_winding))
    [crossing, ..rest] -> {
      let #(t, ray_t) = crossing
      case t <. 0.0 || t >. 1.0 {
        True ->
          curved_segment_crossings_bidirectional_winding(
            point,
            segment,
            ray,
            rest,
            forward_winding:,
            backward_winding:,
          )
        False -> {
          use contribution <- result.try(
            curved_crossing_bidirectional_contribution(
              point,
              segment,
              ray,
              t,
              ray_t,
            ),
          )
          let #(forward, backward) = contribution
          curved_segment_crossings_bidirectional_winding(
            point,
            segment,
            ray,
            rest,
            forward_winding: forward_winding + forward,
            backward_winding: backward_winding + backward,
          )
        }
      }
    }
  }
}

fn curved_crossing_bidirectional_contribution(
  point: Point,
  segment: Segment,
  ray: ContainmentRay,
  t: Float,
  ray_t: Float,
) -> Result(#(Int, Int), Error) {
  case ray_t >. 0.0 {
    True -> {
      use contribution <- result.try(curved_crossing_contribution(
        point,
        segment,
        ray,
        t,
        ray_t,
      ))
      Ok(#(contribution, 0))
    }
    False ->
      case ray_t <. 0.0 {
        False -> Ok(#(0, 0))
        True -> {
          use contribution <- result.try(curved_crossing_contribution(
            point,
            segment,
            containment_ray_opposite(ray),
            t,
            0.0 -. ray_t,
          ))
          Ok(#(0, contribution))
        }
      }
  }
}

fn curved_crossing_contribution(
  point: Point,
  segment: Segment,
  ray: ContainmentRay,
  t: Float,
  ray_t: Float,
) -> Result(Int, Error) {
  let t = clamp01(t)
  case ray_t >. 0.0 {
    False -> Ok(0)
    True -> {
      curved_crossing_contribution_with_probe(
        point,
        segment,
        ray,
        t,
        probe: 0.0000001,
        max_probe: 0.001,
      )
    }
  }
}

fn curved_crossing_contribution_with_probe(
  point: Point,
  segment: Segment,
  ray: ContainmentRay,
  t: Float,
  probe probe: Float,
  max_probe max_probe: Float,
) -> Result(Int, Error) {
  use before <- result.try(segment_point(
    segment,
    at: float.max(0.0, t -. probe),
  ))
  use after <- result.try(segment_point(segment, at: float.min(1.0, t +. probe)))
  let contribution =
    crossing_transition_contribution(
      containment_ray_crossing_value(point, before, ray),
      containment_ray_crossing_value(point, after, ray),
    )
  case contribution != 0 || probe >=. max_probe {
    True -> Ok(contribution)
    False ->
      curved_crossing_contribution_with_probe(
        point,
        segment,
        ray,
        t,
        probe: probe *. 10.0,
        max_probe:,
      )
  }
}

fn containment_ray_crossing_value(
  point: Point,
  candidate: Point,
  ray: ContainmentRay,
) -> Float {
  cross(ray.direction, point_difference(candidate, point))
}

fn containment_ray_for_angle(angle: Float) -> ContainmentRay {
  ContainmentRay(
    angle:,
    direction: Point(trig.cos_degrees(angle), trig.sin_degrees(angle)),
  )
}

fn containment_ray_opposite(ray: ContainmentRay) -> ContainmentRay {
  let ContainmentRay(angle:, direction:) = ray
  ContainmentRay(
    angle: angle +. 180.0,
    direction: Point(0.0 -. direction.x, 0.0 -. direction.y),
  )
}

fn crossing_transition_contribution(before: Float, after: Float) -> Int {
  case before <=. 0.0 && after >. 0.0 {
    True -> 1
    False ->
      case before >. 0.0 && after <=. 0.0 {
        True -> -1
        False -> 0
      }
  }
}

fn crossing_count_for_contribution(contribution: Int) -> Int {
  case contribution == 0 {
    True -> 0
    False -> 1
  }
}

fn line_winding_contribution(
  point: Point,
  start: Point,
  end: Point,
  ray: ContainmentRay,
) -> Int {
  let start_y = containment_ray_crossing_value(point, start, ray)
  let end_y = containment_ray_crossing_value(point, end, ray)
  let side = cross(point_difference(end, start), point_difference(point, start))

  case start_y <=. 0.0 {
    True -> {
      case end_y >. 0.0 && side >. 0.0 {
        True -> 1
        False -> 0
      }
    }
    False -> {
      case end_y <=. 0.0 && side <. 0.0 {
        True -> -1
        False -> 0
      }
    }
  }
}

fn path_containment_loop(
  point: Point,
  subpaths: List(Subpath),
  fill_rule: FillRule,
  options: ContainmentOptions,
  winding winding: Int,
  crossings crossings: Int,
) -> Result(PointContainment, Error) {
  case subpaths {
    [] -> Ok(containment_from_winding(winding, crossings, fill_rule))
    [subpath, ..rest] -> {
      case subpath.segments {
        [] ->
          path_containment_loop(
            point,
            rest,
            fill_rule,
            options,
            winding:,
            crossings:,
          )
        _ -> {
          use calculation <- result.try(subpath_containment_calculation(
            point,
            subpath,
            options,
          ))
          case calculation {
            CalculatedBoundary -> Ok(Boundary)
            CalculatedWinding(
              winding: subpath_winding,
              crossings: subpath_crossings,
            ) ->
              path_containment_loop(
                point,
                rest,
                fill_rule,
                options,
                winding: winding + subpath_winding,
                crossings: crossings + subpath_crossings,
              )
          }
        }
      }
    }
  }
}

fn path_winding_loop(
  point: Point,
  subpaths: List(Subpath),
  options: ContainmentOptions,
  winding winding: Int,
) -> Result(PathWinding, Error) {
  case subpaths {
    [] -> Ok(Winding(winding))
    [subpath, ..rest] -> {
      case subpath.segments {
        [] -> path_winding_loop(point, rest, options, winding:)
        _ -> {
          use calculation <- result.try(subpath_containment_calculation(
            point,
            subpath,
            options,
          ))
          case calculation {
            CalculatedBoundary -> Ok(BoundaryWinding)
            CalculatedWinding(winding: subpath_winding, ..) ->
              path_winding_loop(
                point,
                rest,
                options,
                winding: winding + subpath_winding,
              )
          }
        }
      }
    }
  }
}

fn path_projection_loop(
  point: Point,
  subpaths: List(Subpath),
  options: DistanceOptions,
  index index: Int,
  best best: Option(PathProjection),
) -> Result(PathProjection, Error) {
  case subpaths {
    [] ->
      case best {
        None -> Error(EmptySubpaths)
        Some(projection) -> Ok(projection)
      }
    [subpath, ..rest] -> {
      case list.is_empty(subpath.segments) {
        True ->
          path_projection_loop(point, rest, options, index: index + 1, best:)
        False -> {
          use projection <- result.try(subpath_projection_with(
            point,
            to: subpath,
            options:,
          ))
          let path_projection =
            PathProjection(
              at: PathParameter(subpath_index: index, at: projection.at),
              point: projection.point,
              distance: projection.distance,
            )
          let best = case best {
            None -> Some(path_projection)
            Some(best) -> {
              case path_projection.distance <. best.distance {
                True -> Some(path_projection)
                False -> Some(best)
              }
            }
          }

          path_projection_loop(point, rest, options, index: index + 1, best:)
        }
      }
    }
  }
}

fn clamp01(value: Float) -> Float {
  value |> float.max(0.0) |> float.min(1.0)
}

fn point_difference(a: Point, b: Point) -> Point {
  Point(a.x -. b.x, a.y -. b.y)
}

fn offset(origin: Point, direction: Point, distance: Float) -> Point {
  Point(
    origin.x +. direction.x *. distance,
    origin.y +. direction.y *. distance,
  )
}

fn dot(a: Point, b: Point) -> Float {
  a.x *. b.x +. a.y *. b.y
}

fn cross(a: Point, b: Point) -> Float {
  a.x *. b.y -. a.y *. b.x
}

fn interpolate_float(start: Float, end: Float, t: Float) -> Float {
  start +. { end -. start } *. t
}

fn canonicalize_subpath_parameter_unchecked(
  parameter: SubpathParameter,
  subpath: Subpath,
  tolerance: Float,
) -> SubpathParameter {
  let length = list.length(subpath.segments)
  case parameter {
    SubpathParameter(segment_index:, t:) if t <=. tolerance ->
      SubpathParameter(segment_index:, t: 0.0)
    SubpathParameter(segment_index:, t:) if 1.0 -. t <=. tolerance -> {
      case segment_index < length - 1, subpath.closed {
        True, _ -> SubpathParameter(segment_index + 1, 0.0)
        False, True -> SubpathParameter(0, 0.0)
        False, False -> SubpathParameter(segment_index:, t: 1.0)
      }
    }
    _ -> parameter
  }
}

fn combine_segment_bounding_boxes(
  segments: List(Segment),
  box: BoundingBox,
) -> Result(BoundingBox, Error) {
  case segments {
    [] -> Ok(box)
    [first, ..rest] -> {
      case segment_bounding_box(first) {
        Error(error) -> Error(error)
        Ok(next) ->
          combine_segment_bounding_boxes(rest, combine_boxes(box, next))
      }
    }
  }
}

fn combine_subpath_bounding_boxes(
  subpaths: List(Subpath),
  box: Option(BoundingBox),
) -> Result(BoundingBox, Error) {
  case subpaths {
    [] -> {
      case box {
        None -> Error(EmptySubpaths)
        Some(box) -> Ok(box)
      }
    }
    [first, ..rest] -> {
      case subpath_bounding_box(first) {
        Error(EmptySubpath) -> combine_subpath_bounding_boxes(rest, box)
        Error(error) -> Error(error)
        Ok(next) -> {
          let box = case box {
            None -> next
            Some(box) -> combine_boxes(box, next)
          }

          combine_subpath_bounding_boxes(rest, Some(box))
        }
      }
    }
  }
}

fn combine_boxes(first: BoundingBox, second: BoundingBox) -> BoundingBox {
  bounding_box_union(first, second)
}

fn min_point(a: Point, b: Point) -> Point {
  Point(float.min(a.x, b.x), float.min(a.y, b.y))
}

fn max_point(a: Point, b: Point) -> Point {
  Point(float.max(a.x, b.x), float.max(a.y, b.y))
}

fn splice_segments(
  segments: List(Segment),
  start: Int,
  delete: Int,
  insert: List(Segment),
) -> List(Segment) {
  splice_segments_loop(segments, start, delete, insert, index: 0, before: [])
}

fn first_subpath_start(subpaths: List(Subpath)) -> Result(Point, Error) {
  case subpaths {
    [] -> Error(EmptySubpaths)
    [subpath, ..] -> subpath_start(subpath)
  }
}

fn first_subpath_end(subpaths: List(Subpath)) -> Result(Point, Error) {
  case subpaths {
    [] -> Error(EmptySubpaths)
    [subpath, ..] -> subpath_end(subpath)
  }
}

fn join_open_subpaths(
  subpaths: List(Subpath),
  policy: EndpointPolicy,
) -> Result(Subpath, Error) {
  case subpaths {
    [] -> Error(EmptySubpath)
    [first, ..rest] -> {
      let start = first.start
      let segments = list.flat_map([first, ..rest], subpath_segments)
      open_subpath_with_start(segments, start, policy)
    }
  }
}

fn map_subpaths_points(
  subpaths: List(Subpath),
  f: fn(Point) -> Point,
  mapped: List(Subpath),
) -> Result(List(Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(mapped))
    [first, ..rest] -> {
      case subpath_map_points(first, with: f) {
        Error(error) -> Error(error)
        Ok(subpath) -> map_subpaths_points(rest, f, [subpath, ..mapped])
      }
    }
  }
}

fn path_rebuild_subpaths_with(
  subpaths: List(Subpath),
  policy policy: EndpointPolicy,
  rebuilt rebuilt: List(Subpath),
) -> Result(List(Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(rebuilt))
    [subpath, ..rest] -> {
      use rebuilt_subpath <- result.try(subpath_rebuild_with(subpath, policy:))
      path_rebuild_subpaths_with(rest, policy:, rebuilt: [
        rebuilt_subpath,
        ..rebuilt
      ])
    }
  }
}

fn try_map_subpaths_points(
  subpaths: List(Subpath),
  f: fn(Point) -> Result(Point, error),
  mapped: List(Subpath),
) -> Result(List(Subpath), PointMapError(error)) {
  case subpaths {
    [] -> Ok(list.reverse(mapped))
    [first, ..rest] -> {
      case subpath_try_map_points(first, with: f) {
        Error(error) -> Error(error)
        Ok(subpath) -> try_map_subpaths_points(rest, f, [subpath, ..mapped])
      }
    }
  }
}

fn first_subpath(subpaths: List(Subpath)) -> Subpath {
  case subpaths {
    [first, ..] -> first
    [] -> panic as "svg_path.first_subpath received an empty list"
  }
}

fn subpath_from_valid_segments(
  segments: List(Segment),
  fallback_start fallback_start: Point,
  closed closed: Bool,
) -> Subpath {
  case segments {
    [] -> Subpath(start: fallback_start, segments: [], closed:)
    [first, ..] -> Subpath(start: segment_start(first), segments:, closed:)
  }
}

fn map_segments_points(
  segments: List(Segment),
  f: fn(Point) -> Point,
  mapped: List(Segment),
) -> Result(List(Segment), Error) {
  case segments {
    [] -> Ok(list.reverse(mapped))
    [first, ..rest] -> {
      case segment_map_points(first, with: f) {
        Error(error) -> Error(error)
        Ok(segment) -> map_segments_points(rest, f, [segment, ..mapped])
      }
    }
  }
}

fn try_map_segments_points(
  segments: List(Segment),
  f: fn(Point) -> Result(Point, error),
  mapped: List(Segment),
) -> Result(List(Segment), PointMapError(error)) {
  case segments {
    [] -> Ok(list.reverse(mapped))
    [first, ..rest] -> {
      case segment_try_map_points(first, with: f) {
        Error(error) -> Error(error)
        Ok(segment) -> try_map_segments_points(rest, f, [segment, ..mapped])
      }
    }
  }
}

fn try_map_bezier_points(
  curve: bezier.BezierData,
  with f: fn(Point) -> Result(Point, error),
) -> Result(bezier.BezierData, PointMapError(error)) {
  case curve {
    bezier.LinearBezierData(start:, end:) -> {
      use start <- result.try(
        start
        |> from_bezier_point
        |> f
        |> result.map_error(PointMapFunctionError),
      )
      use end <- result.try(
        end |> from_bezier_point |> f |> result.map_error(PointMapFunctionError),
      )
      Ok(bezier.LinearBezierData(
        start: to_bezier_point(start),
        end: to_bezier_point(end),
      ))
    }
    bezier.QuadraticBezierData(start:, control:, end:) -> {
      use start <- result.try(
        start
        |> from_bezier_point
        |> f
        |> result.map_error(PointMapFunctionError),
      )
      use control <- result.try(
        control
        |> from_bezier_point
        |> f
        |> result.map_error(PointMapFunctionError),
      )
      use end <- result.try(
        end |> from_bezier_point |> f |> result.map_error(PointMapFunctionError),
      )
      Ok(bezier.QuadraticBezierData(
        start: to_bezier_point(start),
        control: to_bezier_point(control),
        end: to_bezier_point(end),
      ))
    }
    bezier.CubicBezierData(start:, control1:, control2:, end:) -> {
      use start <- result.try(
        start
        |> from_bezier_point
        |> f
        |> result.map_error(PointMapFunctionError),
      )
      use control1 <- result.try(
        control1
        |> from_bezier_point
        |> f
        |> result.map_error(PointMapFunctionError),
      )
      use control2 <- result.try(
        control2
        |> from_bezier_point
        |> f
        |> result.map_error(PointMapFunctionError),
      )
      use end <- result.try(
        end |> from_bezier_point |> f |> result.map_error(PointMapFunctionError),
      )
      Ok(bezier.CubicBezierData(
        start: to_bezier_point(start),
        control1: to_bezier_point(control1),
        control2: to_bezier_point(control2),
        end: to_bezier_point(end),
      ))
    }
  }
}

fn splice_segments_loop(
  segments: List(Segment),
  start: Int,
  delete: Int,
  insert: List(Segment),
  index index: Int,
  before before: List(Segment),
) -> List(Segment) {
  case segments {
    [] -> list.append(list.reverse(before), insert)
    [first, ..rest] -> {
      case index < start {
        True ->
          splice_segments_loop(rest, start, delete, insert, index + 1, [
            first,
            ..before
          ])
        False ->
          list.append(
            list.reverse(before),
            list.append(insert, drop(segments, delete)),
          )
      }
    }
  }
}

fn drop(segments: List(Segment), count: Int) -> List(Segment) {
  case count <= 0 {
    True -> segments
    False -> {
      case segments {
        [] -> []
        [_, ..rest] -> drop(rest, count - 1)
      }
    }
  }
}

fn take(segments: List(Segment), count: Int) -> List(Segment) {
  case count <= 0 {
    True -> []
    False -> {
      case segments {
        [] -> []
        [first, ..rest] -> [first, ..take(rest, count - 1)]
      }
    }
  }
}

fn validate_subpath_parameter(
  subpath: Subpath,
  parameter: SubpathParameter,
) -> Result(CanonicalSubpathParameter, Error) {
  let length = list.length(subpath.segments)
  let SubpathParameter(segment_index:, t:) = parameter

  case length == 0 {
    True -> Error(EmptySubpath)
    False -> {
      case
        segment_index < 0 || segment_index >= length || t <. 0.0 || t >. 1.0
      {
        True -> Error(InvalidSubpathParameter(segment_index:, t:, length:))
        False ->
          Ok(canonical_subpath_parameter(
            parameter,
            length:,
            closed: subpath.closed,
          ))
      }
    }
  }
}

fn validate_subpath_parameters(
  subpath: Subpath,
  parameters: List(SubpathParameter),
) -> Result(List(CanonicalSubpathParameter), Error) {
  parameters
  |> list.fold(Ok([]), fn(validated, parameter) {
    use validated <- result.try(validated)
    use parameter <- result.try(validate_subpath_parameter(subpath, parameter))
    Ok([parameter, ..validated])
  })
  |> result.map(list.reverse)
}

fn canonical_subpath_parameter(
  parameter: SubpathParameter,
  length length: Int,
  closed closed: Bool,
) -> CanonicalSubpathParameter {
  let SubpathParameter(segment_index:, t:) = parameter
  case t == 1.0 && segment_index + 1 < length {
    True -> CanonicalSubpathParameter(segment_index: segment_index + 1, t: 0.0)
    False ->
      case closed && t == 1.0 && segment_index == length - 1 {
        True -> CanonicalSubpathParameter(segment_index: 0, t: 0.0)
        False -> CanonicalSubpathParameter(segment_index:, t:)
      }
  }
}

fn canonical_to_subpath_parameter(
  parameter: CanonicalSubpathParameter,
) -> SubpathParameter {
  let CanonicalSubpathParameter(segment_index:, t:) = parameter
  SubpathParameter(segment_index:, t:)
}

fn compare_canonical_subpath_parameters(
  a: CanonicalSubpathParameter,
  b: CanonicalSubpathParameter,
) -> order.Order {
  let CanonicalSubpathParameter(segment_index: a_index, t: a_t) = a
  let CanonicalSubpathParameter(segment_index: b_index, t: b_t) = b

  case int.compare(a_index, b_index) {
    order.Eq -> float.compare(a_t, b_t)
    order -> order
  }
}

fn subpath_start_parameter() -> CanonicalSubpathParameter {
  CanonicalSubpathParameter(segment_index: 0, t: 0.0)
}

fn subpath_end_parameter(length: Int) -> CanonicalSubpathParameter {
  CanonicalSubpathParameter(segment_index: length - 1, t: 1.0)
}

fn subpath_parameter_is_boundary(
  parameter: CanonicalSubpathParameter,
  length: Int,
) -> Bool {
  compare_canonical_subpath_parameters(parameter, subpath_start_parameter())
  == order.Eq
  || compare_canonical_subpath_parameters(
    parameter,
    subpath_end_parameter(length),
  )
  == order.Eq
}

fn invalid_subpath_parameter(
  parameter: CanonicalSubpathParameter,
  length: Int,
) -> Result(a, Error) {
  let CanonicalSubpathParameter(segment_index:, t:) = parameter
  Error(InvalidSubpathParameter(segment_index:, t:, length:))
}

fn subpath_between_valid_parameters(
  subpath: Subpath,
  from from: CanonicalSubpathParameter,
  to to: CanonicalSubpathParameter,
) -> Result(Subpath, Error) {
  case compare_canonical_subpath_parameters(from, to) {
    order.Eq ->
      Error(InvalidSubpathInterval(
        from: canonical_to_subpath_parameter(from),
        to: canonical_to_subpath_parameter(to),
      ))
    order.Lt -> {
      use segments <- result.try(subpath_interval_segments(subpath, from:, to:))
      open_subpath_with_segments(segments, Strict)
    }
    order.Gt ->
      case subpath.closed {
        False ->
          Error(InvalidSubpathInterval(
            from: canonical_to_subpath_parameter(from),
            to: canonical_to_subpath_parameter(to),
          ))
        True -> {
          let length = list.length(subpath.segments)
          use before_wrap <- result.try(subpath_interval_segments(
            subpath,
            from:,
            to: subpath_end_parameter(length),
          ))
          use after_wrap <- result.try(subpath_interval_segments(
            subpath,
            from: subpath_start_parameter(),
            to:,
          ))
          open_subpath_with_segments(
            list.append(before_wrap, after_wrap),
            Strict,
          )
        }
      }
  }
}

fn open_closed_subpath_at_parameter(
  subpath: Subpath,
  parameter: CanonicalSubpathParameter,
) -> Result(Subpath, Error) {
  let length = list.length(subpath.segments)
  use before_wrap <- result.try(subpath_interval_segments(
    subpath,
    from: parameter,
    to: subpath_end_parameter(length),
  ))
  use after_wrap <- result.try(subpath_interval_segments(
    subpath,
    from: subpath_start_parameter(),
    to: parameter,
  ))

  open_subpath_with_segments(list.append(before_wrap, after_wrap), Strict)
}

fn subpath_interval_segments(
  subpath: Subpath,
  from from: CanonicalSubpathParameter,
  to to: CanonicalSubpathParameter,
) -> Result(List(Segment), Error) {
  case compare_canonical_subpath_parameters(from, to) {
    order.Eq -> Ok([])
    order.Gt ->
      Error(InvalidSubpathInterval(
        from: canonical_to_subpath_parameter(from),
        to: canonical_to_subpath_parameter(to),
      ))
    order.Lt -> {
      let CanonicalSubpathParameter(segment_index: from_index, t: from_t) = from
      let CanonicalSubpathParameter(segment_index: to_index, t: to_t) = to

      case from_index == to_index {
        True -> {
          use segment <- result.try(nth_segment(subpath.segments, from_index))
          use piece <- result.try(segment_between_inside(
            segment,
            from: from_t,
            to: to_t,
          ))
          Ok([piece])
        }
        False -> {
          use start <- result.try(subpath_interval_start_piece(
            subpath.segments,
            from_index,
            from_t,
          ))
          let middle =
            subpath.segments
            |> drop(from_index + 1)
            |> take(to_index - from_index - 1)
          use end <- result.try(subpath_interval_end_piece(
            subpath.segments,
            to_index,
            to_t,
          ))
          Ok(list.append(start, list.append(middle, end)))
        }
      }
    }
  }
}

fn subpath_interval_start_piece(
  segments: List(Segment),
  index: Int,
  t: Float,
) -> Result(List(Segment), Error) {
  use segment <- result.try(nth_segment(segments, index))
  case t == 0.0 {
    True -> Ok([segment])
    False -> {
      use piece <- result.try(segment_between_inside(segment, from: t, to: 1.0))
      Ok([piece])
    }
  }
}

fn subpath_interval_end_piece(
  segments: List(Segment),
  index: Int,
  t: Float,
) -> Result(List(Segment), Error) {
  case t == 0.0 {
    True -> Ok([])
    False -> {
      use segment <- result.try(nth_segment(segments, index))
      case t == 1.0 {
        True -> Ok([segment])
        False -> {
          use piece <- result.try(segment_between_inside(
            segment,
            from: 0.0,
            to: t,
          ))
          Ok([piece])
        }
      }
    }
  }
}

fn validate_open_subpath_split_points(
  points: List(CanonicalSubpathParameter),
  length: Int,
) -> Result(Nil, Error) {
  case points {
    [] -> Ok(Nil)
    [point, ..rest] -> {
      case subpath_parameter_is_boundary(point, length) {
        True -> invalid_subpath_parameter(point, length)
        False ->
          validate_open_subpath_split_points_loop(
            rest,
            previous: point,
            length:,
          )
      }
    }
  }
}

fn validate_open_subpath_split_points_loop(
  points: List(CanonicalSubpathParameter),
  previous previous: CanonicalSubpathParameter,
  length length: Int,
) -> Result(Nil, Error) {
  case points {
    [] -> Ok(Nil)
    [point, ..rest] -> {
      case subpath_parameter_is_boundary(point, length) {
        True -> invalid_subpath_parameter(point, length)
        False ->
          case compare_canonical_subpath_parameters(previous, point) {
            order.Lt ->
              validate_open_subpath_split_points_loop(
                rest,
                previous: point,
                length:,
              )
            _ ->
              Error(InvalidSubpathInterval(
                from: canonical_to_subpath_parameter(previous),
                to: canonical_to_subpath_parameter(point),
              ))
          }
      }
    }
  }
}

fn validate_closed_subpath_split_points(
  points: List(CanonicalSubpathParameter),
) -> Result(Nil, Error) {
  case points {
    [] | [_] -> Ok(Nil)
    [first, second, ..rest] ->
      validate_closed_subpath_split_points_loop(
        [second, ..rest],
        first:,
        previous: first,
        descents: 0,
      )
  }
}

fn validate_closed_subpath_split_points_loop(
  points: List(CanonicalSubpathParameter),
  first first: CanonicalSubpathParameter,
  previous previous: CanonicalSubpathParameter,
  descents descents: Int,
) -> Result(Nil, Error) {
  case points {
    [] -> {
      use descents <- result.try(count_cyclic_descent(
        previous,
        first,
        descents:,
      ))
      case descents == 1 {
        True -> Ok(Nil)
        False ->
          Error(InvalidSubpathInterval(
            from: canonical_to_subpath_parameter(previous),
            to: canonical_to_subpath_parameter(first),
          ))
      }
    }
    [point, ..rest] -> {
      use descents <- result.try(count_cyclic_descent(
        previous,
        point,
        descents:,
      ))
      case descents > 1 {
        True ->
          Error(InvalidSubpathInterval(
            from: canonical_to_subpath_parameter(previous),
            to: canonical_to_subpath_parameter(point),
          ))
        False ->
          validate_closed_subpath_split_points_loop(
            rest,
            first:,
            previous: point,
            descents:,
          )
      }
    }
  }
}

fn count_cyclic_descent(
  previous: CanonicalSubpathParameter,
  point: CanonicalSubpathParameter,
  descents descents: Int,
) -> Result(Int, Error) {
  case compare_canonical_subpath_parameters(previous, point) {
    order.Eq ->
      Error(InvalidSubpathInterval(
        from: canonical_to_subpath_parameter(previous),
        to: canonical_to_subpath_parameter(point),
      ))
    order.Gt -> Ok(descents + 1)
    order.Lt -> Ok(descents)
  }
}

fn subpaths_between_points(
  subpath: Subpath,
  points: List(CanonicalSubpathParameter),
) -> Result(List(Subpath), Error) {
  subpaths_between_pairs(subpath, adjacent_parameter_pairs(points))
}

fn subpaths_between_pairs(
  subpath: Subpath,
  pairs: List(#(CanonicalSubpathParameter, CanonicalSubpathParameter)),
) -> Result(List(Subpath), Error) {
  pairs
  |> list.fold(Ok([]), fn(subpaths, pair) {
    use subpaths <- result.try(subpaths)
    let #(from, to) = pair
    use subpath <- result.try(subpath_between_valid_parameters(
      subpath,
      from:,
      to:,
    ))
    Ok([subpath, ..subpaths])
  })
  |> result.map(list.reverse)
}

fn adjacent_parameter_pairs(
  points: List(CanonicalSubpathParameter),
) -> List(#(CanonicalSubpathParameter, CanonicalSubpathParameter)) {
  case points {
    [] | [_] -> []
    [first, second, ..rest] -> [
      #(first, second),
      ..adjacent_parameter_pairs([second, ..rest])
    ]
  }
}

fn cyclic_parameter_pairs(
  points: List(CanonicalSubpathParameter),
) -> List(#(CanonicalSubpathParameter, CanonicalSubpathParameter)) {
  case points {
    [] | [_] -> []
    [first, ..] -> cyclic_parameter_pairs_loop(points, first, [])
  }
}

fn cyclic_parameter_pairs_loop(
  points: List(CanonicalSubpathParameter),
  first first: CanonicalSubpathParameter,
  pairs pairs: List(#(CanonicalSubpathParameter, CanonicalSubpathParameter)),
) -> List(#(CanonicalSubpathParameter, CanonicalSubpathParameter)) {
  case points {
    [] -> list.reverse(pairs)
    [last] -> list.reverse([#(last, first), ..pairs])
    [left, right, ..rest] ->
      cyclic_parameter_pairs_loop([right, ..rest], first:, pairs: [
        #(left, right),
        ..pairs
      ])
  }
}

fn nth_segment(segments: List(Segment), index: Int) -> Result(Segment, Error) {
  case index < 0 {
    True -> Error(EmptySubpath)
    False ->
      case segments, index {
        [], _ -> Error(EmptySubpath)
        [segment, ..], 0 -> Ok(segment)
        [_, ..rest], _ -> nth_segment(rest, index - 1)
      }
  }
}

fn nth_subpath(subpaths: List(Subpath), index: Int) -> Result(Subpath, Error) {
  nth_subpath_loop(
    subpaths,
    index,
    requested_index: index,
    length: list.length(subpaths),
  )
}

fn nth_subpath_loop(
  subpaths: List(Subpath),
  index: Int,
  requested_index requested_index: Int,
  length length: Int,
) -> Result(Subpath, Error) {
  case index < 0 {
    True -> Error(InvalidPathParameter(subpath_index: requested_index, length:))
    False ->
      case subpaths, index {
        [], _ ->
          Error(InvalidPathParameter(subpath_index: requested_index, length:))
        [subpath, ..], 0 -> Ok(subpath)
        [_, ..rest], _ ->
          nth_subpath_loop(rest, index - 1, requested_index:, length:)
      }
  }
}

fn validate_spliced_subpath(
  segments: List(Segment),
  start start: Point,
  closed closed: Bool,
  policy policy: EndpointPolicy,
) -> Result(Subpath, Error) {
  let start = case segments {
    [] -> start
    [first, ..] -> segment_start(first)
  }

  case open_subpath_with_start(segments, start, policy) {
    Ok(subpath) -> {
      case closed {
        False -> Ok(subpath)
        True -> close_subpath_with(subpath, policy)
      }
    }
    Error(error) -> Error(error)
  }
}

fn open_subpath_with_segments(
  segments: List(Segment),
  policy: EndpointPolicy,
) -> Result(Subpath, Error) {
  use _ <- result.try(validate_endpoint_policy(policy))
  case segments {
    [] -> Error(EmptySubpath)
    [first, ..] ->
      open_subpath_with_start(segments, segment_start(first), policy)
  }
}

fn point_lines(points: List(Point)) -> List(Segment) {
  point_lines_loop(points, [])
}

fn point_lines_loop(
  points: List(Point),
  segments: List(Segment),
) -> List(Segment) {
  case points {
    [] | [_] -> list.reverse(segments)
    [start, end, ..rest] ->
      point_lines_loop([end, ..rest], [Line(start:, end:), ..segments])
  }
}

fn close_polygon_points(points: List(Point), first: Point) -> List(Point) {
  case list.last(points) {
    Ok(last) if last == first -> points
    _ -> list.append(points, [first])
  }
}

fn open_subpath_with_start(
  segments: List(Segment),
  start: Point,
  policy: EndpointPolicy,
) -> Result(Subpath, Error) {
  use _ <- result.try(validate_endpoint_policy(policy))
  let reconcile = endpoint_policy_custom(policy)
  use segments <- result.try(reconcile_start(start, segments, policy))

  custom_open_subpath_from(start, segments, reconcile)
}

fn endpoint_policy_custom(policy: EndpointPolicy) -> CustomPolicy {
  case policy {
    Strict -> strict_reconcile_segments
    Wiggle -> wiggle_reconcile_segments(default_wiggle_tolerance)
    WiggleWith(tolerance) -> wiggle_reconcile_segments(tolerance)
    Bridge -> bridge_reconcile_segments
    WiggleThenBridge ->
      wiggle_then_bridge_reconcile_segments(default_wiggle_tolerance)
    WiggleThenBridgeWith(tolerance) ->
      wiggle_then_bridge_reconcile_segments(tolerance)
    Custom(reconcile) -> reconcile
  }
}

fn reconcile_start(
  start: Point,
  segments: List(Segment),
  policy: EndpointPolicy,
) -> Result(List(Segment), Error) {
  case segments {
    [] -> Ok([])
    [first, ..rest] -> {
      case policy {
        Strict | Custom(_) -> {
          use _ <- result.try(starts_at(start, segments))
          Ok(segments)
        }
        Wiggle ->
          wiggle_start_segments(start, first, rest, default_wiggle_tolerance)
        WiggleWith(tolerance) ->
          wiggle_start_segments(start, first, rest, tolerance)
        WiggleThenBridge ->
          Ok(wiggle_then_bridge_start_segments(
            start,
            first,
            rest,
            default_wiggle_tolerance,
          ))
        WiggleThenBridgeWith(tolerance) ->
          Ok(wiggle_then_bridge_start_segments(start, first, rest, tolerance))
        Bridge -> Ok(bridge_start_segments(start, first, rest))
      }
    }
  }
}

fn wiggle_start_segments(
  start: Point,
  first: Segment,
  rest: List(Segment),
  tolerance: Float,
) -> Result(List(Segment), Error) {
  case distance(start, segment_start(first)) <=. tolerance {
    True -> Ok([segment_with_start(first, start), ..rest])
    False ->
      Error(Discontinuous(
        previous_index: -1,
        next_index: 0,
        expected: start,
        got: segment_start(first),
        distance: distance(start, segment_start(first)),
      ))
  }
}

fn bridge_start_segments(
  start: Point,
  first: Segment,
  rest: List(Segment),
) -> List(Segment) {
  let first_start = segment_start(first)
  case start == first_start {
    True -> [first, ..rest]
    False -> [Line(start:, end: first_start), first, ..rest]
  }
}

fn wiggle_then_bridge_start_segments(
  start: Point,
  first: Segment,
  rest: List(Segment),
  tolerance: Float,
) -> List(Segment) {
  case distance(start, segment_start(first)) <=. tolerance {
    True -> [segment_with_start(first, start), ..rest]
    False -> bridge_start_segments(start, first, rest)
  }
}

fn strict_reconcile_segments(
  previous: Segment,
  next: Segment,
  closing closing: Bool,
) -> List(Segment) {
  case closing {
    True -> [previous]
    False -> [previous, next]
  }
}

fn wiggle_reconcile_segments(tolerance: Float) -> CustomPolicy {
  fn(previous, next, closing) {
    case distance(segment_end(previous), segment_start(next)) <=. tolerance {
      True -> wiggle_nearby_segment_pair(previous, next, closing:)
      False -> strict_reconcile_segments(previous, next, closing:)
    }
  }
}

fn bridge_reconcile_segments(
  previous: Segment,
  next: Segment,
  closing closing: Bool,
) -> List(Segment) {
  let previous_end = segment_end(previous)
  let next_start = segment_start(next)

  case previous_end == next_start {
    True -> strict_reconcile_segments(previous, next, closing:)
    False -> {
      let bridge = Line(start: previous_end, end: next_start)
      case closing {
        True -> [previous, bridge]
        False -> [previous, bridge, next]
      }
    }
  }
}

fn wiggle_then_bridge_reconcile_segments(tolerance: Float) -> CustomPolicy {
  fn(previous, next, closing) {
    case distance(segment_end(previous), segment_start(next)) <=. tolerance {
      True -> wiggle_nearby_segment_pair(previous, next, closing:)
      False -> bridge_reconcile_segments(previous, next, closing:)
    }
  }
}

fn strict_open_subpath_from(
  start: Point,
  segments: List(Segment),
) -> Result(Subpath, Error) {
  case starts_at(start, segments) {
    Error(error) -> Error(error)
    Ok(Nil) -> {
      case continuous(segments) {
        Ok(Nil) -> Ok(Subpath(start:, segments:, closed: False))
        Error(error) -> Error(error)
      }
    }
  }
}

fn starts_at(start: Point, segments: List(Segment)) -> Result(Nil, Error) {
  case segments {
    [] -> Ok(Nil)
    [first, ..] -> {
      let got = segment_start(first)
      case got == start {
        True -> Ok(Nil)
        False ->
          Error(Discontinuous(
            previous_index: -1,
            next_index: 0,
            expected: start,
            got:,
            distance: distance(start, got),
          ))
      }
    }
  }
}

fn strict_open_subpath(segments: List(Segment)) -> Result(Subpath, Error) {
  case segments {
    [] -> Error(EmptySubpath)
    [first, ..] -> strict_open_subpath_from(segment_start(first), segments)
  }
}

fn custom_open_subpath_from(
  start: Point,
  segments: List(Segment),
  reconcile: CustomPolicy,
) -> Result(Subpath, Error) {
  custom_reconcile_segments(segments, [], reconcile, previous_index: 0)
  |> finish_custom_open_subpath(start)
}

fn custom_reconcile_segments(
  remaining: List(Segment),
  reversed_accumulated: List(Segment),
  reconcile: CustomPolicy,
  previous_index previous_index: Int,
) -> Result(List(Segment), Error) {
  case reversed_accumulated, remaining {
    [], [] -> Ok([])
    [], [next, ..rest] ->
      custom_reconcile_segments(rest, [next], reconcile, previous_index:)
    [previous, ..before], [] -> Ok(list.reverse([previous, ..before]))
    [previous, ..before], [next, ..rest] -> {
      let replacement = reconcile(previous, next, False)
      use replacement <- result.try(validate_custom_replacement(
        previous,
        replacement,
        previous_index:,
      ))
      let reversed_accumulated = list.append(list.reverse(replacement), before)

      custom_reconcile_segments(
        rest,
        reversed_accumulated,
        reconcile,
        previous_index: previous_index + list.length(replacement) - 1,
      )
    }
  }
}

fn validate_custom_replacement(
  previous: Segment,
  replacement: List(Segment),
  previous_index previous_index: Int,
) -> Result(List(Segment), Error) {
  case replacement {
    [] -> Ok([])
    [_, ..] -> {
      case strict_open_subpath_from(segment_start(previous), replacement) {
        Ok(subpath) -> Ok(subpath.segments)
        Error(error) -> Error(shift_discontinuous_error(error, previous_index))
      }
    }
  }
}

fn shift_discontinuous_error(error: Error, by offset: Int) -> Error {
  case error {
    Discontinuous(previous_index:, next_index:, expected:, got:, distance:) ->
      Discontinuous(
        previous_index: previous_index + offset,
        next_index: next_index + offset,
        expected:,
        got:,
        distance:,
      )
    _ -> error
  }
}

fn finish_custom_open_subpath(
  result: Result(List(Segment), Error),
  original_start: Point,
) -> Result(Subpath, Error) {
  case result {
    Error(error) -> Error(error)
    Ok([]) -> Ok(Subpath(start: original_start, segments: [], closed: False))
    Ok(segments) -> strict_open_subpath(segments)
  }
}

fn segments_arcs_to_cubic_beziers(
  segments: List(Segment),
  converted: List(Segment),
) -> List(Segment) {
  case segments {
    [] -> list.reverse(converted)
    [first, ..rest] -> {
      segments_arcs_to_cubic_beziers(
        rest,
        list.append(
          list.reverse(segment_arcs_to_cubic_beziers(first)),
          converted,
        ),
      )
    }
  }
}

fn segments_to_cubic_beziers(
  segments: List(Segment),
  converted: List(Segment),
) -> List(Segment) {
  case segments {
    [] -> list.reverse(converted)
    [first, ..rest] -> {
      segments_to_cubic_beziers(
        rest,
        list.append(list.reverse(segment_to_cubic_beziers(first)), converted),
      )
    }
  }
}

fn segment_to_lines_valid_options(
  segment: Segment,
  options: LinearizeOptions,
) -> Result(List(Segment), Error) {
  case segment {
    Line(..) -> Ok([segment])
    QuadraticBezier(..) | CubicBezier(..) ->
      bezier_segment_to_lines(segment, options, depth: 0)
    Arc(start:, end:, ..) -> {
      case arc_center_data(segment) {
        Error(_) -> Ok([Line(start:, end:)])
        Ok(arc) -> arc_to_lines(arc, start, end, options, depth: 0)
      }
    }
  }
}

fn bezier_segment_to_lines(
  segment: Segment,
  options: LinearizeOptions,
  depth depth: Int,
) -> Result(List(Segment), Error) {
  let error = bezier_chord_error(segment)
  case error <=. options.tolerance {
    True -> Ok([Line(start: segment_start(segment), end: segment_end(segment))])
    False -> {
      case depth >= options.max_depth {
        True -> Error(LinearizeMaxDepthReached(error:))
        False -> {
          use split <- result.try(segment_split(segment, at: 0.5))
          let #(left, right) = split
          use left <- result.try(bezier_segment_to_lines(
            left,
            options,
            depth: depth + 1,
          ))
          use right <- result.try(bezier_segment_to_lines(
            right,
            options,
            depth: depth + 1,
          ))
          Ok(list.append(left, right))
        }
      }
    }
  }
}

fn bezier_chord_error(segment: Segment) -> Float {
  case segment {
    QuadraticBezier(start:, control:, end:) ->
      point_to_line_projection(control, start, end).distance
    CubicBezier(start:, control1:, control2:, end:) ->
      float.max(
        point_to_line_projection(control1, start, end).distance,
        point_to_line_projection(control2, start, end).distance,
      )
    Line(..) | Arc(..) -> 0.0
  }
}

fn arc_to_lines(
  arc: ellipse.CenterArcData,
  start: Point,
  end: Point,
  options: LinearizeOptions,
  depth depth: Int,
) -> Result(List(Segment), Error) {
  let error = arc_chord_error_bound(arc)
  case error <=. options.tolerance {
    True -> Ok([Line(start:, end:)])
    False -> {
      case depth >= options.max_depth {
        True -> Error(LinearizeMaxDepthReached(error:))
        False -> {
          let #(left_arc, right_arc) = ellipse.split_arc(arc, at: 0.5)
          let middle = ellipse.arc_point(arc, at: 0.5) |> from_ellipse_point
          use left <- result.try(arc_to_lines(
            left_arc,
            start,
            middle,
            options,
            depth: depth + 1,
          ))
          use right <- result.try(arc_to_lines(
            right_arc,
            middle,
            end,
            options,
            depth: depth + 1,
          ))
          Ok(list.append(left, right))
        }
      }
    }
  }
}

fn arc_chord_error_bound(arc: ellipse.CenterArcData) -> Float {
  let radius =
    float.max(
      float.absolute_value(arc.radius.x),
      float.absolute_value(arc.radius.y),
    )
  let delta = float.absolute_value(arc.delta_angle)

  case delta >. 180.0 {
    True -> 2.0 *. radius
    False -> {
      radius *. float.max(0.0, 1.0 -. trig.cos_degrees(delta /. 2.0))
    }
  }
}

fn segments_to_lines(
  segments: List(Segment),
  options: LinearizeOptions,
  converted converted: List(Segment),
) -> Result(List(Segment), Error) {
  case segments {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use lines <- result.try(segment_to_lines_valid_options(first, options))
      segments_to_lines(
        rest,
        options,
        converted: list.append(list.reverse(lines), converted),
      )
    }
  }
}

fn subpaths_to_lines(
  subpaths: List(Subpath),
  options: LinearizeOptions,
  converted converted: List(Subpath),
) -> Result(List(Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use segments <- result.try(
        segments_to_lines(first.segments, options, converted: []),
      )
      subpaths_to_lines(rest, options, converted: [
        Subpath(..first, segments:),
        ..converted
      ])
    }
  }
}

fn line_to_cubic(start: Point, end: Point) -> Segment {
  CubicBezier(
    start:,
    control1: interpolate(start, end, 1.0 /. 3.0),
    control2: interpolate(start, end, 2.0 /. 3.0),
    end:,
  )
}

fn quadratic_to_cubic(start: Point, control: Point, end: Point) -> Segment {
  CubicBezier(
    start:,
    control1: Point(
      start.x +. 2.0 /. 3.0 *. { control.x -. start.x },
      start.y +. 2.0 /. 3.0 *. { control.y -. start.y },
    ),
    control2: Point(
      end.x +. 2.0 /. 3.0 *. { control.x -. end.x },
      end.y +. 2.0 /. 3.0 *. { control.y -. end.y },
    ),
    end:,
  )
}

fn cubic_from_ellipse(cubic: ellipse.Cubic) -> Segment {
  let ellipse.Cubic(start:, control1:, control2:, end:) = cubic

  CubicBezier(
    start: from_ellipse_point(start),
    control1: from_ellipse_point(control1),
    control2: from_ellipse_point(control2),
    end: from_ellipse_point(end),
  )
}

fn cubic_segments_from_ellipse(
  cubics: List(ellipse.Cubic),
  start: Point,
  end: Point,
) -> List(Segment) {
  cubics
  |> list.map(cubic_from_ellipse)
  |> force_cubic_start(start)
  |> force_cubic_end(end)
}

fn force_cubic_start(segments: List(Segment), start: Point) -> List(Segment) {
  case segments {
    [] -> []
    [CubicBezier(control1:, control2:, end:, ..), ..rest] -> [
      CubicBezier(start:, control1:, control2:, end:),
      ..rest
    ]
    [first, ..rest] -> [first, ..rest]
  }
}

fn force_cubic_end(segments: List(Segment), end: Point) -> List(Segment) {
  case segments {
    [] -> []
    [only] -> [segment_with_end(only, end)]
    [first, ..rest] -> [first, ..force_cubic_end(rest, end)]
  }
}

fn to_ellipse_point(point: Point) -> ellipse.EllipsePoint {
  ellipse.EllipsePoint(point.x, point.y)
}

fn from_ellipse_point(point: ellipse.EllipsePoint) -> Point {
  Point(point.x, point.y)
}

fn to_bezier_point(point: Point) -> bezier.BezierPoint {
  bezier.BezierPoint(point.x, point.y)
}

fn from_bezier_point(point: bezier.BezierPoint) -> Point {
  Point(point.x, point.y)
}

fn from_bezier_fit_report(report: bezier.CubicFitReport) -> CubicFitReport {
  CubicFitReport(
    root_sum_square: report.root_sum_square,
    root_mean_square: report.root_mean_square,
    max: report.max,
  )
}

fn from_bezier_error(error: bezier.Error) -> Error {
  case error {
    bezier.DegenerateTangent -> DegenerateCubicFitTangent
    bezier.UnderdeterminedCubicFit -> UnderdeterminedCubicFit
    bezier.SplitOutsideBezier -> ParametricFitFailed
    bezier.InvalidCubicSelfIntersectionMinimumArcLengthSeparation(_) ->
      ParametricFitFailed
    bezier.InvalidCubicSelfIntersectionDistanceTolerance(_) ->
      ParametricFitFailed
  }
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

fn segment_from_bezier_data(data: bezier.BezierData) -> Segment {
  case data {
    bezier.LinearBezierData(start:, end:) -> {
      Line(start: from_bezier_point(start), end: from_bezier_point(end))
    }
    bezier.QuadraticBezierData(start:, control:, end:) -> {
      QuadraticBezier(
        start: from_bezier_point(start),
        control: from_bezier_point(control),
        end: from_bezier_point(end),
      )
    }
    bezier.CubicBezierData(start:, control1:, control2:, end:) -> {
      CubicBezier(
        start: from_bezier_point(start),
        control1: from_bezier_point(control1),
        control2: from_bezier_point(control2),
        end: from_bezier_point(end),
      )
    }
  }
}

/// Return an elliptical arc segment as center-parameter arc data.
pub fn arc_center_data(
  segment: Segment,
) -> Result(ellipse.CenterArcData, Error) {
  case segment {
    Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:) -> {
      let endpoint =
        ellipse.EndpointArcData(
          start: to_ellipse_point(start),
          radius: to_ellipse_point(radius),
          x_axis_rotation:,
          large_arc:,
          sweep:,
          end: to_ellipse_point(end),
        )

      case ellipse.endpoint_to_center(endpoint) {
        Error(_) -> Error(DegenerateArc)
        Ok(arc) -> Ok(arc)
      }
    }
    Line(..) | QuadraticBezier(..) | CubicBezier(..) -> {
      Error(DegenerateArc)
    }
  }
}

/// Evaluate an arc segment at parameter `t`.
///
/// This is a root-module convenience wrapper around `ellipse.arc_point` that
/// accepts an `svg_path.Arc` segment and returns `svg_path.Point`. Non-arc
/// segments return `DegenerateArc`.
pub fn arc_point(segment: Segment, at t: Float) -> Result(Point, Error) {
  use arc <- result.try(arc_center_data(segment))

  Ok(ellipse.arc_point(arc, at: t) |> from_ellipse_point)
}

/// Return an arc segment's derivative with respect to parameter `t`.
///
/// This is a root-module convenience wrapper around `ellipse.arc_derivative`
/// that accepts an `svg_path.Arc` segment and returns `svg_path.Point`.
/// Non-arc segments return `DegenerateArc`.
pub fn arc_derivative(segment: Segment, at t: Float) -> Result(Point, Error) {
  use arc <- result.try(arc_center_data(segment))

  Ok(ellipse.arc_derivative(arc, at: t) |> from_ellipse_point)
}

/// Evaluate an arc segment at an ellipse angle in degrees.
///
/// This is a root-module convenience wrapper around
/// `ellipse.arc_point_at_angle` that accepts an `svg_path.Arc` segment and
/// returns `svg_path.Point`. Non-arc segments return `DegenerateArc`.
pub fn arc_point_at_angle(
  segment: Segment,
  angle angle: Float,
) -> Result(Point, Error) {
  use arc <- result.try(arc_center_data(segment))

  Ok(ellipse.arc_point_at_angle(arc, angle: angle) |> from_ellipse_point)
}

/// Return an arc segment's derivative at an ellipse angle in degrees.
///
/// This is a root-module convenience wrapper around
/// `ellipse.arc_derivative_at_angle` that accepts an `svg_path.Arc` segment and
/// returns `svg_path.Point`. Non-arc segments return `DegenerateArc`.
pub fn arc_derivative_at_angle(
  segment: Segment,
  angle angle: Float,
) -> Result(Point, Error) {
  use arc <- result.try(arc_center_data(segment))

  Ok(ellipse.arc_derivative_at_angle(arc, angle: angle) |> from_ellipse_point)
}

/// Return the ellipse angle, in degrees, reached at arc parameter `t`.
///
/// This is a root-module convenience wrapper around `ellipse.angle_at`.
/// Non-arc segments return `DegenerateArc`.
pub fn arc_angle_at(segment: Segment, t t: Float) -> Result(Float, Error) {
  use arc <- result.try(arc_center_data(segment))

  Ok(ellipse.angle_at(arc, t: t))
}

/// Return the end angle, in degrees, of an arc segment.
///
/// This is a root-module convenience wrapper around `ellipse.arc_end_angle`.
/// Non-arc segments return `DegenerateArc`.
pub fn arc_end_angle(segment: Segment) -> Result(Float, Error) {
  use arc <- result.try(arc_center_data(segment))

  Ok(ellipse.arc_end_angle(arc))
}

fn interpolate(start: Point, end: Point, t: Float) -> Point {
  Point(
    start.x +. { end.x -. start.x } *. t,
    start.y +. { end.y -. start.y } *. t,
  )
}

/// Create an elliptical arc segment from endpoint-parameter arc data.
pub fn arc_from_endpoint_data(data: ellipse.EndpointArcData) -> Segment {
  Arc(
    start: from_ellipse_point(data.start),
    radius: from_ellipse_point(data.radius),
    x_axis_rotation: data.x_axis_rotation,
    large_arc: data.large_arc,
    sweep: data.sweep,
    end: from_ellipse_point(data.end),
  )
}

/// Create an elliptical arc segment from center-parameter arc data.
pub fn arc_from_center_data(data: ellipse.CenterArcData) -> Segment {
  let endpoint = ellipse.center_to_endpoint(data)

  arc_from_endpoint_data(endpoint)
}

fn nonempty_subpaths(subpaths: List(Subpath)) -> List(Subpath) {
  subpaths
  |> list.filter(keeping: fn(subpath) { !list.is_empty(subpath.segments) })
}

fn continuous(segments: List(Segment)) -> Result(Nil, Error) {
  continuous_from(segments, previous_index: 0)
}

fn continuous_from(
  segments: List(Segment),
  previous_index previous_index: Int,
) -> Result(Nil, Error) {
  case segments {
    [] | [_] -> Ok(Nil)
    [left, right, ..rest] -> {
      let left_end = segment_end(left)
      let right_start = segment_start(right)

      case left_end == right_start {
        True -> continuous_from([right, ..rest], previous_index + 1)
        False ->
          Error(Discontinuous(
            previous_index:,
            next_index: previous_index + 1,
            expected: left_end,
            got: right_start,
            distance: distance(left_end, right_start),
          ))
      }
    }
  }
}

fn close_subpath_with(
  subpath: Subpath,
  policy: EndpointPolicy,
) -> Result(Subpath, Error) {
  use _ <- result.try(validate_endpoint_policy(policy))
  case subpath.closed {
    True -> Ok(subpath)
    False -> close_open_subpath_with(subpath, policy)
  }
}

fn validate_endpoint_policy(policy: EndpointPolicy) -> Result(Nil, Error) {
  case policy {
    WiggleWith(tolerance) | WiggleThenBridgeWith(tolerance) ->
      case tolerance <. 0.0 || !number.is_finite(tolerance) {
        True -> Error(InvalidWiggleTolerance(tolerance))
        False -> Ok(Nil)
      }
    _ -> Ok(Nil)
  }
}

fn close_open_subpath_with(
  subpath: Subpath,
  policy: EndpointPolicy,
) -> Result(Subpath, Error) {
  let reconcile = endpoint_policy_custom(policy)
  custom_close_open_subpath(subpath, reconcile)
}

fn custom_close_open_subpath(
  subpath: Subpath,
  reconcile: CustomPolicy,
) -> Result(Subpath, Error) {
  case subpath.segments {
    [] -> Ok(Subpath(..subpath, closed: True))
    [only] -> {
      let replacement = reconcile(only, only, True)
      use replacement <- result.try(validate_custom_replacement(
        only,
        replacement,
        previous_index: 0,
      ))
      validate_custom_closed_segments(subpath.start, replacement)
    }
    [first, ..rest] -> {
      let assert Ok(#(middle, last)) = split_last(rest)
      let replacement = reconcile(last, first, True)
      use replacement <- result.try(validate_custom_replacement(
        last,
        replacement,
        previous_index: 0,
      ))
      validate_custom_closed_segments(
        subpath.start,
        list.append([first, ..middle], replacement),
      )
    }
  }
}

fn validate_custom_closed_segments(
  start: Point,
  segments: List(Segment),
) -> Result(Subpath, Error) {
  case segments {
    [] -> Ok(Subpath(start:, segments:, closed: True))
    _ -> {
      case strict_open_subpath_from(start, segments) {
        Error(error) -> Error(error)
        Ok(subpath) -> validate_closed_subpath_end(subpath)
      }
    }
  }
}

fn validate_closed_subpath_end(subpath: Subpath) -> Result(Subpath, Error) {
  use last <- result.try(subpath_end(subpath))
  case subpath.start == last {
    True -> Ok(Subpath(..subpath, closed: True))
    False -> {
      let previous_index = list.length(subpath.segments) - 1

      Error(Discontinuous(
        previous_index:,
        next_index: 0,
        expected: subpath.start,
        got: last,
        distance: distance(subpath.start, last),
      ))
    }
  }
}

fn distance(a: Point, b: Point) -> Float {
  number.hypot(a.x -. b.x, a.y -. b.y)
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

fn wiggle_nearby_segment_pair(
  previous: Segment,
  next: Segment,
  closing closing: Bool,
) -> List(Segment) {
  case same_axis_bridge_segments(previous, next, closing:) {
    Some(segments) -> segments
    None -> wiggle_nearby_segments(previous, next, closing:)
  }
}

fn same_axis_bridge_segments(
  previous: Segment,
  next: Segment,
  closing closing: Bool,
) -> Option(List(Segment)) {
  case previous, next {
    Line(start: previous_start, end: previous_end),
      Line(start: next_start, end: next_end)
    -> {
      let horizontal_misalignment =
        line_is_horizontal(previous_start, previous_end)
        && line_is_horizontal(next_start, next_end)
        && previous_end.y != next_start.y
      let vertical_misalignment =
        line_is_vertical(previous_start, previous_end)
        && line_is_vertical(next_start, next_end)
        && previous_end.x != next_start.x

      case horizontal_misalignment || vertical_misalignment {
        True -> {
          let bridge = Line(start: previous_end, end: next_start)
          case closing {
            True -> Some([previous, bridge])
            False -> Some([previous, bridge, next])
          }
        }
        False -> None
      }
    }
    _, _ -> None
  }
}

fn wiggle_nearby_segments(
  previous: Segment,
  next: Segment,
  closing closing: Bool,
) -> List(Segment) {
  let previous_end = segment_end(previous)
  let next_start = segment_start(next)
  let join =
    Point(
      wiggle_x(previous, next, previous_end, next_start),
      wiggle_y(previous, next, previous_end, next_start),
    )

  case closing {
    True -> [segment_with_end(previous, next_start)]
    False -> [
      segment_with_end(previous, join),
      segment_with_start(next, join),
    ]
  }
}

fn line_is_horizontal(start: Point, end: Point) -> Bool {
  start.y == end.y
}

fn line_is_vertical(start: Point, end: Point) -> Bool {
  start.x == end.x
}

fn wiggle_x(
  previous: Segment,
  next: Segment,
  previous_end: Point,
  next_start: Point,
) -> Float {
  case segment_is_vertical(previous) {
    True -> previous_end.x
    False -> {
      case segment_is_vertical(next) {
        True -> next_start.x
        False -> midpoint(previous_end, next_start).x
      }
    }
  }
}

fn wiggle_y(
  previous: Segment,
  next: Segment,
  previous_end: Point,
  next_start: Point,
) -> Float {
  case segment_is_horizontal(previous) {
    True -> previous_end.y
    False -> {
      case segment_is_horizontal(next) {
        True -> next_start.y
        False -> midpoint(previous_end, next_start).y
      }
    }
  }
}

fn segment_is_vertical(segment: Segment) -> Bool {
  case segment {
    Line(start:, end:) -> start.x == end.x
    _ -> False
  }
}

fn segment_is_horizontal(segment: Segment) -> Bool {
  case segment {
    Line(start:, end:) -> start.y == end.y
    _ -> False
  }
}

fn split_last(items: List(a)) -> Result(#(List(a), a), Error) {
  case items {
    [] -> Error(EmptySubpath)
    [only] -> Ok(#([], only))
    [first, ..rest] -> {
      case split_last(rest) {
        Ok(#(middle, last)) -> Ok(#([first, ..middle], last))
        Error(error) -> Error(error)
      }
    }
  }
}

fn segment_with_start(segment: Segment, new_start: Point) -> Segment {
  case segment {
    Line(end:, ..) -> Line(start: new_start, end:)
    QuadraticBezier(control:, end:, ..) -> {
      QuadraticBezier(start: new_start, control:, end:)
    }
    CubicBezier(control1:, control2:, end:, ..) -> {
      CubicBezier(start: new_start, control1:, control2:, end:)
    }
    Arc(radius:, x_axis_rotation:, large_arc:, sweep:, end:, ..) -> {
      Arc(start: new_start, radius:, x_axis_rotation:, large_arc:, sweep:, end:)
    }
  }
}

fn segment_with_end(segment: Segment, new_end: Point) -> Segment {
  case segment {
    Line(start:, ..) -> Line(start:, end: new_end)
    QuadraticBezier(start:, control:, ..) -> {
      QuadraticBezier(start:, control:, end: new_end)
    }
    CubicBezier(start:, control1:, control2:, ..) -> {
      CubicBezier(start:, control1:, control2:, end: new_end)
    }
    Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, ..) -> {
      Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end: new_end)
    }
  }
}

fn segment_with_start_and_end(
  segment: Segment,
  new_start: Point,
  new_end: Point,
) -> Segment {
  segment
  |> segment_with_start(new_start)
  |> segment_with_end(new_end)
}
