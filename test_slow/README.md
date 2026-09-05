# Slow test profile

Files in this directory are outside Gleeunit's normal `test/` discovery and
are not run by `gleam test`.

## Why the slow suite lives outside `test/`

The Gleam test toolchain has no way to run a subset of tests. `gleam test`
(which runs `gleeunit.main()` from each test module's `main`) discovers tests
by scanning the `test/` directory at runtime —
`find_files("**/*.{erl,gleam}", in: "test")` in `gleeunit.gleam` — and runs
every `*_test` function in every module it finds. There is no
module-selection or exclusion flag, and Gleeunit ignores command-line
arguments (`gleam test "anything"` still runs the entire suite).

The stress module also deliberately reuses the canonical module name
`svg_path_convex_hull_test`, so it cannot coexist with the ordinary fast
suite in one build. `scripts/test-slow` therefore runs it in isolation by
swapping what is physically under `test/`: it parks the ordinary suite at
`.test-disabled/fast-tests/`, installs the slow copies, runs the profile, and
restores the ordinary suite on exit (interrupted runs restore automatically
via a trap).

`svg_path_convex_hull_test.gleam` contains only the additional convex-hull
stress tests. `scripts/test-slow` runs them in isolation:

```sh
scripts/test-slow
```

Before a release, run:

```sh
scripts/test-release
```

That command runs both disjoint profiles.