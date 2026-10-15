# FB007: closest-pair stack overflow investigation

> Closure status (2026-10-15): Fixed in `b3bb1a9`; full release validation and the final captured-query rerun pass. See FINDINGS.md for the remaining runtime/default-accuracy distinction.
> The dated investigation below preserves the observations and intermediate status at that time.

## Minimal reproducer and independent answer

```text
Cubic: (0,0), (0,1), (1,1), (1,0)
Line:  (0,1), (1,1)
```

Call `distance.segment_segment_closest_pair` with defaults.
The cubic has `y(t) = 3t(1-t)`, whose maximum is `3/4` at `t=1/2`.
Its x coordinate there is `1/2`, inside the horizontal line. The exact closest
pair is therefore `(0.5,0.75)` / `(0.5,1)` with distance **0.25**.

The unchanged JavaScript library throws `RangeError: Maximum call stack size
exceeded`. The same public call on Erlang succeeds with precisely those
parameters, points, and distance. Large coordinates are not required.

## Cause

In `src/svg_path/intersections.gleam`,
`collect_projection_terminal_windows_generation` processes an explicit list of
search windows. It calls `inspect_projection_window` through
`use ... <- result.try(...)`, then recurses on the rest of the list inside that
callback. The generated JavaScript therefore recursively calls the collector
through `result.try`; it cannot compile that branch into its normal tail-call
loop. Each inspected window retains callback/collector stack frames.

The empty-generation transition already compiles into a loop, but that does not
unwind the frames accumulated by the callback branch. Thus limiting geometric
subdivision depth does not bound JavaScript call-stack usage. Instrumented copies
failed after roughly 8,230 inspections, while the unit reproducer still had 34
of the configured 48 subdivision levels remaining. The exact overflow threshold
is runtime- and instrumentation-dependent, not a regression-test expectation.

The overflow's top frame can be in equality, subdivision, or bounding-box code.
Those operations are where the exhausted stack finally fails; the repeated
collector/result.try frames identify the accumulation source.

## Narrow candidate fix (not applied)

Replace the collector's `use result.try` with an explicit `case` on the inspection
result. Return an error immediately in the Error branch. In the Ok branch,
destructure the updated accumulators and call the collector directly in tail
position. Preserve the window order, generation order, current best, depth,
terminal criteria, and numeric refinement unchanged.

This is a control-flow repair; it needs no API or tolerance change. A production
patch should be compiled to verify that the JavaScript collector actually becomes
a loop. Adjacent recursive helpers should only be changed if evidence requires it.

## Disposable experiment

`prepare-stack-experiment.py` copies the compiled JavaScript dependency tree to
`/tmp/flobezier-stack-experiment`, instruments inspection counts, and writes an
experimental collector with iterative accumulator updates. This edits neither
repository production sources nor the normal compiled dependency tree.

The original and iterative copies were exercised with the same five fixtures in
`stack-investigation.mjs`, each in a worker with a 10-second limit:

- Original: all five throw stack overflow (original upstream input, translated
  input, integer-gap variant, unit symmetric case, ten-unit symmetric case).
- Iterative trial: the unit case returns the exact expected answer after 18,527
  inspections and 468 terminal windows; roughly 0.25 seconds on this run.
- Iterative trial: translated upstream input returns normally after 562,325
  inspections, roughly 9.9 seconds on this run.
- Original upstream coordinates, integer-gap, and ten-unit cases exceed that
  diagnostic 10-second limit in the trial. These are timeouts, not proof of
  nontermination or successful completion. A separate 30-second upstream-input
  trial is recorded in `stack-upstream-trial.json`: it completes successfully in
  about 9.9 seconds, returning distance 0.0010000414522580048 after 562,325
  inspections. Timing variability explains why this run fits just below the
  earlier limit; these are observations, not benchmark guarantees.

The search breadth can be substantial even after the stack problem is removed.
Performance changes are a separate question; do not change pruning or search
order as part of the narrow stack repair without additional validation.

## Completed checks and scope

- `node scripts/flobezier/stack-investigation.mjs`: five diagnostic fixtures on
  unchanged JavaScript; all reproduce the exception.
- `gleam run -m closest_pair_stack_probe` in `scripts/flobezier/probe`: one
  Erlang diagnostic, succeeds with distance 0.25. Log: `closest-pair-erlang.log`.
- Instrumented and iterative worker sweeps: `stack-instrumented.json` and
  `stack-iterative-trial.json` retain inputs, outputs, counts, and timeouts.

No production fix, commit, full-suite run, or claim of release validation. The
regression to add when implementing is the unit cubic/line above on both targets,
asserting successful Result, parameters 0.5, and distance 0.25. The larger upstream
fixture can remain an audit/slow check so ordinary testing does not inherit its
current search cost.

## Production implementation and targeted validation

The collector now uses an explicit case and a direct tail call in the Ok branch.
The generated JavaScript was inspected: it updates loop state rather than calling
back through result.try. Search order and numerical criteria are unchanged.

Added `test/svg_path_flobezier_closest_pair_test.gleam`, including the minimal
unit case in both operand orders, and selected it in `test_portable/modules.txt`.

A temporary standalone package copied the repository test modules and called only
12 selected test functions: eight geometry-level closest-pair tests, the
near-parallel scale-invariance test, two v3 projection/options-contract tests,
and the new regression. Commands from `/tmp/svg-path-closest-pair-targeted`:

- `gleam run -m closest_pair_targeted --target javascript`: **12 passed**.
- `gleam run -m closest_pair_targeted --target erlang`: **12 passed**.

Per-test names/results are retained in `closest-pair-targeted-javascript.log`
and `closest-pair-targeted-erlang.log`. The original upstream query was also
rerun against this production build and succeeds, returning distance
0.0010000414522580048 in approximately 10.1 seconds (`stack-production-fix.json`).
The metrics field in that result is zero because production was not instrumented.

Formatting and `git diff --check` pass. The full suite was deliberately not run,
as requested. No commit was created. Earlier failing reports above remain as
historical evidence against the pre-fix revision.
