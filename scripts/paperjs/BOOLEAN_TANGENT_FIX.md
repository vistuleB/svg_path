# CSG tangent boundary ordering

## Change

Binary CSG now pairs retained boundary edges in the geometric clockwise order
already computed by `arrangement.build`. Boundary orientation is determined
from the classified edge's endpoint vertices, because classification can reverse
an edge relative to its stored arrangement direction. Non-boundary edges are
filtered out without sorting the remaining rays again.

The previous code sorted endpoint tangent angles. That discarded the geometric
separation of tangent curves, producing consecutive incoming rays in fixtures
172 and 69. The change removes that second angle sort and its direction-query
helpers. It does not change edge geometry, endpoint clustering, winding-side
sampling, overlap correspondence, or numerical tolerances.

The arrangement's order inside an unresolved group remains its documented,
deterministic best-effort order. CSG still rejects inconsistent successors; this
is not a claim that all ambiguous arrangements now reconstruct successfully.
Unary `nested_contours` is unchanged.

## Regressions

`test/svg_path_csg_tangent_order_test.gleam` adds two portable tests:

- A reduction with four cubic segments and integer controls. Two internally
  tangent loops meet at `(0,0)` with a common vertical tangent. Subtraction must
  produce a closed result of area `9.6 - 2.4 = 7.2`, with the expected inside and
  outside points. All four combinations of operand orientation are checked.
  The returned arrangement must equal an independently built arrangement.
- The original Paper.js fixture 172. It checks closure and exact endpoint
  adjacency, area, bidirectional boundary distances, and off-boundary fill
  samples against the saved upstream expected geometry. Rounded upstream path
  coordinates require geometric allowances rather than serialized equality.

Before the fix, `scripts/test-portable javascript` returned **654 passes and two
failures**, both `InternalBoundaryTopologyError(..., SectorMismatch)` at the
new success assertions. After the change, `scripts/test-portable` passed
**656 tests on Erlang and 656 on JavaScript**.

## Full Boolean screen

`boolean-screening-after-tangent-order.json` reruns all 178 saved comparisons:

| Outcome | Before | After |
| --- | ---: | ---: |
| Sampled geometry match | 102 | 104 |
| Library error | 69 | 67 |
| Different API adapter | 7 | 7 |

Only fixtures **69 and 172** changed status. All 102 previous sampled matches
remain matches, with no timeouts or sampled geometry mismatches.

The maximum sampled boundary distances for recovered fixtures are approximately
`1.0e-5` (69) and `1.31e-6` (172), below the existing `0.001` comparison allowance.
These are sampled checks, not exhaustive geometric equivalence. Fixture 69 is
currently retained in this diagnostic screen, not a new portable test.

Reproduce after building the portable JavaScript target:

```sh
PAPER_AUDIT_TIMEOUT_MS=30000 PAPER_AUDIT_REPORT=./boolean-screening-after-tangent-order.json node scripts/paperjs/probe-booleans.mjs /tmp/svg-path-paper-audit/node_modules/paper
```

The pre-fix instrumentation and counts in `BOOLEAN_ERROR_TRIAGE.md` are
historical evidence from commit `cd49807`; they must not be regenerated against
the fixed code as if all 69 old errors should persist.

## Full-suite verification

`scripts/test-release` passed **1,914 fast tests**, **26 slow tests**, and
**656 portable tests on each of Erlang and JavaScript**. Formatting and
`git diff --check` passed. All other 176 Boolean-screen statuses are unchanged;
all 67 remaining error payloads are identical to the previous screen.

The native Erlang `paper_boolean_failures` diagnostic also returns `Ok(Nil)`
for fixtures 69 and 172 (the probe maps successful paths to Nil). Geometry
comparison for 69 remains the saved JavaScript screen; fixture 172's geometric
regression runs on both targets.

`scripts/generate-published-figures` completed successfully, including its
1,914-test fast-profile prerequisite. All **13 README figures and 33 Gallery
figures** were regenerated and compared byte-for-byte against the local pre-fix
baseline: **zero changes**. All parse as XML, retain explicit dimensions and a
viewBox, and contain no NaN/Infinity values. Promoted Gallery SVGs exactly match
the generated outputs. The new tangent regression is outside the existing
published figure corpus, so unchanged published figures are expected.
