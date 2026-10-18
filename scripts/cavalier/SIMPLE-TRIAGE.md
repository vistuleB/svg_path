# First triage: scalar policies and shallow-arc projection

> Current status (2026-10-18): projection fixes are committed as `dacdb370` and
> `090f8e63`; the original collection wording below is historical. See
> [RESUMED-TRIAGE.md](RESUMED-TRIAGE.md) and `triage-dispositions.json` for the
> latest dispositions. Raw baseline counts and results are preserved. Audit open; F# deferred.

2026-10-16, native source `75970a6`. Stopped at a confirmed native numerical
convergence defect, as requested. No production code or permanent suite tests
were changed; the standalone probe is diagnostic material.

## Disposed without a fix

- `CX00982`, negative point-at-length distance: Cavalier clamps to the start;
  our `validate_length_distance` explicitly rejects distances outside `[0,length]`
  with `InvalidLengthDistance`. Different API contract, not a bug.
- `CX00167`, distance from arc start near the endpoint: upstream explicitly snaps
  within `1e-5`. The adapter composes our nearest-point projection and arc length,
  which does not request that endpoint-snapping policy. Its result differs by
  approximately `1e-6`, consistent with the unsnapped location. Not a bug.
- `CX00755`, `CX00804`, `CX00832`, nearest points queried at a circle's center:
  every arc point is an equally near witness. Our root `Projection` contract
  explicitly permits any tied minimum. Different returned coordinates are not
  failures. The first two witnesses lie at radius 2 about `(2,0)`; the third at
  radius 1 about `(0,0)`.

The six near-semicircle center/bounds flags remain unresolved. They involve
bulge-to-SVG conversion conditioning, and have not been labelled native bugs.

## Confirmed defect: shallow-arc nearest-point convergence

The projection error family first appears in captured case `CX00881` and related
point/threshold cases. A smaller native reproduction removes the bulge adapter:

```xml
<path d="M 0 0 A 10000000 10000000 0 0 1 10 0"/>
```

Query `distance.segment_projection(Point(3, 1), arc)` with default options.
Both Erlang and JavaScript return:

```text
DistanceMaxIterationsReached(0.2999999802063109, 1.825134034865738e-8)
```

Increasing the iteration limit from 100 to 1,000 returns exactly the same error.
The otherwise identical radius-1,000,000 control succeeds on both targets.

An independent 80-digit Decimal radial projection gives the unique interior
nearest point approximately `(2.99999979999977, -0.000001049999960000028)` and
shortest distance `1.000001049999980000053`. The point is strictly within the
lower minor arc. See `shallow-arc-analytic.json`; this expected answer does not
come from Cavalier or from the native solver.

### Observed cause

`refine_arc_projection_window_by_bisection_loop` in `src/svg_path.gleam` rebuilds
each narrow bracket as an endpoint-form SVG arc, computes its bounding box,
and requires that box's taxicab diameter to be at most `1e-9`.

The public-operation replay in `probe-distance-bracket.mjs` records:

- Bracket endpoints eventually become adjacent representable parameters:
  `0.29999998020631086` and `0.2999999802063109`.
- Their difference is about `5.55e-17`; the arc's speed is about 10, so the exact
  original-arc interval has geometric size about `5.55e-16`.
- Evaluating the original arc through its large center/radius introduces a
  positional quantization step. Reconstructing the bracket produces bounds of
  diameter about `1.6081e-9`, larger than the stopping tolerance.
- The midpoint becomes identical to an endpoint. The loop does not detect this
  stagnation and repeats until the iteration limit, without narrowing further.

This is a native numerical-convergence defect, not an upstream output convention
or an insufficient iteration budget. The error result avoids returning an
uncertified answer, but more iterations cannot repair the numerical path.

### Fix direction and trial

Keep refinement in the original arc's parameterization instead of reconstructing
an ill-conditioned endpoint-form arc for every bracket. A conservative speed
bound times parameter width can certify bracket size (`segment_derivative_scale`
already supplies an arc speed bound). Evaluate shallow-arc points/residuals
stably using local angular increments, and handle adjacent-parameter stagnation
explicitly. Preserve the caller's geometric tolerance and curved geometry;
do not silently substitute a line or merely increase the iteration limit.

The investigation called for targeted regression tests, including the original
oblique shallow arc, reversed traversal, translated inputs, and non-circular
ellipses. The subsequent trial and validation are recorded below.

## Reproduction and evidence

```sh
node scripts/cavalier/probe-simple-distance.mjs
node scripts/cavalier/probe-distance-bracket.mjs
(cd scripts/cavalier/probe && gleam run)
(cd scripts/cavalier/probe && gleam run --target javascript)
```

- `simple-distance-sweep.json`: radius/query sweep on JavaScript.
- `distance-bracket-trace.json`: 100-step public-operation bracket replay.
- `shallow-arc-erlang.log`, `shallow-arc-javascript.log`: successful probe runs
  showing the error on both targets and the 1,000-iteration control.
- `shallow-arc-analytic.json`: independent high-precision expected geometry.

Raw broad-audit results are preserved. These dispositions do not retroactively
change a raw comparison failure into a pass.

## Projection trial (2026-10-16)

The Gleam trial keeps the bracket on the original ellipse, bounds its geometric
width by maximum speed times parameter width, and evaluates point/derivative
using angular increments relative to the nearer original endpoint. It detects
an unshrinkable floating-point bracket rather than repeating until exhaustion.
There is no circle-only fast path, tolerance relaxation, or public API change.
The original center conversion is still performed for each evaluation; this is
not a cached-geometry implementation.

`extra-results-distance-trial.jsonl` preserves a separate replay of all 1,057
supplementary comparisons. Relative to the baseline: 35 errors become matches,
937 matches remain matches, 73 scope entries remain scope, ten discrepancies
remain discrepancies, and the negative-length rejection remains an error.
One match becomes a raw discrepancy: CX00749 compares distance strictly to zero
at a circle point. The trial returns 4.440892098500626e-16 instead of exactly zero;
this is a rounding-level comparison difference, not a tolerance violation.
The original raw results are unchanged.

The reduced radius-10,000,000 circular case now returns distance
1.00000104999998 and a closest point within 4.8e-11 of the independent 80-digit
oracle on Erlang. Increasing the iteration budget is no longer necessary.
The trial regression module `test/svg_path_cavalier_projection_test.gleam`
checks circle and non-circular ellipse analytic answers, both directions,
a rotated/translated ellipse, and endpoint minima at 1e-9 absolute accuracy.
The original oblique shallow arcs are covered by the supplementary replay.

Validation completed:

- `scripts/test-all`: 2,042 main tests and 31 slow tests passed, no failures.
- `scripts/test-portable all all`: 788 tests passed on Erlang and 788 on
  JavaScript, no failures. Includes all four new regression tests.
- `gleam format --check src/svg_path.gleam test/svg_path_cavalier_projection_test.gleam`
  and `git diff --check`: passed.
- Supplementary replay command:
  `CAVALIER_CASES=extra-cases.json CAVALIER_RESULTS=extra-results-distance-trial.jsonl node scripts/cavalier/compare-captured.mjs`.

Suite logs are preserved as `projection-trial-test-all.log` and
`projection-trial-portable.log`. This validates the localized projection fix;
it does not close the other Cavalier discrepancies or establish complete audit
parity. Published figures were not regenerated for this trial. No F# port was
made. Recommendation: retain the fix, with no circle-only special case needed
for this failure family.


## Analytic circular-arc path (2026-10-16)

The preceding general fix was committed as `dacdb37`. The next Gleam change
uses radial projection plus endpoints when the corrected radii are exactly equal.
It uses the directed angle from the original start radius, with a local cross
product near the start to retain shallow-arc precision. It handles both sweep
directions, major/minor arcs, SVG radius correction, and circle-center ties.
Elliptical arcs retain the general solver. Options remain validated even when
sampling and iteration budgets are unused by the analytic circle path.

`extra-results-circle-trial.jsonl` replays the 1,057 supplementary comparisons.
All 35 shallow-arc repairs remain matches. Relative to the general fix replay,
three circle-center tie discrepancies become matches (CX00755, CX00804, CX00832).
Two matches become endpoint-tie discrepancies: CX00762 chooses (0,0) rather
than (4,0) for query (2,3) on the lower semicircle; CX00797 makes the same choice
for query (2,-2) on the upper semicircle. In each case both endpoints are global
minima, with exactly equal distances (sqrt(13) and sqrt(8), respectively).
These are output-choice differences, not distance defects. The CX00749
strict-zero rounding discrepancy remains. Remaining statuses are unchanged.

Seven further regression tests exercise minimal positive sampling/iteration
budgets, inside/outside radial queries, near-center queries, excluded radial
angles, major/wrapped sweeps, center ties, negative/corrected radii, shallow
circles, reversal, and invalid options.

Validation of the analytic circle addition:

- `scripts/test-all`: 2,049 main tests and 31 slow tests passed.
- `scripts/test-portable all all`: 795 tests passed on each of Erlang and JavaScript.
- All runs completed with no failures.
- Formatting checks and `git diff --check` passed.
- Logs: `circle-projection-test-all.log`, `circle-projection-portable.log`.

The analytic addition was committed as `090f8e6`, separate from `dacdb37`. F# has not
been changed. Published figures were not regenerated in this step.
