# Offset normalization and traversal — 2026-10-20

Baseline `99ff1694`. Investigation only: production code and permanent tests
unchanged. Copied generated JavaScript builds under `/tmp` contain experiments.

## Finding

The fixed 0.001 short-run threshold is not the whole problem. Offset source
preparation then calls public `degeneracy.normalize_degenerate_segments` on the
whole path. That function explicitly preserves window endpoints and global
longitudinal support extrema, but permits loss of intermediate local reversals.
That is its documented contract, even at zero strip-width tolerance. Using that
operation for normal extrusion loses direction-dependent geometry.

Reduced native example, all points on y=0:

```shell
x: -2 -> 0 -> 1 -> 0.5 -> 2 -> 3
```

Input length is 6. Neither the half-unit backtrack nor its neighbours are below
0.001. Both zero-tolerance degeneracy cleanup and default offset normalization
replace it with one length-5 line. With round joins and offset -1, ordinary raw
offsetting returns length 5. Raw construction supplied directly with the original
source succeeds and returns length 6 + 2*pi = 12.283185307179586: the original
straight travel and two semicircular reversal joins. JavaScript and Erlang agree.
A short-backtrack control (-1,0,0.0002,0.0001,0.0003,1) similarly loses both joins;
a monotone control (-2,0,1,2,3) preserves length with or without normalization.
These are traversal checks, not a claim that final trimming must preserve every
raw join or that the raw result equals Cavalier's trimmed output.

This is a confirmed loss mechanism and a reason to reconsider offset source
preparation. It is not a contract violation of the public degeneracy function:
that function explicitly allows the simplification. Merely lowering its tolerance
cannot repair a zero-width collinear example.

## Original CC01301 experiment

Eight copied-build runs: four variants, fitting tolerance 0.01 and 0.00001.

| Variant | Normalized segment count (0.01 / 0.00001) | Public path offset |
| --- | --- | --- |
| Baseline | 1 / 3 | Existing length 62.5850707345 / 63.3676295904 |
| Bypass fixed short-run stage only | 1 / 3 | Identical to baseline |
| Bypass both normalization stages | 7 / 7 | ConstructionFailed |
| Bypass short-run stage; normalize each segment independently | 7 / 7 | ConstructionFailed |

Copied-build error logging identifies `InternalArrangementGraphError` in the
last two variants. A separate raw-construction call for the segmentwise variant
at 0.00001 succeeds with seven output segments and length 572.3056505869621,
including two radius-81 reversal arcs. Even `NoTrimming` public path calls still
enter arrangement construction and fail; they are not raw-construction probes.
The precise underlying arrangement failure remains unisolated. No claim that
bypassing normalization alone repairs the original fixture is justified.

## History and recommendation

`210c85fa` introduced short-segment elimination with fixed tolerance 0.001 in
source normalization. `e341c796` replaced that elimination with bounded,
balanced short-run cleanup, preserving neighbours and limiting each cleanup
portion to total length upper bound at most 3*tolerance. Its tests protect long
backtracking extent and endpoint continuity. They do not establish preservation
of every reversal. The code/history establish these mechanisms, not a documented
proof that 0.001 is the appropriate universal threshold.

Recommended implementation experiment:

1. Leave the public degeneracy function's documented extent-simplification
   behavior intact.
2. Use an offset-specific cleanup that preserves traversal reversals. Independent
   segment normalization is a starting control; monotone collinear segments may
   subsequently be merged without erasing their traversal. Both the short-run
   and whole-path stages must obey this rule.
3. Check within-curve reversals and endpoint tangent changes, not just line-list
   boundaries. Avoid claiming general correctness from this collinear reduction.
4. Isolate the CC01301 arrangement failure exposed when its reversal survives.
   Then test the revised pipeline against existing normalization, offset/stroke,
   audit and figure regressions before retaining any production change.

This is more substantial than changing a threshold. It need not require a new
public option, but changes which source traversal offsetting retains.

## Evidence

- `probe-short-run-normalization.py` creates copied builds and runs the eight
  original-input settings; results in `short-run-normalization-experiment.json`.
  It logs internal errors without changing their return values.
- `probe-normalization-reversals.mjs` runs the two reversal reductions and a
  monotone control; `normalization-reversal-{baseline,preserved}.json`.
- `probe/src/normalization_reversal_probe.gleam` reproduces the long reduction
  and direct raw-construction control on Erlang; `normalization-reversal-erlang.log`.
- `short-run-segmentwise-raw.json` records the successful direct raw call;
  `short-run-segmentwise-untrimmed.json` records the failing NoTrimming path call.

Commands (Node 24.10.0; existing portable JS build):

```sh
python3 scripts/cavalier/probe-short-run-normalization.py
AUDIT_JS_BUILD=/tmp/cavalier-short-run-baseline node scripts/cavalier/probe-normalization-reversals.mjs
AUDIT_JS_BUILD=/tmp/cavalier-short-run-skip-both node scripts/cavalier/probe-normalization-reversals.mjs
AUDIT_JS_BUILD=/tmp/cavalier-short-run-segmentwise AUDIT_CASE_ID=CC01301 AUDIT_TOLERANCE=0.00001 AUDIT_RAW=1 node scripts/cavalier/probe-short-transition.mjs
AUDIT_JS_BUILD=/tmp/cavalier-short-run-segmentwise AUDIT_CASE_ID=CC01301 AUDIT_TOLERANCE=0.00001 AUDIT_TRIMMING=none node scripts/cavalier/probe-short-transition.mjs
# From scripts/cavalier/probe:
gleam run -m normalization_reversal_probe
```

No full suite or figures rerun: there is no production candidate in this checkout.
No commit or F# changes. The audit remains open.

## Subsequent overlap diagnosis

The internal arrangement error was traced further to
`InternalPathError(NonAffineOverlapCorrespondence)`. The failing pair is a
CubicBezier and a short radius-81 Arc, not two Lines. Their approximately
9.24e-5 span agrees geometrically within the 1e-9 overlap tolerance but their
parameter speeds differ. Replacing only the cubic with its chord makes that
pair's overlap query succeed. This is not yet a full original-fixture repair.
The existing `segment_linearize_if_degenerate` produces one line for that
cubic and preserves a reversing collinear cubic as three ordered lines.
The related arc-helper cleanup is tracked separately in
`ARC-CHORD-CLEANUP-EXPERIMENT.md`; traversal-preserving offset normalization
is still outstanding.
