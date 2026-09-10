# Current follow-ups

Updated 2026-09-10. Every concrete geometry reproducer in the previous audit
ledger has a fix. The complete findings, resolutions, and illustrations are
preserved in [the resolved audit history](historical_docs/RESOLVED_ISSUES.md).

## Intersection test expectations

Four tests still demand one candidate where the numerical residual/separation
contract admits several. Review their assertions without weakening geometric
residual, parameter separation, or endpoint-preference checks:

- `elizabeth_beam_flat_crossing_completes_with_explicit_loss_test`
- `segment_intersections_prefers_shared_endpoint_over_near_endpoint_minimum_test`
- `production_off_center_kissing_quadratics_test`
- `flat_cubic_crossing_regression_test`

Latest verification, after the package documentation pass:
`scripts/test-fast`: **1602 passed, 4 known failures**. No expectations were
changed. This is not a passing release verification.

## Numerical limitation

Elizabeth's bounded beam search and candidate selection remain heuristic,
not a proof of finding every mathematical root. No additional failing geometry
case is established by the resolved audit. Current policy and historical
measurements are in [ELIZABETH_SOLVER.md](examples/debug/ELIZABETH_SOLVER.md).

Older test counts and proposed algorithms belong to their recorded checkpoints;
see [historical_docs](historical_docs/README.md), not those counts, for context.
