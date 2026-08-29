//// Experimental window-preserving curve intersection search.
////
//// Unlike `svg_path/intersections`, this module treats parameter rectangles as
//// the search state. It discards a rectangle only when exact curve-piece
//// bounds separate, and uses chord crossing as positive evidence for a
//// transverse root. The implementation is intentionally separate while its
//// contracts and tangency behavior are evaluated.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import svg_path
import svg_path/ellipse
import svg_path/trig

const default_tolerance = 0.000000001

const maximum_windows = 1000

pub type Window {
  Window(left_from: Float, left_to: Float, right_from: Float, right_to: Float)
}

type SearchState {
  SearchState(
    pending: List(#(Window, Int)),
    intersections: List(svg_path.SegmentIntersection),
    examined: Int,
  )
}

/// Find intersections while preserving parameter windows.
///
/// Transverse roots are seeded by chord crossings and refined by tangent-line
/// Newton steps. Nontransverse contacts remain discoverable through exact
/// curve-piece bounding-box subdivision and coincident terminal samples.
pub fn segment(
  left: svg_path.Segment,
  right: svg_path.Segment,
) -> Result(List(svg_path.SegmentIntersection), svg_path.Error) {
  segment_with(left, right, tolerance: default_tolerance, max_depth: 48)
}

/// Find intersections with explicit geometric tolerance and subdivision depth.
pub fn segment_with(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance tolerance: Float,
  max_depth max_depth: Int,
) -> Result(List(svg_path.SegmentIntersection), svg_path.Error) {
  case left, right {
    svg_path.Arc(radius: left_radius, ..),
      svg_path.Arc(radius: right_radius, ..)
    ->
      case circular_radius(left_radius) && circular_radius(right_radius) {
        True -> circular_arc_intersections(left, right, tolerance)
        False -> windowed_intersections(left, right, tolerance, max_depth)
      }
    _, _ -> windowed_intersections(left, right, tolerance, max_depth)
  }
}

fn windowed_intersections(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
  max_depth: Int,
) -> Result(List(svg_path.SegmentIntersection), svg_path.Error) {
  case certified_disjoint_translation(left, right) {
    True -> Ok([])
    False -> windowed_intersections_unchecked(left, right, tolerance, max_depth)
  }
}

fn windowed_intersections_unchecked(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
  max_depth: Int,
) -> Result(List(svg_path.SegmentIntersection), svg_path.Error) {
  use endpoints <- result.try(endpoint_candidates(left, right, tolerance))
  use crossings <- result.try(sampled_crossing_candidates(
    left,
    right,
    tolerance,
  ))
  search(
    left,
    right,
    tolerance,
    SearchState(
      pending: initial_windows(count: 8, depth: max_depth),
      intersections: list.fold(crossings, endpoints, insert_intersection),
      examined: 0,
    ),
  )
}

// Two identically parameterized Beziers separated by a constant translation
// cannot meet when their projection perpendicular to that translation is
// strictly monotone. The derivative-control projections certify monotonicity;
// this avoids an unbounded strip of overlapping axis-aligned search boxes for
// close parallel curves.
fn certified_disjoint_translation(
  left: svg_path.Segment,
  right: svg_path.Segment,
) -> Bool {
  case bezier_points(left), bezier_points(right) {
    Some(left_points), Some(right_points) ->
      case left_points, right_points {
        [left_start, ..], [right_start, ..] -> {
          let dx = right_start.x -. left_start.x
          let dy = right_start.y -. left_start.y
          let translation_squared = dx *. dx +. dy *. dy
          translation_squared >. 0.000000000000000000000000000001
          && translated_points_match(left_points, right_points, dx, dy)
          && strictly_monotone_projection(left_points, 0.0 -. dy, dx)
        }
        _, _ -> False
      }
    _, _ -> False
  }
}

fn bezier_points(segment: svg_path.Segment) -> Option(List(svg_path.Point)) {
  case segment {
    svg_path.Line(start:, end:) -> Some([start, end])
    svg_path.QuadraticBezier(start:, control:, end:) ->
      Some([start, control, end])
    svg_path.CubicBezier(start:, control1:, control2:, end:) ->
      Some([start, control1, control2, end])
    svg_path.Arc(..) -> None
  }
}

fn translated_points_match(
  left: List(svg_path.Point),
  right: List(svg_path.Point),
  dx: Float,
  dy: Float,
) -> Bool {
  case left, right {
    [], [] -> True
    [left_point, ..left_rest], [right_point, ..right_rest] ->
      float.absolute_value(right_point.x -. left_point.x -. dx)
      <=. 0.00000000000001
      && float.absolute_value(right_point.y -. left_point.y -. dy)
      <=. 0.00000000000001
      && translated_points_match(left_rest, right_rest, dx, dy)
    _, _ -> False
  }
}

fn strictly_monotone_projection(
  points: List(svg_path.Point),
  axis_x: Float,
  axis_y: Float,
) -> Bool {
  let projections = consecutive_projection_differences(points, axis_x, axis_y)
  list.all(projections, fn(value) { value >. 0.000000000000001 })
  || list.all(projections, fn(value) { value <. -0.000000000000001 })
}

fn consecutive_projection_differences(
  points: List(svg_path.Point),
  axis_x: Float,
  axis_y: Float,
) -> List(Float) {
  case points {
    [first, second, ..rest] -> [
      { second.x -. first.x } *. axis_x +. { second.y -. first.y } *. axis_y,
      ..consecutive_projection_differences([second, ..rest], axis_x, axis_y)
    ]
    _ -> []
  }
}

fn circular_radius(radius: svg_path.Point) -> Bool {
  float.absolute_value(
    float.absolute_value(radius.x) -. float.absolute_value(radius.y),
  )
  <=. 0.000000000001
}

fn circular_arc_intersections(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
) -> Result(List(svg_path.SegmentIntersection), svg_path.Error) {
  let assert svg_path.Arc(
    start: left_start,
    radius: left_radius,
    x_axis_rotation: left_rotation,
    large_arc: left_large,
    sweep: left_sweep,
    end: left_end,
  ) = left
  let assert svg_path.Arc(
    start: right_start,
    radius: right_radius,
    x_axis_rotation: right_rotation,
    large_arc: right_large,
    sweep: right_sweep,
    end: right_end,
  ) = right
  use left_arc <- result.try(
    ellipse.endpoint_to_center(ellipse.EndpointArcData(
      start: ellipse.EllipsePoint(left_start.x, left_start.y),
      radius: ellipse.EllipsePoint(left_radius.x, left_radius.y),
      x_axis_rotation: left_rotation,
      large_arc: left_large,
      sweep: left_sweep,
      end: ellipse.EllipsePoint(left_end.x, left_end.y),
    ))
    |> result.map_error(fn(_) { svg_path.DegenerateArc }),
  )
  use right_arc <- result.try(
    ellipse.endpoint_to_center(ellipse.EndpointArcData(
      start: ellipse.EllipsePoint(right_start.x, right_start.y),
      radius: ellipse.EllipsePoint(right_radius.x, right_radius.y),
      x_axis_rotation: right_rotation,
      large_arc: right_large,
      sweep: right_sweep,
      end: ellipse.EllipsePoint(right_end.x, right_end.y),
    ))
    |> result.map_error(fn(_) { svg_path.DegenerateArc }),
  )
  let ellipse.CenterArcData(
    center: left_center,
    radius: ellipse.EllipsePoint(x: left_r, ..),
    start_angle: left_angle,
    delta_angle: left_delta,
    ..,
  ) = left_arc
  let ellipse.CenterArcData(
    center: right_center,
    radius: ellipse.EllipsePoint(x: right_r, ..),
    start_angle: right_angle,
    delta_angle: right_delta,
    ..,
  ) = right_arc
  let dx = right_center.x -. left_center.x
  let dy = right_center.y -. left_center.y
  let distance_squared = dx *. dx +. dy *. dy
  let assert Ok(distance) = float.square_root(distance_squared)
  let radius_difference = float.absolute_value(left_r -. right_r)
  case distance <=. 0.000000000000001 {
    // The production caller has already classified true overlaps. Distinct
    // arcs on the same circle can otherwise meet only at their endpoints.
    True -> endpoint_candidates(left, right, tolerance)
    False if distance >. left_r +. right_r +. tolerance -> Ok([])
    False if distance <. radius_difference -. tolerance -> Ok([])
    False -> {
      let along =
        { left_r *. left_r -. right_r *. right_r +. distance_squared }
        /. { 2.0 *. distance }
      let height_squared = left_r *. left_r -. along *. along
      case height_squared <. 0.0 -. tolerance {
        True -> Ok([])
        False -> {
          let height = case height_squared <=. 0.0 {
            True -> 0.0
            False -> {
              let assert Ok(value) = float.square_root(height_squared)
              value
            }
          }
          let base_x = left_center.x +. along *. dx /. distance
          let base_y = left_center.y +. along *. dy /. distance
          let offset_x = 0.0 -. dy *. height /. distance
          let offset_y = dx *. height /. distance
          let candidates = case height <=. tolerance {
            True -> [svg_path.Point(base_x, base_y)]
            False -> [
              svg_path.Point(base_x +. offset_x, base_y +. offset_y),
              svg_path.Point(base_x -. offset_x, base_y -. offset_y),
            ]
          }
          Ok(
            list.fold(candidates, [], fn(found, point) {
              case
                circular_arc_parameter(
                  point,
                  left_center,
                  left_angle,
                  left_delta,
                ),
                circular_arc_parameter(
                  point,
                  right_center,
                  right_angle,
                  right_delta,
                )
              {
                Some(left_t), Some(right_t) ->
                  insert_intersection(
                    found,
                    svg_path.SegmentIntersection(left_t:, right_t:, point:),
                  )
                _, _ -> found
              }
            }),
          )
        }
      }
    }
  }
}

fn circular_arc_parameter(
  point: svg_path.Point,
  center: ellipse.EllipsePoint,
  start_angle: Float,
  delta_angle: Float,
) -> Option(Float) {
  let angle = trig.atan2_degrees(point.y -. center.y, point.x -. center.x)
  let progress = case delta_angle >=. 0.0 {
    True -> positive_angle_remainder(angle -. start_angle) /. delta_angle
    False ->
      positive_angle_remainder(start_angle -. angle) /. { 0.0 -. delta_angle }
  }
  case progress >=. -0.000000001 && progress <=. 1.000000001 {
    True -> Some(clamp01(progress))
    False -> None
  }
}

fn positive_angle_remainder(angle: Float) -> Float {
  let turns = float.floor(angle /. 360.0)
  angle -. turns *. 360.0
}

fn initial_windows(count count: Int, depth depth: Int) -> List(#(Window, Int)) {
  let intervals = parameter_intervals(0, count:, accumulated: [])
  list.fold(intervals, [], fn(windows, left_interval) {
    let #(left_from, left_to) = left_interval
    list.fold(intervals, windows, fn(windows, right_interval) {
      let #(right_from, right_to) = right_interval
      [#(Window(left_from, left_to, right_from, right_to), depth), ..windows]
    })
  })
}

fn sampled_crossing_candidates(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
) -> Result(List(svg_path.SegmentIntersection), svg_path.Error) {
  let intervals = parameter_intervals(0, count: 16, accumulated: [])
  use candidates <- result.try(
    list.try_fold(intervals, [], fn(candidates, left_interval) {
      list.try_fold(intervals, candidates, fn(candidates, right_interval) {
        sampled_crossing_candidate(
          left,
          right,
          left_interval,
          right_interval,
          tolerance,
          candidates,
        )
      })
    }),
  )
  Ok(candidates)
}

fn parameter_intervals(
  index: Int,
  count count: Int,
  accumulated accumulated: List(#(Float, Float)),
) -> List(#(Float, Float)) {
  case index >= count {
    True -> list.reverse(accumulated)
    False -> {
      let from = int.to_float(index) /. int.to_float(count)
      let to = int.to_float(index + 1) /. int.to_float(count)
      parameter_intervals(index + 1, count:, accumulated: [
        #(from, to),
        ..accumulated
      ])
    }
  }
}

fn sampled_crossing_candidate(
  left: svg_path.Segment,
  right: svg_path.Segment,
  left_interval: #(Float, Float),
  right_interval: #(Float, Float),
  tolerance: Float,
  candidates: List(svg_path.SegmentIntersection),
) -> Result(List(svg_path.SegmentIntersection), svg_path.Error) {
  let #(left_from, left_to) = left_interval
  let #(right_from, right_to) = right_interval
  use left_start <- result.try(svg_path.segment_point(left, at: left_from))
  use left_end <- result.try(svg_path.segment_point(left, at: left_to))
  use right_start <- result.try(svg_path.segment_point(right, at: right_from))
  use right_end <- result.try(svg_path.segment_point(right, at: right_to))
  case chord_crossing(left_start, left_end, right_start, right_end) {
    None -> Ok(candidates)
    Some(#(left_local, right_local)) -> {
      let left_t = interpolate(left_from, left_to, left_local)
      let right_t = interpolate(right_from, right_to, right_local)
      use candidate <- result.try(refine_tangent_crossing(
        left,
        right,
        left_t,
        right_t,
        tolerance,
        remaining: 20,
      ))
      case candidate {
        None -> Ok(candidates)
        Some(candidate) -> Ok(insert_intersection(candidates, candidate))
      }
    }
  }
}

fn refine_tangent_crossing(
  left: svg_path.Segment,
  right: svg_path.Segment,
  left_t: Float,
  right_t: Float,
  tolerance: Float,
  remaining remaining: Int,
) -> Result(Option(svg_path.SegmentIntersection), svg_path.Error) {
  use left_point <- result.try(svg_path.segment_point(left, at: left_t))
  use right_point <- result.try(svg_path.segment_point(right, at: right_t))
  case point_distance(left_point, right_point) <=. tolerance {
    True ->
      Ok(
        Some(svg_path.SegmentIntersection(
          left_t:,
          right_t:,
          point: midpoint(left_point, right_point),
        )),
      )
    False if remaining <= 0 -> Ok(None)
    False -> {
      use left_direction <- result.try(svg_path.segment_derivative(
        left,
        at: left_t,
      ))
      use right_direction <- result.try(svg_path.segment_derivative(
        right,
        at: right_t,
      ))
      let denominator =
        cross(
          left_direction.x,
          left_direction.y,
          right_direction.x,
          right_direction.y,
        )
      case float.absolute_value(denominator) <=. 0.000000000000000001 {
        True -> Ok(None)
        False -> {
          let dx = right_point.x -. left_point.x
          let dy = right_point.y -. left_point.y
          let left_step =
            cross(dx, dy, right_direction.x, right_direction.y) /. denominator
          let right_step =
            0.0
            -. cross(left_direction.x, left_direction.y, dx, dy)
            /. denominator
          let next_left = left_t +. left_step
          let next_right = right_t +. right_step
          case inside01(next_left) && inside01(next_right) {
            False -> Ok(None)
            True ->
              refine_tangent_crossing(
                left,
                right,
                clamp01(next_left),
                clamp01(next_right),
                tolerance,
                remaining: remaining - 1,
              )
          }
        }
      }
    }
  }
}

fn search(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
  state: SearchState,
) -> Result(List(svg_path.SegmentIntersection), svg_path.Error) {
  let SearchState(pending:, intersections:, examined:) = state
  case pending {
    [] -> Ok(list.reverse(intersections))
    [#(window, depth), ..rest] -> {
      case window_already_resolved(window, intersections) {
        True ->
          search(
            left,
            right,
            tolerance,
            SearchState(pending: rest, intersections:, examined:),
          )
        False ->
          case examined >= maximum_windows {
            True ->
              Error(svg_path.IntersectionTerminalWindowLimitExceeded(
                maximum_windows,
              ))
            False -> {
              use decision <- result.try(inspect_window(
                left,
                right,
                window,
                tolerance,
              ))
              case decision {
                Disjoint ->
                  search(
                    left,
                    right,
                    tolerance,
                    SearchState(
                      pending: rest,
                      intersections:,
                      examined: examined + 1,
                    ),
                  )
                Candidate(candidate) -> {
                  let intersections =
                    insert_intersection(intersections, candidate)
                  search(
                    left,
                    right,
                    tolerance,
                    SearchState(
                      pending: rest,
                      intersections:,
                      examined: examined + 1,
                    ),
                  )
                }
                Refine -> {
                  case depth <= 0 {
                    True ->
                      search(
                        left,
                        right,
                        tolerance,
                        SearchState(
                          pending: rest,
                          intersections:,
                          examined: examined + 1,
                        ),
                      )
                    False -> {
                      let children = split_window_nine(window)
                      let pending =
                        list.fold(children, rest, fn(pending, child) {
                          [#(child, depth - 1), ..pending]
                        })
                      search(
                        left,
                        right,
                        tolerance,
                        SearchState(
                          pending:,
                          intersections:,
                          examined: examined + 1,
                        ),
                      )
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

fn window_already_resolved(
  window: Window,
  intersections: List(svg_path.SegmentIntersection),
) -> Bool {
  let Window(left_from:, left_to:, right_from:, right_to:) = window
  let left_width = left_to -. left_from
  let right_width = right_to -. right_from
  left_width <=. 0.125
  && right_width <=. 0.125
  && list.any(intersections, fn(intersection) {
    parameter_near_interval(
      intersection.left_t,
      left_from,
      left_to,
      left_width *. 2.0,
    )
    && parameter_near_interval(
      intersection.right_t,
      right_from,
      right_to,
      right_width *. 2.0,
    )
  })
}

fn parameter_near_interval(
  parameter: Float,
  from: Float,
  to: Float,
  margin: Float,
) -> Bool {
  parameter >=. from -. margin && parameter <=. to +. margin
}

type WindowDecision {
  Disjoint
  Candidate(svg_path.SegmentIntersection)
  Refine
}

fn inspect_window(
  left: svg_path.Segment,
  right: svg_path.Segment,
  window: Window,
  tolerance: Float,
) -> Result(WindowDecision, svg_path.Error) {
  let Window(left_from:, left_to:, right_from:, right_to:) = window
  use left_piece <- result.try(svg_path.segment_between(
    left,
    from: left_from,
    to: left_to,
  ))
  use right_piece <- result.try(svg_path.segment_between(
    right,
    from: right_from,
    to: right_to,
  ))
  use left_box <- result.try(svg_path.segment_bounding_box(left_piece))
  use right_box <- result.try(svg_path.segment_bounding_box(right_piece))
  // Bounding boxes are an enclosure test, not a coincidence test. Expanding
  // them by the geometric certification tolerance creates a two-dimensional
  // band of surviving windows around a tangency.
  // Exact extrema formulas still incur floating-point rounding when two boxes
  // merely touch at a tangency. This fixed enclosure slack is independent of
  // the caller's geometric coincidence tolerance.
  case boxes_overlap(left_box, right_box, 0.000000000001) {
    False -> Ok(Disjoint)
    True -> {
      use left_start <- result.try(svg_path.segment_point(left, at: left_from))
      use left_end <- result.try(svg_path.segment_point(left, at: left_to))
      use right_start <- result.try(svg_path.segment_point(
        right,
        at: right_from,
      ))
      use right_end <- result.try(svg_path.segment_point(right, at: right_to))
      let center_left_t = { left_from +. left_to } /. 2.0
      let center_right_t = { right_from +. right_to } /. 2.0
      use center_left <- result.try(svg_path.segment_point(
        left,
        at: center_left_t,
      ))
      use center_right <- result.try(svg_path.segment_point(
        right,
        at: center_right_t,
      ))
      // A center sample is evidence for a nontransverse contact only when it
      // is effectively coincident. The caller's looser geometric tolerance
      // must not turn an arbitrary close approach into a tangency.
      case
        point_distance(center_left, center_right)
        <=. float.min(tolerance, 0.000000000001)
      {
        True ->
          Ok(
            Candidate(svg_path.SegmentIntersection(
              left_t: center_left_t,
              right_t: center_right_t,
              point: midpoint(center_left, center_right),
            )),
          )
        False -> {
          let #(local_left, local_right) = case
            chord_crossing(left_start, left_end, right_start, right_end)
          {
            Some(parameters) -> parameters
            None ->
              chord_closest_parameters(
                left_start,
                left_end,
                right_start,
                right_end,
              )
          }
          let left_t = interpolate(left_from, left_to, local_left)
          let right_t = interpolate(right_from, right_to, local_right)
          use left_point <- result.try(svg_path.segment_point(left, at: left_t))
          use right_point <- result.try(svg_path.segment_point(
            right,
            at: right_t,
          ))
          case point_distance(left_point, right_point) <=. tolerance {
            True ->
              Ok(
                Candidate(svg_path.SegmentIntersection(
                  left_t:,
                  right_t:,
                  point: midpoint(left_point, right_point),
                )),
              )
            False -> Ok(Refine)
          }
        }
      }
    }
  }
}

fn endpoint_candidates(
  left: svg_path.Segment,
  right: svg_path.Segment,
  tolerance: Float,
) -> Result(List(svg_path.SegmentIntersection), svg_path.Error) {
  use left_start <- result.try(svg_path.segment_point(left, at: 0.0))
  use left_end <- result.try(svg_path.segment_point(left, at: 1.0))
  use right_start <- result.try(svg_path.segment_point(right, at: 0.0))
  use right_end <- result.try(svg_path.segment_point(right, at: 1.0))
  Ok(
    [
      #(0.0, 0.0, left_start, right_start),
      #(0.0, 1.0, left_start, right_end),
      #(1.0, 0.0, left_end, right_start),
      #(1.0, 1.0, left_end, right_end),
    ]
    |> list.fold([], fn(candidates, candidate) {
      let #(left_t, right_t, left_point, right_point) = candidate
      case point_distance(left_point, right_point) <=. tolerance {
        False -> candidates
        True -> [
          svg_path.SegmentIntersection(
            left_t:,
            right_t:,
            point: midpoint(left_point, right_point),
          ),
          ..candidates
        ]
      }
    }),
  )
}

fn chord_closest_parameters(
  p: svg_path.Point,
  p2: svg_path.Point,
  q: svg_path.Point,
  q2: svg_path.Point,
) -> #(Float, Float) {
  let ux = p2.x -. p.x
  let uy = p2.y -. p.y
  let vx = q2.x -. q.x
  let vy = q2.y -. q.y
  let wx = p.x -. q.x
  let wy = p.y -. q.y
  let a = dot(ux, uy, ux, uy)
  let b = dot(ux, uy, vx, vy)
  let c = dot(vx, vy, vx, vy)
  let d = dot(ux, uy, wx, wy)
  let e = dot(vx, vy, wx, wy)
  let denominator = a *. c -. b *. b
  let well_conditioned =
    float.absolute_value(denominator) >. 0.000000000000000001
  let left = case a <=. 0.000000000000000001, c <=. 0.000000000000000001 {
    True, _ -> 0.0
    _, True -> clamp01(0.0 -. d /. a)
    False, False if well_conditioned ->
      clamp01({ b *. e -. c *. d } /. denominator)
    _, _ -> clamp01(0.0 -. d /. a)
  }
  let right = case c <=. 0.000000000000000001 {
    True -> 0.0
    False -> clamp01({ b *. left +. e } /. c)
  }
  let left = case a <=. 0.000000000000000001 {
    True -> 0.0
    False -> clamp01({ b *. right -. d } /. a)
  }
  #(left, right)
}

fn midpoint(left: svg_path.Point, right: svg_path.Point) -> svg_path.Point {
  svg_path.Point({ left.x +. right.x } /. 2.0, { left.y +. right.y } /. 2.0)
}

fn dot(ax: Float, ay: Float, bx: Float, by: Float) -> Float {
  ax *. bx +. ay *. by
}

fn chord_crossing(
  p: svg_path.Point,
  p2: svg_path.Point,
  q: svg_path.Point,
  q2: svg_path.Point,
) -> Option(#(Float, Float)) {
  let rx = p2.x -. p.x
  let ry = p2.y -. p.y
  let sx = q2.x -. q.x
  let sy = q2.y -. q.y
  let denominator = cross(rx, ry, sx, sy)
  case float.absolute_value(denominator) <=. 0.000000000000000001 {
    True -> None
    False -> {
      let qpx = q.x -. p.x
      let qpy = q.y -. p.y
      let left_t = cross(qpx, qpy, sx, sy) /. denominator
      let right_t = cross(qpx, qpy, rx, ry) /. denominator
      case inside01(left_t) && inside01(right_t) {
        True -> Some(#(clamp01(left_t), clamp01(right_t)))
        False -> None
      }
    }
  }
}

fn split_window_nine(window: Window) -> List(Window) {
  let Window(left_from:, left_to:, right_from:, right_to:) = window
  let left_a = interpolate(left_from, left_to, 1.0 /. 3.0)
  let left_b = interpolate(left_from, left_to, 2.0 /. 3.0)
  let right_a = interpolate(right_from, right_to, 1.0 /. 3.0)
  let right_b = interpolate(right_from, right_to, 2.0 /. 3.0)
  [
    Window(left_from, left_a, right_from, right_a),
    Window(left_from, left_a, right_a, right_b),
    Window(left_from, left_a, right_b, right_to),
    Window(left_a, left_b, right_from, right_a),
    Window(left_a, left_b, right_a, right_b),
    Window(left_a, left_b, right_b, right_to),
    Window(left_b, left_to, right_from, right_a),
    Window(left_b, left_to, right_a, right_b),
    Window(left_b, left_to, right_b, right_to),
  ]
}

fn insert_intersection(
  intersections: List(svg_path.SegmentIntersection),
  candidate: svg_path.SegmentIntersection,
) -> List(svg_path.SegmentIntersection) {
  case
    list.any(intersections, fn(existing) {
      float.absolute_value(existing.left_t -. candidate.left_t) <=. 0.0000001
      && float.absolute_value(existing.right_t -. candidate.right_t)
      <=. 0.0000001
    })
  {
    True -> intersections
    False -> [candidate, ..intersections]
  }
}

fn boxes_overlap(
  left: svg_path.BoundingBox,
  right: svg_path.BoundingBox,
  tolerance: Float,
) -> Bool {
  !{
    left.max.x +. tolerance <. right.min.x
    || right.max.x +. tolerance <. left.min.x
    || left.max.y +. tolerance <. right.min.y
    || right.max.y +. tolerance <. left.min.y
  }
}

fn point_distance(left: svg_path.Point, right: svg_path.Point) -> Float {
  let dx = left.x -. right.x
  let dy = left.y -. right.y
  let assert Ok(value) = float.square_root(dx *. dx +. dy *. dy)
  value
}

fn interpolate(from: Float, to: Float, t: Float) -> Float {
  from +. { to -. from } *. t
}

fn cross(ax: Float, ay: Float, bx: Float, by: Float) -> Float {
  ax *. by -. ay *. bx
}

fn inside01(value: Float) -> Bool {
  value >=. -0.000000000001 && value <=. 1.000000000001
}

fn clamp01(value: Float) -> Float {
  float.max(0.0, float.min(1.0, value))
}
