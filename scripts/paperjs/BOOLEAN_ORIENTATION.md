# Paper.js #973: signed contour orientation

The previously unadapted `Path_Boolean.js` block #973 asserts that resolving a
self-intersecting modified ellipse produces children with clockwise flags
`[true, false, true]`.

The direct comparison is **`csg.nested_contours`**, whose documented contract
preserves the signed integer winding field. It produces three contours with
exactly that orientation sequence. Their observed signed areas on JavaScript
are approximately `679.754522`, `-379.148320`, and `679.754522`.
Positive signed area corresponds to clockwise traversal in SVG's downward-y
coordinate convention.

Union with an empty path is a different operation: it preserves the selected
filled region rather than signed winding. For this input it returns one closed
contour touching itself at the two shared vertices. Its different contour count
and traversal are not a failure of the orientation-preserving operation.
The regression includes both operations to keep this distinction explicit.

## Checks

- Assert the original upstream three-child orientation sequence for
  `nested_contours`; this is an actual adapted upstream assertion.
- Compare both nested-contour and union boundaries bidirectionally against the
  pinned Paper.js resolved geometry, allowing the documented arrangement endpoint
  displacement of `1e-6`.
- Check 821 off-boundary points against Paper.js reference containment, the
  original path and both outputs.
- Compare signed winding of the nested output with the original at every point.

The supplementary reference contours and containment points are **derived from
paper@0.12.18**, not additional literal upstream assertions. They exclude points
within `0.001` of the reference boundary. `boolean-orientation.json` labels this
provenance and preserves both upstream and runtime orientation flags.

## Validation

`scripts/test-portable`: **712 tests passed on Erlang and 712 on JavaScript**,
including the orientation, winding and filled-region regression. No production
code was changed; the full release suite and figures were not rerun.

```sh
node scripts/paperjs/extract-boolean-orientation.cjs /path/to/node_modules/paper
python3 scripts/paperjs/generate-boolean-orientation.py
gleam format test/svg_path_paper_boolean_orientation_test.gleam
scripts/test-portable
```

This closes the previously unadapted #973 block. It does not change the separate
178-case geometry-comparison counts or establish full Paper.js parity.
