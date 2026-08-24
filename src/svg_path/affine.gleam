//// Low-level two-dimensional affine matrix helpers.
////
//// Matrices use SVG's six-value affine form `matrix(a b c d e f)` and are
//// applied to column vectors: `x' = a*x + c*y + e`,
//// `y' = b*x + d*y + f`.

import gleam/float
import svg_path/internal/number
import svg_path/trig

/// A two-dimensional affine transform in SVG's six-value matrix form.
pub type Affine {
  Affine(a: Float, b: Float, c: Float, d: Float, e: Float, f: Float)
}

/// Create an affine matrix from SVG's six matrix values.
pub fn matrix(
  a a: Float,
  b b: Float,
  c c: Float,
  d d: Float,
  e e: Float,
  f f: Float,
) -> Affine {
  Affine(a:, b:, c:, d:, e:, f:)
}

/// Create an affine matrix from SVG's six matrix values as a tuple.
pub fn from_tuple(
  values: #(Float, Float, Float, Float, Float, Float),
) -> Affine {
  let #(a, b, c, d, e, f) = values
  matrix(a:, b:, c:, d:, e:, f:)
}

/// Return SVG's six matrix values as `#(a, b, c, d, e, f)`.
pub fn to_tuple(
  transform: Affine,
) -> #(Float, Float, Float, Float, Float, Float) {
  #(
    transform.a,
    transform.b,
    transform.c,
    transform.d,
    transform.e,
    transform.f,
  )
}

/// The identity transform.
pub fn identity() -> Affine {
  matrix(a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: 0.0)
}

/// Chain two transforms in application order.
///
/// `chain(first: a, then: b)` creates a matrix that applies `a` first and `b`
/// second. In algebraic matrix order, this is `b * a`.
pub fn chain(first first: Affine, then second: Affine) -> Affine {
  multiply(left: second, right: first)
}

/// Multiply two matrices in algebraic order.
///
/// `multiply(left: a, right: b)` returns `a * b`.
pub fn multiply(left left: Affine, right right: Affine) -> Affine {
  matrix(
    a: left.a *. right.a +. left.c *. right.b,
    b: left.b *. right.a +. left.d *. right.b,
    c: left.a *. right.c +. left.c *. right.d,
    d: left.b *. right.c +. left.d *. right.d,
    e: left.a *. right.e +. left.c *. right.f +. left.e,
    f: left.b *. right.e +. left.d *. right.f +. left.f,
  )
}

/// Create a matrix that applies a transform about a point.
pub fn about_point(
  transform transform: Affine,
  x x: Float,
  y y: Float,
) -> Affine {
  translate(x: 0.0 -. x, y: 0.0 -. y)
  |> chain(first: _, then: transform)
  |> chain(first: _, then: translate(x:, y:))
}

/// Create a translation matrix.
pub fn translate(x x: Float, y y: Float) -> Affine {
  matrix(a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: x, f: y)
}

/// Create a uniform scale matrix.
pub fn scale(factor factor: Float) -> Affine {
  scale_xy(x: factor, y: factor)
}

/// Create a non-uniform scale matrix.
pub fn scale_xy(x x: Float, y y: Float) -> Affine {
  matrix(a: x, b: 0.0, c: 0.0, d: y, e: 0.0, f: 0.0)
}

/// Create a rotation matrix from an angle in degrees.
pub fn rotate(degrees degrees: Float) -> Affine {
  let cosine = trig.cos_degrees(degrees)
  let sine = trig.sin_degrees(degrees)
  matrix(a: cosine, b: sine, c: 0.0 -. sine, d: cosine, e: 0.0, f: 0.0)
}

/// Create an x-axis skew matrix from an angle in degrees.
pub fn skew_x(degrees degrees: Float) -> Affine {
  matrix(a: 1.0, b: 0.0, c: trig.tan_degrees(degrees), d: 1.0, e: 0.0, f: 0.0)
}

/// Create a y-axis skew matrix from an angle in degrees.
pub fn skew_y(degrees degrees: Float) -> Affine {
  matrix(a: 1.0, b: trig.tan_degrees(degrees), c: 0.0, d: 1.0, e: 0.0, f: 0.0)
}

/// Apply the full affine matrix to raw coordinates.
pub fn point(transform: Affine, x x: Float, y y: Float) -> #(Float, Float) {
  #(
    transform.a *. x +. transform.c *. y +. transform.e,
    transform.b *. x +. transform.d *. y +. transform.f,
  )
}

/// Apply only the linear part of the matrix to raw coordinates.
pub fn linear_point(
  transform: Affine,
  x x: Float,
  y y: Float,
) -> #(Float, Float) {
  #(transform.a *. x +. transform.c *. y, transform.b *. x +. transform.d *. y)
}

/// Return the determinant of the linear part.
pub fn determinant(transform: Affine) -> Float {
  transform.a *. transform.d -. transform.b *. transform.c
}

/// Return true when all six matrix entries are finite.
pub fn is_finite(transform: Affine) -> Bool {
  number.is_finite(transform.a)
  && number.is_finite(transform.b)
  && number.is_finite(transform.c)
  && number.is_finite(transform.d)
  && number.is_finite(transform.e)
  && number.is_finite(transform.f)
}

/// Find a translation, rotation, and uniform scale mapping one point pair to
/// another.
///
/// Points are represented as raw coordinate tuples.
pub fn point_pair_similarity(
  source_start source_start: #(Float, Float),
  source_end source_end: #(Float, Float),
  target_start target_start: #(Float, Float),
  target_end target_end: #(Float, Float),
) -> Result(Affine, Nil) {
  let #(source_start_x, source_start_y) = source_start
  let #(source_end_x, source_end_y) = source_end
  let #(target_start_x, target_start_y) = target_start
  let #(target_end_x, target_end_y) = target_end
  let source_x = source_end_x -. source_start_x
  let source_y = source_end_y -. source_start_y
  let target_x = target_end_x -. target_start_x
  let target_y = target_end_y -. target_start_y
  let vector_scale =
    float.max(
      float.max(float.absolute_value(source_x), float.absolute_value(source_y)),
      float.max(float.absolute_value(target_x), float.absolute_value(target_y)),
    )
  let divisor = case vector_scale >. 0.0 {
    True -> vector_scale
    False -> 1.0
  }
  let source_x = source_x /. divisor
  let source_y = source_y /. divisor
  let target_x = target_x /. divisor
  let target_y = target_y /. divisor
  let denominator = source_x *. source_x +. source_y *. source_y
  case denominator == 0.0 {
    True -> Error(Nil)
    False -> {
      let a = { source_x *. target_x +. source_y *. target_y } /. denominator
      let b = { source_x *. target_y -. source_y *. target_x } /. denominator
      let c = 0.0 -. b
      let d = a
      let transform =
        matrix(
          a:,
          b:,
          c:,
          d:,
          e: target_start_x -. { a *. source_start_x +. c *. source_start_y },
          f: target_start_y -. { b *. source_start_x +. d *. source_start_y },
        )
      case is_finite(transform) {
        True -> Ok(transform)
        False -> Error(Nil)
      }
    }
  }
}

/// Find an affine transform mapping one point triple to another.
///
/// Points are represented as raw coordinate tuples.
pub fn point_triple_map(
  source_a source_a: #(Float, Float),
  source_b source_b: #(Float, Float),
  source_c source_c: #(Float, Float),
  target_a target_a: #(Float, Float),
  target_b target_b: #(Float, Float),
  target_c target_c: #(Float, Float),
) -> Result(Affine, Nil) {
  let #(source_a_x, source_a_y) = source_a
  let #(source_b_x, source_b_y) = source_b
  let #(source_c_x, source_c_y) = source_c
  let #(target_a_x, target_a_y) = target_a
  let #(target_b_x, target_b_y) = target_b
  let #(target_c_x, target_c_y) = target_c
  let source_ab_x = source_b_x -. source_a_x
  let source_ab_y = source_b_y -. source_a_y
  let source_ac_x = source_c_x -. source_a_x
  let source_ac_y = source_c_y -. source_a_y
  let target_ab_x = target_b_x -. target_a_x
  let target_ab_y = target_b_y -. target_a_y
  let target_ac_x = target_c_x -. target_a_x
  let target_ac_y = target_c_y -. target_a_y
  let denominator = source_ab_x *. source_ac_y -. source_ab_y *. source_ac_x
  let a =
    { target_ab_x *. source_ac_y -. target_ac_x *. source_ab_y } /. denominator
  let b =
    { target_ab_y *. source_ac_y -. target_ac_y *. source_ab_y } /. denominator
  let c =
    { target_ac_x *. source_ab_x -. target_ab_x *. source_ac_x } /. denominator
  let d =
    { target_ac_y *. source_ab_x -. target_ab_y *. source_ac_x } /. denominator
  let transform =
    matrix(
      a:,
      b:,
      c:,
      d:,
      e: target_a_x -. { a *. source_a_x +. c *. source_a_y },
      f: target_a_y -. { b *. source_a_x +. d *. source_a_y },
    )

  case is_finite(transform) {
    True -> Ok(transform)
    False -> Error(Nil)
  }
}
