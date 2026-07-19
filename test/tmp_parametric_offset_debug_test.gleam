import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import svg_path
import svg_path/offset
import svg_path/svg
import svg_path/transform

const gallery_output = "examples/debug/svg_path_parametric_join_gallery.svg"

const diamond_zoom_output = "examples/debug/svg_path_parametric_diamond_round_negative_zoom.svg"

const diamond_miter_sections_output = "examples/debug/svg_path_parametric_diamond_round_negative_sections.svg"

const diamond_miter_loop_output = "examples/debug/svg_path_parametric_diamond_round_negative_loop_zoom.svg"

const diamond_section_survival_output = "examples/debug/svg_path_parametric_diamond_round_negative_section_survival.svg"

const diamond_section_nine_output = "examples/debug/svg_path_parametric_diamond_round_negative_section_9.svg"

const panel_w = 185.0

const panel_h = 118.0

const gap = 18.0

const offset_distance = -16.0

const preview_tolerance = 0.001

type JoinCase {
  JoinCase(label: String, join: offset.Join, color: String)
}

type Example {
  Example(label: String, source: svg_path.Subpath, distance: Float)
}

fn preview_options(join: offset.Join) -> offset.Options {
  offset.Options(
    ..offset.default_options(),
    tolerance: preview_tolerance,
    join:,
  )
}

pub fn main() -> Nil {
  let _ = write_file(gallery_output, render_gallery())
  let _ = write_file(diamond_zoom_output, render_diamond_zoom())
  Nil
}

pub fn render_tmp_parametric_join_gallery() {
  let _ = write_file(gallery_output, render_gallery())
  let _ = write_file(diamond_zoom_output, render_diamond_zoom())
  let _ =
    write_file(diamond_miter_sections_output, render_diamond_miter_sections())
  let _ =
    write_file(diamond_miter_loop_output, render_diamond_miter_loop_zoom())
  let _ =
    write_file(
      diamond_section_survival_output,
      render_diamond_section_survival(),
    )
  let _ = write_file(diamond_section_nine_output, render_diamond_section_nine())
  print_parametric_cut_diagnostics(
    "smooth figure-eight round d=-16",
    smooth_figure_eight(),
    offset.Round,
    -16.0,
  )
  print_parametric_cut_diagnostics(
    "rounded diamond miter d=-16",
    rounded_diamond(),
    offset.Miter(8.0),
    -16.0,
  )
  print_diamond_round_negative_section_diagnostics()
  print_diamond_round_negative_distances()
  assert examples() != []
}

fn print_parametric_cut_diagnostics(
  label: String,
  source: svg_path.Subpath,
  join: offset.Join,
  distance: Float,
) -> Nil {
  let assert Ok(provisional) = debug_provisional_with(source, join, distance)
  let options = preview_options(join)
  let assert Ok(result) = offset.subpath_with(source, distance:, options:)
  let segments = svg_path.segments(provisional)
  let cuts =
    count_intersection_cuts(
      indexed_segments(segments, 0),
      total: 0,
      kept: 0,
      adjacent: 0,
      endpoint_endpoint: 0,
      endpoint_endpoint_nonadjacent: 0,
    )
  io.println("")
  io.println(label)
  io.println("provisional segments=" <> int.to_string(list.length(segments)))
  io.println(
    "production output subpaths="
    <> int.to_string(list.length(svg_path.subpaths(result))),
  )
  io.println(
    "intersections="
    <> int.to_string(cuts.0)
    <> " kept="
    <> int.to_string(cuts.1)
    <> " adjacent_endpoint_1e-9="
    <> int.to_string(cuts.2)
    <> " endpoint_endpoint="
    <> int.to_string(cuts.3)
    <> " endpoint_endpoint_nonadjacent="
    <> int.to_string(cuts.4),
  )
  print_near_join_contact_examples(indexed_segments(segments, 0), printed: 0)
  print_kept_cut_examples(indexed_segments(segments, 0), printed: 0)
}

fn print_near_join_contact_examples(
  indexed: List(DebugIndexedSegment),
  printed printed: Int,
) -> Nil {
  case indexed, printed >= 8 {
    _, True -> Nil
    [], _ -> Nil
    [first, ..rest], False -> {
      let printed =
        print_near_join_contact_examples_against(first, rest, printed)
      print_near_join_contact_examples(rest, printed:)
    }
  }
}

fn print_near_join_contact_examples_against(
  left: DebugIndexedSegment,
  rest: List(DebugIndexedSegment),
  printed: Int,
) -> Int {
  case rest, printed >= 8 {
    _, True -> printed
    [], _ -> printed
    [right, ..remaining], False -> {
      let printed = case
        svg_path.segment_intersections(left.segment, right.segment)
      {
        Ok(intersections) ->
          print_near_join_contact_intersections(
            left,
            right,
            intersections,
            printed,
          )
        Error(_) -> printed
      }
      print_near_join_contact_examples_against(left, remaining, printed)
    }
  }
}

fn print_near_join_contact_intersections(
  left: DebugIndexedSegment,
  right: DebugIndexedSegment,
  intersections: List(svg_path.SegmentIntersection),
  printed: Int,
) -> Int {
  case intersections, printed >= 8 {
    _, True -> printed
    [], _ -> printed
    [intersection, ..rest], False -> {
      let old_endpoint =
        old_exact_adjacent_endpoint_intersection(
          intersection,
          left.index,
          right.index,
        )
      let near_join =
        adjacent_endpoint_intersection(
          intersection,
          left.segment,
          right.segment,
          left.index,
          right.index,
          0,
        )
      let printed = case old_endpoint, near_join {
        False, True -> {
          io.println(
            "near join "
            <> int.to_string(printed)
            <> ": left="
            <> int.to_string(left.index)
            <> " t="
            <> f(intersection.left_t)
            <> " right="
            <> int.to_string(right.index)
            <> " t="
            <> f(intersection.right_t)
            <> " d_left_end="
            <> f(distance(
              intersection.point,
              svg_path.segment_end(left.segment),
            ))
            <> " d_right_start="
            <> f(distance(
              intersection.point,
              svg_path.segment_start(right.segment),
            )),
          )
          printed + 1
        }
        _, _ -> printed
      }
      print_near_join_contact_intersections(left, right, rest, printed)
    }
  }
}

fn old_exact_adjacent_endpoint_intersection(
  intersection: svg_path.SegmentIntersection,
  left_index: Int,
  right_index: Int,
) -> Bool {
  {
    right_index == left_index + 1
    && intersection.left_t >=. 1.0 -. 0.000000001
    && intersection.right_t <=. 0.000000001
  }
  || {
    left_index == right_index + 1
    && intersection.left_t <=. 0.000000001
    && intersection.right_t >=. 1.0 -. 0.000000001
  }
}

fn count_intersection_cuts(
  indexed: List(DebugIndexedSegment),
  total total_intersections: Int,
  kept kept_count: Int,
  adjacent adjacent_count: Int,
  endpoint_endpoint endpoint_endpoint_count: Int,
  endpoint_endpoint_nonadjacent endpoint_endpoint_nonadjacent_count: Int,
) -> #(Int, Int, Int, Int, Int) {
  case indexed {
    [] -> #(
      total_intersections,
      kept_count,
      adjacent_count,
      endpoint_endpoint_count,
      endpoint_endpoint_nonadjacent_count,
    )
    [first, ..rest] -> {
      let counts =
        count_against(first, rest, list.length(indexed) + first.index, #(
          total_intersections,
          kept_count,
          adjacent_count,
          endpoint_endpoint_count,
          endpoint_endpoint_nonadjacent_count,
        ))
      count_intersection_cuts(
        rest,
        total: counts.0,
        kept: counts.1,
        adjacent: counts.2,
        endpoint_endpoint: counts.3,
        endpoint_endpoint_nonadjacent: counts.4,
      )
    }
  }
}

fn count_against(
  left: DebugIndexedSegment,
  rest: List(DebugIndexedSegment),
  total: Int,
  counts: #(Int, Int, Int, Int, Int),
) -> #(Int, Int, Int, Int, Int) {
  case rest {
    [] -> counts
    [right, ..remaining] -> {
      let counts = case
        svg_path.segment_intersections(left.segment, right.segment)
      {
        Ok(intersections) ->
          list.fold(intersections, counts, fn(counts, intersection) {
            let total_count = counts.0 + 1
            let adjacent =
              adjacent_endpoint_intersection(
                intersection,
                left.segment,
                right.segment,
                left.index,
                right.index,
                total,
              )
            let endpoint_endpoint =
              split_is_endpoint(intersection.left_t)
              && split_is_endpoint(intersection.right_t)
            let nonadjacent_endpoint_endpoint = endpoint_endpoint && !adjacent
            #(
              total_count,
              case adjacent {
                True -> counts.1
                False -> counts.1 + 1
              },
              case adjacent {
                True -> counts.2 + 1
                False -> counts.2
              },
              case endpoint_endpoint {
                True -> counts.3 + 1
                False -> counts.3
              },
              case nonadjacent_endpoint_endpoint {
                True -> counts.4 + 1
                False -> counts.4
              },
            )
          })
        Error(_) -> counts
      }
      count_against(left, remaining, total, counts)
    }
  }
}

fn print_kept_cut_examples(
  indexed: List(DebugIndexedSegment),
  printed printed: Int,
) -> Nil {
  case indexed, printed >= 12 {
    _, True -> Nil
    [], _ -> Nil
    [first, ..rest], False -> {
      let printed = print_kept_cut_examples_against(first, rest, printed)
      print_kept_cut_examples(rest, printed:)
    }
  }
}

fn print_kept_cut_examples_against(
  left: DebugIndexedSegment,
  rest: List(DebugIndexedSegment),
  printed: Int,
) -> Int {
  case rest, printed >= 12 {
    _, True -> printed
    [], _ -> printed
    [right, ..remaining], False -> {
      let printed = case
        svg_path.segment_intersections(left.segment, right.segment)
      {
        Ok(intersections) ->
          print_kept_cut_intersections(left, right, intersections, printed)
        Error(_) -> printed
      }
      print_kept_cut_examples_against(left, remaining, printed)
    }
  }
}

fn print_kept_cut_intersections(
  left: DebugIndexedSegment,
  right: DebugIndexedSegment,
  intersections: List(svg_path.SegmentIntersection),
  printed: Int,
) -> Int {
  case intersections, printed >= 12 {
    _, True -> printed
    [], _ -> printed
    [intersection, ..rest], False -> {
      let adjacent =
        adjacent_endpoint_intersection(
          intersection,
          left.segment,
          right.segment,
          left.index,
          right.index,
          0,
        )
      let printed = case adjacent {
        True -> printed
        False -> {
          io.println(
            "kept cut "
            <> int.to_string(printed)
            <> ": left="
            <> int.to_string(left.index)
            <> " t="
            <> f(intersection.left_t)
            <> " right="
            <> int.to_string(right.index)
            <> " t="
            <> f(intersection.right_t)
            <> " endpoint_endpoint="
            <> bool_label(
              split_is_endpoint(intersection.left_t)
              && split_is_endpoint(intersection.right_t),
            ),
          )
          printed + 1
        }
      }
      print_kept_cut_intersections(left, right, rest, printed)
    }
  }
}

fn split_is_endpoint(t: Float) -> Bool {
  t <=. 0.000000001 || t >=. 1.0 -. 0.000000001
}

fn bool_label(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

fn print_diamond_round_negative_section_diagnostics() -> Nil {
  let source = rounded_diamond()
  let assert Ok(provisional) = debug_provisional(source, offset.Round)
  let assert Ok(sections) = self_intersection_sections(provisional)
  io.println("")
  io.println("round negative rounded-diamond provisional sections")
  sections
  |> list.index_map(fn(section, index) {
    let good_samples = count_good_section_samples(section, source)
    let start = section_start_label(section)
    let end = section_end_label(section)
    io.println(
      "section "
      <> int.to_string(index)
      <> " segments="
      <> int.to_string(list.length(section))
      <> " good_samples="
      <> int.to_string(good_samples),
    )
    io.println("  start=" <> start <> " end=" <> end)
  })
  Nil
}

fn print_diamond_round_negative_distances() -> Nil {
  let source = rounded_diamond()
  let options = preview_options(offset.Round)
  let assert Ok(result) =
    offset.subpath_with(source, distance: offset_distance, options:)
  let threshold =
    float.absolute_value(offset_distance) -. debug_distance_margin()
  io.println("")
  io.println("round negative rounded-diamond retained segment samples")
  io.println("keep threshold with restored margin: " <> f(threshold))
  svg_path.subpaths(result)
  |> list.index_map(fn(subpath, subpath_index) {
    svg_path.segments(subpath)
    |> list.index_map(fn(segment, segment_index) {
      print_segment_samples(source, subpath_index, segment_index, segment)
    })
  })
  Nil
}

fn print_segment_samples(
  source: svg_path.Subpath,
  subpath_index: Int,
  segment_index: Int,
  segment: svg_path.Segment,
) -> Nil {
  let distances =
    [0.2, 0.5, 0.8]
    |> list.map(fn(t) {
      let assert Ok(point) = svg_path.segment_point(segment, at: t)
      let assert Ok(projection) = svg_path.subpath_projection(point, to: source)
      "t=" <> f(t) <> " d=" <> f(projection.distance)
    })
    |> string.join(" | ")
  io.println(
    "subpath "
    <> int.to_string(subpath_index)
    <> " segment "
    <> int.to_string(segment_index)
    <> " "
    <> segment_kind(segment)
    <> " :: "
    <> distances,
  )
}

fn render_gallery() -> String {
  let rows = examples()
  let columns = join_styles()
  let things = [
    svg.Rectangle(
      svg_path.point(0.0, 0.0),
      gallery_width(),
      gallery_height(rows),
      "fill: #ffffff; stroke: none",
    ),
    svg.Text(
      "parametric offset join styles",
      text_style("700"),
      svg_path.point(8.0, 24.0),
      20,
    ),
    ..list.index_map(rows, fn(example, row) {
      list.index_map(columns, fn(join_case, col) {
        render_panel(example, join_case, col, row)
      })
      |> list.flatten
    })
    |> list.flatten
  ]

  svg.document(
    things,
    view_box: svg_path.BoundingBox(
      min: svg_path.point(0.0, 0.0),
      max: svg_path.point(gallery_width(), gallery_height(rows)),
    ),
  )
}

fn render_diamond_zoom() -> String {
  let source = rounded_diamond()
  let assert Ok(provisional) = debug_provisional(source, offset.Round)
  let assert Ok(sections) = self_intersection_sections(provisional)
  let placed_source = place_path(svg_path.from_subpath(source), 0.0, 0.0)
  let section_drawings =
    sections
    |> list.index_map(fn(section, index) {
      case count_good_section_samples(section, source) >= 5 {
        False -> []
        True -> {
          let color = section_color(index)
          let assert Ok(subpath) =
            svg_path.subpath_with(section, policy: svg_path.Wiggle)
          [
            svg.StyledPath(
              svg_path.from_subpath(subpath),
              "fill: none; stroke: "
                <> color
                <> "; stroke-width: 0.8; stroke-linecap: round; stroke-linejoin: round",
            ),
            ..section_sample_markers(section, source)
          ]
        }
      }
    })
    |> list.flatten
  let things = [
    svg.Rectangle(
      svg_path.point(0.0, 0.0),
      164.0,
      116.0,
      "fill: #ffffff; stroke: none",
    ),
    svg.StyledPath(
      placed_source,
      "fill: none; stroke: #94a3b8; stroke-width: 1.0; stroke-dasharray: 3 3; stroke-linecap: round; stroke-linejoin: round",
    ),
    ..section_drawings
  ]
  svg.document(
    things,
    view_box: svg_path.BoundingBox(
      min: svg_path.point(24.0, 20.0),
      max: svg_path.point(140.0, 100.0),
    ),
  )
}

fn render_diamond_miter_sections() -> String {
  let source = rounded_diamond()
  let assert Ok(provisional) = debug_provisional(source, offset.Round)
  let assert Ok(sections) = self_intersection_sections(provisional)
  let source_path = svg_path.from_subpath(source)
  let section_drawings =
    sections
    |> list.index_map(fn(section, index) {
      let color = section_color(index)
      let assert Ok(subpath) =
        svg_path.subpath_with(section, policy: svg_path.Wiggle)
      let path = svg_path.from_subpath(subpath)
      [
        svg.StyledPath(
          path,
          "fill: none; stroke: "
            <> color
            <> "; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round",
        ),
        ..section_endpoint_markers(section, color)
      ]
    })
    |> list.flatten
  svg.document(
    [
      svg.Rectangle(
        svg_path.point(0.0, 0.0),
        164.0,
        116.0,
        "fill: #ffffff; stroke: none",
      ),
      svg.StyledPath(
        source_path,
        "fill: none; stroke: #94a3b8; stroke-width: 1.0; stroke-dasharray: 3 3; stroke-linecap: round; stroke-linejoin: round",
      ),
      ..section_drawings
    ],
    view_box: svg_path.BoundingBox(
      min: svg_path.point(30.0, 24.0),
      max: svg_path.point(134.0, 98.0),
    ),
  )
}

fn render_diamond_miter_loop_zoom() -> String {
  let source = rounded_diamond()
  let assert Ok(provisional) = debug_provisional(source, offset.Round)
  let assert Ok(sections) = self_intersection_sections(provisional)
  let source_path = svg_path.from_subpath(source)
  let section_drawings =
    sections
    |> list.index_map(fn(section, index) {
      let color = section_color(index)
      let assert Ok(subpath) =
        svg_path.subpath_with(section, policy: svg_path.Wiggle)
      let path = svg_path.from_subpath(subpath)
      [
        svg.StyledPath(
          path,
          "fill: none; stroke: "
            <> color
            <> "; stroke-width: 0.12; stroke-linecap: round; stroke-linejoin: round",
        ),
        ..section_endpoint_markers_with_radius(section, color, 0.08)
      ]
    })
    |> list.flatten
  svg.document(
    [
      svg.Rectangle(
        svg_path.point(0.0, 0.0),
        164.0,
        116.0,
        "fill: #ffffff; stroke: none",
      ),
      svg.StyledPath(
        source_path,
        "fill: none; stroke: #94a3b8; stroke-width: 0.075; stroke-dasharray: 0.3 0.3; stroke-linecap: round; stroke-linejoin: round",
      ),
      ..section_drawings
    ],
    view_box: svg_path.BoundingBox(
      min: svg_path.point(72.0, 78.0),
      max: svg_path.point(91.0, 94.0),
    ),
  )
}

fn render_diamond_section_survival() -> String {
  let source = rounded_diamond()
  let assert Ok(provisional) = debug_provisional(source, offset.Round)
  let assert Ok(sections) = self_intersection_sections(provisional)
  let source_path = svg_path.from_subpath(source)
  let section_drawings =
    sections
    |> list.index_map(fn(section, index) {
      let keep = count_good_section_samples(section, source) >= 5
      let color = case keep {
        True -> "#16a34a"
        False -> "#94a3b8"
      }
      let width = case keep {
        True -> "0.18"
        False -> "0.075"
      }
      let opacity = case keep {
        True -> "1.0"
        False -> "0.45"
      }
      let assert Ok(subpath) =
        svg_path.subpath_with(section, policy: svg_path.Wiggle)
      let path = svg_path.from_subpath(subpath)
      [
        svg.StyledPath(
          path,
          "fill: none; stroke: "
            <> color
            <> "; stroke-width: "
            <> width
            <> "; stroke-opacity: "
            <> opacity
            <> "; stroke-linecap: round; stroke-linejoin: round",
        ),
        ..good_sample_markers(section, source, index)
      ]
    })
    |> list.flatten
  svg.document(
    [
      svg.Rectangle(
        svg_path.point(0.0, 0.0),
        164.0,
        116.0,
        "fill: #ffffff; stroke: none",
      ),
      svg.StyledPath(
        source_path,
        "fill: none; stroke: #cbd5e1; stroke-width: 0.075; stroke-dasharray: 0.3 0.3; stroke-linecap: round; stroke-linejoin: round",
      ),
      ..section_drawings
    ],
    view_box: svg_path.BoundingBox(
      min: svg_path.point(72.0, 78.0),
      max: svg_path.point(91.0, 94.0),
    ),
  )
}

fn render_diamond_section_nine() -> String {
  let source = rounded_diamond()
  let assert Ok(provisional) = debug_provisional(source, offset.Round)
  let assert Ok(sections) = self_intersection_sections(provisional)
  let assert Ok(target_section) = nth_section(sections, 9)
  let source_path = svg_path.from_subpath(source)
  let section_drawings =
    sections
    |> list.index_map(fn(section, index) {
      case index == 9 {
        True -> inspected_section_segment_drawings(section)
        False -> gray_section_drawing(section)
      }
    })
    |> list.flatten
  svg.document(
    [
      svg.Rectangle(
        svg_path.point(0.0, 0.0),
        164.0,
        116.0,
        "fill: #ffffff; stroke: none",
      ),
      svg.StyledPath(
        source_path,
        "fill: none; stroke: #cbd5e1; stroke-width: 0.075; stroke-dasharray: 0.3 0.3; stroke-linecap: round; stroke-linejoin: round",
      ),
      ..list.append(
        section_drawings,
        list.append(
          list.append(
            section_global_parameter_markers(target_section),
            section_savior_marker(target_section, source),
          ),
          [
            svg.Text(
              "section 9: "
                <> int.to_string(list.length(target_section))
                <> " segments",
              "fill: #111827; font-family: system-ui, sans-serif; font-weight: 700; text-anchor: middle; dominant-baseline: central",
              svg_path.point(81.5, 96.0),
              2,
            ),
          ],
        ),
      )
    ],
    view_box: svg_path.BoundingBox(
      min: svg_path.point(72.0, 78.0),
      max: svg_path.point(91.0, 99.0),
    ),
  )
}

fn inspected_section_segment_drawings(
  section: List(svg_path.Segment),
) -> svg.ThingsToDraw {
  section
  |> list.index_map(fn(segment, index) {
    let color = case index % 4 {
      0 -> "#0f766e"
      1 -> "#be185d"
      2 -> "#7c2d12"
      _ -> "#1d4ed8"
    }
    let assert Ok(subpath) =
      svg_path.subpath_with([segment], policy: svg_path.Wiggle)
    svg.StyledPath(
      svg_path.from_subpath(subpath),
      "fill: none; stroke: "
        <> color
        <> "; stroke-width: 0.18; stroke-linecap: round; stroke-linejoin: round",
    )
  })
}

fn gray_section_drawing(section: List(svg_path.Segment)) -> svg.ThingsToDraw {
  let assert Ok(subpath) =
    svg_path.subpath_with(section, policy: svg_path.Wiggle)
  [
    svg.StyledPath(
      svg_path.from_subpath(subpath),
      "fill: none; stroke: #94a3b8; stroke-width: 0.075; stroke-linecap: round; stroke-linejoin: round",
    ),
  ]
}

fn section_sample_markers(
  section: List(svg_path.Segment),
  source: svg_path.Subpath,
) -> svg.ThingsToDraw {
  let assert Ok(subpath) =
    svg_path.subpath_with(section, policy: svg_path.Wiggle)
  let assert Ok(length) = svg_path.subpath_length(subpath)
  section_sample_parameters()
  |> list.map(fn(t) {
    let assert Ok(point) =
      svg_path.subpath_point_at_length(subpath, distance: length *. t)
    let assert Ok(projection) = svg_path.subpath_projection(point, to: source)
    let color = case
      projection.distance +. debug_distance_margin()
      >=. float.absolute_value(offset_distance)
    {
      True -> "#16a34a"
      False -> "#dc2626"
    }
    svg.Circle(
      point,
      0.75,
      "fill: " <> color <> "; stroke: #111827; stroke-width: 0.15",
    )
  })
}

fn good_sample_markers(
  section: List(svg_path.Segment),
  source: svg_path.Subpath,
  index _index: Int,
) -> svg.ThingsToDraw {
  let assert Ok(subpath) =
    svg_path.subpath_with(section, policy: svg_path.Wiggle)
  let assert Ok(length) = svg_path.subpath_length(subpath)
  section_sample_parameters()
  |> list.flat_map(fn(t) {
    let assert Ok(point) =
      svg_path.subpath_point_at_length(subpath, distance: length *. t)
    let assert Ok(projection) = svg_path.subpath_projection(point, to: source)
    case
      projection.distance +. debug_distance_margin()
      >=. float.absolute_value(offset_distance)
    {
      True -> [
        svg.Circle(
          point,
          0.12,
          "fill: #facc15; stroke: #111827; stroke-width: 0.035",
        ),
      ]
      False -> []
    }
  })
}

fn section_global_parameter_markers(
  section: List(svg_path.Segment),
) -> svg.ThingsToDraw {
  let assert Ok(subpath) =
    svg_path.subpath_with(section, policy: svg_path.Wiggle)
  let assert Ok(length) = svg_path.subpath_length(subpath)
  [0.2, 0.4, 0.6, 0.8]
  |> list.flat_map(fn(t) {
    let assert Ok(point) =
      svg_path.subpath_point_at_length(subpath, distance: length *. t)
    [
      svg.Circle(
        point,
        0.11,
        "fill: #ffffff; stroke: #111827; stroke-width: 0.035",
      ),
      svg.Text(
        f(t),
        "fill: #111827; font-family: system-ui, sans-serif; font-size: 0.1px; font-weight: 700; text-anchor: middle; dominant-baseline: central",
        point,
        1,
      ),
    ]
  })
}

fn section_savior_marker(
  section: List(svg_path.Segment),
  source: svg_path.Subpath,
) -> svg.ThingsToDraw {
  case first_good_section_sample(section, source) {
    Error(_) -> []
    Ok(point) -> [
      svg.Circle(
        point,
        0.15,
        "fill: #facc15; stroke: #111827; stroke-width: 0.04",
      ),
    ]
  }
}

fn first_good_section_sample(
  section: List(svg_path.Segment),
  source: svg_path.Subpath,
) -> Result(svg_path.Point, Nil) {
  let assert Ok(subpath) =
    svg_path.subpath_with(section, policy: svg_path.Wiggle)
  let assert Ok(length) = svg_path.subpath_length(subpath)
  first_good_section_sample_loop(
    subpath,
    length,
    source,
    samples: section_sample_parameters(),
  )
}

fn first_good_section_sample_loop(
  section: svg_path.Subpath,
  length: Float,
  source: svg_path.Subpath,
  samples samples: List(Float),
) -> Result(svg_path.Point, Nil) {
  case samples {
    [] -> Error(Nil)
    [t, ..rest] -> {
      let assert Ok(point) =
        svg_path.subpath_point_at_length(section, distance: length *. t)
      let assert Ok(projection) = svg_path.subpath_projection(point, to: source)
      case
        projection.distance +. debug_distance_margin()
        >=. float.absolute_value(offset_distance)
      {
        True -> Ok(point)
        False ->
          first_good_section_sample_loop(section, length, source, samples: rest)
      }
    }
  }
}

fn nth_section(
  sections: List(List(svg_path.Segment)),
  index: Int,
) -> Result(List(svg_path.Segment), Nil) {
  case sections, index {
    [], _ -> Error(Nil)
    [first, ..], 0 -> Ok(first)
    [_, ..rest], _ -> nth_section(rest, index - 1)
  }
}

fn count_good_section_samples(
  section: List(svg_path.Segment),
  source: svg_path.Subpath,
) -> Int {
  let assert Ok(subpath) =
    svg_path.subpath_with(section, policy: svg_path.Wiggle)
  let assert Ok(length) = svg_path.subpath_length(subpath)
  section_sample_parameters()
  |> list.fold(0, fn(count, t) {
    let assert Ok(point) =
      svg_path.subpath_point_at_length(subpath, distance: length *. t)
    let assert Ok(projection) = svg_path.subpath_projection(point, to: source)
    case
      projection.distance +. debug_distance_margin()
      >=. float.absolute_value(offset_distance)
    {
      True -> count + 1
      False -> count
    }
  })
}

fn section_sample_parameters() -> List(Float) {
  [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]
}

fn debug_distance_margin() -> Float {
  preview_tolerance
}

fn section_start_label(section: List(svg_path.Segment)) -> String {
  case section {
    [first, ..] -> point_label(svg_path.segment_start(first))
    [] -> "none"
  }
}

fn section_end_label(section: List(svg_path.Segment)) -> String {
  case list.last(section) {
    Ok(last) -> point_label(svg_path.segment_end(last))
    Error(_) -> "none"
  }
}

fn point_label(point: svg_path.Point) -> String {
  "(" <> f(point.x) <> ", " <> f(point.y) <> ")"
}

fn render_panel(
  example: Example,
  join_case: JoinCase,
  col: Int,
  row: Int,
) -> svg.ThingsToDraw {
  let x = 8.0 +. int.to_float(col) *. { panel_w +. gap }
  let y = 38.0 +. int.to_float(row) *. { panel_h +. gap }
  let placed_source = place_path(svg_path.from_subpath(example.source), x, y)
  let options = preview_options(join_case.join)
  let assert Ok(result) =
    offset.subpath_with(example.source, distance: example.distance, options:)
  let placed_result = place_path(result, x, y)

  [
    svg.Rectangle(
      svg_path.point(x, y),
      panel_w,
      panel_h,
      "fill: #f8fafc; stroke: #cbd5e1; stroke-width: 1",
    ),
    svg.Text(
      join_case.label <> " / " <> example.label,
      text_style("700"),
      svg_path.point(x +. 8.0, y +. 16.0),
      8,
    ),
    svg.StyledPath(
      placed_source,
      "fill: none; stroke: #94a3b8; stroke-width: 1.1; stroke-dasharray: 3 3; stroke-linecap: round; stroke-linejoin: round",
    ),
    ..list.append(
      colored_path_segments(placed_result),
      colored_path_arrows(placed_result),
    )
  ]
}

fn join_styles() -> List(JoinCase) {
  [
    JoinCase("Bevel", offset.Bevel, "#92400e"),
    JoinCase("Miter", offset.Miter(8.0), "#166534"),
    JoinCase("Round", offset.Round, "#6d28d9"),
  ]
}

fn examples() -> List(Example) {
  [
    Example("open corner, d = 12", open_corner(), 12.0),
    Example("open zigzag, d = -10", open_zigzag(), -10.0),
    Example("open cubic wave, d = 12", open_cubic_wave(), 12.0),
    Example("concave narrow wing, d = -18", concave_inset(), -18.0),
    Example("smooth figure-eight, d = -16", smooth_figure_eight(), -16.0),
    Example("closed rounded diamond, d = 16", rounded_diamond(), 16.0),
    Example("closed rounded diamond, d = -16", rounded_diamond(), -16.0),
  ]
}

fn open_corner() -> svg_path.Subpath {
  svg_path.assert_polyline([
    svg_path.point(18.0, 82.0),
    svg_path.point(82.0, 82.0),
    svg_path.point(82.0, 28.0),
  ])
}

fn open_zigzag() -> svg_path.Subpath {
  svg_path.assert_polyline([
    svg_path.point(16.0, 80.0),
    svg_path.point(54.0, 38.0),
    svg_path.point(92.0, 80.0),
    svg_path.point(130.0, 38.0),
  ])
}

fn open_cubic_wave() -> svg_path.Subpath {
  svg_path.assert_subpath([
    svg_path.CubicBezier(
      start: svg_path.point(16.0, 68.0),
      control1: svg_path.point(38.0, 20.0),
      control2: svg_path.point(62.0, 96.0),
      end: svg_path.point(84.0, 50.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.point(84.0, 50.0),
      control1: svg_path.point(104.0, 8.0),
      control2: svg_path.point(124.0, 88.0),
      end: svg_path.point(146.0, 42.0),
    ),
  ])
}

fn concave_inset() -> svg_path.Subpath {
  svg_path.assert_polygon([
    svg_path.point(18.0, 18.0),
    svg_path.point(146.0, 18.0),
    svg_path.point(146.0, 100.0),
    svg_path.point(128.0, 100.0),
    svg_path.point(128.0, 58.0),
    svg_path.point(62.0, 58.0),
    svg_path.point(62.0, 100.0),
    svg_path.point(18.0, 100.0),
  ])
}

fn smooth_figure_eight() -> svg_path.Subpath {
  svg_path.assert_subpath([
    svg_path.CubicBezier(
      start: svg_path.point(82.0, 58.0),
      control1: svg_path.point(40.0, 8.0),
      control2: svg_path.point(12.0, 112.0),
      end: svg_path.point(82.0, 58.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.point(82.0, 58.0),
      control1: svg_path.point(152.0, 4.0),
      control2: svg_path.point(124.0, 112.0),
      end: svg_path.point(82.0, 58.0),
    ),
  ])
  |> svg_path.assert_set_closed(closed: True)
}

fn rounded_diamond() -> svg_path.Subpath {
  svg_path.assert_subpath([
    svg_path.QuadraticBezier(
      start: svg_path.point(82.0, 12.0),
      control: svg_path.point(112.0, 20.0),
      end: svg_path.point(146.0, 58.0),
    ),
    svg_path.QuadraticBezier(
      start: svg_path.point(146.0, 58.0),
      control: svg_path.point(120.0, 92.0),
      end: svg_path.point(82.0, 104.0),
    ),
    svg_path.QuadraticBezier(
      start: svg_path.point(82.0, 104.0),
      control: svg_path.point(42.0, 92.0),
      end: svg_path.point(18.0, 58.0),
    ),
    svg_path.QuadraticBezier(
      start: svg_path.point(18.0, 58.0),
      control: svg_path.point(48.0, 22.0),
      end: svg_path.point(82.0, 12.0),
    ),
  ])
  |> svg_path.assert_set_closed(closed: True)
}

type DebugOffsetPiece {
  DebugOffsetPiece(source: svg_path.Segment, offset: List(svg_path.Segment))
}

type DebugIndexedSegment {
  DebugIndexedSegment(index: Int, segment: svg_path.Segment)
}

type DebugSplitParameter {
  DebugSplitParameter(t: Float, cut: Bool)
}

type DebugSplitPiece {
  DebugSplitPiece(
    segment: svg_path.Segment,
    start_is_cut: Bool,
    end_is_cut: Bool,
  )
}

fn debug_provisional(
  source: svg_path.Subpath,
  join: offset.Join,
) -> Result(svg_path.Subpath, Nil) {
  debug_provisional_with(source, join, offset_distance)
}

fn debug_provisional_with(
  source: svg_path.Subpath,
  join: offset.Join,
  distance distance: Float,
) -> Result(svg_path.Subpath, Nil) {
  let options = preview_options(join)
  case join {
    offset.Round -> {
      let assert Ok(subpath) =
        offset.subpath_untrimmed_with(source, distance:, options:)
      Ok(subpath)
    }
    _ -> {
      let pieces =
        svg_path.segments(source)
        |> list.map(fn(segment) {
          let assert Ok(offset_subpath) =
            offset.segment_with(segment, distance:, options:)
          DebugOffsetPiece(
            source: segment,
            offset: svg_path.segments(offset_subpath),
          )
        })
      case pieces {
        [] -> Ok(svg_path.empty_subpath(at: svg_path.point(0.0, 0.0)))
        [first, ..rest] -> {
          let assert Ok(segments) =
            debug_miter_join_loop(
              first,
              first,
              rest,
              offset_distance: distance,
              accumulated: first.offset,
            )
          let assert Ok(subpath) =
            svg_path.subpath_with(segments, policy: svg_path.Wiggle)
          let assert Ok(subpath) =
            svg_path.set_closed_with(
              subpath,
              closed: True,
              policy: svg_path.Wiggle,
            )
          Ok(subpath)
        }
      }
    }
  }
}

fn debug_miter_join_loop(
  first: DebugOffsetPiece,
  previous: DebugOffsetPiece,
  rest: List(DebugOffsetPiece),
  offset_distance offset_distance: Float,
  accumulated accumulated: List(svg_path.Segment),
) -> Result(List(svg_path.Segment), svg_path.Error) {
  case rest {
    [] -> {
      let assert Ok(connector) =
        debug_miter_connector(previous, first, offset_distance:)
      Ok(list.append(accumulated, connector))
    }
    [next, ..remaining] -> {
      let assert Ok(connector) =
        debug_miter_connector(previous, next, offset_distance:)
      debug_miter_join_loop(
        first,
        next,
        remaining,
        offset_distance:,
        accumulated: list.append(
          accumulated,
          list.append(connector, next.offset),
        ),
      )
    }
  }
}

fn debug_miter_connector(
  left: DebugOffsetPiece,
  right: DebugOffsetPiece,
  offset_distance offset_distance: Float,
) -> Result(List(svg_path.Segment), svg_path.Error) {
  let assert Ok(left_offset) = list.last(left.offset)
  let assert Ok(right_offset) = list.first(right.offset)
  let start = svg_path.segment_end(left_offset)
  let end = svg_path.segment_start(right_offset)
  case distance(start, end) <=. 0.000000001 {
    True -> Ok([])
    False -> {
      let assert Ok(left_tangent) = unit_tangent(left.source, 1.0)
      let assert Ok(right_tangent) = unit_tangent(right.source, 0.0)
      case directed_line_intersection(start, left_tangent, end, right_tangent) {
        Error(_) -> Ok([svg_path.Line(start:, end:)])
        Ok(apex) -> {
          let corner = svg_path.segment_end(left.source)
          let miter_length = distance(corner, apex)
          case miter_length /. float.absolute_value(offset_distance) <=. 8.0 {
            True -> Ok(line_segments_between([start, apex, end]))
            False -> Ok([svg_path.Line(start:, end:)])
          }
        }
      }
    }
  }
}

fn self_intersection_sections(
  subpath: svg_path.Subpath,
) -> Result(List(List(svg_path.Segment)), svg_path.Error) {
  let assert Ok(split_points) = self_intersection_split_parameters(subpath)
  let sections =
    split_segments_at_subpath_parameters(
      svg_path.segments(subpath),
      split_points,
      index: 0,
      current: [],
      sections: [],
    )
  case svg_path.is_closed(subpath) {
    True -> Ok(merge_wrapping_sections(sections))
    False -> Ok(sections)
  }
}

fn self_intersection_split_parameters(
  subpath: svg_path.Subpath,
) -> Result(List(svg_path.SubpathParameter), svg_path.Error) {
  let assert Ok(intersections) =
    svg_path.subpath_self_intersections_with(
      subpath,
      options: svg_path.SelfIntersectionOptions(
        minimum_arc_length_separation: 2.0 *. 0.000000001,
        distance_tolerance: 0.000000001,
      ),
    )

  let parameters =
    intersections
    |> list.flat_map(fn(intersection) {
      let svg_path.SubpathSelfIntersection(parameters: #(left, right), ..) =
        intersection
      [left, right]
    })
    |> list.filter(fn(parameter) {
      !is_open_subpath_boundary_parameter(subpath, parameter)
    })
    |> list.sort(by: svg_path.compare_subpath_parameters)
    |> unique_subpath_parameters(0.000000001, [])

  Ok(parameters)
}

fn is_open_subpath_boundary_parameter(
  subpath: svg_path.Subpath,
  parameter: svg_path.SubpathParameter,
) -> Bool {
  case svg_path.is_closed(subpath) {
    True -> False
    False -> {
      let length = list.length(svg_path.segments(subpath))
      let svg_path.SubpathParameter(segment_index:, t:) = parameter
      { segment_index == 0 && t <=. 0.000000001 }
      || { segment_index == length - 1 && t >=. 1.0 -. 0.000000001 }
    }
  }
}

fn unique_subpath_parameters(
  values: List(svg_path.SubpathParameter),
  tolerance: Float,
  unique unique: List(svg_path.SubpathParameter),
) -> List(svg_path.SubpathParameter) {
  case values {
    [] -> list.reverse(unique)
    [first, ..rest] -> {
      case unique {
        [previous, ..] -> {
          case same_subpath_parameter(first, previous, tolerance) {
            True -> unique_subpath_parameters(rest, tolerance, unique:)
            False ->
              unique_subpath_parameters(rest, tolerance, unique: [
                first,
                ..unique
              ])
          }
        }
        [] -> unique_subpath_parameters(rest, tolerance, unique: [first])
      }
    }
  }
}

fn same_subpath_parameter(
  left: svg_path.SubpathParameter,
  right: svg_path.SubpathParameter,
  tolerance: Float,
) -> Bool {
  let svg_path.SubpathParameter(segment_index: left_index, t: left_t) = left
  let svg_path.SubpathParameter(segment_index: right_index, t: right_t) = right
  left_index == right_index
  && float.absolute_value(left_t -. right_t) <=. tolerance
}

fn split_segments_at_subpath_parameters(
  segments: List(svg_path.Segment),
  split_points: List(svg_path.SubpathParameter),
  index index: Int,
  current current: List(svg_path.Segment),
  sections sections: List(List(svg_path.Segment)),
) -> List(List(svg_path.Segment)) {
  case segments {
    [] ->
      case current {
        [] -> list.reverse(sections)
        _ -> list.reverse([list.reverse(current), ..sections])
      }
    [first, ..rest] -> {
      let parameters =
        split_parameters_for_segment(split_points, index, [
          DebugSplitParameter(0.0, False),
          DebugSplitParameter(1.0, False),
        ])
        |> list.sort(by: fn(a, b) {
          let DebugSplitParameter(t: left, cut: _) = a
          let DebugSplitParameter(t: right, cut: _) = b
          float.compare(left, right)
        })
        |> unique_split_parameters([])
      let pieces = split_piece(first, parameters)
      let #(current, sections) =
        append_split_pieces(pieces, current:, sections:)
      split_segments_at_subpath_parameters(
        rest,
        split_points,
        index: index + 1,
        current:,
        sections:,
      )
    }
  }
}

fn split_parameters_for_segment(
  split_points: List(svg_path.SubpathParameter),
  index: Int,
  parameters: List(DebugSplitParameter),
) -> List(DebugSplitParameter) {
  case split_points {
    [] -> parameters
    [first, ..rest] -> {
      let svg_path.SubpathParameter(segment_index:, t:) = first
      let parameters = case segment_index == index {
        True -> [DebugSplitParameter(clamp01(t), True), ..parameters]
        False -> parameters
      }
      split_parameters_for_segment(rest, index, parameters)
    }
  }
}

fn indexed_segments(
  segments: List(svg_path.Segment),
  index: Int,
) -> List(DebugIndexedSegment) {
  case segments {
    [] -> []
    [first, ..rest] -> [
      DebugIndexedSegment(index:, segment: first),
      ..indexed_segments(rest, index + 1)
    ]
  }
}

fn unique_split_parameters(
  values: List(DebugSplitParameter),
  unique: List(DebugSplitParameter),
) -> List(DebugSplitParameter) {
  case values {
    [] -> list.reverse(unique)
    [first, ..rest] -> {
      let DebugSplitParameter(t: first_t, cut: first_cut) = first
      case unique {
        [previous, ..previous_rest] -> {
          let DebugSplitParameter(t: previous_t, cut: previous_cut) = previous
          case float.absolute_value(first_t -. previous_t) <=. 0.000000001 {
            True ->
              unique_split_parameters(rest, [
                DebugSplitParameter(previous_t, first_cut || previous_cut),
                ..previous_rest
              ])
            False -> unique_split_parameters(rest, [first, ..unique])
          }
        }
        _ -> unique_split_parameters(rest, [first])
      }
    }
  }
}

fn split_piece(
  segment: svg_path.Segment,
  parameters: List(DebugSplitParameter),
) -> List(DebugSplitPiece) {
  case parameters {
    [] | [_] -> []
    [from, to, ..rest] -> {
      let DebugSplitParameter(t: from_t, cut: from_cut) = from
      let DebugSplitParameter(t: to_t, cut: to_cut) = to
      case to_t -. from_t <=. 0.000000001 {
        True -> split_piece(segment, [to, ..rest])
        False -> {
          let assert Ok(pieces) =
            svg_path.segments_between_inside(segment, between: [from_t, to_t])
          list.append(
            pieces
              |> list.index_map(fn(segment, index) {
                DebugSplitPiece(
                  segment:,
                  start_is_cut: from_cut && index == 0,
                  end_is_cut: to_cut && index == list.length(pieces) - 1,
                )
              }),
            split_piece(segment, [to, ..rest]),
          )
        }
      }
    }
  }
}

fn append_split_pieces(
  pieces: List(DebugSplitPiece),
  current current: List(svg_path.Segment),
  sections sections: List(List(svg_path.Segment)),
) -> #(List(svg_path.Segment), List(List(svg_path.Segment))) {
  case pieces {
    [] -> #(current, sections)
    [DebugSplitPiece(segment:, start_is_cut:, end_is_cut:), ..rest] -> {
      let #(current, sections) = case start_is_cut, current {
        True, [_, ..] -> #([], [list.reverse(current), ..sections])
        _, _ -> #(current, sections)
      }
      let current = [segment, ..current]
      case end_is_cut {
        True ->
          append_split_pieces(rest, current: [], sections: [
            list.reverse(current),
            ..sections
          ])
        False -> append_split_pieces(rest, current:, sections:)
      }
    }
  }
}

fn merge_wrapping_sections(
  sections: List(List(svg_path.Segment)),
) -> List(List(svg_path.Segment)) {
  case sections {
    [] | [_] -> sections
    [first, ..rest] -> {
      let assert Ok(last) = list.last(rest)
      case chunks_touch(last, first) {
        True -> [list.append(last, first), ..drop_last(rest)]
        False -> sections
      }
    }
  }
}

fn adjacent_endpoint_intersection(
  intersection: svg_path.SegmentIntersection,
  left: svg_path.Segment,
  right: svg_path.Segment,
  left_index: Int,
  right_index: Int,
  total: Int,
) -> Bool {
  {
    right_index == left_index + 1
    && intersection.left_t >=. 1.0 -. 0.000000001
    && intersection.right_t <=. 0.000000001
  }
  || {
    left_index == right_index + 1
    && intersection.left_t <=. 0.000000001
    && intersection.right_t >=. 1.0 -. 0.000000001
  }
  || {
    left_index == 0
    && right_index == total - 1
    && intersection.left_t <=. 0.000000001
    && intersection.right_t >=. 1.0 -. 0.000000001
  }
  || {
    right_index == 0
    && left_index == total - 1
    && intersection.left_t >=. 1.0 -. 0.000000001
    && intersection.right_t <=. 0.000000001
  }
  || adjacent_local_intersection(
    intersection,
    left,
    right,
    left_index,
    right_index,
  )
}

fn adjacent_local_intersection(
  intersection: svg_path.SegmentIntersection,
  left: svg_path.Segment,
  right: svg_path.Segment,
  left_index: Int,
  right_index: Int,
) -> Bool {
  case right_index == left_index + 1 {
    True ->
      same_point(intersection.point, svg_path.segment_end(left), 0.01)
      && same_point(intersection.point, svg_path.segment_start(right), 0.01)
    False ->
      case left_index == right_index + 1 {
        True ->
          same_point(intersection.point, svg_path.segment_start(left), 0.01)
          && same_point(intersection.point, svg_path.segment_end(right), 0.01)
        False -> False
      }
  }
}

fn same_point(a: svg_path.Point, b: svg_path.Point, tolerance: Float) -> Bool {
  distance(a, b) <=. tolerance
}

fn chunks_touch(
  left: List(svg_path.Segment),
  right: List(svg_path.Segment),
) -> Bool {
  case list.last(left), list.first(right) {
    Ok(left_last), Ok(right_first) ->
      distance(
        svg_path.segment_end(left_last),
        svg_path.segment_start(right_first),
      )
      <=. 0.000000001
    _, _ -> False
  }
}

fn drop_last(items: List(a)) -> List(a) {
  case items {
    [] | [_] -> []
    [first, ..rest] -> [first, ..drop_last(rest)]
  }
}

fn section_endpoint_markers(
  section: List(svg_path.Segment),
  color: String,
) -> svg.ThingsToDraw {
  section_endpoint_markers_with_radius(section, color, 0.95)
}

fn section_endpoint_markers_with_radius(
  section: List(svg_path.Segment),
  color: String,
  radius: Float,
) -> svg.ThingsToDraw {
  case list.first(section), list.last(section) {
    Ok(first), Ok(last) -> [
      svg.Circle(
        svg_path.segment_start(first),
        radius,
        "fill: #ffffff; stroke: "
          <> color
          <> "; stroke-width: "
          <> f(radius *. 0.47),
      ),
      svg.Circle(
        svg_path.segment_end(last),
        radius,
        "fill: "
          <> color
          <> "; stroke: #ffffff; stroke-width: "
          <> f(radius *. 0.37),
      ),
    ]
    _, _ -> []
  }
}

fn line_segments_between(
  points: List(svg_path.Point),
) -> List(svg_path.Segment) {
  case points {
    [] | [_] -> []
    [first, second, ..rest] -> [
      svg_path.Line(start: first, end: second),
      ..line_segments_between([second, ..rest])
    ]
  }
}

fn unit_tangent(
  segment: svg_path.Segment,
  t: Float,
) -> Result(svg_path.Point, Nil) {
  let assert Ok(derivative) = svg_path.segment_derivative(segment, at: t)
  normalize(derivative)
}

fn directed_line_intersection(
  left_start: svg_path.Point,
  left_direction: svg_path.Point,
  right_start: svg_path.Point,
  right_direction: svg_path.Point,
) -> Result(svg_path.Point, Nil) {
  let delta = subtract(right_start, left_start)
  let determinant = cross(left_direction, right_direction)
  case float.absolute_value(determinant) <=. 0.000000001 {
    True -> Error(Nil)
    False -> {
      let left_t = cross(delta, right_direction) /. determinant
      let right_t = cross(delta, left_direction) /. determinant
      let point = add(left_start, scale(left_direction, left_t))
      case left_t >=. 0.0 && right_t <=. 0.0 {
        True -> Ok(point)
        False -> Error(Nil)
      }
    }
  }
}

fn subtract(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.point(a.x -. b.x, a.y -. b.y)
}

fn cross(a: svg_path.Point, b: svg_path.Point) -> Float {
  a.x *. b.y -. a.y *. b.x
}

fn clamp01(value: Float) -> Float {
  value |> float.max(0.0) |> float.min(1.0)
}

fn section_color(index: Int) -> String {
  case index % 16 {
    0 -> "#dc2626"
    1 -> "#2563eb"
    2 -> "#16a34a"
    3 -> "#d97706"
    4 -> "#7c3aed"
    5 -> "#0891b2"
    6 -> "#be123c"
    7 -> "#4d7c0f"
    8 -> "#c026d3"
    9 -> "#0f766e"
    10 -> "#ea580c"
    11 -> "#4338ca"
    12 -> "#65a30d"
    13 -> "#db2777"
    14 -> "#0284c7"
    _ -> "#7f1d1d"
  }
}

fn place_path(path: svg_path.Path, x: Float, y: Float) -> svg_path.Path {
  let assert Ok(placed) = transform.translate_path(path, x:, y:)
  placed
}

fn colored_path_segments(path: svg_path.Path) -> svg.ThingsToDraw {
  path
  |> svg_path.subpaths
  |> list.index_map(fn(subpath, subpath_index) {
    svg_path.segments(subpath)
    |> list.index_map(fn(segment, segment_index) {
      let color = segment_color(subpath_index, segment_index)
      let assert Ok(segment_subpath) =
        svg_path.subpath_with([segment], policy: svg_path.Wiggle)
      svg.StyledPath(
        svg_path.from_subpath(segment_subpath),
        "fill: none; stroke: "
          <> color
          <> "; stroke-width: 2.2; stroke-linecap: round; stroke-linejoin: round",
      )
    })
  })
  |> list.flatten
}

fn colored_path_arrows(path: svg_path.Path) -> svg.ThingsToDraw {
  path
  |> svg_path.subpaths
  |> list.index_map(fn(subpath, subpath_index) {
    svg_path.segments(subpath)
    |> list.index_map(fn(segment, segment_index) {
      let color = segment_color(subpath_index, segment_index)
      case segment_direction(segment) |> normalize {
        Error(_) -> []
        Ok(unit) -> {
          let assert Ok(point) = svg_path.segment_point(segment, at: 0.5)
          [arrow(point, unit, color)]
        }
      }
    })
    |> list.flatten
  })
  |> list.flatten
}

fn segment_color(subpath_index: Int, segment_index: Int) -> String {
  section_color(subpath_index * 37 + segment_index * 11)
}

fn arrow(
  point: svg_path.Point,
  unit: svg_path.Point,
  color: String,
) -> svg.ThingToDraw {
  let perp = svg_path.point(0.0 -. unit.y, unit.x)
  let half_width = 3.8
  let arrow_height = half_width *. 1.7320508075688772
  let tip = add(point, scale(unit, arrow_height *. 2.0 /. 3.0))
  let base = add(point, scale(unit, 0.0 -. arrow_height /. 3.0))
  let left = add(base, scale(perp, half_width))
  let right = add(base, scale(perp, 0.0 -. half_width))
  svg.StyledPath(
    svg_path.Path([svg_path.assert_polygon([tip, left, right])]),
    "fill: " <> color <> "; stroke: none",
  )
}

fn segment_direction(segment: svg_path.Segment) -> svg_path.Point {
  let assert Ok(start) = svg_path.segment_derivative(segment, at: 0.48)
  let assert Ok(end) = svg_path.segment_derivative(segment, at: 0.52)
  add(start, end)
}

fn normalize(point: svg_path.Point) -> Result(svg_path.Point, Nil) {
  let length = distance(svg_path.point(0.0, 0.0), point)
  case length <=. 0.0000001 {
    True -> Error(Nil)
    False -> Ok(scale(point, 1.0 /. length))
  }
}

fn add(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.point(a.x +. b.x, a.y +. b.y)
}

fn scale(point: svg_path.Point, factor: Float) -> svg_path.Point {
  svg_path.point(point.x *. factor, point.y *. factor)
}

fn distance(a: svg_path.Point, b: svg_path.Point) -> Float {
  let dx = a.x -. b.x
  let dy = a.y -. b.y
  let assert Ok(distance) = float.square_root(dx *. dx +. dy *. dy)
  distance
}

fn segment_kind(segment: svg_path.Segment) -> String {
  case segment {
    svg_path.Line(..) -> "Line"
    svg_path.QuadraticBezier(..) -> "Quadratic"
    svg_path.CubicBezier(..) -> "Cubic"
    svg_path.Arc(..) -> "Arc"
  }
}

fn f(value: Float) -> String {
  float.to_string(value)
}

fn text_style(weight: String) -> String {
  "fill: #111827; font-family: system-ui, sans-serif; font-weight: " <> weight
}

fn gallery_width() -> Float {
  8.0 +. 3.0 *. panel_w +. 2.0 *. gap +. 8.0
}

fn gallery_height(rows: List(Example)) -> Float {
  38.0 +. int.to_float(list.length(rows)) *. { panel_h +. gap } +. 8.0
}

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
