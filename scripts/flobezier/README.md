# FloBezier geometry audit

This is a bug-finding comparison of shared geometry contracts. It is not a
claim of FloBezier parity or an attempt to adopt its entire API or certified
precision guarantees. The audit is closed against implementation `a7d8cc7`;
see [final findings](FINDINGS.md) and `closure/summary.json`.

## Source and scope

- Repository: <https://github.com/FlorisSteenkamp/FloBezier>.
- Revision: `8ad65ac79cb69989cd40b0d375a51392eb477f16`.
- Source package identifies itself as `flo-bezier3` 9.0.1.
- Downloaded 2026-10-14; exact recording time and archive SHA-256 are in
  `provenance.json`, alongside hashes of all archived files.
- Original filenames are preserved under `upstream/`, including source,
  tests/helpers, configurations, dependency lock, and the MIT license.
- The main suite has 164 specification files. Two further specification files
  live under `experiments/hausdorff`; upstream's normal Jest run excludes them.
  They remain explicitly inventoried rather than counted as covered.

[INDEX.md](INDEX.md) lists every specification file and current status.
[Findings](FINDINGS.md) records the discrepancy inventory; [first-batch
findings](FIRST_BATCH.md) preserves the original FB001 investigation.

The first file-inventory pass is complete. The unmodified normal upstream suite
passes: **164 files / 326 tests**. The index now records:

- **68 files** with selected operations compared against our JavaScript API.
- **42 files** reviewed as different or absent public contracts.
- **54 files** screened as arithmetic/infrastructure without a direct public counterpart.
- **Two experimental files**, separately source-reviewed and not executed.

There are no pending files in the original 61-file queue. This is not exhaustive
assertion parity: a compared file may contain additional assertions outside the
captured operations, and certified-precision requirements were not adopted.

The three comparison reports contain **19,063 calls**, including repeated inputs:
3,609 intersection calls, 14,526 numerical/affine calls, and 928 remaining-batch
calls. All identified groups have been fixed, clarified by an explicit convention, or
recorded as numerical/contract limitations. The final JavaScript rerun has
18,820 direct/adapted matches, 217 explicit differences, and 26 individually
reviewed raw flags; none is unclassified. Raw flags remain visible in the reports.

## Reproduce closure against an existing capture

```sh
(cd test_portable && gleam build --target javascript)
FLO_CALLS=intersections-calls.jsonl FLO_RESULTS=intersections-results.json node scripts/flobezier/intersections.mjs
node scripts/flobezier/numerics.mjs
FLO_TIMEOUT_MS=60000 node scripts/flobezier/remaining.mjs
node scripts/flobezier/closure-boundaries.mjs
python3 scripts/flobezier/close-audit.py
python3 scripts/flobezier/catalog.py
```

The longer remaining-batch timeout accommodates the repaired closest-pair query;
its five-second initial closure run timed out. Results record all differences,
not just successful matches. `baseline/` preserves pre-fix reports; other
investigation/experiment folders are historical evidence, not additional passing
regression suites. The normal repository tests contain the adopted regressions.

## Reproduce the first batch

Extract the pinned source archive into a separate working directory and install
its locked dependencies with `npm ci --ignore-scripts --no-audit --no-fund`.
Use Node 22 or newer as required by the upstream package. The first run used
Node 24.10.0 and Gleam 1.18.1.

```sh
FLO_SOURCE=/path/to/extracted/FloBezier node scripts/flobezier/capture.mjs
(cd test_portable && gleam build --target javascript)
node scripts/flobezier/intersections.mjs
(cd scripts/flobezier/probe && gleam run)
(cd scripts/flobezier/probe && gleam run --target javascript)
```

`capture.mjs` runs the selected upstream file unchanged, then runs it again with
an input/result capture wrapper. Both runs must pass. It verifies the two files
it instruments against archived hashes and restores them in a `finally` block.
Use a separate extraction, not the archived `upstream/` directory. The wrapper
captures actual inputs, including generated inputs, rather than parsing source
text for numeric literals. `intersection-calls.jsonl` records each call with its
upstream test name. The two `upstream-first-batch*.json` files record Jest results.

The comparison runner uses public Gleam `intersections.segment` on the
JavaScript target. Each query runs in an isolated worker with a five-second
limit. Point-only inputs are recorded as outside this segment adapter, not
silently turned into zero-length lines. Overlaps are compared by contract:
FloBezier returns representative endpoints; our point API should reject
continuous overlap. Matching isolated intersections use one-to-one parameter
matching at 1e-7 as an audit diagnostic, not a new library accuracy guarantee.
Returned parameters are also evaluated with independent De Casteljau arithmetic
and checked against the default geometric tolerance plus floating-point allowance.

The standalone first-batch probe is a historical diagnostic, not a regression
assertion. Current fixes and native regression coverage are listed in FINDINGS.md.

## Reproduce expanded batches

Use the same disposable extraction and installed dependencies as above:

```sh
FLO_SOURCE=/path/to/extracted/FloBezier FLO_BATCH=intersections node scripts/flobezier/capture.mjs
FLO_CALLS=intersections-calls.jsonl FLO_RESULTS=intersections-results.json node scripts/flobezier/intersections.mjs
FLO_SOURCE=/path/to/extracted/FloBezier node scripts/flobezier/capture-numerics.mjs
node scripts/flobezier/numerics.mjs
python3 scripts/flobezier/catalog.py
```

Do not run capture commands concurrently: they temporarily instrument the same
upstream extraction. Both restore original source in a `finally` block. The
intersection capture passes 20 upstream files / 55 tests before and after
instrumentation. The numerical capture passes 63 upstream files / 124 tests
before and after instrumentation. These groups overlap; do not add their test
counts and call that upstream coverage.

`numeric-scopes.json` records which upstream files are eligible for each captured
operation. The numerical hook only retains calls made directly from a test file,
including test-local helper functions; it excludes incidental library-internal
calls. Evaluation and derivative capture is restricted to their local-property
specs so integration reference loops do not dominate the inventory. Reports
retain concrete arguments, expected results, observed results and dispositions.

The comparison runners use four worker lanes and a five-second query limit.
`numeric-results.json` and `intersections-results.json` are diagnostic outputs,
not passing native tests. No fixes or commits are made by these scripts.

## Reproduce the remaining-file pass

```sh
FLO_SOURCE=/path/to/extracted/FloBezier node scripts/flobezier/capture-remaining.mjs
node scripts/flobezier/remaining.mjs
python3 scripts/flobezier/catalog.py
```

`remaining-files.json` preserves the original 61-file queue.
`remaining-review.json` records a scope decision for every one of those files,
including differences in files with captured helper calls. The unchanged and
instrumented upstream runs each pass **61 files / 122 tests**. Current results and dispositions for all 928 captured calls are in FINDINGS.md.

After rebuilding the JavaScript dependency with `gleam build --target javascript`
in `test_portable`, the comparison was rerun. A separate direct public-API probe
also reproduced the stack overflow:

```sh
node scripts/flobezier/closest-pair-stack-probe.mjs
```

That probe originally exited 1 on the stack overflow. It now succeeds, but may
exceed a short audit timeout. See FINDINGS.md for the final analytic comparison
and STACK_OVERFLOW.md for the historical investigation.
