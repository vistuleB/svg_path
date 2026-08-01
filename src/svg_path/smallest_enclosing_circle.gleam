//// Deterministic smallest-enclosing-circle geometry for point sets.

import gleam/float
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import svg_path
import svg_path/point

@internal
pub type EnclosingCircle {
  EnclosingCircle(center: svg_path.Point, radius_squared: Float)
}

/// Return the smallest circle containing a non-empty point set.
///
/// Input is sorted first, so permutations produce the same sequence of
/// support decisions. Exact duplicate points are discarded. The returned
/// squared radius is recomputed as the greatest squared distance from the
/// selected center to any input point.
@internal
pub fn points(samples: List(svg_path.Point)) -> Result(EnclosingCircle, Nil) {
  let samples = samples |> list.sort(compare_points) |> unique_points([])
  case samples {
    [] -> Error(Nil)
    [only] -> Ok(point_circle(only))
    [first, second] -> Ok(two_point_circle(first, second))
    [first, ..rest] -> {
      let circle =
        enclosing_loop(rest, processed: [first], circle: point_circle(first))
      Ok(circle_with_exact_radius(circle, samples))
    }
  }
}

fn enclosing_loop(
  remaining: List(svg_path.Point),
  processed processed: List(svg_path.Point),
  circle circle: EnclosingCircle,
) -> EnclosingCircle {
  case remaining {
    [] -> circle
    [sample, ..rest] -> {
      let circle = case contains(circle, sample) {
        True -> circle
        False -> enclosing_with_one(processed, sample)
      }
      enclosing_loop(rest, processed: [sample, ..processed], circle:)
    }
  }
}

fn enclosing_with_one(
  processed: List(svg_path.Point),
  first: svg_path.Point,
) -> EnclosingCircle {
  enclosing_with_one_loop(
    list.reverse(processed),
    seen: [],
    first:,
    circle: point_circle(first),
  )
}

fn enclosing_with_one_loop(
  remaining: List(svg_path.Point),
  seen seen: List(svg_path.Point),
  first first: svg_path.Point,
  circle circle: EnclosingCircle,
) -> EnclosingCircle {
  case remaining {
    [] -> circle
    [second, ..rest] -> {
      let circle = case contains(circle, second) {
        True -> circle
        False -> enclosing_with_two(seen, first, second)
      }
      enclosing_with_one_loop(rest, seen: [second, ..seen], first:, circle:)
    }
  }
}

fn enclosing_with_two(
  processed: List(svg_path.Point),
  first: svg_path.Point,
  second: svg_path.Point,
) -> EnclosingCircle {
  enclosing_with_two_loop(
    list.reverse(processed),
    first,
    second,
    two_point_circle(first, second),
  )
}

fn enclosing_with_two_loop(
  remaining: List(svg_path.Point),
  first: svg_path.Point,
  second: svg_path.Point,
  circle: EnclosingCircle,
) -> EnclosingCircle {
  case remaining {
    [] -> circle
    [third, ..rest] -> {
      let circle = case contains(circle, third) {
        True -> circle
        False -> three_point_circle(first, second, third)
      }
      enclosing_with_two_loop(rest, first, second, circle)
    }
  }
}

fn point_circle(sample: svg_path.Point) -> EnclosingCircle {
  EnclosingCircle(center: sample, radius_squared: 0.0)
}

fn two_point_circle(
  first: svg_path.Point,
  second: svg_path.Point,
) -> EnclosingCircle {
  case first == second {
    True -> point_circle(first)
    False -> {
      let center = midpoint(first, second)
      EnclosingCircle(
        center:,
        radius_squared: point.distance_squared(center, first),
      )
    }
  }
}

fn three_point_circle(
  first: svg_path.Point,
  second: svg_path.Point,
  third: svg_path.Point,
) -> EnclosingCircle {
  let pairs = [
    two_point_circle(first, second),
    two_point_circle(first, third),
    two_point_circle(second, third),
  ]
  case smallest_containing(pairs, [first, second, third], None) {
    Some(circle) -> circle
    None -> circumcircle(first, second, third)
  }
}

fn smallest_containing(
  candidates: List(EnclosingCircle),
  samples: List(svg_path.Point),
  best: Option(EnclosingCircle),
) -> Option(EnclosingCircle) {
  case candidates {
    [] -> best
    [candidate, ..rest] -> {
      let best = case list.all(samples, contains(candidate, _)) {
        False -> best
        True ->
          case best {
            None -> Some(candidate)
            Some(previous) ->
              case compare_circles(candidate, previous) == order.Lt {
                True -> Some(candidate)
                False -> best
              }
          }
      }
      smallest_containing(rest, samples, best)
    }
  }
}

fn circumcircle(
  first: svg_path.Point,
  second: svg_path.Point,
  third: svg_path.Point,
) -> EnclosingCircle {
  let denominator =
    2.0
    *. {
      first.x
      *. { second.y -. third.y }
      +. second.x
      *. { third.y -. first.y }
      +. third.x
      *. { first.y -. second.y }
    }
  case denominator == 0.0 {
    True -> farthest_pair_circle(first, second, third)
    False -> {
      let first_norm = first.x *. first.x +. first.y *. first.y
      let second_norm = second.x *. second.x +. second.y *. second.y
      let third_norm = third.x *. third.x +. third.y *. third.y
      let center =
        svg_path.Point(
          x: {
            first_norm
            *. { second.y -. third.y }
            +. second_norm
            *. { third.y -. first.y }
            +. third_norm
            *. { first.y -. second.y }
          }
            /. denominator,
          y: {
            first_norm
            *. { third.x -. second.x }
            +. second_norm
            *. { first.x -. third.x }
            +. third_norm
            *. { second.x -. first.x }
          }
            /. denominator,
        )
      EnclosingCircle(
        center:,
        radius_squared: point.distance_squared(center, first),
      )
    }
  }
}

fn farthest_pair_circle(
  first: svg_path.Point,
  second: svg_path.Point,
  third: svg_path.Point,
) -> EnclosingCircle {
  [
    two_point_circle(first, second),
    two_point_circle(first, third),
    two_point_circle(second, third),
  ]
  |> list.sort(by: compare_circles)
  |> list.last
  |> result.unwrap(point_circle(first))
}

fn contains(circle: EnclosingCircle, sample: svg_path.Point) -> Bool {
  let EnclosingCircle(center:, radius_squared:) = circle
  let slack =
    float.max(0.000000000000000000000001, radius_squared *. 0.000000000001)
  point.distance_squared(center, sample) <=. radius_squared +. slack
}

fn circle_with_exact_radius(
  circle: EnclosingCircle,
  samples: List(svg_path.Point),
) -> EnclosingCircle {
  let EnclosingCircle(center:, ..) = circle
  let radius_squared =
    samples
    |> list.map(point.distance_squared(center, _))
    |> list.fold(0.0, float.max)
  EnclosingCircle(center:, radius_squared:)
}

fn midpoint(first: svg_path.Point, second: svg_path.Point) -> svg_path.Point {
  svg_path.Point(
    x: first.x +. { second.x -. first.x } /. 2.0,
    y: first.y +. { second.y -. first.y } /. 2.0,
  )
}

fn unique_points(
  sorted: List(svg_path.Point),
  unique: List(svg_path.Point),
) -> List(svg_path.Point) {
  case sorted, unique {
    [], _ -> list.reverse(unique)
    [first, ..rest], [previous, ..] if first == previous ->
      unique_points(rest, unique)
    [first, ..rest], _ -> unique_points(rest, [first, ..unique])
  }
}

fn compare_points(
  first: svg_path.Point,
  second: svg_path.Point,
) -> order.Order {
  case float.compare(first.x, second.x) {
    order.Eq -> float.compare(first.y, second.y)
    ordering -> ordering
  }
}

fn compare_circles(
  first: EnclosingCircle,
  second: EnclosingCircle,
) -> order.Order {
  let EnclosingCircle(center: first_center, radius_squared: first_radius) =
    first
  let EnclosingCircle(center: second_center, radius_squared: second_radius) =
    second
  case float.compare(first_radius, second_radius) {
    order.Eq -> compare_points(first_center, second_center)
    ordering -> ordering
  }
}
