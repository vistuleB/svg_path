# Boolean error triage, 2026-10-13

This is a classification of the **69 errors** in the saved 178-comparison screen.
It is not successful Boolean parity, not a completed Paper.js audit, and not a
release qualification. Production code was not changed. The 102 earlier sampled
matches were not rerun in this investigation.

All 69 saved errors reproduce on Erlang and JavaScript. The previous 62
unclassified errors now have a disposition: 54 overlap-contract limitations
and eight numerical crossing failures. The previously accepted overlap case
makes **55 overlap limitations** in total. The six existing topology failures
also have more specific causes. There are **14 failing comparisons**, not 14
independent bugs.

| Current disposition across the 178 comparisons | Count |
| --- | ---: |
| Earlier sampled geometry match | 102 |
| Understood overlap-correspondence limitation | 55 |
| Crossing root-isolation failure | 8 |
| Topology/classification failure at default settings | 6 |
| Different operation/fill-rule adapter needed | 7 |
| Unclassified error | 0 |

`boolean-status.json` is the current disposition table.
`boolean-error-findings.json` retains per-fixture results from both targets,
source SHA-256 hashes, failing rays/vertices and classification experiments.
Older reports are historical snapshots and have not been rewritten.

## Contract assessment

The table counts reproduced failures, not proven contract violations. Fixtures
69 and 172 are the strongest confirmed defects: CSG fails despite a valid
arrangement and usable geometric incident order. The eight crossing cases show
a numerical weakness, but the internal root contract explicitly permits merging
close roots and does not guarantee completeness for ill-conditioned polynomials.
Their incorrect or unhelpful isolation windows alone do not prove a violation
of that contract. Cases 79/113 remain localized classification failures.
Discarding short pieces in 122/123 is explicitly documented, so those cases do
not yet establish a defect beyond the configured size-filtering limitation.
No production repair is implied by the `confirmed-our-failure` report status.

## Overlap correspondence: 55 limitations

The overlap API requires an affine, monotone relationship between the two
segment parameters on every overlap piece. A common geometric trace is not
sufficient. The error is raised deliberately when that requirement fails.

For **each** of the 55 errors, the diagnostic records the exact pair of segments
and an uncovered rejected parameter interval. Independent 80-digit Decimal
calculations, starting with the actual binary64 controls and parameters, check:

1. Trim both cubics to the recorded intervals using de Casteljau subdivision.
2. Project their control polygons along a common chord. Both projected control
   sequences are monotone. The control-polygon transverse bounds and endpoint
   projection gaps therefore bound the distance between their geometric images.
3. The resulting whole-interval geometric-distance bound is below the detector's
   `5e-7` tolerance. The largest bound is approximately `4.1132e-7`.
4. Evaluate paired parameters at 1/4, 1/2 and 3/4 under the required affine
   mapping. At least one exceeds the tolerance. Even the smallest maximum
   mismatch is approximately 5.85 times the tolerance.

The calculations use a `1e-60` comparison margin, well below the observed
margins; they are high-precision numerical bounds, not an interval-arithmetic
proof implementation. Line inputs are elevated to cubic form for the same
checks. See `boolean-overlap-witnesses.json` and `check-overlap-witnesses.py`.

This explains the **reported blocker** in every case. It does not establish
that linearizing the inputs would make every operation pass, nor exclude a
later independent defect. Several witnesses are only approximately collinear;
replacing all of them with lines would change geometry. No such replacement
was made.

## Crossing isolation: eight failures, five distinct witnesses

Fixtures **103, 107, 128, 129, 130, 131, 168 and 169** fail in
`polish_line_crossing_roots`, while overlap endpoint projections query a
coordinate line. Pairs 128/129, 130/131 and 168/169 share their respective
failing projected cubic.

The reported root window does not contain the real interior root. Independent
80-digit bisection of the projected Bernstein polynomial gives:

| Fixtures | Interior root, approximately | Reported estimate, approximately |
| --- | ---: | ---: |
| 103 | 0.999999043644256 | 0.999999999999972 |
| 107 | 0.999999827004815 | 0.999999913502410 |
| 128–129 | 0.999999345740485 | 0.999999999999997 |
| 130–131 | 0.999999583900639 | 0.9999999999999997 |
| 168–169 | 0.999999175280590 | 0.999999999999994 |

The seven near-endpoint estimates are not *exactly* 1, so they miss the existing
exact-endpoint/monotone fallback. The original coefficient-relative isolation
has mistaken near-endpoint behavior for an endpoint root. Refining its narrow
window cannot recover the real root outside it.

Fixture 107 is different: it has both an exact endpoint root at 1 and a nearby
interior root. The reported estimate lies between them. A general endpoint snap
or unconditional whole-domain search would risk merging roots. This case needs
root isolation that preserves both roots.

The independently found roots, rounded to binary64 parameters, have projected
Bernstein residuals below `1e-20`, versus the requested `1e-12`. Thus these are
not cases where coordinate precision makes the requested accuracy unattainable.
See `boolean-crossing-witnesses.json`. No solver modification was made.

## Topology failures

### 69 and 172: CSG discards the arrangement's geometric ordering

Both graphs pass closed-boundary validation and their selected boundary edges
have equal incoming/outgoing counts. Their arrangement `cyclic_orders` already
separate the incident curves in a usable geometric order. CSG instead sorts
endpoint tangent headings afresh.

- Fixture 172: two rays have heading 90 degrees and two have heading 270 degrees.
  Angle-only ordering produces an incoming ray followed by another incoming ray.
  Nearby curve samples separate them; the arrangement's order alternates
  outgoing/incoming correctly.
- Fixture 69: headings differ by only about `2.04e-5` degrees near a tangency.
  The tangent-only order is `[9 incoming, 8 outgoing, 10 outgoing, 3 incoming]`.
  The arrangement's order is `[8 outgoing, 9 incoming, 10 outgoing, 3 incoming]`.
  Secants at parameters `1e-4`, `1e-3` and `1e-2` support the latter order.

These are boundary-pairing failures, not unsupported affine overlap mappings.
Using the existing arrangement order is a candidate repair, not an implemented
or fully tested fix.

### 79 and 113: boundary-side classification depends on sampling scale

The original arrangement passes closed-boundary validation. CSG's selected
boundary does not balance at its vertices: fixture 79 has four imbalanced
vertices; fixture 113 has two.

Keeping the graph identical and reducing only the tolerance passed to
`classify_boolean_edges` from `1e-6` to `1e-7` restores balanced selected edges
in both cases; `1e-8` and `1e-9` also balance. This changes both containment
sampling tolerance and side displacement (`16 * tolerance`); it does not
identify those two effects separately. The documented internal sampler does
not certify that the displacement avoids another nearby boundary.

This localizes the default failures to side classification. It does **not**
prove the resulting complete Boolean geometry correct, and reducing defaults
globally is not a proposed fix.

### 122 and 123: minimum-size filtering breaks closed-boundary topology

These operations use the same operand pair. The default graph itself fails
`validate_closed_boundaries` and has dangling boundary structure.

Instrumentation records a connecting cubic with length upper bound
`4.475995395897419e-6` being removed by the default `minimum_length = 1e-5`.
Its endpoints are approximately `(243.0290599968, 272.4534802583)` and
`(243.0290634164, 272.4534831463)`, belonging to distinct clusters. The discarded
connection leaves an unmatched end. Side-classification changes alone cannot
restore it.

This is a configuration-related geometry-filtering limitation contributing to
an actual default CSG failure; it is not an affine-parameterization rejection.
Lowering `minimum_length` to `1e-7` or `1e-9` instead produces
`ArrangementGraphError(ConstructionFailed)` for both operations. Those settings
are therefore not demonstrated workarounds. The deeper reason for that stricter
construction failure remains uninvestigated; it does not change the reproduced
default-failure classification. See `boolean-minimum-size-findings.json`.

## Seven adapter cases

Fixture 44 gives the two operands different fill rules; our binary CSG entry
point takes one common rule. Fixtures 26, 71, 73, 75, 77 and 78 use open-path
clipping or divided-result selection that the Boolean adapter does not model.
They remain unexecuted comparisons requiring appropriate adapters, not failures
of the union/intersection API or passing coverage.

## Reproduction

```sh
(cd test_paperjs && gleam build --target javascript)
node scripts/paperjs/investigate-boolean-errors.mjs
# Save the printed REPORT path; it refers to an instrumented temporary copy.
node scripts/paperjs/investigate-topology.mjs REPORT /tmp/topology-details.json
python3 scripts/paperjs/check-overlap-witnesses.py REPORT scripts/paperjs/boolean-overlap-witnesses.json
python3 scripts/paperjs/check-crossing-witnesses.py REPORT scripts/paperjs/boolean-crossing-witnesses.json
python3 scripts/paperjs/generate-boolean-remaining.py
gleam format test_paperjs/src/paper_boolean_remaining_probe.gleam
(cd test_paperjs && gleam run -m paper_boolean_remaining_probe --target erlang) > /tmp/boolean-remaining-erlang.log
python3 scripts/paperjs/collect-boolean-errors.py REPORT /tmp/topology-details.json /tmp/boolean-remaining-erlang.log
# Optional minimum-size experiment:
node scripts/paperjs/investigate-boolean-minimum.mjs REPORT /tmp/topology-minimum.json
```

The JS investigator copies compiled output to a fresh temporary directory and
only adds tracing and private exports there. It never edits production source
or the ordinary build. Instrumentation anchors are checked where unique; no
behavioral repair is applied. The generated Gleam probe prints errors rather
than asserting they should persist. These are diagnostic runs, not 69 passing
regression tests. The full release suite and figures were not rerun because no
production code changed.

## What remains before any parity claim

The 14 default failing comparisons need repairs or explicit, adequately
specified limitations. The eight crossing failures are newly confirmed by
this pass. Fixing one cause may expose another; repeat the whole saved Boolean
screen after any repair. The seven adapter cases, earlier intersection
parameter/crossing assertions, other unadapted assertions, diagnostic-to-test
promotion and unexamined upstream files remain outside this triage.
