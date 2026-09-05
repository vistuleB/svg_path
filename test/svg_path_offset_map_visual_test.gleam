import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{Some}
import gleam/result
import gleam/string
import gleeunit
import svg_path
import svg_path/offset
import svg_path/parse
import svg_path/svg
import svg_path/trig

const output = "examples/debug/the_quick_brown_khmer_spiral_map.svg"

const decaying_output = "examples/debug/the_quick_brown_khmer_decaying_spiral_map.svg"

const rectangle_focus_output = "examples/debug/the_quick_brown_khmer_rectangle_focus.svg"

const source = "examples/debug/the_quick_brown_khmer.svg"

const pi = 3.141592653589793

const band_inner = 5.0

const band_height = 15.0

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn generate_khmer_text_offset_map_spiral_visual() {
  let assert Ok(source_svg) = read_file(source)
  let d = extract_path_data(source_svg)
  let assert Ok(text_path) = parse.path(d)
  let assert Ok(text_box) = svg_path.path_bounding_box(text_path)
  let coil = coil_subpath(turns: 6, samples: 900)
  let assert Ok(coil_length) = svg_path.subpath_length(coil)
  let assert Ok(coil_map) = offset.subpath_offset_map(coil)
  let text_layout = text_layout(text_box, coil_length)
  let assert Ok(mapped) =
    repeated_text_on_coil(text_path, text_box, text_layout, coil_map)
  let assert Ok(mapped_box) = svg_path.path_bounding_box(mapped)
  let view_box = offset_map_view_box(mapped_box)

  let drawing =
    svg.document(
      things: [
        background_rectangle(view_box),
        svg.StyledPath(
          mapped,
          "fill: #0f766e; fill-opacity: 0.78; stroke: #064e3b; stroke-width: 0.25",
        ),
      ],
      view_box:,
    )

  let _ = write_file(output, drawing)
  assert drawing != ""
}

pub fn generate_khmer_text_offset_map_decaying_spiral_visual() {
  let assert Ok(source_svg) = read_file(source)
  let d = extract_path_data(source_svg)
  let assert Ok(text_path) = parse.path(d)
  let assert Ok(text_box) = svg_path.path_bounding_box(text_path)
  let spiral = decaying_spiral_subpath(turns: 5, samples: 900)
  let assert Ok(spiral_length) = svg_path.subpath_length(spiral)
  let assert Ok(spiral_map) = offset.subpath_offset_map(spiral)
  let source_capacity =
    source_distance_for_spiral_length(
      maximum_spiral_query_length(spiral_length),
      spiral_length,
    )
  let text_layout = text_layout(text_box, source_capacity)
  let decaying_map = decaying_offset_map(spiral_length, spiral_map)
  let assert Ok(subdivided_text) =
    svg_path.path_subdivide_to_max_length(text_path, max_length: 1.0)
  let assert Ok(mapped) =
    repeated_text_on_coil(subdivided_text, text_box, text_layout, decaying_map)
  let assert Ok(mapped_box) = svg_path.path_bounding_box(mapped)
  let view_box = offset_map_view_box(mapped_box)

  let drawing =
    svg.document(
      things: [
        background_rectangle(view_box),
        svg.StyledPath(
          mapped,
          "fill: #581c87; fill-opacity: 0.78; stroke: #2e1065; stroke-width: 0.2",
        ),
      ],
      view_box:,
    )

  let _ = write_file(decaying_output, drawing)
  assert drawing != ""
}

pub fn khmer_text_offset_map_rectangle_focus_visual_probe() {
  let assert Ok(source_svg) = read_file(source)
  let d = extract_path_data(source_svg)
  let source_rectangle = extract_rectangle(source_svg)
  let assert Ok(text_path) = parse.path(d)
  let assert Ok(text_box) = svg_path.path_bounding_box(text_path)
  let spiral = decaying_spiral_subpath(turns: 5, samples: 900)
  let assert Ok(spiral_length) = svg_path.subpath_length(spiral)
  let assert Ok(spiral_map) = offset.subpath_offset_map(spiral)
  let source_capacity =
    source_distance_for_spiral_length(
      maximum_spiral_query_length(spiral_length),
      spiral_length,
    )
  let text_layout = text_layout(text_box, source_capacity)
  let decaying_map = decaying_offset_map(spiral_length, spiral_map)
  let selected_segments = path_segments_inside(text_path, source_rectangle)
  let selected_count = list.length(selected_segments)
  let cubic_count = count_cubic_segments(selected_segments, 0)
  let selected_source = selected_segments_to_plain_path(selected_segments)
  let source_verticals = rectangle_vertical_grid_subpaths(source_rectangle)
  let source_highlighted_vertical_4 =
    svg_path.Path(highlighted_grid_line(source_verticals, index: 5))
  let source_highlighted_vertical_5 =
    svg_path.Path(highlighted_grid_line(source_verticals, index: 6))
  let source_grid =
    svg_path.Path(
      rectangle_horizontal_grid_subpaths(source_rectangle)
      |> list.append(non_highlighted_vertical_grid(source_verticals)),
    )
  let assert Ok(selected_mapped) =
    selected_segments_to_path(
      selected_segments,
      text_box,
      text_layout.x_scale,
      0.0,
      decaying_map,
    )
  let assert Ok(mapped_rectangle) =
    mapped_rectangle_subpath(
      source_rectangle,
      text_box,
      text_layout.x_scale,
      0.0,
      decaying_map,
    )
  let assert Ok(mapped_grid) =
    svg_path.path_try_map_points(source_grid, with: fn(point) {
      source_point_to_offset_point(
        point,
        text_box,
        text_layout.x_scale,
        0.0,
        decaying_map,
      )
    })
  let assert Ok(mapped_highlighted_vertical_4) =
    svg_path.path_try_map_points(source_highlighted_vertical_4, with: fn(point) {
      source_point_to_offset_point(
        point,
        text_box,
        text_layout.x_scale,
        0.0,
        decaying_map,
      )
    })
  let assert Ok(mapped_highlighted_vertical_5) =
    svg_path.path_try_map_points(source_highlighted_vertical_5, with: fn(point) {
      source_point_to_offset_point(
        point,
        text_box,
        text_layout.x_scale,
        0.0,
        decaying_map,
      )
    })
  let assert Ok(mapped_verticals) =
    map_vertical_grid(
      source_verticals,
      text_box,
      text_layout.x_scale,
      decaying_map,
    )
  let _ =
    print_vertical_base_diagnostics(
      source_verticals,
      text_box,
      text_layout.x_scale,
      decaying_map,
    )
  let source_control_points =
    selected_segments
    |> list.flat_map(segment_source_marks)
  let mapped_control_points =
    selected_segments
    |> list.flat_map(segment_source_marks)
    |> map_control_points(text_box, text_layout.x_scale, 0.0, decaying_map, [])
  let source_view_box =
    focus_view_box(source_rectangle_bounding_box(source_rectangle))
  let assert Ok(mapped_focus_box) =
    svg_path.subpath_bounding_box(mapped_rectangle)
  let mapped_view_box = focus_view_box(mapped_focus_box)
  let source_panel_map =
    panel_map(
      source_view_box,
      left: 20.0,
      top: 38.0,
      width: 390.0,
      height: 315.0,
    )
  let mapped_panel_map =
    panel_map(
      mapped_view_box,
      left: 455.0,
      top: 38.0,
      width: 390.0,
      height: 315.0,
    )
  let assert Ok(source_panel_path) =
    svg_path.path_map_points(selected_source, with: source_panel_map)
  let assert Ok(source_panel_grid) =
    svg_path.path_map_points(source_grid, with: source_panel_map)
  let assert Ok(source_panel_highlighted_vertical_4) =
    svg_path.path_map_points(
      source_highlighted_vertical_4,
      with: source_panel_map,
    )
  let assert Ok(source_panel_highlighted_vertical_5) =
    svg_path.path_map_points(
      source_highlighted_vertical_5,
      with: source_panel_map,
    )
  let assert Ok(mapped_panel_path) =
    svg_path.path_map_points(selected_mapped, with: mapped_panel_map)
  let assert Ok(mapped_panel_grid) =
    svg_path.path_map_points(mapped_grid, with: mapped_panel_map)
  let assert Ok(mapped_panel_highlighted_vertical_4) =
    svg_path.path_map_points(
      mapped_highlighted_vertical_4,
      with: mapped_panel_map,
    )
  let assert Ok(mapped_panel_highlighted_vertical_5) =
    svg_path.path_map_points(
      mapped_highlighted_vertical_5,
      with: mapped_panel_map,
    )
  let source_panel_marks =
    source_control_points
    |> map_marks(source_panel_map, [])
  let mapped_panel_marks =
    mapped_control_points
    |> marks_from_control_marks
    |> map_marks(mapped_panel_map, [])
  let source_line_labels =
    vertical_line_labels(source_verticals, source_panel_map)
  let mapped_line_labels =
    vertical_line_labels(mapped_verticals, mapped_panel_map)
  let view_box =
    svg_path.BoundingBox(
      min: svg_path.Point(0.0, 0.0),
      max: svg_path.Point(865.0, 390.0),
    )

  let drawing =
    svg.document(
      things: [
        svg.Rectangle(
          view_box.min,
          svg_path.bounding_box_width(view_box),
          svg_path.bounding_box_height(view_box),
          "fill: #ffffff; stroke: none",
        ),
        svg.Text(
          "source",
          "fill: #111827; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-weight: 700",
          svg_path.Point(20.0, 24.0),
          18.0,
        ),
        svg.Text(
          "mapped",
          "fill: #111827; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-weight: 700",
          svg_path.Point(455.0, 24.0),
          18.0,
        ),
        svg.StyledPath(
          source_panel_grid,
          "fill: none; stroke: #0ea5e9; stroke-opacity: 0.55; stroke-width: 0.8",
        ),
        svg.StyledPath(
          source_panel_highlighted_vertical_4,
          "fill: none; stroke: #f97316; stroke-width: 2.2",
        ),
        svg.StyledPath(
          source_panel_highlighted_vertical_5,
          "fill: none; stroke: #16a34a; stroke-width: 2.2",
        ),
        svg.StyledPath(
          source_panel_path,
          "fill: none; stroke: #111827; stroke-width: 2.0",
        ),
        svg.StyledPath(
          mapped_panel_grid,
          "fill: none; stroke: #0ea5e9; stroke-opacity: 0.55; stroke-width: 0.8",
        ),
        svg.StyledPath(
          mapped_panel_highlighted_vertical_4,
          "fill: none; stroke: #f97316; stroke-width: 2.2",
        ),
        svg.StyledPath(
          mapped_panel_highlighted_vertical_5,
          "fill: none; stroke: #16a34a; stroke-width: 2.2",
        ),
        svg.StyledPath(
          mapped_panel_path,
          "fill: none; stroke: #111827; stroke-width: 2.0",
        ),
        svg.Text(
          "selected segments: "
            <> int.to_string(selected_count)
            <> "; cubic bezier: "
            <> int.to_string(cubic_count),
          "fill: #475569; font-family: ui-monospace, SFMono-Regular, Menlo, monospace",
          svg_path.Point(20.0, 374.0),
          12.0,
        ),
      ]
        |> list.append(source_line_labels)
        |> list.append(mapped_line_labels)
        |> list.append(control_point_circles(source_panel_marks))
        |> list.append(control_point_circles(mapped_panel_marks)),
      view_box:,
    )

  let _ = write_file(rectangle_focus_output, drawing)
  assert drawing != ""
}

fn extract_path_data(source_svg: String) -> String {
  let assert Ok(#(_, after_prefix)) =
    string.split_once(source_svg, "<path d=\"")
  let assert Ok(#(d, _)) = string.split_once(after_prefix, "\" id=")
  d
}

type SourceRectangle {
  SourceRectangle(min: svg_path.Point, max: svg_path.Point)
}

type ControlMark {
  ControlMark(point: svg_path.Point, style: String)
}

type SourceMark {
  SourceMark(point: svg_path.Point, style: String)
}

fn extract_rectangle(source_svg: String) -> SourceRectangle {
  let assert Ok(#(_, after_rect)) = string.split_once(source_svg, "<rect")
  let x = extract_float_attribute(after_rect, "x")
  let y = extract_float_attribute(after_rect, "y")
  let width = extract_float_attribute(after_rect, "width")
  let height = extract_float_attribute(after_rect, "height")
  SourceRectangle(
    min: svg_path.Point(x, y),
    max: svg_path.Point(x +. width, y +. height),
  )
}

fn extract_float_attribute(text: String, name: String) -> Float {
  let assert Ok(#(_, after_prefix)) = string.split_once(text, name <> "=\"")
  let assert Ok(#(value, _)) = string.split_once(after_prefix, "\"")
  let assert Ok(float) = float.parse(value)
  float
}

fn source_rectangle_bounding_box(
  rectangle: SourceRectangle,
) -> svg_path.BoundingBox {
  svg_path.BoundingBox(min: rectangle.min, max: rectangle.max)
}

fn path_segments_inside(
  path: svg_path.Path,
  rectangle: SourceRectangle,
) -> List(svg_path.Segment) {
  svg_path.path_subpaths(path)
  |> list.flat_map(fn(subpath) { svg_path.subpath_segments(subpath) })
  |> list.filter(fn(segment) {
    segment_defining_points(segment)
    |> list.all(point_inside_rectangle(_, rectangle))
  })
}

fn point_inside_rectangle(
  point: svg_path.Point,
  rectangle: SourceRectangle,
) -> Bool {
  point.x >=. rectangle.min.x
  && point.x <=. rectangle.max.x
  && point.y >=. rectangle.min.y
  && point.y <=. rectangle.max.y
}

fn segment_defining_points(segment: svg_path.Segment) -> List(svg_path.Point) {
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

fn segment_source_marks(segment: svg_path.Segment) -> List(SourceMark) {
  case segment {
    svg_path.Line(start:, end:) -> [
      endpoint_mark(start),
      endpoint_mark(end),
    ]
    svg_path.QuadraticBezier(start:, control:, end:) -> [
      endpoint_mark(start),
      first_control_mark(control),
      endpoint_mark(end),
    ]
    svg_path.CubicBezier(start:, control1:, control2:, end:) -> [
      endpoint_mark(start),
      first_control_mark(control1),
      second_control_mark(control2),
      endpoint_mark(end),
    ]
    svg_path.Arc(start:, end:, ..) -> [
      endpoint_mark(start),
      endpoint_mark(end),
    ]
  }
}

fn endpoint_mark(point: svg_path.Point) -> SourceMark {
  SourceMark(
    point:,
    style: "fill: #2563eb; fill-opacity: 0.6; stroke: #ffffff; stroke-width: 0.035",
  )
}

fn first_control_mark(point: svg_path.Point) -> SourceMark {
  SourceMark(
    point:,
    style: "fill: #dc2626; fill-opacity: 0.6; stroke: #ffffff; stroke-width: 0.035",
  )
}

fn second_control_mark(point: svg_path.Point) -> SourceMark {
  SourceMark(
    point:,
    style: "fill: #eab308; fill-opacity: 0.6; stroke: #111827; stroke-width: 0.025",
  )
}

fn count_cubic_segments(segments: List(svg_path.Segment), count: Int) -> Int {
  case segments {
    [] -> count
    [segment, ..rest] -> {
      let next_count = case segment {
        svg_path.CubicBezier(..) -> count + 1
        _ -> count
      }
      count_cubic_segments(rest, next_count)
    }
  }
}

fn selected_segments_to_path(
  segments: List(svg_path.Segment),
  text_box: svg_path.BoundingBox,
  x_scale: Float,
  start_distance: Float,
  coil_map: fn(svg_path.Point) -> Result(svg_path.Point, offset.Error),
) -> Result(svg_path.Path, svg_path.PointMapError(offset.Error)) {
  selected_segments_to_subpaths(
    segments,
    text_box,
    x_scale,
    start_distance,
    coil_map,
    [],
  )
  |> result.map(fn(subpaths) { svg_path.Path(subpaths) })
}

fn selected_segments_to_plain_path(
  segments: List(svg_path.Segment),
) -> svg_path.Path {
  segments
  |> list.map(fn(segment) { svg_path.subpath_assert([segment]) })
  |> svg_path.Path
}

fn selected_segments_to_subpaths(
  segments: List(svg_path.Segment),
  text_box: svg_path.BoundingBox,
  x_scale: Float,
  start_distance: Float,
  coil_map: fn(svg_path.Point) -> Result(svg_path.Point, offset.Error),
  mapped: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), svg_path.PointMapError(offset.Error)) {
  case segments {
    [] -> Ok(list.reverse(mapped))
    [segment, ..rest] -> {
      use mapped_segment <- result.try(
        svg_path.segment_try_map_points(segment, with: fn(point) {
          source_point_to_offset_point(
            point,
            text_box,
            x_scale,
            start_distance,
            coil_map,
          )
        }),
      )
      let subpath = svg_path.subpath_assert([mapped_segment])
      selected_segments_to_subpaths(
        rest,
        text_box,
        x_scale,
        start_distance,
        coil_map,
        [subpath, ..mapped],
      )
    }
  }
}

fn map_control_points(
  points: List(SourceMark),
  text_box: svg_path.BoundingBox,
  x_scale: Float,
  start_distance: Float,
  coil_map: fn(svg_path.Point) -> Result(svg_path.Point, offset.Error),
  mapped mapped: List(ControlMark),
) -> List(ControlMark) {
  case points {
    [] -> list.reverse(mapped)
    [SourceMark(point:, style:), ..rest] -> {
      let assert Ok(mapped_point) =
        source_point_to_offset_point(
          point,
          text_box,
          x_scale,
          start_distance,
          coil_map,
        )
      map_control_points(rest, text_box, x_scale, start_distance, coil_map, [
        ControlMark(point: mapped_point, style:),
        ..mapped
      ])
    }
  }
}

fn map_marks(
  marks: List(SourceMark),
  with f: fn(svg_path.Point) -> svg_path.Point,
  mapped mapped: List(ControlMark),
) -> List(ControlMark) {
  case marks {
    [] -> list.reverse(mapped)
    [SourceMark(point:, style:), ..rest] ->
      map_marks(rest, with: f, mapped: [
        ControlMark(point: f(point), style:),
        ..mapped
      ])
  }
}

fn vertical_line_labels(
  verticals: List(svg_path.Subpath),
  with f: fn(svg_path.Point) -> svg_path.Point,
) -> svg.ThingsToDraw {
  vertical_line_labels_loop(verticals, with: f, index: 1, labels: [])
}

fn vertical_line_labels_loop(
  verticals: List(svg_path.Subpath),
  with f: fn(svg_path.Point) -> svg_path.Point,
  index index: Int,
  labels labels: svg.ThingsToDraw,
) -> svg.ThingsToDraw {
  case verticals {
    [] -> list.reverse(labels)
    [line, ..rest] -> {
      let points = subpath_polyline_points(line)
      let label = case points {
        [] -> svg.Text("", "fill: none", svg_path.Point(0.0, 0.0), 1.0)
        [base, ..] -> {
          let point = f(base)
          svg.Text(
            int.to_string(index),
            "fill: #111827; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-weight: 700",
            svg_path.Point(point.x -. 4.0, point.y +. 16.0),
            12.0,
          )
        }
      }
      vertical_line_labels_loop(rest, with: f, index: index + 1, labels: [
        label,
        ..labels
      ])
    }
  }
}

fn marks_from_control_marks(marks: List(ControlMark)) -> List(SourceMark) {
  marks
  |> list.map(fn(mark) { SourceMark(point: mark.point, style: mark.style) })
}

fn panel_map(
  source_box: svg_path.BoundingBox,
  left left: Float,
  top top: Float,
  width width: Float,
  height height: Float,
) -> fn(svg_path.Point) -> svg_path.Point {
  let source_width = svg_path.bounding_box_width(source_box)
  let source_height = svg_path.bounding_box_height(source_box)
  let scale = float.min(width /. source_width, height /. source_height)
  let used_width = source_width *. scale
  let used_height = source_height *. scale
  let offset_x = left +. { width -. used_width } /. 2.0
  let offset_y = top +. { height -. used_height } /. 2.0

  fn(point: svg_path.Point) {
    svg_path.Point(
      offset_x +. { point.x -. source_box.min.x } *. scale,
      offset_y +. { point.y -. source_box.min.y } *. scale,
    )
  }
}

fn control_point_circles(points: List(ControlMark)) -> svg.ThingsToDraw {
  points
  |> list.map(fn(mark) { svg.Circle(mark.point, 4.5, mark.style) })
}

fn mapped_rectangle_subpath(
  rectangle: SourceRectangle,
  text_box: svg_path.BoundingBox,
  x_scale: Float,
  start_distance: Float,
  coil_map: fn(svg_path.Point) -> Result(svg_path.Point, offset.Error),
) -> Result(svg_path.Subpath, svg_path.PointMapError(offset.Error)) {
  rectangle_points(rectangle, side_samples: 60, points: [])
  |> map_rectangle_points(text_box, x_scale, start_distance, coil_map, [])
  |> result.map(points_to_subpath)
}

fn rectangle_points(
  rectangle: SourceRectangle,
  side_samples side_samples: Int,
  points points: List(svg_path.Point),
) -> List(svg_path.Point) {
  let SourceRectangle(min:, max:) = rectangle
  []
  |> rectangle_side_points(min, svg_path.Point(max.x, min.y), side_samples)
  |> rectangle_side_points(svg_path.Point(max.x, min.y), max, side_samples)
  |> rectangle_side_points(max, svg_path.Point(min.x, max.y), side_samples)
  |> rectangle_side_points(svg_path.Point(min.x, max.y), min, side_samples)
  |> list.append(points)
}

fn rectangle_vertical_grid_subpaths(
  rectangle: SourceRectangle,
) -> List(svg_path.Subpath) {
  rectangle_grid_lines(rectangle, vertical: True, index: 0, lines: [])
}

fn rectangle_horizontal_grid_subpaths(
  rectangle: SourceRectangle,
) -> List(svg_path.Subpath) {
  rectangle_grid_lines(rectangle, vertical: False, index: 0, lines: [])
}

fn highlighted_grid_line(
  lines: List(svg_path.Subpath),
  index index: Int,
) -> List(svg_path.Subpath) {
  case nth_subpath(lines, index) {
    Ok(line) -> [line]
    Error(_) -> []
  }
}

fn nth_subpath(
  lines: List(svg_path.Subpath),
  index: Int,
) -> Result(svg_path.Subpath, Nil) {
  case lines, index {
    [], _ -> Error(Nil)
    [line, ..], 0 -> Ok(line)
    [_, ..rest], _ -> nth_subpath(rest, index - 1)
  }
}

fn non_highlighted_vertical_grid(
  lines: List(svg_path.Subpath),
) -> List(svg_path.Subpath) {
  non_highlighted_vertical_grid_loop(lines, index: 0, kept: [])
}

fn non_highlighted_vertical_grid_loop(
  lines: List(svg_path.Subpath),
  index index: Int,
  kept kept: List(svg_path.Subpath),
) -> List(svg_path.Subpath) {
  case lines {
    [] -> list.reverse(kept)
    [line, ..rest] -> {
      let kept = case index == 5 || index == 6 {
        True -> kept
        False -> [line, ..kept]
      }
      non_highlighted_vertical_grid_loop(rest, index: index + 1, kept:)
    }
  }
}

fn rectangle_grid_lines(
  rectangle: SourceRectangle,
  vertical vertical: Bool,
  index index: Int,
  lines lines: List(svg_path.Subpath),
) -> List(svg_path.Subpath) {
  case index >= 10 {
    True -> lines
    False -> {
      let SourceRectangle(min:, max:) = rectangle
      let t = int.to_float(index) /. 9.0
      let #(start, end) = case vertical {
        True -> {
          let x = min.x +. { max.x -. min.x } *. t
          #(svg_path.Point(x, min.y), svg_path.Point(x, max.y))
        }
        False -> {
          let y = min.y +. { max.y -. min.y } *. t
          #(svg_path.Point(min.x, y), svg_path.Point(max.x, y))
        }
      }
      let line =
        rectangle_side_points([], start, end, 100)
        |> points_to_subpath
      rectangle_grid_lines(rectangle, vertical:, index: index + 1, lines: [
        line,
        ..lines
      ])
    }
  }
}

fn print_vertical_base_diagnostics(
  verticals: List(svg_path.Subpath),
  text_box: svg_path.BoundingBox,
  x_scale: Float,
  coil_map: fn(svg_path.Point) -> Result(svg_path.Point, offset.Error),
) -> Nil {
  let samples =
    verticals
    |> list.map(mapped_vertical_base_sample(text_box, x_scale, coil_map))

  io.println("mapped vertical grid base diagnostics")
  print_adjacent_base_diagnostics(samples, index: 0)
}

fn mapped_vertical_base_sample(
  text_box: svg_path.BoundingBox,
  x_scale: Float,
  coil_map: fn(svg_path.Point) -> Result(svg_path.Point, offset.Error),
) -> fn(svg_path.Subpath) -> #(svg_path.Point, Float) {
  fn(line: svg_path.Subpath) {
    let points = subpath_polyline_points(line)
    let assert [source_base, source_next, ..] = points
    let assert Ok(base) =
      source_point_to_offset_point(
        source_base,
        text_box,
        x_scale,
        0.0,
        coil_map,
      )
    let assert Ok(next) =
      source_point_to_offset_point(
        source_next,
        text_box,
        x_scale,
        0.0,
        coil_map,
      )
    #(base, angle_between(base, next))
  }
}

fn subpath_polyline_points(subpath: svg_path.Subpath) -> List(svg_path.Point) {
  case svg_path.subpath_segments(subpath) {
    [] -> []
    segments -> [
      segment_list_start(segments),
      ..list.map(segments, svg_path.segment_end)
    ]
  }
}

fn segment_list_start(segments: List(svg_path.Segment)) -> svg_path.Point {
  let assert [first, ..] = segments
  svg_path.segment_start(first)
}

fn print_adjacent_base_diagnostics(
  samples: List(#(svg_path.Point, Float)),
  index index: Int,
) -> Nil {
  case samples {
    [] | [_] -> Nil
    [#(left_point, left_angle), #(right_point, right_angle), ..rest] -> {
      let spacing = point_distance(left_point, right_point)
      let angle_delta = normalized_angle_difference(right_angle -. left_angle)
      io.println(
        "line "
        <> int.to_string(index + 1)
        <> " -> "
        <> int.to_string(index + 2)
        <> ": base_distance="
        <> float.to_string(spacing)
        <> "; base_angle_delta_degrees="
        <> float.to_string(angle_delta),
      )
      print_adjacent_base_diagnostics(
        [#(right_point, right_angle), ..rest],
        index: index + 1,
      )
    }
  }
}

fn angle_between(start: svg_path.Point, end: svg_path.Point) -> Float {
  trig.atan2_degrees(end.y -. start.y, end.x -. start.x)
}

fn normalized_angle_difference(angle: Float) -> Float {
  case angle >. 180.0 {
    True -> normalized_angle_difference(angle -. 360.0)
    False ->
      case angle <. -180.0 {
        True -> normalized_angle_difference(angle +. 360.0)
        False -> angle
      }
  }
}

fn point_distance(a: svg_path.Point, b: svg_path.Point) -> Float {
  pow({ b.x -. a.x } *. { b.x -. a.x } +. { b.y -. a.y } *. { b.y -. a.y }, 0.5)
}

fn rectangle_side_points(
  points: List(svg_path.Point),
  start: svg_path.Point,
  end: svg_path.Point,
  samples: Int,
) -> List(svg_path.Point) {
  rectangle_side_points_loop(0, samples, start, end, points)
}

fn rectangle_side_points_loop(
  index: Int,
  samples: Int,
  start: svg_path.Point,
  end: svg_path.Point,
  points: List(svg_path.Point),
) -> List(svg_path.Point) {
  case index > samples {
    True -> points
    False -> {
      let t = int.to_float(index) /. int.to_float(samples)
      let point =
        svg_path.Point(
          start.x +. { end.x -. start.x } *. t,
          start.y +. { end.y -. start.y } *. t,
        )
      rectangle_side_points_loop(index + 1, samples, start, end, [
        point,
        ..points
      ])
    }
  }
}

fn map_rectangle_points(
  points: List(svg_path.Point),
  text_box: svg_path.BoundingBox,
  x_scale: Float,
  start_distance: Float,
  coil_map: fn(svg_path.Point) -> Result(svg_path.Point, offset.Error),
  mapped: List(svg_path.Point),
) -> Result(List(svg_path.Point), svg_path.PointMapError(offset.Error)) {
  case points {
    [] -> Ok(list.reverse(mapped))
    [point, ..rest] -> {
      use mapped_point <- result.try(
        source_point_to_offset_point(
          point,
          text_box,
          x_scale,
          start_distance,
          coil_map,
        )
        |> result.map_error(svg_path.PointMapFunctionError),
      )
      map_rectangle_points(rest, text_box, x_scale, start_distance, coil_map, [
        mapped_point,
        ..mapped
      ])
    }
  }
}

fn map_vertical_grid(
  verticals: List(svg_path.Subpath),
  text_box: svg_path.BoundingBox,
  x_scale: Float,
  coil_map: fn(svg_path.Point) -> Result(svg_path.Point, offset.Error),
) -> Result(List(svg_path.Subpath), svg_path.PointMapError(offset.Error)) {
  map_vertical_grid_loop(verticals, text_box, x_scale, coil_map, mapped: [])
}

fn map_vertical_grid_loop(
  verticals: List(svg_path.Subpath),
  text_box: svg_path.BoundingBox,
  x_scale: Float,
  coil_map: fn(svg_path.Point) -> Result(svg_path.Point, offset.Error),
  mapped mapped: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), svg_path.PointMapError(offset.Error)) {
  case verticals {
    [] -> Ok(list.reverse(mapped))
    [line, ..rest] -> {
      use mapped_line <- result.try(
        svg_path.subpath_try_map_points(line, with: fn(point) {
          source_point_to_offset_point(point, text_box, x_scale, 0.0, coil_map)
        }),
      )
      map_vertical_grid_loop(rest, text_box, x_scale, coil_map, mapped: [
        mapped_line,
        ..mapped
      ])
    }
  }
}

fn focus_view_box(rectangle_box: svg_path.BoundingBox) -> svg_path.BoundingBox {
  let center = svg_path.bounding_box_center(rectangle_box)
  let width = svg_path.bounding_box_width(rectangle_box) /. 0.3
  let height = svg_path.bounding_box_height(rectangle_box) /. 0.3
  svg_path.BoundingBox(
    min: svg_path.Point(center.x -. width /. 2.0, center.y -. height /. 2.0),
    max: svg_path.Point(center.x +. width /. 2.0, center.y +. height /. 2.0),
  )
}

fn offset_map_view_box(
  content_box: svg_path.BoundingBox,
) -> svg_path.BoundingBox {
  svg_path.BoundingBox(
    min: svg_path.Point(content_box.min.x -. 30.0, content_box.min.y -. 30.0),
    max: svg_path.Point(content_box.max.x +. 30.0, content_box.max.y +. 45.0),
  )
}

fn background_rectangle(view_box: svg_path.BoundingBox) -> svg.ThingToDraw {
  svg.Rectangle(
    view_box.min,
    svg_path.bounding_box_width(view_box),
    svg_path.bounding_box_height(view_box),
    "fill: #ffffff; stroke: none",
  )
}

type TextLayout {
  TextLayout(
    x_scale: Float,
    text_length: Float,
    gap: Float,
    full_copies: Int,
    remainder: Float,
  )
}

fn text_layout(
  text_box: svg_path.BoundingBox,
  coil_length: Float,
) -> TextLayout {
  let width = svg_path.bounding_box_width(text_box)
  let height = svg_path.bounding_box_height(text_box)
  let x_scale = height /. band_height
  let text_length = width *. x_scale
  let gap = band_height
  let pitch = text_length +. gap
  let full_copies = full_copy_count(coil_length, pitch, text_length, count: 0)
  let remainder = coil_length -. int.to_float(full_copies) *. pitch
  TextLayout(x_scale:, text_length:, gap:, full_copies:, remainder:)
}

fn full_copy_count(
  remaining: Float,
  pitch: Float,
  text_length: Float,
  count count: Int,
) -> Int {
  case remaining >=. text_length {
    False -> count
    True ->
      full_copy_count(remaining -. pitch, pitch, text_length, count: count + 1)
  }
}

fn repeated_text_on_coil(
  text_path: svg_path.Path,
  text_box: svg_path.BoundingBox,
  layout: TextLayout,
  coil_map: fn(svg_path.Point) -> Result(svg_path.Point, offset.Error),
) -> Result(svg_path.Path, svg_path.PointMapError(offset.Error)) {
  let copies =
    repeated_text_copies(
      text_path,
      text_box,
      layout,
      coil_map,
      index: 0,
      mapped: [],
    )
  let mapped = case layout.remainder >. 0.0 {
    False -> copies
    True -> {
      let available_width =
        float.min(
          svg_path.bounding_box_width(text_box),
          layout.remainder /. layout.x_scale,
        )
      case available_width <=. 0.0 {
        True -> copies
        False -> {
          let start_distance =
            int.to_float(layout.full_copies)
            *. { layout.text_length +. layout.gap }
          let assert Ok(last) =
            map_text_copy_to_coil(
              text_path,
              text_box,
              layout.x_scale,
              start_distance,
              available_width:,
              coil_map:,
            )
          [last, ..copies]
        }
      }
    }
  }

  Ok(svg_path.Path(
    mapped |> list.reverse |> list.flat_map(svg_path.path_subpaths),
  ))
}

fn repeated_text_copies(
  text_path: svg_path.Path,
  text_box: svg_path.BoundingBox,
  layout: TextLayout,
  coil_map: fn(svg_path.Point) -> Result(svg_path.Point, offset.Error),
  index index: Int,
  mapped mapped: List(svg_path.Path),
) -> List(svg_path.Path) {
  case index >= layout.full_copies {
    True -> mapped
    False -> {
      let start_distance =
        int.to_float(index) *. { layout.text_length +. layout.gap }
      let assert Ok(copy) =
        map_text_copy_to_coil(
          text_path,
          text_box,
          layout.x_scale,
          start_distance,
          available_width: svg_path.bounding_box_width(text_box),
          coil_map:,
        )
      repeated_text_copies(
        text_path,
        text_box,
        layout,
        coil_map,
        index: index + 1,
        mapped: [copy, ..mapped],
      )
    }
  }
}

fn map_text_copy_to_coil(
  text_path: svg_path.Path,
  text_box: svg_path.BoundingBox,
  x_scale: Float,
  start_distance: Float,
  available_width available_width: Float,
  coil_map coil_map: fn(svg_path.Point) -> Result(svg_path.Point, offset.Error),
) -> Result(svg_path.Path, svg_path.PointMapError(offset.Error)) {
  svg_path.path_try_map_points(text_path, with: fn(point) {
    source_point_to_offset_point(
      svg_path.Point(
        float.min(point.x, text_box.min.x +. available_width),
        point.y,
      ),
      text_box,
      x_scale,
      start_distance,
      coil_map,
    )
  })
}

fn source_point_to_offset_point(
  point: svg_path.Point,
  text_box: svg_path.BoundingBox,
  x_scale: Float,
  start_distance: Float,
  coil_map: fn(svg_path.Point) -> Result(svg_path.Point, offset.Error),
) -> Result(svg_path.Point, offset.Error) {
  let height = svg_path.bounding_box_height(text_box)
  let source_x = point.x -. text_box.min.x
  let distance = start_distance +. source_x *. x_scale
  let band_offset =
    band_inner +. { text_box.max.y -. point.y } /. height *. band_height
  coil_map(svg_path.Point(distance, band_offset))
}

fn coil_subpath(turns turns: Int, samples _samples: Int) -> svg_path.Subpath {
  let total_degrees = int.to_float(turns) *. 360.0
  let assert Ok(subpath) =
    svg_path.subpath_parametric_with(
      from: 0.0,
      to: total_degrees,
      point: coil_point_at_degrees,
      options: svg_path.ParametricOptions(
        tolerance: 0.001,
        samples_per_piece: 3,
        initial_piece_count: turns * 36,
        max_depth: 0,
        tangent: Some(coil_tangent_at_degrees),
      ),
    )
  subpath
}

fn coil_point_at_degrees(degrees: Float) -> svg_path.Point {
  let radians = degrees *. pi /. 180.0
  svg_path.Point(
    100.0 *. trig.cos_degrees(degrees) +. 16.0 *. radians,
    100.0 *. trig.sin_degrees(degrees),
  )
}

fn coil_tangent_at_degrees(degrees: Float) -> svg_path.Point {
  let angle_derivative = pi /. 180.0
  svg_path.Point(
    16.0
      *. angle_derivative
      -. 100.0
      *. trig.sin_degrees(degrees)
      *. angle_derivative,
    100.0 *. trig.cos_degrees(degrees) *. angle_derivative,
  )
}

fn decaying_spiral_subpath(
  turns turns: Int,
  samples _samples: Int,
) -> svg_path.Subpath {
  let total_degrees = int.to_float(turns) *. 360.0
  let assert Ok(subpath) =
    svg_path.subpath_parametric_with(
      from: 0.0,
      to: total_degrees,
      point: decaying_spiral_point_at_degrees,
      options: svg_path.ParametricOptions(
        tolerance: 0.001,
        samples_per_piece: 3,
        initial_piece_count: turns * 36,
        max_depth: 0,
        tangent: Some(decaying_spiral_tangent_at_degrees),
      ),
    )
  subpath
}

fn decaying_spiral_point_at_degrees(degrees: Float) -> svg_path.Point {
  let radius = 100.0 *. decay_for_degrees(degrees)
  svg_path.Point(
    radius *. trig.cos_degrees(degrees),
    radius *. trig.sin_degrees(degrees),
  )
}

fn decaying_spiral_tangent_at_degrees(degrees: Float) -> svg_path.Point {
  let radius = 100.0 *. decay_for_degrees(degrees)
  let radius_derivative = log(0.8) /. 360.0 *. radius
  let angle_derivative = pi /. 180.0
  svg_path.Point(
    radius_derivative
      *. trig.cos_degrees(degrees)
      -. radius
      *. trig.sin_degrees(degrees)
      *. angle_derivative,
    radius_derivative
      *. trig.sin_degrees(degrees)
      +. radius
      *. trig.cos_degrees(degrees)
      *. angle_derivative,
  )
}

fn decaying_offset_map(
  spiral_length: Float,
  spiral_map: fn(svg_path.Point) -> Result(svg_path.Point, offset.Error),
) -> fn(svg_path.Point) -> Result(svg_path.Point, offset.Error) {
  fn(point: svg_path.Point) {
    let mapped_length = slowed_spiral_length(point.x, spiral_length)
    let length =
      mapped_length
      |> float.max(0.0)
      |> float.min(maximum_spiral_query_length(spiral_length))
    let local_decay = decay_for_length(length, spiral_length)
    spiral_map(svg_path.Point(length, point.y *. local_decay))
  }
}

fn slowed_spiral_length(source_distance: Float, total_length: Float) -> Float {
  let positive_rate = 0.0 -. decay_rate_per_length(total_length)
  log(1.0 +. positive_rate *. source_distance) /. positive_rate
}

fn source_distance_for_spiral_length(
  length: Float,
  total_length: Float,
) -> Float {
  let positive_rate = 0.0 -. decay_rate_per_length(total_length)
  { exp(positive_rate *. length) -. 1.0 } /. positive_rate
}

fn decay_rate_per_length(total_length: Float) -> Float {
  5.0 *. log(0.8) /. total_length
}

fn maximum_spiral_query_length(spiral_length: Float) -> Float {
  spiral_length -. 0.000001
}

fn decay_for_length(length: Float, total_length: Float) -> Float {
  let turns_at_length = length /. total_length *. 5.0
  pow(0.8, turns_at_length)
}

fn decay_for_degrees(degrees: Float) -> Float {
  pow(0.8, degrees /. 360.0)
}

fn points_to_subpath(points: List(svg_path.Point)) -> svg_path.Subpath {
  let assert [first, second, ..rest] = points
  svg_path.subpath_assert(
    points_to_segments(second, rest, previous: first, segments: []),
  )
}

fn points_to_segments(
  point: svg_path.Point,
  rest: List(svg_path.Point),
  previous previous: svg_path.Point,
  segments segments: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  let segments = [svg_path.Line(start: previous, end: point), ..segments]
  case rest {
    [] -> list.reverse(segments)
    [next, ..remaining] ->
      points_to_segments(next, remaining, previous: point, segments:)
  }
}

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(String, Dynamic)

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic

@external(erlang, "math", "pow")
fn pow(base: Float, exponent: Float) -> Float

@external(erlang, "math", "log")
fn log(value: Float) -> Float

@external(erlang, "math", "exp")
fn exp(value: Float) -> Float
