# Short arc/line transitions — 2026-10-20

Investigation at `4cd55fe`, JavaScript. No production changes.

## CC01297: detail-controlled source normalization

`small_bulge_arc_line_transition` defaults to one normalized Line and produces
length 5529.501028726129. Fitting tolerance 0.001 (also 0.0001) preserves a
Line/Arc/Line source and produces length 5639.266054486938, compared with
Cavalier's 5639.2660543910415. Largest bounds difference is 1.07e-7; length
difference is 9.59e-8. These satisfy the captured comparison's 1e-4 threshold.
This is an understood normalization/detail difference, not a newly demonstrated
intersection or trimming bug. Aggregate agreement is not a boundary proof.

## CC01301: short-run cleanup removes a reversal

`sub_tolerance_raw_offset_arc_does_not_panic` contains a backtrack from vertex 2
to vertex 3 of chord length 1.3270338878614748e-5. The initial short-run cleanup
replaces the three interior segments between vertices 1 and 4 with one Line.
This occurs before extrusion, with a fixed 0.001 cleanup tolerance, independently
of the user-selected fitting tolerance. The resulting source has no reversal.

Default fitting tolerance 0.01 and 0.001 then normalize the entire source to a
Line: one offset of length 62.585070734508804. At 0.0001 and 0.00001 the final
source is Line/Arc/Line and the output length is 63.36762959036916. Cavalier's
first walk has length 63.36763396689099; bounds differ by at most 4.07e-6.
Cavalier also retains a second walk of length 254.46905435554729. Its size and
bounds are consistent with a radius-81 reversal join (pi*81=254.46900494077323).
That attribution is a geometric inference from the captured properties, not an
instrumented trace of Cavalier's reconstruction. Native stage output directly
establishes that the source reversal is already absent before offsetting.

Disposition: understood source-normalization limitation; no new native defect
established under the current normalize-then-extrude behavior. Do not describe
the missing large feature as a final-output error bounded by 0.001. Normal
extrusion is sensitive to tangent direction, and geometrically short reversals
can generate large offsets. Tightening fitting tolerance cannot disable this
fixed preprocessing stage.

API/documentation suggestion, deferred: explicitly distinguish fitting detail
from the fixed short-run preparation threshold and state that short reversals
may disappear before extrusion. Preserving every such reversal or allowing a
caller-controlled threshold would require deliberate policy consideration.
No option or behavior is changed in this investigation.

## Evidence and commands

Using the existing portable JS build:

```sh
AUDIT_CASE_ID=CC01297 node scripts/cavalier/probe-offset-detail.mjs
AUDIT_CASE_ID=CC01301 node scripts/cavalier/probe-offset-detail.mjs
AUDIT_CASE_ID=CC01301 AUDIT_TOLERANCE=0.00001 node scripts/cavalier/probe-short-transition.mjs
```

Captured in `short-transition-CC01297.json`, `short-transition-CC01301.json`, and
`short-transition-CC01301-stages.json`. The last probe additionally records
`normalize_short_source_runs` before full normalization. Seven diagnostic
settings completed successfully; no permanent suite tests were added. No full
suite or figures rerun for this investigation. Erlang was not rerun for these
two fixtures. The broader audit remains open.
