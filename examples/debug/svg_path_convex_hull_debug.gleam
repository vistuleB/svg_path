//// Scratch runner for visually debugging `svg_path/convex_hull`.
////
//// This module is parked in `examples/debug` so it is not compiled as part of
//// the package. To run it again, temporarily copy it to the project `src` root
//// and restore any development-only convex hull hooks it references, then run:
////
////     gleam run -m svg_path_convex_hull_debug
////
//// Redirect stdout into `examples/debug/*.svg` to refresh a drawing.

import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import gleam_community/maths
import svg_path
import svg_path/convex_hull
import svg_path/number_format
import svg_path/svg

const segment_to_draw = GeneratedArc22

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
  GeneratedCubic0
  GeneratedArc22
  NearCuspCubic
  NearEndpointArc
  NearEndpointArcReverse
  NearEndpointLine
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
  let #(name, segment) = selected_segment()
  io.println_error("selected segment: " <> name)
  print_segment_probe(segment)
  print_hull_samples(segment)

  case convex_hull.segment_hull(segment) {
    Ok(#(subpath, pieces)) -> {
      io.println_error("segment_hull: Ok")
      io.println_error("hull pieces: " <> hull_pieces_to_string(pieces))
      print_support_comparison(segment, subpath, [0.0, 50.0, 70.0, 120.0])
      print_subpath_derivative_angles(subpath)
      io.println(drawing_svg(segment, subpath, pieces))
    }

    Error(error) -> {
      io.println_error("segment_hull: Error " <> string.inspect(error))
      print_pre_rejection_pieces(segment)
      io.println(drawing_svg(segment, empty_subpath(), []))
    }
  }
}

fn print_pre_rejection_pieces(segment: svg_path.Segment) -> Nil {
  case convex_hull.debug_segment_hull_pieces_before_rejection(segment) {
    Ok(pieces) ->
      io.println_error(
        "pre-rejection hull pieces: " <> hull_pieces_to_precise_string(pieces),
      )
    Error(error) ->
      io.println_error(
        "pre-rejection hull pieces: Error " <> string.inspect(error),
      )
  }

  print_hull_samples(segment)
}

fn print_hull_samples(segment: svg_path.Segment) -> Nil {
  case convex_hull.debug_segment_hull_samples(segment) {
    Ok(#(purified, refined)) -> {
      io.println_error(
        "refined sample count: " <> int.to_string(list.length(refined)),
      )
      io.println_error("refined sample summary: " <> sample_summary(refined))
      print_after_first_duplicate_removal(segment)
      io.println_error(
        "purified samples: " <> debug_samples_to_string(purified),
      )
    }

    Error(error) ->
      io.println_error("debug samples: Error " <> string.inspect(error))
  }
}

fn print_after_first_duplicate_removal(segment: svg_path.Segment) -> Nil {
  case
    convex_hull.debug_segment_hull_samples_after_first_duplicate_removal(
      segment,
    )
  {
    Ok(samples) -> {
      io.println_error(
        "after first duplicate-t removal count: "
        <> int.to_string(list.length(samples)),
      )
      io.println_error(
        "after first duplicate-t removal samples: "
        <> debug_samples_to_string(samples),
      )
    }

    Error(error) ->
      io.println_error(
        "after first duplicate-t removal: Error " <> string.inspect(error),
      )
  }
}

fn debug_samples_to_string(
  samples: List(#(Float, Float, svg_path.Point)),
) -> String {
  samples
  |> list.map(fn(sample) {
    let #(angle, t, point) = sample
    "{angle="
    <> float_to_string(angle)
    <> ", t="
    <> float_to_string(t)
    <> ", point="
    <> point_to_string(point)
    <> "}"
  })
  |> string.join(", ")
}

fn sample_summary(samples: List(#(Float, Float, svg_path.Point))) -> String {
  let start_count =
    samples
    |> list.filter(fn(sample) {
      let #(_, t, _) = sample
      t <. 0.000001
    })
    |> list.length
  let end_count =
    samples
    |> list.filter(fn(sample) {
      let #(_, t, _) = sample
      t >. 0.999999
    })
    |> list.length
  let middle_count = list.length(samples) - start_count - end_count

  "near t=0: "
  <> int.to_string(start_count)
  <> ", near t=1: "
  <> int.to_string(end_count)
  <> ", middle: "
  <> int.to_string(middle_count)
  <> ", transitions: "
  <> sample_transitions_to_string(samples)
}

fn sample_transitions_to_string(
  samples: List(#(Float, Float, svg_path.Point)),
) -> String {
  case samples {
    [] -> ""
    [first, ..rest] ->
      sample_transitions_loop(rest, previous: first, transitions: [])
      |> list.reverse
      |> string.join(", ")
  }
}

fn sample_transitions_loop(
  samples: List(#(Float, Float, svg_path.Point)),
  previous previous: #(Float, Float, svg_path.Point),
  transitions transitions: List(String),
) -> List(String) {
  case samples {
    [] -> transitions
    [sample, ..rest] -> {
      let #(_, previous_t, _) = previous
      let #(angle, t, _) = sample
      let transitions = case support_bucket(previous_t) == support_bucket(t) {
        True -> transitions
        False -> [
          float_to_string(angle)
            <> "deg "
            <> support_bucket(previous_t)
            <> " -> "
            <> support_bucket(t),
          ..transitions
        ]
      }

      sample_transitions_loop(rest, previous: sample, transitions: transitions)
    }
  }
}

fn support_bucket(t: Float) -> String {
  case t <. 0.000001 {
    True -> "t=0"
    False ->
      case t >. 0.999999 {
        True -> "t=1"
        False -> "middle"
      }
  }
}

fn print_segment_probe(segment: svg_path.Segment) -> Nil {
  case svg_path.segment_bounding_box(segment) {
    Ok(box) -> {
      io.println_error("bounding box: " <> bounding_box_to_string(box))
      io.println_error(
        "bounding box diameter: "
        <> float_to_string(svg_path.bounding_box_diameter(box)),
      )
    }
    Error(error) ->
      io.println_error("bounding box: Error " <> string.inspect(error))
  }

  print_initial_10_degree_support_ts(segment)

  [0.0, 90.0, 180.0, 270.0]
  |> list.each(fn(angle) {
    io.println_error(
      "support probe "
      <> format_float(angle)
      <> "deg: "
      <> support_probe(segment, angle),
    )
  })
}

fn print_initial_10_degree_support_ts(segment: svg_path.Segment) -> Nil {
  let lines =
    int.range(from: 0, to: 35, with: [], run: fn(lines, i) {
      let angle = int.to_float(i) *. 10.0
      [format_support_t(segment, angle), ..lines]
    })
    |> list.reverse

  io.println_error(
    "initial 10deg support t values:\n" <> string.join(lines, "\n"),
  )
}

fn format_support_t(segment: svg_path.Segment, angle: Float) -> String {
  let direction = angle_direction(angle)
  let t = case
    svg_path.segment_minimize(segment, measure: fn(point) {
      0.0 -. { point.x *. direction.x +. point.y *. direction.y }
    })
  {
    Ok(t) -> float_to_string(t)
    Error(error) -> "Error(" <> string.inspect(error) <> ")"
  }

  float_to_string(angle) <> "deg: t=" <> t
}

fn support_probe(segment: svg_path.Segment, angle: Float) -> String {
  let direction = angle_direction(angle)
  case
    svg_path.segment_minimize(segment, measure: fn(point) {
      0.0 -. { point.x *. direction.x +. point.y *. direction.y }
    })
  {
    Ok(t) -> {
      case svg_path.segment_point(segment, at: t) {
        Ok(point) ->
          "t=" <> format_float(t) <> ", point=" <> point_to_string(point)
        Error(error) -> "point error " <> string.inspect(error)
      }
    }
    Error(error) -> "minimize error " <> string.inspect(error)
  }
}

fn print_support_comparison(
  segment: svg_path.Segment,
  hull: svg_path.Subpath,
  angles: List(Float),
) -> Nil {
  angles
  |> list.each(fn(angle) {
    io.println_error(
      "support comparison "
      <> format_float(angle)
      <> "deg: "
      <> support_comparison(segment, svg_path.subpath_segments(hull), angle),
    )
  })
}

fn support_comparison(
  segment: svg_path.Segment,
  hull_segments: List(svg_path.Segment),
  angle: Float,
) -> String {
  case support_value(segment, angle), hull_support_value(hull_segments, angle) {
    Ok(original), Ok(#(hull, index)) -> {
      let difference = original -. hull
      "original="
      <> float_to_string(original)
      <> ", hull="
      <> float_to_string(hull)
      <> ", diff="
      <> float_to_string(difference)
      <> ", hull_segment="
      <> int.to_string(index)
    }
    Error(error), _ -> "original error " <> string.inspect(error)
    _, Error(error) -> "hull error " <> string.inspect(error)
  }
}

fn hull_support_value(
  segments: List(svg_path.Segment),
  angle: Float,
) -> Result(#(Float, Int), svg_path.Error) {
  case segments {
    [] -> Error(svg_path.EmptySubpath)
    [first, ..rest] -> {
      use first_value <- result_try_support(support_value(first, angle))
      hull_support_value_loop(rest, angle, first_value, 0, 1)
    }
  }
}

fn hull_support_value_loop(
  segments: List(svg_path.Segment),
  angle: Float,
  best: Float,
  best_index: Int,
  index: Int,
) -> Result(#(Float, Int), svg_path.Error) {
  case segments {
    [] -> Ok(#(best, best_index))
    [segment, ..rest] -> {
      use value <- result_try_support(support_value(segment, angle))
      case value >. best {
        True -> hull_support_value_loop(rest, angle, value, index, index + 1)
        False ->
          hull_support_value_loop(rest, angle, best, best_index, index + 1)
      }
    }
  }
}

fn result_try_support(
  result: Result(Float, svg_path.Error),
  next: fn(Float) -> Result(a, svg_path.Error),
) -> Result(a, svg_path.Error) {
  case result {
    Ok(value) -> next(value)
    Error(error) -> Error(error)
  }
}

fn support_value(
  segment: svg_path.Segment,
  angle: Float,
) -> Result(Float, svg_path.Error) {
  let direction = angle_direction(angle)
  use t <- result_try_minimize(
    svg_path.segment_minimize(segment, measure: fn(point) {
      0.0 -. dot(point, direction)
    }),
  )
  use point <- result_try_point(svg_path.segment_point(segment, at: t))

  Ok(dot(point, direction))
}

fn result_try_minimize(
  result: Result(Float, svg_path.Error),
  next: fn(Float) -> Result(a, svg_path.Error),
) -> Result(a, svg_path.Error) {
  case result {
    Ok(value) -> next(value)
    Error(error) -> Error(error)
  }
}

fn result_try_point(
  result: Result(svg_path.Point, svg_path.Error),
  next: fn(svg_path.Point) -> Result(a, svg_path.Error),
) -> Result(a, svg_path.Error) {
  case result {
    Ok(value) -> next(value)
    Error(error) -> Error(error)
  }
}

fn angle_direction(degrees: Float) -> svg_path.Point {
  let radians = degrees *. maths.pi() /. 180.0

  svg_path.Point(maths.cos(radians), maths.sin(radians))
}

fn dot(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.x +. a.y *. b.y
}

fn drawing_svg(
  segment: svg_path.Segment,
  hull: svg_path.Subpath,
  pieces: List(convex_hull.HullPiece),
) -> String {
  let assert Ok(box) = svg_path.segment_bounding_box(segment)
  let original = svg_path.Path([svg_path.subpath_assert([segment])])
  let hull_path = svg_path.Path([hull])
  let assert Ok(start) = svg_path.segment_point(segment, at: 0.0)
  let assert Ok(end) = svg_path.segment_point(segment, at: 1.0)

  let piece_things =
    pieces
    |> list.index_map(fn(piece, index) {
      svg.StyledPath(
        hull_piece_path(segment, piece),
        hull_piece_style(index, piece),
      )
    })
  let things =
    [
      svg.StyledPath(
        original,
        "fill: none; stroke: #222222; stroke-width: 2; stroke-linecap: round",
      ),
      svg.StyledPath(
        hull_path,
        "fill: rgba(70, 130, 180, 0.08); stroke: #4682b4; stroke-width: 0.8",
      ),
      ..piece_things
    ]
    |> list.append(svg.labeled_point("start", "#e63946", start, 5))
    |> list.append(svg.labeled_point("end", "#2a9d8f", end, 5))

  svg.document(things, view_box: pad_box(box, padding: 20.0))
}

fn hull_piece_path(
  segment: svg_path.Segment,
  piece: convex_hull.HullPiece,
) -> svg_path.Path {
  case piece {
    convex_hull.HullCurve(start_t, end_t) -> {
      let assert Ok(piece_segment) =
        svg_path.segment_between(segment, from: start_t, to: end_t)

      svg_path.Path([svg_path.subpath_assert([piece_segment])])
    }

    convex_hull.HullLine(start_t, end_t) -> {
      let assert Ok(start) = svg_path.segment_point(segment, at: start_t)
      let assert Ok(end) = svg_path.segment_point(segment, at: end_t)

      svg_path.Path([
        svg_path.subpath_assert([svg_path.Line(start: start, end: end)]),
      ])
    }
  }
}

fn hull_piece_style(index: Int, piece: convex_hull.HullPiece) -> String {
  let color = palette(index)

  case piece {
    convex_hull.HullCurve(_, _) ->
      "fill: none; stroke: "
      <> color
      <> "; stroke-width: 3; stroke-linecap: round"

    convex_hull.HullLine(_, _) ->
      "fill: none; stroke: "
      <> color
      <> "; stroke-width: 2.5; stroke-dasharray: 7 4; stroke-linecap: round"
  }
}

fn palette(index: Int) -> String {
  case index % 8 {
    0 -> "rgba(230, 57, 70, 0.76)"
    1 -> "rgba(42, 157, 143, 0.76)"
    2 -> "rgba(244, 162, 97, 0.76)"
    3 -> "rgba(69, 123, 157, 0.76)"
    4 -> "rgba(131, 56, 236, 0.76)"
    5 -> "rgba(255, 0, 110, 0.76)"
    6 -> "rgba(58, 134, 255, 0.76)"
    _ -> "rgba(6, 214, 160, 0.76)"
  }
}

fn hull_pieces_to_string(pieces: List(convex_hull.HullPiece)) -> String {
  pieces
  |> list.map(hull_piece_to_string)
  |> string.join(", ")
}

fn hull_pieces_to_precise_string(
  pieces: List(convex_hull.HullPiece),
) -> String {
  pieces
  |> list.map(hull_piece_to_precise_string)
  |> string.join(", ")
}

fn hull_piece_to_string(piece: convex_hull.HullPiece) -> String {
  case piece {
    convex_hull.HullCurve(start_t, end_t) ->
      "Curve(" <> format_float(start_t) <> ", " <> format_float(end_t) <> ")"
    convex_hull.HullLine(start_t, end_t) ->
      "Line(" <> format_float(start_t) <> ", " <> format_float(end_t) <> ")"
  }
}

fn hull_piece_to_precise_string(piece: convex_hull.HullPiece) -> String {
  case piece {
    convex_hull.HullCurve(start_t, end_t) ->
      "Curve("
      <> float_to_string(start_t)
      <> ", "
      <> float_to_string(end_t)
      <> ")"
    convex_hull.HullLine(start_t, end_t) ->
      "Line("
      <> float_to_string(start_t)
      <> ", "
      <> float_to_string(end_t)
      <> ")"
  }
}

fn bounding_box_to_string(box: svg_path.BoundingBox) -> String {
  "min=" <> point_to_string(box.min) <> ", max=" <> point_to_string(box.max)
}

fn point_to_string(point: svg_path.Point) -> String {
  "(" <> float_to_string(point.x) <> ", " <> float_to_string(point.y) <> ")"
}

fn all_derivative_angles() -> String {
  debug_segments()
  |> list.map(fn(specimen) {
    let #(name, segment) = specimen
    case convex_hull.segment_hull(segment) {
      Ok(#(subpath, _)) ->
        name
        <> "\n"
        <> segment_derivative_angles(svg_path.subpath_segments(subpath))

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

fn selected_segment() -> #(String, svg_path.Segment) {
  case segment_to_draw {
    Stem -> #("stem", stem())
    Horseshoe -> #("horseshoe", horseshoe())
    HorseshoeWide -> #("horseshoe_wide", horseshoe_wide())
    DiagonalLine -> #("diagonal_line", diagonal_line())
    ReverseDiagonalLine -> #("reverse_diagonal_line", reverse_diagonal_line())
    HorizontalLine -> #("horizontal_line", horizontal_line())
    VerticalLine -> #("vertical_line", vertical_line())
    SnakeCubic -> #("snake_cubic", snake_cubic())
    FishCubic -> #("fish_cubic", fish_cubic())
    DelCubic -> #("del_cubic", del_cubic())
    FlourishCubic -> #("flourish_cubic", flourish_cubic())
    LeftHookCubic -> #("left_hook_cubic", left_hook_cubic())
    HalfCircleArc -> #("half_circle_arc", half_circle_arc())
    HalfCircleArcReverse -> #(
      "half_circle_arc_reverse",
      half_circle_arc_reverse(),
    )
    RotatedArc -> #("rotated_arc", rotated_arc())
    RotatedArcReverse -> #("rotated_arc_reverse", rotated_arc_reverse())
    LargeArc -> #("large_arc", large_arc())
    LargeArcReverse -> #("large_arc_reverse", large_arc_reverse())
    GeneratedCubic0 -> #("generated_cubic_0", generated_cubic_0())
    GeneratedArc22 -> #("generated_arc_22", generated_arc(22))
    NearCuspCubic -> #("near_cusp_cubic", near_cusp_cubic())
    NearEndpointArc -> #("near_endpoint_arc", near_endpoint_arc())
    NearEndpointArcReverse -> #(
      "near_endpoint_arc_reverse",
      near_endpoint_arc_reverse(),
    )
    NearEndpointLine -> #("near_endpoint_line", near_endpoint_line())
  }
}

fn print_subpath_derivative_angles(subpath: svg_path.Subpath) -> Nil {
  io.println_error(
    segment_derivative_angles(svg_path.subpath_segments(subpath)),
  )
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
    Ok(angle) -> format_float(angle)
    Error(error) -> "Error(" <> error <> ")"
  }
}

fn format_float(value: Float) -> String {
  let format =
    number_format.prepare(
      number_format.Options(
        left_decimals: number_format.Succinct,
        right_decimals: number_format.Fixed(2),
      ),
      [],
    )

  number_format.number(value, with: format)
}

fn float_to_string(value: Float) -> String {
  float.to_string(value)
}

fn pad_box(
  box: svg_path.BoundingBox,
  padding padding: Float,
) -> svg_path.BoundingBox {
  svg_path.BoundingBox(
    min: svg_path.Point(box.min.x -. padding, box.min.y -. padding),
    max: svg_path.Point(box.max.x +. padding, box.max.y +. padding),
  )
}

fn empty_subpath() -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(0.0, 0.0),
    ),
  ])
}

fn stem() -> svg_path.Segment {
  svg_path.CubicBezier(
    start: svg_path.Point(5.0, 70.0),
    control1: svg_path.Point(30.0, 20.0),
    control2: svg_path.Point(65.0, 105.0),
    end: svg_path.Point(95.0, 30.0),
  )
}

fn horseshoe() -> svg_path.Segment {
  svg_path.CubicBezier(
    start: svg_path.Point(20.0, 80.0),
    control1: svg_path.Point(20.0, 5.0),
    control2: svg_path.Point(100.0, 5.0),
    end: svg_path.Point(100.0, 80.0),
  )
}

fn horseshoe_wide() -> svg_path.Segment {
  svg_path.CubicBezier(
    start: svg_path.Point(20.0, 90.0),
    control1: svg_path.Point(-25.0, 0.0),
    control2: svg_path.Point(145.0, 0.0),
    end: svg_path.Point(100.0, 90.0),
  )
}

fn diagonal_line() -> svg_path.Segment {
  svg_path.Line(
    start: svg_path.Point(10.0, 85.0),
    end: svg_path.Point(120.0, 15.0),
  )
}

fn reverse_diagonal_line() -> svg_path.Segment {
  svg_path.Line(
    start: svg_path.Point(10.0, 15.0),
    end: svg_path.Point(120.0, 85.0),
  )
}

fn horizontal_line() -> svg_path.Segment {
  svg_path.Line(
    start: svg_path.Point(10.0, 50.0),
    end: svg_path.Point(120.0, 50.0),
  )
}

fn vertical_line() -> svg_path.Segment {
  svg_path.Line(
    start: svg_path.Point(65.0, 10.0),
    end: svg_path.Point(65.0, 90.0),
  )
}

fn snake_cubic() -> svg_path.Segment {
  svg_path.CubicBezier(
    start: svg_path.Point(15.0, 55.0),
    control1: svg_path.Point(135.0, 0.0),
    control2: svg_path.Point(-20.0, 110.0),
    end: svg_path.Point(105.0, 55.0),
  )
}

fn fish_cubic() -> svg_path.Segment {
  svg_path.CubicBezier(
    start: svg_path.Point(25.0, 40.0),
    control1: svg_path.Point(155.0, 100.0),
    control2: svg_path.Point(155.0, 10.0),
    end: svg_path.Point(25.0, 70.0),
  )
}

fn del_cubic() -> svg_path.Segment {
  svg_path.CubicBezier(
    start: svg_path.Point(100.0, 20.0),
    control1: svg_path.Point(120.0, 60.0),
    control2: svg_path.Point(0.0, 140.0),
    end: svg_path.Point(100.0, 40.0),
  )
}

fn flourish_cubic() -> svg_path.Segment {
  svg_path.CubicBezier(
    start: svg_path.Point(100.0, 20.0),
    control1: svg_path.Point(120.0, 60.0),
    control2: svg_path.Point(20.0, 140.0),
    end: svg_path.Point(120.0, 40.0),
  )
}

fn left_hook_cubic() -> svg_path.Segment {
  svg_path.CubicBezier(
    start: svg_path.Point(120.0, 120.0),
    control1: svg_path.Point(121.0, 120.0),
    control2: svg_path.Point(20.0, 20.0),
    end: svg_path.Point(120.0, 20.0),
  )
}

fn near_cusp_cubic() -> svg_path.Segment {
  svg_path.CubicBezier(
    start: svg_path.Point(0.0, 0.0),
    control1: svg_path.Point(100.0, 0.0),
    control2: svg_path.Point(-100.0, 0.0),
    end: svg_path.Point(0.001, 0.0),
  )
}

fn half_circle_arc() -> svg_path.Segment {
  half_circle_arc_with_sweep(True)
}

fn half_circle_arc_reverse() -> svg_path.Segment {
  half_circle_arc_with_sweep(False)
}

fn half_circle_arc_with_sweep(sweep: Bool) -> svg_path.Segment {
  svg_path.Arc(
    start: svg_path.Point(20.0, 80.0),
    radius: svg_path.Point(40.0, 40.0),
    x_axis_rotation: 0.0,
    large_arc: False,
    sweep: sweep,
    end: svg_path.Point(100.0, 80.0),
  )
}

fn rotated_arc() -> svg_path.Segment {
  rotated_arc_with_sweep(True)
}

fn rotated_arc_reverse() -> svg_path.Segment {
  rotated_arc_with_sweep(False)
}

fn rotated_arc_with_sweep(sweep: Bool) -> svg_path.Segment {
  svg_path.Arc(
    start: svg_path.Point(30.0, 80.0),
    radius: svg_path.Point(55.0, 25.0),
    x_axis_rotation: 30.0,
    large_arc: False,
    sweep: sweep,
    end: svg_path.Point(120.0, 40.0),
  )
}

fn large_arc() -> svg_path.Segment {
  large_arc_with_sweep(True)
}

fn large_arc_reverse() -> svg_path.Segment {
  large_arc_with_sweep(False)
}

fn large_arc_with_sweep(sweep: Bool) -> svg_path.Segment {
  svg_path.Arc(
    start: svg_path.Point(20.0, 70.0),
    radius: svg_path.Point(50.0, 35.0),
    x_axis_rotation: 0.0,
    large_arc: True,
    sweep: sweep,
    end: svg_path.Point(100.0, 70.0),
  )
}

fn near_endpoint_arc() -> svg_path.Segment {
  near_endpoint_arc_with_sweep(True)
}

fn near_endpoint_arc_reverse() -> svg_path.Segment {
  near_endpoint_arc_with_sweep(False)
}

fn near_endpoint_arc_with_sweep(sweep: Bool) -> svg_path.Segment {
  svg_path.Arc(
    start: svg_path.Point(10.0, 10.0),
    radius: svg_path.Point(40.0, 30.0),
    x_axis_rotation: 15.0,
    large_arc: False,
    sweep: sweep,
    end: svg_path.Point(10.0001, 10.0001),
  )
}

fn near_endpoint_line() -> svg_path.Segment {
  svg_path.Line(
    start: svg_path.Point(10.0, 10.0),
    end: svg_path.Point(10.0001, 10.0001),
  )
}

fn generated_cubic_0() -> svg_path.Segment {
  svg_path.CubicBezier(
    start: svg_path.Point(0.0, 0.0),
    control1: svg_path.Point(0.0, 0.0),
    control2: svg_path.Point(0.0, 0.0),
    end: svg_path.Point(0.0, 0.0),
  )
}

fn generated_arc(i: Int) -> svg_path.Segment {
  let x = int.to_float(i) +. 1.0
  let scale = case i % 4 {
    0 -> 1.0
    1 -> 0.05
    2 -> 40.0
    _ -> 8.0
  }

  svg_path.Arc(
    start: svg_path.Point(scale *. wave(x, 5.0), scale *. wave(x, 7.0)),
    radius: svg_path.Point(
      1.0 +. scale *. float.absolute_value(wave(x, 11.0)),
      1.0 +. scale *. float.absolute_value(wave(x, 13.0)),
    ),
    x_axis_rotation: normalize_degrees(wave(x, 17.0)),
    large_arc: i % 3 == 0,
    sweep: i % 2 == 0,
    end: svg_path.Point(
      scale *. { wave(x, 19.0) +. 0.5 },
      scale *. { wave(x, 23.0) -. 0.5 },
    ),
  )
}

fn wave(i: Float, salt: Float) -> Float {
  maths.sin(i *. salt *. 12.9898) *. 50.0
}
