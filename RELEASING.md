# Releasing

This checklist supplements the figure and asset-tag workflow in
`COMMIT_CYCLE.md`.

## Required verification

1. Run the canonical pre-release test command:

   ```sh
   scripts/test-release
   ```

   This runs both the fast profile and the slow convex-hull profile. Neither
   `gleam test` nor `scripts/test-fast` alone is full release verification.
   The slow profile lives in `test_slow/` and is documented in
   `test_slow/README.md`.

2. Report the command precisely. The phrase “full suite passes” is reserved
   for a successful `scripts/test-all` or `scripts/test-release` run.

3. Confirm that the worktree contains no accidentally parked test module:

   ```sh
   test ! -e .test-disabled/svg_path_convex_hull_test.gleam
   ```

4. Confirm that no temporary package-source debug module is present:

   ```sh
   test ! -e src/svg_path/debug.gleam
   ```

   Debug/probe constants should live in `examples/debug/` fixtures rather than
   in package source.

5. Complete the README figure, changelog, version, asset-tag, release-tag, and
   publication steps in `COMMIT_CYCLE.md`.
