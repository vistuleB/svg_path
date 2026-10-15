# First intersection batch

Source file:
[bezier-bezier-intersection-specific-cases.spec.ts](upstream/__tests__/intersection/bezier-bezier-intersection/bezier-bezier-intersection-specific-cases.spec.ts).
Upstream test names are retained in `intersection-calls.jsonl` and
`intersection-results.json`.

Both the unmodified and instrumented upstream runs passed **12 tests**. The
instrumented run captured **59 calls**, representing **38 distinct ordered input
pairs**. Repeated calls include upstream consistency checks and reversed operands.
The Gleam JavaScript replay classifies all 59 calls:

| Disposition | Calls |
| --- | ---: |
| Isolated intersections match at the diagnostic tolerance | 25 |
| Point-only inputs outside this segment adapter | 24 |
| Continuous-overlap API differences | 7 |
| Confirmed overlap-classification bug | 3 |

The three failing comparisons are one geometry case, repeated and reversed.
This is not three independent bugs. No discrepancy in this batch remains
unclassified. The remaining upstream files have not yet been compared.

## Confirmed bug FB001

Upstream test: `it should find the intersection between an overlapping line and quadratic bezier curve`.
Captured calls: 38, 39, and 40.

Inputs are a line from (1,1) to (2,2), and a quadratic with controls
(0,0), (3,3), (0.5,0.5). Both lie on x=y. Writing the quadratic as
B(t)=(s(t),s(t)), we have

```text
s(t) = 6t - (11/2)t²
s'(t) = 6 - 11t
maximum at t = 6/11, with s = 18/11
s(t) = 1 at t = (6 ± sqrt(14))/11
```

The curves share the whole interval from (1,1) to (18/11,18/11), traversed twice
by the quadratic. A constant affine parameter correspondence cannot describe
this line–quadratic overlap. The documented `overlaps` contract calls for
`NonAffineOverlapCorrespondence` in this situation, not an empty successful
result. This conclusion follows from the polynomial directly, independently of
FloBezier's numerical precision or endpoint-reporting convention.

Actual output, confirmed on **Erlang and JavaScript**, in both operand orders:

| Our API | Result |
| --- | --- |
| `overlaps.segment` | `Ok([])` |
| `intersections.segment` | `Error(InternalOverlapClassificationInconsistency)` |
| `encounters.segment` | `Error(OverlappingSegments)` |

The primary bug is the false empty overlap result. The intersection inconsistency
is a downstream symptom. No claim is made that our overlap API should return
FloBezier's two representative endpoints or gain a non-affine overlap payload.

## Cause in the current implementation

`internal/overlap_detection.endpoint_projections` proposes overlaps from original
segment endpoints projected onto the other segment. Here the only coincident
endpoint is the line's start at (1,1), reached at two quadratic parameters.
The line's end is beyond the quadratic's maximum; neither quadratic endpoint
lies on the line segment.

Every close proposal therefore has the same line parameter, zero.
`overlap_has_positive_span` rejects the resulting zero-span candidates before
non-affinity can be diagnosed. The interior turning point is not a candidate
boundary. Consequently `detect_with_samples` returns an empty overlap list.
The independent point-intersection path recognizes continuous collinearity;
`segment_intersections_checked_valid_options` turns that disagreement into
`InternalOverlapClassificationInconsistency`.

A future fix should detect/reject this unsupported correspondence consistently,
without pretending that endpoint interpolation represents its parameterization.
Changing the overlap representation or linearizing the curve is not required
to correct the error classification. No fix is implemented in this audit.

## Verification and reproduction

- `capture.mjs`: 12 upstream tests passed unchanged and again instrumented.
- `intersections.mjs`: all 59 captured calls classified; residual and one-to-one
  parameter checks passed for the 25 matched calls.
- `gleam run` in `probe/`: reproduced all three API outcomes on Erlang.
- `gleam run --target javascript` in `probe/`: same outcomes on JavaScript.
- Archived file hashes verified against `provenance.json`.

The saved probe logs and `probe/src/flobezier_audit_probe.gleam` provide a small
standalone reproducer. No full native suite was run for this audit-only change.
