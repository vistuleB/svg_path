# Agent Instructions

- Do not use `svg` as a Markdown code fence language. Use `xml` instead.

## Commit Permission

- Do not create a git commit unless the user explicitly instructs you to commit.
- Treat questions about committing, especially messages ending in `?`, as discussion or permission checks, not as authorization.
- If the user asks whether a commit should be made, answer the question and wait for an explicit follow-up command before committing.

## README Images

- Markdown figures that must render on hex.pm and in local VSCode preview should be published to the orphan `markdown-assets` branch and referenced with raw GitHub URLs like `https://raw.githubusercontent.com/vistuleB/svg_path/markdown-assets/figures/name.svg`.
- Do not point README images only at generated test-output paths. Generated figures can still live under `test/generated/...`, but Markdown image URLs should point at the `markdown-assets` branch copy.
- When adding or regenerating Markdown figures:
  1. Generate or update the SVGs in the normal working tree.
  2. Copy the stable Markdown-facing SVGs into the `figures/` directory of a `markdown-assets` worktree.
  3. Commit and push the `markdown-assets` branch.
  4. Reference the pushed files from Markdown with `https://raw.githubusercontent.com/vistuleB/svg_path/markdown-assets/figures/...`.
  5. Tell the user when the asset branch needs to be pushed before remote renderers can display the new figures. Offer a short checkpoint such as: “Shall we push these figures to `markdown-assets` so you can inspect them through the README URL?”
- Batch Markdown figure updates so the user is asked for push permission at most once per figure-editing pass.
- Use a separate worktree for `markdown-assets` so the main checkout can remain dirty. One existing local worktree path is `/private/tmp/svg_path-markdown-assets`.
- When generating paired or tabular graphics where one version changes a subpath's orientation, keep that subpath's arrow in the same visual location across versions and only flip its direction. This makes orientation changes easier to compare.

## Communication Style

- Avoid using the word “tiny” unless it is technically relevant, such as describing a small numeric tolerance, geometry case, file size, or similar concrete measurement.
- Keep language plain, vanilla, and jargon-free by default.
- Prefer direct descriptions over colorful phrasing, metaphors, or dramatic wording.
- Use technical terms when they clarify the work, but avoid unnecessary slang or invented labels.
