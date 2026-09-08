//// Small helper library for the `svg_path.Point` type.

import gleam/float
import gleam/result
import svg_path
import svg_path/internal/number
import svg_path/trig

/// The unit vector pointing right.
pub const right = svg_path.Point(1.0, 0.0)

/// The unit vector pointing left.
pub const left = svg_path.Point(-1.0, 0.0)

/// The unit vector pointing up in SVG coordinates.
pub const up = svg_path.Point(0.0, -1.0)

/// The unit vector pointing down in SVG coordinates.
pub const down = svg_path.Point(0.0, 1.0)

/// The zero vector.
pub const zero = svg_path.Point(0.0, 0.0)

/// Return the unit vector pointing at an SVG angle in degrees.
///
/// `0` points right, `90` points down, `180` points left, and `270` points up.
pub fn direction(degrees degrees: Float) -> svg_path.Point {
  svg_path.Point(trig.cos_degrees(degrees), trig.sin_degrees(degrees))
}

/// Return the clockwise SVG heading of a vector in degrees from positive X.
///
/// `0` points right, `90` points down, `180` points left, and `270` points up.
/// The result is in `[0, 360)`. A zero vector has heading `0`.
pub fn heading(vector: svg_path.Point) -> Float {
  case number.is_zero(vector.x) && number.is_zero(vector.y) {
    True -> 0.0
    False -> {
      let degrees = trig.atan2_degrees(vector.y, vector.x)
      let turns = float.floor(degrees /. 360.0)
      let normalized = degrees -. turns *. 360.0
      let normalized = case normalized <. 0.0 {
        True -> normalized +. 360.0
        False -> normalized
      }
      canonical_turn_endpoint(normalized)
    }
  }
}

/// Return the clockwise aperture in degrees from one vector to another.
///
/// The result is in `[0, 360)`. Equal headings have aperture `0`. Since
/// `heading` assigns the zero vector a heading of `0`, this function does the
/// same when either input is zero.
pub fn clockwise_aperture(
  from from: svg_path.Point,
  to to: svg_path.Point,
) -> Float {
  let difference = heading(to) -. heading(from)
  let aperture = case difference <. 0.0 {
    True -> difference +. 360.0
    False -> difference
  }
  canonical_turn_endpoint(aperture)
}

// A small negative angle is representable near zero, but adding 360 can round
// to exactly 360: Float spacing is coarser at that magnitude. Apply this after
// the final arithmetic in both heading and aperture (the latter can introduce
// the same rounding independently). No epsilon: representable angles below
// 360 remain unchanged; only the excluded upper endpoint maps back to zero.
fn canonical_turn_endpoint(degrees: Float) -> Float {
  case degrees >=. 360.0 {
    True -> 0.0
    False -> degrees
  }
}

/// Add two points as vectors.
pub fn add(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.Point(a.x +. b.x, a.y +. b.y)
}

/// Subtract `b` from `a` as vectors.
pub fn subtract(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.Point(a.x -. b.x, a.y -. b.y)
}

/// Return `0 - point`.
pub fn negate(point: svg_path.Point) -> svg_path.Point {
  svg_path.Point(0.0 -. point.x, 0.0 -. point.y)
}

/// Scale a point as a vector.
pub fn scale(point: svg_path.Point, by factor: Float) -> svg_path.Point {
  svg_path.Point(point.x *. factor, point.y *. factor)
}

/// Return the dot product of two points as vectors.
pub fn dot(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.x +. a.y *. b.y
}

/// Return the 2D cross product of two points as vectors.
pub fn cross(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.y -. a.y *. b.x
}

/// Return the squared Euclidean norm of a point as a vector.
pub fn norm_squared(point: svg_path.Point) -> Float {
  dot(point, point)
}

/// Return the Euclidean norm of a point as a vector.
pub fn norm(point: svg_path.Point) -> Float {
  number.hypot(point.x, point.y)
}

/// Return the squared distance between two points.
pub fn distance_squared(a: svg_path.Point, b: svg_path.Point) -> Float {
  subtract(a, b) |> norm_squared
}

/// Return the distance between two points.
pub fn distance(a: svg_path.Point, b: svg_path.Point) -> Float {
  number.hypot(a.x -. b.x, a.y -. b.y)
}

/// Return the midpoint between two points.
pub fn midpoint(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  lerp(a, b, t: 0.5)
}

/// Linearly interpolate from `a` to `b`.
///
/// `t: 0.0` returns `a`, `t: 1.0` returns `b`, and values outside that range
/// extrapolate.
pub fn lerp(
  a: svg_path.Point,
  b: svg_path.Point,
  t t: Float,
) -> svg_path.Point {
  // Preserve the supplied endpoints without cancellation or overflowing b-a.
  case number.is_zero(t), t == 1.0 {
    True, _ -> a
    _, True -> b
    _, _ ->
      svg_path.Point(lerp_coordinate(a.x, b.x, t), lerp_coordinate(a.y, b.y, t))
  }
}

fn lerp_coordinate(a: Float, b: Float, t: Float) -> Float {
  // Opposite-sign endpoints can overflow b-a even though any point between
  // them is representable. Weighted terms cannot overflow for 0 < t < 1,
  // and their opposite signs make their sum safe as well.
  case
    t >. 0.0
    && t <. 1.0
    && { { a <. 0.0 && b >. 0.0 } || { a >. 0.0 && b <. 0.0 } }
  {
    True -> a *. { 1.0 -. t } +. b *. t
    False -> a +. { b -. a } *. t
  }
}

/// Return a unit vector with the same direction as `point`.
/// Returns `Error(Nil)` for a zero vector. Finite nonzero vectors are scaled
/// before computing their length to avoid intermediate overflow or underflow.
pub fn normalize(point: svg_path.Point) -> Result(svg_path.Point, Nil) {
  let largest =
    float.max(float.absolute_value(point.x), float.absolute_value(point.y))
  case number.is_zero(largest) {
    True -> Error(Nil)
    False -> {
      // Divide coordinates directly: the reciprocal of a subnormal scale can
      // overflow even though each coordinate divided by that scale is bounded.
      let scaled = svg_path.Point(point.x /. largest, point.y /. largest)
      let length = norm(scaled)
      Ok(svg_path.Point(scaled.x /. length, scaled.y /. length))
    }
  }
}

/// Project `point` onto `onto`.
/// Returns `Error(Nil)` for a zero target vector or a non-finite result.
pub fn project(
  point point: svg_path.Point,
  onto onto: svg_path.Point,
) -> Result(svg_path.Point, Nil) {
  use unit <- result.try(normalize(onto))
  let x_contribution = point.x *. unit.x
  let y_contribution = point.y *. unit.y
  // Distribute the final multiplication before adding: the scalar projection
  // can overflow even when both coordinates of the vector result are finite.
  // Do not rescale the source: that could erase its smaller coordinate.
  use x <- result.try(number.checked_sum(
    x_contribution *. unit.x,
    y_contribution *. unit.x,
  ))
  use y <- result.try(number.checked_sum(
    x_contribution *. unit.y,
    y_contribution *. unit.y,
  ))
  Ok(svg_path.Point(x, y))
}

/// Return the scalar projection of `point` onto `onto`.
/// Returns `Error(Nil)` for a zero target vector or a non-finite result.
pub fn scalar_projection(
  point point: svg_path.Point,
  onto onto: svg_path.Point,
) -> Result(Float, Nil) {
  use unit <- result.try(normalize(onto))
  number.checked_sum(point.x *. unit.x, point.y *. unit.y)
}

/// Rotate a point as a vector by 90 degrees clockwise.
pub fn rotate_clockwise(point: svg_path.Point) -> svg_path.Point {
  svg_path.Point(0.0 -. point.y, point.x)
}

/// Rotate a point as a vector by 90 degrees counterclockwise.
pub fn rotate_counterclockwise(point: svg_path.Point) -> svg_path.Point {
  svg_path.Point(point.y, 0.0 -. point.x)
}

/// Return whether two points are within a Euclidean distance tolerance.
pub fn near(
  a: svg_path.Point,
  b: svg_path.Point,
  tolerance tolerance: Float,
) -> Bool {
  case tolerance >=. 0.0 && number.is_finite(tolerance) {
    False -> False
    True -> {
      // A difference that overflows is necessarily outside any finite tolerance.
      case
        number.checked_sum(a.x, 0.0 -. b.x),
        number.checked_sum(a.y, 0.0 -. b.y)
      {
        Ok(dx), Ok(dy) -> {
          case number.is_zero(tolerance) {
            True -> number.is_zero(dx) && number.is_zero(dy)
            False -> {
              // Reject outside the coordinate box before dividing, so neither
              // ratios nor their squares can overflow. Do not square tolerance.
              float.absolute_value(dx) <=. tolerance
              && float.absolute_value(dy) <=. tolerance
              && {
                let x = dx /. tolerance
                let y = dy /. tolerance
                x *. x +. y *. y <=. 1.0
              }
            }
          }
        }
        _, _ -> False
      }
    }
  }
}
