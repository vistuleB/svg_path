# Flatten.js geometry audit

**3.x compatibility update:** the FL004 boundary guard remains active, but its
new public error case is deferred to 4.0.0 in both languages. Current 3.x code
returns the existing arrangement-construction error. Historical descriptions
below retain the original diagnostic. See [API-001](../../DEFERRED-API.md).

## Current status after FL006 fixes

FL006's missed crossing and backwards endpoint-overlap suppression are fixed in
Gleam. The twelve reconciled comparisons pass with both adapter policies;
the two native-output chains also pass their sampled checks. See
[the implementation and validation](FL006-OVERLAP-FIX.md).

All FL002–FL006 fixes are ported and tested in F#; see [the port checklist](FSHARP-PORT-STATUS.md). FL004 retains its explicit size-policy limitation.
Broader assertion coverage gaps remain; this is not a claim of full upstream
parity or release readiness. Historical comparison records are preserved.

Bug-finding comparison of overlapping public contracts, started 2026-10-15.
Production geometry code was unchanged during inventory. FL001 now has a validated
fix documented in FINDINGS.md. This audit is separate from the completed
Paper.js, SVGO and FloBezier investigations and does not claim complete parity.

## Pinned upstream

- Repository: https://github.com/alexbol99/flatten-js
- Revision: `5c02ff087b16d82c8c7d3a76086856c2bd3df58f`
- Package: `@flatten-js/core` 1.6.14
- Archive: `upstream/`, preserving original filenames and MIT license.
- `provenance.json`: download time, tarball hash and SHA-256 of all 184 files.
- 23 test files; the unmodified source baseline passed **544 tests**.
  `upstream-baseline.json` records file/test names and outcomes.

[INDEX.md](INDEX.md) is the file-by-file inventory. Pending means unreviewed,
not failed. Comparisons capture public calls made by selected tests; they do not
reproduce every assertion in those files.

## First batch: arcs and circles

`run-upstream.cjs arc-circle` executes both original test files with runtime
wrappers on selected methods/getters. All 93 tests pass with capture enabled;
116 outermost calls from 42 test cases are retained in `arc-circle-calls.jsonl`. Calls include
repeated inputs and helper queries; this is not 116 independent tests. The
wrappers do not edit upstream source, change inputs or alter return values.

The adapter uses the existing Gleam JavaScript build of release 3.1.2:

- Circular arcs map to SVG arcs, split into spans no larger than a quarter turn.
  This represents full circles without illegal coincident-endpoint SVG arcs.
  Flatten's increasing-angle direction maps to SVG's positive sweep; no y-axis
  reflection is applied to either numeric coordinate system.
- Box and polygon boundaries map to their line/arc segments. Circle containment
  is a filled-disk query; arc containment is a boundary-membership query.
- Infinite-line intersection uses the public supporting-line crossing query,
  retaining both signs of the ray parameter. Infinite-line distance is deferred
  rather than approximated by an arbitrarily truncated segment.
- Intersection positions are deduplicated at a diagnostic `1e-6`, matching
  upstream's default `DP_TOL`. This is a comparison threshold, not a new library
  tolerance or accuracy guarantee. Native queries retain their defaults.
- Continuous overlaps deliberately have different output contracts: Flatten
  may return overlap endpoints or a representative point. Our overlap error
  is classified separately for coincident circular supports and native
  `OverlappingSegments` results for line pairs.
- A zero-radius circle is recorded as a contract difference, not silently
  converted to a nondegenerate SVG arc.
- Shape-to-shape distance uses the public path closest-pair query so its
  bounding-box pruning remains active. An initial exhaustive segment-pair
  adapter timed out on an irrelevant pair; see [findings](FINDINGS.md).
- Each comparison has its own worker and 30-second limit. Timeouts are recorded
  as needing investigation, not as confirmed bugs or passing comparisons.

Final first-batch result: **110 matches, four understood continuous-overlap
contract differences, two scope differences, zero unclassified comparisons**.
The continuation adds 30 arc operations (all matches) and 271 segment/line/ray
calls: **194 matches, eight overlap-contract differences, 67 scope differences,
and two failures from one confirmed JavaScript stack-overflow bug (FL001)**.
There are no unclassified comparison discrepancies in these batches.

The continuation covers primitives (82 upstream tests), polygons/Boolean/ray
shooting (131), and faces/multilines (41). Capture-mode upstream runs pass.
Primitive comparison: 190 matches, nine scope calls. Chain comparison: 182
matches, 20 scope calls. Polygon comparison: 4,865 ordinary matches, 53 sampled
Boolean matches, 29 scope calls, and **21 flags deferred for investigation**.
These counts include many helper/repeated calls, especially 4,736 segment bounds
getters; they are not independent regression counts.

The first-pass inventory now covers **all 23 files and 544 upstream tests**.
Sixteen files have captured operation comparisons; seven have scope-only reviews.
The final residual run passed 57 upstream tests and recorded three sampled
Boolean matches, one point-to-set distance match and 101 scope calls, with no
new flag.

This is inventory completion, **not complete parity or assertion coverage**.
`inventory.json` records 374 tests with selected captured operations (including
helper-only captures), 165 scope-reviewed tests, and five tests whose principal
adaptation is explicitly deferred. Additional assertion gaps also occur inside
the 374 captured tests. [COVERAGE-GAPS.md](COVERAGE-GAPS.md) names affected files
and tests in seven categories; [REVIEW.md](REVIEW.md) explains the comparison
limits. No test/file remains marked as unreviewed.

[DISCREPANCIES.md](DISCREPANCIES.md) is the deferred queue: the two earlier calls
triggering confirmed bug FL001 plus 21 new observations. [FINDINGS.md](FINDINGS.md)
distinguishes native-query failures from conversion failures and sampled output
disagreements. Raw observations remain separate from `dispositions.json`.

## Reproduction

```sh
(cd scripts/flatten/upstream && npm ci --ignore-scripts --no-audit --no-fund)
node scripts/flatten/run-upstream.cjs baseline
node scripts/flatten/run-upstream.cjs arc-circle
(cd test_portable && gleam build --target javascript)
node scripts/flatten/compare-arc-circle.mjs
node scripts/flatten/run-upstream.cjs arc-extra
FLATTEN_BATCH=arc-extra node scripts/flatten/compare-arc-circle.mjs
node scripts/flatten/run-upstream.cjs linear
FLATTEN_BATCH=linear node scripts/flatten/compare-arc-circle.mjs
node scripts/flatten/run-upstream.cjs primitives
FLATTEN_BATCH=primitives node scripts/flatten/compare-arc-circle.mjs
node scripts/flatten/run-upstream.cjs polygons
FLATTEN_BATCH=polygons node scripts/flatten/compare-arc-circle.mjs
node scripts/flatten/run-upstream.cjs chains
FLATTEN_BATCH=chains node scripts/flatten/compare-arc-circle.mjs
node scripts/flatten/run-upstream.cjs residual
FLATTEN_BATCH=residual node scripts/flatten/compare-arc-circle.mjs
node scripts/flatten/probe-distance-stack.mjs
python3 scripts/flatten/catalog.py
```

Installation disables lifecycle scripts. Dependencies and coverage/cache outputs
are ignored; the source archive remains hash-verified. Capture and comparison
logs are stored beside their machine-readable reports.

## Remaining scope after triage

FL002–FL006 ports are complete and fully tested. FL004 retains its documented minimum-length
limitation; no automatic threshold override is applied.
The twelve conversion cases are now executed; FL006 is fixed and validated. Their sampled comparison coverage is described in CONTINUITY-REPLAY.md.
Stronger boundary
checks, cutting/clipping, island grouping, point-based splitting, distance
witnesses and path-string round trips remain explicit adaptation gaps, not
silently passing tests. Whole-shape relations/validity are recorded as API-scope
ideas. FL001 is fixed in both implementations; FL005 is fixed in Gleam.
