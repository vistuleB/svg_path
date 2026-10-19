# CC01189: disconnected dual placement and narrow local faces

Initial investigation: 2026-10-19, production commit `d3b2eca`.
The repair and subsequent validation are recorded below.

## Direct captured-graph replay

`prepare-dual-replay.py` copies the generated JS build and adds observational
wrappers. `replay-CC01189-dual.mjs` reconstructs the exact 26-vertex, 33-edge
arrangement saved by the offset probe and calls `arrangement.dual` directly.
It fails in about 67 ms, without the ~20s offset construction. Results are in
`CC01189-dual-replay.json`.

The graph has two connected components: 23 vertices/30 edges (eight bounded
local faces) and 3 vertices/3 edges (one bounded local face). Exterior search
succeeds. Placement first certifies walk 0, then stalls on walk 3.

- Exterior attempts: three vertex-proximity rejections, four accepted lines.
- Walk 0 placement: two accepted lines.
- Walk 3 placement: **830 hit-separation rejections**.

This corrects the earlier possible diagnosis: the blocking test is crossing
separation, not vertex proximity. Walk 3 is bounded by arc edge 3 and line edge
2; its width is too small for the conservative crossing uncertainty. The
existing rejection is doing its intended job. Increasing random attempts cannot
make a geometrically inseparable crossing pair into a certified pair.

## Six-edge reduction on both targets

Let P=(0,0), Q=(1e-5,-1e-5). Build these segments with vertex_tolerance and
minimum_length both 1e-12, endpoint_sliver_tolerance=0:

1. Line P → (1,0)
2. Line (1,0) → (0,1)
3. Line (0,1) → P
4. Minor radius-1 circular arc P → Q, rotation 0, positive sweep
5. Line Q → P
6. Optional distant line (3,0) → (3,1)

All arrangements build. Without edge 6, dual succeeds with three faces. Adding
edge 6, which creates no bounded face, makes dual return DualCertificationFailed.
The narrow lens has chord length sqrt(2)*1e-5 and sagitta approximately 2.5e-11;
the dual sweep tolerance has a floor of 1e-9. Controls with Q=(1e-4,-1e-4) and
Q=(1e-3,-1e-3) succeed with or without the distant line.

Evidence:

- `probe-dual-narrow-face.mjs`, `dual-narrow-face-results.json` (JavaScript).
- `probe/src/dual_narrow_face_audit_probe.gleam`,
  `dual-narrow-face-erlang.log` (Erlang).

The two scripts insert the distant line at different list positions and both
reproduce the failure. No full test suite was run: this is diagnostic work with
no library changes.

## Mechanism and contract assessment

`dual_walk_candidates` already exploits the topology of connected graphs:
cyclic orders determine local faces, so only the exterior requires geometric
certification. With more than one component it switches to `dual_find_placements`,
which tries to sweep through **every** local face. This unnecessarily makes a
previously accepted narrow face dependent on the presence of unrelated geometry.

This is a demonstrated robustness/design limitation with a reduced reproducer.
The public API documents DualCertificationFailed on budget exhaustion, so do not
claim an undocumented-success-contract violation. The actionable defect is the
unnecessary face-interior certification requirement in the disconnected case.
The original tighter-tolerance offset remains unresolved until a repair passes
its original replay. Default normalization/collapse semantics are separate.

## Initial recommended repair direction

Generalize the existing connected-component reasoning:

1. Keep local face walks and certified exteriors.
2. Determine which local face of each *other* component contains a connected
   component. Its boundary cannot cross another component under arrangement
   invariants, so this relationship is constant along that component.
3. Combine those component-placement relationships with the known local face
   walks to form global face signatures and merge boundary walks.

A point on an actual component edge can serve as a witness for locating that
component relative to other components; no displaced probe into its narrow
interior is required. Exclude its own edges from that placement query and retain
certification/independent confirmations for other components. Nested components,
exterior bridges and disjoint components must be handled explicitly; do not
assume that all components are disjoint in filled-region terms.

Do not lower the global uncertainty, drop narrow faces, ignore the remote line,
or return a guessed dual when certification fails. The proposed algorithm still
needs implementation/design review and regression validation for disconnected
nesting, reversed orientations, bridges and the original captured graph.

## Component-placement repair — 2026-10-19

The implementation now locates each component using points on its own edges,
against only the other components' edges and vertices. An accepted line's
negative crossings give the local face containing that point in every other
component. Those states are combined with each known local face of the queried
component. Two accepted witnesses must agree; inconsistent claims still fail.
The original crossing/vertex/tangency rejection and uncertainty floor remain.
A crossing whose uncertainty includes the witness is rejected as well.
Neither graph edges nor cyclic orders are modified.

Removed the obsolete pair-of-walk line generator and per-crossing walk-placement
collector. The public error union and options are unchanged. The `dual` docs
now describe component placement and the absence of local interior witnesses.

`svg_path_dual_component_placement_test` adds three portable regressions,
covering the remote bridge, an interior bridge, and a surrounding square.
They check face counts, bridge ownership, annulus boundary grouping, reversed
segment directions, and three lens scales. Existing arrangement tests cover
nested curved components, multiple islands, bridges, and winding propagation.

Direct replay of the original 26-vertex/33-edge graph now succeeds with ten
faces (`CC01189-dual-repaired.json`, ~9.5ms diagnostic, not a benchmark).
The actual CC01189 offset at fitting tolerance 1e-6 now succeeds with an empty
result, agreeing with upstream (`offset-CC01189-repaired-0.000001.json`, ~20s).
The 1e-5 replay still fails **before dual construction**, in cyclic-order
circle intersection (vertex 11, edge 10, radius 1.126974491590287e-9).
See `offset-CC01189-repaired-trace.json`. This is a separate remaining
construction limitation, not a failed placement witness. Default source
normalization/collapse semantics are unchanged by this repair.

### Separately discovered construction limitation

The first portable run passed 817 tests on Erlang, but two new JS tests failed
before reaching `dual`. Reversing both segment directions and list order in
the size-1e-4 triangle/lens produces
`InternalCyclicOrderCircleIntersectionFailed(vertex: 0, edge: 0,
radius: 5.85355592232908e-13)`. The same error reproduces in the pre-repair
copied build (`dual-reverse-build-baseline.json`). The final regression reverses
directions while retaining segment order, which reaches the dual on both
targets. This is not a target-specific test exclusion: all test inputs are
identical on Erlang and JS. The construction limitation remains recorded for
separate investigation, not repaired here. Initial portable output is retained
in `dual-component-first-portable.log`.

`probe/src/dual_reverse_audit_probe.gleam` and
`dual-reverse-order-results.log` inventory direction/order combinations on JS.
The earlier `dual-reverse-build-results.log` used reversed directions *and*
reversed list order; `dual-reverse-stable-order-results.log` kept list order.

### Final regression assertion adjustment

The initial canonical run passed 2,076 ordinary, 31 slow, and 822 portable
Erlang tests. JavaScript passed 820 and failed the two new bridge tests because
they assumed the added line was the *only* graph bridge. At size 1e-4 in the
reversed case, JS retains additional short bridge fragments. Face counts were
correct. The tests now identify the added line by its segment and assert both
of its sides belong to the expected face, rather than asserting there are no
other bridges. All three corrected checks pass in a direct JS run. No production
change was made for this assertion adjustment. The initial complete run is
preserved as `dual-component-initial-release.log`; the final canonical rerun is
`dual-component-test-release.log`.

### Completed validation

Final command:

```sh
PATH=/Users/jpsteinb/.nvm/versions/node/v24.10.0/bin:$PATH scripts/test-release
```

Exit 0: **2,076 ordinary + 31 slow + 822 portable Erlang + 822 portable
JavaScript**, no failures. Log: `dual-component-test-release.log`.
Formatting of the changed library/test modules, `git diff --check`, and
`python3 scripts/cavalier/validate-records.py` also pass.
No F# port, published-figure regeneration, or commit in this repair turn.
