# SVG Stroke Research Notes

These notes summarize the parts of SVG/CSS stroke behavior that matter for
future dash-array stroking, marker/decorator placement, and related geometry
helpers.

Primary sources:

- SVG 2 Painting: <https://svgwg.org/svg2-draft/painting.html>
- CSS Fill and Stroke Level 3: <https://www.w3.org/TR/fill-stroke-3/>
- SVG Markers draft: <https://www.w3.org/TR/svg-markers/>

## Stroke Shape

SVG defines stroking as if the geometric stroke shape were converted to an
equivalent path and filled. The stroke computation depends on:

- `stroke-width`
- `stroke-linecap`
- `stroke-linejoin`
- `stroke-miterlimit`
- `stroke-dasharray`
- `stroke-dashoffset`
- `vector-effect`
- path length, including `pathLength` scaling when present

The spec explicitly allows user agents some leeway for performance, especially
near tight curves. This matters because our package is trying to expose geometry,
not just mimic one browser rasterization.

## Caps

`stroke-linecap` values:

- `butt`: no extension past open-subpath endpoints. Zero-length subpaths do not
  stroke.
- `round`: endpoints get semicircles with diameter equal to stroke width.
  Zero-length subpaths produce a full circle centered at the subpath point.
- `square`: endpoints get rectangles of stroke-width width and half-stroke-width
  length. Zero-length subpaths produce a square centered at the subpath point,
  oriented by the effective tangent.

For dashed strokes, each dash is treated like an open stroked piece and gets
caps at both ends.

## Joins

`stroke-linejoin` values:

- `miter`: extend outer stroke edges until they meet; if the miter limit is
  exceeded, fall back to bevel.
- `round`: circular sector centered at the join point.
- `bevel`: triangle joining the outer corners of adjacent stroked segments.
- `miter-clip`: SVG 2 value; like miter, but clip instead of bevel on miter-limit
  overflow. Marked at risk / not widely implemented.
- `arcs`: SVG 2 value; uses arcs matching outer-edge curvature. Also at risk /
  not widely implemented.

`stroke-miterlimit` is a multiple of stroke width. SVG 2 defines miter length
from the join angle:

```text
miter length = stroke-width / sin(theta / 2)
```

For `miter`, if `miter length / stroke-width > stroke-miterlimit`, use bevel.

Current package implication: our existing `Miter`, `Round`, and `Bevel` are the
right first supported set. `miter-clip` and `arcs` can be deferred unless users
ask for exact SVG 2 edge behavior.

## Dash Arrays

`stroke-dasharray`:

- `none` means continuous stroke.
- Otherwise it is a list of non-negative lengths/percentages.
- Negative values are invalid.
- If all dash values are zero, the result is treated as `none`.
- The first value is dash length, the second is gap length, alternating.
- If the list length is odd, duplicate the list to make an even-length pattern.
- The pattern repeats.
- The dashing pattern resets at the start of each subpath.
- SVG presentation attributes allow comma and/or whitespace separation.

Implementation-level normalization:

```text
none or all zeros -> one full dash covering the subpath
[a, b, c] -> [a, b, c, a, b, c]
[a, b, c, d] -> unchanged
```

Percentages are relative to SVG viewport sizing in CSS/SVG rendering. For this
geometry package, the first API should probably accept already-resolved user
unit lengths and leave CSS percentage parsing/resolution to a future parser or
caller.

## Dash Offset

`stroke-dashoffset` is the distance into the repeated dash pattern at which
dashing starts. It can be negative.

SVG 2 dash-position algorithm, restated:

1. Let `pathlength` be the subpath length.
2. Normalize `dashes` as above.
3. Let `sum` be the pattern length.
4. If `sum == 0`, return one dash interval `[0, pathlength]`.
5. Let `offset = stroke-dashoffset`.
6. If `offset < 0`, set `offset = sum - abs(offset)`.
7. Set `offset = offset mod sum`.
8. Find the pattern index containing `offset`.
9. Walk the subpath length, emitting intervals only when the current pattern
   index is even.

Important edge behavior:

- Dashes are measured by distance along the subpath, not by segment parameter.
- Dash boundaries can occur inside any segment.
- The dash pattern starts over for every subpath.
- For a closed subpath, dashing still starts at that subpath's start point; the
  seam is meaningful.

Likely package decomposition:

- `dash_intervals(length, pattern, offset) -> List(#(start_length, end_length))`
- `subpath_dashes(subpath, pattern, offset, length_options) -> List(Subpath)`
- `path_dashes(path, pattern, offset, length_options) -> Path`
- `stroke_dashed(...)` can then stroke each dash independently and union the
  resulting stroke shapes if desired.

## PathLength

SVG's `pathLength` attribute scales dash and stroke distance computations by:

```text
authorlength / user_agent_computed_length
```

This package currently works on semantic geometry rather than SVG elements, so
`pathLength` should not be part of the first dash API unless exposed explicitly
as an option. If added, it should be an optional scale layer over measured
subpath length.

## Markers

SVG 2 only includes vertex markers:

- `marker-start`: first vertex of the whole path data.
- `marker-mid`: every vertex other than the first and last vertex of the whole
  path data.
- `marker-end`: last vertex of the whole path data.

For closed path subpaths, the first and last vertex coincide, but `marker-start`
and `marker-end` still refer to the whole path data's first and last vertex, not
to every subpath. `marker-mid` can be drawn at closed-subpath seams in cases
where neither start nor end applies.

Automatic marker orientation:

- At the start or end of an open subpath, use the path direction.
- Otherwise use the direction halfway between the incoming segment end direction
  and outgoing segment start direction.
- `orient="auto-start-reverse"` flips only a start marker by 180 degrees.
- Numeric marker `orient` values are in degrees.

Marker sizing/placement:

- `markerUnits="strokeWidth"` scales marker coordinates by stroke width.
- `markerUnits="userSpaceOnUse"` uses the referencing element's user coordinate
  system.
- `refX`/`refY` identify the marker point placed on the path vertex.
- Marker contents can use `context-stroke` / `context-fill`.

SVG Markers Level 1 discusses extra concepts such as segment markers, repeating
markers, marker patterns, and marker knockout, but SVG 2 says only vertex
markers are included. Those extra marker types should be treated as
future/experimental rather than baseline SVG compatibility.

## Paint Order

Default paint order is:

1. fill
2. stroke
3. markers

`paint-order` can reorder `fill`, `stroke`, and `markers`. This matters for
rendering, but probably not for pure geometry unless we generate combined visual
examples.

## Implementation Guidance For This Package

Recommended first dash feature:

- Accept dash lengths in user units only.
- Reject negative dash lengths.
- Treat all-zero patterns as continuous stroke.
- Duplicate odd-length patterns.
- Reset pattern per subpath.
- Compute dash intervals in true arc length.
- Convert intervals back to existing `SubpathParameter` / `subpath_between`
  machinery.
- Return open dash subpaths.
- Build dashed stroke by stroking each dash with ordinary open-subpath caps.

Deferred:

- CSS parsing of comma/space dash syntax.
- Percentage dash values.
- `pathLength` unless added as an explicit option.
- `miter-clip` and `arcs` joins.
- SVG Markers Level 1 segment/repeating marker extensions.
- Full marker element rendering. A geometry-first helper should probably return
  marker placement records first, not render marker contents.

