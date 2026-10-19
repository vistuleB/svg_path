# Remaining offset detail discrepancies — 2026-10-19

Investigation after `d3b2eca`; no production changes.

## CC01160 and CC01292: existing detail control explains comparisons

`probe-offset-detail.mjs` converts captured paths preserving open/closed state
and sweeps fitting.tolerance, retaining normalized sources and output segments.

CC01160 at default 0.01 returns area 12.882708949581552 and length
18.23028089781032. At 0.0001 it returns area 12.688565508722672 and length
17.447959331395, agreeing with upstream 12.688565508722656 / 17.44795933139501.

CC01292 at default returns length 25.816256262803876; at 0.0001 it returns
26.598674298301184 versus upstream 26.598669794674937. Bounds agree within
3.79e-6 (`offset-CC01292-tight-bounds.json`). This input is open: Cavalier's zero
area convention is not native signed open-path integration. The comparison
already handles that convention. Do not interpret the diagnostic nonzero native
signed integral as a new error.

These are understood detail/normalization differences under existing options,
not new confirmed geometry bugs. Results are the four `offset-CC01160-*` and
`offset-CC01292-*` files plus the tight bounds replay. No universal geometric
error bound or exact output equivalence is inferred from aggregate checks.

## CC01189: collapse policy and a distinct tighter-tolerance failure

This is the three-arc small-loop intermediate from upstream
`separate_behavior_splits_tangent_touching_small_loop`, offset again by 0.1.
Cavalier expects deletion. Native defaults normalize this narrow loop to a line
and its exact reverse, then produce a nonempty normal-extrusion offset.
Tolerances 0.01, 0.001 and 0.0001 produce the same normalized source and output.
This relates to the already-open collapse/erosion policy question; do not label
it an unexplained missing intersection, or assume native offset guarantees
filled-region erosion.

At 1e-5 and 1e-6 the source retains two arcs and the intervening line. Both calls
fail. The initial serial sweep completed in about 36s and 19s for these two
settings (`offset-CC01189-detail.json`; empty error objects there are a serializer
limitation, not successful results). An interrupted-wait request arrived after
that process had already finished; its five results are complete. Later probes
record error names explicitly.

At 1e-6 the trace establishes:

- Public offset error: ConstructionFailed.
- Internal arrangement error: InternalDualSweepExhausted(unresolved: 5).
- Dual exterior search succeeds; placement search exhausts its budget.
- 833 rejected and six accepted sweep-intersection attempts.
- Captured arrangement: 26 vertices, 33 edges.
- Sweep tolerance: 3.784316901211825e-9.
- Several edge chords lie between 2.00e-9 and 3.04e-9, below that tolerance.

Evidence: `offset-CC01189-tight.json`, `offset-CC01189-tight-trace.json`, and
`offset-CC01189-dual-result.json` / `offset-CC01189-dual-trace.json`.
`prepare-offset-dual-trace.py` instruments a copied build, preserving values.
The 833 failed `dual_find_placements` wrapper returns are recursive unwinding,
not 833 independent placement runs. Rejected sweeps return Error(Nil), so the
specific rejection predicate has not yet been isolated.

The small-edge/tolerance relationship is a lead, not a proven diagnosis.
Do not dismiss the tighter failure as an understood policy difference. Next:
replay the captured graph directly, identify the sweep rejection predicate and
reduce the graph/geometry before deciding on a repair. It remains an open
numerical robustness investigation; no fix is proposed or adopted here.

## Validation

Native JS targeted replays and observational copied-build traces only. No
Erlang/full-suite claim, new regression test, figures or F# change. Record
validation and whitespace checks pass. New findings remain uncommitted.

## Repair follow-up

The component-placement repair now accepts the captured graph and the original
1e-6 offset returns empty. The 1e-5 failure was separately traced to cyclic-order
circle intersection before dual construction; it remains open. See
`DUAL-NARROW-FACE-TRIAGE.md` for regression coverage and validation.
