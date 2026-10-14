> Historical snapshots, preserved on 2026-10-14. Statements about pending work
> and old failure counts below are superseded by [the current index](README.md).

# Paper.js regression compatibility audit

## Current status (2026-10-13)

**The final bug-finding review is complete; long SVG parsing remains unfixed.**
The [JavaScript construction/closure fix](LARGE_CONSTRUCTION_FIX.md) now passes
the full release suite, including 100,000-segment regressions.
The [zero-length-line stroke defect](STROKE_ZERO_ARC_FIX.md) is now fixed and
passed the full release suite.
See [FINAL_AUDIT.md](FINAL_AUDIT.md) for reproductions, validation and API
suggestions. This is not a claim of Paper.js parity or release readiness.
The final pass screened all 37 upstream test files for relevance, closed the
remaining core dispositions, and found a JavaScript long-path stack overflow
and a cross-target stroke failure involving zero-length edges beside arcs.
The sections below retain chronological checkpoints. Their old "remaining work"
and failure counts are historical, not a consolidated current status.

The [Boolean error triage](BOOLEAN_ERROR_TRIAGE.md) classified all 69 saved
errors. The [tangent-order fix](BOOLEAN_TANGENT_FIX.md) recovered fixtures 69
and 172; the [Bernstein line-root fallback](CROSSING_BERNSTEIN_FIX.md) recovers
103, 168 and 169. The [face-winding classifier](FACE_WINDING_FIX.md) recovers
79 and 113. The [certified full-overlap fix](FULL_OVERLAP_FIX.md) recovers
107, 122 and 123. The area-only 178-case screen has **112 sampled matches**,
**59 understood overlap-contract limitations**, and seven cases requiring
adapters. All 109 pre-overlap-fix matches remain matches; the 59 errors are unchanged.
The [seven adapter cases](BOOLEAN_ADAPTERS.md) now pass separate portable
regressions on Erlang and JavaScript, bringing the combined inventory to
**119 matched/adapted comparisons and 59 understood limitations**. No unclassified
Boolean discrepancy or unexecuted adapter case remains in this 178-case set.
Classification and sampled comparisons do not establish complete parity.

The separate [#973 orientation assertion](BOOLEAN_ORIENTATION.md), previously
unadapted, now matches through `csg.nested_contours` on both runtimes. Its three
contour orientations agree exactly; supplementary checks cover signed winding
and filled-region equivalence. This is separate from the 178 geometry comparisons.

The [six Path.js arc-construction cases](PATH_ARCS.md) are classified: five
require a three-point constructor absent from our API; #1613 matches after
explicit SVG arc normalization. None establishes a library defect.

The [Path.js tangent-offset query](PATH_TANGENTS.md) is covered by two
adapted geometric regressions using projection roots, canonical addresses
and length measurements. The missing-direction call has no counterpart;
there is no single public path-level inverse tangent query.

The [coincident-node simplification case](PATH_COINCIDENT.md) maps to
degeneracy normalization: two zero-length edges become an empty subpath
retaining the anchor. This does not equate the general simplification APIs.

The [128–131 investigation](NEW_OVERLAP_REJECTIONS.md) independently classified
all four newly exposed rejections as documented overlap-contract limitations.
The [107/122/123 investigation](FINAL_BOOLEAN_INVESTIGATION.md) records the
pre-fix overlap-merging defect and its downstream construction errors/timeout.
[Dead-code cleanup](DEFERRED_CLEANUP.md) is deferred until later.

The [three #1409 crossing assertions](CROSSINGS_1409.md) now pass through the
overlap-aware API on Erlang and JavaScript, with a transverse-crossing positive
control. No production change was needed.

The [address and classification audit](INTERSECTION_ADDRESSES.md) now covers
all 29 other extracted intersection fixtures on both runtimes. All returned
addresses reconstruct within the library tolerance. Of 54 expected contacts,
45 crossing flags agree, six have no flag assertion, two use a different
shared-arc convention, and one is the previously understood absent near-contact.
Together with #1409, all 32 extracted intersection assertions now have
contract-aware address/classification coverage; no new confirmed bug was found.

The scope and excluded assertions are recorded in FINAL_AUDIT.md and
final-file-screening.json. Additional arbitrary scale/transform variants and
exhaustive upstream assertion equivalence are outside this completed review.
Full Paper.js parity is not established.

## Historical investigation log

This is an unfinished audit, not a claim of Paper.js compatibility or a release
qualification. The first pass was diagnostic; crossing fix `e55a433` was subsequently approved
and committed. See `BOOLEAN_AUDIT.md` for the baseline and follow-up results.

Upstream: https://github.com/paperjs/paper.js
Revision: `92775f5279c05fb7f0a743e9e7fa02cd40ec1e70` (`develop`, inspected 2026-10-12).
The five original test files and MIT license are under `upstream/`.
`inventory.json` records their SHA-256 hashes and all 146 top-level test blocks:
50 Boolean, 24 intersection, 17 curve, 40 general path, and 15 containment blocks. Blocks may
contain multiple fixtures, loops, and assertions. These are not coverage percentages.

The subsequent shared-vertex CSG output fix recovers Boolean fixtures 104, 136
and 137. The latest screen is `boolean-screening-after-vertex-join.json`: 102
sampled matches, 69 library errors and seven API adapters. All 99 prior matches
remain matches. The original and post-crossing-fix screens are retained as
historical evidence; see the latest section of `BOOLEAN_AUDIT.md` for validation.

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

- `Path.js`: now triaged below: ten blocks have adapted geometry checks,
  20 concern object APIs, and ten still require adapters or separate work.
- `Curve.js`: all 17 blocks are triaged. Fourteen have extracted/adapted subsets;
  three classification/predicate blocks have no direct public counterpart. Legacy
  aliases, object behavior and the missing-direction tangent assertion remain
  outside these checks. See the second Curve batch below.
- Boolean screening has been refreshed after the crossing fix: 99 sampled
  matches, nine confirmed failures, one accepted limitation, 62 unclassified
  errors and seven other-adapter cases. See `BOOLEAN_AUDIT.md` for the native
  reproductions and seven newly recovered regressions. The original JSON screen
  remains the baseline; the new screen is saved separately.
- Intersections: crossing-only queries, parameter/address checks and crossing
  classification remain, plus independent segment-entry-point coverage. The
  eight raw location discrepancies are classified API differences.
- Containment: two object-level blocks are unadapted; saved Paper-generated
  interior points do not test our own interior-point selection.
- The five downloaded files are a subset of Paper.js's suite. Other potential
  geometry sources include `PathItem.js`, `CompoundPath.js`, `CurveLocation.js`,
  `Path_Constructors.js`, `Item_Bounds.js`, `Matrix.js`, `Numerical.js`, and SVG
  import/export tests. Their applicability has not yet been audited.

Recommended next work: classify the remaining Boolean errors, or expand to
geometry-oriented bounds/constructor tests in other upstream files.


## Path.js geometry batch (2026-10-12)

All 40 blocks are now triaged in `path-status.json`: ten have geometry-adapted
checks, 20 concern mutable objects, style/selection, scene ownership or node/cache
synchronization, and ten require different adapters or separate work. This is
not 40 passed tests. The 16 new native tests in
`test/svg_path_paper_paths_test.gleam` cover length, inverse length, area, joins,
reversal, flattening, splitting and move/line construction from the ten blocks.

`paths.json` retains extracted inputs and literal upstream assertions.
`path-screening.json` records direct query outputs, including strict-join errors;
those errors are classified policy differences, not newly confirmed bugs.
The extractor also captures a setup join during SVG parsing in the zero-area
flattening block; it is not counted as an independent upstream join regression.
Generated geometry expectations use the upstream literal anchor/handle strings,
not the geometry resulting from executing Paper's operation.

### Numerical findings

- Length: Gleam returns 172.1011280892614; the upstream literal is
  172.10112809179614. They differ by about 2.53e-9.
- Quarter-length inversion: Gleam returns t = 0.2255851578374859; the upstream
  literal is 0.2255849553116685. Independent 50-digit Decimal integration,
  repeated at 1e-14 and 1e-18 integration tolerances, gives Gleam's distance
  residual as approximately 9.73751012007e-10, within the default 1e-9 inversion
  tolerance. The upstream literal's distance residual is approximately
  -3.521563074e-5. This is a reference-accuracy difference, not a confirmed bug.
  See `check-path-length.py` and `path-length-findings.json`. The native test
  checks traveled distance with 2e-9 to allow both integration and inversion
  error, rather than asserting Paper's approximate parameter.
- Rectangle area matches 100. Paper's cubic circle has area
  314.2472332656507; the test's explicit 0.1 allowance around 100*pi is retained.

### Explicit API adapters

Paper `join` chooses orientation, bridges gaps, closes loops, and removes scene
objects. Gleam's strict join requires matching endpoints in the supplied order.
Tests make reversal, `Bridge`, `WiggleWith(1e-12)` and closure explicit. Node counts
map to edge counts plus one for open subpaths. Scene removal is not tested.

Closed-path reversal is compared modulo a cyclic starting vertex, retaining
traversal direction and the upstream rounded cubic controls. Circle flattening
at distance 5 produces the expected eight nonzero edges; this does not impose
Paper's subdivision count as a general contract. The closed one-cubic smoke case
uses Paper's default flatness 0.25 explicitly. No sampled-distance bound beyond
these source assertions is claimed.

Straight cubic splitting preserves controls in our model; Paper may simplify
its handles. Tests check the split point, one curve per half, equal half lengths,
and continuity. They do not demand zero handles. The `lineTo` case exercises the
equivalent SVG move/line construction, not a mutable drawing-command interface.

Still requiring work: simplifying coincident nodes, interpolation, three-point
arc construction (five blocks), tangent offsets, the 100,000-node clone stress
case, and coincident-endpoint arc drawing. No new production changes were made.

Reproduce:

```sh
node scripts/paperjs/extract-paths.cjs /tmp/svg-path-paper-audit/node_modules/paper
node scripts/paperjs/probe-paths.mjs
python3 scripts/paperjs/check-path-length.py
python3 scripts/paperjs/generate-paths.py
gleam format test/svg_path_paper_paths_test.gleam
scripts/test-portable
```

Path-batch validation: `scripts/test-portable` passed 517 tests on Erlang and
517 on JavaScript; `scripts/test-fast` passed 1,802 tests. The slow/full release
profiles were not run. These tests and findings are included in the subsequent audit commit.


## Remaining Curve.js batch (2026-10-12)

`curve-remaining.json` preserves operations and assertions from the eight blocks
not previously extracted. `curve-remaining-status.json` classifies five as
adapted geometry checks and three as lacking a directly equivalent public API.
`curve-remaining-screening.json` preserves direct JavaScript query outputs;
it includes setup queries and deliberate contract mismatches, not a pass count.

The 13 new native tests in `test/svg_path_paper_curve_remaining_test.gleam` cover:

- Eleven fractional arc-length round trips, including the upstream floating-point
  loop's endpoint values. Forward and end-relative positions are compared after
  explicitly converting the latter to start-relative distances. Returned partial
  lengths and one-sided tangent directions are checked. Distances use Gleam's own
  length; this tests the upstream relational assertion rather than importing
  Paper's computed parameters as expected answers.
- Negative and too-large distances: Paper accepts end-relative negative offsets
  and returns null out of range; Gleam documents `InvalidLengthDistance`.
  The location case uses point-at-length, not Paper's mutable location object.
- One hundred unique segment/point probes across 40 points on four rectangle
  sides. Nearest-point projection is checked against independent axis-aligned
  membership bounds, not assumed to establish membership merely by succeeding.
  Returned parameters must evaluate back to their projected points.
- Two divisions, at distance 50 and parameter 0.5: source midpoint assertions
  plus evaluation of both halves against the original curve. Object mutation
  and legacy aliases are not tested.
- Seven explicit tangent directions. A cubic's derivative is a quadratic curve;
  parallel tangents are its intersections with a supporting line through zero.
  Opposite direction vectors intentionally give the same answers. Every candidate
  in these fixtures is checked for nonzero speed; this adapter is not a general
  singular-tangent implementation. The missing-direction assertion is omitted.

All these checks pass. The direct screen's inverse-length errors are explained:
negative offsets are rejected by contract, as are distances larger than the
computed length. Paper's length for the common fixture is 293.59471358341074;
Gleam computes 293.5947135833825. The final Paper-derived positive distance is
about 2.8e-11 greater than Gleam's length, so the strict range check rejects it.
That is why relational round trips use each implementation's own length.

The seven `classify` scenarios, eleven `isStraight` scenarios and three `isLinear`
scenarios remain recorded but unexecuted against Gleam. There is no directly
matching public classifier/predicate. Collinearity is insufficient to reproduce
Paper's straightness semantics (overshoot and reversal matter), and a straight
trace need not have linear parameterization. These are feature/API differences,
not established numerical failures. Classification-root checks could be adapted
individually in later work; they are not claimed as covered here.

Reproduce:

```sh
node scripts/paperjs/extract-curve-remaining.cjs /tmp/svg-path-paper-audit/node_modules/paper
node scripts/paperjs/probe-curve-remaining.mjs
python3 scripts/paperjs/generate-curve-remaining.py
gleam format test/svg_path_paper_curve_remaining_test.gleam
scripts/test-portable
```

Validation: `scripts/test-portable` passed 530 tests on Erlang and 530 on
JavaScript; `scripts/test-fast` passed 1,815 tests. The slow/full release profiles
were not run. No production changes or F# edits were made in this batch; tests and findings
are included in the subsequent audit commit.

## Item_Bounds.js inventory batch (2026-10-12)

Source: `upstream/Item_Bounds.js`, downloaded at the same pinned revision and
hashed in `inventory.json`. This sixth upstream file adds 35 blocks (181 total
across the six files). The audit remains incomplete. This batch inventories
outcomes without changing production code or asserting that errors are correct.

`bounds.json` extracts 76 numeric queries from 21 blocks, representing 41 distinct
inputs after duplicates are removed. The upstream file repeats several blocks.
Both native targets produce **69 matches, five numerical differences, and two
empty-path errors**. These are query counts, not new Gleeunit test counts.
`bounds-native-screening.json` retains every native result; `bounds-status.json`
records duplicate IDs, dispositions and unadapted blocks. All 76 JavaScript
worker results agree in disposition with the native runs.

The comparisons cover open and closed cubic bounds, bounds centers, all nine
cap/join combinations, rectangular and triangular strokes, compound paths,
non-scaling strokes at different zoom levels, affine stroke deformation,
a circular arc and a rotated ellipse. Paper performs source construction and
transform setup; Gleam receives full-precision cubic snapshots and any remaining
matrix. These do **not** independently test Gleam's constructors, resize commands
or scene mutation. Zero-handle cubics are retained as cubics, not replaced by lines.

Adapter details:

- `bounds` queries use exact path bounds. `position` uses the bounds center.
- `strokeBounds` with a stroke constructs the Gleam outline and queries its
  bounds. This is an approximation-based adapter to Paper's direct stroke-bounds
  calculation, not an assertion that the APIs have identical accuracy contracts.
- A retained stroke-scaling matrix is applied to the completed stroke outline.
  Without stroke scaling, the input is transformed before stroking and the width
  is divided by the view zoom. `internalBounds` uses local geometry.
- Upstream five-decimal expected literals are preserved. The numerical comparison
  allowance is `2e-5` for rectangle coordinates/dimensions and centers. This is a
  comparison threshold, not a new promised stroke error bound.

The seven nonmatching queries represent four distinct cases:

| Fixture IDs | Case | Observed result and disposition |
| --- | --- | --- |
| 8, 40 | Open path with one node, butt cap | `EmptyPath` from the final bounds query. Gleam returns no stroke geometry; Paper retains a zero-size item rectangle at `(121,334)`. Different API expectations, not an established bug. |
| 9, 41 | Closed one-cubic stroke | Maximum rectangle-component difference `0.00120548`. Unresolved numerical difference. |
| 10, 42 | Curved miter stroke | Maximum difference `0.00178854` at defaults; with fitting tolerance `1e-4`, the difference falls to `0.00000757`, passing the comparison. Evidence of approximation sensitivity. |
| 75 | Rotated ellipse stroke | Maximum difference `0.00012580`. Unresolved numerical difference. |

All three default numerical differences are smaller than the default `0.01`
fitting tolerance. That observation alone neither proves nor disproves correctness:
Paper bounds and bounds of a fitted outline are different calculations.
JavaScript-only follow-up probes are preserved in `bounds-refined-screening.json`
and `bounds-tight-screening.json`. At fitting tolerance `1e-4`, the closed cubic
and ellipse return `OffsetError(MaxDepthReached(...))`; at `1e-6`, all three do.
Other options, including maximum depth, remain at defaults. These are recorded
convergence limitations for further investigation, not three confirmed bugs or
new failures under the default configuration. No solver changes were attempted.

Fourteen blocks remain unadapted: scene/group caching and mutation, text,
Shape/Symbol objects, visibility, global matrices, and additional internal-bound
queries under non-scaling strokes. Ten non-bounds assertions inside selected
blocks (segment string formatting and hit testing) are separately listed as
omitted. No claim of covering the entire file is made.

Reproduce from the repository root:

```sh
node scripts/paperjs/extract-bounds.cjs /tmp/svg-path-paper-audit/node_modules/paper
node scripts/paperjs/probe-bounds.mjs
python3 scripts/paperjs/generate-bounds.py
gleam format test_paperjs/src/paper_bounds_probe.gleam
(cd test_paperjs && gleam run -m paper_bounds_probe --target erlang) > /tmp/paper-bounds-erlang.log
(cd test_paperjs && gleam run -m paper_bounds_probe --target javascript) > /tmp/paper-bounds-js.log
python3 scripts/paperjs/collect-bounds-native.py /tmp/paper-bounds-erlang.log /tmp/paper-bounds-js.log
BOUNDS_IDS=9,10,75 BOUNDS_FITTING_TOLERANCE=0.0001 BOUNDS_REPORT=bounds-refined-screening.json node scripts/paperjs/probe-bounds.mjs
BOUNDS_IDS=9,10,75 BOUNDS_FITTING_TOLERANCE=0.000001 BOUNDS_REPORT=bounds-tight-screening.json node scripts/paperjs/probe-bounds.mjs
```

Validation: both `paper_bounds_probe` runs completed all 76 queries successfully
as diagnostic programs, including the recorded errors. The ordinary, portable
and release test selections are unchanged and were not rerun for this audit-only
batch. No production code, F# code or published figures changed. No commit made.

### First numerical discrepancy investigated: fixtures 9 / 41

`check-first-stroke-bounds.mjs` and `first-stroke-bounds-findings.json` isolate
the closed one-cubic, width-one miter stroke. Independent differentiation of
the source cubic gives its coordinate extrema. Offsetting these supporting
points by radius 0.5 and intersecting the offset endpoint tangent lines gives
stroke bounds agreeing with Paper's unrounded result:

`[minX, minY, maxX, maxY] = [120.44098344921575, 312.8832379684846,
140.41642563622514, 343.4230062398443]`.

An independent polynomial-extrema calculation on Gleam's *returned outline*
agrees with the library bounds query to within `5.7e-14` in all successful sweep
runs. Thus the observed difference is in the fitted outline, not a bounds-query
error or an inaccurate Paper reference. The default outline's signed edge errors
are `[0, -0.0000228774, +0.0012032968, -0.0008115042]`.

| Fitting tolerance | Output segments | Maximum absolute edge error |
| --- | ---: | ---: |
| 0.01 (default) | 24 | 0.00120330 |
| 0.005 | 28 | 0.00120330 |
| 0.002 | 38 | 0.00012666 |
| 0.001 | 40 | 0.00012666 |
| 0.0005, 0.0002, 0.0001, 0.000001 | No output | `MaxDepthReached` |

Disposition: **understood approximation difference, not a demonstrated bug**.
The bounds errors in successful runs remain below the requested fitting tolerance;
this is evidence for this fixture, not a proof of a global error guarantee.
The default result was independently reproduced on both backends in the batch;
the additional tolerance sweep and independent checks ran on JavaScript.

There is a separate refinement limitation worth retaining in the inventory:
`offset` defaults to, and currently permits at most, five refinement generations.
The raw fitting acceptance threshold is half the requested tolerance, explaining
why some reported divergences are below the caller's tolerance while still
causing `MaxDepthReached`. Increasing the option beyond five is not a supported
workaround. No production change or depth-limit change was attempted.

Reproduce: `node scripts/paperjs/check-first-stroke-bounds.mjs`.

### Remaining four numerical entries investigated

The remaining entries in the five-entry numerical-discrepancy list are 10, 41,
42 and 75. Fixture 41 exactly duplicates 9; fixture 42 exactly duplicates 10.
The path coordinates, options, matrix and reference results were checked for
identity, so this adds two distinct geometries rather than four distinct bugs.

`check-remaining-stroke-bounds.mjs` independently solves source-cubic coordinate
extrema and endpoint offset-tangent intersections. For these fixtures, every
extreme bound is attained either at a radius-offset interior source extremum or
at an accepted miter. The resulting references agree with unrounded Paper bounds
within `5.7e-14`. The ellipse calculation uses the actual four source cubics,
not an ideal ellipse, avoiding a separate circle/ellipse approximation difference.

The same script independently bounds every line and cubic in the generated
outlines. Those bounds agree with the library query within `1.8e-13` throughout
the successful sweep runs. This identifies outline approximation as the source
of the differences, rather than a defective bounds query or Paper reference.
Full results are in `remaining-stroke-bounds-findings.json`.

| Distinct case | Default maximum edge error | Tighter successful setting | Observed refinement limit |
| --- | ---: | --- | --- |
| Curved miter stroke (10, 42) | 0.00178661 | At tolerance 0.0001: error 0.00000364, 72 output segments | Tested 0.00001 and 0.000001 return `MaxDepthReached`; 0.00005 succeeds. |
| Rotated cubic ellipse (75) | 0.000061654 | Tolerances 0.005, 0.002 and 0.001 retain the same extremal error while refining other portions | Every tested setting from 0.0005 down to 0.000001 returns `MaxDepthReached`. |

Errors here are measured on the four box *edges*, against an unrounded independent
reference. The original screen compared `x, y, width, height` against rounded
literals; for the symmetric ellipse, the width difference is approximately twice
the individual left/right edge error. This explains the earlier 0.00012580 report.

Disposition for all five numerical entries: **understood stroke-approximation
differences, not demonstrated correctness bugs**. Each successful sweep's bounds
error is below that run's fitting tolerance. This does not establish a global
Hausdorff bound. Keep the tight-tolerance refinement failures as a separate known
limitation for later work. Defaults were checked on both native targets in the
batch; independent calculations and option sweeps ran on JavaScript.

Reproduce: `node scripts/paperjs/check-remaining-stroke-bounds.mjs`.
No production changes, regression expectation changes, or commits were made.

## Constructors, PathItem and Matrix batches (2026-10-12)

Three more files from the same pinned Paper revision are preserved under
`upstream/`, with hashes in `inventory.json`. The inventory now has nine files
and 204 top-level blocks. This batch adds diagnostic programs and comparison
reports; it makes no production changes and adds no tests to the release gate.

### Path_Constructors.js

All 24 original assertions from 18 blocks are preserved in `constructors.json`.
Ten assertions from ten blocks have native constructor adapters: plain rectangle
(two API forms), circle (two forms), ellipse, rounded rectangle (two forms),
oversized-radius rectangle and line (two forms). These represent six distinct
geometric inputs. All ten match on Erlang and JavaScript.

The adapters use arguments transcribed from the source calls, not shapes
reconstructed from Paper's answers. Expectations come from the original rounded
segment-string literals. Relative handles become absolute controls; our exact
arc segments are explicitly converted to cubic approximations for comparison.
Closed contours may start at different cyclic vertices, but direction is retained.
Zero-length, zero-handle segments are omitted on both sides for geometric
comparison. Closure and every remaining endpoint/control coordinate are compared
with allowance `2e-5`; the largest observed difference is below `0.000005`.
Lines are encoded with zero endpoint handles to match Paper's node representation.
This does not claim that an exact ellipse and its cubic approximation are
identical curves, or that the libraries have identical segment counts by default.

`constructors-native-screening.json` contains both runs. Fourteen assertions
remain uncompared: scene insertion (four), three-point arcs (two), regular
polygons (four) and stars (four). The last three families could be implemented
as explicit geometry adapters later; no direct matching constructor was used.
`constructors-status.json` records block dispositions.

### PathItem.js

`pathitem.json` preserves both blocks and all 33 assertions. The 22 SVG path-data
parsing cases all match on Erlang and JavaScript. They exercise multiple subpaths,
relative commands, exponent notation, whitespace, closure, smooth cubics and
smooth quadratics. Expected coordinates and handles come from the original
literal arrays. Quadratics are converted to cubics for comparison; lines use
zero endpoint handles. Contour order, starting vertex and closure are retained.
Only zero-length zero-handle segments are ignored. Coordinates use `2e-5` to
accommodate five-decimal reference handles. Results are in
`pathitem-native-screening.json`.

The eleven `PathItem#compare` assertions are preserved but not passed through
Gleam's congruency query. Paper asks for equality of traces across subdivisions
and cyclic starts; Gleam congruency searches for a similarity transform under
ordered correspondence. Using it as a boolean equality predicate would conflate
different contracts. `pathitem-status.json` records this coverage gap.
The upstream file includes its original attribution for W3C-derived path data.

### Matrix.js

The three blocks and 52 decomposition assertions in `matrix.json` have now been
compared with the public `affine.decompose` API on Erlang and JavaScript
(2026-10-13). Both targets produce the same classification:

- **47 direct numerical matches**, using absolute tolerance `1e-10`.
- **5 equivalent angle-endpoint conventions**, fixture IDs 22, 30, 32, 40, 42.
  Paper.js expects `-180°`; Gleam documents `(-180°, 180°]` and returns `+180°`.
  These are a known API convention difference, not a numerical failure.
- **No unexplained discrepancies or library errors.** Signed scales, including
  reflection placement, agree with the upstream expectations.

`matrix-native-screening.json` preserves every raw comparison and classifies the
five endpoint differences explicitly. `matrix-status.json` and the inventory
now mark all three blocks as adapted decomposition matches.

The 52 generated tests in `test/svg_path_paper_matrix_test.gleam` are also in the
portable suite and the upstream audit runner. For the 26 input cases, supplemental
checks verify zero shear, affine recomposition, ordinary pretty-print/parse round
trips, and explicit standard-order serialization/parse round trips. Only the
known `-180°` / `+180°` convention is adapted in expected factors.

These upstream cases cover pure rotations, signed scales, and four combinations
of rotation and signed scale. They do **not** test general shear, translation
placement, singular maps, or arbitrary orders. The separate affine and serializer
regressions remain responsible for those features. No production change was
needed for the Paper.js comparisons.

To reproduce this batch:

```sh
node scripts/paperjs/extract-matrix.cjs /tmp/svg-path-paper-audit/node_modules/paper
python3 scripts/paperjs/generate-matrix.py
gleam format test/svg_path_paper_matrix_test.gleam test_paperjs/src/paper_matrix_probe.gleam
(cd test_paperjs && gleam run -m paper_matrix_probe --target erlang) > /tmp/paper-matrix-erlang.log
(cd test_paperjs && gleam run -m paper_matrix_probe --target javascript) > /tmp/paper-matrix-js.log
python3 scripts/paperjs/collect-matrix.py /tmp/paper-matrix-erlang.log /tmp/paper-matrix-js.log
scripts/test-portable
```

### Reproduction and validation

```sh
node scripts/paperjs/extract-constructors.cjs /tmp/svg-path-paper-audit/node_modules/paper
node scripts/paperjs/extract-pathitem.cjs /tmp/svg-path-paper-audit/node_modules/paper
node scripts/paperjs/extract-matrix.cjs /tmp/svg-path-paper-audit/node_modules/paper
python3 scripts/paperjs/generate-constructors.py
python3 scripts/paperjs/generate-pathitem.py
gleam format test_paperjs/src/paper_constructors_probe.gleam test_paperjs/src/paper_pathitem_probe.gleam
(cd test_paperjs && gleam run -m paper_constructors_probe --target erlang) > /tmp/paper-constructors-erlang.log
(cd test_paperjs && gleam run -m paper_constructors_probe --target javascript) > /tmp/paper-constructors-js.log
python3 scripts/paperjs/collect-constructors.py /tmp/paper-constructors-erlang.log /tmp/paper-constructors-js.log
(cd test_paperjs && gleam run -m paper_pathitem_probe --target erlang) > /tmp/paper-pathitem-erlang.log
(cd test_paperjs && gleam run -m paper_pathitem_probe --target javascript) > /tmp/paper-pathitem-js.log
python3 scripts/paperjs/collect-pathitem.py /tmp/paper-pathitem-erlang.log /tmp/paper-pathitem-js.log
```

Completed: 10 constructor and 22 parser comparisons on each backend, all matching;
extraction/inventory of the unsupported assertions; formatting and diff checks.
The collectors assert completeness but retain discrepancies as report entries,
so a successful collector exit alone is not a passing geometry claim. No full
release rerun was needed for these diagnostic-only changes. No new discrepancies,
production changes, F# edits, figure changes, or commits in this batch.

## Next downloaded batches (2026-10-12)

Four further files are vendored at the same pinned Paper revision. Their original
license headers are intact, and `inventory.json` records SHA-256 hashes and
`downloaded-not-yet-compared` status for every block:

| File | Blocks | Candidate coverage |
| --- | ---: | --- |
| `Numerical.js` | 2 | Quadratic and cubic roots under coefficient scaling; four explicit assertions. |
| `CurveLocation.js` | 1 | Cumulative distances at four successive vertices of a straight path. |
| `CompoundPath.js` | 2 | Multi-contour construction and contour reorientation. |
| `Segment.js` | 14 | Paper node/handle construction, reversal, cloning, removal and selection; many are object-model features rather than curve-segment operations. |

The inventory now contains 13 files and 223 top-level blocks. These 19 newly
fetched blocks have not yet been compared against Gleam; download counts are
not passing-test counts. Numerical roots and cumulative curve locations are the
next direct numerical candidates. Decomposition remains deferred. No production
changes or commits were made during this download batch.

## Segment.js batch (2026-10-12)

All 16 assertions in the 14 upstream blocks are preserved in `segments.json`.
The central API distinction is that a Paper `Segment` is one path **node** with
incoming/outgoing relative handles. A Gleam `Segment` is an entire **edge** with
start/end points and absolute controls. Identical names do not imply equivalent
constructors or editing operations.

One original assertion has a geometric adapter and **matches exactly on both
Erlang and JavaScript**: the handle-reversal test. The node `(10,10)`, incoming
handle `(5,5)` and outgoing handle `(15,15)` becomes a closed cubic with controls
`(25,25)` and `(15,15)`. After `subpath_reverse`, reconstructing the relative
handles gives incoming `(15,15)` and outgoing `(5,5)`, matching the original
expected string. Supplementary checks confirm closure, endpoint continuity, and
that two reversals restore the original subpath. These three extra checks are
not counted as additional upstream assertions. Mutable identity and in-place
mutation are not tested by this adapter.

The remaining assertions are explicitly unexecuted against Gleam:

- Ten constructor-overload assertions: node construction, missing/null fields,
  numeric/object/Point/Size inputs. No direct edge-constructor equivalence.
- Two clone assertions: separate object identity and equal geometry. No matching
  mutable-node identity API for immutable values.
- One node-removal assertion: removing the middle node of `[A,B,A]` leaves two
  coincident nodes and a zero-length edge. Node removal is outside our API;
  deleting an edge is a different operation. This is an understood API difference,
  not a pending adapter, missing test obligation, or library failure.
- Two selection assertions: editor/scene selection state has no geometry-only
  counterpart.

`segments-status.json` records all block/assertion dispositions;
`segments-native-screening.json` records both native outputs. No discrepancies
were found in the single executed comparison. The 15 unexecuted assertions are
not passing tests and are not evidence of library failures.

Reproduce:

```sh
node scripts/paperjs/extract-segments.cjs /tmp/svg-path-paper-audit/node_modules/paper
python3 scripts/paperjs/generate-segments.py
gleam format test_paperjs/src/paper_segments_probe.gleam
(cd test_paperjs && gleam run -m paper_segments_probe --target erlang) > /tmp/paper-segments-erlang.log
(cd test_paperjs && gleam run -m paper_segments_probe --target javascript) > /tmp/paper-segments-js.log
python3 scripts/paperjs/collect-segments.py /tmp/paper-segments-erlang.log /tmp/paper-segments-js.log
```

Both native probes completed. Formatting and diff checks passed. Production
code, standard test selections and F# are unchanged; no release suite rerun or
commit was made for this diagnostic-only batch.

## CurveLocation.js batch (2026-10-12)

This file has one block containing four assertions: nodes at `(100,100)`,
`(200,100)`, `(300,100)` and `(400,100)` have cumulative distances `0,100,200,300`.
All four assertions match exactly on Erlang and JavaScript, both with Paper's
original zero-handle cubic representation and with an explicit line polyline.
That is four upstream assertions in two representations, or eight native queries
per backend—not eight independent upstream assertions.

Our geometry API has no mutable `CurveLocation` object with an `offset` property.
The adapter measures the prefix ending at each known node parameter using
`subpath_between` and `measure.subpath_length`. At the first node it uses an empty
prefix because `subpath_between` intentionally rejects equal parameters. The
final node is addressed as the final segment's `t=1`; intermediate nodes use
next-segment `t=0`. Supplementary checks evaluate each address and independently
query `subpath_point_at_length` using the upstream expected distance. All recover
the corresponding input point exactly on both backends.

The probe uses the input geometry, not the expected offsets, to compute prefix
lengths. Expected offsets are used only for comparison and the supplementary
inverse query. Location-object identity, mutation and caching are not claimed
as covered; the upstream block does not test them either.

Evidence: `curve-locations.json`, `curve-locations-native-screening.json` and
`curve-locations-status.json`. No discrepancy or failure was observed.

```sh
node scripts/paperjs/extract-curve-locations.cjs /tmp/svg-path-paper-audit/node_modules/paper
python3 scripts/paperjs/generate-curve-locations.py
gleam format test_paperjs/src/paper_curve_locations_probe.gleam
(cd test_paperjs && gleam run -m paper_curve_locations_probe --target erlang) > /tmp/paper-curve-locations-erlang.log
(cd test_paperjs && gleam run -m paper_curve_locations_probe --target javascript) > /tmp/paper-curve-locations-js.log
python3 scripts/paperjs/collect-curve-locations.py /tmp/paper-curve-locations-erlang.log /tmp/paper-curve-locations-js.log
```

Both native probes and formatting/diff checks completed successfully. Production
code, standard test selections and F# are unchanged. No release rerun or commit.

## Remaining downloaded batches: Numerical and CompoundPath (2026-10-12)

### Numerical.js

All four assertions from both blocks are extracted in `numerical.json` and
compared against `svg_path/internal/root` on Erlang and JavaScript. These are
internal implementation checks, not a claim of a public polynomial-solving API.
Extraction records only the outer solver call: Paper's cubic implementation also
calls its quadratic helper internally, whose coefficients must not replace the
original cubic input.

Both quadratic cases return exactly `[-1,1]`, versus Paper's `[1,-1]`. Root order
is explicitly ignored for comparison and retained in the report. Coefficient
scaling from 1 to Paper's `EPSILON=1e-12` leaves both roots unchanged.
Both cubic cases return `2.9196395657246743`, versus the upstream literal
`2.919639565839418`: absolute difference approximately `1.14744e-10`, within the
`1e-9` comparison allowance. The scaled and unscaled results agree exactly, as
do the two backends. Normalized polynomial residuals are also retained.
All four comparisons match; the raw ordering difference is an understood
output-convention difference, not a missing root.

### CompoundPath.js

All nine assertions from both blocks are preserved in `compound-paths.json`.
Four have geometric adapters, all matching on both backends:

- The recorded move/line sequence is translated to SVG `M`/`L` commands and parsed;
  the result has the expected two subpaths. This compares construction structure,
  not mutable drawing methods, fill-color state or exhaustive vertex geometry.
- The three source rectangles are constructed from their original corner/size
  arguments. Positive signed area matches Paper's initial clockwise orientation
  in SVG's downward-y coordinates.

Five assertions have no direct counterpart: two compare child object identity
and ordering after mutation; three inspect orientations after `reorient()`.
Paper changes the two inner rectangles to counterclockwise and retains the outer
rectangle clockwise. Our `csg.nested_contours` preserves the signed integer
winding field and does not implement that reorientation policy. Substituting it
would create a false discrepancy. These are documented API differences, not
pending repairs or passing native comparisons. See `compound-paths-status.json`.

### Reproduction and completion

```sh
node scripts/paperjs/extract-numerical.cjs /tmp/svg-path-paper-audit/node_modules/paper
node scripts/paperjs/extract-compound-paths.cjs /tmp/svg-path-paper-audit/node_modules/paper
python3 scripts/paperjs/generate-final-batches.py
gleam format test_paperjs/src/paper_final_batches_probe.gleam
(cd test_paperjs && gleam run -m paper_final_batches_probe --target erlang) > /tmp/paper-final-batches-erlang.log
(cd test_paperjs && gleam run -m paper_final_batches_probe --target javascript) > /tmp/paper-final-batches-js.log
python3 scripts/paperjs/collect-final-batches.py /tmp/paper-final-batches-erlang.log /tmp/paper-final-batches-js.log
```

`final-batches-native-screening.json` records all eight executed comparisons per
backend; all match. Formatting/diff checks passed, and hashes of all 13 vendored
source files were rechecked. No production changes, F# changes, standard test
selection changes, full release rerun or commits.

Every file in the most recently downloaded four-file group now has a recorded
comparison/disposition pass. This does not close earlier audit gaps or establish
coverage of all Paper.js tests: the larger Boolean discrepancy inventory,
unadapted assertions in earlier files and as-yet-undownloaded files remain.
