# Review of convertPathData.06–40

Reference: SVGO 4.1.0, revision `5765cbe4e0a930dca648c6b81d335b1522cd7375`, retrieved 2026-10-14. Each case is identified by fixture number and one-based path ordinal; no source line numbers are used. Exact inputs, outputs, attributes, byte counts and classifications are in `all-fixtures.json`.

All 35 remaining fixtures reproduce their complete expected SVG on both upstream passes. Their 129 input paths parse successfully in our library. Together with fixtures 01–05, there are 180 valid paths and one intentionally malformed input. No difference remains unclassified. This is an audit of these fixtures, not a proof of general equivalence or an audit of every SVGO plugin.

## Fixture-by-fixture findings

| Fixture | Cases | Contract and disposition |
| --- | ---: | --- |
| 06 | 13 | Zero-length line removal, initial H/V choice, absolute H/V selection, and merging consecutive collinear lines. We preserve segments; our preset can waste two bytes on the first axis-aligned line. Command selection is a serializer opportunity; merging/removal needs a simplification policy. |
| 07 | 7 | Move-only input agrees apart from letter case. Zero-length L/H/V/C/S/Q/T commands remain in our representation. The coincident-endpoint arc is preserved by parse/serialize, but our existing explicit `path_normalize_svg_arcs` omits it as SVG requires. No parser failure. |
| 08 | 13 | Straight cubic/quadratic reduction, merging and smooth-control bookkeeping after reduction. Large same-parameter differences in cases 3, 4, 7, 10 and 13 reflect changed parameterization of straight segments, not a different traced line. Both zero-radius arcs (11–12) become lines through our existing explicit normalization. Case 8 already agrees except initial M/m. |
| 09 | 5 | Cubic and quadratic reflected-control shorthand detection agrees in every case apart from initial M/m. |
| 10 | 1 | Relative moveto after closepath is correct. The only difference is initial H/V selection in the second subpath. |
| 11 | 26 | Transform flattening, inherited strokes, identifiers, paint references, clipping, affine arcs and straight cubic reduction. We apply the public transform API where SVGO removes a transform and retain local coordinates where SVGO retains it. Geometry checks succeed within the recorded numerical differences. Cases 3 and 6–10 show different rounding and S/T selection; 18–24 expose equivalent arc representations and sensitivity to decimal rounding. Detailed investigation below. Stroke-width rewriting and deciding whether to flatten SVG attributes are document-level policies, not implemented by this adapter. |
| 12 | 14 | SVGO merges same-direction axis-aligned lines but preserves reversals; case 11's diagonal run is not merged by either output. Return-to-start lines become Z in 1, 2, 5, 6. Case 14 loses an empty subpath. We preserve open/closed state and segment/subpath structure. Other differences are initial H/V and absolute/relative choices. |
| 13 | 1 | Commands after Z, a zero-length T, and empty closed subpaths. Our parser starts a new subpath after closepath, as documented, and serialization preserves it. SVGO removes redundant drawing/closing commands under the fixture's un-stroked context. No incorrect parser-state carryover. |
| 14 | 9 | Approximate cubic-to-circular-arc fitting, including combining several cubics and removing near-retracing detail in case 7. We retain the source cubics. These are deliberate approximation opportunities, not missing serializer shorthands or proof of an exact equivalent arc. |
| 15 | 2 | Precision 2: case 1 performs approximate cubic-to-arc fitting. Case 2 keeps its cubics; its two-byte difference is mixed absolute/relative S selection. |
| 16 | 2 | Precision 0: substantial rounding is requested. SVGO additionally reduces curves to lines/arcs or quadratics. Our largest sampled displacement is about 0.584 coordinate units. No geometric-error bound follows from a decimal-place setting. |
| 17 | 1 | Precision 8: SVGO reduces a nearly straight cubic, uses exponents for short numbers, and selects mixed coordinates. We retain the cubic and use fixed decimal spelling here. Same-parameter displacement from SVGO's straightening is not a geometric-distance measurement. Our sampled round-trip displacement is about 2.4e-9. |
| 18 | 1 | Reflection flips arc sweep correctly in our transform output. Packed flags and absolute/relative H/V account for string differences. Both serializers use Z for the final return. |
| 19 | 1 | Uniform scaling with `vector-effect="non-scaling-stroke"`. Adapted transformed geometry agrees. SVGO also preserves the stroke width, an SVG-attribute policy. Remaining path-data gap is initial H/V choice. |
| 20 | 1 | Compact arc flags parse correctly. Both outputs omit an explicit final return line in favor of Z. Our flags are more compact, while SVGO sometimes selects shorter absolute H/V. |
| 21 | 1 | Large arc and stroked closure are preserved. Differences are first-line command selection, absolute/relative coordinates and flag separators. |
| 22 | 6 | Uniform scaling with stroke width, dasharray and dashoffset adjustment. Our transformed geometry agrees; the harness does not implement attribute rewriting. The remaining path-data gap is initial H/V selection. |
| 23 | 2 | SVGO retains the transform on the inline-style case but flattens the presentation-attribute case and adjusts stroke width. The adapter follows those decisions, testing our geometry in the corresponding coordinate frame. Both have the initial H/V gap. |
| 24 | 2 | Composition of translation and scaling, with relative and absolute large-arc input. Our transformed geometry agrees. Different command choices balance out to equal byte counts. |
| 25 | 1 | Translation across closed subpaths and a following relative moveto is correct. Mixed H/V coordinates and initial-line selection explain the size gap. |
| 26 | 1 | Zero-radius arc under identity transform. Applying our existing SVG arc normalization before transforming produces the expected line. Remaining gap is command selection; no new normalization API is needed. |
| 27 | 3 | SVGO drops Z for an un-stroked path and for matching round caps/joins, but retains it with the default stroked join. We preserve semantic closure in all three. This cannot be copied as a context-free serializer rule. |
| 28 | 1 | Open out-and-back line becomes a closed subpath under SVGO's un-stroked context. We preserve open state. Other differences are command spelling. |
| 29 | 2 | SVGO removes empty leading subpaths, including an empty closed subpath. We preserve them and correctly resolve the subsequent relative moveto. |
| 30 | 1 | SVGO merges `.1` and `.2` horizontal movements into `.3`. Our two segments remain distinct, with the correct total displacement. |
| 31 | 1 | The `.0005` line is dropped by SVGO's aggressive rounding/removal policy; ours becomes `.001` at precision 3. Both differ from the original endpoint by approximately `.0005`. This is a rounding-policy and structure-preservation difference, not failed accumulation. |
| 32 | 1 | A radius-10000 arc spanning eight units is approximated by one line in SVGO. Sagitta is about `.0008`; our arc is retained exactly at these input decimals. An optional error-budgeted simplifier could do this. |
| 33 | 1 | SVGO rounds radius `10.567` to `11` because the short arc changes little. Ours retains `10.567`. Sampled displacement between those arcs is about `.0004664`. Geometry-aware rounding is an optional optimizer feature. |
| 34 | 2 | Quadratic smooth-control tracking agrees, including retaining Q when T would imply the wrong control. Differences are initial M/m only. |
| 35 | 1 | Exact cubic-to-quadratic degree reduction. For P0=(0,12), P1=(4,4), P2=(8,4), P3=(12,12), both degree-reduction formulas yield Q=(6,0); this preserves the polynomial at every parameter. We retain C. A useful exact reduction opportunity. |
| 36 | 1 | SVGO removes an intervening zero-length line and packs a decimal separator more tightly. We retain the line and correctly restart the following Q control state. |
| 37 | 2 | With `marker-start`, SVGO substitutes Z for a zero-length line, rather than removing all drawable commands. Our zero-length line remains; both preserve the separate move-only case. Marker-aware substitution requires document context. |
| 38 | 1 | Empty closed path with round stroke caps/joins is preserved by both. Initial M/m only. |
| 39 | 1 | SVGO removes a trailing zero-length segment with round cap/join styling. We retain it. The context-free serializer must not infer styling. |
| 40 | 1 | Initial T uses the current point as its control, tracing a straight line nonuniformly. SVGO replaces it with H and expands the next T to Q to preserve its original reflected control. Our T/T sequence is already correct and three bytes shorter here. |

## Numerical investigation

### Transforms and shorthand selection

All 29 cases whose transforms SVGO flattens were adapted with `transform.parse.attribute` and `transform.path`. Degenerate SVG arcs were explicitly normalized before transformation. As an independent consistency check, the transformed segment was sampled against `transform.point` applied to samples from the original segment. The largest sampled discrepancy was about `3.052e-6` (11:21); most were zero or floating-point noise. These checks exercise affine composition and transformed arcs but are not a formal accuracy bound.

The adapter follows the expected fixture's flatten/retain decision. It does **not** establish that our package implements SVG CSS inheritance, paint-server adjustment, stroke-width scaling, or document-level transform-flattening policy.

In 11:3 and 11:6–10, our serializer adjusts curve controls to rounded endpoint chords and checks reflected controls against the state of its emitted commands. SVGO follows a different rounding/optimization sequence and retains more S/T commands. Our sampled displacement is smaller in these particular cases, at the cost of longer output. A permissive shorthand optimizer would need an explicit error budget; relaxing equality indiscriminately is not a correctness fix.

### Arc representation and rounding

The apparently different radii in 11:21–22 are legitimate SVG representations. Our `.8 2.4` radii are expanded by SVG's radius-correction rule to span the endpoint chord. SVGO emits approximately `80 240`. Swapping ellipse radii and rotating the axes by 90 degrees, or adding 180 degrees to an ellipse angle (11:25), also preserves the ellipse.

The largest observed *serialization* displacement is not a large transform error. At precision 3, case 11:19 produces approximately `.04380` sampled displacement in both outputs. Case 11:24 produces approximately `.28672` in ours and `.27142` in SVGO's original 17-point diagnostic. These are arcs near the semicircle/radius-correction threshold: rounding radii, rotation and endpoints changes the center calculation sensitively. The setting specifies decimal places, not a geometric tolerance.

`numerical-probes.mjs` repeats five arc cases with 513 samples per segment and precision 3, 5, 8 and 12. In 11:24, our measured displacement falls from `.28672` to `.02394`, then about `1.28e-6`, then about `1.02e-5`. In 11:19, precision 5 happens to be closer than precision 8. More decimal places do not guarantee monotonically smaller measured geometric error near the threshold. This deserves documentation and potentially a separate geometry-bounded serialization mode. It does not establish a violation of the present decimal-formatting contract. No production change was made.

Point sampling is diagnostic only. In particular, it must not be interpreted as a Hausdorff bound, a proof that SVGO's approximate fittings are safe, or a comparison of equal parameterizations after curve reduction. Finite-precision arc evaluation itself contributes to the observed residuals.

## Proposed follow-ups, not implemented

1. Choose initial H/V versus implicit L by serialized length; then consider mixed absolute/relative command selection. These need no geometry changes.
2. Consider shorter legal numeric spellings and separators. Fixture 17 exposes useful scientific notation; fixture 36 exposes another removable separator.
3. Offer exact polynomial degree reduction separately from approximate simplification. Fixture 35 supplies a clear regression case with identical parameterization.
4. Document that decimal precision is not a geometric error bound, especially for arcs. Consider an explicit geometry-error budget only as a separate design task.
5. Keep collinear merging, straight-curve reduction, empty-segment removal, closepath substitution, arc fitting, and smart radius rounding under explicit simplification policies. Marker, stroke, closure, and parameterization needs differ.

Existing explicit SVG arc normalization already handles the zero-radius and coincident-endpoint cases. No new API is required for those.

No confirmed bug under our current API contract was found in these 35 fixtures. None of the API suggestions above has been implemented.
