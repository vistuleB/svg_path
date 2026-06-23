# svg_path

[![Package Version](https://img.shields.io/hexpm/v/svg_path)](https://hex.pm/packages/svg_path)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/svg_path/)

`svg_path` is a set of utilities for working with SVG paths and transforms.
This README is a tour of the main workflows; the complete API reference lives
on HexDocs.

```sh
gleam add svg_path@0
```

```gleam
import svg_path/parse
import svg_path/serialize

pub fn tidy_path_data(input: String) -> String {
  let assert Ok(path) = parse.path(input)

  serialize.path(path)
}
```

Typical workflows compose parsing, path editing, transforms, conversion, and
serialization:

```gleam
import gleam/result
import svg_path
import svg_path/parse
import svg_path/serialize
import svg_path/transform

pub fn prepare_for_arc_averse_consumer(
  input: String,
) -> Result(String, parse.Error) {
  use path <- result.try(parse.path(input))

  let assert Ok(path) =
    path
    |> transform.scale_path(factor: 2.0)

  path
  |> svg_path.path_arcs_to_cubic_beziers
  |> serialize.path
  |> Ok
}
```

## Core Model

The root `svg_path` module models SVG path data with four main types: `Point`,
`Segment`, `Subpath`, and `Path`.

### Points

A `Point` is borrowed from the [`vec`](https://hex.pm/packages/vec) package:

```gleam
pub type Point =
  Vec2(Float)
```

Use `svg_path.point` to create points without importing `vec` directly:

```gleam
svg_path.point(10.0, 20.0)
```

### Segments

A `Segment` is one drawing instruction with explicit start and end points.
These are the public segment variants:

```gleam
svg_path.Line(start:, end:)
svg_path.QuadraticBezier(start:, control:, end:)
svg_path.CubicBezier(start:, control1:, control2:, end:)
svg_path.Arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:)
```

The lower-case helper functions construct the same values with ordinary
function-call syntax:

```gleam
svg_path.line(start:, end:)
svg_path.quadratic_bezier(start:, control:, end:)
svg_path.cubic_bezier(start:, control1:, control2:, end:)
svg_path.arc(start:, radius:, x_axis_rotation:, large_arc:, sweep:, end:)
```

Segments can be evaluated and split by their local parameter `t`, where `0.0`
is the segment start and `1.0` is the segment end:

```gleam
svg_path.segment_point(segment, at: 0.5)
svg_path.segment_derivative(segment, at: 0.5)
svg_path.split_segment(segment, at: 0.5)
svg_path.sub_segment(segment, from: 0.25, to: 0.75)
svg_path.sub_segments(segment, between: [0.25, 0.75, 0.5])
```

These helpers work for lines, quadratic Beziers, cubic Beziers, and arcs.
Values outside `0.0..1.0` extrapolate along the same segment. Use
`split_segment_inside`, `sub_segment_inside`, or `sub_segments_inside` when
outside values should return an error instead.

### Subpaths

A `Subpath` is a continuous list of segments plus a closed/open flag. Its
constructor is opaque; internally, the type is shaped like this:

```gleam
pub opaque type Subpath {
  Subpath(segments: List(Segment), closed: Bool)
}
```

The `segments` list must be continuous: every segment after the first must
start at the previous segment's end point. The `closed` field records whether
the subpath is topologically closed. A closed subpath must end where it starts,
which is an invariant that the library maintains by keeping the type opaque,
but a geometrically closed path need not be `closed`. The serialization of a
`Subpath` ends in `Z` (or `z` if relative motions are used) if and only if
`closed` is `True`.

Use `svg_path.subpath` to construct an open subpath from a list of already
continuous segments, and `svg_path.set_closed` to change whether a subpath is
topologically closed:

```gleam
svg_path.subpath(segments)
svg_path.set_closed(subpath, closed: Bool)
```

Construction succeeds when the segment endpoints meet. In this example, the
segments return to their starting point geometrically, but the subpath becomes
topologically closed only after `set_closed`:

```gleam
import gleam/result
import svg_path

pub fn closed_triangle() -> Result(svg_path.Subpath, svg_path.Error) {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(5.0, 10.0)

  use subpath <- result.try(svg_path.subpath([
    svg_path.line(start: a, end: b),
    svg_path.line(start: b, end: c),
    svg_path.line(start: c, end: a),
  ]))

  svg_path.set_closed(subpath, closed: True)
  // Ok(subpath)
}
```

Construction returns an error when the segment endpoints do not meet. Closing a
subpath with `set_closed(subpath, closed: True)` can fail for the same reason if
the final segment endpoint does not meet the first segment start point:

```gleam
import svg_path

pub fn discontinuous_corner() -> Result(svg_path.Subpath, svg_path.Error) {
  let a = svg_path.point(0.0, 0.0)
  let b = svg_path.point(10.0, 0.0)
  let c = svg_path.point(10.0, 10.0)
  let d = svg_path.point(20.0, 10.0)

  svg_path.subpath([
    svg_path.line(start: a, end: b),
    svg_path.line(start: c, end: d),
  ])
  // Error(...)
}
```

### Paths

A `Path` is a list of `Subpath` values:

```gleam
pub type Path {
  Path(subpaths: List(Subpath))
}
```

You can use the public constructor directly, or the helper function with the
same shape:

```gleam
svg_path.Path(subpaths: [subpath])
svg_path.path([subpath])
```

Use `combine_paths` to concatenate the subpaths from several paths, preserving
empty subpaths. Use `clean_combine_paths` when you want the combined result to
also drop empty subpaths and clean zero-length lines:

```gleam
svg_path.combine_paths([first, second])
svg_path.clean_combine_paths([first, second])
```

A `Path` may consist of an empty list of subpaths, and an open `Subpath` may
consist of an empty list of segments, which is intentional. Empty paths and
empty open subpaths serialize to the empty string. A closed `Subpath` with no
segments is impossible to construct.

Use `path_start` and `path_end` to get the endpoints of a full path. Empty
subpaths are ignored; `EmptyPath` is returned for `Path([])`, and
`EmptySubpaths` is returned when a path has subpaths but none contain segments:

```gleam
svg_path.path_start(path)
svg_path.path_end(path)
```

## Matching Endpoints

Helper functions in the root module let users employ an `EndpointPolicy` option
to specify different types of error-recovery behavior for non-matching
endpoints:

```gleam
svg_path.Strict
svg_path.Wiggle
svg_path.Bridge
svg_path.WiggleThenBridge
svg_path.Custom(fn(previous, next) { #(previous, next) })
```

`Strict` requires exact endpoint equality. `Wiggle` moves nearby endpoints
together within the package's default wiggle tolerance of `0.000000001`, while
preserving horizontal and vertical straight-line segments. `Bridge` keeps
existing endpoints in place and inserts a straight line segment when needed.
`WiggleThenBridge`, as the name implies, first tries `Wiggle` before falling
back on `Bridge`. `Custom` gives callers a hook for bespoke endpoint
reconciliation.

The behavior of option-free functions and constructors is
`EndpointPolicy.Strict`. These include:

```gleam
svg_path.subpath(segments)
svg_path.append_segment(subpath, segment)
svg_path.join([first_subpath, second_subpath])
svg_path.splice(subpath, start:, delete:, insert:)
svg_path.set_closed(subpath, closed: Bool)
```

These functions preserve `Segment` lists exactly while returning a
`Discontinuous` error payload when segment endpoints fail to match up by exact
floating point equality. The `Discontinuous` error payload names the index at
which discontinuity occurs as well as the position and distance between the
endpoints involved:

```gleam
Discontinuous(
  previous_index: Int,
  next_index: Int,
  expected: Point,
  got: Point,
  distance: Float,
)
```

This is often enough to tell whether upstream geometry missed by floating-point
noise or by a real modeling mistake.

The `_with` variants of constructor and subpath-modifying functions enable the
specification of a non-`Strict` endpoint policy:

```gleam
svg_path.subpath_with(segments, policy: svg_path.Wiggle)
svg_path.append_segment_with(subpath, segment, policy: svg_path.Bridge)
svg_path.join_with([first_subpath, second_subpath], policy: svg_path.WiggleThenBridge)
svg_path.splice_with(subpath, start:, delete:, insert:, policy: svg_path.Wiggle)
svg_path.set_closed_with(subpath, closed: Bool, policy: svg_path.Bridge)
```

### Custom Endpoint Policies

`Custom` receives each non-matching adjacent pair as `previous` and `next`, and
returns replacement segments for that pair. It is called only when the two
endpoints do not already match. After all custom reconciliation has run, the
result is validated normally, so custom policies still return the usual
construction errors if they leave the subpath discontinuous.

For example, a custom policy can move the start of each incoming line to the
previous segment's end point:

```gleam
let policy =
  svg_path.Custom(fn(previous, next) {
    case next {
      svg_path.Line(end:, ..) -> {
        #(previous, svg_path.line(start: svg_path.segment_end(previous), end:))
      }
      _ -> #(previous, next)
    }
  })
```

When closing a subpath with `set_closed_with`, the adjacent pair is the last
segment followed by the first segment. The returned pair is used to close that
wraparound boundary, and the final subpath must still validate as both
continuous and closed.

Use the `assert_` functions for hand-authored/static geometry where invalid
continuity is a programmer error:

```gleam
svg_path.assert_subpath(segments)
svg_path.assert_append_segment(subpath, segment)
svg_path.assert_join([first_subpath, second_subpath])
svg_path.assert_join_with([first_subpath, second_subpath], policy: svg_path.WiggleThenBridge)
svg_path.assert_splice(subpath, start:, delete:, insert:)
svg_path.assert_set_closed(subpath, closed: Bool)
```

### Joining Subpaths

`join` combines open subpaths into one open subpath. With the default
`Strict` policy, each subpath's end point must exactly equal the next
subpath's start point. Empty open subpaths act as identity values, and
`join([])` returns an empty open subpath.

```gleam
svg_path.join([first_subpath, second_subpath, third_subpath])
```

Closed subpaths are rejected rather than implicitly opened. This keeps
closedness as explicit topology: if you want to discard it, use
`set_closed(subpath, closed: False)` first.

Use `join_with` when you want another endpoint policy:

```gleam
svg_path.join_with([first_subpath, second_subpath], policy: svg_path.Wiggle)
svg_path.join_with([first_subpath, second_subpath], policy: svg_path.Bridge)
```

### Splicing Subpaths

`splice` replaces a range of segments while preserving the subpath invariant.
`start` is a zero-based segment index, `delete` is the number of segments to
remove, and `insert` is the replacement list.

```gleam
svg_path.splice(subpath, start: 2, delete: 1, insert: replacement_segments)
```

If `start + delete` extends past the end of the subpath, everything from
`start` onward is deleted. Negative `start`, negative `delete`, and `start`
greater than the subpath length return `InvalidSplice`.

With the default `Strict` policy, the edited subpath must still be continuous,
otherwise `Discontinuous` is returned with segment indices, points, and
distance. Closed subpaths preserve their closed state; a splice that would turn
a closed subpath into an empty subpath returns `ClosedEmptySubpath`.

Use `splice_with` when the splice should use a different endpoint policy:

```gleam
svg_path.splice_with(
  subpath,
  start: 2,
  delete: 1,
  insert: replacement_segments,
  policy: svg_path.Wiggle,
)
```

### Opening Closed Subpaths

`open_at` breaks open a closed subpath at a segment index and returns a single
open subpath. The indexed segment becomes the first segment of the result:

```gleam
svg_path.open_at(closed_subpath, index: 2)
```

Negative indices count from the end. The accepted index range is inclusive:
`-length <= index <= length`, where `length` is the number of segments in the
closed subpath. After this range check, the index is taken modulo `length`, so
`-length`, `0`, and `length` all open at the first segment.

The error behavior is intentionally specific:

- `NotClosed` is returned if the subpath is not closed.
- `InvalidOpenIndex(index, length)` is returned if the index is outside the
  accepted inclusive range.

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

## Geometry Helpers

The root module provides a few geometry helpers that work directly with the
`Segment`, `Subpath`, and `Path` model.

### Bounding Boxes

Use `segment_bounding_box`, `subpath_bounding_box`, and `path_bounding_box` to
compute exact axis-aligned bounding boxes:

```gleam
import svg_path

pub fn box_path(path: svg_path.Path) -> Result(svg_path.BoundingBox, svg_path.Error) {
  svg_path.path_bounding_box(path)
}
```

Use `bounding_box_width`, `bounding_box_height`, `bounding_box_center`, and
`bounding_box_diameter` to measure a `BoundingBox`. The diameter is the taxicab
diameter: width plus height.

Line, quadratic Bezier, cubic Bezier, and arc extrema are included. Empty
subpaths return `EmptySubpath`; empty paths return `EmptyPath`; paths whose
subpaths are all empty return `EmptySubpaths`.

For callers working at the lower-level curve modules, `svg_path/bezier` exposes
`bezier_bounding_box`, and `svg_path/ellipse` exposes `arc_bounding_box`.

### Segment Minimization

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
`segment_point` or `split_segment`.

Minimization is numerical and sampling-based. Each sampled window is refined
with golden-section search, so it does not require a derivative of the measured
function. Use `segment_minimize_with` and `MinimizeOptions` to tune `samples`,
`tolerance`, and `max_iterations`.

### Segment Distances

Use `segment_distance` to measure the shortest distance from a point to a
segment:

```gleam
import svg_path

pub fn distance_to_segment(
  point: svg_path.Point,
  segment: svg_path.Segment,
) -> Result(Float, svg_path.Error) {
  svg_path.segment_distance(point, to: segment)
}
```

Lines are measured exactly. Quadratic Beziers, cubic Beziers, and arcs are
measured by finding stationary points of squared distance over the segment
parameter range `0.0..1.0`. Use `segment_distance_with` and `DistanceOptions`
to tune `samples`, `tolerance`, and `max_iterations`.

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

The returned values are segment parameters in `0.0..1.0`. You can pass them to
`segment_point` or `split_segment`.

Crossing detection is numerical and sampling-based. It finds sign-change
crossings visible at the configured sampling resolution, plus endpoint/sample
values that are already close to zero. It does not promise tangent roots or
multiple crossings hidden inside one sample window. Use `segment_crossings_with`
and `CrossingOptions` to tune `samples`, `tolerance`, and `max_iterations`.

The scalar solver behind this lives in `svg_path/root.gleam` as a small
self-contained bisection helper for bracketed `Float -> Float` functions.

### Segment Intersections

Use `segment_intersections` to find point intersections between two segments:

```gleam
import svg_path

pub fn crossings(
  left: svg_path.Segment,
  right: svg_path.Segment,
) -> Result(List(svg_path.SegmentIntersection), svg_path.Error) {
  svg_path.segment_intersections(left, right)
}
```

Each `SegmentIntersection` contains the intersection point plus the local
parameters on both segments:

```gleam
svg_path.SegmentIntersection(left_t:, right_t:, point:)
```

The result represents finite point intersections only. Segments that overlap
in more than one point, such as partially overlapping collinear lines, return
`OverlappingSegments`. Use `segment_intersections_with` and
`IntersectionOptions` to tune `tolerance` and `max_depth` for curved segment
intersection detection.

### Convex Hulls

The `svg_path/convex_hull` module computes a closed hull for a single segment.
The hull reuses curve portions from the original segment where possible, joined
by straight lines:

```gleam
import svg_path
import svg_path/convex_hull

pub fn hull(
  segment: svg_path.Segment,
) -> Result(
  #(svg_path.Subpath, List(convex_hull.HullPiece)),
  convex_hull.HullError,
) {
  convex_hull.segment_hull(segment)
}
```

`HullPiece` records how the hull was assembled:

```gleam
convex_hull.HullCurve(from, to)
convex_hull.HullLine(from, to)
```

The `Float` values are the original segment parameters. A curve piece is
produced with `sub_segment(segment, from:, to:)`; a line piece connects
`segment_point(segment, at: from)` to `segment_point(segment, at: to)`.

Lines, quadratic Beziers, and ordinary arcs are handled semantically. Lines
produce line pieces, while quadratic Beziers and arcs produce the original
primitive plus the chord joining its endpoints. Cubic Beziers use a
cubic-specific numerical solver that samples analytic support points and then
refines curve-line boundaries.

`PathError` means the generated pieces could not be turned into a valid closed
`Subpath`. The other `HullError` values are reserved for cubic solver
consistency failures, so the function reports an error rather than guessing at
a hull.

For a whole continuous subpath, use `subpath_hull`:

```gleam
pub fn hull(
  subpath: svg_path.Subpath,
) -> Result(svg_path.Subpath, convex_hull.HullError) {
  convex_hull.subpath_hull(subpath)
}
```

This returns a closed `Subpath` containing the convex hull of all segments in
the input. Internally each segment is first converted to a segment hull, then
those convex loops are unioned together.

For a path with multiple subpaths, use `path_hull`:

```gleam
convex_hull.path_hull(path)
```

Empty subpaths are ignored, and the result is still a single closed `Subpath`.

## Parsing

`svg_path/parse` accepts normal SVG path data syntax, including:

- comma separators
- whitespace separators
- compact signed numbers such as `M0-1`
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

Closepath is also represented semantically. If parsing `Z` needs a straight
line back to the subpath start, the parser inserts that line and marks the
subpath closed. If the subpath is already back at its start, no extra line is
inserted; the subpath is just marked closed.

## Path Serialization

`svg_path/serialize` emits canonical SVG path data.

By default it uses:

- absolute commands
- up to 5 decimal places
- stripped trailing decimal zeroes
- readable whitespace
- repeated command letters
- one-line path data
- `H` and `V` for horizontal and vertical lines when possible
- `Z` for closed subpaths

```gleam
import svg_path/parse
import svg_path/serialize

pub fn tidy_path_data(input: String) -> String {
  let assert Ok(path) = parse.path(input)

  serialize.path(path)
}
```

If you want a complete SVG document for debugging or examples, use
`svg_path/svg` with a view box, per-path style strings, and optional styled
text labels. This is a deliberately small helper for quick drawings, not a
full rendering layer:

```gleam
import svg_path/svg

pub fn debug_svg(
  things: svg.ThingsToDraw,
  box: svg_path.BoundingBox,
) -> String {
  svg.document(things, view_box: box)
}
```

Serialization options can use relative commands, commas inside coordinate
pairs, smaller whitespace, rounded numbers, fixed decimal places, omitted
repeated command letters, and left-padded numbers for visual alignment. The
lower-level decimal controls are split into `LeftDecimalOptions` and
`RightDecimalOptions`.

```gleam
import svg_path/parse
import svg_path/serialize

pub fn compact_path_data(input: String) -> String {
  let assert Ok(path) = parse.path(input)
  let options =
    serialize.relative_decimal_options(2)
    |> serialize.minimize_whitespace
    |> serialize.repeat_commands(False)
    |> serialize.with_left_padding(serialize.AutoLeftPadding)

  serialize.path_with_options(path, options:)
}
```

### Repeated Command Letters

SVG allows repeated commands of the same type to omit later command letters.
Pass `False` to `repeat_commands` to use this form.

```gleam
serialize.default_options()
|> serialize.repeat_commands(False)
```

For example, repeated line commands may serialize as:

```text
M 0 0 L 10 10 20 20 30 30
```

instead of:

```text
M 0 0 L 10 10 L 20 20 L 30 30
```

### Newlines

Use `with_newlines` to choose where the serializer inserts newlines:

```gleam
serialize.default_options()
|> serialize.with_newlines(serialize.AtSubpaths)
```

`OneLine` keeps the path data on one line. `AtSubpaths` puts each subpath on
its own line:

```text
M 0 0 L 10 10 L 20 20 Z
M 100 100 L 110 110 L 120 120 Z
```

`AtSegments` puts each segment on its own line. With repeated command letters
enabled, each line starts with its command:

```text
M 0 0
L 10 10
L 20 20
Z
```

The one unusual combination is `AtSegments` with `repeat_commands(False)`.
There, each emitted command letter is followed by a newline, repeated commands
are omitted, and `M`/`m` always starts a new line. This can be combined with
fixed-width decimal formatting for visual alignment:

```gleam
serialize.fixed_decimal_options(2)
|> serialize.with_left_padding(serialize.AutoLeftPadding)
|> serialize.with_commas(True)
|> serialize.repeat_commands(False)
|> serialize.with_newlines(serialize.AtSegments)
```

```text
M
  20.00, -30.00 C
 -15.00,  40.00   80.00, -90.00  140.00,  20.00
 260.00,  30.00 -320.00,  45.00  480.00, -60.00
 600.50, -70.25  720.00,  80.00  840.00, -90.00
```

### Left Padding

`RightDecimalOptions` controls the fractional side of serialized numbers:

- `System` uses the system float formatter.
- `AtMost(Int)` rounds to at most that many decimal places and strips trailing
  zeroes.
- `Fixed(Int)` rounds to exactly that many decimal places.

`LeftDecimalOptions` controls the whole-number side:

- `Succinct` uses no left padding.
- `LeftPadding(Int)` pads the whole-number side to that width with spaces.
- `AutoLeftPadding` pre-scans the serialized value and chooses a shared width.

Use `with_left_padding` to align serialized numbers visually:

```gleam
serialize.fixed_decimal_options(1)
|> serialize.with_left_padding(serialize.AutoLeftPadding)
```

For more explicit control, use `with_left_decimals` and
`with_right_decimals`:

```gleam
serialize.default_options()
|> serialize.with_left_decimals(serialize.AutoLeftPadding)
|> serialize.with_right_decimals(serialize.Fixed(2))
```

### Closepath and Final Lines

Closed subpaths serialize with `Z`.

If a closed subpath ends with a non-zero-length straight line back to the
subpath start, the serializer drops that final line command and uses `Z` to
represent the closure.

For example, this internal subpath:

```text
Line(0,0 -> 10,0)
Line(10,0 -> 10,20)
Line(10,20 -> 0,0)
closed
```

serializes as:

```text
M 0 0 H 10 V 20 Z
```

not:

```text
M 0 0 H 10 V 20 L 0 0 Z
```

This is intentional. `Z` is the SVG-native representation of closing the
subpath, and including both the final straight line and `Z` would be redundant.

Zero-length final lines are different. If the final segment is
`Line(A, A)`, the serializer keeps it visible:

```text
M 0 0 H 0 Z
```

This is also intentional. A zero-length line is often evidence of unusual
upstream geometry. The serializer does not hide that from the user.

The same rule applies in relative mode:

```text
m 10 10 h 10 h -10 h 0 Z
```

The final `h 0` remains visible because it is a zero-length line.

### Cleaning Zero-Length Lines

Serialization is not a general cleanup pass. It only uses `Z` to avoid a
redundant non-zero-length final closing line.

If you want to remove zero-length straight lines from a subpath, use
`clean_subpath`. If you want to clean a whole path, use `clean_path`; it removes
empty subpaths and runs `clean_subpath` on each remaining subpath.

```gleam
import svg_path

pub fn clean(subpath: svg_path.Subpath) -> svg_path.Subpath {
  svg_path.clean_subpath(subpath)
}

pub fn clean_all(path: svg_path.Path) -> svg_path.Path {
  svg_path.clean_path(path)
}
```

`clean_subpath` removes zero-length `Line` segments while preserving the
subpath's closed/open state. If a subpath consists only of zero-length lines,
one zero-length line is retained so the subpath does not become empty.

This distinction is deliberate:

- `serialize.subpath` preserves odd zero-length lines so the output still shows
  that the object contains them.
- `svg_path.clean_subpath` is an explicit user-requested cleanup.

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

```gleam
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
translate(10)scale(2) skewX(3)
```

Transform serialization prefers readable SVG forms when the matrix can be
recognized clearly:

```text
translate(10 20)
translate(10 20)scale(2)
rotate(30)
translate(10 20)rotate(30)scale(2 3)
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
  |> serialize.to_string_with_options(
    options: serialize.default_options() |> serialize.force_matrix,
  )
}
```

## Inspecting Paths

`svg_path/inspect` prints path data structures for debugging and tests. It is
not the SVG `d` serializer.

Human-readable structural inspection:

```gleam
import svg_path
import svg_path/inspect

pub fn inspect_line() -> String {
  svg_path.line(
    start: svg_path.point(0.0, 0.0),
    end: svg_path.point(12.0, 10.0),
  )
  |> inspect.segment
}
```

Example output:

```text
Line(start=0,0 end=12,10)
```

Copy-pasteable Gleam inspection:

```gleam
import svg_path
import svg_path/inspect

pub fn inspect_code(path: svg_path.Path) -> String {
  inspect.path_code(path)
}
```

Example output:

```text
svg_path.path([
  svg_path.assert_subpath([
    svg_path.line(start: svg_path.point(0.0, 0.0), end: svg_path.point(12.0, 10.0))
  ])
])
```

Inspection options support decimal rounding, fixed decimal places, and
left-padding for visual alignment. As with serialization, lower-level decimal
controls are split into `LeftDecimalOptions` and `RightDecimalOptions`, with the
same constructors.

```gleam
import svg_path
import svg_path/inspect

pub fn inspect_aligned(path: svg_path.Path) -> String {
  let options =
    inspect.fixed_decimal_options(1)
    |> inspect.with_left_padding(inspect.AutoLeftPadding)

  inspect.path_code_with_options(path, options:)
}
```

`AutoLeftPadding` pre-scans the value being inspected and chooses a shared
left-side width for the numbers in that output. `LeftPadding(Int)` lets you
choose the width yourself. Use `Succinct` to disable left padding.

## Converting Matrices From `matrix_gleam`

`svg_path` does not depend on
[`matrix_gleam`](https://hex.pm/packages/matrix_gleam), but the tuple helpers
make the conversion small if your application uses both packages.

```gleam
import matrix/mat3f
import svg_path/transform

pub fn to_mat3f(matrix: transform.Matrix) -> mat3f.Mat3f {
  let #(a, b, c, d, e, f) = transform.to_tuple(matrix)

  mat3f.new(
    a, b, 0.0,
    c, d, 0.0,
    e, f, 1.0,
  )
}
```

```gleam
import matrix/mat3f
import svg_path/transform

pub type MatrixConversionError {
  NonAffineMatrix
}

pub fn from_mat3f(
  matrix: mat3f.Mat3f,
) -> Result(transform.Matrix, MatrixConversionError) {
  case matrix.x.z == 0.0 && matrix.y.z == 0.0 && matrix.z.z == 1.0 {
    False -> Error(NonAffineMatrix)
    True -> {
      Ok(transform.from_tuple(#(
        matrix.x.x,
        matrix.x.y,
        matrix.y.x,
        matrix.y.y,
        matrix.z.x,
        matrix.z.y,
      )))
    }
  }
}
```

Further documentation can be found at <https://hexdocs.pm/svg_path>.

## Development

```sh
gleam test
gleam docs build
```
