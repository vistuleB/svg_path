# Inward square offsets: surviving contours — 2026-10-19

Baseline `c64cd00`. Investigation only; production code and permanent tests are
unchanged. F# remains deferred.

## Native reproduction

Source: closed square (-1,-1), (1,-1), (1,1), (-1,1). Round joins, negative
offset distance, default options and trimming. No upstream adapter is needed.
Fresh JavaScript replay of the 48 circle/square trimming combinations retains
the historical subpath counts. The six-distance square probe also reproduces
on Erlang (small area rounding differences only).

| Inward distance | Default result |
| --- | --- |
| 0.5 | Square of area 1 |
| 1 | Empty |
| 1.25 | Empty |
| 1.5 | Four-arc central loop, area about 0.028898609535 |
| 2 | Reversed square of signed area -4, plus four-arc loop of area 1.260586974511 |
| 2.5 | Empty |

At 1.5 disabling offside trimming leaves the same final loop. Disabling in-band
trimming preserves the full raw self-intersecting walk. Thus offside trimming
is not inventing the small loop, and the final winding pass deliberately retains
its edges.

## Why the winding pass retains them

`prepare-square-winding-trace.py` instruments a copied JS build to log each edge,
its expected winding pair, measured pair, and original keep decision. It does
not alter decisions. At distance 1.5:

- 28 edges have expected (1,0), measured (2,1): rejected.
- 16 edges have expected (1,0), measured (3,2): rejected.
- Four central arc pieces have expected (1,0), measured (1,0): retained.

At distance 2, four central arcs again exactly match (1,0), and four coincident
source/offset edges exactly match expected and measured (2,0). Those survivors
form the two reported contours. This is not a roundoff mismatch, erroneous
negative-common-shift acceptance, or an unexplained extra curve after trimming.

For a closed inward offset, `offside_trimmed_single_offset_winding_subpaths`
constructs semantic band winding as source minus the surviving raw offset.
The round joins are radius-d quarter-circles centered at the original square
corners. They pass through the origin at d=sqrt(2). The shifted straight edges
pass through it at d=1. An independent dense-angle winding calculation from
these known centers (not native curve or winding code) obtains:

| d | Raw offset winding at origin | Source-minus-offset band winding |
| --- | --- | --- |
| 0.5 | 1 | 0 |
| 1.25 | -3 | 4 |
| 1.5 | 1 | 0 |
| 2 | 1 | 0 |
| 2.5 | 1 | 0 |

The last row describes the raw walk; offside trimming removes it before final
classification at 2.5. The sampled calculation checks selected points, not a
proof of every face. The captured edge decisions establish the local cause.
At 1.5 the retained central boundary consists of the inward-facing corner-circle
pieces; its axis intercept is sqrt(d*d-1)-1 = 0.11803398875.

## Contract classification and recommendation

This differs from filled-region erosion. A square of inradius 1 has no positive
area erosion at d>=1; the center cannot become part of it again at d>sqrt(2).
The retained loop is less than distance d from source edges, even though each
arc is exactly distance d from its originating corner.

Our documented offset contract describes normal-extrusion construction followed
by offside face filtering and winding/parity-capacity trimming. It does not
promise a nearest-boundary distance threshold, monotonic erosion, or empty
output beyond the inradius. `SingleOffsetTrimming` also explicitly preserves
traversal without final nesting-based reversal. The measured decisions agree
with the implemented and documented mechanism. Classify this reduced square
case as an understood trimming-policy limitation, not a confirmed solver bug.
This does not close all offset discrepancies or prove every trimming decision.

Recommendation: clarify that default trimming is not morphological erosion and
may retain contours after inward collapse. Do not silently discard these loops
by tightening tolerances or changing the winding predicate. If erosion is wanted,
consider a separate future operation or explicit policy using nearest-source
boundary distance on candidate regions, with independent topology/degeneracy
validation. This investigation has not implemented or validated that algorithm.

## Evidence and validation

- `offset-collapse-current.json`: fresh 48-case public replay.
- `probe-square-winding.mjs`, `square-winding-results.json`.
- `prepare-square-winding-trace.py`, `square-winding-trace.jsonl`.
- `probe/src/square_collapse_audit_probe.gleam`, `square-collapse-erlang.log`.
- `check-square-winding.py`, `square-independent-winding.json`.
- Preview: `examples/debug/square-collapse-winding.svg`.

Targeted native JS/Erlang diagnostics only; no full suite or figure regeneration
was needed or claimed for this investigation. No production changes or commits.


## Follow-up closed — 2026-10-21

The user reviewed the Gallery example and fresh previews with offside disabled,
in-band enabled. Distances 0.5, 1, 1.5 and 2 have identical serialized output to
the default calls. At distance 2.5 default trimming returns empty; disabling
offside preserves one closed self-intersecting walk. The user accepted these as
expected behavior under the current implementation and closed the beyond-collapse
review. No algorithm change is requested. Morphological erosion would be a
separate contract, not a pending repair to this example.

Reproduction: `node scripts/cavalier/draw-square-no-offside.mjs` and the same
command with `--2.5`. Records: `square-no-offside-preview.json` and
`square-2-5-preview.json`. Preview SVGs are under `examples/debug/`.
No production change or new test-suite run for this classification update.
