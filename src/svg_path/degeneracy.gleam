//// Degenerate and nearly-degenerate geometry cleanup.

import gleam/float
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import svg_path
import svg_path/convex_hull
import svg_path/internal/number
import svg_path/internal/root
import svg_path/point

/// The longest leading segment sequence certified to fit in a thin strip.
@internal
pub type ThinPrefix {
  ThinPrefix(
    segments: List(svg_path.Segment),
    remaining: List(svg_path.Segment),
    hull: Option(svg_path.Subpath),
    strip: Option(convex_hull.MinimumWidthStrip),
  )
}

/// Errors returned by degeneracy cleanup helpers.
pub type Error {
  /// The linearization tolerance must be finite and non-negative.
  InvalidTolerance(tolerance: Float)

  /// An underlying path operation failed.
  PathError(error: svg_path.Error)

  /// Convex-hull construction failed while normalizing degenerate segments.
  ConvexHullError(error: convex_hull.Error)
}

/// Replace maximal contiguous line-degenerate windows in a subpath.
///
/// Each selected window preserves its start and end and the two longitudinal
/// support extrema, ordered by their occurrence in the source. Intermediate
/// local reversals need not be retained. Windows are considered from left to
/// right. Their exact curve-preserving convex hull is
/// grown one segment at a time, and the largest prefix certified to fit in a
/// strip of the requested width is selected first. A `0.0` tolerance collapses
/// a window only when its strip width is exactly zero.
pub fn normalize_degenerate_segments(
  subpath: svg_path.Subpath,
  tolerance tolerance: Float,
) -> Result(svg_path.Subpath, Error) {
  case tolerance <. 0.0 || !number.is_finite(tolerance) {
    True -> Error(InvalidTolerance(tolerance))
    False -> {
      use segments <- result.try(
        colinearize_segments(
          svg_path.subpath_segments(subpath),
          tolerance,
          converted: [],
        ),
      )
      use open <- result.try(case segments {
        [] -> Ok(svg_path.subpath_empty(at: svg_path.subpath_start(subpath)))
        _ ->
          svg_path.subpath_with(segments, policy: svg_path.Strict)
          |> result.map_error(PathError)
      })
      case svg_path.subpath_is_closed(subpath) {
        False -> Ok(open)
        True ->
          svg_path.subpath_close_with(open, policy: svg_path.Strict)
          |> result.map_error(PathError)
      }
    }
  }
}

fn colinearize_segments(
  segments: List(svg_path.Segment),
  tolerance: Float,
  converted converted: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), Error) {
  case segments {
    [] -> Ok(list.reverse(converted))
    [first, ..rest] -> {
      use pending <- result.try(
        svg_path.subpath([first, ..rest]) |> result.map_error(PathError),
      )
      use prefix <- result.try(longest_thin_prefix(pending, tolerance:))
      case prefix.segments {
        [_, _, ..] -> {
          use lines <- result.try(degenerate_window_traversal(prefix, tolerance))
          colinearize_segments(
            prefix.remaining,
            tolerance,
            converted: list.append(list.reverse(lines), converted),
          )
        }
        _ -> {
          use replacement <- result.try(segment_linearize_if_degenerate(
            first,
            tolerance,
          ))
          let replacement = case replacement {
            None -> [first]
            Some(lines) -> lines
          }
          colinearize_segments(
            rest,
            tolerance,
            converted: list.append(list.reverse(replacement), converted),
          )
        }
      }
    }
  }
}

/// Return the longest leading segment sequence certified to fit in a strip.
@internal
pub fn internal_longest_thin_prefix(
  subpath: svg_path.Subpath,
  tolerance tolerance: Float,
) -> Result(ThinPrefix, Error) {
  longest_thin_prefix(subpath, tolerance:)
}

fn longest_thin_prefix(
  subpath: svg_path.Subpath,
  tolerance tolerance: Float,
) -> Result(ThinPrefix, Error) {
  case svg_path.subpath_segments(subpath) {
    [] -> Ok(ThinPrefix(segments: [], remaining: [], hull: None, strip: None))
    [first, ..rest] -> {
      use hull <- result.try(
        convex_hull.segment(first) |> result.map_error(ConvexHullError),
      )
      use decision <- result.try(source_width_decision([first], hull, tolerance))
      case decision {
        convex_hull.MinimumWidthFits(strip) ->
          longest_thin_prefix_loop(
            rest,
            accepted: [first],
            hull:,
            strip:,
            tolerance:,
          )
        convex_hull.MinimumWidthExceeds(..)
        | convex_hull.MinimumWidthUnresolved(..) ->
          Ok(ThinPrefix(
            segments: [],
            remaining: [first, ..rest],
            hull: None,
            strip: None,
          ))
      }
    }
  }
}

fn longest_thin_prefix_loop(
  remaining: List(svg_path.Segment),
  accepted accepted: List(svg_path.Segment),
  hull hull: svg_path.Subpath,
  strip strip: convex_hull.MinimumWidthStrip,
  tolerance tolerance: Float,
) -> Result(ThinPrefix, Error) {
  case remaining {
    [] ->
      Ok(ThinPrefix(
        segments: list.reverse(accepted),
        remaining: [],
        hull: Some(hull),
        strip: Some(strip),
      ))
    [first, ..rest] -> {
      use #(candidate_hull, decision) <- result.try(
        convex_hull.internal_convex_subpath_add_segment_and_test_width(
          hull,
          first,
          tolerance:,
        )
        |> result.map_error(ConvexHullError),
      )
      let decision = case
        convex_hull.internal_source_strip_candidate([first, ..accepted])
      {
        Ok(Some(candidate)) if candidate.width <=. tolerance ->
          convex_hull.MinimumWidthFits(candidate)
        _ -> decision
      }
      case decision {
        convex_hull.MinimumWidthFits(candidate_strip) ->
          longest_thin_prefix_loop(
            rest,
            accepted: [first, ..accepted],
            hull: candidate_hull,
            strip: candidate_strip,
            tolerance:,
          )
        convex_hull.MinimumWidthExceeds(..)
        | convex_hull.MinimumWidthUnresolved(..) -> {
          case
            rebuilt_candidate_width_decision([first, ..accepted], tolerance)
          {
            Ok(#(rebuilt_hull, convex_hull.MinimumWidthFits(rebuilt_strip))) ->
              longest_thin_prefix_loop(
                rest,
                accepted: [first, ..accepted],
                hull: rebuilt_hull,
                strip: rebuilt_strip,
                tolerance:,
              )
            _ ->
              Ok(ThinPrefix(
                segments: list.reverse(accepted),
                remaining: [first, ..rest],
                hull: Some(hull),
                strip: Some(strip),
              ))
          }
        }
      }
    }
  }
}

fn rebuilt_candidate_width_decision(
  reversed_segments: List(svg_path.Segment),
  tolerance: Float,
) -> Result(#(svg_path.Subpath, convex_hull.MinimumWidthDecision), Error) {
  use subpath <- result.try(
    svg_path.subpath_with(
      list.reverse(reversed_segments),
      policy: svg_path.Strict,
    )
    |> result.map_error(PathError),
  )
  use hull <- result.try(
    convex_hull.subpath(subpath) |> result.map_error(ConvexHullError),
  )
  use decision <- result.try(source_width_decision(
    reversed_segments,
    hull,
    tolerance,
  ))
  Ok(#(hull, decision))
}

fn source_width_decision(
  segments: List(svg_path.Segment),
  hull: svg_path.Subpath,
  tolerance: Float,
) -> Result(convex_hull.MinimumWidthDecision, Error) {
  case convex_hull.internal_source_strip_candidate(segments) {
    Ok(Some(strip)) if strip.width <=. tolerance ->
      Ok(convex_hull.MinimumWidthFits(strip))
    _ ->
      convex_hull.internal_convex_subpath_minimum_width_decision(
        hull,
        tolerance:,
      )
      |> result.map_error(ConvexHullError)
  }
}

fn degenerate_window_traversal(
  prefix: ThinPrefix,
  tolerance: Float,
) -> Result(List(svg_path.Segment), Error) {
  let ThinPrefix(segments:, strip:, ..) = prefix
  case strip {
    None -> degenerate_traversal(segments, tolerance)
    Some(strip) ->
      case strip_points_in_traversal_order(segments, strip, tolerance) {
        Error(_) -> degenerate_traversal(segments, tolerance)
        // Candidates were already deduplicated against both endpoint anchors.
        // Do not drop a final short line and thereby move the original end.
        Ok(points) -> Ok(point_traversal_lines(points, 0.0))
      }
  }
}

fn strip_points_in_traversal_order(
  segments: List(svg_path.Segment),
  strip: convex_hull.MinimumWidthStrip,
  tolerance: Float,
) -> Result(List(svg_path.Point), svg_path.Error) {
  let axis = point.rotate_90_clockwise(strip.normal)
  let angle = point.heading(axis)
  let assert [first, ..] = segments
  let start = svg_path.segment_start(first)
  let end = last_segment_end(segments)
  use minimum <- result.try(traversal_support(segments, angle +. 180.0))
  use maximum <- result.try(traversal_support(segments, angle))
  let #(min_index, min_t, min_point, _) = minimum
  let #(max_index, max_t, max_point, _) = maximum
  let ordered = case
    min_index < max_index || { min_index == max_index && min_t <=. max_t }
  {
    True -> [min_point, max_point]
    False -> [max_point, min_point]
  }
  // Endpoints have priority over nearby extrema, including when the original
  // start and end coincide. Only interior candidates are deduplicated.
  let protrusions =
    ordered
    |> list.filter(fn(candidate) {
      point.distance(candidate, start) >. tolerance
      && point.distance(candidate, end) >. tolerance
    })
    |> unique_points(tolerance)
  Ok([start, ..list.append(protrusions, [end])])
}

fn last_segment_end(segments: List(svg_path.Segment)) -> svg_path.Point {
  let assert [first, ..rest] = segments
  last_segment_end_loop(rest, svg_path.segment_end(first))
}

fn last_segment_end_loop(
  segments: List(svg_path.Segment),
  end end: svg_path.Point,
) -> svg_path.Point {
  case segments {
    [] -> end
    [first, ..rest] -> last_segment_end_loop(rest, svg_path.segment_end(first))
  }
}

// Query the original segments, retaining the parameter and segment index.
// A strict comparison keeps the first segment occurrence of tied support.
fn traversal_support(
  segments: List(svg_path.Segment),
  angle: Float,
) -> Result(#(Int, Float, svg_path.Point, Float), svg_path.Error) {
  let assert [first, ..rest] = segments
  use #(t, support_point, value) <- result.try(
    convex_hull.internal_segment_support(first, angle:),
  )
  traversal_support_loop(rest, angle, 1, #(0, t, support_point, value))
}

fn traversal_support_loop(
  segments: List(svg_path.Segment),
  angle: Float,
  index: Int,
  best: #(Int, Float, svg_path.Point, Float),
) -> Result(#(Int, Float, svg_path.Point, Float), svg_path.Error) {
  case segments {
    [] -> Ok(best)
    [first, ..rest] -> {
      use #(t, support_point, value) <- result.try(
        convex_hull.internal_segment_support(first, angle:),
      )
      let best = case value >. best.3 {
        True -> #(index, t, support_point, value)
        False -> best
      }
      traversal_support_loop(rest, angle, index + 1, best)
    }
  }
}

fn unique_points(
  points: List(svg_path.Point),
  tolerance: Float,
) -> List(svg_path.Point) {
  points
  |> list.fold([], fn(unique, point) {
    case point_is_already_present(point, unique, tolerance) {
      True -> unique
      False -> [point, ..unique]
    }
  })
  |> list.reverse
}

fn point_is_already_present(
  point: svg_path.Point,
  points: List(svg_path.Point),
  tolerance: Float,
) -> Bool {
  case points {
    [] -> False
    [first, ..rest] ->
      case point.distance(point, first) <=. tolerance {
        True -> True
        False -> point_is_already_present(point, rest, tolerance)
      }
  }
}

fn point_traversal_lines(
  points: List(svg_path.Point),
  tolerance: Float,
) -> List(svg_path.Segment) {
  case points {
    [] | [_] -> []
    [first, second, ..rest] -> {
      let tail = point_traversal_lines([second, ..rest], tolerance)
      case point.distance(first, second) <=. tolerance {
        True -> tail
        False -> [svg_path.Line(start: first, end: second), ..tail]
      }
    }
  }
}

fn degenerate_traversal(
  segments: List(svg_path.Segment),
  tolerance: Float,
) -> Result(List(svg_path.Segment), Error) {
  case segments {
    [] -> Ok([])
    [first, ..rest] -> {
      use replacement <- result.try(segment_linearize_if_degenerate(
        first,
        tolerance,
      ))
      let replacement = case replacement {
        None -> [first]
        Some(lines) -> lines
      }
      use remaining <- result.try(degenerate_traversal(rest, tolerance))
      Ok(list.append(replacement, remaining))
    }
  }
}

/// Detect a curve that is contained in an absolute-width strip and replace it
/// with ordered line segments when possible.
///
/// `tolerance` is the maximum distance from the replacement line or lines to
/// the curve, in path coordinate units. `Ok(None)` means that the segment is
/// not line-degenerate. `Ok(Some(lines))` preserves collinear backtracking;
/// `Some([])` represents a curve with no movement. Lines themselves return
/// `Ok(None)`. The tolerance must be finite and non-negative; a tolerance of
/// `0.0` collapses the segment only when it lies exactly on a line strip of
/// width zero.
pub fn segment_linearize_if_degenerate(
  segment: svg_path.Segment,
  tolerance tolerance: Float,
) -> Result(Option(List(svg_path.Segment)), Error) {
  case tolerance <. 0.0 || !number.is_finite(tolerance) {
    True -> Error(InvalidTolerance(tolerance))
    False -> segment_degenerate_lines_valid(segment, tolerance)
  }
}

/// Detect whether an entire subpath fits inside one absolute-width line strip.
///
/// `Ok(Some(lines))` returns an ordered line replacement, preserving the
/// subpath's flattened traversal and backtracking. `Ok(None)` means that the
/// subpath is not line-degenerate. Empty subpaths return `Ok(Some([]))`.
pub fn subpath_linearize_if_degenerate(
  subpath: svg_path.Subpath,
  tolerance tolerance: Float,
) -> Result(Option(List(svg_path.Segment)), Error) {
  case tolerance <. 0.0 || !number.is_finite(tolerance) {
    True -> Error(InvalidTolerance(tolerance))
    False -> {
      use replacements <- result.try(
        subpath_degenerate_line_replacements(
          svg_path.subpath_segments(subpath),
          tolerance,
          [],
        ),
      )
      case replacements {
        None -> Ok(None)
        Some(lines) -> degenerate_line_list(lines, tolerance)
      }
    }
  }
}

fn subpath_degenerate_line_replacements(
  segments: List(svg_path.Segment),
  tolerance: Float,
  lines lines: List(svg_path.Segment),
) -> Result(Option(List(svg_path.Segment)), Error) {
  case segments {
    [] -> Ok(Some(list.reverse(lines)))
    [first, ..rest] -> {
      use replacement <- result.try(segment_linearize_if_degenerate(
        first,
        tolerance:,
      ))
      case first, replacement {
        svg_path.Line(..), None ->
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
  segment: svg_path.Segment,
  tolerance: Float,
) -> Result(Option(List(svg_path.Segment)), Error) {
  case segment {
    svg_path.Line(..) -> Ok(None)
    svg_path.QuadraticBezier(start:, control:, end:) ->
      bezier_degenerate_lines(
        segment,
        [start, control, end],
        quadratic_degenerate_breaks(start, control, end, start),
        tolerance,
      )
    svg_path.CubicBezier(start:, control1:, control2:, end:) ->
      bezier_degenerate_lines(
        segment,
        [start, control1, control2, end],
        cubic_degenerate_breaks(start, control1, control2, end, start),
        tolerance,
      )
    svg_path.Arc(start:, radius:, end:, ..) -> {
      case number.is_zero(radius.x) || number.is_zero(radius.y) {
        True -> {
          case start == end {
            True -> Ok(Some([]))
            False -> Ok(Some([svg_path.Line(start:, end:)]))
          }
        }
        False -> {
          use lines <- result.try(
            svg_path.segment_to_lines_with(
              segment,
              options: svg_path.LinearizeOptions(
                tolerance:,
                max_depth: svg_path.default_linearize_options().max_depth,
              ),
            )
            |> result.map_error(PathError),
          )
          degenerate_line_list(lines, tolerance)
        }
      }
    }
  }
}

fn bezier_degenerate_lines(
  segment: svg_path.Segment,
  defining_points: List(svg_path.Point),
  breaks: List(Float),
  tolerance: Float,
) -> Result(Option(List(svg_path.Segment)), Error) {
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
  points: List(svg_path.Point),
  tolerance: Float,
) -> Option(#(svg_path.Point, svg_path.Point)) {
  case points {
    [start, ..] -> {
      case farthest_point(points, start, start) {
        farthest -> {
          case
            point.distance_squared(farthest, start) <=. tolerance *. tolerance
          {
            True -> None
            False -> Some(#(start, point.subtract(farthest, start)))
          }
        }
      }
    }
    [] -> None
  }
}

fn defining_points_are_in_strip(
  points: List(svg_path.Point),
  start: svg_path.Point,
  axis: svg_path.Point,
  tolerance: Float,
) -> Bool {
  let axis_length_squared =
    point.distance_squared(axis, svg_path.Point(0.0, 0.0))
  list.all(points, fn(point) {
    let relative = point.subtract(point, start)
    let cross = relative.x *. axis.y -. relative.y *. axis.x
    float.absolute_value(cross) /. sqrt(axis_length_squared) <=. tolerance
  })
}

fn degenerate_line_list(
  lines: List(svg_path.Segment),
  tolerance: Float,
) -> Result(Option(List(svg_path.Segment)), Error) {
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

fn farthest_point(
  points: List(svg_path.Point),
  origin: svg_path.Point,
  best: svg_path.Point,
) -> svg_path.Point {
  case points {
    [] -> best
    [first, ..rest] -> {
      let best = case
        point.distance_squared(first, origin)
        >. point.distance_squared(best, origin)
      {
        True -> first
        False -> best
      }
      farthest_point(rest, origin, best)
    }
  }
}

fn line_list_points(
  lines: List(svg_path.Segment),
  points: List(svg_path.Point),
) -> List(svg_path.Point) {
  case lines {
    [] -> list.reverse(points)
    [svg_path.Line(start:, end:), ..rest] ->
      line_list_points(rest, [end, start, ..points])
    [_first, ..rest] -> line_list_points(rest, points)
  }
}

fn remove_zero_length_lines(
  lines: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  list.filter(lines, fn(segment) {
    svg_path.segment_start(segment) != svg_path.segment_end(segment)
  })
}

fn line_pieces_at_breaks(
  segment: svg_path.Segment,
  breaks: List(Float),
  lines: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), Error) {
  case breaks {
    [] | [_] -> Ok(list.reverse(lines))
    [from, to, ..rest] -> {
      use start <- result.try(
        svg_path.segment_point(segment, at: from) |> result.map_error(PathError),
      )
      use end <- result.try(
        svg_path.segment_point(segment, at: to) |> result.map_error(PathError),
      )
      line_pieces_at_breaks(segment, [to, ..rest], [
        svg_path.Line(start:, end:),
        ..lines
      ])
    }
  }
}

fn quadratic_degenerate_breaks(
  start: svg_path.Point,
  control: svg_path.Point,
  end: svg_path.Point,
  axis_start: svg_path.Point,
) -> List(Float) {
  let axis =
    point.subtract(
      farthest_point([start, control, end], axis_start, axis_start),
      axis_start,
    )
  let s = axis_coordinate(start, axis_start, axis)
  let c = axis_coordinate(control, axis_start, axis)
  let e = axis_coordinate(end, axis_start, axis)
  let denominator = s -. { 2.0 *. c } +. e
  case number.is_zero(denominator) {
    True -> []
    False -> {
      let root = { s -. c } /. denominator
      root.strictly_inside([root], from: 0.0, to: 1.0)
    }
  }
}

fn cubic_degenerate_breaks(
  start: svg_path.Point,
  control1: svg_path.Point,
  control2: svg_path.Point,
  end: svg_path.Point,
  axis_start: svg_path.Point,
) -> List(Float) {
  let axis =
    point.subtract(
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

fn axis_coordinate(
  point: svg_path.Point,
  origin: svg_path.Point,
  axis: svg_path.Point,
) -> Float {
  let relative = point.subtract(point, origin)
  let denominator = point.distance_squared(axis, svg_path.Point(0.0, 0.0))
  case denominator == 0.0 {
    True -> 0.0
    False -> point.dot(relative, axis) /. denominator
  }
}

fn sqrt(value: Float) -> Float {
  let assert Ok(root) = float.square_root(value)
  root
}
