import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import svg_path
import svg_path/bezier
import svg_path/svg

const output_path = "test/generated/bezier_cubic_fit.svg"

const page_width = 900.0

const page_height = 720.0

const panel_width = 280.0

const panel_height = 220.0

const panel_gap = 20.0

const panel_pad = 22.0

pub fn cubic_fit_visual_examples_are_generated_test() {
  let _ = ensure_dir(output_path)
  let _ = write_file(output_path, render())
}

type FitCase {
  FitCase(
    title: String,
    original: option.Option(bezier.BezierData),
    start: bezier.Point,
    end: bezier.Point,
    start_tangent: bezier.Point,
    end_tangent: bezier.Point,
    samples: List(#(Float, bezier.Point)),
  )
}

type Box {
  Box(min: bezier.Point, max: bezier.Point)
}

type Placement {
  Placement(x: Float, y: Float, scale: Float, world: Box)
}

fn render() -> String {
  let things =
    [
      svg.Rectangle(
        svg_path.point(0.0, 0.0),
        page_width,
        page_height,
        "fill: #ffffff; stroke: none",
      ),
    ]
    |> list.append(render_cases(cases(), 0))

  svg.document(
    things,
    view_box: svg_path.BoundingBox(
      min: svg_path.point(0.0, 0.0),
      max: svg_path.point(page_width, page_height),
    ),
  )
}

fn render_cases(cases: List(FitCase), index: Int) -> svg.ThingsToDraw {
  case cases {
    [] -> []
    [fit_case, ..rest] ->
      render_case(fit_case, index)
      |> list.append(render_cases(rest, index + 1))
  }
}

fn render_case(fit_case: FitCase, index: Int) -> svg.ThingsToDraw {
  let FitCase(
    title:,
    original:,
    start:,
    end:,
    start_tangent:,
    end_tangent:,
    samples:,
  ) = fit_case
  let assert Ok(#(fit, error)) =
    bezier.fit_cubic_with_endpoint_tangents(
      start:,
      end:,
      start_tangent:,
      end_tangent:,
      samples:,
    )
  let box =
    drawing_box(start, end, start_tangent, end_tangent, samples, fit, original)
  let placement = panel_placement(index, box)
  let origin = panel_origin(index)
  let bezier.CubicFitError(root_sum_square:, root_mean_square: _, max: _) =
    error
  let taxicab_diameter = box_taxicab_diameter(box)

  [
    svg.Rectangle(
      svg_path.point(origin.x, origin.y),
      panel_width,
      panel_height,
      "fill: #f8fafc; stroke: #d1d5db; stroke-width: 1",
    ),
    svg.Text(
      title,
      "fill: #111827; font-family: system-ui, sans-serif; font-weight: 700",
      svg_path.point(origin.x, origin.y -. 8.0),
      13,
    ),
  ]
  |> list.append(original_overlay(original, placement))
  |> list.append([
    curve_thing(
      fit,
      placement,
      "fill: none; stroke: #1f2937; stroke-width: 3; stroke-linecap: round",
    ),
  ])
  |> list.append(tangent_arrow(start, start_tangent, placement))
  |> list.append(tangent_arrow(end, end_tangent, placement))
  |> list.append(endpoint_marks(start, end, placement))
  |> list.append(sample_marks(samples, placement))
  |> list.append([
    svg.Text(
      "root_sum_square = " <> float.to_string(root_sum_square),
      "fill: #374151; font-family: ui-monospace, SFMono-Regular, Menlo, monospace",
      svg_path.point(origin.x +. 8.0, origin.y +. panel_height -. 28.0),
      9,
    ),
    svg.Text(
      "taxicab_diameter = " <> float.to_string(taxicab_diameter),
      "fill: #374151; font-family: ui-monospace, SFMono-Regular, Menlo, monospace",
      svg_path.point(origin.x +. 8.0, origin.y +. panel_height -. 12.0),
      9,
    ),
  ])
}

fn original_overlay(
  original: option.Option(bezier.BezierData),
  placement: Placement,
) -> svg.ThingsToDraw {
  case original {
    None -> []
    Some(curve) -> [
      curve_thing(
        curve,
        placement,
        "fill: none; stroke: #ef4444; stroke-width: 1.2; stroke-opacity: 0.45; stroke-linecap: round",
      ),
    ]
  }
}

fn endpoint_marks(
  start: bezier.Point,
  end: bezier.Point,
  placement: Placement,
) -> svg.ThingsToDraw {
  [
    svg.Circle(
      place(start, placement),
      3.8,
      "fill: #2563eb; stroke: #ffffff; stroke-width: 1.2",
    ),
    svg.Circle(
      place(end, placement),
      3.8,
      "fill: #2563eb; stroke: #ffffff; stroke-width: 1.2",
    ),
  ]
}

fn sample_marks(
  samples: List(#(Float, bezier.Point)),
  placement: Placement,
) -> svg.ThingsToDraw {
  samples
  |> list.map(fn(sample) {
    let #(_, point) = sample
    svg.Circle(
      place(point, placement),
      3.2,
      "fill: #f59e0b; stroke: #ffffff; stroke-width: 1",
    )
  })
}

fn tangent_arrow(
  point: bezier.Point,
  tangent: bezier.Point,
  placement: Placement,
) -> svg.ThingsToDraw {
  let start = place(point, placement)
  let direction = unit(tangent)
  let end =
    place(
      bezier.Point(
        x: point.x
          +. direction.x
          *. box_taxicab_diameter(placement.world)
          /. 8.0,
        y: point.y
          +. direction.y
          *. box_taxicab_diameter(placement.world)
          /. 8.0,
      ),
      placement,
    )

  [
    svg.StyledPath(
      svg_path.Path([
        svg_path.assert_subpath([svg_path.Line(start:, end:)]),
      ]),
      "fill: none; stroke: #94a3b8; stroke-width: 1.2; stroke-linecap: round; stroke-opacity: 0.65",
    ),
    arrow_head(start, end, "fill: #94a3b8; stroke: none; opacity: 0.65"),
  ]
}

fn arrow_head(
  start: svg_path.Point,
  end: svg_path.Point,
  style: String,
) -> svg.ThingToDraw {
  let dx = end.x -. start.x
  let dy = end.y -. start.y
  let assert Ok(length) = float.square_root(dx *. dx +. dy *. dy)
  let direction_x = dx /. length
  let direction_y = dy /. length
  let normal_x = 0.0 -. direction_y
  let normal_y = direction_x
  let head = 8.0
  let width = 7.0
  let base =
    svg_path.point(end.x -. direction_x *. head, end.y -. direction_y *. head)
  let left =
    svg_path.point(
      base.x +. normal_x *. width /. 2.0,
      base.y +. normal_y *. width /. 2.0,
    )
  let right =
    svg_path.point(
      base.x -. normal_x *. width /. 2.0,
      base.y -. normal_y *. width /. 2.0,
    )

  svg.StyledPath(
    svg_path.Path([
      svg_path.assert_subpath([
        svg_path.Line(start: end, end: left),
        svg_path.Line(start: left, end: right),
        svg_path.Line(start: right, end: end),
      ])
      |> svg_path.assert_set_closed(closed: True),
    ]),
    style,
  )
}

fn curve_thing(
  curve: bezier.BezierData,
  placement: Placement,
  style: String,
) -> svg.ThingToDraw {
  svg.StyledPath(svg_path.Path([curve_subpath(curve, placement)]), style)
}

fn curve_subpath(
  curve: bezier.BezierData,
  placement: Placement,
) -> svg_path.Subpath {
  case curve {
    bezier.CubicBezierData(start:, control1:, control2:, end:) ->
      svg_path.assert_subpath([
        svg_path.CubicBezier(
          start: place(start, placement),
          control1: place(control1, placement),
          control2: place(control2, placement),
          end: place(end, placement),
        ),
      ])
    _ ->
      svg_path.assert_subpath([
        svg_path.Line(
          start: place(bezier.bezier_start(curve), placement),
          end: place(bezier.bezier_end(curve), placement),
        ),
      ])
  }
}

fn panel_placement(index: Int, world: Box) -> Placement {
  let origin = panel_origin(index)
  let Box(min:, max:) = world
  let width = max.x -. min.x
  let height = max.y -. min.y
  let scale =
    float.min(
      { panel_width -. panel_pad *. 2.0 } /. width,
      { panel_height -. panel_pad *. 2.0 -. 42.0 } /. height,
    )

  Placement(x: origin.x +. panel_pad, y: origin.y +. panel_pad, scale:, world:)
}

fn panel_origin(index: Int) -> svg_path.Point {
  let column = index % 3
  let row = index / 3

  svg_path.point(
    10.0 +. int.to_float(column) *. { panel_width +. panel_gap },
    32.0 +. int.to_float(row) *. { panel_height +. panel_gap },
  )
}

fn place(point: bezier.Point, placement: Placement) -> svg_path.Point {
  let Placement(x:, y:, scale:, world:) = placement
  let Box(min:, max:) = world

  svg_path.point(
    x +. { point.x -. min.x } *. scale,
    y +. { max.y -. point.y } *. scale,
  )
}

fn drawing_box(
  start: bezier.Point,
  end: bezier.Point,
  start_tangent: bezier.Point,
  end_tangent: bezier.Point,
  samples: List(#(Float, bezier.Point)),
  fit: bezier.BezierData,
  original: option.Option(bezier.BezierData),
) -> Box {
  let tangent_scale =
    box_taxicab_diameter(include_many(
      [start, end, ..sample_points(samples)],
      empty_box(start),
    ))
    /. 8.0
  let start_direction = unit(start_tangent)
  let end_direction = unit(end_tangent)
  let points =
    [start, end, ..sample_points(samples)]
    |> list.append(curve_points(fit))
    |> list.append([
      bezier.Point(
        x: start.x +. start_direction.x *. tangent_scale,
        y: start.y +. start_direction.y *. tangent_scale,
      ),
      bezier.Point(
        x: end.x +. end_direction.x *. tangent_scale,
        y: end.y +. end_direction.y *. tangent_scale,
      ),
    ])
    |> list.append(case original {
      None -> []
      Some(curve) -> curve_points(curve)
    })
  let box = include_many(points, empty_box(start))

  pad_box(box, by: box_taxicab_diameter(box) /. 20.0 +. 1.0)
}

fn curve_points(curve: bezier.BezierData) -> List(bezier.Point) {
  [
    0.0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.5, 0.55, 0.6, 0.65,
    0.7, 0.75, 0.8, 0.85, 0.9, 0.95, 1.0,
  ]
  |> list.map(fn(t) { bezier.bezier_point(curve, at: t) })
}

fn sample_points(samples: List(#(Float, bezier.Point))) -> List(bezier.Point) {
  samples
  |> list.map(fn(sample) {
    let #(_, point) = sample
    point
  })
}

fn include_many(points: List(bezier.Point), box: Box) -> Box {
  points
  |> list.fold(box, fn(box, point) { include_point(box, point) })
}

fn empty_box(point: bezier.Point) -> Box {
  Box(min: point, max: point)
}

fn include_point(box: Box, point: bezier.Point) -> Box {
  let Box(min:, max:) = box
  Box(
    min: bezier.Point(
      x: float.min(min.x, point.x),
      y: float.min(min.y, point.y),
    ),
    max: bezier.Point(
      x: float.max(max.x, point.x),
      y: float.max(max.y, point.y),
    ),
  )
}

fn pad_box(box: Box, by amount: Float) -> Box {
  let Box(min:, max:) = box
  Box(
    min: bezier.Point(x: min.x -. amount, y: min.y -. amount),
    max: bezier.Point(x: max.x +. amount, y: max.y +. amount),
  )
}

fn box_taxicab_diameter(box: Box) -> Float {
  let Box(min:, max:) = box
  max.x -. min.x +. max.y -. min.y
}

fn unit(vector: bezier.Point) -> bezier.Point {
  let assert Ok(length) =
    float.square_root(vector.x *. vector.x +. vector.y *. vector.y)
  bezier.Point(x: vector.x /. length, y: vector.y /. length)
}

fn exact_case(
  title: String,
  curve: bezier.BezierData,
  ts: List(Float),
) -> FitCase {
  FitCase(
    title:,
    original: Some(curve),
    start: bezier.bezier_start(curve),
    end: bezier.bezier_end(curve),
    start_tangent: bezier.bezier_derivative(curve, at: 0.0),
    end_tangent: bezier.bezier_derivative(curve, at: 1.0),
    samples: sample_curve(curve, ts),
  )
}

fn noisy_case(
  title: String,
  curve: bezier.BezierData,
  ts_and_noise: List(#(Float, bezier.Point)),
) -> FitCase {
  FitCase(
    title:,
    original: None,
    start: bezier.bezier_start(curve),
    end: bezier.bezier_end(curve),
    start_tangent: bezier.bezier_derivative(curve, at: 0.0),
    end_tangent: bezier.bezier_derivative(curve, at: 1.0),
    samples: ts_and_noise |> list.map(noisy_sample(curve, _)),
  )
}

fn noisy_sample(
  curve: bezier.BezierData,
  sample: #(Float, bezier.Point),
) -> #(Float, bezier.Point) {
  let #(t, noise) = sample
  let point = bezier.bezier_point(curve, at: t)
  #(t, bezier.Point(x: point.x +. noise.x, y: point.y +. noise.y))
}

fn sample_curve(
  curve: bezier.BezierData,
  ts: List(Float),
) -> List(#(Float, bezier.Point)) {
  ts
  |> list.map(fn(t) { #(t, bezier.bezier_point(curve, at: t)) })
}

fn cases() -> List(FitCase) {
  let c1 =
    bezier.CubicBezierData(
      start: bezier.Point(0.0, 0.0),
      control1: bezier.Point(35.0, 65.0),
      control2: bezier.Point(90.0, -35.0),
      end: bezier.Point(130.0, 25.0),
    )
  let c2 =
    bezier.CubicBezierData(
      start: bezier.Point(10.0, 80.0),
      control1: bezier.Point(45.0, 120.0),
      control2: bezier.Point(70.0, -40.0),
      end: bezier.Point(120.0, 30.0),
    )
  let c3 =
    bezier.CubicBezierData(
      start: bezier.Point(-20.0, 10.0),
      control1: bezier.Point(20.0, 90.0),
      control2: bezier.Point(95.0, 90.0),
      end: bezier.Point(150.0, 5.0),
    )
  let c4 =
    bezier.CubicBezierData(
      start: bezier.Point(0.0, 40.0),
      control1: bezier.Point(40.0, -30.0),
      control2: bezier.Point(90.0, 115.0),
      end: bezier.Point(135.0, 30.0),
    )
  let c5 =
    bezier.CubicBezierData(
      start: bezier.Point(0.0, 0.0),
      control1: bezier.Point(20.0, 105.0),
      control2: bezier.Point(115.0, 105.0),
      end: bezier.Point(135.0, 0.0),
    )

  [
    exact_case("exact 2 samples", c1, [0.3, 0.72]),
    exact_case("exact 3 samples", c2, [0.2, 0.52, 0.83]),
    exact_case("exact 4 samples", c3, [0.18, 0.38, 0.66, 0.88]),
    exact_case("exact 3 samples", c4, [0.25, 0.5, 0.75]),
    exact_case("exact 4 samples", c5, [0.15, 0.35, 0.65, 0.9]),
    noisy_case("noisy 2 samples", c1, [
      #(0.28, bezier.Point(0.0, 9.0)),
      #(0.74, bezier.Point(-7.0, -5.0)),
    ]),
    noisy_case("noisy 3 samples", c2, [
      #(0.2, bezier.Point(6.0, -8.0)),
      #(0.5, bezier.Point(-10.0, 5.0)),
      #(0.82, bezier.Point(4.0, 7.0)),
    ]),
    noisy_case("noisy 4 samples", c3, [
      #(0.16, bezier.Point(-4.0, 7.0)),
      #(0.36, bezier.Point(9.0, -6.0)),
      #(0.64, bezier.Point(-8.0, -5.0)),
      #(0.86, bezier.Point(5.0, 8.0)),
    ]),
    noisy_case("noisy 4 samples", c5, [
      #(0.12, bezier.Point(7.0, -4.0)),
      #(0.33, bezier.Point(-6.0, 10.0)),
      #(0.62, bezier.Point(8.0, 7.0)),
      #(0.89, bezier.Point(-5.0, -8.0)),
    ]),
  ]
}

@external(erlang, "filelib", "ensure_dir")
fn ensure_dir(path: String) -> Dynamic

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
