import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleeunit/should
import svg_path
import svg_path/arrangement_graph
import svg_path/arrangement_graph/drawing as arrangement_graph_drawing
import svg_path/csg
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

  let assert Ok(graph) = build_graph([square], tolerance:, minimum_chord:)
  let arrangement_graph.ArrangementGraph(vertices:, edges:) = graph

  list.length(vertices) |> should.equal(4)
  list.length(edges) |> should.equal(4)
  arrangement_graph.validate(graph, tolerance:, minimum_chord:)
  |> should.equal(Ok(Nil))
}

pub fn build_preserves_source_path_grouping_test() {
  let first = svg_path.path_from_subpath(square(0.0, 0.0, 10.0))
  let second =
    svg_path.Path([
      square(20.0, 0.0, 5.0),
      square(30.0, 0.0, 5.0),
    ])

  let assert Ok(arrangement_graph.ArrangementGraphBuild(
    normalized_paths: [normalized_first, normalized_second],
    ..,
  )) = arrangement_graph.build([first, second], tolerance:, minimum_chord:)

  normalized_first
  |> svg_path.path_subpaths
  |> list.length
  |> should.equal(1)
  normalized_second
  |> svg_path.path_subpaths
  |> list.length
  |> should.equal(2)
}

pub fn two_endpoint_samples_use_enclosing_circle_midpoint_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b1 = svg_path.Point(10.0, 0.0)
  let b2 = svg_path.Point(10.0000004, 0.0)
  let c = svg_path.Point(10.0, 10.0)
  let assert Ok(first) =
    arrangement_graph.insert_atomic_segment(
      arrangement_graph.empty(),
      svg_path.Line(start: a, end: b1),
      tolerance:,
      minimum_chord:,
    )
  let assert Ok(graph) =
    arrangement_graph.insert_atomic_segment(
      first,
      svg_path.Line(start: b2, end: c),
      tolerance:,
      minimum_chord:,
    )
  let arrangement_graph.ArrangementGraph(vertices:, ..) = graph
  let assert [
    _,
    arrangement_graph.ArrangementVertex(
      point: joined,
      endpoint_samples: [_, _],
      ..,
    ),
    _,
  ] = vertices

  point.near(joined, svg_path.Point(10.0000002, 0.0), tolerance: 0.000000001)
  |> should.be_true
}

pub fn endpoint_cluster_center_is_independent_of_insertion_order_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(2.0, 0.0)
  let c = svg_path.Point(1.0, 2.0)
  let assert Ok(first) = graph_with_clustered_endpoints([a, b, c], 2.0)
  let assert Ok(second) = graph_with_clustered_endpoints([c, a, b], 2.0)
  let assert arrangement_graph.ArrangementGraph(
    vertices: [
      _,
      arrangement_graph.ArrangementVertex(point: first_center, ..),
      ..
    ],
    ..,
  ) = first
  let assert arrangement_graph.ArrangementGraph(
    vertices: [
      _,
      arrangement_graph.ArrangementVertex(point: second_center, ..),
      ..
    ],
    ..,
  ) = second

  first_center |> should.equal(svg_path.Point(1.0, 0.75))
  second_center |> should.equal(first_center)
}

pub fn exactly_equal_endpoint_samples_preserve_exact_vertex_test() {
  let endpoint = svg_path.Point(1.25, -3.5)
  let assert Ok(graph) =
    graph_with_clustered_endpoints([endpoint, endpoint, endpoint], tolerance)
  let assert arrangement_graph.ArrangementGraph(
    vertices: [
      _,
      arrangement_graph.ArrangementVertex(
        point:,
        endpoint_samples: [_, _, _],
        ..,
      ),
      ..
    ],
    ..,
  ) = graph

  point |> should.equal(endpoint)
}

pub fn validation_rejects_vertex_sample_outside_official_tolerance_test() {
  let graph =
    arrangement_graph.ArrangementGraph(
      vertices: [
        arrangement_graph.ArrangementVertex(
          id: 0,
          point: svg_path.Point(0.0, 0.0),
          endpoint_samples: [
            svg_path.Point(-2.0, 0.0),
            svg_path.Point(2.0, 0.0),
          ],
        ),
      ],
      edges: [],
    )

  arrangement_graph.validate(graph, tolerance: 1.0, minimum_chord:)
  |> should.equal(
    Error(arrangement_graph.VertexSampleOutsideTolerance(
      vertex: 0,
      distance_squared: 4.0,
      tolerance_squared: 1.0,
    )),
  )
}

pub fn validation_rejects_noncanonical_vertex_center_test() {
  let graph =
    arrangement_graph.ArrangementGraph(
      vertices: [
        arrangement_graph.ArrangementVertex(
          id: 0,
          point: svg_path.Point(0.1, 0.0),
          endpoint_samples: [svg_path.Point(0.0, 0.0)],
        ),
      ],
      edges: [],
    )

  let assert Error(arrangement_graph.VertexCenterMismatch(
    vertex: 0,
    distance_squared:,
  )) = arrangement_graph.validate(graph, tolerance: 1.0, minimum_chord:)
  assert float.absolute_value(distance_squared -. 0.01) <. tolerance
}

pub fn validation_rejects_vertex_without_endpoint_samples_test() {
  let graph =
    arrangement_graph.ArrangementGraph(
      vertices: [
        arrangement_graph.ArrangementVertex(
          id: 0,
          point: svg_path.Point(0.0, 0.0),
          endpoint_samples: [],
        ),
      ],
      edges: [],
    )

  arrangement_graph.validate(graph, tolerance:, minimum_chord:)
  |> should.equal(Error(arrangement_graph.VertexWithoutEndpointSamples(0)))
}

pub fn reversed_duplicate_increments_reverse_multiplicity_test() {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let forward = svg_path.Line(start: a, end: b)
  let reverse = svg_path.Line(start: b, end: a)
  let assert Ok(first) =
    arrangement_graph.insert_atomic_segment(
      arrangement_graph.empty(),
      forward,
      tolerance:,
      minimum_chord:,
    )
  let assert Ok(graph) =
    arrangement_graph.insert_atomic_segment(
      first,
      reverse,
      tolerance:,
      minimum_chord:,
    )
  let arrangement_graph.ArrangementGraph(edges:, ..) = graph

  let assert [
    arrangement_graph.ArrangementEdge(
      forward_multiplicity: 1,
      reverse_multiplicity: 1,
      ..,
    ),
  ] = edges
  arrangement_graph.validate(graph, tolerance:, minimum_chord:)
  |> should.equal(Ok(Nil))
}

pub fn open_chain_fails_final_even_degree_invariant_test() {
  let assert Ok(graph) =
    arrangement_graph.insert_atomic_segment(
      arrangement_graph.empty(),
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
      tolerance:,
      minimum_chord:,
    )

  arrangement_graph.validate(graph, tolerance:, minimum_chord:)
  |> should.equal(
    Error(arrangement_graph.OddWeightedDegree(vertex: 0, degree: 1)),
  )
}

pub fn short_chord_is_rejected_test() {
  arrangement_graph.insert_atomic_segment(
    arrangement_graph.empty(),
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(0.000001, 0.0),
    ),
    tolerance:,
    minimum_chord:,
  )
  |> should.equal(
    Error(arrangement_graph.SegmentTooShort(
      chord: 0.000001,
      minimum: minimum_chord,
    )),
  )
}

pub fn drawing_contains_edges_vertices_and_multiplicity_labels_test() {
  let line =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 0.0),
    )
  let assert Ok(graph) =
    arrangement_graph.insert_atomic_segment(
      arrangement_graph.empty(),
      line,
      tolerance:,
      minimum_chord:,
    )

  arrangement_graph_drawing.drawing(graph)
  |> list.length
  |> should.equal(7)
}

pub fn edge_annotation_pose_comes_from_segment_midpoint_and_tangent_test() {
  let edge =
    arrangement_graph.ArrangementEdge(
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

  arrangement_graph_drawing.edge_annotation_pose(edge)
  |> should.equal(
    Ok(arrangement_graph_drawing.EdgeAnnotationPose(
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

  let assert Ok(arrangement_graph.ArrangementGraph(vertices:, edges:)) =
    build_graph([horizontal, vertical], tolerance:, minimum_chord:)

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

  let assert Ok(arrangement_graph.ArrangementGraph(vertices:, edges:)) =
    build_graph([first, second], tolerance:, minimum_chord:)

  list.length(vertices) |> should.equal(4)
  list.length(edges) |> should.equal(3)
  edges
  |> list.filter(fn(edge) {
    let arrangement_graph.ArrangementEdge(forward_multiplicity:, ..) = edge
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
    build_graph([clockwise, counterclockwise], tolerance:, minimum_chord:)
  let arrangement_graph.ArrangementGraph(vertices:, edges:) = graph

  list.length(vertices) |> should.equal(4)
  list.length(edges) |> should.equal(4)
  edges
  |> list.all(fn(edge) {
    let arrangement_graph.ArrangementEdge(
      forward_multiplicity:,
      reverse_multiplicity:,
      ..,
    ) = edge
    forward_multiplicity == 1 && reverse_multiplicity == 1
  })
  |> should.be_true
  arrangement_graph.validate(graph, tolerance:, minimum_chord:)
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
    build_graph(
      [outer, inner_reversed],
      tolerance: graph_tolerance,
      minimum_chord:,
    )
  let arrangement_graph.ArrangementGraph(vertices:, edges:) = graph

  list.length(vertices) |> should.equal(2)
  list.length(edges) |> should.equal(2)
  edges
  |> list.all(fn(edge) {
    let arrangement_graph.ArrangementEdge(
      forward_multiplicity:,
      reverse_multiplicity:,
      ..,
    ) = edge
    forward_multiplicity == 1 && reverse_multiplicity == 1
  })
  |> should.be_true
}

pub fn csg_union_removes_interlocking_square_internal_edges_test() {
  let first = square(0.0, 0.0, 10.0)
  let second = square(5.0, 5.0, 10.0)
  let left = svg_path.path_from_subpath(first)
  let right = svg_path.path_from_subpath(second)
  let assert Ok(csg.CsgResult(path: union, ..)) =
    csg.union(left, right, using: svg_path.Nonzero)

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

pub fn csg_union_does_not_cancel_opposite_operands_test() {
  let clockwise = square(0.0, 0.0, 10.0)
  let counterclockwise = svg_path.subpath_reverse(clockwise)
  let left = svg_path.path_from_subpath(clockwise)
  let right = svg_path.path_from_subpath(counterclockwise)
  let assert Ok(csg.CsgResult(path: union, ..)) =
    csg.union(left, right, using: svg_path.Nonzero)

  list.length(svg_path.path_subpaths(union)) |> should.equal(1)
  svg_path.path_containment(
    svg_path.Point(5.0, 5.0),
    within: union,
    using: svg_path.Nonzero,
  )
  |> should.equal(Ok(svg_path.Inside))
}

pub fn csg_union_applies_requested_fill_rule_test() {
  let contour = square(0.0, 0.0, 10.0)
  let doubled = svg_path.Path([contour, contour])
  let empty = svg_path.path_empty()
  let assert Ok(csg.CsgResult(path: nonzero, ..)) =
    csg.union(doubled, empty, using: svg_path.Nonzero)
  let assert Ok(csg.CsgResult(path: even_odd, ..)) =
    csg.union(doubled, empty, using: svg_path.EvenOdd)

  list.length(svg_path.path_subpaths(nonzero)) |> should.equal(1)
  list.length(svg_path.path_subpaths(even_odd)) |> should.equal(0)
}

pub fn csg_union_pairs_filled_sectors_at_corner_pinch_test() {
  let first = square(0.0, 0.0, 10.0)
  let second = square(10.0, 10.0, 10.0)
  let left = svg_path.path_from_subpath(first)
  let right = svg_path.path_from_subpath(second)
  let assert Ok(csg.CsgResult(path: union, ..)) =
    csg.union(left, right, using: svg_path.Nonzero)

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

fn build_graph(
  subpaths: List(svg_path.Subpath),
  tolerance tolerance: Float,
  minimum_chord minimum_chord: Float,
) -> Result(arrangement_graph.ArrangementGraph, arrangement_graph.Error) {
  arrangement_graph.build([svg_path.Path(subpaths)], tolerance:, minimum_chord:)
  |> result.map(fn(built) {
    let arrangement_graph.ArrangementGraphBuild(graph:, ..) = built
    graph
  })
}

fn graph_with_clustered_endpoints(
  endpoints: List(svg_path.Point),
  cluster_tolerance: Float,
) -> Result(arrangement_graph.ArrangementGraph, arrangement_graph.Error) {
  insert_clustered_endpoints(
    endpoints,
    arrangement_graph.empty(),
    index: 0,
    cluster_tolerance:,
  )
}

fn insert_clustered_endpoints(
  endpoints: List(svg_path.Point),
  graph: arrangement_graph.ArrangementGraph,
  index index: Int,
  cluster_tolerance cluster_tolerance: Float,
) -> Result(arrangement_graph.ArrangementGraph, arrangement_graph.Error) {
  case endpoints {
    [] -> Ok(graph)
    [endpoint, ..rest] -> {
      use graph <- result.try(arrangement_graph.insert_atomic_segment(
        graph,
        svg_path.Line(
          start: svg_path.Point(100.0, int.to_float(index) *. 10.0),
          end: endpoint,
        ),
        tolerance: cluster_tolerance,
        minimum_chord:,
      ))
      insert_clustered_endpoints(
        rest,
        graph,
        index: index + 1,
        cluster_tolerance:,
      )
    }
  }
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
