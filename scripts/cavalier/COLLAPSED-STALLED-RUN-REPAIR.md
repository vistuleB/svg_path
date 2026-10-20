# Preserve collapsed stalled runs through joining — 2026-10-20

Supersedes the conclusion in `EXACT-COLLAPSE-ERROR-TRIAGE.md`: an existing
isolated-arc rejection test was insufficient evidence that rejecting embedded
collapsed arcs was correct. The stalled-run architecture already recognizes
these arcs; dropping the run before joining loses the information needed to
construct its two corner joins.

## Change

A collapsed stalled run proposes a zero-length Line, retaining its full source
correspondence and the first/last source tangent directions. It does not ask
the point segment for a tangent. Adjacent joins are constructed normally using
that information. After joins have been assembled, redundant point lines are
removed from both geometry and its matching preimage records. If the entire
assembled walk is point geometry, one point line survives. Subsequent trimming
continues to apply its own existing policies.

The isolated circular-arc regression now expects a point line instead of
`DegenerateTangent`. New regressions cover an inward-collapsed quarter circle
between tangent lines and an inward-collapsed semicircle between corner-forming
lines, in both orientations. The latter retains both round joins; the former
contains just the two connected lines. Both raw and default-trimmed calls are
checked. No public type or option was added. F# remains deferred.

## Validation

Canonical release verification and figure comparison completed below. An initial direct
`gleam test` attempt aborted on a missing test module after 1146 passing tests;
this was not a successful full test run. The canonical runner cleans/rebuilds
each profile. The original case6 probe now succeeds in both orientations on
Erlang. Final counts and diagnostic replay results will be recorded below.

Completed `PATH=/Users/jpsteinb/.nvm/versions/node/v24.10.0/bin:$PATH scripts/test-release`:
2,100 ordinary tests, 31 slow tests, and 846 portable tests on each of Erlang
and JavaScript; all pass. See `collapsed-stalled-run-release.log`.

`CAVALIER_CASES=collapsed-stalled-run-cases.json CAVALIER_RESULTS=collapsed-stalled-run-results.jsonl CAVALIER_WORKERS=1 CAVALIER_TIMEOUT_MS=30000 node scripts/cavalier/compare-captured.mjs`
replayed all six formerly failing inputs: six property matches. The four closed
collapsed-circle inputs trim to empty; both case6 traversals agree with upstream
length and bounds within floating-point roundoff. This is property agreement,
not a complete boundary-equivalence proof.

`PATH=/Users/jpsteinb/.nvm/versions/node/v24.10.0/bin:$PATH scripts/generate-published-figures`
completed: all 34 Gallery and 13 README figures regenerated. All Gallery and
12 README figures are byte-identical to the baseline. The remaining README
`band_cusp_trimming.svg` has only the previously recorded three panel-centering
spellings (`-2.0` / `-1.9999999999999998`), with all path data unchanged. A full
text comparison after normalizing just that spelling is identical. No new
figure geometry changes. See `collapsed-stalled-run-figures.log` and
`collapsed-stalled-run-figure-comparison.json`. Format, diff whitespace and
audit-record validation pass. Changes remain uncommitted.
