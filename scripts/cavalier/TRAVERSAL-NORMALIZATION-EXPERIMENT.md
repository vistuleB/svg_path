# Pre-offset traversal normalization experiment — 2026-10-20

Baseline `4d1edd2`. Candidate in `offset.gleam`, uncommitted and not validated
for adoption. Public degeneracy behavior is unchanged.

## Candidate

Replace both fixed short-run cleanup and whole-path extent simplification in
`normalize_source_subpath` with:

- Per-segment `segment_linearize_if_degenerate` at absolute tolerance 1e-9.
  Preserve non-flat curves and the ordered line pieces of reversing Béziers.
- Merge adjacent Lines only with shared endpoints, a zero cross product and
  positive dot product in working floating-point arithmetic. No angular
  tolerance; no merging across a reversal or the original closed-path seam.

Existing zero-length source-line cleanup and tangent-alignment stages remain.
The internal `normalize_short_source_runs` helper remains available but is no
longer called by this candidate's production pipeline. Its future removal or
reuse is deferred until the experiment is resolved.

## Focused outcomes

JavaScript reductions (`traversal-normalization-reductions.json`):

| Source x coordinates, all y=0 | Normalized lines | Normalized length | Raw offset length, distance -1 / Round |
| --- | ---: | ---: | ---: |
| -1,0,0.0002,0.0001,0.0003,1 | 3 | 2.0002 | 8.283385307179586 |
| -2,0,1,0.5,2,3 | 3 | 6 | 12.283185307179586 |
| -2,0,1,2,3 | 1 | 5 | 5 |

Erlang independently reproduces the middle row: source and normalized lengths
are 6, and public raw offset length is 6+2*pi. The unchanged public degeneracy
normalizer still returns length 5, confirming the behavioral change is confined
to offset preparation. See `traversal-normalization-erlang.log`.

CC01297 at default fitting tolerance 0.01 now succeeds with length
5639.266054392647 (upstream 5639.2660543910415), instead of straightening the
whole source. This is a property observation, not full boundary certification.

CC01301 source normalizes to six Lines and one Arc at both fitting tolerances
0.01 and 0.00001. Public path offset still fails: newly fitted stalled-run
cubics later trigger `InternalPathError(NonAffineOverlapCorrespondence)` inside
arrangement construction. The trace identifies the same short CubicBezier /
radius-81 Arc pair as before. Pre-offset straightening alone does not prevent
later fitting from reintroducing nonuniform straight-curve parameterizations.

## Separate generated-code control

`prepare-traversal-stalled-control.py` copies the built JS runtime into /tmp.
Its additional control linearizes a fitted stalled-run segment at 1e-9 only if
the helper returns exactly one Line. This change is NOT in production source.
The overlap incompatibility is replaced by a different failure:
`InternalArrangementGraphError(InternalNormalizationError)`. Its cause remains
unisolated. Do not report the original fixture repaired or the control validated.

## Reproduction

```sh
# In test_portable: gleam build --target javascript
node scripts/cavalier/probe-normalization-reversals.mjs
AUDIT_CASE_ID=CC01297 AUDIT_TOLERANCE=0.01 node scripts/cavalier/probe-short-transition.mjs
AUDIT_CASE_ID=CC01301 AUDIT_TOLERANCE=0.00001 node scripts/cavalier/probe-short-transition.mjs
python3 scripts/cavalier/prepare-traversal-stalled-control.py --source-only
AUDIT_JS_BUILD=/tmp/cavalier-traversal-source-only AUDIT_CASE_ID=CC01301 AUDIT_TOLERANCE=0.01 node scripts/cavalier/probe-short-transition.mjs
python3 scripts/cavalier/prepare-traversal-stalled-control.py
AUDIT_JS_BUILD=/tmp/cavalier-traversal-stalled-control AUDIT_CASE_ID=CC01301 AUDIT_TOLERANCE=0.00001 node scripts/cavalier/probe-short-transition.mjs
# In scripts/cavalier/probe: gleam run -m normalization_reversal_probe
```

Captured outputs are `traversal-normalization-*`. Focused probes only, not a full
suite or figure regeneration. Format and diff checks pass. No F# port or commit.
Next: isolate the normalization failure exposed by retaining the reversal before
adopting this pipeline or starting broad regression testing.

## Segment-by-segment graph-input control — 2026-10-20

User requested testing every generated offset segment, rather than only stalled
fits. `prepare-offset-straightening-control.py` copies the current generated JS
runtime and changes only `offset_segment_arrangement` in that copy. Every indexed
segment is independently offered to `segment_linearize_if_degenerate(..., 1e-9)`;
only exactly one Line is accepted. No adjacent merging or multi-Line replacement
is performed at this stage. Matching winding occurrences happens before this
control, preserving occurrence counts. This is a geometry experiment, NOT a
production implementation: the original construction-preimage parameters are
not remapped, so successful geometry would not alone establish correctness.

Restricting it to `UntrimmedOffsetSegment` was insufficient: another non-affine
pair appears in the generated zero-offset side. Including all graph inputs
straightens four offset cubics and four zero-offset cubics in CC01301. Both
fitting tolerances 0.01 and 0.00001 then reach the same normalization failure.
The helper leaves the long radius-81 arcs unchanged.

The failure is now isolated to `certify_segment_edge_geometry`, not ambiguous
vertex selection or inconsistent image bookkeeping. An almost-semicircular arc
has a progressively split edge whose endpoint differs from its original-source
parameter evaluation by **1.755612765130745e-6**, versus certification tolerance
**2e-9**. The diagnostic is reproduced without offsets, arrangements, or cubic
straightening by `probe-offset-arc-reparameterization.mjs` and the Erlang
`offset_arc_reparameterization_probe`:

1. Take the recorded radius-81 arc, sweep -179.99998882125465 degrees.
2. Extract its tail beginning at t=3.011885532211048e-8.
3. Evaluate that reconstructed endpoint-form arc at the local parameter
   corresponding to original t=0.2841409618472.
4. Compare against evaluation of the original arc at that original parameter.

The reconstructed center moves about 2.19e-6. Both targets give the same 1.76e-6
point discrepancy. Direct extraction from the original arc pins the endpoint
correctly; composing splits through the reconstructed tail does not preserve
that equality. This is near-semicircle endpoint-form conditioning, exposed by
progressive arrangement splitting. It is not caused by straightening the arc
(the arc was retained), and raising the certification tolerance would conceal
rather than resolve it. Center-form preservation or rebuilding progressive
pieces from original source intervals are candidates, not tested repairs.

### Checks and results

- `node scripts/cavalier/check-offset-straightening-control.mjs`: **55 passed,
  0 failed**, existing exported offset/stroke/degeneracy/collapsed-offset tests
  from the current portable JS build, run against the copied control. This is
  a diagnostic subset, not `scripts/test-all` or `scripts/test-release`.
- CC01297 still succeeds at default fitting tolerance, length
  5639.266054392647, three output segments.
- CC01301 fails at both tested fitting tolerances with the arc certification
  discrepancy above. No claim of repair.
- Three source traversal/reversal reductions retain their preceding results.
  Their raw-output checks do not exercise arrangement-input straightening.
- Erlang standalone probe confirms the arc discrepancy; the all-segment control
  itself is JS-only. No production straightening, F# port, full suite, figure
  regeneration, or commit in this step.

### Before production adoption

Arrangement-split parameters currently map by linear interpolation into the
immutable H preimage (`arrangement_split_segments_from_i_edge_images`, also the
contamination path). Replacing only indexed graph geometry changes that
parameterization and invalidates this assumption for nonuniform flat cubics.
A production change must either establish the straightened geometry before
those immutable preimages are recorded, or explicitly map new parameters back
to old ones. Do not promote this late-boundary control verbatim.

Reproduce after the portable JS build:

```sh
python3 scripts/cavalier/prepare-offset-straightening-control.py
AUDIT_JS_BUILD=/tmp/cavalier-offset-straightening AUDIT_CASE_ID=CC01301 AUDIT_TOLERANCE=0.01 node scripts/cavalier/probe-short-transition.mjs
AUDIT_JS_BUILD=/tmp/cavalier-offset-straightening AUDIT_CASE_ID=CC01301 AUDIT_TOLERANCE=0.00001 node scripts/cavalier/probe-short-transition.mjs
node scripts/cavalier/check-offset-straightening-control.mjs
node scripts/cavalier/probe-offset-arc-reparameterization.mjs
# In scripts/cavalier/probe:
gleam run -m offset_arc_reparameterization_probe
```

Captured results: `offset-straightening-*.json`,
`offset-straightening-*-trace.jsonl`, `offset-arc-reparameterization.json`, and
`offset-arc-reparameterization-erlang.log`.

## Stage naming follow-up — 2026-10-20

The existing H preimage and I culled stages have been renamed I and J,
respectively, reserving H for straightening. The earlier descriptions above use
the names current when those experiments ran. In particular,
`arrangement_split_segments_from_i_edge_images` is now
`arrangement_split_segments_from_j_edge_images`. This step only renames stages;
it does not implement the proposed straightening representation.

Validation of the stage rename: `scripts/test-release` completed successfully:
2100 ordinary tests, 31 slow tests, 846 portable Erlang tests, and 846 portable
JavaScript tests. See `offset-stage-shift-tests.log`. The run includes the
earlier source-normalization candidate but not generated-offset straightening.
An inverse-rename comparison confirms this step changes only identifiers,
comments, and whitespace in production code. Figures were not regenerated for
this naming-only step. No commit or F# change.

## Production H straightening — 2026-10-20

Implemented the stage before immutable I preimages, not as a late graph-input
rewrite. Assembled healed pieces and joins pass individually through
`straighten_generated_segment`. It uses the existing degeneracy helper at 1e-9
and accepts exactly one Line; otherwise it retains the original segment. It
never merges neighbouring segments or replaces a reversal with multiple lines.
The stage also handles the generated zero-offset side.

`HStraightenedSegment` retains both original and replacement geometry for
inspection. Each I preimage stores that H record, the replacement as its
immutable segment, and the existing healed/join construction provenance.
Downstream J, traced, and arrangement-split parameter intervals refer to this
replacement. Earlier G/E fitting data remains unchanged; it is not claimed to
share the new line parameterization. The preimage-source consumer classifies
reversal using tangent directions and join/stalled provenance, rather than
transferring split fractions back into G. Subsequent trimming narrows I
intervals, so the geometry-only control's correspondence problem is avoided.

Five new portable tests cover nonuniform straight cubics and original retention,
reversing cubics, shallow versus semicircular arcs, point-segment retention, and
a stalled reversal through public raw offset construction. `scripts/test-release`
passed: 2105 ordinary, 31 slow, 851 portable Erlang, 851 portable JavaScript.
The debug survivor-provenance regression also passed all seven cases.

CC01297 remains successful (length 5639.266054392647). CC01301 still reaches
`InternalArrangementGraphError(InternalNormalizationError)` at default fitting
tolerance. The independently isolated near-semicircle reconstruction problem
has not been repaired here. No audit-completion claim or F# port. This work,
including the earlier source normalization and stage rename, is uncommitted.

### Figure-discovered short-line failure

The first canonical figure run stopped with 29/30 Erlang gallery jobs passing;
the nine-offset title failed on level 3 with `DegenerateTangent(0.25)`. The
remaining README and four W3C generators were subsequently run independently.
A copied Erlang control with H disabled failed at precisely the same level.
Restoring the previous source-normalization policy in a copied runtime while
retaining H allowed all nine levels. Thus the failing combination exposed an
issue in retaining short source traversal, not the new H replacement stage.

The isolated offending Line runs from (65.13497199999999, 13.465) to
(65.13497199999999, 13.464999999999996): it is nonzero and has a downward tangent,
but the general curve direction threshold rejects it at t=0.25. A copied-runtime
control computing nonzero Line tangents with scaled endpoint differences and
using their exact zero curvature completed all nine levels. That localized
correction is now in `offset.unit_tangent` and `offset_direction`. Exact point
lines keep their prior failure; no small-length deletion rule was added.
The sixth new test checks both directions, four parameters, exact-point failure,
and a public raw offset containing that short segment.

The JavaScript title probe exceeded the default Node stack before producing its
first level in both H-enabled and H-disabled controls; those runs do not certify
this figure. The decisive controlled comparison used Erlang, matching the
published figure generator. Existing portable tests are separately rerun on both
targets. Scripts and raw Erlang controls are `probe-h-title-offsets.escript`,
`prepare-h-title-controls.py`, and `h-title-*-erlang.log`.

### Final verification

With the short-Line correction, `scripts/test-release` passed **2106 ordinary,
31 slow, 852 portable Erlang, and 852 portable JavaScript** tests. The seven-case
survivor-provenance script passed again after the final build.
`scripts/generate-published-figures` completed successfully: **34 Gallery and
13 README** figures regenerated, including all nine title offsets. It also ran
its required ordinary test suite successfully. Logs:
`h-straightening-tests-final.log`, `h-straightening-figures-final.log`.

Compared with the saved pre-H working figure outputs, 41/47 are byte-identical.
The Gallery recursive dashes, first title offset, second title arrangement, and
nine title offsets changed geometry/serialization. These comparisons include
the earlier source-normalization candidate (its figures had not previously
been regenerated), so changes must not all be attributed to H alone.
The two README miter-clip figures have identical nonnumeric text/token structure;
the largest numeric difference is 8.881784197001252e-16. Figure hashes and preview
paths are in `h-straightening-figure-comparison.json`. Before/after SVG previews
are under `examples/debug/h-straightening-*.svg`. Other existing worktree figure
changes were preserved; comparison was against pre-experiment files, not HEAD.

CC01301's separate near-semicircle reconstruction failure remains open.
No commit, F# port, or release preparation was performed.
