# CC01301: additional open fragment

Investigated 2026-10-20 after `e4d7255`, without production changes.
The earlier arrangement construction bug was repaired in `09d30a1`.

## Result

The additional Cavalier fragment is not lost during offset construction. Its
main left-hand semicircle exists in the native offset arrangement and passes
winding classification. It disappears in forced parity reduction after a
different, right-hand arc is rejected.

Trace at default fitting tolerance 0.01:

| Stage | Offset-image edge IDs |
| --- | --- |
| Offset images | 0, 5, 1, 6, 15, 7, 2, 3, 4, 8, 9 |
| Winding survivors | 0, 5, 1, 15, 7, 2, 3, 4, 8, 9 |
| Parity survivors | 0, 5, 1, 8, 9 |

Edge 6 expects winding pair `[1,0]`, but measures `[2,1]`. Separate public
point-winding queries on either side of its midpoint agree at distances 1e-3,
1e-4 and 1e-5 (the query's normal-side order reverses the stored pair). These
queries use our containment implementation, not an independent winding oracle.
Its sampled distances to the source are 80.6815, 73.1584 and 56.4959 versus
requested distance 81: this right-hand arc crosses the covered region.

Removing edge 6 leaves the chain 15 -> 7 -> 2 -> 3 -> 4 dangling at vertex 16.
Parity reduction removes that entire chain. Edges 3 and 4 are the left-hand arc
corresponding to Cavalier's extra fragment. Their winding pairs are `[1,0]`
and pass. They total 254.46890099811338 in length, with the connecting short
line edge 2 of length 1.3270338878614748e-5. Cavalier's fragment also contains
small connector/overlapping pieces, so its total is 254.46905435554729.

Three samples per upstream segment map the extra fragment's main arc to native
edges 3/4; the midpoint residual is 5.69e-6. This sampled comparison does not
establish exact equality or a maximum bound. The source contains extremely
short reversals; upstream also explicitly allows offset-distance epsilon 1e-4.
Sampled source distances on native edges 3/4 fall to approximately 80.9999009,
consistent with that proximity scale. No tighter numerical equivalence claimed.

The ordinary final output has one open path, length 63.367633966914624.
The no-final-trimming control retains the raw walk. These are successful calls,
not full-suite or figure validation.

## Disposition

Known trimming-policy limitation/difference, no new confirmed implementation
bug. Current documented algorithm removes winding mismatches then forces parity
capacities; source endpoints are preferred terminals, but a newly exposed
interior vertex is not automatically made a terminal. Cavalier can retain an
open fragment that this rule removes.

A possible API/policy discussion is whether valid partial offset runs should
survive at newly exposed endpoints after winding rejection. That would alter
trimming behavior and needs broader examples and regression checks. Do not
bypass parity or preserve this one arc as a fixture-specific repair. This item
now belongs to the existing general offset-policy discussion; it is no longer
an unexplained CC01301 construction discrepancy.

## Reproduction and evidence

`prepare-cc01301-fragment-trace.py` instruments a copied JavaScript build under
`/tmp/cavalier-cc01301-fragment-trace`. Wrappers preserve return values.

```sh
python3 scripts/cavalier/prepare-cc01301-fragment-trace.py
AUDIT_CASE_ID=CC01301 AUDIT_TOLERANCE=0.01 AUDIT_JS_BUILD=/tmp/cavalier-cc01301-fragment-trace node scripts/cavalier/probe-cc01301-fragment-trace.mjs > scripts/cavalier/cc01301-fragment-output.json 2> scripts/cavalier/cc01301-fragment-stages.json
AUDIT_CASE_ID=CC01301 AUDIT_TOLERANCE=0.01 AUDIT_TRIMMING=none node scripts/cavalier/probe-offset-detail.mjs > scripts/cavalier/cc01301-fragment-untrimmed.json
AUDIT_CASE_FILE=cc01301-fragment-case.json python3 scripts/cavalier/prepare-original-offset-export.py
RUSTUP_HOME=/tmp/cavalier-audit-rustup CARGO_HOME=/tmp/cavalier-audit-cargo CARGO_TARGET_DIR=/tmp/cavalier-audit-target cargo +1.95.0 run --offline --quiet --manifest-path /tmp/cavalier-original-offset-export/Cargo.toml > scripts/cavalier/cc01301-fragment-upstream.jsonl
node scripts/cavalier/analyze-cc01301-fragment.mjs > scripts/cavalier/cc01301-fragment-analysis.json
```

The generated trace probe also records `cc01301-fragment-winding-samples.json`.
Pinned upstream exporter succeeded; both native offset calls succeeded.
