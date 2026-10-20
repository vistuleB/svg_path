# Original coverage gaps — 2026-10-20

Native revision `09d30a1`, Gleam JavaScript. Pinned upstream revision remains
`22887a824d22cd8ab50968a551f34cdb4508127f` (0.9.0). This pass reviews
all 31 originally uncaptured tests; original capture ledgers remain historical.

## Public geometry probes

`node scripts/cavalier/probe-original-coverage-gaps.mjs` executes 32 checks
derived from eight upstream tests. All 32 passed. Results are in
`original-coverage-gap-results.jsonl`.

- Arc sweep tests: distance-to-arc membership substitutes for the private angular
  predicate. Three scales exclude the opposite point; twelve endpoint-neighborhood
  checks distinguish half-epsilon from twice-epsilon separation. This checks
  corresponding geometry, not every detail of upstream angular tolerance.
- Local self-intersections: empty/single-vertex paths and a two-semicircle circle
  report no isolated self-intersections. Retraced half-circle geometry reports
  one continuous overlap through `encounters.segment`. Native whole-subpath
  self-intersection queries instead explicitly reject continuous overlaps.
- Raw offset: a right-angle two-line source returns three valid segments with
  length `20 + pi/2`. Twelve outer round-join checks cover both directions and
  sweep angles from 1e-12 to pi, comparing length to `2 + sweep` at 1e-8.
  This checks geometry, not upstream bulge storage.

## Scope dispositions

The other 23 tests assert contracts without direct native equivalents. They
are source-reviewed scope dispositions, **not native passing tests**. In particular
the private near-collinear join-class test does not supply an expected public
offset shape, and zero-offset storage identity is not our normalization contract.
These dispositions do not establish equivalence of internal algorithms.

| Upstream test | Disposition | Native checks |
| --- | --- | ---: |
| `core::math::vector2::tests::ops` | different-private-or-representation-contract | 0 |
| `core::math::base_math::tests::small_arc_sweep_excludes_opposite_point_at_different_scales` | public-geometry-probe-passed | 3 |
| `core::math::base_math::tests::arc_sweep_uses_position_tolerance_at_both_boundaries` | public-geometry-probe-passed | 12 |
| `polyline::internal::pline_intersects::local_self_intersect_tests::circle_no_intersects` | public-geometry-probe-passed | 1 |
| `polyline::internal::pline_intersects::local_self_intersect_tests::empty_polyline` | public-geometry-probe-passed | 1 |
| `polyline::internal::pline_intersects::local_self_intersect_tests::filters_local_segment_pairs` | different-private-or-representation-contract | 0 |
| `polyline::internal::pline_intersects::local_self_intersect_tests::half_circle_overlapping_self` | public-geometry-probe-passed | 1 |
| `polyline::internal::pline_intersects::local_self_intersect_tests::single_vertex` | public-geometry-probe-passed | 1 |
| `polyline::internal::pline_offset::tests::ambiguous_multiway_touch_falls_back_to_preserve_order` | different-private-or-representation-contract | 0 |
| `polyline::internal::pline_offset::tests::discarded_overlap_blocks_preserve_touch_routing_at_shared_boundary` | different-private-or-representation-contract | 0 |
| `polyline::internal::pline_offset::tests::dissection_points_sort_into_segment_ranges` | different-private-or-representation-contract | 0 |
| `polyline::internal::pline_offset::tests::indexed_node_lookup_handles_unbucketed_coordinates` | different-private-or-representation-contract | 0 |
| `polyline::internal::pline_offset::tests::indexed_node_lookup_uses_bucket_probe_order_for_multiple_matches` | different-private-or-representation-contract | 0 |
| `polyline::internal::pline_offset::tests::preserve_routing_visits_related_slice_before_closing` | different-private-or-representation-contract | 0 |
| `polyline::internal::pline_offset::tests::reversed_relation_reports_merge_and_strengthen_one_pair` | different-private-or-representation-contract | 0 |
| `polyline::internal::pline_offset::tests::separate_behavior_keeps_crossing_closure_order` | different-private-or-representation-contract | 0 |
| `polyline::internal::pline_offset::tests::separate_routing_prioritizes_relation_to_initial_occurrence` | different-private-or-representation-contract | 0 |
| `polyline::internal::pline_offset::tests::slices_with_invalid_indexes_are_rejected` | different-private-or-representation-contract | 0 |
| `polyline::internal::pline_offset::tests::unrelated_nodes_do_not_connect_by_position` | different-private-or-representation-contract | 0 |
| `polyline::internal::raw_pline_offset::tests::near_collinear_corner_uses_normalized_angular_tolerance` | different-private-or-representation-contract | 0 |
| `polyline::internal::raw_pline_offset::tests::normal_raw_offsets_have_no_invalid_segments` | public-geometry-probe-passed | 1 |
| `polyline::internal::raw_pline_offset::tests::round_join_bulge_matches_sweep_and_offset_direction` | public-geometry-probe-passed | 12 |
| `polyline::internal::raw_pline_offset::tests::zero_raw_offset_is_an_exact_copy` | different-private-or-representation-contract | 0 |
| `polyline::internal::pline_offset::tests::topology_builder_indexes_large_contact_sets` | different-private-or-representation-contract | 0 |
| `iter_segments` | different-private-or-representation-contract | 0 |
| `create_from_remove_repeat` | different-private-or-representation-contract | 0 |
| `invert_direction_mut` | different-private-or-representation-contract | 0 |
| `iter_segment_indexes` | different-private-or-representation-contract | 0 |
| `iter_vertexes` | different-private-or-representation-contract | 0 |
| `remove_repeat` | different-private-or-representation-contract | 0 |
| `attempting_to_wrap_slice_on_open_pline - should panic` | different-private-or-representation-contract | 0 |

Per-test reasons: `original-coverage-gap-dispositions.json`. No production changes,
permanent suite additions, F# port or full-suite rerun. No commit in this batch.
Other original offset/Boolean classifications remain open; this is not audit closure.
