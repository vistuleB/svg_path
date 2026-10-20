# Offset follow-up after reversal-join repair — 2026-10-20

Native baseline `1e97935`. Investigation only: no production edits, permanent
suite changes, F# port or new commit. Original captured results are preserved.

## Replay scope

`offset-post-reversal-cases.json` selects all 192 original discrepancy/error/
timeout records of kind `offset` or `shape_offset` in `captured-results.jsonl`.
This includes already explained cases and upstream option variants. It does not
include previously passing inputs and cannot establish absence of regressions.

Commands, from the repository root except the first:

```sh
(cd test_portable && gleam build --target javascript)
CAVALIER_CASES=offset-post-reversal-cases.json CAVALIER_RESULTS=offset-post-reversal-results.jsonl CAVALIER_WORKERS=1 CAVALIER_TIMEOUT_MS=30000 node scripts/cavalier/compare-captured.mjs
python3 scripts/cavalier/summarize-offset-post-reversal.py
```

Use a fresh results filename for a fresh run: the runner resumes existing IDs.
The completed run has 29 property matches, 149 discrepancies, six errors and
eight timeouts across 45 upstream test families. All six errors are
`DegenerateTangent` (four collapsed-circle variants and two `case6` variants).
The generated replay table and summary retain each outcome. A property match
is not complete boundary equivalence; no general attribution to the latest
repair is made. CC01192/CC01196 are separately established reversal-join fixes.

## Detail-control discrepancies

Targeted replays use `probe-offset-detail.mjs`, with `AUDIT_CASE_ID` and optionally
`AUDIT_TOLERANCE`. Files are `offset-post-reversal-<ID>-detail.json`.

| Input | Default result | Tighter result | Captured upstream |
| --- | --- | --- | --- |
| CC01131 | area 14.534002238872327; length 20.150280832028464 | tolerance 1e-4: area 14.52921913221516; length 20.149586160070236 | area 14.529219132215086; length 20.149586160070246 |
| CC01167 | length 1.7156330664354031 | tolerance 1e-3: length 1.7717624752984837 | length 1.7717624752984793 |
| CC01179 | length 5529.501028726129 | tolerance 1e-3: length 5639.266054486938 | length 5639.266054690314 |
| CC01248 | area 195.41031137806036; length 61.34607173115212 | tolerance 1e-3: area 195.4013387486115; length 61.34637855077659 | area 195.40133876887995; length 61.34637855753273 |

Bounds also agree within the existing 1e-4 comparison threshold at the tighter
settings. CC01167 normalizes to three segments by default versus four when
tightened; CC01179 to one versus three. The latter's large change in offset
extent is not a claim that fitting tolerance bounds final offset displacement:
source normalization changes before extrusion. No such global error guarantee
is inferred. No new defect is established by these output comparisons.

CC01151 has identical native input to CC01131. CC01183 also has that input but
upstream requests Separate touching loops. The tighter native one-contour result
matches the sum of upstream area/length and combined bounds; grouping remains a
separate policy difference. CC01252 repeats CC01248's native call; CC01253/54
reverse it. A separate tighter CC01253 replay matches signed area, length and
bounds; CC01254 has identical native input to CC01253.

## CC01287 (`open_pline4`): final trimming removes all chains

At fitting tolerances 0.01, 0.001 and 0.0001 the default result is empty.
Disabling final in-band trimming produces a 13-segment raw walk of length
1332.0786195245466. Offside-only gives that same result: offside trimming applies
to closed sources. Enabling in-band trimming without offside still returns empty.
Cavalier instead returns an open chain of length 174.88800664020044.

`prepare-open-pline4-trace.py` instruments only a copied generated JS build under
`/tmp/cavalier-open-pline4-trace`. Wrappers return original results unchanged.
Run the generated diagnostic with:

```sh
python3 scripts/cavalier/prepare-open-pline4-trace.py
AUDIT_CASE_ID=CC01287 AUDIT_TOLERANCE=0.01 AUDIT_JS_BUILD=/tmp/cavalier-open-pline4-trace node scripts/cavalier/probe-open-pline4-trace.mjs > /tmp/open-pline4-result.json 2> /tmp/open-pline4-trace.json
```

The saved trace records:

- 30 offset-image arrangement edges before winding rejection.
- 20 edges survive; rejected pairs measure `(2,1)` versus expected `(1,0)`.
- Those 20 edges form seven disjoint open chains. Six have no original protected
  endpoint; the remaining chain starts at protected vertex 0 but ends at
  unprotected vertex 34. Protected original endpoint 15 is no longer incident.
- Forced parity removes all 20 edges, leaving no walk to reconstruct.

Direct public `path_winding` sampling of the semantic band agrees with every
edge's propagated winding pair at distances 1e-3, 1e-4 and 1e-5 from its midpoint.
The sample script uses the algebraic left normal first, opposite the library's
visual-left ordering, so its pair is reversed before comparison. These 90 paired
checks are a separate evaluation route, not an independent exact geometry oracle.

The graph has no surviving cycle or chain between two allowed open terminals.
The existing parity rule necessarily removes these chains; its comment explicitly
permits complete deletion of an endpoint component. Public offset documentation
also allows complete removal and explains cap-dependent band trimming. This is
an understood difference in trimming policy, not a newly confirmed native bug.
It does not imply that Cavalier's output is wrong or that empty is preferable for
all applications. Allowing new open terminals would be a policy/API discussion,
not a justified local numerical repair.

Evidence: `offset-post-reversal-CC01287-*` files. The component inventory is
computed from retained graph connectivity, without geometry approximation.
The reverse-input CC01291 also returns empty in the broad replay, but this
stage-by-stage tracing and disposition concern CC01287 specifically.

## Limits and next work

Other catalogue families remain open; the replay is not audit closure. Any
30-second timeouts remain explicit unresolved performance/correctness results.
No full suite or figures were rerun for this diagnostic-only work. Prior full
validation belongs to the committed reversal-join correction, not this replay.

### Timeout follow-up

All eight timeouts concern `tangent_arc_arc_segment_interiors`: CC01640/44/47/48/
51/52/55/56. Their original ten-second screening timed out too, but the archived
30-second baseline replay completed with errors; the new 30-second limit is an
unresolved change in observable behavior. The summary therefore records both
raw-screening and completed-baseline transitions. Do not call these stable passes
or claim the earlier timeout investigation closed them on the current revision.

A copied-build control restores only `round_join`'s former `angle > 0` sweep rule.
CC01640 still exceeds 30 seconds. See `offset-post-reversal-old-sweep-control.json`.
This rules out the new tie branch as a necessary cause of that timeout; it does
not locate the responsible change or establish how long the call ultimately takes.
No timing-regression magnitude is inferred from this bounded test.

Recommended next investigation: this orientation-dependent tangent arc–arc group,
starting with CC01640, using a longer bounded run and stage profiling. Nearby
CC01645/46/49/50 match; CC01653/54/57/58 still have grouping/property differences.
The audit remains open. Findings and diagnostics are uncommitted.
