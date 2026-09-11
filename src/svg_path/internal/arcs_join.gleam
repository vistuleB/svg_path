//// SVG 2 arcs join geometry, in coordinates local to the source corner.
//// See painting.html sections 13.5.5, 13.5.8 and 13.5.9. Radii are signed
//// along the visual left normal. Source curvature, not fitted cubic curvature,
//// determines the initial radii. All endpoints remain the healed endpoints.

import gleam/float
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import svg_path.{type Point, type Segment, Arc, Line, Point}
import svg_path/internal/number
import svg_path/internal/root
import svg_path/point as p
import svg_path/trig

@internal
pub type Continuation {
  Continuation(start: Point, tangent: Point, radius: Option(Float))
}

fn normal(c: Continuation) -> Point {
  p.rotate_90_counterclockwise(c.tangent)
}

fn center(c: Continuation, r: Float) -> Point {
  p.add(c.start, p.scale(normal(c), r))
}

fn sign(x: Float) -> Float {
  case x <. 0.0 {
    True -> -1.0
    False -> 1.0
  }
}

// Only compensate for arithmetic roundoff at tangency, not geometric gaps.
fn sqrt_roundoff(value: Float, scale: Float) -> Result(Float, Nil) {
  case value <. -1.0e-12 *. scale {
    True -> Error(Nil)
    False -> float.square_root(float.max(0.0, value))
  }
}

fn line_circle(a: Point, tangent: Point, c: Point, r: Float) -> List(Point) {
  let delta = p.subtract(c, a)
  let t = p.dot(delta, tangent)
  let h = p.cross(delta, tangent)
  case sqrt_roundoff(r *. r -. h *. h, r *. r +. h *. h) {
    Error(_) -> []
    Ok(v) -> [
      p.add(a, p.scale(tangent, t -. v)),
      p.add(a, p.scale(tangent, t +. v)),
    ]
  }
}

fn circle_circle(a: Point, ra: Float, b: Point, rb: Float) -> List(Point) {
  let delta = p.subtract(b, a)
  let d = p.norm(delta)
  case number.is_zero(d) {
    True -> []
    False -> {
      let x = { d *. d +. { ra -. rb } *. { ra +. rb } } /. { 2.0 *. d }
      case sqrt_roundoff(ra *. ra -. x *. x, ra *. ra +. x *. x) {
        Error(_) -> []
        Ok(y) -> {
          let axis = p.scale(delta, 1.0 /. d)
          let mid = p.add(a, p.scale(axis, x))
          let side = p.scale(p.rotate_90_counterclockwise(axis), y)
          [p.add(mid, side), p.subtract(mid, side)]
        }
      }
    }
  }
}

fn intersections(a: Continuation, b: Continuation) -> List(Point) {
  case a.radius, b.radius {
    Some(ra), Some(rb) ->
      circle_circle(
        center(a, ra),
        float.absolute_value(ra),
        center(b, rb),
        float.absolute_value(rb),
      )
    None, Some(rb) -> line_circle(a.start, a.tangent, center(b, rb), rb)
    Some(ra), None -> line_circle(b.start, b.tangent, center(a, ra), ra)
    None, None -> []
    // Caller delegates the straight/straight case to MiterClip.
  }
}

fn least(values: List(Float)) -> Result(Float, Nil) {
  values |> list.sort(float.compare) |> list.first
}

fn adjust_circle_line(
  circle: Continuation,
  line: Continuation,
  r: Float,
) -> Result(Continuation, Nil) {
  // Signed line distance of the center is h + s*r. Tangency requires
  // (h+s*r)^2=r^2; keep the original curvature sign and nearest radius.
  let h = p.cross(p.subtract(circle.start, line.start), line.tangent)
  let s = p.cross(normal(circle), line.tangent)
  use new_r <- result.try(
    root.quadratic(s *. s -. 1.0, 2.0 *. h *. s, h *. h)
    |> list.filter(fn(v) { number.is_finite(v) && v *. r >. 0.0 })
    |> list.sort(fn(x, y) {
      float.compare(float.absolute_value(x -. r), float.absolute_value(y -. r))
    })
    |> list.first,
  )
  Ok(Continuation(..circle, radius: Some(new_r)))
}

fn adjust(
  a: Continuation,
  b: Continuation,
) -> Result(#(Continuation, Continuation), Nil) {
  case a.radius, b.radius {
    Some(r), None -> {
      use a <- result.try(adjust_circle_line(a, b, r))
      Ok(#(a, b))
    }
    None, Some(r) -> {
      use b <- result.try(adjust_circle_line(b, a, r))
      Ok(#(a, b))
    }
    None, None -> Error(Nil)
    Some(ra), Some(rb) -> {
      let ar = float.absolute_value(ra)
      let br = float.absolute_value(rb)
      let delta = p.subtract(center(b, rb), center(a, ra))
      let separate = p.norm(delta) >. ar +. br
      // External tangency: grow both. Internal tangency: shrink the larger
      // and grow the smaller. Centers move on their endpoint normal rays.
      let da = case separate || ar <. br {
        True -> 1.0
        False -> -1.0
      }
      let db = case separate || br <. ar {
        True -> 1.0
        False -> -1.0
      }
      let v =
        p.subtract(
          p.scale(normal(b), sign(rb) *. db),
          p.scale(normal(a), sign(ra) *. da),
        )
      let target = case separate {
        True -> ar +. br
        False -> ar -. br
      }
      let slope = case separate {
        True -> da +. db
        False -> da -. db
      }
      use amount <- result.try(
        root.quadratic(
          p.dot(v, v) -. slope *. slope,
          2.0 *. { p.dot(delta, v) -. target *. slope },
          p.dot(delta, delta) -. target *. target,
        )
        |> list.filter(fn(x) {
          number.is_finite(x)
          && x >=. 0.0
          && ar +. da *. x >. 0.0
          && br +. db *. x >. 0.0
        })
        |> least,
      )
      Ok(#(
        Continuation(..a, radius: Some(sign(ra) *. { ar +. da *. amount })),
        Continuation(..b, radius: Some(sign(rb) *. { br +. db *. amount })),
      ))
    }
  }
}

fn angle(c: Continuation, tip: Point, forward: Bool) -> Float {
  let assert Some(r) = c.radius
  let origin = center(c, r)
  let a = p.subtract(c.start, origin)
  let b = p.subtract(tip, origin)
  let raw = trig.atan2_degrees(p.cross(a, b), p.dot(a, b))
  let clockwise = { r <. 0.0 } == forward
  case clockwise, raw >=. 0.0 {
    True, True | False, False -> float.absolute_value(raw)
    _, _ -> 360.0 -. float.absolute_value(raw)
  }
}

fn progress(c: Continuation, tip: Point, forward: Bool) -> Float {
  case c.radius {
    Some(_) -> angle(c, tip, forward)
    None ->
      p.dot(p.subtract(tip, c.start), c.tangent)
      *. case forward {
        True -> 1.0
        False -> -1.0
      }
  }
}

fn piece(c: Continuation, tip: Point, forward: Bool) -> List(Segment) {
  case p.near(c.start, tip, tolerance: 0.0) {
    True -> []
    False ->
      case c.radius {
        None -> [Line(c.start, tip)]
        Some(r) -> [
          Arc(
            c.start,
            Point(float.absolute_value(r), float.absolute_value(r)),
            0.0,
            angle(c, tip, forward) >. 180.0,
            { r <. 0.0 } == forward,
            tip,
          ),
        ]
      }
  }
}

fn assemble(
  a: Continuation,
  b: Continuation,
  at: Point,
  bt: Point,
) -> List(Segment) {
  list.append(
    piece(a, at, True),
    list.append(
      case p.near(at, bt, tolerance: 0.0) {
        True -> []
        False -> [Line(at, bt)]
      },
      piece(b, bt, False) |> list.reverse |> list.map(svg_path.segment_reverse),
    ),
  )
}

fn clip_point(
  c: Continuation,
  tip: Point,
  forward: Bool,
  origin: Point,
  axis: Point,
) -> Result(Point, Nil) {
  let candidates = case c.radius {
    None -> {
      let divisor = p.dot(c.tangent, axis)
      case number.is_zero(divisor) {
        True -> []
        False -> [
          p.add(
            c.start,
            p.scale(
              c.tangent,
              p.dot(p.subtract(origin, c.start), axis) /. divisor,
            ),
          ),
        ]
      }
    }
    Some(r) ->
      line_circle(origin, p.rotate_90_counterclockwise(axis), center(c, r), r)
  }
  let stop = progress(c, tip, forward)
  candidates
  |> list.filter(fn(q) {
    let t = progress(c, q, forward)
    t >=. 0.0 && t <=. stop +. 1.0e-9
  })
  |> list.sort(fn(x, y) {
    float.compare(progress(c, x, forward), progress(c, y, forward))
  })
  |> list.first
}

fn clipped(
  a: Continuation,
  b: Continuation,
  tip: Point,
  axis: Point,
  limit: Float,
) -> Result(List(Segment), Nil) {
  // Auxiliary circle through the pivot (local zero) and tip, tangent to the
  // outward angle bisector at the pivot. Its arc length, not chord length,
  // determines the clipping plane. The straight case is its exact limit.
  let n = p.rotate_90_counterclockwise(axis)
  let x = p.dot(tip, axis)
  let y = p.dot(tip, n)
  let #(extent, cut, tangent) = case number.is_zero(y) {
    True -> #(p.norm(tip), p.scale(axis, limit), axis)
    False -> {
      let r = p.dot(tip, tip) /. { 2.0 *. y }
      let theta = 2.0 *. trig.atan2_degrees(y, x)
      let phi = trig.radians_to_degrees(limit /. r)
      // 1-cos(phi) written as 2*sin(phi/2)^2 avoids cancellation.
      let half_sin = trig.sin_degrees(phi /. 2.0)
      #(
        float.absolute_value(r *. trig.degrees_to_radians(theta)),
        p.add(
          p.scale(axis, r *. trig.sin_degrees(phi)),
          p.scale(n, r *. 2.0 *. half_sin *. half_sin),
        ),
        p.add(
          p.scale(axis, trig.cos_degrees(phi)),
          p.scale(n, trig.sin_degrees(phi)),
        ),
      )
    }
  }
  case extent <=. limit {
    True -> Ok(assemble(a, b, tip, tip))
    False -> {
      // Low limits cannot shorten the already-emitted neighboring segments.
      case
        p.dot(p.subtract(a.start, cut), tangent) >. 0.0
        || p.dot(p.subtract(b.start, cut), tangent) >. 0.0
      {
        True -> Ok([Line(a.start, b.start)])
        False -> {
          use at <- result.try(clip_point(a, tip, True, cut, tangent))
          use bt <- result.try(clip_point(b, tip, False, cut, tangent))
          Ok(assemble(a, b, at, bt))
        }
      }
    }
  }
}

@internal
pub fn join(
  a: Continuation,
  b: Continuation,
  bisector: Point,
  limit: Float,
) -> Result(List(Segment), Nil) {
  use pair <- result.try(case intersections(a, b) {
    [] -> adjust(a, b)
    _ -> Ok(#(a, b))
  })
  let #(a, b) = pair
  use tip <- result.try(
    intersections(a, b)
    |> list.filter(fn(q) {
      number.is_finite(q.x)
      && number.is_finite(q.y)
      && progress(a, q, True) >=. 0.0
      && progress(b, q, False) >=. 0.0
    })
    |> list.sort(fn(x, y) { float.compare(p.dot(x, x), p.dot(y, y)) })
    |> list.first,
  )
  clipped(a, b, tip, bisector, limit)
}
