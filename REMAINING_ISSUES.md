# Remaining audit issues

Updated 2026-09-09, including the SP1 and OF3 follow-ups after `f57dd01`.

Gallery regeneration subsequently exposed and resolved an offset-map cumulative
length roundoff failure: subtracting a span's start from a valid cumulative
endpoint could exceed the stored segment length. The conversion is now clamped
to the selected span after strict global-distance validation. A regression
covers both an interior boundary and the final endpoint using lengths 10 and
0.3; it failed before the fix with `InvalidLengthDistance(0.3000000000000007, 0.3)`.
Both offset-text generators now run during Gallery generation instead of merely
copying their saved SVGs. The second-offset arrangement remains an explicitly
labeled archived diagnostic; reconnecting its original graph-capture generator
is still needed for fresh verification. The next two audit issues were deferred
to address this Gallery failure first.
`scripts/test-fast` passed **1,560 tests** with this fix.
`scripts/generate-published-figures` then completed: 28 freshly recomputed
Gallery figures, one explicitly archived arrangement figure, and nine README
figures. `xmllint --noout` accepted the Gallery files and staged chat previews.

The subsequent arrangement follow-up restored fresh generation of that final
Gallery entry. `scripts/gallery/package_title_arrangement.escript` traces the
actual production classification and capacity-reduction calls while running
the second `1.05` offset. It does not duplicate pruning algorithms or alter the
library. The initial capture was incorrectly taken after offside trimming.
The corrected diagnostic disables offside trimming only for the second offset,
capturing all 1,181 graph edges: 783 eligible offset edges, 471 initially
submerged, 103 initially dangling and deleted, 24 deleted later, and 185
retaining positive final capacity. Yellow uses the historical initially
degree-one/deleted meaning, not a serial capacity decrement. The original SVG
is archived at `docs/gallery/archive/second-offset-arrangement-2026-08-22.svg`.
The maintained fixture writes directly into `test/generated/gallery` and has
no dependency on that archived drawing.

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
and fallback behavior together. IX4's position-only deduplication has now been
removed on the current solver, with the fast suite and second-offset fixture
passing. The archived residual-search experiment still needs its own checks
for multiple approximations of one root; IX4 does not resolve window exhaustion.

### IX3 — parallel tangents do not imply touching

![IX3 — parallel tangents do not imply touching](examples/debug/v1_review_visuals/ix3.svg)

**Module/function:** `svg_path/intersections.classify_directions`.
**Evidence:** reproduced classification error.

The cubic y=(t−0.5)^3 crosses a horizontal line at t=0.5, but the equal-tangent
branch labels it `Touching`. Higher-order/local separation is needed to
distinguish an odd-order crossing from an even-order touch. Endpoint and
overlap cases need explicit treatment. No repair has been committed.

### IX4 — coincident positions can have distinct parameter pairs — resolved

![IX4 — coincident positions can have distinct parameter pairs](examples/debug/v1_review_visuals/ix4.svg)

**Module/function:** `svg_path/intersections.insert_intersection`.
**Evidence:** reproduced lost addresses; regression-tested repair.

A closed cubic can meet a line at both `(0,0.5)` and `(1,0.5)`. The old
deduplication merged hits when their positions agreed **or** both parameters
were close, losing one occurrence. Deduplication now requires both parameters
to be within the existing `1e-9` parameter tolerance. Endpoint preference is
preserved within such a duplicate pair. Geometric certification still uses
the caller's tolerance; only the unrelated position-based merging is removed.
A graph vertex may merge positions while retaining both preimages.

Two public regressions failed before the repair and pass afterward: a closed
cubic meeting a line at both endpoints (also with operands swapped), and a
retraced quadratic meeting a line at two interior parameters. Removed the
unused geometric deduplication tolerance and its private argument plumbing.
`scripts/test-fast` passes **1,565 tests**. The production second-offset
capture (`escript scripts/gallery/package_title_arrangement.escript`) succeeds
and its SVG is byte-identical to the published Gallery figure.

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

### OF1 — resolved: reconstruction capacity included ineligible source occurrences

![OF1 — reconstruction capacity includes ineligible source occurrences](examples/debug/v1_review_visuals/of1.svg)

**Module/functions:** `svg_path/offset.retain_offset_image_edges`,
`offset_reconstruction_images`, `forced_parity_reduce_trim_graph`.
**Evidence:** zero-offset closed-square and duplicate-square regressions failed
before the fix with `ConstructionFailed`; an open-line control already passed.

At offset zero, source and offset share graph edges. Initial capacity counted
both, but reconstruction could consume only the eligible offset occurrences.
Capacities now count the same filtered source-image occurrences that
reconstruction visits. The pruning adapter respects these explicit counts,
excluding submerged edges, while the full arrangement remains unchanged for
winding classification. Band trimming still derives capacity from all its
boundary occurrences. The capacity-consumed assertion remains in place.

Regressions cover both square orientations, an open line's endpoint demands,
and two coincident square traversals. The latter preserves total length 80,
guarding against incorrectly replacing every capacity by one.
Verification: `scripts/test-fast` passed **1,563 tests**. Both
`escript scripts/gallery/package_title_arrangement.escript` and
`gleam run -m svg_path_two_corner_square_bands_fixture` succeeded and left
their tracked generated outputs unchanged. Formatting and whitespace checks
passed.

### OF2 — resolved: a corner at the closing seam missed join construction

![OF2 — a corner at the closing seam misses join construction](examples/debug/v1_review_visuals/of2.svg)

**Module/functions:** `svg_path/offset.split_join_free_portions`,
`mark_closed_join_free_portion`, `synchronized_join_correspondences`.
**Evidence:** reproduced dependence on the starting segment address.

The single-portion case now checks the last-to-first source tangent boundary
before marking the portion internally closed. A sharp seam remains an open
portion, so it is not incorrectly healed as a smooth boundary. The join
assembler now visits the closing boundary even with only one portion; smooth
coincident endpoints produce no additional join geometry.

A public untrimmed-offset regression covers both cyclic orderings of a Line
and CubicBezier with one smooth junction and one corner. Both must succeed,
remain closed, and contain exactly one Round join. The seam-at-corner case
failed before the fix. The illustration shows that former failure.
Verification: `scripts/test-fast` passed 1,554 tests in the combined OF2/CH1
worktree; `scripts/test-slow` passed its 26 additional tests.
The existing `closed_offset_preserves_corner_at_single_portion_seam_test`
was rerun successfully during the OF1 follow-up; no further OF2 code change
was needed.

### OF3 — resolved: closing alignment lost the first segment's edit

![OF3 — closing alignment loses the first segment's edit](examples/debug/v1_review_visuals/of3.svg)

**Module/function:** `svg_path/offset.colinearize_source_tangent_policy`.
**Evidence:** reproduced private normalization difference at the seam.

The source normalizer now aligns the last-to-first boundary explicitly before
rebuilding the ordinary interior boundaries. Both edited endpoint segments are
retained. For a single closed cubic, the start-handle and end-handle edits are
combined into that one segment. Final closure uses Strict; the public Custom
contract is unchanged, and no extra segment is appended.

Two public normalization regressions failed before the fix: one checks all
three cyclic orderings of a Cubic/Line/Line source and preservation of its
start and closedness; the other checks both endpoint directions of a single
closed cubic. The original drawing depicts the discarded first-handle edit.

### OF4 — resolved: reversed survivor parameter orientation

![OF4 — reversed survivor geometry retains its old parameter orientation](examples/debug/v1_review_visuals/of4.svg)

**Module/function:** `svg_path/offset.reverse_survivor_edges`.
**Evidence:** private-helper and downstream conversion regression; no public
offset fixture was needed to demonstrate the parameter-mapping error.

Reversing a survivor now also reverses its arrangement-split section geometry,
endpoint vertices, and directed H interval. The immutable I/H preimages and the
independent geometric REVERSED flag are unchanged. Both offside and cusp output
conversions therefore receive the correctly oriented interval without needing
separate reversal logic. Double reversal restores the original metadata.

`node examples/debug/survivor_provenance_regression.mjs` passes seven private
production-helper cases, covering both geometric REVERSED states, both output
conversions, later local-to-H parameter mapping, double reversal, and a survivor
without traced provenance. Before the fix it reproduced the wrong interval.
Build JavaScript first as described for the cusp regression. The illustration
depicts the old mismatch using explanatory parameter values.

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

### OF6 — resolved: collapsed-handle constraints checked lines rather than signed rays

![OF6 — collapsed-handle constraints check lines rather than signed rays](examples/debug/v1_review_visuals/of6.svg)

**Module/functions:** `svg_path/offset.stalled_start_control2`,
`stalled_end_control1`, including their bisection fallbacks.
**Evidence:** reproduced synthetic private-fit violation, not a full offset.

A candidate could satisfy collinearity and handle length while pointing opposite
the requested one-sided direction. Both collapsed-handle fitters now validate
the returned cubic's actual one-sided endpoint directions against the requested
directions. This common final check covers direct, parallel-fit, and bisection
branches, including higher-derivative directions at collapsed handles. A wrong
ray returns fitting failure through the existing error/refinement path.

`examples/debug/collapsed_handle_rays.escript` tests the actual compiled private
fitters with exports enabled only in memory. Its 12 cases cover correct rays,
each wrong endpoint separately, both wrong, and forward/backward parallel
constraints for both collapsed endpoints. The wrong-ray case failed before
the fix; all 12 now pass. `scripts/test-fast` passed **1,563 tests**.

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

### SP1 — resolved: extrapolated directions inherited split-child orientation

![SP1 — extrapolated directions inherit reversed split-child orientation](examples/debug/v1_review_visuals/sp1.svg)

**Module/function:** `svg_path.segment_directions_with`.
**Evidence:** reproduced on a Line outside t in [0,1].

For x=10t, the incoming direction at t=−1 and outgoing direction at t=2 pointed
backward. Polynomial segments outside [0,1] are now reparameterized over the
increasing interval [t−1,t+1], then evaluated at its interior midpoint using
the existing singularity-safe direction logic. This supplies genuinely opposite
sides of t, including at stationary points. Arc handling already uses its
derivative and is unchanged, as is all handling within [0,1].

Three regressions cover extrapolated Lines, quadratic stationary reversals,
and a cubic stationary point with no reversal. The Line and Cubic tests failed
before the fix; the Quadratic test guards existing correct behavior. The
illustration shows the old Line failure.
Verification in the combined SP1/OF3 worktree: `scripts/test-fast` passed
1,559 tests; `scripts/test-slow` passed 26 tests.

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

### CH1 — resolved: minimum-width pruning used an unadjusted lower bound

![CH1 — minimum-width optimization prunes with an unadjusted lower bound](examples/debug/v1_review_visuals/ch1.svg)

**Module/function:** `svg_path/convex_hull.minimum_width_optimization_loop`.
**Evidence:** controlled late-stage search reproduced false convergence.

Interval pruning now subtracts the same rounding allowance used by the
convergence check. Thus exhaustion cannot bypass the allowance by discarding
an interval whose adjusted bound is still insufficient. Stored discarded bounds
remain raw and are adjusted at the existing reporting point, not twice.

`node examples/debug/width_pruning_roundoff_regression.mjs` passes four cases
using exact circle support geometry at two scales. It resumes a controlled
late-stage interval with a known bound for previously discarded regions.
A strict request previously reported convergence after discarding its last
interval; it now refines and reports unresolved at the supplied depth limit.
A coarse request still converges immediately. This is a private search-state
regression, not a claim of a newly reproduced public end-to-end hull failure.
Build JavaScript first as described for the other private regression scripts.
The original illustration remains a schematic of the old inconsistency.

### CH2 — hull tangent-root helpers assert success of fallible operations

![CH2 — hull tangent-root helpers assert success of fallible operations](examples/debug/v1_review_visuals/ch2.svg)

**Module/functions:** `svg_path/convex_hull.cubic_point_tangent_roots`,
`refine_polynomial_tangent_isolation`.
**Status:** investigation, not a confirmed reachable crash.

Determine whether exhaustion can occur with the actual inputs and budgets.
Propagate the error if reachable; otherwise document the invariant supporting
the assertion. Do not replace assertions indiscriminately.

## Verification baseline and next work

For SP1 and OF3, `scripts/test-fast` passed **1,559 tests** and
`scripts/test-slow` passed **26 tests**. Formatting and whitespace checks passed.

For OF2 and CH1, `scripts/test-fast` passed **1,554 tests** and
`scripts/test-slow` passed **26 tests**. The width-pruning private regression
passed **four cases**. Formatting and whitespace checks passed.

For PA1 and OF4, `scripts/test-fast` passed **1,553 tests**. The private survivor
provenance regression passed **seven cases**, and the private cusp-empty
regression still passed **17 cases**. Formatting and whitespace checks passed.

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

The remaining intersection search task is **IX2**. IX4's address/deduplication
repair is committed separately. IX3 is a separate classification problem.
The other entries remain available for separate fixes with their own regressions.
