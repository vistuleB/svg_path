import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/list
import svg_path
import svg_path/offset
import svg_path/svg

const output_path = "examples/debug/figure_eight_band_correspondence_blocks.svg"

pub fn main() {
  let contents = figure_eight_correspondence_blocks()
  let _ = ensure_dir(output_path)
  let _ = write_file(output_path, contents)
  Nil
}

pub fn figure_eight_correspondence_blocks() -> String {
  let source = figure_eight()
  let options = offset.Options(..offset.default_options(), join: offset.Round)
  let assert Ok(band) =
    offset.subpath_band_with(
      source,
      distance_a: 18.0,
      distance_b: 34.0,
      options:,
    )
  let assert Ok(blocks) =
    offset.internal_synchronized_offset_area_trace(
      source,
      inner_distance: 18.0,
      outer_distance: 34.0,
      options:,
    )
  let assert Ok(joins) =
    offset.internal_synchronized_join_trace(
      source,
      inner_distance: 18.0,
      outer_distance: 34.0,
      options:,
    )
  let block_drawings =
    blocks
    |> list.index_map(fn(block, index) {
      let offset.SynchronizedOffsetTraceArea(
        inner_segments:,
        outer_segments:,
        ..,
      ) = block
      correspondence_drawing(inner_segments, outer_segments, index)
    })
    |> list.flatten
  let join_drawings =
    joins
    |> list.index_map(fn(join, index) {
      let offset.SynchronizedOffsetTraceJoin(
        inner_segments:,
        outer_segments:,
        ..,
      ) = join
      correspondence_drawing(
        inner_segments,
        outer_segments,
        index + list.length(blocks),
      )
    })
    |> list.flatten
  let geometry = svg_path.Path([source, ..svg_path.path_subpaths(band)])
  let assert Ok(bounds) = svg_path.path_bounding_box(geometry)
  let view_box = padded_box(bounds, fraction: 0.15)
  let svg_path.BoundingBox(min:, max:) = view_box
  svg.document(
    things: [
      svg.Rectangle(min, max.x -. min.x, max.y -. min.y, "fill: #ffffff"),
      svg.StyledPath(band, "fill: #f1f5f9; stroke: none"),
      ..list.append(block_drawings, join_drawings)
      |> list.append([
        svg.StyledPath(band, "fill: none; stroke: #0f172a; stroke-width: 1.5"),
        svg.StyledPath(
          svg_path.subpath_as_path(source),
          "fill: none; stroke: #111827; stroke-width: 1.2; stroke-dasharray: 7 6",
        ),
      ])
    ],
    view_box:,
  )
}

fn padded_box(box: svg_path.BoundingBox, fraction fraction: Float) {
  let svg_path.BoundingBox(min:, max:) = box
  let x_padding = { max.x -. min.x } *. fraction
  let y_padding = { max.y -. min.y } *. fraction
  svg_path.BoundingBox(
    min: svg_path.Point(min.x -. x_padding, min.y -. y_padding),
    max: svg_path.Point(max.x +. x_padding, max.y +. y_padding),
  )
}

fn correspondence_drawing(
  inner: List(svg_path.Segment),
  outer: List(svg_path.Segment),
  index: Int,
) -> List(svg.ThingToDraw) {
  case correspondence_subpath(inner, outer) {
    Error(_) -> []
    Ok(area) -> [
      svg.StyledPath(
        svg_path.subpath_as_path(area),
        "fill: "
          <> color(index)
          <> "; fill-opacity: 0.42; stroke: "
          <> color(index)
          <> "; stroke-opacity: 0.7; stroke-width: 0.8",
      ),
    ]
  }
}

fn correspondence_subpath(
  inner: List(svg_path.Segment),
  outer: List(svg_path.Segment),
) -> Result(svg_path.Subpath, Nil) {
  case inner, outer, list.last(inner), list.last(outer) {
    [inner_first, ..], [outer_first, ..], Ok(inner_last), Ok(outer_last) -> {
      let outer_end = svg_path.segment_end(outer_last)
      let inner_end = svg_path.segment_end(inner_last)
      let inner_start = svg_path.segment_start(inner_first)
      let outer_start = svg_path.segment_start(outer_first)
      let segments =
        list.append(outer, [
          svg_path.Line(start: outer_end, end: inner_end),
          ..list.append(reverse_segments(inner), [
            svg_path.Line(start: inner_start, end: outer_start),
          ])
        ])
      Ok(
        svg_path.subpath_assert(segments)
        |> svg_path.subpath_assert_set_closed(closed: True),
      )
    }
    _, _, _, _ -> Error(Nil)
  }
}

fn reverse_segments(
  segments: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  segments |> list.reverse |> list.map(svg_path.segment_reverse)
}

fn color(index: Int) -> String {
  let colors = [
    "#ef4444",
    "#3b82f6",
    "#22c55e",
    "#f59e0b",
    "#a855f7",
    "#06b6d4",
    "#ec4899",
    "#84cc16",
  ]
  let assert Ok(color_index) = int.modulo(index, by: list.length(colors))
  let assert [selected, ..] = list.drop(colors, color_index)
  selected
}

fn figure_eight() -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(-336.0, -234.0),
      control2: svg_path.Point(-336.0, 234.0),
      end: svg_path.Point(0.0, 0.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(336.0, -234.0),
      control2: svg_path.Point(336.0, 234.0),
      end: svg_path.Point(0.0, 0.0),
    ),
  ])
  |> svg_path.subpath_assert_set_closed(closed: True)
}

@external(erlang, "filelib", "ensure_dir")
fn ensure_dir(path: String) -> Dynamic

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
