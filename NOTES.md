# Notes

## Library Shape and Next Steps for 0.11.0

The library currently has three broad layers:

- Core path model: `Path`, `Subpath`, `Segment`, parsing, serialization,
  continuity checks, bounding boxes, distances, and intersections.
- Geometry helpers: `ellipse`, `bezier`, `transform`, `trig`, and convex hull
  code.
- Higher-level semantic tools: `congruency`, which encodes policy about when
  ordered points, segments, subpaths, and paths count as the same under
  translation, rotation, and uniform scale.

The public surface is now broader than "parse and serialize SVG paths". That is
useful, but it means naming and module boundaries should get one more pass
before `1.0.0`.

Suggested follow-up work:

- Release `0.11.0` from the current version-bump commit.
- Do a naming pass before `1.0.0`, especially around
  `ellipse.arc_center_data`, `transform.point_pair_map`,
  `transform.point_triple_map`, and the `congruency` API.
- Keep replacing local point/vector arithmetic with `vec/vec2f` where it
  improves clarity.

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
