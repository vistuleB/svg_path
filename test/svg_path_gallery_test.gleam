import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import gleeunit
import svg_path
import svg_path/area
import svg_path/csg
import svg_path/effects
import svg_path/number_format
import svg_path/offset
import svg_path/serialize
import svg_path/stroke
import svg_path/svg
import svg_path/transform
import svg_path/trig
import vec/vec2f

const output_dir = "test/generated/gallery"

const stalled_arc_turn_radius = 40.0

const stalled_arc_turn_distance = 39.999

const stalled_arc_turn_threshold = 0.01

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn gallery_figures_are_generated_test() {
  let _ = ensure_dir(output_dir <> "/README.md")

  let figures = [
    #(
      "gallery-rounded-rectangle-union.svg",
      "Rounded rectangle union",
      rounded_rectangle_union(),
    ),
    #("gallery-stroke-caps.svg", "Stroke caps", stroke_caps()),
    #("gallery-dashed-strokes.svg", "Dashed strokes", dashed_strokes()),
    #("gallery-recursive-dashes.svg", "Recursive dashes", recursive_dashes()),
    #(
      "gallery-figure-eight-band.svg",
      "Figure-eight asymmetric band",
      figure_eight_band(),
    ),
    #(
      "gallery-stroke-offset-tracks.svg",
      "Stroke offset tracks",
      stroke_offset_tracks(),
    ),
    #(
      "gallery-earth-tone-offsets.svg",
      "Earth-tone offsets",
      earth_tone_offsets(),
    ),
    #(
      "gallery-stalled-offset-arc-turns.svg",
      "Stalled offset arc turns",
      stalled_arc_turn_svg(stalled_arc_turn_cases()),
    ),
    #(
      "gallery-stalled-offset-corner-zoom.svg",
      "Stalled offset corner zoom",
      stalled_arc_turn_zoom_svg(stalled_arc_turn_cases()),
    ),
    #("gallery-area-winding.svg", "Area and winding", area_winding()),
  ]

  let entries =
    figures
    |> list.map(fn(figure) {
      let #(filename, title, contents) = figure
      let _ = write_file(output_dir <> "/" <> filename, contents)
      "- [" <> title <> "](" <> filename <> ")"
    })

  let _ =
    write_file(
      output_dir <> "/README.md",
      "# Generated Gallery Figures\n\n" <> string.join(entries, "\n") <> "\n",
    )

  assert figures != []
}

fn rounded_rectangle_union() -> String {
  let rectangles = rectangle_stack()
  let assert Ok(union) =
    rectangles
    |> list.fold(Ok(svg_path.empty_path()), fn(acc, next) {
      use acc <- result_try(acc)
      csg.union(acc, next, using: svg_path.Nonzero)
    })
  let round_options =
    effects.RoundCornerOptions(
      ..effects.default_round_corner_options(),
      failure: effects.AdaptRadius,
    )
  let assert Ok(rounded) =
    effects.round_corners_with(union, radius: 8.0, options: round_options)

  document(
    list.flatten([
      [panel(0.0, "rectangles")],
      [panel(250.0, "raw union")],
      [panel(500.0, "|> rounded_corners(..., 8)")],
      path_layer(
        rectangle_cloud_path(rectangles),
        0.0,
        fill: "#d9f99d",
        stroke: "#365314",
        width: 2.0,
        arrows: "#365314",
      ),
      path_layer(
        union,
        250.0,
        fill: "#bfdbfe",
        stroke: "#1f2937",
        width: 3.0,
        arrows: "#1f2937",
      ),
      path_layer(
        rounded,
        500.0,
        fill: "#bbf7d0",
        stroke: "#14532d",
        width: 3.0,
        arrows: "#14532d",
      ),
    ]),
    width: 730.0,
    height: 220.0,
  )
}

pub fn recursive_dash_failure_zoom_is_generated_test() {
  let _ = ensure_dir("examples/debug/recursive-dash-failure-zoom.svg")
  let drawing = recursive_dashes()
  let _ = write_file("examples/debug/recursive-dash-failure-zoom.svg", drawing)
  Nil
}

pub fn recursive_dash_cap_report_is_generated_test() {
  let _ = ensure_dir("examples/debug/recursive-dash-cap-report.txt")
  let source = place_subpath(recursive_dash_source(), 92.0, 154.0)
  let first_options =
    stroke.Options(
      width: 58.0,
      cap: stroke.Round,
      offset: offset.Options(..offset.default_options(), join: offset.Round),
    )
  let assert Ok(first_stroke) =
    stroke.subpath_dashed_with(
      source,
      options: first_options,
      dash_options: stroke.default_dash_options(
        pattern: [112.0, 48.0],
        offset: 10.0,
      ),
    )
  let outline = nth_subpath(svg_path.subpaths(first_stroke), 2)
  let assert Ok(dashes) =
    stroke.subpath_dashes(outline, pattern: [17.0, 9.0], offset: 3.0)
  let dash = nth_subpath(dashes, 4)
  let options = offset.Options(..offset.default_options(), join: offset.Round)
  let stroke_options =
    stroke.Options(width: 6.0, cap: stroke.Round, offset: options)
  let radius = 3.0
  let positive = offset.subpath_untrimmed_with(dash, distance: radius, options:)
  let negative =
    offset.subpath_untrimmed_with(dash, distance: 0.0 -. radius, options:)
  let start_cap = debug_round_start_cap(dash, radius)
  let end_cap = debug_round_end_cap(dash, radius)
  let candidate = case positive, negative, start_cap, end_cap {
    Ok(positive), Ok(negative), Ok(start_cap), Ok(end_cap) -> {
      let segments =
        list.append(
          svg_path.segments(positive),
          list.append(
            [end_cap],
            list.append(debug_reverse_segments(svg_path.segments(negative)), [
              start_cap,
            ]),
          ),
        )
      case svg_path.subpath_with(segments, policy: svg_path.Wiggle) {
        Ok(candidate) ->
          svg_path.set_closed_with(
            candidate,
            closed: True,
            policy: svg_path.Wiggle,
          )
        Error(error) -> Error(error)
      }
    }
    _, _, _, _ -> Error(svg_path.EmptySubpath)
  }
  let report =
    string.join(
      [
        "dash index: 4",
        "dash segment count: "
          <> int.to_string(list.length(svg_path.segments(dash))),
        "dash length: "
          <> length_result_to_string(svg_path.subpath_length(dash)),
        "start point: " <> point_result_to_string(svg_path.start(dash)),
        "end point: " <> point_result_to_string(svg_path.end(dash)),
        "first derivative length at t=0: "
          <> derivative_length_result_to_string(first_segment(dash), 0.0),
        "last derivative length at t=1: "
          <> derivative_length_result_to_string(last_segment(dash), 1.0),
        "start cap: " <> cap_result_to_string(start_cap),
        "end cap: " <> cap_result_to_string(end_cap),
        "positive individual offset pieces: "
          <> individual_offset_piece_counts_to_string(
          svg_path.segments(dash),
          distance: radius,
          options: options,
        ),
        "negative individual offset pieces: "
          <> individual_offset_piece_counts_to_string(
          svg_path.segments(dash),
          distance: 0.0 -. radius,
          options: options,
        ),
        "positive side: " <> offset_subpath_result_to_string(positive),
        "negative side: " <> offset_subpath_result_to_string(negative),
        "positive inserted joins: "
          <> inserted_join_diameters_to_string(positive),
        "negative inserted joins: "
          <> inserted_join_diameters_to_string(negative),
        "positive raw pair 0->1 before join: "
          <> raw_offset_pair_report(
          svg_path.segments(dash),
          distance: radius,
          options: options,
        ),
        "negative raw pair 0->1 before join: "
          <> raw_offset_pair_report(
          svg_path.segments(dash),
          distance: 0.0 -. radius,
          options: options,
        ),
        "assembled candidate: " <> subpath_result_to_string(candidate),
        "candidate self intersections: "
          <> self_intersections_result_to_string(candidate),
        self_intersection_points_result_to_string(candidate),
        "full stroke result: "
          <> stroke_result_to_string(stroke.subpath_with(
          dash,
          options: stroke_options,
        )),
      ],
      "\n",
    )
  let _ = write_file("examples/debug/recursive-dash-cap-report.txt", report)
  Nil
}

fn stroke_caps() -> String {
  let source =
    svg_path.assert_subpath([
      svg_path.CubicBezier(
        start: svg_path.point(0.0, 20.0),
        control1: svg_path.point(40.0, -58.0),
        control2: svg_path.point(100.0, 78.0),
        end: svg_path.point(150.0, 0.0),
      ),
    ])
  let examples = [
    #(0.0, "butt", offset.Butt),
    #(250.0, "square", offset.Square),
    #(500.0, "round", offset.RoundCap),
  ]

  document(
    list.flatten(
      examples
      |> list.map(fn(example) {
        let #(x, label, cap) = example
        let placed = place_subpath(source, x +. 42.0, 112.0)
        let options =
          offset.Options(..offset.default_options(), join: offset.Round)
        let assert Ok(stroke) =
          offset.subpath_stroke_with(placed, width: 28.0, cap:, options:)
        [
          panel(x, label),
          svg.StyledPath(
            stroke,
            "fill: #fed7aa; stroke: #7c2d12; stroke-width: 2.5; stroke-linejoin: round",
          ),
          svg.StyledPath(
            svg_path.from_subpath(placed),
            "fill: none; stroke: #4c1d95; stroke-width: 2; stroke-dasharray: 5 5; stroke-linecap: round",
          ),
          ..path_arrows(stroke, "#7c2d12", 1.0)
        ]
      }),
    ),
    width: 730.0,
    height: 220.0,
  )
}

fn dashed_strokes() -> String {
  let source = dash_source()
  let examples = [
    #(0.0, "short dashes", [18.0, 12.0], 0.0, "#7f1d1d", "#fecaca"),
    #(
      250.0,
      "offset pattern",
      [26.0, 12.0, 8.0, 12.0],
      18.0,
      "#854d0e",
      "#fde68a",
    ),
    #(500.0, "round caps", [34.0, 18.0], 9.0, "#14532d", "#bbf7d0"),
  ]

  document(
    list.flatten(
      examples
      |> list.map(fn(example) {
        let #(x, label, pattern, dash_offset, stroke_color, fill_color) =
          example
        let placed = place_subpath(source, x +. 22.0, 118.0)
        let options =
          stroke.Options(
            width: 16.0,
            cap: stroke.Round,
            offset: offset.Options(
              ..offset.default_options(),
              join: offset.Round,
            ),
          )
        let assert Ok(dashed) =
          stroke.subpath_dashed_with(
            placed,
            options:,
            dash_options: stroke.default_dash_options(
              pattern:,
              offset: dash_offset,
            ),
          )
        [
          panel(x, label),
          svg.StyledPath(
            dashed,
            "fill: "
              <> fill_color
              <> "; stroke: "
              <> stroke_color
              <> "; stroke-width: 2.2; stroke-linejoin: round",
          ),
          svg.StyledPath(
            svg_path.from_subpath(placed),
            "fill: none; stroke: #334155; stroke-width: 1.8; stroke-dasharray: 5 6; stroke-linecap: round",
          ),
          ..path_arrows(dashed, stroke_color, 0.8)
        ]
      }),
    ),
    width: 730.0,
    height: 220.0,
  )
}

fn recursive_dashes() -> String {
  let source = place_subpath(recursive_dash_source(), 92.0, 154.0)
  let first_options =
    stroke.Options(
      width: 58.0,
      cap: stroke.Round,
      offset: offset.Options(..offset.default_options(), join: offset.Round),
    )
  let assert Ok(first_stroke) =
    stroke.subpath_dashed_with(
      source,
      options: first_options,
      dash_options: stroke.default_dash_options(
        pattern: [112.0, 48.0],
        offset: 10.0,
      ),
    )
  let second_options =
    stroke.Options(
      width: 6.0,
      cap: stroke.Round,
      offset: offset.Options(..offset.default_options(), join: offset.Round),
    )
  let assert Ok(second_paths) =
    recursive_dash_outline_strokes(
      svg_path.subpaths(first_stroke),
      options: second_options,
      accumulated: [],
    )
  let second_path =
    second_paths
    |> list.flat_map(svg_path.subpaths)
    |> svg_path.Path

  document(
    list.flatten([
      [
        svg.Rectangle(
          svg_path.point(8.0, 18.0),
          714.0,
          304.0,
          "fill: #f8fafc; stroke: #cbd5e1; stroke-width: 1.4",
        ),
        svg.StyledPath(
          first_stroke,
          "fill: #fed7aa; stroke: #9a3412; stroke-width: 1.4; stroke-linejoin: round; opacity: 0.42",
        ),
        svg.StyledPath(
          second_path,
          "fill: #fee2e2; stroke: #7f1d1d; stroke-width: 1.7; stroke-linejoin: round",
        ),
      ],
      [
        svg.StyledPath(
          svg_path.from_subpath(source),
          "fill: none; stroke: #334155; stroke-width: 1.8; stroke-linecap: round; stroke-dasharray: 7 7; opacity: 0.75",
        ),
      ],
      path_arrows(second_path, "#7f1d1d", 0.65),
    ]),
    width: 730.0,
    height: 340.0,
  )
}

fn recursive_dash_outline_strokes(
  outlines: List(svg_path.Subpath),
  options options: stroke.Options,
  accumulated accumulated: List(svg_path.Path),
) -> Result(List(svg_path.Path), stroke.Error) {
  case outlines {
    [] -> Ok(list.reverse(accumulated))
    [outline, ..rest] -> {
      case stroke.subpath_dashes(outline, pattern: [17.0, 9.0], offset: 3.0) {
        Ok(dashes) -> {
          use stroked <- result_try(
            stroke_non_degenerate_dashes(dashes, options:, accumulated: []),
          )
          recursive_dash_outline_strokes(rest, options:, accumulated: [
            svg_path.Path(stroked),
            ..accumulated
          ])
        }
        Error(_) -> recursive_dash_outline_strokes(rest, options:, accumulated:)
      }
    }
  }
}

fn stroke_non_degenerate_dashes(
  dashes: List(svg_path.Subpath),
  options options: stroke.Options,
  accumulated accumulated: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), stroke.Error) {
  case dashes {
    [] -> Ok(list.reverse(accumulated))
    [dash, ..rest] -> {
      case svg_path.subpath_length(dash) {
        Ok(length) if length >. 0.1 -> {
          case stroke.subpath_with(dash, options:) {
            Ok(stroked) ->
              stroke_non_degenerate_dashes(
                rest,
                options:,
                accumulated: list.append(
                  svg_path.subpaths(stroked),
                  accumulated,
                ),
              )
            Error(_) ->
              stroke_non_degenerate_dashes(rest, options:, accumulated:)
          }
        }
        _ -> stroke_non_degenerate_dashes(rest, options:, accumulated:)
      }
    }
  }
}

fn nth_subpath(
  subpaths: List(svg_path.Subpath),
  index: Int,
) -> svg_path.Subpath {
  let assert [first, ..rest] = subpaths
  case index <= 0 {
    True -> first
    False -> nth_subpath(rest, index - 1)
  }
}

fn first_segment(subpath: svg_path.Subpath) -> svg_path.Segment {
  let assert [first, ..] = svg_path.segments(subpath)
  first
}

fn last_segment(subpath: svg_path.Subpath) -> svg_path.Segment {
  let assert Ok(last) = list.last(svg_path.segments(subpath))
  last
}

fn debug_round_start_cap(
  source: svg_path.Subpath,
  radius: Float,
) -> Result(svg_path.Segment, svg_path.Error) {
  let first = first_segment(source)
  use tangent <- result_try(debug_unit_tangent(first, 0.0))
  use start <- result_try(svg_path.start(source))
  Ok(debug_round_cap(start, tangent, radius, at_end: False))
}

fn debug_round_end_cap(
  source: svg_path.Subpath,
  radius: Float,
) -> Result(svg_path.Segment, svg_path.Error) {
  let last = last_segment(source)
  use tangent <- result_try(debug_unit_tangent(last, 1.0))
  use end <- result_try(svg_path.end(source))
  Ok(debug_round_cap(end, tangent, radius, at_end: True))
}

fn debug_round_cap(
  center: svg_path.Point,
  tangent: svg_path.Point,
  radius: Float,
  at_end at_end: Bool,
) -> svg_path.Segment {
  let normal = svg_path.point(tangent.y, 0.0 -. tangent.x)
  let positive = add_points(center, scale_point(normal, radius))
  let negative = add_points(center, scale_point(normal, 0.0 -. radius))
  let start = case at_end {
    True -> positive
    False -> negative
  }
  let end = case at_end {
    True -> negative
    False -> positive
  }
  svg_path.Arc(
    start:,
    radius: svg_path.point(radius, radius),
    x_axis_rotation: 0.0,
    large_arc: False,
    sweep: True,
    end:,
  )
}

fn debug_unit_tangent(
  segment: svg_path.Segment,
  t: Float,
) -> Result(svg_path.Point, svg_path.Error) {
  use derivative <- result_try(svg_path.segment_derivative(segment, at: t))
  let length = vec2f.length(derivative)
  case length >. 0.000001 {
    True -> Ok(scale_point(derivative, 1.0 /. length))
    False -> {
      let chord =
        subtract_points(
          svg_path.segment_end(segment),
          svg_path.segment_start(segment),
        )
      let length = vec2f.length(chord)
      case length >. 0.000001 {
        True -> Ok(scale_point(chord, 1.0 /. length))
        False -> Error(svg_path.EmptySubpath)
      }
    }
  }
}

fn debug_reverse_segments(
  segments: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  segments
  |> list.reverse
  |> list.map(svg_path.reverse_segment)
}

fn add_points(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.point(a.x +. b.x, a.y +. b.y)
}

fn subtract_points(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.point(a.x -. b.x, a.y -. b.y)
}

fn scale_point(point: svg_path.Point, factor: Float) -> svg_path.Point {
  svg_path.point(point.x *. factor, point.y *. factor)
}

fn length_result_to_string(result: Result(Float, svg_path.Error)) -> String {
  case result {
    Ok(length) -> debug_float_to_string(length)
    Error(_) -> "Error"
  }
}

fn point_result_to_string(
  result: Result(svg_path.Point, svg_path.Error),
) -> String {
  case result {
    Ok(point) -> point_to_string(point)
    Error(_) -> "Error"
  }
}

fn point_to_string(point: svg_path.Point) -> String {
  "("
  <> debug_float_to_string(point.x)
  <> ", "
  <> debug_float_to_string(point.y)
  <> ")"
}

fn derivative_length_result_to_string(
  segment: svg_path.Segment,
  t: Float,
) -> String {
  case svg_path.segment_derivative(segment, at: t) {
    Ok(derivative) -> debug_float_to_string(vec2f.length(derivative))
    Error(_) -> "Error"
  }
}

fn cap_result_to_string(
  result: Result(svg_path.Segment, svg_path.Error),
) -> String {
  case result {
    Ok(cap) ->
      "Ok(start="
      <> point_to_string(svg_path.segment_start(cap))
      <> ", end="
      <> point_to_string(svg_path.segment_end(cap))
      <> ")"
    Error(_) -> "Error"
  }
}

fn subpath_result_to_string(
  result: Result(svg_path.Subpath, svg_path.Error),
) -> String {
  case result {
    Ok(subpath) ->
      "Ok(segments="
      <> int.to_string(list.length(svg_path.segments(subpath)))
      <> ", closed="
      <> bool_to_string(svg_path.is_closed(subpath))
      <> ", length="
      <> length_result_to_string(svg_path.subpath_length(subpath))
      <> ")"
    Error(_) -> "Error"
  }
}

fn offset_subpath_result_to_string(
  result: Result(svg_path.Subpath, offset.Error),
) -> String {
  case result {
    Ok(subpath) -> subpath_summary_to_string(subpath)
    Error(error) -> offset_error_to_string(error)
  }
}

fn inserted_join_diameters_to_string(
  result: Result(svg_path.Subpath, offset.Error),
) -> String {
  case result {
    Error(error) -> offset_error_to_string(error)
    Ok(subpath) ->
      inserted_join_diameters_loop(
        svg_path.segments(subpath),
        index: 0,
        joins: [],
      )
  }
}

fn raw_offset_pair_report(
  segments: List(svg_path.Segment),
  distance distance: Float,
  options options: offset.Options,
) -> String {
  let raw = raw_offset_segments(segments, distance:, options:, accumulated: [])
  case raw {
    [left, right, ..] -> {
      let left_end = svg_path.segment_end(left)
      let right_start = svg_path.segment_start(right)
      "left_end="
      <> point_to_string(left_end)
      <> "; right_start="
      <> point_to_string(right_start)
      <> "; gap="
      <> debug_float_to_string(vec2f.distance(left_end, with: right_start))
      <> "; intersections="
      <> segment_intersections_to_string(svg_path.segment_intersections(
        left,
        right,
      ))
    }
    _ -> "not enough raw offset segments"
  }
}

fn raw_offset_segments(
  segments: List(svg_path.Segment),
  distance distance: Float,
  options options: offset.Options,
  accumulated accumulated: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case segments {
    [] -> list.reverse(accumulated)
    [segment, ..rest] -> {
      let next = case offset.segment_with(segment, distance:, options:) {
        Ok(subpath) -> list.reverse(svg_path.segments(subpath))
        Error(_) -> []
      }
      raw_offset_segments(
        rest,
        distance:,
        options:,
        accumulated: list.append(next, accumulated),
      )
    }
  }
}

fn segment_intersections_to_string(
  result: Result(List(svg_path.SegmentIntersection), svg_path.Error),
) -> String {
  case result {
    Error(_) -> "Error"
    Ok(intersections) ->
      "count="
      <> int.to_string(list.length(intersections))
      <> "; "
      <> segment_intersection_list_to_string(intersections, index: 0)
  }
}

fn segment_intersection_list_to_string(
  intersections: List(svg_path.SegmentIntersection),
  index index: Int,
) -> String {
  case intersections {
    [] -> ""
    [first, ..rest] -> {
      let svg_path.SegmentIntersection(left_t:, right_t:, point:) = first
      int.to_string(index)
      <> ": left_t="
      <> debug_float_to_string(left_t)
      <> ", right_t="
      <> debug_float_to_string(right_t)
      <> ", point="
      <> point_to_string(point)
      <> case rest {
        [] -> ""
        _ -> "; "
      }
      <> segment_intersection_list_to_string(rest, index: index + 1)
    }
  }
}

fn inserted_join_diameters_loop(
  segments: List(svg_path.Segment),
  index index: Int,
  joins joins: List(String),
) -> String {
  case segments {
    [] -> {
      let joins = list.reverse(joins)
      "count="
      <> int.to_string(list.length(joins))
      <> "; "
      <> string.join(joins, "; ")
    }
    [segment, ..rest] -> {
      let joins = case segment {
        svg_path.Arc(..) -> [
          "segment "
            <> int.to_string(index)
            <> " bbox_diameter="
            <> segment_bounding_box_diameter_to_string(segment)
            <> " chord="
            <> debug_float_to_string(vec2f.distance(
            svg_path.segment_start(segment),
            with: svg_path.segment_end(segment),
          )),
          ..joins
        ]
        _ -> joins
      }
      inserted_join_diameters_loop(rest, index: index + 1, joins:)
    }
  }
}

fn segment_bounding_box_diameter_to_string(
  segment: svg_path.Segment,
) -> String {
  case svg_path.segment_bounding_box(segment) {
    Ok(box) -> debug_float_to_string(svg_path.bounding_box_diameter(box))
    Error(_) -> "Error"
  }
}

fn individual_offset_piece_counts_to_string(
  segments: List(svg_path.Segment),
  distance distance: Float,
  options options: offset.Options,
) -> String {
  let counts =
    individual_offset_piece_counts(segments, distance:, options:, counts: [])
  "counts="
  <> string.join(counts, ",")
  <> "; total="
  <> int.to_string(sum_strings_as_ints(counts, total: 0))
}

fn individual_offset_piece_counts(
  segments: List(svg_path.Segment),
  distance distance: Float,
  options options: offset.Options,
  counts counts: List(String),
) -> List(String) {
  case segments {
    [] -> list.reverse(counts)
    [segment, ..rest] -> {
      let count = case offset.segment_with(segment, distance:, options:) {
        Ok(offset) -> int.to_string(list.length(svg_path.segments(offset)))
        Error(_) -> "Error"
      }
      individual_offset_piece_counts(rest, distance:, options:, counts: [
        count,
        ..counts
      ])
    }
  }
}

fn sum_strings_as_ints(strings: List(String), total total: Int) -> Int {
  case strings {
    [] -> total
    [first, ..rest] -> {
      let value = case first {
        "0" -> 0
        "1" -> 1
        "2" -> 2
        "3" -> 3
        "4" -> 4
        "5" -> 5
        _ -> 0
      }
      sum_strings_as_ints(rest, total: total + value)
    }
  }
}

fn subpath_summary_to_string(subpath: svg_path.Subpath) -> String {
  "Ok(segments="
  <> int.to_string(list.length(svg_path.segments(subpath)))
  <> ", closed="
  <> bool_to_string(svg_path.is_closed(subpath))
  <> ", length="
  <> length_result_to_string(svg_path.subpath_length(subpath))
  <> ")"
}

fn offset_error_to_string(error: offset.Error) -> String {
  case error {
    offset.DegenerateTangent(t) ->
      "DegenerateTangent(" <> debug_float_to_string(t) <> ")"
    _ -> "OffsetError"
  }
}

fn self_intersections_result_to_string(
  result: Result(svg_path.Subpath, svg_path.Error),
) -> String {
  case result {
    Error(_) -> "not computed"
    Ok(subpath) -> {
      case
        svg_path.subpath_self_intersections_with(
          subpath,
          options: svg_path.default_self_intersection_options(),
        )
      {
        Ok(intersections) -> int.to_string(list.length(intersections))
        Error(_) -> "Error"
      }
    }
  }
}

fn self_intersection_points_result_to_string(
  result: Result(svg_path.Subpath, svg_path.Error),
) -> String {
  case result {
    Error(_) -> "candidate self intersection points: not computed"
    Ok(subpath) -> {
      case
        svg_path.subpath_self_intersections_with(
          subpath,
          options: svg_path.default_self_intersection_options(),
        )
      {
        Ok(intersections) ->
          "candidate self intersection points:\n"
          <> self_intersection_points_to_string(intersections, index: 0)
        Error(_) -> "candidate self intersection points: Error"
      }
    }
  }
}

fn self_intersection_points_to_string(
  intersections: List(svg_path.SubpathSelfIntersection),
  index index: Int,
) -> String {
  case intersections {
    [] -> ""
    [intersection, ..rest] -> {
      let svg_path.SubpathSelfIntersection(point:, ..) = intersection
      "  "
      <> int.to_string(index)
      <> ": "
      <> point_to_string(point)
      <> "\n"
      <> self_intersection_points_to_string(rest, index: index + 1)
    }
  }
}

fn stroke_result_to_string(
  result: Result(svg_path.Path, stroke.Error),
) -> String {
  case result {
    Ok(path) ->
      "Ok(subpaths="
      <> int.to_string(list.length(svg_path.subpaths(path)))
      <> ")"
    Error(error) -> stroke_error_name(error)
  }
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "True"
    False -> "False"
  }
}

fn debug_float_to_string(value: Float) -> String {
  number_format.number(
    value,
    with: number_format.prepare(
      number_format.Options(
        left_decimals: number_format.Succinct,
        right_decimals: number_format.AtMost(12),
      ),
      [value],
    ),
  )
}

fn stroke_error_name(error: stroke.Error) -> String {
  case error {
    stroke.OffsetError(offset.DegenerateTangent(t)) ->
      "OffsetError(DegenerateTangent(" <> debug_float_to_string(t) <> "))"
    stroke.OffsetError(_) -> "OffsetError(...)"
    stroke.PathError(_) -> "PathError(...)"
    stroke.InvalidWidth(_) -> "InvalidWidth"
    stroke.InvalidDashLength(_) -> "InvalidDashLength"
    stroke.InvalidDashOffset(_) -> "InvalidDashOffset"
  }
}

fn figure_eight_band() -> String {
  let source = place_subpath(figure_eight(), 430.0, 190.0)
  let options = offset.Options(..offset.default_options(), join: offset.Round)
  let assert Ok(band) =
    offset.subpath_band_with(
      source,
      distance_a: 18.0,
      distance_b: 34.0,
      options:,
    )

  document(
    list.flatten([
      [wide_panel()],
      [
        svg.StyledPath(
          band,
          "fill: #bbf7d0; stroke: #14532d; stroke-width: 3.2; stroke-linejoin: round",
        ),
      ],
      [
        svg.StyledPath(
          svg_path.from_subpath(source),
          "fill: none; stroke: #be123c; stroke-width: 2.2; stroke-dasharray: 7 6; stroke-linecap: round",
        ),
      ],
    ]),
    width: 860.0,
    height: 380.0,
  )
}

fn stroke_offset_tracks() -> String {
  let source = place_subpath(offset_track_source(), 95.0, 160.0)
  let options = offset.Options(..offset.default_options(), join: offset.Round)
  let offsets = [
    #(-42.0, "#7f1d1d"),
    #(-28.0, "#c2410c"),
    #(-14.0, "#b45309"),
    #(14.0, "#047857"),
    #(28.0, "#0369a1"),
    #(42.0, "#6d28d9"),
  ]

  document(
    list.flatten([
      [
        svg.Rectangle(
          svg_path.point(8.0, 18.0),
          714.0,
          244.0,
          "fill: #f8fafc; stroke: #cbd5e1; stroke-width: 1.4",
        ),
      ],
      offsets
        |> list.map(fn(entry) {
          let #(distance, color) = entry
          let assert Ok(track) =
            offset.subpath_untrimmed_with(source, distance:, options:)
          svg.StyledPath(
            svg_path.from_subpath(track),
            "fill: none; stroke: "
              <> color
              <> "; stroke-width: 3.2; stroke-linecap: round; stroke-linejoin: round",
          )
        }),
      [
        svg.StyledPath(
          svg_path.from_subpath(source),
          "fill: none; stroke: #111827; stroke-width: 3.6; stroke-dasharray: 7 6; stroke-linecap: round",
        ),
      ],
      subpath_arrows(source, "#111827", 1.0),
    ]),
    width: 730.0,
    height: 280.0,
  )
}

fn earth_tone_offsets() -> String {
  let options = offset.Options(..offset.default_options(), join: offset.Round)
  let colors = ["#5f4339", "#8a5a3c", "#a36a2d", "#7c6a3d", "#51633f"]
  document(
    list.flatten([
      [panel(0.0, "soft arc")],
      [panel(250.0, "bending line")],
      [panel(500.0, "quiet turn")],
      centered_offset_family(
        source: earth_arc_source(),
        panel_center: svg_path.point(119.0, 112.0),
        distances: [8.0, 16.0, 24.0, 32.0, 40.0],
        colors:,
        options:,
      ),
      centered_offset_family(
        source: earth_bend_source(),
        panel_center: svg_path.point(369.0, 112.0),
        distances: [8.0, 16.0, 24.0, 32.0, 40.0],
        colors:,
        options:,
      ),
      centered_offset_family(
        source: earth_turn_source(),
        panel_center: svg_path.point(619.0, 112.0),
        distances: [8.0, 16.0, 24.0, 32.0, 40.0],
        colors:,
        options:,
      ),
    ]),
    width: 730.0,
    height: 220.0,
  )
}

fn centered_offset_family(
  source source: svg_path.Subpath,
  panel_center panel_center: svg_path.Point,
  distances distances: List(Float),
  colors colors: List(String),
  options options: offset.Options,
) -> svg.ThingsToDraw {
  let tracks =
    distances
    |> list.map(fn(distance) {
      let assert Ok(track) =
        offset.subpath_untrimmed_with(source, distance:, options:)
      track
    })
  let geometry_path = svg_path.Path([source, ..tracks])
  let assert Ok(box) = svg_path.path_bounding_box(geometry_path)
  let center = svg_path.bounding_box_center(box)
  let dx = panel_center.x -. center.x
  let dy = panel_center.y -. center.y
  let assert Ok(placed_source) =
    transform.translate_subpath(source, x: dx, y: dy)
  let placed_tracks =
    tracks
    |> list.map(fn(track) {
      let assert Ok(placed) = transform.translate_subpath(track, x: dx, y: dy)
      placed
    })

  list.flatten([
    placed_tracks
      |> list.index_map(fn(track, index) {
        let color = color_from(colors, index)
        svg.StyledPath(
          svg_path.from_subpath(track),
          "fill: none; stroke: "
            <> color
            <> "; stroke-width: 2.8; stroke-linecap: round; stroke-linejoin: round",
        )
      }),
    [
      svg.StyledPath(
        svg_path.from_subpath(placed_source),
        "fill: none; stroke: #1f1a17; stroke-width: 3.1; stroke-dasharray: 7 6; stroke-linecap: round; stroke-linejoin: round",
      ),
    ],
  ])
}

fn color_from(colors: List(String), index: Int) -> String {
  case colors |> list.drop(index % list.length(colors)) {
    [color, ..] -> color
    [] -> "#1f2937"
  }
}

fn area_winding() -> String {
  let one = square_path(0.0, 0.0, 90.0)
  let twice =
    svg_path.Path([
      square_subpath(0.0, 0.0, 90.0),
      square_subpath(0.0, 0.0, 90.0),
    ])
  let opposite =
    svg_path.Path([
      square_subpath(0.0, 0.0, 90.0),
      square_subpath(0.0, 0.0, 90.0) |> svg_path.reverse_subpath,
    ])

  document(
    list.flatten([
      area_panel(0.0, "one loop", one),
      area_panel(250.0, "twice, same direction", twice),
      area_panel(500.0, "twice, opposite", opposite),
    ]),
    width: 730.0,
    height: 230.0,
  )
}

fn area_panel(
  x: Float,
  label: String,
  path: svg_path.Path,
) -> svg.ThingsToDraw {
  let placed = place_path(path, x +. 78.0, 58.0)
  let signed = area.signed_path(path)
  let assert Ok(nonzero) = area.path(path, using: svg_path.Nonzero)
  let assert Ok(even_odd) = area.path(path, using: svg_path.EvenOdd)
  let assert Ok(absolute) = area.absolute_path(path)

  list.flatten([
    [
      panel(x, label),
      svg.StyledPath(
        placed,
        "fill: #dcfce7; stroke: #166534; stroke-width: 4; stroke-linejoin: round",
      ),
    ],
    path_arrows(placed, "#166534", 1.0),
    [
      svg.Text(
        "signed: " <> area_label(signed),
        text_style("#334155"),
        svg_path.point(x +. 22.0, 170.0),
        11,
      ),
      svg.Text(
        "Nonzero: " <> area_label(nonzero),
        text_style("#334155"),
        svg_path.point(x +. 22.0, 187.0),
        11,
      ),
      svg.Text(
        "EvenOdd: " <> area_label(even_odd),
        text_style("#334155"),
        svg_path.point(x +. 118.0, 187.0),
        11,
      ),
      svg.Text(
        "absolute: " <> area_label(absolute),
        text_style("#334155"),
        svg_path.point(x +. 22.0, 204.0),
        11,
      ),
    ],
  ])
}

fn area_label(value: Float) -> String {
  case value {
    value if value >=. 18_000.0 -> "2A"
    value if value <=. -18_000.0 -> "-2A"
    value if value >=. 9000.0 -> "A"
    value if value <=. -9000.0 -> "-A"
    _ -> "0"
  }
}

fn rectangle_stack() -> List(svg_path.Path) {
  [
    square_path(0.0, 22.0, 96.0),
    rectangle_path(42.0, 0.0, 150.0, 64.0),
    rectangle_path(118.0, 38.0, 210.0, 118.0),
    rectangle_path(24.0, 88.0, 146.0, 146.0),
    rectangle_path(152.0, 86.0, 226.0, 152.0),
  ]
}

fn rectangle_cloud_path(paths: List(svg_path.Path)) -> svg_path.Path {
  paths
  |> list.flat_map(svg_path.subpaths)
  |> svg_path.Path
}

fn square_path(x: Float, y: Float, size: Float) -> svg_path.Path {
  svg_path.from_subpath(square_subpath(x, y, size))
}

fn rectangle_path(
  min_x: Float,
  min_y: Float,
  max_x: Float,
  max_y: Float,
) -> svg_path.Path {
  svg_path.from_subpath(
    svg_path.assert_polygon([
      svg_path.point(min_x, min_y),
      svg_path.point(max_x, min_y),
      svg_path.point(max_x, max_y),
      svg_path.point(min_x, max_y),
    ]),
  )
}

fn square_subpath(x: Float, y: Float, size: Float) -> svg_path.Subpath {
  svg_path.assert_polygon([
    svg_path.point(x, y),
    svg_path.point(x +. size, y),
    svg_path.point(x +. size, y +. size),
    svg_path.point(x, y +. size),
  ])
}

fn figure_eight() -> svg_path.Subpath {
  svg_path.assert_subpath([
    svg_path.CubicBezier(
      start: svg_path.point(0.0, 0.0),
      control1: svg_path.point(-336.0, -234.0),
      control2: svg_path.point(-336.0, 234.0),
      end: svg_path.point(0.0, 0.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.point(0.0, 0.0),
      control1: svg_path.point(336.0, -234.0),
      control2: svg_path.point(336.0, 234.0),
      end: svg_path.point(0.0, 0.0),
    ),
  ])
  |> svg_path.assert_set_closed(closed: True)
}

fn stalled_arc_turn_cases() -> List(
  #(
    String,
    String,
    Int,
    svg_path.Subpath,
    Result(svg_path.Subpath, offset.Error),
  ),
) {
  let subdivisions = [1, 4, 30]
  list.append(
    subdivisions
      |> list.map(fn(count) {
        stalled_arc_turn_case("real arcs", "arc", count, use_arcs: True)
      }),
    subdivisions
      |> list.map(fn(count) {
        stalled_arc_turn_case(
          "cubic approximation",
          "cubic",
          count,
          use_arcs: False,
        )
      }),
  )
}

fn stalled_arc_turn_case(
  row_label: String,
  unit_label: String,
  subdivisions: Int,
  use_arcs use_arcs: Bool,
) -> #(
  String,
  String,
  Int,
  svg_path.Subpath,
  Result(svg_path.Subpath, offset.Error),
) {
  let source = stalled_arc_turn_source(subdivisions, use_arcs:)
  let default = offset.default_options()
  let options =
    offset.Options(
      ..default,
      fitting: offset.FittingOptions(..default.fitting, tolerance: 0.001),
      join: offset.Round,
    )
  let result =
    offset.subpath_untrimmed_with(
      source,
      distance: stalled_arc_turn_distance,
      options:,
    )
  #(row_label, unit_label, subdivisions, source, result)
}

fn stalled_arc_turn_source(
  subdivisions: Int,
  use_arcs use_arcs: Bool,
) -> svg_path.Subpath {
  let r = stalled_arc_turn_radius
  let arc_start = circle_point(0.0, radius: r)
  let arc_end = circle_point(-90.0, radius: r)
  let turn_segments = case use_arcs {
    True -> quarter_turn_arcs(subdivisions)
    False -> quarter_turn_cubics(subdivisions)
  }
  let segments = [
    svg_path.Line(start: svg_path.point(r, r), end: arc_start),
    ..list.append(turn_segments, [
      svg_path.Line(start: arc_end, end: svg_path.point(0.0 -. r, 0.0 -. r)),
    ])
  ]
  let assert Ok(subpath) = svg_path.subpath(segments)
  subpath
}

fn quarter_turn_arcs(subdivisions: Int) -> List(svg_path.Segment) {
  quarter_turn_arcs_loop(0, subdivisions, arcs: [])
}

fn quarter_turn_arcs_loop(
  index: Int,
  subdivisions: Int,
  arcs arcs: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case index >= subdivisions {
    True -> list.reverse(arcs)
    False -> {
      let step = -90.0 /. int.to_float(subdivisions)
      let start_angle = int.to_float(index) *. step
      let end_angle = int.to_float(index + 1) *. step
      quarter_turn_arcs_loop(index + 1, subdivisions, arcs: [
        circle_arc_segment(
          start_angle,
          end_angle,
          radius: stalled_arc_turn_radius,
        ),
        ..arcs
      ])
    }
  }
}

fn circle_arc_segment(
  start_angle: Float,
  end_angle: Float,
  radius radius: Float,
) -> svg_path.Segment {
  svg_path.Arc(
    start: circle_point(start_angle, radius:),
    radius: svg_path.point(radius, radius),
    x_axis_rotation: 0.0,
    large_arc: False,
    sweep: False,
    end: circle_point(end_angle, radius:),
  )
}

fn quarter_turn_cubics(subdivisions: Int) -> List(svg_path.Segment) {
  quarter_turn_cubics_loop(0, subdivisions, cubics: [])
}

fn quarter_turn_cubics_loop(
  index: Int,
  subdivisions: Int,
  cubics cubics: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case index >= subdivisions {
    True -> list.reverse(cubics)
    False -> {
      let step = -90.0 /. int.to_float(subdivisions)
      let start_angle = int.to_float(index) *. step
      let end_angle = int.to_float(index + 1) *. step
      quarter_turn_cubics_loop(index + 1, subdivisions, cubics: [
        circle_arc_cubic(
          start_angle,
          end_angle,
          radius: stalled_arc_turn_radius,
        ),
        ..cubics
      ])
    }
  }
}

fn circle_arc_cubic(
  start_angle: Float,
  end_angle: Float,
  radius radius: Float,
) -> svg_path.Segment {
  let start = circle_point(start_angle, radius:)
  let end = circle_point(end_angle, radius:)
  let k = 4.0 /. 3.0 *. trig.tan_degrees({ end_angle -. start_angle } /. 4.0)
  let start_tangent = circle_angle_tangent(start_angle)
  let end_tangent = circle_angle_tangent(end_angle)
  svg_path.CubicBezier(
    start:,
    control1: add(start, scale(start_tangent, k *. radius)),
    control2: subtract_points(end, scale(end_tangent, k *. radius)),
    end:,
  )
}

fn circle_point(angle: Float, radius radius: Float) -> svg_path.Point {
  svg_path.point(
    clean_zero(radius *. trig.cos_degrees(angle)),
    clean_zero(radius *. trig.sin_degrees(angle)),
  )
}

fn clean_zero(value: Float) -> Float {
  case float.absolute_value(value) <=. 0.000000000001 {
    True -> 0.0
    False -> value
  }
}

fn circle_angle_tangent(angle: Float) -> svg_path.Point {
  svg_path.point(0.0 -. trig.sin_degrees(angle), trig.cos_degrees(angle))
}

fn count_stalled_segments(segments: List(svg_path.Segment)) -> Int {
  segments
  |> list.filter(stalled_arc_turn_segment_is_caught)
  |> list.length
}

fn stalled_arc_turn_segment_is_caught(segment: svg_path.Segment) -> Bool {
  let start = offset_endpoint(segment, 0.0)
  let end = offset_endpoint(segment, 1.0)
  case start, end {
    Ok(start), Ok(end) ->
      vec2f.distance(start, with: end) <=. stalled_arc_turn_threshold
    _, _ -> False
  }
}

fn offset_endpoint(
  segment: svg_path.Segment,
  t: Float,
) -> Result(svg_path.Point, Nil) {
  case
    svg_path.segment_point(segment, at: t),
    svg_path.segment_derivative(segment, at: t)
  {
    Ok(point), Ok(derivative) -> {
      let normal = right_unit_normal(derivative)
      Ok(add(point, scale(normal, stalled_arc_turn_distance)))
    }
    _, _ -> Error(Nil)
  }
}

fn right_unit_normal(point: svg_path.Point) -> svg_path.Point {
  let length = vec2f.length(point)
  svg_path.point(point.y /. length, { 0.0 -. point.x } /. length)
}

fn stalled_arc_turn_svg(
  cases: List(
    #(
      String,
      String,
      Int,
      svg_path.Subpath,
      Result(svg_path.Subpath, offset.Error),
    ),
  ),
) -> String {
  "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 860 570\" width=\"860\" height=\"570\">\n"
  <> "  <rect width=\"100%\" height=\"100%\" fill=\"#ffffff\"/>\n"
  <> "  <text x=\"430\" y=\"28\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"16\" text-anchor=\"middle\" fill=\"#111827\">near-collapsed quarter-turn offsets</text>\n"
  <> string.join(list.index_map(cases, stalled_arc_turn_panel), "\n")
  <> "\n</svg>\n"
}

fn stalled_arc_turn_zoom_svg(
  cases: List(
    #(
      String,
      String,
      Int,
      svg_path.Subpath,
      Result(svg_path.Subpath, offset.Error),
    ),
  ),
) -> String {
  "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 860 650\" width=\"860\" height=\"650\">\n"
  <> "  <rect width=\"100%\" height=\"100%\" fill=\"#ffffff\"/>\n"
  <> "  <text x=\"430\" y=\"30\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"15\" text-anchor=\"middle\" fill=\"#111827\">corner zoom; distance="
  <> gallery_float_to_string(stalled_arc_turn_distance)
  <> "; threshold="
  <> gallery_float_to_string(stalled_arc_turn_threshold)
  <> "</text>\n"
  <> string.join(list.index_map(cases, stalled_arc_turn_zoom_panel), "\n")
  <> "\n</svg>\n"
}

fn stalled_arc_turn_panel(
  example: #(
    String,
    String,
    Int,
    svg_path.Subpath,
    Result(svg_path.Subpath, offset.Error),
  ),
  index: Int,
) -> String {
  let #(row_label, unit_label, subdivisions, source, result) = example
  let column = index % 3
  let row = index / 3
  let tx = 145.0 +. int.to_float(column) *. 280.0
  let ty = 145.0 +. int.to_float(row) *. 260.0
  let source_path = serialize.subpath(source)
  let stalled_segments =
    svg_path.segments(source)
    |> list.filter(stalled_arc_turn_segment_is_caught)
    |> serialize_segments
  let output = case result {
    Ok(subpath) ->
      "    <path d=\""
      <> escape(serialize.subpath(subpath))
      <> "\" style=\"fill: none; stroke: #2563eb; stroke-width: 2.4; stroke-linecap: round; stroke-linejoin: round\" />\n"
    Error(error) ->
      "    <text x=\"0\" y=\"24\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"7\" text-anchor=\"middle\" fill=\"#b91c1c\">"
      <> escape(string.inspect(error))
      <> "</text>\n"
  }

  "  <g transform=\"translate("
  <> gallery_float_to_string(tx)
  <> " "
  <> gallery_float_to_string(ty)
  <> ") scale(2)\">\n"
  <> "    <rect x=\"-58\" y=\"-58\" width=\"116\" height=\"88\" fill=\"#f8fafc\" stroke=\"#d1d5db\" stroke-width=\"0.7\" />\n"
  <> "    <path d=\""
  <> escape(source_path)
  <> "\" style=\"fill: none; stroke: #9ca3af; stroke-width: 1.6; stroke-linecap: round; stroke-linejoin: round\" />\n"
  <> "    <path d=\""
  <> escape(stalled_segments)
  <> "\" style=\"fill: none; stroke: #f97316; stroke-width: 2.2; stroke-linecap: round; stroke-linejoin: round\" />\n"
  <> output
  <> "  </g>\n"
  <> "  <text x=\""
  <> gallery_float_to_string(tx)
  <> "\" y=\""
  <> gallery_float_to_string(ty +. 105.0)
  <> "\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"12\" text-anchor=\"middle\" fill=\"#111827\">"
  <> row_label
  <> "; "
  <> int.to_string(subdivisions)
  <> " "
  <> unit_label
  <> case subdivisions == 1 {
    True -> ""
    False -> "s"
  }
  <> "</text>\n"
  <> "  <text x=\""
  <> gallery_float_to_string(tx)
  <> "\" y=\""
  <> gallery_float_to_string(ty +. 122.0)
  <> "\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"11\" text-anchor=\"middle\" fill=\"#334155\">corner segments="
  <> stalled_arc_turn_corner_segment_count(result)
  <> "; stalled="
  <> int.to_string(count_stalled_segments(svg_path.segments(source)))
  <> "</text>"
}

fn stalled_arc_turn_zoom_panel(
  example: #(
    String,
    String,
    Int,
    svg_path.Subpath,
    Result(svg_path.Subpath, offset.Error),
  ),
  index: Int,
) -> String {
  let #(row_label, unit_label, subdivisions, source, result) = example
  let #(clip_x, clip_y, clip_size) = stalled_arc_turn_zoom_box(source, result)
  let scale = 220.0 /. clip_size
  let column = index % 3
  let row = index / 3
  let panel_x = 145.0 +. int.to_float(column) *. 280.0
  let panel_y = 170.0 +. int.to_float(row) *. 260.0
  let tx = panel_x -. { clip_x +. clip_size /. 2.0 } *. scale
  let ty = panel_y -. { clip_y +. clip_size /. 2.0 } *. scale
  let source_path = serialize.subpath(source)
  let stalled_segments =
    svg_path.segments(source)
    |> list.filter(stalled_arc_turn_segment_is_caught)
    |> serialize_segments
  let output = case result {
    Ok(subpath) ->
      "    <path d=\""
      <> escape(serialize.subpath(subpath))
      <> "\" style=\"fill: none; stroke: #1d4ed8; stroke-width: 0.00008; stroke-linecap: round; stroke-linejoin: round\" />\n"
      <> "    <circle cx=\"0\" cy=\"0\" r=\"0.00008\" fill=\"#111827\" />\n"
      <> stalled_arc_turn_output_control_marks(subpath)
    Error(error) ->
      "    <text x=\"0\" y=\"0.0016\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"0.0003\" text-anchor=\"middle\" fill=\"#b91c1c\">"
      <> escape(string.inspect(error))
      <> "</text>\n"
  }

  "  <g transform=\"translate("
  <> gallery_float_to_string(tx)
  <> " "
  <> gallery_float_to_string(ty)
  <> ") scale("
  <> gallery_float_to_string(scale)
  <> ")\">\n"
  <> "    <clipPath id=\"corner-zoom-clip-"
  <> int.to_string(index)
  <> "\"><rect x=\""
  <> gallery_float_to_string(clip_x)
  <> "\" y=\""
  <> gallery_float_to_string(clip_y)
  <> "\" width=\""
  <> gallery_float_to_string(clip_size)
  <> "\" height=\""
  <> gallery_float_to_string(clip_size)
  <> "\" /></clipPath>\n"
  <> "    <rect x=\""
  <> gallery_float_to_string(clip_x)
  <> "\" y=\""
  <> gallery_float_to_string(clip_y)
  <> "\" width=\""
  <> gallery_float_to_string(clip_size)
  <> "\" height=\""
  <> gallery_float_to_string(clip_size)
  <> "\" fill=\"#f8fafc\" stroke=\"#d1d5db\" stroke-width=\"0.00003\" />\n"
  <> "    <g clip-path=\"url(#corner-zoom-clip-"
  <> int.to_string(index)
  <> ")\">\n"
  <> "    <path d=\""
  <> escape(source_path)
  <> "\" style=\"fill: none; stroke: #cbd5e1; stroke-width: 0.000035; stroke-linecap: round; stroke-linejoin: round\" />\n"
  <> "    <path d=\""
  <> escape(stalled_segments)
  <> "\" style=\"fill: none; stroke: #f97316; stroke-width: 0.000055; stroke-linecap: round; stroke-linejoin: round\" />\n"
  <> output
  <> stalled_arc_turn_fit_marks(source)
  <> "    </g>\n"
  <> "  </g>\n"
  <> "  <text x=\""
  <> gallery_float_to_string(panel_x)
  <> "\" y=\""
  <> gallery_float_to_string(panel_y +. 132.0)
  <> "\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"11\" text-anchor=\"middle\" fill=\"#111827\">"
  <> row_label
  <> "; "
  <> int.to_string(subdivisions)
  <> " "
  <> unit_label
  <> case subdivisions == 1 {
    True -> ""
    False -> "s"
  }
  <> "; corner "
  <> stalled_arc_turn_corner_label(result)
  <> "; stalled="
  <> int.to_string(count_stalled_segments(svg_path.segments(source)))
  <> "</text>"
}

fn stalled_arc_turn_zoom_box(
  source: svg_path.Subpath,
  result: Result(svg_path.Subpath, offset.Error),
) -> #(Float, Float, Float) {
  let points =
    list.append(
      stalled_arc_turn_offset_sample_points(source),
      stalled_arc_turn_corner_diagnostic_points(result),
    )

  case points {
    [] -> #(-0.004, -0.008, 0.01)
    [first, ..rest] -> {
      let #(min_x, min_y, max_x, max_y) =
        rest
        |> list.fold(#(first.x, first.y, first.x, first.y), fn(box, point) {
          let #(min_x, min_y, max_x, max_y) = box
          #(
            float.min(min_x, point.x),
            float.min(min_y, point.y),
            float.max(max_x, point.x),
            float.max(max_y, point.y),
          )
        })
      let width = max_x -. min_x
      let height = max_y -. min_y
      let size = float.max(float.max(width, height) *. 1.3, 0.002)
      let center_x = { min_x +. max_x } /. 2.0
      let center_y = { min_y +. max_y } /. 2.0
      #(center_x -. size /. 2.0, center_y -. size /. 2.0, size)
    }
  }
}

fn stalled_arc_turn_offset_sample_points(
  source: svg_path.Subpath,
) -> List(svg_path.Point) {
  let stalled =
    svg_path.segments(source)
    |> list.filter(stalled_arc_turn_segment_is_caught)

  stalled_arc_turn_sample_points(stalled)
}

fn stalled_arc_turn_sample_points(
  segments: List(svg_path.Segment),
) -> List(svg_path.Point) {
  stalled_arc_turn_sample_points_loop(segments, points: [])
}

fn stalled_arc_turn_sample_points_loop(
  segments: List(svg_path.Segment),
  points points: List(svg_path.Point),
) -> List(svg_path.Point) {
  case segments {
    [] -> list.reverse(points)
    [first, ..rest] -> {
      let points =
        stalled_arc_turn_segment_sample_points(first, [0.25, 0.5, 0.75], points)
      stalled_arc_turn_sample_points_loop(rest, points:)
    }
  }
}

fn stalled_arc_turn_segment_sample_points(
  segment: svg_path.Segment,
  samples: List(Float),
  points: List(svg_path.Point),
) -> List(svg_path.Point) {
  case samples {
    [] -> points
    [t, ..rest] -> {
      let points = case offset_endpoint(segment, t) {
        Ok(point) -> [point, ..points]
        Error(_) -> points
      }
      stalled_arc_turn_segment_sample_points(segment, rest, points)
    }
  }
}

fn stalled_arc_turn_corner_diagnostic_points(
  result: Result(svg_path.Subpath, offset.Error),
) -> List(svg_path.Point) {
  case result {
    Error(_) -> []
    Ok(subpath) ->
      subpath
      |> stalled_arc_turn_corner_segments
      |> list.flat_map(stalled_arc_turn_segment_diagnostic_points)
  }
}

fn stalled_arc_turn_segment_diagnostic_points(
  segment: svg_path.Segment,
) -> List(svg_path.Point) {
  case segment {
    svg_path.Line(start:, end:) -> [start, end]
    svg_path.QuadraticBezier(start:, control:, end:) -> [start, control, end]
    svg_path.CubicBezier(start:, control1:, control2:, end:) -> [
      start,
      control1,
      control2,
      end,
    ]
    svg_path.Arc(start:, end:, ..) -> [start, end]
  }
}

fn stalled_arc_turn_output_control_marks(subpath: svg_path.Subpath) -> String {
  case svg_path.segments(subpath) {
    [_, svg_path.CubicBezier(control1:, control2:, ..), ..] ->
      "    <circle cx=\""
      <> gallery_float_to_string(control1.x)
      <> "\" cy=\""
      <> gallery_float_to_string(control1.y)
      <> "\" r=\"0.00007\" fill=\"#dc2626\" stroke=\"#ffffff\" stroke-width=\"0.000018\" />\n"
      <> "    <text x=\""
      <> gallery_float_to_string(control1.x)
      <> "\" y=\""
      <> gallery_float_to_string(control1.y -. 0.00018)
      <> "\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"0.00018\" text-anchor=\"middle\" fill=\"#dc2626\" stroke=\"#ffffff\" stroke-width=\"0.000035\" paint-order=\"stroke fill\">c1</text>\n"
      <> "    <circle cx=\""
      <> gallery_float_to_string(control2.x)
      <> "\" cy=\""
      <> gallery_float_to_string(control2.y)
      <> "\" r=\"0.00007\" fill=\"#7c3aed\" stroke=\"#ffffff\" stroke-width=\"0.000018\" />\n"
      <> "    <text x=\""
      <> gallery_float_to_string(control2.x)
      <> "\" y=\""
      <> gallery_float_to_string(control2.y -. 0.00018)
      <> "\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"0.00018\" text-anchor=\"middle\" fill=\"#7c3aed\" stroke=\"#ffffff\" stroke-width=\"0.000035\" paint-order=\"stroke fill\">c2</text>\n"
    _ -> ""
  }
}

fn stalled_arc_turn_fit_marks(source: svg_path.Subpath) -> String {
  let stalled =
    svg_path.segments(source)
    |> list.filter(stalled_arc_turn_segment_is_caught)

  stalled_arc_turn_sample_marks(stalled)
  <> stalled_arc_turn_tangent_marks(stalled)
}

fn stalled_arc_turn_sample_marks(segments: List(svg_path.Segment)) -> String {
  stalled_arc_turn_sample_marks_loop(segments, marks: "")
}

fn stalled_arc_turn_sample_marks_loop(
  segments: List(svg_path.Segment),
  marks marks: String,
) -> String {
  case segments {
    [] -> marks
    [first, ..rest] -> {
      let marks =
        marks <> stalled_arc_turn_segment_sample_marks(first, [0.25, 0.5, 0.75])
      stalled_arc_turn_sample_marks_loop(rest, marks:)
    }
  }
}

fn stalled_arc_turn_segment_sample_marks(
  segment: svg_path.Segment,
  samples: List(Float),
) -> String {
  case samples {
    [] -> ""
    [t, ..rest] -> {
      let mark = case offset_endpoint(segment, t) {
        Ok(point) ->
          "    <circle cx=\""
          <> gallery_float_to_string(point.x)
          <> "\" cy=\""
          <> gallery_float_to_string(point.y)
          <> "\" r=\"0.00007\" fill=\"#16a34a\" stroke=\"#ffffff\" stroke-width=\"0.000018\" />\n"
        Error(_) -> ""
      }
      mark <> stalled_arc_turn_segment_sample_marks(segment, rest)
    }
  }
}

fn stalled_arc_turn_tangent_marks(segments: List(svg_path.Segment)) -> String {
  case segments {
    [] -> ""
    [first, ..rest] -> {
      let assert Ok(last) = list.last([first, ..rest])
      stalled_arc_turn_tangent_mark(first, t: 0.0, color: "#eab308")
      <> stalled_arc_turn_tangent_mark(last, t: 1.0, color: "#eab308")
    }
  }
}

fn stalled_arc_turn_tangent_mark(
  segment: svg_path.Segment,
  t t: Float,
  color color: String,
) -> String {
  case offset_endpoint(segment, t), segment_unit_tangent(segment, t) {
    Ok(point), Ok(tangent) -> {
      let end = add(point, scale(tangent, 0.00075))
      "    <line x1=\""
      <> gallery_float_to_string(point.x)
      <> "\" y1=\""
      <> gallery_float_to_string(point.y)
      <> "\" x2=\""
      <> gallery_float_to_string(end.x)
      <> "\" y2=\""
      <> gallery_float_to_string(end.y)
      <> "\" style=\"stroke: "
      <> color
      <> "; stroke-width: 0.000045; stroke-linecap: round\" />\n"
      <> "    <circle cx=\""
      <> gallery_float_to_string(point.x)
      <> "\" cy=\""
      <> gallery_float_to_string(point.y)
      <> "\" r=\"0.000075\" fill=\""
      <> color
      <> "\" stroke=\"#ffffff\" stroke-width=\"0.000018\" />\n"
    }
    _, _ -> ""
  }
}

fn segment_unit_tangent(
  segment: svg_path.Segment,
  t: Float,
) -> Result(svg_path.Point, Nil) {
  case svg_path.segment_derivative(segment, at: t) {
    Ok(derivative) -> {
      let length = vec2f.length(derivative)
      case length <=. 0.0 {
        True -> Error(Nil)
        False ->
          Ok(svg_path.point(derivative.x /. length, derivative.y /. length))
      }
    }
    Error(_) -> Error(Nil)
  }
}

fn stalled_arc_turn_corner_label(
  result: Result(svg_path.Subpath, offset.Error),
) -> String {
  case result {
    Error(_) -> "Error"
    Ok(subpath) -> {
      let segments = stalled_arc_turn_corner_segments(subpath)
      int.to_string(list.length(segments))
      <> " seg; length "
      <> gallery_float_to_string(stalled_arc_turn_segments_length(segments))
    }
  }
}

fn stalled_arc_turn_corner_segment_count(
  result: Result(svg_path.Subpath, offset.Error),
) -> String {
  case result {
    Error(_) -> "Error"
    Ok(subpath) ->
      subpath
      |> stalled_arc_turn_corner_segments
      |> list.length
      |> int.to_string
  }
}

fn stalled_arc_turn_corner_segments(
  subpath: svg_path.Subpath,
) -> List(svg_path.Segment) {
  case svg_path.segments(subpath) {
    [] | [_] | [_, _] -> []
    [_, ..rest] -> list.take(rest, list.length(rest) - 1)
  }
}

fn stalled_arc_turn_segments_length(segments: List(svg_path.Segment)) -> Float {
  segments
  |> list.fold(0.0, fn(total, segment) {
    case svg_path.segment_length(segment) {
      Ok(length) -> total +. length
      Error(_) -> total
    }
  })
}

fn serialize_segments(segments: List(svg_path.Segment)) -> String {
  case svg_path.subpath_with(segments, policy: svg_path.Wiggle) {
    Ok(subpath) -> serialize.subpath(subpath)
    Error(_) -> ""
  }
}

fn escape(text: String) -> String {
  text
  |> string.replace("&", "\\&amp;")
  |> string.replace("\"", "\\&quot;")
  |> string.replace("<", "\\&lt;")
  |> string.replace(">", "\\&gt;")
}

fn offset_track_source() -> svg_path.Subpath {
  svg_path.assert_subpath([
    svg_path.CubicBezier(
      start: svg_path.point(0.0, 32.0),
      control1: svg_path.point(82.0, -108.0),
      control2: svg_path.point(150.0, 142.0),
      end: svg_path.point(232.0, 12.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.point(232.0, 12.0),
      control1: svg_path.point(300.0, -92.0),
      control2: svg_path.point(414.0, 118.0),
      end: svg_path.point(532.0, -16.0),
    ),
  ])
}

fn dash_source() -> svg_path.Subpath {
  svg_path.assert_subpath([
    svg_path.CubicBezier(
      start: svg_path.point(0.0, 28.0),
      control1: svg_path.point(48.0, -62.0),
      control2: svg_path.point(112.0, 88.0),
      end: svg_path.point(154.0, 16.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.point(154.0, 16.0),
      control1: svg_path.point(194.0, -52.0),
      control2: svg_path.point(218.0, 70.0),
      end: svg_path.point(188.0, 42.0),
    ),
  ])
}

fn recursive_dash_source() -> svg_path.Subpath {
  svg_path.assert_subpath([
    svg_path.CubicBezier(
      start: svg_path.point(0.0, 34.0),
      control1: svg_path.point(88.0, -112.0),
      control2: svg_path.point(180.0, 146.0),
      end: svg_path.point(270.0, 10.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.point(270.0, 10.0),
      control1: svg_path.point(344.0, -98.0),
      control2: svg_path.point(418.0, 138.0),
      end: svg_path.point(520.0, 22.0),
    ),
  ])
}

fn earth_arc_source() -> svg_path.Subpath {
  svg_path.assert_subpath([
    svg_path.CubicBezier(
      start: svg_path.point(0.0, 28.0),
      control1: svg_path.point(42.0, -24.0),
      control2: svg_path.point(118.0, -24.0),
      end: svg_path.point(164.0, 28.0),
    ),
  ])
}

fn earth_bend_source() -> svg_path.Subpath {
  svg_path.assert_subpath([
    svg_path.CubicBezier(
      start: svg_path.point(0.0, 42.0),
      control1: svg_path.point(34.0, 6.0),
      control2: svg_path.point(82.0, -18.0),
      end: svg_path.point(126.0, 0.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.point(126.0, 0.0),
      control1: svg_path.point(156.0, 12.0),
      control2: svg_path.point(160.0, 50.0),
      end: svg_path.point(188.0, 66.0),
    ),
  ])
}

fn earth_turn_source() -> svg_path.Subpath {
  svg_path.assert_subpath([
    svg_path.Line(
      start: svg_path.point(0.0, 34.0),
      end: svg_path.point(68.0, -8.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.point(68.0, -8.0),
      control1: svg_path.point(110.0, -34.0),
      control2: svg_path.point(150.0, 34.0),
      end: svg_path.point(188.0, 10.0),
    ),
  ])
}

fn panel(x: Float, _label: String) -> svg.ThingToDraw {
  svg.Rectangle(
    svg_path.point(x +. 8.0, 18.0),
    222.0,
    184.0,
    "fill: #f8fafc; stroke: #cbd5e1; stroke-width: 1.4",
  )
}

fn wide_panel() -> svg.ThingToDraw {
  svg.Rectangle(
    svg_path.point(8.0, 18.0),
    844.0,
    344.0,
    "fill: #f8fafc; stroke: #cbd5e1; stroke-width: 1.4",
  )
}

fn path_layer(
  path: svg_path.Path,
  x: Float,
  fill fill: String,
  stroke stroke: String,
  width width: Float,
  arrows arrows: String,
) -> svg.ThingsToDraw {
  let placed = place_path(path, x +. 6.0, 34.0)
  [
    svg.StyledPath(
      placed,
      "fill: "
        <> fill
        <> "; stroke: "
        <> stroke
        <> "; stroke-width: "
        <> float_to_string(width)
        <> "; stroke-linejoin: round",
    ),
    ..path_arrows(placed, arrows, 0.9)
  ]
}

fn document(
  things: svg.ThingsToDraw,
  width width: Float,
  height height: Float,
) -> String {
  svg.document(
    things: list.append(
      [
        svg.Rectangle(svg_path.point(0.0, 0.0), width, height, "fill: #ffffff"),
      ],
      things,
    ),
    view_box: svg_path.BoundingBox(
      min: svg_path.point(0.0, 0.0),
      max: svg_path.point(width, height),
    ),
  )
}

fn path_arrows(
  path: svg_path.Path,
  color: String,
  arrow_scale: Float,
) -> svg.ThingsToDraw {
  path
  |> svg_path.subpaths
  |> list.flat_map(subpath_arrows(_, color, arrow_scale))
}

fn subpath_arrows(
  subpath: svg_path.Subpath,
  color: String,
  arrow_scale: Float,
) -> svg.ThingsToDraw {
  case svg_path.subpath_length(subpath) {
    Error(_) -> []
    Ok(total_length) -> {
      let distance = total_length *. 0.34
      case
        svg_path.subpath_point_at_length(subpath, distance:),
        svg_path.subpath_derivative_at_length(subpath, distance:)
      {
        Ok(point), Ok(derivative) -> {
          let length = vec2f.length(derivative)
          case length <=. 0.000001 {
            True -> []
            False -> [
              arrow_glyph(
                point,
                scale(derivative, 1.0 /. length),
                color,
                arrow_scale,
              ),
            ]
          }
        }
        _, _ -> []
      }
    }
  }
}

fn arrow_glyph(
  point: svg_path.Point,
  unit: svg_path.Point,
  color: String,
  arrow_scale: Float,
) -> svg.ThingToDraw {
  let half_width = 5.0 *. arrow_scale
  let arrow_height = half_width *. 1.7320508075688772
  let normal = rotate_counterclockwise(unit)
  let tip = add(point, scale(unit, arrow_height *. 2.0 /. 3.0))
  let base = add(point, scale(unit, 0.0 -. arrow_height /. 3.0))
  let left = add(base, scale(normal, half_width))
  let right = add(base, scale(normal, 0.0 -. half_width))
  svg.StyledPath(
    svg_path.Path([svg_path.assert_polygon([tip, left, right])]),
    "fill: " <> color <> "; stroke: none",
  )
}

fn place_path(path: svg_path.Path, x: Float, y: Float) -> svg_path.Path {
  let assert Ok(translated) = transform.translate_path(path, x:, y:)
  translated
}

fn place_subpath(
  subpath: svg_path.Subpath,
  x: Float,
  y: Float,
) -> svg_path.Subpath {
  let assert Ok(translated) = transform.translate_subpath(subpath, x:, y:)
  translated
}

fn text_style(color: String) -> String {
  "fill: "
  <> color
  <> "; font-family: ui-monospace, SFMono-Regular, Menlo, monospace"
}

fn add(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.point(a.x +. b.x, a.y +. b.y)
}

fn scale(point: svg_path.Point, factor: Float) -> svg_path.Point {
  svg_path.point(point.x *. factor, point.y *. factor)
}

fn rotate_counterclockwise(point: svg_path.Point) -> svg_path.Point {
  svg_path.point(0.0 -. point.y, point.x)
}

fn float_to_string(value: Float) -> String {
  case value {
    2.0 -> "2"
    3.0 -> "3"
    _ -> "2.5"
  }
}

fn gallery_float_to_string(value: Float) -> String {
  number_format.number(
    value,
    with: number_format.prepare(
      number_format.Options(
        left_decimals: number_format.Succinct,
        right_decimals: number_format.AtMost(6),
      ),
      [],
    ),
  )
}

fn result_try(
  result: Result(a, e),
  next: fn(a) -> Result(b, e),
) -> Result(b, e) {
  case result {
    Ok(value) -> next(value)
    Error(error) -> Error(error)
  }
}

@external(erlang, "filelib", "ensure_dir")
fn ensure_dir(path: String) -> Dynamic

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
