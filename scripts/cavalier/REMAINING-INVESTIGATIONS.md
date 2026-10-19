# Remaining investigation groups — 2026-10-19

After the endpoint-cycle repair, the remaining work is organized into seven
groups. This is a work breakdown, not seven confirmed bugs or a count of all
individual fixture discrepancies. Original baseline totals remain historical.

1. **Tangent arc interiors:** CC01645/46/49/50/53/54/57/58, eight offset variants.
   Current replay: four aggregate matches and four discrepancies; all eight
   construct successfully. The first differing case splits one touching contour
   into two, with agreeing total area/length. Region equivalence is not yet
   proven. See `remaining-construction-after-endpoint-cycle.jsonl`.
2. **Shape offset case3:** CC01807 now constructs but remains an aggregate
   discrepancy. Same current replay file.
3. **Other offset geometry and trimming policies:** remaining contour/length/
   bounds differences, including CC01160, CC01189 and CC01292 after endpoint-loss
   repair, square extra contours, and collapse semantics. Circle normal extrusion
   is understood and must not simply be treated as filled-region erosion.
4. **Boolean closure and geometry classification:** earlier construction choices
   behind the 16 default boundary-guard cases, stronger equivalence checks for
   decomposition differences, and earlier-stage correctness in cases where final
   arc reconstruction conforms to the documented tolerance contract. See
   `BOOLEAN-CONTRACT-TRIAGE.md` and the dispositions register.
5. **Near-semicircle numerical accuracy:** six center/bounds flags (CX00420/21,
   CX00622/23, CX00636/37). Conversion conditioning and additional native
   cancellation were separated; disposition/improvement remains open.
6. **Reduced endpoint-search robustness:** the 1e-12-gap iteration error from
   `ENDPOINT-REPAIR-EXPERIMENT.md`. Missing proximity matches are understood under
   the clarified necessary-not-sufficient tolerance contract; this narrower
   iteration failure remains a separate concern.
7. **Coverage closure:** overlap interval adaptation and disposition of the 31
   tests without selected adaptations (8 representation/API reviews and 23
   math/internal gaps). See `TEST-COVERAGE.md` and `REVIEW.md`.

The F# port and final validation follow the Gleam audit; they are not counted as
additional investigations. The audit is not ready to be called complete.
