# Deferred cleanup

Requested to retain for later, 2026-10-13. These are cleanup candidates, not
part of the current 128–131 overlap investigation.

- Remove CSG `BoundaryEdge.layer`: always zero, making its comparison redundant.
- Remove test-only `root.is_crossing_root`; assert classifications directly.
- Review test-only `root.cubic`, `cubic_with` and root-bound helper. Preserve the
  unit and Paper.js numerical checks, possibly moving convenience code to test support.
- Mark older private-API diagnostic scripts with their required historical revision.

Keep the winding sampler: unary nested contours and arrangement drawing use it.
Keep the original polynomial solver: Bernstein recovery is a fallback.
