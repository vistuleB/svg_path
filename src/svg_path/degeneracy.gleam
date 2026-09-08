//// Degenerate and nearly-degenerate geometry cleanup.

import gleam/float
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import svg_path
import svg_path/convex_hull
import svg_path/internal/number
import svg_path/point

type LineWindow {
  LineWindow(
    replacement: List(svg_path.Segment),
    remaining: List(svg_path.Segment),
  )
}

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
/// Each selected window is replaced by its ordered line traversal. Windows are
/// considered from left to right. Their exact curve-preserving convex hull is
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
          svg_path.subpath_set_closed_with(
            open,
            closed: True,
            policy: svg_path.Strict,
          )
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
      case leading_line_window([first, ..rest], tolerance) {
        Some(LineWindow(replacement:, remaining:)) -> {
          colinearize_segments(
            remaining,
            tolerance,
            converted: list.append(list.reverse(replacement), converted),
          )
        }
        None -> {
          use pending <- result.try(
            svg_path.subpath([first, ..rest]) |> result.map_error(PathError),
          )
          use prefix <- result.try(longest_thin_prefix(pending, tolerance:))
          case prefix.segments {
            [_, _, ..] -> {
              use lines <- result.try(degenerate_window_traversal(
                prefix,
                tolerance,
              ))
              colinearize_segments(
                prefix.remaining,
                tolerance,
                converted: list.append(list.reverse(lines), converted),
              )
            }
            _ -> {
              use replacement <- result.try(
                svg_path.segment_degenerate_lines(first, tolerance)
                |> result.map_error(PathError),
              )
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
  }
}

fn leading_line_window(
  segments: List(svg_path.Segment),
  tolerance: Float,
) -> Option(LineWindow) {
  case segments {
    [svg_path.Line(start:, end:), ..rest] -> {
      case point.normalize(point.subtract(end, start)) {
        Error(_) -> None
        Ok(axis) -> {
          let normal = svg_path.Point(0.0 -. axis.y, axis.x)
          let start_support = point.dot(start, normal)
          let end_support = point.dot(end, normal)
          let lower = float.min(start_support, end_support)
          let upper = float.max(start_support, end_support)
          let endpoints = [end, start]
          leading_line_window_loop(
            rest,
            tolerance,
            axis,
            normal,
            lower,
            upper,
            accepted_count: 1,
            endpoints:,
          )
        }
      }
    }
    _ -> None
  }
}

fn leading_line_window_loop(
  remaining: List(svg_path.Segment),
  tolerance: Float,
  axis: svg_path.Point,
  normal: svg_path.Point,
  lower: Float,
  upper: Float,
  accepted_count accepted_count: Int,
  endpoints endpoints: List(svg_path.Point),
) -> Option(LineWindow) {
  case remaining {
    [svg_path.Line(end:, ..), ..rest] -> {
      let support = point.dot(end, normal)
      let candidate_lower = float.min(lower, support)
      let candidate_upper = float.max(upper, support)
      case candidate_upper -. candidate_lower <=. tolerance {
        True ->
          leading_line_window_loop(
            rest,
            tolerance,
            axis,
            normal,
            candidate_lower,
            candidate_upper,
            accepted_count: accepted_count + 1,
            endpoints: [end, ..endpoints],
          )
        False -> line_window_result(accepted_count, endpoints, axis, remaining)
      }
    }
    _ -> line_window_result(accepted_count, endpoints, axis, remaining)
  }
}

fn line_window_result(
  accepted_count: Int,
  reversed_endpoints: List(svg_path.Point),
  axis: svg_path.Point,
  remaining: List(svg_path.Segment),
) -> Option(LineWindow) {
  case accepted_count >= 2 {
    False -> None
    True -> {
      let endpoints = list.reverse(reversed_endpoints)
      let replacement =
        endpoints
        |> axial_protrusion_points(axis)
        |> point_traversal_lines(0.0)
      Some(LineWindow(replacement:, remaining:))
    }
  }
}

fn axial_protrusion_points(
  ordered_points: List(svg_path.Point),
  axis: svg_path.Point,
) -> List(svg_path.Point) {
  case unique_adjacent_points(ordered_points, 0.0) {
    [] | [_] -> ordered_points
    [first, second, ..rest] ->
      axial_protrusion_points_loop(
        previous: first,
        current: second,
        rest:,
        axis:,
        reversed_kept: [first],
      )
  }
}

fn axial_protrusion_points_loop(
  previous previous: svg_path.Point,
  current current: svg_path.Point,
  rest rest: List(svg_path.Point),
  axis axis: svg_path.Point,
  reversed_kept reversed_kept: List(svg_path.Point),
) -> List(svg_path.Point) {
  case rest {
    [] -> list.reverse([current, ..reversed_kept])
    [next, ..tail] -> {
      let previous_delta = point.dot(current, axis) -. point.dot(previous, axis)
      let next_delta = point.dot(next, axis) -. point.dot(current, axis)
      let reversed_kept = case previous_delta *. next_delta <. 0.0 {
        True -> [current, ..reversed_kept]
        False -> reversed_kept
      }
      axial_protrusion_points_loop(
        previous: current,
        current: next,
        rest: tail,
        axis:,
        reversed_kept:,
      )
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
        convex_hull.segment_hull(first) |> result.map_error(ConvexHullError),
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
    convex_hull.subpath_hull(subpath) |> result.map_error(ConvexHullError),
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
  let axis = point.rotate_clockwise(strip.normal)
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

fn unique_adjacent_points(
  points: List(svg_path.Point),
  tolerance: Float,
) -> List(svg_path.Point) {
  case points {
    [] -> []
    [first, ..rest] ->
      unique_adjacent_points_loop(rest, tolerance, previous: first, kept: [
        first,
      ])
      |> list.reverse
  }
}

fn unique_adjacent_points_loop(
  points: List(svg_path.Point),
  tolerance: Float,
  previous previous: svg_path.Point,
  kept kept: List(svg_path.Point),
) -> List(svg_path.Point) {
  case points {
    [] -> kept
    [first, ..rest] ->
      case point.distance(previous, first) <=. tolerance {
        True -> unique_adjacent_points_loop(rest, tolerance, previous:, kept:)
        False ->
          unique_adjacent_points_loop(rest, tolerance, previous: first, kept: [
            first,
            ..kept
          ])
      }
  }
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
      use replacement <- result.try(
        svg_path.segment_degenerate_lines(first, tolerance)
        |> result.map_error(PathError),
      )
      let replacement = case replacement {
        None -> [first]
        Some(lines) -> lines
      }
      use remaining <- result.try(degenerate_traversal(rest, tolerance))
      Ok(list.append(replacement, remaining))
    }
  }
}
