//// Scratch runner for drawing a 1-degree crescent point cloud with its hull.
////
////     gleam run -m crescent_hull_probe > crescent_hull_probe.svg

import gleam/int
import gleam/io
import gleam/list
import gleam_community/maths
import svg_path
import svg_path/convex_hull
import svg_path/svg

pub fn main() {
  io.println(drawing_svg())
}

pub fn drawing_svg() -> String {
  let start = radius_1000_point(0.0)
  let end = radius_1000_point(1.0)
  let points = visible_crescent_points(60, line_start: start, line_end: end)
  let path = crescent_path(points, line_start: start, line_end: end)
  let assert Ok(hull) = convex_hull.path_hull(path)

  svg.document(
    [
      svg.StyledPath(
        reference_circle_arc(start, end),
        "fill: none; stroke: #9a9a9a; stroke-width: 0.002; stroke-linecap: round",
      ),
      svg.StyledPath(
        big_line(start, end),
        "fill: none; stroke: #777; stroke-width: 0.0025; stroke-linecap: round",
      ),
      svg.StyledPath(
        svg_path.Path([hull]),
        "fill: rgba(255, 127, 14, 0.12); stroke: #ff7f0e; stroke-width: 0.003",
      ),
      ..point_markers(points)
    ],
    view_box: svg_path.BoundingBox(
      min: svg_path.point(999.8, 8.4),
      max: svg_path.point(1000.0, 8.5),
    ),
  )
}

fn crescent_path(
  points: List(svg_path.Point),
  line_start line_start: svg_path.Point,
  line_end line_end: svg_path.Point,
) -> svg_path.Path {
  let line =
    svg_path.subpath_assert([
      svg_path.Line(start: line_start, end: line_end),
    ])
  let point_subpaths =
    points
    |> list.map(fn(point) { svg_path.subpath_empty(at: point) })

  svg_path.Path([line, ..point_subpaths])
}

fn reference_circle_arc(
  start: svg_path.Point,
  end: svg_path.Point,
) -> svg_path.Path {
  svg_path.Path([
    svg_path.subpath_assert([
      svg_path.Arc(
        start:,
        radius: svg_path.point(1000.0, 1000.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end:,
      ),
    ]),
  ])
}

fn big_line(start: svg_path.Point, end: svg_path.Point) -> svg_path.Path {
  svg_path.Path([
    svg_path.subpath_assert([
      svg_path.Line(start:, end:),
    ]),
  ])
}

fn visible_crescent_points(
  count: Int,
  line_start line_start: svg_path.Point,
  line_end line_end: svg_path.Point,
) -> List(svg_path.Point) {
  candidate_indexes(count * 12)
  |> list.filter_map(fn(index) {
    let point = crescent_candidate_point(index, line_start:, line_end:)
    case point_inside_crescent(point, line_start:, line_end:) {
      True -> Ok(point)
      False -> Error(Nil)
    }
  })
  |> take_first(count)
}

fn candidate_indexes(count: Int) -> List(Int) {
  int.range(from: 0, to: count, with: [], run: fn(indexes, index) {
    [index, ..indexes]
  })
  |> list.reverse
}

fn crescent_candidate_point(
  index: Int,
  line_start line_start: svg_path.Point,
  line_end line_end: svg_path.Point,
) -> svg_path.Point {
  let angle = 0.481 +. int.to_float({ index * 89 + 37 } % 1000) /. 100_000.0
  let radians = angle *. maths.pi() /. 180.0
  let y = 1000.0 *. maths.sin(radians)
  let circle_x = 1000.0 *. maths.cos(radians)
  let chord_x = chord_x_at_y(y, line_start:, line_end:)
  let fraction =
    0.08
    +. 0.84
    *. int.to_float({ { index * 61 + 43 } * { index * 31 + 29 } + 17 } % 10_000)
    /. 10_000.0

  svg_path.point(chord_x +. fraction *. { circle_x -. chord_x }, y)
}

fn chord_x_at_y(
  y: Float,
  line_start line_start: svg_path.Point,
  line_end line_end: svg_path.Point,
) -> Float {
  let t = { y -. line_start.y } /. { line_end.y -. line_start.y }
  line_start.x +. t *. { line_end.x -. line_start.x }
}

fn point_inside_crescent(
  point: svg_path.Point,
  line_start line_start: svg_path.Point,
  line_end line_end: svg_path.Point,
) -> Bool {
  let radius_squared = point.x *. point.x +. point.y *. point.y
  radius_squared <=. 1000.0 *. 1000.0 +. 0.000001
  && chord_side(point, line_start:, line_end:) <=. 0.000001
}

fn chord_side(
  point: svg_path.Point,
  line_start line_start: svg_path.Point,
  line_end line_end: svg_path.Point,
) -> Float {
  { line_end.x -. line_start.x }
  *. { point.y -. line_start.y }
  -. { line_end.y -. line_start.y }
  *. { point.x -. line_start.x }
}

fn take_first(
  points: List(svg_path.Point),
  count: Int,
) -> List(svg_path.Point) {
  take_first_loop(points, count, [])
}

fn take_first_loop(
  points: List(svg_path.Point),
  count: Int,
  taken: List(svg_path.Point),
) -> List(svg_path.Point) {
  case points, count {
    _, count if count <= 0 -> list.reverse(taken)
    [], _ -> list.reverse(taken)
    [point, ..rest], _ -> take_first_loop(rest, count - 1, [point, ..taken])
  }
}

fn radius_1000_point(angle: Float) -> svg_path.Point {
  let radians = angle *. maths.pi() /. 180.0
  svg_path.point(1000.0 *. maths.cos(radians), 1000.0 *. maths.sin(radians))
}

fn point_markers(points: List(svg_path.Point)) -> List(svg.ThingToDraw) {
  points
  |> list.map(fn(point) {
    svg.Circle(point, 0.003, "fill: #2ca02c; stroke: none")
  })
}
