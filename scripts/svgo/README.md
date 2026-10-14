# SVGO path-minification audit

This is a standalone compatibility investigation, not a production test suite or a claim of SVGO parity. No library behavior is changed by this audit.

The reference is SVGO **4.1.0**, revision `5765cbe4e0a930dca648c6b81d335b1522cd7375`, downloaded 2026-10-14 from <https://github.com/svg/svgo>. `provenance.json` records SHA-256 hashes of the archived upstream files. The upstream MIT license is retained in `upstream/LICENSE`. The npm dependency is locked; its `convertPathData.js` and `_path.js` were compared byte-for-byte with the archived release source.

All 40 `convertPathData` fixtures (181 input paths) have been reviewed. See `SUMMARY.md`, `INDEX.md`, `FIRST_BATCH.md` and `REMAINING_FIXTURES.md`. No discrepancy remains unclassified in this fixture set. Additional groups are now covered in `EXTENDED_AUDIT.md` and `EXTRA_INDEX.md`: 113 plugin fixtures in total have applicable comparisons or explicit contract classifications, plus 22 standalone tests. The remaining 262 plugin fixtures have upstream baseline verification only.

## Reproduce

From the repository root:

```sh
npm ci --prefix scripts/svgo --ignore-scripts --no-audit --no-fund
(cd test_portable && gleam build --target javascript)
python3 scripts/svgo/extract.py
node scripts/svgo/audit.mjs
python3 scripts/svgo/report.py
node scripts/svgo/numerical-probes.mjs
```

The harness uses the JavaScript build of our public parsing, serialization and point-evaluation API. It uses `serialize.minifying_options` with the fixture's `floatPrecision` (3 by default; fixtures 15, 16 and 17 use 2, 0 and 8). The standard preset already enables H/V and S/T shorthands. No alternate options are selected per case to improve the results.

SVGO receives each complete original SVG, including CSS, markers and stroke attributes, with the original fixture options and only the `convertPathData` plugin enabled. Each fixture is optimized twice, matching the upstream runner. Both complete SVG outputs must equal the pinned expected output. Our serializer receives path geometry alone; context-dependent differences are recorded explicitly. When SVGO removes a transform, the harness first applies our public transform parser and path-transform API, explicitly normalizing degenerate SVG arcs. When SVGO retains a transform, the harness retains local coordinates. This adapts the geometry comparison to the same coordinate frame; it does not implement or validate a document-level flattening decision or attribute rewriting. All 29 flattened cases also compare sampled transformed points with matrix-mapped original points.

Byte counts cover uncompressed `d` strings, not whole SVGs or gzip size. Geometry diagnostics compare subpath starts and 17 equally spaced parameters on corresponding segments when segment/subpath counts match. They do not prove equivalence or establish a general rounding bound. Null means structural comparison was not applicable. All valid emitted paths are parsed again, independently decoded by SVGO's parser and compared as complete parsed command geometry, and checked for second-pass serialization stability; stability is an observation, not a newly imposed public contract.

`review.json` records manual dispositions for nontrivial differences. The runner rejects unclassified differences in the reviewed batch. Raw observations are in `all-fixtures.json` and the first-five subset `first-batch.json`. Arc precision probes are in `numerical-probes.json`. The runner verifies archived hashes and byte equality of the installed SVGO optimizer/helper source against the archive. `--explore` allows unclassified results while extending the investigation; the default run rejects them. These scripts regenerate their reports and do not modify library source or ordinary test suites.

## Completed scope and validation

Completed on 2026-10-14 against Gleam source revision `28bb4088c8ed1536e2d56077ec0fac8f0f9c0de6`, with Gleam 1.18.1 and Node v24.10.0. `gleam build --target javascript` in `test_portable` completed successfully. The default audit and report commands completed: 40 fixtures, 80 successful upstream pass comparisons, 180 valid path round trips with independent parser agreement, one expected malformed input, and no unclassified differences. Numerical probes completed for five transformed arc cases at four precision settings.

No library source, ordinary test files or release metadata was changed. No full test-suite result is claimed. This section records the original convertPathData pass. See `EXTENDED_AUDIT.md` for the subsequent completed groups and the external visual-corpus scope boundary.

## Run the extended audit

After installing the locked npm dependencies, run:

```sh
bash scripts/svgo/run-audit
```

This builds the JavaScript dependency, regenerates fixture extraction, verifies original and extended groups, and refreshes diagnostic JSON/reports. It does not download the external visual corpus, run Erlang tests, or claim whole-SVG rendering parity. The manually written interpretation remains in `EXTENDED_AUDIT.md` and `REMAINING_FIXTURES.md`.

## Compact separator follow-up

`node scripts/svgo/separator-check.mjs` compares the current JavaScript serializer
with the preserved pre-change `all-fixtures.json` baseline at commit `f36b5df`
(the later level 2 policies require the broader check below). Build first with
`scripts/test-portable all fast`. It writes a separate `separator-check.json`;
it does not replace the baseline audit reports.

The level 1 change removes optional spaces before leading decimal points when
the preceding numeric token already contains a decimal point or exponent. It
applies within curve arguments and between repeated command chunks. Integer
boundaries retain their required separator. Command choices, numeric precision,
arc flags, and serializer options are unchanged.

Across the 180 valid path cases, seven outputs become shorter, saving 14 bytes
(6,369 to 6,355). Both our parser and SVGO's independent parser return exactly
the same data before and after; the non-whitespace text is also unchanged.
Three regression tests cover curve groups, repeated commands with both newline
layouts, integer boundaries, signs, and existing exponent output. This does
not implement scientific-notation selection or any other level 2/3 policy.

## Level 2 compact policies

`node scripts/svgo/level2-check.mjs` checks the current serializer against the
preserved baseline and writes `level2-check.json`. Compact initial lines prefer
an enabled H/V command when its prefix is strictly shorter than the implicit
coordinate pair. Compact, unpadded AtMost numbers may use scientific notation
when that shortens the already-rounded decimal text. Fixed, padded, and
noncompact numeric formatting retain their existing layouts. No option was added.

All 180 valid cases pass the comparison and serialize stably. Across both
levels, 72 paths improve, from 6,369 to 6,223 bytes (146 saved); level 2 saves
132 additional bytes beyond level 1. No case grows. The check compares parsed
geometry with the baseline and with SVGO's independent parser expansion, using
relative/absolute tolerance 1e-12 for floating-point parsing differences. This
is not a geometric approximation bound. Scientific rewriting preserves the exact
rounded decimal value, although parsers may compute different last binary bits.

Initial H/V selection is a local prefix comparison, not a search over subsequent
command runs. Scientific selection uses an integer significand and retains the
existing spelling on equal length. Mixed absolute/relative command selection,
new precision options, and curve conversion remain deferred.

## Further suggestions

See [LEVEL_3_SUGGESTIONS.md](LEVEL_3_SUGGESTIONS.md) for the remaining design
questions, API-preserving opportunities, and recommendations to defer new options.

The follow-up [POLICY_EXPERIMENTS.md](POLICY_EXPERIMENTS.md) records the
whole-path comparison recipe and the command-run experiment verdict.
