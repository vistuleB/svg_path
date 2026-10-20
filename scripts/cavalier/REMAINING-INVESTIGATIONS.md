# Remaining investigation groups — 2026-10-19

> Current status (2026-10-20): investigation of the original selected-case
> queue is complete. See [ORIGINAL-AUDIT-CLOSURE.md](ORIGINAL-AUDIT-CLOSURE.md)
> for scope, validation and the separate deferred-review list. Older pending
> wording below is historical. This is not full parity, release readiness, or
> completion of the F# port.


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
   CC01192/CC01196 now reduce to a confirmed Round-join reversal bug; see
   `OFFSET-REVERSAL-JOIN-TRIAGE.md`. A targeted correction now passes the full
   release suite and all 47 published figures are byte-identical; see
   `OFFSET-REVERSAL-JOIN-REPAIR.md`. The correction is retained; F# remains pending.
   The broader offset replay now covers 192 originally flagged records: 29 matches,
   149 property mismatches, six errors and eight timeouts. Early numerical
   mismatches are explained by fitting detail; CC01287 is traced to existing
   open-band winding/parity policy. Eight upstream tangent arc–arc option variants share one native call. The
   circular intersection repair (80d0953) now completes these in 824–922 ms.
   Full release tests pass; all 47 figures regenerate with only last-bit panel
   centering changes in one README SVG. See `TANGENT-CIRCLE-REPAIR.md`.
   The 402-case offset replay introduces no flags for previously matching cases. See
   `OFFSET-POST-REVERSAL-TRIAGE.md` and `OFFSET-POST-REVERSAL-REPLAY.md`.
   The six exact-collapse errors were reopened: preserving collapsed stalled
   runs through join construction repairs all six property comparisons. See
   `COLLAPSED-STALLED-RUN-REPAIR.md`, superseding the earlier policy disposition.
   CC01297 and CC01301 now have source-normalization dispositions; see
   `SHORT-TRANSITION-TRIAGE.md`, including the fixed short-run threshold limitation.
   Remaining mismatches are not all classified; raw counts are not bug counts.
2. **Boolean closure and geometry classification:** the 16 default boundary-guard cases now have traced short-piece filtering
   explanations and verified lower-threshold public-operation success; see
   `BOOLEAN-MINIMUM-LENGTH-TRIAGE.md`. The 56 previously witness-free difference/XOR decomposition flags now have
   per-family dispositions in `BOOLEAN-DECOMPOSITION-TRIAGE.md`, including real
   numerical differences rather than an exact-parity claim. Remaining work is
   earlier-stage correctness in cases where final
   arc reconstruction conforms to the documented tolerance contract. See
   `BOOLEAN-CONTRACT-TRIAGE.md` and the dispositions register.
3. **Original coverage closure completed (2026-10-20):** all 53 selected overlap
   records now have interval adaptations: 52 default matches and one understood
   large-coordinate tolerance mismatch, successful with explicit options. All 31
   originally uncaptured tests have named dispositions: eight supply 32 passing
   public geometry probes; 23 concern different private/representation contracts.
   See `ORIGINAL-OVERLAP-ADAPTATION.md` and `ORIGINAL-COVERAGE-GAPS.md`.
   This is scoped coverage, not full assertion-level parity. Original ledgers
   remain historical; the offset and Boolean groups above are still open.

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
limitation. See `BOOLEAN-STITCHING-GEOMETRY-TRIAGE.md`. The remaining previously witness-free Boolean families were subsequently reviewed
in `BOOLEAN-DECOMPOSITION-TRIAGE.md`.

## Original-queue continuation — 2026-10-20

The four offset-specific families and all 18 topology-policy families now have
current dispositions in `ORIGINAL-OFFSET-SPECIFIC-TRIAGE.md` and
`ORIGINAL-OFFSET-TOPOLOGY-TRIAGE.md`. This adds ten specific-offset records and
192 topology-policy records (including controls) to the classified inventory.
Numerical residuals and stronger policy validation remain explicitly deferred.
Next reconcile any remaining original offset IDs and finish original Boolean
classification; do not infer overall closure from these batch totals.
