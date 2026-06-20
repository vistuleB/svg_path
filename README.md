# svg_path

[![Package Version](https://img.shields.io/hexpm/v/svg_path)](https://hex.pm/packages/svg_path)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/svg_path/)

`svg_path` is a utility library for parsing, serializing, inspecting, and
performing simple geometric manipulations on SVG paths and transforms.

The package is especially mindful of providing a practical and versatile API for the
construction of valid SVG paths from noisy data. It also offers several knobs to
fine-tune the details of path and SVG transform serialization.

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
  |> svg_path.path_arcs_to_bezier
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

A `Path` may consist of an empty list of subpaths, and an open `Subpath` may
consist of an empty list of segments, which is intentional. Empty paths and
empty open subpaths serialize to the empty string. A closed `Subpath` with no
segments is impossible to construct.

## Ergonomics for Endpoint Reconciliation

Helper functions in the root module let users employ an `EndpointPolicy` option to specify
different types of error-recovery behavior for non-matching endpoints:

```gleam
svg_path.Strict
svg_path.Wiggle
svg_path.Bridge
svg_path.WiggleThenBridge
```

`Strict` requires exact endpoint equality. `Wiggle` moves nearby endpoints
together within the package's default wiggle tolerance of `0.000000001`.
`Bridge` keeps existing endpoints in place and inserts a straight line segment
when needed. `WiggleThenBridge`, as the name implies, first tries `Wiggle`
before falling back on `Bridge`.

The behavior of option-free functions and constructors is `EndpointPolicy.Strict`. These
include:

```gleam
svg_path.subpath(segments)
svg_path.append_segment(subpath, segment)
svg_path.concat(first_subpath, second_subpath)
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
svg_path.concat_with(first_subpath, second_subpath, policy: svg_path.WiggleThenBridge)
svg_path.splice_with(subpath, start:, delete:, insert:, policy: svg_path.Wiggle)
svg_path.set_closed_with(subpath, closed: Bool, policy: svg_path.Bridge)
```

Use the `assert_` functions for hand-authored/static geometry where invalid
continuity is a programmer error:

```gleam
svg_path.assert_subpath(segments)
svg_path.assert_append_segment(subpath, segment)
svg_path.assert_concat(first_subpath, second_subpath)
svg_path.assert_splice(subpath, start:, delete:, insert:)
svg_path.assert_set_closed(subpath, closed: Bool)
```

### Concatenating Subpaths

`concat` combines two open subpaths into one open subpath. With the default
`Strict` policy, the end of the first subpath must exactly equal the start of
the second subpath. Empty open subpaths act as identity values.

```gleam
svg_path.concat(first_subpath, second_subpath)
```

Closed subpaths are rejected rather than implicitly opened. This keeps
closedness as explicit topology: if you want to discard it, use
`set_closed(subpath, closed: False)` first.

Use `concat_with` when you want another endpoint policy:

```gleam
svg_path.concat_with(first_subpath, second_subpath, policy: svg_path.Wiggle)
svg_path.concat_with(first_subpath, second_subpath, policy: svg_path.Bridge)
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

## Converting Arcs to Beziers

Some SVG consumers and geometry workflows prefer to avoid elliptical `Arc`
segments. Use the `_arcs_to_bezier` function family to replace arcs with cubic
Bezier curves while preserving lines, quadratic Beziers, and existing cubic
Beziers:

```gleam
svg_path.segment_arcs_to_bezier(segment)
svg_path.subpath_arcs_to_bezier(subpath)
svg_path.path_arcs_to_bezier(path)
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

Serialization options can use relative commands, remove optional whitespace,
round numbers, keep fixed decimal places, and omit repeated command letters.

```gleam
import svg_path/parse
import svg_path/serialize

pub fn compact_path_data(input: String) -> String {
  let assert Ok(path) = parse.path(input)
  let options =
    serialize.relative_decimal_options(2)
    |> serialize.minimize_whitespace
    |> serialize.repeat_commands(False)

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
`clean_subpath`.

```gleam
import svg_path

pub fn clean(subpath: svg_path.Subpath) -> svg_path.Subpath {
  svg_path.clean_subpath(subpath)
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
left-padding for visual alignment.

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
choose the width yourself. `NoLeftPadding` disables it.

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
