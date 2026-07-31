# Robust Union Completion Summary

## Completed pipeline

`src/svg_path/robust_union.gleam` now implements arrangement-based Nonzero
union for one path and Boolean union for two independently filled operands.

The pipeline:

1. indexes every source segment occurrence with operand and subpath provenance;
2. collects point and overlap encounters through `svg_path/overlaps`;
3. splits occurrences at all encounter parameters;
4. merges overlap relations into arrangement-wide equivalence classes;
5. preserves coincident contributors as separate atomic occurrences;
6. samples Nonzero levels on both sides of each atomic occurrence;
7. emits labelled threshold occurrences with explicit boundary roles;
8. resolves overlap ownership by class, output level, and role;
9. traces contours by occurrence ID with output-level and role continuity;
10. orients fill contours by nesting, internal level contours clockwise, and
    retains equal-level slit contours.

`csg.union` routes through this implementation. Boolean operands remain
separate during fill classification, so opposite-oriented or duplicate
operands do not cancel before union.

## Representation and invariants

Atomic pieces retain:

- emitted occurrence ID and source occurrence ID;
- operand, source subpath, and source segment;
- overlap class;
- segment geometry;
- left and right fill levels;
- output threshold level;
- directed boundary role.

Tracing consumes exact occurrence IDs. It does not use geometric equality to
identify or remove coincident pieces.

## Verification status

The robust-union and CSG behavior tests pass, including:

- crossing and overlap-plus-crossing arrangements;
- partial, reversed, and transitive coincident overlaps;
- three coincident contributors with winding depth 3;
- adjacent and offset shared-edge slit contours;
- internal Nonzero winding levels;
- reversed coincident operands;
- sampled Boolean semantics;
- four touching squares with area 16 and a counterclockwise central hole.

The complete suite reports 414 passing tests and 3 failure reports. All three
reports originate from the separate
`arcs_sharing_two_endpoints_are_two_point_intersections_test` timeout cascade
in curve-intersection processing.

## Remaining separate work

Investigate the arc-intersection timeout independently. It is not a
robust-union behavioral failure.

Do not:

- combine Boolean operands into one fill path;
- collapse coincident source occurrences before classification;
- restore geometric equality as a tracing consumption mechanism;
- post-process offset output with robust union;
- infer overlap classes from final segment geometry when encounter provenance
  is available.
