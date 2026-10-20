# Circular near-semicircle rotation accuracy — 2026-10-19

Baseline: `2abb659`. No production edits in this investigation.
Follow-up to the remaining rotation limitation in SEMICIRCLE-ACCURACY-TRIAGE.md.

## Finding

For exactly equal absolute radii, x-axis rotation cannot change the geometric
circle. The current endpoint-to-center conversion rotates the half-chord before
computing the center; rounding those coordinates is amplified near a semicircle.
The preceding compensated-product repair cannot recover that lost information.

The original three exact SVG circular inputs were checked at seven rotations
(0, 17, 37, 73, 90, 137, 359 degrees), all four large-arc/sweep combinations:
84 cases. Comparing with the identical input at rotation zero gives:

| Quantity | Current maximum discrepancy | Experimental maximum discrepancy |
| --- | --- | --- |
| Center | 9.919999944e-6 | 0 |
| Five sampled curve points | 9.919999944e-6 | 4.067384e-12 |
| Bounding-box coordinates | 8.416362107e-6 | 3.637979e-12 |

These are invariance comparisons, not a new independent arbitrary-precision
oracle. The earlier exact-input oracle validates the rotation-zero centers.
The origin-centered representative also reproduces rotation-sensitive centers
on Erlang (`circle-rotation-erlang.log`). Thus this is avoidable native numerical
error, not an upstream representation mismatch or a new snapping policy.

## Candidate

For a circle only, compute the center and sweep with rotation zero, retain the
supplied x-axis rotation in CenterArcData, and subtract that rotation from the
start angle (normalized to the usual angular interval). This preserves the
parameterized geometry and the public rotation field. The experiment uses public
conversion/evaluation functions with an explicitly constructed candidate center
record; it does not patch production source or a generated build.

Only exact equality of absolute radii should select this branch. Do not classify
nearly equal elliptical axes as circular or silently change an ellipse to a circle.
Unequal-radius near-semicircles can still suffer transformed-coordinate rounding;
this candidate does not solve that general problem. Residual sampled/bounds
errors in the candidate are ordinary angle/trigonometric rounding.

Recommendation: implement a narrowly scoped circular conversion path, add
portable rotation-invariance regressions including flags, negative radii,
translations, exact semicircles and radius enlargement, then run the full suite
and regenerate figures. Preserve the unequal-radius conversion path. No API or
option change is required. The 84-case experiment is not full-suite validation.

## Reproduction

Run `node scripts/cavalier/probe-circle-rotation.mjs` after building the portable
JavaScript package; saved output: `circle-rotation-experiment.json`.
Run `gleam run -m circle_rotation_audit_probe` in `scripts/cavalier/probe` for
the Erlang baseline. No permanent test edits, F# work or commit in this phase.

## Production candidate — 2026-10-20

The shared internal endpoint conversion now computes exactly circular inputs at
zero rotation, then rotates the start unit direction into the caller's axis
frame and uses atan2 to obtain the start angle. The rotation field, sweep and
corrected radii are retained. Unit-vector rotation uses the existing degree
helpers, avoiding direct subtraction of potentially huge angles. All internal
consumers use this path; unequal absolute radii retain the general conversion.

Two new portable tests cover rotation invariance with flags and translation,
five curve samples and bounds, plus negative radii, exact semicircles and radius
enlargement. The canonical release run and published-figure regeneration are
being performed; final results will be recorded below.


## Completed validation — 2026-10-20

- `scripts/test-release` (Node 24.10.0 on PATH, Gleam 1.18.1): 2,088 ordinary,
  31 slow, 834 portable Erlang and 834 portable JavaScript tests passed.
- `scripts/generate-published-figures`: repeat ordinary suite passed; 13 README
  and 34 Gallery figures regenerated successfully, all 47 byte-identical.
- Production 84-case probe: zero center variation; maximum sampled difference
  4.067384e-12 and bounds difference 3.637979e-12, relative to rotation zero.
  The historical `baseline*Error` JSON keys denote the implementation under
  test; in `circle-rotation-production.json` they therefore describe production
  after the repair, not the original baseline.
- Formatting, whitespace and audit metadata checks passed.

Evidence: `circle-rotation-production.json`, `circle-rotation-test-release.log`,
`circle-rotation-figures.log`, `circle-rotation-figure-comparison.json`.
The circular repair is validated but not committed. Unequal-radius elliptical
conditioning remains separate; this does not close investigation group #3.
F# remains deferred.
