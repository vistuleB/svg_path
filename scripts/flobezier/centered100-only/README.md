# Single centered normalized search: [-50,50]²

Experiment date: 2026-10-14. Baseline: `269a535`.

## Variant

Same single-search experiment as `../normalized100-only/`, changing only the
normalization placement. Use the combined control-point bounds, not exact curve
bounds. For each eligible polynomial pair:

```
dx = xmax - xmin
cx = xmin + dx / 2
x' = 100 * ((x - cx) / dx)
```

Apply the analogous transformation to y. This translates to the box center
before scaling independently to spans of 100. Floating-point rounding means the
transformed bounds need not be exactly ±50.

Run just the normalized beam search, with internal tolerance 1e-12 and the
caller's max_depth; re-evaluate candidate parameters on the original curves,
retain original-coordinate midpoints satisfying the caller's tolerance, then
use the existing public snapping/certification. No second search or fallback
for eligible pairs. Arc/zero-range exclusions and line/constant dispatch remain
unchanged, as do original-coordinate overlap checks.

As in the previous experiment, filtering uncertifiable candidates can return
`Ok([])` instead of the existing certification error. This known policy issue
was deliberately held constant to isolate centering; its failures should not
be blamed solely on the coordinate transform. No production adoption or test
expectation changes are part of this experiment.

## Observations

- `elizabeth_kissing_candidates_obey_resolution_contract_test` now passes.
- `flat_cubic_crossing_regression_test` now passes its known-root parameter
  accuracy and geometric-validity assertions. Its count snapshot still fails:
  6 candidates instead of 9.
- `segment_intersections_prefers_shared_endpoint_over_near_endpoint_minimum_test`
  still fails its raw count snapshot: 2 instead of 4. Later assertions are not
  reached in the unchanged test.
- `production_off_center_kissing_quadratics_test` still returns 1 instead of 4;
  its known-root and geometric-validity assertions pass before that snapshot.
- `conditioned_search_preserves_original_candidates_test` still fails, as
  expected for replacing rather than supplementing the original search. The
  separate known thin-curve-root test passes.
- `conditioned_search_does_not_override_overlap_or_certification_test` and
  `unrepresentable_tolerance_reports_error_instead_of_empty_result_test` still
  return `Ok([])` instead of the expected certification error.
- New failures: `paper_address_21_test`, `paper_address_22_test`, `paper_21_test`,
  and `paper_22_test`. Expected intersections/addresses cannot be matched.
  These are not candidate-count snapshots. The address tests are in
  `svg_path_paper_intersection_addresses_test.gleam`; the point tests are in
  `svg_path_paper_intersections_test.gleam`. Root causes remain uninvestigated.

All 31 root slow tests pass, including `paper_address_12_test`, which returned
`Indeterminate` in the [0,100]² variant.

Centering improves the symmetric-contact cases, but it does not establish a
safe replacement for the original search. The newly failing Paper.js-derived
checks need investigation before adoption. The full inventory below records
all completed profiles. Published figures were not regenerated.

## Completed validation

Each profile ran separately, continuing after failures.

| Command | Passed | Failed | Wall seconds |
| --- | ---: | ---: | ---: |
| `scripts/test-fast` | 2002 | 10 | 51.87 |
| `scripts/test-slow` | 31 | 0 | 58.61 |
| `scripts/test-portable erlang all` | 749 | 9 | 58.81 |
| `scripts/test-portable javascript all` | 749 | 9 | 74.51 |

There are 10 unique failing test functions. The portable profiles omit the
geometry module, so they each have nine failures. Both targets report the same
failing functions. These timings are observations, not controlled benchmarks.

Cleaned logs and the exact experimental patch are saved alongside this report.
Production source was restored after all four profiles completed. Test
expectations remain unchanged. No commit was made.

## Investigation: Paper.js 21/22 endpoint failures

The four new failures share the same cubic pair and expected near-shared start
point (the captured 21 and 22 fixture geometries repeat). The actual binary64
start points differ in y by 1.1368683772161603e-13, with identical x. They are not
an exact common endpoint, but are comfortably within the caller's default 1e-9
geometric tolerance. Their original midpoint is about 5.68e-14 from either end.

A direct probe of the compiled centered experiment separates endpoint discovery
from public validation. Both the centered raw beam report and endpoint-candidate
stage return empty lists: the candidate is lost before final validation.

| Coordinates | Endpoint separation | Internal endpoint/search tolerance | Endpoint found? |
| --- | ---: | ---: | --- |
| Original | 1.1368683772161603e-13 | 2.4746358424652494e-12 | Yes |
| [0,100]² | 1.7763568394002505e-13 | 3.552713678800501e-13 | Yes |
| Centered spans of 100 | 1.8118839761882555e-13 | 1.7763568394002563e-13 | No |

The solver's effective internal tolerance is
`max(min(options.tolerance, 1e-13), magnitude * 16 * machine_epsilon)`.
It is also passed to `elizabeth_endpoint_candidates`, which calls point-parameter
matching on the other curve. Centering roughly halves the normalized coordinate
magnitude (100 to 50) and therefore halves the roundoff allowance. The already
nonzero endpoint gap survives the transformation and falls just above the new
allowance. The requested internal 1e-12 is capped at 1e-13 before this allowance
is applied; merely raising that option would not fix this case.

Calling only the normalized endpoint-discovery helper with a diagnostic
allowance of 1e-12 recovers `(0,0)` in both directions. Those parameters evaluate
to the original endpoints and pass the original-coordinate tolerance. This is a
causal probe, not an adopted threshold or a full-suite-tested fix.

Conclusion: a tolerance/roundoff-policy mismatch in the replacement experiment,
not a failure of Newton convergence and not an exact crossing erased by the
coordinate map. Final validation alone cannot preserve tolerance semantics when
discovery rejects an acceptable near-contact first. Choosing a larger arbitrary
constant would conceal the dependence rather than resolve it. A next design
should separate original-metric coincidence checks from normalized numerical
refinement, or explicitly transform their acceptance regions and account for
input-coordinate precision. Original-coordinate endpoint matching could be kept
without restoring a second full beam search.

Artifacts: `endpoint-investigation.jsonl` contains measured values and candidate
lists; `investigate-endpoints.mjs` reproduces the probe against the **compiled
centered experiment** in `test_portable/build/dev/javascript`. It creates an
instrumented sibling JS module exposing the private endpoint helper; it does not
edit production Gleam source. Rebuilding that dependency from the restored
production source requires reapplying the experimental patch first to reproduce
the public centered result. This investigation did not rerun the full suite or
modify production code.
