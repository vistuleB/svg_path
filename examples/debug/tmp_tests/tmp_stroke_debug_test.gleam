import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/list
import svg_path
import svg_path/offset
import svg_path/svg
import svg_path/transform
import vec/vec2f

const output = "examples/debug/svg_path_stroke_gallery.svg"

const panel_w = 230.0

const panel_h = 150.0

const gap = 18.0

type Example {
  Example(
    label: String,
    source: svg_path.Subpath,
    width: Float,
    cap: offset.Cap,
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
          label: "open line / butt",
          source: open_line(),
          width: 24.0,
          cap: offset.Butt,
          join: offset.Miter(4.0),
        ),
      ),
      panel(
        row: 0,
        column: 1,
        example: Example(
          label: "open line / square",
          source: open_line(),
          width: 24.0,
          cap: offset.Square,
          join: offset.Miter(4.0),
        ),
      ),
      panel(
        row: 1,
        column: 0,
        example: Example(
          label: "open curve / round",
          source: open_curve(),
          width: 22.0,
          cap: offset.RoundCap,
          join: offset.Round,
        ),
      ),
      panel(
        row: 1,
        column: 1,
        example: Example(
          label: "closed figure-eight",
          source: figure_eight(),
          width: 26.0,
          cap: offset.Butt,
          join: offset.Round,
        ),
      ),
    ]),
    view_box: svg_path.BoundingBox(
      min: svg_path.point(0.0, 0.0),
      max: svg_path.point(panel_w *. 2.0 +. gap, panel_h *. 2.0 +. gap),
    ),
  )
}

fn panel(
  row row: Int,
  column column: Int,
  example example: Example,
) -> svg.ThingsToDraw {
  let x = int.to_float(column) *. { panel_w +. gap }
  let y = int.to_float(row) *. { panel_h +. gap }
  let Example(label:, source:, width:, cap:, join:) = example
  let matrix = transform.translate(x: x +. 35.0, y: y +. 82.0)
  let assert Ok(source) = transform.subpath(source, by: matrix)
  let options =
    offset.Options(..offset.default_options(), tolerance: 0.01, join:)
  let result_things = case
    offset.subpath_stroke_with(source, width:, cap:, options:)
  {
    Ok(result) -> [
      svg.StyledPath(
        result,
        "fill: #93c5fd; stroke: #1f2937; stroke-width: 2.2; stroke-linejoin: round",
      ),
      ..path_arrows(result, "#1f2937", 1.0)
    ]
    Error(_) -> [
      svg.Text(
        "Error",
        "fill: #b91c1c; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-weight: 700",
        svg_path.point(x +. 12.0, y +. 130.0),
        12,
      ),
    ]
  }

  list.append(
    [
      svg.Rectangle(
        svg_path.point(x, y),
        panel_w,
        panel_h,
        "fill: #ffffff; stroke: #d1d5db; stroke-width: 1.5",
      ),
      svg.Text(
        label,
        "fill: #111827; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-weight: 700",
        svg_path.point(x +. 12.0, y +. 24.0),
        13,
      ),
    ],
    list.append(result_things, [
      svg.StyledPath(
        svg_path.from_subpath(source),
        "fill: none; stroke: #ef4444; stroke-width: 1.4; stroke-dasharray: 4 4; stroke-linecap: round",
      ),
      ..subpath_arrows(source, "#ef4444", 0.9)
    ]),
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
      let distance = total_length *. 0.42
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
  let half_width = 4.0 *. arrow_scale
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

fn add(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.point(a.x +. b.x, a.y +. b.y)
}

fn scale(point: svg_path.Point, factor: Float) -> svg_path.Point {
  svg_path.point(point.x *. factor, point.y *. factor)
}

fn rotate_counterclockwise(point: svg_path.Point) -> svg_path.Point {
  svg_path.point(0.0 -. point.y, point.x)
}

fn open_line() -> svg_path.Subpath {
  svg_path.assert_polyline([
    svg_path.point(0.0, 0.0),
    svg_path.point(150.0, 0.0),
  ])
}

fn open_curve() -> svg_path.Subpath {
  svg_path.assert_subpath([
    svg_path.CubicBezier(
      start: svg_path.point(0.0, 28.0),
      control1: svg_path.point(38.0, -70.0),
      control2: svg_path.point(110.0, 86.0),
      end: svg_path.point(150.0, -4.0),
    ),
  ])
}

fn figure_eight() -> svg_path.Subpath {
  svg_path.assert_subpath([
    svg_path.CubicBezier(
      start: svg_path.point(76.0, 0.0),
      control1: svg_path.point(-2.0, -62.0),
      control2: svg_path.point(-2.0, 62.0),
      end: svg_path.point(76.0, 0.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.point(76.0, 0.0),
      control1: svg_path.point(154.0, -62.0),
      control2: svg_path.point(154.0, 62.0),
      end: svg_path.point(76.0, 0.0),
    ),
  ])
  |> svg_path.assert_set_closed(closed: True)
}

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
