# CC01504 / CC01508: closed-component numerical residual

Investigated 2026-10-20 against the unchanged production code at `cebcaee`.
This closes the deferred numerical investigation, not the separate omitted-open-
component trimming-policy comparison.

## Finding

The upstream input encodes two exact semicircles with bulge = 1 (or -1 on
reversal). The audit adapter converts each into one SVG endpoint arc, computing
its radius with `Math.hypot(dx, dy) / 2`. That conversion cannot in general retain
exact semicircle geometry in floating point.

For the second arc, the rounded radius is slightly larger than the exact
half-chord of the represented endpoints. An independent 80-digit calculation,
using the exact binary float values, gives:

- `radius² - half_chord² = 3.168825136654831…e-12`
- implied center distance from chord midpoint: `1.7801194164029646e-6`
- native center distance: `1.7801194146970846e-6`

Thus the library's center calculation agrees with the geometry actually supplied.
The first arc instead has a slightly undersized radius; SVG radius correction
produces a semicircle. Reversing the input chooses the other side for the second
arc's displaced center, also explaining the orientation-dependent residual.

## Control experiment

Only in the diagnostic adapter, encode each upstream semicircle as two quarter
arcs. Compute the intermediate vertex directly from the upstream midpoint plus
the signed perpendicular half-chord. Do not obtain it by evaluating the already
rounded SVG semicircle. Keep the same radii, offset options and trimming.

| Input representation | CC01504 signed area | CC01508 signed area | Closed length |
| --- | ---: | ---: | ---: |
| Existing single SVG arcs | 72784.07516302385 | -72784.07517218402 | 1139.2177531250875 / 1139.2177531431262 |
| Quarter-arc control | 72784.07553221736 | -72784.07553221736 | 1139.2177538521232 |
| Cavalier | 72784.07553221736 | -72784.07553221736 | 1139.2177538521232 |

Both controls reproduce Cavalier's reported area and length exactly at printed
float precision. This is not a claim of exact equality of all output coordinates.
Both still return only the closed component: the separate open-component policy
question is unaffected.

## Disposition and recommendation

No offsetter or area-measurement bug established. The residual is explained by
loss of upstream semicircle intent in the audit adapter. Do not silently snap
near-semicircle SVG inputs in production; those encode distinct geometries.
For future bulge-to-SVG comparisons, split exact upstream semicircles into quarter
arcs as a documented adapter choice. Preserve existing baseline captures.

Reproduction (existing portable JavaScript build):

```sh
node scripts/cavalier/probe-offset-semicircle-residual.mjs > scripts/cavalier/offset-semicircle-residual.jsonl
python3 scripts/cavalier/check-offset-semicircle-exact-floats.py > scripts/cavalier/offset-semicircle-residual-exact-floats.json
```

Four offset calls completed successfully: two original representations and two
quarter-arc controls. No production changes, full-suite run, figures, or F# work.
