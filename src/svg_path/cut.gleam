//// Cutting helpers for path geometry.
////
//// Cutters are only used to find intersection parameters on the subject; only
//// subject pieces are returned.

import gleam/list
import gleam/result
import svg_path
import vec/vec2f

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
  path_with(
    subject:,
    by: cutter,
    options: svg_path.default_intersection_options(),
  )
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
/// Intersections near internal segment boundaries are canonicalized to one
/// subject parameter before splitting. For open subjects, intersections at the
/// very start or very end are ignored because they do not cut the subject. For
/// closed subjects, one cut point opens the whole loop at that point; two or more
/// cut points return the open pieces between adjacent cut points.
pub fn subpath(
  subject subject: svg_path.Subpath,
  by cutter: svg_path.Subpath,
) -> Result(List(svg_path.Subpath), svg_path.Error) {
  subpath_with(
    subject:,
    by: cutter,
    options: svg_path.default_intersection_options(),
  )
}

/// Cut a subject subpath by a cutter subpath using explicit intersection
/// options.
pub fn subpath_with(
  subject subject: svg_path.Subpath,
  by cutter: svg_path.Subpath,
  options options: svg_path.IntersectionOptions,
) -> Result(List(svg_path.Subpath), svg_path.Error) {
  use intersections <- result.try(svg_path.subpath_intersections_with(
    subject,
    cutter,
    options:,
  ))

  intersections
  |> list.flat_map(fn(intersection) { intersection.left_parameters })
  |> cut_at_parameters(subject: subject, tolerance: options.tolerance)
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
      use pieces <- result.try(cut_at_parameters(
        cut_points,
        subject: subject,
        tolerance: options.tolerance,
      ))

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
  use intersections <- result.try(svg_path.path_intersections_with(
    svg_path.from_subpath(subject),
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
  tolerance tolerance: Float,
) -> Result(List(svg_path.Subpath), svg_path.Error) {
  let cut_points =
    parameters
    |> list.map(canonicalize_subpath_parameter(subject, _, tolerance))
    |> list.filter(should_keep_parameter(subject, _))
    |> sort_near_unique_parameters(subject: subject, tolerance: tolerance)

  case cut_points {
    [] -> Ok([subject])
    _ -> svg_path.subpaths_between(subject, between: cut_points)
  }
}

fn should_keep_parameter(
  subject: svg_path.Subpath,
  parameter: svg_path.SubpathParameter,
) -> Bool {
  case svg_path.is_closed(subject) {
    True -> True
    False -> !is_open_boundary_parameter(subject, parameter)
  }
}

fn canonicalize_subpath_parameter(
  subject: svg_path.Subpath,
  parameter: svg_path.SubpathParameter,
  tolerance: Float,
) -> svg_path.SubpathParameter {
  let length = list.length(svg_path.segments(subject))
  let closed = svg_path.is_closed(subject)
  case parameter {
    svg_path.SubpathParameter(segment_index:, t:) if t <=. tolerance ->
      svg_path.SubpathParameter(segment_index:, t: 0.0)
    svg_path.SubpathParameter(segment_index:, t:) if 1.0 -. t <=. tolerance -> {
      case segment_index < length - 1, closed {
        True, _ -> svg_path.SubpathParameter(segment_index + 1, 0.0)
        False, True -> svg_path.SubpathParameter(0, 0.0)
        False, False -> svg_path.SubpathParameter(segment_index:, t: 1.0)
      }
    }
    _ -> parameter
  }
}

fn is_open_boundary_parameter(
  subject: svg_path.Subpath,
  parameter: svg_path.SubpathParameter,
) -> Bool {
  let length = list.length(svg_path.segments(subject))
  case parameter {
    svg_path.SubpathParameter(segment_index: 0, t:) if t == 0.0 -> True
    svg_path.SubpathParameter(segment_index:, t:)
      if segment_index == length - 1 && t == 1.0
    -> True
    _ -> False
  }
}

fn sort_near_unique_parameters(
  parameters: List(svg_path.SubpathParameter),
  subject subject: svg_path.Subpath,
  tolerance tolerance: Float,
) -> List(svg_path.SubpathParameter) {
  parameters
  |> list.sort(by: svg_path.compare_subpath_parameters)
  |> near_unique_sorted_parameters(
    subject: subject,
    tolerance: tolerance,
    kept: [],
  )
  |> drop_closed_wrap_duplicate(subject: subject, tolerance: tolerance)
}

fn near_unique_sorted_parameters(
  parameters: List(svg_path.SubpathParameter),
  subject subject: svg_path.Subpath,
  tolerance tolerance: Float,
  kept kept: List(svg_path.SubpathParameter),
) -> List(svg_path.SubpathParameter) {
  case parameters, kept {
    [], _ -> list.reverse(kept)
    [first, ..rest], [] ->
      near_unique_sorted_parameters(
        rest,
        subject: subject,
        tolerance: tolerance,
        kept: [first],
      )
    [first, ..rest], [previous, ..] ->
      case subpath_parameters_near(subject, first, previous, tolerance) {
        True ->
          near_unique_sorted_parameters(
            rest,
            subject: subject,
            tolerance: tolerance,
            kept:,
          )
        False ->
          near_unique_sorted_parameters(
            rest,
            subject: subject,
            tolerance: tolerance,
            kept: [first, ..kept],
          )
      }
  }
}

fn drop_closed_wrap_duplicate(
  parameters: List(svg_path.SubpathParameter),
  subject subject: svg_path.Subpath,
  tolerance tolerance: Float,
) -> List(svg_path.SubpathParameter) {
  case svg_path.is_closed(subject), parameters {
    True, [first, second, ..rest] -> {
      let last = list.last(parameters)
      case last {
        Ok(last) ->
          case subpath_parameters_near(subject, first, last, tolerance) {
            True -> [second, ..rest]
            False -> parameters
          }
        _ -> parameters
      }
    }
    _, _ -> parameters
  }
}

fn subpath_parameters_near(
  subject: svg_path.Subpath,
  a: svg_path.SubpathParameter,
  b: svg_path.SubpathParameter,
  tolerance: Float,
) -> Bool {
  parameter_addresses_near(subject, a, b, tolerance)
  && parameter_positions_near(subject, a, b, tolerance)
}

fn parameter_addresses_near(
  subject: svg_path.Subpath,
  a: svg_path.SubpathParameter,
  b: svg_path.SubpathParameter,
  tolerance: Float,
) -> Bool {
  let svg_path.SubpathParameter(segment_index: a_index, t: a_t) = a
  let svg_path.SubpathParameter(segment_index: b_index, t: b_t) = b
  let length = list.length(svg_path.segments(subject))
  case a_index == b_index {
    True -> float_absolute_value(a_t -. b_t) <=. tolerance
    False ->
      are_adjacent_boundary_parameters(a_index, a_t, b_index, b_t, tolerance)
      || {
        svg_path.is_closed(subject)
        && are_closed_wrap_boundary_parameters(
          a_index,
          a_t,
          b_index,
          b_t,
          length,
          tolerance,
        )
      }
  }
}

fn are_adjacent_boundary_parameters(
  a_index: Int,
  a_t: Float,
  b_index: Int,
  b_t: Float,
  tolerance: Float,
) -> Bool {
  case a_index + 1 == b_index {
    True -> float_absolute_value(b_t -. a_t +. 1.0) <=. tolerance
    False ->
      case b_index + 1 == a_index {
        True -> float_absolute_value(a_t -. b_t +. 1.0) <=. tolerance
        False -> False
      }
  }
}

fn are_closed_wrap_boundary_parameters(
  a_index: Int,
  a_t: Float,
  b_index: Int,
  b_t: Float,
  length: Int,
  tolerance: Float,
) -> Bool {
  case a_index == 0 && b_index == length - 1 {
    True -> float_absolute_value(a_t -. b_t +. 1.0) <=. tolerance
    False ->
      case b_index == 0 && a_index == length - 1 {
        True -> float_absolute_value(b_t -. a_t +. 1.0) <=. tolerance
        False -> False
      }
  }
}

fn parameter_positions_near(
  subject: svg_path.Subpath,
  a: svg_path.SubpathParameter,
  b: svg_path.SubpathParameter,
  tolerance: Float,
) -> Bool {
  let a_point = svg_path.subpath_point(subject, at: a)
  let b_point = svg_path.subpath_point(subject, at: b)
  case a_point, b_point {
    Ok(a_point), Ok(b_point) ->
      vec2f.distance_squared(a_point, with: b_point) <=. tolerance *. tolerance
    _, _ -> False
  }
}

fn float_absolute_value(value: Float) -> Float {
  case value <. 0.0 {
    True -> 0.0 -. value
    False -> value
  }
}
