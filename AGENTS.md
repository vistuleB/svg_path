# Agent Instructions

- Do not use `svg` as a Markdown code fence language. Use `xml` instead.

## Commit Permission

- Do not create a git commit unless the user explicitly instructs you to commit.
- Treat questions about committing, especially messages ending in `?`, as discussion or permission checks, not as authorization.
- If the user asks whether a commit should be made, answer the question and wait for an explicit follow-up command before committing.

## README Images

- Markdown figures that must render on hex.pm and in local VSCode preview should be published to the orphan `markdown-assets` branch and referenced with raw GitHub URLs like `https://raw.githubusercontent.com/vistuleB/svg_path/markdown-assets/figures/name.svg`.
- Do not point README images only at generated test-output paths. Generated figures can still live under `test/generated/...`, but Markdown image URLs should point at the `markdown-assets` branch copy.
- Key invariant: if a turn changes README-visible assets and the user is expected to inspect those assets through the README URL, the matching `markdown-assets` commit and push must happen before that assistant turn completes.
- Do not end the turn with a final answer that merely asks whether to push `markdown-assets`. Ask for push permission during the work, batch all figure changes for that pass, perform the push if approved, and only then send the final response.
- When adding or regenerating Markdown figures, generate or update the normal working-tree SVGs, copy the stable Markdown-facing SVGs into the `figures/` directory of a `markdown-assets` worktree, reference them with `https://raw.githubusercontent.com/vistuleB/svg_path/markdown-assets/figures/...`, then commit and push `markdown-assets` before saying the README is ready to inspect.
- Batch Markdown figure updates so the user is asked for push permission at most once per figure-editing pass.
- Use a separate worktree for `markdown-assets` so the main checkout can remain dirty. One existing local worktree path is `/private/tmp/svg_path-markdown-assets`.
- When generating paired or tabular graphics where one version changes a subpath's orientation, keep that subpath's arrow in the same visual location across versions and only flip its direction. This makes orientation changes easier to compare.

## Previewing Figures In Codex Desktop Chat

- Store preview SVGs under `examples/debug/`.
- Display SVGs with ordinary Markdown image syntax using an absolute local filesystem path.
- Do not use `file://`, relative paths, plain paths, or GUI commands such as `open`, Chrome, Inkscape, or Preview.
- Preview SVGs must include explicit root `width` and `height` attributes in addition to `viewBox`; SVGs with only `viewBox` have failed to render inline in Codex desktop chat.
- In this repo, this exact pattern has rendered successfully in Codex desktop chat:

  `![svg preview probe](/Users/jpsteinb/github.com/vistuleB/svg_path/examples/debug/svg_preview_probe.svg)`

- For generated figures, use the same shape:

  `![label](/Users/jpsteinb/github.com/vistuleB/svg_path/examples/debug/name.svg)`

- Do not generate PNG fallbacks unless the user explicitly asks for PNG. SVG is the expected preview format.

## Communication Style

- Avoid using the word “tiny” unless it is technically relevant, such as describing a small numeric tolerance, geometry case, file size, or similar concrete measurement.
- Keep language plain, vanilla, and jargon-free by default.
- Prefer direct descriptions over colorful phrasing, metaphors, or dramatic wording.
- Use technical terms when they clarify the work, but avoid unnecessary slang or invented labels.
