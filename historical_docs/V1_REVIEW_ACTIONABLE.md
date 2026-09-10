# Straightforward fixes from the remaining 20-module audit

> Historical record. Status, commands, and code locations below describe their
> original checkpoints, not current main. See [the archive index](README.md)
> and [current follow-ups](../REMAINING_ISSUES.md).

Source: [V1_REVIEW.md](V1_REVIEW.md), audit at `7345278`.
IDs match the full review. The nine correctness fixes and three documentation
items below were implemented in separate commits on 2026-09-08. The remaining
groups are still proposals, not completed work.

## Completed commits

| ID | Commit | Change |
|---|---|---|
| BS1 | `3351438` | Preserve the ordinary rectangle start when one corner radius is zero. |
| SE1 | `3c419ab` | Keep a separator between unsigned coordinate groups; retain safe sign-based compaction. |
| SE2 | `3f1a135` | Separate repeated numeric arguments in subpath-line output. |
| SE3 | `0b605ab` | Emit coincident-endpoint arcs directly instead of manufacturing a loop. |
| EF1 | `61bbbe3` | Do not treat untouched segments as over-consumed; preserve them on reconstruction. |
| SP2 | `fd9d26a` | Represent empty Arc splits as Lines, retaining the original nonempty Arc. |
| IX1 | `1752c36` | Convert circular intersection angles into local ellipse coordinates. |
| CL1 | `787c6d7` | Include the region's implicit fill closure in encounters. |
| CL2 | `ed500a2` | Return the original subject when every clipped portion survives. |
| EF2 | `842ca9a` | Correct tolerance and radius-adaptation documentation. |
| AG4 | `93b5880` | Correct clustering and atomic-insertion documentation. |
| OF7 docs | `ddad3c4` | Refresh offset module and provenance-helper documentation. |

Every correctness regression was observed failing before its repair (EF1
timed out). SE3 replaces a test that incorrectly required a manufactured loop,
and adds a zero-radius termination regression. No other audit fixes were made.

## Summary

The original shortlist comprised **9 confirmed correctness fixes**, plus
**3 documentation cleanups**. These have localized causes and a reasonably clear intended result.
“Straightforward” describes the proposed repair, not a guarantee that downstream
tests will reveal no additional consequences.

Each correctness fix should first receive a failing regression test, then the
smallest repair consistent with the existing contract. Do not substitute broad
normalization or tolerance changes for the identified cause.

## First group: localized correctness fixes

| Order | ID / module | Observed failure | Proposed repair | Regression coverage |
|---|---|---|---|---|
| 1 | BS1 — `basic_shapes` | Rectangle with `rx=2`, `ry=0` loses a corner: area 90 instead of 100. | Compute its starting point from the effective radii; when either radius is zero, take the ordinary rectangle branch with an ordinary corner start. | Both zero-radius permutations; compare geometry/area with the unrounded rectangle. |
| 2 | SE1 — `serialize` | Minified quadratic becomes invalid `m0 0q1.5 2.5.5`. | Decide numeric separation from the preceding **final numeric token**, not whether any earlier token contained a decimal point. | Parse the result back; mixed integer/decimal coordinates and adjacent leading-dot numbers. |
| 3 | SE2 — `serialize` | Repeated horizontal coordinates concatenate into `h111`, changing the endpoint to 111. | Apply numeric separation even when the selected command separator is empty. | Minification with `AtSubpaths` and `explicit_initial_lineto`; repeated H/V and general coordinate groups. |
| 4 | SE3 — `serialize` | Same-endpoint relative Arc can recurse forever or manufacture a lens. | Remove the special invented-full-circle subdivision. Serialize the supplied endpoint arc directly, as the absolute path already does; do not invent a traversal for coincident endpoints. | Coincident endpoints with zero and nonzero radii; termination; absolute/relative semantic consistency. |
| 5 | EF1 — `effects` | Corner rounding with an untouched zero-length segment recurses without changing its input. | Only classify a segment as over-consumed when actual corner trimming consumes it. Ensure overlap resolution makes progress; do not delete degenerate source segments as a workaround. | The recorded `LeaveCorner` example; zero-length segments at other positions; ordinary overlapping trims still resolve. |
| 6 | SP2 — `svg_path` | Splitting an Arc at an endpoint returns an empty Arc whose length raises `DegenerateArc`. | Represent the empty portion as a zero-length Line at the exact endpoint, retaining the original Arc as the other portion. | Split at both 0 and 1; exact endpoint preservation; length/evaluation of both returned portions. |
| 7 | IX1 — `intersections` | Circular arcs with nonzero axis rotation return an uncertified intersection despite unchanged circle geometry. | Convert the global intersection angle into the ellipse's local angular coordinates before recovering its parameter. | Rotations 0, 30, 90 and negative rotation; both sweeps; verify returned parameters by evaluating the original arcs. |

## Second group: clear repairs with somewhat wider scope

| Order | ID / module | Observed failure | Proposed repair | Regression coverage |
|---|---|---|---|---|
| 8 | CL1 — `clip` | Clipping against an open triangular fill region retains geometry outside its implicit closing edge. | Include the fill region's implicit closing lines when collecting encounters, consistently with containment and the recent CSG fix. The subject being clipped is not implicitly closed. | Recorded open triangle; equivalent explicitly closed region; both fill rules and an open subject. |
| 9 | CL2 — `clip` | A closed square that survives clipping whole returns three open pieces. | If every classified subject portion survives, return the original subject intact. This restores the stated whole-subpath preservation contract without inventing a general piece-merging algorithm. | Recorded coincident-boundary square; wholly contained closed and open subjects; partially removed subjects must not take this branch. |

## Documentation-only cleanups

1. **EF2 — `effects`:** document that distance tolerance may be zero, and
   describe `AdaptRadius` as the simultaneous scaling pass actually performed.
2. **AG4 — `arrangement`:** restrict the insertion-order independence claim to
   the representative center for a fixed cluster; remove the unrelated
   parity-pruning comment on `insert_atomic_segment`.
3. **OF7, documentation portion — `offset`:** repair misplaced comments and
   references to stroke functionality that moved to `stroke`. Removal of
   supposedly dead fitting branches is **not** included in this easy-docs item.

## Actionable, but not in the easy-fix count

These should not be forgotten merely because the first group is simpler.

| IDs | Why separate them |
|---|---|
| DE1 | Confirmed loss of a real longitudinal extent. The plateau-turn correction is plausible, but deserves explicit traversal/endpoint invariants and several regressions rather than another local deletion rule. |
| AG2 | The shared-endpoint intersection skip is demonstrably invalid. Removing it is simple; processing the newly discovered cuts can expose the existing self-loop and repeated-address limitations. |
| OF2, OF3 | Confirmed closed-seam errors. Fix cyclic join classification and closure edits together with cyclic-rotation regressions; do not hide the issue by arbitrarily rotating the source. |
| OF6 | Wrong tangent ray is confirmed through a private production-function probe. Rejecting it is clear, but selecting the correct fallback and checking full-offset behavior requires more work. |
| PA1 | Supporting drawing after `Z` is required by the SVG contract, but parser state, repeated close commands, relative commands, and smooth-command control-point history need coordinated tests. |
| SP1 | Extrapolated directions are wrong. Preserve one-sided endpoint behavior and stationary-point semantics when changing the split-based computation. |
| TS1 | Shear loss is confirmed. The choice of recognition/round-trip tolerance should be explicit before changing matrix decomposition. |
| OF1 | Zero-offset failure is confirmed. The proposed capacity correction affects shared-preimage bookkeeping generally, not just the zero-offset case. |
| ST1 | Zero-length visible dashes need preservation, but endpoint-only dash geometry must survive extraction and cap construction together. |

## Investigation or contract work first

- **IX2:** missed roots in the generic intersection search are confirmed and
  important. Correct window termination needs a defensible search rule, not
  just a smaller exclusion constant.
- **IX3 / IX4:** clarify topological crossing versus tangent classification,
  and geometric-point uniqueness versus preservation of all parameter pairs.
- **AG1 / OF8:** confirmed narrow-region sampling failures need a safe way of
  choosing a point in the intended region; reducing the fixed step alone is
  not a general repair.
- **AG3:** self-intersection splitting interacts with graph self-loop support.
- **AD1, CH1, CH2, OF4, OF5:** static concerns need focused reproduction or
  contract verification before implementation.
- **OF7, dead-code portion:** verify reachability before removing fitting
  alternatives; keep separate from the documentation cleanup.
- **AG5:** already documented; no new fix is proposed.

## Verification baseline

At the audit checkpoint, `scripts/test-all` completed with 1,521 ordinary
tests and 26 slow tests passed. The newly found failures are diagnostic probes
in `examples/debug/remaining_audit.mjs`, not yet permanent regression tests.
That was the pre-fix baseline, not verification of the commits above.

Post-fix verification at `ddad3c4`: `scripts/test-all` completed successfully:
**1,530 ordinary tests and 26 slow tests passed**. `gleam format --check src test`
also passed. The ordinary test directory was restored by the slow-test runner;
there are no tracked working-tree changes. Review notes remain untracked.
