# F# port status since 3.1.3

Last released F# preparation: `11a36c9` (3.1.3). Corresponding Gleam release
preparation: `a0d45fbc`. This table distinguishes fixes from investigation records.

| Change | Gleam source | F# status |
| --- | --- | --- |
| FL001 crossing-seeded closest-pair search | `d6c7b63` | Already in 3.1.3 (`8914885`) |
| FL002 endpoint-distance line-overlap bound | `e4299170` | Ported and validated in `c7a6e52` |
| FL002/FL003 vertex-local cyclic sampling | `f10fa997` | Ported and validated in `c7a6e52` |
| FL004 backwards line correspondence rejection and `RefinedBoundaryNotClosed` | `bf59110d` | Ported and validated in `c7a6e52` |
| FL005 bounded line/arc and arc/arc closest-pair searches | `2a2f94a2` | Ported and validated in `c7a6e52` |
| FL006 five-sample chord-based ranking | `0a67c0aa` | Ported and validated in `bbd9d46` |
| FL006 arc correspondence direction guard | `efcc3aa` | Ported and validated in `7ee6a3a` |

The four remaining change groups are now implemented in F#. Regression mapping:

- `svg_path_flatten_overlap_test.gleam` → `FlattenOverlapTests.fs` (six tests).
- `svg_path_flatten_cyclic_order_test.gleam` → `FlattenCyclicOrderTests.fs` (three tests).
- `svg_path_flatten_boundary_test.gleam` → `FlattenBoundaryTests.fs` (two tests).
- Seven FL005 tests in `svg_path_flatten_closest_pair_test.gleam` →
  `FlattenClosestPairTests.fs`, alongside its four existing FL001 tests.

The cyclic-order port retains F#'s length-valued radial crossing residual;
geometry evaluation now takes place relative to the arrangement vertex.
The new public error is `Csg.RefinedBoundaryNotClosed(pathIndex, vertex, netFlow)`.
Option shapes and caller tolerance semantics remain unchanged.

This is a port checklist, not release readiness or an assertion of exhaustive
Flatten.js test parity. Broader comparison gaps remain in `COVERAGE-GAPS.md`.

## Arc-guard validation

`scripts/test-release` in the F# repository passed **2,018 main + 30 slow tests**.
The three new tests mirror Gleam's reduced crossing in eight orientations,
valid partial/reversed overlap, and original default-options CSG fixture.
Log: `remaining-fl006-fsharp-arc-release.log`.

The arc guard and its tests are committed in both repositories. That change
left F# public signatures and options unchanged. No figures or package artifacts were
generated, and no release version was changed.

## Remaining ports completed (2026-10-16)

F# commit `c7a6e52` completes FL002–FL005. `scripts/test-release` passed
**2,036 main + 30 slow tests**, with zero failures or skips. Main test execution
was 1m24s; slow execution was 28s. These are single-run validation timings,
not a performance benchmark. Build completed without warnings or errors.

Full log: `remaining-fsharp-ports-release.log`. `git diff --check` passed.
All production changes since the 3.1.3 release preparation are now represented
in F#. No figures, package artifacts, or release versions were changed.
