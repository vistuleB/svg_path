# Join/line shared endpoint omitted by intersection solver

## Fix verification

The missing stored endpoint is now included by
`intersections.line_segment_intersections_by_ray`: independently project both
curve endpoints onto the finite line and retain matches within the caller's
geometric tolerance, then combine with analytic roots using the existing
endpoint-preferring parameter deduplication. No tolerance was increased.

`near_tangent_arc_line_keeps_exact_stored_endpoint_test` failed before the fix
and now checks both argument orders and both traversal directions of each
segment. `scripts/test-fast` passes **1,606 tests**.

The saved reproducer now returns both the previous near-endpoint candidate
and the exact `(1, 0)` address. The nearby candidate is deliberately not removed:
its geometric residual passes tolerance, and these parameter pairs are not
duplicates under the existing parameter tolerance. Determining whether it
represents a second true intersection remains separate from restoring the
missing exact endpoint. The analytic ray-crossing primitive itself is unchanged.

## Original reproduction and investigation

Captured from the isolated recursive-dash stroke, outer offset +3, before caps.
The exact source segments and intersection options are in
`join_line_missing_endpoint.term`. This fixture does not need gallery generation.

Run from the repository root after an Erlang build:

```sh
escript examples/debug/join_line_missing_endpoint.escript
```

`intersections.segment_with` currently returns one intersection:

- Join parameter: `0.999895513484253`
- Line parameter: `7.905709238521863e-7`
- Point: `(430.6702027471619, 178.6947740775757)`

The join's end and line's start are exactly the same stored point:
`(430.670203101245, 178.69477431938788)`. Thus `(1, 0)` is also an exact
intersection, but is absent from the result. The two reported/geometric
locations are approximately `4.29e-7` apart, versus a `1e-9` intersection
tolerance. Investigate candidate collection, endpoint preference, and
deduplication before deciding on a fix; no cause has yet been established.

This is saved diagnostic geometry, not an approved expected-result test.
No solver changes were made when saving it.

## Analytic-path investigation

`escript examples/debug/join_line_endpoint_trace.escript` exposes the compiled
private helpers for inspection, without changing their behavior. This pair
uses `intersections.line_segment_intersections_by_ray`, then
`svg_path.arc_line_classified_roots`; it does **not** use the IX2 window solver.

The reconstructed center is `(432.36208492726405, 176.21736924819214)`.
The analytic cosine is `0.9999999999999898`, giving an aperture of
`8.18910913293408e-6` degrees. Its two raw candidates are:

- `t = 0.999895513484253`, retained;
- `t = 1.0001044893463296`, outside the sweep and rejected.

The join's exact stored endpoint remains the line's exact start, but this
analytic path never independently seeds that endpoint. The missing `(1, 0)`
is therefore not lost by downstream deduplication. Near tangency makes the
angle recovered by `acos` sensitive to floating-point discrepancies between
the center representation and the exact stored endpoints.

Recommendation: independently include geometrically verified endpoint
candidates in the arc/line crossing path, then use the existing
endpoint-preferring parameter deduplication. Do not increase a global tolerance
or assume that the nearby interior candidate is a distinct genuine crossing.
Whether that near-tangent candidate should also be consolidated needs separate
consideration. No intersection implementation or root tolerance was changed
during this investigation.
