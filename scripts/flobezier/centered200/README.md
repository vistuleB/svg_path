# Centered normalization to [-100,100] per axis

2026-10-15, based on `b4b492a`. Double the normalization multiplier from 100 to
200, retaining the same control-point bounds, center calculation, endpoint
matching, internal tolerance, certification and test expectations. Coordinates
now map approximately to [-100,100] rather than [-50,50].

All four release profiles completed independently:

| Command | Passed (zero failures) | Wall seconds |
| --- | ---: | ---: |
| `scripts/test-fast` | 2012 | 39.79 |
| `scripts/test-slow` | 31 | 56.61 |
| `scripts/test-portable erlang all` | 758 | 45.43 |
| `scripts/test-portable javascript all` | 758 | 65.72 |

No candidate-count snapshots or other test expectations changed. Logs and the exact source patch for the validated change are saved here. The captured FloBezier comparison corpus was not rerun for this follow-up;
those comparison results cover the [-50,50] implementation. Timings are observations, not controlled benchmarks.

## Published figures

`scripts/generate-published-figures` completed successfully on 2026-10-15,
including its 2,012-test fast-suite gate. All 13 README and 33 Gallery figures
were regenerated and verified; Gallery files were promoted by the canonical
script. **All 46 SVGs are byte-for-byte identical** to their saved pre-run
[-50,50] baselines. `figures.json` contains the before/after SHA-256 hashes;
`figures.log` records the generation.
