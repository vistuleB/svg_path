//// Directional congruency checks for path geometry.

import gleam/float
import gleam/list
import svg_path
import svg_path/ellipse
import svg_path/transform

type IndexedPoint {
  IndexedPoint(source: svg_path.Point, target: svg_path.Point)
}

type PointPair {
  PointPair(
    source_a: svg_path.Point,
    source_b: svg_path.Point,
    target_a: svg_path.Point,
    target_b: svg_path.Point,
    distance_squared: Float,
  )
}

/// Find a translation, rotation, and uniform scale mapping one ordered point
/// list to another.
///
/// Empty lists and lists with different lengths return `Error(Nil)`. A
/// one-point source list uses a translation. For two or more source points, the
/// candidate transform is built from the farthest-apart source point pair and
/// the target points at the corresponding indexes, then every mapped source
/// point is checked against the corresponding target point.
pub fn points(
  source source: List(svg_path.Point),
  target target: List(svg_path.Point),
  tolerance tolerance: Float,
) -> Result(transform.Matrix, Nil) {
  case indexed_points(source, target, accumulated: []) {
    Error(_) -> Error(Nil)
    Ok([]) -> Error(Nil)
    Ok([only]) -> {
      let matrix =
        transform.translate(
          x: only.target.x -. only.source.x,
          y: only.target.y -. only.source.y,
        )

      check_points([only], matrix, tolerance)
    }
    Ok([first, second, ..rest] as indexed) -> {
      let pair = farthest_pair([first, second, ..rest])

      case pair.distance_squared <=. 0.0 {
        True -> {
          let matrix =
            transform.translate(
              x: first.target.x -. first.source.x,
              y: first.target.y -. first.source.y,
            )

          check_points(indexed, matrix, tolerance)
        }
        False -> {
          case
            transform.point_pair_map(
              source_start: pair.source_a,
              source_end: pair.source_b,
              target_start: pair.target_a,
              target_end: pair.target_b,
              tolerance:,
            )
          {
            Error(_) -> Error(Nil)
            Ok(matrix) -> check_points(indexed, matrix, tolerance)
          }
        }
      }
    }
  }
}

/// Find a translation, rotation, and uniform scale mapping one segment to
/// another segment of the same constructor.
///
/// This is a directional, tolerance-based check. `Ok(transform)` means the
/// returned transform maps `source` to `target` within `tolerance` under this
/// module's semantic segment comparison. `Error(Nil)` means no such transform
/// was found.
pub fn segment(
  source source: svg_path.Segment,
  target target: svg_path.Segment,
  tolerance tolerance: Float,
) -> Result(transform.Matrix, Nil) {
  case source, target {
    svg_path.Line(start: source_start, end: source_end),
      svg_path.Line(start: target_start, end: target_end)
    -> {
      transform.point_pair_map(
        source_start:,
        source_end:,
        target_start:,
        target_end:,
        tolerance:,
      )
    }

    svg_path.QuadraticBezier(
      start: source_start,
      control: source_control,
      end: source_end,
    ),
      svg_path.QuadraticBezier(
        start: target_start,
        control: target_control,
        end: target_end,
      )
    -> {
      let pair =
        quadratic_pair(
          source_start:,
          source_control:,
          source_end:,
          target_start:,
          target_control:,
          target_end:,
        )

      map_and_check(source, target, pair, tolerance)
    }

    svg_path.CubicBezier(
      start: source_start,
      control1: source_control1,
      control2: source_control2,
      end: source_end,
    ),
      svg_path.CubicBezier(
        start: target_start,
        control1: target_control1,
        control2: target_control2,
        end: target_end,
      )
    -> {
      let pair =
        cubic_pair(
          source_start:,
          source_control1:,
          source_control2:,
          source_end:,
          target_start:,
          target_control1:,
          target_control2:,
          target_end:,
        )

      map_and_check(source, target, pair, tolerance)
    }

    svg_path.Arc(..), svg_path.Arc(..) -> arc_segment(source, target, tolerance)

    _, _ -> Error(Nil)
  }
}

fn map_and_check(
  source: svg_path.Segment,
  target: svg_path.Segment,
  pair: PointPair,
  tolerance: Float,
) -> Result(transform.Matrix, Nil) {
  case
    transform.point_pair_map(
      source_start: pair.source_a,
      source_end: pair.source_b,
      target_start: pair.target_a,
      target_end: pair.target_b,
      tolerance:,
    )
  {
    Error(_) -> Error(Nil)
    Ok(matrix) -> {
      case transform.segment(source, by: matrix) {
        Error(_) -> Error(Nil)
        Ok(mapped) -> {
          case same_segment(mapped, target, tolerance) {
            True -> Ok(matrix)
            False -> Error(Nil)
          }
        }
      }
    }
  }
}

fn indexed_points(
  source: List(svg_path.Point),
  target: List(svg_path.Point),
  accumulated accumulated: List(IndexedPoint),
) -> Result(List(IndexedPoint), Nil) {
  case source, target {
    [], [] -> Ok(list.reverse(accumulated))
    [source_first, ..source_rest], [target_first, ..target_rest] -> {
      indexed_points(source_rest, target_rest, accumulated: [
        IndexedPoint(source: source_first, target: target_first),
        ..accumulated
      ])
    }
    _, _ -> Error(Nil)
  }
}

fn farthest_pair(points: List(IndexedPoint)) -> PointPair {
  let assert [first, second, ..] = points
  let initial = indexed_pair(first, second)

  farthest_pair_outer(points, initial)
}

fn farthest_pair_outer(
  points: List(IndexedPoint),
  best: PointPair,
) -> PointPair {
  case points {
    [] | [_] -> best
    [first, ..rest] -> {
      farthest_pair_outer(rest, farthest_pair_with(first, rest, best))
    }
  }
}

fn farthest_pair_with(
  point: IndexedPoint,
  rest: List(IndexedPoint),
  best: PointPair,
) -> PointPair {
  case rest {
    [] -> best
    [first, ..remaining] -> {
      farthest_pair_with(
        point,
        remaining,
        farther(best, indexed_pair(point, first)),
      )
    }
  }
}

fn indexed_pair(a: IndexedPoint, b: IndexedPoint) -> PointPair {
  pair(a.source, b.source, a.target, b.target)
}

fn check_points(
  points: List(IndexedPoint),
  matrix: transform.Matrix,
  tolerance: Float,
) -> Result(transform.Matrix, Nil) {
  case
    list.all(points, fn(point) {
      transform.point(point.source, by: matrix)
      |> points_within_tolerance(point.target, tolerance)
    })
  {
    True -> Ok(matrix)
    False -> Error(Nil)
  }
}

fn arc_segment(
  source: svg_path.Segment,
  target: svg_path.Segment,
  tolerance: Float,
) -> Result(transform.Matrix, Nil) {
  case svg_path.arc_center_data(source), svg_path.arc_center_data(target) {
    Ok(source_arc), Ok(target_arc) -> {
      let source_start = svg_path.segment_start(source)
      let target_start = svg_path.segment_start(target)
      let source_opposite =
        ellipse.point_at_angle(
          source_arc,
          angle: source_arc.start_angle +. 180.0,
        )
        |> from_ellipse_point
      let target_opposite =
        ellipse.point_at_angle(
          target_arc,
          angle: target_arc.start_angle +. 180.0,
        )
        |> from_ellipse_point

      let pair =
        PointPair(
          source_a: source_start,
          source_b: source_opposite,
          target_a: target_start,
          target_b: target_opposite,
          distance_squared: distance_squared(source_start, source_opposite),
        )

      map_and_check(source, target, pair, tolerance)
    }
    _, _ -> Error(Nil)
  }
}

fn quadratic_pair(
  source_start source_start: svg_path.Point,
  source_control source_control: svg_path.Point,
  source_end source_end: svg_path.Point,
  target_start target_start: svg_path.Point,
  target_control target_control: svg_path.Point,
  target_end target_end: svg_path.Point,
) -> PointPair {
  farther(
    farther(
      pair(source_start, source_control, target_start, target_control),
      pair(source_start, source_end, target_start, target_end),
    ),
    pair(source_control, source_end, target_control, target_end),
  )
}

fn cubic_pair(
  source_start source_start: svg_path.Point,
  source_control1 source_control1: svg_path.Point,
  source_control2 source_control2: svg_path.Point,
  source_end source_end: svg_path.Point,
  target_start target_start: svg_path.Point,
  target_control1 target_control1: svg_path.Point,
  target_control2 target_control2: svg_path.Point,
  target_end target_end: svg_path.Point,
) -> PointPair {
  farther(
    farther(
      farther(
        pair(source_start, source_control1, target_start, target_control1),
        pair(source_start, source_control2, target_start, target_control2),
      ),
      farther(
        pair(source_start, source_end, target_start, target_end),
        pair(source_control1, source_control2, target_control1, target_control2),
      ),
    ),
    farther(
      pair(source_control1, source_end, target_control1, target_end),
      pair(source_control2, source_end, target_control2, target_end),
    ),
  )
}

fn pair(
  source_a: svg_path.Point,
  source_b: svg_path.Point,
  target_a: svg_path.Point,
  target_b: svg_path.Point,
) -> PointPair {
  PointPair(
    source_a:,
    source_b:,
    target_a:,
    target_b:,
    distance_squared: distance_squared(source_a, source_b),
  )
}

fn farther(left: PointPair, right: PointPair) -> PointPair {
  case left.distance_squared >=. right.distance_squared {
    True -> left
    False -> right
  }
}

fn same_segment(
  actual: svg_path.Segment,
  expected: svg_path.Segment,
  tolerance: Float,
) -> Bool {
  case actual, expected {
    svg_path.Line(start: actual_start, end: actual_end),
      svg_path.Line(start: expected_start, end: expected_end)
    -> {
      points_within_tolerance(actual_start, expected_start, tolerance)
      && points_within_tolerance(actual_end, expected_end, tolerance)
    }

    svg_path.QuadraticBezier(
      start: actual_start,
      control: actual_control,
      end: actual_end,
    ),
      svg_path.QuadraticBezier(
        start: expected_start,
        control: expected_control,
        end: expected_end,
      )
    -> {
      points_within_tolerance(actual_start, expected_start, tolerance)
      && points_within_tolerance(actual_control, expected_control, tolerance)
      && points_within_tolerance(actual_end, expected_end, tolerance)
    }

    svg_path.CubicBezier(
      start: actual_start,
      control1: actual_control1,
      control2: actual_control2,
      end: actual_end,
    ),
      svg_path.CubicBezier(
        start: expected_start,
        control1: expected_control1,
        control2: expected_control2,
        end: expected_end,
      )
    -> {
      points_within_tolerance(actual_start, expected_start, tolerance)
      && points_within_tolerance(actual_control1, expected_control1, tolerance)
      && points_within_tolerance(actual_control2, expected_control2, tolerance)
      && points_within_tolerance(actual_end, expected_end, tolerance)
    }

    svg_path.Arc(
      start: actual_start,
      radius: actual_radius,
      x_axis_rotation: actual_rotation,
      large_arc: actual_large_arc,
      sweep: actual_sweep,
      end: actual_end,
    ),
      svg_path.Arc(
        start: expected_start,
        radius: expected_radius,
        x_axis_rotation: expected_rotation,
        large_arc: expected_large_arc,
        sweep: expected_sweep,
        end: expected_end,
      )
    -> {
      actual_large_arc == expected_large_arc
      && actual_sweep == expected_sweep
      && points_within_tolerance(actual_start, expected_start, tolerance)
      && points_within_tolerance(actual_radius, expected_radius, tolerance)
      && floats_within_tolerance(actual_rotation, expected_rotation, tolerance)
      && points_within_tolerance(actual_end, expected_end, tolerance)
    }

    _, _ -> False
  }
}

fn points_within_tolerance(
  a: svg_path.Point,
  b: svg_path.Point,
  tolerance: Float,
) -> Bool {
  case float.square_root(distance_squared(a, b)) {
    Ok(distance) -> distance <=. tolerance
    Error(_) -> False
  }
}

fn floats_within_tolerance(a: Float, b: Float, tolerance: Float) -> Bool {
  float.absolute_value(a -. b) <=. tolerance
}

fn distance_squared(a: svg_path.Point, b: svg_path.Point) -> Float {
  let dx = a.x -. b.x
  let dy = a.y -. b.y

  dx *. dx +. dy *. dy
}

fn from_ellipse_point(point: ellipse.Point) -> svg_path.Point {
  svg_path.point(point.x, point.y)
}
