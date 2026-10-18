# Boolean contract classification — 2026-10-18

Source `090f8e63`; diagnostic scripts and records only. No production edits,
commits, or F# changes.

## Correction to the previous batch

The previous batch established real geometry displacement but called it a
confirmed Boolean bug before checking the complete `CsgResult` contract. That
classification was too strong.

`src/svg_path/csg.gleam` documents that binary output endpoints are adjusted to
arrangement vertex positions, by at most the build tolerance, retaining arc
parameters. It explicitly says that this endpoint bound is **not a bound on the
interior displacement of an elliptical arc**. The default build tolerance is
1e-6, not the standalone intersection query's 1e-9.

For all 35 previously flagged `And` results:

- Every output segment matches a stored arrangement edge, forward or reversed,
  with all non-endpoint fields unchanged.
- Every endpoint displacement is within default tolerance; the largest is
  1.5033221201665352e-7.
- The largest sampled midpoint displacement from the stored edge is
  0.00047181127104281237.

Thus the outside-input witnesses are real, but are explained by the documented
endpoint-reconstruction limitation, amplified by near-semicircular conditioning.
They are not, on that evidence, a violation of the current contract. Retain this
as an improvement/API-policy candidate: endpoint distance alone is a poor bound
on arc geometry movement. A future change must decide how to preserve arc
geometry while obtaining exactly joined output, rather than changing clustering
or asserting a new interior-error guarantee implicitly.

Evidence: `probe-csg-reconstruction.mjs`, `csg-reconstruction.json`.
The extended check (`probe-csg-reconstruction-all.mjs`,
`csg-reconstruction-all.json`) covered all 181 originally flagged Boolean
records: 165 now succeed and 16 return errors. Every segment in all 165
successful results matches a stored edge with unchanged non-endpoint fields;
all endpoint adjustments are within tolerance (maximum 4.915100078052176e-7).
This verifies reconstruction behavior, not correctness of every earlier
arrangement/classification stage.
The earlier witnesses and independent capsule calculations remain valid evidence
of displacement; only their classification is corrected.

## Remaining Boolean replay and region sampling

`probe-boolean-remaining.mjs` checks all 126 baseline `Not`/`Xor` property flags
and all 20 baseline Boolean errors: 146 records. It samples both sides of output
segments at parameters 0.25, 0.5 and 0.75, with normal offsets +/-1e-5 and +/-1e-4.
It compares the output classification with the Boolean truth table of the input
classifications. Boundary points are skipped; stored mismatch witnesses require
more than 1e-7 distance from all three boundaries. Up to 12 witnesses are retained
per record. This is a diagnostic, not a proof of region equivalence or a full
independent oracle (the classification/distance functions are native).

Fresh outcomes in `boolean-remaining.jsonl`:

| Operation | Samples with witnesses | No witnesses in samples | Errors |
| --- | ---: | ---: | ---: |
| Difference | 36 | 4 | 4 |
| XOR | 36 | 52 | 4 |
| Union (original error cases only) | 0 | 1 | 4 |
| Intersection (original error cases only) | 1 | 0 | 4 |

The 72 Difference/XOR witness cases are from the same near-semicircular pill
families. They must be interpreted with the reconstruction contract above.
The 56 Difference/XOR no-witness records are consistent with decomposition or
small numerical differences; they are **not all closed as equivalent** merely
because samples pass. The earlier two elementary circle/rectangle XOR examples
have additional analytic explanations; do not generalize them to every fixture.

The first probe run used an XOR truth table for newly successful Union/Intersection
records, which had previously been errors. Those two records (CC00804/CC00805)
were rerun with the correct operation truth table. `boolean-remaining.jsonl` is
the corrected result; `boolean-remaining-initial.jsonl` is retained only as
historical diagnostic output and must not be used for dispositions.

## Original Boolean errors: 4 recovered, 16 documented guard failures

CC00804–CC00807 now return results at defaults. Their original errors are no
longer reproducible at the current commit; no individual fix attribution was
isolated. Their geometry is included in the checks above.

The remaining 16 records are four operations in four presentations of
`parametric_from_point_debug_assert_reported2` (CC01059, CC01063–CC01077).
The arrangement itself builds at defaults, but the second operand has four
nonzero vertex flows after refinement. The CSG boundary-closure guard rejects
this, as documented for pieces discarded below `minimum_length=1e-5`.
This is an explicit failure, not silent incorrect output. The guard behaves
as documented. This does not independently establish that every preceding
refinement/discard decision is correct; the remaining construction behavior
is still open for investigation. It is the same guard associated with the
public error variant deferred for 4.0.0; do not restore that variant in 3.x.

A diagnostic rerun with minimum length 1e-8 (otherwise default) fails earlier
with `InternalCyclicOrderCircleIntersectionFailed`, at a vertex probe radius
around 1.5e-6. Lowering the threshold therefore is not a verified workaround.
This alternative-settings construction failure remains an investigation candidate;
no conclusion about its root cause is made here.

`probe-boolean-errors.mjs` and `boolean-errors.json` preserve both arrangement
runs and each operand's nonzero vertex flows. No production instrumentation or
public API modification was required.

## Validation and next work

Diagnostics use the existing current JavaScript build. No full suite was rerun:
production code and permanent tests are unchanged. Preserve the baseline raw
comparison results. Remaining work includes stronger equivalence checks for
unresolved Boolean decomposition flags, the smaller-threshold cyclic-order
failure, offset construction/collapse discrepancies, and coverage gaps.


## Subsequent cyclic-order investigation

The smaller-threshold failure is now explained in
[CYCLIC-ORDER-TRIAGE.md](CYCLIC-ORDER-TRIAGE.md). A circle-sampling tolerance
mismatch is confirmed, reduced to two perpendicular lines and reproduced on
both targets. The original CC01059 trace has the same mechanism. The subsequent local repair
experiment makes all 16 affected arrangements build at minimum length 1e-8; see
`cyclic-repaired-original.json` and the cyclic-order report.
This does not change the default minimum-length boundary-guard disposition.
