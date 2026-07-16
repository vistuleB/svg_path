import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/list
import gleam/string
import gleeunit
import svg_path
import svg_path/csg
import svg_path/svg
import svg_path/transform

const output_dir = "test/generated/csg_visual"

const panel_width = 150.0

const panel_height = 125.0

const panel_gap = 18.0

const panel_origin_y = 34.0

const drawing_origin_x = 15.0

const drawing_origin_y = 16.0

pub fn main() -> Nil {
  gleeunit.main()
}

type Example {
  Example(
    slug: String,
    title: String,
    fill_rule: svg_path.FillRule,
    a: svg_path.Path,
    b: svg_path.Path,
  )
}

pub fn csg_visual_examples_are_generated_test() {
  let cases = examples()
  let _ = ensure_dir(output_dir <> "/README.md")

  let entries =
    cases
    |> list.map(fn(example) {
      let svg_filename = example.slug <> ".svg"
      let svg_path = output_dir <> "/" <> svg_filename
      let _ = write_file(svg_path, render_example(example))
      "- [" <> example.title <> "](" <> svg_filename <> ")"
    })

  let _ = write_file(output_dir <> "/README.md", markdown_index(entries))

  assert cases != []
}

fn examples() -> List(Example) {
  [
    Example(
      slug: "overlapping-rectangles",
      title: "Overlapping rectangles",
      fill_rule: svg_path.Nonzero,
      a: rectangle(0.0, 10.0, 78.0, 86.0),
      b: rectangle(42.0, 10.0, 120.0, 86.0),
    ),
    Example(
      slug: "corner-cutout",
      title: "Corner overlap",
      fill_rule: svg_path.Nonzero,
      a: rectangle(0.0, 0.0, 88.0, 88.0),
      b: rectangle(58.0, 58.0, 122.0, 122.0),
    ),
    Example(
      slug: "contained-rectangle",
      title: "Contained rectangle",
      fill_rule: svg_path.Nonzero,
      a: rectangle(0.0, 0.0, 122.0, 96.0),
      b: rectangle(34.0, 24.0, 88.0, 72.0),
    ),
    Example(
      slug: "evenodd-contained-rectangle",
      title: "Contained rectangle with EvenOdd",
      fill_rule: svg_path.EvenOdd,
      a: rectangle(0.0, 0.0, 122.0, 96.0),
      b: rectangle(34.0, 24.0, 88.0, 72.0),
    ),
    Example(
      slug: "disjoint-rectangles",
      title: "Disjoint rectangles",
      fill_rule: svg_path.Nonzero,
      a: rectangle(0.0, 24.0, 48.0, 86.0),
      b: rectangle(74.0, 24.0, 122.0, 86.0),
    ),
    Example(
      slug: "diamond-and-bar",
      title: "Diamond and bar",
      fill_rule: svg_path.Nonzero,
      a: polygon([
        svg_path.point(60.0, 0.0),
        svg_path.point(122.0, 60.0),
        svg_path.point(60.0, 122.0),
        svg_path.point(0.0, 60.0),
      ]),
      b: rectangle(12.0, 42.0, 110.0, 80.0),
    ),
    Example(
      slug: "circle-and-rectangle",
      title: "Circle and rectangle",
      fill_rule: svg_path.Nonzero,
      a: circle(svg_path.point(58.0, 61.0), 52.0),
      b: rectangle(44.0, 16.0, 122.0, 106.0),
    ),
    Example(
      slug: "identical-rectangles",
      title: "Identical rectangles",
      fill_rule: svg_path.Nonzero,
      a: rectangle(18.0, 18.0, 104.0, 92.0),
      b: rectangle(18.0, 18.0, 104.0, 92.0),
    ),
    Example(
      slug: "edge-tangent-rectangles",
      title: "Edge tangent rectangles",
      fill_rule: svg_path.Nonzero,
      a: rectangle(0.0, 22.0, 60.0, 92.0),
      b: rectangle(60.0, 22.0, 120.0, 92.0),
    ),
    Example(
      slug: "point-tangent-rectangles",
      title: "Point tangent rectangles",
      fill_rule: svg_path.Nonzero,
      a: rectangle(0.0, 0.0, 60.0, 60.0),
      b: rectangle(60.0, 60.0, 120.0, 120.0),
    ),
    Example(
      slug: "nested-input-nonzero",
      title: "Nested input with Nonzero",
      fill_rule: svg_path.Nonzero,
      a: nested_rectangles(),
      b: rectangle(46.0, 34.0, 76.0, 64.0),
    ),
    Example(
      slug: "nested-input-evenodd",
      title: "Nested input with EvenOdd",
      fill_rule: svg_path.EvenOdd,
      a: nested_rectangles(),
      b: rectangle(46.0, 34.0, 76.0, 64.0),
    ),
    Example(
      slug: "circle-tangent-rectangle",
      title: "Circle tangent rectangle",
      fill_rule: svg_path.Nonzero,
      a: circle(svg_path.point(50.0, 60.0), 40.0),
      b: rectangle(90.0, 20.0, 124.0, 100.0),
    ),
    Example(
      slug: "self-intersecting-bowtie",
      title: "Self-intersecting bowtie",
      fill_rule: svg_path.Nonzero,
      a: polygon([
        svg_path.point(8.0, 8.0),
        svg_path.point(114.0, 112.0),
        svg_path.point(114.0, 8.0),
        svg_path.point(8.0, 112.0),
      ]),
      b: rectangle(36.0, 28.0, 86.0, 92.0),
    ),
  ]
}

fn render_example(example: Example) -> String {
  let Example(title:, fill_rule:, a:, b:, ..) = example
  let assert Ok(union) = csg.union(a, b, using: fill_rule)
  let assert Ok(intersection) = csg.intersection(a, b, using: fill_rule)
  let assert Ok(difference) = csg.difference(a, minus: b, using: fill_rule)

  svg.document(
    [
      svg.Rectangle(
        svg_path.point(0.0, 0.0),
        document_width(),
        document_height(),
        "fill: #ffffff; stroke: none",
      ),
      svg.Text(
        title <> " (" <> fill_rule_name(fill_rule) <> ")",
        "fill: #111827; font-family: system-ui, sans-serif; font-weight: 700",
        svg_path.point(0.0, 18.0),
        14,
      ),
    ]
      |> list.append(input_panel(0, "Inputs", a, b))
      |> list.append(result_panel(1, "union(A, B)", union))
      |> list.append(result_panel(2, "intersection(A, B)", intersection))
      |> list.append(result_panel(3, "difference(A, B)", difference)),
    view_box: svg_path.BoundingBox(
      min: svg_path.point(0.0, 0.0),
      max: svg_path.point(document_width(), document_height()),
    ),
  )
}

fn input_panel(
  index: Int,
  label: String,
  a: svg_path.Path,
  b: svg_path.Path,
) -> svg.ThingsToDraw {
  let x = panel_x(index)
  [
    panel_background(x),
    panel_label(x, label),
    svg.StyledPath(
      place(a, x),
      "fill: rgba(31, 41, 55, 0.08); stroke: #1f2937; stroke-width: 4; stroke-linejoin: round",
    ),
    svg.StyledPath(
      place(b, x),
      "fill: rgba(245, 158, 11, 0.16); stroke: #f59e0b; stroke-width: 4; stroke-dasharray: 8 6; stroke-linejoin: round",
    ),
    svg.Text(
      "A",
      "fill: #1f2937; font-family: system-ui, sans-serif; font-weight: 700",
      svg_path.point(x +. 8.0, panel_origin_y +. 24.0),
      13,
    ),
    svg.Text(
      "B",
      "fill: #d97706; font-family: system-ui, sans-serif; font-weight: 700",
      svg_path.point(x +. panel_width -. 22.0, panel_origin_y +. 24.0),
      13,
    ),
  ]
}

fn result_panel(
  index: Int,
  label: String,
  result: svg_path.Path,
) -> svg.ThingsToDraw {
  let x = panel_x(index)
  [
    panel_background(x),
    panel_label(x, label),
    svg.StyledPath(
      place(result, x),
      "fill: #8ecae6; stroke: #1f2937; stroke-width: 4; stroke-linejoin: round",
    ),
  ]
}

fn panel_background(x: Float) -> svg.ThingToDraw {
  svg.Rectangle(
    svg_path.point(x, panel_origin_y),
    panel_width,
    panel_height,
    "fill: #f8fafc; stroke: #d1d5db; stroke-width: 1",
  )
}

fn panel_label(x: Float, label: String) -> svg.ThingToDraw {
  svg.Text(
    label,
    "fill: #111827; font-family: system-ui, sans-serif; font-weight: 700",
    svg_path.point(x, panel_origin_y -. 7.0),
    10,
  )
}

fn place(path: svg_path.Path, panel_x: Float) -> svg_path.Path {
  let assert Ok(translated) =
    transform.translate_path(
      path,
      x: panel_x +. drawing_origin_x,
      y: panel_origin_y +. drawing_origin_y,
    )
  translated
}

fn rectangle(
  min_x: Float,
  min_y: Float,
  max_x: Float,
  max_y: Float,
) -> svg_path.Path {
  polygon([
    svg_path.point(min_x, min_y),
    svg_path.point(max_x, min_y),
    svg_path.point(max_x, max_y),
    svg_path.point(min_x, max_y),
  ])
}

fn polygon(points: List(svg_path.Point)) -> svg_path.Path {
  svg_path.from_subpath(svg_path.assert_polygon(points))
}

fn nested_rectangles() -> svg_path.Path {
  svg_path.Path([
    svg_path.assert_polygon([
      svg_path.point(8.0, 8.0),
      svg_path.point(114.0, 8.0),
      svg_path.point(114.0, 90.0),
      svg_path.point(8.0, 90.0),
    ]),
    svg_path.assert_polygon([
      svg_path.point(34.0, 28.0),
      svg_path.point(88.0, 28.0),
      svg_path.point(88.0, 70.0),
      svg_path.point(34.0, 70.0),
    ]),
  ])
}

fn circle(center: svg_path.Point, radius: Float) -> svg_path.Path {
  let left = svg_path.point(center.x -. radius, center.y)
  let right = svg_path.point(center.x +. radius, center.y)
  svg_path.from_subpath(
    svg_path.assert_subpath([
      svg_path.Arc(
        start: right,
        radius: svg_path.point(radius, radius),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: left,
      ),
      svg_path.Arc(
        start: left,
        radius: svg_path.point(radius, radius),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: right,
      ),
    ])
    |> svg_path.assert_set_closed(closed: True),
  )
}

fn markdown_index(entries: List(String)) -> String {
  "# CSG Visual Examples\n\n"
  <> "Generated by `test/svg_path_csg_visual_test.gleam`.\n\n"
  <> "Each SVG shows the inputs and the three path CSG operations for one example.\n\n"
  <> string.join(entries, "\n")
  <> "\n"
}

fn fill_rule_name(fill_rule: svg_path.FillRule) -> String {
  case fill_rule {
    svg_path.Nonzero -> "Nonzero"
    svg_path.EvenOdd -> "EvenOdd"
  }
}

fn panel_x(index: Int) -> Float {
  int.to_float(index) *. { panel_width +. panel_gap }
}

fn document_width() -> Float {
  panel_width *. 4.0 +. panel_gap *. 3.0
}

fn document_height() -> Float {
  panel_origin_y +. panel_height +. 8.0
}

@external(erlang, "filelib", "ensure_dir")
fn ensure_dir(path: String) -> Dynamic

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
