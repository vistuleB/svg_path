import gleam/int
import gleam/list
import gleam/result
import gleeunit/should
import svg_path
import svg_path/arrangement as arrangement_graph
import svg_path/arrangement/drawing as arrangement_graph_drawing
import svg_path/csg
import svg_path/point
import svg_path/svg

const tolerance = 0.000001

const minimum_chord = 0.00001

fn self_crossing_cubic() -> svg_path.Segment {
  svg_path.CubicBezier(
    start: svg_path.Point(0.0, -0.09375),
    control1: svg_path.Point(-1.0 /. 3.0, 0.13541666666666666),
    control2: svg_path.Point(-1.0 /. 3.0, -0.13541666666666666),
    end: svg_path.Point(0.0, 0.09375),
  )
}

fn closed_cubic() -> svg_path.Segment {
  svg_path.CubicBezier(
    start: svg_path.Point(0.0, 0.0),
    control1: svg_path.Point(2.0, 2.0),
    control2: svg_path.Point(-2.0, 2.0),
    end: svg_path.Point(0.0, 0.0),
  )
}

fn build_loop_fixture(
  segments: List(svg_path.Segment),
) -> arrangement_graph.ArrangementGraph {
  let assert Ok(arrangement_graph.ArrangementSegmentBuild(graph:, ..)) =
    arrangement_graph.build_with(
      segments,
      vertex_tolerance: 0.000000001,
      minimum_chord: 0.00000001,
      endpoint_sliver_tolerance: 0.0,
    )
  assert list.all(graph.edges, fn(edge) { edge.start_vertex != edge.end_vertex })
  graph
}

pub fn closed_cubic_is_split_instead_of_discarded_test() {
  let graph = build_loop_fixture([closed_cubic()])
  assert list.length(graph.vertices) == 2
  assert list.length(graph.edges) == 2
}

pub fn closed_cubic_source_intervals_preserve_final_endpoint_test() {
  let assert Ok(build) =
    arrangement_graph.build_with(
      [closed_cubic()],
      vertex_tolerance: 0.000000001,
      minimum_chord: 0.00000001,
      endpoint_sliver_tolerance: 0.0,
    )
  let assert [image] = build.segment_images
  assert list.map(image.edges, fn(edge) { #(edge.ta, edge.tb) })
    == [#(0.0, 0.5), #(0.5, 1.0)]
}

pub fn self_crossing_source_intervals_preserve_each_occurrence_test() {
  let source = self_crossing_cubic()
  let assert Ok(build) =
    arrangement_graph.build_with(
      [source],
      vertex_tolerance: 0.000000001,
      minimum_chord: 0.00000001,
      endpoint_sliver_tolerance: 0.0,
    )
  let assert [image] = build.segment_images
  assert_image_intervals(source, build.graph, image.edges, 0.0)
}

pub fn repeated_graph_edge_splits_compose_reverse_source_intervals_test() {
  let source =
    svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(10.0, 0.0))
  let reverse = svg_path.segment_reverse(source)
  let assert Ok(build) =
    arrangement_graph.build_with(
      [
        source,
        reverse,
        svg_path.Line(svg_path.Point(3.0, -1.0), svg_path.Point(3.0, 1.0)),
        svg_path.Line(svg_path.Point(7.0, -1.0), svg_path.Point(7.0, 1.0)),
      ],
      vertex_tolerance: 0.000000001,
      minimum_chord: 0.00000001,
      endpoint_sliver_tolerance: 0.0,
    )
  let assert [forward_image, reverse_image, ..] = build.segment_images
  assert list.length(forward_image.edges) == 3
  assert list.length(reverse_image.edges) == 3
  assert_image_intervals(source, build.graph, forward_image.edges, 0.0)
  assert_image_intervals(reverse, build.graph, reverse_image.edges, 0.0)
}

pub fn closed_curve_duplicate_intervals_survive_later_graph_cuts_test() {
  let source = closed_cubic()
  let reverse = svg_path.segment_reverse(source)
  let assert Ok(build) =
    arrangement_graph.build_with(
      [
        source,
        reverse,
        svg_path.Line(svg_path.Point(-2.0, 0.75), svg_path.Point(2.0, 0.75)),
        svg_path.Line(svg_path.Point(-2.0, 1.0), svg_path.Point(2.0, 1.0)),
      ],
      vertex_tolerance: 0.000000001,
      minimum_chord: 0.00000001,
      endpoint_sliver_tolerance: 0.0,
    )
  let assert [forward_image, reverse_image, ..] = build.segment_images
  assert list.length(forward_image.edges) == 6
  assert list.length(reverse_image.edges) == 6
  assert_image_intervals(source, build.graph, forward_image.edges, 0.0)
  assert_image_intervals(reverse, build.graph, reverse_image.edges, 0.0)
}

fn assert_image_intervals(
  source: svg_path.Segment,
  graph: arrangement_graph.ArrangementGraph,
  images: List(arrangement_graph.ArrangementSegmentEdgeImage),
  previous: Float,
) {
  case images {
    [] -> {
      assert previous == 1.0
    }
    [image, ..rest] -> {
      assert image.ta == previous
      assert image.tb >. image.ta
      let assert Ok(edge) =
        list.find(graph.edges, fn(edge) { edge.id == image.edge_id })
      list.each([0.0, 0.5, 1.0], fn(t) {
        let source_t = case t {
          0.0 -> image.ta
          1.0 -> image.tb
          _ -> image.ta +. t *. { image.tb -. image.ta }
        }
        let assert Ok(expected) = svg_path.segment_point(source, at: source_t)
        let edge_t = case image.reversed {
          True -> 1.0 -. t
          False -> t
        }
        let assert Ok(actual) = svg_path.segment_point(edge.segment, at: edge_t)
        assert point.distance(expected, actual) <. 0.00000001
      })
      assert_image_intervals(source, graph, rest, image.tb)
    }
  }
}

pub fn self_crossing_cubic_is_noded_and_its_loop_preserved_test() {
  let graph = build_loop_fixture([self_crossing_cubic()])
  assert list.length(graph.vertices) == 4
  assert list.length(graph.edges) == 4
  assert list.any(graph.vertices, fn(vertex) {
    point.distance(vertex.point, svg_path.Point(-0.1875, 0.0)) <. 0.000000001
  })
}

pub fn preexisting_cuts_do_not_hide_same_source_self_crossing_test() {
  let cutter =
    svg_path.Line(
      start: svg_path.Point(-0.24, -1.0),
      end: svg_path.Point(-0.24, 1.0),
    )
  let graph = build_loop_fixture([cutter, self_crossing_cubic()])
  assert list.any(graph.vertices, fn(vertex) {
    point.distance(vertex.point, svg_path.Point(-0.1875, 0.0)) <. 0.000000001
  })
}

pub fn externally_cut_closed_cubic_needs_no_extra_midpoint_test() {
  let cutter =
    svg_path.Line(
      start: svg_path.Point(-2.0, 0.75),
      end: svg_path.Point(2.0, 0.75),
    )
  let graph = build_loop_fixture([cutter, closed_cubic()])
  assert list.length(graph.vertices) == 5
  assert list.length(graph.edges) == 6
}

pub fn shared_endpoints_do_not_hide_an_interior_crossing_test() {
  let start = svg_path.Point(0.0, 0.0)
  let end = svg_path.Point(1.0, 0.0)
  let curve =
    svg_path.CubicBezier(
      start:,
      control1: svg_path.Point(1.0 /. 3.0, 1.0 /. 6.0),
      control2: svg_path.Point(2.0 /. 3.0, -1.0 /. 6.0),
      end:,
    )
  let line = svg_path.Line(start:, end:)
  list.each([line, svg_path.segment_reverse(line)], fn(line) {
    list.each([[curve, line], [line, curve]], fn(segments) {
      let assert Ok(arrangement_graph.ArrangementSegmentBuild(graph:, ..)) =
        arrangement_graph.build_with(
          segments,
          vertex_tolerance: 0.000000001,
          minimum_chord: 0.00000001,
          endpoint_sliver_tolerance: 0.0,
        )
      assert list.length(graph.vertices) == 3
      assert list.length(graph.edges) == 4
      assert list.any(graph.vertices, fn(vertex) {
        point.distance(vertex.point, svg_path.Point(0.5, 0.0)) <. 0.000000001
      })
      assert arrangement_graph.validate(
          graph,
          tolerance: 0.000000001,
          minimum_chord: 0.00000001,
        )
        == Ok(Nil)
    })
  })
}

pub fn shared_endpoint_lens_keeps_distinct_edges_test() {
  let start = svg_path.Point(0.0, 0.0)
  let end = svg_path.Point(2.0, 0.0)
  let assert Ok(arrangement_graph.ArrangementSegmentBuild(graph:, ..)) =
    arrangement_graph.build_with(
      [
        svg_path.QuadraticBezier(
          start:,
          control: svg_path.Point(1.0, 1.0),
          end:,
        ),
        svg_path.QuadraticBezier(
          start:,
          control: svg_path.Point(1.0, -1.0),
          end:,
        ),
      ],
      vertex_tolerance: tolerance,
      minimum_chord:,
      endpoint_sliver_tolerance: 0.0,
    )
  assert list.length(graph.vertices) == 2
  assert list.length(graph.edges) == 2
}

pub fn progressive_duplicate_curves_preserve_directional_multiplicity_test() {
  let curve =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.0),
      control: svg_path.Point(1.0, 1.0),
      end: svg_path.Point(2.0, 0.0),
    )
  let assert Ok(arrangement_graph.ArrangementSegmentBuild(graph:, ..)) =
    arrangement_graph.build_with(
      [curve, curve, svg_path.segment_reverse(curve)],
      vertex_tolerance: tolerance,
      minimum_chord:,
      endpoint_sliver_tolerance: 0.0,
    )
  let assert [edge] = graph.edges
  assert list.length(graph.vertices) == 2
  assert edge.forward_multiplicity == 2
  assert edge.reverse_multiplicity == 1
}

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

pub fn coincident_arc_cut_parameters_do_not_create_degenerate_arcs_test() {
  let left = svg_path.Point(378.75, 132.0)
  let right = svg_path.Point(513.75, 132.0)
  let circle =
    closed_subpath([
      svg_path.Arc(
        start: right,
        radius: svg_path.Point(67.5, 67.5),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: left,
      ),
      svg_path.Arc(
        start: left,
        radius: svg_path.Point(67.5, 67.5),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: True,
        end: right,
      ),
    ])
  let cutter = rectangle(431.25, 57.0, 90.0, 150.0)

  let assert Ok(graph) =
    build_graph([circle, cutter], tolerance:, minimum_chord:)
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

pub fn dual_square_has_infinite_and_bounded_faces_test() {
  let assert Ok(graph) =
    build_graph([square(0.0, 0.0, 10.0)], tolerance:, minimum_chord:)
  let assert Ok(arrangement_graph.DualArrangementGraph(faces:, edge_faces:)) =
    arrangement_graph.dual(graph)
  let assert [outer, bounded] = faces
  let assert arrangement_graph.ArrangementFace(
    id: outer_id,
    outer: True,
    walks: [outer_walk],
  ) = outer
  let assert arrangement_graph.ArrangementFace(
    id: bounded_id,
    outer: False,
    walks: [bounded_walk],
  ) = bounded
  outer_id |> should.equal(0)
  bounded_id |> should.equal(1)
  outer_walk.outer |> should.be_false
  bounded_walk.outer |> should.be_true
  list.length(outer_walk.edges) |> should.equal(4)
  list.length(bounded_walk.edges) |> should.equal(4)
  list.length(edge_faces) |> should.equal(4)
}

fn propagated_source_windings(subpaths: List(svg_path.Subpath)) {
  let assert Ok(graph) = build_graph(subpaths, tolerance:, minimum_chord:)
  let assert Ok(dual) = arrangement_graph.dual(graph)
  let changes =
    list.map(graph.edges, fn(edge) {
      arrangement_graph.EdgeWindingChange(
        edge.id,
        edge.forward_multiplicity - edge.reverse_multiplicity,
      )
    })
  arrangement_graph.face_windings(dual, changes)
}

pub fn dual_face_windings_follow_signed_nested_sources_test() {
  let outer = square(0.0, 0.0, 10.0)
  let inner = square(2.0, 2.0, 6.0)
  list.each(
    [
      #([outer, inner], [0, 1, 2]),
      #([outer, svg_path.subpath_reverse(inner)], [0, 0, 1]),
      #([svg_path.subpath_reverse(outer), svg_path.subpath_reverse(inner)], [
        -2,
        -1,
        0,
      ]),
    ],
    fn(example) {
      let assert Ok(values) = propagated_source_windings(example.0)
      list.map(values, fn(value) { value.value })
      |> list.sort(int.compare)
      |> should.equal(example.1)
    },
  )
}

pub fn dual_face_windings_accumulate_overlap_and_multiplicity_test() {
  let a = square(0.0, 0.0, 10.0)
  let b = square(5.0, 5.0, 10.0)
  let assert Ok(values) = propagated_source_windings([a, a, b])
  list.map(values, fn(value) { value.value })
  |> list.sort(int.compare)
  |> should.equal([0, 1, 2, 3])
}

pub fn dual_face_windings_reject_open_boundary_but_accept_cancellation_test() {
  let line =
    svg_path.subpath_assert([
      svg_path.Line(svg_path.Point(0.0, 0.0), svg_path.Point(10.0, 0.0)),
    ])
  let assert Error(arrangement_graph.ContradictoryWinding(..)) =
    propagated_source_windings([line])
  let assert Ok([arrangement_graph.FaceWinding(_, 0)]) =
    propagated_source_windings([line, svg_path.subpath_reverse(line)])
}

pub fn dual_face_windings_empty_graph_test() {
  let assert Ok([arrangement_graph.FaceWinding(0, 0)]) =
    propagated_source_windings([])
}

pub fn dual_face_windings_validate_changes_and_detect_cycle_conflicts_test() {
  let assert Ok(graph) =
    build_graph([square(0.0, 0.0, 10.0)], tolerance:, minimum_chord:)
  let assert Ok(dual) = arrangement_graph.dual(graph)
  let changes =
    list.map(graph.edges, fn(edge) {
      arrangement_graph.EdgeWindingChange(
        edge.id,
        edge.forward_multiplicity - edge.reverse_multiplicity,
      )
    })
  let assert [first, ..rest] = changes
  let assert Error(arrangement_graph.InvalidWindingChanges) =
    arrangement_graph.face_windings(dual, rest)
  let assert Error(arrangement_graph.InvalidWindingChanges) =
    arrangement_graph.face_windings(dual, [first, ..changes])
  let assert Error(arrangement_graph.ContradictoryWinding(..)) =
    arrangement_graph.face_windings(dual, [
      arrangement_graph.EdgeWindingChange(
        first.edge_id,
        first.right_minus_left + 1,
      ),
      ..rest
    ])
}

pub fn dual_narrow_nested_squares_do_not_skip_annular_face_test() {
  let assert Ok(graph) =
    build_graph(
      [
        square(0.0, 0.0, 10.0),
        square(0.00001, 0.00001, 9.99998),
      ],
      tolerance: 0.000000001,
      minimum_chord: 0.000000001,
    )
  let assert Ok(dual) = arrangement_graph.dual(graph)
  assert list.length(dual.faces) == 3
  let assert Ok(annulus) =
    list.find(dual.faces, fn(face) { list.length(face.walks) == 2 })
  assert !annulus.outer
  let assert [enclosing, island] = annulus.walks
  assert enclosing.outer && !island.outer
}

pub fn dual_mixed_nested_and_separate_components_test() {
  let assert Ok(graph) =
    build_graph(
      [
        square(0.0, 0.0, 20.0),
        square(0.00001, 0.00001, 19.99998),
        square(5.0, 5.0, 2.0),
        square(10.0, 5.0, 2.0),
        square(30.0, 0.0, 4.0),
      ],
      tolerance: 0.000000001,
      minimum_chord: 0.000000001,
    )
  let assert Ok(dual) = arrangement_graph.dual(graph)
  assert list.length(dual.faces) == 6
  let assert [outer, ..] = dual.faces
  assert outer.outer && list.length(outer.walks) == 2
  assert list.any(dual.faces, fn(face) {
    !face.outer && list.length(face.walks) == 3
  })
  assert arrangement_graph.dual(graph) == Ok(dual)
}

pub fn dual_curved_nested_components_ignore_traversal_orientation_test() {
  let outer = dual_test_circle(10.0)
  let inner = dual_test_circle(9.99999)
  list.each([inner, svg_path.subpath_reverse(inner)], fn(inner) {
    let assert Ok(graph) =
      build_graph(
        [outer, inner],
        tolerance: 0.000000001,
        minimum_chord: 0.000000001,
      )
    let assert Ok(dual) = arrangement_graph.dual(graph)
    assert list.length(dual.faces) == 3
    assert list.any(dual.faces, fn(face) {
      !face.outer && list.length(face.walks) == 2
    })
  })
}

pub fn dual_closed_cubic_and_disconnected_bridge_test() {
  let loop =
    closed_subpath([
      svg_path.CubicBezier(
        svg_path.Point(0.0, 0.0),
        svg_path.Point(4.0, 6.0),
        svg_path.Point(-4.0, 6.0),
        svg_path.Point(0.0, 0.0),
      ),
    ])
  let bridge =
    svg_path.segment_as_subpath(svg_path.Line(
      svg_path.Point(-0.2, 2.0),
      svg_path.Point(0.2, 2.0),
    ))
  let assert Ok(graph) = build_graph([loop, bridge], tolerance:, minimum_chord:)
  let assert Ok(dual) = arrangement_graph.dual(graph)
  assert list.length(dual.faces) == 2
  assert list.any(dual.faces, fn(face) {
    !face.outer && list.length(face.walks) == 2
  })
  assert list.any(dual.edge_faces, fn(edge) {
    edge.left_face == edge.right_face
  })
}

fn dual_test_circle(radius: Float) -> svg_path.Subpath {
  let a = svg_path.Point(radius, 0.0)
  let b = svg_path.Point(0.0 -. radius, 0.0)
  let r = svg_path.Point(radius, radius)
  closed_subpath([
    svg_path.Arc(a, r, 0.0, False, True, b),
    svg_path.Arc(b, r, 0.0, False, True, a),
  ])
}

pub fn dual_infinite_face_collects_disconnected_islands_test() {
  let assert Ok(graph) =
    build_graph(
      [square(0.0, 0.0, 10.0), square(20.0, 0.0, 10.0)],
      tolerance:,
      minimum_chord:,
    )
  let assert Ok(arrangement_graph.DualArrangementGraph(faces:, ..)) =
    arrangement_graph.dual(graph)
  let assert [outer, _, _] = faces
  outer.outer |> should.be_true
  list.length(outer.walks) |> should.equal(2)
  outer.walks
  |> list.all(fn(walk) { !walk.outer })
  |> should.be_true
}

pub fn dual_bounded_face_orders_outer_walk_before_island_test() {
  let assert Ok(graph) =
    build_graph(
      [square(0.0, 0.0, 20.0), square(5.0, 5.0, 5.0)],
      tolerance:,
      minimum_chord:,
    )
  let assert Ok(arrangement_graph.DualArrangementGraph(faces:, ..)) =
    arrangement_graph.dual(graph)
  let assert Ok(face) =
    list.find(faces, fn(face) { !face.outer && list.length(face.walks) == 2 })
  let assert [outer_walk, island_walk] = face.walks
  outer_walk.outer |> should.be_true
  island_walk.outer |> should.be_false
}

pub fn dual_bounded_face_collects_two_island_walks_test() {
  let assert Ok(graph) =
    build_graph(
      [
        rectangle(0.0, 0.0, 30.0, 20.0),
        square(5.0, 5.0, 5.0),
        square(20.0, 5.0, 5.0),
      ],
      tolerance:,
      minimum_chord:,
    )
  let assert Ok(arrangement_graph.DualArrangementGraph(faces:, ..)) =
    arrangement_graph.dual(graph)
  let assert Ok(face) =
    list.find(faces, fn(face) { !face.outer && list.length(face.walks) == 3 })
  let assert [outer_walk, first_island, second_island] = face.walks
  outer_walk.outer |> should.be_true
  first_island.outer |> should.be_false
  second_island.outer |> should.be_false
}

pub fn dual_bridge_has_same_face_on_both_sides_test() {
  let line =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
    ])
  let assert Ok(graph) = build_graph([line], tolerance:, minimum_chord:)
  let assert Ok(arrangement_graph.DualArrangementGraph(
    faces: [face],
    edge_faces: [edge_faces],
  )) = arrangement_graph.dual(graph)
  face.outer |> should.be_true
  let arrangement_graph.ArrangementEdgeFaces(left_face:, right_face:, ..) =
    edge_faces
  left_face |> should.equal(right_face)
}

pub fn dual_empty_graph_is_the_infinite_face_test() {
  let assert Ok(arrangement_graph.DualArrangementGraph(
    faces: [arrangement_graph.ArrangementFace(id: 0, outer: True, walks: [])],
    edge_faces: [],
  )) = arrangement_graph.empty() |> arrangement_graph.dual
}

pub fn dual_overlapping_squares_partition_every_edge_side_test() {
  let assert Ok(graph) =
    build_graph(
      [square(0.0, 0.0, 10.0), square(5.0, 0.0, 10.0)],
      tolerance:,
      minimum_chord:,
    )
  let assert Ok(arrangement_graph.DualArrangementGraph(faces:, edge_faces:)) =
    arrangement_graph.dual(graph)
  list.length(faces) |> should.equal(4)
  let arrangement_graph.ArrangementGraph(edges:, ..) = graph
  list.length(edge_faces) |> should.equal(list.length(edges))
  faces
  |> list.flat_map(fn(face) { face.walks })
  |> list.flat_map(fn(walk) { walk.edges })
  |> list.length
  |> should.equal(list.length(edges) * 2)
}

pub fn dual_self_crossing_bowtie_has_two_bounded_faces_test() {
  let bowtie =
    closed_subpath([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 10.0),
      ),
      svg_path.Line(
        start: svg_path.Point(10.0, 10.0),
        end: svg_path.Point(0.0, 10.0),
      ),
      svg_path.Line(
        start: svg_path.Point(0.0, 10.0),
        end: svg_path.Point(10.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(10.0, 0.0),
        end: svg_path.Point(0.0, 0.0),
      ),
    ])
  let assert Ok(graph) = build_graph([bowtie], tolerance:, minimum_chord:)
  let assert Ok(arrangement_graph.DualArrangementGraph(faces:, ..)) =
    arrangement_graph.dual(graph)
  list.length(faces) |> should.equal(3)
  faces
  |> list.filter(fn(face) { !face.outer })
  |> list.length
  |> should.equal(2)
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

pub fn build_rejects_nonfinite_numeric_options_test() {
  let infinity = 1.0 /. 0.0
  let nan = 0.0 /. 0.0

  arrangement_graph.build([], tolerance: infinity, minimum_chord:)
  |> should.equal(Error(arrangement_graph.InvalidTolerance(infinity)))
  arrangement_graph.build([], tolerance:, minimum_chord: infinity)
  |> should.equal(Error(arrangement_graph.InvalidMinimumChord(infinity)))
  arrangement_graph.build([], tolerance: nan, minimum_chord:)
  |> should.be_error
  arrangement_graph.build([], tolerance:, minimum_chord: nan)
  |> should.be_error
}

pub fn build_with_rejects_negative_endpoint_sliver_tolerance_test() {
  arrangement_graph.build_with(
    [],
    vertex_tolerance: tolerance,
    minimum_chord:,
    endpoint_sliver_tolerance: -0.1,
  )
  |> should.equal(
    Error(arrangement_graph.InternalInvalidEndpointSliverTolerance(-0.1)),
  )
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
  |> should.equal(Error(arrangement_graph.InternalSegmentCollapsedToVertex(0)))
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
  |> should.equal(Error(arrangement_graph.ConstructionFailed))
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

  arrangement_graph.validate(graph, tolerance: 1.0, minimum_chord:)
  |> should.equal(Error(arrangement_graph.ConstructionFailed))
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
  |> should.equal(Error(arrangement_graph.ConstructionFailed))
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
  |> should.equal(Error(arrangement_graph.ConstructionFailed))
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
    Error(arrangement_graph.InternalSegmentTooShort(
      chord: 0.000001,
      minimum: minimum_chord,
    )),
  )
}

pub fn annotated_drawing_uses_requested_winding_tolerance_test() {
  let source =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(100.0, 0.0),
      svg_path.Point(100.0, 100.0),
      svg_path.Point(0.0, 100.0),
      svg_path.Point(0.0, 0.0),
    ])
    |> svg_path.subpath_assert_close()
  let path = svg_path.subpath_as_path(source)
  let assert Ok(build) =
    arrangement_graph.build([path], 0.000000000001, 0.00000001)
  let assert Ok(things) =
    arrangement_graph_drawing.annotated_drawing(
      build.graph,
      path,
      tolerance: 0.000000000001,
    )
  let winding_labels =
    list.filter_map(things, fn(thing) {
      case thing {
        svg.RotatedText(label, style, _, _, _, _) -> {
          case
            style
            == "fill: #0f172a; font-family: ui-monospace, monospace; font-weight: 700; text-anchor: middle"
          {
            True -> Ok(label)
            False -> Error(Nil)
          }
        }
        _ -> Error(Nil)
      }
    })
  list.length(winding_labels) |> should.equal(4)
  list.all(winding_labels, fn(label) { label == "0/1" || label == "1/0" })
  |> should.be_true
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

  list.length(svg_path.path_subpaths(union)) |> should.equal(1)
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

pub fn csg_union_pairs_filled_sectors_at_corner_pinch_reversed_orientation_test() {
  let first = square(0.0, 0.0, 10.0) |> svg_path.subpath_reverse
  let second = square(10.0, 10.0, 10.0) |> svg_path.subpath_reverse
  let left = svg_path.subpath_as_path(first)
  let right = svg_path.subpath_as_path(second)
  let assert Ok(csg.CsgResult(path: union, ..)) =
    csg.union(left, right, using: svg_path.Nonzero)

  list.length(svg_path.path_subpaths(union)) |> should.equal(1)
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

pub fn csg_union_pairs_filled_sectors_at_other_corner_pinch_test() {
  let first = square(0.0, 10.0, 10.0)
  let second = square(10.0, 0.0, 10.0)
  let left = svg_path.subpath_as_path(first)
  let right = svg_path.subpath_as_path(second)
  let assert Ok(csg.CsgResult(path: union, ..)) =
    csg.union(left, right, using: svg_path.Nonzero)

  list.length(svg_path.path_subpaths(union)) |> should.equal(1)
  svg_path.path_containment(
    svg_path.Point(5.0, 15.0),
    within: union,
    using: svg_path.Nonzero,
  )
  |> should.equal(Ok(svg_path.Inside))
  svg_path.path_containment(
    svg_path.Point(15.0, 5.0),
    within: union,
    using: svg_path.Nonzero,
  )
  |> should.equal(Ok(svg_path.Inside))
}

pub fn csg_union_pairs_filled_sectors_at_other_corner_pinch_reversed_orientation_test() {
  let first = square(0.0, 10.0, 10.0) |> svg_path.subpath_reverse
  let second = square(10.0, 0.0, 10.0) |> svg_path.subpath_reverse
  let left = svg_path.subpath_as_path(first)
  let right = svg_path.subpath_as_path(second)
  let assert Ok(csg.CsgResult(path: union, ..)) =
    csg.union(left, right, using: svg_path.Nonzero)

  list.length(svg_path.path_subpaths(union)) |> should.equal(1)
  svg_path.path_containment(
    svg_path.Point(5.0, 15.0),
    within: union,
    using: svg_path.Nonzero,
  )
  |> should.equal(Ok(svg_path.Inside))
  svg_path.path_containment(
    svg_path.Point(15.0, 5.0),
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
  |> svg_path.subpath_assert_close()
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
) -> Result(arrangement_graph.ArrangementGraph, arrangement_graph.InternalError) {
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
) -> Result(arrangement_graph.ArrangementGraph, arrangement_graph.InternalError) {
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
  rectangle(x, y, side, side)
}

fn rectangle(
  x: Float,
  y: Float,
  width: Float,
  height: Float,
) -> svg_path.Subpath {
  let a = svg_path.Point(x, y)
  let b = svg_path.Point(x +. width, y)
  let c = svg_path.Point(x +. width, y +. height)
  let d = svg_path.Point(x, y +. height)
  closed_subpath([
    svg_path.Line(start: a, end: b),
    svg_path.Line(start: b, end: c),
    svg_path.Line(start: c, end: d),
    svg_path.Line(start: d, end: a),
  ])
}
