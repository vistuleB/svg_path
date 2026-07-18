# Notes

## Final Major Feature Candidates

The library now covers much more than SVG path parsing and serialization:

- Core path model: `Path`, `Subpath`, `Segment`, `Point`, construction,
  editing, splitting, joining, cleaning, parsing, serialization, and inspection.
- Numeric geometry: bounding boxes, segment optimization, distances,
  projections, true-length lookup, intersections, linearization, areas, and
  convex hulls.
- Semantic geometry: `congruency`, fill-rule containment, clipping, and CSG.
- Output-side helpers: transform parsing/serialization, `basic_shapes`,
  `effects`, and the small `svg` drawing module for tests and examples.

Two major features would make the package feel close to complete:

1. Path offsets.
2. Path stroking, including dash arrays, caps, joins, marker/decorator
   placement, and SVG-style stroke semantics.

After those, the remaining useful feature areas are probably smaller and more
selective:

- Path normalization or canonicalization pipelines. This would gather existing
  operations such as arc-to-cubic conversion, curve linearization,
  zero-length cleanup, empty-subpath handling, and maybe fill-rule orientation
  normalization behind clear public presets.
- Structural simplification, not smoothing. Reasonable package-level cleanup
  includes merging adjacent collinear lines, removing redundant repeated points,
  collapsing explicit backtracking when requested, and removing zero-length
  artifacts according to the existing move-only semantics. Curve fitting,
  smoothing, and aesthetic simplification should probably live in specialized
  packages.
- Stroke hit testing. If stroking returns a filled outline, callers can already
  use containment on the produced path, but direct helpers for "point inside
  stroke" or "point near stroked path" may still be ergonomic.
- Orientation and topology helpers. Some CSG internals may be worth exposing in
  smaller form: classify subpath orientation, orient clockwise/counterclockwise,
  group nested contours, or distinguish outer contours from holes under a fill
  rule.
- Marker and decoration placement as geometry. This overlaps with stroking but
  is not identical: `marker-start`, `marker-mid`, `marker-end`, repeated
  decorations along length, tangent extraction, and arrowheads converted to
  paths can be valuable independently.

Ongoing pruning principles:

- Keep `svg_path` as the large convenience module unless a smaller module has a
  very clear separate identity.
- Keep implementation-heavy modules like `convex_hull` and `csg` behind concise
  README explanations plus module docs. The README should teach concepts and
  show pictures, not repeat every option type.
- Keep `clip` distinct from CSG. Clipping removes portions of input curves and
  does not add boundary bridges from the clipping region.
- Keep `effects` for artistic one-off path rewrites. It should not become a
  second geometry module.
- Do not add more public test-only helpers. When internals must be exposed to
  package tests, use `@internal` and names that do not look like public API.

## Move-Only vs Closed Zero-Length Subpaths

SVG can distinguish a pure moveto from a closed zero-length subpath:

```xml
M 0,0
M 0,0 Z
```

SVG 2 Painting says a subpath consisting only of a moveto is not stroked, while
other zero-length subpaths such as `M 30,30 Z` follow the `stroke-linecap`
zero-length behavior. With `round` or `square`, that can produce a visible
dot/square where pure `M 30,30` does not.

The local probe file `zero_length_closepath_probe.svg` demonstrates the
expected distinction:

```xml
<path d="M 90,50" style="fill: none; stroke: black; stroke-width: 24; stroke-linecap: round;" />
<path d="M 240,50 Z" style="fill: none; stroke: black; stroke-width: 24; stroke-linecap: round;" />
```

## Closepath Normalization

We are comfortable normalizing these two forms to the same semantic
representation:

```xml
M 0,0 L 10,0 Z
M 0,0 L 10,0 L 0,0 Z
```

In the first form, `Z` supplies the straight return-home connection. In the
second form, the explicit `L 0,0` has already returned to the subpath start,
and `Z` marks the subpath as topologically closed.

The SVG spec describes `Z` as closing the current subpath by connecting the
current point back to the initial point, with the automatic straight line
allowed to be zero length. We read this semantically rather than as a
requirement to append a distinct zero-length segment whenever the current point
is already home. This matters for ordinary cases such as a subpath whose final
drawn segment is a cubic ending at the start point:

```xml
M 0,0 C 10,0 10,10 0,0 Z
```

We do not know of an SVG spec requirement or concrete user-agent behavior that
distinguishes the first two forms above after the path has been interpreted.
The library may therefore flatten both to the same segment list plus
`closed == True`, while acknowledging that raw command-list structure is not
preserved.

## Test Speed

`gleeunit.main()` discovers every public function ending in `_test` under
`test/`, so running one test module through Gleam does not restrict discovery
to that module. The ordinary `gleam test` suite includes the convex hull smoke
tests and deterministic point-cloud tests under `test/`.

The slower convex hull stress module lives at
`test_slow/svg_path_convex_hull_test.gleam`, outside normal discovery. To run
it, temporarily park `test/svg_path_convex_hull_test.gleam`, copy the slow file
into `test/svg_path_convex_hull_test.gleam`, run `gleam test`, then restore the
smoke-test file.

Use these local helpers when iterating on the ordinary suite:

```sh
scripts/test-fast
scripts/test-all
```

`scripts/test-fast` temporarily moves `test/svg_path_convex_hull_test.gleam`
out of `test/`, runs `gleam test`, and restores the file before exiting.

`scripts/test-all` restores `test/svg_path_convex_hull_test.gleam` if needed
and runs the ordinary `gleam test` suite.
