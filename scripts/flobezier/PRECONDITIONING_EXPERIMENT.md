# Supplementary polynomial intersection preconditioning

Experiment and candidate implementation, 2026-10-14, based on `e09bef8`.

## Decision

A supplementary search is useful without changing the metric or approximate
overlap policy. It adds candidates; it does not replace the original search.
No API fields or options have been added.

For polynomial curve pairs whose combined control-coordinate ranges have
aspect ratio greater than 1,000,000, with both ranges positive and finite:

1. Run the original solver with the original options. Its errors still propagate.
2. Translate and independently scale the two coordinate ranges into [0,1].
3. Run a second bounded search, using the original max_depth and an internal
   normalized residual target of 1e-12. Ignore failure of this supplementary pass.
4. Evaluate candidate parameters on the ORIGINAL segments and construct the
   original-coordinate midpoint. Retain only candidates whose point-to-curve
   distances satisfy the user's ORIGINAL tolerance.
5. Add candidates not already covered by the existing 1e-7 beam parameter
   deduplication radius. Keep every original candidate and sort the result.
6. Existing public parameter cleanup and final certification still apply.

Arcs and zero-range axes are excluded. Line-specific and constant-segment
handling remain unchanged. Overlap classification still happens first in the
original metric. Consequently FI004's default NonAffineOverlapCorrespondence
result remains unchanged. At tolerance 1e-12 the missing reference root is
added to the original approximate candidates, rather than replacing their list
with a purportedly certified single root.

The aspect-ratio threshold and normalized residual are internal heuristics,
not new guarantees. Extra search increases work for eligible pairs, and this
remains an incomplete numerical search. Arbitrary rotations or badly conditioned
translations need not give invariant candidate inventories.

## Experiment

`preconditioning-experiment.mjs` compares raw and normalized searches for:

- FI004 at tolerance 1e-12;
- 22 selected polynomial pairs from the captured upstream audit, with their
  y coordinates multiplied by 1e-12 (preserving exact intersection parameters);
- one disjoint parallel control pair.

There are 46 reference pairs across the first 23 cases. The original search
matches 12 at parameter tolerance 1e-7. The normalized search matches all 46;
all its candidates pass a check in the original coordinates.

`preconditioning-integrated.mjs` repeats the experiment through the internal
point-query composition hook, including the actual supplementary implementation
and original-coordinate certification. It also matches all 46 reference pairs,
with no query errors. These compressed cases intentionally test the point solver
without the overlap precheck; they do not claim the public default query ignores
approximate overlap. Results are in the corresponding JSON files.

The experiment scripts use the probe's compiled JavaScript dependency and the
locally archived `intersections-results.json` audit inventory. They are diagnostic
experiments, not the portable regression runner. The standalone FI004 fixture is
also retained separately in `almost-collinear-fixture.json`.

## Regression validation

Three tests in `test/svg_path_conditioned_intersections_test.gleam` verify:

- recovery of the reference FI004 root in both argument orders;
- retention of all original candidates and original-coordinate acceptance;
- preservation of default overlap rejection and strict certification errors.

The tests are registered in the portable suite. A temporary runner at
`/tmp/svg-path-conditioned-targeted` ran them with the existing overlap,
intersection, encounter, folded-overlap, and constant-segment tests:

- `gleam run --target javascript -m conditioned_targeted`: 100 tests passed.
- `gleam run --target erlang -m conditioned_targeted`: 100 tests passed.

Logs: `/tmp/conditioned-tests-js.log`, `/tmp/conditioned-tests-erlang.log`.
Formatting and whitespace checks pass.

Full validation subsequently completed with `scripts/test-release` (exit 0):

- Root fast profile: 2,012 passed, no failures.
- Root slow profile: 31 passed, no failures.
- Portable combined profile, Erlang: 758 passed, no failures.
- Portable combined profile, JavaScript: 758 passed, no failures.

Full log: `/tmp/preconditioning-release-tests.log`.
`scripts/generate-published-figures` subsequently completed with exit 0.
All 33 published Gallery figures and 13 README figures were regenerated.
All 46 SVGs parse successfully and are byte-for-byte identical to the saved
pre-run outputs. All 29 Erlang gallery jobs completed without failures; the
four JavaScript W3C figures and all README outputs passed the generator checks.
Logs: `/tmp/preconditioning-figures.log`; hash comparison:
`/tmp/preconditioning-figures-comparison.json`.
The implementation, regression tests, and validation record are included in this change.
