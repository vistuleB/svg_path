//// Winding-field sampling shared by arrangement operations.

import gleam/float
import gleam/option.{type Option, None, Some}
import gleam/result
import svg_path

/// Return the signed Nonzero winding level at a point. Boundary samples fall
/// back to filled/not-filled because a signed winding is undefined there.
@internal
pub fn nonzero_level_at(
  point: svg_path.Point,
  within path: svg_path.Path,
  options options: svg_path.ContainmentOptions,
) -> Result(Int, svg_path.Error) {
  use winding <- result.try(svg_path.path_winding_with(
    point,
    within: path,
    options:,
  ))
  case winding {
    svg_path.Winding(value) -> Ok(value)
    svg_path.BoundaryWinding -> {
      use containment <- result.try(svg_path.path_containment_with(
        point,
        within: path,
        using: svg_path.Nonzero,
        options:,
      ))
      Ok(case containment {
        svg_path.Inside | svg_path.Boundary -> 1
        svg_path.Outside -> 0
      })
    }
  }
}

/// Sample the Nonzero winding field immediately on the geometric left and
/// right of a segment. `side_sampling_distance` is the geometric distance from
/// the segment midpoint to each sample. The first result is the left-side level.
@internal
pub fn segment_side_nonzero_levels(
  segment: svg_path.Segment,
  within path: svg_path.Path,
  side_sampling_distance side_sampling_distance: Float,
  options options: svg_path.ContainmentOptions,
) -> Result(#(Int, Int), svg_path.Error) {
  use _ <- result.try(validate_sampling_distance(side_sampling_distance))
  use midpoint <- result.try(sample_segment_sides(
    segment,
    at: 0.5,
    within: path,
    side_sampling_distance:,
    options:,
  ))
  case midpoint {
    Some(levels) -> Ok(levels)
    None ->
      sample_symmetric_fallbacks(
        segment,
        within: path,
        parameter_pairs: [#(0.25, 0.75), #(0.125, 0.875), #(0.375, 0.625)],
        side_sampling_distance:,
        options:,
      )
  }
}

fn sample_segment_sides(
  segment: svg_path.Segment,
  at t: Float,
  within path: svg_path.Path,
  side_sampling_distance side_sampling_distance: Float,
  options options: svg_path.ContainmentOptions,
) -> Result(Option(#(Int, Int)), svg_path.Error) {
  use sample <- result.try(svg_path.segment_point(segment, at: t))
  use derivative <- result.try(svg_path.segment_derivative(segment, at: t))
  let length_squared =
    derivative.x *. derivative.x +. derivative.y *. derivative.y
  case length_squared >. 0.0 && length_squared -. length_squared == 0.0 {
    False -> Ok(None)
    True -> {
      let assert Ok(length) = float.square_root(length_squared)
      let normal =
        svg_path.Point(
          derivative.y /. length *. side_sampling_distance,
          { 0.0 -. derivative.x } /. length *. side_sampling_distance,
        )
      let left = svg_path.Point(sample.x +. normal.x, sample.y +. normal.y)
      let right = svg_path.Point(sample.x -. normal.x, sample.y -. normal.y)
      use left_level <- result.try(nonzero_level_at(
        left,
        within: path,
        options:,
      ))
      use right_level <- result.try(nonzero_level_at(
        right,
        within: path,
        options:,
      ))
      Ok(Some(#(left_level, right_level)))
    }
  }
}

fn sample_symmetric_fallbacks(
  segment: svg_path.Segment,
  within path: svg_path.Path,
  parameter_pairs parameter_pairs: List(#(Float, Float)),
  side_sampling_distance side_sampling_distance: Float,
  options options: svg_path.ContainmentOptions,
) -> Result(#(Int, Int), svg_path.Error) {
  case parameter_pairs {
    [] -> Error(svg_path.IndeterminateWindingSideLevels)
    [#(before, after), ..rest] -> {
      use before_levels <- result.try(sample_segment_sides(
        segment,
        at: before,
        within: path,
        side_sampling_distance:,
        options:,
      ))
      use after_levels <- result.try(sample_segment_sides(
        segment,
        at: after,
        within: path,
        side_sampling_distance:,
        options:,
      ))
      case before_levels, after_levels {
        Some(before_levels), Some(after_levels) ->
          case before_levels == after_levels {
            True -> Ok(before_levels)
            False -> Error(svg_path.InconsistentWindingSideLevels)
          }
        _, _ ->
          sample_symmetric_fallbacks(
            segment,
            within: path,
            parameter_pairs: rest,
            side_sampling_distance:,
            options:,
          )
      }
    }
  }
}

fn validate_sampling_distance(distance: Float) -> Result(Nil, svg_path.Error) {
  case distance <=. 0.0 || distance -. distance != 0.0 {
    True -> Error(svg_path.InvalidContainmentTolerance(distance))
    False -> Ok(Nil)
  }
}
