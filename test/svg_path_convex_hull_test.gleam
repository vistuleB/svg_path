import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam_community/maths
import svg_path
import svg_path/convex_hull
import svg_path/transform

const tolerance = 0.000001

const support_unit_diameter_tolerance = 0.00000002

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

pub fn segment_hull_returns_two_line_pieces_for_point_cubic_test() {
  let segment =
    svg_path.cubic_bezier(
      start: svg_path.point(0.0, 0.0),
      control1: svg_path.point(0.0, 0.0),
      control2: svg_path.point(0.0, 0.0),
      end: svg_path.point(0.0, 0.0),
    )
  let assert Ok(#(subpath, pieces)) = convex_hull.segment_hull(segment)

  assert svg_path.is_closed(subpath)
  assert list.length(svg_path.segments(subpath)) == 2
  assert pieces
    == [
      convex_hull.HullLine(0.0, 0.0),
      convex_hull.HullLine(0.0, 0.0),
    ]
}

pub fn segment_hull_returns_curve_and_chord_for_quadratic_test() {
  let segment =
    svg_path.quadratic_bezier(
      start: svg_path.point(0.0, 0.0),
      control: svg_path.point(5.0, 10.0),
      end: svg_path.point(10.0, 0.0),
    )
  let assert Ok(#(subpath, pieces)) = convex_hull.segment_hull(segment)

  assert svg_path.is_closed(subpath)
  assert pieces
    == [
      convex_hull.HullCurve(0.0, 1.0),
      convex_hull.HullLine(1.0, 0.0),
    ]
}

pub fn segment_hull_handles_near_endpoint_arc_as_curve_and_chord_test() {
  let assert Ok(#(subpath, pieces)) =
    convex_hull.segment_hull(near_endpoint_arc(sweep: True))

  assert svg_path.is_closed(subpath)
  assert pieces
    == [
      convex_hull.HullCurve(0.0, 1.0),
      convex_hull.HullLine(1.0, 0.0),
    ]
}

pub fn subpath_hull_returns_closed_hull_for_l_shaped_polyline_test() {
  let segments = [
    svg_path.line(
      start: svg_path.point(0.0, 0.0),
      end: svg_path.point(20.0, 0.0),
    ),
    svg_path.line(
      start: svg_path.point(20.0, 0.0),
      end: svg_path.point(20.0, 15.0),
    ),
  ]
  let assert Ok(subpath) = svg_path.subpath(segments)
  let assert Ok(hull) = convex_hull.subpath_hull(subpath)

  assert svg_path.is_closed(hull)
  assert list.length(svg_path.segments(hull)) >= 3
  assert subpath_support_matches_bool(segments, hull)
}

pub fn subpath_hull_handles_curved_subpath_test() {
  let curve =
    svg_path.cubic_bezier(
      start: svg_path.point(0.0, 0.0),
      control1: svg_path.point(30.0, 60.0),
      control2: svg_path.point(80.0, -30.0),
      end: svg_path.point(100.0, 20.0),
    )
  let tail =
    svg_path.line(
      start: svg_path.point(100.0, 20.0),
      end: svg_path.point(135.0, 70.0),
    )
  let segments = [curve, tail]
  let assert Ok(subpath) = svg_path.subpath(segments)
  let assert Ok(hull) = convex_hull.subpath_hull(subpath)

  assert svg_path.is_closed(hull)
  assert list.length(svg_path.segments(hull)) >= 3
  assert subpath_support_matches_bool(segments, hull)
}

pub fn subpath_hull_rejects_empty_subpath_test() {
  assert convex_hull.subpath_hull(svg_path.empty_subpath())
    == Error(convex_hull.PathError(svg_path.EmptySubpath))
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

pub fn adversarial_segment_hulls_pass_geometry_checks_test() {
  assert failing_specimen_reports(adversarial_specimens()) == []
}

pub fn paired_specimen_subpath_hulls_pass_support_checks_test() {
  assert failing_subpath_specimen_reports(paired_subpath_specimens()) == []
}

pub fn transformed_adversarial_segment_hulls_pass_geometry_checks_test() {
  assert failing_specimen_reports(transformed_adversarial_specimens())
    == known_transformed_adversarial_failures()
}

fn known_transformed_adversarial_failures() -> List(String) {
  []
}

fn specimens() -> List(#(String, svg_path.Segment)) {
  list.append(curve_and_line_specimens(), arc_specimens())
}

fn adversarial_specimens() -> List(#(String, svg_path.Segment)) {
  [
    #("tiny_line", tiny_line()),
    #("almost_horizontal_line", almost_horizontal_line()),
    #("almost_vertical_line", almost_vertical_line()),
    #("nearly_straight_cubic", nearly_straight_cubic()),
    #("tiny_cubic", tiny_cubic()),
    #("flat_cubic", flat_cubic()),
    #("far_control_cubic", far_control_cubic()),
    #("endpoint_control_cubic", endpoint_control_cubic()),
    #("opposite_far_controls_cubic", opposite_far_controls_cubic()),
    #("near_cusp_cubic", near_cusp_cubic()),
    #("wide_loop_cubic", wide_loop_cubic()),
    #("narrow_loop_cubic", narrow_loop_cubic()),
    #("flat_arc", flat_arc(sweep: True)),
    #("flat_arc_reverse", flat_arc(sweep: False)),
    #("tall_arc", tall_arc(sweep: True)),
    #("tall_arc_reverse", tall_arc(sweep: False)),
    #("rotated_large_arc", rotated_large_arc(sweep: True)),
    #("rotated_large_arc_reverse", rotated_large_arc(sweep: False)),
    #("near_endpoint_arc", near_endpoint_arc(sweep: True)),
    #("near_endpoint_arc_reverse", near_endpoint_arc(sweep: False)),
  ]
  |> list.append(generated_cubic_specimens())
  |> list.append(generated_arc_specimens())
  |> list.append(reversed_generated_witness_specimens())
}

fn transformed_adversarial_specimens() -> List(#(String, svg_path.Segment)) {
  adversarial_specimens()
  |> list.take(14)
  |> list.flat_map(fn(specimen) {
    let #(name, segment) = specimen

    list.append(transformed_specimen_variants(name, segment), [
      Ok(#("reverse_" <> name, svg_path.reverse_segment(segment))),
    ])
    |> list.filter_map(fn(result) { result })
  })
}

fn paired_subpath_specimens() -> List(#(String, List(svg_path.Segment))) {
  curve_and_line_specimens()
  |> list.take(8)
  |> adjacent_pairs
  |> list.filter_map(fn(pair) {
    let #(#(left_name, left), #(right_name, right)) = pair
    use connected_right <- result.try(connect_segment_after(
      right,
      svg_path.segment_end(left),
    ))
    Ok(#(left_name <> "_then_" <> right_name, [left, connected_right]))
  })
}

fn connect_segment_after(
  segment: svg_path.Segment,
  point: svg_path.Point,
) -> Result(svg_path.Segment, Nil) {
  let start = svg_path.segment_start(segment)
  let matrix = transform.translate(x: point.x -. start.x, y: point.y -. start.y)
  transform.segment(segment, by: matrix)
  |> result.map_error(fn(_) { Nil })
}

fn transformed_specimen_variants(
  name: String,
  segment: svg_path.Segment,
) -> List(Result(#(String, svg_path.Segment), Nil)) {
  [
    #("translated", transform.translate(x: 37.0, y: -19.0)),
    #("rotated", transform.rotate(degrees: 37.0)),
    #("scaled", transform.scale(factor: 1.7)),
    #("reflected_x", transform.scale_xy(x: -1.0, y: 1.0)),
    #("reflected_y", transform.scale_xy(x: 1.0, y: -1.0)),
    #("stretched", transform.scale_xy(x: 0.25, y: 3.0)),
    #("skewed_x", transform.skew_x(degrees: 12.0)),
  ]
  |> list.map(fn(variant) {
    let #(suffix, matrix) = variant
    transform_specimen(name <> "_" <> suffix, segment, matrix)
  })
}

fn transform_specimen(
  name: String,
  segment: svg_path.Segment,
  matrix: transform.Matrix,
) -> Result(#(String, svg_path.Segment), Nil) {
  case transform.segment(segment, by: matrix) {
    Ok(segment) -> Ok(#(name, segment))
    Error(_) -> Error(Nil)
  }
}

fn failing_specimen_reports(
  specimens: List(#(String, svg_path.Segment)),
) -> List(String) {
  specimens
  |> list.filter_map(fn(specimen) {
    let #(name, segment) = specimen

    case hull_failure_reason(segment) {
      Ok(Nil) -> Error(Nil)
      Error(reason) -> Ok(name <> ": " <> reason)
    }
  })
}

fn failing_subpath_specimen_reports(
  specimens: List(#(String, List(svg_path.Segment))),
) -> List(String) {
  specimens
  |> list.filter_map(fn(specimen) {
    let #(name, segments) = specimen

    case subpath_hull_failure_reason(segments) {
      Ok(Nil) -> Error(Nil)
      Error(reason) -> Ok(name <> ": " <> reason)
    }
  })
}

fn hull_failure_reason(segment: svg_path.Segment) -> Result(Nil, String) {
  case convex_hull.segment_hull(segment) {
    Error(error) -> Error("segment_hull returned " <> string.inspect(error))
    Ok(#(subpath, pieces)) -> {
      case svg_path.is_closed(subpath) {
        False -> Error("hull subpath is not closed")
        True ->
          case list.length(svg_path.segments(subpath)) >= 2 {
            False -> Error("hull has fewer than two segments")
            True ->
              case list.length(pieces) >= 2 {
                False -> Error("hull has fewer than two pieces")
                True ->
                  case hull_derivative_angles_are_nondecreasing(subpath) {
                    False -> Error("derivative angles are not nondecreasing")
                    True ->
                      case support_mismatch_report(segment, subpath) {
                        Ok(report) ->
                          Error("support values do not match: " <> report)
                        Error(Nil) -> Ok(Nil)
                      }
                  }
              }
          }
      }
    }
  }
}

fn subpath_hull_failure_reason(
  segments: List(svg_path.Segment),
) -> Result(Nil, String) {
  case svg_path.subpath(segments) {
    Error(error) ->
      Error("subpath constructor returned " <> string.inspect(error))
    Ok(subpath) -> {
      case convex_hull.subpath_hull(subpath) {
        Error(error) -> Error("subpath_hull returned " <> string.inspect(error))
        Ok(hull) -> {
          case svg_path.is_closed(hull) {
            False -> Error("hull subpath is not closed")
            True ->
              case list.length(svg_path.segments(hull)) >= 2 {
                False -> Error("hull has fewer than two segments")
                True ->
                  case subpath_support_matches(segments, hull) {
                    Ok(Nil) -> Ok(Nil)
                    Error(report) ->
                      Error("support values do not match: " <> report)
                  }
              }
          }
        }
      }
    }
  }
}

fn hull_derivative_angles_are_nondecreasing(subpath: svg_path.Subpath) -> Bool {
  subpath
  |> svg_path.segments
  |> segment_derivative_angles
  |> rotate_to_smallest_positive_angle
  |> unwrap_angles
  |> nondecreasing(tolerance: 0.0)
}

fn support_mismatch_report(
  segment: svg_path.Segment,
  hull: svg_path.Subpath,
) -> Result(String, Nil) {
  support_mismatch_report_loop(multiples_of_10_degrees(), segment, hull)
}

fn support_mismatch_report_loop(
  angles: List(Float),
  segment: svg_path.Segment,
  hull: svg_path.Subpath,
) -> Result(String, Nil) {
  case angles {
    [] -> Error(Nil)
    [angle, ..rest] -> {
      case support_matches_at_angle(segment, hull, angle) {
        Ok(Nil) -> support_mismatch_report_loop(rest, segment, hull)
        Error(report) -> Ok(report)
      }
    }
  }
}

fn support_matches_at_angle(
  segment: svg_path.Segment,
  hull: svg_path.Subpath,
  angle: Float,
) -> Result(Nil, String) {
  case
    original_support_value(segment, angle),
    hull_support_value(svg_path.segments(hull), angle)
  {
    Ok(original), Ok(hull) -> {
      let difference = float.absolute_value(original -. hull)

      let support_tolerance = support_tolerance(segment)

      case difference <. support_tolerance {
        True -> Ok(Nil)
        False ->
          Error(
            "angle="
            <> float.to_string(angle)
            <> " original="
            <> float.to_string(original)
            <> " hull="
            <> float.to_string(hull)
            <> " diff="
            <> float.to_string(difference)
            <> " tolerance="
            <> float.to_string(support_tolerance),
          )
      }
    }
    Error(error), _ ->
      Error("original support errored " <> string.inspect(error))
    _, Error(error) -> Error("hull support errored " <> string.inspect(error))
  }
}

fn subpath_support_matches(
  original_segments: List(svg_path.Segment),
  hull: svg_path.Subpath,
) -> Result(Nil, String) {
  subpath_support_matches_loop(
    multiples_of_10_degrees(),
    original_segments,
    hull,
  )
}

fn subpath_support_matches_loop(
  angles: List(Float),
  original_segments: List(svg_path.Segment),
  hull: svg_path.Subpath,
) -> Result(Nil, String) {
  case angles {
    [] -> Ok(Nil)
    [angle, ..rest] -> {
      case subpath_support_matches_at_angle(original_segments, hull, angle) {
        Ok(Nil) -> subpath_support_matches_loop(rest, original_segments, hull)
        Error(report) -> Error(report)
      }
    }
  }
}

fn subpath_support_matches_at_angle(
  original_segments: List(svg_path.Segment),
  hull: svg_path.Subpath,
  angle: Float,
) -> Result(Nil, String) {
  let tolerance = subpath_support_tolerance(original_segments)

  case
    hull_support_value(original_segments, angle),
    hull_support_value(svg_path.segments(hull), angle)
  {
    Ok(original_value), Ok(hull_value) -> {
      let difference = float.absolute_value(original_value -. hull_value)
      case difference <. tolerance {
        True -> Ok(Nil)
        False ->
          Error(
            "angle="
            <> float.to_string(angle)
            <> " original="
            <> float.to_string(original_value)
            <> " hull="
            <> float.to_string(hull_value)
            <> " diff="
            <> float.to_string(difference)
            <> " tolerance="
            <> float.to_string(tolerance),
          )
      }
    }
    Error(error), _ ->
      Error("original support errored " <> string.inspect(error))
    _, Error(error) -> Error("hull support errored " <> string.inspect(error))
  }
}

fn subpath_support_matches_bool(
  original_segments: List(svg_path.Segment),
  hull: svg_path.Subpath,
) -> Bool {
  multiples_of_10_degrees()
  |> list.all(fn(angle) {
    case
      hull_support_value(original_segments, angle),
      hull_support_value(svg_path.segments(hull), angle)
    {
      Ok(original_value), Ok(hull_value) ->
        float.absolute_value(original_value -. hull_value)
        <. subpath_support_tolerance(original_segments)
      _, _ -> False
    }
  })
}

fn subpath_support_tolerance(segments: List(svg_path.Segment)) -> Float {
  segments
  |> list.fold(tolerance, fn(best, segment) {
    case svg_path.segment_bounding_box(segment) {
      Ok(box) ->
        float.max(
          best,
          svg_path.bounding_box_diameter(box) *. support_unit_diameter_tolerance,
        )
      Error(_) -> best
    }
  })
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

fn tiny_line() -> svg_path.Segment {
  svg_path.line(
    start: svg_path.point(0.0, 0.0),
    end: svg_path.point(0.00001, 0.00001),
  )
}

fn almost_horizontal_line() -> svg_path.Segment {
  svg_path.line(
    start: svg_path.point(-100.0, 0.0),
    end: svg_path.point(100.0, 0.000001),
  )
}

fn almost_vertical_line() -> svg_path.Segment {
  svg_path.line(
    start: svg_path.point(0.0, -100.0),
    end: svg_path.point(0.000001, 100.0),
  )
}

fn nearly_straight_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(0.0, 0.0),
    control1: svg_path.point(33.0, 0.000001),
    control2: svg_path.point(66.0, -0.000001),
    end: svg_path.point(100.0, 0.0),
  )
}

fn tiny_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(0.0, 0.0),
    control1: svg_path.point(0.00001, 0.00002),
    control2: svg_path.point(-0.00003, 0.00004),
    end: svg_path.point(0.00005, 0.0),
  )
}

fn flat_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(-120.0, 0.0),
    control1: svg_path.point(-60.0, 0.1),
    control2: svg_path.point(60.0, -0.1),
    end: svg_path.point(120.0, 0.0),
  )
}

fn far_control_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(0.0, 0.0),
    control1: svg_path.point(1000.0, 600.0),
    control2: svg_path.point(-900.0, 700.0),
    end: svg_path.point(100.0, 0.0),
  )
}

fn endpoint_control_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(0.0, 0.0),
    control1: svg_path.point(0.0, 0.0),
    control2: svg_path.point(100.0, 0.0),
    end: svg_path.point(100.0, 0.0),
  )
}

fn opposite_far_controls_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(-20.0, -10.0),
    control1: svg_path.point(500.0, -450.0),
    control2: svg_path.point(-520.0, 470.0),
    end: svg_path.point(30.0, 20.0),
  )
}

fn near_cusp_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(0.0, 0.0),
    control1: svg_path.point(100.0, 0.0),
    control2: svg_path.point(-100.0, 0.0),
    end: svg_path.point(0.001, 0.0),
  )
}

fn wide_loop_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(-80.0, 0.0),
    control1: svg_path.point(180.0, 160.0),
    control2: svg_path.point(-180.0, 160.0),
    end: svg_path.point(80.0, 0.0),
  )
}

fn narrow_loop_cubic() -> svg_path.Segment {
  svg_path.cubic_bezier(
    start: svg_path.point(-5.0, 0.0),
    control1: svg_path.point(95.0, 120.0),
    control2: svg_path.point(-95.0, 120.0),
    end: svg_path.point(5.0, 0.0),
  )
}

fn flat_arc(sweep sweep: Bool) -> svg_path.Segment {
  svg_path.arc(
    start: svg_path.point(-100.0, 0.0),
    radius: svg_path.point(120.0, 1.0),
    x_axis_rotation: 0.0,
    large_arc: False,
    sweep: sweep,
    end: svg_path.point(100.0, 0.0),
  )
}

fn tall_arc(sweep sweep: Bool) -> svg_path.Segment {
  svg_path.arc(
    start: svg_path.point(0.0, -100.0),
    radius: svg_path.point(1.0, 120.0),
    x_axis_rotation: 0.0,
    large_arc: False,
    sweep: sweep,
    end: svg_path.point(0.0, 100.0),
  )
}

fn rotated_large_arc(sweep sweep: Bool) -> svg_path.Segment {
  svg_path.arc(
    start: svg_path.point(-70.0, 20.0),
    radius: svg_path.point(95.0, 20.0),
    x_axis_rotation: 73.0,
    large_arc: True,
    sweep: sweep,
    end: svg_path.point(80.0, -10.0),
  )
}

fn near_endpoint_arc(sweep sweep: Bool) -> svg_path.Segment {
  svg_path.arc(
    start: svg_path.point(10.0, 10.0),
    radius: svg_path.point(40.0, 30.0),
    x_axis_rotation: 15.0,
    large_arc: False,
    sweep: sweep,
    end: svg_path.point(10.0001, 10.0001),
  )
}

fn generated_cubic_specimens() -> List(#(String, svg_path.Segment)) {
  int.range(from: 0, to: 35, with: [], run: fn(specimens, i) {
    [#("generated_cubic_" <> int.to_string(i), generated_cubic(i)), ..specimens]
  })
  |> list.reverse
}

fn generated_arc_specimens() -> List(#(String, svg_path.Segment)) {
  [
    #("generated_arc_3", generated_arc(3)),
    #("generated_arc_11", generated_arc(11)),
    #("generated_arc_22", generated_arc(22)),
  ]
}

fn reversed_generated_witness_specimens() -> List(#(String, svg_path.Segment)) {
  [
    #("generated_cubic_0_reverse", svg_path.reverse_segment(generated_cubic(0))),
    #("generated_arc_3_reverse", svg_path.reverse_segment(generated_arc(3))),
    #("generated_arc_11_reverse", svg_path.reverse_segment(generated_arc(11))),
    #("generated_arc_22_reverse", svg_path.reverse_segment(generated_arc(22))),
  ]
}

fn generated_cubic(i: Int) -> svg_path.Segment {
  let x = int.to_float(i)
  let scale = case i % 4 {
    0 -> 1.0
    1 -> 0.01
    2 -> 100.0
    _ -> 10.0
  }

  svg_path.cubic_bezier(
    start: svg_path.point(scale *. wave(x, 3.0), scale *. wave(x, 11.0)),
    control1: svg_path.point(
      scale *. 4.0 *. wave(x, 17.0),
      scale *. 3.0 *. wave(x, 23.0),
    ),
    control2: svg_path.point(
      scale *. 4.0 *. wave(x, 31.0),
      scale *. 3.0 *. wave(x, 41.0),
    ),
    end: svg_path.point(scale *. wave(x, 47.0), scale *. wave(x, 59.0)),
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

  svg_path.arc(
    start: svg_path.point(scale *. wave(x, 5.0), scale *. wave(x, 7.0)),
    radius: svg_path.point(
      1.0 +. scale *. float.absolute_value(wave(x, 11.0)),
      1.0 +. scale *. float.absolute_value(wave(x, 13.0)),
    ),
    x_axis_rotation: normalize_degrees(wave(x, 17.0)),
    large_arc: i % 3 == 0,
    sweep: i % 2 == 0,
    end: svg_path.point(
      scale *. { wave(x, 19.0) +. 0.5 },
      scale *. { wave(x, 23.0) -. 0.5 },
    ),
  )
}

fn wave(i: Float, salt: Float) -> Float {
  maths.sin(i *. salt *. 12.9898) *. 50.0
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

fn adjacent_pairs(items: List(a)) -> List(#(a, a)) {
  case items {
    [] | [_] -> []
    [left, right, ..rest] -> [#(left, right), ..adjacent_pairs([right, ..rest])]
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

fn support_tolerance(segment: svg_path.Segment) -> Float {
  case svg_path.segment_bounding_box(segment) {
    Ok(box) ->
      float.max(
        tolerance,
        svg_path.bounding_box_diameter(box) *. support_unit_diameter_tolerance,
      )
    Error(_) -> tolerance
  }
}
