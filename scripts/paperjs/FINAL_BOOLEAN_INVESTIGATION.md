# Remaining Boolean discrepancies: 107, 122 and 123

Investigated against production after `d2f949a`, 2026-10-13. Production code is
unchanged. All three cases expose a shared **overlap-candidate merging defect**.
This is the pre-fix investigation; see [the subsequent repair](FULL_OVERLAP_FIX.md)
for production changes and validation. Temporary experiments are not a release.

## Shared cause

Overlap detection independently accepts a full-domain affine correspondence,
plus nearly identical endpoint-projection proposals. Merging those proposals
reports a contradiction in parameter space. `detect_with_samples` then turns
that contradiction into `Ok([])`, throwing away the valid continuous overlap.
Point-intersection processing consequently operates on coincident curve pieces.

This is distinct from the understood `NonAffineOverlapCorrespondence` cases:
these inputs have valid affine correspondences that the detector itself accepts.

For the first conflicting pair reached by 122/123, reversed corresponding
control points differ by at most **8.4572e-12**. For a pair reached by 107, the
same-direction bound is **1.7054e-12**. The tolerance is **5e-7**. The convex-hull
property of the difference of two cubics bounds their distance at every paired
parameter by that control-point bound. Both witnesses have monotone control
projections, so neither requires multiple traversal branches.

`final-boolean-affine-bounds.json` uses 80-digit Decimal arithmetic on the exact
binary64 controls. It also records other observed conflicts: two are partial
interval pairs, whose *whole-segment* bounds exceed tolerance. Those entries
are not claimed as full-domain overlap proofs. The first three 122/123 conflicts
and the recorded 107 witness suffice to demonstrate lost valid full overlaps.

## 107: repeated expensive intersection work

An instrumented 60-second JavaScript run completed 93 pair queries taking over
100 ms each (most roughly 0.6 seconds) before a diagnostic watchdog stopped it.
This is repeated finite work, not evidence of an infinite loop. Stack capture
places these calls in arrangement's `pair_cuts_with_common_endpoint_sliver`.
The profile includes curve-pair search and `spatial_diversity_pass`.

One recorded overlap candidate list contains a valid `(0,1) -> (0,1)` map and
a microscopic reverse proposal `(0.999999996740371,1) ->
(1,0.999999996740371)`, as well as slightly different forward endpoint maps.
The merger discards the entire collection. Removing just short proposals in a
temporary experiment did not resolve the timeout; the near-duplicate forward
maps matter too.

### Reduced public-API counterexample

A vertical cubic with x=736 and successive y controls

```
337.7804798720905
337.780485777646
337.7804916832015
337.780497588757
```

is monotone and nondegenerate. `overlaps.segment_with(curve, curve,
tolerance: 5e-7)` returns **`Ok([])`**. Subtracting the first y coordinate from
all four controls restores the expected full `(0,1) -> (0,1)` overlap.
Both Erlang and JavaScript reproduce this. Unlike the full CSG timeout, this
is a small direct correctness failure under our own overlap contract.

## 122/123: why filtering and clustering were downstream symptoms

These fixtures share operands; 122 is union, 123 intersection.

At default options, the build drops a connector with length upper bound
**4.4759954e-6**, below the configured `minimum_length=1e-5`. Face propagation
then reports `ContradictoryWinding(edge_id: 14, face_id: 4, assigned: 0,
required: -1)`; CSG surfaces `ConstructionFailed`.

At minimum length 1e-7 or 1e-9, no piece is dropped, but insertion rejects an
ambiguous endpoint in `unique_vertex_for_endpoint_loop`:

- Endpoint `(243.02910442051652, 272.45351777540037)` is within tolerance 1e-6
  of two cluster centers: distances **8.4592e-7** and **9.6838e-7**.
- The centers are **1.8143e-6** apart. Their combined samples span at least
  **3.4374e-6**, so merging both complete clusters cannot preserve radius 1e-6.
- The guard returns `InternalNormalizationError`, publicly `ConstructionFailed`.

Both full operations reproduce the default and lowered-minimum errors on
Erlang and JavaScript. A JavaScript trial lowering both tolerance and minimum
length to 1e-7 instead reaches `OverlappingSegments`; it is not a workaround.

These mechanisms explain the immediate errors, but are **not sufficient to
classify the original cases as harmless configuration limitations**. Preserving
the valid full overlaps in a temporary build makes both operations complete
at their original defaults. Incorrect overlap handling caused unnecessary
intersection cuts leading to those filtering/clustering failures.

## Isolated causal experiment

A temporary compiled copy prefers an already-accepted exact full-domain
candidate when present, before merging. It changes no tolerances or geometry.
It does not bypass non-affine rejection. This deliberately narrow experiment
is **not a proposed unconditional production rule**: a repair must preserve
legitimate additional parameter branches and partial overlaps.

| Fixture | Production observation | Temporary experiment, complete CSG | Maximum sampled boundary distance |
| --- | --- | ---: | ---: |
| 107 | 30 s screening timeout; diagnostic stopped after 60.6 s | 3.66 s | 4.5336e-6 |
| 122 | `ConstructionFailed` | 0.74 s | 1.0124e-5 |
| 123 | `ConstructionFailed` | 0.73 s | 1.0275e-5 |

All three experimental outputs match the existing Paper.js geometry screen,
with zero off-boundary fill mismatches. Times are diagnostic observations, not
controlled benchmarks; sampling is not an exhaustive region-equivalence proof.
The production 178-case screen remains unchanged: these are not three new
production passes.

## Next implementation

Fix candidate dominance/merging so redundant endpoint proposals cannot erase a
verified overlap. Preserve multiple genuinely distinct correspondences. Start
with the reduced self-overlap regression, both orientations and translated
variants, then exercise partial overlaps, retraced curves and these three full
fixtures. Run both targets, the full release suite, the full upstream screen
and figure regeneration before adopting the change. Do not loosen the
non-affine correspondence contract to address this bug.

## Reproduction and artifacts

These instrumentation commands describe the pre-fix source at `d2f949a`;
private-source replacement anchors are revision-specific.

```
(cd test_paperjs && gleam build --target javascript)
node scripts/paperjs/investigate-final-booleans.mjs 122
node scripts/paperjs/investigate-final-booleans.mjs 122 1e-7 1e-6
node scripts/paperjs/investigate-final-booleans.mjs 107
AUDIT_PREFER_FULL_OVERLAP=1 node scripts/paperjs/investigate-final-booleans.mjs 107
# Use the experimental REPORT printed above:
node scripts/paperjs/screen-final-experiment.mjs REPORT /path/to/node_modules/paper OUTPUT 107
(cd test_paperjs && gleam run --target erlang -m paper_final_boolean_probe)
(cd test_paperjs && gleam run --target javascript -m paper_final_boolean_probe)
```

`final-boolean-findings.json` retains option sweeps, internal errors, clusters,
slow pairs, call stacks, experiments and source hashes. The profile summary is
in `final-boolean-profile.json`; the runtime logs in
`final-boolean-native-results.json`; comparison results in
`final-boolean-experimental-screen.json`. The native executable reports actual
results rather than asserting the failures should persist. No production
repair, full release test run, figure regeneration or commit was made here.

[Deferred cleanup](DEFERRED_CLEANUP.md) remains queued separately.
