# Boolean decomposition discrepancy review — 2026-10-20

Baseline `6a9f80f`. All 56 previously witness-free Not/Xor flags across 13
upstream families have now received stronger independent scanline checks.
This includes the four stitching cases reviewed separately. No production changes.

## Findings

- **36 representation/decomposition cases:** region checks agree to floating-point
  precision, with contour grouping, orientation, holes or shared seams explaining
  the flagged properties. This is numerical evidence, not exact-predicate proof.
- **8 acute-angle cases:** our output retains thin geometry omitted by the looser
  Cavalier tolerance. These are not just decomposition differences.
- **12 numerical/reconstruction cases:** stitching plus pill cases 2 and 3.
  Differences are real, near boundaries, and consistent with the previously
  documented endpoint-reconstruction limitation. No new contract violation has
  been established; do not relabel them as exact parity.

| Upstream family | Cases | Maximum net-area difference | Maximum sampled clearance | Disposition |
| --- | ---: | ---: | ---: | --- |
| `rectangle_over_half_of_circle` | 4 | 9.09e-13 | 0 | Decomposition/orientation |
| `rectangle_slicing_circle` | 4 | 5.68e-14 | 1.78e-15 | Decomposition/orientation |
| `debug_assert_stitching_slices_reported` | 4 | 4.89e-07 | 2.34e-07 | Numerical/reconstruction differences retained |
| `mostly_overlapping_case2` | 4 | 9.09e-12 | 2.84e-14 | Decomposition/orientation |
| `opposite_direction_arc_arc_endpoints_intersect_bug_reported` | 4 | 7.28e-11 | 1.15e-11 | Decomposition/orientation |
| `overlapping_pill_shaped_ends_reported` | 4 | 3.91e-14 | 0 | Decomposition/orientation |
| `overlapping_pill_shaped_ends_reported2` | 4 | 1.68e-07 | 6.61e-08 | Numerical/reconstruction differences retained |
| `overlapping_pill_shaped_ends_reported3` | 4 | 1.46e-06 | 2.58e-07 | Numerical/reconstruction differences retained |
| `overlapping_pill_shaped_ends_reported4` | 4 | 7.74e-13 | 1.33e-14 | Decomposition/orientation |
| `overlapping_pill_shaped_ends_reported7` | 4 | 2.17e-13 | 9.76e-13 | Decomposition/orientation |
| `parametric_from_point_debug_assert_reported1` | 4 | 1.24e-14 | 1.25e-15 | Decomposition/orientation |
| `pill_shapes_overlapping_at_ends_90_deg` | 4 | 1.78e-15 | 0 | Decomposition/orientation |
| `pill_shapes_overlapping_at_ends_at_acute_angle` | 8 | 6.33e-06 | 9.16e-16 | Tolerance-dependent thin geometry |

The JSON summary records every case ID and additional perimeter/count metrics.
Clearance means minimum distance from a sampled difference midpoint to any input
or output boundary. It is not a global displacement bound or proof that all
differences lie within tolerance. The independent oracle uses input bulges and
analytic line/circle formulas, not our containment or intersection routines.

## Mostly overlapping case 2

CC00742/46/50/54 produce an outer contour of signed area 10218.742012420476
and a hole of area -884.615153413566. Cavalier describes two positive contours
with absolute areas 3403.3777038046774 and 5930.7491552022275. Net filled area
agrees within 9.1e-12; total boundary length agrees. Independent horizontal
cross-sections differ by at most 1.03e-12. Comparing individual contour bounds
and areas was therefore the wrong equivalence criterion.

## Opposite-direction arc endpoint family: shared upstream seams

CC00761/65/69/73 initially retained an unexplained perimeter difference despite
matching filled regions. Full curves were recaptured from the pinned upstream
test in an isolated instrumented Rust checkout. Cavalier outputs two positive
contours with four exactly matching geometric boundary segments. Those segments
have total length 99.70520406381223. Cavalier counts them in both perimeters.
Subtracting twice that length explains the upstream perimeter excess of about
199.4104081276, leaving at most 1.27e-11 residual. Our output uses an outer contour
and two holes without that doubled seam. This is a representation distinction.

`boolean-endpoints-upstream-geometry.json` stores the four captured presentations;
`check-upstream-shared-boundaries.py` verifies the shared curves and perimeter
accounting, saving `boolean-endpoints-shared-boundaries.json`. It compares whole
segments exactly (or reversed); no proximity-based seam guess is used.

## Acute-angle pill geometry

For CC01102 and its related difference/XOR presentations, one input end circle
has center (4,4), radius 1. The other has center (4,4), radius
0.9999975776470663, a radial difference of 2.4223529337e-6. Cavalier uses
`pos_equal_eps = 1e-5`; our default build tolerance is 1e-6. Our result retains
part of that thin crescent and reaches y=3; the upstream difference result starts
at y=4. Thus the large perimeter/bounds differences do not imply a large filled
region error. Net area differs by at most 6.34e-6, and independent comparison
against the actual input geometry finds cross-section differences below 8.1e-13.
The retained arcs are not an exact retrace. No suppression policy is added.

## Remaining numerical differences

The 12 cases in the numerical category must remain explicitly nonidentical.
Maximum sampled clearances are 2.34e-7 (stitching), 6.61e-8 (pill case 2), and
2.59e-7 (pill case 3), versus default construction tolerance 1e-6. Horizontal
differences can be much larger near tangencies and are not normal distances.
The earlier reconstruction audit matched final segments to stored arrangement
edges and verified endpoint adjustments within tolerance for these cases.
See `BOOLEAN-CONTRACT-TRIAGE.md` and `BOOLEAN-STITCHING-GEOMETRY-TRIAGE.md`.
These comparisons add no proof of every preceding arrangement decision; broader
Boolean earlier-stage questions remain separate from the decomposition flags.

## Validation and reproducibility

- 56 public Boolean calls completed; no errors or timeouts.
- 2,487 independent scanlines checked; 1,476 sample positions skipped because
  their event strips were narrower than 1e-11. Coincident-circle and floating
  arithmetic limitations remain as documented in the stitching report.
- The operation table now handles difference as well as XOR; the reference truth
  table is selected per case. The previous XOR-only controls remain available.
- The pinned upstream endpoint fixture passed: 1 test, 0 failures.
- No full native suite or figures rerun: production source and tests are unchanged.
- No F# work, no new public API, no commit in this batch.

```sh
NODE=/path/to/node python3 scripts/cavalier/run-boolean-decomposition.py
python3 scripts/cavalier/summarize-boolean-decomposition.py
python3 scripts/cavalier/check-upstream-shared-boundaries.py
python3 scripts/cavalier/validate-records.py
```

Upstream capture: `python3 scripts/cavalier/prepare-decomposition-capture.py`,
then the isolated Rust 1.95.0 command from `README.md`, selecting
`--test test_pline_boolean opposite_direction_arc_arc_endpoints_intersect_bug_reported`
and passing `-- --nocapture --test-threads=1`. The instrumentation adds full
polyline geometry to properties; the pinned source archive is unchanged.
The isolated toolchain/dependencies were restored because the previous /tmp
installation was no longer present. Captures were matched to original inputs,
second operands and operation, not selected by output properties.
