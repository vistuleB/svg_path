# Remaining audit issues

Updated 2026-09-09, including the PA1 follow-up after `c91e527`.

AD1 and OF5 have now been resolved in `c2e8865` and `3bf9b2a`. Their illustrated
entries are retained below, explicitly marked resolved, as a record of this
follow-up. They are no longer candidates for further fixes.

TS1 and OF7 are also resolved, in `5ec5fd2` and `c91e527`, respectively.

This is the outstanding-work list extracted from
[V1_REVIEW_VISUAL.md](V1_REVIEW_VISUAL.md) (the existing visual review's filename).
Original issue IDs are retained for discussion. The original document and its
figures remain a historical record, not a statement of current behavior.

DE1, AG2, and AG3 are excluded: they were repaired in `7d37623`, `126e79c`,
and `8b43c68`, respectively. The related arrangement source-interval repair is
in `af898f9`. OF7's documentation corrections were already completed; only its
code-reachability question remains below.

This update checks the subsequent commits and current intersection/orientation
code. It does not rerun every historical reproducer. “Reproduced” below refers
to the evidence recorded in the visual review unless stated otherwise.

The drawings below are retained from that review, not regenerated against this
checkout. Blue denotes source/reference geometry, red the reported problem,
and green expected or comparison geometry. Some close-ups exaggerate one axis.
OF4, CH1, CH2, and OF7 use explanatory diagrams rather than public failing
geometry; the text distinguishes private probes and illustrative results from
public reproductions. The AG1/OF8 trial displacement is illustrative, not a
captured private probe. A drawing alone does not establish a reachable failure.

## Intersection search and classification

### IX2 — a found intersection does not exhaust its parameter window

![IX2 — a found intersection does not exhaust its parameter window](examples/debug/v1_review_visuals/ix2.svg)

**Module:** `svg_path/intersections`.
**Functions:** `window_preserving_search`, `window_preserving_inspect_window`,
`window_preserving_window_already_resolved`, and `insert_intersection`.
**Status:** unresolved; supporting improvements committed, residual-search
experiment shelved.

The original reproducer uses x=t and y=(t−0.2)(t−0.21)(t−0.22).
Intersecting it with a horizontal Line finds three crossings. Representing the
same horizontal geometry as a Quadratic selects the generic solver, which
misses crossings. See the [original illustration](examples/debug/v1_review_visuals/ix2.svg).

The current window-preserving solver still has two insufficient stopping rules:

- Finding an accepted candidate can finish the current window without proving
  that it contains no other intersection.
- `window_preserving_window_already_resolved` suppresses windows whose two
  parameter widths are at most 0.125 when an existing intersection lies within
  a margin of twice those widths. Proximity to a known hit is not uniqueness.

There are still two search algorithms: the window-preserving solver and the
older descent solver used as fallback on terminal-window exhaustion. The
crossing-based window search did not become a descent step inside the older
solver.

#### Improvements retained on main

- `46b3cd6`: crossing-root refinement validates the endpoint signs of its
  bracket. Unmatched endpoint root estimates can be rejected rather than
  being treated as certified crossings. This repair is in `svg_path.gleam`.
- `d49e170`: the window solver uses conservative polygonal enclosures after
  its bounding-box test. Bézier portions use control points; Arc portions use
  endpoint/tangent enclosures. Separation includes a floating-point allowance.
  A private switch retains the bounding-box-only mode; `EnclosingPolygons` is
  selected. Subdivision also avoids zero-width and unchanged children.

These changes improve rejection of empty windows and bracket handling. They
do **not** establish that a window containing a hit has been exhausted.

#### What is not active

The attempted residual-window search, partial-result fallback merging, and
associated candidate handling are preserved in
[IX2_EXPERIMENT.md](examples/debug/IX2_EXPERIMENT.md) and
[`ix2-residual-experiment.patch`](examples/debug/ix2-residual-experiment.patch).
The patch is against `af898f9`, not current main. Some independently committed
changes are also in that historical patch; do not apply it wholesale here.

That checkpoint had **1,539 passing tests and nine failures** under `gleam test`.
Problems included multiple numerical approximations of flat/tangent roots and
search exhaustion around accepted roots. The trial `1e-15` polishing threshold
was removed. The fixed parameter-exclusion box was not an adequate way to
identify a root and delimit its remaining uncertainty.

#### Remaining work

Retain found intersections while searching the residual parameter region,
without repeatedly rediscovering one approximate root or excluding a distinct
nearby root. Candidate refinement/deduplication and window exhaustion need
separate criteria. Test clustered crossings, touching roots, endpoint hits,
and fallback behavior together. Address IX4 alongside this work; changing only
geometric deduplication can admit multiple approximations of one root.

### IX3 — parallel tangents do not imply touching

![IX3 — parallel tangents do not imply touching](examples/debug/v1_review_visuals/ix3.svg)

**Module/function:** `svg_path/intersections.classify_directions`.
**Evidence:** reproduced classification error.

The cubic y=(t−0.5)^3 crosses a horizontal line at t=0.5, but the equal-tangent
branch labels it `Touching`. Higher-order/local separation is needed to
distinguish an odd-order crossing from an even-order touch. Endpoint and
overlap cases need explicit treatment. No repair has been committed.

### IX4 — coincident positions can have distinct parameter pairs

![IX4 — coincident positions can have distinct parameter pairs](examples/debug/v1_review_visuals/ix4.svg)

**Module/function:** `svg_path/intersections.insert_intersection`.
**Evidence:** reproduced lost address.

A closed cubic can meet a line at both `(0,0.5)` and `(1,0.5)`. Current
deduplication merges hits when their positions agree **or** both parameters
are close, losing one occurrence. Preserve distinct parameter pairs while
deduplicating numerical approximations of the same pair. Endpoint preference
alone does not solve this. A later graph vertex may merge positions while
retaining both preimages.

## Arrangement and offset topology/provenance

### AG1 / OF8 — an interior probe can cross into another contour

![AG1 / OF8 — an interior probe can cross into another contour](examples/debug/v1_review_visuals/ag1_of8.svg)

**Modules/functions:** `svg_path/arrangement.dual_face_walk_sample`;
`svg_path/offset.outline_contour_probe`, `orient_outline_path`.
**Evidence:** two independently reproduced failures.

Nested squares of side 10 separated by 0.00001 expose a probe displacement of
chord×0.0001 that crosses the gap. Dual construction fails; independently,
outline orientation gives both contours the same orientation instead of
opposite orientations. Bound the probe step using surrounding boundaries,
rather than decreasing a universal sampling fraction.

**C-shape fix is separate:** `6679aa6` preserves traversal when no interior
probe is found, allowing a closed retraced line to survive orientation
normalization. It does not stop an existing probe landing in the wrong nested
region. AG1 and OF8 therefore remain open.

### OF1 — reconstruction capacity includes ineligible source occurrences

![OF1 — reconstruction capacity includes ineligible source occurrences](examples/debug/v1_review_visuals/of1.svg)

**Module/function:** `svg_path/offset.forced_parity_capacities`.
**Evidence:** reproduced zero-offset closed-square failure.

At offset zero, source and offset share graph edges. Initial capacity counts
both, but reconstruction can consume only the eligible offset occurrence.
Initialize capacities from eligible reconstruction preimages while retaining
the complete inventory for winding classification. Keep the capacity-consumed
assertion. Replacing capacities universally with one is not a valid fix.

### OF2 — a corner at the closing seam misses join construction

![OF2 — a corner at the closing seam misses join construction](examples/debug/v1_review_visuals/of2.svg)

**Module/functions:** `svg_path/offset.split_join_free_portions`,
`mark_closed_join_free_portion`, `synchronized_join_correspondences`.
**Evidence:** reproduced dependence on the starting segment address.

The linear smooth/corner partition misses the cyclic seam. A sole portion is
marked closed even when it needs an end-to-start join. Include the wraparound
boundary in classification and test cyclic rotations of the segment list.

### OF3 — closing alignment loses the first segment's edit

![OF3 — closing alignment loses the first segment's edit](examples/debug/v1_review_visuals/of3.svg)

**Module/function:** `svg_path/offset.colinearize_source_tangent_policy`.
**Evidence:** reproduced private normalization difference at the seam.

Alignment computes edits to both neighbors, but the closing Custom policy
retains only the last segment's edit. Use a cyclic alignment pass or explicit
seam handling that retains both edits. Returning the first segment as an
appended tail would duplicate it; do not alter the public closure contract
incidentally. Pair tests with OF2's cyclic-rotation cases.

### OF4 — reversed survivor geometry retains its old parameter orientation

![OF4 — reversed survivor geometry retains its old parameter orientation](examples/debug/v1_review_visuals/of4.svg)

**Module/function:** `svg_path/offset.reverse_survivor_edges`.
**Evidence:** private-helper metadata mismatch; no public failing fixture yet.

The Line reverses but its ascending preimage interval is copied unchanged into
cusp output. Carry directed interval orientation and compose it exactly once
with subsequent cuts. Do not conflate traversal reversal with the independent
geometric REVERSED classification.

### OF5 — resolved: complete erasure after parity

![OF5 — complete erasure after parity is treated differently from before it](examples/debug/v1_review_visuals/of5.svg)

**Module/function:** `svg_path/offset.finish_cusp_trim_with_parity`.
**Evidence:** controlled internal-state reproducer.

Previously, no retained geometry before parity gave `Ok(None)`, but parity
erasing the last edge gave `InternalIToKSubpathCount(0)`. Commit `3bf9b2a` makes
both cases return `Ok(None)`, preserving errors for multiple chains and invalid
sole-chain topology. The drawing illustrates the old behavior.

`node examples/debug/cusp_empty_regression.mjs` passes 17 controlled private
finisher cases: empty input, every contiguous proper portion of a four-edge
square, and the complete surviving square. Build JavaScript first using
`(cd examples/public_api_smoke && gleam build --target javascript)`.
The harness exposes the production finisher in memory without replacing its
logic or adding public API. This is not a newly found public winding fixture.

### OF6 — collapsed-handle constraints check lines rather than signed rays

![OF6 — collapsed-handle constraints check lines rather than signed rays](examples/debug/v1_review_visuals/of6.svg)

**Module/functions:** `svg_path/offset.stalled_start_control2`,
`stalled_end_control1`, including their bisection fallbacks.
**Evidence:** reproduced synthetic private-fit violation, not a full offset.

A candidate can satisfy collinearity and handle length while pointing opposite
the requested one-sided direction. Validate the signed direction, including
collapsed handles; continue the existing fallback or return fitting failure
when the candidate lies on the wrong ray.

### OF7 — resolved: unused fitting alternatives

![OF7 — apparently unused fitting alternatives](examples/debug/v1_review_visuals/of7.svg)

**Module/functions:** `svg_path/offset.e_join_free_endpoint_policy`,
`fit_offset_cubic_data_with_endpoint_policies`.
**Status:** reachability verified; dead alternatives removed.

The private policy's producer and collapsed-handle recovery never construct
`FitPositionOnly`. Removed that variant, its dispatch/direction branches, and
four exclusive fitting helpers (152 lines). The one-handle solvers and scalar
validation also serve active parallel-direction fallbacks and were retained.
This is dead-code removal, not a change to reachable fitting behavior. The
drawing describes the removed alternatives; documentation fixes were already done.

## Other public behavior and numerical contracts

### PA1 — resolved: drawing commands after closepath

![PA1 — drawing commands after closepath are rejected](examples/debug/v1_review_visuals/pa1.svg)

**Module/functions:** `svg_path/parse.parse_close`, `ensure_active`.
**Evidence:** `M0 0L1 0ZL2 0` previously returned `ExpectedMove`.

The parser now requires a current point rather than an active subpath before
accepting a drawing command. Its existing append operation starts the new
subpath at the point retained after Z. Repeated Z is a no-op; a leading Z still
errors. Closepath continues to clear both smooth-control histories.

Three regressions cover all absolute/relative drawing command families, smooth
control reset, repeated Z, and a leading-Z error. They failed before the fix.
This follows [SVG closepath semantics](https://www.w3.org/TR/SVG/paths.html#PathDataClosePathCommand).
The illustration shows the former rejection and the intended continuation.

### SP1 — extrapolated directions inherit reversed split-child orientation

![SP1 — extrapolated directions inherit reversed split-child orientation](examples/debug/v1_review_visuals/sp1.svg)

**Module/function:** `svg_path.segment_directions_with`.
**Evidence:** reproduced on a Line outside t in [0,1].

For x=10t, the incoming direction at t=−1 and outgoing direction at t=2 can
point backward. Obtain directions relative to increasing original parameter,
not a reversed split child. Preserve endpoint/stationary behavior within [0,1];
the existing local-neighborhood prototype is not a complete Arc policy.

### TS1 — resolved: compact transform serialization discarded shear

![TS1 — compact transform serialization can discard shear](examples/debug/v1_review_visuals/ts1.svg)

**Module/functions:** `svg_path/transform/serialize.analyze_rotation_scale`,
`close_to_zero`.
**Evidence:** reproduced without requested decimal rounding.

A 1e-6 near-orthogonality threshold accepted a rotate/scale decomposition that
lost a real shear. The serializer now reconstructs all four coefficients and
accepts the decomposition only within a 1e-12 relative allowance per column;
otherwise it emits `matrix`. A regression covers positive/negative small shear
and scaled-up geometry. Existing pure-rotation and anisotropic-scale tests
continue to check compact output. The drawing illustrates the old behavior.

### ST1 — zero-length visible dashes lose their caps

![ST1 — zero-length visible dashes lose their caps](examples/debug/v1_review_visuals/st1.svg)

**Module/functions:** `svg_path/stroke.dash_start`, `dash_intervals_loop`.
**Evidence:** reproduced empty output for [0,2] with Round caps.

Preserve zero-length visible dash events so cap construction can produce their
geometry. Test Butt, Round, Square, phase shifts and endpoints. Do not send zero
intervals through unrelated curve-offset construction or conflate this with
coalescing a [1,0] pattern into a solid stroke.

### AD1 — resolved: annotation sampling and containment tolerance mismatch

![AD1 — annotation sampling and containment use different tolerances](examples/debug/v1_review_visuals/ad1.svg)

**Module/function:** `svg_path/arrangement/drawing.annotated_edge_things`.
**Evidence:** reproduced helper-level incorrect side labels.

Previously, samples displaced using drawing tolerance 1e-12 were tested with
default containment tolerance 1e-9. Commit `c2e8865` passes matching containment
options. This affects annotations, not arrangement topology; the drawing
illustrates the old mismatch. A public `annotated_drawing` regression checks
all four square-edge winding labels and failed before the repair.

### CH1 — minimum-width optimization prunes with an unadjusted lower bound

![CH1 — minimum-width optimization prunes with an unadjusted lower bound](examples/debug/v1_review_visuals/ch1.svg)

**Module/function:** `svg_path/convex_hull.minimum_width_optimization_loop`.
**Evidence:** code-level inconsistency; no public geometric failure yet.

The reported lower bound includes a rounding allowance, but interval pruning
uses the raw bound; exhaustion can then report convergence without that
allowance. Apply conservative bounds consistently to pruning and convergence.
Prepare a targeted regression before changing this branch.

### CH2 — hull tangent-root helpers assert success of fallible operations

![CH2 — hull tangent-root helpers assert success of fallible operations](examples/debug/v1_review_visuals/ch2.svg)

**Module/functions:** `svg_path/convex_hull.cubic_point_tangent_roots`,
`refine_polynomial_tangent_isolation`.
**Status:** investigation, not a confirmed reachable crash.

Determine whether exhaustion can occur with the actual inputs and budgets.
Propagate the error if reachable; otherwise document the invariant supporting
the assertion. Do not replace assertions indiscriminately.

## Verification baseline and next work

For TS1 and OF7, `scripts/test-fast` passed **1,550 tests**. The private cusp
finisher regression still passed its **17 cases**, and the two public C-offset
results were unchanged. Formatting and whitespace checks passed.

For the AD1 and OF5 follow-up, `scripts/test-fast` passed **1,549 tests** and
`node examples/debug/cusp_empty_regression.mjs` passed **17 cases**.
`gleam format --check src test` and `git diff --check` also passed.
No additional issue was repaired in this follow-up.

The C-shape fix and both regressions are committed in `6679aa6`.
`scripts/test-fast` passed with **1,548 tests** for that work. Before those two
tests, `scripts/test-all` passed with **1,546 ordinary tests and 26 slow tests**
on the retained intersection improvements. These are historical completed runs,
not a fresh verification performed while writing this document.

The current interrupted task is **IX2**, with IX4's address/deduplication
contract considered alongside it. IX3 is a separate classification problem.
The other entries remain available for separate fixes with their own regressions.
