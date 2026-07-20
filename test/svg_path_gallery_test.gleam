import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/string
import gleeunit
import svg_path
import svg_path/area
import svg_path/csg
import svg_path/effects
import svg_path/offset
import svg_path/svg
import svg_path/transform
import vec/vec2f

const output_dir = "test/generated/gallery"

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
