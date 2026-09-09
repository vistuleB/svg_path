# Gallery capture fixtures

Run `scripts/generate-published-figures` from the repository root for the complete
Gallery workflow.

For just the second-offset arrangement:

```sh
gleam build
escript scripts/gallery/package_title_arrangement.escript
```

This fixture reads the shared package-title source SVG, runs the public offset
API twice at 1.05 with Miter(4), and disables offside trimming only on the second
offset. Erlang runtime tracing captures the actual final-trimming graph,
submerged classification, and final capacity assignment. No alternate pruning
solver or public debug API is introduced. Assertions require one captured final
trimming operation and successful production results.

Outputs go to `test/generated/gallery`. The canonical script promotes the SVG
to `docs/gallery`. Keep the tuple patterns and traced function names aligned
with their production definitions when those internal types change.

Rendering preserves the historical styles, overlay order, endpoint dots, and
edge labels. Yellow marks initially degree-one edges that production pruning
deletes, not merely the first serial capacity decrement. The historical SVG
is retained separately under `docs/gallery/archive` and is never a build input.
