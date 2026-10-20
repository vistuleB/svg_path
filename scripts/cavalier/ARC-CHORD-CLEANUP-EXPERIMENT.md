# Arc cleanup: one chord or unchanged — 2026-10-20

Production baseline `99ff1694`. User-requested change; initial experiment and
subsequent adoption checks are recorded separately below.

`degeneracy.segment_linearize_if_degenerate` no longer flattens an arc into a
polyline before testing its thinness. It validates the SVG arc, computes a
conservative whole-arc endpoint-chord bound, and returns exactly one Line if
that bound is within tolerance; otherwise it returns None. The normalizer's
caller then retains the arc. Invalid SVG arc handling is unchanged. Valid arcs
at zero tolerance return None rather than entering the positive-tolerance
polyline flattener.

For sweep <=180 degrees the bound is R*(1-cos(sweep/2)), with R the larger
ellipse radius. It is evaluated as 2*R*sin(sweep/4)^2 to avoid cancellation for
short sweeps. For larger sweeps the bound is 2*R. This is conservative: some very
flat eccentric ellipses remain unchanged even when a tighter geometric test
could certify their chord. The candidate never replaces an arc with several
lines. Bézier behavior and the separate whole-window normalization policy are
unchanged; this does not by itself repair reversal loss discussed in
`SHORT-RUN-NORMALIZATION-INVESTIGATION.md`.

## Existing-suite conflict

The ordinary suite reports 2099 passes and one failure:
`svg_path_svg_arc_normalization_test.valid_narrow_arc_can_still_be_simplified_test`.
That test explicitly requires `Some(lines)` with more than one line. Its arc
has radii (0.0001,10), endpoints (0,0) and (0,10), and the large-arc flag. Its
bounds extend from y=-5 to y=15: it is narrow, but travels five units beyond
both ends of its endpoint chord. Keeping this arc is appropriate for the new
single-chord contract; replacing it with its chord at tolerance 0.001 would
lose substantial traversal. The old assertion was left unchanged for the initial run to report the
requested old-suite comparison honestly.

The canonical `scripts/test-release` command stops after this ordinary-suite
failure. Slow and both portable profiles are subsequently run individually,
sequentially, to collect all remaining outcomes. Final results recorded below.

## Focused checks

`gleam run -m arc_chord_cleanup_probe` in `scripts/cavalier/probe`:
- radius-one arc with chord 0.00003: one line at tolerance 0.001;
- unit quarter circle: None at tolerance 0.001;
- half ellipse with radii (10,0.0001): conservatively None at tolerance 0.001;
- all three valid arcs: None at zero tolerance.

See `arc-chord-cleanup-erlang.log`. During the initial experiment no figures
were regenerated and no tests were changed. F# remains deferred.

## Completed old-suite results

| Command | Passed | Failed |
| --- | ---: | ---: |
| `scripts/test-release` (stopped after ordinary profile) | 2099 | 1 |
| `scripts/test-slow` | 31 | 0 |
| `scripts/test-portable erlang all` | 845 | 1 |
| `scripts/test-portable javascript all` | 845 | 1 |

All three failures are the same existing multi-line arc expectation described
above. No other old test failed. Node 24.10.0 was prepended to PATH for all
commands. Logs are `arc-chord-{release,slow,portable-erlang,portable-javascript}.log`;
sequential command exit codes are in `arc-chord-test-outcomes.json`. Tests remained
unchanged in those initial runs. Format and diff-whitespace checks pass. This is not an all-green
release validation; the intentional contract conflict remains visible.

## Adoption checks after requested figure regeneration

Updated the one intentionally conflicting regression to
`narrow_major_arc_is_not_replaced_by_a_chord_test`. It now checks None from
the helper and unchanged geometry through the public normalizer. This changes
the explicitly retired multi-line contract assertion; no other old test was
weakened or removed. Existing short-arc tests check successful one-line cleanup.

Completed commands with Node 24.10.0 prepended to PATH:

- `scripts/generate-published-figures`: ordinary suite 2100 passed, no failures;
  all 34 Gallery and 13 README figures regenerated. All 47 are byte-for-byte
  identical to the saved pre-change outputs.
- `scripts/test-portable all all`: 846 passed on Erlang and 846 on JavaScript,
  no failures.
- The earlier `scripts/test-slow` run on this production change passed all 31;
  the subsequent edit changed only the ordinary regression's expectation.

See `arc-chord-figures.log`, `arc-chord-portable-final.log`, and
`arc-chord-figure-comparison.json`. Format/diff checks and audit-record validation
pass. No new figure assets or F# changes.
