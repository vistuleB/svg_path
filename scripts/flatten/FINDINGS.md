# Flatten.js audit — first batch

Current follow-up: [FL006 is fixed and validated in Gleam](FL006-OVERLAP-FIX.md).

**Latest status:** the history below predates the 3.1.3 remaining-observation
triage. [REMAINING-TRIAGE.md](REMAINING-TRIAGE.md) classifies all 21 later flags
and records Gleam fixes for FL002–FL005 (F# ports pending), including an
explicit size-filter closure error for FL004 at default options. The later
[continuity replay](CONTINUITY-REPLAY.md) found the open FL006 arc-intersection
miss while executing the twelve previously blocked comparisons. Statements
below that only FL001 was confirmed describe the earlier inventory snapshot.

2026-10-15. Gleam implementation: `ba6988cc036dc340e69bde411fb6ffab11ce98fa`
(3.1.2). Upstream pinned revision/version and archive hashes are in
`provenance.json`. No production changes or new native regressions in this pass.

## Coverage

- Unmodified upstream baseline: 544 passing tests across 23 files.
- Arc/circle instrumented run: 93 passing tests, preserving their assertions.
- Captured comparison: 116 calls from 42 distinct tests, including repeated
  queries. Results: 110 matches at diagnostic tolerance, four contract
  differences, two scope differences. Zero unclassified calls in this batch.
- 51 tests in those files have no captured operation; their assertions still
  require review. Capturing a call does not imply every assertion in its test
  was adapted. The other 21 files are pending.

## Reviewed differences

| Calls | Upstream test / operation | Disposition |
| --- | --- | --- |
| 8 | `arc.js`: Intersect arc with circle, same center and radius - return two end points | Continuous overlap; our point API reports `OverlappingSegments`. |
| 11–12 | `arc.js`: Intersect arc with arc, overlapping case / overlapping case, 4 points | Same distinction: Flatten returns boundary points for shared intervals; our API separates interval overlaps from isolated contacts. |
| 104 | `circle.js`: Can intersect circle with circle - same circle, one intersection, leftmost point | Flatten chooses a representative point for coincident circles; our API reports continuous overlap. |
| 105 | `circle.js`: Can intersect circle with circle - degenerated circle | Flatten's zero-radius circle produces no intersections in this fixture. There is no circle primitive with that contract in our API. An SVG zero-radius arc requires normalization, and a constant polynomial has point-contact semantics. Do not silently equate these models. |
| 110 | `circle.js`: Can measure distance between circle and line | Infinite-line distance has no direct public counterpart. Left outside this batch rather than truncating an infinite line arbitrarily. A possible convenience API, not a bug finding. |

All other captured operations match: length, bounding boxes, points at length,
point membership, isolated intersections and applicable closest distances.
The diagnostic comparison threshold is `1e-6` (upstream's default tolerance).
Native options are unchanged. Distance comparison currently checks the distance
value, not uniqueness/equality of closest-point witnesses; intersection
comparison checks deduplicated point sets, not parameter addresses.

## Adapter timeout resolved

Call 115, `circle.js` / `Can measure distance between circle and polygon`,
initially exceeded a 30-second limit with an adapter that explicitly evaluated
every segment pair. That bypassed the bounding-box pruning in our public
`distance.path_path_closest_pair` query.

Using the public path query completes and returns the expected distance **25**.
The query is repeated successfully in the final full batch. No production bug
is established. The initial 116-call report is retained as
`initial-exhaustive-results.json`, and the direct public-query check as
`arc-circle-public-distance-results.json`. The exhaustive-adapter rerun also reached its 120-second limit
(`arc-circle-call115-results.json`); this is historical adapter-runtime evidence,
not the final classification or a release gate.

## Next work

Review remaining arc/circle assertions and then move to segment, line and ray
tests. Continue to distinguish adapter mistakes, model/contract differences,
numerical limitations and confirmed failures. Investigate every new comparison
flag before advancing to a different batch. No fixes are authorized by these
results alone.

## FL001 — confirmed JavaScript closest-pair stack overflow

Upstream `test/classes/segment.js`, tests `Distance to Circle Case 1
Intersection - two points` and `Distance to Circle Case 1 Intersection - one
points` (linear calls 66 and 67). Both expect distance zero.

Independent native reproduction, with no Flatten dependency or adapter:

- Line: `(0, 2)` to `(4, 2)`.
- SVG arc: `(3, 0)` to `(0, 3)`, radii `(3, 3)`, rotation zero,
  `large_arc=False`, `sweep=True`.
- `intersections.segment` succeeds at approximately `(sqrt(5), 2)`.
- `distance.segment_segment_closest_pair` throws `RangeError: Maximum call
  stack size exceeded`.
- `distance.path_path_closest_pair` on the two single-segment paths does too.

Run `node scripts/flatten/probe-distance-stack.mjs`; results and stacks are in
`distance-stack-probe.json`. The generated JavaScript for
`initial_descent_records_loop` recursively calls itself inside a `result.try`
callback. The captured stacks repeat that callback/loop pair. Its other branch
is compiled as a loop; the callback branch accumulates stack frames. This
identifies the immediate failure mechanism, not yet why this input produces so
many descent records or whether further issues would appear after fixing it.

This is a violation of our result-returning query contract for valid geometry,
not a disagreement about circle representation, witness choice or tolerance.
Confirmed on JavaScript only; Erlang behavior has not been measured in this
batch. At inventory time no production fix had been applied; see the fix validation below. Raw comparison failures are retained;
`dispositions.json` classifies both as this one bug.

## Linear overlap conventions

- Linear calls 15–17: overlapping finite segments return their two overlap
  endpoints upstream; our intersection query returns `OverlappingSegments`.
- Calls 26–28 and 224: a segment lies along an infinite line or ray. Flatten
  returns overlap endpoints; the supporting-line crossing query returns no
  isolated roots for the identically-zero projection. This is not a missing
  isolated crossing.
- Call 59, upstream issue #99: horizontal segments separated by about `7e-15`
  are treated as overlapping by both libraries at their defaults. Flatten
  returns two points, ours `OverlappingSegments`. The upstream test title says
  “zero intersections”, but its actual assertion expects **two**. The distance
  query in the same test also matches.
- The near-parallel isolated-crossing fixture and issue #85's almost-touching
  endpoints match.

## Additional arc/linear adapters

The 30 arc-extra calls all match. These include exact projection-extrema
splitting (including issue #220), full-circle signed integrals, endpoint
tangents, midpoint, reversal, and reflection. Extrema splitting uses the public
`ellipse` center-form API, including full turns. The two closed-circle integral
fixtures compare Flatten's integral of `y dx` to the negative of our signed
area. This does not establish equivalence for arbitrary open-curve integrals.

Flatten's end tangent points backwards into the curve: the adapter negates our
forward derivative before normalization. Transform comparison samples five
parameter positions per piece, including endpoints; it is a geometric check,
not equality of stored center/angle representations. Initial transform failures
came from passing `affine.Affine` to the opaque `transform.Matrix` parameter;
converting via public tuple constructors resolved this adapter mistake.

No direct distance-to-infinite-line, standalone infinite-line/ray containment,
bounds, line-line intersection or object-construction API is claimed. Finite
shape intersections against their supporting lines are compared, with negative
ray parameters filtered only for a half-ray. The 67 linear scope calls include
repeated getters and methods; they are not 67 different missing features.

## Continuation inventory — investigations deferred

Per the instruction to finish inventory before revisiting discrepancies, no
production changes or bug fixes were attempted. The point/vector/matrix/box
batch has 190 matches and nine scope calls; the face/multiline batch has 182
matches and 20 scope calls. No new numerical flag appeared in either batch.

The polygon/Boolean/ray-shooting batch has 4,865 ordinary matches, 53 sampled
Boolean geometry matches, 29 scope calls, and **21 flagged calls across 12
upstream tests**. Most ordinary calls are helper bounds queries; see REVIEW.md.
The 21 flags are observations, not 21 confirmed bugs:

- **One distance timeout:** `polygons:317`, `Can measure distance between two
  polygons`. The 30-second worker cap was reached; no diagnosis yet.
- **Seven native Boolean errors:** calls 3380, 3497, 4033, 4150, 4682, 4799,
  4920. Issue #55 case 2 reports `InternalOverlapClassificationInconsistency`
  through `ArrangementGraphError/PathError` for union, difference and
  intersection. Issue #55 case 3 reports `ConstructionFailed` for those three
  operations. Issue #139 intersection also reports `ConstructionFailed`.
  Validity, overlap contracts and root causes remain to be checked.
- **Twelve conversion discontinuities:** calls 3115, 4278–4282, 4291–4296.
  Three occur when adapting upstream output after our Boolean query succeeded;
  nine occur while adapting an input (often an upstream result fed into a later
  operation). Endpoint gaps range approximately `1e-14` to `7e-13`.
  These are strict `subpath` construction rejections, not evidence that our
  Boolean engine produced discontinuous output. Inputs have not been snapped
  or modified to hide the mismatch. A conversion policy remains to be decided.
- **One sampled-region mismatch:** call 4354, upstream subtraction issue #15.
  Both outputs have area 20,000, but sampled containment differs. This warrants
  checking fill/orientation and upstream expectations before declaring a bug.

[DISCREPANCIES.md](DISCREPANCIES.md) lists exact call IDs, filenames and test names;
`discrepancy-queue.json` retains observations and existing adjudications. The
only independently confirmed library bug remains FL001 from the earlier batch.

Possible API ideas from scope review are nonlinear circle inversion, a separate
WKT adapter, and whole-shape/topological relation predicates. They are not
proposals to expand the library automatically; no API change is needed to keep
using these upstream tests as geometry evidence.


## Final residual inventory

No new flagged comparison arose from the 57 relation/planar-set/linked-list
upstream tests. The capture has 105 calls: one scalar distance match, three
sampled Boolean construction matches and 101 scope calls. Relation predicates
are intentionally not emulated by testing boundary intersections alone.

The discrepancy queue remains 23 call observations: two for confirmed FL001,
and the 21 polygon-batch observations awaiting investigation. The first-pass
inventory now covers all 23 files / 544 tests. COVERAGE-GAPS.md explicitly lists
unimplemented assertion adaptations; this is not a complete-parity claim.


## FL001 fix validation

The seed-list walk and descent-list walk now use explicit Result cases so the
JavaScript compiler emits loops rather than recursion through `result.try`.
Removing the first overflow alone exposed a distance search exceeding the
30-second diagnostic cap. Line/curve closest-pair queries now also use existing
crossing candidates to tighten their initial upper bound. Both points are
re-evaluated on the original segments, with parameters constrained to [0,1];
no intersection candidate is assumed to have zero distance. Failed crossing
queries retain the original distance-search fallback.

The standalone line/quarter-circle reproducer now returns distance zero for
both the segment and path APIs. Original audit calls `linear:66` and `linear:67`
match their reference distances. Original failure reports remain unchanged;
new results are in `distance-stack-fixed-probe.json` and
`linear-call66-public-results.json` / `linear-call67-public-results.json`.
Four regressions in `test/svg_path_flatten_closest_pair_test.gleam` cover operand
order, path dispatch, a positive sub-tolerance tangent gap, and disjoint fallback.

Validation on the final source: `scripts/test-portable all all` passed **762 tests
on each of Erlang and JavaScript**; `scripts/test-all` passed **2,016 fast and
31 slow tests**. Gleam 1.18.1. Source hash and commands are recorded in
`fl001-validation.json`. The audit snapshot is `eae13fa`; this change fixes FL001
and adds its regressions and validation evidence. F# is unchanged.
