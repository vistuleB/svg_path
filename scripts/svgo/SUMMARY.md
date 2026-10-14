# SVGO convertPathData audit summary

All 40 pinned SVGO 4.1.0 fixtures reviewed (181 paths). No pending discrepancies in this fixture set. No confirmed bug under our current API contract. No production changes.

See FIRST_BATCH.md for fixtures 01–05 and REMAINING_FIXTURES.md for fixtures 06–40, numerical investigations, limitations and proposed follow-ups.

## Verification

- Complete expected SVG matches on both optimization passes for all 40 upstream fixtures.
- 180 valid paths serialize, parse through our parser and SVGO’s independent parser with matching command interpretation, and remain stable on a second serialization.
- One intentionally invalid input (`...`, 01:15) yields our ParseError and is passed through by SVGO.
- All 29 flattened-transform cases exercise our public transform parser and path transformation, with point-mapping consistency checks.
- Archived hashes and the installed SVGO optimizer/helper source are verified by the runner.
- These are JavaScript audit diagnostics. No new Erlang checks or full regression suite run is claimed.

## Size observations

Across the 180 valid cases, our uncompressed path-data strings total 6369 bytes versus 5277 for SVGO.

Per path: 13 shorter, 49 equal size, 118 longer.

These totals mix syntax choices, structural preservation, approximation, and adapted transform flattening. They are not a representative compression benchmark or a claim of equivalent contracts. Whole-SVG attributes and compressed size are excluded.

## Per-case inventory

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
| convertPathData.06.svg.txt/1 | 10 | 6 | zero-segment-preservation |
| convertPathData.06.svg.txt/2 | 11 | 9 | initial-line-choice |
| convertPathData.06.svg.txt/3 | 11 | 9 | initial-line-choice |
| convertPathData.06.svg.txt/4 | 16 | 15 | mixed-coordinate-selection |
| convertPathData.06.svg.txt/5 | 16 | 15 | mixed-coordinate-selection |
| convertPathData.06.svg.txt/6 | 22 | 21 | mixed-coordinate-selection |
| convertPathData.06.svg.txt/7 | 22 | 21 | mixed-coordinate-selection |
| convertPathData.06.svg.txt/8 | 14 | 9 | collinear-line-merging |
| convertPathData.06.svg.txt/9 | 14 | 9 | collinear-line-merging |
| convertPathData.06.svg.txt/10 | 17 | 9 | collinear-line-merging |
| convertPathData.06.svg.txt/11 | 14 | 9 | collinear-line-merging |
| convertPathData.06.svg.txt/12 | 14 | 9 | collinear-line-merging |
| convertPathData.06.svg.txt/13 | 17 | 9 | collinear-line-merging |
| convertPathData.07.svg.txt/1 | 4 | 4 | initial-move-case-only |
| convertPathData.07.svg.txt/2 | 8 | 4 | zero-segment-preservation |
| convertPathData.07.svg.txt/3 | 8 | 4 | zero-segment-preservation |
| convertPathData.07.svg.txt/4 | 8 | 4 | zero-segment-preservation |
| convertPathData.07.svg.txt/5 | 20 | 4 | zero-segment-preservation |
| convertPathData.07.svg.txt/6 | 12 | 4 | zero-segment-preservation |
| convertPathData.07.svg.txt/7 | 19 | 4 | explicit-svg-arc-normalization |
| convertPathData.08.svg.txt/1 | 26 | 12 | straight-curve-reduction |
| convertPathData.08.svg.txt/2 | 31 | 12 | straight-curve-reduction |
| convertPathData.08.svg.txt/3 | 34 | 26 | straight-curve-reduction |
| convertPathData.08.svg.txt/4 | 34 | 19 | straight-curve-reduction |
| convertPathData.08.svg.txt/5 | 20 | 12 | straight-curve-reduction |
| convertPathData.08.svg.txt/6 | 26 | 12 | straight-curve-reduction |
| convertPathData.08.svg.txt/7 | 28 | 26 | straight-curve-reduction |
| convertPathData.08.svg.txt/8 | 34 | 34 | initial-move-case-only |
| convertPathData.08.svg.txt/9 | 34 | 20 | straight-curve-reduction |
| convertPathData.08.svg.txt/10 | 16 | 16 | straight-curve-reduction |
| convertPathData.08.svg.txt/11 | 24 | 14 | explicit-svg-arc-normalization |
| convertPathData.08.svg.txt/12 | 24 | 14 | explicit-svg-arc-normalization |
| convertPathData.08.svg.txt/13 | 96 | 92 | straight-curve-reduction |
| convertPathData.09.svg.txt/1 | 42 | 42 | initial-move-case-only |
| convertPathData.09.svg.txt/2 | 34 | 34 | initial-move-case-only |
| convertPathData.09.svg.txt/3 | 22 | 22 | initial-move-case-only |
| convertPathData.09.svg.txt/4 | 28 | 28 | initial-move-case-only |
| convertPathData.09.svg.txt/5 | 34 | 34 | initial-move-case-only |
| convertPathData.10.svg.txt/1 | 31 | 29 | initial-line-choice |
| convertPathData.11.svg.txt/1 | 36 | 34 | transform-context-and-initial-line-choice |
| convertPathData.11.svg.txt/2 | 34 | 32 | transform-context-and-initial-line-choice |
| convertPathData.11.svg.txt/3 | 199 | 167 | transformed-rounding-and-shorthand-selection |
| convertPathData.11.svg.txt/4 | 83 | 81 | retained-transform-and-command-selection |
| convertPathData.11.svg.txt/5 | 103 | 103 | retained-transform-and-command-selection |
| convertPathData.11.svg.txt/6 | 201 | 172 | transformed-rounding-and-shorthand-selection |
| convertPathData.11.svg.txt/7 | 202 | 184 | transformed-rounding-and-shorthand-selection |
| convertPathData.11.svg.txt/8 | 182 | 162 | transformed-rounding-and-shorthand-selection |
| convertPathData.11.svg.txt/9 | 201 | 172 | transformed-rounding-and-shorthand-selection |
| convertPathData.11.svg.txt/10 | 201 | 172 | transformed-rounding-and-shorthand-selection |
| convertPathData.11.svg.txt/11 | 34 | 32 | transform-context-and-initial-line-choice |
| convertPathData.11.svg.txt/12 | 34 | 32 | transform-context-and-initial-line-choice |
| convertPathData.11.svg.txt/13 | 34 | 32 | transform-context-and-initial-line-choice |
| convertPathData.11.svg.txt/14 | 34 | 32 | transform-context-and-initial-line-choice |
| convertPathData.11.svg.txt/15 | 83 | 81 | retained-transform-and-command-selection |
| convertPathData.11.svg.txt/16 | 83 | 81 | retained-transform-and-command-selection |
| convertPathData.11.svg.txt/17 | 20 | 22 | transformed-arc-packed-flags |
| convertPathData.11.svg.txt/18 | 39 | 37 | transformed-arc-representation-and-rounding |
| convertPathData.11.svg.txt/19 | 36 | 38 | transformed-arc-representation-and-rounding |
| convertPathData.11.svg.txt/20 | 29 | 31 | transformed-arc-packed-flags |
| convertPathData.11.svg.txt/21 | 71 | 72 | transformed-arc-representation-and-rounding |
| convertPathData.11.svg.txt/22 | 73 | 73 | transformed-arc-representation-and-rounding |
| convertPathData.11.svg.txt/23 | 65 | 57 | transformed-mixed-coordinate-and-initial-line-choice |
| convertPathData.11.svg.txt/24 | 92 | 94 | transformed-arc-representation-and-rounding |
| convertPathData.11.svg.txt/25 | 38 | 39 | equivalent-ellipse-angle-and-packed-flags |
| convertPathData.11.svg.txt/26 | 49 | 21 | straight-curve-reduction |
| convertPathData.12.svg.txt/1 | 15 | 10 | style-dependent-closepath-substitution |
| convertPathData.12.svg.txt/2 | 14 | 11 | style-dependent-closepath-substitution |
| convertPathData.12.svg.txt/3 | 15 | 10 | collinear-line-merging |
| convertPathData.12.svg.txt/4 | 14 | 9 | collinear-line-merging |
| convertPathData.12.svg.txt/5 | 15 | 10 | style-dependent-closepath-substitution |
| convertPathData.12.svg.txt/6 | 14 | 10 | style-dependent-closepath-substitution |
| convertPathData.12.svg.txt/7 | 15 | 10 | collinear-line-merging |
| convertPathData.12.svg.txt/8 | 14 | 9 | collinear-line-merging |
| convertPathData.12.svg.txt/9 | 15 | 11 | initial-line-and-mixed-coordinate-choice |
| convertPathData.12.svg.txt/10 | 14 | 12 | initial-line-and-mixed-coordinate-choice |
| convertPathData.12.svg.txt/11 | 24 | 24 | identical |
| convertPathData.12.svg.txt/12 | 15 | 11 | initial-line-and-mixed-coordinate-choice |
| convertPathData.12.svg.txt/13 | 14 | 11 | initial-line-and-mixed-coordinate-choice |
| convertPathData.12.svg.txt/14 | 29 | 20 | empty-subpath-and-command-selection |
| convertPathData.13.svg.txt/1 | 78 | 65 | empty-segment-and-closepath-preservation |
| convertPathData.14.svg.txt/1 | 28 | 18 | approximate-cubic-to-arc-replacement |
| convertPathData.14.svg.txt/2 | 32 | 22 | approximate-cubic-to-arc-replacement |
| convertPathData.14.svg.txt/3 | 56 | 21 | approximate-cubic-to-arc-replacement |
| convertPathData.14.svg.txt/4 | 45 | 39 | approximate-cubic-to-arc-replacement |
| convertPathData.14.svg.txt/5 | 93 | 35 | approximate-cubic-to-arc-replacement |
| convertPathData.14.svg.txt/6 | 63 | 42 | approximate-cubic-to-arc-replacement |
| convertPathData.14.svg.txt/7 | 115 | 34 | approximate-cubic-to-arc-replacement |
| convertPathData.14.svg.txt/8 | 128 | 65 | approximate-cubic-to-arc-replacement |
| convertPathData.14.svg.txt/9 | 75 | 40 | approximate-cubic-to-arc-replacement |
| convertPathData.15.svg.txt/1 | 110 | 58 | approximate-cubic-to-arc-replacement |
| convertPathData.15.svg.txt/2 | 54 | 52 | mixed-coordinate-selection |
| convertPathData.16.svg.txt/1 | 52 | 21 | coarse-rounding-and-approximate-arc-replacement |
| convertPathData.16.svg.txt/2 | 26 | 21 | coarse-rounding-and-degree-reduction |
| convertPathData.17.svg.txt/1 | 187 | 123 | near-straight-reduction-exponents-and-command-selection |
| convertPathData.18.svg.txt/1 | 68 | 70 | reflected-arcs-and-command-selection |
| convertPathData.19.svg.txt/1 | 26 | 24 | non-scaling-stroke-context-and-initial-line-choice |
| convertPathData.20.svg.txt/1 | 66 | 70 | packed-arc-flags-and-mixed-coordinate-choice |
| convertPathData.21.svg.txt/1 | 35 | 34 | initial-line-and-mixed-coordinate-choice |
| convertPathData.22.svg.txt/1 | 12 | 10 | stroke-dash-context-and-initial-line-choice |
| convertPathData.22.svg.txt/2 | 12 | 10 | stroke-dash-context-and-initial-line-choice |
| convertPathData.22.svg.txt/3 | 13 | 11 | stroke-dash-context-and-initial-line-choice |
| convertPathData.22.svg.txt/4 | 13 | 11 | stroke-dash-context-and-initial-line-choice |
| convertPathData.22.svg.txt/5 | 13 | 11 | stroke-dash-context-and-initial-line-choice |
| convertPathData.22.svg.txt/6 | 13 | 11 | stroke-dash-context-and-initial-line-choice |
| convertPathData.23.svg.txt/1 | 11 | 9 | style-context-and-initial-line-choice |
| convertPathData.23.svg.txt/2 | 12 | 10 | style-context-and-initial-line-choice |
| convertPathData.24.svg.txt/1 | 35 | 35 | transformed-arc-and-initial-line-choice |
| convertPathData.24.svg.txt/2 | 35 | 35 | transformed-arc-and-initial-line-choice |
| convertPathData.25.svg.txt/1 | 42 | 34 | transformed-mixed-coordinate-and-initial-line-choice |
| convertPathData.26.svg.txt/1 | 32 | 31 | explicit-svg-arc-normalization-and-initial-line-choice |
| convertPathData.27.svg.txt/1 | 25 | 23 | style-dependent-closepath-removal |
| convertPathData.27.svg.txt/2 | 26 | 25 | initial-line-and-packed-arc-flags |
| convertPathData.27.svg.txt/3 | 26 | 24 | style-dependent-closepath-removal |
| convertPathData.28.svg.txt/1 | 25 | 17 | style-dependent-closepath-substitution |
| convertPathData.29.svg.txt/1 | 8 | 4 | empty-subpath-preservation |
| convertPathData.29.svg.txt/2 | 31 | 26 | empty-subpath-preservation |
| convertPathData.30.svg.txt/1 | 12 | 7 | collinear-line-merging |
| convertPathData.31.svg.txt/1 | 11 | 4 | rounding-policy-and-zero-segment-removal |
| convertPathData.32.svg.txt/1 | 24 | 6 | approximate-flat-arc-to-line |
| convertPathData.33.svg.txt/1 | 26 | 20 | geometry-aware-arc-radius-rounding |
| convertPathData.34.svg.txt/1 | 24 | 24 | initial-move-case-only |
| convertPathData.34.svg.txt/2 | 20 | 20 | initial-move-case-only |
| convertPathData.35.svg.txt/1 | 18 | 15 | exact-cubic-to-quadratic-reduction |
| convertPathData.36.svg.txt/1 | 42 | 39 | zero-segment-and-separator-preservation |
| convertPathData.37.svg.txt/1 | 8 | 5 | marker-context-and-closepath-substitution |
| convertPathData.37.svg.txt/2 | 4 | 4 | initial-move-case-only |
| convertPathData.38.svg.txt/1 | 7 | 7 | initial-move-case-only |
| convertPathData.39.svg.txt/1 | 13 | 9 | zero-segment-preservation |
| convertPathData.40.svg.txt/1 | 17 | 20 | straight-quadratic-reduction |
