//// Directional semantic congruency checks for path geometry.
////
//// Congruency means that a translation, rotation, and uniform scale maps the
//// source geometry to the target geometry within a tolerance. Reflection and
//// shear are not allowed.
////
//// These checks compare ordered semantic structure, not rendered shape. Segment
//// constructors must match, subpaths and paths must have matching ordered
//// structure, and closed subpaths are not cycled to search for another starting
//// segment.

import gleam/float
import gleam/int
import gleam/list
import svg_path
import svg_path/ellipse
import svg_path/transform
import vec/vec2f

/// The transform family allowed during best-fit congruency.
pub type TransformFamily {
  /// Translation, rotation, and uniform scale. Reflection and shear are not
  /// allowed.
  Similar

  /// A general affine transform, allowing non-uniform scale, shear, and
  /// reflection. If the source point cloud is underdetermined for an affine
  /// solve, this falls back to `Similar`.
  Affine
}

/// A best-fit transform and its root-mean-square point error.
///
/// `error` is measured in the same coordinate units as the input points.
pub type Fit {
  Fit(transform: transform.Matrix, error: Float)
}

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

type PointSums {
  PointSums(
    count: Int,
    source_x: Float,
    source_y: Float,
    target_x: Float,
    target_y: Float,
  )
}

type SimilaritySums {
  SimilaritySums(dot: Float, cross: Float, source_length_squared: Float)
}

type AffineSums {
  AffineSums(
    count: Int,
    source_x: Float,
    source_y: Float,
    source_xx: Float,
    source_xy: Float,
    source_yy: Float,
    target_x: Float,
    target_y: Float,
    source_target_xx: Float,
    source_target_yx: Float,
    source_target_xy: Float,
    source_target_yy: Float,
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

/// Find the best transform mapping one ordered point list to another.
///
/// Empty lists and lists with different lengths return `Error(Nil)`.
/// `Similar` fits translation, rotation, and uniform scale without reflection.
/// `Affine` fits a general affine transform; when the source points do not
/// determine an affine transform stably, it falls back to `Similar`.
///
/// The returned `Fit.error` is the root-mean-square distance between each
/// transformed source point and its corresponding target point.
pub fn fit_points(
  source source: List(svg_path.Point),
  target target: List(svg_path.Point),
  family family: TransformFamily,
) -> Result(Fit, Nil) {
  use indexed <- result_try_nil(indexed_points(source, target, accumulated: []))

  case indexed {
    [] -> Error(Nil)
    _ -> {
      case family {
        Similar -> fit_similar(indexed)
        Affine -> fit_affine(indexed)
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
///
/// Segment congruency is intentionally not visual-shape congruency. A segment
/// only matches a target segment built with the same constructor, even if two
/// different constructors would render the same geometry.
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

/// Find the best transform mapping one segment to another segment of the same
/// constructor.
///
/// This uses the same semantic point-cloud policy as `segment`, but returns a
/// best-fit transform and RMS point error instead of applying a tolerance.
pub fn fit_segment(
  source source: svg_path.Segment,
  target target: svg_path.Segment,
  family family: TransformFamily,
) -> Result(Fit, Nil) {
  use cloud <- result_try_nil(segment_point_cloud(source, target))
  fit_points(source: cloud.source, target: cloud.target, family:)
}

/// Find a translation, rotation, and uniform scale mapping one subpath to
/// another subpath.
///
/// The subpath `closed` field is ignored. Segment constructors must match in
/// order. Closed subpaths are not cycled, and no alternate starting segment is
/// attempted.
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

/// Find the best transform mapping one ordered subpath to another.
///
/// The subpath `closed` field is ignored. Segment constructors must match in
/// order. Closed subpaths are not cycled, and no alternate starting segment is
/// attempted.
pub fn fit_subpath(
  source source: svg_path.Subpath,
  target target: svg_path.Subpath,
  family family: TransformFamily,
) -> Result(Fit, Nil) {
  use cloud <- result_try_nil(subpath_point_cloud(source, target))
  fit_points(source: cloud.source, target: cloud.target, family:)
}

/// Find a translation, rotation, and uniform scale mapping one path to another
/// path.
///
/// Path subpaths must match in order. Each subpath comparison ignores the
/// subpath `closed` field. Closed subpaths are not cycled, no alternate
/// starting segment is attempted, and subpaths are not reordered.
pub fn path(
  source source: svg_path.Path,
  target target: svg_path.Path,
  tolerance tolerance: Float,
) -> Result(transform.Matrix, Nil) {
  case
    path_point_cloud(
      svg_path.path_subpaths(source),
      svg_path.path_subpaths(target),
    )
  {
    Error(_) -> Error(Nil)
    Ok(cloud) -> {
      case points(source: cloud.source, target: cloud.target, tolerance:) {
        Error(_) -> Error(Nil)
        Ok(matrix) -> {
          case
            !cloud.has_arc
            || path_arc_fields_match(
              svg_path.path_subpaths(source),
              svg_path.path_subpaths(target),
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

/// Find the best transform mapping one ordered path to another.
///
/// Path subpaths must match in order. Each subpath comparison ignores the
/// subpath `closed` field. Closed subpaths are not cycled, no alternate
/// starting segment is attempted, and subpaths are not reordered.
pub fn fit_path(
  source source: svg_path.Path,
  target target: svg_path.Path,
  family family: TransformFamily,
) -> Result(Fit, Nil) {
  use cloud <- result_try_nil(path_point_cloud(
    svg_path.path_subpaths(source),
    svg_path.path_subpaths(target),
  ))
  fit_points(source: cloud.source, target: cloud.target, family:)
}

fn segment_point_cloud(
  source: svg_path.Segment,
  target: svg_path.Segment,
) -> Result(PointCloud, Nil) {
  case segment_points(source, target) {
    Error(_) -> Error(Nil)
    Ok(#(source_extra, target_extra, has_arc)) -> {
      Ok(PointCloud(
        source: [svg_path.segment_start(source), ..source_extra],
        target: [svg_path.segment_start(target), ..target_extra],
        has_arc:,
      ))
    }
  }
}

fn fit_similar(points: List(IndexedPoint)) -> Result(Fit, Nil) {
  let centroids = point_centroids(points)
  use centroids <- result_try_nil(centroids)
  let #(source_center, target_center) = centroids
  let sums = similarity_sums(points, source_center, target_center)

  let matrix = case sums.source_length_squared <=. 0.0 {
    True ->
      transform.translate(
        x: target_center.x -. source_center.x,
        y: target_center.y -. source_center.y,
      )
    False -> {
      let scale_cos = sums.dot /. sums.source_length_squared
      let scale_sin = sums.cross /. sums.source_length_squared

      transform.matrix(
        a: scale_cos,
        b: scale_sin,
        c: 0.0 -. scale_sin,
        d: scale_cos,
        e: target_center.x
          -. { scale_cos *. source_center.x -. scale_sin *. source_center.y },
        f: target_center.y
          -. { scale_sin *. source_center.x +. scale_cos *. source_center.y },
      )
    }
  }

  fit_from_matrix(points, matrix)
}

fn fit_affine(points: List(IndexedPoint)) -> Result(Fit, Nil) {
  let sums = affine_sums(points)
  let n = int.to_float(sums.count)
  let determinant =
    sums.source_xx
    *. { sums.source_yy *. n -. sums.source_y *. sums.source_y }
    -. sums.source_xy
    *. { sums.source_xy *. n -. sums.source_y *. sums.source_x }
    +. sums.source_x
    *. { sums.source_xy *. sums.source_y -. sums.source_yy *. sums.source_x }

  case determinant_within_zero(determinant) {
    True -> fit_similar(points)
    False -> {
      use x_coefficients <- result_try_nil(solve_affine_coefficients(
        sums,
        rhs_x: sums.source_target_xx,
        rhs_y: sums.source_target_yx,
        rhs_constant: sums.target_x,
        determinant:,
      ))
      use y_coefficients <- result_try_nil(solve_affine_coefficients(
        sums,
        rhs_x: sums.source_target_xy,
        rhs_y: sums.source_target_yy,
        rhs_constant: sums.target_y,
        determinant:,
      ))
      let #(a, c, e) = x_coefficients
      let #(b, d, f) = y_coefficients

      transform.matrix(a:, b:, c:, d:, e:, f:)
      |> fit_from_matrix(points, _)
    }
  }
}

fn solve_affine_coefficients(
  sums: AffineSums,
  rhs_x rhs_x: Float,
  rhs_y rhs_y: Float,
  rhs_constant rhs_constant: Float,
  determinant determinant: Float,
) -> Result(#(Float, Float, Float), Nil) {
  let n = int.to_float(sums.count)
  let x =
    {
      rhs_x
      *. { sums.source_yy *. n -. sums.source_y *. sums.source_y }
      -. sums.source_xy
      *. { rhs_y *. n -. sums.source_y *. rhs_constant }
      +. sums.source_x
      *. { rhs_y *. sums.source_y -. sums.source_yy *. rhs_constant }
    }
    /. determinant
  let y =
    {
      sums.source_xx
      *. { rhs_y *. n -. sums.source_y *. rhs_constant }
      -. rhs_x
      *. { sums.source_xy *. n -. sums.source_y *. sums.source_x }
      +. sums.source_x
      *. { sums.source_xy *. rhs_constant -. rhs_y *. sums.source_x }
    }
    /. determinant
  let constant =
    {
      sums.source_xx
      *. { sums.source_yy *. rhs_constant -. rhs_y *. sums.source_y }
      -. sums.source_xy
      *. { sums.source_xy *. rhs_constant -. rhs_y *. sums.source_x }
      +. rhs_x
      *. { sums.source_xy *. sums.source_y -. sums.source_yy *. sums.source_x }
    }
    /. determinant

  case is_finite(x) && is_finite(y) && is_finite(constant) {
    True -> Ok(#(x, y, constant))
    False -> Error(Nil)
  }
}

fn point_centroids(
  points: List(IndexedPoint),
) -> Result(#(svg_path.Point, svg_path.Point), Nil) {
  let sums =
    list.fold(
      points,
      PointSums(
        count: 0,
        source_x: 0.0,
        source_y: 0.0,
        target_x: 0.0,
        target_y: 0.0,
      ),
      fn(sums, point) {
        PointSums(
          count: sums.count + 1,
          source_x: sums.source_x +. point.source.x,
          source_y: sums.source_y +. point.source.y,
          target_x: sums.target_x +. point.target.x,
          target_y: sums.target_y +. point.target.y,
        )
      },
    )

  case sums.count <= 0 {
    True -> Error(Nil)
    False -> {
      let count = int.to_float(sums.count)

      Ok(#(
        svg_path.point(sums.source_x /. count, sums.source_y /. count),
        svg_path.point(sums.target_x /. count, sums.target_y /. count),
      ))
    }
  }
}

fn similarity_sums(
  points: List(IndexedPoint),
  source_center: svg_path.Point,
  target_center: svg_path.Point,
) -> SimilaritySums {
  list.fold(
    points,
    SimilaritySums(dot: 0.0, cross: 0.0, source_length_squared: 0.0),
    fn(sums, point) {
      let source_x = point.source.x -. source_center.x
      let source_y = point.source.y -. source_center.y
      let target_x = point.target.x -. target_center.x
      let target_y = point.target.y -. target_center.y

      SimilaritySums(
        dot: sums.dot +. source_x *. target_x +. source_y *. target_y,
        cross: sums.cross +. source_x *. target_y -. source_y *. target_x,
        source_length_squared: sums.source_length_squared
          +. source_x
          *. source_x
          +. source_y
          *. source_y,
      )
    },
  )
}

fn affine_sums(points: List(IndexedPoint)) -> AffineSums {
  list.fold(
    points,
    AffineSums(
      count: 0,
      source_x: 0.0,
      source_y: 0.0,
      source_xx: 0.0,
      source_xy: 0.0,
      source_yy: 0.0,
      target_x: 0.0,
      target_y: 0.0,
      source_target_xx: 0.0,
      source_target_yx: 0.0,
      source_target_xy: 0.0,
      source_target_yy: 0.0,
    ),
    fn(sums, point) {
      AffineSums(
        count: sums.count + 1,
        source_x: sums.source_x +. point.source.x,
        source_y: sums.source_y +. point.source.y,
        source_xx: sums.source_xx +. point.source.x *. point.source.x,
        source_xy: sums.source_xy +. point.source.x *. point.source.y,
        source_yy: sums.source_yy +. point.source.y *. point.source.y,
        target_x: sums.target_x +. point.target.x,
        target_y: sums.target_y +. point.target.y,
        source_target_xx: sums.source_target_xx
          +. point.source.x
          *. point.target.x,
        source_target_yx: sums.source_target_yx
          +. point.source.y
          *. point.target.x,
        source_target_xy: sums.source_target_xy
          +. point.source.x
          *. point.target.y,
        source_target_yy: sums.source_target_yy
          +. point.source.y
          *. point.target.y,
      )
    },
  )
}

fn fit_from_matrix(
  points: List(IndexedPoint),
  matrix: transform.Matrix,
) -> Result(Fit, Nil) {
  let #(a, b, c, d, e, f) = transform.to_tuple(matrix)

  case
    is_finite(a)
    && is_finite(b)
    && is_finite(c)
    && is_finite(d)
    && is_finite(e)
    && is_finite(f)
  {
    False -> Error(Nil)
    True -> {
      case rms_error(points, matrix) {
        Error(_) -> Error(Nil)
        Ok(error) -> Ok(Fit(transform: matrix, error:))
      }
    }
  }
}

fn rms_error(
  points: List(IndexedPoint),
  matrix: transform.Matrix,
) -> Result(Float, Nil) {
  let #(count, error_squared) =
    list.fold(points, #(0, 0.0), fn(accumulated, point) {
      let #(count, error_squared) = accumulated
      let mapped = transform.point(point.source, by: matrix)

      #(
        count + 1,
        error_squared +. vec2f.distance_squared(mapped, with: point.target),
      )
    })

  case count <= 0 {
    True -> Error(Nil)
    False -> {
      let mean_error_squared = error_squared /. int.to_float(count)

      case float.square_root(mean_error_squared) {
        Ok(error) -> {
          case is_finite(error) {
            True -> Ok(error)
            False -> Error(Nil)
          }
        }
        Error(_) -> Error(Nil)
      }
    }
  }
}

fn determinant_within_zero(value: Float) -> Bool {
  !is_finite(value) || float.absolute_value(value) <=. 0.000000000001
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
  case svg_path.subpath_start(source), svg_path.subpath_start(target) {
    Ok(source_start), Ok(target_start) -> {
      subpath_points(
        svg_path.subpath_segments(source),
        svg_path.subpath_segments(target),
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
    svg_path.subpath_segments(source),
    svg_path.subpath_segments(target),
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
        vec2f.distance_squared(point.source, with: first.source)
        >. vec2f.distance_squared(point.source, with: best.source)
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
    distance_squared: vec2f.distance_squared(source_a, with: source_b),
  )
}

fn points_within_tolerance(
  a: svg_path.Point,
  b: svg_path.Point,
  tolerance: Float,
) -> Bool {
  vec2f.distance_squared(a, with: b) <=. tolerance *. tolerance
}

fn floats_within_tolerance(a: Float, b: Float, tolerance: Float) -> Bool {
  float.absolute_value(a -. b) <=. tolerance
}

fn result_try_nil(result: Result(a, Nil), next: fn(a) -> Result(b, Nil)) {
  case result {
    Ok(value) -> next(value)
    Error(Nil) -> Error(Nil)
  }
}

fn is_finite(value: Float) -> Bool {
  !is_nan(value -. value)
}

fn is_nan(value: Float) -> Bool {
  !{ value <. 0.0 || value >=. 0.0 }
}

fn from_ellipse_point(point: ellipse.Point) -> svg_path.Point {
  svg_path.point(point.x, point.y)
}
