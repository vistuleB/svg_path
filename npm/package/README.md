# SVG path geometry — local preview

JavaScript and TypeScript access to the `svg_path` Gleam geometry library.
The package name and version are provisional. This package is private and is
not published. Geometry algorithms are compiled from Gleam, not reimplemented.

```js
import { parse, serialize, measure, unwrap } from 'svg-path-geometry-preview';

const path = unwrap(parse.path('M 0 0 L 3 4'));
console.log(unwrap(measure.pathLength(path))); // 5
console.log(serialize.path(path));
```

Use ESM imports in Node 20+ or a browser bundler. There are no runtime npm
dependencies, Node built-ins, install scripts, or network requests. CommonJS
`require()` is not a supported entry point.

## API conventions

All 36 public Gleam modules are available. Root exports include core types and
constructors, and module namespaces such as `parse`, `offset`, and `csg`.
Subpath imports are also available, for example
`import * as offset from 'svg-path-geometry-preview/offset'`.
Nested modules use subpaths (`transform/parse`) and root namespace names
(`transformParse`). See [API.md](API.md) and the included TypeScript declarations
for the complete generated function signatures and original Gleam documentation.

- Function and field names use camelCase; argument order matches Gleam.
- Lists and tuples use native JavaScript arrays. Inputs are not mutated.
- Single-constructor records are plain objects, e.g. `{ x: 3, y: 4 }`.
  Options are full records: use a module's `defaultOptions()` and object spread
  to override fields. Missing fields are errors, not implicit defaults.
- Multi-variant values use a `kind` discriminator, preserving Gleam variant
  names, e.g. `{ kind: 'Nonzero' }`. Exported constructor functions provide a
  typed alternative: `Nonzero()`, `Line(start, end)`, `Point(x, y)`.
  Unlabelled variant fields are named `value0`, `value1`, etc.
- Results are `{ ok: true, value }` or `{ ok: false, error }`. Errors retain
  their structured payloads. `unwrap(result)` throws `SvgPathError` with the
  original error available in `.detail`. Invalid JavaScript representations
  throw `TypeError`; numerical failures follow Gleam's Result contract.
- Options (Gleam `Option`, not configuration records) use `null` for None.
  Some is represented by its payload directly; None is `null`, not `undefined`
  or an omitted field. Gleam Nil is `undefined`. Ordering values are `-1`, `0`, or `1`.
- `Subpath` and transform `Matrix` remain opaque handles. Create and inspect
  them through the public functions; don't JSON-serialize or forge them.
  Handles belong to the loaded package instance that created them; they cannot
  cross workers, structured cloning, or separately loaded copies of the package.
  Use SVG serialization for portable path storage.
- Callbacks are synchronous and use the same native representations. Exceptions
  from callbacks propagate. Generic user payloads are passed through unchanged.
- Coordinates, units, tolerances, arc normalization, trimming policies, and
  documented limitations remain those of the Gleam library. Parsing does not
  silently normalize SVG arcs; use `pathNormalizeSvgArcs` explicitly when needed.

The adapter converts public data at call boundaries. It does not cache mutable
record inputs. Large arrays therefore incur conversion work; opaque subpaths
are reused. This preview does not claim fine-grained tree shaking or benchmark
parity with direct calls to compiled Gleam.

## Common tasks

Configuration records require every field. Start with defaults and override only
what you need. This example uses a round join on both sides of the corner:

```js
import { parse, offset, serialize, unwrap } from 'svg-path-geometry-preview';

const source = unwrap(parse.path('M 0 0 L 10 0 L 10 10'));
const options = { ...offset.defaultOptions(), innerJoin: offset.InnerRound() };
const shifted = unwrap(offset.pathWith(
  source, 1, offset.Round(), offset.Butt(), options,
  offset.defaultSingleOffsetTrimming(),
));
console.log(serialize.path(shifted));
```

You can handle a failure without throwing. Narrow the Result using `ok` before
reading `value` or `error` (TypeScript checks this):

```js
import { parse, serialize } from 'svg-path-geometry-preview';

const result = parse.path('M nope');
if (result.ok) {
  console.log(serialize.path(result.value));
} else {
  console.log(result.error.reason.kind); // UnsupportedCommand
}
```

Point-mapping callbacks receive ordinary objects and must return synchronously:

```js
import { parse, pathMapPoints, measure, unwrap } from 'svg-path-geometry-preview';

const source = unwrap(parse.path('M 0 0 L 3 4'));
const doubled = unwrap(pathMapPoints(source, point => ({
  x: point.x * 2,
  y: point.y * 2,
})));
console.log(unwrap(measure.pathLength(doubled))); // 10
```

Constructor exports are functions: call `Point(1, 2)`, not `new Point(1, 2)`.
Returned records and arrays are snapshots; changing them does not edit an opaque
subpath. Use the mapping/building functions to construct changed geometry.
Generated API documentation retains Gleam examples and terminology; those code
examples require translation to the JavaScript conventions above.

## Versions and source

npm versions are independent of Hex/F# versions. `source.json` records the Gleam
version, commit, source fingerprint, compiler, and public API counts. A wrapper
change can produce a new npm version without a new Gleam release.

MIT licensed; the bundled Gleam standard library is Apache-2.0 licensed, with
its license included under `THIRD-PARTY-LICENSES`.
