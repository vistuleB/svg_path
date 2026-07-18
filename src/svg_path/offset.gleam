//// Segment offset construction.
////
//// This module follows the same basic model as `svgpathsio`: lines are offset
//// exactly, while curves are converted to cubic Beziers and approximated by
//// endpoint-normal cubics. The approximation is checked by sampling the true
//// normal extrusion of the source curve and measuring its distance to the
//// proposed offset. If the error is too large, the source curve is split and
//// each half is offset recursively.

import gleam/float
import gleam/int
import gleam/list
import gleam/result
import svg_path
import vec/vec2f

const default_tolerance = 0.01

const default_max_depth = 20

const default_samples = 10

const tangent_epsilon = 0.000001

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

  /// A segment tangent was too small to define a stable normal direction.
  DegenerateTangent(t: Float)

  /// Refinement could not produce an offset within the requested tolerance.
  MaxDepthReached(error: Float)

  /// A calculation produced a non-finite coordinate.
  NonFinite
}

/// Options for segment offset construction.
pub type Options {
  Options(
    tolerance: Float,
    max_depth: Int,
    samples: Int,
    distance: svg_path.DistanceOptions,
  )
}

/// Return default options for offset construction.
pub fn default_options() -> Options {
  Options(
    tolerance: default_tolerance,
    max_depth: default_max_depth,
    samples: default_samples,
    distance: svg_path.default_distance_options(),
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

fn validate_options(options: Options) -> Result(Nil, Error) {
  case options.tolerance <=. 0.0 {
    True -> Error(InvalidTolerance(options.tolerance))
    False ->
      case options.samples <= 0 {
        True -> Error(InvalidSamples(options.samples))
        False ->
          case options.max_depth <= 0 {
            True -> Error(InvalidMaxDepth(options.max_depth))
            False -> Ok(Nil)
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
