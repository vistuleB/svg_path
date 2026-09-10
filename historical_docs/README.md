# Historical documentation

These records preserve earlier designs, experiments, and audit checkpoints.
They are not current API contracts or executable instructions for main.
Source line numbers, test counts, and statements of unresolved work can be
superseded. Paths in prose and commands are relative to the repository root
unless explicitly stated otherwise. Markdown image links have been adjusted
for this directory; the original drawings remain in `examples/debug/`.

Current references: [README](../README.md), [current follow-ups](../REMAINING_ISSUES.md),
[development notes](../NOTES.md), and the source module documentation.

## Plans and notes

- [Arrangement and offset proposal](GENIUS_PLAN.md): superseded construction plan.
- [Development notes before cleanup](NOTES_BEFORE_CLEANUP.md): preserves removed
  wishlist items and outdated implementation observations.

## Audit history

- [Original module review](V1_REVIEW.md)
- [First actionable fixes](V1_REVIEW_ACTIONABLE.md)
- [Visual explanations](V1_REVIEW_VISUAL.md)
- [Resolved issue ledger and drawings](RESOLVED_ISSUES.md): subsequent fixes and
  the evolution of intersection and offset logic.

## Numerical experiments

- [Projection refinement experiments](PROJECTION_REFINEMENT_EXPERIMENTS.md)
- [Residual-window intersection experiment](IX2_EXPERIMENT.md): applies only to
  its named historical checkout, not current main. Its patch and fixtures remain
  in `examples/debug/`.

The retained small-loop switch and current Elizabeth policy are documented
under `examples/debug/`; their earlier measurements are labeled historical.
