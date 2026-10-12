# Paper.js Boolean audit: first batch

Date: 2026-10-12. Gleam library revision:
`03c95a0a4053b58d8039481fac5d6e52b6820e95` (production source unchanged).
Paper.js source revision and license are recorded in `inventory.json` and
`upstream/LICENSE.txt`; extraction runtime is separately pinned to paper 0.12.18.

## Crossing fix follow-up (2026-10-12)

The results below record the original unmodified-source screening. The current
working tree now contains a narrow crossing fix in `src/svg_path.gleam`:
rejected endpoint candidates may be refined over [0,1] only when ordered
projected Bézier controls prove monotonicity. The existing root solver,
nonmonotone isolation handling, tangent handling, tolerances and iteration
limits are retained. This is deliberately not a general near-tangency repair.

Six regressions cover inside/outside lines, reversed curves, quadratic and cubic
curves, a curved monotone projection, exact endpoint contact, interior tangency,
two crossings, and the iteration limit. The two inside/outside test functions
fail against the saved pre-change JavaScript build and pass after this change.

Validation: `scripts/test-portable` passed 443 tests on Erlang and 443 on
JavaScript; `scripts/test-fast` passed 1,728 tests. The native Boolean diagnostic
was rerun on both targets: fixture 16 and the reduced cubic rectangles now return
`NonAffineOverlapCorrespondence`, rather than the crossing error. The remaining rectangle
Boolean failure is recorded as an accepted API limitation, per the user’s
2026-10-12 decision; no further fix is planned for this fixture. This disposition
is separate from the crossing defect, which was fixed. It does not classify
the other overlap-correspondence errors automatically. Fixtures 69 and 172 retain
their topology errors. The full 178-comparison screening has not been rerun;
its JSON results are the baseline, not results for this fix.

No overlap fix, F# change, commit or release has been made.

## Scope and results

All 50 upstream Boolean blocks were executed for extraction, without extraction
errors. They contain 178 `compareBoolean` geometry comparisons and two other
assertions. The 178 comparisons belong to 49 blocks: #973 only asserts child
orientation after resolveCrossings, and is not covered by this geometric probe.
The other non-geometric assertion is #1221's divided-child count.

Final JavaScript screening, with a 30-second worker limit:

| Result | Comparisons |
| --- | ---: |
| Sampled geometry matches | 92 |
| Library returns an error | 79 |
| Different API / adapter needed | 7 |
| Timeouts | 0 |
| Sampled geometry mismatches after a successful result | 0 |

Two cases (154, 155) initially exceeded ten seconds; both completed and matched
with the longer budget. These timings include startup, CSG and comparison, and
are not isolated CSG benchmarks. Their outputs have many more curve pieces than
the reference, so a geometric match does not imply equivalent output simplicity.

The 79 errors comprise 41 `CrossingMaxIterationsReached`, 29
`NonAffineOverlapCorrespondence`, six `InternalBoundaryTopologyError`, and three
`Discontinuous`. These are not 79 independent bugs. Three representative failures
have been confirmed natively on both backends; the remaining error cases need
individual classification. In particular, non-affine overlap correspondence is
a documented limitation, but the error name alone does not establish that every
such case is a legitimate limitation rather than an erroneous detection.

## Baseline confirmed failures and subsequent disposition

### Fixture 16: frame.intersect(rect) — crossing fixed; remaining limitation accepted

Both Erlang and JavaScript return:

```text
ArrangementGraphError(PathError(CrossingMaxIterationsReached(
  estimate: 1.0, value: 6.969003152335063e-11)))
```

This reduces to two axis-aligned closed rectangles:

- left: x = 150..200, y = 80..160;
- right: x = 50..150, y = 50..200.

Their interiors are disjoint; they share the vertical edge x = 150, y = 80..160.
The filled intersection should be empty. With each edge represented as
`CubicBezier(start, start, end, end)`, the query errors. Replacing each edge by
`Line(start, end)` preserves exactly the same geometry and returns an empty
path on both targets. This is a reproducible numerical failure on valid geometry,
not a Paper.js contour-order convention or a JavaScript adapter issue.
Further tracing isolated the failing call to endpoint matching inside curve–curve
intersections: `elizabeth_endpoint_candidates` →
`overlap_detection.point_parameters` → coordinate ray crossings →
`polish_line_crossing_roots`. Logging was added only to a copied JavaScript build
under `/tmp`; production source was not instrumented.

One split endpoint has y = 80.00000000006969. Matching that point against the
vertical cubic `(150,160), (150,160), (150,80), (150,80)` uses a signed line-distance
tolerance of 1e-12. The polynomial solver supplies a `NegativeToNegative` candidate
at t = 1, with isolation interval `[0.9999999995, 1]`. Its geometric residual is
6.969003152335063e-11. The non-sign-changing branch of
`polish_line_crossing_roots` immediately returns `CrossingMaxIterationsReached`;
it does not attempt refinement. This is not exhaustion of 100 bisection steps.

A standalone query confirms the defect on both targets, without CSG, splitting,
or arrangement. For that cubic and horizontal supporting lines:

| Line y | Expected geometry | Cubic result | Equivalent Line result |
| --- | --- | --- | --- |
| 80 | endpoint intersection | endpoint | endpoint |
| 80.00000000006969 | one interior intersection | error | one intersection |
| 79.99999999993031 | no intersection | error | empty |

The cubic y coordinate decreases monotonically from 160 to 80, so these expected
intersection counts do not depend on Paper.js. The inside case demonstrates why
simply discarding rejected endpoint candidates would be an unsafe fix: a real
root must be recovered. The outside case requires rejecting the spurious
candidate. The exact root-isolation change needed remains to be designed.

Run the additional diagnostic on either backend:

```sh
cd test_paperjs
gleam run --target erlang -m paper_crossing_probe
gleam run --target javascript -m paper_crossing_probe
```

Both commands completed with the table's results. This diagnostic prints results;
it deliberately does not assert that the current errors should persist. No claim
is made yet that this cause explains the other 40 convergence-error fixtures.

### Fixtures 69 (#1123) and 172 (#1506)

Both reproduce `InternalBoundaryTopologyError(..., SectorMismatch)` on Erlang
and JavaScript (vertices 7 and 4 respectively). Neither uses a derived Paper.js
operand, differing operand fill rules, nor `trace: false`. The error is explicitly
defined by our CSG API as an internal reconstruction consistency failure.
These are confirmed failures; whether they share one underlying cause remains
unknown. #1506 is the difference of two closed curved shapes supplied directly
as SVG path strings in the upstream test.

Run the preserved native reproducer from the repository root:

```sh
cd test_paperjs
gleam run --target erlang -m paper_boolean_probe
gleam run --target javascript -m paper_boolean_probe
```

It prints the three original failures and the reduced rectangle comparison.
It is diagnostic output, not a test that asserts those failures should persist.

## Comparison method and limits

`booleans.json` preserves cubic control points, closure and fill rules. The
extractor snapshots operands immediately before the operation. Expected geometry
comes from upstream's explicit expected result, not a fresh Paper.js solver output.
Paper.js executes setup and chained operations during extraction. Five comparisons
therefore have derived operands and are marked accordingly: screening those final
steps is not an end-to-end Gleam test of their full operation chains.

The probe calls Gleam's compiled JavaScript CSG with default options. Unary
`unite` and the geometry-only screening of `resolveCrossings` use union with an
empty path; this does not test Paper.js's object mutation or child orientation.
Open subpaths keep their closure flag; filled CSG uses implicit SVG closure.
Mixed operand fill rules are excluded because Gleam binary CSG takes one rule.

Successful results are serialized with system float precision and explicit
curve commands, avoiding the normal five-decimal output rounding. Paper.js is
used as an independent inspection engine for both result and expected geometry:

- nine sample points per curve, in both directions, with nearest-boundary
  distance at most 0.001 path units;
- a 25-by-25 fill grid plus samples on both sides of each curve;
- samples within 0.001 of either boundary are excluded from fill comparison.

This detects substantial discrepancies independently of contour order or curve
subdivision, but is not a proof of equal regions or equal topology. Features
smaller than the sampling/allowance can be missed. No general correctness claim
is made for the 92 matches. `boolean-screening.json` retains actual distances,
sample counts, output paths, errors and timings for every comparison.

Seven comparisons require different adapters: fixture 44 uses different operand
fill rules; fixtures 26, 71, 73, 75, 77 and 78 involve open-path clipping or
postprocessing/divided child results. These should be adapted to the appropriate
API rather than counted as failed filled-region CSG tests.

## Incorporated regressions and validation

The 16 nested/disjoint rectangle comparisons from the first upstream block are
now portable Gleam tests in `test/svg_path_paper_boolean_basics_test.gleam`.
They retain cubic inputs and check area, closed contours and fill membership in
every rectangular cell induced by the input boundaries, including outside cells.
They do not require a particular contour starting point or segment order.

Completed commands:

- `scripts/test-portable`: 437 passed on Erlang and 437 on JavaScript.
- `scripts/test-fast`: 1,722 passed.
- Native diagnostic above: same three failures and reduced rectangle result on
  both targets.

No production files were changed. No F# changes, commits or release were made.

## Reproduction and next work

```sh
node scripts/paperjs/extract-booleans.cjs /tmp/svg-path-paper-audit/node_modules/paper
PAPER_AUDIT_TIMEOUT_MS=30000 node scripts/paperjs/probe-booleans.mjs /tmp/svg-path-paper-audit/node_modules/paper
python3 scripts/paperjs/generate-boolean-basics.py
```

The extraction runtime installation is described in `README.md`. A final numeric
argument selects one fixture for the probe; its result is written separately.
The probe is a diagnostic command, not a CI gate: inspect its recorded statuses.
`boolean-status.json` tracks which comparisons were matched, require adapters,
returned unclassified errors, or have confirmed native failures.

Recommended first fix, after approval: make near-endpoint polynomial candidates
respect the requested geometric tolerance, recovering genuine nearby roots and
rejecting spurious ones. Then classify the other convergence errors,
non-affine overlap cases, topology failures and discontinuous reconstructions.
Any production fix requires the user's approval.
