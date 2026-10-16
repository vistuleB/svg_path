# Gleam 3.1.4 release validation

Validated on 2026-10-16 with Gleam 1.18.1 after the FL002–FL006 fixes and
API-001 compatibility adjustment. The public CSG error union matches 3.1.3;
the boundary guard remains active and reports the existing construction error.
The detailed diagnostic remains reserved for 4.0.0; see
[the register](../DEFERRED-API.md).

- `scripts/test-release`: passed 2,038 main and 31 slow root tests, followed by
  784 portable Erlang and 784 portable JavaScript tests, with no failures.
- `gleam format --check src test test_slow test_portable/runner.gleam`: passed.
- `python3 scripts/paperjs/catalog.py --check`: verified 37 upstream files and
  all adaptation modules.
- `python3 scripts/flatten/catalog.py`: verified 184 archived files and indexed
  23 test files.
- `gleam run --target javascript` in `examples/public_api_smoke`: passed.
- `gleam docs build`: passed; generated CSG documentation excludes the deferred
  public error case.
- `scripts/generate-published-figures`: regenerated 13 README and 33 Gallery
  figures. The Gallery SVGs are unchanged; all 13 README assets match the
  previous immutable asset commit byte for byte. `assets-v3.1.4` reuses that
  commit and is pushed.
- `gleam export hex-tarball`: generated `build/svg_path-3.1.4.tar`. Inspection
  verified version 3.1.4, the expected README and sources, and exclusion of
  test/example/script files.
- `git diff --check`: passed. README asset URLs use `assets-v3.1.4`.

The first canonical run stopped after passing root profiles because local
manifests still recorded 3.1.3. All eight local dependency entries were updated,
then the entire canonical command passed. Figure generation initially stopped
at example-project dependency resolution under restricted network access; the
complete generator passed with approved access. Neither required source changes.

This is a patch release of the recorded fixes, not a claim of exhaustive
Flatten.js assertion parity. See `scripts/flatten/COVERAGE-GAPS.md` for the
remaining adaptation scope. Publishing to Hex remains a separate user action.
Unrelated local workflow edits and untracked diagnostic files are excluded
from the release commit.
