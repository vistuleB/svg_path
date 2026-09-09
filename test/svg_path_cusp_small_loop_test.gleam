import gleam/list
import svg_path
import svg_path/arrangement
import svg_path/offset

fn pair() -> List(svg_path.Segment) {
  [
    svg_path.QuadraticBezier(
      svg_path.Point(0.0, 0.0),
      svg_path.Point(2.0, 3.0),
      svg_path.Point(4.0, 0.0),
    ),
    svg_path.Line(svg_path.Point(4.0, 0.0), svg_path.Point(0.0, 1.0)),
  ]
}

pub fn embedded_culling_selects_only_opposite_reversed_adjacent_loop_test() {
  let assert Ok(build) = arrangement.build_with(pair(), 2.0e-9, 2.0e-9, 0.0001)
  let assert Ok(ids) =
    offset.cusp_small_loop_edges(
      build.graph,
      build.segment_images,
      [True, False],
      False,
    )
  assert list.length(ids) == 2
  assert offset.cusp_small_loop_edges(
      build.graph,
      build.segment_images,
      [False, True],
      False,
    )
    == Ok(ids)
  assert offset.cusp_small_loop_edges(
      build.graph,
      build.segment_images,
      [True, True],
      False,
    )
    == Ok([])
  assert offset.cusp_small_loop_edges(
      build.graph,
      build.segment_images,
      [False, False],
      False,
    )
    == Ok([])
}

pub fn embedded_culling_follows_all_graph_splits_inside_the_loop_test() {
  let segments =
    list.append(pair(), [
      svg_path.Line(svg_path.Point(3.8, -2.0), svg_path.Point(3.8, 3.0)),
    ])
  let assert Ok(build) =
    arrangement.build_with(segments, 2.0e-9, 2.0e-9, 0.0001)
  let assert Ok(ids) =
    offset.cusp_small_loop_edges(
      build.graph,
      list.take(build.segment_images, 2),
      [True, False],
      False,
    )
  assert list.length(ids) == 4
  let assert Ok(extra) = list.last(build.segment_images)
  assert list.all(extra.edges, fn(edge) { !list.contains(ids, edge.edge_id) })
}

pub fn embedded_culling_checks_wraparound_only_for_closed_input_test() {
  let assert Ok(build) =
    arrangement.build_with(list.reverse(pair()), 2.0e-9, 2.0e-9, 0.0001)
  assert offset.cusp_small_loop_edges(
      build.graph,
      build.segment_images,
      [False, True],
      False,
    )
    == Ok([])
  let assert Ok(ids) =
    offset.cusp_small_loop_edges(
      build.graph,
      build.segment_images,
      [False, True],
      True,
    )
  assert list.length(ids) == 2
}

pub fn embedded_culling_ignores_ordinary_shared_endpoint_test() {
  let assert Ok(build) =
    arrangement.build_with(
      [
        svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(2.0, 2.0)),
        svg_path.Line(svg_path.Point(2.0, 2.0), svg_path.Point(4.0, 0.0)),
      ],
      2.0e-9,
      2.0e-9,
      0.0001,
    )
  assert offset.cusp_small_loop_edges(
      build.graph,
      build.segment_images,
      [True, False],
      False,
    )
    == Ok([])
}
