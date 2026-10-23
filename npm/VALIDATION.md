# Local npm preview validation — 2026-10-22

The preview is built from unchanged Gleam 3.1.5 source at
`79e9bfb9b57dd54e38e4414c58c86976ab95c3d1`, with Gleam 1.18.1 and
`gleam_stdlib` 1.0.3. Package and tooling names are provisional/private.

Completed checks:

- `node npm/tools/verify.mjs`, with `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH`
  selecting the existing headless Chromium installation:
  - **425** adapter representation/API checks passed. These include public
    constructor round trips through the real compiled Gleam representation,
    callback conversion, optional values, ordering, and verification that all
    600 exported functions have compiled implementations.
  - **15** installed-package Node tests passed, covering parsing, serialization,
    length, callbacks and generic errors, malformed JavaScript arguments,
    opaque values, options, intersections, projection, CSG/arrangement,
    offsets/strokes, affine factorization, and explicit SVG arc normalization.
  - Strict TypeScript consumer checks and the full declaration graph passed,
    including expected compile errors for invalid usage.
  - Every advertised module export imported from the installed tarball.
  - The installed tarball bundled for browsers without external imports.
  - Chromium executed geometry operations and wrote serialized path data into
    the SVG DOM without page errors.
- `scripts/test-portable javascript all`: **870 passed**, no failures.
  This is the existing numerical regression suite; it is separate from adapter
  tests. The full Erlang/F# suites and figures were not rerun for packaging work.

Local toolchain: Node 24.10.0, TypeScript 5.9.3, esbuild 0.25.11,
Playwright 1.56.1, existing Chromium 156.0.8078.4. CI uses Playwright's matching
Chromium download; the new CI workflow has not yet run remotely.

Artifact: `artifacts/svg-path-geometry-preview-0.1.0.tgz`, approximately
646 KB compressed and 4.13 MB unpacked. It contains 36 public modules and 600
function adapters, plus constructors, declarations, documentation, runtime
modules, licenses, and provenance. There are 39 package export entries including
root, result helpers, and source metadata. No runtime npm dependency is required.

The verifier creates a fresh consumer directory for each run and compares the
installed source metadata with the packed build. Machine-readable results,
archive integrity, toolchain and fingerprints are in `test-output/report.json`.
The preview is not published; no package name is reserved.

## Second cleanup pass

Committed the initial preview as `df70240`, then reran
`node npm/tools/verify.mjs` with the same Chromium override after cleanup:
**429 generator/adapter checks and 15 installed-package tests passed**, along
with strict TypeScript, all exports, browser bundling, and Chromium checks.
All 38 generated declaration files are byte-for-byte unchanged. No Gleam source
changed; the numerical suite was not rerun for this tooling-only pass.

Naming rules now share one implementation between code generation and runtime
conversion. Declaration/schema helpers are separate from build orchestration.
Metadata removal preserves symbols named like metadata fields, parameter-name
extraction ignores documentation examples, and unsupported type kinds produce
an explicit diagnostic. Verification clears the previous success report before
starting and creates its output directory explicitly.

## Third pass: installed consumer review

`node npm/tools/verify.mjs` with the existing Chromium override passed **429**
generator/adapter checks, **17** installed-package tests, and **4** examples
extracted directly from the installed README. All four examples also passed
strict TypeScript checking, alongside the existing consumer/declaration checks.
Export, required documentation/license, bundling, and Chromium checks passed.
The resulting archive is 647,165 bytes packed, 4,138,637 bytes unpacked.

No runtime adapter or Gleam source changes were needed. CI now selects Node 20
and 24; that matrix has not run remotely. Local validation used Node 24 only.
See [CONSUMER-REVIEW.md](CONSUMER-REVIEW.md) for the findings and publication gates.

## Limits of these checks

These checks exercise conversion mechanics broadly and selected real operations
end to end. They do not execute all 600 operations with representative geometry,
nor claim complete upstream-library parity. Browser checks cover Chromium, not
all browsers. No wrapper-performance equivalence or fine-grained tree shaking
is claimed. The public adapter conventions still need review before publication.
