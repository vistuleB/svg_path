# Preserve certified full overlaps, 2026-10-13

Fixtures 107, 122 and 123 exposed an overlap detector defect: accepted full
correspondences were discarded when nearby endpoint projection proposals
contradicted each other during merging. The [investigation](FINAL_BOOLEAN_INVESTIGATION.md)
records the reduced counterexample and downstream CSG failures.

## Repair

After the existing non-affine rejection check, prefer an accepted full-domain
correspondence only when all of these conditions hold:

- Both inputs are polynomial segments of the same degree (line, quadratic or cubic).
- Corresponding control points, reversed when appropriate, are within tolerance.
  The convex-hull property bounds separation for the whole affine correspondence,
  not just the detector's interior samples.
- Both oriented control polygons are monotone along a shared x or y coordinate,
  with at least one strict step on each. The curve coordinate is then strictly
  monotone in the interior, excluding additional traversal branches. Stationary
  endpoints are permitted.

Under these conditions the full map explains both complete parameter domains.
Nearby alternative endpoint addresses cannot erase it. Otherwise the existing
merger runs unchanged. Arc handling, partial overlaps, genuine non-affine
rejection, tolerances, minimum lengths and arrangement edge geometry are unchanged.
This is deliberately a sufficient condition, not a general overlap solver rewrite.

## Regressions

Two direct overlap tests cover the reduced translated cubic from 107, both
orientations and its translation to the origin; and the rounded reverse cubic
pair from 122/123, including a stationary endpoint and swapped operands. They
also check that point intersection reports `OverlappingSegments`.

Three portable full-fixture regressions compare CSG output against pinned
Paper.js expectations: signed area magnitude, bidirectional boundary samples,
closed output contours and off-boundary fill classification. The existing
partial-overlap, multiple interior address, closed-cubic and non-affine tests
remain in the portable suite. Sampled comparison is not exhaustive equivalence.

## Validation

- `scripts/test-release`: **1,929 fast**, **26 slow**, **671 portable Erlang**,
  **671 portable JavaScript**, all passing.
- `PAPER_AUDIT_TIMEOUT_MS=30000 PAPER_AUDIT_REPORT=./boolean-screening-after-full-overlap.json node scripts/paperjs/probe-booleans.mjs /path/to/paper`:
  **112 sampled matches, 59 library errors, seven adapter cases**. All 109 earlier
  matches remain matches; each remaining error is identical to its previous
  screen result and has an understood overlap-contract classification.
- Fixtures 107/122/123 complete in approximately 4.84/1.18/0.92 seconds in this
  two-worker diagnostic run. No timing threshold is asserted in the tests.
- `scripts/generate-published-figures`: **13 README and 33 Gallery SVGs**
  regenerated, all **46 byte-for-byte identical** to their pre-fix files.
  SHA-256 pairs are saved in `full-overlap-figure-verification.json`.

The broader Paper.js audit remains unfinished; these results settle the three
confirmed overlap-merging failures without claiming complete parity.
