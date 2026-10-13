# Classification of Boolean fixtures 128–131

Investigated 2026-10-13 after `d2f949a`. All four newly exposed rejections are
**understood overlap-contract limitations, not confirmed library bugs**.
No production code was changed and no geometry was linearized.

## Evidence

The Bernstein repair cleared the earlier root-isolation failures, allowing
construction to reach these overlap checks. Instrumentation in a temporary
compiled JavaScript copy records the exact rejected segment pair and all
candidate parameter intervals. Each fixture has four duplicate rejected
candidates, no accepted affine candidate, and the same full-span correspondence:
left `[0,1]`, right `[1,0]`.

There are two distinct witnesses: 128/129 share one pair; 130/131 share another.
Each pair consists of oppositely traversed, almost straight cubics. They trace
the same geometry within tolerance but traverse it at different speeds.

Independent 80-digit Decimal calculations start from the actual binary64
controls. Monotone projections of both control polygons onto the common chord,
transverse control bounds, and endpoint projection gaps bound the distance
between the entire geometric images. De Casteljau evaluation at paired
quarter/mid/three-quarter parameters supplies a lower bound on the maximum
disagreement under the required affine parameter map.

| Fixtures | Whole-image distance upper bound | Sampled affine-parameter mismatch | Detector tolerance |
| --- | ---: | ---: | ---: |
| 128, 129 | 5.4402e-11 | 4.2261 | 5e-7 |
| 130, 131 | 4.2251e-11 | 5.4750 | 5e-7 |

Thus the geometry-distance bound is over 9,000 times smaller than tolerance,
while the affine mismatch is over eight million times larger. These are
high-precision numerical bounds, not a formal interval-arithmetic proof.

For intuition, normalize the common chord to `[0,1]` and reverse the second
curve. The first cubic has scalar controls `[0,0,1,1]`; the other has roughly
`[0,0.3099151,0.7804619,1]` or `[0,0.5286990,1,1]`. Their geometric interval is
the same, but their parameter-to-position polynomials differ. Monotone
traversal fixes the endpoint correspondence, so a different endpoint pairing
cannot explain away the observed mismatch.

`overlaps` explicitly requires an affine, monotone parameter correspondence
within each returned piece. Rejecting these pairs follows that contract. This
classifies the reported blocker only; it does not claim that every subsequent
CSG stage would succeed if inputs were replaced by lines.

## Runtime checks and saved artifacts

- Four full CSG calls reproduce `NonAffineOverlapCorrespondence` on Erlang.
- The same four calls reproduce it on JavaScript.
- `new-overlap-findings.json`: exact witnesses, candidates and production source hashes.
- `new-overlap-witnesses.json`: independent geometric bounds and parameter mismatches.
- `new-overlap-native-results.json`: both runtime logs and checked outcomes.
- `test_paperjs/src/paper_new_overlap_probe.gleam`: the four native diagnostic inputs.

The native executable prints observations; it does not assert that these
failures should persist forever or count them as passing Boolean regressions.
No full-suite or figure rerun was needed for this investigation-only change.

## Reproduction

```sh
(cd test_paperjs && gleam build --target javascript)
node scripts/paperjs/investigate-new-overlaps.mjs
# Use the REPORT path printed by that command:
python3 scripts/paperjs/check-overlap-witnesses.py REPORT /tmp/new-overlap-witnesses.json
(cd test_paperjs && gleam run --target erlang -m paper_new_overlap_probe)
(cd test_paperjs && gleam run --target javascript -m paper_new_overlap_probe)
```

## Remaining work at this investigation checkpoint

See [the subsequent overlap repair](FULL_OVERLAP_FIX.md) for updated results.
The then-current Boolean inventory is 109 sampled matches, 59 understood overlap
limitations, two default minimum-size/construction failures (122/123), one
unresolved downstream timeout (107), and seven adapter cases. No newly exposed
overlap rejection remains unclassified. Broader unadapted assertions and
coverage gaps are unchanged.

[Deferred cleanup](DEFERRED_CLEANUP.md) remains queued separately.
