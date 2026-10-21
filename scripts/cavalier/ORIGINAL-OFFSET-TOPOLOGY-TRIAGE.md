# Original offset topology-policy families — 2026-10-20

Native `1b4113b` (production unchanged from `09d30a1`), JavaScript. Pinned
Cavalier 0.9.0 revision `22887a824d22cd8ab50968a551f34cdb4508127f`.
No production changes. This batch covers 192 original records from 18 families,
including passing controls, representing 34 distinct native input/distance calls.

## Results

All 192 public calls complete within the 30-second worker limit: 82 match the
original per-contour properties, 110 differ, zero errors/timeouts. Full upstream
coordinates were exported with each original Preserve/Separate and
Preserve/Discard setting. Reconstructed upstream area, length and bounds match
all 192 original captured expectations at the existing 1e-4 comparison threshold.

Boundary checks sample seven fractions per segment in both directions at 1e-5.
127 records agree as sampled geometric sets; 65 have sampled differences.
These checks use native analytic line/circle projection, not an independent
oracle or an exhaustive proof. They deliberately ignore traversal multiplicity.
For repeated geometry, an additional interval-union calculation uses native
segment overlaps to count each boundary span once. It is not independent of our
overlap solver either. Raw outputs and every check remain recorded.

The 110 property flags divide as follows:

- **55 coincident-discard policy comparisons.** Cavalier's Discard option deletes
  coincident geometry; native has no matching option. For every such record,
  the same native call agrees with the corresponding upstream Preserve boundary
  samples. These are real boundary differences, not mere grouping differences.
- **24 contour-grouping comparisons.** Sampled boundary sets and total lengths
  agree, but Preserve/Separate presentations differ. Native has no equivalent
  touching-loop routing switch.
- **21 traversal-multiplicity comparisons.** Sampled boundary sets agree; total
  traversal lengths differ because copies of coincident spans are counted
  differently. Boundary lengths counted once agree within 5.04e-8. Examples:
  open coincident lines have native length 15 versus upstream 20; the line/arc
  case has 21.283185307179586 versus 32.56637061435917. This is not missing
  geometric coverage. Native trimming uses occurrence capacities and forced
  parity rather than promising Cavalier's preservation of every traversal.
- **8 three-way coincident-line comparisons.** Investigated separately below.
- **2 bow-tie crossing comparisons.** Investigated separately below.

These are scoped dispositions, not assertions that every internal winding label
is correct. They do not settle the deferred question of whether to change the
native trimming policy.

## Three-way coincident lines: CC01697, CC01701–CC01707

Native returns a closed retrace plus an open walk. The retrace contains two
length-5 lines and four radius-1 quarter arcs, retraced in pairs. Upstream
Preserve keeps the straight traversals but removes these round excursions.
The extra traversed arc length is exactly 2*pi: native total 41.283185307179586,
upstream Preserve total 35. Upstream Discard additionally removes coincident spans.

The retained arcs are not a missing-intersection assertion: they lie near the
source and are traversed out and back. One recorded boundary witness is only
0.19509032201612836 from the source, versus offset magnitude 1. Cavalier's explicit
minimum-source-distance filtering rejects that geometry. Native winding/parity
trimming has no equivalent global distance guarantee and can retain retraces.
Classify as a source-distance/retrace policy difference; whether such retraces
should be removed is a deferred policy question, not silently called a match.

## Bow-tie crossing: CC01738–CC01739

Upstream tests that changing touching-loop behavior does not change true-crossing
results. Its two settings produce identical geometry. Our adapter also produces
identical native results for those settings, but retains only the upper lobe:
length 8.491168824543141 versus upstream total 18.41926197207399.

All 56 sampled upstream boundary points occur in the native untrimmed geometry
within 4.97e-16. Default tracing shows 40 arrangement edges -> 24 offset-image
edges -> 16 winding-compatible edges -> 3 after forced parity -> one subpath.
Disabling offside trimming gives the same one-lobe result. Thus the missing lobe
is removed in winding/parity trimming, not lost during raw construction or by
the offside switch. This differs from Cavalier's distance/slice-routing policy.

The public native contract explicitly permits deletion during this process.
No new contract violation is established here, and no independent verification
of every winding label is claimed. Stronger validation or redesign of this policy
belongs to the deferred follow-up; the observed lobe loss remains documented.

## Per-family results

See `original-topology-family-table.md` and `original-topology-dispositions.json`
for all 18 names and all 192 individual IDs. Earlier historical replay totals
are not overwritten. New dispositions supersede old errors for these IDs only.

## Reproduction

```sh
CAVALIER_CASES=original-offset-topology-cases.json CAVALIER_RESULTS=NEW_RESULTS.jsonl CAVALIER_WORKERS=1 CAVALIER_TIMEOUT_MS=30000 node scripts/cavalier/compare-captured.mjs
CAVALIER_GEOMETRY=1 CAVALIER_CASES=original-offset-topology-unique.json CAVALIER_RESULTS=NEW_GEOMETRY.jsonl CAVALIER_WORKERS=1 CAVALIER_TIMEOUT_MS=30000 node scripts/cavalier/compare-captured.mjs
AUDIT_CASE_FILE=original-offset-topology-cases.json python3 scripts/cavalier/prepare-original-offset-export.py
RUSTUP_HOME=/tmp/cavalier-audit-rustup CARGO_HOME=/tmp/cavalier-audit-cargo CARGO_TARGET_DIR=/tmp/cavalier-audit-target cargo +1.95.0 run --offline --quiet --manifest-path /tmp/cavalier-original-offset-export/Cargo.toml
node scripts/cavalier/check-original-topology-boundaries.mjs
python3 scripts/cavalier/summarize-original-topology.py
```

The checker reads the recorded filenames `original-offset-topology-geometry.jsonl`
and `original-offset-topology-upstream.jsonl`; select fresh outputs when replaying
and compare them before replacing records. `CAVALIER_GEOMETRY` is an opt-in audit
runner output field; its absence preserves the previous comparison format.
Trace preparation uses the existing `prepare-original-offset-trace.py` and case
CC01738. Default, no-offside, untrimmed and stage records are
`original-topology-crossing-*.json`.

No full suite, figure generation, F# port or production repair in this batch.
Findings uncommitted. Remaining original inventory reconciliation and Boolean
classification precede the deferred-policy review; this is not audit closure.


## Bow-tie follow-up closed — 2026-10-21

CC01738/CC01739 are now classified as intended winding/parity trimming behavior
under a different contract from Cavalier, with explicit user agreement. The
lower component is an **open walk**, not a closed lobe. The earlier tracing
identified its removal in winding/parity reconstruction. A fresh CC01738 replay
on the current JavaScript build gives exactly identical segment coordinates for
default trimming and `SingleOffsetTrimming(False, InBandTrimming)`: one upper
triangle, three line segments, length 8.491168824543141, signed area
3.092598846298224. Disabling offside trimming does not recover the lower walk.

The README single-offset final-trimming figure illustrates this broader deletion
behavior. After reviewing that figure, the user accepted the bow-tie result as
following the intended algorithm. No further winding-label investigation is
required for this case; this disposition does not claim a proof of every label
or close the other deferred offset questions. A more intuitive trimming policy
is separate design work, not an outstanding repair for this example.

The native adapter uses offset -0.1 for Cavalier's +0.1 convention. Fresh replay:

```sh
AUDIT_CASE_ID=CC01738 AUDIT_TOLERANCE=0.01 AUDIT_TRIMMING=no-offside node scripts/cavalier/probe-offset-detail.mjs
AUDIT_CASE_ID=CC01738 AUDIT_TOLERANCE=0.01 AUDIT_TRIMMING=default node scripts/cavalier/probe-offset-detail.mjs
```

Preview: `examples/debug/bow-tie-trimming-comparison.svg`, generated from the
recorded audit geometry by `scripts/cavalier/draw-bow-tie-trimming.py`.
No production change or new full-suite run for this classification update.


## Round-retrace follow-up closed — 2026-10-21

The user reviewed CC01697's drawing and exact traversal and accepted the result
as intended algorithm behavior. The source goes 0 → 10 → 5 → 10 → 5 → 15 along
one line, reversing four times. Untrimmed construction emits two identical
semicircles at x=10 and two at x=5, each pair with the same traversal direction.
The final lower component is one closed zero-area walk: bottom line 5→10,
right quarter arc out-and-back, bottom line 10→5, left quarter arc out-and-back.
The bottom line is therefore traversed twice. Opposite-direction retracing
appears in reconstruction; it is accepted behavior, not a pending bug.

Fresh current native replay reproduces lengths 16.283185307179586 and 25 for
its two output walks, versus total 35 for Cavalier Preserve. The extra 2π is
the round excursions. This closes CC01697/CC01701–CC01707's follow-up; it does
not independently close the distinct case11/case5 distance-filtering examples
or self-intersecting-case1/case2 missing-walk examples in
ORIGINAL-OFFSET-SPECIFIC-TRIAGE.md. No production change requested.

Evidence: `three-way-lines-preview.json`, `three-way-lines-untrimmed-preview.json`;
`draw-three-way-lines.py` produces `examples/debug/three-way-lines-trimming.svg`.
