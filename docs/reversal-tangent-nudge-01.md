# Reversal-fit tangent nudge experiment: 0.5° → 0.1°

Date: 2026-10-16. Baselines: Gleam `e8a043fd` and F# `81b8d30` (3.1.4).
Accepted on 2026-10-16 as the baseline for the forthcoming Cavalier Contours audit.
The held 3.1.4 release and asset tags remain unchanged.

## Change

Only the reversal-fit tangent nudge constant was changed in each implementation:
Gleam `reversal_fit_tangent_nudge_degrees` and F#
`reversalFitTangentNudgeDegrees`, from 0.5° to 0.1°.
The sign, opposite-endpoint angular clamp, fitting policies, tolerances, and
other constants were left unchanged. No test expectations were adjusted.

## Completed checks

| Check | Result |
| --- | --- |
| Gleam main suite, run by `scripts/generate-published-figures` | 2,038 passed |
| `scripts/test-portable all fast`, Erlang | 779 passed |
| `scripts/test-portable all fast`, JavaScript | 779 passed |
| F# `scripts/test-fast` | 2,036 passed, no skips |
| Gleam `scripts/generate-published-figures` | 13 README + 33 Gallery figures generated |
| F# `scripts/generate-readme-figures` | 13 figures generated |
| F# `scripts/generate-gallery-figures` | 33 succeeded, 0 failed |
| `git diff --check`, both repositories | Passed |

The entire main suites cover the offset/stroke tests and their shared geometry
regressions. This was not a canonical full release run: the separate slow suites
were not rerun. Local test logs and before/after previews are retained in the Gleam checkout
under `examples/debug/tangent-nudge-01/` (not committed).

## Figure comparison

The same six Gallery figures changed in both languages:

- `gallery-earth-tone-offsets.svg`
- `gallery-dashed-strokes.svg`
- `gallery-stroke-offset-tracks.svg`
- `gallery-package-title-first-offset.svg`
- `gallery-package-title-nine-offsets.svg`
- `gallery-package-title-second-offset-arrangement.svg`

All 13 README figures and the other 27 Gallery figures are byte-identical to
baseline in each language. All figure viewBoxes remain unchanged.
The first five changed figures retain their element counts and differ in path
coordinates. The second-offset arrangement also has one fewer SVG path/group.

The Gleam production capture records the intermediate arrangement changing from
907 to 906 vertices and 1,181 to 1,180 graph edges. Counts of eligible offset edges
(783), initially submerged edges (471), initially retained edges (312), and
positive-final-capacity edges (185) are unchanged. This is an observed change
in intermediate subdivision, not by itself a demonstrated correctness failure.
The updated capture summaries are committed with the figures.

## Result

No test or figure-generation failure was observed at 0.1°. Both implementations
show the same set of changed figures. This supports 0.1° as a candidate, but does
not establish it as an optimal constant or prove all possible offset geometries.
Following visual review, retain the constants and regenerated figures for the
Cavalier Contours audit. No public API or caller options changed. The 3.1.4
source tags, asset tags and publication state remain unchanged.
