# Targeted reversal-join correction — 2026-10-20

Validated correction on baseline `6da0b70`. See
`OFFSET-REVERSAL-JOIN-TRIAGE.md` for the diagnosis and pre-change evidence.

`round_join` still derives the circle turn from the actual endpoint radii around
the shared source corner. Only when the absolute angle is within the existing
`angle_tolerance_degrees` (1e-9 degrees) of 180 does it choose the sweep from
`offset > 0`. This resolves the sign ambiguity of antiparallel radii and reverses
the join when source traversal and signed offset are reversed. Other turns keep
the previous endpoint-angle rule. No options or public types change.

## Targeted evidence

- Native Erlang reduced fixture now returns areas +7.793971097219577 and
  -7.793971097219577 under opposite traversals (previously empty versus nonempty).
- All eight native JavaScript quarter-turn/reversal variants return one contour.
- Original CC01192 now returns area 26880.50880023273, length 879.9419421394238,
  and bounds agreeing with upstream within floating-point precision. CC01196 has
  identical native input/options; its differing upstream self-intersection flag
  has no native counterpart.
- Two permanent portable regressions cover 15 scale/rotation combinations in
  both traversal directions and four near-tie open-arc offset calls. Nearby
  turns at +/-1e-5 degrees retain their endpoint-derived sweep.
- The first portable Erlang run passed 834 tests and failed the new area assertion
  at a normalized difference of 2.1611547218469696e-8. That assertion's 1e-8
  threshold was stricter than the rotated endpoint reconstruction warranted.
  It now allows 1e-6 while still requiring closed, nonempty contours and reversal
  area agreement. No existing test failed in that run.

The cutoff reuses the existing internal angular tolerance, not a new
caller-visible tolerance. Nonzero angular deviations within that band are treated
as ties; outside it, behavior is unchanged. Full tests and figure comparison
are recorded below. F# is deferred.

## Full native validation

`PATH=/Users/jpsteinb/.nvm/versions/node/v24.10.0/bin:$PATH scripts/test-release`
completed with exit 0: 2,094 ordinary tests, 31 slow tests, 840 portable Erlang
tests and 840 portable JavaScript tests. Both new regressions are included.
See `offset-reversal-test-release.log`. The initial overly strict assertion
failure is retained in `offset-reversal-initial-portable.log` for transparency.

Formatting, README recipe checks (part of the release run), audit record checks,
and `git diff --check` passed. No public API changes. The user authorized
committing the correction, regressions and evidence after reviewing these results.

## Published figures and recommendation

`PATH=/Users/jpsteinb/.nvm/versions/node/v24.10.0/bin:$PATH scripts/generate-published-figures`
completed with exit 0, including another successful 2,094-test ordinary run.
All 47 SVGs (13 README, 34 Gallery) are byte-for-byte identical to pre-change
hashes. Evidence: `offset-reversal-published-figures.log` and
`offset-reversal-figure-comparison.json`.

Recommendation: retain the targeted correction. It repairs the native reversal
inconsistency and the original fixture without changing existing tests or published
figures. Diagnostic before/after preview:
`examples/debug/offset-reversal-join-correction.svg`. F# port remains pending.
