# ArrangementGraph CSG Plan

## Current module layout

- `svg_path/arrangement_graph` owns graph construction, validation, low-level
  boundary extraction, and diagnostic drawing.
- `svg_path/winding_field` owns trusting point and segment-side winding samples.
- `svg_path/csg` is the public path-operation facade for union, intersection,
  difference, symmetric difference, and monotone contours.
- `svg_path/legacy/csg` and `svg_path/legacy/robust_union` retain the superseded
  implementations until their remaining useful fixtures have been migrated.

## Historical robust-union position

The arrangement pipeline now retains atomic records through noding,
classification, threshold emission, candidate selection, and tracing.

Each atomic record carries:

- a unique emitted occurrence ID;
- its source segment occurrence;
- operand provenance;
- source subpath and segment indices;
- an overlap-group ID;
- left and right fill levels;
- an output contour level.

Tracing consumes occurrences by ID. It no longer removes pieces by geometric
equality.

The current implementation also:

- resolves one owned contributor for each two-piece overlap group and output
  level;
- retains equal-level filled overlaps as back-and-forth slit contours;
- prevents slit pieces and fill-separating pieces from joining during tracing;
- preserves contributor direction across reversed overlaps.

The best full-suite result is 413 passing tests and 4 reported failures. One is
the `four_square_union_nonzero_test` assertion. The other three reports are the
existing timeout cascade from
`arcs_sharing_two_endpoints_are_two_point_intersections_test`.

## Evidence from the remaining cases

### Four touching squares

The traced result has the required geometry:

- one outer boundary;
- one central square boundary;
- four two-segment slit contours.

It therefore has six subpaths and four back-and-forth subpaths as expected.

The central square bounds an unfilled hole, but unconditional clockwise
normalization turns it into a filled contour. The reported area is 17 instead
of 16.

Piece-local side levels cannot reliably repair this after tracing because
candidate reversal swaps the side metadata of individual pieces. The contour
needs a stable role that survives all reversals.

### Three coincident contributors

A prospective test using three identical same-direction contours produces
winding depth 6 instead of 3.

The current overlap groups are assigned per pair encounter. With three
contributors, the same geometric overlap belongs to several pair groups.
Ownership is therefore resolved more than once.

Pairwise overlap groups must be merged into equivalence classes before output
ownership is selected.

## Required additions

### 1. Overlap equivalence classes

Replace independent pairwise overlap-group IDs with arrangement-wide
equivalence-class IDs.

An overlap member should identify at least:

```gleam
type OverlapMember {
  OverlapMember(
    source_occurrence: Int,
    from: Float,
    to: Float,
  )
}
```

An equivalence class represents atomic spans known by encounter data to be
coincident. It must not be inferred later by comparing segment endpoints.

Required behavior:

1. Create one relation for every `overlaps.Overlap` encounter.
2. Split all source occurrences at all overlap endpoints first.
3. Associate each resulting overlap span with the relations that cover it.
4. Merge relations that share an atomic overlap member.
5. Assign one stable class ID to every member of the merged class.
6. Use `(overlap_class, output_level, boundary_role)` for ownership.

This is a union-find problem. A simple immutable equivalence-list
implementation is sufficient initially; performance optimization can follow
after correctness.

### 2. Explicit boundary role

Add a role to classified output occurrences:

```gleam
type BoundaryRole {
  OuterBoundary
  HoleBoundary
  InternalLevelBoundary
  EqualLevelSlit
}
```

The exact constructors may change, but the following distinctions must remain:

- a fill-forced boundary separating level zero from a positive level;
- whether level zero lies on the contour-interior side;
- an internal boundary separating two positive levels;
- an equal-level overlap retained as a slit.

Role assignment must happen during field classification, before tracing.

For a fill-forced atomic piece, classification knows which side is level zero.
When the piece is reversed, its side levels and directed role must be reversed
together. A boolean `zero_on_left` or an equivalent directed representation can
be used internally.

### 3. Contour-role continuity

Candidate collection currently filters by:

- output level;
- equal-level versus separating role.

Extend this to require compatible directed boundary roles.

At minimum:

- slit pieces continue only into slit pieces;
- internal level boundaries continue only at the same output level;
- fill-forced boundaries preserve the same filled-side/zero-side relation;
- a U-turn remains valid only when it is the sole compatible continuation.

Candidate reversal must update all directed metadata before compatibility is
tested.

### 4. Role-aware contour assembly

Tracing should return a contour record rather than only a subpath:

```gleam
type OutputContour {
  OutputContour(
    subpath: svg_path.Subpath,
    output_level: Int,
    role: BoundaryRole,
  )
}
```

Assembly rules:

- `OuterBoundary`: orient clockwise.
- `HoleBoundary`: orient counterclockwise.
- `InternalLevelBoundary`: orient clockwise to preserve the existing Nonzero
  output contract.
- `EqualLevelSlit`: retain a closed back-and-forth contour; its signed area is
  zero.

Do not infer hole status from signed area alone. Signed area describes the
current direction, not the filled side.

## Implementation stages

### Stage A: Stabilize overlap classes

1. Introduce an overlap-member relation type.
2. Build relations from `PairEncounter` overlap data.
3. Merge related members into equivalence classes.
4. Replace `overlap_group` on `SpanReplacement`, `BuiltPiece`, and
   `AtomicPiece` with the stable class ID.
5. Retain the existing two-contributor ownership behavior.

Verification:

- existing overlap and reversed-overlap tests;
- overlapping rectangle union;
- adjacent and offset shared-edge slit tests;
- add the three-coincident-contributor regression test and require winding
  depth 3.

### Stage B: Add directed boundary roles

1. Add `BoundaryRole` or its directed precursor to `AtomicPiece`.
2. Assign it in `union_boundaries` and `nonzero_boundaries`.
3. Update threshold emission to copy the role.
4. Update `reverse_atomic_piece` to reverse directed role metadata.
5. Include role in overlap ownership keys.

Verification:

- coincident opposite-orientation operands remain filled under Boolean union;
- internal Nonzero winding-depth tests remain at their expected levels;
- slit tests continue producing exactly two directed pieces per slit.

### Stage C: Trace by contour role

1. Extend candidate compatibility to use the full role.
2. Return a traced contour record containing role and output level.
3. Validate that every piece added to a contour has a compatible role.
4. Keep the current locally outermost turn selection.
5. Keep the current U-turn fallback restriction.

Verification:

- crossing and overlap-plus-crossing robust-union tests;
- four touching squares produce six separate contours;
- no slit piece is absorbed into a fill boundary.

### Stage D: Assemble with role-aware orientation

1. Replace unconditional clockwise normalization.
2. Apply the role-specific orientation rules.
3. Verify the central four-square contour is classified as a hole.
4. Remove any temporary orientation heuristics.

Verification:

- `four_square_union_nonzero_test` passes with area 16;
- all outer-boundary direction-sensitive tests pass;
- forced-hole and internal-depth orientation tests pass;
- sampled Boolean semantics remain correct.

### Stage E: Cleanup

After the behavioral tests pass:

1. Remove unused prototype line-overlap helpers.
2. Remove obsolete comments describing discarded pipeline stages.
3. Update `ROBUST_UNION_HANDOFF.md` or replace it with a completion summary.
4. Run formatting and `git diff --check`.
5. Run the complete test suite.
6. Investigate the arc-intersection timeout separately if it remains.

## New tests to retain or add

The following focused tests already pass and should remain:

- overlapping operands resolve owned overlap occurrences;
- adjacent operands preserve an equal-level shared-edge slit;
- reversed coincident operands preserve Boolean union winding levels.

Add these tests during the corresponding stages:

1. Three identical same-direction contours produce winding depth 3, not 6.
2. Three coincident contributors with one reversed contour produce the correct
   Nonzero level.
3. A merged overlap class spanning three operands has one owner per output
   level.
4. A fill boundary and slit meeting at one junction trace as separate
   contours.
5. A simple frame produces a counterclockwise hole and clockwise outer
   boundary.
6. Internal positive-level contours remain clockwise.
7. Reversing every source contour does not change Boolean union containment.

## Constraints

- Do not restore geometric equality as a consumption mechanism.
- Do not collapse coincident source occurrences before classification.
- Do not concatenate Boolean operands into one fill path.
- Do not post-process offset output with the legacy robust-union prototype.
- Do not infer overlap classes from final segment geometry when encounter
  provenance is available.
- Do not use broad U-turn permissions to compensate for missing role
  continuity.
- Preserve the public `node_segments` API projection to bare segments.

## Progress

### Stage A completed

Pairwise overlap groups are now merged transitively when they share the same
source occurrence and atomic parameter span. Ownership therefore runs once per
arrangement-wide overlap class and output level.

The three-identical-contour regression test now passes with winding depth 3.
The existing two-contributor ownership, reversed-coincident, and shared-edge
slit regression tests also pass.

### Stage B completed

Classified atomic output occurrences now carry one of these roles:

- unclassified noding output;
- fill boundary with the zero side recorded;
- internal positive-level boundary;
- equal-level slit.

Role assignment happens during fill-field classification. Reversing an atomic
piece reverses the directed zero-side flag. Threshold emission, overlap
ownership, occurrence reindexing, and tracing preserve the role. Overlap
ownership keys now include the role.

The four focused overlap and provenance regression tests continue to pass.

### Stage C completed

Tracing now returns internal `OutputContour` records containing the assembled
subpath, output level, and boundary role. The public path result is projected
from those records only after tracing is complete.

Candidate selection now:

- continues only at the same output level;
- orients the candidate before checking its role;
- keeps equal-level slit pieces separate from separating boundaries;
- keeps unclassified pieces separate from classified boundaries;
- allows fill and internal separating roles to meet on one contour;
- preserves directed fill-side metadata on every reversed occurrence.

The directed `zero_on_left` flag is retained for Stage D rather than used as a
strict junction equality test. A strict equality check rejected valid joins
after candidate reversal.

The full suite remains at 413 passing tests and 4 reported failures. The
substantive failure is still `four_square_union_nonzero_test`; the other three
reports are the existing overlap-test timeout cascade.

### Stage D completed

Contour assembly no longer normalizes each traced loop clockwise in isolation.
It first closes all traced contours, then assigns orientation using the
classified contour role:

- fill boundaries are classified by their nesting depth among larger fill
  boundaries;
- outer fill boundaries are clockwise;
- nested fill holes are counterclockwise;
- internal positive-level boundaries remain clockwise;
- equal-level slit contours retain their traced back-and-forth direction.

The nesting check uses a point on the target contour against strictly larger
fill contours. Signed area is used only to compare contour size and apply the
chosen direction; it is not used to decide whether a fill contour is a hole.

This fixes the central contour in `four_square_union_nonzero_test` while
preserving adjacent-slit direction, internal Nonzero winding depth, forced-hole
orientation, and sampled Boolean semantics.

The full suite now reports 414 passing tests and 3 failures. All three reports
come from the existing
`arcs_sharing_two_endpoints_are_two_point_intersections_test` timeout cascade;
there are no remaining robust-union assertion failures.

### Stage E completed

Removed the unused prototype line-overlap implementation and its private
parameter and zero-tolerance helpers. Updated the module documentation to
describe the production arrangement pipeline and replaced the original
handoff with a completion summary.

The separate arc-intersection timeout remains outside the robust-union plan.

## Planar-graph follow-up

Gallery candidate after the graph builder is complete:

- `examples/debug/arrangement_graph_separate_radius_circle_matrix.svg`
- Shows oriented graph edges, vertices, signed left/right winding numbers, and
  directional multiplicities for twelve concentric-circle configurations.
- Before gallery inclusion, regenerate it from actual `ArrangementGraph` values rather
  than retaining the current debug SVG construction.

ArrangementGraph gallery figures:

- `docs/gallery/gallery-arrangement-csg-nonzero.svg`
- `docs/gallery/gallery-arrangement-csg-evenodd.svg`
- These compare the same two multi-rectangle paths, their ArrangementGraph,
  union, intersection, both directional differences, and symmetric difference
  under Nonzero and EvenOdd filling.
- The panels share one coordinate transform and use a common pale, densely
  hatched `(0, 0)` to `(6, 6)` backdrop. The graph cartouches display winding
  levels and directional multiplicities from the shared drawing helper.
- Regenerate their preview sources with `arrangement_csg_figures` before copying
  updated stable outputs into `docs/gallery/`.
