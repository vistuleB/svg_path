# Endpoint tolerance repair experiment — 2026-10-18

Baseline: `3e8aa8c`. Production source unchanged during this investigation.
Follow-up to CC01751–CC01753 in ENDPOINT-BOOLEAN-TRIAGE.md.

## Reduced native case

Two circular quarter-arcs of radius 1, rotation 0, small arc, positive sweep:

- `(1,0)` to `(0,1)`;
- `(0,1+gap)` to `(-1,2+gap)`.

At the default intersection tolerance 1e-9:

| gap | Baseline result |
| --- | --- |
| 0 | Endpoint intersection (1,0) |
| 1e-12 | `CrossingMaxIterationsReached` |
| 1e-10 | Empty |
| 2e-9 | Empty, expected |

The native Erlang probe reproduces all four outcomes. No upstream adapter or
bulge-to-arc conversion is involved. The JS probe additionally tests translation
by (1000,1000), and a stricter caller tolerance of 1e-13. At translated coordinates,
the 1e-12 gap succeeds under the default tolerance: the internally computed
roundoff allowance admits the endpoint there but not near the origin.

This is approximate endpoint coincidence under the caller's documented geometric
tolerance, not a missed exact mathematical intersection. Direct point-parameter
matching at the public tolerance finds the endpoint for both sub-tolerance gaps.

## Isolated experiment

`prepare-endpoint-experiment.py` copies the audit probe's generated JavaScript
build into `/tmp/cavalier-endpoint-experiment`. In that copy only, it changes the
two endpoint-candidate call sites to use `options.tolerance`:

- ordinary `elizabeth_beam_with_endpoint_seeds`;
- original-coordinate endpoint seeding before polynomial normalization.

The stricter search/refinement tolerance is unchanged. The script asserts exactly
two replacements; it does not modify source or the ordinary generated build.

Results:

- Both sub-tolerance quarter-circle gaps return endpoint (1,0), at original and
  translated coordinates, under the default tolerance.
- Exact endpoint control still passes; gap 2e-9 remains rejected.
- All three original Cavalier records recover their expected endpoint pair.
- This is a focused JS experiment, not an adopted repair or a full-suite result.
  Tighter-tolerance cases can still return certification/refinement errors;
  those are recorded rather than claimed fixed.

Recommendation: use caller tolerance for endpoint coincidence at both call sites,
retain stricter internal root refinement, and keep final certification. Validate
with permanent regressions and the broad intersection/CSG suites before adoption;
additional admitted endpoint candidates may affect downstream topology.

## Reproduction and evidence

- `probe-endpoint-minimal.mjs`, `endpoint-minimal.json`: native JS baseline matrix.
- `probe/src/endpoint_tolerance_audit_probe.gleam`,
  `endpoint-minimal-erlang.log`: native Erlang reduced cases.
- `prepare-endpoint-experiment.py`: isolated generated-build experiment.
- `endpoint-minimal-experiment.json`: same JS matrix after experimental change.
- `endpoint-tolerance-experiment.json`: original three cases after the change.

Run the audit probe's JS build first, then the preparation script and the two
copied probes under `/tmp/cavalier-endpoint-experiment`. Original probe inputs and
outputs remain separate. F# untouched.

## Broader investigation — do not adopt the blanket change

The initial recommendation above was based only on focused successes. The broader
investigation exposes a policy conflict and supersedes that recommendation.

### Matrix probe

`probe-endpoint-matrix.mjs` checks 108 combinations of circular arcs, quadratics,
cubics, scales 0.001/1/1000, translations 0/1000, exact/inside/outside-tolerance
endpoint gaps, and forward/reversed traversal. Raw results are
`endpoint-matrix-baseline.json` and `endpoint-matrix-experiment.json`.

Under the exploratory expectation that every endpoint pair within caller tolerance
must appear, baseline has 30 missing-pair cases plus six certification errors.
The experiment has no missing pairs and two certification errors. Those two are
unchanged arc cases at scale 0.001 translated to (1000,1000), with actual gap
2.04636e-12 and tolerance 1e-12. Certification errors at unachievable tolerance
are documented behavior, not automatically bugs. This probe's expectation is
stronger than the published API guarantee and is not an adopted regression suite.

### Existing FL006 regression conflicts

A source-level candidate was tested in a separate directory under `/tmp`, using
`endpoint-candidate.patch`. Main-workspace production source was not edited.
The existing `fl006_endpoint_arc_overlap_does_not_hide_crossing_test` fails:
it expects one isolated interior crossing, while the candidate returns four:

- endpoint pair (0,0), distance between evaluated points 1.02352e-7;
- two endpoint-to-near-endpoint pairs, distance about 1.44778e-7;
- the original interior crossing, retained at parameters about (0.449123,0.449124).

All four pass the unchanged final certification at caller tolerance 5e-7.
The three extras have midpoint-to-curve distances about 5.12e-8–7.24e-8.
`probe-endpoint-fl006.mjs` and `endpoint-fl006-experiment.json` record this.
This is changed candidate inventory, not loss of the true crossing. The existing
regression must not simply be weakened to accept the proposed behavior.

### Contract correction and recommendation

The module docs explicitly describe a bounded search, no completeness proof,
and potentially several acceptable candidates near a contact. The option docs
require returned candidates to satisfy caller tolerance; they do not explicitly
promise that all endpoint pairs inside that tolerance are reported. Treating
that tolerance as an endpoint capture radius was an additional assumption.

Therefore the earlier wording "wrong tolerance" / straightforward native bug
was too strong. The evidence establishes scale/translation-sensitive approximate
endpoint behavior and a robustness/API-policy question, not a proven violation
of an explicit endpoint-completeness guarantee. This correction also applies to
the preliminary classification in ENDPOINT-BOOLEAN-TRIAGE.md.

Recommendation: retain current production behavior for now and record this as an
endpoint-policy decision. Do not silently change all endpoint seeding to public
tolerance, raise an arbitrary roundoff constant to fit the three fixtures, or
suppress the extra candidates without a defined rule. A future change needs to
specify whether tolerance is only an acceptance bound or also an endpoint capture
radius, then reconcile the FL006 expectation and downstream topology tests.
The reduced 1e-12-gap iteration error remains recorded as a numerical robustness
case; this experiment does not establish a separate, policy-neutral repair for it.

### Completed suite checks

- Unchanged main workspace, `scripts/test-all`: 2,053 fast + 31 slow passed.
- Isolated candidate, `scripts/test-fast`: 2,052 passed, one failure (FL006).
  The candidate slow profile was not run after the fast profile rejected it.
- An earlier copied-workspace attempt additionally lacked the
  `examples/debug/package_title.svg` fixture, producing three setup failures.
  After copying that input, the complete fast rerun above isolated the one real
  behavioral difference. No setup failures are counted as candidate regressions.
- Raw final suite logs: `endpoint-baseline-test-all.log` and
  `endpoint-candidate-test-fast.log`.
- No full portable-suite or figure-generation claims are made for this candidate.

## Semantics resolved — 2026-10-19

The user clarified that satisfying intersection tolerance is necessary, not
sufficient, for reporting an intersection. It is a numerical acceptance bound,
not a proximity rule or endpoint snapping/merging radius. Missing approximate
endpoint matches are therefore not confirmed bugs. The blanket widening is
rejected; the smaller-gap iteration error remains a separate robustness concern.

The Gleam module docs, `IntersectionOptions.tolerance` field docs and README now
state this explicitly. They retain the warnings about approximate candidates,
bounded search and lack of exact root certification. No solver behavior changed.
Include this clarification when the deferred F# audit port is performed.
