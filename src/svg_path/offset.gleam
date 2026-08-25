//// Path offset construction.
////
//// This module follows the same basic model as `svgpathsio`: lines and
//// circular arcs are offset exactly, while other curves are offset by fitted
//// cubic Beziers. Cubic approximations are checked by sampling the true normal
//// extrusion of the source curve and measuring its distance to the proposed
//// offset. If the error is too large, the source curve is split and each half
//// is offset recursively.
////
//// Subpath and path offsets first normalize the source, split it into
//// not-stalled and stalled pieces, build an untrimmed one-sided offset walk,
//// and connect adjacent offset pieces with the requested join style. The
//// public trimmed single offset builds one arrangement from that walk and its
//// final refined zero-offset source pieces. Zero-source-only edges are removed
//// directly; offset edges are classified against an offset-band inside
//// predicate before unsupported edges are burned. Survivors are reconstructed
//// in untrimmed traversal order.
//// Because trimming can split an offset or remove it entirely, subpath and
//// path offsets return `Path`.
////
//// The `*_untrimmed` helpers expose the untrimmed offset walk directly. It
//// is useful for debugging, drawing raw construction geometry, or implementing
//// a different trimming policy.
////
//// `subpath_band` and `path_band` construct two signed offset walks and trim
//// them together without adding endpoint caps. `subpath_stroke` and
//// `path_stroke` add endpoint caps for open subpaths. Closed strokes use the
//// same capless per-subpath band construction.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import svg_path
import svg_path/area
import svg_path/arrangement as arrangement_graph
import svg_path/bezier
import svg_path/curvature
import svg_path/degeneracy
import svg_path/internal/number
import svg_path/intersections
import svg_path/point as point_helpers
import svg_path/root
import svg_path/trig

const default_tolerance = 0.01

const default_max_depth = 20

const default_samples = 10

const default_trimming_samples = 5

const default_miter_limit = 4.0

const tangent_epsilon = 0.000001

const point_tolerance = 0.000000001

const arrangement_tolerance = 0.000000002

const submerged_side_sampling_distance = 0.00000005

const curvature_parameter_tolerance = 0.000001

const default_tangent_heal_angle_degrees = 2.0

const join_free_tangent_alignment_angle_degrees = 0.001

const tangent_heal_agreement_angle_degrees = 2.0

const source_tangent_colinearization_angle_degrees = 2.0

const reversal_tangent_gap_degrees = 1.0

const reversal_fit_tangent_nudge_degrees = 0.5

const reversal_fit_line_aperture_degrees = 2.0

const reversal_fit_min_handle_chord_ratio = 0.1

const reversal_fit_max_handle_chord_ratio = 0.9

const tangent_turn_curvature_epsilon = 0.000000001

const tangent_turn_angle_epsilon = 0.001

const stable_tangent_assertion_diameter = 0.01

const default_stalled_offset_diameter = 0.01

/// Errors returned by offset helpers.
pub type Error {
  /// An underlying path operation failed.
  PathError(svg_path.Error)

  /// Arrangement construction failed while noding offset geometry.
  ArrangementGraphError(arrangement_graph.Error)

  /// Source normalization failed before offset construction.
  SourceNormalizationError(degeneracy.Error)

  /// The offset tolerance must be finite and greater than zero.
  InvalidTolerance(tolerance: Float)

  /// The number of divergence samples must be greater than zero.
  InvalidSamples(samples: Int)

  /// The recursive subdivision limit must be greater than zero.
  InvalidMaxDepth(max_depth: Int)

  /// The miter limit must be finite and greater than zero.
  InvalidMiterLimit(miter_limit: Float)

  /// The stalled offset diameter must be finite and non-negative.
  InvalidStalledOffsetDiameter(diameter: Float)

  /// Stroke width must be finite and greater than zero.
  InvalidStrokeWidth(width: Float)

  /// Band payloads used for inside classification must be closed.
  BandSubpathNotClosed

  /// A closed band or stroke candidate produced non-loop arrangement edges.
  BandOddSkeletonNotEmpty

  /// A segment tangent was too small to define a stable normal direction.
  DegenerateTangent(t: Float)

  /// Refinement could not produce an offset within the requested tolerance.
  MaxDepthReached(error: Float)

  /// A calculation produced a non-finite coordinate.
  NonFinite
}

/// Join style used when offsetting adjacent subpath segments.
///
/// This covers the common SVG `stroke-linejoin` values `bevel`, `miter`, and
/// `round`. SVG 2 also describes `miter-clip` and `arcs`; those are not exposed
/// here yet.
pub type Join {
  /// Connect adjacent offset segments with a straight line.
  Bevel

  /// Extend the offset tangents toward their intersection when the miter stays
  /// within `miter_limit`; otherwise fall back to `Bevel`.
  Miter(miter_limit: Float)

  /// Connect adjacent offset segments with a circular SVG arc.
  Round
}

/// Cap style used at open stroke endpoints.
pub type Cap {
  /// End the stroke exactly at the endpoint.
  Butt

  /// Extend the stroke by half its width beyond the endpoint.
  Square

  /// Add a semicircular endpoint cap.
  RoundCap
}

/// Closed band payload produced from one source subpath before trimming.
///
/// `OpenSubpathBand` is the closed outline produced from an open source
/// subpath after caps are added. `ClosedSubpathBand` stores the two closed
/// offset sides of a closed source subpath in corresponding source traversal
/// order; semantically, the second side is reversed before nonzero containment
/// is evaluated.
@internal
pub type OneSubpathBand {
  OpenSubpathBand(outline: svg_path.Subpath)
  ClosedSubpathBand(side_a: svg_path.Subpath, side_b: svg_path.Subpath)
}

/// Cubic fitting controls used by the recursive offset builders.
///
/// `tolerance` bounds the sampled geometric error of a fitted offset curve,
/// `samples` controls the number of check samples, and `max_depth` limits
/// recursive subdivision.
pub type FittingOptions {
  FittingOptions(tolerance: Float, samples: Int, max_depth: Int)
}

/// Options for offset construction.
///
/// `fitting` controls offset approximation. `trimming` controls projection and
/// root-finding used while pruning. `stalled_offset_diameter` decides when the
/// stalled-run builder treats an offset piece as too small to keep as an
/// ordinary independently fitted segment. `tangent_heal_angle_degrees` is the
/// maximum tangent direction mismatch, in degrees, allowed by post-healing
/// continuity checks at stable smooth boundaries.
pub type Options {
  Options(
    fitting: FittingOptions,
    trimming: svg_path.DistanceOptions,
    stalled_offset_diameter: Float,
    tangent_heal_angle_degrees: Float,
    join: Join,
  )
}

type LengthSpan {
  LengthSpan(segment: svg_path.Segment, start_distance: Float, length: Float)
}

type FUnhealedOffsetSegment {
  FUnhealedOffsetSegment(
    segment: svg_path.Segment,
    source: OffsetSegmentSource,
    nudged_start_tangent_direction: svg_path.Point,
    nudged_end_tangent_direction: svg_path.Point,
  )
}

type GHealedOffsetSegment {
  GHealedOffsetSegment(
    segment: svg_path.Segment,
    source: OffsetSegmentSource,
    nudged_start_tangent_direction: svg_path.Point,
    nudged_end_tangent_direction: svg_path.Point,
  )
}

@internal
pub type OffsetSegmentSource {
  OffsetFromJoinFree(EJoinFreeSegment)
  OffsetFromStalledRun(List(CStalledSegment))
}

@internal
pub type APreparedSegment {
  APreparedSegment(
    source_subpath_index: Int,
    source_segment_index: Int,
    segment: svg_path.Segment,
  )
}

type BClassifiedSegment {
  BNotStalled(CNotStalledSegment)
  BStalled(CStalledSegment)
}

type CNotStalledSegment {
  CNotStalledSegment(
    prepared: APreparedSegment,
    start_boundary: BoundaryKind,
    end_boundary: BoundaryKind,
  )
}

@internal
pub type CStalledSegment {
  CStalledSegment(
    prepared: APreparedSegment,
    prepared_from: Float,
    prepared_to: Float,
    segment: svg_path.Segment,
  )
}

type DOffsetPiece {
  DNotStalled(DRefinedSegment)
  DStalled(CStalledSegment)
}

@internal
pub type DRefinedSegment {
  DRefinedSegment(
    prepared: APreparedSegment,
    prepared_from: Float,
    prepared_to: Float,
    segment: svg_path.Segment,
    start_boundary: BoundaryKind,
    end_boundary: BoundaryKind,
  )
}

@internal
pub type EJoinFreeSegment {
  EJoinFreeSegment(
    portion_index: Int,
    segment_index: Int,
    generation: Int,
    refined: DRefinedSegment,
    refined_from: Float,
    refined_to: Float,
    segment: svg_path.Segment,
    start_boundary: BoundaryKind,
    end_boundary: BoundaryKind,
  )
}

type SegmentEndpoint {
  SegmentStart
  SegmentEnd
}

type CubicEndpointFitPolicy {
  FitPositionOnly
  FitPositionAndDirection(direction: svg_path.Point)
  FitPositionAndDirectionWithCollapsedHandle(direction: svg_path.Point)
}

/// Tangent turn direction in the package's SVG screen-coordinate convention.
///
/// Positive y points downward, so `Clockwise` means visual clockwise.
@internal
pub type TangentTurn {
  Clockwise
  CounterClockwise
  Straight
  CouldNotMeasure
}

/// Signed tangent rotations for a reversal boundary.
///
/// Positive angles rotate clockwise in SVG coordinates. Negative angles rotate
/// counterclockwise.
@internal
pub type ReversalTangentAdjustment {
  ReversalTangentAdjustment(incoming_degrees: Float, outgoing_degrees: Float)
}

/// Diagnostic view of one join-free portion in the actual offset pipeline.
@internal
pub type OffsetSourceTracePortion {
  OffsetSourceTracePortion(
    index: Int,
    subpath: svg_path.Subpath,
    pieces: List(OffsetSourceTracePiece),
  )
}

/// Diagnostic view of one source piece inside a join-free portion.
@internal
pub type OffsetSourceTracePiece {
  OffsetSourceTraceDRefined(
    source_segment_index: Int,
    refined_piece_index: Int,
    source_from: Float,
    source_to: Float,
    segment: svg_path.Segment,
    start_is_reversal: Bool,
    end_is_reversal: Bool,
  )
  OffsetSourceTraceStalled(source_segment_index: Int, segment: svg_path.Segment)
}

/// Diagnostic snapshot of the production single-offset arrangement before
/// unsupported-edge burning.
@internal
pub type SingleOffsetArrangementTrace {
  SingleOffsetArrangementTrace(
    source: svg_path.Subpath,
    untrimmed: svg_path.Subpath,
    semantic_paths: List(svg_path.Path),
    graph: arrangement_graph.ArrangementGraph,
    edges: List(SingleOffsetArrangementTraceEdge),
  )
}

/// Initial production classification of one single-offset arrangement edge.
@internal
pub type SingleOffsetArrangementTraceEdge {
  SingleOffsetArrangementTraceEdge(
    edge: arrangement_graph.ArrangementEdge,
    submerged: Bool,
    zero_source_only: Bool,
  )
}

type OffsetArrangementBuild {
  OffsetArrangementBuild(
    graph: arrangement_graph.ArrangementGraph,
    indexed_segments: List(IndexedOffsetSegment),
    segment_images: List(arrangement_graph.ArrangementSourceSegmentImage),
    edge_images: List(arrangement_graph.ArrangementEdgeImage),
  )
}

type OffsetArrangementSegmentGroup {
  UntrimmedOffsetSegment
  ZeroOffsetSourceSegment
}

type SingleOffsetUntrimmedBuild {
  SingleOffsetUntrimmedBuild(
    subpath: svg_path.Subpath,
    zero_source: svg_path.Subpath,
  )
}

type OffsetSegmentsBuild {
  OffsetSegmentsBuild(
    offsets: List(GHealedOffsetSegment),
    zero_source_segments: List(svg_path.Segment),
  )
}

type IndexedOffsetSegment {
  IndexedOffsetSegment(
    group: OffsetArrangementSegmentGroup,
    subpath_index: Int,
    segment: svg_path.Segment,
  )
}

type SurvivorEdge {
  SurvivorEdge(
    edge_id: Int,
    start_vertex: Int,
    end_vertex: Int,
    segment: svg_path.Segment,
  )
}

type SurvivorChain {
  SurvivorChain(
    start_vertex: Int,
    end_vertex: Int,
    segments: List(svg_path.Segment),
    closed: Bool,
  )
}

type JoinFreePortion {
  JoinFreePortion(index: Int, subpath: svg_path.Subpath, closed: Bool)
}

type SplitParameter {
  SplitParameter(t: Float, cut: Bool)
}

type SplitPiece {
  SplitPiece(segment: svg_path.Segment, start_is_cut: Bool, end_is_cut: Bool)
}

@internal
pub type BoundaryKind {
  Ordinary
  ReversalBoundary
  Inflection
  NonReversalBoundaryTouch
}

type CurvatureSplitKind {
  OrdinarySplit
  CuspSplit
  InflectionSplit
}

type CurvatureSplitParameter {
  CurvatureSplitParameter(t: Float, kind: CurvatureSplitKind)
}

type CurvatureBoundary {
  CurvatureBoundary(t: Float, boundary: BoundaryKind)
}

type OffsetCurvatureZone {
  OutsideOffsetRadius
  InsideOffsetRadius
  Opposite
  UnknownCurvatureZone
}

/// Return default options for offset construction.
pub fn default_fitting_options() -> FittingOptions {
  FittingOptions(
    tolerance: default_tolerance,
    samples: default_samples,
    max_depth: default_max_depth,
  )
}

/// Return default options for offset construction.
pub fn default_options() -> Options {
  Options(
    fitting: default_fitting_options(),
    trimming: default_trimming_options(),
    stalled_offset_diameter: default_stalled_offset_diameter,
    tangent_heal_angle_degrees: default_tangent_heal_angle_degrees,
    join: Miter(default_miter_limit),
  )
}

/// Build the nonzero inside predicate for closed band payloads.
@internal
pub fn internal_band_inside_function(
  bands: List(OneSubpathBand),
) -> Result(fn(svg_path.Point) -> Result(Bool, Error), Error) {
  use semantic_paths <- result.try(
    one_subpath_band_semantic_paths(bands, paths: []),
  )
  Ok(fn(point) { point_inside_any_semantic_band(point, semantic_paths) })
}

/// Classify whether both immediate sides of a segment lie inside a predicate.
@internal
pub fn internal_segment_is_submerged(
  segment: svg_path.Segment,
  inside inside: fn(svg_path.Point) -> Result(Bool, Error),
  side_sampling_distance side_sampling_distance: Float,
) -> Result(Bool, Error) {
  submerged_segment(segment, inside:, side_sampling_distance:)
}

/// Remove loops whose weighted majority of segments is submerged.
@internal
pub fn internal_filter_band_loops(
  loops: List(svg_path.Subpath),
  inside inside: fn(svg_path.Point) -> Result(Bool, Error),
  side_sampling_distance side_sampling_distance: Float,
) -> Result(List(svg_path.Subpath), Error) {
  filter_band_loops(loops, inside:, side_sampling_distance:, retained: [])
}

/// Extract closed even contours from a closed provisional band or stroke.
@internal
pub fn internal_closed_candidate_even_contours(
  provisional: List(svg_path.Subpath),
  options options: Options,
) -> Result(List(svg_path.Subpath), Error) {
  closed_candidate_even_contours(provisional, options)
}

/// Extract and filter band loops using the band inside predicate.
@internal
pub fn internal_topological_band_loops(
  provisional: List(svg_path.Subpath),
  bands bands: List(OneSubpathBand),
  options options: Options,
) -> Result(List(svg_path.Subpath), Error) {
  use inside <- result.try(internal_band_inside_function(bands))
  burn_pruned_band_survivors(provisional, inside:, options:)
}

/// Extract, filter, and orient band loops as a path.
@internal
pub fn internal_topological_band_path(
  provisional: List(svg_path.Subpath),
  bands bands: List(OneSubpathBand),
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use loops <- result.try(internal_topological_band_loops(
    provisional,
    bands:,
    options:,
  ))
  orient_outline_path(svg_path.Path(subpaths: loops))
}

fn single_offset_survivor_subpaths(
  untrimmed: List(svg_path.Subpath),
  zero_source_segments zero_source_segments: List(svg_path.Segment),
  bands bands: List(OneSubpathBand),
  options options: Options,
) -> Result(List(svg_path.Subpath), Error) {
  use inside <- result.try(internal_band_inside_function(bands))
  burn_pruned_single_offset_survivors(
    untrimmed,
    zero_source_segments:,
    inside:,
    options:,
  )
}

fn trim_single_offset_path(
  untrimmed: List(svg_path.Subpath),
  zero_source_segments zero_source_segments: List(svg_path.Segment),
  bands bands: List(OneSubpathBand),
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use loops <- result.try(single_offset_survivor_subpaths(
    untrimmed,
    zero_source_segments:,
    bands:,
    options:,
  ))
  use oriented <- result.try(
    orient_outline_path(svg_path.Path(subpaths: loops)),
  )
  Ok(oriented)
}

/// Build the exact closed band used to classify one single-sided offset.
@internal
pub fn internal_single_offset_band_candidate(
  source: svg_path.Subpath,
  distance distance: Float,
  options options: Options,
) -> Result(OneSubpathBand, Error) {
  use _ <- result.try(validate_options(options))
  use normalized <- result.try(normalize_source_subpath(source, options))
  use build <- result.try(build_single_offset_untrimmed(
    normalized,
    distance:,
    options:,
  ))
  single_offset_band_from_sides(build.zero_source, build.subpath)
}

/// Return the production single-offset arrangement and its initial edge
/// classifications before unsupported-edge burning.
@internal
pub fn internal_single_offset_arrangement_trace(
  subpath subpath: svg_path.Subpath,
  distance distance: Float,
  options options: Options,
) -> Result(SingleOffsetArrangementTrace, Error) {
  use _ <- result.try(validate_options(options))
  use normalized <- result.try(normalize_source_subpath(subpath, options))
  use untrimmed_build <- result.try(build_single_offset_untrimmed(
    normalized,
    distance:,
    options:,
  ))
  let SingleOffsetUntrimmedBuild(subpath: untrimmed, zero_source:) =
    untrimmed_build
  use band <- result.try(single_offset_band_from_sides(zero_source, untrimmed))
  use semantic_paths <- result.try(
    one_subpath_band_semantic_paths([band], paths: []),
  )
  let inside = fn(point) {
    point_inside_any_semantic_band(point, semantic_paths)
  }
  use build <- result.try(single_offset_segment_arrangement(
    [untrimmed],
    zero_source_segments: svg_path.subpath_segments(zero_source),
  ))
  let OffsetArrangementBuild(
    graph: arrangement_graph.ArrangementGraph(edges: graph_edges, ..) as graph,
    ..,
  ) = build
  use edges <- result.try(
    graph_edges
    |> list.map(fn(edge) {
      let arrangement_graph.ArrangementEdge(id:, segment:, ..) = edge
      let zero_source_only =
        !arrangement_edge_has_group(build, id, UntrimmedOffsetSegment)
      case zero_source_only {
        True ->
          Ok(SingleOffsetArrangementTraceEdge(
            edge:,
            submerged: True,
            zero_source_only: True,
          ))
        False -> {
          use submerged <- result.try(submerged_segment(
            segment,
            inside:,
            side_sampling_distance: submerged_side_sampling_distance,
          ))
          Ok(SingleOffsetArrangementTraceEdge(
            edge:,
            submerged:,
            zero_source_only: False,
          ))
        }
      }
    })
    |> result.all,
  )
  Ok(SingleOffsetArrangementTrace(
    source: normalized,
    untrimmed:,
    semantic_paths:,
    graph:,
    edges:,
  ))
}

/// Build the untrimmed closed stroke band for one source subpath.
@internal
pub fn internal_stroke_band_candidate(
  source: svg_path.Subpath,
  width width: Float,
  cap cap: Cap,
  options options: Options,
) -> Result(OneSubpathBand, Error) {
  use _ <- result.try(validate_stroke_width(width))
  stroke_band_candidate(source, width, cap, options)
}

fn default_trimming_options() -> svg_path.DistanceOptions {
  svg_path.DistanceOptions(
    ..svg_path.default_distance_options(),
    samples: default_trimming_samples,
  )
}

fn closed_candidate_even_contours(
  provisional: List(svg_path.Subpath),
  options: Options,
) -> Result(List(svg_path.Subpath), Error) {
  use build <- result.try(provisional_arrangement(provisional))
  let arrangement_graph.ArrangementGraphBuild(graph:, ..) = build
  let undirected = arrangement_graph.to_undirected(graph)
  use decomposition <- result.try(
    arrangement_graph.odd_even_decomposition(undirected)
    |> result.map_error(ArrangementGraphError),
  )
  let arrangement_graph.OddEvenDecomposition(
    odd_skeleton: arrangement_graph.UndirectedArrangementGraph(
      edges: odd_edges,
      ..,
    ),
    even_graph: _,
  ) = decomposition
  case odd_edges {
    [] ->
      arrangement_nested_contours_from_build_graph(
        graph,
        svg_path.Path(provisional),
        tolerance: options.fitting.tolerance,
      )
    _ -> Error(BandOddSkeletonNotEmpty)
  }
}

fn burn_pruned_single_offset_survivors(
  untrimmed: List(svg_path.Subpath),
  zero_source_segments zero_source_segments: List(svg_path.Segment),
  inside inside: fn(svg_path.Point) -> Result(Bool, Error),
  options options: Options,
) -> Result(List(svg_path.Subpath), Error) {
  use build <- result.try(single_offset_segment_arrangement(
    untrimmed,
    zero_source_segments:,
  ))
  let OffsetArrangementBuild(graph:, ..) = build
  let undirected =
    graph
    |> arrangement_graph.to_undirected
    |> retain_offset_image_edges(build)
  use protected_vertices <- result.try(untrimmed_open_endpoint_vertices(
    build,
    untrimmed,
  ))
  use without_submerged <- result.try(delete_submerged_edges(
    undirected,
    inside:,
    side_sampling_distance: submerged_side_sampling_distance,
  ))
  let burned = burn_unsupported_edges(without_submerged, protected_vertices:)
  use subpaths <- result.try(source_order_survivor_subpaths(
    build,
    burned,
    protected_vertices:,
    tolerance: options.fitting.tolerance,
  ))
  use closed <- result.try(close_survivor_subpaths(
    subpaths,
    tolerance: options.fitting.tolerance,
  ))
  Ok(closed)
}

fn burn_pruned_band_survivors(
  provisional: List(svg_path.Subpath),
  inside inside: fn(svg_path.Point) -> Result(Bool, Error),
  options options: Options,
) -> Result(List(svg_path.Subpath), Error) {
  use build <- result.try(provisional_segment_arrangement(provisional))
  let OffsetArrangementBuild(graph:, ..) = build
  let undirected = arrangement_graph.to_undirected(graph)
  case undirected_odd_vertices(undirected) {
    [] -> {
      use without_submerged <- result.try(delete_submerged_edges(
        undirected,
        inside:,
        side_sampling_distance: submerged_side_sampling_distance,
      ))
      let burned =
        burn_unsupported_edges(without_submerged, protected_vertices: [])
      source_order_survivor_subpaths(
        build,
        burned,
        protected_vertices: [],
        tolerance: options.fitting.tolerance,
      )
      |> result.try(close_survivor_subpaths(
        _,
        tolerance: options.fitting.tolerance,
      ))
    }
    _ -> Error(BandOddSkeletonNotEmpty)
  }
}

fn undirected_odd_vertices(
  graph: arrangement_graph.UndirectedArrangementGraph,
) -> List(Int) {
  let arrangement_graph.UndirectedArrangementGraph(vertices:, edges:) = graph
  vertices
  |> list.filter(fn(vertex) {
    let arrangement_graph.ArrangementVertex(id:, ..) = vertex
    case int.modulo(undirected_weighted_degree(edges, id), by: 2) {
      Ok(1) -> True
      _ -> False
    }
  })
  |> list.map(fn(vertex) {
    let arrangement_graph.ArrangementVertex(id:, ..) = vertex
    id
  })
}

fn undirected_incidence_degree(
  edges: List(arrangement_graph.UndirectedArrangementEdge),
  vertex: Int,
) -> Int {
  case edges {
    [] -> 0
    [edge, ..rest] -> {
      let arrangement_graph.UndirectedArrangementEdge(
        start_vertex:,
        end_vertex:,
        ..,
      ) = edge
      let contribution = case start_vertex == vertex, end_vertex == vertex {
        True, True -> 2
        True, False -> 1
        False, True -> 1
        False, False -> 0
      }
      contribution + undirected_incidence_degree(rest, vertex)
    }
  }
}

fn undirected_weighted_degree(
  edges: List(arrangement_graph.UndirectedArrangementEdge),
  vertex: Int,
) -> Int {
  case edges {
    [] -> 0
    [edge, ..rest] -> {
      let arrangement_graph.UndirectedArrangementEdge(
        start_vertex:,
        end_vertex:,
        multiplicity:,
        ..,
      ) = edge
      let contribution = case start_vertex == vertex, end_vertex == vertex {
        True, True -> 2 * multiplicity
        True, False -> multiplicity
        False, True -> multiplicity
        False, False -> 0
      }
      contribution + undirected_weighted_degree(rest, vertex)
    }
  }
}

fn untrimmed_open_endpoint_vertices(
  build: OffsetArrangementBuild,
  untrimmed: List(svg_path.Subpath),
) -> Result(List(Int), Error) {
  let OffsetArrangementBuild(segment_images:, ..) = build
  untrimmed_open_endpoint_vertices_loop(
    build,
    untrimmed,
    segment_images,
    protected: [],
  )
}

fn untrimmed_open_endpoint_vertices_loop(
  build: OffsetArrangementBuild,
  untrimmed: List(svg_path.Subpath),
  images: List(arrangement_graph.ArrangementSourceSegmentImage),
  protected protected: List(Int),
) -> Result(List(Int), Error) {
  case untrimmed {
    [] -> Ok(list.reverse(protected))
    [first, ..rest] -> {
      let count = list.length(svg_path.subpath_segments(first))
      use span <- result.try(take_segment_images(images, count))
      let #(subpath_images, remaining_images) = span
      case svg_path.subpath_is_closed(first), subpath_images {
        True, _ ->
          untrimmed_open_endpoint_vertices_loop(
            build,
            rest,
            remaining_images,
            protected:,
          )
        False, [] ->
          untrimmed_open_endpoint_vertices_loop(
            build,
            rest,
            remaining_images,
            protected:,
          )
        False, [first_image, ..] -> {
          let assert Ok(last_image) = last_segment_image(subpath_images)
          use start_vertex <- result.try(segment_image_start_vertex(
            build,
            first_image,
          ))
          use end_vertex <- result.try(segment_image_end_vertex(
            build,
            last_image,
          ))
          untrimmed_open_endpoint_vertices_loop(
            build,
            rest,
            remaining_images,
            protected: [end_vertex, start_vertex, ..protected],
          )
        }
      }
    }
  }
}

fn take_segment_images(
  images: List(arrangement_graph.ArrangementSourceSegmentImage),
  count: Int,
) -> Result(
  #(
    List(arrangement_graph.ArrangementSourceSegmentImage),
    List(arrangement_graph.ArrangementSourceSegmentImage),
  ),
  Error,
) {
  case count <= 0 {
    True -> Ok(#([], images))
    False ->
      case images {
        [] ->
          Error(ArrangementGraphError(
            arrangement_graph.InternalNormalizationError,
          ))
        [first, ..rest] -> {
          use tail <- result.try(take_segment_images(rest, count - 1))
          let #(taken, remaining) = tail
          Ok(#([first, ..taken], remaining))
        }
      }
  }
}

fn last_segment_image(
  images: List(arrangement_graph.ArrangementSourceSegmentImage),
) -> Result(arrangement_graph.ArrangementSourceSegmentImage, Nil) {
  case images {
    [] -> Error(Nil)
    [first] -> Ok(first)
    [_, ..rest] -> last_segment_image(rest)
  }
}

fn segment_image_start_vertex(
  build: OffsetArrangementBuild,
  image: arrangement_graph.ArrangementSourceSegmentImage,
) -> Result(Int, Error) {
  use edges <- result.try(source_segment_image_edges(build, image))
  case edges {
    [] ->
      Error(ArrangementGraphError(arrangement_graph.InternalNormalizationError))
    [first, ..] -> {
      let #(edge, reversed) = first
      case reversed {
        True -> Ok(edge.end_vertex)
        False -> Ok(edge.start_vertex)
      }
    }
  }
}

fn segment_image_end_vertex(
  build: OffsetArrangementBuild,
  image: arrangement_graph.ArrangementSourceSegmentImage,
) -> Result(Int, Error) {
  use edges <- result.try(source_segment_image_edges(build, image))
  use last <- result.try(
    last_directed_edge(edges)
    |> result.map_error(fn(_) {
      ArrangementGraphError(arrangement_graph.InternalNormalizationError)
    }),
  )
  let #(edge, reversed) = last
  case reversed {
    True -> Ok(edge.start_vertex)
    False -> Ok(edge.end_vertex)
  }
}

fn last_directed_edge(
  edges: List(#(arrangement_graph.ArrangementEdge, Bool)),
) -> Result(#(arrangement_graph.ArrangementEdge, Bool), Nil) {
  case edges {
    [] -> Error(Nil)
    [first] -> Ok(first)
    [_, ..rest] -> last_directed_edge(rest)
  }
}

fn delete_submerged_edges(
  graph: arrangement_graph.UndirectedArrangementGraph,
  inside inside: fn(svg_path.Point) -> Result(Bool, Error),
  side_sampling_distance side_sampling_distance: Float,
) -> Result(arrangement_graph.UndirectedArrangementGraph, Error) {
  let arrangement_graph.UndirectedArrangementGraph(vertices:, edges:) = graph
  use retained <- result.try(
    delete_submerged_edges_loop(
      edges,
      inside:,
      side_sampling_distance:,
      retained: [],
    ),
  )
  Ok(arrangement_graph.UndirectedArrangementGraph(vertices:, edges: retained))
}

fn delete_submerged_edges_loop(
  edges: List(arrangement_graph.UndirectedArrangementEdge),
  inside inside: fn(svg_path.Point) -> Result(Bool, Error),
  side_sampling_distance side_sampling_distance: Float,
  retained retained: List(arrangement_graph.UndirectedArrangementEdge),
) -> Result(List(arrangement_graph.UndirectedArrangementEdge), Error) {
  case edges {
    [] -> Ok(list.reverse(retained))
    [edge, ..rest] -> {
      let arrangement_graph.UndirectedArrangementEdge(segment:, ..) = edge
      use submerged <- result.try(submerged_segment(
        segment,
        inside:,
        side_sampling_distance:,
      ))
      let retained = case submerged {
        True -> retained
        False -> [edge, ..retained]
      }
      delete_submerged_edges_loop(
        rest,
        inside:,
        side_sampling_distance:,
        retained:,
      )
    }
  }
}

fn burn_unsupported_edges(
  graph: arrangement_graph.UndirectedArrangementGraph,
  protected_vertices protected_vertices: List(Int),
) -> arrangement_graph.UndirectedArrangementGraph {
  let arrangement_graph.UndirectedArrangementGraph(vertices:, edges:) = graph
  let retained =
    edges
    |> list.filter(fn(edge) {
      !undirected_edge_is_burned(edge, edges, protected_vertices)
    })
  case list.length(retained) == list.length(edges) {
    True -> graph
    False ->
      burn_unsupported_edges(
        arrangement_graph.UndirectedArrangementGraph(vertices:, edges: retained),
        protected_vertices:,
      )
  }
}

fn undirected_edge_is_burned(
  edge: arrangement_graph.UndirectedArrangementEdge,
  edges: List(arrangement_graph.UndirectedArrangementEdge),
  protected_vertices: List(Int),
) -> Bool {
  let arrangement_graph.UndirectedArrangementEdge(
    start_vertex:,
    end_vertex:,
    ..,
  ) = edge
  endpoint_burns(start_vertex, edges, protected_vertices)
  || endpoint_burns(end_vertex, edges, protected_vertices)
}

fn endpoint_burns(
  vertex: Int,
  edges: List(arrangement_graph.UndirectedArrangementEdge),
  protected_vertices: List(Int),
) -> Bool {
  !list.contains(protected_vertices, vertex)
  && undirected_incidence_degree(edges, vertex) == 1
}

fn close_survivor_subpaths(
  subpaths: List(svg_path.Subpath),
  tolerance tolerance: Float,
) -> Result(List(svg_path.Subpath), Error) {
  case subpaths {
    [] -> Ok([])
    [first, ..rest] -> {
      use closed <- result.try(close_survivor_subpath(first, tolerance:))
      use rest <- result.try(close_survivor_subpaths(rest, tolerance:))
      Ok([closed, ..rest])
    }
  }
}

fn close_survivor_subpath(
  subpath: svg_path.Subpath,
  tolerance tolerance: Float,
) -> Result(svg_path.Subpath, Error) {
  use start <- result.try(
    svg_path.subpath_start(subpath) |> result.map_error(PathError),
  )
  use end <- result.try(
    svg_path.subpath_end(subpath) |> result.map_error(PathError),
  )
  case point_helpers.distance(start, end) <=. tolerance {
    True ->
      svg_path.subpath_set_closed_with(
        subpath,
        closed: True,
        policy: svg_path.WiggleThenBridgeWith(tolerance),
      )
      |> result.map_error(PathError)
    False -> Ok(subpath)
  }
}

fn arrangement_nested_contours_from_build_graph(
  graph: arrangement_graph.ArrangementGraph,
  path: svg_path.Path,
  tolerance tolerance: Float,
) -> Result(List(svg_path.Subpath), Error) {
  arrangement_graph.nested_contours_from_graph(graph, path:, tolerance:)
  |> result.map_error(ArrangementGraphError)
}

fn source_order_survivor_subpaths(
  build: OffsetArrangementBuild,
  graph: arrangement_graph.UndirectedArrangementGraph,
  protected_vertices protected_vertices: List(Int),
  tolerance tolerance: Float,
) -> Result(List(svg_path.Subpath), Error) {
  let OffsetArrangementBuild(segment_images:, ..) = build
  let segment_images =
    list.filter(segment_images, fn(image) {
      let arrangement_graph.ArrangementSourceSegmentImage(segment_index:, ..) =
        image
      offset_segment_index_has_group(
        build,
        segment_index,
        UntrimmedOffsetSegment,
      )
    })
  let available_ids = undirected_edge_ids(graph)
  use chains <- result.try(
    source_order_survivor_chains(
      build,
      segment_images,
      available_ids,
      open: [],
      finished: [],
    ),
  )
  let chains = filter_bare_survivor_chains(chains, protected_vertices)
  survivor_chains_to_subpaths(chains, tolerance, subpaths: [])
}

fn filter_bare_survivor_chains(
  chains: List(SurvivorChain),
  protected_vertices: List(Int),
) -> List(SurvivorChain) {
  chains
  |> list.filter(fn(chain) {
    let SurvivorChain(start_vertex:, end_vertex:, closed:, ..) = chain
    closed
    || {
      list.contains(protected_vertices, start_vertex)
      && list.contains(protected_vertices, end_vertex)
    }
  })
}

fn undirected_edge_ids(
  graph: arrangement_graph.UndirectedArrangementGraph,
) -> List(Int) {
  let arrangement_graph.UndirectedArrangementGraph(edges:, ..) = graph
  edges
  |> list.map(fn(edge) {
    let arrangement_graph.UndirectedArrangementEdge(id:, ..) = edge
    id
  })
}

fn source_order_survivor_chains(
  build: OffsetArrangementBuild,
  images: List(arrangement_graph.ArrangementSourceSegmentImage),
  available_ids: List(Int),
  open open: List(SurvivorChain),
  finished finished: List(SurvivorChain),
) -> Result(List(SurvivorChain), Error) {
  case images {
    [] -> Ok(list.reverse(finished) |> list.append(list.reverse(open)))
    [image, ..rest] -> {
      use image_result <- result.try(source_order_survivor_image_edges(
        build,
        image,
        available_ids,
      ))
      let #(image_edges, available_ids) = image_result
      let #(open, finished) =
        append_source_order_edges(image_edges, open:, finished:)
      source_order_survivor_chains(build, rest, available_ids, open:, finished:)
    }
  }
}

fn source_order_survivor_image_edges(
  build: OffsetArrangementBuild,
  image: arrangement_graph.ArrangementSourceSegmentImage,
  available_ids: List(Int),
) -> Result(#(List(SurvivorEdge), List(Int)), Error) {
  use directed <- result.try(source_segment_image_edges(build, image))
  Ok(source_order_survivor_directed_edges(directed, available_ids, edges: []))
}

fn source_order_survivor_directed_edges(
  directed_edges: List(#(arrangement_graph.ArrangementEdge, Bool)),
  available_ids: List(Int),
  edges edges: List(SurvivorEdge),
) -> #(List(SurvivorEdge), List(Int)) {
  case directed_edges {
    [] -> #(list.reverse(edges), available_ids)
    [directed_edge, ..rest] -> {
      let #(edge, reversed) = directed_edge
      case take_id(edge.id, available_ids) {
        Ok(available_ids) -> {
          let #(start_vertex, end_vertex, segment) = case reversed {
            True -> #(
              edge.end_vertex,
              edge.start_vertex,
              svg_path.segment_reverse(edge.segment),
            )
            False -> #(edge.start_vertex, edge.end_vertex, edge.segment)
          }
          let survivor =
            SurvivorEdge(edge_id: edge.id, start_vertex:, end_vertex:, segment:)
          source_order_survivor_directed_edges(rest, available_ids, edges: [
            survivor,
            ..edges
          ])
        }
        Error(Nil) ->
          source_order_survivor_directed_edges(rest, available_ids, edges:)
      }
    }
  }
}

fn take_id(id: Int, ids: List(Int)) -> Result(List(Int), Nil) {
  case ids {
    [] -> Error(Nil)
    [first, ..rest] -> {
      case first == id {
        True -> Ok(rest)
        False -> {
          use rest <- result.try(take_id(id, rest))
          Ok([first, ..rest])
        }
      }
    }
  }
}

fn append_source_order_edges(
  edges: List(SurvivorEdge),
  open open: List(SurvivorChain),
  finished finished: List(SurvivorChain),
) -> #(List(SurvivorChain), List(SurvivorChain)) {
  case edges {
    [] -> #(open, finished)
    [first, ..rest] -> {
      let #(open, finished) = append_source_order_edge(first, open:, finished:)
      append_source_order_edges(rest, open:, finished:)
    }
  }
}

fn append_source_order_edge(
  edge: SurvivorEdge,
  open open: List(SurvivorChain),
  finished finished: List(SurvivorChain),
) -> #(List(SurvivorChain), List(SurvivorChain)) {
  let SurvivorEdge(start_vertex:, end_vertex:, segment:, ..) = edge
  let chain =
    SurvivorChain(
      start_vertex:,
      end_vertex:,
      segments: [segment],
      closed: start_vertex == end_vertex,
    )
  insert_survivor_chain(chain, open, skipped: [], finished:)
}

fn insert_survivor_chain(
  chain: SurvivorChain,
  open: List(SurvivorChain),
  skipped skipped: List(SurvivorChain),
  finished finished: List(SurvivorChain),
) -> #(List(SurvivorChain), List(SurvivorChain)) {
  let SurvivorChain(closed:, ..) = chain
  case closed {
    True -> #(list.append(list.reverse(skipped), open), [chain, ..finished])
    False -> {
      case open {
        [] -> #([chain, ..list.reverse(skipped)], finished)
        [candidate, ..rest] -> {
          case merge_survivor_chains(chain, candidate) {
            Ok(merged) ->
              insert_survivor_chain(
                mark_survivor_chain_closed(merged),
                list.append(list.reverse(skipped), rest),
                skipped: [],
                finished:,
              )
            Error(Nil) ->
              insert_survivor_chain(
                chain,
                rest,
                skipped: [candidate, ..skipped],
                finished:,
              )
          }
        }
      }
    }
  }
}

fn merge_survivor_chains(
  incoming: SurvivorChain,
  candidate: SurvivorChain,
) -> Result(SurvivorChain, Nil) {
  let SurvivorChain(
    start_vertex: incoming_start,
    end_vertex: incoming_end,
    segments: incoming_segments,
    ..,
  ) = incoming
  let SurvivorChain(
    start_vertex: candidate_start,
    end_vertex: candidate_end,
    segments: candidate_segments,
    ..,
  ) = candidate

  case incoming_end == candidate_start {
    True ->
      Ok(SurvivorChain(
        start_vertex: incoming_start,
        end_vertex: candidate_end,
        segments: list.append(incoming_segments, candidate_segments),
        closed: incoming_start == candidate_end,
      ))
    False ->
      case incoming_end == candidate_end {
        True -> {
          let candidate = reverse_survivor_chain(candidate)
          merge_survivor_chains(incoming, candidate)
        }
        False ->
          case incoming_start == candidate_end {
            True ->
              Ok(SurvivorChain(
                start_vertex: candidate_start,
                end_vertex: incoming_end,
                segments: list.append(candidate_segments, incoming_segments),
                closed: candidate_start == incoming_end,
              ))
            False ->
              case incoming_start == candidate_start {
                True -> {
                  let candidate = reverse_survivor_chain(candidate)
                  merge_survivor_chains(candidate, incoming)
                }
                False -> Error(Nil)
              }
          }
      }
  }
}

fn mark_survivor_chain_closed(chain: SurvivorChain) -> SurvivorChain {
  let SurvivorChain(start_vertex:, end_vertex:, ..) = chain
  SurvivorChain(..chain, closed: start_vertex == end_vertex)
}

fn reverse_survivor_chain(chain: SurvivorChain) -> SurvivorChain {
  let SurvivorChain(start_vertex:, end_vertex:, segments:, closed:) = chain
  SurvivorChain(
    start_vertex: end_vertex,
    end_vertex: start_vertex,
    segments: reverse_survivor_segments(segments, reversed: []),
    closed:,
  )
}

fn reverse_survivor_segments(
  segments: List(svg_path.Segment),
  reversed reversed: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case segments {
    [] -> reversed
    [first, ..rest] ->
      reverse_survivor_segments(rest, reversed: [
        svg_path.segment_reverse(first),
        ..reversed
      ])
  }
}

fn survivor_chains_to_subpaths(
  chains: List(SurvivorChain),
  tolerance: Float,
  subpaths subpaths: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case chains {
    [] -> Ok(list.reverse(subpaths))
    [first, ..rest] -> {
      let SurvivorChain(segments:, closed:, ..) = first
      use subpath <- result.try(
        svg_path.subpath_with(
          segments,
          policy: svg_path.WiggleThenBridgeWith(tolerance),
        )
        |> result.map_error(PathError),
      )
      use subpath <- result.try(
        svg_path.subpath_set_closed_with(
          subpath,
          closed:,
          policy: svg_path.WiggleThenBridgeWith(tolerance),
        )
        |> result.map_error(PathError),
      )
      survivor_chains_to_subpaths(rest, tolerance, subpaths: [
        subpath,
        ..subpaths
      ])
    }
  }
}

fn single_offset_band_from_sides(
  zero_source: svg_path.Subpath,
  offset: svg_path.Subpath,
) -> Result(OneSubpathBand, Error) {
  case svg_path.subpath_is_closed(zero_source) {
    True -> Ok(ClosedSubpathBand(side_a: zero_source, side_b: offset))
    False -> {
      use outline <- result.try(open_butt_band_outline(
        side_a: zero_source,
        side_b: offset,
      ))
      Ok(OpenSubpathBand(outline))
    }
  }
}

fn stroke_band_candidate(
  source: svg_path.Subpath,
  width: Float,
  cap: Cap,
  options: Options,
) -> Result(OneSubpathBand, Error) {
  let radius = width /. 2.0
  case svg_path.subpath_is_closed(source) {
    True -> {
      use side_a <- result.try(closed_untrimmed_side(
        source,
        distance: 0.0 -. radius,
        options:,
      ))
      use side_b <- result.try(closed_untrimmed_side(
        source,
        distance: radius,
        options:,
      ))
      Ok(ClosedSubpathBand(side_a:, side_b:))
    }
    False -> {
      use outline <- result.try(stroke_candidate_subpath(
        source,
        radius,
        cap,
        options,
      ))
      Ok(OpenSubpathBand(outline))
    }
  }
}

fn closed_untrimmed_side(
  source: svg_path.Subpath,
  distance distance: Float,
  options options: Options,
) -> Result(svg_path.Subpath, Error) {
  use side <- result.try(subpath_untrimmed_with(source, distance:, options:))
  svg_path.subpath_set_closed_with(
    side,
    closed: True,
    policy: svg_path.WiggleWith(options.fitting.tolerance),
  )
  |> result.map_error(PathError)
}

fn open_butt_band_outline(
  side_a side_a: svg_path.Subpath,
  side_b side_b: svg_path.Subpath,
) -> Result(svg_path.Subpath, Error) {
  use end_cap <- result.try(open_butt_band_end_cap(side_a, side_b))
  use start_cap <- result.try(open_butt_band_start_cap(side_a, side_b))
  let segments =
    list.append(
      svg_path.subpath_segments(side_a),
      list.append(
        end_cap,
        list.append(
          reverse_segments(svg_path.subpath_segments(side_b)),
          start_cap,
        ),
      ),
    )
  use outline <- result.try(
    svg_path.subpath_with(segments, policy: svg_path.Wiggle)
    |> result.map_error(PathError),
  )
  svg_path.subpath_set_closed_with(
    outline,
    closed: True,
    policy: svg_path.Wiggle,
  )
  |> result.map_error(PathError)
}

fn open_butt_band_end_cap(
  side_a: svg_path.Subpath,
  side_b: svg_path.Subpath,
) -> Result(List(svg_path.Segment), Error) {
  use end_a <- result.try(
    svg_path.subpath_end(side_a) |> result.map_error(PathError),
  )
  use end_b <- result.try(
    svg_path.subpath_end(side_b) |> result.map_error(PathError),
  )
  Ok(line_segments_between([end_a, end_b]))
}

fn open_butt_band_start_cap(
  side_a: svg_path.Subpath,
  side_b: svg_path.Subpath,
) -> Result(List(svg_path.Segment), Error) {
  use start_a <- result.try(
    svg_path.subpath_start(side_a) |> result.map_error(PathError),
  )
  use start_b <- result.try(
    svg_path.subpath_start(side_b) |> result.map_error(PathError),
  )
  Ok(line_segments_between([start_b, start_a]))
}

fn one_subpath_band_semantic_paths(
  bands: List(OneSubpathBand),
  paths paths: List(svg_path.Path),
) -> Result(List(svg_path.Path), Error) {
  case bands {
    [] -> Ok(list.reverse(paths))
    [first, ..rest] -> {
      use path <- result.try(one_subpath_band_semantic_path(first))
      one_subpath_band_semantic_paths(rest, paths: [path, ..paths])
    }
  }
}

fn one_subpath_band_semantic_path(
  band: OneSubpathBand,
) -> Result(svg_path.Path, Error) {
  case band {
    OpenSubpathBand(outline) -> {
      use _ <- result.try(require_closed_band_subpath(outline))
      Ok(svg_path.Path([outline]))
    }
    ClosedSubpathBand(side_a, side_b) -> {
      use _ <- result.try(require_closed_band_subpath(side_a))
      use _ <- result.try(require_closed_band_subpath(side_b))
      Ok(svg_path.Path([side_a, svg_path.subpath_reverse(side_b)]))
    }
  }
}

fn require_closed_band_subpath(
  subpath: svg_path.Subpath,
) -> Result(Nil, Error) {
  case svg_path.subpath_is_closed(subpath) {
    True -> Ok(Nil)
    False -> Error(BandSubpathNotClosed)
  }
}

fn point_inside_any_semantic_band(
  point: svg_path.Point,
  paths: List(svg_path.Path),
) -> Result(Bool, Error) {
  case paths {
    [] -> Ok(False)
    [first, ..rest] -> {
      use inside <- result.try(point_inside_semantic_band(point, first))
      case inside {
        True -> Ok(True)
        False -> point_inside_any_semantic_band(point, rest)
      }
    }
  }
}

fn point_inside_semantic_band(
  point: svg_path.Point,
  path: svg_path.Path,
) -> Result(Bool, Error) {
  use containment <- result.try(
    svg_path.path_containment(point, within: path, using: svg_path.Nonzero)
    |> result.map_error(PathError),
  )
  Ok(containment == svg_path.Inside)
}

fn submerged_segment(
  segment: svg_path.Segment,
  inside inside: fn(svg_path.Point) -> Result(Bool, Error),
  side_sampling_distance side_sampling_distance: Float,
) -> Result(Bool, Error) {
  use point <- result.try(
    svg_path.segment_point(segment, at: 0.5) |> result.map_error(PathError),
  )
  use normal <- result.try(unit_normal(segment, t: 0.5))
  let first = add(point, scale(normal, side_sampling_distance))
  let second = add(point, scale(normal, 0.0 -. side_sampling_distance))
  use first_inside <- result.try(inside(first))
  use second_inside <- result.try(inside(second))
  Ok(first_inside && second_inside)
}

fn filter_band_loops(
  loops: List(svg_path.Subpath),
  inside inside: fn(svg_path.Point) -> Result(Bool, Error),
  side_sampling_distance side_sampling_distance: Float,
  retained retained: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case loops {
    [] -> Ok(list.reverse(retained))
    [first, ..rest] -> {
      use remove <- result.try(loop_should_be_filtered(
        first,
        inside:,
        side_sampling_distance:,
      ))
      let retained = case remove {
        True -> retained
        False -> [first, ..retained]
      }
      filter_band_loops(rest, inside:, side_sampling_distance:, retained:)
    }
  }
}

fn loop_should_be_filtered(
  loop: svg_path.Subpath,
  inside inside: fn(svg_path.Point) -> Result(Bool, Error),
  side_sampling_distance side_sampling_distance: Float,
) -> Result(Bool, Error) {
  loop_submerged_weights(
    svg_path.subpath_segments(loop),
    inside:,
    side_sampling_distance:,
    submerged_weight: 0.0,
    total_weight: 0.0,
  )
}

fn loop_submerged_weights(
  segments: List(svg_path.Segment),
  inside inside: fn(svg_path.Point) -> Result(Bool, Error),
  side_sampling_distance side_sampling_distance: Float,
  submerged_weight submerged_weight: Float,
  total_weight total_weight: Float,
) -> Result(Bool, Error) {
  case segments {
    [] -> Ok(submerged_weight >. total_weight /. 2.0)
    [first, ..rest] -> {
      use submerged <- result.try(submerged_segment(
        first,
        inside:,
        side_sampling_distance:,
      ))
      use length <- result.try(
        svg_path.segment_length(first) |> result.map_error(PathError),
      )
      let submerged_weight = case submerged {
        True -> submerged_weight +. length
        False -> submerged_weight
      }
      loop_submerged_weights(
        rest,
        inside:,
        side_sampling_distance:,
        submerged_weight:,
        total_weight: total_weight +. length,
      )
    }
  }
}

/// Build a local coordinate map around a subpath.
///
/// The returned function interprets its input point as local path coordinates:
/// `x` is true arc length along the source subpath, and `y` is signed offset
/// from that point. Positive offsets use this module's usual convention:
/// to the right of the subpath direction.
///
/// Open subpaths reject `x` values outside `0.0..subpath_length`. Closed
/// subpaths wrap `x` modulo the subpath length. Empty and zero-length subpaths
/// cannot define a stable normal direction and return an error.
pub fn subpath_offset_map(
  subpath: svg_path.Subpath,
) -> Result(fn(svg_path.Point) -> Result(svg_path.Point, Error), Error) {
  subpath_offset_map_with(subpath, options: svg_path.default_length_options())
}

/// Build a local coordinate map around a subpath using explicit length options.
pub fn subpath_offset_map_with(
  subpath: svg_path.Subpath,
  options options: svg_path.LengthOptions,
) -> Result(fn(svg_path.Point) -> Result(svg_path.Point, Error), Error) {
  use spans <- result.try(
    length_spans(
      svg_path.subpath_segments(subpath),
      options:,
      start_distance: 0.0,
      spans: [],
    ),
  )
  let total_length = length_spans_total(spans)

  case total_length <=. 0.0 {
    True -> Error(DegenerateTangent(0.0))
    False -> {
      let closed = svg_path.subpath_is_closed(subpath)
      Ok(fn(point) {
        offset_map_point(spans, total_length:, closed:, options:, local: point)
      })
    }
  }
}

/// Offset one segment by a signed distance.
///
/// Positive distances offset to the right of the segment direction. For a line
/// from `(0, 0)` to `(10, 0)`, `distance: 2.0` returns a line from `(0, -2)` to
/// `(10, -2)`.
///
/// Curves return an open subpath because the result may need several pieces to
/// stay within tolerance. Circular arcs offset to circular arcs; non-circular
/// arcs and Beziers use cubic fitting.
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
  use source <- result.try(
    svg_path.subpath_with([segment], policy: svg_path.Strict)
    |> result.map_error(PathError),
  )
  case subpath_untrimmed_with(source, distance:, options:) {
    Error(PathError(svg_path.EmptySubpath)) -> Error(DegenerateTangent(0.0))
    result -> result
  }
}

/// Offset a subpath by a signed distance.
///
/// Positive distances offset to the right of the subpath direction. Adjacent
/// offset segments are connected using `default_options().join`. The result is
/// a path because trimming self-intersections can split the offset into
/// multiple subpaths or remove it entirely.
///
/// Trimming nodes the untrimmed offset together with its final refined
/// zero-offset source pieces, removes zero-source-only, submerged, and
/// unsupported arrangement edges, and reconstructs surviving offset edges in
/// untrimmed traversal order.
pub fn subpath(
  subpath: svg_path.Subpath,
  distance distance: Float,
) -> Result(svg_path.Path, Error) {
  subpath_with(subpath, distance:, options: default_options())
}

/// Offset a subpath by a signed distance using explicit options.
pub fn subpath_with(
  subpath subpath: svg_path.Subpath,
  distance distance: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use normalized <- result.try(normalize_source_subpath(subpath, options))
  use untrimmed_build <- result.try(build_single_offset_untrimmed(
    normalized,
    distance:,
    options:,
  ))
  let SingleOffsetUntrimmedBuild(subpath: untrimmed, zero_source:) =
    untrimmed_build
  use band <- result.try(single_offset_band_from_sides(zero_source, untrimmed))
  trim_single_offset_path(
    [untrimmed],
    zero_source_segments: svg_path.subpath_segments(zero_source),
    bands: [band],
    options:,
  )
}

fn normalize_source_subpath(
  subpath: svg_path.Subpath,
  options: Options,
) -> Result(svg_path.Subpath, Error) {
  use subpath <- result.try(eliminate_small_offset_source_segments(
    subpath,
    tolerance: 0.001,
  ))
  use subpath <- result.try(
    degeneracy.normalize_degenerate_segments(
      subpath,
      tolerance: options.fitting.tolerance,
    )
    |> result.map_error(SourceNormalizationError),
  )
  case svg_path.subpath_segments(subpath) {
    [] -> Ok(subpath)
    [_, ..] ->
      colinearize_offset_source_tangents(
        subpath,
        tolerance: source_tangent_colinearization_angle_degrees,
      )
  }
}

fn normalize_source_path(
  path: svg_path.Path,
  options: Options,
) -> Result(svg_path.Path, Error) {
  path
  |> svg_path.path_subpaths
  |> list.map(fn(subpath) { normalize_source_subpath(subpath, options) })
  |> result.all
  |> result.map(fn(subpaths) {
    svg_path.Path(
      list.filter(subpaths, fn(subpath) {
        !list.is_empty(svg_path.subpath_segments(subpath))
      }),
    )
  })
}

fn colinearize_offset_source_tangents(
  subpath: svg_path.Subpath,
  tolerance tolerance: Float,
) -> Result(svg_path.Subpath, Error) {
  svg_path.subpath_rebuild_with(
    subpath,
    policy: colinearize_source_tangent_policy(tolerance),
  )
  |> result.map_error(PathError)
}

fn colinearize_source_tangent_policy(
  tolerance: Float,
) -> svg_path.EndpointPolicy {
  svg_path.Custom(fn(previous, next, closing) {
    let #(previous, next) =
      colinearize_source_tangent_boundary(previous, next, tolerance)
    case closing {
      True -> [previous]
      False -> [previous, next]
    }
  })
}

fn colinearize_source_tangent_boundary(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
) -> #(svg_path.Segment, svg_path.Segment) {
  case unit_tangent(left, t: 1.0), unit_tangent(right, t: 0.0) {
    Ok(left_tangent), Ok(right_tangent) -> {
      let angle = signed_angle(left_tangent, right_tangent)
      case float.absolute_value(angle) <=. tolerance {
        False -> #(left, right)
        True ->
          colinearize_source_tangent_boundary_within_tolerance(
            left,
            right,
            left_tangent,
            right_tangent,
          )
      }
    }
    _, _ -> #(left, right)
  }
}

fn colinearize_source_tangent_boundary_within_tolerance(
  left: svg_path.Segment,
  right: svg_path.Segment,
  left_tangent: svg_path.Point,
  right_tangent: svg_path.Point,
) -> #(svg_path.Segment, svg_path.Segment) {
  case source_tangent_is_movable(left), source_tangent_is_movable(right) {
    True, True -> {
      let direction = averaged_boundary_tangent(left_tangent, right_tangent)
      let left = snap_source_end_tangent(left, direction)
      let right = snap_source_start_tangent(right, direction)
      #(left, right)
    }
    True, False -> #(snap_source_end_tangent(left, right_tangent), right)
    False, True -> #(left, snap_source_start_tangent(right, left_tangent))
    False, False -> #(left, right)
  }
}

fn source_tangent_is_movable(segment: svg_path.Segment) -> Bool {
  case segment {
    svg_path.QuadraticBezier(..) | svg_path.CubicBezier(..) -> True
    svg_path.Line(..) | svg_path.Arc(..) -> False
  }
}

fn averaged_boundary_tangent(
  left_tangent: svg_path.Point,
  right_tangent: svg_path.Point,
) -> svg_path.Point {
  let sum = add(left_tangent, right_tangent)
  case point_length(sum) >. tangent_epsilon {
    True ->
      case unit_vector(sum, t: 1.0) {
        Ok(direction) -> direction
        Error(_) -> left_tangent
      }
    False -> left_tangent
  }
}

fn snap_source_end_tangent(
  segment: svg_path.Segment,
  direction: svg_path.Point,
) -> svg_path.Segment {
  case segment {
    svg_path.QuadraticBezier(start:, control:, end:) -> {
      let control1 = add(start, scale(subtract(control, start), 2.0 /. 3.0))
      let control2 = add(end, scale(subtract(control, end), 2.0 /. 3.0))
      let handle = point_distance(control2, end)
      svg_path.CubicBezier(
        start:,
        control1:,
        control2: add(end, scale(direction, 0.0 -. handle)),
        end:,
      )
    }
    svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      let handle = point_distance(control2, end)
      svg_path.CubicBezier(
        start:,
        control1:,
        control2: add(end, scale(direction, 0.0 -. handle)),
        end:,
      )
    }
    _ -> segment
  }
}

fn snap_source_start_tangent(
  segment: svg_path.Segment,
  direction: svg_path.Point,
) -> svg_path.Segment {
  case segment {
    svg_path.QuadraticBezier(start:, control:, end:) -> {
      let control1 = add(start, scale(subtract(control, start), 2.0 /. 3.0))
      let control2 = add(end, scale(subtract(control, end), 2.0 /. 3.0))
      let handle = point_distance(control1, start)
      svg_path.CubicBezier(
        start:,
        control1: add(start, scale(direction, handle)),
        control2:,
        end:,
      )
    }
    svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      let handle = point_distance(control1, start)
      svg_path.CubicBezier(
        start:,
        control1: add(start, scale(direction, handle)),
        control2:,
        end:,
      )
    }
    _ -> segment
  }
}

fn eliminate_small_offset_source_segments(
  subpath: svg_path.Subpath,
  tolerance tolerance: Float,
) -> Result(svg_path.Subpath, Error) {
  let segments = svg_path.subpath_segments(subpath)
  case eliminate_small_segments(segments, tolerance) {
    [] -> Ok(subpath)
    normalized -> {
      use normalized <- result.try(
        svg_path.subpath_with(
          normalized,
          policy: svg_path.WiggleThenBridgeWith(tolerance),
        )
        |> result.map_error(PathError),
      )
      svg_path.subpath_set_closed_with(
        normalized,
        closed: svg_path.subpath_is_closed(subpath),
        policy: svg_path.WiggleThenBridgeWith(tolerance),
      )
      |> result.map_error(PathError)
    }
  }
}

fn eliminate_small_segments(
  segments: List(svg_path.Segment),
  tolerance: Float,
) -> List(svg_path.Segment) {
  case segments {
    [] -> []
    [first, ..rest] ->
      eliminate_small_segments_loop(
        previous: first,
        rest: rest,
        tolerance:,
        normalized: [],
        deleted_since_bridge: False,
      )
  }
}

fn eliminate_small_segments_loop(
  previous previous: svg_path.Segment,
  rest rest: List(svg_path.Segment),
  tolerance tolerance: Float,
  normalized normalized: List(svg_path.Segment),
  deleted_since_bridge deleted_since_bridge: Bool,
) -> List(svg_path.Segment) {
  case rest {
    [] -> list.reverse([previous, ..normalized])
    [next, ..remaining] -> {
      case segment_is_short(next, tolerance) {
        False -> {
          let #(previous, next) = case deleted_since_bridge {
            True -> bridge_deleted_small_segment_gap(previous, next, tolerance)
            False -> #(previous, next)
          }
          eliminate_small_segments_loop(
            previous: next,
            rest: remaining,
            tolerance:,
            normalized: [previous, ..normalized],
            deleted_since_bridge: False,
          )
        }
        True ->
          case remaining {
            [] ->
              eliminate_small_segments_loop(
                previous: next,
                rest: [],
                tolerance:,
                normalized: [previous, ..normalized],
                deleted_since_bridge: False,
              )
            [_, ..] -> {
              let previous =
                carry_deleted_small_segment(previous, deleted: next, tolerance:)
              eliminate_small_segments_loop(
                previous:,
                rest: remaining,
                tolerance:,
                normalized:,
                deleted_since_bridge: True,
              )
            }
          }
      }
    }
  }
}

fn carry_deleted_small_segment(
  previous: svg_path.Segment,
  deleted deleted: svg_path.Segment,
  tolerance tolerance: Float,
) -> svg_path.Segment {
  let displacement =
    subtract(svg_path.segment_end(deleted), svg_path.segment_start(deleted))
  let target =
    add(svg_path.segment_end(previous), scale(displacement, 1.0 /. 3.0))
  stretch_segment_end(previous, to: target, tolerance:)
}

fn bridge_deleted_small_segment_gap(
  previous: svg_path.Segment,
  next: svg_path.Segment,
  tolerance: Float,
) -> #(svg_path.Segment, svg_path.Segment) {
  let previous_end = svg_path.segment_end(previous)
  let next_start = svg_path.segment_start(next)
  let target = interpolate(previous_end, next_start, 0.25)
  #(
    stretch_segment_end(previous, to: target, tolerance:),
    stretch_segment_start(next, to: target, tolerance:),
  )
}

fn segment_is_short(segment: svg_path.Segment, tolerance: Float) -> Bool {
  case segment_diameter(segment) {
    Ok(diameter) -> diameter <. tolerance
    Error(_) -> False
  }
}

fn stretch_segment_start(
  segment: svg_path.Segment,
  to target_start: svg_path.Point,
  tolerance tolerance: Float,
) -> svg_path.Segment {
  stretch_segment(
    segment,
    target_start:,
    target_end: svg_path.segment_end(segment),
    tolerance:,
  )
}

fn stretch_segment_end(
  segment: svg_path.Segment,
  to target_end: svg_path.Point,
  tolerance tolerance: Float,
) -> svg_path.Segment {
  stretch_segment(
    segment,
    target_start: svg_path.segment_start(segment),
    target_end:,
    tolerance:,
  )
}

fn stretch_segment(
  segment: svg_path.Segment,
  target_start target_start: svg_path.Point,
  target_end target_end: svg_path.Point,
  tolerance _tolerance: Float,
) -> svg_path.Segment {
  case svg_path.segment_remap_endpoints(segment, target_start, target_end) {
    Ok(segment) -> segment
    Error(_) -> svg_path.Line(start: target_start, end: target_end)
  }
}

/// Offset a subpath at two signed distances and trim the two sides together.
///
/// No endpoint caps are added. The two provisional offset walks are trimmed
/// together as a capless band. This supports ordinary capless stroke sides,
/// one-sided bands, and asymmetric bands such as two positive offsets.
pub fn subpath_band(
  subpath: svg_path.Subpath,
  distance_a distance_a: Float,
  distance_b distance_b: Float,
) -> Result(svg_path.Path, Error) {
  subpath_band_with(
    subpath,
    distance_a:,
    distance_b:,
    options: default_options(),
  )
}

/// Offset a subpath at two signed distances using explicit options.
pub fn subpath_band_with(
  subpath subpath: svg_path.Subpath,
  distance_a distance_a: Float,
  distance_b distance_b: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use normalized <- result.try(normalize_source_subpath(subpath, options))
  use untrimmed_a <- result.try(untrimmed_subpath_from_normalized_source(
    normalized,
    distance: distance_a,
    options:,
  ))
  use untrimmed_b <- result.try(untrimmed_subpath_from_normalized_source(
    normalized,
    distance: distance_b,
    options:,
  ))
  use subpaths <- result.try(parametric_pruned_pair(
    normalized,
    untrimmed_a:,
    distance_a:,
    untrimmed_b:,
    distance_b:,
    options:,
  ))
  orient_outline_path(svg_path.Path(subpaths:))
}

/// Offset a subpath at two signed distances without trimming either side.
///
/// This returns the two provisional offset walks in one path, with the
/// `distance_a` side first and the `distance_b` side second. No caps, bridges,
/// pairwise trimming, self-intersection pruning, or fill-rule interpretation
/// are added.
pub fn subpath_band_untrimmed(
  subpath: svg_path.Subpath,
  distance_a distance_a: Float,
  distance_b distance_b: Float,
) -> Result(svg_path.Path, Error) {
  subpath_band_untrimmed_with(
    subpath,
    distance_a:,
    distance_b:,
    options: default_options(),
  )
}

/// Offset a subpath at two signed distances without trimming either side,
/// using explicit options.
pub fn subpath_band_untrimmed_with(
  subpath subpath: svg_path.Subpath,
  distance_a distance_a: Float,
  distance_b distance_b: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use side_a <- result.try(subpath_untrimmed_with(
    subpath,
    distance: distance_a,
    options:,
  ))
  use side_b <- result.try(subpath_untrimmed_with(
    subpath,
    distance: distance_b,
    options:,
  ))
  Ok(svg_path.Path(subpaths: [side_a, side_b]))
}

/// Stroke a subpath with the default butt cap.
///
/// Open subpaths build one closed provisional stroke boundary from the two
/// offset sides and endpoint caps, then keep sections that separate points
/// inside the intended stroke from points outside it. Closed subpaths use the
/// same capless construction as `subpath_band`.
pub fn subpath_stroke(
  subpath: svg_path.Subpath,
  width width: Float,
) -> Result(svg_path.Path, Error) {
  subpath_stroke_with(subpath, width:, cap: Butt, options: default_options())
}

/// Stroke a subpath using explicit cap and offset options.
pub fn subpath_stroke_with(
  subpath subpath: svg_path.Subpath,
  width width: Float,
  cap cap: Cap,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_stroke_width(width))
  use _ <- result.try(validate_options(options))
  let radius = width /. 2.0
  case svg_path.subpath_segments(subpath) {
    [] -> Ok(svg_path.path_empty())
    _ ->
      case
        svg_path.subpath_is_zero_length(subpath, tolerance: point_tolerance)
      {
        Error(error) -> Error(PathError(error))
        Ok(True) -> zero_length_stroke_path(subpath, radius:, cap:)
        Ok(False) -> {
          case svg_path.subpath_is_closed(subpath) {
            True -> {
              use stroke <- result.try(closed_stroke_path(
                subpath,
                radius: radius,
                options: options,
              ))
              orient_outline_path(stroke)
            }
            False -> {
              use candidate <- result.try(stroke_candidate_subpath(
                subpath,
                radius,
                cap,
                options,
              ))
              use stroke <- result.try(parametric_pruned_stroke_candidate(
                source: subpath,
                candidate:,
                radius:,
                cap:,
                options:,
              ))
              orient_outline_path(stroke)
            }
          }
        }
      }
  }
}

/// Offset a subpath without trimming self-intersections.
///
/// This returns the untrimmed one-sided offset walk. Adjacent segment offsets
/// are connected with `default_options().join`; the result may self-intersect or
/// contain sections that a trimmed offset would remove.
pub fn subpath_untrimmed(
  subpath: svg_path.Subpath,
  distance distance: Float,
) -> Result(svg_path.Subpath, Error) {
  subpath_untrimmed_with(subpath, distance:, options: default_options())
}

/// Offset a subpath without trimming self-intersections using explicit options.
pub fn subpath_untrimmed_with(
  subpath subpath: svg_path.Subpath,
  distance distance: Float,
  options options: Options,
) -> Result(svg_path.Subpath, Error) {
  use _ <- result.try(validate_options(options))
  use normalized <- result.try(normalize_source_subpath(subpath, options))
  untrimmed_subpath_from_normalized_source(normalized, distance:, options:)
}

fn untrimmed_subpath_from_normalized_source(
  subpath: svg_path.Subpath,
  distance distance: Float,
  options options: Options,
) -> Result(svg_path.Subpath, Error) {
  build_single_offset_untrimmed(subpath, distance, options)
  |> result.map(fn(build) { build.subpath })
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
  use normalized <- result.try(normalize_source_path(path, options))
  let source_subpaths = svg_path.path_subpaths(normalized)
  use untrimmed_builds <- result.try(
    single_offset_untrimmed_path_builds(
      source_subpaths,
      distance,
      options,
      converted: [],
    ),
  )
  let untrimmed = list.map(untrimmed_builds, fn(build) { build.subpath })
  let zero_source_segments =
    untrimmed_builds
    |> list.flat_map(fn(build) { svg_path.subpath_segments(build.zero_source) })
  use bands <- result.try(
    single_offset_band_candidates_from_builds(untrimmed_builds, converted: []),
  )
  use result <- result.try(trim_single_offset_path(
    untrimmed,
    zero_source_segments:,
    bands:,
    options:,
  ))
  Ok(result)
}

fn single_offset_band_candidates_from_builds(
  builds: List(SingleOffsetUntrimmedBuild),
  converted converted: List(OneSubpathBand),
) -> Result(List(OneSubpathBand), Error) {
  case builds {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use band <- result.try(single_offset_band_from_sides(
        first.zero_source,
        first.subpath,
      ))
      single_offset_band_candidates_from_builds(rest, converted: [
        band,
        ..converted
      ])
    }
  }
}

/// Return the retained, globally split offset sections without stitching
/// touching sections together. This is intended for construction diagnostics.
@internal
pub fn path_sections_with(
  path path: svg_path.Path,
  distance distance: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use provisional <- result.try(
    untrimmed_offset_path_subpaths(
      svg_path.path_subpaths(path),
      distance,
      options,
      converted: [],
    ),
  )
  use sections <- result.try(arrangement_global_section_chunks(
    provisional,
    options,
    cleanup: False,
  ))
  use retained <- result.try(
    retain_global_parametric_sections(
      sections,
      source: path,
      distance:,
      options:,
      retained: [],
    ),
  )
  use subpaths <- result.try(chunks_to_subpaths(
    retained,
    options.fitting.tolerance,
    closed: False,
  ))
  Ok(svg_path.Path(subpaths:))
}

/// Offset every subpath in a path at two signed distances and trim each pair of
/// sides together.
pub fn path_band(
  path: svg_path.Path,
  distance_a distance_a: Float,
  distance_b distance_b: Float,
) -> Result(svg_path.Path, Error) {
  path_band_with(path, distance_a:, distance_b:, options: default_options())
}

/// Offset every subpath in a path at two signed distances using explicit
/// options.
pub fn path_band_with(
  path path: svg_path.Path,
  distance_a distance_a: Float,
  distance_b distance_b: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use subpaths <- result.try(
    parametric_band_path_subpaths(
      svg_path.path_subpaths(path),
      distance_a,
      distance_b,
      options,
      converted: [],
    ),
  )
  Ok(svg_path.Path(subpaths:))
}

/// Offset every subpath in a path at two signed distances without trimming any
/// side.
pub fn path_band_untrimmed(
  path: svg_path.Path,
  distance_a distance_a: Float,
  distance_b distance_b: Float,
) -> Result(svg_path.Path, Error) {
  path_band_untrimmed_with(
    path,
    distance_a:,
    distance_b:,
    options: default_options(),
  )
}

/// Offset every subpath in a path at two signed distances without trimming any
/// side, using explicit options.
pub fn path_band_untrimmed_with(
  path path: svg_path.Path,
  distance_a distance_a: Float,
  distance_b distance_b: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use subpaths <- result.try(
    untrimmed_band_path_subpaths(
      svg_path.path_subpaths(path),
      distance_a,
      distance_b,
      options,
      converted: [],
    ),
  )
  Ok(svg_path.Path(subpaths:))
}

/// Stroke every subpath in a path with the default butt cap.
pub fn path_stroke(
  path: svg_path.Path,
  width width: Float,
) -> Result(svg_path.Path, Error) {
  path_stroke_with(path, width:, cap: Butt, options: default_options())
}

/// Stroke every subpath in a path using explicit cap and offset options.
pub fn path_stroke_with(
  path path: svg_path.Path,
  width width: Float,
  cap cap: Cap,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_stroke_width(width))
  use _ <- result.try(validate_options(options))
  use subpaths <- result.try(
    stroke_path_subpaths(
      svg_path.path_subpaths(path),
      width,
      cap,
      options,
      converted: [],
    ),
  )
  Ok(svg_path.Path(subpaths:))
}

/// Offset every subpath in a path without trimming self-intersections.
pub fn path_untrimmed(
  path: svg_path.Path,
  distance distance: Float,
) -> Result(svg_path.Path, Error) {
  path_untrimmed_with(path, distance:, options: default_options())
}

/// Offset every subpath in a path without trimming self-intersections using
/// explicit options.
pub fn path_untrimmed_with(
  path path: svg_path.Path,
  distance distance: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use subpaths <- result.try(
    untrimmed_offset_path_subpaths(
      svg_path.path_subpaths(path),
      distance,
      options,
      converted: [],
    ),
  )
  Ok(svg_path.Path(subpaths:))
}

fn validate_options(options: Options) -> Result(Nil, Error) {
  case
    options.fitting.tolerance <=. 0.0
    || !number.is_finite(options.fitting.tolerance)
  {
    True -> Error(InvalidTolerance(options.fitting.tolerance))
    False ->
      case options.fitting.samples <= 0 {
        True -> Error(InvalidSamples(options.fitting.samples))
        False ->
          case options.fitting.max_depth <= 0 {
            True -> Error(InvalidMaxDepth(options.fitting.max_depth))
            False -> validate_offset_diameter(options)
          }
      }
  }
}

fn validate_offset_diameter(options: Options) -> Result(Nil, Error) {
  case
    options.stalled_offset_diameter <. 0.0
    || !number.is_finite(options.stalled_offset_diameter)
  {
    True -> Error(InvalidStalledOffsetDiameter(options.stalled_offset_diameter))
    False -> validate_join(options.join)
  }
}

fn validate_join(join: Join) -> Result(Nil, Error) {
  case join {
    Miter(miter_limit) ->
      case miter_limit <=. 0.0 || !number.is_finite(miter_limit) {
        True -> Error(InvalidMiterLimit(miter_limit))
        False -> Ok(Nil)
      }
    Bevel | Round -> Ok(Nil)
  }
}

fn validate_stroke_width(width: Float) -> Result(Nil, Error) {
  case width <=. 0.0 || !number.is_finite(width) {
    True -> Error(InvalidStrokeWidth(width))
    False -> Ok(Nil)
  }
}

fn untrimmed_offset_path_subpaths(
  subpaths: List(svg_path.Subpath),
  distance: Float,
  options: Options,
  converted converted: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use offset <- result.try(subpath_untrimmed_with(
        first,
        distance:,
        options:,
      ))
      untrimmed_offset_path_subpaths(rest, distance, options, converted: [
        offset,
        ..converted
      ])
    }
  }
}

fn single_offset_untrimmed_path_builds(
  subpaths: List(svg_path.Subpath),
  distance: Float,
  options: Options,
  converted converted: List(SingleOffsetUntrimmedBuild),
) -> Result(List(SingleOffsetUntrimmedBuild), Error) {
  case subpaths {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use build <- result.try(build_single_offset_untrimmed(
        first,
        distance:,
        options:,
      ))
      single_offset_untrimmed_path_builds(rest, distance, options, converted: [
        build,
        ..converted
      ])
    }
  }
}

fn untrimmed_band_path_subpaths(
  subpaths: List(svg_path.Subpath),
  distance_a: Float,
  distance_b: Float,
  options: Options,
  converted converted: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use band <- result.try(subpath_band_untrimmed_with(
        first,
        distance_a:,
        distance_b:,
        options:,
      ))
      untrimmed_band_path_subpaths(
        rest,
        distance_a,
        distance_b,
        options,
        converted: list.append(
          list.reverse(svg_path.path_subpaths(band)),
          converted,
        ),
      )
    }
  }
}

fn stroke_path_subpaths(
  subpaths: List(svg_path.Subpath),
  width: Float,
  cap: Cap,
  options: Options,
  converted converted: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use stroke <- result.try(subpath_stroke_with(
        first,
        width:,
        cap:,
        options:,
      ))
      stroke_path_subpaths(
        rest,
        width,
        cap,
        options,
        converted: list.append(
          list.reverse(svg_path.path_subpaths(stroke)),
          converted,
        ),
      )
    }
  }
}

fn provisional_arrangement(
  provisional: List(svg_path.Subpath),
) -> Result(arrangement_graph.ArrangementGraphBuild, Error) {
  use build <- result.try(provisional_segment_arrangement(provisional))
  offset_public_arrangement_build(build)
}

fn offset_public_arrangement_build(
  build: OffsetArrangementBuild,
) -> Result(arrangement_graph.ArrangementGraphBuild, Error) {
  let OffsetArrangementBuild(graph:, segment_images:, ..) = build
  use images <- result.try(
    segment_images
    |> list.map(source_segment_image_to_public_image(build, _))
    |> result.all,
  )
  Ok(arrangement_graph.ArrangementGraphBuild(graph:, segment_images: images))
}

fn source_segment_image_to_public_image(
  build: OffsetArrangementBuild,
  image: arrangement_graph.ArrangementSourceSegmentImage,
) -> Result(arrangement_graph.ArrangementSegmentImage, Error) {
  let arrangement_graph.ArrangementSourceSegmentImage(segment_index:, edges:) =
    image
  use indexed <- result.try(
    offset_indexed_segment_at(build.indexed_segments, segment_index)
    |> result.map_error(fn(_) {
      ArrangementGraphError(arrangement_graph.InternalNormalizationError)
    }),
  )
  let IndexedOffsetSegment(group:, subpath_index:, ..) = indexed
  case group {
    ZeroOffsetSourceSegment ->
      Error(ArrangementGraphError(arrangement_graph.InternalNormalizationError))
    UntrimmedOffsetSegment ->
      Ok(arrangement_graph.ArrangementSegmentImage(
        path_index: 0,
        subpath_index:,
        segment_index: segment_index,
        edges: list.map(edges, fn(edge) {
          let arrangement_graph.ArrangementSegmentEdgeImage(
            edge_id:,
            reversed:,
            ..,
          ) = edge
          arrangement_graph.DirectedEdgeReference(edge_id:, reversed:)
        }),
      ))
  }
}

fn provisional_segment_arrangement(
  provisional: List(svg_path.Subpath),
) -> Result(OffsetArrangementBuild, Error) {
  let indexed =
    indexed_offset_segments(provisional, group: UntrimmedOffsetSegment)
  offset_segment_arrangement(indexed)
}

fn single_offset_segment_arrangement(
  untrimmed: List(svg_path.Subpath),
  zero_source_segments zero_source_segments: List(svg_path.Segment),
) -> Result(OffsetArrangementBuild, Error) {
  let indexed =
    list.append(
      indexed_offset_segments(untrimmed, group: UntrimmedOffsetSegment),
      list.map(zero_source_segments, fn(segment) {
        IndexedOffsetSegment(
          group: ZeroOffsetSourceSegment,
          subpath_index: 0,
          segment:,
        )
      }),
    )
  offset_segment_arrangement(indexed)
}

fn offset_segment_arrangement(
  indexed: List(IndexedOffsetSegment),
) -> Result(OffsetArrangementBuild, Error) {
  let segments =
    indexed
    |> list.map(fn(item) {
      let IndexedOffsetSegment(segment:, ..) = item
      segment
    })
  let build_result =
    arrangement_graph.build_with(
      segments,
      vertex_tolerance: arrangement_tolerance,
      minimum_chord: arrangement_tolerance,
      endpoint_sliver_tolerance: 0.0001,
    )
  use build <- result.try(
    build_result |> result.map_error(ArrangementGraphError),
  )
  let arrangement_graph.ArrangementSegmentBuild(
    graph:,
    segment_images:,
    edge_images:,
    ..,
  ) = build
  Ok(OffsetArrangementBuild(
    graph:,
    indexed_segments: indexed,
    segment_images:,
    edge_images:,
  ))
}

fn indexed_offset_segments(
  subpaths: List(svg_path.Subpath),
  group group: OffsetArrangementSegmentGroup,
) -> List(IndexedOffsetSegment) {
  indexed_offset_segments_loop(subpaths, group, subpath_index: 0, collected: [])
}

fn indexed_offset_segments_loop(
  subpaths: List(svg_path.Subpath),
  group: OffsetArrangementSegmentGroup,
  subpath_index subpath_index: Int,
  collected collected: List(IndexedOffsetSegment),
) -> List(IndexedOffsetSegment) {
  case subpaths {
    [] -> list.reverse(collected)
    [first, ..rest] -> {
      let collected =
        first
        |> svg_path.subpath_segments
        |> list.fold(collected, fn(collected, segment) {
          [IndexedOffsetSegment(group:, subpath_index:, segment:), ..collected]
        })
      indexed_offset_segments_loop(
        rest,
        group,
        subpath_index: subpath_index + 1,
        collected:,
      )
    }
  }
}

fn source_segment_image_edges(
  build: OffsetArrangementBuild,
  image: arrangement_graph.ArrangementSourceSegmentImage,
) -> Result(List(#(arrangement_graph.ArrangementEdge, Bool)), Error) {
  let OffsetArrangementBuild(
    graph: arrangement_graph.ArrangementGraph(edges: graph_edges, ..),
    ..,
  ) = build
  let arrangement_graph.ArrangementSourceSegmentImage(edges:, ..) = image
  edges
  |> list.map(fn(reference) {
    let arrangement_graph.ArrangementSegmentEdgeImage(edge_id:, reversed:, ..) =
      reference
    use edge <- result.try(
      arrangement_edge_by_id(graph_edges, edge_id)
      |> result.map_error(ArrangementGraphError),
    )
    Ok(#(edge, reversed))
  })
  |> result.all
}

fn arrangement_edge_by_id(
  edges: List(arrangement_graph.ArrangementEdge),
  id: Int,
) -> Result(arrangement_graph.ArrangementEdge, arrangement_graph.Error) {
  case edges {
    [] -> Error(arrangement_graph.MissingEdge(id))
    [first, ..rest] -> {
      let arrangement_graph.ArrangementEdge(id: candidate, ..) = first
      case candidate == id {
        True -> Ok(first)
        False -> arrangement_edge_by_id(rest, id)
      }
    }
  }
}

/// Return one atomic section for each directed provisional-edge occurrence.
/// Coincident graph edges are expanded according to directional multiplicity.
@internal
pub fn internal_arrangement_global_sections(
  provisional: List(svg_path.Subpath),
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use sections <- result.try(arrangement_global_section_chunks(
    provisional,
    options,
    cleanup: False,
  ))
  use subpaths <- result.try(chunks_to_subpaths(
    sections,
    options.fitting.tolerance,
    closed: False,
  ))
  Ok(svg_path.Path(subpaths:))
}

/// Apply the production global-section trimming predicate to one subpath.
@internal
pub fn internal_global_section_is_valid(
  section: svg_path.Subpath,
  source source: svg_path.Path,
  distance distance: Float,
  options options: Options,
) -> Result(Bool, Error) {
  global_parametric_section_is_valid(
    svg_path.subpath_segments(section),
    source:,
    distance:,
    options:,
  )
}

fn offset_segment_index_has_group(
  build: OffsetArrangementBuild,
  segment_index: Int,
  group: OffsetArrangementSegmentGroup,
) -> Bool {
  let OffsetArrangementBuild(indexed_segments:, ..) = build
  case offset_indexed_segment_at(indexed_segments, segment_index) {
    Ok(IndexedOffsetSegment(group: candidate_group, ..)) ->
      candidate_group == group
    Error(Nil) -> False
  }
}

fn retain_offset_image_edges(
  graph: arrangement_graph.UndirectedArrangementGraph,
  build: OffsetArrangementBuild,
) -> arrangement_graph.UndirectedArrangementGraph {
  let arrangement_graph.UndirectedArrangementGraph(vertices:, edges:) = graph
  let retained =
    list.filter(edges, fn(edge) {
      let arrangement_graph.UndirectedArrangementEdge(id:, ..) = edge
      arrangement_edge_has_group(build, id, UntrimmedOffsetSegment)
    })
  arrangement_graph.UndirectedArrangementGraph(vertices:, edges: retained)
}

fn arrangement_edge_has_group(
  build: OffsetArrangementBuild,
  edge_id: Int,
  group: OffsetArrangementSegmentGroup,
) -> Bool {
  build.edge_images
  |> list.any(fn(image) {
    let arrangement_graph.ArrangementEdgeImage(edge_id: candidate, sources:) =
      image
    candidate == edge_id
    && sources
    |> list.any(fn(source) {
      let arrangement_graph.ArrangementEdgeSourceImage(segment_index:, ..) =
        source
      offset_segment_index_has_group(build, segment_index, group)
    })
  })
}

fn offset_indexed_segment_at(
  segments: List(IndexedOffsetSegment),
  index: Int,
) -> Result(IndexedOffsetSegment, Nil) {
  case segments, index {
    [], _ -> Error(Nil)
    [first, ..], 0 -> Ok(first)
    [_, ..rest], _ -> offset_indexed_segment_at(rest, index - 1)
  }
}

fn arrangement_global_section_chunks(
  provisional: List(svg_path.Subpath),
  options: Options,
  cleanup cleanup: Bool,
) -> Result(List(List(svg_path.Segment)), Error) {
  let _ = options
  let _ = cleanup
  use build <- result.try(provisional_segment_arrangement(provisional))
  let OffsetArrangementBuild(segment_images:, ..) = build
  use image_sections <- result.try(
    segment_images
    |> list.map(fn(image) {
      source_segment_image_edges(build, image)
      |> result.map(fn(edges) {
        list.map(edges, fn(directed) {
          let #(edge, reversed) = directed
          [
            case reversed {
              True -> svg_path.segment_reverse(edge.segment)
              False -> edge.segment
            },
          ]
        })
      })
    })
    |> result.all,
  )
  Ok(list.flatten(image_sections))
}

fn retain_global_parametric_sections(
  sections: List(List(svg_path.Segment)),
  source source: svg_path.Path,
  distance distance: Float,
  options options: Options,
  retained retained: List(List(svg_path.Segment)),
) -> Result(List(List(svg_path.Segment)), Error) {
  case sections {
    [] -> Ok(list.reverse(retained))
    [first, ..rest] -> {
      use keep <- result.try(global_parametric_section_is_valid(
        first,
        source:,
        distance:,
        options:,
      ))
      let retained = case keep {
        True -> [first, ..retained]
        False -> retained
      }
      retain_global_parametric_sections(
        rest,
        source:,
        distance:,
        options:,
        retained:,
      )
    }
  }
}

fn global_parametric_section_is_valid(
  section: List(svg_path.Segment),
  source source: svg_path.Path,
  distance distance: Float,
  options options: Options,
) -> Result(Bool, Error) {
  use section <- result.try(normalize_chunk(section, options.fitting.tolerance))
  use section <- result.try(
    svg_path.subpath_with(
      section,
      policy: svg_path.WiggleWith(options.fitting.tolerance),
    )
    |> result.map_error(PathError),
  )
  use length <- result.try(
    svg_path.subpath_length(section) |> result.map_error(PathError),
  )
  global_parametric_section_samples(
    section,
    length,
    section_sample_parameters(),
    source:,
    distance:,
    options:,
  )
}

fn global_parametric_section_samples(
  section: svg_path.Subpath,
  length: Float,
  samples: List(Float),
  source source: svg_path.Path,
  distance distance: Float,
  options options: Options,
) -> Result(Bool, Error) {
  case samples {
    [] -> Ok(True)
    [first, ..rest] -> {
      use point <- result.try(
        svg_path.subpath_point_at_length(section, distance: length *. first)
        |> result.map_error(PathError),
      )
      let margin = distance_margin(options)
      use projection <- result.try(
        svg_path.path_projection_with(
          point,
          to: source,
          options: options.trimming,
        )
        |> result.map_error(PathError),
      )
      case projection.distance +. margin >=. float.absolute_value(distance) {
        True ->
          global_parametric_section_samples(
            section,
            length,
            rest,
            source:,
            distance:,
            options:,
          )
        False -> Ok(False)
      }
    }
  }
}

fn parametric_band_path_subpaths(
  subpaths: List(svg_path.Subpath),
  distance_a: Float,
  distance_b: Float,
  options: Options,
  converted converted: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use offset <- result.try(subpath_band_with(
        first,
        distance_a:,
        distance_b:,
        options:,
      ))
      parametric_band_path_subpaths(
        rest,
        distance_a,
        distance_b,
        options,
        converted: list.append(
          list.reverse(svg_path.path_subpaths(offset)),
          converted,
        ),
      )
    }
  }
}

fn build_single_offset_untrimmed(
  subpath: svg_path.Subpath,
  distance distance: Float,
  options options: Options,
) -> Result(SingleOffsetUntrimmedBuild, Error) {
  case svg_path.subpath_segments(subpath) {
    [] -> {
      use start <- result.try(
        svg_path.subpath_start(subpath) |> result.map_error(PathError),
      )
      Ok(SingleOffsetUntrimmedBuild(
        subpath: svg_path.subpath_empty(at: start),
        zero_source: svg_path.subpath_empty(at: start),
      ))
    }
    [_, ..] -> {
      use offset_build <- result.try(build_offset_segments_with_zero_source(
        subpath,
        distance,
        options,
      ))
      let OffsetSegmentsBuild(offsets: offset_segments, zero_source_segments:) =
        offset_build
      use zero_source <- result.try(subpath_from_zero_source_segments(
        zero_source_segments,
        closed: svg_path.subpath_is_closed(subpath),
        tolerance: options.fitting.tolerance,
      ))
      use output_segments <- result.try(parametric_joined_offset_segments(
        offset_segments,
        distance,
        options.join,
        closed: svg_path.subpath_is_closed(subpath),
      ))
      use untrimmed <- result.try(
        svg_path.subpath_with(
          output_segments,
          policy: svg_path.WiggleWith(options.fitting.tolerance),
        )
        |> result.map_error(PathError),
      )
      case svg_path.subpath_is_closed(subpath) {
        False ->
          Ok(SingleOffsetUntrimmedBuild(subpath: untrimmed, zero_source:))
        True -> {
          use closed <- result.try(
            svg_path.subpath_set_closed_with(
              untrimmed,
              closed: True,
              policy: svg_path.WiggleWith(options.fitting.tolerance),
            )
            |> result.map_error(PathError),
          )
          Ok(SingleOffsetUntrimmedBuild(subpath: closed, zero_source:))
        }
      }
    }
  }
}

fn subpath_from_zero_source_segments(
  segments: List(svg_path.Segment),
  closed closed: Bool,
  tolerance tolerance: Float,
) -> Result(svg_path.Subpath, Error) {
  use subpath <- result.try(
    svg_path.subpath_with(segments, policy: svg_path.WiggleWith(tolerance))
    |> result.map_error(PathError),
  )
  svg_path.subpath_set_closed_with(
    subpath,
    closed:,
    policy: svg_path.WiggleWith(tolerance),
  )
  |> result.map_error(PathError)
}

fn parametric_joined_offset_segments(
  offsets: List(GHealedOffsetSegment),
  distance: Float,
  join: Join,
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
        join,
        closed:,
        segments: [first.segment],
      )
  }
}

fn parametric_joined_offset_segments_loop(
  first: GHealedOffsetSegment,
  previous: GHealedOffsetSegment,
  rest: List(GHealedOffsetSegment),
  distance: Float,
  join: Join,
  closed closed: Bool,
  segments segments: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), Error) {
  case rest {
    [] -> {
      case closed {
        False -> Ok(segments)
        True -> {
          use connector <- result.try(parametric_join_segments(
            previous,
            first,
            distance,
            join,
          ))
          Ok(list.append(segments, connector))
        }
      }
    }
    [next, ..remaining] -> {
      use connector <- result.try(parametric_join_segments(
        previous,
        next,
        distance,
        join,
      ))
      parametric_joined_offset_segments_loop(
        first,
        next,
        remaining,
        distance,
        join,
        closed:,
        segments: list.append(segments, list.append(connector, [next.segment])),
      )
    }
  }
}

fn parametric_join_segments(
  left: GHealedOffsetSegment,
  right: GHealedOffsetSegment,
  distance: Float,
  join: Join,
) -> Result(List(svg_path.Segment), Error) {
  let start = svg_path.segment_end(left.segment)
  let end = svg_path.segment_start(right.segment)
  case points_near(start, end) {
    True -> Ok([])
    False ->
      case join {
        Bevel -> Ok(line_segments_between([start, end]))
        Miter(miter_limit) ->
          directed_miter_join(left, right, start, end, distance, miter_limit)
        Round -> round_join(left, right, start, end, distance)
      }
  }
}

fn closed_stroke_path(
  source: svg_path.Subpath,
  radius radius: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use band <- result.try(stroke_band_candidate(
    source,
    radius *. 2.0,
    Butt,
    options,
  ))
  case band {
    OpenSubpathBand(_) -> Error(BandSubpathNotClosed)
    ClosedSubpathBand(side_a, side_b) ->
      internal_topological_band_path([side_a, side_b], bands: [band], options:)
  }
}

fn orient_outline_path(path: svg_path.Path) -> Result(svg_path.Path, Error) {
  use subpaths <- result.try(
    orient_outline_subpaths(
      svg_path.path_subpaths(path),
      all: svg_path.path_subpaths(path),
      oriented: [],
    ),
  )
  Ok(svg_path.Path(subpaths:))
}

fn orient_outline_subpaths(
  subpaths: List(svg_path.Subpath),
  all all: List(svg_path.Subpath),
  oriented oriented: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(oriented))
    [first, ..rest] -> {
      use oriented_first <- result.try(orient_outline_subpath_from_depth(
        first,
        all,
      ))
      orient_outline_subpaths(rest, all:, oriented: [oriented_first, ..oriented])
    }
  }
}

fn orient_outline_subpath_from_depth(
  subpath: svg_path.Subpath,
  all: List(svg_path.Subpath),
) -> Result(svg_path.Subpath, Error) {
  case svg_path.subpath_is_closed(subpath) {
    False -> Ok(subpath)
    True -> {
      use depth <- result.try(outline_contour_depth(subpath, all))
      let assert Ok(remainder) = int.remainder(depth, by: 2)
      Ok(orient_outline_subpath(subpath, clockwise: remainder == 0))
    }
  }
}

fn outline_contour_depth(
  subpath: svg_path.Subpath,
  all: List(svg_path.Subpath),
) -> Result(Int, Error) {
  use probe <- result.try(outline_contour_probe(subpath))
  outline_contour_depth_loop(probe, all, depth: 0)
}

fn outline_contour_depth_loop(
  probe: svg_path.Point,
  subpaths: List(svg_path.Subpath),
  depth depth: Int,
) -> Result(Int, Error) {
  case subpaths {
    [] -> Ok(depth)
    [first, ..rest] -> {
      use containment <- result.try(
        svg_path.subpath_containment(
          probe,
          within: first,
          using: svg_path.Nonzero,
        )
        |> result.map_error(PathError),
      )
      let depth = case containment {
        svg_path.Inside -> depth + 1
        svg_path.Boundary | svg_path.Outside -> depth
      }
      outline_contour_depth_loop(probe, rest, depth:)
    }
  }
}

fn outline_contour_probe(
  subpath: svg_path.Subpath,
) -> Result(svg_path.Point, Error) {
  case svg_path.subpath_segments(subpath) {
    [] -> Error(PathError(svg_path.EmptySubpath))
    [first, ..] ->
      svg_path.segment_point(first, at: 0.5) |> result.map_error(PathError)
  }
}

fn orient_outline_subpath(
  subpath: svg_path.Subpath,
  clockwise clockwise: Bool,
) -> svg_path.Subpath {
  let is_clockwise = area.signed_subpath(subpath) >=. 0.0
  case is_clockwise == clockwise {
    True -> subpath
    False -> svg_path.subpath_reverse(subpath)
  }
}

fn stroke_candidate_subpath(
  source: svg_path.Subpath,
  radius: Float,
  cap: Cap,
  options: Options,
) -> Result(svg_path.Subpath, Error) {
  use positive <- result.try(subpath_untrimmed_with(
    source,
    distance: radius,
    options:,
  ))
  use negative <- result.try(subpath_untrimmed_with(
    source,
    distance: 0.0 -. radius,
    options:,
  ))
  use end_cap <- result.try(stroke_end_cap(source, radius, cap))
  use start_cap <- result.try(stroke_start_cap(source, radius, cap))
  let segments =
    list.append(
      svg_path.subpath_segments(positive),
      list.append(
        end_cap,
        list.append(
          reverse_segments(svg_path.subpath_segments(negative)),
          start_cap,
        ),
      ),
    )
  use candidate <- result.try(
    svg_path.subpath_with(segments, policy: svg_path.Wiggle)
    |> result.map_error(PathError),
  )
  svg_path.subpath_set_closed_with(
    candidate,
    closed: True,
    policy: svg_path.Wiggle,
  )
  |> result.map_error(PathError)
}

fn zero_length_stroke_path(
  subpath: svg_path.Subpath,
  radius radius: Float,
  cap cap: Cap,
) -> Result(svg_path.Path, Error) {
  use center <- result.try(
    svg_path.subpath_start(subpath) |> result.map_error(PathError),
  )
  case cap {
    Butt -> Ok(svg_path.path_empty())
    RoundCap -> zero_length_round_stroke_path(center, radius)
    Square -> zero_length_square_stroke_path(center, radius)
  }
}

fn zero_length_round_stroke_path(
  center: svg_path.Point,
  radius: Float,
) -> Result(svg_path.Path, Error) {
  let right = add(center, svg_path.Point(radius, 0.0))
  let left = add(center, svg_path.Point(0.0 -. radius, 0.0))
  let segments = [
    svg_path.Arc(
      start: right,
      radius: svg_path.Point(radius, radius),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: left,
    ),
    svg_path.Arc(
      start: left,
      radius: svg_path.Point(radius, radius),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: right,
    ),
  ]
  use outline <- result.try(
    svg_path.subpath_with(segments, policy: svg_path.Strict)
    |> result.map_error(PathError),
  )
  use closed <- result.try(
    svg_path.subpath_set_closed_with(
      outline,
      closed: True,
      policy: svg_path.Strict,
    )
    |> result.map_error(PathError),
  )
  Ok(svg_path.Path(subpaths: [closed]))
}

fn zero_length_square_stroke_path(
  center: svg_path.Point,
  radius: Float,
) -> Result(svg_path.Path, Error) {
  let top_left = add(center, svg_path.Point(0.0 -. radius, 0.0 -. radius))
  let top_right = add(center, svg_path.Point(radius, 0.0 -. radius))
  let bottom_right = add(center, svg_path.Point(radius, radius))
  let bottom_left = add(center, svg_path.Point(0.0 -. radius, radius))
  use outline <- result.try(
    svg_path.subpath_with(
      line_segments_between([
        top_left,
        top_right,
        bottom_right,
        bottom_left,
        top_left,
      ]),
      policy: svg_path.Strict,
    )
    |> result.map_error(PathError),
  )
  use closed <- result.try(
    svg_path.subpath_set_closed_with(
      outline,
      closed: True,
      policy: svg_path.Strict,
    )
    |> result.map_error(PathError),
  )
  Ok(svg_path.Path(subpaths: [closed]))
}

fn stroke_end_cap(
  source: svg_path.Subpath,
  radius: Float,
  cap: Cap,
) -> Result(List(svg_path.Segment), Error) {
  use end <- result.try(
    svg_path.subpath_end(source) |> result.map_error(PathError),
  )
  let assert Ok(last) = list.last(svg_path.subpath_segments(source))
  use tangent <- result.try(unit_tangent(last, t: 1.0))
  stroke_cap_segments(center: end, tangent:, radius:, cap:, at_end: True)
}

fn stroke_start_cap(
  source: svg_path.Subpath,
  radius: Float,
  cap: Cap,
) -> Result(List(svg_path.Segment), Error) {
  use start <- result.try(
    svg_path.subpath_start(source) |> result.map_error(PathError),
  )
  let assert [first, ..] = svg_path.subpath_segments(source)
  use tangent <- result.try(unit_tangent(first, t: 0.0))
  stroke_cap_segments(center: start, tangent:, radius:, cap:, at_end: False)
}

fn stroke_cap_segments(
  center center: svg_path.Point,
  tangent tangent: svg_path.Point,
  radius radius: Float,
  cap cap: Cap,
  at_end at_end: Bool,
) -> Result(List(svg_path.Segment), Error) {
  let normal = rotate_clockwise(tangent)
  let positive = add(center, scale(normal, radius))
  let negative = add(center, scale(normal, 0.0 -. radius))
  case cap {
    Butt -> {
      case at_end {
        True -> Ok(line_segments_between([positive, negative]))
        False -> Ok(line_segments_between([negative, positive]))
      }
    }
    Square -> {
      let extension = case at_end {
        True -> scale(tangent, radius)
        False -> scale(tangent, 0.0 -. radius)
      }
      let positive_extended = add(positive, extension)
      let negative_extended = add(negative, extension)
      case at_end {
        True ->
          Ok(
            line_segments_between([
              positive,
              positive_extended,
              negative_extended,
              negative,
            ]),
          )
        False ->
          Ok(
            line_segments_between([
              negative,
              negative_extended,
              positive_extended,
              positive,
            ]),
          )
      }
    }
    RoundCap -> {
      let start = case at_end {
        True -> positive
        False -> negative
      }
      let end = case at_end {
        True -> negative
        False -> positive
      }
      Ok([
        svg_path.Arc(
          start:,
          radius: svg_path.Point(radius, radius),
          x_axis_rotation: 0.0,
          large_arc: False,
          sweep: True,
          end:,
        ),
      ])
    }
  }
}

fn reverse_segments(
  segments: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  segments
  |> list.reverse
  |> list.map(svg_path.segment_reverse)
}

fn parametric_pruned_pair(
  source: svg_path.Subpath,
  untrimmed_a untrimmed_a: svg_path.Subpath,
  distance_a distance_a: Float,
  untrimmed_b untrimmed_b: svg_path.Subpath,
  distance_b distance_b: Float,
  options options: Options,
) -> Result(List(svg_path.Subpath), Error) {
  use #(cross_a, cross_b) <- result.try(cross_side_split_parameters(
    untrimmed_a,
    untrimmed_b,
  ))
  use subpaths_a <- result.try(parametric_pruned_band_side(
    source,
    untrimmed_a,
    distance_a:,
    distance_b:,
    options:,
    extra_split_points: cross_a,
  ))
  use subpaths_b <- result.try(parametric_pruned_band_side(
    source,
    untrimmed_b,
    distance_a:,
    distance_b:,
    options:,
    extra_split_points: cross_b,
  ))
  Ok(list.append(subpaths_a, subpaths_b))
}

fn parametric_pruned_band_side(
  source: svg_path.Subpath,
  untrimmed: svg_path.Subpath,
  distance_a distance_a: Float,
  distance_b distance_b: Float,
  options options: Options,
  extra_split_points extra_split_points: List(svg_path.SubpathParameter),
) -> Result(List(svg_path.Subpath), Error) {
  use retained <- result.try(parametric_pruned_band_side_chunks(
    source,
    untrimmed,
    distance_a:,
    distance_b:,
    options:,
    extra_split_points:,
  ))
  use subpaths <- result.try(chunks_to_subpaths(
    retained,
    options.fitting.tolerance,
    closed: svg_path.subpath_is_closed(source),
  ))
  Ok(subpaths)
}

fn parametric_pruned_band_side_chunks(
  source: svg_path.Subpath,
  untrimmed: svg_path.Subpath,
  distance_a distance_a: Float,
  distance_b distance_b: Float,
  options options: Options,
  extra_split_points extra_split_points: List(svg_path.SubpathParameter),
) -> Result(List(List(svg_path.Segment)), Error) {
  use sections <- result.try(parametric_self_intersection_sections(
    untrimmed,
    intersections.default_options(),
    options.fitting.tolerance,
    extra_split_points:,
  ))
  use retained <- result.try(
    retain_band_boundary_sections(
      sections,
      source:,
      distance_a:,
      distance_b:,
      options:,
      retained: [],
    ),
  )
  Ok(merge_touching_chunks(retained, options.fitting.tolerance))
}

fn parametric_pruned_stroke_candidate(
  source source: svg_path.Subpath,
  candidate candidate: svg_path.Subpath,
  radius radius: Float,
  cap cap: Cap,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use sections <- result.try(
    parametric_self_intersection_sections(
      candidate,
      intersections.default_options(),
      options.fitting.tolerance,
      extra_split_points: [],
    ),
  )
  use retained <- result.try(
    retain_stroke_boundary_sections(
      sections,
      source:,
      radius:,
      cap:,
      options:,
      retained: [],
    ),
  )
  let retained = merge_touching_chunks(retained, options.fitting.tolerance)
  use subpaths <- result.try(chunks_to_subpaths(
    retained,
    options.fitting.tolerance,
    closed: True,
  ))
  Ok(svg_path.Path(subpaths:))
}

fn cross_side_split_parameters(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
) -> Result(
  #(List(svg_path.SubpathParameter), List(svg_path.SubpathParameter)),
  Error,
) {
  use intersections <- result.try(
    intersections.subpath_with(
      left,
      right,
      options: intersections.default_options(),
    )
    |> result.map_error(PathError),
  )
  let left_parameters =
    intersections
    |> list.flat_map(fn(intersection) {
      let svg_path.SubpathIntersection(left_parameters:, ..) = intersection
      left_parameters
    })
    |> list.filter(fn(parameter) {
      !is_open_subpath_boundary_parameter(left, parameter)
    })
    |> list.sort(by: svg_path.subpath_parameters_compare)
    |> unique_subpath_parameters(point_tolerance, [])
  let right_parameters =
    intersections
    |> list.flat_map(fn(intersection) {
      let svg_path.SubpathIntersection(right_parameters:, ..) = intersection
      right_parameters
    })
    |> list.filter(fn(parameter) {
      !is_open_subpath_boundary_parameter(right, parameter)
    })
    |> list.sort(by: svg_path.subpath_parameters_compare)
    |> unique_subpath_parameters(point_tolerance, [])
  Ok(#(left_parameters, right_parameters))
}

fn parametric_self_intersection_sections(
  subpath: svg_path.Subpath,
  _intersection_options: intersections.IntersectionOptions,
  _tolerance: Float,
  extra_split_points extra_split_points: List(svg_path.SubpathParameter),
) -> Result(List(List(svg_path.Segment)), Error) {
  use split_points <- result.try(self_intersection_split_parameters(subpath))
  let split_points =
    list.append(split_points, extra_split_points)
    |> list.sort(by: svg_path.subpath_parameters_compare)
    |> unique_subpath_parameters(point_tolerance, [])
  use sections <- result.try(
    split_segments_at_subpath_parameters(
      svg_path.subpath_segments(subpath),
      split_points,
      index: 0,
      current: [],
      sections: [],
    ),
  )
  let sections = case svg_path.subpath_is_closed(subpath) {
    True -> merge_wrapping_chunks(sections, point_tolerance)
    False -> sections
  }
  normalize_section_chunks(sections, point_tolerance, normalized: [])
}

fn normalize_section_chunks(
  sections: List(List(svg_path.Segment)),
  tolerance: Float,
  normalized normalized: List(List(svg_path.Segment)),
) -> Result(List(List(svg_path.Segment)), Error) {
  case sections {
    [] -> Ok(list.reverse(normalized))
    [first, ..rest] -> {
      use first <- result.try(normalize_chunk(first, tolerance))
      normalize_section_chunks(rest, tolerance, normalized: [
        first,
        ..normalized
      ])
    }
  }
}

fn split_segments_at_subpath_parameters(
  segments: List(svg_path.Segment),
  split_points: List(svg_path.SubpathParameter),
  index index: Int,
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
      let parameters =
        split_parameters_for_segment(split_points, index, [
          SplitParameter(0.0, False),
          SplitParameter(1.0, False),
        ])
        |> list.sort(by: fn(a, b) {
          let SplitParameter(t: left, ..) = a
          let SplitParameter(t: right, ..) = b
          float.compare(left, right)
        })
        |> unique_split_parameters(point_tolerance, [])

      use pieces <- result.try(split_parametric_piece(first, parameters))
      let #(current, sections) =
        append_split_pieces(pieces, current: current, sections: sections)
      split_segments_at_subpath_parameters(
        rest,
        split_points,
        index: index + 1,
        current:,
        sections:,
      )
    }
  }
}

fn split_parameters_for_segment(
  split_points: List(svg_path.SubpathParameter),
  index: Int,
  parameters: List(SplitParameter),
) -> List(SplitParameter) {
  case split_points {
    [] -> parameters
    [first, ..rest] -> {
      let svg_path.SubpathParameter(segment_index:, t:) = first
      let parameters = case segment_index == index {
        True -> [
          SplitParameter(float.min(1.0, float.max(0.0, t)), True),
          ..parameters
        ]
        False -> parameters
      }
      split_parameters_for_segment(rest, index, parameters)
    }
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
        [] -> unique_split_parameters(rest, tolerance, unique: [first])
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
      let SplitParameter(t: from_t, cut: from_cut) = from
      let SplitParameter(t: to_t, cut: to_cut) = to
      use pieces <- result.try(split_parametric_piece(segment, [to, ..rest]))
      case to_t -. from_t <=. point_tolerance {
        True -> Ok(pieces)
        False -> {
          use piece <- result.try(
            svg_path.segment_between_many_inside(segment, between: [
              from_t,
              to_t,
            ])
            |> result.map_error(PathError),
          )
          Ok(list.append(
            piece
              |> list.map(fn(segment) {
                SplitPiece(segment:, start_is_cut: from_cut, end_is_cut: to_cut)
              }),
            pieces,
          ))
        }
      }
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
    [SplitPiece(segment:, start_is_cut:, end_is_cut:), ..rest] -> {
      let #(current, sections) = case start_is_cut, current {
        True, [_, ..] -> #([], [list.reverse(current), ..sections])
        _, _ -> #(current, sections)
      }
      let current = [segment, ..current]
      case end_is_cut {
        True ->
          append_split_pieces(rest, current: [], sections: [
            list.reverse(current),
            ..sections
          ])
        False -> append_split_pieces(rest, current:, sections:)
      }
    }
  }
}

fn section_sample_parameters() -> List(Float) {
  [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
}

fn retain_band_boundary_sections(
  sections: List(List(svg_path.Segment)),
  source source: svg_path.Subpath,
  distance_a distance_a: Float,
  distance_b distance_b: Float,
  options options: Options,
  retained retained: List(List(svg_path.Segment)),
) -> Result(List(List(svg_path.Segment)), Error) {
  case sections {
    [] -> Ok(list.reverse(retained))
    [first, ..rest] -> {
      use keep <- result.try(band_section_is_boundary(
        first,
        source:,
        distance_a:,
        distance_b:,
        options:,
      ))
      let retained = case keep {
        True -> [first, ..retained]
        False -> retained
      }
      retain_band_boundary_sections(
        rest,
        source:,
        distance_a:,
        distance_b:,
        options:,
        retained:,
      )
    }
  }
}

fn band_section_is_boundary(
  section: List(svg_path.Segment),
  source source: svg_path.Subpath,
  distance_a distance_a: Float,
  distance_b distance_b: Float,
  options options: Options,
) -> Result(Bool, Error) {
  use section <- result.try(normalize_chunk(section, options.fitting.tolerance))
  use section <- result.try(
    svg_path.subpath_with(
      section,
      policy: svg_path.WiggleWith(options.fitting.tolerance),
    )
    |> result.map_error(PathError),
  )
  use length <- result.try(
    svg_path.subpath_length(section) |> result.map_error(PathError),
  )
  use score <- result.try(band_section_boundary_score(
    section,
    length,
    section_sample_parameters(),
    source:,
    distance_a:,
    distance_b:,
    options:,
    score: 0,
  ))
  Ok(int.absolute_value(score) >= 5)
}

fn band_section_boundary_score(
  section: svg_path.Subpath,
  length: Float,
  samples: List(Float),
  source source: svg_path.Subpath,
  distance_a distance_a: Float,
  distance_b distance_b: Float,
  options options: Options,
  score score: Int,
) -> Result(Int, Error) {
  case samples {
    [] -> Ok(score)
    [first, ..rest] -> {
      use sample_score <- result.try(band_section_sample_score(
        section,
        length *. first,
        source:,
        distance_a:,
        distance_b:,
        options:,
      ))
      band_section_boundary_score(
        section,
        length,
        rest,
        source:,
        distance_a:,
        distance_b:,
        options:,
        score: score + sample_score,
      )
    }
  }
}

fn band_section_sample_score(
  section: svg_path.Subpath,
  distance distance_along_section: Float,
  source source: svg_path.Subpath,
  distance_a distance_a: Float,
  distance_b distance_b: Float,
  options options: Options,
) -> Result(Int, Error) {
  use point <- result.try(
    svg_path.subpath_point_at_length(section, distance: distance_along_section)
    |> result.map_error(PathError),
  )
  use derivative <- result.try(
    svg_path.subpath_derivative_at_length(
      section,
      distance: distance_along_section,
    )
    |> result.map_error(PathError),
  )
  use tangent_length <- result.try(length(derivative, t: 0.5))
  let tangent = scale(derivative, 1.0 /. tangent_length)
  let normal = rotate_clockwise(tangent)
  let probe_distance =
    boundary_probe_distance(distance_a, distance_b, options.fitting.tolerance)
  let left_probe = add(point, scale(normal, 0.0 -. probe_distance))
  let right_probe = add(point, scale(normal, probe_distance))
  use left <- result.try(in_band(
    left_probe,
    source:,
    distance_a:,
    distance_b:,
    options:,
  ))
  use right <- result.try(in_band(
    right_probe,
    source:,
    distance_a:,
    distance_b:,
    options:,
  ))
  Ok(bool_int(left) - bool_int(right))
}

fn retain_stroke_boundary_sections(
  sections: List(List(svg_path.Segment)),
  source source: svg_path.Subpath,
  radius radius: Float,
  cap cap: Cap,
  options options: Options,
  retained retained: List(List(svg_path.Segment)),
) -> Result(List(List(svg_path.Segment)), Error) {
  case sections {
    [] -> Ok(list.reverse(retained))
    [first, ..rest] -> {
      use keep <- result.try(stroke_section_is_boundary(
        first,
        source:,
        radius:,
        cap:,
        options:,
      ))
      let retained = case keep {
        True -> [first, ..retained]
        False -> retained
      }
      retain_stroke_boundary_sections(
        rest,
        source:,
        radius:,
        cap:,
        options:,
        retained:,
      )
    }
  }
}

fn stroke_section_is_boundary(
  section: List(svg_path.Segment),
  source source: svg_path.Subpath,
  radius radius: Float,
  cap cap: Cap,
  options options: Options,
) -> Result(Bool, Error) {
  use section <- result.try(normalize_chunk(section, options.fitting.tolerance))
  use section <- result.try(
    svg_path.subpath_with(
      section,
      policy: svg_path.WiggleWith(options.fitting.tolerance),
    )
    |> result.map_error(PathError),
  )
  use length <- result.try(
    svg_path.subpath_length(section) |> result.map_error(PathError),
  )
  use score <- result.try(stroke_section_boundary_score(
    section,
    length,
    section_sample_parameters(),
    source:,
    radius:,
    cap:,
    options:,
    score: 0,
  ))
  Ok(int.absolute_value(score) >= 5)
}

fn stroke_section_boundary_score(
  section: svg_path.Subpath,
  length: Float,
  samples: List(Float),
  source source: svg_path.Subpath,
  radius radius: Float,
  cap cap: Cap,
  options options: Options,
  score score: Int,
) -> Result(Int, Error) {
  case samples {
    [] -> Ok(score)
    [first, ..rest] -> {
      use sample_score <- result.try(stroke_section_sample_score(
        section,
        length *. first,
        source:,
        radius:,
        cap:,
        options:,
      ))
      stroke_section_boundary_score(
        section,
        length,
        rest,
        source:,
        radius:,
        cap:,
        options:,
        score: score + sample_score,
      )
    }
  }
}

fn stroke_section_sample_score(
  section: svg_path.Subpath,
  distance distance_along_section: Float,
  source source: svg_path.Subpath,
  radius radius: Float,
  cap cap: Cap,
  options options: Options,
) -> Result(Int, Error) {
  use point <- result.try(
    svg_path.subpath_point_at_length(section, distance: distance_along_section)
    |> result.map_error(PathError),
  )
  use derivative <- result.try(
    svg_path.subpath_derivative_at_length(
      section,
      distance: distance_along_section,
    )
    |> result.map_error(PathError),
  )
  use tangent_length <- result.try(length(derivative, t: 0.5))
  let tangent = scale(derivative, 1.0 /. tangent_length)
  let normal = rotate_clockwise(tangent)
  let probe_distance =
    boundary_probe_distance(0.0 -. radius, radius, options.fitting.tolerance)
  let left_probe = add(point, scale(normal, 0.0 -. probe_distance))
  let right_probe = add(point, scale(normal, probe_distance))
  use left <- result.try(in_stroke(left_probe, source:, radius:, cap:, options:))
  use right <- result.try(in_stroke(
    right_probe,
    source:,
    radius:,
    cap:,
    options:,
  ))
  Ok(bool_int(left) - bool_int(right))
}

fn boundary_probe_distance(
  distance_a: Float,
  distance_b: Float,
  tolerance: Float,
) -> Float {
  let base = float.max(tolerance *. 10.0, 0.000001)
  let width = float.absolute_value(distance_a -. distance_b)
  case width <=. point_tolerance {
    True -> base
    False -> float.min(base, width /. 100.0)
  }
}

fn in_stroke(
  point: svg_path.Point,
  source source: svg_path.Subpath,
  radius radius: Float,
  cap cap: Cap,
  options options: Options,
) -> Result(Bool, Error) {
  use in_body <- result.try(in_band(
    point,
    source:,
    distance_a: 0.0 -. radius,
    distance_b: radius,
    options:,
  ))
  case in_body {
    True -> Ok(True)
    False -> in_stroke_cap(point, source:, radius:, cap:)
  }
}

fn in_stroke_cap(
  point: svg_path.Point,
  source source: svg_path.Subpath,
  radius radius: Float,
  cap cap: Cap,
) -> Result(Bool, Error) {
  case cap {
    Butt -> Ok(False)
    RoundCap -> {
      use start <- result.try(
        svg_path.subpath_start(source) |> result.map_error(PathError),
      )
      use end <- result.try(
        svg_path.subpath_end(source) |> result.map_error(PathError),
      )
      Ok(
        distance_squared(point, start) <=. radius *. radius
        || distance_squared(point, end) <=. radius *. radius,
      )
    }
    Square -> {
      let segments = svg_path.subpath_segments(source)
      let assert [first, ..] = segments
      let assert Ok(last) = list.last(segments)
      use start <- result.try(
        svg_path.subpath_start(source) |> result.map_error(PathError),
      )
      use end <- result.try(
        svg_path.subpath_end(source) |> result.map_error(PathError),
      )
      use start_tangent <- result.try(unit_tangent(first, t: 0.0))
      use end_tangent <- result.try(unit_tangent(last, t: 1.0))
      Ok(
        point_in_square_cap(
          point,
          center: start,
          tangent: start_tangent,
          radius:,
          at_end: False,
        )
        || point_in_square_cap(
          point,
          center: end,
          tangent: end_tangent,
          radius:,
          at_end: True,
        ),
      )
    }
  }
}

fn point_in_square_cap(
  point: svg_path.Point,
  center center: svg_path.Point,
  tangent tangent: svg_path.Point,
  radius radius: Float,
  at_end at_end: Bool,
) -> Bool {
  let delta = subtract(point, center)
  let normal = rotate_clockwise(tangent)
  let along = dot(delta, tangent)
  let across = dot(delta, normal)
  let along_ok = case at_end {
    True ->
      along >=. 0.0 -. point_tolerance && along <=. radius +. point_tolerance
    False ->
      along <=. point_tolerance && along >=. 0.0 -. radius -. point_tolerance
  }
  along_ok && float.absolute_value(across) <=. radius +. point_tolerance
}

fn bool_int(value: Bool) -> Int {
  case value {
    True -> 1
    False -> 0
  }
}

fn in_band(
  point: svg_path.Point,
  source source: svg_path.Subpath,
  distance_a distance_a: Float,
  distance_b distance_b: Float,
  options options: Options,
) -> Result(Bool, Error) {
  use in_body <- result.try(in_band_segments(
    point,
    svg_path.subpath_segments(source),
    distance_a:,
    distance_b:,
    options:,
  ))
  case in_body {
    True -> Ok(True)
    False ->
      in_band_joins(
        point,
        svg_path.subpath_segments(source),
        closed: svg_path.subpath_is_closed(source),
        distance_a:,
        distance_b:,
        options:,
      )
  }
}

fn in_band_segments(
  point: svg_path.Point,
  segments: List(svg_path.Segment),
  distance_a distance_a: Float,
  distance_b distance_b: Float,
  options options: Options,
) -> Result(Bool, Error) {
  case segments {
    [] -> Ok(False)
    [first, ..rest] -> {
      use current <- result.try(in_band_segment(
        point,
        first,
        distance_a:,
        distance_b:,
        options:,
      ))
      case current {
        True -> Ok(True)
        False ->
          in_band_segments(point, rest, distance_a:, distance_b:, options:)
      }
    }
  }
}

fn in_band_segment(
  point: svg_path.Point,
  segment: svg_path.Segment,
  distance_a distance_a: Float,
  distance_b distance_b: Float,
  options options: Options,
) -> Result(Bool, Error) {
  use parameters <- result.try(normal_projection_parameters(
    point,
    segment,
    options,
  ))
  in_band_segment_parameters(
    point,
    segment,
    parameters,
    distance_a:,
    distance_b:,
    tolerance: options.fitting.tolerance,
  )
}

fn in_band_joins(
  point: svg_path.Point,
  segments: List(svg_path.Segment),
  closed closed: Bool,
  distance_a distance_a: Float,
  distance_b distance_b: Float,
  options options: Options,
) -> Result(Bool, Error) {
  case segments {
    [] | [_] -> Ok(False)
    [first, ..rest] -> {
      use internal <- result.try(in_band_adjacent_joins(
        point,
        previous: first,
        rest:,
        distance_a:,
        distance_b:,
        options:,
      ))
      case internal {
        True -> Ok(True)
        False ->
          case closed {
            False -> Ok(False)
            True -> {
              use last <- result.try(
                list.last(segments) |> result.map_error(fn(_) { NonFinite }),
              )
              in_band_join(
                point,
                left: last,
                right: first,
                distance_a:,
                distance_b:,
                options:,
              )
            }
          }
      }
    }
  }
}

fn in_band_adjacent_joins(
  point: svg_path.Point,
  previous previous: svg_path.Segment,
  rest rest: List(svg_path.Segment),
  distance_a distance_a: Float,
  distance_b distance_b: Float,
  options options: Options,
) -> Result(Bool, Error) {
  case rest {
    [] -> Ok(False)
    [next, ..remaining] -> {
      use current <- result.try(in_band_join(
        point,
        left: previous,
        right: next,
        distance_a:,
        distance_b:,
        options:,
      ))
      case current {
        True -> Ok(True)
        False ->
          in_band_adjacent_joins(
            point,
            previous: next,
            rest: remaining,
            distance_a:,
            distance_b:,
            options:,
          )
      }
    }
  }
}

fn in_band_join(
  point: svg_path.Point,
  left left: svg_path.Segment,
  right right: svg_path.Segment,
  distance_a distance_a: Float,
  distance_b distance_b: Float,
  options options: Options,
) -> Result(Bool, Error) {
  use region <- result.try(band_join_region(
    left,
    right,
    distance_a:,
    distance_b:,
    options:,
  ))
  case region {
    None -> Ok(False)
    Some(region) -> {
      let containment_options =
        svg_path.ContainmentOptions(
          ..svg_path.default_containment_options(),
          tolerance: options.fitting.tolerance,
        )
      use containment <- result.try(
        svg_path.subpath_containment_with(
          point,
          within: region,
          using: svg_path.EvenOdd,
          options: containment_options,
        )
        |> result.map_error(PathError),
      )
      case containment {
        svg_path.Outside -> Ok(False)
        svg_path.Inside | svg_path.Boundary -> Ok(True)
      }
    }
  }
}

fn band_join_region(
  left: svg_path.Segment,
  right: svg_path.Segment,
  distance_a distance_a: Float,
  distance_b distance_b: Float,
  options options: Options,
) -> Result(Option(svg_path.Subpath), Error) {
  use left_a <- result.try(join_offset_segment_end(left, distance_a))
  use right_a <- result.try(join_offset_segment_start(right, distance_a))
  use left_b <- result.try(join_offset_segment_end(left, distance_b))
  use right_b <- result.try(join_offset_segment_start(right, distance_b))
  use join_a <- result.try(parametric_join_segments(
    left_a,
    right_a,
    distance_a,
    options.join,
  ))
  use join_b <- result.try(parametric_join_segments(
    left_b,
    right_b,
    distance_b,
    options.join,
  ))
  let left_a_end = svg_path.segment_end(left_a.segment)
  let right_a_start = svg_path.segment_start(right_a.segment)
  let left_b_end = svg_path.segment_end(left_b.segment)
  let right_b_start = svg_path.segment_start(right_b.segment)
  let segments =
    list.append(
      join_a,
      list.append(
        line_segments_between([right_a_start, right_b_start]),
        list.append(
          reverse_segments(join_b),
          line_segments_between([left_b_end, left_a_end]),
        ),
      ),
    )
  case list.length(segments) < 3 {
    True -> Ok(None)
    False -> {
      use region <- result.try(
        svg_path.subpath_with(segments, policy: svg_path.Wiggle)
        |> result.map_error(PathError),
      )
      use region <- result.try(
        svg_path.subpath_set_closed_with(
          region,
          closed: True,
          policy: svg_path.Wiggle,
        )
        |> result.map_error(PathError),
      )
      Ok(Some(region))
    }
  }
}

fn join_offset_segment_start(
  segment: svg_path.Segment,
  distance: Float,
) -> Result(GHealedOffsetSegment, Error) {
  join_offset_segment_endpoint(segment, distance, endpoint: SegmentStart)
}

fn join_offset_segment_end(
  segment: svg_path.Segment,
  distance: Float,
) -> Result(GHealedOffsetSegment, Error) {
  join_offset_segment_endpoint(segment, distance, endpoint: SegmentEnd)
}

fn join_offset_segment_endpoint(
  segment: svg_path.Segment,
  distance: Float,
  endpoint endpoint: SegmentEndpoint,
) -> Result(GHealedOffsetSegment, Error) {
  let t = case endpoint {
    SegmentStart -> 0.0
    SegmentEnd -> 1.0
  }
  use point <- result.try(offset_point(segment, t:, distance:))
  let source = whole_e_join_free_source(segment)
  let assert OffsetFromJoinFree(join_free) = source
  use policy <- result.try(e_join_free_endpoint_policy(
    join_free,
    distance,
    endpoint:,
  ))
  use direction <- result.try(case policy {
    FitPositionAndDirection(direction)
    | FitPositionAndDirectionWithCollapsedHandle(direction) -> Ok(direction)
    FitPositionOnly -> Error(NonFinite)
  })
  Ok(GHealedOffsetSegment(
    segment: svg_path.Line(start: point, end: point),
    source:,
    nudged_start_tangent_direction: direction,
    nudged_end_tangent_direction: direction,
  ))
}

fn in_band_segment_parameters(
  point: svg_path.Point,
  segment: svg_path.Segment,
  parameters: List(Float),
  distance_a distance_a: Float,
  distance_b distance_b: Float,
  tolerance tolerance: Float,
) -> Result(Bool, Error) {
  case parameters {
    [] -> Ok(False)
    [first, ..rest] -> {
      use signed_distance <- result.try(signed_normal_distance(
        point,
        segment,
        t: first,
      ))
      case
        distance_in_interval(signed_distance, distance_a, distance_b, tolerance)
      {
        True -> Ok(True)
        False ->
          in_band_segment_parameters(
            point,
            segment,
            rest,
            distance_a:,
            distance_b:,
            tolerance:,
          )
      }
    }
  }
}

fn distance_in_interval(
  value: Float,
  a: Float,
  b: Float,
  tolerance: Float,
) -> Bool {
  let low = float.min(a, b) -. tolerance
  let high = float.max(a, b) +. tolerance
  value >=. low && value <=. high
}

fn signed_normal_distance(
  point: svg_path.Point,
  segment: svg_path.Segment,
  t t: Float,
) -> Result(Float, Error) {
  use source_point <- result.try(
    svg_path.segment_point(segment, at: t) |> result.map_error(PathError),
  )
  use normal <- result.try(unit_normal(segment, t:))
  Ok(dot(subtract(point, source_point), normal))
}

fn normal_projection_parameters(
  point: svg_path.Point,
  segment: svg_path.Segment,
  options: Options,
) -> Result(List(Float), Error) {
  use first_value <- result.try(normal_projection_value(point, segment, 0.0))
  scan_normal_projection_parameters(
    point,
    segment,
    options,
    index: 1,
    previous_t: 0.0,
    previous_value: first_value,
    parameters: [],
  )
}

fn scan_normal_projection_parameters(
  point: svg_path.Point,
  segment: svg_path.Segment,
  options: Options,
  index index: Int,
  previous_t previous_t: Float,
  previous_value previous_value: Float,
  parameters parameters: List(Float),
) -> Result(List(Float), Error) {
  case index > options.trimming.samples {
    True -> Ok(parameters |> unique_floats(options.trimming.tolerance, []))
    False -> {
      let next_t = int_to_float(index) /. int_to_float(options.trimming.samples)
      use next_value <- result.try(normal_projection_value(
        point,
        segment,
        next_t,
      ))
      use candidate <- result.try(normal_projection_candidate(
        point,
        segment,
        options,
        previous_t,
        previous_value,
        next_t,
        next_value,
      ))
      let parameters = case candidate {
        Some(t) -> [t, ..parameters]
        None -> parameters
      }
      scan_normal_projection_parameters(
        point,
        segment,
        options,
        index: index + 1,
        previous_t: next_t,
        previous_value: next_value,
        parameters:,
      )
    }
  }
}

fn normal_projection_candidate(
  point: svg_path.Point,
  segment: svg_path.Segment,
  options: Options,
  previous_t: Float,
  previous_value: Float,
  next_t: Float,
  next_value: Float,
) -> Result(Option(Float), Error) {
  case float.absolute_value(previous_value) <=. options.trimming.tolerance {
    True -> Ok(Some(previous_t))
    False ->
      case float.absolute_value(next_value) <=. options.trimming.tolerance {
        True -> Ok(Some(next_t))
        False ->
          case same_sign(previous_value, next_value) {
            True -> Ok(None)
            False -> {
              let root_options =
                root.Options(
                  tolerance: options.trimming.tolerance,
                  max_iterations: options.trimming.max_iterations,
                )
              case
                root.bisect_with(
                  fn(t) {
                    let assert Ok(value) =
                      normal_projection_value(point, segment, t)
                    value
                  },
                  from: previous_t,
                  to: next_t,
                  options: root_options,
                )
              {
                Ok(t) -> Ok(Some(t))
                Error(root.MaxIterationsReached(..)) -> Error(NonFinite)
                Error(_) -> Ok(None)
              }
            }
          }
      }
  }
}

fn normal_projection_value(
  point: svg_path.Point,
  segment: svg_path.Segment,
  t: Float,
) -> Result(Float, Error) {
  use source_point <- result.try(
    svg_path.segment_point(segment, at: t) |> result.map_error(PathError),
  )
  use derivative <- result.try(
    svg_path.segment_derivative(segment, at: t) |> result.map_error(PathError),
  )
  Ok(dot(subtract(point, source_point), derivative))
}

fn unique_floats(
  values: List(Float),
  tolerance: Float,
  unique unique: List(Float),
) -> List(Float) {
  case values |> list.sort(by: float.compare) {
    [] -> list.reverse(unique)
    [first, ..rest] ->
      case unique {
        [previous, ..] -> {
          case float.absolute_value(first -. previous) <=. tolerance {
            True -> unique_floats(rest, tolerance, unique:)
            False -> unique_floats(rest, tolerance, unique: [first, ..unique])
          }
        }
        [] -> unique_floats(rest, tolerance, unique: [first])
      }
  }
}

fn same_sign(a: Float, b: Float) -> Bool {
  { a <. 0.0 && b <. 0.0 } || { a >. 0.0 && b >. 0.0 }
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
        svg_path.subpath_with(
          first,
          policy: svg_path.WiggleThenBridgeWith(tolerance),
        )
        |> result.map_error(PathError),
      )
      use subpath <- result.try(case close {
        True ->
          svg_path.subpath_set_closed_with(
            subpath,
            closed: True,
            policy: svg_path.WiggleThenBridgeWith(tolerance),
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
    [_, ..] -> {
      use subpath <- result.try(
        svg_path.subpath_with(
          chunk,
          policy: snap_chunk_endpoint_policy(tolerance),
        )
        |> result.map_error(PathError),
      )
      Ok(svg_path.subpath_segments(subpath))
    }
  }
}

fn snap_chunk_endpoint_policy(tolerance: Float) -> svg_path.EndpointPolicy {
  svg_path.Custom(fn(previous, next, closing) {
    let previous_end = svg_path.segment_end(previous)
    let next_start = svg_path.segment_start(next)
    case same_point(previous_end, next_start, tolerance), closing {
      True, True -> [snap_segment_end(previous, next_start)]
      True, False -> [previous, snap_segment_start(next, previous_end)]
      False, True -> [previous]
      False, False -> [previous, next]
    }
  })
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

fn self_intersection_split_parameters(
  subpath: svg_path.Subpath,
) -> Result(List(svg_path.SubpathParameter), Error) {
  use intersections <- result.try(
    intersections.subpath_self_with(
      subpath,
      options: svg_path.SelfIntersectionOptions(
        minimum_arc_length_separation: 2.0 *. point_tolerance,
        distance_tolerance: point_tolerance,
      ),
    )
    |> result.map_error(PathError),
  )

  let parameters =
    intersections
    |> list.flat_map(fn(intersection) {
      let svg_path.SubpathSelfIntersection(parameters: #(left, right), ..) =
        intersection
      [left, right]
    })
    |> list.filter(fn(parameter) {
      !is_open_subpath_boundary_parameter(subpath, parameter)
    })
    |> list.sort(by: svg_path.subpath_parameters_compare)
    |> unique_subpath_parameters(point_tolerance, [])

  Ok(parameters)
}

fn is_open_subpath_boundary_parameter(
  subpath: svg_path.Subpath,
  parameter: svg_path.SubpathParameter,
) -> Bool {
  case svg_path.subpath_is_closed(subpath) {
    True -> False
    False -> {
      let length = list.length(svg_path.subpath_segments(subpath))
      let svg_path.SubpathParameter(segment_index:, t:) = parameter
      { segment_index == 0 && t <=. point_tolerance }
      || { segment_index == length - 1 && t >=. 1.0 -. point_tolerance }
    }
  }
}

fn unique_subpath_parameters(
  values: List(svg_path.SubpathParameter),
  tolerance: Float,
  unique unique: List(svg_path.SubpathParameter),
) -> List(svg_path.SubpathParameter) {
  case values {
    [] -> list.reverse(unique)
    [first, ..rest] -> {
      case unique {
        [previous, ..] -> {
          case same_subpath_parameter(first, previous, tolerance) {
            True -> unique_subpath_parameters(rest, tolerance, unique:)
            False ->
              unique_subpath_parameters(rest, tolerance, unique: [
                first,
                ..unique
              ])
          }
        }
        [] -> unique_subpath_parameters(rest, tolerance, unique: [first])
      }
    }
  }
}

fn same_subpath_parameter(
  left: svg_path.SubpathParameter,
  right: svg_path.SubpathParameter,
  tolerance: Float,
) -> Bool {
  let svg_path.SubpathParameter(segment_index: left_index, t: left_t) = left
  let svg_path.SubpathParameter(segment_index: right_index, t: right_t) = right
  left_index == right_index
  && float.absolute_value(left_t -. right_t) <=. tolerance
}

fn same_point(a: svg_path.Point, b: svg_path.Point, tolerance: Float) -> Bool {
  distance_squared(a, b) <=. tolerance *. tolerance
}

fn distance_margin(options: Options) -> Float {
  options.fitting.tolerance *. 1.1
}

fn build_offset_segments_with_zero_source(
  subpath: svg_path.Subpath,
  distance: Float,
  options: Options,
) -> Result(OffsetSegmentsBuild, Error) {
  use portions <- result.try(join_free_portions(subpath, options))
  build_offset_portions_with_zero_source(
    portions,
    distance,
    options,
    converted_offsets: [],
    converted_zero_source: [],
  )
}

fn build_offset_portions_with_zero_source(
  portions: List(JoinFreePortion),
  distance: Float,
  options: Options,
  converted_offsets converted_offsets: List(GHealedOffsetSegment),
  converted_zero_source converted_zero_source: List(svg_path.Segment),
) -> Result(OffsetSegmentsBuild, Error) {
  case portions {
    [] ->
      Ok(OffsetSegmentsBuild(
        offsets: list.reverse(converted_offsets),
        zero_source_segments: list.reverse(converted_zero_source),
      ))
    [first, ..rest] -> {
      use build <- result.try(stalled_run_offset_segments_with_zero_source(
        first,
        distance,
        options,
      ))
      build_offset_portions_with_zero_source(
        rest,
        distance,
        options,
        converted_offsets: list.append(
          list.reverse(build.offsets),
          converted_offsets,
        ),
        converted_zero_source: list.append(
          list.reverse(build.zero_source_segments),
          converted_zero_source,
        ),
      )
    }
  }
}

fn join_free_portions(
  subpath: svg_path.Subpath,
  options: Options,
) -> Result(List(JoinFreePortion), Error) {
  case svg_path.subpath_segments(subpath) {
    [] -> Ok([])
    segments -> {
      use portions <- result.try(
        split_join_free_portions(segments, options, current: [], portions: []),
      )
      Ok(
        mark_closed_join_free_portion(
          portions,
          closed: svg_path.subpath_is_closed(subpath),
        )
        |> index_join_free_portions(index: 0, indexed: []),
      )
    }
  }
}

/// Return the actual join-free portions and refined source pieces used by the
/// offset pipeline. This is for debug fixtures only.
@internal
pub fn internal_offset_source_trace(
  subpath subpath: svg_path.Subpath,
  distance distance: Float,
  options options: Options,
) -> Result(List(OffsetSourceTracePortion), Error) {
  use _ <- result.try(validate_options(options))
  use normalized <- result.try(normalize_source_subpath(subpath, options))
  use portions <- result.try(join_free_portions(normalized, options))
  Ok(offset_source_trace_portions(portions, distance, options, index: 0))
}

fn offset_source_trace_portions(
  portions: List(JoinFreePortion),
  distance: Float,
  options: Options,
  index index: Int,
) -> List(OffsetSourceTracePortion) {
  case portions {
    [] -> []
    [first, ..rest] -> {
      let JoinFreePortion(subpath:, ..) = first
      [
        OffsetSourceTracePortion(
          index:,
          subpath:,
          pieces: offset_source_trace_pieces(subpath, distance, options),
        ),
        ..offset_source_trace_portions(
          rest,
          distance,
          options,
          index: index + 1,
        )
      ]
    }
  }
}

fn offset_source_trace_pieces(
  subpath: svg_path.Subpath,
  distance: Float,
  options: Options,
) -> List(OffsetSourceTracePiece) {
  let classified =
    subpath
    |> prepared_segments(source_subpath_index: 0)
    |> classify_prepared_segments(
      distance,
      threshold: options.stalled_offset_diameter,
    )
    |> mark_classified_segment_cross_reversals(distance)
  case
    refine_b_classified_segments_for_offset(
      classified,
      distance,
      options.stalled_offset_diameter,
      refined: [],
    )
  {
    Error(_) -> []
    Ok(refined) ->
      offset_source_trace_d_offset_pieces(
        refined,
        refined_piece_index: 0,
        traced: [],
      )
  }
}

fn offset_source_trace_d_offset_pieces(
  pieces: List(DOffsetPiece),
  refined_piece_index refined_piece_index: Int,
  traced traced: List(OffsetSourceTracePiece),
) -> List(OffsetSourceTracePiece) {
  case pieces {
    [] -> list.reverse(traced)
    [DNotStalled(first), ..rest] -> {
      let next = offset_source_trace_d_refined([first], refined_piece_index, [])
      offset_source_trace_d_offset_pieces(
        rest,
        refined_piece_index: refined_piece_index + 1,
        traced: list.append(next, traced),
      )
    }
    [DStalled(CStalledSegment(prepared:, segment:, ..)), ..rest] -> {
      let APreparedSegment(source_segment_index:, ..) = prepared
      offset_source_trace_d_offset_pieces(
        rest,
        refined_piece_index: refined_piece_index + 1,
        traced: [
          OffsetSourceTraceStalled(source_segment_index:, segment:),
          ..traced
        ],
      )
    }
  }
}

fn offset_source_trace_d_refined(
  refined: List(DRefinedSegment),
  refined_piece_index: Int,
  traced: List(OffsetSourceTracePiece),
) -> List(OffsetSourceTracePiece) {
  case refined {
    [] -> traced
    [first, ..rest] -> {
      let DRefinedSegment(
        prepared: APreparedSegment(source_segment_index:, ..),
        prepared_from:,
        prepared_to:,
        segment:,
        start_boundary:,
        end_boundary:,
      ) = first
      offset_source_trace_d_refined(rest, refined_piece_index + 1, [
        OffsetSourceTraceDRefined(
          source_segment_index:,
          refined_piece_index:,
          source_from: prepared_from,
          source_to: prepared_to,
          segment:,
          start_is_reversal: boundary_is_reversal(start_boundary),
          end_is_reversal: boundary_is_reversal(end_boundary),
        ),
        ..traced
      ])
    }
  }
}

fn stalled_run_offset_segments_with_zero_source(
  portion: JoinFreePortion,
  distance: Float,
  options: Options,
) -> Result(OffsetSegmentsBuild, Error) {
  use build <- result.try(stalled_run_offset_segments_without_postconditions(
    portion,
    distance,
    options,
  ))
  use _ <- result.try(assert_smooth_offset_postconditions(
    g_healed_to_f_unhealed_offset_segments(build.offsets),
    options.tangent_heal_angle_degrees,
  ))
  Ok(build)
}

fn stalled_run_offset_segments_without_postconditions(
  portion: JoinFreePortion,
  distance: Float,
  options: Options,
) -> Result(OffsetSegmentsBuild, Error) {
  let JoinFreePortion(index:, subpath:, closed:) = portion
  let pieces =
    subpath
    |> prepared_segments(source_subpath_index: 0)
    |> classify_prepared_segments(
      distance,
      threshold: options.stalled_offset_diameter,
    )
    |> mark_classified_segment_cross_reversals(distance)
  offset_classified_segments_with_zero_source(
    pieces,
    distance,
    options,
    portion_index: index,
    closed:,
    converted: [],
  )
}

fn classify_prepared_segments(
  segments: List(APreparedSegment),
  distance: Float,
  threshold threshold: Float,
) -> List(BClassifiedSegment) {
  classify_prepared_segments_loop(segments, distance, threshold, pieces: [])
}

fn classify_prepared_segments_loop(
  segments: List(APreparedSegment),
  distance: Float,
  threshold: Float,
  pieces pieces: List(BClassifiedSegment),
) -> List(BClassifiedSegment) {
  case segments {
    [] -> list.reverse(pieces)
    [first, ..rest] -> {
      let APreparedSegment(segment:, ..) = first
      case source_segment_offset_is_stalled(segment, distance, threshold) {
        True ->
          classify_prepared_segments_loop(rest, distance, threshold, pieces: [
            BStalled(CStalledSegment(
              prepared: first,
              prepared_from: 0.0,
              prepared_to: 1.0,
              segment:,
            )),
            ..pieces
          ])
        False -> {
          classify_prepared_segments_loop(rest, distance, threshold, pieces: [
            BNotStalled(CNotStalledSegment(
              prepared: first,
              start_boundary: Ordinary,
              end_boundary: Ordinary,
            )),
            ..pieces
          ])
        }
      }
    }
  }
}

fn prepared_segments(
  subpath: svg_path.Subpath,
  source_subpath_index source_subpath_index: Int,
) -> List(APreparedSegment) {
  prepared_segments_loop(
    svg_path.subpath_segments(subpath),
    source_subpath_index,
    source_segment_index: 0,
    prepared: [],
  )
}

fn prepared_segments_loop(
  segments: List(svg_path.Segment),
  source_subpath_index: Int,
  source_segment_index source_segment_index: Int,
  prepared prepared: List(APreparedSegment),
) -> List(APreparedSegment) {
  case segments {
    [] -> list.reverse(prepared)
    [first, ..rest] ->
      prepared_segments_loop(
        rest,
        source_subpath_index,
        source_segment_index: source_segment_index + 1,
        prepared: [
          APreparedSegment(
            source_subpath_index:,
            source_segment_index:,
            segment: first,
          ),
          ..prepared
        ],
      )
  }
}

fn mark_classified_segment_cross_reversals(
  pieces: List(BClassifiedSegment),
  distance: Float,
) -> List(BClassifiedSegment) {
  case pieces {
    [] | [_] -> pieces
    [first, second, ..rest] ->
      mark_classified_segment_cross_reversals_loop(
        first,
        [second, ..rest],
        distance,
        marked: [],
      )
  }
}

fn mark_classified_segment_cross_reversals_loop(
  previous: BClassifiedSegment,
  rest: List(BClassifiedSegment),
  distance: Float,
  marked marked: List(BClassifiedSegment),
) -> List(BClassifiedSegment) {
  case rest {
    [] -> list.reverse([previous, ..marked])
    [next, ..remaining] -> {
      let #(previous, next) =
        mark_adjacent_classified_segment_cross_reversal(
          previous,
          next,
          distance,
        )
      mark_classified_segment_cross_reversals_loop(
        next,
        remaining,
        distance,
        marked: [previous, ..marked],
      )
    }
  }
}

fn mark_adjacent_classified_segment_cross_reversal(
  left: BClassifiedSegment,
  right: BClassifiedSegment,
  distance: Float,
) -> #(BClassifiedSegment, BClassifiedSegment) {
  case left, right {
    BNotStalled(left_not_stalled), BNotStalled(right_not_stalled) -> {
      let CNotStalledSegment(
        prepared: APreparedSegment(segment: left_segment, ..),
        start_boundary: left_start_boundary,
        ..,
      ) = left_not_stalled
      let CNotStalledSegment(
        prepared: APreparedSegment(segment: right_segment, ..),
        end_boundary: right_end_boundary,
        ..,
      ) = right_not_stalled
      case
        source_segments_have_boundary_reversal(
          left_segment,
          right_segment,
          distance,
        )
      {
        True -> #(
          BNotStalled(
            CNotStalledSegment(
              ..left_not_stalled,
              start_boundary: left_start_boundary,
              end_boundary: ReversalBoundary,
            ),
          ),
          BNotStalled(
            CNotStalledSegment(
              ..right_not_stalled,
              start_boundary: ReversalBoundary,
              end_boundary: right_end_boundary,
            ),
          ),
        )
        False -> #(left, right)
      }
    }
    _, _ -> #(left, right)
  }
}

fn source_segments_have_boundary_reversal(
  left: svg_path.Segment,
  right: svg_path.Segment,
  distance: Float,
) -> Bool {
  offset_curvature_zones_form_reversal_boundary(
    Some(offset_curvature_zone(left, distance, 1.0)),
    Some(offset_curvature_zone(right, distance, 0.0)),
  )
}

fn source_segment_offset_is_stalled(
  segment: svg_path.Segment,
  distance: Float,
  threshold: Float,
) -> Bool {
  case circular_arc_offset_radius(segment, distance) {
    Ok(radius) -> float.absolute_value(radius) <=. threshold
    Error(_) ->
      case
        offset_point(segment, t: 0.0, distance:),
        offset_point(segment, t: 0.5, distance:),
        offset_point(segment, t: 1.0, distance:)
      {
        Ok(start), Ok(mid), Ok(end) ->
          point_distance(start, mid) +. point_distance(mid, end) <=. threshold
        _, _, _ -> False
      }
  }
}

fn offset_classified_segments_with_zero_source(
  pieces: List(BClassifiedSegment),
  distance: Float,
  options: Options,
  portion_index portion_index: Int,
  closed closed: Bool,
  converted converted: List(FUnhealedOffsetSegment),
) -> Result(OffsetSegmentsBuild, Error) {
  use refined <- result.try(
    refine_b_classified_segments_for_offset(
      pieces,
      distance,
      options.stalled_offset_diameter,
      refined: [],
    ),
  )
  use offsets <- result.try(offset_d_offset_pieces(
    refined,
    distance,
    options,
    portion_index:,
    converted:,
  ))
  let offsets =
    mark_cross_source_reversal_boundaries(offsets, distance, closed:)
  use healed <- result.try(heal_offset_boundaries(
    offsets,
    distance,
    options,
    closed:,
  ))
  Ok(OffsetSegmentsBuild(
    offsets: healed,
    zero_source_segments: zero_source_segments_from_d_pieces(
      refined,
      healed,
      converted: [],
    ),
  ))
}

fn zero_source_segments_from_d_pieces(
  pieces: List(DOffsetPiece),
  offsets: List(GHealedOffsetSegment),
  converted converted: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case pieces {
    [] -> list.reverse(converted)
    [DStalled(first), ..rest] -> {
      let #(run, remaining_pieces) =
        collect_d_stalled_run(first, rest, collected: [])
      let remaining_offsets = case offsets {
        [GHealedOffsetSegment(source: OffsetFromStalledRun(source), ..), ..tail]
          if source == run
        -> tail
        _ -> offsets
      }
      let segments =
        list.map(run, fn(piece) {
          let CStalledSegment(segment:, ..) = piece
          segment
        })
      zero_source_segments_from_d_pieces(
        remaining_pieces,
        remaining_offsets,
        converted: list.append(list.reverse(segments), converted),
      )
    }
    [DNotStalled(first), ..rest] -> {
      let #(segments, remaining_offsets) =
        take_d_refined_zero_source_segments(offsets, first, taken: [])
      zero_source_segments_from_d_pieces(
        rest,
        remaining_offsets,
        converted: list.append(list.reverse(segments), converted),
      )
    }
  }
}

fn take_d_refined_zero_source_segments(
  offsets: List(GHealedOffsetSegment),
  refined: DRefinedSegment,
  taken taken: List(svg_path.Segment),
) -> #(List(svg_path.Segment), List(GHealedOffsetSegment)) {
  case offsets {
    [
      GHealedOffsetSegment(
        source: OffsetFromJoinFree(EJoinFreeSegment(
          refined: source_refined,
          segment:,
          ..,
        )),
        ..,
      ),
      ..rest
    ]
      if source_refined == refined
    ->
      take_d_refined_zero_source_segments(rest, refined, taken: [
        segment,
        ..taken
      ])
    _ -> #(list.reverse(taken), offsets)
  }
}

fn offset_d_offset_pieces(
  pieces: List(DOffsetPiece),
  distance: Float,
  options: Options,
  portion_index portion_index: Int,
  converted converted: List(FUnhealedOffsetSegment),
) -> Result(List(FUnhealedOffsetSegment), Error) {
  case pieces {
    [] -> Ok(list.reverse(converted))
    [DStalled(first), ..rest] -> {
      let #(run, rest) = collect_d_stalled_run(first, rest, collected: [])
      use offsets <- result.try(offset_c_stalled_run(run, distance:))
      offset_d_offset_pieces(
        rest,
        distance,
        options,
        portion_index:,
        converted: list.append(list.reverse(offsets), converted),
      )
    }
    [DNotStalled(first), ..rest] -> {
      use offsets <- result.try(
        offset_e_join_free_segments(
          join_free_segments([first], portion_index:),
          distance,
          options,
          converted: [],
        ),
      )
      offset_d_offset_pieces(
        rest,
        distance,
        options,
        portion_index:,
        converted: list.append(list.reverse(offsets), converted),
      )
    }
  }
}

fn refine_b_classified_segments_for_offset(
  pieces: List(BClassifiedSegment),
  distance: Float,
  stalled_threshold: Float,
  refined refined: List(DOffsetPiece),
) -> Result(List(DOffsetPiece), Error) {
  case pieces {
    [] -> {
      Ok(list.reverse(refined))
    }
    [BStalled(stalled), ..rest] ->
      refine_b_classified_segments_for_offset(
        rest,
        distance,
        stalled_threshold,
        refined: [DStalled(stalled), ..refined],
      )
    [BNotStalled(not_stalled), ..rest] -> {
      use next <- result.try(refine_c_not_stalled_segment_for_offset(
        not_stalled,
        distance,
        stalled_threshold,
      ))
      refine_b_classified_segments_for_offset(
        rest,
        distance,
        stalled_threshold,
        refined: list.append(list.reverse(next), refined),
      )
    }
  }
}

fn collect_d_stalled_run(
  first: CStalledSegment,
  rest: List(DOffsetPiece),
  collected collected: List(CStalledSegment),
) -> #(List(CStalledSegment), List(DOffsetPiece)) {
  case rest {
    [DStalled(stalled), ..remaining] ->
      collect_d_stalled_run(first, remaining, collected: [stalled, ..collected])
    _ -> #([first, ..list.reverse(collected)], rest)
  }
}

fn mark_cross_source_reversal_boundaries(
  offsets: List(FUnhealedOffsetSegment),
  distance: Float,
  closed closed: Bool,
) -> List(FUnhealedOffsetSegment) {
  let marked = mark_linear_cross_source_reversal_boundaries(offsets, distance)
  case closed, marked {
    True, [first, second, ..rest] -> {
      let assert Ok(last) = list.last([first, second, ..rest])
      let #(last, first) =
        mark_adjacent_cross_source_reversal_boundary(last, first, distance)
      [first, ..replace_last([second, ..rest], last, previous: [])]
    }
    _, _ -> marked
  }
}

fn mark_linear_cross_source_reversal_boundaries(
  offsets: List(FUnhealedOffsetSegment),
  distance: Float,
) -> List(FUnhealedOffsetSegment) {
  case offsets {
    [] | [_] -> offsets
    [first, second, ..rest] ->
      mark_linear_cross_source_reversal_boundaries_loop(
        first,
        [second, ..rest],
        distance,
        marked: [],
      )
  }
}

fn mark_linear_cross_source_reversal_boundaries_loop(
  previous: FUnhealedOffsetSegment,
  rest: List(FUnhealedOffsetSegment),
  distance: Float,
  marked marked: List(FUnhealedOffsetSegment),
) -> List(FUnhealedOffsetSegment) {
  case rest {
    [] -> list.reverse([previous, ..marked])
    [next, ..remaining] -> {
      let #(previous, next) =
        mark_adjacent_cross_source_reversal_boundary(previous, next, distance)
      mark_linear_cross_source_reversal_boundaries_loop(
        next,
        remaining,
        distance,
        marked: [previous, ..marked],
      )
    }
  }
}

fn mark_adjacent_cross_source_reversal_boundary(
  left: FUnhealedOffsetSegment,
  right: FUnhealedOffsetSegment,
  distance: Float,
) -> #(FUnhealedOffsetSegment, FUnhealedOffsetSegment) {
  case left.source, right.source {
    OffsetFromJoinFree(left_source), OffsetFromJoinFree(right_source) -> {
      case
        e_segments_have_cross_source_reversal_boundary(
          left_source,
          right_source,
          distance,
        )
      {
        True -> #(
          set_offset_segment_source_end_reversal(left),
          set_offset_segment_source_start_reversal(right),
        )
        False -> #(left, right)
      }
    }
    _, _ -> #(left, right)
  }
}

fn e_segments_have_cross_source_reversal_boundary(
  left: EJoinFreeSegment,
  right: EJoinFreeSegment,
  distance: Float,
) -> Bool {
  let EJoinFreeSegment(
    refined: DRefinedSegment(
      prepared: APreparedSegment(
        source_subpath_index: left_subpath,
        source_segment_index: left_index,
        ..,
      ),
      ..,
    ),
    ..,
  ) = left
  let EJoinFreeSegment(
    refined: DRefinedSegment(
      prepared: APreparedSegment(
        source_subpath_index: right_subpath,
        source_segment_index: right_index,
        ..,
      ),
      ..,
    ),
    ..,
  ) = right
  left_subpath == right_subpath
  && left_index != right_index
  && offset_curvature_zones_form_reversal_boundary(
    Some(refined_source_interval_zone(left, distance)),
    Some(refined_source_interval_zone(right, distance)),
  )
}

fn refined_source_interval_zone(
  source: EJoinFreeSegment,
  distance: Float,
) -> OffsetCurvatureZone {
  let EJoinFreeSegment(
    refined: DRefinedSegment(
      prepared: APreparedSegment(segment: prepared_segment, ..),
      prepared_from:,
      prepared_to:,
      ..,
    ),
    refined_from:,
    refined_to:,
    ..,
  ) = source
  let from = prepared_from +. { prepared_to -. prepared_from } *. refined_from
  let to = prepared_from +. { prepared_to -. prepared_from } *. refined_to
  offset_curvature_zone(prepared_segment, distance, { from +. to } /. 2.0)
}

fn set_offset_segment_source_start_reversal(
  offset: FUnhealedOffsetSegment,
) -> FUnhealedOffsetSegment {
  case offset.source {
    OffsetFromJoinFree(source) ->
      FUnhealedOffsetSegment(
        ..offset,
        source: OffsetFromJoinFree(set_join_free_segment_start_boundary(
          source,
          ReversalBoundary,
        )),
      )
    OffsetFromStalledRun(..) -> offset
  }
}

fn set_offset_segment_source_end_reversal(
  offset: FUnhealedOffsetSegment,
) -> FUnhealedOffsetSegment {
  case offset.source {
    OffsetFromJoinFree(source) ->
      FUnhealedOffsetSegment(
        ..offset,
        source: OffsetFromJoinFree(set_join_free_segment_end_boundary(
          source,
          ReversalBoundary,
        )),
      )
    OffsetFromStalledRun(..) -> offset
  }
}

fn set_join_free_segment_start_boundary(
  source: EJoinFreeSegment,
  boundary: BoundaryKind,
) -> EJoinFreeSegment {
  EJoinFreeSegment(..source, start_boundary: boundary)
}

fn set_join_free_segment_end_boundary(
  source: EJoinFreeSegment,
  boundary: BoundaryKind,
) -> EJoinFreeSegment {
  EJoinFreeSegment(..source, end_boundary: boundary)
}

fn replace_last(
  rest: List(FUnhealedOffsetSegment),
  last: FUnhealedOffsetSegment,
  previous previous: List(FUnhealedOffsetSegment),
) -> List(FUnhealedOffsetSegment) {
  case rest {
    [] -> list.reverse(previous)
    [_] -> list.reverse([last, ..previous])
    [first, ..remaining] ->
      replace_last(remaining, last, previous: [first, ..previous])
  }
}

fn refine_c_not_stalled_segment_at_boundaries(
  source: CNotStalledSegment,
  distance distance: Float,
) -> Result(List(DRefinedSegment), Error) {
  let CNotStalledSegment(prepared:, start_boundary:, end_boundary:) = source
  let APreparedSegment(segment:, ..) = prepared
  use reversal_parameters <- result.try(offset_reversal_parameters(
    segment,
    distance,
  ))
  let reversal_parameters =
    reversal_parameters
    |> list.filter(fn(t) { t >. point_tolerance && t <. 1.0 -. point_tolerance })
    |> list.map(fn(t) { CurvatureSplitParameter(t, CuspSplit) })
  use inflection_parameters <- result.try(offset_inflection_parameters(segment))
  let inflection_parameters =
    inflection_parameters
    |> list.filter(fn(t) { t >. point_tolerance && t <. 1.0 -. point_tolerance })
    |> list.map(fn(t) { CurvatureSplitParameter(t, InflectionSplit) })

  let parameters =
    [
      CurvatureSplitParameter(0.0, OrdinarySplit),
      CurvatureSplitParameter(1.0, OrdinarySplit),
    ]
    |> list.append(reversal_parameters)
    |> list.append(inflection_parameters)
    |> list.sort(by: fn(a, b) {
      let CurvatureSplitParameter(t: left, ..) = a
      let CurvatureSplitParameter(t: right, ..) = b
      float.compare(left, right)
    })
    |> unique_curvature_split_parameters(curvature_parameter_tolerance, [])
    |> classify_curvature_boundaries(segment, distance)
    |> apply_endpoint_boundary_overrides(start_boundary:, end_boundary:)
  use pieces <- result.try(split_c_not_stalled_segment_into_d_refined_segments(
    prepared:,
    parameters:,
  ))
  split_bezier_double_radius_reversal_d_segments(pieces, distance, refined: [])
}

fn refine_c_not_stalled_segment_for_offset(
  source: CNotStalledSegment,
  distance: Float,
  stalled_threshold: Float,
) -> Result(List(DOffsetPiece), Error) {
  use refined <- result.try(refine_c_not_stalled_segment_at_boundaries(
    source,
    distance:,
  ))
  use start_adjusted <- result.try(late_stall_near_start(
    refined,
    distance,
    stalled_threshold,
  ))
  late_stall_near_end(start_adjusted, distance, stalled_threshold)
}

fn late_stall_near_start(
  pieces: List(DRefinedSegment),
  distance: Float,
  stalled_threshold: Float,
) -> Result(List(DOffsetPiece), Error) {
  case pieces {
    [first, second, ..rest] -> {
      let DRefinedSegment(
        prepared:,
        prepared_from: first_from,
        prepared_to: root_t,
        end_boundary:,
        ..,
      ) = first
      let DRefinedSegment(
        prepared: second_prepared,
        prepared_from: second_from,
        prepared_to: second_to,
        end_boundary: second_end_boundary,
        ..,
      ) = second
      let expanded_to = root_t *. 2.0
      case
        prepared == second_prepared
        && first_from == 0.0
        && boundary_is_reversal(end_boundary)
        && second_from == root_t
        && expanded_to <. second_to -. point_tolerance
      {
        False -> Ok(list.map(pieces, DNotStalled))
        True -> {
          use stalled_segment <- result.try(prepared_segment_between(
            prepared,
            0.0,
            expanded_to,
          ))
          case
            source_segment_offset_is_stalled(
              stalled_segment,
              distance,
              stalled_threshold,
            )
          {
            False -> Ok(list.map(pieces, DNotStalled))
            True -> {
              use remainder <- result.try(prepared_segment_between(
                prepared,
                expanded_to,
                second_to,
              ))
              Ok([
                DStalled(CStalledSegment(
                  prepared:,
                  prepared_from: 0.0,
                  prepared_to: expanded_to,
                  segment: stalled_segment,
                )),
                DNotStalled(DRefinedSegment(
                  prepared:,
                  prepared_from: expanded_to,
                  prepared_to: second_to,
                  segment: remainder,
                  start_boundary: Ordinary,
                  end_boundary: second_end_boundary,
                )),
                ..list.map(rest, DNotStalled)
              ])
            }
          }
        }
      }
    }
    _ -> Ok(list.map(pieces, DNotStalled))
  }
}

fn late_stall_near_end(
  pieces: List(DOffsetPiece),
  distance: Float,
  stalled_threshold: Float,
) -> Result(List(DOffsetPiece), Error) {
  let reversed = list.reverse(pieces)
  case reversed {
    [DNotStalled(last), DNotStalled(previous), ..rest] -> {
      let DRefinedSegment(
        prepared:,
        prepared_from: root_t,
        prepared_to: last_to,
        start_boundary:,
        ..,
      ) = last
      let DRefinedSegment(
        prepared: previous_prepared,
        prepared_from: previous_from,
        prepared_to: previous_to,
        start_boundary: previous_start_boundary,
        ..,
      ) = previous
      let expanded_from = root_t *. 2.0 -. 1.0
      case
        prepared == previous_prepared
        && last_to == 1.0
        && boundary_is_reversal(start_boundary)
        && previous_to == root_t
        && expanded_from >. previous_from +. point_tolerance
      {
        False -> Ok(pieces)
        True -> {
          use stalled_segment <- result.try(prepared_segment_between(
            prepared,
            expanded_from,
            1.0,
          ))
          case
            source_segment_offset_is_stalled(
              stalled_segment,
              distance,
              stalled_threshold,
            )
          {
            False -> Ok(pieces)
            True -> {
              use remainder <- result.try(prepared_segment_between(
                prepared,
                previous_from,
                expanded_from,
              ))
              Ok(
                list.reverse([
                  DStalled(CStalledSegment(
                    prepared:,
                    prepared_from: expanded_from,
                    prepared_to: 1.0,
                    segment: stalled_segment,
                  )),
                  DNotStalled(DRefinedSegment(
                    prepared:,
                    prepared_from: previous_from,
                    prepared_to: expanded_from,
                    segment: remainder,
                    start_boundary: previous_start_boundary,
                    end_boundary: Ordinary,
                  )),
                  ..rest
                ]),
              )
            }
          }
        }
      }
    }
    _ -> Ok(pieces)
  }
}

fn prepared_segment_between(
  prepared: APreparedSegment,
  from: Float,
  to: Float,
) -> Result(svg_path.Segment, Error) {
  let APreparedSegment(segment:, ..) = prepared
  use segments <- result.try(
    svg_path.segment_between_many_inside(segment, between: [from, to])
    |> result.map_error(PathError),
  )
  case segments {
    [between] -> Ok(between)
    _ -> Error(NonFinite)
  }
}

fn split_bezier_double_radius_reversal_d_segments(
  pieces: List(DRefinedSegment),
  distance: Float,
  refined refined: List(DRefinedSegment),
) -> Result(List(DRefinedSegment), Error) {
  case pieces {
    [] -> Ok(list.reverse(refined))
    [first, ..rest] -> {
      let DRefinedSegment(segment:, start_boundary:, end_boundary:, ..) = first
      case
        boundary_is_reversal(start_boundary)
        && boundary_is_reversal(end_boundary)
        && d_refined_endpoint_reaches_offset_radius(
          first,
          distance,
          SegmentStart,
        )
        && d_refined_endpoint_reaches_offset_radius(first, distance, SegmentEnd)
        && segment_is_bezier(segment)
      {
        True -> {
          use split <- result.try(split_d_refined_segment_at_midpoint(first))
          let #(left, right) = split
          split_bezier_double_radius_reversal_d_segments(
            rest,
            distance,
            refined: [right, left, ..refined],
          )
        }
        False ->
          split_bezier_double_radius_reversal_d_segments(
            rest,
            distance,
            refined: [first, ..refined],
          )
      }
    }
  }
}

fn join_free_segments(
  refined: List(DRefinedSegment),
  portion_index portion_index: Int,
) -> List(EJoinFreeSegment) {
  join_free_segments_loop(
    refined,
    portion_index,
    segment_index: 0,
    converted: [],
  )
}

fn join_free_segments_loop(
  refined: List(DRefinedSegment),
  portion_index: Int,
  segment_index segment_index: Int,
  converted converted: List(EJoinFreeSegment),
) -> List(EJoinFreeSegment) {
  case refined {
    [] -> list.reverse(converted)
    [first, ..rest] -> {
      let DRefinedSegment(segment:, start_boundary:, end_boundary:, ..) = first
      join_free_segments_loop(
        rest,
        portion_index,
        segment_index: segment_index + 1,
        converted: [
          EJoinFreeSegment(
            portion_index:,
            segment_index:,
            generation: 0,
            refined: first,
            refined_from: 0.0,
            refined_to: 1.0,
            segment:,
            start_boundary:,
            end_boundary:,
          ),
          ..converted
        ],
      )
    }
  }
}

fn segment_is_bezier(segment: svg_path.Segment) -> Bool {
  case segment {
    svg_path.QuadraticBezier(..) | svg_path.CubicBezier(..) -> True
    svg_path.Line(..) | svg_path.Arc(..) -> False
  }
}

fn split_c_not_stalled_segment_into_d_refined_segments(
  prepared prepared: APreparedSegment,
  parameters parameters: List(CurvatureBoundary),
) -> Result(List(DRefinedSegment), Error) {
  let APreparedSegment(segment: source_segment, ..) = prepared
  case parameters {
    [] | [_] -> Ok([])
    [from, to, ..rest] -> {
      let CurvatureBoundary(t: from_t, boundary: from_boundary) = from
      let CurvatureBoundary(t: to_t, boundary: to_boundary) = to
      use pieces <- result.try(
        split_c_not_stalled_segment_into_d_refined_segments(
          prepared:,
          parameters: [to, ..rest],
        ),
      )
      case to_t -. from_t <=. point_tolerance {
        True -> Ok(pieces)
        False -> {
          use segments <- result.try(
            svg_path.segment_between_many_inside(source_segment, between: [
              from_t,
              to_t,
            ])
            |> result.map_error(PathError),
          )
          let refined =
            list.map(segments, fn(segment) {
              DRefinedSegment(
                prepared:,
                prepared_from: from_t,
                prepared_to: to_t,
                segment:,
                start_boundary: from_boundary,
                end_boundary: to_boundary,
              )
            })
          Ok(list.append(refined, pieces))
        }
      }
    }
  }
}

fn unique_curvature_split_parameters(
  values: List(CurvatureSplitParameter),
  tolerance: Float,
  unique unique: List(CurvatureSplitParameter),
) -> List(CurvatureSplitParameter) {
  case values {
    [] -> list.reverse(unique)
    [first, ..rest] -> {
      let CurvatureSplitParameter(t: first_t, kind: first_kind) = first
      case unique {
        [previous, ..previous_rest] -> {
          let CurvatureSplitParameter(t: previous_t, kind: previous_kind) =
            previous
          case float.absolute_value(first_t -. previous_t) <=. tolerance {
            True ->
              unique_curvature_split_parameters(rest, tolerance, unique: [
                CurvatureSplitParameter(
                  previous_t,
                  merge_curvature_split_kind(previous_kind, first_kind),
                ),
                ..previous_rest
              ])
            False ->
              unique_curvature_split_parameters(rest, tolerance, unique: [
                first,
                ..unique
              ])
          }
        }
        [] ->
          unique_curvature_split_parameters(rest, tolerance, unique: [first])
      }
    }
  }
}

fn merge_curvature_split_kind(
  left: CurvatureSplitKind,
  right: CurvatureSplitKind,
) -> CurvatureSplitKind {
  case left, right {
    InflectionSplit, _ | _, InflectionSplit -> InflectionSplit
    CuspSplit, _ | _, CuspSplit -> CuspSplit
    _, _ -> OrdinarySplit
  }
}

fn classify_curvature_boundaries(
  parameters: List(CurvatureSplitParameter),
  segment: svg_path.Segment,
  distance: Float,
) -> List(CurvatureBoundary) {
  let zones = curvature_interval_zones(parameters, segment, distance, zones: [])
  classify_curvature_boundaries_loop(
    parameters,
    zones,
    previous_zone: None,
    boundaries: [],
  )
}

fn curvature_interval_zones(
  parameters: List(CurvatureSplitParameter),
  segment: svg_path.Segment,
  distance: Float,
  zones zones: List(OffsetCurvatureZone),
) -> List(OffsetCurvatureZone) {
  case parameters {
    [] | [_] -> list.reverse(zones)
    [from, to, ..rest] -> {
      let CurvatureSplitParameter(t: from_t, ..) = from
      let CurvatureSplitParameter(t: to_t, ..) = to
      let midpoint = { from_t +. to_t } /. 2.0
      curvature_interval_zones([to, ..rest], segment, distance, zones: [
        offset_curvature_zone(segment, distance, midpoint),
        ..zones
      ])
    }
  }
}

fn classify_curvature_boundaries_loop(
  parameters: List(CurvatureSplitParameter),
  zones: List(OffsetCurvatureZone),
  previous_zone previous_zone: Option(OffsetCurvatureZone),
  boundaries boundaries: List(CurvatureBoundary),
) -> List(CurvatureBoundary) {
  case parameters {
    [] -> list.reverse(boundaries)
    [first, ..rest] -> {
      let CurvatureSplitParameter(t:, kind:) = first
      let next_zone = case zones {
        [zone, ..] -> Some(zone)
        [] -> None
      }
      let behavior = curvature_boundary_behavior(kind, previous_zone, next_zone)
      classify_curvature_boundaries_loop(
        rest,
        case zones {
          [_, ..remaining] -> remaining
          [] -> []
        },
        previous_zone: next_zone,
        boundaries: [CurvatureBoundary(t:, boundary: behavior), ..boundaries],
      )
    }
  }
}

fn curvature_boundary_behavior(
  kind: CurvatureSplitKind,
  previous_zone: Option(OffsetCurvatureZone),
  next_zone: Option(OffsetCurvatureZone),
) -> BoundaryKind {
  case kind {
    InflectionSplit -> Inflection
    CuspSplit ->
      case
        offset_curvature_zones_form_reversal_boundary(previous_zone, next_zone)
      {
        True -> ReversalBoundary
        False -> NonReversalBoundaryTouch
      }
    OrdinarySplit ->
      case
        offset_curvature_zones_form_reversal_boundary(previous_zone, next_zone)
      {
        True -> ReversalBoundary
        False -> Ordinary
      }
  }
}

fn offset_curvature_zone(
  segment: svg_path.Segment,
  distance: Float,
  t: Float,
) -> OffsetCurvatureZone {
  case curvature.segment_right_normal_radius(segment, at: t) {
    Ok(radius) -> offset_curvature_radius_zone(radius, distance)
    Error(_) ->
      case curvature.segment_right_normal_curvature(segment, at: t) {
        Ok(value) if value >. curvature_parameter_tolerance -> Opposite
        Ok(value) if value <. 0.0 -. curvature_parameter_tolerance -> Opposite
        Ok(_) -> OutsideOffsetRadius
        Error(_) -> UnknownCurvatureZone
      }
  }
}

fn offset_curvature_radius_zone(radius: Float, distance: Float) {
  let tolerance = curvature_parameter_tolerance
  case distance >=. 0.0 {
    True ->
      case radius <. 0.0 -. tolerance {
        True -> Opposite
        False ->
          case radius <. distance -. tolerance {
            True -> InsideOffsetRadius
            False -> OutsideOffsetRadius
          }
      }
    False ->
      case radius >. tolerance {
        True -> Opposite
        False ->
          case radius >. distance +. tolerance {
            True -> InsideOffsetRadius
            False -> OutsideOffsetRadius
          }
      }
  }
}

fn offset_curvature_zones_form_reversal_boundary(
  previous: Option(OffsetCurvatureZone),
  next: Option(OffsetCurvatureZone),
) -> Bool {
  case previous, next {
    Some(InsideOffsetRadius), Some(OutsideOffsetRadius)
    | Some(InsideOffsetRadius), Some(Opposite)
    | Some(OutsideOffsetRadius), Some(InsideOffsetRadius)
    | Some(Opposite), Some(InsideOffsetRadius)
    -> True
    _, _ -> False
  }
}

fn boundary_is_reversal(boundary: BoundaryKind) -> Bool {
  case boundary {
    ReversalBoundary -> True
    _ -> False
  }
}

fn apply_endpoint_boundary_overrides(
  boundaries: List(CurvatureBoundary),
  start_boundary start_boundary: BoundaryKind,
  end_boundary end_boundary: BoundaryKind,
) -> List(CurvatureBoundary) {
  boundaries
  |> apply_start_boundary_override(start_boundary)
  |> apply_end_boundary_override(end_boundary)
}

fn apply_start_boundary_override(
  boundaries: List(CurvatureBoundary),
  override: BoundaryKind,
) -> List(CurvatureBoundary) {
  case override, boundaries {
    Ordinary, _ -> boundaries
    _, [first, ..rest] -> {
      let CurvatureBoundary(t:, ..) = first
      [CurvatureBoundary(t:, boundary: override), ..rest]
    }
    _, _ -> boundaries
  }
}

fn apply_end_boundary_override(
  boundaries: List(CurvatureBoundary),
  override: BoundaryKind,
) -> List(CurvatureBoundary) {
  case override, boundaries {
    Ordinary, _ -> boundaries
    _, [_, ..] ->
      replace_last_curvature_boundary(boundaries, override, previous: [])
    _, _ -> boundaries
  }
}

fn replace_last_curvature_boundary(
  boundaries: List(CurvatureBoundary),
  boundary: BoundaryKind,
  previous previous: List(CurvatureBoundary),
) -> List(CurvatureBoundary) {
  case boundaries {
    [] -> list.reverse(previous)
    [last] -> {
      let CurvatureBoundary(t:, ..) = last
      list.reverse([CurvatureBoundary(t:, boundary:), ..previous])
    }
    [first, ..rest] ->
      replace_last_curvature_boundary(rest, boundary, previous: [
        first,
        ..previous
      ])
  }
}

fn offset_e_join_free_segments(
  pieces: List(EJoinFreeSegment),
  distance: Float,
  options: Options,
  converted converted: List(FUnhealedOffsetSegment),
) -> Result(List(FUnhealedOffsetSegment), Error) {
  case pieces {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use offsets <- result.try(offset_e_join_free_segment(
        first,
        distance,
        options,
      ))
      offset_e_join_free_segments(
        rest,
        distance,
        options,
        converted: list.append(list.reverse(offsets), converted),
      )
    }
  }
}

fn offset_e_join_free_segment(
  source: EJoinFreeSegment,
  distance: Float,
  options: Options,
) -> Result(List(FUnhealedOffsetSegment), Error) {
  let EJoinFreeSegment(segment:, ..) = source
  case segment {
    svg_path.Line(..) -> {
      use offset_start <- result.try(offset_point(segment, t: 0.0, distance:))
      use offset_end <- result.try(offset_point(segment, t: 1.0, distance:))
      use offset <- result.try(build_offset_segment(
        distance: distance,
        source: OffsetFromJoinFree(source),
        segment: svg_path.Line(start: offset_start, end: offset_end),
      ))
      Ok([offset])
    }
    svg_path.Arc(..) -> {
      case circular_arc_offset_radius(segment, distance) {
        Ok(radius) -> {
          case float.absolute_value(radius) <=. point_tolerance {
            True -> Error(DegenerateTangent(0.0))
            False -> {
              use arc <- result.try(offset_circular_arc_segment_raw(
                segment,
                distance,
                radius,
              ))
              use offset <- result.try(build_exact_arc_offset_segment(
                arc,
                source: OffsetFromJoinFree(source),
              ))
              Ok([offset])
            }
          }
        }
        Error(_) ->
          recursive_offset_e_join_free_segment(
            source,
            distance,
            options,
            depth: options.fitting.max_depth,
          )
      }
    }
    _ ->
      recursive_offset_e_join_free_segment(
        source,
        distance,
        options,
        depth: options.fitting.max_depth,
      )
  }
}

fn recursive_offset_e_join_free_segment(
  source: EJoinFreeSegment,
  distance: Float,
  options: Options,
  depth depth: Int,
) -> Result(List(FUnhealedOffsetSegment), Error) {
  let EJoinFreeSegment(segment:, ..) = source
  use candidate <- result.try(fit_e_join_free_offset_segment(source, distance))
  use divergence <- result.try(smart_offset_divergence(
    segment,
    candidate,
    distance,
    options,
  ))
  case divergence <=. raw_fitting_tolerance(options) {
    True -> {
      use offset <- result.try(build_offset_segment(
        distance: distance,
        source: OffsetFromJoinFree(source),
        segment: candidate,
      ))
      Ok([offset])
    }
    False ->
      case depth <= 0 {
        True -> Error(MaxDepthReached(divergence))
        False -> {
          use split <- result.try(split_e_join_free_segment_at_midpoint(source))
          let #(left, right) = split
          use left_offset <- result.try(recursive_offset_e_join_free_segment(
            left,
            distance,
            options,
            depth: depth - 1,
          ))
          use right_offset <- result.try(recursive_offset_e_join_free_segment(
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

fn split_e_join_free_segment_at_midpoint(
  source: EJoinFreeSegment,
) -> Result(#(EJoinFreeSegment, EJoinFreeSegment), Error) {
  let EJoinFreeSegment(refined_from:, refined_to:, segment:, generation:, ..) =
    source
  use split <- result.try(
    svg_path.segment_split(segment, at: 0.5)
    |> result.map_error(PathError),
  )
  let #(left, right) = split
  let source_mid = refined_from +. { refined_to -. refined_from } /. 2.0
  Ok(#(
    EJoinFreeSegment(
      ..source,
      generation: generation + 1,
      refined_to: source_mid,
      segment: left,
      end_boundary: Ordinary,
    ),
    EJoinFreeSegment(
      ..source,
      generation: generation + 1,
      refined_from: source_mid,
      segment: right,
      start_boundary: Ordinary,
    ),
  ))
}

fn split_d_refined_segment_at_midpoint(
  source: DRefinedSegment,
) -> Result(#(DRefinedSegment, DRefinedSegment), Error) {
  let DRefinedSegment(prepared_from:, prepared_to:, segment:, ..) = source
  use split <- result.try(
    svg_path.segment_split(segment, at: 0.5)
    |> result.map_error(PathError),
  )
  let #(left, right) = split
  let source_mid = prepared_from +. { prepared_to -. prepared_from } /. 2.0
  Ok(#(
    DRefinedSegment(
      ..source,
      prepared_to: source_mid,
      segment: left,
      end_boundary: Ordinary,
    ),
    DRefinedSegment(
      ..source,
      prepared_from: source_mid,
      segment: right,
      start_boundary: Ordinary,
    ),
  ))
}

fn offset_reversal_parameters(
  segment: svg_path.Segment,
  distance: Float,
) -> Result(List(Float), Error) {
  curvature.segment_right_normal_cusp_parameters(
    segment,
    distance:,
    options: curvature.default_options(),
  )
  |> result.map_error(fn(_) { NonFinite })
}

fn offset_inflection_parameters(
  segment: svg_path.Segment,
) -> Result(List(Float), Error) {
  let options =
    curvature.Options(
      tolerance: curvature_parameter_tolerance,
      samples: 100,
      max_depth: 32,
    )
  curvature.segment_inflection_parameters(segment, options:)
  |> result.map_error(fn(_) { NonFinite })
}

fn offset_c_stalled_run(
  run: List(CStalledSegment),
  distance distance: Float,
) -> Result(List(FUnhealedOffsetSegment), Error) {
  let segments =
    list.map(run, fn(segment) {
      let CStalledSegment(segment:, ..) = segment
      segment
    })
  case segments {
    [] -> Ok([])
    [first, ..rest] -> {
      let assert Ok(last) = list.last([first, ..rest])
      use start <- result.try(offset_point(first, t: 0.0, distance:))
      use end <- result.try(offset_point(last, t: 1.0, distance:))
      use samples <- result.try(
        stalled_run_offset_samples(
          [first, ..rest],
          distance,
          index: 0,
          count: list.length([first, ..rest]),
          samples: [],
        ),
      )
      case stalled_run_collapsed(start, end, samples) {
        True -> Ok([])
        False -> {
          case rest, circular_arc_offset_radius(first, distance) {
            [], Ok(radius) -> {
              use arc <- result.try(offset_circular_arc_segment_raw(
                first,
                distance,
                radius,
              ))
              use offset <- result.try(build_exact_arc_offset_segment(
                arc,
                source: OffsetFromStalledRun(run),
              ))
              Ok([offset])
            }
            _, _ ->
              offset_nonempty_stalled_source_run(
                first,
                last,
                run,
                start,
                end,
                samples,
              )
          }
        }
      }
    }
  }
}

fn stalled_run_collapsed(
  start: svg_path.Point,
  end: svg_path.Point,
  _samples: List(#(Float, bezier.BezierPoint)),
) -> Bool {
  start == end
}

fn offset_nonempty_stalled_source_run(
  first: svg_path.Segment,
  last: svg_path.Segment,
  run: List(CStalledSegment),
  start: svg_path.Point,
  end: svg_path.Point,
  samples: List(#(Float, bezier.BezierPoint)),
) -> Result(List(FUnhealedOffsetSegment), Error) {
  use source_start_tangent <- result.try(unit_tangent(first, t: 0.0))
  use source_end_tangent <- result.try(unit_tangent(last, t: 1.0))
  use curve <- result.try(
    bezier.fit_cubic_with_endpoint_tangents(
      start: to_bezier_point(start),
      end: to_bezier_point(end),
      start_tangent: to_bezier_point(source_start_tangent),
      end_tangent: to_bezier_point(source_end_tangent),
      samples:,
    )
    |> result.map_error(cubic_fit_error)
    |> result.map(fn(fit) {
      let #(curve, _) = fit
      curve
    }),
  )
  use segment <- result.try(fitted_curve_to_segment(curve))
  case segment_is_finite(segment) {
    False -> Error(NonFinite)
    True -> {
      use start_tangent <- result.try(unit_tangent(segment, t: 0.0))
      use end_tangent <- result.try(unit_tangent(segment, t: 1.0))
      Ok([
        make_offset_segment(
          segment:,
          source: OffsetFromStalledRun(run),
          nudged_start_tangent_direction: start_tangent,
          nudged_end_tangent_direction: end_tangent,
        ),
      ])
    }
  }
}

fn stalled_run_offset_samples(
  segments: List(svg_path.Segment),
  distance: Float,
  index index: Int,
  count count: Int,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(List(#(Float, bezier.BezierPoint)), Error) {
  case segments {
    [] -> Ok(list.reverse(samples))
    [first, ..rest] -> {
      use samples <- result.try(stalled_segment_offset_samples(
        first,
        distance,
        index,
        count,
        [0.25, 0.5, 0.75],
        samples:,
      ))
      stalled_run_offset_samples(
        rest,
        distance,
        index: index + 1,
        count:,
        samples:,
      )
    }
  }
}

fn stalled_segment_offset_samples(
  segment: svg_path.Segment,
  distance: Float,
  index: Int,
  count: Int,
  t_values: List(Float),
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(List(#(Float, bezier.BezierPoint)), Error) {
  case t_values {
    [] -> Ok(samples)
    [local_t, ..rest] -> {
      use point <- result.try(offset_point(segment, t: local_t, distance:))
      let t = { int.to_float(index) +. local_t } /. int.to_float(count)
      stalled_segment_offset_samples(
        segment,
        distance,
        index,
        count,
        rest,
        samples: [#(t, to_bezier_point(point)), ..samples],
      )
    }
  }
}

fn assert_smooth_offset_postconditions(
  offsets: List(FUnhealedOffsetSegment),
  heal_angle: Float,
) -> Result(Nil, Error) {
  case offsets {
    [] | [_] -> Ok(Nil)
    [first, second, ..rest] -> {
      use _ <- result.try(assert_smooth_offset_boundary(
        first,
        second,
        heal_angle,
      ))
      assert_smooth_offset_postconditions([second, ..rest], heal_angle)
    }
  }
}

fn assert_smooth_offset_boundary(
  left: FUnhealedOffsetSegment,
  right: FUnhealedOffsetSegment,
  heal_angle: Float,
) -> Result(Nil, Error) {
  case
    svg_path.segment_end(left.segment) == svg_path.segment_start(right.segment)
  {
    False -> Error(NonFinite)
    True ->
      case
        offset_segment_source_end(left.source)
        == offset_segment_source_start(right.source)
      {
        False -> Ok(Nil)
        True ->
          case offset_boundary_is_known_reversal(left, right) {
            True -> Ok(Nil)
            False ->
              assert_continuous_offset_tangent_boundary(
                left.segment,
                right.segment,
                heal_angle,
              )
          }
      }
  }
}

fn assert_continuous_offset_tangent_boundary(
  left: svg_path.Segment,
  right: svg_path.Segment,
  heal_angle: Float,
) -> Result(Nil, Error) {
  use left_diameter <- result.try(segment_diameter(left))
  use right_diameter <- result.try(segment_diameter(right))
  case
    left_diameter >=. stable_tangent_assertion_diameter
    && right_diameter >=. stable_tangent_assertion_diameter
  {
    False -> Ok(Nil)
    True -> {
      use left_tangent <- result.try(unit_tangent(left, t: 1.0))
      use right_tangent <- result.try(unit_tangent(right, t: 0.0))
      let angle =
        float.absolute_value(signed_angle(left_tangent, right_tangent))
      case angle <=. heal_angle || { 180.0 -. angle } <=. heal_angle {
        True -> Ok(Nil)
        False -> Error(DegenerateTangent(1.0))
      }
    }
  }
}

fn segment_diameter(segment: svg_path.Segment) -> Result(Float, Error) {
  use box <- result.try(
    svg_path.segment_bounding_box(segment) |> result.map_error(PathError),
  )
  Ok(svg_path.bounding_box_diameter(box))
}

fn split_join_free_portions(
  segments: List(svg_path.Segment),
  options: Options,
  current current: List(svg_path.Segment),
  portions portions: List(JoinFreePortion),
) -> Result(List(JoinFreePortion), Error) {
  case segments {
    [] -> {
      use portions <- result.try(prepend_join_free_portion(
        current,
        closed: False,
        to: portions,
      ))
      Ok(list.reverse(portions))
    }
    [first, ..rest] ->
      case current {
        [] ->
          split_join_free_portions(rest, options, current: [first], portions:)
        [previous, ..] -> {
          case source_boundary_is_smooth(previous, first, options) {
            True ->
              split_join_free_portions(
                rest,
                options,
                current: [first, ..current],
                portions:,
              )
            False -> {
              use portions <- result.try(prepend_join_free_portion(
                current,
                closed: False,
                to: portions,
              ))
              split_join_free_portions(
                rest,
                options,
                current: [first],
                portions:,
              )
            }
          }
        }
      }
  }
}

fn prepend_join_free_portion(
  segments: List(svg_path.Segment),
  closed closed: Bool,
  to portions: List(JoinFreePortion),
) -> Result(List(JoinFreePortion), Error) {
  case segments {
    [] -> Ok(portions)
    _ -> {
      use open_subpath <- result.try(
        svg_path.subpath_with(list.reverse(segments), policy: svg_path.Strict)
        |> result.map_error(PathError),
      )
      use subpath <- result.try(
        svg_path.subpath_set_closed_with(
          open_subpath,
          closed:,
          policy: svg_path.Strict,
        )
        |> result.map_error(PathError),
      )
      Ok([JoinFreePortion(index: 0, subpath:, closed:), ..portions])
    }
  }
}

fn mark_closed_join_free_portion(
  portions: List(JoinFreePortion),
  closed closed: Bool,
) -> List(JoinFreePortion) {
  case closed, portions {
    True, [JoinFreePortion(index:, subpath:, ..)] -> [
      JoinFreePortion(index:, subpath:, closed: True),
    ]
    _, _ -> portions
  }
}

fn index_join_free_portions(
  portions: List(JoinFreePortion),
  index index: Int,
  indexed indexed: List(JoinFreePortion),
) -> List(JoinFreePortion) {
  case portions {
    [] -> list.reverse(indexed)
    [first, ..rest] -> {
      let JoinFreePortion(subpath:, closed:, ..) = first
      index_join_free_portions(rest, index: index + 1, indexed: [
        JoinFreePortion(index:, subpath:, closed:),
        ..indexed
      ])
    }
  }
}

fn source_boundary_is_smooth(
  left: svg_path.Segment,
  right: svg_path.Segment,
  _options: Options,
) -> Bool {
  case unit_tangent(left, t: 1.0), unit_tangent(right, t: 0.0) {
    Ok(left_tangent), Ok(right_tangent) -> {
      let angle =
        float.absolute_value(signed_angle(left_tangent, right_tangent))
      angle <=. join_free_tangent_alignment_angle_degrees
    }
    _, _ -> False
  }
}

fn heal_offset_boundaries(
  offsets: List(FUnhealedOffsetSegment),
  distance: Float,
  options: Options,
  closed closed: Bool,
) -> Result(List(GHealedOffsetSegment), Error) {
  use healed <- result.try(heal_adjacent_offset_boundaries(
    offsets,
    distance,
    options,
  ))
  use healed <- result.try(case closed {
    False -> Ok(healed)
    True -> heal_wrapping_offset_boundary(healed, distance, options)
  })
  Ok(list.map(healed, f_unhealed_to_g_healed_offset_segment))
}

fn f_unhealed_to_g_healed_offset_segment(
  offset: FUnhealedOffsetSegment,
) -> GHealedOffsetSegment {
  GHealedOffsetSegment(
    segment: offset.segment,
    source: offset.source,
    nudged_start_tangent_direction: offset.nudged_start_tangent_direction,
    nudged_end_tangent_direction: offset.nudged_end_tangent_direction,
  )
}

fn g_healed_to_f_unhealed_offset_segment(
  offset: GHealedOffsetSegment,
) -> FUnhealedOffsetSegment {
  FUnhealedOffsetSegment(
    segment: offset.segment,
    source: offset.source,
    nudged_start_tangent_direction: offset.nudged_start_tangent_direction,
    nudged_end_tangent_direction: offset.nudged_end_tangent_direction,
  )
}

fn g_healed_to_f_unhealed_offset_segments(
  offsets: List(GHealedOffsetSegment),
) -> List(FUnhealedOffsetSegment) {
  list.map(offsets, g_healed_to_f_unhealed_offset_segment)
}

fn heal_adjacent_offset_boundaries(
  offsets: List(FUnhealedOffsetSegment),
  distance: Float,
  options: Options,
) -> Result(List(FUnhealedOffsetSegment), Error) {
  case offsets {
    [] | [_] -> Ok(offsets)
    [first, second, ..rest] -> {
      use #(first, second) <- result.try(heal_offset_boundary(
        first,
        second,
        distance,
        options,
      ))
      heal_adjacent_offset_boundaries_loop(
        second,
        rest,
        distance,
        options,
        healed: [
          first,
        ],
      )
    }
  }
}

fn heal_adjacent_offset_boundaries_loop(
  previous: FUnhealedOffsetSegment,
  rest: List(FUnhealedOffsetSegment),
  distance: Float,
  options: Options,
  healed healed: List(FUnhealedOffsetSegment),
) -> Result(List(FUnhealedOffsetSegment), Error) {
  case rest {
    [] -> Ok(list.reverse([previous, ..healed]))
    [next, ..remaining] -> {
      use #(previous, next) <- result.try(heal_offset_boundary(
        previous,
        next,
        distance,
        options,
      ))
      heal_adjacent_offset_boundaries_loop(
        next,
        remaining,
        distance,
        options,
        healed: [previous, ..healed],
      )
    }
  }
}

fn heal_wrapping_offset_boundary(
  offsets: List(FUnhealedOffsetSegment),
  distance: Float,
  options: Options,
) -> Result(List(FUnhealedOffsetSegment), Error) {
  case offsets {
    [] | [_] -> Ok(offsets)
    [first, ..rest] -> {
      use last <- result.try(last_list_item(rest))
      use #(last, first) <- result.try(heal_offset_boundary(
        last,
        first,
        distance,
        options,
      ))
      Ok([first, ..replace_last_offset(rest, last)])
    }
  }
}

fn heal_offset_boundary(
  left: FUnhealedOffsetSegment,
  right: FUnhealedOffsetSegment,
  distance: Float,
  options: Options,
) -> Result(#(FUnhealedOffsetSegment, FUnhealedOffsetSegment), Error) {
  case heal_reversal_offset_boundary(left, right, distance, options) {
    Ok(healed) -> Ok(healed)
    Error(_) -> heal_smooth_offset_boundary(left, right, distance, options)
  }
}

fn heal_smooth_offset_boundary(
  left: FUnhealedOffsetSegment,
  right: FUnhealedOffsetSegment,
  distance: Float,
  options: Options,
) -> Result(#(FUnhealedOffsetSegment, FUnhealedOffsetSegment), Error) {
  let boundary =
    interpolate(
      svg_path.segment_end(left.segment),
      svg_path.segment_start(right.segment),
      0.5,
    )
  let healed_left = snap_offset_end_position_only(left, boundary)
  let healed_right = snap_offset_start_position_only(right, boundary)
  case
    certified_healed_boundary(healed_left:, healed_right:, distance:, options:)
  {
    True -> Ok(#(healed_left, healed_right))
    False -> Ok(#(left, right))
  }
}

fn heal_reversal_offset_boundary(
  left: FUnhealedOffsetSegment,
  right: FUnhealedOffsetSegment,
  distance: Float,
  options: Options,
) -> Result(#(FUnhealedOffsetSegment, FUnhealedOffsetSegment), Error) {
  use _ <- result.try(
    bool_result(offset_boundary_is_known_reversal(left, right)),
  )
  let boundary =
    interpolate(
      svg_path.segment_end(left.segment),
      svg_path.segment_start(right.segment),
      0.5,
    )
  let healed_left = snap_offset_end_position_only(left, boundary)
  let healed_right = snap_offset_start_position_only(right, boundary)
  case
    certified_healed_boundary(healed_left:, healed_right:, distance:, options:)
  {
    True -> Ok(#(healed_left, healed_right))
    False -> Error(NonFinite)
  }
}

fn snap_offset_end_position_only(
  offset: FUnhealedOffsetSegment,
  end: svg_path.Point,
) -> FUnhealedOffsetSegment {
  let delta = subtract(end, svg_path.segment_end(offset.segment))
  FUnhealedOffsetSegment(
    ..offset,
    segment: translate_segment_end_handle(offset.segment, end, delta),
  )
}

fn snap_offset_start_position_only(
  offset: FUnhealedOffsetSegment,
  start: svg_path.Point,
) -> FUnhealedOffsetSegment {
  let delta = subtract(start, svg_path.segment_start(offset.segment))
  FUnhealedOffsetSegment(
    ..offset,
    segment: translate_segment_start_handle(offset.segment, start, delta),
  )
}

fn translate_segment_start_handle(
  segment: svg_path.Segment,
  start: svg_path.Point,
  delta: svg_path.Point,
) -> svg_path.Segment {
  case segment {
    svg_path.Line(end:, ..) -> svg_path.Line(start:, end:)
    svg_path.QuadraticBezier(control:, end:, ..) ->
      svg_path.QuadraticBezier(start:, control: add(control, delta), end:)
    svg_path.CubicBezier(control1:, control2:, end:, ..) ->
      svg_path.CubicBezier(
        start:,
        control1: add(control1, delta),
        control2:,
        end:,
      )
    svg_path.Arc(radius:, x_axis_rotation:, large_arc:, sweep:, end:, ..) ->
      svg_path.Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:)
  }
}

fn translate_segment_end_handle(
  segment: svg_path.Segment,
  end: svg_path.Point,
  delta: svg_path.Point,
) -> svg_path.Segment {
  case segment {
    svg_path.Line(start:, ..) -> svg_path.Line(start:, end:)
    svg_path.QuadraticBezier(start:, control:, ..) ->
      svg_path.QuadraticBezier(start:, control: add(control, delta), end:)
    svg_path.CubicBezier(start:, control1:, control2:, ..) ->
      svg_path.CubicBezier(
        start:,
        control1:,
        control2: add(control2, delta),
        end:,
      )
    svg_path.Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, ..) ->
      svg_path.Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:)
  }
}

fn offset_boundary_is_known_reversal(
  left: FUnhealedOffsetSegment,
  right: FUnhealedOffsetSegment,
) -> Bool {
  offset_segment_source_end_is_reversal(left.source)
  && offset_segment_source_start_is_reversal(right.source)
}

fn offset_segment_source_start_is_reversal(
  source: OffsetSegmentSource,
) -> Bool {
  case source {
    OffsetFromJoinFree(join_free) -> {
      let EJoinFreeSegment(start_boundary:, ..) = join_free
      boundary_is_reversal(start_boundary)
    }
    OffsetFromStalledRun(..) -> False
  }
}

fn offset_segment_source_end_is_reversal(source: OffsetSegmentSource) -> Bool {
  case source {
    OffsetFromJoinFree(join_free) -> {
      let EJoinFreeSegment(end_boundary:, ..) = join_free
      boundary_is_reversal(end_boundary)
    }
    OffsetFromStalledRun(..) -> False
  }
}

fn certified_healed_boundary(
  healed_left healed_left: FUnhealedOffsetSegment,
  healed_right healed_right: FUnhealedOffsetSegment,
  distance distance: Float,
  options options: Options,
) -> Bool {
  healed_offset_certified(healed_left, distance, options)
  && healed_offset_certified(healed_right, distance, options)
}

fn healed_offset_certified(
  healed: FUnhealedOffsetSegment,
  distance: Float,
  options: Options,
) -> Bool {
  case offset_segment_certification_source(healed.source) {
    None -> True
    Some(source_segment) ->
      case
        offset_divergence(source_segment, healed.segment, distance, options)
      {
        Ok(divergence) -> divergence <=. options.fitting.tolerance
        Error(_) -> False
      }
  }
}

fn offset_segment_certification_source(
  source: OffsetSegmentSource,
) -> Option(svg_path.Segment) {
  case source {
    OffsetFromJoinFree(join_free) -> {
      let EJoinFreeSegment(segment:, ..) = join_free
      Some(segment)
    }
    OffsetFromStalledRun(..) -> None
  }
}

fn endpoint_tangent_turn(
  segment: svg_path.Segment,
  endpoint: SegmentEndpoint,
) -> TangentTurn {
  case segment {
    svg_path.Line(..) -> Straight
    _ -> {
      let t = case endpoint {
        SegmentStart -> 0.0
        SegmentEnd -> 1.0
      }
      case curvature.segment_right_normal_curvature(segment, at: t) {
        Ok(value) ->
          case float.absolute_value(value) >. tangent_turn_curvature_epsilon {
            True ->
              case value <. 0.0 {
                True -> Clockwise
                False -> CounterClockwise
              }
            False -> endpoint_tangent_turn_from_chord(segment, endpoint)
          }
        Error(_) -> endpoint_tangent_turn_from_chord(segment, endpoint)
      }
    }
  }
}

fn endpoint_tangent_turn_from_chord(
  segment: svg_path.Segment,
  endpoint: SegmentEndpoint,
) -> TangentTurn {
  let chord =
    subtract(svg_path.segment_end(segment), svg_path.segment_start(segment))
  case unit_vector(chord, t: 0.5) {
    Error(_) -> CouldNotMeasure
    Ok(chord_direction) ->
      case endpoint {
        SegmentStart ->
          case unit_tangent(segment, t: 0.0) {
            Error(_) -> CouldNotMeasure
            Ok(tangent) ->
              tangent_turn_from_aperture(point_helpers.clockwise_aperture(
                from: tangent,
                to: chord_direction,
              ))
          }
        SegmentEnd ->
          case unit_tangent(segment, t: 1.0) {
            Error(_) -> CouldNotMeasure
            Ok(tangent) ->
              tangent_turn_from_aperture(point_helpers.clockwise_aperture(
                from: chord_direction,
                to: tangent,
              ))
          }
      }
  }
}

fn tangent_turn_from_aperture(aperture: Float) -> TangentTurn {
  case
    aperture <=. tangent_turn_angle_epsilon
    || 360.0 -. aperture <=. tangent_turn_angle_epsilon
  {
    True -> Straight
    False ->
      case
        float.absolute_value(aperture -. 180.0) <=. tangent_turn_angle_epsilon
      {
        True -> CouldNotMeasure
        False ->
          case aperture <. 180.0 {
            True -> Clockwise
            False -> CounterClockwise
          }
      }
  }
}

fn bool_result(condition: Bool) -> Result(Nil, Error) {
  case condition {
    True -> Ok(Nil)
    False -> Error(NonFinite)
  }
}

/// Compute the angular perturbation needed to make a near-cusp tangent pair
/// strictly ordered.
///
/// `incoming_direction` is the left segment's endpoint tangent in traversal
/// direction. `outgoing_direction` is the right segment's start tangent in
/// traversal direction. Returned angles are SVG-clockwise degrees to apply to
/// those same tangent vectors. Longer chord lengths receive smaller
/// perturbations.
@internal
pub fn internal_reversal_tangent_adjustment(
  incoming_direction incoming_direction: svg_path.Point,
  outgoing_direction outgoing_direction: svg_path.Point,
  incoming_turn incoming_turn: TangentTurn,
  outgoing_turn outgoing_turn: TangentTurn,
  incoming_chord incoming_chord: Float,
  outgoing_chord outgoing_chord: Float,
  required_gap_degrees required_gap_degrees: Float,
) -> Result(ReversalTangentAdjustment, Nil) {
  use turn <- result.try(combine_tangent_turns(incoming_turn, outgoing_turn))
  let total_chord = incoming_chord +. outgoing_chord
  case total_chord >. 0.0 && required_gap_degrees >=. 0.0 {
    False -> Error(Nil)
    True -> {
      let incoming_weight = outgoing_chord /. total_chord
      let outgoing_weight = incoming_chord /. total_chord
      let gap =
        reversal_existing_gap(incoming_direction, outgoing_direction, turn)
      let missing_gap = float.max(0.0, required_gap_degrees -. gap)
      let incoming_magnitude = missing_gap *. incoming_weight
      let outgoing_magnitude = missing_gap *. outgoing_weight
      case turn {
        Clockwise ->
          Ok(ReversalTangentAdjustment(
            incoming_degrees: 0.0 -. incoming_magnitude,
            outgoing_degrees: outgoing_magnitude,
          ))
        CounterClockwise ->
          Ok(ReversalTangentAdjustment(
            incoming_degrees: incoming_magnitude,
            outgoing_degrees: 0.0 -. outgoing_magnitude,
          ))
        Straight -> Error(Nil)
        CouldNotMeasure -> Error(Nil)
      }
    }
  }
}

fn combine_tangent_turns(
  incoming: TangentTurn,
  outgoing: TangentTurn,
) -> Result(TangentTurn, Nil) {
  case incoming, outgoing {
    Clockwise, Clockwise -> Ok(Clockwise)
    Clockwise, Straight -> Ok(Clockwise)
    Straight, Clockwise -> Ok(Clockwise)
    CounterClockwise, CounterClockwise -> Ok(CounterClockwise)
    CounterClockwise, Straight -> Ok(CounterClockwise)
    Straight, CounterClockwise -> Ok(CounterClockwise)
    Straight, Straight -> Ok(Straight)
    _, _ -> Error(Nil)
  }
}

fn reversal_existing_gap(
  incoming_direction: svg_path.Point,
  outgoing_direction: svg_path.Point,
  turn: TangentTurn,
) -> Float {
  let opposite_outgoing = scale(outgoing_direction, -1.0)
  case turn {
    Clockwise ->
      local_aperture(point_helpers.clockwise_aperture(
        from: incoming_direction,
        to: opposite_outgoing,
      ))
    CounterClockwise ->
      local_aperture(point_helpers.clockwise_aperture(
        from: opposite_outgoing,
        to: incoming_direction,
      ))
    Straight -> 0.0
    CouldNotMeasure -> 0.0
  }
}

fn local_aperture(aperture: Float) -> Float {
  case aperture <=. 180.0 {
    True -> aperture
    False -> 0.0 -. { 360.0 -. aperture }
  }
}

fn rotate_direction(
  direction: svg_path.Point,
  degrees: Float,
) -> svg_path.Point {
  point_helpers.direction(degrees: point_helpers.heading(direction) +. degrees)
}

fn last_list_item(items: List(a)) -> Result(a, Error) {
  case list.last(items) {
    Ok(item) -> Ok(item)
    Error(_) -> Error(NonFinite)
  }
}

fn replace_last_offset(
  offsets: List(FUnhealedOffsetSegment),
  replacement: FUnhealedOffsetSegment,
) -> List(FUnhealedOffsetSegment) {
  case offsets {
    [] -> []
    [_] -> [replacement]
    [first, ..rest] -> [first, ..replace_last_offset(rest, replacement)]
  }
}

fn directed_miter_join(
  left: GHealedOffsetSegment,
  right: GHealedOffsetSegment,
  start: svg_path.Point,
  end: svg_path.Point,
  distance: Float,
  miter_limit: Float,
) -> Result(List(svg_path.Segment), Error) {
  let left_tangent = left.nudged_end_tangent_direction
  let right_tangent = right.nudged_start_tangent_direction

  case directed_line_intersection(start, left_tangent, end, right_tangent) {
    Error(_) -> Ok(line_segments_between([start, end]))
    Ok(apex) -> {
      let corner = offset_segment_source_end(left.source)
      let miter_length = point_distance(corner, apex)
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
  left: GHealedOffsetSegment,
  right: GHealedOffsetSegment,
  start: svg_path.Point,
  end: svg_path.Point,
  distance: Float,
) -> Result(List(svg_path.Segment), Error) {
  let radius = float.absolute_value(distance)
  case radius <=. point_tolerance {
    True -> Ok(line_segments_between([start, end]))
    False -> {
      let left_tangent = left.nudged_end_tangent_direction
      let right_tangent = right.nudged_start_tangent_direction
      let left_normal = rotate_clockwise(left_tangent)
      let right_normal = rotate_clockwise(right_tangent)
      let angle = signed_angle(left_normal, right_normal)
      case float.absolute_value(angle) <=. point_tolerance {
        True -> Ok(line_segments_between([start, end]))
        False ->
          Ok([
            svg_path.Arc(
              start:,
              radius: svg_path.Point(radius, radius),
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

fn directed_line_intersection(
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
      let right_t = cross(delta, left_direction) /. determinant
      let point = add(left_start, scale(left_direction, left_t))
      case left_t >=. 0.0 && right_t <=. 0.0 && point_is_finite(point) {
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

fn build_exact_arc_offset_segment(
  arc: svg_path.Segment,
  source source: OffsetSegmentSource,
) -> Result(FUnhealedOffsetSegment, Error) {
  use start_tangent <- result.try(unit_tangent(arc, t: 0.0))
  use end_tangent <- result.try(unit_tangent(arc, t: 1.0))
  Ok(make_offset_segment(
    segment: arc,
    source:,
    nudged_start_tangent_direction: start_tangent,
    nudged_end_tangent_direction: end_tangent,
  ))
}

fn offset_circular_arc_segment_raw(
  segment: svg_path.Segment,
  distance: Float,
  radius: Float,
) -> Result(svg_path.Segment, Error) {
  use start <- result.try(offset_point(segment, t: 0.0, distance:))
  use end <- result.try(offset_point(segment, t: 1.0, distance:))
  use center <- result.try(
    svg_path.arc_center_data(segment) |> result.map_error(PathError),
  )
  let arc =
    svg_path.Arc(
      start:,
      radius: svg_path.Point(
        float.absolute_value(radius),
        float.absolute_value(radius),
      ),
      x_axis_rotation: center.x_axis_rotation,
      large_arc: float.absolute_value(center.delta_angle) >. 180.0,
      sweep: center.delta_angle >=. 0.0,
      end:,
    )
  Ok(arc)
}

fn circular_arc_offset_radius(
  segment: svg_path.Segment,
  distance: Float,
) -> Result(Float, Error) {
  use center <- result.try(
    svg_path.arc_center_data(segment) |> result.map_error(PathError),
  )
  case
    float.absolute_value(center.radius.x -. center.radius.y) <=. point_tolerance
  {
    False -> Error(NonFinite)
    True -> {
      let signed_distance = case center.delta_angle >=. 0.0 {
        True -> distance
        False -> 0.0 -. distance
      }
      Ok(center.radius.x +. signed_distance)
    }
  }
}

fn build_offset_segment(
  distance distance: Float,
  source source: OffsetSegmentSource,
  segment segment: svg_path.Segment,
) -> Result(FUnhealedOffsetSegment, Error) {
  use start_tangent <- result.try(offset_segment_nudged_tangent_direction(
    source,
    segment,
    distance,
    endpoint: SegmentStart,
  ))
  use end_tangent <- result.try(offset_segment_nudged_tangent_direction(
    source,
    segment,
    distance,
    endpoint: SegmentEnd,
  ))
  Ok(make_offset_segment(
    segment:,
    source:,
    nudged_start_tangent_direction: start_tangent,
    nudged_end_tangent_direction: end_tangent,
  ))
}

fn make_offset_segment(
  segment segment: svg_path.Segment,
  source source: OffsetSegmentSource,
  nudged_start_tangent_direction nudged_start_tangent_direction: svg_path.Point,
  nudged_end_tangent_direction nudged_end_tangent_direction: svg_path.Point,
) -> FUnhealedOffsetSegment {
  FUnhealedOffsetSegment(
    segment:,
    source:,
    nudged_start_tangent_direction:,
    nudged_end_tangent_direction:,
  )
}

fn offset_segment_nudged_tangent_direction(
  source: OffsetSegmentSource,
  offset_segment: svg_path.Segment,
  distance: Float,
  endpoint endpoint: SegmentEndpoint,
) -> Result(svg_path.Point, Error) {
  case source {
    OffsetFromJoinFree(join_free) -> {
      use policy <- result.try(e_join_free_endpoint_policy(
        join_free,
        distance,
        endpoint:,
      ))
      case policy {
        FitPositionOnly -> unit_tangent_at_endpoint(offset_segment, endpoint:)
        FitPositionAndDirection(direction)
        | FitPositionAndDirectionWithCollapsedHandle(direction) -> Ok(direction)
      }
    }
    OffsetFromStalledRun(..) ->
      unit_tangent_at_endpoint(offset_segment, endpoint:)
  }
}

fn unit_tangent_at_endpoint(
  segment: svg_path.Segment,
  endpoint endpoint: SegmentEndpoint,
) -> Result(svg_path.Point, Error) {
  case endpoint {
    SegmentStart -> unit_tangent(segment, t: 0.0)
    SegmentEnd -> unit_tangent(segment, t: 1.0)
  }
}

fn offset_segment_source_start(source: OffsetSegmentSource) -> svg_path.Point {
  case source {
    OffsetFromJoinFree(join_free) -> {
      let EJoinFreeSegment(segment:, ..) = join_free
      svg_path.segment_start(segment)
    }
    OffsetFromStalledRun(run) -> {
      let segments = run
      case segments {
        [] -> svg_path.Point(0.0, 0.0)
        [first, ..] -> {
          let CStalledSegment(segment:, ..) = first
          svg_path.segment_start(segment)
        }
      }
    }
  }
}

fn offset_segment_source_end(source: OffsetSegmentSource) -> svg_path.Point {
  case source {
    OffsetFromJoinFree(join_free) -> {
      let EJoinFreeSegment(segment:, ..) = join_free
      svg_path.segment_end(segment)
    }
    OffsetFromStalledRun(run) -> {
      let segments = run
      case list.last(segments) {
        Error(_) -> svg_path.Point(0.0, 0.0)
        Ok(last) -> {
          let CStalledSegment(segment:, ..) = last
          svg_path.segment_end(segment)
        }
      }
    }
  }
}

fn whole_e_join_free_source(segment: svg_path.Segment) -> OffsetSegmentSource {
  let prepared =
    APreparedSegment(source_subpath_index: 0, source_segment_index: 0, segment:)
  let refined =
    DRefinedSegment(
      prepared:,
      prepared_from: 0.0,
      prepared_to: 1.0,
      segment:,
      start_boundary: Ordinary,
      end_boundary: Ordinary,
    )
  OffsetFromJoinFree(EJoinFreeSegment(
    portion_index: 0,
    segment_index: 0,
    generation: 0,
    refined:,
    refined_from: 0.0,
    refined_to: 1.0,
    segment:,
    start_boundary: Ordinary,
    end_boundary: Ordinary,
  ))
}

fn raw_fitting_tolerance(options: Options) -> Float {
  options.fitting.tolerance *. 0.5
}

fn fit_e_join_free_offset_segment(
  source: EJoinFreeSegment,
  distance: Float,
) -> Result(svg_path.Segment, Error) {
  let EJoinFreeSegment(segment:, ..) = source
  use start <- result.try(offset_point(segment, t: 0.0, distance:))
  use end <- result.try(offset_point(segment, t: 1.0, distance:))
  let samples =
    available_offset_fit_samples(
      segment,
      distance,
      [0.2, 0.35, 0.5, 0.65, 0.8],
      samples: [],
    )
  use start_policy <- result.try(e_join_free_endpoint_policy(
    source,
    distance,
    endpoint: SegmentStart,
  ))
  use end_policy <- result.try(e_join_free_endpoint_policy(
    source,
    distance,
    endpoint: SegmentEnd,
  ))
  use _ <- result.try(reject_bezier_double_radius_reversal_e_segment(
    source,
    distance,
  ))
  let policy_fit =
    fit_offset_cubic_with_endpoint_policies(
      start:,
      end:,
      start_policy:,
      end_policy:,
      samples:,
    )
  use candidate <- result.try(policy_fit)

  case segment_is_finite(candidate) {
    True -> Ok(candidate)
    False -> Error(NonFinite)
  }
}

fn d_refined_endpoint_reaches_offset_radius(
  source: DRefinedSegment,
  distance: Float,
  endpoint: SegmentEndpoint,
) -> Bool {
  let DRefinedSegment(
    prepared: APreparedSegment(segment: prepared_segment, ..),
    prepared_from:,
    prepared_to:,
    ..,
  ) = source
  let t = case endpoint {
    SegmentStart -> prepared_from
    SegmentEnd -> prepared_to
  }
  prepared_parameter_reaches_offset_radius(prepared_segment, t, distance)
}

fn e_join_free_endpoint_reaches_offset_radius(
  source: EJoinFreeSegment,
  distance: Float,
  endpoint: SegmentEndpoint,
) -> Bool {
  let EJoinFreeSegment(
    refined: DRefinedSegment(
      prepared: APreparedSegment(segment: prepared_segment, ..),
      prepared_from:,
      prepared_to:,
      ..,
    ),
    refined_from:,
    refined_to:,
    ..,
  ) = source
  let refined_t = case endpoint {
    SegmentStart -> refined_from
    SegmentEnd -> refined_to
  }
  let prepared_t =
    prepared_from +. { prepared_to -. prepared_from } *. refined_t
  prepared_parameter_reaches_offset_radius(
    prepared_segment,
    prepared_t,
    distance,
  )
}

fn prepared_parameter_reaches_offset_radius(
  segment: svg_path.Segment,
  t: Float,
  distance: Float,
) -> Bool {
  let residual = radius_residual(segment, t, distance)
  case residual {
    Ok(value) ->
      case float.absolute_value(value) <=. curvature_parameter_tolerance {
        True -> True
        False -> parameter_brackets_offset_radius(segment, t, distance)
      }
    Error(_) -> parameter_brackets_offset_radius(segment, t, distance)
  }
}

fn parameter_brackets_offset_radius(
  segment: svg_path.Segment,
  t: Float,
  distance: Float,
) -> Bool {
  let delta = curvature_parameter_tolerance *. 2.0
  case t >. delta && t <. 1.0 -. delta {
    False -> False
    True ->
      case
        radius_residual(segment, t -. delta, distance),
        radius_residual(segment, t +. delta, distance)
      {
        Ok(left), Ok(right) -> left *. right <=. 0.0
        _, _ -> False
      }
  }
}

fn radius_residual(
  segment: svg_path.Segment,
  t: Float,
  distance: Float,
) -> Result(Float, Nil) {
  curvature.segment_right_normal_radius(segment, at: t)
  |> result.map(fn(radius) { radius -. distance })
}

fn reject_bezier_double_radius_reversal_e_segment(
  source: EJoinFreeSegment,
  distance: Float,
) -> Result(Nil, Error) {
  let EJoinFreeSegment(segment:, start_boundary:, end_boundary:, ..) = source
  case
    boundary_is_reversal(start_boundary)
    && boundary_is_reversal(end_boundary)
    && e_join_free_endpoint_reaches_offset_radius(
      source,
      distance,
      SegmentStart,
    )
    && e_join_free_endpoint_reaches_offset_radius(source, distance, SegmentEnd)
    && segment_is_bezier(segment)
  {
    True -> Error(NonFinite)
    False -> Ok(Nil)
  }
}

fn e_join_free_endpoint_policy(
  source: EJoinFreeSegment,
  distance: Float,
  endpoint endpoint: SegmentEndpoint,
) -> Result(CubicEndpointFitPolicy, Error) {
  let EJoinFreeSegment(segment:, start_boundary:, end_boundary:, ..) = source
  let is_reversal = case endpoint {
    SegmentStart -> boundary_is_reversal(start_boundary)
    SegmentEnd -> boundary_is_reversal(end_boundary)
  }
  let reaches_offset_radius =
    e_join_free_endpoint_reaches_offset_radius(source, distance, endpoint)
  let opposite_t = case endpoint {
    SegmentStart -> 1.0
    SegmentEnd -> 0.0
  }
  let opposite_direction = offset_derivative(segment, t: opposite_t, distance:)
  use direction <- result.try(e_join_free_endpoint_offset_direction(
    source,
    distance,
    endpoint,
    is_reversal,
    reaches_offset_radius,
  ))
  case is_reversal {
    False -> Ok(FitPositionAndDirection(direction))
    True -> {
      let turn = endpoint_tangent_turn(segment, endpoint)
      let nudged =
        nudged_reversal_fit_direction(
          direction,
          opposite_direction,
          turn,
          endpoint,
        )
      case reaches_offset_radius {
        True -> Ok(FitPositionAndDirectionWithCollapsedHandle(nudged))
        False -> Ok(FitPositionAndDirection(nudged))
      }
    }
  }
}

fn e_join_free_endpoint_offset_direction(
  source: EJoinFreeSegment,
  distance: Float,
  endpoint: SegmentEndpoint,
  is_reversal: Bool,
  reaches_offset_radius: Bool,
) -> Result(svg_path.Point, Error) {
  let EJoinFreeSegment(segment:, ..) = source
  let endpoint_t = case endpoint {
    SegmentStart -> 0.0
    SegmentEnd -> 1.0
  }
  let interior_t = case endpoint {
    SegmentStart -> curvature_parameter_tolerance *. 2.0
    SegmentEnd -> 1.0 -. curvature_parameter_tolerance *. 2.0
  }
  case is_reversal && reaches_offset_radius {
    False -> offset_derivative(segment, t: endpoint_t, distance:)
    True ->
      case offset_derivative(segment, t: interior_t, distance:) {
        Ok(direction) -> Ok(direction)
        Error(_) -> offset_derivative(segment, t: endpoint_t, distance:)
      }
  }
}

fn nudged_reversal_fit_direction(
  direction: svg_path.Point,
  opposite_direction: Result(svg_path.Point, Error),
  turn: TangentTurn,
  endpoint: SegmentEndpoint,
) -> svg_path.Point {
  let base_desired_degrees =
    case turn, endpoint {
      Clockwise, SegmentStart -> 1.0
      Clockwise, SegmentEnd -> -1.0
      CounterClockwise, SegmentStart -> -1.0
      CounterClockwise, SegmentEnd -> 1.0
      Straight, _ | CouldNotMeasure, _ -> 0.0
    }
    *. reversal_fit_tangent_nudge_degrees
  let desired_degrees = base_desired_degrees
  let degrees = case opposite_direction {
    Ok(opposite_direction) ->
      clamped_reversal_fit_nudge(direction, opposite_direction, desired_degrees)
    Error(_) -> desired_degrees
  }
  rotate_direction(direction, degrees)
}

fn clamped_reversal_fit_nudge(
  reversal_direction: svg_path.Point,
  opposite_direction: svg_path.Point,
  desired_degrees: Float,
) -> Float {
  let room = signed_angle(reversal_direction, opposite_direction)
  case room *. desired_degrees <=. 0.0 {
    True -> 0.0
    False -> {
      let room_abs = float.absolute_value(room)
      let desired_abs = float.absolute_value(desired_degrees)
      case room_abs <=. desired_abs {
        True -> room *. 0.5
        False -> desired_degrees
      }
    }
  }
}

fn fit_offset_cubic_with_endpoint_policies(
  start start: svg_path.Point,
  end end: svg_path.Point,
  start_policy start_policy: CubicEndpointFitPolicy,
  end_policy end_policy: CubicEndpointFitPolicy,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(svg_path.Segment, Error) {
  case start_policy, end_policy {
    FitPositionAndDirectionWithCollapsedHandle(start_direction),
      FitPositionAndDirectionWithCollapsedHandle(end_direction)
    ->
      fit_offset_cubic_both_stalled(
        start:,
        end:,
        start_direction:,
        end_direction:,
      )
    _, _ ->
      fit_offset_cubic_with_non_both_stalled_endpoint_policies(
        start:,
        end:,
        start_policy:,
        end_policy:,
        samples:,
      )
  }
}

fn fit_offset_cubic_with_non_both_stalled_endpoint_policies(
  start start: svg_path.Point,
  end end: svg_path.Point,
  start_policy start_policy: CubicEndpointFitPolicy,
  end_policy end_policy: CubicEndpointFitPolicy,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(svg_path.Segment, Error) {
  let start = to_bezier_point(start)
  let end = to_bezier_point(end)
  use curve <- result.try(fit_offset_cubic_data_with_endpoint_policies(
    start:,
    end:,
    start_policy:,
    end_policy:,
    samples:,
  ))
  fitted_curve_to_segment(curve)
}

fn fit_offset_cubic_data_with_endpoint_policies(
  start start: bezier.BezierPoint,
  end end: bezier.BezierPoint,
  start_policy start_policy: CubicEndpointFitPolicy,
  end_policy end_policy: CubicEndpointFitPolicy,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(bezier.BezierData, Error) {
  case start_policy, end_policy {
    FitPositionAndDirection(start_direction),
      FitPositionAndDirection(end_direction)
    -> {
      use fit <- result.try(
        bezier.fit_cubic_with_endpoint_tangents(
          start:,
          end:,
          start_tangent: to_bezier_point(start_direction),
          end_tangent: to_bezier_point(end_direction),
          samples:,
        )
        |> result.map_error(cubic_fit_error),
      )
      let #(curve, _) = fit
      recover_collapsed_direction_fit(
        curve,
        start:,
        end:,
        start_direction:,
        end_direction:,
        samples:,
      )
    }
    FitPositionOnly, FitPositionOnly -> {
      use fit <- result.try(
        bezier.fit_cubic_with_endpoints(start:, end:, samples:)
        |> result.map_error(cubic_fit_error),
      )
      let #(curve, _) = fit
      Ok(curve)
    }
    FitPositionAndDirectionWithCollapsedHandle(_start_direction),
      FitPositionAndDirectionWithCollapsedHandle(_end_direction)
    -> Error(NonFinite)
    FitPositionAndDirectionWithCollapsedHandle(start_direction),
      FitPositionAndDirection(end_direction)
    ->
      fit_offset_cubic_start_stalled_end_tangent(
        start:,
        end:,
        start_direction:,
        end_direction:,
        samples:,
      )
    FitPositionAndDirection(start_direction),
      FitPositionAndDirectionWithCollapsedHandle(end_direction)
    ->
      fit_offset_cubic_start_tangent_end_stalled(
        start:,
        end:,
        start_direction:,
        end_direction:,
        samples:,
      )
    FitPositionAndDirectionWithCollapsedHandle(start_direction), FitPositionOnly
    ->
      fit_offset_cubic_start_stalled_end_position(
        start:,
        end:,
        start_direction:,
        samples:,
      )
    FitPositionOnly, FitPositionAndDirectionWithCollapsedHandle(end_direction)
    ->
      fit_offset_cubic_start_position_end_stalled(
        start:,
        end:,
        end_direction:,
        samples:,
      )
    FitPositionAndDirection(start_direction), FitPositionOnly ->
      fit_offset_cubic_start_tangent_end_position(
        start:,
        end:,
        start_direction:,
        samples:,
      )
    FitPositionOnly, FitPositionAndDirection(end_direction) ->
      fit_offset_cubic_start_position_end_tangent(
        start:,
        end:,
        end_direction:,
        samples:,
      )
  }
}

fn recover_collapsed_direction_fit(
  curve: bezier.BezierData,
  start start: bezier.BezierPoint,
  end end: bezier.BezierPoint,
  start_direction start_direction: svg_path.Point,
  end_direction end_direction: svg_path.Point,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(bezier.BezierData, Error) {
  case curve {
    bezier.CubicBezierData(control1:, control2:, ..) -> {
      let start_collapsed = bezier_points_equal(start, control1)
      let end_collapsed = bezier_points_equal(end, control2)
      case start_collapsed, end_collapsed {
        True, True -> Error(NonFinite)
        True, False ->
          fit_offset_cubic_data_with_endpoint_policies(
            start:,
            end:,
            start_policy: FitPositionAndDirectionWithCollapsedHandle(
              start_direction,
            ),
            end_policy: FitPositionAndDirection(end_direction),
            samples:,
          )
        False, True ->
          fit_offset_cubic_data_with_endpoint_policies(
            start:,
            end:,
            start_policy: FitPositionAndDirection(start_direction),
            end_policy: FitPositionAndDirectionWithCollapsedHandle(
              end_direction,
            ),
            samples:,
          )
        False, False -> Ok(curve)
      }
    }
    _ -> Ok(curve)
  }
}

fn bezier_points_equal(
  left: bezier.BezierPoint,
  right: bezier.BezierPoint,
) -> Bool {
  left.x == right.x && left.y == right.y
}

fn fit_offset_cubic_both_stalled(
  start start: svg_path.Point,
  end end: svg_path.Point,
  start_direction start_direction: svg_path.Point,
  end_direction end_direction: svg_path.Point,
) -> Result(svg_path.Segment, Error) {
  let chord = subtract(end, start)
  use chord_direction <- result.try(unit_vector(chord, t: 0.5))
  let start_angle =
    float.absolute_value(signed_angle(start_direction, chord_direction))
  let end_angle =
    float.absolute_value(signed_angle(end_direction, chord_direction))
  case
    start_angle <=. reversal_tangent_gap_degrees
    && end_angle <=. reversal_tangent_gap_degrees
  {
    True -> Ok(svg_path.Line(start:, end:))
    False -> Error(NonFinite)
  }
}

fn fit_offset_cubic_start_stalled_end_tangent(
  start start: bezier.BezierPoint,
  end end: bezier.BezierPoint,
  start_direction start_direction: svg_path.Point,
  end_direction end_direction: svg_path.Point,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(bezier.BezierData, Error) {
  let start_point = from_bezier_point(start)
  let end_point = from_bezier_point(end)
  use c2 <- result.try(stalled_start_control2(
    start: start_point,
    end: end_point,
    start_direction:,
    end_direction:,
    samples:,
  ))
  Ok(bezier.CubicBezierData(
    start:,
    control1: start,
    control2: to_bezier_point(c2),
    end:,
  ))
}

fn fit_offset_cubic_start_tangent_end_stalled(
  start start: bezier.BezierPoint,
  end end: bezier.BezierPoint,
  start_direction start_direction: svg_path.Point,
  end_direction end_direction: svg_path.Point,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(bezier.BezierData, Error) {
  let start_point = from_bezier_point(start)
  let end_point = from_bezier_point(end)
  use c1 <- result.try(stalled_end_control1(
    start: start_point,
    end: end_point,
    start_direction:,
    end_direction:,
    samples:,
  ))
  Ok(bezier.CubicBezierData(
    start:,
    control1: to_bezier_point(c1),
    control2: end,
    end:,
  ))
}

fn fit_offset_cubic_start_stalled_end_position(
  start start: bezier.BezierPoint,
  end end: bezier.BezierPoint,
  start_direction start_direction: svg_path.Point,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(bezier.BezierData, Error) {
  let start_point = from_bezier_point(start)
  let end_point = from_bezier_point(end)
  use start_direction <- result.try(unit_vector(start_direction, t: 0.0))
  use b <- result.try(fit_start_tangent_one_handle(
    start: start_point,
    end: end_point,
    direction: start_direction,
    control2: end_point,
    samples:,
  ))
  use _ <- result.try(validate_reversal_handle_scalar(start_point, end_point, b))
  Ok(bezier.CubicBezierData(
    start:,
    control1: start,
    control2: to_bezier_point(add(start_point, scale(start_direction, b))),
    end:,
  ))
}

fn fit_offset_cubic_start_position_end_stalled(
  start start: bezier.BezierPoint,
  end end: bezier.BezierPoint,
  end_direction end_direction: svg_path.Point,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(bezier.BezierData, Error) {
  let start_point = from_bezier_point(start)
  let end_point = from_bezier_point(end)
  use end_direction <- result.try(unit_vector(end_direction, t: 1.0))
  use a <- result.try(fit_end_tangent_one_handle(
    start: start_point,
    end: end_point,
    control1: start_point,
    direction: end_direction,
    samples:,
  ))
  use _ <- result.try(validate_reversal_handle_scalar(start_point, end_point, a))
  Ok(bezier.CubicBezierData(
    start:,
    control1: to_bezier_point(subtract(end_point, scale(end_direction, a))),
    control2: end,
    end:,
  ))
}

fn fit_offset_cubic_start_tangent_end_position(
  start start: bezier.BezierPoint,
  end end: bezier.BezierPoint,
  start_direction start_direction: svg_path.Point,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(bezier.BezierData, Error) {
  let start_point = from_bezier_point(start)
  let end_point = from_bezier_point(end)
  use start_direction <- result.try(unit_vector(start_direction, t: 0.0))
  use a <- result.try(fit_start_tangent_one_handle(
    start: start_point,
    end: end_point,
    direction: start_direction,
    control2: end_point,
    samples:,
  ))
  use _ <- result.try(validate_reversal_handle_scalar(start_point, end_point, a))
  Ok(bezier.CubicBezierData(
    start:,
    control1: to_bezier_point(add(start_point, scale(start_direction, a))),
    control2: end,
    end:,
  ))
}

fn fit_offset_cubic_start_position_end_tangent(
  start start: bezier.BezierPoint,
  end end: bezier.BezierPoint,
  end_direction end_direction: svg_path.Point,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(bezier.BezierData, Error) {
  let start_point = from_bezier_point(start)
  let end_point = from_bezier_point(end)
  use end_direction <- result.try(unit_vector(end_direction, t: 1.0))
  use b <- result.try(fit_end_tangent_one_handle(
    start: start_point,
    end: end_point,
    control1: start_point,
    direction: end_direction,
    samples:,
  ))
  use _ <- result.try(validate_reversal_handle_scalar(start_point, end_point, b))
  Ok(bezier.CubicBezierData(
    start:,
    control1: start,
    control2: to_bezier_point(subtract(end_point, scale(end_direction, b))),
    end:,
  ))
}

fn validate_reversal_handle_scalar(
  start: svg_path.Point,
  end: svg_path.Point,
  value: Float,
) -> Result(Nil, Error) {
  let chord = point_distance(start, end)
  let min = reversal_fit_min_handle_chord_ratio *. chord
  let max = reversal_fit_max_handle_chord_ratio *. chord
  case
    number.is_finite(value)
    && chord >. point_tolerance
    && value >=. min
    && value <=. max
  {
    True -> Ok(Nil)
    False -> Error(NonFinite)
  }
}

fn stalled_start_control2(
  start start: svg_path.Point,
  end end: svg_path.Point,
  start_direction start_direction: svg_path.Point,
  end_direction end_direction: svg_path.Point,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(svg_path.Point, Error) {
  case
    direction_line_intersection(
      start,
      start_direction,
      end,
      scale(end_direction, -1.0),
    )
  {
    Ok(point) -> {
      let handle = point_distance(end, point)
      let chord = point_distance(start, end)
      case handle >=. 0.0 && handle <=. 2.0 *. chord {
        True -> Ok(point)
        False ->
          stalled_start_control2_by_bisection(
            start:,
            end:,
            start_direction:,
            end_direction:,
          )
      }
    }
    Error(_) ->
      stalled_start_control2_parallel_or_bisection(
        start:,
        end:,
        start_direction:,
        end_direction:,
        samples:,
      )
  }
}

fn stalled_end_control1(
  start start: svg_path.Point,
  end end: svg_path.Point,
  start_direction start_direction: svg_path.Point,
  end_direction end_direction: svg_path.Point,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(svg_path.Point, Error) {
  case direction_line_intersection(start, start_direction, end, end_direction) {
    Ok(point) -> {
      let handle = point_distance(start, point)
      let chord = point_distance(start, end)
      case handle >=. 0.0 && handle <=. 2.0 *. chord {
        True -> Ok(point)
        False ->
          stalled_end_control1_by_bisection(
            start:,
            end:,
            start_direction:,
            end_direction:,
          )
      }
    }
    Error(_) ->
      stalled_end_control1_parallel_or_bisection(
        start:,
        end:,
        start_direction:,
        end_direction:,
        samples:,
      )
  }
}

fn stalled_start_control2_parallel_or_bisection(
  start start: svg_path.Point,
  end end: svg_path.Point,
  start_direction start_direction: svg_path.Point,
  end_direction end_direction: svg_path.Point,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(svg_path.Point, Error) {
  case directions_follow_chord(start, end, start_direction, end_direction) {
    False ->
      stalled_start_control2_by_bisection(
        start:,
        end:,
        start_direction:,
        end_direction:,
      )
    True -> {
      use end_direction <- result.try(unit_vector(end_direction, t: 1.0))
      use handle <- result.try(fit_end_tangent_one_handle(
        start:,
        end:,
        control1: start,
        direction: end_direction,
        samples:,
      ))
      use _ <- result.try(validate_reversal_handle_scalar(start, end, handle))
      Ok(subtract(end, scale(end_direction, handle)))
    }
  }
}

fn stalled_end_control1_parallel_or_bisection(
  start start: svg_path.Point,
  end end: svg_path.Point,
  start_direction start_direction: svg_path.Point,
  end_direction end_direction: svg_path.Point,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(svg_path.Point, Error) {
  case directions_follow_chord(start, end, start_direction, end_direction) {
    False ->
      stalled_end_control1_by_bisection(
        start:,
        end:,
        start_direction:,
        end_direction:,
      )
    True -> {
      use start_direction <- result.try(unit_vector(start_direction, t: 0.0))
      use handle <- result.try(fit_start_tangent_one_handle(
        start:,
        end:,
        direction: start_direction,
        control2: end,
        samples:,
      ))
      use _ <- result.try(validate_reversal_handle_scalar(start, end, handle))
      Ok(add(start, scale(start_direction, handle)))
    }
  }
}

fn directions_follow_chord(
  start: svg_path.Point,
  end: svg_path.Point,
  start_direction: svg_path.Point,
  end_direction: svg_path.Point,
) -> Bool {
  case unit_vector(subtract(end, start), t: 0.5) {
    Error(_) -> False
    Ok(chord_direction) ->
      float.absolute_value(signed_angle(start_direction, chord_direction))
      <=. reversal_tangent_gap_degrees
      && float.absolute_value(signed_angle(end_direction, chord_direction))
      <=. reversal_tangent_gap_degrees
  }
}

fn direction_line_intersection(
  a: svg_path.Point,
  a_direction: svg_path.Point,
  b: svg_path.Point,
  b_direction: svg_path.Point,
) -> Result(svg_path.Point, Error) {
  use a_unit <- result.try(unit_vector(a_direction, t: 0.0))
  use b_unit <- result.try(unit_vector(b_direction, t: 0.0))
  let determinant = cross(a_unit, b_unit)
  case
    float.absolute_value(determinant)
    <. trig.sin_degrees(reversal_fit_line_aperture_degrees)
  {
    True -> Error(NonFinite)
    False -> {
      let delta = subtract(b, a)
      let scale_a = cross(delta, b_unit) /. determinant
      Ok(add(a, scale(a_unit, scale_a)))
    }
  }
}

fn stalled_start_control2_by_bisection(
  start start: svg_path.Point,
  end end: svg_path.Point,
  start_direction start_direction: svg_path.Point,
  end_direction end_direction: svg_path.Point,
) -> Result(svg_path.Point, Error) {
  let chord = point_distance(start, end)
  let from = reversal_fit_min_handle_chord_ratio *. chord
  let to = reversal_fit_max_handle_chord_ratio *. chord
  let point_for = fn(handle) { subtract(end, scale(end_direction, handle)) }
  let score = fn(handle) {
    case unit_vector(subtract(point_for(handle), start), t: 0.0) {
      Error(_) -> 0.0
      Ok(direction) -> cross(start_direction, direction)
    }
  }
  use handle <- result.try(bisect_signed_zero(score, from, to, iterations: 40))
  Ok(point_for(handle))
}

fn stalled_end_control1_by_bisection(
  start start: svg_path.Point,
  end end: svg_path.Point,
  start_direction start_direction: svg_path.Point,
  end_direction end_direction: svg_path.Point,
) -> Result(svg_path.Point, Error) {
  let chord = point_distance(start, end)
  let from = reversal_fit_min_handle_chord_ratio *. chord
  let to = reversal_fit_max_handle_chord_ratio *. chord
  let point_for = fn(handle) { add(start, scale(start_direction, handle)) }
  let score = fn(handle) {
    case unit_vector(subtract(point_for(handle), end), t: 1.0) {
      Error(_) -> 0.0
      Ok(direction) -> cross(end_direction, direction)
    }
  }
  use handle <- result.try(bisect_signed_zero(score, from, to, iterations: 40))
  Ok(point_for(handle))
}

fn bisect_signed_zero(
  score: fn(Float) -> Float,
  from: Float,
  to: Float,
  iterations iterations: Int,
) -> Result(Float, Error) {
  let from_score = score(from)
  let to_score = score(to)
  case from_score == 0.0 {
    True -> Ok(from)
    False ->
      case to_score == 0.0 {
        True -> Ok(to)
        False ->
          case from_score *. to_score >. 0.0 {
            True -> Error(NonFinite)
            False ->
              Ok(bisect_signed_zero_loop(
                score,
                from,
                to,
                from_score,
                iterations:,
              ))
          }
      }
  }
}

fn bisect_signed_zero_loop(
  score: fn(Float) -> Float,
  from: Float,
  to: Float,
  from_score: Float,
  iterations iterations: Int,
) -> Float {
  case iterations <= 0 {
    True -> { from +. to } /. 2.0
    False -> {
      let middle = { from +. to } /. 2.0
      let middle_score = score(middle)
      case middle_score == 0.0 {
        True -> middle
        False ->
          case from_score *. middle_score <=. 0.0 {
            True ->
              bisect_signed_zero_loop(
                score,
                from,
                middle,
                from_score,
                iterations: iterations - 1,
              )
            False ->
              bisect_signed_zero_loop(
                score,
                middle,
                to,
                middle_score,
                iterations: iterations - 1,
              )
          }
      }
    }
  }
}

fn fit_start_tangent_one_handle(
  start start: svg_path.Point,
  end end: svg_path.Point,
  direction direction: svg_path.Point,
  control2 control2: svg_path.Point,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(Float, Error) {
  fit_one_handle(
    samples,
    fixed: fn(t) {
      let u = 1.0 -. t
      add(
        add(
          scale(start, u *. u *. u +. 3.0 *. u *. u *. t),
          scale(control2, 3.0 *. u *. t *. t),
        ),
        scale(end, t *. t *. t),
      )
    },
    column: fn(t) {
      let u = 1.0 -. t
      scale(direction, 3.0 *. u *. u *. t)
    },
  )
}

fn fit_end_tangent_one_handle(
  start start: svg_path.Point,
  end end: svg_path.Point,
  control1 control1: svg_path.Point,
  direction direction: svg_path.Point,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(Float, Error) {
  fit_one_handle(
    samples,
    fixed: fn(t) {
      let u = 1.0 -. t
      add(
        add(scale(start, u *. u *. u), scale(control1, 3.0 *. u *. u *. t)),
        scale(end, 3.0 *. u *. t *. t +. t *. t *. t),
      )
    },
    column: fn(t) {
      let u = 1.0 -. t
      scale(direction, -3.0 *. u *. t *. t)
    },
  )
}

fn fit_one_handle(
  samples: List(#(Float, bezier.BezierPoint)),
  fixed fixed: fn(Float) -> svg_path.Point,
  column column: fn(Float) -> svg_path.Point,
) -> Result(Float, Error) {
  fit_one_handle_loop(samples, fixed, column, ata: 0.0, atb: 0.0, count: 0)
}

fn fit_one_handle_loop(
  samples: List(#(Float, bezier.BezierPoint)),
  fixed: fn(Float) -> svg_path.Point,
  column: fn(Float) -> svg_path.Point,
  ata ata: Float,
  atb atb: Float,
  count count: Int,
) -> Result(Float, Error) {
  case samples {
    [] -> {
      case count == 0 || float.absolute_value(ata) <=. point_tolerance {
        True -> Error(NonFinite)
        False -> Ok(atb /. ata)
      }
    }
    [sample, ..rest] -> {
      let #(t, point) = sample
      let target = subtract(from_bezier_point(point), fixed(t))
      let col = column(t)
      fit_one_handle_loop(
        rest,
        fixed,
        column,
        ata: ata +. dot(col, col),
        atb: atb +. dot(col, target),
        count: count + 1,
      )
    }
  }
}

fn available_offset_fit_samples(
  segment: svg_path.Segment,
  distance: Float,
  t_values: List(Float),
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> List(#(Float, bezier.BezierPoint)) {
  case t_values {
    [] -> list.reverse(samples)
    [t, ..rest] -> {
      let samples = case offset_point(segment, t:, distance:) {
        Ok(point) -> [#(t, to_bezier_point(point)), ..samples]
        Error(DegenerateTangent(_)) -> samples
        Error(_) -> samples
      }
      available_offset_fit_samples(segment, distance, rest, samples:)
    }
  }
}

fn fitted_curve_to_segment(
  curve: bezier.BezierData,
) -> Result(svg_path.Segment, Error) {
  case curve {
    bezier.CubicBezierData(start:, control1:, control2:, end:) ->
      Ok(svg_path.CubicBezier(
        start: from_bezier_point(start),
        control1: from_bezier_point(control1),
        control2: from_bezier_point(control2),
        end: from_bezier_point(end),
      ))
    _ -> Error(NonFinite)
  }
}

fn cubic_fit_error(error: bezier.Error) -> Error {
  case error {
    bezier.DegenerateTangent -> DegenerateTangent(0.0)
    _ -> NonFinite
  }
}

fn length_spans(
  segments: List(svg_path.Segment),
  options options: svg_path.LengthOptions,
  start_distance start_distance: Float,
  spans spans: List(LengthSpan),
) -> Result(List(LengthSpan), Error) {
  case segments {
    [] -> Ok(list.reverse(spans))
    [first, ..rest] -> {
      use length <- result.try(
        svg_path.segment_length_with(first, options:)
        |> result.map_error(PathError),
      )
      let spans = case length >. 0.0 {
        True -> [LengthSpan(segment: first, start_distance:, length:), ..spans]
        False -> spans
      }
      length_spans(
        rest,
        options:,
        start_distance: start_distance +. length,
        spans:,
      )
    }
  }
}

fn length_spans_total(spans: List(LengthSpan)) -> Float {
  case spans {
    [] -> 0.0
    [first, ..rest] ->
      rest
      |> list.fold(first.start_distance +. first.length, fn(total, span) {
        span.start_distance +. span.length |> float.max(total)
      })
  }
}

fn offset_map_point(
  spans: List(LengthSpan),
  total_length total_length: Float,
  closed closed: Bool,
  options options: svg_path.LengthOptions,
  local local: svg_path.Point,
) -> Result(svg_path.Point, Error) {
  case point_is_finite(local) {
    False -> Error(NonFinite)
    True -> {
      use distance <- result.try(offset_map_distance(
        local.x,
        total_length,
        closed,
      ))
      use span <- result.try(length_span_at(spans, distance))
      let local_distance = distance -. span.start_distance
      use t <- result.try(
        svg_path.segment_parameter_at_length_with(
          span.segment,
          distance: local_distance,
          options:,
        )
        |> result.map_error(PathError),
      )
      use point <- result.try(
        svg_path.segment_point(span.segment, at: t)
        |> result.map_error(PathError),
      )
      use normal <- result.try(unit_normal(span.segment, t:))
      let mapped = add(point, scale(normal, local.y))

      case point_is_finite(mapped) {
        True -> Ok(mapped)
        False -> Error(NonFinite)
      }
    }
  }
}

fn offset_map_distance(
  distance: Float,
  total_length: Float,
  closed: Bool,
) -> Result(Float, Error) {
  case closed {
    True -> Ok(positive_remainder(distance, total_length))
    False ->
      case distance <. 0.0 || distance >. total_length {
        True ->
          Error(
            PathError(svg_path.InvalidLengthDistance(
              distance:,
              length: total_length,
            )),
          )
        False -> Ok(distance)
      }
  }
}

fn positive_remainder(value: Float, modulus: Float) -> Float {
  let turns = float.floor(value /. modulus)
  let remainder = value -. turns *. modulus
  case remainder <. 0.0 {
    True -> remainder +. modulus
    False ->
      case remainder >=. modulus {
        True -> remainder -. modulus
        False -> remainder
      }
  }
}

fn length_span_at(
  spans: List(LengthSpan),
  distance: Float,
) -> Result(LengthSpan, Error) {
  case spans {
    [] -> Error(DegenerateTangent(0.0))
    [first] -> Ok(first)
    [first, ..rest] -> {
      case distance <=. first.start_distance +. first.length {
        True -> Ok(first)
        False -> length_span_at(rest, distance)
      }
    }
  }
}

fn to_bezier_point(point: svg_path.Point) -> bezier.BezierPoint {
  bezier.BezierPoint(x: point.x, y: point.y)
}

fn from_bezier_point(point: bezier.BezierPoint) -> svg_path.Point {
  svg_path.Point(point.x, point.y)
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
    add(derivative, scale(rotate_clockwise(tangent_change), distance))

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
    svg_path.Line(..) -> Ok(svg_path.Point(0.0, 0.0))
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
  case sample > options.fitting.samples {
    True -> Ok(best)
    False -> {
      let t = int_to_float(sample) /. int_to_float(options.fitting.samples + 1)
      use point <- result.try(offset_point(source, t:, distance:))
      use candidate_point <- result.try(
        svg_path.segment_point(candidate, at: t) |> result.map_error(PathError),
      )
      let best = float.max(best, point_distance(point, candidate_point))
      case best >. options.fitting.tolerance {
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

fn smart_offset_divergence(
  source: svg_path.Segment,
  candidate: svg_path.Segment,
  distance: Float,
  options: Options,
) -> Result(Float, Error) {
  smart_offset_divergence_loop(
    source,
    candidate,
    distance,
    options,
    sample: 1,
    best: 0.0,
    valid_samples: 0,
  )
}

fn smart_offset_divergence_loop(
  source: svg_path.Segment,
  candidate: svg_path.Segment,
  distance: Float,
  options: Options,
  sample sample: Int,
  best best: Float,
  valid_samples valid_samples: Int,
) -> Result(Float, Error) {
  case sample > options.fitting.samples {
    True ->
      case valid_samples == 0 {
        True -> Error(DegenerateTangent(0.5))
        False -> Ok(best)
      }
    False -> {
      let t = int_to_float(sample) /. int_to_float(options.fitting.samples + 1)
      case offset_point(source, t:, distance:) {
        Error(DegenerateTangent(_)) ->
          smart_offset_divergence_loop(
            source,
            candidate,
            distance,
            options,
            sample: sample + 1,
            best:,
            valid_samples:,
          )
        Error(error) -> Error(error)
        Ok(point) -> {
          use candidate_point <- result.try(
            svg_path.segment_point(candidate, at: t)
            |> result.map_error(PathError),
          )
          let best = float.max(best, point_distance(point, candidate_point))
          case best >. options.fitting.tolerance {
            True -> Ok(best)
            False ->
              smart_offset_divergence_loop(
                source,
                candidate,
                distance,
                options,
                sample: sample + 1,
                best:,
                valid_samples: valid_samples + 1,
              )
          }
        }
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
  use directions <- result.try(
    svg_path.segment_directions(segment, at: t) |> result.map_error(PathError),
  )
  case t {
    0.0 -> required_direction(directions.outgoing, t:)
    1.0 -> required_direction(directions.incoming, t:)
    _ -> interior_unit_tangent(directions, t:)
  }
}

fn required_direction(
  direction: Option(svg_path.Point),
  t t: Float,
) -> Result(svg_path.Point, Error) {
  case direction {
    Some(direction) -> Ok(direction)
    None -> Error(DegenerateTangent(t))
  }
}

fn interior_unit_tangent(
  directions: svg_path.Directions,
  t t: Float,
) -> Result(svg_path.Point, Error) {
  case directions.incoming, directions.outgoing {
    Some(incoming), Some(outgoing) -> {
      let angle = float.absolute_value(signed_angle(incoming, outgoing))
      case angle <=. tangent_heal_agreement_angle_degrees {
        False -> Error(DegenerateTangent(t))
        True -> {
          let sum = add(incoming, outgoing)
          case point_length(sum) >. tangent_epsilon {
            True -> unit_vector(sum, t:)
            False -> Error(DegenerateTangent(t))
          }
        }
      }
    }
    _, _ -> Error(DegenerateTangent(t))
  }
}

fn length(point: svg_path.Point, t t: Float) -> Result(Float, Error) {
  let length = point_length(point)
  case length >. tangent_epsilon {
    True -> Ok(length)
    False -> Error(DegenerateTangent(t))
  }
}

fn unit_vector(
  point: svg_path.Point,
  t t: Float,
) -> Result(svg_path.Point, Error) {
  use length <- result.try(length(point, t:))
  Ok(scale(point, 1.0 /. length))
}

fn rotate_clockwise(point: svg_path.Point) -> svg_path.Point {
  point_helpers.rotate_clockwise(point)
}

fn interpolate(
  a: svg_path.Point,
  b: svg_path.Point,
  t: Float,
) -> svg_path.Point {
  point_helpers.lerp(a, b, t:)
}

fn add(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  point_helpers.add(a, b)
}

fn subtract(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  point_helpers.subtract(a, b)
}

fn scale(point: svg_path.Point, factor: Float) -> svg_path.Point {
  point_helpers.scale(point, by: factor)
}

fn dot(a: svg_path.Point, b: svg_path.Point) -> Float {
  point_helpers.dot(a, b)
}

fn point_length(point: svg_path.Point) -> Float {
  point_helpers.norm(point)
}

fn point_distance(a: svg_path.Point, b: svg_path.Point) -> Float {
  point_helpers.distance(a, b)
}

fn distance_squared(a: svg_path.Point, b: svg_path.Point) -> Float {
  point_helpers.distance_squared(a, b)
}

fn cross(a: svg_path.Point, b: svg_path.Point) -> Float {
  point_helpers.cross(a, b)
}

fn signed_angle(a: svg_path.Point, b: svg_path.Point) -> Float {
  trig.atan2_degrees(cross(a, b), dot(a, b))
}

fn points_near(a: svg_path.Point, b: svg_path.Point) -> Bool {
  point_helpers.near(a, b, tolerance: point_tolerance)
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
      && number.is_finite(x_axis_rotation)
      && point_is_finite(end)
  }
}

fn point_is_finite(point: svg_path.Point) -> Bool {
  number.is_finite(point.x) && number.is_finite(point.y)
}

fn int_to_float(value: Int) -> Float {
  value |> int.to_float
}
