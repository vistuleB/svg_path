# Slow test profile

Files in this directory are outside Gleeunit's normal `test/` discovery and
are not run by `gleam test`.

`svg_path_convex_hull_test.gleam` contains only the additional convex-hull
stress tests. `scripts/test-slow` runs these tests in isolation from the
ordinary suite:

```sh
scripts/test-slow
```

Before a release, run:

```sh
scripts/test-release
```

That command runs both disjoint profiles.
