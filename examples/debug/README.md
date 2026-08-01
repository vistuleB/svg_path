# Debug Drawings

Generated SVG debug drawings live here.

- `tmp_tests/`: parked R&D drawing fixtures. These used to live under `test/`,
  but are intentionally outside normal `gleam test` discovery.
- `arrangement_csg_figures.gleam`: parked generator for ArrangementGraph and
  CSG diagnostic sheets.
- `offset_sv_probe.gleam` and `package_title_figure.gleam`: parked package-title
  offset probes. They live outside `src` so their Erlang file I/O is not part
  of the published package.
- `debug_drawing.*`: leaf/stem renderer smoke test
- `convex_hull_stem.*`: convex hull overlay for the first cubic stem segment
- `convex_hull_horseshoe.*`: convex hull overlay for the horseshoe cubic segment
- `convex_hull_horseshoe_wide.*`: convex hull overlay for a wider horseshoe cubic segment
- `convex_hull_diagonal_line.*`: convex hull overlay for a diagonal line segment
- `convex_hull_reverse_diagonal_line.*`: convex hull overlay for an opposite-slope diagonal line segment
- `convex_hull_horizontal_line.*`: convex hull overlay for a horizontal line segment
- `convex_hull_vertical_line.*`: convex hull overlay for a vertical line segment
- `convex_hull_snake_cubic.*`: convex hull overlay for a crossing snake-shaped cubic
- `convex_hull_fish_cubic.*`: convex hull overlay for a crossing fish-shaped cubic
- `convex_hull_del_cubic.*`: convex hull overlay for the del cubic
- `convex_hull_flourish_cubic.*`: convex hull overlay for the flourish cubic
- `convex_hull_left_hook_cubic.*`: convex hull overlay for the left-hook cubic
- `convex_hull_half_circle_arc_reverse.*`: convex hull overlay for a reverse-sweep half-circle arc
- `convex_hull_rotated_arc_reverse.*`: convex hull overlay for a reverse-sweep rotated arc

`svg_path_convex_hull_debug.gleam` is the parked scratch harness that generated
the convex hull segment drawings. It is intentionally outside `src` so it is not
compiled as part of the package. It was originally run from `src`, where it
could talk to development-only helper functions while the hull algorithm was
being shaped.

## Convex Hull Numeric Tuning Notes

These notes record the temporary state of the segment hull prototype before the
test suite was made green. They are here to preserve debugging context, not to
document public behavior.

Earlier constants and checks:

- `t_tolerance` was `0.05` before being raised to `0.1`.
- The support-value test used a fixed absolute tolerance of `0.000001`.
- The direct adversarial support check then failed on normal-to-large arcs:
  - `rotated_large_arc_reverse`: support mismatch, for example around
    `1.8e-6`.
  - `generated_arc_3`: support mismatch, around `2.8e-6` to `3.5e-5`
    depending on angle.
  - `generated_arc_11`: support mismatch, around `2.7e-6` to `1.3e-5`.
  - `generated_arc_22`: support mismatch, around `2.2e-5` to `5.9e-5`.
  - Reverse witnesses for generated arcs showed the same kind of drift.

The largest inspected witness was `generated_arc_22`. Its hull pieces were just
`HullCurve(0.0, 1.0)` and `HullLine(1.0, 0.0)`, so the support mismatch was not
caused by missing hull topology. It came from evaluating support on a rebuilt
whole-arc piece rather than on the original arc data. The observed scale was:

- bounding-box diameter: about `5490.665954523197`
- largest support mismatch seen in the test loop: about `5.9e-5`
- relative error: about `1e-8` of the diameter

The concrete support-mismatch arc witnesses were:

```gleam
// rotated_large_arc_reverse is segment_reverse(rotated_large_arc(sweep: False)).
svg_path.Arc(
  start: svg_path.Point(-70.0, 20.0),
  radius: svg_path.Point(95.0, 20.0),
  x_axis_rotation: 73.0,
  large_arc: True,
  sweep: False,
  end: svg_path.Point(80.0, -10.0),
)

// generated_arc_3, plus its reverse.
svg_path.Arc(
  start: svg_path.Point(326.80026387727264, -260.8390009191016),
  radius: svg_path.Point(87.76984319319511, 11.87045278497363),
  x_axis_rotation: 335.205286439588,
  large_arc: True,
  sweep: False,
  end: svg_path.Point(280.93017594732527, 376.3922587940047),
)

// generated_arc_11, plus its reverse.
svg_path.Arc(
  start: svg_path.Point(107.85705720801101, -338.8495268430821),
  radius: svg_path.Point(244.9772635063338, 33.57924520474891),
  x_axis_rotation: 310.005043260612,
  large_arc: False,
  sweep: False,
  end: svg_path.Point(303.8439162943818, -238.8757730743505),
)

// generated_arc_22, plus its reverse.
svg_path.Arc(
  start: svg_path.Point(-1999.999905884838, -1618.5387408292152),
  radius: svg_path.Point(617.7500734194787, 1618.0958002375917),
  x_axis_rotation: 40.48148243217115,
  large_arc: False,
  sweep: True,
  end: svg_path.Point(640.2509972532353, -1636.37341664681),
)
```

Other experiments:

- Capping the hull point-distance tolerance with `min(diameter, 1.0)` made the
  algorithm much less stable. It introduced many new cubic failures such as
  `ConsecutiveCurves` and `RefinementReachedMaxIterations`.
- Raising `initial_sample_number` from `100` to `360` did not reduce the arc
  support errors. It reintroduced `ConsecutiveCurves` for
  `near_endpoint_arc` / `near_endpoint_arc_reverse` and made the transformed
  adversarial test time out inside repeated arc minimization.
- Returning the original segment for `segment_between(segment, 0.0, 1.0)` preserved
  whole-arc support better, but broke strict subpath continuity because arc
  endpoint evaluation can differ from declared endpoints by tiny floating-point
  dust.

The current green test setup keeps ordinary geometric comparisons at
`0.000001`, but uses a diameter-aware support tolerance:

- `max(0.000001, diameter * 0.00000002)`

The transformed adversarial test also documents four known failures rather than
pretending they are solved:

- `endpoint_control_cubic_translated`: `RefinementReachedMaxIterations(0)`
- `endpoint_control_cubic_rotated`: `ConsecutiveCurves`
- `near_cusp_cubic_translated`: `RefinementReachedMaxIterations(0)`
- `near_cusp_cubic_scaled`: `ConsecutiveCurves`

Those transformed failures come from these base cubics:

```gleam
// endpoint_control_cubic
svg_path.CubicBezier(
  start: svg_path.Point(0.0, 0.0),
  control1: svg_path.Point(0.0, 0.0),
  control2: svg_path.Point(100.0, 0.0),
  end: svg_path.Point(100.0, 0.0),
)

// near_cusp_cubic
svg_path.CubicBezier(
  start: svg_path.Point(0.0, 0.0),
  control1: svg_path.Point(100.0, 0.0),
  control2: svg_path.Point(-100.0, 0.0),
  end: svg_path.Point(0.001, 0.0),
)
```

The transforms are the standard adversarial variants from the test:

```gleam
transform.translate(x: 37.0, y: -19.0)
transform.rotate(degrees: 37.0)
transform.scale(factor: 1.7)
```
