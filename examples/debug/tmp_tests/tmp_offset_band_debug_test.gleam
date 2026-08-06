import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/list
import svg_path
import svg_path/offset
import svg_path/svg
import svg_path/transform

const output = "examples/debug/svg_path_offset_band_gallery.svg"

const panel_w = 240.0

const panel_h = 170.0

const gap = 18.0

type Example {
  Example(
    label: String,
    source: svg_path.Subpath,
    distance_a: Float,
    distance_b: Float,
    join: offset.Join,
  )
}

pub fn main() -> Nil {
  let _ = write_file(output, render())
  Nil
}

fn render() -> String {
  svg.document(
    things: list.flatten([
      panel(
        row: 0,
        column: 0,
        example: Example(
          label: "open curve: -10 / 10",
          source: open_curve(),
          distance_a: -10.0,
          distance_b: 10.0,
          join: offset.Round,
        ),
      ),
      panel(
        row: 0,
        column: 1,
        example: Example(
          label: "open curve: 6 / 18",
          source: open_curve(),
          distance_a: 6.0,
          distance_b: 18.0,
          join: offset.Round,
        ),
      ),
      panel(
        row: 1,
        column: 0,
        example: Example(
          label: "concave closed: -14 / 14",
          source: concave_polygon(),
          distance_a: -14.0,
          distance_b: 14.0,
          join: offset.Round,
        ),
      ),
      panel(
        row: 1,
        column: 1,
        example: Example(
          label: "diamond miter: -22 / 8",
          source: diamond(),
          distance_a: -22.0,
          distance_b: 8.0,
          join: offset.Miter(4.0),
        ),
      ),
      panel(
        row: 2,
        column: 0,
        example: Example(
          label: "smooth figure-eight: -16 / 16",
          source: smooth_figure_eight(),
          distance_a: -16.0,
          distance_b: 16.0,
          join: offset.Round,
        ),
      ),
      panel(
        row: 2,
        column: 1,
        example: Example(
          label: "narrow concavity: -18 / 8",
          source: narrow_concavity(),
          distance_a: -18.0,
          distance_b: 8.0,
          join: offset.Round,
        ),
      ),
      panel(
        row: 3,
        column: 0,
        example: Example(
          label: "upright figure-eight bevel: 4 / 8",
          source: upright_figure_eight(),
          distance_a: 4.0,
          distance_b: 8.0,
          join: offset.Bevel,
        ),
      ),
      panel(
        row: 3,
        column: 1,
        example: Example(
          label: "upright figure-eight bevel: -8 / 8",
          source: upright_figure_eight(),
          distance_a: -8.0,
          distance_b: 8.0,
          join: offset.Bevel,
        ),
      ),
    ]),
    view_box: svg_path.BoundingBox(
      min: svg_path.Point(0.0, 0.0),
      max: svg_path.Point(
        panel_w *. 2.0 +. gap,
        panel_h *. 4.0 +. gap *. 3.0 +. gap,
      ),
    ),
  )
}

fn panel(
  row row: Int,
  column column: Int,
  example example: Example,
) -> svg.ThingsToDraw {
  let x = int_to_float(column) *. { panel_w +. gap }
  let y = int_to_float(row) *. { panel_h +. gap }
  let Example(label:, source:, distance_a:, distance_b:, join:) = example
  let matrix = transform.translate(x: x +. 34.0, y: y +. 48.0)
  let assert Ok(source) = transform.subpath(source, by: matrix)
  let default = offset.default_options()
  let options =
    offset.Options(
      ..default,
      fitting: offset.FittingOptions(..default.fitting, tolerance: 0.01),
      join:,
    )
  let result_things = case
    offset.subpath_band_with(source, distance_a:, distance_b:, options:)
  {
    Ok(result) -> [
      svg.StyledPath(
        result,
        "fill: none; stroke: #0f766e; stroke-width: 4; stroke-linecap: round; stroke-linejoin: round",
      ),
    ]
    Error(error) -> [
      svg.Text(
        error_label(error),
        "fill: #b91c1c; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-weight: 700",
        svg_path.Point(x +. 12.0, y +. 148.0),
        12,
      ),
    ]
  }

  list.append(
    [
      svg.Rectangle(
        svg_path.Point(x, y),
        panel_w,
        panel_h,
        "fill: #ffffff; stroke: #d1d5db; stroke-width: 1.5",
      ),
      svg.Text(
        label,
        "fill: #111827; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-weight: 700",
        svg_path.Point(x +. 12.0, y +. 23.0),
        13,
      ),
      svg.StyledPath(
        svg_path.subpath_as_path(source),
        "fill: none; stroke: #9ca3af; stroke-width: 1.5; stroke-linecap: round; stroke-linejoin: round; stroke-dasharray: 5 5",
      ),
    ],
    result_things,
  )
}

fn error_label(error: offset.Error) -> String {
  case error {
    offset.PathError(svg_path.OverlappingSegments) ->
      "Error: overlapping offset sections"
    offset.PathError(_) -> "Error: path operation failed"
    offset.InvalidTolerance(_) -> "Error: invalid tolerance"
    offset.InvalidSamples(_) -> "Error: invalid samples"
    offset.InvalidMaxDepth(_) -> "Error: invalid max depth"
    offset.InvalidMiterLimit(_) -> "Error: invalid miter limit"
    offset.InvalidStrokeWidth(_) -> "Error: invalid stroke width"
    offset.DegenerateTangent(_) -> "Error: degenerate tangent"
    offset.MaxDepthReached(_) -> "Error: max depth reached"
    offset.NonFinite -> "Error: non-finite coordinate"
  }
}

fn open_curve() -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 86.0),
      control1: svg_path.Point(35.0, -26.0),
      control2: svg_path.Point(104.0, 18.0),
      end: svg_path.Point(154.0, 70.0),
    ),
  ])
}

fn concave_polygon() -> svg_path.Subpath {
  svg_path.subpath_assert_polygon([
    svg_path.Point(0.0, 0.0),
    svg_path.Point(150.0, 0.0),
    svg_path.Point(150.0, 38.0),
    svg_path.Point(94.0, 38.0),
    svg_path.Point(94.0, 78.0),
    svg_path.Point(150.0, 78.0),
    svg_path.Point(150.0, 116.0),
    svg_path.Point(0.0, 116.0),
  ])
}

fn diamond() -> svg_path.Subpath {
  svg_path.subpath_assert_polygon([
    svg_path.Point(78.0, 0.0),
    svg_path.Point(156.0, 58.0),
    svg_path.Point(78.0, 116.0),
    svg_path.Point(0.0, 58.0),
  ])
}

fn narrow_concavity() -> svg_path.Subpath {
  svg_path.subpath_assert_polygon([
    svg_path.Point(0.0, 0.0),
    svg_path.Point(154.0, 0.0),
    svg_path.Point(154.0, 118.0),
    svg_path.Point(126.0, 118.0),
    svg_path.Point(126.0, 50.0),
    svg_path.Point(80.0, 50.0),
    svg_path.Point(80.0, 118.0),
    svg_path.Point(0.0, 118.0),
  ])
}

fn smooth_figure_eight() -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.CubicBezier(
      start: svg_path.Point(82.0, 58.0),
      control1: svg_path.Point(40.0, 8.0),
      control2: svg_path.Point(12.0, 112.0),
      end: svg_path.Point(82.0, 58.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.Point(82.0, 58.0),
      control1: svg_path.Point(152.0, 4.0),
      control2: svg_path.Point(124.0, 112.0),
      end: svg_path.Point(82.0, 58.0),
    ),
  ])
  |> svg_path.subpath_assert_set_closed(closed: True)
}

fn upright_figure_eight() -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.Line(
      start: svg_path.Point(82.0, 58.0),
      end: svg_path.Point(20.0, 4.0),
    ),
    svg_path.Line(
      start: svg_path.Point(20.0, 4.0),
      end: svg_path.Point(144.0, 4.0),
    ),
    svg_path.Line(
      start: svg_path.Point(144.0, 4.0),
      end: svg_path.Point(82.0, 58.0),
    ),
    svg_path.Line(
      start: svg_path.Point(82.0, 58.0),
      end: svg_path.Point(144.0, 112.0),
    ),
    svg_path.Line(
      start: svg_path.Point(144.0, 112.0),
      end: svg_path.Point(20.0, 112.0),
    ),
    svg_path.Line(
      start: svg_path.Point(20.0, 112.0),
      end: svg_path.Point(82.0, 58.0),
    ),
  ])
  |> svg_path.subpath_assert_set_closed(closed: True)
}

fn int_to_float(value: Int) -> Float {
  value |> int.to_float
}

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
