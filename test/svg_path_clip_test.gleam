import gleam/float
import gleam/list
import gleeunit
import svg_path
import svg_path/clip

const tolerance = 0.000001

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn open_line_clips_to_inside_piece_test() {
  let input =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(-5.0, 5.0),
        end: svg_path.Point(15.0, 5.0),
      ),
    ])

  let assert Ok([clipped]) =
    clip.subpath(
      input,
      to: rectangle(0.0, 0.0, 10.0, 10.0),
      using: svg_path.Nonzero,
    )

  assert !svg_path.subpath_is_closed(clipped)
  assert svg_path.subpath_segments(clipped)
    == [
      svg_path.Line(
        start: svg_path.Point(0.0, 5.0),
        end: svg_path.Point(10.0, 5.0),
      ),
    ]
}

pub fn open_subpath_clips_to_multiple_open_pieces_without_bridges_test() {
  let input =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(-5.0, 2.0),
        end: svg_path.Point(5.0, 2.0),
      ),
      svg_path.Line(
        start: svg_path.Point(5.0, 2.0),
        end: svg_path.Point(15.0, 2.0),
      ),
      svg_path.Line(
        start: svg_path.Point(15.0, 2.0),
        end: svg_path.Point(15.0, 8.0),
      ),
      svg_path.Line(
        start: svg_path.Point(15.0, 8.0),
        end: svg_path.Point(5.0, 8.0),
      ),
      svg_path.Line(
        start: svg_path.Point(5.0, 8.0),
        end: svg_path.Point(-5.0, 8.0),
      ),
    ])

  let assert Ok([first, second]) =
    clip.subpath(
      input,
      to: rectangle(0.0, 0.0, 10.0, 10.0),
      using: svg_path.Nonzero,
    )

  assert !svg_path.subpath_is_closed(first)
  assert !svg_path.subpath_is_closed(second)
  assert svg_path.subpath_segments(first)
    == [
      svg_path.Line(
        start: svg_path.Point(0.0, 2.0),
        end: svg_path.Point(5.0, 2.0),
      ),
      svg_path.Line(
        start: svg_path.Point(5.0, 2.0),
        end: svg_path.Point(10.0, 2.0),
      ),
    ]
  assert svg_path.subpath_segments(second)
    == [
      svg_path.Line(
        start: svg_path.Point(10.0, 8.0),
        end: svg_path.Point(5.0, 8.0),
      ),
      svg_path.Line(
        start: svg_path.Point(5.0, 8.0),
        end: svg_path.Point(0.0, 8.0),
      ),
    ]
}

pub fn clip_boundary_at_subpath_vertex_does_not_duplicate_split_test() {
  let input =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(-5.0, 5.0),
        end: svg_path.Point(0.0, 5.0),
      ),
      svg_path.Line(
        start: svg_path.Point(0.0, 5.0),
        end: svg_path.Point(5.0, 5.0),
      ),
    ])

  let assert Ok([clipped]) =
    clip.subpath(
      input,
      to: rectangle(0.0, 0.0, 10.0, 10.0),
      using: svg_path.Nonzero,
    )

  assert svg_path.subpath_segments(clipped)
    == [
      svg_path.Line(
        start: svg_path.Point(0.0, 5.0),
        end: svg_path.Point(5.0, 5.0),
      ),
    ]
}

pub fn closed_subpath_survives_whole_when_fully_inside_test() {
  let input = rectangle_subpath(2.0, 2.0, 8.0, 8.0)

  let assert Ok([clipped]) =
    clip.subpath(
      input,
      to: rectangle(0.0, 0.0, 10.0, 10.0),
      using: svg_path.Nonzero,
    )

  assert svg_path.subpath_is_closed(clipped)
  assert svg_path.subpath_segments(clipped) == svg_path.subpath_segments(input)
}

pub fn closed_circle_clips_to_open_arc_fragments_test() {
  let input = circle_subpath(svg_path.Point(0.0, 0.0), 10.0)

  let assert Ok(clipped) =
    clip.subpath(
      input,
      to: rectangle(-20.0, -5.0, 20.0, 5.0),
      using: svg_path.Nonzero,
    )

  assert list.length(clipped) == 2
  assert list.all(clipped, fn(subpath) { !svg_path.subpath_is_closed(subpath) })
  assert list.all(clipped, has_arc)
}

pub fn path_clipping_preserves_subpath_order_test() {
  let input =
    svg_path.Path([
      svg_path.subpath_assert([
        svg_path.Line(
          start: svg_path.Point(-5.0, 2.0),
          end: svg_path.Point(15.0, 2.0),
        ),
      ]),
      svg_path.subpath_assert([
        svg_path.Line(
          start: svg_path.Point(-5.0, 8.0),
          end: svg_path.Point(15.0, 8.0),
        ),
      ]),
    ])

  let assert Ok(clipped) =
    clip.path(
      input,
      to: rectangle(0.0, 0.0, 10.0, 10.0),
      using: svg_path.Nonzero,
    )

  let assert [first, second] = svg_path.path_subpaths(clipped)
  assert_start(first, svg_path.Point(0.0, 2.0))
  assert_start(second, svg_path.Point(0.0, 8.0))
}

fn rectangle(
  min_x: Float,
  min_y: Float,
  max_x: Float,
  max_y: Float,
) -> svg_path.Path {
  svg_path.path_from_subpath(rectangle_subpath(min_x, min_y, max_x, max_y))
}

fn rectangle_subpath(
  min_x: Float,
  min_y: Float,
  max_x: Float,
  max_y: Float,
) -> svg_path.Subpath {
  svg_path.subpath_assert_polygon([
    svg_path.Point(min_x, min_y),
    svg_path.Point(max_x, min_y),
    svg_path.Point(max_x, max_y),
    svg_path.Point(min_x, max_y),
  ])
}

fn circle_subpath(center: svg_path.Point, radius: Float) -> svg_path.Subpath {
  let left = svg_path.Point(center.x -. radius, center.y)
  let right = svg_path.Point(center.x +. radius, center.y)
  svg_path.subpath_assert([
    svg_path.Arc(
      start: right,
      radius: svg_path.Point(radius, radius),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: left,
    ),
    svg_path.Arc(
      start: left,
      radius: svg_path.Point(radius, radius),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: right,
    ),
  ])
  |> svg_path.subpath_assert_set_closed(closed: True)
}

fn has_arc(subpath: svg_path.Subpath) -> Bool {
  subpath
  |> svg_path.subpath_segments
  |> list.any(fn(segment) {
    case segment {
      svg_path.Arc(..) -> True
      _ -> False
    }
  })
}

fn assert_start(subpath: svg_path.Subpath, expected: svg_path.Point) {
  let assert Ok(actual) = svg_path.subpath_start(subpath)
  assert same_point(actual, expected)
}

fn same_point(left: svg_path.Point, right: svg_path.Point) -> Bool {
  float.absolute_value(left.x -. right.x) <=. tolerance
  && float.absolute_value(left.y -. right.y) <=. tolerance
}
