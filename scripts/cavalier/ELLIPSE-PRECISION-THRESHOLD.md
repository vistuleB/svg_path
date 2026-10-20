# Selective ellipse precision threshold experiment — 2026-10-20

Production follow-up: the selective fallback is now implemented. See
[ELLIPSE-PRECISION-PRODUCTION.md](ELLIPSE-PRECISION-PRODUCTION.md) for validation
and scope. The experiment-only statements below describe the earlier checkpoint.

Baseline `1230e93`. Isolated JavaScript/Decimal investigation; production unchanged.

## Proposed rule

Before ordinary radius correction, compute the transformed half-chord:

```
dx = (start.x - end.x) / 2
dy = (start.y - end.y) / 2
u = (cos(phi)*dx + sin(phi)*dy) / abs(rx)
v = (-sin(phi)*dx + cos(phi)*dy) / abs(ry)
lambda = u*u + v*v
g = abs(1 - lambda)
K = max(1, lambda
           + abs(u)*(abs(dx)+abs(dy))/abs(rx)
           + abs(v)*(abs(dx)+abs(dy))/abs(ry))
```

Provisional dispatch: use higher precision when `g <= 1e-8 * K*K`.
Equivalently, `g / K / K <= 1e-8` avoids overflowing the squared factor for
finite positive K. This is an internal engineering threshold, not a new public
tolerance or guaranteed relative-error bound. A production implementation still
needs finite-range guards before evaluating these expressions. Existing circular
handling remains separate.

Why this form: the center displacement contains a square root of the gap from
lambda=1. Its sensitivity therefore grows roughly as 1/sqrt(g). Rotation error
also grows with unequal axes and cancellation; K estimates this contribution.
Bounding that amplified sensitivity leads to a cutoff proportional to K squared.
The 1e-8 coefficient is experimentally selected, not a proved error constant.
The target used to compare alternatives was center error below 1e-12 times the
larger input radius, with a margin in the observed boundary tests. It is not an
existing API accuracy promise.

For modest axis ratios this selects a narrow near-semicircle region. For extremely
unequal axes it can select higher precision even for shorter arcs. This is
intentional: those cases can be poorly conditioned without being almost 180°.
K is conservative; this experiment does not optimize exact quadrant rotations
or prove that every selected case needs the slow path.

## How the threshold was estimated

The form came from a sensitivity estimate; the constant came from experiments.
Neither was derived as a certified floating-point error bound.

1. **Locate the sensitive quantity.** In normalized ellipse coordinates,
   `lambda = u² + v²`. At lambda=1 the endpoints determine a semicircle;
   above it the radii must be enlarged. Just below it, the center's displacement
   contains `sqrt(1-lambda)`. Differentiating this factor gives an amplification
   proportional to `1/sqrt(g)`. Thus a small error in lambda matters much more
   as g approaches zero.
2. **Estimate error entering lambda.** Rotation forms sums and differences of
   products. Their absolute rounding sensitivity depends on the magnitudes of
   the terms before cancellation, not just the final u and v. The quantities
   `(|dx|+|dy|)/|rx|` and `(|dx|+|dy|)/|ry|` are inexpensive proxies for that
   sensitivity. In `delta(lambda) ≈ 2u delta(u) + 2v delta(v)`, these acquire
   factors |u| and |v|. The lambda term covers sensitivity of the squares and
   their sum. This motivates K; numerical factors and platform trigonometry
   error are deliberately not claimed to be rigorously bounded by it.
3. **Choose the squared dependence.** The resulting rough relative-center-error
   model is `C * epsilon * K / sqrt(g)`, with an unknown factor C. Requiring this
   to be below a trial accuracy target tau suggests
   `g > (C * epsilon / tau)² * K²` for the fast path. This motivates K²,
   rather than selecting that exponent solely to fit the audit examples.
4. **Calibrate the coefficient.** I chose tau=1e-12 relative to the larger radius
   as an internal experiment target, not from an existing API promise. With
   binary64 epsilon about 2.22e-16, `(epsilon/tau)²` is about 5e-8: an order-of-
   magnitude guide, not the final cutoff. I compared coefficients 1e-12, 1e-10,
   1e-8 and 1e-6. Of those tested, 1e-8 was the smallest K² coefficient that
   kept all measured fast-path errors below the trial target. The narrower
   1e-10 alternative failed that test; 1e-6 selected more slow calls.

I then added cases immediately around the proposed boundary and checked a subset
with the independent Decimal oracle. The worst observed retained error was
4.58e-13, about a factor of two below the trial target. That observed margin
is not a safety proof or a statistically established bound.

The same guard is applied on both sides of lambda=1 so that the decision to
enlarge radii is made in higher precision near the boundary. The square-root
sensitivity argument concerns the displaced-center side; using the symmetric
guard is a conservative dispatch choice. It does not justify snapping either
side to a semicircle.

## Selection evidence

`experiment-ellipse-threshold.mjs` compares fixed, K-weighted and K-squared
thresholds of 1e-12, 1e-10, 1e-8 and 1e-6 against the isolated double-double
kernel. The full set contains 3,274 cases:

- 2,970 grid cases: ratios 1e-6, .001, .5, 2, 1,000, 1e6; three scales;
  five rotations; three chord directions; eleven gaps on both sides of collapse.
- 16 saved audit inputs, including translations.
- 216 boundary cases, iteratively placed at approximately 0.5, 0.9, 0.99,
  1.01, 1.1 and 2 times the proposed cutoff on both sides of lambda=1.
- 72 ordinary controls: ratios .1, .5, 2, 10; three rotations; spans
  30, 90, 150, 170, 175 and 179 degrees.

Representative maximum relative center errors retained on the ordinary path:

| Rule | Maximum error versus double-double |
| --- | ---: |
| g > 1e-8 (fixed cutoff) | 2.44e-7 |
| g > 1e-8 K | 3.62e-11 |
| g > 1e-10 K² | 3.10e-11 |
| **g > 1e-8 K²** | **4.58e-13** |
| g > 1e-6 K² | 3.35e-14 |

The proposed rule selects 2,614/3,274 stress cases. This is deliberately a
near-degeneracy/large-aspect-ratio grid, not an estimate of real usage frequency.
All 72 ordinary controls stay on the fast path. The more conservative 1e-6 K²
rule selects more cases without being needed for the selected 1e-12 target.

## Independent check

`check-ellipse-threshold.py` checks 383 cases: all explicit boundary/audit/ordinary
cases, the 60 largest fast-path errors, and a spaced subset of the main grid.
It evaluates the exact binary64 SVG inputs using Decimal at 80 and 90 digits;
center results agree between precisions to better than 1e-55.

The hybrid choice (native fast path or experimental higher-precision kernel)
has maximum relative center error 4.58126e-13 in that independent subset.
The double-double candidate's maximum is 1.01944e-15, and all its midpoint
branch decisions match the oracle. These remain sampled results, not an exact
predicate or universal bound. Full reconstruction/angles are not included.

## Recommendation

Use `g <= 1e-8 K²` as the next implementation candidate, evaluated before radius
correction, rather than a fixed distance-to-semicircle cutoff. The observed
accuracy/cost tradeoff is sufficient to justify a Gleam prototype and portable
regressions; it is not yet sufficient to claim production validation.

Remaining validation includes numerical range guards, full arc reconstruction,
Erlang agreement, downstream geometry, figures, and actual workload timings
including the dispatch overhead. The earlier ~8.8x timing concerned the isolated
slow kernel; no end-to-end hybrid performance claim is made here.

## Reproduction

The double-double kernel was extracted without arithmetic changes into
`ellipse-double-double-kernel.mjs`, shared by both standalone experiments.

```
node scripts/cavalier/experiment-ellipse-threshold.mjs > scripts/cavalier/ellipse-threshold-grid.json
python3 scripts/cavalier/check-ellipse-threshold.py > scripts/cavalier/ellipse-threshold-oracle.json
```

The grid JSON preserves all inputs, native/candidate results, dispatch inputs,
and comparisons for every threshold. No production source, F# code, permanent
tests or figures changed; no full-suite run or commit in this investigation.


## Checkpoint and deferred validation

The user requested committing this work and deferring full testing. This checkpoint
contains experiments and evidence only; the production ellipse converter still
uses the existing unequal-radius path. The isolated checks above have run.
Production integration, portable regression tests, complete arc reconstruction
checks, the canonical release suite, and published-figure regeneration remain
pending. Do not treat this checkpoint as a completed production repair or close
the unequal-radius investigation on its basis.
