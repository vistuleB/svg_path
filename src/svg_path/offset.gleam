//// Path offset construction.
////
//// This module follows the same basic model as `svgpathsio`: lines and
//// circular arcs are offset exactly, while other curves are offset by fitted
//// cubic Beziers. Cubic approximations are checked by sampling the true normal
//// extrusion of the source curve and measuring its distance to the proposed
//// offset. If the error is too large, the source curve is split and each half
//// is offset recursively.
////
//// Subpath and path offsets first normalize the source, split it into stalled
//// and not-stalled pieces, fit the offset pieces, heal their boundaries, add
//// joins, and cull adjacent reversal loops. A trimmed single offset then nodes
//// that walk with its final refined zero-offset source. For each closed source
//// subpath, the arrangement dual floods the signed source-side faces and
//// removes offside offset occurrences. A second arrangement classifies the
//// remaining offset edges by their measured and expected winding pairs,
//// removes winding mismatches, applies forced parity-capacity reductions,
//// and reconstructs the survivors in source order.
////
//// Band construction shares source refinement between its two sides. Each
//// side is first noded against the zero-offset source and trimmed in source
//// order, retaining submerged runs that contain no reversed preimage. The two
//// surviving sides are then noded together; winding mismatches and forced
//// parity-capacity reductions are applied before the final band walks are
//// reconstructed.
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
import svg_path/overlaps
import svg_path/point as point_helpers
import svg_path/trig

const default_tolerance = 0.01

const maximum_refinement_generation = 5

const default_max_depth = maximum_refinement_generation

const default_samples = 10

const default_trimming_samples = 5

const default_miter_limit = 4.0

const small_unit_division_tolerance = 0.000001

const point_tolerance = 0.000000001

const point_parameter_tolerance = 0.000000001

const direction_determinant_tolerance = 0.000000001

const angle_tolerance_degrees = 0.000000001

const arrangement_tolerance = 0.000000002

const submerged_side_sampling_distance = 0.00000005

const band_orientation_side_sampling_distance = 0.0001

const curvature_parameter_tolerance = 0.000001

// Curvature has inverse-length units; keep this distinct from the parameter
// tolerance even while both use the same numeric default.
const curvature_value_tolerance = 0.000001

// Radius values have length units and must not reuse parameter-space or
// inverse-length curvature tolerances.
const curvature_radius_tolerance = 0.000001

const default_tangent_heal_angle_degrees = 2.0

const join_free_tangent_alignment_angle_degrees = 0.001

const tangent_heal_agreement_angle_degrees = 2.0

const source_tangent_colinearization_angle_degrees = 2.0

const reversal_tangent_gap_degrees = 1.0

const reversal_fit_tangent_nudge_degrees = 0.5

const reversal_fit_line_aperture_degrees = 0.02

const reversal_fit_min_handle_chord_ratio = 0.1

const reversal_fit_max_handle_chord_ratio = 0.9

const tangent_turn_curvature_epsilon = 0.000000001

const tangent_turn_angle_epsilon = 0.001

const stable_tangent_assertion_diameter = 0.01

const default_stalled_offset_diameter = 0.01

const adjacent_loop_endpoint_parameter_tolerance = 0.0001

/// Errors returned by offset helpers.
pub type Error {
  /// An underlying path operation failed.
  PathError(svg_path.Error)

  /// Arrangement construction failed while noding offset geometry.
  ArrangementGraphError(arrangement_graph.Error)

  /// Forced parity pruning could not determine a unique feasible assignment.
  ForcedParityPruningError(arrangement_graph.ForcedParityError)

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

  /// The tangent-healing angle must be finite and non-negative.
  InvalidTangentHealAngleDegrees(angle: Float)

  /// Stroke width must be finite and greater than zero.
  InvalidStrokeWidth(width: Float)

  /// Band payloads used for inside classification must be closed.
  BandSubpathNotClosed

  /// A segment tangent was too small to define a stable normal direction.
  DegenerateTangent(t: Float)

  /// Refinement could not produce an offset within the requested tolerance.
  MaxDepthReached(error: Float)

  /// A calculation produced a non-finite coordinate.
  NonFinite

  /// Arrangement segment-image counts did not match offset segment counts.
  InternalSegmentImageCountMismatch

  /// A source segment's arrangement image contained no graph edges.
  InternalEmptySegmentImage(segment_index: Int)

  /// An arrangement edge had no source-image record.
  InternalMissingEdgeImage(edge_id: Int)

  /// An arrangement source image referenced no indexed offset segment.
  InternalMissingIndexedSegment(segment_index: Int)

  /// An indexed offset segment had no winding-side opinion.
  InternalMissingWindingOpinion(segment_index: Int)

  /// Source-order reconstruction did not consume an assigned edge capacity.
  InternalSurvivorCapacityMismatch(edge_id: Int, remaining: Int)

  /// Forced-parity band reconstruction produced an open chain.
  InternalForcedParityOpenChain(start_vertex: Int, end_vertex: Int)

  /// Cusp trimming reconstructed the wrong number of survivor subpaths.
  ///
  /// The historical `IToK` constructor name is retained for compatibility.
  InternalIToKSubpathCount(actual: Int)

  /// Closed cusp-trimming input reconstructed as an open subpath.
  /// The historical `IToK` constructor name is retained for compatibility.
  InternalIToKExpectedClosedSubpath

  /// Open cusp-trimming input did not preserve its endpoint vertices.
  /// The historical `IToK` constructor name is retained for compatibility.
  InternalIToKEndpointMismatch(
    expected_start: Int,
    actual_start: Int,
    expected_end: Int,
    actual_end: Int,
  )

  /// Cusp reconstruction lost an edge's arrangement-split provenance.
  /// The historical `IToK`/`J` constructor name is retained for compatibility.
  InternalIToKMissingJPreimage(edge_id: Int)
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
  ClosedSubpathBand(exterior: svg_path.Subpath, interior: svg_path.Subpath)
}

/// Final trimming applied to a single offset after optional offside trimming.
///
/// `CuspTrimming` applies the side-local cusp trimmer independently to every
/// surviving offset walk. It can delete a walk, but a retained walk must keep
/// its original open/closed topology and, when open, its original endpoints.
///
/// `InBandTrimming` constructs the current zero-to-offset band arrangement and
/// performs the general winding and parity-capacity trim. It subsumes cusp
/// trimming and may return any number of reconstructed survivor subpaths.
///
/// `NoTrimming` returns the geometry surviving optional offside trimming.
pub type SingleOffsetFinalTrimming {
  CuspTrimming
  InBandTrimming
  NoTrimming
}

/// Trimming controls for a single offset.
///
/// `offside` enables face-contamination trimming for each closed source
/// subpath independently. One closed input offset walk may become zero, one,
/// or several closed survivor walks. Open source subpaths pass through this
/// stage unchanged.
///
/// `final_trimming` selects the terminal operation. In-band trimming includes
/// cusp removal and is the default, more comprehensive operation.
pub type SingleOffsetTrimming {
  SingleOffsetTrimming(offside: Bool, final_trimming: SingleOffsetFinalTrimming)
}

/// Trimming controls for a band.
///
/// `inner_cusps` and `outer_cusps` independently enable side-local cusp
/// trimming for the caller-designated inner and outer offsets. The names keep
/// those caller-designated roles even when `inner_offset > outer_offset`.
/// `in_band` enables the final joint submerged trimming pass.
pub type BandTrimming {
  BandTrimming(inner_cusps: Bool, outer_cusps: Bool, in_band: Bool)
}

/// Cubic fitting controls used by the recursive offset builders.
///
/// `tolerance` bounds the sampled geometric error of a fitted offset curve,
/// `samples` controls the number of check samples, and `max_depth` limits
/// recursive subdivision. The offset pipeline additionally caps refinement at
/// five generations, so values above five do not increase refinement depth.
pub type FittingOptions {
  FittingOptions(tolerance: Float, samples: Int, max_depth: Int)
}

/// Options for offset construction.
///
/// `fitting` controls offset approximation. `distance_options` controls
/// projection and root-finding used while pruning. `stalled_offset_diameter`
/// decides when the stalled-run builder treats an offset piece as too small to
/// keep as an ordinary independently fitted segment.
/// `tangent_heal_angle_degrees` is the maximum tangent direction mismatch, in
/// degrees, allowed by post-healing continuity checks at stable smooth
/// boundaries. `single_offset_trimming` and `band_trimming` select the public
/// trimming pipelines.
pub type Options {
  Options(
    fitting: FittingOptions,
    distance_options: svg_path.DistanceOptions,
    stalled_offset_diameter: Float,
    tangent_heal_angle_degrees: Float,
    join: Join,
    single_offset_trimming: SingleOffsetTrimming,
    band_trimming: BandTrimming,
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

@internal
pub type CStalledSegment {
  CStalledSegment(
    prepared: APreparedSegment,
    prepared_from: Float,
    prepared_to: Float,
    segment: svg_path.Segment,
  )
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
    start_boundary: BoundaryKind,
    end_boundary: BoundaryKind,
    start_is_reversal: Bool,
    end_is_reversal: Bool,
  )
  OffsetSourceTraceStalled(source_segment_index: Int, segment: svg_path.Segment)
}

/// Diagnostic summary of one production inner/outer source correspondence.
@internal
pub type SynchronizedOffsetTraceCorrespondence {
  SynchronizedOffsetTraceCorrespondence(
    portion_index: Int,
    correspondence_index: Int,
    inner_stalled: Bool,
    outer_stalled: Bool,
    inner_leaves: List(SynchronizedOffsetTraceLeaf),
    outer_leaves: List(SynchronizedOffsetTraceLeaf),
  )
}

/// One terminal source interval used to construct a synchronized offset side.
@internal
pub type SynchronizedOffsetTraceLeaf {
  SynchronizedOffsetTraceLeaf(
    source_segment_index: Int,
    prepared_from: Float,
    prepared_to: Float,
    generation: Int,
  )
}

/// One matched pair of joins between synchronized inner and outer portions.
@internal
pub type SynchronizedOffsetTraceJoin {
  SynchronizedOffsetTraceJoin(
    after_portion_index: Int,
    inner_segments: List(svg_path.Segment),
    outer_segments: List(svg_path.Segment),
    inner_reversed: Bool,
    outer_reversed: Bool,
  )
}

/// The healed offset geometry on both sides of one source correspondence.
@internal
pub type SynchronizedOffsetTraceArea {
  SynchronizedOffsetTraceArea(
    portion_index: Int,
    correspondence_index: Int,
    inner_segments: List(svg_path.Segment),
    outer_segments: List(svg_path.Segment),
  )
}

/// One offset-image edge in the offside-trimming arrangement, together with
/// its source-face contamination and final survivor status.
@internal
pub type SingleOffsetContaminationTraceEdge {
  SingleOffsetContaminationTraceEdge(
    id: Int,
    segment: svg_path.Segment,
    start_vertex: Int,
    end_vertex: Int,
    preimage_from: Float,
    preimage_to: Float,
    offside: Bool,
    survives: Bool,
  )
}

@internal
pub type BandArrangementTraceEdge {
  BandArrangementTraceEdge(id: Int, segment: svg_path.Segment, submerged: Bool)
}

@internal
pub type CuspTrimmingArrangementTraceEdge {
  CuspTrimmingArrangementTraceEdge(
    side_index: Int,
    id: Int,
    segment: svg_path.Segment,
    offset_image: Bool,
    submerged: Bool,
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

/// Arrangement data retained while offset edges are classified and reduced.
///
/// Removing edges invalidates an `ArrangementGraph`'s cyclic orders, which
/// this trimming phase does not use.
type OffsetTrimGraph {
  OffsetTrimGraph(
    vertices: List(arrangement_graph.ArrangementVertex),
    edges: List(arrangement_graph.ArrangementEdge),
    /// `None` means capacities have not yet been reduced. `Some` contains the
    /// exact undirected capacities reconstruction must consume.
    edge_capacities: Option(List(#(Int, Int))),
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
    culled: ICulledOffsetSubpath,
    correspondences: List(OffsetCorrespondence),
    portions: List(SynchronizedHealedPortion),
    join_correspondences: List(OffsetJoinCorrespondence),
  )
}

/// The two consistently tracked sides of a synchronized band construction.
///
/// `Inner` and `Outer` record the caller's ordered band roles. They do not
/// require `inner_offset < outer_offset`; exchanging the two roles reverses the
/// orientation of the resulting band.
type BandSide {
  Inner
  Outer
}

/// One immutable segment of an assembled untrimmed offset side.
///
/// Healed offset pieces and joins first meet at this stage. Later geometric
/// cleanup retains this payload as provenance rather than rewriting it.
type HPreimageSource {
  HealedPreimage(GHealedOffsetSegment)
  JoinPreimage(
    after_portion_index: Int,
    side: BandSide,
    join_segment_index: Int,
    reversed: Bool,
  )
}

type HPreimageSegment {
  HPreimageSegment(segment: svg_path.Segment, source: HPreimageSource)
}

type HPreimageSubpath {
  HPreimageSubpath(
    segments: List(HPreimageSegment),
    closed: Bool,
    side: BandSide,
  )
}

// Trimming-stage data flow
//
//   H: healed offset pieces and joins with immutable construction provenance
//   I: H geometry after adjacent-loop culling; a piece may represent an
//      interval of its immutable H preimage
//   Traced: the common interchange representation between optional trimmers
//   ArrangementSplit: an I/Traced walk split into source order by arrangement
//                     vertices
//   CuspTrimmed: the optional single survivor of side-local cusp trimming
//
// Offside trimming maps one I walk to zero or more Traced walks. Cusp trimming
// temporarily lowers one Traced walk to I, splits it by an arrangement, and
// raises its optional CuspTrimmed survivor back to Traced. Final in-band
// trimming consumes Traced geometry and returns ordinary Subpaths; no later
// stage needs construction provenance.

/// One post-healing segment after local loop culling.
///
/// `preimage` remains immutable even when `segment` is shortened.
/// `segment` is the current geometry representing the ordered parameter
/// interval `preimage_from..preimage_to` of `preimage.segment`.
type ICulledOffsetSegment {
  ICulledOffsetSegment(
    segment: svg_path.Segment,
    preimage: HPreimageSegment,
    preimage_from: Float,
    preimage_to: Float,
  )
}

type ICulledOffsetSubpath {
  ICulledOffsetSubpath(
    segments: List(ICulledOffsetSegment),
    closed: Bool,
    side: BandSide,
  )
}

/// A trimming-stage-independent offset segment.
///
/// This is the common segment representation accepted and returned by optional
/// trimming stages. `segment` is the current surviving geometry. `preimage`
/// identifies its immutable H-stage construction source, and the ordered
/// `preimage_from..preimage_to` interval identifies the represented portion of
/// `preimage.segment`. Arrangement noding may narrow that interval but must not
/// replace its coordinate system.
///
/// `reversed` classifies the represented preimage geometry relative to its
/// E-source. It is construction provenance, not the orientation of an
/// arrangement edge; reversing an arrangement edge does not toggle it.
type TracedOffsetSegment {
  TracedOffsetSegment(
    segment: svg_path.Segment,
    preimage: HPreimageSegment,
    preimage_from: Float,
    preimage_to: Float,
    reversed: Bool,
  )
}

/// One current offset walk with segment-level construction provenance.
///
/// Segments are stored in the current source traversal order and must form the
/// walk described by `closed`. `side` retains the caller-designated Inner or
/// Outer role. `source_subpath_index` identifies the prepared source subpath
/// and its zero-source geometry; it remains unchanged if trimming splits one
/// input walk into several survivor walks.
type TracedOffsetSubpath {
  TracedOffsetSubpath(
    segments: List(TracedOffsetSegment),
    closed: Bool,
    side: BandSide,
    source_subpath_index: Int,
  )
}

/// One I-segment section in original traversal order after arrangement noding.
///
/// `segment` is oriented in the I walk's traversal direction. `edge_id` and
/// the vertex ids identify its arrangement image. `preimage_from..preimage_to`
/// is expressed directly in the immutable H preimage's parameter space, not
/// in the immediate I segment's local parameter space. `deletion_candidate`
/// records the current trimming classification and may later be cleared when
/// a submerged run is rescued.
type ArrangementSplitTracedSegment {
  ArrangementSplitTracedSegment(
    segment: svg_path.Segment,
    preimage: ICulledOffsetSegment,
    preimage_from: Float,
    preimage_to: Float,
    edge_id: Int,
    start_vertex: Int,
    end_vertex: Int,
    reversed: Bool,
    deletion_candidate: Bool,
  )
}

type ArrangementSplitTracedSubpath {
  ArrangementSplitTracedSubpath(
    segments: List(ArrangementSplitTracedSegment),
    closed: Bool,
    side: BandSide,
  )
}

/// One partial source-ordered walk considered by offside reconstruction.
type OffsideClosedWalkState {
  OffsideClosedWalkState(
    first_start_vertex: Int,
    end_vertex: Int,
    last_index: Int,
    retained_span: Float,
    skipped_runs: Int,
    indices_reversed: List(Int),
    segments_reversed: List(ArrangementSplitTracedSegment),
  )
}

/// One side-local survivor after winding-run rescue and parity reduction.
///
/// A cusp-trimmed result is deliberately more restrictive than an offside
/// result: cusp trimming requires either no survivor or exactly one survivor
/// with the input walk's open/closed topology and, for an open walk, its
/// original endpoint vertices.
type CuspTrimmedSegment {
  CuspTrimmedSegment(
    segment: svg_path.Segment,
    arrangement_preimage: ArrangementSplitTracedSegment,
  )
}

type CuspTrimmedSubpath {
  CuspTrimmedSubpath(segments: List(CuspTrimmedSegment), closed: Bool)
}

fn traced_subpath_from_i(
  subpath: ICulledOffsetSubpath,
  source_subpath_index: Int,
) -> TracedOffsetSubpath {
  let ICulledOffsetSubpath(segments:, closed:, side:) = subpath
  TracedOffsetSubpath(
    segments: list.map(segments, fn(segment) {
      TracedOffsetSegment(
        segment: segment.segment,
        preimage: segment.preimage,
        preimage_from: segment.preimage_from,
        preimage_to: segment.preimage_to,
        reversed: h_preimage_is_reversed(segment.preimage),
      )
    }),
    closed:,
    side:,
    source_subpath_index:,
  )
}

/// Raise an offside survivor chain into the common traced representation.
///
/// Every survivor edge must carry the arrangement-split preimage installed when
/// the original I walk was split by the arrangement. This preserves provenance
/// and the H-parameter interval through offside reconstruction.
fn traced_subpath_from_survivor_chain(
  chain: SurvivorChain,
  side: BandSide,
  source_subpath_index: Int,
) -> Result(TracedOffsetSubpath, Error) {
  use segments <- result.try(
    chain.edges
    |> list.map(fn(edge) {
      use split <- result.try(
        edge.arrangement_preimage
        |> option.to_result(InternalMissingIndexedSegment(edge.edge_id)),
      )
      Ok(TracedOffsetSegment(
        segment: edge.segment,
        preimage: split.preimage.preimage,
        preimage_from: split.preimage_from,
        preimage_to: split.preimage_to,
        reversed: split.reversed,
      ))
    })
    |> result.all,
  )
  Ok(TracedOffsetSubpath(
    segments:,
    closed: chain.closed,
    side:,
    source_subpath_index:,
  ))
}

/// Materialize the current traced walk as ordinary SVG path geometry.
///
/// This is the terminal boundary at which trimming provenance may be discarded.
fn traced_subpath_geometry(
  traced: TracedOffsetSubpath,
  tolerance: Float,
) -> Result(svg_path.Subpath, Error) {
  subpath_from_synchronized_segments(
    list.map(traced.segments, fn(segment) { segment.segment }),
    closed: traced.closed,
    tolerance:,
  )
}

/// Lower a traced walk to the structural input expected by the cusp trimmer.
/// This does not restore older I geometry: the traced segment's current
/// geometry and current H-parameter interval remain authoritative.
fn i_subpath_from_traced(traced: TracedOffsetSubpath) -> ICulledOffsetSubpath {
  ICulledOffsetSubpath(
    segments: list.map(traced.segments, fn(segment) {
      ICulledOffsetSegment(
        segment: segment.segment,
        preimage: segment.preimage,
        preimage_from: segment.preimage_from,
        preimage_to: segment.preimage_to,
      )
    }),
    closed: traced.closed,
    side: traced.side,
  )
}

/// Raise the unique cusp-trimmed survivor into the common traced representation.
/// Its arrangement-split preimage supplies the narrowed H-parameter interval
/// and REVERSED classification established before parity reconstruction.
fn traced_subpath_from_cusp_trimmed(
  subpath: CuspTrimmedSubpath,
  source_subpath_index: Int,
  side: BandSide,
) -> TracedOffsetSubpath {
  let CuspTrimmedSubpath(segments:, closed:) = subpath
  TracedOffsetSubpath(
    segments: list.map(segments, fn(segment) {
      let CuspTrimmedSegment(segment: geometry, arrangement_preimage:) = segment
      let ArrangementSplitTracedSegment(
        preimage: i_segment,
        preimage_from:,
        preimage_to:,
        reversed:,
        ..,
      ) = arrangement_preimage
      TracedOffsetSegment(
        segment: geometry,
        preimage: i_segment.preimage,
        preimage_from:,
        preimage_to:,
        reversed:,
      )
    }),
    closed:,
    side:,
    source_subpath_index:,
  )
}

/// Apply side-local cusp trimming to one traced walk.
///
/// `None` means that the walk was removed completely. `Some` is guaranteed by
/// the cusp-trimming contract to preserve the input topology and open endpoints.
fn cusp_trim_traced_subpath(
  traced: TracedOffsetSubpath,
  zero_source: svg_path.Subpath,
  offset: Float,
  options: Options,
) -> Result(Option(TracedOffsetSubpath), Error) {
  use trimmed <- result.try(cusp_trim_i_subpath(
    i_subpath_from_traced(traced),
    zero_source,
    offset,
    options,
  ))
  Ok(
    option.map(trimmed, fn(subpath) {
      traced_subpath_from_cusp_trimmed(
        subpath,
        traced.source_subpath_index,
        traced.side,
      )
    }),
  )
}

type ArrangementSplitRun {
  ArrangementSplitRun(
    segments: List(ArrangementSplitTracedSegment),
    submerged: Bool,
  )
}

type OffsetDistances {
  OffsetDistances(inner: Float, outer: Float)
}

type BoundaryPair {
  BoundaryPair(inner: BoundaryKind, outer: BoundaryKind)
}

type SideStalledStatus {
  SideStalled
  SideNotStalled
}

type SynchronizedClassifiedSegment {
  SynchronizedClassifiedSegment(
    prepared: APreparedSegment,
    inner_status: SideStalledStatus,
    outer_status: SideStalledStatus,
    start_boundary: BoundaryPair,
    end_boundary: BoundaryPair,
  )
}

/// One source interval shared by the inner and outer offset constructions.
type SynchronizedSourceSegment {
  SynchronizedSourceSegment(
    prepared: APreparedSegment,
    prepared_from: Float,
    prepared_to: Float,
    segment: svg_path.Segment,
    inner_status: SideStalledStatus,
    outer_status: SideStalledStatus,
    start_boundary: BoundaryPair,
    end_boundary: BoundaryPair,
  )
}

/// The adaptive source partition used by one side of a correspondence.
///
/// A stalled side remains a leaf while the other side may form a refinement
/// tree beneath the same overall source interval.
type SynchronizedSideSource {
  RefinableSideSource(EJoinFreeSegment)
  StalledSideSource(List(CStalledSegment))
  SplitSideSource(left: SynchronizedSideSource, right: SynchronizedSideSource)
}

/// Source correspondence retained while constructing both sides of a band.
type OffsetCorrespondence {
  OffsetCorrespondence(
    portion_index: Int,
    correspondence_index: Int,
    sources: List(SynchronizedSourceSegment),
    inner: SynchronizedSideSource,
    outer: SynchronizedSideSource,
    inner_offset_count: Int,
    outer_offset_count: Int,
  )
}

type OffsetJoinCorrespondence {
  OffsetJoinCorrespondence(
    after_portion_index: Int,
    inner: List(svg_path.Segment),
    outer: List(svg_path.Segment),
    inner_reversed: Bool,
    outer_reversed: Bool,
    inner_start: svg_path.Point,
    inner_end: svg_path.Point,
    outer_start: svg_path.Point,
    outer_end: svg_path.Point,
  )
}

type SynchronizedHealedPortion {
  SynchronizedHealedPortion(
    portion_index: Int,
    inner: List(GHealedOffsetSegment),
    outer: List(GHealedOffsetSegment),
  )
}

type SynchronizedOffsetSegmentsBuild {
  SynchronizedOffsetSegmentsBuild(
    inner_offsets: List(GHealedOffsetSegment),
    outer_offsets: List(GHealedOffsetSegment),
    correspondences: List(OffsetCorrespondence),
    portions: List(SynchronizedHealedPortion),
  )
}

type SynchronizedUntrimmedBuild {
  SynchronizedUntrimmedBuild(
    inner: svg_path.Subpath,
    outer: svg_path.Subpath,
    inner_culled: ICulledOffsetSubpath,
    outer_culled: ICulledOffsetSubpath,
    correspondences: List(OffsetCorrespondence),
    portions: List(SynchronizedHealedPortion),
    join_correspondences: List(OffsetJoinCorrespondence),
  )
}

type OffsetAttempt {
  OffsetAccepted(FUnhealedOffsetSegment)
  OffsetNeedsRefinement(divergence: Float)
}

type SynchronizedUnhealedResult {
  SynchronizedUnhealedResult(
    inner_offsets: List(FUnhealedOffsetSegment),
    outer_offsets: List(FUnhealedOffsetSegment),
    inner_source: SynchronizedSideSource,
    outer_source: SynchronizedSideSource,
  )
}

type SynchronizedPortionUnhealedBuild {
  SynchronizedPortionUnhealedBuild(
    inner_offsets: List(FUnhealedOffsetSegment),
    outer_offsets: List(FUnhealedOffsetSegment),
    correspondences: List(OffsetCorrespondence),
  )
}

type IndexedOffsetSegment {
  IndexedOffsetSegment(
    group: OffsetArrangementSegmentGroup,
    subpath_index: Int,
    segment: svg_path.Segment,
    winding_opinion: Option(WindingSideOpinion),
  )
}

type WindingSideOpinion {
  WindingSideOpinion(left: Int, right: Int)
}

type SurvivorEdge {
  SurvivorEdge(
    edge_id: Int,
    reversed: Bool,
    start_vertex: Int,
    end_vertex: Int,
    segment: svg_path.Segment,
    arrangement_preimage: Option(ArrangementSplitTracedSegment),
  )
}

type SurvivorChain {
  SurvivorChain(
    start_vertex: Int,
    end_vertex: Int,
    edges: List(SurvivorEdge),
    closed: Bool,
  )
}

type AvailableEdgeCapacity {
  AvailableEdgeCapacity(edge_id: Int, remaining: Int)
}

type JoinFreePortion {
  JoinFreePortion(index: Int, subpath: svg_path.Subpath, closed: Bool)
}

@internal
pub type BoundaryKind {
  Ordinary
  ReversalBoundary(left_normal_curvature: Option(Float))
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
    distance_options: default_distance_options(),
    stalled_offset_diameter: default_stalled_offset_diameter,
    tangent_heal_angle_degrees: default_tangent_heal_angle_degrees,
    join: Miter(default_miter_limit),
    single_offset_trimming: SingleOffsetTrimming(
      offside: True,
      final_trimming: InBandTrimming,
    ),
    band_trimming: BandTrimming(
      inner_cusps: True,
      outer_cusps: True,
      in_band: True,
    ),
  )
}

fn refinement_depth(options: Options) -> Int {
  int.min(options.fitting.max_depth, maximum_refinement_generation)
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

fn internal_band_winding_function(
  bands: List(OneSubpathBand),
) -> Result(fn(svg_path.Point) -> Result(Int, Error), Error) {
  use semantic_paths <- result.try(
    one_subpath_band_semantic_paths(bands, paths: []),
  )
  let path =
    svg_path.Path(
      semantic_paths
      |> list.flat_map(svg_path.path_subpaths),
    )
  Ok(fn(point) {
    use winding <- result.try(
      svg_path.path_winding(point, within: path) |> result.map_error(PathError),
    )
    case winding {
      svg_path.Winding(value) -> Ok(value)
      svg_path.BoundaryWinding ->
        Error(PathError(svg_path.InconsistentContainment))
    }
  })
}

fn offside_trimmed_single_offset_winding_function(
  builds: List(SingleOffsetUntrimmedBuild),
  trimmed: List(TracedOffsetSubpath),
  offset: Float,
  bands: List(OneSubpathBand),
  tolerance: Float,
) -> Result(fn(svg_path.Point) -> Result(Int, Error), Error) {
  use subpaths <- result.try(
    offside_trimmed_single_offset_winding_subpaths(
      builds,
      trimmed,
      offset,
      bands,
      tolerance,
      source_subpath_index: 0,
      collected: [],
    ),
  )
  let path = svg_path.Path(subpaths:)
  Ok(fn(point) {
    use winding <- result.try(
      svg_path.path_winding(point, within: path) |> result.map_error(PathError),
    )
    case winding {
      svg_path.Winding(value) -> Ok(value)
      svg_path.BoundaryWinding ->
        Error(PathError(svg_path.InconsistentContainment))
    }
  })
}

fn offside_trimmed_single_offset_winding_subpaths(
  builds: List(SingleOffsetUntrimmedBuild),
  trimmed: List(TracedOffsetSubpath),
  offset: Float,
  bands: List(OneSubpathBand),
  tolerance: Float,
  source_subpath_index source_subpath_index: Int,
  collected collected: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case builds, bands {
    [], _ -> Ok(list.reverse(collected))
    [build, ..rest], [band, ..remaining_bands] -> {
      let offset_subpaths =
        trimmed
        |> list.filter(fn(item) {
          item.source_subpath_index == source_subpath_index
        })
        |> list.map(fn(item) { traced_subpath_geometry(item, tolerance) })
      use offset_subpaths <- result.try(result.all(offset_subpaths))
      let semantic_subpaths = case svg_path.subpath_is_closed(build.subpath) {
        False ->
          case band {
            OpenSubpathBand(outline) -> [outline]
            ClosedSubpathBand(exterior, interior) -> [
              exterior,
              svg_path.subpath_reverse(interior),
            ]
          }
        True ->
          case offset_subpaths, offset >=. 0.0 {
            [], _ -> []
            [_, ..], True ->
              list.append(offset_subpaths, [
                svg_path.subpath_reverse(build.zero_source),
              ])
            [_, ..], False -> [
              build.zero_source,
              ..list.map(offset_subpaths, svg_path.subpath_reverse)
            ]
          }
      }
      offside_trimmed_single_offset_winding_subpaths(
        rest,
        trimmed,
        offset,
        remaining_bands,
        tolerance,
        source_subpath_index: source_subpath_index + 1,
        collected: list.append(list.reverse(semantic_subpaths), collected),
      )
    }
    [_, ..], [] -> Ok(list.reverse(collected))
  }
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

/// Extract and filter band loops using the band inside predicate.
@internal
pub fn internal_topological_band_loops(
  untrimmed: List(svg_path.Subpath),
  bands bands: List(OneSubpathBand),
  options options: Options,
) -> Result(List(svg_path.Subpath), Error) {
  use winding <- result.try(internal_band_winding_function(bands))
  trim_band_arrangement(
    untrimmed,
    winding:,
    winding_opinions: band_subpath_winding_opinions(bands),
    options:,
  )
}

fn topological_band_path_with_opinions(
  untrimmed: List(svg_path.Subpath),
  bands: List(OneSubpathBand),
  winding_opinions: List(WindingSideOpinion),
  options: Options,
) -> Result(svg_path.Path, Error) {
  use winding <- result.try(internal_band_winding_function(bands))
  use loops <- result.try(trim_band_arrangement(
    untrimmed,
    winding:,
    winding_opinions:,
    options:,
  ))
  orient_band_path(svg_path.Path(subpaths: loops), winding)
}

/// Extract, filter, and orient band loops as a path.
fn topological_band_path(
  untrimmed: List(svg_path.Subpath),
  bands bands: List(OneSubpathBand),
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use loops <- result.try(internal_topological_band_loops(
    untrimmed,
    bands:,
    options:,
  ))
  use winding <- result.try(internal_band_winding_function(bands))
  orient_band_path(svg_path.Path(subpaths: loops), winding)
}

fn trim_single_offset_builds(
  builds: List(SingleOffsetUntrimmedBuild),
  offset: Float,
  bands bands: List(OneSubpathBand),
  options options: Options,
) -> Result(svg_path.Path, Error) {
  let SingleOffsetTrimming(offside:, final_trimming:) =
    options.single_offset_trimming
  use subpaths <- result.try(final_single_offset_subpaths(
    builds,
    offset,
    bands:,
    options:,
    offside:,
    final_trimming:,
  ))
  let subpaths =
    subpaths
    |> list.filter(fn(subpath) {
      !list.is_empty(svg_path.subpath_segments(subpath))
    })
  use oriented <- result.try(orient_outline_path(svg_path.Path(subpaths:)))
  Ok(oriented)
}

/// Build the exact closed band used to classify one single-sided offset.
@internal
pub fn internal_single_offset_band_candidate(
  source: svg_path.Subpath,
  offset offset: Float,
  options options: Options,
) -> Result(OneSubpathBand, Error) {
  use _ <- result.try(validate_options(options))
  use normalized <- result.try(normalize_source_subpath(source, options))
  use build <- result.try(build_single_offset_untrimmed(
    normalized,
    offset:,
    options:,
  ))
  band_from_sides(build.zero_source, 0.0, build.subpath, offset)
}

/// Return arrangement-split offset edges with their offside classification
/// before contamination pruning reconstructs survivor walks. This is for debug
/// fixtures only.
@internal
pub fn internal_path_single_offset_contamination_arrangement_trace(
  source source: svg_path.Path,
  offset offset: Float,
  options options: Options,
) -> Result(List(SingleOffsetContaminationTraceEdge), Error) {
  use _ <- result.try(validate_options(options))
  use normalized <- result.try(normalize_source_path(source, options))
  use builds <- result.try(
    single_offset_untrimmed_path_builds(
      svg_path.path_subpaths(normalized),
      offset,
      options,
      converted: [],
    ),
  )
  let offset_count =
    builds
    |> list.fold(0, fn(count, build) {
      count + list.length(svg_path.subpath_segments(build.subpath))
    })
  let untrimmed = list.map(builds, fn(build) { build.subpath })
  let zero_source_segments =
    builds
    |> list.flat_map(fn(build) { svg_path.subpath_segments(build.zero_source) })
  use arrangement <- result.try(single_offset_segment_arrangement(
    untrimmed,
    zero_source_segments:,
    offset:,
  ))
  use split <- result.try(take_segment_images(
    arrangement.segment_images,
    offset_count,
  ))
  let #(offset_images, zero_images) = split
  use dual <- result.try(
    arrangement_graph.dual(arrangement.graph)
    |> result.map_error(ArrangementGraphError),
  )
  contamination_arrangement_trace_builds(
    builds,
    offset_images,
    zero_images,
    arrangement,
    dual,
    offset,
    traced: [],
  )
}

fn contamination_arrangement_trace_builds(
  builds: List(SingleOffsetUntrimmedBuild),
  offset_images: List(arrangement_graph.ArrangementSourceSegmentImage),
  zero_images: List(arrangement_graph.ArrangementSourceSegmentImage),
  arrangement: OffsetArrangementBuild,
  dual: arrangement_graph.DualArrangementGraph,
  offset: Float,
  traced traced: List(SingleOffsetContaminationTraceEdge),
) -> Result(List(SingleOffsetContaminationTraceEdge), Error) {
  case builds {
    [] -> Ok(list.reverse(traced))
    [build, ..rest] -> {
      use offset_span <- result.try(take_segment_images(
        offset_images,
        list.length(svg_path.subpath_segments(build.subpath)),
      ))
      use zero_span <- result.try(take_segment_images(
        zero_images,
        list.length(svg_path.subpath_segments(build.zero_source)),
      ))
      let #(build_offset_images, remaining_offset_images) = offset_span
      let #(build_zero_images, remaining_zero_images) = zero_span
      let barriers = segment_image_edge_ids(build_zero_images, ids: [])
      use seeds <- result.try(
        contamination_seed_faces(build_zero_images, dual, offset, seeded: []),
      )
      let contaminated = propagate_contaminated_faces(dual, barriers, seeds)
      use split <- result.try(arrangement_split_subpath_from_i_contamination(
        build.culled,
        build_offset_images,
        arrangement,
        dual,
        contaminated,
      ))
      use survivors <- result.try(
        case svg_path.subpath_is_closed(build.subpath) {
          True -> {
            let chains = offside_survivor_chains(split.segments)
            Ok(arrangement_split_segments_from_survivor_chains(chains))
          }
          False -> Ok(split.segments)
        },
      )
      let survivor_edge_ids =
        list.map(survivors, fn(segment) { segment.edge_id })
      let traced =
        split.segments
        |> list.fold(traced, fn(traced, segment) {
          [
            SingleOffsetContaminationTraceEdge(
              id: segment.edge_id,
              segment: segment.segment,
              start_vertex: segment.start_vertex,
              end_vertex: segment.end_vertex,
              preimage_from: segment.preimage_from,
              preimage_to: segment.preimage_to,
              offside: segment.deletion_candidate,
              survives: list.contains(survivor_edge_ids, segment.edge_id),
            ),
            ..traced
          ]
        })
      contamination_arrangement_trace_builds(
        rest,
        remaining_offset_images,
        remaining_zero_images,
        arrangement,
        dual,
        offset,
        traced:,
      )
    }
  }
}

fn unique_ints(values: List(Int), unique unique: List(Int)) -> List(Int) {
  case values {
    [] -> list.reverse(unique)
    [first, ..rest] ->
      case list.contains(unique, first) {
        True -> unique_ints(rest, unique:)
        False -> unique_ints(rest, unique: [first, ..unique])
      }
  }
}

/// Run the configurable single-offset trimming pipeline.
///
/// Small-loop culling has already produced one I walk per untrimmed build.
/// This function first enters Traced form, optionally replaces each closed I
/// walk with its offside survivor walks, and then selects exactly one terminal
/// operation: cusp-only trimming, general in-band trimming, or materialization
/// without further trimming. Cusp and in-band trimming are alternatives;
/// in-band trimming already performs the more general submerged removal.
fn final_single_offset_subpaths(
  builds: List(SingleOffsetUntrimmedBuild),
  offset: Float,
  bands bands: List(OneSubpathBand),
  options options: Options,
  offside offside: Bool,
  final_trimming final_trimming: SingleOffsetFinalTrimming,
) -> Result(List(svg_path.Subpath), Error) {
  let original_untrimmed = list.map(builds, fn(build) { build.subpath })
  let zero_source_segments =
    builds
    |> list.flat_map(fn(build) { svg_path.subpath_segments(build.zero_source) })
  use original_arrangement <- result.try(single_offset_segment_arrangement(
    original_untrimmed,
    zero_source_segments:,
    offset:,
  ))
  use offside_trimmed <- result.try(offside_trimmed_single_offset_subpaths(
    builds,
    original_arrangement,
    offset,
    options,
    enabled: offside,
  ))
  case final_trimming {
    CuspTrimming ->
      cusp_trimmed_single_offset_subpaths_result(
        offside_trimmed,
        builds,
        offset,
        options,
      )
    InBandTrimming ->
      submerged_trimmed_single_offset_subpaths(
        offside_trimmed,
        builds,
        original_arrangement,
        zero_source_segments,
        offset,
        bands,
        options,
        offside,
      )
    NoTrimming ->
      offside_trimmed
      |> list.map(fn(trimmed) {
        traced_subpath_geometry(trimmed, options.fitting.tolerance)
      })
      |> result.all
  }
}

/// Finish a single offset with the general in-band trimmer.
///
/// The input is the exact set of traced walks surviving offside trimming. When
/// offside trimming ran, both the winding path and arrangement are rebuilt
/// from that current geometry; classification is therefore never computed
/// against the obsolete pre-offside offset. This is a terminal operation and
/// returns ordinary Subpaths rather than TracedOffsetSubpaths.
fn submerged_trimmed_single_offset_subpaths(
  offside_trimmed: List(TracedOffsetSubpath),
  builds: List(SingleOffsetUntrimmedBuild),
  original_arrangement: OffsetArrangementBuild,
  zero_source_segments: List(svg_path.Segment),
  offset: Float,
  bands: List(OneSubpathBand),
  options: Options,
  offside: Bool,
) -> Result(List(svg_path.Subpath), Error) {
  use untrimmed <- result.try(
    offside_trimmed
    |> list.map(fn(trimmed) {
      traced_subpath_geometry(trimmed, options.fitting.tolerance)
    })
    |> result.all,
  )
  use winding <- result.try(case offside {
    True ->
      offside_trimmed_single_offset_winding_function(
        builds,
        offside_trimmed,
        offset,
        bands,
        options.fitting.tolerance,
      )
    False -> internal_band_winding_function(bands)
  })
  use arrangement <- result.try(case offside {
    False -> Ok(original_arrangement)
    True ->
      single_offset_segment_arrangement(
        untrimmed,
        zero_source_segments:,
        offset:,
      )
  })
  trim_single_offset_arrangement(arrangement, untrimmed, winding, options)
}

/// Finish a single offset using only side-local cusp trimming.
///
/// Each traced walk is processed independently and may survive once or be
/// deleted. Provenance remains available until all results are materialized.
fn cusp_trimmed_single_offset_subpaths_result(
  offside_trimmed: List(TracedOffsetSubpath),
  builds: List(SingleOffsetUntrimmedBuild),
  offset: Float,
  options: Options,
) -> Result(List(svg_path.Subpath), Error) {
  use traced <- result.try(
    cusp_trimmed_single_offset_subpaths(
      offside_trimmed,
      builds,
      offset,
      options,
      trimmed: [],
    ),
  )
  result.all(
    list.map(traced, fn(subpath) {
      traced_subpath_geometry(subpath, options.fitting.tolerance)
    }),
  )
}

fn cusp_trimmed_single_offset_subpaths(
  subpaths: List(TracedOffsetSubpath),
  builds: List(SingleOffsetUntrimmedBuild),
  offset: Float,
  options: Options,
  trimmed trimmed: List(TracedOffsetSubpath),
) -> Result(List(TracedOffsetSubpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(trimmed))
    [traced, ..rest] -> {
      use build <- result.try(
        list_at(builds, traced.source_subpath_index)
        |> result.map_error(fn(_) { InternalSegmentImageCountMismatch }),
      )
      use result <- result.try(cusp_trim_traced_subpath(
        traced,
        build.zero_source,
        offset,
        options,
      ))
      cusp_trimmed_single_offset_subpaths(
        rest,
        builds,
        offset,
        options,
        trimmed: case result {
          Some(subpath) -> [subpath, ..trimmed]
          None -> trimmed
        },
      )
    }
  }
}

fn list_at(values: List(a), index: Int) -> Result(a, Nil) {
  case values, index {
    [], _ -> Error(Nil)
    [first, ..], 0 -> Ok(first)
    [_, ..rest], index if index > 0 -> list_at(rest, index - 1)
    _, _ -> Error(Nil)
  }
}

/// Enter the common traced representation and optionally apply closed-subpath
/// offside trimming.
///
/// With trimming disabled there is one traced walk per build. With trimming
/// enabled, each closed build may yield zero or more closed traced walks, all
/// retaining the build's `source_subpath_index`; open builds remain one-to-one.
fn offside_trimmed_single_offset_subpaths(
  builds: List(SingleOffsetUntrimmedBuild),
  arrangement: OffsetArrangementBuild,
  offset: Float,
  options: Options,
  enabled enabled: Bool,
) -> Result(List(TracedOffsetSubpath), Error) {
  case enabled {
    False ->
      Ok(
        builds
        |> list.index_map(fn(build, index) {
          traced_subpath_from_i(build.culled, index)
        }),
      )
    True ->
      offside_trimmed_single_offset_subpaths_enabled(
        builds,
        arrangement,
        offset,
        options,
      )
  }
}

/// Construct the common arrangement and dual used by enabled offside trimming.
fn offside_trimmed_single_offset_subpaths_enabled(
  builds: List(SingleOffsetUntrimmedBuild),
  arrangement: OffsetArrangementBuild,
  offset: Float,
  options: Options,
) -> Result(List(TracedOffsetSubpath), Error) {
  let offset_count =
    builds
    |> list.fold(0, fn(count, build) {
      count + list.length(svg_path.subpath_segments(build.subpath))
    })
  use split <- result.try(take_segment_images(
    arrangement.segment_images,
    offset_count,
  ))
  let #(offset_images, zero_images) = split
  use dual <- result.try(
    arrangement_graph.dual(arrangement.graph)
    |> result.map_error(ArrangementGraphError),
  )
  offside_trimmed_single_offset_subpaths_loop(
    builds,
    offset_images,
    zero_images,
    arrangement,
    dual,
    offset,
    options,
    source_subpath_index: 0,
    trimmed: [],
  )
}

fn offside_trimmed_single_offset_subpaths_loop(
  builds: List(SingleOffsetUntrimmedBuild),
  offset_images: List(arrangement_graph.ArrangementSourceSegmentImage),
  zero_images: List(arrangement_graph.ArrangementSourceSegmentImage),
  arrangement: OffsetArrangementBuild,
  dual: arrangement_graph.DualArrangementGraph,
  offset: Float,
  options: Options,
  source_subpath_index source_subpath_index: Int,
  trimmed trimmed: List(TracedOffsetSubpath),
) -> Result(List(TracedOffsetSubpath), Error) {
  case builds {
    [] -> Ok(list.reverse(trimmed))
    [build, ..rest] -> {
      let offset_segment_count =
        list.length(svg_path.subpath_segments(build.subpath))
      let zero_segment_count =
        list.length(svg_path.subpath_segments(build.zero_source))
      use offset_span <- result.try(take_segment_images(
        offset_images,
        offset_segment_count,
      ))
      use zero_span <- result.try(take_segment_images(
        zero_images,
        zero_segment_count,
      ))
      let #(build_offset_images, remaining_offset_images) = offset_span
      let #(build_zero_images, remaining_zero_images) = zero_span
      use build_trimmed <- result.try(offside_trimmed_single_offset_subpath(
        build,
        build_offset_images,
        build_zero_images,
        arrangement,
        dual,
        offset,
        options,
        source_subpath_index,
      ))
      offside_trimmed_single_offset_subpaths_loop(
        rest,
        remaining_offset_images,
        remaining_zero_images,
        arrangement,
        dual,
        offset,
        options,
        source_subpath_index: source_subpath_index + 1,
        trimmed: list.append(list.reverse(build_trimmed), trimmed),
      )
    }
  }
}

fn offside_trimmed_single_offset_subpath(
  build: SingleOffsetUntrimmedBuild,
  offset_images: List(arrangement_graph.ArrangementSourceSegmentImage),
  zero_images: List(arrangement_graph.ArrangementSourceSegmentImage),
  arrangement: OffsetArrangementBuild,
  dual: arrangement_graph.DualArrangementGraph,
  offset: Float,
  _options: Options,
  source_subpath_index: Int,
) -> Result(List(TracedOffsetSubpath), Error) {
  case svg_path.subpath_is_closed(build.subpath) && offset != 0.0 {
    False ->
      Ok([
        traced_subpath_from_i(build.culled, source_subpath_index),
      ])
    True -> {
      let barriers = segment_image_edge_ids(zero_images, ids: [])
      use seeds <- result.try(
        contamination_seed_faces(zero_images, dual, offset, seeded: []),
      )
      let contaminated = propagate_contaminated_faces(dual, barriers, seeds)
      use split <- result.try(arrangement_split_subpath_from_i_contamination(
        build.culled,
        offset_images,
        arrangement,
        dual,
        contaminated,
      ))
      let chains = offside_survivor_chains(split.segments)
      chains
      |> list.try_map(fn(chain) {
        use traced <- result.try(traced_subpath_from_survivor_chain(
          chain,
          build.culled.side,
          source_subpath_index,
        ))
        Ok(traced)
      })
    }
  }
}

fn segment_image_edge_ids(
  images: List(arrangement_graph.ArrangementSourceSegmentImage),
  ids ids: List(Int),
) -> List(Int) {
  case images {
    [] -> ids
    [first, ..rest] -> {
      let arrangement_graph.ArrangementSourceSegmentImage(edges:, ..) = first
      let ids =
        edges
        |> list.fold(ids, fn(ids, image) {
          let arrangement_graph.ArrangementSegmentEdgeImage(edge_id:, ..) =
            image
          case list.contains(ids, edge_id) {
            True -> ids
            False -> [edge_id, ..ids]
          }
        })
      segment_image_edge_ids(rest, ids:)
    }
  }
}

fn contamination_seed_faces(
  images: List(arrangement_graph.ArrangementSourceSegmentImage),
  dual: arrangement_graph.DualArrangementGraph,
  offset: Float,
  seeded seeded: List(Int),
) -> Result(List(Int), Error) {
  case images {
    [] -> Ok(seeded)
    [first, ..rest] -> {
      let arrangement_graph.ArrangementSourceSegmentImage(edges:, ..) = first
      use seeded <- result.try(
        edges
        |> list.fold(Ok(seeded), fn(accumulator, image) {
          use seeded <- result.try(accumulator)
          let arrangement_graph.ArrangementSegmentEdgeImage(
            edge_id:,
            reversed:,
            ..,
          ) = image
          use faces <- result.try(dual_edge_faces(dual, edge_id))
          let source_left_face = case reversed {
            True -> faces.right_face
            False -> faces.left_face
          }
          let source_right_face = case reversed {
            True -> faces.left_face
            False -> faces.right_face
          }
          let face = case offset >. 0.0 {
            True -> source_left_face
            False -> source_right_face
          }
          Ok(case list.contains(seeded, face) {
            True -> seeded
            False -> [face, ..seeded]
          })
        }),
      )
      contamination_seed_faces(rest, dual, offset, seeded:)
    }
  }
}

fn propagate_contaminated_faces(
  dual: arrangement_graph.DualArrangementGraph,
  barriers: List(Int),
  contaminated: List(Int),
) -> List(Int) {
  let arrangement_graph.DualArrangementGraph(edge_faces:, ..) = dual
  let expanded =
    edge_faces
    |> list.fold(contaminated, fn(contaminated, edge) {
      case list.contains(barriers, edge.edge_id) {
        True -> contaminated
        False -> {
          let left_contaminated = list.contains(contaminated, edge.left_face)
          let right_contaminated = list.contains(contaminated, edge.right_face)
          case left_contaminated, right_contaminated {
            True, False -> [edge.right_face, ..contaminated]
            False, True -> [edge.left_face, ..contaminated]
            _, _ -> contaminated
          }
        }
      }
    })
    |> unique_ints(unique: [])
  case list.length(expanded) == list.length(contaminated) {
    True -> expanded
    False -> propagate_contaminated_faces(dual, barriers, expanded)
  }
}

fn dual_edge_faces(
  dual: arrangement_graph.DualArrangementGraph,
  edge_id: Int,
) -> Result(arrangement_graph.ArrangementEdgeFaces, Error) {
  let arrangement_graph.DualArrangementGraph(edge_faces:, ..) = dual
  edge_faces
  |> list.find(fn(edge) { edge.edge_id == edge_id })
  |> result.map_error(fn(_) {
    ArrangementGraphError(arrangement_graph.MissingEdge(edge_id))
  })
}

fn arrangement_split_subpath_from_i_contamination(
  subpath: ICulledOffsetSubpath,
  images: List(arrangement_graph.ArrangementSourceSegmentImage),
  build: OffsetArrangementBuild,
  dual: arrangement_graph.DualArrangementGraph,
  contaminated: List(Int),
) -> Result(ArrangementSplitTracedSubpath, Error) {
  let ICulledOffsetSubpath(segments:, closed:, side:) = subpath
  use split <- result.try(
    arrangement_split_segments_from_i_contamination_images(
      segments,
      images,
      build,
      dual,
      contaminated,
      split: [],
    ),
  )
  Ok(ArrangementSplitTracedSubpath(segments: split, closed:, side:))
}

fn arrangement_split_segments_from_i_contamination_images(
  segments: List(ICulledOffsetSegment),
  images: List(arrangement_graph.ArrangementSourceSegmentImage),
  build: OffsetArrangementBuild,
  dual: arrangement_graph.DualArrangementGraph,
  contaminated: List(Int),
  split split: List(ArrangementSplitTracedSegment),
) -> Result(List(ArrangementSplitTracedSegment), Error) {
  case segments, images {
    [], [] -> Ok(list.reverse(split))
    [segment, ..remaining_segments], [image, ..remaining_images] -> {
      use pieces <- result.try(
        arrangement_split_segments_from_i_contamination_image(
          segment,
          image,
          build,
          dual,
          contaminated,
          split: [],
        ),
      )
      arrangement_split_segments_from_i_contamination_images(
        remaining_segments,
        remaining_images,
        build,
        dual,
        contaminated,
        split: list.append(list.reverse(pieces), split),
      )
    }
    _, _ -> Error(InternalSegmentImageCountMismatch)
  }
}

fn arrangement_split_segments_from_i_contamination_image(
  source: ICulledOffsetSegment,
  source_image: arrangement_graph.ArrangementSourceSegmentImage,
  build: OffsetArrangementBuild,
  dual: arrangement_graph.DualArrangementGraph,
  contaminated: List(Int),
  split split: List(ArrangementSplitTracedSegment),
) -> Result(List(ArrangementSplitTracedSegment), Error) {
  let arrangement_graph.ArrangementSourceSegmentImage(edges:, ..) = source_image
  arrangement_split_segments_from_i_contamination_edges(
    source,
    edges,
    build,
    dual,
    contaminated,
    split:,
  )
}

fn arrangement_split_segments_from_i_contamination_edges(
  source: ICulledOffsetSegment,
  edges: List(arrangement_graph.ArrangementSegmentEdgeImage),
  build: OffsetArrangementBuild,
  dual: arrangement_graph.DualArrangementGraph,
  contaminated: List(Int),
  split split: List(ArrangementSplitTracedSegment),
) -> Result(List(ArrangementSplitTracedSegment), Error) {
  case edges {
    [] -> Ok(list.reverse(split))
    [image, ..rest] -> {
      let arrangement_graph.ArrangementSegmentEdgeImage(
        ta:,
        tb:,
        edge_id:,
        reversed: edge_reversed,
        ..,
      ) = image
      let OffsetArrangementBuild(
        graph: arrangement_graph.ArrangementGraph(edges: graph_edges, ..),
        ..,
      ) = build
      use edge <- result.try(
        arrangement_edge_by_id(graph_edges, edge_id)
        |> result.map_error(ArrangementGraphError),
      )
      use faces <- result.try(dual_edge_faces(dual, edge_id))
      let offside =
        !list.contains(contaminated, faces.left_face)
        && !list.contains(contaminated, faces.right_face)
      let #(segment, start_vertex, end_vertex) = case edge_reversed {
        True -> #(
          svg_path.segment_reverse(edge.segment),
          edge.end_vertex,
          edge.start_vertex,
        )
        False -> #(edge.segment, edge.start_vertex, edge.end_vertex)
      }
      let preimage_from =
        interval_parameter(source.preimage_from, source.preimage_to, ta)
      let preimage_to =
        interval_parameter(source.preimage_from, source.preimage_to, tb)
      arrangement_split_segments_from_i_contamination_edges(
        source,
        rest,
        build,
        dual,
        contaminated,
        split: [
          ArrangementSplitTracedSegment(
            segment:,
            preimage: source,
            preimage_from:,
            preimage_to:,
            edge_id:,
            start_vertex:,
            end_vertex:,
            reversed: h_preimage_is_reversed(source.preimage),
            deletion_candidate: offside,
          ),
          ..split
        ],
      )
    }
  }
}

/// Build the untrimmed closed stroke band for one source subpath.
@internal
pub fn internal_untrimmed_stroke_band(
  source: svg_path.Subpath,
  width width: Float,
  cap cap: Cap,
  options options: Options,
) -> Result(OneSubpathBand, Error) {
  use _ <- result.try(validate_stroke_width(width))
  untrimmed_stroke_band(source, width, cap, options)
}

fn default_distance_options() -> svg_path.DistanceOptions {
  svg_path.DistanceOptions(
    ..svg_path.default_distance_options(),
    samples: default_trimming_samples,
  )
}

/// Terminal general-purpose trimming for current single-offset geometry.
///
/// Only offset-image edges are eligible to survive. Winding-mismatched edges
/// receive zero initial capacity, forced parity reduction removes necessarily
/// dangling capacity, and reconstruction consumes the remaining capacities in
/// source order. Open input endpoints are preferred parity-one vertices while
/// attached, but complete deletion of an endpoint component is permitted.
fn trim_single_offset_arrangement(
  build: OffsetArrangementBuild,
  untrimmed: List(svg_path.Subpath),
  winding: fn(svg_path.Point) -> Result(Int, Error),
  options: Options,
) -> Result(List(svg_path.Subpath), Error) {
  let OffsetArrangementBuild(graph:, ..) = build
  let trim_graph = retain_offset_image_edges(graph, build)
  use protected_vertices <- result.try(untrimmed_open_endpoint_vertices(
    build,
    untrimmed,
  ))
  use without_submerged <- result.try(delete_winding_mismatched_edges(
    build,
    trim_graph,
    winding:,
    side_sampling_distance: submerged_side_sampling_distance,
  ))
  use parity_reduced <- result.try(forced_parity_reduce_trim_graph(
    without_submerged,
    protected_vertices,
  ))
  use subpaths <- result.try(source_order_survivor_subpaths(
    build,
    parity_reduced,
    protected_vertices:,
    tolerance: options.fitting.tolerance,
  ))
  close_survivor_subpaths(subpaths, tolerance: options.fitting.tolerance)
}

/// Terminal joint trimming for a completed band boundary.
///
/// Both sides and any caps are arranged together. Winding-side opinions define
/// which arrangement images match the semantic band; parity-capacity reduction
/// and source-order reconstruction then produce closed survivor subpaths.
fn trim_band_arrangement(
  untrimmed: List(svg_path.Subpath),
  winding winding: fn(svg_path.Point) -> Result(Int, Error),
  winding_opinions winding_opinions: List(WindingSideOpinion),
  options options: Options,
) -> Result(List(svg_path.Subpath), Error) {
  use build <- result.try(band_segment_arrangement(untrimmed, winding_opinions))
  let OffsetArrangementBuild(graph:, ..) = build
  use protected_vertices <- result.try(untrimmed_open_endpoint_vertices(
    build,
    untrimmed,
  ))
  use without_submerged <- result.try(delete_winding_mismatched_edges(
    build,
    offset_trim_graph(graph),
    winding:,
    side_sampling_distance: submerged_side_sampling_distance,
  ))
  use parity_reduced <- result.try(forced_parity_reduce_trim_graph(
    without_submerged,
    protected_vertices,
  ))
  source_order_survivor_subpaths(
    build,
    parity_reduced,
    protected_vertices:,
    tolerance: options.fitting.tolerance,
  )
  |> result.try(close_survivor_subpaths(_, tolerance: options.fitting.tolerance))
}

fn forced_parity_reduce_trim_graph(
  graph: OffsetTrimGraph,
  protected_vertices: List(Int),
) -> Result(OffsetTrimGraph, Error) {
  let OffsetTrimGraph(vertices:, edges:, ..) = graph
  let arrangement =
    arrangement_graph.ArrangementGraph(vertices:, edges:, cyclic_orders: [])
  use assignments <- result.try(
    arrangement_graph.forced_parity_capacities(
      arrangement,
      vertex_parities: protected_vertex_parities(protected_vertices),
    )
    |> result.map_error(ForcedParityPruningError),
  )
  let edge_capacities =
    list.map(assignments, fn(assignment) {
      let arrangement_graph.EdgeCapacityAssignment(edge_id:, capacity:) =
        assignment
      #(edge_id, capacity)
    })
  let edges =
    edges
    |> list.filter_map(fn(edge) {
      case
        list.find(assignments, fn(candidate) { candidate.edge_id == edge.id })
      {
        Error(_) -> Error(Nil)
        Ok(arrangement_graph.EdgeCapacityAssignment(capacity:, ..)) -> {
          case capacity > 0 {
            True -> Ok(edge)
            False -> Error(Nil)
          }
        }
      }
    })
  Ok(OffsetTrimGraph(vertices:, edges:, edge_capacities: Some(edge_capacities)))
}

fn protected_vertex_parities(
  vertices: List(Int),
) -> List(arrangement_graph.VertexParityRequest) {
  vertices
  |> unique_ints(unique: [])
  |> list.filter_map(fn(vertex) {
    case int_occurrences(vertices, vertex) % 2 {
      // Open offset endpoints guide forced reductions while they remain
      // attached, but trimming is intentionally allowed to delete an entire
      // endpoint component rather than turn its isolation into an error.
      1 -> Ok(arrangement_graph.PreferredVertexParity(vertex, 1))
      _ -> Error(Nil)
    }
  })
}

fn int_occurrences(values: List(Int), target: Int) -> Int {
  case values {
    [] -> 0
    [first, ..rest] ->
      case first == target {
        True -> 1 + int_occurrences(rest, target)
        False -> int_occurrences(rest, target)
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
        [] -> Error(InternalSegmentImageCountMismatch)
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
  let arrangement_graph.ArrangementSourceSegmentImage(segment_index:, ..) =
    image
  use edges <- result.try(source_segment_image_edges(build, image))
  case edges {
    [] -> Error(InternalEmptySegmentImage(segment_index:))
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
  let arrangement_graph.ArrangementSourceSegmentImage(segment_index:, ..) =
    image
  use edges <- result.try(source_segment_image_edges(build, image))
  use last <- result.try(
    last_directed_edge(edges)
    |> result.map_error(fn(_) { InternalEmptySegmentImage(segment_index:) }),
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

fn delete_winding_mismatched_edges(
  build: OffsetArrangementBuild,
  graph: OffsetTrimGraph,
  winding winding: fn(svg_path.Point) -> Result(Int, Error),
  side_sampling_distance side_sampling_distance: Float,
) -> Result(OffsetTrimGraph, Error) {
  let OffsetTrimGraph(vertices:, edges:, edge_capacities:) = graph
  use retained <- result.try(
    delete_winding_mismatched_edges_loop(
      build,
      edges,
      winding:,
      side_sampling_distance:,
      retained: [],
    ),
  )
  Ok(OffsetTrimGraph(vertices:, edges: retained, edge_capacities:))
}

fn delete_winding_mismatched_edges_loop(
  build: OffsetArrangementBuild,
  edges: List(arrangement_graph.ArrangementEdge),
  winding winding: fn(svg_path.Point) -> Result(Int, Error),
  side_sampling_distance side_sampling_distance: Float,
  retained retained: List(arrangement_graph.ArrangementEdge),
) -> Result(List(arrangement_graph.ArrangementEdge), Error) {
  case edges {
    [] -> Ok(list.reverse(retained))
    [edge, ..rest] -> {
      use matches <- result.try(arrangement_edge_winding_matches_opinion(
        build,
        edge,
        winding:,
        side_sampling_distance:,
      ))
      let retained = case matches {
        True -> [edge, ..retained]
        False -> retained
      }
      delete_winding_mismatched_edges_loop(
        build,
        rest,
        winding:,
        side_sampling_distance:,
        retained:,
      )
    }
  }
}

fn arrangement_edge_winding_matches_opinion(
  build: OffsetArrangementBuild,
  edge: arrangement_graph.ArrangementEdge,
  winding winding: fn(svg_path.Point) -> Result(Int, Error),
  side_sampling_distance side_sampling_distance: Float,
) -> Result(Bool, Error) {
  let arrangement_graph.ArrangementEdge(id:, segment:, ..) = edge
  use expected <- result.try(arrangement_edge_winding_opinion(build, id))
  use point <- result.try(
    svg_path.segment_point(segment, at: 0.5) |> result.map_error(PathError),
  )
  use normal <- result.try(unit_normal(segment, t: 0.5))
  use left <- result.try(
    winding(point_helpers.add(
      point,
      point_helpers.scale(normal, side_sampling_distance),
    )),
  )
  use right <- result.try(
    winding(point_helpers.add(
      point,
      point_helpers.scale(normal, 0.0 -. side_sampling_distance),
    )),
  )
  let WindingSideOpinion(left: expected_left, right: expected_right) = expected
  let common_shift = expected_left - left
  Ok(
    common_shift >= 0
    && expected_right - right == common_shift
    && left + common_shift >= 0
    && right + common_shift >= 0,
  )
}

fn arrangement_edge_winding_opinion(
  build: OffsetArrangementBuild,
  edge_id: Int,
) -> Result(WindingSideOpinion, Error) {
  let OffsetArrangementBuild(edge_images:, ..) = build
  case arrangement_edge_image_by_id(edge_images, edge_id) {
    Error(Nil) -> Error(InternalMissingEdgeImage(edge_id:))
    Ok(arrangement_graph.ArrangementEdgeImage(sources:, ..)) ->
      arrangement_source_winding_opinions(
        build,
        sources,
        WindingSideOpinion(0, 0),
      )
  }
}

fn arrangement_source_winding_opinions(
  build: OffsetArrangementBuild,
  sources: List(arrangement_graph.ArrangementEdgeSourceImage),
  opinion: WindingSideOpinion,
) -> Result(WindingSideOpinion, Error) {
  case sources {
    [] -> Ok(opinion)
    [first, ..rest] -> {
      let arrangement_graph.ArrangementEdgeSourceImage(
        segment_index:,
        reversed:,
        ..,
      ) = first
      use indexed <- result.try(
        offset_indexed_segment_at(build.indexed_segments, segment_index)
        |> result.map_error(fn(_) {
          InternalMissingIndexedSegment(segment_index:)
        }),
      )
      let IndexedOffsetSegment(winding_opinion:, ..) = indexed
      use source_opinion <- result.try(case winding_opinion {
        Some(opinion) -> Ok(opinion)
        None -> Error(InternalMissingWindingOpinion(segment_index:))
      })
      let WindingSideOpinion(left:, right:) = source_opinion
      let source_opinion = case reversed {
        True -> WindingSideOpinion(left: right, right: left)
        False -> source_opinion
      }
      let WindingSideOpinion(left: total_left, right: total_right) = opinion
      let WindingSideOpinion(left: source_left, right: source_right) =
        source_opinion
      arrangement_source_winding_opinions(
        build,
        rest,
        WindingSideOpinion(
          left: total_left + source_left,
          right: total_right + source_right,
        ),
      )
    }
  }
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
  let start = svg_path.subpath_start(subpath)
  let end = svg_path.subpath_end(subpath)
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

fn source_order_survivor_subpaths(
  build: OffsetArrangementBuild,
  graph: OffsetTrimGraph,
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
  let available = arrangement_edge_capacities(graph)
  use chain_result <- result.try(
    source_order_survivor_chains(build, segment_images, available, open: []),
  )
  let #(chains, remaining) = chain_result
  use _ <- result.try(assert_capacities_consumed(remaining))
  use _ <- result.try(assert_forced_parity_chains_valid(
    graph,
    chains,
    protected_vertices,
  ))
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

fn arrangement_edge_capacities(
  graph: OffsetTrimGraph,
) -> List(AvailableEdgeCapacity) {
  let OffsetTrimGraph(edges:, edge_capacities:, ..) = graph
  case edge_capacities {
    None -> list.map(edges, fn(edge) { AvailableEdgeCapacity(edge.id, 1) })
    Some(capacities) ->
      capacities
      |> list.filter_map(fn(entry) {
        case entry.1 > 0 {
          True -> Ok(AvailableEdgeCapacity(entry.0, entry.1))
          False -> Error(Nil)
        }
      })
  }
}

fn assert_capacities_consumed(
  capacities: List(AvailableEdgeCapacity),
) -> Result(Nil, Error) {
  case capacities {
    [] -> Ok(Nil)
    [AvailableEdgeCapacity(edge_id:, remaining:), ..] ->
      Error(InternalSurvivorCapacityMismatch(edge_id:, remaining:))
  }
}

fn assert_forced_parity_chains_valid(
  graph: OffsetTrimGraph,
  chains: List(SurvivorChain),
  protected_vertices: List(Int),
) -> Result(Nil, Error) {
  let OffsetTrimGraph(edge_capacities:, ..) = graph
  case edge_capacities {
    None -> Ok(Nil)
    Some(_) ->
      case
        list.find(chains, fn(chain) {
          !chain.closed
          && !{
            list.contains(protected_vertices, chain.start_vertex)
            && list.contains(protected_vertices, chain.end_vertex)
          }
        })
      {
        Ok(chain) ->
          Error(InternalForcedParityOpenChain(
            start_vertex: chain.start_vertex,
            end_vertex: chain.end_vertex,
          ))
        Error(_) -> Ok(Nil)
      }
  }
}

fn source_order_survivor_chains(
  build: OffsetArrangementBuild,
  images: List(arrangement_graph.ArrangementSourceSegmentImage),
  available: List(AvailableEdgeCapacity),
  open open: List(SurvivorChain),
) -> Result(#(List(SurvivorChain), List(AvailableEdgeCapacity)), Error) {
  case images {
    [] -> Ok(#(list.reverse(open), available))
    [image, ..rest] -> {
      use image_result <- result.try(source_order_survivor_image_edges(
        build,
        image,
        available,
      ))
      let #(image_edges, available) = image_result
      let open = append_source_order_edges(image_edges, open:)
      source_order_survivor_chains(build, rest, available, open:)
    }
  }
}

fn source_order_survivor_image_edges(
  build: OffsetArrangementBuild,
  image: arrangement_graph.ArrangementSourceSegmentImage,
  available: List(AvailableEdgeCapacity),
) -> Result(#(List(SurvivorEdge), List(AvailableEdgeCapacity)), Error) {
  use directed <- result.try(source_segment_image_edges(build, image))
  Ok(source_order_survivor_directed_edges(directed, available, edges: []))
}

fn source_order_survivor_directed_edges(
  directed_edges: List(#(arrangement_graph.ArrangementEdge, Bool)),
  available: List(AvailableEdgeCapacity),
  edges edges: List(SurvivorEdge),
) -> #(List(SurvivorEdge), List(AvailableEdgeCapacity)) {
  case directed_edges {
    [] -> #(list.reverse(edges), available)
    [directed_edge, ..rest] -> {
      let #(edge, reversed) = directed_edge
      case take_edge_capacity(edge.id, available) {
        Ok(available) -> {
          let #(start_vertex, end_vertex, segment) = case reversed {
            True -> #(
              edge.end_vertex,
              edge.start_vertex,
              svg_path.segment_reverse(edge.segment),
            )
            False -> #(edge.start_vertex, edge.end_vertex, edge.segment)
          }
          let survivor =
            SurvivorEdge(
              edge_id: edge.id,
              reversed:,
              start_vertex:,
              end_vertex:,
              segment:,
              arrangement_preimage: None,
            )
          source_order_survivor_directed_edges(rest, available, edges: [
            survivor,
            ..edges
          ])
        }
        Error(Nil) ->
          source_order_survivor_directed_edges(rest, available, edges:)
      }
    }
  }
}

fn take_edge_capacity(
  id: Int,
  capacities: List(AvailableEdgeCapacity),
) -> Result(List(AvailableEdgeCapacity), Nil) {
  case capacities {
    [] -> Error(Nil)
    [first, ..rest] -> {
      let AvailableEdgeCapacity(edge_id:, remaining:) = first
      case edge_id == id {
        True ->
          case remaining == 1 {
            True -> Ok(rest)
            False ->
              Ok([
                AvailableEdgeCapacity(edge_id:, remaining: remaining - 1),
                ..rest
              ])
          }
        False -> {
          use rest <- result.try(take_edge_capacity(id, rest))
          Ok([first, ..rest])
        }
      }
    }
  }
}

fn append_source_order_edges(
  edges: List(SurvivorEdge),
  open open: List(SurvivorChain),
) -> List(SurvivorChain) {
  case edges {
    [] -> open
    [first, ..rest] -> {
      let open = append_source_order_edge(first, open:)
      append_source_order_edges(rest, open:)
    }
  }
}

fn append_source_order_edge(
  edge: SurvivorEdge,
  open open: List(SurvivorChain),
) -> List(SurvivorChain) {
  let SurvivorEdge(start_vertex:, end_vertex:, ..) = edge
  let chain =
    SurvivorChain(
      start_vertex:,
      end_vertex:,
      edges: [edge],
      closed: start_vertex == end_vertex,
    )
  insert_survivor_chain(chain, open, skipped: [])
}

fn insert_survivor_chain(
  chain: SurvivorChain,
  open: List(SurvivorChain),
  skipped skipped: List(SurvivorChain),
) -> List(SurvivorChain) {
  case open {
    [] -> [mark_survivor_chain_closed(chain), ..list.reverse(skipped)]
    [candidate, ..rest] -> {
      case merge_survivor_chains(chain, candidate) {
        Ok(merged) ->
          insert_survivor_chain(
            mark_survivor_chain_closed(merged),
            list.append(list.reverse(skipped), rest),
            skipped: [],
          )
        Error(Nil) ->
          insert_survivor_chain(chain, rest, skipped: [candidate, ..skipped])
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
    edges: incoming_edges,
    ..,
  ) = incoming
  let SurvivorChain(
    start_vertex: candidate_start,
    end_vertex: candidate_end,
    edges: candidate_edges,
    ..,
  ) = candidate

  // `candidate` was encountered earlier in source order. Prefer extending it
  // with `incoming` before considering the equivalent closed-loop rotation
  // that prepends `incoming` to `candidate`.
  case candidate_end == incoming_start {
    True ->
      Ok(SurvivorChain(
        start_vertex: candidate_start,
        end_vertex: incoming_end,
        edges: list.append(candidate_edges, incoming_edges),
        closed: candidate_start == incoming_end,
      ))
    False ->
      case incoming_end == candidate_start {
        True ->
          Ok(SurvivorChain(
            start_vertex: incoming_start,
            end_vertex: candidate_end,
            edges: list.append(incoming_edges, candidate_edges),
            closed: incoming_start == candidate_end,
          ))
        False ->
          case incoming_end == candidate_end {
            True -> {
              let incoming = reverse_survivor_chain(incoming)
              merge_survivor_chains(incoming, candidate)
            }
            False ->
              case incoming_start == candidate_start {
                True -> {
                  let incoming = reverse_survivor_chain(incoming)
                  merge_survivor_chains(incoming, candidate)
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
  let SurvivorChain(start_vertex:, end_vertex:, edges:, closed:) = chain
  SurvivorChain(
    start_vertex: end_vertex,
    end_vertex: start_vertex,
    edges: reverse_survivor_edges(edges, reversed: []),
    closed:,
  )
}

fn reverse_survivor_edges(
  edges: List(SurvivorEdge),
  reversed reversed: List(SurvivorEdge),
) -> List(SurvivorEdge) {
  case edges {
    [] -> reversed
    [
      SurvivorEdge(
        edge_id:,
        reversed: edge_reversed,
        start_vertex:,
        end_vertex:,
        segment:,
        arrangement_preimage:,
      ),
      ..rest
    ] ->
      reverse_survivor_edges(rest, reversed: [
        SurvivorEdge(
          edge_id:,
          reversed: !edge_reversed,
          start_vertex: end_vertex,
          end_vertex: start_vertex,
          segment: svg_path.segment_reverse(segment),
          arrangement_preimage:,
        ),
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
      let SurvivorChain(edges:, closed:, ..) = first
      let segments =
        list.map(edges, fn(edge) {
          let SurvivorEdge(segment:, ..) = edge
          segment
        })
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

fn band_from_sides(
  side_a: svg_path.Subpath,
  inner_offset: Float,
  side_b: svg_path.Subpath,
  outer_offset: Float,
) -> Result(OneSubpathBand, Error) {
  let #(exterior, interior) = case inner_offset >=. outer_offset {
    True -> #(side_a, side_b)
    False -> #(side_b, side_a)
  }
  case svg_path.subpath_is_closed(side_a) {
    True -> Ok(ClosedSubpathBand(exterior:, interior:))
    False -> {
      use outline <- result.try(open_butt_band_outline(
        side_a: exterior,
        side_b: interior,
      ))
      Ok(OpenSubpathBand(outline))
    }
  }
}

fn untrimmed_stroke_band(
  source: svg_path.Subpath,
  width: Float,
  cap: Cap,
  options: Options,
) -> Result(OneSubpathBand, Error) {
  let radius = width /. 2.0
  use normalized <- result.try(normalize_source_subpath(source, options))
  case svg_path.subpath_is_closed(source) {
    True -> {
      use side_a <- result.try(closed_untrimmed_side_from_normalized_source(
        normalized,
        offset: 0.0 -. radius,
        options:,
      ))
      use side_b <- result.try(closed_untrimmed_side_from_normalized_source(
        normalized,
        offset: radius,
        options:,
      ))
      Ok(ClosedSubpathBand(exterior: side_b, interior: side_a))
    }
    False -> {
      use outline <- result.try(untrimmed_stroke_outline_from_normalized_source(
        normalized,
        radius,
        cap,
        options,
      ))
      Ok(OpenSubpathBand(outline))
    }
  }
}

fn closed_untrimmed_side_from_normalized_source(
  source: svg_path.Subpath,
  offset offset: Float,
  options options: Options,
) -> Result(svg_path.Subpath, Error) {
  use side <- result.try(untrimmed_subpath_from_normalized_source(
    source,
    offset: offset,
    options:,
  ))
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
  let end_a = svg_path.subpath_end(side_a)
  let end_b = svg_path.subpath_end(side_b)
  Ok(line_segments_between([end_a, end_b]))
}

fn open_butt_band_start_cap(
  side_a: svg_path.Subpath,
  side_b: svg_path.Subpath,
) -> Result(List(svg_path.Segment), Error) {
  let start_a = svg_path.subpath_start(side_a)
  let start_b = svg_path.subpath_start(side_b)
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
  let first =
    point_helpers.add(
      point,
      point_helpers.scale(normal, side_sampling_distance),
    )
  let second =
    point_helpers.add(
      point,
      point_helpers.scale(normal, 0.0 -. side_sampling_distance),
    )
  use first_inside <- result.try(inside(first))
  use second_inside <- result.try(inside(second))
  Ok(first_inside && second_inside)
}

/// Build a local coordinate map around a subpath.
///
/// The returned function interprets its input point as local path coordinates:
/// `x` is true arc length along the source subpath, and `y` is signed offset
/// from that point. Positive offsets use this module's usual convention:
/// to the visual left of the subpath direction.
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

/// Offset one segment by a signed normal displacement.
///
/// Positive offsets point along the visual left normal. For a line
/// from `(0, 0)` to `(10, 0)`, `offset: 2.0` returns a line from `(0, -2)` to
/// `(10, -2)`.
///
/// Curves return an open subpath because the result may need several pieces to
/// stay within tolerance. Circular arcs offset to circular arcs; non-circular
/// arcs and Beziers use cubic fitting.
pub fn segment(
  segment: svg_path.Segment,
  offset offset: Float,
) -> Result(svg_path.Subpath, Error) {
  segment_with(segment, offset:, options: default_options())
}

/// Offset one segment by a signed normal displacement using explicit options.
pub fn segment_with(
  segment segment: svg_path.Segment,
  offset offset: Float,
  options options: Options,
) -> Result(svg_path.Subpath, Error) {
  use source <- result.try(
    svg_path.subpath_with([segment], policy: svg_path.Strict)
    |> result.map_error(PathError),
  )
  case subpath_untrimmed_with(source, offset:, options:) {
    Error(PathError(svg_path.EmptySubpath)) -> Error(DegenerateTangent(0.0))
    result -> result
  }
}

/// Offset a subpath by a signed normal displacement.
///
/// Positive offsets point along the visual left normal. Adjacent
/// offset segments are connected using `default_options().join`. The result is
/// a path because trimming self-intersections can split the offset into
/// multiple subpaths or remove it entirely.
///
/// Trimming nodes the untrimmed offset together with its final refined
/// zero-offset source pieces, removes zero-source-only and winding-mismatched
/// arrangement capacities, applies forced parity reductions, and reconstructs
/// surviving offset edges in untrimmed traversal order.
pub fn subpath(
  subpath: svg_path.Subpath,
  offset offset: Float,
) -> Result(svg_path.Path, Error) {
  subpath_with(subpath, offset:, options: default_options())
}

/// Offset a subpath by a signed normal displacement using explicit options.
pub fn subpath_with(
  subpath subpath: svg_path.Subpath,
  offset offset: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use normalized <- result.try(normalize_source_subpath(subpath, options))
  use untrimmed_build <- result.try(build_single_offset_untrimmed(
    normalized,
    offset:,
    options:,
  ))
  use band <- result.try(band_from_sides(
    untrimmed_build.zero_source,
    0.0,
    untrimmed_build.subpath,
    offset,
  ))
  trim_single_offset_builds([untrimmed_build], offset, bands: [band], options:)
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
  let sum = point_helpers.add(left_tangent, right_tangent)
  case point_helpers.norm(sum) >. small_unit_division_tolerance {
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
      let control1 =
        point_helpers.add(
          start,
          point_helpers.scale(
            point_helpers.subtract(control, start),
            2.0 /. 3.0,
          ),
        )
      let control2 =
        point_helpers.add(
          end,
          point_helpers.scale(point_helpers.subtract(control, end), 2.0 /. 3.0),
        )
      let handle = point_helpers.distance(control2, end)
      svg_path.CubicBezier(
        start:,
        control1:,
        control2: point_helpers.add(
          end,
          point_helpers.scale(direction, 0.0 -. handle),
        ),
        end:,
      )
    }
    svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      let handle = point_helpers.distance(control2, end)
      svg_path.CubicBezier(
        start:,
        control1:,
        control2: point_helpers.add(
          end,
          point_helpers.scale(direction, 0.0 -. handle),
        ),
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
      let control1 =
        point_helpers.add(
          start,
          point_helpers.scale(
            point_helpers.subtract(control, start),
            2.0 /. 3.0,
          ),
        )
      let control2 =
        point_helpers.add(
          end,
          point_helpers.scale(point_helpers.subtract(control, end), 2.0 /. 3.0),
        )
      let handle = point_helpers.distance(control1, start)
      svg_path.CubicBezier(
        start:,
        control1: point_helpers.add(
          start,
          point_helpers.scale(direction, handle),
        ),
        control2:,
        end:,
      )
    }
    svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      let handle = point_helpers.distance(control1, start)
      svg_path.CubicBezier(
        start:,
        control1: point_helpers.add(
          start,
          point_helpers.scale(direction, handle),
        ),
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
    point_helpers.subtract(
      svg_path.segment_end(deleted),
      svg_path.segment_start(deleted),
    )
  let target =
    point_helpers.add(
      svg_path.segment_end(previous),
      point_helpers.scale(displacement, 1.0 /. 3.0),
    )
  stretch_segment_end(previous, to: target, tolerance:)
}

fn bridge_deleted_small_segment_gap(
  previous: svg_path.Segment,
  next: svg_path.Segment,
  tolerance: Float,
) -> #(svg_path.Segment, svg_path.Segment) {
  let previous_end = svg_path.segment_end(previous)
  let next_start = svg_path.segment_start(next)
  let target = point_helpers.lerp(previous_end, next_start, 0.25)
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

/// Offset a subpath at two signed normal displacements and trim the sides.
///
/// No endpoint caps are added. The two untrimmed offset walks are trimmed
/// together as a capless band. This supports ordinary capless stroke sides,
/// one-sided bands, and asymmetric bands such as two positive offsets.
/// Either numeric ordering is accepted. Exchanging `inner_offset` and
/// `outer_offset` reverses the orientation of the resulting band.
pub fn subpath_band(
  subpath: svg_path.Subpath,
  inner_offset inner_offset: Float,
  outer_offset outer_offset: Float,
) -> Result(svg_path.Path, Error) {
  subpath_band_with(
    subpath,
    inner_offset:,
    outer_offset:,
    options: default_options(),
  )
}

/// Offset a subpath at two signed normal displacements using explicit options.
///
/// Each synchronized side is first noded and trimmed on its own. A submerged
/// run without any reversed source preimage is retained because it does not
/// represent a reversal-generated fold. The surviving sides are then assembled
/// into a band and trimmed together using their directed winding-side opinions.
pub fn subpath_band_with(
  subpath subpath: svg_path.Subpath,
  inner_offset inner_offset: Float,
  outer_offset outer_offset: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use normalized <- result.try(normalize_source_subpath(subpath, options))
  use build <- result.try(build_synchronized_untrimmed(
    normalized,
    inner_offset: inner_offset,
    outer_offset: outer_offset,
    options:,
  ))
  let SynchronizedUntrimmedBuild(
    inner_culled: culled_a,
    outer_culled: culled_b,
    ..,
  ) = build
  let BandTrimming(inner_cusps:, outer_cusps:, in_band:) = options.band_trimming
  use untrimmed_a <- result.try(trim_band_side_cusps(
    culled_a,
    normalized,
    inner_offset,
    options,
    enabled: inner_cusps,
  ))
  use untrimmed_b <- result.try(trim_band_side_cusps(
    culled_b,
    normalized,
    outer_offset,
    options,
    enabled: outer_cusps,
  ))
  case untrimmed_a, untrimmed_b {
    None, _ | _, None -> Ok(svg_path.path_empty())
    Some(untrimmed_a), Some(untrimmed_b) -> {
      use band <- result.try(band_from_sides(
        untrimmed_a,
        inner_offset,
        untrimmed_b,
        outer_offset,
      ))
      let winding_opinions = case inner_offset >=. outer_offset {
        True -> [
          WindingSideOpinion(left: 0, right: 1),
          WindingSideOpinion(left: 1, right: 0),
        ]
        False -> [
          WindingSideOpinion(left: 1, right: 0),
          WindingSideOpinion(left: 0, right: 1),
        ]
      }
      use path <- result.try(case in_band {
        True ->
          topological_band_path_with_opinions(
            [untrimmed_a, untrimmed_b],
            [band],
            winding_opinions,
            options,
          )
        False -> one_subpath_band_semantic_path(band)
      })
      case inner_offset >. outer_offset {
        True -> Ok(svg_path.path_reverse(path))
        False -> Ok(path)
      }
    }
  }
}

fn trim_band_side_cusps(
  subpath: ICulledOffsetSubpath,
  zero_source: svg_path.Subpath,
  offset: Float,
  options: Options,
  enabled enabled: Bool,
) -> Result(Option(svg_path.Subpath), Error) {
  case enabled {
    False ->
      traced_subpath_from_i(subpath, 0)
      |> traced_subpath_geometry(options.fitting.tolerance)
      |> result.map(Some)
    True -> {
      use trimmed <- result.try(cusp_trim_i_subpath(
        subpath,
        zero_source,
        offset,
        options,
      ))
      case trimmed {
        None -> Ok(None)
        Some(trimmed) ->
          cusp_trimmed_subpath_geometry(trimmed, options.fitting.tolerance)
          |> result.map(Some)
      }
    }
  }
}

/// Trace the final joint-pruning arrangement used by `subpath_band_with`.
@internal
pub fn internal_subpath_band_arrangement_trace(
  subpath subpath: svg_path.Subpath,
  inner_offset inner_offset: Float,
  outer_offset outer_offset: Float,
  options options: Options,
) -> Result(List(BandArrangementTraceEdge), Error) {
  use _ <- result.try(validate_options(options))
  use normalized <- result.try(normalize_source_subpath(subpath, options))
  use build <- result.try(build_synchronized_untrimmed(
    normalized,
    inner_offset: inner_offset,
    outer_offset: outer_offset,
    options:,
  ))
  let SynchronizedUntrimmedBuild(
    inner_culled: culled_a,
    outer_culled: culled_b,
    ..,
  ) = build
  use trimmed_a <- result.try(cusp_trim_i_subpath(
    culled_a,
    normalized,
    inner_offset,
    options,
  ))
  use trimmed_b <- result.try(cusp_trim_i_subpath(
    culled_b,
    normalized,
    outer_offset,
    options,
  ))
  case trimmed_a, trimmed_b {
    None, _ | _, None -> Ok([])
    Some(trimmed_a), Some(trimmed_b) -> {
      use untrimmed_a <- result.try(cusp_trimmed_subpath_geometry(
        trimmed_a,
        options.fitting.tolerance,
      ))
      use untrimmed_b <- result.try(cusp_trimmed_subpath_geometry(
        trimmed_b,
        options.fitting.tolerance,
      ))
      use band <- result.try(band_from_sides(
        untrimmed_a,
        inner_offset,
        untrimmed_b,
        outer_offset,
      ))
      let winding_opinions = case inner_offset >=. outer_offset {
        True -> [
          WindingSideOpinion(left: 0, right: 1),
          WindingSideOpinion(left: 1, right: 0),
        ]
        False -> [
          WindingSideOpinion(left: 1, right: 0),
          WindingSideOpinion(left: 0, right: 1),
        ]
      }
      use winding <- result.try(internal_band_winding_function([band]))
      use arrangement <- result.try(band_segment_arrangement(
        [untrimmed_a, untrimmed_b],
        winding_opinions,
      ))
      let OffsetArrangementBuild(
        graph: arrangement_graph.ArrangementGraph(edges:, ..),
        ..,
      ) = arrangement
      band_arrangement_trace_edges(edges, arrangement, winding, traced: [])
    }
  }
}

/// Trace both production side-local arrangements immediately before cusp
/// trimming.
@internal
pub fn internal_subpath_band_cusp_trimming_arrangement_trace(
  subpath subpath: svg_path.Subpath,
  inner_offset inner_offset: Float,
  outer_offset outer_offset: Float,
  options options: Options,
) -> Result(List(CuspTrimmingArrangementTraceEdge), Error) {
  use _ <- result.try(validate_options(options))
  use normalized <- result.try(normalize_source_subpath(subpath, options))
  use build <- result.try(build_synchronized_untrimmed(
    normalized,
    inner_offset: inner_offset,
    outer_offset: outer_offset,
    options:,
  ))
  let SynchronizedUntrimmedBuild(
    inner_culled: culled_a,
    outer_culled: culled_b,
    ..,
  ) = build
  use first <- result.try(cusp_trimming_arrangement_trace_for_side(
    culled_a,
    normalized,
    inner_offset,
    side_index: 0,
    options:,
  ))
  use second <- result.try(cusp_trimming_arrangement_trace_for_side(
    culled_b,
    normalized,
    outer_offset,
    side_index: 1,
    options:,
  ))
  Ok(list.append(first, second))
}

fn cusp_trimming_arrangement_trace_for_side(
  subpath: ICulledOffsetSubpath,
  zero_source: svg_path.Subpath,
  offset: Float,
  side_index side_index: Int,
  options options: Options,
) -> Result(List(CuspTrimmingArrangementTraceEdge), Error) {
  let ICulledOffsetSubpath(segments:, closed:, ..) = subpath
  use geometry <- result.try(subpath_from_synchronized_segments(
    list.map(segments, fn(segment) { segment.segment }),
    closed:,
    tolerance: options.fitting.tolerance,
  ))
  use band <- result.try(band_from_sides(zero_source, 0.0, geometry, offset))
  use winding <- result.try(internal_band_winding_function([band]))
  use arrangement <- result.try(single_offset_segment_arrangement(
    [geometry],
    zero_source_segments: svg_path.subpath_segments(zero_source),
    offset:,
  ))
  let OffsetArrangementBuild(
    graph: arrangement_graph.ArrangementGraph(edges:, ..),
    ..,
  ) = arrangement
  cusp_trimming_arrangement_trace_edges(
    edges,
    arrangement,
    winding,
    side_index,
    traced: [],
  )
}

fn cusp_trimming_arrangement_trace_edges(
  edges: List(arrangement_graph.ArrangementEdge),
  build: OffsetArrangementBuild,
  winding: fn(svg_path.Point) -> Result(Int, Error),
  side_index: Int,
  traced traced: List(CuspTrimmingArrangementTraceEdge),
) -> Result(List(CuspTrimmingArrangementTraceEdge), Error) {
  case edges {
    [] -> Ok(list.reverse(traced))
    [edge, ..rest] -> {
      let arrangement_graph.ArrangementEdge(id:, segment:, ..) = edge
      use matches <- result.try(arrangement_edge_winding_matches_opinion(
        build,
        edge,
        winding:,
        side_sampling_distance: submerged_side_sampling_distance,
      ))
      cusp_trimming_arrangement_trace_edges(
        rest,
        build,
        winding,
        side_index,
        traced: [
          CuspTrimmingArrangementTraceEdge(
            side_index:,
            id:,
            segment:,
            offset_image: arrangement_edge_has_group(
              build,
              id,
              UntrimmedOffsetSegment,
            ),
            submerged: !matches,
          ),
          ..traced
        ],
      )
    }
  }
}

fn band_arrangement_trace_edges(
  edges: List(arrangement_graph.ArrangementEdge),
  build: OffsetArrangementBuild,
  winding: fn(svg_path.Point) -> Result(Int, Error),
  traced traced: List(BandArrangementTraceEdge),
) -> Result(List(BandArrangementTraceEdge), Error) {
  case edges {
    [] -> Ok(list.reverse(traced))
    [edge, ..rest] -> {
      let arrangement_graph.ArrangementEdge(id:, segment:, ..) = edge
      use matches <- result.try(arrangement_edge_winding_matches_opinion(
        build,
        edge,
        winding:,
        side_sampling_distance: submerged_side_sampling_distance,
      ))
      band_arrangement_trace_edges(rest, build, winding, traced: [
        BandArrangementTraceEdge(id:, segment:, submerged: !matches),
        ..traced
      ])
    }
  }
}

/// Offset a subpath at two signed normal displacements without trimming.
///
/// This returns the two untrimmed offset walks in one path, with the
/// `inner_offset` side first and the `outer_offset` side second. No caps, bridges,
/// pairwise trimming, self-intersection pruning, or fill-rule interpretation
/// are added.
pub fn subpath_band_untrimmed(
  subpath: svg_path.Subpath,
  inner_offset inner_offset: Float,
  outer_offset outer_offset: Float,
) -> Result(svg_path.Path, Error) {
  subpath_band_untrimmed_with(
    subpath,
    inner_offset:,
    outer_offset:,
    options: default_options(),
  )
}

/// Offset a subpath at two signed normal displacements without trimming,
/// using explicit options.
pub fn subpath_band_untrimmed_with(
  subpath subpath: svg_path.Subpath,
  inner_offset inner_offset: Float,
  outer_offset outer_offset: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use normalized <- result.try(normalize_source_subpath(subpath, options))
  use build <- result.try(build_synchronized_untrimmed(
    normalized,
    inner_offset: inner_offset,
    outer_offset: outer_offset,
    options:,
  ))
  let SynchronizedUntrimmedBuild(inner: side_a, outer: side_b, ..) = build
  Ok(svg_path.Path(subpaths: [side_a, side_b]))
}

/// Stroke a subpath with the default butt cap.
///
/// Open subpaths build one closed untrimmed stroke boundary from the two
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
              use untrimmed <- result.try(untrimmed_stroke_outline(
                subpath,
                radius,
                cap,
                options,
              ))
              use stroke <- result.try(topological_band_path(
                [untrimmed],
                bands: [OpenSubpathBand(untrimmed)],
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
  offset offset: Float,
) -> Result(svg_path.Subpath, Error) {
  subpath_untrimmed_with(subpath, offset:, options: default_options())
}

/// Offset a subpath without trimming self-intersections using explicit options.
pub fn subpath_untrimmed_with(
  subpath subpath: svg_path.Subpath,
  offset offset: Float,
  options options: Options,
) -> Result(svg_path.Subpath, Error) {
  use _ <- result.try(validate_options(options))
  use normalized <- result.try(normalize_source_subpath(subpath, options))
  untrimmed_subpath_from_normalized_source(normalized, offset: offset, options:)
}

fn untrimmed_subpath_from_normalized_source(
  subpath: svg_path.Subpath,
  offset offset: Float,
  options options: Options,
) -> Result(svg_path.Subpath, Error) {
  build_single_offset_untrimmed(subpath, offset, options)
  |> result.map(fn(build) { build.subpath })
}

/// Offset every subpath in a path by a signed normal displacement.
pub fn path(
  path: svg_path.Path,
  offset offset: Float,
) -> Result(svg_path.Path, Error) {
  path_with(path, offset:, options: default_options())
}

/// Offset every subpath by a signed normal displacement using explicit options.
pub fn path_with(
  path path: svg_path.Path,
  offset offset: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use normalized <- result.try(normalize_source_path(path, options))
  let source_subpaths = svg_path.path_subpaths(normalized)
  use untrimmed_builds <- result.try(
    single_offset_untrimmed_path_builds(
      source_subpaths,
      offset,
      options,
      converted: [],
    ),
  )
  use bands <- result.try(
    single_offset_bands_from_builds(untrimmed_builds, offset, converted: []),
  )
  use result <- result.try(trim_single_offset_builds(
    untrimmed_builds,
    offset,
    bands:,
    options:,
  ))
  Ok(result)
}

fn single_offset_bands_from_builds(
  builds: List(SingleOffsetUntrimmedBuild),
  offset: Float,
  converted converted: List(OneSubpathBand),
) -> Result(List(OneSubpathBand), Error) {
  case builds {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use band <- result.try(band_from_sides(
        first.zero_source,
        0.0,
        first.subpath,
        offset,
      ))
      single_offset_bands_from_builds(rest, offset, converted: [
        band,
        ..converted
      ])
    }
  }
}

/// Offset every subpath at two signed normal displacements and trim each pair.
/// Exchanging `inner_offset` and `outer_offset` reverses each resulting band.
pub fn path_band(
  path: svg_path.Path,
  inner_offset inner_offset: Float,
  outer_offset outer_offset: Float,
) -> Result(svg_path.Path, Error) {
  path_band_with(path, inner_offset:, outer_offset:, options: default_options())
}

/// Offset every subpath in a path at two signed normal displacements using
/// options.
pub fn path_band_with(
  path path: svg_path.Path,
  inner_offset inner_offset: Float,
  outer_offset outer_offset: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use subpaths <- result.try(
    band_path_subpaths(
      svg_path.path_subpaths(path),
      inner_offset,
      outer_offset,
      options,
      converted: [],
    ),
  )
  Ok(svg_path.Path(subpaths:))
}

/// Offset every subpath at two signed normal displacements without trimming any
/// side.
pub fn path_band_untrimmed(
  path: svg_path.Path,
  inner_offset inner_offset: Float,
  outer_offset outer_offset: Float,
) -> Result(svg_path.Path, Error) {
  path_band_untrimmed_with(
    path,
    inner_offset:,
    outer_offset:,
    options: default_options(),
  )
}

/// Offset every subpath at two signed normal displacements without trimming any
/// side, using explicit options.
pub fn path_band_untrimmed_with(
  path path: svg_path.Path,
  inner_offset inner_offset: Float,
  outer_offset outer_offset: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use subpaths <- result.try(
    untrimmed_band_path_subpaths(
      svg_path.path_subpaths(path),
      inner_offset,
      outer_offset,
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
  offset offset: Float,
) -> Result(svg_path.Path, Error) {
  path_untrimmed_with(path, offset:, options: default_options())
}

/// Offset every subpath in a path without trimming self-intersections using
/// explicit options.
pub fn path_untrimmed_with(
  path path: svg_path.Path,
  offset offset: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_options(options))
  use subpaths <- result.try(
    untrimmed_offset_path_subpaths(
      svg_path.path_subpaths(path),
      offset,
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
    False -> validate_tangent_heal_angle(options)
  }
}

fn validate_tangent_heal_angle(options: Options) -> Result(Nil, Error) {
  case
    options.tangent_heal_angle_degrees <. 0.0
    || !number.is_finite(options.tangent_heal_angle_degrees)
  {
    True ->
      Error(InvalidTangentHealAngleDegrees(options.tangent_heal_angle_degrees))
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
  offset: Float,
  options options: Options,
  converted converted: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use offset_subpath <- result.try(subpath_untrimmed_with(
        first,
        offset:,
        options:,
      ))
      untrimmed_offset_path_subpaths(rest, offset, options, converted: [
        offset_subpath,
        ..converted
      ])
    }
  }
}

fn single_offset_untrimmed_path_builds(
  subpaths: List(svg_path.Subpath),
  offset: Float,
  options: Options,
  converted converted: List(SingleOffsetUntrimmedBuild),
) -> Result(List(SingleOffsetUntrimmedBuild), Error) {
  case subpaths {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use build <- result.try(build_single_offset_untrimmed(
        first,
        offset:,
        options:,
      ))
      single_offset_untrimmed_path_builds(rest, offset, options, converted: [
        build,
        ..converted
      ])
    }
  }
}

fn untrimmed_band_path_subpaths(
  subpaths: List(svg_path.Subpath),
  inner_offset: Float,
  outer_offset: Float,
  options: Options,
  converted converted: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use band <- result.try(subpath_band_untrimmed_with(
        first,
        inner_offset:,
        outer_offset:,
        options:,
      ))
      untrimmed_band_path_subpaths(
        rest,
        inner_offset,
        outer_offset,
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

fn band_segment_arrangement(
  untrimmed: List(svg_path.Subpath),
  winding_opinions: List(WindingSideOpinion),
) -> Result(OffsetArrangementBuild, Error) {
  let indexed =
    indexed_offset_segments(
      untrimmed,
      group: UntrimmedOffsetSegment,
      winding_opinions:,
    )
  offset_segment_arrangement(indexed)
}

fn single_offset_segment_arrangement(
  untrimmed: List(svg_path.Subpath),
  zero_source_segments zero_source_segments: List(svg_path.Segment),
  offset offset: Float,
) -> Result(OffsetArrangementBuild, Error) {
  let #(offset_opinion, zero_opinion) = case offset >=. 0.0 {
    True -> #(
      WindingSideOpinion(left: 0, right: 1),
      WindingSideOpinion(left: 1, right: 0),
    )
    False -> #(
      WindingSideOpinion(left: 1, right: 0),
      WindingSideOpinion(left: 0, right: 1),
    )
  }
  let indexed =
    list.append(
      indexed_offset_segments(
        untrimmed,
        group: UntrimmedOffsetSegment,
        winding_opinions: list.repeat(offset_opinion, list.length(untrimmed)),
      ),
      list.map(zero_source_segments, fn(segment) {
        IndexedOffsetSegment(
          group: ZeroOffsetSourceSegment,
          subpath_index: 0,
          segment:,
          winding_opinion: Some(zero_opinion),
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
  winding_opinions winding_opinions: List(WindingSideOpinion),
) -> List(IndexedOffsetSegment) {
  indexed_offset_segments_loop(
    subpaths,
    group,
    winding_opinions,
    subpath_index: 0,
    collected: [],
  )
}

fn indexed_offset_segments_loop(
  subpaths: List(svg_path.Subpath),
  group: OffsetArrangementSegmentGroup,
  winding_opinions: List(WindingSideOpinion),
  subpath_index subpath_index: Int,
  collected collected: List(IndexedOffsetSegment),
) -> List(IndexedOffsetSegment) {
  case subpaths {
    [] -> list.reverse(collected)
    [first, ..rest] -> {
      let #(winding_opinion, remaining_opinions) = case winding_opinions {
        [opinion, ..remaining] -> #(Some(opinion), remaining)
        [] -> #(None, [])
      }
      let collected =
        first
        |> svg_path.subpath_segments
        |> list.fold(collected, fn(collected, segment) {
          [
            IndexedOffsetSegment(
              group:,
              subpath_index:,
              segment:,
              winding_opinion:,
            ),
            ..collected
          ]
        })
      indexed_offset_segments_loop(
        rest,
        group,
        remaining_opinions,
        subpath_index: subpath_index + 1,
        collected:,
      )
    }
  }
}

fn band_subpath_winding_opinions(
  bands: List(OneSubpathBand),
) -> List(WindingSideOpinion) {
  case bands {
    [] -> []
    [first, ..rest] -> {
      let first_opinions = case first {
        OpenSubpathBand(_) -> [
          WindingSideOpinion(left: 0, right: 1),
        ]
        ClosedSubpathBand(_, _) -> [
          WindingSideOpinion(left: 0, right: 1),
          WindingSideOpinion(left: 1, right: 0),
        ]
      }
      list.append(first_opinions, band_subpath_winding_opinions(rest))
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
  graph: arrangement_graph.ArrangementGraph,
  build: OffsetArrangementBuild,
) -> OffsetTrimGraph {
  let arrangement_graph.ArrangementGraph(vertices:, edges:, ..) = graph
  let retained =
    list.filter(edges, fn(edge) {
      let arrangement_graph.ArrangementEdge(id:, ..) = edge
      arrangement_edge_has_group(build, id, UntrimmedOffsetSegment)
    })
  OffsetTrimGraph(vertices:, edges: retained, edge_capacities: None)
}

fn offset_trim_graph(
  graph: arrangement_graph.ArrangementGraph,
) -> OffsetTrimGraph {
  let arrangement_graph.ArrangementGraph(vertices:, edges:, ..) = graph
  OffsetTrimGraph(vertices:, edges:, edge_capacities: None)
}

fn arrangement_edge_has_group(
  build: OffsetArrangementBuild,
  edge_id: Int,
  group: OffsetArrangementSegmentGroup,
) -> Bool {
  case arrangement_edge_image_by_id(build.edge_images, edge_id) {
    Error(Nil) -> False
    Ok(arrangement_graph.ArrangementEdgeImage(sources:, ..)) ->
      sources
      |> list.any(fn(source) {
        let arrangement_graph.ArrangementEdgeSourceImage(segment_index:, ..) =
          source
        offset_segment_index_has_group(build, segment_index, group)
      })
  }
}

fn arrangement_edge_image_by_id(
  images: List(arrangement_graph.ArrangementEdgeImage),
  edge_id: Int,
) -> Result(arrangement_graph.ArrangementEdgeImage, Nil) {
  list.find(images, fn(image) { image.edge_id == edge_id })
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

fn band_path_subpaths(
  subpaths: List(svg_path.Subpath),
  inner_offset: Float,
  outer_offset: Float,
  options: Options,
  converted converted: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use offset <- result.try(subpath_band_with(
        first,
        inner_offset:,
        outer_offset:,
        options:,
      ))
      band_path_subpaths(
        rest,
        inner_offset,
        outer_offset,
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
  offset offset: Float,
  options options: Options,
) -> Result(SingleOffsetUntrimmedBuild, Error) {
  use build <- result.try(build_synchronized_untrimmed(
    subpath,
    inner_offset: 0.0,
    outer_offset: offset,
    options:,
  ))
  let SynchronizedUntrimmedBuild(
    inner: zero_source,
    outer: subpath,
    outer_culled: culled,
    correspondences:,
    portions:,
    join_correspondences:,
    ..,
  ) = build
  Ok(SingleOffsetUntrimmedBuild(
    subpath:,
    zero_source:,
    culled:,
    correspondences:,
    portions:,
    join_correspondences:,
  ))
}

fn build_synchronized_untrimmed(
  subpath: svg_path.Subpath,
  inner_offset inner_offset: Float,
  outer_offset outer_offset: Float,
  options options: Options,
) -> Result(SynchronizedUntrimmedBuild, Error) {
  let distances = OffsetDistances(inner: inner_offset, outer: outer_offset)
  case svg_path.subpath_segments(subpath) {
    [] -> {
      let start = svg_path.subpath_start(subpath)
      Ok(
        SynchronizedUntrimmedBuild(
          inner: svg_path.subpath_empty(at: start),
          outer: svg_path.subpath_empty(at: start),
          inner_culled: ICulledOffsetSubpath(
            segments: [],
            closed: svg_path.subpath_is_closed(subpath),
            side: Inner,
          ),
          outer_culled: ICulledOffsetSubpath(
            segments: [],
            closed: svg_path.subpath_is_closed(subpath),
            side: Outer,
          ),
          correspondences: [],
          portions: [],
          join_correspondences: [],
        ),
      )
    }
    [_, ..] -> {
      use build <- result.try(build_synchronized_offset_segments(
        subpath,
        distances,
        options,
      ))
      let SynchronizedOffsetSegmentsBuild(correspondences:, portions:, ..) =
        build
      use join_correspondences <- result.try(synchronized_join_correspondences(
        portions,
        distances,
        options.join,
        closed: svg_path.subpath_is_closed(subpath),
      ))
      let closed = svg_path.subpath_is_closed(subpath)
      let inner_preimage =
        assemble_preimage_subpath(
          portions,
          join_correspondences,
          side: Inner,
          closed:,
        )
      let outer_preimage =
        assemble_preimage_subpath(
          portions,
          join_correspondences,
          side: Outer,
          closed:,
        )
      use inner_culled <- result.try(cull_adjacent_preimage_loops(
        inner_preimage,
      ))
      use outer_culled <- result.try(cull_adjacent_preimage_loops(
        outer_preimage,
      ))
      let inner_segments = culled_offset_subpath_segments(inner_culled)
      let outer_segments = culled_offset_subpath_segments(outer_culled)
      use inner <- result.try(subpath_from_synchronized_segments(
        inner_segments,
        closed:,
        tolerance: options.fitting.tolerance,
      ))
      use outer <- result.try(subpath_from_synchronized_segments(
        outer_segments,
        closed:,
        tolerance: options.fitting.tolerance,
      ))
      Ok(SynchronizedUntrimmedBuild(
        inner:,
        outer:,
        inner_culled:,
        outer_culled:,
        correspondences:,
        portions:,
        join_correspondences:,
      ))
    }
  }
}

fn subpath_from_synchronized_segments(
  segments: List(svg_path.Segment),
  closed closed: Bool,
  tolerance tolerance: Float,
) -> Result(svg_path.Subpath, Error) {
  case segments {
    [] -> Error(DegenerateTangent(0.0))
    [_, ..] -> {
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
  }
}

fn assemble_preimage_subpath(
  portions: List(SynchronizedHealedPortion),
  joins: List(OffsetJoinCorrespondence),
  side side: BandSide,
  closed closed: Bool,
) -> HPreimageSubpath {
  HPreimageSubpath(
    segments: assemble_preimage_segments(portions, joins, side:),
    closed:,
    side:,
  )
}

fn assemble_preimage_segments(
  portions: List(SynchronizedHealedPortion),
  joins: List(OffsetJoinCorrespondence),
  side side: BandSide,
) -> List(HPreimageSegment) {
  case portions {
    [] -> []
    [first, ..rest] -> {
      let SynchronizedHealedPortion(inner:, outer:, ..) = first
      let portion = case side {
        Inner -> inner
        Outer -> outer
      }
      let portion_segments =
        list.map(portion, fn(offset) {
          HPreimageSegment(
            segment: offset.segment,
            source: HealedPreimage(offset),
          )
        })
      case joins {
        [] ->
          list.append(
            portion_segments,
            assemble_preimage_segments(rest, [], side:),
          )
        [join, ..remaining_joins] -> {
          let OffsetJoinCorrespondence(
            after_portion_index:,
            inner:,
            outer:,
            inner_reversed:,
            outer_reversed:,
            ..,
          ) = join
          let #(raw_join_segments, join_reversed) = case side {
            Inner -> #(inner, inner_reversed)
            Outer -> #(outer, outer_reversed)
          }
          let join_segments =
            indexed_join_preimage_segments(
              raw_join_segments,
              after_portion_index,
              side,
              join_reversed,
              index: 0,
              assembled: [],
            )
          list.append(
            portion_segments,
            list.append(
              join_segments,
              assemble_preimage_segments(rest, remaining_joins, side:),
            ),
          )
        }
      }
    }
  }
}

fn indexed_join_preimage_segments(
  segments: List(svg_path.Segment),
  after_portion_index: Int,
  side: BandSide,
  reversed: Bool,
  index index: Int,
  assembled assembled: List(HPreimageSegment),
) -> List(HPreimageSegment) {
  case segments {
    [] -> list.reverse(assembled)
    [segment, ..rest] ->
      indexed_join_preimage_segments(
        rest,
        after_portion_index,
        side,
        reversed,
        index: index + 1,
        assembled: [
          HPreimageSegment(
            segment:,
            source: JoinPreimage(
              after_portion_index:,
              side:,
              join_segment_index: index,
              reversed:,
            ),
          ),
          ..assembled
        ],
      )
  }
}

fn cull_adjacent_preimage_loops(
  subpath: HPreimageSubpath,
) -> Result(ICulledOffsetSubpath, Error) {
  let HPreimageSubpath(segments:, closed:, side:) = subpath
  let segments =
    list.map(segments, fn(preimage) {
      let HPreimageSegment(segment:, ..) = preimage
      ICulledOffsetSegment(
        segment:,
        preimage:,
        preimage_from: 0.0,
        preimage_to: 1.0,
      )
    })
  use segments <- result.try(cull_adjacent_offset_segment_loops(segments))
  use segments <- result.try(case closed {
    False -> Ok(segments)
    True -> cull_wrapping_offset_segment_loop(segments)
  })
  Ok(ICulledOffsetSubpath(segments:, closed:, side:))
}

fn cull_adjacent_offset_segment_loops(
  segments: List(ICulledOffsetSegment),
) -> Result(List(ICulledOffsetSegment), Error) {
  case segments {
    [] | [_] -> Ok(segments)
    [first, second, ..rest] -> {
      use #(first, second) <- result.try(cull_offset_segment_loop(first, second))
      case second {
        Some(second) ->
          cull_adjacent_offset_segment_loops_loop(second, rest, culled: [first])
        None -> cull_adjacent_offset_segment_loops_loop(first, rest, culled: [])
      }
    }
  }
}

fn cull_adjacent_offset_segment_loops_loop(
  previous: ICulledOffsetSegment,
  rest: List(ICulledOffsetSegment),
  culled culled: List(ICulledOffsetSegment),
) -> Result(List(ICulledOffsetSegment), Error) {
  case rest {
    [] -> Ok(list.reverse([previous, ..culled]))
    [next, ..remaining] -> {
      use #(previous, next) <- result.try(cull_offset_segment_loop(
        previous,
        next,
      ))
      case next {
        Some(next) ->
          cull_adjacent_offset_segment_loops_loop(next, remaining, culled: [
            previous,
            ..culled
          ])
        None ->
          cull_adjacent_offset_segment_loops_loop(previous, remaining, culled:)
      }
    }
  }
}

fn cull_wrapping_offset_segment_loop(
  segments: List(ICulledOffsetSegment),
) -> Result(List(ICulledOffsetSegment), Error) {
  case segments {
    [] | [_] -> Ok(segments)
    [first, ..rest] -> {
      use last <- result.try(last_list_item(rest))
      use #(last, first) <- result.try(cull_offset_segment_loop(last, first))
      case first {
        Some(first) -> Ok([first, ..replace_last_culled_offset(rest, last)])
        None -> Ok(replace_last_culled_offset(rest, last))
      }
    }
  }
}

fn cull_offset_segment_loop(
  left: ICulledOffsetSegment,
  right: ICulledOffsetSegment,
) -> Result(#(ICulledOffsetSegment, Option(ICulledOffsetSegment)), Error) {
  // This adjacent-pair rule could later be generalized to non-adjacent
  // self-intersections: split the resulting figure-eight into its two closed
  // sides, then remove the smaller side when its boundary starts and ends in
  // opposite REVERSED/NON-REVERSED states. Defining and measuring the smaller
  // side robustly is deliberately outside the present heuristic.
  case
    h_preimage_is_reversed(left.preimage)
    == h_preimage_is_reversed(right.preimage)
  {
    True -> Ok(#(left, Some(right)))
    False -> {
      case
        short_circuit_adjacent_offset_segment_loop_with_parameters(
          left.segment,
          right.segment,
        )
      {
        Error(PathError(svg_path.OverlappingSegments)) ->
          cull_adjacent_offset_segment_overlap(left, right)
        Error(error) -> Error(error)
        Ok(#(left_segment, left_to, right_segment, right_from)) -> {
          let left_preimage_to =
            interval_parameter(left.preimage_from, left.preimage_to, left_to)
          let right_preimage_from =
            interval_parameter(
              right.preimage_from,
              right.preimage_to,
              right_from,
            )
          Ok(#(
            ICulledOffsetSegment(
              ..left,
              segment: left_segment,
              preimage_to: left_preimage_to,
            ),
            Some(
              ICulledOffsetSegment(
                ..right,
                segment: right_segment,
                preimage_from: right_preimage_from,
              ),
            ),
          ))
        }
      }
    }
  }
}

fn cull_adjacent_offset_segment_overlap(
  left: ICulledOffsetSegment,
  right: ICulledOffsetSegment,
) -> Result(#(ICulledOffsetSegment, Option(ICulledOffsetSegment)), Error) {
  use found <- result.try(
    overlaps.segment(left.segment, right.segment) |> result.map_error(PathError),
  )
  case adjacent_endpoint_overlap(found) {
    Error(_) -> Ok(#(left, Some(right)))
    Ok(overlap) -> {
      let overlaps.SegmentOverlap(left_from:, right_from:, right_to:, ..) =
        overlap
      let right_end = float.max(right_from, right_to)
      use shared <- result.try(
        svg_path.segment_point(right.segment, at: right_end)
        |> result.map_error(PathError),
      )
      use left_segment <- result.try(
        svg_path.segment_between_inside(left.segment, from: 0.0, to: left_from)
        |> result.map_error(PathError),
      )
      let left =
        ICulledOffsetSegment(
          ..left,
          segment: segment_with_end(left_segment, shared),
          preimage_to: interval_parameter(
            left.preimage_from,
            left.preimage_to,
            left_from,
          ),
        )
      case right_end >=. 1.0 -. adjacent_loop_endpoint_parameter_tolerance {
        True -> Ok(#(left, None))
        False -> {
          use right_segment <- result.try(
            svg_path.segment_between_inside(
              right.segment,
              from: right_end,
              to: 1.0,
            )
            |> result.map_error(PathError),
          )
          Ok(#(
            left,
            Some(
              ICulledOffsetSegment(
                ..right,
                segment: segment_with_start(right_segment, shared),
                preimage_from: interval_parameter(
                  right.preimage_from,
                  right.preimage_to,
                  right_end,
                ),
              ),
            ),
          ))
        }
      }
    }
  }
}

fn adjacent_endpoint_overlap(
  found: List(overlaps.SegmentOverlap),
) -> Result(overlaps.SegmentOverlap, Nil) {
  case found {
    [] -> Error(Nil)
    [first, ..rest] -> {
      let overlaps.SegmentOverlap(
        left_from:,
        left_to:,
        right_from:,
        right_to:,
        ..,
      ) = first
      let right_start = float.min(right_from, right_to)
      case
        left_from <. 1.0
        && left_to >=. 1.0 -. adjacent_loop_endpoint_parameter_tolerance
        && right_start <=. adjacent_loop_endpoint_parameter_tolerance
        && float.max(right_from, right_to) >. 0.0
      {
        True -> Ok(first)
        False -> adjacent_endpoint_overlap(rest)
      }
    }
  }
}

fn h_preimage_is_reversed(preimage: HPreimageSegment) -> Bool {
  let HPreimageSegment(segment: offset_segment, source:) = preimage
  case source {
    HealedPreimage(GHealedOffsetSegment(
      source: OffsetFromJoinFree(EJoinFreeSegment(segment: source_segment, ..)),
      ..,
    )) ->
      case
        unit_tangent(offset_segment, t: 0.5),
        unit_tangent(source_segment, t: 0.5)
      {
        Ok(offset_tangent), Ok(source_tangent) ->
          point_helpers.dot(offset_tangent, source_tangent) <. 0.0
        _, _ -> False
      }
    HealedPreimage(GHealedOffsetSegment(source: OffsetFromStalledRun(_), ..)) ->
      False
    JoinPreimage(reversed:, ..) -> reversed
  }
}

fn replace_last_culled_offset(
  segments: List(ICulledOffsetSegment),
  replacement: ICulledOffsetSegment,
) -> List(ICulledOffsetSegment) {
  case segments {
    [] -> []
    [_] -> [replacement]
    [first, ..rest] -> [first, ..replace_last_culled_offset(rest, replacement)]
  }
}

fn culled_offset_subpath_segments(
  subpath: ICulledOffsetSubpath,
) -> List(svg_path.Segment) {
  let ICulledOffsetSubpath(segments:, ..) = subpath
  list.map(segments, fn(segment) { segment.segment })
}

/// Trim one I-side in source order while using an arrangement for noding and
/// winding classification only.
///
/// The offset and its zero source define a temporary closed semantic band.
/// Arrangement edges whose measured winding disagrees with that band are
/// initial deletion candidates. A maximal candidate run is rescued unless it
/// contains REVERSED geometry. Parity-capacity reduction then removes forced
/// dangling material and reconstructs source-ordered survivors.
///
/// Contract: return `None` when nothing survives; otherwise return exactly one
/// cusp-trimmed subpath with the same open/closed topology as the input and,
/// for an open input, the same endpoint vertices. Multiple survivors are an
/// internal error.
fn cusp_trim_i_subpath(
  subpath: ICulledOffsetSubpath,
  zero_source: svg_path.Subpath,
  offset: Float,
  options: Options,
) -> Result(Option(CuspTrimmedSubpath), Error) {
  let ICulledOffsetSubpath(segments:, closed:, ..) = subpath
  case segments {
    [] -> Ok(None)
    [_, ..] -> {
      use geometry <- result.try(subpath_from_synchronized_segments(
        list.map(segments, fn(segment) { segment.segment }),
        closed:,
        tolerance: options.fitting.tolerance,
      ))
      use band <- result.try(band_from_sides(zero_source, 0.0, geometry, offset))
      use winding <- result.try(internal_band_winding_function([band]))
      use build <- result.try(single_offset_segment_arrangement(
        [geometry],
        zero_source_segments: svg_path.subpath_segments(zero_source),
        offset:,
      ))
      use split <- result.try(arrangement_split_subpath_from_i_arrangement(
        subpath,
        build,
        winding,
      ))
      let rescued = rescue_arrangement_split_submerged_runs(split)
      finish_cusp_trim_with_parity(split, rescued, build)
    }
  }
}

fn finish_cusp_trim_with_parity(
  split: ArrangementSplitTracedSubpath,
  rescued: List(ArrangementSplitTracedSegment),
  build: OffsetArrangementBuild,
) -> Result(Option(CuspTrimmedSubpath), Error) {
  let ArrangementSplitTracedSubpath(segments: original, closed:, ..) = split
  let retained =
    list.filter(rescued, fn(segment) { !segment.deletion_candidate })
  case retained {
    [] -> Ok(None)
    [_, ..] -> {
      use endpoints <- result.try(cusp_trim_expected_endpoints(original, closed))
      let #(expected_start, expected_end) = endpoints
      let OffsetArrangementBuild(graph:, ..) = build
      let protected = case closed {
        True -> []
        False -> [expected_start, expected_end]
      }
      use chains <- result.try(cusp_trim_parity_survivor_chains(
        retained,
        graph,
        protected_vertices: protected,
      ))
      case chains {
        [chain] ->
          cusp_trim_subpath_from_chain(
            chain,
            closed,
            expected_start,
            expected_end,
          )
          |> result.map(Some)
        _ -> Error(InternalIToKSubpathCount(list.length(chains)))
      }
    }
  }
}

fn cusp_trim_parity_survivor_chains(
  segments: List(ArrangementSplitTracedSegment),
  graph: arrangement_graph.ArrangementGraph,
  protected_vertices protected_vertices: List(Int),
) -> Result(List(SurvivorChain), Error) {
  let retained =
    list.filter(segments, fn(segment) { !segment.deletion_candidate })
  case retained {
    [] -> Ok([])
    [_, ..] -> {
      let initial = arrangement_split_edge_capacities(graph, retained)
      use assignments <- result.try(
        arrangement_graph.forced_parity_capacities_with(
          graph,
          initial,
          vertex_parities: protected_vertex_parities(protected_vertices),
        )
        |> result.map_error(ForcedParityPruningError),
      )
      arrangement_split_parity_chains_from_assignments(retained, assignments)
    }
  }
}

fn arrangement_split_parity_chains_from_assignments(
  retained: List(ArrangementSplitTracedSegment),
  assignments: List(arrangement_graph.EdgeCapacityAssignment),
) -> Result(List(SurvivorChain), Error) {
  let available =
    assignments
    |> list.filter_map(fn(assignment) {
      case assignment.capacity > 0 {
        True ->
          Ok(AvailableEdgeCapacity(assignment.edge_id, assignment.capacity))
        False -> Error(Nil)
      }
    })
  use result <- result.try(
    arrangement_split_source_order_survivor_chains(
      retained,
      available,
      open: [],
    ),
  )
  let #(chains, remaining) = result
  use _ <- result.try(assert_capacities_consumed(remaining))
  Ok(chains)
}

fn arrangement_split_walk_to_survivor_chain(
  walk: List(ArrangementSplitTracedSegment),
) -> SurvivorChain {
  let assert [first, ..rest] = walk
  let initial =
    SurvivorChain(
      start_vertex: first.start_vertex,
      end_vertex: first.end_vertex,
      edges: [arrangement_split_survivor_edge(first)],
      closed: first.start_vertex == first.end_vertex,
    )
  rest
  |> list.fold(initial, fn(chain, segment) {
    SurvivorChain(
      ..chain,
      end_vertex: segment.end_vertex,
      edges: [arrangement_split_survivor_edge(segment), ..chain.edges],
      closed: chain.start_vertex == segment.end_vertex,
    )
  })
  |> fn(chain) { SurvivorChain(..chain, edges: list.reverse(chain.edges)) }
}

fn arrangement_split_survivor_edge(
  segment: ArrangementSplitTracedSegment,
) -> SurvivorEdge {
  SurvivorEdge(
    edge_id: segment.edge_id,
    reversed: False,
    start_vertex: segment.start_vertex,
    end_vertex: segment.end_vertex,
    segment: segment.segment,
    arrangement_preimage: Some(segment),
  )
}

fn arrangement_split_segments_from_survivor_chains(
  chains: List(SurvivorChain),
) -> List(ArrangementSplitTracedSegment) {
  chains
  |> list.flat_map(fn(chain) { chain.edges })
  |> list.filter_map(fn(edge) {
    case edge.arrangement_preimage {
      Some(preimage) -> Ok(preimage)
      None -> Error(Nil)
    }
  })
}

fn cusp_trim_expected_endpoints(
  segments: List(ArrangementSplitTracedSegment),
  closed: Bool,
) -> Result(#(Int, Int), Error) {
  case segments {
    [] -> Error(InternalSegmentImageCountMismatch)
    [first, ..] -> {
      use last <- result.try(
        last_arrangement_split_segment(segments)
        |> result.map_error(fn(_) { InternalSegmentImageCountMismatch }),
      )
      case closed {
        True -> Ok(#(first.start_vertex, first.start_vertex))
        False -> Ok(#(first.start_vertex, last.end_vertex))
      }
    }
  }
}

fn arrangement_split_edge_capacities(
  graph: arrangement_graph.ArrangementGraph,
  retained: List(ArrangementSplitTracedSegment),
) -> List(arrangement_graph.EdgeCapacityAssignment) {
  let arrangement_graph.ArrangementGraph(edges:, ..) = graph
  list.map(edges, fn(edge) {
    arrangement_graph.EdgeCapacityAssignment(
      edge.id,
      retained
        |> list.filter(fn(segment) { segment.edge_id == edge.id })
        |> list.length,
    )
  })
}

fn arrangement_split_source_order_survivor_chains(
  segments: List(ArrangementSplitTracedSegment),
  available: List(AvailableEdgeCapacity),
  open open: List(SurvivorChain),
) -> Result(#(List(SurvivorChain), List(AvailableEdgeCapacity)), Error) {
  case segments {
    [] -> Ok(#(list.reverse(open), available))
    [segment, ..rest] ->
      case take_edge_capacity(segment.edge_id, available) {
        Error(Nil) ->
          arrangement_split_source_order_survivor_chains(rest, available, open:)
        Ok(available) -> {
          let edge =
            SurvivorEdge(
              edge_id: segment.edge_id,
              reversed: False,
              start_vertex: segment.start_vertex,
              end_vertex: segment.end_vertex,
              segment: segment.segment,
              arrangement_preimage: Some(segment),
            )
          arrangement_split_source_order_survivor_chains(
            rest,
            available,
            open: append_source_order_edge(edge, open:),
          )
        }
      }
  }
}

fn cusp_trim_subpath_from_chain(
  chain: SurvivorChain,
  expected_closed: Bool,
  expected_start: Int,
  expected_end: Int,
) -> Result(CuspTrimmedSubpath, Error) {
  use chain <- result.try(case expected_closed {
    True ->
      case chain.closed {
        True -> Ok(chain)
        False -> Error(InternalIToKExpectedClosedSubpath)
      }
    False ->
      case
        chain.start_vertex == expected_start && chain.end_vertex == expected_end,
        chain.start_vertex == expected_end && chain.end_vertex == expected_start
      {
        True, _ -> Ok(chain)
        False, True -> Ok(reverse_survivor_chain(chain))
        False, False ->
          Error(InternalIToKEndpointMismatch(
            expected_start:,
            actual_start: chain.start_vertex,
            expected_end:,
            actual_end: chain.end_vertex,
          ))
      }
  })
  use segments <- result.try(
    chain.edges
    |> list.try_map(fn(edge) {
      case edge.arrangement_preimage {
        None -> Error(InternalIToKMissingJPreimage(edge.edge_id))
        Some(preimage) ->
          Ok(CuspTrimmedSegment(
            segment: edge.segment,
            arrangement_preimage: preimage,
          ))
      }
    }),
  )
  Ok(CuspTrimmedSubpath(segments:, closed: expected_closed))
}

fn arrangement_split_subpath_from_i_arrangement(
  subpath: ICulledOffsetSubpath,
  build: OffsetArrangementBuild,
  winding: fn(svg_path.Point) -> Result(Int, Error),
) -> Result(ArrangementSplitTracedSubpath, Error) {
  let ICulledOffsetSubpath(segments:, closed:, side:) = subpath
  let OffsetArrangementBuild(segment_images:, ..) = build
  use image_span <- result.try(take_segment_images(
    segment_images,
    list.length(segments),
  ))
  let #(images, _) = image_span
  use split_segments <- result.try(
    arrangement_split_segments_from_i_images(
      segments,
      images,
      build,
      winding,
      split: [],
    ),
  )
  Ok(ArrangementSplitTracedSubpath(segments: split_segments, closed:, side:))
}

fn arrangement_split_segments_from_i_images(
  segments: List(ICulledOffsetSegment),
  images: List(arrangement_graph.ArrangementSourceSegmentImage),
  build: OffsetArrangementBuild,
  winding: fn(svg_path.Point) -> Result(Int, Error),
  split split: List(ArrangementSplitTracedSegment),
) -> Result(List(ArrangementSplitTracedSegment), Error) {
  case segments, images {
    [], [] -> Ok(list.reverse(split))
    [segment, ..remaining_segments], [image, ..remaining_images] -> {
      use pieces <- result.try(
        arrangement_split_segments_from_i_image(
          segment,
          image,
          build,
          winding,
          split: [],
        ),
      )
      arrangement_split_segments_from_i_images(
        remaining_segments,
        remaining_images,
        build,
        winding,
        split: list.append(list.reverse(pieces), split),
      )
    }
    _, _ -> Error(InternalSegmentImageCountMismatch)
  }
}

fn arrangement_split_segments_from_i_image(
  source: ICulledOffsetSegment,
  image: arrangement_graph.ArrangementSourceSegmentImage,
  build: OffsetArrangementBuild,
  winding: fn(svg_path.Point) -> Result(Int, Error),
  split split: List(ArrangementSplitTracedSegment),
) -> Result(List(ArrangementSplitTracedSegment), Error) {
  let arrangement_graph.ArrangementSourceSegmentImage(edges:, ..) = image
  arrangement_split_segments_from_i_edge_images(
    source,
    edges,
    build,
    winding,
    split:,
  )
}

fn arrangement_split_segments_from_i_edge_images(
  source: ICulledOffsetSegment,
  images: List(arrangement_graph.ArrangementSegmentEdgeImage),
  build: OffsetArrangementBuild,
  winding: fn(svg_path.Point) -> Result(Int, Error),
  split split: List(ArrangementSplitTracedSegment),
) -> Result(List(ArrangementSplitTracedSegment), Error) {
  case images {
    [] -> Ok(list.reverse(split))
    [image, ..rest] -> {
      let arrangement_graph.ArrangementSegmentEdgeImage(
        ta:,
        tb:,
        edge_id:,
        reversed: edge_reversed,
        ..,
      ) = image
      let OffsetArrangementBuild(
        graph: arrangement_graph.ArrangementGraph(edges: graph_edges, ..),
        ..,
      ) = build
      use edge <- result.try(
        arrangement_edge_by_id(graph_edges, edge_id)
        |> result.map_error(ArrangementGraphError),
      )
      let arrangement_graph.ArrangementEdge(
        segment: edge_segment,
        start_vertex: edge_start,
        end_vertex: edge_end,
        ..,
      ) = edge
      use matches <- result.try(arrangement_edge_winding_matches_opinion(
        build,
        edge,
        winding:,
        side_sampling_distance: submerged_side_sampling_distance,
      ))
      let #(segment, start_vertex, end_vertex) = case edge_reversed {
        True -> #(svg_path.segment_reverse(edge_segment), edge_end, edge_start)
        False -> #(edge_segment, edge_start, edge_end)
      }
      let preimage_from =
        interval_parameter(source.preimage_from, source.preimage_to, ta)
      let preimage_to =
        interval_parameter(source.preimage_from, source.preimage_to, tb)
      arrangement_split_segments_from_i_edge_images(
        source,
        rest,
        build,
        winding,
        split: [
          ArrangementSplitTracedSegment(
            segment:,
            preimage: source,
            preimage_from:,
            preimage_to:,
            edge_id:,
            start_vertex:,
            end_vertex:,
            reversed: h_preimage_is_reversed(source.preimage),
            deletion_candidate: !matches,
          ),
          ..split
        ],
      )
    }
  }
}

fn rescue_arrangement_split_submerged_runs(
  subpath: ArrangementSplitTracedSubpath,
) -> List(ArrangementSplitTracedSegment) {
  let ArrangementSplitTracedSubpath(segments:, closed:, ..) = subpath
  let runs = arrangement_split_runs(segments, runs: [])
  let rescued = list.map(runs, rescue_arrangement_split_run)
  let rescued = case closed, runs {
    True, [first, _, ..] -> {
      let assert Ok(last) = last_arrangement_split_run(runs)
      case first.submerged && last.submerged {
        False -> rescued
        True -> {
          let wrapping_reversed =
            arrangement_split_run_contains_reversed(first)
            || arrangement_split_run_contains_reversed(last)
          rescued
          |> replace_first_arrangement_split_run(
            ArrangementSplitRun(
              ..first,
              segments: set_arrangement_split_segments_submerged(
                first.segments,
                wrapping_reversed,
              ),
            ),
          )
          |> replace_last_arrangement_split_run(
            ArrangementSplitRun(
              ..last,
              segments: set_arrangement_split_segments_submerged(
                last.segments,
                wrapping_reversed,
              ),
            ),
          )
        }
      }
    }
    _, _ -> rescued
  }
  rescued |> list.flat_map(fn(run) { run.segments })
}

fn arrangement_split_runs(
  segments: List(ArrangementSplitTracedSegment),
  runs runs: List(ArrangementSplitRun),
) -> List(ArrangementSplitRun) {
  case segments {
    [] -> list.reverse(runs)
    [first, ..rest] -> {
      let #(same, remaining) =
        take_arrangement_split_run(rest, first.deletion_candidate, taken: [
          first,
        ])
      arrangement_split_runs(remaining, runs: [
        ArrangementSplitRun(segments: same, submerged: first.deletion_candidate),
        ..runs
      ])
    }
  }
}

fn take_arrangement_split_run(
  segments: List(ArrangementSplitTracedSegment),
  submerged: Bool,
  taken taken: List(ArrangementSplitTracedSegment),
) -> #(List(ArrangementSplitTracedSegment), List(ArrangementSplitTracedSegment)) {
  case segments {
    [first, ..rest] if first.deletion_candidate == submerged ->
      take_arrangement_split_run(rest, submerged, taken: [first, ..taken])
    _ -> #(list.reverse(taken), segments)
  }
}

fn rescue_arrangement_split_run(
  run: ArrangementSplitRun,
) -> ArrangementSplitRun {
  case run.submerged && !arrangement_split_run_contains_reversed(run) {
    True ->
      ArrangementSplitRun(
        ..run,
        segments: set_arrangement_split_segments_submerged(run.segments, False),
      )
    False -> run
  }
}

fn arrangement_split_run_contains_reversed(run: ArrangementSplitRun) -> Bool {
  list.any(run.segments, fn(segment) { segment.reversed })
}

fn set_arrangement_split_segments_submerged(
  segments: List(ArrangementSplitTracedSegment),
  submerged: Bool,
) -> List(ArrangementSplitTracedSegment) {
  list.map(segments, fn(segment) {
    ArrangementSplitTracedSegment(..segment, deletion_candidate: submerged)
  })
}

/// Decompose the non-offside arrangement-split segments into maximal closed
/// source-ordered walks. Unlike cusp trimming, offside trimming intentionally
/// permits several survivors from one closed input walk; each resulting chain
/// is raised independently into a TracedOffsetSubpath carrying the same
/// source-subpath identity.
fn offside_survivor_chains(
  segments: List(ArrangementSplitTracedSegment),
) -> List(SurvivorChain) {
  offside_closed_walk_decomposition(segments)
  |> list.map(arrangement_split_walk_to_survivor_chain)
}

fn offside_closed_walk(
  segments: List(ArrangementSplitTracedSegment),
) -> List(ArrangementSplitTracedSegment) {
  let available =
    segments
    |> list.index_map(fn(segment, index) { #(segment, index) })
    |> list.filter(fn(indexed) {
      let #(segment, _) = indexed
      !segment.deletion_candidate
    })
  let #(_, best) = offside_closed_walk_loop(available, states: [], best: None)
  case best {
    None -> []
    Some(OffsideClosedWalkState(segments_reversed:, ..)) ->
      list.reverse(segments_reversed)
  }
}

fn offside_closed_walk_decomposition(
  segments: List(ArrangementSplitTracedSegment),
) -> List(List(ArrangementSplitTracedSegment)) {
  let walk = offside_closed_walk(segments)
  case walk {
    [] -> []
    [_, ..] -> {
      let remaining =
        list.filter(segments, fn(segment) { !list.contains(walk, segment) })
      [walk, ..offside_closed_walk_decomposition(remaining)]
    }
  }
}

fn offside_closed_walk_loop(
  segments: List(#(ArrangementSplitTracedSegment, Int)),
  states states: List(OffsideClosedWalkState),
  best best: Option(OffsideClosedWalkState),
) -> #(List(OffsideClosedWalkState), Option(OffsideClosedWalkState)) {
  case segments {
    [] -> #(states, best)
    [indexed, ..rest] -> {
      let #(segment, index) = indexed
      let starting = offside_closed_walk_start(segment, index)
      let extended =
        states
        |> list.filter(fn(state) { state.end_vertex == segment.start_vertex })
        |> list.map(fn(state) {
          offside_closed_walk_extend(state, segment, index)
        })
      let new_states = [starting, ..extended]
      let states =
        new_states
        |> list.fold(states, insert_better_offside_closed_walk_state)
      let best =
        new_states
        |> list.filter(fn(state) {
          state.end_vertex == state.first_start_vertex
        })
        |> list.fold(best, fn(best, candidate) {
          case best {
            None -> Some(candidate)
            Some(current) ->
              case offside_closed_walk_is_better(candidate, current) {
                True -> Some(candidate)
                False -> best
              }
          }
        })
      offside_closed_walk_loop(rest, states:, best:)
    }
  }
}

fn offside_closed_walk_start(
  segment: ArrangementSplitTracedSegment,
  index: Int,
) -> OffsideClosedWalkState {
  OffsideClosedWalkState(
    first_start_vertex: segment.start_vertex,
    end_vertex: segment.end_vertex,
    last_index: index,
    retained_span: offside_segment_span(segment),
    skipped_runs: 0,
    indices_reversed: [index],
    segments_reversed: [segment],
  )
}

fn offside_closed_walk_extend(
  state: OffsideClosedWalkState,
  segment: ArrangementSplitTracedSegment,
  index: Int,
) -> OffsideClosedWalkState {
  OffsideClosedWalkState(
    ..state,
    end_vertex: segment.end_vertex,
    last_index: index,
    retained_span: state.retained_span +. offside_segment_span(segment),
    skipped_runs: state.skipped_runs
      + case index == state.last_index + 1 {
        True -> 0
        False -> 1
      },
    indices_reversed: [index, ..state.indices_reversed],
    segments_reversed: [segment, ..state.segments_reversed],
  )
}

fn offside_segment_span(segment: ArrangementSplitTracedSegment) -> Float {
  float.absolute_value(segment.preimage_to -. segment.preimage_from)
}

fn insert_better_offside_closed_walk_state(
  states: List(OffsideClosedWalkState),
  candidate: OffsideClosedWalkState,
) -> List(OffsideClosedWalkState) {
  case states {
    [] -> [candidate]
    [first, ..rest] -> {
      let same_state =
        first.first_start_vertex == candidate.first_start_vertex
        && first.end_vertex == candidate.end_vertex
        && first.last_index == candidate.last_index
      case same_state {
        True ->
          case offside_closed_walk_is_better(candidate, first) {
            True -> [candidate, ..rest]
            False -> states
          }
        False -> [
          first,
          ..insert_better_offside_closed_walk_state(rest, candidate)
        ]
      }
    }
  }
}

fn offside_closed_walk_is_better(
  candidate: OffsideClosedWalkState,
  current: OffsideClosedWalkState,
) -> Bool {
  case
    candidate.retained_span >. current.retained_span,
    candidate.retained_span <. current.retained_span
  {
    True, _ -> True
    _, True -> False
    False, False ->
      case
        candidate.skipped_runs < current.skipped_runs,
        candidate.skipped_runs > current.skipped_runs
      {
        True, _ -> True
        _, True -> False
        False, False ->
          int_list_lexicographically_before(
            list.reverse(candidate.indices_reversed),
            list.reverse(current.indices_reversed),
          )
      }
  }
}

fn int_list_lexicographically_before(
  left: List(Int),
  right: List(Int),
) -> Bool {
  case left, right {
    [], [] -> False
    [], [_, ..] -> True
    [_, ..], [] -> False
    [left_first, ..left_rest], [right_first, ..right_rest] ->
      case left_first < right_first, left_first > right_first {
        True, _ -> True
        _, True -> False
        False, False -> int_list_lexicographically_before(left_rest, right_rest)
      }
  }
}

fn last_arrangement_split_run(
  runs: List(ArrangementSplitRun),
) -> Result(ArrangementSplitRun, Nil) {
  case runs {
    [] -> Error(Nil)
    [run] -> Ok(run)
    [_, ..rest] -> last_arrangement_split_run(rest)
  }
}

fn replace_first_arrangement_split_run(
  runs: List(ArrangementSplitRun),
  replacement: ArrangementSplitRun,
) -> List(ArrangementSplitRun) {
  case runs {
    [] -> []
    [_, ..rest] -> [replacement, ..rest]
  }
}

fn replace_last_arrangement_split_run(
  runs: List(ArrangementSplitRun),
  replacement: ArrangementSplitRun,
) -> List(ArrangementSplitRun) {
  case runs {
    [] -> []
    [_] -> [replacement]
    [first, ..rest] -> [
      first,
      ..replace_last_arrangement_split_run(rest, replacement)
    ]
  }
}

fn last_arrangement_split_segment(
  segments: List(ArrangementSplitTracedSegment),
) -> Result(ArrangementSplitTracedSegment, Nil) {
  case segments {
    [] -> Error(Nil)
    [segment] -> Ok(segment)
    [_, ..rest] -> last_arrangement_split_segment(rest)
  }
}

fn cusp_trimmed_subpath_geometry(
  subpath: CuspTrimmedSubpath,
  tolerance: Float,
) -> Result(svg_path.Subpath, Error) {
  let CuspTrimmedSubpath(segments:, closed:) = subpath
  subpath_from_synchronized_segments(
    list.map(segments, fn(segment) { segment.segment }),
    closed:,
    tolerance:,
  )
}

fn parametric_join_segments(
  left: GHealedOffsetSegment,
  right: GHealedOffsetSegment,
  offset: Float,
  join: Join,
) -> Result(List(svg_path.Segment), Error) {
  let start = svg_path.segment_end(left.segment)
  let end = svg_path.segment_start(right.segment)
  case point_helpers.near(start, end, tolerance: point_tolerance) {
    True -> Ok([])
    False ->
      case join {
        Bevel -> Ok(line_segments_between([start, end]))
        Miter(miter_limit) ->
          directed_miter_join(left, right, start, end, offset, miter_limit)
        Round -> round_join(left, right, start, end, offset)
      }
  }
}

fn synchronized_join_correspondences(
  portions: List(SynchronizedHealedPortion),
  distances: OffsetDistances,
  join: Join,
  closed closed: Bool,
) -> Result(List(OffsetJoinCorrespondence), Error) {
  case portions {
    [] | [_] -> Ok([])
    [first, second, ..rest] ->
      synchronized_join_correspondences_loop(
        first,
        first,
        [second, ..rest],
        distances,
        join,
        closed:,
        joined: [],
      )
  }
}

fn synchronized_join_correspondences_loop(
  first: SynchronizedHealedPortion,
  previous: SynchronizedHealedPortion,
  rest: List(SynchronizedHealedPortion),
  distances: OffsetDistances,
  join: Join,
  closed closed: Bool,
  joined joined: List(OffsetJoinCorrespondence),
) -> Result(List(OffsetJoinCorrespondence), Error) {
  case rest {
    [] ->
      case closed {
        False -> Ok(list.reverse(joined))
        True -> {
          use closing <- result.try(synchronized_join_correspondence(
            previous,
            first,
            distances,
            join,
          ))
          Ok(list.reverse([closing, ..joined]))
        }
      }
    [next, ..remaining] -> {
      use correspondence <- result.try(synchronized_join_correspondence(
        previous,
        next,
        distances,
        join,
      ))
      synchronized_join_correspondences_loop(
        first,
        next,
        remaining,
        distances,
        join,
        closed:,
        joined: [correspondence, ..joined],
      )
    }
  }
}

fn synchronized_join_correspondence(
  left: SynchronizedHealedPortion,
  right: SynchronizedHealedPortion,
  distances: OffsetDistances,
  join: Join,
) -> Result(OffsetJoinCorrespondence, Error) {
  let SynchronizedHealedPortion(
    portion_index:,
    inner: left_inner,
    outer: left_outer,
  ) = left
  let SynchronizedHealedPortion(inner: right_inner, outer: right_outer, ..) =
    right
  let OffsetDistances(inner:, outer:) = distances
  use inner_join <- result.try(join_between_offset_portions(
    left_inner,
    right_inner,
    inner,
    join,
  ))
  use outer_join <- result.try(join_between_offset_portions(
    left_outer,
    right_outer,
    outer,
    join,
  ))
  use inner_boundary <- result.try(offset_portion_join_boundary(
    left_inner,
    right_inner,
  ))
  use outer_boundary <- result.try(offset_portion_join_boundary(
    left_outer,
    right_outer,
  ))
  let #(inner_start, inner_end) = inner_boundary
  let #(outer_start, outer_end) = outer_boundary
  use inner_reversed <- result.try(join_is_geometrically_reversed(
    left_inner,
    right_inner,
    inner_start,
    inner_end,
  ))
  use outer_reversed <- result.try(join_is_geometrically_reversed(
    left_outer,
    right_outer,
    outer_start,
    outer_end,
  ))
  Ok(OffsetJoinCorrespondence(
    after_portion_index: portion_index,
    inner: inner_join,
    outer: outer_join,
    inner_reversed:,
    outer_reversed:,
    inner_start:,
    inner_end:,
    outer_start:,
    outer_end:,
  ))
}

fn join_is_geometrically_reversed(
  left: List(GHealedOffsetSegment),
  right: List(GHealedOffsetSegment),
  join_start: svg_path.Point,
  join_end: svg_path.Point,
) -> Result(Bool, Error) {
  use previous <- result.try(last_list_item(left))
  use next <- result.try(case right {
    [first, ..] -> Ok(first)
    [] -> Error(DegenerateTangent(0.0))
  })
  use incoming <- result.try(offset_source_endpoint_unit_tangent(
    previous.source,
    endpoint: SegmentEnd,
  ))
  use outgoing <- result.try(offset_source_endpoint_unit_tangent(
    next.source,
    endpoint: SegmentStart,
  ))
  let average_direction = point_helpers.add(incoming, outgoing)
  let join_chord = point_helpers.subtract(join_end, join_start)
  Ok(point_helpers.dot(average_direction, join_chord) <. 0.0)
}

fn offset_source_endpoint_unit_tangent(
  source: OffsetSegmentSource,
  endpoint endpoint: SegmentEndpoint,
) -> Result(svg_path.Point, Error) {
  case source {
    OffsetFromJoinFree(EJoinFreeSegment(segment:, ..)) ->
      unit_tangent_at_endpoint(segment, endpoint:)
    OffsetFromStalledRun(run) -> {
      use segment <- result.try(case endpoint {
        SegmentStart ->
          case run {
            [CStalledSegment(segment:, ..), ..] -> Ok(segment)
            [] -> Error(DegenerateTangent(0.0))
          }
        SegmentEnd -> {
          use last <- result.try(last_list_item(run))
          let CStalledSegment(segment:, ..) = last
          Ok(segment)
        }
      })
      unit_tangent_at_endpoint(segment, endpoint:)
    }
  }
}

fn offset_portion_join_boundary(
  left: List(GHealedOffsetSegment),
  right: List(GHealedOffsetSegment),
) -> Result(#(svg_path.Point, svg_path.Point), Error) {
  case list.last(left), right {
    Ok(previous), [next, ..] ->
      Ok(#(
        svg_path.segment_end(previous.segment),
        svg_path.segment_start(next.segment),
      ))
    _, _ -> Error(DegenerateTangent(0.0))
  }
}

fn join_between_offset_portions(
  left: List(GHealedOffsetSegment),
  right: List(GHealedOffsetSegment),
  offset: Float,
  join: Join,
) -> Result(List(svg_path.Segment), Error) {
  case list.last(left), right {
    Ok(previous), [next, ..] ->
      parametric_join_segments(previous, next, offset, join)
    _, _ -> Ok([])
  }
}

fn closed_stroke_path(
  source: svg_path.Subpath,
  radius radius: Float,
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use band <- result.try(untrimmed_stroke_band(
    source,
    radius *. 2.0,
    Butt,
    options,
  ))
  case band {
    OpenSubpathBand(_) -> Error(BandSubpathNotClosed)
    ClosedSubpathBand(exterior, interior) ->
      topological_band_path_with_opinions(
        [interior, exterior],
        [band],
        [
          WindingSideOpinion(left: 1, right: 0),
          WindingSideOpinion(left: 0, right: 1),
        ],
        options,
      )
  }
}

fn orient_band_path(
  path: svg_path.Path,
  winding: fn(svg_path.Point) -> Result(Int, Error),
) -> Result(svg_path.Path, Error) {
  use subpaths <- result.try(
    orient_band_subpaths(svg_path.path_subpaths(path), winding, oriented: []),
  )
  Ok(svg_path.Path(subpaths:))
}

fn orient_band_subpaths(
  subpaths: List(svg_path.Subpath),
  winding: fn(svg_path.Point) -> Result(Int, Error),
  oriented oriented: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(oriented))
    [first, ..rest] -> {
      use oriented_first <- result.try(case svg_path.subpath_is_closed(first) {
        False -> Ok(first)
        True ->
          orient_band_subpath(first, svg_path.subpath_segments(first), winding)
      })
      orient_band_subpaths(rest, winding, oriented: [oriented_first, ..oriented])
    }
  }
}

fn orient_band_subpath(
  subpath: svg_path.Subpath,
  segments: List(svg_path.Segment),
  winding: fn(svg_path.Point) -> Result(Int, Error),
) -> Result(svg_path.Subpath, Error) {
  case segments {
    [] -> Ok(subpath)
    [first, ..rest] -> {
      use point <- result.try(
        svg_path.segment_point(first, at: 0.5) |> result.map_error(PathError),
      )
      case unit_normal(first, t: 0.5) {
        Error(_) -> orient_band_subpath(subpath, rest, winding)
        Ok(normal) -> {
          use left <- result.try(
            winding(point_helpers.add(
              point,
              point_helpers.scale(
                normal,
                band_orientation_side_sampling_distance,
              ),
            )),
          )
          use right <- result.try(
            winding(point_helpers.add(
              point,
              point_helpers.scale(
                normal,
                0.0 -. band_orientation_side_sampling_distance,
              ),
            )),
          )
          case right > left, left > right {
            True, False -> Ok(subpath)
            False, True -> Ok(svg_path.subpath_reverse(subpath))
            _, _ -> orient_band_subpath(subpath, rest, winding)
          }
        }
      }
    }
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
  use containing_count <- result.try(outline_contour_depth_loop(
    probe,
    all,
    depth: 0,
  ))
  Ok(int.max(0, containing_count - 1))
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
  outline_contour_probe_segments(subpath, svg_path.subpath_segments(subpath))
}

fn outline_contour_probe_segments(
  subpath: svg_path.Subpath,
  segments: List(svg_path.Segment),
) -> Result(svg_path.Point, Error) {
  case segments {
    [] -> Error(PathError(svg_path.EmptySubpath))
    [first, ..rest] -> {
      use point <- result.try(
        svg_path.segment_point(first, at: 0.5) |> result.map_error(PathError),
      )
      case unit_normal(first, t: 0.5) {
        Error(_) -> outline_contour_probe_segments(subpath, rest)
        Ok(left_normal) -> {
          let distance =
            float.max(
              point_tolerance *. 10.0,
              svg_path.segment_chord_length(first) *. 0.0001,
            )
          let left =
            point_helpers.add(point, point_helpers.scale(left_normal, distance))
          let right =
            point_helpers.add(
              point,
              point_helpers.scale(left_normal, 0.0 -. distance),
            )
          use left_containment <- result.try(
            svg_path.subpath_containment(
              left,
              within: subpath,
              using: svg_path.Nonzero,
            )
            |> result.map_error(PathError),
          )
          use right_containment <- result.try(
            svg_path.subpath_containment(
              right,
              within: subpath,
              using: svg_path.Nonzero,
            )
            |> result.map_error(PathError),
          )
          case left_containment, right_containment {
            svg_path.Inside, svg_path.Outside -> Ok(left)
            svg_path.Outside, svg_path.Inside -> Ok(right)
            _, _ -> outline_contour_probe_segments(subpath, rest)
          }
        }
      }
    }
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

fn untrimmed_stroke_outline(
  source: svg_path.Subpath,
  radius: Float,
  cap: Cap,
  options: Options,
) -> Result(svg_path.Subpath, Error) {
  use normalized <- result.try(normalize_source_subpath(source, options))
  untrimmed_stroke_outline_from_normalized_source(
    normalized,
    radius,
    cap,
    options,
  )
}

fn untrimmed_stroke_outline_from_normalized_source(
  source: svg_path.Subpath,
  radius: Float,
  cap: Cap,
  options: Options,
) -> Result(svg_path.Subpath, Error) {
  use positive <- result.try(untrimmed_subpath_from_normalized_source(
    source,
    offset: radius,
    options:,
  ))
  use negative <- result.try(untrimmed_subpath_from_normalized_source(
    source,
    offset: 0.0 -. radius,
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
  let center = svg_path.subpath_start(subpath)
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
  let right = point_helpers.add(center, svg_path.Point(radius, 0.0))
  let left = point_helpers.add(center, svg_path.Point(0.0 -. radius, 0.0))
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
  let top_left =
    point_helpers.add(center, svg_path.Point(0.0 -. radius, 0.0 -. radius))
  let top_right =
    point_helpers.add(center, svg_path.Point(radius, 0.0 -. radius))
  let bottom_right = point_helpers.add(center, svg_path.Point(radius, radius))
  let bottom_left =
    point_helpers.add(center, svg_path.Point(0.0 -. radius, radius))
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
  let end = svg_path.subpath_end(source)
  let assert Ok(last) = list.last(svg_path.subpath_segments(source))
  use tangent <- result.try(unit_tangent(last, t: 1.0))
  stroke_cap_segments(center: end, tangent:, radius:, cap:, at_end: True)
}

fn stroke_start_cap(
  source: svg_path.Subpath,
  radius: Float,
  cap: Cap,
) -> Result(List(svg_path.Segment), Error) {
  let start = svg_path.subpath_start(source)
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
  let normal = point_helpers.rotate_counterclockwise(tangent)
  let positive = point_helpers.add(center, point_helpers.scale(normal, radius))
  let negative =
    point_helpers.add(center, point_helpers.scale(normal, 0.0 -. radius))
  case cap {
    Butt -> {
      case at_end {
        True -> Ok(line_segments_between([positive, negative]))
        False -> Ok(line_segments_between([negative, positive]))
      }
    }
    Square -> {
      let extension = case at_end {
        True -> point_helpers.scale(tangent, radius)
        False -> point_helpers.scale(tangent, 0.0 -. radius)
      }
      let positive_extended = point_helpers.add(positive, extension)
      let negative_extended = point_helpers.add(negative, extension)
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

fn build_synchronized_offset_segments(
  subpath: svg_path.Subpath,
  distances: OffsetDistances,
  options: Options,
) -> Result(SynchronizedOffsetSegmentsBuild, Error) {
  use portions <- result.try(join_free_portions(subpath, options))
  build_synchronized_offset_portions(
    portions,
    distances,
    options,
    inner_offsets: [],
    outer_offsets: [],
    correspondences: [],
    healed_portions: [],
  )
}

fn build_synchronized_offset_portions(
  portions: List(JoinFreePortion),
  distances: OffsetDistances,
  options: Options,
  inner_offsets inner_offsets: List(GHealedOffsetSegment),
  outer_offsets outer_offsets: List(GHealedOffsetSegment),
  correspondences correspondences: List(OffsetCorrespondence),
  healed_portions healed_portions: List(SynchronizedHealedPortion),
) -> Result(SynchronizedOffsetSegmentsBuild, Error) {
  case portions {
    [] ->
      Ok(SynchronizedOffsetSegmentsBuild(
        inner_offsets: list.reverse(inner_offsets),
        outer_offsets: list.reverse(outer_offsets),
        correspondences: list.reverse(correspondences),
        portions: list.reverse(healed_portions),
      ))
    [first, ..rest] -> {
      use built <- result.try(build_synchronized_offset_portion(
        first,
        distances,
        options,
      ))
      let SynchronizedOffsetSegmentsBuild(
        inner_offsets: next_inner,
        outer_offsets: next_outer,
        correspondences: next_correspondences,
        portions: next_portions,
      ) = built
      build_synchronized_offset_portions(
        rest,
        distances,
        options,
        inner_offsets: list.append(list.reverse(next_inner), inner_offsets),
        outer_offsets: list.append(list.reverse(next_outer), outer_offsets),
        correspondences: list.append(
          list.reverse(next_correspondences),
          correspondences,
        ),
        healed_portions: list.append(
          list.reverse(next_portions),
          healed_portions,
        ),
      )
    }
  }
}

fn build_synchronized_offset_portion(
  portion: JoinFreePortion,
  distances: OffsetDistances,
  options: Options,
) -> Result(SynchronizedOffsetSegmentsBuild, Error) {
  let JoinFreePortion(index:, subpath:, closed:) = portion
  let classified =
    subpath
    |> prepared_segments(source_subpath_index: 0)
    |> classify_prepared_segments_for_both_offsets(
      distances,
      options.stalled_offset_diameter,
    )
  use sources <- result.try(
    refine_synchronized_classified_segments(
      classified,
      distances,
      options.stalled_offset_diameter,
      refined: [],
    ),
  )
  use sources <- result.try(
    split_synchronized_double_reversal_segments(sources, distances, split: []),
  )
  use unhealed <- result.try(
    offset_synchronized_source_segments(
      sources,
      distances,
      options,
      index,
      correspondence_index: 0,
      inner_offsets: [],
      outer_offsets: [],
      correspondences: [],
    ),
  )
  let SynchronizedPortionUnhealedBuild(
    inner_offsets: inner_unhealed,
    outer_offsets: outer_unhealed,
    correspondences:,
  ) = unhealed
  let OffsetDistances(inner:, outer:) = distances
  let inner_unhealed =
    mark_cross_source_reversal_boundaries(inner_unhealed, inner, closed:)
  let outer_unhealed =
    mark_cross_source_reversal_boundaries(outer_unhealed, outer, closed:)
  use inner_healed <- result.try(heal_offset_boundaries(
    inner_unhealed,
    inner,
    options,
    closed:,
  ))
  use outer_healed <- result.try(heal_offset_boundaries(
    outer_unhealed,
    outer,
    options,
    closed:,
  ))
  use _ <- result.try(assert_smooth_offset_postconditions(
    g_healed_to_f_unhealed_offset_segments(inner_healed),
    options.tangent_heal_angle_degrees,
  ))
  use _ <- result.try(assert_smooth_offset_postconditions(
    g_healed_to_f_unhealed_offset_segments(outer_healed),
    options.tangent_heal_angle_degrees,
  ))
  Ok(
    SynchronizedOffsetSegmentsBuild(
      inner_offsets: inner_healed,
      outer_offsets: outer_healed,
      correspondences:,
      portions: [
        SynchronizedHealedPortion(
          portion_index: index,
          inner: inner_healed,
          outer: outer_healed,
        ),
      ],
    ),
  )
}

fn split_synchronized_double_reversal_segments(
  sources: List(SynchronizedSourceSegment),
  distances: OffsetDistances,
  split split: List(SynchronizedSourceSegment),
) -> Result(List(SynchronizedSourceSegment), Error) {
  case sources {
    [] -> Ok(list.reverse(split))
    [first, ..rest] -> {
      let SynchronizedSourceSegment(
        segment:,
        start_boundary: BoundaryPair(inner: inner_start, outer: outer_start),
        end_boundary: BoundaryPair(inner: inner_end, outer: outer_end),
        ..,
      ) = first
      let OffsetDistances(inner:, outer:) = distances
      let inner_double =
        boundary_reaches_offset_radius(inner_start, inner)
        && boundary_reaches_offset_radius(inner_end, inner)
      let outer_double =
        boundary_reaches_offset_radius(outer_start, outer)
        && boundary_reaches_offset_radius(outer_end, outer)
      case segment_is_bezier(segment) && { inner_double || outer_double } {
        False ->
          split_synchronized_double_reversal_segments(rest, distances, split: [
            first,
            ..split
          ])
        True -> {
          use children <- result.try(split_synchronized_source_at_midpoint(
            first,
          ))
          let #(left, right) = children
          split_synchronized_double_reversal_segments(rest, distances, split: [
            right,
            left,
            ..split
          ])
        }
      }
    }
  }
}

fn split_synchronized_source_at_midpoint(
  source: SynchronizedSourceSegment,
) -> Result(#(SynchronizedSourceSegment, SynchronizedSourceSegment), Error) {
  let SynchronizedSourceSegment(
    prepared_from:,
    prepared_to:,
    segment:,
    start_boundary:,
    end_boundary:,
    ..,
  ) = source
  use children <- result.try(
    svg_path.segment_split(segment, at: 0.5) |> result.map_error(PathError),
  )
  let #(left, right) = children
  let midpoint = prepared_from +. { prepared_to -. prepared_from } /. 2.0
  let ordinary = BoundaryPair(inner: Ordinary, outer: Ordinary)
  Ok(#(
    SynchronizedSourceSegment(
      ..source,
      prepared_to: midpoint,
      segment: left,
      start_boundary:,
      end_boundary: ordinary,
    ),
    SynchronizedSourceSegment(
      ..source,
      prepared_from: midpoint,
      segment: right,
      start_boundary: ordinary,
      end_boundary:,
    ),
  ))
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
  offset offset: Float,
  options options: Options,
) -> Result(List(OffsetSourceTracePortion), Error) {
  use _ <- result.try(validate_options(options))
  use normalized <- result.try(normalize_source_subpath(subpath, options))
  use portions <- result.try(join_free_portions(normalized, options))
  synchronized_offset_source_trace_portions(
    portions,
    offset,
    options,
    traced: [],
  )
}

/// Return the source leaves used by the production synchronized band builder.
@internal
pub fn internal_synchronized_offset_trace(
  subpath subpath: svg_path.Subpath,
  inner_offset inner_offset: Float,
  outer_offset outer_offset: Float,
  options options: Options,
) -> Result(List(SynchronizedOffsetTraceCorrespondence), Error) {
  use _ <- result.try(validate_options(options))
  use normalized <- result.try(normalize_source_subpath(subpath, options))
  use build <- result.try(build_synchronized_offset_segments(
    normalized,
    OffsetDistances(inner: inner_offset, outer: outer_offset),
    options,
  ))
  let SynchronizedOffsetSegmentsBuild(correspondences:, ..) = build
  Ok(list.map(correspondences, synchronized_offset_trace_correspondence))
}

/// Return the matched joins produced between synchronized offset portions.
@internal
pub fn internal_synchronized_join_trace(
  subpath subpath: svg_path.Subpath,
  inner_offset inner_offset: Float,
  outer_offset outer_offset: Float,
  options options: Options,
) -> Result(List(SynchronizedOffsetTraceJoin), Error) {
  use _ <- result.try(validate_options(options))
  use normalized <- result.try(normalize_source_subpath(subpath, options))
  use build <- result.try(build_synchronized_untrimmed(
    normalized,
    inner_offset:,
    outer_offset:,
    options:,
  ))
  let SynchronizedUntrimmedBuild(join_correspondences:, ..) = build
  Ok(
    list.map(join_correspondences, fn(correspondence) {
      let OffsetJoinCorrespondence(
        after_portion_index:,
        inner: inner_segments,
        outer: outer_segments,
        inner_reversed:,
        outer_reversed:,
        ..,
      ) = correspondence
      SynchronizedOffsetTraceJoin(
        after_portion_index:,
        inner_segments:,
        outer_segments:,
        inner_reversed:,
        outer_reversed:,
      )
    }),
  )
}

/// Return the final healed offset geometry paired by source correspondence.
@internal
pub fn internal_synchronized_offset_area_trace(
  subpath subpath: svg_path.Subpath,
  inner_offset inner_offset: Float,
  outer_offset outer_offset: Float,
  options options: Options,
) -> Result(List(SynchronizedOffsetTraceArea), Error) {
  use _ <- result.try(validate_options(options))
  use normalized <- result.try(normalize_source_subpath(subpath, options))
  use build <- result.try(build_synchronized_offset_segments(
    normalized,
    OffsetDistances(inner: inner_offset, outer: outer_offset),
    options,
  ))
  let SynchronizedOffsetSegmentsBuild(
    inner_offsets:,
    outer_offsets:,
    correspondences:,
    ..,
  ) = build
  Ok(
    synchronized_offset_trace_areas(
      correspondences,
      inner_offsets,
      outer_offsets,
      traced: [],
    ),
  )
}

fn synchronized_offset_trace_areas(
  correspondences: List(OffsetCorrespondence),
  inner_offsets: List(GHealedOffsetSegment),
  outer_offsets: List(GHealedOffsetSegment),
  traced traced: List(SynchronizedOffsetTraceArea),
) -> List(SynchronizedOffsetTraceArea) {
  case correspondences {
    [] -> list.reverse(traced)
    [first, ..rest] -> {
      let OffsetCorrespondence(
        portion_index:,
        correspondence_index:,
        inner: inner_source,
        outer: outer_source,
        inner_offset_count:,
        outer_offset_count:,
        ..,
      ) = first
      let inner = list.take(inner_offsets, inner_offset_count)
      let outer = list.take(outer_offsets, outer_offset_count)
      let areas =
        synchronized_max_granularity_trace_areas(
          portion_index,
          correspondence_index,
          inner_source,
          outer_source,
          list.map(inner, fn(offset) { offset.segment }),
          list.map(outer, fn(offset) { offset.segment }),
        )
      synchronized_offset_trace_areas(
        rest,
        list.drop(inner_offsets, inner_offset_count),
        list.drop(outer_offsets, outer_offset_count),
        traced: list.append(list.reverse(areas), traced),
      )
    }
  }
}

fn synchronized_max_granularity_trace_areas(
  portion_index: Int,
  correspondence_index: Int,
  inner_source: SynchronizedSideSource,
  outer_source: SynchronizedSideSource,
  inner_segments: List(svg_path.Segment),
  outer_segments: List(svg_path.Segment),
) -> List(SynchronizedOffsetTraceArea) {
  case inner_source, outer_source {
    SplitSideSource(left: inner_left, right: inner_right),
      SplitSideSource(left: outer_left, right: outer_right)
    -> {
      let inner_left_count = synchronized_side_source_offset_count(inner_left)
      let outer_left_count = synchronized_side_source_offset_count(outer_left)
      list.append(
        synchronized_max_granularity_trace_areas(
          portion_index,
          correspondence_index,
          inner_left,
          outer_left,
          list.take(inner_segments, inner_left_count),
          list.take(outer_segments, outer_left_count),
        ),
        synchronized_max_granularity_trace_areas(
          portion_index,
          correspondence_index,
          inner_right,
          outer_right,
          list.drop(inner_segments, inner_left_count),
          list.drop(outer_segments, outer_left_count),
        ),
      )
    }
    _, _ -> [
      SynchronizedOffsetTraceArea(
        portion_index:,
        correspondence_index:,
        inner_segments:,
        outer_segments:,
      ),
    ]
  }
}

fn synchronized_side_source_offset_count(
  source: SynchronizedSideSource,
) -> Int {
  case source {
    RefinableSideSource(_) | StalledSideSource(_) -> 1
    SplitSideSource(left:, right:) ->
      synchronized_side_source_offset_count(left)
      + synchronized_side_source_offset_count(right)
  }
}

fn synchronized_offset_trace_correspondence(
  correspondence: OffsetCorrespondence,
) -> SynchronizedOffsetTraceCorrespondence {
  let OffsetCorrespondence(
    portion_index:,
    correspondence_index:,
    inner:,
    outer:,
    ..,
  ) = correspondence
  SynchronizedOffsetTraceCorrespondence(
    portion_index:,
    correspondence_index:,
    inner_stalled: synchronized_side_source_is_stalled(inner),
    outer_stalled: synchronized_side_source_is_stalled(outer),
    inner_leaves: synchronized_side_source_trace_leaves(inner, leaves: []),
    outer_leaves: synchronized_side_source_trace_leaves(outer, leaves: []),
  )
}

fn synchronized_side_source_is_stalled(source: SynchronizedSideSource) -> Bool {
  case source {
    StalledSideSource(_) -> True
    RefinableSideSource(_) | SplitSideSource(..) -> False
  }
}

fn synchronized_side_source_trace_leaves(
  source: SynchronizedSideSource,
  leaves leaves: List(SynchronizedOffsetTraceLeaf),
) -> List(SynchronizedOffsetTraceLeaf) {
  case source {
    RefinableSideSource(EJoinFreeSegment(
      refined: DRefinedSegment(
        prepared: APreparedSegment(source_segment_index:, ..),
        prepared_from:,
        prepared_to:,
        ..,
      ),
      refined_from:,
      refined_to:,
      generation:,
      ..,
    )) ->
      list.reverse([
        SynchronizedOffsetTraceLeaf(
          source_segment_index:,
          prepared_from: prepared_from
            +. { prepared_to -. prepared_from }
            *. refined_from,
          prepared_to: prepared_from
            +. { prepared_to -. prepared_from }
            *. refined_to,
          generation:,
        ),
        ..leaves
      ])
    StalledSideSource(run) ->
      run
      |> list.fold(leaves, fn(leaves, stalled) {
        let CStalledSegment(
          prepared: APreparedSegment(source_segment_index:, ..),
          prepared_from:,
          prepared_to:,
          ..,
        ) = stalled
        [
          SynchronizedOffsetTraceLeaf(
            source_segment_index:,
            prepared_from:,
            prepared_to:,
            generation: 0,
          ),
          ..leaves
        ]
      })
      |> list.reverse
    SplitSideSource(left:, right:) -> {
      let left = synchronized_side_source_trace_leaves(left, leaves: [])
      let right = synchronized_side_source_trace_leaves(right, leaves: [])
      list.append(list.reverse(leaves), list.append(left, right))
    }
  }
}

fn synchronized_offset_source_trace_portions(
  portions: List(JoinFreePortion),
  offset: Float,
  options: Options,
  traced traced: List(OffsetSourceTracePortion),
) -> Result(List(OffsetSourceTracePortion), Error) {
  case portions {
    [] -> Ok(list.reverse(traced))
    [first, ..rest] -> {
      let JoinFreePortion(index:, subpath:, ..) = first
      let distances = OffsetDistances(inner: 0.0, outer: offset)
      let classified =
        subpath
        |> prepared_segments(source_subpath_index: 0)
        |> classify_prepared_segments_for_both_offsets(
          distances,
          options.stalled_offset_diameter,
        )
      use sources <- result.try(
        refine_synchronized_classified_segments(
          classified,
          distances,
          options.stalled_offset_diameter,
          refined: [],
        ),
      )
      use sources <- result.try(
        split_synchronized_double_reversal_segments(
          sources,
          distances,
          split: [],
        ),
      )
      synchronized_offset_source_trace_portions(rest, offset, options, traced: [
        OffsetSourceTracePortion(
          index:,
          subpath:,
          pieces: synchronized_offset_source_trace_pieces(
            sources,
            refined_piece_index: 0,
            traced: [],
          ),
        ),
        ..traced
      ])
    }
  }
}

fn synchronized_offset_source_trace_pieces(
  pieces: List(SynchronizedSourceSegment),
  refined_piece_index refined_piece_index: Int,
  traced traced: List(OffsetSourceTracePiece),
) -> List(OffsetSourceTracePiece) {
  case pieces {
    [] -> list.reverse(traced)
    [first, ..rest] -> {
      let SynchronizedSourceSegment(
        prepared: prepared,
        prepared_from:,
        prepared_to:,
        segment:,
        outer_status:,
        start_boundary: BoundaryPair(outer: start_boundary, ..),
        end_boundary: BoundaryPair(outer: end_boundary, ..),
        ..,
      ) = first
      let APreparedSegment(source_segment_index:, ..) = prepared
      case outer_status {
        SideStalled -> {
          let #(stalled_to, remaining) =
            collect_outer_stalled_trace_run(rest, prepared, prepared_to)
          let assert Ok(stalled_segment) =
            prepared_segment_between(prepared, prepared_from, stalled_to)
          synchronized_offset_source_trace_pieces(
            remaining,
            refined_piece_index: refined_piece_index + 1,
            traced: [
              OffsetSourceTraceStalled(
                source_segment_index:,
                segment: stalled_segment,
              ),
              ..traced
            ],
          )
        }
        SideNotStalled -> {
          let trace =
            OffsetSourceTraceDRefined(
              source_segment_index:,
              refined_piece_index:,
              source_from: prepared_from,
              source_to: prepared_to,
              segment:,
              start_boundary:,
              end_boundary:,
              start_is_reversal: boundary_is_reversal(start_boundary),
              end_is_reversal: boundary_is_reversal(end_boundary),
            )
          synchronized_offset_source_trace_pieces(
            rest,
            refined_piece_index: refined_piece_index + 1,
            traced: [trace, ..traced],
          )
        }
      }
    }
  }
}

fn collect_outer_stalled_trace_run(
  pieces: List(SynchronizedSourceSegment),
  prepared: APreparedSegment,
  stalled_to: Float,
) -> #(Float, List(SynchronizedSourceSegment)) {
  case pieces {
    [next, ..rest] -> {
      let SynchronizedSourceSegment(
        prepared: next_prepared,
        prepared_to: next_to,
        outer_status:,
        ..,
      ) = next
      case next_prepared == prepared && outer_status == SideStalled {
        True -> collect_outer_stalled_trace_run(rest, prepared, next_to)
        False -> #(stalled_to, pieces)
      }
    }
    [] -> #(stalled_to, [])
  }
}

fn classify_prepared_segments_for_both_offsets(
  segments: List(APreparedSegment),
  distances: OffsetDistances,
  threshold: Float,
) -> List(SynchronizedClassifiedSegment) {
  let OffsetDistances(inner:, outer:) = distances
  segments
  |> list.map(fn(prepared) {
    let APreparedSegment(segment:, ..) = prepared
    SynchronizedClassifiedSegment(
      prepared:,
      inner_status: stalled_status(segment, inner, threshold),
      outer_status: stalled_status(segment, outer, threshold),
      start_boundary: BoundaryPair(inner: Ordinary, outer: Ordinary),
      end_boundary: BoundaryPair(inner: Ordinary, outer: Ordinary),
    )
  })
  |> mark_synchronized_cross_segment_reversals(distances)
}

fn stalled_status(
  segment: svg_path.Segment,
  offset: Float,
  threshold: Float,
) -> SideStalledStatus {
  case source_segment_offset_is_stalled(segment, offset, threshold) {
    True -> SideStalled
    False -> SideNotStalled
  }
}

fn mark_synchronized_cross_segment_reversals(
  segments: List(SynchronizedClassifiedSegment),
  distances: OffsetDistances,
) -> List(SynchronizedClassifiedSegment) {
  case segments {
    [] | [_] -> segments
    [first, second, ..rest] ->
      mark_synchronized_cross_segment_reversals_loop(
        first,
        [second, ..rest],
        distances,
        marked: [],
      )
  }
}

fn mark_synchronized_cross_segment_reversals_loop(
  previous: SynchronizedClassifiedSegment,
  rest: List(SynchronizedClassifiedSegment),
  distances: OffsetDistances,
  marked marked: List(SynchronizedClassifiedSegment),
) -> List(SynchronizedClassifiedSegment) {
  case rest {
    [] -> list.reverse([previous, ..marked])
    [next, ..remaining] -> {
      let #(previous, next) =
        mark_synchronized_adjacent_reversal(previous, next, distances)
      mark_synchronized_cross_segment_reversals_loop(
        next,
        remaining,
        distances,
        marked: [previous, ..marked],
      )
    }
  }
}

fn mark_synchronized_adjacent_reversal(
  left: SynchronizedClassifiedSegment,
  right: SynchronizedClassifiedSegment,
  distances: OffsetDistances,
) -> #(SynchronizedClassifiedSegment, SynchronizedClassifiedSegment) {
  let SynchronizedClassifiedSegment(
    prepared: APreparedSegment(segment: left_segment, ..),
    start_boundary: left_start,
    end_boundary: BoundaryPair(inner: left_inner_end, outer: left_outer_end),
    ..,
  ) = left
  let SynchronizedClassifiedSegment(
    prepared: APreparedSegment(segment: right_segment, ..),
    start_boundary: BoundaryPair(
      inner: right_inner_start,
      outer: right_outer_start,
    ),
    end_boundary: right_end,
    ..,
  ) = right
  let OffsetDistances(inner:, outer:) = distances
  let inner_reversal =
    source_segments_have_boundary_reversal(left_segment, right_segment, inner)
  let outer_reversal =
    source_segments_have_boundary_reversal(left_segment, right_segment, outer)
  #(
    SynchronizedClassifiedSegment(
      ..left,
      start_boundary: left_start,
      end_boundary: BoundaryPair(
        inner: case inner_reversal {
          True -> reversal_boundary(left_segment, 1.0)
          False -> left_inner_end
        },
        outer: case outer_reversal {
          True -> reversal_boundary(left_segment, 1.0)
          False -> left_outer_end
        },
      ),
    ),
    SynchronizedClassifiedSegment(
      ..right,
      start_boundary: BoundaryPair(
        inner: case inner_reversal {
          True -> reversal_boundary(right_segment, 0.0)
          False -> right_inner_start
        },
        outer: case outer_reversal {
          True -> reversal_boundary(right_segment, 0.0)
          False -> right_outer_start
        },
      ),
      end_boundary: right_end,
    ),
  )
}

fn refine_synchronized_classified_segments(
  segments: List(SynchronizedClassifiedSegment),
  distances: OffsetDistances,
  stalled_threshold: Float,
  refined refined: List(SynchronizedSourceSegment),
) -> Result(List(SynchronizedSourceSegment), Error) {
  case segments {
    [] -> Ok(list.reverse(refined))
    [first, ..rest] -> {
      let SynchronizedClassifiedSegment(
        prepared:,
        inner_status:,
        outer_status:,
        start_boundary: BoundaryPair(inner: inner_start, outer: outer_start),
        end_boundary: BoundaryPair(inner: inner_end, outer: outer_end),
      ) = first
      use next <- result.try(refine_prepared_segment_for_both_offsets(
        prepared,
        distances,
        inner_status,
        outer_status,
        inner_start_boundary: inner_start,
        inner_end_boundary: inner_end,
        outer_start_boundary: outer_start,
        outer_end_boundary: outer_end,
        stalled_threshold:,
      ))
      refine_synchronized_classified_segments(
        rest,
        distances,
        stalled_threshold,
        refined: list.append(list.reverse(next), refined),
      )
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

fn source_segments_have_boundary_reversal(
  left: svg_path.Segment,
  right: svg_path.Segment,
  offset: Float,
) -> Bool {
  offset_curvature_zones_form_reversal_boundary(
    Some(offset_curvature_zone(left, offset, 1.0)),
    Some(offset_curvature_zone(right, offset, 0.0)),
  )
}

fn source_segment_offset_is_stalled(
  segment: svg_path.Segment,
  offset: Float,
  threshold: Float,
) -> Bool {
  case circular_arc_offset_radius(segment, offset) {
    Ok(radius) -> float.absolute_value(radius) <=. threshold
    Error(_) ->
      case
        offset_point(segment, t: 0.0, offset:),
        offset_point(segment, t: 0.5, offset:),
        offset_point(segment, t: 1.0, offset:)
      {
        Ok(start), Ok(mid), Ok(end) ->
          point_helpers.distance(start, mid) +. point_helpers.distance(mid, end)
          <=. threshold
        _, _, _ -> False
      }
  }
}

fn mark_cross_source_reversal_boundaries(
  offsets: List(FUnhealedOffsetSegment),
  offset: Float,
  closed closed: Bool,
) -> List(FUnhealedOffsetSegment) {
  let marked = mark_linear_cross_source_reversal_boundaries(offsets, offset)
  case closed, marked {
    True, [first, second, ..rest] -> {
      let assert Ok(last) = list.last([first, second, ..rest])
      let #(last, first) =
        mark_adjacent_cross_source_reversal_boundary(last, first, offset)
      [first, ..replace_last([second, ..rest], last, previous: [])]
    }
    _, _ -> marked
  }
}

fn mark_linear_cross_source_reversal_boundaries(
  offsets: List(FUnhealedOffsetSegment),
  offset: Float,
) -> List(FUnhealedOffsetSegment) {
  case offsets {
    [] | [_] -> offsets
    [first, second, ..rest] ->
      mark_linear_cross_source_reversal_boundaries_loop(
        first,
        [second, ..rest],
        offset,
        marked: [],
      )
  }
}

fn mark_linear_cross_source_reversal_boundaries_loop(
  previous: FUnhealedOffsetSegment,
  rest: List(FUnhealedOffsetSegment),
  offset: Float,
  marked marked: List(FUnhealedOffsetSegment),
) -> List(FUnhealedOffsetSegment) {
  case rest {
    [] -> list.reverse([previous, ..marked])
    [next, ..remaining] -> {
      let #(previous, next) =
        mark_adjacent_cross_source_reversal_boundary(previous, next, offset)
      mark_linear_cross_source_reversal_boundaries_loop(
        next,
        remaining,
        offset,
        marked: [previous, ..marked],
      )
    }
  }
}

fn mark_adjacent_cross_source_reversal_boundary(
  left: FUnhealedOffsetSegment,
  right: FUnhealedOffsetSegment,
  offset: Float,
) -> #(FUnhealedOffsetSegment, FUnhealedOffsetSegment) {
  case left.source, right.source {
    OffsetFromJoinFree(left_source), OffsetFromJoinFree(right_source) -> {
      case
        e_segments_have_cross_source_reversal_boundary(
          left_source,
          right_source,
          offset,
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
  offset: Float,
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
    Some(refined_source_interval_zone(left, offset)),
    Some(refined_source_interval_zone(right, offset)),
  )
}

fn refined_source_interval_zone(
  source: EJoinFreeSegment,
  offset: Float,
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
  offset_curvature_zone(prepared_segment, offset, { from +. to } /. 2.0)
}

fn set_offset_segment_source_start_reversal(
  offset: FUnhealedOffsetSegment,
) -> FUnhealedOffsetSegment {
  case offset.source {
    OffsetFromJoinFree(source) -> {
      let boundary =
        ReversalBoundary(e_join_free_source_endpoint_curvature(
          source,
          SegmentStart,
        ))
      FUnhealedOffsetSegment(
        ..offset,
        source: OffsetFromJoinFree(set_join_free_segment_start_boundary(
          source,
          boundary,
        )),
      )
    }
    OffsetFromStalledRun(..) -> offset
  }
}

fn set_offset_segment_source_end_reversal(
  offset: FUnhealedOffsetSegment,
) -> FUnhealedOffsetSegment {
  case offset.source {
    OffsetFromJoinFree(source) -> {
      let boundary =
        ReversalBoundary(e_join_free_source_endpoint_curvature(
          source,
          SegmentEnd,
        ))
      FUnhealedOffsetSegment(
        ..offset,
        source: OffsetFromJoinFree(set_join_free_segment_end_boundary(
          source,
          boundary,
        )),
      )
    }
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

fn refine_prepared_segment_for_both_offsets(
  prepared: APreparedSegment,
  distances: OffsetDistances,
  inner_status: SideStalledStatus,
  outer_status: SideStalledStatus,
  inner_start_boundary inner_start_boundary: BoundaryKind,
  inner_end_boundary inner_end_boundary: BoundaryKind,
  outer_start_boundary outer_start_boundary: BoundaryKind,
  outer_end_boundary outer_end_boundary: BoundaryKind,
  stalled_threshold stalled_threshold: Float,
) -> Result(List(SynchronizedSourceSegment), Error) {
  let APreparedSegment(segment:, ..) = prepared
  let OffsetDistances(inner:, outer:) = distances
  use parameters <- result.try(synchronized_curvature_split_parameters(
    segment,
    inner,
    outer,
    inner_status,
    outer_status,
  ))
  let inner_boundaries =
    parameters
    |> classify_curvature_boundaries(segment, inner)
    |> apply_endpoint_boundary_overrides(
      start_boundary: inner_start_boundary,
      end_boundary: inner_end_boundary,
    )
  let outer_boundaries =
    parameters
    |> classify_curvature_boundaries(segment, outer)
    |> apply_endpoint_boundary_overrides(
      start_boundary: outer_start_boundary,
      end_boundary: outer_end_boundary,
    )
  use sources <- result.try(
    split_prepared_segment_for_both_offsets(
      prepared,
      inner_boundaries,
      outer_boundaries,
      inner_status,
      outer_status,
      synchronized: [],
    ),
  )
  use sources <- result.try(synchronized_late_stalls(
    sources,
    Inner,
    inner,
    stalled_threshold,
  ))
  synchronized_late_stalls(sources, Outer, outer, stalled_threshold)
}

fn synchronized_curvature_split_parameters(
  segment: svg_path.Segment,
  inner: Float,
  outer: Float,
  inner_status: SideStalledStatus,
  outer_status: SideStalledStatus,
) -> Result(List(CurvatureSplitParameter), Error) {
  use inner_reversals <- result.try(case inner_status {
    SideStalled -> Ok([])
    SideNotStalled -> offset_reversal_parameters(segment, inner)
  })
  use outer_reversals <- result.try(case outer_status {
    SideStalled -> Ok([])
    SideNotStalled -> offset_reversal_parameters(segment, outer)
  })
  use inflections <- result.try(offset_inflection_parameters(segment))
  let reversals =
    list.append(inner_reversals, outer_reversals)
    |> list.filter(fn(t) {
      t >. point_parameter_tolerance && t <. 1.0 -. point_parameter_tolerance
    })
    |> list.map(fn(t) { CurvatureSplitParameter(t, CuspSplit) })
  let inflections =
    inflections
    |> list.filter(fn(t) {
      t >. point_parameter_tolerance && t <. 1.0 -. point_parameter_tolerance
    })
    |> list.map(fn(t) { CurvatureSplitParameter(t, InflectionSplit) })
  Ok(
    [
      CurvatureSplitParameter(0.0, OrdinarySplit),
      CurvatureSplitParameter(1.0, OrdinarySplit),
      ..list.append(reversals, inflections)
    ]
    |> list.sort(by: fn(a, b) {
      let CurvatureSplitParameter(t: left, ..) = a
      let CurvatureSplitParameter(t: right, ..) = b
      float.compare(left, right)
    })
    |> unique_curvature_split_parameters(curvature_parameter_tolerance, []),
  )
}

fn split_prepared_segment_for_both_offsets(
  prepared: APreparedSegment,
  inner_boundaries: List(CurvatureBoundary),
  outer_boundaries: List(CurvatureBoundary),
  inner_status: SideStalledStatus,
  outer_status: SideStalledStatus,
  synchronized synchronized: List(SynchronizedSourceSegment),
) -> Result(List(SynchronizedSourceSegment), Error) {
  case inner_boundaries, outer_boundaries {
    [inner_from, inner_to, ..inner_rest], [outer_from, outer_to, ..outer_rest]
    -> {
      let CurvatureBoundary(t: from_t, boundary: inner_start) = inner_from
      let CurvatureBoundary(t: to_t, boundary: inner_end) = inner_to
      let CurvatureBoundary(t: outer_from_t, boundary: outer_start) = outer_from
      let CurvatureBoundary(t: outer_to_t, boundary: outer_end) = outer_to
      case from_t == outer_from_t && to_t == outer_to_t {
        False -> Error(NonFinite)
        True -> {
          use rest <- result.try(split_prepared_segment_for_both_offsets(
            prepared,
            [inner_to, ..inner_rest],
            [outer_to, ..outer_rest],
            inner_status,
            outer_status,
            synchronized:,
          ))
          case to_t -. from_t <=. point_parameter_tolerance {
            True -> Ok(rest)
            False -> {
              use segment <- result.try(prepared_segment_between(
                prepared,
                from_t,
                to_t,
              ))
              Ok([
                SynchronizedSourceSegment(
                  prepared:,
                  prepared_from: from_t,
                  prepared_to: to_t,
                  segment:,
                  inner_status:,
                  outer_status:,
                  start_boundary: BoundaryPair(
                    inner: inner_start,
                    outer: outer_start,
                  ),
                  end_boundary: BoundaryPair(inner: inner_end, outer: outer_end),
                ),
                ..rest
              ])
            }
          }
        }
      }
    }
    [_], [_] | [], [] -> Ok(list.reverse(synchronized))
    _, _ -> Error(NonFinite)
  }
}

fn synchronized_late_stalls(
  sources: List(SynchronizedSourceSegment),
  side: BandSide,
  offset: Float,
  stalled_threshold: Float,
) -> Result(List(SynchronizedSourceSegment), Error) {
  use sources <- result.try(synchronized_late_stall_near_start(
    sources,
    side,
    offset,
    stalled_threshold,
  ))
  synchronized_late_stall_near_end(sources, side, offset, stalled_threshold)
}

fn synchronized_late_stall_near_start(
  sources: List(SynchronizedSourceSegment),
  side: BandSide,
  offset: Float,
  stalled_threshold: Float,
) -> Result(List(SynchronizedSourceSegment), Error) {
  case synchronized_first_reversal_parameter(sources, side) {
    None -> Ok(sources)
    Some(root_t) -> {
      let expanded_to = root_t *. 2.0
      case expanded_to >=. 1.0 -. point_parameter_tolerance {
        True -> Ok(sources)
        False -> {
          let assert [first, ..] = sources
          let SynchronizedSourceSegment(prepared:, ..) = first
          use stalled_segment <- result.try(prepared_segment_between(
            prepared,
            0.0,
            expanded_to,
          ))
          case
            source_segment_offset_is_stalled(
              stalled_segment,
              offset,
              stalled_threshold,
            )
          {
            False -> Ok(sources)
            True -> {
              use split <- result.try(split_synchronized_sources_at(
                sources,
                expanded_to,
              ))
              Ok(
                list.map(split, fn(source) {
                  let SynchronizedSourceSegment(prepared_to:, ..) = source
                  case
                    prepared_to <=. expanded_to +. point_parameter_tolerance
                  {
                    True -> set_synchronized_side_stalled(source, side)
                    False -> source
                  }
                }),
              )
            }
          }
        }
      }
    }
  }
}

fn synchronized_late_stall_near_end(
  sources: List(SynchronizedSourceSegment),
  side: BandSide,
  offset: Float,
  stalled_threshold: Float,
) -> Result(List(SynchronizedSourceSegment), Error) {
  case synchronized_last_reversal_parameter(sources, side) {
    None -> Ok(sources)
    Some(root_t) -> {
      let expanded_from = root_t *. 2.0 -. 1.0
      case expanded_from <=. point_parameter_tolerance {
        True -> Ok(sources)
        False -> {
          let assert [first, ..] = sources
          let SynchronizedSourceSegment(prepared:, ..) = first
          use stalled_segment <- result.try(prepared_segment_between(
            prepared,
            expanded_from,
            1.0,
          ))
          case
            source_segment_offset_is_stalled(
              stalled_segment,
              offset,
              stalled_threshold,
            )
          {
            False -> Ok(sources)
            True -> {
              use split <- result.try(split_synchronized_sources_at(
                sources,
                expanded_from,
              ))
              Ok(
                list.map(split, fn(source) {
                  let SynchronizedSourceSegment(prepared_from:, ..) = source
                  case
                    prepared_from >=. expanded_from -. point_parameter_tolerance
                  {
                    True -> set_synchronized_side_stalled(source, side)
                    False -> source
                  }
                }),
              )
            }
          }
        }
      }
    }
  }
}

fn synchronized_first_reversal_parameter(
  sources: List(SynchronizedSourceSegment),
  side: BandSide,
) -> Option(Float) {
  case sources {
    [] -> None
    [first, ..rest] -> {
      let SynchronizedSourceSegment(prepared_to:, end_boundary:, ..) = first
      case synchronized_side_boundary(end_boundary, side) {
        Ordinary -> synchronized_first_reversal_parameter(rest, side)
        ReversalBoundary(_) -> Some(prepared_to)
        Inflection | NonReversalBoundaryTouch -> None
      }
    }
  }
}

fn synchronized_last_reversal_parameter(
  sources: List(SynchronizedSourceSegment),
  side: BandSide,
) -> Option(Float) {
  synchronized_first_reversal_parameter(
    list.map(list.reverse(sources), fn(source) {
      let SynchronizedSourceSegment(
        prepared_from:,
        prepared_to:,
        start_boundary:,
        end_boundary:,
        ..,
      ) = source
      SynchronizedSourceSegment(
        ..source,
        prepared_from: 1.0 -. prepared_to,
        prepared_to: 1.0 -. prepared_from,
        start_boundary: end_boundary,
        end_boundary: start_boundary,
      )
    }),
    side,
  )
  |> option.map(fn(t) { 1.0 -. t })
}

fn synchronized_side_boundary(
  boundary: BoundaryPair,
  side: BandSide,
) -> BoundaryKind {
  let BoundaryPair(inner:, outer:) = boundary
  case side {
    Inner -> inner
    Outer -> outer
  }
}

fn set_synchronized_side_stalled(
  source: SynchronizedSourceSegment,
  side: BandSide,
) -> SynchronizedSourceSegment {
  case side {
    Inner -> SynchronizedSourceSegment(..source, inner_status: SideStalled)
    Outer -> SynchronizedSourceSegment(..source, outer_status: SideStalled)
  }
}

fn split_synchronized_sources_at(
  sources: List(SynchronizedSourceSegment),
  parameter: Float,
) -> Result(List(SynchronizedSourceSegment), Error) {
  case sources {
    [] -> Ok([])
    [first, ..rest] -> {
      let SynchronizedSourceSegment(prepared_from:, prepared_to:, ..) = first
      case
        parameter >. prepared_from +. point_parameter_tolerance
        && parameter <. prepared_to -. point_parameter_tolerance
      {
        False -> {
          use rest <- result.try(split_synchronized_sources_at(rest, parameter))
          Ok([first, ..rest])
        }
        True -> {
          use split <- result.try(split_synchronized_source_at_parameter(
            first,
            parameter,
          ))
          let #(left, right) = split
          Ok([left, right, ..rest])
        }
      }
    }
  }
}

fn split_synchronized_source_at_parameter(
  source: SynchronizedSourceSegment,
  parameter: Float,
) -> Result(#(SynchronizedSourceSegment, SynchronizedSourceSegment), Error) {
  let SynchronizedSourceSegment(
    prepared_from:,
    prepared_to:,
    segment:,
    start_boundary:,
    end_boundary:,
    ..,
  ) = source
  let local = { parameter -. prepared_from } /. { prepared_to -. prepared_from }
  use split <- result.try(
    svg_path.segment_split(segment, at: local) |> result.map_error(PathError),
  )
  let #(left, right) = split
  let ordinary = BoundaryPair(inner: Ordinary, outer: Ordinary)
  Ok(#(
    SynchronizedSourceSegment(
      ..source,
      prepared_to: parameter,
      segment: left,
      start_boundary:,
      end_boundary: ordinary,
    ),
    SynchronizedSourceSegment(
      ..source,
      prepared_from: parameter,
      segment: right,
      start_boundary: ordinary,
      end_boundary:,
    ),
  ))
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

fn segment_is_bezier(segment: svg_path.Segment) -> Bool {
  case segment {
    svg_path.QuadraticBezier(..) | svg_path.CubicBezier(..) -> True
    svg_path.Line(..) | svg_path.Arc(..) -> False
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
  offset: Float,
) -> List(CurvatureBoundary) {
  let zones = curvature_interval_zones(parameters, segment, offset, zones: [])
  classify_curvature_boundaries_loop(
    parameters,
    zones,
    segment,
    previous_zone: None,
    boundaries: [],
  )
}

fn curvature_interval_zones(
  parameters: List(CurvatureSplitParameter),
  segment: svg_path.Segment,
  offset: Float,
  zones zones: List(OffsetCurvatureZone),
) -> List(OffsetCurvatureZone) {
  case parameters {
    [] | [_] -> list.reverse(zones)
    [from, to, ..rest] -> {
      let CurvatureSplitParameter(t: from_t, ..) = from
      let CurvatureSplitParameter(t: to_t, ..) = to
      let midpoint = { from_t +. to_t } /. 2.0
      curvature_interval_zones([to, ..rest], segment, offset, zones: [
        offset_curvature_zone(segment, offset, midpoint),
        ..zones
      ])
    }
  }
}

fn classify_curvature_boundaries_loop(
  parameters: List(CurvatureSplitParameter),
  zones: List(OffsetCurvatureZone),
  segment: svg_path.Segment,
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
      let behavior =
        curvature_boundary_behavior(
          kind,
          previous_zone,
          next_zone,
          reversal_curvature: source_endpoint_curvature(segment, t),
        )
      classify_curvature_boundaries_loop(
        rest,
        case zones {
          [_, ..remaining] -> remaining
          [] -> []
        },
        segment,
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
  reversal_curvature reversal_curvature: Option(Float),
) -> BoundaryKind {
  case kind {
    InflectionSplit -> Inflection
    CuspSplit ->
      case
        offset_curvature_zones_form_reversal_boundary(previous_zone, next_zone)
      {
        True -> ReversalBoundary(reversal_curvature)
        False -> NonReversalBoundaryTouch
      }
    OrdinarySplit ->
      case
        offset_curvature_zones_form_reversal_boundary(previous_zone, next_zone)
      {
        True -> ReversalBoundary(reversal_curvature)
        False -> Ordinary
      }
  }
}

fn offset_curvature_zone(
  segment: svg_path.Segment,
  offset: Float,
  t: Float,
) -> OffsetCurvatureZone {
  case curvature.segment_left_normal_radius(segment, at: t) {
    Ok(radius) -> offset_curvature_radius_zone(radius, offset)
    Error(_) ->
      case curvature.segment_left_normal_curvature(segment, at: t) {
        Ok(value) if value >. curvature_value_tolerance -> Opposite
        Ok(value) if value <. 0.0 -. curvature_value_tolerance -> Opposite
        Ok(_) -> OutsideOffsetRadius
        Error(_) -> UnknownCurvatureZone
      }
  }
}

fn offset_curvature_radius_zone(radius: Float, offset: Float) {
  let tolerance = curvature_radius_tolerance
  case offset >=. 0.0 {
    True ->
      case radius <. 0.0 -. tolerance {
        True -> Opposite
        False ->
          case radius <. offset -. tolerance {
            True -> InsideOffsetRadius
            False -> OutsideOffsetRadius
          }
      }
    False ->
      case radius >. tolerance {
        True -> Opposite
        False ->
          case radius >. offset +. tolerance {
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
    ReversalBoundary(_) -> True
    _ -> False
  }
}

fn reversal_boundary(segment: svg_path.Segment, t: Float) -> BoundaryKind {
  ReversalBoundary(source_endpoint_curvature(segment, t))
}

fn source_endpoint_curvature(
  segment: svg_path.Segment,
  t: Float,
) -> Option(Float) {
  case curvature.segment_left_normal_curvature(segment, at: t) {
    Ok(value) -> Some(value)
    Error(_) -> None
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

fn offset_e_join_free_segment_attempt(
  source: EJoinFreeSegment,
  offset: Float,
  options: Options,
) -> Result(OffsetAttempt, Error) {
  let EJoinFreeSegment(segment:, ..) = source
  case segment {
    svg_path.Line(..) -> {
      use offset_start <- result.try(offset_point(segment, t: 0.0, offset:))
      use offset_end <- result.try(offset_point(segment, t: 1.0, offset:))
      use offset <- result.try(build_offset_segment(
        offset: offset,
        source: OffsetFromJoinFree(source),
        segment: svg_path.Line(start: offset_start, end: offset_end),
      ))
      Ok(OffsetAccepted(offset))
    }
    svg_path.Arc(..) ->
      case circular_arc_offset_radius(segment, offset) {
        Ok(radius) ->
          case float.absolute_value(radius) <=. point_tolerance {
            True -> Error(DegenerateTangent(0.0))
            False -> {
              use arc <- result.try(offset_circular_arc_segment_raw(
                segment,
                offset,
                radius,
              ))
              use offset <- result.try(build_exact_arc_offset_segment(
                arc,
                source: OffsetFromJoinFree(source),
              ))
              Ok(OffsetAccepted(offset))
            }
          }
        Error(_) -> fitted_offset_attempt(source, offset, options)
      }
    _ -> fitted_offset_attempt(source, offset, options)
  }
}

fn fitted_offset_attempt(
  source: EJoinFreeSegment,
  offset: Float,
  options: Options,
) -> Result(OffsetAttempt, Error) {
  let EJoinFreeSegment(segment:, ..) = source
  use candidate <- result.try(fit_e_join_free_offset_segment(source, offset))
  use divergence <- result.try(smart_offset_divergence(
    segment,
    candidate,
    offset,
    options,
  ))
  case divergence <=. raw_fitting_tolerance(options) {
    False -> Ok(OffsetNeedsRefinement(divergence))
    True -> {
      use offset <- result.try(build_offset_segment(
        offset: offset,
        source: OffsetFromJoinFree(source),
        segment: candidate,
      ))
      Ok(OffsetAccepted(offset))
    }
  }
}

fn offset_synchronized_e_pair(
  inner_source: EJoinFreeSegment,
  outer_source: EJoinFreeSegment,
  distances: OffsetDistances,
  options: Options,
  depth depth: Int,
) -> Result(SynchronizedUnhealedResult, Error) {
  let OffsetDistances(inner:, outer:) = distances
  use inner_attempt <- result.try(offset_e_join_free_segment_attempt(
    inner_source,
    inner,
    options,
  ))
  use outer_attempt <- result.try(offset_e_join_free_segment_attempt(
    outer_source,
    outer,
    options,
  ))
  case inner_attempt, outer_attempt {
    OffsetAccepted(inner_offset), OffsetAccepted(outer_offset) ->
      Ok(SynchronizedUnhealedResult(
        inner_offsets: [inner_offset],
        outer_offsets: [outer_offset],
        inner_source: RefinableSideSource(inner_source),
        outer_source: RefinableSideSource(outer_source),
      ))
    _, _ -> {
      let divergence = largest_attempt_divergence(inner_attempt, outer_attempt)
      case depth <= 0 {
        True -> Error(MaxDepthReached(divergence))
        False -> {
          use inner_split <- result.try(split_e_join_free_segment_at_midpoint(
            inner_source,
          ))
          use outer_split <- result.try(split_e_join_free_segment_at_midpoint(
            outer_source,
          ))
          let #(inner_left, inner_right) = inner_split
          let #(outer_left, outer_right) = outer_split
          use left <- result.try(offset_synchronized_e_pair(
            inner_left,
            outer_left,
            distances,
            options,
            depth: depth - 1,
          ))
          use right <- result.try(offset_synchronized_e_pair(
            inner_right,
            outer_right,
            distances,
            options,
            depth: depth - 1,
          ))
          Ok(join_synchronized_unhealed_results(left, right))
        }
      }
    }
  }
}

fn offset_e_with_source_tree(
  source: EJoinFreeSegment,
  offset: Float,
  options: Options,
  depth depth: Int,
) -> Result(#(List(FUnhealedOffsetSegment), SynchronizedSideSource), Error) {
  use attempt <- result.try(offset_e_join_free_segment_attempt(
    source,
    offset,
    options,
  ))
  case attempt {
    OffsetAccepted(offset) -> Ok(#([offset], RefinableSideSource(source)))
    OffsetNeedsRefinement(divergence) ->
      case depth <= 0 {
        True -> Error(MaxDepthReached(divergence))
        False -> {
          use split <- result.try(split_e_join_free_segment_at_midpoint(source))
          let #(left, right) = split
          use left_result <- result.try(offset_e_with_source_tree(
            left,
            offset,
            options,
            depth: depth - 1,
          ))
          use right_result <- result.try(offset_e_with_source_tree(
            right,
            offset,
            options,
            depth: depth - 1,
          ))
          let #(left_offsets, left_source) = left_result
          let #(right_offsets, right_source) = right_result
          Ok(#(
            list.append(left_offsets, right_offsets),
            SplitSideSource(left: left_source, right: right_source),
          ))
        }
      }
  }
}

fn offset_synchronized_source_segments(
  sources: List(SynchronizedSourceSegment),
  distances: OffsetDistances,
  options: Options,
  portion_index: Int,
  correspondence_index correspondence_index: Int,
  inner_offsets inner_offsets: List(FUnhealedOffsetSegment),
  outer_offsets outer_offsets: List(FUnhealedOffsetSegment),
  correspondences correspondences: List(OffsetCorrespondence),
) -> Result(SynchronizedPortionUnhealedBuild, Error) {
  case sources {
    [] ->
      Ok(SynchronizedPortionUnhealedBuild(
        inner_offsets: list.reverse(inner_offsets),
        outer_offsets: list.reverse(outer_offsets),
        correspondences: list.reverse(correspondences),
      ))
    [first, ..rest] -> {
      let #(group, rest) = collect_synchronized_status_run(first, rest, [])
      use built <- result.try(offset_synchronized_source_group(
        group,
        distances,
        options,
        portion_index,
        correspondence_index,
      ))
      let SynchronizedUnhealedResult(
        inner_offsets: next_inner,
        outer_offsets: next_outer,
        inner_source:,
        outer_source:,
      ) = built
      offset_synchronized_source_segments(
        rest,
        distances,
        options,
        portion_index,
        correspondence_index: correspondence_index + 1,
        inner_offsets: list.append(list.reverse(next_inner), inner_offsets),
        outer_offsets: list.append(list.reverse(next_outer), outer_offsets),
        correspondences: [
          OffsetCorrespondence(
            portion_index:,
            correspondence_index:,
            sources: group,
            inner: inner_source,
            outer: outer_source,
            inner_offset_count: list.length(next_inner),
            outer_offset_count: list.length(next_outer),
          ),
          ..correspondences
        ],
      )
    }
  }
}

fn collect_synchronized_status_run(
  first: SynchronizedSourceSegment,
  rest: List(SynchronizedSourceSegment),
  collected: List(SynchronizedSourceSegment),
) -> #(List(SynchronizedSourceSegment), List(SynchronizedSourceSegment)) {
  let SynchronizedSourceSegment(
    inner_status: first_inner,
    outer_status: first_outer,
    ..,
  ) = first
  case first_inner, first_outer {
    SideNotStalled, SideNotStalled -> #([first], rest)
    _, _ ->
      case rest {
        [next, ..remaining] -> {
          let SynchronizedSourceSegment(
            inner_status: next_inner,
            outer_status: next_outer,
            ..,
          ) = next
          case next_inner == first_inner && next_outer == first_outer {
            True ->
              collect_synchronized_status_run(first, remaining, [
                next,
                ..collected
              ])
            False -> #([first, ..list.reverse(collected)], rest)
          }
        }
        [] -> #([first, ..list.reverse(collected)], [])
      }
  }
}

fn offset_synchronized_source_group(
  sources: List(SynchronizedSourceSegment),
  distances: OffsetDistances,
  options: Options,
  portion_index: Int,
  correspondence_index: Int,
) -> Result(SynchronizedUnhealedResult, Error) {
  case sources {
    [] -> Error(NonFinite)
    [first] ->
      offset_synchronized_source_segment(
        first,
        distances,
        options,
        portion_index,
        correspondence_index,
      )
    [first, ..] -> {
      let SynchronizedSourceSegment(inner_status:, outer_status:, ..) = first
      offset_synchronized_stalled_group(
        sources,
        distances,
        options,
        portion_index,
        correspondence_index,
        inner_status,
        outer_status,
      )
    }
  }
}

fn offset_synchronized_stalled_group(
  sources: List(SynchronizedSourceSegment),
  distances: OffsetDistances,
  options: Options,
  portion_index: Int,
  correspondence_index: Int,
  inner_status: SideStalledStatus,
  outer_status: SideStalledStatus,
) -> Result(SynchronizedUnhealedResult, Error) {
  let OffsetDistances(inner:, outer:) = distances
  case inner_status, outer_status {
    SideStalled, SideNotStalled -> {
      let stalled = synchronized_stalled_group(sources, Inner)
      use inner_offsets <- result.try(offset_c_stalled_run(stalled, inner))
      use outer_result <- result.try(offset_refinable_synchronized_group(
        sources,
        Outer,
        outer,
        options,
        portion_index,
        correspondence_index,
      ))
      let #(outer_offsets, outer_source) = outer_result
      Ok(SynchronizedUnhealedResult(
        inner_offsets:,
        outer_offsets:,
        inner_source: StalledSideSource(stalled),
        outer_source:,
      ))
    }
    SideNotStalled, SideStalled -> {
      let stalled = synchronized_stalled_group(sources, Outer)
      use inner_result <- result.try(offset_refinable_synchronized_group(
        sources,
        Inner,
        inner,
        options,
        portion_index,
        correspondence_index,
      ))
      use outer_offsets <- result.try(offset_c_stalled_run(stalled, outer))
      let #(inner_offsets, inner_source) = inner_result
      Ok(SynchronizedUnhealedResult(
        inner_offsets:,
        outer_offsets:,
        inner_source:,
        outer_source: StalledSideSource(stalled),
      ))
    }
    SideStalled, SideStalled -> {
      let inner_stalled = synchronized_stalled_group(sources, Inner)
      let outer_stalled = synchronized_stalled_group(sources, Outer)
      use inner_offsets <- result.try(offset_c_stalled_run(inner_stalled, inner))
      use outer_offsets <- result.try(offset_c_stalled_run(outer_stalled, outer))
      Ok(SynchronizedUnhealedResult(
        inner_offsets:,
        outer_offsets:,
        inner_source: StalledSideSource(inner_stalled),
        outer_source: StalledSideSource(outer_stalled),
      ))
    }
    SideNotStalled, SideNotStalled -> Error(NonFinite)
  }
}

fn synchronized_stalled_group(
  sources: List(SynchronizedSourceSegment),
  side: BandSide,
) -> List(CStalledSegment) {
  list.map(sources, fn(source) {
    synchronized_stalled_segment(synchronized_refined_segment(source, side))
  })
}

fn offset_refinable_synchronized_group(
  sources: List(SynchronizedSourceSegment),
  side: BandSide,
  offset: Float,
  options: Options,
  portion_index: Int,
  segment_index segment_index: Int,
) -> Result(#(List(FUnhealedOffsetSegment), SynchronizedSideSource), Error) {
  case sources {
    [] -> Error(NonFinite)
    [first, ..rest] -> {
      let refined = synchronized_refined_segment(first, side)
      let source = synchronized_e_segment(refined, portion_index, segment_index)
      use first_result <- result.try(offset_e_with_source_tree(
        source,
        offset,
        options,
        depth: refinement_depth(options),
      ))
      case rest {
        [] -> Ok(first_result)
        [_, ..] -> {
          use rest_result <- result.try(offset_refinable_synchronized_group(
            rest,
            side,
            offset,
            options,
            portion_index,
            segment_index: segment_index + 1,
          ))
          let #(first_offsets, first_source) = first_result
          let #(rest_offsets, rest_source) = rest_result
          Ok(#(
            list.append(first_offsets, rest_offsets),
            SplitSideSource(left: first_source, right: rest_source),
          ))
        }
      }
    }
  }
}

fn synchronized_refined_segment(
  source: SynchronizedSourceSegment,
  side: BandSide,
) -> DRefinedSegment {
  let SynchronizedSourceSegment(
    prepared:,
    prepared_from:,
    prepared_to:,
    segment:,
    start_boundary: BoundaryPair(inner: inner_start, outer: outer_start),
    end_boundary: BoundaryPair(inner: inner_end, outer: outer_end),
    ..,
  ) = source
  let #(start_boundary, end_boundary) = case side {
    Inner -> #(inner_start, inner_end)
    Outer -> #(outer_start, outer_end)
  }
  DRefinedSegment(
    prepared:,
    prepared_from:,
    prepared_to:,
    segment:,
    start_boundary:,
    end_boundary:,
  )
}

fn offset_synchronized_source_segment(
  source: SynchronizedSourceSegment,
  distances: OffsetDistances,
  options: Options,
  portion_index: Int,
  correspondence_index: Int,
) -> Result(SynchronizedUnhealedResult, Error) {
  let SynchronizedSourceSegment(
    prepared:,
    prepared_from:,
    prepared_to:,
    segment:,
    inner_status:,
    outer_status:,
    start_boundary: BoundaryPair(inner: inner_start, outer: outer_start),
    end_boundary: BoundaryPair(inner: inner_end, outer: outer_end),
  ) = source
  let inner_refined =
    DRefinedSegment(
      prepared:,
      prepared_from:,
      prepared_to:,
      segment:,
      start_boundary: inner_start,
      end_boundary: inner_end,
    )
  let outer_refined =
    DRefinedSegment(
      prepared:,
      prepared_from:,
      prepared_to:,
      segment:,
      start_boundary: outer_start,
      end_boundary: outer_end,
    )
  let inner_e =
    synchronized_e_segment(inner_refined, portion_index, correspondence_index)
  let outer_e =
    synchronized_e_segment(outer_refined, portion_index, correspondence_index)
  let OffsetDistances(inner:, outer:) = distances
  case inner_status, outer_status {
    SideNotStalled, SideNotStalled ->
      offset_synchronized_e_pair(
        inner_e,
        outer_e,
        distances,
        options,
        depth: refinement_depth(options),
      )
    SideStalled, SideNotStalled -> {
      let stalled = synchronized_stalled_segment(inner_refined)
      use inner_offsets <- result.try(offset_c_stalled_run([stalled], inner))
      use outer_result <- result.try(offset_e_with_source_tree(
        outer_e,
        outer,
        options,
        depth: refinement_depth(options),
      ))
      let #(outer_offsets, outer_source) = outer_result
      Ok(SynchronizedUnhealedResult(
        inner_offsets:,
        outer_offsets:,
        inner_source: StalledSideSource([stalled]),
        outer_source:,
      ))
    }
    SideNotStalled, SideStalled -> {
      let stalled = synchronized_stalled_segment(outer_refined)
      use inner_result <- result.try(offset_e_with_source_tree(
        inner_e,
        inner,
        options,
        depth: refinement_depth(options),
      ))
      use outer_offsets <- result.try(offset_c_stalled_run([stalled], outer))
      let #(inner_offsets, inner_source) = inner_result
      Ok(SynchronizedUnhealedResult(
        inner_offsets:,
        outer_offsets:,
        inner_source:,
        outer_source: StalledSideSource([stalled]),
      ))
    }
    SideStalled, SideStalled -> {
      let inner_stalled = synchronized_stalled_segment(inner_refined)
      let outer_stalled = synchronized_stalled_segment(outer_refined)
      use inner_offsets <- result.try(offset_c_stalled_run(
        [inner_stalled],
        inner,
      ))
      use outer_offsets <- result.try(offset_c_stalled_run(
        [outer_stalled],
        outer,
      ))
      Ok(SynchronizedUnhealedResult(
        inner_offsets:,
        outer_offsets:,
        inner_source: StalledSideSource([inner_stalled]),
        outer_source: StalledSideSource([outer_stalled]),
      ))
    }
  }
}

fn synchronized_e_segment(
  refined: DRefinedSegment,
  portion_index: Int,
  segment_index: Int,
) -> EJoinFreeSegment {
  let DRefinedSegment(segment:, start_boundary:, end_boundary:, ..) = refined
  EJoinFreeSegment(
    portion_index:,
    segment_index:,
    generation: 0,
    refined:,
    refined_from: 0.0,
    refined_to: 1.0,
    segment:,
    start_boundary:,
    end_boundary:,
  )
}

fn synchronized_stalled_segment(refined: DRefinedSegment) -> CStalledSegment {
  let DRefinedSegment(prepared:, prepared_from:, prepared_to:, segment:, ..) =
    refined
  CStalledSegment(prepared:, prepared_from:, prepared_to:, segment:)
}

fn largest_attempt_divergence(
  inner: OffsetAttempt,
  outer: OffsetAttempt,
) -> Float {
  case inner, outer {
    OffsetNeedsRefinement(left), OffsetNeedsRefinement(right) ->
      float.max(left, right)
    OffsetNeedsRefinement(value), _ | _, OffsetNeedsRefinement(value) -> value
    _, _ -> 0.0
  }
}

fn join_synchronized_unhealed_results(
  left: SynchronizedUnhealedResult,
  right: SynchronizedUnhealedResult,
) -> SynchronizedUnhealedResult {
  let SynchronizedUnhealedResult(
    inner_offsets: left_inner_offsets,
    outer_offsets: left_outer_offsets,
    inner_source: left_inner_source,
    outer_source: left_outer_source,
  ) = left
  let SynchronizedUnhealedResult(
    inner_offsets: right_inner_offsets,
    outer_offsets: right_outer_offsets,
    inner_source: right_inner_source,
    outer_source: right_outer_source,
  ) = right
  SynchronizedUnhealedResult(
    inner_offsets: list.append(left_inner_offsets, right_inner_offsets),
    outer_offsets: list.append(left_outer_offsets, right_outer_offsets),
    inner_source: SplitSideSource(
      left: left_inner_source,
      right: right_inner_source,
    ),
    outer_source: SplitSideSource(
      left: left_outer_source,
      right: right_outer_source,
    ),
  )
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

fn offset_reversal_parameters(
  segment: svg_path.Segment,
  offset: Float,
) -> Result(List(Float), Error) {
  curvature.segment_left_normal_cusp_parameters(
    segment,
    distance: offset,
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
  offset offset: Float,
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
      use start <- result.try(offset_point(first, t: 0.0, offset:))
      use end <- result.try(offset_point(last, t: 1.0, offset:))
      use samples <- result.try(
        stalled_run_offset_samples(
          [first, ..rest],
          offset,
          index: 0,
          count: list.length([first, ..rest]),
          samples: [],
        ),
      )
      case stalled_run_collapsed(start, end, samples) {
        True -> Ok([])
        False -> {
          case rest, circular_arc_offset_radius(first, offset) {
            [], Ok(radius) -> {
              use arc <- result.try(offset_circular_arc_segment_raw(
                first,
                offset,
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
  offset: Float,
  index index: Int,
  count count: Int,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(List(#(Float, bezier.BezierPoint)), Error) {
  case segments {
    [] -> Ok(list.reverse(samples))
    [first, ..rest] -> {
      use samples <- result.try(stalled_segment_offset_samples(
        first,
        offset,
        index,
        count,
        [0.25, 0.5, 0.75],
        samples:,
      ))
      stalled_run_offset_samples(
        rest,
        offset,
        index: index + 1,
        count:,
        samples:,
      )
    }
  }
}

fn stalled_segment_offset_samples(
  segment: svg_path.Segment,
  offset: Float,
  index: Int,
  count: Int,
  t_values: List(Float),
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(List(#(Float, bezier.BezierPoint)), Error) {
  case t_values {
    [] -> Ok(samples)
    [local_t, ..rest] -> {
      use point <- result.try(offset_point(segment, t: local_t, offset:))
      let t = { int.to_float(index) +. local_t } /. int.to_float(count)
      stalled_segment_offset_samples(
        segment,
        offset,
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
  offset: Float,
  options: Options,
  closed closed: Bool,
) -> Result(List(GHealedOffsetSegment), Error) {
  use healed <- result.try(heal_adjacent_offset_boundaries(
    offsets,
    offset,
    options,
  ))
  use healed <- result.try(case closed {
    False -> Ok(healed)
    True -> heal_wrapping_offset_boundary(healed, offset, options)
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
  offset: Float,
  options: Options,
) -> Result(List(FUnhealedOffsetSegment), Error) {
  case offsets {
    [] | [_] -> Ok(offsets)
    [first, second, ..rest] -> {
      use #(first, second) <- result.try(heal_offset_boundary(
        first,
        second,
        offset,
        options,
      ))
      heal_adjacent_offset_boundaries_loop(
        second,
        rest,
        offset,
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
  offset: Float,
  options: Options,
  healed healed: List(FUnhealedOffsetSegment),
) -> Result(List(FUnhealedOffsetSegment), Error) {
  case rest {
    [] -> Ok(list.reverse([previous, ..healed]))
    [next, ..remaining] -> {
      use #(previous, next) <- result.try(heal_offset_boundary(
        previous,
        next,
        offset,
        options,
      ))
      heal_adjacent_offset_boundaries_loop(
        next,
        remaining,
        offset,
        options,
        healed: [previous, ..healed],
      )
    }
  }
}

fn heal_wrapping_offset_boundary(
  offsets: List(FUnhealedOffsetSegment),
  offset: Float,
  options: Options,
) -> Result(List(FUnhealedOffsetSegment), Error) {
  case offsets {
    [] | [_] -> Ok(offsets)
    [first, ..rest] -> {
      use last <- result.try(last_list_item(rest))
      use #(last, first) <- result.try(heal_offset_boundary(
        last,
        first,
        offset,
        options,
      ))
      Ok([first, ..replace_last_offset(rest, last)])
    }
  }
}

fn heal_offset_boundary(
  left: FUnhealedOffsetSegment,
  right: FUnhealedOffsetSegment,
  offset: Float,
  options: Options,
) -> Result(#(FUnhealedOffsetSegment, FUnhealedOffsetSegment), Error) {
  case heal_reversal_offset_boundary(left, right, offset, options) {
    Ok(healed) -> Ok(healed)
    Error(_) -> heal_smooth_offset_boundary(left, right, offset, options)
  }
}

/// Remove the loop enclosed around the shared endpoint of two consecutive
/// post-healing offset preimages. This is exposed internally for focused
/// instrumentation.
@internal
pub fn internal_short_circuit_adjacent_offset_segment_loop(
  left: svg_path.Segment,
  right: svg_path.Segment,
) -> Result(#(svg_path.Segment, svg_path.Segment), Error) {
  short_circuit_adjacent_offset_segment_loop(left, right)
}

fn short_circuit_adjacent_offset_segment_loop(
  left: svg_path.Segment,
  right: svg_path.Segment,
) -> Result(#(svg_path.Segment, svg_path.Segment), Error) {
  use #(left, _, right, _) <- result.try(
    short_circuit_adjacent_offset_segment_loop_with_parameters(left, right),
  )
  Ok(#(left, right))
}

fn short_circuit_adjacent_offset_segment_loop_with_parameters(
  left: svg_path.Segment,
  right: svg_path.Segment,
) -> Result(#(svg_path.Segment, Float, svg_path.Segment, Float), Error) {
  use intersections <- result.try(
    intersections.segment(left, right) |> result.map_error(PathError),
  )
  case earliest_interior_adjacent_intersection(intersections, best: None) {
    None -> Ok(#(left, 1.0, right, 0.0))
    Some(svg_path.SegmentIntersection(left_t:, right_t:, point:)) -> {
      use retained_left <- result.try(
        svg_path.segment_between_inside(left, from: 0.0, to: left_t)
        |> result.map_error(PathError),
      )
      use retained_right <- result.try(
        svg_path.segment_between_inside(right, from: right_t, to: 1.0)
        |> result.map_error(PathError),
      )
      Ok(#(
        segment_with_end(retained_left, point),
        left_t,
        segment_with_start(retained_right, point),
        right_t,
      ))
    }
  }
}

fn interval_parameter(from: Float, to: Float, local: Float) -> Float {
  from +. { to -. from } *. local
}

fn earliest_interior_adjacent_intersection(
  intersections: List(svg_path.SegmentIntersection),
  best best: Option(svg_path.SegmentIntersection),
) -> Option(svg_path.SegmentIntersection) {
  case intersections {
    [] -> best
    [intersection, ..rest] -> {
      let svg_path.SegmentIntersection(left_t:, right_t:, ..) = intersection
      // Contacts this close to the already-shared endpoint are not an
      // adjacent loop. Arc reconstruction can otherwise turn an exact
      // internal tangency into a second numerical root immediately beside
      // that endpoint.
      let interior =
        left_t >. 0.0
        && left_t <. 1.0 -. adjacent_loop_endpoint_parameter_tolerance
        && right_t >. adjacent_loop_endpoint_parameter_tolerance
        && right_t <. 1.0
      let best = case interior, best {
        False, _ -> best
        True, None -> Some(intersection)
        True, Some(current) -> {
          let svg_path.SegmentIntersection(
            left_t: current_left_t,
            right_t: current_right_t,
            ..,
          ) = current
          case
            left_t <. current_left_t
            || { left_t == current_left_t && right_t >. current_right_t }
          {
            True -> Some(intersection)
            False -> best
          }
        }
      }
      earliest_interior_adjacent_intersection(rest, best:)
    }
  }
}

fn segment_with_start(
  segment: svg_path.Segment,
  start: svg_path.Point,
) -> svg_path.Segment {
  case segment {
    svg_path.Line(_, end) -> svg_path.Line(start:, end:)
    svg_path.QuadraticBezier(_, control, end) ->
      svg_path.QuadraticBezier(start:, control:, end:)
    svg_path.CubicBezier(_, control1, control2, end) ->
      svg_path.CubicBezier(start:, control1:, control2:, end:)
    svg_path.Arc(_, radius, x_axis_rotation, large_arc, sweep, end) ->
      svg_path.Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:)
  }
}

fn segment_with_end(
  segment: svg_path.Segment,
  end: svg_path.Point,
) -> svg_path.Segment {
  case segment {
    svg_path.Line(start, _) -> svg_path.Line(start:, end:)
    svg_path.QuadraticBezier(start, control, _) ->
      svg_path.QuadraticBezier(start:, control:, end:)
    svg_path.CubicBezier(start, control1, control2, _) ->
      svg_path.CubicBezier(start:, control1:, control2:, end:)
    svg_path.Arc(start, radius, x_axis_rotation, large_arc, sweep, _) ->
      svg_path.Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:)
  }
}

fn heal_smooth_offset_boundary(
  left: FUnhealedOffsetSegment,
  right: FUnhealedOffsetSegment,
  offset: Float,
  options: Options,
) -> Result(#(FUnhealedOffsetSegment, FUnhealedOffsetSegment), Error) {
  let boundary =
    point_helpers.lerp(
      svg_path.segment_end(left.segment),
      svg_path.segment_start(right.segment),
      0.5,
    )
  let healed_left = snap_offset_end_position_only(left, boundary)
  let healed_right = snap_offset_start_position_only(right, boundary)
  case
    certified_healed_boundary(healed_left:, healed_right:, offset:, options:)
  {
    True -> Ok(#(healed_left, healed_right))
    False -> Ok(#(left, right))
  }
}

fn heal_reversal_offset_boundary(
  left: FUnhealedOffsetSegment,
  right: FUnhealedOffsetSegment,
  offset: Float,
  options: Options,
) -> Result(#(FUnhealedOffsetSegment, FUnhealedOffsetSegment), Error) {
  use _ <- result.try(
    bool_result(offset_boundary_is_known_reversal(left, right)),
  )
  let boundary =
    point_helpers.lerp(
      svg_path.segment_end(left.segment),
      svg_path.segment_start(right.segment),
      0.5,
    )
  let healed_left = snap_offset_end_position_only(left, boundary)
  let healed_right = snap_offset_start_position_only(right, boundary)
  case
    certified_healed_boundary(healed_left:, healed_right:, offset:, options:)
  {
    True -> Ok(#(healed_left, healed_right))
    False -> Error(NonFinite)
  }
}

fn snap_offset_end_position_only(
  offset: FUnhealedOffsetSegment,
  end: svg_path.Point,
) -> FUnhealedOffsetSegment {
  let delta = point_helpers.subtract(end, svg_path.segment_end(offset.segment))
  FUnhealedOffsetSegment(
    ..offset,
    segment: translate_segment_end_handle(offset.segment, end, delta),
  )
}

fn snap_offset_start_position_only(
  offset: FUnhealedOffsetSegment,
  start: svg_path.Point,
) -> FUnhealedOffsetSegment {
  let delta =
    point_helpers.subtract(start, svg_path.segment_start(offset.segment))
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
      svg_path.QuadraticBezier(
        start:,
        control: point_helpers.add(control, delta),
        end:,
      )
    svg_path.CubicBezier(control1:, control2:, end:, ..) ->
      svg_path.CubicBezier(
        start:,
        control1: point_helpers.add(control1, delta),
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
      svg_path.QuadraticBezier(
        start:,
        control: point_helpers.add(control, delta),
        end:,
      )
    svg_path.CubicBezier(start:, control1:, control2:, ..) ->
      svg_path.CubicBezier(
        start:,
        control1:,
        control2: point_helpers.add(control2, delta),
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
  offset offset: Float,
  options options: Options,
) -> Bool {
  healed_offset_certified(healed_left, offset, options)
  && healed_offset_certified(healed_right, offset, options)
}

fn healed_offset_certified(
  healed: FUnhealedOffsetSegment,
  offset: Float,
  options: Options,
) -> Bool {
  case offset_segment_certification_source(healed.source) {
    None -> True
    Some(source_segment) ->
      case offset_divergence(source_segment, healed.segment, offset, options) {
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
      case curvature.segment_left_normal_curvature(segment, at: t) {
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
    point_helpers.subtract(
      svg_path.segment_end(segment),
      svg_path.segment_start(segment),
    )
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
  let opposite_outgoing = point_helpers.scale(outgoing_direction, -1.0)
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
  offset: Float,
  miter_limit: Float,
) -> Result(List(svg_path.Segment), Error) {
  let left_tangent = left.nudged_end_tangent_direction
  let right_tangent = right.nudged_start_tangent_direction

  case directed_line_intersection(start, left_tangent, end, right_tangent) {
    Error(_) -> Ok(line_segments_between([start, end]))
    Ok(apex) -> {
      let corner = offset_segment_source_end(left.source)
      let miter_length = point_helpers.distance(corner, apex)
      let offset_distance = float.absolute_value(offset)
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
  _right: GHealedOffsetSegment,
  start: svg_path.Point,
  end: svg_path.Point,
  offset: Float,
) -> Result(List(svg_path.Segment), Error) {
  let radius = float.absolute_value(offset)
  case radius <=. point_tolerance {
    True -> Ok(line_segments_between([start, end]))
    False -> {
      // Use the actual join endpoints around their shared source corner. The
      // healed tangent directions can differ from the radial directions that
      // produced those endpoints, especially beside a stalled arc. Using the
      // tangents can therefore select the other SVG circle center and invert
      // the join.
      let corner = offset_segment_source_end(left.source)
      let start_radius = point_helpers.subtract(start, corner)
      let end_radius = point_helpers.subtract(end, corner)
      let angle = signed_angle(start_radius, end_radius)
      case float.absolute_value(angle) <=. angle_tolerance_degrees {
        True -> Ok(line_segments_between([start, end]))
        False ->
          Ok([
            svg_path.Arc(
              start:,
              radius: svg_path.Point(radius, radius),
              x_axis_rotation: 0.0,
              large_arc: False,
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
  let delta = point_helpers.subtract(right_start, left_start)
  let determinant = point_helpers.cross(left_direction, right_direction)
  case float.absolute_value(determinant) <=. direction_determinant_tolerance {
    True -> Error(Nil)
    False -> {
      let left_t = point_helpers.cross(delta, right_direction) /. determinant
      let right_t = point_helpers.cross(delta, left_direction) /. determinant
      let point =
        point_helpers.add(
          left_start,
          point_helpers.scale(left_direction, left_t),
        )
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
      case point_helpers.near(first, second, tolerance: point_tolerance) {
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
  offset: Float,
  radius: Float,
) -> Result(svg_path.Segment, Error) {
  use start <- result.try(offset_point(segment, t: 0.0, offset:))
  use end <- result.try(offset_point(segment, t: 1.0, offset:))
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
  offset: Float,
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
        True -> offset
        False -> 0.0 -. offset
      }
      Ok(center.radius.x +. signed_distance)
    }
  }
}

fn build_offset_segment(
  offset offset: Float,
  source source: OffsetSegmentSource,
  segment segment: svg_path.Segment,
) -> Result(FUnhealedOffsetSegment, Error) {
  use start_tangent <- result.try(offset_segment_nudged_tangent_direction(
    source,
    segment,
    offset,
    endpoint: SegmentStart,
  ))
  use end_tangent <- result.try(offset_segment_nudged_tangent_direction(
    source,
    segment,
    offset,
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
  offset: Float,
  endpoint endpoint: SegmentEndpoint,
) -> Result(svg_path.Point, Error) {
  case source {
    OffsetFromJoinFree(join_free) -> {
      use policy <- result.try(e_join_free_endpoint_policy(
        join_free,
        offset,
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

fn raw_fitting_tolerance(options: Options) -> Float {
  options.fitting.tolerance *. 0.5
}

fn fit_e_join_free_offset_segment(
  source: EJoinFreeSegment,
  offset: Float,
) -> Result(svg_path.Segment, Error) {
  let EJoinFreeSegment(segment:, ..) = source
  use start <- result.try(offset_point(segment, t: 0.0, offset:))
  use end <- result.try(offset_point(segment, t: 1.0, offset:))
  let samples =
    available_offset_fit_samples(
      segment,
      offset,
      [0.2, 0.35, 0.5, 0.65, 0.8],
      samples: [],
    )
  use start_policy <- result.try(e_join_free_endpoint_policy(
    source,
    offset,
    endpoint: SegmentStart,
  ))
  use end_policy <- result.try(e_join_free_endpoint_policy(
    source,
    offset,
    endpoint: SegmentEnd,
  ))
  use _ <- result.try(reject_bezier_double_radius_reversal_e_segment(
    source,
    offset,
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

fn e_join_free_endpoint_reaches_offset_radius(
  source: EJoinFreeSegment,
  offset: Float,
  endpoint: SegmentEndpoint,
) -> Bool {
  let EJoinFreeSegment(start_boundary:, end_boundary:, ..) = source
  let boundary = case endpoint {
    SegmentStart -> start_boundary
    SegmentEnd -> end_boundary
  }
  boundary_reaches_offset_radius(boundary, offset)
}

fn boundary_reaches_offset_radius(
  boundary: BoundaryKind,
  offset: Float,
) -> Bool {
  case boundary {
    ReversalBoundary(Some(value)) if value != 0.0 -> {
      let radius = 1.0 /. value
      number.is_finite(radius)
      && float.absolute_value(radius -. offset) <=. curvature_radius_tolerance
    }
    _ -> False
  }
}

fn e_join_free_source_endpoint_curvature(
  source: EJoinFreeSegment,
  endpoint: SegmentEndpoint,
) -> Option(Float) {
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
  source_endpoint_curvature(prepared_segment, prepared_t)
}

fn reject_bezier_double_radius_reversal_e_segment(
  source: EJoinFreeSegment,
  offset: Float,
) -> Result(Nil, Error) {
  let EJoinFreeSegment(segment:, start_boundary:, end_boundary:, ..) = source
  case
    boundary_is_reversal(start_boundary)
    && boundary_is_reversal(end_boundary)
    && e_join_free_endpoint_reaches_offset_radius(source, offset, SegmentStart)
    && e_join_free_endpoint_reaches_offset_radius(source, offset, SegmentEnd)
    && segment_is_bezier(segment)
  {
    True -> Error(NonFinite)
    False -> Ok(Nil)
  }
}

fn e_join_free_endpoint_policy(
  source: EJoinFreeSegment,
  offset: Float,
  endpoint endpoint: SegmentEndpoint,
) -> Result(CubicEndpointFitPolicy, Error) {
  let EJoinFreeSegment(segment:, start_boundary:, end_boundary:, ..) = source
  let is_reversal = case endpoint {
    SegmentStart -> boundary_is_reversal(start_boundary)
    SegmentEnd -> boundary_is_reversal(end_boundary)
  }
  let reaches_offset_radius =
    e_join_free_endpoint_reaches_offset_radius(source, offset, endpoint)
  let opposite_t = case endpoint {
    SegmentStart -> 1.0
    SegmentEnd -> 0.0
  }
  let opposite_direction = offset_derivative(segment, t: opposite_t, offset:)
  use direction <- result.try(e_join_free_endpoint_offset_direction(
    source,
    offset,
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
  offset: Float,
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
    False -> offset_derivative(segment, t: endpoint_t, offset:)
    True ->
      case offset_derivative(segment, t: interior_t, offset:) {
        Ok(direction) -> Ok(direction)
        Error(_) -> offset_derivative(segment, t: endpoint_t, offset:)
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
      let #(curve, report) = fit
      recover_collapsed_direction_fit(
        curve,
        report,
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
  report: bezier.CubicFitReport,
  start start: bezier.BezierPoint,
  end end: bezier.BezierPoint,
  start_direction start_direction: svg_path.Point,
  end_direction end_direction: svg_path.Point,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(bezier.BezierData, Error) {
  case report.start_handle, report.end_handle {
    bezier.CollapsedHandle, bezier.CollapsedHandle -> Error(NonFinite)
    bezier.CollapsedHandle, bezier.PositiveHandle ->
      fit_offset_cubic_data_with_endpoint_policies(
        start:,
        end:,
        start_policy: FitPositionAndDirectionWithCollapsedHandle(
          start_direction,
        ),
        end_policy: FitPositionAndDirection(end_direction),
        samples:,
      )
    bezier.PositiveHandle, bezier.CollapsedHandle ->
      fit_offset_cubic_data_with_endpoint_policies(
        start:,
        end:,
        start_policy: FitPositionAndDirection(start_direction),
        end_policy: FitPositionAndDirectionWithCollapsedHandle(end_direction),
        samples:,
      )
    bezier.PositiveHandle, bezier.PositiveHandle -> Ok(curve)
    bezier.UnconstrainedHandle, _ | _, bezier.UnconstrainedHandle ->
      Error(NonFinite)
  }
}

fn fit_offset_cubic_both_stalled(
  start start: svg_path.Point,
  end end: svg_path.Point,
  start_direction start_direction: svg_path.Point,
  end_direction end_direction: svg_path.Point,
) -> Result(svg_path.Segment, Error) {
  let chord = point_helpers.subtract(end, start)
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
    control2: to_bezier_point(point_helpers.add(
      start_point,
      point_helpers.scale(start_direction, b),
    )),
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
    control1: to_bezier_point(point_helpers.subtract(
      end_point,
      point_helpers.scale(end_direction, a),
    )),
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
    control1: to_bezier_point(point_helpers.add(
      start_point,
      point_helpers.scale(start_direction, a),
    )),
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
    control2: to_bezier_point(point_helpers.subtract(
      end_point,
      point_helpers.scale(end_direction, b),
    )),
    end:,
  ))
}

fn validate_reversal_handle_scalar(
  start: svg_path.Point,
  end: svg_path.Point,
  value: Float,
) -> Result(Nil, Error) {
  let chord = point_helpers.distance(start, end)
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
      point_helpers.scale(end_direction, -1.0),
    )
  {
    Ok(point) -> {
      let handle = point_helpers.distance(end, point)
      let chord = point_helpers.distance(start, end)
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
      let handle = point_helpers.distance(start, point)
      let chord = point_helpers.distance(start, end)
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
      Ok(point_helpers.subtract(end, point_helpers.scale(end_direction, handle)))
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
      Ok(point_helpers.add(start, point_helpers.scale(start_direction, handle)))
    }
  }
}

fn directions_follow_chord(
  start: svg_path.Point,
  end: svg_path.Point,
  start_direction: svg_path.Point,
  end_direction: svg_path.Point,
) -> Bool {
  case unit_vector(point_helpers.subtract(end, start), t: 0.5) {
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
  let determinant = point_helpers.cross(a_unit, b_unit)
  case
    float.absolute_value(determinant)
    <. trig.sin_degrees(reversal_fit_line_aperture_degrees)
  {
    True -> Error(NonFinite)
    False -> {
      let delta = point_helpers.subtract(b, a)
      let scale_a = point_helpers.cross(delta, b_unit) /. determinant
      Ok(point_helpers.add(a, point_helpers.scale(a_unit, scale_a)))
    }
  }
}

fn stalled_start_control2_by_bisection(
  start start: svg_path.Point,
  end end: svg_path.Point,
  start_direction start_direction: svg_path.Point,
  end_direction end_direction: svg_path.Point,
) -> Result(svg_path.Point, Error) {
  let chord = point_helpers.distance(start, end)
  let from = reversal_fit_min_handle_chord_ratio *. chord
  let to = reversal_fit_max_handle_chord_ratio *. chord
  let point_for = fn(handle) {
    point_helpers.subtract(end, point_helpers.scale(end_direction, handle))
  }
  let score = fn(handle) {
    case unit_vector(point_helpers.subtract(point_for(handle), start), t: 0.0) {
      Error(_) -> 0.0
      Ok(direction) -> point_helpers.cross(start_direction, direction)
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
  let chord = point_helpers.distance(start, end)
  let from = reversal_fit_min_handle_chord_ratio *. chord
  let to = reversal_fit_max_handle_chord_ratio *. chord
  let point_for = fn(handle) {
    point_helpers.add(start, point_helpers.scale(start_direction, handle))
  }
  let score = fn(handle) {
    case unit_vector(point_helpers.subtract(point_for(handle), end), t: 1.0) {
      Error(_) -> 0.0
      Ok(direction) -> point_helpers.cross(end_direction, direction)
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
      point_helpers.add(
        point_helpers.add(
          point_helpers.scale(start, u *. u *. u +. 3.0 *. u *. u *. t),
          point_helpers.scale(control2, 3.0 *. u *. t *. t),
        ),
        point_helpers.scale(end, t *. t *. t),
      )
    },
    column: fn(t) {
      let u = 1.0 -. t
      point_helpers.scale(direction, 3.0 *. u *. u *. t)
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
      point_helpers.add(
        point_helpers.add(
          point_helpers.scale(start, u *. u *. u),
          point_helpers.scale(control1, 3.0 *. u *. u *. t),
        ),
        point_helpers.scale(end, 3.0 *. u *. t *. t +. t *. t *. t),
      )
    },
    column: fn(t) {
      let u = 1.0 -. t
      point_helpers.scale(direction, -3.0 *. u *. t *. t)
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
      let target = point_helpers.subtract(from_bezier_point(point), fixed(t))
      let col = column(t)
      fit_one_handle_loop(
        rest,
        fixed,
        column,
        ata: ata +. point_helpers.dot(col, col),
        atb: atb +. point_helpers.dot(col, target),
        count: count + 1,
      )
    }
  }
}

fn available_offset_fit_samples(
  segment: svg_path.Segment,
  offset: Float,
  t_values: List(Float),
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> List(#(Float, bezier.BezierPoint)) {
  case t_values {
    [] -> list.reverse(samples)
    [t, ..rest] -> {
      let samples = case offset_point(segment, t:, offset:) {
        Ok(point) -> [#(t, to_bezier_point(point)), ..samples]
        Error(DegenerateTangent(_)) -> samples
        Error(_) -> samples
      }
      available_offset_fit_samples(segment, offset, rest, samples:)
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
      let mapped =
        point_helpers.add(point, point_helpers.scale(normal, local.y))

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
  offset offset: Float,
) -> Result(svg_path.Point, Error) {
  use point <- result.try(
    svg_path.segment_point(segment, at: t) |> result.map_error(PathError),
  )
  use normal <- result.try(unit_normal(segment, t:))
  let point = point_helpers.add(point, point_helpers.scale(normal, offset))

  case point_is_finite(point) {
    True -> Ok(point)
    False -> Error(NonFinite)
  }
}

fn offset_derivative(
  segment: svg_path.Segment,
  t t: Float,
  offset offset: Float,
) -> Result(svg_path.Point, Error) {
  use derivative <- result.try(
    svg_path.segment_derivative(segment, at: t) |> result.map_error(PathError),
  )
  use second <- result.try(
    svg_path.segment_second_derivative(segment, at: t)
    |> result.map_error(PathError),
  )
  use speed <- result.try(length(derivative, t:))

  let tangent_change =
    point_helpers.subtract(
      point_helpers.scale(second, 1.0 /. speed),
      point_helpers.scale(
        derivative,
        point_helpers.dot(derivative, second) /. { speed *. speed *. speed },
      ),
    )

  let candidate =
    point_helpers.add(
      derivative,
      point_helpers.scale(
        point_helpers.rotate_counterclockwise(tangent_change),
        offset,
      ),
    )

  case point_is_finite(candidate) {
    True -> Ok(candidate)
    False -> Error(NonFinite)
  }
}

fn offset_divergence(
  source: svg_path.Segment,
  candidate: svg_path.Segment,
  offset: Float,
  options: Options,
) -> Result(Float, Error) {
  offset_divergence_loop(
    source,
    candidate,
    offset,
    options,
    sample: 1,
    best: 0.0,
  )
}

fn offset_divergence_loop(
  source: svg_path.Segment,
  candidate: svg_path.Segment,
  offset: Float,
  options: Options,
  sample sample: Int,
  best best: Float,
) -> Result(Float, Error) {
  case sample > options.fitting.samples {
    True -> Ok(best)
    False -> {
      let t = int_to_float(sample) /. int_to_float(options.fitting.samples + 1)
      use point <- result.try(offset_point(source, t:, offset:))
      use candidate_point <- result.try(
        svg_path.segment_point(candidate, at: t) |> result.map_error(PathError),
      )
      let best = float.max(best, point_helpers.distance(point, candidate_point))
      case best >. options.fitting.tolerance {
        True -> Ok(best)
        False ->
          offset_divergence_loop(
            source,
            candidate,
            offset,
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
  offset: Float,
  options: Options,
) -> Result(Float, Error) {
  smart_offset_divergence_loop(
    source,
    candidate,
    offset,
    options,
    sample: 1,
    best: 0.0,
    valid_samples: 0,
  )
}

fn smart_offset_divergence_loop(
  source: svg_path.Segment,
  candidate: svg_path.Segment,
  offset: Float,
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
      case offset_point(source, t:, offset:) {
        Error(DegenerateTangent(_)) ->
          smart_offset_divergence_loop(
            source,
            candidate,
            offset,
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
          let best =
            float.max(best, point_helpers.distance(point, candidate_point))
          case best >. options.fitting.tolerance {
            True -> Ok(best)
            False ->
              smart_offset_divergence_loop(
                source,
                candidate,
                offset,
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
  Ok(point_helpers.rotate_counterclockwise(tangent))
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
          let sum = point_helpers.add(incoming, outgoing)
          case point_helpers.norm(sum) >. small_unit_division_tolerance {
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
  let length = point_helpers.norm(point)
  case length >. small_unit_division_tolerance {
    True -> Ok(length)
    False -> Error(DegenerateTangent(t))
  }
}

fn unit_vector(
  point: svg_path.Point,
  t t: Float,
) -> Result(svg_path.Point, Error) {
  use length <- result.try(length(point, t:))
  Ok(point_helpers.scale(point, 1.0 /. length))
}

fn signed_angle(a: svg_path.Point, b: svg_path.Point) -> Float {
  trig.atan2_degrees(point_helpers.cross(a, b), point_helpers.dot(a, b))
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
