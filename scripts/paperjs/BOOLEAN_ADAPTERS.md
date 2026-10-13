# Seven Boolean adapter cases, 2026-10-13

These seven comparisons were previously unexecuted by the area-Boolean screen.
All can be expressed for their specific inputs using existing public operations.
No production code was changed. This does not add a general outside-clipping or
per-operand mixed-fill-rule API.

| Fixture | Upstream behavior | Gleam composition |
| --- | --- | --- |
| 26 / #757 | Clip an open zigzag, then explicitly join result children | `clip.path`, then `subpath_join_with(..., Bridge)` |
| 71 / #1221 | Retain rectangle boundary outside a circle | `cut.path`, then retain outside pieces by containment |
| 73 / #1221 | Retain an open cubic curve outside a rectangle | Same outside-piece selection |
| 75 / #1221 | Repeat with a shorter clipping rectangle | Same outside-piece selection |
| 77 / #1221 | First child of a divided vertical line | `cut.path`, require two pieces, select the first |
| 78 / #1221 | Second child of the same division | Require two pieces, select the second |
| 44 / #877 | Even-odd compound shape minus a nonzero rectangle | `csg.difference_path(..., EvenOdd)`; the simple rectangle has identical fill under either rule |

## Important adaptations

Fixture 26's expected path includes four straight bridges between separated
clipped pieces. Those are created by explicit upstream `join()` calls after
clipping, not by `intersect(..., {trace:false})` itself. Our test first requires
five clipped pieces and then joins them with the explicit `Bridge` policy.
It does not change clipping to insert boundary segments.

The outside-selection adapter is test code: cut the original subject at region
intersections, then classify an interior point on each piece's first segment.
These fixtures have no positive-length boundary overlap; the cuts partition each
piece into a constant inside/outside region. Boundary samples are rejected by
the adapter rather than silently assigned a policy. Returned curves retain their
original parameterization, orientation and traversal order. This is not a generic
outside-clipping implementation or a claim about all tangent/overlap cases.

For fixture 44 the right operand is a simple rectangle. Its nonzero and even-odd
filled sets coincide mathematically, so the common even-odd rule preserves both
operands' intended regions. The left operand retains its even-odd hole. Arbitrary
operands with different fill rules still require additional adaptation; the public
binary CSG function continues to accept one common rule.

## Extraction repair

The original extraction lost provenance when upstream selected a child of an
operation result (26, 77, 78). `extract-boolean-adapters.cjs` reuses the pinned
extractor, additionally recording operation provenance on result children. It
writes only `boolean-adapter-fixtures.json`, leaving the original 178-fixture
snapshot unchanged. All seven expected geometries and strings are identical to
the original snapshot. The four previously captured operand pairs also match
exactly. Expected results still come from upstream assertions.

## Verification

`scripts/test-portable`: **711 passed on Erlang and 711 on JavaScript**,
including all seven new adapter regressions. No discrepancy remains in this
batch. The full release suite and figures were not rerun for test-only changes.

Seven portable regressions check output piece count, closure, length and
bidirectional boundary samples. Open results additionally check the ordered start
and end points of each piece. Fixture 44 checks signed area and representative
fill classifications, including the hole and the removed rectangle region.
Rounded expected curves use `1e-4` boundary/endpoint distance and `1e-3` total
length allowances; production operation tolerances remain at defaults.

```sh
node scripts/paperjs/extract-boolean-adapters.cjs /path/to/node_modules/paper
python3 scripts/paperjs/generate-boolean-adapters.py
gleam format test/svg_path_paper_boolean_adapters_test.gleam
scripts/test-portable
```

The original 178-case JavaScript area screen still labels these seven as requiring
adapters; its historical counts are not rewritten. These separate native adapted
checks supplement that screen. Sampling and these regressions do not establish
full Paper.js parity.
