# Final Paper.js bug-finding audit — 2026-10-13

This closes the remaining **relevance review and selected bug-finding checks**
against pinned Paper.js revision `92775f5279c05fb7f0a743e9e7fa02cd40ec1e70`.
Subsequent status: the [stroke defect is fixed](STROKE_ZERO_ARC_FIX.md), with
the full release suite passing. The [construction/closure crash is now fixed](LARGE_CONSTRUCTION_FIX.md);
the follow-up parser overflows are also fixed (`7ddb2fc`, `256c5e1`). A subsequent
[stack investigation](STACK_OVERFLOW_INVESTIGATION.md) established small
construction/closure candidates and independently confirmed tokenizer and
command-dispatch overflow on long SVG strings.
The findings and diagnostic outputs below describe the pre-fix audit.

It is not a claim of Paper.js parity or exhaustive equivalence. No library source
was changed in this final pass. At the time of this report, two newly confirmed defects remained unfixed;
both are now fixed as noted above.

## Confirmed defects

### 1. JavaScript stack overflow during valid long-path construction

`svg_path.subpath_polyline` on 100,000 points crashes with
`RangeError: Maximum call stack size exceeded` on Node 24.10.0. The same input
succeeds on Erlang. This is the directly applicable portion of upstream
`Path.js` #1493; Paper's mutable cloning step has no counterpart and is omitted.

The JavaScript sweep also fails with **5,000 and 10,000 points**, both for repeated
`(0,0)` points and distinct collinear points. 100 and 1,000 points succeed.
These are observed samples, not a portable maximum-size threshold.

The stack identifies `custom_reconcile_segments` and the continuation passed to
`result.try` in `svg_path.gleam`. Source inspection shows recursive reconciliation
inside that continuation, which the JavaScript compiler does not turn into a
loop. This is a runtime crash on valid input, not a returned documented geometry
error. Avoiding recursion proportional to segment count is the likely repair;
no repair was attempted.

Repro: `test_paperjs/src/paper_bulk_checks.gleam`.
`bulk-construction-findings.json` records the JavaScript sweep and stack traces.

### 2. Stroke fails on zero-length lines adjacent to arcs

A valid rounded rectangle from `basic_shapes.rect` with width 300, height 180,
`rx = ry = 90`, stroked at width 30 with round joins and butt caps, returns
`OffsetError(DegenerateTangent(0.0))` on **both Erlang and JavaScript**.
The constructor legitimately clamps radii to half the corresponding dimension;
this leaves two zero-length straight edges between quarter arcs.

This was exposed by the rounded-stroke fixture in `HitResult.js` #1207.
The counterpart being tested is our generated stroke geometry, not Paper's
scene hit-test implementation. Removing only those two zero-length lines
makes the same stroke succeed and contain all three explicit upstream probe
points `(90,-10)`, `(90,190)`, `(-10,90)`.

A smaller reproduction is:

```text
M10 0 L10 0 A10 10 0 0 1 0 10
```

Stroke width 2, round join, butt cap fails. Removing the initial `L10 0`
makes it succeed. Straight-line controls with leading, interior and trailing
zero-length edges all succeed. Rounded-rectangle radius 89 succeeds; radius
90 and radius 100 (clamped in y) fail. This is a cleanup/normalization defect
on otherwise valid geometry, not a degenerate elliptical arc or an undefined
whole-path tangent. The precise failing normalization stage has not been
isolated; no fix was attempted.

Repro and controls: `test_paperjs/src/paper_stroke_zero_probe.gleam`.
Exact target outputs are preserved in `final-validation.json`.

## Remaining core blocks: dispositions

- **Shape containment:** all 17 upstream points pass for exact circular/elliptical
  arcs and rectangles, under both Nonzero and EvenOdd (34 checks per target).
  Paper's inclusive boundary booleans map to `classification != Outside`.
- **#1651:** the upstream input is an empty path carrying a singular scene matrix.
  Empty geometry containment passes. Scene-local inverse-matrix behavior has no
  counterpart; this does not establish singular-transform equivalence.
- **Interpolation:** no public path interpolation operation. Implementing it in
  an adapter would test new adapter code. Classified as inapplicable, not a pass.
- **#1493:** confirmed construction failure above, with Erlang positive control.

The prior arc, tangent and coincident-node dispositions are retained. None of
these remaining blocks is left as an unexplained "adapter required" item.
`inventory.json` is the current block ledger; older investigation reports are
historical and may retain obsolete failure/pending counts.

## Additional file screening and checks

`final-file-screening.json` lists **all 37 JavaScript files** under upstream
`test/tests`, with hashes, test-title inventory and relevance dispositions.
The original detailed inventory covers 13 files and 223 top-level blocks.
The remaining files mostly test scene trees, mutation, styling, events, DOM,
JSON, rasterization or dynamic constructors absent from this library.
Relevant extra fixtures were selected from `HitResult.js`, `Point.js` and
`SvgExport.js`; these sources are now vendored too. Four original HitResult
blocks also executed successfully against the pinned Paper runtime (335
assertions, including all 330 assertions in #1207); see
`extra-paper-fixture-validation.json`. Only the stated geometric counterparts
were tested against our library.

Additional checks passed on both targets:

- a point only `2.842e-14` from a rectangle endpoint: distance and containment;
- the diagonal distance of 10 used by the fill hit-tolerance test;
- inclusion of a stroked rectangle's outer miter corner;
- vector normalization and a 90-degree rotation;
- parsed geometry after relative decimal serialization at precision 5 and 0.

These test the shared numerical behavior, not scene selection, exact serialized
spelling, default Paper formatting, or all HitResult assertions. #1207's three
explicit points are checked on the zero-edge-removed control; its full
arc-length sampling loop was not ported because the original input already
fails stroke construction.

Existing findings remain classified: overlap-aware versus point-only
intersection conventions; tolerance-valid near-tangent candidates; different
zero-speed curvature and inverse-length conventions; approximate stroke bounds;
and 59 Boolean cases outside supported overlap correspondence. They are not
newly confirmed defects. The existing Boolean inventory remains 119
matched/adapted comparisons and 59 understood limitations out of 178.

## API suggestions, separate from bugs

No API expansion is required merely to reproduce Paper's tests.

1. A public path-level inverse tangent query could collect projection roots,
   handle stationary/straight intervals explicitly, and deduplicate canonical
   addresses. Current numerical pieces exist, but the general policy does not.
2. A three-point circular arc constructor could be useful if users request it;
   its side selection and collinear cases deserve explicit contracts. Five
   skipped Path.js cases and two constructor forms motivate tests for such a
   future feature, not a present defect.
3. If broader Boolean coverage becomes a goal, support for overlapping curves
   with different parameterizations is the substantive limitation to revisit.
   It should remain an intentional project decision, as previously agreed.

Interpolation, mutable node editing, a scene graph and Paper-compatible
serialization are not recommended additions based on this audit alone.

The previously requested [dead-code cleanup](DEFERRED_CLEANUP.md) remains deferred.

## Verification and limits

See `final-validation.json` for commands and recorded output. Diagnostics print
the known stroke failure deliberately; their exit code alone is not a clean
bill of health. The standalone JavaScript bulk reproduction exits unsuccessfully
with the stack overflow; its sweep catches and records each exception.

No source patch, release preparation, F# migration, commit or push was performed.
The last portable-suite checkpoint was 716 passing tests on each target; this
final diagnostic pass does not rerun or extend that suite, and the new failures
are not yet CI regressions. Full release tests and figures were not regenerated.

This finishes the selected upstream bug-finding exercise and relevance triage.
Unported scene assertions, arbitrary new scale/transform variants and exhaustive
coverage of every geometric input are outside that completion claim.
