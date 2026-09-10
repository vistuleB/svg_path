# v1.0 readiness review

> Historical record. Status, commands, and code locations below describe their
> original checkpoints, not current main. See [the archive index](README.md)
> and [current follow-ups](../REMAINING_ISSUES.md).

## Reading order

1. [Foundational review and early follow-ups](#foundational-review-and-early-follow-ups): historical findings and their recorded status.
2. [Module audits and implementation follow-ups](#module-audits-and-implementation-follow-ups): earlier module records, oldest first, with findings before their subsequent fixes.
3. [Remaining 20-module audit](#remaining-20-module-audit--started-2026-09-08-205927-utc): the latest audit, scope first, then batches A–E and verification.

Historical status statements describe their own checkpoints; later entries supersede them. Reordering this document does not change any finding or implementation status.

## Foundational review and early follow-ups

### Scope and method

- Starting commit: `29ce1db9bcc058009843c1d8ac42178c9f47a598`.
- Reproduction environment: Gleam 1.18.1, Erlang/OTP 29, Node v24.10.0,
  `gleam_stdlib` 1.0.3, `gleeunit` 1.11.0.
- Audit only: do not change production algorithms as part of review batches.
- Review in dependency order, recording contracts, caller assumptions, tests,
  concrete counterexamples, and remaining uncertainty.
- A reviewed module is not certified bug-free. Status describes coverage only.
- External implementations are references, not correctness oracles.

### Batch 1 — 15-minute baseline

The findings below record the original audit state. Follow-up implementation:
`number.is_zero` now explicitly accepts both signed zeros, and the reviewed
`point`, `trig`, `affine`, `root`, and numeric-support checks use it. This fixes
R6/R7/R8/R10 in the demonstrated cases. Other modules' mathematical-zero checks
have not undergone a library-wide conversion. R1–R5 and R9 remain separate work.

Verification after this fix: `gleam test` passes **1376 tests**. The eight new
tests in `test/svg_path_signed_zero_test.gleam` also passed on JavaScript,
compiled as an exact temporary copy in `examples/public_api_smoke` and invoked
with Node. The temporary source copy was removed afterward. Root-level
`gleam build --target javascript` is blocked by existing Erlang-only fixture
writers; no whole-JavaScript-suite claim is made.

Before implementing, checked F# commits `1444fd5` and `c612b7b` against the
recent Gleam changes (error causes, validation, affine errors, payload labels,
curvature API/docs and tests); corresponding changes are present. F# was clean
and was not modified by this fix.
The newly added explicit zero-vector heading convention still needs mirroring
in F# `Point.heading`; its existing numeric equality already treats signed
zeros alike, unlike the affected Erlang predicates.

- Started: 2026-09-08 03:56:51 UTC.
- Target finish: 2026-09-08 04:11:51 UTC.
- Scope: `point`, `trig`, `affine`, and directly relevant numeric support.
- Starting weekly Codex usage: 10% used, account-wide, as reported by the
  usage tool (integer-percent resolution; other activity may affect the delta).
- Finished substantive review and final checks: 2026-09-08 04:10:29 UTC
  (13 minutes 38 seconds, within the 15-minute budget).
- Ending weekly Codex usage: 12% used. Observed increase: 2 percentage points,
  account-wide and rounded, not an exact token count or isolated billing figure.

### Coverage

#### Follow-up: affine ordinary-input review at `f8922a9`

- Re-read all of `affine.gleam`, its eight tests, and the correspondence and
  composition wrappers in `transform.gleam` and `svg_path.gleam`.
- No new ordinary-input correctness bug found. Composition order, translation
  about an arbitrary center, determinant, similarity orientation, and triple
  mapping formulas agree with the documented contracts. Degenerate sources
  are rejected; collapsed targets remain permitted.
- JavaScript production-module probe: 120,003 assertions passed across 10,000
  deterministic ordinary-scale cases. These are audit assertions, not additions
  to the permanent test count or F# parity inventory.
- `gleam test`: 1455 passed at this checkpoint.
- No affine production changes made. Existing extreme-scale correspondence
  limitations remain outside this ordinary-input pass; this is not a claim of
  universal numerical robustness.
- Recent foundational fixes committed: `3c072a9` (checked arithmetic),
  `ada3613` (normalization), `7dbfee4` (projection, proximity, interpolation),
  `f8922a9` (degree reduction and angle conversion). F# mirroring remains pending.

#### Original coverage inventory

| Module | Status | Coverage / next step |
|---|---|---|
| `point` | Reviewed | All 177 lines and 9 existing tests read; finite-input numerical probes on both backends; selected heading/aperture callers inspected. |
| `trig` | Reviewed | All 176 lines and 8 existing tests read; cardinal, branch-cut, large-angle and signed-zero probes. |
| `affine` | Reviewed | All 338 lines and 8 existing tests read; correspondence solvers, composition, degeneracy, numeric errors. |
| `internal/number` | Reviewed | All definitions read; hypot, exponent parsing and overflow-guard probes; direct parser callers checked. |
| `root` | Partial | Low-degree solver entry points and exact-zero helper inspected; signed-zero counterexamples confirmed. Higher-degree isolation not reviewed. |
| `transform`, `transform/parse`, `parse`, `intersections`, `arrangement`, `degeneracy` | Partial caller follow-up only | Checked selected consumers; these modules are not fully reviewed. |
| Other modules | Unreviewed | No completeness claim from this batch. |

### Findings

#### Follow-up root/fitting review — two reproducible root findings

- On both Erlang and JavaScript, classifying coefficients
  `[1, -2, 1.375, -0.375, 0.03515625]` on `[0,1]` labels the roots near
  `0.25` and `0.75` as `NegativeToPositive` and `PositiveToNegative`.
  The polynomial is exactly `(t-0.25)^2*(t-0.75)^2`, hence both should be
  `PositiveToPositive`. The derivative fallback evaluates at an approximate
  root; its small nonzero first derivative is taken as evidence of a crossing.
  This is a confirmed classification error, but current production classified
  callers use degree at most three; no public geometry failure demonstrated.
- On both backends, isolating `[1,0,1,-0.625]` on `[0,1]` returns
  `RootIsolation(0,0.5,1)`. An exactly hit bisection midpoint retains the entire
  old bracket rather than receiving the centered window used for exact roots.
  The root estimate is correct; this is a window-consistency issue, not a
  demonstrated missed intersection.
- Read the constrained/nonnegative cubic fitting and endpoint-only fitting
  paths and their residual reports. No concrete new fitting failure identified
  in this bounded pass. This does not constitute full Bezier-module coverage.
- No production changes made for these findings.

Follow-up implementation (uncommitted): private `RootCandidate` records the
number of derivatives already known to vanish through recursive isolation.
Classification skips those derivatives instead of reinterpreting their residual
at an approximate root. Deduplication retains the stronger evidence when a root
is found both at a domain endpoint and through the derivative. Exact bisection
hits become point isolations, and exact success is checked before exhaustion in
both bisection helpers. Six new tests all failed before these changes and pass
afterward; they cover both signs of the touching quartic, odd multiplicity,
endpoint duplication, centered windows, and last-iteration success. The exact
six Gleam test functions also passed compiled to JavaScript using a temporary
copy in the public-API smoke project (temporary source removed).

#### R1 — `point.lerp` does not preserve its documented endpoint (recommended fix)

- Source: `src/svg_path/point.gleam`, `lerp` (around line 125).
- Contract says `t: 1.0` returns `b`; interpolation uses `a + (b-a)*t`
  with no endpoint fast path.
- Ordinary-scale reproduction: `a=(1,0), b=(0.1,0), t=1` returns an x
  coordinate different from the supplied `0.1`. A stronger cancellation case,
  `a=(1e16,0), b=(1,0), t=1`, returns `(0,0)` on both backends.
- Recommendation: explicit endpoint returns for mathematical `t = 0` and `t = 1`
  (including negative zero, given R6).
  Consider overflow-resistant interpolation separately, without conflating it
  with this exact endpoint promise.

#### R2 — heading/aperture can equal 360 (contract decision)

- Source: `point.heading` / `clockwise_aperture`, around lines 34–59.
- `heading((1,-1e-16))` and aperture from `(1,0)` to that vector both return
  `360.0` on Erlang and JavaScript; aperture promises `[0,360)`.
- This is final rounding near the branch cut, not a large directional error.
  Canonicalizing to zero or changing the documented range are different policies.
- Callers use these values for cyclic ordering and crossing classification;
  downstream behavioral impact has not been demonstrated yet.

#### R3 — extreme-scale vector operations (numerical range limitation)

- `normalize((1e-310,0))`: Erlang raises `badarith`; JS returns
  `Ok((Infinity,NaN))`, although the unit answer `(1,0)` is representable.
  Cause: forming `1 / length` before multiplication.
- Projection onto `(1e-200,0)` returns `Error(Nil)` because squared norm
  underflows, even with an ordinary projected point `(3,4)`.
- `near((0,0),(1e-199,0), tolerance=1e-200)` returns true on both backends
  because both squares underflow. With delta `1e200` and tolerance `1e199`,
  JS compares infinities and returns true; Erlang raises `badarith`.
- Midpoint of `(-1e308,0)` and `(1e308,0)` overflows the subtraction even
  though the midpoint is representable.
- These are finite-input cases, not demands to sanitize user-supplied NaNs.
  Severity for normal SVG coordinate ranges is low; do not equate these with
  demonstrated failures in offset geometry. Prefer stable scaling/division if
  fixing, rather than new arbitrary cutoff policies.

#### R4 — large degree angles can snap to the wrong cardinal angle (confirmed)

- Source: `trig.positive_remainder`, quarter/eighth-turn normalization.
- `sin_degrees(1e20)` returns `0.0` on both backends. The representable input
  is the exact integer 100000000000000000000, whose remainder modulo 360 is
  280; expected sine is approximately `-0.9848077530122081`.
- `gleam/float.modulo` uses `x - floor(x/360)*360`, losing the remainder
  through cancellation. The zero then selects an exact cardinal branch.
- Existing large-angle test checks only boundedness/finiteness, not accuracy.
- Ordinary non-cardinal angles also go to radians without range reduction;
  for example `360000030` differs from the 30-degree sine by about `6.7e-10`.
- Recommendation: reliable remainder computation before trigonometry, with
  backend tests; do not assume the current standard-library modulo is suitable.

#### R5 — extreme-scale affine and angle conversions (numerical range limitation)

- `degrees_to_radians(1e308)` and `radians_to_degrees(1e306)` overflow
  intermediate products although the final answers are representable.
- Triple-map identity on a triangle of side `1e200` returns
  `NonFiniteTransform`; on side `1e-200`, `DegenerateSourceTriple`.
- Pair map from separation `1e-200` to separation 1 returns
  `DegenerateSourcePair` although the desired scale `1e200` is finite.
- Affine errors currently document *computed* degeneracy, so these are
  limitations rather than false claims of exact geometric degeneracy.
  Retain that distinction. No production-scale consequence established.

#### R6 — zero-vector heading depends on signed zeros and backend (recommended fix)

- `point.heading(point.scale(point.zero, by: -1))` returns 180 on JavaScript
  and 225 on the current Erlang backend. Documentation says a zero vector has
  heading 0. This is ordinary arithmetic on a library-provided constant.
- Erlang's literal `0.0` pattern in `trig.atan2_degrees` does not match `-0.0`
  on the current runtime. Both negative-zero coordinates enter the diagonal
  branch and produce -135 degrees rather than the platform atan2 result.
- Recommendation: deliberately handle the zero-vector convention in `heading`
  and make axis detection robust to signed zero in `atan2_degrees`. Add tests
  for all four signed-zero combinations on both backends. Preserve ordinary
  nonzero direction semantics; no new tolerance is needed.
- Related ordinary-scale consequences on Erlang: `normalize((-0,-0))` returns
  `Ok((0,0))`, violating the unit-result contract, and scalar projection onto
  that zero direction returns `Ok(-0)` rather than an error. The `hypot`
  result is `-0` because `float.absolute_value` preserves negative zero and
  its zero guard also misses it. JavaScript rejects both operations.
- Do not substitute `float.compare` as a presumed repair: its current
  implementation itself uses Gleam equality before ordering comparisons.
- **Demonstrated geometry impact:** normalize the open polyline
  `(0,0) -> (-0,-0) -> (1,0) -> (1,1) -> (2,1)` with
  `degeneracy.normalize_degenerate_segments(..., 0)` on Erlang. It returns
  just the diagonal `(0,0) -> (2,1)`, deleting both real corners. With `+0`
  in place of `-0`, the three nonzero lines survive correctly. The false
  `Ok((0,0))` axis makes every line appear to have zero transverse width.
  This elevates the signed-zero normalization fix above cosmetic heading issues.
- The same failure is reachable from ordinary public SVG parsing, without
  constructing internal data: parse `M0 0 L-0 -0 L1 0 L1 1 L2 1`, extract its
  one subpath, and normalize at zero tolerance. Saved in the Erlang probe.

#### R7 — collinear triple accepted as a zero affine matrix on Erlang (recommended fix)

- Ordinary source `(0,0), (-1,0), (1,0)` and noncollinear target
  `(0,0), (1,0), (0,1)` returns `Ok` with a zero linear matrix on Erlang;
  JavaScript returns the expected `DegenerateSourceTriple`.
- The determinant becomes `-0.0` through multiplication, without requiring
  signed-zero inputs. The generated `=:= +0.0` guard misses it on OTP 29.
  Gleam's division helper subsequently returns signed zero for division by zero.
- Recommendation: zero detection that treats both signs of zero as zero;
  checking both order comparisons is one possible language-level approach.
  Do not assume that replacing a literal pattern with Gleam `== 0.0` fixes it:
  both distinguish the signs in the generated Erlang on this runtime.
- Existing collinear test covers only positive-X ordering. Add all relevant
  orderings and both targets, including collapsed targets. The `transform`
  wrapper checks mapped points afterward, but `affine` itself is public.
- Runtime observation: OTP 29 reports `0.0 == -0.0` true but
  `0.0 =:= -0.0` false. This is a concrete backend-sensitive bug, not a
  request to implement arbitrary tolerance-based collinearity.

#### R8 — negative underflow defeats exponent-parser early exit (recommended fix)

- `internal/number.scale_by_power_of_ten` stops early on a literal `0.0`.
  On OTP 29, negative underflow produces `-0.0`, missing this pattern.
- A warmed Erlang probe parsed `1e-100000000` in about 2 microseconds and
  `-1e-100000000` in about 53 milliseconds. The latter continues through
  roughly a million 100-exponent chunks after its answer is already zero.
  Times are illustrative; the linear dependence on exponent magnitude is
  visible directly in the recursion.
- Both public path parsing and transform-attribute parsing use this helper.
  An input with only a few exponent digits can therefore cause excessive work.
  Existing large-exponent tests cover positive mantissas and positive zero only.
- Recommendation: recognize both signs of zero at the early exit; no arbitrary
  new exponent limit is necessary to fix this particular case. JavaScript's
  zero equality already takes this exit.

#### R9 — checked arithmetic can overflow after its overflow check (recommended fix)

- `number.checked_product(max_finite / 3, 3)` returns `Ok(Infinity)` on JS
  and raises `badarith` on Erlang. The division used for the guard rounds up;
  equality at that rounded threshold is not enough to certify the product.
- `checked_sum(1.7658771479739417e308, 3.181598688837415e306)` has the
  same defect: `Ok(Infinity)` on JS and `badarith` on Erlang. Its subtractive
  threshold rounds, too. The repair must cover addition as well as multiplication.
- Public reproduction: construct a transform string `scale(N) scale(3)` where
  `N` is the full decimal integer representation of `trunc(max_finite / 3)`.
  Erlang's `transform/parse.attribute` raises rather than returning its
  `NonFiniteTransform` error. JS's final matrix finiteness check catches it.
- The full integer spelling matters: the parser's manual exponent scaling
  slightly changes the value of the shorter scientific spelling, masking this
  boundary case. Probe scripts construct the input exactly.
- Recommendation: actual-result finiteness verification plus Erlang arithmetic
  error conversion, or a demonstrably conservative guard. This is a parser
  error-contract defect, although its triggering magnitude is extreme.

#### R10 — low-degree root solvers manufacture roots for negative-zero coefficients

- `root.linear(-0.0, 1.0)` returns `[-0.0]` on Erlang although the constant
  equation `1 = 0` has no roots. JS correctly returns `[]`.
- `root.quadratic(-0.0, 1.0, -1.0)` returns `[-0.0, 1.0]` on Erlang;
  the reduced equation `x - 1 = 0` has only root 1. JS returns `[1.0]`.
- `coefficient_is_zero` uses the same signed-zero-sensitive equality when
  coefficient tolerance is zero. This was a focused follow-up, not a complete
  root-module audit or proof of a particular downstream intersection failure.
- Recommendation: include root degree classification in the signed-zero repair;
  do not replace exact classification with an arbitrary epsilon.

### Priorities

1. **Signed-zero family (R6, R7, R8, R10):** fix mathematical zero predicates,
   add both-backend tests, and review similarly used predicates elsewhere.
   R6 has demonstrated geometry loss; R7/R10 accept invalid mathematical results.
   Do not mechanically rewrite structural equality or every float equality:
   these findings concern places specifically testing mathematical zero.
2. **Exact endpoint promise (R1):** small, localized fix and regression test.
3. **Parser arithmetic errors (R9):** extreme magnitude, but a public parser
   should return its existing error rather than raise from checked arithmetic.
4. **Angle handling (R2/R4):** canonical range and reliable remainder logic.
5. **Extreme-scale robustness (R3/R5):** document or improve deliberately;
   not evidence that normal-scale offsetting is broken by these cases.

### Verification results

- `gleam test` completed: **1368 passed, no failures**. This is the default
  suite, not `scripts/test-all` or release verification.
- `escript examples/debug/v1_foundations_review.escript`: completed; invokes
  actual compiled Gleam Erlang modules and all 25 existing point/trig/affine tests.
  Existing tests pass; diagnostic probes above report the observed deficiencies.
- `node examples/debug/v1_foundations_review.mjs`: completed; invokes actual
  Gleam-generated JS from the external API smoke build, not copied algorithms.
- `gleam build --target javascript` in `examples/public_api_smoke` completed;
  the JS probes were rerun successfully against that refreshed build.
- Probe output is diagnostic, not a passing regression suite: each label states
  an expected property and prints the actual value/error.
- The JS probe also completed 6,000 deterministic ordinary-scale property
  checks: composition order, determinant multiplication, fixed about-points,
  pair correspondence, and reconstruction of known affine maps from triples.
  These are additional audit checks, not 6,000 existing unit tests.

### Resume

Next complete `root` (902 lines total), then proceed through `bezier` (1431),
`ellipse` (1154), and `curvature` (496), checking dependency assumptions before
each batch. The higher-level geometry modules remain unreviewed. First address
the signed-zero family if implementation is authorized; this batch is audit-only.

The four fully read foundation modules total 855 production lines, excluding
tests and the partial caller/root follow-ups. No production code was modified
and no commit was made. The report and two probe scripts are uncommitted review
artifacts, intentionally saved for reproduction and continuation.

Recommended next action: fix and test the signed-zero family before moving on
to a broad new review batch. No fixes have been applied by this review.

### Degeneracy reconstruction follow-up (2026-09-08)

The working-tree reconstruction fix replaces transverse support witnesses with
longitudinal extrema queried on the original segments and preserves endpoint
anchors. Its 11 regression tests bring `gleam test` to 1387 passing tests.
The general branch still retains only the two global longitudinal extrema,
not every successive axial reversal; this is the agreed scope of this change.

Two additional hull-stage behaviors surfaced while developing these tests and
remain unresolved (neither is repaired by the reconstruction change):

- `M0 0 Q-20 0 0 0 L3 0`, tolerance `0.0`, produces traversal
  `(0,0) -> (-10,0) -> (0,0) -> (3,0)`, whereas tolerance `1e-6` allows the
  combined replacement `(0,0) -> (-10,0) -> (3,0)`. Investigate the zero-width
  hull decision rather than weakening reconstruction expectations globally.
- `M0 0 Q-0.00000025 0 -0.0000005 0 L10.0000005 0 L10 0`, tolerance `1e-6`,
  returns `ConvexHullError(ConstructionPathError(Discontinuous(...)))` with a
  `5e-7` gap between `(-5e-7,0)` and `(0,0)`. This happens before reconstruction.
  The endpoint-priority regression uses excursions of `0.0005` and tolerance
  `0.001` to exercise that contract independently of this hull failure.

#### Subsequent resolution status

- `2d71317`: longitudinal reconstruction and endpoint-anchor fix committed;
  removed `compact_loop_pieces`. The short-connector regression passes, but
  removal exposed 18 hull-assembly failures.
- `1584d30`: non-unit vector support and conservative angular lower bounds
  committed. The unseeded collinear case returns `Unresolved`, not `Exceeds`.
- `c40509a`: source endpoints/control-point seed committed; support on actual
  segments verifies the candidate. The collinear candidate has exact width zero.
- Current uncommitted follow-up: `LoopPiece` distinguishes `FullLoop`,
  `OnePoint`, and `Portion`; `LoopParam` aliases `SubpathParameter`. Exact cyclic
  endpoint aliases are canonicalized without treating nearby parameters as a
  full loop. This resolves the 18 failures. `gleam test`: 1406 passed, including
  five additional regressions for triangle assembly, traversal reversal,
  closure aliases, full-loop containment and narrow triangle geometry.
- `remove_point_like_segments` remains a separate audit candidate; this
  refactor does not change it. F# mirroring of the follow-up work is pending.

### Signed-zero parameter follow-up after `1d32ade`

Audit only, no source edits. Actual compiled Erlang calls confirm the following
remaining `svg_path.gleam` parameter defects:

- `canonical_subpath_parameter` preserves -0.0 instead of canonicalizing it.
  For the two-line subpath (0,0)->(1,0)->(1,1), querying directions at (1,0.0)
  returns incoming=(1,0), outgoing=(0,1); (1,-0.0) loses incoming entirely.
- On the same subpath, `subpath_between((0,0.0),(1,-0.0))` adds an extra
  zero-length line at (1,0); the +0.0 version returns just the first line.
  The private interval-end helper misses its t==0.0 branch. Normalizing in
  canonical_subpath_parameter addresses both subpath issues centrally.
- `segment_point` and `segment_directions_with` directly pattern-match 0.0.
  Arc(start=(.1,.2), radius=(3,2), rotation=17, large_arc=False, sweep=True,
  end=(2,3)) evaluated at -0.0 returns (.10000000000000014,
  .20000000000000018), whereas +0.0 returns the stored start exactly.
  Directions at -0.0 incorrectly include an incoming direction at the start.
- `segment_between(arc, 0.0, -0.0)` misses from==to, producing an Arc with
  near-coincident endpoints rather than the point-like Line returned for
  (0.0,0.0). Normalize both interval parameters before equality dispatch.

The local float-list deduplicators `unique_near_sorted` and `insert_near_unique`
already use absolute differences and <= tolerance, so they treat both zeros as
equal. Parameter ordering uses float.compare, which also compares them equally.
No blanket sorting/deduplication rewrite is indicated. Recommended normalization
sites: canonical_subpath_parameter, segment_point, segment_directions_with,
segment_between. Review direct split wrappers as part of regression coverage.
Other zero comparisons on geometric lengths/function values are a separate scope.

## Module audits and implementation follow-ups

### Latest status — root and Bezier audit completed (2026-09-08)

Reviewed at `7227f07`. This section supersedes older resume/status notes below;
the older sections are historical snapshots. Root and Bezier now have complete
module-level review coverage, alongside point, trig, affine and internal/number:
six modules reviewed, with convex_hull and degeneracy substantial partial reviews.
Coverage is not a guarantee of absence of bugs. No production code changed in
this audit, and no commit was made.

Root: no additional confirmed ordinary-scale defect after `7227f07` (the
multiplicity-evidence and exact-bisection-success fixes). Checked public and
private solving/classification paths, caller assumptions, and existing tests.
A deterministic production-JavaScript probe checked all 1,286 degree-1-through-5
root multisets from the dyadic grid [-.75,-.5,-.25,0,.25,.5,.75,1], including
multiplicity and crossing/touch classification: zero failures. This is not
exhaustive evidence for closely spaced roots or extreme coefficient scales.
Machine-stagnation success in the callback bisector is an explicitly tested
existing contract, not a newly reported defect.

Confirmed outstanding Bezier findings:

1. **Missed closed-cubic endpoint intersection.** For start=end=(0,0),
   control1=(0.1,1), control2=(-1,0.2), `cubic_self_intersections` returns
   `Ok([])` on both Erlang and JavaScript, contrary to its endpoint-intersection
   contract. Instrumenting the actual generated private functions in memory
   (no copied algorithm or production-file edit) yields candidate
   `(-2.220446049250313e-16, 1)`. The strict `s >= 0 && t <= 1` gate at
   bezier.gleam:1115 rejects it. In a 361-case closed-cubic grid with
   control1=(x/10,1), control2=(-1,y/10), x,y=1..19, 73 cases missed the known
   shared endpoint on JavaScript. Add known-endpoint certification/handling;
   do not merely expand all candidate acceptance bounds without verification.
2. **Endpoint interpolation drift.** The independent private `interpolate`
   at bezier.gleam:1376 still uses start+(end-start)*t. A line (1,0)->(.1,0)
   evaluates at t=1 to (.09999999999999998,0), on Erlang and JavaScript.
   Splitting at 1 also leaves a nonzero second segment. The recently fixed
   endpoint-preserving point interpolation has not reached this independent
   implementation. Fix locally without creating a dependency cycle.
3. **Negative-zero split boundary.** On Erlang/OTP29, splitting that line with
   `split_many(curve, [-0.0])` returns two segments, whereas `[0.0]` returns one.
   `trim_start_progress` uses the literal 0.0 pattern, and exact duplicate
   comparison has the same signed-zero issue. Use mathematical-zero semantics.

Lower-priority contract/cleanup observation: tangent-constrained fitting with
only endpoint samples returns a cubic with both handles collapsed; unconstrained
fitting rejects such samples as underdetermined. The constrained solver always
includes the zero/zero candidate, so its no-candidate error branch is unreachable.
Returning a minimizer of an underdetermined fit may be intentional; this is not
classified as a confirmed geometry bug. Its contract should be clarified.

Verification in this audit:

- `gleam test`: **1461 passed, no failures** (default suite only).
- `gleam build --target javascript` in `examples/public_api_smoke`: completed.
- Production-JavaScript Bezier probe: **61,491 checks on 500 deterministic
  ordinary-scale cubics**, zero failures, covering Bernstein evaluation,
  subdivision/reparameterization, split_many, sampled bounding-box containment,
  and recovery of exact cubics by both fitters. These are additional property
  checks, not existing test-suite cases or a proof of correctness.
- Explicit defect probes above fail their expected contracts on the stated
  targets despite the passing existing suite. No regression tests added yet.

Next: resolve the three concrete Bezier findings if authorized; then continue
module review with ellipse and curvature. F# was not changed by this audit.

### Latest status — ellipse audit (2026-09-08, after `fd10a21`)

Follow-up implementation: all four findings below are now fixed (uncommitted).
Monotone collapsed lines preserve exact transformed endpoints and traversal;
the range approximation for out-and-back motion follows net displacement.
Eigenvectors are normalized after component scaling, without arbitrary-axis
fallback. Coincidence uses mathematical-zero coordinate differences. Projection
extrema enumerate repeated turns, return parameter order, and treat zero sweep
as having no isolated extrema. Removed the obsolete collapsed_candidate_angles.
Five new regressions failed before and pass after; two old transform expectations
were corrected to preserve traversal. `scripts/test-all` passed 1,494 fast tests
and 26 slow tests. The production JS audit again passed 92,826 ordinary checks
plus the focused collapse, axes, and multi-turn regressions.

This section supersedes the older outstanding-Bezier list below. All three
concrete Bezier findings there are fixed: endpoint interpolation (`72add87`),
signed-zero split deduplication (`1d32ade`), and boundary self-intersections
(`838b78d`). Endpoint-only direction-constrained fitting now returns
`UnderdeterminedCubicFit` (`fd10a21`); `scripts/test-fast` passed 1,489 tests
after that fix. Root and Bezier review is complete for this audit.

Read all 1,156 lines of ellipse.gleam, its tests, and relevant transform/root
callers. No production edits in this batch. Reproducible JavaScript probes:
`node examples/debug/ellipse_review.mjs` (requires the public_api_smoke JS build).
These call compiled production functions; no copied production algorithms.
1,000 deterministic ordinary-scale arcs passed 92,826 checks of endpoint/center
conversion, bounding boxes, projection extrema, finite-difference derivatives,
splitting, cubic approximation endpoints/continuity, and affine-transformed
geometry including reflections. These are audit assertions, not permanent tests.

Findings requiring follow-up:

1. `collapsed_arc_line` returns extrema in low/high scalar order rather than
   traversal order. Public `transform.segment_gracefully` on quarter-circle
   (1,0)->(0,1), radii (1,1), sweep=True, under diag(1,0) returns
   Line((0,0),(1,0)), reversed from the expected (1,0)->(0,0).
   Confirmed on Erlang and JavaScript. Existing test
   `graceful_arc_transform_returns_collapsed_line_test` explicitly expects the
   reversed result for a semicircle, so this needs contract/test alignment.
   Recommendation: preserve endpoint traversal when a single line suffices;
   retain the multi-line helper for out-and-back motion. No claim that the
   graceful subpath helper has this same defect (it uses the ordered helper).
2. `transformed_axes((1e-5,2e-5),17,identity)` returns radii (2e-5,1e-5),
   rotation 0, not the same ellipse. Confirmed on both backends. Its eigenvector
   has matrix-coefficient-sized components, but private `normalize` compares
   their norm to the absolute 1e-9 threshold and substitutes (1,0). Existing
   small-radius test checks radii only and misses the orientation corruption.
   Recommendation: normalize the nonzero eigenvector without that arbitrary
   direction fallback. This is a small-geometry issue, not an extreme-float one.
3. `endpoint_to_center` compares complete endpoint records using `==`.
   On Erlang, endpoints (0,0) and (-0,0), radii (10,10), rotation 0,
   large_arc=False/sweep=True return Ok(center=(0,0), start=0, delta=0), not
   DegenerateInputArc. Its evaluated point is (10,0), not either endpoint.
   Recommendation: mathematical coordinate equality via zero differences.
4. Lower-priority public extrapolation limitation: splitting a 90-degree
   CenterArcData at t=8 produces a supported 720-degree sweep, but
   arc_projection_extrema along x returns only [0,.25], omitting .5,.75,1.
   It considers each stationary angle modulo one turn only. Normal endpoint
   SVG arcs do not span multiple turns. Either enumerate repetitions or
   explicitly restrict this helper's contract.

The new probes and this audit note are uncommitted. Curvature is next; it has
not received a complete review in this batch. F# remains unchanged.

### Latest status — curvature audit completed (2026-09-08)

Read all 496 lines of curvature.gleam, all 16 curvature tests, derivative
dependencies reviewed in the preceding passes, and its production consumers
in offset.gleam (reversal discovery, inflection splits, curvature zones,
endpoint boundary payloads, tangent turn and offset direction/endpoint limits).
No new confirmed ordinary-scale defect found. No production changes in this
audit. This brings module-level coverage to eight: point, trig, affine,
internal/number, root, bezier, ellipse, curvature. Partial broader reviews of
convex_hull and degeneracy remain separate.

Verification:

- Targeted EUnit `eunit:test(svg_path_curvature_test, [verbose])`: 16 passed.
- `node examples/debug/curvature_review.mjs`: 9,307 audit assertions passed
  using compiled production modules. Covered 1,000 random cubic/ellipse pairs:
  traversal reversal, reflection, uniform scaling, subdivision invariance,
  radius/curvature reciprocity, radius proximity and residual equivalence,
  independent analytic ellipse curvature; 101 parabola parameters and analytic
  cusp locations; stationary-endpoint errors and sampled-band boundaries.
- No exhaustive-root claim. The known sampled-discovery limitation remains:
  a touching root at .5 is missed with 99 sample windows. This is expressly
  allowed by the documentation, not classified as a new bug. offset's reversal
  discovery calls this sampled finder, so completeness is not guaranteed there.
- Pointwise zero-speed errors are intentional. offset has its own endpoint
  direction-limit fallback rather than curvature claiming a one-sided limit.
- Test coverage gap: permanent curvature tests do not currently exercise
  close-band discovery; the audit probe checks its documented grid semantics.

Audit notes/probes and preceding ellipse fixes remain uncommitted. F# unchanged.

### Latest implementation — extrema-based cusp discovery (2026-09-08)

Supersedes the sampled-cusp limitation recorded in the audit below. Cusp
discovery now solves 2*C'*Q - 3*C*Q' (degree <=5) for polynomial curves, where
Q=dot(p',p') and C=cross(p',p''). Arc partitions use ellipse axis extrema.
Partition points undergo a 1e-12 relative cusp-residual cancellation check;
sign-changing intervals use bisection. Polynomial-isolation failures propagate
as CurvatureRootIsolationFailed. Existing bisection depth-limit midpoint behavior
is retained and documented. Options.samples remains validated but is only used
by sampled band discovery now.

Zero-speed points are found by solving both velocity coordinates and verifying
both at each candidate. This avoids losing a common zero when one coordinate's
double root is less stable than the other's simple root. They partition the
search but are never cusp outputs; limiting residual signs cover neighboring
intervals. Lines/zero offsets return []; a constant matching circular arc
returns [0,1]. Touch-vs-close-miss discrimination remains floating-point limited.

Eight new tests cover touches between former samples, two crossings in one old
window, a close miss, zero-speed endpoints and interior points, 99 shifted
stationary cubics, matching circles, and elliptical touches. Initial regressions
failed 6/7 before implementation; the shifted-stationary regression was added
after the independent probe exposed a weakness in the first implementation.

Verification: scripts/test-all passed 1,502 fast tests and 26 slow tests.
Production JS probes passed 9,307 earlier geometry assertions plus the new touch,
99 shifted stationary cases, and 200 random cubic cusp comparisons against a
2,000-window reference (all 213 detected sign-changing windows recovered),
including reversal and root-equation checks. No production algorithm was copied
into the probes. New source/tests and the earlier ellipse fixes are uncommitted.
F# unchanged.

### Pending follow-up — explicit curvature bisection exhaustion

Added CurvatureMaxDepthReached(lower, upper), with exact-midpoint and interval
convergence checked before depth exhaustion. Documentation updated. Three new
regressions check exhaustion and both last-depth success cases. Uncommitted.
`scripts/test-fast`: 1,504 passed, 1 failure. The sole failure is existing
`zero_tolerance_options_are_accepted_test`, which requests tolerance=0 and
max_depth=32, then assumes success. It now reports the remaining bracket
[0.4786978279007599, 0.4786978280171752]. Left that test unchanged to surface this
contract change to the user. No other fast-suite failures. This supersedes the
earlier documented silent-midpoint behavior below.

### Latest status — area audit completed (2026-09-08)

Read all 748 lines of area.gleam and its 19 tests, checked linearization
delegation and signed-area consumers in offset/arrangement. No confirmed
ordinary-scale algorithm defect found. Signed area is positive for visual
clockwise traversal; rebasing makes the implicit closing chord contribute zero.
Polynomial and ellipse integral formulas, crossing winding updates, parity,
coincident-loop aggregation, and open/move-only behavior are consistent.

Verification: targeted EUnit `eunit:test(svg_path_area_test, [verbose])`
passed 19 tests. `node examples/debug/area_review.mjs` passed 4,800 checks
against compiled production JavaScript: 300 randomized rectangle arrangements
with an independent integer-cell oracle for fill and winding magnitude,
including rotated/translated versions; 300 cases each of quadratics, cubics,
and rotated elliptical arcs checked by Simpson integration, reversal, and
subdivision additivity. No production code changed or commit made.

Documentation opportunities: signed_points/signed_segment should explicitly
state positive = visually clockwise. Fill-area docs should mention the private
1e-12 extent-relative arrangement merge threshold in addition to the caller's
linearization tolerance; near-coincident geometry can be merged even for lines.
These are not newly confirmed algorithm bugs. Approximation and clamping in
clockwiseness remain intentional. Probe is saved as examples/debug/area_review.mjs.
This brings module-level audit coverage to nine modules; partial convex-hull
and degeneracy reviews remain separate.

Curvature follow-up status: sampled band discovery was removed in a2caa2d;
zero-tolerance exhaustion regression updated in 1045251. `scripts/test-fast`
completed with 1,504 passed and no failures at that commit. Older pending
curvature entries below are historical and superseded.

### Latest status — smallest-enclosing-circle audit (2026-09-08)

Read the complete module, nine tests, and arrangement's vertex attachment and
validation consumers. Confirmed a nonminimal-circle bug on both production
JavaScript and Erlang for [(6,8), (0,-10), (-1,-10), (-7,8)]. Returned center
(2.5,-1), radius_squared=171.25; correct center=(-0.5,1/6),
radius_squared=103.61111111111111. The symmetric trapezoid's four vertices
lie on that smaller circle.

Erlang local-call tracing confirms it first finds the correct circle, then
revisits a boundary point rejected by strict floating-point containment.
enclosing_with_two_loop calls three_point_circle, which may select a diameter
circle and discard a required boundary support. Here it forgets (-7,8) and
returns radius_squared=93.25 about (2.5,-1). circle_with_exact_radius then
expands to 171.25, masking the lost containment invariant without repairing
minimality. Arrangement may therefore reject feasible endpoint clusters.
Recommended repair: preserve the fixed-boundary constraints in the two-support
solver, handle numerical boundary containment consistently, and regress this
case plus co-circular point inventories. Not implemented pending user review.

Targeted EUnit `eunit:test(svg_path_smallest_enclosing_circle_test, [verbose])`:
9 passed. `node examples/debug/enclosing_circle_review.mjs`: 11,984 randomized
integer point sets agreed with an exhaustive support-candidate oracle before
the failure; the probe reduced it to the four points above. No production
changes for this audit. Module-level audit count is now ten.

Area documentation suggestions were implemented and committed as eda3e14.

### Implemented — enclosing-circle fixed-support repair (2026-09-08)

The four-point trapezoid regression failed against the old code. The constrained
two-support loop now uses the circumcircle rather than a triple's unconstrained
minimum circle. Removed the unused triple-minimum search and Option import.
Two- and three-point circles compute radius from every defining point's squared
distance, preventing support rejection due to radius rounding. No new tolerance
constant was introduced. Added co-circular rotation/scaling, exact containment,
and permutation checks. Production/test changes are not committed.

Verification: `scripts/test-fast` passed 1,506 tests. The production-JavaScript
audit `node examples/debug/enclosing_circle_review.mjs` matched an exhaustive
support-candidate oracle for 60,000 point sets (20,000 integer, 20,000 continuous,
20,000 co-circular); all also passed containment and reversed-order determinism.

### Latest status — overlaps audit (2026-09-08)

Enclosing-circle fix committed as e6eae1b. Audited all 1,098 lines of
overlaps.gleam and all 763 lines of its shared overlap_detection helper,
35 existing tests, and the arrangement/encounters call sites. No production
changes during this audit. Two confirmed issues, reproduced on Erlang and JS:

1. A true affine overlap is rejected by a preliminary projection check.
   Quadratic (0,0), control (5,1.1076024267822504), end (10,0), against its
   reversed segment_between(0.24867968684993685,0.802967485692352) returns Ok([]).
   Even supplying the known correspondence returns Ok(None). At the middle
   interior sample, segment_projection returns t=0.4999999995343387 and
   distance=2.581272252654408e-9. Direct affine matching at t=0.5 differs by
   only about 1e-16. sampled_overlap_valid vetoes before affine checking.
   Suggested: check direct affine correspondence first, retaining geometric
   projection only to distinguish non-affine coincidence when direct checking
   fails; separately investigate projection polishing in svg_path.gleam.
2. check_parameter_correspondence only checks interior samples, never the
   proposed endpoint pairs. Lines (0,0)->(10,0) and (0,1.1)->(10,0), using
   full [0,1] correspondence, tolerance=1, samples=5, return Ok(Some(overlap)),
   despite the first endpoint pair being distance 1.1 apart. This helper is
   used by arrangement.check_edge_correspondence. Suggested: validate endpoint
   pairs too, reviewing the arrangement endpoint-cluster contract explicitly.

Targeted EUnit svg_path_overlaps_test: 35 passed. Saved probe
examples/debug/overlaps_review.mjs: 1,195/1,200 split/reversed segment cases
passed and five were missed (quadratics); piecewise forward/reverse lookup
checks passed. Two 270-degree circular arcs correctly returned two disconnected
overlap intervals in a separate probe. Suggestions are NOT implemented.
Module-level audit count is eleven, plus the shared detection helper reviewed.

### Implemented — projection isolation endpoint retention (2026-09-08)

Traced the missed quadratic overlap to svg_path.refine_isolated_distance_root_by_bisection.
The polynomial isolation [0.4999999990686774,0.5] had geometric stationary
values -2.8617227035585257e-8 and -7.040540381252397e-18. Matching signs caused
an immediate midpoint return, losing the superior upper endpoint. The no-sign-
change branch now selects the nearest geometric point among estimate/lower/upper.
No bracket expansion, new tolerance, or overlap-check reordering was introduced.
Added direct projection and overlap regressions; both failed before the fix.

`scripts/test-fast`: 1,508 passed, no failures. Production JS overlap probe:
1,200 split/reversed segment cases passed, zero missed (previously five missed).
Separate explicit-correspondence endpoint-validation issue remains unmodified.
These production/test changes are implemented, not committed.

### Implemented — explicit overlap endpoint validation (2026-09-08)

Projection fix committed as 6082627. The user accepts root.gleam's fixed 1e-12
relative near-zero policy; the close-pair/touch ambiguity is an accepted
numerical limitation, not a pending request to change its constants.

check_parameter_correspondence now evaluates both supplied right endpoints and
checks their distances to the corresponding left endpoints before interior
sampling. Mismatches return Ok(None), not NonAffineOverlapCorrespondence.
Updated docs in overlap_detection/overlaps. Added start/end mismatch regressions
in both traversal directions and a positive test exactly at tolerance. The
mismatch regression failed before the implementation. Reviewed arrangement's
sole production caller: vertex matching selects candidates, then this function
certifies correspondence; sharing a cluster is not itself proof of pairwise
coincidence within the requested edge tolerance.

`scripts/test-fast`: 1,510 passed, no failures, including arrangement tests.
Production JS overlaps_review probe: 1,200 split/reversed cases passed, and the
endpoint mismatch is now rejected. Endpoint-validation changes committed as
d4aaffd. Both original confirmed overlap-audit issues are now implemented fixes.

### Audited — encounters (2026-09-08)

Previous explicit endpoint-validation fix committed as d4aaffd. Read encounters
(1,267 lines). Targeted EUnit command `eunit:test(svg_path_encounters_test,
[verbose])` passes 25 tests. Production JavaScript probe
`node examples/debug/encounters_review.mjs` passes 60 partial quadratic overlap
cases and 40 disconnected circular-arc overlap cases, then fails on the added
closed-cubic identity regression. This probe intentionally remains red.

Confirmed upstream failure: cubic (0,0), (3,4), (-3,4), (0,0) compared with
itself returns NonAffineOverlapCorrespondence in overlaps and encounters, on
both Erlang and JavaScript. Traced actual overlap_detection calls: all four
endpoint projections select target t=0. Candidate assembly produces only
zero-span candidates and the reversed full-span correspondence (0,1)->(1,0).
Geometric sample containment accepts that candidate, but point-by-parameter
comparison rejects its orientation and immediately raises the error. The valid
identity correspondence is never proposed. This is endpoint-address ambiguity,
not a genuine non-affine overlap. Suggested repair: retain coincident endpoint
address alternatives and evaluate valid affine alternatives before concluding
that an overlap is non-affine. No implementation performed yet.

Also confirmed stale segment-query documentation: it describes unchanged
results / OverlappingSegments fallback, while the implementation partitions
overlap windows, searches off-diagonal self-intersections, filters and deduplicates.
No production changes made during this audit.

### Implemented — overlap endpoint alternatives (2026-09-08)

Added explicit target endpoint alternatives alongside each closest projection.
Non-affine candidates are collected instead of immediately raising an error;
the error remains if either parameter domain is not covered by accepted affine
overlaps. No tolerance changes or interior-multiplicity work. Added closed-cubic
identity and reversed regressions, including encounters' off-diagonal results.
Identity regression failed before the fix; reversed regression already passed.
`scripts/test-fast`: 1,512 passed. `node examples/debug/encounters_review.mjs`:
102 passed. `node examples/debug/overlaps_review.mjs`: 1,200 overlap checks passed
plus endpoint-mismatch check. Not committed yet.

### Confirmed — interior endpoint-address ambiguity (2026-09-08)

Endpoint alternatives committed as 602d2f0. Follow-up probe:
`node examples/debug/overlap_interior_addresses_review.mjs` fails as expected.
Source cubic (0,0),(-13,-16),(-26,-16),(9,0) has equal points (-9,-9)
at t=.25 and t=.75. Its exact [.25,.75] portion is the closed cubic
(-9,-9),(-14,-13),(-16,-13),(-9,-9). overlaps.segment(source,portion)
returns Ok([]), confirmed in Erlang and JavaScript. Both portion endpoints
project to source t approximately .25, losing the required .75 alternative;
explicit target endpoint checks cannot recover interior addresses. The [.75,1]
portion also loses its overlap; [0,.75] raises NonAffineOverlapCorrespondence.
No production fix performed for this follow-up.

### Implemented — interior endpoint-address alternatives (2026-09-08)

Overlap detection now queries both coordinate supporting lines through each
endpoint using the existing algebraic ray/line crossing machinery (including
angular arc roots), filters candidates by geometric distance, retains explicit
endpoints and closest projection, and deduplicates parameter addresses with
endpoint priority. Constant coordinates provide no root candidates. Coordinate
convergence errors may be ignored only when the other coordinate has reached
its degree bound with distinct verified matches; other errors propagate.
Six focused Erlang checks of the private decision function passed, using an
in-memory export_all compilation only for that diagnostic (no production API
change). Non-affinity claims now also require reciprocal sampled containment,
so a wrong endpoint pairing containing an extra loop is discarded.

The new regression exercises [.25,.75], [.75,1], [0,.75] in both directions
and argument orders, checking recovered parameter intervals and correspondence.
It failed before the implementation. Production JS encounters_review: 102
passed; overlaps_review: 1,200 cases plus explicit endpoint mismatch passed;
overlap_interior_addresses_review now passes. Final `scripts/test-fast`:
1,513 passed, no failures. No commit yet.

### Audited — congruency (2026-09-08)

Interior overlap fix committed as 2fd732c. Read all 1,195 lines of congruency.
Targeted EUnit `eunit:test(svg_path_congruency_test,[verbose])`: 41 passed.
`node examples/debug/congruency_review.mjs`: 1,000 exact Similar/Affine
point-cloud fits passed (eight points each). Two arc findings reproduced on
both Erlang and JavaScript; no production fixes performed:

1. fit_segment(..., Affine) rejects a reflected quarter-circle before fitting:
   segment_points requires identical sweep flags even though Affine explicitly
   allows reflection. Source M10,0 A10,10 0 0,1 0,10; reflected target
   M-10,0 A10,10 0 0,0 0,10. The same precheck affects fit_subpath/fit_path.
   Suggested: make the fitting point-cloud flag policy aware of transform
   family, without loosening the non-reflecting congruency checks.
2. Arc fitting uses start, antipodal-start point, end. For a semicircle the
   antipodal point equals end, so the cloud carries no transverse extent.
   M-10,0 A10,10 0 0,1 10,0 against radius(10,20) returns identity/error0
   for both Similar and Affine; actual midpoint y is -10 vs -20. Affine
   unnecessarily falls back to Similar even though the geometry determines
   the vertical scale. The documented error is point-cloud RMS, so error0
   follows that narrow definition, but the arc point inventory is inadequate.
   Suggested: include a non-collinear on-arc point (e.g. parameter midpoint)
   and document the actual cloud used by the fit API.

Module introduction also describes only similarity transforms although fit
functions support general affine transforms. Other reviewed semantics (ordered
structure, ignored closed flag, heuristic pair selection) are documented.

### Implemented — congruency arc fitting (2026-09-08)

Propagated transform family through the point-cloud builders. Affine fits
permit differing sweep flags, while Similar and congruency checks still require
matching flags. Added arc parameter midpoint to retain transverse extent when
the antipodal point equals the end. Documented the cloud and point-RMS contract.
Two regressions failed before implementation: reflected quarter-circle at
segment/subpath/path levels, and vertically stretched semicircle (Affine must
recover scale 2, Similar must report nonzero error). `scripts/test-fast`:
1,515 passed. `node examples/debug/congruency_review.mjs`: 1,000 point-cloud
checks pass; reflected arc now fits with RMS about 4.5e-16 and semicircle
recovers exact matrix (1,0,0,2,0,0) with RMS zero. Fixes committed this turn.

### Audited — transform (2026-09-08)

Read all 1,005 lines, targeted tests and delegated ellipse collapse helpers.
Targeted EUnit `eunit:test(svg_path_transform_test,[verbose])`: 47 passed.
`node examples/debug/transform_review.mjs`: 34,000 nonsingular affine samples
passed for lines, quadratics, cubics and arcs; all 500 axis-collapsed individual
arcs preserve sampled extent within 1e-6, but only 123/500 closed subpaths
reconstruct (377 Discontinuous errors). No production changes.

Confirmed on both Erlang/JS:
1. Graceful arc-to-subpath collapse computes endpoints via trigonometry rather
   than directly transforming the original endpoints. Neighboring lines use
   direct arithmetic. finalize_transformed_subpath calls strict subpath(), so
   machine-scale gaps abort. Simple source M10,4 L3,4 A5,5 0 0,1 -3,4 L10,4
   under scale_xy(1,0) errors: expected start(3,0), got(2.999999999999999,0).
   Suggested fix: preserve exact transformed first/last endpoints inside
   ellipse.collapsed_arc_points; retain interior extrema. Do not loosen strict
   continuity or add geometric healing to hide the mismatch.
2. Singular matrix(1,2,0,0,0,0) returns an Arc rather than DegenerateArcTransform
   for M3,4 A3,2 2 0,1 -3,4. Returned minor radius about 5.96e-8 despite exact
   line image y=2x. ellipse.extract_axes computes the small eigenvalue by
   subtracting nearly equal numbers, leaving a positive residual and bypassing
   graceful collapse. Suggested: stable determinant-based small eigenvalue
   calculation and explicit singularity handling; verify without introducing
   a broad near-singular rejection threshold.

Doc discrepancy: subpath_gracefully says it uses wiggle helpers to preserve
continuity, but construction is Strict; only later closure has a Wiggle fallback.

### Implemented — graceful collapsed-arc endpoint preservation (2026-09-08)

Corrected transform.subpath_gracefully documentation: reconstruction is strict,
with a Wiggle fallback only for final semantic closure. ellipse.collapsed_arc_points
now uses direct affine transformation for the first/last points while retaining
trigonometric interior extrema. Regression failed on exact endpoint equality
before the fix and now passes; covers small/large arcs, open/closed subpaths,
path wrapper and retained large-arc extrema. JavaScript transform_review:
34,000 affine samples pass and 500/500 graceful closed subpaths pass (previously
123/500). Singular-eigenvalue issue #2 remains unchanged.

### Implemented — stable transformed ellipse minor eigenvalue (2026-09-08)

Replaced subtractive small-eigenvalue formula with det(B)^2/lambda_max,
where B contains transformed ellipse axes. Original transform determinant
is also checked for mathematical zero before extracting axes. Existing length
and squared-length thresholds unchanged. Two regressions failed before fix:
oblique rank-one map must return strict error and graceful lines; invertible
scale_y=1e-8 must preserve the small axis and determinant-derived radius product.
`scripts/test-fast`: 1,518 passed. JS transform_review: 34,000 samples and
500 graceful closed subpaths passed; ellipse_review: 92,826 checks over 1,000
ordinary arcs plus focused regressions passed. Both transform audit findings
are now fixed; documentation was corrected in b5a6cab.

### Audited — csg (2026-09-08)

Read all 814 lines and the shared winding_field helper. No production changes.
Targeted EUnit `eunit:test(svg_path_csg_test,[verbose])`: 33 tests passed.
`node examples/debug/csg_review.mjs`: 196 rectangle Boolean/area checks passed.
Two confirmed findings remain unfixed:

1. Open triangular polyline (0,0)->(10,0)->(0,10), union with empty Path,
   Nonzero: InternalBoundaryTopologyError(vertex: 2, reason: SectorMismatch).
   Winding uses implicit straight closure, but csg_subpath_segments includes
   only explicit segments. Include the fill-closing edge in the arrangement
   input to match the fill contract.
2. Closed 10-by-10 square, union with empty Path, Nonzero,
   Options(tolerance: 1e-12, minimum_chord: 1e-5): Ok empty result.
   classify_boolean_edges samples at 16*tolerance but passes the default
   containment tolerance 1e-9. Both samples become Boundary, erasing the edge.
   Pass containment options consistent with the requested CSG tolerance.

Audit reproduction saved in examples/debug/csg_review.mjs. Endpoint-angle
sector ordering was also inspected; no separate confirmed failure found.

### Implemented — CSG fill closure and tolerance consistency (2026-09-08)

Included implicit end-to-start fill lines in CSG arrangement inputs and
documented their presence in the returned build. Boolean classification and
the arrangement nested-contour classifier now use the requested tolerance
for containment as well as side sampling. Three regression tests failed
before their respective fixes. `scripts/test-fast`: 1,521 passed.
`node examples/debug/csg_review.mjs`: 196 Boolean/area checks passed; open
triangle union and fine-tolerance square now each return one contour.
Both CSG audit findings below are resolved. No F# changes in this batch.

### Audited — cut (2026-09-08)

Read all 214 lines and all 14 tests; checked encounter option validation,
overlap endpoint extraction, subpath parameter comparison, and the delegated
subpath_between_many reconstruction contracts. No confirmed new correctness
bug or stale documentation found. No production changes.
Targeted EUnit `eunit:test(svg_path_cut_test,[verbose])`: 14 passed.
`node examples/debug/cut_review.mjs`: 591 checks passed, covering ordered
reconstruction, cutter permutation/duplication, closed wraparound, reverse
overlaps, quadratic/cubic/arc cutting and length preservation, and empty
subpaths. These probes are not permanent test-suite or parity counts.

#### Historical coverage snapshot after cut (superseded by the next section)

20 Gleam modules lack a completed audit in this review (targeted prior fixes
and caller checks are not full audits): svg_path, arrangement,
arrangement/drawing, basic_shapes, clip, convex_hull, degeneracy, effects,
format, inspect, intersections, marker, offset, parse, serialize, stroke,
svg, transform/parse, transform/serialize, winding_field.
overlap_detection was covered with overlaps; the other 16 completed modules
are point, trig, affine, internal/number, root, bezier, ellipse, curvature,
area, smallest_enclosing_circle, overlaps, encounters, congruency, transform,
csg, and cut. This inventory counts Gleam modules, not companion FFI files.

## Remaining 20-module audit — started 2026-09-08 20:59:27 UTC

Implementation follow-up: BS1, SE1, SE2, SE3, EF1, SP2, IX1, CL1, and CL2
were subsequently fixed in nine separate commits. EF2, AG4, and the OF7
documentation corrections have three separate documentation commits.
See [the actionable-fixes record](V1_REVIEW_ACTIONABLE.md) for commit IDs and
verification. Findings below preserve the original audit observations; the
remaining findings, including OF7's dead-code concern, have not been fixed.

Deadline 21:59:27 UTC. Completed 21:26 UTC (about 27 minutes).
User requested no fixes or commits, offset/stroke last.
This is a mechanical code/contract audit with selected production probes, not
a proof of numerical or topological completeness. Companion FFI is inspected
where applicable. Reproduction script: examples/debug/remaining_audit.mjs.

Coverage complete for the 20 remaining modules at HEAD 7345278:
svg_path, arrangement, arrangement/drawing, basic_shapes, clip, convex_hull,
degeneracy, effects, format, inspect, intersections, marker, parse, serialize,
svg, transform/parse, transform/serialize, winding_field, then offset and stroke.
The large-module passes focus on algorithm bodies, contracts, dispatch, and
failure branches; they are not a claim to have reread every wrapper line.
Earlier audit entries above remain historical records; this coverage list
supersedes their old remaining-module inventory.

No production fixes or commits. Only this log and an untracked diagnostic
script were written. Confirmed findings use actual compiled production code;
STATIC findings are hypotheses or contract concerns requiring focused tests.
Diagnostic replay: `node examples/debug/remaining_audit.mjs` (after a JavaScript
build in examples/public_api_smoke). The intentional nontermination probe is
run in a child process with a two-second timeout. These are investigation
probes, not additions to the permanent regression suite.

### Batch A coverage and findings

Read complete format (318), inspect (557), basic_shapes (285), svg (379),
winding_field (155), transform/serialize (315), transform/parse (589), and
clip (405) modules.

- BS1 CONFIRMED: basic_shapes.rect(0,0,10,10,Some(2),Some(0)) returns
  `M 2 0 H 10 V 10 H 0 Z`, area 90 rather than rectangle area 100. The
  unrounded branch retains x+rx as start, then closes diagonally. If either
  radius is zero, both effective corner radii should be zero before computing
  the start. Symmetric radius case should be tested too.
- CL1 CONFIRMED: clip of line (-2,2)->(4,2) by open triangle
  (0,0)->(10,0)->(0,10) keeps the entire line, including outside x<0 portion.
  Same class of mismatch as fixed CSG: containment implicitly closes the
  region but encounters used for splitting omit that line. Expected (0,2)->(4,2).
- CL2 CONFIRMED contract mismatch: closed square [0,10]^2 clipped by [0,20]^2
  survives wholly, but returns three open subpaths (top; right+bottom; left).
  Coincident-boundary cut points split it; retained pieces are never reunited.
  Docs say a closed input remains closed when it survives whole. Restore
  original subject if all split pieces survive, or deliberately change contract;
  preservation is the more likely intended fix.
- TS1 CONFIRMED: transform serializer silently drops shear even with
  decimal_places=None. Matrix(2,0,1e-6,2,0,0) ->
  `rotate(0) scale(2 2.00000000000025)` -> c=0 instead of 1e-6.
  rotation_scale_epsilon=1e-6 is used to recognize orthogonality regardless of
  requested precision. Use machine-precision recognition or verify reconstructed
  coefficients against intended output precision; fallback to matrix otherwise.
- No additional confirmed ordinary-input issue in format, inspect, svg,
  transform/parse. Inspect's copy-paste code cannot preserve caller-created
  NaN/Infinity; consistent with current finite-geometry audit scope.
- Winding_field: boundary fallback intentionally maps any BoundaryWinding to
  +1, losing sign/multiplicity. Documented, but callers requiring signed levels
  must not mistake it for a certified signed winding. Fixed-offset side samples
  can cross unrelated nearby edges; recorded as a sampling limitation, not a
  newly confirmed bug. Downstream review assumes reliable side samples when
  reasoning about topology.

### Batch B coverage and findings

Read parser (1,155), serializer state/command emission and numeric helpers,
marker (575), degeneracy (611), effects (1,038). Serializer options inventory
checked; most option constructor boilerplate not reread line by line.

- SE1 CONFIRMED: QuadraticBezier((0,0),(1.5,2),(.5,.5)) with
  minifying_options(5) -> `m0 0q1.5 2.5.5`, which its own parser rejects.
  minimized_number_separator examines the whole preceding group for '.', not
  its final number. A decimal in an earlier coordinate wrongly allows merging
  the final integer with the next leading-dot number. Must examine last token.
- SE2 CONFIRMED: AtSubpaths + minimized whitespace + explicit_initial_lineto
  on polyline (0,0)->(1,0)->(2,0)->(3,0) produces `m0 0h111`, a line ending
  at x=111. join_with_subpath_separators uses an empty command_separator between
  repeated numeric arguments rather than the required numeric separator.
- SE3 CONFIRMED: relative serialization of same-endpoint Arc((0,0),(0,2),0,
  False,True,(0,0)) recurses indefinitely (JS RangeError). The invented midpoint
  equals start, so recursion receives the same arc. For radius (2,2), it instead
  manufactures two arcs forming a lens. Comment claiming a library full-arc
  representation is stale: ellipse now rejects coincident endpoint form as
  DegenerateInputArc and SVG treats it as no-op. Absolute and relative outputs
  are inconsistent. Likely emit the original no-op arc or omit consistently;
  never invent a center/traversal or recurse without progress.
- PA1 CONFIRMED behavior / SVG contract issue: `M0 0L1 0ZL2 0` returns
  ExpectedMove at L2. parse_close sets active=False; ensure_active requires it
  for subsequent drawing commands. SVG permits drawing after closepath from
  the closed subpath's initial point. Repeated Z also rejected. Start a fresh
  active continuation from current when has_current=True after Z. (No fix.)
  Specification: https://www.w3.org/TR/SVG2/paths.html#PathDataClosePathCommand .
- DE1 CONFIRMED: normalize [(0,0),(10,0),(10,.0001),(1,0)] at .001 ->
  `M 0 0 H 1`, losing x=10. Axial reversal separated by a zero axial delta
  passes both product<0 tests, so both plateau extrema disappear. Preserve
  turning plateau extrema by carrying the last nonzero axial direction.
- EF1 CONFIRMED nontermination: LeaveCorner rounding radius 1 of polyline
  [(0,0),(0,0),(10,0),(10,10)] fails to terminate; JS subprocess killed at
  2 seconds. first_overlapping_segment selects zero-length segment even with
  no corner trims (0 >= length-tolerance). corners_touching_segment removes
  nothing, and resolve_overlapping_trims recurses unchanged. Check actual trim
  consumption/progress; preserve untouched degenerate segments on rebuilding.
- EF2 documentation: InvalidDistanceTolerance says strictly positive, but
  validate_round_corner_inputs accepts zero. AdaptRadius docs say repeated
  limiting, implementation is one simultaneous conservative scaling pass.
- No new confirmed issue in marker. Closed marker orientations, nearest
  nondegenerate direction searches, and viewBox/reference transform order read.

### Batch C — core geometry, hull, intersections, drawing

Mechanically inventoried core svg_path entry points and failure branches;
read constructors/rebuild, closure, parameter addressing, curve evaluation,
derivatives/directions, splitting/portions, length/inverse length, containment
dispatch, parametric fitting, and linearization. Hull review covers support,
width decisions/optimization, loop assembly/parameter semantics, prefilter,
orientation, and tangent-root refinement. Intersection review covers fast paths,
window-preserving search, legacy descent fallback, certification, deduplication,
self-intersection collection, and crossing classification.

- SP1 CONFIRMED: segment_directions of Line((0,0),(10,0)) at t=-1 returns
  incoming=(-1,0), outgoing=(1,0); at t=2 outgoing=(-1,0). Public docs permit
  extrapolation. Splitting outside [0,1] reverses one child parameterization;
  its direction is then mistaken for the original curve's direction.
- SP2 CONFIRMED behavior/contract mismatch: endpoint split of a valid quarter
  circle returns a zero-span Arc, whose segment_length fails with DegenerateArc.
  Endpoint splits are documented as valid zero-length segments. Use a point
  Line for an empty arc portion, or consistently support degenerate arc values
  downstream; the former matches the recent ellipse decision.
- AD1 STATIC: arrangement/drawing annotated winding labels still sample at
  16*tolerance while passing default containment tolerance (1e-9). Same mismatch
  as recently fixed CSG: sufficiently small sampling tolerance labels both
  sides Boundary/+1. Does not affect AG construction, but misleads debugging.
- CH1 STATIC: minimum_width_optimization_loop subtracts its roundoff allowance
  from reported bounds but partitions/prunes using raw bounds. Its no-active
  branch returns converged=True without that allowance. The analogous decision
  search was fixed to subtract before pruning. Reproduce before fixing.
- CH2 STATIC hard-error handling concern: cubic_point_tangent_roots and
  refine_polynomial_tangent_isolation assert successful root isolation/bisection
  despite convergence errors being expressible by those APIs. Geometry-scale
  termination is not guaranteed merely by 100 iterations. No ordinary-input
  crash established in this pass. Propagate errors instead of asserting if
  a reproduction is found. Do not blanket-replace all structural assertions.
- IX1 CONFIRMED: upper semicircle (1,0)->(-1,0), radii(1,1), sweep=True,
  x_axis_rotation=90, against upper semicircle (2,0)->(0,0), radii(1,1),
  rotation=0, returns InternalUncertifiedSegmentIntersection with left distance
  sqrt(2). Rotation 0 succeeds. Circular fast path compares global atan2 angle
  against local ellipse start_angle, omitting x_axis_rotation. Subtract rotation
  or use the ellipse's own point-to-parameter conversion.
- IX2 CONFIRMED missing roots: cubic x=t, y=(t-.2)(t-.21)(t-.22) against
  a straight quadratic x=t,y=0 returns only t~.2, not .21 or .22. For roots
  .2,.21,.8 it returns only .21 and .8. window_already_resolved dismisses all
  1/8-wide windows within two widths of any known intersection, without a
  uniqueness proof. Candidate windows also stop after one candidate. A found
  root cannot certify an entire neighboring window empty. Retain/refine search
  outside a justified root neighborhood. Assuming this repaired for AG review.
  Control comparison: replacing the straight quadratic by the identical Line
  finds all three roots in both examples. This isolates the generic search path
  rather than the polynomial fixture or the line/curve root solver.
- IX3 CONFIRMED classification mismatch: x=t,y=(t-.5)^3 versus y=0, both
  addressed at .5, is labeled Touching, not Crossing. Exact directions are
  collinear, and classify_directions always returns Touching in this branch
  even after sampling. Both outward-ray orders are equal, consistent with
  a nontransverse crossing. Clarify whether names intentionally classify
  differential transversality; current docs describe topological crossing.
- IX4 CONFIRMED parameter-address loss / contract concern: cubic
  ((0,0),(1,1),(-1,1),(0,0)) against Line((-2,0),(2,0)) returns only
  (left_t=0,right_t=.5), losing (left_t=1,right_t=.5). insert_intersection
  deduplicates by geometric point OR parameter-pair proximity. These are one
  geometric point but two distinct parameter pairs. The public description
  says point intersections; downstream noding needs all parameter occurrences.
  Decide explicitly whether this API preserves addresses, or provide a separate
  all-address operation. Do not assume geometric equality implies duplicate
  parameter pairs. The same risk applies at self-crossing points.

### Batch D — arrangement construction and dual

Read build/progressive insertion, overlap/intersection cuts, endpoint clustering,
image bookkeeping/certification, cyclic-order sampling, dual walking/grouping,
nested contours, and validation. Downstream reasoning assumes IX1/IX2 repaired.

- AG1 CONFIRMED: dual of two nested axis-aligned 10-by-10 squares separated
  by gap 1e-5 returns ConstructionFailed; gap .1 succeeds with three faces.
  Build succeeds in both cases (vertex tolerance 1e-9, minimum chord 1e-8).
  dual_face_walk_sample starts at chord*1e-4 and only shrinks on Boundary;
  a sample can jump entirely across the narrow face and be accepted in a
  different face. Need to certify the segment from boundary to sample crosses
  no other boundary, or determine a local clearance before assigning signature.
- AG2 CONFIRMED: two segments with shared endpoints, cubic
  (0,0),(1/3,1/6),(2/3,-1/6),(1,0) and Line((0,0),(1,0)), produce just two
  vertices and two edges, omitting their proper intersection at (.5,0).
  progressive_compare_edge skips intersection checks whenever both endpoint
  vertex pairs match. Common endpoints do not exclude additional intersections.
  This is independent of IX2: the line/curve solver can find the middle root.
- AG3 CONFIRMED structural gap: no self-intersection noding of one input segment;
  progressive_compare_edge also skips pieces already imaged from the same
  original source. A self-crossing cubic can remain one non-planar graph edge.
  Need explicit self-noding or an explicit/rejected simple-segment precondition.
  Cubic((0,-.09375),(-1/3,.13541666666666666),
  (-1/3,-.13541666666666666),(0,.09375)) has a confirmed self-intersection
  at t=.25,.75 via intersections.segment_self; build nevertheless returns
  two vertices and a single self-crossing edge.
  Same-endpoint whole curves are separately dropped by the chord cutoff: an
  existing documented minimum-chord/self-loop limitation, not a new regression.
- AG4 documentation: ArrangementVertex claims endpoint insertion-order
  independence. Enclosing-circle center is independent for a fixed sample set,
  but the greedy partition into clusters is not (overlapping candidate clusters
  and ties use existing IDs). Narrow the claim to the representative center.
  insert_atomic_segment also has an unrelated leftover parity-pruning doc block.
- AG5 NOT A NEW ISSUE (checked again): validate_edges tests only positive SUM of
  directional multiplicities, not nonnegative individual values; duplicate IDs,
  atomic intersections and cyclic-order completeness are not checked. Public
  transparent graphs are caller-responsible, but validate is not a complete
  verifier of all listed invariants. Its current docstring already explicitly
  lists these omissions; no documentation change or fix is required here.

### Batch E — offset and stroke (reviewed last)

Offset: examined public dispatch, traced provenance transitions, source
normalization, synchronized D/E refinement, stalled runs, fitting and healing,
joins, adjacent culling, offside walks, cusp rescue, final winding/parity
reconstruction, orientation, and validation. Stroke: read all 1,119 lines,
including outline construction, caps, dash extraction, and validation.
Upstream findings elsewhere in this audit are assumed repaired when assessing independent
downstream logic; inherited failures are not counted again.

- OF1 CONFIRMED: default single offset of closed square [0,10]^2 by 0 returns
  ConstructionFailed. Both offside settings fail with InBandTrimming; both
  succeed with NoTrimming or CuspTrimming. An open line succeeds. Final
  trimming initializes capacities from all graph multiplicities, including
  coincident zero-source contributions, but reconstruction walks only offset
  images. A closed coincident edge retains capacity 2 while only one eligible
  occurrence can consume it. The open-line dangling reduction happens to reduce
  it. Candidate fix: initialize reconstruction capacities from eligible offset
  occurrences, independently of the complete winding-opinion inventory.
- OF2 CONFIRMED: a sharp closing seam is omitted from join-free classification.
  Source Line((0,0),(1,0)) followed by Cubic((1,0),(2,0),(0,1),(0,0)), closed,
  offset +0.1 Round, fails untrimmed construction with closing discontinuity
  0.14142135623730953. Rotating the SAME two source segments to start with the
  cubic succeeds. split_join_free_portions only examines linear adjacency;
  mark_closed_join_free_portion marks a sole portion closed without checking
  its seam, and synchronized_join_correspondences emits no self-portion join.
  The seam needs the same smooth/corner decision as other boundaries.
- OF3 CONFIRMED: source tangent alignment also depends on the closed seam.
  Closed [Cubic((0,0),(1,.01),(2,1),(2,2)), Line((2,2),(-1,0)),
  Line((-1,0),(0,0))] leaves control1=(1,.01). Cyclically rotating the same
  segments makes control1=(1.0000499987500624,0), as intended by alignment.
  colinearize_source_tangent_policy discards the modified `next` at closure,
  so an immovable last Line cannot align the movable first Cubic. Address the
  closed rebuild limitation explicitly rather than silently dropping the edit.
- OF4 STATIC provenance error: reverse_survivor_edges reverses geometry but
  keeps arrangement_preimage unchanged. cusp_trim_subpath_from_chain and
  traced_subpath_from_cusp_trimmed then copy the old ascending preimage bounds.
  A reversed survivor thus claims the wrong endpoint-to-H-parameter mapping.
  Carry orientation or swap interval ends according to a documented directed
  interval contract. Do not conflate this with geometric REVERSED. No public
  fixture requiring a reversed cusp survivor has yet been isolated.
- OF5 STATIC empty-result mismatch: finish_cusp_trim_with_parity permits None
  only if the pre-parity retained list is empty; if parity consumes everything,
  chains=[] instead becomes InternalIToKSubpathCount(0). Compare with the
  documented optional-survivor contract. Needs a focused reproducer.
- OF6 CONFIRMED private fitting direction issue: stalled_start_control2/stalled_end_control1
  accept intersections of infinite tangent LINES with only an unsigned handle
  length check. A control point on the wrong ray can satisfy this check while
  violating the requested tangent direction. Their bisection fallback likewise
  tests a cross product, not same-direction collinearity, and accepts a zero
  vector as score zero. Validate signed direction constraints before accepting.
  Direct invocation of the unchanged compiled private stalled_start_control2
  with start=(0,0), end=(1,0), start_direction=(-sqrt(.5),-sqrt(.5)),
  end_direction=(0,-1) returns control2=(1,1). With control1=start, the
  one-sided start direction is exactly opposite the requested direction.
  No ordinary full-offset fixture isolated during this pass. The diagnostic
  exports the original compiled function in memory, not a reimplementation.
- OF7 STATIC dead/stale paths: e_join_free_endpoint_policy never returns
  FitPositionOnly, yet private fit dispatch retains several PositionOnly
  branches. Those collapsed-handle PositionOnly branches use the one-handle
  least-squares formula for a DIFFERENT control-point placement than they
  subsequently construct. Unreachable today, so remove or separately repair
  before reuse. Misattached doc comments exist on i_subpath_from_traced,
  default_distance_options, and interval_parameter; module introduction still
  refers to moved stroke functionality.
- OF8 CONFIRMED: outline_contour_probe accepts the first self-interior sample
  at chord*1e-4 without checking clearance from other contours. Like AG1, it can
  count an inner contour as a container of the outer contour when the sample
  crosses a narrow annulus. This can misorient stroke output even after fixing
  dual face sampling. Fixed-distance orient_band_subpath sampling has the
  analogous limitation. orient_outline_path of [0,10]^2 and the concentric
  square inset by 1e-5 returns signed areas [-100,-99.99960000040001]: both
  contours counterclockwise, instead of opposite orientations. This direct
  public-internal helper probe does not involve the faulty AG dual at all.
- ST1 CONFIRMED: dash pattern [0,2] on Line((0,0),(5,0)), width 1, RoundCap
  produces an empty Path. Zero-length visible dashes are discarded both in
  dash_start and dash_intervals_loop; SVG dotted strokes need those positions
  so RoundCap/Square can render them. The library advertises SVG dash semantics;
  document any deliberate deviation. Verified against SVG2's dash-position
  algorithm, which retains zero-length visible intervals and adds their caps:
  https://www.w3.org/TR/SVG2/painting.html#StrokeShape . Pattern [1,0] producing
  separate touching dashes is consistent with that algorithm, NOT a bug.
- Stroke caps correctly use the normalized source in the current code. No
  additional confirmed cap-direction regression found. Closed active-dash seam
  behavior is explicitly documented; not counted as a newly discovered bug.

### Verification

Verification: scripts/test-all completed successfully in the unchanged
production tree: ordinary profile 1,521 passed; slow profile 26 passed.
The new diagnostic probes are deliberately not permanent tests or fixes.
