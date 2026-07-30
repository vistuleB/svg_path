//// Cutting helpers for path geometry.
////
//// Cutters are only used to find intersection parameters on the subject; only
//// subject pieces are returned.

import gleam/list
import gleam/order
import gleam/result
import svg_path
import svg_path/intersections

/// Cut a subject path by a cutter path.
///
/// The returned path contains only pieces of the subject path, in subject
/// traversal order. The cutter path is only used to find cut points. All cut
/// points for each subject subpath are gathered before cutting, so the result is
/// independent of cutter subpath order.
pub fn path(
  subject subject: svg_path.Path,
  by cutter: svg_path.Path,
) -> Result(svg_path.Path, svg_path.Error) {
  path_with(subject:, by: cutter, options: intersections.default_options())
}

/// Cut a subject path by a cutter path using explicit intersection options.
pub fn path_with(
  subject subject: svg_path.Path,
  by cutter: svg_path.Path,
  options options: svg_path.IntersectionOptions,
) -> Result(svg_path.Path, svg_path.Error) {
  use pieces <- result.try(
    cut_subject_subpaths(subject.subpaths, cutter, options, accumulated: []),
  )

  Ok(svg_path.Path(pieces))
}

/// Cut a subject subpath by a cutter subpath.
///
/// The returned pieces follow the subject's traversal order. The cutter is not
/// returned. If there are no usable cut points, the unchanged subject is
/// returned in a singleton list.
///
/// For open subjects, intersections at the very start or very end are ignored
/// because they do not cut the subject. For closed subjects, one cut point opens
/// the whole loop at that point; two or more cut points return the open pieces
/// between adjacent cut points.
pub fn subpath(
  subject subject: svg_path.Subpath,
  by cutter: svg_path.Subpath,
) -> Result(List(svg_path.Subpath), svg_path.Error) {
  subpath_with(subject:, by: cutter, options: intersections.default_options())
}

/// Cut a subject subpath by a cutter subpath using explicit intersection
/// options.
pub fn subpath_with(
  subject subject: svg_path.Subpath,
  by cutter: svg_path.Subpath,
  options options: svg_path.IntersectionOptions,
) -> Result(List(svg_path.Subpath), svg_path.Error) {
  use intersections <- result.try(intersections.subpath_with(
    subject,
    cutter,
    options:,
  ))

  intersections
  |> list.flat_map(fn(intersection) { intersection.left_parameters })
  |> cut_at_parameters(subject: subject)
}

fn cut_subject_subpaths(
  subpaths: List(svg_path.Subpath),
  cutter: svg_path.Path,
  options: svg_path.IntersectionOptions,
  accumulated accumulated: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), svg_path.Error) {
  case subpaths {
    [] -> Ok(list.reverse(accumulated))
    [subject, ..rest] -> {
      use cut_points <- result.try(path_cut_points(subject, cutter, options))
      use pieces <- result.try(cut_at_parameters(cut_points, subject: subject))

      cut_subject_subpaths(
        rest,
        cutter,
        options,
        accumulated: list.append(list.reverse(pieces), accumulated),
      )
    }
  }
}

fn path_cut_points(
  subject: svg_path.Subpath,
  cutter: svg_path.Path,
  options: svg_path.IntersectionOptions,
) -> Result(List(svg_path.SubpathParameter), svg_path.Error) {
  use intersections <- result.try(intersections.path_with(
    svg_path.path_from_subpath(subject),
    cutter,
    options:,
  ))

  intersections
  |> list.flat_map(fn(intersection) {
    intersection.left_parameters
    |> list.filter_map(fn(parameter) {
      case parameter {
        svg_path.PathParameter(subpath_index: 0, at:) -> Ok(at)
        _ -> Error(Nil)
      }
    })
  })
  |> Ok
}

fn cut_at_parameters(
  parameters: List(svg_path.SubpathParameter),
  subject subject: svg_path.Subpath,
) -> Result(List(svg_path.Subpath), svg_path.Error) {
  let cut_points =
    parameters
    |> list.filter(should_keep_parameter(subject, _))
    |> sort_unique_parameters

  case cut_points {
    [] -> Ok([subject])
    _ -> svg_path.subpath_between_many(subject, between: cut_points)
  }
}

fn should_keep_parameter(
  subject: svg_path.Subpath,
  parameter: svg_path.SubpathParameter,
) -> Bool {
  case svg_path.subpath_is_closed(subject) {
    True -> True
    False -> !is_open_boundary_parameter(subject, parameter)
  }
}

fn is_open_boundary_parameter(
  subject: svg_path.Subpath,
  parameter: svg_path.SubpathParameter,
) -> Bool {
  let length = list.length(svg_path.subpath_segments(subject))
  case parameter {
    svg_path.SubpathParameter(segment_index: 0, t:) if t == 0.0 -> True
    svg_path.SubpathParameter(segment_index:, t:)
      if segment_index == length - 1 && t == 1.0
    -> True
    _ -> False
  }
}

fn sort_unique_parameters(
  parameters: List(svg_path.SubpathParameter),
) -> List(svg_path.SubpathParameter) {
  parameters
  |> list.sort(by: svg_path.subpath_parameters_compare)
  |> unique_sorted_parameters(kept: [])
}

fn unique_sorted_parameters(
  parameters: List(svg_path.SubpathParameter),
  kept kept: List(svg_path.SubpathParameter),
) -> List(svg_path.SubpathParameter) {
  case parameters, kept {
    [], _ -> list.reverse(kept)
    [first, ..rest], [] -> unique_sorted_parameters(rest, kept: [first])
    [first, ..rest], [previous, ..] ->
      case svg_path.subpath_parameters_compare(first, previous) {
        order.Eq -> unique_sorted_parameters(rest, kept:)
        _ -> unique_sorted_parameters(rest, kept: [first, ..kept])
      }
  }
}
