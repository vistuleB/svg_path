# FL006 extra ranking sample: benchmark and tests

Follow-up: [five-sample replacement comparison](FL006-REPLACEMENT.md). The
working tree now contains that replacement candidate; this report preserves the
earlier additive experiment.

2026-10-15. Baseline: `2a2f94a299ec06cd81e60dc37593d5f281a755be`.
Candidate: working-tree change in `elizabeth_window_score`, plus a regression in
`svg_path_elizabeth_test`. Not committed. F# not changed.

## Candidate

Retain the four corner samples and midpoint. The sixth sample uses the chord
crossing if present, otherwise the closest chord parameters. Unlike the initial
runtime experiment, do not add a redundant closest-chord sample when the chords
cross. This affects ranking only when surviving windows exceed the beam budget.

## Timing

Node.js v24.10.0, Gleam 1.18.1. Machine details and generated-runtime hashes are
in `remaining-fl006-benchmark.json`. Timings ran after all test processes exited,
with both runtimes in one process, one warm-up batch each, then seven alternating
baseline/candidate rounds. No diagnostic instrumentation in either timed runtime.

Fixed corpus: 374 distinct curve pairs captured from 150 passing existing portable
intersection/overlap-related tests, plus the FL006 pair. Existing pairs comprise
324 cubic/cubic, 35 arc/arc, 13 quadratic/quadratic, one cubic/quadratic and one
arc/cubic. Inputs and tolerance/depth are frozen in `fl006-benchmark-corpus.json`.
Queries use the public segment API, with parameter snapping disabled consistently
in both versions. These are solver workloads, not whole-test or CSG timings.

| Measurement | Baseline | Candidate | Difference |
| --- | ---: | ---: | ---: |
| Median whole 375-pair batch | 3.258 s | 3.307 s | +1.5% |
| Whole-batch range, seven rounds | 3.227–3.370 s | 3.279–3.355 s | overlapping ranges |
| FL006 pair, median | 111.3 ms | 151.8 ms | +36.4% |
| Sum of individual medians, 374 existing pairs | 3.146 s | 3.134 s | -0.4% |

The sum of per-pair medians is not the median of a complete batch. It helps
separate the recovered FL006 work from the existing workloads. The largest
existing absolute per-pair increase was 1.32 ms (56.99 → 58.31 ms). Several
roughly 7 ms cases increased by 8–10%; others became faster. This is not a
statistical claim of zero cost, nor an Erlang/F# performance measurement.

Verdict: no broad slowdown evident in this corpus; the recovered case itself
costs more because its crossing window now survives and is refined. The timing
cost alone does not justify dropping the midpoint or rejecting this candidate.

## Result changes and limitations

All 374 existing pairs retain their success/error category. Nine change hit
count: corpus indices 27, 86, 90, 93, 96, 100, 103, 140, 202. The changed clusters
are near endpoint contacts with nearly parallel tangents. Existing interior
crossings remain in the latter two cases. Index 27 loses one near-endpoint
candidate while retaining the exact endpoint; the others return more candidates
near an endpoint. Both versions already exhibit multiple near-endpoint answers.

The candidate points have pair separations no greater than 4.55e-13 in those
nine cases. That demonstrates numerical coincidence, not a proof that each is
a distinct mathematical root. This investigation does **not** certify those
hit lists as equivalent or declare all changed counts desirable. The extra
sample changes the existing sensitivity of endpoint/tangency candidate selection.
Raw parameters and tangent/separation measurements are saved in
`remaining-fl006-result-changes.json`; rerun with
`node scripts/flatten/check-fl006-result-changes.mjs` after the benchmark.

FL006 changes from zero to one crossing as intended. The separate Boolean
short-pair overlap classification described in `FL006-INVESTIGATION.md` remains
open. This is not closure of the entire FL006 Boolean discrepancy.

## Validation

`scripts/test-release` completed successfully with the candidate:

- Main: 2,035 passed.
- Slow: 31 passed.
- Portable Erlang: 781 passed.
- Portable JavaScript: 781 passed.

The new portable regression checks the FL006 crossing in both operand orders,
against the independently computed point and with curve-evaluation agreement.
Full output is `remaining-fl006-release.log`. `git diff --check` passed.
Figures were not regenerated for this benchmark request.

## Repeating timings

Keep separate compiled JavaScript runtime snapshots for baseline and candidate
(the complete `test_portable/build/dev/javascript` directory, not just one file).
The recorded baseline was copied before the source edit; the candidate was the
build validated by `scripts/test-release`. Then run:

```sh
node scripts/flatten/benchmark-fl006.mjs \
  /tmp/fl006-baseline-runtime \
  "$PWD/test_portable/build/dev/javascript" \
  /tmp/fl006-repeat.json
```

Use a new output filename for repeats. The runner records all seven total times,
per-pair median times and first-round outputs. Runtime and corpus hashes identify
the measured inputs. Do not benchmark concurrently with test/figure jobs.
