# Original inventory reconciliation — 2026-10-20

After the topology batch (`29f2708`), compare original discrepancy/error/timeout
IDs with the latest per-ID entries in `triage-dispositions.json`. Historical
baseline files remain unchanged. An entry is a disposition, not necessarily a
resolution or a passing test.

## Offset IDs missing from the register

Fresh public-operation replay of all 21 missing offset IDs completed on Gleam
JavaScript, with 12 property matches, nine discrepancies and no errors/timeouts.

- CC01398/CC01402 (case10), CC01412/CC01416 (case12), CC01426/CC01430 (case14),
  CC01438/CC01439 (case15), CC01485/CC01489 (case8), CC01492/CC01496 (case9):
  original failures no longer reproduce; properties now match. No attempt is
  made to attribute each recovery to an individual earlier fix.
- CC01305–CC01308: beyond-center circle normal extrusion, covered by
  `OFFSET-COLLAPSE-AND-NORMALIZATION-TRIAGE.md`. Native behavior is not filled-region
  erosion. Whether to change high-level collapse policy remains deferred.
- CC01383–CC01386: post-collapse square contours, covered by
  `SQUARE-COLLAPSE-WINDING-TRIAGE.md`; traced winding retention plus an independent
  winding calculation explain the output. Policy reconsideration remains deferred.
- CC01291: reversed open_pline4 presentation, still empty like CC01287. This batch
  verifies the result, while `OFFSET-POST-REVERSAL-TRIAGE.md` contains the detailed
  representative winding/parity explanation. No independent re-trace of this
  orientation is claimed.

Records: `original-offset-reconciliation-cases.json` and
`original-offset-reconciliation-results.jsonl`. These are fresh observations;
known policy differences are not relabelled matches.

## Boolean timeout CC00937

The first 10-second screen timed out. The original serial 30-second replay
already completed in 13.278 seconds and matched properties, so the final
181-record discrepancy queue correctly excludes it. Its absent disposition
was bookkeeping, not an uninvestigated original failure. A current independent
scanline probe completes with 75 levels and maximum sampled difference clearance
5.24e-8; see `original-boolean-recovered-timeout.json`. This remains numerical
comparison evidence, not exact boundary equality.

No production edits, permanent test changes, F# port, full-suite rerun or commit
in this batch. See the companion current Boolean review for the remaining
original stage-classification checks. Deferred issues remain distinct.
