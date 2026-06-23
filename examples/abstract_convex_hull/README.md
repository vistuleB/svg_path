# Abstract Convex Hull Experiment

This is a walled-off Gleam playground for the idea that two convex loops can be
unioned without knowing what their parameters mean.

The abstract solver in `src/abstract_union.gleam` asks each loop for support at
an angle, refines angles where the support winner changes, and returns pieces
with provenance:

```gleam
HullLineAB(a, b)
HullLineBA(b, a)
LoopPieceA(a1, a2)
LoopPieceB(b1, b2)
```

The concrete escape hatch is also abstract: each loop can turn a parameter pair
into SVG path segments, and the solver can turn the abstract pieces into a
closed `Subpath`.

Current fixtures:

- `polygon_loop.gleam` is an exact convex polygon implementation for checking
  the topology of the abstract algorithm.
- `face_polygon_loop.gleam` and `face_union.gleam` start the face-aware version
  of the abstraction. Support can return either a point or a flat face, and
  face/face ties can distinguish overlapping and merely touching aligned faces.
- `segment_hull_loop.gleam` wraps the real `svg_path/convex_hull.segment_hull`
  output. Curved support is currently sampled, not solved exactly.

Run from this directory:

```sh
gleam run -m main
```

The latest generated artifacts are in `output/`.

Useful current observations:

- The polygon fixture produces a clean abstract union with two retained loop
  pieces and two transition lines.
- The face-aware square fixtures preserve top-edge ties as faces. Overlapping
  squares report the overlap interval; touching squares report the shared
  endpoint instead of inventing a support point in the middle of a line face.
- A rectangle that swallows a square in width while sharing the same top and
  bottom lines behaves the same in both argument orders: the rectangle wins
  left/right support, while top/bottom support are face ties whose overlap is
  the square's full top or bottom edge.
- Additional face-aware fixtures cover a small square tucked into a larger
  square's corner, a diagonal parallelogram whose opposite corners coincide
  with the larger square's diagonal corners, and a triangle cutting through a
  square. These exercise point/point ties, point/face ties, face/face overlaps,
  and ordinary ownership changes.
- The real segment-hull fixture produces a closed path too, but still has small
  transition-edge noise and approximate support for curved pieces.
- Cubics can also be split at inflection roots into primitive-plus-chord convex
  loops, then folded through the abstract two-loop union. The first pass over
  the old cubic specimen list passed support checks for all 45 cubics at
  10-degree directions.
- A denser 1-degree support-error comparison against production `segment_hull`
  found both algorithms at floating-point-noise scale on the old cubic corpus.
  The diagnostic is slow because it repeatedly minimizes support over many
  generated hull segments; see `output/comparison_output.txt`. Replacing the
  primitive cubic support oracle with an analytic root-solved version did not
  change the topology or produce new support errors.
- The next useful improvements are probably exact support for `segment_hull`
  loop pieces, better transition coalescing, and examples with three or more
  loops folded through the same two-loop union.
