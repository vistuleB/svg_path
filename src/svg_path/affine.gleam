//// Low-level two-dimensional affine matrix helpers.
////
//// Matrices use SVG's six-value affine form `matrix(a b c d e f)` and are
//// applied to column vectors: `x' = a*x + c*y + e`,
//// `y' = b*x + d*y + f`.

import gleam/float
import gleam/list
import gleam/result
import svg_path/internal/number
import svg_path/trig

/// A two-dimensional affine transform in SVG's six-value matrix form.
pub type Affine {
  Affine(a: Float, b: Float, c: Float, d: Float, e: Float, f: Float)
}

/// Failures while constructing a transform from point correspondences.
pub type Error {
  /// The source pair has zero separation in the scaled calculation.
  DegenerateSourcePair
  /// The source triple has zero determinant in the calculation, for example
  /// when its points are collinear or repeated.
  DegenerateSourceTriple
  /// Construction produced a non-finite denominator or matrix coefficient.
  NonFiniteTransform
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
/// Positive angles rotate visually clockwise in SVG coordinates (y down).
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
/// Returns `DegenerateSourcePair` for zero computed source separation, or
/// `NonFiniteTransform` when construction produces non-finite values.
pub fn point_pair_similarity(
  source_start source_start: #(Float, Float),
  source_end source_end: #(Float, Float),
  target_start target_start: #(Float, Float),
  target_end target_end: #(Float, Float),
) -> Result(Affine, Error) {
  number.with_arithmetic_errors(
    fn() {
      do_point_pair_similarity(
        source_start,
        source_end,
        target_start,
        target_end,
      )
    },
    NonFiniteTransform,
  )
}

fn do_point_pair_similarity(
  source_start: #(Float, Float),
  source_end: #(Float, Float),
  target_start: #(Float, Float),
  target_end: #(Float, Float),
) -> Result(Affine, Error) {
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
  case number.is_zero(denominator) {
    True -> Error(DegenerateSourcePair)
    False -> {
      use _ <- result.try(finite_denominator(denominator))
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
        False -> Error(NonFiniteTransform)
      }
    }
  }
}

/// Find an affine transform mapping one point triple to another.
///
/// Points are represented as raw coordinate tuples.
/// Returns `DegenerateSourceTriple` for a zero computed source determinant,
/// or `NonFiniteTransform` when construction produces non-finite values.
pub fn point_triple_map(
  source_a source_a: #(Float, Float),
  source_b source_b: #(Float, Float),
  source_c source_c: #(Float, Float),
  target_a target_a: #(Float, Float),
  target_b target_b: #(Float, Float),
  target_c target_c: #(Float, Float),
) -> Result(Affine, Error) {
  number.with_arithmetic_errors(
    fn() {
      do_point_triple_map(
        source_a,
        source_b,
        source_c,
        target_a,
        target_b,
        target_c,
      )
    },
    NonFiniteTransform,
  )
}

fn do_point_triple_map(
  source_a: #(Float, Float),
  source_b: #(Float, Float),
  source_c: #(Float, Float),
  target_a: #(Float, Float),
  target_b: #(Float, Float),
  target_c: #(Float, Float),
) -> Result(Affine, Error) {
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
  // Do not divide by zero: Gleam's zero-division behavior can otherwise yield
  // a finite matrix even though these correspondences do not determine one.
  use _ <- result.try(case number.is_zero(denominator) {
    True -> Error(DegenerateSourceTriple)
    False -> finite_denominator(denominator)
  })
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
    False -> Error(NonFiniteTransform)
  }
}

fn finite_denominator(denominator: Float) -> Result(Nil, Error) {
  case number.is_finite(denominator) {
    True -> Ok(Nil)
    False -> Error(NonFiniteTransform)
  }
}

/// Algebraic factor order (the rightmost factor acts on a point first).
/// Each variant contains exactly one translation, rotation, x-shear and scale.
pub type DecompositionOrder {
  TranslationRotationShearXScale
  TranslationRotationScaleShearX
  TranslationShearXRotationScale
  TranslationShearXScaleRotation
  TranslationScaleRotationShearX
  TranslationScaleShearXRotation
  RotationTranslationShearXScale
  RotationTranslationScaleShearX
  RotationShearXTranslationScale
  RotationShearXScaleTranslation
  RotationScaleTranslationShearX
  RotationScaleShearXTranslation
  ShearXTranslationRotationScale
  ShearXTranslationScaleRotation
  ShearXRotationTranslationScale
  ShearXRotationScaleTranslation
  ShearXScaleTranslationRotation
  ShearXScaleRotationTranslation
  ScaleTranslationRotationShearX
  ScaleTranslationShearXRotation
  ScaleRotationTranslationShearX
  ScaleRotationShearXTranslation
  ScaleShearXTranslationRotation
  ScaleShearXRotationTranslation
}

/// Numerical factors with their algebraic order retained for recomposition.
/// `shear_x` is the coefficient in `[[1,h],[0,1]]`, not a skew angle.
/// Rotation is in degrees. See `decompose_with_order` for sign conventions.
pub type Decomposition {
  Decomposition(
    order: DecompositionOrder,
    translation_x: Float,
    translation_y: Float,
    rotation_degrees: Float,
    shear_x: Float,
    scale_x: Float,
    scale_y: Float,
  )
}

/// Failures while factoring an affine matrix in a requested order.
pub type DecompositionError {
  /// The requested order has no finite real factorization under the computed
  /// rank/solvability conditions, including incompatible singular translation.
  NoFactorizationInOrder(order: DecompositionOrder)
  /// Input or a required factor/intermediate is not finite.
  DecompositionNonFinite
  /// Numerical range or conditioning prevented certified reconstruction.
  DecompositionUnstable
}

type LinearOrder {
  Rhs
  Rsh
  Srh
  Shr
  Hsr
  Hrs
}

type Factor {
  RotationFactor
  ShearFactor
  ScaleFactor
}

fn order_parts(order: DecompositionOrder) -> #(LinearOrder, Int) {
  case order {
    TranslationRotationShearXScale -> #(Rhs, 0)
    TranslationRotationScaleShearX -> #(Rsh, 0)
    TranslationShearXRotationScale -> #(Hrs, 0)
    TranslationShearXScaleRotation -> #(Hsr, 0)
    TranslationScaleRotationShearX -> #(Srh, 0)
    TranslationScaleShearXRotation -> #(Shr, 0)
    RotationTranslationShearXScale -> #(Rhs, 1)
    RotationTranslationScaleShearX -> #(Rsh, 1)
    RotationShearXTranslationScale -> #(Rhs, 2)
    RotationShearXScaleTranslation -> #(Rhs, 3)
    RotationScaleTranslationShearX -> #(Rsh, 2)
    RotationScaleShearXTranslation -> #(Rsh, 3)
    ShearXTranslationRotationScale -> #(Hrs, 1)
    ShearXTranslationScaleRotation -> #(Hsr, 1)
    ShearXRotationTranslationScale -> #(Hrs, 2)
    ShearXRotationScaleTranslation -> #(Hrs, 3)
    ShearXScaleTranslationRotation -> #(Hsr, 2)
    ShearXScaleRotationTranslation -> #(Hsr, 3)
    ScaleTranslationRotationShearX -> #(Srh, 1)
    ScaleTranslationShearXRotation -> #(Shr, 1)
    ScaleRotationTranslationShearX -> #(Srh, 2)
    ScaleRotationShearXTranslation -> #(Srh, 3)
    ScaleShearXTranslationRotation -> #(Shr, 2)
    ScaleShearXRotationTranslation -> #(Shr, 3)
  }
}

fn linear_factors(order: LinearOrder) -> List(Factor) {
  case order {
    Rhs -> [RotationFactor, ShearFactor, ScaleFactor]
    Rsh -> [RotationFactor, ScaleFactor, ShearFactor]
    Srh -> [ScaleFactor, RotationFactor, ShearFactor]
    Shr -> [ScaleFactor, ShearFactor, RotationFactor]
    Hsr -> [ShearFactor, ScaleFactor, RotationFactor]
    Hrs -> [ShearFactor, RotationFactor, ScaleFactor]
  }
}

/// Factor using the default algebraic order `T * R * Hx * S`.
/// For invertible matrices x-scale is positive; y-scale carries reflections.
pub fn decompose(
  transform: Affine,
) -> Result(Decomposition, DecompositionError) {
  decompose_with_order(transform, order: TranslationRotationShearXScale)
}

/// Factor in a requested algebraic order, without falling back to another order.
///
/// RHS and RSH use positive x-scale; their reversed counterparts SHR and HSR
/// use positive y-scale. For SRH, x-scale is positive and the valid quadratic
/// branch with the smallest absolute rotation is preferred (then signed angle).
/// HRS uses the dual convention with positive y-scale. Degenerate branches
/// use zero shear where possible and nonnegative remaining scale. Rotation lies in
/// (-180,180], with signed zero canonicalized. These are deterministic choices,
/// not continuity guarantees for animation or an enumeration of all solutions.
///
/// All six coefficients are checked by recomposition. Each linear column and
/// the translation vector must have relative max-norm error at most 1e-12;
/// an exactly zero column/vector must reconstruct as zero. This backward-error
/// bound does not bound relative error in ill-conditioned factors. No geometric
/// tolerance is used to snap small scales to zero. Computed rank and quadratic
/// discriminant tests are floating-point tests, not exact arithmetic proofs.
///
/// Singular maps are supported when the order permits them. Translation after
/// a singular scale must lie in the image of the factors to its left. One free
/// translation coordinate is set to zero, using the largest matrix entry as
/// pivot. Near quadratic double roots are tried and accepted only if certified.
/// Consequently, `Ok` certifies a nearby reconstruction, not exact algebraic
/// solvability: a slightly negative computed discriminant can be accepted within
/// a relative boundary allowance of 1e-14. A clearly negative discriminant is
/// rejected. Rank lost through normalization underflow is a numerical failure;
/// cancellation in rank tests is still not an exact singularity certificate.
/// Finite extreme inputs may return a numerical error instead of factors.
pub fn decompose_with_order(
  transform: Affine,
  order order: DecompositionOrder,
) -> Result(Decomposition, DecompositionError) {
  number.with_arithmetic_errors(
    fn() {
      case is_finite(transform) {
        False -> Error(DecompositionNonFinite)
        True -> {
          let #(linear, position) = order_parts(order)
          use candidates <- result.try(linear_candidates(
            transform,
            order,
            linear,
          ))
          try_candidates(
            candidates,
            transform,
            linear,
            position,
            DecompositionUnstable,
          )
        }
      }
    },
    DecompositionNonFinite,
  )
}

fn base(
  order: DecompositionOrder,
  angle: Float,
  shear: Float,
  sx: Float,
  sy: Float,
) -> Decomposition {
  Decomposition(
    order,
    0.0,
    0.0,
    canonical_angle(angle),
    number.normalize_zero(shear),
    number.normalize_zero(sx),
    number.normalize_zero(sy),
  )
}

fn canonical_angle(angle: Float) -> Float {
  case angle <=. -180.0 {
    True -> angle +. 360.0
    False if angle >. 180.0 -> angle -. 360.0
    False -> number.normalize_zero(angle)
  }
}

// F(A) = J transpose(A) J reverses products, preserves R and Hx, and swaps
// the scales. This reduces six linear orders to three without matrix inversion.
fn linear_candidates(
  m: Affine,
  order: DecompositionOrder,
  linear: LinearOrder,
) -> Result(List(Decomposition), DecompositionError) {
  case linear {
    Rhs | Rsh -> triangular_candidates(m, order, linear == Rhs)
    Srh -> middle_rotation_candidates(m, order)
    Shr | Hsr | Hrs -> {
      let dual = Affine(m.d, m.b, m.c, m.a, 0.0, 0.0)
      let core = case linear {
        Shr -> Rhs
        Hsr -> Rsh
        _ -> Srh
      }
      use candidates <- result.try(linear_candidates(dual, order, core))
      Ok(
        list.map(candidates, fn(f) {
          Decomposition(..f, scale_x: f.scale_y, scale_y: f.scale_x)
        }),
      )
    }
  }
}

// An entry lost during normalization is not evidence of exact rank deficiency.
// Cancellation between nonzero products is still subject
// to the documented floating-point rank test.
fn check_normalized_entries(
  entries: List(#(Float, Float)),
) -> Result(Nil, DecompositionError) {
  case
    list.any(entries, fn(pair) {
      !number.is_zero(pair.0) && number.is_zero(pair.1)
    })
  {
    True -> Error(DecompositionUnstable)
    False -> Ok(Nil)
  }
}

fn triangular_candidates(
  m: Affine,
  order: DecompositionOrder,
  shear_before_scale: Bool,
) -> Result(List(Decomposition), DecompositionError) {
  let first = float.max(float.absolute_value(m.a), float.absolute_value(m.b))
  let second = float.max(float.absolute_value(m.c), float.absolute_value(m.d))
  case number.is_zero(first), number.is_zero(second) {
    True, True -> Ok([base(order, 0.0, 0.0, 0.0, 0.0)])
    True, False ->
      Ok([
        base(
          order,
          trig.atan2_degrees(0.0 -. m.c, m.d),
          0.0,
          0.0,
          number.hypot(m.c, m.d),
        ),
      ])
    False, True ->
      Ok([
        base(
          order,
          trig.atan2_degrees(m.b, m.a),
          0.0,
          number.hypot(m.a, m.b),
          0.0,
        ),
      ])
    False, False -> {
      let x = m.a /. first
      let y = m.b /. first
      let norm = number.hypot(x, y)
      let u = x /. norm
      let v = y /. norm
      let c = m.c /. second
      let d = m.d /. second
      let perpendicular = u *. d -. v *. c
      use _ <- result.try(case number.is_zero(perpendicular) {
        True ->
          check_normalized_entries([
            #(m.a, x),
            #(m.b, y),
            #(m.c, c),
            #(m.d, d),
          ])
        False -> Ok(Nil)
      })
      let parallel = u *. c +. v *. d
      case shear_before_scale && number.is_zero(perpendicular) {
        True -> Error(NoFactorizationInOrder(order))
        False -> {
          let sx = first *. norm
          let sy = perpendicular *. second
          case !number.is_zero(perpendicular) && number.is_zero(sy) {
            True -> Error(DecompositionUnstable)
            False -> {
              let shear = case shear_before_scale {
                True -> parallel /. perpendicular
                False -> { parallel *. second } /. sx
              }
              Ok([base(order, trig.atan2_degrees(y, x), shear, sx, sy)])
            }
          }
        }
      }
    }
  }
}

fn middle_rotation_candidates(
  m: Affine,
  order: DecompositionOrder,
) -> Result(List(Decomposition), DecompositionError) {
  let top = float.max(float.absolute_value(m.a), float.absolute_value(m.c))
  let bottom = float.max(float.absolute_value(m.b), float.absolute_value(m.d))
  case number.is_zero(top), number.is_zero(bottom) {
    True, True -> Ok([base(order, 0.0, 0.0, 0.0, 0.0)])
    True, False ->
      Ok([
        base(
          order,
          trig.atan2_degrees(m.b, m.d),
          0.0,
          0.0,
          number.hypot(m.b, m.d),
        ),
      ])
    False, True ->
      Ok([
        base(
          order,
          trig.atan2_degrees(0.0 -. m.c, m.a),
          0.0,
          number.hypot(m.a, m.c),
          0.0,
        ),
      ])
    False, False -> {
      // Normalize rows independently: determinant and a*b then share a scale.
      let a = m.a /. top
      let c = m.c /. top
      let b = m.b /. bottom
      let d = m.d /. bottom
      let det = a *. d -. b *. c
      use _ <- result.try(case number.is_zero(det) {
        True ->
          check_normalized_entries([
            #(m.a, a),
            #(m.b, b),
            #(m.c, c),
            #(m.d, d),
          ])
        False -> Ok(Nil)
      })
      case number.is_zero(det) {
        True -> Error(NoFactorizationInOrder(order))
        False ->
          case number.is_zero(m.a), number.is_zero(m.b) {
            True, _ -> {
              let sign = case m.c >. 0.0 {
                True -> -1.0
                False -> 1.0
              }
              Ok([
                base(
                  order,
                  sign *. 90.0,
                  m.d /. m.b,
                  float.absolute_value(m.c),
                  m.b /. sign,
                ),
              ])
            }
            _, True -> {
              let sign = case m.a >. 0.0 {
                True -> 1.0
                False -> -1.0
              }
              Ok([
                base(
                  order,
                  case sign >. 0.0 {
                    True -> 0.0
                    False -> 180.0
                  },
                  m.c /. m.a,
                  float.absolute_value(m.a),
                  m.d /. sign,
                ),
              ])
            }
            False, False -> {
              let k = a *. b
              let twice_k = 2.0 *. float.absolute_value(k)
              let abs_det = float.absolute_value(det)
              let gap = abs_det -. twice_k
              let boundary_allowance = 1.0e-14 *. float.max(abs_det, twice_k)
              case number.is_zero(k) {
                True -> Error(DecompositionUnstable)
                False if gap <. 0.0 -. boundary_allowance ->
                  Error(NoFactorizationInOrder(order))
                False -> {
                  let assert Ok(root) =
                    float.square_root(
                      float.max(0.0, gap) *. { abs_det +. twice_k },
                    )
                  let denominator =
                    det
                    +. case det <. 0.0 {
                      True -> 0.0 -. root
                      False -> root
                    }
                  // The small tangent root is 2*k/denominator; swapping the
                  // homogeneous coordinates gives its reciprocal without overflow.
                  let angle1 = trig.atan2_degrees(2.0 *. k, denominator)
                  let angle2 = trig.atan2_degrees(denominator, 2.0 *. k)
                  let first =
                    number.with_arithmetic_errors(
                      fn() {
                        middle_rotation_factors(m, order, angle1, a, b, c, d)
                      },
                      DecompositionNonFinite,
                    )
                  let second =
                    number.with_arithmetic_errors(
                      fn() {
                        middle_rotation_factors(m, order, angle2, a, b, c, d)
                      },
                      DecompositionNonFinite,
                    )
                  order_candidates(first, second)
                }
              }
            }
          }
      }
    }
  }
}

fn order_candidates(
  first: Result(Decomposition, DecompositionError),
  second: Result(Decomposition, DecompositionError),
) -> Result(List(Decomposition), DecompositionError) {
  case first, second {
    Error(error), Error(_) -> Error(error)
    Ok(f), Error(_) | Error(_), Ok(f) -> Ok([f])
    Ok(first), Ok(second) -> {
      let a = float.absolute_value(first.rotation_degrees)
      let b = float.absolute_value(second.rotation_degrees)
      case
        a <. b
        || { a == b && first.rotation_degrees <=. second.rotation_degrees }
      {
        True -> Ok([first, second])
        False -> Ok([second, first])
      }
    }
  }
}

fn middle_rotation_factors(
  m: Affine,
  order: DecompositionOrder,
  angle: Float,
  a: Float,
  b: Float,
  c: Float,
  d: Float,
) -> Result(Decomposition, DecompositionError) {
  let angle = case { m.a <. 0.0 } != { trig.cos_degrees(angle) <. 0.0 } {
    True -> canonical_angle(angle +. 180.0)
    False -> canonical_angle(angle)
  }
  let cosine = trig.cos_degrees(angle)
  let sine = trig.sin_degrees(angle)
  case number.is_zero(cosine) || number.is_zero(sine) {
    True -> Error(DecompositionUnstable)
    False -> {
      let shear = case float.absolute_value(a) >=. float.absolute_value(b) {
        True -> c /. a +. sine /. cosine
        False -> d /. b -. cosine /. sine
      }
      // Recover each row scale from its larger coefficient. Dividing by a
      // nearly zero sine/cosine magnifies angle roundoff near quarter turns.
      let top_right = cosine *. shear -. sine
      let bottom_right = sine *. shear +. cosine
      let sx = case
        float.absolute_value(cosine) >=. float.absolute_value(top_right)
      {
        True -> m.a /. cosine
        False -> m.c /. top_right
      }
      let sy = case
        float.absolute_value(sine) >=. float.absolute_value(bottom_right)
      {
        True -> m.b /. sine
        False -> m.d /. bottom_right
      }
      Ok(base(order, angle, shear, sx, sy))
    }
  }
}

/// Recompose using the stored algebraic order. Like raw matrix constructors,
/// this does not validate user-supplied factors or catch arithmetic overflow.
pub fn recompose(factors: Decomposition) -> Affine {
  let #(linear, position) = order_parts(factors.order)
  let m = recompose_linear(factors, linear)
  let prefix = list.take(linear_factors(linear), position)
  let #(e, f) =
    apply_factors(prefix, factors, factors.translation_x, factors.translation_y)
  Affine(..m, e:, f:)
}

fn recompose_linear(f: Decomposition, order: LinearOrder) -> Affine {
  case order {
    Shr | Hsr | Hrs -> {
      let core = case order {
        Shr -> Rhs
        Hsr -> Rsh
        _ -> Srh
      }
      let m =
        recompose_linear(
          Decomposition(..f, scale_x: f.scale_y, scale_y: f.scale_x),
          core,
        )
      Affine(m.d, m.b, m.c, m.a, 0.0, 0.0)
    }
    _ -> {
      let c = trig.cos_degrees(f.rotation_degrees)
      let s = trig.sin_degrees(f.rotation_degrees)
      case order {
        Rhs | Rsh -> {
          let q =
            f.shear_x
            *. case order {
              Rhs -> f.scale_y
              _ -> f.scale_x
            }
          Affine(
            c *. f.scale_x,
            s *. f.scale_x,
            c *. q -. s *. f.scale_y,
            s *. q +. c *. f.scale_y,
            0.0,
            0.0,
          )
        }
        _ -> {
          let a = f.scale_x *. c
          let b = f.scale_y *. s
          Affine(
            a,
            b,
            a *. f.shear_x -. f.scale_x *. s,
            b *. f.shear_x +. f.scale_y *. c,
            0.0,
            0.0,
          )
        }
      }
    }
  }
}

fn apply_factor(
  factor: Factor,
  f: Decomposition,
  x: Float,
  y: Float,
) -> #(Float, Float) {
  case factor {
    RotationFactor -> {
      let c = trig.cos_degrees(f.rotation_degrees)
      let s = trig.sin_degrees(f.rotation_degrees)
      #(c *. x -. s *. y, s *. x +. c *. y)
    }
    ShearFactor -> #(x +. f.shear_x *. y, y)
    ScaleFactor -> #(f.scale_x *. x, f.scale_y *. y)
  }
}

fn apply_factors(
  factors: List(Factor),
  f: Decomposition,
  x: Float,
  y: Float,
) -> #(Float, Float) {
  case factors {
    [] -> #(x, y)
    [first, ..rest] -> {
      let #(x, y) = apply_factors(rest, f, x, y)
      apply_factor(first, f, x, y)
    }
  }
}

fn inverse_factors(
  factors: List(Factor),
  f: Decomposition,
  x: Float,
  y: Float,
) -> #(Float, Float) {
  case factors {
    [] -> #(x, y)
    [first, ..rest] -> {
      let #(x, y) = case first {
        RotationFactor ->
          apply_factor(
            RotationFactor,
            Decomposition(..f, rotation_degrees: 0.0 -. f.rotation_degrees),
            x,
            y,
          )
        ShearFactor -> #(x -. f.shear_x *. y, y)
        ScaleFactor -> #(x /. f.scale_x, y /. f.scale_y)
      }
      inverse_factors(rest, f, x, y)
    }
  }
}

fn with_translation(
  f: Decomposition,
  m: Affine,
  linear: LinearOrder,
  position: Int,
) -> Result(Decomposition, DecompositionError) {
  let prefix = list.take(linear_factors(linear), position)
  let singular =
    list.contains(prefix, ScaleFactor)
    && { number.is_zero(f.scale_x) || number.is_zero(f.scale_y) }
  use translation <- result.try(case singular {
    False -> Ok(inverse_factors(prefix, f, m.e, m.f))
    True -> {
      let #(a, b) = apply_factors(prefix, f, 1.0, 0.0)
      let #(c, d) = apply_factors(prefix, f, 0.0, 1.0)
      case is_finite(Affine(a, b, c, d, 0.0, 0.0)) {
        True -> singular_translation(a, b, c, d, m.e, m.f, f.order)
        False -> Error(DecompositionNonFinite)
      }
    }
  })
  let #(x, y) = translation
  Ok(Decomposition(..f, translation_x: x, translation_y: y))
}

fn singular_translation(
  a: Float,
  b: Float,
  c: Float,
  d: Float,
  e: Float,
  f: Float,
  order: DecompositionOrder,
) -> Result(#(Float, Float), DecompositionError) {
  let first = float.max(float.absolute_value(a), float.absolute_value(b))
  let second = float.max(float.absolute_value(c), float.absolute_value(d))
  let zero = number.is_zero(first)
  let #(x, y) = case first >=. second {
    True if zero -> #(0.0, 0.0)
    True -> #(
      case float.absolute_value(a) >=. float.absolute_value(b) {
        True -> e /. a
        False -> f /. b
      },
      0.0,
    )
    False -> #(0.0, case float.absolute_value(c) >=. float.absolute_value(d) {
      True -> e /. c
      False -> f /. d
    })
  }
  use _ <- result.try(case number.is_finite(x) && number.is_finite(y) {
    True -> Ok(Nil)
    False -> Error(DecompositionNonFinite)
  })
  case decomposition_column_matches(e, f, a *. x +. c *. y, b *. x +. d *. y) {
    True -> Ok(#(x, y))
    False -> Error(NoFactorizationInOrder(order))
  }
}

fn try_candidates(
  candidates: List(Decomposition),
  m: Affine,
  linear: LinearOrder,
  position: Int,
  last_error: DecompositionError,
) -> Result(Decomposition, DecompositionError) {
  case candidates {
    [] -> Error(last_error)
    [first, ..rest] -> {
      let attempt =
        number.with_arithmetic_errors(
          fn() {
            use _ <- result.try(case decomposition_is_finite(first) {
              True -> Ok(Nil)
              False -> Error(DecompositionNonFinite)
            })
            use f <- result.try(with_translation(first, m, linear, position))
            let rebuilt = recompose(f)
            case is_finite(rebuilt) && decomposition_is_finite(f) {
              False -> Error(DecompositionNonFinite)
              True ->
                case
                  decomposition_column_matches(m.a, m.b, rebuilt.a, rebuilt.b)
                  && decomposition_column_matches(
                    m.c,
                    m.d,
                    rebuilt.c,
                    rebuilt.d,
                  )
                  && decomposition_column_matches(
                    m.e,
                    m.f,
                    rebuilt.e,
                    rebuilt.f,
                  )
                {
                  True -> Ok(f)
                  False -> Error(DecompositionUnstable)
                }
            }
          },
          DecompositionNonFinite,
        )
      case attempt {
        Ok(f) -> Ok(f)
        Error(error) -> try_candidates(rest, m, linear, position, error)
      }
    }
  }
}

fn decomposition_is_finite(f: Decomposition) -> Bool {
  number.is_finite(f.translation_x)
  && number.is_finite(f.translation_y)
  && number.is_finite(f.rotation_degrees)
  && number.is_finite(f.shear_x)
  && number.is_finite(f.scale_x)
  && number.is_finite(f.scale_y)
}

fn decomposition_column_matches(
  a: Float,
  b: Float,
  x: Float,
  y: Float,
) -> Bool {
  let scale = float.max(float.absolute_value(a), float.absolute_value(b))
  case number.is_zero(scale) {
    True -> number.is_zero(x) && number.is_zero(y)
    False ->
      float.absolute_value(a /. scale -. x /. scale) <=. 1.0e-12
      && float.absolute_value(b /. scale -. y /. scale) <=. 1.0e-12
  }
}
