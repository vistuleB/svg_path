# Contributor Workflow

This file describes coding conventions, verification, generated figures, and
release preparation for contributors, whether working manually or with an agent.

## Coding And Documentation Conventions

- Name every error-variant payload argument, including single arguments.
  Labels describe the carried value: for example, `divergence`, not `depth`,
  when reporting fitting error remaining at a recursion limit.
- Use `xml`, not `svg`, as the Markdown code-fence language for SVG examples.

## Tested README Recipes

The `tested-recipes` block in `README.md` must match
`test/readme_recipes.gleam`. Edit the compiled module, format it, and copy its
contents into that block. `bash scripts/check-readme-recipes` checks the match;
CI and `scripts/test-fast` run it before the tests. Behavior checks live in
`test/readme_recipes_test.gleam`.

## Test Profiles And Reporting

Use Gleam 1.18.1 for release validation and formatting, matching both CI jobs.
Different compiler versions can produce different formatting.

- `gleam test`: default suite.
- `scripts/test-fast`: ordinary suite, including convex-hull smoke tests.
- `scripts/test-slow`: additional convex-hull stress tests only.
- `scripts/test-all`: both profiles.
- `scripts/test-portable [all|erlang|javascript]`: shared numerical regressions
  on both targets by default, or on the named target.
- `scripts/test-release`: canonical pre-release verification, including both
  root profiles and the portable suite on Erlang and JavaScript; fast tests
  alone do not verify a release.

In review notes and reports, record the exact completed command and test count.
Reserve claims that the full suite passes for a successful `scripts/test-all`
or `scripts/test-release` run in the current worktree.

## Portable Numerical Tests

`test_portable/modules.txt` selects existing modules from `test/`, including
support modules. `scripts/test-portable` copies them into the ignored
`test_portable/test/` directory and installs its Gleeunit runner. Edit the
original tests in `test/`; generated copies must not be edited or committed.
The standalone package compiles the library as a dependency, avoiding the
root test directory's Erlang-only figure I/O. Its manifest locks dependencies.

The selection runs 400 tests and covers curve intersections (including scale/translation
regressions), overlaps, SVG arc normalization, parsing, serialization, CSG,
clipping, area, stroke, transforms, and signed-zero Bézier/ellipse splitting. Add suitable modules to the selection as coverage
expands; portable modules and their support code must implement both targets.
CI runs the same selection in separate Erlang and JavaScript jobs. Failures
must be fixed or explained, not bypassed by target-specific exclusions.

Do not run this script concurrently with `scripts/test-slow`, which temporarily
moves the source `test/` directory, or run two portable scripts concurrently in
the same checkout, since they share the generated test directory.

## Area Performance Probe

After `scripts/test-portable javascript`, run `node scripts/benchmark-area.mjs`.
It reports filled-area time, flattened segment count, and normalized area for
one quadratic at scales 1, 1,000, and 100,000, using default and scaled geometric
tolerances. Each case runs in a fresh JavaScript worker without warm-up and has
an eight-second timeout. Timings include linearization and arrangement, but not
module loading. They are diagnostic observations, not CI timing assertions.

The area sweeps prune disjoint x-ranges. Many edges spanning the same x-range
can still require quadratic work; this probe is not a worst-case bound.

## Figure Layout

- When comparing opposite orientations, keep each direction arrow at the same
  visual location and only reverse its direction.
- Compute each panel's actual geometry bounds and recenter the geometry in its
  panel rather than relying on hand-tuned translations when practical.

## Figure Audiences

There are two different audiences:

- `README.md` is rendered by Hex, so its figures need externally hosted
  absolute URLs.
- `GALLERY.md` is browsed from the repository, so its figures can live directly
  on `main`.

## Local Previews

For chat/debug previews, write SVGs under `examples/debug/` and show them with
absolute local Markdown image paths.

Do not use GUI commands such as `open`, Chrome, Inkscape, or Preview for this
workflow. Do not generate PNG fallbacks unless specifically requested.

## Regenerating Every Published Figure

Run the canonical generator from the repository root:

```sh
scripts/generate-published-figures
```

It regenerates the thirteen README figures in `test/generated/readme`, regenerates
all published Gallery figures in `test/generated/gallery`, verifies that every
published filename was produced, and promotes the Gallery figures into
`docs/gallery`. README figures still require review and promotion through the
asset worktree described below.

The package-title second-offset arrangement is captured from production calls
and returns by `scripts/gallery/package_title_arrangement.escript` after the
fast build, writing directly to `test/generated/gallery`. The old drawing is
archived at `docs/gallery/archive/second-offset-arrangement-2026-08-22.svg`;
no generator reads the archived SVG.
The two offset-text figures are recomputed by their original fixtures before
their generated SVGs are included in the Gallery.

### Concurrent gallery-only generation

Build the root and `examples/readme_arrangement_figures` projects with
`gleam build`, then run `escript scripts/gallery/run.escript` from the root.
This runs the 29 Erlang gallery figures concurrently without requiring passing tests
or promoting images. Pass one or more exact SVG filenames to select jobs.

Each job prints START, DONE or FAILED with elapsed wall time and Erlang
reductions. Every ten idle seconds the coordinator prints unfinished filenames,
elapsed times and current reductions. Successful files are written immediately;
failures do not cancel other jobs. The final exit status is nonzero if any job
failed. `test/generated/gallery/timings.tsv` is replaced as results arrive;
failed jobs have a `.svg.error.txt` diagnostic, and the generated index links
only successful jobs from this run. Existing SVGs are not deleted on failure,
so consult the run report rather than treating file existence as success.

The portable registry is filename, title, and a zero-argument SVG-producing
function. Only the development runner in `test/gallery_jobs.erl` handles
processes and timing; an F# port can use the same registry with a .NET scheduler.
The arrangement tracing job alone uses an isolated VM to avoid interfering
with other jobs' trace patterns; its wrapper reductions exclude child-VM work.
Shared build steps happen before launching jobs. Each offset-text job runs its
own required fixture before reading that fixture's output.

The four additional W3C join comparisons use the JavaScript public API build.
After `gleam build --target javascript` in `examples/public_api_smoke`, run
`node scripts/gallery/w3c_join_comparison.mjs` from the root. This writes to
`test/generated/gallery`; an optional directory argument selects another output
location (use `examples/debug` for chat previews). The canonical published-figure
generator runs this step and promotes all 33 Gallery figures. W3C reference SVGs
are vendored in `scripts/gallery/w3c-join-reference`; generation needs no network.

## Gallery Figures

Gallery figures are committed on `main`.

Workflow:

1. Generate or regenerate source outputs, usually under
   `test/generated/gallery/...`.
2. Copy the selected stable SVGs into `docs/gallery/...`.
3. Link `GALLERY.md` to those files with repository-local paths:

   ```text
   docs/gallery/name.svg
   ```

4. Commit `GALLERY.md` and `docs/gallery/...` together on `main`.

`GALLERY.md` does not need `markdown-assets`, because Hex does not render it as
package documentation.

## README Figures During Feature Work

README figures use the `markdown-assets` branch while work is in progress.

The mutable preview URL shape is:

```text
https://raw.githubusercontent.com/vistuleB/svg_path/markdown-assets/figures/name.svg
```

Workflow:

1. Generate or regenerate source outputs in the normal working tree, usually
   under `test/generated/...` or `examples/debug/...`.
2. If the README needs to be inspected before the main feature commit is final:
   - copy the selected README-facing SVGs into the `figures/` directory of a
     separate worktree checked out on the orphan `markdown-assets` branch,
   - commit those figure changes on `markdown-assets`,
   - push `markdown-assets`,
   - point the temporary README URLs at the mutable `markdown-assets` branch.
3. Commit the README/source changes on `main`.

Generated README figures should not be referenced through local
package-relative paths. Hex will not reliably render those paths.

## README Figures During Release Prep

For a release, `README.md` should not point at the mutable `markdown-assets`
branch. It should point at an immutable asset tag.

Release asset URL shape:

```text
https://raw.githubusercontent.com/vistuleB/svg_path/assets-vX.Y.Z/figures/name.svg
```

Release workflow:

1. Run the canonical pre-release verification command:

   ```sh
   scripts/test-release
   ```

   This includes the slow test profile; `gleam test` alone does not. See
   `test_slow/README.md` for how that profile is structured.

2. Ensure the `markdown-assets` worktree contains the final README-facing SVGs
   for the release.
3. Commit and push `markdown-assets`.
4. Tag that exact `markdown-assets` commit:

   ```sh
   git tag assets-vX.Y.Z
   git push origin assets-vX.Y.Z
   ```

5. On `main`, rewrite README image URLs from `markdown-assets` to
   `assets-vX.Y.Z`.
6. Verify the release README no longer points at the mutable branch:

   ```sh
   rg 'raw.githubusercontent.com/vistuleB/svg_path/markdown-assets' README.md
   ```

   For a release commit, this should print nothing.

7. Commit release prep on `main`, including:

   - `README.md` asset URL rewrites,
   - `CHANGELOG.md`,
   - `gleam.toml` version bump.

8. Tag the release commit on `main` as `vX.Y.Z`.
9. Let the user run the final `gleam publish` commands from that exact
   release commit.

## Practical Notes

- Use `markdown-assets` only as the mutable branch name.
- Use `assets-vX.Y.Z` only as release asset tag names.
- Do not create a branch and a tag with the same name.
- Do not rewrite or delete old asset tags.
- If a Hex release is replaced, move both relevant tags deliberately:
  `vX.Y.Z` on `main`, and `assets-vX.Y.Z` on `markdown-assets` if README
  figures changed.
