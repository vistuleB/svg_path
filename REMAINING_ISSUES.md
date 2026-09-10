# Current follow-ups

Updated 2026-09-10. Every concrete geometry reproducer in the previous audit
ledger has a fix. The complete findings, resolutions, and illustrations are
preserved in [the resolved audit history](historical_docs/RESOLVED_ISSUES.md).

## Intersection test expectations — resolved

The four tests now check known intersections, geometric residuals, parameter
separation, and exact endpoint retention where applicable. Explicit numerical
candidate-count snapshots remain to flag changes in either direction; they are
not assertions of mathematical root multiplicity:

- `elizabeth_beam_flat_crossing_completes_with_explicit_loss_test`
- `segment_intersections_prefers_shared_endpoint_over_near_endpoint_minimum_test`
- `production_off_center_kissing_quadratics_test`
- `flat_cubic_crossing_regression_test`

Release verification for 0.46.0 (including ordered bounding polygons):
`scripts/test-release`: **1612 fast tests and 26 slow tests passed**.
`scripts/generate-published-figures` regenerated all **29 Gallery figures and
9 README figures**. `gleam docs build` and `gleam export hex-tarball` succeeded.

## Numerical limitation

Elizabeth's bounded beam search and candidate selection remain heuristic,
not a proof of finding every mathematical root. No additional failing geometry
case is established by the resolved audit. Current policy and historical
measurements are in [ELIZABETH_SOLVER.md](examples/debug/ELIZABETH_SOLVER.md).

Older test counts and proposed algorithms belong to their recorded checkpoints;
see [historical_docs](historical_docs/README.md), not those counts, for context.
