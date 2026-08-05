//// Path offset construction.
////
//// This module follows the same basic model as `svgpathsio`: lines and
//// circular arcs are offset exactly, while other curves are offset by fitted
//// cubic Beziers. Cubic approximations are checked by sampling the true normal
//// extrusion of the source curve and measuring its distance to the proposed
//// offset. If the error is too large, the source curve is split and each half
//// is offset recursively.
////
//// Subpath and path offsets create a provisional one-sided offset walk by
//// connecting adjacent segment offsets with the requested join style. The
//// public trimmed offset builds an arrangement that nodes the provisional
//// walks at intersections and endpoint-bounded overlaps, removes
//// sections that lie inside the forbidden distance tube around the original
//// subpath, then keeps the remaining sections in provisional traversal order.
//// Because trimming can split an offset or remove it entirely, subpath and
//// path offsets return `Path`.
////
//// The `*_untrimmed` helpers expose the provisional offset walk directly. It
//// is useful for debugging, drawing raw construction geometry, or implementing
//// a different trimming policy.
////
//// `subpath_band` and `path_band` construct two signed offset walks and trim
//// them together. They do not add caps or bridges. `subpath_stroke` and
//// `path_stroke` add endpoint caps for open subpaths. Closed strokes use the
//// same capless per-subpath band construction.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import svg_path
import svg_path/area
import svg_path/arrangement_graph
import svg_path/bezier
import svg_path/intersections
import svg_path/point as point_helpers
import svg_path/root
import svg_path/trig

const default_tolerance = 0.01

const default_max_depth = 20

const default_samples = 10

const default_miter_limit = 4.0

const tangent_epsilon = 0.000001

const point_tolerance = 0.000000001

const default_tangent_heal_angle_degrees = 2.0

const stable_tangent_assertion_diameter = 0.01

const default_stalled_offset_diameter = 0.01

/// Errors returned by offset helpers.
pub type Error {
  /// An underlying path operation failed.
  PathError(svg_path.Error)

  /// Arrangement construction failed while noding provisional offset paths.
  ArrangementGraphError(arrangement_graph.Error)

  /// The offset tolerance must be greater than zero.
  InvalidTolerance(tolerance: Float)

  /// The number of divergence samples must be greater than zero.
  InvalidSamples(samples: Int)

  /// The recursive subdivision limit must be greater than zero.
  InvalidMaxDepth(max_depth: Int)

  /// The miter limit must be greater than zero.
  InvalidMiterLimit(miter_limit: Float)

  /// The stalled offset diameter must be non-negative.
  InvalidStalledOffsetDiameter(diameter: Float)

  /// Stroke width must be greater than zero.
  InvalidStrokeWidth(width: Float)

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
/// `fitting` controls offset approximation, `trimming` controls projection and
/// root-finding used while pruning, `stalled_offset_diameter` decides when
/// the stalled-run builder treats an offset piece as too small to keep as an
/// ordinary independently fitted segment, and `tangent_heal_angle_degrees` is
/// the maximum tangent change-of-direction, in degrees, between two adjacent
/// offset pieces that is still treated as a smooth boundary and welded to a
/// single vertex. Larger values weld more near-smooth joins, avoiding the tiny
/// degenerate connector segments that otherwise appear between offset pieces.
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

type OffsetSegment {
  OffsetSegment(
    segment: svg_path.Segment,
    source_start: svg_path.Point,
    source_end: svg_path.Point,
    source_start_tangent: svg_path.Point,
    source_end_tangent: svg_path.Point,
  )
}

type OffsetBuilder {
  OffsetBuilder(
    build: fn(svg_path.Subpath, Float, Options) ->
      Result(List(OffsetSegment), Error),
  )
}

type JoinFreePortion {
  JoinFreePortion(subpath: svg_path.Subpath, closed: Bool)
}

type SmoothOffsetBuilder {
  SmoothOffsetBuilder(
    build: fn(JoinFreePortion, Float, Options) ->
      Result(List(OffsetSegment), Error),
  )
}

type OriginalRecursiveOffsetBuilderFitPolicy {
  OriginalRecursiveFit
  SmartOriginalRecursiveFit
}

type SmoothSourcePiece {
  BigSourceSegment(svg_path.Segment)
  StalledSourceRun(List(svg_path.Segment))
}

type SplitParameter {
  SplitParameter(t: Float, cut: Bool)
}

type SplitPiece {
  SplitPiece(segment: svg_path.Segment, start_is_cut: Bool, end_is_cut: Bool)
}

/// Return default options for offset construction.
pub fn default_options() -> Options {
  Options(
    fitting: FittingOptions(
      tolerance: default_tolerance,
      samples: default_samples,
      max_depth: default_max_depth,
    ),
    trimming: svg_path.default_distance_options(),
    stalled_offset_diameter: default_stalled_offset_diameter,
    tangent_heal_angle_degrees: default_tangent_heal_angle_degrees,
    join: Miter(default_miter_limit),
  )
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
  use _ <- result.try(validate_options(options))
  use pieces <- result.try(offset_source_segment_with_builder(
    segment,
    distance,
    options,
    OriginalRecursiveFit,
  ))
  pieces
  |> list.map(fn(piece) { piece.segment })
  |> svg_path.subpath_with(policy: svg_path.Wiggle)
  |> result.map_error(PathError)
}

/// Offset a subpath by a signed distance.
///
/// Positive distances offset to the right of the subpath direction. Adjacent
/// offset segments are connected using `default_options().join`. The result is
/// a path because trimming self-intersections can split the offset into
/// multiple subpaths or remove it entirely.
///
/// The provisional offset is split at self-intersections. Each section is
/// sampled at global section-length parameters `0.1, 0.2, ..., 0.9`; sections
/// with fewer than five samples at least `abs(distance) - options.fitting.tolerance`
/// from the original subpath are removed.
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
  use provisional <- result.try(subpath_untrimmed_with(
    subpath,
    distance:,
    options:,
  ))
  parametric_pruned_subpath(subpath, provisional, distance, options)
}

/// Offset a subpath at two signed distances and trim the two sides together.
///
/// No caps, bridges, or fill-rule interpretation are added. The two provisional
/// offset walks are split at their own self-intersections and at intersections
/// with each other, then each section is tested against the original subpath's
/// distance tube. This supports ordinary capless stroke sides, one-sided bands,
/// and asymmetric bands such as two positive offsets.
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
  use provisional_a <- result.try(subpath_untrimmed_with(
    subpath,
    distance: distance_a,
    options:,
  ))
  use provisional_b <- result.try(subpath_untrimmed_with(
    subpath,
    distance: distance_b,
    options:,
  ))
  use subpaths <- result.try(parametric_pruned_pair(
    subpath,
    provisional_a:,
    distance_a:,
    provisional_b:,
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
/// This returns the provisional one-sided offset walk. Adjacent segment offsets
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
  parametric_provisional_subpath(subpath, distance, options)
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
  use provisional <- result.try(
    parametric_untrimmed_path_subpaths(
      svg_path.path_subpaths(path),
      distance,
      options,
      converted: [],
    ),
  )
  use sections <- result.try(arrangement_global_section_chunks(provisional))
  use retained <- result.try(
    retain_global_parametric_sections(
      sections,
      source: path,
      distance:,
      options:,
      retained: [],
    ),
  )
  let retained = merge_touching_chunks(retained, options.fitting.tolerance)
  use subpaths <- result.try(chunks_to_subpaths(
    retained,
    options.fitting.tolerance,
    closed: all_subpaths_closed(svg_path.path_subpaths(path)),
  ))
  Ok(svg_path.Path(subpaths:))
}

fn all_subpaths_closed(subpaths: List(svg_path.Subpath)) -> Bool {
  case subpaths {
    [] -> False
    [first, ..rest] ->
      svg_path.subpath_is_closed(first) && all_remaining_subpaths_closed(rest)
  }
}

fn all_remaining_subpaths_closed(subpaths: List(svg_path.Subpath)) -> Bool {
  case subpaths {
    [] -> True
    [first, ..rest] ->
      svg_path.subpath_is_closed(first) && all_remaining_subpaths_closed(rest)
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
    parametric_untrimmed_path_subpaths(
      svg_path.path_subpaths(path),
      distance,
      options,
      converted: [],
    ),
  )
  use sections <- result.try(arrangement_global_section_chunks(provisional))
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
  case options.fitting.tolerance <=. 0.0 {
    True -> Error(InvalidTolerance(options.fitting.tolerance))
    False ->
      case options.fitting.samples <= 0 {
        True -> Error(InvalidSamples(options.fitting.samples))
        False ->
          case options.fitting.max_depth <= 0 {
            True -> Error(InvalidMaxDepth(options.fitting.max_depth))
            False ->
              case options.stalled_offset_diameter <. 0.0 {
                True ->
                  Error(InvalidStalledOffsetDiameter(
                    options.stalled_offset_diameter,
                  ))
                False -> validate_join(options.join)
              }
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

fn validate_stroke_width(width: Float) -> Result(Nil, Error) {
  case width <=. 0.0 || !is_finite(width) {
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

/// Build the arrangement used to node provisional offset subpaths.
@internal
pub fn internal_provisional_arrangement(
  provisional: List(svg_path.Subpath),
) -> Result(arrangement_graph.ArrangementGraphBuild, Error) {
  arrangement_graph.build(
    [svg_path.Path(subpaths: provisional)],
    tolerance: point_tolerance,
    minimum_chord: point_tolerance,
  )
  |> result.map_error(ArrangementGraphError)
}

/// Return one atomic section for each directed provisional-edge occurrence.
/// Coincident graph edges are expanded according to directional multiplicity.
@internal
pub fn internal_arrangement_global_sections(
  provisional: List(svg_path.Subpath),
  options options: Options,
) -> Result(svg_path.Path, Error) {
  use sections <- result.try(arrangement_global_section_chunks(provisional))
  use subpaths <- result.try(chunks_to_subpaths(
    sections,
    options.fitting.tolerance,
    closed: False,
  ))
  Ok(svg_path.Path(subpaths:))
}

fn arrangement_global_section_chunks(
  provisional: List(svg_path.Subpath),
) -> Result(List(List(svg_path.Segment)), Error) {
  use build <- result.try(internal_provisional_arrangement(provisional))
  use image_sections <- result.try(
    build.segment_images
    |> list.map(fn(image) {
      arrangement_graph.segment_image_edges(build, image)
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
      |> result.map_error(ArrangementGraphError)
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
    svg_path.subpath_with(section, policy: svg_path.Wiggle)
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
    count: 0,
  )
}

fn global_parametric_section_samples(
  section: svg_path.Subpath,
  length: Float,
  samples: List(Float),
  source source: svg_path.Path,
  distance distance: Float,
  options options: Options,
  count count: Int,
) -> Result(Bool, Error) {
  case samples {
    [] -> Ok(count >= 5)
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
      let count = case
        projection.distance +. margin >=. float.absolute_value(distance)
      {
        True -> count + 1
        False -> count
      }
      global_parametric_section_samples(
        section,
        length,
        rest,
        source:,
        distance:,
        options:,
        count:,
      )
    }
  }
}

fn parametric_untrimmed_path_subpaths(
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
      parametric_untrimmed_path_subpaths(rest, distance, options, converted: [
        offset,
        ..converted
      ])
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

fn parametric_provisional_subpath(
  subpath: svg_path.Subpath,
  distance: Float,
  options: Options,
) -> Result(svg_path.Subpath, Error) {
  case svg_path.subpath_segments(subpath) {
    [] -> {
      use start <- result.try(
        svg_path.subpath_start(subpath) |> result.map_error(PathError),
      )
      Ok(svg_path.subpath_empty(at: start))
    }
    [_, ..] -> {
      use offset_segments <- result.try(build_offset_segments(
        stalled_run_offset_builder(),
        subpath,
        distance,
        options,
      ))
      use output_segments <- result.try(parametric_joined_offset_segments(
        offset_segments,
        distance,
        options.join,
        closed: svg_path.subpath_is_closed(subpath),
      ))
      use provisional <- result.try(
        svg_path.subpath_with(output_segments, policy: svg_path.Wiggle)
        |> result.map_error(PathError),
      )
      case svg_path.subpath_is_closed(subpath) {
        False -> Ok(provisional)
        True ->
          svg_path.subpath_set_closed_with(
            provisional,
            closed: True,
            policy: svg_path.Wiggle,
          )
          |> result.map_error(PathError)
      }
    }
  }
}

fn build_offset_segments(
  builder: OffsetBuilder,
  subpath: svg_path.Subpath,
  distance: Float,
  options: Options,
) -> Result(List(OffsetSegment), Error) {
  let OffsetBuilder(build:) = builder
  build(subpath, distance, options)
}

fn parametric_joined_offset_segments(
  offsets: List(OffsetSegment),
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
  first: OffsetSegment,
  previous: OffsetSegment,
  rest: List(OffsetSegment),
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
  left: OffsetSegment,
  right: OffsetSegment,
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
  let distance_a = 0.0 -. radius
  let distance_b = radius
  use provisional_a <- result.try(subpath_untrimmed_with(
    source,
    distance: distance_a,
    options:,
  ))
  use provisional_b <- result.try(subpath_untrimmed_with(
    source,
    distance: distance_b,
    options:,
  ))
  use #(cross_a, cross_b) <- result.try(cross_side_split_parameters(
    provisional_a,
    provisional_b,
  ))
  use chunks_a <- result.try(parametric_pruned_band_side_chunks(
    source,
    provisional_a,
    distance_a:,
    distance_b:,
    options:,
    extra_split_points: cross_a,
  ))
  use chunks_b <- result.try(parametric_pruned_band_side_chunks(
    source,
    provisional_b,
    distance_a:,
    distance_b:,
    options:,
    extra_split_points: cross_b,
  ))
  let chunks =
    list.append(chunks_a, chunks_b)
    |> merge_connecting_chunks(options.fitting.tolerance)
  use subpaths <- result.try(chunks_to_subpaths(
    chunks,
    options.fitting.tolerance,
    closed: True,
  ))
  Ok(svg_path.Path(subpaths:))
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
      use depth <- result.try(outline_contour_depth(first, all))
      let assert Ok(remainder) = int.remainder(depth, by: 2)
      let oriented_first =
        orient_outline_subpath(first, clockwise: remainder == 0)
      orient_outline_subpaths(rest, all:, oriented: [oriented_first, ..oriented])
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

fn parametric_pruned_subpath(
  source: svg_path.Subpath,
  provisional: svg_path.Subpath,
  distance: Float,
  options: Options,
) -> Result(svg_path.Path, Error) {
  use subpaths <- result.try(
    parametric_pruned_side(
      source,
      provisional,
      distance,
      options,
      extra_split_points: [],
    ),
  )
  Ok(svg_path.Path(subpaths:))
}

fn parametric_pruned_pair(
  source: svg_path.Subpath,
  provisional_a provisional_a: svg_path.Subpath,
  distance_a distance_a: Float,
  provisional_b provisional_b: svg_path.Subpath,
  distance_b distance_b: Float,
  options options: Options,
) -> Result(List(svg_path.Subpath), Error) {
  use #(cross_a, cross_b) <- result.try(cross_side_split_parameters(
    provisional_a,
    provisional_b,
  ))
  use subpaths_a <- result.try(parametric_pruned_band_side(
    source,
    provisional_a,
    distance_a:,
    distance_b:,
    options:,
    extra_split_points: cross_a,
  ))
  use subpaths_b <- result.try(parametric_pruned_band_side(
    source,
    provisional_b,
    distance_a:,
    distance_b:,
    options:,
    extra_split_points: cross_b,
  ))
  Ok(list.append(subpaths_a, subpaths_b))
}

fn parametric_pruned_side(
  source: svg_path.Subpath,
  provisional: svg_path.Subpath,
  distance: Float,
  options: Options,
  extra_split_points extra_split_points: List(svg_path.SubpathParameter),
) -> Result(List(svg_path.Subpath), Error) {
  use sections <- result.try(parametric_self_intersection_sections(
    provisional,
    intersections.default_options(),
    options.fitting.tolerance,
    extra_split_points:,
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
  let retained = merge_touching_chunks(retained, options.fitting.tolerance)
  use subpaths <- result.try(chunks_to_subpaths(
    retained,
    options.fitting.tolerance,
    closed: svg_path.subpath_is_closed(source),
  ))
  Ok(subpaths)
}

fn parametric_pruned_band_side(
  source: svg_path.Subpath,
  provisional: svg_path.Subpath,
  distance_a distance_a: Float,
  distance_b distance_b: Float,
  options options: Options,
  extra_split_points extra_split_points: List(svg_path.SubpathParameter),
) -> Result(List(svg_path.Subpath), Error) {
  use retained <- result.try(parametric_pruned_band_side_chunks(
    source,
    provisional,
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
  provisional: svg_path.Subpath,
  distance_a distance_a: Float,
  distance_b distance_b: Float,
  options options: Options,
  extra_split_points extra_split_points: List(svg_path.SubpathParameter),
) -> Result(List(List(svg_path.Segment)), Error) {
  use sections <- result.try(parametric_self_intersection_sections(
    provisional,
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
  use section <- result.try(normalize_chunk(section, options.fitting.tolerance))
  use section <- result.try(
    svg_path.subpath_with(section, policy: svg_path.Wiggle)
    |> result.map_error(PathError),
  )
  use length <- result.try(
    svg_path.subpath_length(section) |> result.map_error(PathError),
  )
  parametric_section_has_enough_non_negative_samples(
    section,
    length,
    section_sample_parameters(),
    source:,
    distance:,
    options:,
    count: 0,
  )
}

fn section_sample_parameters() -> List(Float) {
  [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]
}

fn parametric_section_has_enough_non_negative_samples(
  section: svg_path.Subpath,
  length: Float,
  samples: List(Float),
  source source: svg_path.Subpath,
  distance distance: Float,
  options options: Options,
  count count: Int,
) -> Result(Bool, Error) {
  case samples {
    [] -> Ok(count >= 5)
    [first, ..rest] -> {
      use point <- result.try(
        svg_path.subpath_point_at_length(section, distance: length *. first)
        |> result.map_error(PathError),
      )
      use is_non_negative <- result.try(parametric_point_is_non_negative(
        point,
        source:,
        distance:,
        options:,
      ))
      let count = case is_non_negative {
        True -> count + 1
        False -> count
      }
      parametric_section_has_enough_non_negative_samples(
        section,
        length,
        rest,
        source:,
        distance:,
        options:,
        count:,
      )
    }
  }
}

fn parametric_point_is_non_negative(
  point: svg_path.Point,
  source source: svg_path.Subpath,
  distance distance: Float,
  options options: Options,
) -> Result(Bool, Error) {
  let margin = distance_margin(options)
  use projection <- result.try(
    svg_path.subpath_projection_with(
      point,
      to: source,
      options: options.trimming,
    )
    |> result.map_error(PathError),
  )
  Ok(projection.distance +. margin >=. float.absolute_value(distance))
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
    svg_path.subpath_with(section, policy: svg_path.Wiggle)
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
    svg_path.subpath_with(section, policy: svg_path.Wiggle)
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
  use left_a <- result.try(join_offset_segment_end(left, distance_a, options))
  use right_a <- result.try(join_offset_segment_start(
    right,
    distance_a,
    options,
  ))
  use left_b <- result.try(join_offset_segment_end(left, distance_b, options))
  use right_b <- result.try(join_offset_segment_start(
    right,
    distance_b,
    options,
  ))
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
  use left_a_end <- result.try(offset_segment_end(left_a))
  use right_a_start <- result.try(offset_segment_start(right_a))
  use left_b_end <- result.try(offset_segment_end(left_b))
  use right_b_start <- result.try(offset_segment_start(right_b))
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
  options: Options,
) -> Result(OffsetSegment, Error) {
  use offsets <- result.try(offset_source_segment_with_builder(
    segment,
    distance,
    options,
    OriginalRecursiveFit,
  ))
  case offsets {
    [] -> Error(NonFinite)
    [first, ..] -> Ok(first)
  }
}

fn join_offset_segment_end(
  segment: svg_path.Segment,
  distance: Float,
  options: Options,
) -> Result(OffsetSegment, Error) {
  use offsets <- result.try(offset_source_segment_with_builder(
    segment,
    distance,
    options,
    OriginalRecursiveFit,
  ))
  offsets |> list.last |> result.map_error(fn(_) { NonFinite })
}

fn offset_segment_start(
  offset: OffsetSegment,
) -> Result(svg_path.Point, Error) {
  Ok(svg_path.segment_start(offset.segment))
}

fn offset_segment_end(offset: OffsetSegment) -> Result(svg_path.Point, Error) {
  Ok(svg_path.segment_end(offset.segment))
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

fn merge_connecting_chunks(
  chunks: List(List(svg_path.Segment)),
  tolerance: Float,
) -> List(List(svg_path.Segment)) {
  let #(merged, changed) =
    merge_connecting_chunks_pass(chunks, tolerance, merged: [])
  case changed {
    True -> merge_connecting_chunks(merged, tolerance)
    False -> merged
  }
}

fn merge_connecting_chunks_pass(
  chunks: List(List(svg_path.Segment)),
  tolerance: Float,
  merged merged: List(List(svg_path.Segment)),
) -> #(List(List(svg_path.Segment)), Bool) {
  case chunks {
    [] -> #(list.reverse(merged), False)
    [first, ..remaining] ->
      case find_connecting_chunk(first, remaining, tolerance, skipped: []) {
        Ok(#(connected, rest)) -> #(
          list.reverse(merged) |> list.append([connected, ..rest]),
          True,
        )
        Error(Nil) ->
          merge_connecting_chunks_pass(remaining, tolerance, merged: [
            first,
            ..merged
          ])
      }
  }
}

fn find_connecting_chunk(
  current: List(svg_path.Segment),
  candidates: List(List(svg_path.Segment)),
  tolerance: Float,
  skipped skipped: List(List(svg_path.Segment)),
) -> Result(#(List(svg_path.Segment), List(List(svg_path.Segment))), Nil) {
  case candidates {
    [] -> Error(Nil)
    [first, ..rest] ->
      case connect_chunks(current, first, tolerance) {
        Ok(connected) ->
          Ok(#(connected, list.append(list.reverse(skipped), rest)))
        Error(Nil) ->
          find_connecting_chunk(current, rest, tolerance, skipped: [
            first,
            ..skipped
          ])
      }
  }
}

fn connect_chunks(
  left: List(svg_path.Segment),
  right: List(svg_path.Segment),
  tolerance: Float,
) -> Result(List(svg_path.Segment), Nil) {
  case left, right, list.last(left), list.last(right) {
    [left_first, ..], [right_first, ..], Ok(left_last), Ok(right_last) -> {
      let left_start = svg_path.segment_start(left_first)
      let left_end = svg_path.segment_end(left_last)
      let right_start = svg_path.segment_start(right_first)
      let right_end = svg_path.segment_end(right_last)
      case same_point(left_end, right_start, tolerance) {
        True -> Ok(list.append(left, right))
        False ->
          case same_point(left_end, right_end, tolerance) {
            True -> Ok(list.append(left, reverse_segments(right)))
            False ->
              case same_point(left_start, right_end, tolerance) {
                True -> Ok(list.append(right, left))
                False ->
                  case same_point(left_start, right_start, tolerance) {
                    True -> Ok(list.append(reverse_segments(right), left))
                    False -> Error(Nil)
                  }
              }
          }
      }
    }
    _, _, _, _ -> Error(Nil)
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
          svg_path.subpath_set_closed_with(
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
  options.fitting.tolerance
}

fn stalled_run_offset_builder() -> OffsetBuilder {
  offset_builder_with(
    splitter: join_free_portions,
    smooth_builder: stalled_run_smooth_offset_builder(),
  )
}

fn offset_builder_with(
  splitter splitter: fn(svg_path.Subpath, Options) ->
    Result(List(JoinFreePortion), Error),
  smooth_builder smooth_builder: SmoothOffsetBuilder,
) -> OffsetBuilder {
  OffsetBuilder(build: fn(subpath, distance, options) {
    use portions <- result.try(splitter(subpath, options))
    build_offset_portions(
      portions,
      distance,
      options,
      smooth_builder,
      converted: [],
    )
  })
}

fn build_offset_portions(
  portions: List(JoinFreePortion),
  distance: Float,
  options: Options,
  smooth_builder: SmoothOffsetBuilder,
  converted converted: List(OffsetSegment),
) -> Result(List(OffsetSegment), Error) {
  case portions {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      let SmoothOffsetBuilder(build:) = smooth_builder
      use offsets <- result.try(build(first, distance, options))
      build_offset_portions(
        rest,
        distance,
        options,
        smooth_builder,
        converted: list.append(list.reverse(offsets), converted),
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
      Ok(mark_closed_join_free_portion(
        portions,
        closed: svg_path.subpath_is_closed(subpath),
      ))
    }
  }
}

fn original_recursive_smooth_offset_builder() -> SmoothOffsetBuilder {
  SmoothOffsetBuilder(build: original_recursive_smooth_offset_segments)
}

fn stalled_run_smooth_offset_builder() -> SmoothOffsetBuilder {
  SmoothOffsetBuilder(build: stalled_run_smooth_offset_segments)
}

fn original_recursive_smooth_offset_segments(
  portion: JoinFreePortion,
  distance: Float,
  options: Options,
) -> Result(List(OffsetSegment), Error) {
  let JoinFreePortion(subpath:, closed:) = portion
  offset_subpath_segments(
    svg_path.subpath_segments(subpath),
    distance,
    options,
    fit_policy: OriginalRecursiveFit,
    closed:,
    converted: [],
  )
}

fn stalled_run_smooth_offset_segments(
  portion: JoinFreePortion,
  distance: Float,
  options: Options,
) -> Result(List(OffsetSegment), Error) {
  let JoinFreePortion(subpath:, closed:) = portion
  let pieces =
    svg_path.subpath_segments(subpath)
    |> classify_smooth_source_pieces(
      distance,
      threshold: options.stalled_offset_diameter,
    )
  use offsets <- result.try(
    offset_smooth_source_pieces(
      pieces,
      distance,
      options,
      closed:,
      converted: [],
    ),
  )
  use _ <- result.try(assert_smooth_offset_postconditions(
    offsets,
    options.tangent_heal_angle_degrees,
  ))
  Ok(offsets)
}

fn classify_smooth_source_pieces(
  segments: List(svg_path.Segment),
  distance: Float,
  threshold threshold: Float,
) -> List(SmoothSourcePiece) {
  classify_smooth_source_pieces_loop(
    segments,
    distance,
    threshold,
    stalled: [],
    pieces: [],
  )
}

fn classify_smooth_source_pieces_loop(
  segments: List(svg_path.Segment),
  distance: Float,
  threshold: Float,
  stalled stalled: List(svg_path.Segment),
  pieces pieces: List(SmoothSourcePiece),
) -> List(SmoothSourcePiece) {
  case segments {
    [] -> {
      let pieces = prepend_stalled_source_run(stalled, to: pieces)
      list.reverse(pieces)
    }
    [first, ..rest] -> {
      case source_segment_offset_is_stalled(first, distance, threshold) {
        True ->
          classify_smooth_source_pieces_loop(
            rest,
            distance,
            threshold,
            stalled: [first, ..stalled],
            pieces:,
          )
        False -> {
          let pieces = prepend_stalled_source_run(stalled, to: pieces)
          classify_smooth_source_pieces_loop(
            rest,
            distance,
            threshold,
            stalled: [],
            pieces: [BigSourceSegment(first), ..pieces],
          )
        }
      }
    }
  }
}

fn prepend_stalled_source_run(
  stalled: List(svg_path.Segment),
  to pieces: List(SmoothSourcePiece),
) -> List(SmoothSourcePiece) {
  case stalled {
    [] -> pieces
    _ -> [StalledSourceRun(list.reverse(stalled)), ..pieces]
  }
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
        offset_point(segment, t: 1.0, distance:)
      {
        Ok(start), Ok(end) -> point_distance(start, end) <=. threshold
        _, _ -> False
      }
  }
}

fn offset_smooth_source_pieces(
  pieces: List(SmoothSourcePiece),
  distance: Float,
  options: Options,
  closed closed: Bool,
  converted converted: List(OffsetSegment),
) -> Result(List(OffsetSegment), Error) {
  case pieces {
    [] ->
      heal_offset_boundaries(
        list.reverse(converted),
        distance,
        options.tangent_heal_angle_degrees,
        closed:,
      )
    [first, ..rest] -> {
      use offsets <- result.try(offset_smooth_source_piece(
        first,
        distance,
        options,
      ))
      offset_smooth_source_pieces(
        rest,
        distance,
        options,
        closed:,
        converted: list.append(list.reverse(offsets), converted),
      )
    }
  }
}

fn offset_smooth_source_piece(
  piece: SmoothSourcePiece,
  distance: Float,
  options: Options,
) -> Result(List(OffsetSegment), Error) {
  case piece {
    BigSourceSegment(segment) -> {
      use subpath <- result.try(
        svg_path.subpath_with([segment], policy: svg_path.Strict)
        |> result.map_error(PathError),
      )
      let SmoothOffsetBuilder(build:) =
        original_recursive_smooth_offset_builder()
      build(JoinFreePortion(subpath:, closed: False), distance, options)
    }
    StalledSourceRun(segments) -> offset_stalled_source_run(segments, distance)
  }
}

fn offset_stalled_source_run(
  segments: List(svg_path.Segment),
  distance: Float,
) -> Result(List(OffsetSegment), Error) {
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
              use offset <- result.try(offset_circular_arc_segment(
                first,
                distance,
                radius,
              ))
              Ok([offset])
            }
            _, _ ->
              offset_nonempty_stalled_source_run(
                first,
                last,
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
  start: svg_path.Point,
  end: svg_path.Point,
  samples: List(#(Float, bezier.BezierPoint)),
) -> Result(List(OffsetSegment), Error) {
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
      use offset <- result.try(make_offset_segment(
        segment:,
        source_start: svg_path.segment_start(first),
        source_end: svg_path.segment_end(last),
        source_start_tangent:,
        source_end_tangent:,
      ))
      Ok([offset])
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
  offsets: List(OffsetSegment),
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
  left: OffsetSegment,
  right: OffsetSegment,
  heal_angle: Float,
) -> Result(Nil, Error) {
  case
    svg_path.segment_end(left.segment) == svg_path.segment_start(right.segment)
  {
    False -> Error(NonFinite)
    True ->
      case left.source_end == right.source_start {
        False -> Ok(Nil)
        True ->
          assert_smooth_offset_tangent_boundary(
            left.segment,
            right.segment,
            heal_angle,
          )
      }
  }
}

fn assert_smooth_offset_tangent_boundary(
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
      case angle <=. heal_angle {
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
      use subpath <- result.try(
        svg_path.subpath_with(list.reverse(segments), policy: svg_path.Strict)
        |> result.map_error(PathError),
      )
      use subpath <- result.try(
        svg_path.subpath_set_closed_with(
          subpath,
          closed:,
          policy: svg_path.Strict,
        )
        |> result.map_error(PathError),
      )
      Ok([JoinFreePortion(subpath:, closed:), ..portions])
    }
  }
}

fn mark_closed_join_free_portion(
  portions: List(JoinFreePortion),
  closed closed: Bool,
) -> List(JoinFreePortion) {
  case closed, portions {
    True, [JoinFreePortion(subpath:, ..)] -> [
      JoinFreePortion(subpath:, closed: True),
    ]
    _, _ -> portions
  }
}

fn source_boundary_is_smooth(
  left: svg_path.Segment,
  right: svg_path.Segment,
  options: Options,
) -> Bool {
  case unit_tangent(left, t: 1.0), unit_tangent(right, t: 0.0) {
    Ok(left_tangent), Ok(right_tangent) -> {
      let angle =
        float.absolute_value(signed_angle(left_tangent, right_tangent))
      angle <=. options.tangent_heal_angle_degrees
    }
    _, _ -> False
  }
}

fn offset_subpath_segments(
  segments: List(svg_path.Segment),
  distance: Float,
  options: Options,
  fit_policy fit_policy: OriginalRecursiveOffsetBuilderFitPolicy,
  closed closed: Bool,
  converted converted: List(OffsetSegment),
) -> Result(List(OffsetSegment), Error) {
  case segments {
    [] ->
      heal_offset_boundaries(
        list.reverse(converted),
        distance,
        options.tangent_heal_angle_degrees,
        closed: closed,
      )
    [first, ..rest] -> {
      use offsets <- result.try(offset_source_segment_with_builder(
        first,
        distance,
        options,
        fit_policy,
      ))
      offset_subpath_segments(
        rest,
        distance,
        options,
        fit_policy:,
        closed:,
        converted: list.append(list.reverse(offsets), converted),
      )
    }
  }
}

fn heal_offset_boundaries(
  offsets: List(OffsetSegment),
  distance: Float,
  heal_angle: Float,
  closed closed: Bool,
) -> Result(List(OffsetSegment), Error) {
  use healed <- result.try(heal_adjacent_offset_boundaries(
    offsets,
    distance,
    heal_angle,
  ))
  case closed {
    False -> Ok(healed)
    True -> heal_wrapping_offset_boundary(healed, distance, heal_angle)
  }
}

fn heal_adjacent_offset_boundaries(
  offsets: List(OffsetSegment),
  distance: Float,
  heal_angle: Float,
) -> Result(List(OffsetSegment), Error) {
  case offsets {
    [] | [_] -> Ok(offsets)
    [first, second, ..rest] -> {
      use #(first, second) <- result.try(heal_offset_boundary(
        first,
        second,
        distance,
        heal_angle,
      ))
      heal_adjacent_offset_boundaries_loop(
        second,
        rest,
        distance,
        heal_angle,
        healed: [
          first,
        ],
      )
    }
  }
}

fn heal_adjacent_offset_boundaries_loop(
  previous: OffsetSegment,
  rest: List(OffsetSegment),
  distance: Float,
  heal_angle: Float,
  healed healed: List(OffsetSegment),
) -> Result(List(OffsetSegment), Error) {
  case rest {
    [] -> Ok(list.reverse([previous, ..healed]))
    [next, ..remaining] -> {
      use #(previous, next) <- result.try(heal_offset_boundary(
        previous,
        next,
        distance,
        heal_angle,
      ))
      heal_adjacent_offset_boundaries_loop(
        next,
        remaining,
        distance,
        heal_angle,
        healed: [previous, ..healed],
      )
    }
  }
}

fn heal_wrapping_offset_boundary(
  offsets: List(OffsetSegment),
  distance: Float,
  heal_angle: Float,
) -> Result(List(OffsetSegment), Error) {
  case offsets {
    [] | [_] -> Ok(offsets)
    [first, ..rest] -> {
      use last <- result.try(last_list_item(rest))
      use #(last, first) <- result.try(heal_offset_boundary(
        last,
        first,
        distance,
        heal_angle,
      ))
      Ok([first, ..replace_last_offset(rest, last)])
    }
  }
}

fn heal_offset_boundary(
  left: OffsetSegment,
  right: OffsetSegment,
  distance: Float,
  heal_angle: Float,
) -> Result(#(OffsetSegment, OffsetSegment), Error) {
  case shared_boundary_tangent(left, right, heal_angle) {
    Error(_) -> Ok(#(left, right))
    Ok(tangent) -> {
      let corner = left.source_end
      let point = add(corner, scale(rotate_clockwise(tangent), distance))
      let left = snap_offset_end_to_boundary(left, point, tangent)
      let right = snap_offset_start_to_boundary(right, point, tangent)
      Ok(#(left, right))
    }
  }
}

fn shared_boundary_tangent(
  left: OffsetSegment,
  right: OffsetSegment,
  heal_angle: Float,
) -> Result(svg_path.Point, Error) {
  let left_tangent = left.source_end_tangent
  let right_tangent = right.source_start_tangent
  let angle = float.absolute_value(signed_angle(left_tangent, right_tangent))
  case angle <=. heal_angle {
    False -> Error(NonFinite)
    True -> unit_vector(add(left_tangent, right_tangent), t: 1.0)
  }
}

fn snap_offset_end_to_boundary(
  offset: OffsetSegment,
  point: svg_path.Point,
  tangent: svg_path.Point,
) -> OffsetSegment {
  OffsetSegment(
    ..offset,
    segment: snap_offset_segment_boundary(
      offset.segment,
      point,
      tangent,
      at_end: True,
    ),
    source_end_tangent: tangent,
  )
}

fn snap_offset_start_to_boundary(
  offset: OffsetSegment,
  point: svg_path.Point,
  tangent: svg_path.Point,
) -> OffsetSegment {
  OffsetSegment(
    ..offset,
    segment: snap_offset_segment_boundary(
      offset.segment,
      point,
      tangent,
      at_end: False,
    ),
    source_start_tangent: tangent,
  )
}

fn snap_offset_segment_boundary(
  segment: svg_path.Segment,
  point: svg_path.Point,
  tangent: svg_path.Point,
  at_end at_end: Bool,
) -> svg_path.Segment {
  case at_end {
    True -> snap_offset_segment_end(segment, point, tangent)
    False -> snap_offset_segment_start(segment, point, tangent)
  }
}

fn snap_offset_segment_start(
  segment: svg_path.Segment,
  start: svg_path.Point,
  tangent: svg_path.Point,
) -> svg_path.Segment {
  case segment {
    svg_path.Line(end:, ..) -> svg_path.Line(start:, end:)
    svg_path.QuadraticBezier(control:, end:, ..) -> {
      let handle = point_distance(control, svg_path.segment_start(segment))
      svg_path.QuadraticBezier(
        start:,
        control: add(start, scale(tangent, handle)),
        end:,
      )
    }
    svg_path.CubicBezier(control1:, control2:, end:, ..) -> {
      let handle = point_distance(control1, svg_path.segment_start(segment))
      svg_path.CubicBezier(
        start:,
        control1: add(start, scale(tangent, handle)),
        control2:,
        end:,
      )
    }
    svg_path.Arc(radius:, x_axis_rotation:, large_arc:, sweep:, end:, ..) ->
      svg_path.Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:)
  }
}

fn snap_offset_segment_end(
  segment: svg_path.Segment,
  end: svg_path.Point,
  tangent: svg_path.Point,
) -> svg_path.Segment {
  case segment {
    svg_path.Line(start:, ..) -> svg_path.Line(start:, end:)
    svg_path.QuadraticBezier(start:, control:, ..) -> {
      let handle = point_distance(control, svg_path.segment_end(segment))
      svg_path.QuadraticBezier(
        start:,
        control: subtract(end, scale(tangent, handle)),
        end:,
      )
    }
    svg_path.CubicBezier(start:, control1:, control2:, ..) -> {
      let handle = point_distance(control2, svg_path.segment_end(segment))
      svg_path.CubicBezier(
        start:,
        control1:,
        control2: subtract(end, scale(tangent, handle)),
        end:,
      )
    }
    svg_path.Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, ..) ->
      svg_path.Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:)
  }
}

fn last_list_item(items: List(a)) -> Result(a, Error) {
  case list.last(items) {
    Ok(item) -> Ok(item)
    Error(_) -> Error(NonFinite)
  }
}

fn replace_last_offset(
  offsets: List(OffsetSegment),
  replacement: OffsetSegment,
) -> List(OffsetSegment) {
  case offsets {
    [] -> []
    [_] -> [replacement]
    [first, ..rest] -> [first, ..replace_last_offset(rest, replacement)]
  }
}

fn directed_miter_join(
  left: OffsetSegment,
  right: OffsetSegment,
  start: svg_path.Point,
  end: svg_path.Point,
  distance: Float,
  miter_limit: Float,
) -> Result(List(svg_path.Segment), Error) {
  let left_tangent = left.source_end_tangent
  let right_tangent = right.source_start_tangent

  case directed_line_intersection(start, left_tangent, end, right_tangent) {
    Error(_) -> Ok(line_segments_between([start, end]))
    Ok(apex) -> {
      let corner = left.source_end
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
      let left_normal = rotate_clockwise(left.source_end_tangent)
      let right_normal = rotate_clockwise(right.source_start_tangent)
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

fn offset_source_segment_with_builder(
  segment: svg_path.Segment,
  distance: Float,
  options: Options,
  fit_policy: OriginalRecursiveOffsetBuilderFitPolicy,
) -> Result(List(OffsetSegment), Error) {
  case segment {
    svg_path.Line(..) -> {
      use offset_start <- result.try(offset_point(segment, t: 0.0, distance:))
      use offset_end <- result.try(offset_point(segment, t: 1.0, distance:))
      use offset <- result.try(build_offset_segment(
        source: segment,
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
              use offset <- result.try(offset_circular_arc_segment(
                segment,
                distance,
                radius,
              ))
              Ok([offset])
            }
          }
        }
        Error(_) ->
          offset_cubic_segments_with_builder(
            svg_path.segment_to_cubic_beziers(segment),
            distance,
            options,
            fit_policy,
            converted: [],
          )
      }
    }
    svg_path.QuadraticBezier(..) | svg_path.CubicBezier(..) ->
      offset_cubic_segments_with_builder(
        svg_path.segment_to_cubic_beziers(segment),
        distance,
        options,
        fit_policy,
        converted: [],
      )
  }
}

fn offset_circular_arc_segment(
  segment: svg_path.Segment,
  distance: Float,
  radius: Float,
) -> Result(OffsetSegment, Error) {
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
  build_offset_segment(source: segment, segment: arc)
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
  source source: svg_path.Segment,
  segment segment: svg_path.Segment,
) -> Result(OffsetSegment, Error) {
  use source_start_tangent <- result.try(unit_tangent(source, t: 0.0))
  use source_end_tangent <- result.try(unit_tangent(source, t: 1.0))
  make_offset_segment(
    segment:,
    source_start: svg_path.segment_start(source),
    source_end: svg_path.segment_end(source),
    source_start_tangent:,
    source_end_tangent:,
  )
}

fn make_offset_segment(
  segment segment: svg_path.Segment,
  source_start source_start: svg_path.Point,
  source_end source_end: svg_path.Point,
  source_start_tangent source_start_tangent: svg_path.Point,
  source_end_tangent source_end_tangent: svg_path.Point,
) -> Result(OffsetSegment, Error) {
  Ok(OffsetSegment(
    segment:,
    source_start:,
    source_end:,
    source_start_tangent:,
    source_end_tangent:,
  ))
}

fn offset_cubic_segments_with_builder(
  segments: List(svg_path.Segment),
  distance: Float,
  options: Options,
  fit_policy: OriginalRecursiveOffsetBuilderFitPolicy,
  converted converted: List(OffsetSegment),
) -> Result(List(OffsetSegment), Error) {
  case segments {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use offset <- result.try(offset_cubic_segment_with_builder(
        first,
        distance,
        options,
        fit_policy,
      ))
      offset_cubic_segments_with_builder(
        rest,
        distance,
        options,
        fit_policy,
        converted: list.append(list.reverse(offset), converted),
      )
    }
  }
}

fn offset_cubic_segment_with_builder(
  segment: svg_path.Segment,
  distance: Float,
  options: Options,
  fit_policy: OriginalRecursiveOffsetBuilderFitPolicy,
) -> Result(List(OffsetSegment), Error) {
  case fit_policy {
    OriginalRecursiveFit ->
      recursive_offset_cubic_segment(
        segment,
        distance,
        options,
        depth: options.fitting.max_depth,
      )
    SmartOriginalRecursiveFit ->
      smart_recursive_offset_cubic_segment(
        segment,
        distance,
        options,
        depth: options.fitting.max_depth,
      )
  }
}

fn recursive_offset_cubic_segment(
  segment: svg_path.Segment,
  distance: Float,
  options: Options,
  depth depth: Int,
) -> Result(List(OffsetSegment), Error) {
  use candidate <- result.try(fitted_cubic_offset(segment, distance))
  use divergence <- result.try(offset_divergence(
    segment,
    candidate,
    distance,
    options,
  ))

  case divergence <=. options.fitting.tolerance {
    True -> {
      use offset <- result.try(build_offset_segment(
        source: segment,
        segment: candidate,
      ))
      Ok([offset])
    }
    False ->
      case depth <= 0 {
        True -> Error(MaxDepthReached(divergence))
        False -> {
          use split <- result.try(
            svg_path.segment_split(segment, at: 0.5)
            |> result.map_error(PathError),
          )
          let #(left, right) = split
          use left_offset <- result.try(recursive_offset_cubic_segment(
            left,
            distance,
            options,
            depth: depth - 1,
          ))
          use right_offset <- result.try(recursive_offset_cubic_segment(
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

fn smart_recursive_offset_cubic_segment(
  segment: svg_path.Segment,
  distance: Float,
  options: Options,
  depth depth: Int,
) -> Result(List(OffsetSegment), Error) {
  use candidate <- result.try(smart_fitted_cubic_offset(segment, distance))
  use divergence <- result.try(smart_offset_divergence(
    segment,
    candidate,
    distance,
    options,
  ))

  case divergence <=. options.fitting.tolerance {
    True -> {
      use offset <- result.try(build_offset_segment(
        source: segment,
        segment: candidate,
      ))
      Ok([offset])
    }
    False ->
      case depth <= 0 {
        True -> Error(MaxDepthReached(divergence))
        False -> {
          use split <- result.try(
            svg_path.segment_split(segment, at: 0.5)
            |> result.map_error(PathError),
          )
          let #(left, right) = split
          use left_offset <- result.try(smart_recursive_offset_cubic_segment(
            left,
            distance,
            options,
            depth: depth - 1,
          ))
          use right_offset <- result.try(smart_recursive_offset_cubic_segment(
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

fn fitted_cubic_offset(
  segment: svg_path.Segment,
  distance: Float,
) -> Result(svg_path.Segment, Error) {
  use start <- result.try(offset_point(segment, t: 0.0, distance:))
  use end <- result.try(offset_point(segment, t: 1.0, distance:))
  use samples <- result.try(
    offset_fit_samples(segment, distance, [0.25, 0.5, 0.75], samples: []),
  )
  use curve <- result.try(fit_cubic_offset_curve(
    segment,
    distance,
    start:,
    end:,
    samples:,
  ))
  use candidate <- result.try(fitted_curve_to_segment(curve))

  case segment_is_finite(candidate) {
    True -> Ok(candidate)
    False -> Error(NonFinite)
  }
}

fn smart_fitted_cubic_offset(
  segment: svg_path.Segment,
  distance: Float,
) -> Result(svg_path.Segment, Error) {
  use start <- result.try(offset_point(segment, t: 0.0, distance:))
  use end <- result.try(offset_point(segment, t: 1.0, distance:))
  let samples =
    available_offset_fit_samples(
      segment,
      distance,
      [0.2, 0.35, 0.5, 0.65, 0.8],
      samples: [],
    )
  use curve <- result.try(fit_cubic_offset_curve(
    segment,
    distance,
    start:,
    end:,
    samples:,
  ))
  use candidate <- result.try(fitted_curve_to_segment(curve))

  case segment_is_finite(candidate) {
    True -> Ok(candidate)
    False -> Error(NonFinite)
  }
}

fn fit_cubic_offset_curve(
  segment: svg_path.Segment,
  distance: Float,
  start start: svg_path.Point,
  end end: svg_path.Point,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(bezier.BezierData, Error) {
  case
    offset_derivative(segment, t: 0.0, distance:),
    offset_derivative(segment, t: 1.0, distance:)
  {
    Ok(start_tangent), Ok(end_tangent) -> {
      case
        bezier.fit_cubic_with_endpoint_tangents(
          start: to_bezier_point(start),
          end: to_bezier_point(end),
          start_tangent: to_bezier_point(start_tangent),
          end_tangent: to_bezier_point(end_tangent),
          samples:,
        )
        |> result.map_error(cubic_fit_error)
      {
        Ok(#(curve, _)) -> Ok(curve)
        Error(DegenerateTangent(_)) ->
          fit_cubic_offset_curve_from_points(start:, end:, samples:)
        Error(error) -> Error(error)
      }
    }
    Error(DegenerateTangent(_)), _ ->
      fit_cubic_offset_curve_from_points(start:, end:, samples:)
    _, Error(DegenerateTangent(_)) ->
      fit_cubic_offset_curve_from_points(start:, end:, samples:)
    _, _ -> fit_cubic_offset_curve_from_points(start:, end:, samples:)
  }
}

fn fit_cubic_offset_curve_from_points(
  start start: svg_path.Point,
  end end: svg_path.Point,
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(bezier.BezierData, Error) {
  use fit <- result.try(
    bezier.fit_cubic_with_endpoints(
      start: to_bezier_point(start),
      end: to_bezier_point(end),
      samples:,
    )
    |> result.map_error(cubic_fit_error),
  )
  let #(curve, _) = fit
  Ok(curve)
}

fn offset_fit_samples(
  segment: svg_path.Segment,
  distance: Float,
  t_values: List(Float),
  samples samples: List(#(Float, bezier.BezierPoint)),
) -> Result(List(#(Float, bezier.BezierPoint)), Error) {
  case t_values {
    [] -> Ok(list.reverse(samples))
    [t, ..rest] -> {
      use point <- result.try(offset_point(segment, t:, distance:))
      offset_fit_samples(segment, distance, rest, samples: [
        #(t, to_bezier_point(point)),
        ..samples
      ])
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
      use projection <- result.try(
        svg_path.segment_projection_with(
          point,
          to: candidate,
          options: options.trimming,
        )
        |> result.map_error(PathError),
      )
      let best = float.max(best, projection.distance)
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
          use projection <- result.try(
            svg_path.segment_projection_with(
              point,
              to: candidate,
              options: options.trimming,
            )
            |> result.map_error(PathError),
          )
          let best = float.max(best, projection.distance)
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
  case svg_path.segment_derivative(segment, at: t) {
    Ok(derivative) -> {
      case point_length(derivative) >. tangent_epsilon {
        True -> Ok(scale(derivative, 1.0 /. point_length(derivative)))
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

  case point_length(derivative) >. tangent_epsilon {
    True -> Ok(scale(derivative, 1.0 /. point_length(derivative)))
    False -> {
      let start = svg_path.segment_start(segment)
      let end = svg_path.segment_end(segment)
      let chord = subtract(end, start)
      case point_length(chord) >. tangent_epsilon {
        True -> Ok(scale(chord, 1.0 /. point_length(chord)))
        False -> Error(DegenerateTangent(t))
      }
    }
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
