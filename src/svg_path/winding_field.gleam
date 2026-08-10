//// Winding-field sampling shared by arrangement operations.

import gleam/float
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
  use midpoint <- result.try(svg_path.segment_point(segment, at: 0.5))
  use derivative <- result.try(svg_path.segment_derivative(segment, at: 0.5))
  let length_squared =
    derivative.x *. derivative.x +. derivative.y *. derivative.y
  case length_squared <=. 0.0 {
    True -> Ok(#(0, 0))
    False -> {
      let assert Ok(length) = float.square_root(length_squared)
      let normal =
        svg_path.Point(
          { 0.0 -. derivative.y } /. length *. side_sampling_distance,
          derivative.x /. length *. side_sampling_distance,
        )
      let left = svg_path.Point(midpoint.x +. normal.x, midpoint.y +. normal.y)
      let right = svg_path.Point(midpoint.x -. normal.x, midpoint.y -. normal.y)
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
      Ok(#(left_level, right_level))
    }
  }
}

fn validate_sampling_distance(distance: Float) -> Result(Nil, svg_path.Error) {
  case distance <=. 0.0 || distance -. distance != 0.0 {
    True -> Error(svg_path.InvalidContainmentTolerance(distance))
    False -> Ok(Nil)
  }
}
