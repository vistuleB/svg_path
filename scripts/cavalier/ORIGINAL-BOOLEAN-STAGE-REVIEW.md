# Original Boolean stage review — 2026-10-20

Native `29f2708`, production unchanged from `09d30a1`. JavaScript diagnostics
only. Replayed all 181 entries of the final original Boolean discrepancy queue.
CC00937, the recovered initial timeout, is covered separately in
`ORIGINAL-INVENTORY-RECONCILIATION.md`.

## Separating stored boundaries from endpoint reconstruction

The existing independent line/circle scanline probe now has a `PRE_SNAP=1`
diagnostic mode. It runs the public detailed CSG operation, matches each returned
segment to an oriented stored arrangement edge with identical non-endpoint
fields, and checks that endpoint movement is at most the CSG tolerance. It then
uses the stored curves and inserts straight connectors across any endpoint gaps
to obtain closed walks for the scanline calculation. This is an experiment, not
a production repair or an alternative API output contract.

The input model is the actual SVG arc representation supplied to the library,
not a separately rounded bulge circle. Circle centers, intersections, scanline
winding and distance checks use analytic JavaScript formulas independent of the
native intersection/containment/distance implementations. Floating-point oracle
calculations are not certified exact predicates.

## Observations

| Mode | Successful cases | Scanlines checked | Maximum sampled difference clearance |
| --- | ---: | ---: | ---: |
| Returned output | 165 | 12,012 | 2.353335259639433e-4 |
| Stored curves with straight gap connectors | 165 | 9,849 | 1.3065072144014896e-7 |

All stored-edge matches conform to the documented endpoint adjustment contract;
maximum endpoint movement is 4.915100078052176e-7 (default tolerance 1e-6).
The 16 other cases fail the same known default construction guard in both modes.
No case times out under the 45-second diagnostic limit.

This supports endpoint reconstruction as the principal source of the larger
observed differences. It finds no new demonstrable earlier-stage classification
failure. It **does not prove** that the selected edges, every face label, or every
boundary point is correct. Clearance is measured at sampled symmetric-difference
midpoints against the nearest input/output boundary, not a Hausdorff bound.
Scanline sets differ between modes; straight connectors introduce their own
small diagnostic regions. Remaining small numerical differences remain real.

The existing 56-case decomposition review remains applicable: 36 decomposition/
orientation comparisons, eight tolerance-dependent thin-geometry comparisons,
and twelve nonidentical numerical/reconstruction comparisons. Its classifications
have now been reconciled into the per-ID register instead of leaving its old
“no sampled mismatch, not yet equivalence” statuses as the latest entries.

## Independent oracle exceptions

Four output checks (CC00968/72/76/80) and two stored-edge checks (CC00972/80)
initially abort with `Unbalanced scanline`. These exceptions belong to the
floating-point diagnostic, not a native CSG error. All six complete after an
exact coordinate quarter-turn of the already constructed analytic geometry,
scanning along the orthogonal axis. No production operation or geometry is
changed for this control. Original failing runs are retained rather than erased.
The precise oracle rounding mechanism is not isolated; these observations are
not represented as exhaustive successful checks in both directions.

## Records and reproduction

- `run-original-boolean-review.py`: bounded two-mode replay of the 181 IDs.
- `original-boolean-scanlines.jsonl`: all 362 initial observations, including errors.
- `recheck-original-boolean-scanlines.py` / `original-boolean-orthogonal-rechecks.jsonl`:
  six orthogonal controls.
- `summarize-original-boolean.py` / `original-boolean-stage-summary.json`:
  effective per-case results and aggregate measurements.
- `probe-boolean-minimum-length.mjs`: existing guard/filter diagnostic; current
  replay saved separately as `original-boolean-minimum-length-recheck.json`.

```sh
python3 scripts/cavalier/run-original-boolean-review.py
python3 scripts/cavalier/recheck-original-boolean-scanlines.py
python3 scripts/cavalier/summarize-original-boolean.py
```

No production or permanent test edits, full-suite/figure rerun or F# changes.
Endpoint-reconstruction redesign and stronger numerical guarantees remain
explicitly deferred. This records original-case investigation, not exact parity.

## Current guard recheck completed

All 16 original guard cases fail at `minimum_length=1e-5` and succeed at
`1e-6`, `1e-7`, and `1e-8`. The earlier smaller-threshold cyclic-order blocker
does not recur. This corroborates the traced short-piece filtering disposition
in `BOOLEAN-MINIMUM-LENGTH-TRIAGE.md`; no exact equivalence claim is made for
the alternative-option outputs.
