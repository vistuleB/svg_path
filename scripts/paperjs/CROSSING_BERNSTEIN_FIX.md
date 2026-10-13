# Bernstein recovery for rejected line-crossing roots

## Scope

Commit `1b78ea6` separately normalizes signed-zero polynomial candidates before
sorting/deduplication. It retains the stronger derivative-multiplicity evidence
when an endpoint and derivative root coincide. The new regression failed on
Erlang before that fix. Afterward, `scripts/test-fast` passed 1,916 tests and
`scripts/test-portable` passed 658 tests on each target.

The subsequent Bernstein change is deliberately restricted to **failed
Bézier–line queries**. A successful original query is returned unchanged. The
power-basis solver, its coefficient-relative thresholds, classified-root API,
arc solver, general curve–curve refinement and caller tolerances are unchanged.
There is no new user-facing option or type.

When the original query reports `CrossingMaxIterationsReached`:

1. Project the Bézier controls relative to the query line's origin.
2. Return an empty result if all projected controls lie beyond the geometric
   tolerance on the same side of the line. The control polygon proves separation.
3. Otherwise isolate scalar roots in Bernstein form: recursively split at
   derivative roots, retain exact hits and bisect strict sign changes without
   treating coefficient-relative small values as zeros. Close distinct roots
   are not merged by a fixed parameter tolerance.
4. Validate every returned parameter through the existing segment evaluation,
   using the original geometric tolerance. Unvalidated roots are not returned.

Each bisection uses the configured iteration limit. An empty root list without
control-polygon separation does not establish absence of a tangent contact, so
that case retains the original error. Arc errors also retain their original
behavior. The fallback is not a claim of complete root certification for every
ill-conditioned input, nor a replacement for all successful root queries.

## Regression coverage

`svg_path_crossing_endpoint_test.gleam` is already in the portable selection.
The new tests include:

- All five distinct projected cubic witnesses behind the eight original Boolean
  failures, checking root count, parameters and geometric residuals.
- Both reduced failure families in both orientations; the interior-plus-endpoint
  pair also runs at scales 0.001, 1 and 1,000.
- Three distinct scalar roots and a genuine repeated/tangent root.
- The later 128/129 query whose positive control polygon proves no root exists.

Existing endpoint, tangent, two-crossing and iteration-limit regressions remain.
The native pre-fix probes and experiment are archived in
`CROSSING_ROOT_INVESTIGATION.md`; they are historical diagnostics, not passing
post-fix tests.

## Validation

Completed against the current worktree, including pending affine/release work:

- `scripts/test-portable`: **663 Erlang and 663 JavaScript tests passed**.
- `scripts/test-release`: **1,921 fast, 26 slow, 663 Erlang portable and
  663 JavaScript portable tests passed**.
- Full 178-case Boolean screen with a 30-second per-case limit:
  **107 sampled matches, 63 library errors, one timeout, seven API adapters**.
- All **104 previous sampled matches remain matches**, with no sampled geometry
  mismatch or harness error. Only the eight previously identified scalar-root
  failure cases change outcome/error payload.
- `scripts/generate-published-figures`: completed successfully, including its
  1,921-test fast prerequisite. All **13 README and 33 Gallery figures** were
  regenerated and are byte-for-byte identical to the pre-change baseline.
  XML, explicit dimensions/viewBox, non-finite-value checks and equality of
  promoted Gallery files with generated output all passed.
- Formatting of changed Gleam files and `git diff --check` passed.

Reproduce the saved screen after building the portable JS target:

```sh
PAPER_AUDIT_TIMEOUT_MS=30000 PAPER_AUDIT_REPORT=./boolean-screening-after-bernstein.json node scripts/paperjs/probe-booleans.mjs /tmp/svg-path-paper-audit/node_modules/paper
```

## Remaining blockers

| Fixtures | Current outcome |
| --- | --- |
| 103, 168, 169 | Sampled geometry matches; full Boolean checks remain diagnostic, scalar witnesses are permanent portable tests |
| 128, 129, 130, 131 | Original scalar failures cleared; now `NonAffineOverlapCorrespondence`, with these newly exposed overlap witnesses awaiting classification |
| 107 | Both scalar roots recovered; complete CSG operation exceeds the screen's 30-second limit |

The prior temporary experiment's CPU profile places 107's later cost in
curve-pair intersection processing, including `spatial_diversity_pass`.
The actual production screen also times out in CSG; this is not a successful
Boolean repair or a claim of nontermination. This change allows execution to
reach that later expensive work instead of returning the earlier root error.

The previously understood 55 overlap limitations and four topology/filtering
failures remain. The audit is not complete, and these results are not a release
qualification or a claim of Paper.js parity.
