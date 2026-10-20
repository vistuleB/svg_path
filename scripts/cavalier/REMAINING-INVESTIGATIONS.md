# Remaining investigation groups — 2026-10-19

Three investigation groups remain after the selective ellipse precision repair.
These are work groups, not three confirmed bugs or a count of individual fixture
discrepancies. Original baseline totals remain historical.

Completed tangent-arc follow-up: exact-arc full-map preference repairs overlap
classification and reduces the representative offset from ~15.4s to ~0.63s.
Canonical release tests pass. Contour grouping remains a policy distinction.
See `SHORT-ARC-OVERLAP-PERFORMANCE.md`; committed as `0d3449f`.

Completed CC01807: source-normalization tolerance explains the main property
mismatch; the tighter run's zero-area retrace follows existing preservation
behavior. Documentation clarification suggested; see `SHAPE-CASE3-TRIAGE.md`.

1. **Other offset geometry and trimming policies:** CC01160/CC01292 are now
   explained by detail tolerance. CC01189's tight-tolerance numerical failures
   are repaired: component placement fixes 1e-6, and consistent endpoint
   ownership fixes 1e-5 and the reduced reversed-order JS case. Both original
   calls now return empty; canonical release tests pass. See
   `DUAL-NARROW-FACE-TRIAGE.md` and `CYCLIC-CLUSTER-RADIUS-TRIAGE.md`.
   The reduced square extra contours now have a winding-policy explanation,
   reproduced on both targets; see `SQUARE-COLLAPSE-WINDING-TRIAGE.md`.
   The remaining broader offset catalogue still needs review. See `REMAINING-OFFSET-DETAIL-TRIAGE.md`.
2. **Boolean closure and geometry classification:** the 16 default boundary-guard cases now have traced short-piece filtering
   explanations and verified lower-threshold public-operation success; see
   `BOOLEAN-MINIMUM-LENGTH-TRIAGE.md`. Remaining work is stronger equivalence checks for
   decomposition differences, and earlier-stage correctness in cases where final
   arc reconstruction conforms to the documented tolerance contract. See
   `BOOLEAN-CONTRACT-TRIAGE.md` and the dispositions register.
3. **Coverage closure:** overlap interval adaptation and disposition of the 31
   tests without selected adaptations (8 representation/API reviews and 23
   math/internal gaps). See `TEST-COVERAGE.md` and `REVIEW.md`.

The F# port and final validation follow the Gleam audit; they are not counted as
additional investigations. The audit is not ready to be called complete.

Completed reduced endpoint-search robustness: direct excess-distance comparison
repairs the arc-line candidate admission inconsistency without widening endpoint
capture. Full release suite passes (2,086 + 31 + 832 per portable target); all
46 published figures regenerate byte-identically. See
`ENDPOINT-CROSSING-ROUNDOFF-TRIAGE.md`.

Completed near-semicircle numerical accuracy: compensated center arithmetic,
circular rotation handling and the selective unequal-radius precision fallback
are implemented. The latest full release run passes 2,092 + 31 + 838 per portable
target; all 47 published figures are byte-identical. The production replay covers
3,274 inputs, including 383 independent oracle comparisons. Finite precision and
range limitations remain documented, rather than implying exact arithmetic.
See `ELLIPSE-PRECISION-PRODUCTION.md`, `ELLIPSE-PRECISION-THRESHOLD.md`,
`CIRCLE-ROTATION-TRIAGE.md` and `SEMICIRCLE-ACCURACY-TRIAGE.md`.

Completed Boolean stitching decomposition follow-up: CC00704/08/12/16 split into
the expected two cycles at an exact repeated vertex. Independent scanlines also
find narrow nonidentical regions, not exact parity; no new contract violation is
established. The tighter run demonstrates the existing arc reconstruction
limitation. See `BOOLEAN-STITCHING-GEOMETRY-TRIAGE.md`. Other Boolean families
still need their own geometry checks.
