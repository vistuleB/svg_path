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

type PointCloud {
  PointCloud(
    source: List(svg_path.Point),
    target: List(svg_path.Point),
    has_arc: Bool,
  )
}

/// Find a translation, rotation, and uniform scale mapping one ordered point
/// list to another.
///
/// Empty lists and lists with different lengths return `Error(Nil)`. A
/// one-point source list uses a translation. For two or more source points, the
/// candidate transform is built from a triple-sweep source point pair and the
/// target points at the corresponding positions, then every mapped source point
/// is checked against the corresponding target point.
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
      let pair = swept_pair([first, second, ..rest])

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
  case segment_points(source, target) {
    Error(_) -> Error(Nil)
    Ok(#(source_extra, target_extra, has_arc)) -> {
      let source_points = [svg_path.segment_start(source), ..source_extra]
      let target_points = [svg_path.segment_start(target), ..target_extra]

      case points(source: source_points, target: target_points, tolerance:) {
        Error(_) -> Error(Nil)
        Ok(matrix) -> {
          case has_arc {
            False -> Ok(matrix)
            True -> {
              case arc_field_match(source, target, matrix, tolerance) {
                True -> Ok(matrix)
                False -> Error(Nil)
              }
            }
          }
        }
      }
    }
  }
}

/// Find a translation, rotation, and uniform scale mapping one subpath to
/// another subpath.
///
/// The subpath `closed` field is ignored. Segment constructors must match in
/// order; no cycling or alternate starting segment is attempted.
pub fn subpath(
  source source: svg_path.Subpath,
  target target: svg_path.Subpath,
  tolerance tolerance: Float,
) -> Result(transform.Matrix, Nil) {
  case subpath_point_cloud(source, target) {
    Error(_) -> Error(Nil)
    Ok(cloud) -> {
      case points(source: cloud.source, target: cloud.target, tolerance:) {
        Error(_) -> Error(Nil)
        Ok(matrix) -> {
          case
            !cloud.has_arc
            || subpath_arc_fields_match(source, target, matrix, tolerance)
          {
            True -> Ok(matrix)
            False -> Error(Nil)
          }
        }
      }
    }
  }
}

/// Find a translation, rotation, and uniform scale mapping one path to another
/// path.
///
/// Path subpaths must match in order. Each subpath comparison ignores the
/// subpath `closed` field, and no cycling or alternate starting segment is
/// attempted.
pub fn path(
  source source: svg_path.Path,
  target target: svg_path.Path,
  tolerance tolerance: Float,
) -> Result(transform.Matrix, Nil) {
  case path_point_cloud(svg_path.subpaths(source), svg_path.subpaths(target)) {
    Error(_) -> Error(Nil)
    Ok(cloud) -> {
      case points(source: cloud.source, target: cloud.target, tolerance:) {
        Error(_) -> Error(Nil)
        Ok(matrix) -> {
          case
            !cloud.has_arc
            || path_arc_fields_match(
              svg_path.subpaths(source),
              svg_path.subpaths(target),
              matrix,
              tolerance,
            )
          {
            True -> Ok(matrix)
            False -> Error(Nil)
          }
        }
      }
    }
  }
}

fn path_point_cloud(
  source: List(svg_path.Subpath),
  target: List(svg_path.Subpath),
) -> Result(PointCloud, Nil) {
  path_point_cloud_loop(
    source,
    target,
    PointCloud(source: [], target: [], has_arc: False),
  )
}

fn path_point_cloud_loop(
  source: List(svg_path.Subpath),
  target: List(svg_path.Subpath),
  cloud: PointCloud,
) -> Result(PointCloud, Nil) {
  case source, target {
    [], [] -> {
      Ok(PointCloud(
        source: list.reverse(cloud.source),
        target: list.reverse(cloud.target),
        has_arc: cloud.has_arc,
      ))
    }

    [source_first, ..source_rest], [target_first, ..target_rest] -> {
      case subpath_point_cloud(source_first, target_first) {
        Error(_) -> Error(Nil)
        Ok(subpath_cloud) -> {
          path_point_cloud_loop(
            source_rest,
            target_rest,
            PointCloud(
              source: prepend_reversed(subpath_cloud.source, cloud.source),
              target: prepend_reversed(subpath_cloud.target, cloud.target),
              has_arc: cloud.has_arc || subpath_cloud.has_arc,
            ),
          )
        }
      }
    }

    _, _ -> Error(Nil)
  }
}

fn subpath_point_cloud(
  source: svg_path.Subpath,
  target: svg_path.Subpath,
) -> Result(PointCloud, Nil) {
  case svg_path.start(source), svg_path.start(target) {
    Ok(source_start), Ok(target_start) -> {
      subpath_points(
        svg_path.segments(source),
        svg_path.segments(target),
        [source_start],
        [target_start],
        has_arc: False,
      )
    }
    _, _ -> Error(Nil)
  }
}

fn subpath_points(
  source: List(svg_path.Segment),
  target: List(svg_path.Segment),
  source_points: List(svg_path.Point),
  target_points: List(svg_path.Point),
  has_arc has_arc: Bool,
) -> Result(PointCloud, Nil) {
  case source, target {
    [], [] ->
      Ok(PointCloud(
        source: list.reverse(source_points),
        target: list.reverse(target_points),
        has_arc:,
      ))

    [source_first, ..source_rest], [target_first, ..target_rest] -> {
      case segment_points(source_first, target_first) {
        Error(_) -> Error(Nil)
        Ok(#(source_extra, target_extra, segment_has_arc)) -> {
          subpath_points(
            source_rest,
            target_rest,
            prepend_reversed(source_extra, source_points),
            prepend_reversed(target_extra, target_points),
            has_arc: has_arc || segment_has_arc,
          )
        }
      }
    }

    _, _ -> Error(Nil)
  }
}

fn segment_points(
  source: svg_path.Segment,
  target: svg_path.Segment,
) -> Result(#(List(svg_path.Point), List(svg_path.Point), Bool), Nil) {
  case source, target {
    svg_path.Line(end: source_end, ..), svg_path.Line(end: target_end, ..) -> {
      Ok(#([source_end], [target_end], False))
    }

    svg_path.QuadraticBezier(control: source_control, end: source_end, ..),
      svg_path.QuadraticBezier(control: target_control, end: target_end, ..)
    -> {
      Ok(#([source_control, source_end], [target_control, target_end], False))
    }

    svg_path.CubicBezier(
      control1: source_control1,
      control2: source_control2,
      end: source_end,
      ..,
    ),
      svg_path.CubicBezier(
        control1: target_control1,
        control2: target_control2,
        end: target_end,
        ..,
      )
    -> {
      Ok(#(
        [source_control1, source_control2, source_end],
        [target_control1, target_control2, target_end],
        False,
      ))
    }

    svg_path.Arc(
      large_arc: source_large_arc,
      sweep: source_sweep,
      end: source_end,
      ..,
    ),
      svg_path.Arc(
        large_arc: target_large_arc,
        sweep: target_sweep,
        end: target_end,
        ..,
      )
    -> {
      case
        source_large_arc == target_large_arc && source_sweep == target_sweep
      {
        False -> Error(Nil)
        True -> {
          case arc_opposite_point(source), arc_opposite_point(target) {
            Ok(source_opposite), Ok(target_opposite) ->
              Ok(#(
                [source_opposite, source_end],
                [target_opposite, target_end],
                True,
              ))
            _, _ -> Error(Nil)
          }
        }
      }
    }

    _, _ -> Error(Nil)
  }
}

fn arc_opposite_point(
  segment: svg_path.Segment,
) -> Result(svg_path.Point, Nil) {
  case svg_path.arc_center_data(segment) {
    Error(_) -> Error(Nil)
    Ok(arc) -> {
      Ok(
        ellipse.point_at_angle(arc, angle: arc.start_angle +. 180.0)
        |> from_ellipse_point,
      )
    }
  }
}

fn prepend_reversed(
  points: List(svg_path.Point),
  accumulated: List(svg_path.Point),
) -> List(svg_path.Point) {
  case points {
    [] -> accumulated
    [first, ..rest] -> prepend_reversed(rest, [first, ..accumulated])
  }
}

fn arc_fields_match(
  source: List(svg_path.Segment),
  target: List(svg_path.Segment),
  matrix: transform.Matrix,
  tolerance: Float,
) -> Bool {
  case source, target {
    [], [] -> True
    [source_first, ..source_rest], [target_first, ..target_rest] -> {
      arc_field_match(source_first, target_first, matrix, tolerance)
      && arc_fields_match(source_rest, target_rest, matrix, tolerance)
    }
    _, _ -> False
  }
}

fn path_arc_fields_match(
  source: List(svg_path.Subpath),
  target: List(svg_path.Subpath),
  matrix: transform.Matrix,
  tolerance: Float,
) -> Bool {
  case source, target {
    [], [] -> True
    [source_first, ..source_rest], [target_first, ..target_rest] -> {
      subpath_arc_fields_match(source_first, target_first, matrix, tolerance)
      && path_arc_fields_match(source_rest, target_rest, matrix, tolerance)
    }
    _, _ -> False
  }
}

fn subpath_arc_fields_match(
  source: svg_path.Subpath,
  target: svg_path.Subpath,
  matrix: transform.Matrix,
  tolerance: Float,
) -> Bool {
  arc_fields_match(
    svg_path.segments(source),
    svg_path.segments(target),
    matrix,
    tolerance,
  )
}

fn arc_field_match(
  source: svg_path.Segment,
  target: svg_path.Segment,
  matrix: transform.Matrix,
  tolerance: Float,
) -> Bool {
  case source, target {
    svg_path.Arc(..),
      svg_path.Arc(
        radius: target_radius,
        x_axis_rotation: target_rotation,
        large_arc: target_large_arc,
        sweep: target_sweep,
        ..,
      )
    -> {
      case transform.segment(source, by: matrix) {
        Ok(svg_path.Arc(
          radius: actual_radius,
          x_axis_rotation: actual_rotation,
          large_arc: actual_large_arc,
          sweep: actual_sweep,
          ..,
        )) -> {
          actual_large_arc == target_large_arc
          && actual_sweep == target_sweep
          && points_within_tolerance(actual_radius, target_radius, tolerance)
          && floats_within_tolerance(
            actual_rotation,
            target_rotation,
            tolerance,
          )
        }
        _ -> False
      }
    }
    _, _ -> True
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

fn swept_pair(points: List(IndexedPoint)) -> PointPair {
  let assert [first, second, ..rest] = points
  let first_sweep = farthest_from(first, [second, ..rest])
  let second_sweep = farthest_from(first_sweep, points)
  let third_sweep = farthest_from(second_sweep, points)

  indexed_pair(second_sweep, third_sweep)
}

fn farthest_from(
  point: IndexedPoint,
  points: List(IndexedPoint),
) -> IndexedPoint {
  case points {
    [] -> point
    [first, ..rest] -> farthest_from_loop(point, rest, first)
  }
}

fn farthest_from_loop(
  point: IndexedPoint,
  rest: List(IndexedPoint),
  best: IndexedPoint,
) -> IndexedPoint {
  case rest {
    [] -> best
    [first, ..remaining] -> {
      let next = case
        distance_squared(point.source, first.source)
        >. distance_squared(point.source, best.source)
      {
        True -> first
        False -> best
      }

      farthest_from_loop(point, remaining, next)
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

fn points_within_tolerance(
  a: svg_path.Point,
  b: svg_path.Point,
  tolerance: Float,
) -> Bool {
  distance_squared(a, b) <=. tolerance *. tolerance
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
