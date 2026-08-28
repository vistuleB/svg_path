import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleeunit/should
import svg_path
import svg_path/arrangement as arrangement_graph
import svg_path/arrangement/drawing as arrangement_graph_drawing
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
  let arrangement_graph.ArrangementGraph(vertices:, edges:, ..) = graph

  list.length(vertices) |> should.equal(4)
  list.length(edges) |> should.equal(4)
  arrangement_graph.validate(graph, tolerance:, minimum_chord:)
  |> should.equal(Ok(Nil))
}

pub fn cyclic_order_uses_clockwise_common_circle_positions_test() {
  let center = svg_path.Point(0.0, 0.0)
  let rays = [
    svg_path.Line(start: center, end: svg_path.Point(10.0, 0.0)),
    svg_path.Line(start: center, end: svg_path.Point(0.0, 10.0)),
    svg_path.Line(start: center, end: svg_path.Point(-10.0, 0.0)),
    svg_path.Line(start: svg_path.Point(0.0, -10.0), end: center),
  ]
  let assert Ok(arrangement_graph.ArrangementSegmentBuild(graph:, ..)) =
    arrangement_graph.build_with(
      rays,
      vertex_tolerance: tolerance,
      minimum_chord:,
      endpoint_sliver_tolerance: 0.0,
    )
  let assert Ok(order) =
    arrangement_graph.vertex_cyclic_order_with(
      graph,
      vertex_id: 0,
      tolerance:,
      max_attempts: 3,
    )

  order
  |> list.flatten
  |> list.map(fn(oriented_edge) {
    let arrangement_graph.OrientedArrangementEdge(edge_id:, reversed:) =
      oriented_edge
    #(edge_id, reversed)
  })
  |> should.equal([#(0, False), #(1, False), #(2, False), #(3, True)])
}

pub fn cyclic_order_separates_equal_endpoint_tangents_on_circle_test() {
  let center = svg_path.Point(0.0, 0.0)
  let rays = [
    svg_path.QuadraticBezier(
      start: center,
      control: svg_path.Point(5.0, 0.0),
      end: svg_path.Point(10.0, 3.0),
    ),
    svg_path.QuadraticBezier(
      start: center,
      control: svg_path.Point(5.0, 0.0),
      end: svg_path.Point(10.0, -3.0),
    ),
    svg_path.Line(start: center, end: svg_path.Point(-10.0, 0.0)),
  ]
  let assert Ok(arrangement_graph.ArrangementSegmentBuild(graph:, ..)) =
    arrangement_graph.build_with(
      rays,
      vertex_tolerance: tolerance,
      minimum_chord:,
      endpoint_sliver_tolerance: 0.0,
    )
  let assert Ok(order) =
    arrangement_graph.vertex_cyclic_order_with(
      graph,
      vertex_id: 0,
      tolerance:,
      max_attempts: 3,
    )

  order
  |> list.flatten
  |> list.map(fn(oriented_edge) { oriented_edge.edge_id })
  |> should.equal([0, 2, 1])
}

pub fn cyclic_order_groups_circle_points_below_both_separation_limits_test() {
  let center = svg_path.Point(0.0, 0.0)
  let rays = [
    svg_path.Line(start: center, end: svg_path.Point(10.0, 0.0)),
    svg_path.Line(start: center, end: svg_path.Point(10.0, 0.00000001)),
  ]
  let assert Ok(arrangement_graph.ArrangementSegmentBuild(graph:, ..)) =
    arrangement_graph.build_with(
      rays,
      vertex_tolerance: 0.000000001,
      minimum_chord:,
      endpoint_sliver_tolerance: 0.0,
    )
  let assert Ok(groups) =
    arrangement_graph.vertex_cyclic_order_with(
      graph,
      vertex_id: 0,
      tolerance:,
      max_attempts: 3,
    )
  groups
  |> list.map(fn(group) { list.map(group, fn(edge) { edge.edge_id }) })
  |> should.equal([[0, 1]])
}

pub fn cyclic_orders_cover_every_vertex_of_built_square_test() {
  let assert Ok(arrangement_graph.ArrangementGraph(cyclic_orders: orders, ..)) =
    build_graph([square(0.0, 0.0, 10.0)], tolerance:, minimum_chord:)

  list.length(orders) |> should.equal(4)
  orders
  |> list.all(fn(entry) {
    let #(_, order) = entry
    list.length(list.flatten(order)) == 2
  })
  |> should.be_true
}

pub fn build_preserves_source_path_grouping_test() {
  let first = svg_path.subpath_as_path(square(0.0, 0.0, 10.0))
  let second =
    svg_path.Path([
      square(20.0, 0.0, 5.0),
      square(30.0, 0.0, 5.0),
    ])

  let assert Ok(arrangement_graph.ArrangementGraphBuild(segment_images:, ..)) =
    arrangement_graph.build([first, second], tolerance:, minimum_chord:)

  first
  |> svg_path.path_subpaths
  |> list.length
  |> should.equal(1)
  second
  |> svg_path.path_subpaths
  |> list.length
  |> should.equal(2)
  segment_images
  |> list.length
  |> should.equal(12)
}

pub fn segment_images_follow_crossing_source_traversals_test() {
  let horizontal =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])
  let vertical =
    svg_path.subpath_assert_polyline([
      svg_path.Point(5.0, -5.0),
      svg_path.Point(5.0, 5.0),
    ])
  let assert Ok(build) =
    arrangement_graph.build(
      [svg_path.Path([horizontal, vertical])],
      tolerance:,
      minimum_chord:,
    )
  let assert [horizontal_image, vertical_image] = build.segment_images
  let assert Ok(horizontal_edges) =
    arrangement_graph.segment_image_edges(build, horizontal_image)
  let assert Ok(vertical_edges) =
    arrangement_graph.segment_image_edges(build, vertical_image)

  let assert [#(horizontal_first, False), #(horizontal_second, False)] =
    horizontal_edges
  let assert [#(vertical_first, False), #(vertical_second, False)] =
    vertical_edges
  svg_path.segment_start(horizontal_first.segment)
  |> should.equal(svg_path.Point(0.0, 0.0))
  svg_path.segment_end(horizontal_second.segment)
  |> should.equal(svg_path.Point(10.0, 0.0))
  svg_path.segment_start(vertical_first.segment)
  |> should.equal(svg_path.Point(5.0, -5.0))
  svg_path.segment_end(vertical_second.segment)
  |> should.equal(svg_path.Point(5.0, 5.0))
}

pub fn progressive_segment_build_maps_crossing_sources_test() {
  let horizontal =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 0.0),
    )
  let vertical =
    svg_path.Line(
      start: svg_path.Point(5.0, -5.0),
      end: svg_path.Point(5.0, 5.0),
    )

  let assert Ok(arrangement_graph.ArrangementSegmentBuild(
    graph: arrangement_graph.ArrangementGraph(vertices:, edges:, ..),
    segment_images: [
      arrangement_graph.ArrangementSourceSegmentImage(
        segment_index: 0,
        edges: horizontal_edges,
      ),
      arrangement_graph.ArrangementSourceSegmentImage(
        segment_index: 1,
        edges: vertical_edges,
      ),
    ],
    edge_images: edge_images,
    ..,
  )) =
    arrangement_graph.build_with(
      [horizontal, vertical],
      vertex_tolerance: tolerance,
      minimum_chord: minimum_chord,
      endpoint_sliver_tolerance: 0.0,
    )

  list.length(vertices) |> should.equal(5)
  list.length(edges) |> should.equal(4)
  list.length(horizontal_edges) |> should.equal(2)
  list.length(vertical_edges) |> should.equal(2)
  list.length(edge_images) |> should.equal(4)
}

pub fn progressive_segment_build_splits_existing_edges_by_incoming_endpoints_test() {
  assert_near_cross_orders_agree(0.0000000001)
  assert_near_cross_orders_agree(0.0000000004)
}

fn assert_near_cross_orders_agree(gap: Float) {
  let assert Ok(first) =
    arrangement_graph.build_with(
      near_cross_order_1(gap),
      vertex_tolerance: 0.000000001,
      minimum_chord: 0.000000000001,
      endpoint_sliver_tolerance: 0.0,
    )
  let assert Ok(second) =
    arrangement_graph.build_with(
      near_cross_order_2(gap),
      vertex_tolerance: 0.000000001,
      minimum_chord: 0.000000000001,
      endpoint_sliver_tolerance: 0.0,
    )
  let arrangement_graph.ArrangementSegmentBuild(
    graph: arrangement_graph.ArrangementGraph(
      vertices: first_vertices,
      edges: first_edges,
      ..,
    ),
    ..,
  ) = first
  let arrangement_graph.ArrangementSegmentBuild(
    graph: arrangement_graph.ArrangementGraph(
      vertices: second_vertices,
      edges: second_edges,
      ..,
    ),
    ..,
  ) = second

  list.length(first_vertices) |> should.equal(5)
  list.length(second_vertices) |> should.equal(5)
  list.length(first_edges) |> should.equal(4)
  list.length(second_edges) |> should.equal(4)
}

fn near_cross_order_1(gap: Float) -> List(svg_path.Segment) {
  [
    near_cross_vertical(),
    near_cross_left(gap),
    near_cross_right(gap),
  ]
}

fn near_cross_order_2(gap: Float) -> List(svg_path.Segment) {
  [
    near_cross_left(gap),
    near_cross_right(gap),
    near_cross_vertical(),
  ]
}

fn near_cross_vertical() -> svg_path.Segment {
  svg_path.Line(start: svg_path.Point(1.0, 2.0), end: svg_path.Point(1.0, 0.0))
}

fn near_cross_left(gap: Float) -> svg_path.Segment {
  svg_path.Line(
    start: svg_path.Point(0.0, 1.0),
    end: svg_path.Point(1.0 -. gap, 1.0),
  )
}

fn near_cross_right(gap: Float) -> svg_path.Segment {
  svg_path.Line(
    start: svg_path.Point(1.0 +. gap, 1.0),
    end: svg_path.Point(2.0, 1.0),
  )
}

pub fn segment_images_share_coincident_edges_with_source_orientation_test() {
  let forward =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])
  let reverse =
    svg_path.subpath_assert_polyline([
      svg_path.Point(10.0, 0.0),
      svg_path.Point(0.0, 0.0),
    ])
  let assert Ok(build) =
    arrangement_graph.build(
      [svg_path.Path([forward, reverse])],
      tolerance:,
      minimum_chord:,
    )
  let assert [forward_image, reverse_image] = build.segment_images
  let assert arrangement_graph.ArrangementSegmentImage(
    edges: [
      arrangement_graph.DirectedEdgeReference(
        edge_id: forward_id,
        reversed: False,
      ),
    ],
    ..,
  ) = forward_image
  let assert arrangement_graph.ArrangementSegmentImage(
    edges: [
      arrangement_graph.DirectedEdgeReference(
        edge_id: reverse_id,
        reversed: True,
      ),
    ],
    ..,
  ) = reverse_image

  forward_id |> should.equal(reverse_id)
}

pub fn segment_images_map_different_source_decompositions_to_shared_edges_test() {
  let whole =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])
  let divided =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(5.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])
  let assert Ok(build) =
    arrangement_graph.build(
      [svg_path.Path([whole, divided])],
      tolerance:,
      minimum_chord:,
    )
  let assert [whole_image, divided_first_image, divided_second_image] =
    build.segment_images
  let assert arrangement_graph.ArrangementSegmentImage(
    path_index: 0,
    subpath_index: 0,
    segment_index: 0,
    edges: [whole_first, whole_second],
  ) = whole_image
  let assert arrangement_graph.ArrangementSegmentImage(
    path_index: 0,
    subpath_index: 1,
    segment_index: 0,
    edges: [divided_first],
  ) = divided_first_image
  let assert arrangement_graph.ArrangementSegmentImage(
    path_index: 0,
    subpath_index: 1,
    segment_index: 1,
    edges: [divided_second],
  ) = divided_second_image

  whole_first |> should.equal(divided_first)
  whole_second |> should.equal(divided_second)
}

pub fn build_rejects_invalid_tolerance_before_inspecting_sources_test() {
  arrangement_graph.build([], tolerance: 0.0, minimum_chord:)
  |> should.equal(Error(arrangement_graph.InvalidTolerance(0.0)))
}

pub fn build_rejects_invalid_minimum_chord_before_inspecting_sources_test() {
  arrangement_graph.build([], tolerance:, minimum_chord: 0.0)
  |> should.equal(Error(arrangement_graph.InvalidMinimumChord(0.0)))
}

pub fn validation_rejects_invalid_numeric_options_test() {
  arrangement_graph.validate(
    arrangement_graph.ArrangementGraph(
      vertices: [],
      edges: [],
      cyclic_orders: [],
    ),
    tolerance:,
    minimum_chord: 0.0,
  )
  |> should.equal(Error(arrangement_graph.InvalidMinimumChord(0.0)))
}

pub fn insertion_reports_tolerance_cluster_collapse_test() {
  arrangement_graph.insert_atomic_segment(
    arrangement_graph.empty(),
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(0.5, 0.0),
    ),
    tolerance: 1.0,
    minimum_chord: 0.1,
  )
  |> should.equal(Error(arrangement_graph.SegmentCollapsedToVertex(vertex: 0)))
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
      cyclic_orders: [],
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
      cyclic_orders: [],
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
      cyclic_orders: [],
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
    test_edge(
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

pub fn edge_annotation_pose_uses_incoming_direction_at_stationary_reversal_test() {
  let edge =
    test_edge(
      id: 0,
      segment: svg_path.QuadraticBezier(
        start: svg_path.Point(1.0, 0.0),
        control: svg_path.Point(-1.0, 0.0),
        end: svg_path.Point(1.0, 0.0),
      ),
      start_vertex: 0,
      end_vertex: 1,
      forward_multiplicity: 1,
      reverse_multiplicity: 0,
    )

  arrangement_graph_drawing.edge_annotation_pose(edge)
  |> should.equal(
    Ok(arrangement_graph_drawing.EdgeAnnotationPose(
      point: svg_path.Point(0.0, 0.0),
      rotation: 270.0,
    )),
  )
}

pub fn edge_annotation_pose_rejects_directionless_segment_test() {
  let point = svg_path.Point(1.0, 2.0)
  let edge =
    test_edge(
      id: 0,
      segment: svg_path.Line(start: point, end: point),
      start_vertex: 0,
      end_vertex: 0,
      forward_multiplicity: 1,
      reverse_multiplicity: 0,
    )

  arrangement_graph_drawing.edge_annotation_pose(edge)
  |> should.equal(Error(svg_path.IndeterminateDirection))
}

fn test_edge(
  id id: Int,
  segment segment: svg_path.Segment,
  start_vertex start_vertex: Int,
  end_vertex end_vertex: Int,
  forward_multiplicity forward_multiplicity: Int,
  reverse_multiplicity reverse_multiplicity: Int,
) -> arrangement_graph.ArrangementEdge {
  let assert Ok(bounds) = svg_path.segment_bounding_box(segment)
  arrangement_graph.ArrangementEdge(
    id:,
    segment:,
    bounds:,
    start_vertex:,
    end_vertex:,
    forward_multiplicity:,
    reverse_multiplicity:,
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

  let assert Ok(arrangement_graph.ArrangementGraph(vertices:, edges:, ..)) =
    build_graph([horizontal, vertical], tolerance:, minimum_chord:)

  list.length(vertices) |> should.equal(5)
  list.length(edges) |> should.equal(4)
}

pub fn builder_keeps_geometrically_distinct_cuts_on_long_segment_test() {
  let horizontal =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10_000.0, 0.0),
      ),
    ])
  let first =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(5000.0, -10.0),
        end: svg_path.Point(5000.0, 10.0),
      ),
    ])
  let second =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(5005.0, -10.0),
        end: svg_path.Point(5005.0, 10.0),
      ),
    ])

  let assert Ok(arrangement_graph.ArrangementGraph(vertices:, edges:, ..)) =
    build_graph([horizontal, first, second], tolerance: 0.001, minimum_chord:)

  list.length(vertices) |> should.equal(8)
  list.length(edges) |> should.equal(7)
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

  let assert Ok(arrangement_graph.ArrangementGraph(vertices:, edges:, ..)) =
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
  let arrangement_graph.ArrangementGraph(vertices:, edges:, ..) = graph

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
  let arrangement_graph.ArrangementGraph(vertices:, edges:, ..) = graph

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
  let left = svg_path.subpath_as_path(first)
  let right = svg_path.subpath_as_path(second)
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
  let left = svg_path.subpath_as_path(clockwise)
  let right = svg_path.subpath_as_path(counterclockwise)
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
  let left = svg_path.subpath_as_path(first)
  let right = svg_path.subpath_as_path(second)
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

pub fn subpath_direction_arrows_draws_one_arrow_per_segment_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
    ])

  subpath
  |> arrangement_graph_drawing.subpath_direction_arrows("red")
  |> list.length
  |> should.equal(2)
}

pub fn segment_direction_arrow_recovers_collapsed_cubic_endpoint_test() {
  let end = svg_path.Point(10.0, 10.0)
  let segment =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(0.0, 10.0),
      control2: end,
      end:,
    )

  arrangement_graph_drawing.segment_direction_arrow(segment, "red")
  |> should.be_ok
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
