//// Shared numerical implementations for the public operation modules.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import svg_path/bezier
import svg_path/ellipse
import svg_path/internal/number
import svg_path/trig

import svg_path.{
  type BoundingBox, type ContainmentCalculation, type ContainmentOptions,
  type ContainmentRay, type CrossingOptions, type CubicFitHandleState,
  type CubicFitReport, type Directions, type DistanceOptions, type Error,
  type FillRule, type LengthOptions, type MinimizeCandidate,
  type MinimizeOptions, type ParametricOptions, type Path, type PathParameter,
  type PathProjection, type PathWinding, type Point, type PointContainment,
  type Segment, type SegmentProjection, type Subpath, type SubpathParameter,
  type SubpathProjection, Arc, Boundary, BoundaryWinding, BoundingBox,
  CalculatedBoundary, CalculatedWinding, CollapsedHandle, ContainmentOptions,
  CrossingOptions, CubicBezier, CubicFitReport, DegenerateCubicFitTangent,
  DistanceOptions, EmptyPath, EmptySubpath, EmptySubpaths, InvalidLengthDistance,
  InvalidLengthMaxDepth, InvalidLengthTolerance, InvalidMinimizeMaxIterations,
  InvalidMinimizeSamples, InvalidMinimizeTolerance,
  InvalidParametricInitialPieceCount, InvalidParametricInterval,
  InvalidParametricMaxDepth, InvalidParametricSamplesPerPiece,
  InvalidParametricTolerance, InvalidSubdivisionMaxLength,
  InvalidZeroLengthTolerance, LengthMaxDepthReached, LengthOptions, Line,
  MinimizeCandidate, MinimizeMaxIterationsReached, MinimizeOptions,
  NonFiniteParametricPoint, NonFiniteParametricTangent, Outside,
  ParametricFitFailed, ParametricMaxDepthReached, ParametricOptions, Path,
  PathParameter, Point, PositiveHandle, Projection, QuadraticBezier,
  SplitOutsideSegment, SubpathParameter, UnconstrainedHandle,
  UnderdeterminedCubicFit, Winding, arc_center_data, bounding_box_height,
  bounding_box_union, bounding_box_width, canonical_to_subpath_parameter,
  containment_from_winding, containment_ray_for_angle,
  default_containment_horizontal_ray_angle, default_containment_max_iterations,
  default_containment_samples, default_containment_tolerance,
  default_containment_vertical_ray_angle, default_crossing_max_iterations,
  default_crossing_samples, default_crossing_tolerance, default_distance_options,
  default_length_max_depth, default_length_tolerance,
  default_minimize_max_iterations, default_minimize_samples,
  default_minimize_tolerance, default_parametric_initial_piece_count,
  default_parametric_max_depth, default_parametric_samples_per_piece,
  default_parametric_tolerance, distance, distance_squared, from_bezier_point,
  golden_section_ratio, max_point, min_point, nonempty_subpaths,
  original_subpath_consistent_winding, path_derivative, path_point,
  point_to_line_projection, segment_between, segment_between_many,
  segment_crossings_with, segment_derivative, segment_derivative_scale,
  segment_end, segment_from_bezier_data, segment_point, segment_projection_with,
  segment_ray_crossings_with, segment_start, subpath, subpath_between,
  subpath_derivative, subpath_directions, subpath_end_parameter, subpath_point,
  subpath_projection_with, subpath_replace_segments, subpath_segments,
  subpath_split_many, subpath_start, to_bezier_point,
  validate_containment_options, validate_distance_options,
}

/// Return the center point of a bounding box.
pub fn bounding_box_center(box: BoundingBox) -> Point {
  Point(
    box.min.x +. bounding_box_width(box) /. 2.0,
    box.min.y +. bounding_box_height(box) /. 2.0,
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

/// Approximate a parametric curve with a sequence of cubic Bezier segments.
///
/// The parameter interval is split uniformly into
/// `default_parametric_options().initial_piece_count` pieces. Each piece is
/// fitted with a cubic, then recursively bisected in parameter space until the
/// maximum sampled fitting error is within tolerance.
/// `from` and `to` must be finite and unequal; descending intervals are allowed.
/// Otherwise returns `InvalidParametricInterval`. Fitting and construction
/// errors propagate; this function does not guarantee a successful fit.
pub fn subpath_from_parametric(
  from start: Float,
  to end: Float,
  point point_function: fn(Float) -> Point,
) -> Result(Subpath, Error) {
  subpath_from_parametric_with(
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
/// The interval restrictions are the same as for `subpath_from_parametric`.
/// Options must satisfy the constraints documented on `ParametricOptions`;
/// invalid options, failed fits, and exhausted refinement return errors.
pub fn subpath_from_parametric_with(
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

/// Find crossings with a ray's supporting line using default crossing options.
///
/// Like `segment_ray_crossings_with`, this includes negative ray parameters;
/// callers can filter those out when they need only the positive ray.
pub fn segment_ray_crossings(
  segment: Segment,
  origin origin: Point,
  direction direction: Point,
) -> Result(List(#(Float, Float)), Error) {
  segment_ray_crossings_with(
    segment,
    origin:,
    direction:,
    options: default_crossing_options(),
  )
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

/// Return a cheap upper bound on a segment's length.
///
/// Lines use their chord length. Beziers use the sum of their control-polygon
/// edge lengths. Arcs use absolute angular travel in radians times the larger
/// corrected ellipse radius. No numerical integration or subdivision is used.
/// These mathematical upper bounds are evaluated with ordinary floating-point
/// arithmetic, not outward-rounded interval arithmetic, and can substantially
/// overestimate length. Arcs rejected by `arc_center_data` return
/// `DegenerateArc`; see that function for endpoint and radius restrictions.
pub fn segment_length_upper_bound(segment: Segment) -> Result(Float, Error) {
  case segment {
    Line(start:, end:) -> Ok(distance(start, end))
    QuadraticBezier(start:, control:, end:) ->
      Ok(distance(start, control) +. distance(control, end))
    CubicBezier(start:, control1:, control2:, end:) ->
      Ok(
        distance(start, control1)
        +. distance(control1, control2)
        +. distance(control2, end),
      )
    Arc(..) -> segment_derivative_scale(segment)
  }
}

/// Return a convex polygon enclosing the segment, in visual clockwise order.
///
/// The first vertex is the segment start when it is a hull vertex; otherwise
/// it is the lexicographically smallest vertex (x, then y). The first vertex
/// is not repeated at the end. Point and line degeneracies return one or two
/// vertices. Beziers use their control-point hull; arcs use tangent triangles
/// spanning at most 90 degrees on the corrected ellipse, then their hull.
/// This is an ordinary floating-point bound, not outward-rounded arithmetic.
/// Arcs rejected by `arc_center_data` return `DegenerateArc`; see that function
/// for endpoint and radius restrictions.
pub fn segment_bounding_polygon(
  segment: Segment,
) -> Result(List(Point), Error) {
  segment_bounding_polygon_between(segment, 0.0, 1.0)
}

/// Enclose the segment portion between `from` and `to`, both in `0.0..1.0`.
///
/// Reversed intervals are allowed. The boundary remains visually clockwise;
/// its preferred first vertex is the point at `from`, when that is a hull
/// vertex. Equal parameters return one point. Other conventions are those of
/// `segment_bounding_polygon`. Out-of-range parameters return
/// `SplitOutsideSegment`.
pub fn segment_bounding_polygon_between(
  segment: Segment,
  from from: Float,
  to to: Float,
) -> Result(List(Point), Error) {
  case from <. 0.0 || from >. 1.0 || to <. 0.0 || to >. 1.0 {
    True -> Error(SplitOutsideSegment)
    False -> {
      use start <- result.try(segment_point(segment, from))
      case from == to {
        True -> Ok([start])
        False -> {
          use points <- result.try(case segment {
            Arc(..) -> {
              use arc <- result.try(arc_center_data(segment))
              use end <- result.try(segment_point(segment, to))
              // Include the exact stored endpoints as well as reconstructed
              // ellipse points; endpoint encoding can differ by roundoff.
              Ok([start, end, ..bounding_arc_points(arc, from, to)])
            }
            _ -> {
              use piece <- result.try(segment_between(segment, from, to))
              Ok(case piece {
                Line(a, b) -> [a, b]
                QuadraticBezier(a, b, c) -> [a, b, c]
                CubicBezier(a, b, c, d) -> [a, b, c, d]
                Arc(..) -> []
              })
            }
          })
          let sorted =
            list.map(points, fn(p) {
              Point(number.normalize_zero(p.x), number.normalize_zero(p.y))
            })
            |> list.sort(fn(a, b) {
              case float.compare(a.x, b.x) {
                order.Eq -> float.compare(a.y, b.y)
                other -> other
              }
            })
            |> list.unique
          let hull = case sorted {
            [] | [_] -> sorted
            _ -> {
              let lower =
                list.fold(sorted, [], bounding_hull_push) |> list.reverse
              let upper =
                list.fold(list.reverse(sorted), [], bounding_hull_push)
                |> list.reverse
              list.append(
                list.take(lower, list.length(lower) - 1),
                list.take(upper, list.length(upper) - 1),
              )
            }
          }
          let #(before, after) =
            list.split_while(hull, fn(p) { p.x != start.x || p.y != start.y })
          Ok(case after {
            [] -> hull
            _ -> list.append(after, before)
          })
        }
      }
    }
  }
}

fn bounding_hull_push(stack: List(Point), p: Point) -> List(Point) {
  case stack {
    [b, a, ..rest] -> {
      let cross =
        { b.x -. a.x } *. { p.y -. a.y } -. { b.y -. a.y } *. { p.x -. a.x }
      case cross <=. 0.0 {
        True -> bounding_hull_push([a, ..rest], p)
        False -> [p, ..stack]
      }
    }
    _ -> [p, ..stack]
  }
}

fn bounding_arc_points(
  arc: ellipse.CenterArcData,
  from: Float,
  to: Float,
) -> List(Point) {
  let middle = from +. { to -. from } /. 2.0
  let span = arc.delta_angle *. { to -. from }
  case float.absolute_value(span) >. 90.0 {
    True ->
      list.append(
        bounding_arc_points(arc, from, middle),
        bounding_arc_points(arc, middle, to),
      )
    False -> {
      let a = ellipse.arc_point(arc, from)
      let b = ellipse.arc_point(arc, to)
      let m = ellipse.arc_point(arc, middle)
      // Tangent intersection without a nearly-parallel line solve.
      // cos(half-span) is at least sqrt(1/2).
      let divisor = trig.cos_degrees(span /. 2.0)
      [
        Point(a.x, a.y),
        Point(b.x, b.y),
        Point(
          arc.center.x +. { m.x -. arc.center.x } /. divisor,
          arc.center.y +. { m.y -. arc.center.y } /. divisor,
        ),
      ]
    }
  }
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
    subdivide_segments_to_max_length(
      subpath_segments(subpath),
      max_length,
      options,
      [],
    ),
  )
  subpath_replace_segments(subpath, segments)
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

/// Sum the cheap segment-length upper bounds of a subpath.
///
/// Empty subpaths return `0.0`. The closed flag adds no implicit segment.
/// See `segment_length_upper_bound` for the bounds and numerical limitations.
pub fn subpath_length_upper_bound(subpath: Subpath) -> Result(Float, Error) {
  list.try_fold(subpath_segments(subpath), 0.0, fn(total, segment) {
    use bound <- result.try(segment_length_upper_bound(segment))
    Ok(total +. bound)
  })
}

/// Return the approximate length of a subpath using explicit options.
pub fn subpath_length_with(
  subpath: Subpath,
  options options: LengthOptions,
) -> Result(Float, Error) {
  case validate_length_options(options) {
    Error(error) -> Error(error)
    Ok(Nil) ->
      subpath_length_loop(subpath_segments(subpath), options, total: 0.0)
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
  case subpath_segments(subpath) {
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
/// the same split-point rules as `subpath_split_many`.
pub fn subpath_split_at_lengths(
  subpath: Subpath,
  at distances: List(Float),
) -> Result(List(Subpath), Error) {
  subpath_split_at_lengths_with(
    subpath,
    at: distances,
    options: default_length_options(),
  )
}

/// Split a subpath at multiple traveled distances using explicit length
/// options.
pub fn subpath_split_at_lengths_with(
  subpath: Subpath,
  at distances: List(Float),
  options options: LengthOptions,
) -> Result(List(Subpath), Error) {
  use length <- result.try(subpath_length_with(subpath, options:))
  use points <- result.try(
    subpath_parameters_at_known_lengths(subpath, distances, length, options, []),
  )
  subpath_split_many(subpath, at: points)
}

/// Return the approximate length of a path.
///
/// Empty paths have length `0.0`. Move-only subpaths contribute `0.0`.
pub fn path_length(path: Path) -> Result(Float, Error) {
  path_length_with(path, options: default_length_options())
}

/// Sum the cheap segment-length upper bounds across a path's subpaths.
///
/// Empty paths and move-only subpaths contribute `0.0`; gaps between subpaths
/// contribute nothing. See `segment_length_upper_bound` for numerical limits.
pub fn path_length_upper_bound(path: Path) -> Result(Float, Error) {
  list.try_fold(path.subpaths, 0.0, fn(total, subpath) {
    use bound <- result.try(subpath_length_upper_bound(subpath))
    Ok(total +. bound)
  })
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

// Keep the ordinary query unchanged. If absolute refinement stalls at floating-
// point resolution, retry with an enclosure-coordinate roundoff allowance. A
// coarse result may reject a sample only when its separation exceeds both the
// matching tolerance and the refinement uncertainty; ambiguous cases retain
// the original error. A point within tolerance is a geometric witness itself.
@internal
pub fn segment_projection_for_matching(
  sample: svg_path.Point,
  segment: svg_path.Segment,
  matching_tolerance: Float,
) -> Result(svg_path.SegmentProjection, svg_path.Error) {
  case segment_projection(sample, to: segment) {
    Error(svg_path.DistanceMaxIterationsReached(..) as original_error) -> {
      use enclosure <- result.try(segment_bounding_polygon(segment))
      let magnitude =
        list.fold([sample, ..enclosure], 0.0, fn(size, p) {
          float.max(
            size,
            float.max(float.absolute_value(p.x), float.absolute_value(p.y)),
          )
        })
      let defaults = default_distance_options()
      let roundoff = magnitude *. 0.000000000000003552713678800501
      case roundoff >. defaults.tolerance {
        False -> Error(original_error)
        True -> {
          use projection <- result.try(segment_projection_with(
            sample,
            to: segment,
            options: svg_path.DistanceOptions(..defaults, tolerance: roundoff),
          ))
          case
            projection.distance <=. matching_tolerance
            || projection.distance >. matching_tolerance +. roundoff
          {
            True -> Ok(projection)
            False -> Error(original_error)
          }
        }
      }
    }
    result -> result
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
/// projection and ray-crossing queries.
pub fn subpath_containment_with(
  point: Point,
  within subpath: Subpath,
  using fill_rule: FillRule,
  options options: ContainmentOptions,
) -> Result(PointContainment, Error) {
  use _ <- result.try(validate_containment_options(options))
  case subpath_segments(subpath) {
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

/// Return the signed winding number of a path around a point.
///
/// Open subpaths are implicitly closed, matching `path_containment`. If the
/// point is within the boundary tolerance of any non-empty subpath, the result
/// is `BoundaryWinding` because the winding number is not numerically stable at
/// that point.
/// A visually clockwise loop contributes `+1`; a counterclockwise loop
/// contributes `-1`.
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
  case subpath_segments(subpath) {
    [] -> Error(EmptySubpath)
    _ -> {
      use _ <- result.try(validate_length_distance(distance, length:))
      case number.is_zero(distance) {
        True -> Ok(SubpathParameter(segment_index: 0, t: 0.0))
        False ->
          case distance == length {
            True ->
              Ok(
                canonical_to_subpath_parameter(
                  subpath_end_parameter(list.length(subpath_segments(subpath))),
                ),
              )
            False ->
              subpath_parameter_at_valid_length_loop(
                subpath_segments(subpath),
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
  case number.is_zero(distance) {
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
      case list.is_empty(subpath_segments(first)) {
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
      case list.is_empty(subpath_segments(first)) {
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
  let subpath_end = case list.last(subpath_segments(subpath)) {
    Ok(last) -> segment_end(last)
    Error(_) -> subpath_start(subpath)
  }
  let closing_distance =
    point_to_line_projection(point, subpath_end, subpath_start(subpath)).distance
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

fn containment_ray_for_subpath_projection(
  subpath: Subpath,
  projection: SubpathProjection,
) -> ContainmentRay {
  let Projection(at:, ..) = projection
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
      case subpath_segments(subpath) {
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
      case subpath_segments(subpath) {
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
      case list.is_empty(subpath_segments(subpath)) {
        True ->
          path_projection_loop(point, rest, options, index: index + 1, best:)
        False -> {
          use projection <- result.try(subpath_projection_with(
            point,
            to: subpath,
            options:,
          ))
          let path_projection =
            Projection(
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

fn interpolate_float(start: Float, end: Float, t: Float) -> Float {
  start +. { end -. start } *. t
}

fn from_bezier_fit_report(report: bezier.CubicFitReport) -> CubicFitReport {
  CubicFitReport(
    root_sum_square: report.root_sum_square,
    root_mean_square: report.root_mean_square,
    max: report.max,
    start_handle: from_bezier_fit_handle_state(report.start_handle),
    end_handle: from_bezier_fit_handle_state(report.end_handle),
  )
}

fn from_bezier_fit_handle_state(
  state: bezier.CubicFitHandleState,
) -> CubicFitHandleState {
  case state {
    bezier.UnconstrainedHandle -> UnconstrainedHandle
    bezier.PositiveHandle -> PositiveHandle
    bezier.CollapsedHandle -> CollapsedHandle
  }
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
