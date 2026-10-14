# First batch: convertPathData.01–05

52 cases: 51 valid paths and one malformed input. Both upstream optimization passes match each complete expected SVG.

Path data bytes only: ours 1044, SVGO 1009. Per path: 32 equal size, 4 shorter, 15 longer. These fixtures are not a representative size benchmark.

All 51 of our outputs parse and serialize stably on a second pass. Parameter-matched sampling at 17 points per segment (plus subpath starts) finds only expected rounding differences and floating-point noise. Sampling is not a proof or an error bound. SVGO changes segment/subpath counts in three cases, reported as null in the JSON diagnostic.

| Fixture/path | Our bytes | SVGO bytes | Disposition |
| --- | ---: | ---: | --- |
| convertPathData.01.svg.txt/1 | 6 | 6 | initial-move-case-only |
| convertPathData.01.svg.txt/2 | 6 | 6 | initial-move-case-only |
| convertPathData.01.svg.txt/3 | 6 | 6 | initial-move-case-only |
| convertPathData.01.svg.txt/4 | 6 | 6 | initial-move-case-only |
| convertPathData.01.svg.txt/5 | 5 | 5 | initial-move-case-only |
| convertPathData.01.svg.txt/6 | 17 | 12 | mixed-coordinate-selection |
| convertPathData.01.svg.txt/7 | 11 | 11 | identical |
| convertPathData.01.svg.txt/8 | 6 | 6 | initial-move-case-only |
| convertPathData.01.svg.txt/9 | 7 | 7 | initial-move-case-only |
| convertPathData.01.svg.txt/10 | 7 | 7 | initial-move-case-only |
| convertPathData.01.svg.txt/11 | 7 | 7 | initial-move-case-only |
| convertPathData.01.svg.txt/12 | 7 | 7 | initial-move-case-only |
| convertPathData.01.svg.txt/13 | 7 | 7 | initial-move-case-only |
| convertPathData.01.svg.txt/14 | 7 | 7 | initial-move-case-only |
| convertPathData.01.svg.txt/15 | — | — | invalid-input-pass-through |
| convertPathData.02.svg.txt/1 | 12 | 12 | identical |
| convertPathData.02.svg.txt/2 | 23 | 23 | initial-move-case-only |
| convertPathData.02.svg.txt/3 | 36 | 35 | mixed-coordinate-selection |
| convertPathData.02.svg.txt/4 | 18 | 18 | initial-move-case-only |
| convertPathData.02.svg.txt/5 | 23 | 23 | initial-move-case-only |
| convertPathData.02.svg.txt/6 | 23 | 25 | packed-arc-flags |
| convertPathData.03.svg.txt/1 | 12 | 6 | empty-subpath-preservation |
| convertPathData.03.svg.txt/2 | 12 | 12 | identical |
| convertPathData.03.svg.txt/3 | 18 | 18 | identical |
| convertPathData.03.svg.txt/4 | 18 | 18 | identical |
| convertPathData.03.svg.txt/5 | 41 | 41 | initial-move-case-only |
| convertPathData.03.svg.txt/6 | 41 | 41 | initial-move-case-only |
| convertPathData.03.svg.txt/7 | 48 | 47 | mixed-coordinate-selection |
| convertPathData.03.svg.txt/8 | 48 | 47 | mixed-coordinate-selection |
| convertPathData.03.svg.txt/9 | 29 | 29 | initial-move-case-only |
| convertPathData.03.svg.txt/10 | 29 | 29 | initial-move-case-only |
| convertPathData.03.svg.txt/11 | 29 | 29 | initial-move-case-only |
| convertPathData.03.svg.txt/12 | 29 | 29 | initial-move-case-only |
| convertPathData.03.svg.txt/13 | 39 | 43 | packed-arc-flags |
| convertPathData.03.svg.txt/14 | 39 | 43 | packed-arc-flags |
| convertPathData.03.svg.txt/15 | 10 | 8 | initial-line-choice-marker-preserved |
| convertPathData.03.svg.txt/16 | 10 | 8 | initial-line-choice-marker-preserved |
| convertPathData.03.svg.txt/17 | 8 | 6 | initial-line-choice-round-cap-preserved |
| convertPathData.03.svg.txt/18 | 8 | 6 | initial-line-choice-round-cap-preserved |
| convertPathData.03.svg.txt/19 | 8 | 4 | style-dependent-zero-line-removal |
| convertPathData.03.svg.txt/20 | 8 | 4 | style-dependent-zero-line-removal |
| convertPathData.04.svg.txt/1 | 18 | 18 | identical |
| convertPathData.04.svg.txt/2 | 42 | 42 | initial-move-case-only |
| convertPathData.04.svg.txt/3 | 45 | 42 | mixed-coordinate-selection |
| convertPathData.04.svg.txt/4 | 30 | 30 | initial-move-case-only |
| convertPathData.04.svg.txt/5 | 32 | 30 | mixed-coordinate-selection |
| convertPathData.04.svg.txt/6 | 41 | 44 | packed-arc-flags |
| convertPathData.04.svg.txt/7 | 20 | 8 | straight-cubic-reduction-and-initial-line-choice |
| convertPathData.05.svg.txt/1 | 21 | 21 | equal-size-coordinate-choice |
| convertPathData.05.svg.txt/2 | 14 | 14 | identical |
| convertPathData.05.svg.txt/3 | 25 | 24 | mixed-coordinate-selection-rounding-compensated |
| convertPathData.05.svg.txt/4 | 32 | 32 | identical |

## Interpretation

- `identical`, `initial-move-case-only`, and `equal-size-coordinate-choice`: no practical minification gap.
- `mixed-coordinate-selection`: optimization opportunity, not a violation of our relative serialization contract. The rounding-compensated variant already corrects accumulated decimal error; its one-byte difference is command selection.
- `packed-arc-flags`: our SVG arc flag separators are more compact. Our parser accepts them; this audit does not constitute browser rendering verification.
- `initial-line-choice-*`: the minifying preset suppresses the first line command, which can cost bytes compared with H/V. Intermediate marker vertices and round-cap zero-length lines are preserved by both outputs. A shortest-command chooser could improve this without changing geometry.
- `empty-subpath-preservation`: SVGO removes an empty subpath; our serializer preserves the path structure. An explicit simplification policy would be needed.
- `style-dependent-zero-line-removal`: SVGO knows the SVG stroke/cap context. Our serializer receives only a path. Removing these lines unconditionally would damage other use cases.
- `straight-cubic-reduction-and-initial-line-choice`: SVGO reduces a straight cubic to a line. This particular cubic has uniform control spacing, but a general reduction must consider backtracking and parameterization. This belongs to an explicit geometry simplification operation, not an automatic serializer assumption.
- `invalid-input-pass-through`: SVGO leaves `...` untouched; our parser returns `ParseError`. Different API contract, not a bug.

No confirmed library bug in this batch. Complete input, expected output, our output, byte counts and sampled differences are in `first-batch.json`. Original SVG context remains in `upstream/test/plugins/` and `fixtures.json`.
