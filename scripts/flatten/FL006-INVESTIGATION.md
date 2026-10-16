# FL006: missed arc crossing — investigation, 2026-10-15

Follow-up: [candidate benchmark and full test results](FL006-BENCHMARK.md).
The candidate is now present in the working tree for review; the investigation
below records the preceding temporary-runtime experiments.

Status at the time of that investigation: root cause identified for the original full-arc pair. A local candidate
improvement works in a temporary JavaScript runtime; no production change or
full-suite validation has been made. The default Boolean discrepancy remains.

## Search failure

The independently certified crossing from `CONTINUITY-REPLAY.md` survives every
bounding-polygon check up to generation 6. At that generation there are 649
surviving windows and 586 retention slots. The window containing the crossing
ranks 601st by sampled residual and is discarded. The solver reports 63 discarded
noncrossing windows and returns no intersections after examining 10,936 windows.
Increasing max_depth cannot restore a window already discarded.

The short arc spans about 0.053 degrees; the other spans 90 degrees. Equal
parameter widths therefore cover very different geometric lengths. The true
crossing window's chords do not cross, so ranking uses only four corners and a
midpoint. Its best sampled separation is 0.0166476275 despite containing a root.
This is heuristic search loss, not an enclosure rejection or Newton failure.

## Candidate improvement, not adopted

Add one ranking sample using the closest parameters of the two window chords.
Evaluate the actual curves at those parameters, as the existing crossing sample
does. Keep the existing crossing classification and search budgets.

In the temporary runtime, the root window ranks first with residual 1.635e-9.
The solver recovers the crossing after examining 13,654 windows. Public queries
succeed in both operand orders at max_depth 48 and 96. The recovered point is
about 2.13e-11 from the independently computed witness.

As a diagnostic control, raising the total retention budget to 10,000 also
recovers the same crossing, examining 37,009 windows with no budget discards.
That is evidence for the diagnosis, not a recommendation to raise the budget.

Recommended next implementation: the additional ranking sample, with a portable
regression for both operand orders, followed by solver regression/full-suite
validation. It improves the heuristic; it does not make the search complete.
The added sample's broader runtime cost has not been benchmarked.

## Boolean comparison remains separate

The candidate alone does **not** make default CSG call 4295 match. It still emits
four arcs rather than five, with area 0.006167927557369612 and sampled boundary
difference about 3.63e-6. At tolerance 1e-7 the candidate emits five arcs and the
sampled boundary difference is about 3.0e-11.

Tracing arrangement calls shows that the cutter has already been split into a
short arc before it meets the relevant incoming arc. That pair returns
`Error(OverlappingSegments)` at intersection tolerance 5e-7; the arrangement's
shared-endpoint handling suppresses that query. Calling the beam solver directly
on the same pair recovers a crossing near parameters (0.449122668, 0.449123626).
This is a separate tolerance-dependent overlap classification, not the full-arc
ranking loss. Its policy/correctness still requires investigation; do not mark
4295 or the chained 4296 closed based on the ranking experiment.

The exact short pair and candidate Boolean results are recorded in
`remaining-fl006-experiment.json`. Its serialized `result` alone does not
distinguish an empty list from a payload-free error: the explicitly checked
result type is recorded separately as `shortPairPublicResultType`.

## Reproduction and scope

Using the current generated portable JavaScript build:

```sh
python3 scripts/flatten/prepare-fl006-runtime.py baseline
node scripts/flatten/probe-fl006-ranking.mjs
python3 scripts/flatten/prepare-fl006-runtime.py closest
node scripts/flatten/probe-fl006-ranking.mjs
python3 scripts/flatten/prepare-fl006-runtime.py budget
node scripts/flatten/probe-fl006-ranking.mjs
```

The preparer copies the generated runtime to `/tmp/fl006-runtime` and only edits
that copy. Run these sequentially. Trace coordinates intentionally follow this
specific witness. Raw logs are `remaining-fl006-ranking-{baseline,closest,budget}.log`.
The original miss was reproduced on both Erlang and JavaScript in the preceding
continuity audit; this candidate experiment ran on JavaScript only.

No production files, F# files, release metadata, or figures were changed. No full
test suite was run for this diagnostic-only investigation.
