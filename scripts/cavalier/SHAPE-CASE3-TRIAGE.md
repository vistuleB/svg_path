# Shape offset case3 (CC01807) — 2026-10-19

Investigated after exact-arc overlap repair `0d3449f`. No production edits.

## Observed difference

The input is an outer rectangle and two curved inner contours, offset by 0.8.
The outer output already agrees. Default inner output has area -148.4496132139452
and length 61.03574804977124, compared with captured Cavalier values
-148.47470067296538 and 61.01805560001197. This is not just contour grouping.

## Tolerance sweep

`probe-shape-case3.mjs` runs the actual library and exports normalized source
segments and final output. `shape-case3-normalization-sweep.json` records:

| Fitting tolerance | Inner area | Inner length | Main inner segments |
| --- | --- | --- | --- |
| 0.01 (default) | -148.4496132139452 | 61.03574804977124 | 21 |
| 0.001 | -148.47321512634147 | 61.01805186866559 | 24 |
| 0.0001 | -148.47469897238008 | 61.01805682812906 | 28 |
| 0.00001 | same as 0.0001 | same as 0.0001 | 28 |

At default tolerance the two inner source contours normalize from 11/13 segments
to 6/7. At 0.001 they retain 9/10; at 0.0001 they retain 11/13. This is deliberate
line-degenerate-window replacement, not an intersection failure or unexpected
loss of an endpoint. `normalize_source_subpath` passes fitting.tolerance to
`degeneracy.normalize_degenerate_segments`; that routine replaces maximal
contiguous windows certified to fit within the requested strip width.

The tighter main inner contour agrees to ~4.4e-11 in area and ~1.7e-11 in length
with the pinned Rust fixture's literal expectations (-148.47469897242397,
61.018056828113345). Captured runtime expectations differ slightly from those
literals, but agreement remains within the audit's 1e-4 threshold. No comparator
threshold was changed.

## Controlled causal check

`prepare-shape-normalization-experiment.py` copies the generated JS build and
changes only the options passed to source normalization, forcing tolerance
0.0001 there. All subsequent fitting/construction options retain the caller's
values. The default 0.01 call then returns exactly the same recorded output
properties as the tight run (`shape-case3-normalization-experiment.json`).
This isolates the observed difference to source normalization. It is not a
proposal to hardcode a smaller value or change the public options.

## Additional zero-area contour at tighter tolerances

The tighter runs also return a closed two-arc contour with signed area zero and
length 2.27296632093755e-7. Its arcs have identical radii and reversed endpoints
and sweep: an exact out-and-back traversal, not an additional filled island.
The complete coordinates are retained in the replay files.

Current offset behavior intentionally preserves surviving retraces: see
`open_c_offset_preserves_closed_retraced_line_test` and
`closed_c_and_reversal_offset_preserves_retraced_line_and_outline_test` in
`svg_path_offset_test.gleam`. Source-order reconstruction consumes surviving
capacities and retains closed walks; it does not promise removal of every
zero-area contour. Do not silently delete the retrace to match Cavalier's
contour count. No separate defect is established by this observation.

## Disposition and API/documentation suggestion

Classify CC01807 as an understood normalization/detail and output-policy
difference, not a confirmed native bug. The main aggregate mismatch converges
under the existing option, and the extra tight-run contour is a retrace under
our existing preservation behavior. This is an explanation of the captured
fixture, not a general filled-region-equivalence proof.

Documentation should clarify that fitting.tolerance also governs source
line-degeneracy normalization. Its current field description emphasizes sampled
fitted-curve error; the module only says that source normalization occurs.
No new option or API break is needed for that clarification. Whether to decouple
these controls belongs in future API design, not this audit fix.

## Validation and scope

Executed native JS tolerance sweep and copied-build normalization-only control.
No full-suite rerun or Erlang claim: production code/tests were unchanged.
Audit validator and whitespace check pass. No F# changes or figures. Findings
remain uncommitted pending the next explicit commit request.
