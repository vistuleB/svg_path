# Open endpoint clipping: stale parity request

Investigation after repair commit `f2ccd80`, 2026-10-19. No production changes.

## Replay

`endpoint-clip-cases.json` selects the original non-tangent open-endpoint fixture
and its orientation variants. Running `compare-captured.mjs` with this selection
and the current portable JavaScript build still produces eight offset errors;
three other records are upstream helper observations. Results are in
`endpoint-clip-current.jsonl`.

Representative CC01558 is the open four-line path
(0,0) → (10,0) → (10,10) → (0,10) → (0,1), offset inward by 1.
Untrimmed, NoTrimming and CuspTrimming calls succeed. InBandTrimming fails with
`InternalForcedParityPruningError(ForcedParityAmbiguous([9]))`.
See `probe-endpoint-clip.mjs` and `endpoint-clip-trace.json`.

## Localized mechanism

An observational wrapper around `forced_parity_reduce` in a copied generated JS
build captures the graph and requests in `endpoint-clip-parity.log`.
The graph passed to parity pruning contains exactly four capacity-one lines:

- (1,1) → (9,1)
- (9,1) → (9,9)
- (9,9) → (1,9)
- (1,9) → (1,1)

Winding pruning has already produced a complete square, length 32, with the
expected bounds. Every active vertex has even degree. However, protected original
open endpoints still request odd parity at vertex 0, (0,1), and vertex 9, (1,1).
Vertex 0 is now isolated and its preferred request is correctly ignored. Vertex 9
is attached to two retained edges, so its preferred odd request is enforced and
reported ambiguous. There is no numerical gap or failed arrangement here.

This demonstrates a stale endpoint constraint after clipping: an original open
endpoint can become the seam of a retained cycle. Merely being incident to surviving
edges does not establish that it remains an open terminal. The upstream output
is an open contour with coincident start/end, so its closure flag is a separate
API comparison from our failure to return geometry.

## Repair direction, not implemented

Determine surviving endpoint roles from retained source traversal/occurrences,
rather than requiring odd degree for every attached original endpoint. A cycle
may visit the same geometric vertex as both traversal endpoints and have even
degree. Preserve genuinely open terminals and source-order reconstruction.
Do not globally suppress parity ambiguity: branched ambiguous graphs still need
the existing guard. Check chain validation as well as initial parity requests.

Next validation should reduce this to a permanent native regression and test
reversed traversal plus surviving-open-terminal controls. This investigation has
only run JavaScript diagnostic replays; no new Erlang/full-suite claim is made.

## Candidate implementation

The candidate deliberately handles a narrower, provable case than general
endpoint-role reconstruction: when a protected vertex belongs to an intact
unit-capacity cycle, omit its preferred odd-parity request. Every vertex in the
connected component must have exactly two active, non-self-loop edges, each of
capacity one. Isolated vertices, open chains, branches and repeated capacities
keep the previous behavior. The general forced-parity API and chain validation
are unchanged. Both original open endpoints remain available to source-order
reconstruction and its validation.

The check runs at terminal trimming after winding rejection. Capacity extraction
is shared between the cycle check and the existing parity solver. It does not
change graph vertices, edge geometry or capacities.

Two permanent tests in `svg_path_offset_endpoint_cycle_test.gleam` cover both
orientations of the square fixture (length 32, bounds [1,1,9,9], closed native
output), and both orientations of a genuinely open line offset. The module is
included in portable tests. Existing required-parity ambiguity and capacity
validation tests remain unchanged.

Initial validation: `gleam test` — 2,069 passed, no failures. See
`endpoint-cycle-fast.log`. Further target and slow-suite results follow below.

All eight original offset variants now complete and match the recorded length,
area-comparison convention and bounds (`endpoint-cycle-repaired.jsonl`). Native
output is explicitly closed; Cavalier retains an open contour with coincident
endpoints. The comparator intentionally does not compare closure flags, so these
are aggregate matches, not identical path representations.

Final completed validation for the candidate:

- `gleam test`: 2,069 passed (`endpoint-cycle-fast.log`).
- `scripts/test-portable all all`: 815 Erlang and 815 JavaScript passed
  (`endpoint-cycle-portable.log`; Node 24.10.0 on PATH).
- `scripts/test-slow`: 31 passed (`endpoint-cycle-slow.log`), run after portable
  completed to avoid its temporary test-directory move affecting that runner.
- Formatting and whitespace checks passed.

No figures regenerated, no F# port, and no commit in this test turn. The candidate
is retained for review. The rule is intentionally conservative; more complicated
branched/repeated-capacity endpoint cases are not claimed to be resolved.
