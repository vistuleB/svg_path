//// Curve clipping helpers.
////
//// These functions clip path geometry, not filled areas. The clipping region
//// is interpreted as a filled `Path`, but the input geometry is interpreted as
//// curves to keep or discard. Returned subpaths contain only pieces of the
//// original input geometry; no bridge segments from the clipping boundary are
//// inserted.

import gleam/list
import gleam/option.{Some}
import gleam/order
import gleam/result
import svg_path
import svg_path/encounters
import svg_path/intersections
import svg_path/overlaps

const default_tolerance = 0.000001

/// Options for curve clipping.
pub type Options {
  Options(
    /// Options used to locate clipping-boundary intersections.
    intersection: intersections.IntersectionOptions,
    /// Options used to classify pieces against the filled clipping region.
    containment: svg_path.ContainmentOptions,
    /// Path-coordinate tolerance used to deduplicate cut parameters.
    tolerance: Float,
  )
}

/// Return default clipping options.
///
/// Intersection and containment use their module defaults; cut parameters are
/// deduplicated with a `0.000001` path-coordinate tolerance.
pub fn default_options() -> Options {
  Options(
    intersection: intersections.default_options(),
    containment: svg_path.default_containment_options(),
    tolerance: default_tolerance,
  )
}

/// Clip every subpath in `input` to the filled `clip_region`.
///
/// The result keeps only portions of the original input geometry whose sample
/// point is inside or on the boundary of the clipping region. Open inputs may
/// produce zero or more open subpaths. Closed inputs may also produce open
/// subpaths when the clipping boundary cuts them; a closed input remains closed
/// only when it survives whole.
pub fn path(
  input: svg_path.Path,
  to clip_region: svg_path.Path,
  using fill_rule: svg_path.FillRule,
) -> Result(svg_path.Path, svg_path.Error) {
  path_with(
    input,
    to: clip_region,
    using: fill_rule,
    options: default_options(),
  )
}

/// Clip every subpath in `input` using explicit options.
pub fn path_with(
  input: svg_path.Path,
  to clip_region: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  options options: Options,
) -> Result(svg_path.Path, svg_path.Error) {
  input
  |> svg_path.path_subpaths
  |> clip_subpaths(clip_region, fill_rule, options, kept: [])
  |> result.map(fn(subpaths) { svg_path.Path(subpaths) })
}

/// Clip one subpath to the filled `clip_region`.
///
/// Returned subpaths preserve traversal order. No closing or bridge segments
/// are added at clipping-boundary crossings.
pub fn subpath(
  input: svg_path.Subpath,
  to clip_region: svg_path.Path,
  using fill_rule: svg_path.FillRule,
) -> Result(List(svg_path.Subpath), svg_path.Error) {
  subpath_with(
    input,
    to: clip_region,
    using: fill_rule,
    options: default_options(),
  )
}

/// Clip one subpath using explicit options.
pub fn subpath_with(
  input: svg_path.Subpath,
  to clip_region: svg_path.Path,
  using fill_rule: svg_path.FillRule,
  options options: Options,
) -> Result(List(svg_path.Subpath), svg_path.Error) {
  case svg_path.subpath_segments(input) {
    [] -> Ok([])
    _ -> {
      use split_points <- result.try(split_points(input, clip_region, options))
      case split_points {
        [] -> keep_whole_subpath(input, clip_region, fill_rule, options)
        _ -> {
          use pieces <- result.try(svg_path.subpath_between_many(
            input,
            between: split_points,
          ))
          keep_inside_subpaths(
            pieces,
            clip_region,
            fill_rule,
            options,
            kept: [],
          )
        }
      }
    }
  }
}

fn clip_subpaths(
  subpaths: List(svg_path.Subpath),
  clip_region: svg_path.Path,
  fill_rule: svg_path.FillRule,
  options: Options,
  kept kept: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), svg_path.Error) {
  case subpaths {
    [] -> Ok(list.reverse(kept))
    [subpath, ..rest] -> {
      use clipped <- result.try(subpath_with(
        subpath,
        to: clip_region,
        using: fill_rule,
        options:,
      ))
      clip_subpaths(
        rest,
        clip_region,
        fill_rule,
        options,
        kept: list.append(list.reverse(clipped), kept),
      )
    }
  }
}

fn split_points(
  input: svg_path.Subpath,
  clip_region: svg_path.Path,
  options: Options,
) -> Result(List(svg_path.SubpathParameter), svg_path.Error) {
  use found <- result.try(encounters.path_with(
    svg_path.subpath_as_path(input),
    clip_region,
    options: options.intersection,
  ))
  let encounters.Encounters(overlaps: overlap_intervals, intersections:) = found
  let intersection_parameters =
    intersections |> list.flat_map(left_subpath_parameters)
  let overlap_parameters =
    overlap_intervals |> list.flat_map(left_overlap_parameters)
  let parameters =
    list.append(intersection_parameters, overlap_parameters)
    |> list.map(normalize_parameter(input, _))
    |> list.filter(should_keep_split_point(input, _))

  sort_unique_parameters(input, parameters, options.tolerance)
}

fn left_subpath_parameters(
  intersection: svg_path.PathIntersection,
) -> List(svg_path.SubpathParameter) {
  intersection.left_parameters
  |> list.filter_map(fn(parameter) {
    case parameter {
      svg_path.PathParameter(subpath_index: 0, at:) -> Ok(at)
      _ -> Error(Nil)
    }
  })
}

fn left_overlap_parameters(
  overlap: overlaps.PathOverlap,
) -> List(svg_path.SubpathParameter) {
  [
    overlaps.path_overlap_left_start(overlap),
    overlaps.path_overlap_left_end(overlap),
  ]
  |> list.filter_map(fn(parameter) {
    case parameter {
      Some(svg_path.PathParameter(subpath_index: 0, at:)) -> Ok(at)
      _ -> Error(Nil)
    }
  })
}

fn should_keep_split_point(
  input: svg_path.Subpath,
  parameter: svg_path.SubpathParameter,
) -> Bool {
  case svg_path.subpath_is_closed(input) {
    True -> True
    False -> !is_open_boundary_parameter(input, parameter)
  }
}

fn normalize_parameter(
  input: svg_path.Subpath,
  parameter: svg_path.SubpathParameter,
) -> svg_path.SubpathParameter {
  let length = list.length(svg_path.subpath_segments(input))
  let closed = svg_path.subpath_is_closed(input)
  case parameter {
    svg_path.SubpathParameter(segment_index:, t:)
      if t == 1.0 && segment_index < length - 1
    -> svg_path.SubpathParameter(segment_index + 1, 0.0)
    svg_path.SubpathParameter(segment_index:, t:)
      if t == 1.0 && segment_index == length - 1 && closed
    -> svg_path.SubpathParameter(0, 0.0)
    _ -> parameter
  }
}

fn is_open_boundary_parameter(
  input: svg_path.Subpath,
  parameter: svg_path.SubpathParameter,
) -> Bool {
  let length = list.length(svg_path.subpath_segments(input))
  case parameter {
    svg_path.SubpathParameter(segment_index: 0, t:) if t == 0.0 -> True
    svg_path.SubpathParameter(segment_index:, t:)
      if segment_index == length - 1 && t == 1.0
    -> True
    _ -> False
  }
}

fn sort_unique_parameters(
  input: svg_path.Subpath,
  parameters: List(svg_path.SubpathParameter),
  tolerance: Float,
) -> Result(List(svg_path.SubpathParameter), svg_path.Error) {
  parameters
  |> list.sort(by: svg_path.subpath_parameters_compare)
  |> unique_sorted_parameters(input, tolerance, kept: [])
}

fn unique_sorted_parameters(
  parameters: List(svg_path.SubpathParameter),
  input: svg_path.Subpath,
  tolerance: Float,
  kept kept: List(svg_path.SubpathParameter),
) -> Result(List(svg_path.SubpathParameter), svg_path.Error) {
  case parameters, kept {
    [], _ -> Ok(list.reverse(kept))
    [first, ..rest], [] ->
      unique_sorted_parameters(rest, input, tolerance, kept: [first])
    [first, ..rest], [previous, ..] ->
      case svg_path.subpath_parameters_compare(first, previous) {
        order.Eq -> unique_sorted_parameters(rest, input, tolerance, kept:)
        _ -> {
          use between <- result.try(svg_path.subpath_between(
            input,
            from: previous,
            to: first,
          ))
          use separation <- result.try(svg_path.subpath_length(between))
          case separation <=. tolerance {
            True -> unique_sorted_parameters(rest, input, tolerance, kept:)
            False ->
              unique_sorted_parameters(rest, input, tolerance, kept: [
                first,
                ..kept
              ])
          }
        }
      }
  }
}

fn keep_whole_subpath(
  input: svg_path.Subpath,
  clip_region: svg_path.Path,
  fill_rule: svg_path.FillRule,
  options: Options,
) -> Result(List(svg_path.Subpath), svg_path.Error) {
  use keep <- result.try(subpath_is_inside(
    input,
    clip_region,
    fill_rule,
    options,
  ))
  case keep {
    True -> Ok([input])
    False -> Ok([])
  }
}

fn keep_inside_subpaths(
  pieces: List(svg_path.Subpath),
  clip_region: svg_path.Path,
  fill_rule: svg_path.FillRule,
  options: Options,
  kept kept: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), svg_path.Error) {
  case pieces {
    [] -> Ok(list.reverse(kept))
    [piece, ..rest] -> {
      use keep <- result.try(subpath_is_inside(
        piece,
        clip_region,
        fill_rule,
        options,
      ))
      case keep {
        True ->
          keep_inside_subpaths(rest, clip_region, fill_rule, options, kept: [
            piece,
            ..kept
          ])
        False ->
          keep_inside_subpaths(rest, clip_region, fill_rule, options, kept:)
      }
    }
  }
}

fn subpath_is_inside(
  input: svg_path.Subpath,
  clip_region: svg_path.Path,
  fill_rule: svg_path.FillRule,
  options: Options,
) -> Result(Bool, svg_path.Error) {
  use sample <- result.try(subpath_sample_point(input, options))
  use containment <- result.try(svg_path.path_containment_with(
    sample,
    within: clip_region,
    using: fill_rule,
    options: options.containment,
  ))
  case containment {
    svg_path.Inside | svg_path.Boundary -> Ok(True)
    svg_path.Outside -> Ok(False)
  }
}

fn subpath_sample_point(
  input: svg_path.Subpath,
  options: Options,
) -> Result(svg_path.Point, svg_path.Error) {
  use length <- result.try(svg_path.subpath_length(input))
  case length <=. options.tolerance {
    True -> svg_path.subpath_point(input, at: svg_path.SubpathParameter(0, 0.0))
    False -> svg_path.subpath_point_at_length(input, distance: length /. 2.0)
  }
}
