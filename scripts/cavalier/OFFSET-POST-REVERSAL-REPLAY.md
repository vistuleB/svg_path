# Flagged offset replay after reversal-join repair

Revision `1e97935`, JavaScript. Historical baseline records are unchanged.

192 originally flagged records across 45 upstream tests. discrepancy: 149, match: 29, error: 6, timeout: 8.

These are property comparisons, not boundary-equivalence proofs or bug counts. Matches may reflect any preceding audit repair; only the separately isolated reversal cases are attributed to the latest fix. Previously matching inputs were not selected. Timeouts remain unresolved.

| Upstream test | Records | Current outcomes | IDs still flagged |
| --- | ---: | --- | --- |
| `coincident_discard_does_not_remove_a_point_only_tangent` | 1 | discrepancy: 1 | CC01131 |
| `coincident_discard_removes_same_direction_and_opposing_partial_spans` | 3 | discrepancy: 3 | CC01142, CC01143, CC01146 |
| `collapsed_rectangle_preserves_or_discards_coincident_centerline` | 1 | discrepancy: 1 | CC01150 |
| `default_behavior_preserves_tangent_touching_small_loop` | 1 | discrepancy: 1 | CC01151 |
| `next_offset_removes_collapsed_small_loop` | 1 | discrepancy: 1 | CC01160 |
| `offset_does_not_self_intersect` | 1 | discrepancy: 1 | CC01167 |
| `repeat_position_real_world_input_is_sanitized_before_offset` | 1 | discrepancy: 1 | CC01179 |
| `separate_behavior_splits_tangent_touching_small_loop` | 2 | discrepancy: 2 | CC01183, CC01189 |
| `test_past_failures::closed_pline1` | 2 | match: 2 | — |
| `test_past_failures::closed_pline9` | 4 | discrepancy: 4 | CC01248, CC01252, CC01253, CC01254 |
| `test_past_failures::near_tangent_line_arc_joins` | 2 | match: 2 | — |
| `test_past_failures::open_pline4` | 2 | discrepancy: 2 | CC01287, CC01291 |
| `test_past_failures::open_pline5` | 2 | discrepancy: 1, match: 1 | CC01292 |
| `test_past_failures::small_bulge_arc_line_transition` | 1 | discrepancy: 1 | CC01297 |
| `test_past_failures::sub_tolerance_raw_offset_arc_does_not_panic` | 1 | discrepancy: 1 | CC01301 |
| `test_simple::circle_collapsed` | 4 | discrepancy: 4 | CC01305, CC01306, CC01307, CC01308 |
| `test_simple::circle_collapsed_into_point` | 4 | error: 4 | CC01309, CC01310, CC01311, CC01312 |
| `test_simple::square_collapsed` | 4 | discrepancy: 4 | CC01383, CC01384, CC01385, CC01386 |
| `test_specific::case10` | 2 | match: 2 | — |
| `test_specific::case11` | 4 | discrepancy: 4 | CC01405, CC01409, CC01410, CC01411 |
| `test_specific::case12` | 2 | match: 2 | — |
| `test_specific::case14` | 2 | match: 2 | — |
| `test_specific::case15` | 2 | match: 2 | — |
| `test_specific::case5` | 2 | discrepancy: 2 | CC01470, CC01474 |
| `test_specific::case6` | 2 | error: 2 | CC01475, CC01479 |
| `test_specific::case8` | 2 | match: 2 | — |
| `test_specific::case9` | 2 | match: 2 | — |
| `test_specific::self_intersecting_case1` | 2 | discrepancy: 2 | CC01499, CC01503 |
| `test_specific::self_intersecting_case2` | 2 | discrepancy: 2 | CC01504, CC01508 |
| `test_topology_stitching::coincident_line_dumbbell_segment_interior_boundaries` | 8 | discrepancy: 8 | CC01520, CC01521, CC01522, CC01523, CC01524, CC01525, CC01526, CC01527 |
| `test_topology_stitching::coincident_line_dumbbell_vertex_boundaries` | 8 | discrepancy: 8 | CC01539, CC01540, CC01541, CC01542, CC01543, CC01544, CC01545, CC01546 |
| `test_topology_stitching::disjoint_same_direction_coincident_spans` | 8 | discrepancy: 8 | CC01547, CC01551, CC01552, CC01553, CC01554, CC01555, CC01556, CC01557 |
| `test_topology_stitching::non_tangent_open_endpoint_clip` | 8 | match: 8 | — |
| `test_topology_stitching::opposing_coincident_arcs_segment_interior_boundaries` | 12 | discrepancy: 12 | CC01574, CC01575, CC01578, CC01579, CC01580, CC01581, CC01582, CC01583, CC01584, CC01585, CC01586, CC01587 |
| `test_topology_stitching::opposing_coincident_arcs_vertex_boundaries` | 12 | discrepancy: 12 | CC01593, CC01594, CC01597, CC01598, CC01599, CC01600, CC01601, CC01602, CC01603, CC01604, CC01605, CC01606 |
| `test_topology_stitching::same_direction_coincident_open_arcs` | 8 | discrepancy: 8 | CC01607, CC01611, CC01612, CC01613, CC01614, CC01615, CC01616, CC01617 |
| `test_topology_stitching::same_direction_coincident_open_line_arc` | 8 | discrepancy: 8 | CC01618, CC01622, CC01623, CC01624, CC01625, CC01626, CC01627, CC01628 |
| `test_topology_stitching::same_direction_coincident_open_lines` | 8 | discrepancy: 8 | CC01629, CC01633, CC01634, CC01635, CC01636, CC01637, CC01638, CC01639 |
| `test_topology_stitching::tangent_arc_arc_segment_interiors` | 16 | timeout: 8, match: 4, discrepancy: 4 | CC01640, CC01644, CC01647, CC01648, CC01651, CC01652, CC01653, CC01654, CC01655, CC01656, CC01657, CC01658 |
| `test_topology_stitching::tangent_line_arc_segment_interiors` | 8 | discrepancy: 8 | CC01670, CC01671, CC01672, CC01673, CC01674, CC01675, CC01676, CC01677 |
| `test_topology_stitching::tangent_line_endpoints` | 8 | discrepancy: 8 | CC01689, CC01690, CC01691, CC01692, CC01693, CC01694, CC01695, CC01696 |
| `test_topology_stitching::three_way_coincident_lines` | 8 | discrepancy: 8 | CC01697, CC01701, CC01702, CC01703, CC01704, CC01705, CC01706, CC01707 |
| `test_topology_stitching::touch_at_coincident_overlap_boundary` | 8 | discrepancy: 8 | CC01727, CC01731, CC01732, CC01733, CC01734, CC01735, CC01736, CC01737 |
| `touching_loop_behavior_does_not_change_crossing_routing` | 2 | discrepancy: 2 | CC01738, CC01739 |
| `test_specific::case3` | 1 | discrepancy: 1 | CC01807 |

See `OFFSET-POST-REVERSAL-TRIAGE.md` for targeted follow-up and dispositions.
