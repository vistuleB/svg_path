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

`scripts/test-slow` installs every `.gleam` module in this directory, plus the
shared convex-hull support module. It runs 31 tests: 26 convex-hull stress tests
and five expensive Paper.js regressions:

- #1409 crossing cases 2 and 3. Case 1 and the positive crossing control remain fast.
- Boolean full-overlap case 107. Cases 122 and 123 remain fast.
- Intersection-address cases 12 and 19. The other address cases remain fast.

These five cases accounted for about 26 seconds in the measured fast suite.
Their geometry and assertions are unchanged. The generators preserve this split.
All parser and construction stack-safety regressions remain in the fast suite.

Run the root slow profile:

```sh
scripts/test-slow
```

Before a release, run:

```sh
scripts/test-release
```

That command runs both disjoint root profiles, then both portable profiles on
Erlang and JavaScript (734 tests per target).

The five moved regressions also form the portable slow profile, selected by
`test_portable/slow-modules.txt`:

```sh
scripts/test-portable all slow
```

`test-portable` defaults to the fast profile (729 tests per target). Use
`scripts/test-portable all all` for the combined selection. CI uses the combined
selection so moving these cases does not remove their JavaScript coverage.
Do not run portable tests concurrently with `test-slow`, which swaps `test/`.
