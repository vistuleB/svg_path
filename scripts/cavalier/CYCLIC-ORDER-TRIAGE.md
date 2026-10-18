# Cyclic-order sampling failure — 2026-10-18

Source `090f8e63` (catalogue checkpoint `fac4ede` makes no production changes).
Confirmed native sampling defect. The initial investigation below describes the
pre-fix behavior; see the repair experiment at the end for current results.

## Minimal native reproduction

Two perpendicular lines sharing the exact origin:

- `(0,0)` to `(1,0)`;
- `(0,0)` to `(0,0.000003)`.

Call `arrangement.build_with` with vertex tolerance 1e-6, minimum length 1e-8,
and endpoint sliver tolerance zero. It returns
`InternalCyclicOrderCircleIntersectionFailed(vertex: 0, edge: 0, radius: 1.536e-6)`.
Both segments exceed the minimum length. Their nonshared endpoints are distinct
under clustering. No SVG arcs, bulge conversion, overlapping segments, closed
path requirement, or Boolean fill rule is needed for the failure.

Increasing only the short edge length to 3.1e-6 makes the build succeed.
The failed pair and successful control reproduce on both Erlang and JavaScript.

Candidate desired-behavior regressions are in
`regressions/cyclic_order_short_edge_test.gleam`. They are not wired into the
ordinary suite: the first currently fails. The standalone native probe executes
the same public API call and records its current result on both targets.

## Mechanism

The first common probe-circle radius is 0.8 times the shortest opposite-endpoint
distance: here r=2.4e-6. The vertex-local long edge is simply p(t)=(t,0).
The circle residual is f(t)=t*t-r*r; the exact positive crossing is t=r.

The cyclic-order sampler supplies scalar residual tolerance
`vertex_tolerance * (2*r + vertex_tolerance) = 5.8e-12` to the general crossing
helper. But `f(0) = -5.76e-12` is already within this tolerance.

`svg_path.refine_crossing` therefore accepts the left endpoint t=0 without
refining the real crossing. The query returns only `[0]`. Then
`arrangement.circle_sample_for_oriented_edge` requires `t > 0` and rejects it.
The remaining smaller radii retain the same problem; no successful sample is
available and the arrangement build fails.

This is not a missing mathematical edge/circle intersection or an exhausted
iteration budget. It is a mismatch between the scalar root tolerance chosen by
the circle sampler and its requirement for a positive, useful circle sample.
The general crossing helper follows its supplied residual tolerance.

For an edge starting exactly at the vertex, origin acceptance occurs whenever
`r*r <= tolerance*(2*r+tolerance)`, i.e. `r <= (1+sqrt(2))*tolerance`.
Thus even radii greater than the vertex tolerance can falsely accept the origin.
A squared-residual band built from the outward radial tolerance is not an
identical inward radial-distance band near the origin.

## Connection to the original Cavalier fixture

`CC01059`, minimum length 1e-8, retains enough short pieces to reach cyclic-order
construction. An observational wrapper in a **copied generated build under
/tmp/cavalier-cyclic-trace** records the failed samples. It neither changes the
production source/build nor alters return values.

At vertex 1, the first radius is 2.442585918124453e-6. The local incident arc
starts about 8.958472612619062e-7 from the vertex center. Its start residual is
-5.16368365189932e-12, within residual tolerance 5.885171836248905e-12.
The crossing query returns `[0]`. The two following radii also return `[0]`;
the final error names radius 1.5632549875996502e-6. Another incident arc has the
same issue. `cyclic-original-trace.json` preserves all six failed samples.

The nonzero starting offset explains why the original fixture can fail even
when its first radius is slightly above `(1+sqrt(2))*tolerance`. Clustering
allows stored edge endpoints to differ from the vertex center.

## Evidence and reproduction

- `probe-cyclic-minimal.mjs`, `cyclic-minimal.json`: six short-edge lengths,
  residuals, returned roots and build outcomes.
- `probe/src/cyclic_order_audit_probe.gleam`: native reduced case and control.
- `cyclic-minimal-erlang.log`, `cyclic-minimal-javascript.log`: both target results.
- `prepare-cyclic-trace.py`, `probe-cyclic-original.mjs`,
  `cyclic-original-trace.json`: copied-build tracing of the original fixture.

```sh
node scripts/cavalier/probe-cyclic-minimal.mjs > scripts/cavalier/cyclic-minimal.json
(cd scripts/cavalier/probe && gleam run -m cyclic_order_audit_probe)
(cd scripts/cavalier/probe && gleam run --target javascript -m cyclic_order_audit_probe)
python3 scripts/cavalier/prepare-cyclic-trace.py
node scripts/cavalier/probe-cyclic-original.mjs > scripts/cavalier/cyclic-original-trace.json
```

For the JavaScript Gleam runner, Node must be on the child process PATH. This
machine's successful invocation explicitly prepended
`/Users/jpsteinb/.nvm/versions/node/v24.10.0/bin`. An initial runner invocation
could not find Node; after setting PATH it ran successfully.

## Repair direction to consider later

Keep the change local to common-circle sampling. Its numerical solve tolerance
must be stricter than the angular grouping/vertex clustering tolerance and must
not accept the starting point in place of a positive circle crossing. Retain
geometric checks of the chosen sample. Do not change general crossing semantics,
accept t=0 as a direction, silently discard the short edge, or merely increase
iteration counts. A radius-relative residual bound or a bracketed radial-distance
solve are candidates, not tested fixes.

Any fix should cover centered and offset-within-cluster edge starts, both line
and arc edges, reversed traversal, scale changes, and the original fixture. Also
retain deliberate errors where no incident-edge circle sample exists. Full
arrangement/CSG validation is needed before adopting a repair. The other audit
classification work remains unfinished.

## Repair experiment — 2026-10-18

`arrangement.circle_sample_for_oriented_edge` now caps the scalar solve tolerance
at one quarter of `radius² - start_distance²` when the stored edge starts strictly
inside the probe circle. This prevents the inside starting point from satisfying
the residual test, while retaining the existing upper bound on residual error.
Outside/on-circle starts retain existing behavior; this change does not invent a
direction when no positive crossing is found. General crossing semantics,
clustering tolerance, angular grouping and edge geometry are unchanged.

Permanent regressions are now in `test/svg_path_cyclic_order_short_edge_test.gleam`
and selected for portable tests: minimal failure, nearby control, scaled/reversed
lines, and offset clustered arc endpoints in both orientations. All four targeted
Erlang tests pass, with explicit cyclic-order assertions in the latter two.
The earlier candidate file under `regressions/` is historical evidence.

`probe-cyclic-repaired.mjs` replays the original geometry and all 16 affected
orientation/operation records using the ordinary audit probe JavaScript build.
`cyclic-repaired-original.json`: all 16 arrangements now build at minimum length
1e-8. This does not assert CSG equivalence or change the separate default boundary
guard classification. No F# port or commit has been made.

Validation of the repair:

- `scripts/test-fast`: 2,053 passed.
- `PATH=/Users/jpsteinb/.nvm/versions/node/v24.10.0/bin:$PATH scripts/test-portable all all`:
  797 passed on Erlang and 797 on JavaScript. This run selected the first two new
  tests before the scale/offset-arc cases were added.
- Targeted EUnit run of `svg_path_cyclic_order_short_edge_test`: all four passed.
- Rebuilt portable JS module, then invoked its four exported test functions with
  Node: all four passed, including the two added after the portable run started.
- `python3 scripts/cavalier/validate-records.py`: passed.
- `scripts/test-slow`: 31 passed.
