# Slow test profile

Files in this directory are outside Gleeunit's normal `test/` discovery and
are not run by `gleam test`.

`svg_path_convex_hull_test.gleam` is a stress-test replacement for the smaller
module with the same name under `test/`. Use the repository scripts rather
than moving it manually:

```sh
scripts/test-slow
```

Before a release, run:

```sh
scripts/test-release
```

That command runs the full suite through both the fast and slow profiles.
