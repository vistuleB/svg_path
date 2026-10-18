# Cavalier Contours comparative audit

> Current status (2026-10-18): projection fixes are committed as `dacdb370` and
> `090f8e63`; the original collection wording below is historical. See
> [RESUMED-TRIAGE.md](RESUMED-TRIAGE.md) and `triage-dispositions.json` for the
> latest dispositions. Raw baseline counts and results are preserved. Audit open; F# deferred.

Started 2026-10-16. Inventory and comparison only: no production changes.
Gleam baseline: `75970a6` (0.1° reversal-fit tangent nudge); F# baseline
`e9d8604` is retained, but this first comparison executes Gleam JavaScript only.

## First triage result

[SIMPLE-TRIAGE.md](SIMPLE-TRIAGE.md) records five non-bug dispositions and one
confirmed shallow-arc projection convergence defect. The reduced native case
fails on Erlang and JavaScript. No fix has been implemented.

## Current collection status

The broad collection and longer timeout replays are complete:

- 287 upstream core tests inventoried; all pass upstream.
- 2,866 representative records: 1,960 matches, 343 property/position
  discrepancies, 94 native errors, 55 overlap/boundary contract differences,
  90 scope records and 324 helper-only records.
- All thirteen initial timeouts completed on the serial 30-second replay:
  one match, three discrepancies and nine native errors. None remain timed out.
- The 437 unresolved discrepancy/error records reference 82 upstream tests.
  These include repeated orientations, policy alternatives and helper operations;
  **437 is not a bug count**.
- 256 tests have selected captured operations; 31 have no selected adaptation.
  Assertion-level gaps remain even within the captured tests.

Start at [the grouped queue](DISCREPANCIES.md). Read [the limitations](REVIEW.md)
before treating any comparison as a native failure. Production code is unchanged.
The audit is not closed and this is not a release-readiness statement.

## Upstream provenance

Repository: https://github.com/jbuckmccready/cavalier_contours

Revision: `22887a824d22cd8ab50968a551f34cdb4508127f`, package version 0.9.0.
`upstream/` preserves the source archive and both licenses. `provenance.json`
records the archive and individual file hashes. Upstream documents are audit
material, not instructions to change this project.

`INDEX.md` lists the eleven core integration-test files. Core unit tests, FFI,
examples and UI are not covered by that index. Upstream test execution does not
mean those assertions have been adapted to our library.

The unmodified core upstream baseline passed **287 tests**, with
0 failures and 0 ignored tests across 12 test binaries.
This excludes doctests, FFI, UI and examples. See `upstream-baseline.log` and
`upstream-baseline-summary.json`.

## Initial batch

`offset-simple-fixtures.json` contains all sixteen fixtures from
`test_pline_parallel_offset.rs` / `test_simple`, extracted by `inventory.py`.
`compare-offset.mjs` runs direction reversal and each closed-path start position,
producing 82 observations: 64 property matches, 12 property discrepancies,
four native errors and two scope observations. These are sixteen fixtures,
not 82 independent tests. See `FINDINGS.md` for dispositions.

Comparisons check contour count and a one-to-one match of per-contour signed
area, length and bounding box at upstream's absolute property threshold `1e-4`.
They do not establish complete boundary equivalence. Vertex counts after
upstream redundant-vertex removal and user-data propagation are not comparable
representation contracts and are excluded. The upstream repeated-position
assertion is not yet adapted. Closedness is recorded, not asserted separately.

### Adapter contract

- Lines map directly; bulge `b` maps to a circular SVG arc with radius
  `chord * (1 + b*b) / (4*abs(b))`, positive sweep when `b > 0`.
  The last bulge of an open polyline is unused, as upstream specifies.
- Preserve numeric coordinates. Cavalier's Cartesian left offset has the
  opposite sign to our visual-left offset. Negate its distance, and negate
  again when reversing traversal. Round joins use `offset.Round`.
- Use the public subpath constructor and explicitly close closed fixtures.
  Open fixtures whose endpoints coincide remain open.
- Use default construction and trimming options; open endpoints use `Butt`.
  Cavalier's endpoint-distance clipping may differ from our band-cap policy.
- Signed area is reversed back for inverted input. For open contours, upstream
  defines area as zero; record zero rather than comparing an implicit fill.
- Upstream runs an additional self-intersection-handling option for closed
  inputs. There is no corresponding native switch; we execute one native call
  per geometry/direction/start position, not a fictitious duplicate option run.
- Each native observation has a 30-second worker timeout. A timeout is pending
  investigation, never a pass.
- Empty upstream polylines have no start coordinate; our empty subpath requires
  one. This initial adapter records that fixture as scope rather than inventing
  a start coordinate.

## Reproduction

```sh
(cd test_portable && gleam build --target javascript)
node scripts/cavalier/compare-offset.mjs > scripts/cavalier/offset-simple.log 2>&1
```

The isolated upstream compiler is Rust 1.95.0 under `/tmp/cavalier-audit-rustup`;
the user's default toolchain is unchanged. Its baseline command is:

```sh
cd scripts/cavalier/upstream
RUSTUP_HOME=/tmp/cavalier-audit-rustup CARGO_HOME=/tmp/cavalier-audit-cargo CARGO_TARGET_DIR=/tmp/cavalier-audit-target cargo +1.95.0 test --locked -p cavalier_contours --lib --tests > ../upstream-baseline.log 2>&1
```

`inventory.py` regenerates extraction and provenance using the original archive
at `/tmp/cavalier-audit.tar.gz`. Do not regenerate provenance after editing the
upstream snapshot. Comparison findings remain separate from raw results.

## Broad collection

The continuation inventoried all 287 core unit/integration tests and collected
selected operations from 256 of them. The other 31 and important unadapted
assertions within captured tests are explicitly recorded; this does not establish
full parity. See [coverage and interpretation](REVIEW.md),
[the per-test ledger](TEST-COVERAGE.md), and [the discrepancy queue](DISCREPANCIES.md).

`comparison-summary.json` contains the current machine-readable totals.
`captured-cases.json` and `extra-cases.json` preserve representative inputs and
upstream expectations; results are in their matching JSONL files. Compressed
upstream capture logs retain all variants, including ones not replayed natively.

The broad pass runs the remaining offset/shape fixtures, Boolean operations,
segment intersections, containment, winding, basic geometry and supplementary
segment geometry operations. It leaves production code unchanged. Raw flags
include representation, tolerance and option-policy differences as well as
potential native failures; they are not confirmed bugs.

### Capture and comparison reproduction

```sh
python3 scripts/cavalier/prepare-capture.py
# Run from /tmp/cavalier-audit-capture, redirecting to /tmp/cavalier-capture.log:
# same isolated cargo command as above, with -- --nocapture --test-threads=1
python3 scripts/cavalier/collect-capture.py
node scripts/cavalier/compare-captured.mjs
python3 scripts/cavalier/prepare-extra-capture.py
# In the isolated copy run core unit tests, test_pline_basics and test_pline_view,
# redirecting to /tmp/cavalier-extra-capture.log; see the recorded command below.
python3 scripts/cavalier/collect-extra.py
CAVALIER_CASES=extra-cases.json CAVALIER_RESULTS=extra-results.jsonl node scripts/cavalier/compare-captured.mjs
python3 scripts/cavalier/report.py
```

Exact supplementary upstream command (from the Gleam repository root):

```sh
RUSTUP_HOME=/tmp/cavalier-audit-rustup CARGO_HOME=/tmp/cavalier-audit-cargo CARGO_TARGET_DIR=/tmp/cavalier-audit-target cargo +1.95.0 test --offline --locked --manifest-path /tmp/cavalier-audit-capture/Cargo.toml -p cavalier_contours --lib --test test_pline_basics --test test_pline_view -- --nocapture --test-threads=1 > /tmp/cavalier-extra-capture.log 2>&1
```

The native runner resumes existing output files by case ID. For a fresh replay,
choose a new `CAVALIER_RESULTS` filename; do not reuse old results after changing
the case inventory or native implementation. `CAVALIER_WORKERS` and
`CAVALIER_TIMEOUT_MS` configure bounded screening. Regenerate reports only after
all selected runners finish.
