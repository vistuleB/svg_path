# Tangent arc interior offsets — 2026-10-19

Investigated after `634c490`. No production changes or new permanent tests.

## Disposition of the eight original records

CC01645/46/49/50 request Cavalier `TouchingLoopBehavior::Preserve`; it retains a
single self-touching traversal. CC01653/54/57/58 request `Separate`; they expect
two closed contours. Other policy switches concern self-intersection handling
and coincident spans. The pinned upstream test explicitly says coincident-span
policy must not affect this point-only contact.

All eight captured inputs and offset distances are identical. Their native
aggregate outputs are identical because our adapter makes the same native call;
it does not map Cavalier's touching-loop policy to a native option. Native
construction options have no corresponding Preserve/Separate switch. The
module explicitly permits trimming to split a subpath into several subpaths.

The four Preserve records are therefore contour-policy differences, not a
requirement that native output contain one contour. The four Separate records
already match. The old construction errors no longer reproduce; attribution
between recent repairs has not been isolated.

## Independent geometry check

The source consists of two overlapping 12-by-12 square lobes with concave corners
at (12,10) and (10,12), inset by sqrt(2). The two radius-sqrt(2) round joins touch
at (11,11). Each ideal surviving lobe has four lines and two 45-degree arcs.

`probe-tangent-arc-contours.mjs` exports the actual default JS result, including
arc center data (`tangent-arc-contours.json`). `check-tangent-arc-boundary.py`
constructs the ideal boundary independently, without native projection or
intersection calls. It matches all 12 substantial pieces by endpoint and circle
parameters. Linear/angular parameter correspondence bounds entire corresponding
pieces; extra short pieces are enclosed around (11,11) using endpoint distance
plus arc length. This is a double-precision calculation, not interval-arithmetic
certification or a proof of exact topological equality.

Results in `tangent-arc-boundary-check.json`:

- Ideal lobe area: 84.20380692878892; native magnitude 84.20380692878886.
- Ideal lobe length: 37.736160094840606; native lengths
  37.73616011162558 and 37.73616006000139.
- All 12 ideal substantial pieces accounted for.
- Maximum corresponding-piece bound: 3.49e-7.
- Maximum extra seam-piece enclosure: 6.62e-7.
- Calculated symmetric boundary-distance bound: 6.62e-7.

The discrepancy is not evidence of missing lobe geometry. Numerical contact
geometry is not literally identical: output contains short retraced pieces and
slightly separated extremal seam points. No native contract violation is
established by those errors. They lie below the audit comparison threshold of
1e-4. Do not claim that fitting.tolerance is a universal bound on arrangement
reconstruction; its documented purpose is fitted-curve sampling.

## Separate efficiency follow-up

One current replay took 15.42 seconds on JavaScript (the earlier eight serial
replays took roughly 14.7–15.8 seconds each). These are diagnostic timings, not a
controlled performance regression benchmark. Output contains 37 segments versus
12 ideal pieces: 25 additional short arcs near contact, with combined length
1.2592e-6. Several are immediately retraced.

Investigate repeated near-tangent subdivision / reconstruction as a separate
performance and output-complexity issue. Do not change contour policy merely to
make this comparison report a match. This efficiency follow-up remains open;
no performance regression against a prior successful version has been proven.

## Validation

Executed the representative native JS probe and the independent Python boundary
check; reused the committed eight-case current replay. Confirmed one distinct
input and one distinct native aggregate result across all eight records.
No library edits, full test-suite run, figures, F# port or commit this turn.
