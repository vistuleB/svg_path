import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/result
import svg_path
import svg_path/convex_hull
import svg_path/offset
import svg_path/svg
import svg_path/transform

const preview_path = "examples/debug/convex_hull_figure_eight_regressions.svg"

pub fn figure_eight() -> svg_path.Subpath {
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

pub fn figure_eight_band() -> Result(svg_path.Path, offset.Error) {
  offset.subpath_band_with(
    figure_eight(),
    distance_a: 18.0,
    distance_b: 34.0,
    options: offset.Options(..offset.default_options(), join: offset.Round),
  )
}

pub fn combined_path() -> Result(svg_path.Path, offset.Error) {
  use band <- result.try(figure_eight_band())
  Ok(svg_path.Path([figure_eight(), ..svg_path.path_subpaths(band)]))
}

pub fn main() {
  let contents = figure_eight_hull_strip()
  let _ = ensure_dir(preview_path)
  let _ = write_file(preview_path, contents)
  Nil
}

pub fn figure_eight_hull_strip() -> String {
  let source = figure_eight()
  let assert Ok(band) = figure_eight_band()
  let assert Ok(combined) = combined_path()
  let assert Ok(source_hull) = convex_hull.subpath_hull(source)
  let assert Ok(band_hull) = convex_hull.path_hull(band)
  let assert Ok(combined_hull) = convex_hull.path_hull(combined)

  let panels = [
    panel(
      0.0,
      "1. figure-eight hull",
      svg_path.subpath_as_path(source),
      source_hull,
      "fill: none; stroke: #be123c; stroke-width: 4; stroke-dasharray: 10 7",
    ),
    panel(
      360.0,
      "2. asymmetric band hull",
      band,
      band_hull,
      "fill: #bbf7d0; fill-opacity: 0.75; stroke: #166534; stroke-width: 3",
    ),
    panel(
      720.0,
      "3. combined hull",
      combined,
      combined_hull,
      "fill: #fecdd3; fill-opacity: 0.55; stroke: #9f1239; stroke-width: 3",
    ),
  ]
  let contents =
    svg.document(
      things: [
        svg.Rectangle(svg_path.Point(0.0, 0.0), 1080.0, 260.0, "fill: #ffffff"),
        ..list.flatten(panels)
      ],
      view_box: svg_path.BoundingBox(
        min: svg_path.Point(0.0, 0.0),
        max: svg_path.Point(1080.0, 260.0),
      ),
    )
  contents
}

fn panel(
  x: Float,
  caption: String,
  subject: svg_path.Path,
  hull: svg_path.Subpath,
  subject_style: String,
) -> svg.ThingsToDraw {
  let subject = place_path(subject, x: x +. 180.0, y: 112.0)
  let hull = place_path(svg_path.subpath_as_path(hull), x: x +. 180.0, y: 112.0)
  [
    svg.StyledPath(
      hull,
      "fill: #bfdbfe; fill-opacity: 0.35; stroke: #1d4ed8; stroke-width: 5",
    ),
    svg.StyledPath(subject, subject_style),
    svg.Text(
      caption,
      "fill: #172554; font-family: sans-serif; text-anchor: middle",
      svg_path.Point(x +. 180.0, 244.0),
      16,
    ),
  ]
}

fn place_path(path: svg_path.Path, x x: Float, y y: Float) -> svg_path.Path {
  let assert Ok(scaled) = transform.scale_path(path, factor: 0.48)
  let assert Ok(placed) = transform.translate_path(scaled, x:, y:)
  placed
}

@external(erlang, "filelib", "ensure_dir")
fn ensure_dir(path: String) -> Dynamic

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
