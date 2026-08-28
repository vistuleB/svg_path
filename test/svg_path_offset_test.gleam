import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/string
import svg_path
import svg_path/area
import svg_path/arrangement as arrangement_graph
import svg_path/format as number_format
import svg_path/offset
import svg_path/parse
import svg_path/point
import svg_path/serialize
import svg_path/trig

const stalled_arc_turn_svg_output = "examples/debug/stalled-offset-arc-turns.svg"

const stalled_arc_turn_zoom_svg_output = "examples/debug/stalled-offset-corner-zoom.svg"

const stalled_arc_turn_report_output = "examples/debug/stalled-offset-arc-turns-report.txt"

const stalled_arc_turn_radius = 40.0

const stalled_arc_turn_distance = 39.999

const stalled_arc_turn_threshold = 0.01

pub fn reversal_boundaries_store_endpoint_curvature_test() {
  let segment =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(1.0, 0.0),
      control2: svg_path.Point(1.0, 0.0),
      end: svg_path.Point(1.0, 1.0),
    )
  let assert Ok(source) =
    svg_path.subpath_with([segment], policy: svg_path.Strict)
  let distance = -0.27
  let assert Ok(portions) =
    offset.internal_offset_source_trace(
      source,
      distance:,
      options: offset.default_options(),
    )
  let reversal_curvatures =
    portions
    |> list.flat_map(fn(portion) {
      let offset.OffsetSourceTracePortion(pieces:, ..) = portion
      pieces
      |> list.flat_map(fn(piece) {
        case piece {
          offset.OffsetSourceTraceDRefined(start_boundary:, end_boundary:, ..) -> [
            start_boundary,
            end_boundary,
          ]
          offset.OffsetSourceTraceStalled(..) -> []
        }
      })
    })
    |> list.filter_map(fn(boundary) {
      case boundary {
        offset.ReversalBoundary(Some(curvature)) -> Ok(curvature)
        _ -> Error(Nil)
      }
    })

  assert reversal_curvatures != []
  assert list.all(reversal_curvatures, fn(value) {
    value != 0.0 && float.absolute_value(1.0 /. value -. distance) <. 0.00001
  })
}

pub fn synchronized_offsets_share_nonstalled_refinement_leaves_test() {
  let segment =
    svg_path.CubicBezier(
      start: svg_path.Point(0.0, 0.0),
      control1: svg_path.Point(1.0, 0.0),
      control2: svg_path.Point(1.0, 0.0),
      end: svg_path.Point(1.0, 1.0),
    )
  let assert Ok(source) =
    svg_path.subpath_with([segment], policy: svg_path.Strict)
  let assert Ok(correspondences) =
    offset.internal_synchronized_offset_trace(
      source,
      inner_distance: 0.0,
      outer_distance: -0.27,
      options: offset.default_options(),
    )
  let paired =
    correspondences
    |> list.filter(fn(correspondence) {
      let offset.SynchronizedOffsetTraceCorrespondence(
        inner_stalled:,
        outer_stalled:,
        ..,
      ) = correspondence
      !inner_stalled && !outer_stalled
    })

  assert paired != []
  assert list.all(paired, fn(correspondence) {
    let offset.SynchronizedOffsetTraceCorrespondence(
      inner_leaves:,
      outer_leaves:,
      ..,
    ) = correspondence
    synchronized_trace_spans(inner_leaves)
    == synchronized_trace_spans(outer_leaves)
  })
}

pub fn synchronized_offsets_keep_stalled_side_as_one_run_test() {
  let source = stalled_arc_turn_source(4, use_arcs: True)
  let assert Ok(correspondences) =
    offset.internal_synchronized_offset_trace(
      source,
      inner_distance: 0.0,
      outer_distance: stalled_arc_turn_distance,
      options: offset.default_options(),
    )

  assert list.any(correspondences, fn(correspondence) {
    let offset.SynchronizedOffsetTraceCorrespondence(
      outer_stalled:,
      outer_leaves:,
      ..,
    ) = correspondence
    outer_stalled && list.length(outer_leaves) >= 4
  })
}

pub fn synchronized_offsets_accept_reversed_distance_order_test() {
  let source =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(2.0, 1.0),
      ),
    ])
  let assert Ok(forward) =
    offset.subpath_band_untrimmed(source, distance_a: -0.5, distance_b: 1.0)
  let assert Ok(reversed) =
    offset.subpath_band_untrimmed(source, distance_a: 1.0, distance_b: -0.5)
  let assert [forward_inner, forward_outer] = svg_path.path_subpaths(forward)
  let assert [reversed_inner, reversed_outer] = svg_path.path_subpaths(reversed)

  assert forward_inner == reversed_outer
  assert forward_outer == reversed_inner
}

pub fn synchronized_offsets_retain_matched_join_geometry_test() {
  let source =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(1.0, 1.0),
      ),
      svg_path.Line(
        start: svg_path.Point(1.0, 1.0),
        end: svg_path.Point(2.0, 0.0),
      ),
    ])
  let assert Ok(joins) =
    offset.internal_synchronized_join_trace(
      source,
      inner_distance: -0.25,
      outer_distance: 0.5,
      options: offset.default_options(),
    )
  let assert [
    offset.SynchronizedOffsetTraceJoin(
      after_portion_index: 0,
      inner_segments:,
      outer_segments:,
      inner_reversed:,
      outer_reversed:,
    ),
  ] = joins

  assert inner_segments != []
  assert outer_segments != []
  assert inner_reversed == False
  assert outer_reversed == True
}

fn synchronized_trace_spans(
  leaves: List(offset.SynchronizedOffsetTraceLeaf),
) -> List(#(Int, Float, Float)) {
  list.map(leaves, fn(leaf) {
    let offset.SynchronizedOffsetTraceLeaf(
      source_segment_index:,
      prepared_from:,
      prepared_to:,
      ..,
    ) = leaf
    #(source_segment_index, prepared_from, prepared_to)
  })
}

pub fn endpoint_near_reversal_is_absorbed_into_stalled_piece_test() {
  let segment =
    svg_path.CubicBezier(
      start: svg_path.Point(21.684995, 1.2450002000000002),
      control1: svg_path.Point(21.494995, 1.3150002000000003),
      control2: svg_path.Point(21.37800567659191, 1.4211122301564318),
      end: svg_path.Point(21.324995, 1.5600002000000002),
    )
  let assert Ok(source) =
    svg_path.subpath_with([segment], policy: svg_path.Strict)
  let options =
    offset.Options(
      ..offset.default_options(),
      fitting: offset.FittingOptions(tolerance: 0.01, samples: 5, max_depth: 12),
    )
  let assert Ok([
    offset.OffsetSourceTracePortion(
      pieces: [
        offset.OffsetSourceTraceStalled(segment: stalled, ..),
        offset.OffsetSourceTraceDRefined(source_from:, ..),
        ..
      ],
      ..,
    ),
  ]) = offset.internal_offset_source_trace(source, distance: 1.04, options:)

  assert svg_path.segment_chord_length(stalled) <. 0.001
  assert float.absolute_value(source_from -. 0.00019493877887725834)
    <. 0.000000001
}

pub fn segment_offsets_line_to_visual_left_for_positive_distance_test() {
  let line =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 0.0),
    )

  let assert Ok(offset) = offset.segment(line, distance: 2.0)

  assert svg_path.subpath_segments(offset)
    == [
      svg_path.Line(
        start: svg_path.Point(0.0, -2.0),
        end: svg_path.Point(10.0, -2.0),
      ),
    ]
}

pub fn segment_offsets_line_to_visual_right_for_negative_distance_test() {
  let line =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(0.0, 10.0),
    )

  let assert Ok(offset) = offset.segment(line, distance: -3.0)

  assert svg_path.subpath_segments(offset)
    == [
      svg_path.Line(
        start: svg_path.Point(-3.0, 0.0),
        end: svg_path.Point(-3.0, 10.0),
      ),
    ]
}

pub fn reversal_tangent_adjustment_opens_clockwise_gap_test() {
  let assert Ok(adjustment) =
    offset.internal_reversal_tangent_adjustment(
      incoming_direction: point.direction(degrees: 0.0),
      outgoing_direction: point.direction(degrees: 180.0),
      incoming_turn: offset.Clockwise,
      outgoing_turn: offset.Clockwise,
      incoming_chord: 1.0,
      outgoing_chord: 1.0,
      required_gap_degrees: 1.0,
    )

  assert_reversal_gap(
    incoming_direction: point.direction(degrees: 0.0),
    outgoing_direction: point.direction(degrees: 180.0),
    adjustment:,
    expected_turn: offset.Clockwise,
    at_least: 1.0,
  )
  assert_near(adjustment.incoming_degrees, -0.5)
  assert_near(adjustment.outgoing_degrees, 0.5)
}

pub fn reversal_tangent_adjustment_opens_counterclockwise_gap_test() {
  let assert Ok(adjustment) =
    offset.internal_reversal_tangent_adjustment(
      incoming_direction: point.direction(degrees: 0.0),
      outgoing_direction: point.direction(degrees: 180.0),
      incoming_turn: offset.CounterClockwise,
      outgoing_turn: offset.CounterClockwise,
      incoming_chord: 1.0,
      outgoing_chord: 1.0,
      required_gap_degrees: 1.0,
    )

  assert_reversal_gap(
    incoming_direction: point.direction(degrees: 0.0),
    outgoing_direction: point.direction(degrees: 180.0),
    adjustment:,
    expected_turn: offset.CounterClockwise,
    at_least: 1.0,
  )
  assert_near(adjustment.incoming_degrees, 0.5)
  assert_near(adjustment.outgoing_degrees, -0.5)
}

pub fn reversal_tangent_adjustment_uses_existing_gap_test() {
  let assert Ok(adjustment) =
    offset.internal_reversal_tangent_adjustment(
      incoming_direction: point.direction(degrees: 0.0),
      outgoing_direction: point.direction(degrees: 180.5),
      incoming_turn: offset.Clockwise,
      outgoing_turn: offset.Clockwise,
      incoming_chord: 1.0,
      outgoing_chord: 1.0,
      required_gap_degrees: 1.0,
    )

  assert_reversal_gap(
    incoming_direction: point.direction(degrees: 0.0),
    outgoing_direction: point.direction(degrees: 180.5),
    adjustment:,
    expected_turn: offset.Clockwise,
    at_least: 1.0,
  )
  assert_near(adjustment.incoming_degrees, -0.25)
  assert_near(adjustment.outgoing_degrees, 0.25)
}

pub fn reversal_tangent_adjustment_corrects_wrong_side_gap_test() {
  let assert Ok(adjustment) =
    offset.internal_reversal_tangent_adjustment(
      incoming_direction: point.direction(degrees: 0.0),
      outgoing_direction: point.direction(degrees: 179.5),
      incoming_turn: offset.Clockwise,
      outgoing_turn: offset.Clockwise,
      incoming_chord: 1.0,
      outgoing_chord: 1.0,
      required_gap_degrees: 1.0,
    )

  assert_reversal_gap(
    incoming_direction: point.direction(degrees: 0.0),
    outgoing_direction: point.direction(degrees: 179.5),
    adjustment:,
    expected_turn: offset.Clockwise,
    at_least: 1.0,
  )
  assert_near(adjustment.incoming_degrees, -0.75)
  assert_near(adjustment.outgoing_degrees, 0.75)
}

pub fn reversal_tangent_adjustment_weights_shorter_segment_more_test() {
  let assert Ok(adjustment) =
    offset.internal_reversal_tangent_adjustment(
      incoming_direction: point.direction(degrees: 0.0),
      outgoing_direction: point.direction(degrees: 180.0),
      incoming_turn: offset.Clockwise,
      outgoing_turn: offset.Clockwise,
      incoming_chord: 1.0,
      outgoing_chord: 9.0,
      required_gap_degrees: 1.0,
    )

  assert_near(adjustment.incoming_degrees, -0.9)
  assert_near(adjustment.outgoing_degrees, 0.1)
}

pub fn reversal_tangent_adjustment_treats_straight_as_other_turn_test() {
  let assert Ok(adjustment) =
    offset.internal_reversal_tangent_adjustment(
      incoming_direction: point.direction(degrees: 0.0),
      outgoing_direction: point.direction(degrees: 180.0),
      incoming_turn: offset.Straight,
      outgoing_turn: offset.CounterClockwise,
      incoming_chord: 1.0,
      outgoing_chord: 1.0,
      required_gap_degrees: 1.0,
    )

  assert_reversal_gap(
    incoming_direction: point.direction(degrees: 0.0),
    outgoing_direction: point.direction(degrees: 180.0),
    adjustment:,
    expected_turn: offset.CounterClockwise,
    at_least: 1.0,
  )
}

pub fn reversal_tangent_adjustment_rejects_ambiguous_turns_test() {
  assert offset.internal_reversal_tangent_adjustment(
      incoming_direction: point.direction(degrees: 0.0),
      outgoing_direction: point.direction(degrees: 180.0),
      incoming_turn: offset.Clockwise,
      outgoing_turn: offset.CounterClockwise,
      incoming_chord: 1.0,
      outgoing_chord: 1.0,
      required_gap_degrees: 1.0,
    )
    == Error(Nil)

  assert offset.internal_reversal_tangent_adjustment(
      incoming_direction: point.direction(degrees: 0.0),
      outgoing_direction: point.direction(degrees: 180.0),
      incoming_turn: offset.CouldNotMeasure,
      outgoing_turn: offset.Clockwise,
      incoming_chord: 1.0,
      outgoing_chord: 1.0,
      required_gap_degrees: 1.0,
    )
    == Error(Nil)
}

pub fn subpath_offset_map_maps_local_coordinates_to_right_side_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
    ])
  let assert Ok(map) = offset.subpath_offset_map(subpath)

  assert map(svg_path.Point(3.0, 2.0)) == Ok(svg_path.Point(3.0, -2.0))
  assert map(svg_path.Point(3.0, -2.0)) == Ok(svg_path.Point(3.0, 2.0))
}

pub fn subpath_offset_map_uses_cumulative_segment_lengths_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(10.0, 0.0),
        end: svg_path.Point(10.0, 10.0),
      ),
    ])
  let assert Ok(map) = offset.subpath_offset_map(subpath)

  assert map(svg_path.Point(12.0, 3.0)) == Ok(svg_path.Point(13.0, 2.0))
}

pub fn subpath_offset_map_wraps_closed_subpath_distances_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
      svg_path.Line(
        start: svg_path.Point(10.0, 0.0),
        end: svg_path.Point(10.0, 10.0),
      ),
      svg_path.Line(
        start: svg_path.Point(10.0, 10.0),
        end: svg_path.Point(0.0, 10.0),
      ),
      svg_path.Line(
        start: svg_path.Point(0.0, 10.0),
        end: svg_path.Point(0.0, 0.0),
      ),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)
  let assert Ok(map) = offset.subpath_offset_map(subpath)

  assert map(svg_path.Point(42.0, 1.0)) == Ok(svg_path.Point(2.0, -1.0))
}

pub fn subpath_offset_map_rejects_open_subpath_distances_outside_length_test() {
  let subpath =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(10.0, 0.0),
      ),
    ])
  let assert Ok(map) = offset.subpath_offset_map(subpath)

  assert map(svg_path.Point(11.0, 0.0))
    == Error(
      offset.PathError(svg_path.InvalidLengthDistance(
        distance: 11.0,
        length: 10.0,
      )),
    )
}

pub fn subpath_offset_map_rejects_zero_length_subpath_test() {
  let subpath = svg_path.subpath_empty(at: svg_path.Point(0.0, 0.0))

  assert offset.subpath_offset_map(subpath)
    == Error(offset.DegenerateTangent(0.0))
}

pub fn subpath_offset_map_composes_with_try_map_path_points_test() {
  let baseline =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(0.0, 0.0),
        end: svg_path.Point(100.0, 0.0),
      ),
    ])
  let outline =
    svg_path.Path([
      svg_path.subpath_assert([
        svg_path.Line(
          start: svg_path.Point(20.0, 3.0),
          end: svg_path.Point(40.0, 5.0),
        ),
      ]),
    ])
  let assert Ok(map) = offset.subpath_offset_map(baseline)
  let assert Ok(mapped) = svg_path.path_try_map_points(outline, with: map)

  assert mapped
    == svg_path.Path([
      svg_path.subpath_assert([
        svg_path.Line(
          start: svg_path.Point(20.0, -3.0),
          end: svg_path.Point(40.0, -5.0),
        ),
      ]),
    ])
}

pub fn package_title_s_iterated_offset_keeps_three_closed_first_offset_subpaths_test() {
  let assert Ok(contents) = read_file("examples/debug/package_title.svg")
  let assert Ok(title) = parse.path(first_path_data(contents))
  let assert Ok(s) = first_subpath(title)
  let source = svg_path.Path([s])
  let options =
    offset.Options(
      ..offset.default_options(),
      fitting: offset.FittingOptions(tolerance: 0.01, samples: 5, max_depth: 12),
      trimming: svg_path.DistanceOptions(
        ..svg_path.default_distance_options(),
        tolerance: 0.000000001,
      ),
    )

  let assert Ok(first_offset) =
    offset.path_with(source, distance: 1.0, options:)
  let first_offset_subpaths = svg_path.path_subpaths(first_offset)
  assert list.length(first_offset_subpaths) == 3
  assert all_subpaths_closed(first_offset_subpaths)

  let assert Ok(_second_offset) =
    offset.path_with(first_offset, distance: 1.0, options:)
}

pub fn package_title_v_1_05_public_offset_filters_micro_loops_test() {
  let assert Ok(contents) = read_file("examples/debug/package_title.svg")
  let assert Ok(title) = parse.path(first_path_data(contents))
  let assert [_, v, ..] = svg_path.path_subpaths(title)
  let options =
    offset.Options(
      ..offset.default_options(),
      fitting: offset.FittingOptions(tolerance: 0.01, samples: 5, max_depth: 12),
      trimming: svg_path.DistanceOptions(
        ..svg_path.default_distance_options(),
        tolerance: 0.000000001,
      ),
    )
  let assert Ok(result) =
    offset.path_with(svg_path.Path([v]), distance: 1.05, options:)
  let subpaths = svg_path.path_subpaths(result)

  assert list.length(subpaths) == 1
  assert list.all(subpaths, svg_path.subpath_is_closed)
}

pub fn package_title_a_and_v_1_05_bevel_offsets_filter_micro_loops_test() {
  let assert Ok(contents) = read_file("examples/debug/package_title.svg")
  let assert Ok(title) = parse.path(first_path_data(contents))
  let assert [_, v, _, _, _, _, a_outer, a_inner, ..] =
    svg_path.path_subpaths(title)
  let options =
    offset.Options(
      ..offset.default_options(),
      fitting: offset.FittingOptions(tolerance: 0.01, samples: 5, max_depth: 12),
      trimming: svg_path.DistanceOptions(
        ..svg_path.default_distance_options(),
        tolerance: 0.000000001,
      ),
      join: offset.Bevel,
    )

  let assert Ok(v_offset) =
    offset.path_with(svg_path.Path([v]), distance: 1.05, options:)
  let assert Ok(a_offset) =
    offset.path_with(
      svg_path.Path([a_outer, a_inner]),
      distance: 1.05,
      options:,
    )

  assert list.length(svg_path.path_subpaths(v_offset)) == 1
  assert list.length(svg_path.path_subpaths(a_offset)) == 2
}

fn first_subpath(path: svg_path.Path) -> Result(svg_path.Subpath, Nil) {
  case svg_path.path_subpaths(path) {
    [first, ..] -> Ok(first)
    [] -> Error(Nil)
  }
}

fn all_subpaths_closed(subpaths: List(svg_path.Subpath)) -> Bool {
  case subpaths {
    [] -> True
    [first, ..rest] ->
      svg_path.subpath_is_closed(first) && all_subpaths_closed(rest)
  }
}

pub fn segment_offsets_quadratic_to_cubic_pieces_within_tolerance_test() {
  let curve =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.0),
      control: svg_path.Point(50.0, -80.0),
      end: svg_path.Point(100.0, 0.0),
    )
  let default = offset.default_options()
  let options =
    offset.Options(
      ..default,
      fitting: offset.FittingOptions(
        ..default.fitting,
        tolerance: 0.001,
        samples: 12,
      ),
    )

  let assert Ok(offset_subpath) =
    offset.segment_with(curve, distance: 5.0, options:)

  assert svg_path.subpath_segments(offset_subpath) != []
  assert max_offset_error(curve, offset_subpath, distance: 5.0) <=. 0.01
}

pub fn segment_offset_preserves_reversed_offset_tangent_direction_test() {
  let curve =
    svg_path.CubicBezier(
      start: svg_path.Point(72.63756968951799, 2.697503894403671),
      control1: svg_path.Point(72.63562808208563, 2.697622530169285),
      control2: svg_path.Point(72.63354998266372, 2.6977495058451253),
      end: svg_path.Point(72.63043, 2.69644),
    )
  let default = offset.default_options()
  let options =
    offset.Options(
      ..default,
      fitting: offset.FittingOptions(
        ..default.fitting,
        tolerance: 0.01,
        samples: 5,
      ),
    )

  let assert Ok(offset_subpath) =
    offset.segment_with(curve, distance: 0.4, options:)

  assert svg_path.subpath_segments(offset_subpath) != []
}

pub fn segment_offsets_circular_arc_exactly_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.Point(10.0, 0.0),
      radius: svg_path.Point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: True,
      end: svg_path.Point(0.0, 10.0),
    )

  let assert Ok(offset_subpath) = offset.segment(arc, distance: 2.0)

  assert serialize.subpath(offset_subpath) == "M 12 0 A 12 12 0 0 1 0 12"
}

pub fn segment_offsets_circular_arc_across_center_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.Point(10.0, 0.0),
      radius: svg_path.Point(10.0, 10.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: False,
      end: svg_path.Point(0.0, -10.0),
    )

  let assert Ok(offset_subpath) = offset.segment(arc, distance: 12.0)

  assert serialize.subpath(offset_subpath) == "M -2 0 A 2 2 0 0 0 0 2"
}

pub fn segment_offsets_near_collapsed_circular_arc_exactly_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.Point(40.0, 0.0),
      radius: svg_path.Point(40.0, 40.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: False,
      end: svg_path.Point(0.0, -40.0),
    )

  let assert Ok(offset_subpath) = offset.segment(arc, distance: 39.999)

  assert serialize.subpath(offset_subpath)
    == "M 0.001 0 A 0.001 0.001 0 0 0 0 -0.001"
}

pub fn segment_rejects_collapsed_circular_arc_offset_test() {
  let arc =
    svg_path.Arc(
      start: svg_path.Point(40.0, 0.0),
      radius: svg_path.Point(40.0, 40.0),
      x_axis_rotation: 0.0,
      large_arc: False,
      sweep: False,
      end: svg_path.Point(0.0, -40.0),
    )

  assert offset.segment(arc, distance: 40.0)
    == Error(offset.DegenerateTangent(0.0))
}

pub fn subpath_offsets_one_small_circular_arc_as_arc_test() {
  let source = stalled_arc_turn_source(1, use_arcs: True)
  let default = offset.default_options()
  let options =
    offset.Options(
      ..default,
      fitting: offset.FittingOptions(..default.fitting, tolerance: 0.001),
      join: offset.Round,
    )

  let assert Ok(offset_subpath) =
    offset.subpath_untrimmed_with(source, distance: 39.999, options:)

  let corner_segments = stalled_arc_turn_corner_segments(offset_subpath)

  assert list.length(corner_segments) == 1
  assert list.any(corner_segments, fn(segment) {
    case segment {
      svg_path.Arc(..) -> True
      _ -> False
    }
  })
  assert serialize.subpath(offset_subpath)
    == "M 0.001 40 V 0 A 0.001 0.001 0 0 0 0 -0.001 H -40"
}

pub fn subpath_offsets_many_small_circular_arcs_as_one_sampled_segment_test() {
  let source = stalled_arc_turn_source(4, use_arcs: True)
  let default = offset.default_options()
  let options =
    offset.Options(
      ..default,
      fitting: offset.FittingOptions(..default.fitting, tolerance: 0.001),
      join: offset.Round,
    )

  let assert Ok(offset_subpath) =
    offset.subpath_untrimmed_with(source, distance: 39.999, options:)

  let corner_segments = stalled_arc_turn_corner_segments(offset_subpath)

  assert list.length(corner_segments) == 1
  assert list.any(corner_segments, fn(segment) {
    case segment {
      svg_path.CubicBezier(..) -> True
      _ -> False
    }
  })
}

pub fn segment_rejects_invalid_options_test() {
  let line =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 0.0),
    )
  let default = offset.default_options()
  let options =
    offset.Options(
      ..default,
      fitting: offset.FittingOptions(..default.fitting, tolerance: 0.0),
    )

  assert offset.segment_with(line, distance: 1.0, options:)
    == Error(offset.InvalidTolerance(0.0))
}

pub fn default_offset_trimming_uses_precise_projection_test() {
  let options = offset.default_options()

  assert options.trimming.samples == 5
  assert options.trimming.tolerance
    == svg_path.default_distance_options().tolerance
}

pub fn section_filter_uses_fitting_tolerance_margin_test() {
  let source =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])
  let section =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.997),
      svg_path.Point(10.0, 0.997),
    ])
  let default = offset.default_options()
  let tight =
    offset.Options(
      ..default,
      fitting: offset.FittingOptions(..default.fitting, tolerance: 0.002),
    )
  let permissive =
    offset.Options(
      ..default,
      fitting: offset.FittingOptions(..default.fitting, tolerance: 0.01),
    )

  assert offset.internal_global_section_is_valid(
      section,
      source: svg_path.Path([source]),
      distance: 1.0,
      options: default,
    )
    == Ok(True)
  assert offset.internal_global_section_is_valid(
      section,
      source: svg_path.Path([source]),
      distance: 1.0,
      options: tight,
    )
    == Ok(False)
  assert offset.internal_global_section_is_valid(
      section,
      source: svg_path.Path([source]),
      distance: 1.0,
      options: permissive,
    )
    == Ok(True)
}

pub fn segment_rejects_negative_stalled_offset_diameter_test() {
  let line =
    svg_path.Line(
      start: svg_path.Point(0.0, 0.0),
      end: svg_path.Point(10.0, 0.0),
    )
  let options =
    offset.Options(..offset.default_options(), stalled_offset_diameter: -1.0)

  assert offset.segment_with(line, distance: 1.0, options:)
    == Error(offset.InvalidStalledOffsetDiameter(-1.0))
}

pub fn segment_rejects_zero_length_line_test() {
  let line =
    svg_path.Line(
      start: svg_path.Point(1.0, 2.0),
      end: svg_path.Point(1.0, 2.0),
    )

  assert offset.segment(line, distance: 1.0)
    == Error(offset.DegenerateTangent(0.0))
}

pub fn subpath_untrimmed_offsets_open_polyline_with_bevel_join_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
    ])
  let options = offset.Options(..offset.default_options(), join: offset.Bevel)

  let assert Ok(offset_subpath) =
    offset.subpath_untrimmed_with(subpath, distance: 2.0, options:)

  assert serialize.subpath(offset_subpath) == "M 0 -2 H 10 L 12 0 V 10"
}

pub fn subpath_untrimmed_offsets_open_polyline_with_miter_join_by_default_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
    ])

  let assert Ok(offset_subpath) =
    offset.subpath_untrimmed(subpath, distance: 2.0)

  assert serialize.subpath(offset_subpath) == "M 0 -2 H 10 H 12 V 0 V 10"
}

pub fn subpath_untrimmed_offsets_open_polyline_with_round_join_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
    ])
  let options = offset.Options(..offset.default_options(), join: offset.Round)

  let assert Ok(offset_subpath) =
    offset.subpath_untrimmed_with(subpath, distance: 2.0, options:)

  assert has_arc(svg_path.subpath_segments(offset_subpath))
  assert serialize.subpath(offset_subpath)
    == "M 0 -2 H 10 A 2 2 0 0 1 12 0 V 10"
}

pub fn subpath_untrimmed_round_join_uses_source_corner_center_test() {
  let source =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(1.0, 0.0),
        end: svg_path.Point(3.0, 0.0),
      ),
      svg_path.Arc(
        start: svg_path.Point(3.0, 0.0),
        radius: svg_path.Point(1.0, 1.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: False,
        end: svg_path.Point(4.0, 1.0),
      ),
    ])
  let options = offset.Options(..offset.default_options(), join: offset.Round)

  let assert Ok(offset_subpath) =
    offset.subpath_untrimmed_with(source, distance: 1.8, options:)

  assert serialize.subpath(offset_subpath)
    == "M 1 -1.8 H 3 A 1.8 1.8 0 0 1 4.8 0 A 0.8 0.8 0 0 0 4 -0.8"
}

pub fn subpath_band_side_trimming_removes_round_join_loops_test() {
  let source =
    svg_path.subpath_assert([
      svg_path.Line(
        start: svg_path.Point(1.0, 0.0),
        end: svg_path.Point(3.0, 0.0),
      ),
      svg_path.Arc(
        start: svg_path.Point(3.0, 0.0),
        radius: svg_path.Point(1.0, 1.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: False,
        end: svg_path.Point(4.0, 1.0),
      ),
      svg_path.Line(
        start: svg_path.Point(4.0, 1.0),
        end: svg_path.Point(4.0, 3.0),
      ),
      svg_path.Line(
        start: svg_path.Point(4.0, 3.0),
        end: svg_path.Point(3.0, 4.0),
      ),
      svg_path.Line(
        start: svg_path.Point(3.0, 4.0),
        end: svg_path.Point(1.0, 4.0),
      ),
      svg_path.Arc(
        start: svg_path.Point(1.0, 4.0),
        radius: svg_path.Point(1.0, 1.0),
        x_axis_rotation: 0.0,
        large_arc: False,
        sweep: False,
        end: svg_path.Point(0.0, 3.0),
      ),
      svg_path.Line(
        start: svg_path.Point(0.0, 3.0),
        end: svg_path.Point(0.0, 1.0),
      ),
      svg_path.Line(
        start: svg_path.Point(0.0, 1.0),
        end: svg_path.Point(1.0, 0.0),
      ),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)
  let options = offset.Options(..offset.default_options(), join: offset.Round)

  let assert Ok(band) =
    offset.subpath_band_with(source, distance_a: 1.7, distance_b: 1.8, options:)
  assert list.length(svg_path.path_subpaths(band)) == 2
}

pub fn subpath_offsets_open_polyline_to_trimmed_intersection_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, -10.0),
    ])

  let assert Ok(offset_path) = offset.subpath(subpath, distance: 2.0)

  assert serialize.path(offset_path) == "M 0 -2 H 8 V -10"
}

pub fn subpath_offsets_closed_square_inset_test() {
  let square =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
      svg_path.Point(0.0, 10.0),
    ])

  let assert Ok(offset_path) = offset.subpath(square, distance: -2.0)
  let assert [offset_subpath] = svg_path.path_subpaths(offset_path)

  assert svg_path.subpath_is_closed(offset_subpath)
  assert serialize.subpath(offset_subpath) == "M 2 2 H 8 V 8 H 2 Z"
}

pub fn subpath_untrimmed_offsets_closed_square_and_preserves_closed_state_test() {
  let square =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
      svg_path.Point(0.0, 10.0),
    ])

  let assert Ok(offset_subpath) =
    offset.subpath_untrimmed(square, distance: 2.0)

  assert svg_path.subpath_is_closed(offset_subpath)
  assert list.length(svg_path.subpath_segments(offset_subpath)) == 12
}

pub fn path_untrimmed_offsets_every_subpath_test() {
  let first =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])
  let second =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 10.0),
      svg_path.Point(10.0, 10.0),
    ])
  let path = svg_path.Path(subpaths: [first, second])

  let assert Ok(offset_path) = offset.path_untrimmed(path, distance: 1.0)

  assert list.length(svg_path.path_subpaths(offset_path)) == 2
  assert serialize.path(offset_path) == "M 0 -1 H 10 M 0 9 H 10"
}

pub fn path_offsets_straight_subpaths_test() {
  let first =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, -10.0),
    ])
  let second =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 20.0),
      svg_path.Point(10.0, 20.0),
      svg_path.Point(10.0, 10.0),
    ])
  let path = svg_path.Path(subpaths: [first, second])

  let assert Ok(offset_path) = offset.path(path, distance: 2.0)

  assert list.length(svg_path.path_subpaths(offset_path)) == 2
  assert serialize.path(offset_path) == "M 0 -2 H 8 V -10 M 0 18 H 8 V 10"
}

pub fn provisional_arrangement_nodes_crossing_subpaths_test() {
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
      tolerance: 0.000000002,
      minimum_chord: 0.000000002,
    )

  assert list.length(build.graph.vertices) == 5
  assert list.length(build.graph.edges) == 4
  assert list.all(build.graph.edges, fn(edge) {
    edge.forward_multiplicity == 1 && edge.reverse_multiplicity == 0
  })
}

pub fn provisional_arrangement_consolidates_coincident_pieces_test() {
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
      tolerance: 0.000000002,
      minimum_chord: 0.000000002,
    )

  assert list.length(build.graph.vertices) == 3
  assert list.length(build.graph.edges) == 2
  assert list.all(build.graph.edges, fn(edge) {
    edge.forward_multiplicity == 2 && edge.reverse_multiplicity == 0
  })
}

pub fn arrangement_global_sections_expand_coincident_multiplicity_test() {
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

  let assert Ok(sections) =
    offset.internal_arrangement_global_sections(
      [whole, divided],
      options: offset.default_options(),
    )

  assert serialize.path(sections) == "M 0 0 H 5 M 5 0 H 10 M 0 0 H 5 M 5 0 H 10"
}

pub fn arrangement_global_sections_preserve_opposite_multiplicity_test() {
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
      tolerance: 0.000000002,
      minimum_chord: 0.000000002,
    )
  let assert [edge] = build.graph.edges
  assert edge.forward_multiplicity == 1
  assert edge.reverse_multiplicity == 1

  let assert Ok(sections) =
    offset.internal_arrangement_global_sections(
      [forward, reverse],
      options: offset.default_options(),
    )
  assert serialize.path(sections) == "M 0 0 H 10 M 10 0 H 0"
}

pub fn subpath_band_open_line_returns_two_capless_sides_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])

  let assert Ok(offset_path) =
    offset.subpath_band(subpath, distance_a: -1.0, distance_b: 2.0)

  assert list.length(svg_path.path_subpaths(offset_path)) == 2
  assert serialize.path(offset_path) == "M 0 1 H 10 M 0 -2 H 10"
}

pub fn subpath_band_closed_square_returns_two_closed_sides_test() {
  let square =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
      svg_path.Point(0.0, 10.0),
    ])

  let assert Ok(offset_path) =
    offset.subpath_band(square, distance_a: -2.0, distance_b: 2.0)
  let assert [inner, outer] = svg_path.path_subpaths(offset_path)

  assert svg_path.subpath_is_closed(inner)
  assert svg_path.subpath_is_closed(outer)
  assert serialize.path(offset_path)
    == "M 2 2 V 8 H 8 V 2 Z M 0 -2 H 10 H 12 V 0 V 10 V 12 H 10 H 0 H -2 V 10 V 0 V -2 Z"
}

pub fn concave_band_orients_overlapping_contours_for_nonzero_fill_test() {
  let source =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(150.0, 0.0),
      svg_path.Point(150.0, 38.0),
      svg_path.Point(94.0, 38.0),
      svg_path.Point(94.0, 78.0),
      svg_path.Point(150.0, 78.0),
      svg_path.Point(150.0, 116.0),
      svg_path.Point(0.0, 116.0),
    ])
  let default = offset.default_options()
  let options =
    offset.Options(
      ..default,
      fitting: offset.FittingOptions(..default.fitting, tolerance: 0.01),
      join: offset.Round,
    )
  let assert Ok(band) = offset.subpath_band_with(source, -12.0, -14.0, options)
  let dominant_areas =
    svg_path.path_subpaths(band)
    |> list.map(area.signed_subpath)
    |> list.filter(fn(value) { float.absolute_value(value) >. 1000.0 })
  let assert [first, second] = dominant_areas

  assert first *. second <. 0.0
}

pub fn figure_eight_band_joins_reversed_outer_chunks_test() {
  let figure_eight =
    svg_path.subpath_assert([
      svg_path.CubicBezier(
        start: svg_path.Point(0.0, 0.0),
        control1: svg_path.Point(-336.0, -234.0),
        control2: svg_path.Point(-336.0, 234.0),
        end: svg_path.Point(0.0, 0.0),
      ),
      svg_path.CubicBezier(
        start: svg_path.Point(0.0, 0.0),
        control1: svg_path.Point(336.0, -234.0),
        control2: svg_path.Point(336.0, 234.0),
        end: svg_path.Point(0.0, 0.0),
      ),
    ])
    |> svg_path.subpath_assert_set_closed(closed: True)
  let options = offset.Options(..offset.default_options(), join: offset.Round)

  let assert Ok(band) =
    offset.subpath_band_with(
      figure_eight,
      distance_a: 18.0,
      distance_b: 34.0,
      options:,
    )
  let subpaths = svg_path.path_subpaths(band)

  assert list.length(subpaths) == 3
  assert list.all(subpaths, svg_path.subpath_is_closed)
}

pub fn path_band_offsets_every_subpath_on_both_sides_test() {
  let first =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])
  let second =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 10.0),
      svg_path.Point(10.0, 10.0),
    ])
  let path = svg_path.Path(subpaths: [first, second])

  let assert Ok(offset_path) =
    offset.path_band(path, distance_a: -1.0, distance_b: 1.0)

  assert list.length(svg_path.path_subpaths(offset_path)) == 4
  assert serialize.path(offset_path)
    == "M 0 1 H 10 M 0 -1 H 10 M 0 11 H 10 M 0 9 H 10"
}

pub fn subpath_band_untrimmed_returns_two_raw_sides_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
    ])

  let assert Ok(offset_path) =
    offset.subpath_band_untrimmed(subpath, distance_a: -1.0, distance_b: 2.0)

  assert list.length(svg_path.path_subpaths(offset_path)) == 2
  assert serialize.path(offset_path)
    == "M 0 1 H 10 L 9 0 V 10 M 0 -2 H 10 H 12 V 0 V 10"
}

pub fn path_band_untrimmed_returns_two_raw_sides_per_subpath_test() {
  let first =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])
  let second =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 10.0),
      svg_path.Point(10.0, 10.0),
    ])
  let path = svg_path.Path(subpaths: [first, second])

  let assert Ok(offset_path) =
    offset.path_band_untrimmed(path, distance_a: -1.0, distance_b: 1.0)

  assert list.length(svg_path.path_subpaths(offset_path)) == 4
  assert serialize.path(offset_path)
    == "M 0 1 H 10 M 0 -1 H 10 M 0 11 H 10 M 0 9 H 10"
}

pub fn subpath_stroke_open_line_with_butt_cap_returns_closed_outline_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])

  let assert Ok(stroke) = offset.subpath_stroke(subpath, width: 2.0)

  assert list.length(svg_path.path_subpaths(stroke)) == 1
  assert serialize.path(stroke) == "M 0 -1 H 10 V 1 H 0 Z"
}

pub fn subpath_stroke_open_line_with_square_cap_extends_ends_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])

  let assert Ok(stroke) =
    offset.subpath_stroke_with(
      subpath,
      width: 2.0,
      cap: offset.Square,
      options: offset.default_options(),
    )

  assert serialize.path(stroke) == "M 0 -1 H 10 H 11 V 1 H 10 H 0 H -1 V -1 Z"
}

pub fn subpath_stroke_closed_square_uses_band_test() {
  let square =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
      svg_path.Point(0.0, 10.0),
    ])

  let assert Ok(stroke) = offset.subpath_stroke(square, width: 4.0)

  assert serialize.path(stroke)
    == "M 2 2 V 8 H 8 V 2 Z M 0 -2 H 10 H 12 V 0 V 10 V 12 H 10 H 0 H -2 V 10 V 0 V -2 Z"
}

pub fn subpath_stroke_rejects_invalid_width_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])

  assert offset.subpath_stroke(subpath, width: 0.0)
    == Error(offset.InvalidStrokeWidth(0.0))
}

pub fn band_inside_function_uses_nonzero_for_open_subpath_band_test() {
  let outline =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
      svg_path.Point(0.0, 10.0),
    ])
  let assert Ok(inside) =
    offset.internal_band_inside_function([offset.OpenSubpathBand(outline)])

  assert inside(svg_path.Point(5.0, 5.0)) == Ok(True)
  assert inside(svg_path.Point(15.0, 5.0)) == Ok(False)
}

pub fn band_inside_function_reverses_second_closed_subpath_side_test() {
  let outer =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
      svg_path.Point(0.0, 10.0),
    ])
  let inner =
    svg_path.subpath_assert_polygon([
      svg_path.Point(2.0, 2.0),
      svg_path.Point(8.0, 2.0),
      svg_path.Point(8.0, 8.0),
      svg_path.Point(2.0, 8.0),
    ])
  let assert Ok(inside) =
    offset.internal_band_inside_function([
      offset.ClosedSubpathBand(outer, inner),
    ])

  assert inside(svg_path.Point(1.0, 1.0)) == Ok(True)
  assert inside(svg_path.Point(5.0, 5.0)) == Ok(False)
  assert inside(svg_path.Point(12.0, 5.0)) == Ok(False)
}

pub fn band_inside_function_rejects_open_payload_test() {
  let open =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])

  assert offset.internal_band_inside_function([offset.OpenSubpathBand(open)])
    == Error(offset.BandSubpathNotClosed)
}

pub fn segment_is_submerged_checks_both_immediate_sides_test() {
  let outline =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
      svg_path.Point(0.0, 10.0),
    ])
  let assert Ok(inside) =
    offset.internal_band_inside_function([offset.OpenSubpathBand(outline)])
  let middle =
    svg_path.Line(
      start: svg_path.Point(2.0, 5.0),
      end: svg_path.Point(8.0, 5.0),
    )
  let boundary =
    svg_path.Line(
      start: svg_path.Point(2.0, 0.0),
      end: svg_path.Point(8.0, 0.0),
    )

  assert offset.internal_segment_is_submerged(
      middle,
      inside:,
      side_sampling_distance: 0.5,
    )
    == Ok(True)
  assert offset.internal_segment_is_submerged(
      boundary,
      inside:,
      side_sampling_distance: 0.5,
    )
    == Ok(False)
}

pub fn topological_band_loops_filters_submerged_loop_test() {
  let loop = square_loop()
  let containing_band =
    svg_path.subpath_assert_polygon([
      svg_path.Point(-1.0, -1.0),
      svg_path.Point(11.0, -1.0),
      svg_path.Point(11.0, 11.0),
      svg_path.Point(-1.0, 11.0),
    ])

  assert offset.internal_topological_band_loops(
      [loop],
      bands: [offset.OpenSubpathBand(containing_band)],
      options: offset.default_options(),
    )
    == Ok([])
}

pub fn single_offset_band_candidate_closes_open_source_test() {
  let open =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])

  let assert Ok(offset.OpenSubpathBand(outline)) =
    offset.internal_single_offset_band_candidate(
      open,
      distance: 2.0,
      options: offset.default_options(),
    )

  assert svg_path.subpath_is_closed(outline)
}

pub fn single_offset_band_candidate_keeps_closed_source_as_two_sides_test() {
  let closed = square_loop()

  let assert Ok(offset.ClosedSubpathBand(side_a:, side_b:)) =
    offset.internal_single_offset_band_candidate(
      closed,
      distance: 2.0,
      options: offset.default_options(),
    )

  assert svg_path.subpath_is_closed(side_a)
  assert svg_path.subpath_is_closed(side_b)
}

pub fn stroke_band_candidate_closes_open_source_test() {
  let open =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])

  let assert Ok(offset.OpenSubpathBand(outline)) =
    offset.internal_stroke_band_candidate(
      open,
      width: 4.0,
      cap: offset.Butt,
      options: offset.default_options(),
    )

  assert svg_path.subpath_is_closed(outline)
}

pub fn subpath_prunes_self_crossed_inset_sections_test() {
  let shape =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(120.0, 0.0),
      svg_path.Point(120.0, 30.0),
      svg_path.Point(70.0, 30.0),
      svg_path.Point(70.0, 90.0),
      svg_path.Point(120.0, 90.0),
      svg_path.Point(120.0, 120.0),
      svg_path.Point(0.0, 120.0),
    ])

  let options = offset.Options(..offset.default_options(), join: offset.Round)
  let assert Ok(trimmed) = offset.subpath_with(shape, distance: -24.0, options:)

  assert serialize.path(trimmed)
    == "M 24 24 H 46.7621 A 24 24 0 0 0 46 30 V 90 A 24 24 0 0 0 46.7621 96 H 24 Z"
}

pub fn path_offsets_closed_subpaths_test() {
  let first =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
      svg_path.Point(0.0, 10.0),
    ])
  let second =
    svg_path.subpath_assert_polygon([
      svg_path.Point(20.0, 0.0),
      svg_path.Point(30.0, 0.0),
      svg_path.Point(30.0, 10.0),
      svg_path.Point(20.0, 10.0),
    ])
  let path = svg_path.Path(subpaths: [first, second])

  let assert Ok(trimmed) = offset.path(path, distance: -2.0)

  assert list.length(svg_path.path_subpaths(trimmed)) == 2
  assert serialize.path(trimmed) == "M 2 2 H 8 V 8 H 2 Z M 22 2 H 28 V 8 H 22 Z"
}

pub fn subpath_offsets_open_polyline_with_default_miter_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
    ])

  let assert Ok(offset_path) = offset.subpath(subpath, distance: 2.0)

  assert serialize.path(offset_path) == "M 0 -2 H 10 H 12 V 0 V 10"
}

pub fn subpath_can_use_round_join_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
    ])
  let options = offset.Options(..offset.default_options(), join: offset.Round)

  let assert Ok(offset_path) =
    offset.subpath_with(subpath, distance: 2.0, options:)

  assert serialize.path(offset_path) == "M 0 -2 H 10 A 2 2 0 0 1 12 0 V 10"
}

pub fn subpath_can_use_bevel_join_test() {
  let subpath =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
      svg_path.Point(10.0, 10.0),
    ])
  let options = offset.Options(..offset.default_options(), join: offset.Bevel)

  let assert Ok(offset_path) =
    offset.subpath_with(subpath, distance: 2.0, options:)

  assert serialize.path(offset_path) == "M 0 -2 H 10 L 12 0 V 10"
}

pub fn subpath_prunes_negative_inset_sections_test() {
  let shape =
    svg_path.subpath_assert_polygon([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(120.0, 0.0),
      svg_path.Point(120.0, 30.0),
      svg_path.Point(70.0, 30.0),
      svg_path.Point(70.0, 90.0),
      svg_path.Point(120.0, 90.0),
      svg_path.Point(120.0, 120.0),
      svg_path.Point(0.0, 120.0),
    ])

  let options = offset.Options(..offset.default_options(), join: offset.Round)
  let assert Ok(parametric) =
    offset.subpath_with(shape, distance: -24.0, options:)

  assert list.length(svg_path.path_subpaths(parametric)) == 1
  assert serialize.path(parametric)
    == "M 24 24 H 46.7621 A 24 24 0 0 0 46 30 V 90 A 24 24 0 0 0 46.7621 96 H 24 Z"
}

pub fn subpath_ignores_adjacent_local_contacts_test() {
  let assert Ok(shape) =
    svg_path.subpath([
      svg_path.CubicBezier(
        start: svg_path.Point(0.0, 0.0),
        control1: svg_path.Point(60.0, -75.0),
        control2: svg_path.Point(115.0, -75.0),
        end: svg_path.Point(75.0, 0.0),
      ),
      svg_path.CubicBezier(
        start: svg_path.Point(75.0, 0.0),
        control1: svg_path.Point(115.0, 75.0),
        control2: svg_path.Point(60.0, 75.0),
        end: svg_path.Point(0.0, 0.0),
      ),
      svg_path.CubicBezier(
        start: svg_path.Point(0.0, 0.0),
        control1: svg_path.Point(-60.0, -75.0),
        control2: svg_path.Point(-115.0, -75.0),
        end: svg_path.Point(-75.0, 0.0),
      ),
      svg_path.CubicBezier(
        start: svg_path.Point(-75.0, 0.0),
        control1: svg_path.Point(-115.0, 75.0),
        control2: svg_path.Point(-60.0, 75.0),
        end: svg_path.Point(0.0, 0.0),
      ),
    ])

  let options = offset.Options(..offset.default_options(), join: offset.Round)
  let assert Ok(parametric) =
    offset.subpath_with(shape, distance: -16.0, options:)

  assert list.length(svg_path.path_subpaths(parametric)) == 1
}

pub fn path_offsets_every_subpath_test() {
  let first =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 0.0),
      svg_path.Point(10.0, 0.0),
    ])
  let second =
    svg_path.subpath_assert_polyline([
      svg_path.Point(0.0, 10.0),
      svg_path.Point(10.0, 10.0),
    ])
  let path = svg_path.Path(subpaths: [first, second])

  let assert Ok(offset_path) = offset.path(path, distance: 1.0)

  assert list.length(svg_path.path_subpaths(offset_path)) == 2
  assert serialize.path(offset_path) == "M 0 -1 H 10 M 0 9 H 10"
}

pub fn generate_stalled_arc_turn_offset_debug_fixture() {
  let cases = stalled_arc_turn_cases()
  let _ = write_file(stalled_arc_turn_svg_output, stalled_arc_turn_svg(cases))
  let _ =
    write_file(
      stalled_arc_turn_zoom_svg_output,
      stalled_arc_turn_zoom_svg(cases),
    )
  let _ =
    write_file(stalled_arc_turn_report_output, stalled_arc_turn_report(cases))
  Nil
}

pub fn stalled_arc_turn_offset_catches_expected_stalled_segments_test() {
  let cases = stalled_arc_turn_cases()
  let caught_counts =
    cases
    |> list.map(fn(example) {
      let #(_, _, _, source, _) = example
      count_stalled_segments(svg_path.subpath_segments(source))
    })

  assert caught_counts == [1, 4, 30, 1, 4, 30]
}

fn stalled_arc_turn_cases() {
  let subdivisions = [1, 4, 30]
  list.append(
    subdivisions
      |> list.map(fn(count) {
        stalled_arc_turn_case("real arcs", "arc", count, use_arcs: True)
      }),
    subdivisions
      |> list.map(fn(count) {
        stalled_arc_turn_case(
          "cubic approximation",
          "cubic",
          count,
          use_arcs: False,
        )
      }),
  )
}

fn stalled_arc_turn_case(
  row_label: String,
  unit_label: String,
  subdivisions: Int,
  use_arcs use_arcs: Bool,
) -> #(
  String,
  String,
  Int,
  svg_path.Subpath,
  Result(svg_path.Subpath, offset.Error),
) {
  let source = stalled_arc_turn_source(subdivisions, use_arcs:)
  let default = offset.default_options()
  let options =
    offset.Options(
      ..default,
      fitting: offset.FittingOptions(..default.fitting, tolerance: 0.001),
      join: offset.Round,
    )
  let result =
    offset.subpath_untrimmed_with(
      source,
      distance: stalled_arc_turn_distance,
      options:,
    )
  #(row_label, unit_label, subdivisions, source, result)
}

fn max_offset_error(
  source: svg_path.Segment,
  offset_subpath: svg_path.Subpath,
  distance distance: Float,
) -> Float {
  max_offset_error_loop(source, offset_subpath, distance, sample: 1, best: 0.0)
}

fn max_offset_error_loop(
  source: svg_path.Segment,
  offset_subpath: svg_path.Subpath,
  distance: Float,
  sample sample: Int,
  best best: Float,
) -> Float {
  case sample > 19 {
    True -> best
    False -> {
      let t = int.to_float(sample) /. 20.0
      let assert Ok(point) = svg_path.segment_point(source, at: t)
      let assert Ok(derivative) = svg_path.segment_derivative(source, at: t)
      let normal = right_unit_normal(derivative)
      let extruded =
        svg_path.Point(
          point.x +. normal.x *. distance,
          point.y +. normal.y *. distance,
        )
      let assert Ok(projection) =
        svg_path.subpath_projection(extruded, to: offset_subpath)

      max_offset_error_loop(
        source,
        offset_subpath,
        distance,
        sample: sample + 1,
        best: float.max(best, projection.distance),
      )
    }
  }
}

fn right_unit_normal(point: svg_path.Point) -> svg_path.Point {
  let length = distance(svg_path.Point(0.0, 0.0), point)
  svg_path.Point(point.y /. length, { 0.0 -. point.x } /. length)
}

fn has_arc(segments: List(svg_path.Segment)) -> Bool {
  list.any(segments, fn(segment) {
    case segment {
      svg_path.Arc(..) -> True
      _ -> False
    }
  })
}

fn distance(a: svg_path.Point, b: svg_path.Point) -> Float {
  let assert Ok(distance) =
    float.square_root(
      { a.x -. b.x } *. { a.x -. b.x } +. { a.y -. b.y } *. { a.y -. b.y },
    )
  distance
}

fn stalled_arc_turn_source(
  subdivisions: Int,
  use_arcs use_arcs: Bool,
) -> svg_path.Subpath {
  let r = stalled_arc_turn_radius
  let arc_start = circle_point(0.0, radius: r)
  let arc_end = circle_point(-90.0, radius: r)
  let turn_segments = case use_arcs {
    True -> quarter_turn_arcs(subdivisions)
    False -> quarter_turn_cubics(subdivisions)
  }
  let segments = [
    svg_path.Line(start: svg_path.Point(r, r), end: arc_start),
    ..list.append(turn_segments, [
      svg_path.Line(start: arc_end, end: svg_path.Point(0.0 -. r, 0.0 -. r)),
    ])
  ]
  let assert Ok(subpath) = svg_path.subpath(segments)
  subpath
}

fn quarter_turn_arcs(subdivisions: Int) -> List(svg_path.Segment) {
  quarter_turn_arcs_loop(0, subdivisions, arcs: [])
}

fn quarter_turn_arcs_loop(
  index: Int,
  subdivisions: Int,
  arcs arcs: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case index >= subdivisions {
    True -> list.reverse(arcs)
    False -> {
      let step = -90.0 /. int.to_float(subdivisions)
      let start_angle = int.to_float(index) *. step
      let end_angle = int.to_float(index + 1) *. step
      quarter_turn_arcs_loop(index + 1, subdivisions, arcs: [
        circle_arc_segment(
          start_angle,
          end_angle,
          radius: stalled_arc_turn_radius,
        ),
        ..arcs
      ])
    }
  }
}

fn circle_arc_segment(
  start_angle: Float,
  end_angle: Float,
  radius radius: Float,
) -> svg_path.Segment {
  svg_path.Arc(
    start: circle_point(start_angle, radius:),
    radius: svg_path.Point(radius, radius),
    x_axis_rotation: 0.0,
    large_arc: False,
    sweep: False,
    end: circle_point(end_angle, radius:),
  )
}

fn quarter_turn_cubics(subdivisions: Int) -> List(svg_path.Segment) {
  quarter_turn_cubics_loop(0, subdivisions, cubics: [])
}

fn quarter_turn_cubics_loop(
  index: Int,
  subdivisions: Int,
  cubics cubics: List(svg_path.Segment),
) -> List(svg_path.Segment) {
  case index >= subdivisions {
    True -> list.reverse(cubics)
    False -> {
      let step = -90.0 /. int.to_float(subdivisions)
      let start_angle = int.to_float(index) *. step
      let end_angle = int.to_float(index + 1) *. step
      quarter_turn_cubics_loop(index + 1, subdivisions, cubics: [
        circle_arc_cubic(
          start_angle,
          end_angle,
          radius: stalled_arc_turn_radius,
        ),
        ..cubics
      ])
    }
  }
}

fn circle_arc_cubic(
  start_angle: Float,
  end_angle: Float,
  radius radius: Float,
) -> svg_path.Segment {
  let start = circle_point(start_angle, radius:)
  let end = circle_point(end_angle, radius:)
  let k = 4.0 /. 3.0 *. trig.tan_degrees({ end_angle -. start_angle } /. 4.0)
  let start_tangent = circle_angle_tangent(start_angle)
  let end_tangent = circle_angle_tangent(end_angle)
  svg_path.CubicBezier(
    start:,
    control1: add_point(start, scale_point(start_tangent, k *. radius)),
    control2: subtract_point(end, scale_point(end_tangent, k *. radius)),
    end:,
  )
}

fn circle_point(angle: Float, radius radius: Float) -> svg_path.Point {
  svg_path.Point(
    clean_zero(radius *. trig.cos_degrees(angle)),
    clean_zero(radius *. trig.sin_degrees(angle)),
  )
}

fn clean_zero(value: Float) -> Float {
  case float.absolute_value(value) <=. 0.000000000001 {
    True -> 0.0
    False -> value
  }
}

fn assert_near(actual: Float, expected: Float) -> Nil {
  assert float.absolute_value(actual -. expected) <=. 0.000000001
}

fn assert_reversal_gap(
  incoming_direction incoming_direction: svg_path.Point,
  outgoing_direction outgoing_direction: svg_path.Point,
  adjustment adjustment: offset.ReversalTangentAdjustment,
  expected_turn expected_turn: offset.TangentTurn,
  at_least at_least: Float,
) -> Nil {
  let offset.ReversalTangentAdjustment(incoming_degrees:, outgoing_degrees:) =
    adjustment
  let incoming = rotate_direction(incoming_direction, incoming_degrees)
  let outgoing = rotate_direction(outgoing_direction, outgoing_degrees)
  let opposite_outgoing = svg_path.Point(0.0 -. outgoing.x, 0.0 -. outgoing.y)
  let gap = case expected_turn {
    offset.Clockwise ->
      point.clockwise_aperture(from: incoming, to: opposite_outgoing)
    offset.CounterClockwise ->
      point.clockwise_aperture(from: opposite_outgoing, to: incoming)
    offset.Straight -> 0.0
    offset.CouldNotMeasure -> 0.0
  }
  assert gap +. 0.000000001 >=. at_least
  assert gap <=. 180.0
}

fn rotate_direction(
  direction: svg_path.Point,
  degrees: Float,
) -> svg_path.Point {
  point.direction(degrees: point.heading(direction) +. degrees)
}

fn circle_angle_tangent(angle: Float) -> svg_path.Point {
  svg_path.Point(0.0 -. trig.sin_degrees(angle), trig.cos_degrees(angle))
}

fn count_stalled_segments(segments: List(svg_path.Segment)) -> Int {
  segments
  |> list.filter(stalled_arc_turn_segment_is_caught)
  |> list.length
}

fn stalled_arc_turn_segment_is_caught(segment: svg_path.Segment) -> Bool {
  let start = offset_endpoint(segment, 0.0)
  let end = offset_endpoint(segment, 1.0)
  case start, end {
    Ok(start), Ok(end) -> distance(start, end) <=. stalled_arc_turn_threshold
    _, _ -> False
  }
}

fn offset_endpoint(
  segment: svg_path.Segment,
  t: Float,
) -> Result(svg_path.Point, Nil) {
  case
    svg_path.segment_point(segment, at: t),
    svg_path.segment_derivative(segment, at: t)
  {
    Ok(point), Ok(derivative) -> {
      let normal = right_unit_normal(derivative)
      Ok(add_point(point, scale_point(normal, stalled_arc_turn_distance)))
    }
    _, _ -> Error(Nil)
  }
}

fn stalled_arc_turn_report(
  cases: List(
    #(
      String,
      String,
      Int,
      svg_path.Subpath,
      Result(svg_path.Subpath, offset.Error),
    ),
  ),
) -> String {
  string.join(
    [
      "stalled arc turn offset fixture",
      "radius: " <> f(stalled_arc_turn_radius),
      "distance: " <> f(stalled_arc_turn_distance),
      "classifier threshold: " <> f(stalled_arc_turn_threshold),
      "",
      ..cases
      |> list.map(stalled_arc_turn_case_report)
    ],
    "\n",
  )
}

fn stalled_arc_turn_case_report(
  example: #(
    String,
    String,
    Int,
    svg_path.Subpath,
    Result(svg_path.Subpath, offset.Error),
  ),
) -> String {
  let #(row_label, unit_label, subdivisions, source, result) = example
  let source_segments = svg_path.subpath_segments(source)
  let caught = count_stalled_segments(source_segments)
  row_label
  <> "; subdivisions: "
  <> int.to_string(subdivisions)
  <> " "
  <> unit_label
  <> case subdivisions == 1 {
    True -> ""
    False -> "s"
  }
  <> "\n"
  <> "  source segments: "
  <> int.to_string(list.length(source_segments))
  <> "\n"
  <> "  near-collapsed offset chords: "
  <> int.to_string(caught)
  <> "\n"
  <> "  corner offset section: "
  <> stalled_arc_turn_corner_summary(result)
  <> "\n"
  <> "  result: "
  <> stalled_arc_turn_offset_result_summary(result)
}

fn stalled_arc_turn_corner_summary(
  result: Result(svg_path.Subpath, offset.Error),
) -> String {
  case result {
    Error(error) -> "Error: " <> string.inspect(error)
    Ok(subpath) -> {
      let segments = stalled_arc_turn_corner_segments(subpath)
      "segments="
      <> int.to_string(list.length(segments))
      <> "; length="
      <> f(stalled_arc_turn_segments_length(segments))
    }
  }
}

fn stalled_arc_turn_offset_result_summary(
  result: Result(svg_path.Subpath, offset.Error),
) -> String {
  case result {
    Ok(subpath) ->
      "Ok; output segments: "
      <> int.to_string(list.length(svg_path.subpath_segments(subpath)))
      <> "; path: "
      <> serialize.subpath(subpath)
    Error(error) -> "Error: " <> string.inspect(error)
  }
}

fn stalled_arc_turn_corner_label(
  result: Result(svg_path.Subpath, offset.Error),
) -> String {
  case result {
    Error(_) -> "Error"
    Ok(subpath) -> {
      let segments = stalled_arc_turn_corner_segments(subpath)
      int.to_string(list.length(segments))
      <> " seg; length "
      <> f(stalled_arc_turn_segments_length(segments))
    }
  }
}

fn stalled_arc_turn_corner_segment_count(
  result: Result(svg_path.Subpath, offset.Error),
) -> String {
  case result {
    Error(_) -> "Error"
    Ok(subpath) ->
      subpath
      |> stalled_arc_turn_corner_segments
      |> list.length
      |> int.to_string
  }
}

fn stalled_arc_turn_corner_segments(
  subpath: svg_path.Subpath,
) -> List(svg_path.Segment) {
  case svg_path.subpath_segments(subpath) {
    [] | [_] | [_, _] -> []
    [_, ..rest] ->
      case list.take(rest, list.length(rest) - 1) {
        middle -> middle
      }
  }
}

fn stalled_arc_turn_segments_length(segments: List(svg_path.Segment)) -> Float {
  segments
  |> list.fold(0.0, fn(total, segment) {
    case svg_path.segment_length(segment) {
      Ok(length) -> total +. length
      Error(_) -> total
    }
  })
}

fn stalled_arc_turn_svg(
  cases: List(
    #(
      String,
      String,
      Int,
      svg_path.Subpath,
      Result(svg_path.Subpath, offset.Error),
    ),
  ),
) -> String {
  "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 860 570\" width=\"860\" height=\"570\">\n"
  <> "  <rect width=\"100%\" height=\"100%\" fill=\"#ffffff\"/>\n"
  <> "  <text x=\"430\" y=\"28\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"16\" text-anchor=\"middle\" fill=\"#111827\">near-collapsed quarter-turn offsets</text>\n"
  <> string.join(list.index_map(cases, stalled_arc_turn_panel), "\n")
  <> "\n</svg>\n"
}

fn stalled_arc_turn_zoom_svg(
  cases: List(
    #(
      String,
      String,
      Int,
      svg_path.Subpath,
      Result(svg_path.Subpath, offset.Error),
    ),
  ),
) -> String {
  "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 860 650\" width=\"860\" height=\"650\">\n"
  <> "  <rect width=\"100%\" height=\"100%\" fill=\"#ffffff\"/>\n"
  <> "  <text x=\"430\" y=\"30\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"15\" text-anchor=\"middle\" fill=\"#111827\">corner zoom; distance="
  <> f(stalled_arc_turn_distance)
  <> "; threshold="
  <> f(stalled_arc_turn_threshold)
  <> "</text>\n"
  <> string.join(list.index_map(cases, stalled_arc_turn_zoom_panel), "\n")
  <> "\n</svg>\n"
}

fn stalled_arc_turn_zoom_panel(
  example: #(
    String,
    String,
    Int,
    svg_path.Subpath,
    Result(svg_path.Subpath, offset.Error),
  ),
  index: Int,
) -> String {
  let #(row_label, unit_label, subdivisions, source, result) = example
  let #(clip_x, clip_y, clip_size) = stalled_arc_turn_zoom_box(source, result)
  let scale = 220.0 /. clip_size
  let column = index % 3
  let row = index / 3
  let panel_x = 145.0 +. int.to_float(column) *. 280.0
  let panel_y = 170.0 +. int.to_float(row) *. 260.0
  let tx = panel_x -. { clip_x +. clip_size /. 2.0 } *. scale
  let ty = panel_y -. { clip_y +. clip_size /. 2.0 } *. scale
  let source_path = serialize.subpath(source)
  let stalled_segments =
    svg_path.subpath_segments(source)
    |> list.filter(stalled_arc_turn_segment_is_caught)
    |> serialize_segments
  let output = case result {
    Ok(subpath) ->
      "    <path d=\""
      <> escape(serialize.subpath(subpath))
      <> "\" style=\"fill: none; stroke: #1d4ed8; stroke-width: 0.00008; stroke-linecap: round; stroke-linejoin: round\" />\n"
      <> "    <circle cx=\"0\" cy=\"0\" r=\"0.00008\" fill=\"#111827\" />\n"
      <> stalled_arc_turn_output_control_marks(subpath)
    Error(error) ->
      "    <text x=\"0\" y=\"0.0016\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"0.0003\" text-anchor=\"middle\" fill=\"#b91c1c\">"
      <> escape(string.inspect(error))
      <> "</text>\n"
  }

  "  <g transform=\"translate("
  <> f(tx)
  <> " "
  <> f(ty)
  <> ") scale("
  <> f(scale)
  <> ")\">\n"
  <> "    <clipPath id=\"corner-zoom-clip-"
  <> int.to_string(index)
  <> "\"><rect x=\""
  <> f(clip_x)
  <> "\" y=\""
  <> f(clip_y)
  <> "\" width=\""
  <> f(clip_size)
  <> "\" height=\""
  <> f(clip_size)
  <> "\" /></clipPath>\n"
  <> "    <rect x=\""
  <> f(clip_x)
  <> "\" y=\""
  <> f(clip_y)
  <> "\" width=\""
  <> f(clip_size)
  <> "\" height=\""
  <> f(clip_size)
  <> "\" fill=\"#f8fafc\" stroke=\"#d1d5db\" stroke-width=\"0.00003\" />\n"
  <> "    <g clip-path=\"url(#corner-zoom-clip-"
  <> int.to_string(index)
  <> ")\">\n"
  <> "    <path d=\""
  <> escape(source_path)
  <> "\" style=\"fill: none; stroke: #cbd5e1; stroke-width: 0.000035; stroke-linecap: round; stroke-linejoin: round\" />\n"
  <> "    <path d=\""
  <> escape(stalled_segments)
  <> "\" style=\"fill: none; stroke: #f97316; stroke-width: 0.000055; stroke-linecap: round; stroke-linejoin: round\" />\n"
  <> output
  <> stalled_arc_turn_fit_marks(source)
  <> "    </g>\n"
  <> "  </g>\n"
  <> "  <text x=\""
  <> f(panel_x)
  <> "\" y=\""
  <> f(panel_y +. 132.0)
  <> "\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"11\" text-anchor=\"middle\" fill=\"#111827\">"
  <> row_label
  <> "; "
  <> int.to_string(subdivisions)
  <> " "
  <> unit_label
  <> case subdivisions == 1 {
    True -> ""
    False -> "s"
  }
  <> "; corner "
  <> stalled_arc_turn_corner_label(result)
  <> "; stalled="
  <> int.to_string(count_stalled_segments(svg_path.subpath_segments(source)))
  <> "</text>"
}

fn stalled_arc_turn_zoom_box(
  source: svg_path.Subpath,
  result: Result(svg_path.Subpath, offset.Error),
) -> #(Float, Float, Float) {
  let points =
    list.append(
      stalled_arc_turn_offset_sample_points(source),
      stalled_arc_turn_corner_diagnostic_points(result),
    )

  case points {
    [] -> #(-0.004, -0.008, 0.01)
    [first, ..rest] -> {
      let #(min_x, min_y, max_x, max_y) =
        rest
        |> list.fold(#(first.x, first.y, first.x, first.y), fn(box, point) {
          let #(min_x, min_y, max_x, max_y) = box
          #(
            float.min(min_x, point.x),
            float.min(min_y, point.y),
            float.max(max_x, point.x),
            float.max(max_y, point.y),
          )
        })
      let width = max_x -. min_x
      let height = max_y -. min_y
      let size = float.max(float.max(width, height) *. 1.3, 0.002)
      let center_x = { min_x +. max_x } /. 2.0
      let center_y = { min_y +. max_y } /. 2.0
      #(center_x -. size /. 2.0, center_y -. size /. 2.0, size)
    }
  }
}

fn stalled_arc_turn_offset_sample_points(
  source: svg_path.Subpath,
) -> List(svg_path.Point) {
  let stalled =
    svg_path.subpath_segments(source)
    |> list.filter(stalled_arc_turn_segment_is_caught)

  stalled_arc_turn_sample_points(stalled)
}

fn stalled_arc_turn_sample_points(
  segments: List(svg_path.Segment),
) -> List(svg_path.Point) {
  stalled_arc_turn_sample_points_loop(segments, points: [])
}

fn stalled_arc_turn_sample_points_loop(
  segments: List(svg_path.Segment),
  points points: List(svg_path.Point),
) -> List(svg_path.Point) {
  case segments {
    [] -> list.reverse(points)
    [first, ..rest] -> {
      let points =
        stalled_arc_turn_segment_sample_points(first, [0.25, 0.5, 0.75], points)
      stalled_arc_turn_sample_points_loop(rest, points:)
    }
  }
}

fn stalled_arc_turn_segment_sample_points(
  segment: svg_path.Segment,
  samples: List(Float),
  points: List(svg_path.Point),
) -> List(svg_path.Point) {
  case samples {
    [] -> points
    [t, ..rest] -> {
      let points = case offset_endpoint(segment, t) {
        Ok(point) -> [point, ..points]
        Error(_) -> points
      }
      stalled_arc_turn_segment_sample_points(segment, rest, points)
    }
  }
}

fn stalled_arc_turn_corner_diagnostic_points(
  result: Result(svg_path.Subpath, offset.Error),
) -> List(svg_path.Point) {
  case result {
    Error(_) -> []
    Ok(subpath) ->
      subpath
      |> stalled_arc_turn_corner_segments
      |> list.flat_map(stalled_arc_turn_segment_diagnostic_points)
  }
}

fn stalled_arc_turn_segment_diagnostic_points(
  segment: svg_path.Segment,
) -> List(svg_path.Point) {
  case segment {
    svg_path.Line(start:, end:) -> [start, end]
    svg_path.QuadraticBezier(start:, control:, end:) -> [start, control, end]
    svg_path.CubicBezier(start:, control1:, control2:, end:) -> [
      start,
      control1,
      control2,
      end,
    ]
    svg_path.Arc(start:, end:, ..) -> [start, end]
  }
}

fn stalled_arc_turn_output_control_marks(subpath: svg_path.Subpath) -> String {
  case svg_path.subpath_segments(subpath) {
    [_, svg_path.CubicBezier(control1:, control2:, ..), ..] ->
      "    <circle cx=\""
      <> f(control1.x)
      <> "\" cy=\""
      <> f(control1.y)
      <> "\" r=\"0.00007\" fill=\"#dc2626\" stroke=\"#ffffff\" stroke-width=\"0.000018\" />\n"
      <> "    <text x=\""
      <> f(control1.x)
      <> "\" y=\""
      <> f(control1.y -. 0.00018)
      <> "\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"0.00018\" text-anchor=\"middle\" fill=\"#dc2626\" stroke=\"#ffffff\" stroke-width=\"0.000035\" paint-order=\"stroke fill\">c1</text>\n"
      <> "    <circle cx=\""
      <> f(control2.x)
      <> "\" cy=\""
      <> f(control2.y)
      <> "\" r=\"0.00007\" fill=\"#7c3aed\" stroke=\"#ffffff\" stroke-width=\"0.000018\" />\n"
      <> "    <text x=\""
      <> f(control2.x)
      <> "\" y=\""
      <> f(control2.y -. 0.00018)
      <> "\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"0.00018\" text-anchor=\"middle\" fill=\"#7c3aed\" stroke=\"#ffffff\" stroke-width=\"0.000035\" paint-order=\"stroke fill\">c2</text>\n"
    _ -> ""
  }
}

fn stalled_arc_turn_fit_marks(source: svg_path.Subpath) -> String {
  let stalled =
    svg_path.subpath_segments(source)
    |> list.filter(stalled_arc_turn_segment_is_caught)

  stalled_arc_turn_sample_marks(stalled)
  <> stalled_arc_turn_tangent_marks(stalled)
}

fn stalled_arc_turn_sample_marks(segments: List(svg_path.Segment)) -> String {
  stalled_arc_turn_sample_marks_loop(segments, index: 0, marks: "")
}

fn stalled_arc_turn_sample_marks_loop(
  segments: List(svg_path.Segment),
  index index: Int,
  marks marks: String,
) -> String {
  case segments {
    [] -> marks
    [first, ..rest] -> {
      let marks =
        marks <> stalled_arc_turn_segment_sample_marks(first, [0.25, 0.5, 0.75])
      stalled_arc_turn_sample_marks_loop(rest, index: index + 1, marks:)
    }
  }
}

fn stalled_arc_turn_segment_sample_marks(
  segment: svg_path.Segment,
  samples: List(Float),
) -> String {
  case samples {
    [] -> ""
    [t, ..rest] -> {
      let mark = case offset_endpoint(segment, t) {
        Ok(point) ->
          "    <circle cx=\""
          <> f(point.x)
          <> "\" cy=\""
          <> f(point.y)
          <> "\" r=\"0.00007\" fill=\"#16a34a\" stroke=\"#ffffff\" stroke-width=\"0.000018\" />\n"
        Error(_) -> ""
      }
      mark <> stalled_arc_turn_segment_sample_marks(segment, rest)
    }
  }
}

fn stalled_arc_turn_tangent_marks(segments: List(svg_path.Segment)) -> String {
  case segments {
    [] -> ""
    [first, ..rest] -> {
      let assert Ok(last) = list.last([first, ..rest])
      stalled_arc_turn_tangent_mark(first, t: 0.0, color: "#eab308")
      <> stalled_arc_turn_tangent_mark(last, t: 1.0, color: "#eab308")
    }
  }
}

fn stalled_arc_turn_tangent_mark(
  segment: svg_path.Segment,
  t t: Float,
  color color: String,
) -> String {
  case offset_endpoint(segment, t), segment_unit_tangent(segment, t) {
    Ok(point), Ok(tangent) -> {
      let end = add_point(point, scale_point(tangent, 0.00075))
      "    <line x1=\""
      <> f(point.x)
      <> "\" y1=\""
      <> f(point.y)
      <> "\" x2=\""
      <> f(end.x)
      <> "\" y2=\""
      <> f(end.y)
      <> "\" style=\"stroke: "
      <> color
      <> "; stroke-width: 0.000045; stroke-linecap: round\" />\n"
      <> "    <circle cx=\""
      <> f(point.x)
      <> "\" cy=\""
      <> f(point.y)
      <> "\" r=\"0.000075\" fill=\""
      <> color
      <> "\" stroke=\"#ffffff\" stroke-width=\"0.000018\" />\n"
    }
    _, _ -> ""
  }
}

fn segment_unit_tangent(
  segment: svg_path.Segment,
  t: Float,
) -> Result(svg_path.Point, Nil) {
  case svg_path.segment_derivative(segment, at: t) {
    Ok(derivative) -> {
      let length = distance(svg_path.Point(0.0, 0.0), derivative)
      case length <=. 0.0 {
        True -> Error(Nil)
        False ->
          Ok(svg_path.Point(derivative.x /. length, derivative.y /. length))
      }
    }
    Error(_) -> Error(Nil)
  }
}

fn stalled_arc_turn_panel(
  example: #(
    String,
    String,
    Int,
    svg_path.Subpath,
    Result(svg_path.Subpath, offset.Error),
  ),
  index: Int,
) -> String {
  let #(row_label, unit_label, subdivisions, source, result) = example
  let column = index % 3
  let row = index / 3
  let tx = 145.0 +. int.to_float(column) *. 280.0
  let ty = 145.0 +. int.to_float(row) *. 260.0
  let source_path = serialize.subpath(source)
  let stalled_segments =
    svg_path.subpath_segments(source)
    |> list.filter(stalled_arc_turn_segment_is_caught)
    |> serialize_segments
  let output = case result {
    Ok(subpath) ->
      "    <path d=\""
      <> escape(serialize.subpath(subpath))
      <> "\" style=\"fill: none; stroke: #2563eb; stroke-width: 2.4; stroke-linecap: round; stroke-linejoin: round\" />\n"
    Error(error) ->
      "    <text x=\"0\" y=\"24\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"7\" text-anchor=\"middle\" fill=\"#b91c1c\">"
      <> escape(string.inspect(error))
      <> "</text>\n"
  }

  "  <g transform=\"translate("
  <> f(tx)
  <> " "
  <> f(ty)
  <> ") scale(2)\">\n"
  <> "    <rect x=\"-58\" y=\"-58\" width=\"116\" height=\"88\" fill=\"#f8fafc\" stroke=\"#d1d5db\" stroke-width=\"0.7\" />\n"
  <> "    <path d=\""
  <> escape(source_path)
  <> "\" style=\"fill: none; stroke: #9ca3af; stroke-width: 1.6; stroke-linecap: round; stroke-linejoin: round\" />\n"
  <> "    <path d=\""
  <> escape(stalled_segments)
  <> "\" style=\"fill: none; stroke: #f97316; stroke-width: 2.2; stroke-linecap: round; stroke-linejoin: round\" />\n"
  <> output
  <> "  </g>\n"
  <> "  <text x=\""
  <> f(tx)
  <> "\" y=\""
  <> f(ty +. 105.0)
  <> "\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"12\" text-anchor=\"middle\" fill=\"#111827\">"
  <> row_label
  <> "; "
  <> int.to_string(subdivisions)
  <> " "
  <> unit_label
  <> case subdivisions == 1 {
    True -> ""
    False -> "s"
  }
  <> "</text>\n"
  <> "  <text x=\""
  <> f(tx)
  <> "\" y=\""
  <> f(ty +. 122.0)
  <> "\" font-family=\"ui-monospace, SFMono-Regular, Menlo, monospace\" font-size=\"11\" text-anchor=\"middle\" fill=\"#334155\">corner segments="
  <> stalled_arc_turn_corner_segment_count(result)
  <> "; stalled="
  <> int.to_string(count_stalled_segments(svg_path.subpath_segments(source)))
  <> "</text>"
}

fn serialize_segments(segments: List(svg_path.Segment)) -> String {
  case svg_path.subpath_with(segments, policy: svg_path.Wiggle) {
    Ok(subpath) -> serialize.subpath(subpath)
    Error(_) -> ""
  }
}

fn square_loop() -> svg_path.Subpath {
  svg_path.subpath_assert_polygon([
    svg_path.Point(0.0, 0.0),
    svg_path.Point(10.0, 0.0),
    svg_path.Point(10.0, 10.0),
    svg_path.Point(0.0, 10.0),
  ])
}

fn add_point(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.Point(a.x +. b.x, a.y +. b.y)
}

fn subtract_point(a: svg_path.Point, b: svg_path.Point) -> svg_path.Point {
  svg_path.Point(a.x -. b.x, a.y -. b.y)
}

fn scale_point(point: svg_path.Point, scale: Float) -> svg_path.Point {
  svg_path.Point(point.x *. scale, point.y *. scale)
}

fn f(value: Float) -> String {
  number_format.number(
    value,
    with: number_format.prepare(
      number_format.Options(
        left_decimals: number_format.Succinct,
        right_decimals: number_format.AtMost(6),
      ),
      [],
    ),
  )
}

fn escape(text: String) -> String {
  text
  |> string.replace("&", "\\&amp;")
  |> string.replace("\"", "\\&quot;")
  |> string.replace("<", "\\&lt;")
  |> string.replace(">", "\\&gt;")
}

@external(erlang, "file", "write_file")
fn write_file(path: String, contents: String) -> Dynamic

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(String, Dynamic)

fn first_path_data(contents: String) -> String {
  let assert [_, after_attribute] = string.split(contents, on: " d=\"")
  let assert [data, ..] = string.split(after_attribute, on: "\"")
  data
}

pub fn pairwise_healing_loop_short_circuit_is_idempotent_test() {
  let previous =
    svg_path.QuadraticBezier(
      start: svg_path.Point(0.0, 0.0),
      control: svg_path.Point(0.5, 2.0),
      end: svg_path.Point(1.0, 0.0),
    )
  let next =
    svg_path.QuadraticBezier(
      start: svg_path.Point(1.0, 0.0),
      control: svg_path.Point(0.5, -1.0),
      end: svg_path.Point(0.0, 1.0),
    )
  let assert Ok(#(rebuilt_previous, rebuilt_next)) =
    offset.internal_short_circuit_adjacent_offset_segment_loop(previous, next)

  assert svg_path.segment_end(rebuilt_previous)
    == svg_path.segment_start(rebuilt_next)
  assert svg_path.segment_end(rebuilt_previous)
    != svg_path.segment_end(previous)
  assert offset.internal_short_circuit_adjacent_offset_segment_loop(
      rebuilt_previous,
      rebuilt_next,
    )
    == Ok(#(rebuilt_previous, rebuilt_next))
}
