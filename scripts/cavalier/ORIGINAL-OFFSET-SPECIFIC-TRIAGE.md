# Original offset-specific families — 2026-10-20

Native `079b2db` (production unchanged from `09d30a1`), JavaScript diagnostics.
Ten originally flagged records from four upstream families were replayed; all
still flag the aggregate property comparison. Both orientations agree on the
large differences. These records are not ten confirmed bugs.

## Source-distance trimming differs

### case11: CC01405, CC01409–CC01411

Native length 2060.7342659972455 versus upstream 2052.5428168464023;
area 141919.56853060416 versus 141959.84850931115. Bounds agree.
Fitting tolerances 0.01, 0.001 and 0.0001 produce identical properties.
The original source includes consecutive semicircles with diameters 25, 15, 25
around x=125..190. Native output follows two radius-21.5 arc pieces through
(157.5,-7.889866919029753). The differing native pieces have lengths
9.438606 each; upstream uses a different connecting arc of length 10.685764.
Sampled source distances on the native pieces reach 1.267616, despite requested
offset magnitude 9. Upstream's differing arc samples remain at distance 9.

### case5: CC01470, CC01474

Native length 962.830952838181 versus upstream 916.7498699472794; bounds agree.
Tightening fitting to 0.0001 does not change the native result. The first source
arc has radius about 13.9754, smaller than the requested inward distance 30.
Native retains its post-collapse normal extrusion and an adjoining round join;
upstream clips these more aggressively. Sampled native-only geometry has source
distance as low as 20.202132. All sampled upstream output points lie on the
native output within the 1e-5 diagnostic threshold.

These are understood **different trimming contracts**, not established native
failures. Upstream `point_valid_for_offset` explicitly rejects slices closer
than `abs(offset)-offset_tol` to any source segment. Our documented operation
uses signed normal extrusion, band winding and forced parity, with no global
minimum-source-distance guarantee. The observations establish this policy
contrast; they do not prove that every output boundary point is correct or that
either definition is preferable. Reconsidering the policy belongs to the deferred
review, not this original-case classification pass.

## Self-intersection families: winding/parity removes extra walks

### self_intersecting_case1: CC01499, CC01503

Native returns the same small component as upstream, length
24.810068463598622 versus 24.810068463598636. Upstream additionally returns a
walk of length 1047.5088824641757. Both exist geometrically in native untrimmed
output: maximum sampled upstream-to-raw distance is 1.28e-13. Tightening fitting
to 0.0001 does not restore the second walk.

Tracing wrappers preserve all values and run only in a copied JS build:
60 arrangement edges -> 29 offset-image edges -> 16 winding-compatible edges
-> 2 after forced parity -> one reconstructed subpath. Thus the discrepancy is
in trimming, not failure to generate the larger offset geometry.

### self_intersecting_case2: CC01504, CC01508

Native retains the closed component (length 1139.2177531250875 versus
1139.2177538521232), but omits the upstream open walk of length
137.47770415252785. Trace: 20 arrangement edges -> 12 offset-image edges ->
10 after winding -> 7 after forced parity -> one subpath. Sampled omitted-walk
points lie on raw output within 9.12e-7. Fitting 0.0001 gives the same result.

There is also a **separate numerical residual** on the retained closed component:
area differs by about 0.0003692, and sampled upstream-to-raw boundary distance
reaches 1.95e-6. This is not called exact equivalence or proven correct. Its
numerical cause has not been isolated in this batch; it remains an explicit
follow-up, separate from the missing-walk policy comparison.

The missing walks are consistent with documented winding/parity trimming, which
can discard open chains. These traces identify the removal stages but do not
independently certify all winding labels. No new native contract violation is
established. Stronger validation of this policy remains eligible for the later
deferred review; do not silently promote these comparisons to exact matches.

## Reproduction and evidence

- `original-offset-specific-cases.json` / `original-offset-specific-results.jsonl`:
  ten original cases and fresh public calls, 30-second worker limit; no timeouts.
- `original-offset-case11-detail.json`, `original-offset-CC*-tight.json`:
  fitting controls and complete native output segments.
- `prepare-original-offset-export.py`: standalone Rust runner, depending on the
  unmodified pinned upstream source. Full output coordinates in
  `original-offset-specific-upstream.jsonl`; original capture only stored properties.
- `probe-original-offset-boundaries.mjs`: five samples per segment, compared to
  the other output and the source through native analytic line/circle distance.
  Results: `original-offset-boundary-samples.jsonl`. These are not an independent
  distance oracle or exhaustive boundary-equivalence proof.
- `prepare-original-offset-trace.py`, `probe-original-offset-trace.mjs`:
  copied-build stage counters, `original-offset-CC01499-stages.json` and
  `original-offset-CC01504-stages.json`.
- `original-offset-CC*-untrimmed.json`, `original-offset-untrimmed-samples.jsonl`:
  explicit NoTrimming controls. Set `AUDIT_UNTRIMMED=1` for boundary sampling.

```sh
CAVALIER_CASES=original-offset-specific-cases.json CAVALIER_RESULTS=NEW_RESULTS.jsonl CAVALIER_WORKERS=1 CAVALIER_TIMEOUT_MS=30000 node scripts/cavalier/compare-captured.mjs
python3 scripts/cavalier/prepare-original-offset-export.py
RUSTUP_HOME=/tmp/cavalier-audit-rustup CARGO_HOME=/tmp/cavalier-audit-cargo CARGO_TARGET_DIR=/tmp/cavalier-audit-target cargo +1.95.0 run --offline --quiet --manifest-path /tmp/cavalier-original-offset-export/Cargo.toml
node scripts/cavalier/probe-original-offset-boundaries.mjs
```

No production changes, full-suite rerun, figure regeneration or F# work.
These findings are uncommitted. Original topology-policy offset families and
Boolean classifications still remain; this is not audit closure.
