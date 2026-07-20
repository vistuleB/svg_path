//// Path offset construction.
////
//// This module follows the same basic model as `svgpathsio`: lines are offset
//// exactly, while curves are converted to cubic Beziers and approximated by
//// endpoint-normal cubics. The approximation is checked by sampling the true
//// normal extrusion of the source curve and measuring its distance to the
//// proposed offset. If the error is too large, the source curve is split and
//// each half is offset recursively.
////
//// Subpath and path offsets create a provisional one-sided offset walk by
//// connecting adjacent segment offsets with the requested join style. The
//// public trimmed offset splits that walk at self-intersections, removes
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
import svg_path/bezier
import svg_path/root
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

type SplitParameter {
  SplitParameter(t: Float, cut: Bool)
}

type SplitPiece {
  SplitPiece(segment: svg_path.Segment, start_is_cut: Bool, end_is_cut: Bool)
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
/// Positive distances offset to the right of the subpath direction. Adjacent
/// offset segments are connected using `default_options().join`. The result is
/// a path because trimming self-intersections can split the offset into
/// multiple subpaths or remove it entirely.
///
/// The provisional offset is split at self-intersections. Each section is
/// sampled at global section-length parameters `0.1, 0.2, ..., 0.9`; sections
/// with fewer than five samples at least `abs(distance) - options.tolerance`
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
  case svg_path.segments(subpath) {
    [] -> Ok(svg_path.empty_path())
    _ ->
      case svg_path.is_closed(subpath) {
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
      svg_path.subpaths(path),
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
      svg_path.subpaths(path),
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
      svg_path.subpaths(path),
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
        converted: list.append(list.reverse(svg_path.subpaths(band)), converted),
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
          list.reverse(svg_path.subpaths(stroke)),
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
      use offset <- result.try(subpath_with(first, distance:, options:))
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
        options.join,
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
        segments: first.offset,
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
        segments: list.append(segments, list.append(connector, next.offset)),
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
    |> merge_connecting_chunks(options.tolerance)
  use subpaths <- result.try(chunks_to_subpaths(
    chunks,
    options.tolerance,
    closed: True,
  ))
  Ok(svg_path.Path(subpaths:))
}

fn orient_outline_path(path: svg_path.Path) -> Result(svg_path.Path, Error) {
  use subpaths <- result.try(
    orient_outline_subpaths(
      svg_path.subpaths(path),
      all: svg_path.subpaths(path),
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
  case svg_path.segments(subpath) {
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
    False -> svg_path.reverse_subpath(subpath)
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
      svg_path.segments(positive),
      list.append(
        end_cap,
        list.append(reverse_segments(svg_path.segments(negative)), start_cap),
      ),
    )
  use candidate <- result.try(
    svg_path.subpath_with(segments, policy: svg_path.Wiggle)
    |> result.map_error(PathError),
  )
  svg_path.set_closed_with(candidate, closed: True, policy: svg_path.Wiggle)
  |> result.map_error(PathError)
}

fn stroke_end_cap(
  source: svg_path.Subpath,
  radius: Float,
  cap: Cap,
) -> Result(List(svg_path.Segment), Error) {
  use end <- result.try(svg_path.end(source) |> result.map_error(PathError))
  let assert Ok(last) = list.last(svg_path.segments(source))
  use tangent <- result.try(unit_tangent(last, t: 1.0))
  stroke_cap_segments(center: end, tangent:, radius:, cap:, at_end: True)
}

fn stroke_start_cap(
  source: svg_path.Subpath,
  radius: Float,
  cap: Cap,
) -> Result(List(svg_path.Segment), Error) {
  use start <- result.try(svg_path.start(source) |> result.map_error(PathError))
  let assert [first, ..] = svg_path.segments(source)
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
          radius: svg_path.point(radius, radius),
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
  |> list.map(svg_path.reverse_segment)
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
    svg_path.default_intersection_options(),
    options.tolerance,
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
  let retained = merge_touching_chunks(retained, options.tolerance)
  use subpaths <- result.try(chunks_to_subpaths(
    retained,
    options.tolerance,
    closed: svg_path.is_closed(source),
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
    options.tolerance,
    closed: svg_path.is_closed(source),
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
    svg_path.default_intersection_options(),
    options.tolerance,
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
  Ok(merge_touching_chunks(retained, options.tolerance))
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
      svg_path.default_intersection_options(),
      options.tolerance,
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
  let retained = merge_touching_chunks(retained, options.tolerance)
  use subpaths <- result.try(chunks_to_subpaths(
    retained,
    options.tolerance,
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
    svg_path.subpath_intersections_with(
      left,
      right,
      options: svg_path.default_intersection_options(),
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
    |> list.sort(by: svg_path.compare_subpath_parameters)
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
    |> list.sort(by: svg_path.compare_subpath_parameters)
    |> unique_subpath_parameters(point_tolerance, [])
  Ok(#(left_parameters, right_parameters))
}

fn parametric_self_intersection_sections(
  subpath: svg_path.Subpath,
  _intersection_options: svg_path.IntersectionOptions,
  _tolerance: Float,
  extra_split_points extra_split_points: List(svg_path.SubpathParameter),
) -> Result(List(List(svg_path.Segment)), Error) {
  use split_points <- result.try(self_intersection_split_parameters(subpath))
  let split_points =
    list.append(split_points, extra_split_points)
    |> list.sort(by: svg_path.compare_subpath_parameters)
    |> unique_subpath_parameters(point_tolerance, [])
  use sections <- result.try(
    split_segments_at_subpath_parameters(
      svg_path.segments(subpath),
      split_points,
      index: 0,
      current: [],
      sections: [],
    ),
  )
  let sections = case svg_path.is_closed(subpath) {
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
            svg_path.segments_between_inside(segment, between: [from_t, to_t])
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
  use section <- result.try(normalize_chunk(section, options.tolerance))
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
      options: options.distance,
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
  use section <- result.try(normalize_chunk(section, options.tolerance))
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
    boundary_probe_distance(distance_a, distance_b, options.tolerance)
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
  use section <- result.try(normalize_chunk(section, options.tolerance))
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
    boundary_probe_distance(0.0 -. radius, radius, options.tolerance)
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
        svg_path.start(source) |> result.map_error(PathError),
      )
      use end <- result.try(svg_path.end(source) |> result.map_error(PathError))
      Ok(
        vec2f.distance_squared(point, with: start) <=. radius *. radius
        || vec2f.distance_squared(point, with: end) <=. radius *. radius,
      )
    }
    Square -> {
      let segments = svg_path.segments(source)
      let assert [first, ..] = segments
      let assert Ok(last) = list.last(segments)
      use start <- result.try(
        svg_path.start(source) |> result.map_error(PathError),
      )
      use end <- result.try(svg_path.end(source) |> result.map_error(PathError))
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
    svg_path.segments(source),
    distance_a:,
    distance_b:,
    options:,
  ))
  case in_body {
    True -> Ok(True)
    False ->
      in_band_joins(
        point,
        svg_path.segments(source),
        closed: svg_path.is_closed(source),
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
    tolerance: options.tolerance,
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
          tolerance: options.tolerance,
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
  use left_a <- result.try(join_offset_segment(left, distance_a, options))
  use right_a <- result.try(join_offset_segment(right, distance_a, options))
  use left_b <- result.try(join_offset_segment(left, distance_b, options))
  use right_b <- result.try(join_offset_segment(right, distance_b, options))
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
        svg_path.set_closed_with(region, closed: True, policy: svg_path.Wiggle)
        |> result.map_error(PathError),
      )
      Ok(Some(region))
    }
  }
}

fn join_offset_segment(
  segment: svg_path.Segment,
  distance: Float,
  options: Options,
) -> Result(OffsetSegment, Error) {
  use offset <- result.try(segment_with(segment, distance:, options:))
  Ok(OffsetSegment(source: segment, offset: svg_path.segments(offset)))
}

fn offset_segment_start(
  offset: OffsetSegment,
) -> Result(svg_path.Point, Error) {
  use first <- result.try(first_offset_segment(offset))
  Ok(svg_path.segment_start(first))
}

fn offset_segment_end(offset: OffsetSegment) -> Result(svg_path.Point, Error) {
  use last <- result.try(last_offset_segment(offset))
  Ok(svg_path.segment_end(last))
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
  case index > options.distance.samples {
    True -> Ok(parameters |> unique_floats(options.distance.tolerance, []))
    False -> {
      let next_t = int_to_float(index) /. int_to_float(options.distance.samples)
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
  case float.absolute_value(previous_value) <=. options.distance.tolerance {
    True -> Ok(Some(previous_t))
    False ->
      case float.absolute_value(next_value) <=. options.distance.tolerance {
        True -> Ok(Some(next_t))
        False ->
          case same_sign(previous_value, next_value) {
            True -> Ok(None)
            False -> {
              let root_options =
                root.Options(
                  tolerance: options.distance.tolerance,
                  max_iterations: options.distance.max_iterations,
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

fn self_intersection_split_parameters(
  subpath: svg_path.Subpath,
) -> Result(List(svg_path.SubpathParameter), Error) {
  use intersections <- result.try(
    svg_path.subpath_self_intersections_with(
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
    |> list.sort(by: svg_path.compare_subpath_parameters)
    |> unique_subpath_parameters(point_tolerance, [])

  Ok(parameters)
}

fn is_open_subpath_boundary_parameter(
  subpath: svg_path.Subpath,
  parameter: svg_path.SubpathParameter,
) -> Bool {
  case svg_path.is_closed(subpath) {
    True -> False
    False -> {
      let length = list.length(svg_path.segments(subpath))
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
  vec2f.distance_squared(a, with: b) <=. tolerance *. tolerance
}

fn distance_margin(options: Options) -> Float {
  options.tolerance
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

fn directed_miter_join(
  left: OffsetSegment,
  right: OffsetSegment,
  start: svg_path.Point,
  end: svg_path.Point,
  distance: Float,
  miter_limit: Float,
) -> Result(List(svg_path.Segment), Error) {
  use left_tangent <- result.try(unit_tangent(left.source, t: 1.0))
  use right_tangent <- result.try(unit_tangent(right.source, t: 0.0))

  case directed_line_intersection(start, left_tangent, end, right_tangent) {
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
  use candidate <- result.try(fitted_cubic_offset(segment, distance))
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

fn fitted_cubic_offset(
  segment: svg_path.Segment,
  distance: Float,
) -> Result(svg_path.Segment, Error) {
  use start <- result.try(offset_point(segment, t: 0.0, distance:))
  use end <- result.try(offset_point(segment, t: 1.0, distance:))
  use start_tangent <- result.try(offset_derivative(segment, t: 0.0, distance:))
  use end_tangent <- result.try(offset_derivative(segment, t: 1.0, distance:))
  use samples <- result.try(
    offset_fit_samples(segment, distance, [0.25, 0.5, 0.75], samples: []),
  )
  use fit <- result.try(
    bezier.fit_cubic_with_endpoint_tangents(
      start: to_bezier_point(start),
      end: to_bezier_point(end),
      start_tangent: to_bezier_point(start_tangent),
      end_tangent: to_bezier_point(end_tangent),
      samples:,
    )
    |> result.map_error(cubic_fit_error),
  )
  let #(curve, _) = fit
  use candidate <- result.try(fitted_curve_to_segment(curve))

  case segment_is_finite(candidate) {
    True -> Ok(candidate)
    False -> Error(NonFinite)
  }
}

fn offset_fit_samples(
  segment: svg_path.Segment,
  distance: Float,
  t_values: List(Float),
  samples samples: List(#(Float, bezier.Point)),
) -> Result(List(#(Float, bezier.Point)), Error) {
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

fn to_bezier_point(point: svg_path.Point) -> bezier.Point {
  bezier.Point(x: point.x, y: point.y)
}

fn from_bezier_point(point: bezier.Point) -> svg_path.Point {
  svg_path.point(point.x, point.y)
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
