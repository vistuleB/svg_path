# Residual-window experiment checkpoint

`ix2-residual-experiment.patch` preserves the combined experiment against
commit `af898f9`. It includes residual-window retention, partial-result fallback
merging, enclosing polygons, subdivision safeguards, and bracket validation.
The unprincipled `1e-15` polishing threshold has been removed in this snapshot.

This is a historical diagnostic snapshot, **not a patch to apply to current
main**. Some independently verified changes have since been committed. To
reproduce the snapshot, use a separate checkout of `af898f9` and apply the patch
there. Do not overwrite subsequent work with it.

At this checkpoint `gleam test` reported 1,539 passing tests and nine failures.
Remaining problems included multiple approximations of flat/tangent roots and
search exhaustion around accepted roots. The proposed fixed parameter exclusion
box is not yet an adequate root-identity/uncertainty contract.

The main implementation retains the original window-resolution policy while
the independently tested bracket and enclosure changes are separated out.
Restoring that policy does **not** fix IX2's missed nearby roots; it restores the
pre-experiment behavior pending a better solution.

`intersection_enclosures.mjs` tests the current private enclosing-point helpers
and compares the two bounds modes without modifying generated modules on disk.
Build and run with:

```shell
cd examples/public_api_smoke
gleam build --target javascript
cd ../..
node examples/debug/intersection_enclosures.mjs
```
