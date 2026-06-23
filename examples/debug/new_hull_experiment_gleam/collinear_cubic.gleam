import gleam/float
import gleam/list
import svg_path
import svg_path/convex_hull

const epsilon = 0.000000001

pub type Error {
  NotCubic
  NotCollinear
}

pub fn hull_pieces(
  segment: svg_path.Segment,
) -> Result(List(convex_hull.HullPiece), Error) {
  case segment {
    svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      case is_collinear(start, control1, control2, end) {
        False -> Error(NotCollinear)
        True -> {
          let #(min_t, max_t) = scalar_extrema(start, control1, control2, end)

          Ok([
            convex_hull.HullLine(min_t, max_t),
            convex_hull.HullLine(max_t, min_t),
          ])
        }
      }
    }
    _ -> Error(NotCubic)
  }
}

fn is_collinear(
  start: svg_path.Point,
  control1: svg_path.Point,
  control2: svg_path.Point,
  end: svg_path.Point,
) -> Bool {
  let axis = best_axis(start, control1, control2, end)
  let scale = float.max(length(axis), 1.0)

  float.absolute_value(cross(axis, subtract(control1, start)))
  <=. epsilon *. scale
  && float.absolute_value(cross(axis, subtract(control2, start)))
  <=. epsilon *. scale
}

fn scalar_extrema(
  start: svg_path.Point,
  control1: svg_path.Point,
  control2: svg_path.Point,
  end: svg_path.Point,
) -> #(Float, Float) {
  let axis = best_axis(start, control1, control2, end)
  let p0 = dot(start, axis)
  let p1 = dot(control1, axis)
  let p2 = dot(control2, axis)
  let p3 = dot(end, axis)
  let a = 0.0 -. p0 +. 3.0 *. p1 -. 3.0 *. p2 +. p3
  let b = 3.0 *. p0 -. 6.0 *. p1 +. 3.0 *. p2
  let c = 0.0 -. 3.0 *. p0 +. 3.0 *. p1
  let candidates =
    quadratic_roots(3.0 *. a, 2.0 *. b, c)
    |> list.filter(fn(t) { t >=. 0.0 && t <=. 1.0 })
    |> list.append([0.0, 1.0])
    |> list.map(fn(t) { #(t, scalar_value(p0, p1, p2, p3, t)) })

  case candidates {
    [] -> #(0.0, 0.0)
    [first, ..rest] -> extrema_loop(rest, min: first, max: first)
  }
}

fn extrema_loop(
  values: List(#(Float, Float)),
  min min_value: #(Float, Float),
  max max_value: #(Float, Float),
) -> #(Float, Float) {
  case values {
    [] -> {
      let #(min_t, _) = min_value
      let #(max_t, _) = max_value
      #(min_t, max_t)
    }
    [value, ..rest] -> {
      let #(_, scalar) = value
      let #(_, min_scalar) = min_value
      let #(_, max_scalar) = max_value
      extrema_loop(
        rest,
        min: case scalar <. min_scalar {
          True -> value
          False -> min_value
        },
        max: case scalar >. max_scalar {
          True -> value
          False -> max_value
        },
      )
    }
  }
}

fn scalar_value(p0: Float, p1: Float, p2: Float, p3: Float, t: Float) -> Float {
  let mt = 1.0 -. t

  p0
  *. mt
  *. mt
  *. mt
  +. 3.0
  *. p1
  *. mt
  *. mt
  *. t
  +. 3.0
  *. p2
  *. mt
  *. t
  *. t
  +. p3
  *. t
  *. t
  *. t
}

fn quadratic_roots(a: Float, b: Float, c: Float) -> List(Float) {
  case float.absolute_value(a) <=. epsilon {
    True -> linear_roots(b, c)
    False -> {
      let discriminant = b *. b -. 4.0 *. a *. c

      case discriminant <. 0.0 {
        True -> []
        False -> {
          let root = square_root(discriminant)
          [
            { 0.0 -. b -. root } /. { 2.0 *. a },
            { 0.0 -. b +. root } /. { 2.0 *. a },
          ]
        }
      }
    }
  }
}

fn linear_roots(a: Float, b: Float) -> List(Float) {
  case float.absolute_value(a) <=. epsilon {
    True -> []
    False -> [{ 0.0 -. b } /. a]
  }
}

fn best_axis(
  start: svg_path.Point,
  control1: svg_path.Point,
  control2: svg_path.Point,
  end: svg_path.Point,
) -> svg_path.Point {
  [subtract(end, start), subtract(control1, start), subtract(control2, start)]
  |> longest_axis(svg_path.point(1.0, 0.0))
}

fn longest_axis(
  axes: List(svg_path.Point),
  best: svg_path.Point,
) -> svg_path.Point {
  case axes {
    [] -> best
    [axis, ..rest] -> {
      case length(axis) >. length(best) {
        True -> longest_axis(rest, axis)
        False -> longest_axis(rest, best)
      }
    }
  }
}

fn subtract(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.point(a.x -. b.x, a.y -. b.y)
}

fn dot(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.x +. a.y *. b.y
}

fn cross(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.y -. a.y *. b.x
}

fn length(a: svg_path.Point) -> Float {
  square_root(dot(a, a))
}

fn square_root(value: Float) -> Float {
  let assert Ok(root) = float.square_root(value)
  root
}
