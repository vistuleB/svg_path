//// Explicit finite encounters between path segments.
////
//// This module supplements `intersections`: a coincident span is returned as
//// an `Overlap` encounter instead of being surfaced as `OverlappingSegments`.

import gleam/float
import gleam/list
import svg_path
import svg_path/intersections

pub type SegmentEncounter {
  Intersection(left_t: Float, right_t: Float, point: svg_path.Point)
  Overlap(
    left_from: Float,
    left_to: Float,
    right_from: Float,
    right_to: Float,
    start: svg_path.Point,
    end: svg_path.Point,
  )
}

pub fn segment(
  left: svg_path.Segment,
  right: svg_path.Segment,
) -> Result(List(SegmentEncounter), svg_path.Error) {
  segment_with(left, right, options: intersections.default_options())
}

pub fn segment_with(
  left: svg_path.Segment,
  right: svg_path.Segment,
  options options: intersections.IntersectionOptions,
) -> Result(List(SegmentEncounter), svg_path.Error) {
  case intersections.segment_with(left, right, options:) {
    Ok(found) ->
      found
      |> list.map(fn(hit) {
        let svg_path.SegmentIntersection(left_t:, right_t:, point:) = hit
        Intersection(left_t:, right_t:, point:)
      })
      |> Ok
    Error(svg_path.OverlappingSegments) ->
      line_overlap(left, right, options.tolerance)
    Error(error) -> Error(error)
  }
}

fn line_overlap(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
) -> Result(List(SegmentEncounter), svg_path.Error) {
  case left, right {
    svg_path.Line(start: left_start, end: left_end),
      svg_path.Line(start: right_start, end: right_end)
    -> {
      let left_dx = left_end.x -. left_start.x
      let left_dy = left_end.y -. left_start.y
      let right_dx = right_end.x -. right_start.x
      let right_dy = right_end.y -. right_start.y
      case
        near_zero(left_dx *. left_dx +. left_dy *. left_dy, tolerance)
        || near_zero(right_dx *. right_dx +. right_dy *. right_dy, tolerance)
      {
        True -> Ok([])
        False -> {
          let right_start_t =
            line_parameter(left_start, left_dx, left_dy, right_start)
          let right_end_t =
            line_parameter(left_start, left_dx, left_dy, right_end)
          let left_from = max_float(0.0, min_float(right_start_t, right_end_t))
          let left_to = min_float(1.0, max_float(right_start_t, right_end_t))
          case left_to -. left_from <=. tolerance {
            True -> Ok([])
            False -> {
              let assert Ok(start) = svg_path.segment_point(left, at: left_from)
              let assert Ok(end) = svg_path.segment_point(left, at: left_to)
              Ok([
                Overlap(
                  left_from:,
                  left_to:,
                  right_from: line_parameter(
                    right_start,
                    right_dx,
                    right_dy,
                    start,
                  ),
                  right_to: line_parameter(right_start, right_dx, right_dy, end),
                  start:,
                  end:,
                ),
              ])
            }
          }
        }
      }
    }
    _, _ -> Ok([])
  }
}

fn line_parameter(
  start: svg_path.Point,
  dx: Float,
  dy: Float,
  point: svg_path.Point,
) -> Float {
  case float.absolute_value(dx) >=. float.absolute_value(dy) {
    True -> { point.x -. start.x } /. dx
    False -> { point.y -. start.y } /. dy
  }
}

fn near_zero(value: Float, tolerance: Float) -> Bool {
  float.absolute_value(value) <=. tolerance *. tolerance
}

fn min_float(a: Float, b: Float) -> Float {
  case a <=. b {
    True -> a
    False -> b
  }
}

fn max_float(a: Float, b: Float) -> Float {
  case a >=. b {
    True -> a
    False -> b
  }
}
