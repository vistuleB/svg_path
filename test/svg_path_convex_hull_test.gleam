import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam_community/maths
import svg_path
import svg_path/convex_hull

const tolerance = 0.000001

pub fn segment_hull_returns_closed_subpath_and_line_pieces_for_line_test() {
  let segment =
    svg_path.line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(10.0, 0.0),
    )
  let assert Ok(#(subpath, pieces)) = convex_hull.segment_hull(segment)

  assert svg_path.is_closed(subpath)
  assert list.length(svg_path.segments(subpath)) == 2
  assert list.length(pieces) == 2
  assert list.all(pieces, is_line_piece)
}

pub fn specimen_hulls_survive_strict_subpath_constructor_test() {
  assert list.all(specimens(), fn(specimen) {
    let #(_, segment) = specimen

    case convex_hull.segment_hull(segment) {
      Ok(_) -> True
      Error(_) -> False
    }
  })
}

pub fn specimen_hulls_have_at_least_two_segments_test() {
  assert list.all(specimens(), fn(specimen) {
    let #(_, segment) = specimen

    case convex_hull.segment_hull(segment) {
      Ok(#(subpath, pieces)) ->
        list.length(svg_path.segments(subpath)) >= 2 && list.length(pieces) >= 2
      Error(_) -> False
    }
  })
}

pub fn specimen_hull_derivative_angles_are_nondecreasing_test() {
  assert list.all(specimens(), fn(specimen) {
    let #(_, segment) = specimen

    case convex_hull.segment_hull(segment) {
      Ok(#(subpath, _)) ->
        subpath
        |> svg_path.segments
        |> segment_derivative_angles
        |> rotate_to_smallest_positive_angle
        |> unwrap_angles
        |> nondecreasing(tolerance: 0.0)

      Error(_) -> False
    }
  })
}

pub fn specimen_hull_support_matches_original_at_10_degree_steps_test() {
  assert list.all(specimens(), fn(specimen) {
    let #(_, segment) = specimen

    case convex_hull.segment_hull(segment) {
      Ok(#(hull, _)) ->
        multiples_of_10_degrees()
        |> list.all(fn(angle) {
          case
            original_support_value(segment, angle),
            hull_support_value(svg_path.segments(hull), angle)
          {
            Ok(original), Ok(hull) -> near(original, hull)
            _, _ -> False
          }
        })

      Error(_) -> False
    }
  })
}

fn specimens() -> List(#(String, svg_path.Segment)) {
  list.append(curve_and_line_specimens(), arc_specimens())
}

fn curve_and_line_specimens() -> List(#(String, svg_path.Segment)) {
  [
    #("stem", stem()),
    #("horseshoe", horseshoe()),
    #("horseshoe_wide", horseshoe_wide()),
    #("diagonal_line", diagonal_line()),
    #("reverse_diagonal_line", reverse_diagonal_line()),
    #("horizontal_line", horizontal_line()),
    #("vertical_line", vertical_line()),
    #("snake_cubic", snake_cubic()),
    #("fish_cubic", fish_cubic()),
    #("del_cubic", del_cubic()),
    #("flourish_cubic", flourish_cubic()),
    #("left_hook_cubic", left_hook_cubic()),
  ]
}

fn arc_specimens() -> List(#(String, svg_path.Segment)) {
  [
    #("half_circle_arc", half_circle_arc(sweep: True)),
    #("half_circle_arc_reverse", half_circle_arc(sweep: False)),
    #("rotated_arc", rotated_arc(sweep: True)),
    #("rotated_arc_reverse", rotated_arc(sweep: False)),
    #("large_arc", large_arc(sweep: True)),
    #("large_arc_reverse", large_arc(sweep: False)),
  ]
}

fn stem() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(5.0, 70.0),
    control1: svg_path.point(30.0, 20.0),
    control2: svg_path.point(65.0, 105.0),
    end: svg_path.point(95.0, 30.0),
  )
}

fn horseshoe() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(20.0, 80.0),
    control1: svg_path.point(20.0, 5.0),
    control2: svg_path.point(100.0, 5.0),
    end: svg_path.point(100.0, 80.0),
  )
}

fn horseshoe_wide() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(20.0, 90.0),
    control1: svg_path.point(-25.0, 0.0),
    control2: svg_path.point(145.0, 0.0),
    end: svg_path.point(100.0, 90.0),
  )
}

fn diagonal_line() -> svg_path.Segment {
  svg_path.line(
    start: svg_path.point(10.0, 85.0),
    end: svg_path.point(120.0, 15.0),
  )
}

fn reverse_diagonal_line() -> svg_path.Segment {
  svg_path.line(
    start: svg_path.point(10.0, 15.0),
    end: svg_path.point(120.0, 85.0),
  )
}

fn horizontal_line() -> svg_path.Segment {
  svg_path.line(
    start: svg_path.point(10.0, 50.0),
    end: svg_path.point(120.0, 50.0),
  )
}

fn vertical_line() -> svg_path.Segment {
  svg_path.line(
    start: svg_path.point(65.0, 10.0),
    end: svg_path.point(65.0, 90.0),
  )
}

fn snake_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(15.0, 55.0),
    control1: svg_path.point(135.0, 0.0),
    control2: svg_path.point(-20.0, 110.0),
    end: svg_path.point(105.0, 55.0),
  )
}

fn fish_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(25.0, 40.0),
    control1: svg_path.point(155.0, 100.0),
    control2: svg_path.point(155.0, 10.0),
    end: svg_path.point(25.0, 70.0),
  )
}

fn del_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(100.0, 20.0),
    control1: svg_path.point(120.0, 60.0),
    control2: svg_path.point(0.0, 140.0),
    end: svg_path.point(100.0, 40.0),
  )
}

fn flourish_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(100.0, 20.0),
    control1: svg_path.point(120.0, 60.0),
    control2: svg_path.point(20.0, 140.0),
    end: svg_path.point(120.0, 40.0),
  )
}

fn left_hook_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(120.0, 120.0),
    control1: svg_path.point(121.0, 120.0),
    control2: svg_path.point(20.0, 20.0),
    end: svg_path.point(120.0, 20.0),
  )
}

fn half_circle_arc(sweep sweep: Bool) -> svg_path.Segment {
  svg_path.arc(
    start: svg_path.point(20.0, 80.0),
    radius: svg_path.point(40.0, 40.0),
    x_axis_rotation: 0.0,
    large_arc: False,
    sweep: sweep,
    end: svg_path.point(100.0, 80.0),
  )
}

fn rotated_arc(sweep sweep: Bool) -> svg_path.Segment {
  svg_path.arc(
    start: svg_path.point(30.0, 80.0),
    radius: svg_path.point(55.0, 25.0),
    x_axis_rotation: 30.0,
    large_arc: False,
    sweep: sweep,
    end: svg_path.point(120.0, 40.0),
  )
}

fn large_arc(sweep sweep: Bool) -> svg_path.Segment {
  svg_path.arc(
    start: svg_path.point(20.0, 70.0),
    radius: svg_path.point(50.0, 35.0),
    x_axis_rotation: 0.0,
    large_arc: True,
    sweep: sweep,
    end: svg_path.point(100.0, 70.0),
  )
}

fn segment_derivative_angles(segments: List(svg_path.Segment)) -> List(Float) {
  segments
  |> list.flat_map(fn(segment) {
    [
      segment_derivative_angle(segment, at: 0.1),
      segment_derivative_angle(segment, at: 0.9),
    ]
  })
}

fn segment_derivative_angle(segment: svg_path.Segment, at t: Float) -> Float {
  let assert Ok(derivative) = svg_path.segment_derivative(segment, at: t)

  maths.atan2(derivative.y, derivative.x)
  |> radians_to_degrees
  |> normalize_degrees
}

fn radians_to_degrees(radians: Float) -> Float {
  radians *. 180.0 /. maths.pi()
}

fn normalize_degrees(degrees: Float) -> Float {
  case degrees <. 0.0 {
    True -> degrees +. 360.0
    False ->
      case degrees >=. 360.0 {
        True -> degrees -. 360.0
        False -> degrees
      }
  }
}

fn rotate_to_smallest_positive_angle(angles: List(Float)) -> List(Float) {
  case smallest_positive_angle_index(angles, 0, -1, 0.0) {
    -1 -> angles
    index -> rotate_list(angles, at: index)
  }
}

fn smallest_positive_angle_index(
  angles: List(Float),
  position: Int,
  best_index: Int,
  best_angle: Float,
) -> Int {
  case angles {
    [] -> best_index
    [angle, ..rest]
      if angle >. 0.0 && { best_index < 0 || angle <. best_angle }
    -> smallest_positive_angle_index(rest, position + 1, position, angle)
    [_, ..rest] ->
      smallest_positive_angle_index(rest, position + 1, best_index, best_angle)
  }
}

fn unwrap_angles(angles: List(Float)) -> List(Float) {
  case angles {
    [] -> []
    [first, ..rest] ->
      unwrap_angles_loop(rest, previous: first, offset: 0.0, unwrapped: [first])
  }
}

fn unwrap_angles_loop(
  angles: List(Float),
  previous previous: Float,
  offset offset: Float,
  unwrapped unwrapped: List(Float),
) -> List(Float) {
  case angles {
    [] -> list.reverse(unwrapped)
    [angle, ..rest] -> {
      let offset = case angle +. offset <. previous {
        True -> offset +. 360.0
        False -> offset
      }
      let angle = angle +. offset

      unwrap_angles_loop(rest, previous: angle, offset: offset, unwrapped: [
        angle,
        ..unwrapped
      ])
    }
  }
}

fn nondecreasing(values: List(Float), tolerance tolerance: Float) -> Bool {
  case values {
    [] | [_] -> True
    [first, second, ..rest] ->
      first <=. second +. tolerance
      && nondecreasing([second, ..rest], tolerance: tolerance)
  }
}

fn rotate_list(items: List(a), at index: Int) -> List(a) {
  list.append(list.drop(items, index), take(items, index))
}

fn take(items: List(a), count: Int) -> List(a) {
  take_loop(items, count, [])
}

fn take_loop(items: List(a), count: Int, taken: List(a)) -> List(a) {
  case count <= 0 {
    True -> list.reverse(taken)
    False ->
      case items {
        [] -> list.reverse(taken)
        [first, ..rest] -> take_loop(rest, count - 1, [first, ..taken])
      }
  }
}

fn multiples_of_10_degrees() -> List(Float) {
  int.range(from: 0, to: 35, with: [], run: fn(angles, i) { [i, ..angles] })
  |> list.reverse
  |> list.map(fn(i) { int.to_float(i) *. 10.0 })
}

fn original_support_value(
  segment: svg_path.Segment,
  angle: Float,
) -> Result(Float, svg_path.Error) {
  use point <- result.try(segment_support_point(segment, angle))

  Ok(point_support(point, degrees: angle))
}

fn hull_support_value(
  segments: List(svg_path.Segment),
  angle: Float,
) -> Result(Float, svg_path.Error) {
  use point <- result.try(segments_support_point(segments, angle))

  Ok(point_support(point, degrees: angle))
}

fn segments_support_point(
  segments: List(svg_path.Segment),
  angle: Float,
) -> Result(svg_path.Point, svg_path.Error) {
  case segments {
    [] -> Error(svg_path.EmptySubpath)
    [first, ..rest] -> {
      use point <- result.try(segment_support_point(first, angle))
      segments_support_point_loop(rest, angle, point)
    }
  }
}

fn segments_support_point_loop(
  segments: List(svg_path.Segment),
  angle: Float,
  best: svg_path.Point,
) -> Result(svg_path.Point, svg_path.Error) {
  case segments {
    [] -> Ok(best)
    [segment, ..rest] -> {
      use point <- result.try(segment_support_point(segment, angle))
      let best = case
        point_support(point, degrees: angle)
        >. point_support(best, degrees: angle)
      {
        True -> point
        False -> best
      }

      segments_support_point_loop(rest, angle, best)
    }
  }
}

fn segment_support_point(
  segment: svg_path.Segment,
  angle: Float,
) -> Result(svg_path.Point, svg_path.Error) {
  let direction = angle_direction(angle)
  use t <- result.try(
    svg_path.segment_minimize(segment, measure: fn(point) {
      0.0 -. dot(point, direction)
    }),
  )

  svg_path.segment_point(segment, at: t)
}

fn point_support(point: svg_path.Point, degrees degrees: Float) -> Float {
  dot(point, angle_direction(degrees))
}

fn angle_direction(degrees: Float) -> svg_path.Point {
  let radians = degrees *. maths.pi() /. 180.0

  svg_path.point(maths.cos(radians), maths.sin(radians))
}

fn dot(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.x +. a.y *. b.y
}

fn is_line_piece(piece: convex_hull.HullPiece) -> Bool {
  case piece {
    convex_hull.HullLine(_, _) -> True
    convex_hull.HullCurve(_, _) -> False
  }
}

fn near(a: Float, b: Float) -> Bool {
  float.absolute_value(a -. b) <. tolerance
}
