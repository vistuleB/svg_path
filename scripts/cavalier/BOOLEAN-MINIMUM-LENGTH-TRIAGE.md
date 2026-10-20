# Boolean minimum-length closure investigation — 2026-10-20

Production baseline: `b009298`. No production changes.

## Question and disposition

The 16 default failures in `parametric_from_point_debug_assert_reported2`
(CC01059 and CC01063–CC01077) are understood short-piece filtering failures
under the documented CSG options contract. No new repair is proposed.

The default threshold is 1e-5. Source-image interval reconstruction finds two
missing intervals per case, both shorter than that threshold. For CC01059,
an observational trace of a copied generated JS build confirms that
`split_atomic_pieces_for_parameters` actually discards:

- Source segment 6, parameters 0.9999954351177222–1: a line of length
  3.949079659102007e-6.
- Source segment 7, parameters 0.9999967007057828–1: a circular arc with length
  upper bound 3.949079658936149e-6.

The missing intervals match those traced deletions. Four nonzero operand vertex
flows remain, and the public CSG call returns
`ArrangementGraphError(ConstructionFailed)`. This is the behavior explicitly
specified in `csg.Options`: pieces smaller than the threshold may open an operand
boundary, in which case the operation fails instead of lowering the threshold
or widening endpoint clustering.

## Current workaround verified through public CSG

All 16 cases were run with `tolerance = 1e-6` and four minimum lengths:

| Minimum length | Public operation outcomes |
| --- | --- |
| 1e-5 (default) | 16 documented construction errors |
| 1e-6 | 16 successes |
| 1e-7 | 16 successes |
| 1e-8 | 16 successes |

These are union, intersection, difference and XOR across four presentations of
the same upstream fixture. Successful union/intersection/difference returns one
subpath and XOR returns two. The earlier smaller-threshold cyclic-order failure
is no longer reproducible after the existing repair. A separate arrangement
replay verifies balanced operand flows for all 16 at 1e-8.

This establishes successful construction, not exact geometric equivalence with
upstream. Source-image gaps at smaller thresholds are not automatically individual
filtered fragments: endpoint clustering and progressive refinement also affect
images. Do not infer a new bug from their combined lengths or claim that this
probe independently certifies every intermediate decision. Stronger Boolean
geometry/decomposition checks remain in the broader audit queue.

## Reproduction and validation

Using the current compiled portable JavaScript build:

```sh
node scripts/cavalier/probe-boolean-errors.mjs > scripts/cavalier/boolean-errors-current.json
node scripts/cavalier/probe-boolean-minimum-length.mjs > scripts/cavalier/boolean-minimum-length-current.json
python3 scripts/cavalier/prepare-boolean-discard-trace.py
node /tmp/cavalier-boolean-discard-trace/probe.mjs > scripts/cavalier/boolean-discard-trace.json
```

The copied-build instrumentation records size-filter decisions without changing
return values. The public-operation sweep runs 64 calls plus their arrangement
probes. The separate earlier-error replay covers 20 cases at two settings.
These are JavaScript diagnostics; no new Erlang/full-suite run or figure generation
was needed because production code is unchanged. No F# changes.
