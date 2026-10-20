//// Selective double-double SVG endpoint conversion. Internal, not an error bound.

import gleam/float
import gleam/int
import svg_path/internal/number
import svg_path/trig

type DD =
  #(Float, Float)

@internal
pub type Converted {
  Converted(
    cx: Float,
    cy: Float,
    rx: Float,
    ry: Float,
    start: Float,
    delta: Float,
  )
}

// The empirical cutoff and its conditioning estimate are documented in
// scripts/cavalier/ELLIPSE-PRECISION-THRESHOLD.md. Decide before radius correction.
@internal
pub fn convert(
  ax: Float,
  ay: Float,
  bx: Float,
  by: Float,
  rx: Float,
  ry: Float,
  rotation: Float,
  large: Bool,
  sweep: Bool,
) -> Result(Converted, Nil) {
  let magnitude =
    float.max(
      float.max(float.absolute_value(ax), float.absolute_value(ay)),
      float.max(
        float.max(float.absolute_value(bx), float.absolute_value(by)),
        float.max(rx, ry),
      ),
    )
  case
    !number.is_finite(magnitude)
    || !number.is_finite(rotation)
    || magnitude >. 1.0e150
    || magnitude <. 1.0e-150
    || rx <=. 0.0
    || ry <=. 0.0
    || rx /. magnitude <. 1.0e-30
    || ry /. magnitude <. 1.0e-30
  {
    True -> Error(Nil)
    False -> {
      let scale = power_scale(magnitude, 1.0)
      let ax = ax /. scale
      let ay = ay /. scale
      let bx = bx /. scale
      let by = by /. scale
      let rx = rx /. scale
      let ry = ry /. scale
      let dx = { ax -. bx } /. 2.0
      let dy = { ay -. by } /. 2.0
      let c = trig.cos_degrees(rotation)
      let s = trig.sin_degrees(rotation)
      case needed(dx, dy, rx, ry, c *. dx +. s *. dy, c *. dy -. s *. dx) {
        False -> Error(Nil)
        True -> solve(ax, ay, bx, by, rx, ry, rotation, large, sweep, scale)
      }
    }
  }
}

// Reuse the ordinary converter's rotated coordinates on the common fast path.
@internal
pub fn needed(
  dx: Float,
  dy: Float,
  rx: Float,
  ry: Float,
  x: Float,
  y: Float,
) -> Bool {
  let u = x /. rx
  let v = y /. ry
  let lambda = u *. u +. v *. v
  let reach = float.absolute_value(dx) +. float.absolute_value(dy)
  let k =
    float.max(
      1.0,
      lambda
        +. float.absolute_value(u)
        *. reach
        /. rx
        +. float.absolute_value(v)
        *. reach
        /. ry,
    )
  float.absolute_value(1.0 -. lambda) /. k /. k <=. 1.0e-8
}

fn power_scale(m: Float, scale: Float) -> Float {
  case m {
    m if m >. 1.0 -> power_scale(m /. 2.0, scale *. 2.0)
    m if m <. 0.5 -> power_scale(m *. 2.0, scale /. 2.0)
    _ -> scale
  }
}

fn solve(
  ax: Float,
  ay: Float,
  bx: Float,
  by: Float,
  rx: Float,
  ry: Float,
  rotation: Float,
  large: Bool,
  sweep: Bool,
  scale: Float,
) -> Result(Converted, Nil) {
  let #(s, c) = sincos(rotation)
  let dx = mul(dd(0.5), sub(dd(ax), dd(bx)))
  let dy = mul(dd(0.5), sub(dd(ay), dd(by)))
  let x = add(mul(c, dx), mul(s, dy))
  let y = sub(mul(c, dy), mul(s, dx))
  let rx = dd(rx)
  let ry = dd(ry)
  let rx2 = mul(rx, rx)
  let ry2 = mul(ry, ry)
  let den = add(mul(rx2, mul(y, y)), mul(ry2, mul(x, x)))
  let product = mul(rx2, ry2)
  let gap = sub(product, den)
  case !positive(den) || !positive(product) {
    True -> Error(Nil)
    False -> {
      let #(rx, ry, px, py) = case positive(gap) {
        True -> {
          let k = root(divide(gap, den))
          let k = case large == sweep {
            True -> neg(k)
            False -> k
          }
          #(
            rx,
            ry,
            divide(mul(mul(k, rx), y), ry),
            neg(divide(mul(mul(k, ry), x), rx)),
          )
        }
        False -> {
          let factor = case positive(neg(gap)) {
            True -> root(divide(den, product))
            False -> dd(1.0)
          }
          #(mul(rx, factor), mul(ry, factor), dd(0.0), dd(0.0))
        }
      }
      let cx =
        add(mul(dd(0.5), add(dd(ax), dd(bx))), sub(mul(c, px), mul(s, py)))
      let cy =
        add(mul(dd(0.5), add(dd(ay), dd(by))), add(mul(s, px), mul(c, py)))
      let ux = divide(sub(x, px), rx)
      let uy = divide(sub(y, py), ry)
      let vx = divide(sub(neg(x), px), rx)
      let vy = divide(sub(neg(y), py), ry)
      let start = trig.atan2_degrees(value(uy), value(ux))
      let delta =
        trig.atan2_degrees(
          value(sub(mul(ux, vy), mul(uy, vx))),
          value(add(mul(ux, vx), mul(uy, vy))),
        )
      let delta = case sweep, delta <. 0.0 {
        True, True -> delta +. 360.0
        False, False if delta >. 0.0 -> delta -. 360.0
        _, _ -> delta
      }
      Ok(Converted(
        value(cx) *. scale,
        value(cy) *. scale,
        value(rx) *. scale,
        value(ry) *. scale,
        start,
        delta,
      ))
    }
  }
}

fn dd(x: Float) -> DD {
  #(x, 0.0)
}

fn value(a: DD) -> Float {
  a.0 +. a.1
}

fn neg(a: DD) -> DD {
  #(0.0 -. a.0, 0.0 -. a.1)
}

fn positive(a: DD) -> Bool {
  a.0 >. 0.0 || { number.is_zero(a.0) && a.1 >. 0.0 }
}

fn sum(a: Float, b: Float) -> DD {
  let h = a +. b
  let v = h -. a
  #(h, { a -. { h -. v } } +. { b -. v })
}

fn product(a: Float, b: Float) -> DD {
  let h = a *. b
  let ca = 134_217_729.0 *. a
  let cb = 134_217_729.0 *. b
  let ah = ca -. { ca -. a }
  let bh = cb -. { cb -. b }
  let al = a -. ah
  let bl = b -. bh
  #(h, { { ah *. bh -. h } +. ah *. bl +. al *. bh } +. al *. bl)
}

fn add(a: DD, b: DD) -> DD {
  let s = sum(a.0, b.0)
  sum(s.0, s.1 +. a.1 +. b.1)
}

fn sub(a: DD, b: DD) -> DD {
  add(a, neg(b))
}

fn mul(a: DD, b: DD) -> DD {
  let p = product(a.0, b.0)
  sum(p.0, p.1 +. a.0 *. b.1 +. a.1 *. b.0 +. a.1 *. b.1)
}

fn divide(a: DD, b: DD) -> DD {
  let q = a.0 /. b.0
  let r = sub(a, mul(dd(q), b))
  let q2 = r.0 /. b.0
  let r = sub(r, mul(dd(q2), b))
  add(sum(q, q2), dd(value(r) /. b.0))
}

fn root(a: DD) -> DD {
  case number.is_zero(a.0) && number.is_zero(a.1) {
    True -> dd(0.0)
    False -> {
      let assert Ok(x) = float.square_root(a.0)
      let x = mul(dd(0.5), add(dd(x), divide(a, dd(x))))
      mul(dd(0.5), add(x, divide(a, x)))
    }
  }
}

fn sincos(rotation: Float) -> #(DD, DD) {
  let reduced = remainder(rotation, 360.0)
  let q = float.round(reduced /. 90.0) |> int.to_float
  let r = reduced -. q *. 90.0
  let x =
    divide(mul(dd(r), #(3.141592653589793, 1.2246467991473532e-16)), dd(180.0))
  let #(s, c) = taylor(neg(mul(x, x)), x, dd(1.0), x, dd(1.0), 1.0)
  let q = remainder(q +. 4.0, 4.0)
  case q {
    0.0 -> #(s, c)
    1.0 -> #(c, neg(s))
    2.0 -> #(neg(s), neg(c))
    _ -> #(neg(c), s)
  }
}

fn taylor(xx: DD, s: DD, c: DD, st: DD, ct: DD, n: Float) -> #(DD, DD) {
  case n >. 18.0 {
    True -> #(s, c)
    False -> {
      let st = divide(mul(st, xx), dd(2.0 *. n *. { 2.0 *. n +. 1.0 }))
      let ct = divide(mul(ct, xx), dd({ 2.0 *. n -. 1.0 } *. 2.0 *. n))
      taylor(xx, add(s, st), add(c, ct), st, ct, n +. 1.0)
    }
  }
}

@external(erlang, "math", "fmod")
@external(javascript, "../trig_ffi.mjs", "remainder")
fn remainder(value: Float, modulus: Float) -> Float
