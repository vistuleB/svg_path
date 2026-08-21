//// One-off artistic path effects.

import gleam/float
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import svg_path
import svg_path/convex_hull
import svg_path/degeneracy
import svg_path/point as point_helpers
import svg_path/trig

const default_tolerance = 0.000001

/// Errors returned by path effects.
pub type Error {
  /// An underlying path operation failed.
  PathError(svg_path.Error)

  /// The radius must be greater than zero.
  InvalidRadius(radius: Float)

  /// The distance tolerance must be finite and greater than zero.
  InvalidDistanceTolerance(tolerance: Float)

  /// The angular tolerance must be finite and non-negative.
  InvalidAngularTolerance(tolerance: Float)

  /// The requested corner cannot be rounded with the current options.
  CannotRoundCorner(index: Int)

  /// Two rounded corners would consume too much of a segment between them.
  CornerTrimsOverlap(segment_index: Int)

  /// Convex-hull construction failed while normalizing degenerate segments.
  ConvexHullError(convex_hull.Error)
}

/// Replace maximal contiguous line-degenerate windows in a subpath.
///
/// Each selected window is replaced by its ordered line traversal. Windows are
/// considered from left to right. Their exact curve-preserving convex hull is
/// grown one segment at a time, and the largest prefix certified to fit in a
/// strip of the requested width is selected first.
pub fn normalize_degenerate_segments(
  subpath: svg_path.Subpath,
  tolerance tolerance: Float,
) -> Result(svg_path.Subpath, Error) {
  degeneracy.normalize_degenerate_segments(subpath, tolerance:)
  |> result.map_error(degeneracy_error)
}

fn degeneracy_error(error: degeneracy.Error) -> Error {
  case error {
    degeneracy.PathError(error) -> PathError(error)
    degeneracy.ConvexHullError(error) -> ConvexHullError(error)
  }
}

/// What to do when an individual corner cannot be rounded.
pub type FailureMode {
  /// Return an error.
  ErrorOnFailure

  /// Leave the corner untouched.
  LeaveCorner

  /// Reduce corner radii as needed after considering all segment constraints.
  /// This first measures every eligible corner, then repeatedly applies the
  /// strongest per-segment radius limits together so the result does not depend
  /// on segment order.
  AdaptRadius
}

/// Options for corner rounding.
pub type RoundCornerOptions {
  RoundCornerOptions(
    failure: FailureMode,
    length: svg_path.LengthOptions,
    distance_tolerance: Float,
    angular_tolerance: Float,
  )
}

type SegmentInfo {
  SegmentInfo(index: Int, segment: svg_path.Segment, length: Float)
}

type Corner {
  Corner(index: Int, trim: Float, arc: svg_path.Segment)
}

type CornerSpec {
  CornerSpec(
    index: Int,
    trim_per_radius: Float,
    incoming_tangent: svg_path.Point,
    outgoing_tangent: svg_path.Point,
  )
}

type AssignedRadius {
  AssignedRadius(index: Int, radius: Float)
}

type AssignedScale {
  AssignedScale(index: Int, scale: Float)
}

/// Return default options for corner rounding.
pub fn default_round_corner_options() -> RoundCornerOptions {
  RoundCornerOptions(
    failure: ErrorOnFailure,
    length: svg_path.default_length_options(),
    distance_tolerance: default_tolerance,
    angular_tolerance: default_tolerance,
  )
}

/// Round eligible corners in every subpath of a path.
///
/// A rounded corner trims both incident segments and inserts a circular SVG
/// arc. For a line-line corner, the arc is an exact circular fillet tangent to
/// both lines. When either incident segment is curved, its endpoint direction
/// determines the trim estimate, but the inserted arc is not guaranteed to be
/// tangent to the curve at the resulting cut point.
///
/// If a corner is straight, degenerate, or lacks enough incident segment
/// length, behavior is controlled by `RoundCornerOptions.failure`.
pub fn round_corners(
  path: svg_path.Path,
  radius radius: Float,
) -> Result(svg_path.Path, Error) {
  round_corners_with(path, radius:, options: default_round_corner_options())
}

/// Round eligible corners in every subpath of a path using explicit options.
pub fn round_corners_with(
  path: svg_path.Path,
  radius radius: Float,
  options options: RoundCornerOptions,
) -> Result(svg_path.Path, Error) {
  use _ <- result.try(validate_round_corner_inputs(radius, options))
  use subpaths <- result.try(
    round_subpaths(svg_path.path_subpaths(path), radius:, options:, rounded: []),
  )
  Ok(svg_path.Path(subpaths:))
}

/// Round eligible corners in a subpath.
pub fn round_subpath_corners(
  subpath: svg_path.Subpath,
  radius radius: Float,
) -> Result(svg_path.Subpath, Error) {
  round_subpath_corners_with(
    subpath,
    radius:,
    options: default_round_corner_options(),
  )
}

/// Round eligible corners in a subpath using explicit options.
pub fn round_subpath_corners_with(
  subpath: svg_path.Subpath,
  radius radius: Float,
  options options: RoundCornerOptions,
) -> Result(svg_path.Subpath, Error) {
  use _ <- result.try(validate_round_corner_inputs(radius, options))
  {
    let segments = svg_path.subpath_segments(subpath)
    case segments {
      [] -> Ok(subpath)
      [_] -> {
        case svg_path.subpath_is_closed(subpath) {
          False -> Ok(subpath)
          True ->
            round_subpath_corners_nonempty(subpath, segments, radius, options)
        }
      }
      _ -> {
        round_subpath_corners_nonempty(subpath, segments, radius, options)
      }
    }
  }
}

fn validate_round_corner_inputs(
  radius: Float,
  options: RoundCornerOptions,
) -> Result(Nil, Error) {
  case valid_radius(radius) {
    False -> Error(InvalidRadius(radius))
    True -> {
      use _ <- result.try(
        svg_path.validate_length_options(options.length)
        |> result.map_error(PathError),
      )
      case
        options.distance_tolerance <=. 0.0
        || options.distance_tolerance -. options.distance_tolerance != 0.0
      {
        True -> Error(InvalidDistanceTolerance(options.distance_tolerance))
        False ->
          case
            options.angular_tolerance <. 0.0
            || options.angular_tolerance -. options.angular_tolerance != 0.0
          {
            True -> Error(InvalidAngularTolerance(options.angular_tolerance))
            False -> Ok(Nil)
          }
      }
    }
  }
}

fn round_subpath_corners_nonempty(
  subpath: svg_path.Subpath,
  segments: List(svg_path.Segment),
  radius: Float,
  options: RoundCornerOptions,
) -> Result(svg_path.Subpath, Error) {
  use infos <- result.try(segment_infos(segments, options.length, []))
  case options.failure {
    AdaptRadius ->
      round_subpath_corners_adaptively(subpath, infos, radius, options)
    ErrorOnFailure | LeaveCorner -> {
      use corners <- result.try(corners(infos, subpath, radius, options))
      let active = resolve_overlapping_trims(corners, infos, subpath, options)
      rounded_subpath_from_corners(subpath, infos, active, options)
    }
  }
}

fn round_subpaths(
  subpaths: List(svg_path.Subpath),
  radius radius: Float,
  options options: RoundCornerOptions,
  rounded rounded: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(rounded))
    [subpath, ..rest] -> {
      use subpath <- result.try(round_subpath_corners_with(
        subpath,
        radius:,
        options:,
      ))
      round_subpaths(rest, radius:, options:, rounded: [subpath, ..rounded])
    }
  }
}

fn valid_radius(radius: Float) -> Bool {
  radius >. 0.0
}

fn segment_infos(
  segments: List(svg_path.Segment),
  length_options: svg_path.LengthOptions,
  infos: List(SegmentInfo),
) -> Result(List(SegmentInfo), Error) {
  segment_infos_loop(segments, length_options, index: 0, infos:)
}

fn segment_infos_loop(
  segments: List(svg_path.Segment),
  length_options: svg_path.LengthOptions,
  index index: Int,
  infos infos: List(SegmentInfo),
) -> Result(List(SegmentInfo), Error) {
  case segments {
    [] -> Ok(list.reverse(infos))
    [segment, ..rest] -> {
      use length <- result.try(
        svg_path.segment_length_with(segment, options: length_options)
        |> result.map_error(PathError),
      )
      segment_infos_loop(rest, length_options, index: index + 1, infos: [
        SegmentInfo(index:, segment:, length:),
        ..infos
      ])
    }
  }
}

fn corners(
  infos: List(SegmentInfo),
  subpath: svg_path.Subpath,
  radius: Float,
  options: RoundCornerOptions,
) -> Result(List(Corner), Error) {
  let pairs = corner_pairs(infos, closed: svg_path.subpath_is_closed(subpath))
  corner_candidates(pairs, radius, options, corners: [])
}

fn corner_pairs(
  infos: List(SegmentInfo),
  closed closed: Bool,
) -> List(#(SegmentInfo, SegmentInfo, Int)) {
  case infos {
    [] -> []
    [_] -> {
      case closed {
        False -> []
        True -> {
          let assert [first] = infos
          [#(first, first, first.index)]
        }
      }
    }
    [first, ..] -> {
      let open_pairs = adjacent_corner_pairs(infos, [])
      case closed {
        False -> open_pairs
        True -> {
          let last = infos |> list.last |> result.unwrap(first)
          list.append(open_pairs, [#(last, first, last.index)])
        }
      }
    }
  }
}

fn adjacent_corner_pairs(
  infos: List(SegmentInfo),
  pairs: List(#(SegmentInfo, SegmentInfo, Int)),
) -> List(#(SegmentInfo, SegmentInfo, Int)) {
  case infos {
    [] | [_] -> list.reverse(pairs)
    [left, right, ..rest] ->
      adjacent_corner_pairs([right, ..rest], [
        #(left, right, left.index),
        ..pairs
      ])
  }
}

fn corner_candidates(
  pairs: List(#(SegmentInfo, SegmentInfo, Int)),
  radius: Float,
  options: RoundCornerOptions,
  corners corners: List(Corner),
) -> Result(List(Corner), Error) {
  case pairs {
    [] -> Ok(list.reverse(corners))
    [#(incoming, outgoing, index), ..rest] -> {
      case corner_candidate(incoming, outgoing, index, radius, options) {
        Ok(Some(corner)) ->
          corner_candidates(rest, radius, options, corners: [corner, ..corners])
        Ok(None) -> corner_candidates(rest, radius, options, corners:)
        Error(error) -> Error(error)
      }
    }
  }
}

fn corner_candidate(
  incoming: SegmentInfo,
  outgoing: SegmentInfo,
  index: Int,
  radius: Float,
  options: RoundCornerOptions,
) -> Result(Option(Corner), Error) {
  use incoming_tangent <- result.try(endpoint_unit_tangent(
    incoming.segment,
    at: 1.0,
    index:,
    options:,
  ))
  use outgoing_tangent <- result.try(endpoint_unit_tangent(
    outgoing.segment,
    at: 0.0,
    index:,
    options:,
  ))
  case incoming_tangent, outgoing_tangent {
    None, _ | _, None -> Ok(None)
    Some(incoming_tangent), Some(outgoing_tangent) -> {
      use angle <- result.try(turn_angle(
        incoming_tangent,
        outgoing_tangent,
        index,
      ))

      case angle <=. options.angular_tolerance {
        True -> Ok(None)
        False -> {
          let trim = radius *. trig.tan_degrees(angle /. 2.0)
          case
            trim >. options.distance_tolerance
            && trim <. incoming.length -. options.distance_tolerance
            && trim <. outgoing.length -. options.distance_tolerance
          {
            False -> corner_failure(index, options)
            True -> {
              use incoming_cut <- result.try(
                svg_path.segment_point_at_length_with(
                  incoming.segment,
                  distance: incoming.length -. trim,
                  options: options.length,
                )
                |> result.map_error(PathError),
              )
              use outgoing_cut <- result.try(
                svg_path.segment_point_at_length_with(
                  outgoing.segment,
                  distance: trim,
                  options: options.length,
                )
                |> result.map_error(PathError),
              )
              Ok(
                Some(Corner(
                  index:,
                  trim:,
                  arc: svg_path.Arc(
                    start: incoming_cut,
                    radius: svg_path.Point(radius, radius),
                    x_axis_rotation: 0.0,
                    large_arc: False,
                    sweep: sweep_from_turn(incoming_tangent, outgoing_tangent),
                    end: outgoing_cut,
                  ),
                )),
              )
            }
          }
        }
      }
    }
  }
}

fn endpoint_unit_tangent(
  segment: svg_path.Segment,
  at t: Float,
  index index: Int,
  options options: RoundCornerOptions,
) -> Result(Option(svg_path.Point), Error) {
  use derivative <- result.try(
    svg_path.segment_derivative(segment, at: t) |> result.map_error(PathError),
  )
  case unit(derivative) {
    Ok(unit) -> Ok(Some(unit))
    Error(_) -> {
      case options.failure {
        ErrorOnFailure -> Error(CannotRoundCorner(index))
        LeaveCorner | AdaptRadius -> Ok(None)
      }
    }
  }
}

fn turn_angle(
  incoming: svg_path.Point,
  outgoing: svg_path.Point,
  index: Int,
) -> Result(Float, Error) {
  let value = clamp(point_helpers.dot(incoming, outgoing), min: -1.0, max: 1.0)
  case trig.acos_degrees(value) {
    Ok(angle) -> Ok(angle)
    Error(_) -> Error(CannotRoundCorner(index))
  }
}

fn corner_failure(
  index: Int,
  options: RoundCornerOptions,
) -> Result(Option(a), Error) {
  case options.failure {
    ErrorOnFailure -> Error(CannotRoundCorner(index))
    LeaveCorner | AdaptRadius -> Ok(None)
  }
}

fn round_subpath_corners_adaptively(
  subpath: svg_path.Subpath,
  infos: List(SegmentInfo),
  radius: Float,
  options: RoundCornerOptions,
) -> Result(svg_path.Subpath, Error) {
  let pairs = corner_pairs(infos, closed: svg_path.subpath_is_closed(subpath))
  use specs <- result.try(corner_specs(pairs, options, specs: []))
  let assigned =
    initial_radii(specs, radius)
    |> adapt_radii(specs, infos, subpath, options, iteration: 0)
  use corners <- result.try(
    corners_from_specs(specs, assigned, infos, options, []),
  )
  rounded_subpath_from_corners(subpath, infos, corners, options)
}

fn rounded_subpath_from_corners(
  subpath: svg_path.Subpath,
  infos: List(SegmentInfo),
  corners: List(Corner),
  options: RoundCornerOptions,
) -> Result(svg_path.Subpath, Error) {
  case list.is_empty(corners) {
    True -> Ok(subpath)
    False -> {
      use rounded_segments <- result.try(
        rounded_subpath_segments(infos, corners, subpath, options, rounded: []),
      )
      use rounded <- result.try(
        svg_path.subpath_with(rounded_segments, policy: svg_path.Wiggle)
        |> result.map_error(PathError),
      )
      svg_path.subpath_set_closed_with(
        rounded,
        closed: svg_path.subpath_is_closed(subpath),
        policy: svg_path.Wiggle,
      )
      |> result.map_error(PathError)
    }
  }
}

fn corner_specs(
  pairs: List(#(SegmentInfo, SegmentInfo, Int)),
  options: RoundCornerOptions,
  specs specs: List(CornerSpec),
) -> Result(List(CornerSpec), Error) {
  case pairs {
    [] -> Ok(list.reverse(specs))
    [#(incoming, outgoing, index), ..rest] -> {
      use maybe_spec <- result.try(corner_spec(
        incoming,
        outgoing,
        index,
        options,
      ))
      let specs = case maybe_spec {
        None -> specs
        Some(spec) -> [spec, ..specs]
      }
      corner_specs(rest, options, specs:)
    }
  }
}

fn corner_spec(
  incoming: SegmentInfo,
  outgoing: SegmentInfo,
  index: Int,
  options: RoundCornerOptions,
) -> Result(Option(CornerSpec), Error) {
  use incoming_tangent <- result.try(endpoint_unit_tangent(
    incoming.segment,
    at: 1.0,
    index:,
    options:,
  ))
  use outgoing_tangent <- result.try(endpoint_unit_tangent(
    outgoing.segment,
    at: 0.0,
    index:,
    options:,
  ))
  case incoming_tangent, outgoing_tangent {
    None, _ | _, None -> Ok(None)
    Some(incoming_tangent), Some(outgoing_tangent) -> {
      use angle <- result.try(turn_angle(
        incoming_tangent,
        outgoing_tangent,
        index,
      ))
      case angle <=. options.angular_tolerance {
        True -> Ok(None)
        False -> {
          let trim_per_radius = trig.tan_degrees(angle /. 2.0)
          case trim_per_radius >. 0.0 {
            False -> Ok(None)
            True ->
              Ok(
                Some(CornerSpec(
                  index:,
                  trim_per_radius:,
                  incoming_tangent:,
                  outgoing_tangent:,
                )),
              )
          }
        }
      }
    }
  }
}

fn initial_radii(
  specs: List(CornerSpec),
  radius: Float,
) -> List(AssignedRadius) {
  specs
  |> list.map(fn(spec) { AssignedRadius(index: spec.index, radius:) })
}

fn adapt_radii(
  radii: List(AssignedRadius),
  specs: List(CornerSpec),
  infos: List(SegmentInfo),
  subpath: svg_path.Subpath,
  options: RoundCornerOptions,
  iteration iteration: Int,
) -> List(AssignedRadius) {
  case iteration >= 24 {
    True -> radii
    False -> {
      let next =
        segment_scales(specs, infos, radii, subpath, options.distance_tolerance)
        |> apply_radius_scales(radii)
      case radii_near(radii, next, options.distance_tolerance) {
        True -> next
        False ->
          adapt_radii(
            next,
            specs,
            infos,
            subpath,
            options,
            iteration: iteration + 1,
          )
      }
    }
  }
}

fn segment_scales(
  specs: List(CornerSpec),
  infos: List(SegmentInfo),
  radii: List(AssignedRadius),
  subpath: svg_path.Subpath,
  tolerance: Float,
) -> List(AssignedScale) {
  let scales = specs |> list.map(fn(spec) { AssignedScale(spec.index, 1.0) })

  infos
  |> list.fold(scales, fn(scales, info) {
    constrain_segment_scales(scales, specs, radii, info, subpath, tolerance)
  })
}

fn constrain_segment_scales(
  scales: List(AssignedScale),
  specs: List(CornerSpec),
  radii: List(AssignedRadius),
  info: SegmentInfo,
  subpath: svg_path.Subpath,
  tolerance: Float,
) -> List(AssignedScale) {
  let before_index = previous_corner_index(info.index, subpath)
  let before = find_spec(before_index, specs)
  let after = find_spec(info.index, specs)
  let before_trim = spec_trim(before, radii)
  let after_trim = spec_trim(after, radii)
  let total = before_trim +. after_trim
  let available = float.max(0.0, info.length -. 2.0 *. tolerance)

  case total <=. available {
    True -> scales
    False -> {
      let scale = available /. total
      scales
      |> limit_scale(before_index, scale)
      |> limit_scale(info.index, scale)
    }
  }
}

fn spec_trim(spec: Option(CornerSpec), radii: List(AssignedRadius)) -> Float {
  case spec {
    None -> 0.0
    Some(spec) -> radius_for(spec.index, radii) *. spec.trim_per_radius
  }
}

fn limit_scale(
  scales: List(AssignedScale),
  index: Int,
  scale: Float,
) -> List(AssignedScale) {
  scales
  |> list.map(fn(assigned) {
    case assigned.index == index {
      True -> AssignedScale(index:, scale: float.min(assigned.scale, scale))
      False -> assigned
    }
  })
}

fn apply_radius_scales(
  scales: List(AssignedScale),
  radii: List(AssignedRadius),
) -> List(AssignedRadius) {
  radii
  |> list.map(fn(radius) {
    AssignedRadius(
      index: radius.index,
      radius: radius.radius *. scale_for(radius.index, scales),
    )
  })
}

fn scale_for(index: Int, scales: List(AssignedScale)) -> Float {
  case scales {
    [] -> 1.0
    [scale, ..rest] -> {
      case scale.index == index {
        True -> scale.scale
        False -> scale_for(index, rest)
      }
    }
  }
}

fn radii_near(
  left: List(AssignedRadius),
  right: List(AssignedRadius),
  tolerance: Float,
) -> Bool {
  case left {
    [] -> True
    [radius, ..rest] -> {
      float.absolute_value(radius.radius -. radius_for(radius.index, right))
      <=. tolerance
      && radii_near(rest, right, tolerance)
    }
  }
}

fn corners_from_specs(
  specs: List(CornerSpec),
  radii: List(AssignedRadius),
  infos: List(SegmentInfo),
  options: RoundCornerOptions,
  corners: List(Corner),
) -> Result(List(Corner), Error) {
  case specs {
    [] -> Ok(list.reverse(corners))
    [spec, ..rest] -> {
      let radius = radius_for(spec.index, radii)
      let trim = radius *. spec.trim_per_radius
      case
        radius <=. options.distance_tolerance
        || trim <=. options.distance_tolerance
      {
        True -> corners_from_specs(rest, radii, infos, options, corners)
        False -> {
          use corner <- result.try(corner_from_spec(
            spec,
            radius,
            trim,
            infos,
            options,
          ))
          corners_from_specs(rest, radii, infos, options, [corner, ..corners])
        }
      }
    }
  }
}

fn corner_from_spec(
  spec: CornerSpec,
  radius: Float,
  trim: Float,
  infos: List(SegmentInfo),
  options: RoundCornerOptions,
) -> Result(Corner, Error) {
  use incoming <- result.try(
    segment_info(spec.index, infos) |> result.map_error(CornerTrimsOverlap),
  )
  use outgoing <- result.try(
    next_segment_info(spec.index, infos) |> result.map_error(CornerTrimsOverlap),
  )
  use incoming_cut <- result.try(
    svg_path.segment_point_at_length_with(
      incoming.segment,
      distance: incoming.length -. trim,
      options: options.length,
    )
    |> result.map_error(PathError),
  )
  use outgoing_cut <- result.try(
    svg_path.segment_point_at_length_with(
      outgoing.segment,
      distance: trim,
      options: options.length,
    )
    |> result.map_error(PathError),
  )
  Ok(Corner(
    index: spec.index,
    trim:,
    arc: svg_path.Arc(
      start: incoming_cut,
      radius: svg_path.Point(radius, radius),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: sweep_from_turn(spec.incoming_tangent, spec.outgoing_tangent),
      end: outgoing_cut,
    ),
  ))
}

fn segment_info(
  index: Int,
  infos: List(SegmentInfo),
) -> Result(SegmentInfo, Int) {
  case infos {
    [] -> Error(index)
    [info, ..rest] -> {
      case info.index == index {
        True -> Ok(info)
        False -> segment_info(index, rest)
      }
    }
  }
}

fn next_segment_info(
  index: Int,
  infos: List(SegmentInfo),
) -> Result(SegmentInfo, Int) {
  case segment_info(index + 1, infos) {
    Ok(info) -> Ok(info)
    Error(_) -> segment_info(0, infos)
  }
}

fn find_spec(index: Int, specs: List(CornerSpec)) -> Option(CornerSpec) {
  case specs {
    [] -> None
    [spec, ..rest] -> {
      case spec.index == index {
        True -> Some(spec)
        False -> find_spec(index, rest)
      }
    }
  }
}

fn radius_for(index: Int, radii: List(AssignedRadius)) -> Float {
  case radii {
    [] -> 0.0
    [radius, ..rest] -> {
      case radius.index == index {
        True -> radius.radius
        False -> radius_for(index, rest)
      }
    }
  }
}

fn resolve_overlapping_trims(
  corners: List(Corner),
  infos: List(SegmentInfo),
  subpath: svg_path.Subpath,
  options: RoundCornerOptions,
) -> List(Corner) {
  case
    first_overlapping_segment(
      corners,
      infos,
      subpath,
      options.distance_tolerance,
    )
  {
    Ok(_) -> corners
    Error(index) -> {
      case options.failure {
        ErrorOnFailure -> corners
        AdaptRadius -> corners
        LeaveCorner -> {
          let filtered = corners_touching_segment(corners, index, subpath)
          resolve_overlapping_trims(filtered, infos, subpath, options)
        }
      }
    }
  }
}

fn rounded_subpath_segments(
  infos: List(SegmentInfo),
  corners: List(Corner),
  subpath: svg_path.Subpath,
  options: RoundCornerOptions,
  rounded rounded: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), Error) {
  case infos {
    [] -> Ok(list.reverse(rounded))
    [info, ..rest] -> {
      let start_trim = start_trim(info.index, corners, subpath)
      let end_trim = end_trim(info.index, corners)
      case
        start_trim +. end_trim >=. info.length -. options.distance_tolerance
      {
        True -> Error(CornerTrimsOverlap(info.index))
        False -> {
          use shortened <- result.try(
            svg_path.segment_between_lengths_with(
              info.segment,
              from: start_trim,
              to: info.length -. end_trim,
              options: options.length,
            )
            |> result.map_error(PathError),
          )
          let rounded = case corner_after(info.index, corners) {
            None -> [shortened, ..rounded]
            Some(corner) -> [corner.arc, shortened, ..rounded]
          }
          rounded_subpath_segments(rest, corners, subpath, options, rounded:)
        }
      }
    }
  }
}

fn first_overlapping_segment(
  corners: List(Corner),
  infos: List(SegmentInfo),
  subpath: svg_path.Subpath,
  tolerance: Float,
) -> Result(Nil, Int) {
  case infos {
    [] -> Ok(Nil)
    [info, ..rest] -> {
      case
        start_trim(info.index, corners, subpath)
        +. end_trim(info.index, corners)
        >=. info.length -. tolerance
      {
        True -> Error(info.index)
        False -> first_overlapping_segment(corners, rest, subpath, tolerance)
      }
    }
  }
}

fn corners_touching_segment(
  corners: List(Corner),
  segment_index: Int,
  subpath: svg_path.Subpath,
) -> List(Corner) {
  let before_index = previous_corner_index(segment_index, subpath)
  corners
  |> list.filter(keeping: fn(corner) {
    corner.index != segment_index && corner.index != before_index
  })
}

fn previous_corner_index(segment_index: Int, subpath: svg_path.Subpath) -> Int {
  case segment_index > 0 {
    True -> segment_index - 1
    False -> {
      case svg_path.subpath_is_closed(subpath) {
        False -> -1
        True -> list.length(svg_path.subpath_segments(subpath)) - 1
      }
    }
  }
}

fn start_trim(
  segment_index: Int,
  corners: List(Corner),
  subpath: svg_path.Subpath,
) -> Float {
  find_corner(previous_corner_index(segment_index, subpath), corners)
  |> corner_trim
}

fn end_trim(segment_index: Int, corners: List(Corner)) -> Float {
  find_corner(segment_index, corners) |> corner_trim
}

fn corner_after(segment_index: Int, corners: List(Corner)) -> Option(Corner) {
  find_corner(segment_index, corners)
}

fn find_corner(index: Int, corners: List(Corner)) -> Option(Corner) {
  case corners {
    [] -> None
    [corner, ..rest] -> {
      case corner.index == index {
        True -> Some(corner)
        False -> find_corner(index, rest)
      }
    }
  }
}

fn corner_trim(corner: Option(Corner)) -> Float {
  case corner {
    None -> 0.0
    Some(Corner(trim:, ..)) -> trim
  }
}

fn unit(point: svg_path.Point) -> Result(svg_path.Point, Nil) {
  point_helpers.normalize(point)
}

fn sweep_from_turn(incoming: svg_path.Point, outgoing: svg_path.Point) -> Bool {
  point_helpers.cross(incoming, outgoing) >=. 0.0
}

fn clamp(value: Float, min min: Float, max max: Float) -> Float {
  value |> float.max(min) |> float.min(max)
}
