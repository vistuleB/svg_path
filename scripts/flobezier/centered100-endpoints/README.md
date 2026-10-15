# Centered normalized search with original-coordinate endpoint matching

Experiment date: 2026-10-14. Baseline: `269a535`.

## Algorithm tested

Build on `../centered100-only/`: one general beam search on polynomial curves
mapped using combined control-point bounds to centered spans of 100 on both
axes. Keep original-coordinate overlap checks and final original-coordinate
candidate validation. Retain existing arc, zero-range, line and constant handling.

The sole algorithmic change from that experiment is endpoint discovery. Compute
endpoint matches on the original curves using the original solver's internal
roundoff-adjusted tolerance. Transform their reported points and supply these
candidates as the initial seeds for the normalized beam search, replacing its
normalized-coordinate endpoint-discovery step. Candidate ranking and deduplication
remain in the normal beam pipeline. Re-evaluate final candidate parameters on
the original curves before returning original-coordinate midpoints.

This runs one full beam search, not the original plus normalized searches.
The internal raw-beam entry point keeps its previous behavior when no endpoint
seed override is supplied. Its tolerance calculation was extracted into a shared
private helper without changing its formula.

The previously identified filtering policy remains unchanged to isolate this
experiment: failed original-coordinate validation discards a candidate, possibly
returning `Ok([])` instead of the existing certification error. This remains a
known issue and is not proposed for adoption.

## Failure inventory

All four Paper.js-derived fixture 21/22 checks now pass. The root fast suite has
six remaining failures:

| Module | Test function | Difference |
| --- | --- | --- |
| `svg_path_conditioned_intersections_test` | `conditioned_search_preserves_original_candidates_test` | Does not preserve all parameter pairs from the original full search; this assertion specifically requires supplementation. |
| `svg_path_conditioned_intersections_test` | `conditioned_search_does_not_override_overlap_or_certification_test` | Returns `Ok([])` instead of `InternalUncertifiedSegmentIntersection` at the strict tolerance; overlap assertion passes. |
| `svg_path_geometry_test` | `segment_intersections_prefers_shared_endpoint_over_near_endpoint_minimum_test` | Raw count 2 instead of 4; preceding raw/snapped candidate-validity assertions pass, subsequent assertions are not reached. |
| `svg_path_intersection_scale_test` | `unrepresentable_tolerance_reports_error_instead_of_empty_result_test` | Returns `Ok([])` instead of the expected certification error. |
| `svg_path_intersections_test` | `production_off_center_kissing_quadratics_test` | Count 1 instead of 4; preceding known-contact and geometric assertions pass. |
| `svg_path_intersections_test` | `flat_cubic_crossing_regression_test` | Count 6 instead of 9; preceding known-root accuracy and geometric assertions pass. |

No repository test expectations were modified. A failing assertion stops its test
function; passing earlier checks does not certify later unreached assertions.
The candidate-preservation test now observes two candidates, including an
original-coordinate endpoint match, rather than the one in the centered-only
experiment. The separate thin-curve known-root test passes.

This experiment resolves the newly introduced endpoint-discovery failures. The
remaining certification-error behavior must still be corrected before adoption;
count changes and the now-inapplicable supplementation test also require review.
Published figures were not regenerated.

## Completed validation

Each profile ran separately, continuing after failures.

| Command | Passed | Failed | Wall seconds |
| --- | ---: | ---: | ---: |
| `scripts/test-fast` | 2006 | 6 | 42.05 |
| `scripts/test-slow` | 31 | 0 | 58.19 |
| `scripts/test-portable erlang all` | 753 | 5 | 51.38 |
| `scripts/test-portable javascript all` | 753 | 5 | 65.83 |

Six unique failing functions remain. Both portable targets report the same five
failures; the geometry module is not selected there. All slow tests pass.
Timings are observations, not controlled benchmarks.

Cleaned logs and the experimental patch are saved alongside this report.
Production source was restored after all four profiles completed. No commit
was made.
