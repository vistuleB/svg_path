# Coverage and interpretation

> Current status (2026-10-18): projection fixes are committed as `dacdb370` and
> `090f8e63`; the original collection wording below is historical. See
> [RESUMED-TRIAGE.md](RESUMED-TRIAGE.md) and `triage-dispositions.json` for the
> latest dispositions. Raw baseline counts and results are preserved. Audit open; F# deferred.

## What was collected

The pinned core crate has 79 unit tests and 208 integration tests in eleven
files. All 287 passed unmodified and again with capture enabled. A second,
more detailed capture of core unit tests plus basics/views passed 97 tests.
These are upstream runs, not native regression-test counts.

The capture scripts modify only `/tmp/cavalier-audit-capture`. Public/core
operations are wrapped in a closure, preserving early returns and results.
A thread-local guard captures outermost instrumented calls and suppresses
recursive helper calls. Test assertions remain unchanged. Result-property
summaries run while the guard remains active. Both compressed capture logs
are preserved, along with scripts to recreate the instrumentation. The pinned
`upstream/` source files remain hash-identical to the downloaded archive.

The first capture records 202,835 calls, mostly repeated property-helper calls.
The collection selects closed cyclic-start representatives, preserving input
orientation. It ignores the result when forming equivalence classes, so the
first observed expectation is used; other start-position output variations
remain in the compressed raw log. This is deliberately not a claim to have
replayed every cyclic start position in our implementation.

`captured-cases.json` has 1,809 representatives. `extra-cases.json` adds 1,057.
324 records are marked helper-only; they are not independently compared.
The native target is Gleam JavaScript at `75970a6`. No F# or Erlang parity run
has been performed for these newly captured cases.

## What comparisons establish

- Offsets and shape offsets: number of walks and one-to-one per-walk signed
  area, length and bounds at absolute `1e-4`. Round joins, Butt band caps,
  default native construction/trimming; negate upstream's offset sign.
- Booleans: number of contours and one-to-one absolute area, length and bounds
  at `1e-4`, using native Nonzero fill. **Different contour decomposition can
  fail this comparison while describing the same filled region.** Holes versus
  touching components and XOR walks particularly require subsequent review.
  There is no filled-region or full-boundary equivalence proof here.
- Intersections: deduplicate positions within `1e-7`, then use a one-to-one
  matching threshold of `1e-6`. Several acceptable near-tangent candidates can
  therefore flag a multiplicity difference. Preserve raw positions in results.
- Line–line: compare the finite-segment intersection, treating upstream's
  `FalseIntersect` as no finite intersection. Its supporting-line parameters
  are not checked. Line–circle uses our supporting-line crossing query,
  including negative parameters. A zero-length line is not a valid direction;
  its error is an adapter/domain-policy flag, not a confirmed solver failure.
- Continuous overlap variants are marked contract-difference: their intervals
  have **not** yet been adapted to `encounters`.
- Winding: preserve numeric coordinate orientation. Native BoundaryWinding is
  recorded separately from upstream's integer result. Open winding policies
  differ. Whole-polyline containment is derived from intersections and point
  containment for these valid simple closed inputs; it is not a new native API.
- Segment centers, bounds, lengths, midpoint and projection positions use
  `1e-6` absolute diagnostic comparisons. Projection ties can have different
  valid witnesses. Near-semicircle bulge-to-SVG conversion can amplify rounding;
  a center discrepancy is not automatically evidence of a native bug.
- Segment tangent checks compare direction only, not upstream's radius-scaled
  magnitude. Split checks compare sampled geometry of both pieces, not bulge
  representation. Distance-threshold checks compose native distance with `>`.
- Upstream's approximate sagitta boxes are recorded as scope, not compared for
  equality with exact native bounds. Vertex counts, user-data propagation,
  iterator state, borrowed views and Rust panic behavior are different contracts.

## Unmapped options and assertions

Cavalier supports `touching_loop_behavior: Preserve/Separate` and
`coincident_segment_behavior: Preserve/Discard`. We preserve these settings in
records but use the same native default for each. Flags under alternate policies
are policy comparisons, not evidence that our default is wrong. Its
`handle_self_intersects`, positional epsilon, offset-distance epsilon, and
Boolean collapsed-area threshold do not map one-to-one to our option types.
No native tolerance or trimming override was silently introduced.

Even tests with captured operations can have important uncaptured assertions:
repeated-position removal, redundant vertex counts, user-data sets, Boolean
slice provenance/result-info, point-to-segment index ownership, source mutation,
full local/global self-intersection lists and routing topology. The coverage
ledger means **selected operations observed**, not the whole test adapted.

31 tests have no selected captured operation. The exact names are in
`TEST-COVERAGE.md` / `test-coverage.json`:

- Six basic iterator/mutation/repeated-vertex tests and the open-view wrapping
  panic test are representation/API-scope reviews. Reversal itself is exercised
  by offset/Boolean variants, but its mutation assertions are not ported.
- The vector operator unit test is a utility/API-scope review.
- Twenty-three core math/internal algorithm tests remain explicit adaptation
  gaps: sweep membership/tolerance, local self-intersections, node/routing and
  raw-offset invariants. Some concern private data structures with no direct
  equivalent; their public geometric consequences may still yield useful probes.

This is a complete ledger of the selected **core test suite**, not exhaustive
upstream parity. Doctests, FFI, UI, examples and benchmarks are outside the
current collection. FFI ABI and UI assertions are not native geometry contracts.

## Timing and disposition

The broad pass used four workers with ten seconds per representative. Timeout
flags were subsequently selected for a single-worker, thirty-second replay;
`timeout-results.jsonl` records that observation separately. All thirteen completed:
one match, three property discrepancies and nine native errors. Timeouts are bounded
screening results, not a performance benchmark or a confirmed regression.

`DISCREPANCIES.md` groups raw flags by original source file, test and operation;
`discrepancy-queue.json` retains individual cases. Counts include orientations,
policy variants and related helper calls. They are **not counts of bugs**.
No production fix or permanent regression test has been added during collection.
