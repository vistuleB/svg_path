# Zero-length lines beside arcs: stroke fix

A valid rounded rectangle (width 300, height 180, corner radii 90) contains
zero-length straight edges where the quarter arcs meet. Stroking it returned
`OffsetError(DegenerateTangent(0.0))` on both targets. The smaller input
`M10 0L10 0A10 10 0 0 1 0 10` failed too; removing its zero-length line made
it succeed. The rounded rectangle comes from Paper.js HitResult.js #1207.

Generic degeneracy cleanup intentionally leaves individual line segments
unchanged. A point line beside an arc need not belong to a larger line-degenerate
window, so it can survive until offset construction requests its tangent.

`offset.normalize_source_subpath` now removes exact zero-length **lines** when
other segments remain, before short-run normalization and tangent processing.
It reconstructs an open or closed source with strict continuity. Arcs and
nonzero lines are retained. All-point inputs keep their existing behavior,
including `offset.segment` rejecting a standalone point line. No constructor,
public API or generic degeneracy-cleanup contract changes.

The portable regression module `svg_path_stroke_zero_arc_test` has three tests:

- leading, trailing and interior point lines beside arcs, both traversal
  directions and all cap styles; outputs equal their point-line-free controls;
- maximum/clamped-radius rounded rectangles, including the three explicit
  upstream seam-containment points;
- standalone degenerate offsets, a nonzero short line and undefined SVG arcs
  retain their existing behavior.

Validation: `scripts/test-release` completed successfully: **1,977 fast**,
**26 slow**, **719 portable Erlang** and **719 portable JavaScript** tests.
Formatting and `git diff --check` passed. Validation used the current working
tree, including pre-existing uncommitted work; that unrelated work is excluded
from this commit. Published figures were not separately regenerated.
The separate JavaScript long-path stack-overflow finding is not changed by this fix.
