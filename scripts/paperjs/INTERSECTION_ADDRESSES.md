# Intersection addresses and crossing flags, 2026-10-13

This pass covers every extracted non-#1409 assertion in the pinned
`Path_Intersections.js`: **29 fixtures, 54 expected contacts**. The three #1409
assertions have their [own completed checks](CROSSINGS_1409.md).
No production code was changed.

## Address checks

For every returned point and every represented left/right parameter pair:

- Require valid addresses in the original single-subpath paths.
- Evaluate both addresses through the public `path_point` API.
- Require each evaluated point to be within the default **1e-9** tolerance of
  the reported intersection, and the two evaluated points within that tolerance
  of each other.
- Classify the addressed pair; reject errors and `Indeterminate`.

The JavaScript diagnostic recorded **81 parameter pairs**. The largest pair
separation was **1.74794e-12**, and the largest residual from a reported point
was **8.81073e-13**. These are observations, not increased test tolerances.
The native portable tests perform the same checks on both runtimes, without
requiring identical extra candidate counts near tangency.

Match upstream contacts by point and the supplied left segment index/time,
independently of output order. Point comparison keeps the previous per-coordinate
`1e-5` allowance for rounded upstream coordinates. Interior times use `5.1e-6`
for five-decimal rounding. Exact endpoint times 0 and 1 must match exactly.
No segment-boundary alias adaptation was needed in this extracted batch.
Upstream provides no corresponding right-hand times: those are verified by
geometric reconstruction rather than invented reference values.

The initial harness incorrectly applied the interior-time allowance to endpoints,
matching #1255's exact endpoint assertion to two additional interior candidates.
The corrected adapter matches the exact `(0,1)` endpoint pair, classified
`EndpointContact`. The other pairs (left times approximately `1.20e-7` and
`2.26e-7`) are tolerance-valid interior candidates; the local classifier returns
`Crossing` for them. The search contract permits such extra candidates, and the
classifier explicitly assumes supplied addresses identify an already-known
intersection. No upstream flag is assigned to those extra parameter pairs.

## Classification results

| Disposition of expected contacts | Count |
| --- | ---: |
| Address and crossing flag agree | 45 |
| Address agrees; upstream does not assert a crossing flag | 6 |
| Shared-arc boundary classification differs by API convention | 2 |
| Previously understood near-contact excluded by our tolerance | 1 |

The absent contact is fixture 18 / #1233's first expectation. The prior audit
established that it lies outside the default coincidence tolerance. Its absence
is checked explicitly; the other three self-intersections match addresses and
crossing flags.

### Fixture 12: two boundaries of a continuous overlap

The shared interval is left segment 0, approximately `[0.277691475974,1]`,
corresponding to all of right segment 1. Its endpoints are approximately
`(426.611718000375,448)` and `(376,480)`.

Paper.js 0.12.18 reports **both `hasOverlap() == true` and `isCrossing() == true`**
at those endpoints, agreeing with the pinned upstream crossing expectations.
Gleam reports `Touching` for the local addressed pairs. The shared arc means
these are not isolated transverse crossings with four distinct alternating
branches. Our overlap-aware API retains the continuous correspondence separately.
The other two expected contacts in this fixture are isolated crossings and agree.

The implementations use different local tests. Paper.js `CurveLocation.isCrossing`
(`dist/paper-full.js`, starting near line 7945 in 0.12.18) compares strict angular
ranges, using a tangent for an interior address and finite-offset rays at a segment
boundary. It does not exclude `hasOverlap()` from the crossing predicate.
Gleam's classifier uses local traversal directions and tolerance-aware equal-arc-
length branch samples; coincident branches can have indeterminate touching order.
Thus the two booleans cannot be copied across as an isolated-crossing requirement.
The tests explicitly adapt only these two flags, preserving their parameter checks.
This is a documented convention difference, not a confirmed library defect.

## Validation and scope

`scripts/test-portable`: **704 tests passed on Erlang and 704 on JavaScript**,
including 29 new address/classification regressions. The full release suite
and figures were not rerun for this test-only addition.

The new 29-test module also exercises the eight earlier point-list API differences
through contract-aware queries. Fixtures 12 and 19 first verify the point-only
`OverlappingSegments` response, then use `encounters.path` to validate returned
addresses and compare the expected contacts. Other near-tangent extras remain
allowed, but their addresses must still satisfy the geometric tolerance.

This completes address reconstruction and supplied index/time/crossing comparisons
for the **32 extracted assertions**, including #1409. It does not cover unextracted
upstream assertions, additional scale/transform variants, or all possible overlap
and near-tangency classification behavior. The raw upstream runner intentionally
retains the eight known point-list contract mismatches.

## Reproduction

```sh
python3 scripts/paperjs/generate-intersection-addresses.py
gleam format test/svg_path_paper_intersection_addresses_test.gleam
scripts/test-portable
node scripts/paperjs/probe-intersection-addresses.mjs
python3 scripts/paperjs/collect-intersection-addresses.py
# Optional pinned Paper runtime cross-check:
node scripts/paperjs/probe-paper-overlap-crossings.cjs /path/to/node_modules/paper
```

`intersection-address-findings.json` records evaluations and classifications;
`intersection-address-comparison.json` records all 54 expected-contact dispositions.
`paper-overlap-crossing-reference.json` preserves the pinned-runtime overlap flags.
The generated tests retain exact cubic inputs and upstream license attribution.
