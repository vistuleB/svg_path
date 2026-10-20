# Near-semicircle accuracy follow-up — 2026-10-19

Production baseline: `b7f9257`. The production implementation below follows the
initial copied-build investigation.
Six audit flags represent three arcs: center/bounds pairs CX00420/21,
CX00622/23, CX00636/37. Earlier exact-input diagnosis: `RESUMED-TRIAGE.md`.

## Cause and disposition

There are two independent effects:

1. Bulge-to-SVG conversion loses near-semicircle center information when it
   rounds the radius. The native solver must respect the resulting SVG input;
   matching the original upstream bulge center is not the correct regression
   expectation.
2. `ellipse.center_prime` computes
   `rx² ry² - rx² y² - ry² x²` using ordinary rounded products/subtractions.
   Near a semicircle those terms nearly cancel. This adds avoidable native
   numerical error even relative to the exact binary64 SVG inputs.

The second effect merits an accuracy repair. No public tolerance guarantee is
being inferred from the audit's comparison threshold. The first effect remains
an understood representation difference; do not mark all six upstream-equality
comparisons fixed merely because native arithmetic improves.

## Copied-build experiment

`prepare-semicircle-compensated-experiment.py` copies the generated JS build.
It changes only `center_prime`, using power-of-two normalization and compensated
sums/products (high/low pairs) for the numerator and denominator. It does not
snap to a semicircle or alter supplied radii, sweep flags, or endpoints.
The previous implementation is retained as a nonfinite-result fallback.

The experiment is intentionally not production-ready: it computes compensated
products for every call, and its extreme-exponent behavior, rotated ellipses,
radius-correction decision, and broad geometry consequences are not validated.
It demonstrates that the identified cancellation can be repaired using ordinary
binary64 arithmetic on both-runtime-compatible mathematical operations.
Only JavaScript ran this candidate; earlier baseline errors reproduced on both
targets. No candidate Erlang or full-suite pass is claimed.

`probe-semicircle-accuracy.mjs` evaluates the three original arcs at scales
1, 0.001, 1024 and y-axis stretch factors 1, 2, 0.5: 27 cases, including circular
and axis-aligned elliptical arcs. `compare-semicircle-accuracy.py` independently
computes expected centers with 80-digit Decimal arithmetic from the exact API
input values. Its bounds oracle includes endpoints and applicable axis extrema;
only cardinal-angle membership uses binary64, with these fixtures' endpoints
well separated from cardinal angles. This is not a general interval oracle.

### Original circular inputs

| Arc | Baseline center error | Candidate center error | Baseline maximum bound-coordinate error | Candidate bound-coordinate error |
| --- | --- | --- | --- | --- |
| CX00420 | 1.41524e-6 | 5.79e-22 | 1.17646e-6 | 1.14e-13 |
| CX00622 | 3.24454e-6 | 1.56e-12 | 2.75275e-6 | 1.58e-12 |
| CX00636 | 3.24454e-6 | 1.56e-12 | 2.75275e-6 | 1.58e-12 |

The translated cases are limited by rounding the final center coordinates
near 10,000 and -20,000. Across all 27 cases, center accuracy improves in 24;
three scaled inputs require radius enlargement and already return the exact
midpoint, so both results have zero center error. This is targeted evidence,
not a guarantee for all ellipses or inputs.

## Evidence and reproduction

```sh
python3 scripts/cavalier/prepare-semicircle-compensated-experiment.py
node scripts/cavalier/probe-semicircle-accuracy.mjs > scripts/cavalier/semicircle-accuracy-baseline.json
AUDIT_JS_BUILD=/tmp/cavalier-semicircle-compensated node scripts/cavalier/probe-semicircle-accuracy.mjs > scripts/cavalier/semicircle-accuracy-compensated.json
python3 scripts/cavalier/compare-semicircle-accuracy.py > scripts/cavalier/semicircle-accuracy-comparison.json
```

These prototype reproduction commands require a build of baseline `b7f9257`,
not the patched working tree. The preparation script reads that checkout's
`test_portable/build/dev/javascript` output. Do not overwrite the saved baseline
with a patched build. Existing
`semicircle-native.json` provides the original exact API input coordinates.

## Recommendation

Implement a compensated near-cancellation path in the center solver, keeping
the ordinary well-conditioned path inexpensive. Use exact-SVG-input oracle
expectations, including circle/ellipse variants, translation, reversed sweep,
large-arc choice, exact semicircles, and radius enlargement. Check rotated and
extreme-scale behavior explicitly rather than assuming compensation covers it.
Then run the canonical full suite and review regenerated figures: the computed
arc geometry changes numerically, and downstream intersection/topology code
uses it. No API or option change is needed. Performance should be checked for
ordinary arcs before adopting an unconditional compensated path.

## Production implementation

`ellipse.center_prime` retains ordinary arithmetic unless the absolute numerator
is at most 1e-12 times the larger radius/denominator product. Near cancellation,
it uses compensated sums and products after power-of-two normalization. No
public API, tolerance option, or sweep choice changes. When SVG requires radius
enlargement, the center is explicitly the midpoint: the enlargement leaves one
mathematical solution, and rounding the corrected radii must not displace it.
The high/low pairs retain rounding remainders; they are not interval bounds.
This does not repair general extreme-exponent overflow in earlier calculations.

`svg_path_semicircle_accuracy_test` contains four portable tests: 27 exact-input
center fixtures, all sweep/large-arc choices, exact semicircle/radius enlargement,
and bounds plus quadrant rotations. Targeted runs passed on Erlang and JavaScript.

`semicircle-rotation-controls.json` records an additional limitation: a 37-degree
rotation of the circular input rounds the transformed half-chord before this
calculation. Compensating the subsequent products does not recover those lost
bits. For CX00420 the resulting center is approximately
(-6.04120322848e-6, 4.03957779569e-6), versus the exact circular input center
(-5.31791807067e-6, 3.55593793904e-6). Quadrant rotations pass the regression.
This is retained as follow-up numerical work, not classified as repaired here.

The first complete ordinary-suite run found one regression:
`arc_accepts_equivalent_axis_representations_test` (2,083 passed, one failed).
It exposed precisely that radius-enlargement residue. Explicit midpoint handling
repairs the cause; the regression module also checks the two rotated, swapped-axis
inputs directly. The existing congruency assertion is unchanged.

Final validation command (Node 24.10.0 on PATH, Gleam 1.18.1):
`scripts/test-release` — 2,084 ordinary, 31 slow, 830 portable Erlang and
830 portable JavaScript tests passed. See `semicircle-test-release.log`.
The production 27-case output (`semicircle-accuracy-production.json`) matches
all copied-prototype results exactly, including bounds.

`scripts/generate-published-figures` completed successfully, including another
2,084-test ordinary run, all 13 README figures, and all 33 Gallery figures.
All README and 30 Gallery files are byte-identical to the pre-generation files.
Three Gallery files differ only in numeric tokens; nonnumeric content, drawing
commands and XML element counts are identical:

- `gallery-dashed-strokes.svg`: one token, maximum absolute delta 1e-5.
- `gallery-recursive-dashes.svg`: 17 tokens, maximum absolute delta 1e-5.
- `gallery-package-title-second-offset-arrangement.svg`: 1,281 tokens, maximum
  absolute delta 2.622e-9.

Hashes are in `semicircle-figure-comparison.json`; generation output is in
`semicircle-figures.log`. Updated Gallery outputs are retained. Audit metadata
validation and formatting checks pass. F# port remains deferred until the
Gleam audit is finished. This change does not close the full audit.
