# Paper.js #1409: crossings along shared boundaries

The three assertions in pinned `upstream/Path_Intersections.js` require
`getCrossings()` to return an empty list for:

1. Two adjacent closed rectangles sharing one complete side.
2. Two identical closed rectangles.
3. Two identical closed circles represented by four cubics each.

The extracted fixtures are IDs 28–30 in `intersections.json`. Their coordinates,
zero-handle cubic straight edges, orientations and closure are retained exactly.
The expected empty lists come from upstream assertions, not a fresh Paper.js run.

## Contract-aware comparison

`intersections.subpath` rejects continuous overlaps with `OverlappingSegments`;
that is the expected point-only API behavior, not a failed crossing comparison.
Use `encounters.subpath` for overlapping operands, then
`encounters.subpath_remove_redundant_intersections` to remove addresses explained
by continuous overlap correspondences. The filtered point list is empty for
all three cases, while overlaps are preserved.

The regressions also classify every raw encounter address pair with
`intersections.classify_grouped_subpath_intersection`. Every result must be
`Touching`; neither `Crossing`, `Indeterminate`, nor a classification error is
silently accepted. This exercises the classifier even though overlap filtering
leaves no isolated points to classify.

A fourth test uses partially overlapping rectangles with two transverse
crossings. The same encounter/filter/classify sequence must retain both and
classify them as `Crossing`, guarding against an adapter that discards everything.

## Validation

`scripts/test-portable`: **675 tests passed on Erlang and 675 on JavaScript**,
including the three upstream assertions and the positive control. No discrepancy
remains in this batch, and no production code was changed. The full release
suite and figures were not rerun for this test-only addition.

Regressions: `test/svg_path_paper_crossings_1409_test.gleam`.
Generator: `scripts/paperjs/generate-crossings-1409.py`.
Both the portable suite and `scripts/test-paperjs` include the module.

```sh
python3 scripts/paperjs/generate-crossings-1409.py
gleam format test/svg_path_paper_crossings_1409_test.gleam
scripts/test-portable
```

This covers all three #1409 assertions. It does not complete the parameter-address
or crossing-classification audit for the other intersection fixtures.
