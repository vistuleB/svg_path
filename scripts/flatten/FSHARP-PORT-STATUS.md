# F# port status since 3.1.3

Last released F# preparation: `11a36c9` (3.1.3). Corresponding Gleam release
preparation: `a0d45fbc`. This table distinguishes fixes from investigation records.

| Change | Gleam source | F# status |
| --- | --- | --- |
| FL001 crossing-seeded closest-pair search | `d6c7b63` | Already in 3.1.3 (`8914885`) |
| FL002 endpoint-distance line-overlap bound | `e4299170` | Pending |
| FL002/FL003 vertex-local cyclic sampling | `f10fa997` | Pending |
| FL004 backwards line correspondence rejection and `RefinedBoundaryNotClosed` | `bf59110d` | Pending |
| FL005 bounded line/arc and arc/arc closest-pair searches | `2a2f94a2` | Pending |
| FL006 five-sample chord-based ranking | `0a67c0aa` | Ported and validated in `bbd9d46` |
| FL006 arc correspondence direction guard | Gleam working tree | Ported in F# working tree; full validation passed |

The four pending rows are four change groups, not four independent bug counts.
Inspection of the F# overlap detector, arrangement, CSG and closest-pair dispatch
confirms these are not merely missing changelog entries. The present arc-guard
port does not silently include these older changes. In particular F# overlap
documentation describes the arc rule only; the analogous line rule is pending.

This is a port checklist, not release readiness or an assertion of exhaustive
Flatten.js test parity. Broader comparison gaps remain in `COVERAGE-GAPS.md`.

## Arc-guard validation

`scripts/test-release` in the F# repository passed **2,018 main + 30 slow tests**.
The three new tests mirror Gleam's reduced crossing in eight orientations,
valid partial/reversed overlap, and original default-options CSG fixture.
Log: `remaining-fl006-fsharp-arc-release.log`.

The guard and new tests are uncommitted in both repositories. F# public
signatures and options are unchanged. No figures or package artifacts were
generated, and no release version was changed.
