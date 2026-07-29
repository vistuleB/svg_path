//// More explicit ConvexLoop model for the next hull-union refactor.
////
//// This keeps provenance separate from geometry. The union algorithm should be
//// able to carry `LoopPoint(id)` values without knowing what an `id` means.

import gleam/float
import gleam/list
import gleam_community/maths
import svg_path

const tie_tolerance = 0.0000001

pub type LoopPoint(id) {
  SourcePoint(id: id, t: Float)
}

pub type LoopPiece(id) {
  Curve(id: id, from: Float, to: Float)
  Line(from: LoopPoint(id), to: LoopPoint(id))
}

pub type SupportSet(id) {
  SupportPoint(point: LoopPoint(id))
  SupportFace(from: LoopPoint(id), to: LoopPoint(id))
}

pub type Support(id) {
  Support(value: Float, set: SupportSet(id))
}

pub type ConvexLoop(id) {
  ConvexLoop(
    name: String,
    pieces: List(LoopPiece(id)),
    support: fn(Float) -> Support(id),
    point: fn(LoopPoint(id)) -> svg_path.Point,
    piece_segments: fn(LoopPiece(id)) -> List(svg_path.Segment),
    point_label: fn(LoopPoint(id)) -> String,
  )
}

pub type UnionSupport(id_a, id_b) {
  AWins(SupportSet(id_a))
  BWins(SupportSet(id_b))
  Tie(SupportSet(id_a), SupportSet(id_b))
}

pub fn union_support(
  loop_a: ConvexLoop(id_a),
  loop_b: ConvexLoop(id_b),
  angle angle: Float,
) -> UnionSupport(id_a, id_b) {
  let a = loop_a.support(angle)
  let b = loop_b.support(angle)
  let difference = a.value -. b.value

  case float.absolute_value(difference) <=. tie_tolerance {
    True -> Tie(a.set, b.set)
    False ->
      case difference >. 0.0 {
        True -> AWins(a.set)
        False -> BWins(b.set)
      }
  }
}

pub fn support_set_points(
  set: SupportSet(id),
  loop: ConvexLoop(id),
) -> #(svg_path.Point, svg_path.Point) {
  case set {
    SupportPoint(point:) -> {
      let position = loop.point(point)
      #(position, position)
    }
    SupportFace(from:, to:) -> #(loop.point(from), loop.point(to))
  }
}

pub fn support_set_piece(set: SupportSet(id)) -> LoopPiece(id) {
  case set {
    SupportPoint(point:) -> Line(point, point)
    SupportFace(from:, to:) -> Line(from, to)
  }
}

pub fn line_support(
  from: LoopPoint(id),
  to: LoopPoint(id),
  from_point: svg_path.Point,
  to_point: svg_path.Point,
  angle angle: Float,
) -> Support(id) {
  let direction = direction(angle)
  let from_value = dot(from_point, direction)
  let to_value = dot(to_point, direction)

  case float.absolute_value(from_value -. to_value) <=. tie_tolerance {
    True -> Support(value: from_value, set: SupportFace(from: from, to: to))
    False ->
      case from_value >. to_value {
        True -> Support(value: from_value, set: SupportPoint(from))
        False -> Support(value: to_value, set: SupportPoint(to))
      }
  }
}

pub fn best_support(supports: List(Support(id))) -> Support(id) {
  let assert [first, ..rest] = supports
  list.fold(rest, first, fn(best, support) {
    case support.value >. best.value {
      True -> support
      False -> best
    }
  })
}

pub fn direction(angle: Float) -> svg_path.Point {
  let radians = angle *. 3.141592653589793 /. 180.0
  svg_path.Point(maths.cos(radians), maths.sin(radians))
}

pub fn dot(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.x +. a.y *. b.y
}
