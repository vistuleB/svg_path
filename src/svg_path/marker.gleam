//// Marker placement helpers.
////
//// SVG markers are full rendering objects with their own viewport, reference
//// point, units, and content. This module only covers the part supplied by path
//// data: marker positions and path-derived orientation angles.

import gleam/float
import gleam/list
import gleam/result
import svg_path
import svg_path/transform as affine
import svg_path/trig

/// Errors returned while computing marker poses.
pub type Error {
  /// The subpath has no drawable segments.
  EmptySubpath

  /// A marker orientation could not be computed from a zero derivative.
  DegenerateTangent

  /// An underlying path operation failed.
  PathError(svg_path.Error)
}

/// Which SVG marker slot a pose belongs to.
pub type MarkerKind {
  MarkerStart
  MarkerMid
  MarkerEnd
}

/// A marker position and absolute orientation angle in degrees.
pub type MarkerPose {
  MarkerPose(kind: MarkerKind, point: svg_path.Point, angle: Float)
}

/// SVG-style marker orientation policy.
pub type MarkerOrient {
  /// Use path-derived marker angles.
  Auto

  /// Use path-derived marker angles, but rotate the start marker by 180 degrees.
  AutoStartReverse

  /// Use one fixed absolute angle for every marker.
  Fixed(Float)
}

/// Return marker poses for one subpath.
///
/// `MarkerStart` is placed at the first segment start, `MarkerEnd` at the last
/// segment end, and `MarkerMid` at each join between adjacent segments. For
/// `Auto`, open-subpath start and end markers use the outgoing and incoming
/// segment directions respectively. Mid markers and closed-subpath start/end
/// markers use the angle bisector of the incoming and outgoing directions. If
/// that bisector is degenerate because the two directions are exactly opposite,
/// the incoming direction is used.
pub fn subpath_poses(
  subpath: svg_path.Subpath,
  orient orient: MarkerOrient,
) -> Result(List(MarkerPose), Error) {
  case svg_path.subpath_segments(subpath) {
    [] -> Error(EmptySubpath)
    [first, ..rest] -> {
      let last = last_segment(first, rest)
      use start_angle <- result.try(start_angle(
        first,
        last,
        orient,
        closed: svg_path.subpath_is_closed(subpath),
      ))
      use mids <- result.try(mid_poses(first, rest, orient, poses: []))
      use end <- result.try(end_pose(
        first,
        last,
        orient,
        closed: svg_path.subpath_is_closed(subpath),
      ))

      Ok([
        MarkerPose(
          kind: MarkerStart,
          point: svg_path.segment_start(first),
          angle: start_angle,
        ),
        ..list.append(mids, [end])
      ])
    }
  }
}

/// Return a transform that places marker-local coordinates at a pose.
///
/// The returned matrix rotates marker-local coordinates by the pose angle, then
/// translates marker-local `(0, 0)` to the pose point.
pub fn pose_transform(pose: MarkerPose) -> affine.Matrix {
  let MarkerPose(point:, angle:, ..) = pose
  transform(point:, angle:)
}

/// Return a transform that places marker-local coordinates at `point`.
///
/// The returned matrix rotates marker-local coordinates by `angle`, then
/// translates marker-local `(0, 0)` to `point`.
pub fn transform(
  point point: svg_path.Point,
  angle angle: Float,
) -> affine.Matrix {
  affine.rotate(degrees: angle)
  |> affine.chain(first: _, then: affine.translate(x: point.x, y: point.y))
}

/// Return a transform that places a marker-local reference point at a pose.
///
/// The returned matrix rotates marker-local coordinates by the pose angle and
/// translates them so `reference` lands on the pose point. This corresponds to
/// the geometric part of SVG's `refX` and `refY` marker reference point.
pub fn pose_transform_with_reference(
  pose: MarkerPose,
  reference reference: svg_path.Point,
) -> affine.Matrix {
  let MarkerPose(point:, angle:, ..) = pose
  transform_with_reference(point:, angle:, reference:)
}

/// Return a transform that places a marker-local reference point at `point`.
pub fn transform_with_reference(
  point point: svg_path.Point,
  angle angle: Float,
  reference reference: svg_path.Point,
) -> affine.Matrix {
  affine.translate(x: 0.0 -. reference.x, y: 0.0 -. reference.y)
  |> affine.chain(first: _, then: affine.rotate(degrees: angle))
  |> affine.chain(first: _, then: affine.translate(x: point.x, y: point.y))
}

fn mid_poses(
  previous: svg_path.Segment,
  remaining: List(svg_path.Segment),
  orient: MarkerOrient,
  poses poses: List(MarkerPose),
) -> Result(List(MarkerPose), Error) {
  case remaining {
    [] -> Ok(list.reverse(poses))
    [next, ..rest] -> {
      use angle <- result.try(mid_angle(previous, next, orient))
      let pose =
        MarkerPose(
          kind: MarkerMid,
          point: svg_path.segment_end(previous),
          angle:,
        )
      mid_poses(next, rest, orient, poses: [pose, ..poses])
    }
  }
}

fn end_pose(
  first: svg_path.Segment,
  last: svg_path.Segment,
  orient: MarkerOrient,
  closed closed: Bool,
) -> Result(MarkerPose, Error) {
  use angle <- result.try(end_angle(first, last, orient, closed:))
  Ok(MarkerPose(kind: MarkerEnd, point: svg_path.segment_end(last), angle:))
}

fn start_angle(
  first: svg_path.Segment,
  last: svg_path.Segment,
  orient: MarkerOrient,
  closed closed: Bool,
) -> Result(Float, Error) {
  case orient {
    Fixed(angle) -> Ok(angle)
    Auto -> {
      case closed {
        True -> join_angle(last, first)
        False -> tangent_angle(first, at: 0.0)
      }
    }
    AutoStartReverse -> {
      use angle <- result.try(case closed {
        True -> join_angle(last, first)
        False -> tangent_angle(first, at: 0.0)
      })
      Ok(angle +. 180.0)
    }
  }
}

fn end_angle(
  first: svg_path.Segment,
  last: svg_path.Segment,
  orient: MarkerOrient,
  closed closed: Bool,
) -> Result(Float, Error) {
  case orient {
    Fixed(angle) -> Ok(angle)
    Auto | AutoStartReverse -> {
      case closed {
        True -> join_angle(last, first)
        False -> tangent_angle(last, at: 1.0)
      }
    }
  }
}

fn mid_angle(
  incoming: svg_path.Segment,
  outgoing: svg_path.Segment,
  orient: MarkerOrient,
) -> Result(Float, Error) {
  case orient {
    Fixed(angle) -> Ok(angle)
    Auto | AutoStartReverse -> join_angle(incoming, outgoing)
  }
}

fn join_angle(
  incoming_segment: svg_path.Segment,
  outgoing_segment: svg_path.Segment,
) -> Result(Float, Error) {
  use incoming <- result.try(tangent_unit(incoming_segment, at: 1.0))
  use outgoing <- result.try(tangent_unit(outgoing_segment, at: 0.0))
  let bisector =
    svg_path.point(incoming.x +. outgoing.x, incoming.y +. outgoing.y)

  case vector_length(bisector) <=. 0.0 {
    True -> Ok(angle_of(incoming))
    False -> Ok(angle_of(bisector))
  }
}

fn last_segment(
  first: svg_path.Segment,
  rest: List(svg_path.Segment),
) -> svg_path.Segment {
  case list.last(rest) {
    Ok(last) -> last
    Error(_) -> first
  }
}

fn tangent_angle(
  segment: svg_path.Segment,
  at t: Float,
) -> Result(Float, Error) {
  use tangent <- result.try(tangent_unit(segment, at: t))
  Ok(angle_of(tangent))
}

fn tangent_unit(
  segment: svg_path.Segment,
  at t: Float,
) -> Result(svg_path.Point, Error) {
  use tangent <- result.try(
    svg_path.segment_derivative(segment, at: t) |> result.map_error(PathError),
  )
  let length = vector_length(tangent)
  case length <=. 0.0 || !is_finite(length) {
    True -> Error(DegenerateTangent)
    False -> Ok(svg_path.point(tangent.x /. length, tangent.y /. length))
  }
}

fn angle_of(vector: svg_path.Point) -> Float {
  trig.atan2_degrees(vector.y, vector.x)
}

fn vector_length(vector: svg_path.Point) -> Float {
  let assert Ok(length) =
    vector.x *. vector.x +. vector.y *. vector.y
    |> float.square_root
  length
}

fn is_finite(value: Float) -> Bool {
  !is_nan(value -. value)
}

fn is_nan(value: Float) -> Bool {
  !{ value <. 0.0 || value >=. 0.0 }
}
