# Notes

## Library Shape and Next Steps for 0.15.0

The library is now broader than SVG path parsing and serialization. Its public
surface has four main layers:

- Core path model: `Path`, `Subpath`, `Segment`, `Point`, construction,
  editing, splitting, joining, cleaning, parsing, serialization, and inspection.
- Numeric geometry: bounding boxes, segment optimization, distances,
  projections, true-length lookup, intersections, linearization, areas, and
  convex hulls.
- Semantic geometry: `congruency`, fill-rule containment, clipping, and CSG.
- Output-side helpers: transform parsing/serialization, `basic_shapes`,
  `effects`, and the small `svg` drawing module for tests and examples.

The current shape is coherent enough for continued 0.x releases, but the public
surface is large enough that pruning should stay active before `1.0.0`.

Next-step observations for 0.15.0:

- Keep `svg_path` as the large convenience module for now. Moving functions too
  aggressively would make common path workflows harder to discover.
- Keep implementation-heavy modules like `convex_hull` and `csg` behind concise
  README explanations plus module docs. The README should teach concepts and
  show pictures, not repeat every option type.
- `effects` is the right home for artistic one-off path rewrites such as rounded
  corners. It should not become a second geometry module.
- `clip` should remain distinct from CSG. Clipping removes portions of the input
  curves and does not add boundary bridges from the clipping region.
- CSG currently preserves contour information more than a minimal renderer
  outline would. Keep `csg.simplify_nonzero_output` as the explicit cleanup tool
  rather than making every operation silently discard internal contour lines.
- Keep replacing local point/vector arithmetic with `vec/vec2f` when it improves
  clarity, but do not force it into places where the code becomes harder to
  read.
- Avoid adding more public test-only helpers. When internals must be exposed to
  package tests, use `@internal` and names that do not look like public API.
- The test suite is now split beyond the original catch-all
  `test/svg_path_test.gleam`; continue splitting by feature when a section
  grows large enough to hide failures.

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
