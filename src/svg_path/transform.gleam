import gleam/list
import svg_path
import svg_path/ellipse

pub type Matrix {
  Matrix(a: Float, b: Float, c: Float, d: Float, e: Float, f: Float)
}

pub type Error {
  DegenerateArcTransform
  InvalidMatrix
  Core(svg_path.Error)
}

pub fn matrix(
  a a: Float,
  b b: Float,
  c c: Float,
  d d: Float,
  e e: Float,
  f f: Float,
) -> Matrix {
  Matrix(a:, b:, c:, d:, e:, f:)
}

pub fn identity() -> Matrix {
  matrix(a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: 0.0)
}

pub fn point(point: svg_path.Point, by transform: Matrix) -> svg_path.Point {
  svg_path.point(
    transform.a *. point.x +. transform.c *. point.y +. transform.e,
    transform.b *. point.x +. transform.d *. point.y +. transform.f,
  )
}

pub fn segment(
  segment: svg_path.Segment,
  by transform: Matrix,
) -> Result(svg_path.Segment, Error) {
  case validate_matrix(transform) {
    Error(error) -> Error(error)
    Ok(Nil) -> transform_valid_segment(segment, transform)
  }
}

pub fn segment_gracefully(
  input: svg_path.Segment,
  by transform: Matrix,
) -> Result(svg_path.Segment, Error) {
  case segment(input, by: transform) {
    Ok(segment) -> Ok(segment)
    Error(DegenerateArcTransform) -> {
      case input {
        svg_path.Arc(
          start:,
          radius:,
          x_axis_rotation:,
          large_arc:,
          sweep:,
          end:,
        ) -> {
          case
            ellipse.collapsed_arc_line(
              start:,
              radius:,
              x_axis_rotation:,
              large_arc:,
              sweep:,
              end:,
              by: affine(transform),
            )
          {
            Ok(segment) -> Ok(segment)
            Error(_) -> Error(DegenerateArcTransform)
          }
        }
        _ -> Error(DegenerateArcTransform)
      }
    }
    Error(error) -> Error(error)
  }
}

pub fn segment_gracefully2(
  input: svg_path.Segment,
  by transform: Matrix,
) -> Result(svg_path.Subpath, Error) {
  case segment(input, by: transform) {
    Ok(segment) -> svg_path.subpath([segment]) |> map_core_error
    Error(DegenerateArcTransform) -> {
      case input {
        svg_path.Arc(
          start:,
          radius:,
          x_axis_rotation:,
          large_arc:,
          sweep:,
          end:,
        ) -> {
          case
            ellipse.collapsed_arc_subpath(
              start:,
              radius:,
              x_axis_rotation:,
              large_arc:,
              sweep:,
              end:,
              by: affine(transform),
            )
          {
            Ok(subpath) -> Ok(subpath)
            Error(_) -> Error(DegenerateArcTransform)
          }
        }
        _ -> Error(DegenerateArcTransform)
      }
    }
    Error(error) -> Error(error)
  }
}

pub fn subpath(
  subpath: svg_path.Subpath,
  by transform: Matrix,
) -> Result(svg_path.Subpath, Error) {
  case validate_matrix(transform) {
    Error(error) -> Error(error)
    Ok(Nil) -> {
      case transform_segments(svg_path.segments(subpath), transform, []) {
        Error(error) -> Error(error)
        Ok(segments) -> {
          case svg_path.subpath(segments) {
            Error(error) -> Error(Core(error))
            Ok(transformed) -> {
              case svg_path.is_closed(subpath) {
                True -> close_transformed_subpath(transformed)
                False -> Ok(transformed)
              }
            }
          }
        }
      }
    }
  }
}

pub fn subpath_gracefully(
  subpath: svg_path.Subpath,
  by transform: Matrix,
) -> Result(svg_path.Subpath, Error) {
  case validate_matrix(transform) {
    Error(error) -> Error(error)
    Ok(Nil) -> {
      case
        transform_segments_gracefully(svg_path.segments(subpath), transform, [])
      {
        Error(error) -> Error(error)
        Ok(segments) -> {
          case svg_path.wiggle_subpath(segments) {
            Error(error) -> Error(Core(error))
            Ok(transformed) -> {
              case svg_path.is_closed(subpath) {
                True -> close_transformed_subpath(transformed)
                False -> Ok(transformed)
              }
            }
          }
        }
      }
    }
  }
}

pub fn path(
  path: svg_path.Path,
  by transform: Matrix,
) -> Result(svg_path.Path, Error) {
  case validate_matrix(transform) {
    Error(error) -> Error(error)
    Ok(Nil) -> {
      case transform_subpaths(svg_path.subpaths(path), transform, []) {
        Error(error) -> Error(error)
        Ok(subpaths) -> Ok(svg_path.path(subpaths))
      }
    }
  }
}

fn transform_valid_segment(
  segment: svg_path.Segment,
  transform: Matrix,
) -> Result(svg_path.Segment, Error) {
  case segment {
    svg_path.Line(start:, end:) -> {
      Ok(svg_path.line(
        start: point(start, transform),
        end: point(end, transform),
      ))
    }
    svg_path.QuadraticBezier(start:, control:, end:) -> {
      Ok(svg_path.quadratic_bezier(
        start: point(start, transform),
        control: point(control, transform),
        end: point(end, transform),
      ))
    }
    svg_path.CubicBezier(start:, control1:, control2:, end:) -> {
      Ok(svg_path.cubic_bezier(
        start: point(start, transform),
        control1: point(control1, transform),
        control2: point(control2, transform),
        end: point(end, transform),
      ))
    }
    svg_path.Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:) -> {
      case
        ellipse.transformed_axes(
          radius:,
          x_axis_rotation:,
          by: affine(transform),
        )
      {
        Error(_) -> Error(DegenerateArcTransform)
        Ok(#(radius, x_axis_rotation)) -> {
          Ok(svg_path.arc(
            start: point(start, transform),
            radius: radius,
            x_axis_rotation: x_axis_rotation,
            large_arc: large_arc,
            sweep: transformed_sweep(sweep, transform),
            end: point(end, transform),
          ))
        }
      }
    }
  }
}

fn validate_matrix(transform: Matrix) -> Result(Nil, Error) {
  case
    is_finite(transform.a)
    && is_finite(transform.b)
    && is_finite(transform.c)
    && is_finite(transform.d)
    && is_finite(transform.e)
    && is_finite(transform.f)
  {
    True -> Ok(Nil)
    False -> Error(InvalidMatrix)
  }
}

fn map_core_error(
  result: Result(svg_path.Subpath, svg_path.Error),
) -> Result(svg_path.Subpath, Error) {
  case result {
    Ok(subpath) -> Ok(subpath)
    Error(error) -> Error(Core(error))
  }
}

fn affine(transform: Matrix) -> ellipse.Affine {
  ellipse.Affine(
    a: transform.a,
    b: transform.b,
    c: transform.c,
    d: transform.d,
    e: transform.e,
    f: transform.f,
  )
}

fn is_finite(value: Float) -> Bool {
  !is_nan(value -. value)
}

fn is_nan(value: Float) -> Bool {
  !{ value <. 0.0 || value >=. 0.0 }
}

fn transform_segments(
  segments: List(svg_path.Segment),
  transform: Matrix,
  transformed: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), Error) {
  case segments {
    [] -> Ok(list.reverse(transformed))
    [first, ..rest] -> {
      case segment(first, by: transform) {
        Error(error) -> Error(error)
        Ok(first) -> transform_segments(rest, transform, [first, ..transformed])
      }
    }
  }
}

fn transform_segments_gracefully(
  segments: List(svg_path.Segment),
  transform: Matrix,
  transformed: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), Error) {
  case segments {
    [] -> Ok(list.reverse(transformed))
    [first, ..rest] -> {
      case segment_gracefully2(first, by: transform) {
        Error(error) -> Error(error)
        Ok(first) -> {
          let transformed =
            prepend_all(svg_path.segments(first), to: transformed)
          transform_segments_gracefully(rest, transform, transformed)
        }
      }
    }
  }
}

fn prepend_all(
  segments: List(svg_path.Segment),
  to transformed: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case segments {
    [] -> transformed
    [first, ..rest] -> prepend_all(rest, to: [first, ..transformed])
  }
}

fn transform_subpaths(
  subpaths: List(svg_path.Subpath),
  transform: Matrix,
  transformed: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), Error) {
  case subpaths {
    [] -> Ok(list.reverse(transformed))
    [first, ..rest] -> {
      case subpath(first, by: transform) {
        Error(error) -> Error(error)
        Ok(first) -> transform_subpaths(rest, transform, [first, ..transformed])
      }
    }
  }
}

fn close_transformed_subpath(
  subpath: svg_path.Subpath,
) -> Result(svg_path.Subpath, Error) {
  case svg_path.close(subpath) {
    Ok(subpath) -> Ok(subpath)
    Error(_) -> {
      case svg_path.wiggle_close(subpath) {
        Ok(subpath) -> Ok(subpath)
        Error(error) -> Error(Core(error))
      }
    }
  }
}

fn transformed_sweep(sweep: Bool, transform: Matrix) -> Bool {
  case determinant(transform) <. 0.0 {
    True -> !sweep
    False -> sweep
  }
}

fn determinant(transform: Matrix) -> Float {
  transform.a *. transform.d -. transform.b *. transform.c
}
