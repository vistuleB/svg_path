//// Isolated package-title A diagnostic for second-offset U1 and its E preimage.

import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/string
import svg_path
import svg_path/offset
import svg_path/parse
import svg_path/svg

const input = "examples/debug/package_title.svg"

const output = "examples/debug/package_title_a_second_u1_preimage.svg"

const e_zoom_output = "examples/debug/package_title_a_e0_0g3_zoom.svg"

const sample_closeup_output = "examples/debug/package_title_a_u1_offset_samples_closeup.svg"

const distance = 0.4

pub fn main() -> Nil {
  let assert Ok(contents) = read_file(input)
  let assert Ok(source) = parse.path(first_path_data(contents))
  let subpaths = svg_path.path_subpaths(source)
  let assert Ok(a_outer) = list_at(subpaths, 6)
  let assert Ok(a_inner) = list_at(subpaths, 7)
  let source_a = svg_path.Path([a_outer, a_inner])
  let options =
    offset.Options(
      ..offset.default_options(),
      fitting: offset.FittingOptions(tolerance: 0.01, samples: 5, max_depth: 12),
      distance_options: svg_path.DistanceOptions(
        ..svg_path.default_distance_options(),
        tolerance: 0.000000001,
      ),
    )

  let assert Ok(first_offset) = offset.path_with(source_a, offset:, options:)
  let assert Ok(second_untrimmed) =
    offset.path_untrimmed_with(first_offset, offset:, options:)
  let assert Ok(u1) =
    untrimmed_segment(second_untrimmed, subpath_index: 0, segment_index: 1)
  let e_segment = u1_preimage()

  let _ =
    write_file(
      output,
      render(source_a, first_offset, second_untrimmed, e_segment, u1),
    )
  let _ = write_file(e_zoom_output, render_e_zoom(first_offset, e_segment, u1))
  let _ =
    write_file(sample_closeup_output, render_sample_closeup(e_segment, u1))
  Nil
}

fn untrimmed_segment(
  path: svg_path.Path,
  subpath_index subpath_index: Int,
  segment_index segment_index: Int,
) -> Result(svg_path.Segment, Nil) {
  let assert Ok(subpath) = list_at(svg_path.path_subpaths(path), subpath_index)
  list_at(svg_path.subpath_segments(subpath), segment_index)
}

fn u1_preimage() -> svg_path.Segment {
  svg_path.CubicBezier(
    start: svg_path.Point(64.0594463192202, 9.938508893593266),
    control1: svg_path.Point(64.0594463192202, 9.938508893593266),
    control2: svg_path.Point(64.05960458352459, 9.93898368650646),
    end: svg_path.Point(64.06001516129359, 9.939884020213311),
  )
}

fn render(
  source: svg_path.Path,
  first_offset: svg_path.Path,
  second_untrimmed: svg_path.Path,
  e_segment: svg_path.Segment,
  u1: svg_path.Segment,
) -> String {
  let view_box =
    path_boxes([
      segment_path(e_segment),
      segment_path(u1),
    ])
    |> padded_box(margin: 0.35)

  let font = 0.035
  let stroke = 0.008
  let sample_markers =
    offset_sample_markers(
      e_segment,
      u1,
      options: svg_path.default_distance_options(),
      line_width: 0.003,
      sample_radius: 0.014,
      projection_radius: 0.01,
      label_size: 0.026,
      label_delta: svg_path.Point(0.016, -0.016),
    )
  let things = [
    background(view_box),
    svg.StyledPath(source, "fill: #d1d5db; stroke: none; opacity: 0.55"),
    svg.StyledPath(
      first_offset,
      "fill: none; stroke: #2563eb; stroke-width: "
        <> float.to_string(stroke)
        <> "; stroke-linecap: round; stroke-linejoin: round; opacity: 0.45",
    ),
    svg.StyledPath(
      second_untrimmed,
      "fill: none; stroke: #9ca3af; stroke-width: "
        <> float.to_string(stroke)
        <> "; stroke-linecap: round; stroke-linejoin: round; opacity: 0.45",
    ),
    svg.StyledPath(
      segment_path(e_segment),
      "fill: none; stroke: #16a34a; stroke-width: "
        <> float.to_string(2.5 *. stroke)
        <> "; stroke-linecap: round; stroke-linejoin: round",
    ),
    svg.StyledPath(
      segment_path(u1),
      "fill: none; stroke: #dc2626; stroke-width: "
        <> float.to_string(2.5 *. stroke)
        <> "; stroke-linecap: round; stroke-linejoin: round",
    ),
    endpoint_dot(svg_path.segment_start(e_segment), "#16a34a", 0.012),
    endpoint_dot(svg_path.segment_end(e_segment), "#16a34a", 0.012),
    endpoint_dot(svg_path.segment_start(u1), "#dc2626", 0.012),
    endpoint_dot(svg_path.segment_end(u1), "#dc2626", 0.012),
    svg.Text(
      "E0.0g3",
      label_style("#166534"),
      label_point(e_segment, 0.58, svg_path.Point(0.03, -0.025)),
      font,
    ),
    svg.Text(
      "U1",
      label_style("#991b1b"),
      label_point(u1, 0.45, svg_path.Point(0.03, 0.035)),
      font,
    ),
    ..sample_markers
  ]

  svg.document(things:, view_box:)
  |> with_root_size(width: 1400, height: 900)
}

fn render_e_zoom(
  first_offset: svg_path.Path,
  e_segment: svg_path.Segment,
  u1: svg_path.Segment,
) -> String {
  let view_box =
    path_boxes([
      segment_path(e_segment),
      segment_path(u1),
    ])
    |> padded_box(margin: 0.004)
  let stroke = 0.00006
  let dot = 0.00018
  let font = 0.00042
  let assert svg_path.CubicBezier(start:, control1:, control2:, end:) =
    e_segment
  let sample_markers =
    offset_sample_markers(
      e_segment,
      u1,
      options: svg_path.default_distance_options(),
      line_width: 0.000035,
      sample_radius: 0.00022,
      projection_radius: 0.00016,
      label_size: 0.00036,
      label_delta: svg_path.Point(0.00022, -0.00022),
    )
  let things = [
    background(view_box),
    svg.StyledPath(
      first_offset,
      "fill: none; stroke: #9ca3af; stroke-width: "
        <> float.to_string(stroke)
        <> "; stroke-linecap: round; stroke-linejoin: round; opacity: 0.55",
    ),
    svg.StyledPath(
      segment_path(u1),
      "fill: none; stroke: #dc2626; stroke-width: "
        <> float.to_string(4.0 *. stroke)
        <> "; stroke-linecap: round; stroke-linejoin: round",
    ),
    svg.StyledPath(
      segment_path(e_segment),
      "fill: none; stroke: #16a34a; stroke-width: "
        <> float.to_string(4.0 *. stroke)
        <> "; stroke-linecap: round; stroke-linejoin: round",
    ),
    svg.StyledPath(
      segment_path(svg_path.Line(start:, end: control1)),
      "fill: none; stroke: #64748b; stroke-width: "
        <> float.to_string(stroke)
        <> "; stroke-dasharray: "
        <> float.to_string(3.0 *. stroke)
        <> " "
        <> float.to_string(3.0 *. stroke),
    ),
    svg.StyledPath(
      segment_path(svg_path.Line(start: control2, end:)),
      "fill: none; stroke: #64748b; stroke-width: "
        <> float.to_string(stroke)
        <> "; stroke-dasharray: "
        <> float.to_string(3.0 *. stroke)
        <> " "
        <> float.to_string(3.0 *. stroke),
    ),
    endpoint_dot(start, "#16a34a", dot),
    endpoint_dot(end, "#16a34a", dot),
    endpoint_dot(control1, "#2563eb", dot),
    endpoint_dot(control2, "#f59e0b", dot),
    svg.Text(
      "start/c1",
      label_style("#166534"),
      svg_path.Point(start.x +. 0.0002, start.y -. 0.00035),
      font,
    ),
    svg.Text(
      "c2",
      label_style("#92400e"),
      svg_path.Point(control2.x +. 0.0002, control2.y -. 0.00035),
      font,
    ),
    svg.Text(
      "end",
      label_style("#166534"),
      svg_path.Point(end.x +. 0.0002, end.y +. 0.00055),
      font,
    ),
    svg.Text(
      "E0.0g3",
      label_style("#166534"),
      label_point(e_segment, 0.55, svg_path.Point(0.00025, 0.0003)),
      font,
    ),
    svg.Text(
      "U1",
      label_style("#991b1b"),
      label_point(u1, 0.5, svg_path.Point(0.00025, 0.0003)),
      font,
    ),
    ..sample_markers
  ]

  svg.document(things:, view_box:)
  |> with_root_size(width: 1400, height: 900)
}

fn render_sample_closeup(
  e_segment: svg_path.Segment,
  u1: svg_path.Segment,
) -> String {
  let scale = 10_000.0
  let origin = svg_path.segment_start(u1)
  let samples = offset_sample_points(e_segment)
  let offset_start = scale_point(svg_path.segment_start(u1), origin, scale)
  let offset_end = scale_point(svg_path.segment_end(u1), origin, scale)
  let samples = samples |> list.map(scale_point(_, origin, scale))
  let u1 = scale_segment(u1, origin, scale)
  let view_box =
    point_box([offset_start, offset_end, ..samples])
    |> padded_point_box(margin: 120.0)
  let stroke = 3.5
  let dot = 10.5
  let font = 24.0
  let things = [
    background(view_box),
    svg.StyledPath(
      segment_path(u1),
      "fill: none; stroke: #dc2626; stroke-width: "
        <> float.to_string(stroke)
        <> "; stroke-linecap: round; stroke-linejoin: round; opacity: 0.55",
    ),
    svg.StyledPath(
      segment_path(svg_path.Line(start: offset_start, end: offset_end)),
      "fill: none; stroke: #dc2626; stroke-width: "
        <> float.to_string(stroke /. 2.0)
        <> "; stroke-dasharray: "
        <> float.to_string(3.0 *. stroke)
        <> " "
        <> float.to_string(3.0 *. stroke)
        <> "; opacity: 0.8",
    ),
    ..sample_closeup_markers(samples, dot: dot, font: font)
  ]
  let things =
    list.append(things, [
      endpoint_dot(offset_start, "#dc2626", dot *. 1.2),
      endpoint_dot(offset_end, "#dc2626", dot *. 1.2),
      svg.Text(
        "offset start",
        label_style("#991b1b"),
        svg_path.Point(offset_start.x +. 0.0014, offset_start.y -. 0.0015),
        font,
      ),
      svg.Text(
        "offset end",
        label_style("#991b1b"),
        svg_path.Point(offset_end.x +. 0.0014, offset_end.y +. 0.0022),
        font,
      ),
    ])

  svg.document(things:, view_box:)
  |> with_root_size(width: 1400, height: 900)
}

fn scale_segment(
  segment: svg_path.Segment,
  origin: svg_path.Point,
  factor: Float,
) -> svg_path.Segment {
  case segment {
    svg_path.Line(start:, end:) ->
      svg_path.Line(
        start: scale_point(start, origin, factor),
        end: scale_point(end, origin, factor),
      )
    svg_path.QuadraticBezier(start:, control:, end:) ->
      svg_path.QuadraticBezier(
        start: scale_point(start, origin, factor),
        control: scale_point(control, origin, factor),
        end: scale_point(end, origin, factor),
      )
    svg_path.CubicBezier(start:, control1:, control2:, end:) ->
      svg_path.CubicBezier(
        start: scale_point(start, origin, factor),
        control1: scale_point(control1, origin, factor),
        control2: scale_point(control2, origin, factor),
        end: scale_point(end, origin, factor),
      )
    svg_path.Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:) ->
      svg_path.Arc(
        start: scale_point(start, origin, factor),
        radius: svg_path.Point(radius.x *. factor, radius.y *. factor),
        x_axis_rotation:,
        large_arc:,
        sweep:,
        end: scale_point(end, origin, factor),
      )
  }
}

fn scale_point(
  point: svg_path.Point,
  origin: svg_path.Point,
  factor: Float,
) -> svg_path.Point {
  svg_path.Point(
    { point.x -. origin.x } *. factor,
    { point.y -. origin.y } *. factor,
  )
}

fn point_box(points: List(svg_path.Point)) -> svg_path.BoundingBox {
  let assert [first, ..] = points
  list.fold(
    points,
    svg_path.BoundingBox(min: first, max: first),
    fn(acc, point) {
      let svg_path.BoundingBox(min:, max:) = acc
      svg_path.BoundingBox(
        min: svg_path.Point(
          float.min(min.x, point.x),
          float.min(min.y, point.y),
        ),
        max: svg_path.Point(
          float.max(max.x, point.x),
          float.max(max.y, point.y),
        ),
      )
    },
  )
}

fn padded_point_box(
  box: svg_path.BoundingBox,
  margin margin: Float,
) -> svg_path.BoundingBox {
  let svg_path.BoundingBox(min:, max:) = box
  svg_path.BoundingBox(
    min: svg_path.Point(min.x -. margin, min.y -. margin),
    max: svg_path.Point(max.x +. margin, max.y +. margin),
  )
}

fn offset_sample_points(source: svg_path.Segment) -> List(svg_path.Point) {
  [1, 2, 3, 4, 5]
  |> list.filter_map(fn(index) {
    e_offset_point(source, int.to_float(index) /. 6.0, distance)
  })
}

fn sample_closeup_markers(
  samples: List(svg_path.Point),
  dot dot: Float,
  font font: Float,
) -> List(svg.ThingToDraw) {
  samples
  |> list.index_map(fn(sample, index) {
    let sample_index = index + 1
    [
      svg.Circle(
        sample,
        dot,
        "fill: #7c3aed; stroke: #ffffff; stroke-width: "
          <> float.to_string(dot /. 3.0),
      ),
      svg.Text(
        "s" <> int.to_string(sample_index),
        label_style("#581c87"),
        svg_path.Point(sample.x +. 0.0014, sample.y -. 0.0012),
        font,
      ),
    ]
  })
  |> list.flatten
}

fn offset_sample_markers(
  source: svg_path.Segment,
  candidate: svg_path.Segment,
  options options: svg_path.DistanceOptions,
  line_width line_width: Float,
  sample_radius sample_radius: Float,
  projection_radius projection_radius: Float,
  label_size label_size: Float,
  label_delta label_delta: svg_path.Point,
) -> List(svg.ThingToDraw) {
  [1, 2, 3, 4, 5]
  |> list.flat_map(fn(index) {
    let t = int.to_float(index) /. 6.0
    case e_offset_point(source, t, distance) {
      Error(_) -> []
      Ok(sample) -> {
        let projection =
          svg_path.segment_projection_with(sample, to: candidate, options:)
        let projection_point = case projection {
          Ok(svg_path.SegmentProjection(point:, ..)) -> point
          Error(_) -> sample
        }
        [
          svg.StyledPath(
            segment_path(svg_path.Line(start: sample, end: projection_point)),
            "fill: none; stroke: #7c3aed; stroke-width: "
              <> float.to_string(line_width)
              <> "; opacity: 0.75",
          ),
          svg.Circle(
            sample,
            sample_radius,
            "fill: #7c3aed; stroke: #ffffff; stroke-width: "
              <> float.to_string(sample_radius /. 3.0),
          ),
          svg.Circle(
            projection_point,
            projection_radius,
            "fill: #f97316; stroke: #ffffff; stroke-width: "
              <> float.to_string(projection_radius /. 3.0),
          ),
          svg.Text(
            "s" <> int.to_string(index),
            label_style("#581c87"),
            svg_path.Point(sample.x +. label_delta.x, sample.y +. label_delta.y),
            label_size,
          ),
        ]
      }
    }
  })
}

fn e_offset_point(
  segment: svg_path.Segment,
  t: Float,
  distance: Float,
) -> Result(svg_path.Point, Nil) {
  case svg_path.segment_point(segment, t), unit_normal_for_debug(segment, t) {
    Ok(point), Ok(normal) ->
      Ok(svg_path.Point(
        point.x +. distance *. normal.x,
        point.y +. distance *. normal.y,
      ))
    _, _ -> Error(Nil)
  }
}

fn unit_normal_for_debug(
  segment: svg_path.Segment,
  t: Float,
) -> Result(svg_path.Point, Nil) {
  case svg_path.segment_directions(segment, at: t) {
    Ok(svg_path.Directions(incoming:, outgoing:)) -> {
      let direction = case incoming, outgoing {
        _, Some(outgoing) -> Ok(outgoing)
        Some(incoming), _ -> Ok(incoming)
        _, _ -> Error(Nil)
      }
      case direction {
        Ok(direction) -> Ok(svg_path.Point(direction.y, 0.0 -. direction.x))
        Error(_) -> Error(Nil)
      }
    }
    Error(_) -> Error(Nil)
  }
}

fn label_point(
  segment: svg_path.Segment,
  t: Float,
  delta: svg_path.Point,
) -> svg_path.Point {
  let assert Ok(point) = svg_path.segment_point(segment, t)
  svg_path.Point(point.x +. delta.x, point.y +. delta.y)
}

fn label_style(color: String) -> String {
  "fill: "
  <> color
  <> "; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; paint-order: stroke; stroke: #ffffff; stroke-width: 0.012"
}

fn endpoint_dot(
  point: svg_path.Point,
  color: String,
  radius: Float,
) -> svg.ThingToDraw {
  svg.Circle(
    point,
    radius,
    "fill: "
      <> color
      <> "; stroke: #ffffff; stroke-width: "
      <> float.to_string(radius /. 3.0),
  )
}

fn segment_path(segment: svg_path.Segment) -> svg_path.Path {
  svg_path.Path([svg_path.subpath_assert([segment])])
}

fn path_boxes(paths: List(svg_path.Path)) -> List(svg_path.BoundingBox) {
  paths |> list.filter_map(svg_path.path_bounding_box)
}

fn background(view_box: svg_path.BoundingBox) -> svg.ThingToDraw {
  svg.Rectangle(
    view_box.min,
    svg_path.bounding_box_width(view_box),
    svg_path.bounding_box_height(view_box),
    "fill: #ffffff; stroke: none",
  )
}

fn padded_box(
  boxes: List(svg_path.BoundingBox),
  margin margin: Float,
) -> svg_path.BoundingBox {
  let assert [first, ..] = boxes
  let combined =
    list.fold(boxes, first, fn(acc, box) { combine_boxes(acc, box) })
  let svg_path.BoundingBox(min:, max:) = combined

  svg_path.BoundingBox(
    min: svg_path.Point(min.x -. margin, min.y -. margin),
    max: svg_path.Point(max.x +. margin, max.y +. margin),
  )
}

fn combine_boxes(
  left: svg_path.BoundingBox,
  right: svg_path.BoundingBox,
) -> svg_path.BoundingBox {
  svg_path.BoundingBox(
    min: svg_path.Point(
      float.min(left.min.x, right.min.x),
      float.min(left.min.y, right.min.y),
    ),
    max: svg_path.Point(
      float.max(left.max.x, right.max.x),
      float.max(left.max.y, right.max.y),
    ),
  )
}

fn list_at(items: List(a), index: Int) -> Result(a, Nil) {
  case items, index {
    [], _ -> Error(Nil)
    [first, ..], 0 -> Ok(first)
    [_, ..rest], _ -> list_at(rest, index - 1)
  }
}

fn with_root_size(
  svg_document: String,
  width width: Int,
  height height: Int,
) -> String {
  let assert Ok(#(before_width, after_width)) =
    string.split_once(svg_document, on: "\" width=\"")
  let assert Ok(#(_, after_height)) =
    string.split_once(after_width, on: "\" height=\"")
  let assert Ok(#(_, rest)) = string.split_once(after_height, on: "\">")

  before_width
  <> "\" width=\""
  <> int.to_string(width)
  <> "\" height=\""
  <> int.to_string(height)
  <> "\">"
  <> rest
}

fn first_path_data(contents: String) -> String {
  let assert [_, after_attribute] = string.split(contents, on: " d=\"")
  let assert [data, ..] = string.split(after_attribute, on: "\"")
  data
}

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(String, Nil)

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Result(Nil, Dynamic)
