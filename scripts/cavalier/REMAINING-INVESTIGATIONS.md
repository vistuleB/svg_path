# Remaining investigation groups — 2026-10-19

Five investigation groups remain after the tested exact-arc overlap repair.
These are work groups, not five confirmed bugs or a count of individual fixture
discrepancies. Original baseline totals remain historical.

Completed tangent-arc follow-up: exact-arc full-map preference repairs overlap
classification and reduces the representative offset from ~15.4s to ~0.63s.
Canonical release tests pass. Contour grouping remains a policy distinction.
See `SHORT-ARC-OVERLAP-PERFORMANCE.md`; committed as `0d3449f`.

Completed CC01807: source-normalization tolerance explains the main property
mismatch; the tighter run's zero-area retrace follows existing preservation
behavior. Documentation clarification suggested; see `SHAPE-CASE3-TRIAGE.md`.

1. **Other offset geometry and trimming policies:** remaining contour/length/
   bounds differences, including CC01160, CC01189 and CC01292 after endpoint-loss
   repair, square extra contours, and collapse semantics. Circle normal extrusion
   is understood and must not simply be treated as filled-region erosion.
2. **Boolean closure and geometry classification:** earlier construction choices
   behind the 16 default boundary-guard cases, stronger equivalence checks for
   decomposition differences, and earlier-stage correctness in cases where final
   arc reconstruction conforms to the documented tolerance contract. See
   `BOOLEAN-CONTRACT-TRIAGE.md` and the dispositions register.
3. **Near-semicircle numerical accuracy:** six center/bounds flags (CX00420/21,
   CX00622/23, CX00636/37). Conversion conditioning and additional native
   cancellation were separated; disposition/improvement remains open.
4. **Reduced endpoint-search robustness:** the 1e-12-gap iteration error from
   `ENDPOINT-REPAIR-EXPERIMENT.md`. Missing proximity matches are understood under
   the clarified necessary-not-sufficient tolerance contract; this narrower
   iteration failure remains a separate concern.
5. **Coverage closure:** overlap interval adaptation and disposition of the 31
   tests without selected adaptations (8 representation/API reviews and 23
   math/internal gaps). See `TEST-COVERAGE.md` and `REVIEW.md`.

The F# port and final validation follow the Gleam audit; they are not counted as
additional investigations. The audit is not ready to be called complete.
