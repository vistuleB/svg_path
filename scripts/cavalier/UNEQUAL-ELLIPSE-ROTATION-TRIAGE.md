# Unequal-radius near-semicircle conditioning — 2026-10-20

Baseline: `1230e93` (circular rotation repair committed). Investigation only.

## Exact-input experiment

`probe-ellipse-rotation.mjs` generates 16 inputs: stretch the original
origin-centered near-semicircle by 0.5 or 2 along y, rotate by 0/17/37/73 degrees,
and translate by 0 or 10,000. The resulting binary64 SVG inputs, rather than the
unrounded intended transformations, define the oracle problem.

`check-ellipse-rotation.py` evaluates the SVG center formula with Decimal
arithmetic and high-precision Taylor sine/cosine. It includes exact-input radius
enlargement, choosing the midpoint when the supplied radii are insufficient.
The oracle agrees between 80- and 90-digit runs to better than 1e-60 in center
coordinates. It is a selected-fixture numerical oracle, not an interval proof
or a general-purpose trigonometry implementation.

It also evaluates the formula in high precision using the library's already
rounded sine/cosine values. This isolates the remaining error even if all later
coordinate and product arithmetic were much more precise.

Selected errors (Euclidean center distance in input units):

| y stretch | rotation | translation | Current error | High-precision arithmetic with rounded trig error |
| --- | --- | --- | --- | --- |
| 0.5 | 17 | 0 | 8.14e-7 | 3.67e-6 |
| 0.5 | 37 | 0 | 5.61e-6 | 0 |
| 2 | 37 | 0 | 6.01e-6 | 2.51e-6 |
| 2 | 73 | 0 | 1.80e-5 | 1.54e-5 |

In the 0.5/37 and 2/73 origin-centered cases, the high-precision exact-input
solution requires radius enlargement and has center (0,0). Native conversion
instead keeps the supplied radii and returns a displaced center. Both examples
reproduce on Erlang. Thus the issue is not just output angle evaluation or an
upstream adapter expectation. The inputs have radii from 500 to 2,000; these
absolute errors must not be generalized to other scales.

## Interpretation

Near a semicircle, the numerator that determines center displacement is close
to zero. Rotation/product rounding can change its sign, and the square root
amplifies the residual. Unequal axes genuinely depend on rotation, so the circular
repair cannot be applied. Compensating only the transformed coordinates/products
is insufficient: rounded trigonometric values alone retain substantial error,
and removing one source of rounding can even remove accidental cancellation
(the 0.5/17 example).

This is a reproduced numerical-accuracy limitation relative to exact SVG inputs.
The public conversion has no user-selected center-error guarantee, so this does
not establish violation of such a guarantee. It remains a potential numerical
improvement, not an unexplained audit-parity mismatch.

## Recommendation

Do not extend the circular shortcut to approximately equal axes or snap every
near-semicircle to its midpoint. Both would change legitimate ellipse geometry.
Do not adopt a compensated-half-chord-only change based on a few passing cases.

A principled repair would need to address the rotation and radius-enlargement
predicate together: for example, a higher-precision fallback for trigonometry,
rotated coordinates, and the sign-sensitive center expression when the ordinary
calculation is poorly conditioned. That is a larger numerical change than the
circle branch and requires a separate implementation/validation decision.
Alternatively retain this as an explicitly documented conditioning limitation.
No candidate production repair is established by this investigation.

## Records and checks

- `ellipse-rotation-inputs.json`: exact native inputs, trig values, and results.
- `ellipse-rotation-oracle.json`: exact-input and rounded-trig comparisons.
- `probe-ellipse-rotation.mjs`, `check-ellipse-rotation.py`: reproduction.
- `probe/src/ellipse_rotation_audit_probe.gleam`, `ellipse-rotation-erlang.log`.

Rebuild portable JavaScript, run the JS probe into its inputs file, then run the
Python oracle into its results file. Run the Erlang probe from the audit package.
No production edits, full-suite rerun, figure changes, F# port, or commit here.
