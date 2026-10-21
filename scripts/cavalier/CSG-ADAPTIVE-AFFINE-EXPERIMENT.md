# Bounded affine arc reconstruction — 2026-10-21

CSG reconstruction now bounds both midpoint-fixed affine adjustment and its
similarity fallback before considering subdivision.

## Algorithm

Try an affine map fixing the parameter midpoint and moving the endpoints to the
arrangement vertices. Decode the resulting SVG arc and bound its displacement
from the original center-form source interval. Accept only if the bound is at
most the existing arrangement tolerance. If that candidate fails, try an
endpoint-matching similarity transform under the same bound. If both fail,
bisect the original interval; new internal endpoints stay on the source ellipse. Depth is capped at 3, hence
at most eight pieces per original arc. An exhausted branch fails the operation
with the existing ArrangementGraphError(ConstructionFailed); no public error
variant was added. Stored arrangement edges remain unchanged.

The bound writes both curves as C + U cos(w*t) + V sin(w*t), accommodating changed
rotation, axis order and orientation. It takes the smaller of (1) a direct bound
from center/basis/frequency differences and (2) maximum endpoint displacement
plus one eighth of a bound on the second derivative of their difference.
This is an analytic bound evaluated in ordinary floating point, not certified
interval arithmetic. It bounds corresponding normalized parameters, and hence
also provides a positional correspondence. It does not guarantee tangent
continuity. Similarity is permitted only when the bound passes.

## Focused results

- Focused `gleam test --target javascript`: 104 passed, zero failures.
- Focused `gleam test --target erlang`: 104 passed, zero failures.
- Harness prepared by `python3 scripts/cavalier/prepare-csg-affine-focused.py`;
  both commands run in `/tmp/csg-affine-focused`.
- 181 Boolean audit cases: 165 successes, the same 16 existing failures; no
  additional failures. Every successful output has exact endpoint joins.
- 384 adjusted arc intervals checked in those successes, all accepted without
  subdivision. Maximum displacement at 129 samples per interval: 4.915100078e-7,
  below tolerance 1e-6.
- Synthetic sweep: all 72 cases succeed. Piece counts: 58 with one, six with two,
  eight with three. Maximum sampled displacement: 2.607663709e-7. Exact outer
  endpoints and joins on every successful case.
- The eight shallow failures of the initial adaptive experiment were regressions
  caused by removing similarity, not inherent limitations. Restoring it behind
  the same bound recovers all eight without accepting the excessive near-full
  deformation. The near-full eccentric fixture still needs subdivision.

Tests retain the shallow similarity regression, now with a displacement check,
and add a sweep over rotated/eccentric shallow arcs in both displacement
orientations. Additional tests cover a near-full eccentric ellipse, excessive
endpoint displacement, and unchanged-arc identity. Existing affine midpoint,
reverse traversal and transformed-ellipse regressions remain.

## Reproduce diagnostic records

After compiling the focused JavaScript harness, run:

```sh
python3 scripts/cavalier/instrument-csg-adaptive.py
node scripts/cavalier/check-csg-adaptive-synthetic.mjs > scripts/cavalier/csg-adaptive-synthetic.json
node scripts/cavalier/probe-csg-adaptive.mjs > scripts/cavalier/csg-adaptive-boolean.json
```

Instrumentation changes only the disposable generated JS module. Rebuild that
module before instrumenting again. The JSON records include accepted intervals
and sample maxima. Diagnostics can include successful children of a subsequently
failed parent; only successful top-level cases count as accepted output.

## Full validation

`PATH=/Users/jpsteinb/.nvm/versions/node/v24.10.0/bin:$PATH scripts/test-release`
completed successfully on 2026-10-21:

- Main suite: 2,119 passed.
- Slow suite: 31 passed.
- Portable all-profile Erlang: 865 passed.
- Portable all-profile JavaScript: 865 passed.

This includes the shared ellipse-axis correction below. The F# port remains
outstanding.

`scripts/generate-published-figures` also completed successfully: its main-suite
run passed 2,119 tests, and all 13 README plus 34 Gallery figures regenerated.
Compared with the pre-run workspace snapshot, 45 SVGs are byte-identical. Only
`gallery-difference-circle-rectangle.svg` and
`gallery-intersection-circle-rectangle.svg` changed: three serialized axis
rotation values on circular arcs with equal radii 67.5. No other SVG tokens
changed, so these rotations do not alter the rendered geometry. Both regenerated
Gallery files accompany the implementation. The pre-existing README
`band_cusp_trimming.svg` workspace change is unrelated and is not included.

## Shared ellipse-axis correction

The ellipse transform uses the scaled half-angle atan2 formula to extract axis
directions. The former fixed off-diagonal cutoff discarded small shears of
nearly circular ellipses and could amplify an endpoint adjustment. The new
semicircle regression covers this interaction; the old normalization helper
became unused and was removed.
