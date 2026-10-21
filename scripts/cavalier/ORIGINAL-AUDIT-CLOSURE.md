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

The bow-tie, beyond-collapse, three-way round-retrace and case5 examples are
closed as accepted policy differences. Case5 (CC01470, offset magnitude 30)
was explicitly accepted by the user on 2026-10-21 after reviewing the comparison.
No repair is requested.

The user reviewed drawings of self_intersecting_case1/case2 on 2026-10-21 and
accepted the omitted upstream walks as consequences of the current trimming
policy. Both follow-up investigations are closed without a repair. See
ORIGINAL-OFFSET-SPECIFIC-TRIAGE.md. Case11's remaining cusp-only failure is a
known algorithm misbehavior, recorded below, rather than an active investigation.
There are no remaining active investigations in this audit register. This does
not imply exact Cavalier parity or that documented limitations have been fixed.

### Case11 follow-up repair — 2026-10-21

The later investigation established a curved-cusp join-side/metadata defect and
an offside route-selection problem. The repair resolves curved reversal joins
using source curvature, aligns reversal metadata, retries ambiguous cusp parity
by revoking eligible rescues, and prefers wholly non-submerged competing offside
routes before the existing score. Mixed submerged alternatives retain the old
score. Case11 with offside plus cusp trimming now returns one 44-segment contour,
area 141959.84850931115, matching the pinned Cavalier area. The isolated rectangle
regression and original README offside figure are preserved.

See CUSP-JOIN-SIDE-EXPERIMENT.md for validation and intermediate failures.
Without offside trimming, the recorded case11 cusp-only probe still produces two
cycles and returns InternalIToKSubpathCount(2), wrapped in ConstructionFailed;
the user explicitly retained this as a documented algorithm discrepancy/misbehavior
on 2026-10-21. It is not fixed and must not be described as correct output or
upstream parity, but further repair is not requested in this audit. Case5 was
separately closed as an accepted policy difference. The self_intersecting_case1/case2 policy examples were subsequently reviewed
and accepted as current-policy consequences; their investigations are closed.
F# migration remains outstanding. The full release suite passed before the final heuristic restriction;
focused tests and all 12 selected Gallery figures passed after it.

### Case1 reopened — 2026-10-21

The user withdrew acceptance of self_intersecting_case1 pending inspection of
its pre-trimming arrangement. CC01499 is active again; case2 remains accepted.
Fresh trace: 60 arrangement edges, 29 offset-image edges, 16 winding-compatible,
13 submerged, and 2 surviving parity. See self-case1-graph.json and
examples/debug/self-case1-arrangement-pre-trimming.svg. Earlier statements that
all investigations are closed are superseded by this reopening.

### Case1 mode comparison accepted; review closed — 2026-10-21

The user reviewed the cusp-only drawing and accepted the finding as documented.
With `CuspTrimming` instead of default `InBandTrimming`, CC01499 retains the
large geometry as one open 11-segment walk, length 1154.2864439731295. This is
not identical to Cavalier's two open walks. The different terminal modes and
reversed-run rescue explain the reviewed behavior. See the final policy review
in ORIGINAL-OFFSET-SPECIFIC-TRIAGE.md. This supersedes the reopening above:
no active Cavalier investigations remain. Documented limitations, F# migration,
and final release validation remain separate outstanding work.
