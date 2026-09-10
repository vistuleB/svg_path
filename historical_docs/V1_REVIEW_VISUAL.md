# Remaining audit findings — visual explanation and recommendations

> Historical record. Status, commands, and code locations below describe their
> original checkpoints, not current main. See [the archive index](README.md)
> and [current follow-ups](../REMAINING_ISSUES.md).

Baseline: `ddad3c4`, after the nine correctness fixes and three documentation
fixes listed in [V1_REVIEW_ACTIONABLE.md](V1_REVIEW_ACTIONABLE.md).
The complete audit history remains in [V1_REVIEW.md](V1_REVIEW.md).

## How to read this document

Every remaining finding has an illustration below. Some are actual geometry;
others are explicitly labeled explanatory diagrams because there is no
confirmed geometric reproducer. **A diagram is not evidence that an
unreproduced failure occurs.**

- **Blue:** source/reference geometry. **Red:** current problematic result.
- **Green:** expected geometry or a comparison, identified in each caption.
- **Black AG edges and vertices:** taken from actual arrangement build data.
- Several close-ups deliberately exaggerate one coordinate; their captions
  say so. SVG path coordinates use system precision, not rounded five-decimal
  output. Every figure has explicit dimensions and a full-viewBox white
  background as its first element.
- The experimental variants modify compiled JavaScript **only in memory**.
  They do not modify `.gleam` source or installed/generated production modules.
  They are diagnostic experiments, not verified production patches or an F# port.

Reproduction files:

- [`examples/debug/v1_review_visuals.mjs`](../examples/debug/v1_review_visuals.mjs)
  gathers current production results and generates the illustrations.
- [`observations.json`](../examples/debug/v1_review_visuals/observations.json)
  contains the production observations used for the figures.
- [`examples/debug/v1_review_experiments.mjs`](../examples/debug/v1_review_experiments.mjs)
  contains the isolated candidate changes.
- [`experiments.json`](../examples/debug/v1_review_visuals/experiments.json)
  records their results. These probes are not permanent regression tests.

## 1. DE1 — a flat step hides a longitudinal reversal

**Module:** `svg_path/degeneracy`. **Functions:** [axial_protrusion_points_loop](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/degeneracy.gleam:240), [normalize_degenerate_segments](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/degeneracy.gleam:49).

![DE1](../examples/debug/v1_review_visuals/de1.svg)

The source goes from x=0 to x=10, moves vertically by 0.0001, then comes back
to x=1. At tolerance 0.001, the normalizer returns only the line from 0 to 1.
The issue is not the transverse displacement: the missing excursion is nine
units long. The left panel exaggerates y so the intervening step is visible.

The turn detector multiplies consecutive axial changes. Their signs are
positive, zero, negative; neither adjacent product is negative. The intervening
zero masks the reversal.

**Experiment:** carrying the preceding nonzero change through the flat step
returns `M 0 0 L 10 0.0001 L 1 0`. Two consecutive flat steps also preserve
x=10. A flat step followed by continued forward motion still simplifies.

**Recommendation:** adopt plateau-aware turning detection, preserving the
original start/end anchors and the selected plateau endpoint. Add reversed,
initial-plateau, terminal-plateau and multiple-reversal cases. This is now a
specific, promising fix; no deletion of zero-length source segments is needed.

## 2. AG2 — common endpoints do not exclude another crossing

**Module:** `svg_path/arrangement`. **Functions:** [progressive_compare_edge](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/arrangement.gleam:2674).

![AG2](../examples/debug/v1_review_visuals/ag2.svg)

The cubic and line share their two endpoints **and** cross at their midpoint.
The arrangement builder skips intersection detection once both endpoint
vertices match, so the actual graph has two vertices and two unsplit edges.
The green midpoint is established by the ordinary line/curve intersection
solver, not by a visual guess.

**Experiment:** removing only that endpoint-match shortcut gives three
vertices and four edges. The crossing vertex is approximately
`(0.500000000269, -3.36e-11)`, consistent with the configured tolerance.

**Recommendation:** remove the shortcut. Structural identity or certified
overlap can justify combining images; shared endpoints alone cannot. Test
identical/reversed duplicates and lens-shaped nonintersecting pairs as well
as this crossing. This repair works on the focused example without a new
topological algorithm.

## 3. AG3 — an individual input segment may self-intersect

**Module:** `svg_path/arrangement`. **Functions:** [build](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/arrangement.gleam:2020), [progressive_compare_edge](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/arrangement.gleam:2674).

![AG3](../examples/debug/v1_review_visuals/ag3.svg)

The self-intersection solver finds the crossing at t=0.25 and t=0.75. The
builder nevertheless inserts the entire cubic as one edge. It compares new
segments with existing geometry, but does not split one segment at its own
self-intersection first.

**Experiments:** splitting at the crossing parameters creates a middle portion
whose endpoints coincide. The existing minimum-chord filtering drops that
entire loop. Adding a split at its midpoint preserves the loop as two edges:
the resulting graph has four vertices and four edges.

**Recommendation:** self-intersection splitting must include a plan for
nontrivial closed portions. Merely adding self-intersection parameters is
insufficient. Either support self-loop edges throughout, or deliberately split
closed portions again while preserving their source intervals. I prefer the
latter as the narrower compatibility fix for the present graph contract, but
it should be discussed before implementation.

## 4. IX2 — finding a root is not a proof that its window is finished

**Module:** `svg_path/intersections`. **Functions:** [window_preserving_window_already_resolved](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/intersections.gleam:4655).

![IX2](../examples/debug/v1_review_visuals/ix2.svg)

The cubic has y=`(t−0.2)(t−0.21)(t−0.22)` and x=t. All three crossings exist.
Representing the horizontal curve as a Line finds all three; representing the
same geometry as a Quadratic selects the generic search and returns only one.
Both panels show a local window with y magnified.

Two termination rules are implicated: a candidate ends its current window,
and an existing hit suppresses nearby windows within a margin based on their
width. Neither establishes that there is only one root there.

**Experiment:** disabling the neighborhood exclusion recovers neighborhoods
of all three roots, but gives four answers: two approximations near t=0.2.
For roots 0.2, 0.21, 0.8 it returns three answers. Simply removing the shortcut
is therefore not a sufficient fix.

**Recommendation:** separate root refinement/deduplication from window
exhaustion. Continue searching the residual window unless uniqueness or
exclusion has been established. Preserve distinct parameter pairs, but refine
duplicate candidates before merging them. This is a solver correction, not an
opportunity to tune the exclusion constant until this fixture passes.

## 5. IX3 — parallel tangents can occur at a true crossing

**Module:** `svg_path/intersections`. **Functions:** [classify_directions](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/intersections.gleam:1897).

![IX3](../examples/debug/v1_review_visuals/ix3.svg)

The cubic y=`(t−0.5)^3` crosses the line at t=0.5. Their first derivatives are
parallel there. The current classification is `Touching`, because the
equal-direction branch treats that as decisive.

**Recommendation:** keep the public names topological: this is a crossing.
Use a higher-order/local separation test when tangent directions coincide;
the first nonzero signed separation term distinguishes this odd-order crossing
from an even-order touch. Do not classify unresolved near-coincidence by first
derivatives alone. No classification repair was implemented in this session.
The general fallback needs care for endpoint and overlap cases.

## 6. IX4 — geometrically equal hits can carry different addresses

**Module:** `svg_path/intersections`. **Functions:** [insert_intersection](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/intersections.gleam:6318).

![IX4](../examples/debug/v1_review_visuals/ix4.svg)

The closed cubic meets the horizontal line at its start and end. These are
the parameter pairs `(0,0.5)` and `(1,0.5)`. Current deduplication merges them
because their point positions agree, returning only the first pair.

**Experiment:** parameter-pair-only deduplication returns both pairs.

**Recommendation:** preserve distinct parameter pairs in the segment
intersection result. A graph vertex may subsequently unite their positions,
but must retain both occurrences. Document this explicitly. Combine its tests
with IX2 so fixing repeated addresses does not also admit duplicate numerical
approximations of a single pair.

## 7. AG1 and OF8 — a proposed interior point can land inside the wrong region

**Module:** `svg_path/arrangement`. **Functions:** [dual_face_walk_sample](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/arrangement.gleam:1182).

**OF8 module:** `svg_path/offset`. **Functions:** [outline_contour_probe](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/offset.gleam:6722), [orient_outline_path](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/offset.gleam:6640).

![AG1 and OF8](../examples/debug/v1_review_visuals/ag1_of8.svg)

The actual squares have side 10 and an inset of 0.00001. A trial displacement
of chord×0.0001 is 0.001: one hundred times the gap. It can cross the inner
boundary before being classified. The right panel illustrates this scale;
the trial point is explanatory, not a captured private probe.

Two independent failures are confirmed:

- **AG1:** arrangement build succeeds, but construction of its dual returns
  `ConstructionFailed`.
- **OF8:** `orient_outline_path` gives both contours negative signed area
  (`−100`, `−99.99960000040001`) instead of opposite orientations. This test
  bypasses the arrangement dual, so fixing AG1 alone will not fix OF8.

**Recommendation:** choose a sample within the local region, checking the
path from the boundary to the sample for another boundary crossing. Both
consumers need awareness of other contours. A smaller universal fraction only
moves the failure to narrower gaps. A nearest positive crossing along the
chosen normal is one practical way to bound the step, provided intersection
errors are propagated rather than ignored. No production sampling change made.

## 8. OF1 — zero offset exposes a capacity/provenance mismatch

**Module:** `svg_path/offset`. **Functions:** [forced_parity_capacities](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/offset.gleam:11408).

![OF1](../examples/debug/v1_review_visuals/of1.svg)

For a zero offset, the source and offset images occupy the same edges. The
default closed-square offset fails with `ConstructionFailed`. Reconstruction
can consume one offset occurrence, but the starting capacity includes the
coincident source occurrence too. The leftover capacity triggers the check.

**Experiment:** forcing unit initial capacities makes this square succeed at
offset 0 and 0.1. This only diagnoses the mismatch: **unit capacity is not a
valid general replacement**, because repeated eligible offset occurrences
really can require larger capacities.

**Recommendation:** initialize reconstruction capacity from eligible offset
preimages, independently of the complete preimage inventory used for winding.
Keep the all-capacities-consumed assertion; it caught a useful bookkeeping
error. Do not special-case zero offset to evade the assertion.

## 9. OF2 — a corner at the closing seam is not classified like other corners

**Module:** `svg_path/offset`. **Functions:** [split_join_free_portions](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/offset.gleam:2472), [mark_closed_join_free_portion](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/offset.gleam:8947), [synchronized_join_correspondences](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/offset.gleam:6363).

![OF2](../examples/debug/v1_review_visuals/of2.svg)

Both panels use exactly the same closed source geometry. Only the initial
segment address changes. Starting at the corner makes +0.1 untrimmed Round
offset fail with a closing gap of about 0.141421. Starting at the other junction
succeeds; the green curve is that actual successful output.

The linear pass checks consecutive boundaries but not the wraparound boundary.
A sole join-free portion is then marked closed, and no join is made there.

**Recommendation:** include the cyclic seam in the smooth/corner partition.
A single open portion around a closed source can need a join from its end
back to its own start; “only one portion” must not mean “no join.” Test cyclic
rotations of every segment list. No proposed implementation was substituted
into production during this presentation exercise.

## 10. OF3 — the closing alignment edit to the first segment is discarded

**Module:** `svg_path/offset`. **Functions:** [colinearize_source_tangent_policy](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/offset.gleam:4834).

![OF3](../examples/debug/v1_review_visuals/of3.svg)

The first cubic's control1 is `(1,0.01)`. When it occurs at the seam, this is
left unchanged; rotating the source changes it to `(1.0000499987500624,0)`.
The panels show actual normalized control points, with y exaggerated.

The boundary alignment routine produces edits to both neighbors. The closing
Custom policy returns only the last segment, because the current rebuild
closure API preserves the first segment and appends a tail replacement.
Returning both neighbors there would append the first segment again; that is
not a valid fix.

**Experiment:** explicitly applying the existing boundary routine to the last
Line and first Cubic with its normal 2° tolerance produces the desired first
control point while leaving the Line unchanged.

**Recommendation:** make source alignment a genuinely cyclic pair pass that
can retain both edits, or explicitly handle this seam before ordinary rebuilding.
Do not change the public Custom closure contract incidentally. This is separate
from OF2, although both should share cyclic-rotation regressions.

## 11. OF4 — reversed geometry retains an unreversed interval

**Module:** `svg_path/offset`. **Functions:** [reverse_survivor_edges](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/offset.gleam:4630).

![OF4](../examples/debug/v1_review_visuals/of4.svg)

This diagram uses illustrative H parameters. The concern is that a reversed
survivor still carries an ascending interval identifying the old traversal.
Subsequent local-to-preimage mapping can therefore associate its start with
the wrong source endpoint.

**Experiment:** invoking the real private `reverse_survivor_edges` on a
constructed survivor reverses its Line but leaves the supplied `[0.2,0.7]`
preimage metadata unchanged. The downstream cusp conversion copies those fields.
There is still no end-to-end public cusp fixture demonstrating the consequence.

**Recommendation:** carry a directed interval or an explicit orientation
through this conversion. Apply the orientation exactly once when composing
parameters. Do not flip the independent geometric `REVERSED` classification
merely to represent reversed traversal.

## 12. OF5 — empty output depends on when it became empty

**Module:** `svg_path/offset`. **Functions:** [finish_cusp_trim_with_parity](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/offset.gleam:5635).

![OF5](../examples/debug/v1_review_visuals/of5.svg)

The cusp finisher returns `Ok(None)` if nothing was retained before parity
reduction, but reports `InternalIToKSubpathCount(0)` if parity removes everything.

**Experiment:** provide the private finisher with a valid square graph and its
original closed traversal, then retain just one of its edges. Parity burns the
remaining edge, and the function returns exactly that count-zero error. This
is a controlled internal-state test, not a claim that winding/rescue produces
that state for a particular public band fixture.

**Recommendation:** treat zero reconstructed chains as `Ok(None)` after parity
too. Retain the error for more than one chain and the checks on a sole chain's
closure/endpoints. The optional-result contract is the reason for this change.

## 13. OF6 — signed tangent constraints require rays, not infinite lines

**Module:** `svg_path/offset`. **Functions:** [stalled_start_control2](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/offset.gleam:10483), [stalled_end_control1](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/offset.gleam:10523).

![OF6](../examples/debug/v1_review_visuals/of6.svg)

The synthetic private-fit request has a collapsed start handle and asks to
leave the start toward the upper left. The returned second control point is
`(1,1)`, which makes the one-sided start direction point lower right instead.
The unsigned handle length and infinite-line intersection checks accept it.

These are the actual returned handle and resulting cubic, not a fabricated
full offset. There is no end-to-end offset reproducer in this report.

**Recommendation:** check same-direction collinearity, including the limiting
one-sided direction at collapsed handles. Reject the candidate or continue the
existing fallback when it lies on the wrong ray. Apply the same validation to
the bisection fallback; a zero cross product alone cannot establish direction.
Surface the existing fitting failure if no valid candidate is found.

## 14. PA1 — drawing after closepath is rejected

**Module:** `svg_path/parse`. **Functions:** [parse_close](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/parse.gleam:636), [ensure_active](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/parse.gleam:763).

![PA1](../examples/debug/v1_review_visuals/pa1.svg)

`M0 0L1 0ZL2 0` is rejected at the final L with `ExpectedMove`. The right panel
illustrates the specified continuation, not current parser output. Closepath
returns the current point to the subpath start; a following drawing command
can begin a new subpath there.

**Recommendation:** distinguish “a current point exists” from “an active
subpath is accumulating segments.” Start a continuation when a drawing command
arrives after Z, using that current point. Test relative commands, repeated Z,
and smooth commands whose previous-control state must have reset. This does
not require new geometry algorithms, but it is more than deleting a validation.

## 15. SP1 — directions outside [0,1] inherit a reversed split-child orientation

**Module:** `svg_path`. **Functions:** [segment_directions_with](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path.gleam:2978).

![SP1](../examples/debug/v1_review_visuals/sp1.svg)

The line x=10t points right for increasing t everywhere. At t=−1, current code
returns a leftward incoming direction; at t=2, the outgoing direction is
leftward. The split representation has reversed one child's parameterization.

**Experiment:** obtain a locally increasing-parameter portion around t and
query its interior direction. This returns rightward incoming and outgoing
directions for both test parameters.

**Recommendation:** derive extrapolated one-sided directions from a local
increasing-parameter neighborhood or the appropriate derivative limits, not
from pieces anchored to the original 0 and 1. Preserve the current endpoint
and stationary-point behavior inside the interval. The neighborhood prototype
is evidence for the diagnosis, not a finished Arc/extrapolation policy.

## 16. TS1 — serialization drops shear without requested decimal rounding

**Module:** `svg_path/transform/serialize`. **Functions:** [analyze_rotation_scale](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/transform/serialize.gleam:201), [close_to_zero](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/transform/serialize.gleam:295).

![TS1](../examples/debug/v1_review_visuals/ts1.svg)

The input maps `(0,1)` to `(0.000001,2)`. Its serialized rotate/scale form maps
that point to x=0. Horizontal exaggeration makes the discrepancy visible.
The decomposition recognizer accepts near-orthogonal axes using 1e-6 even when
the requested decimal setting is `None`.

**Experiment:** tightening that recognizer to 1e-12 selects
`matrix(2 0 0.000001 2 0 0)` and retains the shear.

**Recommendation:** verify any compact decomposition against the original
matrix at a small, explicit floating-point allowance; otherwise emit `matrix`.
The recognizer should not introduce a separate 1e-6 loss unrelated to requested
rounding. The trial constant demonstrates the fix direction, but coefficient
reconstruction is the clearer final acceptance test.

## 17. ST1 — a visible dash of length zero can still draw a cap

**Module:** `svg_path/stroke`. **Functions:** [dash_start](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/stroke.gleam:857), [dash_intervals_loop](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/stroke.gleam:873).

![ST1](../examples/debug/v1_review_visuals/st1.svg)

The `[0,2]` dash pattern at width 1 with Round caps should produce discs at
positions 0, 2, 4 on this five-unit line. The current API returns an empty Path.
Green discs illustrate the requested result; the right-hand grey line is only
a source guide.

**Recommendation:** preserve zero-length visible dash events, separately from
positive-length intervals if needed. Cap construction then determines their
geometry. Avoid feeding a zero interval into unrelated curve-offset machinery.
Test Butt (no visible disc), Round, Square, phase shifts and endpoint events.
Do not coalesce `[1,0]` into a solid stroke as part of this fix: that was examined
and is not the same issue.

## 18. AD1 — annotation samples and containment disagree on tolerance

**Module:** `svg_path/arrangement/drawing`. **Functions:** [annotated_edge_things](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/arrangement/drawing.gleam:134).

![AD1](../examples/debug/v1_review_visuals/ad1.svg)

The annotation helper samples at 16 times its supplied tolerance but calls
containment with its default tolerance. At drawing tolerance 1e-12, both sample
points are within the default 1e-9 boundary band.

**Experiment:** the same winding helper used by drawing returns `(1,1)` on a
square edge with default containment options, and `(0,1)` with containment
tolerance 1e-12. This upgrades the earlier static concern to a reproduced
helper-level labeling problem; it does not alter the AG itself.

**Recommendation:** pass matching containment options, as the CSG fix already
does. Add a regression for labels or the exact side-level query. This looks like
a small, well-defined next fix.

## 19. CH1 — a conservative bound must be used before discarding intervals

**Module:** `svg_path/convex_hull`. **Functions:** [minimum_width_optimization_loop](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/convex_hull.gleam:1132).

![CH1](../examples/debug/v1_review_visuals/ch1.svg)

The optimizer subtracts its rounding allowance when reporting a lower bound,
but prunes using the raw bound. If no intervals remain, it reports convergence
without the same allowance. The diagram shows the logical mismatch using
symbolic values, not an observed hull result.

**Recommendation:** use the adjusted bound consistently for pruning and
convergence, matching the previously repaired decision search. Before merging
a patch, construct a targeted test of this branch or an ordinary geometric
counterexample. The code-level inconsistency is clear; its practical failure
frequency remains unmeasured. No public failing fixture found in this session.

## 20. CH2 — unchecked root-solver errors

**Module:** `svg_path/convex_hull`. **Functions:** [cubic_point_tangent_roots](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/convex_hull.gleam:2963), [refine_polynomial_tangent_isolation](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/convex_hull.gleam:3027).

![CH2](../examples/debug/v1_review_visuals/ch2.svg)

Some hull tangent-root helpers assert `Ok` on fallible root operations. This
alone does not establish a reachable crash: their inputs and iteration budget
might make the error cases unreachable in practice.

**Recommendation:** do not label this a confirmed bug yet. Check whether the
caller can reach exhaustion; if yes, propagate it through the hull error type.
If a mathematical invariant rules it out, document that invariant. I would
defer code changes rather than replace assertions indiscriminately.

## 21. OF7 — apparently unreachable fitting alternatives

**Module:** `svg_path/offset`. **Functions:** [e_join_free_endpoint_policy](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/offset.gleam:9993), [fit_offset_cubic_data_with_endpoint_policies](/Users/jpsteinb/github.com/vistuleB/svg_path/src/svg_path/offset.gleam:10152).

![OF7](../examples/debug/v1_review_visuals/of7.svg)

The current endpoint-policy producer does not emit `FitPositionOnly`, while
the private fitting dispatcher and a direction consumer retain branches for it.
Two collapsed-handle branches appear to use a least-squares formula for a
different control-point placement than the cubic subsequently constructed.

**Recommendation:** verify the complete call graph, then remove the unused
variant and branches instead of repairing dormant fitting formulas. The
remaining active collapsed-handle direction paths are still needed. OF7's
separate documentation corrections were already committed in `ddad3c4`.

## Recommended sequence

1. **Small, now better-supported repairs:** DE1, AG2, AD1, OF5; then OF3 and
   OF4 with focused provenance/cyclic-boundary tests.
2. **Keep solver changes together:** IX2 and IX4; review IX3's local-contact
   semantics explicitly rather than folding it into a tolerance adjustment.
3. **Topology and region selection:** AG3, AG1/OF8, OF1 and OF2. Each has a
   specific proposed direction, but broader invariants need regression coverage.
4. **Independent API behavior:** PA1, SP1, TS1 and ST1.
5. **Fitting and unresolved concerns:** OF6 needs active-path validation;
   remove OF7 only after reachability checks. CH1 needs a focused failure;
   CH2 remains an investigation item, not a confirmed defect.

AG5 was already documented and requires no fix. The agreed implicit fill
closure contract behind CL1 is not reopened here.

## Reproduction and verification

Build the production JavaScript modules from this checkout, then run the two
scripts from the repository root:

```shell
cd examples/public_api_smoke
gleam build --target javascript
cd ../..
node examples/debug/v1_review_visuals.mjs
node examples/debug/v1_review_experiments.mjs
xmllint --noout examples/debug/v1_review_visuals/*.svg
```

Both scripts completed on the stated baseline. All 21 generated SVGs passed
XML validation. No production source files were changed; the experiments are
deliberately isolated and include diagnostic changes that must not be shipped
as-is. The normal and slow test suites were not rerun for this presentation
work. Every proposed production change still needs its own regression tests.
