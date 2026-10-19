# Near-tangent offset repair — 2026-10-19

## Findings and retained repairs

1. Arc overlap interval extraction could create coincident-endpoint arcs from
   valid sources. The earlier uncommitted witness fallback remains: only actual
   original-interval points within tolerance can establish acceptance; otherwise
   retain the error. Source arcs are validated first.
2. Greedy enclosing-circle attachment could assign an exact repeated endpoint
   to two clusters. `best_vertex_attachment` now preserves its existing owner
   when that cluster satisfies the requested tolerance. New samples retain the
   previous radius-based policy. Edge coordinates and tolerance semantics are
   unchanged. The five-line reduced arrangement now succeeds.
3. The remaining subdivisions are driven by repeated **intersection searches**,
   not vertex-to-curve projection. For the initial circular pair near the final
   join, the true circle intersections occur at the shared endpoint and outside
   both arc sweeps. The bounded numerical solver nevertheless reports an interior
   candidate within its numerical residual bound. On the shortened children it
   reports more interior candidates. Their coordinates are close enough to satisfy
   the solver's numerical acceptance, but treating them as distinct arrangement
   nodes generates further subdivisions. The public general-search documentation
   already allows multiple approximate candidates near a tangent contact; this
   becomes an operational failure in arrangement construction.

The 70-digit Decimal calculation in `check-cut-circles.py` uses the exact binary
input floats, circular endpoint-to-center conversion and circle intersection
algebra. Parameters are converted to double for final angular ratios. The first
repeated pair's mathematical hits have approximate parameters `(1,0)` and
`(1.0000002662,-0.00103077)`; the numerical search proposes
`(0.9999998671,0.0005144033)` instead. On the next shortened pair it proposes two
interior hits, while the second mathematical circle intersection is outside both
sweeps, around `(2.99976,-1.99976)`. See `cut-circle-checks.jsonl`.

## Circular pair calculation

For two distinct circles sharing an exact endpoint P, their radical axis passes
through P and is perpendicular to the center difference. Let N be its unit
normal direction along that axis, and C the first center. Substituting P+tN into
the circle equation gives the two roots:

```text
t = 0
t = -2 dot(P-C, N)
```

The new private intersection path constructs these candidates, checks the second
against both actual arc sweeps using projection and the existing numerical and
caller tolerance bounds, then uses ordinary parameter polishing and final
certification. If both endpoints are shared, those are already the complete
intersection set for distinct circles; no third candidate is generated.

It is restricted to exactly circular corrected radii and exactly shared
endpoints. Ellipses, non-shared endpoints, non-finite arithmetic, and circles
whose center separation is small relative to their radii retain the existing
solver. The relative center-separation guard is `1e-8`; this is a conditioning
fallback, not an alteration of caller tolerance. Overlap prechecking remains in
place, so coincident arcs still report overlap. No public API additions.

The arithmetic does not depend on large-coordinate circle-square subtraction.
The center difference is normalized before computing its direction. Near-tangent
rounding can still affect a candidate, so the ordinary residual and final
certification checks remain mandatory. This does not claim a general exact
circle solver or a solution for all elliptical tangencies.

## Original outcomes

`near-tangent-shared-circle-repaired.jsonl` replays CC01267 and CC01271 through
the actual compiled Gleam JavaScript library with default offset options. Both
match the captured aggregate properties: one open contour, the expected bounds,
and length 26.393274274152024 (reverse differs by about 3.6e-15).
Observed times were 168 ms and 74 ms, compared with failure after about 16 and
48 seconds for the overlap-witness-only candidate. These are audit replay times,
not isolated benchmarks. No captured baseline result was overwritten.

Permanent regressions cover vertex identity, progressive arrangement completion,
false interior circle contacts in both orientations, a genuine second interior
intersection, two shared endpoints, continuous overlap, and both original offset
directions. Existing overlap witness regressions remain selected for portability.

## Evidence and validation

- `prepare-cut-provenance-trace.py`, `near-tangent-cut-provenance.log`: bounded
  observational trace of pair cuts and endpoint projection; production unchanged
  by instrumentation. The trace run stopped at its 60-second budget.
- `check-cut-circles.py`, `cut-circle-checks.jsonl`: independent circular check.
- `prepare-shared-circle-experiment.py`, `shared-circle-CC01267.*`,
  `shared-circle-CC01271.*`: initial copied-JavaScript prototype, before Gleam port.
- `vertex-membership-tests.log`: 2,062 ordinary tests passed after the first
  ownership implementation, before adding the circular solver.
- `shared-circle-test-release.log`: initial validation was interrupted while
  finalizing guards and tests; it is **not** release validation, despite later
  phases continuing. Use the final-run log and counts recorded below instead.

F# remains deferred. No figures regenerated and no commit made in this turn.

Final validation completed successfully with `scripts/test-release` (Node
24.10.0 on PATH): **2,067 ordinary + 31 slow + 813 portable Erlang + 813 portable
JavaScript**, all passed. This run includes the final exact-membership tolerance
check, the two-shared-endpoints guard and all new regressions. Raw log:
`shared-circle-final-test-release.log`. `git diff --check` and the immutable audit
record validator passed as well. Changes remain uncommitted.
