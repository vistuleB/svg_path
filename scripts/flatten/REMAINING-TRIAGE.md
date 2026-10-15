# Remaining Flatten.js observations: triage on 3.1.3

**Triage complete; FL002–FL005 have Gleam fixes. FL004 still requires a smaller minimum length for a successful result; default filtering now reports an explicit closure error.** All 21 polygon
observations have a disposition. No confirmed native bug in this inventory
remains without a Gleam fix. F# ports, the pending FL005 commit, and explicitly
deferred comparisons remain outstanding; this is not full upstream assertion
parity or release readiness. The earlier FL001 is fixed separately.

Triage baseline: Gleam `a0d45fbc` (3.1.3). No production source was changed for
the initial investigation. The subsequent FL005 implementation is described below. The original comparison records are preserved. New evidence
is in `remaining-*.json`, with executable probes alongside it.

## Disposition totals

| Classification | Observations | Detail |
| --- | ---: | --- |
| Native numerical failures, fixed in Gleam | 6 | FL002 and FL003; F# port pending |
| Native crossing bug fixed; size-policy limitation remains | 1 | FL004: explicit closure error at default minimum length; success with retained short pieces |
| Native performance failure, fixed in Gleam | 1 | FL005; all recorded distance cases now pass; F# port pending |
| Adapter contract mismatches | 12 | Strict path construction rejects discontinuous upstream coordinates |
| Upstream orientation-contract mismatch | 1 | Oppositely oriented operands in the rectangle subtraction fixture |
| Unclassified | 0 | F# ports and broader assertion adaptations remain outstanding |

These are **failure groups**, not proof of four independent implementation
mistakes. Some numerical failures may share a cause. No new wrong successful
native Boolean result was established in this pass: the native Boolean failures
return errors. FL005 establishes excessive work, not an incorrect distance.

## FL002: overlap classifiers disagree during insertion

Calls **3380, 4033, 4682** are union, difference and intersection on exactly the
same input pair (issue #55 case 2). All fail on both JavaScript and Erlang with
`ArrangementGraphError(PathError(InternalOverlapClassificationInconsistency))`.
Both input contours are exactly closed line chains, with 26 and 6 segments;
the shortest original segment is about 10.99 units, above the default minimum.
There is no non-affine Bézier parameterization or conversion rejection here.

Progressive insertion first fails at source segment 32. A diagnostic copy of
the generated runtime captured the actual two split lines. The reduced public
query in `remaining-overlap-reduced.json` reproduces the inconsistency at
`tolerance = 5e-7`: `overlaps.segment_with` returns `Ok([])`, while
`intersections.segment_with` reports the internal inconsistency. These are
roughly 11-unit lines near x=1.336 billion, with endpoint differences on the
order of 1e-7. The failed consistency check is in
`segment_intersections_checked_valid_options` in `src/svg_path/intersections.gleam`.

At CSG tolerance 1e-5 the original union succeeds. Scaling coordinates by 1e-6
with the default CSG tolerance also succeeds, but changes relative tolerance and
is not a semantics-preserving fix. Scaling tolerance proportionally produces a
winding contradiction instead. This is a native numerical robustness failure;
loosening tolerance is diagnostic evidence, not an adopted workaround.

### FL002 endpoint-bound follow-up (historical intermediate result)

The reduced lines have endpoint separations below 3e-7, but their independently
rounded midpoint evaluations differ by about 5.012e-7 at x≈1.336 billion. That
exceeds the 5e-7 query tolerance even though the exact affine correspondence is
bounded by the endpoint separations. Sampled overlap validation could therefore
reject what the line-intersection classifier correctly treated as overlap.

For line/line correspondences, both containment and affine validation now use
the endpoint-distance bound instead of rounded interior samples. The difference
between affinely paired lines is affine, and its norm cannot exceed the larger
endpoint norm. Other curve types retain their existing sample checks. The change
does not enlarge the caller's tolerance or suppress the inconsistency error.
The reduced case now gives one full overlap and `OverlappingSegments`, including
all eight operand-order / traversal-direction combinations. New native tests
also verify rejection with a tighter tolerance and ordinary isolated crossings.

**At this intermediate stage FL002 was only partially resolved:** original calls 3380, 4033, and 4682 now
reach arrangement/dual construction, then fail winding propagation with
`ConstructionFailed`. The left operand has
`ContradictoryWinding(edge_id:25, face_id:10, assigned:0, required:1)` and the right
has `ContradictoryWinding(edge_id:41, face_id:0, assigned:0, required:-1)`.
The graph has 37 vertices, 48 edges, one connected component, and 11 reported
faces; a planar embedding with these counts requires 13 faces by Euler's formula.
Both source operands have zero net directed-edge contribution at every vertex,
so the winding contradiction is not explained by an open source-image chain.

The same diagnostic on FL003 gives 54 vertices, 63 edges, one component and
9 faces instead of 11, also with balanced source images. This narrows both cases
toward noding, cyclic ordering, or dual construction; it does not prove a shared
root cause. FL004 separately has four unbalanced source-image vertices in its
right operand and still fails dual construction. No topology changes were made.

Evidence: `remaining-fl002-endpoint-reduced.json`,
`remaining-fl002-endpoint-original.json`, `remaining-fl002-endpoint-arrangement.json`,
`remaining-fl002-endpoint-internal.json`, and `remaining-fl002-source-balance.json`.
The standalone Erlang replay is `remaining-fl002-endpoint-erlang.log`.
These are working-tree results; historical reports are retained. The Erlang
replay also returns `ConstructionFailed` for all three original FL002 operations.

Validation: `scripts/test-release` passed 2,026 main tests, 31 slow tests,
and 772 portable tests on each of Erlang and JavaScript. Formatting, whitespace,
and the Flatten catalog checks passed. The FL002 changes are uncommitted;
no F# port or figure regeneration was performed.

## FL003: per-operand winding contradiction

Calls **3497, 4150, 4799** use identical input geometry (issue #55 case 3).
Union, difference and intersection fail on both targets with
`ArrangementGraphError(ConstructionFailed)`.

The original contours have 48 and 10 exactly joined/closed line segments; the
shortest original segment is about 5.52 units. Arrangement construction succeeds
with 54 vertices and 63 edges; the dual has 9 faces. Replaying the actual
per-operand source multiplicities through `arrangement.face_windings` yields:

- left operand: `ContradictoryWinding(edge_id: 47, face_id: 1, assigned: 0, required: -1)`;
- right operand: `ContradictoryWinding(edge_id: 52, face_id: 1, assigned: -1, required: 1)`.

CSG maps these errors to `ConstructionFailed`. Lowering `minimum_length` from
1e-5 to 1e-9 leaves the same contradiction. Scaling coordinates and tolerance
both by 1e-6 lets this case reach consistent winding propagation (55 vertices,
64 edges, 11 faces). The evidence localizes the failure to the numerical
arrangement/dual/source-image result, not the upstream fill rule. It does not yet
isolate whether incorrect noding, cyclic ordering, or ownership is responsible.

### FL002 / FL003 topology investigation (diagnostics only)

The two-face deficit is already present in the raw walks induced by the stored
cyclic orders, before the dual's face grouping. Exact rational cross-product
comparisons of the stored binary floating-point line endpoints identify:

- FL002: vertex 12 reverses outgoing edges 12 and 41. Correcting only that pair
  changes the walk/face count from 11 to 13.
- FL003: vertex 8 reverses edges 7 and 53; vertex 50 reverses edges 51 and 52.
  Both corrections are needed: either alone leaves nine faces, while both give 11.

Both the original segment-direction vectors and the official vertex-to-vertex
chords give the same corrections. The direction comparator in the investigation
uses Python `Fraction` arithmetic to avoid using an uncertain double-precision
angle comparison as its reference. No edge geometry or source provenance is
changed in these experiments.

The existing sampler computes absolute-coordinate circle intersections and
angles. At these vertices the meaningful angular gaps are approximately
2e-12, 4e-9, and 3e-12 degrees. Rounded sample positions can reverse those gaps.
FL002's three radius votes all favor the wrong order. At FL003 vertex 8, two of
three votes favor the wrong order. Vertex 50 is more serious than an ambiguous
group tie-break: the reversed edges are placed in separate certified groups.
Changing only the ambiguous-group voting rule would therefore miss this case.

Each failure reproduces on a **three-line fan** extracted from the graph.
Translating that diagnostic fan to place its common vertex at the origin makes
the existing `vertex_cyclic_order_with` return the correct order in all three
cases. Independently resampling every vertex in its own local coordinates, then
applying only those orders to a copy of the original graph, produces:

| Input pair | Original faces | Locally sampled faces | Operand windings | Union / difference / intersection |
| --- | ---: | ---: | --- | --- |
| 3380 (FL002) | 11 | 13 | both consistent | all return successfully |
| 3497 (FL003) | 9 | 11 | both consistent | all return successfully |

The existing dual and Boolean routines were used from a copied generated
JavaScript runtime, with their private entry points exported for diagnosis.
Vertices, edges, source mappings, tolerances and winding rules stayed unchanged
in the graph passed to those routines. This establishes cyclic-order computation
as the cause of these winding failures; successful Boolean return values alone
are not a complete output-equivalence proof.

An exact rational inventory of stored line intersections finds only crossings
between edges that already share a vertex. Several lie a few microunits away
from the representative vertex because stored endpoints are not snapped to it.
These residual geometric effects were not changed; they are not needed to
explain or remove the observed two-face deficit.

**Candidate implementation:** perform circle sampling and angle/separation
calculations in vertex-local coordinates, retaining original stored geometry.
The diagnostic results support this approach without adding a tolerance or
altering winding propagation. No production implementation or new full-suite
validation has been performed for this proposal. FL002 and FL003 remain open
pending implementation and validation; FL004 remains a separate investigation.

Evidence and reproduction:

```shell
PROBE_LABEL=topology-snapshots node scripts/flatten/investigate-remaining.mjs graph-snapshot 3380 3497
python3 scripts/flatten/probe-topology.py
python3 scripts/flatten/prepare-topology-runtime.py > /tmp/flatten-topology-runtime-url
PROBE_RUNTIME="$(cat /tmp/flatten-topology-runtime-url)" node scripts/flatten/probe-topology-replay.mjs
```

The three `remaining-topology-*.json` reports retain graphs, rational direction
comparisons, sampled radii, reduced fans, single-vertex replacements, and the
all-vertices-local replay. The production source was not edited in this pass.

## FL004: contradictory planar-dual certification

Call **4920** (issue #139 intersection) fails on both targets with
`ArrangementGraphError(ConstructionFailed)`. Both input line chains are exactly
closed; they contain 9 and 51 segments, with minimum lengths about 0.0770 and
0.01656, respectively. All original segments exceed the default minimum.

Arrangement construction succeeds (65 vertices, 69 edges). A diagnostic copy
that preserves the hidden arrangement error identifies
`InternalDualSweepContradiction(walk: 4)` in `arrangement.dual`.

Increasing CSG tolerance to 1e-5 makes the intersection succeed. Lowering only
minimum length to 1e-9 changes the failure to contradictory face windings;
lowering tolerance as well to 1e-8 yields consistent winding propagation.
This is a native numerical/topological failure, not a rejected input syntax or
an unsupported curve correspondence. The error's precise algorithmic correction
is still to be determined; successful option variants are not an output-equivalence
proof or a proposed change to defaults.

## FL005: non-intersecting closest-pair search explosion

Call **317** still exceeds a 60-second worker limit on JavaScript 3.1.3.
The expected polygon-boundary distance is 50, with witnesses (250,200) and
(250,250). A per-segment probe finds that distance quickly, but three of the
44 individual pair queries exceed a three-second diagnostic cap.

A reduced native example removes all adapter details:

- line from (170,200) to (120,350);
- quarter-circle from (200,300) to (250,250), radius (50,50), positive sweep;
- closest distance analytically `sqrt(102² + 34²) - 50 = 57.5174404457249`.

The default public closest-pair call exceeds a 15-second cap. In a temporary
instrumented runtime it inspects **200,000 windows** before reaching even a
terminal generation (remaining depth 27 out of 48); its best upper bound still
has squared distance 3610. The diagnostic run deliberately stops there.
`inspect_projection_window` and `collect_projection_terminal_windows_generation`
retain a loose boundary-derived upper bound until terminal windows refine it.
The FL001 crossing seed does not help this disjoint pair.

Lower depth 8/16 runs return `DistanceMaxIterationsReached`; those are not
successful fixes. The evidence supports a search-performance defect requiring
better bounds/refinement. It does not establish a regression introduced by
3.1.3, nor a new correctness failure. No F# performance claim is made here.

### FL005 implementation follow-up (working tree, after 3.1.3)

The line/arc branch now considers endpoint projections, line crossings, and
arc projection extrema in the line-normal direction. For an interior positive
minimum, the separation must be perpendicular to both tangents; this reduces
line/elliptical-arc distance to a finite candidate list. Candidate distances are
evaluated on the original segments. Line parameters are clamped to the finite
line. Failed analytical queries retain the existing numerical fallback. Public
options, tolerances, and the generic curve/curve search are unchanged.

The first experiment tightened bounds with window midpoint samples. It reached
terminal subdivision but still produced enough windows to overflow recursive
window numbering on JavaScript. That experiment was **not adopted**. The change
is limited to line/arc pairs, not a claimed repair of generic subdivision.

Observed JavaScript timings (single cold worker measurements, not benchmark
medians): the reduced line/arc case returned 57.517440445724915 in about 12 ms;
the original polygon query returned distance 50 and the expected witnesses in
about 34 ms. Independent line/arc pairs (4,0) and (5,3) returned in about 11 and
16 ms. Evidence: `remaining-fl005-fixed.json`,
`remaining-fl005-fixed-replay.json`, and `remaining-fl005-fixed-pairs.json`.
These reports use the uncommitted implementation atop the recorded HEAD.

**Status after the line/arc-only change (superseded by the follow-up below):** independent arc/arc pair (9,0) still exceeds 60 seconds.
Its analytical distance is `sqrt(75² + 150²) - 80`; the arcs are the first
quadrant of the radius-30 circle centered at (175,150), and the third quadrant
of the radius-50 circle centered at (250,300). The original polygon query now
prunes that pair using its distance-50 bound, but this is not a repair of the
standalone arc/arc query. An exact-endpoint native reduction also exceeds a
15-second cap (`remaining-fl005-arc-reduced.json`; reproduce with
`PROBE_TIMEOUT_MS=15000 node scripts/flatten/investigate-remaining.mjs distance-arc-reduced 317`). The earlier summary's three slow pairs included this
arc/arc pair; they were not all line/arc pairs. No F# port has been made.

Four added native regressions in `svg_path_flatten_closest_pair_test.gleam`
cover the reduced interior minimum (both operand orders with evaluated
witnesses), finite-line endpoint clamping, a zero-length line, and a noncircular
ellipse. Existing crossing and positive near-tangent gap regressions are retained.
`probe-fl005-line-arc.mjs` additionally checks 96 analytical cases across
rotation, scale, translation, sweep reversal, and operand order; all pass, with
maximum absolute distance error about 2.1e-10. The evidence is recorded in
`remaining-fl005-transform-checks.json`.

Validation: `scripts/test-release` completed successfully: 2,020 main tests,
31 slow tests, and 766 portable tests on each of Erlang and JavaScript.
`gleam format --check` on the changed source/tests, `git diff --check`, and
the Flatten catalog validation also passed. No figure regeneration or F# port
was performed for this change. Changes are uncommitted.

### FL005 arc/arc follow-up

The remaining pair is now handled by a tighter lower bound in the existing
arc/arc subdivision search. Each surviving window evaluates its midpoint pair
for an upper bound and projects both arc pieces along that separation direction.
Endpoint values and analytic ellipse projection extrema give each projection
interval. The gap between those intervals is a lower bound on Euclidean distance,
so a window whose lower bound exceeds the best evaluated distance can be pruned.
The existing axis-aligned box bound is retained. Projection intervals are expanded
by a coordinate-scaled floating-point allowance (64 machine epsilons times the
coordinate/radius magnitude); this weakens pruning, not the caller's tolerance.
Terminal subdivision, descent, depth options, and returned witness evaluation
are unchanged. The additional bound applies only to arc/arc pairs.

The exact-endpoint reduction now returns `87.7050983124842` (analytical value
`87.70509831248424`) in about 36 ms. A diagnostic copy with this bound disabled
hits the 200,000-window cap at remaining depth 29; with the bound it finishes
in **197 windows**. See `remaining-fl005-before-arc-window-count.json`,
`remaining-fl005-bound-window-count.json`, and `remaining-fl005-arc-bound.json`.
The diagnostic baseline is the current runtime with only this helper bypassed,
not a separately built release. The retained earlier timeout reports are the
unmodified pre-bound evidence.

All 44 original segment-pair queries now complete, including pair (9,0), with
single-worker query times no greater than about 46 ms in the recorded concurrent
probe. See `remaining-fl005-bound-pairs.json`. These timings are observations,
not repeat-median benchmarks or CI timing assertions. For the 41 pairs that
already completed in the baseline, the maximum distance change is 5.7e-14.

Three further native regressions cover the circular interior minimum (including
reversed orientation and operands with evaluated witness checks), an elliptical
pair separated by known supporting lines, and a positive near-tangent gap.
`probe-fl005-arc-arc.mjs` checks 96 analytical ellipse-pair variants across
rotation, scale, translation, sweep reversal, and operand order; all pass with
maximum absolute error about 4.2e-10. Results are in
`remaining-fl005-arc-transform-checks.json`.

All 124 captured `distanceTo` queries were replayed by
`probe-fl005-distances.mjs`: 120 match and four retain their documented
API-scope difference (distance to an infinite line); no failures or timeouts.
See `remaining-fl005-distance-replay.json`. Historical observations were retained.

Validation of the combined line/arc and arc/arc changes:
`scripts/test-release` passed **2,023 main tests + 31 slow tests**, plus
**769 portable tests on each of Erlang and JavaScript**. Formatting, whitespace,
and the archive/catalog checks passed. No figure regeneration was performed.
The implementation and added regressions remain uncommitted.

No F# port has been made. This addresses the recorded FL005 cases, not a claim
that the general closest-pair solver has bounded work for every geometry.

## Twelve conversion failures: adapter contract mismatch

Calls **3115, 4278–4282, 4291–4296** fail at conversion of upstream contours.
The captured endpoint coordinates are already unequal before the corresponding
native operation. `svg_path.subpath` requires exact joins, whereas Flatten's
contours tolerate nearby endpoints. The adapter neither merges endpoints nor
inserts connectors. The resulting `Discontinuous` errors satisfy our contract.

Three failures occur while converting upstream output, after our Boolean query
succeeds (3115, 4278, 4291); nine occur while converting a later input. The
first rejected joins in the original observations are approximately 1e-14 to
7e-13 apart. `remaining-gaps.json` also examines later outputs not reached by
the original adapter: call 4296's reference result includes a larger 1.86e-8
join gap. That is upstream geometry too, not native output.

These observations are classified, but their underlying geometry comparisons
remain **unexecuted** until an explicit adapter continuity policy is chosen.
They are not promoted to matches. A bounded endpoint-reconciliation policy is
an audit-adapter suggestion, not a proposed weakening of our constructor.

## Call 4354: opposite orientation in upstream Boolean operands

The fixture subtracts x=100..200 from x=0..200, both at y=0..200. Our result
contains (50,100) and excludes (150,100), as subtraction requires. Flatten's
captured result does the reverse, despite both results having area 20,000.

An independent replay of pinned upstream source confirms that its operands
have opposite face orientations (-1 and +1). Flatten's README section
“Boolean operations” requires both operands to have the same meaning of face
orientation; validity is the caller's responsibility. Reversing the cutter to
match the subject makes Flatten's output agree with ours. Its original test
asserts only one face and four edges, so it does not catch the wrong region.

This is an upstream precondition/API-contract mismatch, **not our bug**. The
independent replay is `probe-rectangle-reference.cjs`; its results are in
`remaining-rectangle-reference.json`.

## Reproduction and limits

```shell
node scripts/flatten/investigate-remaining.mjs replay
node scripts/flatten/investigate-remaining.mjs arrangement 3380 3497 4920
node scripts/flatten/investigate-remaining.mjs overlap-reduced 3380
PROBE_TIMEOUT_MS=15000 node scripts/flatten/investigate-remaining.mjs distance-reduced 317
node scripts/flatten/probe-rectangle-reference.cjs
(cd scripts/flatten/probe && gleam run)
```

`prepare-diagnostic-runtime.py` prints a temporary runtime URL. Supplying it as
`PROBE_RUNTIME` exposes hidden arrangement errors, logs the inconsistent line
pair, and caps distance instrumentation at 200,000 windows. It never edits the
production source or normal generated runtime. `remaining-internal.json` and
`remaining-distance-window-count.json` record those diagnostics. The option
sweeps record their settings in each report. Raw observations remain untouched.

The initial standalone Erlang probe reproduced all seven native Boolean errors. The
JavaScript probes cover all 21 observations; timed-out workers are terminated.
No production changes, full test-suite rerun, figure regeneration, or fixes were
performed for the initial triage; see the subsequent FL005 follow-up above. `COVERAGE-GAPS.md` remains the separate inventory of
unimplemented assertion adaptations.

## Vertex-local cyclic sampling implementation

The sampler now translates a temporary oriented segment by the arrangement
vertex before solving its circle crossings and evaluating the sample. Angles
and sample separation use these local points. Stored vertices, edges, source
images, tolerances, sampling radii and iteration limits remain unchanged.
Arc translation preserves radii, rotation and flags.

Three reduced fans in `svg_path_flatten_cyclic_order_test.gleam` cover both
traversal directions and world/local coordinate versions. They include the
short-radius majority-vote reversal and the incorrectly separated singleton
groups, so the fix does not depend on treating every close pair as ambiguous.

The original six FL002/FL003 Boolean calls now succeed on Erlang and JavaScript.
The JavaScript replay has 13 faces for FL002 and 11 for FL003, with both operand
windings consistent. Each Boolean output matches all 169 sampled containment
points and the existing relative-area comparison against Flatten. These checks
are sampled geometry comparisons, not proof of exact boundary equivalence.
FL004 remains a dual-construction error and is not resolved by this change.

Evidence: `remaining-local-sampling-original.json`,
`remaining-local-sampling-arrangement.json`,
`remaining-local-sampling-comparison.json`, and
`remaining-local-sampling-erlang.log`. These records describe the working tree
based on the recorded commit, including the pending FL005 change.

All three reduced JavaScript regressions fail when a temporary runtime copy
restores the previous world-coordinate sampler, and pass with the local sampler.
See `remaining-local-sampling-regressions.log`. No production/generated build
files were modified by that negative control.

Validation of this working tree: `scripts/test-release` passed 2,029 main tests,
31 slow tests, and 775 portable tests on each of Erlang and JavaScript.
`scripts/generate-published-figures` completed all 13 README and 33 Gallery
figures; all 46 are byte-for-byte identical to their pre-change baselines.
Counts and figure hashes are retained in `remaining-local-sampling-validation.txt`
and `remaining-local-sampling-figures.json`. This validates the combined worktree,
including the still-pending FL005 change; it does not close FL004 or the adapter
and assertion-coverage gaps.

## FL004 follow-up: two independent mechanisms

Investigation after `f10fa99`; no production source changed. The pending FL005
closest-pair implementation remains in the worktree but is not involved in
these line-only queries.

### Discarded split pieces (documented size policy)

At default `minimum_length = 1e-5`, the right operand has four vertices with
nonzero source flow. Two gaps are about 4.74e-6 and 3.095e-6 units long, larger
than the 1e-6 vertex tolerance but smaller than the minimum length. The original
segments were longer than the threshold; these are pieces produced by splitting.
The CSG options documentation explicitly says refined pieces below this bound
are discarded. Therefore original input closure does not guarantee source-flow
closure after this configured filter. This part is an understood consequence
of the current policy, not evidence of a missed input segment.

With `minimum_length = 1e-9`, all source flows balance, but both operand windings
still contradict. Retaining small pieces alone does not resolve FL004.

### Tolerance-sized reversed overlap hides a real crossing

Two lines suffice to reproduce the second mechanism:

- A: `(0, 0)` to `(1, 1)`.
- B: `(-2e-7, 2e-7)` to `(1, 0.999997)`.

Their genuine crossing is near `(0.117646882357, 0.117646882357)`, about 0.166
units from the clustered start. At intersection/overlap tolerance 5e-7,
`overlaps.segment_with` instead finds a short correspondence:
A parameters `[0, 2e-7]`, B parameters `[1.9999996000000803e-7, 0]`.
That correspondence is reversed despite the lines' nearly equal directions.
Its A span is about 2.83e-7 units. Both endpoint residuals satisfy the tolerance,
so the current affine-distance test accepts it. This is not floating-point
cancellation or the earlier cyclic-angle sampling problem.

`intersections.segment_with` returns `OverlappingSegments` as specified when
any overlap is detected. In arrangement construction,
`pair_cuts_with_common_endpoint_sliver` treats that error as no additional cuts
when an endpoint vertex is shared. The resulting graph contains two edges and
three vertices, omitting the genuine interior crossing. This conflicts with
the arrangement's documented atomic-edge invariant. The overlap query itself
has a distance-based contract; rejection of such correspondences is a proposed
refinement of that policy, not an assertion that its current endpoint-distance
calculation is wrong.

The reduced case reproduces on Erlang and JavaScript. Changing operand order
has the same outcome. See `probe-fl004-reduced.mjs`,
`probe/src/flatten_fl004_probe.gleam`, `remaining-fl004-reduced.json`, and
`remaining-fl004-reduced-erlang.log`.

### Candidate fix experiment, not adopted

`prepare-fl004-runtime.py` copies the JavaScript runtime to a temporary directory
and rejects a line correspondence when its two paired displacement vectors
have nonpositive dot product. It leaves the normal build and production source
unchanged. With this diagnostic guard:

- The two-line fixture recovers the interior crossing in either operand order;
  its arrangement has four vertices and three edges (the short common prefix
  merges within tolerance).
- The original FL004 graph with minimum length 1e-9 has 67 vertices, 75 edges,
  10 faces, and consistent windings for both operands. Its intersection succeeds,
  with signed area 0.1889795884135252 versus the upstream result's
  0.18897957530876658. This is an area observation, not a complete boundary check.
- With the default minimum length, dual construction now succeeds, but right
  operand winding propagation still fails because of the four flow imbalances.

Recommendation: first consider the narrow line-direction guard, with dedicated
regressions and full validation before adoption. Separately decide whether CSG
should retain topology-essential short pieces or report filtering-induced
closure loss more explicitly. Silently raising the vertex tolerance or lowering
the user's minimum length is not part of this experiment. FL004 stays open;
this investigation does not claim a default-options fix or release readiness.

Evidence: `remaining-fl004-crossings.json`, `remaining-fl004-source-balance.json`,
`remaining-fl004-small-minimum-balance.json`, `remaining-fl004-topology.json`,
`remaining-fl004-small-minimum-topology.json`, and the
`remaining-fl004-direction-*.json` and `remaining-fl004-reduced-direction-guard.json`
reports. Exact rational checks of stored line segments are available through
`probe-topology.py <snapshot filename> <report filename>`.

Reproduction of the candidate (diagnostic only):

```shell
python3 scripts/flatten/prepare-fl004-runtime.py > /tmp/fl004-runtime-url
PROBE_RUNTIME="$(cat /tmp/fl004-runtime-url)" PROBE_MINIMUM=1e-9 PROBE_LABEL=fl004-direction-small-minimum node scripts/flatten/investigate-remaining.mjs arrangement 4920
PROBE_RUNTIME="$(cat /tmp/fl004-runtime-url)" PROBE_MINIMUM=1e-9 PROBE_LABEL=fl004-direction-small-minimum-boolean node scripts/flatten/investigate-remaining.mjs boolean 4920
```

No full test suite or figure regeneration was run for this investigation because
no production fix was adopted. The previous localized-sampling validation is
recorded separately above.

## FL004 implementation: direction guard and explicit closure failure

The line correspondence guard is now implemented in Gleam. Unit directions
are compared with the signs of the paired parameter intervals, avoiding a
product of vector magnitudes and parameter spans. It rejects a backwards
correspondence between codirectional lines while retaining a genuine overlap
traversed in opposite directions. The crossing and reduced arrangement are
covered for both operand orders; the intersection regression also covers both
traversal directions.

CSG now validates each operand's directed source flow after arrangement
construction. If any vertex has nonzero incoming-minus-outgoing multiplicity,
it returns `RefinedBoundaryNotClosed(path_index, vertex, net_flow)` before dual
construction or winding propagation. This is a new public error variant;
callers exhaustively matching `csg.Error` must handle it. Binary and unary CSG
use the same check. Vertex selection is deterministic. The error describes
the observed loss of closure, not a claim that filtering is the only possible
cause. The documented minimum-length policy remains unchanged.

At default options, original call 4920 now reports
`RefinedBoundaryNotClosed(1, 8, -1)` on Erlang, identifying the right operand.
With `minimum_length = 1e-9`, the original intersection succeeds. Both outcomes
have portable native regressions in `svg_path_flatten_boundary_test.gleam`.
No tolerance widening, automatic retries, or silent minimum-length override
were introduced. Thus the crossing bug has a fix, while successful default
CSG for this fixture remains limited by the configured size-filter policy.

The adopted JavaScript implementation returns the same explicit error at default
options. With minimum length 1e-9, all 169 sampled containment points match the
upstream output; signed-area error is about 1.31e-8. See
`remaining-fl004-implemented.json` and `probe-fl004-implemented.mjs`.
The original reduced baseline is preserved separately from
`remaining-fl004-implemented-reduced.json`.

Final implementation validation: `scripts/test-release` passed 2,034 main tests,
31 slow tests, and 780 portable tests on each of Erlang and JavaScript.
`scripts/generate-published-figures` regenerated all 13 README and 33 Gallery
figures successfully; all 46 are byte-for-byte unchanged. Formatting and
`git diff --check` passed. See `remaining-fl004-implemented-validation.txt`
and `remaining-fl004-implemented-figures.json`. These checks cover the combined
worktree, including the pending FL005 changes. F# ports remain pending, and the
adapter-continuity and assertion-coverage gaps are unchanged.
