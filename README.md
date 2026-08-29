# svg_path

[![Package Version](https://img.shields.io/hexpm/v/svg_path)](https://hex.pm/packages/svg_path)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/svg_path/)

`svg_path` is a geometry library for SVG paths in Gleam. It parses and
serializes SVG `d` and `transform` attributes and works directly with paths,
subpaths, lines, quadratic and cubic Beziers, and elliptical arcs. Operations
preserve the original curve types where possible rather than flattening them
into polygons.

The package also includes:

- construction, editing, evaluation, differentiation, splitting, and
  singularity-safe curve directions;
- isolated intersections, continuous overlaps, combined encounter queries,
  and closest-point pair projections;
- fill-rule-aware union, intersection, difference, and symmetric difference
  under SVG `nonzero` and `evenodd` rules;
- clipping, cutting, one- and two-sided offsets, stroke outlines, dashes, and
  marker layout;
- bounding boxes, convex hulls, containment, area, transforms, curve fitting,
  basic-shape conversion, and path effects;
- decimal-aware relative serialization that compensates for accumulated
  rounding drift.

Topology-sensitive operations use planar arrangements of the original curves.
Segments are progressively split at intersections, endpoint contacts, and
overlap boundaries; coincident portions retain directional multiplicities and
source correspondence. This supports robust reconstruction without replacing
the input geometry with a polygonal approximation.

`svg_path` supports Erlang and JavaScript and has no runtime dependency beyond
the Gleam standard library.

```sh
gleam add svg_path@0
```

```gleam
import svg_path/parse
import svg_path/serialize

pub fn tidy_path_data(input: String) -> String {
  let assert Ok(path) = parse.path(input)
  let options = serialize.decimal_options(2)

  serialize.path_with(path, options:)
}
```

```gleam
import gleam/result
import svg_path
import svg_path/parse
import svg_path/serialize

pub fn prepare_for_arc_averse_consumer(
  input: String,
) -> Result(String, parse.Error) {
  use path <- result.try(parse.path(input))

  path
  |> svg_path.path_arcs_to_cubic_beziers
  |> serialize.path
  |> Ok
}
```

## Module Map

- `svg_path`: core `Path`, `Subpath`, `Segment`, and `Point` types, plus
  construction, editing, geometry, splitting, and distances.
- `svg_path/point`: small helper library for the `svg_path.Point` type.
- `svg_path/parse` and `svg_path/serialize`: SVG path-data parsing and
  serialization.
- `svg_path/affine`: raw six-value affine matrices, composition, and point
  mapping.
- `svg_path/transform`: applying affine transforms to SVG path geometry.
- `svg_path/transform/parse` and `svg_path/transform/serialize`: SVG
  `transform` attribute parsing and serialization.
- `svg_path/trig`: degree-based trigonometry helpers for SVG-facing angles.
- `svg_path/ellipse`: endpoint and center arc data, arc conversion, evaluation,
  splitting, bounding boxes, and cubic approximation.
- `svg_path/congruency`: semantic ordered congruency checks under translation,
  rotation, and uniform scale.
- `svg_path/area`: signed area and SVG fill-rule area for subpaths and paths.
- `svg_path/clip`: curve clipping that keeps original geometry inside a filled
  clipping region without adding closure bridges.
- `svg_path/intersections`: segment, subpath, and path point-intersection
  queries, plus closest-point pair projections.
- `svg_path/overlaps`: continuous coincident intervals between segments,
  subpaths, and paths.
- `svg_path/encounters`: combined continuous-overlap and isolated
  point-intersection queries.
- `svg_path/arrangement`: planar arrangements built by progressively noding
  path segments, including endpoint clusters and coincident-edge multiplicities.
- `svg_path/arrangement/drawing`: drawing primitives for inspecting an
  arrangement graph.
- `svg_path/csg`: Boolean union, intersection, difference, symmetric
  difference, and nested contour reconstruction for filled paths.
- `svg_path/cut`: split subpaths and paths at intersections with cutter
  geometry.
- `svg_path/offset`: one-sided offsets, two-sided bands, and offset-map
  helpers.
- `svg_path/stroke`: SVG-style stroke outlines, caps, joins, dash extraction,
  and dashed stroke geometry.
- `svg_path/marker`: marker pose computation and marker layout transforms.
- `svg_path/effects`: one-off artistic path effects such as corner rounding.
- `svg_path/degeneracy`: normalization of near-degenerate geometry into simpler
  segments.
- `svg_path/curvature`: signed curvature and visual-left-normal radius helpers
  for segments.
- `svg_path/convex_hull`: convex hulls for segments, subpaths, paths, and point
  lists.
- `svg_path/bezier`: Bezier fitting and low-level Bezier geometry helpers.
- `svg_path/basic_shapes`: conversions from SVG basic shapes to paths.
- `svg_path/svg`: small debugging helper for writing complete SVG documents.
- `svg_path/inspect`: stable, non-SVG inspection strings for debugging and
  tests.

## Core Model

The root `svg_path` module represents SVG path data with `Path` and `Subpath`
types, supported by lower-level `Segment` and `Point` primitives.

### Points

A `Point` stores `x` and `y` coordinates:

```gleam
pub type Point =
  Point(x: Float, y: Float)
```

Construct points with the public `Point` constructor:

```gleam
svg_path.Point(10.0, 20.0)
```

Use `svg_path/point` for vector-style helpers such as `point.dot`,
`point.norm`, `point.project`, `point.right`, and `point.direction`.

### Segments

A `Segment` is one SVG path segment, expressed in absolute coordinates, i.e.,
not relative to a previous "current point":

```gleam
pub type Segment {
  Line(start: Point, end: Point)
  QuadraticBezier(start: Point, control: Point, end: Point)
  CubicBezier(start: Point, control1: Point, control2: Point, end: Point)
  Arc(
    start: Point,
    radius: Point,
    x_axis_rotation: Float,
    large_arc: Bool,
    sweep: Bool,
    end: Point,
  )
}
```

For `Arc`, `x_axis_rotation` is in degrees, matching SVG path data.

Segments can be evaluated, differentiated, and split by their local parameter
`t`, where `0.0` is the segment start and `1.0` is the segment end:

```gleam
svg_path.segment_point(segment, at: 0.5)                    // -> Result(Point, svg_path.Error)
svg_path.segment_derivative(segment, at: 0.5)               // -> Result(Point, svg_path.Error)
svg_path.segment_split(segment, at: 0.5)                    // -> Result(#(Segment, Segment), svg_path.Error)
svg_path.segment_between(segment, from: 0.25, to: 0.75)        // -> Result(Segment, svg_path.Error)
svg_path.segment_between_many(segment, between: [0.25, 0.75, 0.5]) // -> Result(List(Segment), svg_path.Error)
```

Values outside `0.0..1.0` lead to silent extrapolation along the same algebraic
parameterization. Use `_inside` variants of the same functions to surface
parameter domain errors instead.

For unit traversal directions that remain meaningful when the ordinary
derivative collapses to zero, use `segment_directions`. It returns incoming
and outgoing directions separately, since a cusp can have two different
one-sided directions. `subpath_directions` and `path_directions` apply the same
operation at their respective parameter types; the `_with` variants accept
`DirectionOptions` for controlling when a derivative candidate is treated as
collapsed.

### Subpaths

A `Subpath` is opaque. It internally consists of a start point, a list of
end-to-end segments, and a flag indicating topological closure:

```gleam
pub opaque type Subpath {
  Subpath(start: Point, segments: List(Segment), closed: Bool)
}
```

The library guarantees that the first segment, when present, starts at `start`,
and that the last segment of a topologically closed subpath, when present,
likewise ends at `start`.

Subpaths with `segments == []` can have any value of `closed`. A `Subpath`'s
serialization ends in `Z`/`z` if and only if `closed == True`.

Subpaths can be split by local segment addresses:

```gleam
pub type SubpathParameter {
  SubpathParameter(segment_index: Int, t: Float)
}

svg_path.subpath_split(subpath, at: svg_path.SubpathParameter(1, 0.5))
svg_path.subpath_between(
  subpath,
  from: svg_path.SubpathParameter(0, 0.5),
  to: svg_path.SubpathParameter(2, 0.25),
)
svg_path.subpath_between_many(subpath, between: [
  svg_path.SubpathParameter(0, 0.5),
  svg_path.SubpathParameter(2, 0.25),
])
svg_path.subpath_point(subpath, at: svg_path.SubpathParameter(1, 0.5))
svg_path.subpath_derivative(subpath, at: svg_path.SubpathParameter(1, 0.5))
```

Subpath parameters are strict: `segment_index` must address a real segment and
`t` must be inside `0.0..1.0`. Unlike segment parameters, subpath parameters do
not extrapolate beyond a segment. The split helpers only return positive-length
pieces: open subpath split lists must be strictly increasing and cannot include
the very start or very end, while closed subpath split lists must be distinct
and cyclically increasing. Use `subpath_parameters_compare` for plain
segment-index-then-`t` ordering.

The subpath interval helpers have deliberately narrow roles:

- `subpath_split` splits one open subpath into two open subpaths.
- `subpath_between` extracts one positive-length interval; closed subpaths may
  wrap.
- `subpath_between_many` extracts every interval between a list of split points.
  For a closed subpath, a single split point returns one open loop, while an
  empty split list returns an empty list.
- `subpath_open_at` is the convenience form for opening one closed subpath at one
  `SubpathParameter`.
- `subpath_point` and `subpath_derivative` evaluate a subpath at one
  `SubpathParameter`.

Use `svg_path.subpath` to construct an open subpath from a nonempty list of
contiguous segments, and `svg_path.subpath_set_closed` to change whether a
subpath is topologically closed. `subpath_set_closed(_, True)` may return an
error, but `subpath_set_closed(_, False)` cannot:

Use `SubpathParameter(index, t)` for normal forward addresses. Use
`subpath_parameter_from_end(subpath, segment_index:, t:)` to address the
subpath as if its segment order were reversed and convert that address back into
the original subpath's coordinates.

```gleam
svg_path.subpath(segments)                  // -> Result(Subpath, svg_path.Error)
svg_path.subpath_set_closed(subpath, closed: Bool)  // -> Result(Subpath, svg_path.Error)
```

Construction succeeds when the required segment endpoints meet. Construct empty
"move-only" subpaths with `subpath_empty(at:)` where `at` gives the start of
the subpath.

In the following example the segments return to their starting point
geometrically, but the subpath only becomes topologically closed after
`subpath_set_closed`:

```gleam
import gleam/io
import gleam/result
import svg_path
import svg_path/serialize

pub fn closed_triangle() -> Result(svg_path.Subpath, svg_path.Error) {
  let a = svg_path.Point(0.0, 0.0)
  let b = svg_path.Point(10.0, 0.0)
  let c = svg_path.Point(5.0, 10.0)

  use subpath <- result.try(svg_path.subpath([
    svg_path.Line(start: a, end: b),
    svg_path.Line(start: b, end: c),
    svg_path.Line(start: c, end: a),
  ]))

  io.println(serialize.subpath(subpath))
  // -> "M 0 0 H 10 L 5 10"

  use subpath <- result.try(svg_path.subpath_set_closed(subpath, closed: True))

  io.println(serialize.subpath(subpath))
  // -> "M 0 0 H 10 L 5 10 Z"

  Ok(subpath)
}
```

Use `svg_path.subpath_normalize_zero_length_lines(subpath)` to remove
zero-length line segments from a `Subpath`. Note that
`subpath_normalize_zero_length_lines` preserves at least one zero-length
segment of a nonempty `Subpath`, though it does not add any new segments if
`subpath_segments(subpath) == []` to start with.

### Paths

A `Path` is a list of `Subpath`.

```gleam
pub type Path {
  Path(subpaths: List(Subpath))
}
```

Construct paths directly via the public variant:

```gleam
svg_path.Path(subpaths: [subpath])
```

The total widening conversions are `segment_as_subpath`, `segment_as_path`,
and `subpath_as_path`. The narrowing `path_as_subpath` succeeds when a path has
at most one nonempty subpath; empty subpaths are ignored unless they are all
the path contains.

Retrieve subpaths with `svg_path.path_subpaths(path)`.

Use `path_map_subpaths` and `path_filter_subpaths` to transform or filter a
path's subpaths.

Use `path_combine` to assemble a single `Path` from a `List(Path)`. The result
of `path_combine(paths)` is equivalent to
`Path(paths |> list.map(svg_path.path_subpaths) |> list.flatten)`.

Use `path_start` and `path_end` to get the endpoints of a full path. Empty
paths return `Error(EmptyPath)`; paths with subpaths use the first subpath's
start and the last subpath's end, including empty subpaths:

```gleam
svg_path.path_start(path)
svg_path.path_end(path)
```

## Subpath-Building

Helper functions in the root module let users employ an `EndpointPolicy` option
to specify different types of reconciliation behavior for adjacent endpoints:

```gleam
pub type EndpointPolicy {
  Strict
  Wiggle
  WiggleWith(Float)
  Bridge
  WiggleThenBridge
  WiggleThenBridgeWith(Float)
  Custom(fn(Segment, Segment, Bool) -> List(Segment))
}
```

`Strict` is the behavior of `subpath`, requiring exact endpoint
equality. `Wiggle` moves nearby endpoints together within the package's default
wiggle tolerance of 1e-9 while respecting the horizontality and verticality
of `Line` segments: horizontal and vertical lines stay horizontal and vertical.
If adjacent horizontal/horizontal or vertical/vertical lines are misaligned, a
bridge is inserted regardless of endpoint distance.
`wiggle_with(tolerance)` provides the same policy with an explicit tolerance.
`Bridge` keeps existing endpoints in place and inserts a straight line segment
when needed. `WiggleThenBridge` applies the same pair-local wiggle behavior
when adjacent endpoints are within tolerance, and otherwise bridges that pair;
`wiggle_then_bridge_with(tolerance)` is its configurable counterpart. `Custom`
gives callers a hook for bespoke endpoint reconciliation. Its third callback
argument is `True` only for the closing join from the last segment back to the
first segment of a closed subpath.

Functions that accept an `EndpointPolicy` end in `_with`. Including:

```gleam
svg_path.subpath_with(segments, policy: svg_path.Wiggle)
svg_path.subpath_append_segment_with(subpath, segment, policy: svg_path.Bridge)
svg_path.subpath_join_with([first_subpath, second_subpath], policy: svg_path.WiggleThenBridge)
svg_path.subpath_splice_with(subpath, start: Int, delete: Int, insert: List(Segment), policy: svg_path.Wiggle)
svg_path.subpath_set_closed_with(subpath, closed, policy: svg_path.Bridge)
```

Subtracting the `_with` suffix yields equivalent functions whose policy is
`EndpointPolicy.Strict`.

Failure to reconcile segment endpoints under a given policy results in a
`Discontinuous` `svg_path.Error` variant:

```gleam
Discontinuous(
  previous_index: Int,
  next_index: Int,
  expected: Point,
  got: Point,
  distance: Float,
)
```

In the above, `expected` is the end of a putative last segment, `got` is the
start of a putative next segment (or first segment of the subpath, for a
closure error), and `distance` is the distance between the two.

Use the `assert_` functions for hand-authored/static geometry where invalid
continuity is a programmer error:

```gleam
svg_path.subpath_assert(segments)
svg_path.subpath_assert_with(segments, policy)
svg_path.subpath_assert_append_segment(subpath, segment)
svg_path.subpath_assert_append_segment_with(subpath, segment, policy)
svg_path.subpath_assert_join([first_subpath, second_subpath])
svg_path.subpath_assert_join_with([first_subpath, second_subpath], policy)
svg_path.subpath_assert_splice(subpath, start, delete, insert)
svg_path.subpath_assert_splice_with(subpath, start, delete, insert, policy)
svg_path.subpath_assert_set_closed(subpath, closed)
svg_path.subpath_assert_set_closed_with(subpath, closed, policy)
```

`Custom` receives adjacent segments as `previous` and `next`. For ordinary
adjacent pairs, its returned list replaces the pair. For the closing join from
the last segment back to the first segment of a closed subpath, the returned
list replaces only the last segment. An empty list deletes the replaced segment
or pair. If the returned list is nonempty, its first segment must start where
`previous` started; the constructor verifies the final subpath afterward. A
custom policy can adjust, delete, replace, or insert bridge-like segments. It
may be called even when the original adjacent endpoints already match, so it
can also perform coalescing or cleanup effects.

Use `subpath_rebuild_with` to re-run an endpoint policy over an existing
subpath's segment list while preserving its open/closed state. Empty subpaths
are preserved unchanged. `path_rebuild_with` applies the same operation to each
subpath independently.

### Joining Subpaths

`subpath_join` combines open subpaths into one open subpath. With the default
`Strict` policy, each subpath's end point must exactly equal the next
subpath's start point. Empty open subpaths can act as identity values when
their start points line up. `subpath_join([])` returns `EmptySubpath`.

```gleam
svg_path.subpath_join([first_subpath, second_subpath, third_subpath])
```

Closed subpaths are rejected rather than implicitly opened. This keeps
closedness as explicit topology: if you want to discard it, use
`subpath_set_closed(subpath, closed: False)` first.

Use `subpath_join_with` when you want another endpoint policy:

```gleam
svg_path.subpath_join_with([first_subpath, second_subpath], policy: svg_path.Wiggle)
svg_path.subpath_join_with([first_subpath, second_subpath], policy: svg_path.Bridge)
```

### Splicing Subpaths

`subpath_splice` replaces a range of segments while preserving the subpath
invariant. `start` is a zero-based segment index, `delete` is the number of
segments to remove, and `insert` is the replacement list.

```gleam
svg_path.subpath_splice(subpath, start: 2, delete: 1, insert: replacement_segments)
```

If `start + delete` extends past the end of the subpath, everything from
`start` onward is deleted. Negative `start`, negative `delete`, and `start`
greater than the subpath length return `InvalidSplice`.

With the default `Strict` policy, the edited subpath must still be continuous,
otherwise `Discontinuous` is returned with segment indices, points, and
distance. Closed subpaths preserve their closed state. If the splice result is
nonempty, the subpath start is updated to the first resulting segment's start
point. If the splice result is empty, the previous start point is preserved.

Use `subpath_splice_with` when the splice should use a different endpoint policy:

```gleam
svg_path.subpath_splice_with(
  subpath,
  start: 2,
  delete: 1,
  insert: replacement_segments,
  policy: svg_path.Wiggle,
)
```

### Opening Closed Subpaths

`subpath_open_at` breaks open a closed subpath at a subpath parameter and
returns a single open subpath. The result traverses the whole loop from that
point back to itself:

```gleam
svg_path.subpath_open_at(closed_subpath, at: svg_path.SubpathParameter(2, 0.5))
```

Use `t: 0.0` to open at a segment boundary. A parameter at the final endpoint of
a closed subpath, such as `SubpathParameter(length - 1, 1.0)`, opens at the
first point of the subpath.

The error behavior is intentionally specific:

- `NotClosed` is returned if the subpath is not closed.
- `InvalidSubpathParameter(segment_index, t, length)` is returned if the
  parameter is outside the segment list or outside `0.0..1.0`.

### Reversing Subpaths

Use `subpath_reverse` to reverse the traversal direction of a subpath while
preserving its closed/open state:

```gleam
svg_path.subpath_reverse(subpath)
```

For lower-level operations, `segment_reverse` reverses a single segment.

## Converting Arcs to Beziers

Some SVG consumers and geometry workflows prefer to avoid elliptical `Arc`
segments. Use the `_arcs_to_cubic_beziers` function family to replace arcs with
cubic Bezier curves while preserving lines, quadratic Beziers, and existing
cubic Beziers:

```gleam
svg_path.segment_arcs_to_cubic_beziers(segment)
svg_path.subpath_arcs_to_cubic_beziers(subpath)
svg_path.path_arcs_to_cubic_beziers(path)
```

Elliptical arcs are approximated with one or more cubic Beziers, split into
chunks of at most a quarter turn. The conversion preserves subpath closed/open
state. If an arc is degenerate, it falls back to the straight-line cubic Bezier
between the arc endpoints.

There is no tolerance option for this conversion. The approximation policy is
deterministic: each arc chunk spans no more than 90 degrees. This is the common
practical SVG arc-to-cubic approximation and is usually more than adequate for
rendering and interchange.

If you want every segment represented as cubic Bezier curves, use the stricter
helpers instead. Lines and quadratic Beziers are converted exactly.

```gleam
svg_path.segment_to_cubic_beziers(segment)
svg_path.subpath_to_cubic_beziers(subpath)
svg_path.path_to_cubic_beziers(path)
```

## Converting Segments to Lines

Use the `_to_lines` function family to approximate every segment with straight
lines:

```gleam
svg_path.segment_to_lines(segment)
svg_path.subpath_to_lines(subpath)
svg_path.path_to_lines(path)
```

The `_with` variants accept `LinearizeOptions(tolerance:, max_depth:)`. The
default tolerance is `0.01` coordinate units and the default recursion limit is
20. Beziers are adaptively subdivided using their control points' distance from
each chord. Arcs use a conservative bound based on their radius and angular
span. Degenerate arcs become lines between their endpoints.

Subpath order, start points, closed/open state, and move-only subpaths are
preserved. Conversion returns an error when the requested tolerance cannot be
reached within `max_depth`.

## Arcs and the `ellipse` Module

`svg_path.Arc` uses SVG's endpoint arc representation: an explicit `start`,
an `end`, two semi-axis radii, an `x_axis_rotation`, and the SVG `large_arc`
and `sweep` flags. This matches the information carried by an SVG `A` path
command, with the current point made explicit as `start`.

Endpoint arcs are compact, but they are awkward for evaluation and splitting.
The lower-level `svg_path/ellipse` module exposes the two arc representations
used by the SVG implementation notes:

```gleam
ellipse.EndpointArcData(
  start:,
  radius:,
  x_axis_rotation:,
  large_arc:,
  sweep:,
  end:,
)

ellipse.CenterArcData(
  center:,
  radius:,
  x_axis_rotation:,
  start_angle:,
  delta_angle:,
)
```

`endpoint_to_center` converts SVG-style endpoint data into center data. During
that conversion, radii follow SVG's forgiving rules: negative radii are made
positive, and radii that are too small to connect the endpoints are scaled up
uniformly. `CenterArcData.radius` is therefore the corrected radius.

Public arc angles are in degrees. `start_angle` and `delta_angle` are measured
in the ellipse's own coordinate system before stretching and rotation; `delta`
is signed, and determines the `sweep` direction.

Use `svg_path.arc_center_data` to convert a root-module `Arc` segment to
`ellipse.CenterArcData`, and `svg_path.arc_from_center_data` to come back to an
`Arc`. For common evaluation tasks, use the root wrappers `svg_path.arc_point`,
`svg_path.arc_derivative`, and `svg_path.arc_point_at_angle`; these keep the
ordinary `svg_path.Point` and `svg_path.Error` types. The `ellipse` module also
exposes lower-level helpers such as `arc_point`, `arc_point_at_angle`,
`split_arc`, `arc_bounding_box`, and `arc_to_cubics`.

## Geometry Helpers

The root module exposes common geometry helpers directly on `Segment`,
`Subpath`, and `Path`. The module docs contain the full option and error
details; this section is a map of the available families.

### Bounding Boxes

Use `segment_bounding_box`, `subpath_bounding_box`, and `path_bounding_box` for
axis-aligned bounds. Line, Bezier, and arc extrema are included. Measure a box
with `bounding_box_width`, `bounding_box_height`, `bounding_box_center`, and
`bounding_box_diameter`; the diameter is width plus height.

### Optimization Over Segments

Use `segment_minimize` to find the segment parameter where a scalar function of
the segment point is minimized:

```gleam
import svg_path

pub fn lowest_point(segment: svg_path.Segment) -> Result(Float, svg_path.Error) {
  svg_path.segment_minimize(segment, measure: fn(point) {
    point.y
  })
}
```

The returned value is a segment parameter in `0.0..1.0`. You can pass it to
`segment_point` or `segment_split`.

Minimization is numerical and does not require a derivative. Use
`segment_minimize_with` when the default sampling and tolerance are not
appropriate.

### Segment and Subpath Lengths

Use `segment_length`, `subpath_length`, or `path_length` to measure geometry.
Lines are exact. Beziers and arcs use adaptive integration. Distances are true
path-coordinate lengths, not normalized fractions.

Length-address helpers convert traveled distances back to ordinary parameters
and evaluated geometry:

```gleam
svg_path.segment_parameter_at_length(segment, distance: 12.0)
svg_path.segment_point_at_length(segment, distance: 12.0)
svg_path.segment_derivative_at_length(segment, distance: 12.0)
svg_path.segment_between_lengths(segment, from: 12.0, to: 30.0)
svg_path.segment_between_lengths_many(segment, between: [12.0, 20.0, 30.0])

svg_path.subpath_parameter_at_length(subpath, distance: 25.0)
svg_path.subpath_point_at_length(subpath, distance: 25.0)
svg_path.subpath_derivative_at_length(subpath, distance: 25.0)
svg_path.subpath_between_lengths(subpath, from: 25.0, to: 60.0)
svg_path.subpath_between_lengths_many(subpath, between: [25.0, 40.0, 60.0])

svg_path.path_parameter_at_length(path, distance: 40.0)
svg_path.path_point_at_length(path, distance: 40.0)
svg_path.path_derivative_at_length(path, distance: 40.0)
```

### Distances and Projections

Use `segment_distance` to measure the shortest distance from a point to a
segment. Use `segment_projection` when you also need the nearest segment
parameter and point:

```gleam
import svg_path

pub fn distance_to_segment(
  point: svg_path.Point,
  segment: svg_path.Segment,
) -> Result(Float, svg_path.Error) {
  svg_path.segment_distance(point, to: segment)
}

pub fn nearest_on_segment(
  point: svg_path.Point,
  segment: svg_path.Segment,
) -> Result(svg_path.SegmentProjection, svg_path.Error) {
  svg_path.segment_projection(point, to: segment)
}

pub fn nearest_on_path(
  point: svg_path.Point,
  path: svg_path.Path,
) -> Result(svg_path.PathProjection, svg_path.Error) {
  svg_path.path_projection(point, to: path)
}
```

`subpath_projection` and `path_projection` lift the same idea to larger
structures and return public parameters. Move-only subpaths are skipped.

### Point Containment

Use the containment helpers to classify a point relative to SVG fill geometry:

```gleam
svg_path.subpath_containment(point, within: subpath, using: svg_path.Nonzero)
svg_path.path_containment(point, within: path, using: svg_path.EvenOdd)

// Both return Result(svg_path.PointContainment, svg_path.Error)
```

The result and fill-rule types are:

```gleam
pub type PointContainment {
  Inside
  Outside
  Boundary
}

pub type FillRule {
  Nonzero
  EvenOdd
}
```

`Boundary` is reported independently of the fill rule. Otherwise, `Nonzero`
or `EvenOdd` determines whether the result is `Inside` or `Outside`.

Fill geometry implicitly closes every nonempty subpath with a straight line
from its end to its start. This happens whether `Subpath.closed` is `True` or
`False`. Consequently, changing only the `closed` field does not change the
result of containment testing. The `closed` field still matters for
serialization and stroke semantics.

A move-only subpath has no segments, fill area, or boundary. It is always
`Outside`, even when the tested point equals its move point. An empty path and
a path containing only move-only subpaths are also `Outside`.

`Nonzero` is SVG's default fill rule. A directed crossing contributes `+1` or
`-1` to the winding number. The point is inside when the total winding number
is not zero. For a `Path`, winding numbers are summed across all subpaths, so
oppositely directed loops can cancel and equally directed loops reinforce one
another.

`EvenOdd` ignores crossing direction. The point is inside when the total number
of crossings across all subpaths is odd. Passing through another enclosed loop
therefore toggles inside/outside regardless of that loop's direction.

For a point inside both an outer loop and a nested inner loop:

| Inner loop direction | `Nonzero` | `EvenOdd` |
| --- | --- | --- |
| Same as outer loop | `Inside` (winding magnitude 2) | `Outside` (two crossings) |
| Opposite to outer loop | `Outside` (windings cancel) | `Outside` (two crossings) |

This aggregation is why `path_containment` cannot be implemented as "inside
any subpath". Self-intersecting subpaths and paths that revisit an area use the
same winding and crossing rules.

Before applying a fill rule, containment checks the original geometry and
implicit closing lines for boundary hits. A boundary match takes precedence over
both fill rules. Use `_with` variants to choose the coordinate-space boundary
tolerance and numerical options.

### Areas

Use `svg_path/area` for signed area, SVG fill-rule area, and absolute winding
area:

```gleam
import svg_path
import svg_path/area

pub fn filled_area(path: svg_path.Path) -> Result(Float, svg_path.Error) {
  area.path(path, using: svg_path.Nonzero)
}
```

There are three area notions here. `area.signed_subpath` and `area.signed_path`
return algebraic area. `area.subpath` and `area.path` return unsigned filled
area under `Nonzero` or `EvenOdd`. `area.absolute_subpath` and
`area.absolute_path` integrate `abs(winding_number)`, so repeated same-direction
loops count with multiplicity. `svg_path/convex_hull` is a separate geometry
operation; a hull area can be larger than the filled area of a concave or
self-intersecting shape.

Signed area is computed from line integrals. Lines, quadratic Beziers, cubic
Beziers, and elliptical arcs are handled directly. The sign depends on drawing
direction: reversing a simple loop reverses the sign. Self-intersections and
oppositely directed loops can cancel, while repeated loops can multiply the
result.

Fill-rule area follows SVG fill semantics. Every nonempty subpath is
implicitly closed with a straight line from its end to its start, regardless of
the `Subpath.closed` field. Move-only subpaths contribute zero area. For a
path, all subpaths are considered together, so overlapping and nested subpaths
are not measured independently and then added.

The difference matters for repeated or nested loops:

| Shape | Signed area | `Nonzero` area | `EvenOdd` area |
| --- | --- | --- | --- |
| One simple loop | `+A` or `-A` | `A` | `A` |
| Same loop twice, same direction | `+2A` or `-2A` | `A` | `0` |
| Same loop twice, opposite directions | `0` | `0` | `0` |

For those three rows, `area.absolute_path` returns `A`, `2A`, and `0`,
respectively.

`area.subpath`, `area.path`, `area.absolute_subpath`, and `area.absolute_path`
first linearize curves and then integrate slabs of the resulting line
arrangement. The `_with` variants accept `LinearizeOptions`;
`options.tolerance` controls curve-to-line approximation in coordinate units,
not a direct bound on final area error. The arrangement step compares every
pair of linearized edges, so these arrangement-based areas are quadratic in the
number of generated line edges.

### Segment Crossings

Use `segment_crossings` to find parameter values where a scalar predicate
changes sign along a segment:

```gleam
import svg_path

pub fn horizontal_crossings(
  segment: svg_path.Segment,
  y: Float,
) -> Result(List(Float), svg_path.Error) {
  svg_path.segment_crossings(segment, where: fn(point) {
    point.y -. y
  })
}
```

The returned values are ordinary segment parameters in `0.0..1.0`. Crossing
detection is numerical and sampling-based; use `segment_crossings_with` to tune
it.

### Segment Intersections

Use `intersections.segment` to find point intersections between two segments:

```gleam
import svg_path
import svg_path/intersections

pub fn crossings(
  left: svg_path.Segment,
  right: svg_path.Segment,
) -> Result(List(svg_path.SegmentIntersection), svg_path.Error) {
  intersections.segment(left, right)
}
```

Each `SegmentIntersection` contains the intersection point plus the local
parameters on both segments:

```gleam
svg_path.SegmentIntersection(left_t:, right_t:, point:)
```

The result represents finite point intersections only; segment overlaps return
`OverlappingSegments`. The same operation is lifted to larger structures:

```gleam
intersections.segment_subpath(segment, subpath)
intersections.subpath(left_subpath, right_subpath)
intersections.path(left_path, right_path)
```

Self-intersections use parallel names:

```gleam
intersections.segment_self(segment)
intersections.subpath_self(subpath)
intersections.path_self(path)
```

Results are ordered by parameter, and boundary aliases are canonicalized. Use
`_with` variants to supply `IntersectionOptions` or `SelfIntersectionOptions`.

Known subpath intersection addresses can be classified afterward with
`classify_subpath_intersection` as crossings, nontransverse contacts, endpoint
contacts, or indeterminate cases. Contact order uses outward-pointing rays
sampled at equal arc lengths; the accompanying aperture angles instead use the
incoming and outgoing traversal directions directly.

### Segment and Subpath Overlaps

Point-intersection queries deliberately cannot represent a continuous shared
interval. Use `svg_path/overlaps` when coincident geometry is the expected
result:

```gleam
import svg_path/overlaps

overlaps.segment(left_segment, right_segment)
// -> Result(List(overlaps.SegmentOverlap), svg_path.Error)

overlaps.subpath(left_subpath, right_subpath)
// -> Result(List(overlaps.SubpathOverlap), svg_path.Error)
```

A `SegmentOverlap` gives the interval parameters and geometric endpoints on
both segments. Its left parameters are canonicalized into increasing order;
the right parameters may decrease when the two segments traverse the overlap
in opposite directions. The endpoint parameters define an affine, monotone
correspondence throughout the overlap. Coincident geometry that cannot satisfy
that contract returns `NonAffineOverlapCorrespondence`; normalize or linearize
such segments before overlap detection. At a matching tolerance,
`intersections.segment` returns `OverlappingSegments` exactly when
`overlaps.segment` reports an overlap.

The overlap detector is intended for non-degenerate segments whose overlap
boundaries occur at an endpoint of at least one input segment. Arrangement
construction establishes that working model through progressive endpoint,
intersection, and overlap-boundary splitting. Subpath and path overlap values
retain their constituent piecewise-affine segment correspondences, and the
module provides helpers for mapping exact parameters from either traversal to
the other.

Use `svg_path/encounters` when both continuous overlaps and isolated point
intersections are required from one query. Its segment, segment-subpath,
subpath, and path functions return both lists without changing the underlying
payload types. Subpath encounters retain overlap-boundary intersections by
default; the explicitly named
`filter_fully_overlap_explained_subpath_intersection_parameters` helper derives
a view with parameters fully explained by overlaps removed.

### Convex Hulls

The `svg_path/convex_hull` module computes closed convex hull subpaths for
segments, subpaths, paths, and point lists.

```gleam
import svg_path
import svg_path/convex_hull

pub fn hull(
  segment: svg_path.Segment,
) -> Result(svg_path.Subpath, convex_hull.Error) {
  convex_hull.segment_hull(segment)
}
```

Lines, quadratic Beziers, and ordinary arcs are handled semantically. Lines
produce a two-line closed hull, while quadratic Beziers and arcs produce the
original primitive plus the chord joining its endpoints. Cubic Beziers use a
cubic-specific numerical solver.

Use `subpath_hull`, `path_hull`, and `points_hull` for larger inputs. Move-only
subpaths contribute their start points.

### Congruency

The `svg_path/congruency` module finds a translation, rotation, and uniform
scale mapping one ordered piece of geometry to another:

```gleam
import svg_path
import svg_path/congruency
import svg_path/transform

pub fn mapped(
  source: svg_path.Path,
  target: svg_path.Path,
) -> Result(svg_path.Path, transform.Error) {
  let assert Ok(matrix) =
    congruency.path(source: source, target: target, tolerance: 0.000001)

  transform.path(source, by: matrix)
}
```

This is semantic congruency, not rendered-shape equivalence. Segment
constructors must match, so a line and a visually identical degenerate curve do
not match. Arc field details are checked after the point cloud transform is
found.

`congruency.subpath` and `congruency.path` compare ordered structure only. They
ignore the subpath `closed` field, but they do not rotate or cycle closed
subpaths, choose alternate starting segments, or reorder subpaths. If two
closed loops start at different places, open or rebuild them with matching
segment order before calling congruency.

The same module also exposes `fit_points`, `fit_segment`, `fit_subpath`, and
`fit_path` for best-fit matching. Pass `Similar` for translation, rotation, and
uniform scale, or `Affine` for a general affine matrix. These helpers return a
`Fit(transform:, error:)`, where `error` is RMS point distance.

## Parsing

`svg_path/parse` accepts normal SVG path data syntax, including:

- comma separators
- SVG whitespace separators, including form feed
- compact signed numbers such as `M0-1`
- compact arc flags such as `A10 10 0 0110 20`
- implicit line commands after `M`
- repeated command argument groups
- relative and absolute commands
- closepath commands `Z` and `z`

```gleam
import gleam/result
import svg_path/parse
import svg_path/serialize

pub fn canonicalize() -> Result(String, parse.Error) {
  use path <- result.try(parse.path("M0,0 10,10z"))

  Ok(serialize.path(path))
}
```

The parsed object is not just a token stream. It is normalized into this
package's path model. For example, an implicit line after `M` becomes a
`Line` segment internally.

The parser follows the SVG path-data grammar for number consumption,
comma/whitespace placement, command repetition, and arc flags. Its conformance
suite includes cases adapted from Web Platform Tests and the W3C SVG 1.1
Second Edition test suite. Unlike a browser renderer, `parse.path` is strict:
invalid trailing data returns `Error` for the whole input instead of returning
or rendering the valid prefix.

Parser errors have the form `ParseError(reason:, remaining:)`. `remaining` is
the exact suffix of the original input beginning at the failure location and
is empty for a failure at end of input.

Closepath is also represented semantically. If parsing `Z` needs a straight
line back to the subpath start, the parser inserts that line and marks the
subpath closed. If the subpath is already back at its start, no extra line is
inserted; the subpath is just marked closed.

## Serialization

`svg_path/serialize` emits SVG path data from `Path`, `Subpath`, and
`Segment` values.

By default it uses:

- absolute commands
- up to 5 decimal places
- stripped trailing decimal zeroes
- readable whitespace
- repeated command letters
- one-line path data
- `H` and `V` for horizontal and vertical lines when possible
- `S` and `T` for smooth curves when possible
- `Z` for closed subpaths

Serialization options can use relative commands, commas inside coordinate
pairs, smaller whitespace, rounded numbers, fixed decimal places, omitted
repeated command letters, line breaks, left-padded numbers for visual
alignment, explicit line commands instead of `H`/`V`, and explicit curve
commands instead of `S`/`T`.

When `options.relative == True`, the serializer compensates for accumulated
drift caused by decimal rounding.

```gleam
import svg_path/parse
import svg_path/serialize

pub fn compact_path_data(input: String) -> String {
  let assert Ok(path) = parse.path(input)

  serialize.path_with(path, options: serialize.minifying_options(2))
}
```

`minifying_options` is a deterministic small-output preset. It uses the
serializer's normal `H`/`V` and `S`/`T` discovery, but it does not try every SVG
spelling and prove that the result is globally shortest.

If you want a complete SVG document for debugging or examples, use
`svg_path/svg` with a view box, per-path style strings, and optional text
labels. It is a small drawing helper, not a rendering framework.

### Move-Only Subpaths, Zero-Length Segments, and Closure

SVG distinguishes move-only subpaths from zero-length drawing subpaths. The
subpath consisting only of the command `M 50,0` has a current point but no
drawing segment, whereas `M 50,0 L 50,0` has a zero-length line segment. User
agents can render these differently: with `stroke-linecap:round` or
`stroke-linecap:square`, for example, the zero-length line can produce a
visible mark while the move-only subpath remains invisible. SVG 2 describes this
in its notes on
[zero-length path segments](https://www.w3.org/TR/SVG2/paths.html#PathElementImplementationNotes)
and
[stroke line caps](https://www.w3.org/TR/SVG2/painting.html#LineCaps).
There is a similar difference between `M 0,0` and `M 0,0 Z`, with the `Z`
command "supplying" a zero-length line segment to the subpath:

<center>
  <img src="https://raw.githubusercontent.com/vistuleB/svg_path/assets-v0.40.0/figures/zero_length_closepath_probe.svg" alt="Zero-length closepath probe">
</center>

```xml
<path d="M 90,50" style="fill:none;stroke:blue;stroke-width:24;stroke-linecap:round;" />
<path d="M 260,50 L 260,50" style="fill:none; stroke:blue; stroke-width:24;stroke-linecap:round;" />

<path d="M 90,120" style="fill:none;stroke:blue;stroke-width:24;stroke-linecap:square;" />
<path d="M 260,120 L 260,120" style="fill:none;stroke:blue;stroke-width:24;stroke-linecap:square;" />

<path d="M 90,230" style="fill:none;stroke:black;stroke-width:24;stroke-linecap:round;" />
<path d="M 260,230 Z" style="fill:none;stroke:black;stroke-width:24;stroke-linecap:round;" />

<path d="M 90,300" style="fill:none; stroke:black; stroke-width:24; stroke-linecap:square;" />
<path d="M 260,300 Z" style="fill:none; stroke:black; stroke-width:24; stroke-linecap:square;" />
```

For that reason, `svg_path.subpath_normalize_zero_length_lines` keeps one
zero-length line if a
subpath consists only of zero-length lines, preserving the difference between a
zero-length subpath and a move-only subpath. It does this even for closed
subpaths, where the choice is mainly about preserving internal representation
consistency.

Concerning the detailed mechanics of subpath closure, a literal read of the
[SVG 2 specification](https://www.w3.org/TR/SVG2/paths.html#PathDataClosePathCommand)
plausibly suggests that `Z` means "draw a final line from the current point to
the starting point, even if this final line has length 0, and then mark
topological closure". The observable behavior of user agents, however, suggests
that `Z` is commonly interpreted as meaning "draw a final line to the starting
point only if necessary to bridge a gap or when no segments have been added to
the subpath yet, and then mark topological closure".
This library follows the latter interpretation.

Under this interpretation, a final nonzero-jump line that geometrically
closes a topologically closed subpath can be elided in the representation of
the subpath, shortening `M0,0 L10,10 0,0 Z` to `M0,0 L10,10 Z`. A final
zero-length jump followed by `Z` cannot be dropped without losing information,
so the serializer never drops zero-length lines, including immediately prior to
`Z`.

## Transforming Paths

`svg_path/transform` applies SVG-style affine transforms to segments, subpaths,
and paths.

```gleam
import svg_path/parse
import svg_path/serialize
import svg_path/transform

pub fn move_path_data(input: String) -> String {
  let assert Ok(path) = parse.path(input)
  let matrix = transform.translate(x: 10.0, y: 20.0)
  let assert Ok(path) = transform.path(path, by: matrix)

  serialize.path(path)
}
```

Transforms use the SVG six-value affine matrix:

```text
matrix(a b c d e f)
```

which corresponds to:

```text
x' = a*x + c*y + e
y' = b*x + d*y + f
```

The ordinary `segment`, `subpath`, and `path` transform functions preserve
segment types and return `DegenerateArcTransform` when an affine transform
collapses an arc into line geometry. Use `segment_gracefully`,
`segment_to_subpath_gracefully`, `subpath_gracefully`, or `path_gracefully`
when collapsed arcs should instead become one or more line segments.

Matrix values can be constructed and inspected as tuples:

```gleam
import svg_path/transform

pub fn inspect_transform() -> #(Float, Float, Float, Float, Float, Float) {
  transform.rotate(degrees: 30.0)
  |> transform.to_tuple
}
```

Use `chain(first:, then:)` when thinking in application order. Use
`multiply(left:, right:)` when thinking in matrix multiplication order.

```gleam
import svg_path/transform

pub fn scale_then_move() -> transform.Matrix {
  let scale = transform.scale(factor: 2.0)
  let move = transform.translate(x: 10.0, y: 20.0)

  // Applying scale, then move, is move * scale.
  transform.chain(first: scale, then: move)
  // transform.multiply(left: move, right: scale)
}
```

Transforms can also be applied about a point, or about one of the nine anchor
points on a segment, subpath, or path bounding box:

```text
TopLeft      TopCenter      TopRight
CenterLeft   Center         CenterRight
BottomLeft   BottomCenter   BottomRight
```

```gleam
import svg_path
import svg_path/transform

pub fn flip_path_horizontally(
  path: svg_path.Path,
) -> Result(svg_path.Path, transform.Error) {
  path
  |> transform.path_about_anchor(
    by: transform.scale_xy(x: -1.0, y: 1.0),
    anchor: transform.Center,
  )
}
```

## Transform Attributes

SVG transform attributes can be parsed and serialized separately from paths.

```gleam
import svg_path/transform/parse
import svg_path/transform/serialize

pub fn tidy_transform_attribute(input: String) -> String {
  let assert Ok(matrix) = parse.attribute(input)

  serialize.to_string(matrix)
}
```

The transform parser accepts normal SVG transform syntax, including compound
attributes such as:

```text
translate(10) scale(2) skewX(3)
```

Its errors use the same `ParseError(reason:, remaining:)` convention as the
path-data parser.

Transform serialization prefers readable SVG forms when the matrix can be
recognized clearly:

```text
translate(10 20)
translate(10 20) scale(2)
rotate(30)
translate(10 20) rotate(30) scale(2 3)
```

If no clearer representation is available, it falls back to:

```text
matrix(a b c d e f)
```

Use `force_matrix` when you want the raw matrix form even if a shorter
transform expression could be detected.

```gleam
import svg_path/transform
import svg_path/transform/serialize

pub fn raw_transform_attribute() -> String {
  transform.translate(x: 10.0, y: 20.0)
  |> serialize.to_string_with(
    options: serialize.default_options() |> serialize.force_matrix,
  )
}
```

## Inspecting Paths

`svg_path/inspect` prints path data structures for debugging and tests. It is
not the SVG `d` serializer. Use `inspect.segment`, `inspect.subpath`, and
`inspect.path` for readable structural output:

```gleam
import svg_path
import svg_path/inspect

pub fn inspect_line() -> String {
  svg_path.Line(
    start: svg_path.Point(0.0, 0.0),
    end: svg_path.Point(12.0, 10.0),
  )
  |> inspect.segment
}
```

Example output:

```text
Line(start=0,0 end=12,10)
```

Use the `_code` functions when you want copy-pasteable Gleam:

```gleam
import svg_path
import svg_path/inspect

pub fn inspect_code(path: svg_path.Path) -> String {
  inspect.path_code(path)
}
```

Example output:

```text
svg_path.Path([
  svg_path.subpath_assert([
    svg_path.Line(start: svg_path.Point(0.0, 0.0), end: svg_path.Point(12.0, 10.0))
  ])
])
```

Inspection options mirror the serializer's decimal controls: rounding, fixed
decimal places, and left padding are available through the `_with` functions.

Further documentation can be found at <https://hexdocs.pm/svg_path>.

## Curve Clipping

`svg_path/clip` clips drawn geometry to a filled clipping region. This is not a
filled Boolean operation: the input path is treated as curves, and the clipping
path is treated as a filled region.

```gleam
clip.subpath(input, to: clip_region, using: svg_path.Nonzero)
clip.path(input, to: clip_region, using: svg_path.Nonzero)

// Each returns Result(..., svg_path.Error)
```

The returned subpaths contain only pieces of the original input geometry.
Boundary pieces from the clipping region are not inserted. If an open subpath
enters, exits, and re-enters the clipping region, the result contains multiple
open subpaths. If a closed circle is clipped by a rectangle, the result is the
visible arc fragments as open subpaths, not a closed rectangle-and-arc outline.

Closed inputs stay closed only when the whole subpath survives without being
cut by the clipping boundary. Pieces whose sample point is inside or on the
boundary of the clipping region are retained. Segment types are preserved where
possible: lines remain lines, Beziers remain Beziers, and arcs remain arcs
after splitting.

## Arrangement Graphs

`svg_path/arrangement` constructs a planar arrangement from one or more
source paths. Construction preserves the caller's segment geometry while
progressively splitting segments at intersections, endpoint contacts, and
overlap boundaries. The resulting atomic edges do not intersect except at
endpoint clusters. Coincident edges are stored once with forward and reverse
multiplicities.

For two overlapping squares, the input boundaries cross at two points. Those
crossings become vertices, and the four original sides that pass through them
are split into atomic edges. The left panel uses one color per source subpath;
the right panel shows the resulting vertices, directed edges, winding levels,
and directional multiplicities.

<center>
  <img src="https://raw.githubusercontent.com/vistuleB/svg_path/assets-v0.40.0/figures/arrangement_graph_overlapping_squares.svg" alt="Two overlapping square subpaths and their arrangement graph">
</center>

```gleam
import svg_path/arrangement

arrangement.build(
  [left, right],
  tolerance: 0.000001,
  minimum_chord: 0.00001,
)
// -> Result(arrangement.ArrangementGraphBuild, arrangement.Error)
```

`ArrangementGraphBuild` contains the graph and `segment_images`. Each segment
image records, in original path, subpath, and segment order, the graph-edge
identifiers produced from one source segment and whether each traversal
reverses the stored edge direction. An image can be empty when all pieces of an
input segment are shorter than `minimum_chord`.

The graph, vertex, and edge representations are transparent for inspection.
Vertices retain their clustered source endpoints and use the center of the
smallest circle enclosing those endpoints as their representative point. Edges
retain their segment geometry, endpoint vertex identifiers, and directional
multiplicities. Cyclic edge order around a vertex is derived from geometry; it
is not stored in the graph.

Arrangement construction compares segment geometry rather than requiring
structurally equal segment values. In the following case, two equal circles run
in opposite directions. Each consists of two 180-degree arcs, but the second
circle's subdivision is shifted by 45 degrees. The graph splits the common
circle at all four source endpoints and represents each geometric edge once,
with one occurrence in each direction.

<center>
  <img src="https://raw.githubusercontent.com/vistuleB/svg_path/assets-v0.40.0/figures/arrangement_graph_semantic_circle_overlap.svg" alt="Oppositely directed equal circles with phase-shifted arc subdivisions and their arrangement graph">
</center>

`build` is the supported constructor. Direct construction remains possible for
inspection, serialization, and tests, but callers then assume responsibility
for the documented graph invariants. `arrangement.validate` checks local
representation and closed-boundary invariants that do not require pairwise
intersection tests.

`svg_path/arrangement/drawing` provides reusable drawing primitives for
the transparent graph representation. `drawing` shows vertices, edges, and
directional multiplicities. `annotated_drawing` additionally shows winding
levels on both sides of every edge relative to a compatible source path; it
trusts that the supplied source corresponds to the graph.

## Path CSG

`svg_path/csg` performs operations on the filled point-sets represented by SVG
paths. It builds an arrangement graph, measures the winding field on either
side of its edges, applies the requested fill rule, and reconstructs the
necessary boundary cycles.

```gleam
import svg_path
import svg_path/csg

csg.union(left, right, using: svg_path.Nonzero)
csg.intersection(left, right, using: svg_path.Nonzero)
csg.difference(left, minus: right, using: svg_path.Nonzero)
csg.symmetric_difference(left, right, using: svg_path.Nonzero)

// Each returns Result(csg.CsgResult, csg.Error)
```

For example, both products of a union remain available without rebuilding the
arrangement:

```gleam
let assert Ok(output) =
  csg.union(left, right, using: svg_path.Nonzero)

let result_path = output.path
let arrangement_build = output.build
```

`CsgResult.path` is the reconstructed output path. `CsgResult.build` is the
exact `ArrangementGraphBuild` used to compute it, exposing the arrangement
graph and source-segment images for inspection or drawing. This matters because
endpoint clustering and segment refinement make the arrangement's geometry the
source of truth for the returned path.

Boolean operations can produce no components, one component, multiple
components, holes, or islands inside holes. Multiple subpaths in each operand
are evaluated globally. Open subpaths follow SVG fill semantics and are
implicitly closed for filling. The `using` fill rule is part of the operation:
repeated loops, self-intersections, and nested subpaths can produce different
results under `Nonzero` and `EvenOdd`.

The following worked example uses two paths containing two rectangles each.
Every panel retains the same coordinate system: the first row shows the source
paths, their arrangement graph, union, and intersection; the second shows both
orders of difference, symmetric difference, and rounded nested contours.
The arrangement is constructed once from geometry, while each binary result
classifies its edge sectors under the selected fill rule.

Under `Nonzero`, any nonzero winding level is filled. The arrangement panel's
black numbers are the winding levels immediately to the left and right of each
directed edge; its red numbers are forward and reverse source multiplicities.

<center>
  <img src="https://raw.githubusercontent.com/vistuleB/svg_path/assets-v0.40.0/figures/arrangement_csg_nonzero.svg" alt="Eight-panel ArrangementGraph CSG example using the Nonzero fill rule">
</center>

The same inputs and arrangement produce different Boolean boundaries under
`EvenOdd`, where winding parity determines whether a sector is filled. The
final `nested_contours` panel is unchanged because that unary operation
preserves the complete signed winding field and does not take a fill rule.

<center>
  <img src="https://raw.githubusercontent.com/vistuleB/svg_path/assets-v0.40.0/figures/arrangement_csg_evenodd.svg" alt="Eight-panel ArrangementGraph CSG example using the EvenOdd fill rule">
</center>

For points away from a boundary:

| Operation | The point is inside the result when |
| --- | --- |
| `union(left, right)` | it is inside `left` or `right` |
| `intersection(left, right)` | it is inside both operands |
| `difference(left, minus: right)` | it is inside `left` but not `right` |
| `symmetric_difference(left, right)` | it is inside exactly one operand |

Use the `_with` variants with `csg.Options` to choose the endpoint tolerance
and minimum atomic-edge chord. Returned segments retain their source type where
possible: lines remain lines, Beziers remain Beziers, and arcs remain arcs
after splitting.

The unary `csg.nested_contours` operation takes no fill rule. It reconstructs
nested or disjoint unit-level contours that preserve a path's complete signed
integer winding field, rather than reducing that field to filled/unfilled
values.

## Development

```sh
scripts/test-fast
scripts/test-slow
gleam docs build
```
