//// Deterministic smallest-enclosing-circle geometry for point sets.

import gleam/float
import gleam/list
import gleam/order
import gleam/result
import svg_path
import svg_path/internal/number
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
        // Both fixed points must stay on the boundary. The smallest circle of
        // just this triple may instead use a different diameter and discard
        // an earlier support, invalidating the already-processed points.
        False -> circumcircle(first, second, third)
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
        radius_squared: float.max(
          point.distance_squared(center, first),
          point.distance_squared(center, second),
        ),
      )
    }
  }
}

fn circumcircle(
  first: svg_path.Point,
  second: svg_path.Point,
  third: svg_path.Point,
) -> EnclosingCircle {
  // Work relative to the first point. Expanding the formula in absolute
  // coordinates loses precision when a small configuration is translated far
  // from the origin.
  let ax = second.x -. first.x
  let ay = second.y -. first.y
  let bx = third.x -. first.x
  let by = third.y -. first.y
  let denominator = 2.0 *. { ax *. by -. ay *. bx }
  case number.is_zero(denominator) {
    True -> farthest_pair_circle(first, second, third)
    False -> {
      let a_norm = ax *. ax +. ay *. ay
      let b_norm = bx *. bx +. by *. by
      let center =
        svg_path.Point(
          x: first.x +. { a_norm *. by -. b_norm *. ay } /. denominator,
          y: first.y +. { ax *. b_norm -. bx *. a_norm } /. denominator,
        )
      // Roundoff can give the three support points slightly different squared
      // distances. Include all of them rather than immediately rejecting one
      // of the circle's own supports on a later containment check.
      circle_with_exact_radius(EnclosingCircle(center:, radius_squared: 0.0), [
        first,
        second,
        third,
      ])
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
  point.distance_squared(center, sample) <=. radius_squared
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
