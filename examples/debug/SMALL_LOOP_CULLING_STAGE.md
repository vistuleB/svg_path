# Small-loop culling placement experiment

The private `small_loop_culling_stage` constant in `offset.gleam` selects:

- `BeforeCuspTrimming`: established H-to-I pairwise geometry shortening.
- `InsideCuspTrimming`: no pre-AG shortening; only a cusp-trimming call runs
  small-loop detection. Offside and final in-band trimming do not run it.

The embedded implementation uses the cusp arrangement's source images, in
source traversal order. For each adjacent pair of opposite REVERSED states,
it finds the earliest shared vertex on the previous preimage and latest
matching vertex on the next. The intervening edge ids are marked for deletion
after submerged-run rescue and before the existing parity-capacity finish.
All occurrences of a selected edge are marked. Geometry, endpoint clustering,
sliver handling, and extra cuts are owned by the arrangement; the culler does
not run a second intersection solver or alter segments.

As before, the previous preimage's original start and next preimage's original
end are not cut candidates. Only closed inputs include the last/first pair.
Ordinary shared endpoints alone select no edges. The implementation deliberately
does not invent additional iterations over newly adjacent preimages after
deletion; it selects loops between the original adjacent pairs.

Four tests in `test/svg_path_cusp_small_loop_test.gleam` cover opposite/same
REVERSED states, extra graph cuts inside a loop, wrapping adjacency, and an
ordinary shared endpoint.

With `InsideCuspTrimming`, `scripts/test-fast` completed with 1,593 passing
tests and two failures: the existing A/V single-offset micro-loop regressions
at offset 1.05. Those use final in-band trimming, not cusp trimming, so their
previous small-loop cleanup is deliberately absent under this experiment.
The tests have not been weakened or rewritten to accept the changed result.

The constant is restored to `BeforeCuspTrimming` pending evaluation of that
behavior change; `scripts/test-fast` then passes 1,595 tests. The separate final-orientation experiment remains in the
worktree and still has its previously reported concave-square fixture conflict.
