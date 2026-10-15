# Centered single-search curve intersections

Adopted 2026-10-15, replacing the supplementary-search approach recorded in
`PRECONDITIONING_EXPERIMENT.md`.

## Implementation

For eligible polynomial pairs reaching the general curve solver, use their
combined control-point bounds (not expensive exact curve bounds). With positive,
finite coordinate ranges, translate to the box center and scale independently
into approximately [-100,100] on each axis:

```
x' = 200 * ((x - (xmin + (xmax - xmin) / 2)) / (xmax - xmin))
```

Use the analogous mapping for y. Run one beam search with normalized internal
tolerance 1e-12 and the caller's depth limit. The existing roundoff-adjusted
residual policy still applies internally. Arc pairs and invalid/zero-range cases
retain their ordinary search. Existing line/constant dispatch is unchanged.

Endpoint matching remains on the original curves with their original internal
roundoff-adjusted tolerance. Those matches seed the normalized search in place
of its normalized-coordinate endpoint discovery. This is not a second beam
search. Overlap decisions also retain the original metric.

Evaluate returned parameters on the original curves to obtain reported midpoints.
The existing polishing/certification path enforces the caller's tolerance and
raises its existing certification error when it cannot be achieved. Do not
silently filter uncertifiable candidates into an empty successful result.

Public types and options are unchanged. Search results are numerical candidates,
not a certified count of mathematical roots; normalization can change candidate
counts and parameter representatives. Final residual bounds do not imply root
completeness or parameter-error bounds at ill-conditioned contacts.

## Why centering and original-coordinate endpoint matching matter

Mapping the flat cubic crossing to [0,100] moved its contact from y=0 to y=50.
Nearby positive/negative deviations then rounded to the same coordinate, losing
the exact midpoint representative. Centering restored that representative.

Paper.js fixtures 21/22 have a near-shared endpoint separated by 1.14e-13 in
original coordinates. Centered normalization produces a gap of 1.81e-13 while
its coordinate-based internal allowance is about 1.78e-13. Original-coordinate
endpoint discovery retains this valid near-contact without changing the caller's
final tolerance. All four point/address regression checks pass with this design.

## Reviewed test changes

- Shared stationary endpoint: raw and snapped count snapshots change 4 -> 2.
  Exact endpoint preservation, candidate validity and separation checks remain.
- Off-center quadratic contact: count 4 -> 1; known-root and residual checks remain.
- Flat cubic crossing: count 9 -> 6; exact central contact remains and known-root
  accuracy and residual checks remain.
- Replace the supplementary-search requirement to retain every original raw
  candidate with original-coordinate tolerance and endpoint-preservation checks.
  Known thin-curve-root checks in both orientations remain.

Temporary test copies first exercised all assertions beyond the failing snapshots
on Erlang and JavaScript; both certification-error regressions also passed after
restoring the existing certification path. Candidate inventories showed smaller
maximum original-coordinate curve-to-curve residuals in all three snapshot cases.

## Figure validation

All 13 README and 33 Gallery figures regenerated successfully against the
original [-50,50] version of this algorithm before adoption. The canonical generator's test-fast gate was run
separately because the then-unchanged snapshots failed; all subsequent generation,
verification and promotion steps ran unchanged, with an explicit root build.

45 SVGs were byte-identical. The second-offset arrangement changed only 86 numeric
text/circle position attributes across 58 elements (maximum delta 1.55e-10 SVG
units). All 8,638 elements retained their order and structure; path data and text
content were unchanged. The regenerated figure is included in this change.

## Adoption validation

`scripts/test-release` completed successfully with the adopted source and reviewed
expectations on 2026-10-15:

- Root fast: 2,012 passed, no failures.
- Root slow: 31 passed, no failures.
- Portable combined Erlang: 758 passed, no failures.
- Portable combined JavaScript: 758 passed, no failures.

`git diff --check` also passed. F# migration is not included in this change.

## Normalized window follow-up

On 2026-10-15 the multiplier was doubled to 200 for a [-100,100] window.
All four full profiles passed with unchanged test expectations: 2,012 fast,
31 slow, 758 portable Erlang and 758 portable JavaScript. See
[centered200/README.md](centered200/README.md) for commands and logs. The canonical figure generator was also rerun successfully: all 46 published
SVGs are byte-identical to the [-50,50] outputs. The captured-comparison corpus
was not rerun for this window-size follow-up.
