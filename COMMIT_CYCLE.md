# Commit Cycle

This file describes the intended workflow for generated figures during normal
feature work and release prep.

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

It regenerates the five README figures in `test/generated/readme`, regenerates
all published Gallery figures in `test/generated/gallery`, verifies that every
published filename was produced, and promotes the Gallery figures into
`docs/gallery`. README figures still require review and promotion through the
asset worktree described below.

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
9. Publish to Hex from that exact release commit.

## Practical Notes

- Use `markdown-assets` only as the mutable branch name.
- Use `assets-vX.Y.Z` only as release asset tag names.
- Do not create a branch and a tag with the same name.
- Do not rewrite or delete old asset tags.
- If a Hex release is replaced, move both relevant tags deliberately:
  `vX.Y.Z` on `main`, and `assets-vX.Y.Z` on `markdown-assets` if README
  figures changed.
