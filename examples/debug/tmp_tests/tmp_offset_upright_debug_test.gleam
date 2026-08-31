import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/list
import gleam/result
import svg_path
import svg_path/offset
import svg_path/svg
import svg_path/transform

const output = "examples/debug/svg_path_offset_upright_figure_eight_single.svg"

pub fn main() -> Nil {
  let _ = write_file(output, render())
  Nil
}

fn render() -> String {
  let source =
    smooth_horizontal_figure_eight()
    |> transform.translate_subpath(x: -220.4, y: -116.0)
  let assert Ok(source) = source
  let default = offset.default_options()
  let options =
    offset.Options(
      ..default,
      fitting: offset.FittingOptions(..default.fitting, tolerance: 0.01),
      join: offset.Round,
    )

  let result_things = case
    retained_band_sections(
      source,
      inner_offset: 15.0,
      outer_offset: 30.0,
      options:,
    )
  {
    Ok(sections) ->
      list.append(
        colored_subpaths(sections, palette()),
        segment_start_dots(sections),
      )
    Error(_) -> [
      svg.Text(
        "Error while computing retained +15/+30 sections",
        "fill: #b91c1c; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-weight: 700",
        svg_path.Point(24.0, 466.0),
        14,
      ),
    ]
  }

  svg.document(
    things: [
      svg.Rectangle(
        svg_path.Point(0.0, 0.0),
        640.0,
        500.0,
        "fill: #ffffff; stroke: #d1d5db; stroke-width: 1.5",
      ),
      svg.Text(
        "smooth horizontal figure-eight: retained sections before restitch",
        "fill: #111827; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-weight: 700",
        svg_path.Point(24.0, 30.0),
        15,
      ),
      svg.StyledPath(
        svg_path.subpath_as_path(source),
        "fill: none; stroke: #9ca3af; stroke-width: 1.2; stroke-linecap: round; stroke-linejoin: round; stroke-dasharray: 5 5",
      ),
      ..result_things
    ],
    view_box: svg_path.BoundingBox(
      min: svg_path.Point(0.0, 0.0),
      max: svg_path.Point(640.0, 500.0),
    ),
  )
}

fn retained_band_sections(
  source: svg_path.Subpath,
  inner_offset inner_offset: Float,
  outer_offset outer_offset: Float,
  options options: offset.Options,
) -> Result(List(svg_path.Subpath), offset.Error) {
  use provisional_a <- result.try(offset.subpath_untrimmed_with(
    source,
    offset: inner_offset,
    options:,
  ))
  use provisional_b <- result.try(offset.subpath_untrimmed_with(
    source,
    offset: outer_offset,
    options:,
  ))
  use #(cross_a, cross_b) <- result.try(cross_side_split_parameters(
    provisional_a,
    provisional_b,
  ))
  use sections_a <- result.try(retained_sections_for_side(
    source,
    provisional_a,
    inner_offset,
    options,
    extra_split_points: cross_a,
  ))
  use sections_b <- result.try(retained_sections_for_side(
    source,
    provisional_b,
    outer_offset,
    options,
    extra_split_points: cross_b,
  ))
  Ok(list.append(sections_a, sections_b))
}

fn retained_sections_for_side(
  source: svg_path.Subpath,
  provisional: svg_path.Subpath,
  distance: Float,
  options: offset.Options,
  extra_split_points extra_split_points: List(svg_path.SubpathParameter),
) -> Result(List(svg_path.Subpath), offset.Error) {
  use sections <- result.try(split_sections(provisional, extra_split_points:))
  retain_sections(sections, source, distance, options, retained: [])
}

fn split_sections(
  subpath: svg_path.Subpath,
  extra_split_points extra_split_points: List(svg_path.SubpathParameter),
) -> Result(List(svg_path.Subpath), offset.Error) {
  use self_points <- result.try(self_split_parameters(subpath))
  let split_points =
    list.append(self_points, extra_split_points)
    |> list.sort(by: svg_path.subpath_parameters_compare)
    |> unique_subpath_parameters([])

  case split_points {
    [] -> Ok([subpath])
    _ ->
      svg_path.subpath_between_many(subpath, between: split_points)
      |> result.map_error(offset.PathError)
  }
}

fn self_split_parameters(
  subpath: svg_path.Subpath,
) -> Result(List(svg_path.SubpathParameter), offset.Error) {
  use intersections <- result.try(
    svg_path.subpath_self_intersections_with(
      subpath,
      options: svg_path.SelfIntersectionOptions(
        minimum_arc_length_separation: 0.000000002,
        distance_tolerance: 0.000000001,
      ),
    )
    |> result.map_error(offset.PathError),
  )

  Ok(
    intersections
    |> list.flat_map(fn(intersection) {
      let svg_path.SubpathSelfIntersection(parameters: #(left, right), ..) =
        intersection
      [left, right]
    })
    |> list.sort(by: svg_path.subpath_parameters_compare)
    |> unique_subpath_parameters([]),
  )
}

fn cross_side_split_parameters(
  left: svg_path.Subpath,
  right: svg_path.Subpath,
) -> Result(
  #(List(svg_path.SubpathParameter), List(svg_path.SubpathParameter)),
  offset.Error,
) {
  use intersections <- result.try(
    svg_path.subpath_intersections_with(
      left,
      right,
      options: svg_path.default_intersection_options(),
    )
    |> result.map_error(offset.PathError),
  )
  let left_parameters =
    intersections
    |> list.flat_map(fn(intersection) {
      let svg_path.SubpathIntersection(left_parameters:, ..) = intersection
      left_parameters
    })
    |> list.sort(by: svg_path.subpath_parameters_compare)
    |> unique_subpath_parameters([])
  let right_parameters =
    intersections
    |> list.flat_map(fn(intersection) {
      let svg_path.SubpathIntersection(right_parameters:, ..) = intersection
      right_parameters
    })
    |> list.sort(by: svg_path.subpath_parameters_compare)
    |> unique_subpath_parameters([])
  Ok(#(left_parameters, right_parameters))
}

fn unique_subpath_parameters(
  parameters: List(svg_path.SubpathParameter),
  unique unique: List(svg_path.SubpathParameter),
) -> List(svg_path.SubpathParameter) {
  case parameters {
    [] -> list.reverse(unique)
    [first, ..rest] -> {
      case unique {
        [previous, ..] -> {
          case same_parameter(first, previous) {
            True -> unique_subpath_parameters(rest, unique:)
            False -> unique_subpath_parameters(rest, unique: [first, ..unique])
          }
        }
        [] -> unique_subpath_parameters(rest, unique: [first])
      }
    }
  }
}

fn same_parameter(
  left: svg_path.SubpathParameter,
  right: svg_path.SubpathParameter,
) -> Bool {
  let svg_path.SubpathParameter(segment_index: left_index, t: left_t) = left
  let svg_path.SubpathParameter(segment_index: right_index, t: right_t) = right
  left_index == right_index
  && float.absolute_value(left_t -. right_t) <=. 0.000000001
}

fn retain_sections(
  sections: List(svg_path.Subpath),
  source: svg_path.Subpath,
  distance: Float,
  options: offset.Options,
  retained retained: List(svg_path.Subpath),
) -> Result(List(svg_path.Subpath), offset.Error) {
  case sections {
    [] -> Ok(list.reverse(retained))
    [first, ..rest] -> {
      use keep <- result.try(section_is_valid(first, source, distance, options))
      let retained = case keep {
        True -> [first, ..retained]
        False -> retained
      }
      retain_sections(rest, source, distance, options, retained:)
    }
  }
}

fn section_is_valid(
  section: svg_path.Subpath,
  source: svg_path.Subpath,
  distance: Float,
  options: offset.Options,
) -> Result(Bool, offset.Error) {
  use length <- result.try(
    svg_path.subpath_length(section) |> result.map_error(offset.PathError),
  )
  section_has_enough_non_negative_samples(
    section,
    length,
    [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9],
    source,
    distance,
    options,
    count: 0,
  )
}

fn section_has_enough_non_negative_samples(
  section: svg_path.Subpath,
  length: Float,
  samples: List(Float),
  source: svg_path.Subpath,
  distance: Float,
  options: offset.Options,
  count count: Int,
) -> Result(Bool, offset.Error) {
  case samples {
    [] -> Ok(count >= 5)
    [first, ..rest] -> {
      use point <- result.try(
        svg_path.subpath_point_at_length(section, distance: length *. first)
        |> result.map_error(offset.PathError),
      )
      use projection <- result.try(
        svg_path.subpath_projection_with(
          point,
          to: source,
          options: options.distance_options,
        )
        |> result.map_error(offset.PathError),
      )
      let count = case
        projection.distance +. options.fitting.tolerance
        >=. float.absolute_value(distance)
      {
        True -> count + 1
        False -> count
      }
      section_has_enough_non_negative_samples(
        section,
        length,
        rest,
        source,
        distance,
        options,
        count:,
      )
    }
  }
}

fn colored_subpaths(
  subpaths: List(svg_path.Subpath),
  colors: List(String),
) -> svg.ThingsToDraw {
  colored_subpaths_loop(subpaths, colors, palette(), drawn: [])
}

fn colored_subpaths_loop(
  subpaths: List(svg_path.Subpath),
  colors: List(String),
  all_colors: List(String),
  drawn drawn: svg.ThingsToDraw,
) -> svg.ThingsToDraw {
  case subpaths, colors {
    [], _ -> list.reverse(drawn)
    _, [] -> colored_subpaths_loop(subpaths, all_colors, all_colors, drawn:)
    [first, ..rest], [color, ..remaining_colors] ->
      colored_subpaths_loop(rest, remaining_colors, all_colors, drawn: [
        svg.StyledPath(
          svg_path.subpath_as_path(first),
          "fill: none; stroke: "
            <> color
            <> "; stroke-width: 2.4; stroke-linecap: round; stroke-linejoin: round",
        ),
        ..drawn
      ])
  }
}

fn palette() -> List(String) {
  ["#0f766e", "#b45309", "#6d28d9", "#be123c", "#047857", "#1d4ed8"]
}

fn segment_start_dots(subpaths: List(svg_path.Subpath)) -> svg.ThingsToDraw {
  subpaths
  |> list.flat_map(fn(subpath) {
    subpath
    |> svg_path.subpath_segments
    |> list.map(fn(segment) {
      svg.Circle(
        svg_path.segment_start(segment),
        3.2,
        "fill: #000000; stroke: #ffffff; stroke-width: 0.8",
      )
    })
  })
}

fn smooth_horizontal_figure_eight() -> svg_path.Subpath {
  svg_path.subpath_assert([
    svg_path.CubicBezier(
      start: svg_path.Point(518.4, 360.0),
      control1: svg_path.Point(108.0, 11.52),
      control2: svg_path.Point(108.0, 708.48),
      end: svg_path.Point(518.4, 360.0),
    ),
    svg_path.CubicBezier(
      start: svg_path.Point(518.4, 360.0),
      control1: svg_path.Point(928.8, 11.52),
      control2: svg_path.Point(928.8, 708.48),
      end: svg_path.Point(518.4, 360.0),
    ),
  ])
  |> svg_path.subpath_assert_set_closed(closed: True)
}

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic
