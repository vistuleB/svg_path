//// Compile-only smoke coverage for the package's arrangement and CSG API.

import svg_path
import svg_path/arrangement
import svg_path/csg
import svg_path/intersections
import svg_path/overlaps

pub fn main() -> Nil {
  let left = rectangle(0.0, 0.0, 10.0, 10.0)
  let right = rectangle(5.0, 0.0, 15.0, 10.0)

  let assert Ok(build) =
    arrangement.build(
      [left, right],
      tolerance: 0.000001,
      minimum_chord: 0.00001,
    )
  let arrangement.ArrangementGraphBuild(
    graph:,
    normalized_paths:,
    segment_images:,
  ) = build
  let _ = graph
  let _ = normalized_paths
  let _ = segment_images

  let assert Ok(union) = csg.union(left, right, using: svg_path.Nonzero)
  let _ = union.path
  let _ = union.build
  let _ = csg.intersection(left, right, using: svg_path.Nonzero)
  let _ = csg.difference(left, minus: right, using: svg_path.Nonzero)
  let _ = csg.symmetric_difference(left, right, using: svg_path.EvenOdd)
  let _ = csg.nested_contours(svg_path.path_combine([left, right]))

  let horizontal =
    svg_path.Line(
      start: svg_path.Point(0.0, 5.0),
      end: svg_path.Point(10.0, 5.0),
    )
  let vertical =
    svg_path.Line(
      start: svg_path.Point(5.0, 0.0),
      end: svg_path.Point(5.0, 10.0),
    )
  let _ = intersections.segment(horizontal, vertical)
  let _ = overlaps.segment(horizontal, horizontal)
  let _ = svg_path.segment_as_subpath(horizontal)
  let _ = svg_path.segment_as_path(vertical)

  Nil
}

fn rectangle(
  min_x: Float,
  min_y: Float,
  max_x: Float,
  max_y: Float,
) -> svg_path.Path {
  let a = svg_path.Point(min_x, min_y)
  let b = svg_path.Point(max_x, min_y)
  let c = svg_path.Point(max_x, max_y)
  let d = svg_path.Point(min_x, max_y)
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
      svg_path.Line(start: d, end: a),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)
  svg_path.subpath_as_path(subpath)
}
