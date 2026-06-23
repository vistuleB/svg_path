import gleam/float
import gleam/list
import gleam_community/maths
import svg_path

const epsilon = 0.000000000001

pub type SupportError {
  NotCubic
  PointError(svg_path.Error)
}

pub fn support(
  segment: svg_path.Segment,
  degrees degrees: Float,
) -> Result(#(Float, svg_path.Point), SupportError) {
  case segment {
    svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      let direction = angle_direction(degrees)

      best_candidate(
        segment,
        direction,
        candidates(start, control1, control2, end, direction),
      )
    }
    _ -> Error(NotCubic)
  }
}

fn candidates(
  start: svg_path.Point,
  control1: svg_path.Point,
  control2: svg_path.Point,
  end: svg_path.Point,
  direction: svg_path.Point,
) -> List(Float) {
  let a =
    add(
      add(scale(start, -1.0), scale(control1, 3.0)),
      add(scale(control2, -3.0), end),
    )
  let b =
    add(scale(start, 3.0), add(scale(control1, -6.0), scale(control2, 3.0)))
  let c = add(scale(control1, 3.0), scale(start, -3.0))

  quadratic_roots(
    3.0 *. dot(a, direction),
    2.0 *. dot(b, direction),
    dot(c, direction),
  )
  |> list.filter(fn(t) { t >=. 0.0 && t <=. 1.0 })
  |> list.append([0.0, 1.0])
}

fn best_candidate(
  segment: svg_path.Segment,
  direction: svg_path.Point,
  candidates: List(Float),
) -> Result(#(Float, svg_path.Point), SupportError) {
  case candidates {
    [] -> Error(NotCubic)
    [first, ..rest] -> {
      use first_point <- result_try_point(svg_path.segment_point(
        segment,
        at: first,
      ))
      best_candidate_loop(
        segment,
        direction,
        rest,
        best_t: first,
        best_point: first_point,
      )
    }
  }
}

fn best_candidate_loop(
  segment: svg_path.Segment,
  direction: svg_path.Point,
  candidates: List(Float),
  best_t best_t: Float,
  best_point best_point: svg_path.Point,
) -> Result(#(Float, svg_path.Point), SupportError) {
  case candidates {
    [] -> Ok(#(best_t, best_point))
    [t, ..rest] -> {
      use point <- result_try_point(svg_path.segment_point(segment, at: t))
      case dot(point, direction) >. dot(best_point, direction) {
        True ->
          best_candidate_loop(
            segment,
            direction,
            rest,
            best_t: t,
            best_point: point,
          )
        False ->
          best_candidate_loop(
            segment,
            direction,
            rest,
            best_t: best_t,
            best_point: best_point,
          )
      }
    }
  }
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

fn square_root(value: Float) -> Float {
  let assert Ok(root) = float.square_root(value)
  root
}

fn angle_direction(degrees: Float) -> svg_path.Point {
  let radians = degrees *. maths.pi() /. 180.0

  svg_path.point(maths.cos(radians), maths.sin(radians))
}

fn dot(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.x +. a.y *. b.y
}

fn add(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.point(a.x +. b.x, a.y +. b.y)
}

fn scale(point: svg_path.Point, factor: Float) -> svg_path.Point {
  svg_path.point(point.x *. factor, point.y *. factor)
}

fn result_try_point(
  result: Result(svg_path.Point, svg_path.Error),
  next: fn(svg_path.Point) -> Result(a, SupportError),
) -> Result(a, SupportError) {
  case result {
    Ok(point) -> next(point)
    Error(error) -> Error(PointError(error))
  }
}
