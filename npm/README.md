# JavaScript package preparation

This directory holds a **npm distribution `svg-path-geometry`**. Gleam remains the
source of all geometry algorithms. No changes to the Gleam or F# API are needed.

## Release package versus local tools

| Directory | Purpose | Published? |
| --- | --- | --- |
| `package/` | Distributable package metadata and user README | Copied into the tarball |
| `tools/` | Private Node build/test tools and their own lockfile | Never |
| `tools/gleam/` | Isolated Gleam build root, depending on the repository | Never |
| `tests/` | Adapter, installed-package, TypeScript, and browser checks | Never |
| `generated/` | Rebuilt package contents; ignored by Git | Used by `npm pack` |
| `artifacts/` | Verified `.tgz` files; ignored by Git | Ready for local installation |
| `test-output/` | Consumer install, cache, browser bundle, verification report | Never |

The two `package.json` files are intentionally separate. Only the local tools
are private. Run tooling commands with `--prefix npm/tools`. Publish only the
verified archive as described below; never run bare `npm publish` in the root
or tools directory. The initial distribution version is `0.1.0`.

## Build and verify

Requirements: Gleam **1.18.1**, Node 20+, and npm. The adapter uses the compiler's
exported interface and generated constructor accessors; another compiler version
requires an explicit compatibility review. The build root pins the same
`gleam_stdlib` version as the repository lock, and the builder checks agreement.

From the repository root:

```sh
npm ci --prefix npm/tools --ignore-scripts
npm run build --prefix npm/tools
```

The builder writes `npm/generated/`. It regenerates all 36 public modules,
600 function adapters, TypeScript declarations, API documentation, source
provenance, and bundled runtime dependencies. Private/internal Gleam API entries
are absent from the interface and therefore not exported by the wrapper.

For browser verification, install the tooling's Chromium once:

```sh
npm exec --prefix npm/tools -- playwright install chromium
npm test --prefix npm/tools
```

Alternatively set `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` to an existing Chromium
executable. Verification is not silently skipped if no browser is available.
`npm test` rebuilds, checks conversions, packs, installs the **actual tarball** in
an isolated consumer, runs Node tests and strict TypeScript checks, verifies
all export paths, executes and type-checks the examples extracted from the packed
README, bundles for the browser, and runs geometry/DOM checks in
headless Chromium. Its local install is offline, with scripts disabled. The
package needs no runtime dependencies or build steps on the consumer's machine.

To install the resulting local package in another project:

```sh
npm install /absolute/path/to/svg_path/npm/artifacts/svg-path-geometry-0.1.0.tgz
```

The archive is self-contained. Consumers need neither Gleam nor a checkout of
this repository. ESM is supported; CommonJS and fine-grained tree shaking are
not promised.

## Keeping Gleam authoritative

`build.mjs` obtains the public schema through `gleam export package-interface`.
It compiles the library as a dependency of a private leaf project, leaving the
root's build/test profile alone. `bridge.mjs` converts lists, records, variants,
results, options, tuples and callbacks; it implements no geometry formulas.
Opaque Gleam values remain opaque handles.

The generated `API.md` and `.d.mts` files describe every operation. The adapter
uses camelCase names and fields, but keeps argument order, full option records,
explicit Results, units, tolerances, and error variants. The user README records
these conventions and the few JavaScript-specific representation rules.

`source.json` identifies the Gleam version, Git commit, dirty-source flag,
source fingerprint, adapter fingerprint, compiler, standard library, and npm
version. The npm version can advance independently when only the adapter changes.
No historical npm releases or matching Hex version numbers are needed.

This is packaging and interoperability work, not a new geometry audit. The
portable Gleam JavaScript suite remains the numerical regression suite. Existing
policy limitations and the deferred API-001 error variant are unchanged.

## Release and publication

Run commands from the repository root. Use Node 24 and Gleam 1.18.1 for the
release build; CI checks consumers on both Node 20 and 24. The builder and
verifier never publish. The distribution manifest is public, while the tools
manifest must stay private.

1. Update `package/package.json` for the intended npm version and review the
   packaged README. npm versions are independent of Gleam/F# versions.
2. Commit the release inputs, push, and wait for the `npm package` workflow's
   Node 20 and 24 jobs to pass. Do not include unrelated workspace changes.
3. From that commit, run the verification below. It rebuilds, packs, installs,
   and tests the exact archive. If using an existing Chromium installation, set
   `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` to its executable first.

```sh
npm ci --prefix npm/tools --ignore-scripts
npm exec --prefix npm/tools -- playwright install chromium
npm test --prefix npm/tools
```

4. Inspect `test-output/report.json`: package/version, source commit,
   `sourceDirty: false`, adapter/source fingerprints, and archive integrity.
   Keep that report with the release archive. A pre-commit archive is not the
   final release artifact. Archive paths below are for the initial `0.1.0`;
   substitute the new version for subsequent releases.
5. Log into the intended npm account and inspect the publication dry run:

```sh
npm login
npm whoami
npm publish ./npm/artifacts/svg-path-geometry-0.1.0.tgz --access public --dry-run
```

6. Only when publication is explicitly authorized, publish that same archive.
   Complete npm's interactive authentication/2FA prompts:

```sh
npm publish ./npm/artifacts/svg-path-geometry-0.1.0.tgz --access public
npm view svg-path-geometry@0.1.0 version dist.integrity
```

7. Compare registry integrity with the verified report. Install the exact
   registry version in a fresh consumer and run the README recipe. After
   successful publication, tag the source commit `npm-v0.1.0` and push that tag.
   npm tags are separate from Gleam tags. Do not reuse a published version for
   different package contents.

Consumer-readiness findings and remaining limitations are recorded in
[CONSUMER-REVIEW.md](CONSUMER-REVIEW.md). `VALIDATION.md` retains the historical
preview checks; `test-output/report.json` describes the latest verified archive.
