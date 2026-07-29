import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/list
import gleam/order
import gleam/result
import svg_path
import svg_path/offset
import svg_path/svg
import svg_path/transform

const output = "examples/debug/svg_path_stroke_sections.svg"

const scale_factor = 4.0

pub fn main() -> Nil {
  let _ = write_file(output, render())
  Nil
}

fn render() -> String {
  let assert Ok(source) =
    figure_eight()
    |> transform.scale_subpath(factor: scale_factor)
    |> result.try_recover(fn(_) { Error(Nil) })
  let assert Ok(source) = transform.translate_subpath(source, x: 80.0, y: 240.0)
  let default = offset.default_options()
  let options =
    offset.Options(
      ..default,
      fitting: offset.FittingOptions(
        ..default.fitting,
        tolerance: 0.01 *. scale_factor,
      ),
    )
  let assert Ok(negative) =
    offset.subpath_untrimmed_with(source, distance: 0.0 -. radius(), options:)
  let assert Ok(positive) =
    offset.subpath_untrimmed_with(source, distance: radius(), options:)
  let #(negative_cross, positive_cross) =
    cross_split_parameters(negative, positive)
  let negative_sections = split_sections(negative, extra: negative_cross)
  let positive_sections = split_sections(positive, extra: positive_cross)

  svg.document(
    things: list.flatten([
      [
        svg.Rectangle(
          svg_path.Point(0.0, 0.0),
          720.0,
          430.0,
          "fill: #ffffff; stroke: #d1d5db; stroke-width: 2",
        ),
        svg.Text(
          "closed stroke after self/cross-intersection split",
          "fill: #111827; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-weight: 700",
          svg_path.Point(24.0, 36.0),
          18,
        ),
      ],
      draw_sections(negative_sections, index: 0, things: []),
      draw_sections(
        positive_sections,
        index: list.length(negative_sections),
        things: [],
      ),
      [
        svg.StyledPath(
          svg_path.path_from_subpath(source),
          "fill: none; stroke: #ef4444; stroke-width: 2.5; stroke-dasharray: 10 10; stroke-linecap: round",
        ),
        ..segment_arrows(svg_path.subpath_segments(source), "#ef4444", 1.3)
      ],
    ]),
    view_box: svg_path.BoundingBox(
      min: svg_path.Point(0.0, 0.0),
      max: svg_path.Point(720.0, 430.0),
    ),
  )
}

fn cross_split_parameters(
  negative: svg_path.Subpath,
  positive: svg_path.Subpath,
) -> #(List(svg_path.SubpathParameter), List(svg_path.SubpathParameter)) {
  let assert Ok(intersections) =
    svg_path.subpath_intersections(negative, positive)
  let negative_parameters =
    intersections
    |> list.flat_map(fn(intersection) {
      let svg_path.SubpathIntersection(left_parameters:, ..) = intersection
      left_parameters
    })
    |> normalize_parameters
  let positive_parameters =
    intersections
    |> list.flat_map(fn(intersection) {
      let svg_path.SubpathIntersection(right_parameters:, ..) = intersection
      right_parameters
    })
    |> normalize_parameters
  #(negative_parameters, positive_parameters)
}

fn split_sections(
  subpath: svg_path.Subpath,
  extra extra: List(svg_path.SubpathParameter),
) -> List(svg_path.Subpath) {
  let self_options =
    svg_path.SelfIntersectionOptions(
      minimum_arc_length_separation: 0.000001,
      distance_tolerance: 0.000001,
    )
  let assert Ok(intersections) =
    svg_path.subpath_self_intersections_with(subpath, options: self_options)
  let parameters =
    intersections
    |> list.flat_map(fn(intersection) {
      let svg_path.SubpathSelfIntersection(parameters: #(left, right), ..) =
        intersection
      [left, right]
    })
    |> list.append(extra)
    |> normalize_parameters
  case parameters {
    [] -> [subpath]
    _ -> {
      let assert Ok(sections) =
        svg_path.subpath_between_many(subpath, between: parameters)
      sections
    }
  }
}

fn normalize_parameters(
  parameters: List(svg_path.SubpathParameter),
) -> List(svg_path.SubpathParameter) {
  parameters
  |> list.sort(by: svg_path.subpath_parameters_compare)
  |> unique_subpath_parameters([])
}

fn unique_subpath_parameters(
  parameters: List(svg_path.SubpathParameter),
  unique unique: List(svg_path.SubpathParameter),
) -> List(svg_path.SubpathParameter) {
  case parameters {
    [] -> list.reverse(unique)
    [first, ..rest] ->
      case unique {
        [previous, ..] ->
          case svg_path.subpath_parameters_compare(first, previous) {
            order.Eq -> unique_subpath_parameters(rest, unique:)
            _ -> unique_subpath_parameters(rest, unique: [first, ..unique])
          }
        [] -> unique_subpath_parameters(rest, unique: [first])
      }
  }
}

fn draw_sections(
  sections: List(svg_path.Subpath),
  index index: Int,
  things things: svg.ThingsToDraw,
) -> svg.ThingsToDraw {
  case sections {
    [] -> list.reverse(things)
    [first, ..rest] -> {
      let color = color(index)
      draw_sections(rest, index: index + 1, things: [
        svg.StyledPath(
          svg_path.path_from_subpath(first),
          "fill: none; stroke: "
            <> color
            <> "; stroke-width: 4; stroke-linejoin: round; stroke-linecap: round",
        ),
        ..list.append(subpath_arrows(first, color, 0.85), things)
      ])
    }
  }
}

fn segment_arrows(
  segments: List(svg_path.Segment),
  color: String,
  arrow_scale: Float,
) -> svg.ThingsToDraw {
  case segments {
    [] -> []
    [first, ..rest] ->
      list.append(
        segment_arrow(first, color, arrow_scale),
        segment_arrows(rest, color, arrow_scale),
      )
  }
}

fn segment_arrow(
  segment: svg_path.Segment,
  color: String,
  arrow_scale: Float,
) -> svg.ThingsToDraw {
  case
    svg_path.segment_point(segment, at: 0.42),
    svg_path.segment_derivative(segment, at: 0.42)
  {
    Ok(point), Ok(derivative) -> {
      let length = point_length(derivative)
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
          let length = point_length(derivative)
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
  let half_width = 6.0 *. arrow_scale
  let arrow_height = half_width *. 1.7320508075688772
  let normal = svg_path.Point(0.0 -. unit.y, unit.x)
  let tip = add(point, scale(unit, arrow_height *. 2.0 /. 3.0))
  let base = add(point, scale(unit, 0.0 -. arrow_height /. 3.0))
  let left = add(base, scale(normal, half_width))
  let right = add(base, scale(normal, 0.0 -. half_width))
  svg.StyledPath(
    svg_path.Path([svg_path.subpath_assert_polygon([tip, left, right])]),
    "fill: " <> color <> "; stroke: none",
  )
}

fn add(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.Point(a.x +. b.x, a.y +. b.y)
}

fn scale(point: svg_path.Point, factor: Float) -> svg_path.Point {
  svg_path.Point(point.x *. factor, point.y *. factor)
}

fn point_length(point: svg_path.Point) -> Float {
  let assert Ok(length) =
    float.square_root(point.x *. point.x +. point.y *. point.y)
  length
}

fn color(index: Int) -> String {
  case index % 10 {
    0 -> "#0f766e"
    1 -> "#b45309"
    2 -> "#7c3aed"
    3 -> "#be123c"
    4 -> "#2563eb"
    5 -> "#15803d"
    6 -> "#a21caf"
    7 -> "#92400e"
    8 -> "#0891b2"
    _ -> "#334155"
  }
}

fn figure_eight() -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.CubicBezier(
      start: svg_path.Point(76.0, 0.0),
      control1: svg_path.Point(-2.0, -62.0),
      control2: svg_path.Point(-2.0, 62.0),
      end: svg_path.Point(76.0, 0.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.Point(76.0, 0.0),
      control1: svg_path.Point(154.0, -62.0),
      control2: svg_path.Point(154.0, 62.0),
      end: svg_path.Point(76.0, 0.0),
    ),
  ])
  |> svg_path.subpath_assert_set_closed(closed: True)
}

fn radius() -> Float {
  13.0 *. scale_factor
}

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
