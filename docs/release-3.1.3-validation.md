# Gleam 3.1.3 release validation

Validated on 2026-10-15 with Gleam 1.18.1, after closest-pair fix `d6c7b63`.

- `scripts/test-release`: passed 2,016 fast and 31 slow root tests, followed
  by 762 portable tests on Erlang and 762 on JavaScript, no failures.
- `gleam format --check src test test_slow test_portable/runner.gleam`: passed.
- `python3 scripts/paperjs/catalog.py --check`: verified all 37 upstream files
  and adaptation modules.
- `gleam run --target javascript` in `examples/public_api_smoke`: passed.
- `gleam docs build`: succeeded.
- `scripts/generate-published-figures`: regenerated 13 README and 33 Gallery
  figures. All 46 match their pre-run bytes. All 13 README references match
  the previous immutable asset commit, reused for `assets-v3.1.3`.
- `gleam export hex-tarball`: builds `build/svg_path-3.1.3.tar`; package
  inspection verified version 3.1.3 and no test/example/benchmark files.

The first canonical run stopped after the passing root suites because local
lockfiles still recorded 3.1.2. All seven local dependency lock entries were
updated to 3.1.3, and the entire canonical command then passed. Figure generation
needed approved network access for example-project dependency resolution and
passed on retry. Neither issue required implementation changes.

Public signatures and options are unchanged. This patch fixes closest-pair
search behavior; publishing to Hex remains a separate user action.
