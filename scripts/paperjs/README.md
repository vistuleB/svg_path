# Paper.js regression compatibility audit

This is an unfinished audit, not a claim of Paper.js compatibility or a release
qualification. The first pass was diagnostic; crossing fix `e55a433` was subsequently approved
and committed. See `BOOLEAN_AUDIT.md` for the baseline and follow-up results.

Upstream: https://github.com/paperjs/paper.js
Revision: `92775f5279c05fb7f0a743e9e7fa02cd40ec1e70` (`develop`, inspected 2026-10-12).
The five original test files and MIT license are under `upstream/`.
`inventory.json` records their SHA-256 hashes and all 146 top-level test blocks:
50 Boolean, 24 intersection, 17 curve, 40 general path, and 15 containment blocks. Blocks may
contain multiple fixtures, loops, and assertions. These are not coverage percentages.

## First milestone: intersection point locations

`intersections.json` contains 32 extracted assertions from all 24 intersection
blocks. Original expected coordinates, curve indices, parameters and crossing
flags are retained. Current executable checks cover counts and unordered point
positions for the 29 `getIntersections` assertions. Three `getCrossings`
assertions, parameter/address checks, crossing classification and object-level
`intersects` assertions remain pending. Curve and path entry points currently
both exercise Gleam's path query; separate segment-level checks remain pending.

The initial runs on both Erlang and JavaScript returned 21 passing location
checks and eight discrepancies. Investigation on 2026-10-12 classified **all eight
as different API expectations, not confirmed bugs under the current contracts**.
`intersection-status.json` records each classification; `discrepancy-findings.json`
retains the query outputs and higher-precision numerical evidence.

The existing 21 matching location checks remain in the ordinary/portable suites.
The raw upstream comparison still fails eight assertions: its original counts
and point-only queries have deliberately not been weakened or replaced. An
adapted contract-aware suite is a separate remaining task.

| Fixture IDs | Upstream | Classification and evidence |
| --- | --- | --- |
| 12 | #1073 issue comment | Different API: partial cubic overlap, which the point-only query rejects. The right curve coincides with the left interval approximately `[0.27769147597427946, 1]`; a control-polygon error bound is `1.554e-10`, below the `1e-9` tolerance. Paper.js also identifies the overlap. |
| 13 | #1074 | Different API: multiple tolerance-valid near-tangent candidates. Maximum independently evaluated pair separation `1.752e-12`; both expected endpoint contacts remain present. |
| 18 | #1233 | Different API: Paper.js accepts an additional near endpoint contact whose reported parameter pair is separated by `7.698e-8`. The endpoint cannot meet the other curve within our `1e-9` tolerance; the three genuine crossings remain. This is NOT an adjacent-endpoint/arc-length exclusion. |
| 19 | #1239 | Different API: an identical shared cubic segment is a continuous overlap. `intersections.path` intentionally rejects it; `encounters.path` reports the overlap and point candidates. |
| 23, 24 | #1284 sketch 2 | Different API: two tolerance-valid near-tangent candidates rather than one. Maximum separation `1.019e-12`. These are the same geometric fixture through two upstream entry points. |
| 27 | #1262 | Different API: six tolerance-valid candidates rather than two exact endpoint roots. Maximum separation `5.337e-14`. The extra four are not additional mathematical roots. |
| 31 | #1255 | Different API: three tolerance-valid candidates rather than one. Maximum separation `8.912e-13`; the endpoint contact remains present. |

### Why the tangency cases are not classified as contract bugs

`src/svg_path/intersections.gleam`, module documentation, explicitly permits
multiple acceptable candidates for one mathematical contact near tangency.
`IntersectionOptions.tolerance` bounds geometric separation of the two evaluated
points; it does not bound distance along the curve to a unique exact root.
At a tangency, those are very different requirements. Default parameter snapping
is disabled. Re-evaluating reported pairs with 80-digit decimal arithmetic
(starting from the exact binary64 coordinates and parameters) confirms all the
candidates satisfy the default `1e-9` geometric tolerance.

Fixture 27 makes the distinction especially clear. Both cubics have identical,
strictly increasing x coordinates, so equality forces `t = u`. Their only
control-point difference is in the second y control, giving a y difference of
`3 * delta * t^2 * (1-t)`. The exact roots are just 0 and 1. The extra candidates
are therefore approximate contacts allowed by our API, not additional roots.
This remains a potential API-quality improvement if unique-root counts are
wanted, but it is not evidence of a violation of the existing guarantee.
Do not increase merge thresholds globally to imitate Paper.js's counts.

### The self-contact discrepancy

Paper.js 0.12.18 reports the extra contact between segment 1 at `t = 0` and
segment 3 at `u = 0.9994523254767491`. Their separation is about `7.698e-8`.
This is not just an inaccurate estimate of the same endpoint root: segment 3's
y-coordinate is strictly increasing. The entire parameter interval whose y is
within `1e-9` of that endpoint is approximately
`[0.9994523255195332, 0.9994523255272500]`. Its x-coordinate is decreasing and
remains at least `6.669e-8` away. Thus no parameter meets our coincidence tolerance
at the endpoint. Independent high-precision Newton refinement also converges to
the first of the three already-reported interior crossings.

### Overlap representation

Paper.js includes overlap boundaries in its intersection locations. Our
point-only query returns `OverlappingSegments` instead; this is intentional.
For fixture 12, splitting the left cubic at the reported start and comparing
all four resulting controls with the right cubic bounds the separation over
the WHOLE affine-matched interval (not just sampled points). Fixture 19's shared
segment controls are identical.

`encounters.path` returns these overlaps. Its raw point list can also contain
redundant candidates along overlaps; `encounters.subpath` explicitly documents
the unfiltered view and offers `subpath_remove_redundant_intersections` as an
optional derived view. Therefore merely switching query names and retaining
Paper.js's exact point count is not a valid compatibility assertion either.

No library code or test expectations were changed during this investigation.
No confirmed library bug was found in these eight mismatches. This conclusion
is limited to the examined discrepancies; parameter and crossing assertions,
Boolean tests and the rest of the corpus have not yet been audited.

## Reproduction

Normal regression checks, including the 21 accepted location assertions:

```sh
scripts/test-portable
```

Raw upstream intersection comparison (eight contract mismatches on both targets):

```sh
scripts/test-paperjs
# Or: scripts/test-paperjs erlang / scripts/test-paperjs javascript
```

The standalone audit package isolates raw compatibility assertions from the
established regression suite. Its eight remaining failures now have documented
API explanations, but contract-aware replacement assertions are still needed
before claiming the planned coverage milestone is complete. Run this command
as well as `scripts/test-release` when reviewing the milestone.

To regenerate the captured input geometry, install the pinned Paper.js runtime
in a temporary directory, then run:

```sh
npm install --prefix /tmp/svg-path-paper-audit paper@0.12.18 --ignore-scripts --no-audit --no-fund
node scripts/paperjs/extract-intersections.cjs /tmp/svg-path-paper-audit/node_modules/paper
python3 scripts/paperjs/generate-intersections.py
```

The extractor uses Paper.js only for constructors and transforms. It replaces
intersection methods before loading the tests; expected answers come from the
upstream assertions, not from running Paper.js's solver. It preserves all cubic
control coordinates, including zero-handle cubic lines and Bézier circles.
Deferred item transforms are baked into geometry and expected point coordinates.
This corrected a misleading initial failure in the `applyMatrix: false` fixture.
The runtime used for extraction is separately pinned because it is not a build
of the upstream test revision. Generated JSON is checked in, so running Gleam
tests requires neither npm nor Paper.js.

Point comparisons use one-to-one matching with an absolute per-coordinate
allowance of 1e-5, matching the precision of upstream's rounded coordinates.
This is a fixture comparison allowance, not the solver's tolerance. Input
coordinates are not rounded. No scale variants have been added yet.

After a JavaScript portable build, `node scripts/paperjs/probe-intersections.mjs`
prints detailed current results to help investigate disagreements.

## Remaining work

1. Adapt the eight classified API differences into contract-aware assertions;
   add address and crossing assertions, segment-level calls, and useful
   transformed variants. Keep the raw comparison available as evidence.
2. Adapt the 50 Boolean blocks with geometric region assertions independent of
   serialization order and curve subdivision. Preserve native cubic fixtures.
3. Audit the 17 curve blocks and the applicable portion of 40 general path blocks.
4. Mirror accepted fixtures and fixes into F#, then perform release validation.

Do not label an entire upstream block covered merely because its point-location
check passes. Keep upstream licensing and issue references with adaptations.

## Boolean batch

The first Boolean screening and native failure reproducers are recorded in
[BOOLEAN_AUDIT.md](BOOLEAN_AUDIT.md). It covers 178 extracted comparisons, adds
16 portable basic regressions, and identifies three confirmed native failures.
It is not complete Boolean compatibility coverage.


## Curve evaluation and length batch

`curves.json` retains 45 comparisons extracted from nine of the 17 Curve.js
blocks. `extract-curves.cjs` executes Paper 0.12.18 for construction and setup;
expected values come from explicit upstream assertions. One arc-length input
is derived from Paper's curve length. Legacy aliases and out-of-range point
queries are not covered; the other eight blocks remain pending.

`curve-screening.json` records 42 direct matches and three differences.
`curve-status.json` classifies all three as API expectations:

- Fixtures 32 and 36: a straight cubic has zero derivative at its endpoints.
  Paper returns zero curvature; our API documents `DegenerateCurvatureDerivative`.
- Fixture 38 (#1000): Paper snaps the inverse-length parameter to 1. Our returned
  parameter is 0.9999980926513672. Independent 60-digit evaluation of the exact
  straight-cubic distance polynomial gives residual 6.984341993643259e-10,
  within the default 1e-9 distance tolerance. Parameter error is not distance error.

The adapter uses our visual-left normal `(dy, -dx)` and negates our signed
left-normal curvature to match Paper's curvature sign. Weighted tangents map to
parameter derivatives. Rounded upstream point/weighted-vector coordinates allow
1e-5 per component; unit vectors allow 1e-7, curvature 1e-12, length and ordinary
inverse-length comparisons 1e-8. Exact endpoint coordinate assertions stay exact.

All 45 cases are in `test/svg_path_paper_curves_test.gleam`, with the three
contract differences tested explicitly instead of changing the upstream data.
`scripts/test-portable` passed 488 tests on Erlang and 488 on JavaScript.

Reproduce:

```sh
node scripts/paperjs/extract-curves.cjs /tmp/svg-path-paper-audit/node_modules/paper
node scripts/paperjs/probe-curves.mjs
python3 scripts/paperjs/generate-curves.py
gleam format test/svg_path_paper_curves_test.gleam
```

The pinned `PathItem_Contains.js` was downloaded for the next batch.


## Containment batch

`containment.json` preserves 331 assertions over 24 distinct geometries from 13
of 15 blocks in the pinned `PathItem_Contains.js`. All 331 match the JavaScript
screen (`containment-screening.json`). Native tests group the same assertions
into 13 tests in `test/svg_path_paper_containment_test.gleam`.

The adapter preserves absolute cubic controls, global transforms, closure and
fill rules. It maps both `Inside` and `Boundary` to Paper's `contains() = true`.
Compound paths, even-odd/nonzero fill, implicit closure of open paths, boundary
contacts, stationary points and the upstream complex-shape cases are included.

Two blocks are explicitly unadapted: analytic Shape-object containment and
non-invertible item matrices. Converting analytic ellipses to cubic paths would
change their geometry, and item transform validity has no direct equivalent in
a plain path. Six extracted queries use Paper-computed `interiorPoint` values:
these test our containment at those saved points, not our ability to choose an
interior point. Paper also performs upstream construction/reorientation setup;
the preserved geometry is the input to our query, not an end-to-end test of
those setup methods. No new production changes resulted from these batches.

```sh
node scripts/paperjs/extract-containment.cjs /tmp/svg-path-paper-audit/node_modules/paper
node scripts/paperjs/probe-containment.mjs
python3 scripts/paperjs/generate-containment.py
gleam format test/svg_path_paper_containment_test.gleam
```

Final validation after both new batches: `scripts/test-portable` passed 501 tests
on Erlang and 501 on JavaScript; `scripts/test-fast` passed 1,786 tests.
The slow/full release profiles were not run. Crossing fix `e55a433` is committed; comparison fixtures, generators, reports
and suite registration are preserved in the subsequent audit commit.


## Remaining work at this checkpoint

- `Path.js`: all 40 blocks await triage. Length, area, joining, reversal,
  flattening and splitting are relevant; selection, scene ownership and other
  editor-object behavior may have no library equivalent.
- `Curve.js`: eight blocks remain unadapted (classification, general inverse
  length, location lookup, straight/linear predicates, point-to-parameter lookup,
  division and tangent-direction roots). The nine extracted blocks also omit
  legacy aliases and some out-of-range checks.
- Boolean screening: 76 library-error comparisons still need classification;
  fixtures 69 and 172 are confirmed topology failures awaiting approval to fix.
  Fixture 16's remaining overlap error is an accepted limitation. Seven
  comparisons need other adapters. The full screen predates the crossing fix;
  counts are not fresh results for the current source. The 92 sampled matches
  are not exhaustive region equivalence tests.
- Intersections: crossing-only queries, parameter/address checks and crossing
  classification remain, plus independent segment-entry-point coverage. The
  eight raw location discrepancies are classified API differences.
- Containment: two object-level blocks are unadapted; saved Paper-generated
  interior points do not test our own interior-point selection.
- The five downloaded files are a subset of Paper.js's suite. Other potential
  geometry sources include `PathItem.js`, `CompoundPath.js`, `CurveLocation.js`,
  `Path_Constructors.js`, `Item_Bounds.js`, `Matrix.js`, `Numerical.js`, and SVG
  import/export tests. Their applicability has not yet been audited.

Recommended next batch: geometry-focused `Path.js` cases, then the remaining
curve inversion/splitting cases. Continue classifying Boolean errors separately.
