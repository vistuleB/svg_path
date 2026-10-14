# Path.js tangent-offset query

The pinned `Path#getOffsetsWithTangent()` block contains three assertions:

1. Missing direction returns an empty list.
2. Horizontal tangents on a radius-50 cubic circle occur at one-quarter and
   three-quarters of its length, without duplicate offsets at curve joins.
3. A diagonal direction gives two offsets.

`extract-path-tangents.cjs` executes the original block against paper@0.12.18
and verifies all three assertions. `path-tangents.json` captures its exact cubic
control points, query results and per-curve parameters. The diagonal offset
values and per-curve parameters are supplementary runtime observations, not
literal upstream expectations.

## Mapping to our API

There is **no single public path-level inverse tangent query**. Our
`segment_directions`, `subpath_directions` and `path_directions` evaluate a
known parameter; they do not find parameters from a direction.

For these regular cubic fixtures, `bezier.projection_extrema` supplies the
root finder. Given tangent direction `(dx,dy)`, use normal `(-dy,dx)`:
stationarity of the projection means the derivative is parallel to the tangent
(in either orientation). The adapter checks that each derivative is nonzero
and its cross product with the requested direction is below `1e-8`.

The horizontal query yields four segment-local roots at two joins. Public
`subpath_parameter_canonicalize` maps those to two unique addresses. The
fixture adapter collects them and removes exact duplicates with `list.unique`.
The diagonal query yields two interior roots. Splitting at each parameter and
summing segment lengths gives offsets matching the captured Paper.js output
to absolute `1e-8`; horizontal offsets are also checked against our own total
length's quarter and three-quarter values.

`test/svg_path_paper_path_tangents_test.gleam` contains these two portable
regressions using the captured cubics, not our exact circular arcs. This tests
root finding, address canonicalization and length measurement. Path-wide
collection and duplicate removal belong to the test adapter, not an existing
library tangent-search function. It does not establish general equivalence
for stationary points, straight segments, approximate endpoint roots or seams.
The missing-direction assertion has no counterpart: our APIs require a typed
argument, so it is an understood calling-convention difference.

Classification: two adapted geometric assertions; one no-counterpart
calling-convention assertion. No production change. Completed validation is
recorded in `path-tangents-validation.json`.

```sh
node scripts/paperjs/extract-path-tangents.cjs /path/to/node_modules/paper
scripts/test-portable
```
