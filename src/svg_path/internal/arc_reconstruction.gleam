//// Bounded affine CSG arc reconstruction. No stored arrangement geometry is edited.

import gleam/float
import gleam/list
import gleam/result
import svg_path
import svg_path/affine
import svg_path/ellipse
import svg_path/internal/number
import svg_path/point
import svg_path/trig

const epsilon = 0.0000000000000002220446049250313

// Keep an estimated eight decimal digits in the normalized linear solve.
// This is a numerical conditioning gate, not a geometric error guarantee.
const solve_relative_budget = 0.00000001

@internal
pub fn adjust(
  arc: svg_path.Segment,
  start: svg_path.Point,
  end: svg_path.Point,
) -> Result(svg_path.Segment, Nil) {
  case
    start == svg_path.segment_start(arc) && end == svg_path.segment_end(arc)
  {
    True -> Ok(arc)
    False -> {
      use data <- result.try(
        svg_path.arc_center_data(arc) |> result.replace_error(Nil),
      )
      use middle <- result.try(
        svg_path.segment_point(arc, 0.5) |> result.replace_error(Nil),
      )
      let old_start = svg_path.segment_start(arc)
      let old_end = svg_path.segment_end(arc)
      use matrix <- result.try(midpoint_map(
        old_start,
        old_end,
        middle,
        start,
        end,
      ))
      encode(arc, data, matrix, start, end)
    }
  }
}

// All descendants refer directly to the original center-form interval.
// The tolerance is positional, not a tangent-continuity guarantee.
@internal
pub fn adjust_with_tolerance(
  arc: svg_path.Segment,
  start: svg_path.Point,
  end: svg_path.Point,
  tolerance: Float,
) -> Result(List(svg_path.Segment), Nil) {
  use _ <- result.try(case tolerance >. 0.0 && number.is_finite(tolerance) {
    True -> Ok(Nil)
    False -> Error(Nil)
  })
  case
    start == svg_path.segment_start(arc) && end == svg_path.segment_end(arc)
  {
    True -> Ok([arc])
    False -> {
      use parent <- result.try(
        svg_path.arc_center_data(arc) |> result.replace_error(Nil),
      )
      interval(arc, parent, 0.0, 1.0, start, end, tolerance, 3)
    }
  }
}

fn interval(
  original: svg_path.Segment,
  parent: ellipse.CenterArcData,
  from: Float,
  to: Float,
  start: svg_path.Point,
  end: svg_path.Point,
  tolerance: Float,
  depth: Int,
) {
  let reference =
    ellipse.CenterArcData(
      ..parent,
      start_angle: parent.start_angle +. from *. parent.delta_angle,
      delta_angle: { to -. from } *. parent.delta_angle,
    )
  let source = case from == 0.0 && to == 1.0 {
    True -> original
    False -> svg_path.arc_from_center_data(reference)
  }
  let candidate = case
    bounded(adjust(source, start, end), reference, tolerance)
  {
    Ok(segment) -> Ok(segment)
    Error(_) -> bounded(similarity(source, start, end), reference, tolerance)
  }
  case candidate {
    Ok(segment) -> Ok([segment])
    Error(_) -> {
      use _ <- result.try(case depth > 0 {
        True -> Ok(Nil)
        False -> Error(Nil)
      })
      let middle = from +. { to -. from } /. 2.0
      let p = ellipse.arc_point(parent, middle)
      let shared = svg_path.Point(p.x, p.y)
      use left <- result.try(interval(
        original,
        parent,
        from,
        middle,
        start,
        shared,
        tolerance,
        depth - 1,
      ))
      use right <- result.try(interval(
        original,
        parent,
        middle,
        to,
        shared,
        end,
        tolerance,
        depth - 1,
      ))
      Ok(list.append(left, right))
    }
  }
}

fn bounded(candidate, reference, tolerance) {
  use segment <- result.try(candidate)
  use data <- result.try(
    svg_path.arc_center_data(segment) |> result.replace_error(Nil),
  )
  let bound = deviation_bound(reference, data)
  case number.is_finite(bound) && bound <=. tolerance {
    True -> Ok(segment)
    False -> Error(Nil)
  }
}

// Endpoint-matching rotation and uniform scale. Its displacement must pass the
// same bound as the midpoint-fixed candidate before it can be used.
fn similarity(arc, start, end) {
  use data <- result.try(
    svg_path.arc_center_data(arc) |> result.replace_error(Nil),
  )
  let old_start = svg_path.segment_start(arc)
  let chord = point.subtract(svg_path.segment_end(arc), old_start)
  let target = point.subtract(end, start)
  let scale =
    float.max(float.absolute_value(chord.x), float.absolute_value(chord.y))
  use _ <- result.try(case scale >. 0.0 && number.is_finite(scale) {
    True -> Ok(Nil)
    False -> Error(Nil)
  })
  let x = chord.x /. scale
  let y = chord.y /. scale
  let tx = target.x /. scale
  let ty = target.y /. scale
  let denominator = x *. x +. y *. y
  let a = { tx *. x +. ty *. y } /. denominator
  let b = { ty *. x -. tx *. y } /. denominator
  let matrix =
    affine.matrix(
      a: a,
      b: b,
      c: 0.0 -. b,
      d: a,
      e: start.x -. a *. old_start.x +. b *. old_start.y,
      f: start.y -. b *. old_start.x -. a *. old_start.y,
    )
  encode(arc, data, matrix, start, end)
}

fn vector(p: ellipse.EllipsePoint) {
  svg_path.Point(p.x, p.y)
}

// Express each ellipse as C + U cos(w t) + V sin(w t), with w >= 0.
// This accommodates changed axis rotation, swapped axes, and reflection.
fn basis(data: ellipse.CenterArcData) {
  let rotation = data.x_axis_rotation
  let phase = data.start_angle
  let c = trig.cos_degrees(rotation)
  let s = trig.sin_degrees(rotation)
  let cp = trig.cos_degrees(phase)
  let sp = trig.sin_degrees(phase)
  let sign = case data.delta_angle <. 0.0 {
    True -> -1.0
    False -> 1.0
  }
  let u =
    svg_path.Point(
      data.radius.x *. cp *. c -. data.radius.y *. sp *. s,
      data.radius.x *. cp *. s +. data.radius.y *. sp *. c,
    )
  let v =
    svg_path.Point(
      sign *. { 0.0 -. data.radius.x *. sp *. c -. data.radius.y *. cp *. s },
      sign *. { 0.0 -. data.radius.x *. sp *. s +. data.radius.y *. cp *. c },
    )
  #(u, v, trig.degrees_to_radians(float.absolute_value(data.delta_angle)))
}

@internal
pub fn deviation_bound(
  parent: ellipse.CenterArcData,
  child: ellipse.CenterArcData,
) -> Float {
  let #(u, v, w) = basis(parent)
  let #(a, b, z) = basis(child)
  let angular = float.min(2.0, float.absolute_value(w -. z))
  let radius = float.max(child.radius.x, child.radius.y)
  let center_bound =
    point.distance(vector(parent.center), vector(child.center))
    +. point.distance(u, a)
    +. point.distance(v, b)
    +. radius
    *. angular
  let endpoints =
    float.max(
      point.distance(
        vector(ellipse.arc_point(parent, 0.0)),
        vector(ellipse.arc_point(child, 0.0)),
      ),
      point.distance(
        vector(ellipse.arc_point(parent, 1.0)),
        vector(ellipse.arc_point(child, 1.0)),
      ),
    )
  let second =
    point.distance(point.scale(u, w *. w), point.scale(a, z *. z))
    +. point.distance(point.scale(v, w *. w), point.scale(b, z *. z))
    +. radius
    *. z
    *. z
    *. angular
  float.min(center_bound, endpoints +. second /. 8.0)
}

fn encode(
  arc: svg_path.Segment,
  data: ellipse.CenterArcData,
  matrix: affine.Affine,
  start: svg_path.Point,
  end: svg_path.Point,
) {
  use _ <- result.try(
    case affine.is_finite(matrix) && affine.determinant(matrix) != 0.0 {
      True -> Ok(Nil)
      False -> Error(Nil)
    },
  )
  use #(radius, rotation) <- result.try(
    ellipse.transformed_axes(data.radius, data.x_axis_rotation, matrix)
    |> result.replace_error(Nil),
  )
  let assert svg_path.Arc(large_arc:, sweep:, ..) = arc
  let output =
    svg_path.Arc(
      start:,
      radius: svg_path.Point(radius.x, radius.y),
      x_axis_rotation: rotation,
      large_arc:,
      sweep: case affine.determinant(matrix) <. 0.0 {
        True -> !sweep
        False -> sweep
      },
      end:,
    )
  use _ <- result.try(
    svg_path.arc_center_data(output) |> result.replace_error(Nil),
  )
  Ok(output)
}

fn midpoint_map(a, b, middle, target_a, target_b) {
  let u = point.subtract(a, middle)
  let v = point.subtract(b, middle)
  let scale =
    float.max(
      float.max(float.absolute_value(u.x), float.absolute_value(u.y)),
      float.max(float.absolute_value(v.x), float.absolute_value(v.y)),
    )
  use _ <- result.try(case scale >. 0.0 && number.is_finite(scale) {
    True -> Ok(Nil)
    False -> Error(Nil)
  })
  let ux = u.x /. scale
  let uy = u.y /. scale
  let vx = v.x /. scale
  let vy = v.y /. scale
  let det = ux *. vy -. vx *. uy
  let norm =
    float.max(
      float.absolute_value(ux) +. float.absolute_value(vx),
      float.absolute_value(uy) +. float.absolute_value(vy),
    )
  let adj_norm =
    float.max(
      float.absolute_value(vy) +. float.absolute_value(vx),
      float.absolute_value(uy) +. float.absolute_value(ux),
    )
  use _ <- result.try(
    case
      float.absolute_value(det) >. 0.0
      && norm *. adj_norm *. epsilon
      <=. solve_relative_budget *. float.absolute_value(det)
    {
      True -> Ok(Nil)
      False -> Error(Nil)
    },
  )
  // Solve for the change from identity, keeping endpoint movements small.
  let da = point.subtract(target_a, a)
  let db = point.subtract(target_b, b)
  let ax = da.x /. scale
  let ay = da.y /. scale
  let bx = db.x /. scale
  let by = db.y /. scale
  let ea = { ax *. vy -. bx *. uy } /. det
  let eb = { ay *. vy -. by *. uy } /. det
  let ec = { bx *. ux -. ax *. vx } /. det
  let ed = { by *. ux -. ay *. vx } /. det
  let residual =
    float.max(
      float.max(
        float.absolute_value(ea *. ux +. ec *. uy -. ax),
        float.absolute_value(eb *. ux +. ed *. uy -. ay),
      ),
      float.max(
        float.absolute_value(ea *. vx +. ec *. vy -. bx),
        float.absolute_value(eb *. vx +. ed *. vy -. by),
      ),
    )
  let rhs =
    float.max(
      float.max(float.absolute_value(ax), float.absolute_value(ay)),
      float.max(float.absolute_value(bx), float.absolute_value(by)),
    )
  use _ <- result.try(case residual <=. 64.0 *. epsilon *. float.max(1.0, rhs) {
    True -> Ok(Nil)
    False -> Error(Nil)
  })
  let matrix =
    affine.matrix(
      a: 1.0 +. ea,
      b: eb,
      c: ec,
      d: 1.0 +. ed,
      e: 0.0 -. ea *. middle.x -. ec *. middle.y,
      f: 0.0 -. eb *. middle.x -. ed *. middle.y,
    )
  case affine.is_finite(matrix) && affine.determinant(matrix) != 0.0 {
    True -> Ok(matrix)
    False -> Error(Nil)
  }
}
