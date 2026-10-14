# FI002: shared-endpoint candidate clusters

Investigated 2026-10-14 against production commit `dd381a2`. No production
source or tests changed during this investigation.

The fixture source is FloBezier 9.0.1, revision
`8ad65ac79cb69989cd40b0d375a51392eb477f16` of
https://github.com/FlorisSteenkamp/FloBezier (MIT). The extracted fixtures retain
upstream file names, test names, and captured reference results.

## Disposition

Documented numerical limitation, not a confirmed violation of our current
intersection contract. The introductory documentation in
`src/svg_path/intersections.gleam` explicitly says near-tangent geometry may
produce several acceptable candidates for one mathematical contact. The
public tolerance bounds the separation of the two evaluated points; it is
not a certified bound on distance to a mathematical root.

There are 20 affected upstream calls, containing 29 reference intersections.
Current JavaScript results contain 52 candidates: every reference parameter
pair is matched within the audit's diagnostic 1e-7 threshold, plus 23 extras.
All extra clusters are beside shared endpoints. Thirteen inputs have regular,
parallel endpoint derivatives; seven have a zero endpoint derivative on one
input. These are ill-conditioned parameter solves.

Both argument orders were rerun on JavaScript and Erlang (40 queries per
target). Candidate counts agree between targets for every ordered query.
Argument order itself changes the candidate count in case 1283 (3 versus 2),
consistent with an approximate search, not a certified root inventory.

## Independent algebra for call 1268

The quadratics are:

- A: `(11,40), (89,67), (-7,44)`
- B: `(19,23), (185,90), (-7,44)`

Put `u=1-t_A`, `v=1-t_B`, measured from the shared endpoint. Then:

- A = `(-7,44) + (192,46)u + (-174,-50)u²`
- B = `(-7,44) + (384,92)v + (-358,-113)v²`

Eliminating the common linear tangent gives `399u² = 1307v²`.
Besides `(u,v)=(0,0)`, the two real solutions have approximately
`(u,v)=(-0.311667,-0.172203)` and `(6.245833,-3.450953)`.
Neither lies in `[0,1]²`. Thus the sole exact intersection of these segments
is `(t_A,t_B)=(1,1)`.

Our two additional pairs are approximately
`(0.999999372774,0.999999686387)` and
`(0.999999685419,0.999999842710)`. They are approximations near the same
contact, not additional exact roots. The farther returned point is about
0.000124 path units from the true endpoint, even though the two curves at
its parameters are separated by less than 6e-13. This illustrates the
important distinction between residual tolerance and root-location accuracy.

For all 52 returned pairs, evaluation with 90-digit Decimal arithmetic using
the exact binary64 parameter values gives residuals below 7.71e-13, comfortably
within the default 1e-9 tolerance. This residual check does not independently
prove completeness of the reference root inventories for the other 19 cases;
those classifications additionally rely on the pinned reference results.

## Why the candidates survive

`elizabeth_beam_search` allows a coordinate-scaled floating-point residual
floor (16 machine epsilons times the largest control-coordinate magnitude).
Near a tangency, separation can decrease quadratically with displacement,
so this permits a wider interval of parameters than at a transverse crossing.
The final beam candidate filter merges only within 1e-7 in parameter space;
these endpoint neighbors are about 1.04e-7 to 6.28e-7 away.

For representative regular/stationary cases 1268, 1622 and 1714, reducing
public tolerance from 1e-9 to 1e-12 leaves the results unchanged. At 1e-14,
all three return `InternalUncertifiedSegmentIntersection`. That is consistent
with the documented final certification behavior, not a way to obtain a
unique root count.

## Recommendation

Close FI002 as an understood numerical limitation. Do not enlarge the global
parameter merge radius or snap every near-endpoint candidate to the endpoint:
that can discard genuine nearby roots or distinct visits to the same point.

If improved behavior becomes necessary, investigate local root isolation or
endpoint-root deflation, preserving separate nearby roots. That requires
stronger evidence than pointwise residuals and is a separate numerical project.
No API change or production fix is proposed by this investigation.

## Reproduction

- `node scripts/flobezier/tangent-investigation.mjs`: current results in
  `tangent-investigation.json`; both argument orders and three tolerance sweeps.
  First run `gleam build --target javascript` in `scripts/flobezier/probe`;
  the script imports that local dependency build and reads `tangent-fixtures.json`.
- `python3 scripts/flobezier/tangent-exact-analysis.py`: high-precision
  residuals in `tangent-exact-analysis.json`, plus the independent algebraic
  solution for call 1268. Uses only the Python standard library.
- From `scripts/flobezier/probe`,
  `gleam run --target erlang -m tangent_probe`: `tangent-erlang.log`.

Diagnostic probes only; no full regression suite was run.
