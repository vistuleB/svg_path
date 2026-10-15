# Full validation of centered normalization with original endpoints and certification

2026-10-15. Baseline `269a535`. Source variant:
`../checks/certification-experiment.patch`.

All four full test profiles completed with repository expectations unchanged.

| Command | Passed | Failed | Wall seconds |
| --- | ---: | ---: | ---: |
| `scripts/test-fast` | 2008 | 4 | 40.69 |
| `scripts/test-slow` | 31 | 0 | 59.36 |
| `scripts/test-portable erlang all` | 755 | 3 | 47.6 |
| `scripts/test-portable javascript all` | 755 | 3 | 66.4 |

Four distinct failing functions remain: the shared-endpoint (4 -> 2), off-center
quadratic (4 -> 1), and flat cubic (9 -> 6) count snapshots, plus
`conditioned_search_preserves_original_candidates_test`, which specifically
requires supplementation. The geometry module is not in the portable registry,
so both portable profiles report three failures. No other assertions failed.
Both certification-error tests now pass in all applicable full profiles.
Earlier targeted continuation checks in `../checks/` exercised assertions after
the snapshot failures on both targets. This run does not constitute an unchanged
full-suite pass, and no snapshot expectations were adopted.

## Figure generation

Completed `bash /tmp/svg-path-centered-final/generate-figures`, exit 0, 50.09 s.
This is a temporary copy of `scripts/generate-published-figures`, with the root
path fixed and its initial `scripts/test-fast` call replaced by `gleam build`.
The full fast test already ran separately; its four known failures would otherwise
prevent regeneration. Every subsequent canonical generation, verification and
promotion command ran unchanged. The temporary script is saved here as
`generate-figures.sh` for exact command review.

All **13 README and 33 Gallery SVGs** regenerated successfully. Baselines were
captured before this run. `figures.json` records SHA-256 hashes for all 46 outputs.

- All 13 README figures are byte-identical.
- 32 of 33 Gallery figures are byte-identical.
- `gallery-package-title-second-offset-arrangement.svg` differs only in 86
  numeric text/circle position attributes across 58 elements, with maximum
  coordinate change **1.5544543430223712e-10** SVG units.
- Both versions contain 8,638 XML elements in the same order. No element/tag,
  text-content, path-data, or other nonnumeric attribute differences were found.
  `svg-diff.json` records the comparison. This is structural/numeric comparison,
  not a pixel-diff claim.

The changed experimental figure is preserved under `changed-figures/gallery/`
and previewed from `examples/debug/centered_normalization_second_offset_arrangement.svg`.
Logs and process exit statuses are saved alongside this report. Timings are
observations, not controlled benchmarks.

After validation, production source and changed published/generated figure
files were restored to their pre-experiment bytes. No test expectations changed,
no F# files changed, and no commit was made. The normalization remains a saved
experiment pending adoption.
