# Near-tangent offset investigation — 2026-10-19

After short-arc cleanup commit `abe15554`, CC01267 and CC01271 still return
`ConstructionFailed`. These are the captured
`test_past_failures::near_tangent_line_arc_joins` cases. The mechanism below is
confirmed for CC01267; CC01271 has only been replayed, not independently traced.

## Confirmed mechanism

CC01267 is a continuous open Line–Arc–Line source. Its circular arc is valid.
Untrimmed offset construction succeeds. The public offset fails even with
offside filtering disabled and `NoTrimming`: arrangement overlap checking
fails before those choices can avoid the problem.

The internal error is `InternalArrangementGraphError(InternalPathError(
DegenerateArc))`. `sampled_overlap_valid` extracts a right-hand arc interval
using `segment_between_inside`. The failing generated arc is:

```text
start  = (44.65470741897046, -2.0000001287369904)
end    = (44.65470741271587, -2.0000001287338165)
radius = (1, 1), rotation = 0, large_arc = false, sweep = true
from   = 0.9999995858161379
to     = 1
```

Its chord is about 6.25e-9. Extracting its final 4.14e-7 parameter fraction
produces a remainder whose two endpoints both round to the original end point.
`forward_segment_between` then splits that remainder again, triggering
`DegenerateArc`. Native Erlang reproduces both the direct extraction error and
the original public offset error; JavaScript tracing identifies the call path.
This is an internally generated numerical degeneration, not an invalid input
arc or an upstream output-policy disagreement.

## Repair constraints

The next repair should avoid constructing an unusable endpoint-form arc during
overlap validation. Prefer a local solution that measures against the original
arc's restricted parameter interval, or a rigorously bounded treatment of an
interval that has collapsed at floating-point precision. Do not merely skip
the second split: that would return an invalid coincident-endpoint arc.

Do not replace the current projection test with paired-parameter sampling:
`sampled_overlap_valid_loop` measures distance to any point of the extracted
right interval, not just to the matching affine parameter. That substitution
would change overlap semantics. Do not swallow `DegenerateArc` indiscriminately
or convert arbitrary equal-endpoint arcs into points.

No production repair has been implemented for this issue. A repair must retain
the existing overlap behavior and be tested against both original cases and
the broader intersection/arrangement/offset regressions.

## Evidence and reproduction

- `near-tangent-offset-cases.json`: selected captured originals.
- `near-tangent-offset-current.jsonl`: fresh JavaScript replay of both errors.
- `prepare-near-tangent-trace.py`: creates an instrumented copy of the portable
  JavaScript build under `/tmp/cavalier-near-tangent-offset-trace`; production
  sources and normal build output are untouched.
- `probe-near-tangent-offset.mjs` and `near-tangent-offset-trace.json`: four
  offset modes, internal errors, failing arc extraction and call stacks.
- `probe/src/near_tangent_offset_audit_probe.gleam` and
  `near-tangent-offset-erlang.log`: direct native reproduction and public case.

Run the native probe from `scripts/cavalier/probe` with
`gleam run -m near_tangent_offset_audit_probe`. For JavaScript, first prepare
the portable build, run the trace preparation script, then run the JavaScript
probe with Node. This investigation does not add permanent regression tests or
change audit baseline results. F# remains deferred.

## Candidate witness repair — 2026-10-19

An experimental local repair is now in `sampled_overlap_valid`. Ordinary
extraction and projection remain the first path. If that path returns
`DegenerateArc`, validate the original right arc and evaluate its interval
endpoints and midpoint. Accept the sampled distance check only if every left
sample has an actual right-interval witness within tolerance. A witness bounds
nearest distance from above, so this does not assume affine correspondence or
turn a collapsed arc into a line. If any sample lacks a witness, preserve the
original error; this is not evidence of non-overlap. Invalid original arcs
still fail validation. No public API or arc-splitting behavior changes.

The first experiment caught only extraction errors. It exposed a second path:
extraction can also return `Ok` with an invalid coincident-endpoint arc, which
then fails during distance evaluation. The final candidate catches that error
from the combined extraction-and-projection operation.

Three regressions in `svg_path_arc_interval_overlap_test.gleam` cover forward
and reversed intervals on the reduced valid arc, invalid original arcs, and an
inconclusive witness search (an interior excursion with matching endpoints).
The last must retain the error rather than silently accept or reject overlap.

### Original offsets are not repaired yet

`near-tangent-offset-witness.jsonl` records both original cases still returning
`ConstructionFailed`, now after more computation (about 16 and 48 seconds in
this run, not isolated benchmarks). A preliminary 10-second-budget replay
reported a timeout for CC01271; the final replay used 120 seconds per case.

For CC01267, tracing shows that the candidate gets past arc degeneration and
reaches `unique_vertex_for_endpoint_loop`, which returns
`InternalNormalizationError`. The endpoint
`(44.654707373969785, -2.0000001287141567)` lies within the `2e-9` vertex tolerance
of both vertex 15 (distance `1.298090683233275e-9`) and vertex 17 (distance
`1.1806095487078072e-9`). Those vertices are about `2.479e-9` apart: farther than
the matching tolerance, but with intersecting matching neighborhoods. Choosing
the nearest or first vertex is not yet justified; provenance and connectivity
need investigation. This is a separate obstacle to completing the public offset.

Evidence:

- `near-tangent-offset-candidate-erlang.log`: first candidate, native public
  offset still fails; direct arc extraction intentionally remains unchanged.
- `near-tangent-offset-candidate.jsonl` and `*-candidate-trace.json`: first
  candidate's outcome and the later invalid-arc projection failure.
- `near-tangent-offset-witness.jsonl` and `*-witness-trace.json`: final candidate
  replay and CC01267 mode comparison.
- `near-tangent-offset-normalization-stack.log`: exact normalization failure
  call path.
- `near-tangent-offset-ambiguity-stack.log` and `*-ambiguity-trace.json`: endpoint
  and both nearby vertices, with observational tracing only.

Candidate retained uncommitted for review, not declared a complete fix. F# and
figures untouched. The ordinary suite invocation `gleam test -- --help` ran the
suite (the extra argument did not select help): **2,060 passed, no failures**.
Portable validation results are recorded below after completion. The root slow
suite and canonical release sequence have not been rerun for this experiment.

Final portable check: `scripts/test-portable all all` (Node 24.10.0 on PATH)
passed **806 tests on Erlang and 806 on JavaScript**. Raw output:
`near-tangent-witness-portable.log`. README recipe consistency, `git diff --check`
and `validate-records.py` also passed.

The reversed original CC01271 was independently traced with
`AUDIT_CASE_ID=CC01271 AUDIT_ONE_MODE=none`. It reaches the same vertex-ambiguity
check: endpoint `(44.6547075248664, -2.0000001287907363)`, tolerance `2e-9`,
vertex 5 at distance `1.9847663934180586e-9` and vertex 39 at distance
`1.272518246491724e-9`. See `near-tangent-offset-reversed-stack.log` and
`near-tangent-offset-reversed-trace.json`. Both original cases therefore move
past the initial degeneration into an unresolved arrangement ambiguity.
