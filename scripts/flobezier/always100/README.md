# Always normalize supplementary search to 100 × 100

Experiment date: 2026-10-14. Baseline: commit `269a535`.
The experiment is saved as `experiment.patch`; the production source has been
restored to the baseline. No test expectations were changed in the repository.

## Variant tested

Remove the 1,000,000:1 aspect-ratio trigger. Every polynomial curve pair that
reaches the supplementary search and has finite positive combined control-point
ranges is normalized independently into [0,100] × [0,100].

This remains the supplementary search: original candidates are retained,
overlap classification still runs in original coordinates, and added candidates
must pass the original-coordinate tolerance checks. The normalized search
residual setting stays at 1e-12. The original line-specific dispatch, constant
handling, arc exclusion, and zero-range exclusions remain in place. This is not
a replacement of all geometric operations by operations on normalized geometry.

## Full test inventory

Profiles were run separately so failure of one did not skip the others.

| Command | Passed | Failed | Elapsed seconds |
| --- | ---: | ---: | ---: |
| `scripts/test-fast` | 2010 | 2 | 58 |
| `scripts/test-slow` | 31 | 0 | 67 |
| `scripts/test-portable erlang all` | 757 | 1 | 64 |
| `scripts/test-portable javascript all` | 757 | 1 | 87 |

These timings are wall-clock observations, not controlled comparisons against
the baseline. An interrupted first slow run exited 137 after 53 seconds and
was excluded from the result inventory. No processes survived; the temporarily
parked fast-test directory was restored before rerunning the slow suite.

## Unique failing tests

1. `svg_path_geometry_test.gleam`:
   `segment_intersections_prefers_shared_endpoint_over_near_endpoint_minimum_test`
   - First failure: raw candidate count is 5, expected 4.
   - Decimal-snapped candidate count is also 5, expected 4, discovered in the
     diagnostic continuation below.
   - This module is not selected by the portable registry, so this failure
     appears in the root suite only.
2. `svg_path_intersections_test.gleam`:
   `flat_cubic_crossing_regression_test`
   - Candidate count is 14, expected 9.
   - Fails in the root fast suite and both portable targets.

Both tests explicitly describe these counts as snapshots, not mathematical
root counts. Their geometric candidate checks pass before the failing snapshot
assertions. The flat cubic case still includes its known (0.5,0.5) contact.

## Checking assertions after the first failure

Separate temporary copies of the two modules were compiled in
`/tmp/svg-path-always100/diagnostics`. Only their count-snapshot assertions were
replaced by printing the observed counts; all geometric and shared-endpoint
assertions remained active. The repository tests were not edited.

Commands, in that temporary directory:

- `gleam run --target javascript -m snapshot_diagnostics`
- `gleam run --target erlang -m snapshot_diagnostics`

Both completed successfully, reporting raw=5, snapped=5, flat-contact=14.
Thus the two unique failures are candidate-inventory changes, with no additional
failure found in their remaining geometric or endpoint-preservation assertions.
This does not prove the extra candidates are distinct exact roots or improve
root isolation; the supplemental search can enlarge near-contact clouds.

## Conclusion and artifacts

No geometric-validity, topology, or other assertions failed in these completed
test profiles. Always-on normalization nevertheless changes observable result
counts, so the variant does not pass the unchanged suite and has not been adopted.
It demonstrates that the aspect-ratio restriction can be removed without broad
failures in this suite; it does not establish that always running the extra pass
is beneficial. Published figures were not regenerated for this experiment.

Cleaned logs, including all failure messages, and the patch are stored alongside
this file. Raw logs and the temporary diagnostic runner remain under
`/tmp/svg-path-always100`. The committed production implementation is restored.

## Investigation of the two count failures

The captured JavaScript builds of baseline and experiment were queried directly
with the two original fixtures. `candidates.json` records all returned raw
parameter pairs and points. `analyze-candidates.py` evaluates the original
binary64 control coordinates and returned parameters with 90-digit Decimal
arithmetic; `candidate-analysis.log` records the results. Run:

`python3 scripts/flobezier/always100/analyze-candidates.py`

All baseline parameter pairs are retained exactly. None of the six additions is
an exact root of the original curves at its returned parameters.

### Flat crossing: five more approximations of the same root

Both curves have the same strictly increasing x polynomial. Their y coordinates
are `(t - 0.5)^3` and `-(t - 0.5)^3`, respectively. Equality of x forces equal
parameters, so their sole exact intersection is `(t,u) = (0.5,0.5)`.
(The stored binary64 one-third controls do not give exactly x=t, but this does
not affect monotonicity or the argument.)

| Added t=u | Original curve-to-curve separation |
| --- | ---: |
| 0.49999411056574239 | 4.0855519e-16 |
| 0.49999792909119989 | 1.7762861e-17 |
| 0.50000070562865873 | 7.0268168e-19 |
| 0.50000423377195213 | 1.5177924e-16 |
| 0.50000635065792820 | 5.1225494e-16 |

These lie inside the existing candidate span, roughly 0.499969–0.500034.
Normalization increases its population, not its extent or mathematical root
coverage. The exact central root was already present. Cubic-order separation
means excellent residuals can coexist with comparatively large parameter error.

### Shared endpoint: one more approximation near the stationary endpoint

The addition is `(t,u) = (0.99999945117770994,
1.1680608590306609e-11)`. Its high-precision original-coordinate separation is
2.3652745e-16. The left curve's last two controls coincide, so its derivative
vanishes at t=1 and small geometric error does not imply equally small parameter
error.

Starting Newton refinement at this addition, using 90-digit arithmetic on the
original controls, approaches the already-present exact endpoint `(1,0)`:

| Steps | 1-t | u |
| --- | ---: | ---: |
| 1 | 2.74416282e-7 | 2.20612757e-16 |
| 10 | 5.35979311e-10 | 1.64304190e-24 |
| 30 | 5.11149722e-16 | 1.42511215e-42 |
| 60 | 4.76045275e-25 | 1.15119643e-69 |

This supports classifying the addition as another endpoint approximation, not
a newly recovered distinct intersection. Newton convergence is local evidence,
not a proof excluding other intersections elsewhere on these curves. The exact
endpoint remains present, and the addition lies within the old candidate span.

### Cause and recommendation

The supplementary merge deduplicates by a fixed 1e-7 distance in parameter-pair
space. Each addition is farther than this from the retained pairs, despite its
very small geometric residual. Changing coordinates changes the numerical
search and yields different representatives of these ill-conditioned contacts.
The merge retains the old representatives and adds the new ones.

These are count-snapshot failures, not newly demonstrated violations of the
module's documented bounded-search contract, which explicitly permits several
acceptable candidates near one tangential contact. They expose an existing
root-isolation limitation more strongly: the baseline already returns 4 and 9
candidates in these cases. Always-on supplementation does not improve these two
results. Do not interpret 5 or 14 as recovered root counts, and do not increase
the dedupe radius indiscriminately: that can merge genuinely distinct nearby
intersections. A separate contact-isolation/refinement change would need its own
regressions. These two failures alone do not establish that normalization is
geometrically wrong or justify adopting it unconditionally.

Production source and repository test expectations remain unchanged. This
investigation ran the candidate probes and Decimal analysis, not another full
suite; the completed full-profile and two-target diagnostic results above still
apply to the saved experiment.
