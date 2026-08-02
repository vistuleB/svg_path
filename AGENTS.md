# Agent Instructions

- Do not use `svg` as a Markdown code fence language. Use `xml` instead.

## Commit Permission

- Do not create a git commit unless the user explicitly instructs you to commit.
- Treat questions about committing, especially messages ending in `?`, as discussion or permission checks, not as authorization.
- If the user asks whether a commit should be made, answer the question and wait for an explicit follow-up command before committing.

## Test Reporting

- Always report the exact test command or named profile that completed. For
  example: `` `gleam test` passes: 996 tests`` or
  `` `scripts/test-slow` passes: 1,017 tests``.
- Never say “all tests pass”, “the full suite passes”, or equivalent unless
  `scripts/test-all` completed successfully in the current worktree.
- Use these names consistently:
  - `gleam test`: default suite;
  - `scripts/test-fast`: fast profile, which omits the convex-hull module;
  - `scripts/test-slow`: slow profile, which substitutes the convex-hull
    stress module;
  - `scripts/test-all`: full suite, consisting of both profiles;
  - `scripts/test-release`: canonical pre-release test command.
- Before a release, run `scripts/test-release`. A passing `gleam test` or
  `scripts/test-fast` is not sufficient release verification.

## README And Gallery Images

- Follow `COMMIT_CYCLE.md` for README and Gallery figure workflows.
- When generating paired or tabular graphics where one version changes a subpath's orientation, keep that subpath's arrow in the same visual location across versions and only flip its direction. This makes orientation changes easier to compare.
- When drawing multiple examples in panels, compute the bounding box of each panel's actual geometry and recenter that geometry in the panel before presenting it. Do not rely on hand-tuned translations when a bounding-box centering pass is practical.

## Previewing Figures In Codex Desktop Chat

- Store preview SVGs under `examples/debug/`.
- Display SVGs with ordinary Markdown image syntax using an absolute local filesystem path.
- Do not use `file://`, relative paths, plain paths, or GUI commands such as `open`, Chrome, Inkscape, or Preview.
- Preview SVGs must include explicit root `width` and `height` attributes in addition to `viewBox`; SVGs with only `viewBox` have failed to render inline in Codex desktop chat.
- In this repo, this exact pattern has rendered successfully in Codex desktop chat:

  `![svg preview probe](<absolute-path-to-repo>/examples/debug/svg_preview_probe.svg)`

- For generated figures, use the same shape:

  `![label](<absolute-path-to-repo>/examples/debug/name.svg)`

- Do not generate PNG fallbacks unless the user explicitly asks for PNG. SVG is the expected preview format.

## Communication Style

- Avoid using the word “tiny” unless it is technically relevant, such as describing a small numeric tolerance, geometry case, file size, or similar concrete measurement.
- Keep language plain, vanilla, and jargon-free by default.
- Prefer direct descriptions over colorful phrasing, metaphors, or dramatic wording.
- Use technical terms when they clarify the work, but avoid unnecessary slang or invented labels.
