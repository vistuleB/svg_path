import gleam/list
import gleeunit/should
import svg_path
import svg_path/planar_graph
import svg_path/point

const tolerance = 0.000001

const minimum_chord = 0.00001

pub fn closed_square_builds_valid_graph_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(10.0, 10.0)
  let d = svg_path.Point(0.0, 10.0)
  let square =
    closed_subpath([
      svg_path.Line(start: a, end: b),
      svg_path.Line(start: b, end: c),
      svg_path.Line(start: c, end: d),
      svg_path.Line(start: d, end: a),
    ])

  let assert Ok(graph) =
    planar_graph.from_noded_subpaths([square], tolerance:, minimum_chord:)
  let planar_graph.ArrangementGraph(vertices:, edges:) = graph

  list.length(vertices) |> should.equal(4)
  list.length(edges) |> should.equal(4)
  planar_graph.validate(graph, tolerance:, minimum_chord:)
  |> should.equal(Ok(Nil))
}

pub fn endpoint_samples_are_averaged_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b1 = svg_path.Point(10.0, 0.0)
  let b2 = svg_path.Point(10.0000004, 0.0)
  let c = svg_path.Point(10.0, 10.0)
  let assert Ok(first) =
    planar_graph.insert_noded_segment(
      planar_graph.empty(),
      svg_path.Line(start: a, end: b1),
      tolerance:,
      minimum_chord:,
    )
  let assert Ok(graph) =
    planar_graph.insert_noded_segment(
      first,
      svg_path.Line(start: b2, end: c),
      tolerance:,
      minimum_chord:,
    )
  let planar_graph.ArrangementGraph(vertices:, ..) = graph
  let assert [
    _,
    planar_graph.ArrangementVertex(point: joined, sample_count: 2, ..),
    _,
  ] = vertices

  point.near(joined, svg_path.Point(10.0000002, 0.0), tolerance: 0.000000001)
  |> should.be_true
}

pub fn reversed_duplicate_increments_reverse_multiplicity_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let forward = svg_path.Line(start: a, end: b)
  let reverse = svg_path.Line(start: b, end: a)
  let assert Ok(first) =
    planar_graph.insert_noded_segment(
      planar_graph.empty(),
      forward,
      tolerance:,
      minimum_chord:,
    )
  let assert Ok(graph) =
    planar_graph.insert_noded_segment(
      first,
      reverse,
      tolerance:,
      minimum_chord:,
    )
  let planar_graph.ArrangementGraph(edges:, ..) = graph

  let assert [
    planar_graph.ArrangementEdge(
      forward_multiplicity: 1,
      reverse_multiplicity: 1,
      ..,
    ),
  ] = edges
  planar_graph.validate(graph, tolerance:, minimum_chord:)
  |> should.equal(Ok(Nil))
}

pub fn open_chain_fails_final_even_degree_invariant_test() {
  let assert Ok(graph) =
    planar_graph.insert_noded_segment(
      planar_graph.empty(),
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
      tolerance:,
      minimum_chord:,
    )

  planar_graph.validate(graph, tolerance:, minimum_chord:)
  |> should.equal(Error(planar_graph.OddWeightedDegree(vertex: 0, degree: 1)))
}

pub fn short_chord_is_rejected_test() {
  planar_graph.insert_noded_segment(
    planar_graph.empty(),
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(0.000001, 0.0),
    ),
    tolerance:,
    minimum_chord:,
  )
  |> should.equal(
    Error(planar_graph.SegmentTooShort(chord: 0.000001, minimum: minimum_chord)),
  )
}

pub fn drawing_contains_edges_vertices_and_multiplicity_labels_test() {
  let line =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 0.0),
    )
  let assert Ok(graph) =
    planar_graph.insert_noded_segment(
      planar_graph.empty(),
      line,
      tolerance:,
      minimum_chord:,
    )

  planar_graph.things_to_draw(graph)
  |> list.length
  |> should.equal(7)
}

pub fn edge_annotation_pose_comes_from_segment_midpoint_and_tangent_test() {
  let edge =
    planar_graph.ArrangementEdge(
      id: 0,
      segment: svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
      start_vertex: 0,
      end_vertex: 1,
      forward_multiplicity: 1,
      reverse_multiplicity: 0,
    )

  planar_graph.edge_annotation_pose(edge)
  |> should.equal(
    Ok(planar_graph.EdgeAnnotationPose(
      point: svg_path.Point(5.0, 0.0),
      rotation: 90.0,
    )),
  )
}

pub fn builder_splits_crossing_lines_at_shared_vertex_test() {
  let horizontal =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(-10.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
    ])
  let vertical =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, -10.0),
        end: svg_path.Point(0.0, 10.0),
      ),
    ])

  let assert Ok(planar_graph.ArrangementGraph(vertices:, edges:)) =
    planar_graph.from_subpaths(
      [horizontal, vertical],
      tolerance:,
      minimum_chord:,
    )

  list.length(vertices) |> should.equal(5)
  list.length(edges) |> should.equal(4)
}

pub fn builder_refines_partial_line_overlap_and_counts_middle_test() {
  let first =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
    ])
  let second =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(5.0, 0.0),
        end: svg_path.Point(15.0, 0.0),
      ),
    ])

  let assert Ok(planar_graph.ArrangementGraph(vertices:, edges:)) =
    planar_graph.from_subpaths([first, second], tolerance:, minimum_chord:)

  list.length(vertices) |> should.equal(4)
  list.length(edges) |> should.equal(3)
  edges
  |> list.filter(fn(edge) {
    let planar_graph.ArrangementEdge(forward_multiplicity:, ..) = edge
    forward_multiplicity == 2
  })
  |> list.length
  |> should.equal(1)
}

pub fn builder_consolidates_phase_shifted_opposite_circle_arcs_test() {
  let radius = svg_path.Point(10.0, 10.0)
  let east = svg_path.Point(10.0, 0.0)
  let west = svg_path.Point(-10.0, 0.0)
  let southeast = svg_path.Point(7.0710678118654755, 7.0710678118654755)
  let northwest = svg_path.Point(-7.0710678118654755, -7.0710678118654755)
  let clockwise =
    closed_subpath([
      svg_path.Arc(
        start: east,
        radius:,
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: west,
      ),
      svg_path.Arc(
        start: west,
        radius:,
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: east,
      ),
    ])
  let counterclockwise =
    closed_subpath([
      svg_path.Arc(
        start: southeast,
        radius:,
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: False,
        end: northwest,
      ),
      svg_path.Arc(
        start: northwest,
        radius:,
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: False,
        end: southeast,
      ),
    ])

  let assert Ok(graph) =
    planar_graph.from_subpaths(
      [clockwise, counterclockwise],
      tolerance:,
      minimum_chord:,
    )
  let planar_graph.ArrangementGraph(vertices:, edges:) = graph

  list.length(vertices) |> should.equal(4)
  list.length(edges) |> should.equal(4)
  edges
  |> list.all(fn(edge) {
    let planar_graph.ArrangementEdge(
      forward_multiplicity:,
      reverse_multiplicity:,
      ..,
    ) = edge
    forward_multiplicity == 1 && reverse_multiplicity == 1
  })
  |> should.be_true
  planar_graph.validate(graph, tolerance:, minimum_chord:)
  |> should.equal(Ok(Nil))
}

pub fn builder_consolidates_near_equal_circles_inside_tolerance_test() {
  let graph_tolerance = 0.0001
  let east = svg_path.Point(10.0, 0.0)
  let west = svg_path.Point(-10.0, 0.0)
  let inner_east = svg_path.Point(9.99996, 0.0)
  let inner_west = svg_path.Point(-9.99996, 0.0)
  let outer =
    closed_subpath([
      svg_path.Arc(
        start: east,
        radius: svg_path.Point(10.0, 10.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: west,
      ),
      svg_path.Arc(
        start: west,
        radius: svg_path.Point(10.0, 10.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: east,
      ),
    ])
  let inner_reversed =
    closed_subpath([
      svg_path.Arc(
        start: inner_east,
        radius: svg_path.Point(9.99996, 9.99996),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: False,
        end: inner_west,
      ),
      svg_path.Arc(
        start: inner_west,
        radius: svg_path.Point(9.99996, 9.99996),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: False,
        end: inner_east,
      ),
    ])

  let assert Ok(graph) =
    planar_graph.from_subpaths(
      [outer, inner_reversed],
      tolerance: graph_tolerance,
      minimum_chord:,
    )
  let planar_graph.ArrangementGraph(vertices:, edges:) = graph

  list.length(vertices) |> should.equal(2)
  list.length(edges) |> should.equal(2)
  edges
  |> list.all(fn(edge) {
    let planar_graph.ArrangementEdge(
      forward_multiplicity:,
      reverse_multiplicity:,
      ..,
    ) = edge
    forward_multiplicity == 1 && reverse_multiplicity == 1
  })
  |> should.be_true
}

pub fn union_from_arrangement_graph_removes_interlocking_square_internal_edges_test() {
  let first = square(0.0, 0.0, 10.0)
  let second = square(5.0, 5.0, 10.0)
  let left = svg_path.path_from_subpath(first)
  let right = svg_path.path_from_subpath(second)
  let assert Ok(graph) =
    planar_graph.from_subpaths([first, second], tolerance:, minimum_chord:)
  let assert Ok(union) =
    planar_graph.union_from_arrangement_graph(
      graph,
      left,
      right,
      using: svg_path.Nonzero,
      tolerance:,
    )

  list.length(svg_path.path_subpaths(union)) |> should.equal(1)
  svg_path.path_containment(
    svg_path.Point(2.0, 2.0),
    within: union,
    using: svg_path.Nonzero,
  )
  |> should.equal(Ok(svg_path.Inside))
  svg_path.path_containment(
    svg_path.Point(7.0, 7.0),
    within: union,
    using: svg_path.Nonzero,
  )
  |> should.equal(Ok(svg_path.Inside))
  svg_path.path_containment(
    svg_path.Point(13.0, 13.0),
    within: union,
    using: svg_path.Nonzero,
  )
  |> should.equal(Ok(svg_path.Inside))
  svg_path.path_containment(
    svg_path.Point(2.0, 13.0),
    within: union,
    using: svg_path.Nonzero,
  )
  |> should.equal(Ok(svg_path.Outside))
}

pub fn union_from_arrangement_graph_does_not_cancel_opposite_operands_test() {
  let clockwise = square(0.0, 0.0, 10.0)
  let counterclockwise = svg_path.subpath_reverse(clockwise)
  let left = svg_path.path_from_subpath(clockwise)
  let right = svg_path.path_from_subpath(counterclockwise)
  let assert Ok(graph) =
    planar_graph.from_subpaths(
      [clockwise, counterclockwise],
      tolerance:,
      minimum_chord:,
    )
  let assert Ok(union) =
    planar_graph.union_from_arrangement_graph(
      graph,
      left,
      right,
      using: svg_path.Nonzero,
      tolerance:,
    )

  list.length(svg_path.path_subpaths(union)) |> should.equal(1)
  svg_path.path_containment(
    svg_path.Point(5.0, 5.0),
    within: union,
    using: svg_path.Nonzero,
  )
  |> should.equal(Ok(svg_path.Inside))
}

pub fn union_from_arrangement_graph_applies_requested_fill_rule_test() {
  let contour = square(0.0, 0.0, 10.0)
  let doubled = svg_path.Path([contour, contour])
  let empty = svg_path.path_empty()
  let assert Ok(graph) =
    planar_graph.from_subpaths([contour, contour], tolerance:, minimum_chord:)
  let assert Ok(nonzero) =
    planar_graph.union_from_arrangement_graph(
      graph,
      doubled,
      empty,
      using: svg_path.Nonzero,
      tolerance:,
    )
  let assert Ok(even_odd) =
    planar_graph.union_from_arrangement_graph(
      graph,
      doubled,
      empty,
      using: svg_path.EvenOdd,
      tolerance:,
    )

  list.length(svg_path.path_subpaths(nonzero)) |> should.equal(1)
  list.length(svg_path.path_subpaths(even_odd)) |> should.equal(0)
}

pub fn union_from_arrangement_graph_pairs_filled_sectors_at_corner_pinch_test() {
  let first = square(0.0, 0.0, 10.0)
  let second = square(10.0, 10.0, 10.0)
  let left = svg_path.path_from_subpath(first)
  let right = svg_path.path_from_subpath(second)
  let assert Ok(graph) =
    planar_graph.from_subpaths([first, second], tolerance:, minimum_chord:)
  let assert Ok(union) =
    planar_graph.union_from_arrangement_graph(
      graph,
      left,
      right,
      using: svg_path.Nonzero,
      tolerance:,
    )

  list.length(svg_path.path_subpaths(union)) |> should.equal(2)
  svg_path.path_containment(
    svg_path.Point(5.0, 5.0),
    within: union,
    using: svg_path.Nonzero,
  )
  |> should.equal(Ok(svg_path.Inside))
  svg_path.path_containment(
    svg_path.Point(15.0, 15.0),
    within: union,
    using: svg_path.Nonzero,
  )
  |> should.equal(Ok(svg_path.Inside))
}

fn closed_subpath(segments: List(svg_path.Segment)) -> svg_path.Subpath {
  svg_path.subpath_assert(segments)
  |> svg_path.subpath_assert_set_closed(closed: True)
}

fn square(x: Float, y: Float, side: Float) -> svg_path.Subpath {
  let a = svg_path.Point(x, y)
  let b = svg_path.Point(x +. side, y)
  let c = svg_path.Point(x +. side, y +. side)
  let d = svg_path.Point(x, y +. side)
  closed_subpath([
    svg_path.Line(start: a, end: b),
    svg_path.Line(start: b, end: c),
    svg_path.Line(start: c, end: d),
    svg_path.Line(start: d, end: a),
  ])
}
