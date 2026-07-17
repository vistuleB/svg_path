import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleeunit
import svg_path
import svg_path/csg
import svg_path/effects
import svg_path/svg
import svg_path/transform
import svg_path/trig

const output_dir = "test/generated/csg_visual"

const readme_nested_csg_nonzero_table = "csg_nested_csg_nonzero_table.svg"

const readme_nested_csg_evenodd_table = "csg_nested_csg_evenodd_table.svg"

const panel_width = 150.0

const panel_height = 125.0

const panel_gap = 18.0

const panel_origin_y = 34.0

const drawing_origin_x = 15.0

const drawing_origin_y = 16.0

const minimum_arrow_segment_length = 28.0

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
    |> list.append(orientation_entries())
    |> list.append(theory_entries())

  let _ = write_file(output_dir <> "/README.md", markdown_index(entries))

  assert cases != []
}

fn orientation_entries() -> List(String) {
  [
    #(
      "nested-orientation-nonzero",
      "Nested orientation matrix with Nonzero",
      svg_path.Nonzero,
    ),
    #(
      "nested-orientation-evenodd",
      "Nested orientation matrix with EvenOdd",
      svg_path.EvenOdd,
    ),
  ]
  |> list.map(fn(entry) {
    let #(slug, title, fill_rule) = entry
    let svg_filename = slug <> ".svg"
    let svg_path = output_dir <> "/" <> svg_filename
    let _ = write_file(svg_path, render_orientation_guide(title, fill_rule))
    "- [" <> title <> "](" <> svg_filename <> ")"
  })
}

fn theory_entries() -> List(String) {
  [
    #("theory-corner-overlap", "CSG corner overlap", render_theory_corner()),
    #(
      "theory-simple-orientation",
      "Simple contour orientation",
      render_theory_simple_orientation(),
    ),
    #(
      "theory-nested-fill-rules",
      "Nested contours and fill rules",
      render_theory_nested_fill_rules(),
    ),
    #(
      "theory-nested-csg-nonzero-table",
      "Nested CSG table with Nonzero",
      render_theory_nested_csg_table(svg_path.Nonzero),
    ),
    #(
      "theory-nested-csg-evenodd-table",
      "Nested CSG table with EvenOdd",
      render_theory_nested_csg_table(svg_path.EvenOdd),
    ),
    #(
      "theory-difference-asymmetry",
      "Difference is not symmetric",
      render_theory_difference_asymmetry(),
    ),
    #(
      "theory-output-orientation",
      "Canonical output orientation",
      render_theory_output_orientation(),
    ),
    #(
      "adjacent-offset-squares-union",
      "Adjacent offset squares union",
      render_adjacent_offset_squares_union(),
    ),
    #(
      "effects-rounded-rectangle-union",
      "Rounded corners on rectangle union",
      render_effects_rounded_rectangle_union(),
    ),
    #(
      "effects-rounded-ellipse-union",
      "Rounded corners on ellipse union",
      render_effects_rounded_ellipse_union(),
    ),
  ]
  |> list.map(fn(entry) {
    let #(slug, title, contents) = entry
    let svg_filename = slug <> ".svg"
    let svg_path = output_dir <> "/" <> svg_filename
    let _ = write_file(svg_path, contents)
    let _ = case slug {
      "theory-corner-overlap" -> {
        let _ = write_file("csg_theory_corner_overlap.svg", contents)
        Nil
      }
      "theory-simple-orientation" -> {
        let _ = write_file("csg_theory_simple_orientation.svg", contents)
        Nil
      }
      "theory-nested-fill-rules" -> {
        let _ = write_file("csg_theory_nested_fill_rules.svg", contents)
        Nil
      }
      "theory-nested-csg-nonzero-table" -> {
        let _ = write_file(readme_nested_csg_nonzero_table, contents)
        Nil
      }
      "theory-nested-csg-evenodd-table" -> {
        let _ = write_file(readme_nested_csg_evenodd_table, contents)
        Nil
      }
      "theory-difference-asymmetry" -> {
        let _ = write_file("csg_theory_difference_asymmetry.svg", contents)
        Nil
      }
      "theory-output-orientation" -> {
        let _ = write_file("csg_theory_output_orientation.svg", contents)
        Nil
      }
      _ -> Nil
    }
    "- [" <> title <> "](" <> svg_filename <> ")"
  })
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
    ..path_arrows(place(a, x), "#1f2937")
  ]
  |> list.append(path_arrows(place(b, x), "#f59e0b"))
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
    ..path_arrows(place(result, x), "#1f2937")
  ]
}

type OrientationRow {
  OrientationRow(label: String, a: svg_path.Path, b: svg_path.Path)
}

fn render_orientation_guide(
  title: String,
  fill_rule: svg_path.FillRule,
) -> String {
  let rows = orientation_rows()
  let width = guide_document_width()
  let height = guide_document_height(list.length(rows))

  svg.document(
    [
      svg.Rectangle(
        svg_path.point(0.0, 0.0),
        width,
        height,
        "fill: #ffffff; stroke: none",
      ),
      svg.Text(
        title,
        "fill: #111827; font-family: system-ui, sans-serif; font-weight: 700",
        svg_path.point(0.0, 18.0),
        14,
      ),
    ]
      |> list.append(guide_header())
      |> list.append(
        rows
        |> list.index_map(fn(row, index) {
          orientation_row(index, row, fill_rule)
        })
        |> list.flatten,
      ),
    view_box: svg_path.BoundingBox(
      min: svg_path.point(0.0, 0.0),
      max: svg_path.point(width, height),
    ),
  )
}

fn orientation_rows() -> List(OrientationRow) {
  [
    OrientationRow(
      label: "A contours same; B same",
      a: nested_rectangles_with_inner(same_direction: True),
      b: bar(same_direction: True),
    ),
    OrientationRow(
      label: "A contours same; B reversed",
      a: nested_rectangles_with_inner(same_direction: True),
      b: bar(same_direction: False),
    ),
    OrientationRow(
      label: "A inner reversed; B same",
      a: nested_rectangles_with_inner(same_direction: False),
      b: bar(same_direction: True),
    ),
    OrientationRow(
      label: "A inner reversed; B reversed",
      a: nested_rectangles_with_inner(same_direction: False),
      b: bar(same_direction: False),
    ),
  ]
}

fn orientation_row(
  index: Int,
  row: OrientationRow,
  fill_rule: svg_path.FillRule,
) -> svg.ThingsToDraw {
  let OrientationRow(label:, a:, b:) = row
  let assert Ok(union) = csg.union(a, b, using: fill_rule)
  let assert Ok(intersection) = csg.intersection(a, b, using: fill_rule)
  let assert Ok(difference) = csg.difference(a, minus: b, using: fill_rule)
  let y = guide_row_y(index)

  guide_input_panel(0, y, a, b)
  |> list.append(guide_result_panel(1, y, union, fill_rule))
  |> list.append(guide_result_panel(2, y, intersection, fill_rule))
  |> list.append(guide_result_panel(3, y, difference, fill_rule))
  |> list.append([
    svg.Text(
      label,
      "fill: #374151; font-family: system-ui, sans-serif",
      svg_path.point(0.0, y -. 6.0),
      9,
    ),
  ])
}

fn guide_header() -> svg.ThingsToDraw {
  ["Inputs", "union(A, B)", "intersection(A, B)", "difference(A, B)"]
  |> list.index_map(fn(label, index) {
    svg.Text(
      label,
      "fill: #111827; font-family: system-ui, sans-serif; font-weight: 700",
      svg_path.point(guide_panel_x(index), guide_header_y()),
      10,
    )
  })
}

fn guide_input_panel(
  index: Int,
  y: Float,
  a: svg_path.Path,
  b: svg_path.Path,
) -> svg.ThingsToDraw {
  let x = guide_panel_x(index)
  let placed_a = guide_place(a, x, y)
  let placed_b = guide_place(b, x, y)

  [
    guide_panel_background(x, y),
    svg.StyledPath(
      placed_a,
      "fill: rgba(31, 41, 55, 0.06); stroke: #1f2937; stroke-width: 3; stroke-linejoin: round",
    ),
    svg.StyledPath(
      placed_b,
      "fill: rgba(245, 158, 11, 0.14); stroke: #f59e0b; stroke-width: 3; stroke-dasharray: 6 5; stroke-linejoin: round",
    ),
    svg.Text(
      "A",
      "fill: #1f2937; font-family: system-ui, sans-serif; font-weight: 700",
      svg_path.point(x +. 8.0, y +. 25.0),
      11,
    ),
    svg.Text(
      "B",
      "fill: #d97706; font-family: system-ui, sans-serif; font-weight: 700",
      svg_path.point(x +. guide_panel_width -. 18.0, y +. 45.0),
      11,
    ),
    ..nested_input_arrows(placed_a, "#1f2937", arrow_scale: 1.0)
  ]
  |> list.append(bar_input_arrows(placed_b, "#f59e0b", arrow_scale: 1.0))
}

fn guide_result_panel(
  index: Int,
  y: Float,
  result: svg_path.Path,
  fill_rule: svg_path.FillRule,
) -> svg.ThingsToDraw {
  let x = guide_panel_x(index)
  let placed = guide_place(result, x, y)

  [
    guide_panel_background(x, y),
    svg.StyledPath(
      placed,
      "fill: #8ecae6; fill-rule: "
        <> svg_fill_rule(fill_rule)
        <> "; stroke: none",
    ),
  ]
  |> list.append(contour_overlays(placed, stroke_width: 3.0))
}

fn path_arrows(path: svg_path.Path, color: String) -> svg.ThingsToDraw {
  path_arrows_with_scale(path, color, 1.0)
}

fn path_arrows_with_scale(
  path: svg_path.Path,
  color: String,
  arrow_scale: Float,
) -> svg.ThingsToDraw {
  path
  |> svg_path.subpaths
  |> list.flat_map(subpath_arrows(_, color, arrow_scale))
}

fn nested_input_arrows(
  path: svg_path.Path,
  color: String,
  arrow_scale arrow_scale: Float,
) -> svg.ThingsToDraw {
  fixed_top_center_arrows(path, color, arrow_scale)
}

fn bar_input_arrows(
  path: svg_path.Path,
  color: String,
  arrow_scale arrow_scale: Float,
) -> svg.ThingsToDraw {
  fixed_top_center_arrows(path, color, arrow_scale)
}

fn fixed_top_center_arrows(
  path: svg_path.Path,
  color: String,
  arrow_scale: Float,
) -> svg.ThingsToDraw {
  path
  |> svg_path.subpaths
  |> list.flat_map(fixed_top_center_subpath_arrow(_, color, arrow_scale))
}

fn contour_overlays(
  path: svg_path.Path,
  stroke_width stroke_width: Float,
) -> svg.ThingsToDraw {
  path
  |> svg_path.subpaths
  |> list.index_map(fn(subpath, index) {
    let color = contour_color(index)
    let subpath_path = svg_path.from_subpath(subpath)
    [
      svg.StyledPath(
        subpath_path,
        "fill: none; stroke: "
          <> color
          <> "; stroke-width: "
          <> float.to_string(stroke_width)
          <> "; stroke-linejoin: round",
      ),
      ..path_arrows(subpath_path, color)
    ]
  })
  |> list.flatten
}

fn contour_color(index: Int) -> String {
  case index % 6 {
    0 -> "#1f2937"
    1 -> "#0f766e"
    2 -> "#b45309"
    3 -> "#6d28d9"
    4 -> "#be123c"
    _ -> "#0369a1"
  }
}

fn subpath_arrows(
  subpath: svg_path.Subpath,
  color: String,
  arrow_scale: Float,
) -> svg.ThingsToDraw {
  subpath_arrow(svg_path.segments(subpath), color, arrow_scale)
}

fn subpath_arrow(
  segments: List(svg_path.Segment),
  color: String,
  arrow_scale: Float,
) -> svg.ThingsToDraw {
  case segments {
    [] -> []
    [first, ..rest] -> {
      case segment_arrow(first, color, arrow_scale) {
        Ok(arrow) -> arrow
        Error(_) -> subpath_arrow(rest, color, arrow_scale)
      }
    }
  }
}

fn fixed_top_center_subpath_arrow(
  subpath: svg_path.Subpath,
  color: String,
  arrow_scale: Float,
) -> svg.ThingsToDraw {
  let assert Ok(segment) = top_horizontal_segment(subpath)
  let assert Ok(point) = svg_path.segment_point(segment, at: 0.5)
  let direction = segment_direction(segment)

  case normalize(direction) {
    Error(_) -> []
    Ok(unit) -> arrow_glyph(point, unit, color, arrow_scale)
  }
}

fn top_horizontal_segment(
  subpath: svg_path.Subpath,
) -> Result(svg_path.Segment, Nil) {
  subpath
  |> svg_path.segments
  |> list.filter(is_horizontal_line)
  |> top_segment(None)
}

fn top_segment(
  segments: List(svg_path.Segment),
  best: Option(svg_path.Segment),
) -> Result(svg_path.Segment, Nil) {
  case segments, best {
    [], Some(segment) -> Ok(segment)
    [], None -> Error(Nil)
    [segment, ..rest], None -> top_segment(rest, Some(segment))
    [segment, ..rest], Some(best_segment) -> {
      case segment_midpoint_y(segment) <. segment_midpoint_y(best_segment) {
        True -> top_segment(rest, Some(segment))
        False -> top_segment(rest, best)
      }
    }
  }
}

fn is_horizontal_line(segment: svg_path.Segment) -> Bool {
  case segment {
    svg_path.Line(start:, end:) ->
      float.absolute_value(start.y -. end.y) <=. 0.000001
    _ -> False
  }
}

fn segment_midpoint_y(segment: svg_path.Segment) -> Float {
  let start = svg_path.segment_start(segment)
  let end = svg_path.segment_end(segment)
  { start.y +. end.y } /. 2.0
}

fn segment_arrow(
  segment: svg_path.Segment,
  color: String,
  arrow_scale: Float,
) -> Result(svg.ThingsToDraw, Nil) {
  let assert Ok(length) = svg_path.segment_length(segment)
  case length <. minimum_arrow_segment_length {
    True -> Error(Nil)
    False -> segment_arrow_on_long_enough_segment(segment, color, arrow_scale)
  }
}

fn segment_arrow_on_long_enough_segment(
  segment: svg_path.Segment,
  color: String,
  arrow_scale: Float,
) -> Result(svg.ThingsToDraw, Nil) {
  segment_arrow_at(segment, color, arrow_scale, 0.42)
}

fn segment_arrow_at(
  segment: svg_path.Segment,
  color: String,
  arrow_scale: Float,
  t: Float,
) -> Result(svg.ThingsToDraw, Nil) {
  let assert Ok(point) = svg_path.segment_point(segment, at: t)
  let direction = segment_direction(segment)

  case normalize(direction) {
    Error(_) -> Error(Nil)
    Ok(unit) -> Ok(arrow_glyph(point, unit, color, arrow_scale))
  }
}

fn arrow_glyph(
  point: svg_path.Point,
  unit: svg_path.Point,
  color: String,
  arrow_scale: Float,
) -> svg.ThingsToDraw {
  let tail = add(point, scale(unit, -6.0 *. arrow_scale))
  let tip = add(point, scale(unit, 6.0 *. arrow_scale))
  let perp = svg_path.point(0.0 -. unit.y, unit.x)
  let half_width = 4.0 *. arrow_scale
  let equilateral_height = half_width *. 1.7320508075688772
  let head_center = point
  let head_tip = add(head_center, scale(unit, equilateral_height *. 2.0 /. 3.0))
  let head_base =
    add(head_center, scale(unit, 0.0 -. equilateral_height /. 3.0))
  let left = add(head_base, scale(perp, half_width))
  let right = add(head_base, scale(perp, 0.0 -. half_width))

  [
    svg.StyledPath(
      svg_path.from_subpath(
        svg_path.assert_subpath([
          svg_path.Line(start: tail, end: tip),
        ]),
      ),
      "fill: none; stroke: "
        <> color
        <> "; stroke-width: 2; stroke-linecap: round",
    ),
    svg.StyledPath(
      polygon([head_tip, left, right]),
      "fill: " <> color <> "; stroke: none",
    ),
  ]
}

fn segment_direction(segment: svg_path.Segment) -> svg_path.Point {
  let assert Ok(derivative) = svg_path.segment_derivative(segment, at: 0.42)

  case length_squared(derivative) >. 0.000000000001 {
    True -> derivative
    False -> {
      let start = svg_path.segment_start(segment)
      let end = svg_path.segment_end(segment)
      subtract(end, start)
    }
  }
}

fn normalize(point: svg_path.Point) -> Result(svg_path.Point, Nil) {
  let length_squared = length_squared(point)

  case length_squared <=. 0.000000000001 {
    True -> Error(Nil)
    False -> {
      let assert Ok(length) = float.square_root(length_squared)
      Ok(scale(point, 1.0 /. length))
    }
  }
}

fn add(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.point(a.x +. b.x, a.y +. b.y)
}

fn subtract(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.point(a.x -. b.x, a.y -. b.y)
}

fn scale(point: svg_path.Point, factor: Float) -> svg_path.Point {
  svg_path.point(point.x *. factor, point.y *. factor)
}

fn length_squared(point: svg_path.Point) -> Float {
  point.x *. point.x +. point.y *. point.y
}

const theory_panel_width = 170.0

const theory_panel_height = 125.0

const theory_panel_gap = 16.0

const theory_top = 48.0

const theory_row_gap = 24.0

fn render_theory_corner() -> String {
  let a = rectangle(28.0, 22.0, 102.0, 84.0)
  let b = rectangle(74.0, 50.0, 142.0, 98.0)
  let assert Ok(union) = csg.union(a, b, using: svg_path.Nonzero)
  let assert Ok(intersection) = csg.intersection(a, b, using: svg_path.Nonzero)
  let assert Ok(difference) =
    csg.difference(a, minus: b, using: svg_path.Nonzero)

  theory_document(
    "Corner/corner overlap",
    4,
    1,
    [
      theory_input_panel(0, 0, "Inputs", a, b),
      theory_result_panel(1, 0, "union(A, B)", union, svg_path.Nonzero),
      theory_result_panel(
        2,
        0,
        "intersection(A, B)",
        intersection,
        svg_path.Nonzero,
      ),
      theory_result_panel(
        3,
        0,
        "difference(A, B)",
        difference,
        svg_path.Nonzero,
      ),
    ]
      |> list.flatten,
  )
}

fn render_theory_simple_orientation() -> String {
  let a = rectangle(28.0, 22.0, 102.0, 84.0)
  let b = rectangle(74.0, 50.0, 142.0, 98.0)
  let reversed_b =
    svg_path.from_subpath(rectangle_subpath(
      74.0,
      50.0,
      142.0,
      98.0,
      same_direction: False,
    ))

  theory_document(
    "Simple contour orientation",
    4,
    2,
    list.append(
      simple_orientation_row(0, "A and B counterclockwise", a, b),
      simple_orientation_row(1, "B clockwise", a, reversed_b),
    ),
  )
}

fn simple_orientation_row(
  row: Int,
  label: String,
  a: svg_path.Path,
  b: svg_path.Path,
) -> svg.ThingsToDraw {
  let assert Ok(union) = csg.union(a, b, using: svg_path.Nonzero)
  let assert Ok(intersection) = csg.intersection(a, b, using: svg_path.Nonzero)
  let assert Ok(difference) =
    csg.difference(a, minus: b, using: svg_path.Nonzero)

  [
    theory_input_panel(0, row, label, a, b),
    theory_result_panel(1, row, "union(A, B)", union, svg_path.Nonzero),
    theory_result_panel(
      2,
      row,
      "intersection(A, B)",
      intersection,
      svg_path.Nonzero,
    ),
    theory_result_panel(
      3,
      row,
      "difference(A, B)",
      difference,
      svg_path.Nonzero,
    ),
  ]
  |> list.flatten
}

fn render_theory_nested_fill_rules() -> String {
  let same = nested_theory_path(inner_same_direction: True)
  let opposite = nested_theory_path(inner_same_direction: False)

  theory_document(
    "Nested contours and fill rules",
    3,
    2,
    [
      theory_input_only_panel(0, 0, "Same direction", same),
      theory_result_panel(1, 0, "A under Nonzero", same, svg_path.Nonzero),
      theory_result_panel(2, 0, "A under EvenOdd", same, svg_path.EvenOdd),
      theory_input_only_panel(0, 1, "Inner reversed", opposite),
      theory_result_panel(1, 1, "A under Nonzero", opposite, svg_path.Nonzero),
      theory_result_panel(2, 1, "A under EvenOdd", opposite, svg_path.EvenOdd),
    ]
      |> list.flatten,
  )
}

type NestedCsgRow {
  NestedCsgRow(label: String, a: svg_path.Path, b: svg_path.Path)
}

fn render_theory_nested_csg_table(fill_rule: svg_path.FillRule) -> String {
  let rows = [
    NestedCsgRow(
      label: "same-direction A; counterclockwise B",
      a: nested_theory_path(inner_same_direction: True),
      b: theory_bar(same_direction: True),
    ),
    NestedCsgRow(
      label: "same-direction A; clockwise B",
      a: nested_theory_path(inner_same_direction: True),
      b: theory_bar(same_direction: False),
    ),
    NestedCsgRow(
      label: "opposite-direction A; counterclockwise B",
      a: nested_theory_path(inner_same_direction: False),
      b: theory_bar(same_direction: True),
    ),
    NestedCsgRow(
      label: "opposite-direction A; clockwise B",
      a: nested_theory_path(inner_same_direction: False),
      b: theory_bar(same_direction: False),
    ),
  ]

  combo_document(
    "Nested CSG with " <> fill_rule_name(fill_rule),
    fill_rule,
    rows
      |> list.index_map(fn(row, index) { nested_csg_row(index, row, fill_rule) })
      |> list.flatten,
  )
}

fn nested_csg_row(
  row_index: Int,
  row: NestedCsgRow,
  fill_rule: svg_path.FillRule,
) -> svg.ThingsToDraw {
  let NestedCsgRow(label:, a:, b:) = row
  let assert Ok(union) = csg.union(a, b, using: fill_rule)
  let assert Ok(intersection) = csg.intersection(a, b, using: fill_rule)
  let assert Ok(difference) = csg.difference(a, minus: b, using: fill_rule)

  [
    combo_input_panel(0, row_index, label, a, b, fill_rule),
    combo_result_panel(1, row_index, "union(A, B)", union, fill_rule),
    combo_result_panel(
      2,
      row_index,
      "intersection(A, B)",
      intersection,
      fill_rule,
    ),
    combo_result_panel(3, row_index, "difference(A, B)", difference, fill_rule),
  ]
  |> list.flatten
}

fn combo_document(
  title: String,
  fill_rule: svg_path.FillRule,
  things: svg.ThingsToDraw,
) -> String {
  svg.document(
    [
      svg.Rectangle(
        svg_path.point(0.0, 0.0),
        combo_width(),
        combo_height(),
        "fill: #ffffff; stroke: none",
      ),
      svg.Text(
        title,
        "fill: #111827; font-family: system-ui, sans-serif; font-weight: 700",
        svg_path.point(0.0, 20.0),
        16,
      ),
      ..combo_headers(fill_rule)
    ]
      |> list.append(things),
    view_box: svg_path.BoundingBox(
      min: svg_path.point(0.0, 0.0),
      max: svg_path.point(combo_width(), combo_height()),
    ),
  )
}

fn combo_headers(fill_rule: svg_path.FillRule) -> svg.ThingsToDraw {
  [
    "Inputs as " <> fill_rule_name(fill_rule),
    "union(A, B)",
    "intersection(A, B)",
    "difference(A, B)",
  ]
  |> list.index_map(fn(label, index) {
    svg.Text(
      label,
      "fill: #111827; font-family: system-ui, sans-serif; font-weight: 700",
      svg_path.point(combo_x(index), 42.0),
      9,
    )
  })
}

fn combo_input_panel(
  column: Int,
  row: Int,
  label: String,
  a: svg_path.Path,
  b: svg_path.Path,
  fill_rule: svg_path.FillRule,
) -> svg.ThingsToDraw {
  let x = combo_x(column)
  let y = combo_y(row)
  let placed_a = combo_place(a, x, y)
  let placed_b = combo_place(b, x, y)

  [
    combo_panel_background(x, y),
    combo_row_label(x, y, label),
    svg.StyledPath(
      placed_a,
      "fill: rgba(142, 202, 230, 0.42); fill-rule: "
        <> svg_fill_rule(fill_rule)
        <> "; stroke: none",
    ),
    svg.StyledPath(
      placed_b,
      "fill: rgba(255, 183, 3, 0.26); fill-rule: "
        <> svg_fill_rule(fill_rule)
        <> "; stroke: none",
    ),
    svg.StyledPath(
      placed_a,
      "fill: none; stroke: #1f2937; stroke-width: 4; stroke-linejoin: round",
    ),
    svg.StyledPath(
      placed_b,
      "fill: none; stroke: #f59e0b; stroke-width: 3; stroke-dasharray: 6 5; stroke-linejoin: round",
    ),
    svg.Text(
      "A",
      "fill: #1f2937; font-family: system-ui, sans-serif; font-weight: 700",
      svg_path.point(x +. 34.0, y +. 43.0),
      13,
    ),
    svg.Text(
      "B",
      "fill: #d97706; font-family: system-ui, sans-serif; font-weight: 700",
      svg_path.point(x +. 164.0, y +. 55.0),
      13,
    ),
    ..nested_input_arrows(placed_a, "#1f2937", arrow_scale: 1.25)
  ]
  |> list.append(bar_input_arrows(placed_b, "#f59e0b", arrow_scale: 1.3))
}

fn combo_result_panel(
  column: Int,
  row: Int,
  label: String,
  path: svg_path.Path,
  fill_rule: svg_path.FillRule,
) -> svg.ThingsToDraw {
  let x = combo_x(column)
  let y = combo_y(row)
  let placed = combo_place(path, x, y)

  [
    combo_panel_background(x, y),
    combo_row_label(x, y, label),
    svg.StyledPath(
      placed,
      "fill: #8ecae6; fill-rule: "
        <> svg_fill_rule(fill_rule)
        <> "; stroke: none",
    ),
  ]
  |> list.append(contour_overlays(placed, stroke_width: 3.0))
}

fn combo_panel_background(x: Float, y: Float) -> svg.ThingToDraw {
  svg.Rectangle(
    svg_path.point(x, y),
    combo_panel_width,
    combo_panel_height,
    "fill: #f8fafc; stroke: #d1d5db; stroke-width: 1",
  )
}

fn combo_row_label(x: Float, y: Float, label: String) -> svg.ThingToDraw {
  svg.Text(
    label,
    "fill: #374151; font-family: system-ui, sans-serif",
    svg_path.point(x, y -. 5.0),
    8,
  )
}

fn theory_bar(same_direction same_direction: Bool) -> svg_path.Path {
  svg_path.from_subpath(rounded_rectangle_subpath(
    10.0,
    54.0,
    180.0,
    76.0,
    radius: 5.0,
    same_direction:,
  ))
}

fn render_theory_difference_asymmetry() -> String {
  let a = rectangle(28.0, 22.0, 102.0, 84.0)
  let b = rectangle(74.0, 50.0, 142.0, 98.0)
  let assert Ok(a_minus_b) =
    csg.difference(a, minus: b, using: svg_path.Nonzero)
  let assert Ok(b_minus_a) =
    csg.difference(b, minus: a, using: svg_path.Nonzero)

  theory_document(
    "Difference is not symmetric",
    2,
    1,
    [
      theory_result_panel(0, 0, "difference(A, B)", a_minus_b, svg_path.Nonzero),
      theory_result_panel(1, 0, "difference(B, A)", b_minus_a, svg_path.Nonzero),
    ]
      |> list.flatten,
  )
}

fn render_theory_output_orientation() -> String {
  let ring = nested_theory_path(inner_same_direction: False)

  theory_document(
    "Canonical output orientation",
    2,
    1,
    [
      theory_result_panel(0, 0, "Filled result", ring, svg_path.Nonzero),
      theory_result_panel(1, 0, "Output orientation", ring, svg_path.Nonzero),
    ]
      |> list.flatten,
  )
}

fn render_adjacent_offset_squares_union() -> String {
  let a = rectangle(16.0, 20.0, 76.0, 80.0)
  let b = rectangle(76.0, 50.0, 136.0, 110.0)
  let assert Ok(union) = csg.union(a, b, using: svg_path.Nonzero)

  theory_document(
    "Adjacent offset squares union",
    2,
    1,
    [
      theory_input_panel(0, 0, "Inputs", a, b),
      theory_result_panel(1, 0, "union(A, B)", union, svg_path.Nonzero),
    ]
      |> list.flatten,
  )
}

fn render_effects_rounded_rectangle_union() -> String {
  let rectangles = effect_rectangles()
  let input = svg_path.combine_paths(rectangles)
  let assert Ok(union) = union_paths(rectangles)
  let round_options =
    effects.RoundCornerOptions(
      ..effects.default_round_corner_options(),
      failure: effects.AdaptRadius,
    )
  let assert Ok(rounded) =
    effects.round_corners_with(union, radius: 6.0, options: round_options)

  theory_document(
    "Rounded corners on a rectangle union",
    3,
    1,
    [
      effects_input_panel(0, 0, "7 overlapping rectangles", input),
      effects_result_panel(
        1,
        0,
        "raw union(rectangles)",
        union,
        svg_path.Nonzero,
      ),
      effects_result_panel(
        2,
        0,
        "round_corners(..., 6)",
        rounded,
        svg_path.Nonzero,
      ),
    ]
      |> list.flatten,
  )
}

fn render_effects_rounded_ellipse_union() -> String {
  let ellipses = effect_ellipses()
  let input = svg_path.combine_paths(ellipses)
  let assert Ok(union) = union_paths(ellipses)
  let assert Ok(union_for_effects) = wiggle_path(union)
  let round_options =
    effects.RoundCornerOptions(
      ..effects.default_round_corner_options(),
      failure: effects.AdaptRadius,
    )
  let assert Ok(rounded) =
    effects.round_corners_with(
      union_for_effects,
      radius: 4.5,
      options: round_options,
    )

  theory_document(
    "Rounded corners on an ellipse union",
    3,
    1,
    [
      effects_input_panel(0, 0, "5 eccentric ellipses", input),
      effects_result_panel(1, 0, "raw union(ellipses)", union, svg_path.Nonzero),
      effects_result_panel(
        2,
        0,
        "round_corners(..., 4.5)",
        rounded,
        svg_path.Nonzero,
      ),
    ]
      |> list.flatten,
  )
}

fn wiggle_path(path: svg_path.Path) -> Result(svg_path.Path, svg_path.Error) {
  use subpaths <- result.try(
    wiggle_subpaths(svg_path.subpaths(path), wiggled: []),
  )
  Ok(svg_path.Path(subpaths:))
}

fn wiggle_subpaths(
  subpaths: List(svg_path.Subpath),
  wiggled wiggled: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), svg_path.Error) {
  case subpaths {
    [] -> Ok(list.reverse(wiggled))
    [subpath, ..rest] -> {
      use wiggled_subpath <- result.try(wiggle_subpath(subpath))
      wiggle_subpaths(rest, wiggled: [wiggled_subpath, ..wiggled])
    }
  }
}

fn wiggle_subpath(
  subpath: svg_path.Subpath,
) -> Result(svg_path.Subpath, svg_path.Error) {
  use open <- result.try(svg_path.subpath_with(
    svg_path.segments(subpath),
    policy: svg_path.Wiggle,
  ))
  svg_path.set_closed_with(
    open,
    closed: svg_path.is_closed(subpath),
    policy: svg_path.Wiggle,
  )
}

fn effect_rectangles() -> List(svg_path.Path) {
  [
    rectangle(26.0, 25.0, 82.0, 82.0),
    rectangle(58.0, 15.0, 120.0, 55.0),
    rectangle(94.0, 34.0, 146.0, 92.0),
    rectangle(42.0, 66.0, 108.0, 112.0),
    rectangle(5.0, 52.0, 54.0, 100.0),
    rectangle(112.0, 58.0, 166.0, 108.0),
    rectangle(72.0, 42.0, 132.0, 78.0),
  ]
}

fn effect_ellipses() -> List(svg_path.Path) {
  [
    ellipse_path(
      center: svg_path.point(84.0, 64.0),
      radius_x: 72.0,
      radius_y: 45.0,
      rotation: 11.0,
    ),
    ellipse_path(
      center: svg_path.point(87.0, 62.0),
      radius_x: 66.0,
      radius_y: 41.0,
      rotation: -31.0,
    ),
    ellipse_path(
      center: svg_path.point(80.0, 67.0),
      radius_x: 60.0,
      radius_y: 38.0,
      rotation: 42.0,
    ),
    ellipse_path(
      center: svg_path.point(90.0, 66.0),
      radius_x: 55.0,
      radius_y: 34.0,
      rotation: -64.0,
    ),
    ellipse_path(
      center: svg_path.point(82.0, 60.0),
      radius_x: 50.0,
      radius_y: 31.0,
      rotation: 73.0,
    ),
  ]
}

fn union_paths(
  paths: List(svg_path.Path),
) -> Result(svg_path.Path, svg_path.Error) {
  union_paths_with_options(paths, csg.default_options())
}

fn union_paths_with_options(
  paths: List(svg_path.Path),
  options: csg.Options,
) -> Result(svg_path.Path, svg_path.Error) {
  case paths {
    [] -> Ok(svg_path.empty_path())
    [first, ..rest] -> union_paths_loop(rest, first, options)
  }
}

fn union_paths_loop(
  paths: List(svg_path.Path),
  accumulated: svg_path.Path,
  options: csg.Options,
) -> Result(svg_path.Path, svg_path.Error) {
  case paths {
    [] -> Ok(accumulated)
    [path, ..rest] -> {
      use accumulated <- result.try(csg.union_with(
        accumulated,
        path,
        using: svg_path.Nonzero,
        options:,
      ))
      union_paths_loop(rest, accumulated, options)
    }
  }
}

fn effects_input_panel(
  column: Int,
  row: Int,
  label: String,
  path: svg_path.Path,
) -> svg.ThingsToDraw {
  let x = theory_x(column)
  let y = theory_y(row)
  let placed = theory_place(path, x, y)
  [
    theory_panel_background(x, y),
    theory_label(x, y, label),
    svg.StyledPath(
      placed,
      "fill: rgba(245, 158, 11, 0.16); stroke: #b45309; stroke-width: 2; stroke-linejoin: round",
    ),
  ]
  |> list.append(contour_overlays(placed, stroke_width: 1.5))
}

fn effects_result_panel(
  column: Int,
  row: Int,
  label: String,
  path: svg_path.Path,
  fill_rule: svg_path.FillRule,
) -> svg.ThingsToDraw {
  let x = theory_x(column)
  let y = theory_y(row)
  let placed = theory_place(path, x, y)
  [
    theory_panel_background(x, y),
    theory_label(x, y, label),
    svg.StyledPath(
      placed,
      "fill: #8ecae6; fill-rule: "
        <> svg_fill_rule(fill_rule)
        <> "; stroke: none",
    ),
  ]
  |> list.append(effects_contour_overlays(placed, stroke_width: 1.9))
}

fn effects_contour_overlays(
  path: svg_path.Path,
  stroke_width stroke_width: Float,
) -> svg.ThingsToDraw {
  path
  |> svg_path.subpaths
  |> list.index_map(fn(subpath, index) {
    let color = effects_contour_color(index)
    let subpath_path = svg_path.from_subpath(subpath)
    [
      svg.StyledPath(
        subpath_path,
        "fill: none; stroke: "
          <> color
          <> "; stroke-width: "
          <> float.to_string(stroke_width)
          <> "; stroke-linejoin: round",
      ),
      ..subpath_longest_segment_arrow(subpath, color, 0.82)
    ]
  })
  |> list.flatten
}

fn subpath_longest_segment_arrow(
  subpath: svg_path.Subpath,
  color: String,
  arrow_scale: Float,
) -> svg.ThingsToDraw {
  case longest_segment(svg_path.segments(subpath), best: Error(Nil)) {
    Error(_) -> []
    Ok(segment) -> {
      case segment_arrow_at(segment, color, arrow_scale, 0.42) {
        Error(_) -> []
        Ok(arrow) -> arrow
      }
    }
  }
}

fn longest_segment(
  segments: List(svg_path.Segment),
  best best: Result(#(svg_path.Segment, Float), Nil),
) -> Result(svg_path.Segment, Nil) {
  case segments {
    [] -> {
      case best {
        Error(_) -> Error(Nil)
        Ok(#(segment, _)) -> Ok(segment)
      }
    }
    [segment, ..rest] -> {
      let assert Ok(length) = svg_path.segment_length(segment)
      let best = case best {
        Error(_) -> Ok(#(segment, length))
        Ok(#(_, best_length)) if length >. best_length -> Ok(#(segment, length))
        Ok(_) -> best
      }
      longest_segment(rest, best:)
    }
  }
}

fn effects_contour_color(index: Int) -> String {
  case index % 10 {
    0 -> "#1f2937"
    1 -> "#fef08a"
    2 -> "#f0abfc"
    3 -> "#bae6fd"
    4 -> "#bbf7d0"
    5 -> "#fed7aa"
    6 -> "#c4b5fd"
    7 -> "#fde68a"
    8 -> "#99f6e4"
    _ -> "#fecdd3"
  }
}

fn theory_document(
  title: String,
  columns: Int,
  rows: Int,
  things: svg.ThingsToDraw,
) -> String {
  let width = theory_width(columns)
  let height = theory_height(rows)

  svg.document(
    [
      svg.Rectangle(
        svg_path.point(0.0, 0.0),
        width,
        height,
        "fill: #ffffff; stroke: none",
      ),
      svg.Text(
        title,
        "fill: #111827; font-family: system-ui, sans-serif; font-weight: 700",
        svg_path.point(0.0, 20.0),
        16,
      ),
      ..things
    ],
    view_box: svg_path.BoundingBox(
      min: svg_path.point(0.0, 0.0),
      max: svg_path.point(width, height),
    ),
  )
}

fn theory_input_panel(
  column: Int,
  row: Int,
  label: String,
  a: svg_path.Path,
  b: svg_path.Path,
) -> svg.ThingsToDraw {
  let x = theory_x(column)
  let y = theory_y(row)
  let placed_a = theory_place(a, x, y)
  let placed_b = theory_place(b, x, y)
  [
    theory_panel_background(x, y),
    theory_label(x, y, label),
    svg.StyledPath(
      placed_a,
      "fill: rgba(142, 202, 230, 0.55); stroke: #1f2937; stroke-width: 3; stroke-linejoin: round",
    ),
    svg.StyledPath(
      placed_b,
      "fill: rgba(255, 183, 3, 0.32); stroke: #f59e0b; stroke-width: 3; stroke-dasharray: 6 5; stroke-linejoin: round",
    ),
    svg.Text(
      "A",
      "fill: #1f2937; font-family: system-ui, sans-serif; font-weight: 700",
      svg_path.point(x +. 12.0, y +. 42.0),
      14,
    ),
    svg.Text(
      "B",
      "fill: #d97706; font-family: system-ui, sans-serif; font-weight: 700",
      svg_path.point(x +. theory_panel_width -. 26.0, y +. 70.0),
      14,
    ),
    ..path_arrows(placed_a, "#1f2937")
  ]
  |> list.append(path_arrows(placed_b, "#f59e0b"))
}

fn theory_input_only_panel(
  column: Int,
  row: Int,
  label: String,
  path: svg_path.Path,
) -> svg.ThingsToDraw {
  let x = theory_x(column)
  let y = theory_y(row)
  let placed = theory_place(path, x, y)
  [
    theory_panel_background(x, y),
    theory_label(x, y, label),
    svg.StyledPath(
      placed,
      "fill: rgba(31, 41, 55, 0.06); stroke: #1f2937; stroke-width: 4; stroke-linejoin: round",
    ),
    svg.Text(
      "A",
      "fill: #1f2937; font-family: system-ui, sans-serif; font-weight: 700",
      svg_path.point(x +. 12.0, y +. 42.0),
      14,
    ),
    ..nested_input_arrows(placed, "#1f2937", arrow_scale: 1.0)
  ]
}

fn theory_result_panel(
  column: Int,
  row: Int,
  label: String,
  path: svg_path.Path,
  fill_rule: svg_path.FillRule,
) -> svg.ThingsToDraw {
  let x = theory_x(column)
  let y = theory_y(row)
  let placed = theory_place(path, x, y)
  [
    theory_panel_background(x, y),
    theory_label(x, y, label),
    svg.StyledPath(
      placed,
      "fill: #8ecae6; fill-rule: "
        <> svg_fill_rule(fill_rule)
        <> "; stroke: none",
    ),
  ]
  |> list.append(contour_overlays(placed, stroke_width: 3.0))
}

fn theory_panel_background(x: Float, y: Float) -> svg.ThingToDraw {
  svg.Rectangle(
    svg_path.point(x, y),
    theory_panel_width,
    theory_panel_height,
    "fill: #f8fafc; stroke: #d1d5db; stroke-width: 1",
  )
}

fn theory_label(x: Float, y: Float, label: String) -> svg.ThingToDraw {
  svg.Text(
    label,
    "fill: #111827; font-family: system-ui, sans-serif; font-weight: 700",
    svg_path.point(x, y -. 7.0),
    10,
  )
}

fn theory_x(column: Int) -> Float {
  int.to_float(column) *. { theory_panel_width +. theory_panel_gap }
}

fn theory_y(row: Int) -> Float {
  theory_top +. int.to_float(row) *. { theory_panel_height +. theory_row_gap }
}

fn theory_place(path: svg_path.Path, x: Float, y: Float) -> svg_path.Path {
  let assert Ok(translated) = transform.translate_path(path, x:, y:)
  translated
}

fn theory_width(columns: Int) -> Float {
  int.to_float(columns)
  *. theory_panel_width
  +. int.to_float(columns - 1)
  *. theory_panel_gap
}

fn theory_height(rows: Int) -> Float {
  theory_top
  +. int.to_float(rows)
  *. theory_panel_height
  +. int.to_float(rows - 1)
  *. theory_row_gap
  +. 8.0
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
  nested_rectangles_with_inner(same_direction: True)
}

fn nested_theory_path(
  inner_same_direction inner_same_direction: Bool,
) -> svg_path.Path {
  svg_path.Path([
    rounded_rectangle_subpath(
      30.0,
      20.0,
      150.0,
      110.0,
      radius: 8.0,
      same_direction: True,
    ),
    rounded_rectangle_subpath(
      65.0,
      48.0,
      115.0,
      82.0,
      radius: 5.0,
      same_direction: inner_same_direction,
    ),
  ])
}

fn nested_rectangles_with_inner(
  same_direction same_direction: Bool,
) -> svg_path.Path {
  svg_path.Path([
    svg_path.assert_polygon([
      svg_path.point(8.0, 8.0),
      svg_path.point(114.0, 8.0),
      svg_path.point(114.0, 90.0),
      svg_path.point(8.0, 90.0),
    ]),
    rectangle_subpath(34.0, 28.0, 88.0, 70.0, same_direction:),
  ])
}

fn bar(same_direction same_direction: Bool) -> svg_path.Path {
  svg_path.from_subpath(rectangle_subpath(
    0.0,
    44.0,
    122.0,
    66.0,
    same_direction:,
  ))
}

fn rectangle_subpath(
  min_x: Float,
  min_y: Float,
  max_x: Float,
  max_y: Float,
  same_direction same_direction: Bool,
) -> svg_path.Subpath {
  let points = case same_direction {
    True -> [
      svg_path.point(min_x, min_y),
      svg_path.point(max_x, min_y),
      svg_path.point(max_x, max_y),
      svg_path.point(min_x, max_y),
    ]
    False -> [
      svg_path.point(min_x, min_y),
      svg_path.point(min_x, max_y),
      svg_path.point(max_x, max_y),
      svg_path.point(max_x, min_y),
    ]
  }

  svg_path.assert_polygon(points)
}

fn rounded_rectangle_subpath(
  min_x: Float,
  min_y: Float,
  max_x: Float,
  max_y: Float,
  radius radius: Float,
  same_direction same_direction: Bool,
) -> svg_path.Subpath {
  let top_left = svg_path.point(min_x +. radius, min_y)
  let top_right = svg_path.point(max_x -. radius, min_y)
  let right_top = svg_path.point(max_x, min_y +. radius)
  let right_bottom = svg_path.point(max_x, max_y -. radius)
  let bottom_right = svg_path.point(max_x -. radius, max_y)
  let bottom_left = svg_path.point(min_x +. radius, max_y)
  let left_bottom = svg_path.point(min_x, max_y -. radius)
  let left_top = svg_path.point(min_x, min_y +. radius)
  let arc_radius = svg_path.point(radius, radius)

  let clockwise =
    svg_path.assert_subpath([
      svg_path.Line(start: top_left, end: top_right),
      svg_path.Arc(
        start: top_right,
        radius: arc_radius,
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: right_top,
      ),
      svg_path.Line(start: right_top, end: right_bottom),
      svg_path.Arc(
        start: right_bottom,
        radius: arc_radius,
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: bottom_right,
      ),
      svg_path.Line(start: bottom_right, end: bottom_left),
      svg_path.Arc(
        start: bottom_left,
        radius: arc_radius,
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: left_bottom,
      ),
      svg_path.Line(start: left_bottom, end: left_top),
      svg_path.Arc(
        start: left_top,
        radius: arc_radius,
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: top_left,
      ),
    ])
    |> svg_path.assert_set_closed(closed: True)

  case same_direction {
    True -> clockwise
    False -> svg_path.reverse_subpath(clockwise)
  }
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

fn ellipse_path(
  center center: svg_path.Point,
  radius_x radius_x: Float,
  radius_y radius_y: Float,
  rotation rotation: Float,
) -> svg_path.Path {
  let axis =
    svg_path.point(
      trig.cos_degrees(rotation) *. radius_x,
      trig.sin_degrees(rotation) *. radius_x,
    )
  let left = subtract(center, axis)
  let right = add(center, axis)
  let radius = svg_path.point(radius_x, radius_y)

  svg_path.from_subpath(
    svg_path.assert_subpath([
      svg_path.Arc(
        start: right,
        radius:,
        x_axis_rotation: rotation,
        large_arc: False,
        sweep: True,
        end: left,
      ),
      svg_path.Arc(
        start: left,
        radius:,
        x_axis_rotation: rotation,
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

fn svg_fill_rule(fill_rule: svg_path.FillRule) -> String {
  case fill_rule {
    svg_path.Nonzero -> "nonzero"
    svg_path.EvenOdd -> "evenodd"
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

const guide_panel_width = 150.0

const guide_panel_height = 104.0

const guide_panel_gap = 16.0

const guide_origin_y = 55.0

const guide_row_gap = 28.0

fn guide_panel_x(index: Int) -> Float {
  int.to_float(index) *. { guide_panel_width +. guide_panel_gap }
}

fn guide_header_y() -> Float {
  42.0
}

fn guide_row_y(index: Int) -> Float {
  guide_origin_y
  +. int.to_float(index)
  *. { guide_panel_height +. guide_row_gap }
}

fn guide_panel_background(x: Float, y: Float) -> svg.ThingToDraw {
  svg.Rectangle(
    svg_path.point(x, y),
    guide_panel_width,
    guide_panel_height,
    "fill: #f8fafc; stroke: #d1d5db; stroke-width: 1",
  )
}

fn guide_place(
  path: svg_path.Path,
  panel_x: Float,
  panel_y: Float,
) -> svg_path.Path {
  let assert Ok(translated) =
    transform.translate_path(path, x: panel_x +. 14.0, y: panel_y +. 6.0)
  translated
}

fn guide_document_width() -> Float {
  guide_panel_width *. 4.0 +. guide_panel_gap *. 3.0
}

fn guide_document_height(rows: Int) -> Float {
  guide_origin_y
  +. int.to_float(rows)
  *. guide_panel_height
  +. int.to_float(rows - 1)
  *. guide_row_gap
  +. 16.0
}

const combo_panel_width = 190.0

const combo_panel_height = 130.0

const combo_panel_gap = 14.0

const combo_top = 58.0

const combo_row_gap = 24.0

fn combo_x(column: Int) -> Float {
  int.to_float(column) *. { combo_panel_width +. combo_panel_gap }
}

fn combo_y(row: Int) -> Float {
  combo_top +. int.to_float(row) *. { combo_panel_height +. combo_row_gap }
}

fn combo_place(path: svg_path.Path, x: Float, y: Float) -> svg_path.Path {
  let assert Ok(translated) = transform.translate_path(path, x:, y:)
  translated
}

fn combo_width() -> Float {
  combo_panel_width *. 4.0 +. combo_panel_gap *. 3.0
}

fn combo_height() -> Float {
  combo_top +. combo_panel_height *. 4.0 +. combo_row_gap *. 3.0 +. 8.0
}

@external(erlang, "filelib", "ensure_dir")
fn ensure_dir(path: String) -> Dynamic

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
