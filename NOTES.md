# Notes

## Wishlist

- Full marker rendering as geometry, only if there is real caller demand. The
  current marker API computes poses and layout transforms, but does not render
  marker SVG subtrees into paths.
- SVG 2 stroke join styles `miter-clip` and `arcs`, only if real caller demand
  appears. The current stroke API covers `bevel`, `miter`, and `round`.
- Newer/proposed stroke features such as `stroke-alignment`,
  `stroke-dashcorner`, and `stroke-dashadjust`, only if real caller demand
  appears.
- Stroke hit testing, if real callers need geometry-level hit tests rather than
  renderer-level hit tests.
- Structural simplification, not smoothing:
  - remove internal contours on request,
  - merge obvious adjacent collinear lines,
  - drop or preserve degenerate pieces according to an explicit policy.
- Path normalization or canonicalization helpers, only once concrete repeated
  cleanup patterns emerge.
- Possible `intersection` module extraction in a future breaking release, while
  keeping `svg_path` as the large convenience module.
- Further orientation and topology helpers if actual caller needs appear.
- Full SVG path-module reshaping such as `svg_path/subpath` or
  `svg_path/segment`, only if the user experience clearly beats the current
  one-import convenience style.

Recently completed:

- Path offsets, including trimmed and untrimmed variants.
- Path bands, including asymmetric and untrimmed variants.
- Plain path stroking with caps and joins.
- Zero-length subpath stroke behavior for `butt`, `round`, and `square` caps.
- Ordinary open-subpath stroke cap behavior for `butt`, `round`, and `square`.
- Stroke join behavior for `bevel`, `miter`, and `round`, including
  miter-limit bevel fallback.
- SVG-style dasharray normalization and dashoffset behavior.
- SVG-style dash extraction and dashed stroke geometry.
- SVG marker pose helpers and marker layout transforms.
- Area helpers for fill-rule area, absolute winding area, signed area, and
  subpath clockwiseness.
- Cut helpers for splitting subjects by cutter intersections.
- Intersection parameter canonicalization.
- Public gallery seed file and generated candidate figures.
- Gallery figures for markers, offsets, strokes, cuts, hulls, and offset maps.
- Point helpers in `svg_path/point`, while keeping the public `Point` type in
  the root `svg_path` module.
- Root convenience wrappers for common ellipse arc and cubic fitting helpers.
- Minifying serialization options, including `H`/`V` and `S`/`T` command
  discovery.

Stabilization preference:

- Prefer examples, fixtures, and documentation cleanup over new major geometry
  features for now.
- Add new public APIs only when they cover a concrete repeated need or expose a
  coherent SVG concept.
- Wait for real bugs or awkward caller code before reshaping the offset,
  stroke, CSG, or intersection machinery again.

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

The local probe file `examples/debug/zero_length_closepath_probe.svg`
demonstrates the
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
`test_slow/svg_path_convex_hull_test.gleam`, outside normal discovery. Run it
with `scripts/test-slow`. That script temporarily parks
`test/svg_path_convex_hull_test.gleam`, copies the slow file into its place,
runs `gleam test`, then restores the smoke-test file.

Use these local helpers when iterating on the ordinary suite:

```sh
scripts/test-fast
scripts/test-all
scripts/test-slow
```

`scripts/test-fast` temporarily moves `test/svg_path_convex_hull_test.gleam`
out of `test/`, runs `gleam test`, and restores the file before exiting.
`scripts/test-all` runs the ordinary suite and then `scripts/test-slow`.

`scripts/test-all` restores `test/svg_path_convex_hull_test.gleam` if needed
and runs the ordinary `gleam test` suite.
