# Tangent arc subdivision growth — 2026-10-20

Investigation after `90c6565` (offset catalogue findings). Production remains at
its existing implementation; no source changes, F# work or permanent tests.

## The eight timeouts are one native call

CC01640/44/47/48/51/52/55/56 have identical native input and offset. Their upstream
option variants are not native options. All exceed the 30-second screening limit.
A longer, instrumented CC01640 run completes successfully within the 120-second
limit: the operation reports about 90.2 seconds. It is not an infinite loop.

The result is one closed contour with area 168.40761385757781 and length
75.47232018968123, matching captured area/length/bounds. It contains 116 segments;
upstream records 12 vertices. These are different representation measures, not
an assertion that native must produce 12 segments. The reversed traversal's
CC01645 screening call matched in 668 ms. Single diagnostic timings, not controlled
benchmark medians; concurrent investigation probes ran during part of this work.

## Location of the cost

`prepare-tangent-timeout-trace.py` copies generated JS to
`/tmp/cavalier-tangent-timeout-trace`. Instrumentation logs entry/exit and returns
original values unchanged. The run uses `probe-offset-detail.mjs` with:

```sh
python3 scripts/cavalier/prepare-tangent-timeout-trace.py
AUDIT_CASE_ID=CC01640 AUDIT_TOLERANCE=0.01 AUDIT_JS_BUILD=/tmp/cavalier-tangent-timeout-trace node scripts/cavalier/probe-offset-detail.mjs
```

Saved `tangent-timeout-trace.jsonl`, `tangent-timeout-result.json`,
`tangent-timeout-run.json` and `tangent-timeout-timing-summary.json` record:

- Two arrangement builds consume about 89.5 seconds, the first about 80.5 seconds.
- 291 general curve–curve intersection calls consume about 88.9 seconds.
- 400 shared-endpoint circle checks consume about 17 ms in total.
- Final winding/parity/reconstruction trimming takes about 14 ms.

These are nested inclusive timings and must not be added together. The cost is
progressive arrangement subdivision/re-intersection, not final trimming.

## Reduction and numerical evidence

The original expensive pair consists of the two radius-sqrt(2) quarter-circle
joins around `(12,10)` and `(10,12)`. Exact binary64 SVG endpoints and radii are
saved in `tangent-timeout-original-pair.json`. No bulge adapter is needed to
reproduce the pair. `probe-tangent-timeout-pair.mjs` tests intersections and public
arrangements of just these two separate open subpaths, in both orientations.

The initial intersection call takes about 40–50 ms and supplies two cuts:

- `(10.999999974912782, 10.999999974912782)`
- `(11.000000246310869, 11.000000246310869)`

After splitting, the arrangement repeatedly encounters short, almost-reversed
arcs near `(11,11)`, but with different binary64 endpoint coordinates. Many of
these pairs cost hundreds of milliseconds in the general solver. Existing
exact-identical/reversed-arc overlap recognition does not apply to those records.
One captured costly pair is in `tangent-timeout-reduced-pair.json`.

The standalone public two-arc arrangement exceeds a 15-second bound in both
orientations, using vertex/minimum-length tolerances 1e-9. This is a reduction of
the slow behavior, not a claim of identical execution: offset's internal graph
uses 2e-9 and includes the other source and offset pieces. Direct short-pair
intersection checks finish; no individual intersection call is an infinite loop.

`tangent-timeout-circle-oracle.py` uses 80-digit Decimal arithmetic on the exact
binary64 SVG inputs, computes their circle centers, then intersects the circles.
Both roots lie inside the quarter arcs. They are near:

- `(10.999999961672676, 10.999999961672676)`
- `(11.000000038327324, 11.000000038327324)`

Thus the exact supplied SVG geometry is slightly overlapping, not exactly tangent.
The second numerical candidate is displaced about 2.08e-7 in each coordinate
from the corresponding exact intersection. Near tangency, a small curve-to-curve
residual does not imply comparably small root-location error. Do not label this
alone a violation of a promised root-coordinate error bound: no such bound has
been established from the API contract. The confirmed concern is the resulting
subdivision growth and severe orientation-dependent cost, despite matching final
aggregate geometry.

## Oracle-seeding experiment

`prepare-tangent-oracle-experiment.py` copies the current generated build to
`/tmp/cavalier-tangent-oracle-experiment`. Only for the exact original pair, it
replaces general-solver output with two high-precision-reference roots converted
back to binary64 parameters. All later calls and production source remain unchanged.
The parameter conversion uses the near-integer circle centers in ordinary
binary64 arithmetic; this is a diagnostic intervention, not an exact solver.

```sh
python3 scripts/cavalier/tangent-timeout-circle-oracle.py
python3 scripts/cavalier/prepare-tangent-oracle-experiment.py
AUDIT_CASE_ID=CC01640 AUDIT_TOLERANCE=0.01 AUDIT_JS_BUILD=/tmp/cavalier-tangent-oracle-experiment node scripts/cavalier/probe-offset-detail.mjs
```

One pair replacement is logged. The full offset finishes in about 7.8 seconds,
with 30 segments, area 168.4076138575778 and length 75.4723201896812. This supports
initial root localization as a driver of later growth, but does not establish that
improving that first call alone eliminates the whole problem. No general candidate
implementation has been written or adopted. The earlier old-sweep control also
timed out at 30 seconds; the latest reversal-join tie rule is not necessary for
this behavior.

## Suggested next repair experiment

Investigate a stable circular-arc intersection path near tangency, beyond the
existing exact-shared-endpoint shortcut. It must respect actual SVG-input circles,
clip roots to both arc intervals, preserve genuine near-tangent double roots,
and retain a fallback for unsupported/uncertain configurations. Near cancellation,
center/separation and discriminant accuracy both matter. Do not simply round this
pair to one tangent root, broaden overlap recognition to all nearby arcs, or loosen
acceptance tolerances.

First test the original pair, both traversal directions and the full offset;
then nearby tangent/disjoint/intersecting and shared-endpoint controls. Determine
whether residual split/reconstruction drift still generates unnecessary cuts.
This is a repair direction supported by an oracle experiment, not a ready fix.

## Validation limits

All new execution is JavaScript diagnostic work. No Erlang reproduction, full-suite
run or figures in this step. Existing source is untouched. New findings remain
uncommitted; the broader Cavalier audit is still open.
