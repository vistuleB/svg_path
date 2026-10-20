# Endpoint-search crossing roundoff — 2026-10-19

Baseline: `5fe1d99`. Production source unchanged in this investigation.
Follow-up to the remaining 1e-12-gap case in ENDPOINT-REPAIR-EXPERIMENT.md.

## Reproduction and cause

Rebuilt the audit probe and reran the native quarter-circle case on Erlang and
JavaScript. Both still return `CrossingMaxIterationsReached` for the 1e-12 gap.
The exact endpoint and larger-gap controls retain their previous results.

The failing subquery is the horizontal supporting line at y = 1 + gap against
the first arc, (1,0) to (0,1). Its actual separation is
1.000088900582341e-12. Internal coordinate matching requests a signed-line
acceptance tolerance of 1e-12.

`arc_line_classified_roots` permits a cosine outside [-1,1] when
`abs(cosine) <= 1 + tolerance / radius`. Here the rounded right-hand side is
1.0000000000010000889, admitting the candidate at t=1. The later geometric
validation correctly finds distance 1.000088900582341e-12 > 1e-12.
The candidate has kind Ambiguous, so rejection raises
`CrossingMaxIterationsReached` directly; this is not iteration exhaustion.

Thus this particular error is an inconsistent near-tangent admission check,
not evidence that endpoint matching must use the caller's tolerance as a capture
radius. The exact circles are disjoint, and an empty result is appropriate.

## Isolated experiment

`prepare-endpoint-roundoff-experiment.py` copies the generated JS build into
`/tmp/cavalier-endpoint-roundoff`. It replaces only the outside-cosine comparison
with `abs(constant) - radius <= signed_line_distance_tolerance`, comparing the
line's excess distance directly instead of adding a small allowance to one.
Production source is untouched.

The 16-case native endpoint matrix changes exactly two rows: the origin-centered
1e-12 gap now returns an empty result at both caller tolerances (1e-13 and 1e-9).
All other rows are unchanged, including the translated stricter-tolerance
certification error. A separate 20-query coordinate probe covers exact contact,
5e-13, 1e-12, 2e-12 and 1e-10 gaps and isolates the same failure.

This is a promising localized repair, not yet a production/full-suite result.
Before adoption, add direct arc-line and arc-arc regressions, test rotated and
scaled tangent controls, and run the portable crossing/intersection tests. Retain
final geometric verification; do not suppress arbitrary Ambiguous failures.

## Evidence

- `endpoint-minimal-current.json`, `endpoint-minimal-current-erlang.log`.
- `probe-endpoint-crossing-roundoff.mjs`, `endpoint-crossing-roundoff.json`.
- `prepare-endpoint-roundoff-experiment.py`.
- `endpoint-minimal-roundoff-experiment.json`.
- `endpoint-crossing-roundoff-experiment.json`.

Reproduction: build `scripts/cavalier/probe` for JavaScript, run the two probes,
then the preparation script and the copied probes under the printed /tmp path.
F# remains untouched.

## Production candidate

The outside-cosine admission check now compares excess distance directly.
Final geometric validation is unchanged. This does not turn caller tolerance
into an endpoint-capture radius or suppress unrelated iteration errors.

`svg_path_arc_line_roundoff_test.gleam` adds two portable regression tests:

- Disjoint quarter arcs with the 1e-12 gap, both input orders, at caller
  tolerances 1e-13 and 1e-9: empty results rather than iteration errors.
- Direct arc-line checks at scales 1/1024, 1 and 1024 and four quadrant
  orientations: exact contact, a gap inside the acceptance bound, the formerly
  failing just-outside gap, and a larger outside gap (48 cases).

Validation: `scripts/test-release` passed with 2,086 ordinary, 31 slow,
832 portable Erlang and 832 portable JavaScript tests (Gleam 1.18.1,
Node 24.10.0). Log: `endpoint-roundoff-test-release.log`.
`endpoint-minimal-roundoff-production.json` matches the isolated experiment
exactly across all 16 rows. The translated 1e-13 certification error is unchanged;
this repair does not claim to make unachievable tolerances succeed.
Formatting, `git diff --check`, and the Cavalier inventory validator pass.
`scripts/generate-published-figures` also passed (including its repeat ordinary
suite): all 13 README and 33 Gallery figures are byte-identical to the baseline.
See `endpoint-roundoff-figures.log` and `endpoint-roundoff-figure-comparison.json`.
The reduced endpoint-search iteration issue is repaired and validated. The
broader audit and F# migration remain open. Production repair and validation records are ready for the fix commit.
