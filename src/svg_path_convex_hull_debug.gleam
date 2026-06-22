import gleam/int
import gleam/io
import gleam/list
import gleam/string
import gleam_community/maths
import svg_path
import svg_path/convex_hull
import svg_path/number_format

const segment_to_draw = FlourishCubic

const print_all_derivative_angles = False

type SegmentToDraw {
  Stem
  Horseshoe
  HorseshoeWide
  DiagonalLine
  ReverseDiagonalLine
  HorizontalLine
  VerticalLine
  SnakeCubic
  FishCubic
  DelCubic
  FlourishCubic
  LeftHookCubic
  HalfCircleArc
  HalfCircleArcReverse
  RotatedArc
  RotatedArcReverse
  LargeArc
  LargeArcReverse
}

type SegmentDerivativeAngles {
  SegmentDerivativeAngles(
    index: Int,
    at_01: Result(Float, String),
    at_09: Result(Float, String),
  )
}

pub fn main() -> Nil {
  case print_all_derivative_angles {
    True -> io.println_error(all_derivative_angles())
    False -> draw_selected_segment()
  }
}

fn draw_selected_segment() -> Nil {
  let segment = selected_segment()
  let assert Ok(stage) = convex_hull.hull_debug_stage(segment)
  io.println_error(convex_hull.hull_debug_stage_to_string(stage))
  case convex_hull.hull_subpath(segment) {
    Ok(subpath) -> {
      io.println_error("strict closed subpath: Ok")
      print_subpath_derivative_angles(subpath)
    }
    Error(error) ->
      io.println_error("strict closed subpath: Error " <> string.inspect(error))
  }

  let assert Ok(svg) =
    convex_hull.segment_drawing_svg_with_padding(segment, padding: 20.0)

  io.println(svg)
}

fn all_derivative_angles() -> String {
  debug_segments()
  |> list.map(fn(specimen) {
    let #(name, segment) = specimen
    case convex_hull.hull_subpath(segment) {
      Ok(subpath) ->
        name <> "\n" <> segment_derivative_angles(svg_path.segments(subpath))

      Error(error) -> name <> "\nError " <> string.inspect(error)
    }
  })
  |> string.join("\n\n")
}

fn debug_segments() -> List(#(String, svg_path.Segment)) {
  [
    #("stem", stem()),
    #("horseshoe", horseshoe()),
    #("horseshoe_wide", horseshoe_wide()),
    #("snake", snake_cubic()),
    #("fish", fish_cubic()),
    #("del", del_cubic()),
    #("flourish", flourish_cubic()),
    #("left_hook_cubic", left_hook_cubic()),
    #("half_circle_arc", half_circle_arc()),
    #("half_circle_arc_reverse", half_circle_arc_reverse()),
    #("rotated_arc", rotated_arc()),
    #("rotated_arc_reverse", rotated_arc_reverse()),
    #("large_arc", large_arc()),
    #("large_arc_reverse", large_arc_reverse()),
  ]
}

fn selected_segment() -> svg_path.Segment {
  // Toggle the segment under test with `segment_to_draw` above.
  case segment_to_draw {
    Stem -> stem()
    Horseshoe -> horseshoe()
    HorseshoeWide -> horseshoe_wide()
    DiagonalLine -> diagonal_line()
    ReverseDiagonalLine -> reverse_diagonal_line()
    HorizontalLine -> horizontal_line()
    VerticalLine -> vertical_line()
    SnakeCubic -> snake_cubic()
    FishCubic -> fish_cubic()
    DelCubic -> del_cubic()
    FlourishCubic -> flourish_cubic()
    LeftHookCubic -> left_hook_cubic()
    HalfCircleArc -> half_circle_arc()
    HalfCircleArcReverse -> half_circle_arc_reverse()
    RotatedArc -> rotated_arc()
    RotatedArcReverse -> rotated_arc_reverse()
    LargeArc -> large_arc()
    LargeArcReverse -> large_arc_reverse()
  }
}

fn print_subpath_derivative_angles(subpath: svg_path.Subpath) -> Nil {
  print_segment_derivative_angles(svg_path.segments(subpath))
}

fn print_segment_derivative_angles(segments: List(svg_path.Segment)) -> Nil {
  io.println_error(segment_derivative_angles(segments))
}

fn segment_derivative_angles(segments: List(svg_path.Segment)) -> String {
  let lines =
    segments
    |> list.index_map(segment_derivative_angle_record)
    |> rotate_to_smallest_positive_at_01
    |> list.map(format_segment_derivative_angles)

  "derivative angles:\n" <> string.join(lines, "\n")
}

fn segment_derivative_angle_record(
  segment: svg_path.Segment,
  index: Int,
) -> SegmentDerivativeAngles {
  SegmentDerivativeAngles(
    index:,
    at_01: derivative_angle(segment, at: 0.1),
    at_09: derivative_angle(segment, at: 0.9),
  )
}

fn format_segment_derivative_angles(angles: SegmentDerivativeAngles) -> String {
  "segment "
  <> int.to_string(angles.index)
  <> ": t=0.10 "
  <> format_angle_result(angles.at_01)
  <> "deg, t=0.90 "
  <> format_angle_result(angles.at_09)
  <> "deg"
}

fn derivative_angle(
  segment: svg_path.Segment,
  at t: Float,
) -> Result(Float, String) {
  case svg_path.segment_derivative(segment, at: t) {
    Ok(derivative) ->
      maths.atan2(derivative.y, derivative.x)
      |> radians_to_degrees
      |> normalize_degrees
      |> Ok

    Error(error) -> Error(string.inspect(error))
  }
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

fn rotate_to_smallest_positive_at_01(
  angles: List(SegmentDerivativeAngles),
) -> List(SegmentDerivativeAngles) {
  case smallest_positive_at_01_index(angles, 0, -1, 0.0) {
    -1 -> angles
    index -> rotate_list(angles, at: index)
  }
}

fn smallest_positive_at_01_index(
  angles: List(SegmentDerivativeAngles),
  position: Int,
  best_index: Int,
  best_angle: Float,
) -> Int {
  case angles {
    [] -> best_index
    [first, ..rest] -> {
      case first.at_01 {
        Ok(angle)
          if angle >. 0.0 && { best_index < 0 || angle <. best_angle }
        -> smallest_positive_at_01_index(rest, position + 1, position, angle)

        _ ->
          smallest_positive_at_01_index(
            rest,
            position + 1,
            best_index,
            best_angle,
          )
      }
    }
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

fn format_angle_result(angle: Result(Float, String)) -> String {
  case angle {
    Ok(angle) -> format_angle(angle)
    Error(error) -> "Error(" <> error <> ")"
  }
}

fn format_angle(angle: Float) -> String {
  let format =
    number_format.prepare(
      number_format.Options(
        left_decimals: number_format.Succinct,
        right_decimals: number_format.Fixed(2),
      ),
      [],
    )

  number_format.number(angle, with: format)
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

fn half_circle_arc() -> svg_path.Segment {
  half_circle_arc_with_sweep(True)
}

fn half_circle_arc_reverse() -> svg_path.Segment {
  half_circle_arc_with_sweep(False)
}

fn half_circle_arc_with_sweep(sweep: Bool) -> svg_path.Segment {
  svg_path.arc(
    start: svg_path.point(20.0, 80.0),
    radius: svg_path.point(40.0, 40.0),
    x_axis_rotation: 0.0,
    large_arc: False,
    sweep: sweep,
    end: svg_path.point(100.0, 80.0),
  )
}

fn rotated_arc() -> svg_path.Segment {
  rotated_arc_with_sweep(True)
}

fn rotated_arc_reverse() -> svg_path.Segment {
  rotated_arc_with_sweep(False)
}

fn rotated_arc_with_sweep(sweep: Bool) -> svg_path.Segment {
  svg_path.arc(
    start: svg_path.point(30.0, 80.0),
    radius: svg_path.point(55.0, 25.0),
    x_axis_rotation: 30.0,
    large_arc: False,
    sweep: sweep,
    end: svg_path.point(120.0, 40.0),
  )
}

fn large_arc() -> svg_path.Segment {
  large_arc_with_sweep(True)
}

fn large_arc_reverse() -> svg_path.Segment {
  large_arc_with_sweep(False)
}

fn large_arc_with_sweep(sweep: Bool) -> svg_path.Segment {
  svg_path.arc(
    start: svg_path.point(20.0, 70.0),
    radius: svg_path.point(50.0, 35.0),
    x_axis_rotation: 0.0,
    large_arc: True,
    sweep: sweep,
    end: svg_path.point(100.0, 70.0),
  )
}
