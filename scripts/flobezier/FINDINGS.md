# FloBezier audit closure

Closed 2026-10-15 against Gleam implementation **`a7d8cc7`**. This is completion
of the scoped bug-finding audit, not exhaustive assertion or certified-precision
parity. The original discrepancy report and pre-fix results are preserved in
[`baseline/`](baseline/).

## Scope and final comparison

All 164 normal upstream specification files have a disposition: 68 have selected
operations compared, 42 have reviewed contract differences, and 54 are screened
arithmetic/infrastructure files without a direct public counterpart. Two excluded
Hausdorff experiments are separately source-reviewed. The recorded unmodified
upstream baseline passed 164 files / 326 tests; it was not downloaded or rerun at
closure. Its revision is `8ad65ac79cb69989cd40b0d375a51392eb477f16` (9.0.1).
All 611 archived files match the hashes in `provenance.json`.

| Final JavaScript batch | Captured calls | Direct/adapted matches | Existing explicit differences | Reviewed raw flags |
| --- | ---: | ---: | ---: | ---: |
| Intersections | 3,609 | 3,507 | 78 | 24 |
| Numerical/affine | 14,526 | 14,440 | 85 | 1 |
| Remaining operations | 928 | 873 | 54 | 1 |
| Total | 19,063 | 18,820 | 217 | 26 |

Calls include repeated inputs and helper calls; they are not test/assertion counts.
Raw comparator outputs deliberately retain `needs-investigation` for diagnostic
mismatches. `closure/summary.json` records the reviewed dispositions of all 26;
**zero remain unclassified**. `close-audit.py` checks the expected results and
fails on unknown flags rather than silently treating a new mismatch as covered.

## Findings and disposition

| Finding | Final status | Evidence / change |
| --- | --- | --- |
| FB001 / FI003: folded non-affine overlaps | Fixed | `dd381a2`; [overlap investigation](OVERLAP_INVESTIGATION.md). Nine captured calls now return the documented `NonAffineOverlapCorrespondence` error rather than points or an inconsistent internal error. |
| FB007: closest-pair JavaScript stack overflow | Fixed | `b3bb1a9`; [stack investigation](STACK_OVERFLOW.md). Original query completes; its cost/default accuracy are discussed below. |
| FI006: folded-curve length integration | Fixed | `0d96855`; [length investigation](LENGTH_INVESTIGATION.md). All four originally failing length calls now match. |
| FI005 / FI008: constant-segment parameter and zero-direction behavior | Fixed/defined | `e09bef8`; [constant-segment investigation](CONSTANT_INTERSECTION_INVESTIGATION.md). Canonical t=0 differs intentionally from FloBezier's t=0.5. |
| FI004: extremely thin curve conditioning | Addressed, with default-tolerance distinction retained | `269a535`, superseded by `a7d8cc7`; [adopted normalization](CENTERED_NORMALIZATION.md). Tight-tolerance native regressions recover the reference root in both orientations. Default tolerance still treats this geometry as a non-affine overlap: three raw flags are understood policy differences, not claimed numerical matches. |
| FI002: shared tangent candidate clouds | Documented numerical limitation | `36d812f`; [original investigation](TANGENT_INVESTIGATION.md). Nine current flagged calls retain all reference roots and pass the independent residual check, with extra candidates near shared endpoints. Root isolation is not certified. |

## Two closure-boundary checks

**Numerical call 13594: independently rounded total length.** FloBezier supplies
278.7257728017262 as the whole-curve length; our revised integration computes
278.72577280172595, a difference of 2.2737367544323206e-13. Our inverse-length API
rejects the supplied distance because it exceeds our total, and returns exactly
t=1 when given its own total. This is a domain-boundary difference, not an
in-range failure. Evidence: `closure/length-boundary.json`; reproduce with
`node scripts/flobezier/closure-boundaries.mjs`.

**Remaining call 728: default closest-pair accuracy and runtime.** The five-second
adapter timeout was too short for the repaired query. Rerunning the remaining
batch with `FLO_TIMEOUT_MS=60000` completes with no exception or timeout. Our
distance is 0.0010000414522580048; FloBezier's default result is
0.0015024959575384855. The analytic minimum for the stored input is approximately
0.0009999999987052425. Our error is about 4.15e-8; the reference's error is about
5.02e-4. Thus requiring their default numbers to agree is inappropriate. Our
closest-pair API explicitly does not promise a certified global distance-error
bound. Runtime and refinement remain possible future improvements, not an
unresolved stack bug. Evidence: `closure/closest-pair-boundary.json`.

The analytic minimum follows from maximizing the cubic's y coordinate:
y(t)=100000+30t-51t²+21t³, at t=(102-sqrt(2844))/126, then subtracting from the
horizontal line's stored y. The cubic's x lies within the line segment there.

## Validation and deferred scope

Final implementation passed `scripts/test-release`: 2,012 fast, 31 slow,
758 portable Erlang and 758 portable JavaScript tests. All 13 README and 33
Gallery figures regenerated; see [normalization validation](CENTERED_NORMALIZATION.md).
The complete captured-call comparison runs at closure are JavaScript; targeted
native regressions and the portable release suites cover both targets. This is
not a claim that all 19,063 comparison calls ran on Erlang.

No known captured discrepancy is awaiting investigation. Certified root isolation,
stronger default closest-pair accuracy/performance and absent API capabilities
remain optional future work. F# migration is separate and not performed by this
closure. The audit scripts do not alter production geometry code.
