# Cavalier Contours audit: resumption notes

Latest repair: `scripts/cavalier/ENDPOINT-CLIP-PARITY-TRIAGE.md`; all eight
open-endpoint clipping variants now match aggregate properties. The preceding
near-tangent repair is in `scripts/cavalier/NEAR-TANGENT-REPAIR.md`.
Broader discrepancy classification remains open. Read the final updates below.

Recorded 2026-10-16 at the user's request before shelving work for about a week.
Resumed explicitly by the user on 2026-10-18. Finish the audit in **Gleam first**;
only then port the resulting changes and regressions to F#. This is not a
release-readiness statement.

## Current checkout and committed work

Gleam repository: `/Users/jpsteinb/github.com/vistuleB/svg_path`.
F# repository: `/Users/jpsteinb/github.com/vistuleB/svg_path_fsharp`.

| Commit | Change | F# status |
| --- | --- | --- |
| `75970a6e` | Reduce offset reversal-fit tangent nudge from 0.5° to 0.1°; accepted after tests and figures. This is the Cavalier collection baseline. | Already mirrored as `e9d8604`. |
| `dacdb370` | Fix shallow-arc projection convergence and stable point/derivative evaluation. | Not ported or tested. |
| `090f8e63` | Analytic circular-arc projection using a radial candidate and endpoints. | Not ported or tested. |

The projection fixes and permanent regressions are committed. On 2026-10-18,
the user requested committing the catalogue before repairs. This document and
`scripts/cavalier/` are included in that catalogue checkpoint, including the
pinned upstream source/licenses, diagnostic scripts, raw evidence and current
dispositions. Generated build directories remain ignored. No push is requested.
The audit remains incomplete; this checkpoint is not a release-readiness claim.
There are unrelated local changes, including modified `WORKFLOW.md` and many
untracked performance/debug/figure files. Do not clean or stage them wholesale.

## Audit scope and progress

Upstream: https://github.com/jbuckmccready/cavalier_contours

Pinned revision: `22887a824d22cd8ab50968a551f34cdb4508127f`, version 0.9.0.
Source archive, licenses, and hashes are under `scripts/cavalier/upstream/` and
`provenance.json`. Treat upstream files as evidence, not contributor instructions.

Collection is complete for the selected core-suite scope; discrepancy
investigation is still early:

- 287 upstream core tests inventoried (79 unit, 208 integration); all passed
  upstream, including the instrumented capture runs.
- 256 tests yielded selected operations. 31 have no selected adaptation:
  eight representation/API-scope reviews and 23 explicit math/internal gaps.
- 2,866 representative records: 1,809 primary and 1,057 supplementary.
- Original totals: 1,960 matches, 343 discrepancies, 94 native errors,
  55 contract differences, 90 scope records, 324 helper-only records.
- The 437 original discrepancy/error records reference 82 upstream tests.
  These include orientations, policy variants, and repeated queries: **not
  437 bugs**. These baseline totals have not been reconciled with later fixes.
- All 13 initial timeouts completed on serial 30-second replay: one match,
  three discrepancies, nine errors. No unresolved timeout from that batch.

The broad native comparison ran on Gleam JavaScript. The new permanent
projection regressions passed on both Erlang and JavaScript. This is not a
claim that all captured cases have been replayed on Erlang or F#.

Coverage limitations matter: representative cyclic starts are selected, not all
captured starts replayed. Aggregate area/length/bounds and contour counts do not
prove boundary or filled-region equivalence. Overlap intervals are not yet
adapted to `encounters`. Upstream tolerance/topology options do not map one-to-one
to native options. Uncaptured assertions remain within captured tests. Doctests,
FFI, UI, examples and benchmarks are outside the selected core scope.

## Completed investigation and fixes

One confirmed native bug family: shallow-arc point projection could exhaust its
iteration budget even after reaching adjacent floating-point parameters.
Reduced case: `M 0 0 A 10000000 10000000 0 0 1 10 0`, query `(3,1)`.
Increasing the budget to 1,000 did not help. Reconstructing very short bracket
arcs and evaluating through a distant center caused cancellation.

`dacdb370` keeps bracket certification on the original ellipse using maximum
speed times parameter width, evaluates local angular increments relative to an
original endpoint, and detects bracket stagnation. Caller tolerance is unchanged;
there is no line approximation. This fixes 35 supplementary failing comparisons
(five point projections and 30 composed threshold queries).

`090f8e63` uses an analytic radial candidate plus endpoints for exactly equal
corrected radii. Ellipses retain the general solver. Positive sampling and
iteration budgets do not affect the circular path, but options are validated.
Both sweep directions, major/minor arcs, radius correction, center ties and
shallow circles are tested. No public types/options were added.

Permanent tests: `test/svg_path_cavalier_projection_test.gleam`, selected in
`test_portable/modules.txt`. Public behavior notes: `src/svg_path/distance.gleam`.
Implementation: `src/svg_path.gleam`.

Latest completed validation (circle addition):

- `scripts/test-all`: **2,049 main + 31 slow tests**, no failures.
- `scripts/test-portable all all`: **795 tests on each target**, no failures.
- Formatting checks and `git diff --check` passed.
- Supplementary replay: all 35 repaired cases remain matches.
- Published Gallery/README figures were not regenerated for these projection
  changes. F# has neither change and has not run their regression tests.

Explained differences: negative length rejection (CX00982), upstream endpoint
snapping (CX00167), tied circle-center witnesses (CX00755/CX00804/CX00832), and
endpoint ties (CX00762/CX00797). CX00749 is a strict-zero threshold comparison
with a native residual of `4.44e-16`, within tolerance. These are not new distance
bugs. See the detailed notes for exact evidence.

## Where the evidence is

All paths below are relative to `scripts/cavalier/`:

| Files | Purpose |
| --- | --- |
| `SIMPLE-TRIAGE.md` | Detailed first investigation, independent analytic answer, both fixes and validation. Read the later sections: the opening describes the original baseline. |
| `INDEX.md`, `TEST-COVERAGE.md`, `test-coverage.json` | File/test coverage ledger and gaps. |
| `REVIEW.md` | Comparison contracts, omitted assertions, adapter limitations. |
| `DISCREPANCIES.md`, `discrepancy-queue.json` | Original grouped discrepancy queue and case IDs. |
| `FINDINGS.md` | Initial offset-collapse observations. |
| `captured-cases.json`, `extra-cases.json` | Inputs and captured upstream expectations. |
| `captured-results.jsonl`, `extra-results.jsonl`, `timeout-results.jsonl` | Preserved baseline comparisons and timeout replay. |
| `extra-results-distance-trial.jsonl` | Supplementary replay after general projection fix. |
| `extra-results-circle-trial.jsonl` | Supplementary replay after analytic circle addition. |
| `circle-projection-test-all.log`, `circle-projection-portable.log` | Latest full/portable validation logs. |
| `projection-trial-*.log`, `shallow-arc-*.json`, `distance-bracket-trace.json`, `probe/` | Earlier validation, independent oracle and reduced diagnostic reproductions. |
| `prepare-capture.py`, `prepare-extra-capture.py`, `collect-capture.py`, `collect-extra.py` | Reproducible upstream capture/selection. |
| `compare-captured.mjs`, `compare-offset.mjs`, `report.py`, `validate-records.py` | Native comparisons, baseline reporting and record checks. |
| `provenance.json`, `native-run-provenance.json`, compressed capture logs | Source/run provenance and original captured variants. |

**Bookkeeping debt:** `README.md`, `REVIEW.md`, `FINDINGS.md`, the opening of
`SIMPLE-TRIAGE.md`, and `triage-dispositions.json` contain baseline-era wording
such as “no fix implemented.” Later sections of `SIMPLE-TRIAGE.md` and this handoff
supersede it. Reconcile the summaries/dispositions on resumption, preserving raw
baseline records rather than overwriting them or presenting old totals as current.

## Recommended resumption order

1. Read this file, `WORKFLOW.md`, and `DEFERRED-API.md`; inspect Git status.
2. Reconcile the stale overview/disposition records with the two committed fixes.
3. Investigate the six near-semicircle center/bounds flags (representatives
   CX00420/CX00421). Determine whether bulge-to-SVG conversion conditioning,
   upstream expectations, or native geometry is responsible.
4. Review elementary tangent/intersection cases (e.g. CC00013, CC00020,
   CC00057, CC00070/71, CC00073, CC00082), distinguishing tolerance/domain
   policy from an actual failure under our contract.
5. Continue through Boolean arrangement errors, offset construction errors,
   contour/property differences, and beyond-collapse behavior. Initial collapse
   cases CC001–CC003 are in `FINDINGS.md`; these short IDs belong to the initial
   offset batch, distinct from the broad CC000xx inventory.
6. Disposition the remaining coverage gaps explicitly. Do not equate upstream
   test execution, aggregate property matches, or a completed ledger with parity.
7. Once the Gleam audit is complete, port accepted changes/regressions to F#,
   run its validation, then consider release preparation.

No additional confirmed native bug is established merely by this queue. The
six center/bounds flags are the recommended next investigation, not a promised fix.
Commit only on explicit user authorization.

For a fresh supplementary replay after changing code:

```sh
(cd test_portable && gleam build --target javascript)
CAVALIER_CASES=extra-cases.json CAVALIER_RESULTS=extra-results-NEW-RUN.jsonl node scripts/cavalier/compare-captured.mjs
```

Use a new output filename: the runner resumes by case ID and would otherwise
silently reuse old results. For primary cases set `CAVALIER_CASES=captured-cases.json`
and another fresh output. Worker count/timeouts are controlled by
`CAVALIER_WORKERS` and `CAVALIER_TIMEOUT_MS`. Do not run portable tests concurrently
with `scripts/test-slow` (which temporarily moves `test/`).

The isolated Rust toolchain was installed under `/tmp/cavalier-audit-rustup`
with Cargo home `/tmp/cavalier-audit-cargo` and target directory
`/tmp/cavalier-audit-target` (Rust 1.95.0). Capture work was under
`/tmp/cavalier-audit-capture`. Temporary directories may disappear during the
pause; preserved source, logs and scripts are in the audit directory.

## Deferred public error variant: keep for 4.0.0

This is a separate, earlier change, not part of the Cavalier projection fixes.
Read [DEFERRED-API.md](DEFERRED-API.md) and its F# counterpart before release work.

API-001 adds public CSG error `RefinedBoundaryNotClosed(path_index, vertex, net_flow)`
(F# labels `pathIndex`, `vertex`, `netFlow`). Adding a union case can break
exhaustive matches, so it must not ship in a 3.x patch.

Preserved on local branch **`codex/v4-api` in each repository**:

- Gleam focused restoration commit: `5d0ca55b4f1bf7859ed25447fad5b17df83492f1`.
- F# focused restoration commit: `cd5b4a7d04d79d2d28e09ff84f0fa9d9d1079ed0`.
- Original implementation history: Gleam `bf59110d`, F# `c7a6e52`.
- Compatible main-branch adjustments: Gleam `cb22d9a`, F# `f795014`.

The 3.x code retains the boundary guard and private diagnostic, mapping failures
to existing public `ArrangementGraphError(ConstructionFailed)` / F#
`CsgArrangementError Arrangement.ConstructionFailed`. Do not remove the guard.

When deliberately adopting this in 4.0.0, cherry-pick/reapply the focused commits
onto current main and resolve drift; **do not merge the old branch wholesale**.
Update migration docs, regression assertions and both deferral registers, and
run both release suites. These local shelf branches are not automatically pushed.

## Held release reminder

The earlier 3.1.4 release was prepared and held unpublished per the conversation.
Its tags remain separate from subsequent audit work:

- Gleam `v3.1.4`: `e8a043fdaa3b0eba90866151fae65ec8c89f39e1`.
- F# `v3.1.4`: `81b8d30ff2db4e398ceb9faabd6354b5a17049d3`.

Do not move these tags to include new audit changes. Publication state has not
been independently rechecked for this handoff. The held release and the deferred
4.0.0 error-variant branch are two different things.


## Resumption update — 2026-10-18

Read `scripts/cavalier/RESUMED-TRIAGE.md` first for new findings. The six
near-semicircle flags combine adapter information loss with measured native
center cancellation (1.4e-6–3.3e-6 forward error against exact SVG inputs).
No fix applied. An 80-digit oracle and Erlang/JavaScript probe evidence are saved.
Fifteen of 18 elementary intersection flags have documented non-bug dispositions.
CC01751–CC01753 remain open: near-coincident arc endpoints return no candidates.
Investigating that endpoint search is the next recommended step. Overview files
now carry current-status notices and the disposition JSON includes the prior
fixes; raw baseline reports remain historical. No production changes, commits,
full-suite rerun or F# work in this resumption batch.


## Second resumption batch — 2026-10-18

Latest detailed record: `scripts/cavalier/ENDPOINT-BOOLEAN-TRIAGE.md`.
The three endpoint misses are traced to an internal tolerance of 8.016e-13 used
instead of caller 1e-9 for arc endpoint matching. All 35 flagged Boolean `And`
comparisons have output outside at least one input; independent capsule checks
cover 14 records and 42 inset points are Inside the result but Outside an input.
This is a confirmed geometry failure family; root cause still unestablished.
Two simple XOR representatives instead have equivalent Nonzero regions with
different contour decompositions. Scripts, JSON evidence and dispositions saved.
Next: remaining Boolean difference/XOR discrepancies and arrangement errors,
then offset cases and coverage gaps. Continue classification before repairs as
agreed with the user. No production changes, commits or F# work in this batch.


## Boolean contract correction and wider replay — 2026-10-18

The earlier label “confirmed Boolean geometry failure” was too strong. The CSG
contract explicitly bounds endpoint adjustment, not interior arc displacement.
All 165 successful results among the 181 originally flagged Boolean records
match stored arrangement edges with non-endpoint fields unchanged, and endpoint
movement <=4.916e-7 (default tolerance 1e-6). The previously recorded outside-input
witnesses remain real; they demonstrate the documented reconstruction limitation,
not by themselves a contract violation. Consider geometry-preserving arc output
as a future improvement/policy decision.

All 146 remaining Difference/XOR flags plus original Boolean errors were replayed
with boundary-neighborhood truth-table sampling (see detailed counts in
BOOLEAN-CONTRACT-TRIAGE.md). Four baseline errors now succeed. The 16 remaining
errors are the documented boundary-closure guard rejecting nonzero operand flows.
Lower minimum length instead causes an internal cyclic-order-circle-intersection
error. That construction behavior and stronger equivalence checks for no-witness
cases remain open. No fixes or commits. F# deferred. Next: offset discrepancies
and remaining construction/equivalence questions, continuing classification.


## Cyclic-order investigation — 2026-10-18

Read `scripts/cavalier/CYCLIC-ORDER-TRIAGE.md`. The smaller-minimum-length
failure is a confirmed native circle-sampling tolerance mismatch: the scalar
crossing helper accepts t=0 within residual tolerance, and cyclic sampling then
rejects t=0. A minimal pair of perpendicular lines (lengths 1 and 3e-6; vertex
tolerance 1e-6; minimum length 1e-8) fails on both targets; length 3.1e-6 succeeds.
Copied-build tracing confirms the same cause in CC01059. Candidate desired
regressions live under `scripts/cavalier/regressions/`, not the default suite.
No production repair or commit. Continue remaining catalogue classification;
when repairs are authorized, keep this fix local to circle sampling and validate
centered/offset endpoints, line/arc edges, scales and original geometry.

### Authorized cyclic-order repair experiment

The local residual-tolerance cap is implemented in Gleam. Four permanent tests
cover centered and offset endpoints, lines/arcs, reversed traversal and scales.
All 16 original affected arrangements now build with minimum length 1e-8 on JS;
see `scripts/cavalier/cyclic-repaired-original.json` and `CYCLIC-ORDER-TRIAGE.md`.
Default CSG boundary-guard dispositions remain separate. F# and commit deferred.

## Endpoint tolerance follow-up after cyclic-order repair

Cyclic-order repair committed as `3e8aa8c`. Next investigation reduces
CC01751–CC01753 to two unit-radius quarter-circles with a sub-tolerance endpoint
gap, reproduced on Erlang and JS. An isolated copied-JS-build experiment using
caller tolerance for endpoint seeds recovers the reduced and original cases;
production source remains unchanged. See
`scripts/cavalier/ENDPOINT-REPAIR-EXPERIMENT.md` for the candidate repair, controls,
raw evidence, and remaining validation requirements.

### Endpoint recommendation revised after broader testing

The blanket endpoint-tolerance change conflicts with the existing FL006 regression:
it adds three tolerance-valid near-endpoint candidates alongside the true crossing.
The API does not explicitly promise all within-tolerance endpoint pairs are found.
The earlier bug classification was too strong; record an approximate-endpoint
policy/robustness question rather than adopting this as an unconditional repair.
See the broader-investigation section of ENDPOINT-REPAIR-EXPERIMENT.md. Production
source is unchanged; the tested candidate is preserved as an unapplied patch.

### Endpoint semantics resolved — 2026-10-19

User decision: tolerance is a necessary acceptance bound, not a sufficient
proximity rule. CC01751–CC01753 missing approximate endpoint matches are not
confirmed bugs; the blanket endpoint widening is rejected. Gleam API docs and
README clarify this. The reduced iteration error remains a separate numerical
robustness concern. Carry the documentation clarification into the deferred F#
port; no solver changes or new commits in this documentation update.

### Tolerance implementation review — 2026-10-19

`TOLERANCE-SEMANTICS-REVIEW.md` records a concrete representation discrepancy:
two straight edges separated by a sub-tolerance endpoint gap return a candidate
as Lines but empty as straight quadratics. Reproduced Erlang/JS. Caller tolerance
also participates in constant-point matching, overlap recognition and result
grouping, so it is not used solely for final certification internally. The
necessary-but-not-sufficient public bound remains coherent; no strict exact-root
or representation-invariance guarantee is established. A shared numerical
endpoint-recognition policy is a possible future internal improvement, requiring
FL006 and exact-endpoint regressions. No production changes or commit.

### Authorized stricter line-query experiment — 2026-10-19

See `STRICT-LINE-TOLERANCE-EXPERIMENT.md`. The non-collinear line solver now shares
curve search's numerical recognition threshold for endpoint admission, ray
residuals and finite-line parameter bounds; public tolerance remains the final
acceptance bound. The representation probe now agrees on all 27 line/Bezier pair
cases. Constants, overlap/collinear handling and result grouping are unchanged.
A permanent portable regression covers reversed line/quadratic representations.
F# remains deferred. Validation results are recorded in the experiment report.

The final stricter-line implementation passed `scripts/test-release`: 2,054
ordinary + 31 slow, and 800 portable tests on each of Erlang and JavaScript.
Retained in the working tree, uncommitted. Figures not regenerated; F# deferred.
Raw log: `scripts/cavalier/strict-line-test-release.log`.

## Offset investigation after `e936c7b` — 2026-10-19

See `scripts/cavalier/OFFSET-COLLAPSE-AND-NORMALIZATION-TRIAGE.md`.
Circle beyond-collapse behavior follows an explicitly tested normal-extrusion
construction; default trimming is not generally filled-region erosion. High-level
collapse behavior remains a policy question, not a newly confirmed bug.

A separate confirmed bug explains short-arc failures CC01160/CC01292: degeneracy
cleanup drops the connection between distinct endpoints when shorter than its
tolerance, violating documented endpoint preservation and opening a gap inside
offset source normalization. Reduced to one radius-1 arc of chord length 3e-5,
reproduced Erlang/JS, with the public offset failure reproduced on a three-segment
continuous path. Candidate next fix: omit only exact zero-length connections
between retained traversal points. Not implemented; F# deferred.

### Short-arc cleanup repair — 2026-10-19

Corrected the earlier call-path diagnosis: `point_traversal_lines` already gets
zero tolerance. The loss is in `degenerate_line_list`, whose no-axis branch
returned an empty list even for distinct endpoints. It now retains existing
linearized connections, omitting only exact zero-length lines. Three permanent
portable regressions pass targeted Erlang checks. Original CC01160/CC01189/
CC01292/CC01296 now all complete; only CC01296 also matches baseline aggregate
properties. Other output discrepancies remain open. No commit or F# port yet.

Short-arc repair passed `scripts/test-release`: 2,057 ordinary + 31 slow, plus
803 portable tests each on Erlang and JavaScript. See
`scripts/cavalier/short-arc-cleanup-test-release.log`. Uncommitted; F# deferred.

Committed the short-arc cleanup repair and its evidence as `abe15554`.

### Next issue: near-tangent offset — 2026-10-19

CC01267/CC01271 still fail after that repair. See
`scripts/cavalier/NEAR-TANGENT-OFFSET-TRIAGE.md`. CC01267 is now traced on JS and
reproduced on Erlang: overlap checking extracts a subinterval of a valid generated
arc whose endpoints round to the same point, then attempts a second split and
gets `DegenerateArc`. Untrimmed construction succeeds; the arrangement path
fails even with `NoTrimming`. CC01271 was replayed but not independently traced.
No production repair yet; local interval-distance handling is the next candidate
to investigate. New investigation evidence is uncommitted. F# remains deferred.

### Arc-interval witness experiment — 2026-10-19

An uncommitted local overlap repair now uses actual original-interval points as
positive distance witnesses when an extracted arc degenerates numerically.
It preserves the error when witnesses are inconclusive and validates the source
arc. Three regressions added; ordinary suite: 2,060 passed. The original offsets
still fail. CC01267 advances to ambiguous vertex matching: an endpoint is within
2e-9 of two distinct vertices, each more than 2e-9 from the other. Do not describe
this as a completed offset repair. See the candidate section of
`scripts/cavalier/NEAR-TANGENT-OFFSET-TRIAGE.md` and its new replay/trace evidence.

Portable validation completed: 806 Erlang + 806 JavaScript tests passed via
`scripts/test-portable all all`; root slow/release sequence not rerun.
CC01271 independently traced to the same ambiguous-vertex check (two matches
inside 2e-9). Both original offsets remain unresolved. No commit this turn.

### Vertex identity investigation — 2026-10-19

Both CC01267 and CC01271 contain an exact endpoint sample assigned to two
vertices: greedy minimum-radius attachment can reassign a repeated sample to a
newer cluster. Reduced to five straight lines; reproduced on Erlang and JS.
A copied-JS experiment preserving existing exact sample membership fixes that
reduced arrangement. It is not yet a demonstrated fix for the original offsets.
See `scripts/cavalier/VERTEX-MEMBERSHIP-TRIAGE.md` and provenance/reduction logs.
No additional production changes or commits in this investigation.

Exact-membership copied-build experiment: five-line arrangement now succeeds;
original CC01267 continues subdividing and exceeded a separate 60-second budget.
This confirms a local repair direction, not completion of the offset case.

### Near-tangent repair implementation — 2026-10-19

See `scripts/cavalier/NEAR-TANGENT-REPAIR.md`. Exact repeated endpoint ownership
is now preserved. Cut tracing identified repeated approximate interior hits
between circular arcs that mathematically only share an endpoint on their sweeps.
A guarded shared-endpoint circular solver now avoids that repeated subdivision.
Both CC01267 and CC01271 complete and match the recorded aggregate properties
with default options (actual Gleam JS replay). Earlier unresolved-outcome entries
above are historical. Full final validation is recorded in the repair report;
changes remain uncommitted, F# deferred.

Final `scripts/test-release` passed: 2,067 ordinary + 31 slow + 813 portable on
each target. Log `scripts/cavalier/shared-circle-final-test-release.log`.
Both targeted originals match recorded aggregate properties. No figures or F#
port in this turn; no commit requested or made.

### Near-tangent commit and next endpoint investigation — 2026-10-19

Committed the tested near-tangent repairs and evidence as `f2ccd80`.
Next: `scripts/cavalier/ENDPOINT-CLIP-PARITY-TRIAGE.md`. All eight original
non-tangent open-endpoint offset variants still fail on current JS. CC01558's
arrangement and winding pruning produce the expected complete square, but a
stale odd-parity request at its original open endpoint rejects that cycle.
Repair direction: derive terminal roles from surviving source traversal rather
than attachment alone. No additional production change; F# deferred.

### Endpoint-cycle candidate tested — 2026-10-19

The candidate exempts original open endpoints from preferred odd parity only
when their retained component is an intact unit-capacity cycle. General parity
solver and reconstruction guards are unchanged. All eight CC01558/CC01562–68
variants now complete and match aggregate properties (native output explicitly
closed, upstream open with coincident endpoints). Two permanent portable tests
cover forward/reverse cycle geometry and preserved open terminals.
Validation: `gleam test` 2,069; `scripts/test-portable all all` 815 each target;
`scripts/test-slow` 31, all passing. Details and raw logs in
`scripts/cavalier/ENDPOINT-CLIP-PARITY-TRIAGE.md`. Retained uncommitted; figures and
F# not updated.

### Remaining-work inventory for endpoint-cycle commit

See `scripts/cavalier/REMAINING-INVESTIGATIONS.md`: seven open work groups,
not seven confirmed bugs. Fresh replay of the nine outstanding tangent-arc/
shape-offset construction-error records now gives four matches and five
aggregate discrepancies, with no construction errors. Root-cause attribution
across the recent repairs is not isolated. These differences still require
classification; the entire audit remains incomplete.

### Tangent-arc contour investigation — 2026-10-19

See `scripts/cavalier/TANGENT-ARC-CONTOUR-TRIAGE.md`. The four remaining
CC01645-family contour mismatches are Preserve/Separate policy differences.
Independent analytic boundary checking accounts for all 12 ideal pieces with
calculated deviation <6.7e-7. The other four cases already match. No production
changes. A separate efficiency concern remains: roughly 15 seconds for this
8-edge source and 37 output segments, including 25 short seam pieces. This is
not yet a measured historical regression; the remaining-work register now
tracks that concern instead of the explained contour-policy discrepancy.

### Short-arc overlap performance investigation

Committed preceding contour-policy findings as `544a358`. Profiling isolates
~16.3s in general curve intersections. A valid radius-1 arc of chord 1e-8 against
itself/reverse incorrectly returns point hits: conflicting endpoint proposals
erase the already-validated full overlap. Reproduced Erlang/JS. Copied-build
exact-arc full-map preference reduces the original offset to ~0.61s and 18
segments (one self-touching contour); independent boundary check still passes.
See `scripts/cavalier/SHORT-ARC-OVERLAP-PERFORMANCE.md`. No production repair or
full regression testing yet. New investigation evidence remains uncommitted.

### Exact-arc overlap candidate tested

Implemented narrow full-map preference for exactly identical/reversed arcs,
after existing validation. Four portable regression tests added. Canonical
`scripts/test-release` passed: 2,073 ordinary + 31 slow + 819 on each portable
target. Actual Gleam JS original replay ~0.63s, 18 segments, boundary check passes.
Preserve variants now match; Separate differs only in grouping. Six remaining
investigation groups are listed in `scripts/cavalier/REMAINING-INVESTIGATIONS.md`.
No commit, F# port or figures in this turn. See SHORT-ARC-OVERLAP-PERFORMANCE.md
for logs, caveats and exact replay filenames.

### Shape case3 investigation

Committed exact-arc overlap repair and evidence as `0d3449f`. CC01807 is now
explained: default fitting.tolerance also normalizes line-degenerate source
windows. Tightening only that normalization to 1e-4 reproduces the main upstream
contours; the extra zero-area out-and-back contour is consistent with existing
retrace preservation tests. No new geometry bug established. Documentation
clarification suggested. See `scripts/cavalier/SHAPE-CASE3-TRIAGE.md`. Five open
investigation groups remain. No production changes; new findings uncommitted.

### Remaining offset detail investigation

Committed CC01807 findings as `d3b2eca`. CC01160 and CC01292 now have targeted
replays explaining their property discrepancies through existing detail
controls. CC01189 defaults normalize to a retraced line; at tighter tolerance,
it fails dual placement with five unresolved walks. Captured graph has 26
vertices/33 edges, with several chords below sweep tolerance; causal diagnosis
still open. See `scripts/cavalier/REMAINING-OFFSET-DETAIL-TRIAGE.md`. No production
changes. New findings uncommitted; five broad investigation groups remain.

### CC01189 dual-placement diagnosis

Direct graph replay identifies 830 hit-separation rejections while placing a
narrow arc/line face. Reduced to a five-edge connected triangle/lens which dual
accepts; adding one distant line makes dual fail. Reproduced Erlang and JS.
Disconnected placement unnecessarily requires a certified sweep through every
local face, unlike the existing connected-graph shortcut. Recommended direction:
certify component placement relative to other components, then combine known
local faces. No production implementation yet. See
`scripts/cavalier/DUAL-NARROW-FACE-TRIAGE.md`. Findings remain uncommitted.

### CC01189 component-placement repair validated

Implemented component placement relative to other components, retaining local
face topology, existing sweep uncertainty, and two agreeing accepted witnesses.
Three portable regressions cover narrow faces with exterior/interior bridges,
enclosing contours, and reversed directions. Captured graph now gives ten
faces; actual CC01189 at fitting tolerance 1e-6 returns the expected empty path.
Final `scripts/test-release` passed: 2,076 ordinary + 31 slow + 822 on each
portable target. See `scripts/cavalier/DUAL-NARROW-FACE-TRIAGE.md` for logs.

CC01189 is still only partially resolved: 1e-5 fails in cyclic-order circle
intersection before dual construction. A reversed/reordered reduced 1e-4 case
also exposes a pre-existing JS cyclic-order construction limitation, recorded
separately. Default collapse/erosion semantics are unchanged. Five broad audit
groups remain; audit not complete. Changes uncommitted; F# remains deferred.

### CC01189 remaining cyclic-order failure isolated

Committed the component-placement repair and accumulated investigation records
as `e7c1581`. The 1e-5 failure is now traced to clustered endpoint geometry:
no circle about vertex 11 can intersect both outward arc 10 and cubic 14.
A 70-digit radial calculation verifies the arc's minimum distance exceeds the
cubic control-hull radius bound. Changing radius or root precision cannot fix
that stored geometry. Investigate creation/ownership of the short cubic and its
arc overlap next; do not silently change the edge geometry or tolerance policy.
See `scripts/cavalier/CYCLIC-CLUSTER-RADIUS-TRIAGE.md`. No new production changes;
these follow-up findings are uncommitted.

### CC01189 endpoint-owner inconsistency found

Source mapping traces the problematic cubic to an ordinary fitted offset source.
Both endpoints uniquely match vertex 11 during incoming comparison, but insertion
recomputes ownership by smallest enclosing circle and assigns its start to 13.
A copied-JS experiment retaining unique existing-center ownership returns the
expected empty CC01189 offset at 1e-5 and repairs all 24 direction/order/size
controls, including the prior reversed JS failure. Only two attachment choices
change in the original offset. Minimal insertion reproducer saved. Recommend
unifying owner selection with exact-sample precedence retained, then full tests.
See CYCLIC-CLUSTER-RADIUS-TRIAGE.md. Production code remains unchanged; new
investigation records are uncommitted.

### Endpoint ownership repair validated

Implemented exact-sample precedence, then admissible unique existing-center
ownership, then the previous enclosing-circle fallback. Four new portable
regressions and restored reversed-list-order controls pass. Actual CC01189
replays at 1e-5 and 1e-6 both return the expected empty offset. Canonical
`scripts/test-release` (Gleam 1.18.1) passed: 2,080 ordinary + 31 slow + 826 on
each portable target. See CYCLIC-CLUSTER-RADIUS-TRIAGE.md and
`owner-repair-test-release.log`. The numerical failures are repaired; default
normalization/collapse policy is unchanged. No new public API or edge-geometry
rewriting. Changes uncommitted; F# remains deferred. Five broader investigation
groups still remain; the overall audit is not complete.

### Near-semicircle accuracy experiment

Committed the endpoint-ownership fix and preceding investigation as `b7f9257`.
The six center/bounds flags reduce to three SVG arcs with mixed adapter loss and
native cancellation. A copied-JS compensated center calculation reduces original
center errors from 1.4e-6/3.2e-6 to final-coordinate rounding scale; a 27-case
circle/axis-aligned-ellipse scale sweep improves 24 cases and preserves three
already-exact midpoint cases. Exact-input Decimal oracle and raw results saved
in SEMICIRCLE-ACCURACY-TRIAGE.md and companion files. Recommend a compensated
near-cancellation path, followed by full tests and figure review. No production
changes, candidate Erlang run, or full suite in this investigation. Upstream
bulge-equality discrepancies remain representation differences; audit not closed.


### Near-semicircle production repair and full validation

Implemented compensated center products only near cancellation. Radius enlargement
now explicitly retains its unique midpoint center, avoiding an artificial shift
from rounding the enlarged radii. Four new portable regression tests cover 27
exact-input center cases, flags, bounds, quadrant rotations, and radius correction.
The first run exposed one existing congruency regression; explicit midpoint
handling fixed it without weakening the assertion.

Final `scripts/test-release`: 2,084 ordinary + 31 slow + 830 portable Erlang +
830 portable JavaScript, all passing. `scripts/generate-published-figures` passed,
including its ordinary suite rerun: 13 README and 33 Gallery figures generated.
All README and 30 Gallery files are byte-identical. The other three have identical
nonnumeric content and only coordinate rounding changes (dash figures <=1e-5;
second-offset arrangement <=2.622e-9). Evidence and limitations are recorded in
`scripts/cavalier/SEMICIRCLE-ACCURACY-TRIAGE.md`.

Non-quadrant rotation can still lose half-chord accuracy before the compensated
calculation; this remains recorded follow-up work. Bulge-to-SVG information loss
is also unchanged. No public API changes. F# remains deferred; audit not closed.


### Endpoint crossing roundoff follow-up

Committed near-semicircle repair as `5fe1d99`. Next investigation reproduced the
reduced endpoint-gap failure on both targets and isolated it to near-tangent
arc-line candidate admission: adding tolerance/radius to one rounds upward,
while later distance verification rejects the same candidate. A copied-JS
direct-distance comparison returns empty for both failing rows, preserving the
other 14 endpoint controls. Production is unchanged; regression/broad validation
is pending. See `scripts/cavalier/ENDPOINT-CROSSING-ROUNDOFF-TRIAGE.md`.


### Endpoint crossing roundoff repair validated

Applied the direct excess-distance admission check in the arc-line solver.
Final certification and endpoint tolerance semantics are unchanged. Added two
portable tests covering the reduced arc pair in both orders and 48 direct
arc-line controls across three scales and four quadrant orientations.

`scripts/test-release`: 2,086 ordinary + 31 slow + 832 portable Erlang + 832
portable JavaScript, all passed. `scripts/generate-published-figures`: repeat
ordinary suite passed, all 13 README and 33 Gallery figures byte-identical.
Production endpoint probe matches all 16 isolated-experiment results.
Evidence: `scripts/cavalier/ENDPOINT-CROSSING-ROUNDOFF-TRIAGE.md`.
This closes the reduced endpoint-search investigation; four broader groups
remain. F# is deferred. Production repair and validation records are ready for the fix commit.


### Square collapse investigation

After endpoint repair commit `c64cd00`, reproduced square inward-offset contours
on both targets. A copied-build winding trace shows the central loop edges
exactly match expected/measured (1,0); at distance 2 the extra square edges match
(2,0). Independent raw-walk winding explains why the center reappears after the
corner circles pass it at distance sqrt(2). This reduced case follows the current
winding trimming mechanism but differs from erosion; classified as an understood
policy limitation, not a confirmed solver bug. Documentation clarification is
recommended, not implemented. See `scripts/cavalier/SQUARE-COLLAPSE-WINDING-TRIAGE.md`.
No production change, full-suite rerun, F# change, or commit in this investigation.


### Circular rotation follow-up

Gallery addition and square findings committed as `2abb659`. Investigated the
remaining circular near-semicircle axis-rotation error: reproduced on both targets.
An 84-case JS candidate computes circles at rotation zero, preserves the returned
rotation, and adjusts the start angle. Maximum center discrepancy versus the same
zero-rotation input drops from 9.92e-6 to zero; sampled/bounds differences fall to
about 4.1e-12. Unequal-radius ellipses are outside this candidate's scope.
See `scripts/cavalier/CIRCLE-ROTATION-TRIAGE.md`. No production changes or full
suite rerun; candidate implementation and broad validation remain pending.


### Circular rotation repair validated — 2026-10-20

Implemented zero-rotation center calculation for exactly equal absolute radii,
retaining the caller's rotation and rotating the start unit direction into its
angle frame. Unequal-radius conversion is unchanged. Two portable regressions
cover flags, translation, curve points/bounds, negative radii and enlargement.

`scripts/test-release`: 2,088 ordinary + 31 slow + 834 portable Erlang + 834
portable JavaScript passed. `scripts/generate-published-figures`: repeat ordinary
suite passed; all 13 README + 34 Gallery outputs are byte-identical. The 84-case
production probe has zero center variation and ~4.1e-12 maximum sampled error
relative to rotation zero. See `scripts/cavalier/CIRCLE-ROTATION-TRIAGE.md`.
Not yet committed; F# deferred. Unequal-radius conditioning remains open.
