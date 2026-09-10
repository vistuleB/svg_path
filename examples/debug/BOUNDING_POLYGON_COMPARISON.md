# Ordered bounding polygons in Elizabeth

Comparison on 2026-09-10. Public helper and regression tests are committed in
`785df2f`. The subsequent wiring replaces Elizabeth's unordered enclosing
points and all-pair axes with convex boundary vertices and side normals.
Two-point hulls retain an along-line axis; coordinate axes and the existing
floating-point separation allowance remain unchanged.

Both runs used:

```sh
gleam build
escript scripts/gallery/run.escript gallery-package-title-nine-offsets.svg
```

| Implementation | Wall time | Erlang reductions |
| --- | ---: | ---: |
| Unordered points / all-pair axes | 30.08 s | 6,284,656,836 |
| Ordered hull / side axes | 27.75 s | 6,162,673,419 |

The generated SVGs were byte-for-byte identical (`cmp`). This is one timing
pair, not a controlled benchmark; another F# migration task was active.
The reduction count decreased by approximately 1.9%.

The public helper's pre-wiring `scripts/test-fast` run passed 1,611 tests.
The post-wiring `scripts/test-fast` run passed 1,612 tests, including the
additional collinear-enclosure regression. No slow profile was run.
