# Unequal ellipse higher-precision experiment — 2026-10-20

Production baseline: `1230e93`. Standalone JavaScript experiment only; neither
production source nor generated library builds are modified.

## Scope and method

`experiment-ellipse-double-double.mjs` implements a center/radius kernel using
pairs of binary64 values (double-double arithmetic). It retains remainders through
sums, products, division and square root. The degree angle is reduced to a quadrant;
sine/cosine use an 18-term Taylor recurrence on the remaining angle, with a split
pi constant. Coordinates and radii are normalized by a power of two before the
calculation. The sign-sensitive radius-enlargement decision is made before the
computed center and corrected radii are rounded back to ordinary floats.

The implementation uses only scalar floating-point operations available on both
Gleam targets, but it is currently JavaScript, not a validated Gleam/Erlang port.
The pi constant and double-double operations provide finite extra precision;
this is not arbitrary precision, interval certification, or an exact predicate.

The 64 audit cases are the previous 16 exact SVG inputs with all four flag
combinations. The 72 additional controls combine scales 1/1024, 1 and 1024,
axis ratios 0.5 and 2, rotations -137/37/123/359 degrees, and chord fractions
0.5, 1 and 1+2^-40. Intended transformed controls are rounded to binary64 first;
the oracle uses those actual inputs, not the ideal pre-rounding geometry.

`check-ellipse-double-double.py` independently evaluates the exact-input SVG
formula in Decimal at 80 and 90 digits, checking center convergence to 1e-58.
It also computes corrected radii, so returning a plausible center alone is not
enough to pass the comparison. All data and comparisons are retained as JSON.

## Results

| Group | Cases | Current maximum center error | Candidate maximum center error | Candidate maximum radius error |
| --- | ---: | ---: | ---: | ---: |
| Audit inputs and flags | 64 | 1.79554e-5 | 1.01944e-12 | 8.54614e-14 |
| Scale/angle/chord controls | 72 | 0.00603980 | 6.14020e-11 | 8.75037e-11 |

The larger control errors are absolute input-coordinate units; control radii
reach 2,048,000. They must not be read as errors at unit scale.

- All 136 midpoint-versus-displaced-center decisions match the oracle.
- Audit cases: 44 improve, 20 are unchanged, none worsen.
- Controls: 36 improve, 36 are unchanged, none worsen.
- The two previously misclassified radius-enlargement examples are corrected.
- These are measured results on selected inputs, not universal accuracy bounds.

## Timing observation

After 1,000 warm-up calls to each implementation, five batches of 5,000 calls
were timed with Node 24.10.0. Median observed time per call:

- Experimental center/radius kernel: about 5,500 ns.
- Current complete native center conversion: about 626 ns.

That is about 8.8 times the native time in this local probe. The workloads are
not identical: the experimental kernel does not yet compute start/delta angles,
while the native function does. This comparison therefore does not establish
a production slowdown ratio; it shows that unconditional use is materially
more expensive even before completing the conversion. It is not a CI benchmark.

## Recommendation and limits

The experiment supports a higher-precision fallback for poorly conditioned
near-semicircle inputs. Any dispatch decision must happen before ordinary
radius enlargement discards the distinction between a genuine displaced center
and the unique midpoint. Merely replacing the existing late compensated-product
helper would not address that branch decision.

Do not adopt this implementation as-is. Next steps, if pursued:

1. Implement the scalar kernel in isolated Gleam code and check both targets.
2. Establish and test a selective condition for entering it, including cases on
   either side of the radius-enlargement boundary.
3. Integrate angle construction and validate reconstructed endpoints, sampled
   geometry, bounds, downstream topology and timings.
4. Run the full suites and regenerate figures before production adoption.

This experiment validates only centers, radii and the branch decision. It does
not validate full arc reconstruction, extreme exponent ranges, huge angles,
near-degenerate axes, or the full library. No full-suite/figure run was performed
because production is unchanged. F# is untouched. Nothing is committed here.

## Reproduction

With the current portable JavaScript build present:

```sh
node scripts/cavalier/experiment-ellipse-double-double.mjs > scripts/cavalier/ellipse-double-double-results.json
python3 scripts/cavalier/check-ellipse-double-double.py > scripts/cavalier/ellipse-double-double-comparison.json
```
