# Remaining-failure checks

2026-10-14. These checks build on the centered single-search experiment with
original-coordinate endpoint discovery. Production source was restored afterward;
repository test expectations were never edited. No commit was made.

## Certification experiment

Replace the experimental filter of invalid original-coordinate candidates with
`list.try_map` that re-evaluates their original-coordinate midpoints, propagating
evaluation errors. Do not drop candidates. Existing public polishing and
certification then decide acceptance and report the usual
`InternalUncertifiedSegmentIntersection` error when appropriate. This reuses the
existing validation path instead of inventing an error or duplicating validation.

The complete experimental source patch is `certification-experiment.patch`.
The two previously failing error assertions now pass on both targets.

## Assertions previously hidden by snapshots

A standalone temporary project at `/tmp/svg-path-centered-checks` copies the
relevant original test modules. In those copies only:

- Shared endpoint raw/snapped count expectations: 4 -> 2.
- Off-center quadratic contact count: 4 -> 1.
- Flat cubic crossing count: 9 -> 6.
- Remove the loop requiring every original raw-search candidate to be retained,
  while retaining all its subsequent original-coordinate geometric assertions.

`temporary-test-changes.patch` records these exact diagnostic allowances; these
are not adopted test edits. All other assertions in the called functions remain
unchanged. `snapshot_diagnostics.gleam` records the seven function calls.

Completed from the temporary project:

- `gleam run --target erlang -m snapshot_diagnostics`: all seven checks pass.
- `gleam run --target javascript -m snapshot_diagnostics`: all seven checks pass.

These include exact shared-endpoint preservation, parameter separation, raw and
snapped geometric validity, known off-center/flat roots, thin-curve root recovery
in both orientations, overlap policy and both strict certification errors.
Logs are saved here. This is a targeted runner, not a full-suite pass; the
certification change has not yet had a full release-profile rerun.

## Candidate inventories

`candidates.json` compares baseline and experimental raw results on JavaScript.
The original binary64 controls and parameter values were evaluated with
80-digit Decimal arithmetic to inspect true residuals beneath ordinary binary64
rounding. Reported high-precision values are curve-to-curve separations, not
curve-to-reported-midpoint distances.

| Fixture | Baseline count | Experiment count | Largest baseline separation | Largest experimental separation |
| --- | ---: | ---: | ---: | ---: |
| Shared endpoint | 4 | 2 | 2.24e-14 | 6.55e-17 |
| Flat cubic crossing | 9 | 6 | 7.77e-14 | 6.17e-20 |
| Off-center quadratic contact | 4 | 1 | 9.36e-14 | 5.65e-17 |

Shared endpoint: exact (1,0) survives. The other experimental pair is approximately
(0.999999711553717, 3.226404842343157e-12), near that stationary endpoint.
The full raw/snapped endpoint assertions pass.

Flat crossing: exact (0.5,0.5) survives. The candidate span contracts from roughly
[0.499969,0.500034] to [0.4999997561,0.5000003136]. Its exact single-root argument
is unchanged: both x polynomials are identical and strictly increasing, while
the y polynomials are opposite cubes centered at 0.5.

Off-center contact: the remaining pair is approximately
(0.37000000345695266,0.6300000034569526), about 3.46e-9 from the intended contact
parameters. The baseline four candidates are clustered around the same intended
contact; the remaining candidate has substantially smaller residual. This is
not a proof of exact root multiplicity for the rounded binary64 control points.

## Conclusion

No additional assertion failure was uncovered behind the four snapshot/preservation
failures. The count changes are consistent with tighter candidate clusters, not
a demonstrated loss of the tested contacts. Exact preservation of every candidate
from a second original search is inapplicable to the replacement design; the
known-root and geometric checks remain relevant and pass. Both certification
regressions are resolved by restoring the existing error-producing certification
path in the diagnostic variant. A full rerun of that variant remains required
before claiming the overall experiment passes or adopting updated snapshots.
