# Near-tangent vertex membership investigation — 2026-10-19

This follows the uncommitted arc-interval witness experiment in
`NEAR-TANGENT-OFFSET-TRIAGE.md`. No production code was changed in this
investigation. Instrumentation and the candidate below affect only a copied
JavaScript build under `/tmp`.

## Confirmed identity loss in both original cases

The ambiguous vertices do not merely have overlapping tolerance neighborhoods:
they contain the **same exact endpoint sample**. `attach_vertex` always runs
`best_vertex_attachment`, choosing the cluster whose proposed enclosing circle
has the smallest radius. It does not first preserve membership of a sample
already assigned to a cluster. When another cluster is created later, a repeated
endpoint can therefore join that cluster instead, while remaining in the old
cluster's sample list. Incident edges can acquire different vertex identities
for an identical geometric endpoint.

CC01267:

- A repeated sample `(44.654707373969785, -2.0000001287141402)` first belongs to
  vertex 15. Addition of another sample moves that cluster's representative
  to `(44.654707375267876, -2.0000001287147997)`.
- Vertex 17 is later created at
  `(44.65470737160856, -2.000000128712941)`.
- The exact earlier sample is attached again during
  `progressive_replacement_edges`, but now chooses vertex 17. Its resulting
  radius is smaller than vertex 15's radius. Both sample lists now contain it.
- An incoming piece's start (already an exact sample of vertex 15, with a
  slightly different y coordinate from the shared sample above) lies within
  `2e-9` of both representatives. `unique_vertex_for_endpoint_loop` rejects it.

CC01271 independently exhibits the same sequence. The repeated sample
`(44.6547075248664, -2.000000128790753)` initially belongs to vertex 5 and is
later added to vertex 39 by `progressive_replacement_edges`. The next failed
piece's start is within tolerance of both clusters. This is not an inference
from the forward case; both creation histories were captured.

## Reduced reproduction without arcs

Use endpoint tolerance 2 and minimum length 0.01. Insert these five lines in
order (also supplied together to `arrangement.build_with`):

```text
( 0,    0) -> ( 0,    10)
( 2.6,  0) -> ( 2.6,  20)
(-2.36, 0) -> (-2.36, 30)
( 0,    0) -> ( 0,   -10)
( 0,    0) -> (10,   -10)
```

After the second line, the first cluster has samples 0 and 2.6 on the x axis,
center 1.3, radius 1.3. The third line creates a separate cluster at -2.36:
combining it with both existing samples would exceed radius 2. When the fourth
line repeats (0,0), the new cluster's proposed radius is 1.18, smaller than 1.3.
The routine assigns (0,0) to the second cluster too. The fifth line then fails
unique-vertex validation: its exact (0,0) endpoint matches both representatives.

Both Erlang and JavaScript reproduce the duplicate ownership and
`InternalNormalizationError`. This is ordinary-sized straight-line geometry,
not a representational limit of short arcs. The repeated lines share an endpoint
but have no proper interior intersections. The insertion primitive's atomic
precondition is respected.

## Candidate and limits

In a copied JavaScript build, before greedy attachment, find a vertex whose
`endpoint_samples` already contains the exact endpoint. Preserve that owner,
append the repeated sample, and keep its center (the enclosing point set has
not changed). Continue the existing radius-based policy for genuinely new
samples. This repairs the five-line reproduction: one owner throughout and
`build_with` returns `Ok`.

This is preferable to selecting the nearest representative during ambiguous
lookup: the latter could give an already attached endpoint a new owner. It also
avoids merging clusters whose combined sample radius exceeds tolerance, moving
edge endpoints, or changing the tolerance definition.

The reduced repair is **not yet demonstrated to complete the original offsets**.
An initial full CC01267 copied-build experiment was interrupted without a final
result. A separate 60-second bounded replay records its outcome and progress in
`near-tangent-membership-bounded.*`. Do not treat improved progress or the reduced
case's success as a repaired Cavalier fixture. Further work must inspect the
progressive subdivision and identity of non-identical, numerically nearby split
endpoints as well as enforce exact membership consistency.

## Reproduction and evidence

- `prepare-vertex-provenance-trace.py`: observational wrapper around the existing
  copied-build tracing; captures original segments, vertex attachment histories,
  edge splits and the failed piece with its graph.
- `near-tangent-vertex-provenance.json` and `*-reversed.json`: full histories for
  CC01267 and CC01271; matching `.log` files contain ambiguity diagnostics.
- `probe/src/vertex_identity_audit_probe.gleam`, run with
  `gleam run -m vertex_identity_audit_probe` from `scripts/cavalier/probe`:
  native reduction. Output `vertex-identity-erlang.log`.
- `probe-vertex-identity.mjs`: same reduction on copied JavaScript build.
  Baseline output `vertex-identity-javascript.log`.
- Run trace preparation with `AUDIT_PRESERVE_VERTEX_MEMBERSHIP=1` to enable the
  copied-build experiment, then run the same JavaScript reduction. Output
  `vertex-identity-membership-experiment.log`.
- `AUDIT_TRACE_PROGRESS=1` adds periodic event diagnostics. The bounded original
  replay uses the exact-membership experiment and records an explicit time limit.

No full-suite rerun, F# change or commit: this turn is an investigation. The
previous overlap candidate and its tests remain uncommitted and unchanged.

Bounded original-case result: CC01267 did not finish within 60 seconds with the
copied-build exact-membership change. Progress diagnostics show continued
splitting and attachment beyond the earlier 110-event failure (at least 225
recorded events). This is a time-budget observation with instrumentation, not a
performance benchmark or proof of nontermination. The duplicate-membership
repair is supported by the reduced case; the full offset remains unresolved.
`near-tangent-membership-bounded.status.json` records the timeout. No completed
JSON result exists for that run.
