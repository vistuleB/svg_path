import gleam/result
import svg_path
import svg_path/csg
import svg_path/distance
import svg_path/fit
import svg_path/measure
import svg_path/offset
import svg_path/stroke

// Fit a curve on 0..1, then retain its middle half by traveled distance.
pub fn middle_half(
  point: fn(Float) -> svg_path.Point,
) -> Result(svg_path.Subpath, svg_path.Error) {
  use curve <- result.try(fit.subpath_from_parametric(
    from: 0.0,
    to: 1.0,
    point:,
  ))
  use length <- result.try(measure.subpath_length(curve))
  measure.subpath_between_lengths(
    curve,
    from: length *. 0.25,
    to: length *. 0.75,
  )
}

// Recover a nearest address and the derivative at that address.
// The derivative is not a unit tangent and can be zero at a singularity.
pub fn nearest_location(
  point: svg_path.Point,
  path: svg_path.Path,
) -> Result(#(svg_path.PathProjection, svg_path.Point), svg_path.Error) {
  use projection <- result.try(distance.path_projection(point, to: path))
  use derivative <- result.try(svg_path.path_derivative(path, at: projection.at))
  Ok(#(projection, derivative))
}

// Keep the original diagnostic when composing operations with different errors.
pub type OutlineUnionError {
  StrokeFailure(error: stroke.Error)
  BooleanFailure(error: csg.Error)
}

// Turn centerlines into a filled outline, then combine it with another fill.
pub fn outline_union(
  centerlines: svg_path.Path,
  width: Float,
  filled_region: svg_path.Path,
) -> Result(svg_path.Path, OutlineUnionError) {
  use outline <- result.try(
    stroke.path(centerlines, width:, join: offset.Round, cap: offset.Butt)
    |> result.map_error(StrokeFailure),
  )
  csg.union_path(outline, filled_region, using: svg_path.Nonzero)
  |> result.map_error(BooleanFailure)
}
