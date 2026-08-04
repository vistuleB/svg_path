# Projection refinement experiments

This note records the informal numerical experiments that preceded selection of
the point-to-Bezier projection algorithm. It is not an API contract or a formal
accuracy study.

## Fixture grid

The comparison grid used four deliberately curved Bezier segments:

- two quadratic Beziers;
- two cubic Beziers, including a strongly backtracking example.

Each segment was queried at the Cartesian product of
`[-12, -9, -6, -3, 0, 3, 6, 9, 12]`, producing 324 cases. Of these, 212 selected
an interior projection and were suitable for tangential-stationarity
measurements. Endpoint projections were excluded from those measurements
because endpoint minima need not be orthogonal.

## Polishing metric

For an interior candidate `t`, the geometric tangential error was measured as

```text
abs((C(t) - query) dot C'(t)) / abs(C'(t)).
```

This exposed improvements around `1e-9` that were mostly invisible in distance,
where changes were commonly around `1e-15`. Raw stationary residual was rejected
as the final progress measure because it becomes artificially small with a
small tangent.

The relative tangent magnitude was defined as

```text
rho = abs(C'(t)) / (degree * max consecutive-control-point distance).
```

Adversarial near-degenerate experiments first showed disagreements between
tangential-error progress and distance progress in the broad `1e-6..1e-4`
range. The selected working policy treats normalized tangential error as
reliable when `rho >= 1e-5`. The implementation uses the squared equivalent and
therefore avoids square roots in the reliability test.

## Controlled polishing comparison

Starting both polishers from the same bisection-certified bracket over the 212
interior cases gave these accepted-step distributions:

| Accepted steps | Bisection cases | Newton cases |
| ---: | ---: | ---: |
| 0 | 107 | 0 |
| 1 | 55 | 173 |
| 2 | 32 | 38 |
| 3 | 15 | 1 |
| 4 | 2 | 0 |
| 5 | 1 | 0 |

Zero accepted bisection steps means that one proposal was evaluated and did not
improve the normalized tangential error. It does not mean polishing was skipped.

Bisection averaged `0.835` accepted polishing steps and reached a maximum of 5.
Newton averaged `1.189` and reached a maximum of 3. Final projection quality was
indistinguishable on this grid.

## Complete-method recursion comparison

An informal end-to-end recursion-count experiment included the 100-sample scan
for sampling/bisection and recursive derivative-root isolation for the
polynomial/Newton method:

| Measurement | Sampling/bisection | Polynomial/Newton |
| --- | ---: | ---: |
| Average recursive steps | 152.39 | 189.51 |
| Median recursive steps | 158 | 167 |
| Minimum | 100 | 31 |
| Maximum | 255 | 549 |

These counts are algorithmic rather than timing measurements. A polynomial
evaluation and a curve-geometry evaluation do not have equal cost.

Across the 324 cases, the maximum returned-parameter difference was
`5.47e-11`, and the maximum squared-distance difference was `1.14e-13`. A first
comparison classified all cases as ties using a deliberately conservative
`64 * binary64 epsilon` distance allowance. That tie result mostly describes
the allowance and must not be interpreted as a high-precision proof of equal
quality.

## Selected direction

The selected implementation direction is:

1. enumerate stationary roots using polynomial isolation;
2. retain real isolated brackets rather than reconstructing windows around
   returned estimates;
3. use bracketed bisection for localization and polishing;
4. certify using the geometric diameter of the bracketed curve portion;
5. after certification, continue only while normalized tangential error
   strictly improves and tangent reliability remains above the `rho` cutoff;
6. choose the final candidate among all stationary candidates and endpoints by
   geometric distance.

Polynomial isolation supplies the completeness that a fixed sampling scan
cannot guarantee. Bisection was selected as the simpler refinement mechanism
because Newton showed no final-quality advantage in these fixtures.

## Deferred hardening

A later accuracy pass may generate committed oracle fixtures using an
arbitrary-precision implementation. It should enumerate all real roots of the
stationary polynomial, evaluate every root and endpoint at high precision, and
store global-minimum data for normal Gleam tests. That work is intentionally
deferred until after the encounters feature resumes.
