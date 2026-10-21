# Gleam 3.1.5 release validation

Release preparation on 2026-10-21 with Gleam 1.18.1.

The accepted Cavalier audit repairs and documented policy dispositions are
recorded in `CAVALIER_AUDIT_CURRENT_STATUS.md`. All active investigations are
closed; accepted limitations remain. This does not claim exact upstream parity.

Public CSG error cases match v3.1.3. API-001 remains reserved for 4.0.0.

- `scripts/test-release`: 2,125 main, 31 slow, 870 portable Erlang and 870
  portable JavaScript tests passed without failures.
- `gleam format --check src test test_slow test_portable/runner.gleam`: passed.
- `python3 scripts/paperjs/catalog.py --check`: 37 upstream files verified.
- `python3 scripts/flatten/catalog.py`: 184 archived files, 23 test files verified.
- Public API smoke check passed on JavaScript, with the host Node directory
  explicitly placed first in PATH.

The first release check encountered stale local dependency versions after the
version bump. All nine local manifests were updated and the complete canonical
release command then passed. Figure generation required network permission to
resolve example-project dependencies. No source changes were required.

- `scripts/generate-published-figures`: all 13 README and 34 Gallery figures
  regenerated successfully. Promoted Gallery SVGs match the committed versions.
  Three README asset files differ from the prior asset commit.
- `gleam docs build`: passed.
- `gleam export hex-tarball`: built `build/svg_path-3.1.5.tar`; verified version,
  pinned README, sources, and exclusion of development files (346 archive files).
- `git diff --check`: passed.

Unrelated local workflow edits and untracked diagnostics are excluded.
Publication to Hex is a separate user action.
