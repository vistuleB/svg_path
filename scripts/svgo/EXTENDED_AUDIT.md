# Extended SVGO audit log

Pinned release: SVGO 4.1.0 (`5765cbe4e0a930dca648c6b81d335b1522cd7375`). All 375 plugin fixture files are now archived with hashes. Archiving alone does not mean a fixture has been audited. Production source is unchanged.

## Completed: path unit tests

`node scripts/svgo/path-units.mjs`: 20 original tests / 24 assertions replayed successfully, with adapted checks against our public API. The runner executes the pinned test bodies using assertion/capture callbacks; it does not approximate the original inputs by hand. Details: `path-units.json`.

- Legal whitespace, commas and compact arc flags: parsed geometry agrees.
- Malformed syntax: SVGO returns the valid prefix, whereas our parser returns an error. This is a contract difference, not a regression.
- Signed arc radii: SVGO normalizes during parsing; ours preserves them and offers explicit SVG arc normalization. Normalized geometry agrees.
- Serialization: upstream serializes command lists, while ours serializes geometry with its own coordinate choices. Valid output, independent SVGO decoding and second-pass stability checked for all serialization assertions. Scientific notation round trips have floating-point differences around 1e-22 at magnitude 1e-7; the independent-decoder comparison allows 32 machine epsilons relative to each numeric value. This is not a geometry-tolerance test.

## Completed: transforms

`node scripts/svgo/transforms.mjs`: 13 fixture files / 59 transform attributes, plus both `_transforms.test.js` cases. Upstream expected output matches. Like the upstream runner, convertTransform is tested for one optimization pass, not two. Details: `transforms.json`.

- 10 comparisons have identical output; 27 differ in factor choice or rounding policy.
- 23 comparisons involve stricter separator grammar in our parser (in either the source or SVGO's output). Six source attributes use omitted separators between numbers; many expected outputs concatenate functions without whitespace. We record rejection, then explicitly canonicalize SVGO's tokenized transform list with separators for the numerical comparison. These are not silently counted as raw-parser matches.
- One incomplete `rotate(45, 34, 34` is rejected by ours and removed by SVGO.
- All 60 valid/adapted numerical comparisons agree with independently composed SVGO matrices within floating-point tolerance. Our pretty-printed output reparses and satisfies our documented column/translation formatting budget. Largest absolute coefficient change in our output: about 4.38e-6.
- SVGO has separate angle, coordinate and matrix precision policies; ours is tested with the fixture's transformPrecision (default 5). Therefore byte counts or equal strings would not establish equal precision contracts.
- Centered rotations, other decomposition orders, shortest-string candidate selection, and optionally permissive transform parsing remain API/optimization ideas, not confirmed bugs.

The strict separator behavior follows the SVG 1.1 transform-list grammar requiring `comma-wsp` between numbers and between transforms: <https://www.w3.org/TR/SVG11/coords.html#TransformAttribute>. This audit does not claim that browser acceptance is limited to that grammar. Permissive SVG/browser compatibility would be a deliberate parser-policy extension.

## Completed: shape conversion

`node scripts/svgo/shapes.mjs`: five convertShapeToPath fixtures and one convertEllipseToCircle fixture, 34 shape elements. Both upstream passes match. Details: `shapes.json`.

- Numeric lines, rectangles, polylines and two-point polygons are supported. Compared bounds agree within the fixture's decimal rounding. Ellipse/circle constructors additionally satisfy the analytic ellipse equation at sampled points and the analytic signed area.
- Our circles/ellipses start at 3 o'clock and use four clockwise quarter arcs. SVGO uses two arcs starting at the top in the opposite direction. Same standalone filled shape, different traversal, segmentation and signed area. These must not be treated as interchangeable contour representations in every compound-path use case.
- In convertShapeToPath.05 element 6, SVGO's rounded two-arc ellipse has horizontal bounds about 0.379 units wider than the analytic source ellipse. This is the same semicircle sensitivity seen in the path-data batch: `rx=34.268`, `ry=8.176`, and vertical chord `16.351` imply a horizontal center offset `rx * sqrt(1 - (chord/(2*ry))^2)` of about 0.379. Our unrounded constructor matches the analytic ellipse. The case is explicitly classified as rounded-semicircle sensitivity, not reported as matching bounds or an error in our constructor.
- Two rounded rectangles remain rect elements in SVGO; our constructor supports them. Percentage/physical-unit resolution is outside our numeric constructor API (five elements). Two malformed odd-length points attributes are deleted by SVGO; our typed point-list API cannot express an unmatched coordinate.
- The ellipse `auto` radius cases require attribute-default resolution in the adapter, not a change to the geometry API. A zero-size ellipse/circle returns our documented DisabledRendering rather than an SVG element with zero radius.

## Completed: merging paths

`node scripts/svgo/merge-paths.mjs`: 12 fixtures, 88 input paths. Both upstream passes match. Nonempty subpath geometry before/after SVGO merging agrees, and our path_combine preserves subpaths and their order. Details: `merge-paths.json`.

This operation concatenates compatible SVG elements; it is not Boolean union. Cases 01–02 cover grouping and empty moves, 03–06 cover conservative overlap-related decisions, and 07–12 cover markers, gradients, filters, clip paths and masks. Our library has no API promising to make these document-level eligibility decisions. We check the applicable parsing/combination/serialization behavior, not equivalence of overlap heuristics or rendered scenes.

One numerical representation difference is recorded rather than hidden: mergePaths.04's first path has 24 segments, but its relative serialization reparses to 25 because the last endpoint becomes `(320, 59.99999999999998)` instead of `(320, 60)`. Z adds a closing line of length about `2.13e-14`. The round-trip comparison allows only an extra closing Line shorter than `1e-10`, checks its closed state, then compares every original segment. No arbitrary segment-count difference is ignored. This is floating-point closure behavior under a rounded relative representation, not a confirmed geometric correctness bug; exact segment-count preservation would require a stronger serialization contract. It is relevant if a caller assigns meaning to every segment or marker.

## Completed: off-canvas paths

`node scripts/svgo/off-canvas.mjs`: six fixtures / 21 paths. Both upstream passes match. Our bounds agree with retention/removal decisions for all fixtures having a viewport, including explicit and inherited transforms. Without viewport dimensions, no culling decision is inferred. Details: `off-canvas.json`.

This is not a general proof that geometric bounds suffice for render culling: strokes, filters, markers and viewport clipping need additional document semantics. These particular fixture paths are sufficient distances from the boundaries for the recorded comparisons.

## Completed: numeric cleanup

`node scripts/svgo/numeric-values.mjs`: six fixtures / 58 numeric tokens in changed attributes. Both upstream passes match. Numeric rounding agrees through our public decimal serializer; two physical-unit conversions (inches/points to pixels) are outside that API. Unit stripping, text position lists, viewBox formatting and attribute selection are document policies. Details: `numeric-values.json`.

## Completed: secondary groups

`node scripts/svgo/secondary.mjs`: 30 fixtures / 48 applicable parsing or static-shape checks. Both upstream passes match. Details: `secondary.json`.

- removeHiddenElems (19 fixtures): visibility/opacity inheritance, animated zero-sized shapes, empty/malformed paths, marker exceptions, reference retention, clip paths, and textPath. Our parser and DisabledRendering results agree with the applicable static geometry contracts. Visibility and animation are not geometry predicates.
- removeUselessStrokeAndFill (5): attribute removal depends on styles, inheritance, markers and optional element removal. It does not test our stroke-outline algorithm; treating stroke-width removal as an outline regression would be misleading.
- reusePaths (6): definitions, IDs, use references, styles and transforms. Our path strings parse; reference deduplication has no public-library counterpart. This is not a congruency test merely because paths are duplicated.

## Scope inventory and baseline verification

The relevant audit now covers **113 plugin fixtures** (40 original plus 73 additional), plus **22 standalone test cases** (20 path tests and two transform tests). Numerical comparisons and documented adaptations are JavaScript-only; no full Erlang/library regression suite result is claimed.

`node scripts/svgo/upstream-replay.mjs` also verifies all 335 additional plugin fixtures against their upstream expected SVG, respecting the upstream single-pass exceptions. All match. This baseline replay is explicitly **not** 335 tests of our library. The other **262 fixtures in 42 groups** concern document/CSS/XML behavior without a matching public contract; they are listed separately in EXTRA_INDEX.md and are not presented as geometry parity coverage.

No production source, ordinary test files, release metadata or commits changed. No confirmed bug requires a fix decision at this point.

## External visual corpus

SVGO's external corpus combines W3C SVG 1.1 tests, Oxygen icons, Charm icons and Wikimedia images. Its repository describes per-file license attribution and processing: <https://github.com/svg/svgo-test-suite>. The SVGO regression runner compares rasterized complete documents, not expected path strings, and maintains skip/expected-mismatch lists. It is a separate source of real-world paths, not an equivalent next batch of fixed input/expected path-minification assertions.

HEAD inspection on 2026-10-14 returned HTTP 200, Content-Length **417,139,824 bytes** (about 417 MB decimal / 398 MiB), ETag `"6a6b064f-18dd0c70"`, and Last-Modified 2026-07-30. The archive was **not downloaded**. The moving download URL is <https://svg.github.io/svgo-test-suite/svgo-test-suite.tar.gz>.

This is the escalation boundary: the directly relevant unit fixtures are complete, and a whole-document visual corpus needs a different comparison strategy. Options are to extract and audit only path/transform data (robustness checks, not visual parity), or build a document-preserving replacement and raster-comparison harness (a separate integration project). Neither is silently counted as completed. Recommendation: prioritize the concrete serializer improvements from this audit before launching that broader corpus project. No visual-regression coverage is claimed.

## Final verification

`bash scripts/svgo/run-audit` completed successfully on 2026-10-14 with Gleam 1.18.1 and Node v24.10.0. The no-parameter warnings from removeAttrs/removeAttributesBySelector are expected upstream no-op fixtures; all baseline outputs still match. A final rerun of `node scripts/svgo/shapes.mjs` refreshed the explicit ellipse-rounding classification. No production fixes were made.
