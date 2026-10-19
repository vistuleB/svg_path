# Shared numerical threshold for line queries — 2026-10-19

Authorized follow-up to TOLERANCE-SEMANTICS-REVIEW.md. This tries the narrower
alternative to widening general curve endpoint matching.

## Change

Extract the existing curve search tolerance computation into
`numerical_search_tolerance`, retaining the same formula and error propagation.
The non-collinear line/segment solver now uses that threshold for:

1. stored endpoint admission against the finite line;
2. the signed-distance residual used by its supporting-line crossing query;
3. the allowed parameter overshoot before clamping to the finite line.

Changing only the first would leave the other paths able to admit the same
near-endpoint gap. Caller tolerance still certifies returned candidates. The
curve/curve solver's numerical behavior is unchanged by the helper extraction.
No new option, error variant or public function was added.

Constant geometry, collinear handling, overlap recognition, and path-result
grouping retain their previous rules. This resolves the demonstrated
non-collinear endpoint inconsistency, not every use of tolerance throughout the
library. Results remain numerical candidates, not exact algebraic certificates.

## Targeted results

The 29-case JS probe in `tolerance-semantics-strict-line.json` now gives:

- All nine line/quadratic/cubic exact-contact combinations retain the endpoint.
- All eighteen separated combinations (gap 1e-10 or 2e-9, caller tolerance 1e-9)
  return empty, regardless of representation.
- Constant-point proximity and parallel-line overlap controls are unchanged.

The new permanent `svg_path_endpoint_representation_test.gleam` additionally
checks forward/reversed line and quadratic combinations. Its targeted EUnit
run passes (one test containing 24 checks). It is selected for portable tests.
Existing FL006 and exact shared-endpoint regressions remain unchanged.

The initial candidate was tested in `/tmp/cavalier-strict-line-experiment`.
After its ordinary suite passed, the equivalent implementation was applied in
the main workspace, removing an unused argument and adding explanatory comments.
The canonical test-release command verifies the final workspace implementation.
No F# changes or commit in this experiment.

The isolated run reported 2,053 ordinary and 31 slow tests passing, but its
cleanup exited nonzero because the new regression was copied into the temporary
slow-test directory during the run. The copied workspace was restored afterward.
This is not recorded as a successful test-all command; the main workspace's
subsequent canonical run is the authoritative validation.

## Final main-workspace validation

`PATH=/Users/jpsteinb/.nvm/versions/node/v24.10.0/bin:$PATH scripts/test-release`
completed successfully (exit 0):

- Ordinary profile: 2,054 passed.
- Slow profile: 31 passed.
- Portable combined profiles, Erlang: 800 passed.
- Portable combined profiles, JavaScript: 800 passed.

Raw output: `strict-line-test-release.log`. The permanent new regression is
included in the main and both portable counts. FL006 and exact endpoint recovery
checks pass unchanged. Formatting, README recipe consistency, audit validation
and `git diff --check` also pass. Figures were not regenerated. The tested
implementation remains in the working tree, uncommitted; F# is deferred.
