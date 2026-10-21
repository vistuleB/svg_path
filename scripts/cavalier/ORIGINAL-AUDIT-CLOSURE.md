# Original selected-case audit: investigation complete

2026-10-20, native production revision `09d30a1`; latest preceding findings
commit `29f2708`. Original closure committed as `cebcaee`; later follow-up decisions are recorded
below. No release readiness or complete upstream parity is implied.

## What is complete

- The original 2,866 representative observations remain preserved, drawn from
  selected operations in the pinned 287-test core suite.
- Every one of the final original queue's **437 discrepancy/error records** has
  an investigation disposition. These include repeated orientations and options;
  they are not 437 bugs. `original-queue-final-dispositions.json` enumerates them.
- The 53 selected continuous-overlap records have interval adaptations and a
  documented large-coordinate/default-tolerance distinction.
- All 31 originally uncaptured tests have named reviews: eight supply 32 passing
  public geometry probes; 23 assert different private/representation contracts.
- The final offset reconciliation covers 21 previously unregistered IDs:
  12 recovered property matches and nine already-understood policy comparisons.
- The Boolean stage review covers all 181 final queue records: 165 successful
  operations with final-output and stored-edge checks; 16 documented default
  minimum-length failures, all successful at three smaller thresholds.
- Initial timeout CC00937 was already resolved in the original serial replay;
  it now has an explicit register entry and current scanline evidence.

The last batch introduces no new confirmed native defect and changes no
production code. It does not rerun the full suite or regenerate figures.
`validate-records.py` verifies pinned source hashes, baseline totals, the original
queue's disposition coverage and the 31 reviewed gaps.

## What this does not mean

An investigated case can remain nonidentical, limited by numerical behavior, or
subject to a deferred policy decision. Passing sampled properties or boundaries
is not proof of exact geometry. Some Boolean scanline controls required the
orthogonal axis after floating-point oracle failures; those failures remain
recorded. Helper-only assertions, every cyclic-start variant, private routing
invariants, FFI, examples and UI are not all native test adaptations.

## Deferred review — separate from the original queue

1. **Offset semantics:** the beyond-collapse review was closed by the user as
   expected behavior on 2026-10-21 (see SQUARE-COLLAPSE-WINDING-TRIAGE.md).
   The three-way coincident-line retraced joins were also accepted on 2026-10-21.
   Remaining individually unreviewed policy examples concern
   distance-to-source filtering versus winding/parity, and removal of otherwise
   recognizable open components or lobes. The bow-tie CC01738/CC01739 follow-up
   was explicitly closed as intended algorithm behavior on 2026-10-21; alternative
   policies are separate design work. Other recorded cases are not closed by
   that decision. The observed rules are recorded;
   stronger independent validation and any policy redesign remain eligible.
   See the collapse/winding reports and ORIGINAL-OFFSET-SPECIFIC/TOPOLOGY-TRIAGE.
2. **CC01301 additional fragment — explained 2026-10-20:** the arc passes
   winding classification but is removed by parity cleanup after an attached
   edge fails winding classification. Fold into the general trimming-policy
   discussion above; see CC01301-FRAGMENT-POLICY.md.
3. **CC01504/CC01508 numerical residual — explained 2026-10-20:** the audit
   adapter loses exact semicircle intent when computing SVG radii. Quarter-arc
   controls match upstream area and length. No production bug established. See
   CC01504-SEMICIRCLE-RESIDUAL.md. The open-component policy remains separate.
4. **CSG endpoint reconstruction — repaired:** commit `c49e940d` bounds affine
   and similarity candidates, with subdivision capped at eight arcs. Full release
   tests and all 47 published figures passed. See
   CSG-ADAPTIVE-AFFINE-EXPERIMENT.md. F# migration remains outstanding.
5. **Scope and numerical limits:** recorded tolerance/representation differences,
   near-degenerate finite-precision limits, and unadapted private assertions are
   not silently converted to parity claims. See REVIEW.md and the per-case reports.

The deferred public Error variant remains in `DEFERRED-API.md` for 4.0.0; do not
restore it during 3.x work. F# migration of accepted Cavalier changes, final
validation and release preparation remain separate work. No audit closure here
authorizes publishing or represents the F# port as complete.

## Navigation

- `ORIGINAL-INVENTORY-RECONCILIATION.md`: missing register entries and current replay.
- `ORIGINAL-BOOLEAN-STAGE-REVIEW.md`: current two-mode scanlines and guard controls.
- `ORIGINAL-OFFSET-TOPOLOGY-TRIAGE.md`: 192 topology comparisons.
- `ORIGINAL-OFFSET-SPECIFIC-TRIAGE.md`: ten specific-offset comparisons.
- `ORIGINAL-OVERLAP-ADAPTATION.md`, `ORIGINAL-COVERAGE-GAPS.md`: original coverage gaps.

Historical reports retain the observations made at their original revisions.
Later entries in `triage-dispositions.json` supersede earlier entries for an ID;
this final queue snapshot uses that same rule.

## Accepted trimming-policy shortcoming

The CC01301 follow-up with a 40° gap returns an empty default-trimmed offset.
Recorded at the user’s request as a known, non-intuitive policy shortcoming;
no replacement API contract has been chosen. See
[OFFSET-TRIMMING-SHORTCOMING.md](OFFSET-TRIMMING-SHORTCOMING.md).

## Remaining distinct policy examples

The accepted bow-tie, beyond-collapse and three-way round-retrace cases are
closed. The original offset-specific report still contains examples not reviewed
individually with the user: case11/case5 retain geometry nearer the source than
Cavalier permits, and self_intersecting_case1/case2 omit upstream walks during
winding/parity trimming. These have recorded contract explanations, not confirmed
native defects. Do not silently treat acceptance of another example as acceptance
of these. See ORIGINAL-OFFSET-SPECIFIC-TRIAGE.md.
