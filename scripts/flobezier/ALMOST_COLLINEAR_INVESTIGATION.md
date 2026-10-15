# FI004: almost-collinear cubics below the query tolerance

> Closure status (2026-10-15): The normalization work is adopted in `a7d8cc7`; see CENTERED_NORMALIZATION.md. Default-tolerance overlap classification is intentionally unchanged.
> The dated investigation below preserves the observations and intermediate status at that time.

Investigated 2026-10-14 against `e09bef8`. No production changes made for FI004.
Fixture: captured FloBezier call 12, repeated as 2005/2997 in the expanded
capture. Exact controls and the reference root are in `almost-collinear-fixture.json`.
Upstream provenance is the FloBezier revision recorded in TANGENT_INVESTIGATION.md.

## Disposition

Understood numerical conditioning/tolerance limitation, not a newly confirmed
contract defect. The original geometry has x extent of order one but all y
coordinates lie between 0 and approximately 2.13e-14. The default Euclidean
coincidence tolerance, 1e-9, is much larger than the entire vertical variation.
Our bounded numerical API does not promise certified root isolation or exact
parameter matching at that scale.

The original audit reported nine acceptable candidates at default tolerance.
After the folded-overlap fix, the current default result is instead
`NonAffineOverlapCorrespondence`: the nearly collinear traversals contain
portions considered coincident within tolerance, with nonlinear parameter
correspondence. This behavioral change must not be mistaken for reproduction
of the original nine-candidate result. Both outcomes reflect approximate
geometry under a tolerance larger than the distinguishing feature.

## Current results

The probe runs both argument orders on JavaScript and Erlang. All result-status
and candidate-count signatures agree between targets.

| Geometry | Tolerance | Overlap query | Intersection query |
| --- | --- | --- | --- |
| Original | 1e-9 | NonAffineOverlapCorrespondence | same error |
| Original | 1e-12 | empty | 9 approximate pairs |
| Original | 1e-14 | empty | 9 approximate pairs |
| Original | 1e-16 | empty | InternalUncertifiedSegmentIntersection |
| y multiplied by 2^46 | 1e-9, 1e-12, 1e-14, 1e-16 | empty | 1 pair |

At original scale, 90-digit evaluation using exact binary64 parameter and
control values confirms maximum point-to-curve residuals of about 3.57e-14
for tolerance 1e-12, and 3.92e-15 for tolerance 1e-14. They satisfy their
respective residual contracts, despite not isolating the reference root.
The candidate sets depend on argument order.

## Conditioning experiment

Multiplying y by 2^46 changes the y controls to values of order one, using
an exact power-of-two scaling. This invertible transformation preserves exact
intersection parameters. Both targets and argument orders then return:

- left t = 0.49624328350634334
- right t = 0.18393974411322173

The captured reference is approximately
(0.4962432835063433, 0.18393974411322186). Agreement is at ordinary
floating-point precision. The scaled point's 90-digit residual is about
1.23e-16; the strictest 1e-16 query still passes binary64 certification, showing
the expected rounding limit rather than an exact-arithmetic certificate.

This experiment supports an ill-conditioning explanation. It is not a general
proof that all roots were recovered, nor a request to normalize every input.
Anisotropic scaling changes Euclidean distances and hence tolerance semantics.
Silently applying it could turn deliberately approximate overlap queries into
exact-root searches or change which nearby geometry counts as coincident.

## Recommendation

Close FI004 as an understood precision limitation. Do not change the public
options, automatic scaling policy, or overlap tolerance behavior as part of
this audit. A future solver-preconditioning experiment would need explicit
preservation of the original metric for acceptance and overlap classification,
and tests distinguishing true close roots from near-coincident traversals.

FI004 was the last unresolved discrepancy group in the current FloBezier
inventory. FI002 is documented as a near-tangent limitation; FB001/FI003,
FB007, FI006, and FI008/FI005 have received fixes or a documented convention.
This completes classification of the captured discrepancies, not a claim of
exhaustive parity with every upstream assertion.

## Reproduction

From `scripts/flobezier/probe`:

- `gleam run --target javascript -m almost_collinear_probe`
- `gleam run --target erlang -m almost_collinear_probe`

Logs: `almost-collinear-javascript.log`, `almost-collinear-erlang.log`.
Each target runs 32 API queries: 2 coordinate scalings, 4 tolerances,
2 argument orders, and overlap/intersection queries.

Run `python3 scripts/flobezier/analyze-almost-collinear.py` from the repository
root to check residuals and compare result signatures. It writes
`almost-collinear-analysis.json` and uses only the Python standard library.
No full regression suite was run for this diagnostic investigation.
