# Single normalized search: 100 × 100

Experiment date: 2026-10-14. Baseline: `269a535`.
This corrects the earlier `always100` experiment, which combined original and
normalized searches rather than replacing the original search.

## Algorithm tested

For eligible polynomial pairs reaching the general curve solver, translate the
combined control-point bounds to the origin and independently scale their x/y
ranges to 100. Run the beam search **once**, on those normalized curves, with
internal tolerance 1e-12 and the caller's max_depth. There is no original-coordinate
search, supplementation, or fallback on normalized-search failure for these
pairs. Re-evaluate returned parameters on the original curves and report their
original-coordinate midpoint, retaining only candidates within the caller's
tolerance of both evaluations. Existing public snapping/certification follows.

Arc pairs and pairs without finite positive ranges retain their ordinary single
search. Existing line/constant dispatch and original-coordinate overlap prechecks
are unchanged. This experiment does not normalize the entire geometry pipeline.

The rejection policy is significant: a candidate that fails original-coordinate
validation is filtered out, potentially producing `Ok([])`. That policy was
suitable for optional supplementary candidates but is not equivalent to the
existing primary-search certification error behavior. Two failures below expose
this difference. They must not be attributed solely to coordinate normalization.

## Failure inventory

| Test module / function | Observed difference | Interpretation |
| --- | --- | --- |
| `svg_path_conditioned_intersections_test`: `conditioned_search_preserves_original_candidates_test` | Original raw parameter pairs are not retained; normalized search returns one candidate near (0.49624328350634306, 0.1839397441132217). | Expected incompatibility with a test specifically requiring supplementation. The separate known thin-curve-root test passes. |
| `svg_path_conditioned_intersections_test`: `conditioned_search_does_not_override_overlap_or_certification_test` | Extremely strict tolerance returns `Ok([])` instead of `InternalUncertifiedSegmentIntersection`. | Rejection-policy regression; the preceding overlap assertion passes. |
| `svg_path_elizabeth_test`: `elizabeth_kissing_candidates_obey_resolution_contract_test` | One pair near (0.4999999961282378, 0.4999999961282378), without exact (0.5,0.5). | Exact-representative assertion fails; parameter error is about 3.9e-9, not a missing nearby contact. Remaining assertions are not reached. |
| `svg_path_geometry_test`: `segment_intersections_prefers_shared_endpoint_over_near_endpoint_minimum_test` | Raw count 2 instead of 4. | Count snapshot fails after candidate-validity assertions; later snapped-count and endpoint assertions are not reached in the unchanged test. |
| `svg_path_intersection_scale_test`: `unrepresentable_tolerance_reports_error_instead_of_empty_result_test` | `Ok([])` instead of `InternalUncertifiedSegmentIntersection`. | Rejection-policy regression. |
| `svg_path_intersections_test`: `production_off_center_kissing_quadratics_test` | Count 1 instead of 4. | Count snapshot only; known-contact and geometric-validity assertions pass first. |
| `svg_path_intersections_test`: `flat_cubic_crossing_regression_test` | Five candidates; nearest is 0.5000007056286587 on both curves, missing the known root within 1e-7. | Parameter-accuracy regression, beyond a count change. Exact (0.5,0.5) was present before. |
| `svg_path_paper_intersection_addresses_slow_test`: `paper_address_12_test` | At least one returned address pair classifies as `Indeterminate`. | Downstream classification regression. Further expected-address assertions are not reached; root cause has not yet been isolated. |

There are eight unique failing test functions. The geometry module is absent
from the portable selection, leaving seven failures in each combined portable
profile. No test expectations were modified or failures bypassed.

## Interpretation

Unlike the supplementary experiment, this variant loses useful representatives
of ill-conditioned contacts. Original-coordinate validation bounds the residual
of accepted candidates; it does not ensure parameter accuracy, preserve a
well-classified representative, or establish completeness. The flat cubic
crossing makes this distinction concrete.

This is an experimental result, not an adoption. Do not fix these failures merely
by changing expected counts: the classification and parameter-accuracy regressions
need investigation, and rejection should preserve meaningful certification errors.
Published figures were not regenerated for this experiment.

## Completed validation

Each command ran separately so an earlier failure could not skip later profiles.

| Command | Passed | Failed | Wall seconds |
| --- | ---: | ---: | ---: |
| `scripts/test-fast` | 2005 | 7 | 40.87 |
| `scripts/test-slow` | 30 | 1 | 55.64 |
| `scripts/test-portable erlang all` | 751 | 7 | 44.96 |
| `scripts/test-portable javascript all` | 751 | 7 | 62.69 |

Timings are observations, not controlled benchmarks. Cleaned logs and the exact
experimental patch are saved here. The production source was restored after all
four profiles completed. No commit was made.
