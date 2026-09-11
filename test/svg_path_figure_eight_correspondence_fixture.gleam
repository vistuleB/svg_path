import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/list
import svg_path
import svg_path/offset
import svg_path/svg

const output_path = "examples/debug/figure_eight_band_correspondence_blocks.svg"

pub fn main() {
  let _ = ensure_dir(output_path)
  let _ = write_file(output_path, figure_eight_correspondence_blocks())
  Nil
}

pub fn figure_eight_correspondence_blocks() -> String {
  let source = figure_eight()
  let options = offset.default_options()
  let assert Ok(band) =
    offset.subpath_band_with(
      source,
      inner_offset: 18.0,
      outer_offset: 34.0,
      join: offset.Round,
      cap: offset.Butt,
      options:,
    )
  let assert Ok(untrimmed) =
    offset.subpath_band_untrimmed_with(
      source,
      inner_offset: 18.0,
      outer_offset: 34.0,
      join: offset.Round,
      options:,
    )
  let block_drawings = case svg_path.path_subpaths(untrimmed) {
    [inner_walk, outer_walk] ->
      svg_path.subpath_segments(inner_walk)
      |> list.index_map(fn(inner_segment, index) {
        paired_block_drawing(inner_segment, outer_walk, index)
      })
      |> list.flatten
    _ -> []
  }
  let geometry = svg_path.Path([source, ..svg_path.path_subpaths(band)])
  let assert Ok(bounds) = svg_path.path_bounding_box(geometry)
  let view_box = padded_box(bounds, fraction: 0.15)
  let svg_path.BoundingBox(min:, max:) = view_box
  svg.document(
    things: [
      svg.Rectangle(min, max.x -. min.x, max.y -. min.y, "fill: #ffffff"),
      svg.StyledPath(band, "fill: #f1f5f9; stroke: none"),
      ..list.append(block_drawings, [
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

fn paired_block_drawing(
  inner: svg_path.Segment,
  outer_walk: svg_path.Subpath,
  index: Int,
) -> List(svg.ThingToDraw) {
  case best_outer_segment(inner, svg_path.subpath_segments(outer_walk)) {
    Error(_) -> []
    Ok(outer) -> {
      let area = block_subpath(inner, outer)
      [
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
}

fn best_outer_segment(
  inner: svg_path.Segment,
  outer_segments: List(svg_path.Segment),
) -> Result(svg_path.Segment, Nil) {
  case outer_segments {
    [] -> Error(Nil)
    [first, ..rest] ->
      Ok(
        list.fold(rest, first, fn(best, candidate) {
          case pairing_score(inner, candidate) <. pairing_score(inner, best) {
            True -> candidate
            False -> best
          }
        }),
      )
  }
}

fn pairing_score(inner: svg_path.Segment, outer: svg_path.Segment) -> Float {
  point_squared_distance(
    svg_path.segment_start(inner),
    svg_path.segment_start(outer),
  )
  +. point_squared_distance(
    svg_path.segment_end(inner),
    svg_path.segment_end(outer),
  )
}

fn point_squared_distance(a: svg_path.Point, b: svg_path.Point) -> Float {
  let dx = a.x -. b.x
  let dy = a.y -. b.y
  { dx *. dx } +. { dy *. dy }
}

fn block_subpath(
  inner: svg_path.Segment,
  outer: svg_path.Segment,
) -> svg_path.Subpath {
  let assert Ok(open) =
    svg_path.subpath_with(
      [inner, svg_path.segment_reverse(outer)],
      policy: svg_path.Bridge,
    )
  let assert Ok(closed) =
    svg_path.subpath_close_with(open, policy: svg_path.Bridge)
  closed
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
  |> svg_path.subpath_assert_close()
}

@external(erlang, "filelib", "ensure_dir")
fn ensure_dir(path: String) -> Dynamic

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
