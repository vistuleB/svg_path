# FL006 remaining overlap suppression: investigation

Current status: the arc guard is implemented and fully tested in Gleam. See
[FL006 implementation and validation](FL006-OVERLAP-FIX.md). The earlier
experiment/status descriptions below are historical.

2026-10-15. Ranking fix committed as Gleam `0a67c0a`, F# `bbd9d46`.
The production overlap detector and arrangement code are unchanged in this
investigation. The experiment below only modifies a copied JavaScript runtime.

## Root cause

The exact short arc pair is recorded in `remaining-fl006-short-overlap.json`.
At the arrangement intersection tolerance of 5e-7, overlap detection returns:

- Left interval: 0 → 0.0000013036695274213663.
- Right interval: 0.000001303228954267232 → 0.

This is a reversed correspondence in a tolerance-sized endpoint neighborhood.
The arcs themselves travel in approximately the same direction there. Across
1,001 samples, paired separation never exceeds 1.448e-7, so proximity checks
accept it. The proximity result is consistent with the supplied tolerance;
it is not an arithmetic failure of those checks. However, it is not a
continuation along the arcs in the mapped traversal direction.

The public intersection query therefore returns `OverlappingSegments`.
`arrangement.pair_cuts_with_common_endpoint_sliver` suppresses that error for
segments sharing an endpoint vertex, returning no cuts for the entire pair.
The distinct interior crossing at parameters about (0.449122668, 0.449123626)
is consequently lost. Bypassing only the overlap precheck finds that crossing.
At tolerance 1e-7 the endpoint correspondence is rejected and the crossing is
found normally. Increasing search depth cannot affect this precheck.

This is analogous to the backwards line correspondence corrected for FL004.
The consequential problem is the loss of a distinct interior crossing. Merely
calling the small endpoint interval coincident under a distance tolerance does
not justify treating the whole pair as having no isolated intersections.

## Temporary candidate

`prepare-fl006-overlap-experiment.py` copies the generated runtime and adds an
arc/arc direction check before sampled overlap validation. It evaluates the two
tangents at the candidate interval midpoints and rejects a correspondence whose
tangent dot product, adjusted for the interval directions, is nonpositive.
It leaves overlap tolerances and arrangement policies unchanged.

The experiment intentionally covers only arc/arc pairs. A production version
should normalize the tangent vectors (as the line guard does), propagate any
evaluation errors, document the direction requirement, and test genuine partial
and reversed overlaps alongside this rejected endpoint correspondence. The raw
product used in the temporary probe is not suitable as a general overflow-safe
implementation. Do not infer a general Bézier direction rule from this test.

## Observed results

- Reduced pair: one crossing, no overlap, in all eight operand-order/traversal
  combinations. Genuine same-arc overlaps still return an overlap for both
  same and reversed traversal.
- CSG 4295 at default options: five segments instead of four; sampled boundary
  difference falls from about 3.6e-6 to 5.12e-8. Area is
  0.006167842451951122, versus reference 0.006167841542276564.
- Chained 4296: seven segments instead of six. Both chain adapter policies pass
  the existing area/membership comparisons; those comparisons do not prove
  complete boundary equivalence.
- All twelve reconciled standalone comparisons pass under both policies:
  24 comparisons and 5,980 boundary samples, maximum distance 5.12e-8.
- All 781 exported portable JavaScript test functions pass in the modified
  runtime. This is a diagnostic replay, **not** a canonical Gleam release run.
  Erlang, F#, and figures have not been tested with this overlap experiment.

Evidence: `remaining-fl006-short-overlap*.json`,
`remaining-fl006-overlap-orientations.json`,
`remaining-fl006-overlap-csg-experiment.json`,
`remaining-fl006-overlap-chains-experiment.json`,
`remaining-fl006-overlap-replay-experiment.json`, and
`remaining-fl006-overlap-tests.json`.

## Reproduction

First build the portable JavaScript runtime from the committed ranking fix.
Then run from the repository root:

```sh
node scripts/flatten/probe-fl006-short-overlap.mjs
python3 scripts/flatten/prepare-fl006-overlap-experiment.py
node /tmp/fl006-overlap-tools/probe-fl006-short-overlap.mjs
node /tmp/fl006-overlap-tools/probe-continuity-4295.mjs
node /tmp/fl006-overlap-tools/probe-continuity-chains.mjs
node /tmp/fl006-overlap-tools/probe-continuity.mjs
node scripts/flatten/probe-fl006-overlap-orientations.mjs
node scripts/flatten/test-fl006-overlap-runtime.mjs
```

Recommendation: implement the arc direction guard with focused regressions and
full production validation next. FL006 remains open until that implementation
is adopted and validated; the successful temporary experiment is not closure.
