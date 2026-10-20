# CC01301: near-semicircle progressive subdivision

Investigation after commit `3425b9e` (2026-10-20). Production is unchanged by
this investigation. Controls patch isolated generated JavaScript copies only.

## Confirmed failure

A radius-81 arc sweeps -179.99998882125465 degrees. Trimming its start at
parameter 3.011885532211048e-8 creates a new endpoint-form Arc. Its inferred
center differs from the original by 2.186491017e-6. Later progressive subdivision
of this tail produces an endpoint 1.755612765e-6 away from the original source
at the composed parameter, exceeding the arrangement's 2e-9 certification
allowance. The certification error is real; increasing that allowance would
hide the displacement.

`probe-cc01301-circle-conditioning.py` uses 80-digit Decimal arithmetic on the
exact binary input coordinates. It finds the same center separation. The
existing ordinary circular conversion is already accurate for those encoded
inputs: higher precision cannot recover center information lost when the new
endpoint was rounded. Enabling the existing double-double ellipse converter
for circles also leaves CC01301 failing.

The arrangement reduction contains only three segments:

1. The original near-semicircular arc.
2. Its short start-to-cut chord.
3. A radial line crossing it at parameter 0.2841409618472.

Inserting [arc, endpoint chord, crossing line] returns
`InternalNormalizationError`; [arc, crossing line, endpoint chord] succeeds.
Both Erlang and JavaScript reproduce this. This is a numerical arrangement
failure, not a distinction between offset trimming policies.

Probes: `probe-cc01301-arrangement.mjs`,
`probe/src/cc01301_arrangement_probe.gleam`, and the corresponding
`cc01301-arrangement-baseline.jsonl` / `cc01301-arrangement-erlang.log` records.

## Controls

`prepare-cc01301-controls.py` creates isolated copies of the portable JS build.

| Control | Three-segment reduction | CC01301 construction | Notes |
| --- | --- | --- | --- |
| Baseline | Fails in one insertion order | Fails | Production behavior |
| Precise circle conversion | Not separately run | Fails | Cannot restore lost endpoint information |
| Pre-split arcs of at least 179.9 degrees into <=90-degree pieces | Passes | Succeeds | Adds vertices even to otherwise untouched arcs; not recommended as a blanket policy |
| Sample-based adaptive split | Passes | Succeeds | Compare reconstructed subarc to parent at quarter, half, three-quarter parameters |
| Center/radius/phase bound alone | Over-subdivides | Fails | Very short arcs can have displaced centers yet nearly identical traces |
| Combined geometric bounds | Passes | Succeeds | Preferred candidate; described below |

The adaptive controls operate in `split_atomic_piece` and
`split_progressive_graph_edge`, before a newly encoded tail is reused. They
leave an unsplit input arc alone. Existing source index/interval machinery
accounts for each extra cut; no caller-input segment renumbering is introduced.

## Preferred candidate

For each proposed arc interval, compare the parent restricted to that interval
with the reconstructed child in center form. Use the minimum of two upper
bounds on their pointwise difference:

- Center displacement + maximum radius difference + maximum parent radius
  times the maximum unwrapped angular disagreement (capped by the unit-circle
  chord diameter).
- Maximum endpoint disagreement + one eighth of the sum of the parent and
  child second-derivative bounds. For angular parameterization, each such bound
  is maximum radius times interval sweep in radians squared.

The first is useful for ordinary arcs, the second for short arcs whose inferred
centers are poorly constrained. These are conservative geometric bounds in real
arithmetic, evaluated here in floating point, not certified interval arithmetic.
The experiment assigns one quarter of the local tolerance to this check and
bisects failing intervals directly from the parent. That budget still needs
review for cumulative subdivision error and evaluation rounding.

CC01301 triggers two distinct bisections per arrangement build; no further
subdivision was needed. Both fitting tolerances 0.01 and 0.00001 construct
successfully. An untouched arc stays one edge; the three-segment example can
still produce different edge counts by insertion order. No claim of canonical
minimal graph structure is made.

The prototype has a depth cap of eight and logs unresolved checks. Production
must return an explicit internal failure at the cap, rather than accepting an
unchecked piece. No unresolved checks occurred for CC01301 or the targeted
combined-bound test run. Production also needs minimum-length handling and a
cheap ordinary-arc fast path considered before adoption.

## Verification and remaining comparison

`check-cc01301-control.mjs` ran 142 existing portable tests selected from
arrangement, CSG, offset, stroke, arc, and semicircle modules. Sample-based and
combined-bound controls each passed 142, failed 0. These are JavaScript-only
controls, not a full suite or figure validation. The baseline three-segment
failure was independently confirmed on Erlang.

Successful default output has one open subpath, length 63.367633966914624;
Cavalier's corresponding main fragment is 63.36763396689099. Cavalier also
reports a separate open arc fragment of length 254.46905435554729, which our
in-band trimming does not retain. With final in-band trimming disabled, our
pre-split control returns one raw walk of length 572.3056505869621. Therefore
construction success does not establish complete fixture parity. The extra
fragment's treatment remains to be classified against our trimming contract.

## Recommendation

Implement the combined-bound adaptive subdivision as a separate arrangement
repair, with the reduced order-dependent regression and explicit depth/length
failure handling, then run full tests and figures. Keep the remaining output
fragment comparison open. Do not change public Arc representation, increase
arrangement tolerance, or apply blanket initial arc splitting for this case.

Reproduction:

```sh
# After building the portable JavaScript project:
python3 scripts/cavalier/prepare-cc01301-controls.py
python3 scripts/cavalier/probe-cc01301-circle-conditioning.py
AUDIT_JS_BUILD=/tmp/cc01301-baseline node scripts/cavalier/probe-cc01301-arrangement.mjs
AUDIT_JS_BUILD=/tmp/cc01301-combined-bound-arcs node scripts/cavalier/probe-cc01301-arrangement.mjs
AUDIT_JS_BUILD=/tmp/cc01301-combined-bound-arcs AUDIT_CASE_ID=CC01301 AUDIT_TOLERANCE=0.01 node scripts/cavalier/probe-short-transition.mjs
AUDIT_JS_BUILD=/tmp/cc01301-combined-bound-arcs node scripts/cavalier/check-cc01301-control.mjs
# From scripts/cavalier/probe:
gleam run -m cc01301_arrangement_probe
```

## Production repair (2026-10-20)

Implemented the combined-bound check in both atomic-piece and progressive-edge
splitting. Untouched arcs retain their original representation. Failing child
intervals are bisected directly from the parent, with a depth limit of eight.
An exhausted limit or a required cut below minimum length returns an internal
construction error; unchecked geometry is never accepted as a fallback. The
public error union is unchanged. Final source-image certification still checks
the accumulated result, independently of the quarter-tolerance local budget.

The new portable regression module tests both insertion orders and reversed
traversal, samples each source-image mapping, checks an untouched arc remains
one edge, and exercises CC01301 through the public offset API. Production probes
succeed at fitting tolerances 0.01 and 0.00001. The separate missing-fragment
comparison above remains open. F# is not ported.

The historical control-generation command above requires a portable JavaScript
build from `3425b9e`; it now rejects builds containing the production repair to
avoid reporting a repaired runtime as the baseline.

Validation on the production implementation:

- `scripts/test-portable all all`: 855 Erlang and 855 JavaScript tests passed.
- `scripts/test-all`: 2109 ordinary and 31 slow tests passed.
- `gleam format --check src/svg_path/arrangement.gleam test/svg_path_arrangement_arc_subdivision_test.gleam`: passed.
- `git diff --check`: passed.

Raw test results and production probes are recorded alongside this document as
`cc01301-portable.log`, `cc01301-root-tests.log`,
`cc01301-production-001.json`, `cc01301-production-000001.json`, and
`cc01301-production-arrangement.jsonl`.

`scripts/generate-published-figures` completed successfully: all 13 README
figures and all 34 Gallery figures were regenerated. All 47 SVGs are
byte-for-byte identical to the saved pre-repair working-tree outputs. This
comparison preserves unrelated preexisting changes instead of comparing against
HEAD. See `cc01301-figures.log` and `cc01301-figure-comparison.json`.

Verdict: retain this repair for the demonstrated arrangement construction bug.
It needs no public option or representation change. No claim of complete
CC01301 output parity or resolved trimming semantics is made.
