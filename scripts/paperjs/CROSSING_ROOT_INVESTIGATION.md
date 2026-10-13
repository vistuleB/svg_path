# Crossing root investigation, 2026-10-13

**Historical pre-fix investigation of `a130b86`.** The subsequent
[fix report](CROSSING_BERNSTEIN_FIX.md) records the production changes and
validation. Run the investigator against the pre-fix revision; it asserts the
original failures and must not be used as a post-fix passing regression.

This investigates all eight remaining Paper.js Boolean comparisons whose first
failure is `CrossingMaxIterationsReached`: **103, 107, 128, 129, 130, 131, 168,
169**. They contain five distinct initial scalar problems. No production source
was changed. Experimental repairs run only in temporary copies of compiled JS.
The production disposition table remains unchanged.

## What fails

The callers project cubic controls onto a coordinate line, isolate the resulting
power-basis polynomial, then validate candidates against the actual segment.
Three stages disagree about what constitutes a root:

1. `internal/root.polynomial_root_isolations_valid` accepts both endpoints and
   derivative roots when their residual is below `1e-12 * max(abs(coefficients))`.
2. `polynomial_crossing_roots_loop` skips an entire derivative-partition interval
   if either boundary passes that relative zero test, even if its endpoint signs
   are opposite.
3. `polish_line_crossing_roots` requires geometric residual at most `1e-12` for
   these calls. The candidates from step 1 fail this stricter test.

In seven comparisons the first candidate is a derivative root numerically just
below 1, classified as a same-sign tangent contact. It is not the true crossing.
Its estimate is not exactly 1, so the existing exact-endpoint monotonicity fallback
is not used. The error is returned directly from the non-crossing candidate arm;
there is no 100-iteration refinement to exhaust. Increasing the limit to **1,000**
produces identical errors in all eight cases.

Fixture 107 has a genuine local extremum between an interior root and an exact
endpoint root. Its extremum is incorrectly accepted as a repeated-root candidate,
while the sign-changing interval that contains the interior root is skipped.
The endpoint and interior root must both survive isolation. Snapping to 1 or
searching the entire domain for a single root would lose this distinction.

The relative zero thresholds in these five witnesses range from approximately
`1.69e-11` to `9.24e-10`, substantially above the caller's `1e-12` tolerance.
Power-basis conversion also moves stationary endpoint parameters by a few ulps;
this determines whether the current exact-endpoint fallback happens to run.

`crossing-root-investigation.json` records coefficients, critical parameters,
classified candidate windows, results at both iteration limits, and independently
computed Bernstein roots. The latter agree with the earlier 80-digit witnesses
to within `1e-15` in parameter; evaluation through the actual segment API meets
`1e-12` for every recovered root. This is attainable accuracy, not a floating-point
resolution barrier in these inputs.

## Two compact reproductions

Use cubic x controls `[0, 1/3, 2/3, 1]` and the following y controls:

| Case | y controls | Supporting line | Expected roots |
| --- | --- | --- | --- |
| Monotone | `[8, 1.9, 0, 0]` | `y = 5e-12` | one, `t ≈ 0.9999990634143654` |
| Interior plus endpoint | `[-1000, -1000, 0.0001, 0]` | `y = 0` | `t ≈ 0.9999999000000134` and `t = 1` |

Both fail on Erlang and JavaScript at the existing `1e-12` tolerance.
The monotone control sequence proves there is only one root. For the second
case, the scalar polynomial factors as
`(1-t) * [-1000(1-t)^2 - 3000(1-t)t + 0.0003t^2]`, exposing the separate endpoint
root without relying on our solver.

Reversing the second case still fails. Reversing the first succeeds, but reveals
an additional target discrepancy described below. These are diagnostic probes,
not permanent tests asserting that failure is correct.

## Additional confirmed issue: signed-zero duplicates

For the reversed monotone reduction, the derivative solver supplies `-0.0` and
the domain endpoint supplies `+0.0`. `distinct_sorted_candidates` compares the
estimates with exact equality. Erlang distinguishes the signs; JS does not.

On Erlang, the root candidates contain both zeros and the geometric fallback
returns the **same crossing twice**. JavaScript returns one crossing. This is
not an ambiguity about near roots: the two returned parameters are identical.
The module promises distinct roots. Canonicalizing mathematical zero before
candidate deduplication is the narrow repair; retain the stronger derivative
multiplicity evidence when merging, as the existing code intends.

The repository already provides `number.normalize_zero` for this purpose.
`crossing-root-native-results.json` preserves the root-candidate and crossing
outputs from both targets.

## What happens after the initial root failure is bypassed

A diagnostic fallback retries only failed cubic-line queries. It evaluates the
projected Bernstein polynomial with de Casteljau, recursively partitions at
roots of its derivative, keeps exact endpoint hits, and bisects strict sign
changes to floating-point parameter resolution. Every returned parameter is
also checked through the existing segment evaluation against the unchanged
geometric tolerance. A control polygon wholly beyond the tolerance on one side
of the line proves an empty result.

This is **not a production-ready general isolator**. It does not supply the
package's classified-root semantics or a complete policy for uncertain tangent
contacts, and successful original queries are left untouched. It is evidence
about the causes and subsequent blockers, not proof of general safety.

The eight-case experimental screen gives:

| Fixtures | Outcome after diagnostic fallback |
| --- | --- |
| 103 | sampled geometry match, maximum boundary distance about `8.23e-6` |
| 168, 169 | sampled geometry matches, distances about `1.40e-5`, `1.28e-5` |
| 128, 129 | a second scalar query, then `NonAffineOverlapCorrespondence` |
| 130, 131 | `NonAffineOverlapCorrespondence` |
| 107 | exceeds the 30-second diagnostic limit after the scalar query succeeds |

The later overlap errors are newly exposed blockers; their specific witnesses
have not been independently verified like the earlier 55 overlap limitations.
Do not reclassify them as understood merely from their error name.

### 128/129: a spurious root where there is no root

The second scalar query has projected controls
`[30.943504188286397, 30.943504188286397, 3.6493474908638746e-11,
3.6493474908638746e-11]`. Every value is positive and greater than `1e-12`.
The Bernstein convex-hull property proves there is no zero, nor a point within
the requested line-distance tolerance. Nevertheless, the original solver
produces a near-endpoint candidate and raises `CrossingMaxIterationsReached`.
This reproduces independently on both targets. Returning an empty list for this
certifiably separated query exposes the subsequent overlap error.

### 107: downstream intersection work

Both scalar roots are recovered with zero residual under the existing segment
evaluation. The experiment then stalls in later curve-pair intersection work.
CPU samples concentrate in `intersections.spatial_diversity_pass` and associated
intersection processing, not the scalar isolator. `crossing-root-profile.json`
records the sampled function totals. The 30-second timeout does not establish
nontermination or correctness of that downstream computation; its full cause
remains outside this scalar-root investigation.

## Recommended repair scope

1. Fix signed-zero candidate deduplication, with an Erlang/JS regression.
2. Repair the Bézier–line isolation path using projected controls and stable
   Bernstein evaluation. Preserve derivative-partition evidence until geometric
   refinement, rather than assigning a narrow window around an unverified
   coefficient-relative candidate. Preserve the two roots in case 107 and
   explicitly reject certifiably root-free intervals.
3. Keep geometric acceptance tolerance separate from root-count/isolation
   decisions. A small extremum value must not automatically erase adjacent
   sign-changing intervals. Handle genuine tangent contacts explicitly.
4. Add both reductions in both orientations, the no-root witness, endpoint and
   true-tangent controls, close distinct roots, and scale/translation variants.
   Rerun all eight original cases and the full saved Boolean screen. Only then
   assess the newly exposed overlap and curve-pair failures.
5. Run the full release suite on both targets and regenerate published figures
   before accepting a production solver change.

Changing the generic polynomial relative tolerance globally is not recommended:
it also serves extrema, curvature and convex-hull computations. Simply widening
all windows or increasing iteration limits does not address the root evidence.
The existing `CrossingMaxIterationsReached` name is also misleading for rejected
unbracketed or false tangent candidates; a repair should document or distinguish
those failure paths rather than suggesting that more iterations will help.

## Reproduction

```sh
(cd test_paperjs && gleam build --target javascript)
node scripts/paperjs/investigate-crossing-roots.mjs
# Also run the temporary repair experiment, requiring the pinned Paper.js install:
node scripts/paperjs/investigate-crossing-roots.mjs --screen
(cd test_paperjs && gleam run --target erlang -m paper_crossing_roots_probe)
(cd test_paperjs && gleam run --target javascript -m paper_crossing_roots_probe)
```

The eight original scalar cases, four reduction/orientation cases, additional
no-root query and signed-zero candidate query were run on both targets. The JS
experiment asserts agreement with the earlier independent high-precision roots
for all initial witnesses. Native outputs are recorded, not counted as passing
regression tests. Full tests and figures were not rerun: production is unchanged.
