# Assertion scope review — first five upstream files

Files: `test/classes/arc.js`, `circle.js`, `segment.js`, `line.js`, `ray.js`.
This initial batch contains 183 of the 544 baseline tests. Later batches are
recorded below. This is an operation-level bug-finding audit, not a port of every
assertion or a claim of full parity.

`inventory.json` records each test name, captured operation IDs and reviewed
scope notes. Calls include a per-file test ordinal so duplicate test titles
(the arc length tests) do not accidentally receive one another's calls.
`assertion-review.json` gives explicit dispositions for all 52 tests without
captured operations in these five files.

## Compared geometry

- Arc/circle length, bounds, point membership, arc-length locations,
  intersections and distances; limitations below.
- Arc midpoint, endpoint tangent direction, reversal, reflection, closed-circle
  signed area and splitting at x/y projection extrema.
- Finite segment length, bounds, point membership, arc-length locations,
  tangent direction, midpoint, translation, rotation, intersections and distance.
- Infinite line/ray intersections with finite shapes use the public
  supporting-line crossing operation. Positive-ray filtering is applied in the
  adapter. Continuous collinear overlap is classified separately.

## Deliberate comparison limits

- Dynamic constructors, defaults, exceptions for invalid dynamic argument
  types, cloning/identity and JSON object round trips are upstream object-model
  assertions. Gleam's immutable, typed model differs.
- Center/angle arc constructors and their endpoint getters are not SVG endpoint
  constructors. A complete circle is represented by multiple SVG arcs. No
  equivalence of the constructor/accessor contracts is implied.
- SVG element generation and stroke/id/class style handling are outside the
  path-data serializer's contract. Captured geometry inside those SVG methods
  does not make the SVG-output assertions covered.
- Intersection comparison checks deduplicated point sets. It does not require
  upstream point ordering or raw multiplicity at adjacent boundary edges.
- Distance comparison currently checks the scalar distance, not upstream
  witness-segment ordering or selection among equally close points. Exact
  witness assertions remain unported; this includes the line/box test whose
  whole query is outside our public object API.
- Transform comparison checks sampled geometry, not each stored center, angle
  or direction field independently. Reversal similarly checks sampled reversed
  geometry rather than identical representation.
- Bounds helper assertions made inside another test (for example box-vs-box
  overlap in the segment intersection tests) are not automatically covered by
  the segment comparison.
- Ray slope, bounds and containment in the seven directional ray tests are
  outside our object API; their segment-intersection assertions are compared.
- Segment slope has no dedicated getter; its direction is covered by the
  separate tangent fixture, not a replay of the slope assertion.

These limits are retained explicitly rather than calling each captured test
“passed”. No new convenience API is proposed merely to reproduce Flatten's
object model.

## Continuation: primitives, polygons and chains

The continuation executes the four point/vector/matrix/box files (82 tests),
the polygon/Boolean/ray-shooting files (131 tests), and the face/multiline files
(41 tests). All those upstream tests pass under capture. This does not imply
that all their assertions have Gleam equivalents or have been replayed.

Primitive adapters use public `point`, `affine`, `transform`, bounds and distance
queries. Matrix composition preserves upstream multiplication order; radians
are converted to degrees. Vector normalization maps a thrown zero-vector error
to our `Error(Nil)`. Box arc-containment uses our exact curve bounds plus ordinary
rectangle comparisons. No new shape-containment API is implied.

Polygon faces remain distinct subpaths. Polygon point membership and Boolean
operations use `EvenOdd`, consistent with upstream ray-count parity. Polygon
area compares absolute signed integrals, matching the upstream area method;
it is not a claim about fill-rule area on arbitrary self-intersecting polygons.

Boolean output validation uses absolute signed area (relative diagnostic
threshold `1e-6`, minimum absolute threshold `1e-6`) and a deterministic 13×13
containment grid over the operand bounds. Samples classified as boundary by
either implementation are skipped and counted. A `sampled-geometry-match` is
weaker than boundary equivalence; no output vertex/edge-count, edge-order or
DE-9IM assertion is claimed by this comparison. Degenerate zero-area or narrow
features may escape this sampling and need stronger checks during follow-up.

The polygon batch captures 4,968 calls, **4,736 of which are segment-bound getters**
invoked by upstream helpers. Those calls are reproducible but should not be
interpreted as thousands of independent geometry regressions. Captured helper
calls in a constructor, mutation, split/cut, SVG-output, validation or island
extraction test do not cover that test's principal structural/output assertions.
In particular, polygon cutting, inner/outer clipping output lists, paired
intersection ordering, polygon validity and island extraction still need
separate decisions/adapters. Face/multiline storage mutations and point-based
splitting likewise are not validated by helper bounds or distance matches.

Face signed area reverses the numeric sign to match Flatten's `integral y dx`
convention. Face and finite multiline length, point-at-length and distances are
compared. Infinite multline geometry remains outside the finite path model.
Witness segment order/equality remains a limitation of the distance adapter.

Six files now have explicit scope-only dispositions: circle inversion,
DE-9IM matrix storage, WKT parsing, SVG attributes, namespace exports, and global
mutable tolerance. None is called a passing geometry comparison. Relation algorithms, planar sets and linked-list scope are recorded in the
final batch below.


## Final residual batch and first-pass inventory closure

`run-upstream.cjs residual` runs relation algorithms (29 tests), planar sets
(15), and linked lists (13): all 57 pass. Capturing relation inputs preserves the
fixtures for later use without claiming we implement the same predicates.

- Relations: 101 residual scope calls include the DE-9IM and whole-shape
  predicates and related shape-containment calls. Filled-region intersection,
  boundary intersection, touching and covering are not interchangeable. The
  three Boolean construction calls in relation tests pass the existing sampled
  geometry comparison. This does not validate the relation assertions.
- Planar sets: one scalar point-to-seven-circle-boundaries distance comparison
  matches (distance 20). It uses the minimum of native segment-distance queries;
  it does not test Flatten's spatial index, search ordering, mutable object
  identity or chosen witness.
- Linked lists: all 13 tests concern mutable doubly linked storage, identity,
  ordering or cycle detection. There is no corresponding svg_path public API.

Every upstream test now has an inventory disposition. A captured operation is
still not necessarily the principal assertion of its upstream test. The seven
categories in COVERAGE-GAPS.md enumerate remaining adaptation work, with exact
upstream filenames and test names; coverage-gaps.json links those entries into
inventory.json. Completion here means no unreviewed test files, not all
assertions translated or all discrepancies resolved.
