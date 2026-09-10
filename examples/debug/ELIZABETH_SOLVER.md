# Elizabeth: production integration and experiment history

## Current production policy

- Generic curve pairs use breadth-first Elizabeth; analytic Line dispatch is
  unchanged. Edward/Henry remain behind a private comparison switch, not an
  automatic fallback from Elizabeth.
- Residual cutoff: min(caller tolerance, 1e-13); terminal parameter widths:
  1e-9; final parameter-space deduplication: 1e-7.
- Independent endpoint-to-segment candidates protect endpoint matches from
  beam loss. Curve evaluations used for ranking are cached by exact parameters.
- Window scoring uses four corners and midpoint, plus the actual curve
  residual at a chord-predicted crossing when present. The five-sample
  crossing experiment was removed: it demonstrated no speed benefit.
- Each bucket starts with 500 slots. Decay starts once at the first generation
  with >1000 enclosure survivors, or generation 5, whichever is earlier.
  It reaches 12 slots per bucket at absolute generation 12, then stays there.
- Coarse-to-fine spatial diversity starts at 0.5 and is shared between window
  selection (floor zero) and final candidates (floor 1e-7). The search is
  heuristic and does not certify mathematical root completeness or uniqueness.

The four existing candidate-count test failures remain intentionally visible.
This document retains earlier experiments below; their settings are historical,
not a description of the current default.

## Original depth-first experiment

The internal `intersections.experimental_curve_intersections` entry point
selects `Henry`, `Edward`, or `Elizabeth`, without fallback or Line dispatch.
The initial experiment left production on Edward with Henry fallback. The
later integration trial below enables Elizabeth in production; Henry and
Edward remain available through the private routing switch.

- Henry: original curve-pair distance-minimization descents.
- Edward: window search that can stop after finding a candidate.
- Elizabeth: exhaustive depth-first window refinement to parameter resolution.

Elizabeth reuses the 8×8 initial grid, regular 3×3 subdivision and enclosing
polygons. Nonterminal windows perform enclosure rejection and subdivision only:
no candidate evaluation or propagation. When both parameter widths are at most
`1e-9`, the terminal solver tries the four corners, midpoint, and chord
crossing/closest-pair seed. Corners include original endpoint pairs.

Each seed is checked geometrically and, if needed, corrected with at most eight
analytic tangent-line Newton steps. Escaped or unchanged steps are rejected;
there is no clamping or relocation into another window. Ill-conditioned tangent
pairs stop correction, not subdivision elsewhere. Successful candidates are
collected only here. There is no near-known-root suppression or exclusion box.

Candidate distance must be at most `min(options.tolerance, 1e-12)`.
After successful exhaustion of the search, candidates are ranked by number of
exact endpoint coordinates (more first), geometric residual, then `(t,u)`.
A candidate is retained only if no earlier retained candidate is within
`1e-7` in both coordinates. Retained representatives never move. This covers
discarded candidates and separates retained ones; it does not certify unique
mathematical roots. Depth exhaustion and the total examined-window budget
produce explicit errors rather than partial success or fallback.

## Initial implementation comparison (before terminal-only refactor)

Run after an Erlang build:

```shell
escript examples/debug/elizabeth_comparison.escript
```

Observed on the initial implementation:

| Geometry | Henry | Edward | Elizabeth, 1,000 windows | Elizabeth, 100,000 windows |
| --- | --- | --- | --- | --- |
| `x=t, y=(t-.2)(t-.21)(t-.22)` versus horizontal quadratic | 3 | 1 | 3 | 3 |
| `y=(t-.5)^2` versus horizontal quadratic | 3 approximations | 1 | Budget error | 15 candidates |

Elizabeth's clustered-crossing parameters were within `2e-10` of the three
known roots. The kissing candidates occupy approximately `.5 ± 7.02e-7`;
they meet the residual and pairwise separation contract. They are **not** 15
distinct mathematical intersections. The high-budget kissing regression tests
the contract, not an exact candidate count, which can depend on rounding.

The budget is total examined windows, not a best-N/live-window policy. No
breadth-first search, ranking-based window deletion, or production replacement
has been introduced. The archived residual-exclusion patch is not applied.

## Verification

`scripts/test-fast` passes **1,614 tests**, including eight direct Elizabeth
tests: transverse crossing, clustered crossings, endpoint preference, disjoint
windows, insufficient depth, insufficient window budget, kissing exhaustion,
and successful kissing-candidate residual/separation checks at a larger budget.

## Historical residual-threshold sweep (before terminal-only refactor)

No production or experimental solver source was changed for this measurement.
`elizabeth_threshold_sweep.escript` runs nine fixtures at each of `1e-12`
through `1e-16`, with a fixed 100,000 examined-window budget. Its optional
`fine` argument changes terminal widths from `1e-9` to `1e-11` in an in-memory
compiled module only. Both modes instrument the examined-window count.

Raw records: [normal widths](elizabeth-threshold-sweep.txt),
[finer widths](elizabeth-threshold-fine.txt). Coverage checks use a `1e-5`
parameter neighborhood of the known root or the existing arc/cubic regression
reference; they are not claims of `1e-5` or better certified root isolation.

At the original `1e-9` terminal widths:

| Fixture | 1e-12 | 1e-13 | 1e-14 | 1e-15 | 1e-16 | Examined windows |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Three clustered crossings | 3 | 3 | 3 | 3 | 3 | 622 |
| Same controls translated by (100,100) | 3 | 3 | 1 | 1 | 1 | 1,315 |
| Centered quadratic kiss | 15 | 7 | 1 | 1 | 1 | 20,332 |
| Off-center quadratic kiss | 9 | 5 | 1 | 1 | 1 | 8,227 |
| Two close quadratic crossings | 2 | 2 | 2 | 2 | 2 | 532 |
| Flat cubic crossing against horizontal quadratic | limit | limit | limit | limit | limit | 100,000 |
| Original loop-eight arc pair | 1 | 1 | 0 | 0 | 0 | 217 |
| Cubic approximations from that arc pair | 1 | 1 | 1 | 1 | 1 | 217 |
| Saved join/line exact endpoint, forced generic route | limit | limit | limit | limit | limit | 100,000 |

All successful candidates satisfy the requested geometric residual. Budget
errors return no partial candidate list, even when an exact endpoint is known.

### What the additional probes establish

- Finer `1e-11` terminal widths do not recover the lost arc intersection.
  Clustered crossings now cost 29,134 windows instead of 622; translated
  crossings and both kisses exceed 100,000. Uniform extra refinement is costly.
- Tightening the residual does not change the number of examined windows in
  these runs: enclosures and terminal widths determine that search, not candidate
  acceptance. It therefore does not remedy budget exhaustion.
- `elizabeth_local_residual_probe.escript` finds **zero computed residual** near
  each of the three translated roots. Their omission below `1e-13` is therefore
  a candidate-selection/refinement limitation, not proof that double precision
  cannot represent an acceptable pair. This probe samples equal parameters
  within `1e-8` of each expected root, at `1e-11` spacing.
- A 65×65 local parameter grid around the original arc intersection finds a
  minimum residual of `1.4210854715202004e-14`. This supports caution about a
  universal `1e-14` cap at this coordinate scale, but is not a proof of a global
  numerical floor. Existing Newton refinement to `1e-16` also failed from the
  arc candidate. It recovered only the middle translated crossing from those
  three initial candidates.

Recommendation: do not globally lower the default yet. `1e-13` preserved all
expected neighborhoods in fixtures that completed here, but still returned
several kissing candidates and did not cure exhausted searches. First examine
terminal candidate refinement on the translated reproducer, where acceptable
pairs demonstrably exist. Treat window-budget control as a separate experiment.

## Terminal-only sampling and tangent-line correction

The follow-up removes all nonterminal candidate work and candidate propagation.
The sweep script now accepts `no_newton`, which disables corrections only in
the in-memory compiled terminal helper. It does not change repository code.

Raw records: [terminal sampling alone](elizabeth-terminal-seeds.txt),
[terminal sampling with Newton](elizabeth-terminal-newton.txt).

At residual `1e-14` and the same `1e-9` window resolution:

| Fixture | Terminal seeds only | Terminal seeds + Newton |
| --- | ---: | ---: |
| Three clustered crossings | 3 | 3 |
| Translated clustered crossings | 0 | 2 |
| Original loop-eight arc pair | 0 | 1 |
| Loop-eight cubic approximation pair | 0 | 1 |

Both loop-eight pairs now reach **zero computed residual**, including at the
`1e-16` threshold. This supersedes any suggestion from the earlier local probe
that its `1.42e-14` best sample established an evaluation floor: it did not.
The third translated crossing is still missed below `1e-13`. Kissing-candidate
multiplicity and flat-contact budget exhaustion persist. Examined-window counts
are unchanged: the correction does not alter the subdivision tree.

Regression tests explicitly cover strict-residual recovery of the arc crossing
and at least two translated candidates. This is still experimental; production
solver selection and tolerances remain unchanged.

`scripts/test-fast` passes **1,616 tests** after this refactor, including the
two new strict-residual regressions. The diagnostic comparisons also completed
with corrections enabled and disabled; no production fallback was used.

## Production-routing integration trial

### Endpoint discovery and best-of-five beam scoring

Elizabeth now queries both endpoints of each segment against the other
segment using the existing coordinate-root/projection inventory from overlap
detection. These candidates bypass beam retention, preserve multiple matching
parameters, and enter the existing endpoint-preferring final selection.
Window scores now use the least distance among all four corners and the center.

The shared-endpoint regression now retains `(1, 0)`, but also retains eight
nearby candidates. The off-center kissing regression still returns three
candidates; the flat-cubic crossing returns three instead of nine. Thus these
changes address endpoint loss, not the remaining candidate consolidation issue.

Added a regression for one endpoint meeting a retraced quadratic at two
parameters. `escript examples/debug/elizabeth_beam_allocation.escript` passes,
including a new check where the best corner must outrank a better midpoint.

`scripts/test-fast` completed after these changes: **1618 passed, 3 failures**.
The failures are the three candidate-consolidation cases described above.
Slow tests have not been run for this integration.

The subsequent gallery trial ran the generator commands directly, without
changing the three tests or promoting images into `docs/gallery`:

- `gleam run -m arrangement_csg_figures` in
  `examples/readme_arrangement_figures` succeeded.
- `escript scripts/gallery/package_title_arrangement.escript` succeeded,
  including the first offset and production-traced second-offset arrangement.
- `gleam run -m svg_path_gallery_test` failed in `figure_eight_band` with
  `Error(ConstructionFailed)`: offsets 18 and 34, Round joins, Butt caps,
  default offset options. This is a downstream integration failure and must
  be investigated before treating the extra candidates as harmless.

The figure-eight failure was traced to cusp trimming's winding propagation:
`ContradictoryWinding(edge_id: 36, face_id: 0, assigned: 0, required: 1)`.
Elizabeth misses source segment 32's crossing with offset segment 0 near
`(399.138882953037, 210.133556931058)`, while retaining the upper crossing.
The incomplete graph puts edge 36 on face 0 on both sides despite its winding
change of -1. No beam windows were discarded (235 examined, peak retained 2).

`escript examples/debug/elizabeth_figure_eight_terminal.escript` confirms:
the smallest Newton residual visited is `6.355287432313019e-14`. All six starts
still fail at `5e-14` with 64 iterations. A process-local threshold experiment
at `1e-13` finds the crossing and successfully constructs the whole original
figure-eight band. `1e-12` also finds the isolated crossing. Production code
has not been changed. This is a terminal acceptance/refinement failure, not
extra-root clustering or beam loss. The numerical bounds on returned
candidates do not guarantee completeness.

Following that experiment, the production Elizabeth cutoff was changed to
`min(options.tolerance, 1e-13)`. `gleam build` and
`escript examples/debug/elizabeth_figure_eight_failure.escript` complete
successfully (`Fixture: ok`) with the updated production code. The earlier
measurements above retain their original thresholds.

Verification with production `1e-13`: `scripts/test-fast` completed with
1618 passed and the same three candidate-count failures. `scripts/test-slow`
completed with 26 passed, no failures. The gallery generator was refactored to
concurrent named jobs after its old batch mode concealed which figure was slow.
The concurrent run regenerated all 29 figures without errors, including
recursive dashes, both figure-eight band fixtures and the second-offset
arrangement. The nine-offset package-title figure completed in 171.78 seconds.
The completed progress log is `/tmp/elizabeth-concurrent-gallery.log`.

`escript examples/debug/package_title_letter_timing.escript` isolates the
first source subpath (S), applying +1.04 twice with the gallery's Miter/Butt
defaults. Process-local routing changes compare Elizabeth against Edward/Henry:

| Level | Elizabeth | Edward/Henry | Curve-pair calls |
| --- | --- | --- | --- |
| 1 | 16.123s | 0.414s | 305 in either route |
| 2 | 9.985s | 0.478s | 226 in either route |

Both routes return the same subpath/segment counts (3/63, then 1/30; this does
not assert exact geometric equality). Elizabeth spends 15.864s and 9.652s in
curve-pair calls. A representative slow pair has coincident endpoints with
both endpoint derivatives zero: the previous cubic's last control point is
its end, and the next cubic's first control point is its start. It examines
50,077 windows, discards 40,828 through the beam, and returns nine candidates
near `(t,u)=(1,0)`, spanning about 2.26e-6 by 1.18e-6 in parameter space.
This is expensive refinement around a stationary shared endpoint, not an
infinite loop. Exact captured geometry, results and timings are saved in
`letter-s-elizabeth-1.term` and the other letter timing captures.

### Generation-dependent beam budgets

The budget is now a private `Int -> #(Int, Int)` function, with one-based
generations starting at the initial 8x8 grid. Crossing/other reserves are
500/500 through generation 5, 250/250 through 10, 125/125 through 15, 60/60
through 20, then 30/30. Unused slots are still shared. Ordinary terminal
width 1e-9 is reached around generation 18; the final tier supports deeper
experiments. Residual and final candidate-selection policies are unchanged.

`escript examples/debug/elizabeth_beam_allocation.escript` passes generation
boundary, asymmetric-budget, unused-slot lending and best-of-five checks.
Isolated S +1.04 timings are 4.514s and 2.923s (previously 16.123s and 9.985s),
with the same subpath/segment counts. The package-title first-offset,
second-offset arrangement, and nine-offset gallery jobs all succeed in
30.62s, 33.33s and 56.60s respectively (previously 126.15s, 124.11s, 171.78s).
Earlier gallery timings included additional concurrent jobs; reduction counts
also decreased (nine offsets: 24.35 billion to 9.99 billion).

`scripts/test-fast`: 1619 passed, 2 failures (shared-endpoint and off-center
kissing candidate counts). The flat-cubic production regression now passes
unchanged. The experimental flat-crossing test was updated from fixed-budget
expectations (peak 1000, six representatives) to the new observed policy
(peak 250, one exact crossing). The other 26 gallery jobs also all succeed.
Finally, `scripts/test-slow` completed: 26 passed, no failures.

### Crossing scores, evaluation caches and smooth decay

Implemented and measured separately, in that order:

1. Ranking includes the actual curve residual at the chord-predicted crossing,
   not the zero residual of the chords themselves. S timings: 4.485s / 2.746s.
2. Exact `(u,v)` ranking-sample cache, retained across generations and local
   to one curve pair. Signed zeros are canonicalized; nearby keys are not
   merged. Entries retain both points and their residual. Pair-only caching
   had about 60% hits but did not speed up S (4.816s / 3.084s). Adding separate
   per-curve point dictionaries underneath it measured 4.301s / 2.883s: close
   to the uncached timing, not a demonstrated significant cache speedup.
   Newton, endpoint discovery and enclosure evaluations are not cached by
   this first implementation; only ranking samples use these dictionaries.
3. Smooth per-bucket budget:
   `round(500 * coefficient^(min(generation, stop)-1))`, bounded below by one,
   with coefficient 0.8705505632961241 and stop generation 21. The exponent is
   clamped at zero for earlier inputs. S timings: 3.491s / 2.732s, same output
   counts. Maximum pair-cache entries for these solves: 17,563 / 24,536.

Focused `elizabeth_beam_allocation.escript` checks cover the crossing score,
cache exactness against direct evaluations, signed zero, nearby distinct keys,
repeat hits, smooth budgets, asymmetric reserves, and lending.
`scripts/test-fast`: 1619 passed, same two candidate-count failures. The
experimental flat fixture retains the exact crossing with peak 226 windows,
within its tested ceiling of 250; the production flat regression is unchanged.

Combined validation: `scripts/test-slow` passes (26 tests). The concurrent
gallery runner completed all 29 figures successfully. Package-title first
offset: 28.46s; second-offset arrangement: 31.05s; nine offsets: 54.26s.
These are concurrent-run wall times, not isolated benchmarks.

### Follow-up: 20 windows per bucket at generation 20

The current coefficient is 0.8441589125494964, with stop generation 20.
This preserves the initial 500 per bucket and holds at 20 per bucket from
generation 20 onward. Focused allocation/cache checks pass.
Isolated S offsets: 2.673s / 1.817s, with unchanged subpath/segment counts,
versus 3.491s / 2.732s under the preceding decay policy.
`scripts/test-fast`: 1619 passed, the same two candidate-count failures.
All 29 gallery jobs succeeded: package-title first offset 20.91s,
second-offset arrangement 22.83s, nine offsets 44.17s (concurrent wall times).
`scripts/test-slow`: 26 passed, no failures.

### Isolated nine-offset comparison: 18 at 18 versus Edward/Henry

`escript examples/debug/package_title_solver_comparison.escript elizabeth18`
and then the same command with `old` run the original nine-offset title job
(+1.04) sequentially, in separate VMs. Compilation is outside the timed job.
The first uses a VM-local budget override: coefficient 0.822387721768745,
stop generation 18, 18 windows per bucket at/after generation 18. The second
uses a VM-local dispatch override to Edward then Henry. Production remains
on the 20-at-20 policy. Both completed successfully:

| Solver | Wall time | Erlang reductions |
| --- | ---: | ---: |
| Elizabeth 18 at 18 | 37.77s | 7,247,547,513 |
| Edward then Henry | 23.10s | 5,168,025,809 |

Outputs are retained under `title-comparison-elizabeth18/` and
`title-comparison-old/` beside this document. These measurements do not
establish output equivalence or test-suite compatibility of 18 at 18.

### Shared spatial-diversity selection

Both window buckets and final candidate selection now use
`select_spatially_diverse`: best-first input, location callback, limit, and
minimum separation. Separation starts at 0.5, halves, and explicitly visits
the floor. Window floors are zero (fill by rank); candidate floor is 1e-7.
For the zero floor, halving stops at unit-interval floating-point resolution
before the explicit zero pass. Selected occurrences are removed from future
passes, so identical locations can fill distinct window slots without
selecting one occurrence twice. Window location is its best-scoring sample.
Production budget remains 20 at 20.

`escript examples/debug/elizabeth_beam_allocation.escript` passes, including
new shared-selector checks. `scripts/test-fast`: 1617 passed, 4 failures.
The two existing shared-endpoint/kissing count assertions remain; additionally
the experimental flat crossing returns 6 rather than 1 candidate, and the
production flat crossing returns 9 rather than 1. These expectations were
not weakened. Gallery and slow tests have not been rerun for this change.

Nine-offset title with diversity and a VM-local 15-at-15 budget completed
successfully in 31.41s (6,581,248,436 Erlang reductions), using
`escript examples/debug/package_title_solver_comparison.escript elizabeth15`.
Coefficient 0.7784360616734048; 15 slots per bucket from generation 15.
Output: `title-comparison-elizabeth15/gallery-package-title-nine-offsets.svg`.
Production remains 20 at 20. This is a single-fixture timing, not suite validation.

### Production validation of diversity with 15 at 15

The working-tree default is now 15 at 15 (coefficient 0.7784360616734048,
stop generation 15). Focused allocation/cache/diversity checks pass.
`scripts/test-fast`: 1617 passed, the same four candidate-count failures as
diversity at 20 at 20. All 29 gallery jobs generated successfully; the title
first offset took 11.45s, second-offset arrangement 14.98s, and nine offsets
34.67s in the concurrent run. No test expectations were changed.
`scripts/test-slow`: 26 passed, no failures.

### Triggered start, absolute 12 at 12

Current policy starts decay at the first generation with more than 1000
survivors after enclosure rejection, or generation 5, whichever is earlier.
The start is stored once. Budget per bucket stays 500 through that start s,
then is round(500 * (12/500)^((g-s)/(12-s))), reaching and holding 12 at
absolute generation 12. The shared diversity selector remains enabled.

Focused allocation checks cover strict >1000 triggering, generation-5
fallback, retention of the original start, monotonic decay for starts 3/4/5,
and the exact final budget. They pass. `scripts/test-fast`: 1617 passed,
the same four candidate-count failures. The isolated nine-offset title
completed in 29.40s (6,149,387,450 Erlang reductions), using
`escript examples/debug/package_title_solver_comparison.escript current`.
Follow-up validation: all 29 gallery jobs generated successfully. Concurrent
title timings were 10.36s (first offset), 13.88s (second-offset arrangement),
and 34.54s (nine offsets). `scripts/test-slow`: 26 passed, no failures.

### Crossing-window five-sample scoring experiment

Crossing windows now score four corners plus the actual curve residual at
the chord-predicted crossing, omitting the midpoint. Noncrossing windows
still use four corners plus midpoint. Focused checks verify five pair-cache
requests in both cases and agreement with direct evaluation.
`scripts/test-fast`: 1617 passed, same four candidate-count failures.
The isolated nine-offset title completed in 29.60s versus 29.40s previously;
reductions were 6,147,108,724 versus 6,149,387,450, effectively unchanged.
All 29 gallery figures generated successfully (nine offsets: 30.89s in that
concurrent run). There is no demonstrated speed benefit on this benchmark.
`scripts/test-slow`: 26 passed, no failures.

### Earlier integration measurements

### Follow-up trace of the three failures

`escript examples/debug/elizabeth_integration_failures.escript` traces actual
enclosure decisions, beam selection, and candidate finishing without changing
the solver. [Recorded trace](elizabeth-integration-trace.txt).

- Shared endpoint: its window passes every enclosure check. At window
  `[0.9999999738656052,1] x [0,2.6134394766096104e-8]`, beam selection goes
  from 2980 survivors to 1000 and drops the endpoint window. Subsequent raw
  output contains 33 candidates but no `(1,0)`; deduplication leaves four.
  This is not final endpoint ranking failing: the exact pair was unavailable
  to rank. The left cubic has its final control point equal to its endpoint,
  making near-endpoint movement second-order. A recommended narrow safeguard
  is to evaluate original endpoint pairs independently of heuristic windows.
  That would preserve the exact pair, but would not by itself remove all
  nearby extra candidates.
- Off-center kiss: 402 raw candidates become three after `1e-7` deduplication.
  They span about `2.01e-7` around `(0.37,0.63)`. All three survive the cap of
  four. No established distinct-root grouping takes place at final selection.
- Flat cubic pair: 4000 raw candidates become nine after deduplication, spanning
  about `8.01e-7` around `(0.5,0.5)`. All nine survive the cubic/cubic cap of
  nine. The exact central pair is present. Their separation is cubic in the
  deviation from 0.5, so nearby nonroots easily meet the geometric threshold.

The latter two failures follow the specified selection heuristic rather than
a faulty implementation of it: an upper bound does not supply a root count.
No solver fixes or test expectation changes were made during this examination.

The private `use_elizabeth_beam` switch is now **True**: generic curve/curve
calls use beam Elizabeth, without falling back to Edward or Henry. Analytic
Line dispatch and the surrounding overlap/snap logic are unchanged. The old
route is retained behind the switch. A genuine beam depth failure maps to
`IntersectionDepthLimitReached` carrying the unresolved parameter rectangle.

`scripts/test-fast` completed: **1617 passed, 3 failures**:

- `segment_intersections_prefers_shared_endpoint_over_near_endpoint_minimum_test`:
  expected the single exact `(1,0)` intersection; returned four near-endpoint
  candidates, none at the exact pair.
- `production_off_center_kissing_quadratics_test`: expected one, returned three.
- `flat_cubic_crossing_regression_test`: expected one, returned nine.

The integration trial therefore does not pass. No tests were weakened and no
solver repairs were made during this run. Per the requested sequence, slow
tests and gallery generation were not attempted. The switch remains enabled
for inspection; this worktree is not yet a passing replacement of production.
[Fast-test failure details](elizabeth-integration-fast.txt).

## Coarse-to-fine final candidate selection

Beam Elizabeth now applies the agreed heuristic after `1e-7` deduplication.
At thresholds `1e-5`, `3e-6`, `1e-6`, `3e-7`, `1e-7`, repeatedly select the
best remaining candidate at least that far from every selected candidate in
the maximum-parameter-difference metric. Previously selected representatives
never move. Ranking prefers exact endpoints, then residual, then parameter
order. Stop at the conservative degree-product bound or the final threshold.

Bounds by segment types: line/line 1, line/quadratic 2, line/cubic 3,
line/arc 2, quadratic/quadratic 4, quadratic/cubic 6, quadratic/arc 4,
cubic/cubic 9, cubic/arc 6, arc/arc 4. These are upper bounds, not root counts;
the experiment excludes overlapping/shared-component cases. No approximate
degree reduction is performed. In particular the flat quadratic fixture still
counts as degree two. `discarded_candidates` reports additional selection loss
after ordinary parameter deduplication. Production and DFS are unchanged.

At `5e-14`, counts before/after:

| Fixture | Before | After |
| --- | ---: | ---: |
| Clustered / translated crossings | 3 / 3 | 3 / 3 |
| Centered kiss | 5 | 4 |
| Off-center kiss | 3 | 3 |
| Two close crossings | 2 | 2 |
| Flat cubic | 17 | 6 |
| Loop-8 arcs / cubics | 1 / 1 | 1 / 1 |
| Join/line | 20 | 2 |

The join endpoint `(1,0)` survives. Its selected interior representative is
`(0.9998698071567402, 9.850713330301448e-7)`, with zero computed residual.
It is `2.57e-5` away in arc parameter from the line-specific reference, so the
diagnostic `1e-5` reference-neighborhood count drops from 2/2 to 1/2. All
interior residuals tie at zero; this follows the requested deterministic
selection policy, not a residual improvement. Other reference-neighborhood
counts remain unchanged. Thus the cap controls output size but does not
certify distinctness or parameter accuracy. Window counts are unchanged.

Reproduce with `escript examples/debug/elizabeth_threshold_sweep.escript beam newton_only`.
See [results](elizabeth-selection-results.txt). Selector checks in
`elizabeth_beam_allocation.escript` also verify coarse-first preference and
determinism under input reversal.

## Inspection of the 17 and 20 candidate groups

Command: `escript examples/debug/elizabeth_candidate_groups.escript`.
This inspects returned candidates only; the clustering below is diagnostic,
not a change to the solver. Distance means the maximum of the two parameter
differences (the same square metric as deduplication).

**Flat cubic:** its y-coordinate is `(t-0.5)^3`, so there is one mathematical
intersection with the horizontal curve, at `(0.5,0.5)`. The 17 candidates
span `t,u = 0.49999916902304054 .. 0.5000008077463864`, width `1.64e-6`.
Adjacent gaps are approximately `1.00e-7 .. 1.13e-7`, reflecting the existing
`1e-7` deduplication. Residuals range from zero at the center to `5.74e-19`:
even a much stricter residual threshold would retain nearby approximations.
Single-link clustering at `2e-7` produces one group, despite its total width
being larger than `2e-7`. The minimum-residual representative is the exact center.

**Join/line:** 19 interior candidates span arc parameters
`0.9998698071567402 .. 0.9998982326667807` (width `2.84e-5`), with line
parameters `7.70e-7 .. 9.85e-7`. The twentieth is the exact endpoint `(1,0)`,
separated by a parameter gap `1.02e-4` from the nearest interior candidate.
All twenty have **zero computed residual**, so ranking by residual gives no
preference. This is not evidence for twenty exact mathematical intersections.
The ordinary line-specific solver at `1e-9` reports two intersections:
approximately `(0.999895513484253, 7.905709238521863e-7)` and `(1,0)`.
The earlier threshold sweep checked only the endpoint neighborhood; its
reference list now includes both line-specific results.

Single-link grouping of the join candidates gives sizes `[13,6,1]` at `1e-5`,
`[19,1]` at `2e-5` or `5e-5`, and `[20]` at `2e-4`. Thus there is an observable
scale separating the interior cloud from the endpoint, but apparent subgroups
within the cloud are not necessarily distinct roots. Search culling can also
affect those gaps. A degree-based upper bound of two for line/circle helps here;
blindly selecting the two lowest residuals does not, since all residuals tie.

Conclusion: these fixtures support investigating clustering, not a global
top-X residual filter. There is no single clustering threshold established by
these two cases. Single-link clusters also do not provide a representative
within the threshold of every member (they can chain).
[Raw parameters, gaps, residuals, and diagnostic groups](elizabeth-candidate-groups.txt).

## Bounded breadth-first Elizabeth

`elizabeth_beam_intersections` is a separate, explicitly incomplete search.
Each breadth-first generation rejects separated enclosures, then retains at
most 1000 windows: 500 per chord-crossing/noncrossing bucket, lending unused
slots. Ranking is midpoint residual, then left/right starting parameters.
Chord crossings are a heuristic, not certified curve crossings. The terminal
solver uses Newton only, residual `min(options.tolerance, 5e-14)`, width `1e-9`,
and the same `1e-7` candidate deduplication as depth-first Elizabeth.

The report includes examined windows, discarded crossing/other windows, and
peak retained windows. There is no total-window limit in this variant; after
the initial 64 windows, at most 9000 are examined per generation. The existing
depth limit still returns an error. Neither zero heuristic discards nor
successful completion certifies that every mathematical root was found.
Production solving and depth-first Elizabeth are unchanged.

Run: `escript examples/debug/elizabeth_threshold_sweep.escript beam newton_only`.
At `5e-14`, max depth 48:

| Fixture | Candidates | Examined | Discarded crossing / other |
| --- | ---: | ---: | ---: |
| Clustered crossings | 3 | 622 | 0 / 0 |
| Translated crossings | 3 | 1315 | 0 / 0 |
| Centered kiss | 5 | 16174 | 0 / 3384 |
| Off-center kiss | 3 | 8227 | 0 / 777 |
| Two close crossings | 2 | 532 | 0 / 0 |
| Flat cubic | 17 | 54460 | 0 / 29076 |
| Loop-8 arcs | 1 | 217 | 0 / 0 |
| Loop-8 cubic approximations | 1 | 217 | 0 / 0 |
| Saved join/line, forced generic solver | 20 | 82522 | 0 / 15265 |

All expected root neighborhoods are represented. The two former window-budget
failures now complete, but produce multiple nearby numerical candidates, not
17 or 20 established distinct mathematical intersections. Culling does not
solve that separate candidate-noise issue. Both buckets' allocation and spare
slot lending are checked by `escript examples/debug/elizabeth_beam_allocation.escript`
against the actual private selector. `scripts/test-fast` passes: 1619 tests,
including no-culling, depth exhaustion, and flat-crossing completion/residual
regressions. [Raw sweep](elizabeth-beam-results.txt).

## Newton-only comparison: `1e-13` versus `5e-14`

Command: `escript examples/debug/elizabeth_threshold_sweep.escript compare newton_only`.
The script disables the alternating retry only in its own compiled VM. Source
defaults and production behavior are unchanged. Width is `1e-9`, deduplication
is `1e-7`, and the examined-window budget is 100,000.

| Fixture | Candidates at `1e-13` | Candidates at `5e-14` |
| --- | ---: | ---: |
| Three clustered crossings | 3 | 3 |
| Translated clustered crossings | 3 | 3 |
| Centered kiss | 7 | 5 |
| Off-center kiss | 5 | 3 |
| Two close crossings | 2 | 2 |
| Loop-8 arcs | 1 | 1 |
| Loop-8 cubic approximations | 1 | 1 |
| Flat cubic | Window limit | Window limit |
| Saved join/line, forced generic solver | Window limit | Window limit |

All expected root neighborhoods remain covered in the seven completed cases.
The translated case's maximum returned residual is `1.4210854715202004e-14`
at both thresholds. Window counts are identical, and timings are similar.
For these fixtures, Newton with `5e-14` is preferable: it retains the crossings
while reducing kissing-root candidates. It does not eliminate that candidate
noise or solve window explosion. This is an empirical recommendation, not an
adopted default or a completeness guarantee.

Raw results: [threshold comparison](elizabeth-threshold-comparison.txt).

## Updated-chord alternating experiment

After a failed eight-step Newton attempt, each terminal seed now retries with
eight alternating tangent/secant steps. Secants join the current and previous
parameter samples of each curve. Their lines may be extrapolated, but the new
parameters must stay inside the terminal window. Collapsed or parallel chords
fall back to analytic tangents. Every accepted candidate still satisfies the
original geometric residual threshold. This is only in experimental Elizabeth.

Result: **no additional root neighborhoods recovered** in the nine-case sweep
from `1e-12` through `1e-16`; all candidate counts are unchanged. In particular,
the translated cluster still returns two roots at `1e-14` and below. The loop-8
arc and cubic cases still succeed. Window-budget failures remain unchanged.

Tracing the terminal window containing the missing root confirms that chord
steps are executed. One trajectory returns to the same two-point Newton cycle:
the left parameter stops moving, so its subsequent chord is collapsed. Other
trajectories also fail. Repeating all six seeds with 64 alternating steps still
returns no candidate. This particular secant policy does not solve the problem;
it does not rule out other ways of updating chord endpoints.

Reproduce with `escript examples/debug/elizabeth_threshold_sweep.escript` and
`escript examples/debug/elizabeth_alternating_trace.escript` after an Erlang
test build. Results: [sweep](elizabeth-alternating-results.txt),
[actual-call trace](elizabeth-alternating-trace.txt).

## Missing translated crossing: traced cause

`escript examples/debug/elizabeth_missing_root_trace.escript` traces actual
enclosure decisions, terminal windows and Newton calls. It exports existing
compiled helpers for read-only inspection, without changing solver behavior.
The complete trace is in [elizabeth-missing-root-trace.txt](elizabeth-missing-root-trace.txt).

The missing crossing is the one near `(0.22,0.22)`. The zero-residual witness
`t=u=0.21999999999` survives every enclosure check and lies in the terminal
rectangle `[0.21999999914821233, 0.22000000011615287]` on both axes.
It is not lost by enclosure rejection, global budget exhaustion or deduplication.

The six terminal seeds all fail the `1e-14` residual condition. Newton sequences
enter short cycles in the rounded coordinate evaluations. For example, with
`t=0.22000000000086384`, `u` alternates between that same value and
`0.22000000000087805`. Both evaluated distances are
`1.4210854715202004e-14` (one floating-point spacing near coordinate 100).
The midpoint seed enters a two-state cycle with residual `2.0097e-14`; the chord
seed enters a longer cycle. All steps of these cycles stay inside the window.

Replaying all six exact terminal seeds with **64 Newton iterations** instead
of eight still yields no candidate. Thus simply increasing the iteration cap
does not repair this case. A qualifying pair exists inside the window, but
these Newton trajectories do not visit it. Nearby windows also have escaped
steps, but that is not the failure of the window containing the witness.

No numerical policy was changed during this trace. The remaining question is
how terminal solving should respond to such rounded-evaluation cycles, rather
than assuming that more Newton iterations or more global search is sufficient.
