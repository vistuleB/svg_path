# Boolean stitching geometry follow-up — 2026-10-20

Baseline `7698b5a`; no production changes.

## Cases and contour decomposition

CC00704, CC00708, CC00712 and CC00716 are the four XOR presentations of
`test_specific::debug_assert_stitching_slices_reported`. The previous sparse
boundary-side sampling found no witnesses; that was insufficient to assert
region equivalence.

The current native result has one closed walk revisiting a shared vertex.
Splitting that walk at exact repeated vertices produces two cycles, corresponding
to the two Cavalier positive contours. Independently integrating the lines and
circular arcs gives these values for CC00704:

| Property | Native decomposed cycle | Cavalier |
| --- | ---: | ---: |
| Left absolute area | 8.126997298679342 | 8.12699670000984 |
| Left perimeter | 16.78824172728442 | 16.788242670074666 |
| Right absolute area | 10.119464375408596 | 10.119464484796188 |
| Right perimeter | 19.925886117252798 | 19.925886964359684 |

Bounds differ by at most about 4.65e-7. Cavalier gives the right contour negative
signed area while keeping it in its positive-output list; the native traversal
has positive area. Signed traversal orientation and number of serialized
subpaths therefore explain the original aggregate mismatch. This does not mean
the two geometric boundaries are bit-identical.

## Independent region checks

`probe-boolean-scanlines.mjs` constructs input circle centers directly from
upstream bulges and reconstructs native output circles independently from their
SVG endpoint data. It does not call native containment, intersection or distance
queries for its region oracle. It computes horizontal winding intervals and XOR,
then compares them to the output winding intervals.

Event levels include endpoints, circle extrema, and analytic line/line,
line/circle and circle/circle intersections among input and output primitives.
Three scanlines are checked in each intervening strip. This is floating-point
numerical evidence, not an exact-predicate proof. Strips narrower than 1e-11
coordinate units are skipped to avoid sampling essentially at a rounded event;
the output records skipped counts. Coincident supporting circles do not produce
pair-intersection events. Four elementary circle/rectangle XOR controls produce
zero interval discrepancies.

For each stitching presentation, 45 scanlines remain after that exclusion.
The largest total horizontal symmetric-difference width is about 2.38e-5.
That width occurs near a tangent: the missing sliver's midpoint is only about
9.2e-10 from an input boundary, despite being about 4.37e-5 from the output
boundary. Width is not a normal displacement bound. Across midpoints of all
observed interval differences, the greatest minimum distance to any input/output
boundary is 2.34e-7, below default construction tolerance 1e-6.

These measurements correct the previous no-witness observation without proving
a new contract violation. Endpoint clustering and arc reconstruction are
explicitly tolerance-dependent; the API does not promise exact region equality
or an interior Hausdorff error bound. The repeated-vertex decomposition is
understood. Do not claim universal geometry equivalence from this finite probe.

## Validation scope

JavaScript diagnostics only. No production edits, permanent regression tests,
full-suite run, figure regeneration or F# changes. Saved results are
`boolean-stitching-scanlines.jsonl` and `boolean-scanline-controls.jsonl`.

## Tighter-options follow-up

CC00704 also completes with tolerance 1e-9 and minimum length 1e-8. Its retained
geometry is saved in `boolean-stitching-tight-geometry.json`; the independent
replay is `boolean-stitching-scanlines-tight.jsonl`. Exact repeated-vertex splitting
finds three cycles, including a sliver with computed area about 1.46e-13. That
area is near floating cancellation and is not claimed as an accurate area oracle.
At 57 sampled levels, maximum horizontal difference falls to 5.64e-6, while
maximum witness clearance is 1.94e-7. Changing the reference from original bulges
to independently decoded SVG input arcs gives the same measurements
(`boolean-stitching-scanlines-tight-svg.jsonl`); the adapter does not explain them.

The residual is consistent with the known endpoint-reconstruction limitation:
one output near-semicircle retains radius 0.6350000000000011 but its independently
reconstructed center differs from the corresponding input circle by 3.90e-7.
Its endpoints are only 3.34e-13 and 2.22e-15 away from that input circle. Those
radial errors are not endpoint-to-arrangement-vertex displacement measurements;
do not confuse the two. The saved support comparison demonstrates conditioning,
not a new upper bound or a complete per-edge provenance proof. The existing
all-case reconstruction audit established that stored radii were preserved and
endpoint movements stayed within build tolerance; see `BOOLEAN-CONTRACT-TRIAGE.md`.

Disposition: the contour/decomposition flag is explained. Exact region equality
is false in the independent numerical probe, but this investigation establishes
no new violation of the current reconstruction contract. Keep improving arc
reconstruction as an existing policy/API candidate, not a new confirmed bug.
Do not label these four cases as exact parity merely because aggregate values
are close. The tighter run is not a claim of an interior 1e-9 geometry bound.

The first tight scanline attempt failed at near-coincident event levels. A second
attempt reached decomposition but exposed a probe assumption that output had
one subpath. The probe now excludes explicitly counted <1e-11 event strips and
handles multiple closed walks. Cached completed geometry was replayed after
these probe-only corrections, avoiding another expensive CSG call.

Reproduction (with Node on PATH):

```sh
node scripts/cavalier/probe-boolean-scanlines.mjs
CASE_TEST=test_simple::rectangle_over_half_of_circle node scripts/cavalier/probe-boolean-scanlines.mjs
CASE_ID=CC00704 TOLERANCE=1e-9 MIN_LENGTH=1e-8 RAW_INPUT=scripts/cavalier/boolean-stitching-tight-geometry.json node scripts/cavalier/probe-boolean-scanlines.mjs
```

Omit RAW_INPUT and optionally set RAW_OUTPUT to recompute the tight public CSG
call. Cached replay reports `contours: null`: it knows primitive geometry but
does not infer the original number of serialized subpaths from it.
