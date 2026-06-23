//// Face-aware support experiment.
////
//// This is the next version of the abstract ConvexLoop idea: support can be a
//// unique point or an entire flat face.

import gleam/float
import gleam_community/maths
import svg_path

const tie_tolerance = 0.0000001

pub type SupportSet(param) {
  SupportPoint(param: param, point: svg_path.Point)
  SupportFace(
    from: param,
    to: param,
    from_point: svg_path.Point,
    to_point: svg_path.Point,
  )
}

pub type Support(param) {
  Support(value: Float, set: SupportSet(param))
}

pub type Loop(param) {
  Loop(
    name: String,
    support: fn(Float) -> Support(param),
    point: fn(param) -> svg_path.Point,
    param_label: fn(param) -> String,
  )
}

pub type UnionSupport(a, b) {
  AWins(SupportSet(a))
  BWins(SupportSet(b))
  Tie(SupportSet(a), SupportSet(b))
}

pub fn union_support(
  loop_a: Loop(a),
  loop_b: Loop(b),
  angle angle: Float,
) -> UnionSupport(a, b) {
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
  set: SupportSet(param),
) -> #(svg_path.Point, svg_path.Point) {
  case set {
    SupportPoint(point:, ..) -> #(point, point)
    SupportFace(from_point:, to_point:, ..) -> #(from_point, to_point)
  }
}

pub fn direction(angle: Float) -> svg_path.Point {
  let radians = angle *. 3.141592653589793 /. 180.0
  svg_path.point(maths.cos(radians), maths.sin(radians))
}

pub fn dot(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.x +. a.y *. b.y
}
