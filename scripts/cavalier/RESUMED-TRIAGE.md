# Resumed triage — 2026-10-18

Native revision `090f8e63`. Investigation only: no production code changes,
no commits, no F# work. Baseline comparison records are preserved.

## Near-semicircle centers and bounds: mixed causes

Cases CX00420/CX00421, CX00622/CX00623 and CX00636/CX00637 use bulges one
floating-point step below magnitude one. These six flags concern three arcs.

Two effects must be separated:

1. The bulge representation retains the center displacement through
   `(1-b)*(1+b)/(4*b)`. Converting to a rounded SVG radius discards that
   near-semicircle information. Even an exact solver of the resulting SVG inputs
   would not reproduce the original bulge center. Snapping to the upstream
   center would silently alter the native input geometry.
2. The native `ellipse.center_prime` calculation subtracts radius/chord products
   of order 1e12 to recover a result near zero. This introduces additional
   forward error even for the exact binary64 inputs supplied to our API.

`semicircle-oracle.py` uses 80-digit Decimal arithmetic and `Decimal.from_float`
to preserve those exact input values. It computes the SVG center independently
as midpoint plus the signed perpendicular half-chord times
`sqrt((r*r - half_chord_squared)/half_chord_squared)`. All three exact differences
are positive, so SVG radius enlargement is unnecessary for these inputs.

| Arc | Exact SVG center (approximately) | Native center error magnitude |
| --- | --- | --- |
| CX00420 | (-0.000005317918071, 0.000003555937939) | 1.415e-6 |
| CX00622 | (9999.999987873408, -19999.999992434414) | 3.244e-6 |
| CX00636 | (10000.000012126592, -20000.000007565586) | 3.244e-6 |

The bulge centers are instead approximately (0,0) and (10000,-20000).
The native center error is reproduced identically on Erlang and JavaScript.
This is measured native numerical inaccuracy, separate from adapter loss. The
routine has no caller-selected accuracy tolerance; do not report the 1e-6 audit
comparison threshold as an API guarantee. A numerically stronger center solver
is a candidate improvement, not yet implemented or validated. The six original
upstream-equality comparisons cannot serve as its expected answers: regressions
must use the exact SVG-input oracle.

Evidence/reproduction:

```sh
(cd test_portable && gleam build --target javascript)
node scripts/cavalier/probe-semicircle.mjs > scripts/cavalier/semicircle-native.json
python3 scripts/cavalier/semicircle-oracle.py > scripts/cavalier/semicircle-oracle.json
(cd scripts/cavalier/probe && gleam run -m semicircle_audit_probe)
```

Saved Erlang output: `semicircle-erlang.log`. The JavaScript probe performs the
same bulge-to-SVG conversion as the adapter, then calls the public ellipse API.

## Elementary intersection batch

Replayed all 18 original discrepancy/error records for the elementary
intersection operations on the current source. Results remain unchanged.
`elementary-triage-cases.json` contains the selected records;
`elementary-triage-20261018.jsonl` contains fresh results.

Fifteen records can be explained under the existing contracts:

| IDs | Disposition / evidence |
| --- | --- |
| CC00013, CC00016, CC00070, CC00071, CC01188 | Several candidates near one tangent contact. The module explicitly permits this for bounded curve searches. Evaluated point-pair residuals are at most 9.11e-14, below default 1e-9. These are not multiple mathematical intersections and are not a tolerance breach. |
| CC00020, CC00057 | Upstream accepts an endpoint gap of 9.9e-6 or a parameter beyond the segment by 5e-6 using epsilon 1e-5. Native default does not request that snapping policy. |
| CC00073, CC00074, CC00075 | The line genuinely crosses the circle twice, with separation approximately 3e-6 to 4e-6. Upstream deliberately collapses them using positional epsilon 1e-5; native returns both. |
| CC00082 | The adapter calls a ray/supporting-line query with zero direction. Native `IndeterminateDirection` is appropriate; upstream treats a point within epsilon 0.01 of the circle as a hit. |
| CC01761 | Line begins about 5e-6 outside the circle. Upstream fuzzy endpoint acceptance uses 1e-5; native default is 1e-9. |
| CC01763, CC01765, CC01767 | Adjacent circular arcs have endpoint gaps approximately 5e-9, 5e-6 and 0.005. Upstream epsilon scales with the fixture (1e-8, 1e-5, 0.01); native default remains 1e-9. |

`probe-elementary.mjs` and `elementary-residuals.json` retain native parameters,
point-pair residuals, endpoint gaps and the default tolerance. No comparator
thresholds were loosened to obtain these dispositions.

### Still open: CC01751, CC01752, CC01753

These are three orientations/orderings of one arc-endpoint fixture. The supplied
endpoints are only 1.4068028429806625e-12 apart, less than native default 1e-9,
yet `intersections.segment` returns `Ok([])`. Unlike the larger-gap cases above,
this cannot be dismissed by comparing the two default tolerances alone.
The general intersection API disclaims exhaustive search, so an empty result is
not by itself proof of a public-contract violation. Investigate endpoint
candidate generation and its internal search tolerance before classifying it.
This is the recommended next focused investigation. No production fix proposed
or applied for it yet.

## Validation and scope

- JavaScript dependency build passed.
- All 18 selected comparisons completed; original outcomes reproduced.
- Three native center probes completed on Erlang and agree with JavaScript.
- Independent exact-input Decimal oracle generated for all three arcs.
- No full suite rerun: production code and permanent tests were unchanged.
- Broad Boolean/offset errors, overlap adaptation and remaining coverage gaps
  remain open; these dispositions do not close the Cavalier audit.


## Subsequent batch

See [ENDPOINT-BOOLEAN-TRIAGE.md](ENDPOINT-BOOLEAN-TRIAGE.md): the endpoint
misses are traced to internal tolerance narrowing, two XOR cases are explained,
and 35 intersection discrepancies have confirmed outside-input witnesses.
