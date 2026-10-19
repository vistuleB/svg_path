# CC01189: no common sampling circle after endpoint clustering

2026-10-19, production commit `e7c1581`. Investigation only; no new library edits.

## Result

The remaining fitting-tolerance 1e-5 failure occurs before dual construction.
It is not a missed circle crossing. At vertex 11, the stored incident segments
admit **no common circle centered on that vertex**. More attempts, a different
initial radius, and tighter root residuals cannot solve this particular geometry.

The first radius is 1.4087181144878586e-9, followed by 1.126974491590287e-9.
Vertex tolerance is 2e-9. Both outgoing arcs start about 1.760897e-9 away
from the cluster center and head outward, so they cannot cross these circles.
Shrinking the radius makes this worse.

Enlarging it is also insufficient:

- Outward arc edge 10 has minimum radius 1.76089785038755836e-9.
- Cubic edge 14 has maximum control-point radius 1.76089764310982320e-9.
  By the Bézier convex-hull property, the entire cubic is inside that radius.
- Therefore any circle that reaches the arc lies outside the entire cubic.
  The radial gap is about 2.073e-16.

`analyze-cyclic-radius.py` checks this using 70-digit Decimal arithmetic on the
stored binary coordinates. It reconstructs the circular arc's center, verifies
positive radial derivative at both endpoints, and verifies its minor sweep is
short enough that no pair of derivative zeros can intervene. Its minimum is
therefore the outward start. The cubic bound follows directly from its control
points. This is a geometric check on the stored segments, not a claim that the
original mathematical SVG input contains a gap of that size, nor an interval
arithmetic certificate of the entire offset pipeline.

The vertex is (25.42188140611414, 6.034334888871326). The incident edges are:

| Edge | Attached vertex IDs | Type |
| --- | --- | --- |
| 10 | 10 → 11 | circular arc |
| 11 | 11 → 13 | circular arc |
| 14 | 13 → 11 | cubic |

The graph attaches endpoints to cluster IDs without moving their coordinates.
Here those displaced endpoints and the short connecting cubic prevent the
common-circle representation assumed by the cyclic-order sampler. Individual
endpoint distances are within the vertex tolerance. That bound alone does not
guarantee a common sampling circle.

## Related reduced JS failure

The reversed/reordered triangle/lens at size 1e-4 has the same broad obstruction:
cluster-center displacement is about 9.14618e-13, while attempted radii are
7.31694e-13 and 5.85356e-13. Some incident lines lie entirely outside those
circles. This was already reproduced on the pre-repair build. Do not assume
its full construction history or eventual repair is identical to CC01189.

## Evidence and reproduction

- `prepare-cyclic-circle-trace.py` copies the current probe JS build and wraps
  `circle_sample_for_oriented_edge`, recording failures without changing results.
- `cyclic-CC01189-offset-result.json`: original 1e-5 offset replay.
- `cyclic-CC01189-circle-failures.json`: six failed samples including all incident
  edges; two at vertex 4 and four at the fatal vertex 11.
- `cyclic-reversed-circle-failures.json`: the reduced reversed-input failure.
- `analyze-cyclic-radius.py`, `cyclic-CC01189-radius-analysis.json`: radial check.

Build `scripts/cavalier/probe` for JavaScript, then run the preparation script.
Set `AUDIT_JS_BUILD=/tmp/cavalier-cyclic-circle-trace` and
`AUDIT_TOLERANCE=0.00001`, import `probe-offset-detail.mjs`, and serialize
`globalThis.auditCircleFailures` afterward. The offset takes roughly 40 seconds;
the recorded radial analysis runs immediately without repeating it.

## Disposition and next repair direction

Confirmed native construction robustness limitation; not a defect in the
crossing solver. The documented construction API can fail, so this is not an
unconditional-success-contract violation.

Do not change the general crossing solver, silently relax tolerance, or simply
increase the circle radius. Do not drop the cubic merely because it is short:
its graph role and winding contributions must be established first.

A repair needs to address how clustered short connections are represented or
ordered. The next useful investigation is the creation of edge 14 and its
endpoint ownership: whether the arc/cubic overlap should already have become
one graph image, and whether the resulting vertex clusters can be embedded
consistently. Alternatively, an ordering fallback would need an explicit
virtual-endpoint convention and validation against winding/topology; it is not
just a root-finder adjustment. No such policy change is adopted here.

No full suite rerun: the library is unchanged from the validated commit.

## Endpoint ownership investigation and successful experiment

Follow-up tracing identifies a concrete inconsistency between two ownership
rules, rather than requiring a new cyclic-order policy.

### Provenance

The offset arrangement receives nine segments. Source 2 is a fitted offset
cubic, starting at the end of the round-join arc (source 1). Edge 14 is source 2
restricted to parameters [0.0015830488323444454, 0.0016894789061204475]. It is
not an artificial connector introduced by arrangement construction.

Adjacent portions of source 2 already map, reversed, onto arc edges 11 and 10.
The source-1 arc image has a gap between those edges, whose facing endpoints
both belong to vertex 11. The intervening cubic is instead inserted as edge 14
from vertex 13 to vertex 11.

Immediately before that insertion (progressive step 21):

| Endpoint of incoming cubic | Distance to center 11 | Distance to center 13 |
| --- | --- | --- |
| start | 1.7608976431e-9 | 2.1972874988e-9 |
| end | 1.7608950087e-9 | 5.7190801506e-9 |

With tolerance 2e-9, **both endpoints uniquely match vertex 11** under
`incoming_context` / `unique_vertex_for_endpoint`. However,
`insert_atomic_segment` calls `attach_vertex`, which independently minimizes
the enclosing-circle radius after adding the sample. Adding the start to
vertex 13 makes a smaller circle, so attachment selects 13 instead. The exact
sample-ownership preference does not apply because the cubic's endpoint differs
from the corresponding stored arc endpoint by a few floating-point units.

Thus comparison uses endpoint ownership 11→11, while insertion creates 13→11.
This is an internal ownership inconsistency, not a request to make tolerance a
universal proximity guarantee. It explains the residual bridge and the missing
common sampling circle.

### Copied-build experiment

`prepare-owner-consistency-experiment.py` changes only a temporary generated JS
build. Attachment first retains a unique existing-center match, provided adding
the sample meets the existing enclosing-circle bound. Otherwise it uses the
existing attachment rule. This does not change segment coordinates, numeric
tolerances, or public options. The ordinary same-owner collapse behavior then
applies consistently to the short cubic.

Results:

- Original CC01189, fitting tolerance 1e-5: **empty successful offset**, ~37.3s.
- Exactly two attachment decisions changed (13→11 and 25→22).
- All 24 reversed/original direction, input-order, remote-line and size
  combinations in `dual_reverse_audit_probe` succeed with three faces. This
  includes the previously failing JS size-1e-4 case.
- A separate small insertion probe demonstrates the mismatch directly: the
  endpoint uniquely matches vertex 0, but baseline attaches it to vertex 1;
  the experiment keeps vertex 0.

Evidence: `cyclic-origin-trace.json` retains all input segments, the certified
pre-dual graph/source maps, all attachment observations, and the three steps
changing vertices 11/13 or edge 14 (13, 18, 21). The full transient trace was
20MB; irrelevant intermediate graph snapshots were omitted from this record.
`prepare-cyclic-origin-trace.py` reproduces the full trace;
`summarize-cyclic-origin.py` reads either form. Other records are
`cyclic-owner-consistency-result.json`, `cyclic-owner-consistency-changes.json`,
`owner-consistency-reversed-experiment.log`, and the two
`owner-consistency-minimal-*.json` outputs from `probe-owner-consistency.mjs`.

### Recommendation

Implement a single consistent endpoint-owner selection rule, preserving exact
stored-sample ownership first and unique existing-center ownership before the
fallback enclosing-circle comparison. Add focused regressions for the minimal
insertion and both recovered arrangement cases. Test exact-sample ownership,
ambiguous clusters, endpoint collapse, source maps, and the full suite on both
targets. The copied-build experiment is evidence for this candidate, not full
regression validation. No production implementation or F# change yet.

## Production candidate

Implemented `selected_vertex_attachment`: preserve an admissible exact stored
sample owner, otherwise prefer the unique existing-center match when that
cluster still satisfies the enclosing-circle bound, otherwise retain the
existing fallback. No edge geometry, tolerances, options, or error types change.

Four portable tests in `svg_path_vertex_ownership_test` check the unique-center
mismatch, exact-sample precedence, ambiguous/missing-center fallback, and
same-vertex collapse instead of a spurious bridge. The three existing
`svg_path_dual_component_placement_test` tests now include reversed list order
as well as reversed directions. All seven focused functions passed in direct
Erlang and JavaScript runs before the canonical suite.

Actual implementation replay: CC01189 at fitting tolerance 1e-5 returns an empty
offset (`owner-repair-CC01189-0.00001.json`, ~37s diagnostic, not a benchmark).
Canonical validation is recorded in `owner-repair-test-release.log`.

### Completed validation of the implementation

With Gleam 1.18.1, the canonical command completed successfully:

```sh
PATH=/Users/jpsteinb/.nvm/versions/node/v24.10.0/bin:$PATH scripts/test-release
```

**2,080 ordinary + 31 slow + 826 portable Erlang + 826 portable JavaScript**,
no failures. Log: `owner-repair-test-release.log`. The actual 1e-6 offset replay
also remains empty (`owner-repair-CC01189-0.000001.json`, ~20s).
Both CC01189 tight-tolerance failures and the reduced reversed-order JS failure
are now repaired. Default source-normalization/collapse semantics remain a
separate policy distinction. Formatting checks, `git diff --check`, and audit
record validation pass. No F# port, figure regeneration, or commit in this turn.
