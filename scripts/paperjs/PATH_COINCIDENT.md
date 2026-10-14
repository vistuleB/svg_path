# Path.js coincident-node simplification

The pinned upstream block `Simplifying a path with three segments of the same
position should not throw an error` constructs three nodes at `(20,20)`, calls
`Path.simplify()`, then asserts that one node remains. Despite the test title,
it checks the resulting node count as well as successful execution.

`extract-path-coincident.cjs` executes that original block against
paper@0.12.18. The assertion passes. `path-coincident.json` also captures the
input and output geometry: an open path with three handle-free nodes and two
constant curves becomes an open path with one node at `(20,20)` and no curves.
The retained position and output curves are runtime observations beyond the
literal upstream count assertion.

Our segments are edges, while Paper.js segments are nodes with handles.
Consequently the input maps to two zero-length `Line` edges; its one-node
output maps to `subpath_empty(at: Point(20,20))`, not to one output edge.
`degeneracy.normalize_degenerate_segments` with zero tolerance performs that
cleanup. The portable regression checks exact output equality, the retained
anchor, open status, empty edge list, zero length and idempotence.

This is a fixture-specific geometric counterpart. Paper.js `simplify` also
fits curves in general; our degeneracy normalization has a narrower contract.
No claim is made that arbitrary simplification inputs share behavior.

Classification: adapted geometry check. No production change. Completed
verification is recorded in `path-coincident-validation.json`.

```sh
node scripts/paperjs/extract-path-coincident.cjs /path/to/node_modules/paper
scripts/test-portable
```
