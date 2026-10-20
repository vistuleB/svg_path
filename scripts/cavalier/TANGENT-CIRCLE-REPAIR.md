# Circular intersection candidate — 2026-10-20

Follow-up to `TANGENT-ARC-SUBDIVISION-PERFORMANCE.md`, baseline `90c6565`.
Production candidate and regressions are uncommitted. F# remains deferred.

## Calculation

After the existing shared-endpoint circle shortcut, distinct circular SVG arcs
can use `ellipse_precision.circle_intersections`. Other ellipses retain the
existing solver. The helper reuses internal double-double arithmetic rather than
adding a dependency or changing public options/errors.

- Subtract a local origin in double-double arithmetic, then scale by a power of
  two. Keep endpoint-derived center corrections through the circle intersection
  calculation; rounding centers first loses important near-tangent information.
- For squared center separation D, squared radii A and B, evaluate
  H = 4*A*D - (A-B+D)^2 with extra precision. Positive H gives two circle roots;
  definitely negative H gives no roots. No proximity-based tangent snapping.
- Project each circle root onto both finite arcs to recover parameters and reject
  roots outside their angular spans. Interior projection disagreement falls back.
- Certify retained candidates against the public segment evaluator and the
  caller's tolerance before accepting the shortcut. Certification failure falls
  back, rather than weakening tolerance or returning an uncertified result.
- Keep the general solver for near-concentric centers, unresolved cancellation,
  numerical range limits, and failed projections. Existing overlap prechecks and
  exact shared-endpoint behavior remain in place.

Arithmetic guards are deliberately separate from geometric tolerance. The
near-concentric squared-distance threshold is 1e-16 relative to summed squared
radii (similar to the existing shared-endpoint shortcut's 1e-8 distance guard).
The discriminant and radius-correction guards use 1e-28 relative cancellation:
roughly four orders above double-double relative rounding (~1e-32). This is a
conservative fallback heuristic, not a formally proved error bound. Relative
radius/range limits also route extreme configurations through the existing solver.
Exact/near-uncertain semicircle correction and tangent discriminants fall back;
the candidate does not decide their sign using a loose epsilon.

## Regression coverage

`svg_path_circle_intersection_precision_test.gleam` is included in portable tests:

1. Two distinct near-tangent roots compared with the independent 80-digit circle
   oracle, in both orientations (coordinate error below 1e-10).
2. Nearby disjoint and crossing controls, with segment-evaluation checks.
3. Full CC01640 native eight-line reduction and reversal: one contour, expected
   area/length, no more than 32 segments. The fragment bound catches subdivision
   growth without asserting machine-dependent wall time.
4. Nearby controls across scales 1/8, 1, 8, translations, arbitrary circular-axis
   rotations, and traversal reversal.

The first portable Erlang trial passed 839 tests and failed one existing test
requesting tolerance 1e-16. Its projected point passed the shortcut's distance
check but public evaluation differed by 1.42e-14. Adding the explicit certificate
and fallback repaired this; no tolerance assertion was relaxed. The next
portable run passed 843 tests on each target. A final transformation regression
was then added, and full release validation was started.

## Initial diagnostic results

The initial candidate's CC01640 replay completes in about 1.17 seconds with
18 segments and matching area/length. The isolated original two-arc arrangements
finish in about 73 ms in either orientation, compared with the previous
15-second screening timeouts. These are single diagnostic observations, not
controlled benchmark medians. The initial numbers precede the final conservative
fallback refinements; final validation/replays are recorded below when complete.

No commit or F# port is implied by retaining this candidate for testing.


## Broader captured replay

After the final source guards, replayed all 402 captured offset/shape-offset
records with one JS worker and a 30-second per-case limit:

```sh
CAVALIER_CASES=tangent-circle-all-offset-cases.json CAVALIER_RESULTS=tangent-circle-all-offset-results.jsonl CAVALIER_WORKERS=1 CAVALIER_TIMEOUT_MS=30000 node scripts/cavalier/compare-captured.mjs
```

Results: 237 property matches, 153 discrepancies, six scope records, six existing
errors, zero timeouts. No originally matching record or match from the preceding
192-record replay becomes flagged. The eight former timeouts complete in
824–922 ms. Four Preserve variants match directly; four Separate variants retain
one contour instead of two, with agreeing summed area/length and combined bounds.
They remain a grouping-policy comparison, not four remaining performance failures.
Other known/unresolved catalogue entries are not closed by this replay.
See `tangent-circle-all-offset-summary.json` and raw JSONL records.


## Full release validation

`PATH=/Users/jpsteinb/.nvm/versions/node/v24.10.0/bin:$PATH scripts/test-release`
completed with exit 0: 2,098 ordinary tests, 31 slow tests, 844 portable Erlang
and 844 portable JavaScript tests. The four new regressions are included.
`gleam format --check` and `git diff --check` passed. Full log:
`tangent-circle-test-release.log`. Earlier failed/revised portable trials are
retained separately; the 1e-16 failure was repaired by fallback, not by weakening
its existing test.


## Published figures and disposition

`PATH=/Users/jpsteinb/.nvm/versions/node/v24.10.0/bin:$PATH scripts/generate-published-figures`
completed with exit 0, including another passing 2,098-test ordinary run.
All 47 published SVGs regenerated: all 34 Gallery files and 12 of 13 README files
are byte-identical. Only `band_cusp_trimming.svg` differs: three panel-centering
coordinates interchange -2.0 and -1.9999999999999998 (2.22e-16). Path data and all
other content are identical, verified by normalizing that number spelling and
comparing complete SVG text. No published asset tag is moved or pushed.

Evidence: `tangent-circle-published-figures.log` and
`tangent-circle-figure-comparison.json`. Chat preview is under
`examples/debug/tangent-circle-band-cusp-trimming.svg`.

Recommendation: retain the correction. No public API, options or error changes.
All requested validation passes; candidate, tests and investigation remain
uncommitted. F# port is deferred until the Gleam audit is complete.
