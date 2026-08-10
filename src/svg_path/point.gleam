//// Small helper library for the `svg_path.Point` type.

import gleam/float
import svg_path
import svg_path/trig

/// The unit vector pointing right.
pub const right = svg_path.Point(1.0, 0.0)

/// The unit vector pointing left.
pub const left = svg_path.Point(-1.0, 0.0)

/// The unit vector pointing up in SVG coordinates.
pub const up = svg_path.Point(0.0, -1.0)

/// The unit vector pointing down in SVG coordinates.
pub const down = svg_path.Point(0.0, 1.0)

/// Return the unit vector pointing at an SVG angle in degrees.
///
/// `0` points right, `90` points down, `180` points left, and `270` points up.
pub fn direction(degrees degrees: Float) -> svg_path.Point {
  svg_path.Point(trig.cos_degrees(degrees), trig.sin_degrees(degrees))
}

/// Return the clockwise SVG heading of a vector in degrees from positive X.
///
/// `0` points right, `90` points down, `180` points left, and `270` points up.
/// A zero vector has heading `0`.
pub fn heading(vector: svg_path.Point) -> Float {
  let degrees = trig.atan2_degrees(vector.y, vector.x)
  let turns = float.floor(degrees /. 360.0)
  let normalized = degrees -. turns *. 360.0
  case normalized <. 0.0 {
    True -> normalized +. 360.0
    False -> normalized
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
  case difference <. 0.0 {
    True -> difference +. 360.0
    False -> difference
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
  norm_squared(point) |> square_root
}

/// Return the squared distance between two points.
pub fn distance_squared(a: svg_path.Point, b: svg_path.Point) -> Float {
  subtract(a, b) |> norm_squared
}

/// Return the distance between two points.
pub fn distance(a: svg_path.Point, b: svg_path.Point) -> Float {
  distance_squared(a, b) |> square_root
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
  svg_path.Point(a.x +. { b.x -. a.x } *. t, a.y +. { b.y -. a.y } *. t)
}

/// Return a unit vector with the same direction as `point`.
pub fn normalize(point: svg_path.Point) -> Result(svg_path.Point, Nil) {
  case norm(point) {
    0.0 -> Error(Nil)
    length -> Ok(scale(point, by: 1.0 /. length))
  }
}

/// Project `point` onto `onto`.
pub fn project(
  point point: svg_path.Point,
  onto onto: svg_path.Point,
) -> Result(svg_path.Point, Nil) {
  let denominator = norm_squared(onto)
  case denominator {
    0.0 -> Error(Nil)
    _ -> Ok(scale(onto, by: dot(point, onto) /. denominator))
  }
}

/// Return the scalar projection of `point` onto `onto`.
pub fn scalar_projection(
  point point: svg_path.Point,
  onto onto: svg_path.Point,
) -> Result(Float, Nil) {
  case norm(onto) {
    0.0 -> Error(Nil)
    length -> Ok(dot(point, onto) /. length)
  }
}

/// Rotate a point as a vector by 90 degrees clockwise.
pub fn rotate_clockwise(point: svg_path.Point) -> svg_path.Point {
  svg_path.Point(point.y, 0.0 -. point.x)
}

/// Rotate a point as a vector by 90 degrees counterclockwise.
pub fn rotate_counterclockwise(point: svg_path.Point) -> svg_path.Point {
  svg_path.Point(0.0 -. point.y, point.x)
}

/// Return whether two points are within a Euclidean distance tolerance.
pub fn near(
  a: svg_path.Point,
  b: svg_path.Point,
  tolerance tolerance: Float,
) -> Bool {
  tolerance >=. 0.0
  && tolerance -. tolerance == 0.0
  && distance_squared(a, b) <=. tolerance *. tolerance
}

fn square_root(value: Float) -> Float {
  let assert Ok(root) = float.square_root(value)
  root
}
