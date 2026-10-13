# Binary CSG face-winding classification

Binary CSG now derives the arrangement dual and propagates signed winding
changes independently for each operand. Source occurrence indices include
implicit closing segments. Forward and reversed occurrences contribute +1 and
-1; repeated sources count even when they do not own an edge. The Boolean
operation combines face fill states, then uses the existing sector pairing and
vertex-based output construction. Stored arrangement edges are unchanged.

This replaces displaced containment sampling and fixes fixtures 79 and 113,
including the reduced silent empty-union failure documented in
[the investigation](BOUNDARY_CLASSIFICATION_INVESTIGATION.md). Unary
`nested_contours` is unchanged. No public symbols or options were added.

Two compatibility details emerged from the existing clustered-endpoint test:

- In a connected graph, each boundary walk already identifies one face. The
  dual still certifies the exterior with independent accepted sweeps, but no
  longer requires a sweep through every bounded face. Disconnected components
  retain their placement certification. This avoids rejecting narrow faces
  solely because no accepted line passes through them.
- Output endpoint reconstruction can collapse a gap into an exact retraced
  closed loop. A loop whose segments cancel in exact opposite pairs is omitted.
  Signed area is not used to discard loops. Nonempty loops keep all their
  original segments, and stored arrangement edges remain unchanged.

Dual certification and contradictory source windings remain explicit errors;
there is no fallback to point sampling.

## Validation

- `scripts/test-release`: 1,924 fast, 26 slow, 666 portable Erlang and 666
  portable JavaScript tests pass.
- `test/svg_path_csg_face_winding_test.gleam` adds three portable tests covering
  both reduced shapes, all four operations, both fill rules, opposite traversal,
  repeated/cancelled sources, implicit closure, exact output joins and empty
  operands. Existing tests cover holes, disconnected shapes and self crossings.
- The historical standalone reduction executable also succeeds on both targets.

- `scripts/generate-published-figures`: all 13 README and 33 Gallery figures
  regenerated successfully. SHA-256 comparison against the pre-change files
  shows all 46 SVGs are byte-for-byte identical.

- `PAPER_AUDIT_TIMEOUT_MS=30000 PAPER_AUDIT_REPORT=./boolean-screening-after-face-winding.json node scripts/paperjs/probe-booleans.mjs /tmp/svg-path-paper-audit/node_modules/paper`:
  all 178 fixtures screened on the final JavaScript build. 109 sampled matches,
  61 library errors, seven adapter cases and one timeout (107). All 107 previous
  sampled matches remain matches. The only status changes are 79 and 113 from
  library errors to sampled matches. The remaining two default filtering
  failures (122/123) and four newly exposed overlap rejections still need work.

The saved JavaScript screen is sampled evidence, not a proof of Paper.js parity.
