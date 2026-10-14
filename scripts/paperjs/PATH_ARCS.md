# Path.js arc construction audit

Source: vendored `upstream/Path.js` at the revision recorded in `inventory.json`.
`extract-path-arcs.cjs` executes all six original `Path#arcTo` test blocks
against paper@0.12.18, checks their original assertions, and records runtime
arguments, errors and output geometry in `path-arcs.json`. All six blocks pass.
Runtime geometry is supplementary evidence, not additional upstream assertions.

| Case | Upstream expectation | Classification |
| --- | --- | --- |
| Three-point arc, (0,20) through (75,75) to (100,0) | Exact rounded cubic node/handle string | No direct public counterpart |
| Collinear through point between endpoints | Ends at (100,75); runtime produces a straight edge | No direct public counterpart |
| Collinear through point beyond end | Throws | No direct public counterpart |
| Collinear through point before start | Throws | No direct public counterpart |
| #1477, almost vertically aligned endpoints | First inserted node lies on through-point side | No direct public counterpart |
| #1613, coincident endpoints with radius 10 | Does not throw (zero explicit assertions) | Matches after explicit SVG arc normalization |

The first five test **construction from three points**. Our public arc entry
points take SVG endpoint/radius/rotation/flags data or ellipse center data;
there is no public three-point constructor. Computing a circumcircle and choosing
a sweep in a test adapter would implement the very behavior being tested.
Consequently these are understood API differences, not five passing library
regressions and not evidence of a defect. In particular, #1477 exercises the
choice of side made by that absent constructor, not generic arc evaluation.
The two collinear error cases also have no corresponding library error contract.

For #1613, the pinned runtime retains a single node at (10,10) and no curves.
Our parser deliberately retains the coincident-endpoint Arc. Calling
`path_normalize_svg_arcs` removes it and retains the move point, giving the
same empty geometry. Strict cubic conversion of the raw arc deliberately
returns `DegenerateArc`; conversion after normalization succeeds. The new
portable regression verifies these distinctions, the exact position and
normalization idempotence. This is an explicit-normalization adapter, not a
claim that raw parsing and Paper.js construction share a contract.

No production code changed. See `path-arcs-validation.json` for completed
verification. This closes six pending inventory blocks; it does not extend
coverage to a general three-point arc constructor or claim complete Paper.js parity.

Reproduce extraction:

```sh
node scripts/paperjs/extract-path-arcs.cjs /path/to/node_modules/paper
```
