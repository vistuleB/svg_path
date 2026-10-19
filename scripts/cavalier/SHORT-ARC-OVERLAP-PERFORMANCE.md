# Short exact arc overlap: correctness and performance — 2026-10-19

Investigation after `544a358`. No production source changes. Copied generated-JS
experiments only; candidate is not adopted or fully regression-tested.

## Profile

`node --cpu-prof --cpu-prof-dir=/tmp/cavalier-tangent-profile
--cpu-prof-name=tangent.cpuprofile scripts/cavalier/probe-tangent-arc-contours.mjs`
produced the CPU profile summarized in `tangent-cpu-summary.json`. The raw
profile is temporary, not required to reproduce the run.

`prepare-tangent-performance-trace.py` instruments a copied generated build.
`probe-tangent-performance.mjs` records inclusive timings in
`tangent-performance-trace.json` (nested totals must not be added):

- Arrangement construction: 16.46 seconds across two calls.
- General curve–curve intersection: 16.31 seconds across 69 calls.
- Final parity reduction: 0.76 milliseconds.
- Final trim reconstruction, including parity: 7.76 milliseconds.

Thus the preceding endpoint-cycle rule is not responsible for this cost.
Several slow pairs are short circular arcs against their exact reverse, taking
600–900 ms each and generating interior point candidates which drive more cuts.

## Confirmed reduced public-contract failure

Use radius 1, rotation 0, minor arc, positive sweep, endpoints (0,0) and (1e-8,0).
Call `intersections.segment(a,a)` or pair it with `segment_reverse(a)`.
Both return a finite point list instead of documented `OverlappingSegments`.
The SVG arc is valid and has positive extent: identity/reversal proves continuous
overlap without relying on a proximity tolerance.

- JS: `probe-short-reversed-arc.mjs`, `short-reversed-arc-results.json`.
  Chord lengths 1 through 1e-7 correctly reject overlap; 1e-8 and 1e-9 do not.
  The 1e-8 self/reverse calls take about 631/602 ms in this run.
- Erlang: `gleam run -m short_arc_overlap_audit_probe` in `probe/`, recorded in
  `short-arc-overlap-erlang.log`. Both 1e-7 and 1e-8 fail on this target, both
  directions. The threshold depends on floating-point evaluation.

## Mechanism

`prepare-short-arc-overlap-trace.py` observes the detector in a copied build.
For the 1e-8 self pair, a correct full [0,1] → [0,1] overlap passes sampled and
parameter correspondence checks. Endpoint projection also supplies a nearby
address 2.4802620430283604e-8 at the start, producing competing maps.
`merge_overlap_list` rejects the incompatible proposals. The detector then
returns an empty overlap list, allowing the expensive point solver to run.

`prefer_certified_full_overlap` already protects a certified full map for
monotone polynomial segments, but excludes arcs. The same structural problem
therefore remains for an arc against itself/reverse. This is not a failure to
find an initial full-overlap candidate.

## Narrow candidate and copied-build result

Extend full-map preference to exactly identical arcs or exact reversals, when a
validated full correspondence is already present. Exact field equality is a
sufficient certificate here; no sampled-nearness generalization is needed.
Keep source validation, candidate validation and general non-affine/retracing
rules. Do not apply this identity rule indiscriminately to retraced polynomial
curves with multiple parameter correspondences.

`prepare-exact-arc-overlap-experiment.py` creates the copied-build candidate and
experiment probes. Its JSON equality is a diagnostic shortcut for structural
field equality; production should use Gleam equality/patterns.

- All 12 JS self/reverse checks (six chord lengths) return OverlappingSegments.
- 1e-8 self/reverse: about 0.89 ms each.
- Full offset: 613.75 ms, compared with representative baseline 15,420.63 ms.
- Output: one closed self-touching contour, 18 segments; baseline two contours,
  37 segments. Grouping is not guaranteed by the native contract.
- Independent analytic boundary check still accounts for all 12 ideal pieces;
  calculated distance bound 6.61e-7. Six short seam pieces remain.

Results: `short-reversed-arc-experiment.json`,
`tangent-arc-contours-experiment.json`, `tangent-arc-experiment-boundary-check.json`.
These are single diagnostic runs, not controlled benchmark claims. They establish
an actionable repair direction, not release readiness. Next step: implement the
narrow certificate in Gleam, add portable self/reverse regressions (including
invalid-arc and nonidentical controls), then run the complete regression profiles.
F# remains deferred. No new commit requested for this investigation.

## Gleam candidate implementation

`prefer_certified_full_overlap` now accepts an already validated full arc map
when the arc records are exactly equal in the indicated orientation. It keeps
the previous monotone-polynomial certificate for other segment types. Source
validation, positive-span checks, sampled/affine validation, and the rejection
of unexplained non-affine candidates still precede this preference.

`svg_path_exact_arc_overlap_test.gleam` adds four tests: short circles with both
sweeps against themselves/reversals at three chord sizes, a rotated short
ellipse, invalid coincident-endpoint arcs, and distinct semicircles with shared
endpoints. The module is included in portable tests. Canonical validation is
being recorded in `exact-arc-overlap-test-release.log`; completion recorded below.

## Completed production-candidate validation

`scripts/test-release` completed successfully: 2,073 ordinary tests, 31 slow,
819 portable Erlang and 819 portable JavaScript. Raw log:
`exact-arc-overlap-test-release.log`. Formatting, `git diff --check`, and audit
record validation passed.

Actual compiled Gleam JS replay (not the copied experiment): 625.95 ms,
one contour with 18 segments (`tangent-arc-contours-repaired.json`). The
independent boundary check passes (`tangent-arc-repaired-boundary-check.json`).
All 12 diagnostic self/reverse queries reject overlap correctly
(`short-reversed-arc-repaired.json`). Timings remain single diagnostic runs.

The eight original tangent-offset variants were replayed: the four Preserve
variants now match and the four Separate variants differ in contour count.
This reverses the previous grouping outcome, not geometric correctness: native
API does not select either Cavalier touching-loop policy. The recorded analytic
boundary comparison remains applicable. CC01807 still differs and is a separate
investigation. Results: `remaining-construction-after-exact-arc.jsonl`.

The repair and regressions are retained uncommitted. No figures regenerated or
F# changes. The short exact-arc overlap defect is resolved by this tested
candidate; the remaining-work register excludes it from pending investigations.
