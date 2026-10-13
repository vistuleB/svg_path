# Boundary classification investigation: 79 and 113

The subsequent implementation and current validation are recorded in
[FACE_WINDING_FIX.md](FACE_WINDING_FIX.md). The sampling instrumentation below
requires the historical `911ba22` source; the standalone reductions now pass.

Historical investigation against production after `911ba22`, 2026-10-13. No production code
was changed during that investigation. Private exports and displacement overrides exist only in temporary
compiled JavaScript copies. This is evidence and a repair proposal, not an
implemented or release-validated change.

## Cause separated from the earlier tolerance experiment

The CSG classifier uses containment tolerance `t` and side displacement `16*t`.
The investigation varies these independently on the **same constructed graph**.
Both original graphs pass `validate_closed_boundaries`.

| Containment tolerance | Side displacement | 79 selected / imbalanced vertices | 113 selected / imbalanced vertices |
| --- | --- | --- | --- |
| 1e-6 | 16e-6 | 14 / 4 | 5 / 2 |
| 1e-9 | 16e-6 | 14 / 4 | 5 / 2 |
| 1e-6 | 1.6e-6 | 12 / 0 | 4 / 0 |
| 1e-8 | 1.6e-7 | 12 / 0 | 4 / 0 |
| 1e-6 | 1.6e-7 | 0 / 0 | 0 / 0 |

All 16 tolerance/displacement combinations per fixture are saved in
`boundary-classification-investigation.json`. Reducing containment tolerance
alone does not fix the failure. Reducing displacement alone does. Reducing it
below containment tolerance instead drops every boundary edge: balance alone
is not evidence of correctness.

The point-containment queries are answering the points they were given. The
problem is using those displaced points as if they represented the immediately
adjacent faces of the edge. Independent Paper.js containment observations at
the saved sample points agree with the local/far-side changes.

### Fixture 79

Near-coincident curved boundaries enclose narrow regions. Graph edges 6 and 18
are internal to the union, but a 16e-6 step crosses the neighboring operand's
boundary, so both are incorrectly retained. Levels also change on edges 11 and
15, although those edges remain selected under union. At 1.6e-6 the probes stay
local and only the correct twelve boundary edges remain.

### Fixture 113

Graph edge 0 is a short shared piece with opposite source orientations. Its
length is approximately 1.39e-5. The correct per-operand side levels are
A=(0,1), B=(1,0), so intersection must omit this edge.

The default displacement yields A=(1,1), B=(1,0), retaining it incorrectly.
The left normal probe crosses A's closing straight edge approximately
1.495e-5 units from the midpoint, before reaching the configured 1.6e-5 offset.
The smaller 1.6e-6 probe remains on the immediately adjacent face.

`examples/debug/boundary_classification_113.svg` illustrates the actual inputs
and recorded sample locations near this shared vertex.

## Minimal expected-success regressions

Both use only `Line` segments; neither requires cubic parameterization,
root-finding recovery, nor an ambiguous expected shape. Arrangements pass
closed-boundary validation at the default 1e-6 tolerance and 1e-5 minimum length.

1. **Nested triangles.** A has vertices `(0,0), (1,1), (0,2)`; B replaces the
   middle vertex with `(1.00004,1)`. A is contained in B. Their union must be B,
   of area **1.00004**. Production returns `InternalBoundaryTopologyError`.
2. **Thin triangles sharing an edge.** A has vertices
   `(0,0), (0,-0.00004), (-1,-1)`; B has
   `(0,-0.00004), (0,0), (1,-1)`. Their interiors are disjoint, and each has area
   0.00002. The union must have area **0.00004**. Production returns
   **`Ok(Path([]))`**, silently losing both nonempty regions.

These are reductions of the sampling mechanism, not assertions that the second
pair is a literal subpath deletion of fixture 113. The second is a stronger
counterexample to accepting any balanced selected-boundary result.

`test_paperjs/src/paper_boundary_classification_regressions.gleam` holds both
expected-success checks. On **both Erlang and JavaScript**, graph validation
succeeds, both production expectations fail, and the final assertion deliberately
fails after printing both results. This executable remains outside the ordinary
passing test profiles while the bug is unfixed. It does not assert that the
current failures are correct behavior.

## Two isolated experiments

### Change only displacement

Keeping containment tolerance at 1e-6 and changing only displacement to 1.6e-6
lets both original complete operations return sampled geometry matches:

- 79: maximum sampled boundary distance `2.2361e-5`, no fill mismatches.
- 113: maximum sampled boundary distance `4.0538e-6`, no fill mismatches.

The reduced unions also have their expected areas. This localizes the cause;
it is **not** a recommendation to replace 16 with 1.6 globally. Smaller geometric
features can still defeat any fixed multiplier.

### Reuse the existing dual and face-winding engine

The repository already provides `arrangement.dual` and
`arrangement.face_windings`. The latter propagates winding changes from the
infinite face without displaced containment probes. The CSG arrangement build
also retains each source segment's oriented edge images.

The diagnostic:

1. Derives the unchanged graph's dual.
2. Sums forward-minus-reverse source occurrences for **each operand separately**
   on every edge. It counts all occurrences; `own` is not a winding multiplicity.
3. Calls `face_windings` once per operand.
4. Combines the resulting face-fill states for union/intersection and feeds the
   selected, oriented edges to the existing CSG boundary pairing and tracing.

For **both original fixtures**, dual construction and winding propagation
succeed. All derived edge levels exactly match the smaller-displacement
reference, and tracing produces closed paths. Comparing the traced paths with
upstream expected geometry gives the same sampled distances and no fill
mismatches as above; see `boundary-dual-experiment-screen.json`.

For both line-only reductions, the prototype yields the exact expected union
areas to within 1e-12. The native executable independently exercises public
arrangement construction, dual construction and per-operand winding propagation
on Erlang and JavaScript and checks the area integral of the selected boundary.
Native checks here are area/topology evidence for the reductions, not full
native CSG repairs or a native upstream geometry screen.

## Recommendation

Use the existing dual and per-operand winding propagation to classify binary
CSG boundaries. This addresses the geometric cause and reuses established
machinery, without adding a new displacement tuning parameter or changing edges.
Simply enforcing balanced output, reducing the multiplier, or retrying only on
an error would miss the silent empty-union counterexample.

Before adoption:

- Preserve implicit closing-segment provenance when splitting the source
  inventory into operands; do not infer ownership from aggregate multiplicity.
- Check union, intersection, difference and symmetric difference with both fill
  rules, opposite traversals, repeated source occurrences, self intersections,
  holes, disconnected components and empty operands.
- Preserve explicit errors when dual certification or winding propagation is
  inconclusive/inconsistent. Successful propagation presupposes a correct dual;
  it does not itself prove the embedding's correctness.
- Run the complete release suite, all saved Paper.js comparisons and published
  figure regeneration. Dual certification can reject graphs currently accepted
  by the sampled classifier, so wider compatibility is not yet established.

No production edit, commit, full-suite run or figure regeneration was performed
for this investigation. The current audit disposition table remains unchanged.

## Reproduction

```sh
(cd test_paperjs && gleam build --target javascript)
node scripts/paperjs/investigate-boundary-classification.mjs --screen
# These two commands intentionally exit nonzero until production is fixed:
(cd test_paperjs && gleam run --target erlang -m paper_boundary_classification_regressions)
(cd test_paperjs && gleam run --target javascript -m paper_boundary_classification_regressions)
```

The JS screen uses pinned Paper.js 0.12.18 at
`/tmp/svg-path-paper-audit/node_modules/paper`. Full raw native diagnostic output
is retained in `boundary-classification-native-results.json`.
