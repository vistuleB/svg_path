# Remaining investigation groups — 2026-10-19

Four investigation groups remain after the tested endpoint-crossing repair.
These are work groups, not four confirmed bugs or a count of individual fixture
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
   Square extra contours, collapse policy and the remaining broader offset
   catalogue still need review. See `REMAINING-OFFSET-DETAIL-TRIAGE.md`.
2. **Boolean closure and geometry classification:** earlier construction choices
   behind the 16 default boundary-guard cases, stronger equivalence checks for
   decomposition differences, and earlier-stage correctness in cases where final
   arc reconstruction conforms to the documented tolerance contract. See
   `BOOLEAN-CONTRACT-TRIAGE.md` and the dispositions register.
3. **Near-semicircle numerical accuracy:** six center/bounds flags (CX00420/21,
   CX00622/23, CX00636/37). Conversion conditioning and additional native
   cancellation are separated. The production compensated center calculation
   improves exact-SVG-input accuracy in 24/27 targeted cases (three already exact).
   Full release tests pass. Rotated-half-chord rounding remains a limitation;
   all 46 published figures regenerated, with only numeric changes in three;
   see `SEMICIRCLE-ACCURACY-TRIAGE.md`.
4. **Coverage closure:** overlap interval adaptation and disposition of the 31
   tests without selected adaptations (8 representation/API reviews and 23
   math/internal gaps). See `TEST-COVERAGE.md` and `REVIEW.md`.

The F# port and final validation follow the Gleam audit; they are not counted as
additional investigations. The audit is not ready to be called complete.

Completed reduced endpoint-search robustness: direct excess-distance comparison
repairs the arc-line candidate admission inconsistency without widening endpoint
capture. Full release suite passes (2,086 + 31 + 832 per portable target); all
46 published figures regenerate byte-identically. See
`ENDPOINT-CROSSING-ROUNDOFF-TRIAGE.md`.
